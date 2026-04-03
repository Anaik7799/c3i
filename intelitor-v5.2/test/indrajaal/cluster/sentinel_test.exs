defmodule Indrajaal.Cluster.SentinelTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Sentinel

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Sentinel)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(Sentinel, :start_link, 1)
    end

    test "defines get_status/0" do
      assert function_exported?(Sentinel, :get_status, 0)
    end

    test "defines get_active_nodes/0" do
      assert function_exported?(Sentinel, :get_active_nodes, 0)
    end

    test "defines quorum_member?/1" do
      assert function_exported?(Sentinel, :quorum_member?, 1)
    end

    test "defines is_quorum_lost/0" do
      assert function_exported?(Sentinel, :is_quorum_lost, 0)
    end

    test "defines get_members/0" do
      assert function_exported?(Sentinel, :get_members, 0)
    end

    test "defines emergency_stop/1" do
      assert function_exported?(Sentinel, :emergency_stop, 1)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(Sentinel, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = Sentinel.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
