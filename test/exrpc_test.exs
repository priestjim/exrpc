defmodule ExRPC.Test do
  use ExUnit.Case

  doctest ExRPC

  test "Proper application startup" do
    assert({:ok, _apps} = Application.ensure_all_started(:exrpc))
  end

  test "Supervisor startup" do
    assert(is_pid(Process.whereis(ExRPC.Supervisor.Application)) === true)
    assert(is_pid(Process.whereis(ExRPC.Supervisor.Server)) === true)
    assert(is_pid(Process.whereis(ExRPC.Supervisor.Client)) === true)
    assert(is_pid(Process.whereis(ExRPC.Supervisor.ServerWorker)) === true)
    assert(is_pid(Process.whereis(ExRPC.Supervisor.ClientWorker)) === true)
    assert(is_pid(Process.whereis(ExRPC.Supervisor.Acceptor)) === true)
    assert(is_pid(Process.whereis(ExRPC.Dispatcher)) === true)
  end

end
