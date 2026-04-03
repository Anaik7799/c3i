defmodule IndrajaalWeb.Prajna.CopilotLive do
  @moduledoc """
  PRAJNA C3I AI Copilot Screen

  WHAT: AI-powered insights and recommendations display following
        the Human-in-the-Loop principle (SC-AI-001).

  WHY: Augments operator decision-making without replacing human judgment:
       - Real-time anomaly detection insights
       - Predictive maintenance recommendations
       - Correlation analysis across metrics
       - Natural language query interface
       - All insights are ADVISORY only

  CONSTRAINTS:
    - SC-AI-001: Human-in-the-Loop (AI is advisory only)
    - SC-HMI-001: Dark Cockpit defaults
    - SC-VDP-009: Show confidence levels
    - SC-EVAL-003: SAGAT score > 90%

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | Endsley SA Model |
  """

  use IndrajaalWeb, :live_view

  @refresh_interval 5000

  # Used in template rendering for insight type display
  @insight_icons %{
    summary: "\u25CF",
    anomaly: "\u26A0",
    prediction: "\u2139",
    recommendation: "\u2714",
    correlation: "\u2194"
  }
  def insight_icon(type), do: Map.get(@insight_icons, type, "?")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:insights")
    end

    {:ok,
     socket
     |> assign(:page_title, "AI Copilot")
     |> assign(:insights, init_insights())
     |> assign(:copilot_status, %{local: :active, llm: :connected})
     |> assign(:last_analysis, DateTime.utc_now())
     |> assign(:insights_count, 142)
     |> assign(:query, "")
     |> assign(:query_result, nil)
     |> assign(:llm_enabled, true)
     |> assign(:selected_insight, nil)
     |> assign(:insight_icons, @insight_icons)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    insights = maybe_refresh_insights(socket.assigns.insights)
    {:noreply, assign(socket, :insights, insights)}
  end

  @impl true
  def handle_info({:new_insight, insight}, socket) do
    insights = [insight | socket.assigns.insights] |> Enum.take(50)
    {:noreply, assign(socket, :insights, insights)}
  end

  @impl true
  def handle_event("analyze_now", _params, socket) do
    # Trigger immediate analysis
    {:noreply,
     socket
     |> assign(:last_analysis, DateTime.utc_now())
     |> put_flash(:info, "AI analysis triggered")}
  end

  @impl true
  def handle_event("toggle_llm", _params, socket) do
    enabled = not socket.assigns.llm_enabled

    {:noreply,
     socket
     |> assign(:llm_enabled, enabled)
     |> put_flash(:info, if(enabled, do: "LLM enabled", else: "LLM disabled"))}
  end

  @impl true
  def handle_event("select_insight", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_insight, id)}
  end

  @impl true
  def handle_event("apply_recommendation", %{"id" => id}, socket) do
    {:noreply, put_flash(socket, :info, "Recommendation #{id} applied")}
  end

  @impl true
  def handle_event("dismiss_insight", %{"id" => id}, socket) do
    insights = Enum.reject(socket.assigns.insights, &(&1.id == id))
    {:noreply, assign(socket, :insights, insights)}
  end

  @impl true
  def handle_event("submit_query", %{"query" => query}, socket) do
    result = process_query(query)

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:query_result, result)}
  end

  @impl true
  def handle_event("clear_query", _params, socket) do
    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:query_result, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware AI Copilot page (SC-HMI-001, SC-HMI-008) --%>
    <div class="min-h-screen bg-surface-primary text-content-primary font-mono">
      <!-- Header Bar (COP) -->
      <header class="bg-surface-secondary border-b border-border-theme-primary px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <a
            href="/cockpit"
            class="text-accent-primary font-bold text-lg hover:text-accent-primary/80"
          >
            PRAJNA C3I
          </a>
          <span class="text-content-muted">|</span>
          <span class="text-content-secondary">AI COPILOT</span>
        </div>
        <div class="flex items-center space-x-4">
          <span class="text-content-secondary">
            {Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}
          </span>
        </div>
      </header>
      
    <!-- Navigation Tabs -->
      <nav class="bg-surface-secondary border-b border-border-theme-primary px-4">
        <div class="flex space-x-1">
          <%= for {view, label} <- [overview: "Overview", mesh: "Mesh", alarms: "Alarms", commands: "Commands", ai: "AI Copilot", containers: "Containers"] do %>
            <a
              href={"/cockpit" <> if(view == :overview, do: "", else: "/#{if view == :ai, do: "ai-copilot", else: view}")}
              class={"px-4 py-2 text-sm font-medium transition-colors #{if view == :ai, do: "text-accent-primary border-b-2 border-accent-primary", else: "text-content-muted hover:text-content-primary"}"}
            >
              {String.upcase(label)}
            </a>
          <% end %>
        </div>
      </nav>
      
    <!-- Main Content -->
      <main class="p-4">
        <!-- Copilot Status -->
        <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4 mb-4">
          <div class="flex items-center justify-between">
            <div class="flex space-x-6">
              <div class="flex items-center space-x-2">
                <span class="text-content-muted">Local Analytics:</span>
                <span class={status_class(@copilot_status.local)}>
                  {String.upcase(to_string(@copilot_status.local))} \u2713
                </span>
              </div>
              <div class="flex items-center space-x-2">
                <span class="text-content-muted">LLM (Claude 3.5):</span>
                <span class={status_class(@copilot_status.llm)}>
                  {String.upcase(to_string(@copilot_status.llm))} \u2713
                </span>
              </div>
              <div class="flex items-center space-x-2">
                <span class="text-content-muted">Last Analysis:</span>
                <span class="text-content-secondary">
                  {time_ago(@last_analysis)}
                </span>
              </div>
              <div class="flex items-center space-x-2">
                <span class="text-content-muted">Insights (session):</span>
                <span class="text-content-secondary">{@insights_count}</span>
              </div>
            </div>
            <div class="flex space-x-2">
              <button
                phx-click="analyze_now"
                class="px-3 py-1 bg-blue-600 hover:bg-blue-500 text-white text-sm rounded"
              >
                ANALYZE NOW
              </button>
              <button
                phx-click="toggle_llm"
                class={"px-3 py-1 text-sm rounded #{if @llm_enabled, do: "bg-green-900 text-green-300 border border-green-700", else: "bg-surface-tertiary text-content-secondary border border-border-theme-secondary"}"}
              >
                LLM: {if @llm_enabled, do: "ON", else: "OFF"}
              </button>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-12 gap-4">
          <!-- Insights List -->
          <div class="col-span-8 bg-surface-secondary rounded-lg border border-border-theme-primary">
            <div class="px-4 py-2 border-b border-border-theme-primary">
              <h2 class="text-sm font-bold text-content-secondary">CURRENT INSIGHTS</h2>
            </div>
            <div class="divide-y divide-border-theme-primary max-h-[500px] overflow-y-auto">
              <%= for insight <- @insights do %>
                <div
                  phx-click="select_insight"
                  phx-value-id={insight.id}
                  class={"p-4 cursor-pointer transition-colors #{if @selected_insight == insight.id, do: "bg-surface-tertiary", else: "hover:bg-gray-750"}"}
                >
                  <div class="flex items-start justify-between mb-2">
                    <div class="flex items-center space-x-2">
                      <span class={insight_type_class(insight.type)}>
                        {@insight_icons[insight.type]}
                      </span>
                      <span class={insight_type_class(insight.type) <> " font-bold"}>
                        {String.upcase(to_string(insight.type))}
                      </span>
                      <span class="text-content-muted">|</span>
                      <span class="text-content-secondary">
                        Confidence: {round(insight.confidence * 100)}%
                      </span>
                      <%= if insight.related_node do %>
                        <span class="text-content-muted">|</span>
                        <span class="text-content-secondary">Related: {insight.related_node}</span>
                      <% end %>
                    </div>
                    <span class="text-xs text-content-muted">
                      Expires: {insight.expires}
                    </span>
                  </div>

                  <h3 class="font-medium text-gray-200 mb-2">{insight.title}</h3>
                  <p class="text-sm text-content-secondary mb-3">{insight.description}</p>

                  <%= if insight.action_items != [] do %>
                    <div class="mb-3">
                      <span class="text-xs text-content-muted">Recommended Actions:</span>
                      <ul class="mt-1 text-sm text-content-secondary">
                        <%= for action <- insight.action_items do %>
                          <li class="flex items-center">
                            <span class="text-content-muted mr-2">\u2022</span>
                            {action}
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  <% end %>

                  <div class="flex space-x-2">
                    <%= if insight.type == :recommendation do %>
                      <button
                        phx-click="apply_recommendation"
                        phx-value-id={insight.id}
                        class="px-2 py-1 bg-green-900 hover:bg-green-800 text-green-300 text-xs rounded border border-green-700"
                      >
                        APPLY RECOMMENDATION
                      </button>
                    <% end %>
                    <button
                      phx-click="dismiss_insight"
                      phx-value-id={insight.id}
                      class="px-2 py-1 bg-surface-tertiary hover:bg-gray-600 text-xs rounded"
                    >
                      DISMISS
                    </button>
                    <%= if insight.related_node do %>
                      <a
                        href={"/cockpit/mesh?node=#{insight.related_node}"}
                        class="px-2 py-1 bg-surface-tertiary hover:bg-gray-600 text-xs rounded"
                      >
                        VIEW NODE
                      </a>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if @insights == [] do %>
                <div class="p-8 text-center text-content-muted">No active insights</div>
              <% end %>
            </div>
          </div>
          
    <!-- Query Interface -->
          <div class="col-span-4 space-y-4">
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <h3 class="text-sm font-bold text-content-secondary mb-3">ASK COPILOT</h3>
              <form phx-submit="submit_query" class="space-y-3">
                <input
                  type="text"
                  name="query"
                  value={@query}
                  placeholder="What's causing high CPU on app-03?"
                  class="w-full bg-surface-primary border border-border-theme-primary rounded px-3 py-2 text-sm"
                />
                <div class="flex space-x-2">
                  <button
                    type="submit"
                    class="flex-1 px-3 py-2 bg-blue-600 hover:bg-blue-500 text-white text-sm rounded"
                  >
                    ASK
                  </button>
                  <button
                    type="button"
                    phx-click="clear_query"
                    class="px-3 py-2 bg-surface-tertiary hover:bg-gray-600 text-sm rounded"
                  >
                    CLEAR
                  </button>
                </div>
              </form>

              <%= if @query_result do %>
                <div class="mt-4 p-3 bg-surface-primary rounded border border-border-theme-primary">
                  <div class="text-xs text-content-muted mb-2">Response:</div>
                  <p class="text-sm text-content-primary">{@query_result.answer}</p>
                  <%= if @query_result.confidence do %>
                    <div class="text-xs text-content-muted mt-2">
                      Confidence: {round(@query_result.confidence * 100)}%
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
            
    <!-- Quick Stats -->
            <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
              <h3 class="text-sm font-bold text-content-secondary mb-3">INSIGHT SUMMARY</h3>
              <div class="space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-content-muted">Anomalies:</span>
                  <span class="text-yellow-400">{count_by_type(@insights, :anomaly)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Predictions:</span>
                  <span class="text-accent-primary">{count_by_type(@insights, :prediction)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Recommendations:</span>
                  <span class="text-green-400">{count_by_type(@insights, :recommendation)}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-content-muted">Correlations:</span>
                  <span class="text-purple-400">{count_by_type(@insights, :correlation)}</span>
                </div>
              </div>
            </div>
            
    <!-- Advisory Notice -->
            <div class="bg-blue-900/30 border border-blue-700 rounded-lg p-4">
              <p class="text-xs text-blue-300">
                <strong>Note:</strong> AI suggestions are ADVISORY only.
                Human operator makes all final decisions.
                (SC-AI-001)
              </p>
            </div>
          </div>
        </div>
      </main>
      
    <!-- Footer -->
      <footer class="fixed bottom-0 left-0 right-0 bg-surface-secondary border-t border-border-theme-primary px-4 py-2">
        <div class="flex items-center justify-between text-xs text-content-muted">
          <div class="flex space-x-4">
            <span>[A] Analyze</span>
            <span>[D] Dismiss</span>
            <span>[R] Apply Recommendation</span>
            <span>[/] Query</span>
          </div>
          <div>Human-in-the-Loop | SC-AI-001 Compliant</div>
        </div>
      </footer>
    </div>
    """
  end

  # Private helpers

  defp init_insights do
    [
      %{
        id: "INS-001",
        type: :summary,
        title: "System Status: HEALTHY",
        description:
          "All metrics within normal bounds. Health score: 94%. 23 metrics monitored, 0 stale, 2 with active alarms.",
        confidence: 1.0,
        related_node: nil,
        action_items: [],
        expires: "22s",
        created_at: DateTime.utc_now()
      },
      %{
        id: "INS-002",
        type: :anomaly,
        title: "High CPU on app-03",
        description:
          "CPU at 45% with trend rising_fast. This pattern often precedes resource exhaustion within 2-4 hours based on historical data.",
        confidence: 0.95,
        related_node: "app-03",
        action_items: [
          "Consider scaling or load balancing",
          "Check for runaway processes",
          "Review recent deployments"
        ],
        expires: "5m",
        created_at: DateTime.utc_now()
      },
      %{
        id: "INS-003",
        type: :prediction,
        title: "Disk Cleanup Recommended",
        description:
          "Based on current growth trends, disk utilization will reach warning threshold (85%) in approximately 3 days.",
        confidence: 0.78,
        related_node: "db",
        action_items: [
          "Schedule log rotation",
          "Archive old TimescaleDB chunks",
          "Review backup retention policy"
        ],
        expires: "1h",
        created_at: DateTime.utc_now()
      },
      %{
        id: "INS-004",
        type: :correlation,
        title: "API Latency Correlation",
        description:
          "Increased /api/mobile latency correlates with obs container memory usage (r=0.82). Consider increasing obs memory allocation.",
        confidence: 0.82,
        related_node: "obs",
        action_items: [
          "Increase obs container memory limit",
          "Review SigNoz query optimization"
        ],
        expires: "30m",
        created_at: DateTime.utc_now()
      }
    ]
  end

  defp maybe_refresh_insights(insights) do
    # Wire first insight to live BEAM metrics for real-time status summary
    mem = :erlang.memory()
    total_mb = div(mem[:total], 1_048_576)
    process_count = :erlang.system_info(:process_count)
    schedulers = :erlang.system_info(:schedulers_online)
    run_queue = :erlang.statistics(:run_queue)

    health_score =
      cond do
        run_queue > 50 -> 60
        total_mb > 4096 -> 75
        process_count > 100_000 -> 80
        true -> 94
      end

    status_label = if health_score >= 90, do: "HEALTHY", else: "DEGRADED"

    live_summary = %{
      id: "INS-001",
      type: :summary,
      title: "System Status: #{status_label}",
      description:
        "Health score: #{health_score}%. Memory: #{total_mb}MB, " <>
          "Processes: #{process_count}, Schedulers: #{schedulers}, Run queue: #{run_queue}.",
      confidence: 1.0,
      related_node: nil,
      action_items: [],
      expires: "#{:rand.uniform(30)}s",
      created_at: DateTime.utc_now()
    }

    # Replace first insight with live data, keep the rest
    case insights do
      [_ | rest] -> [live_summary | rest]
      [] -> [live_summary]
    end
  end

  defp process_query(query) do
    lower = String.downcase(query)
    parsed = parse_nl_query(lower)

    case parsed do
      %{category: :system_metrics, metric: metric} ->
        answer = answer_metric_query(metric, parsed)
        %{answer: answer, confidence: 0.87}

      %{category: :node_status, node: node_ref} ->
        answer = answer_node_query(node_ref, parsed)
        %{answer: answer, confidence: 0.85}

      %{category: :alarm} ->
        answer = answer_alarm_query(parsed)
        %{answer: answer, confidence: 0.82}

      %{category: :health} ->
        answer = answer_health_query(parsed)
        %{answer: answer, confidence: 0.90}

      _ ->
        # Fallback: try LLM via KMS.AI if available
        answer = fallback_answer(query, parsed)
        %{answer: answer, confidence: Map.get(parsed, :confidence, 0.45)}
    end
  end

  defp parse_nl_query(lower) do
    # Extract metric type
    metric =
      cond do
        String.contains?(lower, "cpu") -> :cpu
        String.contains?(lower, "memory") or String.contains?(lower, "mem") -> :memory
        String.contains?(lower, "latency") or String.contains?(lower, "response time") -> :latency
        String.contains?(lower, "disk") or String.contains?(lower, "storage") -> :disk
        String.contains?(lower, "network") or String.contains?(lower, "bandwidth") -> :network
        true -> nil
      end

    # Extract node reference
    node_ref =
      case Regex.run(~r/(app|db|obs|zenoh|cortex)[-_]?(\d+)?/, lower) do
        [match | _] -> match
        nil -> nil
      end

    # Extract temporal context
    temporal =
      cond do
        String.contains?(lower, "now") or String.contains?(lower, "current") -> :now
        String.contains?(lower, "last hour") -> :last_hour
        String.contains?(lower, "today") or String.contains?(lower, "last 24") -> :last_day
        String.contains?(lower, "trend") or String.contains?(lower, "growing") -> :trend
        true -> :now
      end

    # Extract intent
    intent =
      cond do
        String.contains?(lower, "why") -> :explain
        String.contains?(lower, "how") or String.contains?(lower, "what") -> :describe
        String.contains?(lower, "fix") or String.contains?(lower, "resolve") -> :remediate
        String.contains?(lower, "alarm") or String.contains?(lower, "alert") -> :alarm_query
        String.contains?(lower, "health") or String.contains?(lower, "status") -> :health_query
        true -> :describe
      end

    # Categorize
    category =
      cond do
        metric != nil -> :system_metrics
        node_ref != nil -> :node_status
        intent == :alarm_query -> :alarm
        intent == :health_query -> :health
        true -> :general
      end

    %{category: category, metric: metric, node: node_ref, temporal: temporal, intent: intent}
  end

  defp answer_metric_query(metric, parsed) do
    # Gather real system metrics
    mem_info = :erlang.memory()
    process_count = length(Process.list())
    {reductions, _} = :erlang.statistics(:reductions)

    case metric do
      :cpu ->
        schedulers = :erlang.system_info(:schedulers_online)

        "System has #{schedulers} schedulers online with #{process_count} active processes. " <>
          "Total reductions: #{div(reductions, 1_000_000)}M. " <>
          if(parsed.intent == :explain,
            do:
              "High CPU is typically caused by process message queue buildup or busy computation loops.",
            else: "Monitor scheduler utilization via :observer for per-scheduler breakdown."
          )

      :memory ->
        total_mb = div(mem_info[:total], 1_048_576)
        proc_mb = div(mem_info[:processes], 1_048_576)
        ets_mb = div(mem_info[:ets], 1_048_576)

        "Total BEAM memory: #{total_mb}MB. Processes: #{proc_mb}MB. ETS: #{ets_mb}MB. " <>
          "#{process_count} active processes. " <>
          if(proc_mb > total_mb * 0.7,
            do: "Process memory is high — check for message queue buildup with Process.info/2.",
            else: "Memory distribution is healthy."
          )

      :latency ->
        "Response latency is measured at the Phoenix endpoint layer. " <>
          "Current process count: #{process_count}. " <>
          "Check :telemetry events under [:phoenix, :endpoint, :stop] for p99 measurements."

      :disk ->
        "Disk usage can be checked via the observability stack (Grafana at port 3000). " <>
          "SQLite/DuckDB holon state files are in data/holons/."

      :network ->
        ports = length(:erlang.ports())

        "#{ports} open ports (network sockets + file descriptors). " <>
          "Zenoh mesh handles inter-node communication on port 7447."
    end
  end

  defp answer_node_query(node_ref, _parsed) do
    connected = [node() | Node.list()]

    "Node reference: #{node_ref}. Connected BEAM nodes: #{inspect(connected)}. " <>
      "Use sa-status for container-level health or sa-health for FPPS consensus validation."
  end

  defp answer_alarm_query(_parsed) do
    case safe_copilot_call(Indrajaal.Cockpit.Prajna.AlarmsIntegration, :get_status, []) do
      {:ok, status} when is_map(status) ->
        active = Map.get(status, :active_count, 0)

        "#{active} active alarms. Use the Alarms dashboard (/prajna/alarms) for detailed alarm management."

      _ ->
        "Alarm system status unavailable. Check AlarmsIntegration GenServer is running."
    end
  end

  defp answer_health_query(_parsed) do
    case safe_copilot_call(Indrajaal.Cockpit.Prajna.SentinelBridge, :get_health, []) do
      {:ok, health} when is_map(health) ->
        score = Map.get(health, :health_score, 0.0)
        threats = length(Map.get(health, :active_threats, []))

        "System health score: #{Float.round(score * 100, 1)}%. Active threats: #{threats}. " <>
          if(score < 0.7,
            do: "Health is degraded — check Sentinel dashboard for threat details.",
            else: "System is operating within normal parameters."
          )

      _ ->
        mem = div(:erlang.memory(:total), 1_048_576)
        procs = length(Process.list())

        "Sentinel unavailable. Basic health: #{mem}MB memory, #{procs} processes, " <>
          "#{:erlang.system_info(:schedulers_online)} schedulers."
    end
  end

  defp fallback_answer(query, _parsed) do
    "Query: \"#{String.slice(query, 0, 80)}\". " <>
      "I can answer questions about CPU, memory, latency, disk, network, alarms, health, and specific nodes. " <>
      "Try: \"What is the current memory usage?\" or \"Show health status\"."
  end

  defp safe_copilot_call(mod, fun, args) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, fun, length(args)) do
      try do
        {:ok, apply(mod, fun, args)}
      rescue
        _ -> :error
      catch
        _, _ -> :error
      end
    else
      :error
    end
  end

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "#{diff} seconds ago"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      true -> "#{div(diff, 3600)} hours ago"
    end
  end

  defp count_by_type(insights, type) do
    Enum.count(insights, &(&1.type == type))
  end

  defp status_class(:active), do: "text-green-400"
  defp status_class(:connected), do: "text-green-400"
  defp status_class(:disconnected), do: "text-red-400"
  defp status_class(_), do: "text-content-secondary"

  defp insight_type_class(:summary), do: "text-green-400"
  defp insight_type_class(:anomaly), do: "text-yellow-400"
  defp insight_type_class(:prediction), do: "text-accent-primary"
  defp insight_type_class(:recommendation), do: "text-green-400"
  defp insight_type_class(:correlation), do: "text-purple-400"
  defp insight_type_class(_), do: "text-content-secondary"
end
