defmodule Indrajaal.Observability.AdaptiveLogger do
  @moduledoc """
  Adaptive Logger - Context-Aware Logging with Intelligent Filtering

  WHAT: Provides logging functions that respect DirectedTelescopeController
        context and automatically filter based on execution environment.

  WHY: Implements SC-OBS-DT-002 and SC-OBS-DT-007 to ensure test output
       visibility while maintaining full observability in production.

  DESIGN:
    - Consults DirectedTelescopeController for current context
    - Filters logs below threshold for non-critical sources
    - Always allows critical sources (Guardian, Sentinel, etc.)
    - Implements exponential backoff for repeated messages
    - Tracks log volume and provides throttling

  STAMP Constraints:
    - SC-OBS-DT-002: Log level MUST adapt to context
    - SC-OBS-DT-007: Log noise < 1000 lines for unit test run
    - SC-OBS-DT-008: Test output visibility > 90%

  Usage:
    # Instead of Logger.info(...), use:
    AdaptiveLogger.info("Watchdog", "Heartbeat check", %{target: pid})

    # For critical logs that always emit:
    AdaptiveLogger.critical("Guardian", "Veto triggered", %{reason: :safety})
  """

  require Logger
  alias Indrajaal.Observability.DirectedTelescopeController

  # Messages seen recently for deduplication
  @dedup_window_ms 5_000

  # Maximum logs per source per second
  @rate_limit_per_source 10

  # ETS table for tracking
  @ets_table :adaptive_logger_state

  # Critical sources that bypass all filtering
  @critical_sources [
    "Guardian",
    "Constitutional",
    "ImmutableRegister",
    "Sentinel",
    "FPPS",
    "FounderDirective",
    "SIL4",
    "Emergency"
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc "Initialize the adaptive logger (call once at application start)"
  def init do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set])
    end

    :ok
  end

  @doc "Log at debug level with adaptive filtering"
  def debug(source, message, context \\ %{}) do
    log(:debug, source, message, context)
  end

  @doc "Log at info level with adaptive filtering"
  def info(source, message, context \\ %{}) do
    log(:info, source, message, context)
  end

  @doc "Log at warning level with adaptive filtering"
  def warning(source, message, context \\ %{}) do
    log(:warning, source, message, context)
  end

  @doc "Log at error level with adaptive filtering"
  def error(source, message, context \\ %{}) do
    log(:error, source, message, context)
  end

  @doc "Log critical message (always emits, bypasses all filtering)"
  def critical(source, message, context \\ %{}) do
    emit_log(:error, source, message, context, force: true)
  end

  @doc "Check if logging would be emitted for source at level"
  def would_log?(source, level) do
    cond do
      source in @critical_sources -> true
      rate_limited?(source) -> false
      deduplicated?(source, level) -> false
      true -> should_emit?(source, level)
    end
  end

  @doc "Get logging statistics"
  def stats do
    if :ets.whereis(@ets_table) != :undefined do
      :ets.tab2list(@ets_table)
      |> Enum.reduce(%{}, fn
        {{:count, source}, count}, acc ->
          Map.update(acc, :counts, %{source => count}, &Map.put(&1, source, count))

        {{:last_seen, source, _hash}, _timestamp}, acc ->
          Map.update(acc, :last_seen, [source], &[source | &1])

        {{:suppressed, source}, count}, acc ->
          Map.update(acc, :suppressed, %{source => count}, &Map.put(&1, source, count))

        _, acc ->
          acc
      end)
    else
      %{}
    end
  end

  @doc "Reset all statistics and rate limiting"
  def reset do
    if :ets.whereis(@ets_table) != :undefined do
      :ets.delete_all_objects(@ets_table)
    end

    :ok
  end

  # ============================================================================
  # Internal Logging Logic
  # ============================================================================

  defp log(level, source, message, context) do
    cond do
      # Critical sources always log
      source in @critical_sources ->
        emit_log(level, source, message, context, force: true)

      # Check rate limiting
      rate_limited?(source) ->
        record_suppressed(source)
        :suppressed

      # Check deduplication
      deduplicated?(source, level, message) ->
        :deduplicated

      # Check if level meets threshold
      should_emit?(source, level) ->
        record_log(source, level, message)
        emit_log(level, source, message, context)

      true ->
        :filtered
    end
  end

  defp should_emit?(source, level) do
    try do
      DirectedTelescopeController.should_log?(source, level)
    rescue
      _ -> level_value(level) >= level_value(:info)
    catch
      :exit, _ -> level_value(level) >= level_value(:info)
    end
  end

  defp emit_log(level, source, message, context, opts \\ []) do
    force = Keyword.get(opts, :force, false)

    # Format the message
    formatted =
      if force do
        "[#{source}] #{message}"
      else
        "[#{source}] #{message}"
      end

    # Add context if present
    full_message =
      if map_size(context) > 0 do
        formatted <> " " <> inspect(context)
      else
        formatted
      end

    # Emit to Logger
    case level do
      :debug -> Logger.debug(full_message)
      :info -> Logger.info(full_message)
      :warning -> Logger.warning(full_message)
      :error -> Logger.error(full_message)
    end

    :ok
  end

  # ============================================================================
  # Rate Limiting
  # ============================================================================

  defp rate_limited?(source) do
    if :ets.whereis(@ets_table) == :undefined do
      false
    else
      now = System.monotonic_time(:millisecond)
      key = {:rate, source}

      case :ets.lookup(@ets_table, key) do
        [{^key, count, window_start}] when now - window_start < 1000 ->
          if count >= @rate_limit_per_source do
            true
          else
            :ets.update_counter(@ets_table, key, {2, 1})
            false
          end

        _ ->
          :ets.insert(@ets_table, {key, 1, now})
          false
      end
    end
  end

  defp record_suppressed(source) do
    if :ets.whereis(@ets_table) != :undefined do
      key = {:suppressed, source}

      case :ets.lookup(@ets_table, key) do
        [{^key, _count}] ->
          :ets.update_counter(@ets_table, key, {2, 1})

        [] ->
          :ets.insert(@ets_table, {key, 1})
      end
    end
  end

  # ============================================================================
  # Deduplication
  # ============================================================================

  defp deduplicated?(source, level, message \\ "") do
    if :ets.whereis(@ets_table) == :undefined do
      false
    else
      now = System.monotonic_time(:millisecond)
      hash = :erlang.phash2({level, message})
      key = {:last_seen, source, hash}

      case :ets.lookup(@ets_table, key) do
        [{^key, last_time}] when now - last_time < @dedup_window_ms ->
          true

        _ ->
          false
      end
    end
  end

  defp record_log(source, level, message) do
    if :ets.whereis(@ets_table) != :undefined do
      now = System.monotonic_time(:millisecond)
      hash = :erlang.phash2({level, message})

      # Record last seen
      :ets.insert(@ets_table, {{:last_seen, source, hash}, now})

      # Increment count
      count_key = {:count, source}

      case :ets.lookup(@ets_table, count_key) do
        [{^count_key, _}] ->
          :ets.update_counter(@ets_table, count_key, {2, 1})

        [] ->
          :ets.insert(@ets_table, {count_key, 1})
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp level_value(:debug), do: 0
  defp level_value(:info), do: 1
  defp level_value(:warning), do: 2
  defp level_value(:warn), do: 2
  defp level_value(:error), do: 3
  defp level_value(_), do: 1
end
