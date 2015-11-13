defmodule ExRPC.Mixfile do

  use Mix.Project

  @default_elixirc_options [docs: true]

  def project do
    otp_release = :erlang.system_info(:otp_release) |> List.to_integer()
    {:ok, %Version{major: major,
      minor: minor,
      patch: patch}} = Elixir.System.version |> Elixir.Version.parse
    elixir_release = "#{major}.#{minor}.#{patch}"
    [
      app: :exrpc,
      description: "ExRPC is an out-of band RPC application and library that uses multiple TCP ports to send and receive data between Elixir nodes",
      version: "1.0.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      language: :elixir,
      elixir: "~> 1.1",
      deps: deps,
      aliases: aliases,
      package: package,
      source_url: "https://github.com/priestjim/exrpc",
      homepage_url: "https://github.com/priestjim/exrpc",
      elixirc_options: elixirc_options(Mix.env),
      dialyzer: [
        plt_add_apps: [:asn1,
          :crypto,
          :edoc,
          :erts,
          :eunit,
          :inets,
          :kernel,
          :mnesia,
          :public_key,
          :ssl,
          :stdlib,
          :xmerl
          ],
        plt_file: "_plt/otp-#{otp_release}_elixir-#{elixir_release}.plt",
        plt_add_deps: true,
        flags: ["-Wno_return",
          "-Wno_unused",
          "-Wno_improper_lists",
          "-Wno_fun_app",
          "-Wno_match",
          "-Wno_opaque",
          "-Wno_fail_call",
          "-Wno_contracts",
          "-Wno_behaviours",
          "-Wno_undefined_callbacks",
          "-Wunmatched_returns",
          "-Werror_handling",
          "-Wrace_conditions"
        ]
      ],
      test_coverage: [tool: ExCoveralls]
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
      registered: [Elixir.ExRPC.Dispatcher],
      mod: {ExRPC.Application, []}
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

  defp deps do
    [
     # Test dependencies
     {:excoveralls, "~> 0.3", only: :test},
  end

  defp aliases do
    [
      test: [&start_epmd/1, "test"],
      c: "compile",
      t: "test",
      tr: "test --trace",
      d: "dialyzer",
      f: ["deps.get --only #{Mix.env}", "compile", "test", "dialyzer"]
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
