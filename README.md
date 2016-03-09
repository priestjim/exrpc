# ExRPC: A scalable RPC library for Erlang-VM based languages.

## Big Fat Warning

**This project was created as a proof of concept in order to compare Erlang and Elixir development. It has largely fallen behind in features and bug fixes in comparison to its sister project [gen_rpc](https://github.com/priestjim/gen_rpc). `gen_rpc` is fully compatible with any Elixir project and should be used instead of `ExRPC`. The last version of `gen_rpc` that works well with `ExRPC` is `0.9`**

## Overview

- Latest release: ![Tag Version](https://img.shields.io/github/tag/priestjim/exrpc.svg)
- Branch status (`master`): [![Build Status](https://travis-ci.org/priestjim/exrpc.svg?branch=master)](https://travis-ci.org/priestjim/exrpc)
- Branch status (`develop`): [![Build Status](https://travis-ci.org/priestjim/exrpc.svg?branch=develop)](https://travis-ci.org/priestjim/exrpc)
- Issues: [![GitHub issues](https://img.shields.io/github/issues/priestjim/exrpc.svg)](https://github.com/priestjim/exrpc/issues)
- License: [![GitHub license](https://img.shields.io/badge/license-Apache%202-blue.svg)](https://raw.githubusercontent.com/priestjim/exrpc/master/LICENSE)

## Rationale

**TL;DR**: `ExRPC` uses a mailbox-per-node architecture and `:gen_tcp` processes to parallelize data reception from multiple nodes without blocking the VM's distributed port.

The reasons for developing `ExRPC` became apparent after a lot of trial and error while trying to scale a distributed Erlang infrastructure using the `:rpc` library initially and subsequently `:erlang.spawn/4` (remote spawn). Both these solutions suffer from very specific issues under a sufficiently high number of requests.

The `:rpc` library operates by shipping data over the wire via Distributed Erlang's ports into a registered `GenServer` on the other side called `:rex` (Remote EXecution server), which is running as part of the standard distribution. In high traffic scenarios, this allows the inherent problem of running a single `GenServer` server to manifest: mailbox flooding. As the number of nodes participating in a data exchange with the node in question increases, so do the messages that `:rex` has to deal with, eventually becoming too much for the process to handle (don't forget this is confined to a single thread).

Enter `:erlang.spawn/4` (_remote spawn_ from now on). Remote spawn dynamically spawns processes on a remote node, skipping the single-mailbox restriction that `:rex` has. The are various libraries written to leverage that loophole (such as [Rexi](https://github.com/cloudant/rexi)), however there's a catch.

Remote spawn was not designed to ship large amounts of data as part of the call's arguments. Hence, if you want to ship a large binary such as a picture or a transaction log (large can also be small if your network is slow) over remote spawn, sooner or later you'll see this message popping up in your logs if you have subscribed to the system monitor through `:erlang.system_monitor/2`:

    {:monitor,#PID<4685.187.0>,:busy_dist_port,#Port<4685.41652>}

This message essentially means that the VM's distributed port pair was busy while the VM was trying to use it for some other task like _Distributed Erlang heartbeat beacons_ or _mnesia synchronization_. This of course wrecks havoc in certain timing expectations these subsystems have and the results can be very problematic: the VM might detect a node as disconnected even though everything is perfectly healthy and `:mnesia` might misdetect a network partition.

`ExRPC` solves both these problems by sharding data coming from different nodes to different processes (hence different mailboxes) and by using different `:gen_tcp` ports for different nodes (hence not utilizing the Distributed Erlang ports).

# Build Dependencies

To build this project you need to have the following:

* **Erlang/OTP** >= 18.0

* **Elixir** >= 1.20

* **git** >= 1.7

* **GNU make** >= 3.80

## Usage

Getting started with `ExRPC` is easy. First, add the appropriate dependency line to your `mix.exs`:

    def deps do
      [{:exrpc, "~> 1.0.0"}]
    end

Then, add `ExRPC` as a dependency application to your application:

    def application do
      [applications: [:exrpc]]
    end

Finally, start a couple of nodes to test it out:

    iex(exrpc@127.0.0.1)1> ExRPC.call(:"other_node@1.2.3.4", :erlang, :node, []).
    :"other_node@1.2.3.4"

## Build Targets

`ExRPC` bundles a `Makefile` that makes development straightforward.

To build `ExRPC` simply run:

    make

To run the full test suite, run:

    make test

To run Dialyxir, run:

    make dialyzer

To build the project and drop in a console while developing, run:

    make shell

To clean every build artifact and log, run:

    make distclean

## API

`ExRPC` implements only the subset of the functions of the `:rpc` library that make sense for the problem it's trying to solve. The library's function interface and return values is **100%** compatible with `:rpc` with only one addition: Error return values include `{:badrpc, error}` for RPC-based errors but also `{:badtcp, error}` for TCP-based errors.

For more information on what the functions below do, run `erl -man rpc`.

### Functions exported

- `call(node, module, function, args)` and `call(node, module, function, args, timeout)`: A blocking synchronous call, in the `GenServer` fashion.

- `cast(node, module, function, args)`: A non-blocking fire-and-forget call.

### Application settings

- `:connect_timeout`: Default timeout for the initial node-to-node connection in **milliseconds**.

- `:send_timeout`: Default timeout for the transmission of a request (`call`/`cast` etc.) from the local node to the remote node in **milliseconds**.

- `:receive_timeout`: Default timeout for the reception of a response in a `call` in **milliseconds**.

- `:client_inactivity_timeout`: Inactivity period in **milliseconds** after which a client connection to a node will be closed (and hence have the TCP file descriptor freed).

- `:server_inactivity_timeout`: Inactivity period in **milliseconds** after which a server port will be closed (and hence have the TCP file descriptor freed).

## Architecture

In order to achieve the mailbox-per-node feature, `ExRPC` uses a very specific architecture:

- Whenever a client needs to send data to a remote node, it will perform a `Process.whereis` to a process named after the remote node. This is deliberate as it allows fast process lookups without atom-to-term conversions

- If the specified `client` process does not exist, it will request for a new one through the `dispatcher` process, which in turn will launch it through the appropriate supervisor. Since this `whereis`-request from dispatcher sequence can happen concurrently by many different processes, serializing it behind a `GenServer` allows us to avoid race conditions.

- The `dispatcher` process will perform an normal `:rpc` call to the other node, requesting from the `server` supervisor to launch a new `server` listener.

- The `server` supervisor will launch the new `server` process, which in turn will dynamically allocate (`:gen_tcp.listen(0)`) a port and return it to its supervisor.

- The `server` supervisor returns the port to the `client` through `:rpc`.

- The `client` then connects to the returned port and establishes a TCP session. The `server` on the other node launches a new `acceptor` server as soon as a `client` connects. The relationship between `client`-`server`-`acceptor` is one-to-one-to-one.

- The `client` finally encodes the request (`call`, `cast` etc.) along with some metadata (the caller's PID and a reference) and sends it over the TCP channel. At the same time, it launches a process that will be responsible for handing the server's reply to the requester.

- The `server` on the other side decodes the TCP message received and spawns a new process that will perform the requested function. By spawning a process external to the server, the `server` protects itself from misbehaving function calls.

- As soon as the reply from the server is ready (only needed in `async_call` and `call`), the `server` spawned process messages the server with the reply, the `server` ships it through the TCP channel to the `client`, the `client` messages the spawned worker and the worker replies to the caller with the result.

All `:gen_tcp` processes are properly linked so that any TCP failure will cascade and close the TCP channels and any new connection will allocate a new process and port.

An inactivity timeout has been implemented inside the `client` and `server` processes to free unused TCP connections after some time, in case that's needed.

## Known Issues

- When shipping an anonymous function over to another node, it will fail to execute because of the way Erlang implements anonymous functions (Erlang serializes the function metadata but not the function body). This issue also exists in both `:rpc` and remote spawn.

- Client connections are registered with the connected node's name. This might cause issues if you have other processes that register their names like that.

## Licensing

This project is published and distributed under the [Apache License](LICENSE).

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md)
