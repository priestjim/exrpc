defmodule ExRPC.Test.Supervisor do
  use ExUnit.Case

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
