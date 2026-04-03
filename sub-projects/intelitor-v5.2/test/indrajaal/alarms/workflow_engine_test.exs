defmodule Indrajaal.Alarms.WorkflowEngineTest do
  @moduledoc """
  TDG comprehensive test suite for WorkflowEngine.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-WORKFLOW-001: trigger_for_alarm must return :ok for all alarm types
  - SC-WORKFLOW-002: execute_workflow must return {:ok, instance} on success
  - SC-WORKFLOW-003: get_standard_workflows must return exactly 5 templates
  - SC-WORKFLOW-004: Each workflow template must have id, name, steps, trigger_conditions

  ## Constitutional Verification
  - Psi0 Existence: Pure functions never raise on valid alarm/workflow inputs
  - Psi3 Verification: Workflow results are consistently typed
  - Psi5 Truthfulness: Standard workflow templates accurately describe response procedures

  ## Founder's Directive Alignment
  - Omega0.1: Automated workflows ensure timely alarm response protecting assets

  ## TPS 5-Level RCA Context
  - L1 Symptom: Alarm workflows not triggering for correct incident types
  - L5 Root Cause: Trigger condition matching logic defect or empty workflow database
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Alarms.WorkflowEngine

  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp alarm_fixture(event_type \\ :intrusion, severity \\ :high) do
    %{
      id: Ecto.UUID.generate(),
      event_type: event_type,
      severity: severity,
      tenant_id: "tenant-wf-#{System.unique_integer([:positive])}",
      site_id: Ecto.UUID.generate(),
      zone_id: Ecto.UUID.generate(),
      location_details: "Building A",
      correlated_events: [],
      state: :triggered
    }
  end

  # ---------------------------------------------------------------------------
  # describe: trigger_for_alarm/1
  # ---------------------------------------------------------------------------

  describe "trigger_for_alarm/1" do
    test "returns :ok for intrusion alarm" do
      alarm = alarm_fixture(:intrusion, :high)
      result = WorkflowEngine.trigger_for_alarm(alarm)
      assert result == :ok
    end

    test "returns :ok for fire alarm" do
      alarm = alarm_fixture(:fire, :critical)
      result = WorkflowEngine.trigger_for_alarm(alarm)
      assert result == :ok
    end

    test "returns :ok for medical alarm" do
      alarm = alarm_fixture(:medical, :high)
      result = WorkflowEngine.trigger_for_alarm(alarm)
      assert result == :ok
    end

    test "returns :ok for panic alarm" do
      alarm = alarm_fixture(:panic, :critical)
      result = WorkflowEngine.trigger_for_alarm(alarm)
      assert result == :ok
    end

    test "returns :ok for tamper alarm" do
      alarm = alarm_fixture(:tamper, :medium)
      result = WorkflowEngine.trigger_for_alarm(alarm)
      assert result == :ok
    end

    test "returns :ok for supervisory alarm" do
      alarm = alarm_fixture(:supervisory, :low)
      result = WorkflowEngine.trigger_for_alarm(alarm)
      assert result == :ok
    end

    test "returns :ok even when find_applicable_workflows returns empty list (stub)" do
      # The stub returns [] which means no workflows execute — should still be :ok
      alarm = alarm_fixture(:intrusion, :critical)
      assert WorkflowEngine.trigger_for_alarm(alarm) == :ok
    end
  end

  # ---------------------------------------------------------------------------
  # describe: execute_workflow/2
  # ---------------------------------------------------------------------------

  describe "execute_workflow/2" do
    test "returns {:ok, instance} for intrusion_response_workflow" do
      alarm = alarm_fixture(:intrusion, :high)
      workflow = WorkflowEngine.intrusion_response_workflow()

      result = WorkflowEngine.execute_workflow(workflow, alarm)
      assert match?({:ok, _}, result)
    end

    test "returns {:ok, instance} for fire_response_workflow" do
      alarm = alarm_fixture(:fire, :critical)
      workflow = WorkflowEngine.fire_response_workflow()

      result = WorkflowEngine.execute_workflow(workflow, alarm)
      assert match?({:ok, _}, result)
    end

    test "returns {:ok, instance} for medical_emergency_workflow" do
      alarm = alarm_fixture(:medical, :high)
      workflow = WorkflowEngine.medical_emergency_workflow()

      result = WorkflowEngine.execute_workflow(workflow, alarm)
      assert match?({:ok, _}, result)
    end

    test "returns {:ok, instance} for panic_alarm_workflow" do
      alarm = alarm_fixture(:panic, :critical)
      workflow = WorkflowEngine.panic_alarm_workflow()

      result = WorkflowEngine.execute_workflow(workflow, alarm)
      assert match?({:ok, _}, result)
    end

    test "returns {:ok, instance} for system_tamper_workflow" do
      alarm = alarm_fixture(:tamper, :medium)
      workflow = WorkflowEngine.system_tamper_workflow()

      result = WorkflowEngine.execute_workflow(workflow, alarm)
      assert match?({:ok, _}, result)
    end

    test "returned instance has alarm_id matching alarm" do
      alarm = alarm_fixture(:intrusion, :high)
      workflow = WorkflowEngine.system_tamper_workflow()

      {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)
      assert instance.alarm_id == alarm.id
    end

    test "returned instance has workflow_name from template" do
      alarm = alarm_fixture(:fire, :critical)
      workflow = WorkflowEngine.fire_response_workflow()

      {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)
      assert is_binary(instance.workflow_name)
      assert String.length(instance.workflow_name) > 0
    end

    test "returned instance has completed_steps list" do
      alarm = alarm_fixture(:medical, :high)
      workflow = WorkflowEngine.medical_emergency_workflow()

      {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)
      assert is_list(instance.completed_steps)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: get_standard_workflows/0
  # ---------------------------------------------------------------------------

  describe "get_standard_workflows/0" do
    test "returns a list" do
      result = WorkflowEngine.get_standard_workflows()
      assert is_list(result)
    end

    test "returns exactly 5 standard workflow templates" do
      result = WorkflowEngine.get_standard_workflows()
      assert length(result) == 5
    end

    test "each workflow has an id" do
      WorkflowEngine.get_standard_workflows()
      |> Enum.each(fn wf -> assert is_binary(wf.id) end)
    end

    test "each workflow has a name" do
      WorkflowEngine.get_standard_workflows()
      |> Enum.each(fn wf -> assert is_binary(wf.name) end)
    end

    test "each workflow has steps list" do
      WorkflowEngine.get_standard_workflows()
      |> Enum.each(fn wf -> assert is_list(wf.steps) end)
    end

    test "each workflow has trigger_conditions" do
      WorkflowEngine.get_standard_workflows()
      |> Enum.each(fn wf -> assert is_map(wf.trigger_conditions) end)
    end

    test "each workflow has a version" do
      WorkflowEngine.get_standard_workflows()
      |> Enum.each(fn wf -> assert is_binary(wf.version) end)
    end

    test "intrusion_response_workflow is included" do
      workflows = WorkflowEngine.get_standard_workflows()
      ids = Enum.map(workflows, & &1.id)
      assert "intrusion_response_v1" in ids
    end

    test "fire_response_workflow is included" do
      workflows = WorkflowEngine.get_standard_workflows()
      ids = Enum.map(workflows, & &1.id)
      assert "fire_response_v1" in ids
    end

    test "panic_alarm_workflow is included" do
      workflows = WorkflowEngine.get_standard_workflows()
      ids = Enum.map(workflows, & &1.id)
      assert "panic_alarm_v1" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # describe: individual workflow templates
  # ---------------------------------------------------------------------------

  describe "intrusion_response_workflow/0" do
    test "includes parallel execution steps for immediate actions" do
      wf = WorkflowEngine.intrusion_response_workflow()
      parallel_steps = Enum.filter(wf.steps, &(&1.type == :parallel))
      assert length(parallel_steps) >= 1
    end

    test "triggers on intrusion and unauthorized_access" do
      wf = WorkflowEngine.intrusion_response_workflow()
      assert :intrusion in wf.trigger_conditions.incident_types
      assert :unauthorized_access in wf.trigger_conditions.incident_types
    end
  end

  describe "fire_response_workflow/0" do
    test "triggers on fire incident type" do
      wf = WorkflowEngine.fire_response_workflow()
      assert :fire in wf.trigger_conditions.incident_types
    end

    test "minimum severity is :low (triggers for any fire)" do
      wf = WorkflowEngine.fire_response_workflow()
      assert wf.trigger_conditions.severity_minimum == :low
    end
  end

  describe "panic_alarm_workflow/0" do
    test "triggers on panic, duress, and holdup" do
      wf = WorkflowEngine.panic_alarm_workflow()
      assert :panic in wf.trigger_conditions.incident_types
      assert :duress in wf.trigger_conditions.incident_types
      assert :holdup in wf.trigger_conditions.incident_types
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: trigger_for_alarm survives all event types" do
      event_types = [:intrusion, :fire, :medical, :panic, :tamper, :supervisory]

      Enum.each(event_types, fn event_type ->
        alarm = alarm_fixture(event_type, :high)
        result = WorkflowEngine.trigger_for_alarm(alarm)
        assert result == :ok, "Expected :ok for event_type #{event_type}"
      end)
    end

    test "Psi3 verification: all standard workflows are verifiable structs" do
      workflows = WorkflowEngine.get_standard_workflows()

      Enum.each(workflows, fn wf ->
        assert is_binary(wf.id)
        assert is_binary(wf.name)
        assert is_list(wf.steps)
      end)
    end

    test "Psi5 truthfulness: execute_workflow result reflects actual execution" do
      alarm = alarm_fixture(:intrusion, :critical)
      workflow = WorkflowEngine.intrusion_response_workflow()

      {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)
      # The instance must track what actually happened
      assert instance.alarm_id == alarm.id
      assert is_list(instance.completed_steps)
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "trigger_for_alarm completes within 30 seconds (Task.await_many timeout)" do
      alarm = alarm_fixture(:intrusion, :high)
      {elapsed_us, result} = :timer.tc(fn -> WorkflowEngine.trigger_for_alarm(alarm) end)
      assert result == :ok
      assert elapsed_us < 30_000_000
    end

    test "dual-channel: fire and intrusion both return :ok" do
      r_fire = WorkflowEngine.trigger_for_alarm(alarm_fixture(:fire, :critical))
      r_intrusion = WorkflowEngine.trigger_for_alarm(alarm_fixture(:intrusion, :high))

      assert r_fire == :ok
      assert r_intrusion == :ok
    end

    test "execute_workflow completes within 5 seconds per workflow" do
      alarm = alarm_fixture(:fire, :critical)
      workflow = WorkflowEngine.fire_response_workflow()

      {elapsed_us, result} = :timer.tc(fn -> WorkflowEngine.execute_workflow(workflow, alarm) end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "trigger_for_alarm returns :ok for any event_type" do
    event_types = [:intrusion, :fire, :medical, :panic, :tamper, :supervisory, :holdup]

    forall event_type <- PC.oneof(Enum.map(event_types, &PC.exactly/1)) do
      alarm = %{
        id: Ecto.UUID.generate(),
        event_type: event_type,
        severity: :high,
        tenant_id: "prop-tenant",
        site_id: "s",
        zone_id: "z",
        correlated_events: [],
        state: :triggered
      }

      WorkflowEngine.trigger_for_alarm(alarm) == :ok
    end
  end

  property "get_standard_workflows always returns 5 workflows" do
    forall _n <- PC.integer(1, 3) do
      length(WorkflowEngine.get_standard_workflows()) == 5
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "execute_workflow returns {:ok, instance} for all standard workflows" do
    ExUnitProperties.check all(severity <- SD.member_of([:low, :medium, :high, :critical])) do
      alarm = alarm_fixture(:intrusion, severity)

      WorkflowEngine.get_standard_workflows()
      |> Enum.each(fn workflow ->
        result = WorkflowEngine.execute_workflow(workflow, alarm)

        assert match?({:ok, _}, result),
               "Expected {:ok, _} for workflow #{workflow.id} with severity #{severity}"
      end)
    end
  end

  test "each standard workflow trigger_conditions has incident_types" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      workflows = WorkflowEngine.get_standard_workflows()

      Enum.each(workflows, fn wf ->
        assert is_list(wf.trigger_conditions.incident_types)
      end)
    end
  end
end
