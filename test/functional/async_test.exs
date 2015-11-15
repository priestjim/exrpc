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
    assert true = ExRPC.cast(slave, :os, :timestamp, [])
  end

  test "Async on local node mf" do
    assert true= ExRPC.cast(master, :erlang, :node)
  end

  test "Async on local node mfa" do
    assert true = ExRPC.cast(master, Kernel, :send, [self, {:test, 'wawasing'}])
    receive do
        {:test, _} -> true
        msg ->  :erlang.error RuntimeError.exception(msg) 
    end
  end

  test "Async with invalid function" do
    assert true = ExRPC.cast(slave, :os, :timestamp_undef, [])
  end

  test "Async on invalid node" do
    assert true = ExRPC.cast(invalid, :os, :timestamp, [])
  end

  test "Async with process exit" do
    assert true = ExRPC.cast(slave, :erlang, :apply, [fn() -> exit(:die) end, []])
  end

  test "Async local with process throw" do
    assert true =
      ExRPC.cast(master, :erlang, :apply, [fn() -> throw(:throwMaster) end, []])
  end

  test "Async slave with process exit" do
    assert true  =
      ExRPC.cast(slave, :erlang, :apply, [fn() -> throw(:throwSlave) end, []])
  end

  test "Await cannot reuse reference" do
    assert true  =
      ExRPC.cast(slave, :erlang, :apply, [fn() -> throw(:throwSlave) end, []])
  end

  test "Async slave with process exit" do
    assert true  =
      ExRPC.cast(slave, :erlang, :apply, [fn() -> throw(:throwSlave) end, []])
  end

end
