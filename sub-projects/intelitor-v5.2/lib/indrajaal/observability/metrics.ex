defmodule Indrajaal.Observability.Metrics do
  @moduledoc """
  Business metrics collection and reporting for the Indrajaal platform.

  This module provides a unified interface for collecting, aggregating, and
  exporting business-critical metrics to SigNoz. It focuses on domain-specific
  metrics that provide insights into system health, business value, and
  operational efficiency.

  ## Metric Categories

  - **Alarm Metrics**: Response times, acknowledgment rates, false positive rates
  - **Access Control Metrics**: Authentication success/failure, access grant patterns
  - **Video Analytics Metrics**: Processing throughput, detection accuracy
  - **System Performance**: API latency, __database query performance, queue depths
  - **Business KPIs**: Active __users, tenant usage, feature adoption rates

  ## Integration

  Metrics are exported to SigNoz via OpenTelemetry protocol, enabling:
  - Real-time dashboards and visualizations
  - Alerting on threshold violations
  - Historical trend analysis
  - Correlation with traces and logs

  ## Usage

      # Increment a counter
      Metrics.increment("alarms.acknowledged", 1, %{severity: "high"})

      # Record a histogram value
      Metrics.histogram("api.response_time", 145.2, %{endpoint: "/api/alarms"})

      # Update a gauge
      Metrics.gauge("system.active_connections", 42, %{tenant_id: "acme"})

  ## STAMP Safety Constraints

  - SC1: Pr_event metric __data loss during high load
  - SC2: Ensure tenant isolation in metric aggregation
  - SC3: Graceful degradation when metric backend unavailable
  """

  use GenServer
  require Logger
  # Metric type definitions
  @type metric_type :: :counter | :gauge | :histogram | :summary
  @type metric_name :: String.t()
  @type metric_value :: number()
  @type metric_tags :: %{optional(atom() | String.t()) => any()}

  # Internal state structure
  defstruct [
    :metrics_registry,
    :batch_buffer,
    :last_export,
    :export_interval
  ]

  # Default export interval (5 seconds, 100ms in test)
  @default_export_interval if Mix.env() == :test, do: 100, else: 5_000

  # EP-013: Metric naming conventions (unused but kept for future reference)
  # @metric_prefixes %{
  #   alarms: "intelitor.alarms",
  #   access: "intelitor.access",
  #   video: "intelitor.video",
  #   system: "intelitor.system",
  #   business: "intelitor.business"
  # }

  @doc """
  Starts the metrics collection GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initializes the metrics collection system.
  """
  def init(opts) do
    export_interval = Keyword.get(opts, :export_interval, @default_export_interval)

    # Schedule first export
    schedule_export(export_interval)

    state = %__MODULE__{
      metrics_registry: %{},
      batch_buffer: [],
      last_export: DateTime.utc_now(),
      export_interval: export_interval
    }

    Logger.info("Metrics collection system initialized",
      export_interval: export_interval,
      backend: "SigNoz/OpenTelemetry"
    )

    {:ok, state}
  end

  @doc """
  Increments a counter metric.

  ## Examples

      increment("alarms.acknowledged")
      increment("alarms.acknowledged", 1, %{severity: "high", tenant_id: "acme"})
  """
  @spec increment(metric_name(), metric_value(), metric_tags()) :: :ok
  def increment(name, value \\ 1, tags \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, :counter, name, value, tags})
  end

  @doc """
  Records a gauge value.

  ## Examples

      gauge("system.active_connections", 42)
      gauge("system.memory_usage", 1.8, %{unit: "gb", host: "app-01"})
  """
  @spec gauge(metric_name(), metric_value(), metric_tags()) :: :ok
  def gauge(name, value, tags \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, :gauge, name, value, tags})
  end

  @doc """
  Records a histogram value (for distributions).

  ## Examples

      histogram("api.response_time", 145.2)
      histogram("api.response_time", 145.2, %{endpoint: "/api/alarms", method: "GET"})
  """
  @spec histogram(metric_name(), metric_value(), metric_tags()) :: :ok
  def histogram(name, value, tags \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, :histogram, name, value, tags})
  end

  @doc """
  Records a summary value (for percentile calculations).

  ## Examples

      summary("query.execution_time", 23.4)
      summary("query.execution_time", 23.4, %{query_type: "complex", tenant_id: "acme"})
  """
  @spec summary(metric_name(), metric_value(), metric_tags()) :: :ok
  def summary(name, value, tags \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, :summary, name, value, tags})
  end

  @doc """
  Records a domain-specific business metric.

  ## Examples

      record_business_metric(:alarm_response_time, 2.5, %{priority: "high"})
      record_business_metric(:__user_login_success, 1, %{auth_method: "oauth"})
  """
  def record_business_metric(metric_key, value, tags \\ %{}) do
    name = get_business_metric_name(metric_key)
    type = get_business_metric_type(metric_key)

    enhanced_tags =
      tags
      |> Map.put(:metric_category, "business")
      |> ensure_tenant_isolation()

    case type do
      :counter ->
        increment(name, value, enhanced_tags)

      :gauge ->
        gauge(name, value, enhanced_tags)

      :histogram ->
        histogram(name, value, enhanced_tags)
        # Note: type currently only includes :counter, :gauge, :histogram
        # :summary -> summary(name, value, enhanced_tags)  # Unreachable - commented out
    end
  end

  @doc """
  Exports metrics in Prometheus format for scraping.

  ## Examples

      metrics_text = export_prometheus()
      # Returns Prometheus-formatted metrics as text
  """
  def export_prometheus do
    GenServer.call(__MODULE__, :export_prometheus)
  end

  @doc """
  Gets current metric value for monitoring.

  ## Examples

      get_metric_value("system.active_connections")
      # Returns current gauge value or nil
  """
  def get_metric_value(name) do
    GenServer.call(__MODULE__, {:get_metric_value, name})
  end

  # GenServer callbacks

  def handle_cast({:record_metric, type, name, value, tags}, state) do
    # Ensure tenant isolation
    tags = ensure_tenant_isolation(tags)

    # Add to batch buffer
    metric_entry = %{
      type: type,
      name: name,
      value: value,
      tags: tags,
      timestamp: DateTime.utc_now()
    }

    updated_buffer = [metric_entry | state.batch_buffer]

    # Update registry for gauges
    updated_registry =
      if type == :gauge do
        Map.put(state.metrics_registry, {name, tags}, value)
      else
        state.metrics_registry
      end

    {:noreply, %{state | batch_buffer: updated_buffer, metrics_registry: updated_registry}}
  end

  def handle_call(:export_prometheus, _from, state) do
    prometheus_text = generate_prometheus_format(state)
    {:reply, prometheus_text, state}
  end

  def handle_call({:get_metric_value, name}, _from, state) do
    # Find gauge value in registry
    value =
      state.metrics_registry
      |> Enum.find(fn {{metric_name, _}, _} -> metric_name == name end)
      |> case do
        nil -> nil
        {_, value} -> value
      end

    {:reply, value, state}
  end

  def handle_info(:export_metrics, state) do
    # Export batched metrics to OpenTelemetry
    if length(state.batch_buffer) > 0 do
      export_to_opentelemetry(state.batch_buffer)

      Logger.debug("Exported metrics batch",
        count: length(state.batch_buffer),
        export_time: DateTime.utc_now()
      )
    end

    # Schedule next export
    schedule_export(state.export_interval)

    # Clear buffer after export
    {:noreply, %{state | batch_buffer: [], last_export: DateTime.utc_now()}}
  end

  # Private functions

  defp schedule_export(interval) do
    Process.send_after(self(), :export_metrics, interval)
  end

  defp export_to_opentelemetry(metrics) do
    # Group metrics by type for efficient export
    metrics
    |> Enum.group_by(& &1.type)
    |> Enum.each(fn {type, metrics} ->
      export_metric_type(type, metrics)
    end)
  end

  defp export_metric_type(:counter, metrics) do
    Enum.each(metrics, fn metric ->
      # In a real implementation, this would use OpenTelemetry Metrics API
      # For now, emit telemetry __event that can be picked up by handlers
      :telemetry.execute(
        [:indrajaal, :metrics, :counter],
        %{value: metric.value},
        Map.merge(metric.tags, %{name: metric.name})
      )
    end)
  end

  defp export_metric_type(:gauge, metrics) do
    Enum.each(metrics, fn metric ->
      :telemetry.execute(
        [:indrajaal, :metrics, :gauge],
        %{value: metric.value},
        Map.merge(metric.tags, %{name: metric.name})
      )
    end)
  end

  defp export_metric_type(:histogram, metrics) do
    Enum.each(metrics, fn metric ->
      :telemetry.execute(
        [:indrajaal, :metrics, :histogram],
        %{value: metric.value},
        Map.merge(metric.tags, %{name: metric.name})
      )
    end)
  end

  defp export_metric_type(:summary, metrics) do
    Enum.each(metrics, fn metric ->
      :telemetry.execute(
        [:indrajaal, :metrics, :summary],
        %{value: metric.value},
        Map.merge(metric.tags, %{name: metric.name})
      )
    end)
  end

  defp generate_prometheus_format(state) do
    # Generate Prometheus exposition format
    lines = []

    # Add help and type information
    lines =
      lines ++
        [
          "# HELP indrajaal_metrics Indrajaal platform metrics",
          "# TYPE indrajaal_metrics gauge"
        ]

    # Format gauge metrics
    gauge_lines =
      state.metrics_registry
      |> Enum.map(fn {{name, tags}, value} ->
        tag_string =
          Enum.map_join(tags, ",", fn {k, v} -> ~s(#{k}="#{v}") end)

        if tag_string == "" do
          "#{name} #{value}"
        else
          "#{name}{#{tag_string}} #{value}"
        end
      end)

    lines = lines ++ gauge_lines

    # Join all lines
    Enum.join(lines, "\n") <> "\n"
  end

  defp get_business_metric_name(metric_key) do
    case metric_key do
      :alarm_response_time -> "intelitor.business.alarm_response_time_seconds"
      :__user_login_success -> "intelitor.business.__user_login_success_total"
      :feature_usage -> "intelitor.business.feature_usage_total"
      :tenant_activity -> "intelitor.business.tenant_activity_score"
      _ -> "intelitor.business.#{metric_key}"
    end
  end

  defp get_business_metric_type(metric_key) do
    case metric_key do
      :alarm_response_time -> :histogram
      :__user_login_success -> :counter
      :feature_usage -> :counter
      :tenant_activity -> :gauge
      _ -> :gauge
    end
  end

  @doc """
  Tracks KPI metrics for business value measurement.
  """
  def track_kpi(kpi_name, value, meta_data \\ %{}) do
    enhanced_meta_data =
      meta_data
      |> Map.put(:kpi, true)
      |> Map.put(:business_impact, "high")

    gauge("intelitor.kpi.#{kpi_name}", value, enhanced_meta_data)
  end

  @doc """
  Batch records multiple metrics efficiently.
  """
  def batch_record(metrics) when is_list(metrics) do
    Enum.each(metrics, fn {type, name, value, tags} ->
      case type do
        :counter -> increment(name, value, tags)
        :gauge -> gauge(name, value, tags)
        :histogram -> histogram(name, value, tags)
        :summary -> summary(name, value, tags)
      end
    end)
  end

  defp ensure_tenant_isolation(tags) do
    if Map.has_key?(tags, :tenant_id) do
      tags
    else
      # Get tenant __context from process dictionary or default
      tenant_id = Process.get(:tenant_id, "default")
      Map.put(tags, :tenant_id, tenant_id)
    end
  end
end
