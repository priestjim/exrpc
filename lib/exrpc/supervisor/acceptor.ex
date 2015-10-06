# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Supervisor.Acceptor do

  @moduledoc """
    The acceptor supervisor, responsible for starting, stopping and
    supervising local RPC acceptor processes
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
    Starts the RPC acceptor supervisor
  """
  @spec start_link() :: {:ok, pid}
  def start_link() do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
    Starts a local RPC acceptor process
  """
  @spec start_child(:inet.ip4_address, node) :: {:ok, pid}
  def start_child(client_ip, node) when is_tuple(client_ip) and is_atom(node) do
    Supervisor.start_child(__MODULE__, [client_ip,node])
  end

  @doc """
    Terminates a local RPC acceptor process and unregisters that process
    from the supervisor
  """
  @spec stop_child(pid) :: :ok
  def stop_child(pid) when is_pid(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the supervisor using the simple one for one strategy, allowing
    to dynamically register acceptors, one per local server
  """
  @spec init(nil) :: tuple
  def init(nil) do
    supervise([worker(ExRPC.Acceptor, [], [{:name, ExRPC.Acceptor}|@child_spec])], @strategy)
  end

end
