# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Supervisor.Application do

  @moduledoc """
    The `ExRPC` application supervisor, responsible for starting, stopping and
    supervising the `ExRPC` process family, comprised of:

    - The **Client** supervisor, responsible for launching and supervising per
    remote node ExRPC connections
    - The **Server** supervisor, responsible for launching and supervising incoming
    remote connection requests
    - The **Acceptor** supervisor, responsible for launching and supervising the server acceptors,
    in an one-to-one Server-Acceptor fashion
    - The **Dispatcher** server, a GenServer process used for serializing initialization of remote
    `ExRPC` connections
  """

  # Use the Supervisor behaviour
  use Supervisor

  # Supervision flags
  @child_spec [restart: :permanent, timeout: 5_000]
  @strategy [strategy: :one_for_one, max_restarts: 100, max_seconds: 1]

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts the application supervisor
  """
  @spec start_link() :: {:ok, pid}
  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the supervisor and returns a list of children to be supervised
  """
  @spec init(nil) :: tuple
  def init(nil) do
    children = [supervisor(ExRPC.Supervisor.Server, [], [{:name, ExRPC.Supervisor.Server}|@child_spec]),
      supervisor(ExRPC.Supervisor.Acceptor, [], [{:name, ExRPC.Supervisor.Acceptor}|@child_spec]),
      worker(ExRPC.Dispatcher, [], [{:name, ExRPC.Dispatcher}|@child_spec]),
      supervisor(ExRPC.Supervisor.Client, [], [{:name, ExRPC.Supervisor.Client}|@child_spec])]
    supervise(children, @strategy)
  end

end
