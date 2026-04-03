defmodule Indrajaal.Dispatch.OfficerTest do
  use Indrajaal.DataCase

  alias Indrajaal.Accounts.User
  alias Indrajaal.Core.Tenant
  alias Indrajaal.Dispatch.{Officer, Team, Assignment, Vehicle}

  describe "Officer resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      user = insert(:user, tenant: tenant)

      {:ok, tenant: tenant, organization: organization, user: user}
    end

    test "creates an officer with valid attributes",
         %{tenant: tenant, user: user} do
      attrs = %{
        badge_number: "BADGE - 001",
        rank: "Officer",
        status: :on_duty,
        specializations: ["patrol", "traffic", "emergency_response"],
        certifications: ["CPR", "First Aid", "Firearms"],
        contact_number: "+1 - 555 - 0123",
        radio_call_sign: "UNIT - 101",
        emergency_contact: %{
          "name" => "Jane Doe",
          "relationship" => "spouse",
          "phone" => "+1 - 555 - 0124"
        },
        user_id: user.id,
        tenant_id: tenant.id
      }

      {:ok, officer} = Officer.create(attrs)

      assert officer.badge_number == "BADGE - 001"
      assert officer.rank == "Officer"
      assert officer.status == :on_duty
      assert officer.specializations == ["patrol", "traffic", "emergency_response"]
      assert officer.certifications == ["CPR", "First Aid", "Firearms"]
      assert officer.contact_number == "+1 - 555 - 0123"
      assert officer.radio_call_sign == "UNIT - 101"
      assert officer.emergency_contact["name"] == "Jane Doe"
      assert officer.user_id == user.id
      assert officer.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Officer.create(%{tenant_id: tenant.id})

      assert changeset.errors[:badge_number]
      assert changeset.errors[:rank]
      assert changeset.errors[:contact_number]
      assert changeset.errors[:user_id]
    end

    test "validates unique badge number per tenant",
         %{tenant: tenant, user: user} do
      insert(:officer, badge_number: "UNIQUE - BADGE-123", tenant: tenant)

      user2 = insert(:user, tenant: tenant)

      {:error, changeset} =
        Officer.create(%{
          badge_number: "UNIQUE - BADGE-123",
          rank: "Officer",
          contact_number: "+1 - 555 - 0200",
          user_id: user2.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:badge_number]
    end

    test "validates officer status", %{tenant: tenant, user: user} do
      valid_statuses = [:on_duty, :off_duty, :break, :unavailable, :emergency, :training]

      for status <- valid_statuses do
        {:ok, _officer} =
          Officer.create(%{
            badge_number: "TEST-#{System.unique_integer()}",
            rank: "Officer",
            status: status,
            contact_number: "+1 - 555 - 0100",
            user_id: user.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Officer.create(%{
          badge_number: "TEST - INVALID",
          rank: "Officer",
          status: :invalid_status,
          contact_number: "+1 - 555 - 0100",
          user_id: user.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:status]
    end

    test "updates officer status", %{tenant: tenant, user: user} do
      officer = insert(:officer, tenant: tenant, user: user, status: :off_duty)

      {:ok, on_duty_officer} = Officer.report_for_duty(officer)
      assert on_duty_officer.status == :on_duty
      assert on_duty_officer.metadata["status_history"]

      {:ok, break_officer} =
        Officer.go_on_break(on_duty_officer, %{
          break_type: "lunch",
          estimated_duration: 30
        })

      assert break_officer.status == :break
      assert break_officer.metadata["break_info"]["type"] == "lunch"

      {:ok, back_officer} = Officer.return_from_break(break_officer)
      assert back_officer.status == :on_duty

      {:ok, off_duty_officer} =
        Officer.end_shift(back_officer, %{
          shift_end_time: DateTime.utc_now(),
          end_notes: "Routine shift completion"
        })

      assert off_duty_officer.status == :off_duty
    end

    test "manages officer assignments", %{tenant: tenant, user: user} do
      officer = insert(:officer, tenant: tenant, user: user, status: :on_duty)

      assignment_details = %{
        assignment_type: "patrol",
        zone: "downtown",
        priority: "routine",
        # 8 hours
        estimated_duration: 480,
        instructions: "Regular patrol of downtown area"
      }

      {:ok, assigned_officer} = Officer.assign_task(officer, assignment_details)

      assert assigned_officer.metadata["current_assignment"]
      assignment = assigned_officer.metadata["current_assignment"]
      assert assignment["type"] == "patrol"
      assert assignment["zone"] == "downtown"
      assert assignment["priority"] == "routine"

      {:ok, completed_officer} =
        Officer.complete_assignment(assigned_officer, %{
          completion_time: DateTime.utc_now(),
          completion_notes: "Patrol completed without incidents",
          status_report: "area_secure"
        })

      assert completed_officer.metadata["assignment_history"]
      completed_assignment = List.first(completed_officer.metadata["assignment_history"])
      assert completed_assignment["status"] == "completed"
      assert completed_assignment["completion_notes"] == "Patrol completed
        without incidents"
    end

    test "tracks officer location", %{tenant: tenant, user: user} do
      officer = insert(:officer, tenant: tenant, user: user)

      location_data = %{
        latitude: 40.7128,
        longitude: -74.0060,
        accuracy: 5.0,
        altitude: 10.5,
        heading: 45.0,
        speed: 0.0
      }

      {:ok, located_officer} = Officer.update_location(officer, location_data)

      assert located_officer.metadata["current_location"]["latitude"] == 40.7128

      assert located_officer.metadata["current_location"]["longitude"] ==
               -74.0060

      assert located_officer.metadata["current_location"]["accuracy"] == 5.0
      assert located_officer.metadata["location_updated_at"]
    end

    test "manages officer certifications", %{tenant: tenant, user: user} do
      officer =
        insert(:officer,
          tenant: tenant,
          user: user,
          certifications: ["CPR", "First Aid"]
        )

      new_certification = %{
        certification_name: "Advanced Firearms Training",
        issuing_authority: "State Police Academy",
        issue_date: Date.utc_today(),
        expiry_date: Date.utc_today() |> Date.add(365),
        certification_number: "AFT - 2024 - 001"
      }

      {:ok, certified_officer} = Officer.add_certification(officer, new_certification)

      assert "Advanced Firearms Training" in certified_officer.certifications
      assert certified_officer.metadata["certification_details"]

      cert_detail =
        Enum.find(
          certified_officer.metadata["certification_details"],
          &(&1["name"] == "Advanced Firearms Training")
        )

      assert cert_detail["issuing_authority"] == "State Police Academy"
      assert cert_detail["certification_number"] == "AFT - 2024 - 001"
    end

    test "calculates officer availability", %{tenant: tenant, user: user} do
      # Officer with current assignment
      busy_officer =
        insert(:officer,
          tenant: tenant,
          user: user,
          status: :on_duty,
          metadata: %{
            "current_assignment" => %{
              "type" => "emergency_response",
              "priority" => "high",
              # 30 minutes ago
              "started_at" => DateTime.utc_now() |> DateTime.add(-1800, :second)
            }
          }
        )

      # Officer without assignment
      available_officer =
        insert(:officer,
          tenant: tenant,
          user: user,
          status: :on_duty
        )

      # Officer on break
      break_officer =
        insert(:officer,
          tenant: tenant,
          user: user,
          status: :break
        )

      busy_with_calc = Officer.read!(busy_officer.id, load: [:is_available?])
      available_with_calc = Officer.read!(available_officer.id, load: [:is_available?])
      break_with_calc = Officer.read!(break_officer.id, load: [:is_available?])

      assert busy_with_calc.is_available? == false
      assert available_with_calc.is_available? == true
      assert break_with_calc.is_available? == false
    end

    test "tracks officer performance metrics", %{tenant: tenant, user: user} do
      officer =
        insert(:officer,
          tenant: tenant,
          user: user,
          metadata: %{
            "assignments_completed" => 25,
            "total_assignments" => 30,
            "average_response_time" => 8.5,
            "commendations" => 3,
            "incidents" => 1
          }
        )

      officer_with_calc = Officer.read!(officer.id, load: [:completion_rate, :performance_score])

      # ~0.833
      assert officer_with_calc.completion_rate == 25 / 30
      assert is_float(officer_with_calc.performance_score)
      assert officer_with_calc.performance_score > 0
    end

    test "manages officer equipment", %{tenant: tenant, user: user} do
      officer = insert(:officer, tenant: tenant, user: user)

      equipment_list = [
        %{
          "item" => "Radio",
          "model" => "Motorola XPR - 7550",
          "serial_number" => "RAD - 001 - 2024",
          "status" => "operational",
          "checked_out" => DateTime.utc_now()
        },
        %{
          "item" => "Body Camera",
          "model" => "Axon Body 3",
          "serial_number" => "CAM - 001 - 2024",
          "status" => "operational",
          "checked_out" => DateTime.utc_now()
        }
      ]

      {:ok, equipped_officer} =
        Officer.assign_equipment(officer, %{
          equipment: equipment_list
        })

      assert length(equipped_officer.metadata["assigned_equipment"]) == 2

      radio =
        Enum.find(
          equipped_officer.metadata["assigned_equipment"],
          &(&1["item"] == "Radio")
        )

      assert radio["model"] == "Motorola XPR - 7550"
      assert radio["status"] == "operational"

      {:ok, returned_officer} =
        Officer.return_equipment(equipped_officer, %{
          equipment_serial: "RAD - 001 - 2024",
          return_condition: "good",
          return_notes: "Normal wear, no damage"
        })

      returned_equipment = returned_officer.metadata["equipment_history"]
      assert returned_equipment
    end

    test "handles emergency situations", %{tenant: tenant, user: user} do
      officer = insert(:officer, tenant: tenant, user: user, status: :on_duty)

      emergency_data = %{
        emergency_type: "officer_down",
        location: %{
          "latitude" => 40.7580,
          "longitude" => -73.9855,
          "address" => "123 Emergency St, New York, NY"
        },
        severity: "critical",
        assistance_requested: true,
        medical_needed: true
      }

      {:ok, emergency_officer} = Officer.declare_emergency(officer, emergency_data)

      assert emergency_officer.status == :emergency

      assert emergency_officer.metadata["emergency_status"]["type"] ==
               "officer_down"

      assert emergency_officer.metadata["emergency_status"]["severity"] ==
               "critical"

      assert emergency_officer.metadata["emergency_status"]["assistance_requested"] ==
               true

      {:ok, cleared_officer} =
        Officer.clear_emergency(emergency_officer, %{
          resolution_type: "false_alarm",
          resolution_notes: "Accidental activation, officer is safe",
          cleared_by: "Supervisor Johnson"
        })

      assert cleared_officer.status == :on_duty
      assert cleared_officer.metadata["emergency_history"]
    end

    test "manages officer training records", %{tenant: tenant, user: user} do
      officer = insert(:officer, tenant: tenant, user: user)

      training_record = %{
        training_name: "De - escalation Techniques",
        instructor: "Training Instructor Smith",
        start_date: Date.utc_today() |> Date.add(-7),
        end_date: Date.utc_today(),
        hours: 40,
        grade: "A",
        passing: true,
        notes: "Excellent performance in practical scenarios"
      }

      {:ok, trained_officer} = Officer.add_training_record(officer, training_record)

      assert trained_officer.metadata["training_records"]
      training = List.first(trained_officer.metadata["training_records"])
      assert training["training_name"] == "De - escalation Techniques"
      assert training["grade"] == "A"
      assert training["passing"] == true
    end

    test "tracks shift patterns and hours", %{tenant: tenant, user: user} do
      officer =
        insert(:officer,
          tenant: tenant,
          user: user,
          metadata: %{
            "shift_schedule" => %{
              "pattern" => "4_on_4_off",
              "start_time" => "06:00",
              "end_time" => "18:00"
            },
            "hours_this_week" => 32,
            "overtime_hours" => 4
          }
        )

      shift_data = %{
        # 8 hours ago
        shift_start: DateTime.utc_now() |> DateTime.add(-28_800, :second),
        shift_end: DateTime.utc_now(),
        # 1 hour
        break_duration: 60,
        overtime: true,
        shift_notes: "Busy shift with multiple calls"
      }

      {:ok, shift_officer} = Officer.log_shift(officer, shift_data)

      assert shift_officer.metadata["shift_history"]
      logged_shift = List.first(shift_officer.metadata["shift_history"])
      # 8 hours in seconds
      assert logged_shift["duration"] == 8 * 3600
      assert logged_shift["overtime"] == true
    end

    test "enforces tenant isolation", %{user: user} do
      tenant1 = user.tenant
      tenant2 = insert(:tenant)
      user2 = insert(:user, tenant: tenant2)

      officer1 = insert(:officer, tenant: tenant1, user: user)
      officer2 = insert(:officer, tenant: tenant2, user: user2)

      tenant1_officers = Officer.read!(tenant: tenant1)
      tenant2_officers = Officer.read!(tenant: tenant2)

      assert length(tenant1_officers) == 1
      assert length(tenant2_officers) == 1
      assert Enum.any?(tenant1_officers, &(&1.id == officer1.id))
      assert Enum.any?(tenant2_officers, &(&1.id == officer2.id))
      refute Enum.any?(tenant1_officers, &(&1.id == officer2.id))
      refute Enum.any?(tenant2_officers, &(&1.id == officer1.id))
    end

    test "validates radio call sign format", %{tenant: tenant, user: user} do
      valid_call_signs = ["UNIT - 101", "CAR - 25", "PATROL - 7", "K9 - 3", "ADMIN - 1"]

      for call_sign <- valid_call_signs do
        {:ok, _officer} =
          Officer.create(%{
            badge_number: "TEST-#{System.unique_integer()}",
            rank: "Officer",
            contact_number: "+1 - 555 - 0100",
            radio_call_sign: call_sign,
            user_id: user.id,
            tenant_id: tenant.id
          })
      end

      # Invalid call signs (too short, contains invalid characters)
      invalid_call_signs = ["A", "UNIT@101", ""]

      for call_sign <- invalid_call_signs do
        {:error, changeset} =
          Officer.create(%{
            badge_number: "TEST-#{System.unique_integer()}",
            rank: "Officer",
            contact_number: "+1 - 555 - 0100",
            radio_call_sign: call_sign,
            user_id: user.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:radio_call_sign]
      end
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
