# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC do

  use Application

  @moduledoc """
    `ExRPC` is an out-of band messaging library that uses TCP ports to
    send and receive data between Elixir nodes. It behaves mostly like the
    `RPC` module but uses differente ports and processes for different nodes,
    effectively spreading the load to multiple processes instead of the single
    `rex` server.
  """

  # Behaviour callbacks

  @doc """
    Starts the ExRPC application supervisor
  """
  def start(_type, _args) do
    ExRPC.Supervisor.Application.start_link()
  end

  @doc """
    Starts the `ExRPC` application manually for
    testing and rapid iteration
  """
  def start() do
    {:ok, _apps} = Application.ensure_all_started(:exrpc)
    :ok
  end

  @doc """
    Stops the `ExRPC` application manually for
    testing and rapid iteration
  """
  def stop() do
    :ok = Application.stop(:exrpc)
  end


end
