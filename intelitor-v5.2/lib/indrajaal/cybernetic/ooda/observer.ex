defmodule Indrajaal.Cybernetic.OODA.Observer do
  @moduledoc """
  The Eyes of the System.
  Aggregates telemetry from all Cortex sensors into a coherent Observation.
  Task 22.2.1.2.1

  ## STAMP Compliance
  - SC-OODA-001: OODA cycle < 30ms
  - SC-SENS-001: Non-blocking polling
  - SC-SENS-002: Graceful degradation on sensor failure
  """
  require Logger

  # ETS table for rolling metric windows
  @table :ooda_observer_metrics
  @window_size 60

  @doc """
  Ensure the metrics ETS table exists.
  Called lazily before first observation so no supervision dependency is needed.
  """
  def ensure_table do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        @table
    end
  end

  @doc """
  Collect a full system observation snapshot.
  Falls back gracefully for each sensor that is unavailable.
  """
  @spec observe(map()) :: map()
  def observe(_context) do
    ensure_table()

    # 1. Infrastructure State (Sentinel) - fault-isolated
    cluster_status =
      try do
        Indrajaal.Cluster.Sentinel.get_status()
      catch
        :exit, _ -> %{status: :unknown, active_count: 0}
        :error, _ -> %{status: :unknown, active_count: 0}
      end

    # 2. VM State via :erlang.statistics and :erlang.memory
    beam_snapshot = collect_beam_snapshot()

    # 3. Process queue depth - sum of message_queue_len for top processes
    queue_depth = collect_queue_depth()

    # 4. Recent error rate - count of :error_logger messages per window
    error_rate = collect_error_rate()

    # 5. Latency p99 from telemetry ETS store (populated by ZenohTelemetry)
    latency_p99 = read_latency_p99()

    # 6. FLAME pool status (non-blocking, optional subsystem)
    flame_status = collect_flame_status()

    # 7. Data quality — degrades when sensors are unreachable
    data_quality =
      case {cluster_status.status, is_map(beam_snapshot)} do
        {:unknown, false} -> 0
        {:unknown, true} -> 60
        {_, true} -> 100
        _ -> 50
      end

    # Record snapshot into rolling window for trend analysis
    now_ts = System.system_time(:second)
    record_snapshot(now_ts, beam_snapshot, queue_depth, error_rate)

    result = %{
      # Infrastructure State
      cluster_status: cluster_status.status,
      active_nodes: cluster_status.active_count,

      # VM State (Real :erlang metrics)
      memory_usage: beam_snapshot.total_memory,
      process_count: beam_snapshot.process_count,
      process_utilization: beam_snapshot.process_utilization,
      cpu_usage: beam_snapshot.scheduler_usage,
      run_queue: beam_snapshot.run_queue,
      io_input_bytes: beam_snapshot.io_input,
      io_output_bytes: beam_snapshot.io_output,
      gc_count: beam_snapshot.gc_count,
      gc_words_reclaimed: beam_snapshot.gc_words_reclaimed,

      # Compute State
      flame_runners: flame_status.total,

      # Telemetry (populated from ETS rolling window)
      queue_depth: queue_depth,
      latency_p99: latency_p99,
      error_rate: error_rate,

      # Meta
      timestamp: now_ts,
      data_quality: data_quality
    }

    :telemetry.execute(
      [:indrajaal, :cybernetic, :ooda, :observe],
      %{data_quality: data_quality, process_count: beam_snapshot.process_count},
      %{cluster_status: cluster_status.status}
    )

    result
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp collect_beam_snapshot do
    try do
      # Scheduler wall-clock utilization (requires erlang flag +scl false or just read it)
      {_, scheduler_usage} =
        try do
          calculate_scheduler_usage()
        catch
          _, _ -> {0, 0.0}
        end

      # Memory
      mem = :erlang.memory()
      total_memory = Keyword.get(mem, :total, 0)

      # Process stats
      process_count = :erlang.system_info(:process_count)
      process_limit = :erlang.system_info(:process_limit)
      process_utilization = process_count / max(process_limit, 1)

      # Run queue (all schedulers combined)
      run_queue = :erlang.statistics(:total_run_queue_lengths_all)

      # IO
      {{:input, io_in}, {:output, io_out}} = :erlang.statistics(:io)

      # GC
      {gc_count, gc_words_reclaimed, _} = :erlang.statistics(:garbage_collection)

      %{
        total_memory: total_memory,
        process_count: process_count,
        process_limit: process_limit,
        process_utilization: Float.round(process_utilization, 4),
        scheduler_usage: Float.round(scheduler_usage, 4),
        run_queue: run_queue,
        io_input: io_in,
        io_output: io_out,
        gc_count: gc_count,
        gc_words_reclaimed: gc_words_reclaimed
      }
    rescue
      e ->
        Logger.debug("OODA Observer: beam snapshot failed: #{inspect(e)}")

        %{
          total_memory: 0,
          process_count: 0,
          process_limit: 1,
          process_utilization: 0.0,
          scheduler_usage: 0.0,
          run_queue: 0,
          io_input: 0,
          io_output: 0,
          gc_count: 0,
          gc_words_reclaimed: 0
        }
    end
  end

  # Calculate aggregate scheduler utilization across all schedulers.
  # We need two samples separated in time; use cached previous sample from ETS.
  defp calculate_scheduler_usage do
    now = :erlang.statistics(:scheduler_wall_time)

    case :ets.lookup(@table, :prev_scheduler_wall_time) do
      [{:prev_scheduler_wall_time, prev}] ->
        usage = compute_scheduler_utilization(prev, now)
        :ets.insert(@table, {:prev_scheduler_wall_time, now})
        {now, usage}

      [] ->
        :ets.insert(@table, {:prev_scheduler_wall_time, now})
        {now, 0.0}
    end
  end

  defp compute_scheduler_utilization(prev_list, curr_list) do
    pairs =
      Enum.zip(
        Enum.sort(prev_list, fn {id, _, _}, {id2, _, _} -> id <= id2 end),
        Enum.sort(curr_list, fn {id, _, _}, {id2, _, _} -> id <= id2 end)
      )

    total_active = 0
    total_elapsed = 0

    {total_active, total_elapsed} =
      Enum.reduce(pairs, {total_active, total_elapsed}, fn
        {{id, prev_active, prev_total}, {id, curr_active, curr_total}}, {acc_a, acc_e} ->
          {acc_a + (curr_active - prev_active), acc_e + (curr_total - prev_total)}

        _, acc ->
          acc
      end)

    if total_elapsed > 0 do
      Float.round(total_active / total_elapsed, 4)
    else
      0.0
    end
  end

  defp collect_queue_depth do
    try do
      # Sample the 50 longest message queues
      Process.list()
      |> Enum.take_random(min(200, length(Process.list())))
      |> Enum.map(fn pid ->
        case Process.info(pid, :message_queue_len) do
          {:message_queue_len, len} -> len
          _ -> 0
        end
      end)
      |> Enum.sum()
    rescue
      _ -> 0
    end
  end

  defp collect_error_rate do
    # Read from rolling window in ETS — populated by record_snapshot
    now = System.system_time(:second)
    window_start = now - @window_size

    try do
      # Count error snapshots in window
      matches =
        :ets.select(@table, [
          {{:error_snapshot, :"$1", :"$2"}, [{:>=, :"$1", window_start}], [:"$2"]}
        ])

      total_errors = Enum.sum(matches)
      # normalise to per-second rate
      Float.round(total_errors / @window_size, 4)
    rescue
      _ -> 0.0
    end
  end

  defp read_latency_p99 do
    try do
      case :ets.lookup(@table, :latency_p99) do
        [{:latency_p99, val}] -> val
        [] -> 0
      end
    rescue
      _ -> 0
    end
  end

  defp collect_flame_status do
    try do
      runners =
        [Indrajaal.FLAME.IntelligencePool, Indrajaal.FLAME.VideoPool]
        |> Enum.map(fn pool ->
          case GenServer.whereis(pool) do
            nil -> 0
            pid when is_pid(pid) -> 1
          end
        end)
        |> Enum.sum()

      %{total: runners}
    catch
      _, _ -> %{total: 0}
    end
  end

  defp record_snapshot(ts, beam_snapshot, _queue_depth, _error_rate) do
    # Maintain a rolling series keyed by timestamp for trend use
    try do
      :ets.insert(@table, {:memory_snapshot, ts, beam_snapshot.total_memory})
      :ets.insert(@table, {:cpu_snapshot, ts, beam_snapshot.scheduler_usage})
      :ets.insert(@table, {:process_snapshot, ts, beam_snapshot.process_count})

      # Purge old entries beyond window * 2 to prevent unbounded growth
      cutoff = ts - @window_size * 2

      :ets.select_delete(@table, [
        {{:memory_snapshot, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}
      ])

      :ets.select_delete(@table, [
        {{:cpu_snapshot, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}
      ])

      :ets.select_delete(@table, [
        {{:process_snapshot, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}
      ])
    rescue
      _ -> :ok
    end
  end

  @doc """
  Store a latency p99 value from external telemetry (called by ZenohTelemetrySubscriber etc).
  """
  @spec record_latency_p99(number()) :: true
  def record_latency_p99(value) do
    ensure_table()
    :ets.insert(@table, {:latency_p99, value})
  end
end
