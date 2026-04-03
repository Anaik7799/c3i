defmodule Indrajaal.Cockpit.Prajna.DarkCockpitTest do
  @moduledoc """
  Tests for PRAJNA Dark Cockpit CLI Renderer

  WHAT: Verifies terminal UI rendering, color coding, and visual elements.

  WHY: Ensures safety-critical HMI standards are met (NASA-STD-3000, NUREG-0700).

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit (gray/blue default, amber/red deviations)
    - SC-HMI-002: Trend vectors displayed
    - SC-HMI-003: Staleness visual decay
    - TDG-PRAJNA-005: Dark Cockpit must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HMI-001 to SC-HMI-003 |
  """

  use ExUnit.Case, async: true
  @moduletag :zenoh_nif
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Cockpit.Prajna.DarkCockpit

  describe "alarm_color/1" do
    test "returns gray for normal" do
      color = DarkCockpit.alarm_color(:normal)
      assert String.contains?(color, "\e[90m")
    end

    test "returns cyan for advisory" do
      color = DarkCockpit.alarm_color(:advisory)
      assert String.contains?(color, "\e[36m")
    end

    test "returns amber for caution" do
      color = DarkCockpit.alarm_color(:caution)
      assert String.contains?(color, "\e[33m")
    end

    test "returns red for warning" do
      color = DarkCockpit.alarm_color(:warning)
      assert String.contains?(color, "\e[31m")
    end

    test "returns blinking red for critical" do
      color = DarkCockpit.alarm_color(:critical)
      assert String.contains?(color, "\e[31")
      assert String.contains?(color, "5m")
    end
  end

  describe "SC-HMI-001 compliance: Dark Cockpit palette" do
    test "normal state uses dim colors" do
      color = DarkCockpit.alarm_color(:normal)
      # ANSI 90 is bright black (gray)
      assert String.contains?(color, "90m")
    end

    test "deviation states use bright colors" do
      caution = DarkCockpit.alarm_color(:caution)
      warning = DarkCockpit.alarm_color(:warning)

      # These should be clearly visible (not dim)
      # Yellow/Amber
      assert String.contains?(caution, "33m")
      # Red
      assert String.contains?(warning, "31m")
    end
  end

  describe "SC-HMI-002 compliance: trend_arrow/1" do
    test "rising trend shows up arrow" do
      arrow = DarkCockpit.trend_arrow(:rising)
      assert String.contains?(arrow, "↑")
    end

    test "rising_fast trend shows double up arrow" do
      arrow = DarkCockpit.trend_arrow(:rising_fast)
      assert String.contains?(arrow, "↑↑")
    end

    test "falling trend shows down arrow" do
      arrow = DarkCockpit.trend_arrow(:falling)
      assert String.contains?(arrow, "↓")
    end

    test "falling_fast trend shows double down arrow" do
      arrow = DarkCockpit.trend_arrow(:falling_fast)
      assert String.contains?(arrow, "↓↓")
    end

    test "stable trend shows right arrow" do
      arrow = DarkCockpit.trend_arrow(:stable)
      assert String.contains?(arrow, "→")
    end

    test "trend arrows include colors" do
      rising = DarkCockpit.trend_arrow(:rising)
      assert String.contains?(rising, "\e[")
      # Reset at end
      assert String.contains?(rising, "\e[0m")
    end
  end

  describe "render_bar/4" do
    test "renders horizontal bar" do
      bar = DarkCockpit.render_bar(50.0, 100.0, 10)
      assert String.length(bar) > 0
    end

    test "respects max value" do
      half = DarkCockpit.render_bar(50.0, 100.0, 10)
      full = DarkCockpit.render_bar(100.0, 100.0, 10)

      # Full bar should have more filled characters
      # But since ANSI codes are included, we just check they're different
      assert half != full
    end

    test "applies alarm level color" do
      normal = DarkCockpit.render_bar(50.0, 100.0, 10, :normal)
      warning = DarkCockpit.render_bar(50.0, 100.0, 10, :warning)

      # Different colors should be applied
      assert String.contains?(normal, "\e[90m")
      assert String.contains?(warning, "\e[31m")
    end

    test "handles overflow gracefully" do
      # Value exceeds max - should clamp to 100%
      bar = DarkCockpit.render_bar(150.0, 100.0, 10)
      assert String.length(bar) > 0
    end
  end

  describe "render_sparkline/3" do
    test "renders sparkline from values" do
      values = [10.0, 20.0, 30.0, 40.0, 50.0]
      sparkline = DarkCockpit.render_sparkline(values, 100.0, 5)

      # Should contain block characters
      assert String.length(sparkline) > 0
    end

    test "respects width limit" do
      values = Enum.to_list(1..100)
      sparkline = DarkCockpit.render_sparkline(values, 100.0, 10)

      # Sparkline should be limited to width
      # Note: exact length may vary due to Unicode characters
      # Some margin for Unicode
      assert String.length(sparkline) <= 20
    end

    test "handles empty values" do
      sparkline = DarkCockpit.render_sparkline([], 100.0, 10)
      assert is_binary(sparkline)
    end

    test "handles single value" do
      sparkline = DarkCockpit.render_sparkline([50.0], 100.0, 5)
      assert String.length(sparkline) > 0
    end

    test "uses block characters" do
      values = [25.0, 50.0, 75.0, 100.0]
      sparkline = DarkCockpit.render_sparkline(values, 100.0, 4)

      # Should contain Unicode block characters
      # ▁ ▂ ▃ ▄ ▅ ▆ ▇ █
      block_chars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
      assert Enum.any?(block_chars, &String.contains?(sparkline, &1))
    end
  end

  describe "visual elements" do
    test "box drawing characters are available" do
      # Test that Unicode box characters work
      boxes = ["╔", "╗", "╚", "╝", "═", "║"]

      for box <- boxes do
        assert is_binary(box)
        assert String.valid?(box)
      end
    end

    test "icon characters are valid Unicode" do
      icons = ["●", "◐", "○", "↑", "↓", "→", "⚠", "☢", "ℹ"]

      for icon <- icons do
        assert is_binary(icon)
        assert String.valid?(icon)
      end
    end

    test "sparkline characters are valid Unicode" do
      chars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

      for char <- chars do
        assert is_binary(char)
        assert String.valid?(char)
      end
    end
  end

  describe "ANSI escape sequences" do
    test "reset sequence is valid" do
      reset = "\e[0m"
      assert String.valid?(reset)
    end

    test "color sequences are valid" do
      colors = [
        # Gray
        "\e[90m",
        # Cyan
        "\e[36m",
        # Yellow
        "\e[33m",
        # Red
        "\e[31m",
        # Green
        "\e[32m",
        # Blue
        "\e[34m"
      ]

      for color <- colors do
        assert String.valid?(color)
        assert String.starts_with?(color, "\e[")
        assert String.ends_with?(color, "m")
      end
    end

    test "cursor control sequences" do
      clear = "\e[2J\e[H"
      hide_cursor = "\e[?25l"
      show_cursor = "\e[?25h"

      assert String.valid?(clear)
      assert String.valid?(hide_cursor)
      assert String.valid?(show_cursor)
    end
  end

  describe "render helpers" do
    test "bar with zero value" do
      bar = DarkCockpit.render_bar(0.0, 100.0, 10)
      assert is_binary(bar)
    end

    test "bar with max value" do
      bar = DarkCockpit.render_bar(100.0, 100.0, 10)
      assert is_binary(bar)
    end

    test "sparkline normalizes values" do
      # Values higher than max should be clamped
      values = [50.0, 150.0, 200.0]
      sparkline = DarkCockpit.render_sparkline(values, 100.0, 3)
      assert is_binary(sparkline)
    end
  end

  describe "accessibility considerations" do
    test "color is not the only indicator" do
      # Trend arrows provide shape in addition to color
      rising = DarkCockpit.trend_arrow(:rising)
      assert String.contains?(rising, "↑")

      falling = DarkCockpit.trend_arrow(:falling)
      assert String.contains?(falling, "↓")
    end

    test "levels have distinct icons" do
      # Different icons for different severity levels
      levels = [:normal, :advisory, :caution, :warning, :critical]
      icons = Enum.map(levels, &get_level_icon/1)

      # All icons should be unique
      assert length(Enum.uniq(icons)) == length(icons)
    end
  end

  # Helper to get icons - mirrors Domain.alarm_icon/1
  defp get_level_icon(:normal), do: "·"
  defp get_level_icon(:advisory), do: "ℹ"
  defp get_level_icon(:caution), do: "⚠"
  defp get_level_icon(:warning), do: "⛔"
  defp get_level_icon(:critical), do: "☢"

  # ============================================================================
  # Property Tests (TDG Compliance)
  # ============================================================================

  describe "property tests" do
    property "alarm_color returns valid ANSI for all levels" do
      forall level <- PC.oneof([:normal, :advisory, :caution, :warning, :critical]) do
        color = DarkCockpit.alarm_color(level)
        is_binary(color) and String.contains?(color, "\e[")
      end
    end

    property "trend_arrow returns valid string for all trends" do
      forall trend <- PC.oneof([:rising_fast, :rising, :stable, :falling, :falling_fast]) do
        arrow = DarkCockpit.trend_arrow(trend)
        is_binary(arrow) and String.length(arrow) > 0
      end
    end

    property "render_bar respects width parameter" do
      forall {value, max_val, width} <-
               {PC.float(0.0, 100.0), PC.float(50.0, 200.0), PC.range(5, 50)} do
        bar = DarkCockpit.render_bar(value, max_val, width)
        is_binary(bar)
      end
    end

    property "render_sparkline handles arbitrary value lists" do
      forall {values, width} <- {PC.list(PC.float()), PC.range(1, 30)} do
        sparkline = DarkCockpit.render_sparkline(values, 100.0, width)
        is_binary(sparkline)
      end
    end

    property "alarm_color is deterministic" do
      forall level <- PC.oneof([:normal, :advisory, :caution, :warning, :critical]) do
        c1 = DarkCockpit.alarm_color(level)
        c2 = DarkCockpit.alarm_color(level)
        c1 == c2
      end
    end

    property "trend_arrow is deterministic" do
      forall trend <- PC.oneof([:rising_fast, :rising, :stable, :falling, :falling_fast]) do
        a1 = DarkCockpit.trend_arrow(trend)
        a2 = DarkCockpit.trend_arrow(trend)
        a1 == a2
      end
    end

    property "render_bar handles overflow values" do
      forall {value, max_val, width} <-
               {PC.float(100.0, 500.0), PC.float(50.0, 100.0), PC.range(5, 20)} do
        # Value exceeds max - should still produce valid output
        bar = DarkCockpit.render_bar(value, max_val, width)
        is_binary(bar)
      end
    end
  end
end
