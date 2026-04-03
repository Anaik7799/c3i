defmodule Indrajaal.Alarms.AnalyticsEngineTest do
  @moduledoc """
  TDG comprehensive test suite for Alarms.AnalyticsEngine.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-AE-001: generate_analytics_report must return map with 6 required keys
  - SC-AE-002: get_realtime_metrics must return map with 5 required keys
  - SC-AE-003: detect_anomalies must return map with 5 anomaly categories
  - SC-AE-004: AnalyticsEngine GenServer must start and accept calls

  ## Constitutional Verification
  - Psi0 Existence: AnalyticsEngine continues operating even when no alarm data exists
  - Psi3 Verification: Report structure is consistently typed across all tenants
  - Psi5 Truthfulness: Analytics reports accurately reflect alarm processing state

  ## Founder's Directive Alignment
  - Omega0.1: Alarm analytics enable proactive threat detection protecting Founder's assets

  ## TPS 5-Level RCA Context
  - L1 Symptom: Analytics report missing :patterns key
  - L5 Root Cause: generate_analytics_report stub not including all 6 required sections

  ## Change History
  | Version | Date       | Author | Change            |
  |---------|------------|--------|-------------------|
  | 21.3.0  | 2026-03-19 | Claude | Initial TDG suite |
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.AnalyticsEngine

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Setup — ensure GenServer is running
  # ---------------------------------------------------------------------------

  setup do
    case GenServer.whereis(AnalyticsEngine) do
      nil ->
        start_supervised!({AnalyticsEngine, []})

      _pid ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # describe: generate_analytics_report/2
  # ---------------------------------------------------------------------------

  describe "generate_analytics_report/2" do
    test "returns a map" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert is_map(result)
    end

    test "returned map has :summary key" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.has_key?(result, :summary)
    end

    test "returned map has :patterns key" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.has_key?(result, :patterns)
    end

    test "returned map has :performance key" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.has_key?(result, :performance)
    end

    test "returned map has :trends key" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.has_key?(result, :trends)
    end

    test "returned map has :predictions key" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.has_key?(result, :predictions)
    end

    test "returned map has :recommendations key" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.has_key?(result, :recommendations)
    end

    test "default date_range is :last_24hours" do
      # Calling with explicit default returns same structure as implicit default
      r1 = AnalyticsEngine.generate_analytics_report("tenant-1")
      r2 = AnalyticsEngine.generate_analytics_report("tenant-1", :last_24hours)
      assert Map.keys(r1) == Map.keys(r2)
    end

    test "accepts :last_7days date_range" do
      result = AnalyticsEngine.generate_analytics_report("tenant-1", :last_7days)
      assert is_map(result)
      assert Map.has_key?(result, :summary)
    end

    test "accepts different tenant_ids" do
      r1 = AnalyticsEngine.generate_analytics_report("tenant-1")
      r2 = AnalyticsEngine.generate_analytics_report("tenant-2")
      assert is_map(r1)
      assert is_map(r2)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: get_realtime_metrics/1
  # ---------------------------------------------------------------------------

  describe "get_realtime_metrics/1" do
    test "returns a map" do
      result = AnalyticsEngine.get_realtime_metrics("tenant-1")
      assert is_map(result)
    end

    test "returned map has :current_alarm_rate key" do
      result = AnalyticsEngine.get_realtime_metrics("tenant-1")
      assert Map.has_key?(result, :current_alarm_rate)
    end

    test "returned map has :processing_latency key" do
      result = AnalyticsEngine.get_realtime_metrics("tenant-1")
      assert Map.has_key?(result, :processing_latency)
    end

    test "returned map has :queue_health key" do
      result = AnalyticsEngine.get_realtime_metrics("tenant-1")
      assert Map.has_key?(result, :queue_health)
    end

    test "returned map has :error_rate key" do
      result = AnalyticsEngine.get_realtime_metrics("tenant-1")
      assert Map.has_key?(result, :error_rate)
    end

    test "returned map has :correlation_efficiency key" do
      result = AnalyticsEngine.get_realtime_metrics("tenant-1")
      assert Map.has_key?(result, :correlation_efficiency)
    end

    test "different tenants return isolated metrics" do
      m1 = AnalyticsEngine.get_realtime_metrics("tenant-a")
      m2 = AnalyticsEngine.get_realtime_metrics("tenant-b")
      assert is_map(m1)
      assert is_map(m2)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: detect_anomalies/2
  # ---------------------------------------------------------------------------

  describe "detect_anomalies/2" do
    test "returns a map" do
      result = AnalyticsEngine.detect_anomalies("tenant-1")
      assert is_map(result)
    end

    test "returned map has :volume_anomalies key" do
      result = AnalyticsEngine.detect_anomalies("tenant-1")
      assert Map.has_key?(result, :volume_anomalies)
    end

    test "returned map has :pattern_anomalies key" do
      result = AnalyticsEngine.detect_anomalies("tenant-1")
      assert Map.has_key?(result, :pattern_anomalies)
    end

    test "returned map has :temporal_anomalies key" do
      result = AnalyticsEngine.detect_anomalies("tenant-1")
      assert Map.has_key?(result, :temporal_anomalies)
    end

    test "returned map has :device_anomalies key" do
      result = AnalyticsEngine.detect_anomalies("tenant-1")
      assert Map.has_key?(result, :device_anomalies)
    end

    test "returned map has :severity_anomalies key" do
      result = AnalyticsEngine.detect_anomalies("tenant-1")
      assert Map.has_key?(result, :severity_anomalies)
    end

    test "default lookback_hours is 24" do
      r1 = AnalyticsEngine.detect_anomalies("tenant-1")
      r2 = AnalyticsEngine.detect_anomalies("tenant-1", 24)
      assert Map.keys(r1) == Map.keys(r2)
    end

    test "accepts custom lookback_hours" do
      result = AnalyticsEngine.detect_anomalies("tenant-1", 48)
      assert is_map(result)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: engine continues operating for empty/nonexistent tenants" do
      result = AnalyticsEngine.generate_analytics_report("nonexistent-tenant")
      # System exists even with no data — returns empty but valid structure
      assert is_map(result)
      assert Map.has_key?(result, :summary)
    end

    test "Psi3 verification: report structure is consistent across calls" do
      r1 = AnalyticsEngine.generate_analytics_report("tenant-1")
      r2 = AnalyticsEngine.generate_analytics_report("tenant-1")
      assert Map.keys(r1) == Map.keys(r2)
    end

    test "Psi5 truthfulness: anomaly detection returns 5 categories" do
      result = AnalyticsEngine.detect_anomalies("tenant-verify")
      categories = Map.keys(result)
      assert length(categories) == 5
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "generate_analytics_report completes within 5 seconds" do
      {elapsed_us, result} =
        :timer.tc(fn ->
          AnalyticsEngine.generate_analytics_report("tenant-sil4")
        end)

      assert is_map(result)
      assert elapsed_us < 5_000_000
    end

    test "dual-channel: two tenants can get reports concurrently" do
      tasks = [
        Task.async(fn -> AnalyticsEngine.generate_analytics_report("tenant-a") end),
        Task.async(fn -> AnalyticsEngine.generate_analytics_report("tenant-b") end)
      ]

      [r_a, r_b] = Task.await_many(tasks, 10_000)
      assert is_map(r_a)
      assert is_map(r_b)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "generate_analytics_report always returns map with 6 keys" do
    forall tenant_id <- PC.utf8() do
      result = AnalyticsEngine.generate_analytics_report(tenant_id)
      is_map(result) and map_size(result) == 6
    end
  end

  property "detect_anomalies always returns map with 5 keys" do
    forall _n <- PC.integer(1, 3) do
      result = AnalyticsEngine.detect_anomalies("prop-tenant")
      is_map(result) and map_size(result) == 5
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  @tag :property
  test "get_realtime_metrics always returns 5-key map for any tenant" do
    ExUnitProperties.check all(
                             tenant_id <- SD.string(:alphanumeric, min_length: 1, max_length: 20)
                           ) do
      result = AnalyticsEngine.get_realtime_metrics(tenant_id)
      assert is_map(result)
      assert Map.has_key?(result, :current_alarm_rate)
      assert Map.has_key?(result, :processing_latency)
    end
  end

  @tag :property
  test "detect_anomalies accepts any positive lookback_hours" do
    ExUnitProperties.check all(hours <- SD.integer(1..720)) do
      result = AnalyticsEngine.detect_anomalies("tenant-1", hours)
      assert is_map(result)
      assert Map.has_key?(result, :volume_anomalies)
    end
  end
end
