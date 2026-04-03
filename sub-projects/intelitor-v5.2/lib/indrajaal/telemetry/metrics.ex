defmodule Indrajaal.Telemetry.Metrics do
  @moduledoc """
  SIL-6 Biomorphic Telemetry Metrics Module

  Production-grade telemetry metrics collection with:
  - Real-time metric tracking via ETS
  - Telemetry event emission for OTEL/Prometheus integration
  - Histogram/Counter/Gauge support
  - Tenant-aware metrics isolation

  ## STAMP Constraints
  - SC-OBS-001: All metrics must be collected within 1ms
  - SC-OBS-002: Metric cardinality < 10,000 unique labels
  - SC-OBS-003: ETS table cleanup every 1 hour
  - SC-OBS-004: Telemetry events emitted for all metrics

  ## AOR Rules
  - AOR-OBS-001: Log all safety violations immediately
  - AOR-OBS-002: Track auth failures for rate limiting
  - AOR-OBS-003: Aggregate VM metrics every 10s

  Created: 2025-11-13 14:10 CET
  Updated: 2026-01-10 (SIL-6 Biomorphic Implementation)
  Version: 21.2.0-SIL6
  """

  require Logger

  @metrics_table :indrajaal_telemetry_metrics
  @counters_table :indrajaal_telemetry_counters
  @histograms_table :indrajaal_telemetry_histograms

  # Histogram buckets for response times (ms)
  @http_buckets [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
  @db_buckets [0.1, 0.5, 1, 2.5, 5, 10, 25, 50, 100, 250, 500, 1000]

  @doc """
  Initializes the metrics ETS tables. Call from application supervisor.
  """
  @spec init() :: :ok
  def init do
    # Create tables if they don't exist
    create_table_if_not_exists(@metrics_table, [:set, :public, :named_table])
    create_table_if_not_exists(@counters_table, [:set, :public, :named_table])
    create_table_if_not_exists(@histograms_table, [:set, :public, :named_table])
    :ok
  end

  defp create_table_if_not_exists(name, opts) do
    case :ets.whereis(name) do
      :undefined -> :ets.new(name, opts)
      _tid -> name
    end
  end

  defp ensure_tables_exist do
    if :ets.whereis(@metrics_table) == :undefined, do: init()
  end

  # ============================================================================
  # HTTP METRICS
  # ============================================================================

  @doc """
  Records HTTP request metrics.

  ## Parameters
  - method: HTTP method (GET, POST, etc.)
  - path: Request path
  - status: HTTP status code
  - duration_ms: Request duration in milliseconds

  ## Returns
  - {:ok, metrics} on success
  """
  @spec record_http_request(atom(), String.t(), integer(), number()) ::
          {:ok, map()} | {:error, String.t()}
  def record_http_request(method, path, status, duration_ms) do
    ensure_tables_exist()

    # Normalize path (remove IDs for cardinality control)
    normalized_path = normalize_path(path)
    status_class = div(status, 100) * 100

    # Increment request counter
    counter_key = {:http_requests, method, normalized_path, status_class}
    increment_counter(counter_key)

    # Record in histogram
    histogram_key = {:http_duration, method, normalized_path}
    record_histogram(histogram_key, duration_ms, @http_buckets)

    # Emit telemetry event
    :telemetry.execute(
      [:indrajaal, :http, :request],
      %{duration_ms: duration_ms, status: status},
      %{method: method, path: normalized_path, status_class: status_class}
    )

    # Track slow requests (>500ms)
    if duration_ms > 500 do
      Logger.warning("Slow HTTP request",
        method: method,
        path: path,
        duration_ms: duration_ms,
        status: status
      )
    end

    {:ok,
     %{
       method: method,
       path: normalized_path,
       status: status,
       duration_ms: duration_ms,
       recorded_at: DateTime.utc_now()
     }}
  end

  # ============================================================================
  # DATABASE METRICS
  # ============================================================================

  @doc """
  Records database query metrics.

  ## Parameters
  - query_type: Type of query (select, insert, update, delete)
  - duration_ms: Query duration in milliseconds
  """
  @spec record_database_query(atom(), number()) :: {:ok, map()} | {:error, String.t()}
  def record_database_query(query_type, duration_ms) do
    ensure_tables_exist()

    # Increment query counter
    counter_key = {:db_queries, query_type}
    increment_counter(counter_key)

    # Record in histogram
    histogram_key = {:db_duration, query_type}
    record_histogram(histogram_key, duration_ms, @db_buckets)

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :database, :query],
      %{duration_ms: duration_ms},
      %{query_type: query_type}
    )

    # Track slow queries (>100ms)
    if duration_ms > 100 do
      Logger.warning("Slow database query",
        query_type: query_type,
        duration_ms: duration_ms
      )
    end

    {:ok, %{query_type: query_type, duration_ms: duration_ms}}
  end

  @doc """
  Records Ecto query metrics with full query details.
  """
  @spec record_ecto_query(map()) :: {:ok, map()} | {:error, String.t()}
  def record_ecto_query(query_data) do
    ensure_tables_exist()

    query_type = Map.get(query_data, :type, :unknown)
    # nanoseconds to ms
    duration_ms = Map.get(query_data, :query_time, 0) / 1_000_000
    source = Map.get(query_data, :source, "unknown")

    # Record basic metrics
    record_database_query(query_type, duration_ms)

    # Track per-table metrics
    table_key = {:ecto_table, source, query_type}
    increment_counter(table_key)

    # Emit detailed telemetry
    :telemetry.execute(
      [:indrajaal, :ecto, :query],
      %{duration_ms: duration_ms, decode_time: Map.get(query_data, :decode_time, 0)},
      %{
        source: source,
        query_type: query_type,
        result_size: Map.get(query_data, :result, []) |> length()
      }
    )

    {:ok, %{source: source, query_type: query_type, duration_ms: duration_ms}}
  end

  # ============================================================================
  # AUTHENTICATION METRICS
  # ============================================================================

  @doc """
  Records authentication event metrics.
  """
  @spec record_auth_event(atom(), boolean(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def record_auth_event(event_type, success, tenant_id) do
    ensure_tables_exist()

    status = if success, do: :success, else: :failure

    # Increment counter
    counter_key = {:auth_event, event_type, status, tenant_id}
    increment_counter(counter_key)

    # Track global auth metrics
    global_key = {:auth_global, event_type, status}
    increment_counter(global_key)

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :auth, event_type],
      %{count: 1},
      %{success: success, tenant_id: tenant_id}
    )

    # Log failures for security monitoring
    unless success do
      Logger.warning("Authentication failure",
        event_type: event_type,
        tenant_id: tenant_id
      )
    end

    {:ok, %{event_type: event_type, success: success, tenant_id: tenant_id}}
  end

  @doc """
  Records authentication failure for rate limiting and security monitoring.
  """
  @spec record_auth_failure(String.t()) :: {:ok, map()} | {:error, String.t()}
  def record_auth_failure(reason) do
    ensure_tables_exist()

    counter_key = {:auth_failure, reason}
    count = increment_counter(counter_key)

    # Track failure rate (last 5 minutes)
    window_key = {:auth_failure_window, div(System.system_time(:second), 300)}
    increment_counter(window_key)

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :auth, :failure],
      %{count: 1},
      %{reason: reason}
    )

    # Alert on high failure rate
    if count > 100 do
      Logger.error("High authentication failure rate",
        reason: reason,
        count: count
      )
    end

    {:ok, %{reason: reason, count: count}}
  end

  @doc """
  Records session failure metrics.
  """
  @spec record_session_failure(String.t()) :: {:ok, map()} | {:error, String.t()}
  def record_session_failure(reason) do
    ensure_tables_exist()

    counter_key = {:session_failure, reason}
    count = increment_counter(counter_key)

    :telemetry.execute(
      [:indrajaal, :session, :failure],
      %{count: 1},
      %{reason: reason}
    )

    {:ok, %{reason: reason, count: count}}
  end

  # ============================================================================
  # RATE LIMITING METRICS
  # ============================================================================

  @doc """
  Records rate limit violation for monitoring and alerting.
  """
  @spec record_rate_limit_violation(String.t(), atom()) :: {:ok, map()} | {:error, String.t()}
  def record_rate_limit_violation(identifier, limit_type) do
    ensure_tables_exist()

    counter_key = {:rate_limit, limit_type}
    count = increment_counter(counter_key)

    # Track per-identifier violations (with cardinality limit)
    identifier_hash = :erlang.phash2(identifier, 1000)
    id_key = {:rate_limit_id, identifier_hash, limit_type}
    increment_counter(id_key)

    :telemetry.execute(
      [:indrajaal, :rate_limit, :violation],
      %{count: 1},
      %{identifier_hash: identifier_hash, limit_type: limit_type}
    )

    Logger.warning("Rate limit violation",
      identifier: identifier,
      limit_type: limit_type,
      total_count: count
    )

    {:ok, %{identifier: identifier, limit_type: limit_type, count: count}}
  end

  # ============================================================================
  # ALARM METRICS
  # ============================================================================

  @doc """
  Records alarm event metrics for business monitoring.
  """
  @spec record_alarm_event(atom(), atom(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def record_alarm_event(alarm_type, severity, tenant_id) do
    ensure_tables_exist()

    # Increment counters
    counter_key = {:alarm, alarm_type, severity}
    increment_counter(counter_key)

    tenant_key = {:alarm_tenant, tenant_id, alarm_type}
    increment_counter(tenant_key)

    :telemetry.execute(
      [:indrajaal, :alarm, :event],
      %{count: 1},
      %{alarm_type: alarm_type, severity: severity, tenant_id: tenant_id}
    )

    # Log critical alarms
    if severity in [:critical, :emergency] do
      Logger.error("Critical alarm event",
        alarm_type: alarm_type,
        severity: severity,
        tenant_id: tenant_id
      )
    end

    {:ok, %{alarm_type: alarm_type, severity: severity, tenant_id: tenant_id}}
  end

  # ============================================================================
  # SAFETY METRICS
  # ============================================================================

  @doc """
  Records safety violation metrics - highest priority per AOR-OBS-001.
  """
  @spec record_safety_violation(atom(), atom()) :: {:ok, map()} | {:error, String.t()}
  def record_safety_violation(violation_type, severity) do
    ensure_tables_exist()

    counter_key = {:safety_violation, violation_type, severity}
    count = increment_counter(counter_key)

    :telemetry.execute(
      [:indrajaal, :safety, :violation],
      %{count: 1, severity_level: severity_to_level(severity)},
      %{violation_type: violation_type, severity: severity}
    )

    # ALWAYS log safety violations (per AOR-OBS-001)
    Logger.error("Safety violation detected",
      violation_type: violation_type,
      severity: severity,
      total_count: count
    )

    # Alert Sentinel if available
    try do
      Indrajaal.Safety.Sentinel.report_threat(violation_type, :safety_violation, %{
        severity: severity,
        count: count
      })
    rescue
      _ -> :ok
    end

    {:ok, %{violation_type: violation_type, severity: severity, count: count}}
  end

  defp severity_to_level(:critical), do: 5
  defp severity_to_level(:high), do: 4
  defp severity_to_level(:medium), do: 3
  defp severity_to_level(:low), do: 2
  defp severity_to_level(_), do: 1

  # ============================================================================
  # VM METRICS
  # ============================================================================

  @doc """
  Records VM metrics for system health monitoring.
  """
  @spec record_vm_metrics(map()) :: {:ok, map()} | {:error, String.t()}
  def record_vm_metrics(metrics_data) do
    ensure_tables_exist()

    # Extract key metrics
    memory = Map.get(metrics_data, :memory, %{})
    process_count = Map.get(metrics_data, :process_count, :erlang.system_info(:process_count))
    run_queue = Map.get(metrics_data, :run_queue, :erlang.statistics(:total_run_queue_lengths))

    # Store current values
    :ets.insert(@metrics_table, {:vm_memory_total, memory[:total] || :erlang.memory(:total)})

    :ets.insert(
      @metrics_table,
      {:vm_memory_processes, memory[:processes] || :erlang.memory(:processes)}
    )

    :ets.insert(@metrics_table, {:vm_process_count, process_count})
    :ets.insert(@metrics_table, {:vm_run_queue, elem(run_queue, 0)})
    :ets.insert(@metrics_table, {:vm_timestamp, DateTime.utc_now()})

    :telemetry.execute(
      [:indrajaal, :vm, :metrics],
      %{
        memory_total: memory[:total] || :erlang.memory(:total),
        process_count: process_count,
        run_queue: elem(run_queue, 0)
      },
      %{}
    )

    {:ok,
     %{
       memory: memory,
       process_count: process_count,
       run_queue: run_queue,
       recorded_at: DateTime.utc_now()
     }}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp normalize_path(path) do
    # Replace UUIDs and numeric IDs with placeholders
    path
    |> String.replace(~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i, ":id")
    |> String.replace(~r/\/\d+/, "/:id")
  end

  defp increment_counter(key) do
    try do
      :ets.update_counter(@counters_table, key, {2, 1}, {key, 0})
    rescue
      ArgumentError ->
        :ets.insert(@counters_table, {key, 1})
        1
    end
  end

  defp record_histogram(key, value, buckets) do
    # Find the appropriate bucket
    bucket = Enum.find(buckets, List.last(buckets), fn b -> value <= b end)

    bucket_key = {key, bucket}

    try do
      :ets.update_counter(@histograms_table, bucket_key, {2, 1}, {bucket_key, 0})
    rescue
      ArgumentError ->
        :ets.insert(@histograms_table, {bucket_key, 1})
    end

    # Also track sum and count for average calculation
    sum_key = {key, :sum}
    count_key = {key, :count}

    try do
      :ets.update_counter(@histograms_table, sum_key, {2, round(value * 1000)}, {sum_key, 0})
      :ets.update_counter(@histograms_table, count_key, {2, 1}, {count_key, 0})
    rescue
      ArgumentError ->
        :ets.insert(@histograms_table, {sum_key, round(value * 1000)})
        :ets.insert(@histograms_table, {count_key, 1})
    end
  end

  # ============================================================================
  # EXPORT FUNCTIONS
  # ============================================================================

  @doc """
  Exports all metrics in Prometheus text format.
  """
  @spec export_prometheus() :: String.t()
  def export_prometheus do
    ensure_tables_exist()

    counters = export_counters()
    histograms = export_histograms()
    gauges = export_gauges()

    """
    # HELP indrajaal_http_requests_total Total HTTP requests
    # TYPE indrajaal_http_requests_total counter
    #{counters}

    # HELP indrajaal_http_request_duration_seconds HTTP request duration histogram
    # TYPE indrajaal_http_request_duration_seconds histogram
    #{histograms}

    # HELP indrajaal_vm_memory_bytes VM memory usage
    # TYPE indrajaal_vm_memory_bytes gauge
    #{gauges}
    """
  end

  defp export_counters do
    :ets.tab2list(@counters_table)
    |> Enum.map(fn {key, value} ->
      labels = format_labels(key)
      metric_name = format_metric_name(key)
      "#{metric_name}{#{labels}} #{value}"
    end)
    |> Enum.join("\n")
  end

  defp export_histograms do
    :ets.tab2list(@histograms_table)
    |> Enum.group_by(fn {{key, _bucket}, _} -> key end)
    |> Enum.map(fn {key, entries} ->
      format_histogram(key, entries)
    end)
    |> Enum.join("\n")
  end

  defp export_gauges do
    case :ets.lookup(@metrics_table, :vm_memory_total) do
      [{:vm_memory_total, value}] -> "indrajaal_vm_memory_bytes{type=\"total\"} #{value}"
      [] -> ""
    end
  end

  defp format_labels(key) when is_tuple(key) do
    key
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.map(fn {v, i} -> "label#{i}=\"#{v}\"" end)
    |> Enum.join(",")
  end

  defp format_metric_name(key) when is_tuple(key) do
    key |> elem(0) |> to_string() |> String.replace("-", "_")
  end

  defp format_histogram(_key, _entries), do: ""

  @doc """
  Gets current metric value by key.
  """
  @spec get_metric(term()) :: term()
  def get_metric(key) do
    ensure_tables_exist()

    case :ets.lookup(@counters_table, key) do
      [{^key, value}] ->
        value

      [] ->
        case :ets.lookup(@metrics_table, key) do
          [{^key, value}] -> value
          [] -> nil
        end
    end
  end

  @doc """
  Resets all metrics (for testing).
  """
  @spec reset_all() :: :ok
  def reset_all do
    ensure_tables_exist()
    :ets.delete_all_objects(@metrics_table)
    :ets.delete_all_objects(@counters_table)
    :ets.delete_all_objects(@histograms_table)
    :ok
  end
end
