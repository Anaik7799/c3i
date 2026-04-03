defmodule Indrajaal.Cockpit.Prajna.TelemetryDisplayTest do
  @moduledoc """
  TDG-Compliant Tests for TelemetryDisplay Module.

  STAMP Compliance: SC-HMI-003, SC-TEL-001, SC-TEL-002, SC-TEL-003
  TDG: Dual property testing with PropCheck + ExUnitProperties
  """
  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.TelemetryDisplay

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Trend Analysis
  # ═══════════════════════════════════════════════════════════════════════════

  describe "get_trend/1" do
    test "returns :unknown for insufficient data" do
      assert TelemetryDisplay.get_trend([]) == :unknown
      assert TelemetryDisplay.get_trend([50]) == :unknown
    end

    test "detects rising trend" do
      # Values list is newest-first: newest=60, oldest=50 → rising
      values = [60, 58, 56, 54, 52, 50]
      assert TelemetryDisplay.get_trend(values) in [:rising, :rising_fast]
    end

    test "detects falling trend" do
      # Values list is newest-first: newest=50, oldest=60 → falling
      values = [50, 52, 54, 56, 58, 60]
      assert TelemetryDisplay.get_trend(values) in [:falling, :falling_fast]
    end

    test "detects stable trend" do
      values = [50, 50, 50, 50, 50]
      assert TelemetryDisplay.get_trend(values) == :stable
    end

    test "handles zero oldest value" do
      # Values list is newest-first, so oldest (last) = 0
      # When oldest value is 0, returns :unknown
      values = [20, 10, 0]
      assert TelemetryDisplay.get_trend(values) == :unknown
    end
  end

  describe "trend_icon/1" do
    test "returns correct icons for each trend" do
      assert TelemetryDisplay.trend_icon(:rising_fast) == "↑↑"
      assert TelemetryDisplay.trend_icon(:rising) == "↑"
      assert TelemetryDisplay.trend_icon(:stable) == "→"
      assert TelemetryDisplay.trend_icon(:falling) == "↓"
      assert TelemetryDisplay.trend_icon(:falling_fast) == "↓↓"
      assert TelemetryDisplay.trend_icon(:unknown) == "?"
    end
  end

  describe "trend_class/1" do
    test "returns CSS classes for trends" do
      assert TelemetryDisplay.trend_class(:rising_fast) == "text-red-500"
      assert TelemetryDisplay.trend_class(:rising) == "text-amber-500"
      assert TelemetryDisplay.trend_class(:stable) == "text-gray-500"
      assert TelemetryDisplay.trend_class(:falling) == "text-cyan-500"
      assert TelemetryDisplay.trend_class(:falling_fast) == "text-blue-500"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Staleness Detection (SC-HMI-003)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "staleness_class/1" do
    test "classifies fresh data (< 5s)" do
      assert TelemetryDisplay.staleness_class(0) == :fresh
      assert TelemetryDisplay.staleness_class(4.9) == :fresh
    end

    test "classifies stale data (5-30s)" do
      assert TelemetryDisplay.staleness_class(5.0) == :stale
      assert TelemetryDisplay.staleness_class(15) == :stale
      assert TelemetryDisplay.staleness_class(29) == :stale
    end

    test "classifies very stale data (> 30s)" do
      assert TelemetryDisplay.staleness_class(30) == :very_stale
      assert TelemetryDisplay.staleness_class(100) == :very_stale
    end
  end

  describe "staleness_css/1" do
    test "returns CSS classes for staleness" do
      assert TelemetryDisplay.staleness_css(1) == ""
      assert TelemetryDisplay.staleness_css(10) == "opacity-60"
      assert TelemetryDisplay.staleness_css(60) == "opacity-30"
    end
  end

  describe "status_icon/1" do
    test "returns correct status icons" do
      assert TelemetryDisplay.status_icon(1) == "●"
      assert TelemetryDisplay.status_icon(10) == "◐"
      assert TelemetryDisplay.status_icon(60) == "○"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Sparkline Rendering
  # ═══════════════════════════════════════════════════════════════════════════

  describe "render_sparkline/2" do
    test "renders empty values as placeholder" do
      result = TelemetryDisplay.render_sparkline([], 10)
      assert result == "░░░░░░░░░░"
    end

    test "renders values as sparkline characters" do
      values = [10, 30, 50, 70, 90]
      result = TelemetryDisplay.render_sparkline(values, 5)

      assert String.length(result) == 5
      # Should contain sparkline chars
      assert String.match?(result, ~r/[▁▂▃▄▅▆▇█░]+/)
    end

    test "pads shorter data with placeholders" do
      values = [50, 60, 70]
      result = TelemetryDisplay.render_sparkline(values, 10)

      assert String.length(result) == 10
    end
  end

  describe "render_colored_sparkline/3" do
    test "returns sparkline with color class" do
      values = [50, 60, 70]
      {sparkline, color} = TelemetryDisplay.render_colored_sparkline(values, 10, :warning)

      assert is_binary(sparkline)
      assert is_binary(color)
      assert String.contains?(color, "text-red")
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UNIT TESTS - Gauge Rendering
  # ═══════════════════════════════════════════════════════════════════════════

  describe "render_gauge/3" do
    test "renders empty gauge for zero" do
      result = TelemetryDisplay.render_gauge(0, 100, 10)
      assert result == "░░░░░░░░░░"
    end

    test "renders full gauge for max" do
      result = TelemetryDisplay.render_gauge(100, 100, 10)
      assert result == "▓▓▓▓▓▓▓▓▓▓"
    end

    test "renders partial gauge" do
      result = TelemetryDisplay.render_gauge(50, 100, 10)
      assert String.length(result) == 10
      assert String.contains?(result, "▓")
      assert String.contains?(result, "░")
    end

    test "caps at max value" do
      result = TelemetryDisplay.render_gauge(150, 100, 10)
      assert result == "▓▓▓▓▓▓▓▓▓▓"
    end
  end

  describe "render_gauge_with_info/5" do
    test "returns complete gauge info" do
      result = TelemetryDisplay.render_gauge_with_info("cpu", 75, 100, [70, 72, 74, 75], 10)

      assert Map.has_key?(result, :gauge)
      assert Map.has_key?(result, :percent)
      assert Map.has_key?(result, :trend)
      assert Map.has_key?(result, :trend_icon)
      assert Map.has_key?(result, :trend_class)

      assert result.percent == 75
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - PropCheck (PC)
  # ═══════════════════════════════════════════════════════════════════════════

  property "sparkline length matches requested width" do
    forall {values, width} <- {PC.list(PC.float()), PC.range(1, 50)} do
      result = TelemetryDisplay.render_sparkline(values, width)
      String.length(result) == width
    end
  end

  property "gauge length matches requested width" do
    forall {value, width} <- {PC.float(0.0, 100.0), PC.range(1, 50)} do
      result = TelemetryDisplay.render_gauge(value, 100, width)
      String.length(result) == width
    end
  end

  property "staleness_class is deterministic" do
    forall seconds <- PC.float(0.0, 1000.0) do
      r1 = TelemetryDisplay.staleness_class(seconds)
      r2 = TelemetryDisplay.staleness_class(seconds)
      r1 == r2
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PROPERTY TESTS - ExUnitProperties (SD)
  # ═══════════════════════════════════════════════════════════════════════════

  test "trend is one of expected values (property)" do
    test_values = [
      [],
      [50.0],
      [10.0, 20.0, 30.0],
      [30.0, 20.0, 10.0],
      [50.0, 50.0, 50.0],
      [10.0, 30.0, 50.0, 70.0, 90.0],
      Enum.map(1..20, fn _ -> :rand.uniform() * 100 end)
    ]

    for values <- test_values do
      trend = TelemetryDisplay.get_trend(values)
      assert trend in [:unknown, :rising_fast, :rising, :stable, :falling, :falling_fast]
    end
  end

  test "staleness classification is consistent (property)" do
    for seconds <- [0.0, 2.5, 4.9, 5.0, 15.0, 29.9, 30.0, 50.0, 100.0] do
      class = TelemetryDisplay.staleness_class(seconds)

      cond do
        seconds < 5.0 -> assert class == :fresh
        seconds < 30 -> assert class == :stale
        true -> assert class == :very_stale
      end
    end
  end
end
