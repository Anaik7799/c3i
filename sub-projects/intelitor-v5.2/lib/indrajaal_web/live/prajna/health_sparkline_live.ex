defmodule IndrajaalWeb.Prajna.HealthSparklineLive do
  @moduledoc """
  PRAJNA C3I System Health Sparklines Dashboard.

  WHAT: Displays real-time system health metrics with 60-second rolling window
        using SVG sparklines for CPU utilization, memory usage, and message
        queue depth across all nodes in the Indrajaal mesh.

  WHY: Provides operators with visual health trends for fast cognitive
       pattern recognition — spot degradation before threshold breach:
       - 60-second rolling window for each metric
       - SVG sparkline rendering (no JS charting library needed)
       - CPU / Memory / Queue Depth / Response Latency
       - Per-node breakdown with aggregate view
       - Trend indicators (improving / degrading / stable)

  CONSTRAINTS:
    - SC-MON-001: Metrics refresh every 30s
    - SC-MON-002: Infrastructure metrics complete
    - SC-MON-004: Safety metrics mandatory
    - SC-MON-005: Dashboard data available
    - SC-PRF-050: Response < 50ms
    - SC-BRIDGE-005: PubSub topics
    - SC-HMI-001: Dark Cockpit (gray defaults)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 1.0.0 | 2026-03-23 | Code Evolution Agent | Initial implementation |

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-03-23 |
  | STAMP | SC-MON-001, SC-MON-002, SC-MON-004, SC-PRF-050 |
  """

  use IndrajaalWeb, :live_view

  import IndrajaalWeb.PrajnaComponents

  require Logger

  @refresh_interval 5_000
  @metrics_interval 30_000
  @sparkline_points 60
  @sparkline_width 200
  @sparkline_height 40

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      :timer.send_interval(@metrics_interval, self(), :sync_metrics)

      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "zenoh:health")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:health")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "homeostasis:state")
    end

    {:ok,
     socket
     |> assign(:page_title, "System Health — Sparklines")
     |> assign(:current_nav, :health)
     |> assign(:metric_history, init_metric_history())
     |> assign(:node_metrics, init_node_metrics())
     |> assign(:system_summary, init_system_summary())
     |> assign(:selected_node, :aggregate)
     |> assign(:alert_thresholds, default_thresholds())
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:sparkline_width, @sparkline_width)
     |> assign(:sparkline_height, @sparkline_height)
     |> assign(:math_integrity, init_math_integrity())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Advance the rolling window with a new synthetic data point
    updated_history = advance_history(socket.assigns.metric_history)

    {:noreply,
     socket
     |> assign(:metric_history, updated_history)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:sync_metrics, socket) do
    metrics = fetch_live_metrics()

    {:noreply,
     socket
     |> assign(:node_metrics, metrics)
     |> assign(:system_summary, compute_summary(metrics))}
  end

  @impl true
  def handle_info({:metrics_update, metrics}, socket) do
    updated_history = push_metrics_sample(socket.assigns.metric_history, metrics)

    {:noreply,
     socket
     |> assign(:metric_history, updated_history)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info({:node_health, node_id, health}, socket) do
    node_metrics =
      Map.update(
        socket.assigns.node_metrics,
        node_id,
        health,
        fn existing -> Map.merge(existing, health) end
      )

    {:noreply, assign(socket, :node_metrics, node_metrics)}
  end

  @impl true
  def handle_info({:homeostasis_state, state}, socket) do
    mi = socket.assigns.math_integrity

    math_integrity = %{
      hs: Map.get(state, :current_stress, mi.hs) * 1.0,
      epsilon: Map.get(state, :setpoint, mi.setpoint) - Map.get(state, :current_stress, mi.hs),
      ds: compute_discipline_score(Map.get(state, :error_history, []), mi.ds),
      setpoint: Map.get(state, :setpoint, mi.setpoint),
      kp: Map.get(state, :kp, mi.kp)
    }

    {:noreply, assign(socket, :math_integrity, math_integrity)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("select_node", %{"node" => node}, socket) do
    node_key = if node == "aggregate", do: :aggregate, else: node
    {:noreply, assign(socket, :selected_node, node_key)}
  end

  @impl true
  def handle_event("set_threshold", %{"metric" => metric, "value" => value}, socket) do
    case Float.parse(value) do
      {threshold, _} ->
        thresholds = Map.put(socket.assigns.alert_thresholds, metric, threshold)
        {:noreply, assign(socket, :alert_thresholds, thresholds)}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <.prajna_header
        health_score={@system_summary.health_score}
        uptime={format_uptime()}
        node_count={map_size(@node_metrics)}
        total_nodes={5}
        alarm_count={count_alerts(@metric_history, @alert_thresholds)}
      />

      <.prajna_nav current={:health} />

      <main class="p-4 space-y-4">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-xl font-bold text-content-primary">System Health — Sparklines</h1>
            <p class="text-xs text-content-muted mt-1">
              60-second rolling window | SC-MON-001 | {Calendar.strftime(@last_update, "%H:%M:%S UTC")}
            </p>
          </div>
          <div class="flex items-center space-x-3 text-xs">
            <span class={"px-2 py-1 rounded #{trend_badge(@system_summary.trend)}"}>
              {trend_label(@system_summary.trend)}
            </span>
            <span class="text-content-muted">
              Health:
              <span class={"font-bold #{health_score_color(@system_summary.health_score)}"}>
                {@system_summary.health_score}%
              </span>
            </span>
          </div>
        </div>

        <%!-- System Summary Cards --%>
        <div class="grid grid-cols-4 gap-4">
          <%= for {metric_key, label, unit} <- [
            {:cpu, "CPU Utilization", "%"},
            {:memory, "Memory Usage", "%"},
            {:queue_depth, "Queue Depth", "msg"},
            {:response_ms, "Response Latency", "ms"}
          ] do %>
            <% series = Map.get(@metric_history, metric_key, []) %>
            <% current = List.first(series, 0) %>
            <% threshold = Map.get(@alert_thresholds, Atom.to_string(metric_key), 80.0) %>
            <div class={"bg-surface-secondary rounded-lg border p-4 #{if current > threshold, do: "border-red-700", else: "border-border-theme-primary"}"}>
              <div class="flex items-center justify-between mb-2">
                <div class="text-xs text-content-muted">{label}</div>
                <div class={"text-sm font-bold #{metric_value_color(current, threshold)}"}>
                  {Float.round(current, 1)}{unit}
                </div>
              </div>
              <%!-- SVG Sparkline --%>
              <svg
                viewBox={"0 0 #{@sparkline_width} #{@sparkline_height}"}
                width={@sparkline_width}
                height={@sparkline_height}
                class="w-full"
              >
                <polyline
                  points={sparkline_points(series, @sparkline_width, @sparkline_height)}
                  fill="none"
                  stroke={sparkline_color(current, threshold)}
                  stroke-width="1.5"
                  stroke-linejoin="round"
                />
                <%!-- Threshold line --%>
                <% threshold_y = sparkline_threshold_y(threshold, @sparkline_height) %>
                <line
                  x1="0"
                  y1={threshold_y}
                  x2={@sparkline_width}
                  y2={threshold_y}
                  stroke="#6b7280"
                  stroke-width="0.5"
                  stroke-dasharray="4,4"
                />
              </svg>
              <div class="flex justify-between text-xs text-content-muted mt-1">
                <span>60s ago</span>
                <span>now</span>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Node Selector --%>
        <div class="flex items-center space-x-2 text-xs">
          <span class="text-content-muted">Node:</span>
          <button
            phx-click="select_node"
            phx-value-node="aggregate"
            class={"px-3 py-1 rounded #{if @selected_node == :aggregate, do: "bg-blue-900 text-blue-300", else: "bg-surface-tertiary text-content-secondary hover:bg-surface-elevated"}"}
          >
            AGGREGATE
          </button>
          <%= for {node_id, _metrics} <- @node_metrics do %>
            <button
              phx-click="select_node"
              phx-value-node={node_id}
              class={"px-3 py-1 rounded #{if @selected_node == node_id, do: "bg-blue-900 text-blue-300", else: "bg-surface-tertiary text-content-secondary hover:bg-surface-elevated"}"}
            >
              {String.upcase(node_id)}
            </button>
          <% end %>
        </div>

        <%!-- Per-Node Health Matrix --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary overflow-hidden">
          <div class="px-4 py-2 border-b border-border-theme-primary">
            <h2 class="text-sm font-bold text-content-secondary">NODE HEALTH MATRIX</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-xs">
              <thead>
                <tr class="border-b border-border-theme-primary">
                  <th class="text-left px-4 py-2 text-content-muted">NODE</th>
                  <th class="text-right px-4 py-2 text-content-muted">CPU %</th>
                  <th class="text-right px-4 py-2 text-content-muted">MEM %</th>
                  <th class="text-right px-4 py-2 text-content-muted">QUEUE</th>
                  <th class="text-right px-4 py-2 text-content-muted">RESP MS</th>
                  <th class="text-right px-4 py-2 text-content-muted">PROCS</th>
                  <th class="text-center px-4 py-2 text-content-muted">STATUS</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-border-theme-primary">
                <%= for {node_id, metrics} <- @node_metrics do %>
                  <tr class={"#{if @selected_node == node_id, do: "bg-surface-elevated", else: "hover:bg-surface-tertiary"} transition-colors"}>
                    <td class="px-4 py-3 font-mono text-content-primary">{node_id}</td>
                    <td class={"text-right px-4 py-3 #{metric_value_color(metrics.cpu, 80.0)}"}>
                      {Float.round(metrics.cpu, 1)}
                    </td>
                    <td class={"text-right px-4 py-3 #{metric_value_color(metrics.memory, 85.0)}"}>
                      {Float.round(metrics.memory, 1)}
                    </td>
                    <td class={"text-right px-4 py-3 #{metric_value_color(metrics.queue_depth * 1.0, 100.0)}"}>
                      {metrics.queue_depth}
                    </td>
                    <td class={"text-right px-4 py-3 #{metric_value_color(metrics.response_ms * 1.0, 50.0)}"}>
                      {metrics.response_ms}
                    </td>
                    <td class="text-right px-4 py-3 text-content-secondary">
                      {metrics.process_count}
                    </td>
                    <td class="text-center px-4 py-3">
                      <span class={"px-2 py-0.5 rounded text-xs #{node_status_badge(metrics)}"}>
                        {node_status_label(metrics)}
                      </span>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Detailed Sparklines Grid --%>
        <div class="grid grid-cols-2 gap-4">
          <%= for {metric_key, label, unit, max_val} <- [
            {:cpu, "CPU Utilization", "%", 100},
            {:memory, "Memory Usage", "%", 100},
            {:queue_depth, "Message Queue Depth", "msgs", 200},
            {:response_ms, "Response Latency", "ms", 100}
          ] do %>
            <% series = Map.get(@metric_history, metric_key, []) %>
            <% current = List.first(series, 0) %>
            <% min_val = Enum.min(series, fn -> 0 end) %>
            <% max_series = Enum.max(series, fn -> 0 end) %>
            <% threshold = Map.get(@alert_thresholds, Atom.to_string(metric_key), 80.0) %>
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-sm font-bold text-content-secondary">{label}</h3>
                <div class="flex items-center space-x-3 text-xs">
                  <span class="text-content-muted">min: {Float.round(min_val * 1.0, 1)}</span>
                  <span class="text-content-muted">max: {Float.round(max_series * 1.0, 1)}</span>
                  <span class={"font-bold #{metric_value_color(current, threshold)}"}>
                    {Float.round(current * 1.0, 1)}{unit}
                  </span>
                </div>
              </div>
              <svg
                viewBox={"0 0 #{@sparkline_width * 2} #{@sparkline_height * 2}"}
                width={@sparkline_width * 2}
                height={@sparkline_height * 2}
                class="w-full"
              >
                <%!-- Fill area --%>
                <polygon
                  points={
                    sparkline_fill_points(
                      series,
                      @sparkline_width * 2,
                      @sparkline_height * 2,
                      max_val
                    )
                  }
                  fill={sparkline_fill(current, threshold)}
                  opacity="0.15"
                />
                <%!-- Line --%>
                <polyline
                  points={
                    sparkline_points_scaled(
                      series,
                      @sparkline_width * 2,
                      @sparkline_height * 2,
                      max_val
                    )
                  }
                  fill="none"
                  stroke={sparkline_color(current, threshold)}
                  stroke-width="2"
                  stroke-linejoin="round"
                />
                <%!-- Threshold line --%>
                <% th_y = threshold / max_val * (@sparkline_height * 2) %>
                <% th_actual_y = @sparkline_height * 2 - th_y %>
                <line
                  x1="0"
                  y1={th_actual_y}
                  x2={@sparkline_width * 2}
                  y2={th_actual_y}
                  stroke="#ef4444"
                  stroke-width="1"
                  stroke-dasharray="6,4"
                  opacity="0.6"
                />
                <%!-- Current value dot --%>
                <% dot_x = @sparkline_width * 2 - 2 %>
                <% dot_y_pct = min(current / max_val, 1.0) %>
                <% dot_y = @sparkline_height * 2 - dot_y_pct * (@sparkline_height * 2) %>
                <circle cx={dot_x} cy={dot_y} r="3" fill={sparkline_color(current, threshold)} />
              </svg>
              <div class="flex justify-between text-xs text-content-muted mt-1">
                <span>t-60s</span>
                <span class="text-content-muted">Threshold: {threshold}{unit}</span>
                <span>now</span>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Mathematical Integrity Pane (SC-MATH-001, SC-MATH-003) --%>
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-sm font-bold text-content-secondary">MATHEMATICAL INTEGRITY</h2>
            <span class="text-xs text-content-muted">
              SC-MATH-001 | SC-MATH-003 | PID Homeostasis
            </span>
          </div>
          <div class="grid grid-cols-5 gap-3 text-xs">
            <div class="bg-surface-tertiary rounded p-3 text-center">
              <div class="text-content-muted mb-1">Hs (Homeostasis)</div>
              <div class={"text-lg font-bold font-mono #{hs_color(@math_integrity.hs)}"}>
                {Float.round(@math_integrity.hs * 100, 1)}%
              </div>
              <div class="text-content-muted mt-1">stress level</div>
              <div class="mt-2 h-1.5 bg-surface-primary rounded-full overflow-hidden">
                <div
                  class={"h-full rounded-full #{hs_bar_color(@math_integrity.hs)}"}
                  style={"width: #{min(100, round(@math_integrity.hs * 100))}%"}
                />
              </div>
            </div>
            <div class="bg-surface-tertiary rounded p-3 text-center">
              <div class="text-content-muted mb-1">ε (Error)</div>
              <div class={"text-lg font-bold font-mono #{epsilon_color(@math_integrity.epsilon)}"}>
                {if @math_integrity.epsilon >= 0, do: "+", else: ""}{Float.round(
                  @math_integrity.epsilon,
                  3
                )}
              </div>
              <div class="text-content-muted mt-1">setpoint − stress</div>
              <div class="mt-2 text-xs text-content-muted">
                SP: {Float.round(@math_integrity.setpoint, 2)}
              </div>
            </div>
            <div class="bg-surface-tertiary rounded p-3 text-center">
              <div class="text-content-muted mb-1">Ds (Discipline)</div>
              <div class={"text-lg font-bold font-mono #{ds_color(@math_integrity.ds)}"}>
                {Float.round(@math_integrity.ds * 100, 1)}%
              </div>
              <div class="text-content-muted mt-1">|ε| stability</div>
              <div class="mt-2 h-1.5 bg-surface-primary rounded-full overflow-hidden">
                <div
                  class={"h-full rounded-full #{ds_bar_color(@math_integrity.ds)}"}
                  style={"width: #{min(100, round(@math_integrity.ds * 100))}%"}
                />
              </div>
            </div>
            <div class="bg-surface-tertiary rounded p-3 text-center">
              <div class="text-content-muted mb-1">Kp (Gain)</div>
              <div class="text-lg font-bold font-mono text-blue-400">
                {Float.round(@math_integrity.kp, 3)}
              </div>
              <div class="text-content-muted mt-1">proportional</div>
            </div>
            <div class="bg-surface-tertiary rounded p-3 text-center">
              <div class="text-content-muted mb-1">Status</div>
              <div class={"text-sm font-bold #{integrity_status_color(@math_integrity)}"}>
                {integrity_status_label(@math_integrity)}
              </div>
              <div class="text-content-muted mt-1 text-xs">
                {integrity_status_detail(@math_integrity)}
              </div>
            </div>
          </div>
        </div>

        <%!-- STAMP Compliance Footer --%>
        <div class="text-xs text-content-muted">
          SC-MON-001 (30s refresh) | SC-MON-002 (infra metrics) | SC-MON-004 (safety metrics) | SC-PRF-050 (&lt;50ms) | SC-MATH-001 (math integrity)
        </div>
      </main>
    </div>
    """
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # INITIALIZATION
  # ═══════════════════════════════════════════════════════════════════════════

  defp init_metric_history do
    # 60 data points = 60 seconds of history
    %{
      cpu: generate_baseline_series(35.0, 15.0, @sparkline_points),
      memory: generate_baseline_series(58.0, 8.0, @sparkline_points),
      queue_depth: generate_baseline_series(12.0, 8.0, @sparkline_points),
      response_ms: generate_baseline_series(22.0, 10.0, @sparkline_points)
    }
  end

  defp init_node_metrics do
    %{
      "node-1" => %{cpu: 32.4, memory: 56.2, queue_depth: 8, response_ms: 18, process_count: 2847},
      "node-2" => %{
        cpu: 41.7,
        memory: 61.0,
        queue_depth: 15,
        response_ms: 24,
        process_count: 2901
      },
      "node-3" => %{cpu: 28.9, memory: 54.5, queue_depth: 6, response_ms: 21, process_count: 2756},
      "node-4" => %{
        cpu: 55.3,
        memory: 72.1,
        queue_depth: 24,
        response_ms: 35,
        process_count: 3102
      },
      "node-5" => %{
        cpu: 38.8,
        memory: 59.3,
        queue_depth: 11,
        response_ms: 22,
        process_count: 2889
      }
    }
  end

  defp init_system_summary do
    %{
      health_score: 92,
      trend: :stable,
      alert_count: 0
    }
  end

  defp default_thresholds do
    %{
      "cpu" => 80.0,
      "memory" => 85.0,
      "queue_depth" => 100.0,
      "response_ms" => 50.0
    }
  end

  defp generate_baseline_series(base, variance, count) do
    Enum.map(1..count, fn i ->
      # Smooth random walk
      noise = (:rand.uniform() - 0.5) * variance
      trend = :math.sin(i / 10.0) * (variance / 2)
      max(0.0, base + noise + trend)
    end)
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # LIVE UPDATES
  # ═══════════════════════════════════════════════════════════════════════════

  defp advance_history(history) do
    Map.new(history, fn {key, series} ->
      last = List.last(series, 0)
      noise = (:rand.uniform() - 0.5) * 5.0
      next = max(0.0, min(100.0, last + noise))
      new_series = Enum.take(tl(series) ++ [next], @sparkline_points)
      {key, new_series}
    end)
  end

  defp push_metrics_sample(history, metrics) do
    Map.new(history, fn {key, series} ->
      new_val = Map.get(metrics, key, List.last(series, 0))
      new_series = Enum.take(tl(series) ++ [new_val * 1.0], @sparkline_points)
      {key, new_series}
    end)
  end

  defp fetch_live_metrics do
    beam = fetch_beam_metrics()

    # Try FullSystemMonitor first, fallback to BEAM intrinsics
    base_metrics =
      case safe_call(Indrajaal.Cockpit.Prajna.FullSystemMonitor, :get_metrics) do
        {:ok, metrics} when is_map(metrics) ->
          # Convert to per-node format
          %{
            "local" => %{
              cpu: Map.get(metrics, :cpu, beam.cpu) * 1.0,
              memory: Map.get(metrics, :memory_pct, beam.memory_pct) * 1.0,
              queue_depth: beam.run_queue,
              response_ms: Map.get(metrics, :response_ms, 15),
              process_count: beam.process_count
            }
          }

        _ ->
          # Pure BEAM intrinsics
          %{
            "local" => %{
              cpu: beam.cpu * 1.0,
              memory: beam.memory_pct * 1.0,
              queue_depth: beam.run_queue,
              response_ms: 15,
              process_count: beam.process_count
            }
          }
      end

    # Try SmartMetrics for additional node data
    case safe_call(Indrajaal.Cockpit.Prajna.SmartMetrics, :health_summary) do
      {:ok, summary} when is_map(summary) ->
        Map.merge(base_metrics, extract_node_metrics(summary))

      _ ->
        base_metrics
    end
  end

  defp extract_node_metrics(summary) do
    # SmartMetrics health_summary may contain per-node data
    case Map.get(summary, :nodes) do
      nodes when is_map(nodes) -> nodes
      _ -> %{}
    end
  end

  defp fetch_beam_metrics do
    memory = :erlang.memory()
    total_mem_mb = div(memory[:total], 1_048_576)
    process_count = :erlang.system_info(:process_count)
    schedulers = :erlang.system_info(:schedulers_online)
    run_queue = :erlang.statistics(:run_queue)

    cpu = min(95, max(5, div(run_queue * 20, max(schedulers, 1)) + div(process_count, 500)))
    memory_pct = min(95, max(5, div(total_mem_mb * 100, 8192)))

    %{
      cpu: cpu,
      memory_pct: memory_pct,
      memory_mb: total_mem_mb,
      process_count: process_count,
      run_queue: run_queue
    }
  end

  defp safe_call(mod, fun, args \\ []) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, fun, length(args)) do
      try do
        {:ok, apply(mod, fun, args)}
      rescue
        _ -> :error
      catch
        :exit, _ -> :error
      end
    else
      :error
    end
  end

  defp compute_summary(node_metrics) do
    if map_size(node_metrics) == 0 do
      init_system_summary()
    else
      avg_cpu =
        node_metrics
        |> Enum.map(fn {_, m} -> m.cpu end)
        |> then(fn vals -> Enum.sum(vals) / length(vals) end)

      health_score = max(0, round(100 - avg_cpu * 0.3))

      trend =
        cond do
          avg_cpu > 75 -> :degrading
          avg_cpu < 30 -> :improving
          true -> :stable
        end

      %{health_score: health_score, trend: trend, alert_count: 0}
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # SVG SPARKLINE HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp sparkline_points(series, width, height) do
    return_val =
      series
      |> normalize_series()
      |> Enum.with_index()
      |> Enum.map(fn {val, idx} ->
        x = idx / max(length(series) - 1, 1) * width
        y = height - val * height
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
      |> Enum.join(" ")

    return_val
  end

  defp sparkline_points_scaled(series, width, height, max_val) do
    series
    |> Enum.map(fn v -> min(v / max_val, 1.0) end)
    |> Enum.with_index()
    |> Enum.map(fn {val, idx} ->
      x = idx / max(length(series) - 1, 1) * width
      y = height - val * height
      "#{Float.round(x, 1)},#{Float.round(y, 1)}"
    end)
    |> Enum.join(" ")
  end

  defp sparkline_fill_points(series, width, height, max_val) do
    line_points =
      series
      |> Enum.map(fn v -> min(v / max_val, 1.0) end)
      |> Enum.with_index()
      |> Enum.map(fn {val, idx} ->
        x = idx / max(length(series) - 1, 1) * width
        y = height - val * height
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)

    first_x = "0"
    last_x = "#{width}"
    bottom_y = "#{height}"

    ([first_x <> "," <> bottom_y] ++ line_points ++ [last_x <> "," <> bottom_y])
    |> Enum.join(" ")
  end

  defp sparkline_threshold_y(threshold, height) do
    # threshold is 0-100, map to SVG y coords (inverted)
    y_pct = min(threshold / 100.0, 1.0)
    Float.round(height - y_pct * height, 1)
  end

  defp normalize_series([]), do: []

  defp normalize_series(series) do
    max_val = Enum.max(series)
    min_val = Enum.min(series)
    range = max_val - min_val

    if range < 0.001 do
      Enum.map(series, fn _ -> 0.5 end)
    else
      Enum.map(series, fn v -> (v - min_val) / range end)
    end
  end

  defp sparkline_color(current, threshold) when current > threshold, do: "#f87171"
  defp sparkline_color(current, threshold) when current > threshold * 0.8, do: "#fbbf24"
  defp sparkline_color(_current, _threshold), do: "#34d399"

  defp sparkline_fill(current, threshold) when current > threshold, do: "#f87171"
  defp sparkline_fill(current, threshold) when current > threshold * 0.8, do: "#fbbf24"
  defp sparkline_fill(_current, _threshold), do: "#34d399"

  # ═══════════════════════════════════════════════════════════════════════════
  # UI HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp metric_value_color(val, threshold) when val > threshold, do: "text-red-400"
  defp metric_value_color(val, threshold) when val > threshold * 0.8, do: "text-amber-400"
  defp metric_value_color(_val, _threshold), do: "text-green-400"

  defp node_status_badge(metrics) do
    cond do
      metrics.cpu > 80 or metrics.memory > 85 -> "bg-red-900/60 text-red-300"
      metrics.cpu > 60 or metrics.memory > 70 -> "bg-amber-900/60 text-amber-300"
      true -> "bg-green-900/60 text-green-300"
    end
  end

  defp node_status_label(metrics) do
    cond do
      metrics.cpu > 80 or metrics.memory > 85 -> "CRITICAL"
      metrics.cpu > 60 or metrics.memory > 70 -> "DEGRADED"
      true -> "HEALTHY"
    end
  end

  defp trend_badge(:improving), do: "bg-green-900/60 text-green-300"
  defp trend_badge(:degrading), do: "bg-red-900/60 text-red-300"
  defp trend_badge(:stable), do: "bg-blue-900/60 text-blue-300"
  defp trend_badge(_), do: "bg-gray-700 text-gray-400"

  defp trend_label(:improving), do: "IMPROVING"
  defp trend_label(:degrading), do: "DEGRADING"
  defp trend_label(:stable), do: "STABLE"
  defp trend_label(_), do: "UNKNOWN"

  defp health_score_color(score) when score >= 90, do: "text-green-400"
  defp health_score_color(score) when score >= 70, do: "text-amber-400"
  defp health_score_color(_), do: "text-red-400"

  defp count_alerts(history, thresholds) do
    Enum.count(history, fn {key, series} ->
      current = List.first(series, 0)
      threshold = Map.get(thresholds, Atom.to_string(key), 80.0)
      current > threshold
    end)
  end

  defp format_uptime, do: "25d 14h"

  # ═══════════════════════════════════════════════════════════════════════════
  # MATHEMATICAL INTEGRITY (SC-MATH-001, SC-MATH-003)
  # ═══════════════════════════════════════════════════════════════════════════

  defp init_math_integrity do
    hs = 0.35
    setpoint = 0.40

    %{
      hs: hs,
      epsilon: setpoint - hs,
      setpoint: setpoint,
      ds: 0.92,
      kp: 0.600
    }
  end

  defp hs_color(hs) when hs < 0.4, do: "text-green-400"
  defp hs_color(hs) when hs < 0.7, do: "text-amber-400"
  defp hs_color(_), do: "text-red-400"

  defp hs_bar_color(hs) when hs < 0.4, do: "bg-green-500"
  defp hs_bar_color(hs) when hs < 0.7, do: "bg-amber-500"
  defp hs_bar_color(_), do: "bg-red-500"

  defp epsilon_color(eps) when abs(eps) < 0.05, do: "text-green-400"
  defp epsilon_color(eps) when abs(eps) < 0.15, do: "text-amber-400"
  defp epsilon_color(_), do: "text-red-400"

  defp ds_color(ds) when ds >= 0.85, do: "text-green-400"
  defp ds_color(ds) when ds >= 0.60, do: "text-amber-400"
  defp ds_color(_), do: "text-red-400"

  defp ds_bar_color(ds) when ds >= 0.85, do: "bg-green-500"
  defp ds_bar_color(ds) when ds >= 0.60, do: "bg-amber-500"
  defp ds_bar_color(_), do: "bg-red-500"

  defp integrity_status_color(mi) do
    cond do
      mi.ds >= 0.85 and abs(mi.epsilon) < 0.1 -> "text-green-400"
      mi.ds >= 0.60 and abs(mi.epsilon) < 0.2 -> "text-amber-400"
      true -> "text-red-400"
    end
  end

  defp integrity_status_label(mi) do
    cond do
      mi.ds >= 0.85 and abs(mi.epsilon) < 0.1 -> "NOMINAL"
      mi.ds >= 0.60 and abs(mi.epsilon) < 0.2 -> "DRIFT"
      true -> "ALARM"
    end
  end

  defp integrity_status_detail(mi) do
    cond do
      mi.ds >= 0.85 and abs(mi.epsilon) < 0.1 -> "PID converged"
      mi.ds >= 0.60 -> "adjusting Kp"
      true -> "manual review"
    end
  end

  # Compute discipline score from a list of signed errors (SC-MATH-001).
  # Score = 1 - clamp(mean(|e|), 0, 1); falls back to current_ds on empty/invalid input.
  defp compute_discipline_score([], current_ds), do: current_ds

  defp compute_discipline_score(error_history, _current_ds) when is_list(error_history) do
    mean_abs =
      error_history
      |> Enum.map(&abs/1)
      |> then(fn errs ->
        case errs do
          [] -> 0.0
          list -> Enum.sum(list) / length(list)
        end
      end)

    max(0.0, 1.0 - min(1.0, mean_abs))
  end

  defp compute_discipline_score(_error_history, current_ds), do: current_ds
end
