defmodule ExRPC.Test.Functional.Cast do
  use ExUnit.Case

  import ExRPC.Test.Helper

  setup_all do
    ExRPC.Test.Helper.start_slave_node()
    on_exit fn() ->
      ExRPC.Test.Helper.stop_slave_node()
    end
    :ok
  end

  test "Cast" do
    assert true = ExRPC.cast(slave, :os, :timestamp, [])
  end

  test "Cast with invalid function" do
    assert true = ExRPC.cast(slave, :os, :timestamp_undef, [])
  end

  test "Cast on invalid node" do
    assert true = ExRPC.cast(invalid, :os, :timestamp, [])
  end

  test "Cast with process exit" do
    assert true = ExRPC.cast(slave, :erlang, :apply, [fn() -> exit(:die) end, []])
  end

  test "Call local with process throw" do
    assert true =
      ExRPC.cast(master, :erlang, :apply, [fn() -> throw(:throwMaster) end, []])
  end

  test "Call slave with process exit" do
    assert true  =
      ExRPC.cast(slave, :erlang, :apply, [fn() -> throw(:throwSlave) end, []])
  end

end
