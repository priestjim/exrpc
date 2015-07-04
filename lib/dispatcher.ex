# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Dispatcher do

  # GenServer behaviour
  use GenServer

  # API functions
  @doc "Starts the application supervisor"
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

end
