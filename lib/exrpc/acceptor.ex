# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Acceptor do

  # gen_fsm behaviour
  @behaviour :gen_fsm

  # Logger
  require Logger

  # Use records for state - much faster
  require Record
  import Record

  # State record
  defrecord :state,
    socket: nil,
    client_ip: nil,
    client_node: nil,
    send_timeout: :infinity,
    inactivity_timeout: :infinity

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts an ExRPC `gen_tcp` acceptor
  """
  @spec start_link(:inet.ip4_address, node) :: {:ok, pid}
  def start_link(client_ip, node) when is_tuple(client_ip) and is_atom(node) do
    name = ExRPC.Helper.make_process_name(:acceptor, node)
    :gen_fsm.start_link({:local, name}, __MODULE__, {client_ip, node}, spawn_opt: [priority: :high])
  end

  @doc """
    Sets the FSM to the data ready state by sending the "socket ownership transferred"
    message.
  """
  @spec set_socket(pid, :inet.socket) :: :ok
  def set_socket(pid, socket) when is_pid(pid) and is_port(socket) do
      :gen_fsm.send_event(pid, {:socket_ready, socket})
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the acceptor state machine
  """
  @spec init({:inet.ip4_address, node}) :: {:ok, nil}
  def init({client_ip, node}) do
    :ok = :net_kernel.monitor_nodes(true, [:nodedown_reason])
    send_to = Application.get_env(:exrpc, :send_timeout)
    inactivity_to = Application.get_env(:exrpc, :server_inactivity_timeout)
    # Store the client's IP and the node in our state
    {:ok, :waiting_for_socket, state(client_ip: client_ip,
                                     client_node: node,
                                     send_timeout: send_to,
                                     inactivity_timeout: inactivity_to)}
  end

  @doc """
    State that gets triggered when the acceptor process receives ownership of the socket
    and sets up the socket for data operation right after filtering the client's IP address
  """
  @spec waiting_for_socket({:socket_read, :inet.socket}, record(:state)) ::
    {:stop, {:badtcp,:invalid_client_ip}, record(:state)} | {:next_state, :waiting_for_data, record(:state)}
  def waiting_for_socket({:socket_ready, socket}, state(client_ip: client_ip, send_timeout: send_to) = state_rec) do
    # Filter the ports we're willing to accept connections from
    {:ok, {ip, _port}} = :inet.peername(socket)
    if client_ip != ip do
      {:stop, {:badtcp,:invalid_client_ip}, state_rec}
    else
      # Now we own the socket
      :ok = :inet.setopts(socket, [{:send_timeout, send_to}|ExRPC.Helper.default_tcp_opts()])
      :ok = ExRPC.Helper.activate_socket(socket)
      {:next_state, :waiting_for_data, state(state_rec, socket: socket)}
    end
  end

  @doc """
    Notification event coming from client
  """
  @spec waiting_for_data({:data, any}, record(:state)) ::
    {:stop, {:badtcp,:erroneous_data | :corrupt_data}, record(:state)} | {:next_state, :waiting_for_data, record(:state)}
  def waiting_for_data({:data, data}, state(socket: socket, client_node: node, inactivity_timeout: ttl) = state_rec) do
    # The meat of the whole project: process a function call and return
    # the data
    try do
      case :erlang.binary_to_term(data) do
        {^node, client_pid, ref, {:call, m, f, a}} ->
          {:ok, _worker_pid} = Task.Supervisor.start_child(ExRPC.Supervisor.ServerWorker, __MODULE__, :call_worker, [self(), client_pid, ref, m, f, a])
          :ok = ExRPC.Helper.activate_socket(socket)
          {:next_state, :waiting_for_data, state_rec, ttl}
        {^node, {:cast, m, f, a}} ->
          {:ok, _worker_pid} = Task.Supervisor.start_child(ExRPC.Supervisor.ServerWorker, m, f, a)
          :ok = ExRPC.Helper.activate_socket(socket)
          {:next_state, :waiting_for_data, state_rec, ttl}
        _other_data ->
          {:stop, {:badrpc, :erroneous_data}, state_rec}
      end
    rescue
      ArgumentError ->
        {:stop, {:badtcp, :corrupt_data}, state_rec}
    end
  end

  @doc """
    Handle the inactivity timeout gracefully
  """
  @spec waiting_for_data(:timeout, record(:state)) :: {:stop, :normal, record(:state)}
  def waiting_for_data(:timeout, state_rec) do
    # Spawning a task that calls the acceptor supervisor and stops this process
    {:ok, _pid} = Task.Supervisor.start_child(ExRPC.Supervisor.ServerWorker, ExRPC.Supervisor.Acceptor, :stop_child, [self()])
    {:stop, :normal, state_rec}
  end

  @doc """
    Incoming data handlers
  """
  @spec handle_info({:tcp, :inet.ip4_address, any}, :waiting_for_data, record(:state)) ::
    {:stop, {:badtcp,:erroneous_data | :corrupt_data}, record(:state)} | {:next_state, :waiting_for_data, record(:state)}
  def handle_info({:tcp, socket, data}, :waiting_for_data, state(socket: socket) = state_rec) when socket != nil do
    waiting_for_data({:data, data}, state_rec)
  end

  @doc """
    Handle a call worker message
  """
  @spec handle_info({:call_reply, any}, :waiting_for_data, record(:state)) ::
    {:stop, {:badtcp, any}, record(:state)} | {:next_state, :waiting_for_data, record(:state), timeout}
  def handle_info({:call_reply, packet_bin}, :waiting_for_data, state(socket: socket, inactivity_timeout: ttl) = state_rec)
  when socket != nil do
    case :gen_tcp.send(socket, packet_bin) do
      :ok ->
        {:next_state, :waiting_for_data, state_rec, ttl}
      {:error, reason} ->
            {:stop, {:badtcp, reason}, state_rec}
    end
  end

  @doc """
    Handle VM node down information
  """
  def handle_info({:nodedown, node, [nodedown_reason: _reason]}, _state_name, state(client_node: node) = state_rec), do: {:stop, :normal, state_rec}
  def handle_info({:tcp_closed, socket}, _state_name, state(socket: socket) = state_rec), do: {:stop, :normal, state_rec}
  def handle_info({:tcp_error, socket, _reason}, _state_name, state(socket: socket) = state_rec), do: {:stop, :normal, state_rec}

  @doc """
    Stub callbacks for behaviour
  """
  def handle_info({node_event, _node, _info_list}, _state_name, state(inactivity_timeout: ttl) = state_rec)
  when node_event in [:nodeup, :nodedown] do
    {:noreply, state_rec, ttl}
  end

  @doc """
    Stub callback for generic info message
  """
  @spec handle_info(any, atom, record(:state)) :: {:stop, {atom, :unknown_message, any}, record(:state)}
  def handle_info(message, state_name, state_rec), do: {:stop, {state_name, :unknown_message, message}, state_rec}

  @doc """
    Stub callbacks for the gen_fsm behaviour
  """
  def handle_event(event, state_name, state_rec), do: {:stop, {state_name, :undefined_event, event}, state_rec}
  def handle_sync_event(event, _From, state_name, state_rec), do: {:stop, {state_name, :undefined_event, event}, state_rec}
  def code_change(_old_version, state_name, state_rec, _extra), do: {:ok, state_name, state_rec}
  def terminate(_reason, _state, _state_rec), do: :ok

  @doc """
    This is the function/process that the task supervisor will
    launch to run the RPC call from a remote node.
  """
  @spec call_worker(tuple, pid, reference, module, function, list) :: any
  def call_worker(caller, client_pid, ref, m, f, a) do
    # If called MFA returns exception, not of type term(),
    # this fails the term_to_binary coversion and crashes the worker process
    # which manifests as a timeout on the client side. Wrapping it in a try/catch
    # allows to get a result, even if it's an exit
    result = try do
      Kernel.apply(m, f, a)
    catch
      :throw, what -> what
      :error, what -> {:badrpc, {:'EXIT', {what, :erlang.get_stacktrace()}}}
      :exit, what -> {:badrpc, {:'EXIT', what}}
    end
    packet_bin = :erlang.term_to_binary({client_pid, ref, result})
    send(caller, {:call_reply, packet_bin})
  end

end
