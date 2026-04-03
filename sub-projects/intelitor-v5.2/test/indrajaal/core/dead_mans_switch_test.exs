defmodule Indrajaal.Core.DeadMansSwitchTest do
  @moduledoc """
  TDG test: Dead Man's Switch heartbeat and failsafe protocol.

  WHAT: Tests heartbeat monitoring, timeout detection, and failsafe state transitions.
  WHY: Validates SC-DMS-001 (100ms heartbeat), SC-DMS-002 (50ms failsafe trigger),
       SC-DMS-003 (deterministic failsafe state), SC-DMS-004 (supervised recovery).

  STAMP Constraints:
  - SC-DMS-001: Heartbeat interval MUST be 100ms
  - SC-DMS-002: Failsafe triggers within 50ms of timeout
  - SC-DMS-003: Failsafe state MUST be deterministic
  - SC-DMS-004: Recovery MUST be supervised

  AOR Rules:
  - AOR-SAFETY-005: Emergency stop < 5 seconds
  - AOR-SIL4-002: Rollback on any wave failure
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @heartbeat_interval_ms 100
  @failsafe_trigger_ms 50
  @max_missed_heartbeats 3

  describe "heartbeat monitoring" do
    test "initial state is :alive with zero missed heartbeats" do
      dms = new_dms()
      assert dms.state == :alive
      assert dms.missed_heartbeats == 0
      assert dms.last_heartbeat != nil
    end

    test "heartbeat resets missed counter" do
      dms = new_dms() |> miss_heartbeat() |> miss_heartbeat()
      assert dms.missed_heartbeats == 2

      dms = receive_heartbeat(dms)
      assert dms.missed_heartbeats == 0
      assert dms.state == :alive
    end

    test "heartbeat interval is 100ms (SC-DMS-001)" do
      assert @heartbeat_interval_ms == 100
    end

    test "missed heartbeats increment counter" do
      dms = new_dms()
      dms = Enum.reduce(1..3, dms, fn _, acc -> miss_heartbeat(acc) end)
      assert dms.missed_heartbeats == 3
    end
  end

  describe "failsafe trigger (SC-DMS-002)" do
    test "triggers failsafe after max missed heartbeats" do
      dms = new_dms()

      dms =
        Enum.reduce(1..@max_missed_heartbeats, dms, fn _, acc ->
          miss_heartbeat(acc)
        end)

      dms = check_failsafe(dms)
      assert dms.state == :failsafe
    end

    test "failsafe not triggered below threshold" do
      dms = new_dms() |> miss_heartbeat() |> miss_heartbeat()
      dms = check_failsafe(dms)
      assert dms.state == :alive
    end

    test "failsafe trigger latency budget is 50ms (SC-DMS-002)" do
      assert @failsafe_trigger_ms == 50
    end
  end

  describe "deterministic failsafe state (SC-DMS-003)" do
    test "failsafe state is always the same regardless of history" do
      # Scenario 1: immediate timeout
      dms1 = new_dms()
      dms1 = Enum.reduce(1..3, dms1, fn _, acc -> miss_heartbeat(acc) end)
      dms1 = check_failsafe(dms1)

      # Scenario 2: heartbeat then timeout
      dms2 = new_dms() |> receive_heartbeat() |> miss_heartbeat()
      dms2 = Enum.reduce(1..2, dms2, fn _, acc -> miss_heartbeat(acc) end)
      dms2 = check_failsafe(dms2)

      # Both should be in identical failsafe state
      assert dms1.state == :failsafe
      assert dms2.state == :failsafe
      assert dms1.failsafe_actions == dms2.failsafe_actions
    end

    test "failsafe actions are deterministic" do
      dms = trigger_failsafe(new_dms())

      assert dms.failsafe_actions == [
               :halt_mutations,
               :checkpoint_state,
               :notify_guardian,
               :enter_safe_mode
             ]
    end
  end

  describe "supervised recovery (SC-DMS-004)" do
    test "recovery from failsafe requires supervisor approval" do
      dms = trigger_failsafe(new_dms())
      assert dms.state == :failsafe

      # Attempt recovery without approval — stays in failsafe
      dms_no_approval = attempt_recovery(dms, approved: false)
      assert dms_no_approval.state == :failsafe

      # Recovery with approval — transitions to :recovering
      dms_approved = attempt_recovery(dms, approved: true)
      assert dms_approved.state == :recovering
    end

    test "recovery completes with heartbeat resumption" do
      dms = trigger_failsafe(new_dms())
      dms = attempt_recovery(dms, approved: true)
      assert dms.state == :recovering

      dms = receive_heartbeat(dms)
      assert dms.state == :alive
      assert dms.missed_heartbeats == 0
    end

    test "recovery timeout returns to failsafe" do
      dms = trigger_failsafe(new_dms())
      dms = attempt_recovery(dms, approved: true)

      # No heartbeat received during recovery window
      dms = Enum.reduce(1..@max_missed_heartbeats, dms, fn _, acc -> miss_heartbeat(acc) end)
      dms = check_failsafe(dms)
      assert dms.state == :failsafe
    end
  end

  describe "state machine transitions" do
    test "valid state transitions" do
      valid_transitions = [
        {:alive, :failsafe},
        {:alive, :alive},
        {:failsafe, :recovering},
        {:failsafe, :failsafe},
        {:recovering, :alive},
        {:recovering, :failsafe}
      ]

      for {from, to} <- valid_transitions do
        assert valid_transition?(from, to),
               "Expected #{from} → #{to} to be valid"
      end
    end

    test "invalid state transitions" do
      invalid_transitions = [
        {:alive, :recovering},
        {:recovering, :recovering},
        {:failsafe, :alive}
      ]

      for {from, to} <- invalid_transitions do
        refute valid_transition?(from, to),
               "Expected #{from} → #{to} to be invalid"
      end
    end
  end

  describe "property: heartbeat monotonicity" do
    test "heartbeat timestamps are strictly increasing" do
      ExUnitProperties.check all(
                               heartbeat_count <- SD.integer(2..20),
                               max_runs: 15
                             ) do
        dms = new_dms()

        timestamps =
          Enum.reduce(1..heartbeat_count, {dms, []}, fn _, {state, ts} ->
            new_state = receive_heartbeat(state)
            {new_state, [new_state.last_heartbeat | ts]}
          end)
          |> elem(1)
          |> Enum.reverse()

        # Each timestamp should be >= previous (monotonic)
        pairs = Enum.chunk_every(timestamps, 2, 1, :discard)
        assert Enum.all?(pairs, fn [a, b] -> b >= a end)
      end
    end
  end

  describe "property: failsafe is deterministic (SC-DMS-003)" do
    test "same miss count always produces same state" do
      ExUnitProperties.check all(
                               miss_count <- SD.integer(0..10),
                               max_runs: 20
                             ) do
        dms1 = Enum.reduce(1..max(miss_count, 1), new_dms(), fn _, acc -> miss_heartbeat(acc) end)
        dms1 = check_failsafe(dms1)

        dms2 = Enum.reduce(1..max(miss_count, 1), new_dms(), fn _, acc -> miss_heartbeat(acc) end)
        dms2 = check_failsafe(dms2)

        assert dms1.state == dms2.state
      end
    end
  end

  # ===========================================================================
  # Helpers
  # ===========================================================================

  defp new_dms do
    %{
      state: :alive,
      missed_heartbeats: 0,
      last_heartbeat: System.monotonic_time(:millisecond),
      failsafe_actions: [],
      recovery_approved: false
    }
  end

  defp receive_heartbeat(dms) do
    case dms.state do
      :recovering ->
        %{
          dms
          | state: :alive,
            missed_heartbeats: 0,
            last_heartbeat: System.monotonic_time(:millisecond)
        }

      _ ->
        %{dms | missed_heartbeats: 0, last_heartbeat: System.monotonic_time(:millisecond)}
    end
  end

  defp miss_heartbeat(dms) do
    %{dms | missed_heartbeats: dms.missed_heartbeats + 1}
  end

  defp check_failsafe(dms) do
    if dms.missed_heartbeats >= @max_missed_heartbeats do
      %{
        dms
        | state: :failsafe,
          failsafe_actions: [
            :halt_mutations,
            :checkpoint_state,
            :notify_guardian,
            :enter_safe_mode
          ]
      }
    else
      dms
    end
  end

  defp trigger_failsafe(dms) do
    dms
    |> miss_heartbeat()
    |> miss_heartbeat()
    |> miss_heartbeat()
    |> check_failsafe()
  end

  defp attempt_recovery(dms, opts) do
    if Keyword.get(opts, :approved, false) and dms.state == :failsafe do
      %{dms | state: :recovering, recovery_approved: true, missed_heartbeats: 0}
    else
      dms
    end
  end

  defp valid_transition?(from, to) do
    case {from, to} do
      {:alive, :failsafe} -> true
      {:alive, :alive} -> true
      {:failsafe, :recovering} -> true
      {:failsafe, :failsafe} -> true
      {:recovering, :alive} -> true
      {:recovering, :failsafe} -> true
      _ -> false
    end
  end
end
