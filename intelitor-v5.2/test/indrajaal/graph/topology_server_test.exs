defmodule Indrajaal.Graph.TopologyServerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Graph.TopologyServer

  test "module exists" do
    assert Code.ensure_loaded?(TopologyServer)
  end

  test "start_link/1 is exported" do
    assert function_exported?(TopologyServer, :start_link, 1)
  end

  test "get_state/0 is exported" do
    assert function_exported?(TopologyServer, :get_state, 0)
  end

  test "update_graph/2 is exported" do
    assert function_exported?(TopologyServer, :update_graph, 2)
  end
end
