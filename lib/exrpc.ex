# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC do

  # Use the Application behaviour
  use Application

  @moduledoc """
    `ExRPC` is an out-of band messaging library that uses TCP ports to
    send and receive data between Elixir nodes. It behaves mostly like the
    `RPC` module but uses differente ports and processes for different nodes,
    effectively spreading the load to multiple processes instead of pushin data
    from every remote node/RPC call to the single `rex` server.

    You can generally use `ExRPC.call` and `ExRPC.cast` the same way you use
    the `RPC` library, in the following manner:

    iex> ExRPC.call(node, :erlang, :is_atom, [:ok])
    {:ok, true}

    iex> ExRPC.cast(node, :os, :timestamp)
    :ok
  """

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts the `ExRPC` application manually for
    testing and rapid iteration
  """
  @spec start() :: :ok
  def start() do
    {:ok, _apps} = Application.ensure_all_started(:exrpc)
    :ok
  end

  @doc """
    Performs an `{m,f,a}` RPC call to a remote node and waits `recv_to` milliseconds
    for the results.

    The RPC call is performed on a separate process and is protected
  """
  @spec call(node, atom, atom, list, pos_integer | nil, pos_integer | nil) :: {:ok, any} | {:badtcp, any} | {:badrpc, any}
  def call(node, m, f, a \\ [], recv_to \\ nil, send_to \\ nil)
  when is_atom(node) and is_atom(m) and is_atom(f) and is_list(a) do
    :ok
  end

  @doc """
    Performs an `{m,f,a}` RPC cast to a remote node. The results of the function call are **ignored** and
    never communicated back.

    The RPC cast is performed on a separate process and is protected
  """
  @spec cast(node, atom, atom, list, pos_integer | nil) :: :ok | {:badtcp, any} | {:badrpc, any}
  def cast(node, m, f, a \\ [], send_to \\ nil)
  when is_atom(node) and is_atom(m) and is_atom(f) and is_list(a) do
    :ok
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Starts the ExRPC application supervisor
  """
  @spec start(atom, list) :: {:ok, pid}
  def start(_type, _args) do
    ExRPC.Supervisor.Application.start_link()
  end

end
