defmodule IndrajaalWeb.Crm.DashboardLive do
  @moduledoc """
  Real-time CRM Dashboard LiveView.

  ## WHAT
  Provides real-time, interactive CRM dashboard with auto-refreshing widgets,
  pipeline visualization, forecast tracking, activity streams, and performance
  metrics with WebSocket-based updates via Phoenix LiveView.

  ## WHY
  Enables sales teams to monitor performance in real-time with live updates,
  interactive drill-downs, and responsive UI for mobile and desktop access.

  ## CONSTRAINTS
  - SC-PRF-050: Response time < 50ms
  - SC-BRIDGE-002: Latency budget 50ms per batch
  - SC-OBS-069: Dual logging (Terminal + Zenoh)
  - SC-BUS-001: Async messaging only

  ## Features
  - Auto-refresh every 30s via PubSub
  - Chart.js for pipeline/forecast visualization
  - Drill-down capabilities for opportunities
  - Real-time activity stream
  - Performance leaderboard
  - Responsive mobile layout

  ## Zenoh Integration
  Subscribes to:
  - `indrajaal/crm/metrics` - Real-time metrics updates
  - `indrajaal/crm/pipeline` - Pipeline changes
  - `indrajaal/crm/forecast` - Forecast updates

  ## FMEA Analysis
  | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
  |--------------|----------|------------|-----------|-----|------------|
  | WebSocket disconnect | 6 | 4 | 8 | 192 | Auto-reconnect |
  | Render timeout | 7 | 3 | 6 | 126 | Lazy loading |
  | Data staleness | 5 | 5 | 5 | 125 | 30s refresh |

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial CRM dashboard LiveView implementation |
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.Crm.Analytics.Dashboard
  alias Phoenix.PubSub

  require Logger

  # 30 seconds
  @refresh_interval 30_000

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    # Subscribe to real-time updates
    if connected?(socket) do
      PubSub.subscribe(Indrajaal.PubSub, "crm:dashboard:#{user_id}")
      PubSub.subscribe(Indrajaal.PubSub, "crm:pipeline:#{user_id}")
      PubSub.subscribe(Indrajaal.PubSub, "crm:forecast:#{user_id}")

      # Schedule periodic refresh
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Periodic refresh
    Process.send_after(self(), :refresh, @refresh_interval)

    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:crm_update, _data}, socket) do
    # Real-time update from PubSub
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    # Manual refresh triggered by user
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("drill_down", %{"opportunity_id" => opp_id}, socket) do
    # Navigate to opportunity detail
    socket = push_navigate(socket, to: "/crm/opportunities/#{opp_id}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="crm-dashboard">
      <div class="dashboard-header">
        <h1>Sales Dashboard</h1>
        <button phx-click="refresh" class="btn-refresh">
          <.icon name="hero-arrow-path" class="h-5 w-5" /> Refresh
        </button>
      </div>

      <%= if @loading do %>
        <div class="loading-spinner">
          <.icon name="hero-arrow-path" class="h-8 w-8 animate-spin" /> Loading dashboard...
        </div>
      <% else %>
        <%= if @error do %>
          <div class="alert alert-error">
            <p>Error loading dashboard: {@error}</p>
          </div>
        <% else %>
          <!-- Pipeline Widget -->
          <div class="dashboard-widget">
            <h2>Pipeline Summary</h2>
            <div class="pipeline-metrics">
              <div class="metric-card">
                <span class="metric-label">Total Pipeline</span>
                <span class="metric-value">
                  {format_currency(@dashboard.pipeline.total_pipeline)}
                </span>
              </div>
              <div class="metric-card">
                <span class="metric-label">Weighted Pipeline</span>
                <span class="metric-value">
                  {format_currency(@dashboard.pipeline.weighted_pipeline)}
                </span>
              </div>
              <div class="metric-card">
                <span class="metric-label">Opportunities</span>
                <span class="metric-value">{@dashboard.pipeline.opportunity_count}</span>
              </div>
              <div class="metric-card">
                <span class="metric-label">Avg Deal Size</span>
                <span class="metric-value">
                  {format_currency(@dashboard.pipeline.average_deal_size)}
                </span>
              </div>
            </div>
            
    <!-- Pipeline by Stage Chart -->
            <div
              id="pipeline-chart"
              phx-hook="PipelineChart"
              data-stages={Jason.encode!(@dashboard.pipeline.by_stage)}
            >
              <canvas id="pipeline-canvas"></canvas>
            </div>
          </div>
          
    <!-- Forecast Widget -->
          <div class="dashboard-widget">
            <h2>Forecast Tracker</h2>
            <div class="forecast-metrics">
              <div class="metric-card">
                <span class="metric-label">Quota</span>
                <span class="metric-value">{format_currency(@dashboard.forecast.quota)}</span>
              </div>
              <div class="metric-card">
                <span class="metric-label">Commit</span>
                <span class="metric-value">{format_currency(@dashboard.forecast.commit)}</span>
              </div>
              <div class="metric-card">
                <span class="metric-label">Closed</span>
                <span class="metric-value">{format_currency(@dashboard.forecast.closed)}</span>
              </div>
              <div class="metric-card">
                <span class="metric-label">Attainment</span>
                <span class={"metric-value #{attainment_class(@dashboard.forecast.attainment_percent)}"}>
                  {format_percent(@dashboard.forecast.attainment_percent)}
                </span>
              </div>
            </div>
            
    <!-- Forecast Progress Bar -->
            <div class="progress-bar">
              <div class="progress-fill" style={"width: #{@dashboard.forecast.attainment_percent}%"}>
              </div>
            </div>
          </div>
          
    <!-- Top Deals Widget -->
          <div class="dashboard-widget">
            <h2>Top Deals</h2>
            <div class="deals-list">
              <%= for deal <- @dashboard.top_deals do %>
                <div class="deal-card" phx-click="drill_down" phx-value-opportunity_id={deal.id}>
                  <div class="deal-name">{deal.name}</div>
                  <div class="deal-amount">{format_currency(deal.amount)}</div>
                  <div class="deal-stage">{deal.stage}</div>
                  <div class="deal-probability">{deal.probability}%</div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Activity Stream Widget -->
          <div class="dashboard-widget">
            <h2>Recent Activities</h2>
            <div class="activity-stream">
              <%= for activity <- @dashboard.activities do %>
                <div class="activity-item">
                  <div class="activity-icon">
                    <.icon name={activity_icon(activity.type)} class="h-5 w-5" />
                  </div>
                  <div class="activity-content">
                    <div class="activity-description">{activity.description}</div>
                    <div class="activity-time">{relative_time(activity.created_at)}</div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Leaderboard Widget -->
          <div class="dashboard-widget">
            <h2>Leaderboard</h2>
            <div class="leaderboard">
              <%= for {rep, index} <- Enum.with_index(@dashboard.leaderboard, 1) do %>
                <div class="leaderboard-row">
                  <div class="rank">{index}</div>
                  <div class="rep-name">{rep.name}</div>
                  <div class="attainment">{format_percent(rep.attainment)}</div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Overdue Tasks Widget -->
          <%= if length(@dashboard.overdue_tasks) > 0 do %>
            <div class="dashboard-widget alert">
              <h2>Overdue Tasks ({length(@dashboard.overdue_tasks)})</h2>
              <div class="tasks-list">
                <%= for task <- @dashboard.overdue_tasks do %>
                  <div class="task-item">
                    <div class="task-subject">{task.subject}</div>
                    <div class="task-due-date text-red-600">
                      Due: {format_date(task.due_date)}
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
      <% end %>
      
    <!-- Last Updated Timestamp -->
      <div class="dashboard-footer">
        <span class="text-sm text-gray-500">
          Last updated: {format_timestamp(@dashboard.generated_at)}
        </span>
      </div>
    </div>
    """
  end

  # Private Helpers

  defp load_dashboard_data(socket) do
    user_id = socket.assigns.user_id

    case Dashboard.sales_dashboard(user_id) do
      {:ok, dashboard} ->
        socket
        |> assign(:dashboard, dashboard)
        |> assign(:loading, false)
        |> assign(:error, nil)

      {:error, error} ->
        Logger.error("Dashboard load failed: #{inspect(error)}")

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load dashboard data")
    end
  end

  defp number_to_currency(number) do
    # Simple formatting helper to replace Number.Currency dependency
    if is_number(number) do
      "$" <> :erlang.float_to_binary(number / 1, decimals: 2)
    else
      "$0.00"
    end
  end

  defp format_currency(nil), do: "$0.00"

  defp format_currency(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_float()
    |> format_currency()
  end

  defp format_currency(amount) when is_number(amount) do
    number_to_currency(amount)
  end

  defp format_percent(nil), do: "0%"

  defp format_percent(percent) when is_number(percent) do
    "#{Float.round(percent, 1)}%"
  end

  defp format_date(nil), do: ""

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  defp format_timestamp(nil), do: ""

  defp format_timestamp(dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp relative_time(dt) do
    # Simple relative time formatting
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp attainment_class(percent) when percent >= 100, do: "text-green-600 font-bold"
  defp attainment_class(percent) when percent >= 75, do: "text-yellow-600"
  defp attainment_class(_), do: "text-red-600"

  defp activity_icon(:call), do: "hero-phone"
  defp activity_icon(:email), do: "hero-envelope"
  defp activity_icon(:meeting), do: "hero-calendar"
  defp activity_icon(:task), do: "hero-check-circle"
  defp activity_icon(_), do: "hero-document-text"
end
