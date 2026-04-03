# PRAJNA TUI Component System

**Version**: 2.0.0 (Fractal Update)
**Status**: ACTIVE
**Architecture**: Recursive Holon Rendering

---

## 1.0 The Fractal Renderer Strategy

In v2.0, we move away from hardcoded screens (e.g., `DashboardScreen`, `NodeScreen`) towards a single **Recursive Holon Renderer**.

### 1.1 The Universal Holon View
Instead of 50 different widgets, we use ONE widget (`HolonView`) that changes its appearance based on **Zoom Level** and **Context**.

*   **Zoom 0 (System):** Render as a pulsating Orb (Color = Health).
*   **Zoom 1 (Cluster):** Render as a Grid of Nodes.
*   **Zoom 2 (Node):** Render as a List of Containers with Sparklines.
*   **Zoom 3 (Process):** Render as a Log Stream / Trace.

### 1.2 Deprecation Notice
The following static components are **Deprecated** in favor of dynamic `HolonRenderer` adaptation:
*   `MetricCard` (Replaced by `HolonView` at Zoom Level 2)
*   `NodeCard` (Replaced by `HolonView` at Zoom Level 1)

---

## 2.0 Component Library (Legacy & Fractal)

### 2.1 Core Fractal Components

#### `Cepaf.UI.HolonRenderer`
The master recursive function.
*   **Input:** `HolonTree` (from Elixir Bridge)
*   **Logic:**
    *   If `Depth > Threshold`: Render Details (Text/Graph).
    *   If `Depth < Threshold`: Render Children (Recursion).
*   **Intelligence:** Automatically sorts children by `Salience` (Show the most critical items first).

---

### 2.2 Legacy Widgets (Maintenance Mode)
*(Retained for backward compatibility during migration)*

#### `Prajna.TUI.Primitives.Gauge`
...

## Executive Summary

This document specifies the **PRAJNA TUI Component System** - a unified Terminal UI framework synthesized from best practices in Go (Bubbletea, termui, tview) and Rust (Ratatui, Cursive) ecosystems, adapted for the Indrajaal C3I Mesh Cockpit requirements.

### Design Principles

1. **Elm Architecture Compliance**: Model-Update-View unidirectional data flow
2. **Composable Widgets**: Trait-based component system with render/handle interfaces
3. **Dark Cockpit Philosophy**: Management by exception, ISA-101 colors
4. **Real-Time Updates**: PubSub-driven reactive updates with staleness decay
5. **Two-Step Commit**: All critical operations require arm-then-confirm

---

## 1. Architectural Foundation

### 1.1 Component Model (Elm Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRAJNA TUI ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ MODEL ──────────────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  defmodule Prajna.TUI.Model do                                       │   │
│  │    defstruct [                                                        │   │
│  │      # View state                                                     │   │
│  │      :active_tab,           # :overview | :mesh | :alarms | ...      │   │
│  │      :focus_path,           # [:sidebar, :item_2]                    │   │
│  │      :modal,                # nil | {:confirm, command}              │   │
│  │                                                                       │   │
│  │      # Domain data                                                    │   │
│  │      :metrics,              # %{node_id => %MetricSet{}}             │   │
│  │      :alarms,               # [%Alarm{}, ...]                        │   │
│  │      :nodes,                # %{id => %Node{}}                       │   │
│  │      :insights,             # [%Insight{}, ...]                      │   │
│  │                                                                       │   │
│  │      # Temporal state                                                 │   │
│  │      :last_update,          # DateTime                               │   │
│  │      :staleness,            # %{metric_id => seconds}                │   │
│  │      :armed_command         # nil | %ArmedCommand{}                  │   │
│  │    ]                                                                  │   │
│  │  end                                                                  │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│                              ↓ Messages ↓                                    │
│                                                                              │
│  ┌─ UPDATE ─────────────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  # Message Types                                                      │   │
│  │  {:key, key_event}              # Keyboard input                     │   │
│  │  {:mouse, mouse_event}          # Mouse input                        │   │
│  │  {:tick, timestamp}             # Periodic refresh                   │   │
│  │  {:metric_update, node, data}   # PubSub metric                      │   │
│  │  {:alarm_event, alarm}          # New/updated alarm                  │   │
│  │  {:insight, insight}            # AI Copilot insight                 │   │
│  │  {:command_result, result}      # Command execution result           │   │
│  │                                                                       │   │
│  │  def update(model, message) do                                       │   │
│  │    case message do                                                    │   │
│  │      {:key, %{key: :tab}} ->                                         │   │
│  │        {cycle_tab(model), []}                                        │   │
│  │      {:metric_update, node, data} ->                                 │   │
│  │        {update_metrics(model, node, data), []}                       │   │
│  │      {:key, %{key: :enter}} when model.armed_command != nil ->       │   │
│  │        {model, [{:cmd, :execute_armed}]}                             │   │
│  │      _ ->                                                             │   │
│  │        {model, []}                                                    │   │
│  │    end                                                                │   │
│  │  end                                                                  │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│                              ↓ Model ↓                                       │
│                                                                              │
│  ┌─ VIEW ───────────────────────────────────────────────────────────────┐   │
│  │                                                                       │   │
│  │  def view(model) do                                                  │   │
│  │    frame do                                                           │   │
│  │      row height: 3 do                                                │   │
│  │        StatusBar.render(model)                                       │   │
│  │      end                                                              │   │
│  │                                                                       │   │
│  │      row height: 1 do                                                │   │
│  │        TabBar.render(model.active_tab)                               │   │
│  │      end                                                              │   │
│  │                                                                       │   │
│  │      row fill: true do                                               │   │
│  │        case model.active_tab do                                      │   │
│  │          :overview -> OverviewPane.render(model)                     │   │
│  │          :mesh -> MeshPane.render(model)                             │   │
│  │          :alarms -> AlarmsPane.render(model)                         │   │
│  │          # ...                                                        │   │
│  │        end                                                            │   │
│  │      end                                                              │   │
│  │                                                                       │   │
│  │      if model.modal do                                               │   │
│  │        Modal.render(model.modal)                                     │   │
│  │      end                                                              │   │
│  │    end                                                                │   │
│  │  end                                                                  │   │
│  │                                                                       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Widget Trait System

```elixir
defmodule Prajna.TUI.Widget do
  @moduledoc """
  Base behavior for all TUI components.

  Inspired by Ratatui's Widget trait and Bubbletea's Model interface.
  """

  @type area :: %{x: non_neg_integer(), y: non_neg_integer(),
                   width: non_neg_integer(), height: non_neg_integer()}
  @type buffer :: %{cells: map(), width: non_neg_integer(), height: non_neg_integer()}

  @doc "Render widget to buffer within given area"
  @callback render(widget :: struct(), area :: area(), buffer :: buffer()) :: buffer()

  @doc "Handle input event, return updated widget and commands"
  @callback handle_event(widget :: struct(), event :: term()) ::
    {widget :: struct(), commands :: [term()]}

  @doc "Return minimum size requirements"
  @callback min_size(widget :: struct()) :: {width :: non_neg_integer(), height :: non_neg_integer()}

  @optional_callbacks [handle_event: 2, min_size: 1]
end

defmodule Prajna.TUI.StatefulWidget do
  @moduledoc """
  Widget that maintains internal state (e.g., scroll position, selection).

  Analogous to Ratatui's StatefulWidget trait.
  """

  @callback render_stateful(widget :: struct(), state :: term(), area :: area(), buffer :: buffer()) ::
    {buffer :: buffer(), new_state :: term()}
end
```

---

## 2. Primitive Component Vocabulary

### 2.1 Status Indicators

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STATUS INDICATOR PRIMITIVES                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  HEALTH STATUS (SC-HMI-001)                                                  │
│  ───────────────────────────                                                 │
│  ● HEALTHY   - Green (#22C55E)   - Normal operation                         │
│  ◐ DEGRADED  - Amber (#F59E0B)   - Partial functionality                    │
│  ⚠ WARNING   - Orange (#FB923C)  - Attention required                       │
│  ○ OFFLINE   - Gray (#6B7280)    - Disconnected/unknown                     │
│  ☢ CRITICAL  - Red (#EF4444)     - Immediate action required                │
│                                                                              │
│  TREND INDICATORS (SC-HMI-002)                                               │
│  ──────────────────────────────                                              │
│  ↑↑ rising_fast   - Rapid increase (>20%/min)                               │
│  ↑  rising        - Steady increase (5-20%/min)                             │
│  →  stable        - Within ±5%                                              │
│  ↓  falling       - Steady decrease (5-20%/min)                             │
│  ↓↓ falling_fast  - Rapid decrease (>20%/min)                               │
│                                                                              │
│  COMMAND STATE (Two-Step Commit, SC-HMI-003)                                 │
│  ─────────────────────────────────────────────                               │
│  ○ idle       - No command pending                                          │
│  ◎ armed      - Command armed, awaiting confirmation                        │
│  ◉ executing  - Command in progress                                         │
│  ✓ success    - Command completed successfully                              │
│  ✗ failed     - Command failed                                              │
│                                                                              │
│  STALENESS DECAY (SC-HMI-004)                                                │
│  ───────────────────────────────                                             │
│  ▓▓▓▓▓ Fresh    - <5s old, full intensity                                   │
│  ▓▓▓▓░ Recent   - 5-15s old, 80% intensity                                  │
│  ▓▓▓░░ Aging    - 15-30s old, 60% intensity                                 │
│  ▓▓░░░ Stale    - 30-60s old, 40% intensity                                 │
│  ▓░░░░ Expired  - >60s old, 20% intensity + warning                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Progress & Gauge Primitives

```elixir
defmodule Prajna.TUI.Primitives.Gauge do
  @moduledoc "Horizontal bar gauge with thresholds"

  use Prajna.TUI.Widget

  defstruct [:value, :max, :thresholds, :width, :show_percentage]

  @impl true
  def render(%__MODULE__{} = gauge, area, buffer) do
    # Calculate fill width
    ratio = gauge.value / gauge.max
    fill_width = round(area.width * ratio)

    # Determine color based on thresholds
    color = threshold_color(gauge.value, gauge.thresholds)

    # Draw filled portion
    buffer =
      0..(fill_width - 1)
      |> Enum.reduce(buffer, fn x, buf ->
        put_cell(buf, area.x + x, area.y, "▓", color)
      end)

    # Draw empty portion
    buffer =
      fill_width..(area.width - 1)
      |> Enum.reduce(buffer, fn x, buf ->
        put_cell(buf, area.x + x, area.y, "░", :gray)
      end)

    # Add percentage label if requested
    if gauge.show_percentage do
      label = "#{round(ratio * 100)}%"
      put_string(buffer, area.x + area.width - String.length(label), area.y, label)
    else
      buffer
    end
  end

  defp threshold_color(value, %{critical: c, warning: w, caution: ca}) do
    cond do
      value >= c -> :red
      value >= w -> :orange
      value >= ca -> :amber
      true -> :green
    end
  end
end
```

### 2.3 Sparkline Component

```elixir
defmodule Prajna.TUI.Primitives.Sparkline do
  @moduledoc """
  Compact time-series visualization using Unicode block characters.

  Block characters: ▁▂▃▄▅▆▇█ (8 levels for single-row height)
  """

  use Prajna.TUI.Widget

  @blocks ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

  defstruct [:data, :max, :min, :width, :color]

  @impl true
  def render(%__MODULE__{} = sparkline, area, buffer) do
    # Sample data to fit width
    samples = sample_data(sparkline.data, area.width)

    # Normalize to 0-7 range
    range = (sparkline.max || Enum.max(samples)) - (sparkline.min || 0)

    samples
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {value, index}, buf ->
      level = normalize_level(value, sparkline.min || 0, range)
      char = Enum.at(@blocks, level)
      put_cell(buf, area.x + index, area.y, char, sparkline.color || :cyan)
    end)
  end

  defp normalize_level(value, min, range) when range > 0 do
    min(7, max(0, round((value - min) / range * 7)))
  end
  defp normalize_level(_, _, _), do: 4

  defp sample_data(data, width) when length(data) <= width, do: data
  defp sample_data(data, width) do
    step = length(data) / width
    0..(width - 1)
    |> Enum.map(&Enum.at(data, round(&1 * step)))
  end
end
```

---

## 3. Composite Component Library

### 3.1 MetricCard Component

```elixir
defmodule Prajna.TUI.Components.MetricCard do
  @moduledoc """
  Displays a single metric with value, trend, sparkline, and staleness.

  Layout:
  ┌─ CPU ─────────────────┐
  │ 42% ↑   ▁▂▃▄▅▆▅▄▃▄▅▆ │
  │ [████████░░] Caution  │
  └───────────────────────┘
  """

  use Prajna.TUI.Widget

  alias Prajna.TUI.Primitives.{Gauge, Sparkline, StatusDot, TrendArrow}

  defstruct [:name, :value, :unit, :trend, :history, :thresholds, :last_update]

  @impl true
  def render(%__MODULE__{} = card, area, buffer) do
    # Border
    buffer = draw_border(buffer, area, card.name)

    # Inner area
    inner = shrink(area, 1)

    # Row 1: Value + Trend + Sparkline
    row1_y = inner.y
    buffer = put_string(buffer, inner.x, row1_y, format_value(card))
    buffer = TrendArrow.render(card.trend, %{x: inner.x + 6, y: row1_y}, buffer)
    buffer = Sparkline.render(
      %Sparkline{data: card.history, width: inner.width - 10},
      %{x: inner.x + 10, y: row1_y, width: inner.width - 10, height: 1},
      buffer
    )

    # Row 2: Gauge + Status
    row2_y = inner.y + 1
    gauge_width = inner.width - 10
    buffer = Gauge.render(
      %Gauge{value: card.value, max: 100, thresholds: card.thresholds, width: gauge_width},
      %{x: inner.x, y: row2_y, width: gauge_width, height: 1},
      buffer
    )

    status = status_from_thresholds(card.value, card.thresholds)
    staleness = DateTime.diff(DateTime.utc_now(), card.last_update, :second)
    buffer = StatusDot.render(status, staleness, %{x: inner.x + gauge_width + 2, y: row2_y}, buffer)

    buffer
  end

  defp format_value(%{value: v, unit: u}) when is_float(v), do: "#{Float.round(v, 1)}#{u}"
  defp format_value(%{value: v, unit: u}), do: "#{v}#{u}"
end
```

### 3.2 AlarmCard Component

```elixir
defmodule Prajna.TUI.Components.AlarmCard do
  @moduledoc """
  Displays an alarm with severity, source, message, and actions.

  Layout:
  ┌─────────────────────────────────────────────────────────────┐
  │ ⚠ CAUTION │ app-03 │ CPU trending high (45% ↑↑)            │
  │   Age: 12 min │ Occurrences: 3 │ Source: SmartMetrics      │
  │   [ACK] [SILENCE 1h] [ESCALATE] [VIEW NODE]                │
  └─────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  defstruct [:id, :severity, :source, :message, :triggered_at, :occurrences,
             :acknowledged, :focused]

  @severity_icons %{
    :critical => {"☢", :red},
    :warning => {"⛔", :orange},
    :caution => {"⚠", :amber},
    :advisory => {"ℹ", :cyan}
  }

  @impl true
  def render(%__MODULE__{} = alarm, area, buffer) do
    {icon, color} = Map.get(@severity_icons, alarm.severity, {"?", :gray})
    border_color = if alarm.focused, do: :cyan, else: :gray

    buffer = draw_border(buffer, area, nil, border_color)
    inner = shrink(area, 1)

    # Row 1: Severity + Source + Message
    row1 = "#{icon} #{format_severity(alarm.severity)} │ #{alarm.source} │ #{alarm.message}"
    buffer = put_string(buffer, inner.x, inner.y, row1, color)

    # Row 2: Metadata
    age = format_age(alarm.triggered_at)
    row2 = "  Age: #{age} │ Occurrences: #{alarm.occurrences} │ Source: #{alarm.source}"
    buffer = put_string(buffer, inner.x, inner.y + 1, row2, :dim)

    # Row 3: Actions
    actions = render_actions(alarm)
    buffer = put_string(buffer, inner.x + 2, inner.y + 2, actions)

    buffer
  end

  defp render_actions(%{acknowledged: true}) do
    "[SILENCE 1h] [ESCALATE] [VIEW NODE]"
  end
  defp render_actions(_) do
    "[ACK] [SILENCE 1h] [ESCALATE] [VIEW NODE]"
  end

  defp format_severity(:critical), do: "CRITICAL"
  defp format_severity(:warning), do: "WARNING"
  defp format_severity(:caution), do: "CAUTION"
  defp format_severity(:advisory), do: "ADVISORY"

  defp format_age(timestamp) do
    seconds = DateTime.diff(DateTime.utc_now(), timestamp, :second)
    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)} min"
      seconds < 86400 -> "#{div(seconds, 3600)}h"
      true -> "#{div(seconds, 86400)}d"
    end
  end
end
```

### 3.3 NodeCard Component

```elixir
defmodule Prajna.TUI.Components.NodeCard do
  @moduledoc """
  Displays a mesh node with health, metrics, and quick actions.

  Layout:
  ┌─ app-01 ──────────────────┐
  │ ● HEALTHY   CPU: 42% ↑    │
  │             MEM: 68% →    │
  │ Uptime: 25d  Lat: 12ms    │
  │ [RESTART] [LOGS] [SHELL]  │
  └───────────────────────────┘
  """

  use Prajna.TUI.Widget

  defstruct [:id, :name, :role, :health, :cpu, :cpu_trend, :mem, :mem_trend,
             :uptime, :latency, :focused, :selected]

  @role_icons %{
    :supervisor => "★",
    :controller => "◆",
    :worker => "●",
    :gateway => "◇"
  }

  @impl true
  def render(%__MODULE__{} = node, area, buffer) do
    role_icon = Map.get(@role_icons, node.role, "○")
    border_style = if node.selected, do: :double, else: :single
    border_color = if node.focused, do: :cyan, else: :gray

    buffer = draw_border(buffer, area, "#{role_icon} #{node.name}", border_color, border_style)
    inner = shrink(area, 1)

    # Row 1: Health + CPU
    health_dot = health_indicator(node.health)
    cpu_str = "CPU: #{node.cpu}% #{trend_arrow(node.cpu_trend)}"
    buffer = put_string(buffer, inner.x, inner.y, "#{health_dot} #{health_label(node.health)}", health_color(node.health))
    buffer = put_string(buffer, inner.x + 12, inner.y, cpu_str)

    # Row 2: Memory
    mem_str = "MEM: #{node.mem}% #{trend_arrow(node.mem_trend)}"
    buffer = put_string(buffer, inner.x + 12, inner.y + 1, mem_str)

    # Row 3: Uptime + Latency
    uptime_str = "Uptime: #{format_uptime(node.uptime)}"
    lat_str = "Lat: #{node.latency}ms"
    buffer = put_string(buffer, inner.x, inner.y + 2, "#{uptime_str}  #{lat_str}", :dim)

    # Row 4: Actions
    buffer = put_string(buffer, inner.x, inner.y + 3, "[RESTART] [LOGS] [SHELL]")

    buffer
  end

  defp health_indicator(:healthy), do: "●"
  defp health_indicator(:degraded), do: "◐"
  defp health_indicator(:critical), do: "☢"
  defp health_indicator(_), do: "○"

  defp health_label(:healthy), do: "HEALTHY"
  defp health_label(:degraded), do: "DEGRADED"
  defp health_label(:critical), do: "CRITICAL"
  defp health_label(_), do: "UNKNOWN"

  defp health_color(:healthy), do: :green
  defp health_color(:degraded), do: :amber
  defp health_color(:critical), do: :red
  defp health_color(_), do: :gray

  defp trend_arrow(:rising_fast), do: "↑↑"
  defp trend_arrow(:rising), do: "↑"
  defp trend_arrow(:stable), do: "→"
  defp trend_arrow(:falling), do: "↓"
  defp trend_arrow(:falling_fast), do: "↓↓"
  defp trend_arrow(_), do: ""

  defp format_uptime(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m"
  defp format_uptime(seconds) when seconds < 86400, do: "#{div(seconds, 3600)}h"
  defp format_uptime(seconds), do: "#{div(seconds, 86400)}d"
end
```

### 3.4 InsightCard Component

```elixir
defmodule Prajna.TUI.Components.InsightCard do
  @moduledoc """
  Displays an AI Copilot insight with confidence and actions.

  Layout:
  ┌─────────────────────────────────────────────────────────────┐
  │ ⚠ ANOMALY │ Confidence: 0.95 │ Related: app-03             │
  │ ──────────────────────────────────────────────────────────  │
  │ High CPU on app-03                                          │
  │ CPU at 45% with trend rising_fast (↑↑). This pattern often │
  │ precedes resource exhaustion within 2-4 hours.              │
  │                                                             │
  │ Recommended Actions:                                        │
  │ • Consider scaling or load balancing                        │
  │ • Check for runaway processes                               │
  │                                                             │
  │ [APPLY RECOMMENDATION] [DISMISS] [VIEW NODE]                │
  └─────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  defstruct [:id, :type, :confidence, :related_entity, :title, :description,
             :recommendations, :expires_at, :focused]

  @type_styles %{
    :summary => {"●", :cyan},
    :anomaly => {"⚠", :amber},
    :prediction => {"◇", :blue},
    :recommendation => {"★", :green},
    :correlation => {"◆", :purple}
  }

  @impl true
  def render(%__MODULE__{} = insight, area, buffer) do
    {icon, color} = Map.get(@type_styles, insight.type, {"?", :gray})
    border_color = if insight.focused, do: :cyan, else: :gray

    buffer = draw_border(buffer, area, nil, border_color)
    inner = shrink(area, 1)

    # Header row
    header = "#{icon} #{format_type(insight.type)} │ Confidence: #{Float.round(insight.confidence, 2)} │ Related: #{insight.related_entity}"
    buffer = put_string(buffer, inner.x, inner.y, header, color)

    # Separator
    buffer = put_string(buffer, inner.x, inner.y + 1, String.duplicate("─", inner.width), :dim)

    # Title
    buffer = put_string(buffer, inner.x, inner.y + 2, insight.title, :bold)

    # Description (word-wrapped)
    lines = word_wrap(insight.description, inner.width)
    buffer = lines
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {line, idx}, buf ->
        put_string(buf, inner.x, inner.y + 3 + idx, line)
      end)

    # Recommendations
    rec_start = inner.y + 3 + length(lines) + 1
    buffer = put_string(buffer, inner.x, rec_start, "Recommended Actions:", :dim)
    buffer = insight.recommendations
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {rec, idx}, buf ->
        put_string(buf, inner.x, rec_start + 1 + idx, "• #{rec}")
      end)

    # Actions
    action_y = rec_start + 1 + length(insight.recommendations) + 1
    buffer = put_string(buffer, inner.x, action_y, "[APPLY RECOMMENDATION] [DISMISS] [VIEW NODE]")

    buffer
  end

  defp format_type(:summary), do: "SUMMARY"
  defp format_type(:anomaly), do: "ANOMALY"
  defp format_type(:prediction), do: "PREDICTION"
  defp format_type(:recommendation), do: "RECOMMENDATION"
  defp format_type(:correlation), do: "CORRELATION"

  defp word_wrap(text, width) do
    text
    |> String.split(" ")
    |> Enum.reduce({[], ""}, fn word, {lines, current} ->
      if String.length(current) + String.length(word) + 1 <= width do
        {lines, if(current == "", do: word, else: "#{current} #{word}")}
      else
        {lines ++ [current], word}
      end
    end)
    |> then(fn {lines, last} -> lines ++ [last] end)
  end
end
```

---

## 4. Layout System

### 4.1 Constraint-Based Layout

```elixir
defmodule Prajna.TUI.Layout do
  @moduledoc """
  Constraint-based layout system inspired by Ratatui's Cassowary implementation.

  Supports:
  - Fixed: Exact size in characters
  - Percentage: Relative to parent
  - Min/Max: Bounded sizing
  - Fill: Expand to fill remaining space
  """

  @type constraint ::
    {:fixed, non_neg_integer()} |
    {:percentage, 0..100} |
    {:min, non_neg_integer()} |
    {:max, non_neg_integer()} |
    :fill

  @type direction :: :horizontal | :vertical

  defstruct [:direction, :constraints, :margin, :spacing]

  @doc """
  Split an area according to constraints.

  ## Examples

      iex> layout = %Layout{
      ...>   direction: :horizontal,
      ...>   constraints: [{:percentage, 30}, :fill, {:fixed, 20}]
      ...> }
      iex> Layout.split(layout, %{x: 0, y: 0, width: 100, height: 50})
      [
        %{x: 0, y: 0, width: 30, height: 50},
        %{x: 30, y: 0, width: 50, height: 50},
        %{x: 80, y: 0, width: 20, height: 50}
      ]
  """
  def split(%__MODULE__{direction: dir, constraints: constraints}, area) do
    total = if dir == :horizontal, do: area.width, else: area.height

    # First pass: resolve fixed and percentage
    {resolved, remaining} =
      constraints
      |> Enum.map(fn
        {:fixed, size} -> {:resolved, size}
        {:percentage, pct} -> {:resolved, div(total * pct, 100)}
        {:min, min} -> {:min, min}
        {:max, max} -> {:max, max}
        :fill -> :fill
      end)
      |> Enum.reduce({[], total}, fn
        {:resolved, size}, {acc, rem} -> {acc ++ [size], rem - size}
        other, {acc, rem} -> {acc ++ [other], rem}
      end)

    # Second pass: distribute remaining to fills
    fill_count = Enum.count(resolved, &(&1 == :fill))
    fill_size = if fill_count > 0, do: div(remaining, fill_count), else: 0

    final_sizes = Enum.map(resolved, fn
      :fill -> fill_size
      {:min, min} -> max(min, fill_size)
      {:max, max} -> min(max, fill_size)
      size when is_integer(size) -> size
    end)

    # Build areas
    {areas, _} = Enum.reduce(final_sizes, {[], 0}, fn size, {acc, offset} ->
      new_area = if dir == :horizontal do
        %{x: area.x + offset, y: area.y, width: size, height: area.height}
      else
        %{x: area.x, y: area.y + offset, width: area.width, height: size}
      end
      {acc ++ [new_area], offset + size}
    end)

    areas
  end
end
```

### 4.2 Grid Layout

```elixir
defmodule Prajna.TUI.Layout.Grid do
  @moduledoc """
  Grid layout with rows and columns of varying sizes.

  ## Example

      Grid.new()
      |> Grid.row([{:fixed, 3}])                    # Header
      |> Grid.row([{:percentage, 30}, :fill])       # Sidebar + Content
      |> Grid.row([{:fixed, 1}])                    # Footer
      |> Grid.render(area)
  """

  defstruct rows: [], gap: 0

  def new(opts \\ []) do
    %__MODULE__{gap: Keyword.get(opts, :gap, 0)}
  end

  def row(%__MODULE__{} = grid, columns) when is_list(columns) do
    %{grid | rows: grid.rows ++ [{:row, columns}]}
  end

  def render(%__MODULE__{rows: rows, gap: gap}, area) do
    # Split vertically for rows
    row_heights = Enum.map(rows, fn {:row, _} -> :fill end)  # Simplified
    row_areas = Layout.split(%Layout{direction: :vertical, constraints: row_heights}, area)

    # Split each row horizontally
    Enum.zip(rows, row_areas)
    |> Enum.map(fn {{:row, columns}, row_area} ->
      Layout.split(%Layout{direction: :horizontal, constraints: columns}, row_area)
    end)
  end
end
```

---

## 5. Screen Composition

### 5.1 Main Dashboard Screen

```elixir
defmodule Prajna.TUI.Screens.Dashboard do
  @moduledoc """
  Main C3I Cockpit dashboard screen.

  Layout:
  ┌─────────────────────────────────────────────────────────────────┐
  │ PRAJNA C3I MESH COCKPIT │ ● HEALTHY │ 94% │ 2025-12-27 14:32   │ <- StatusBar
  ├─────────────────────────────────────────────────────────────────┤
  │ [Overview] [Mesh] [Alarms] [Commands] [Copilot] [Containers]   │ <- TabBar
  ├───────────────────────────────────────────────────────────────── │
  │                                                                 │
  │  ┌─ SAFETY STATUS ────────────┐  ┌─ ACTIVE ALARMS (2) ──────┐  │
  │  │ Guardian: ● DMS: ● Env: ●  │  │ ⚠ app-03: CPU high       │  │
  │  └────────────────────────────┘  │ ℹ obs: Latency elevated  │  │
  │                                  └───────────────────────────┘  │
  │  ┌─ MESH NODES (5) ──────────────────────────────────────────┐  │
  │  │ app-01 CPU:42% ● │ app-02 CPU:38% ● │ app-03 CPU:45% ⚠   │  │
  │  │ app-04 CPU:31% ● │ app-05 CPU:28% ●                       │  │
  │  └───────────────────────────────────────────────────────────┘  │
  │                                                                 │
  │  ┌─ CONTAINERS ─────────┐  ┌─ AI COPILOT ───────────────────┐  │
  │  │ APP ● 4000 [████░]   │  │ ● System healthy (0.95)        │  │
  │  │ DB  ● 5433 [███░░]   │  │ ⚠ CPU prediction: high in 2h  │  │
  │  │ OBS ⚠ 8123 [██░░░]   │  └─────────────────────────────────┘  │
  │  └──────────────────────┘                                       │
  │                                                                 │
  │  ┌─ QUICK METRICS ─────────────────────────────────────────────┐│
  │  │ CPU  ▂▃▄▅▆▅▄▃▄▅▆▇▆▅  38%  │  MEM  ▅▅▆▆▆▆▆▆▆▆  65%         ││
  │  └─────────────────────────────────────────────────────────────┘│
  └─────────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  alias Prajna.TUI.Components.{MetricCard, AlarmCard, NodeCard, InsightCard}
  alias Prajna.TUI.Layout.Grid

  defstruct [:model]

  @impl true
  def render(%__MODULE__{model: model}, area, buffer) do
    # Define layout grid
    grid = Grid.new(gap: 1)
      |> Grid.row([{:fixed, 3}])                           # StatusBar
      |> Grid.row([{:fixed, 1}])                           # TabBar
      |> Grid.row([{:percentage, 15}, {:percentage, 40}])  # Safety + Alarms
      |> Grid.row([:fill])                                  # Nodes
      |> Grid.row([{:percentage, 30}, :fill])              # Containers + Copilot
      |> Grid.row([{:fixed, 3}])                           # Quick Metrics

    [[status_area], [tab_area], [safety_area, alarms_area],
     [nodes_area], [containers_area, copilot_area], [metrics_area]] =
      Grid.render(grid, area)

    # Render each section
    buffer = render_status_bar(model, status_area, buffer)
    buffer = render_tab_bar(model.active_tab, tab_area, buffer)
    buffer = render_safety_status(model, safety_area, buffer)
    buffer = render_alarms(model.alarms, alarms_area, buffer)
    buffer = render_nodes(model.nodes, nodes_area, buffer)
    buffer = render_containers(model.containers, containers_area, buffer)
    buffer = render_copilot(model.insights, copilot_area, buffer)
    buffer = render_quick_metrics(model.metrics, metrics_area, buffer)

    buffer
  end

  defp render_status_bar(model, area, buffer) do
    health = aggregate_health(model)
    score = health_score(model)
    time = format_time(DateTime.utc_now())

    line = "PRAJNA C3I MESH COCKPIT │ #{health_dot(health)} #{health} │ #{score}% │ #{time}"
    put_string_centered(buffer, area, line)
  end

  defp render_tab_bar(active, area, buffer) do
    tabs = [:overview, :mesh, :alarms, :commands, :copilot, :containers, :settings]

    tabs
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {tab, idx}, buf ->
      label = "[#{format_tab(tab)}]"
      style = if tab == active, do: :bold, else: :normal
      put_string(buf, area.x + idx * 12, area.y, label, style)
    end)
  end

  # ... additional render helpers
end
```

---

## 6. Event Handling & Input

### 6.1 Keyboard Navigation

```elixir
defmodule Prajna.TUI.Input do
  @moduledoc """
  Keyboard input handling with context-aware bindings.

  Inspired by lazygit's guard-based keybinding system.
  """

  @global_bindings %{
    {:key, ?q} => :quit,
    {:key, ?:} => :command_mode,
    {:key, ?\t} => :next_tab,
    {:key, {:shift, ?\t}} => :prev_tab,
    {:key, ?1} => {:goto_tab, :overview},
    {:key, ?2} => {:goto_tab, :mesh},
    {:key, ?3} => {:goto_tab, :alarms},
    {:key, ?4} => {:goto_tab, :commands},
    {:key, ?5} => {:goto_tab, :copilot},
    {:key, ?6} => {:goto_tab, :containers},
    {:key, ??} => :show_help
  }

  @context_bindings %{
    alarms: %{
      {:key, ?a} => :ack_alarm,
      {:key, ?s} => :silence_alarm,
      {:key, ?e} => :escalate_alarm,
      {:key, ?f} => :filter_alarms,
      {:key, ?\r} => :view_alarm_detail
    },
    commands: %{
      {:key, ?r} => :arm_restart,
      {:key, ?i} => :arm_isolate,
      {:key, ?d} => :arm_drain,
      {:key, ?\r} => :confirm_armed,
      {:key, ?\e} => :cancel_armed
    },
    mesh: %{
      {:key, ?\r} => :select_node,
      {:key, ?l} => :view_logs,
      {:key, ?s} => :shell_into,
      {:key, ?h} => :health_check
    }
  }

  def handle_input(key, %{active_tab: tab, modal: modal} = model) do
    cond do
      # Modal has priority
      modal != nil ->
        handle_modal_input(key, modal, model)

      # Check global bindings
      action = Map.get(@global_bindings, key) ->
        {:action, action}

      # Check context bindings
      context_map = Map.get(@context_bindings, tab, %{}) ->
        case Map.get(context_map, key) do
          nil -> :unhandled
          action -> {:action, action}
        end

      true ->
        :unhandled
    end
  end

  defp handle_modal_input(key, {:confirm, _command} = modal, model) do
    case key do
      {:key, ?\r} -> {:action, :execute_confirmed}
      {:key, ?\e} -> {:action, :cancel_modal}
      {:key, char} when char in ?0..?9 -> {:action, {:input_code, char}}
      _ -> :unhandled
    end
  end
end
```

### 6.2 Two-Step Commit Flow

```elixir
defmodule Prajna.TUI.TwoStepCommit do
  @moduledoc """
  Two-step commit implementation for critical commands.

  Flow:
  1. User initiates critical command → ARM
  2. System displays confirmation modal with countdown
  3. User enters confirmation code → CONFIRM
  4. Command executes with feedback

  Compliant with SC-HMI-003: Two-Step Commit.
  """

  defstruct [:command, :target, :armed_at, :expires_at, :confirmation_code]

  @arm_timeout_seconds 60

  def arm(command, target) do
    now = DateTime.utc_now()
    code = generate_confirmation_code()

    %__MODULE__{
      command: command,
      target: target,
      armed_at: now,
      expires_at: DateTime.add(now, @arm_timeout_seconds, :second),
      confirmation_code: code
    }
  end

  def confirm(%__MODULE__{} = armed, entered_code) do
    cond do
      DateTime.compare(DateTime.utc_now(), armed.expires_at) == :gt ->
        {:error, :expired}

      entered_code != armed.confirmation_code ->
        {:error, :invalid_code}

      true ->
        {:ok, armed.command, armed.target}
    end
  end

  def remaining_seconds(%__MODULE__{expires_at: expires}) do
    max(0, DateTime.diff(expires, DateTime.utc_now(), :second))
  end

  defp generate_confirmation_code do
    :rand.uniform(9999)
    |> Integer.to_string()
    |> String.pad_leading(4, "0")
  end
end
```

---

## 7. Real-Time Updates

### 7.1 PubSub Integration

```elixir
defmodule Prajna.TUI.Subscriptions do
  @moduledoc """
  PubSub subscription management for real-time updates.
  """

  @topics [
    "prajna:metrics",
    "prajna:alarms",
    "prajna:insights",
    "prajna:container_health",
    "prajna:node_status",
    "prajna:ooda_cycle"
  ]

  def subscribe_all do
    Enum.each(@topics, fn topic ->
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, topic)
    end)
  end

  def handle_pubsub_message(message, model) do
    case message do
      {:metric_update, node_id, metrics} ->
        update_metrics(model, node_id, metrics)

      {:alarm_event, alarm} ->
        update_alarms(model, alarm)

      {:insight, insight} ->
        add_insight(model, insight)

      {:container_health, container_id, health} ->
        update_container(model, container_id, health)

      {:node_status, node_id, status} ->
        update_node(model, node_id, status)

      {:ooda_cycle, phase, metrics} ->
        update_ooda(model, phase, metrics)

      _ ->
        model
    end
  end

  defp update_metrics(model, node_id, metrics) do
    metrics_with_staleness =
      Map.update(model.metrics, node_id, metrics, fn existing ->
        Map.merge(existing, metrics)
        |> Map.put(:last_update, DateTime.utc_now())
      end)

    %{model | metrics: metrics_with_staleness}
  end

  # ... additional update handlers
end
```

### 7.2 Staleness Tracking

```elixir
defmodule Prajna.TUI.Staleness do
  @moduledoc """
  Tracks metric staleness and triggers visual decay.

  Compliant with SC-HMI-004: Staleness Decay.
  """

  @thresholds %{
    fresh: 5,      # 0-5s
    recent: 15,    # 5-15s
    aging: 30,     # 15-30s
    stale: 60,     # 30-60s
    expired: :infinity
  }

  def staleness_level(last_update) do
    age = DateTime.diff(DateTime.utc_now(), last_update, :second)

    cond do
      age < @thresholds.fresh -> :fresh
      age < @thresholds.recent -> :recent
      age < @thresholds.aging -> :aging
      age < @thresholds.stale -> :stale
      true -> :expired
    end
  end

  def opacity(level) do
    case level do
      :fresh -> 1.0
      :recent -> 0.8
      :aging -> 0.6
      :stale -> 0.4
      :expired -> 0.2
    end
  end

  def should_warn?(level), do: level in [:stale, :expired]
end
```

---

## 8. Faro-Inspired Correlation Widgets

### 8.1 TraceWaterfall Component

```elixir
defmodule Prajna.TUI.Components.TraceWaterfall do
  @moduledoc """
  Displays distributed trace as waterfall diagram (Grafana Faro pattern).

  Layout:
  ┌─ TRACE: abc123 ─────────────────────────────────────────────────┐
  │ Total: 234ms │ Spans: 12 │ Services: 4                         │
  ├─────────────────────────────────────────────────────────────────┤
  │ phoenix.endpoint     ████░░░░░░░░░░░░░░░░░░░░░░░░░░░   2ms    │
  │ └─ controller.create ░░████████████████░░░░░░░░░░░░░░░   45ms  │
  │    └─ ecto.query     ░░░░░░░░░░░░░░░░░████████████████░ 180ms ⚠│
  │       └─ pubsub      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██░   3ms  │
  └─────────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  defstruct [:trace_id, :spans, :total_duration, :focused_span]

  @impl true
  def render(%__MODULE__{} = waterfall, area, buffer) do
    buffer = draw_border(buffer, area, "TRACE: #{waterfall.trace_id}")
    inner = shrink(area, 1)

    # Header row
    header = "Total: #{waterfall.total_duration}ms │ Spans: #{length(waterfall.spans)} │ Services: #{count_services(waterfall.spans)}"
    buffer = put_string(buffer, inner.x, inner.y, header, :dim)

    # Separator
    buffer = put_string(buffer, inner.x, inner.y + 1, String.duplicate("─", inner.width), :dim)

    # Render spans as waterfall
    waterfall.spans
    |> build_span_tree()
    |> flatten_tree(0)
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {{span, depth}, idx}, buf ->
      render_span(span, depth, waterfall.total_duration, inner, idx + 2, buf)
    end)
  end

  defp render_span(span, depth, total_ms, area, row_offset, buffer) do
    # Calculate bar position and width
    start_pct = span.start_offset / total_ms
    width_pct = span.duration / total_ms
    bar_start = round(20 * start_pct)
    bar_width = max(1, round(20 * width_pct))

    # Indent based on depth
    indent = String.duplicate("  ", depth) <> (if depth > 0, do: "└─ ", else: "")
    name = "#{indent}#{span.name}"

    # Draw name
    y = area.y + row_offset
    buffer = put_string(buffer, area.x, y, String.pad_trailing(name, 20))

    # Draw timing bar
    bar = String.duplicate("░", bar_start) <>
          String.duplicate("█", bar_width) <>
          String.duplicate("░", 20 - bar_start - bar_width)

    color = if span.is_slow, do: :amber, else: :cyan
    buffer = put_string(buffer, area.x + 22, y, bar, color)

    # Draw duration
    duration_str = "#{span.duration}ms"
    buffer = put_string(buffer, area.x + 44, y, duration_str)

    # Slow indicator
    if span.is_slow do
      put_string(buffer, area.x + 52, y, "⚠", :amber)
    else
      buffer
    end
  end
end
```

### 8.2 EventTimeline Component

```elixir
defmodule Prajna.TUI.Components.EventTimeline do
  @moduledoc """
  Chronological timeline of correlated events (Faro pattern).

  Layout:
  ┌─ CORRELATED EVENTS ─────────────────────────────────────────────┐
  │                                                                  │
  │  14:32:43 ─●─ Motion detected (CAM-042)                         │
  │            │                                                     │
  │  14:32:45 ─●─ Door contact triggered (SNS-002)    ← ALARM       │
  │            │                                                     │
  │  14:32:47 ─●─ Access log: John Doe badge swipe (RDR-001)        │
  │            │                                                     │
  │  14:33:12 ─○─ Alarm acknowledged by operator                    │
  │                                                                  │
  └──────────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  defstruct [:events, :focus_event, :time_range]

  @impl true
  def render(%__MODULE__{} = timeline, area, buffer) do
    buffer = draw_border(buffer, area, "CORRELATED EVENTS")
    inner = shrink(area, 1)

    timeline.events
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {event, idx}, buf ->
      render_event(event, inner, idx * 2, timeline.focus_event, buf)
    end)
  end

  defp render_event(event, area, row_offset, focus_id, buffer) do
    y = area.y + row_offset
    time_str = format_time(event.timestamp)
    icon = event_icon(event.type)
    color = if event.id == focus_id, do: :cyan, else: :normal

    # Time column
    buffer = put_string(buffer, area.x, y, time_str, :dim)

    # Timeline connector
    buffer = put_string(buffer, area.x + 10, y, "─#{icon}─", color)

    # Event description
    desc = event.description
    buffer = put_string(buffer, area.x + 14, y, desc, color)

    # Highlight marker
    buffer = if event.is_trigger do
      put_string(buffer, area.x + 14 + String.length(desc) + 2, y, "← ALARM", :amber)
    else
      buffer
    end

    # Vertical connector to next event
    if row_offset < (length(area.events) - 1) * 2 do
      put_string(buffer, area.x + 11, y + 1, "│", :dim)
    else
      buffer
    end
  end

  defp event_icon(:trigger), do: "●"
  defp event_icon(:correlated), do: "●"
  defp event_icon(:action), do: "○"
  defp event_icon(_), do: "·"
end
```

### 8.3 LogViewer Component

```elixir
defmodule Prajna.TUI.Components.LogViewer do
  @moduledoc """
  Contextual log viewer with filtering (Faro LGTM pattern).

  Layout:
  ┌─ LOGS ─────────────────────────────────────────────────────────────┐
  │ Filter: [INFO+] Search: [_____________]   [LIVE TAIL: ON]         │
  ├────────────────────────────────────────────────────────────────────┤
  │ 14:32:45.123 INFO  [SmartMetrics] Recorded metric: cpu.app-03     │
  │ 14:32:45.234 WARN  [AiCopilot] Anomaly detected: high CPU         │
  │ 14:32:45.345 INFO  [Orchestrator] Insight published               │
  │ 14:32:46.123 DEBUG [PubSub] Broadcast: prajna:metrics             │
  │ 14:32:46.234 INFO  [Sentinel] Heartbeat from indrajaal-2          │
  │ 14:32:46.345 INFO  [OODA.Loop] Cycle completed: 0.847s            │
  │ 14:32:47.123 INFO  [Guardian] Safety check passed                 │
  └────────────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  defstruct [:logs, :filter_level, :search_term, :live_tail, :scroll_offset]

  @level_colors %{
    :debug => :dim,
    :info => :normal,
    :warn => :amber,
    :error => :red
  }

  @impl true
  def render(%__MODULE__{} = viewer, area, buffer) do
    buffer = draw_border(buffer, area, "LOGS")
    inner = shrink(area, 1)

    # Filter bar
    filter_str = "Filter: [#{format_level(viewer.filter_level)}] Search: [#{String.pad_trailing(viewer.search_term || "", 15)}]"
    tail_str = "[LIVE TAIL: #{if viewer.live_tail, do: "ON", else: "OFF"}]"
    buffer = put_string(buffer, inner.x, inner.y, filter_str)
    buffer = put_string(buffer, inner.x + inner.width - 16, inner.y, tail_str)

    # Separator
    buffer = put_string(buffer, inner.x, inner.y + 1, String.duplicate("─", inner.width), :dim)

    # Log entries
    visible_logs = viewer.logs
      |> filter_logs(viewer.filter_level, viewer.search_term)
      |> Enum.drop(viewer.scroll_offset || 0)
      |> Enum.take(inner.height - 2)

    visible_logs
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {log, idx}, buf ->
      render_log_line(log, inner, idx + 2, buf)
    end)
  end

  defp render_log_line(log, area, row_offset, buffer) do
    y = area.y + row_offset
    color = Map.get(@level_colors, log.level, :normal)

    time_str = format_timestamp(log.timestamp)
    level_str = String.pad_trailing(String.upcase(to_string(log.level)), 5)
    source_str = "[#{log.source}]"
    message = log.message

    line = "#{time_str} #{level_str} #{String.pad_trailing(source_str, 20)} #{message}"
    put_string(buffer, area.x, y, String.slice(line, 0, area.width), color)
  end
end
```

### 8.4 MetricCorrelation Component

```elixir
defmodule Prajna.TUI.Components.MetricCorrelation do
  @moduledoc """
  Shows metrics from related entities (Faro correlation pattern).

  Layout:
  ┌─ RELATED METRICS ──────────────────────────────────────────────────┐
  │                                                                     │
  │  Entity: app-03                                                     │
  │  ├─ CPU  ▂▃▄▅▆▇█▇▆▅▄▅▆▇█▇▆▅  45% ↑↑  ← Anomaly detected           │
  │  ├─ MEM  ▅▅▅▅▅▆▆▆▆▆▆▆▆▆▆▆▆▆  68% →                                 │
  │  └─ LAT  ▁▁▁▁▂▂▃▃▄▄▃▃▂▂▁▁▁▁  12ms                                  │
  │                                                                     │
  │  Entity: indrajaal-db                                               │
  │  ├─ CONN ████████░░░░░░░░░░░░  23/100                              │
  │  ├─ TXN  ▃▃▄▄▅▅▆▆▅▅▄▄▃▃▄▄▅▅  145/s                                 │
  │  └─ DISK ██████░░░░░░░░░░░░░░  62%                                  │
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘
  """

  use Prajna.TUI.Widget

  alias Prajna.TUI.Primitives.Sparkline

  defstruct [:entities, :anomaly_metrics]

  @impl true
  def render(%__MODULE__{} = correlation, area, buffer) do
    buffer = draw_border(buffer, area, "RELATED METRICS")
    inner = shrink(area, 1)

    row = 0
    Enum.reduce(correlation.entities, {buffer, row}, fn entity, {buf, r} ->
      {buf, r} = render_entity(entity, inner, r, correlation.anomaly_metrics, buf)
      {buf, r + 1}  # Gap between entities
    end)
    |> elem(0)
  end

  defp render_entity(entity, area, row_offset, anomalies, buffer) do
    y = area.y + row_offset

    # Entity header
    buffer = put_string(buffer, area.x, y, "Entity: #{entity.id}")

    # Metrics
    {buffer, final_row} = entity.metrics
      |> Enum.with_index()
      |> Enum.reduce({buffer, row_offset + 1}, fn {{name, data}, idx}, {buf, r} ->
        is_last = idx == length(entity.metrics) - 1
        prefix = if is_last, do: "└─", else: "├─"
        is_anomaly = {entity.id, name} in anomalies

        buf = render_metric_line(name, data, prefix, is_anomaly, area, r, buf)
        {buf, r + 1}
      end)

    {buffer, final_row}
  end

  defp render_metric_line(name, data, prefix, is_anomaly, area, row_offset, buffer) do
    y = area.y + row_offset

    # Prefix and name
    buffer = put_string(buffer, area.x, y, "#{prefix} #{String.pad_trailing(name, 4)}")

    # Sparkline
    sparkline_area = %{x: area.x + 9, y: y, width: 20, height: 1}
    buffer = Sparkline.render(%Sparkline{data: data.history}, sparkline_area, buffer)

    # Current value and trend
    value_str = "#{data.value}#{data.unit} #{trend_arrow(data.trend)}"
    color = if is_anomaly, do: :amber, else: :normal
    buffer = put_string(buffer, area.x + 31, y, value_str, color)

    # Anomaly marker
    if is_anomaly do
      put_string(buffer, area.x + 45, y, "← Anomaly detected", :amber)
    else
      buffer
    end
  end
end
```

---

## 9. STAMP Safety Constraints

### 9.1 HMI Safety Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-HMI-001 | Dark cockpit colors (ISA-101) | Color palette: gray default, deviation colors |
| SC-HMI-002 | Trend indicators always visible | Trend arrows on all metrics |
| SC-HMI-003 | Two-step commit for critical ops | TwoStepCommit module |
| SC-HMI-004 | Staleness decay visual indicator | Staleness module with opacity |
| SC-HMI-005 | Keyboard accessibility | Full keyboard navigation |
| SC-HMI-006 | Action confirmation feedback | Toast notifications |
| SC-HMI-007 | AI advisory disclaimer | "ADVISORY ONLY" labels |

### 9.2 Information Safety Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-INFO-001 | Metric cardinality bounds | MaxSamples config |
| SC-INFO-002 | Event ordering guaranteed | Timestamp ordering |
| SC-INFO-003 | Entity state consistency | Single source of truth |
| SC-INFO-004 | Relationship integrity | Graph validation |

### 9.3 Behavioral Safety Constraints

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-BEH-001 | State machine consistency | FSM module |
| SC-BEH-002 | Threshold hysteresis | Debounce on transitions |
| SC-BEH-003 | Cascade depth limits | Max propagation depth |
| SC-BEH-004 | Temporal ordering | Logical clocks |

---

## 10. Implementation Roadmap

### Phase 1: Core Framework
- [ ] Widget trait system
- [ ] Layout primitives
- [ ] Buffer rendering
- [ ] Input handling

### Phase 2: Primitive Components
- [ ] Status indicators
- [ ] Gauge/progress bars
- [ ] Sparklines
- [ ] Borders/boxes

### Phase 3: Composite Components
- [ ] MetricCard
- [ ] AlarmCard
- [ ] NodeCard
- [ ] InsightCard

### Phase 4: Screens
- [ ] Dashboard
- [ ] Mesh topology
- [ ] Alarm center
- [ ] Command center
- [ ] AI Copilot
- [ ] Containers

### Phase 5: Integration
- [ ] PubSub subscriptions
- [ ] Real-time updates
- [ ] Staleness tracking
- [ ] Two-step commit

---

## Appendix A: Color Palette

```
Background:  #111827 (gray-900)
Surface:     #1F2937 (gray-800)
Border:      #374151 (gray-700)
Text:        #D1D5DB (gray-300)
Dim:         #6B7280 (gray-500)

Green:       #22C55E (healthy)
Amber:       #F59E0B (caution)
Orange:      #FB923C (warning)
Red:         #EF4444 (critical)
Cyan:        #06B6D4 (advisory/focus)
Blue:        #3B82F6 (info)
Purple:      #A855F7 (correlation)
```

## Appendix B: Unicode Characters Reference

```
Status:     ● ◐ ○ ◎ ⊙ ✓ ✗ ☢ ⛔ ⚠ ℹ
Arrows:     ↑ ↓ → ← ↑↑ ↓↓ ⟳ ◀ ▶
Blocks:     ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ░ ▓
Borders:    ┌ ┐ └ ┘ ─ │ ├ ┤ ┬ ┴ ┼
Double:     ╔ ╗ ╚ ╝ ═ ║ ╠ ╣ ╦ ╩ ╬
Roles:      ★ ◆ ● ◇ ○
Progress:   ▰ ▱
```

---

**Document Control**
- Author: Claude Opus 4.5
- Framework: SOPv5.11 + STAMP + C3I Dark Cockpit
- References: Bubbletea, Ratatui, termui, tview, Cursive
