# -*-mode:elixir;coding:utf-8;tab-width:2;c-basic-offset:2;indent-tabs-mode:()-*-
# ex: set ft=elixir fenc=utf-8 sts=2 ts=2 sw=2 et:
#
# Copyright 2015 Panagiotis Papadomitsos. All Rights Reserved.
#

defmodule ExRPC.Helper do

  # Default TCP options for both client and server
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


  # ===================================================
  # Public API
  # ===================================================

  @doc """
    Returns the current OTP release as an integer that
    can be used to version comparisons

    Since Elixir only runs on OTP >= 17, detection of "R"
    based OTP releases is not needed here
  """
  @spec otp_release() :: pos_integer
  def otp_release() do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end

  @doc """
    Returns the default TCP options the client starts with,
    depending on the current OTP release
  """
  @spec default_tcp_opts() :: list
  def default_tcp_opts() do
    if otp_release >= 18 do
      [{:show_econnreset, true}|@default_tcp_opts]
    else
      @default_tcp_opts
    end
  end

  @doc """
    Sets a socket to active once mode
  """
  @spec activate_socket(port) :: :ok
  def activate_socket(socket) when is_port(socket) do
    :ok = :inet.setopts(socket, active: :once)
  end

  @doc """
    Sets a socket's send timeout
  """
  @spec set_socket_send_timeout(:inet.socket, timeout) :: :ok
  def set_socket_send_timeout(socket, send_timeout)
  when is_port(socket) and ((is_integer(send_timeout) and send_timeout > 0) or send_timeout === :infinity) do
    :ok = :inet.setopts(socket, send_timeout: send_timeout)
  end

  @doc """
    Creates an atom to be used as the registered process name
    using a chosen node name
  """
  @spec make_process_name(:client | :server | :acceptor, node) :: atom
  def make_process_name(role, node) when role in [:client, :server, :acceptor] do
    node_str = node |> Atom.to_string
    role_str = role |> Atom.to_string |> String.capitalize
    "ExRPC." <> role_str <> ".Children." <> node_str |> String.to_atom()
  end

  @doc """
    Retrieves an Elixir node's IP as it is seen by the VM
  """
  @spec get_remote_node_ip(node) :: {127,0,0,1}
  def get_remote_node_ip(node) when node === node() do
    {127,0,0,1}
  end

  @spec get_remote_node_ip(node) :: :inet.ip4_address
  def get_remote_node_ip(node) do
    {:ok, node_info} = :net_kernel.node_info(node)
    address_info = Keyword.get(node_info, :address)
    {:net_address, {ip, _port}, _name, _proto, _channel} = address_info
    ip
  end

end
