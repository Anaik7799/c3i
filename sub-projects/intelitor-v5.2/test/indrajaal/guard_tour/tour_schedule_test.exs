defmodule Indrajaal.GuardTour.TourScheduleTest do
  @moduledoc """
  TDG-compliant comprehensive test suite for Indrajaal.GuardTour.TourSchedule.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: activate (create) and deactivate (update) lifecycle verified
    plus end_time > start_time validation boundary

  ## STAMP Safety Integration
  - SC-COV-001: TourSchedule creation and deactivation critical paths
  - SC-COV-006: TDG compliance mandatory
  - SC-HOLON-001: State written to PostgreSQL via Ash (business data)

  ## Constitutional Verification
  - Psi0 Existence: Schedule records persist after create
  - Psi1 Regeneration: Schedule state reconstructible from Ash resource
  - Psi3 Verification: is_active false after deactivate; no regression to true

  ## Founder's Directive Alignment
  - Omega0.1: Schedule management enables predictable security patrol coverage

  ## TPS 5-Level RCA Context
  - L1 Symptom: Schedules with end_time before start_time causing patrol gaps
  - L5 Root Cause: Missing temporal validation on schedule creation

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
  alias Indrajaal.GuardTour.TourSchedule
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

  defp create_schedule(attrs \\ %{}) do
    tenant = random_tenant()
    route = create_route(tenant.id)
    now = DateTime.utc_now()
    later = DateTime.add(now, 3600, :second)

    {:ok, schedule} =
      Ash.create(
        TourSchedule,
        Map.merge(
          %{
            name: "Schedule #{System.unique_integer([:positive])}",
            start_time: now,
            end_time: later,
            route_id: route.id,
            tenant_id: tenant.id
          },
          attrs
        ),
        authorize?: false,
        actor: @system_admin,
        tenant: tenant.id
      )

    {schedule, tenant}
  end

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TourSchedule)
    end

    test "domain is GuardTour" do
      assert Ash.Resource.Info.domain(TourSchedule) == Indrajaal.GuardTour
    end
  end

  # ---------------------------------------------------------------------------
  # Ash resource introspection
  # ---------------------------------------------------------------------------

  describe "Ash resource introspection" do
    test "resource has CRUD actions" do
      actions = Ash.Resource.Info.actions(TourSchedule)
      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :update in action_names
      assert :read in action_names
      assert :destroy in action_names
    end

    test "resource has lifecycle actions" do
      actions = Ash.Resource.Info.actions(TourSchedule)
      action_names = Enum.map(actions, & &1.name)
      assert :activate in action_names
      assert :deactivate in action_names
    end

    test "activate is a create action" do
      actions = Ash.Resource.Info.actions(TourSchedule)
      activate = Enum.find(actions, &(&1.name == :activate))
      assert activate.type == :create
    end

    test "deactivate is an update action" do
      actions = Ash.Resource.Info.actions(TourSchedule)
      deactivate = Enum.find(actions, &(&1.name == :deactivate))
      assert deactivate.type == :update
    end

    test "resource has expected attributes" do
      attrs = Ash.Resource.Info.attributes(TourSchedule)
      attr_names = Enum.map(attrs, & &1.name)
      assert :id in attr_names
      assert :name in attr_names
      assert :start_time in attr_names
      assert :end_time in attr_names
      assert :recurrence_pattern in attr_names
      assert :recurrence_data in attr_names
      assert :is_active in attr_names
      assert :max_delay_minutes in attr_names
      assert :auto_assign in attr_names
    end
  end

  # ---------------------------------------------------------------------------
  # create action defaults
  # ---------------------------------------------------------------------------

  describe "create action" do
    test "creates schedule with default is_active true" do
      {schedule, _tenant} = create_schedule()
      assert schedule.is_active == true
    end

    test "creates schedule with default recurrence_pattern :none" do
      {schedule, _tenant} = create_schedule()
      assert schedule.recurrence_pattern == :none
    end

    test "creates schedule with default max_delay_minutes 15" do
      {schedule, _tenant} = create_schedule()
      assert schedule.max_delay_minutes == 15
    end

    test "creates schedule with default auto_assign false" do
      {schedule, _tenant} = create_schedule()
      assert schedule.auto_assign == false
    end

    test "creates schedule with default recurrence_data empty map" do
      {schedule, _tenant} = create_schedule()
      assert schedule.recurrence_data == %{}
    end

    test "creates schedule with an id" do
      {schedule, _tenant} = create_schedule()
      assert is_binary(schedule.id)
    end

    test "creates schedule with provided name" do
      {schedule, _tenant} = create_schedule(%{name: "Morning Patrol"})
      assert schedule.name == "Morning Patrol"
    end

    test "creates schedule with recurrence_pattern :daily" do
      {schedule, _tenant} = create_schedule(%{recurrence_pattern: :daily})
      assert schedule.recurrence_pattern == :daily
    end

    test "creates schedule with recurrence_pattern :weekly" do
      {schedule, _tenant} = create_schedule(%{recurrence_pattern: :weekly})
      assert schedule.recurrence_pattern == :weekly
    end

    test "creates schedule with recurrence_pattern :monthly" do
      {schedule, _tenant} = create_schedule(%{recurrence_pattern: :monthly})
      assert schedule.recurrence_pattern == :monthly
    end

    test "creates schedule with recurrence_pattern :custom" do
      {schedule, _tenant} = create_schedule(%{recurrence_pattern: :custom})
      assert schedule.recurrence_pattern == :custom
    end

    test "create fails without name" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      now = DateTime.utc_now()
      later = DateTime.add(now, 3600, :second)

      result =
        Ash.create(
          TourSchedule,
          %{
            start_time: now,
            end_time: later,
            route_id: route.id,
            tenant_id: tenant.id
          },
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "create fails when end_time is before start_time" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      now = DateTime.utc_now()
      earlier = DateTime.add(now, -3600, :second)

      result =
        Ash.create(
          TourSchedule,
          %{
            name: "Invalid Schedule",
            start_time: now,
            end_time: earlier,
            route_id: route.id,
            tenant_id: tenant.id
          },
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "create fails when end_time equals start_time" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      now = DateTime.utc_now()

      result =
        Ash.create(
          TourSchedule,
          %{
            name: "Zero Duration Schedule",
            start_time: now,
            end_time: now,
            route_id: route.id,
            tenant_id: tenant.id
          },
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert {:error, _} = result
    end

    test "max_delay_minutes respects bounds: custom value 30" do
      {schedule, _tenant} = create_schedule(%{max_delay_minutes: 30})
      assert schedule.max_delay_minutes == 30
    end

    test "max_delay_minutes respects bounds: value 0" do
      {schedule, _tenant} = create_schedule(%{max_delay_minutes: 0})
      assert schedule.max_delay_minutes == 0
    end

    test "max_delay_minutes respects bounds: value 120" do
      {schedule, _tenant} = create_schedule(%{max_delay_minutes: 120})
      assert schedule.max_delay_minutes == 120
    end
  end

  # ---------------------------------------------------------------------------
  # activate create action
  # ---------------------------------------------------------------------------

  describe "activate/1" do
    test "creates schedule with is_active true" do
      tenant = random_tenant()
      route = create_route(tenant.id)
      now = DateTime.utc_now()
      later = DateTime.add(now, 3600, :second)

      {:ok, schedule} =
        Ash.create(
          TourSchedule,
          %{
            name: "Active Schedule",
            start_time: now,
            end_time: later,
            route_id: route.id,
            tenant_id: tenant.id
          },
          action: :activate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert schedule.is_active == true
    end
  end

  # ---------------------------------------------------------------------------
  # deactivate update action
  # ---------------------------------------------------------------------------

  describe "deactivate/1" do
    test "sets is_active to false" do
      {schedule, tenant} = create_schedule()
      assert schedule.is_active == true

      {:ok, deactivated} =
        Ash.update(
          schedule,
          %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.is_active == false
    end

    test "preserves name after deactivation" do
      {schedule, tenant} = create_schedule(%{name: "Night Patrol"})

      {:ok, deactivated} =
        Ash.update(schedule, %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.name == "Night Patrol"
    end

    test "preserves recurrence_pattern after deactivation" do
      {schedule, tenant} = create_schedule(%{recurrence_pattern: :weekly})

      {:ok, deactivated} =
        Ash.update(schedule, %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.recurrence_pattern == :weekly
    end

    test "is_active is persistently false after deactivation" do
      {schedule, tenant} = create_schedule()

      {:ok, deactivated} =
        Ash.update(schedule, %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      fetched =
        Ash.get!(TourSchedule, deactivated.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.is_active == false
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi3)" do
    test "Psi0 existence: schedule persists after create" do
      {schedule, tenant} = create_schedule()

      fetched =
        Ash.get!(TourSchedule, schedule.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert fetched.id == schedule.id
    end

    test "Psi1 regeneration: schedule fully reconstructible by id" do
      {schedule, tenant} = create_schedule()

      reconstructed =
        Ash.get!(TourSchedule, schedule.id,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert reconstructed.is_active == true
      assert reconstructed.route_id == schedule.route_id
      assert reconstructed.recurrence_pattern == schedule.recurrence_pattern
    end

    test "Psi3 verification: end_time always strictly after start_time in valid schedules" do
      {schedule, _tenant} = create_schedule()
      assert DateTime.compare(schedule.end_time, schedule.start_time) == :gt
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014: PC. prefix)
  # ---------------------------------------------------------------------------

  test "new schedule always has is_active true" do
    forall _x <- PC.integer() do
      {schedule, _tenant} = create_schedule()
      schedule.is_active == true
    end
  end

  test "new schedule max_delay_minutes is in [0, 120]" do
    forall _x <- PC.integer() do
      {schedule, _tenant} = create_schedule()
      schedule.max_delay_minutes >= 0 and schedule.max_delay_minutes <= 120
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
      {schedule, tenant} = create_schedule()

      {:ok, deactivated} =
        Ash.update(schedule, %{},
          action: :deactivate,
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert deactivated.is_active == false
    end
  end

  test "valid schedules always have end_time after start_time" do
    ExUnitProperties.check all(
                             offset_seconds <- SD.integer(1..86400),
                             max_runs: 5
                           ) do
      tenant = random_tenant()
      route = create_route(tenant.id)
      now = DateTime.utc_now()
      later = DateTime.add(now, offset_seconds, :second)

      {:ok, schedule} =
        Ash.create(
          TourSchedule,
          %{
            name: "Schedule #{System.unique_integer([:positive])}",
            start_time: now,
            end_time: later,
            route_id: route.id,
            tenant_id: tenant.id
          },
          authorize?: false,
          actor: @system_admin,
          tenant: tenant.id
        )

      assert DateTime.compare(schedule.end_time, schedule.start_time) == :gt
    end
  end
end
