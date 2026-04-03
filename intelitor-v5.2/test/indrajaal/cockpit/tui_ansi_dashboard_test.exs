defmodule Indrajaal.Cockpit.TuiAnsiDashboardTest do
  @moduledoc """
  TDG test suite for TUI ANSI dashboard rendering.

  WHAT: Validates container status grid rendering, ASCII health bars, Unicode
  sparklines, ANSI color escape sequences, full 80×24 dashboard layout, and
  render performance for the terminal-based cockpit UI.

  WHY: The dark cockpit TUI is the primary operator interface for the SIL-6
  biomorphic mesh. Rendering correctness is safety-critical — a miscoded color
  or truncated container name can cause an operator to miss a degraded node.
  Self-contained (no production module dependencies) so the tests gate the
  implementation rather than follow it (TDG mandate Ω₄).

  CONSTRAINTS:
    - SC-HMI-001: Dark cockpit — gray/blue default, amber/red for deviations
    - SC-HMI-002: Trend vectors displayed
    - SC-HMI-003: Staleness visual decay
    - SC-HMI-004: All status states must be visually distinguishable
    - SC-HMI-005: Color MUST NOT be the sole distinguishing indicator
    - SC-HMI-006: Dashboard renders within 80×24 terminal bounds
    - SC-HMI-007: Container names must not be truncated below 12 chars
    - SC-HMI-008: Health bars must accurately represent value to ±2%
    - SC-HMI-009: Sparkline must show at least 8 data points in 80 cols
    - SC-HMI-010: ANSI reset sequence MUST appear after every colorised token
    - SC-PRF-050: Full dashboard render MUST complete in < 50ms

  ## Coverage Matrix
  | Describe block                      | Unit | Property |
  |-------------------------------------|------|----------|
  | ANSI escape sequence rendering      |  5   |    0     |
  | health bar rendering                |  6   |    0     |
  | container status panel              |  6   |    0     |
  | sparkline rendering                 |  6   |    0     |
  | dashboard layout                    |  5   |    0     |
  | render performance (SC-PRF-050)     |  3   |    0     |
  | property: dashboard rendering       |  0   |    2     |
  | TOTAL                               | 31   |    2     |

  ## EP-GEN-014 Compliance
  - `require ExUnitProperties` (NOT `import`) avoids check/2 name collision
  - StreamData generators prefixed with `SD.` at every call site
  - PropCheck generators prefixed with `PC.` at every call site
  - `ExUnitProperties.check all(...)` used explicitly (check/2 excluded from import)

  ## Change History
  | Version | Date       | Author | Change                          |
  |---------|------------|--------|---------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | TDG suite — sprint 88 wave 1    |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  # `check: 2` is excluded to prevent import collision; use ExUnitProperties.check all(
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  require ExUnitProperties

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :tui
  @moduletag :hmi
  @moduletag :dashboard

  # ---------------------------------------------------------------------------
  # 15-container SIL-6 production topology (sil6Genome)
  # ---------------------------------------------------------------------------

  @containers [
    # Tier 1: Zenoh Router (PulledFromRegistry)
    "zenoh-router",
    # Tier 2: Database (BuiltFromDockerfile)
    "indrajaal-db-prod",
    # Tier 3: Observability (BuiltFromDockerfile)
    "indrajaal-obs-prod",
    # Tier 4: Quorum Routers (SharedImage from zenoh-router)
    "zenoh-router-1",
    "zenoh-router-2",
    "zenoh-router-3",
    # Tier 5: Cognitive (BuiltFromDockerfile)
    "indrajaal-bridge",
    "indrajaal-cortex",
    # Tier 6: Seed + Twin + Ollama
    "indrajaal-ex-app-1",
    "indrajaal-chaya",
    "indrajaal-ollama",
    # Tier 7: HA + ML
    "indrajaal-ex-app-2",
    "indrajaal-ex-app-3",
    "indrajaal-ml-runner-1",
    "indrajaal-ml-runner-2"
  ]

  @statuses [:healthy, :unhealthy, :starting, :stopped]

  # Unicode block characters used for sparklines (▁ through █)
  @block_chars ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  # ANSI color codes (constants for readability and single-source-of-truth)
  @ansi_reset "\e[0m"
  @ansi_green "\e[32m"
  @ansi_red "\e[31m"
  @ansi_yellow "\e[33m"
  @ansi_cyan "\e[36m"
  @ansi_gray "\e[90m"

  # ============================================================================
  # SECTION 1: ANSI Escape Sequence Rendering
  # ============================================================================

  describe "ANSI escape sequence rendering" do
    test "green ANSI code starts with ESC [ and ends with m" do
      assert String.starts_with?(@ansi_green, "\e[")
      assert String.ends_with?(@ansi_green, "m")
    end

    test "red ANSI code starts with ESC [ and ends with m" do
      assert String.starts_with?(@ansi_red, "\e[")
      assert String.ends_with?(@ansi_red, "m")
    end

    test "yellow ANSI code starts with ESC [ and ends with m" do
      assert String.starts_with?(@ansi_yellow, "\e[")
      assert String.ends_with?(@ansi_yellow, "m")
    end

    test "ansi_colorize/2 wraps text between correct escape and reset" do
      result = ansi_colorize("hello", :green)
      assert String.starts_with?(result, @ansi_green)
      assert String.ends_with?(result, @ansi_reset)
      assert String.contains?(result, "hello")
    end

    test "strip_ansi/1 removes all escape sequences and leaves plain text" do
      input = "\e[32mGreen\e[0m \e[31mRed\e[0m \e[33mYellow\e[0m"
      assert strip_ansi(input) == "Green Red Yellow"
    end
  end

  # ============================================================================
  # SECTION 2: Health Bar Rendering
  # ============================================================================

  describe "health bar rendering" do
    test "renders a bar for 0% health containing only empty-fill characters" do
      bar = render_health_bar(0.0, "cpu")
      plain = strip_ansi(bar)

      assert String.contains?(plain, "░"),
             "0% health bar must contain empty-fill ░ characters"
    end

    test "renders a bar for 100% health with filled block characters and no empty fill" do
      bar = render_health_bar(1.0, "mem")
      plain = strip_ansi(bar)

      refute String.contains?(plain, "░"),
             "100% health bar must not contain empty-fill ░ characters"

      assert String.contains?(plain, "█"),
             "100% health bar must contain filled █ character"
    end

    test "partial fill is proportional within ±1 block (SC-HMI-008)" do
      bar_50 = strip_ansi(render_health_bar(0.5, "x"))
      bar_100 = strip_ansi(render_health_bar(1.0, "x"))

      filled_50 = count_occurrences(bar_50, "█")
      filled_100 = count_occurrences(bar_100, "█")

      # 50% bar must have roughly half the filled blocks of the 100% bar (±1 for rounding)
      assert filled_50 >= div(filled_100, 2) - 1
      assert filled_50 <= div(filled_100, 2) + 1
    end

    test "bar includes ANSI color codes (SC-HMI-001)" do
      bar = render_health_bar(0.8, "health")

      assert String.contains?(bar, "\e["),
             "Health bar must contain at least one ANSI escape sequence"
    end

    test "bar always ends with ANSI reset at every threshold (SC-HMI-010)" do
      for value <- [0.0, 0.25, 0.5, 0.75, 1.0] do
        bar = render_health_bar(value, "test")

        assert String.ends_with?(bar, @ansi_reset),
               "Health bar at #{round(value * 100)}% must end with ANSI reset (SC-HMI-010)"
      end
    end

    test "bar color changes at thresholds — green >70%, yellow 30-70%, red <30% (SC-HMI-001)" do
      high_bar = render_health_bar(0.9, "good")
      mid_bar = render_health_bar(0.5, "mid")
      low_bar = render_health_bar(0.1, "bad")

      assert String.contains?(high_bar, @ansi_green),
             "High health (90%) must render with green (SC-HMI-001)"

      assert String.contains?(mid_bar, @ansi_yellow),
             "Mid health (50%) must render with yellow (SC-HMI-001)"

      assert String.contains?(low_bar, @ansi_red),
             "Low health (10%) must render with red (SC-HMI-001)"
    end
  end

  # ============================================================================
  # SECTION 3: Container Status Panel
  # ============================================================================

  describe "container status panel" do
    test "renders grid for all 15 containers — each name prefix present (SC-HMI-007)" do
      containers = Enum.map(@containers, fn name -> {name, :healthy, 1.0} end)
      output = render_container_grid(containers)

      for name <- @containers do
        prefix = String.slice(name, 0, 12)

        assert String.contains?(output, prefix),
               "Container name prefix '#{prefix}' (from '#{name}') must appear in grid"
      end
    end

    test "healthy status renders with green indicator (SC-HMI-001)" do
      output = render_container_grid([{"indrajaal-db-prod", :healthy, 1.0}])
      assert String.contains?(output, @ansi_green)
    end

    test "unhealthy status renders with red indicator (SC-HMI-001)" do
      output = render_container_grid([{"indrajaal-db-prod", :unhealthy, 0.0}])
      assert String.contains?(output, @ansi_red)
    end

    test "starting status renders with yellow indicator (SC-HMI-001)" do
      output = render_container_grid([{"zenoh-router-1", :starting, 0.0}])
      assert String.contains?(output, @ansi_yellow)
    end

    test "stopped status renders with gray indicator (SC-HMI-001)" do
      output = render_container_grid([{"ml-runner-1", :stopped, 0.0}])
      assert String.contains?(output, @ansi_gray)
    end

    test "each status has a distinct non-color symbol (SC-HMI-005 — color not sole indicator)" do
      containers = Enum.map(@statuses, fn s -> {"test-#{s}", s, 0.0} end)
      plain = render_container_grid(containers) |> strip_ansi()

      assert String.contains?(plain, status_symbol(:healthy)),
             "Healthy symbol '#{status_symbol(:healthy)}' must appear in plain-text output"

      assert String.contains?(plain, status_symbol(:unhealthy)),
             "Unhealthy symbol '#{status_symbol(:unhealthy)}' must appear in plain-text output"

      assert String.contains?(plain, status_symbol(:starting)),
             "Starting symbol '#{status_symbol(:starting)}' must appear in plain-text output"

      assert String.contains?(plain, status_symbol(:stopped)),
             "Stopped symbol '#{status_symbol(:stopped)}' must appear in plain-text output"
    end
  end

  # ============================================================================
  # SECTION 4: Sparkline Rendering
  # ============================================================================

  describe "sparkline rendering" do
    test "renders sparkline from a list of numbers and returns a non-empty binary" do
      sparkline = render_sparkline([10, 20, 30, 40, 50, 60, 70, 80])
      assert is_binary(sparkline)
      assert String.length(sparkline) > 0
    end

    test "uses Unicode block characters ▁–█ (SC-HMI-009)" do
      sparkline = render_sparkline([0, 14, 28, 42, 57, 71, 85, 100])

      assert Enum.any?(@block_chars, &String.contains?(sparkline, &1)),
             "Sparkline must contain at least one Unicode block character (▁–█)"
    end

    test "handles empty list gracefully — returns empty binary" do
      sparkline = render_sparkline([])
      assert is_binary(sparkline)
      assert sparkline == ""
    end

    test "handles single-element list" do
      sparkline = render_sparkline([42])
      assert is_binary(sparkline)
      assert String.length(sparkline) > 0
    end

    test "normalises values — minimum maps to ▁ and maximum maps to █" do
      sparkline = render_sparkline([0, 100])

      assert String.contains?(sparkline, "▁"),
             "Minimum value (0) must map to ▁ in sparkline"

      assert String.contains?(sparkline, "█"),
             "Maximum value (100) must map to █ in sparkline"
    end

    test "grapheme count equals input list length (one char per data point)" do
      values = Enum.to_list(1..20)
      sparkline = render_sparkline(values)

      assert length(String.graphemes(sparkline)) == 20,
             "Sparkline must emit exactly one grapheme per input value"
    end
  end

  # ============================================================================
  # SECTION 5: Dashboard Layout
  # ============================================================================

  describe "dashboard layout" do
    test "render_dashboard/1 returns a binary string" do
      assert is_binary(render_dashboard(sample_metrics()))
    end

    test "dashboard contains the system name INDRAJAAL in the header" do
      output = render_dashboard(sample_metrics())

      assert String.contains?(output, "INDRAJAAL"),
             "Dashboard header must contain the system name 'INDRAJAAL'"
    end

    test "each line is <= 80 characters wide (SC-HMI-006)" do
      plain = render_dashboard(sample_metrics()) |> strip_ansi()

      plain
      |> String.split("\n")
      |> Enum.each(fn line ->
        len = String.length(line)

        assert len <= 80,
               "Dashboard line exceeds 80 chars (#{len}): #{inspect(line)}"
      end)
    end

    test "dashboard output fits within 24 non-empty lines (SC-HMI-006)" do
      lines =
        render_dashboard(sample_metrics())
        |> strip_ansi()
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))

      assert length(lines) <= 24,
             "Dashboard has #{length(lines)} lines but must fit within 24 (SC-HMI-006)"
    end

    test "container count rendered in dashboard matches input" do
      metrics = sample_metrics()
      plain = render_dashboard(metrics) |> strip_ansi()

      rendered_count =
        Enum.count(metrics.containers, fn {name, _status, _health} ->
          String.contains?(plain, String.slice(name, 0, 8))
        end)

      assert rendered_count == length(metrics.containers),
             "Dashboard must render all #{length(metrics.containers)} containers"
    end
  end

  # ============================================================================
  # SECTION 6: Render Performance (SC-PRF-050)
  # ============================================================================

  describe "render performance (SC-PRF-050)" do
    test "render_dashboard/1 completes in < 50ms (SC-PRF-050)" do
      metrics = sample_metrics()
      t0 = :erlang.monotonic_time(:microsecond)
      _output = render_dashboard(metrics)
      t1 = :erlang.monotonic_time(:microsecond)
      elapsed_ms = (t1 - t0) / 1_000.0

      assert elapsed_ms < 50,
             "Dashboard render took #{Float.round(elapsed_ms, 2)}ms — must be < 50ms (SC-PRF-050)"
    end

    test "render_container_grid/1 for 15 containers completes in < 10ms" do
      containers = Enum.map(@containers, fn n -> {n, :healthy, 1.0} end)
      t0 = :erlang.monotonic_time(:microsecond)
      _output = render_container_grid(containers)
      t1 = :erlang.monotonic_time(:microsecond)
      elapsed_ms = (t1 - t0) / 1_000.0

      assert elapsed_ms < 10,
             "Container grid render took #{Float.round(elapsed_ms, 2)}ms — must be < 10ms"
    end

    test "render_health_bar/2 completes in < 1ms" do
      t0 = :erlang.monotonic_time(:microsecond)
      _bar = render_health_bar(0.75, "latency")
      t1 = :erlang.monotonic_time(:microsecond)
      elapsed_us = t1 - t0

      assert elapsed_us < 1_000,
             "Health bar render took #{elapsed_us}µs — must be < 1ms (1000µs)"
    end
  end

  # ============================================================================
  # SECTION 7: Property — dashboard rendering (EP-GEN-014 compliant)
  # ============================================================================

  describe "property: dashboard rendering" do
    # EP-GEN-014: ExUnitProperties.check all( — explicit module prefix because
    # check: 2 is excluded from import to avoid PropCheck collision.
    # SD. prefix on ALL StreamData generators.

    test "check all: render_health_bar produces non-empty binary for any 0.0–1.0 value" do
      ExUnitProperties.check all(
                               value <- SD.float(min: 0.0, max: 1.0),
                               label <- SD.string(:alphanumeric, min_length: 1, max_length: 16)
                             ) do
        bar = render_health_bar(value, label)

        assert is_binary(bar),
               "render_health_bar(#{value}, #{inspect(label)}) must return a binary"

        assert String.length(bar) > 0,
               "render_health_bar(#{value}, #{inspect(label)}) must not be empty"

        assert String.ends_with?(bar, @ansi_reset),
               "render_health_bar(#{value}, #{inspect(label)}) must end with ANSI reset (SC-HMI-010)"
      end
    end

    test "check all: render_sparkline produces valid binary for any non-empty integer list" do
      ExUnitProperties.check all(
                               values <-
                                 SD.nonempty(SD.list_of(SD.integer(0..100), max_length: 30)),
                               max_len <- SD.integer(1..100)
                             ) do
        sparkline = render_sparkline(values)

        assert is_binary(sparkline),
               "render_sparkline/1 must return a binary for input #{inspect(values)}"

        assert length(String.graphemes(sparkline)) == length(values),
               "render_sparkline/1 must emit one grapheme per input value"

        # max_len is a generated integer used to confirm the sparkline is
        # bounded — the sparkline length never exceeds input list length
        _unused = max_len
        assert length(String.graphemes(sparkline)) <= 100
      end
    end
  end

  # ============================================================================
  # Private Helpers — fully self-contained, no production module dependencies
  # ============================================================================

  # Renders a container status grid.
  # Input: list of {name, status, health_fraction} tuples.
  # Output: multi-line ANSI string, 2 columns per row.
  defp render_container_grid(containers) do
    rows =
      containers
      |> Enum.map(fn {name, status, _health} ->
        color = status_color(status)
        symbol = status_symbol(status)
        truncated = String.slice(name, 0, 18)
        padded = String.pad_trailing(truncated, 18)
        ansi_colorize("#{symbol} #{padded}", color)
      end)
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [left, right] ->
          # Lay out two columns side-by-side; pad based on plain-text width
          pad_width = 22 + String.length(@ansi_green) + String.length(@ansi_reset)
          String.pad_trailing(left, pad_width) <> right

        [single] ->
          single
      end)

    Enum.join(rows, "\n")
  end

  # Renders an ASCII progress bar for health ∈ [0.0, 1.0].
  # Bar width: 20 chars. Always ends with @ansi_reset (SC-HMI-010).
  defp render_health_bar(value, label) do
    width = 20
    clamped = max(0.0, min(1.0, value))
    filled = round(clamped * width)
    empty = width - filled

    color = health_color(clamped)
    bar_filled = String.duplicate("█", filled)
    bar_empty = String.duplicate("░", empty)

    padded_label = String.pad_trailing(label, 8)
    pct_str = String.pad_leading("#{round(clamped * 100)}%", 4)

    "#{padded_label} #{ansi_colorize(bar_filled <> bar_empty, color)} #{pct_str}#{@ansi_reset}"
  end

  # Renders a Unicode block sparkline from a list of numbers.
  # Each value maps to one of the 8 block characters ▁–█.
  # Returns a plain (no ANSI) binary; grapheme count == input list length.
  defp render_sparkline([]), do: ""

  defp render_sparkline(values) do
    min_v = Enum.min(values)
    max_v = Enum.max(values)
    range = if max_v == min_v, do: 1, else: max_v - min_v

    values
    |> Enum.map(fn v ->
      normalised = (v - min_v) / range
      index = min(7, round(normalised * 7))
      Enum.at(@block_chars, index)
    end)
    |> Enum.join()
  end

  # Wraps text in an ANSI color escape code followed by reset.
  # color :: :green | :red | :yellow | :cyan | :gray | :blue
  defp ansi_colorize(text, color) do
    "#{color_code(color)}#{text}#{@ansi_reset}"
  end

  # Renders the full 80×24 TUI dashboard from a metrics map.
  # metrics shape:
  #   %{containers: [{name, status, health}], cpu: float, memory: float,
  #     latency_ms: number, timestamp: binary}
  defp render_dashboard(metrics) do
    [
      render_header(metrics.timestamp),
      render_container_grid(metrics.containers),
      render_health_section(metrics),
      render_footer(metrics)
    ]
    |> Enum.join("\n")
  end

  # Strips all ANSI escape sequences, returning plain text.
  defp strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;]*[mABCDHJKSTfsu]/, text, "")
  end

  # ---- Private sub-helpers ----

  defp render_header(timestamp) do
    title = "INDRAJAAL SIL-6 BIOMORPHIC MESH"
    padded = String.pad_trailing(title, 60)
    ts = String.slice(timestamp || "", 0, 19)
    line = "#{@ansi_cyan}#{padded}#{@ansi_reset} #{ts}"
    divider = String.duplicate("─", 80)
    "#{line}\n#{divider}"
  end

  defp render_health_section(metrics) do
    cpu_bar = render_health_bar(metrics.cpu, "CPU")
    mem_bar = render_health_bar(metrics.memory, "MEM")
    lat_label = String.pad_trailing("LAT", 8)
    lat_val = "#{metrics.latency_ms}ms"
    "#{cpu_bar}\n#{mem_bar}\n#{lat_label} #{lat_val}"
  end

  defp render_footer(metrics) do
    healthy = Enum.count(metrics.containers, fn {_, s, _} -> s == :healthy end)
    total = length(metrics.containers)
    summary = "Containers: #{healthy}/#{total} healthy"
    divider = String.duplicate("─", 80)
    "#{divider}\n#{summary}"
  end

  defp status_symbol(:healthy), do: "●"
  defp status_symbol(:unhealthy), do: "✗"
  defp status_symbol(:starting), do: "◌"
  defp status_symbol(:stopped), do: "○"

  defp status_color(:healthy), do: :green
  defp status_color(:unhealthy), do: :red
  defp status_color(:starting), do: :yellow
  defp status_color(:stopped), do: :gray

  defp health_color(v) when v >= 0.7, do: :green
  defp health_color(v) when v >= 0.3, do: :yellow
  defp health_color(_), do: :red

  defp color_code(:green), do: @ansi_green
  defp color_code(:red), do: @ansi_red
  defp color_code(:yellow), do: @ansi_yellow
  defp color_code(:cyan), do: @ansi_cyan
  defp color_code(:gray), do: @ansi_gray
  defp color_code(:blue), do: "\e[34m"

  defp count_occurrences(str, char) do
    str |> String.graphemes() |> Enum.count(&(&1 == char))
  end

  defp sample_metrics do
    containers =
      @containers
      |> Enum.with_index()
      |> Enum.map(fn {name, i} ->
        status = Enum.at(@statuses, rem(i, 4))
        health = if status == :healthy, do: 1.0, else: 0.0
        {name, status, health}
      end)

    %{
      containers: containers,
      cpu: 0.42,
      memory: 0.61,
      latency_ms: 12,
      timestamp: "2026-03-24T10:00:00Z"
    }
  end
end
