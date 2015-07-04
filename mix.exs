defmodule ExRPC.Mixfile do
  use Mix.Project

  def project do
    [app: :exrpc,
     version: "1.0.0",
     elixir: "~> 1.1-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     aliases: aliases]
  end

  def application do
    [
      applications: [:logger],
      mod: {ExRPC, []}
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [c: "compile",
    t: "test",
    d: ["deps.get --only #{Mix.env}", "compile", "test"]]
  end
end
