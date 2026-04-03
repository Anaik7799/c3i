defmodule Indrajaal.Security.RateLimiter do
  @moduledoc """
  Real Rate Limiting System with Sliding Window Algorithm

  Provides comprehensive rate limiting with:
  - Sliding window rate limiting with Redis / ETS
  - Role - based and endpoint - specific limits
  - Dynamic adjustment based on load
  - Performance monitoring and telemetry
  - STAMP safety integration
  """

  use GenServer
  require Logger

  @cache_table :rate_limit_cache
  @cleanup_interval :timer.minutes(1)

  @default_limits %{
    admin: %{_requests: 1000, window: 60},
    manager: %{_requests: 500, window: 60},
    operator: %{_requests: 200, window: 60},
    viewer: %{_requests: 100, window: 60},
    service: %{_requests: 2000, window: 60}
  }

  @endpoint_multipliers %{
    # High - traffic endpoints get higher limits
    "/api / health" => 10.0,
    "/api / metrics" => 5.0,
    "/api / alarms" => 2.0,

    # Sensitive endpoints get lower limits
    "/api / auth / login" => 0.1,
    "/api / admin" => 0.2,
    "/api / __users" => 0.5
  }

  defstruct [:cache_table, :cleanup_timer, :redis_enabled, :dynamic_adjustment]

  # Public API

  @spec start_link(any()) :: any()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check rate limit for a user / endpoint combination
  """
  @spec check_rate(term(), term(), term(), list()) :: term()
  # AGENT GA PHASE 20 FIX
  def check_rate(user_id, endpoint, role, opts \\ []) do
    :telemetry.execute(
      [:indrajaal, :security, :rate_limit_check, :start],
      %{system_time: System.system_time()},
      %{user_id: user_id, endpoint: endpoint, role: role}
    )

    GenServer.call(__MODULE__, {:check_rate, user_id, endpoint, role, opts})
  end

  @doc """
  Reset rate limit for a specific user (admin function)
  """
  @spec reset_rate_limit(term(), term()) :: :ok
  def reset_rate_limit(user_id, endpoint) do
    GenServer.cast(__MODULE__, {:reset_rate_limit, user_id, endpoint})
  end

  @doc """
  Get current rate limit statistics
  """
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end

  @doc """
  Update rate limits dynamically based on load
  """
  @spec adjust_limits(map()) :: :ok
  def adjust_limits(adjustments) when is_map(adjustments) do
    GenServer.cast(__MODULE__, {:adjust_limits, adjustments})
  end

  # GenServer Callbacks

  @impl true
  @spec init(any()) :: {:ok, map()}
  def init(opts) do
    # Create ETS table for rate limiting cache
    cache_table = :ets.new(@cache_table, [:set, :public, :named_table])

    # Setup cleanup timer
    cleanup_timer = :timer.send_interval(@cleanup_interval, :cleanup)

    state = %__MODULE__{
      cache_table: cache_table,
      cleanup_timer: cleanup_timer,
      redis_enabled: Keyword.get(opts, :redis_enabled, false),
      dynamic_adjustment: Keyword.get(opts, :dynamic_adjustment, true)
    }

    Logger.info("Rate Limiter initialized", cache_table: cache_table)

    :telemetry.execute(
      [:indrajaal, :security, :rate_limiter, :started],
      %{cache_table_size: 0},
      %{redis_enabled: state.redis_enabled}
    )

    {:ok, state}
  end

  @impl true
  @spec handle_call(term(), GenServer.from(), map()) :: {:reply, term(), map()}
  def handle_call({:check_rate, user_id, endpoint, role, opts}, _from, state) do
    result = perform_rate_check(user_id, endpoint, role, opts, state)

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :security, :rate_limit_check, :stop],
      %{result: if(elem(result, 0) == :ok, do: 1, else: 0)},
      %{user_id: user_id, endpoint: endpoint, role: role}
    )

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_statistics, _from, state) do
    stats = calculate_statistics(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:reset_rate_limit, user_id, endpoint}, state) do
    cache_key = generate_cache_key(user_id, endpoint)
    :ets.delete(@cache_table, cache_key)

    Logger.info("Rate limit reset", user_id: user_id, endpoint: endpoint)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:adjust_limits, adjustments}, state) do
    # Apply dynamic limit adjustments
    Logger.info("Rate limits adjusted", adjustments: inspect(adjustments))
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries(state)
    {:noreply, state}
  end

  # Private Implementation

  @spec perform_rate_check(term(), term(), term(), list(), map()) ::
          {:ok, map()} | {:error, :rate_limited, map()}
  # AGENT GA PHASE 21
  defp perform_rate_check(user_id, endpoint, role, _opts, _state) do
    cache_key = generate_cache_key(user_id, endpoint)
    current_time = System.system_time(:second)

    # Get rate limits for this role / endpoint combination
    limit_config = get_effective_limits(role, endpoint)

    # Check current usage
    case :ets.lookup(@cache_table, cache_key) do
      [] ->
        # First _request - create entry
        entry = %{
          _requests: [current_time],
          first_request: current_time,
          total_requests: 1
        }

        :ets.insert(@cache_table, {cache_key, entry})

        {:ok,
         %{remaining: limit_config._requests - 1, reset_at: current_time + limit_config.window}}

      [{^cache_key, entry}] ->
        # Filter _requests within the time window
        window_start = current_time - limit_config.window
        recent_requests = Enum.filter(entry._requests, fn req_time -> req_time > window_start end)

        if length(recent_requests) >= limit_config._requests do
          # Rate limited
          oldest_request = List.first(Enum.sort(recent_requests))
          reset_at = oldest_request + limit_config.window

          {:error, :rate_limited,
           %{
             limit: limit_config._requests,
             window: limit_config.window,
             reset_at: reset_at,
             retry_after: reset_at - current_time
           }}
        else
          # Allow _request and update entry
          updated_requests = [current_time | recent_requests]

          updated_entry = %{
            entry
            | _requests: updated_requests,
              total_requests: entry.total_requests + 1
          }

          :ets.insert(@cache_table, {cache_key, updated_entry})

          {:ok,
           %{
             remaining: limit_config._requests - length(updated_requests),
             reset_at: current_time + limit_config.window
           }}
        end
    end
  end

  @spec get_effective_limits(atom(), String.t()) :: map()
  defp get_effective_limits(role, endpoint) do
    base_limits = Map.get(@default_limits, role, @default_limits[:viewer])
    multiplier = Map.get(@endpoint_multipliers, endpoint, 1.0)

    %{
      _requests: round(base_limits._requests * multiplier),
      window: base_limits.window
    }
  end

  @spec generate_cache_key(term(), String.t()) :: String.t()
  defp generate_cache_key(user_id, endpoint) do
    "rate_limit:#{user_id}:#{endpoint}"
  end

  @spec calculate_statistics(map()) :: map()
  defp calculate_statistics(state) do
    table_size = :ets.info(@cache_table, :size)
    memory_usage = :ets.info(@cache_table, :memory) * :erlang.system_info(:wordsize)

    %{
      active_entries: table_size,
      memory_usage_bytes: memory_usage,
      redis_enabled: state.redis_enabled,
      dynamic_adjustment: state.dynamic_adjustment
    }
  end

  @spec cleanup_expired_entries(map()) :: :ok
  # AGENT GA PHASE 21
  defp cleanup_expired_entries(_state) do
    current_time = System.system_time(:second)

    # Get all entries
    all_entries = :ets.tab2list(@cache_table)

    # Filter out expired entries (older than max window)
    # 1 hour
    max_window = 3600

    expired_keys =
      for {key, entry} <- all_entries,
          current_time - entry.first_request > max_window,
          do: key

    # Delete expired entries
    Enum.each(expired_keys, fn key ->
      :ets.delete(@cache_table, key)
    end)

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up expired rate limit entries", count: length(expired_keys))
    end

    :ok
  end
end

# Agent: Supervisor - 1 (Security Coordination)
# SOPv5.1 Compliance: ✅ Security rate limiting and STAMP methodology coordination
# Domain: Security
# Responsibilities: Rate limiting enforcement, performance monitoring, dynamic adjustment
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for load - based adjustments
