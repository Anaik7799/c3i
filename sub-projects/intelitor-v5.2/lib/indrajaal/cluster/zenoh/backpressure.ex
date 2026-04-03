defmodule Indrajaal.Cluster.Zenoh.Backpressure do
  @moduledoc """
  Circuit breaker and rate limiting for Zenoh event flow control.

  Implements backpressure mechanisms to prevent event flooding in the
  Zenoh messaging layer with configurable rate limits and circuit
  breaker state transitions.

  ## STAMP Constraints

  - SC-BUS-003: Circuit breaker at 1000 events/sec (configurable)
  - SC-BUS-001: Async messaging only
  - SC-BUS-004: Event ordering preserved

  ## Circuit Breaker States

  ```
  CLOSED ──(limit exceeded)──> OPEN
     ^                           │
     │                           │
     └──(success)── HALF-OPEN <──┘(recovery_time)
  ```

  ## Usage

      {:ok, bp} = Backpressure.start_link(rate_limit: 1000)

      # Check if event is allowed
      if Backpressure.allow?(bp, "alarms") do
        publish_event(event)
      else
        {:error, :rate_limited}
      end

      # Or use try_acquire
      case Backpressure.try_acquire(bp, key) do
        :ok -> publish_event(event)
        {:error, :rate_limited} -> handle_backpressure()
      end

  """

  use GenServer
  require Logger

  @type circuit_state :: :closed | :open | :half_open

  # Default: 1000 events per second per key
  @default_rate_limit 1000
  @default_window_ms 1000
  @default_recovery_time_ms 5000

  # ============================================================================
  # CLIENT API
  # ============================================================================

  @doc """
  Starts the backpressure controller.

  ## Options

  - `:name` - Process name (optional)
  - `:rate_limit` - Max events per window (default: 1000)
  - `:window_ms` - Sliding window duration in ms (default: 1000)
  - `:recovery_time_ms` - Time before half-open transition (default: 5000)

  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Checks if an event is allowed for the given key.

  Returns `true` if the event is allowed, `false` if rate limited.
  This also increments the counter for the key.
  """
  @spec allow?(GenServer.server(), String.t()) :: boolean()
  def allow?(server \\ __MODULE__, key) do
    GenServer.call(server, {:allow?, key})
  end

  @doc """
  Attempts to acquire a slot for an event.

  Returns `:ok` if allowed, `{:error, :rate_limited}` if blocked.
  """
  @spec try_acquire(GenServer.server(), String.t()) :: :ok | {:error, :rate_limited}
  def try_acquire(server \\ __MODULE__, key) do
    if allow?(server, key), do: :ok, else: {:error, :rate_limited}
  end

  @doc """
  Gets the circuit breaker state for a specific key.
  """
  @spec get_state(GenServer.server(), String.t()) :: map()
  def get_state(server \\ __MODULE__, key) do
    GenServer.call(server, {:get_state, key})
  end

  @doc """
  Resets the counter and circuit breaker for a specific key.
  """
  @spec reset(GenServer.server(), String.t()) :: :ok
  def reset(server \\ __MODULE__, key) do
    GenServer.call(server, {:reset, key})
  end

  @doc """
  Resets all counters and circuit breakers.
  """
  @spec reset_all(GenServer.server()) :: :ok
  def reset_all(server \\ __MODULE__) do
    GenServer.call(server, :reset_all)
  end

  @doc """
  Returns metrics about rate limiting activity.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server \\ __MODULE__) do
    GenServer.call(server, :metrics)
  end

  @doc """
  Returns health status of the backpressure controller.
  """
  @spec health(GenServer.server()) :: map()
  def health(server \\ __MODULE__) do
    GenServer.call(server, :health)
  end

  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(opts) do
    rate_limit = Keyword.get(opts, :rate_limit, @default_rate_limit)
    window_ms = Keyword.get(opts, :window_ms, @default_window_ms)
    recovery_time_ms = Keyword.get(opts, :recovery_time_ms, @default_recovery_time_ms)

    state = %{
      rate_limit: rate_limit,
      window_ms: window_ms,
      recovery_time_ms: recovery_time_ms,
      keys: %{},
      metrics: %{
        total_allowed: 0,
        total_rejected: 0,
        started_at: DateTime.utc_now()
      }
    }

    # Schedule periodic cleanup of stale keys
    Process.send_after(self(), :cleanup_stale, window_ms * 2)

    Logger.info("[Backpressure] Started with rate_limit: #{rate_limit}/#{window_ms}ms")

    {:ok, state}
  end

  @impl true
  def handle_call({:allow?, key}, _from, state) do
    now = System.monotonic_time(:millisecond)
    {allowed, new_state} = check_and_update(state, key, now)

    # Update metrics
    new_metrics =
      if allowed do
        %{new_state.metrics | total_allowed: new_state.metrics.total_allowed + 1}
      else
        %{new_state.metrics | total_rejected: new_state.metrics.total_rejected + 1}
      end

    {:reply, allowed, %{new_state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:get_state, key}, _from, state) do
    key_state = Map.get(state.keys, key, new_key_state())
    now = System.monotonic_time(:millisecond)

    # Evaluate current circuit state (may have transitioned due to recovery time)
    current_circuit_state = update_circuit_state(key_state, now, state)

    result = %{
      count: length(key_state.timestamps),
      circuit_state: current_circuit_state,
      last_event: List.first(key_state.timestamps),
      opened_at: key_state.opened_at
    }

    {:reply, result, state}
  end

  @impl true
  def handle_call({:reset, key}, _from, state) do
    new_keys = Map.delete(state.keys, key)
    {:reply, :ok, %{state | keys: new_keys}}
  end

  @impl true
  def handle_call(:reset_all, _from, state) do
    {:reply, :ok, %{state | keys: %{}}}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = %{
      total_allowed: state.metrics.total_allowed,
      total_rejected: state.metrics.total_rejected,
      active_keys: map_size(state.keys),
      rate_limit: state.rate_limit,
      window_ms: state.window_ms
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    health = %{
      status: :healthy,
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.metrics.started_at, :millisecond),
      active_keys: map_size(state.keys),
      total_events: state.metrics.total_allowed + state.metrics.total_rejected
    }

    {:reply, health, state}
  end

  @impl true
  def handle_info(:cleanup_stale, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - state.window_ms * 2

    # Remove keys with no recent activity
    new_keys =
      state.keys
      |> Enum.filter(fn {_key, key_state} ->
        case key_state.timestamps do
          [] -> false
          [latest | _] -> latest > cutoff
        end
      end)
      |> Map.new()

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_stale, state.window_ms * 2)

    {:noreply, %{state | keys: new_keys}}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp check_and_update(state, key, now) do
    key_state = Map.get(state.keys, key, new_key_state())

    # Clean old timestamps outside the window
    window_start = now - state.window_ms
    recent_timestamps = key_state.timestamps |> Enum.filter(&(&1 > window_start))

    # Update circuit state based on recovery time
    circuit_state = update_circuit_state(key_state, now, state)

    case circuit_state do
      :open ->
        # Circuit is open, reject immediately
        new_key_state = %{key_state | timestamps: recent_timestamps, circuit_state: :open}
        new_keys = Map.put(state.keys, key, new_key_state)
        {false, %{state | keys: new_keys}}

      :half_open ->
        # Allow one probe request
        if length(recent_timestamps) < 1 do
          new_key_state = allow_request_state(key_state, now, recent_timestamps)
          new_keys = Map.put(state.keys, key, new_key_state)
          {true, %{state | keys: new_keys}}
        else
          new_key_state = %{key_state | timestamps: recent_timestamps, circuit_state: :open}
          new_keys = Map.put(state.keys, key, new_key_state)
          {false, %{state | keys: new_keys}}
        end

      :closed ->
        if length(recent_timestamps) < state.rate_limit do
          # Under limit, allow
          new_key_state = allow_request_state(key_state, now, recent_timestamps)
          new_keys = Map.put(state.keys, key, new_key_state)
          {true, %{state | keys: new_keys}}
        else
          # Limit exceeded, open circuit
          new_key_state = %{
            key_state
            | timestamps: recent_timestamps,
              circuit_state: :open,
              opened_at: now
          }

          new_keys = Map.put(state.keys, key, new_key_state)

          Logger.warning(
            "[Backpressure] Circuit opened for key: #{key}, " <>
              "count: #{length(recent_timestamps)}/#{state.rate_limit}"
          )

          {false, %{state | keys: new_keys}}
        end
    end
  end

  defp update_circuit_state(key_state, now, state) do
    case key_state.circuit_state do
      :open ->
        # Check if recovery time has passed
        if key_state.opened_at && now - key_state.opened_at >= state.recovery_time_ms do
          :half_open
        else
          # Also check if window has slid and count is now under limit
          window_start = now - state.window_ms
          recent_count = key_state.timestamps |> Enum.count(&(&1 > window_start))

          if recent_count < state.rate_limit do
            # Window has slid, traffic is below limit - close circuit
            :closed
          else
            :open
          end
        end

      other ->
        other
    end
  end

  defp new_key_state do
    %{
      timestamps: [],
      circuit_state: :closed,
      opened_at: nil
    }
  end

  # DRY extraction: Create allowed request state update
  defp allow_request_state(key_state, now, recent_timestamps) do
    %{
      key_state
      | timestamps: [now | recent_timestamps],
        circuit_state: :closed
    }
  end
end
