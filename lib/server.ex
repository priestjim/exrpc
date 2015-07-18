# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Server do

  # GenServer behaviour
  use GenServer

  # Server state
  defmodule State do
    defstruct client_ip: nil,
      client_node: nil,
      listener_sock: nil,
      acceptor_pid: nil,
      acceptor_ref: nil

  end
  alias ExRPC.Server.State

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

  @doc """
    Returns the dynamically allocated port by `gen_tcp`
  """
  @spec get_port(pid) :: {:ok, non_neg_integer}
  def get_port(pid) when is_pid(node) do
    GenServer.call(pid, :get_port, :infinity)
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
        {:ok, %State{client_ip: client_ip, client_node: node,
                     listener_sock: socket, acceptor_ref: ref}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc """
    Returns the dynamically allocated port by `gen_tcp`
  """
  @spec handle_call(:get_port, tuple, %State{}) :: {:ok, pos_integer}
  def handle_call(:get_port, _from, %State{listener_sock: socket} = state) do
    {:ok, port} = :inet.port(socket)
    {:reply, {:ok,port}, state}
  end

  @doc """
    Gracefully stops the server
  """
  @spec handle_call(:stop, tuple, %State{}) :: :ok
  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  @doc """
    Receives an incoming connection to the listening port and dispatches
    an acceptor to handle subsequent communication
  """
  @spec handle_info({:inet_async, port, tuple, tuple}, %State{}) :: {:noreply, %State{}} | {:stop, {:badtcp, any}, %State{}}
  def handle_info({:inet_async, listener_sock, acceptor_ref, {:ok, acceptor_sock}},
                  %State{client_ip: client_ip, listener_sock: listener_sock, acceptor_ref: acceptor_ref} = state) do
    try do
      # Start an acceptor process. We need to provide the acceptor
      # process with our designated node IP and name so enforcement
      # of those attributes can be made for security reasons.
      {:ok, acceptor_pid} = ExRPC.Supervisor.Acceptor.start_child(client_ip, node)
      # Link to acceptor, if they die so should we, since we are single-receiver
      # to single-acceptor service
      true = :erlang.link(acceptor_pid)
      case set_sock_opts(listener_sock, acceptor_sock) do
        :ok ->
          :ok
        {:error, reason} ->
          {:stop, {:badtcp, {:set_sock_opts, reason}}, state}
      end
      :ok = :gen_tcp.set_controlling_process(acceptor_sock, acceptor_pid)
      :ok = ExRPC.Acceptor.set_socket(acceptor_pid, acceptor_sock)
      # We want the acceptor to drop the connection, so we remain
      # open to accepting new connections, otherwise
      # passive connections will remain open and leave us prone to
      # a DoS file descriptor depletion attack
      case :prim_inet.async_accept(listener_sock, -1) do
        {:ok, new_ref} ->
          {:noreply, %{state | acceptor_ref: new_ref}}
        {:error, new_ref} ->
          reason = :inet.format_error(new_ref)
          {:stop, {:badtcp, {:async_accept, reason}}, state}
      end
    catch
      :exit, reason ->
        {:stop, {:badtcp, reason}, state}
    end
  end

  @doc """
    Handles async socket errors gracefully
  """
  @spec handle_info({:inet_async, port, tuple, any}, %State{}) :: {:stop, {:badtcp, any}, %State{}}
  def handle_info({:inet_async, listener_sock, acceptor_ref, error},
                  %State{listener_sock: listener_sock, acceptor_ref: acceptor_ref} = state) do
    {:stop, {:badtcp, error}, state}
  end

  @doc """
    Handle exit messages from the child `ExRPC.Acceptor` gracefully
  """
  @spec handle_info({:EXIT, pid, any}, %State{}) :: {:stop, any, %State{}}
  def handle_info({:EXIT, acceptor_pid, reason}, %State{acceptor_pid: acceptor_pid} = state) do
    {:stop, reason, state}
  end

  @doc """
    Handles termination gracefully by closing the TCP listening socket
  """
  @spec terminate(any, %State{}) :: :ok
  def terminate(_reason, %State{listener_sock: listener_sock}) do
    _res = :gen_tcp.close(listener_sock)
    _pid = Process.spawn(ExRPC.Supervisor.Server, :stop_child, [self()])
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
