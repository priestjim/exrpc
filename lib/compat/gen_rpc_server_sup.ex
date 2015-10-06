# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule :'gen_rpc_server_sup' do

  # ===================================================
  # Compatibility API functions
  # ===================================================

  @doc """
    Proxy module for handling requests from remote Erlang nodes
    to this Elixir node
  """
  @spec start_child(node) :: {:ok, :inet.port_number} | {:ok, any}
  def start_child(node) when is_atom(node) do
    ExRPC.Supervisor.Server.start_child(node)
  end

end
