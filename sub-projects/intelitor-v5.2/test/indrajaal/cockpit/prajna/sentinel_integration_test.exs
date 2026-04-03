defmodule Indrajaal.Cockpit.Prajna.SentinelIntegrationTest do
  @moduledoc """
  TDG tests for Indrajaal.Cockpit.Prajna.SentinelIntegration.

  ## STAMP Safety Integration
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-IMMUNE-INTEG-001: Real-time threat tracking
  - SC-CLU-INTEG-001: Real-time quorum monitoring

  ## TPS 5-Level RCA Context
  - L1 Symptom: Sentinel data not visible in cockpit
  - L5 Root Cause: SentinelIntegration GenServer not syncing
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif

  alias Indrajaal.Cockpit.Prajna.SentinelIntegration

  describe "start_link/1" do
    test "starts GenServer successfully" do
      test_name = :"sentinel_integ_#{System.unique_integer()}"
      assert {:ok, pid} = start_supervised({SentinelIntegration, [name: test_name]})
      assert Process.alive?(pid)
    end
  end

  describe "initial state" do
    test "cluster_status starts with unknown status" do
      test_name = :"sentinel_cluster_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({SentinelIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert state.cluster_status.status == :unknown
    end

    test "cluster_status has_quorum starts false" do
      test_name = :"sentinel_quorum_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({SentinelIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert state.cluster_status.has_quorum == false
    end

    test "mara_stats starts with zero attacks" do
      test_name = :"sentinel_mara_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({SentinelIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert state.mara_stats.total_attacks == 0
    end

    test "active_threats starts as empty list" do
      test_name = :"sentinel_threats_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({SentinelIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert state.active_threats == []
    end

    test "last_sync starts as nil" do
      test_name = :"sentinel_sync_#{System.unique_integer()}"
      {:ok, pid} = start_supervised({SentinelIntegration, [name: test_name]})

      state = :sys.get_state(pid)
      assert is_nil(state.last_sync)
    end
  end

  describe "get_status/0" do
    test "is exported" do
      assert function_exported?(SentinelIntegration, :get_status, 0)
    end
  end

  describe "GenServer behaviour" do
    test "implements GenServer" do
      behaviours = SentinelIntegration.__info__(:attributes)[:behaviour] || []
      assert GenServer in behaviours
    end
  end
end
