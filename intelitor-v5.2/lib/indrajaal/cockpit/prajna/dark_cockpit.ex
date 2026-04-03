defmodule Indrajaal.Cockpit.Prajna.DarkCockpit do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Dark Cockpit CLI Renderer

  WHAT: Terminal-based UI implementing NASA-STD-3000, NUREG-0700, MIL-STD-1472H,
        and Laux/Wickens C3I Visual Display Principles for safety-critical HMI.

  WHY: The "Dark Cockpit" philosophy reduces cognitive load by only highlighting
       deviations from normal. Normal = invisible or dim. Abnormal = bright.
       Based on Laux, Howell, Lane (1993) "Visual Display Principles for C3I System Tasks".

  KEY PRINCIPLES (Wickens & Laux 13 Principles):
    1. Management by Exception - Only show what needs attention
    2. Analog over Digital - Use bar charts, sparklines, not just numbers
    3. Trend Vectors - Show direction, not just current state (Predictive Aiding)
    4. Staleness Decay - Gray out stale data (frozen numbers lie)
    5. Two-Step Commit - Critical commands require arm -> confirm (Closure)
    6. Salience Filtering - Score-based event visibility (d-prime)
    7. Redundancy Gain - Multi-modal alerting (visual + audio)
    8. Common Operational Picture - Standardized COP header
    9. Discriminability - Distinct visual properties for categories
   10. Supervisory Control - Show automation state, not just sensor data

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit (gray/blue default, amber/red deviations)
    - SC-HMI-002: Trend vectors displayed
    - SC-HMI-003: Staleness visual decay
    - SC-HMI-004: Two-step commit UI
    - SC-VDP-001 to SC-VDP-017: Visual Display Principles (Laux/Wickens)

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | Laux, Wickens, NASA-STD-3000, NUREG-0700 |
  | STAMP | SC-HMI-001 to SC-HMI-004, SC-VDP-001 to SC-VDP-017 |
  """

  alias Indrajaal.Cockpit.Prajna.Domain
  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Cockpit.Prajna.AiCopilot
  alias Indrajaal.Cockpit.Prajna.Salience

  # ═══════════════════════════════════════════════════════════════════════════
  # ANSI CODES - Dark Cockpit Color Palette
  # ═══════════════════════════════════════════════════════════════════════════

  @ansi %{
    # Reset
    reset: "\e[0m",
    # Text styles
    bold: "\e[1m",
    dim: "\e[2m",
    italic: "\e[3m",
    blink: "\e[5m",
    # Dark Cockpit Palette
    normal: "\e[90m",
    advisory: "\e[36m",
    caution: "\e[33m",
    warning: "\e[31m",
    critical: "\e[31;5m",
    # Status colors
    connected: "\e[32m",
    stale: "\e[90m",
    disconnected: "\e[31m",
    # Accent
    blue: "\e[34m",
    magenta: "\e[35m",
    white: "\e[37m",
    bright_white: "\e[97m",
    # Background
    bg_blue: "\e[44m",
    bg_gray: "\e[100m",
    # Control
    clear: "\e[2J\e[H",
    hide_cursor: "\e[?25l",
    show_cursor: "\e[?25h"
  }

  @box %{
    tl: "╔",
    tr: "╗",
    bl: "╚",
    br: "╝",
    h: "═",
    v: "║",
    cross: "╬",
    t_right: "╠",
    t_left: "╣",
    t_down: "╦",
    t_up: "╩",
    # Light borders
    ltl: "┌",
    ltr: "┐",
    lbl: "└",
    lbr: "┘",
    lh: "─",
    lv: "│"
  }

  @icons %{
    # Status
    connected: "●",
    stale: "◐",
    disconnected: "○",
    # Trends
    rising: "↑",
    rising_fast: "↑↑",
    falling: "↓",
    falling_fast: "↓↓",
    stable: "→",
    # Alarms
    normal: "·",
    advisory: "ℹ",
    caution: "⚠",
    warning: "⛔",
    critical: "☢",
    # Bars
    bar_full: "█",
    bar_mid: "▓",
    bar_low: "░",
    bar_empty: "·",
    # Sparkline
    spark: ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
    # Spinner
    spinner: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    # Automation States (SC-VDP-001: Supervisory Control Paradigm)
    auto_healing: "🔄",
    auto_scaling: "⚖",
    manual_override: "👤",
    degraded_mode: "⚠",
    emergency_stop: "🛑",
    normal_ops: "✓",
    # Command Closure (SC-VDP-016: Closure Principle)
    cmd_idle: "○",
    cmd_armed: "◎",
    cmd_executing: "●",
    cmd_success: "✓",
    cmd_failed: "✗",
    # Signal Activity
    signal_high: "▅▆▇",
    signal_med: "▃▄▅",
    signal_low: "▁▂▃",
    signal_none: "···"
  }

  # Audio Bell (SC-VDP-003: Redundancy Gain - Multi-modal alerting)
  @bell "\a"
  def bell, do: @bell

  # ═══════════════════════════════════════════════════════════════════════════
  # PUBLIC API
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Render the complete cockpit display with C3I Visual Display Principles.

  Implements:
    - SC-VDP-001: COP Header with automation state
    - SC-VDP-003: Multi-modal alerting (visual + audio bell)
    - SC-VDP-011: Context-sensitive hint bar
    - SC-VDP-015: Salience-based event filtering
  """
  def render(state, spinner_frame \\ 0) do
    {cols, rows} = get_terminal_size()

    IO.write(@ansi.clear)
    IO.write(@ansi.hide_cursor)

    # Check for high-salience alarms and trigger audio alert (SC-VDP-003)
    trigger_audio_alerts(state)

    # Render components
    # COP: Common Operational Picture
    render_cop_header(state, cols, spinner_frame)
    render_main_panels(state, cols, rows - 7)
    # Signal sniffer pane
    render_signal_activity(state, cols)
    # Context-sensitive hints
    render_hint_bar(state, cols)
  end

  @doc """
  Trigger audio alerts for high-salience events (SC-VDP-003: Redundancy Gain).
  Multi-modal alerting: visual + audio bell for critical events.
  """
  def trigger_audio_alerts(state) do
    # Get recent alarms and check salience
    high_salience_alarms =
      state
      |> Map.get(:alarms, %{})
      |> Map.values()
      |> Enum.filter(fn alarm ->
        event = %{
          level: alarm.level,
          unexpected: alarm[:acknowledged_at] == nil,
          occurrence_count: 1
        }

        Salience.calculate_score(event) > 80
      end)

    # Emit bell for critical alarms (first one only to avoid spam)
    if length(high_salience_alarms) > 0 do
      Salience.maybe_beep(100)
    end
  end

  @doc "Get color for alarm level"
  def alarm_color(:normal), do: @ansi.normal
  def alarm_color(:advisory), do: @ansi.advisory
  def alarm_color(:caution), do: @ansi.caution
  def alarm_color(:warning), do: @ansi.warning
  def alarm_color(:critical), do: @ansi.critical

  @doc "Get trend arrow with color"
  def trend_arrow(:rising), do: "#{@ansi.caution}#{@icons.rising}#{@ansi.reset}"
  def trend_arrow(:rising_fast), do: "#{@ansi.warning}#{@icons.rising_fast}#{@ansi.reset}"
  def trend_arrow(:falling), do: "#{@ansi.advisory}#{@icons.falling}#{@ansi.reset}"
  def trend_arrow(:falling_fast), do: "#{@ansi.caution}#{@icons.falling_fast}#{@ansi.reset}"
  def trend_arrow(:stable), do: "#{@ansi.normal}#{@icons.stable}#{@ansi.reset}"

  @doc "Render a horizontal bar (analog representation)"
  def render_bar(value, max_val, width, level \\ :normal) do
    pct = min(1.0, value / max_val)
    filled = round(pct * width)
    empty = width - filled
    color = alarm_color(level)

    "#{color}#{String.duplicate(@icons.bar_full, filled)}#{@ansi.dim}#{String.duplicate(@icons.bar_empty, empty)}#{@ansi.reset}"
  end

  @doc "Render a sparkline"
  def render_sparkline(values, max_val, width) when is_list(values) and length(values) > 0 do
    normalized = Enum.map(values, fn v -> min(1.0, v / max_val) end)

    normalized
    |> Enum.take(width)
    |> Enum.map_join("", fn v ->
      raw_idx = round(v * 7)
      idx = raw_idx |> max(0) |> min(7)
      Enum.at(@icons.spark, idx)
    end)
  end

  def render_sparkline(_, _, width), do: String.duplicate(@icons.bar_empty, width)

  # ═══════════════════════════════════════════════════════════════════════════
  # COP HEADER - Common Operational Picture (SC-VDP-001, SC-VDP-008)
  # Supervisory Control: Shows AUTOMATION STATE, not just sensor data
  # ═══════════════════════════════════════════════════════════════════════════

  # Render COP (Common Operational Picture) header.
  # Implements SC-VDP-001: Supervisory Control Paradigm
  # Shows: Automation State | Health | OODA Cycle | Uptime | Time
  # The key insight from Laux (1993): "UI must answer 'What is the automation doing?'"
  defp render_cop_header(state, cols, spinner_frame) do
    spinner = Enum.at(@icons.spinner, rem(spinner_frame, 10))
    uptime = DateTime.diff(DateTime.utc_now(), state.started_at, :second)
    uptime_str = format_uptime(uptime)
    timestamp = DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")

    # Top border
    IO.puts("#{@box.tl}#{String.duplicate(@box.h, cols - 2)}#{@box.tr}")

    # Title line with Automation State (SC-VDP-001)
    title = "#{@ansi.bold}#{@ansi.bg_blue} PRAJNA C3I COCKPIT #{@ansi.reset}"

    # Determine automation state (answers "What is the automation doing?")
    auto_state = get_automation_state(state)
    auto_badge = render_automation_badge(auto_state)

    view = "#{@ansi.advisory}#{state.current_view}#{@ansi.reset}"

    health = SmartMetrics.health_summary()

    status_summary =
      cond do
        health.by_level.critical > 0 or health.by_level.warning > 0 ->
          "#{@ansi.warning}#{health.alarmed_count} ALERTS#{@ansi.reset}"

        health.status == :healthy ->
          "#{@ansi.connected}#{health.total_metrics} OK#{@ansi.reset}"

        true ->
          "#{@ansi.caution}#{health.health_score}%#{@ansi.reset}"
      end

    # OODA cycle indicator
    ooda_phase = Map.get(state, :ooda_phase, :observe)
    ooda_indicator = render_ooda_indicator(ooda_phase)

    content =
      " #{title} #{spinner} #{auto_badge} │ #{view} │ #{status_summary} │ #{ooda_indicator} │ #{uptime_str} #{timestamp}"

    padded = pad_right(content, cols - 2)
    IO.puts("#{@box.v}#{padded}#{@box.v}")

    # Separator
    IO.puts("#{@box.t_right}#{String.duplicate(@box.h, cols - 2)}#{@box.t_left}")
  end

  # Determine automation state from cockpit state
  defp get_automation_state(state) do
    health = SmartMetrics.health_summary()
    pending_commands_map = Map.get(state, :pending_commands, %{})
    pending_cmds = map_size(pending_commands_map)

    cond do
      Map.get(state, :emergency_stop, false) -> :emergency_stop
      Map.get(state, :manual_override, false) -> :manual_override
      health.by_level.critical > 0 -> :degraded_mode
      Map.get(state, :auto_healing, false) -> :auto_healing
      Map.get(state, :auto_scaling, false) -> :auto_scaling
      pending_cmds > 0 -> :executing
      true -> :normal_ops
    end
  end

  # Render automation state badge (SC-VDP-001)
  defp render_automation_badge(:emergency_stop) do
    "#{@ansi.critical}[#{@icons.emergency_stop} EMERGENCY STOP]#{@ansi.reset}"
  end

  defp render_automation_badge(:manual_override) do
    "#{@ansi.caution}[#{@icons.manual_override} MANUAL]#{@ansi.reset}"
  end

  defp render_automation_badge(:degraded_mode) do
    "#{@ansi.warning}[#{@icons.degraded_mode} DEGRADED]#{@ansi.reset}"
  end

  defp render_automation_badge(:auto_healing) do
    "#{@ansi.advisory}[#{@icons.auto_healing} AUTO-HEALING]#{@ansi.reset}"
  end

  defp render_automation_badge(:auto_scaling) do
    "#{@ansi.advisory}[#{@icons.auto_scaling} AUTO-SCALING]#{@ansi.reset}"
  end

  defp render_automation_badge(:executing) do
    "#{@ansi.caution}[● EXECUTING]#{@ansi.reset}"
  end

  defp render_automation_badge(:normal_ops) do
    "#{@ansi.dim}[#{@icons.normal_ops} NOMINAL]#{@ansi.reset}"
  end

  defp render_automation_badge(_) do
    "#{@ansi.dim}[? UNKNOWN]#{@ansi.reset}"
  end

  # Render OODA cycle phase indicator
  defp render_ooda_indicator(:observe), do: "#{@ansi.advisory}O#{@ansi.dim}ODA#{@ansi.reset}"

  defp render_ooda_indicator(:orient),
    do: "#{@ansi.dim}O#{@ansi.advisory}O#{@ansi.dim}DA#{@ansi.reset}"

  defp render_ooda_indicator(:decide),
    do: "#{@ansi.dim}OO#{@ansi.advisory}D#{@ansi.dim}A#{@ansi.reset}"

  defp render_ooda_indicator(:act), do: "#{@ansi.dim}OOD#{@ansi.advisory}A#{@ansi.reset}"
  defp render_ooda_indicator(_), do: "#{@ansi.dim}OODA#{@ansi.reset}"

  # ═══════════════════════════════════════════════════════════════════════════
  # MAIN PANELS
  # ═══════════════════════════════════════════════════════════════════════════

  defp render_main_panels(_state, cols, available_rows) do
    left_width = div(cols, 2)
    right_width = cols - left_width

    # Get data
    metrics = SmartMetrics.all() |> Enum.take(available_rows - 4)
    insights = AiCopilot.insights() |> Enum.take(div(available_rows, 2))

    # Render side by side
    metrics_panel = render_metrics_panel(metrics, left_width, available_rows)
    insights_panel = render_insights_panel(insights, right_width, available_rows)

    # Merge lines
    merged_panels = Enum.zip(metrics_panel, insights_panel)

    Enum.each(merged_panels, fn {left, right} ->
      IO.puts("#{left}#{right}")
    end)
  end

  defp render_metrics_panel(metrics, width, height) do
    header =
      "#{@box.v}#{@ansi.bold} METRICS (#{length(metrics)}) #{@ansi.reset}#{String.duplicate(@box.lh, width - 18)}"

    metric_lines =
      metrics
      |> Enum.map(fn {id, metric} ->
        is_stale = Domain.stale?(metric)

        color =
          cond do
            is_stale -> @ansi.stale
            metric.level != :normal -> alarm_color(metric.level)
            true -> @ansi.dim
          end

        icon = if is_stale, do: @icons.stale, else: @icons.connected
        bar = render_bar(metric.value, 100.0, 6, metric.level)
        arrow = if is_stale, do: "#{@ansi.stale}?#{@ansi.reset}", else: trend_arrow(metric.trend)

        name_slice = String.slice(id, 0, 15)
        name = String.pad_trailing(name_slice, 15)
        value_str = :erlang.float_to_binary(metric.value, decimals: 1)

        content =
          " #{color}#{icon}#{@ansi.reset} #{name} #{bar} #{value_str}#{metric.unit} #{arrow}"

        "#{@box.v}#{pad_right(content, width - 1)}"
      end)

    # Pad remaining lines
    empty_count = height - 1 - length(metric_lines)

    empty_lines =
      List.duplicate("#{@box.v}#{String.duplicate(" ", width - 1)}", max(0, empty_count))

    [header | metric_lines] ++ empty_lines
  end

  defp render_insights_panel(insights, width, height) do
    header =
      "#{@ansi.bold} 🤖 AI COPILOT #{@ansi.reset}#{String.duplicate(@box.lh, width - 20)}#{@box.v}"

    insight_lines =
      insights
      |> Enum.flat_map(fn insight ->
        color = alarm_color(insight.level)
        icon = Domain.alarm_icon(insight.level)
        confidence = round(insight.confidence * 100)

        title_line =
          " #{color}#{icon}#{@ansi.reset} #{String.slice(insight.title, 0, width - 15)} (#{confidence}%)"

        desc_line =
          " #{@ansi.dim}#{String.slice(insight.description, 0, width - 5)}#{@ansi.reset}"

        [
          "#{pad_right(title_line, width - 1)}#{@box.v}",
          "#{pad_right(desc_line, width - 1)}#{@box.v}"
        ]
      end)
      |> Enum.take(height - 1)

    # Pad remaining lines
    empty_count = height - 1 - length(insight_lines)

    empty_lines =
      if empty_count > 0 and insights == [] do
        no_insights = " #{@ansi.dim}No active insights#{@ansi.reset}"

        [
          pad_right(no_insights, width - 1) <> @box.v
          | List.duplicate("#{String.duplicate(" ", width - 1)}#{@box.v}", empty_count - 1)
        ]
      else
        List.duplicate("#{String.duplicate(" ", width - 1)}#{@box.v}", max(0, empty_count))
      end

    [header | insight_lines] ++ empty_lines
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SIGNAL ACTIVITY PANE (SC-VDP-017: Signal Sniffer)
  # Shows Zenoh pub/sub traffic as analog "radio dial" representation
  # ═══════════════════════════════════════════════════════════════════════════

  defp render_signal_activity(state, cols) do
    msg_rate = calculate_message_rate(state)
    signal_indicator = signal_level_indicator(msg_rate)

    # Zenoh channel activity (simulated from message patterns)
    channels = [
      {"telemetry", msg_rate * 0.6},
      {"alarms", msg_rate * 0.2},
      {"commands", msg_rate * 0.1},
      {"ai", msg_rate * 0.1}
    ]

    channel_bars_list =
      Enum.map(channels, fn {name, rate} ->
        bar_width = 8
        filled = round(min(1.0, rate / 10) * bar_width)
        bar = String.duplicate("▓", filled) <> String.duplicate("░", bar_width - filled)
        color = if rate > 5, do: @ansi.advisory, else: @ansi.dim
        "#{color}#{String.pad_trailing(name, 10)}#{bar}#{@ansi.reset}"
      end)

    channel_bars = Enum.join(channel_bars_list, " │ ")

    content = " #{@ansi.dim}SIGNALS:#{@ansi.reset} #{signal_indicator} │ #{channel_bars}"
    IO.puts("#{@box.t_right}#{String.duplicate(@box.h, cols - 2)}#{@box.t_left}")
    IO.puts("#{@box.v}#{pad_right(content, cols - 2)}#{@box.v}")
  end

  defp calculate_message_rate(state) do
    # Messages per second estimate
    uptime = DateTime.diff(DateTime.utc_now(), state.started_at, :second)
    if uptime > 0, do: state.messages_received / uptime, else: 0
  end

  defp signal_level_indicator(rate) do
    cond do
      rate > 10 -> "#{@ansi.connected}#{@icons.signal_high}#{@ansi.reset}"
      rate > 3 -> "#{@ansi.advisory}#{@icons.signal_med}#{@ansi.reset}"
      rate > 0 -> "#{@ansi.dim}#{@icons.signal_low}#{@ansi.reset}"
      true -> "#{@ansi.stale}#{@icons.signal_none}#{@ansi.reset}"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # CONTEXT-SENSITIVE HINT BAR (SC-VDP-011: Knowledge in the World)
  # Reduces memory burden by showing available actions for current context
  # ═══════════════════════════════════════════════════════════════════════════

  # Render context-sensitive hint bar based on current view/state.
  # Implements SC-VDP-011: Knowledge in the World
  # "Don't make the operator memorize - show what's available."
  defp render_hint_bar(state, cols) do
    IO.puts("#{@box.bl}#{String.duplicate(@box.h, cols - 2)}#{@box.br}")

    # Context-sensitive commands based on current view and state
    hints = get_context_hints(state)
    hint_str = Enum.join(hints, " │ ")

    status =
      if state.messages_received > 0 do
        "#{@ansi.dim}Msg: #{state.messages_received}#{@ansi.reset}"
      else
        "#{@ansi.stale}Awaiting data#{@ansi.reset}"
      end

    session = "#{@ansi.dim}#{String.slice(state.session_id, 0, 8)}#{@ansi.reset}"

    # Add armed command indicator if present (SC-VDP-016: Closure)
    armed_indicator = render_armed_indicator(state)

    content =
      "  #{hint_str}#{armed_indicator}#{String.duplicate(" ", max(1, 10))}#{status} │ #{session}"

    IO.puts(pad_right(content, cols))
  end

  # Get context-sensitive hints based on current state
  defp get_context_hints(state) do
    base_hints = [
      "#{@ansi.dim}[q]#{@ansi.reset}uit",
      "#{@ansi.dim}[v]#{@ansi.reset}iew",
      "#{@ansi.dim}[r]#{@ansi.reset}efresh"
    ]

    view_hints =
      case state.current_view do
        :overview ->
          ["#{@ansi.dim}[m]#{@ansi.reset}esh", "#{@ansi.dim}[l]#{@ansi.reset}alarms"]

        :mesh ->
          [
            "#{@ansi.dim}[Enter]#{@ansi.reset} select node",
            "#{@ansi.dim}[Esc]#{@ansi.reset} back"
          ]

        :alarms ->
          ["#{@ansi.dim}[a]#{@ansi.reset}ck alarm", "#{@ansi.dim}[f]#{@ansi.reset}ilter"]

        :commands ->
          if has_armed_command?(state) do
            ["#{@ansi.caution}[c]#{@ansi.reset}onfirm", "#{@ansi.warning}[x]#{@ansi.reset}cancel"]
          else
            ["#{@ansi.dim}[a]#{@ansi.reset}rm command"]
          end

        :node_detail ->
          [
            "#{@ansi.dim}[r]#{@ansi.reset}estart",
            "#{@ansi.dim}[i]#{@ansi.reset}solate",
            "#{@ansi.dim}[Esc]#{@ansi.reset} back"
          ]

        _ ->
          []
      end

    view_hints ++ base_hints
  end

  # Check if there's an armed command awaiting confirmation
  defp has_armed_command?(state) do
    state
    |> Map.get(:pending_commands, %{})
    |> Map.values()
    |> Enum.any?(fn cmd -> cmd.state == :armed end)
  end

  # Render armed command indicator (SC-VDP-016: Closure Principle).
  # Shows BEGIN (armed) → MIDDLE (executing) → END (complete/failed) states.
  defp render_armed_indicator(state) do
    armed_cmds =
      state
      |> Map.get(:pending_commands, %{})
      |> Map.values()
      |> Enum.filter(fn cmd -> cmd.state in [:armed, :executing] end)

    case armed_cmds do
      [] ->
        ""

      [cmd | _] ->
        icon =
          case cmd.state do
            :armed -> @icons.cmd_armed
            :executing -> @icons.cmd_executing
            _ -> @icons.cmd_idle
          end

        color =
          case cmd.state do
            :armed -> @ansi.caution
            :executing -> @ansi.warning
            _ -> @ansi.dim
          end

        # Show ghost value / impact preview if armed
        ghost =
          if cmd.state == :armed do
            " #{@ansi.dim}→ #{cmd.command}#{@ansi.reset}"
          else
            ""
          end

        " │ #{color}#{icon} CMD: #{cmd.target_node_id}#{ghost}#{@ansi.reset}"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp get_terminal_size do
    case :io.columns() do
      {:ok, cols} ->
        rows =
          case :io.rows() do
            {:ok, r} -> r
            _ -> 40
          end

        {max(80, cols), max(24, rows)}

      _ ->
        {120, 40}
    end
  end

  defp pad_right(str, width) do
    visible_len = visible_length(str)

    if visible_len < width do
      str <> String.duplicate(" ", width - visible_len)
    else
      str
    end
  end

  defp visible_length(str) do
    # Remove ANSI escape sequences for length calculation
    stripped = Regex.replace(~r/\e\[[0-9;]*m/, str, "")
    String.length(stripped)
  end

  defp format_uptime(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)
    formatted = :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, secs])
    to_string(formatted)
  end
end
