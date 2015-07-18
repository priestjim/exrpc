defmodule ExRPC.Mixfile do

  use Mix.Project

  @default_elixirc_options [docs: true]

  def project do
    [
      app: :exrpc,
      description: "ExRPC is an out-of band messaging library that uses TCP ports to send and receive data between Elixir nodes",
      version: "0.1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      language: :elixir,
      deps: [],
      aliases: aliases,
      package: package,
      elixirc_options: elixirc_options(Mix.env)
    ]
  end

  def application do
    [
      applications: [:logger, :crypto, :asn1, :public_key, :ssl],
      env: [connect_timeout: 5000, # Client connect timeout
            send_timeout: 5000, # Client and Server send timeout
            receive_timeout: 15000, # Default receive timeout for call() functions
            client_inactivity_timeout: :infinity, # Inactivity timeout for client gen_server
            server_inactivity_timeout: :infinity # Inactivity timeout for server gen_server
      ],
      registered: [Elixir.ExRPC.Supervisor.Application,
                   Elixir.ExRPC.Supervisor.Server,
                   Elixir.ExRPC.Supervisor.Client,
                   Elixir.ExRPC.Supervisor.Acceptor,
                   Elixir.ExRPC.Dispatcher
      ],
      mod: {ExRPC, []}
    ]
  end

  # ===================================================
  # Private functions
  # ===================================================

  defp package do
    [
      files: [
        "LICENSE",
        "mix.exs",
        "README.md",
        "lib",
        "test"
      ],
      contributors: ["Panagiotis PJ Papadomitsos <pj@ezgr.net>"],
      links: %{"github" => "https://github.com/priestjim/exrpc"},
      licenses: ["Apache"]
    ]
  end

  defp aliases do
    [
      test: [&start_epmd/1, "test"],
      c: "compile",
      t: "test",
      tr: "test --trace",
      d: ["deps.get --only #{Mix.env}", "compile", "test"]
    ]
  end

  defp elixirc_options(:prod) do
    [{:debug_info, false}, {:warnings_as_errors, true}|@default_elixirc_options]
  end

  defp elixirc_options(_env) do
    @default_elixirc_options
  end

  defp start_epmd(_args) do
    Mix.Shell.IO.info("Starting distributed Elixir")
    {"", 0} = System.cmd("epmd", ["-daemon"])
  end

end
