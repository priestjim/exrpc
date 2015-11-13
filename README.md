[![Build Status](https://travis-ci.org/priestjim/exrpc.svg)](https://travis-ci.org/priestjim/exrpc)

+master: [![Coverage Status](https://coveralls.io/repos/priestjim/exrpc/badge.svg?branch=master&service=github)](https://coveralls.io/github/priestjim/exrpc?branch=master)
+develop: [![Coverage Status](https://coveralls.io/repos/priestjim/exrpc/badge.svg?branch=develop&service=github)](https://coveralls.io/github/priestjim/exrpc?branch=develop)

# ExRPC

`ExRPC` is an out-of band messaging library that uses TCP ports to
send and receive data between Elixir nodes. It behaves mostly like the
`RPC` module but uses differente ports and processes for different nodes,
effectively spreading the load to multiple processes instead of the single
`rex` server.

`ExRPC` is full compatible with its sister project, `gen_rpc` as messages can
transparently be exchanged between an Elixir `ExRPC` node and an Erlang `gen_rpc` node.

## Installation

  1. Add exrpc to your list of dependencies in mix.exs:

        def deps do
          [{:exrpc, "~> 1.0.0"}]
        end

  2. Ensure exrpc is started before your application:

        def application do
          [applications: [:exrpc]]
        end
