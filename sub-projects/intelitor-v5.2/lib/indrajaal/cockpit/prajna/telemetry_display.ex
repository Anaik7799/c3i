defmodule Indrajaal.Cockpit.Prajna.TelemetryDisplay do
  @moduledoc """
  PRAJNA Telemetry Display - Real-time Metric Visualization

  WHAT: Provides real-time telemetry display integration for the PRAJNA Cockpit,
        including sparklines, gauges, trend indicators, and staleness detection.

  WHY: Operators need instant visual feedback on system metrics with:
       - Trend detection (rising, falling, stable)
       - Staleness indicators (data freshness)
       - Sparkline history (pattern recognition)
       - Alarm-level coloring (safety status)

  DESIGN PRINCIPLES:
    1. Dark Cockpit - Gray for normal, color for exceptions
    2. Management by Exception - Only highlight deviations
    3. Analog over Digital - Bars and sparklines, not just numbers
    4. Staleness Decay - Visual degradation when data is stale

  STAMP Compliance:
    - SC-HMI-003: Staleness indicator after 5 seconds
    - SC-TEL-001: Display latency <100ms
    - SC-TEL-002: Trend accuracy >95%
    - SC-TEL-003: Sparkline resolution 60 samples

  Usage:
    # Render a metric gauge with sparkline
    TelemetryDisplay.render_gauge("cpu", 75.5, :percent, :caution)

    # Get trend indicator
    TelemetryDisplay.get_trend([75, 76, 78, 80, 82])  # => :rising_fast

    # Check staleness
    TelemetryDisplay.staleness_class(3.5)  # => :fresh
    TelemetryDisplay.staleness_class(7.0)  # => :stale
  """

  alias Indrajaal.Cockpit.Prajna.Messaging

  # Trend thresholds
  # >5% change = fast
  @trend_threshold_fast 5.0
  # >1% change = slow
  @trend_threshold_slow 1.0
  # seconds
  @staleness_threshold 5.0

  # Sparkline characters (8 levels)
  @sparkline_chars ~c[▁▂▃▄▅▆▇█]

  # Trend indicators
  @trend_icons %{
    rising_fast: "↑↑",
    rising: "↑",
    stable: "→",
    falling: "↓",
    falling_fast: "↓↓",
    unknown: "?"
  }

  # Status indicators
  @status_icons %{
    connected: "●",
    stale: "◐",
    disconnected: "○"
  }

  # Alarm level colors (Tailwind classes for LiveView)
  @alarm_colors %{
    normal: "text-gray-500",
    advisory: "text-cyan-500",
    caution: "text-amber-500",
    warning: "text-red-500",
    critical: "text-red-600 animate-pulse"
  }

  # ═══════════════════════════════════════════════════════════════════════════
  # TREND ANALYSIS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Calculate trend from a list of recent values"
  def get_trend(values) when length(values) < 2, do: :unknown

  def get_trend(values) do
    recent = Enum.take(values, 10)
    first = List.last(recent)
    last = List.first(recent)

    if first == 0 do
      :unknown
    else
      change_pct = (last - first) / first * 100

      cond do
        change_pct > @trend_threshold_fast -> :rising_fast
        change_pct > @trend_threshold_slow -> :rising
        change_pct < -@trend_threshold_fast -> :falling_fast
        change_pct < -@trend_threshold_slow -> :falling
        true -> :stable
      end
    end
  end

  @doc "Get trend icon"
  def trend_icon(trend) do
    Map.get(@trend_icons, trend, "?")
  end

  @doc "Get trend CSS class for LiveView"
  def trend_class(trend) do
    case trend do
      :rising_fast -> "text-red-500"
      :rising -> "text-amber-500"
      :stable -> "text-gray-500"
      :falling -> "text-cyan-500"
      :falling_fast -> "text-blue-500"
      _ -> "text-gray-400"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # STALENESS DETECTION
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Get staleness class from seconds since last update"
  def staleness_class(seconds) when seconds < @staleness_threshold, do: :fresh
  def staleness_class(seconds) when seconds < 30, do: :stale
  def staleness_class(_seconds), do: :very_stale

  @doc "Get staleness CSS class"
  def staleness_css(seconds) do
    case staleness_class(seconds) do
      :fresh -> ""
      :stale -> "opacity-60"
      :very_stale -> "opacity-30"
    end
  end

  @doc "Get status icon based on staleness"
  def status_icon(seconds) do
    case staleness_class(seconds) do
      :fresh -> @status_icons.connected
      :stale -> @status_icons.stale
      :very_stale -> @status_icons.disconnected
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SPARKLINE RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Render sparkline from values"
  def render_sparkline(values, width \\ 20)

  def render_sparkline(values, width) when values == [] do
    String.duplicate("░", width)
  end

  def render_sparkline(values, width) do
    taken = Enum.take(values, width)
    recent = Enum.reverse(taken)

    if recent == [] do
      String.duplicate("░", width)
    else
      min_val = Enum.min(recent)
      max_val = Enum.max(recent)
      range = max(0.001, max_val - min_val)

      chars =
        Enum.map(recent, fn v ->
          normalized = (v - min_val) / range
          idx = trunc(normalized * (length(@sparkline_chars) - 1))
          idx = max(0, min(length(@sparkline_chars) - 1, idx))
          Enum.at(@sparkline_chars, idx)
        end)

      padding = String.duplicate("░", max(0, width - length(chars)))
      padding <> List.to_string(chars)
    end
  end

  @doc "Render sparkline with color based on alarm level"
  def render_colored_sparkline(values, width, alarm_level) do
    sparkline = render_sparkline(values, width)
    color_class = Map.get(@alarm_colors, alarm_level, @alarm_colors.normal)
    {sparkline, color_class}
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GAUGE RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Render a progress bar gauge"
  def render_gauge(value, max_value, width \\ 10) when value >= 0 do
    ratio = min(1.0, value / max_value)
    filled = round(ratio * width)
    empty = width - filled

    filled_chars = String.duplicate("▓", filled)
    empty_chars = String.duplicate("░", empty)

    filled_chars <> empty_chars
  end

  @doc "Render gauge with percentage and trend"
  def render_gauge_with_info(_metric_key, value, max_value, values, width \\ 10) do
    gauge = render_gauge(value, max_value, width)
    trend = get_trend(values)
    trend_icon = trend_icon(trend)
    pct = round(value / max_value * 100)

    %{
      gauge: gauge,
      percent: pct,
      trend: trend,
      trend_icon: trend_icon,
      trend_class: trend_class(trend)
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # METRIC CARD RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Generate a complete metric card data structure"
  def metric_card(node_id, metric_type, opts \\ []) do
    state = Messaging.get_telemetry_state()
    metric_key = "#{node_id}.#{metric_type}"

    value =
      case get_in(state.metrics, [metric_key, :value]) do
        nil -> 0.0
        v -> v
      end

    unit =
      case get_in(state.metrics, [metric_key, :unit]) do
        nil -> ""
        u -> u
      end

    values = Map.get(state.sparklines, metric_key, [])
    staleness = Messaging.get_staleness(metric_key)

    # Determine alarm level based on thresholds
    warning_threshold = Keyword.get(opts, :warning, 90)
    caution_threshold = Keyword.get(opts, :caution, 75)

    alarm_level =
      cond do
        value >= warning_threshold -> :warning
        value >= caution_threshold -> :caution
        staleness > 30 -> :advisory
        true -> :normal
      end

    max_value = Keyword.get(opts, :max, 100)
    width = Keyword.get(opts, :width, 10)

    gauge_info = render_gauge_with_info(metric_key, value, max_value, values, width)

    %{
      node_id: node_id,
      metric_type: metric_type,
      value: value,
      unit: unit,
      gauge: gauge_info.gauge,
      percent: gauge_info.percent,
      trend: gauge_info.trend,
      trend_icon: gauge_info.trend_icon,
      trend_class: gauge_info.trend_class,
      sparkline: render_sparkline(values, 20),
      staleness: staleness,
      staleness_class: staleness_class(staleness),
      staleness_css: staleness_css(staleness),
      status_icon: status_icon(staleness),
      alarm_level: alarm_level,
      alarm_class: Map.get(@alarm_colors, alarm_level)
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # NODE STATUS RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @doc "Generate node status summary"
  def node_status(node_id) do
    cpu = metric_card(node_id, :cpu, warning: 90, caution: 75)
    memory = metric_card(node_id, :memory, warning: 90, caution: 80)
    latency = metric_card(node_id, :latency, warning: 100, caution: 50, max: 200)

    # Determine overall node status
    overall_level =
      Enum.max_by(
        [cpu.alarm_level, memory.alarm_level, latency.alarm_level],
        fn level ->
          case level do
            :critical -> 4
            :warning -> 3
            :caution -> 2
            :advisory -> 1
            :normal -> 0
          end
        end
      )

    %{
      node_id: node_id,
      cpu: cpu,
      memory: memory,
      latency: latency,
      overall_level: overall_level,
      overall_class: Map.get(@alarm_colors, overall_level),
      status_icon: status_icon(cpu.staleness)
    }
  end

  @doc "Generate summary for multiple nodes"
  def nodes_summary(node_ids) do
    nodes = Enum.map(node_ids, &node_status/1)

    healthy = Enum.count(nodes, fn n -> n.overall_level == :normal end)
    warning = Enum.count(nodes, fn n -> n.overall_level in [:caution, :warning, :critical] end)

    %{
      nodes: nodes,
      total: length(nodes),
      healthy: healthy,
      warning: warning,
      health_percent: if(length(nodes) > 0, do: round(healthy / length(nodes) * 100), else: 100)
    }
  end
end
