defmodule ExRPC.Test.Functional.Pinfo do
  use ExUnit.Case
  
  import ExRPC.Test.Helper

  setup_all do
    ExRPC.Test.Helper.start_slave_node()
    on_exit fn() ->
      ExRPC.Test.Helper.stop_slave_node()
    end
    :ok
  end

  test "Pinfo on living process on local node" do
    pid = ExRPC.call(master, Process, :spawn, [fn -> :timer.sleep(100000) end])
    assert true = ExRPC.call(master, Process, :alive?, [pid])
    assert [] != ExRPC.pinfo(master, pid)
  end

  test "Pinfo on dead process on local node" do
    pid = ExRPC.call(master, Process, :spawn, [fn -> Process.exit(self, :normal) end])
    assert false = ExRPC.call(master, Process, :alive?, [pid])
    assert :undefined = ExRPC.pinfo(master, pid)
  end

  test "Pinfo status on living process on local node" do
    pid = ExRPC.call(master, Process, :spawn, [fn -> :timer.sleep(100000) end])
    assert true = ExRPC.call(master, Process, :alive?, [pid])
    assert {:status,:waiting}!= ExRPC.pinfo(master, pid, [:status])
  end

  test "Pinfo on living process on slave node" do
    pid = ExRPC.call(slave, Process, :spawn, [fn -> :timer.sleep(100000) end])
    assert true = ExRPC.call(slave, Process, :alive?, [pid])
    assert [] != ExRPC.pinfo(slave, pid)
  end

  test "Pinfo on dead process on slave node" do
    pid = ExRPC.call(slave, Process, :spawn, [fn -> Process.exit(self, :normal) end])
    assert false = ExRPC.call(slave, Process, :alive?, [pid])
    assert :undefined = ExRPC.pinfo(slave, pid)
  end

  test "Pinfo on process that throws on slave node" do
    pid = ExRPC.call(slave, Process, :spawn, [fn -> throw(:xxxxxx) end])
    assert false = ExRPC.call(slave, Process, :alive?, [pid])
    assert :undefined = ExRPC.pinfo(slave, pid)
  end

  test "Pinfo status on living process on slave node" do
    pid = ExRPC.call(slave, Process, :spawn, [fn -> :timer.sleep(100000) end])
    assert true = ExRPC.call(slave, Process, :alive?, [pid])
    assert {:status,:waiting}!= ExRPC.pinfo(slave, pid, [:status])
  end
end
