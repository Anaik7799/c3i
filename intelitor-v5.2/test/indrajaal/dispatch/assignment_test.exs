defmodule Indrajaal.Dispatch.AssignmentTest do
  use Indrajaal.DataCase

  alias Indrajaal.Alarms.AlarmEvent
  alias Indrajaal.Core.Tenant
  alias Indrajaal.Dispatch.{Assignment, Officer, Team, Vehicle}

  describe "Assignment resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      user = insert(:user, tenant: tenant)
      officer = insert(:officer, tenant: tenant, user: user)

      {:ok, tenant: tenant, organization: organization, user: user, officer: officer}
    end

    test "creates an assignment with valid attributes",
         %{tenant: tenant, officer: officer} do
      attrs = %{
        assignment_type: :patrol,
        priority: :routine,
        status: :assigned,
        title: "Downtown Patrol",
        description: "Regular patrol of downtown business district",
        location: %{
          "address" => "123 Main St, Downtown",
          "latitude" => 40.7128,
          "longitude" => -74.0060,
          "radius" => 500
        },
        assigned_at: DateTime.utc_now(),
        # 8 hours
        estimated_duration: 480,
        instructions: "Monitor high - traffic areas and report any suspicious activity",
        officer_id: officer.id,
        tenant_id: tenant.id
      }

      {:ok, assignment} = Assignment.create(attrs)

      assert assignment.assignment_type == :patrol
      assert assignment.priority == :routine
      assert assignment.status == :assigned
      assert assignment.title == "Downtown Patrol"
      assert assignment.description == "Regular patrol of downtown business
        district"
      assert assignment.location["address"] == "123 Main St, Downtown"
      assert assignment.location["latitude"] == 40.7128
      assert assignment.estimated_duration == 480
      assert assignment.officer_id == officer.id
      assert assignment.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Assignment.create(%{tenant_id: tenant.id})

      assert changeset.errors[:assignment_type]
      assert changeset.errors[:priority]
      assert changeset.errors[:title]
      assert changeset.errors[:assigned_at]
      assert changeset.errors[:officer_id]
    end

    test "validates assignment type", %{tenant: tenant, officer: officer} do
      valid_types = [
        :patrol,
        :investigation,
        :emergency_response,
        :traffic_control,
        :security_check,
        :escort,
        :surveillance,
        :crowd_control,
        :search_and_rescue,
        :community_outreach
      ]

      for type <- valid_types do
        {:ok, _assignment} =
          Assignment.create(%{
            assignment_type: type,
            priority: :routine,
            title: "Test Assignment",
            assigned_at: DateTime.utc_now(),
            officer_id: officer.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Assignment.create(%{
          assignment_type: :invalid_type,
          priority: :routine,
          title: "Test Assignment",
          assigned_at: DateTime.utc_now(),
          officer_id: officer.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:assignment_type]
    end

    test "validates priority levels", %{tenant: tenant, officer: officer} do
      valid_priorities = [:low, :routine, :urgent, :high, :critical, :emergency]

      for priority <- valid_priorities do
        {:ok, _assignment} =
          Assignment.create(%{
            assignment_type: :patrol,
            priority: priority,
            title: "Test Assignment",
            assigned_at: DateTime.utc_now(),
            officer_id: officer.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Assignment.create(%{
          assignment_type: :patrol,
          priority: :invalid_priority,
          title: "Test Assignment",
          assigned_at: DateTime.utc_now(),
          officer_id: officer.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:priority]
    end

    test "updates assignment status lifecycle",
         %{tenant: tenant, officer: officer} do
      assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :assigned
        )

      # Start assignment
      {:ok, started_assignment} = Assignment.start_assignment(assignment)
      assert started_assignment.status == :in_progress
      assert started_assignment.started_at
      assert started_assignment.metadata["status_history"]

      # Complete assignment
      {:ok, completed_assignment} =
        Assignment.complete_assignment(started_assignment, %{
          completion_notes: "Assignment completed successfully",
          findings: "No incidents reported",
          next_actions: "Continue regular patrol schedule"
        })

      assert completed_assignment.status == :completed
      assert completed_assignment.completed_at
      assert completed_assignment.completion_notes == "Assignment completed
        successfully"

      # Verify status history
      status_history = completed_assignment.metadata["status_history"]
      assert length(status_history) >= 2
      assert Enum.any?(status_history, &(&1["status"] == "assigned"))
      assert Enum.any?(status_history, &(&1["status"] == "in_progress"))
      assert Enum.any?(status_history, &(&1["status"] == "completed"))
    end

    test "handles assignment cancellation",
         %{tenant: tenant, officer: officer} do
      assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :assigned
        )

      {:ok, cancelled_assignment} =
        Assignment.cancel_assignment(assignment, %{
          cancellation_reason: "Higher priority assignment received",
          cancelled_by: "Dispatch Supervisor",
          reassignment_needed: true
        })

      assert cancelled_assignment.status == :cancelled

      assert cancelled_assignment.metadata["cancellation_reason"] ==
               "Higher priority assignment received"

      assert cancelled_assignment.metadata["cancelled_by"] == "Dispatch
        Supervisor"
      assert cancelled_assignment.metadata["reassignment_needed"] == true
    end

    test "manages assignment escalation", %{tenant: tenant, officer: officer} do
      assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          priority: :routine,
          status: :in_progress
        )

      {:ok, escalated_assignment} =
        Assignment.escalate_priority(assignment, %{
          new_priority: :urgent,
          escalation_reason: "Suspicious activity observed",
          backup_requested: true,
          supervisor_notified: true
        })

      assert escalated_assignment.priority == :urgent
      assert escalated_assignment.metadata["escalation_history"]

      escalation = List.first(escalated_assignment.metadata["escalation_history"])
      assert escalation["from_priority"] == "routine"
      assert escalation["to_priority"] == "urgent"
      assert escalation["reason"] == "Suspicious activity observed"
      assert escalation["backup_requested"] == true
    end

    test "tracks assignment progress", %{tenant: tenant, officer: officer} do
      assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :in_progress,
          # 4 hours
          estimated_duration: 240
        )

      progress_update = %{
        progress_percentage: 50,
        current_activity: "Investigating reported incident",
        location_update: %{
          "latitude" => 40.7589,
          "longitude" => -73.9851,
          "timestamp" => DateTime.utc_now()
        },
        notes: "Interview with witness completed"
      }

      {:ok, updated_assignment} = Assignment.update_progress(assignment, progress_update)

      assert updated_assignment.metadata["progress"]["percentage"] == 50

      assert updated_assignment.metadata["progress"]["current_activity"] ==
               "Investigating reported incident"

      assert updated_assignment.metadata["progress"]["notes"] ==
               "Interview with witness completed"

      assert updated_assignment.metadata["location_updates"]
    end

    test "manages assignment resources", %{tenant: tenant, officer: officer} do
      assignment = insert(:assignment, tenant: tenant, officer: officer)

      vehicle = insert(:vehicle, tenant: tenant)
      team = insert(:team, tenant: tenant)

      resource_allocation = %{
        vehicles: [vehicle.id],
        additional_officers: [],
        equipment: ["radio", "body_camera", "tablet"],
        special_resources: ["K9_unit", "tactical_gear"]
      }

      {:ok, resourced_assignment} = Assignment.allocate_resources(assignment, resource_allocation)

      assert resourced_assignment.metadata["allocated_resources"]["vehicles"] == [vehicle.id]

      assert resourced_assignment.metadata["allocated_resources"]["equipment"] ==
               [
                 "radio",
                 "body_camera",
                 "tablet"
               ]

      assert resourced_assignment.metadata["allocated_resources"]["special_resources"] ==
               [
                 "K9_unit",
                 "tactical_gear"
               ]
    end

    test "calculates assignment metrics", %{tenant: tenant, officer: officer} do
      # Assignment that should be overdue
      overdue_assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :in_progress,
          # 2 hours ago
          assigned_at: DateTime.utc_now() |> DateTime.add(-7200, :second),
          # 1 hour
          estimated_duration: 3600,
          # 100 minutes ago
          started_at: DateTime.utc_now() |> DateTime.add(-6000, :second)
        )

      # Assignment on track
      on_track_assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :in_progress,
          # 30 minutes ago
          assigned_at: DateTime.utc_now() |> DateTime.add(-1800, :second),
          # 1 hour
          estimated_duration: 3600,
          # 25 minutes ago
          started_at: DateTime.utc_now() |> DateTime.add(-1500, :second)
        )

      overdue_with_calc =
        Assignment.read!(overdue_assignment.id, load: [:is_overdue?, :duration_minutes])

      on_track_with_calc =
        Assignment.read!(on_track_assignment.id, load: [:is_overdue?, :duration_minutes])

      assert overdue_with_calc.is_overdue? == true
      assert on_track_with_calc.is_overdue? == false
      assert overdue_with_calc.duration_minutes > 60
      assert on_track_with_calc.duration_minutes < 60
    end

    test "handles emergency assignments", %{tenant: tenant, officer: officer} do
      # Create alarm event for emergency assignment
      alarm = insert(:alarm_event, tenant: tenant)

      emergency_data = %{
        assignment_type: :emergency_response,
        priority: :emergency,
        title: "Burglar Alarm Response",
        description: "Alarm triggered at commercial building",
        alarm_event_id: alarm.id,
        # 5 minutes
        response_time_target: 300,
        backup_required: true,
        supervisor_notification: true
      }

      {:ok, emergency_assignment} =
        Assignment.create_emergency_assignment(officer, emergency_data)

      assert emergency_assignment.assignment_type == :emergency_response
      assert emergency_assignment.priority == :emergency
      assert emergency_assignment.metadata["alarm_event_id"] == alarm.id
      assert emergency_assignment.metadata["response_time_target"] == 300
      assert emergency_assignment.metadata["backup_required"] == true
    end

    test "manages assignment handover", %{tenant: tenant, officer: officer} do
      assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :in_progress
        )

      user2 = insert(:user, tenant: tenant)
      officer2 = insert(:officer, tenant: tenant, user: user2)

      handover_data = %{
        new_officer_id: officer2.id,
        handover_reason: "Shift change",
        current_status: "Investigation 50% complete",
        key_information: "Suspect last seen heading north on Main St",
        handover_notes: "Continue surveillance of suspect vehicle"
      }

      {:ok, handed_over_assignment} = Assignment.handover_assignment(assignment, handover_data)

      assert handed_over_assignment.officer_id == officer2.id
      assert handed_over_assignment.metadata["handover_history"]

      handover = List.first(handed_over_assignment.metadata["handover_history"])
      assert handover["from_officer_id"] == officer.id
      assert handover["to_officer_id"] == officer2.id
      assert handover["reason"] == "Shift change"
    end

    test "tracks response times", %{tenant: tenant, officer: officer} do
      # Assignment with good response time
      fast_assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          # 10 minutes ago
          assigned_at: DateTime.utc_now() |> DateTime.add(-600, :second),
          # 8 minutes ago
          started_at: DateTime.utc_now() |> DateTime.add(-480, :second),
          # 5 minutes target
          metadata: %{"response_time_target" => 300}
        )

      # Assignment with slow response time
      slow_assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          # 15 minutes ago
          assigned_at: DateTime.utc_now() |> DateTime.add(-900, :second),
          # 5 minutes ago
          started_at: DateTime.utc_now() |> DateTime.add(-300, :second),
          # 5 minutes target
          metadata: %{"response_time_target" => 300}
        )

      fast_with_calc =
        Assignment.read!(fast_assignment.id,
          load: [:response_time_seconds, :met_response_target?]
        )

      slow_with_calc =
        Assignment.read!(slow_assignment.id,
          load: [:response_time_seconds, :met_response_target?]
        )

      # 2 minutes
      assert fast_with_calc.response_time_seconds == 120
      # 10 minutes
      assert slow_with_calc.response_time_seconds == 600
      assert fast_with_calc.met_response_target? == true
      assert slow_with_calc.met_response_target? == false
    end

    test "generates assignment reports", %{tenant: tenant, officer: officer} do
      assignment =
        insert(:assignment,
          tenant: tenant,
          officer: officer,
          status: :completed,
          completion_notes: "All objectives completed successfully"
        )

      report_data = %{
        report_type: "incident_report",
        findings: "No criminal activity detected during patrol",
        evidence_collected: false,
        witnesses_interviewed: 0,
        follow_up_required: false,
        report_narrative: "Routine patrol completed without incidents"
      }

      {:ok, reported_assignment} = Assignment.generate_report(assignment, report_data)

      assert reported_assignment.metadata["reports"]
      report = List.first(reported_assignment.metadata["reports"])
      assert report["type"] == "incident_report"
      assert report["findings"] == "No criminal activity detected during patrol"
      assert report["follow_up_required"] == false
    end

    test "enforces tenant isolation", %{officer: officer} do
      tenant1 = officer.tenant
      tenant2 = insert(:tenant)
      user2 = insert(:user, tenant: tenant2)
      officer2 = insert(:officer, tenant: tenant2, user: user2)

      assignment1 = insert(:assignment, tenant: tenant1, officer: officer)
      assignment2 = insert(:assignment, tenant: tenant2, officer: officer2)

      tenant1_assignments = Assignment.read!(tenant: tenant1)
      tenant2_assignments = Assignment.read!(tenant: tenant2)

      assert length(tenant1_assignments) == 1
      assert length(tenant2_assignments) == 1
      assert Enum.any?(tenant1_assignments, &(&1.id == assignment1.id))
      assert Enum.any?(tenant2_assignments, &(&1.id == assignment2.id))
      refute Enum.any?(tenant1_assignments, &(&1.id == assignment2.id))
      refute Enum.any?(tenant2_assignments, &(&1.id == assignment1.id))
    end

    test "validates location data", %{tenant: tenant, officer: officer} do
      valid_locations = [
        %{"latitude" => 40.7128, "longitude" => -74.0060},
        %{"address" => "123 Main St", "city" => "New York", "state" => "NY"},
        %{"latitude" => 40.7128, "longitude" => -74.0060, "radius" => 100}
      ]

      for location <- valid_locations do
        {:ok, _assignment} =
          Assignment.create(%{
            assignment_type: :patrol,
            priority: :routine,
            title: "Test Assignment",
            location: location,
            assigned_at: DateTime.utc_now(),
            officer_id: officer.id,
            tenant_id: tenant.id
          })
      end

      # Invalid location (latitude out of range)
      invalid_location = %{"latitude" => 95.0, "longitude" => -74.0060}

      {:error, changeset} =
        Assignment.create(%{
          assignment_type: :patrol,
          priority: :routine,
          title: "Test Assignment",
          location: invalid_location,
          assigned_at: DateTime.utc_now(),
          officer_id: officer.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:location]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
