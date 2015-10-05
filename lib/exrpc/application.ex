# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Application do

  # Use the Application behaviour
  use Application

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
