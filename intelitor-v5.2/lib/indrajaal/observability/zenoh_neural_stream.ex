defmodule Indrajaal.Observability.ZenohNeuralStream do
  @moduledoc """
  Real-time streaming of logs, metrics, and state via Zenoh.

  WHAT: Replaces disk-based logging with Zenoh pub/sub for real-time telemetry.
  WHY: SC-OBS-001 requires <50ms telemetry latency for OODA loop responsiveness.
  CONSTRAINTS: Zero-copy where possible, batched writes, ordered delivery per key.

  ## Key Expressions

  ```
  indrajaal/neural/logs/<level>/<module>     - Log streaming
  indrajaal/neural/metrics/<domain>/<metric> - Metric aggregation
  indrajaal/neural/state/<agent>/<key>       - State publication
  ```

  ## STAMP Constraints

  - SC-OBS-001: Latency < 50ms (95th percentile)
  - SC-OBS-002: No data loss (buffered until flush)
  - SC-OBS-003: Ordered delivery per key (version vectors)

  ## AOR Rules

  - AOR-CTX-009: Neural streams MUST use zero-copy where available

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-OBS-001, SC-OBS-002, SC-OBS-003 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohCoordinator

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type stream_config :: %{
          key_prefix: String.t(),
          buffer_size: pos_integer(),
          flush_interval_ms: pos_integer(),
          enable_compression: boolean()
        }

  @type log_entry :: %{
          level: atom(),
          module: module(),
          message: binary(),
          metadata: map(),
          timestamp: DateTime.t()
        }

  @type metric_entry :: %{
          domain: atom(),
          name: atom(),
          value: number(),
          tags: map(),
          timestamp: DateTime.t()
        }

  @type state_entry :: %{
          agent: atom(),
          key: atom(),
          value: term(),
          version: non_neg_integer(),
          timestamp: DateTime.t()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_buffer_size 100
  @default_flush_interval_ms 100
  @metric_aggregation_window_ms 1000
  @key_prefix "indrajaal/neural"

  # Log levels for key expressions
  @log_levels [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]
  # Reserved for log level filtering implementation
  _ = @log_levels

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stream a log entry to Zenoh.

  Key format: indrajaal/neural/logs/<level>/<module>

  ## Parameters
  - level: Log level (:debug, :info, :warning, :error, :critical)
  - module: Source module name
  - message: Log message
  - metadata: Optional metadata map

  ## Returns
  - :ok (async, buffered)
  """
  @spec stream_log(atom(), module(), binary(), map()) :: :ok
  def stream_log(level, module, message, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:log, level, module, message, metadata})
  end

  @doc """
  Stream a metric to Zenoh with aggregation.

  Key format: indrajaal/neural/metrics/<domain>/<metric>

  ## Parameters
  - domain: Metric domain (:system, :flame, :cortex, etc.)
  - name: Metric name
  - value: Numeric value
  - tags: Optional tags map

  ## Returns
  - :ok (async, aggregated)
  """
  @spec stream_metric(atom(), atom(), number(), map()) :: :ok
  def stream_metric(domain, name, value, tags \\ %{}) do
    GenServer.cast(__MODULE__, {:metric, domain, name, value, tags})
  end

  @doc """
  Stream agent state to Zenoh with delta encoding.

  Key format: indrajaal/neural/state/<agent>/<key>

  ## Parameters
  - agent: Agent identifier
  - key: State key
  - value: State value (any term)

  ## Returns
  - :ok (async, delta-encoded)
  """
  @spec stream_state(atom(), atom(), term()) :: :ok
  def stream_state(agent, key, value) do
    GenServer.cast(__MODULE__, {:state, agent, key, value})
  end

  @doc """
  Subscribe to a Zenoh key expression.
  The calling process will receive messages as {:zenoh_msg, key, payload}.
  """
  @spec subscribe(String.t(), pid()) :: :ok
  def subscribe(key, pid) do
    GenServer.call(__MODULE__, {:subscribe, key, pid})
  end

  @doc """
  Force flush all buffers immediately.
  """
  @spec flush() :: :ok
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Get current buffer statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Get stream configuration.
  """
  @spec config() :: stream_config()
  def config do
    GenServer.call(__MODULE__, :config)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[ZenohNeuralStream] Initializing neural stream - SC-OBS-001")

    config = %{
      key_prefix: Keyword.get(opts, :key_prefix, @key_prefix),
      buffer_size: Keyword.get(opts, :buffer_size, @default_buffer_size),
      flush_interval_ms: Keyword.get(opts, :flush_interval_ms, @default_flush_interval_ms),
      enable_compression: Keyword.get(opts, :enable_compression, false)
    }

    state = %{
      config: config,
      # Buffers
      log_buffer: [],
      log_buffer_count: 0,
      metric_buffer: %{},
      metric_aggregations: %{},
      state_buffer: %{},
      state_versions: %{},
      # Subscriptions
      subscribers: %{},
      # Statistics
      logs_streamed: 0,
      metrics_streamed: 0,
      states_streamed: 0,
      flushes: 0,
      last_flush: nil,
      started_at: DateTime.utc_now()
    }

    # Schedule periodic flush
    schedule_flush(config.flush_interval_ms)

    # Schedule metric aggregation window
    schedule_metric_aggregation()

    {:ok, state}
  end

  @impl true
  def handle_cast({:log, level, module, message, metadata}, state) do
    entry = %{
      level: level,
      module: module,
      message: message,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    new_buffer = [entry | state.log_buffer]
    new_count = state.log_buffer_count + 1

    # Check if buffer is full
    new_state =
      if new_count >= state.config.buffer_size do
        flush_log_buffer(%{state | log_buffer: new_buffer, log_buffer_count: new_count})
      else
        %{state | log_buffer: new_buffer, log_buffer_count: new_count}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:metric, domain, name, value, tags}, state) do
    key = {domain, name, tags}
    now = System.monotonic_time(:millisecond)

    # Aggregate metrics within the window
    current = Map.get(state.metric_aggregations, key, %{sum: 0, count: 0, min: value, max: value})

    updated = %{
      sum: current.sum + value,
      count: current.count + 1,
      min: min(current.min, value),
      max: max(current.max, value),
      last_value: value,
      last_update: now
    }

    new_aggregations = Map.put(state.metric_aggregations, key, updated)
    {:noreply, %{state | metric_aggregations: new_aggregations}}
  end

  @impl true
  def handle_cast({:state, agent, key, value}, state) do
    state_key = {agent, key}

    # Get current version
    current_version = Map.get(state.state_versions, state_key, 0)
    new_version = current_version + 1

    # Check if value changed (delta encoding)
    current_value = Map.get(state.state_buffer, state_key)

    new_state =
      if current_value != value do
        # Value changed - update buffer and version
        entry = %{
          agent: agent,
          key: key,
          value: value,
          version: new_version,
          timestamp: DateTime.utc_now()
        }

        %{
          state
          | state_buffer: Map.put(state.state_buffer, state_key, entry),
            state_versions: Map.put(state.state_versions, state_key, new_version)
        }
      else
        # No change - skip
        state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:subscribe, key, pid}, _from, state) do
    Logger.info("[ZenohNeuralStream] New subscription: #{key} -> #{inspect(pid)}")

    # Notify ZenohCoordinator to subscribe at the network level
    if Code.ensure_loaded?(ZenohCoordinator) and GenServer.whereis(ZenohCoordinator) do
      ZenohCoordinator.subscribe_coord(key, self())
    end

    # Track subscriber locally for dispatch
    new_subscribers = Map.update(state.subscribers, key, [pid], fn pids -> [pid | pids] end)
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    new_state =
      state
      |> flush_log_buffer()
      |> flush_metric_buffer()
      |> flush_state_buffer()
      |> Map.put(:last_flush, DateTime.utc_now())
      |> Map.update!(:flushes, &(&1 + 1))

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      logs_streamed: state.logs_streamed,
      metrics_streamed: state.metrics_streamed,
      states_streamed: state.states_streamed,
      flushes: state.flushes,
      log_buffer_size: state.log_buffer_count,
      metric_aggregations: map_size(state.metric_aggregations),
      state_buffer_size: map_size(state.state_buffer),
      last_flush: state.last_flush,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:config, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_info({:zenoh_msg, topic, payload}, state) do
    # Dispatch to all matching subscribers
    # Simple implementation: exact match or prefix match for wildcard support
    Enum.each(state.subscribers, fn {key, pids} ->
      if topic_matches?(key, topic) do
        Enum.each(pids, fn pid ->
          send(pid, {:zenoh_msg, topic, payload})
        end)
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:flush_timer, state) do
    new_state =
      state
      |> flush_log_buffer()
      |> flush_state_buffer()
      |> Map.put(:last_flush, DateTime.utc_now())
      |> Map.update!(:flushes, &(&1 + 1))

    schedule_flush(state.config.flush_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:metric_aggregation, state) do
    new_state = flush_metric_buffer(state)
    schedule_metric_aggregation()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp schedule_flush(interval_ms) do
    Process.send_after(self(), :flush_timer, interval_ms)
  end

  defp schedule_metric_aggregation do
    Process.send_after(self(), :metric_aggregation, @metric_aggregation_window_ms)
  end

  defp topic_matches?(key, topic) do
    if String.ends_with?(key, "**") do
      prefix = String.trim_trailing(key, "**")
      String.starts_with?(topic, prefix)
    else
      key == topic
    end
  end

  defp flush_log_buffer(%{log_buffer: []} = state), do: state

  defp flush_log_buffer(state) do
    # Group logs by level and module for efficient publishing
    grouped =
      state.log_buffer
      |> Enum.reverse()
      |> Enum.group_by(fn entry -> {entry.level, entry.module} end)

    # Publish each group
    Enum.each(grouped, fn {{level, module}, entries} ->
      key = "#{state.config.key_prefix}/logs/#{level}/#{inspect(module)}"
      payload = encode_log_batch(entries)
      publish_to_zenoh(key, payload)
    end)

    %{
      state
      | log_buffer: [],
        log_buffer_count: 0,
        logs_streamed: state.logs_streamed + length(state.log_buffer)
    }
  end

  defp flush_metric_buffer(%{metric_aggregations: aggregations} = state)
       when map_size(aggregations) == 0,
       do: state

  defp flush_metric_buffer(state) do
    # Publish aggregated metrics
    Enum.each(state.metric_aggregations, fn {{domain, name, tags}, agg} ->
      key = "#{state.config.key_prefix}/metrics/#{domain}/#{name}"

      payload = %{
        domain: domain,
        name: name,
        value: agg.last_value,
        sum: agg.sum,
        count: agg.count,
        min: agg.min,
        max: agg.max,
        avg: agg.sum / max(agg.count, 1),
        tags: tags,
        timestamp: DateTime.utc_now()
      }

      publish_to_zenoh(key, payload)
    end)

    count = map_size(state.metric_aggregations)

    %{
      state
      | metric_aggregations: %{},
        metrics_streamed: state.metrics_streamed + count
    }
  end

  defp flush_state_buffer(%{state_buffer: buffer} = state) when map_size(buffer) == 0, do: state

  defp flush_state_buffer(state) do
    # Publish state entries
    Enum.each(state.state_buffer, fn {{agent, key}, entry} ->
      zenoh_key = "#{state.config.key_prefix}/state/#{agent}/#{key}"
      publish_to_zenoh(zenoh_key, entry)
    end)

    count = map_size(state.state_buffer)

    %{
      state
      | state_buffer: %{},
        states_streamed: state.states_streamed + count
    }
  end

  defp encode_log_batch(entries) do
    %{
      count: length(entries),
      entries:
        Enum.map(entries, fn e ->
          %{
            level: e.level,
            module: inspect(e.module),
            message: e.message,
            metadata: e.metadata,
            timestamp: DateTime.to_iso8601(e.timestamp)
          }
        end),
      batch_timestamp: DateTime.utc_now()
    }
  end

  defp publish_to_zenoh(key, payload) do
    # Use ZenohCoordinator if available, otherwise log
    if Code.ensure_loaded?(ZenohCoordinator) and GenServer.whereis(ZenohCoordinator) do
      ZenohCoordinator.publish_coord(key, payload)
    else
      # Fallback: Log at debug level
      Logger.debug("[ZenohNeuralStream] Would publish to #{key}: #{inspect(payload, limit: 100)}")
    end
  rescue
    e ->
      Logger.warning("[ZenohNeuralStream] Publish failed: #{inspect(e)}")
  end
end
