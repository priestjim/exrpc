defmodule ExRPC.Test.Functional.Async do
  use ExUnit.Case

  import ExRPC.Test.Helper

  setup_all do
    ExRPC.Test.Helper.start_slave_node()
    on_exit fn() ->
      ExRPC.Test.Helper.stop_slave_node()
    end
    :ok
  end

  setup do
    on_exit fn -> Logger.add_backend(:console, flush: true) end
    :ok
  end

  test "Async" do
    task = ExRPC.async(slave, :os, :timestamp, [])
    assert {_,_,_} =  ExRPC.await(task, 1000) 
    task = ExRPC.async(slave, :os, :timestamp, [])
    assert {_,_,_} =  ExRPC.await(task) 
    task = ExRPC.async(slave, :os, :timestamp, [])
    assert {:ok, {_,_,_}} =  ExRPC.yield(task, 1000)
    task = ExRPC.async(slave, :os, :timestamp, [])
    assert {:ok, {_,_,_}} =  ExRPC.yield(task) 
  end

  test "Async on local node mf" do
    task = ExRPC.async(master, :erlang, :node)
    assert master === ExRPC.await(task, 1000)
    task = ExRPC.async(master, :erlang, :node, [])
    assert {:ok, master} === ExRPC.yield(task, 10)
  end

  test "Async on local node mfa" do
    task = ExRPC.async(master, Kernel, :send, [self, {:test, 'wawasing'}])
    receive do
        {:test, _} -> true
        msg ->  :erlang.error RuntimeError.exception(msg) 
    end
    assert {:test, 'wawasing'} =  ExRPC.await(task, 1000)   
    task = ExRPC.async(master, Kernel, :send, [self, {'yatbaryatbaryatbar'}])
    assert {'yatbaryatbaryatbar'} =  ExRPC.await(task, 1000) 
  end

  test "Async with invalid function" do
    task = ExRPC.async(master, :os, :timestamp_undef, [])
    assert {:badrpc, {:EXIT, {:undef, _}}} = ExRPC.yield(task, 1000)
    task = ExRPC.async(slave, :os, :timestamp_undef, [])
    assert {:badrpc, {:EXIT, {:undef, _}}} = ExRPC.await(task, 1000)
  end

  test "Async on invalid node" do
    task =  ExRPC.async(invalid, :os, :timestamp, [])
    assert {:badrpc, :nodedown} === ExRPC.await(task, 1000)
  end

  test "Async with process exit on local node" do
    task =  ExRPC.async(master, :erlang, :apply, [fn -> exit :die end, []])
    assert {:badrpc, {:EXIT, :die}} === ExRPC.await(task, 1000)
  end

  test "Async with process throw on local node" do
    task = ExRPC.async(master, :erlang, :apply, [fn -> throw :throwMaster end, []])
    assert :throwMaster === ExRPC.await(task, 1000)
  end

  test "Async slave with process timeout on local node" do
    task = ExRPC.async(master, :erlang, :apply, [fn() -> :timer.sleep(10000) end, []])
    assert catch_exit(ExRPC.await(task, 1000) == {:timeout, {Task, :await, [task, 1000]}})
  end

  test "Await cannot reuse reference" do
    task = ExRPC.async(master, Kernel, :throw, [:throwSlave])
    assert {:ok, :throwSlave} === ExRPC.yield(task, 1000)
    assert nil === ExRPC.yield(task, 1000)
    assert catch_exit(ExRPC.await(task, 1000) == {:timeout, {Task, :await, [task, 1000]}})
    task = ExRPC.async(slave, Kernel, :throw, [:throwSlave])
    assert {:ok, :throwSlave} === ExRPC.yield(task, 1000)
    assert nil === ExRPC.yield(task, 1000)
    assert catch_exit(ExRPC.await(task, 1000) == {:timeout, {Task, :await, [task, 1000]}})
  end

  test "Async slave with process exit on remote node" do
    task = ExRPC.async(slave, Kernel, :exit, [:exitslave])
    assert {:badrpc, {:EXIT, :exitslave}} === ExRPC.await(task, 1000)
    task = ExRPC.async(slave, :erlang, :exit, [:exitslave])
    assert {:badrpc, {:EXIT, :exitslave}} === ExRPC.yield(task)
  end

  test "Async with process throw on remote node" do
    task = ExRPC.async(slave, :erlang, :throw, [:throwSlave])
    assert :throwSlave === ExRPC.await(task, 1000)
    task = ExRPC.async(slave, Kernel, :throw, [:throwSlave])
    assert :throwSlave === ExRPC.await(task, 1000)
  end
  test "Async with process raise on remote node" do
    task = ExRPC.async(master, :erlang, :apply, [fn -> raise ArgumentError, :badarg end, []])
    assert {:badrpc, {:EXIT, {:function_clause, [{ArgumentError, :exception, [:badarg],_},
_,_,_,_]}}} = (ExRPC.await(task, 1000))
  end

  test "Async slave with process timeout on remote node" do
    task = ExRPC.async(slave, :timer,:sleep, [10000])
    assert catch_exit(ExRPC.await(task, 1000) == {:timeout, {Task, :await, [task, 1000]}})
  end

end
