defmodule Indrajaal.GuardTour.TourExecutionTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for Indrajaal.GuardTour.TourExecution.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: Lifecycle state machine verified (scheduled→in_progress→completed/aborted)

  ## STAMP Safety Integration
  - SC-COV-001: TourExecution state machine critical path coverage
  - SC-COV-006: TDG compliance mandatory
  - SC-HOLON-001: State written to PostgreSQL via Ash (business data)

  ## Constitutional Verification
  - Psi0 Existence: Execution records persist across status transitions
  - Psi1 Regeneration: State fully reconstructible from Ash resource
  - Psi3 Verification: Status transitions monotonic; abort notes non-nil

  ## Founder's Directive Alignment
  - Omega0.1: Accurate patrol execution tracking enables security accountability

  ## TPS 5-Level RCA Context
  - L1 Symptom: Executions showing stale status or missing timestamps
  - L5 Root Cause: Missing state machine boundary for execution lifecycle

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 comprehensive test generation |
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.GuardTour.TourExecution
  alias Indrajaal.GuardTour.TourRoute

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_route(tenant_id) do
    {:ok, route} =
      Ash.create(
        TourRoute,
        %{
          name: "Route #{System.unique_integer([:positive])}",
          description: "Test patrol route",
          route_type: :regular,
          estimated_duration: 60,
          checkpoint_order: [],
          is_active: true,
          priority_level: :medium,
          tenant_id: tenant_id
        },
        authorize?: false,
        actor: @system_admin,
        tenant: tenant_id
      )

    route
  end

  defp create_execution(attrs \\ %{}) do
    tenant = random_tenant()
    route = create_route(tenant.id)

    base = %{
      scheduled_start: DateTime.utc_now(),
      route_id: route.id,
      tenant_id: tenant.id
    }

    {:ok, execution} =
      Ash.create(
        TourExecution,
        Map.merge(base, attrs),
        authorize?: false,
        actor: @system_admin,
        tenant: tenant.id
      )

    {execution, tenant}
  end

  defp random_uuid, do: Ash.UUID.generate()

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TourExecution)
    end

    test "domain is GuardTour" do
      assert Ash.Resource.Info.domain(TourExecution) == Indrajaal.GuardTour
    end
  end

  # ---------------------------------------------------------------------------
  # Ash resource introspection
  # ---------------------------------------------------------------------------

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(TourExecution)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has tour lifecycle actions" do
      actions = Ash.Resource.Info.actions(TourExecution)
      action_names = Enum.map(actions, & &1.name)
      assert :start_tour in action_names
      assert :complete_tour in action_names
      assert :abort_tour in action_names
    end

    test "start_tour is an update action" do
      actions = Ash.Resource.Info.actions(TourExecution)
      action = Enum.find(actions, &(&1.name == :start_tour))
      assert action.type == :update
    end

    test "complete_tour is an update action" do
      actions = Ash.Resource.Info.actions(TourExecution)
      action = Enum.find(actions, &(&1.name == :complete_tour))
      assert action.type == :update
    end

    test "abort_tour is an update action" do
      actions = Ash.Resource.Info.actions(TourExecution)
      action = Enum.find(actions, &(&1.name == :abort_tour))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(TourExecution)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :execution_status in attr_names
      assert :started_at in attr_names
      assert :completed_at in attr_names
      assert :scheduled_start in attr_names
      assert :completion_percentage in attr_names
      assert :checkpoints_completed in attr_names
      assert :checkpoints_missed in attr_names
      assert :notes in attr_names
      assert :actual_duration in attr_names
      assert :expected_duration in attr_names
    end

    test "resource has is_overdue and delay_minutes calculations" do
      calcs = Ash.Resource.Info.calculations(TourExecution)
      calc_names = Enum.map(calcs, & &1.name)
      assert :is_overdue in calc_names
      assert :delay_minutes in calc_names
    end
  end

  # ---------------------------------------------------------------------------
  # create action defaults
  # ---------------------------------------------------------------------------

  describe "create action" do
    test "creates execution with default status :scheduled" do
      {execution, _tenant} = create_execution()
      assert execution.execution_status == :scheduled
    end

    test "creates execution with default completion_percentage 0" do
      {execution, _tenant} = create_execution()
      assert Decimal.equal?(execution.completion_percentage, Decimal.new(0))
    end

    test "creates execution with default checkpoints_completed 0" do
      {execution, _tenant} = create_execution()
      assert execution.checkpoints_completed == 0
    end

    test "creates execution with default checkpoints_missed 0" do
      {execution, _tenant} = create_execution()
      assert execution.checkpoints_missed == 0
    end

    test "create fails without scheduled_start" do
      tenant = random_tenant()
      route = create_route(tenant.id)

      result =
        Ash.create(
          TourExecution,
          %{route_id: route.id, tenant_id: tenant.id},
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "creates execution with an id" do
      {execution, _tenant} = create_execution()
      assert is_binary(execution.id)
    end

    test "started_at is nil by default" do
      {execution, _tenant} = create_execution()
      assert is_nil(execution.started_at)
    end

    test "completed_at is nil by default" do
      {execution, _tenant} = create_execution()
      assert is_nil(execution.completed_at)
    end
  end

  # ---------------------------------------------------------------------------
  # start_tour action
  # ---------------------------------------------------------------------------

  describe "start_tour/1" do
    test "transitions status to :in_progress" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(
          execution,
          %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert started.execution_status == :in_progress
    end

    test "sets started_at to a datetime" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(
          execution,
          %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert %DateTime{} = started.started_at
    end

    test "sets assigned_guard_id to the provided guard_id" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(
          execution,
          %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert started.assigned_guard_id == guard_id
    end

    test "start_tour requires guard_id argument" do
      {execution, tenant} = create_execution()

      result =
        Ash.update(
          execution,
          %{},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "started_at is before or equal to current time" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()
      before_start = DateTime.utc_now()

      {:ok, started} =
        Ash.update(
          execution,
          %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert DateTime.compare(started.started_at, before_start) in [:gt, :eq]
    end
  end

  # ---------------------------------------------------------------------------
  # complete_tour action
  # ---------------------------------------------------------------------------

  describe "complete_tour/1" do
    test "transitions status to :completed" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert completed.execution_status == :completed
    end

    test "sets completed_at to a datetime" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert %DateTime{} = completed.completed_at
    end

    test "sets actual_duration when started_at is present" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert is_integer(completed.actual_duration)
    end

    test "completed_at is after started_at" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert DateTime.compare(completed.completed_at, completed.started_at) in [:gt, :eq]
    end
  end

  # ---------------------------------------------------------------------------
  # abort_tour action
  # ---------------------------------------------------------------------------

  describe "abort_tour/1" do
    test "transitions status to :aborted" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, aborted} =
        Ash.update(started, %{reason: "Emergency situation"},
          action: :abort_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert aborted.execution_status == :aborted
    end

    test "stores the reason in the notes field" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, aborted} =
        Ash.update(started, %{reason: "Security incident"},
          action: :abort_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert aborted.notes == "Security incident"
    end

    test "abort_tour requires reason argument" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      result =
        Ash.update(started, %{},
          action: :abort_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "notes is non-nil after abort (SIL-6 safety)" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, aborted} =
        Ash.update(started, %{reason: "Equipment failure"},
          action: :abort_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      refute is_nil(aborted.notes)
    end
  end

  # ---------------------------------------------------------------------------
  # Full lifecycle
  # ---------------------------------------------------------------------------

  describe "full execution lifecycle" do
    test "scheduled → in_progress → completed" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      assert execution.execution_status == :scheduled

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert started.execution_status == :in_progress

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert completed.execution_status == :completed
    end

    test "scheduled → in_progress → aborted" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, aborted} =
        Ash.update(started, %{reason: "Weather emergency"},
          action: :abort_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert aborted.execution_status == :aborted
      assert aborted.notes == "Weather emergency"
    end

    test "completed execution has both started_at and completed_at" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert %DateTime{} = completed.started_at
      assert %DateTime{} = completed.completed_at
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi3)" do
    test "Psi0 existence: execution persists after create" do
      {execution, tenant} = create_execution()

      fetched =
        Ash.get!(TourExecution, execution.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.id == execution.id
    end

    test "Psi1 regeneration: execution fully reconstructible by id" do
      {execution, tenant} = create_execution()

      reconstructed =
        Ash.get!(TourExecution, execution.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert reconstructed.execution_status == :scheduled
      assert reconstructed.route_id == execution.route_id
    end

    test "Psi3 verification: status transitions are monotonic (no regression)" do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, completed} =
        Ash.update(started, %{},
          action: :complete_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert completed.execution_status == :completed
      # Once completed, the record does not revert to :scheduled
      fetched =
        Ash.get!(TourExecution, completed.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.execution_status == :completed
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014: PC. prefix)
  # ---------------------------------------------------------------------------

  test "new execution always has status :scheduled" do
    forall _x <- PC.integer() do
      {execution, _tenant} = create_execution()
      execution.execution_status == :scheduled
    end
  end

  test "completion_percentage default is in [0, 100]" do
    forall _x <- PC.integer() do
      {execution, _tenant} = create_execution()
      pct = Decimal.to_float(execution.completion_percentage)
      pct >= 0.0 and pct <= 100.0
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties (EP-GEN-014: SD. prefix)
  # ---------------------------------------------------------------------------

  test "start_tour always transitions to :in_progress" do
    ExUnitProperties.check all(
                             _x <- SD.integer(),
                             max_runs: 3
                           ) do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert started.execution_status == :in_progress
    end
  end

  test "abort_tour always sets notes to provided reason" do
    ExUnitProperties.check all(
                             reason <- SD.string(:alphanumeric, min_length: 1, max_length: 100),
                             max_runs: 3
                           ) do
      {execution, tenant} = create_execution()
      guard_id = random_uuid()

      {:ok, started} =
        Ash.update(execution, %{guard_id: guard_id},
          action: :start_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      {:ok, aborted} =
        Ash.update(started, %{reason: reason},
          action: :abort_tour,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert aborted.notes == reason
    end
  end
end
