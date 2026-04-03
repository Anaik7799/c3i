defmodule Indrajaal.Cockpit.Prajna.SmartMetricsTest do
  @moduledoc """
  Tests for PRAJNA Smart Metrics Engine

  WHAT: Verifies ETS-backed metric collection, trend analysis, and staleness detection.

  WHY: Ensures real-time metric aggregation works correctly for safety-critical monitoring.

  CONSTRAINTS:
    - SC-C3I-001: Data-centric architecture validation
    - SC-HMI-002: Trend vectors must be displayed
    - SC-HMI-003: Staleness visual decay
    - TDG-PRAJNA-002: Metrics engine must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-C3I-001, SC-HMI-002, SC-HMI-003 |
  """

  use ExUnit.Case, async: false
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  setup do
    # Start the SmartMetrics GenServer for each test
    {:ok, pid} = SmartMetrics.start_link([])

    on_exit(fn ->
      try do
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, pid: pid}
  end

  describe "record/4" do
    test "records a new metric" do
      SmartMetrics.record("test.cpu", "CPU", 75.0)
      Process.sleep(50)

      metric = SmartMetrics.get("test.cpu")
      assert metric != nil
      assert metric.label == "CPU"
      assert metric.value == 75.0
    end

    test "records metric with unit and thresholds" do
      SmartMetrics.record("test.memory", "Memory", 80.0,
        unit: "%",
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      Process.sleep(50)

      metric = SmartMetrics.get("test.memory")
      assert metric.unit == "%"
      assert metric.thresholds.caution_high == 75.0
    end

    test "updates existing metric" do
      SmartMetrics.record("test.latency", "Latency", 100.0)
      Process.sleep(50)
      SmartMetrics.record("test.latency", "Latency", 150.0)
      Process.sleep(50)

      metric = SmartMetrics.get("test.latency")
      assert metric.value == 150.0
      assert metric.previous_value == 100.0
    end

    test "calculates trend on update" do
      SmartMetrics.record("test.trend", "Trend Test", 100.0)
      Process.sleep(50)
      # 5% increase for :rising (not :rising_fast)
      SmartMetrics.record("test.trend", "Trend Test", 105.0)
      Process.sleep(50)

      metric = SmartMetrics.get("test.trend")
      assert metric.trend == :rising
    end
  end

  describe "get/1" do
    test "returns nil for non-existent metric" do
      metric = SmartMetrics.get("nonexistent")
      assert metric == nil
    end

    test "returns metric for existing key" do
      SmartMetrics.record("existing", "Existing", 42.0)
      Process.sleep(50)

      metric = SmartMetrics.get("existing")
      assert metric.value == 42.0
    end
  end

  describe "all/0" do
    test "returns all recorded metrics" do
      SmartMetrics.record("metric1", "Metric 1", 10.0)
      SmartMetrics.record("metric2", "Metric 2", 20.0)
      SmartMetrics.record("metric3", "Metric 3", 30.0)
      Process.sleep(50)

      all = SmartMetrics.all()
      assert length(all) >= 3

      ids = Enum.map(all, fn {id, _} -> id end)
      assert "metric1" in ids
      assert "metric2" in ids
      assert "metric3" in ids
    end
  end

  describe "stale_metrics/0" do
    test "returns empty list when no stale metrics" do
      SmartMetrics.record("fresh", "Fresh", 50.0)
      Process.sleep(50)

      stale = SmartMetrics.stale_metrics()
      fresh_ids = Enum.map(stale, fn {id, _} -> id end)
      refute "fresh" in fresh_ids
    end
  end

  describe "alarmed_metrics/0" do
    test "returns empty list when no alarmed metrics" do
      SmartMetrics.record("normal", "Normal", 50.0)
      Process.sleep(50)

      alarmed = SmartMetrics.alarmed_metrics()
      normal_ids = Enum.map(alarmed, fn {id, _} -> id end)
      refute "normal" in normal_ids
    end

    test "returns metrics in alarm state" do
      SmartMetrics.record("alarmed", "Alarmed", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      Process.sleep(50)

      alarmed = SmartMetrics.alarmed_metrics()
      alarmed_ids = Enum.map(alarmed, fn {id, _} -> id end)
      assert "alarmed" in alarmed_ids
    end
  end

  describe "health_summary/0" do
    test "returns summary with zero metrics" do
      SmartMetrics.clear()
      Process.sleep(50)

      summary = SmartMetrics.health_summary()

      assert Map.has_key?(summary, :status)
      assert Map.has_key?(summary, :total_metrics)
      assert Map.has_key?(summary, :health_score)
    end

    test "returns healthy status for normal metrics" do
      SmartMetrics.clear()
      SmartMetrics.record("healthy1", "Healthy 1", 50.0)
      SmartMetrics.record("healthy2", "Healthy 2", 60.0)
      Process.sleep(50)

      summary = SmartMetrics.health_summary()
      assert summary.status == :healthy
      assert summary.health_score == 100
    end

    test "returns degraded status for some alarmed metrics" do
      SmartMetrics.clear()
      SmartMetrics.record("ok1", "OK 1", 50.0)
      SmartMetrics.record("ok2", "OK 2", 60.0)

      SmartMetrics.record("alarm1", "Alarm 1", 95.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      Process.sleep(50)

      summary = SmartMetrics.health_summary()
      assert summary.status in [:degraded, :caution, :warning, :advisory]
      assert summary.alarmed_count >= 1
    end

    test "includes by_level breakdown" do
      SmartMetrics.clear()
      SmartMetrics.record("normal", "Normal", 50.0)

      SmartMetrics.record("caution", "Caution", 80.0,
        thresholds: %{caution_high: 75.0, warning_high: 90.0}
      )

      Process.sleep(50)

      summary = SmartMetrics.health_summary()
      assert Map.has_key?(summary, :by_level)
      assert Map.has_key?(summary.by_level, :normal)
      assert Map.has_key?(summary.by_level, :caution)
    end
  end

  describe "delete/1" do
    test "removes a metric" do
      SmartMetrics.record("to_delete", "To Delete", 100.0)
      Process.sleep(50)
      assert SmartMetrics.get("to_delete") != nil

      SmartMetrics.delete("to_delete")
      assert SmartMetrics.get("to_delete") == nil
    end
  end

  describe "clear/0" do
    test "removes all metrics" do
      SmartMetrics.record("m1", "M1", 10.0)
      SmartMetrics.record("m2", "M2", 20.0)
      SmartMetrics.record("m3", "M3", 30.0)
      Process.sleep(50)

      SmartMetrics.clear()
      all = SmartMetrics.all()
      assert all == []
    end
  end

  describe "trend calculation" do
    test "detects stable trend for zero change" do
      SmartMetrics.record("stable", "Stable", 50.0)
      Process.sleep(50)
      SmartMetrics.record("stable", "Stable", 50.0)
      Process.sleep(50)

      metric = SmartMetrics.get("stable")
      assert metric.trend == :stable
    end

    test "detects rising trend for small increase" do
      SmartMetrics.record("rising", "Rising", 100.0)
      Process.sleep(50)
      # 5% increase should be :rising
      SmartMetrics.record("rising", "Rising", 105.0)
      Process.sleep(50)

      metric = SmartMetrics.get("rising")
      assert metric.trend == :rising
    end

    test "detects rising_fast trend for large increase" do
      SmartMetrics.record("fast", "Fast", 50.0)
      Process.sleep(50)
      # 50% increase should be :rising_fast
      SmartMetrics.record("fast", "Fast", 75.0)
      Process.sleep(50)

      metric = SmartMetrics.get("fast")
      assert metric.trend == :rising_fast
    end

    test "detects falling trend for small decrease" do
      SmartMetrics.record("falling", "Falling", 100.0)
      Process.sleep(50)
      # 5% decrease should be :falling
      SmartMetrics.record("falling", "Falling", 95.0)
      Process.sleep(50)

      metric = SmartMetrics.get("falling")
      assert metric.trend == :falling
    end

    test "detects falling_fast trend for large decrease" do
      SmartMetrics.record("fast_fall", "Fast Fall", 50.0)
      Process.sleep(50)
      # 50% decrease should be :falling_fast
      SmartMetrics.record("fast_fall", "Fast Fall", 25.0)
      Process.sleep(50)

      metric = SmartMetrics.get("fast_fall")
      assert metric.trend == :falling_fast
    end
  end

  describe "sparkline history" do
    test "accumulates values in sparkline" do
      SmartMetrics.record("spark", "Spark", 10.0)
      Process.sleep(50)
      SmartMetrics.record("spark", "Spark", 20.0)
      Process.sleep(50)
      SmartMetrics.record("spark", "Spark", 30.0)
      Process.sleep(50)

      metric = SmartMetrics.get("spark")
      assert length(metric.sparkline) == 3
      assert 30.0 in metric.sparkline
    end
  end

  describe "property tests" do
    property "record/4 accepts valid metric names and stores them retrievably" do
      forall {metric_name, label, val} <-
               {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.float()} do
        m_str = String.slice(metric_name, 0..100)
        l_str = String.slice(label, 0..100)

        SmartMetrics.record(m_str, l_str, val)
        Process.sleep(50)

        retrieved = SmartMetrics.get(m_str)
        retrieved != nil and retrieved.value == val and retrieved.label == l_str
      end
    end

    property "all/0 always returns a list" do
      forall {m1, l1, v1, m2, l2, v2} <-
               {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.float(),
                PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8()), PC.float()} do
        m1_str = String.slice(m1, 0..50)
        m2_str = String.slice(m2, 0..50)

        SmartMetrics.record(m1_str, l1, v1)
        SmartMetrics.record(m2_str, l2, v2)
        Process.sleep(50)

        result = SmartMetrics.all()
        is_list(result)
      end
    end

    property "get/1 returns nil or a valid metric map" do
      forall metric_key <- PC.non_empty(PC.utf8()) do
        m_key = String.slice(metric_key, 0..50)

        result = SmartMetrics.get(m_key)

        result == nil or is_map(result)
      end
    end

    property "record/4 with floating point values maintains numeric type" do
      forall value <- PC.float() do
        SmartMetrics.record("prop_float_test", "Float Test", value)
        Process.sleep(50)

        metric = SmartMetrics.get("prop_float_test")

        metric != nil and is_float(metric.value) and metric.value == value
      end
    end

    property "recorded metrics can be deleted successfully" do
      forall {metric_id, val} <- {PC.non_empty(PC.utf8()), PC.float()} do
        m_id = String.slice(metric_id, 0..50)

        SmartMetrics.record(m_id, "Test", val)
        Process.sleep(50)
        SmartMetrics.delete(m_id)

        SmartMetrics.get(m_id) == nil
      end
    end
  end
end
