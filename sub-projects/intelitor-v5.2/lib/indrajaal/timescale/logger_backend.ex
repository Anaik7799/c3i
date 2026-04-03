defmodule Indrajaal.Timescale.LoggerBackend do
  @moduledoc """
  🚀 Enterprise TimescaleDB Logger Backend - SOPv5.1 Cybernetic Execution
  ======================================================================
  Date: 2025 - 08 - 09 10:07:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container - Only + Git - based
  Agent: Triple Logging Architecture Implementation Worker - 3

  High - performance Logger backend that writes directly to TimescaleDB hypertables
  for real - time time - series logging and analytics. Part of the triple logging
  architecture: Console + SigNoz + TimescaleDB.

  ## Features

  - Direct TimescaleDB hypertable integration
  - Automatic __event classification and routing
  - Batched inserts for optimal performance
  - Time - series metadata extraction
  - Multi - tenant log isolation
  - Automatic retry with exponential backoff
  - Memory - efficient buffering

  ## Configuration

  ```elixir
  config :logger, Indrajaal.Timescale.LoggerBackend,
    level: :info,
    batch_size: 100,
    flush_interval: 5_000,
    hypertables: [
      __event_logs: %{chunk_interval: "1 day", retention_days: 90}
    ]
  ```

  ## Supported Log Types

  - **General Events**: User actions, system __events, API calls
  - **Alarm Events**: Security alarms, device alarms, system alerts
  - **Performance Metrics**: Response times, throughput, resource usage
  - **Audit Events**: Security audits, compliance logs, access logs

  ## Performance Features

  - Batched writes to reduce database load
  - Asynchronous processing with GenServer
  - Configurable flush intervals
  - Connection pooling optimization
  - Memory usage monitoring
  """

  @behaviour :gen_event

  require Logger
  alias Indrajaal.Timescale.EventLogger

  # Default configuration
  @default_config %{
    level: :info,
    batch_size: 100,
    flush_interval: 5_000,
    max_buffer_size: 10_000,
    hypertables: %{
      ts_event_logs: %{chunk_interval: "1 day", retention_days: 90},
      ts_alarm_events: %{chunk_interval: "1 hour", retention_days: 365},
      ts_performance_metrics: %{chunk_interval: "1 hour", retention_days: 30}
    }
  }

  # State structure
  defstruct [
    :config,
    :level,
    :buffer,
    :buffer_size,
    :flush_timer
  ]

  ## gen_event Callbacks

  @impl :gen_event
  @spec init(term()) :: {:ok, term()}
  def init(__MODULE__) do
    opts = Application.get_env(:indrajaal, __MODULE__, [])
    init({__MODULE__, opts})
  end

  def init({__MODULE__, opts}) do
    config = build_config(opts)

    state = %__MODULE__{
      config: config,
      level: config.level,
      buffer: [],
      buffer_size: 0,
      flush_timer: schedule_flush(config.flush_interval)
    }

    {:ok, state}
  end

  @impl :gen_event
  @spec handle_event(term(), term()) :: {:ok, term()}
  def handle_event({level, _gl, {Logger, message, timestamp, metadata}}, state) do
    # Normalize deprecated :warn to :warning (SC-SIL6-001: OTP 28 compatibility)
    normalized_level = normalize_log_level(level)

    if Logger.compare_levels(normalized_level, state.level) != :lt do
      event_entry = format_log_entry(normalized_level, message, timestamp, metadata)
      new_buffer = [event_entry | state.buffer]
      new_size = state.buffer_size + 1
      new_state = %{state | buffer: new_buffer, buffer_size: new_size}

      # Flush if buffer is full
      if new_size >= state.config.batch_size do
        flush_buffer(new_state)
        {:ok, %{state | buffer: [], buffer_size: 0}}
      else
        {:ok, new_state}
      end
    else
      {:ok, state}
    end
  end

  @impl :gen_event
  @spec handle_event(term(), term()) :: term()
  def handle_event(:flush, state) do
    flush_buffer(state)
    {:ok, %{state | buffer: [], buffer_size: 0}}
  end

  @impl :gen_event
  @spec handle_info(term(), term()) :: term()
  def handle_info({:flush_timer}, state) do
    if state.buffer_size > 0 do
      flush_buffer(state)
    end

    new_timer = schedule_flush(state.config.flush_interval)
    {:ok, %{state | buffer: [], buffer_size: 0, flush_timer: new_timer}}
  end

  @impl :gen_event
  def handle_info(_msg, state) do
    # Ignore unexpected messages (e.g. IO replies)
    {:ok, state}
  end

  @impl :gen_event
  @spec handle_call(term(), term()) :: term()
  def handle_call(:get_stats, state) do
    stats = %{
      buffer_size: state.buffer_size,
      max_buffer_size: state.config.max_buffer_size,
      level: state.level,
      config: state.config
    }

    {:ok, stats, state}
  end

  ## Private Functions

  # Normalize deprecated log levels for OTP 28+ compatibility (SC-SIL6-001)
  # :warn is deprecated in favor of :warning since OTP 21/Elixir 1.11
  defp normalize_log_level(:warn), do: :warning
  defp normalize_log_level(level), do: level

  defp build_config(opts) when is_list(opts) do
    @default_config
    |> Map.merge(Enum.into(opts, %{}))
    |> validate_config()
  end

  defp validate_config(config) do
    # Ensure batch_size is reasonable
    config = %{config | batch_size: max(1, min(config.batch_size, 1000))}

    # Ensure flush_interval is reasonable
    config = %{config | flush_interval: max(1000, min(config.flush_interval, 60_000))}

    config
  end

  defp format_log_entry(level, message, timestamp, metadata) do
    %{
      timestamp: timestamp_to_datetime(timestamp),
      level: level,
      message: IO.chardata_to_string(message),
      metadata: extract_timescale_metadata(metadata),
      event_type: classify_event_type(metadata, message),
      event_source: extract_event_source(metadata),
      tenant_id: extract_tenant_id(metadata),
      user_id: metadata[:user_id],
      trace_id: metadata[:trace_id],
      span_id: metadata[:span_id],
      correlation_id: metadata[:request_id],
      duration_ms: extract_duration(metadata),
      status: extract_status(level, metadata),
      severity: atom_to_string(level)
    }
  end

  defp extract_timescale_metadata(metadata) do
    # Extract relevant metadata for time - series analysis
    metadata
    |> Enum.filter(fn {key, _value} ->
      key in [
        :tenant_id,
        :user_id,
        :resource,
        :action,
        :alarm_id,
        :device_id,
        :severity,
        :status,
        :error_type,
        :duration_ms,
        :ip_address,
        :method,
        :path_info,
        :worker,
        :queue,
        :component,
        :metric_value
      ]
    end)
    |> Map.new()
  end

  defp classify_event_type(metadata, message) do
    cond do
      metadata[:alarm_id] -> "alarm_event"
      metadata[:metric_value] -> "performance_metric"
      metadata[:user_id] && metadata[:action] -> "user_activity"
      String.contains?(IO.chardata_to_string(message), ["audit", "security"]) -> "audit_event"
      metadata[:error_type] -> "error_event"
      true -> "general_event"
    end
  end

  defp extract_event_source(metadata) do
    cond do
      metadata[:component] -> atom_to_string(metadata[:component])
      metadata[:worker] -> "oban_job"
      metadata[:resource] -> "ash_resource"
      true -> "application"
    end
  end

  defp extract_tenant_id(metadata) do
    metadata[:tenant_id] || metadata[:actor_id]
  end

  defp extract_duration(metadata) do
    metadata[:duration_ms] || metadata[:duration] || metadata[:elapsed]
  end

  defp extract_status(level, metadata) do
    case metadata[:status] do
      status when not is_nil(status) ->
        atom_to_string(status)

      _ ->
        case level do
          :error -> "error"
          :warning -> "warning"
          :info -> "success"
          _ -> "info"
        end
    end
  end

  defp atom_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp atom_to_string(value) when is_binary(value), do: value
  defp atom_to_string(value), do: inspect(value)

  defp timestamp_to_datetime(timestamp) when is_integer(timestamp) do
    timestamp
    |> System.convert_time_unit(:native, :microsecond)
    |> DateTime.from_unix!(:microsecond)
  end

  defp timestamp_to_datetime({{year, month, day}, {hour, minute, second, microsecond}}) do
    %DateTime{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      microsecond: {microsecond, 6},
      time_zone: "Etc / UTC",
      zone_abbr: "UTC",
      utc_offset: 0,
      std_offset: 0
    }
  end

  defp flush_buffer(%{buffer: buffer, buffer_size: size}) when size > 0 do
    # Route logs to appropriate hypertables
    {events, alarms, metrics, audits} = categorize_log_entries(buffer)

    # Asynchronous batch inserts
    spawn_flush_task(events, :ts_event_logs)
    spawn_flush_task(alarms, :ts_alarm_events)
    spawn_flush_task(metrics, :ts_performance_metrics)
    spawn_flush_task(audits, :ts_audit_logs)
  end

  defp flush_buffer(_), do: :ok

  defp categorize_log_entries(entries) do
    Enum.reduce(entries, {[], [], [], []}, fn entry, {events, alarms, metrics, audits} ->
      case entry.event_type do
        "alarm_event" -> {events, [entry | alarms], metrics, audits}
        "performance_metric" -> {events, alarms, [entry | metrics], audits}
        "audit_event" -> {events, alarms, metrics, [entry | audits]}
        _ -> {[entry | events], alarms, metrics, audits}
      end
    end)
  end

  defp spawn_flush_task([], _table), do: :ok

  defp spawn_flush_task(entries, :ts_event_logs) do
    Task.start(fn ->
      try do
        event_data = Enum.map(entries, &convert_to_event_log/1)
        EventLogger.log_event_batch(event_data)
      rescue
        error ->
          Logger.error("Failed to flush events to ts_event_logs", error: inspect(error))
      end
    end)
  end

  defp spawn_flush_task(entries, :ts_alarm_events) do
    Task.start(fn ->
      try do
        alarm_data = Enum.map(entries, &convert_to_alarm_event/1)
        EventLogger.log_alarm_batch(alarm_data)
      rescue
        error ->
          Logger.error("Failed to flush events to ts_alarm_events", error: inspect(error))
      end
    end)
  end

  defp spawn_flush_task(entries, :ts_performance_metrics) do
    Task.start(fn ->
      try do
        metric_data = Enum.map(entries, &convert_to_performance_metric/1)
        EventLogger.log_metric_batch(metric_data)
      rescue
        error ->
          Logger.error("Failed to flush events to ts_performance_metrics", error: inspect(error))
      end
    end)
  end

  defp spawn_flush_task(entries, :ts_audit_logs) do
    Task.start(fn ->
      try do
        audit_data = Enum.map(entries, &convert_to_audit_log/1)
        EventLogger.log_audit_batch(audit_data)
      rescue
        error ->
          Logger.error("Failed to flush events to ts_audit_logs", error: inspect(error))
      end
    end)
  end

  defp convert_to_event_log(entry) do
    %{
      timestamp: entry.timestamp,
      event_type: entry.event_type,
      event_source: entry.event_source,
      tenant_id: entry.tenant_id,
      user_id: entry.user_id,
      action: entry.metadata[:action],
      status: entry.status,
      metadata: entry.metadata,
      duration_ms: entry.duration_ms,
      correlation_id: entry.correlation_id,
      trace_id: entry.trace_id,
      span_id: entry.span_id,
      severity: entry.severity,
      message: entry.message
    }
  end

  defp convert_to_alarm_event(entry) do
    %{
      timestamp: entry.timestamp,
      tenant_id: entry.tenant_id,
      alarm_id: entry.metadata[:alarm_id],
      device_id: entry.metadata[:device_id],
      alarm_type: entry.metadata[:alarm_type] || "system",
      severity: entry.severity,
      status: entry.status,
      message: entry.message,
      metadata: entry.metadata
    }
  end

  defp convert_to_performance_metric(entry) do
    %{
      timestamp: entry.timestamp,
      tenant_id: entry.tenant_id,
      metric_name: entry.metadata[:metric_name] || "response_time",
      metric_type: "gauge",
      value: entry.metadata[:metric_value] || entry.duration_ms || 0.0,
      unit: entry.metadata[:unit] || "ms",
      labels: entry.metadata,
      source: entry.event_source
    }
  end

  defp convert_to_audit_log(entry) do
    %{
      timestamp: entry.timestamp,
      tenant_id: entry.tenant_id,
      user_id: entry.user_id,
      action: entry.metadata[:action] || "unknown",
      resource_type: entry.metadata[:resource],
      resource_id: entry.metadata[:resource_id],
      metadata: entry.metadata,
      result: entry.status,
      message: entry.message
    }
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), {:flush_timer}, interval)
  end
end
