# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC do

  @moduledoc """
    ExRPC is an out-of band RPC application and library that uses multiple TCP
    ports to send and receive data between Elixir nodes. It behaves mostly like Erlang's
    `RPC` module but uses different ports and processes for different nodes,
    effectively spreading the load to X processes for X nodes, instead of pushing data
    from every remote node/RPC call into a single `rex` server.

    The first step is start the target server. Example below assumes node name is 
    exrpc_@127.0.0.1 and path to your beam per standard rebar3 location.

    You can generally use `ExRPC.call` and `ExRPC.cast` the same way you use
    the `RPC` library, in the following manner:

      iex> ExRPC.call(:'exrpc_slave@127.0.0.1', :erlang, :is_atom, [:ok], 1000)
      true

      iex> ExRPC.call(:'exrpc_slave@127.0.0.1', Kernel, :is_atom, [:ok], 1000)
      true

      iex> ExRPC.call(:'random_node@127.0.0.1', Kernel, :is_atom, [:ok], 1000)
      {:badrpc, :nodedown}

      iex> ExRPC.cast(:'exrpc_slave@127.0.0.1', :os, :timestamp)
      true

      iex> ExRPC.cast(:'exrpc_slave@127.0.0.1', Kernel, :is_atom, [:ok], 1000)
      true

      iex> ExRPC.safe_cast(:'exrpc_slave@127.0.0.1', :os, :timestamp)
      true

      iex> ExRPC.safe_cast(:'exrpc_slave@127.0.0.1', Kernel, :is_atom, [:ok], 1000)
      true

      iex> ExRPC.safe_cast(:'random_node@127.0.0.1', :os, :timestamp)
      {:badrpc, :nodedown}

      Direct rip out from elixir Task.ex doc:
      Note that, when working with distributed tasks, one should use the `async/4` function
      that expects explicit module, function and arguments, instead of `async/2` that
      works with anonymous functions. That's because anonymous functions expect
      the same module version to exist on all involved nodes. Check the `Agent` module
      documentation for more information on distributed processes as the limitations
      described in the agents documentation apply to the whole ecosystem.

      iex'...>' ExRPC.async(:'exrpc_slave@127.0.0.1', IO, :puts, ["hello"]) |> Task.await()
      "hello\n"

      iex'...>' ExRPC.async(:'exrpc_slave@127.0.0.1', IO, :puts, ["hello"]) |> Task.await()
      "hello\n"

    ExRPC will try to detect possible issues with the TCP channel on which
    it operates, both by closely monitoring `gen_tcp` timeouts and by testing
    connectivity through the Erlang VM for `every single request`, thus ensuring
    proper response to changes in channel state.
  """

  # ===================================================
  # Private Macro
  # ===================================================
  defmacro is_proper_timeout(timeout) do
     quote do
        is_nil(unquote(timeout)) or (is_integer(unquote(timeout)) and unquote(timeout) >= 0 ) or unquote(timeout) === :infinity
     end
  end

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Performs an ExRPC `call`, by automatically connecting to a remote `node`,
    performing a "protected" {`m`,`f`,`a`} call and returning the result within
    `recv_to` milliseconds.

    It is important to understand that receiving {:badrpc, :timeout} does not guarantee
    that the RPC call failed, just that it took it longer than it was expected to execute.

    If the RPC calls finishes and sends the result back to the client, those results will be dropped.
  """
  @spec call(node, module, function, list, timeout | nil, timeout | nil) :: {:badtcp | :badrpc, any} | any
  def call(node, m, f, a \\ [], recv_to \\ nil, send_to \\ nil)
  when is_atom(node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       is_proper_timeout(recv_to) and
       is_proper_timeout(send_to)
  do
    ExRPC.Client.call(node, m, f, a, recv_to, send_to)
  end

  @doc """
    Performs an ExRPC `cast`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast).
  """
  @spec cast(node, module, function, list, timeout | nil) :: true
  def cast(node, m, f, a \\ [], send_to \\ nil)
  when is_atom(node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       is_proper_timeout(send_to)
  do
    ExRPC.Client.cast(node, m, f, a, send_to)
  end

  @doc """
    Performs an ExRPC `safe_cast`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast). In contrast to the simple `cast` functin, this function will
    return an error if the connection to the remote node fails (hence the `safe` prefix).
  """
  @spec safe_cast(node, module, function, list, timeout | nil) :: {:badtcp | :badrpc, any} | true
  def safe_cast(node, m, f, a \\ [], send_to \\ nil)
  when is_atom(node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       is_proper_timeout(send_to)
  do
    ExRPC.Client.safe_cast(node, m, f, a, send_to)
  end

  @doc """
    Performs an ExRPC `async`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast). In contrast to the simple `cast` functin, this function will
    return an error if the connection to the remote node fails (hence the `safe` prefix).
  """
  @spec async(node, module, function, list, timeout | nil) :: {:badtcp | :badrpc, any} | true
  def async(node, m, f, a \\ [], send_to \\ nil)
  when is_atom(node) and is_atom(m) and
       is_atom(f) and is_list(a)
  do
    ExRPC.Client.async(node, m, f, a, send_to)
  end

  @doc """
    Performs an ExRPC `yield`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast). In contrast to the simple `cast` functin, this function will
    return an error if the connection to the remote node fails (hence the `safe` prefix).
  """
  @spec yield(node, module, function, list, timeout | nil) :: {:badtcp | :badrpc, any} | true
  def yield(node, m, f, a \\ [], send_to \\ nil)
  when is_atom(node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       is_proper_timeout(send_to)
  do
    ExRPC.Client.yield(node, m, f, a, send_to)
  end

  @doc """
    Performs an ExRPC `await`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast). In contrast to the simple `cast` functin, this function will
    return an error if the connection to the remote node fails (hence the `safe` prefix).
  """
  @spec await(node, module, function, list, timeout | nil) :: {:badtcp | :badrpc, any} | true
  def await(node, m, f, a \\ [], send_to \\ nil)
  when is_atom(node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       is_proper_timeout(send_to)
  do
    ExRPC.Client.await(node, m, f, a, send_to)
  end
end
