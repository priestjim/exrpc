%%% -*-mode:erlang;coding:utf-8;tab-width:4;c-basic-offset:4;indent-tabs-mode:()-*-
%%% ex: set ft=erlang fenc=utf-8 sts=4 ts=4 sw=4 et:
%%%
%%% Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
%%%

-module(gen_rpc_server_sup).
-author("Panagiotis Papadomitsos <pj@ezgr.net>").

%%% ===================================================
%%% Compatibility API functions
%%% ===================================================

%% Proxy module for handling requests from remote Erlang nodes
%% to this Elixir node
-spec start_child(Node::node()) -> {'ok', inet:port_number()} | {ok, _}.
start_child(Node) when is_atom(Node) ->
    'Elixir.ExRPC.Supervisor.Server':start_child(Node).
