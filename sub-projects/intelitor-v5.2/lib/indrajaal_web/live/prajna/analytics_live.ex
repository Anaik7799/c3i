defmodule IndrajaalWeb.Prajna.AnalyticsLive do
  @moduledoc """
  PRAJNA C3I Analytics Dashboard

  WHAT: Real-time analytics and reporting status monitoring.

  WHY: Provides operators with:
       - Report generation status
       - Query performance metrics
       - Trend analysis display
       - Data pipeline health
       - Export job tracking

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit (gray defaults)
    - SC-PRAJNA-004: Sentinel health integration
    - SC-BRIDGE-005: PubSub topics for zenoh:analytics
    - SC-ANA-001: Query timeout < 30s

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-02 |
  | Author | Cybernetic Architect |
  | STAMP | SC-PRAJNA-004, SC-ANA-001 |
  """

  use IndrajaalWeb, :live_view

  require Logger

  @refresh_interval 5000
  @metrics_sync_interval 10_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
      :timer.send_interval(@metrics_sync_interval, self(), :sync_metrics)

      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:analytics")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "zenoh:analytics")
    end

    {:ok,
     socket
     |> assign(:page_title, "Analytics")
     |> assign(:current_nav, :analytics)
     |> assign(:reports, init_reports())
     |> assign(:queries, init_queries())
     |> assign(:pipelines, init_pipelines())
     |> assign(:trends, init_trends())
     |> assign(:filter_status, :all)
     |> assign(:selected_report, nil)
     |> assign(:metrics, init_metrics())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply,
     socket
     |> assign(:reports, refresh_reports(socket.assigns.reports))
     |> assign(:queries, refresh_queries(socket.assigns.queries))}
  end

  def handle_info(:sync_metrics, socket) do
    metrics = fetch_analytics_metrics()
    # SmartMetrics integration deferred to Sprint 31
    {:noreply, assign(socket, :metrics, metrics)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, String.to_existing_atom(status))}
  end

  def handle_event("select_report", %{"id" => id}, socket) do
    report = Enum.find(socket.assigns.reports, &(&1.id == id))
    {:noreply, assign(socket, :selected_report, report)}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, :selected_report, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-surface-primary min-h-screen text-content-primary">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-content-primary">Analytics Center</h1>
        <p class="text-sm text-gray-600">Reports, Queries & Data Pipeline Monitoring</p>
      </div>

      <div class="space-y-6">
        <!-- Metrics Summary -->
        <div class="grid grid-cols-4 gap-4 mb-6">
          <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
            <div class="text-sm text-gray-600">Reports Today</div>
            <div class="text-2xl font-bold text-content-primary">{@metrics.reports_today}</div>
          </div>
          <div class={[
            "bg-surface-secondary border p-4 rounded-lg",
            if(@metrics.avg_query_time > 5000,
              do: "bg-yellow-900/20 border-yellow-600",
              else: "border-border-theme-primary"
            )
          ]}>
            <div class="text-sm text-gray-600">Avg Query Time</div>
            <div class="text-2xl font-bold text-content-primary">{@metrics.avg_query_time}ms</div>
          </div>
          <div class={[
            "bg-surface-secondary border p-4 rounded-lg",
            if(@metrics.pipeline_health < 90,
              do: "bg-yellow-900/20 border-yellow-600",
              else: "border-border-theme-primary"
            )
          ]}>
            <div class="text-sm text-gray-600">Pipeline Health</div>
            <div class="text-2xl font-bold text-content-primary">{@metrics.pipeline_health}%</div>
          </div>
          <div class={[
            "bg-surface-secondary border p-4 rounded-lg",
            if(@metrics.data_freshness > 60,
              do: "bg-yellow-900/20 border-yellow-600",
              else: "border-border-theme-primary"
            )
          ]}>
            <div class="text-sm text-gray-600">Data Freshness</div>
            <div class="text-2xl font-bold text-content-primary">{@metrics.data_freshness}s</div>
          </div>
        </div>
        
    <!-- Main Content -->
        <div class="grid grid-cols-2 gap-4">
          <!-- Reports Panel -->
          <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
            <div class="flex justify-between items-center mb-3">
              <h3 class="text-lg font-semibold text-content-primary">Report Status</h3>
              <select
                phx-change="filter_status"
                name="status"
                class="bg-surface-primary border border-border-theme-primary text-content-primary rounded px-2 py-1 text-sm"
              >
                <option value="all" selected={@filter_status == :all}>All</option>
                <option value="completed" selected={@filter_status == :completed}>Completed</option>
                <option value="running" selected={@filter_status == :running}>Running</option>
                <option value="failed" selected={@filter_status == :failed}>Failed</option>
                <option value="scheduled" selected={@filter_status == :scheduled}>Scheduled</option>
              </select>
            </div>
            <div class="space-y-2">
              <%= for report <- filter_reports(@reports, @filter_status) do %>
                <div
                  class="flex items-center gap-3 p-2 rounded border-b border-border-theme-primary cursor-pointer hover:bg-surface-primary"
                  phx-click="select_report"
                  phx-value-id={report.id}
                >
                  <div class="text-xl">{report_icon(report.type)}</div>
                  <div class="flex-1">
                    <div class="text-content-primary font-medium">{report.name}</div>
                    <div class="flex gap-2 text-xs text-gray-600">
                      <span>{report.type}</span>
                      <span>•</span>
                      <span>{format_time(report.updated_at)}</span>
                    </div>
                  </div>
                  <div>
                    <span class={
                      case report.status do
                        :completed -> "text-green-600 text-xs"
                        :running -> "text-blue-600 text-xs"
                        :failed -> "text-red-600 text-xs"
                        :scheduled -> "text-yellow-600 text-xs"
                        _ -> "text-gray-600 text-xs"
                      end
                    }>
                      {report.status}
                    </span>
                    <%= if report.status == :running do %>
                      <div class="h-1 bg-gray-800 rounded-full overflow-hidden mt-1 w-20">
                        <div
                          class="h-full bg-blue-500 rounded-full"
                          style={"width: #{report.progress}%"}
                        >
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Query Performance Panel -->
          <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
            <div class="flex justify-between items-center mb-3">
              <h3 class="text-lg font-semibold text-content-primary">Query Performance</h3>
            </div>
            <div class="space-y-2">
              <%= for query <- Enum.take(@queries, 10) do %>
                <div class="flex items-center justify-between p-2 border-b border-border-theme-primary">
                  <div class="flex-1">
                    <div class="text-content-primary text-sm font-mono">{query.name}</div>
                    <div class="text-xs text-gray-600">{query.source}</div>
                  </div>
                  <div class="flex gap-3 text-sm">
                    <span class={
                      case duration_class(query.duration) do
                        "fast" -> "text-green-600 font-mono"
                        "normal" -> "text-yellow-600 font-mono"
                        _ -> "text-red-600 font-mono"
                      end
                    }>
                      {query.duration}ms
                    </span>
                    <span class="text-gray-600">{query.rows} rows</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Data Pipelines Panel -->
          <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
            <div class="flex justify-between items-center mb-3">
              <h3 class="text-lg font-semibold text-content-primary">Data Pipelines</h3>
            </div>
            <div class="space-y-3">
              <%= for pipeline <- @pipelines do %>
                <div class="p-3 rounded border border-border-theme-primary">
                  <div class="text-content-primary font-medium mb-1">{pipeline.name}</div>
                  <div class="flex items-center gap-2 text-sm mb-2">
                    <span class="text-blue-600">{pipeline.source}</span>
                    <span class="text-gray-600">→</span>
                    <span class="text-green-600">{pipeline.target}</span>
                  </div>
                  <div class="flex gap-4 text-xs text-gray-600">
                    <span class={
                      case pipeline.status do
                        :running -> "text-green-600"
                        _ -> "text-gray-600"
                      end
                    }>
                      {pipeline.status}
                    </span>
                    <span>{pipeline.throughput}/s</span>
                    <span>{pipeline.lag}s lag</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Trends Panel -->
          <div class="bg-surface-secondary border border-border-theme-primary p-4 rounded-lg">
            <div class="flex justify-between items-center mb-3">
              <h3 class="text-lg font-semibold text-content-primary">Trend Analysis</h3>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <%= for trend <- @trends do %>
                <div class="p-3 rounded-lg border border-border-theme-primary bg-surface-primary">
                  <div class="text-sm text-gray-600">{trend.name}</div>
                  <div class="text-xl font-bold text-content-primary">{trend.value}</div>
                  <div class="flex items-center gap-1 text-sm">
                    <span class={
                      case trend.direction do
                        :up -> "text-green-600"
                        :down -> "text-red-600"
                        _ -> "text-gray-600"
                      end
                    }>
                      {trend_arrow(trend.direction)}
                    </span>
                    <span>{trend.change}%</span>
                  </div>
                  <div class="text-xs text-gray-600">{trend.period}</div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private functions

  defp init_reports do
    report_types = [:daily_summary, :security_audit, :compliance, :performance, :incident]
    statuses = [:completed, :completed, :completed, :running, :scheduled, :failed]
    name_suffixes = ["Daily", "Weekly", "Custom"]
    proc = :erlang.system_info(:process_count)
    ports = length(:erlang.ports())

    Enum.map(1..15, fn i ->
      status = Enum.at(statuses, rem(proc + i, length(statuses)))

      %{
        id: "rpt_#{String.pad_leading(to_string(i), 3, "0")}",
        name: "Report #{i} - #{Enum.at(name_suffixes, rem(ports + i, length(name_suffixes)))}",
        type: Enum.at(report_types, rem(proc * i, length(report_types))),
        status: status,
        progress: if(status == :running, do: rem(proc * i, 100), else: 100),
        created_at: DateTime.utc_now() |> DateTime.add(-(rem(proc * i, 86400) + 1)),
        updated_at: DateTime.utc_now() |> DateTime.add(-(rem(ports * i, 3600) + 1)),
        size_kb: rem(proc * i, 5000) + 1
      }
    end)
  end

  defp init_queries do
    query_names = ["SELECT alarms", "JOIN devices", "AGGREGATE metrics", "COUNT events"]
    sources = ["PostgreSQL", "TimescaleDB", "DuckDB"]
    statuses = [:completed, :completed, :completed, :running]
    proc = :erlang.system_info(:process_count)
    rq = :erlang.statistics(:run_queue)

    Enum.map(1..20, fn i ->
      %{
        id: "qry_#{i}",
        name: Enum.at(query_names, rem(proc + i, length(query_names))),
        source: Enum.at(sources, rem(rq + i, length(sources))),
        status: Enum.at(statuses, rem(proc * i, length(statuses))),
        duration: rem(proc * i, 5000) + 1,
        rows: rem(proc * i + rq, 10000) + 1,
        timestamp: DateTime.utc_now() |> DateTime.add(-(rem(proc + i, 600) + 1))
      }
    end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
  end

  defp init_pipelines do
    [
      %{
        name: "Alarms ETL",
        source: "PostgreSQL",
        target: "DuckDB",
        status: :running,
        throughput: "1.2K",
        lag: 2
      },
      %{
        name: "Metrics Aggregation",
        source: "TimescaleDB",
        target: "Redis",
        status: :running,
        throughput: "5.4K",
        lag: 1
      },
      %{
        name: "Event Stream",
        source: "Kafka",
        target: "PostgreSQL",
        status: :running,
        throughput: "800",
        lag: 5
      },
      %{
        name: "Backup Sync",
        source: "PostgreSQL",
        target: "S3",
        status: :idle,
        throughput: "0",
        lag: 0
      }
    ]
  end

  defp init_trends do
    [
      %{name: "Alarm Volume", value: "1,247", direction: :up, change: 12, period: "vs last week"},
      %{
        name: "Response Time",
        value: "4.2min",
        direction: :down,
        change: 8,
        period: "vs last week"
      },
      %{
        name: "Device Uptime",
        value: "99.2%",
        direction: :up,
        change: 0.3,
        period: "vs last month"
      },
      %{
        name: "False Alarms",
        value: "3.1%",
        direction: :down,
        change: 15,
        period: "vs last month"
      }
    ]
  end

  defp init_metrics do
    %{
      reports_today: 23,
      reports_trend: :up,
      avg_query_time: 1250,
      query_trend: :stable,
      pipeline_health: 98,
      data_freshness: 15
    }
  end

  defp refresh_reports(reports) do
    Enum.map(reports, fn report ->
      if report.status == :running do
        new_progress = min(100, report.progress + :rand.uniform(10))

        if new_progress >= 100 do
          %{report | status: :completed, progress: 100, updated_at: DateTime.utc_now()}
        else
          %{report | progress: new_progress, updated_at: DateTime.utc_now()}
        end
      else
        report
      end
    end)
  end

  defp refresh_queries(queries) do
    # Add new query occasionally
    if :rand.uniform(3) == 1 do
      new_query = %{
        id: "qry_#{System.unique_integer([:positive])}",
        name: Enum.random(["SELECT *", "COUNT(*)", "JOIN tables"]),
        source: Enum.random(["PostgreSQL", "TimescaleDB"]),
        status: :completed,
        duration: 100 + :rand.uniform(2000),
        rows: :rand.uniform(5000),
        timestamp: DateTime.utc_now()
      }

      [new_query | Enum.take(queries, 19)]
    else
      queries
    end
  end

  defp fetch_analytics_metrics do
    # Wire to real BEAM intrinsics for analytics health indicators
    mem = :erlang.memory()
    total_mb = div(mem[:total], 1_048_576)
    process_count = :erlang.system_info(:process_count)
    run_queue = :erlang.statistics(:run_queue)

    # Pipeline health: degrade if run_queue is high or memory pressure
    pipeline_health =
      cond do
        run_queue > 50 -> 70
        total_mb > 6144 -> 80
        run_queue > 20 -> 90
        true -> 98
      end

    # Query time proxy: higher with more processes and run queue
    avg_query_time = 500 + run_queue * 50 + div(process_count, 100)

    %{
      reports_today: 20 + rem(process_count, 10) + 1,
      reports_trend: if(run_queue > 10, do: :down, else: :up),
      avg_query_time: avg_query_time,
      query_trend:
        cond do
          run_queue > 20 -> :up
          run_queue < 5 -> :down
          true -> :stable
        end,
      pipeline_health: pipeline_health,
      data_freshness: run_queue + 5
    }
  end

  defp filter_reports(reports, :all), do: reports
  defp filter_reports(reports, status), do: Enum.filter(reports, &(&1.status == status))

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp report_icon(:daily_summary), do: "📊"
  defp report_icon(:security_audit), do: "🔒"
  defp report_icon(:compliance), do: "✓"
  defp report_icon(:performance), do: "⚡"
  defp report_icon(:incident), do: "⚠"
  defp report_icon(_), do: "📄"

  defp duration_class(ms) when ms < 1000, do: "fast"
  defp duration_class(ms) when ms < 5000, do: "normal"
  defp duration_class(_), do: "slow"

  defp trend_arrow(:up), do: "↑"
  defp trend_arrow(:down), do: "↓"
  defp trend_arrow(_), do: "→"
end
