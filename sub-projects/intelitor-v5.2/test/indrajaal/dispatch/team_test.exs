defmodule Indrajaal.Dispatch.TeamTest do
  use Indrajaal.DataCase
  # Don't import Factory directly - DataCase provides insert function
  alias Indrajaal.Core.Tenant
  alias Indrajaal.Dispatch.{Team, Officer, Assignment}
  alias Indrajaal.Sites.Site

  describe "Team resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)

      {:ok, tenant: tenant, organization: organization, site: site}
    end

    test "creates a dispatch team with valid attributes", %{
      tenant: tenant,
      organization: organization
    } do
      attrs = %{
        name: "Alpha Response Team",
        team_type: :security,
        status: :available,
        capacity: 6,
        specializations: ["armed_response", "alarm_verification", "patrol"],
        coverage_areas: ["downtown", "industrial_district"],
        shift_schedule: %{
          "monday" => %{"start" => "06:00", "end" => "18:00"},
          "tuesday" => %{"start" => "06:00", "end" => "18:00"},
          "wednesday" => %{"start" => "06:00", "end" => "18:00"}
        },
        contact_info: %{
          "primary_phone" => "+1 - 555 - ALPHA1",
          "radio_channel" => "ALPHA - 1",
          "email" => "alpha.team@security.com"
        },
        organization_id: organization.id,
        tenant_id: tenant.id
      }

      {:ok, team} = Team.create(attrs)

      assert team.name == "Alpha Response Team"
      assert team.team_type == :security
      assert team.status == :available
      assert team.capacity == 6
      assert "armed_response" in team.specializations
      assert "downtown" in team.coverage_areas
      assert team.contact_info["radio_channel"] == "ALPHA - 1"
      assert team.organization_id == organization.id
      assert team.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Team.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:team_type]
      assert changeset.errors[:organization_id]
    end

    test "manages team status transitions",
         %{tenant: tenant, organization: organization} do
      team =
        insert(:team,
          status: :available,
          tenant: tenant,
          organization: organization
        )

      # Available -> Dispatched
      {:ok, dispatched_team} =
        Team.dispatch(team, %{
          assignment_id: "assignment-123",
          dispatch_reason: "Alarm response __required"
        })

      assert dispatched_team.status == :dispatched
      assert dispatched_team.current_assignment == "assignment-123"
      assert dispatched_team.metadata["dispatch_history"]

      # Dispatched -> Busy
      {:ok, busy_team} =
        Team.set_busy(dispatched_team, %{
          reason: "Investigating alarm"
        })

      assert busy_team.status == :busy

      # Busy -> Available
      {:ok, available_team} = Team.set_available(busy_team)
      assert available_team.status == :available
      assert available_team.current_assignment == nil
    end

    test "assigns officers to team",
         %{tenant: tenant, organization: organization} do
      team = insert(:team, tenant: tenant, organization: organization)

      # Create officers
      officer1 = insert(:officer, tenant: tenant, organization: organization)
      officer2 = insert(:officer, tenant: tenant, organization: organization)

      {:ok, team_with_officers} =
        Team.assign_officers(team, %{
          officer_ids: [officer1.id, officer2.id],
          roles: %{
            officer1.id => "team_leader",
            officer2.id => "member"
          }
        })

      assert team_with_officers.metadata["assigned_officers"]
      officers = team_with_officers.metadata["assigned_officers"]
      assert length(officers) == 2

      leader = Enum.find(officers, &(&1["officer_id"] == officer1.id))
      assert leader["role"] == "team_leader"
    end

    test "calculates team availability",
         %{tenant: tenant, organization: organization} do
      team =
        insert(:team,
          capacity: 4,
          status: :available,
          tenant: tenant,
          organization: organization
        )

      # Assign some officers
      for i <- 1..3 do
        officer = insert(:officer, tenant: tenant, organization: organization)

        Team.assign_officers(team, %{
          officer_ids: [officer.id],
          roles: %{officer.id => "member"}
        })
      end

      team_with_calc = Team.read!(team.id, load: [:availability_percentage])
      # 3 / 4 = 75%
      assert team_with_calc.availability_percentage == 75.0
    end

    test "manages team equipment",
         %{tenant: tenant, organization: organization} do
      team = insert(:team, tenant: tenant, organization: organization)

      equipment = %{
        "vehicles" => [
          %{"id" => "VEH - 001", "type" => "patrol_car", "license" => "SEC-123"},
          %{"id" => "VEH - 002", "type" => "motorcycle", "license" => "SEC - 124"}
        ],
        "communication" => [
          %{"type" => "radio", "model" => "MOTO - XR", "channel" => "ALPHA - 1"},
          %{"type" => "satellite_phone", "model" => "SAT - PRO"}
        ],
        "protective_gear" => [
          %{"type" => "body_armor", "level" => "IIIA", "quantity" => 4},
          %{"type" => "helmets", "quantity" => 4}
        ]
      }

      {:ok, equipped_team} =
        Team.assign_equipment(team, %{
          equipment: equipment
        })

      assert equipped_team.equipment["vehicles"]
      assert length(equipped_team.equipment["vehicles"]) == 2
      assert equipped_team.equipment["protective_gear"]
    end

    test "tracks team performance metrics",
         %{tenant: tenant, organization: organization} do
      team = insert(:team, tenant: tenant, organization: organization)

      # Log successful assignments
      for i <- 1..5 do
        {:ok, _} =
          Team.log_assignment_completion(team, %{
            assignment_id: "assign-#{i}",
            response_time_minutes: 15 + i,
            outcome: "successful",
            notes: "Assignment completed successfully"
          })
      end

      team_with_metrics = Team.read!(team.id, load: [:average_response_time])
      assert team_with_metrics.average_response_time >= 15.0
      assert team_with_metrics.average_response_time <= 20.0
    end

    test "manages team scheduling",
         %{tenant: tenant, organization: organization} do
      team = insert(:team, tenant: tenant, organization: organization)

      schedule = %{
        "weekly_schedule" => %{
          "monday" => %{"start" => "08:00", "end" => "20:00"},
          "tuesday" => %{"start" => "08:00", "end" => "20:00"},
          "wednesday" => %{"start" => "08:00", "end" => "20:00"}
        },
        "on_call_schedule" => %{
          "weekends" => true,
          "holidays" => true,
          "emergency_contact" => "+1 - 555 - EMERGENCY"
        }
      }

      {:ok, scheduled_team} =
        Team.update_schedule(team, %{
          shift_schedule: schedule
        })

      assert scheduled_team.shift_schedule["weekly_schedule"]["monday"]["start"] ==
               "08:00"

      assert scheduled_team.shift_schedule["on_call_schedule"]["weekends"] ==
               true
    end

    test "handles team alerts and notifications",
         %{tenant: tenant, organization: organization} do
      team = insert(:team, tenant: tenant, organization: organization)

      {:ok, team_with_alert} =
        Team.add_alert(team, %{
          alert_type: "officer_down",
          severity: "critical",
          message: "Emergency alert from officer badge",
          auto_escalate: true
        })

      assert team_with_alert.metadata["active_alerts"]
      alert = List.first(team_with_alert.metadata["active_alerts"])
      assert alert["type"] == "officer_down"
      assert alert["severity"] == "critical"
      assert alert["auto_escalate"] == true
    end

    test "calculates team coverage area",
         %{tenant: tenant, organization: organization} do
      team =
        insert(:team,
          coverage_areas: ["zone_1", "zone_2", "zone_3"],
          tenant: tenant,
          organization: organization
        )

      team_with_calc = Team.read!(team.id, load: [:coverage_zone_count])
      assert team_with_calc.coverage_zone_count == 3
    end

    test "manages team communication channels",
         %{tenant: tenant, organization: organization} do
      team = insert(:team, tenant: tenant, organization: organization)

      comm_config = %{
        "primary_radio" => %{
          "frequency" => "154.450",
          "channel" => "ALPHA - 1",
          "encryption" => true
        },
        "backup_radio" => %{
          "frequency" => "155.475",
          "channel" => "BACKUP - 1"
        },
        "mobile_data" => %{
          "carrier" => "SecureNet",
          "apn" => "secure.__data"
        }
      }

      {:ok, comm_team} =
        Team.configure_communications(team, %{
          communication_config: comm_config
        })

      assert comm_team.communication_config["primary_radio"]["frequency"] ==
               "154.450"

      assert comm_team.communication_config["primary_radio"]["encryption"] ==
               true
    end

    test "enforces tenant isolation", %{organization: organization} do
      tenant1 = organization.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)

      team1 = insert(:team, tenant: tenant1, organization: organization)
      team2 = insert(:team, tenant: tenant2, organization: organization2)

      tenant1_teams = Team.read!(tenant: tenant1)
      tenant2_teams = Team.read!(tenant: tenant2)

      assert length(tenant1_teams) == 1
      assert length(tenant2_teams) == 1
      assert Enum.any?(tenant1_teams, &(&1.id == team1.id))
      assert Enum.any?(tenant2_teams, &(&1.id == team2.id))
      refute Enum.any?(tenant1_teams, &(&1.id == team2.id))
      refute Enum.any?(tenant2_teams, &(&1.id == team1.id))
    end

    test "validates team specializations",
         %{tenant: tenant, organization: organization} do
      valid_specializations = [
        "armed_response",
        "alarm_verification",
        "patrol",
        "emergency_medical",
        "fire_response",
        "investigation"
      ]

      {:ok, team} =
        Team.create(%{
          name: "Specialized Team",
          team_type: :security,
          specializations: valid_specializations,
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      assert length(team.specializations) == 6
      assert "armed_response" in team.specializations
      assert "investigation" in team.specializations
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
