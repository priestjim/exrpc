defmodule ExRPC.Test.Functional.Call do
  use ExUnit.Case
  
  import ExRPC.Test.Helper

  setup_all do
    ExRPC.Test.Helper.start_slave_node()
    on_exit fn() ->
      ExRPC.Test.Helper.stop_slave_node()
    end
    :ok
  end

  test "Call on local node" do
    assert {_mega, _sec, _micro} = ExRPC.call(master, :os, :timestamp, [])
  end

  test "Call on local node mf" do
    assert ExRPC.Test.Helper.master = ExRPC.call(master, :erlang, :node, [])
  end

  test "Call on local node mfa" do
    assert [3,2,1] = ExRPC.call(master, :erlang, :apply, [Enum, :reverse, [[1, 2, 3]]])
  end


  test "Call on invalid node" do
    assert {:badrpc, :nodedown} = ExRPC.call(invalid, :os, :timestamp, [])
  end

  test "Call with valid eponymous function" do
    assert {_mega, _sec, _micro} = ExRPC.call(slave, :os, :timestamp, [], 1000)
  end

  test "Call with invalid eponymous function" do
    assert {:badrpc, {:'EXIT', {:undef, [{:os,:timestamp_undef, [], []}|_]}}} =
      ExRPC.call(slave, :os, :timestamp_undef, [])
  end

  test "Call with valid anonymous function" do
    assert {_,"call_anonymous_function"} =
      ExRPC.call(master, :erlang, :apply, [fn(a) -> {self(), a} end, ["call_anonymous_function"]])
  end

  test "Call with invalid anonymous function" do
    assert {:badrpc, {:'EXIT', {:undef, [{:erlang,:apply, _, _}|_]}}} =
      ExRPC.call(master, :erlang, :apply, [fn() -> :os.timestamp_undef() end])
  end

  test "Call with process exit" do
    assert {:badrpc, {:'EXIT', :die}} =
      ExRPC.call(master, :erlang, :apply, [fn() -> exit(:die) end, []])
  end

  test "Call local with process throw" do
    assert :throwMaster =
      ExRPC.call(master, :erlang, :apply, [fn() -> throw(:throwMaster) end, []])
  end

  test "Call with call timeout" do
    assert {:badrpc, :timeout} = ExRPC.call(slave, :timer, :sleep, [100], 1)
    # Wait for the remote process to die
    :timer.sleep(100)
  end

end
