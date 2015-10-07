defmodule ExRPC.Test.Functional.SafeCast do
  use ExUnit.Case

  @slave :'exrpc_slave@127.0.0.1'
  @invalid :'exrpc_invalid@127.0.0.1'

  setup_all do
    ExRPC.Test.Helper.start_slave_node()
    on_exit fn() ->
      ExRPC.Test.Helper.stop_slave_node()
    end
    :ok
  end

  test "Safe cast with invalid function" do
    assert true = ExRPC.safe_cast(@slave, :os, :timestamp_undef, [])
  end

  test "Safe cast with invalid node" do
    assert {:badrpc, :nodedown} = ExRPC.safe_cast(@invalid, :os, :timestamp, [])
  end

  test "Safe cast with process exit" do
    assert true = ExRPC.safe_cast(@slave, :erlang, :apply, [fn() -> exit(:die) end, []])
  end

  test "Call to slave node" do
    assert {_mega, _sec, _micro} = ExRPC.call(@slave, :os, :timestamp, [], 1000)
  end

end
