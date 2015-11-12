defmodule ExRPC.Test.Moduledoc do
  use ExUnit.Case

  import ExRPC.Test.Helper

  setup_all do
    ExRPC.Test.Helper.start_slave_node()
    on_exit fn() ->
      ExRPC.Test.Helper.stop_slave_node()
    end
    :ok
  end


  doctest ExRPC

end
