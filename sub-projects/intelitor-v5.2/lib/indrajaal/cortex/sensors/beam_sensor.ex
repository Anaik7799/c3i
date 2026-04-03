defmodule Indrajaal.Cortex.Sensors.BeamSensor do
  @moduledoc """
  Sensor for monitoring the Erlang VM (BEAM).
  Collects metrics such as memory usage, process count, and scheduler utilization.
  Task 22.4.1.1.2
  """
  require Logger

  @doc """
  Collects a snapshot of BEAM metrics.
  Returns a map of measurements.
  """
  def take_snapshot do
    # Memory metrics (bytes)
    memory = :erlang.memory()
    total_memory = memory[:total]
    processes_memory = memory[:processes]
    atom_memory = memory[:atom]

    # Process metrics
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)

    # Scheduler metrics
    scheduler_usage = get_scheduler_usage()

    %{
      total_memory: total_memory,
      process_count: process_count,
      process_utilization: Float.round(process_count / process_limit, 4),
      scheduler_usage: scheduler_usage,
      atom_memory: atom_memory,
      processes_memory: processes_memory,
      timestamp: System.system_time(:millisecond)
    }
  end

  # Returns average scheduler utilization as a float 0.0-1.0.
  # Uses `:erlang.statistics(:scheduler_wall_time_all)` with delta-based
  # computation. First call stores baseline and returns 0.0; subsequent
  # calls compute (active_delta / total_delta) per scheduler, averaged.
  defp get_scheduler_usage do
    try do
      # Ensure scheduler wall time collection is enabled
      :erlang.system_flag(:scheduler_wall_time, true)

      case :erlang.statistics(:scheduler_wall_time_all) do
        :undefined ->
          0.0

        current when is_list(current) ->
          case Process.get(:beam_sensor_prev_wall_time) do
            nil ->
              # First sample — store baseline, return 0.0
              Process.put(:beam_sensor_prev_wall_time, current)
              0.0

            prev when is_list(prev) ->
              # Compute delta between samples
              usage = compute_scheduler_delta(prev, current)
              Process.put(:beam_sensor_prev_wall_time, current)
              Float.round(usage, 4)
          end
      end
    rescue
      _ -> 0.0
    end
  end

  defp compute_scheduler_delta(prev, current) do
    # Build map of previous values keyed by scheduler id
    prev_map = Map.new(prev, fn {id, active, total} -> {id, {active, total}} end)

    deltas =
      Enum.flat_map(current, fn {id, active, total} ->
        case Map.get(prev_map, id) do
          {prev_active, prev_total} ->
            dt = total - prev_total
            da = active - prev_active

            if dt > 0 do
              [da / dt]
            else
              []
            end

          nil ->
            []
        end
      end)

    if length(deltas) > 0 do
      Enum.sum(deltas) / length(deltas)
    else
      0.0
    end
  end
end
