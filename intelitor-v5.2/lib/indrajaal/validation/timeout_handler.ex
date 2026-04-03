defmodule Indrajaal.Validation.TimeoutHandler do
  @moduledoc """
  Timeout handling with graceful degradation for OpenCode API client.

  Implements:
  - Configurable timeout strategies
  - Graceful degradation on timeout
  - Partial result handling
  - Timeout prediction and prevention
  """

  require Logger

  # Default timeout configurations (milliseconds)
  @default_timeouts %{
    # 5 seconds for connection
    connect: 5_000,
    # 30 seconds for request
    request: 30_000,
    # 60 seconds total
    total: 60_000,
    # 2 minutes for validation operations
    validation: 120_000
  }

  @doc """
  Wraps a function with timeout handling and graceful degradation.

  ## Options
  - `:timeout` - Maximum time in milliseconds (default: 30_000)
  - `:degradation` - Strategy when timeout occurs (:full, :partial, :minimal, :none)
  - `:cache_key` - Key for cached fallback data
  - `:partial_handler` - Function to extract partial results

  ## Examples

      iex> TimeoutHandler.with_timeout(fn -> long_operation() end, timeout: 5000)
      {:ok, result}

      iex> TimeoutHandler.with_timeout(fn -> very_long_op() end, degradation: :partial)
      {:partial, partial_result}
  """
  def with_timeout(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeouts.request)
    degradation = Keyword.get(opts, :degradation, :partial)
    cache_key = Keyword.get(opts, :cache_key)

    task = Task.async(fun)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        # Operation completed within timeout
        cache_result_if_needed(result, cache_key)
        {:ok, result}

      nil ->
        # Timeout occurred
        Logger.warning("Operation timed out after #{timeout}ms",
          degradation: degradation,
          cache_key: cache_key
        )

        handle_timeout_with_degradation(degradation, cache_key, opts)

      {:exit, reason} ->
        # Task crashed
        Logger.error("Task crashed during execution",
          reason: inspect(reason),
          degradation: degradation
        )

        handle_crash_with_degradation(degradation, cache_key, reason)
    end
  end

  @doc """
  Configures adaptive timeouts based on historical performance.
  """
  def adaptive_timeout(operation_type, base_timeout \\ nil) do
    base = base_timeout || Map.get(@default_timeouts, operation_type, 30_000)

    # Get historical performance data
    history = get_performance_history(operation_type)

    if history do
      calculate_adaptive_timeout(base, history)
    else
      base
    end
  end

  @doc """
  Implements timeout with progressive degradation levels.
  """
  def with_progressive_timeout(fun, opts \\ []) do
    levels =
      Keyword.get(opts, :levels, [
        {5_000, :full},
        {10_000, :partial},
        {20_000, :minimal}
      ])

    run_with_degradation_levels(fun, levels, opts)
  end

  defp run_with_degradation_levels(_fun, [], _opts) do
    {:error, :all_timeout_levels_exceeded}
  end

  defp run_with_degradation_levels(fun, [{timeout, mode} | rest], opts) do
    case with_timeout(fun, timeout: timeout, degradation: mode) do
      {:ok, result} ->
        {:ok, result}

      {:partial, _} = partial ->
        partial

      {:cached, _} = cached ->
        cached

      _error ->
        # Try next degradation level
        run_with_degradation_levels(fun, rest, opts)
    end
  end

  @doc """
  Monitors operation duration and warns about approaching timeouts.
  """
  def monitor_timeout(operation_name, timeout \\ 30_000) do
    start_time = System.monotonic_time(:millisecond)
    # Warn at 80% of timeout
    warning_threshold = timeout * 0.8

    # Schedule warning
    warning_ref =
      Process.send_after(
        self(),
        {:timeout_warning, operation_name, warning_threshold},
        round(warning_threshold)
      )

    # Return monitoring context
    %{
      operation: operation_name,
      start_time: start_time,
      timeout: timeout,
      warning_ref: warning_ref
    }
  end

  @doc """
  Completes timeout monitoring and records metrics.
  """
  def complete_monitoring(monitoring_context) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - monitoring_context.start_time

    # Cancel warning if still pending
    Process.cancel_timer(monitoring_context.warning_ref)

    # Record metrics
    record_performance_metrics(
      monitoring_context.operation,
      duration,
      monitoring_context.timeout
    )

    # Return performance data
    %{
      operation: monitoring_context.operation,
      duration: duration,
      timeout: monitoring_context.timeout,
      utilization: duration / monitoring_context.timeout * 100
    }
  end

  # Private functions

  defp handle_timeout_with_degradation(:full, cache_key, _opts) do
    case get_cached_result(cache_key) do
      {:ok, cached} ->
        Logger.info("Using cached result due to timeout", cache_key: cache_key)
        {:cached, cached}

      :error ->
        {:error, :timeout_no_cache}
    end
  end

  defp handle_timeout_with_degradation(:partial, _cache_key, opts) do
    partial_handler = Keyword.get(opts, :partial_handler, &default_partial_handler/0)

    case partial_handler.() do
      {:ok, partial} ->
        {:partial, partial}

      _ ->
        {:error, :timeout_no_partial}
    end
  end

  defp handle_timeout_with_degradation(:minimal, _cache_key, _opts) do
    {:minimal,
     %{
       status: :timeout,
       timestamp: DateTime.utc_now(),
       message: "Operation timed out, returning minimal data"
     }}
  end

  defp handle_timeout_with_degradation(:none, _cache_key, _opts) do
    {:error, :timeout}
  end

  defp handle_crash_with_degradation(degradation, cache_key, reason) do
    # Similar to timeout handling but for crashes
    case degradation do
      :full when not is_nil(cache_key) ->
        case get_cached_result(cache_key) do
          {:ok, cached} -> {:cached, cached}
          :error -> {:error, {:crashed, reason}}
        end

      _ ->
        {:error, {:crashed, reason}}
    end
  end

  defp cache_result_if_needed(_result, nil), do: :ok

  defp cache_result_if_needed(result, cache_key) do
    # Simple in-memory cache using ETS (in production, use proper cache)
    :ets.insert(:timeout_cache, {cache_key, result, System.monotonic_time(:second)})
    :ok
  end

  defp get_cached_result(nil), do: :error

  defp get_cached_result(cache_key) do
    case :ets.lookup(:timeout_cache, cache_key) do
      [{^cache_key, result, _timestamp}] -> {:ok, result}
      [] -> :error
    end
  end

  defp default_partial_handler do
    {:ok, %{partial: true, data: nil}}
  end

  defp get_performance_history(_operation_type) do
    # In production, fetch from metrics storage
    # For now, return mock data
    %{
      avg_duration: 15_000,
      p95_duration: 25_000,
      p99_duration: 35_000,
      success_rate: 0.95
    }
  end

  defp calculate_adaptive_timeout(base, history) do
    # Use P99 duration with 20% buffer
    adaptive = history.p99_duration * 1.2

    # Don't go below base or above 2x base
    adaptive
    |> max(base)
    |> min(base * 2)
    |> round()
  end

  defp record_performance_metrics(operation, duration, timeout) do
    Logger.info("Operation performance",
      operation: operation,
      duration_ms: duration,
      timeout_ms: timeout,
      utilization: Float.round(duration / timeout * 100, 1)
    )

    # In production, send to telemetry system
    :telemetry.execute(
      [:timeout_handler, :operation, :complete],
      %{duration: duration, timeout: timeout},
      %{operation: operation}
    )
  end

  @doc """
  Initializes the timeout cache table.
  Must be called during application startup.
  """
  def init_cache do
    :ets.new(:timeout_cache, [:set, :public, :named_table])
    :ok
  end
end
