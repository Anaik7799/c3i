defmodule IndrajaalWeb.PrajnaComponents do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Shared Component Library

  WHAT: Provides reusable UI components for the PRAJNA Cockpit following
        NASA-STD-3000 Dark Cockpit design principles.

  WHY: Ensures visual consistency across all 12+ PRAJNA screens:
       - Status indicators (●/◐/○)
       - Trend vectors (↑↑/↑/→/↓/↓↓)
       - Sparklines for metrics
       - Metric cards with staleness detection
       - Navigation tabs
       - Two-step commit modals

  DESIGN PRINCIPLES:
    1. Dark Cockpit - Gray defaults, color for exceptions only
    2. Management by Exception - Only deviations highlighted
    3. Analog over Digital - Bars and sparklines preferred
    4. Staleness Decay - Visual degradation when data stale

  STAMP Compliance:
    - SC-HMI-001: Dark Cockpit defaults
    - SC-HMI-002: Trend indicators mandatory
    - SC-HMI-003: Staleness after 5 seconds
    - SC-HMI-004: Two-step commit for critical
    - SC-HMI-008: Contrast ratio 4.5:1

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | NASA-STD-3000, MIL-STD-1472H, NUREG-0700 |
  """

  use Phoenix.Component

  # ═══════════════════════════════════════════════════════════════════════════
  # PRODUCT LOGO (SC-HMI-010 Color Rich)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders the Indrajaal product logo.
  """
  attr :class, :string, default: "h-12 w-12"
  attr :vibrant, :boolean, default: true

  def product_logo(assigns) do
    ~H"""
    <svg
      viewBox="0 0 100 100"
      class={[@class, @vibrant && "health-pulse"]}
      xmlns="http://www.w3.org/2000/svg"
    >
      <%!-- Fractal Net Nodes --%>
      <circle cx="50" cy="50" r="10" fill="currentColor" class="text-accent-primary" />
      <circle cx="20" cy="20" r="6" fill="currentColor" class="text-accent-secondary" opacity="0.8" />
      <circle cx="80" cy="20" r="6" fill="currentColor" class="text-accent-secondary" opacity="0.8" />
      <circle cx="20" cy="80" r="6" fill="currentColor" class="text-accent-secondary" opacity="0.8" />
      <circle cx="80" cy="80" r="6" fill="currentColor" class="text-accent-secondary" opacity="0.8" />

      <%!-- Interconnecting Lines (The Net) --%>
      <g stroke="currentColor" stroke-width="1.5" class="text-border-theme-primary" opacity="0.6">
        <line x1="50" y1="50" x2="20" y2="20" />
        <line x1="50" y1="50" x2="80" y2="20" />
        <line x1="50" y1="50" x2="20" y2="80" />
        <line x1="50" y1="50" x2="80" y2="80" />
        <line x1="20" y1="20" x2="80" y2="20" />
        <line x1="80" y1="20" x2="80" y2="80" />
        <line x1="80" y1="80" x2="20" y2="80" />
        <line x1="20" y1="80" x2="20" y2="20" />
      </g>

      <%!-- Inner Core Glow --%>
      <circle cx="50" cy="50" r="4" fill="white" opacity="0.4">
        <animate attributeName="opacity" values="0.2;0.6;0.2" dur="2s" repeatCount="indefinite" />
      </circle>
    </svg>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # STATUS INDICATORS (SC-HMI-001)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a status indicator dot with color based on state.

  ## Examples

      <.status_indicator state={:connected} />
      <.status_indicator state={:stale} />
      <.status_indicator state={:disconnected} />
  """
  attr :state, :atom, required: true, values: [:connected, :stale, :disconnected]
  attr :class, :string, default: ""

  def status_indicator(assigns) do
    ~H"""
    <span class={["inline-block w-2 h-2 rounded-full", status_color(@state), @class]} />
    """
  end

  defp status_color(:connected), do: "bg-green-500"
  defp status_color(:stale), do: "bg-amber-500 animate-pulse"
  defp status_color(:disconnected), do: "bg-gray-500"

  @doc """
  Renders a status icon with unicode character.

  ## Examples

      <.status_icon state={:healthy} />
      <.status_icon state={:warning} />
      <.status_icon state={:critical} />
  """
  attr :state, :atom, required: true
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :class, :string, default: ""

  def status_icon(assigns) do
    ~H"""
    <span class={[status_icon_class(@state), size_class(@size), @class]}>
      {status_icon_char(@state)}
    </span>
    """
  end

  defp status_icon_char(:healthy), do: "●"
  defp status_icon_char(:normal), do: "●"
  defp status_icon_char(:connected), do: "●"
  defp status_icon_char(:stale), do: "◐"
  defp status_icon_char(:advisory), do: "ℹ"
  defp status_icon_char(:caution), do: "⚠"
  defp status_icon_char(:warning), do: "⛔"
  defp status_icon_char(:critical), do: "☢"
  defp status_icon_char(:disconnected), do: "○"
  defp status_icon_char(:error), do: "✗"
  defp status_icon_char(:success), do: "✓"
  defp status_icon_char(_), do: "·"

  defp status_icon_class(:healthy), do: "text-gray-500"
  defp status_icon_class(:normal), do: "text-gray-500"
  defp status_icon_class(:connected), do: "text-green-500"
  defp status_icon_class(:stale), do: "text-amber-500"
  defp status_icon_class(:advisory), do: "text-cyan-500"
  defp status_icon_class(:caution), do: "text-amber-500"
  defp status_icon_class(:warning), do: "text-red-500"
  defp status_icon_class(:critical), do: "text-red-600 animate-pulse"
  defp status_icon_class(:disconnected), do: "text-gray-400"
  defp status_icon_class(:error), do: "text-red-500"
  defp status_icon_class(:success), do: "text-green-500"
  defp status_icon_class(_), do: "text-gray-400"

  defp size_class(:sm), do: "text-xs"
  defp size_class(:md), do: "text-sm"
  defp size_class(:lg), do: "text-lg"

  # ═══════════════════════════════════════════════════════════════════════════
  # TREND INDICATORS (SC-HMI-002)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a trend indicator arrow.

  ## Examples

      <.trend_indicator trend={:rising_fast} />
      <.trend_indicator trend={:stable} />
      <.trend_indicator trend={:falling} />
  """
  attr :trend, :atom,
    required: true,
    values: [:rising_fast, :rising, :stable, :falling, :falling_fast, :unknown]

  attr :class, :string, default: ""

  def trend_indicator(assigns) do
    ~H"""
    <span class={[trend_color(@trend), @class]}>
      {trend_icon(@trend)}
    </span>
    """
  end

  defp trend_icon(:rising_fast), do: "↑↑"
  defp trend_icon(:rising), do: "↑"
  defp trend_icon(:stable), do: "→"
  defp trend_icon(:falling), do: "↓"
  defp trend_icon(:falling_fast), do: "↓↓"
  defp trend_icon(:unknown), do: "?"

  defp trend_color(:rising_fast), do: "text-red-500"
  defp trend_color(:rising), do: "text-amber-500"
  defp trend_color(:stable), do: "text-gray-500"
  defp trend_color(:falling), do: "text-cyan-500"
  defp trend_color(:falling_fast), do: "text-blue-500"
  defp trend_color(:unknown), do: "text-gray-400"

  # ═══════════════════════════════════════════════════════════════════════════
  # SPARKLINES (SC-TEL-003)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a sparkline from a list of values using Unicode block characters.

  ## Examples

      <.sparkline values={[10, 20, 30, 25, 40]} />
      <.sparkline values={metrics} width={20} class="text-cyan-500" />
  """
  attr :values, :list, default: []
  attr :width, :integer, default: 20
  attr :class, :string, default: "text-gray-500"
  attr :empty_char, :string, default: "░"

  @sparkline_chars ~c[▁▂▃▄▅▆▇█]

  def sparkline(assigns) do
    rendered = render_sparkline(assigns.values, assigns.width, assigns.empty_char)
    assigns = assign(assigns, :rendered, rendered)

    ~H"""
    <span class={["font-mono text-xs tracking-tighter", @class]}>
      {@rendered}
    </span>
    """
  end

  defp render_sparkline([], width, empty_char) do
    String.duplicate(empty_char, width)
  end

  defp render_sparkline(values, width, empty_char) when values == [] do
    String.duplicate(empty_char, width)
  end

  defp render_sparkline(values, width, empty_char) do
    recent = values |> Enum.take(width) |> Enum.reverse()

    if recent == [] do
      String.duplicate(empty_char, width)
    else
      min_val = Enum.min(recent)
      max_val = Enum.max(recent)
      range = max(0.001, max_val - min_val)
      chars = @sparkline_chars

      rendered =
        Enum.map(recent, fn v ->
          normalized = (v - min_val) / range
          idx = trunc(normalized * (length(chars) - 1))
          idx = max(0, min(length(chars) - 1, idx))
          Enum.at(chars, idx)
        end)

      padding = String.duplicate(empty_char, max(0, width - length(rendered)))
      padding <> List.to_string(rendered)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GAUGE / PROGRESS BAR
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a text-based gauge/progress bar.

  ## Examples

      <.gauge value={75.0} max={100.0} />
      <.gauge value={2.7} max={4.0} width={10} unit="GB" />
  """
  attr :value, :float, required: true
  attr :max, :float, default: 100.0
  attr :width, :integer, default: 10
  attr :show_percent, :boolean, default: true
  attr :unit, :string, default: nil
  attr :alarm_level, :atom, default: :normal
  attr :class, :string, default: ""

  def gauge(assigns) do
    ratio = min(1.0, assigns.value / assigns.max)
    filled = round(ratio * assigns.width)
    empty = assigns.width - filled
    percent = round(ratio * 100)

    assigns =
      assigns
      |> assign(:filled, String.duplicate("▓", filled))
      |> assign(:empty, String.duplicate("░", empty))
      |> assign(:percent, percent)

    ~H"""
    <span class={["font-mono text-xs", gauge_color(@alarm_level), @class]}>
      {@filled}{@empty}
      <%= if @show_percent do %>
        <span class="text-gray-400 ml-1">{@percent}%</span>
      <% end %>
      <%= if @unit do %>
        <span class="text-gray-500 ml-1">
          ({Float.round(@value, 1)}/{Float.round(@max, 1)}{@unit})
        </span>
      <% end %>
    </span>
    """
  end

  defp gauge_color(:normal), do: "text-gray-500"
  defp gauge_color(:advisory), do: "text-cyan-500"
  defp gauge_color(:caution), do: "text-amber-500"
  defp gauge_color(:warning), do: "text-red-500"
  defp gauge_color(:critical), do: "text-red-600"

  # ═══════════════════════════════════════════════════════════════════════════
  # METRIC CARD (SC-HMI-001 to SC-HMI-003)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a complete metric card with gauge, sparkline, trend, and staleness.

  ## Examples

      <.metric_card
        label="CPU"
        value={75.5}
        max={100.0}
        unit="%"
        trend={:rising}
        sparkline={[70, 72, 74, 75, 75]}
        staleness={2.5}
      />
  """
  attr :label, :string, required: true
  attr :value, :float, required: true
  attr :max, :float, default: 100.0
  attr :unit, :string, default: "%"
  attr :trend, :atom, default: :stable
  attr :sparkline, :list, default: []
  attr :staleness, :float, default: 0.0
  attr :warning_threshold, :float, default: 90.0
  attr :caution_threshold, :float, default: 75.0
  attr :class, :string, default: ""

  def metric_card(assigns) do
    alarm_level =
      cond do
        assigns.value >= assigns.warning_threshold -> :warning
        assigns.value >= assigns.caution_threshold -> :caution
        assigns.staleness > 30 -> :advisory
        true -> :normal
      end

    staleness_class =
      cond do
        assigns.staleness < 5 -> ""
        assigns.staleness < 30 -> "opacity-60"
        true -> "opacity-30"
      end

    status_state =
      cond do
        assigns.staleness < 5 -> :connected
        assigns.staleness < 30 -> :stale
        true -> :disconnected
      end

    assigns =
      assigns
      |> assign(:alarm_level, alarm_level)
      |> assign(:staleness_class, staleness_class)
      |> assign(:status_state, status_state)
      |> assign(:percent, round(assigns.value / assigns.max * 100))

    ~H"""
    <div class={["flex items-center space-x-2 font-mono text-sm", @staleness_class, @class]}>
      <.status_icon state={@status_state} size={:sm} />
      <span class="text-content-secondary w-16">{@label}</span>
      <.gauge value={@value} max={@max} alarm_level={@alarm_level} show_percent={false} />
      <span class={[metric_value_class(@alarm_level), "w-10 text-right"]}>
        {@percent}{@unit}
      </span>
      <.trend_indicator trend={@trend} />
      <.sparkline values={@sparkline} width={20} class={sparkline_color(@alarm_level)} />
    </div>
    """
  end

  defp metric_value_class(:normal), do: "text-content-secondary"
  defp metric_value_class(:advisory), do: "text-status-advisory"
  defp metric_value_class(:caution), do: "text-status-caution"
  defp metric_value_class(:warning), do: "text-status-warning"
  defp metric_value_class(:critical), do: "text-status-critical"

  defp sparkline_color(:normal), do: "text-content-muted"
  defp sparkline_color(:advisory), do: "text-status-advisory"
  defp sparkline_color(:caution), do: "text-status-caution"
  defp sparkline_color(:warning), do: "text-status-warning"
  defp sparkline_color(:critical), do: "text-status-critical"

  # ═══════════════════════════════════════════════════════════════════════════
  # STATUS BAR / HEADER
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders the PRAJNA status bar header.

  ## Examples

      <.prajna_header
        health_score={94}
        uptime="25d 14h"
        node_count={5}
        alarm_count={2}
      />
  """
  attr :health_score, :integer, default: 100
  attr :uptime, :string, default: "0d 0h"
  attr :node_count, :integer, default: 0
  attr :total_nodes, :integer, default: 0
  attr :alarm_count, :integer, default: 0
  attr :class, :string, default: ""

  def prajna_header(assigns) do
    health_status =
      cond do
        assigns.health_score >= 90 -> :healthy
        assigns.health_score >= 70 -> :caution
        assigns.health_score >= 50 -> :warning
        true -> :critical
      end

    health_text =
      cond do
        assigns.health_score >= 90 -> "HEALTHY"
        assigns.health_score >= 70 -> "DEGRADED"
        assigns.health_score >= 50 -> "WARNING"
        true -> "CRITICAL"
      end

    assigns =
      assigns
      |> assign(:health_status, health_status)
      |> assign(:health_text, health_text)
      |> assign(:now, format_time())

    ~H"""
    <div class={[
      "flex items-center justify-between px-4 py-2 bg-surface-secondary border-b border-border-theme-primary font-mono text-sm",
      @class
    ]}>
      <div class="flex items-center space-x-4">
        <span class="text-accent-primary font-bold">PRAJNA C3I MESH COCKPIT</span>
        <span class="text-content-muted">│</span>
        <div class="flex items-center space-x-2">
          <.status_icon state={@health_status} size={:sm} />
          <span class={health_text_class(@health_status)}>
            {@health_text}
          </span>
        </div>
        <span class="text-content-muted">│</span>
        <span class="text-content-secondary">Score: {@health_score}%</span>
        <span class="text-content-muted">│</span>
        <span class="text-content-secondary">Uptime: {@uptime}</span>
        <span class="text-content-muted">│</span>
        <span class="text-content-secondary">
          Nodes: {@node_count}/{@total_nodes}
        </span>
        <%= if @alarm_count > 0 do %>
          <span class="text-content-muted">│</span>
          <span class="text-status-caution">
            <.status_icon state={:caution} size={:sm} />
            {@alarm_count} Active
          </span>
        <% end %>
      </div>
      <div class="text-content-muted">
        {@now}
      </div>
    </div>
    """
  end

  defp health_text_class(:healthy), do: "text-status-healthy"
  defp health_text_class(:caution), do: "text-status-caution"
  defp health_text_class(:warning), do: "text-status-warning"
  defp health_text_class(:critical), do: "text-status-critical animate-pulse"

  defp format_time do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # NAVIGATION TABS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders navigation tabs for PRAJNA screens.

  ## Examples

      <.prajna_nav current={:dashboard} />
  """
  attr :current, :atom, required: true
  attr :class, :string, default: ""

  @nav_items [
    {:dashboard, "Overview", "/cockpit"},
    {:mesh, "Mesh", "/cockpit/mesh"},
    {:alarms, "Alarms", "/cockpit/alarms"},
    {:commands, "Commands", "/cockpit/commands"},
    {:copilot, "AI Copilot", "/cockpit/ai-copilot"},
    {:containers, "Containers", "/cockpit/containers"},
    {:cluster, "Cluster", "/cockpit/cluster"},
    {:observability, "Observability", "/cockpit/observability"},
    {:settings, "Settings", "/cockpit/settings"}
  ]

  def prajna_nav(assigns) do
    assigns = assign(assigns, :nav_items, @nav_items)

    ~H"""
    <nav class={[
      "flex items-center space-x-1 px-4 py-2 bg-surface-secondary border-b border-border-theme-primary",
      @class
    ]}>
      <%= for {id, label, path} <- @nav_items do %>
        <a
          href={path}
          class={[
            "px-3 py-1 text-sm font-mono rounded transition-colors",
            if(@current == id,
              do: "bg-surface-tertiary text-accent-primary",
              else: "text-content-secondary hover:text-content-primary hover:bg-surface-tertiary"
            )
          ]}
        >
          <%= if @current == id do %>
            <span class="text-accent-primary mr-1">●</span>
          <% end %>
          {label}
        </a>
      <% end %>
    </nav>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ALARM CARD
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders an alarm card with severity, source, message, and actions.

  ## Examples

      <.alarm_card
        id="alm-001"
        level={:caution}
        source="app-03"
        message="CPU trending high (45% ↑↑)"
        age="12 min"
        occurrences={3}
      />
  """
  attr :id, :string, required: true
  attr :level, :atom, required: true, values: [:advisory, :caution, :warning, :critical]
  attr :source, :string, required: true
  attr :message, :string, required: true
  attr :age, :string, default: "now"
  attr :occurrences, :integer, default: 1
  attr :ai_insight, :string, default: nil
  attr :on_ack, :any, default: nil
  attr :on_silence, :any, default: nil
  attr :on_escalate, :any, default: nil
  attr :class, :string, default: ""

  def alarm_card(assigns) do
    ~H"""
    <div class={[
      "bg-surface-secondary rounded-lg border p-4 font-mono text-sm",
      alarm_border_class(@level),
      @class
    ]}>
      <div class="flex items-start justify-between">
        <div class="flex items-start space-x-3">
          <.status_icon state={@level} size={:md} />
          <div>
            <div class="flex items-center space-x-2 mb-1">
              <span class={alarm_level_text_class(@level)}>
                {String.upcase(to_string(@level))}
              </span>
              <span class="text-content-muted">│</span>
              <span class="text-content-primary">{@source}</span>
              <span class="text-content-muted">│</span>
              <span class="text-content-secondary">{@message}</span>
            </div>
            <div class="text-xs text-content-muted">
              Age: {@age} │ Occurrences: {@occurrences}
            </div>
            <%= if @ai_insight do %>
              <div class="mt-2 text-xs text-status-advisory">
                AI Insight: {@ai_insight}
              </div>
            <% end %>
          </div>
        </div>
        <div class="flex space-x-2">
          <%= if @on_ack do %>
            <button
              phx-click={@on_ack}
              phx-value-id={@id}
              class="px-2 py-1 text-xs bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
            >
              ACK
            </button>
          <% end %>
          <%= if @on_silence do %>
            <button
              phx-click={@on_silence}
              phx-value-id={@id}
              class="px-2 py-1 text-xs bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
            >
              SILENCE 1h
            </button>
          <% end %>
          <%= if @on_escalate do %>
            <button
              phx-click={@on_escalate}
              phx-value-id={@id}
              class="px-2 py-1 text-xs bg-amber-900 hover:bg-amber-800 text-amber-300 rounded"
            >
              ESCALATE
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp alarm_border_class(:advisory), do: "border-cyan-700"
  defp alarm_border_class(:caution), do: "border-amber-700"
  defp alarm_border_class(:warning), do: "border-red-700"
  defp alarm_border_class(:critical), do: "border-red-500 animate-pulse"

  defp alarm_level_text_class(:advisory), do: "text-cyan-400"
  defp alarm_level_text_class(:caution), do: "text-amber-400"
  defp alarm_level_text_class(:warning), do: "text-red-400"
  defp alarm_level_text_class(:critical), do: "text-red-500 font-bold"

  # ═══════════════════════════════════════════════════════════════════════════
  # NODE CARD
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a mesh node card with metrics.

  ## Examples

      <.node_card
        id="app-01"
        cpu={42}
        memory={68}
        cpu_trend={:rising}
        memory_trend={:stable}
        status={:healthy}
      />
  """
  attr :id, :string, required: true
  attr :cpu, :float, default: 0.0
  attr :memory, :float, default: 0.0
  attr :latency, :float, default: 0.0
  attr :cpu_trend, :atom, default: :stable
  attr :memory_trend, :atom, default: :stable
  attr :status, :atom, default: :healthy
  attr :cpu_sparkline, :list, default: []
  attr :memory_sparkline, :list, default: []
  attr :class, :string, default: ""

  def node_card(assigns) do
    ~H"""
    <div class={[
      "bg-surface-secondary rounded border border-border-theme-primary p-3 font-mono text-sm",
      @class
    ]}>
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center space-x-2">
          <.status_icon state={@status} size={:sm} />
          <span class="text-content-primary">{@id}</span>
        </div>
        <%= if @latency > 0 do %>
          <span class="text-xs text-content-muted">{Float.round(@latency, 1)}ms</span>
        <% end %>
      </div>
      <div class="space-y-1 text-xs">
        <div class="flex items-center space-x-2">
          <span class="text-content-muted w-12">CPU:</span>
          <.gauge
            value={@cpu}
            max={100.0}
            width={8}
            show_percent={false}
            alarm_level={cpu_alarm_level(@cpu)}
          />
          <span class={cpu_value_class(@cpu)}>{round(@cpu)}%</span>
          <.trend_indicator trend={@cpu_trend} />
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-content-muted w-12">MEM:</span>
          <.gauge
            value={@memory}
            max={100.0}
            width={8}
            show_percent={false}
            alarm_level={memory_alarm_level(@memory)}
          />
          <span class={memory_value_class(@memory)}>{round(@memory)}%</span>
          <.trend_indicator trend={@memory_trend} />
        </div>
      </div>
    </div>
    """
  end

  defp cpu_alarm_level(cpu) when cpu >= 90, do: :warning
  defp cpu_alarm_level(cpu) when cpu >= 75, do: :caution
  defp cpu_alarm_level(_), do: :normal

  defp cpu_value_class(cpu) when cpu >= 90, do: "text-red-400"
  defp cpu_value_class(cpu) when cpu >= 75, do: "text-amber-400"
  defp cpu_value_class(_), do: "text-gray-400"

  defp memory_alarm_level(mem) when mem >= 90, do: :warning
  defp memory_alarm_level(mem) when mem >= 80, do: :caution
  defp memory_alarm_level(_), do: :normal

  defp memory_value_class(mem) when mem >= 90, do: "text-red-400"
  defp memory_value_class(mem) when mem >= 80, do: "text-amber-400"
  defp memory_value_class(_), do: "text-gray-400"

  # ═══════════════════════════════════════════════════════════════════════════
  # TWO-STEP COMMIT MODAL (SC-HMI-004)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a two-step commit confirmation modal for critical commands.

  ## Examples

      <.two_step_modal
        :if={@armed_command}
        command={@armed_command}
        target={@command_target}
        countdown={@countdown}
        on_confirm="confirm_command"
        on_cancel="cancel_command"
      />
  """
  attr :command, :string, required: true
  attr :target, :string, required: true
  attr :countdown, :integer, default: 300
  attr :armed_by, :string, default: "operator"
  attr :armed_at, :any, default: nil
  attr :on_confirm, :string, required: true
  attr :on_cancel, :string, required: true
  attr :class, :string, default: ""

  def two_step_modal(assigns) do
    countdown_str = format_countdown(assigns.countdown)

    armed_at_str =
      if assigns.armed_at, do: Calendar.strftime(assigns.armed_at, "%Y-%m-%d %H:%M:%S"), else: "-"

    assigns =
      assigns
      |> assign(:countdown_str, countdown_str)
      |> assign(:armed_at_str, armed_at_str)

    ~H"""
    <div class={[
      "fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50",
      @class
    ]}>
      <div class="bg-surface-secondary border-2 border-status-caution rounded-lg p-6 max-w-lg font-mono">
        <div class="flex items-center space-x-2 mb-4">
          <.status_icon state={:caution} size={:lg} />
          <h3 class="text-amber-400 font-bold text-lg">
            {String.upcase(@command)} PENDING CONFIRMATION
          </h3>
        </div>

        <div class="space-y-2 mb-4 text-sm">
          <div class="flex">
            <span class="text-content-muted w-24">Target:</span>
            <span class="text-content-primary">{@target}</span>
          </div>
          <div class="flex">
            <span class="text-content-muted w-24">Command:</span>
            <span class="text-content-primary">{@command}</span>
          </div>
          <div class="flex">
            <span class="text-content-muted w-24">Armed by:</span>
            <span class="text-content-primary">{@armed_by}</span>
          </div>
          <div class="flex">
            <span class="text-content-muted w-24">Armed at:</span>
            <span class="text-content-primary">{@armed_at_str}</span>
          </div>
          <div class="flex">
            <span class="text-content-muted w-24">Expires in:</span>
            <span class="text-status-caution">{@countdown_str}</span>
          </div>
        </div>

        <div class="bg-surface-tertiary border border-border-theme-primary rounded p-3 mb-4 text-xs text-content-secondary">
          This is a <span class="text-status-critical">CRITICAL</span>
          command requiring two-step confirmation.
          Review the target and command details before confirming.
        </div>

        <div class="flex justify-end space-x-4">
          <button
            phx-click={@on_cancel}
            class="px-4 py-2 bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
          >
            CANCEL
          </button>
          <button
            phx-click={@on_confirm}
            class="px-4 py-2 bg-red-900 hover:bg-red-800 text-red-300 rounded border border-red-700"
          >
            CONFIRM {String.upcase(@command)}
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp format_countdown(seconds) when seconds >= 60 do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{mins}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_countdown(seconds),
    do: "0:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"

  # ═══════════════════════════════════════════════════════════════════════════
  # OODA CYCLE STATUS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders OODA cycle status display.

  ## Examples

      <.ooda_status
        phase={:orient}
        cycle_ms={847}
        target_ms={1000}
        quality={98}
      />
  """
  attr :phase, :atom, required: true, values: [:observe, :orient, :decide, :act]
  attr :cycle_ms, :integer, default: 0
  attr :target_ms, :integer, default: 1000
  attr :quality, :integer, default: 100
  attr :class, :string, default: ""

  def ooda_status(assigns) do
    within_target = assigns.cycle_ms <= assigns.target_ms
    cycle_str = "#{Float.round(assigns.cycle_ms / 1000, 2)}s"
    target_str = "#{Float.round(assigns.target_ms / 1000, 1)}s"

    assigns =
      assigns
      |> assign(:within_target, within_target)
      |> assign(:cycle_str, cycle_str)
      |> assign(:target_str, target_str)

    ~H"""
    <div class={[
      "bg-surface-secondary rounded border border-border-theme-primary p-3 font-mono text-sm",
      @class
    ]}>
      <div class="flex items-center justify-between mb-2">
        <span class="text-content-secondary">OODA CYCLE</span>
        <span class={["text-xs", if(@within_target, do: "text-green-400", else: "text-red-400")]}>
          {if @within_target, do: "✓", else: "⚠"} {@cycle_str} / {@target_str}
        </span>
      </div>
      <div class="flex items-center space-x-2 text-xs">
        <span class={ooda_phase_class(:observe, @phase)}>OBSERVE</span>
        <span class="text-content-muted">→</span>
        <span class={ooda_phase_class(:orient, @phase)}>ORIENT</span>
        <span class="text-content-muted">→</span>
        <span class={ooda_phase_class(:decide, @phase)}>DECIDE</span>
        <span class="text-content-muted">→</span>
        <span class={ooda_phase_class(:act, @phase)}>ACT</span>
      </div>
      <div class="mt-2 text-xs text-content-muted">
        Quality: {@quality}%
      </div>
    </div>
    """
  end

  defp ooda_phase_class(phase, current) when phase == current, do: "text-accent-primary font-bold"
  defp ooda_phase_class(_, _), do: "text-content-muted"

  # ═══════════════════════════════════════════════════════════════════════════
  # INSIGHT CARD (AI COPILOT)
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders an AI Copilot insight card.

  ## Examples

      <.insight_card
        type={:anomaly}
        confidence={0.95}
        title="High CPU on app-03"
        content="CPU at 45% with trend rising_fast..."
        recommendations={["Scale horizontally", "Check processes"]}
        related_node="app-03"
      />
  """
  attr :type, :atom,
    required: true,
    values: [:summary, :anomaly, :prediction, :recommendation, :correlation]

  attr :confidence, :float, default: 1.0
  attr :title, :string, required: true
  attr :content, :string, required: true
  attr :recommendations, :list, default: []
  attr :related_node, :string, default: nil
  attr :expires_in, :integer, default: nil
  attr :on_apply, :any, default: nil
  attr :on_dismiss, :any, default: nil
  attr :class, :string, default: ""

  def insight_card(assigns) do
    ~H"""
    <div class={[
      "bg-surface-secondary rounded border p-4 font-mono text-sm",
      insight_border_class(@type),
      @class
    ]}>
      <div class="flex items-start justify-between mb-2">
        <div class="flex items-center space-x-2">
          <.status_icon state={insight_icon_state(@type)} size={:sm} />
          <span class={insight_type_class(@type)}>
            {String.upcase(to_string(@type))}
          </span>
          <span class="text-content-muted">│</span>
          <span class="text-content-secondary">Confidence: {Float.round(@confidence, 2)}</span>
          <%= if @related_node do %>
            <span class="text-content-muted">│</span>
            <span class="text-content-secondary">Related: {@related_node}</span>
          <% end %>
        </div>
        <%= if @expires_in do %>
          <span class="text-xs text-content-muted">Expires: {@expires_in}s</span>
        <% end %>
      </div>

      <div class="mb-2">
        <h4 class="text-content-primary font-medium">{@title}</h4>
        <p class="text-content-secondary text-xs mt-1">{@content}</p>
      </div>

      <%= if length(@recommendations) > 0 do %>
        <div class="mb-3">
          <p class="text-xs text-content-muted mb-1">Recommended Actions:</p>
          <ul class="text-xs text-content-secondary list-disc list-inside">
            <%= for rec <- @recommendations do %>
              <li>{rec}</li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="flex space-x-2">
        <%= if @on_apply do %>
          <button
            phx-click={@on_apply}
            class="px-2 py-1 text-xs bg-accent-primary/20 hover:bg-accent-primary/30 text-accent-primary rounded"
          >
            APPLY RECOMMENDATION
          </button>
        <% end %>
        <%= if @on_dismiss do %>
          <button
            phx-click={@on_dismiss}
            class="px-2 py-1 text-xs bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
          >
            DISMISS
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp insight_border_class(:summary), do: "border-gray-600"
  defp insight_border_class(:anomaly), do: "border-amber-700"
  defp insight_border_class(:prediction), do: "border-cyan-700"
  defp insight_border_class(:recommendation), do: "border-blue-700"
  defp insight_border_class(:correlation), do: "border-purple-700"

  defp insight_icon_state(:summary), do: :normal
  defp insight_icon_state(:anomaly), do: :caution
  defp insight_icon_state(:prediction), do: :advisory
  defp insight_icon_state(:recommendation), do: :advisory
  defp insight_icon_state(:correlation), do: :advisory

  defp insight_type_class(:summary), do: "text-gray-400"
  defp insight_type_class(:anomaly), do: "text-amber-400"
  defp insight_type_class(:prediction), do: "text-cyan-400"
  defp insight_type_class(:recommendation), do: "text-blue-400"
  defp insight_type_class(:correlation), do: "text-purple-400"

  # ═══════════════════════════════════════════════════════════════════════════
  # CONTAINER CARD
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a container status card.

  ## Examples

      <.container_card
        id="app"
        name="indrajaal-app"
        status={:running}
        health={:healthy}
        cpu={42}
        memory={68}
        uptime="25d 14h"
        ports={["4000", "4001"]}
      />
  """
  attr :id, :atom, required: true
  attr :name, :string, required: true
  attr :status, :atom, default: :running
  attr :health, :atom, default: :healthy
  attr :cpu, :float, default: 0.0
  attr :memory, :float, default: 0.0
  attr :memory_used, :float, default: 0.0
  attr :memory_total, :float, default: 0.0
  attr :uptime, :string, default: "-"
  attr :ports, :list, default: []
  attr :cpu_sparkline, :list, default: []
  attr :memory_sparkline, :list, default: []
  attr :on_restart, :any, default: nil
  attr :on_logs, :any, default: nil
  attr :on_shell, :any, default: nil
  attr :class, :string, default: ""

  def container_card(assigns) do
    ~H"""
    <div class={[
      "bg-surface-secondary rounded-lg border border-border-theme-primary p-4 font-mono",
      @class
    ]}>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-2">
          <.status_icon state={container_status_icon(@status, @health)} />
          <span class="text-content-primary font-medium">{@name}</span>
        </div>
        <span class={health_badge_class(@health)}>
          {String.upcase(to_string(@health))}
        </span>
      </div>

      <div class="grid grid-cols-2 gap-4 mb-3 text-xs">
        <div>
          <span class="text-content-muted">Status:</span>
          <span class={status_text_class(@status)}>{String.upcase(to_string(@status))} ✓</span>
        </div>
        <div>
          <span class="text-content-muted">Uptime:</span>
          <span class="text-content-primary">{@uptime}</span>
        </div>
        <div>
          <span class="text-content-muted">Ports:</span>
          <span class="text-content-primary">{Enum.join(@ports, ", ")}</span>
        </div>
      </div>

      <div class="space-y-2 mb-3 text-xs">
        <div class="flex items-center space-x-2">
          <span class="text-content-muted w-12">CPU:</span>
          <.gauge value={@cpu} max={100.0} width={10} alarm_level={cpu_alarm_level(@cpu)} />
          <.sparkline values={@cpu_sparkline} width={15} />
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-content-muted w-12">MEM:</span>
          <.gauge value={@memory} max={100.0} width={10} alarm_level={memory_alarm_level(@memory)} />
          <%= if @memory_total > 0 do %>
            <span class="text-content-muted">
              ({Float.round(@memory_used, 1)}/{Float.round(@memory_total, 1)}GB)
            </span>
          <% end %>
        </div>
      </div>

      <div class="flex space-x-2">
        <%= if @on_restart do %>
          <button
            phx-click={@on_restart}
            phx-value-id={@id}
            class="px-2 py-1 text-xs bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
          >
            RESTART
          </button>
        <% end %>
        <%= if @on_logs do %>
          <button
            phx-click={@on_logs}
            phx-value-id={@id}
            class="px-2 py-1 text-xs bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
          >
            VIEW LOGS
          </button>
        <% end %>
        <%= if @on_shell do %>
          <button
            phx-click={@on_shell}
            phx-value-id={@id}
            class="px-2 py-1 text-xs bg-surface-tertiary hover:bg-surface-elevated text-content-secondary rounded"
          >
            SHELL
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp container_status_icon(:running, :healthy), do: :healthy
  defp container_status_icon(:running, :degraded), do: :caution
  defp container_status_icon(:running, _), do: :warning
  defp container_status_icon(:stopped, _), do: :disconnected
  defp container_status_icon(_, _), do: :error

  defp health_badge_class(:healthy),
    do: "text-xs px-2 py-0.5 bg-green-900/50 text-green-400 rounded"

  defp health_badge_class(:degraded),
    do: "text-xs px-2 py-0.5 bg-amber-900/50 text-amber-400 rounded"

  defp health_badge_class(:unhealthy),
    do: "text-xs px-2 py-0.5 bg-red-900/50 text-red-400 rounded"

  defp health_badge_class(_), do: "text-xs px-2 py-0.5 bg-gray-700 text-gray-400 rounded"

  defp status_text_class(:running), do: "text-green-400"
  defp status_text_class(:stopped), do: "text-gray-500"
  defp status_text_class(:starting), do: "text-amber-400"
  defp status_text_class(_), do: "text-red-400"

  # ═══════════════════════════════════════════════════════════════════════════
  # SAFETY STATUS BAR
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders the safety systems status bar.

  ## Examples

      <.safety_status
        guardian={:active}
        dms={:healthy}
        envelope={:ok}
        sentinel={3}
        sentinel_total={3}
      />
  """
  attr :guardian, :atom, default: :active
  attr :dms, :atom, default: :healthy
  attr :envelope, :atom, default: :ok
  attr :sentinel, :integer, default: 0
  attr :sentinel_total, :integer, default: 3
  attr :violations, :integer, default: 0
  attr :heartbeats, :integer, default: 0
  attr :utilization, :integer, default: 0
  attr :class, :string, default: ""

  def safety_status(assigns) do
    quorum_ok = assigns.sentinel >= div(assigns.sentinel_total, 2) + 1

    assigns = assign(assigns, :quorum_ok, quorum_ok)

    ~H"""
    <div class={[
      "bg-surface-secondary border border-border-theme-primary rounded p-3 font-mono text-xs",
      @class
    ]}>
      <div class="flex items-center space-x-4">
        <div class="flex items-center space-x-1">
          <span class="text-content-muted">Guardian:</span>
          <span class={safety_status_class(@guardian)}>
            {String.upcase(to_string(@guardian))} {if @guardian == :active, do: "✓", else: "⚠"}
          </span>
        </div>
        <div class="flex items-center space-x-1">
          <span class="text-content-muted">DMS:</span>
          <span class={safety_status_class(@dms)}>
            {String.upcase(to_string(@dms))} {if @dms == :healthy, do: "✓", else: "⚠"}
          </span>
        </div>
        <div class="flex items-center space-x-1">
          <span class="text-content-muted">Envelope:</span>
          <span class={safety_status_class(@envelope)}>
            {String.upcase(to_string(@envelope))} {if @envelope == :ok, do: "✓", else: "⚠"}
          </span>
        </div>
        <div class="flex items-center space-x-1">
          <span class="text-content-muted">Sentinel:</span>
          <span class={if @quorum_ok, do: "text-green-400", else: "text-red-400"}>
            {@sentinel}/{@sentinel_total} {if @quorum_ok, do: "✓", else: "⚠"}
          </span>
        </div>
      </div>
      <div class="flex items-center space-x-4 mt-2 text-content-muted">
        <span>Violations: {@violations}</span>
        <span>Heartbeats: {format_number(@heartbeats)}</span>
        <span>Utilization: {@utilization}%</span>
        <span>Quorum: {if @quorum_ok, do: "✓", else: "✗"}</span>
      </div>
    </div>
    """
  end

  defp safety_status_class(:active), do: "text-status-healthy"
  defp safety_status_class(:healthy), do: "text-status-healthy"
  defp safety_status_class(:ok), do: "text-status-healthy"
  defp safety_status_class(:warning), do: "text-status-caution"
  defp safety_status_class(:degraded), do: "text-status-caution"
  defp safety_status_class(:error), do: "text-status-warning"
  defp safety_status_class(:inactive), do: "text-content-muted"
  defp safety_status_class(_), do: "text-content-secondary"

  # ═══════════════════════════════════════════════════════════════════════════
  # FRACTAL LOG DISPLAY
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders a fractal log entry with appropriate styling.

  ## Examples

      <.fractal_log
        level={:spine}
        source="Guardian"
        message="System failure detected"
        timestamp={~U[2025-12-27 14:32:45Z]}
      />
  """
  attr :level, :atom, required: true, values: [:spine, :thorax, :segment, :fiber, :gossamer]
  attr :source, :string, required: true
  attr :message, :string, required: true
  attr :timestamp, :any, required: true
  attr :class, :string, default: ""

  def fractal_log(assigns) do
    time_str =
      if assigns.timestamp do
        assigns.timestamp |> Calendar.strftime("%H:%M:%S.%f") |> String.slice(0..11)
      else
        "-"
      end

    assigns = assign(assigns, :time_str, time_str)

    ~H"""
    <div class={["font-mono text-xs flex items-center space-x-2", fractal_log_class(@level), @class]}>
      <span class="text-content-muted">[{@time_str}]</span>
      <span class={fractal_level_indicator_class(@level)}>{fractal_level_indicator(@level)}</span>
      <span class="text-content-muted">[{@source}]</span>
      <span class="text-content-secondary">{@message}</span>
    </div>
    """
  end

  defp fractal_level_indicator(:spine), do: "⬤"
  defp fractal_level_indicator(:thorax), do: "◉"
  defp fractal_level_indicator(:segment), do: "◎"
  defp fractal_level_indicator(:fiber), do: "○"
  defp fractal_level_indicator(:gossamer), do: "·"

  defp fractal_log_class(:spine), do: "text-red-400"
  defp fractal_log_class(:thorax), do: "text-amber-400"
  defp fractal_log_class(:segment), do: "text-cyan-400"
  defp fractal_log_class(:fiber), do: "text-gray-400"
  defp fractal_log_class(:gossamer), do: "text-gray-500"

  defp fractal_level_indicator_class(:spine), do: "text-red-500"
  defp fractal_level_indicator_class(:thorax), do: "text-amber-500"
  defp fractal_level_indicator_class(:segment), do: "text-cyan-500"
  defp fractal_level_indicator_class(:fiber), do: "text-gray-400"
  defp fractal_level_indicator_class(:gossamer), do: "text-gray-500"

  # ═══════════════════════════════════════════════════════════════════════════
  # UTILITY FUNCTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  @doc false
  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(num) when is_float(num), do: format_number(round(num))
  defp format_number(nil), do: "0"
  defp format_number(num), do: to_string(num)
end
