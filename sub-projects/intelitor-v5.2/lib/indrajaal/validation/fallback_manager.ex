defmodule Indrajaal.Validation.FallbackManager do
  @moduledoc """
  Manages seamless fallback between live API and mock implementations.

  Features:
  - Automatic fallback on API failures
  - Cache-based fallback for recent validations
  - Performance-based routing decisions
  - Gradual live API adoption with canary deployments
  """

  use GenServer
  require Logger

  @fallback_modes [:live_only, :live_with_mock, :mock_only, :cache_first]
  # 1 hour
  @cache_ttl 3600_000
  # 5 minutes
  @performance_window 300_000

  defstruct [
    :mode,
    :cache,
    :performance_stats,
    :canary_percentage,
    :circuit_breaker_state
  ]

  # Public API

  @doc """
  Starts the fallback manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes validation with automatic fallback handling.

  ## Options
  - `:mode` - Fallback mode (:live_only, :live_with_mock, :mock_only, :cache_first)
  - `:cache_key` - Cache key for result storage
  - `:canary` - Whether this is a canary deployment test

  ## Examples

      iex> FallbackManager.validate_with_fallback(fn -> api_call() end, fn -> mock_call() end)
      {:ok, result, :live}

      iex> FallbackManager.validate_with_fallback(fn -> failing_api() end, fn -> mock_call() end)
      {:ok, result, :mock}
  """
  def validate_with_fallback(live_fun, mock_fun, opts \\ []) do
    GenServer.call(__MODULE__, {:validate, live_fun, mock_fun, opts}, 30_000)
  catch
    :exit, {:noproc, _} ->
      # Fallback manager not started, use mock
      Logger.warning("Fallback manager not started, using mock")
      execute_mock(mock_fun)
  end

  @doc """
  Sets the fallback mode.
  """
  def set_mode(mode) when mode in @fallback_modes do
    GenServer.call(__MODULE__, {:set_mode, mode})
  end

  @doc """
  Gets current fallback statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Sets canary deployment percentage (0-100).
  """
  def set_canary_percentage(percentage) when percentage >= 0 and percentage <= 100 do
    GenServer.call(__MODULE__, {:set_canary, percentage})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    mode = Keyword.get(opts, :mode, :live_with_mock)
    canary_percentage = Keyword.get(opts, :canary_percentage, 10)

    # Initialize ETS cache
    :ets.new(:fallback_cache, [:set, :public, :named_table])

    state = %__MODULE__{
      mode: mode,
      cache: :fallback_cache,
      performance_stats: %{
        live_success: 0,
        live_failure: 0,
        mock_used: 0,
        cache_hits: 0,
        total_requests: 0
      },
      canary_percentage: canary_percentage,
      circuit_breaker_state: :closed
    }

    Logger.info("Fallback manager started",
      mode: mode,
      canary_percentage: canary_percentage
    )

    # Schedule performance stats cleanup
    Process.send_after(self(), :cleanup_stats, @performance_window)

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:validate, live_fun, mock_fun, opts}, _from, state) do
    mode = Keyword.get(opts, :mode, state.mode)
    cache_key = Keyword.get(opts, :cache_key)
    is_canary = Keyword.get(opts, :canary, should_use_canary?(state))

    # Update stats
    new_state = update_stats(state, :total_request)

    # Execute based on mode
    {result, source, final_state} =
      case mode do
        :live_only ->
          execute_live_only(live_fun, new_state)

        :mock_only ->
          execute_mock_only(mock_fun, new_state)

        :cache_first ->
          execute_cache_first(cache_key, live_fun, mock_fun, new_state)

        :live_with_mock ->
          if is_canary || state.circuit_breaker_state == :open do
            execute_mock_only(mock_fun, new_state)
          else
            execute_live_with_fallback(live_fun, mock_fun, cache_key, new_state)
          end
      end

    # Cache successful results
    if elem(result, 0) == :ok && cache_key do
      cache_result(cache_key, elem(result, 1))
    end

    {:reply, {result, source}, final_state}
  end

  @impl GenServer
  def handle_call({:set_mode, mode}, _from, state) do
    Logger.info("Fallback mode changed", from: state.mode, to: mode)
    {:reply, :ok, %{state | mode: mode}}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats =
      Map.merge(state.performance_stats, %{
        mode: state.mode,
        canary_percentage: state.canary_percentage,
        circuit_breaker: state.circuit_breaker_state,
        success_rate: calculate_success_rate(state.performance_stats)
      })

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call({:set_canary, percentage}, _from, state) do
    Logger.info("Canary percentage changed", from: state.canary_percentage, to: percentage)
    {:reply, :ok, %{state | canary_percentage: percentage}}
  end

  @impl GenServer
  def handle_info(:cleanup_stats, state) do
    # Reset performance stats periodically
    new_state = %{
      state
      | performance_stats: %{
          live_success: 0,
          live_failure: 0,
          mock_used: 0,
          cache_hits: 0,
          total_requests: 0
        }
    }

    # Check circuit breaker state
    new_state = update_circuit_breaker(new_state)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_stats, @performance_window)

    {:noreply, new_state}
  end

  # Private functions

  defp execute_live_only(live_fun, state) do
    case safe_execute(live_fun) do
      {:ok, result} ->
        {{:ok, result}, :live, update_stats(state, :live_success)}

      {:error, _} = error ->
        {error, :live, update_stats(state, :live_failure)}
    end
  end

  defp execute_mock_only(mock_fun, state) do
    result = execute_mock(mock_fun)
    {result, :mock, update_stats(state, :mock_used)}
  end

  defp execute_cache_first(nil, live_fun, mock_fun, state) do
    # No cache key, fall back to live with mock
    execute_live_with_fallback(live_fun, mock_fun, nil, state)
  end

  defp execute_cache_first(cache_key, live_fun, mock_fun, state) do
    case get_cached_result(cache_key) do
      {:ok, cached} ->
        Logger.debug("Cache hit", cache_key: cache_key)
        {{:ok, cached}, :cache, update_stats(state, :cache_hit)}

      :miss ->
        execute_live_with_fallback(live_fun, mock_fun, cache_key, state)
    end
  end

  defp execute_live_with_fallback(live_fun, mock_fun, _cache_key, state) do
    case safe_execute(live_fun) do
      {:ok, result} ->
        Logger.debug("Live API successful")
        {{:ok, result}, :live, update_stats(state, :live_success)}

      {:error, reason} ->
        Logger.warning("Live API failed, using mock",
          reason: inspect(reason)
        )

        # Try mock fallback
        mock_result = execute_mock(mock_fun)
        {mock_result, :mock, update_stats(state, [:live_failure, :mock_used])}
    end
  end

  defp execute_mock(mock_fun) do
    case safe_execute(mock_fun) do
      {:ok, _} = result -> result
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  end

  defp safe_execute(fun) do
    try do
      case fun.() do
        {:ok, _} = result -> result
        {:error, _} = error -> error
        result -> {:ok, result}
      end
    rescue
      error ->
        Logger.error("Function execution failed",
          error: inspect(error),
          stacktrace: __STACKTRACE__
        )

        {:error, error}
    end
  end

  defp should_use_canary?(state) do
    # Randomly determine if this request should use canary
    :rand.uniform(100) <= state.canary_percentage
  end

  defp update_stats(state, stat) when is_atom(stat) do
    update_stats(state, [stat])
  end

  defp update_stats(state, stats) when is_list(stats) do
    new_performance_stats =
      Enum.reduce(stats, state.performance_stats, fn stat, acc ->
        case stat do
          :total_request -> Map.update(acc, :total_requests, 1, &(&1 + 1))
          :live_success -> Map.update(acc, :live_success, 1, &(&1 + 1))
          :live_failure -> Map.update(acc, :live_failure, 1, &(&1 + 1))
          :mock_used -> Map.update(acc, :mock_used, 1, &(&1 + 1))
          :cache_hit -> Map.update(acc, :cache_hits, 1, &(&1 + 1))
          _ -> acc
        end
      end)

    %{state | performance_stats: new_performance_stats}
  end

  defp update_circuit_breaker(state) do
    success_rate = calculate_success_rate(state.performance_stats)

    new_cb_state =
      cond do
        # Open circuit if success rate drops below 50%
        success_rate < 0.5 && state.performance_stats.total_requests > 10 ->
          if state.circuit_breaker_state != :open do
            Logger.warning("Circuit breaker opened due to low success rate",
              success_rate: success_rate
            )
          end

          :open

        # Close circuit if success rate is good
        success_rate > 0.8 && state.circuit_breaker_state == :open ->
          Logger.info("Circuit breaker closed, success rate recovered",
            success_rate: success_rate
          )

          :closed

        true ->
          state.circuit_breaker_state
      end

    %{state | circuit_breaker_state: new_cb_state}
  end

  defp calculate_success_rate(stats) do
    total_live = stats.live_success + stats.live_failure

    if total_live > 0 do
      stats.live_success / total_live
    else
      # No requests yet, assume healthy
      1.0
    end
  end

  defp cache_result(key, result) do
    :ets.insert(:fallback_cache, {key, result, System.monotonic_time(:millisecond)})
    :ok
  end

  defp get_cached_result(key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(:fallback_cache, key) do
      [{^key, result, timestamp}] ->
        if now - timestamp < @cache_ttl do
          {:ok, result}
        else
          # Expired
          :ets.delete(:fallback_cache, key)
          :miss
        end

      [] ->
        :miss
    end
  end
end
