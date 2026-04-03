defmodule Indrajaal.Cockpit.Prajna.CircuitBreaker do
  @moduledoc """
  PRAJNA Circuit Breaker for Message Storm Protection

  WHAT: Prevents UI freeze during message storms by implementing
        load shedding based on queue depth and message priority.

  WHY: Based on NASA "Power of 10" rules for safety-critical systems:
       - Prevents unbounded queue growth
       - Maintains UI responsiveness under load
       - Prioritizes critical alarms over telemetry

  CONSTRAINTS:
    - SC-CIRCUIT-001: Drop telemetry when queue > 100 messages
    - SC-CIRCUIT-002: Log all dropped messages for post-mortem
    - SC-NASA-001: No unbounded loops
    - SC-PRF-050: Maintain < 50ms response time

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | Reference | NASA Power of 10, ISA-101 |
  """

  require Logger

  # SC-CIRCUIT-001: Queue thresholds
  @telemetry_threshold 100
  @critical_threshold 200
  @emergency_threshold 500

  # Message priorities (higher = more important)
  @priority_levels %{
    emergency: 100,
    alarm: 80,
    warning: 60,
    command: 50,
    insight: 40,
    metric: 20,
    telemetry: 10,
    debug: 0
  }

  @type message_type ::
          :emergency
          | :alarm
          | :warning
          | :command
          | :insight
          | :metric
          | :telemetry
          | :debug

  @type decision :: :process | :drop | :defer

  @doc """
  Determine if a message should be processed based on queue depth.

  Returns:
    - :process - Message should be processed immediately
    - :drop - Message should be dropped (logged per SC-CIRCUIT-002)
    - :defer - Message should be deferred for later processing

  ## Examples

      iex> CircuitBreaker.should_process?(50, :alarm)
      :process

      iex> CircuitBreaker.should_process?(150, :telemetry)
      :drop
  """
  @spec should_process?(non_neg_integer(), message_type()) :: decision()
  def should_process?(queue_length, message_type) do
    priority = Map.get(@priority_levels, message_type, 0)

    cond do
      # Emergency mode: only process emergency messages
      queue_length > @emergency_threshold ->
        if message_type == :emergency do
          :process
        else
          log_dropped(queue_length, message_type, :emergency_mode)
          :drop
        end

      # Critical mode: only process alarms and above
      queue_length > @critical_threshold ->
        if priority >= @priority_levels.alarm do
          :process
        else
          log_dropped(queue_length, message_type, :critical_mode)
          :drop
        end

      # Normal load shedding: drop low-priority telemetry
      queue_length > @telemetry_threshold ->
        if priority > @priority_levels.telemetry do
          :process
        else
          log_dropped(queue_length, message_type, :load_shedding)
          :drop
        end

      # Normal operation
      true ->
        :process
    end
  end

  @doc """
  Get the current circuit breaker state based on queue depth.

  Returns one of:
    - :closed (normal operation)
    - :half_open (load shedding active)
    - :open (critical mode)
    - :tripped (emergency mode)
  """
  @spec state(non_neg_integer()) :: :closed | :half_open | :open | :tripped
  def state(queue_length) do
    cond do
      queue_length > @emergency_threshold -> :tripped
      queue_length > @critical_threshold -> :open
      queue_length > @telemetry_threshold -> :half_open
      true -> :closed
    end
  end

  @doc """
  Get statistics about message processing decisions.
  Used for monitoring and tuning thresholds.
  """
  @spec get_stats() :: map()
  def get_stats do
    # Would typically pull from ETS/persistent store
    %{
      telemetry_threshold: @telemetry_threshold,
      critical_threshold: @critical_threshold,
      emergency_threshold: @emergency_threshold,
      priority_levels: @priority_levels
    }
  end

  @doc """
  Filter a batch of messages, returning only those that should be processed.
  More efficient than calling should_process?/2 individually.
  """
  @spec filter_batch(list({message_type(), term()}), non_neg_integer()) ::
          {list(term()), non_neg_integer()}
  def filter_batch(messages, queue_length) do
    state = state(queue_length)
    min_priority = minimum_priority_for_state(state)

    {processed, dropped} =
      Enum.reduce(messages, {[], 0}, fn {type, msg}, {acc, dropped_count} ->
        priority = Map.get(@priority_levels, type, 0)

        if priority >= min_priority do
          {[msg | acc], dropped_count}
        else
          {acc, dropped_count + 1}
        end
      end)

    if dropped > 0 do
      Logger.warning("[CircuitBreaker] Batch filter dropped #{dropped} messages, state=#{state}")
    end

    {Enum.reverse(processed), dropped}
  end

  # Private helpers

  defp minimum_priority_for_state(:closed), do: 0
  defp minimum_priority_for_state(:half_open), do: @priority_levels.metric
  defp minimum_priority_for_state(:open), do: @priority_levels.alarm
  defp minimum_priority_for_state(:tripped), do: @priority_levels.emergency

  # SC-CIRCUIT-002: Log all dropped messages
  defp log_dropped(queue_length, message_type, reason) do
    Logger.warning(
      "[CircuitBreaker] Dropped #{message_type} message, " <>
        "queue=#{queue_length}, reason=#{reason}"
    )
  end
end
