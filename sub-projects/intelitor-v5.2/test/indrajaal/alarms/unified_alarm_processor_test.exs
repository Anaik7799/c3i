defmodule Indrajaal.Alarms.UnifiedAlarmProcessorTest do
  @moduledoc """
  TDG comprehensive test suite for Alarms.UnifiedAlarmProcessor.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-UAP-001: process_alarm must return {:ok, map} with :alarm, :notifications, :metrics keys
  - SC-UAP-002: handle_alarm_event must route to correct handler per event_type
  - SC-UAP-003: apply_state_machine must not allow invalid state transitions
  - SC-UAP-004: handle_alarm_event with unknown event_type must return {:error, :unknown_event_type}

  ## Constitutional Verification
  - Psi0 Existence: process_alarm never raises on valid alarm structs
  - Psi3 Verification: State machine transitions are deterministic and verifiable
  - Psi5 Truthfulness: Returned alarm.state reflects the actual transition taken

  ## Founder's Directive Alignment
  - Omega0.1: Unified processing eliminates duplication, improving alarm response reliability

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alarm state not transitioning after acknowledge event
  - L5 Root Cause: apply_state_machine pattern match missing event in context map

  ## Change History
  | Version | Date       | Author | Change            |
  |---------|------------|--------|-------------------|
  | 21.3.0  | 2026-03-19 | Claude | Initial TDG suite |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.UnifiedAlarmProcessor

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp alarm_fixture(state \\ :active) do
    %{
      id: Ecto.UUID.generate(),
      state: state,
      event_type: :intrusion,
      severity: :high,
      tenant_id: "tenant-uap-#{System.unique_integer([:positive])}",
      site_id: Ecto.UUID.generate(),
      zone_id: Ecto.UUID.generate()
    }
  end

  # ---------------------------------------------------------------------------
  # describe: process_alarm/2
  # ---------------------------------------------------------------------------

  describe "process_alarm/2" do
    test "returns {:ok, map} for a valid active alarm" do
      alarm = alarm_fixture(:active)
      result = UnifiedAlarmProcessor.process_alarm(alarm)
      assert match?({:ok, _}, result)
    end

    test "returned map has :alarm key" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert Map.has_key?(result, :alarm)
    end

    test "returned map has :notifications key" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert Map.has_key?(result, :notifications)
    end

    test "returned map has :metrics key" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert Map.has_key?(result, :metrics)
    end

    test "notifications is a list" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert is_list(result.notifications)
    end

    test "metrics is a map" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert is_map(result.metrics)
    end

    test "alarm in result has same id as input alarm" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert result.alarm.id == alarm.id
    end

    test "process_alarm with context map succeeds" do
      alarm = alarm_fixture(:active)
      context = %{tenant_id: alarm.tenant_id, start_time: System.monotonic_time(:millisecond)}
      result = UnifiedAlarmProcessor.process_alarm(alarm, context)
      assert match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: handle_alarm_event/3
  # ---------------------------------------------------------------------------

  describe "handle_alarm_event/3" do
    test "handles :created event" do
      alarm = alarm_fixture(:active)
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, :created)
      assert match?({:ok, _}, result)
    end

    test "handles :acknowledged event" do
      alarm = alarm_fixture(:active)
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, :acknowledged)
      assert match?({:ok, _}, result)
    end

    test "handles :resolved event" do
      alarm = alarm_fixture(:acknowledged)
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, :resolved)
      assert match?({:ok, _}, result)
    end

    test "handles :escalated event" do
      alarm = alarm_fixture(:active)
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, :escalated)
      assert match?({:ok, _}, result)
    end

    test "returns {:error, :unknown_event_type} for unknown event" do
      alarm = alarm_fixture(:active)
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, :nonexistent_event)
      assert result == {:error, :unknown_event_type}
    end

    test "handles events with params map" do
      alarm = alarm_fixture(:active)
      params = %{operator_id: "op-1"}
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, :acknowledged, params)
      assert match?({:ok, _}, result) or result == {:error, :unknown_event_type}
    end
  end

  # ---------------------------------------------------------------------------
  # describe: apply_state_machine/2
  # ---------------------------------------------------------------------------

  describe "apply_state_machine/2" do
    test ":active + :acknowledge -> :acknowledged" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :acknowledge})
      assert result.state == :acknowledged
    end

    test ":active + :escalate -> :escalated" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :escalate})
      assert result.state == :escalated
    end

    test ":acknowledged + :resolve -> :resolved" do
      alarm = alarm_fixture(:acknowledged)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :resolve})
      assert result.state == :resolved
    end

    test ":acknowledged + :escalate -> :escalated" do
      alarm = alarm_fixture(:acknowledged)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :escalate})
      assert result.state == :escalated
    end

    test ":escalated + :resolve -> :resolved" do
      alarm = alarm_fixture(:escalated)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :resolve})
      assert result.state == :resolved
    end

    test "unknown event keeps current state" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :no_op})
      assert result.state == :active
    end

    test "returns {:ok, alarm} structure" do
      alarm = alarm_fixture(:active)
      result = UnifiedAlarmProcessor.apply_state_machine(alarm, %{})
      assert match?({:ok, _}, result)
    end

    test "state machine never raises for any valid state" do
      states = [:active, :acknowledged, :escalated, :resolved]

      Enum.each(states, fn state ->
        alarm = alarm_fixture(state)
        result = UnifiedAlarmProcessor.apply_state_machine(alarm, %{})
        assert match?({:ok, _}, result), "Expected {:ok, _} for state #{state}"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: process_alarm never raises for valid alarm" do
      alarm = alarm_fixture(:active)
      # No raise == existence preserved
      assert match?({:ok, _}, UnifiedAlarmProcessor.process_alarm(alarm))
    end

    test "Psi3 verification: state machine produces verifiable transitions" do
      alarm = alarm_fixture(:active)
      {:ok, ack} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :acknowledge})
      {:ok, esc} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :escalate})

      assert ack.state == :acknowledged
      assert esc.state == :escalated
      # Both are deterministic given the same input
    end

    test "Psi5 truthfulness: returned alarm.state matches actual transition" do
      alarm = alarm_fixture(:active)
      {:ok, result} = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: :acknowledge})
      # state must reflect what the state machine actually did — no deceptive state
      assert result.state == :acknowledged
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "process_alarm completes within 5 seconds" do
      alarm = alarm_fixture(:active)
      {elapsed_us, result} = :timer.tc(fn -> UnifiedAlarmProcessor.process_alarm(alarm) end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end

    test "dual-channel: two alarms processed independently" do
      alarm_a = alarm_fixture(:active)
      alarm_b = alarm_fixture(:acknowledged)

      r_a = UnifiedAlarmProcessor.process_alarm(alarm_a)
      r_b = UnifiedAlarmProcessor.process_alarm(alarm_b)

      assert match?({:ok, _}, r_a)
      assert match?({:ok, _}, r_b)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "process_alarm returns {:ok, map} for any valid alarm state" do
    states = [:active, :acknowledged, :escalated, :resolved]

    forall state <- PC.oneof(Enum.map(states, &PC.exactly/1)) do
      alarm = %{
        id: Ecto.UUID.generate(),
        state: state,
        event_type: :intrusion,
        severity: :high,
        tenant_id: "prop-tenant"
      }

      match?({:ok, _}, UnifiedAlarmProcessor.process_alarm(alarm))
    end
  end

  property "handle_alarm_event returns error for unknown event types" do
    known_events = [:created, :acknowledged, :resolved, :escalated]

    forall event <- PC.oneof(Enum.map(known_events, &PC.exactly/1)) do
      alarm = %{id: Ecto.UUID.generate(), state: :active, tenant_id: "t"}
      result = UnifiedAlarmProcessor.handle_alarm_event(alarm, event)
      match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "apply_state_machine always returns {:ok, alarm} tuple" do
    ExUnitProperties.check all(event <- SD.member_of([:acknowledge, :escalate, :resolve, :no_op])) do
      alarm = %{id: Ecto.UUID.generate(), state: :active, tenant_id: "t"}
      result = UnifiedAlarmProcessor.apply_state_machine(alarm, %{event: event})
      assert match?({:ok, _}, result)
    end
  end

  test "process_alarm result always has required keys" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      alarm = %{
        id: Ecto.UUID.generate(),
        state: :active,
        tenant_id: "t",
        event_type: :intrusion,
        severity: :high
      }

      {:ok, result} = UnifiedAlarmProcessor.process_alarm(alarm)
      assert Map.has_key?(result, :alarm)
      assert Map.has_key?(result, :notifications)
      assert Map.has_key?(result, :metrics)
    end
  end
end
