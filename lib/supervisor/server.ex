# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Supervisor.Server do

  @moduledoc """
    The server supervisor, responsible for starting, stopping and
    supervising local RPC server processes
  """

  # Use the Supervisor behaviour
  use Supervisor

  # Supervision attributes
  @child_spec [restart: :transient, timeout: 5_000]
  @strategy [strategy: :simple_one_for_one, max_restarts: 100, max_seconds: 1]

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts the RPC server supervisor
  """
  @spec start_link() :: {:ok, pid}
  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
    Starts a local RPC server process and returns the `gen_tcp` port
    allocated to it
  """
  @spec start_child(node) :: {:ok, pid}
  def start_child(node) when is_atom(node) do
    {:ok, pid} = Supervisor.start_child(__MODULE__, [node])
    {:ok, port} = ExRPC.Server.get_port(pid)
    {:ok, port}
  end

  @doc """
    Terminates a local RPC server process and unregisters that process
    from the supervisor
  """
  @spec stop_child(pid) :: :ok
  def stop_child(pid) when is_pid(pid) do
    :ok = Supervisor.terminate_child(__MODULE__, pid)
    :ok
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the supervisor using the simple one for one strategy, allowing
    to dynamically register servers per remote client
  """
  @spec init(nil) :: tuple
  def init(nil) do
    supervise([worker(ExRPC.Server, [], [{:name, ExRPC.Server}|@child_spec])], @strategy)
  end

end
