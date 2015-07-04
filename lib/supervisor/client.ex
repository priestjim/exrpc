# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Supervisor.Client do

  # Use the Supervisor behaviour
  use Supervisor

  # Worker flags
  @child_spec [restart: :permanent, timeout: 5_000]

  # API functions
  @doc "Starts the application supervisor"
  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  # Callback fuctions
  def init(:ok) do
    supervise([], [strategy: :one_for_one, max_restarts: 100, max_seconds: 1])
  end

end
