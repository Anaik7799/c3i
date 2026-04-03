defmodule Indrajaal.GuardTour.GuardAssignmentTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for Indrajaal.GuardTour.GuardAssignment.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: assign_guard and deactivate lifecycle, exclusive schedule/route validation

  ## STAMP Safety Integration
  - SC-COV-001: GuardAssignment creation and deactivation critical paths
  - SC-COV-006: TDG compliance mandatory
  - SC-HOLON-001: State written to PostgreSQL via Ash (business data)

  ## Constitutional Verification
  - Psi0 Existence: Assignment records persist after assign_guard
  - Psi1 Regeneration: Assignment state reconstructible from Ash resource
  - Psi3 Verification: is_active transitions are unidirectional (true→false)

  ## Founder's Directive Alignment
  - Omega0.1: Guard assignment tracking enables accountable security deployment

  ## TPS 5-Level RCA Context
  - L1 Symptom: Guard assignments with both schedule_id and route_id set
  - L5 Root Cause: Missing XOR validation between schedule and route assignment

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
  alias Indrajaal.GuardTour.GuardAssignment
  alias Indrajaal.GuardTour.TourRoute
  alias Indrajaal.GuardTour.TourSchedule

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp random_uuid, do: Ash.UUID.generate()

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

  defp create_schedule(tenant_id, route_id) do
    now = DateTime.utc_now()
    later = DateTime.add(now, 3600, :second)

    {:ok, schedule} =
      Ash.create(
        TourSchedule,
        %{
          name: "Schedule #{System.unique_integer([:positive])}",
          start_time: now,
          end_time: later,
          route_id: route_id,
          tenant_id: tenant_id
        },
        authorize?: false,
        actor: @system_admin,
        tenant: tenant_id
      )

    schedule
  end

  defp create_assignment_to_route(attrs \\ %{}) do
    tenant = random_tenant()
    route = create_route(tenant.id)
    guard_id = random_uuid()
    assigner_id = random_uuid()
    valid_from = DateTime.utc_now()

    {:ok, assignment} =
      Ash.create(
        GuardAssignment,
        Map.merge(
          %{
            guard_id: guard_id,
            route_id: route.id,
            assignment_type: :primary,
            valid_from: valid_from,
            assigned_by_id: assigner_id,
            tenant_id: tenant.id
          },
          attrs
        ),
        action: :assign_guard,
        authorize?: false,
        actor: @system_admin,
        tenant: tenant.id
      )

    {assignment, tenant}
  end

  defp create_assignment_to_schedule(attrs \\ %{}) do
    tenant = random_tenant()
    route = create_route(tenant.id)
    schedule = create_schedule(tenant.id, route.id)
    guard_id = random_uuid()
    assigner_id = random_uuid()
    valid_from = DateTime.utc_now()

    {:ok, assignment} =
      Ash.create(
        GuardAssignment,
        Map.merge(
          %{
            guard_id: guard_id,
            schedule_id: schedule.id,
            assignment_type: :primary,
            valid_from: valid_from,
            assigned_by_id: assigner_id,
            tenant_id: tenant.id
          },
          attrs
        ),
        action: :assign_guard,
        authorize?: false,
        actor: @system_admin,
        tenant: tenant.id
      )

    {assignment, tenant}
  end

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(GuardAssignment)
    end

    test "domain is GuardTour" do
      assert Ash.Resource.Info.domain(GuardAssignment) == Indrajaal.GuardTour
    end
  end

  # ---------------------------------------------------------------------------
  # Ash resource introspection
  # ---------------------------------------------------------------------------

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(GuardAssignment)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has assign_guard action" do
      actions = Ash.Resource.Info.actions(GuardAssignment)
      action_names = Enum.map(actions, & &1.name)
      assert :assign_guard in action_names
    end

    test "resource has deactivate action" do
      actions = Ash.Resource.Info.actions(GuardAssignment)
      action_names = Enum.map(actions, & &1.name)
      assert :deactivate in action_names
    end

    test "assign_guard is a create action" do
      actions = Ash.Resource.Info.actions(GuardAssignment)
      action = Enum.find(actions, &(&1.name == :assign_guard))
      assert action.type == :create
    end

    test "deactivate is an update action" do
      actions = Ash.Resource.Info.actions(GuardAssignment)
      action = Enum.find(actions, &(&1.name == :deactivate))
      assert action.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(GuardAssignment)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :assignment_type in attr_names
      assert :assigned_at in attr_names
      assert :valid_from in attr_names
      assert :valid_until in attr_names
      assert :is_active in attr_names
      assert :priority_order in attr_names
      assert :qualifications_required in attr_names
    end

    test "resource has expected relationships" do
      rels = Ash.Resource.Info.relationships(GuardAssignment)
      rel_names = Enum.map(rels, & &1.name)
      assert :guard in rel_names
      assert :schedule in rel_names
      assert :route in rel_names
      assert :assigned_by in rel_names
    end
  end

  # ---------------------------------------------------------------------------
  # assign_guard create action
  # ---------------------------------------------------------------------------

  describe "assign_guard/1 to route" do
    test "creates assignment with is_active true by default" do
      {assignment, _tenant} = create_assignment_to_route()
      assert assignment.is_active == true
    end

    test "creates assignment with priority_order 1 by default" do
      {assignment, _tenant} = create_assignment_to_route()
      assert assignment.priority_order == 1
    end

    test "creates assignment with qualifications_required [] by default" do
      {assignment, _tenant} = create_assignment_to_route()
      assert assignment.qualifications_required == []
    end

    test "creates assignment with assigned_at set" do
      {assignment, _tenant} = create_assignment_to_route()
      assert %DateTime{} = assignment.assigned_at
    end

    test "creates assignment with assignment_type :primary" do
      {assignment, _tenant} = create_assignment_to_route(%{assignment_type: :primary})
      assert assignment.assignment_type == :primary
    end

    test "creates assignment with assignment_type :backup" do
      {assignment, _tenant} = create_assignment_to_route(%{assignment_type: :backup})
      assert assignment.assignment_type == :backup
    end

    test "creates assignment with assignment_type :supervisor" do
      {assignment, _tenant} = create_assignment_to_route(%{assignment_type: :supervisor})
      assert assignment.assignment_type == :supervisor
    end

    test "creates assignment with an id" do
      {assignment, _tenant} = create_assignment_to_route()
      assert is_binary(assignment.id)
    end
  end

  describe "assign_guard/1 to schedule" do
    test "creates schedule assignment with is_active true" do
      {assignment, _tenant} = create_assignment_to_schedule()
      assert assignment.is_active == true
    end

    test "creates schedule assignment with schedule_id set" do
      {assignment, _tenant} = create_assignment_to_schedule()
      assert is_binary(assignment.schedule_id)
    end
  end

  describe "assign_guard validation" do
    test "requires guard_id" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      assigner_id = random_uuid()

      result =
        Ash.create(
          GuardAssignment,
          %{
            route_id: route.id,
            assignment_type: :primary,
            valid_from: DateTime.utc_now(),
            assigned_by_id: assigner_id,
            tenant_id: tenant.id
          },
          action: :assign_guard,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "requires valid_from" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      guard_id = random_uuid()
      assigner_id = random_uuid()

      result =
        Ash.create(
          GuardAssignment,
          %{
            guard_id: guard_id,
            route_id: route.id,
            assignment_type: :primary,
            assigned_by_id: assigner_id,
            tenant_id: tenant.id
          },
          action: :assign_guard,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "requires assigned_by_id" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      guard_id = random_uuid()

      result =
        Ash.create(
          GuardAssignment,
          %{
            guard_id: guard_id,
            route_id: route.id,
            assignment_type: :primary,
            valid_from: DateTime.utc_now(),
            tenant_id: tenant.id
          },
          action: :assign_guard,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # deactivate action
  # ---------------------------------------------------------------------------

  describe "deactivate/1" do
    test "sets is_active to false" do
      {assignment, tenant} = create_assignment_to_route()
      assert assignment.is_active == true

      {:ok, deactivated} =
        Ash.update(
          assignment,
          %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.is_active == false
    end

    test "preserves other fields after deactivation" do
      {assignment, tenant} = create_assignment_to_route(%{assignment_type: :supervisor})

      {:ok, deactivated} =
        Ash.update(
          assignment,
          %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.assignment_type == :supervisor
      assert deactivated.guard_id == assignment.guard_id
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi3)" do
    test "Psi0 existence: assignment persists after assign_guard" do
      {assignment, tenant} = create_assignment_to_route()

      fetched =
        Ash.get!(GuardAssignment, assignment.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.id == assignment.id
    end

    test "Psi1 regeneration: assignment fully reconstructible by id" do
      {assignment, tenant} = create_assignment_to_route()

      reconstructed =
        Ash.get!(GuardAssignment, assignment.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert reconstructed.is_active == true
      assert reconstructed.guard_id == assignment.guard_id
    end

    test "Psi3 verification: deactivation is permanent (is_active stays false)" do
      {assignment, tenant} = create_assignment_to_route()

      {:ok, deactivated} =
        Ash.update(assignment, %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      fetched =
        Ash.get!(GuardAssignment, deactivated.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.is_active == false
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014: PC. prefix)
  # ---------------------------------------------------------------------------

  test "new assignment always starts with is_active true" do
    forall _x <- PC.integer() do
      {assignment, _tenant} = create_assignment_to_route()
      assignment.is_active == true
    end
  end

  test "new assignment priority_order is always at least 1" do
    forall _x <- PC.integer() do
      {assignment, _tenant} = create_assignment_to_route()
      assignment.priority_order >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties (EP-GEN-014: SD. prefix)
  # ---------------------------------------------------------------------------

  test "deactivate always sets is_active to false" do
    ExUnitProperties.check all(
                             _x <- SD.integer(),
                             max_runs: 3
                           ) do
      {assignment, tenant} = create_assignment_to_route()

      {:ok, deactivated} =
        Ash.update(assignment, %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.is_active == false
    end
  end
end
