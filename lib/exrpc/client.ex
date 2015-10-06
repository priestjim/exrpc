# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Client do

  # GenServer behaviour
  use GenServer

  # Logger
  require Logger

  # Use records for state - much faster
  require Record
  import Record

  # State record
  defrecord :state,
    socket: nil,
    server_node: nil,
    send_timeout: :infinity,
    receive_timeout: :infinity,
    inactivity_timeout: :infinity

  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Starts an ExRPC `gen_tcp` client
  """
  @spec start_link(node) :: {:ok, pid}
  def start_link(server_node) when is_atom(server_node) do
    GenServer.start_link(__MODULE__, server_node, name: server_node, spawn_opt: [priority: :high])
  end

  @doc """
    Performs an ExRPC `call`, by automatically connecting to a remote `node`,
    performing a "protected" {`m`,`f`,`a`} call and returning the result within
    `recv_to` milliseconds.
  """
  @spec call(node, module, function, list, timeout | nil, timeout | nil) :: {:badtcp | :badrpc, any} | any
  def call(server_node, m, f, a \\ [], recv_to \\ nil, send_to \\ nil)
  when is_atom(server_node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       (is_nil(recv_to) or is_integer(recv_to) or recv_to === :infinity) and
       (is_nil(send_to) or is_integer(send_to) or send_to === :infinity)
  do
    # Naming our gen_server as the node we're calling as it is extremely efficent:
    # We'll never deplete atoms because all connected node names are already atoms in this VM
    case GenServer.whereis(server_node) do
      nil ->
        case ExRPC.Dispatcher.start_client(server_node) do
          {:ok, new_pid} ->
            # We take care of CALL inside the GenServer
            # This is not resilient enough if the caller's mailbox is full
            # but it's good enough for now
            GenServer.call(new_pid, {{:call,m,f,a}, recv_to, send_to}, :infinity)
          {:error, reason} ->
            reason
        end
      pid ->
        GenServer.call(pid, {{:call,m,f,a}, recv_to, send_to}, :infinity)
    end
  end

  @doc """
    Performs an ExRPC `cast`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast).
  """
  @spec cast(node, module, function, list, timeout | nil) :: true
  def cast(server_node, m, f, a \\ [], send_to \\ nil)
  when is_atom(server_node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       (is_nil(send_to) or is_integer(send_to) or send_to === :infinity)
  do
    case GenServer.whereis(server_node) do
      nil ->
        case ExRPC.Dispatcher.start_client(server_node) do
          {:ok, new_pid} ->
            # We take care of CALL inside the GenServer
            # This is not resilient enough if the caller's mailbox is full
            # but it's good enough for now
            :ok = GenServer.cast(new_pid, {{:cast,m,f,a}, send_to})
            true
          {:error, _reason} ->
            true
        end
      pid ->
        :ok = GenServer.cast(pid, {{:cast,m,f,a}, send_to})
        true
    end
  end

  @doc """
    Performs an ExRPC `safe_cast`, by automatically connecting to a remote `node` and
    sending a "protected" {`m`,`f`,`a`} call that will execute but never return the result
    (an asynchronous cast). In contrast to simple `cast`, this function will return an error
    if the remote node is unreachable.
  """
  @spec safe_cast(node, module, function, list, timeout | nil) :: {:badtcp | :badrpc, any} | true
  def safe_cast(server_node, m, f, a \\ [], send_to \\ nil)
  when is_atom(server_node) and is_atom(m) and
       is_atom(f) and is_list(a) and
       (is_nil(send_to) or is_integer(send_to) or send_to === :infinity)
  do
    case GenServer.whereis(server_node) do
      nil ->
        case ExRPC.Dispatcher.start_client(server_node) do
          {:ok, new_pid} ->
            # We take care of CALL inside the GenServer
            # This is not resilient enough if the caller's mailbox is full
            # but it's good enough for now
            GenServer.call(new_pid, {{:cast,m,f,a}, send_to}, :infinity)
          {:error, reason} ->
            reason
        end
      pid ->
        GenServer.call(pid, {{:cast,m,f,a}, send_to}, :infinity)
    end
  end

  # ===================================================
  # Behaviour callbacks
  # ===================================================

  @doc """
    Initializes the client, enabling exit trapping
    in order to clean up gracefully in case of termination
  """
  @spec init(node) :: {:ok, record(:state)} | {:stop, {:badtcp | :badrpc, any}}
  def init(server_node) do
    # Monitor node disconnections in case one of the nodes being managed
    # by ExRPC disconnect
    :ok = :net_kernel.monitor_nodes(true, [:nodedown_reason])
    # Extract settings to store in state
    settings = Application.get_all_env(:exrpc)
    conn_to = Keyword.get(settings, :connect_timeout)
    send_to = Keyword.get(settings, :send_timeout)
    recv_to = Keyword.get(settings, :receive_timeout)
    inactivity_to = Keyword.get(settings, :client_inactivity_timeout)
    # Perform an in-band RPC call to the remote node
    # asking it to launch a listener for us and return us
    # the port that has been allocated for us
    case :rpc.call(server_node, ExRPC.Supervisor.Server, :start_child, [node()], conn_to) do
      {:ok, port} ->
        # Fetching the IP ourselves, since the remote node
        # does not have a straightforward way of returning
        # the proper remote IP
        address = ExRPC.Helper.get_remote_node_ip(server_node)
        case :gen_tcp.connect(address, port, ExRPC.Helper.default_tcp_opts(), conn_to) do
          {:ok, socket} ->
            {:ok, state(socket: socket, server_node: server_node,
                        send_timeout: send_to, receive_timeout: recv_to,
                        inactivity_timeout: inactivity_to), inactivity_to}
            {:error, reason} ->
              {:stop, {:badtcp, reason}}
        end
      {:badrpc, reason} ->
          {:stop, {:badrpc, reason}}
    end
  end

  @doc """
    Handles a `call` request to the client GenServer
  """
  def handle_call({{:call, _m, _f, _a} = packet_tuple, user_recv_to, user_send_to},
                  caller, state(socket: socket, server_node: server_node) = state_rec) do
    # Merge the custom call's settings with the default ones
    state(receive_timeout: state_recv_to, send_timeout: state_send_to, inactivity_timeout: ttl) = state_rec
    {recv_to, send_to} = merge_timeout_values(state_recv_to, user_recv_to, state_send_to, user_send_to)
    ref = Kernel.make_ref()
    # Spawn the worker that will wait for the server's reply and
    # let the server know of the responsible process
    {:ok, worker_pid} = Task.Supervisor.start_child(ExRPC.Supervisor.ClientWorker, __MODULE__, :call_worker, [ref, caller, recv_to])
    packet = :erlang.term_to_binary({node(), worker_pid, ref, packet_tuple})
    :ok = ExRPC.Helper.set_socket_send_timeout(socket, send_to)
    # Since call can fail because of a timed out connection without ExRPC knowing it,
    # we have to make sure the remote node is reachable somehow before we send data. net_kernel:connect does that
    case :net_kernel.connect(server_node) do
      true ->
        case :gen_tcp.send(socket, packet) do
          :ok ->
            # We need to enable the socket and perform the call only if the call succeeds
            :ok = ExRPC.Helper.activate_socket(socket)
            # Reply will be handled from the worker
            {:noreply, state_rec, ttl}
          {:error, :timeout} ->
            # Reply will be handled from the worker
            {:stop, {:badtcp,:send_timeout}, {:badtcp,:send_timeout}, state_rec}
          {:error, reason} ->
            # Reply will be handled from the worker
            {:stop, {:badtcp,reason}, {:badtcp,reason}, state_rec}
        end
      _else ->
        {:stop, {:badrpc,:nodedown}, {:badrpc,:nodedown}, state_rec}
    end
  end

  @doc """
    Handles a `safe_cast` request to the client GenServer
  """
  def handle_call({{:cast, _m, _f, _a} = packet_tuple, user_send_to},
                  _caller, state(socket: socket, server_node: server_node, inactivity_timeout: ttl) = state_rec) do
    case do_cast(packet_tuple, user_send_to, socket, server_node, state_rec) do
      {:error, error} ->
        {:stop, error, error, state_rec};
      :ok ->
        {:reply, true, state_rec, ttl}
    end
  end

  @doc """
    Handles a `cast` request to the client GenServer
  """
  def handle_cast({{:cast, _m, _f, _a} = packet_tuple, user_send_to},
                  state(socket: socket, server_node: server_node, inactivity_timeout: ttl) = state_rec) do
    case do_cast(packet_tuple, user_send_to, socket, server_node, state_rec) do
      {:error, error} ->
        {:stop, error, state_rec};
      :ok ->
        {:noreply, state_rec, ttl}
    end
  end

  @doc """
    Handle any TCP packet coming in
  """
  def handle_info({:tcp,socket,data}, state(socket: socket, inactivity_timeout: ttl) = state_rec) do
    try do
      case :erlang.binary_to_term(data) do
        {task_pid, ref, reply} ->
          if Process.alive?(task_pid) do
            send(task_pid, {:reply,ref,reply})
          else
            :ok
          end
        _other_data ->
          :ok
      end
    rescue
      ArgumentError ->
        :ok
    end
    :ok = ExRPC.Helper.activate_socket(socket)
    {:noreply, state_rec, ttl}
  end

  @doc """
    Handle VM node down information
  """
  def handle_info({:nodedown, node, [nodedown_reason: _reason]}, state(server_node: node) = state_rec), do: {:stop, :normal, state_rec}
  def handle_info({:tcp_closed, socket}, state(socket: socket) = state_rec), do: {:stop, :normal, state_rec}
  def handle_info({:tcp_error, socket, _reason}, state(socket: socket) = state_rec), do: {:stop, :normal, state_rec}

  @doc """
    Stub for VM up information
  """
  def handle_info({node_event, _node, _info_list}, state(inactivity_timeout: ttl) =  state_rec) when node_event in [:nodeup, :nodedown] do
    {:noreply, state_rec, ttl}
  end

  @doc """
    Handle the inactivity timeout gracefully
  """
  def handle_info(:timeout, state_rec) do
    # Spawning a task that calls the client supervisor and stops this process
    {:ok, _pid} = Task.Supervisor.start_child(ExRPC.Supervisor.ServerWorker, ExRPC.Supervisor.Client, :stop_child, [self()])
    {:stop, :normal, state_rec}
  end

  @doc """
    This function is used as the Task launched by the server, waiting to receive a
    reply from the TCP channel via the server in order to reply to the caller
  """
  @spec call_worker(reference, tuple, timeout) :: any
  def call_worker(ref, caller, timeout) do
    receive do
      {:reply,^ref,reply} ->
        _ = GenServer.reply(caller, reply)
      _else ->
        _ = GenServer.reply(caller, {:badrpc, :invalid_message_received})
        exit({:error, :invalid_message_received})
    after
      timeout ->
        _ = GenServer.reply(caller, {:badrpc, :timeout})
        exit({:error, :timeout})
    end
  end

  # ===================================================
  # Private functions
  # ===================================================

  # DRY function for cast and safe_cast
  @spec do_cast(tuple, timeout | nil, :inet.socket, node, record(:state)) :: :ok | {:error, {:badtcp, any}} | {:error, {:badrpc, :nodedown}}
  defp do_cast(packet_tuple, user_send_to, socket, node, state(send_timeout: state_send_to)) do
    {_recv_to, send_to} = merge_timeout_values(nil, nil, state_send_to, user_send_to)
    # Cast requests do not need a reference
    packet = :erlang.term_to_binary({node(), packet_tuple})
    # Set the send timeout and do not run in active mode - we're a cast!
    :ok = ExRPC.Helper.set_socket_send_timeout(socket, send_to)
    # Since cast can fail because of a timed out connection without gen_rpc knowing it,
    # we have to make sure the remote node is reachable somehow before we send data. net_kernel:connect does that
    case :net_kernel.connect(node) do
      true ->
        case :gen_tcp.send(socket, packet) do
          {:error, :timeout} ->
              # Terminate will handle closing the socket
              {:error, {:badtcp,:send_timeout}}
          {:error, reason} ->
              {:error, {:badtcp,reason}}
          :ok ->
            :ok
        end
      _else ->
        {:error, {:badrpc,:nodedown}}
    end
  end

  # Merges user-define timeout values with state timeout values
  @spec merge_timeout_values(timeout | nil, timeout | nil, timeout | nil, timeout | nil) ::
                            {timeout | nil, timeout | nil, timeout | nil, timeout | nil}
  defp merge_timeout_values(state_recv_to, nil, state_send_to, nil), do: ({state_recv_to, state_send_to})
  defp merge_timeout_values(_state_recv_to, user_recv_to, state_send_to, nil), do: ({user_recv_to, state_send_to})
  defp merge_timeout_values(state_recv_to, nil, _state_send_to, user_send_to), do: ({state_recv_to, user_send_to})
  defp merge_timeout_values(_state_recv_to, user_recv_to, _state_send_to, user_send_to), do: ({user_recv_to, user_send_to})

end