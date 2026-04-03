defmodule Indrajaal.Telemetry.MetricsCollector do
  @moduledoc """
  Metrics Collection System

  Collects and aggregates metrics from across the system:
  - HTTP __request / response metrics
  - Database performance metrics
  - Authentication and session metrics
  - Business logic metrics
  - System performance metrics
  """

  use GenServer
  require Logger

  @metrics_table :telemetry_metrics
  @aggregation_interval :timer.seconds(30)

  defstruct [:metrics_table, :aggregation_timer, :start_time]

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc "Record HTTP __request metrics"
  @spec record_http_request(String.t(), String.t(), integer(), number()) :: :ok
  def record_http_request(method, path, status, duration_ms) do
    GenServer.cast(__MODULE__, {:http_request, method, path, status, duration_ms})
  end

  @doc "Record database query metrics"
  @spec record_database_query(String.t(), number()) :: :ok
  def record_database_query(source, duration_ms) do
    GenServer.cast(__MODULE__, {:database_query, source, duration_ms})
  end

  @doc "Record detailed Ecto query metrics"
  @spec record_ecto_query(map()) :: :ok
  def record_ecto_query(metrics) do
    GenServer.cast(__MODULE__, {:ecto_query, metrics})
  end

  @doc "Record authentication events"
  @spec record_auth_event(atom(), boolean(), String.t()) :: :ok
  def record_auth_event(event_type, success, tenant_id) do
    GenServer.cast(__MODULE__, {:auth_event, event_type, success, tenant_id})
  end

  @doc "Record business logic events"
  @spec record_business_event(atom(), String.t(), map()) :: :ok
  def record_business_event(event_type, entity_type, meta_data) do
    GenServer.cast(__MODULE__, {:business_event, event_type, entity_type, meta_data})
  end

  @doc "Record system performance metrics"
  @spec record_system_metric(atom(), number(), map()) :: :ok
  def record_system_metric(metric_type, value, meta_data) do
    GenServer.cast(__MODULE__, {:system_metric, metric_type, value, meta_data})
  end

  @doc "Get current metrics summary"
  @spec get_metrics_summary() :: map()
  def get_metrics_summary do
    GenServer.call(__MODULE__, :get_metrics_summary)
  end

  @doc "Get detailed metrics for specific category"
  @spec get_detailed_metrics(atom()) :: list()
  def get_detailed_metrics(category) do
    GenServer.call(__MODULE__, {:get_detailed_metrics, category})
  end

  @doc "Export metrics for external systems"
  @spec export_metrics(atom()) :: {:ok, any()} | {:error, term()}
  def export_metrics(format \\ :json) do
    GenServer.call(__MODULE__, {:export_metrics, format})
  end

  # GenServer Callbacks

  @impl true
  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    Logger.info("🏭 Starting Telemetry Metrics Collector")

    # Initialize ETS table for metrics storage
    metrics_table =
      :ets.new(@metrics_table, [
        :named_table,
        :public,
        :set,
        {:write_concurrency, true},
        {:read_concurrency, true}
      ])

    state = %__MODULE__{
      metrics_table: metrics_table,
      start_time: DateTime.utc_now(),
      aggregation_timer: schedule_aggregation()
    }

    {:ok, state}
  end

  @impl true
  @spec handle_cast({:http_request, term(), term(), term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:http_request, method, path, status, duration_ms}, state) do
    timestamp = DateTime.utc_now()

    # Store individual metric
    :ets.insert(@metrics_table, {
      {:http_request, timestamp},
      %{
        method: method,
        path: path,
        status: status,
        duration_ms: duration_ms,
        timestamp: timestamp
      }
    })

    # Update aggregated counters
    update_http_counters(method, status, duration_ms)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:database_query, term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:database_query, source, duration_ms}, state) do
    timestamp = DateTime.utc_now()

    :ets.insert(@metrics_table, {
      {:database_query, timestamp},
      %{
        source: source,
        duration_ms: duration_ms,
        timestamp: timestamp
      }
    })

    update_database_counters(source, duration_ms)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:ecto_query, term()}, term()) :: {:noreply, term()}
  def handle_cast({:ecto_query, metrics}, state) do
    timestamp = DateTime.utc_now()

    enhanced_metrics =
      Map.merge(metrics, %{
        timestamp: timestamp,
        collector: "ecto_telemetry"
      })

    :ets.insert(@metrics_table, {
      {:ecto_query, timestamp},
      enhanced_metrics
    })

    # Extract relevant metrics for aggregation
    duration = Map.get(metrics, :total_time, 0)
    update_database_counters("ecto", duration / 1000)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:auth_event, term(), term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:auth_event, event_type, success, tenant_id}, state) do
    timestamp = DateTime.utc_now()

    :ets.insert(@metrics_table, {
      {:auth_event, timestamp},
      %{
        event_type: event_type,
        success: success,
        tenant_id: tenant_id,
        timestamp: timestamp
      }
    })

    update_auth_counters(event_type, success, tenant_id)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:business_event, term(), term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:business_event, event_type, entity_type, metadata}, state) do
    timestamp = DateTime.utc_now()

    enhanced_metadata =
      Map.merge(metadata, %{
        event_type: event_type,
        entity_type: entity_type,
        timestamp: timestamp
      })

    :ets.insert(@metrics_table, {
      {:business_event, timestamp},
      enhanced_metadata
    })

    update_business_counters(event_type, entity_type)

    {:noreply, state}
  end

  @impl true
  @spec handle_cast({:system_metric, term(), term(), term()}, term()) :: {:noreply, term()}
  def handle_cast({:system_metric, metric_type, value, metadata}, state) do
    timestamp = DateTime.utc_now()

    enhanced_metadata =
      Map.merge(metadata, %{
        metric_type: metric_type,
        value: value,
        timestamp: timestamp
      })

    :ets.insert(@metrics_table, {
      {:system_metric, timestamp},
      enhanced_metadata
    })

    update_system_counters(metric_type, value)

    {:noreply, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:get_metrics_summary, _from, state) do
    summary = generate_metrics_summary()
    {:reply, summary, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:get_detailed_metrics, category}, _from, state) do
    metrics = get_category_metrics(category)
    {:reply, metrics, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call({:export_metrics, format}, _from, state) do
    case export_metrics_in_format(format) do
      {:ok, exported} -> {:reply, {:ok, exported}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  @spec handle_info(term(), term()) :: term()
  def handle_info(:aggregate_metrics, state) do
    Logger.debug("🔄 Performing metrics aggregation")

    perform_aggregation()

    # Schedule next aggregation
    new_timer = schedule_aggregation()

    new_state = %{state | aggregation_timer: new_timer}
    {:noreply, new_state}
  end

  @impl true
  @spec terminate(term(), term()) :: term()
  def terminate(_reason, state) do
    if state.aggregation_timer do
      Process.cancel_timer(state.aggregation_timer)
    end

    Logger.info("🛑 Telemetry Metrics Collector terminated")
    :ok
  end

  # Private Helper Functions

  @spec update_http_counters(String.t(), integer(), number()) :: true
  defp update_http_counters(method, status, duration_ms) do
    # Update method counters
    :ets.update_counter(@metrics_table, {:http_methods, method}, {2, 1}, {method, 0})

    # Update status counters
    status_class = div(status, 100) * 100
    :ets.update_counter(@metrics_table, {:http_status, status_class}, {2, 1}, {status_class, 0})

    # Update duration tracking
    :ets.update_counter(
      @metrics_table,
      {:http_duration_total},
      {2, duration_ms},
      {:http_duration_total, 0}
    )

    :ets.update_counter(@metrics_table, {:http_request_count}, {2, 1}, {:http_request_count, 0})
  end

  @spec update_database_counters(String.t(), number()) :: true
  defp update_database_counters(source, duration_ms) do
    # Update query counters by source
    :ets.update_counter(@metrics_table, {:db_queries, source}, {2, 1}, {source, 0})

    # Update duration tracking
    :ets.update_counter(
      @metrics_table,
      {:db_duration_total},
      {2, duration_ms},
      {:db_duration_total, 0}
    )

    :ets.update_counter(@metrics_table, {:db_query_count}, {2, 1}, {:db_query_count, 0})
  end

  @spec update_auth_counters(atom(), boolean(), String.t()) :: true
  defp update_auth_counters(event_type, success, tenant_id) do
    # Update auth event counters
    :ets.update_counter(@metrics_table, {:auth_events, event_type}, {2, 1}, {event_type, 0})

    # Update success / failure counters
    result = if success, do: :success, else: :failure
    :ets.update_counter(@metrics_table, {:auth_results, result}, {2, 1}, {result, 0})

    # Update tenant - specific counters
    :ets.update_counter(@metrics_table, {:auth_tenants, tenant_id}, {2, 1}, {tenant_id, 0})
  end

  @spec update_business_counters(atom(), String.t()) :: true
  defp update_business_counters(event_type, entity_type) do
    # Update business event counters
    :ets.update_counter(@metrics_table, {:business_events, event_type}, {2, 1}, {event_type, 0})

    :ets.update_counter(
      @metrics_table,
      {:business_entities, entity_type},
      {2, 1},
      {entity_type, 0}
    )
  end

  @spec update_system_counters(atom(), number()) :: true
  defp update_system_counters(metric_type, value) do
    # Update system metric counters
    :ets.update_counter(@metrics_table, {:system_metrics, metric_type}, {2, 1}, {metric_type, 0})

    # Store current value (last value overwrites)
    :ets.insert(@metrics_table, {{:system_value, metric_type}, value})
  end

  @spec generate_metrics_summary() :: map()
  defp generate_metrics_summary do
    http_requests = get_counter_value(:http_request_count)
    db_queries = get_counter_value(:db_query_count)
    avg_response_time = calculate_avg_response_time()
    avg_db_time = calculate_avg_db_time()

    %{
      http_requests: http_requests,
      database_queries: db_queries,
      average_response_time_ms: avg_response_time,
      average_db_time_ms: avg_db_time,
      uptime_seconds: calculate_uptime(),
      collected_at: DateTime.utc_now()
    }
  end

  @spec get_category_metrics(atom()) :: list()
  defp get_category_metrics(category) do
    pattern =
      case category do
        :http -> {:http_request, :_}
        :database -> {:database_query, :_}
        :auth -> {:auth_event, :_}
        :business -> {:business_event, :_}
        :system -> {:system_metric, :_}
        _ -> {:_, :_}
      end

    matched_objects = :ets.match_object(@metrics_table, {pattern, :_})

    matched_objects
    |> Enum.map(fn {_key, value} -> value end)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    # Limit to recent 1000 entries
    |> Enum.take(1000)
  end

  @spec export_metrics_in_format(atom()) :: {:ok, any()} | {:error, term()}
  defp export_metrics_in_format(:json) do
    summary = generate_metrics_summary()
    {:ok, Jason.encode!(summary)}
  rescue
    error -> {:error, error}
  end

  defp export_metrics_in_format(format) do
    {:error, {:unsupported_format, format}}
  end

  @spec perform_aggregation() :: :ok
  defp perform_aggregation do
    # Aggregate old metrics to prevent unbounded growth
    # 1 hour ago
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)

    # Clean up old individual metrics, keep aggregated counters
    pattern = {{:_, :"$1"}, :_}
    guard = {:is_map, :"$1"}

    select_result = :ets.select(@metrics_table, [{pattern, [guard], [:"$_"]}])

    old_metrics =
      select_result
      |> Enum.filter(fn {{_type, timestamp}, _value} ->
        DateTime.compare(timestamp, cutoff_time) == :lt
      end)

    # Remove old individual metrics
    Enum.each(old_metrics, fn {key, _value} ->
      :ets.delete(@metrics_table, key)
    end)

    Logger.debug("🧹 Cleaned up #{length(old_metrics)} old metrics entries")
  end

  @spec get_counter_value(atom()) :: integer()
  defp get_counter_value(counter_key) do
    case :ets.lookup(@metrics_table, counter_key) do
      [{_key, value}] -> value
      [] -> 0
    end
  end

  @spec calculate_avg_response_time() :: float()
  defp calculate_avg_response_time do
    total_duration = get_counter_value(:http_duration_total)
    request_count = get_counter_value(:http_request_count)

    case request_count do
      0 -> 0.0
      count -> total_duration / count
    end
  end

  @spec calculate_avg_db_time() :: float()
  defp calculate_avg_db_time do
    total_duration = get_counter_value(:db_duration_total)
    query_count = get_counter_value(:db_query_count)

    case query_count do
      0 -> 0.0
      count -> total_duration / count
    end
  end

  @spec calculate_uptime() :: any()
  def calculate_uptime() do
    case :ets.lookup(@metrics_table, :start_time) do
      [{:start_time, start_time}] ->
        DateTime.diff(DateTime.utc_now(), start_time, :second)

      [] ->
        0
    end
  end

  @spec schedule_aggregation() :: reference()
  defp schedule_aggregation do
    Process.send_after(self(), :aggregate_metrics, @aggregation_interval)
  end
end
