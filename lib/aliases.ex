# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Aliases do

  def __using__(_opts) do
    quote do
      alias :erlang, as: Erlang
      alias :lists, as: Lists
      alias :binary, as: Binary
      alias :gen_tcp, as: GenTCP
    end
  end

end

