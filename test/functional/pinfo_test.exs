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
    pid = ExRPC.call(master, Kernel, :spawn, [fn -> :timer.sleep(100000) end])
    assert true == ExRPC.call(master, Process, :alive?, [pid])
    assert [] == ExRPC.pinfo(master, pid)
  end

  test "Pinfo on dead process on local node" do
    pid = ExRPC.call(master, Kernel, :spawn, [fn -> Process.exit(self, :normal) end])
    assert false == ExRPC.call(master, Process, :alive?, [pid])
    assert [] == ExRPC.pinfo(master, pid)
    assert nil == ExRPC.pinfo(master, pid, :status)
  end

  test "Pinfo status on living process on local node" do
    pid = ExRPC.call(master, Kernel, :spawn, [fn -> :timer.sleep(100000) end])
    assert true == ExRPC.call(master, Process, :alive?, [pid])
    assert {:status,:waiting} == ExRPC.pinfo(master, pid, :status)
  end

  test "Pinfo on living process on slave node" do
    pid = ExRPC.call(slave, Kernel, :spawn, [fn -> :timer.sleep(100000) end])
    assert true == ExRPC.call(slave, Process, :alive?, [pid])
    assert [] == ExRPC.pinfo(slave, pid)
  end

  test "Pinfo on dead process on slave node" do
    pid = ExRPC.call(slave, Kernel, :spawn, [fn -> Process.exit(self, :normal) end])
    # A bit concerning. Erlang never need to wait this long for remote pid status
    :timer.sleep(500) 
    assert false == ExRPC.call(slave, Process, :alive?, [pid])
    assert [] == ExRPC.pinfo(slave, pid)
    assert nil == ExRPC.pinfo(slave, pid, :status)
  end

  test "Pinfo on process that throws on slave node" do
    pid = ExRPC.call(slave, Kernel, :spawn, [fn -> throw(:xxxxxx) end])
    assert true == ExRPC.call(slave, Process, :alive?, [pid])
    assert [] == ExRPC.pinfo(slave, pid)
  end

  test "Pinfo on process that throws but catch on slave node" do
    pid = ExRPC.call(slave, Kernel, :spawn, [fn -> try do throw(:xxxxxx) catch any-> any end end])
    assert true == ExRPC.call(slave, Process, :alive?, [pid])
    assert [] == ExRPC.pinfo(slave, pid)
  end

  test "Pinfo status on living process on slave node" do
    pid = ExRPC.call(slave, Kernel, :spawn, [fn -> :timer.sleep(100000) end])
    assert true == ExRPC.call(slave, Process, :alive?, [pid])
    assert {:status,:waiting} == ExRPC.pinfo(slave, pid, :status)
  end
end
