defmodule Indrajaal.Cockpit.Prajna.DomainTest do
  @moduledoc """
  Tests for PRAJNA C3I Domain Types

  WHAT: Verifies core domain types, factory functions, and type constraints.

  WHY: Ensures type safety and correctness for safety-critical cockpit system.

  CONSTRAINTS:
    - SC-C3I-001: Data-centric architecture validation
    - TDG-PRAJNA-001: Domain types must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-C3I-001, TDG-PRAJNA-001 |
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias Indrajaal.Cockpit.Prajna.Domain
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  describe "create_smart_metric/3" do
    test "creates metric with default values" do
      metric = Domain.create_smart_metric("CPU", 75.5)

      assert metric.label == "CPU"
      assert metric.value == 75.5
      assert metric.previous_value == nil
      assert metric.trend == :stable
      assert metric.level == :normal
      assert metric.unit == ""
      assert metric.sparkline == []
      assert %DateTime{} = metric.last_updated
    end

    test "creates metric with custom unit" do
      metric = Domain.create_smart_metric("Memory", 80.0, unit: "%")

      assert metric.unit == "%"
      assert metric.value == 80.0
    end

    test "creates metric with thresholds" do
      thresholds = %{caution_high: 75.0, warning_high: 90.0}
      metric = Domain.create_smart_metric("Latency", 50.0, thresholds: thresholds)

      assert metric.thresholds == thresholds
      assert metric.level == :normal
    end
  end

  describe "update_metric/2" do
    test "updates value and maintains history" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      updated = Domain.update_metric(metric, 75.0)

      assert updated.value == 75.0
      assert updated.previous_value == 50.0
      assert Enum.member?(updated.sparkline, 75.0)
    end

    test "calculates rising trend for small increase" do
      metric = Domain.create_smart_metric("CPU", 100.0)
      # 5% increase (< 10%) should be :rising
      updated = Domain.update_metric(metric, 105.0)

      assert updated.trend == :rising
    end

    test "calculates rising_fast trend for large increase" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      # 50% increase (> 10%) should be :rising_fast
      updated = Domain.update_metric(metric, 75.0)

      assert updated.trend == :rising_fast
    end

    test "calculates falling trend for small decrease" do
      metric = Domain.create_smart_metric("CPU", 100.0)
      # 5% decrease (< 10%) should be :falling
      updated = Domain.update_metric(metric, 95.0)

      assert updated.trend == :falling
    end

    test "calculates falling_fast trend for large decrease" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      # 30% decrease (> 10%) should be :falling_fast
      updated = Domain.update_metric(metric, 35.0)

      assert updated.trend == :falling_fast
    end

    test "calculates stable trend for zero change" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      # 0% change should be :stable
      updated = Domain.update_metric(metric, 50.0)

      assert updated.trend == :stable
    end

    test "maintains sparkline with max 60 entries" do
      metric = Domain.create_smart_metric("CPU", 0.0)

      final =
        Enum.reduce(1..100, metric, fn i, m ->
          Domain.update_metric(m, i * 1.0)
        end)

      assert length(final.sparkline) == 60
    end
  end

  describe "evaluate_level/2" do
    test "returns normal when no thresholds" do
      metric = Domain.create_smart_metric("CPU", 95.0)
      level = Domain.evaluate_level(metric.value, metric.thresholds)

      assert level == :normal
    end

    test "returns caution when above caution_high" do
      thresholds = %{caution_high: 75.0, warning_high: 90.0}
      level = Domain.evaluate_level(80.0, thresholds)

      assert level == :caution
    end

    test "returns warning when above warning_high" do
      thresholds = %{caution_high: 75.0, warning_high: 90.0}
      level = Domain.evaluate_level(95.0, thresholds)

      assert level == :warning
    end

    test "returns caution when below caution_low" do
      thresholds = %{caution_low: 20.0, warning_low: 10.0}
      level = Domain.evaluate_level(15.0, thresholds)

      assert level == :caution
    end

    test "returns warning when below warning_low" do
      thresholds = %{caution_low: 20.0, warning_low: 10.0}
      level = Domain.evaluate_level(5.0, thresholds)

      assert level == :warning
    end
  end

  describe "stale?/1" do
    test "returns false for recent metric" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      refute Domain.stale?(metric)
    end

    test "returns true for old metric" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      old_metric = %{metric | last_updated: DateTime.add(DateTime.utc_now(), -10, :second)}

      assert Domain.stale?(old_metric)
    end

    test "respects custom timeout" do
      metric = Domain.create_smart_metric("CPU", 50.0)
      old_metric = %{metric | last_updated: DateTime.add(DateTime.utc_now(), -3, :second)}

      refute Domain.stale?(old_metric, 5)
      assert Domain.stale?(old_metric, 2)
    end
  end

  describe "create_cockpit_state/1" do
    test "creates initial state with operator" do
      state = Domain.create_cockpit_state("operator-1")

      assert state.operator_id == "operator-1"
      assert state.session_id != nil
      assert state.current_view == :overview
      assert state.monitor_only == false
      assert state.pending_commands == %{}
      assert state.command_history == []
      assert state.messages_received == 0
      assert %DateTime{} = state.started_at
    end
  end

  describe "create_insight/5" do
    test "creates insight with all fields" do
      insight =
        Domain.create_insight(
          :anomaly,
          :warning,
          "High CPU Detected",
          "CPU at 95% on node-01",
          0.92
        )

      assert insight.type == :anomaly
      assert insight.level == :warning
      assert insight.title == "High CPU Detected"
      assert insight.description == "CPU at 95% on node-01"
      assert insight.confidence == 0.92
      assert insight.id != nil
      assert %DateTime{} = insight.generated_at
    end
  end

  describe "critical_command?/1" do
    test "shutdown is critical" do
      assert Domain.critical_command?(:shutdown)
    end

    test "restart is critical" do
      assert Domain.critical_command?(:restart)
    end

    test "status is not critical" do
      refute Domain.critical_command?(:status)
    end

    test "unknown command is not critical" do
      refute Domain.critical_command?(:ping)
    end
  end

  describe "alarm_icon/1" do
    test "returns correct icons for each level" do
      assert Domain.alarm_icon(:normal) == "·"
      assert Domain.alarm_icon(:advisory) == "ℹ"
      assert Domain.alarm_icon(:caution) == "⚠"
      assert Domain.alarm_icon(:warning) == "⛔"
      assert Domain.alarm_icon(:critical) == "☢"
    end
  end

  describe "trend_icon/1" do
    test "returns correct icons for each trend" do
      assert Domain.trend_icon(:rising) == "↑"
      assert Domain.trend_icon(:rising_fast) == "↑↑"
      assert Domain.trend_icon(:falling) == "↓"
      assert Domain.trend_icon(:falling_fast) == "↓↓"
      assert Domain.trend_icon(:stable) == "→"
    end
  end

  describe "property tests" do
    property "alarm_icon/1 returns string for valid alarm levels" do
      alarm_levels = [:normal, :advisory, :caution, :warning, :critical]

      forall level <- PC.elements(alarm_levels) do
        icon = Domain.alarm_icon(level)
        is_binary(icon) and String.length(icon) > 0
      end
    end

    property "trend_icon/1 returns string for valid trend types" do
      trends = [:rising, :rising_fast, :falling, :falling_fast, :stable]

      forall trend <- PC.elements(trends) do
        icon = Domain.trend_icon(trend)
        is_binary(icon) and String.length(icon) > 0
      end
    end

    property "create_smart_metric/3 always returns a map" do
      forall {label, val} <- {PC.non_empty(PC.utf8()), PC.float()} do
        label_str = String.slice(label, 0..50)
        metric = Domain.create_smart_metric(label_str, val)

        is_map(metric) and Map.has_key?(metric, :label) and Map.has_key?(metric, :value)
      end
    end

    property "evaluate_level/2 returns valid level atom" do
      valid_levels = [:normal, :advisory, :caution, :warning, :critical]
      thresholds = %{caution_high: 75.0, warning_high: 90.0, caution_low: 20.0, warning_low: 10.0}

      forall value <- PC.float() do
        level = Domain.evaluate_level(value, thresholds)
        level in valid_levels
      end
    end

    property "create_cockpit_state/1 creates valid state map" do
      forall operator_id <- PC.non_empty(PC.utf8()) do
        operator_id = String.slice(operator_id, 0..50)
        state = Domain.create_cockpit_state(operator_id)

        (is_map(state) and
           state.operator_id == operator_id and
           Map.has_key?(state, :session_id) and
           Map.has_key?(state, :current_view) and
           is_list(state.pending_commands)) or is_map(state.pending_commands)
      end
    end
  end
end
