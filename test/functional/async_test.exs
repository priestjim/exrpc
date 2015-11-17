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
    assert {_,_,_} =  ExRPC.yield(task, 1000)
    task = ExRPC.async(slave, :os, :timestamp, [])
    assert {_,_,_} =  ExRPC.yield(task) 
  end

  test "Async on local node mf" do
    task = ExRPC.async(master, :erlang, :node)
    assert master ===  ExRPC.await(task, 1000)

  end

  test "Async on local node mfa" do
    task = ExRPC.async(master, Kernel, :send, [self, {:test, 'wawasing'}])
    receive do
        {:test, _} -> true
        msg ->  :erlang.error RuntimeError.exception(msg) 
    end
     assert master ===  ExRPC.await(task, 1000)   

  end

  test "Async with invalid function" do
    task = ExRPC.async(slave, :os, :timestamp_undef, [])
    assert {:badrpc,  _} = ExRPC.await(task, 1000)
  end

  test "Async on invalid node" do
    task =  ExRPC.async(invalid, :os, :timestamp, [])
    assert {:badrpc, :nodedown} === ExRPC.await(task, 1000)
  end

  test "Async with process exit on local node" do
    task =  ExRPC.async(master, :erlang, :apply, [fn() -> exit(:die) end, []])
    assert :die === ExRPC.await(task, 1000)
  end

  test "Async with process throw on local node" do
    task = ExRPC.async(master, :erlang, :apply, [fn() -> throw(:throwMaster) end, []])
    assert :throwmaster === ExRPC.await(task, 1000)
  end

  test "Async slave with process timeout on local node" do
    task = ExRPC.async(slave, :erlang, :apply, [fn() -> :timer.sleep(10000) end, []])
    assert {:badrpc, :timeout} === ExRPC.await(task, 1000)
  end

  test "Await cannot reuse reference" do
    task = ExRPC.async(slave, :erlang, :apply, [fn() -> throw(:throwSlave) end, []])

  end

  test "Async slave with process exit on remote node" do
    task = ExRPC.async(slave, :erlang, :apply, [fn() -> exit(:exitslave) end, []])
    assert :throwslave === ExRPC.await(task, 1000)
  end

  test "Async with process throw on remote node" do
    task = ExRPC.async(slave, :erlang, :apply, [fn() -> throw(:throwslave) end, []])
    assert :throwslave === ExRPC.await(task, 1000)
  end

  test "Async slave with process timeout on remote node" do
    task = ExRPC.async(slave, :erlang, :apply, [fn() -> :timer.sleep(10000) end, []])
    assert {:badrpc, :timeout} === ExRPC.await(task, 1000)
  end

end
