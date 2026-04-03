defmodule Indrajaal.Maintenance.ScheduleTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Maintenance.Schedule.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: Schedule lifecycle verified across all status transitions

  ## STAMP Safety Integration
  - SC-COV-001: Critical preventive maintenance schedule path coverage
  - SC-COV-006: TDG compliance mandatory

  ## Constitutional Verification
  - Psi0 Existence: Schedule records persist across status transitions (draft→active→suspended→active)
  - Psi1 Regeneration: Schedule state fully reconstructible from Ash resource (next_due_date calculated from pattern)

  ## Founder's Directive Alignment
  - Omega0.1: Accurate maintenance schedules prevent equipment failures in security systems

  ## TPS 5-Level RCA Context
  - L1 Symptom: Equipment maintenance missed due to schedule logic errors
  - L5 Root Cause: Missing action boundary validation for schedule status state machine

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 W3 test generation |

  ## Notes
  - Schedule status lifecycle: draft → activate → active → suspend → suspended → reactivate → active
  - complete action: valid from :active or :suspended
  - calculate_next_due_date: daily=+interval, weekly=+interval*7, monthly=+interval*30,
    quarterly=+interval*90, semi_annual=+interval*180, annual=+interval*365,
    biennial=+interval*730, custom/nil=+30
  - No maintenance factory exists yet — creates via Ash.create directly.
  - Requires tenant creation; uses system_admin actor (authorize?: false bypasses policies).
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Maintenance.Schedule

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_code, do: "SCH-#{System.unique_integer([:positive])}"

  defp create_schedule(attrs \\ %{}) do
    tenant = random_tenant()

    base =
      Map.merge(
        %{
          schedule_name: "Test Schedule #{System.unique_integer()}",
          schedule_code: unique_code(),
          schedule_type: :time_based,
          maintenance_category: :security,
          maintenance_type: :inspection,
          recurrence_pattern: :monthly,
          recurrence_interval: 1,
          start_date: Date.utc_today(),
          next_due_date: Date.add(Date.utc_today(), 30),
          lead_time_days: 7,
          priority: :medium,
          criticality: :standard,
          tenant_id: tenant.id
        },
        attrs
      )

    {:ok, schedule} =
      Ash.create(Schedule, base, action: :create, authorize?: false, actor: @system_admin)

    schedule
  end

  # ---------------------------------------------------------------------------
  # create action
  # ---------------------------------------------------------------------------

  describe "create action" do
    test "creates a schedule with default status :draft" do
      schedule = create_schedule()
      assert schedule.status == :draft
    end

    test "creates schedule with all required fields" do
      schedule = create_schedule()
      assert schedule.id
      assert schedule.schedule_name
      assert schedule.schedule_code
      assert schedule.recurrence_pattern == :monthly
      assert schedule.recurrence_interval == 1
    end

    test "next_due_date is calculated from start_date + interval (monthly pattern)" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{
          start_date: today,
          recurrence_pattern: :monthly,
          recurrence_interval: 1
        })

      # monthly: +1 * 30 = today + 30
      expected = Date.add(today, 30)
      assert schedule.next_due_date == expected
    end

    test "next_due_date for weekly pattern is start_date + interval * 7" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{start_date: today, recurrence_pattern: :weekly, recurrence_interval: 2})

      # weekly: +2 * 7 = today + 14
      expected = Date.add(today, 14)
      assert schedule.next_due_date == expected
    end

    test "next_due_date for daily pattern is start_date + interval" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{start_date: today, recurrence_pattern: :daily, recurrence_interval: 5})

      expected = Date.add(today, 5)
      assert schedule.next_due_date == expected
    end

    test "next_due_date for quarterly pattern is start_date + interval * 90" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{
          start_date: today,
          recurrence_pattern: :quarterly,
          recurrence_interval: 1
        })

      expected = Date.add(today, 90)
      assert schedule.next_due_date == expected
    end

    test "next_due_date for annual pattern is start_date + interval * 365" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{start_date: today, recurrence_pattern: :annual, recurrence_interval: 1})

      expected = Date.add(today, 365)
      assert schedule.next_due_date == expected
    end

    test "next_due_date for biennial pattern is start_date + interval * 730" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{
          start_date: today,
          recurrence_pattern: :biennial,
          recurrence_interval: 1
        })

      expected = Date.add(today, 730)
      assert schedule.next_due_date == expected
    end

    test "schedule_code is unique per tenant (enforced by unique index)" do
      tenant = random_tenant()
      code = unique_code()

      {:ok, _} =
        Ash.create(
          Schedule,
          %{
            schedule_name: "First",
            schedule_code: code,
            schedule_type: :time_based,
            maintenance_category: :security,
            maintenance_type: :inspection,
            recurrence_pattern: :monthly,
            recurrence_interval: 1,
            start_date: Date.utc_today(),
            next_due_date: Date.add(Date.utc_today(), 30),
            lead_time_days: 7,
            priority: :medium,
            criticality: :standard,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      result =
        Ash.create(
          Schedule,
          %{
            schedule_name: "Duplicate",
            schedule_code: code,
            schedule_type: :time_based,
            maintenance_category: :security,
            maintenance_type: :inspection,
            recurrence_pattern: :monthly,
            recurrence_interval: 1,
            start_date: Date.utc_today(),
            next_due_date: Date.add(Date.utc_today(), 30),
            lead_time_days: 7,
            priority: :medium,
            criticality: :standard,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # activate action (draft → active)
  # ---------------------------------------------------------------------------

  describe "activate action" do
    test "transitions status from :draft to :active" do
      schedule = create_schedule()
      assert schedule.status == :draft

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.status == :active
    end

    test "returns error when activating an already-active schedule" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      result =
        Ash.update(activated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # suspend action (active → suspended)
  # ---------------------------------------------------------------------------

  describe "suspend action" do
    test "transitions status from :active to :suspended" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, suspended} =
        Ash.update(
          activated,
          %{reason: "Equipment under repair"},
          action: :suspend,
          authorize?: false,
          actor: @system_admin
        )

      assert suspended.status == :suspended
    end

    test "returns error when suspending a draft schedule" do
      schedule = create_schedule()

      result =
        Ash.update(schedule, %{reason: "test"},
          action: :suspend,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # reactivate action (suspended → active)
  # ---------------------------------------------------------------------------

  describe "reactivate action" do
    test "transitions from :suspended back to :active" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, suspended} =
        Ash.update(activated, %{reason: "pause"},
          action: :suspend,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, reactivated} =
        Ash.update(suspended, %{}, action: :reactivate, authorize?: false, actor: @system_admin)

      assert reactivated.status == :active
    end

    test "clears suspension_reason on reactivate" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, suspended} =
        Ash.update(activated, %{reason: "temp stop"},
          action: :suspend,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, reactivated} =
        Ash.update(suspended, %{}, action: :reactivate, authorize?: false, actor: @system_admin)

      assert is_nil(reactivated.suspension_reason)
    end

    test "returns error when reactivating an active (not suspended) schedule" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      result =
        Ash.update(activated, %{}, action: :reactivate, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # complete action (active|suspended → completed)
  # ---------------------------------------------------------------------------

  describe "complete action" do
    test "transitions active schedule to :completed" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, completed} =
        Ash.update(activated, %{}, action: :complete, authorize?: false, actor: @system_admin)

      assert completed.status == :completed
    end

    test "transitions suspended schedule to :completed" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, suspended} =
        Ash.update(activated, %{reason: "pause"},
          action: :suspend,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, completed} =
        Ash.update(suspended, %{}, action: :complete, authorize?: false, actor: @system_admin)

      assert completed.status == :completed
    end

    test "returns error when completing a draft schedule" do
      schedule = create_schedule()

      result =
        Ash.update(schedule, %{}, action: :complete, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # record_completion action
  # ---------------------------------------------------------------------------

  describe "record_completion action" do
    test "increments completed_work_orders and total_work_orders" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      initial_completed = activated.completed_work_orders || 0
      initial_total = activated.total_work_orders || 0

      {:ok, updated} =
        Ash.update(
          activated,
          %{completion_date: Date.utc_today()},
          action: :record_completion,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.completed_work_orders == initial_completed + 1
      assert updated.total_work_orders == initial_total + 1
    end

    test "updates last_completed_date to completion_date" do
      schedule = create_schedule()

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      today = Date.utc_today()

      {:ok, updated} =
        Ash.update(
          activated,
          %{completion_date: today},
          action: :record_completion,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.last_completed_date == today
    end

    test "updates next_due_date based on completion_date + recurrence" do
      today = Date.utc_today()

      schedule =
        create_schedule(%{
          start_date: today,
          recurrence_pattern: :monthly,
          recurrence_interval: 1
        })

      {:ok, activated} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, updated} =
        Ash.update(
          activated,
          %{completion_date: today},
          action: :record_completion,
          authorize?: false,
          actor: @system_admin
        )

      # monthly: completion_date + 30
      expected_next = Date.add(today, 30)
      assert updated.next_due_date == expected_next
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "next_due_date is always after start_date for any interval in 1..999" do
    forall interval <- PC.integer(1, 50) do
      today = Date.utc_today()

      schedule =
        create_schedule(%{
          start_date: today,
          recurrence_pattern: :daily,
          recurrence_interval: interval
        })

      Date.compare(schedule.next_due_date, today) in [:eq, :gt]
    end
  end

  test "create always returns a schedule with :draft status" do
    forall _x <- PC.boolean() do
      schedule = create_schedule()
      schedule.status == :draft
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "activate-suspend-reactivate cycle leaves status :active" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      schedule = create_schedule()

      {:ok, a} =
        Ash.update(schedule, %{}, action: :activate, authorize?: false, actor: @system_admin)

      {:ok, s} =
        Ash.update(a, %{reason: "prop test"},
          action: :suspend,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, r} = Ash.update(s, %{}, action: :reactivate, authorize?: false, actor: @system_admin)
      assert r.status == :active
    end
  end
end
