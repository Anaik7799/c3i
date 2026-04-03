defmodule Indrajaal.Observability.Dashboards do
  @moduledoc """
  SigNoz dashboard configuration and management.

  This module provides programmatic dashboard creation and configuration for
  SigNoz, ensuring consistent monitoring views across all Indrajaal domains.
  It defines dashboard templates, panel configurations, and automated dashboard
  provisioning for comprehensive system observability.

  ## Dashboard Categories

  - **System Overview**: High-level health and performance metrics
  - **Domain Dashboards**: Specific views for each Ash domain
    - Alarms Dashboard: Event processing, response times, escalations
    - Access Control: Authentication metrics, access patterns
    - Video Analytics: Stream health, processing metrics
    - Maintenance: Work order SLAs, pr_eventive maintenance compliance
  - **Infrastructure**: Container health, __database performance, network metrics
  - **Business Intelligence**: ROI metrics, tenant usage, feature adoption

  ## Features

  - Automated dashboard provisioning via SigNoz API
  - Consistent panel layouts and queries
  - Alert rule integration
  - Variable support for multi-tenant filtering
  - Mobile-optimized dashboard variants

  ## Usage

      # Create all default dashboards
      Dashboards.provision_all()

      # Create a specific domain dashboard
      Dashboards.create_domain_dashboard(:alarms)

      # Update dashboard with new panels
      Dashboards.update_dashboard("system-overview", new_panels)
  """

  require Logger

  @dashboard_types [:system_overview, :alarms, :security, :performance, :business_kpis]

  @doc """
  Creates all predefined dashboards in SigNoz.
  Returns {:ok, %{dashboard_name: dashboard_id}} or {:error, errors}
  """
  @spec create_dashboards(any()) :: {:ok, map()} | {:error, list()}
  def create_dashboards(apiclient \\ nil) do
    client = apiclient || create_default_api_client()

    results =
      @dashboard_types
      |> Enum.map(fn type ->
        case load_dashboard_config(type) do
          # Unreachable clause commented out - load_dashboard_config/1 (line 160) always returns map for @dashboard_types, never {:error, ...}
          # {:error, _} = error ->
          #   {type, error}

          config ->
            case create_dashboard(config, client) do
              {:ok, id} ->
                Logger.info("Created #{type} dashboard: #{id}")
                {type, {:ok, id}}

              {:error, reason} = error ->
                Logger.error("Failed to create #{type} dashboard: #{inspect(reason)}")
                {type, error}
            end
        end
      end)

    errors =
      results
      |> Enum.filter(fn {_type, result} -> match?({:error, _}, result) end)
      |> Enum.map(fn {type, {:error, reason}} -> {type, reason} end)

    if Enum.empty?(errors) do
      dashboards =
        results
        |> Enum.map(fn {type, {:ok, id}} -> {type, id} end)
        |> Map.new()

      {:ok, dashboards}
    else
      {:error, errors}
    end
  end

  # Alias for backward compatibility
  @spec provision_all(any()) :: {:ok, map()} | {:error, list()}
  def provision_all(api_client \\ nil), do: create_dashboards(api_client)

  @doc """
  Creates a single dashboard in SigNoz.
  """
  @spec create_dashboard(map(), any()) :: {:ok, String.t()} | {:error, any()}
  def create_dashboard(config, apiclient) do
    case validate_dashboard_config(config) do
      :ok ->
        body = convert_to_signoz_format(config)

        case apiclient.(:post, "/api/v3/dashboards", body, []) do
          {:ok, %{status: status, body: response_body}} when status in 200..299 ->
            dashboard_id = get_in(response_body, ["__data", "id"])
            {:ok, dashboard_id}

          {:ok, %{status: status, body: body}} ->
            {:error, "Failed with status #{status}: #{inspect(body)}"}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Creates a specific domain dashboard.
  """
  @spec create_domain_dashboard(atom(), any()) :: {:ok, String.t()} | {:error, any()}
  def create_domain_dashboard(type, api_client \\ nil) when type in @dashboard_types do
    client = api_client || create_default_api_client()
    config = load_dashboard_config(type)
    create_dashboard(config, client)
  end

  @doc """
  Updates an existing dashboard.
  """
  def updatedashboard(dashboardid, newpanels, apiclient \\ nil) do
    client = apiclient || create_default_api_client()

    case getdashboard(dashboardid, client) do
      {:ok, existing} ->
        updated = Map.put(existing, "panels", newpanels)

        case client.(:put, "/api/v3/dashboards/#{dashboardid}", updated, []) do
          {:ok, %{status: status}} when status in 200..299 ->
            {:ok, dashboardid}

          {:ok, %{status: status, body: body}} ->
            {:error, "Failed with status #{status}: #{inspect(body)}"}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  Loads dashboard configuration for a given type.
  """
  @spec load_dashboard_config(atom()) :: map() | {:error, :unknown_dashboard}
  def load_dashboard_config(type) when type in @dashboard_types do
    case type do
      :system_overview -> system_overview_dashboard()
      :alarms -> alarms_dashboard()
      :security -> security_dashboard()
      :performance -> performance_dashboard()
      :business_kpis -> business_kpis_dashboard()
    end
  end

  @spec load_dashboard_config(any()) :: {:error, :unknown_dashboard}
  # def load_dashboard_config(_), do: {:error, :unknown_dashboard}
  # Claude Agent: EP-076 - Unreachable function clause commented
  @doc """
  Validates a dashboard configuration.
  """
  @spec validate_dashboard_config(map()) :: :ok | {:error, list()}
  def validate_dashboard_config(config) do
    errors = []
    errors = if Map.has_key?(config, :title), do: errors, else: [:title | errors]
    errors = if Map.has_key?(config, :description), do: errors, else: [:description | errors]
    errors = if Map.has_key?(config, :widgets), do: errors, else: [:widgets | errors]

    # Validate widgets
    widget_errors =
      if Map.has_key?(config, :widgets) do
        config.widgets
        |> Enum.with_index()
        |> Enum.flat_map(fn {widget, index} ->
          case validate_widget(widget) do
            :ok -> []
            {:error, reasons} -> [{:widget, index, reasons}]
          end
        end)
      else
        []
      end

    all_errors = errors ++ widget_errors

    if Enum.empty?(all_errors) do
      :ok
    else
      {:error, all_errors}
    end
  end

  @doc """
  Creates an API client for SigNoz.
  """
  @spec create_api_client(String.t(), String.t()) :: function()
  def create_api_client(baseurl, api_key) do
    fn method, path, body, headers ->
      url = "#{baseurl}#{path}"

      auth_headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
        | headers
      ]

      body_json = if body, do: Jason.encode!(body), else: ""
      final_headers = auth_headers

      case method do
        :post ->
          headers_args =
            Enum.flat_map(final_headers, fn {key, value} -> ["-H", "#{key}: #{value}"] end)

          case System.cmd(
                 "curl",
                 [
                   "-X",
                   "POST"
                 ] ++
                   headers_args ++
                   [
                     "-d",
                     body_json,
                     url
                   ]
               ) do
            {response_body, 0} ->
              {:ok, %{status: 200, body: Jason.decode!(response_body)}}

            {_, exit_code} ->
              {:error, "curl command failed with exit code #{exit_code}"}
          end

        :get ->
          headers_args =
            Enum.flat_map(final_headers, fn {key, value} -> ["-H", "#{key}: #{value}"] end)

          case System.cmd("curl", headers_args ++ [url]) do
            {response_body, 0} ->
              {:ok, %{status: 200, body: Jason.decode!(response_body)}}

            {_, exit_code} ->
              {:error, "curl command failed with exit code #{exit_code}"}
          end

        :put ->
          headers_args =
            Enum.flat_map(final_headers, fn {key, value} -> ["-H", "#{key}: #{value}"] end)

          case System.cmd(
                 "curl",
                 [
                   "-X",
                   "PUT"
                 ] ++
                   headers_args ++
                   [
                     "-d",
                     body_json,
                     url
                   ]
               ) do
            {response_body, 0} ->
              {:ok, %{status: 200, body: Jason.decode!(response_body)}}

            {_, exit_code} ->
              {:error, "curl command failed with exit code #{exit_code}"}
          end
      end
    end
  end

  @doc """
  Gets a dashboard by ID.
  """
  def getdashboard(dashboardid, apiclient) do
    case apiclient.(:get, "/api/v3/dashboards/#{dashboardid}", nil, []) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body["__data"]}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets dashboard URLs for created dashboards.
  """
  @spec get_dashboard_urls(map(), String.t()) :: map()
  def get_dashboard_urls(dashboards, baseurl) do
    dashboards
    |> Enum.map(fn {name, id} ->
      {name, "#{baseurl}/dashboard/#{id}"}
    end)
    |> Map.new()
  end

  @doc """
  Creates a trace widget configuration.
  """
  @spec create_trace_widget(String.t(), String.t(), map(), map()) :: map()
  def create_trace_widget(title, query, position, options \\ %{}) do
    %{
      type: "trace",
      title: title,
      query: query,
      position: position,
      options:
        Map.merge(
          %{
            time_range: "15m",
            refresh_interval: "30s"
          },
          options
        )
    }
  end

  @doc """
  Creates a log widget configuration.
  """
  @spec create_log_widget(String.t(), String.t(), map(), map()) :: map()
  def create_log_widget(title, query, position, options \\ %{}) do
    %{
      type: "log",
      title: title,
      query: query,
      position: position,
      options:
        Map.merge(
          %{
            time_range: "15m",
            refresh_interval: "30s",
            columns: ["timestamp", "level", "message"]
          },
          options
        )
    }
  end

  @doc """
  Creates a metric widget configuration.
  """
  @spec create_metric_widget(String.t(), String.t(), map(), map()) :: map()
  def create_metric_widget(title, query, position, options \\ %{}) do
    %{
      type: "metric",
      title: title,
      query: query,
      position: position,
      options:
        Map.merge(
          %{
            aggregation: "avg",
            interval: "1m",
            visualization: "line"
          },
          options
        )
    }
  end

  # Private functions

  defp create_default_api_client do
    base_url = System.get_env("SIGNOZ_API_URL", "http://localhost:8080")
    api_key = System.get_env("SIGNOZ_API_KEY", "")

    create_api_client(base_url, api_key)
  end

  defp validate_widget(widget) do
    errors = []
    errors = if Map.has_key?(widget, :type), do: errors, else: [:type | errors]
    errors = if Map.has_key?(widget, :title), do: errors, else: [:title | errors]
    errors = if Map.has_key?(widget, :query), do: errors, else: [:query | errors]
    errors = if Map.has_key?(widget, :position), do: errors, else: [:position | errors]

    # Validate type
    valid_types = ["trace", "log", "metric"]

    errors =
      if Map.get(widget, :type) in valid_types do
        errors
      else
        [:invalid_type | errors]
      end

    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end
  end

  defp convert_to_signoz_format(config) do
    %{
      "title" => config.title,
      "description" => config.description,
      "panels" => Enum.map(config.widgets, &convert_widget_to_panel/1),
      "layout" => "grid",
      "variables" => []
    }
  end

  defp convert_widget_to_panel(widget) do
    %{
      "title" => widget.title,
      "type" => widget.type,
      "query" => widget.query,
      "gridPos" => widget.position,
      "options" => widget[:options] || %{}
    }
  end

  # Dashboard configurations

  defp system_overview_dashboard do
    %{
      title: "System Overview Dashboard",
      description:
        "Provides a comprehensive view of all system components and their health status",
      widgets: [
        # Request rate across all services
        create_metric_widget(
          "Request Rate (All Services)",
          "sum(rate(http_requests_total[5m])) by (service)",
          %{x: 0, y: 0, w: 6, h: 4},
          %{visualization: "line", aggregation: "sum"}
        ),

        # Error rate
        create_metric_widget(
          "Error Rate",
          "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (service)",
          %{x: 6, y: 0, w: 6, h: 4},
          %{visualization: "line", aggregation: "sum"}
        ),

        # P95 latency
        create_metric_widget(
          "P95 Latency",
          "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (service, le))",
          %{x: 0, y: 4, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Active __users
        create_metric_widget(
          "Active Users",
          "count(count by (user_id) (__user_activity_total))",
          %{x: 6, y: 4, w: 6, h: 4},
          %{visualization: "stat"}
        ),

        # Recent errors
        create_log_widget(
          "Recent Errors",
          "level=error",
          %{x: 0, y: 8, w: 12, h: 4},
          %{columns: ["timestamp", "service", "message"]}
        ),

        # Service traces
        create_trace_widget(
          "Service Traces",
          "duration > 100ms",
          %{x: 0, y: 12, w: 12, h: 4}
        )
      ]
    }
  end

  defp alarms_dashboard do
    %{
      title: "Alarms Dashboard",
      description: "Real-time alarm monitoring and analytics for security incidents",
      widgets: [
        # Active alarms count
        create_metric_widget(
          "Active Alarms",
          "sum(alarm_active_total)",
          %{x: 0, y: 0, w: 3, h: 3},
          %{visualization: "stat"}
        ),

        # Alarm rate
        create_metric_widget(
          "Alarm Rate (per minute)",
          "sum(rate(alarm_created_total[1m]))",
          %{x: 3, y: 0, w: 3, h: 3},
          %{visualization: "stat"}
        ),

        # Average response time
        create_metric_widget(
          "Avg Response Time",
          "avg(alarm_response_time_seconds)",
          %{x: 6, y: 0, w: 3, h: 3},
          %{visualization: "stat"}
        ),

        # Escalated alarms
        create_metric_widget(
          "Escalated Alarms",
          "sum(alarm_escalated_total)",
          %{x: 9, y: 0, w: 3, h: 3},
          %{visualization: "stat"}
        ),

        # Alarms by severity
        create_metric_widget(
          "Alarms by Severity",
          "sum(alarm_active_total) by (severity)",
          %{x: 0, y: 3, w: 6, h: 4},
          %{visualization: "pie"}
        ),

        # Alarms by type
        create_metric_widget(
          "Alarms by Type",
          "sum(alarm_active_total) by (type)",
          %{x: 6, y: 3, w: 6, h: 4},
          %{visualization: "bar"}
        ),

        # Alarm timeline
        create_metric_widget(
          "Alarm Timeline",
          "sum(rate(alarm_created_total[5m])) by (severity)",
          %{x: 0, y: 7, w: 12, h: 4},
          %{visualization: "line", aggregation: "rate"}
        ),

        # Recent alarm logs
        create_log_widget(
          "Recent Alarm Events",
          "service=alarms",
          %{x: 0, y: 11, w: 12, h: 4},
          %{columns: ["timestamp", "severity", "type", "site", "message"]}
        ),

        # Alarm processing traces
        create_trace_widget(
          "Alarm Processing Traces",
          "service=alarms AND operation=process_alarm",
          %{x: 0, y: 15, w: 12, h: 4}
        )
      ]
    }
  end

  defp security_dashboard do
    %{
      title: "Security Dashboard",
      description: "Security monitoring for access control, authentication, and authorization",
      widgets: [
        # Failed login attempts
        create_metric_widget(
          "Failed Login Attempts",
          "sum(rate(auth_login_failed_total[5m]))",
          %{x: 0, y: 0, w: 6, h: 3},
          %{visualization: "stat"}
        ),

        # Active sessions
        create_metric_widget(
          "Active Sessions",
          "sum(auth_sessions_active)",
          %{x: 6, y: 0, w: 6, h: 3},
          %{visualization: "stat"}
        ),

        # Access denied __events
        create_metric_widget(
          "Access Denied Events",
          "sum(rate(access_denied_total[5m]))",
          %{x: 0, y: 3, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Authentication methods
        create_metric_widget(
          "Authentication Methods",
          "sum(auth_login_success_total) by (method)",
          %{x: 6, y: 3, w: 6, h: 4},
          %{visualization: "pie"}
        ),

        # Security __events by type
        create_metric_widget(
          "Security Events by Type",
          "sum(rate(security_event_total[5m])) by (__event_type)",
          %{x: 0, y: 7, w: 12, h: 4},
          %{visualization: "bar"}
        ),

        # Security logs
        create_log_widget(
          "Security Events",
          "level=warn AND (service=auth OR service=access_control)",
          %{x: 0, y: 11, w: 12, h: 4},
          %{columns: ["timestamp", "user", "__event_type", "ip_address", "message"]}
        ),

        # Authentication traces
        create_trace_widget(
          "Authentication Traces",
          "service=auth AND (operation=login OR operation=validate_token)",
          %{x: 0, y: 15, w: 12, h: 4}
        )
      ]
    }
  end

  defp performance_dashboard do
    %{
      title: "Performance Dashboard",
      description: "System performance metrics including latency, throughput, and resource usage",
      widgets: [
        # Request throughput
        create_metric_widget(
          "Request Throughput",
          "sum(rate(http_requests_total[1m]))",
          %{x: 0, y: 0, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Average latency
        create_metric_widget(
          "Average Latency",
          "avg(http_request_duration_seconds)",
          %{x: 6, y: 0, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Latency percentiles
        create_metric_widget(
          "Latency Percentiles",
          "histogram_quantile(0.5, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
          %{x: 0, y: 4, w: 12, h: 4},
          %{visualization: "line", aggregation: "percentile"}
        ),

        # CPU usage
        create_metric_widget(
          "CPU Usage",
          "avg(cpu_usage_percent) by (service)",
          %{x: 0, y: 8, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Memory usage
        create_metric_widget(
          "Memory Usage",
          "avg(memory_usage_bytes) by (service)",
          %{x: 6, y: 8, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Database query time
        create_metric_widget(
          "Database Query Time",
          "avg(db_query_duration_seconds) by (query_type)",
          %{x: 0, y: 12, w: 6, h: 4},
          %{visualization: "bar"}
        ),

        # Cache hit rate
        create_metric_widget(
          "Cache Hit Rate",
          "sum(rate(cache_hits_total[5m])) / sum(rate(cache_requests_total[5m]))",
          %{x: 6, y: 12, w: 6, h: 4},
          %{visualization: "gauge"}
        ),

        # Slow queries
        create_log_widget(
          "Slow Queries",
          "service=__database AND duration > 1000",
          %{x: 0, y: 16, w: 12, h: 4},
          %{columns: ["timestamp", "query", "duration", "rows"]}
        )
      ]
    }
  end

  defp business_kpis_dashboard do
    %{
      title: "Business KPIs Dashboard",
      description: "Executive view of key business metrics and operational indicators",
      widgets: [
        # Monthly active __users
        create_metric_widget(
          "Monthly Active Users",
          "count(count by (user_id) (__user_activity_total[30d]))",
          %{x: 0, y: 0, w: 3, h: 3},
          %{visualization: "stat"}
        ),

        # Total alarms handled
        create_metric_widget(
          "Total Alarms (30d)",
          "sum(increase(alarm_created_total[30d]))",
          %{x: 3, y: 0, w: 3, h: 3},
          %{visualization: "stat"}
        ),

        # System uptime
        create_metric_widget(
          "System Uptime %",
          "(1 - avg(rate(system_downtime_seconds[30d])) / (30 * 24 * 3600)) * 100",
          %{x: 6, y: 0, w: 3, h: 3},
          %{visualization: "gauge"}
        ),

        # Revenue impact
        create_metric_widget(
          "Est. Revenue Impact",
          "sum(alarm_revenue_impact_dollars)",
          %{x: 9, y: 0, w: 3, h: 3},
          %{visualization: "stat", format: "currency"}
        ),

        # User growth trend
        create_metric_widget(
          "User Growth Trend",
          "count(count by (user_id) (__user_created_timestamp)) by (month)",
          %{x: 0, y: 3, w: 6, h: 4},
          %{visualization: "line"}
        ),

        # Alarm resolution efficiency
        create_metric_widget(
          "Alarm Resolution Efficiency",
          "avg(alarm_resolution_time_seconds) by (severity)",
          %{x: 6, y: 3, w: 6, h: 4},
          %{visualization: "bar"}
        ),

        # Site activity heatmap
        create_metric_widget(
          "Site Activity Heatmap",
          "sum(site_activity_score) by (site_id, hour)",
          %{x: 0, y: 7, w: 12, h: 4},
          %{visualization: "heatmap"}
        ),

        # Customer satisfaction score
        create_metric_widget(
          "Customer Satisfaction Score",
          "avg(customer_satisfaction_score)",
          %{x: 0, y: 11, w: 6, h: 3},
          %{visualization: "gauge", min: 0, max: 100}
        ),

        # Operational efficiency
        create_metric_widget(
          "Operational Efficiency Index",
          "(sum(alarm_resolved_total) / sum(alarm_created_total)) * 100",
          %{x: 6, y: 11, w: 6, h: 3},
          %{visualization: "gauge", min: 0, max: 100}
        ),

        # Executive summary logs
        create_log_widget(
          "Key Business Events",
          "level=info AND category=business",
          %{x: 0, y: 14, w: 12, h: 4},
          %{columns: ["timestamp", "__event", "impact", "details"]}
        )
      ]
    }
  end
end
