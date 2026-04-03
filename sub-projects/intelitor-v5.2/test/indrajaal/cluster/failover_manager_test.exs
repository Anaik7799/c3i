defmodule Indrajaal.Cluster.FailoverManagerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.FailoverManager

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(FailoverManager)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(FailoverManager, :start_link, 1)
    end

    test "defines cluster_status/0" do
      assert function_exported?(FailoverManager, :cluster_status, 0)
    end

    test "defines register_critical_process/2" do
      assert function_exported?(FailoverManager, :register_critical_process, 2)
    end

    test "defines unregister_critical_process/1" do
      assert function_exported?(FailoverManager, :unregister_critical_process, 1)
    end

    test "defines trigger_failover/1" do
      assert function_exported?(FailoverManager, :trigger_failover, 1)
    end

    test "defines has_quorum?/0" do
      assert function_exported?(FailoverManager, :has_quorum?, 0)
    end

    test "defines failover_mode/0" do
      assert function_exported?(FailoverManager, :failover_mode, 0)
    end

    test "defines set_failover_mode/1" do
      assert function_exported?(FailoverManager, :set_failover_mode, 1)
    end

    test "defines min_nodes_for_ha/0" do
      assert function_exported?(FailoverManager, :min_nodes_for_ha, 0)
    end
  end

  describe "constants" do
    test "min_nodes_for_ha returns 3" do
      assert FailoverManager.min_nodes_for_ha() == 3
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(FailoverManager, :child_spec, 1)
    end
  end
end
