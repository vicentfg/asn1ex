defmodule Mix.Tasks.Compile.Asn1 do
  use Mix.Task
  alias Mix.Compilers.Erlang

  @recursive true
  @manifest ".compile.asn1"

  @moduledoc """
  Compile ASN.1 source files.

  When this task runs, it will check the modification time of every file, and
  if it has changed, the file will be compiled. Files will be
  compiled in the same source directory with a .erl extension.
  You can force compilation regardless of modification times by passing
  the `--force` option.

  ## Command line options

    * `--force` - forces compilation regardless of modification times

  ## Configuration

    * `:asn1_paths` - directories to find source files. Defaults to `["asn1"]`.

    * `:erlc_paths` - directories to store generated source files. Defaults to `["src"]`.

    * `:asn1_options` - compilation options that apply
      to ASN.1's compiler. There are many other available
      options here: http://erlang.org/doc/man/asn1ct.html#compile-2.

  """

  @doc """
  Runs this task.
  """
  @spec run(OptionParser.argv) :: :ok | :noop
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [force: :boolean])

    project      = Mix.Project.config
    source_paths = project[:asn1_paths] || ["asn1"]
    dest_paths    = project[:erlc_paths]
#    mappings     = Enum.zip(source_paths, dest_paths)
    options      = project[:asn1_options] || []

    build_dest

    targets = extract_targets(source_paths, dest_paths, opts[:force])

    # Erlang.compile(manifest(), mappings, :'set.asn1', :erl, opts[:force], fn
    compile(manifest(), targets, fn
      input, output ->
        options = options ++ [:noobj, outdir: Erlang.to_erl_file(Path.dirname(output))]
        input_file = if is_list(input), then: List.first(input), else: input
        { :asn1ct.compile(Erlang.to_erl_file(input_file), options),
          # String.to_atom Path.basename(input, "set.asn1")}
          Path.basename(output)}
    end)
  end

  @doc """
  Returns ASN.1 manifests.
  """
  def manifests, do: [manifest]
  defp manifest, do: Path.join(Mix.Project.manifest_path, @manifest)

  @doc """
  Cleans up compilation artifacts.
  """
  def clean do
    modules = read_manifest(manifest())
    Enum.each(modules, fn mod -> Enum.each(module_files(Path.dirname(mod),Path.basename(mod)), &File.rm/1) end)
    File.rm manifest
    if File.ls(Path.dirname(List.first(modules)||[])) == {:ok, []} do
      File.rmdir(Path.dirname(List.first(modules)))
    end
  end

  defp module_files(dest_dir, module) do
    [Path.join([dest_dir, module <> ".erl"]),
     Path.join([dest_dir, module <> ".hrl"]),
     Path.join([dest_dir, module <> ".asn1db"])]
  end

  defp module_from_asn(asn) do
    asn |> Path.basename |> Path.rootname |> Path.rootname
  end

  # Get modules
  defp extract_targets(src_dir, dest_dir, force) do

    files = Mix.Utils.extract_files(List.wrap(src_dir), ["asn1", "asn", "py"])
    file_sets = Mix.Utils.extract_files(List.wrap(src_dir),  ["set.asn1", "set.asn", "set.py"])

    {singleFileModules, moduleFiles} = Enum.reduce(file_sets, {files--file_sets, []},
      fn (file, {files, targets}) ->
        case File.read(file) do
          {:ok, contents} ->
            set_files = Enum.map(String.split(contents, "\n", trim: true), &Path.join(src_dir, &1))
            {files -- set_files, [targets ++ [file | set_files]]}
          {:error, _} -> {files, targets}
        end
      end )

    sourcesByModule = singleFileModules ++ moduleFiles

    for source <- sourcesByModule do
      module = module_from_asn( List.first (List.wrap(source)))
      if force || Mix.Utils.stale?(List.wrap(source), module_files(dest_dir, module)) do
        {:stale, source, Path.join(dest_dir,module)}
      else
        {:ok, source, Path.join(dest_dir,module)}
      end
    end
  end

  defp build_dest() do
      # Build the project structure so we can write down compiled files.
      File.mkdir_p!(Mix.Project.config[:erlc_paths])
  end


  defp read_manifest(file) do
    case File.read(file) do
      {:ok, contents} -> String.split(contents, "\n")
      {:error, _} -> []
    end
  end

  defp write_manifest(file, entries) do
    Path.dirname(file) |> File.mkdir_p!
    File.write!(file, Enum.join(entries, "\n"))
  end


  defp compile(manifest, tuples, callback) do
    stale = for {:stale, src, dest} <- tuples, do: {src, dest}

    # Get the previous entries from the manifest
    entries = read_manifest(manifest)

    # Files to remove are the ones in the manifest
    # but they no longer have a source
    removed = Enum.filter(entries, fn entry ->
      not Enum.any?(tuples, fn {_status, _src, dest} -> dest == entry end)
    end)

    if stale == [] && removed == [] do
      :noop
    else

      # Remove manifest entries with no source
      Enum.each(removed, fn mod -> Enum.each(module_files(Path.dirname(mod),Path.basename(mod)), &File.rm/1) end)

      # Compile stale files and print the results
      results = for {input, output} <- stale do
        interpret_result(input, callback.(input, output))
      end

      # Write final entries to manifest
      entries = (entries -- removed) ++ Enum.map(stale, &elem(&1, 1))
      write_manifest(manifest, :lists.usort(entries))

      # Raise if any error, return :ok otherwise
      if :error in results do
        Mix.raise "Encountered compilation errors."
      end
      :ok
    end
  end

  defp interpret_result(_file, result) do
    case result do
      {:ok, mod} -> Mix.shell.info "Compiled #{mod}"
      :error -> nil
    end
    result
  end

end
