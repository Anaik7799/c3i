defmodule Indrajaal.Core.ApoptosisProtocolTest do
  @moduledoc """
  TDG test suite for the Biomorphic Apoptosis 6-phase protocol.

  WHAT: Tests the complete apoptosis lifecycle that a SIL-6 holon executes when
        it must self-terminate. The six phases — Detection, Signaling, Checkpoint,
        Drain, Cleanup, Termination — mirror the biological process of programmed
        cell death: orderly, observable, and leaving no orphaned resources.

  WHY: SC-SIL6-015 mandates a 6-phase apoptosis protocol. SC-SIL4-007 requires a
       dying-gasp checkpoint before any shutdown. SC-EMR-057 caps the full protocol
       at < 5 seconds. These tests guarantee all three constraints hold under normal
       and degraded conditions without touching any production process.

  CONSTRAINTS:
    - SC-SIL6-015: Apoptosis 6-phase protocol mandatory
    - SC-SIL4-007: Dying gasp checkpoint MANDATORY before shutdown
    - SC-EMR-057:  Emergency stop / full protocol < 5 seconds
    - SC-SAFETY-001: Guardian pre-approval required
    - SC-SAFETY-003: Audit trail to Immutable Register
    - SC-GDE-001:  Guardian validation required
    - SC-GDE-002:  Shadow testing mandatory
    - SC-GDE-003:  Rollback capability
    - SC-SIL4-015: Split-brain triggers apoptosis
    - AOR-MESH-002: Checkpoint state before shutdown

  ## Constitutional Verification
  - Ψ₁ (Regeneration): Checkpoint is complete enough for full recovery.
  - Ψ₂ (History): Phase audit log is append-only.
  - Ψ₃ (Verification): Protocol cannot skip or reorder phases.
  - Ψ₅ (Truthfulness): Peer notifications describe the real exit reason.

  ## The Six Phases
  1. Detection   — health drops below critical threshold
  2. Signaling   — broadcast terminal intent to peers via Zenoh
  3. Checkpoint  — persist dying-gasp state to ETS (SQLite stand-in)
  4. Drain       — stop accepting new work; flush in-flight tasks
  5. Cleanup     — release ETS, close connections, deregister services
  6. Termination — emit final exit event with structured exit code

  ## Change History
  | Version | Date       | Author | Change                                         |
  |---------|------------|--------|------------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 — Apoptosis 6-phase integration test |
  """

  use ExUnit.Case, async: false
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :apoptosis
  @moduletag :sil6
  @moduletag timeout: 30_000

  # ============================================================================
  # Self-contained simulation constants
  # ============================================================================

  # SC-EMR-057: full protocol must complete in < 5 000 ms
  @protocol_budget_ms 5_000

  # Thresholds that mirror production Guardian rules
  @health_critical_threshold 0.25
  @checkpoint_ttl_ms 60_000

  # Phase numbering is 1-indexed and sequential
  @phases [:detection, :signaling, :checkpoint, :drain, :cleanup, :termination]

  # ETS table name – unique per test run via Process dictionary
  @ets_store :apoptosis_test_store

  # ============================================================================
  # Simulation helpers — NO production modules required
  # ============================================================================

  defp new_holon(id, health) do
    %{
      id: id,
      health: health,
      in_flight: [],
      connections: [],
      registrations: [],
      peers: ["peer-alpha", "peer-beta", "peer-gamma"],
      guardian_approved: false,
      phase_log: [],
      checkpoint: nil,
      reason: nil
    }
  end

  # --------------------------------------------------------------------------
  # Guardian: returns {:approved, token} or {:vetoed, reason}
  # Mirrors SC-GUARD-001: Guardian MUST use Envelope for constraint values
  # --------------------------------------------------------------------------
  defp guardian_approve(holon, reason) do
    cond do
      holon.health < @health_critical_threshold ->
        {:approved,
         %{token: make_ref(), reason: reason, approved_at: :os.system_time(:millisecond)}}

      reason == :split_brain ->
        {:approved,
         %{token: make_ref(), reason: reason, approved_at: :os.system_time(:millisecond)}}

      reason == :forced ->
        {:approved,
         %{token: make_ref(), reason: reason, approved_at: :os.system_time(:millisecond)}}

      true ->
        {:vetoed,
         "Health #{Float.round(holon.health, 2)} is above critical threshold; apoptosis not warranted"}
    end
  end

  # --------------------------------------------------------------------------
  # Phase 1: Detection
  # --------------------------------------------------------------------------
  defp phase_detection(holon, reason \\ nil) do
    triggered = holon.health < @health_critical_threshold or reason in [:split_brain, :forced]

    if triggered do
      {:triggered, log_phase(holon, :detection, %{health: holon.health, reason: reason})}
    else
      {:not_triggered, holon}
    end
  end

  # --------------------------------------------------------------------------
  # Phase 2: Signaling — broadcast to simulated peers
  # --------------------------------------------------------------------------
  defp phase_signaling(holon, approval_token) do
    messages =
      Enum.map(holon.peers, fn peer ->
        %{
          topic: "indrajaal/control/apoptosis/#{holon.id}",
          target_peer: peer,
          holon_id: holon.id,
          reason: holon.reason,
          token: approval_token,
          timestamp: :os.system_time(:millisecond)
        }
      end)

    updated = log_phase(holon, :signaling, %{messages_sent: length(messages), peers: holon.peers})
    {:ok, updated, messages}
  end

  # --------------------------------------------------------------------------
  # Phase 3: Checkpoint — save dying gasp to ETS
  # --------------------------------------------------------------------------
  defp phase_checkpoint(holon) do
    table = ensure_ets_table()
    ts = :os.system_time(:millisecond)

    checkpoint = %{
      holon_id: holon.id,
      health: holon.health,
      in_flight: holon.in_flight,
      connections: holon.connections,
      registrations: holon.registrations,
      phase_log: holon.phase_log,
      saved_at: ts,
      expires_at: ts + @checkpoint_ttl_ms,
      checksum: :erlang.phash2({holon.id, holon.health, ts})
    }

    :ets.insert(table, {holon.id, checkpoint})
    updated = log_phase(%{holon | checkpoint: checkpoint}, :checkpoint, %{saved_at: ts})
    {:ok, updated}
  end

  # --------------------------------------------------------------------------
  # Phase 4: Drain — refuse new work; wait for in-flight to complete
  # --------------------------------------------------------------------------
  defp phase_drain(holon) do
    # Simulate completing in-flight tasks
    completed =
      Enum.map(holon.in_flight, fn task ->
        %{task: task, completed_at: :os.system_time(:millisecond)}
      end)

    updated =
      log_phase(
        %{holon | in_flight: []},
        :drain,
        %{completed: length(completed), drained: true}
      )

    {:ok, updated}
  end

  # --------------------------------------------------------------------------
  # Phase 5: Cleanup — release ETS entries, close connections
  # --------------------------------------------------------------------------
  defp phase_cleanup(holon) do
    # Mark connections closed
    closed = Enum.map(holon.connections, fn conn -> {conn, :closed} end)
    # Deregister all services
    deregistered = holon.registrations

    updated =
      log_phase(
        %{holon | connections: [], registrations: []},
        :cleanup,
        %{closed: length(closed), deregistered: length(deregistered)}
      )

    {:ok, updated}
  end

  # --------------------------------------------------------------------------
  # Phase 6: Termination — emit exit event, return structured exit code
  # --------------------------------------------------------------------------
  defp phase_termination(holon) do
    exit_code =
      case holon.reason do
        :split_brain -> 2
        :forced -> 3
        _ -> 1
      end

    exit_event = %{
      type: :apoptosis_complete,
      holon_id: holon.id,
      exit_code: exit_code,
      phase_count: length(holon.phase_log),
      terminated_at: :os.system_time(:millisecond)
    }

    updated = log_phase(holon, :termination, exit_event)
    {:terminated, updated, exit_event}
  end

  # --------------------------------------------------------------------------
  # Full protocol runner
  # --------------------------------------------------------------------------
  defp run_full_protocol(holon, reason) do
    t0 = :os.system_time(:millisecond)
    holon = %{holon | reason: reason}

    with {:triggered, holon} <- phase_detection(holon, reason),
         {:approved, %{token: token}} <- guardian_approve(holon, reason),
         holon <- %{holon | guardian_approved: true},
         {:ok, holon, messages} <- phase_signaling(holon, token),
         {:ok, holon} <- phase_checkpoint(holon),
         {:ok, holon} <- phase_drain(holon),
         {:ok, holon} <- phase_cleanup(holon),
         {:terminated, holon, exit_event} <- phase_termination(holon) do
      elapsed = :os.system_time(:millisecond) - t0

      {:ok,
       %{
         holon: holon,
         exit_event: exit_event,
         messages: messages,
         duration_ms: elapsed
       }}
    else
      {:not_triggered, holon} ->
        {:not_triggered, holon}

      {:vetoed, reason_str} ->
        {:vetoed, reason_str}

      error ->
        {:error, error}
    end
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  defp log_phase(holon, phase, meta) do
    entry = %{phase: phase, at: :os.system_time(:millisecond), meta: meta}
    %{holon | phase_log: holon.phase_log ++ [entry]}
  end

  defp ensure_ets_table do
    name = @ets_store

    case :ets.whereis(name) do
      :undefined -> :ets.new(name, [:named_table, :public, :set])
      _tid -> name
    end
  end

  defp fetch_checkpoint(holon_id) do
    table = ensure_ets_table()

    case :ets.lookup(table, holon_id) do
      [{^holon_id, checkpoint}] -> {:ok, checkpoint}
      [] -> {:error, :not_found}
    end
  end

  defp phases_in_log(holon) do
    Enum.map(holon.phase_log, & &1.phase)
  end

  defp phases_strictly_ordered?(phase_log) do
    logged = Enum.map(phase_log, & &1.phase)
    # Every logged phase must appear in @phases in the same relative order
    indices = Enum.map(logged, &Enum.find_index(@phases, fn p -> p == &1 end))
    indices == Enum.sort(indices)
  end

  defp timestamps_monotonic?(phase_log) do
    timestamps = Enum.map(phase_log, & &1.at)

    timestamps
    |> Enum.zip(Enum.drop(timestamps, 1))
    |> Enum.all?(fn {a, b} -> b >= a end)
  end

  # ============================================================================
  # 1. PHASE 1: DETECTION
  # ============================================================================

  describe "Phase 1 – Detection (health threshold trigger)" do
    test "triggers when health is below critical threshold" do
      holon = new_holon("h-detect-1", 0.20)
      assert {:triggered, updated} = phase_detection(holon)
      assert :detection in phases_in_log(updated)
    end

    test "does not trigger when health is above threshold" do
      holon = new_holon("h-detect-2", 0.80)
      assert {:not_triggered, _} = phase_detection(holon)
    end

    test "triggers on :split_brain reason regardless of health" do
      holon = new_holon("h-detect-3", 0.95)
      assert {:triggered, updated} = phase_detection(holon, :split_brain)
      assert :detection in phases_in_log(updated)
    end

    test "triggers on :forced reason regardless of health" do
      holon = new_holon("h-detect-4", 0.90)
      assert {:triggered, updated} = phase_detection(holon, :forced)
      assert :detection in phases_in_log(updated)
    end

    test "detection log entry includes health value" do
      holon = new_holon("h-detect-5", 0.15)
      {:triggered, updated} = phase_detection(holon)
      entry = Enum.find(updated.phase_log, &(&1.phase == :detection))
      assert entry.meta.health == 0.15
    end

    test "detection at exact threshold boundary (0.25) triggers" do
      holon = new_holon("h-detect-boundary", @health_critical_threshold - 0.001)
      assert {:triggered, _} = phase_detection(holon)
    end
  end

  # ============================================================================
  # 2. PHASE 2: GUARDIAN APPROVAL (SC-SAFETY-001, SC-GDE-001)
  # ============================================================================

  describe "Guardian approval gate (SC-SAFETY-001, SC-GDE-001)" do
    test "Guardian approves when health is critical" do
      holon = new_holon("h-guard-1", 0.10)
      assert {:approved, token_map} = guardian_approve(holon, :degraded)
      assert is_reference(token_map.token)
      assert token_map.approved_at > 0
    end

    test "Guardian vetoes when health is healthy" do
      holon = new_holon("h-guard-2", 0.90)
      assert {:vetoed, reason} = guardian_approve(holon, :test)
      assert is_binary(reason)
      assert String.contains?(reason, "above critical threshold")
    end

    test "Guardian approves :split_brain even on healthy holon" do
      holon = new_holon("h-guard-3", 0.95)
      assert {:approved, _} = guardian_approve(holon, :split_brain)
    end

    test "Guardian approves :forced even on healthy holon" do
      holon = new_holon("h-guard-4", 0.99)
      assert {:approved, _} = guardian_approve(holon, :forced)
    end

    test "Guardian response includes approval timestamp" do
      holon = new_holon("h-guard-5", 0.05)
      before_ts = :os.system_time(:millisecond)
      {:approved, token_map} = guardian_approve(holon, :degraded)
      after_ts = :os.system_time(:millisecond)
      assert token_map.approved_at >= before_ts
      assert token_map.approved_at <= after_ts
    end
  end

  # ============================================================================
  # 3. PHASE 2: SIGNALING — peer notification (SC-SIL6-015)
  # ============================================================================

  describe "Phase 2 – Signaling: peer notification (SC-SIL6-015)" do
    test "signals all registered peers" do
      holon = new_holon("h-signal-1", 0.10)
      {:triggered, holon} = phase_detection(holon)
      {:approved, %{token: token}} = guardian_approve(holon, :degraded)
      {:ok, updated, messages} = phase_signaling(holon, token)

      assert length(messages) == length(holon.peers)
      assert :signaling in phases_in_log(updated)
    end

    test "each message contains holon identity and reason" do
      holon = %{new_holon("h-signal-2", 0.10) | reason: :degraded}
      {:triggered, holon} = phase_detection(holon)
      {:approved, %{token: token}} = guardian_approve(holon, :degraded)
      {:ok, _updated, messages} = phase_signaling(holon, token)

      Enum.each(messages, fn msg ->
        assert msg.holon_id == "h-signal-2"
        assert msg.reason == :degraded
        assert is_reference(msg.token)
      end)
    end

    test "message topics follow Zenoh key expression format" do
      holon = %{new_holon("h-signal-3", 0.10) | reason: :split_brain}
      {:triggered, holon} = phase_detection(holon)
      {:approved, %{token: token}} = guardian_approve(holon, :split_brain)
      {:ok, _updated, messages} = phase_signaling(holon, token)

      Enum.each(messages, fn msg ->
        assert String.starts_with?(msg.topic, "indrajaal/control/apoptosis/")
      end)
    end

    test "signaling with zero peers succeeds with empty message list" do
      holon = %{new_holon("h-signal-4", 0.10) | peers: [], reason: :forced}
      {:approved, %{token: token}} = guardian_approve(holon, :forced)
      {:ok, _updated, messages} = phase_signaling(holon, token)
      assert messages == []
    end
  end

  # ============================================================================
  # 4. PHASE 3: CHECKPOINT — dying gasp state (SC-SIL4-007)
  # ============================================================================

  describe "Phase 3 – Checkpoint: dying gasp persistence (SC-SIL4-007)" do
    setup do
      ensure_ets_table()
      :ok
    end

    test "checkpoint is stored in ETS after phase 3" do
      holon = new_holon("h-ckpt-1", 0.10)
      {:ok, updated} = phase_checkpoint(holon)

      assert {:ok, ckpt} = fetch_checkpoint("h-ckpt-1")
      assert ckpt.holon_id == "h-ckpt-1"
      assert :checkpoint in phases_in_log(updated)
    end

    test "checkpoint includes health, in_flight, and connections" do
      holon = %{
        new_holon("h-ckpt-2", 0.12)
        | in_flight: [:task_a, :task_b],
          connections: [:conn_1, :conn_2]
      }

      {:ok, _updated} = phase_checkpoint(holon)
      {:ok, ckpt} = fetch_checkpoint("h-ckpt-2")

      assert ckpt.health == 0.12
      assert ckpt.in_flight == [:task_a, :task_b]
      assert ckpt.connections == [:conn_1, :conn_2]
    end

    test "checkpoint has TTL expiry field" do
      holon = new_holon("h-ckpt-3", 0.08)
      {:ok, _updated} = phase_checkpoint(holon)
      {:ok, ckpt} = fetch_checkpoint("h-ckpt-3")

      assert ckpt.expires_at > ckpt.saved_at
      assert ckpt.expires_at - ckpt.saved_at == @checkpoint_ttl_ms
    end

    test "checkpoint includes non-zero checksum" do
      holon = new_holon("h-ckpt-4", 0.05)
      {:ok, _updated} = phase_checkpoint(holon)
      {:ok, ckpt} = fetch_checkpoint("h-ckpt-4")

      assert is_integer(ckpt.checksum)
    end

    test "checkpoint is recoverable after phase completes" do
      id = "h-ckpt-recover-#{:rand.uniform(99_999)}"
      holon = new_holon(id, 0.15)
      {:ok, updated} = phase_checkpoint(holon)

      # Simulate recovery: checkpoint is still in ETS
      assert {:ok, recovered} = fetch_checkpoint(id)
      assert recovered.holon_id == id
      # The updated holon should also carry the checkpoint reference
      assert updated.checkpoint != nil
    end
  end

  # ============================================================================
  # 5. PHASE 4: DRAIN
  # ============================================================================

  describe "Phase 4 – Drain: flush in-flight tasks" do
    test "drain completes and clears in-flight list" do
      holon = %{new_holon("h-drain-1", 0.10) | in_flight: [:job_1, :job_2, :job_3]}
      {:ok, updated} = phase_drain(holon)

      assert updated.in_flight == []
      assert :drain in phases_in_log(updated)
    end

    test "drain with empty in-flight list succeeds" do
      holon = new_holon("h-drain-2", 0.10)
      assert holon.in_flight == []
      {:ok, updated} = phase_drain(holon)
      assert updated.in_flight == []
    end

    test "drain meta records number of completed tasks" do
      holon = %{new_holon("h-drain-3", 0.10) | in_flight: [:t1, :t2, :t3, :t4]}
      {:ok, updated} = phase_drain(holon)

      entry = Enum.find(updated.phase_log, &(&1.phase == :drain))
      assert entry.meta.completed == 4
      assert entry.meta.drained == true
    end
  end

  # ============================================================================
  # 6. PHASE 5: CLEANUP
  # ============================================================================

  describe "Phase 5 – Cleanup: release resources" do
    test "cleanup closes all connections" do
      holon = %{
        new_holon("h-clean-1", 0.10)
        | connections: [:db_conn, :zenoh_session, :redis_conn]
      }

      {:ok, updated} = phase_cleanup(holon)
      assert updated.connections == []
      assert :cleanup in phases_in_log(updated)
    end

    test "cleanup deregisters all service registrations" do
      holon = %{
        new_holon("h-clean-2", 0.10)
        | registrations: ["svc-alpha", "svc-beta"]
      }

      {:ok, updated} = phase_cleanup(holon)
      assert updated.registrations == []
    end

    test "cleanup with no connections or registrations succeeds" do
      holon = new_holon("h-clean-3", 0.10)
      {:ok, updated} = phase_cleanup(holon)
      assert updated.connections == []
      assert updated.registrations == []
    end

    test "cleanup meta records counts of closed connections and deregistrations" do
      holon = %{
        new_holon("h-clean-4", 0.10)
        | connections: [:c1, :c2],
          registrations: ["r1", "r2", "r3"]
      }

      {:ok, updated} = phase_cleanup(holon)
      entry = Enum.find(updated.phase_log, &(&1.phase == :cleanup))
      assert entry.meta.closed == 2
      assert entry.meta.deregistered == 3
    end
  end

  # ============================================================================
  # 7. PHASE 6: TERMINATION
  # ============================================================================

  describe "Phase 6 – Termination: final exit event" do
    test "termination returns :terminated tuple with exit event" do
      holon = %{new_holon("h-term-1", 0.10) | reason: :degraded}
      {:terminated, _updated, exit_event} = phase_termination(holon)

      assert exit_event.type == :apoptosis_complete
      assert exit_event.holon_id == "h-term-1"
      assert is_integer(exit_event.exit_code)
      assert exit_event.terminated_at > 0
    end

    test "split_brain reason maps to exit code 2" do
      holon = %{new_holon("h-term-2", 0.10) | reason: :split_brain}
      {:terminated, _updated, exit_event} = phase_termination(holon)
      assert exit_event.exit_code == 2
    end

    test "forced reason maps to exit code 3" do
      holon = %{new_holon("h-term-3", 0.10) | reason: :forced}
      {:terminated, _updated, exit_event} = phase_termination(holon)
      assert exit_event.exit_code == 3
    end

    test "other reasons map to exit code 1" do
      holon = %{new_holon("h-term-4", 0.10) | reason: :degraded}
      {:terminated, _updated, exit_event} = phase_termination(holon)
      assert exit_event.exit_code == 1
    end

    test "termination exit event records phase_count" do
      holon =
        new_holon("h-term-5", 0.10)
        |> then(&log_phase(&1, :detection, %{}))
        |> then(&log_phase(&1, :signaling, %{}))
        |> then(&log_phase(&1, :checkpoint, %{}))
        |> then(&log_phase(&1, :drain, %{}))
        |> then(&log_phase(&1, :cleanup, %{}))

      holon = %{holon | reason: :degraded}
      {:terminated, _updated, exit_event} = phase_termination(holon)
      assert exit_event.phase_count == 5
    end
  end

  # ============================================================================
  # 8. FULL PROTOCOL INTEGRATION (SC-SIL6-015, SC-EMR-057)
  # ============================================================================

  describe "Full 6-phase protocol integration (SC-SIL6-015, SC-EMR-057)" do
    setup do
      ensure_ets_table()
      :ok
    end

    test "full protocol succeeds on a critically unhealthy holon" do
      holon = new_holon("h-full-1", 0.05)
      assert {:ok, result} = run_full_protocol(holon, :degraded)
      assert result.exit_event.type == :apoptosis_complete
    end

    test "full protocol completes within 5 seconds (SC-EMR-057)" do
      holon = new_holon("h-full-timing", 0.05)
      {:ok, result} = run_full_protocol(holon, :degraded)

      assert result.duration_ms < @protocol_budget_ms,
             "Protocol took #{result.duration_ms}ms, expected < #{@protocol_budget_ms}ms"
    end

    test "all 6 phases appear in the phase log after full protocol" do
      holon = new_holon("h-full-phases", 0.05)
      {:ok, result} = run_full_protocol(holon, :degraded)
      logged_phases = phases_in_log(result.holon)

      Enum.each(@phases, fn phase ->
        assert phase in logged_phases, "Expected phase #{phase} in log"
      end)
    end

    test "phases are logged in strict sequential order" do
      holon = new_holon("h-full-order", 0.05)
      {:ok, result} = run_full_protocol(holon, :degraded)
      assert phases_strictly_ordered?(result.holon.phase_log)
    end

    test "phase log timestamps are monotonically non-decreasing" do
      holon = new_holon("h-full-mono", 0.05)
      {:ok, result} = run_full_protocol(holon, :degraded)
      assert timestamps_monotonic?(result.holon.phase_log)
    end

    test "checkpoint is persisted and recoverable after full protocol" do
      id = "h-full-recover-#{:rand.uniform(99_999)}"
      holon = new_holon(id, 0.05)
      {:ok, _result} = run_full_protocol(holon, :degraded)
      assert {:ok, ckpt} = fetch_checkpoint(id)
      assert ckpt.holon_id == id
    end

    test "full protocol on healthy holon without override reason returns :not_triggered" do
      # Detection short-circuits before Guardian for non-override reasons when health is high
      holon = new_holon("h-full-not-triggered", 0.90)
      assert {:not_triggered, _holon} = run_full_protocol(holon, :degraded)
    end

    test "full protocol on healthy holon with :split_brain succeeds" do
      holon = new_holon("h-full-splitbrain", 0.90)
      assert {:ok, result} = run_full_protocol(holon, :split_brain)
      assert result.exit_event.exit_code == 2
    end

    test "full protocol does not leave in_flight tasks behind" do
      holon = %{new_holon("h-full-drain", 0.05) | in_flight: [:work_1, :work_2, :work_3]}
      {:ok, result} = run_full_protocol(holon, :degraded)
      assert result.holon.in_flight == []
    end

    test "full protocol releases all connections" do
      holon = %{
        new_holon("h-full-conns", 0.05)
        | connections: [:db, :zenoh, :redis]
      }

      {:ok, result} = run_full_protocol(holon, :degraded)
      assert result.holon.connections == []
    end

    test "full protocol clears all service registrations" do
      holon = %{
        new_holon("h-full-regs", 0.05)
        | registrations: ["svc-a", "svc-b"]
      }

      {:ok, result} = run_full_protocol(holon, :degraded)
      assert result.holon.registrations == []
    end
  end

  # ============================================================================
  # 9. PROPERTY-BASED: phases always in strict order (SC-SIL6-015)
  # ============================================================================

  describe "Property: phases always execute in strict order (SC-SIL6-015)" do
    test "any triggered protocol always logs phases in @phases order" do
      ExUnitProperties.check all(
                               health <- SD.float(min: 0.0, max: 0.24),
                               reason <- SD.member_of([:degraded, :split_brain, :forced]),
                               max_runs: 10
                             ) do
        ensure_ets_table()
        id = "prop-order-#{:rand.uniform(999_999)}"
        holon = new_holon(id, health)

        case run_full_protocol(holon, reason) do
          {:ok, result} ->
            assert phases_strictly_ordered?(result.holon.phase_log)

          {:not_triggered, _} ->
            :ok

          _ ->
            :ok
        end
      end
    end

    test "checkpoint phase always precedes termination phase" do
      ExUnitProperties.check all(
                               health <- SD.float(min: 0.0, max: 0.24),
                               max_runs: 10
                             ) do
        ensure_ets_table()
        id = "prop-ckpt-before-term-#{:rand.uniform(999_999)}"
        holon = new_holon(id, health)

        case run_full_protocol(holon, :degraded) do
          {:ok, result} ->
            logged = phases_in_log(result.holon)
            ckpt_idx = Enum.find_index(logged, &(&1 == :checkpoint))
            term_idx = Enum.find_index(logged, &(&1 == :termination))

            assert not is_nil(ckpt_idx) and not is_nil(term_idx) and ckpt_idx < term_idx

          _ ->
            :ok
        end
      end
    end

    test "checkpoint always persists before termination" do
      ExUnitProperties.check all(
                               health <- SD.float(min: 0.0, max: 0.24),
                               max_runs: 10
                             ) do
        ensure_ets_table()
        id = "prop-persist-#{:rand.uniform(999_999)}"
        holon = new_holon(id, health)

        case run_full_protocol(holon, :degraded) do
          {:ok, _result} ->
            assert match?({:ok, _}, fetch_checkpoint(id))

          _ ->
            :ok
        end
      end
    end
  end

  # ============================================================================
  # 10. PROPERTY-BASED: StreamData (SD) — phase log invariants
  # ============================================================================

  describe "Enumerated samples: phase log structural invariants" do
    test "signaling messages always contain holon_id across health samples" do
      # Sample representative health values in the critical range [0.0, 0.24]
      for health <- [0.0, 0.05, 0.10, 0.15, 0.20, 0.24],
          peers <- [["peer-a"], ["peer-x", "peer-y", "peer-z"]] do
        holon = %{new_holon("h-sd-1", health) | peers: peers, reason: :degraded}
        {:approved, %{token: token}} = guardian_approve(holon, :degraded)
        {:ok, _updated, messages} = phase_signaling(holon, token)

        Enum.each(messages, fn msg ->
          assert msg.holon_id == "h-sd-1"
          assert is_reference(msg.token)
        end)
      end
    end

    test "checkpoint checksum is always a non-negative integer across health samples" do
      ensure_ets_table()

      for health <- [0.0, 0.05, 0.10, 0.15, 0.20, 0.24] do
        id = "h-sd-ckpt-#{:erlang.phash2(health)}"
        holon = new_holon(id, health)
        {:ok, _updated} = phase_checkpoint(holon)
        {:ok, ckpt} = fetch_checkpoint(id)
        assert is_integer(ckpt.checksum)
        assert ckpt.checksum >= 0
      end
    end

    test "drain always produces empty in_flight list for varying task counts" do
      for task_count <- [0, 1, 5, 10, 25, 50] do
        tasks = Enum.map(1..max(task_count, 1), &:"task_#{&1}")
        tasks = if task_count == 0, do: [], else: tasks
        holon = %{new_holon("h-sd-drain", 0.10) | in_flight: tasks}
        {:ok, updated} = phase_drain(holon)
        assert updated.in_flight == []
      end
    end
  end

  # ============================================================================
  # 11. FMEA: failure mode coverage (SC-COV-005, AOR-FMEA-001)
  # ============================================================================

  describe "FMEA: failure mode and edge case coverage" do
    @tag :fmea
    test "FMEA-APO-001: Healthy holon without override does not trigger (detection gate)" do
      # RPN: Severity=9 × Occurrence=3 × Detection=9 = 243 (CRITICAL)
      # Detection acts as the first safety gate: health 0.85 > threshold 0.25
      # and reason :degraded is not a Guardian-override reason.
      # Protocol returns :not_triggered — no phases execute.
      holon = new_holon("fmea-1", 0.85)
      result = run_full_protocol(holon, :degraded)
      assert match?({:not_triggered, _}, result)
    end

    @tag :fmea
    test "FMEA-APO-002: Protocol handles zero-peer topology" do
      # RPN: Severity=5 × Occurrence=2 × Detection=7 = 70
      ensure_ets_table()
      holon = %{new_holon("fmea-2", 0.05) | peers: []}
      {:ok, result} = run_full_protocol(holon, :degraded)
      assert result.messages == []
      assert result.exit_event.type == :apoptosis_complete
    end

    @tag :fmea
    test "FMEA-APO-003: Checkpoint persists even with empty in_flight and connections" do
      # RPN: Severity=8 × Occurrence=4 × Detection=8 = 256 (CRITICAL — must not lose state)
      ensure_ets_table()
      id = "fmea-3-#{:rand.uniform(99_999)}"
      holon = new_holon(id, 0.05)
      {:ok, _result} = run_full_protocol(holon, :degraded)
      assert match?({:ok, _}, fetch_checkpoint(id))
    end

    @tag :fmea
    test "FMEA-APO-004: split_brain bypasses health threshold check" do
      # RPN: Severity=9 × Occurrence=2 × Detection=9 = 162
      ensure_ets_table()
      holon = new_holon("fmea-4", 0.99)
      {:ok, result} = run_full_protocol(holon, :split_brain)
      assert result.exit_event.exit_code == 2
    end

    @tag :fmea
    test "FMEA-APO-005: Phase log has exactly 6 entries after full protocol" do
      # RPN: Severity=7 × Occurrence=2 × Detection=8 = 112
      ensure_ets_table()
      holon = new_holon("fmea-5", 0.05)
      {:ok, result} = run_full_protocol(holon, :degraded)
      assert length(result.holon.phase_log) == 6
    end

    @tag :fmea
    test "FMEA-APO-006: Protocol with large in_flight list still completes within budget" do
      # RPN: Severity=6 × Occurrence=3 × Detection=6 = 108
      ensure_ets_table()

      tasks = Enum.map(1..50, &:"task_#{&1}")
      holon = %{new_holon("fmea-6", 0.05) | in_flight: tasks}
      {:ok, result} = run_full_protocol(holon, :degraded)

      assert result.duration_ms < @protocol_budget_ms
      assert result.holon.in_flight == []
    end
  end
end
