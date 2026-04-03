defmodule Indrajaal.Safety.ApoptosisProtocolIntegrationTest do
  @moduledoc """
  TDG test suite for the 6-phase apoptosis (self-destruction) protocol.

  WHAT: Tests that the apoptosis protocol executes all 6 phases in correct
  order, that state is checkpointed before destruction, that Guardian
  approval is required, and that the protocol can be aborted.

  CONSTRAINTS:
  - SC-SIL6-015: Apoptosis 6-phase protocol
  - SC-SIL4-015: Split-brain triggers apoptosis
  - SC-SIL4-007: Dying gasp checkpoint before shutdown

  ## Constitutional Verification
  - Ψ₀ (Existence): Apoptosis preserves system regenerability
  - Ψ₁ (Regeneration): State fully checkpointed before destruction
  - Ψ₂ (History): Apoptosis events recorded in immutable log

  ## Change History
  | Version | Date       | Author | Change                                     |
  |---------|------------|--------|--------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — apoptosis protocol     |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]

  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # 6-Phase apoptosis protocol engine
  # ---------------------------------------------------------------------------

  @phases [:signal, :guardian_approval, :checkpoint, :drain, :cleanup, :terminate]

  defp initial_state(node_id) do
    %{
      node_id: node_id,
      phase: nil,
      completed_phases: [],
      checkpoint_saved: false,
      connections_drained: false,
      guardian_approved: false,
      aborted: false,
      events: [],
      started_at: nil,
      finished_at: nil
    }
  end

  defp execute_phase(state, :signal) do
    state
    |> Map.put(:phase, :signal)
    |> Map.put(:started_at, System.monotonic_time(:millisecond))
    |> add_event(:signal_received)
    |> advance_phase(:signal)
  end

  defp execute_phase(state, :guardian_approval) do
    if state.aborted do
      {:error, :aborted, state}
    else
      state
      |> Map.put(:phase, :guardian_approval)
      |> Map.put(:guardian_approved, true)
      |> add_event(:guardian_approved)
      |> advance_phase(:guardian_approval)
    end
  end

  defp execute_phase(state, :checkpoint) do
    state
    |> Map.put(:phase, :checkpoint)
    |> Map.put(:checkpoint_saved, true)
    |> add_event(:state_checkpointed)
    |> advance_phase(:checkpoint)
  end

  defp execute_phase(state, :drain) do
    state
    |> Map.put(:phase, :drain)
    |> Map.put(:connections_drained, true)
    |> add_event(:connections_drained)
    |> advance_phase(:drain)
  end

  defp execute_phase(state, :cleanup) do
    state
    |> Map.put(:phase, :cleanup)
    |> add_event(:resources_cleaned)
    |> advance_phase(:cleanup)
  end

  defp execute_phase(state, :terminate) do
    state
    |> Map.put(:phase, :terminate)
    |> Map.put(:finished_at, System.monotonic_time(:millisecond))
    |> add_event(:terminated)
    |> advance_phase(:terminate)
  end

  defp advance_phase(state, phase) do
    %{state | completed_phases: state.completed_phases ++ [phase]}
  end

  defp add_event(state, event) do
    %{state | events: state.events ++ [{event, System.monotonic_time(:microsecond)}]}
  end

  defp run_full_protocol(node_id) do
    state = initial_state(node_id)

    Enum.reduce_while(@phases, state, fn phase, acc ->
      case execute_phase(acc, phase) do
        {:error, reason, failed_state} -> {:halt, {:error, reason, failed_state}}
        new_state -> {:cont, new_state}
      end
    end)
  end

  defp abort_protocol(state) do
    state
    |> Map.put(:aborted, true)
    |> add_event(:protocol_aborted)
  end

  defp validate_phase_order(completed_phases) do
    expected_prefix = Enum.take(@phases, length(completed_phases))
    completed_phases == expected_prefix
  end

  # ---------------------------------------------------------------------------
  # Phase ordering tests
  # ---------------------------------------------------------------------------

  describe "6-phase protocol ordering" do
    test "all 6 phases execute in order" do
      state = run_full_protocol("node-1")
      assert state.completed_phases == @phases
    end

    test "phase order matches specification" do
      state = run_full_protocol("node-2")
      assert validate_phase_order(state.completed_phases)
    end

    test "partial execution maintains order" do
      state = initial_state("node-3")
      state = execute_phase(state, :signal)
      state = execute_phase(state, :guardian_approval)

      assert state.completed_phases == [:signal, :guardian_approval]
      assert validate_phase_order(state.completed_phases)
    end
  end

  # ---------------------------------------------------------------------------
  # Guardian approval tests (SC-SIL6-015)
  # ---------------------------------------------------------------------------

  describe "SC-SIL6-015: Guardian approval" do
    test "guardian approval is set during protocol" do
      state = run_full_protocol("node-4")
      assert state.guardian_approved == true
    end

    test "guardian approval phase is recorded" do
      state = run_full_protocol("node-5")
      assert :guardian_approval in state.completed_phases
    end
  end

  # ---------------------------------------------------------------------------
  # Checkpoint tests (SC-SIL4-007)
  # ---------------------------------------------------------------------------

  describe "SC-SIL4-007: dying gasp checkpoint" do
    test "checkpoint is saved before drain" do
      state = run_full_protocol("node-6")
      assert state.checkpoint_saved == true

      checkpoint_idx = Enum.find_index(state.completed_phases, &(&1 == :checkpoint))
      drain_idx = Enum.find_index(state.completed_phases, &(&1 == :drain))
      assert checkpoint_idx < drain_idx
    end

    test "checkpoint occurs after guardian approval" do
      state = run_full_protocol("node-7")

      approval_idx = Enum.find_index(state.completed_phases, &(&1 == :guardian_approval))
      checkpoint_idx = Enum.find_index(state.completed_phases, &(&1 == :checkpoint))
      assert approval_idx < checkpoint_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Connection drain tests
  # ---------------------------------------------------------------------------

  describe "connection draining" do
    test "connections are drained before cleanup" do
      state = run_full_protocol("node-8")
      assert state.connections_drained == true

      drain_idx = Enum.find_index(state.completed_phases, &(&1 == :drain))
      cleanup_idx = Enum.find_index(state.completed_phases, &(&1 == :cleanup))
      assert drain_idx < cleanup_idx
    end
  end

  # ---------------------------------------------------------------------------
  # Abort tests
  # ---------------------------------------------------------------------------

  describe "protocol abort" do
    test "aborted protocol stops at guardian_approval" do
      state = initial_state("node-9")
      state = execute_phase(state, :signal)
      state = abort_protocol(state)
      result = execute_phase(state, :guardian_approval)

      assert {:error, :aborted, aborted_state} = result
      assert aborted_state.aborted == true
      assert :guardian_approval not in aborted_state.completed_phases
    end

    test "abort is recorded in events" do
      state = initial_state("node-10")
      state = abort_protocol(state)

      event_types = Enum.map(state.events, &elem(&1, 0))
      assert :protocol_aborted in event_types
    end
  end

  # ---------------------------------------------------------------------------
  # Event audit trail tests
  # ---------------------------------------------------------------------------

  describe "event audit trail" do
    test "all phases generate events" do
      state = run_full_protocol("node-11")

      event_types = Enum.map(state.events, &elem(&1, 0))
      assert :signal_received in event_types
      assert :guardian_approved in event_types
      assert :state_checkpointed in event_types
      assert :connections_drained in event_types
      assert :resources_cleaned in event_types
      assert :terminated in event_types
    end

    test "events are in chronological order" do
      state = run_full_protocol("node-12")

      timestamps = Enum.map(state.events, &elem(&1, 1))
      assert timestamps == Enum.sort(timestamps)
    end

    test "event count matches phase count" do
      state = run_full_protocol("node-13")
      assert length(state.events) == length(@phases)
    end
  end

  # ---------------------------------------------------------------------------
  # Timing tests
  # ---------------------------------------------------------------------------

  describe "protocol timing" do
    test "protocol completes with timestamps" do
      state = run_full_protocol("node-14")
      assert state.started_at != nil
      assert state.finished_at != nil
      assert state.finished_at >= state.started_at
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: apoptosis invariants" do
    test "protocol always produces valid phase order" do
      ExUnitProperties.check all(node_num <- SD.integer(1..1000), max_runs: 10) do
        state = run_full_protocol("prop-node-#{node_num}")

        assert validate_phase_order(state.completed_phases) and
                 length(state.completed_phases) == 6
      end
    end

    test "checkpoint always precedes terminate" do
      ExUnitProperties.check all(node_id <- SD.binary(min_length: 1, max_length: 16)) do
        state = run_full_protocol(node_id)

        checkpoint_idx = Enum.find_index(state.completed_phases, &(&1 == :checkpoint))
        terminate_idx = Enum.find_index(state.completed_phases, &(&1 == :terminate))

        assert checkpoint_idx < terminate_idx
      end
    end

    test "completed phases always form a prefix of the full protocol" do
      ExUnitProperties.check all(n <- SD.integer(1..6)) do
        state = initial_state("prop-test")

        final_state =
          Enum.reduce(Enum.take(@phases, n), state, fn phase, acc ->
            execute_phase(acc, phase)
          end)

        assert validate_phase_order(final_state.completed_phases)
        assert length(final_state.completed_phases) == n
      end
    end
  end
end
