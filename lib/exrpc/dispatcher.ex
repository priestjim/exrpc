# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Dispatcher do

  # GenServer behaviour
  use GenServer

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts the dispatcher server
  """
  @spec start_link() :: {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
    Starts a new `ExRPC.Client` server through the appropriate
    supervisor.
  """
  @spec start_client(node) :: {:ok, pid}
  def start_client(node) when is_atom(node) do
    GenServer.call(__MODULE__, {:start_client,node}, :infinity)
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the Dispatcher server
  """
  @spec init(nil) :: {:ok, nil}
  def init(nil) do
    {:ok, nil}
  end

  @doc """
    Requests a client spawn from the `Client` supervisor in
    case a client does not already exist. It is being used as a serialization point
    in case multiple launch requests to the same client are performed
  """
  @spec handle_call({:start_client,node}, tuple, nil) :: {:reply, tuple, nil}
  def handle_call({:start_client,node}, _from, nil) do
    reply = case GenServer.whereis(node) do
      nil ->
        ExRPC.Supervisor.Client.start_child(node)
      pid ->
        {:ok, pid}
      end
    {:reply, reply, nil}
  end

end
