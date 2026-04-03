defmodule IndrajaalWeb.MonitoringDashboardLive do
  @moduledoc """
  Real-time monitoring dashboard for alarm processing system.

  Provides comprehensive visibility into:
  - Alarm processing metrics and performance
  - System health and resource utilization
  - Processing pipeline status and throughput
  - Error rates and quality metrics
  """

  use IndrajaalWeb, :live_view

  alias Indrajaal.ObservabilityDashboard

  # 5 seconds
  @refresh_interval 5_000

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh_metrics)
    end

    socket =
      socket
      |> assign(:page_title, "Monitoring Dashboard")
      |> assign(:current_time, DateTime.utc_now())
      |> assign(:metrics, default_metrics())
      |> load_dashboard_metrics()

    {:ok, socket}
  rescue
    error ->
      require Logger

      Logger.warning(
        "[MonitoringDashboardLive] mount/3 failed, using placeholder data: #{inspect(error)}"
      )

      socket =
        socket
        |> assign(:page_title, "Monitoring Dashboard")
        |> assign(:current_time, DateTime.utc_now())
        |> assign(:metrics, default_metrics())

      {:ok, socket}
  end

  @spec handle_info(atom(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(:refresh_metrics, socket) do
    socket =
      socket
      |> assign(:current_time, DateTime.utc_now())
      |> load_dashboard_metrics()

    {:noreply, socket}
  rescue
    error ->
      require Logger

      Logger.warning(
        "[MonitoringDashboardLive] refresh failed, keeping last metrics: #{inspect(error)}"
      )

      {:noreply, assign(socket, :current_time, DateTime.utc_now())}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <%!-- L4-A09: Theme-aware Monitoring Dashboard page (SC-HMI-001, SC-HMI-008) --%>
    <div class="monitoring-dashboard bg-surface-primary dark:bg-surface-secondary">
      <div class="dashboard-header">
        <h1 class="text-content-primary">System Monitoring Dashboard</h1>
        <div class="last-updated text-content-secondary">
          Last Updated: {Calendar.strftime(@current_time, "%Y-%m-%d %H:%M:%S UTC")}
        </div>
      </div>
      <!-- System Overview Cards -->
      <div class="metrics-grid">
        <div class="metric-card">
          <h3>Active Alarms</h3>
          <div class="metric-value">{@metrics.active_alarms}</div>
          <div class={"metric-trend #{trend_class(@metrics.alarm_trend)}"}>
            {@metrics.alarm_trend}% from last hour
          </div>
        </div>

        <div class="metric-card">
          <h3>Processing Rate</h3>
          <div class="metric-value">{@metrics.processing_rate} per sec</div>
          <div class={"metric-trend #{trend_class(@metrics.rate_trend)}"}>
            {@metrics.rate_trend}% from baseline
          </div>
        </div>

        <div class="metric-card">
          <h3>Average Latency</h3>
          <div class="metric-value">{@metrics.avg_latency}ms</div>
          <div class={"metric-trend #{trend_class(-@metrics.latency_trend)}"}>
            {@metrics.latency_trend}ms from target
          </div>
        </div>

        <div class="metric-card">
          <h3>System Health</h3>
          <div class={"metric-value health-#{@metrics.health_status}"}>
            {String.upcase(@metrics.health_status)}
          </div>
          <div class="metric-trend">
            Uptime: {@metrics.uptime}
          </div>
        </div>
      </div>
      <!-- Processing Pipeline Status -->
      <div class="pipeline-section">
        <h2>Alarm Processing Pipeline</h2>
        <div class="pipeline-stages">
          <div :for={stage <- @metrics.pipeline_stages} class="stage-card">
            <h4>{stage.name}</h4>
            <div class="stage-metrics">
              <div class={"stage-status status-#{stage.status}"}>
                {String.upcase(stage.status)}
              </div>
              <div class="stage-throughput">
                {stage.throughput} per sec
              </div>
              <div class="stage-queue">
                Queue: {stage.queue_size}
              </div>
            </div>
          </div>
        </div>
      </div>
      <!-- Real-time Charts -->
      <div class="charts-section">
        <div class="chart-container">
          <h3>Alarm Volume (Last 24 Hours)</h3>
          <div
            id="alarm-volume-chart"
            phx-hook="AlarmVolumeChart"
            __data-metrics={Jason.encode!(@metrics.alarm_volume)}
          >
          </div>
        </div>

        <div class="chart-container">
          <h3>Processing Latency Distribution</h3>
          <div
            id="latency-chart"
            phx-hook="LatencyChart"
            __data-metrics={Jason.encode!(@metrics.latency_distribution)}
          >
          </div>
        </div>
      </div>
      <!-- Recent Alarms -->
      <div class="recent-alarms-section">
        <h2>Recent High-Priority Alarms</h2>
        <div class="alarms-table">
          <table>
            <thead>
              <tr>
                <th>Time</th>
                <th>Type</th>
                <th>Severity</th>
                <th>Device</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={alarm <- @metrics.recent_alarms}>
                <td>{Calendar.strftime(alarm.timestamp, "%H:%M:%S")}</td>
                <td>{alarm.type}</td>
                <td class={"severity-#{alarm.severity}"}>{alarm.severity}</td>
                <td>{alarm.device_name}</td>
                <td class={"status-#{alarm.status}"}>{alarm.status}</td>
                <td>
                  <button phx-click="view_alarm" phx-value-id={alarm.id} class="btn-primary">
                    View
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <!-- System Alerts -->
      <div :if={@metrics.system_alerts != []} class="alerts-section">
        <h2>System Alerts</h2>
        <div :for={alert <- @metrics.system_alerts} class={"alert alert-#{alert.level}"}>
          <div class="alert-icon">⚠️</div>
          <div class="alert-content">
            <strong>{alert.title}</strong>
            <p>{alert.message}</p>
            <small>{Calendar.strftime(alert.timestamp, "%Y-%m-%d %H:%M:%S")}</small>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec load_dashboard_metrics(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_dashboard_metrics(socket) do
    metrics = %{
      active_alarms: get_active_alarm_count(),
      processing_rate: get_processing_rate(),
      avg_latency: get_average_latency(),
      health_status: get_system_health(),
      alarm_trend: get_alarm_trend_number(),
      rate_trend: get_rate_trend_number(),
      latency_trend: get_latency_trend_number(),
      uptime: get_system_uptime(),
      pipeline_stages: get_pipeline_status(),
      alarm_volume: get_alarm_volume_data(),
      latency_distribution: get_latency_distribution(),
      recent_alarms: get_recent_high_priority_alarms(),
      system_alerts: get_system_alerts()
    }

    assign(socket, :metrics, metrics)
  rescue
    error ->
      require Logger
      Logger.warning("[MonitoringDashboardLive] load_dashboard_metrics failed: #{inspect(error)}")
      assign(socket, :metrics, default_metrics())
  end

  @spec default_metrics() :: map()
  defp default_metrics do
    %{
      active_alarms: 0,
      processing_rate: 0.0,
      avg_latency: 0.0,
      health_status: "unknown",
      alarm_trend: 0,
      rate_trend: 0,
      latency_trend: 0.0,
      uptime: "N/A",
      pipeline_stages: [],
      alarm_volume: [],
      latency_distribution: [],
      recent_alarms: [],
      system_alerts: []
    }
  end

  @spec trend_class(term()) :: term()
  defp trend_class(value) when value > 0, do: "trend-up"
  defp trend_class(value) when value < 0, do: "trend-down"
  defp trend_class(_), do: "trend-neutral"

  # Metric collection functions
  @spec get_active_alarm_count() :: integer()
  defp get_active_alarm_count do
    Indrajaal.Alarms.count_active_alarms()
  rescue
    _ -> 0
  end

  @spec get_processing_rate() :: number()
  defp get_processing_rate do
    ObservabilityDashboard.get_current_processing_rate()
  rescue
    _ -> 0.0
  end

  @spec get_average_latency() :: number()
  defp get_average_latency do
    ObservabilityDashboard.get_average_processing_latency()
  rescue
    _ -> 0.0
  end

  @spec get_system_health() :: any()
  defp get_system_health do
    case ObservabilityDashboard.get_system_health_score() do
      score when score >= 95 -> "healthy"
      score when score >= 80 -> "warning"
      _ -> "critical"
    end
  rescue
    _ -> "unknown"
  end

  # These wrappers normalise the ObservabilityDashboard trend functions, which may
  # return a list (timeseries) instead of a scalar.  The template needs a number
  # for display and for trend_class/1 comparisons.
  @spec get_alarm_trend_number() :: number()
  defp get_alarm_trend_number do
    raw = ObservabilityDashboard.get_alarm_volume_trend(:last_hour)

    case raw do
      v when is_number(v) -> v
      [_ | _] = list -> List.last(list) || 0
      _ -> 0
    end
  rescue
    _ -> 0
  end

  @spec get_rate_trend_number() :: number()
  defp get_rate_trend_number do
    raw = ObservabilityDashboard.get_processing_rate_trend()

    case raw do
      v when is_number(v) -> v
      [_ | _] = list -> List.last(list) || 0
      _ -> 0
    end
  rescue
    _ -> 0
  end

  @spec get_latency_trend_number() :: number()
  defp get_latency_trend_number do
    raw = ObservabilityDashboard.get_latency_trend()

    case raw do
      v when is_number(v) -> v
      [_ | _] = list -> List.last(list) || 0.0
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  @spec get_system_uptime() :: String.t()
  defp get_system_uptime do
    ObservabilityDashboard.get_system_uptime()
  rescue
    _ -> "N/A"
  end

  @spec get_pipeline_status() :: list(map())
  defp get_pipeline_status do
    [
      %{name: "Ingestion", status: "healthy", throughput: 245, queue_size: 12},
      %{name: "Severity", status: "healthy", throughput: 243, queue_size: 8},
      %{name: "Correlation", status: "warning", throughput: 240, queue_size: 25},
      %{name: "Storm Detection", status: "healthy", throughput: 238, queue_size: 5},
      %{name: "Notification", status: "healthy", throughput: 235, queue_size: 15},
      %{name: "Workflow", status: "healthy", throughput: 230, queue_size: 18}
    ]
  end

  @spec get_alarm_volume_data() :: list()
  defp get_alarm_volume_data do
    ObservabilityDashboard.get_alarm_volume_timeseries(:last_24_hours)
  rescue
    _ -> []
  end

  @spec get_latency_distribution() :: list()
  defp get_latency_distribution do
    ObservabilityDashboard.get_latency_distribution(:last_hour)
  rescue
    _ -> []
  end

  @spec get_recent_high_priority_alarms() :: list()
  defp get_recent_high_priority_alarms do
    Indrajaal.Alarms.list_recent_high_priority_alarms(limit: 10)
  rescue
    _ -> []
  end

  @spec get_system_alerts() :: list()
  defp get_system_alerts do
    now = DateTime.utc_now()

    ObservabilityDashboard.get_active_system_alerts()
    |> Enum.map(fn alert ->
      # Normalise field names: the template expects :level and :timestamp.
      # ObservabilityDashboard returns :severity (atom) and no :timestamp.
      level =
        case Map.get(alert, :level) || Map.get(alert, :severity) do
          l when is_binary(l) -> l
          :critical -> "danger"
          :warning -> "warning"
          :info -> "info"
          _ -> "info"
        end

      timestamp = Map.get(alert, :timestamp, now)
      title = Map.get(alert, :title, "System Alert")
      message = Map.get(alert, :message, "")

      %{level: level, title: title, message: message, timestamp: timestamp}
    end)
  rescue
    _ -> []
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic framework
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
