defmodule Indrajaal.Cluster.SwarmTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Swarm

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Swarm)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(Swarm, :start_link, 1)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(Swarm, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = Swarm.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
