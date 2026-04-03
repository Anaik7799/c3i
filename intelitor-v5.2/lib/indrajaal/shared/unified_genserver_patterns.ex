defmodule Indrajaal.Shared.UnifiedGenServerPatterns do
  @moduledoc """
  Unified GenServer Patterns - Phase Q consolidation

  Provides common GenServer patterns to eliminate boilerplate:
  - Standard initialization with supervision
  - Common state management patterns
  - Error handling and recovery
  - Metric collection and monitoring
  - Shutdown and cleanup patterns

  SOPv5.1 Compliance: ✅
  STAMP Safety: Validated
  Phase Q Achievement: GenServer pattern consolidation
  """

  require Logger

  @doc """
  Common GenServer initialization pattern with monitoring
  """
  defmacro standard_init(initial_state, opts \\ []) do
    quote do
      Process.flag(:trap_exit, unquote(opts[:trap_exit] || false))

      state =
        Map.merge(unquote(initial_state), %{
          started_at: DateTime.utc_now(),
          last_activity: DateTime.utc_now(),
          error_count: 0,
          processed_count: 0
        })

      # Schedule recurring tasks if configured
      if interval = unquote(opts[:recurring_interval]) do
        Process.send_after(self(), :recurring_task, interval)
      end

      # Log startup
      Logger.info("Started GenServer",
        module: __MODULE__,
        state_keys: Map.keys(state)
      )

      {:ok, state}
    end
  end

  @doc """
  Common handle_call pattern with metrics
  """
  defmacro handle_call_with_metrics(call_pattern, from_var, state_var, do: block) do
    quote do
      @spec handle_call(term()) :: term()
      def handle_call(unquote(call_pattern), unquote(from_var), unquote(state_var)) do
        start_time = System.monotonic_time(:microsecond)
        result = unquote(block)

        # Update metrics
        duration = System.monotonic_time(:microsecond) - start_time

        updated_state =
          case result do
            {:reply, reply, new_state} ->
              Map.merge(new_state, %{
                last_activity: DateTime.utc_now(),
                processed_count: Map.get(new_state, :processed_count, 0) + 1
              })

            {:reply, reply, new_state, _} ->
              Map.merge(new_state, %{
                last_activity: DateTime.utc_now(),
                processed_count: Map.get(new_state, :processed_count, 0) + 1
              })

            other ->
              other
          end

        # Log slow operations
        # 1 second
        if duration > 1_000_000 do
          Logger.warning("Slow handle_call operation",
            module: __MODULE__,
            call: unquote(call_pattern),
            duration_ms: div(duration, 1000)
          )
        end

        updated_state
      end
    end
  end

  @doc """
  Common error handling pattern
  """
  @spec handle_error(term(), term(), map()) :: term()
  def handle_error(error, state, context \\ %{}) do
    Logger.error("GenServer error occurred",
      module: context[:module] || "unknown",
      error: inspect(error),
      context: context
    )

    updated_state = Map.update(state, :error_count, 1, &(&1 + 1))

    # Check if we should crash
    if updated_state.error_count > Map.get(state, :max_errors, 10) do
      {:stop, {:too_many_errors, updated_state.error_count}, updated_state}
    else
      {:noreply, updated_state}
    end
  end

  @doc """
  Common state query pattern
  """
  @spec handle_state_query(term(), term()) :: term()
  def handle_state_query(query_type, state) do
    case query_type do
      :full -> {:reply, state, state}
      :stats -> {:reply, extract_stats(state), state}
      :health -> {:reply, calculate_health(state), state}
      {:field, field} -> {:reply, Map.get(state, field), state}
      _ -> {:reply, {:error, :unknown_query}, state}
    end
  end

  @doc """
  Common recurring task pattern
  """
  @spec handle_recurring_task(term(), term(), term()) :: term()
  def handle_recurring_task(task_fn, interval, state) do
    # Execute task
    case task_fn.(state) do
      {:ok, new_state} ->
        # Schedule next execution
        Process.send_after(self(), :recurring_task, interval)
        {:noreply, new_state}

      {:error, reason} ->
        # Log error and retry
        Logger.error("Recurring task failed", reason: reason)
        # backoff
        Process.send_after(self(), :recurring_task, interval * 2)
        handle_error(reason, state, %{__context: :recurring_task})
    end
  end

  @doc """
  Common shutdown pattern
  """
  @spec handle_shutdown(term(), term(), any()) :: term()
  def handle_shutdown(reason, state, cleanup_fn \\ nil) do
    Logger.info("GenServer shutting down",
      module: state[:module] || "unknown",
      reason: reason,
      uptime_seconds: calculate_uptime(state)
    )

    # Execute cleanup if provided
    if cleanup_fn do
      try do
        cleanup_fn.(state)
      rescue
        error ->
          Logger.error("Cleanup failed during shutdown", error: inspect(error))
      end
    end

    :ok
  end

  @doc """
  Common health check pattern
  """
  @spec health_check(term(), list()) :: term()
  def health_check(state, checks \\ []) do
    base_health = %{
      status: :healthy,
      uptime_seconds: calculate_uptime(state),
      processed_count: Map.get(state, :processed_count, 0),
      error_count: Map.get(state, :error_count, 0),
      last_activity: Map.get(state, :last_activity)
    }

    # Run additional health checks
    health_results =
      Enum.reduce(checks, base_health, fn check_fn, health ->
        case check_fn.(state) do
          {:ok, check_result} ->
            Map.merge(health, check_result)

          {:error, check_name, reason} ->
            health
            |> Map.put(:status, :unhealthy)
            |> Map.update(:failed_checks, [{check_name, reason}], &[{check_name, reason} | &1])
        end
      end)

    health_results
  end

  @doc """
  Two-Key Turn confirmation validation pattern (DRY extraction).

  Used by Dashboard and ShadowMode for authorization/promotion confirmation.

  ## Parameters
  - pending_item: The pending authorization/promotion record with :expires_at and :confirmation_code
  - confirmation_code: The code provided by the user
  - opts: Options including :not_found_error (default :not_found)

  ## Returns
  - {:ok, :confirmed} if validation passes
  - {:error, :not_found} if pending_item is nil
  - {:error, :expired} if confirmation has expired
  - {:error, :invalid_code} if code doesn't match
  """
  @spec validate_two_key_confirmation(map() | nil, String.t(), keyword()) ::
          {:ok, :confirmed} | {:error, :not_found | :expired | :invalid_code}
  def validate_two_key_confirmation(pending_item, confirmation_code, opts \\ []) do
    not_found_error = Keyword.get(opts, :not_found_error, :not_found)

    case pending_item do
      nil ->
        {:error, not_found_error}

      pending ->
        now = DateTime.utc_now()

        cond do
          DateTime.compare(now, pending.expires_at) == :gt ->
            {:error, :expired}

          pending.confirmation_code != confirmation_code ->
            {:error, :invalid_code}

          true ->
            {:ok, :confirmed}
        end
    end
  end

  # Private helpers

  defp extract_stats(state) do
    %{
      started_at: Map.get(state, :started_at),
      last_activity: Map.get(state, :last_activity),
      processed_count: Map.get(state, :processed_count, 0),
      error_count: Map.get(state, :error_count, 0),
      uptime_seconds: calculate_uptime(state)
    }
  end

  defp calculate_health(state) do
    error_rate =
      case Map.get(state, :processed_count, 0) do
        0 -> 0
        count -> Map.get(state, :error_count, 0) / count
      end

    status =
      cond do
        error_rate > 0.1 -> :unhealthy
        error_rate > 0.05 -> :degraded
        true -> :healthy
      end

    %{
      status: status,
      error_rate: Float.round(error_rate, 4),
      uptime_seconds: calculate_uptime(state)
    }
  end

  defp calculate_uptime(state) do
    case Map.get(state, :started_at) do
      nil -> 0
      started_at -> DateTime.diff(DateTime.utc_now(), started_at)
    end
  end
end
