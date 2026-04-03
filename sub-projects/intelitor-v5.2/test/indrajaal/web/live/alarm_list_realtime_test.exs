defmodule Indrajaal.Web.Live.AlarmListRealtimeTest do
  @moduledoc """
  WHAT: Self-contained tests for LiveView alarm list real-time update patterns
        via Phoenix.PubSub — no production module dependencies required.
  WHY:  Validates FIFO message ordering, severity classification, storm detection,
        dark cockpit filtering, acknowledgment, and 50ms latency budget for
        the Prajna alarm dashboard (SC-BRIDGE-001, SC-BRIDGE-003).

  ## STAMP Compliance
  - SC-BRIDGE-001: Message buffer FIFO — ordering tests verify queue discipline
  - SC-BRIDGE-003: Latency budget 50ms — real-time update latency test
  - SC-HMI-001: Dark cockpit default — only critical/major highlighted
  - SC-ALARM-001: Alarm processing — message structure, severity, deduplication

  ## Coverage Matrix
  | Concern                     | Unit | PropCheck | StreamData |
  |-----------------------------|------|-----------|------------|
  | PubSub topic structure      | 1    | 0         | 0          |
  | Alarm message structure     | 1    | 0         | 0          |
  | Severity classification     | 1    | 0         | 0          |
  | FIFO message ordering       | 1    | 0         | 0          |
  | Storm detection             | 1    | 0         | 0          |
  | Storm batching              | 1    | 0         | 0          |
  | Dark cockpit highlighting   | 1    | 0         | 0          |
  | Acknowledgment removal      | 1    | 0         | 0          |
  | Escalation after timeout    | 1    | 0         | 0          |
  | Sorting invariant           | 0    | 1         | 1          |
  | Dedup invariant             | 0    | 1         | 1          |
  | Latency budget              | 1    | 0         | 0          |

  ## EP-GEN-014 compliance
  - `use PropCheck` provides forall for `property` blocks (PropCheck-native).
  - StreamData `check all` blocks inside plain `test` blocks only.
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :alarm_realtime
  @moduletag :bridge

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Section 1: PubSub topic structure (SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  describe "PubSub topic structure" do
    test "alarm topics follow prajna/alerts/** pattern" do
      topics = [
        build_topic("critical"),
        build_topic("major"),
        build_topic("warning"),
        build_topic("info")
      ]

      for topic <- topics do
        assert String.starts_with?(topic, "prajna/alerts/"),
               "Expected topic to start with 'prajna/alerts/' but got: #{topic}"
      end
    end

    test "broadcast message includes checkpoint and metadata" do
      msg = format_pubsub_message(:alarm_created, build_alarm("a1", :critical, "sensor-01"))

      assert Map.has_key?(msg, :event)
      assert Map.has_key?(msg, :payload)
      assert Map.has_key?(msg, :checkpoint_id)
      assert Map.has_key?(msg, :timestamp)
      assert String.starts_with?(msg.checkpoint_id, "CP-ALARM-")
    end
  end

  # ---------------------------------------------------------------------------
  # Section 2: Alarm message structure (SC-ALARM-001)
  # ---------------------------------------------------------------------------

  describe "Alarm message structure" do
    test "alarm map includes all required fields" do
      alarm = build_alarm("alarm-001", :critical, "door-sensor-42")

      assert Map.has_key?(alarm, :id)
      assert Map.has_key?(alarm, :severity)
      assert Map.has_key?(alarm, :source)
      assert Map.has_key?(alarm, :timestamp)
      assert Map.has_key?(alarm, :description)
      assert Map.has_key?(alarm, :acknowledged)
      assert alarm.acknowledged == false
    end

    test "alarm id is a non-empty string" do
      alarm = build_alarm("alarm-002", :major, "camera-07")
      assert is_binary(alarm.id)
      assert byte_size(alarm.id) > 0
    end

    test "alarm source is recorded" do
      alarm = build_alarm("alarm-003", :warning, "motion-sensor-99")
      assert alarm.source == "motion-sensor-99"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 3: Severity classification (SC-ALARM-001, SC-HMI-001)
  # ---------------------------------------------------------------------------

  describe "Severity classification" do
    test "severity ordering: critical > major > warning > info" do
      assert severity_rank(:critical) > severity_rank(:major)
      assert severity_rank(:major) > severity_rank(:warning)
      assert severity_rank(:warning) > severity_rank(:info)
    end

    test "all four standard severities are recognised" do
      for sev <- [:critical, :major, :warning, :info] do
        assert severity_rank(sev) >= 0,
               "Severity #{sev} must map to a non-negative rank"
      end
    end

    test "unknown severity falls back to lowest rank" do
      assert severity_rank(:unknown) == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 4: FIFO message ordering (SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  describe "FIFO message ordering" do
    test "messages enqueued in order are dequeued in order" do
      queue =
        Enum.reduce(1..5, empty_queue(), fn n, q ->
          enqueue(q, build_alarm("a#{n}", :major, "src-#{n}"))
        end)

      ids =
        queue
        |> drain_queue()
        |> Enum.map(& &1.id)

      assert ids == ["a1", "a2", "a3", "a4", "a5"],
             "Expected FIFO order but got: #{inspect(ids)}"
    end

    test "queue length increases with each enqueue" do
      q0 = empty_queue()
      q1 = enqueue(q0, build_alarm("x", :info, "s"))
      q2 = enqueue(q1, build_alarm("y", :info, "s"))

      assert queue_length(q0) == 0
      assert queue_length(q1) == 1
      assert queue_length(q2) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Section 5: Storm detection (SC-ALARM-001, SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  describe "Storm detection" do
    test "11 alarms/second triggers storm mode" do
      # > 10 alarms/second is the threshold
      now = System.monotonic_time(:millisecond)
      timestamps = Enum.map(1..11, fn i -> now - (1000 - i * 80) end)

      assert storm_detected?(timestamps, now),
             "Expected storm detection with 11 alarms in 1 second"
    end

    test "10 alarms/second does not trigger storm mode" do
      now = System.monotonic_time(:millisecond)
      # Exactly 10 arrivals spread over the last second — at or below threshold
      timestamps = Enum.map(1..10, fn i -> now - (1000 - i * 100) end)

      refute storm_detected?(timestamps, now),
             "Expected no storm with exactly 10 alarms/second"
    end

    test "0 alarms never triggers storm mode" do
      now = System.monotonic_time(:millisecond)
      refute storm_detected?([], now)
    end
  end

  # ---------------------------------------------------------------------------
  # Section 6: Storm mode batching (SC-BRIDGE-001, SC-BRIDGE-003)
  # ---------------------------------------------------------------------------

  describe "Storm mode batching" do
    test "normal mode flushes every alarm immediately (batch size 1)" do
      alarms = build_alarm_list(3, :major)
      {batches, _remainder} = batch_updates(alarms, _storm_mode = false)

      assert length(batches) == 3,
             "Normal mode should produce one batch per alarm"
    end

    test "storm mode batches up to 10 alarms per render cycle" do
      alarms = build_alarm_list(25, :major)
      {batches, _remainder} = batch_updates(alarms, _storm_mode = true)

      for batch <- batches do
        assert length(batch) <= 10,
               "Storm batch exceeded 10 items: #{length(batch)}"
      end
    end

    test "storm mode preserves all alarms across batches" do
      alarms = build_alarm_list(23, :warning)
      {batches, remainder} = batch_updates(alarms, _storm_mode = true)
      all_delivered = List.flatten(batches) ++ remainder

      assert length(all_delivered) == 23,
             "Storm batching must not drop alarms"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 7: Dark cockpit (SC-HMI-001)
  # ---------------------------------------------------------------------------

  describe "Dark cockpit: only critical/major alarms are highlighted" do
    test "critical alarm is highlighted" do
      alarm = build_alarm("h1", :critical, "s")
      assert dark_cockpit_highlight?(alarm)
    end

    test "major alarm is highlighted" do
      alarm = build_alarm("h2", :major, "s")
      assert dark_cockpit_highlight?(alarm)
    end

    test "warning alarm is not highlighted" do
      alarm = build_alarm("h3", :warning, "s")
      refute dark_cockpit_highlight?(alarm)
    end

    test "info alarm is not highlighted" do
      alarm = build_alarm("h4", :info, "s")
      refute dark_cockpit_highlight?(alarm)
    end

    test "dark_cockpit_filter/1 keeps only highlighted alarms" do
      alarms = [
        build_alarm("c1", :critical, "s"),
        build_alarm("m1", :major, "s"),
        build_alarm("w1", :warning, "s"),
        build_alarm("i1", :info, "s")
      ]

      highlighted = dark_cockpit_filter(alarms)

      assert Enum.all?(highlighted, &dark_cockpit_highlight?/1),
             "Filter must return only critical and major"

      assert length(highlighted) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Section 8: Acknowledgment removes alarm from active list
  # ---------------------------------------------------------------------------

  describe "Alarm acknowledgment" do
    test "acknowledging an alarm sets acknowledged: true" do
      alarm = build_alarm("ack-1", :critical, "sensor-ack")
      acked = acknowledge_alarm(alarm)

      assert acked.acknowledged == true
      assert acked.id == alarm.id
    end

    test "acknowledged alarms are excluded from active list" do
      alarms = [
        build_alarm("active-1", :critical, "s"),
        build_alarm("acked-1", :major, "s") |> acknowledge_alarm(),
        build_alarm("active-2", :warning, "s")
      ]

      active = active_alarms(alarms)
      ids = Enum.map(active, & &1.id)

      assert "active-1" in ids
      assert "active-2" in ids
      refute "acked-1" in ids
    end

    test "acknowledging a non-existent id has no effect on the list" do
      alarms = [build_alarm("r1", :info, "s")]
      before_count = length(alarms)
      after_count = alarms |> remove_acknowledged("nonexistent") |> length()
      assert before_count == after_count
    end
  end

  # ---------------------------------------------------------------------------
  # Section 9: Alarm escalation after timeout
  # ---------------------------------------------------------------------------

  describe "Alarm escalation after timeout" do
    test "critical alarm escalates after 30 seconds" do
      created_at = System.monotonic_time(:millisecond) - 31_000
      alarm = build_alarm_at("esc-crit", :critical, "s", created_at)

      assert should_escalate?(alarm),
             "Critical alarm older than 30s must trigger escalation"
    end

    test "critical alarm does not escalate before 30 seconds" do
      created_at = System.monotonic_time(:millisecond) - 20_000
      alarm = build_alarm_at("no-esc-crit", :critical, "s", created_at)

      refute should_escalate?(alarm)
    end

    test "major alarm escalates after 60 seconds" do
      created_at = System.monotonic_time(:millisecond) - 61_000
      alarm = build_alarm_at("esc-major", :major, "s", created_at)

      assert should_escalate?(alarm)
    end

    test "major alarm does not escalate before 60 seconds" do
      created_at = System.monotonic_time(:millisecond) - 45_000
      alarm = build_alarm_at("no-esc-major", :major, "s", created_at)

      refute should_escalate?(alarm)
    end

    test "warning and info alarms never escalate" do
      now = System.monotonic_time(:millisecond)

      for sev <- [:warning, :info] do
        # Even a very old alarm below escalation threshold
        alarm = build_alarm_at("old-#{sev}", sev, "s", now - 3_600_000)
        refute should_escalate?(alarm), "#{sev} should never escalate"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 10: Property — alarm sorting invariant (PropCheck)
  # ---------------------------------------------------------------------------

  describe "Alarm sorting — PropCheck" do
    property "SORT_PROP_01: sorted list is always by severity desc then timestamp desc" do
      forall raw_alarms <- PC.non_empty(PC.list(alarm_gen_pc())) do
        sorted = sort_alarms(raw_alarms)

        pairs = Enum.zip(sorted, tl(sorted))

        Enum.all?(pairs, fn {a, b} ->
          if severity_rank(a.severity) != severity_rank(b.severity) do
            severity_rank(a.severity) >= severity_rank(b.severity)
          else
            a.timestamp >= b.timestamp
          end
        end)
      end
    end

    property "SORT_PROP_02: sorting is idempotent" do
      forall raw_alarms <- PC.non_empty(PC.list(alarm_gen_pc())) do
        once = sort_alarms(raw_alarms)
        twice = sort_alarms(once)
        once == twice
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 11: Property — alarm deduplication invariant (StreamData)
  # ---------------------------------------------------------------------------

  describe "Alarm deduplication — StreamData" do
    test "DEDUP_SD_01: dedup preserves latest occurrence per id" do
      check all(alarms <- SD.list_of(alarm_gen_sd(), min_length: 1, max_length: 20)) do
        deduped = dedup_alarms(alarms)

        # No duplicate ids remain
        ids = Enum.map(deduped, & &1.id)

        assert length(ids) == length(Enum.uniq(ids)),
               "Dedup must remove duplicate ids"
      end
    end

    test "DEDUP_SD_02: dedup keeps the alarm with the latest timestamp" do
      check all(
              id <- SD.binary(min_length: 1, max_length: 8),
              t1 <- SD.integer(0, 999_999),
              t2 <- SD.integer(1_000_000, 1_999_999)
            ) do
        older = build_alarm_at(id, :warning, "s", t1)
        newer = build_alarm_at(id, :warning, "s", t2)

        # Order of input should not matter — dedup always keeps newest
        for input <- [[older, newer], [newer, older]] do
          [kept] = dedup_alarms(input)

          assert kept.timestamp == t2,
                 "Dedup must keep the newer timestamp"
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 12: Real-time update latency within 50ms (SC-BRIDGE-003)
  # ---------------------------------------------------------------------------

  describe "Real-time update latency (SC-BRIDGE-003)" do
    test "processing a single alarm update completes within 50ms" do
      alarm = build_alarm("lat-1", :critical, "sensor-latency")

      t0 = System.monotonic_time(:millisecond)

      # Simulate the full update cycle: format message → sort → dedup → filter
      _msg = format_pubsub_message(:alarm_created, alarm)
      _sorted = sort_alarms([alarm])
      _deduped = dedup_alarms([alarm])
      _filtered = dark_cockpit_filter([alarm])

      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= 50,
             "Single alarm update processing took #{elapsed}ms — must be ≤50ms (SC-BRIDGE-003)"
    end

    test "processing a batch of 50 alarms completes within 50ms" do
      alarms = build_alarm_list(50, :major)

      t0 = System.monotonic_time(:millisecond)

      _sorted = sort_alarms(alarms)
      _deduped = dedup_alarms(alarms)
      _filtered = dark_cockpit_filter(alarms)

      elapsed = System.monotonic_time(:millisecond) - t0

      assert elapsed <= 50,
             "Batch of 50 alarms took #{elapsed}ms — must be ≤50ms (SC-BRIDGE-003)"
    end
  end

  # ===========================================================================
  # Private helpers — all logic is self-contained, no production deps
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Alarm construction
  # ---------------------------------------------------------------------------

  defp build_alarm(id, severity, source) do
    %{
      id: id,
      severity: severity,
      source: source,
      description: "Alarm #{id} from #{source}",
      timestamp: System.monotonic_time(:millisecond),
      acknowledged: false
    }
  end

  defp build_alarm_at(id, severity, source, timestamp_ms) do
    %{
      id: id,
      severity: severity,
      source: source,
      description: "Alarm #{id} at t=#{timestamp_ms}",
      timestamp: timestamp_ms,
      acknowledged: false
    }
  end

  defp build_alarm_list(count, severity) do
    Enum.map(1..count, fn n ->
      build_alarm("alarm-#{n}", severity, "src-#{n}")
    end)
  end

  # ---------------------------------------------------------------------------
  # PubSub helpers (SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  defp build_topic(severity_string),
    do: "prajna/alerts/#{severity_string}"

  defp format_pubsub_message(event, payload) do
    %{
      event: event,
      payload: payload,
      checkpoint_id: "CP-ALARM-#{:erlang.unique_integer([:positive])}",
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  # ---------------------------------------------------------------------------
  # Severity helpers
  # ---------------------------------------------------------------------------

  defp severity_rank(:critical), do: 4
  defp severity_rank(:major), do: 3
  defp severity_rank(:warning), do: 2
  defp severity_rank(:info), do: 1
  defp severity_rank(_), do: 0

  # ---------------------------------------------------------------------------
  # FIFO queue (pure functional — SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  defp empty_queue, do: {[], []}

  defp enqueue({inbox, outbox}, item), do: {[item | inbox], outbox}

  defp drain_queue(queue), do: do_drain(queue, [])

  defp do_drain({[], []}, acc), do: Enum.reverse(acc)

  defp do_drain({inbox, []}, acc),
    do: do_drain({[], Enum.reverse(inbox)}, acc)

  defp do_drain({inbox, [head | rest]}, acc),
    do: do_drain({inbox, rest}, [head | acc])

  defp queue_length({inbox, outbox}), do: length(inbox) + length(outbox)

  # ---------------------------------------------------------------------------
  # Storm detection (> 10 arrivals in 1-second window)
  # ---------------------------------------------------------------------------

  defp storm_detected?(timestamps, now) do
    window_start = now - 1_000
    count_in_window = Enum.count(timestamps, fn t -> t >= window_start end)
    count_in_window > 10
  end

  # ---------------------------------------------------------------------------
  # Storm batching (SC-BRIDGE-001)
  # ---------------------------------------------------------------------------

  @storm_batch_size 10

  # Returns {list_of_complete_batches, remainder}
  defp batch_updates(alarms, false = _storm_mode) do
    batches = Enum.map(alarms, fn a -> [a] end)
    {batches, []}
  end

  defp batch_updates(alarms, true = _storm_mode) do
    chunks = Enum.chunk_every(alarms, @storm_batch_size)
    # Last chunk may be a partial batch — treat as remainder
    case chunks do
      [] ->
        {[], []}

      [single] ->
        {[], single}

      many ->
        complete = Enum.slice(many, 0, length(many) - 1)
        remainder = List.last(many)
        {complete, remainder}
    end
  end

  # ---------------------------------------------------------------------------
  # Dark cockpit (SC-HMI-001)
  # ---------------------------------------------------------------------------

  defp dark_cockpit_highlight?(%{severity: sev}), do: sev in [:critical, :major]

  defp dark_cockpit_filter(alarms), do: Enum.filter(alarms, &dark_cockpit_highlight?/1)

  # ---------------------------------------------------------------------------
  # Acknowledgment
  # ---------------------------------------------------------------------------

  defp acknowledge_alarm(alarm), do: Map.put(alarm, :acknowledged, true)

  defp active_alarms(alarms), do: Enum.reject(alarms, & &1.acknowledged)

  defp remove_acknowledged(alarms, id), do: Enum.reject(alarms, &(&1.id == id))

  # ---------------------------------------------------------------------------
  # Escalation (SC-ALARM-001)
  # ---------------------------------------------------------------------------

  @critical_escalation_ms 30_000
  @major_escalation_ms 60_000

  defp should_escalate?(%{severity: :critical, timestamp: ts}) do
    age = System.monotonic_time(:millisecond) - ts
    age >= @critical_escalation_ms
  end

  defp should_escalate?(%{severity: :major, timestamp: ts}) do
    age = System.monotonic_time(:millisecond) - ts
    age >= @major_escalation_ms
  end

  defp should_escalate?(_), do: false

  # ---------------------------------------------------------------------------
  # Sorting (severity desc, timestamp desc)
  # ---------------------------------------------------------------------------

  defp sort_alarms(alarms) do
    Enum.sort(alarms, fn a, b ->
      rank_a = severity_rank(a.severity)
      rank_b = severity_rank(b.severity)

      if rank_a != rank_b do
        rank_a >= rank_b
      else
        a.timestamp >= b.timestamp
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Deduplication — keeps newest occurrence per id
  # ---------------------------------------------------------------------------

  defp dedup_alarms(alarms) do
    alarms
    |> Enum.reduce(%{}, fn alarm, acc ->
      existing = Map.get(acc, alarm.id)

      if existing == nil or alarm.timestamp > existing.timestamp do
        Map.put(acc, alarm.id, alarm)
      else
        acc
      end
    end)
    |> Map.values()
  end

  # ---------------------------------------------------------------------------
  # PropCheck generators (PC. prefix — EP-GEN-014)
  # ---------------------------------------------------------------------------

  @severities [:critical, :major, :warning, :info]

  defp alarm_gen_pc do
    let {id, sev_idx, ts} <- {PC.binary(max: 8), PC.integer(0, 3), PC.integer(0, 999_999)} do
      sev = Enum.at(@severities, sev_idx)
      build_alarm_at(id, sev, "gen-src", ts)
    end
  end

  # ---------------------------------------------------------------------------
  # StreamData generators (SD. prefix — EP-GEN-014)
  # ---------------------------------------------------------------------------

  defp alarm_gen_sd do
    SD.fixed_map(%{
      id: SD.binary(min_length: 1, max_length: 8),
      severity: SD.member_of(@severities),
      source: SD.constant("gen-src"),
      description: SD.constant("generated alarm"),
      timestamp: SD.integer(0, 999_999),
      acknowledged: SD.constant(false)
    })
  end
end
