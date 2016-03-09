# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Server do

  # GenServer behaviour
  use GenServer

  # Logger
  require Logger

  # Use records for state - much faster
  require Record
  import Record

  # State record
  defrecord :state,
    client_node: nil,
    listener_sock: nil,
    acceptor_pid: nil,
    acceptor_ref: nil

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
  def start_link(client_node) when is_atom(client_node) do
    name = ExRPC.Helper.make_process_name(:server, client_node)
    GenServer.start_link(__MODULE__, client_node, name: name, spawn_opt: [priority: :high])
  end

  @doc """
    Returns the dynamically allocated port by `gen_tcp`
  """
  @spec get_port(pid) :: {:ok, non_neg_integer}
  def get_port(pid) when is_pid(pid) do
    GenServer.call(pid, :get_port, :infinity)
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the server, enabling exit trapping
    in order to clean up gracefully in case of termination
  """
  @spec init(atom) :: {:ok, nil} | {:stop, any}
  def init(client_node) do
    case :gen_tcp.listen(0, ExRPC.Helper.default_tcp_opts()) do
      {:ok, socket} ->
        {:ok, ref} = :prim_inet.async_accept(socket, -1)
        {:ok, state(client_node: client_node,
                     listener_sock: socket, acceptor_ref: ref)}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @doc """
    Returns the dynamically allocated port by `gen_tcp`
  """
  @spec handle_call(atom, tuple, record(:state)) :: {:reply, {:ok, pos_integer}, record(:state)}
  def handle_call(:get_port, _from, state(listener_sock: socket) = state_rec) do
    {:ok, port} = :inet.port(socket)
    {:reply, {:ok,port}, state_rec}
  end

  @doc """
    Gracefully stops the server
  """
  def handle_call(:stop, _from, state_rec) do
    {:stop, :normal, :ok, state_rec}
  end

  @doc """
    Receives an incoming connection to the listening port and dispatches
    an acceptor to handle subsequent communication
  """
  @spec handle_info({:inet_async, port, tuple, tuple}, record(:state) | {:EXIT, pid, any}) ::
    {:noreply, record(:state)} | {:stop, {:badtcp, any}, record(:state)}
  def handle_info({:inet_async, listener_sock, acceptor_ref, {:ok, acceptor_sock}},
                  state(client_node: client_node, listener_sock: listener_sock, acceptor_ref: acceptor_ref) = state_rec) do
    try do
      # Start an acceptor process. We need to provide the acceptor
      # process with our designated node IP and name so enforcement
      # of those attributes can be made for security reasons.
      {:ok, acceptor_pid} = ExRPC.Supervisor.Acceptor.start_child(client_node)
      # Link to acceptor, if they die so should we, since we are single-receiver
      # to single-acceptor service
      true = :erlang.link(acceptor_pid)
      _ = case set_sock_opts(listener_sock, acceptor_sock) do
        :ok ->
          :ok
        {:error, reason} ->
          {:stop, {:badtcp, {:set_sock_opts, reason}}, state_rec}
      end
      :ok = :gen_tcp.controlling_process(acceptor_sock, acceptor_pid)
      :ok = ExRPC.Acceptor.set_socket(acceptor_pid, acceptor_sock)
      # We want the acceptor to drop the connection, so we remain
      # open to accepting new connections, otherwise
      # passive connections will remain open and leave us prone to
      # a DoS file descriptor depletion attack
      case :prim_inet.async_accept(listener_sock, -1) do
        {:ok, new_ref} ->
          {:noreply, state(state_rec, acceptor_ref: new_ref), :hibernate}
        {:error, new_ref} ->
          reason = :inet.format_error(new_ref)
          {:stop, {:badtcp, {:async_accept, reason}}, state_rec}
      end
    catch
      :exit, reason ->
        {:stop, {:badtcp, reason}, state_rec}
    end
  end

  @doc """
    Handles async socket errors gracefully
  """
  def handle_info({:inet_async, listener_sock, acceptor_ref, error},
                  state(listener_sock: listener_sock, acceptor_ref: acceptor_ref) = state_rec) do
    {:stop, {:badtcp, error}, state_rec}
  end

  @doc """
    Handle exit messages from the child `ExRPC.Acceptor` gracefully
  """
  def handle_info({:EXIT, acceptor_pid, reason}, state(acceptor_pid: acceptor_pid) = state_rec) do
    {:stop, reason, state_rec}
  end

  # ===================================================
  # Private functions
  # ===================================================

  # Copies a set of TCP flags from the listener socket to a new
  # acceptor socket. Similar implementation exists in the `prim_inet`
  # module
  @spec set_sock_opts(port, port) :: :ok | {:error, any}
  defp set_sock_opts(listener, acceptor) do
    true = :inet_db.register_socket(acceptor, :inet_tcp)
    case :prim_inet.getopts(listener, @acceptor_tcp_opts) do
      {:ok, opts} ->
        case :prim_inet.setopts(acceptor, opts) do
          :ok ->
            :ok
          error ->
            _res = :gen_tcp.close(acceptor)
            error
        end
      error ->
        _res = :gen_tcp.close(acceptor)
        error
    end
  end

end
