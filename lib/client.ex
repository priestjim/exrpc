# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Client do

  # GenServer behaviour
  use GenServer

  # Client state
  defmodule State do
    defstruct client_sock: nil,
      server_node: nil,
      send_timeout: :infinity,
      receive_timeout: :infinity,
      inactivity_timeout: :infinity
  end
  alias ExRPC.Client.State

  # Default TCP options
  @default_tcp_opts [:binary,    # All data communication is binary
    {:packet,4},                 # The packet payload size is 4 bytes
    {:nodelay, true},            # Send our requests immediately
    {:send_timeout_close, true}, # When the socket times out, close the connection
    {:delay_send, true},         # Scheduler should favor big batch requests
    {:linger, {true,2}},         # Allow the socket to flush outgoing data for 2"
                                 # before closing it - useful for casts
    {:reuseaddr, true},          # Reuse local port numbers
    {:keepalive, true},          # Keep our channel open
    {:tos, 72},                  # Deliver immediately
    {:active, false}]            # Retrieve data from socket upon request

  # TCP options to be copied to the new acceptor
  @acceptor_tcp_opts [:nodelay,
    :send_timeout_close,
    :delay_send,
    :linger,
    :reuseaddr,
    :keepalive,
    :tos,
    :active]

# -record(state, {socket :: port(),
#         server_node :: atom(),
#         send_timeout :: non_neg_integer(),
#         receive_timeout :: non_neg_integer(),
#         inactivity_timeout :: non_neg_integer() | infinity}).

# %%% Default TCP options
# -ifdef(GEN_TCP_CONN_RESET_NOTIFICATION).
# -define(DEFAULT_TCP_OPTS, [binary, {packet,4},
#         {nodelay,true}, % Send our requests immediately
#         {send_timeout_close,true}, % When the socket times out, close the connection
#         {delay_send,true}, % Scheduler should favor big batch requests
#         {linger,{true,2}}, % Allow the socket to flush outgoing data for 2" before closing it - useful for casts
#         {reuseaddr,true}, % Reuse local port numbers
#         {keepalive,true}, % Keep our channel open
#         {tos,72}, % Deliver immediately
#         {show_econnreset, true}, % Receive connection reset messages
#         {active,false}]). % Retrieve data from socket upon request
# -else.
# -define(DEFAULT_TCP_OPTS, [binary, {packet,4},
#         {nodelay,true}, % Send our requests immediately
#         {send_timeout_close,true}, % When the socket times out, close the connection
#         {delay_send,true}, % Scheduler should favor big batch requests
#         {linger,{true,2}}, % Allow the socket to flush outgoing data for 2" before closing it - useful for casts
#         {reuseaddr,true}, % Reuse local port numbers
#         {keepalive,true}, % Keep our channel open
#         {tos,72}, % Deliver immediately
#         {active,false}]). % Retrieve data from socket upon request
# -endif.







  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts an ExRPC `gen_tcp` server
  """
  @spec start_link(node) :: {:ok, pid}
  def start_link(node) when is_atom(node) do
    name = make_process_name(node)
    GenServer.start_link(__MODULE__, node, name: name, spawn_opt: [priority: :high])
  end

  @doc """
    Stops an ExRPC `gen_tcp` server
  """
  @spec stop(pid) :: :ok
  def stop(pid) when is_pid(pid) do
    GenServer.call(pid, :stop, :infinity)
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the Dispatcher server, enabling exit trapping
    in order to clean up gracefully in case of termination
  """
  @spec init(node) :: {:ok, nil}
  def init(node) do
    Process.flag(:trap_exit, true)
    client_ip = get_remote_node_ip(node)
    case :gen_tcp.listen(0, @default_tcp_opts) do
      {:ok, socket} ->
        {:ok, ref} = :prim_inet.async_accept(socket, -1)
        {:ok, %State{server_node: node,
                     client_sock: socket}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc """
    Handles termination gracefully by closing the TCP listening socket
  """
  @spec terminate(any, %State{}) :: :ok
  def terminate(_reason, %State{client_sock: client_sock}) do
    _res = :gen_tcp.close(client_sock)
    _pid = Process.spawn(ExRPC.Supervisor.Client, :stop_child, [self()])
    :ok
  end

  # ===================================================
  # Private functions
  # ===================================================

  """
    Creates an atom to be used as the registered process name
    using a chosen node name
  """
  @spec make_process_name(node) :: atom
  defp make_process_name(node) do
    node_str = Atom.to_string(node)
    String.to_atom("ExRPC.Server.Children." <> node_str)
  end

  """
    Copies a set of TCP flags from the listener socket to a new
    acceptor socket. Similar implementation exists in the `prim_inet`
    module
  """
  @spec set_sock_opts(port, port) :: :ok | {:error, any}
  def set_sock_opts(listener, acceptor) do
    true = :inet_db.register_socket(acceptor, :inet_tcp)
    case :prim_inet.getopts(listener, @acceptor_tcp_opts) do
      {:ok, opts} ->
        case :prim_inet.setopts(acceptor, opts) do
          :ok ->
            :ok
          error ->
            :gen_tcp.close(acceptor)
            error
        end
      error ->
        :gen_tcp.close(acceptor)
        error
    end
  end

  """
    Retrieves an Elixir node's IP as it is seen by the VM
  """
  @spec get_remote_node_ip(node) :: {127,0,0,1}
  defp get_remote_node_ip(node) when node === node() do
    {127,0,0,1}
  end

  @spec get_remote_node_ip(node) :: {non_neg_integer,non_neg_integer,non_neg_integer,non_neg_integer}
  defp get_remote_node_ip(node) do
    {:ok, node_info} = :net_kernel.node_info(node)
    {:address, address_info} = Keyword.fetch(node_info, :address)
    {:net_address, {ip, _port}, _name, _proto, _channel} = address_info
    ip
  end

end
