defmodule Asn1ex.Mixfile do
  use Mix.Project

  def project do
    [app: :asn1ex,
     version: "0.0.1",
     elixir: ">= 0.15.1 and ~> 1.0.2",
     deps: deps]
  end

  def application do
    []
  end

  defp deps do
    []
  end
end
