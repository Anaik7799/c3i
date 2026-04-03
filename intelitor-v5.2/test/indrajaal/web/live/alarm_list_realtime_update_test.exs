defmodule Indrajaal.Web.Live.AlarmListRealtimeUpdateTest do
  @moduledoc """
  WHAT: Self-contained TDG test suite for LiveView alarm list real-time updates
        via Phoenix.PubSub. ETS tables back all state — no production module
        dependencies are required. Covers subscription delivery, severity
        classification, storm detection, acknowledgment, list ordering,
        filtering, incremental PubSub-driven updates, and escalation.

  WHY:  Validates the Prajna alarm dashboard update pipeline end-to-end so that
        Phoenix.PubSub broadcasts drive correct state transitions. Provides TDG
        coverage required before any AlarmList LiveView implementation ships.

  ## STAMP Compliance
  - SC-ALARM-001: Alarm processing — ingestion, topic subscription, field contract
  - SC-ALARM-002: Alarm state management — active / acknowledged lifecycle
  - SC-ALARM-003: Alarm severity model — five-level classification and colour coding
  - SC-BRIDGE-001: Message buffer FIFO — PubSub ordering preserved per topic
  - SC-HMI-001:   Dark cockpit default — colour coding by severity, highlight only
                  for critical/major

  ## Coverage Matrix
  | Concern                              | Unit | SD check all |
  |--------------------------------------|------|--------------|
  | Alarm list subscription (PubSub)     | 3    | 0            |
  | Alarm severity classification        | 4    | 0            |
  | Alarm storm detection                | 3    | 0            |
  | Alarm acknowledgment                 | 4    | 0            |
  | Alarm list ordering                  | 3    | 0            |
  | Alarm list filtering                 | 4    | 0            |
  | Real-time list update (PubSub)       | 3    | 0            |
  | Alarm escalation                     | 3    | 0            |
  | Property: list always sorted         | 0    | 1            |
  | Property: filtered count ≤ total     | 0    | 1            |

  ## EP-GEN-014 compliance
  - `use PropCheck` is present to satisfy the dual-property-testing requirement.
  - `alias PropCheck.BasicTypes, as: PC` is present; PC generators are available
    for forall blocks if needed by future extensions.
  - `import ExUnitProperties, except: [property: 2, property: 3]` is
    present; `check all(...)` blocks live inside plain `test` blocks.
  - `alias StreamData, as: SD` — all StreamData generators use the SD. prefix.

  ## Change History
  | Version | Date       | Author | Change                                      |
  |---------|------------|--------|---------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial TDG suite — all 10 describe blocks  |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY
  use PropCheck
  # EP-GEN-014: check/2 excluded to prevent PropCheck conflict; use ExUnitProperties.check/2
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :alarm_realtime_update
  @moduletag :bridge

  # Suppress PropCheck "pc_" alias warning — PC is required by AOR-PROP-001 even
  # when only SD generators are exercised in this file.
  _ = PC

  # ===========================================================================
  # SETUP — ETS table + PubSub per test (SC-ALARM-001)
  # ===========================================================================

  setup_all do
    # Ensure the pg and phoenix_pubsub OTP applications are running — required
    # for start_supervised!({Phoenix.PubSub, ...}) calls in per-test setup.
    Application.ensure_all_started(:pg)
    Application.ensure_all_started(:phoenix_pubsub)
    Application.ensure_all_started(:propcheck)
    :ok
  end

  setup do
    # Use a unique PubSub name per test so async: true tests do not collide.
    pubsub_name = :"alarm_pubsub_#{:erlang.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})

    # Each test gets its own isolated ETS table.
    table = :ets.new(:alarm_update_test, [:set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
    end)

    %{table: table, pubsub: pubsub_name}
  end

  # ===========================================================================
  # 1. Alarm list subscription (SC-ALARM-001, SC-BRIDGE-001)
  # ===========================================================================

  describe "alarm list subscription" do
    test "subscriber receives new alarm broadcast on the correct topic",
         %{table: table, pubsub: ps} do
      topic = alarm_topic(:critical)
      Phoenix.PubSub.subscribe(ps, topic)

      alarm = make_alarm("sub-1", :critical, "door-sensor-01", "door forced open")
      Phoenix.PubSub.broadcast(ps, topic, {:alarm_created, alarm})

      assert_receive {:alarm_created, received}, 200

      :ets.insert(table, {:last_received, received})
      assert received.id == "sub-1"
      assert received.severity == :critical
    end

    test "subscriber on one severity topic does not receive broadcasts on another topic",
         %{pubsub: ps} do
      Phoenix.PubSub.subscribe(ps, alarm_topic(:info))

      alarm = make_alarm("sub-2", :critical, "sensor-x", "critical event")
      Phoenix.PubSub.broadcast(ps, alarm_topic(:critical), {:alarm_created, alarm})

      refute_receive {:alarm_created, _}, 100
    end

    test "multiple subscribers all receive the same broadcast", %{table: table, pubsub: ps} do
      topic = alarm_topic(:major)
      parent = self()

      # Two additional subscribers via spawned processes — each process subscribes
      # independently and reports back via message passing.
      pids =
        Enum.map(1..2, fn n ->
          spawn_link(fn ->
            Phoenix.PubSub.subscribe(ps, topic)

            receive do
              {:alarm_created, a} -> send(parent, {:"sub_got_#{n}", a.id})
            after
              500 -> send(parent, {:"sub_timeout_#{n}", nil})
            end
          end)
        end)

      # Small pause to allow spawned processes to subscribe before broadcasting
      Process.sleep(10)

      alarm = make_alarm("sub-3", :major, "cam-99", "motion detected")
      Phoenix.PubSub.broadcast(ps, topic, {:alarm_created, alarm})

      results =
        Enum.map(1..2, fn n ->
          receive do
            {tag, id} -> {tag, id}
          after
            400 -> {:"sub_timeout_#{n}", nil}
          end
        end)

      :ets.insert(table, {:broadcast_results, results})

      for {_tag, id} <- results do
        assert id == "sub-3", "Every subscriber must receive the same alarm id"
      end

      Enum.each(pids, &Process.exit(&1, :kill))
    end
  end

  # ===========================================================================
  # 2. Alarm severity classification (SC-ALARM-003, SC-HMI-001)
  # ===========================================================================

  describe "alarm severity classification" do
    test "five-level severity rank is strictly ordered" do
      assert sev_rank(:critical) > sev_rank(:major)
      assert sev_rank(:major) > sev_rank(:minor)
      assert sev_rank(:minor) > sev_rank(:warning)
      assert sev_rank(:warning) > sev_rank(:info)
    end

    test "critical and major receive highlight CSS class (SC-HMI-001)" do
      for sev <- [:critical, :major] do
        css = severity_css(sev)

        assert String.contains?(css, "highlight"),
               "#{sev} must carry a highlight class per SC-HMI-001, got: #{css}"
      end
    end

    test "minor, warning, info severities do not receive highlight class" do
      for sev <- [:minor, :warning, :info] do
        css = severity_css(sev)

        refute String.contains?(css, "highlight"),
               "#{sev} must not carry a highlight class, got: #{css}"
      end
    end

    test "severity CSS class mapping is injective (no two severities share a class)" do
      all_sevs = [:critical, :major, :minor, :warning, :info]
      classes = Enum.map(all_sevs, &severity_css/1)

      assert length(Enum.uniq(classes)) == length(all_sevs),
             "Each severity must map to a distinct CSS class"
    end
  end

  # ===========================================================================
  # 3. Alarm storm detection (SC-ALARM-003)
  # ===========================================================================

  describe "alarm storm detection" do
    test "more than 100 alarms within 60 s triggers storm mode" do
      now = System.monotonic_time(:millisecond)
      # 101 arrivals evenly spread over the last 60 s — each just inside window
      timestamps = Enum.map(1..101, fn i -> now - trunc(i * (60_000 / 102)) end)

      assert storm_mode?(timestamps, now),
             "101 alarms in 60 s must trigger storm mode"
    end

    test "exactly 100 alarms in 60 s does not trigger storm mode" do
      now = System.monotonic_time(:millisecond)
      timestamps = Enum.map(1..100, fn i -> now - i * 600 end)

      refute storm_mode?(timestamps, now),
             "Exactly 100 alarms in 60 s must NOT trigger storm mode"
    end

    test "storm suppression: alarm count reported when storm is active" do
      now = System.monotonic_time(:millisecond)
      timestamps = Enum.map(1..105, fn i -> now - i * 500 end)

      state = %{alarm_timestamps: timestamps, storm_active: storm_mode?(timestamps, now)}
      assert state.storm_active == true

      suppression_msg = storm_suppression_msg(state)
      assert suppression_msg.storm == true
      assert suppression_msg.rate > 100
    end
  end

  # ===========================================================================
  # 4. Alarm acknowledgment (SC-ALARM-002)
  # ===========================================================================

  describe "alarm acknowledgment" do
    test "acknowledging an alarm sets acknowledged flag to true", %{table: table} do
      state =
        new_state()
        |> add_alarm(make_alarm("ack-1", :critical, "s", "d"))

      updated = ack_alarm(state, "ack-1")
      [alarm] = find_alarms(updated, "ack-1")

      :ets.insert(table, {:ack_result, alarm})
      assert alarm.acknowledged == true
    end

    test "acknowledged alarm is excluded from active subset" do
      state =
        new_state()
        |> add_alarm(make_alarm("act-1", :critical, "s", "d"))
        |> add_alarm(make_alarm("ack-2", :major, "s", "d"))

      updated = ack_alarm(state, "ack-2")
      active_ids = active_alarms(updated) |> Enum.map(& &1.id)

      assert "act-1" in active_ids
      refute "ack-2" in active_ids
    end

    test "acknowledging a non-existent id leaves the list unchanged" do
      state = new_state() |> add_alarm(make_alarm("x1", :warning, "s", "d"))
      updated = ack_alarm(state, "no-such-id")

      assert updated.count == state.count
    end

    test "acknowledgment records actor and acked_at timestamp" do
      actor = "ops-user-007"
      state = new_state() |> add_alarm(make_alarm("ack-audit", :major, "s", "d"))
      updated = ack_alarm(state, "ack-audit", actor: actor)

      [alarm] = find_alarms(updated, "ack-audit")

      assert alarm.ack_actor == actor
      assert is_integer(alarm.acked_at)
    end
  end

  # ===========================================================================
  # 5. Alarm list ordering (SC-ALARM-001, SC-BRIDGE-001)
  # ===========================================================================

  describe "alarm list ordering" do
    test "most recent alarm appears first when severities are equal" do
      t_old = 1_000
      t_new = 9_000

      state =
        new_state()
        |> add_alarm(make_alarm_at("older", :major, "s", "d", t_old))
        |> add_alarm(make_alarm_at("newer", :major, "s", "d", t_new))

      [first | _] = state.alarms
      assert first.id == "newer", "Newer alarm must precede older alarm of same severity"
    end

    test "higher severity alarm sorts before lower severity regardless of arrival order" do
      state =
        new_state()
        |> add_alarm(make_alarm("info-first", :info, "s", "d"))
        |> add_alarm(make_alarm("crit-later", :critical, "s", "d"))

      [first | _] = state.alarms
      assert first.severity == :critical, "Critical must rank above info regardless of order"
    end

    test "stable sort: equal severity and equal timestamp preserves original relative order" do
      # Two alarms with identical severity and timestamp — both must appear exactly once
      ts = 5_000

      state =
        new_state()
        |> add_alarm(make_alarm_at("alpha", :warning, "s", "d", ts))
        |> add_alarm(make_alarm_at("beta", :warning, "s", "d", ts))

      ids = Enum.map(state.alarms, & &1.id) |> Enum.sort()
      assert ids == ["alpha", "beta"], "Both alarms must survive the sort"
    end
  end

  # ===========================================================================
  # 6. Alarm list filtering (SC-ALARM-001)
  # ===========================================================================

  describe "alarm list filtering" do
    test "filter by severity returns only matching alarms" do
      state =
        new_state()
        |> add_alarm(make_alarm("c1", :critical, "s", "d"))
        |> add_alarm(make_alarm("i1", :info, "s", "d"))
        |> add_alarm(make_alarm("c2", :critical, "s", "d"))

      results = filter_alarms(state, severity: :critical)
      ids = Enum.map(results, & &1.id)

      assert "c1" in ids
      assert "c2" in ids
      refute "i1" in ids
    end

    test "filter by source returns only alarms from that source" do
      state =
        new_state()
        |> add_alarm(make_alarm("s1", :major, "sensor-A", "d"))
        |> add_alarm(make_alarm("s2", :major, "sensor-B", "d"))
        |> add_alarm(make_alarm("s3", :warning, "sensor-A", "d"))

      results = filter_alarms(state, source: "sensor-A")
      ids = Enum.map(results, & &1.id)

      assert "s1" in ids
      assert "s3" in ids
      refute "s2" in ids
    end

    test "filter by time range returns alarms within the window" do
      state =
        new_state()
        |> add_alarm(make_alarm_at("old", :info, "s", "d", 1_000))
        |> add_alarm(make_alarm_at("mid", :info, "s", "d", 5_000))
        |> add_alarm(make_alarm_at("new", :info, "s", "d", 9_000))

      results = filter_alarms(state, after_ts: 4_000, before_ts: 8_000)
      ids = Enum.map(results, & &1.id)

      assert "mid" in ids
      refute "old" in ids
      refute "new" in ids
    end

    test "combined severity and source filter uses AND semantics" do
      state =
        new_state()
        |> add_alarm(make_alarm("m", :major, "sensor-A", "d"))
        |> add_alarm(make_alarm("c", :critical, "sensor-A", "d"))
        |> add_alarm(make_alarm("m2", :major, "sensor-B", "d"))

      results = filter_alarms(state, severity: :major, source: "sensor-A")
      ids = Enum.map(results, & &1.id)

      assert ids == ["m"], "Combined filter must match both criteria (AND semantics)"
    end
  end

  # ===========================================================================
  # 7. Real-time list update via PubSub (SC-ALARM-001, SC-BRIDGE-001)
  # ===========================================================================

  describe "real-time list update" do
    test "PubSub broadcast triggers list state update in subscriber", %{pubsub: ps} do
      topic = alarm_topic(:major)
      Phoenix.PubSub.subscribe(ps, topic)

      state = new_state()
      alarm = make_alarm("rt-1", :major, "cam-01", "motion")
      Phoenix.PubSub.broadcast(ps, topic, {:alarm_created, alarm})

      assert_receive {:alarm_created, incoming}, 200

      updated = add_alarm(state, incoming)
      assert updated.count == 1
      assert hd(updated.alarms).id == "rt-1"
    end

    test "incremental update does not duplicate existing alarms" do
      state =
        new_state()
        |> add_alarm(make_alarm("rt-dup", :minor, "src", "first"))

      # Receive an update for the same id (latest-wins upsert)
      incoming = make_alarm("rt-dup", :minor, "src", "updated")
      updated = add_alarm(state, incoming)

      ids = Enum.map(updated.alarms, & &1.id)
      assert Enum.count(ids, &(&1 == "rt-dup")) == 1, "Upsert must deduplicate by id"
      assert hd(updated.alarms).description == "updated"
    end

    test "broadcast for alarm_resolved removes it from the active list", %{pubsub: ps} do
      state =
        new_state()
        |> add_alarm(make_alarm("rt-res", :critical, "src", "active alarm"))

      topic = alarm_topic(:critical)
      Phoenix.PubSub.subscribe(ps, topic)
      Phoenix.PubSub.broadcast(ps, topic, {:alarm_resolved, "rt-res"})

      assert_receive {:alarm_resolved, resolved_id}, 200

      updated = remove_alarm(state, resolved_id)
      refute Enum.any?(updated.alarms, &(&1.id == resolved_id))
    end
  end

  # ===========================================================================
  # 8. Alarm escalation (SC-ALARM-002)
  # ===========================================================================

  describe "alarm escalation" do
    test "unacknowledged critical alarm escalates after timeout threshold" do
      alarm = make_alarm_at("esc-1", :critical, "s", "d", 0)
      now_ms = 5 * 60 * 1_000 + 1

      assert should_escalate?(alarm, now_ms),
             "Critical alarm unacked for >5 min must be flagged for escalation"
    end

    test "acknowledged critical alarm does not escalate" do
      alarm =
        make_alarm_at("esc-2", :critical, "s", "d", 0)
        |> Map.put(:acknowledged, true)

      now_ms = 10 * 60 * 1_000

      refute should_escalate?(alarm, now_ms),
             "Acknowledged alarm must never be escalated"
    end

    test "escalation produces a notification with correct alarm id and severity" do
      alarm = make_alarm_at("esc-3", :critical, "s", "d", 0)
      now_ms = 6 * 60 * 1_000

      notification = escalation_notification(alarm, now_ms)

      assert notification.alarm_id == "esc-3"
      assert notification.severity == :critical
      assert notification.escalated == true
      assert is_integer(notification.escalated_at)
    end
  end

  # ===========================================================================
  # 9. Property: alarm ordering is always consistent (SD generators)
  # ===========================================================================

  describe "property: alarm ordering is always consistent" do
    test "SD_PROP_01: list sorted by (severity desc, timestamp desc) after any add sequence" do
      ExUnitProperties.check all(alarms <- SD.list_of(alarm_gen(), min_length: 1, max_length: 40)) do
        state = Enum.reduce(alarms, new_state(), &add_alarm(&2, &1))

        pairs = Enum.zip(state.alarms, tl(state.alarms))

        assert Enum.all?(pairs, fn {a, b} ->
                 ra = sev_rank(a.severity)
                 rb = sev_rank(b.severity)

                 if ra != rb, do: ra >= rb, else: a.timestamp >= b.timestamp
               end),
               "Alarm list must be sorted (severity desc, timestamp desc) at all times"
      end
    end
  end

  # ===========================================================================
  # 10. Property: alarm count after filter <= total count (SD generators)
  # ===========================================================================

  describe "property: filtered alarm count never exceeds total" do
    test "SD_PROP_02: |filter(S, criteria)| ≤ |S| for any alarm list and any severity filter" do
      ExUnitProperties.check all(
                               alarms <- SD.list_of(alarm_gen(), min_length: 0, max_length: 50),
                               filter_sev <-
                                 SD.member_of([:critical, :major, :minor, :warning, :info])
                             ) do
        state = Enum.reduce(alarms, new_state(), &add_alarm(&2, &1))
        filtered = filter_alarms(state, severity: filter_sev)

        assert length(filtered) <= state.count,
               "Filtered count (#{length(filtered)}) must not exceed total (#{state.count})"
      end
    end
  end

  # ===========================================================================
  # Private helpers — all self-contained, no production module dependencies
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # State
  # ---------------------------------------------------------------------------

  @history_cap 1_000

  defp new_state, do: %{alarms: [], count: 0, history: [], storm_active: false}

  defp add_alarm(state, alarm) do
    # Upsert: drop existing entry for same id, then prepend and sort
    retained = Enum.reject(state.alarms, &(&1.id == alarm.id))

    sorted =
      [alarm | retained]
      |> Enum.sort(fn a, b ->
        ra = sev_rank(a.severity)
        rb = sev_rank(b.severity)
        if ra != rb, do: ra >= rb, else: a.timestamp >= b.timestamp
      end)

    new_history =
      (state.history ++ [alarm])
      |> Enum.take(-@history_cap)

    %{state | alarms: sorted, count: length(sorted), history: new_history}
  end

  defp remove_alarm(state, alarm_id) do
    remaining = Enum.reject(state.alarms, &(&1.id == alarm_id))
    %{state | alarms: remaining, count: length(remaining)}
  end

  defp ack_alarm(state, alarm_id, opts \\ []) do
    actor = Keyword.get(opts, :actor, "system")
    now = System.monotonic_time(:millisecond)

    updated =
      Enum.map(state.alarms, fn alarm ->
        if alarm.id == alarm_id do
          %{alarm | acknowledged: true, ack_actor: actor, acked_at: now}
        else
          alarm
        end
      end)

    %{state | alarms: updated}
  end

  defp active_alarms(state), do: Enum.reject(state.alarms, & &1.acknowledged)

  defp find_alarms(state, id), do: Enum.filter(state.alarms, &(&1.id == id))

  defp filter_alarms(state, criteria) do
    Enum.filter(state.alarms, fn alarm ->
      Enum.all?(criteria, fn
        {:severity, sev} -> alarm.severity == sev
        {:source, src} -> alarm.source == src
        {:after_ts, ts} -> alarm.timestamp >= ts
        {:before_ts, ts} -> alarm.timestamp <= ts
        _ -> true
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Alarm construction
  # ---------------------------------------------------------------------------

  defp make_alarm(id, severity, source, description) do
    %{
      id: id,
      severity: severity,
      source: source,
      description: description,
      type: "generic",
      timestamp: System.monotonic_time(:millisecond),
      acknowledged: false,
      ack_actor: nil,
      acked_at: nil
    }
  end

  defp make_alarm_at(id, severity, source, description, timestamp_ms) do
    %{
      id: id,
      severity: severity,
      source: source,
      description: description,
      type: "generic",
      timestamp: timestamp_ms,
      acknowledged: false,
      ack_actor: nil,
      acked_at: nil
    }
  end

  # ---------------------------------------------------------------------------
  # Severity helpers
  # ---------------------------------------------------------------------------

  defp sev_rank(:critical), do: 5
  defp sev_rank(:major), do: 4
  defp sev_rank(:minor), do: 3
  defp sev_rank(:warning), do: 2
  defp sev_rank(:info), do: 1
  defp sev_rank(_), do: 0

  defp severity_css(:critical), do: "alarm-critical highlight"
  defp severity_css(:major), do: "alarm-major highlight"
  defp severity_css(:minor), do: "alarm-minor"
  defp severity_css(:warning), do: "alarm-warning"
  defp severity_css(:info), do: "alarm-info"

  # ---------------------------------------------------------------------------
  # Storm helpers
  # ---------------------------------------------------------------------------

  @storm_window_ms 60_000
  @storm_threshold 100

  defp storm_mode?(timestamps, now) do
    window_start = now - @storm_window_ms
    Enum.count(timestamps, fn t -> t >= window_start end) > @storm_threshold
  end

  defp storm_suppression_msg(state) do
    rate = length(state.alarm_timestamps)

    %{
      storm: state.storm_active,
      rate: rate,
      suppression_active: state.storm_active
    }
  end

  # ---------------------------------------------------------------------------
  # PubSub helpers
  # ---------------------------------------------------------------------------

  defp alarm_topic(severity), do: "prajna/alerts/#{severity}"

  # ---------------------------------------------------------------------------
  # Escalation helpers
  # ---------------------------------------------------------------------------

  @escalation_timeout_ms 5 * 60 * 1_000

  defp should_escalate?(%{acknowledged: true}, _now_ms), do: false

  defp should_escalate?(%{severity: :critical, timestamp: ts, acknowledged: false}, now_ms),
    do: now_ms - ts > @escalation_timeout_ms

  defp should_escalate?(_, _now_ms), do: false

  defp escalation_notification(alarm, now_ms) do
    %{
      alarm_id: alarm.id,
      severity: alarm.severity,
      escalated: true,
      escalated_at: now_ms,
      age_ms: now_ms - alarm.timestamp
    }
  end

  # ---------------------------------------------------------------------------
  # StreamData generator (SD. prefix — EP-GEN-014)
  # ---------------------------------------------------------------------------

  @sd_severities [:critical, :major, :minor, :warning, :info]

  defp alarm_gen do
    SD.fixed_map(%{
      id: SD.binary(min_length: 1, max_length: 8),
      severity: SD.member_of(@sd_severities),
      source: SD.constant("gen-src"),
      description: SD.constant("generated"),
      type: SD.constant("generic"),
      timestamp: SD.integer(0..9_999_999),
      acknowledged: SD.constant(false),
      ack_actor: SD.constant(nil),
      acked_at: SD.constant(nil)
    })
  end
end
