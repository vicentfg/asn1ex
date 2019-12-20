defmodule Asn1ex.Mixfile do
  use Mix.Project

  def project do
    [app: :asn1ex,
     version: "0.0.1",
     deps: deps()]
  end

  def application do
    [
      env: [asn1_paths: ["asn1"], erlc_paths: ["src"], asn1_options: []]
    ]
  end

  defp deps do
    []
  end
end
