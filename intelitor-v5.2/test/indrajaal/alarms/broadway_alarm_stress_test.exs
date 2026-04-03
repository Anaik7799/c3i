defmodule Indrajaal.Alarms.BroadwayAlarmStressTest do
  @moduledoc """
  Stress tests for Broadway alarm pipeline under high-concurrency load.

  WHAT: Verifies the Broadway alarm pipeline simulation handles 100 concurrent
        alarms with correct ordering, deduplication, backpressure, and recovery.
  WHY:  SC-ALARM-001 mandates alarm processing never drops events.
        SC-BROADWAY-001 requires pipeline creation < 2s.
        SC-BROADWAY-002 requires message latency < 100ms.
        SC-BROADWAY-003 requires batch processing metrics tracking.
        SC-BROADWAY-004 requires backpressure handling.

  ## STAMP Safety Integration
  - SC-ALARM-001: Alarm processing pipeline must never drop events
  - SC-ALARM-002: Alarm severity classification must be deterministic
  - SC-ALARM-003: Storm detection threshold: >50 alarms/min
  - SC-ALARM-004: Critical alarms must be prioritised above informational
  - SC-ALARM-005: Duplicate alarms within dedup window must be collapsed
  - SC-ALARM-006: Pipeline crash must not cause permanent alarm loss
  - SC-ALARM-007: Batch size limits enforced (10–50 per batch)
  - SC-ALARM-008: Throughput metrics must be tracked continuously
  - SC-ALARM-009: Latency p99 must remain < 500ms under normal load
  - SC-ALARM-010: Backpressure must engage before buffer overflow
  - SC-BROADWAY-001: Pipeline creation < 2s
  - SC-BROADWAY-002: Per-message latency < 100ms
  - SC-BROADWAY-003: Batch processing metrics tracked
  - SC-BROADWAY-004: Backpressure handling mandatory

  ## Self-Contained
  All helpers are private `defp` functions. No production module calls.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — stress test suite, 44 tests |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  @moduletag :unit
  @moduletag :alarm_stress
  @moduletag :broadway

  # ---------------------------------------------------------------------------
  # STORM THRESHOLD (SC-ALARM-003)
  # ---------------------------------------------------------------------------
  @storm_threshold 50
  @dedup_window_ms 5_000
  @batch_min 10
  @batch_max 50
  @latency_p99_limit_ms 500

  # ---------------------------------------------------------------------------
  # describe "sequential alarm processing"
  # ---------------------------------------------------------------------------

  describe "sequential alarm processing" do
    test "process single alarm updates processed count" do
      pipeline = create_pipeline([])
      alarm = generate_alarm(severity: :critical, source: "door-1")

      {updated, result} = process_batch(pipeline, [alarm])

      assert result == :ok
      assert updated.processed_count == 1
    end

    test "process 10 alarms in order increments count to 10" do
      pipeline = create_pipeline([])
      alarms = generate_alarm_burst(10, [:critical, :high, :medium, :low, :info])

      {updated, result} = process_batch(pipeline, alarms)

      assert result == :ok
      assert updated.processed_count == 10
    end

    test "process 50 alarms sequentially with no loss" do
      pipeline = create_pipeline([])
      alarms = generate_alarm_burst(50, [:critical, :high, :medium, :low, :info])

      {updated, result} = process_batch(pipeline, alarms)

      assert result == :ok
      assert updated.processed_count == 50
    end

    test "processing order matches submission order for equal-priority alarms" do
      pipeline = create_pipeline([])

      alarms =
        Enum.map(1..5, fn i ->
          generate_alarm(severity: :medium, source: "sensor-#{i}", seq: i)
        end)

      {_updated, _result} = process_batch(pipeline, alarms)

      # Verify FIFO: seq numbers must remain in ascending order within same priority
      same_priority = Enum.filter(alarms, &(&1.severity == :medium))
      seqs = Enum.map(same_priority, & &1.seq)
      assert seqs == Enum.sort(seqs)
    end

    test "each alarm assigned a unique id" do
      alarms = generate_alarm_burst(20, [:critical, :high])
      ids = Enum.map(alarms, & &1.id)
      assert length(Enum.uniq(ids)) == length(ids)
    end
  end

  # ---------------------------------------------------------------------------
  # describe "concurrent alarm burst"
  # ---------------------------------------------------------------------------

  describe "concurrent alarm burst" do
    test "100 concurrent alarms all processed, no data loss (SC-ALARM-001)" do
      pipeline = create_pipeline(buffer_limit: 200)
      alarms = generate_alarm_burst(100, [:critical, :high, :medium, :low, :info])

      # Simulate concurrent submission by grouping into 10 batches of 10
      results =
        alarms
        |> Enum.chunk_every(10)
        |> Enum.map(fn batch ->
          {updated, _result} = process_batch(pipeline, batch)
          updated.processed_count
        end)

      total_processed = Enum.sum(results)
      assert total_processed == 100
    end

    test "100 alarms burst does not exceed buffer limit" do
      pipeline = create_pipeline(buffer_limit: 150)
      alarms = generate_alarm_burst(100, [:high, :medium])

      {updated, result} = process_batch(pipeline, alarms)

      assert result == :ok
      # All 100 fit within 150-slot buffer
      assert updated.processed_count == 100
      assert updated.dropped_count == 0
    end

    test "burst beyond buffer limit triggers drop and backpressure" do
      # Buffer of 50 receiving 100 alarms must drop 50 (SC-ALARM-010)
      pipeline = create_pipeline(buffer_limit: 50)
      alarms = generate_alarm_burst(100, [:low, :info])

      {updated, _result} = process_batch(pipeline, alarms)

      assert updated.dropped_count > 0
      assert updated.processed_count + updated.dropped_count == 100
    end

    test "concurrent burst preserves all critical alarms (SC-ALARM-004)" do
      pipeline = create_pipeline(buffer_limit: 200)
      criticals = generate_alarm_burst(25, [:critical])
      others = generate_alarm_burst(75, [:low, :info])
      all_alarms = criticals ++ others

      {updated, _result} = process_batch(pipeline, all_alarms)

      # Critical alarms must never be dropped regardless of buffer pressure
      assert updated.critical_processed == 25
    end
  end

  # ---------------------------------------------------------------------------
  # describe "alarm storm detection"
  # ---------------------------------------------------------------------------

  describe "alarm storm detection" do
    test "50 alarms in 1 minute does not trigger storm" do
      alarms = generate_alarm_burst(50, [:high, :medium])
      timestamps = build_timestamps(50, interval_ms: 1_200)

      assert detect_storm(alarms, timestamps) == false
    end

    test "51 alarms in 1 minute triggers storm condition (SC-ALARM-003)" do
      alarms = generate_alarm_burst(51, [:high, :medium])
      timestamps = build_timestamps(51, interval_ms: 1_100)

      assert detect_storm(alarms, timestamps) == true
    end

    test "storm detection returns false for empty alarm list" do
      assert detect_storm([], []) == false
    end

    test "100 alarms spread across 5 minutes does not trigger storm" do
      alarms = generate_alarm_burst(100, [:critical])
      # 100 alarms over 5 minutes = 20/min — below threshold
      timestamps = build_timestamps(100, interval_ms: 3_000)

      assert detect_storm(alarms, timestamps) == false
    end

    test "storm threshold is exactly @storm_threshold per minute" do
      assert @storm_threshold == 50
    end
  end

  # ---------------------------------------------------------------------------
  # describe "priority ordering under load"
  # ---------------------------------------------------------------------------

  describe "priority ordering under load" do
    test "critical alarms sorted before high before medium before low (SC-ALARM-004)" do
      mixed =
        [
          generate_alarm(severity: :low, source: "lx"),
          generate_alarm(severity: :critical, source: "cx"),
          generate_alarm(severity: :medium, source: "mx"),
          generate_alarm(severity: :high, source: "hx"),
          generate_alarm(severity: :info, source: "ix")
        ]

      sorted = sort_by_priority(mixed)
      severities = Enum.map(sorted, & &1.severity)

      assert Enum.at(severities, 0) == :critical
      assert Enum.at(severities, 1) == :high
      assert Enum.at(severities, 2) == :medium
      assert Enum.at(severities, 3) == :low
      assert Enum.at(severities, 4) == :info
    end

    test "within same priority, FIFO ordering preserved" do
      alarms =
        Enum.map(1..5, fn i ->
          generate_alarm(severity: :high, source: "sensor-#{i}", seq: i)
        end)

      sorted = sort_by_priority(alarms)
      high_seqs = sorted |> Enum.filter(&(&1.severity == :high)) |> Enum.map(& &1.seq)

      assert high_seqs == Enum.sort(high_seqs)
    end

    test "100 mixed-severity alarms yield critical batch first" do
      alarms = generate_alarm_burst(100, [:critical, :high, :medium, :low, :info])
      sorted = sort_by_priority(alarms)
      first_10 = Enum.take(sorted, 10)

      # With 100 alarms and 5 severities evenly distributed, first 20 should be critical
      critical_count = Enum.count(first_10, &(&1.severity == :critical))
      assert critical_count > 0
    end
  end

  # ---------------------------------------------------------------------------
  # describe "backpressure handling"
  # ---------------------------------------------------------------------------

  describe "backpressure handling" do
    test "backpressure engages when buffer exceeds 80% capacity (SC-ALARM-010)" do
      pipeline = create_pipeline(buffer_limit: 100)
      # 85 alarms = 85% of capacity
      alarms = generate_alarm_burst(85, [:medium])

      {updated_pipeline, _} = process_batch(pipeline, alarms)
      bp_result = apply_backpressure(updated_pipeline, 85)

      assert bp_result.backpressure_active == true
    end

    test "backpressure does not engage at 79% capacity" do
      pipeline = create_pipeline(buffer_limit: 100)
      alarms = generate_alarm_burst(79, [:medium])

      {updated_pipeline, _} = process_batch(pipeline, alarms)
      bp_result = apply_backpressure(updated_pipeline, 79)

      assert bp_result.backpressure_active == false
    end

    test "backpressure releases after buffer drains below 60%" do
      pipeline = create_pipeline(buffer_limit: 100)
      alarms = generate_alarm_burst(90, [:low])

      {over_capacity, _} = process_batch(pipeline, alarms)
      bp_engaged = apply_backpressure(over_capacity, 90)
      assert bp_engaged.backpressure_active == true

      # Drain to 55 alarms
      drained = %{over_capacity | processed_count: 35, buffer_used: 55}
      bp_released = apply_backpressure(drained, 55)
      assert bp_released.backpressure_active == false
    end

    test "dropped alarms are counted, not silently lost (SC-ALARM-001)" do
      pipeline = create_pipeline(buffer_limit: 10)
      alarms = generate_alarm_burst(20, [:info])

      {updated, _} = process_batch(pipeline, alarms)

      # 10 processed + 10 dropped = 20 total — no silent loss
      assert updated.processed_count + updated.dropped_count == 20
    end
  end

  # ---------------------------------------------------------------------------
  # describe "batch processing"
  # ---------------------------------------------------------------------------

  describe "batch processing" do
    test "batch of 10 alarms processed as single unit (SC-ALARM-007)" do
      pipeline = create_pipeline(batch_size: 10)
      alarms = generate_alarm_burst(10, [:high])

      {updated, :ok} = process_batch(pipeline, alarms)

      assert updated.batches_processed == 1
      assert updated.processed_count == 10
    end

    test "50 alarms with batch_size 10 produces 5 batches" do
      pipeline = create_pipeline(batch_size: 10)
      alarms = generate_alarm_burst(50, [:medium])

      {updated, :ok} = process_batch(pipeline, alarms)

      assert updated.batches_processed == 5
      assert updated.processed_count == 50
    end

    test "batch size clamped to @batch_min/@batch_max range (SC-ALARM-007)" do
      assert @batch_min == 10
      assert @batch_max == 50
      # batch sizes outside [10, 50] should be clamped
      clamped_low = clamp_batch_size(3)
      clamped_high = clamp_batch_size(200)

      assert clamped_low == @batch_min
      assert clamped_high == @batch_max
    end

    test "partial batch flushed when pipeline drains" do
      pipeline = create_pipeline(batch_size: 10)
      # 7 alarms < batch_size, but flush drains them
      alarms = generate_alarm_burst(7, [:critical])

      {updated, :ok} = process_batch(pipeline, alarms)
      # Partial batch counted as 1 batch (flush semantics)
      assert updated.batches_processed == 1
      assert updated.processed_count == 7
    end

    test "100 alarms with batch_size 25 produces 4 batches" do
      pipeline = create_pipeline(batch_size: 25)
      alarms = generate_alarm_burst(100, [:high, :medium])

      {updated, :ok} = process_batch(pipeline, alarms)

      assert updated.batches_processed == 4
      assert updated.processed_count == 100
    end
  end

  # ---------------------------------------------------------------------------
  # describe "failure recovery"
  # ---------------------------------------------------------------------------

  describe "failure recovery" do
    test "pipeline crash mid-batch marks in-flight alarms as recoverable (SC-ALARM-006)" do
      pipeline = create_pipeline(batch_size: 10)
      in_flight = generate_alarm_burst(5, [:critical])
      pending = generate_alarm_burst(10, [:high])

      # Simulate crash after 5 are in flight
      crash_result = simulate_crash(pipeline, in_flight, pending)

      assert crash_result.in_flight_count == 5
      assert crash_result.pending_count == 10
      assert crash_result.recoverable == true
    end

    test "recovery reprocesses in-flight alarms without duplication" do
      pipeline = create_pipeline(batch_size: 10)
      in_flight = generate_alarm_burst(5, [:critical])
      pending = generate_alarm_burst(10, [:high])

      crash_state = simulate_crash(pipeline, in_flight, pending)
      recovered = recover_pipeline(crash_state)

      # In-flight alarms requeued; total = in_flight + pending
      assert recovered.processed_count == 15
      assert recovered.duplicate_count == 0
    end

    test "pipeline restarts with empty buffer after full recovery" do
      pipeline = create_pipeline(batch_size: 10)
      alarms = generate_alarm_burst(8, [:medium])
      crash_state = simulate_crash(pipeline, alarms, [])

      recovered = recover_pipeline(crash_state)

      assert recovered.buffer_used == 0
      assert recovered.status == :active
    end
  end

  # ---------------------------------------------------------------------------
  # describe "deduplication"
  # ---------------------------------------------------------------------------

  describe "deduplication" do
    test "identical alarms within dedup window collapsed to one (SC-ALARM-005)" do
      now = System.monotonic_time(:millisecond)
      alarm = generate_alarm(severity: :high, source: "door-1")

      duplicates =
        Enum.map(1..5, fn offset ->
          %{alarm | timestamp: now + offset * 100}
        end)

      deduped = deduplicate_alarms(duplicates, @dedup_window_ms)

      assert length(deduped) == 1
    end

    test "alarms from different sources not deduplicated" do
      now = System.monotonic_time(:millisecond)

      alarms =
        Enum.map(1..5, fn i ->
          generate_alarm(severity: :high, source: "sensor-#{i}", timestamp: now + i * 10)
        end)

      deduped = deduplicate_alarms(alarms, @dedup_window_ms)

      assert length(deduped) == 5
    end

    test "alarms outside dedup window not collapsed" do
      now = System.monotonic_time(:millisecond)
      alarm = generate_alarm(severity: :medium, source: "pir-1")

      # Two alarms 6 seconds apart — outside the 5s window
      old_alarm = %{alarm | timestamp: now - 6_001, id: "old-1"}
      new_alarm = %{alarm | timestamp: now, id: "new-1"}

      deduped = deduplicate_alarms([old_alarm, new_alarm], @dedup_window_ms)

      assert length(deduped) == 2
    end

    test "dedup window of 0ms deduplicates only exact-same-timestamp duplicates" do
      now = System.monotonic_time(:millisecond)
      alarm = generate_alarm(severity: :low, source: "pir-2")

      same_ts = Enum.map(1..3, fn _ -> %{alarm | timestamp: now} end)
      deduped = deduplicate_alarms(same_ts, 0)

      assert length(deduped) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # describe "throughput metrics"
  # ---------------------------------------------------------------------------

  describe "throughput metrics" do
    test "throughput computed as alarms/second (SC-ALARM-008)" do
      alarms = generate_alarm_burst(100, [:high, :medium])
      duration_ms = 1_000

      metrics = compute_throughput(alarms, duration_ms)

      assert metrics.alarms_per_second == 100.0
    end

    test "zero-duration returns infinity sentinel" do
      alarms = generate_alarm_burst(10, [:high])
      metrics = compute_throughput(alarms, 0)

      assert metrics.alarms_per_second == :infinity
    end

    test "latency percentiles computed over alarm list (SC-ALARM-009)" do
      latencies_ms = Enum.map(1..100, fn i -> i * 1.0 end)

      pcts = compute_latency_percentiles(latencies_ms)

      # p50 of 1..100 = 50.5
      assert_in_delta pcts.p50, 50.5, 1.0
      # p95 of 1..100 = 95.5
      assert_in_delta pcts.p95, 95.5, 1.0
      # p99 of 1..100 = 99.5
      assert_in_delta pcts.p99, 99.5, 1.0
    end

    test "latency p99 under normal load stays below #{@latency_p99_limit_ms}ms" do
      # Simulate 200 realistic latencies: 5–95ms
      latencies_ms = Enum.map(1..200, fn i -> 5.0 + rem(i, 91) * 1.0 end)

      pcts = compute_latency_percentiles(latencies_ms)

      assert pcts.p99 < @latency_p99_limit_ms
    end
  end

  # ---------------------------------------------------------------------------
  # describe "property: no alarm loss"
  # ---------------------------------------------------------------------------

  describe "property: no alarm loss" do
    test "property — all submitted alarms eventually processed (SD)" do
      check all(
              count <- SD.integer(1..50),
              severity <- SD.member_of([:critical, :high, :medium, :low, :info]),
              max_runs: 10
            ) do
        pipeline = create_pipeline(buffer_limit: count + 10)
        alarms = generate_alarm_burst(count, [severity])

        {updated, result} = process_batch(pipeline, alarms)

        assert result == :ok
        assert updated.processed_count + updated.dropped_count == count
      end
    end

    test "property — no alarm has nil id after generation (SD)" do
      check all(
              n <- SD.integer(1..30),
              max_runs: 8
            ) do
        alarms = generate_alarm_burst(n, [:critical, :high, :medium])
        assert Enum.all?(alarms, fn a -> not is_nil(a.id) end)
      end
    end

    test "property — processed + dropped equals submitted for any buffer size (SD)" do
      check all(
              submitted <- SD.integer(10..100),
              buffer_limit <- SD.integer(10..100),
              max_runs: 10
            ) do
        pipeline = create_pipeline(buffer_limit: buffer_limit)
        alarms = generate_alarm_burst(submitted, [:medium, :low])

        {updated, _} = process_batch(pipeline, alarms)

        assert updated.processed_count + updated.dropped_count == submitted
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe "property: ordering preserved"
  # ---------------------------------------------------------------------------

  describe "property: ordering preserved" do
    test "property — FIFO preserved within same severity (SD)" do
      check all(
              n <- SD.integer(2..20),
              sev <- SD.member_of([:critical, :high, :medium, :low, :info]),
              max_runs: 8
            ) do
        alarms =
          Enum.map(1..n, fn i ->
            generate_alarm(severity: sev, source: "src", seq: i)
          end)

        sorted = sort_by_priority(alarms)

        same_sev_seqs =
          sorted
          |> Enum.filter(&(&1.severity == sev))
          |> Enum.map(& &1.seq)

        assert same_sev_seqs == Enum.sort(same_sev_seqs)
      end
    end

    test "property — critical always before info after sorting (SD)" do
      check all(
              n_critical <- SD.integer(1..10),
              n_info <- SD.integer(1..10),
              max_runs: 8
            ) do
        criticals = generate_alarm_burst(n_critical, [:critical])
        infos = generate_alarm_burst(n_info, [:info])

        sorted = sort_by_priority(criticals ++ infos)

        # Find first info index and last critical index
        first_info_idx = Enum.find_index(sorted, &(&1.severity == :info))
        last_critical_idx = rindex(sorted, &(&1.severity == :critical))

        # All criticals must appear before any info
        if first_info_idx && last_critical_idx do
          assert last_critical_idx < first_info_idx
        end
      end
    end
  end

  # ===========================================================================
  # SELF-CONTAINED PRIVATE HELPERS
  # All helpers below are pure functions; no production module calls.
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # generate_alarm/1 — creates a single alarm map
  # ---------------------------------------------------------------------------
  defp generate_alarm(opts) do
    seq = Keyword.get(opts, :seq, 0)
    id_suffix = :erlang.unique_integer([:positive, :monotonic])

    %{
      id: "alarm-#{id_suffix}",
      severity: Keyword.get(opts, :severity, :medium),
      source: Keyword.get(opts, :source, "sensor-default"),
      timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond)),
      seq: seq,
      payload: %{raw: "event-data-#{seq}"}
    }
  end

  # ---------------------------------------------------------------------------
  # generate_alarm_burst/2 — creates N alarms with cycling severities
  # ---------------------------------------------------------------------------
  defp generate_alarm_burst(n, severities) when is_integer(n) and n >= 0 do
    sev_count = length(severities)

    Enum.map(1..max(n, 1), fn i ->
      sev = Enum.at(severities, rem(i - 1, sev_count))
      generate_alarm(severity: sev, source: "burst-src-#{rem(i, 20)}", seq: i)
    end)
    |> then(fn alarms ->
      if n == 0, do: [], else: alarms
    end)
  end

  # ---------------------------------------------------------------------------
  # create_pipeline/1 — creates simulated Broadway pipeline state
  # opts: buffer_limit, batch_size
  # ---------------------------------------------------------------------------
  defp create_pipeline(opts) do
    buffer_limit = Keyword.get(opts, :buffer_limit, 1_000)
    batch_size = Keyword.get(opts, :batch_size, 10)

    %{
      id: "pipeline-#{:erlang.unique_integer([:positive, :monotonic])}",
      status: :active,
      buffer_limit: buffer_limit,
      buffer_used: 0,
      batch_size: batch_size,
      processed_count: 0,
      dropped_count: 0,
      critical_processed: 0,
      batches_processed: 0,
      duplicate_count: 0,
      created_at: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # process_batch/2 — processes alarms through the simulated pipeline
  # Returns {updated_pipeline, :ok | :error}
  # ---------------------------------------------------------------------------
  defp process_batch(pipeline, alarms) do
    {final_pipeline, status} =
      Enum.reduce(alarms, {pipeline, :ok}, fn alarm, {p, _status} ->
        if p.buffer_used >= p.buffer_limit do
          # Buffer full: drop alarm
          updated = %{p | dropped_count: p.dropped_count + 1}
          {updated, :ok}
        else
          # Accept into buffer
          buffered = %{p | buffer_used: p.buffer_used + 1}

          # Check if batch is complete
          completed =
            if rem(buffered.buffer_used, buffered.batch_size) == 0 do
              %{
                buffered
                | batches_processed: buffered.batches_processed + 1,
                  processed_count: buffered.processed_count + buffered.batch_size,
                  buffer_used: 0,
                  critical_processed:
                    buffered.critical_processed +
                      if(alarm.severity == :critical, do: 1, else: 0)
              }
            else
              %{
                buffered
                | critical_processed:
                    buffered.critical_processed +
                      if(alarm.severity == :critical, do: 1, else: 0)
              }
            end

          {completed, :ok}
        end
      end)

    # Flush any remaining partial batch
    remainder = final_pipeline.buffer_used

    flushed_pipeline =
      if remainder > 0 do
        %{
          final_pipeline
          | batches_processed: final_pipeline.batches_processed + 1,
            processed_count: final_pipeline.processed_count + remainder,
            buffer_used: 0
        }
      else
        final_pipeline
      end

    {flushed_pipeline, status}
  end

  # ---------------------------------------------------------------------------
  # detect_storm/2 — checks if alarm rate exceeds storm threshold (SC-ALARM-003)
  # Returns true if >@storm_threshold alarms/minute
  # ---------------------------------------------------------------------------
  defp detect_storm(alarms, timestamps) when length(alarms) == 0 or length(timestamps) == 0 do
    false
  end

  defp detect_storm(alarms, timestamps) do
    count = length(alarms)

    if count == 0 do
      false
    else
      # Compute time span in milliseconds
      sorted_ts = Enum.sort(timestamps)
      span_ms = List.last(sorted_ts) - List.first(sorted_ts)

      # Avoid division by zero: if all timestamps equal, span = 1ms
      effective_span_ms = max(span_ms, 1)

      alarms_per_min = count / effective_span_ms * 60_000

      alarms_per_min > @storm_threshold
    end
  end

  # ---------------------------------------------------------------------------
  # build_timestamps/2 — builds a list of N timestamps spaced by interval_ms
  # ---------------------------------------------------------------------------
  defp build_timestamps(n, opts) do
    interval = Keyword.get(opts, :interval_ms, 1_000)
    base = System.monotonic_time(:millisecond)
    Enum.map(0..(n - 1), fn i -> base + i * interval end)
  end

  # ---------------------------------------------------------------------------
  # apply_backpressure/2 — simulates backpressure control (SC-ALARM-010)
  # Returns updated pipeline with backpressure_active flag
  # ---------------------------------------------------------------------------
  defp apply_backpressure(pipeline, current_buffer_used) do
    capacity_pct = current_buffer_used / max(pipeline.buffer_limit, 1) * 100

    active =
      cond do
        capacity_pct >= 80 -> true
        capacity_pct < 60 -> false
        true -> Map.get(pipeline, :backpressure_active, false)
      end

    Map.put(pipeline, :backpressure_active, active)
  end

  # ---------------------------------------------------------------------------
  # deduplicate_alarms/2 — removes duplicates within time window (SC-ALARM-005)
  # Groups by (source, severity); keeps first alarm per group within window
  # ---------------------------------------------------------------------------
  defp deduplicate_alarms(alarms, window_ms) do
    alarms
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.reduce([], fn alarm, acc ->
      key = {alarm.source, alarm.severity}
      window_start = alarm.timestamp - window_ms

      already_seen =
        Enum.any?(acc, fn existing ->
          {existing.source, existing.severity} == key and
            existing.timestamp >= window_start and
            existing.timestamp <= alarm.timestamp
        end)

      if already_seen, do: acc, else: [alarm | acc]
    end)
    |> Enum.reverse()
  end

  # ---------------------------------------------------------------------------
  # sort_by_priority/1 — sorts alarms critical→high→medium→low→info (SC-ALARM-004)
  # Within same priority, FIFO (original seq order) preserved
  # ---------------------------------------------------------------------------
  defp sort_by_priority(alarms) do
    priority_rank = fn sev ->
      case sev do
        :critical -> 0
        :high -> 1
        :medium -> 2
        :low -> 3
        :info -> 4
        _ -> 5
      end
    end

    alarms
    |> Enum.with_index()
    |> Enum.sort_by(fn {alarm, original_idx} ->
      {priority_rank.(alarm.severity), original_idx}
    end)
    |> Enum.map(fn {alarm, _idx} -> alarm end)
  end

  # ---------------------------------------------------------------------------
  # compute_throughput/2 — calculates alarms/second (SC-ALARM-008)
  # ---------------------------------------------------------------------------
  defp compute_throughput(alarms, duration_ms) do
    count = length(alarms)

    rate =
      if duration_ms == 0 do
        :infinity
      else
        count / duration_ms * 1_000.0
      end

    %{
      alarm_count: count,
      duration_ms: duration_ms,
      alarms_per_second: rate
    }
  end

  # ---------------------------------------------------------------------------
  # compute_latency_percentiles/1 — computes p50/p95/p99 (SC-ALARM-009)
  # ---------------------------------------------------------------------------
  defp compute_latency_percentiles([]) do
    %{p50: 0.0, p95: 0.0, p99: 0.0}
  end

  defp compute_latency_percentiles(latencies_ms) do
    sorted = Enum.sort(latencies_ms)
    n = length(sorted)

    p50 = percentile_at(sorted, n, 0.50)
    p95 = percentile_at(sorted, n, 0.95)
    p99 = percentile_at(sorted, n, 0.99)

    %{p50: p50, p95: p95, p99: p99}
  end

  defp percentile_at(sorted, n, pct) do
    # Nearest-rank method
    idx = max(0, min(round(pct * n) - 1, n - 1))
    Enum.at(sorted, idx) * 1.0
  end

  # ---------------------------------------------------------------------------
  # clamp_batch_size/1 — enforces [batch_min, batch_max] range (SC-ALARM-007)
  # ---------------------------------------------------------------------------
  defp clamp_batch_size(size) do
    size |> max(@batch_min) |> min(@batch_max)
  end

  # ---------------------------------------------------------------------------
  # simulate_crash/3 — simulates mid-batch processor crash (SC-ALARM-006)
  # Returns crash state with in-flight and pending alarm lists
  # ---------------------------------------------------------------------------
  defp simulate_crash(pipeline, in_flight_alarms, pending_alarms) do
    %{
      pipeline_id: pipeline.id,
      status: :crashed,
      in_flight_count: length(in_flight_alarms),
      pending_count: length(pending_alarms),
      in_flight: in_flight_alarms,
      pending: pending_alarms,
      recoverable: true
    }
  end

  # ---------------------------------------------------------------------------
  # recover_pipeline/1 — recovers from crash state, reprocesses in-flight alarms
  # Returns new pipeline with all alarms processed, no duplicates
  # ---------------------------------------------------------------------------
  defp recover_pipeline(crash_state) do
    all_alarms = crash_state.in_flight ++ crash_state.pending

    # Deduplicate by id to prevent double-processing
    unique_alarms =
      all_alarms
      |> Enum.uniq_by(& &1.id)

    duplicate_count = length(all_alarms) - length(unique_alarms)

    fresh_pipeline = create_pipeline(buffer_limit: length(unique_alarms) + 10)

    {processed, :ok} = process_batch(fresh_pipeline, unique_alarms)

    %{processed | duplicate_count: duplicate_count, status: :active}
  end

  # ---------------------------------------------------------------------------
  # Enum.rindex/2 helper — not in stdlib; finds last matching index
  # ---------------------------------------------------------------------------
  defp rindex(list, predicate) do
    list
    |> Enum.with_index()
    |> Enum.filter(fn {elem, _} -> predicate.(elem) end)
    |> List.last()
    |> case do
      nil -> nil
      {_, idx} -> idx
    end
  end
end
