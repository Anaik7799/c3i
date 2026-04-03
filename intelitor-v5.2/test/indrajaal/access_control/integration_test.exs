defmodule Indrajaal.AccessControl.IntegrationTest do
  use Indrajaal.DataCase, async: true

  alias Indrajaal.AccessControl.{
    AccessCredential,
    AccessLevel,
    AccessSchedule,
    AccessRequest,
    AccessGrant,
    AccessLog,
    VisitorPass,
    AntiPassback,
    AccessException
  }

  describe "complete access control workflow" do
    test "user requests access, gets approved, and logs entry" do
      # Setup
      tenant = create_tenant()
      user = create_user(tenant)
      admin = create_admin(tenant)
      site = create_site(tenant)
      device = create_reader_device(tenant, site)

      # Step 1: Issue credential
      {:ok, credential} =
        AccessCredential.issue(
          %{
            credential_type: :card,
            credential_number: "12_345_678",
            user_id: user.id
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert credential.credential_type == :card
      assert credential.user_id == user.id
      assert credential.status == :active

      # Step 2: Create access level
      {:ok, level} =
        AccessLevel.create(
          %{
            name: "Office Access",
            code: "OFFICE",
            access_points: [device.id]
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert level.name == "Office Access"
      assert level.code == "OFFICE"

      # Step 3: Create access schedule (business hours)
      {:ok, schedule} =
        AccessSchedule.create(
          %{
            name: "Business Hours",
            schedule_type: :business_hours
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      # Step 4: Submit access request
      {:ok, request} =
        AccessRequest.submit(
          %{
            request_type: :permanent,
            justification: "New employee needs office access",
            requested_areas: [device.id],
            requested_from: DateTime.utc_now(),
            requested_for_id: user.id,
            access_level_id: level.id
          },
          actor: %{tenant_id: tenant.id, id: user.id, role: "user"}
        )

      assert request.status == :pending
      assert request.request_type == :permanent

      # Step 5: Approve request (creates grant)
      {:ok, approved_request} =
        AccessRequest.approve(
          request,
          %{
            approval_notes: "Employment verified, office access approved"
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert approved_request.status == :approved
      assert approved_request.approval_notes == "Employment verified,
        office access approved"

      # Step 6: Create access grant manually (in real system this would be auto
      {:ok, grant} =
        AccessGrant.grant(
          %{
            grant_type: :permanent,
            access_credential_id: credential.id,
            access_level_id: level.id,
            access_schedule_id: schedule.id
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert grant.status == :active
      assert grant.grant_type == :permanent

      # Step 7: Initialize anti - passback for zone
      zone = create_zone(tenant, site)

      {:ok, apb} =
        AntiPassback.initialize(
          %{
            access_credential_id: credential.id,
            zone_id: zone.id,
            enforcement_level: :warning
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert apb.current_state == :outside
      assert apb.enforcement_level == :warning

      # Step 8: Log successful access attempt
      {:ok, log} =
        AccessLog.log_access(
          %{
            event_type: :granted,
            access_point_id: device.id,
            direction: :in,
            access_credential_id: credential.id,
            access_grant_id: grant.id,
            user_id: user.id,
            device_id: device.id
          },
          actor: %{tenant_id: tenant.id}
        )

      assert log.event_type == :granted
      assert log.direction == :in

      # Step 9: Update anti - passback state
      {:ok, updated_apb} =
        AntiPassback.record_entry(
          apb,
          %{
            last_access_point_id: device.id
          },
          actor: %{tenant_id: tenant.id}
        )

      assert updated_apb.current_state == :inside
      assert updated_apb.last_entry_time != nil

      # Step 10: Create visitor pass
      {:ok, visitor_pass} =
        VisitorPass.issue(
          %{
            pass_number: "V001",
            visitor_name: "John Visitor",
            visitor_company: "Partner Corp",
            host_name: user.name || "Test Host",
            purpose: "Business meeting",
            expires_at: DateTime.add(DateTime.utc_now(), 4, :hour),
            areas_allowed: [device.id],
            host_user_id: user.id,
            identification_verified: true
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert visitor_pass.visitor_name == "John Visitor"
      assert visitor_pass.status == :active

      # Step 11: Create emergency access exception
      {:ok, exception} =
        AccessException.create_exception(
          %{
            exception_type: :emergency,
            reason: "Fire drill - emergency evacuation access needed",
            authorized_by_name: "Security Chief",
            authorized_by_role: "Chief Security Officer",
            expires_at: DateTime.add(DateTime.utc_now(), 1, :hour),
            access_points_affected: [device.id],
            authorized_by_id: admin.id
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert exception.exception_type == :emergency
      assert exception.status == :active
    end

    test "access denial workflow" do
      tenant = create_tenant()
      user = create_user(tenant)
      admin = create_admin(tenant)
      site = create_site(tenant)
      device = create_reader_device(tenant, site)

      # Create credential but no grant
      {:ok, credential} =
        AccessCredential.issue(
          %{
            credential_type: :card,
            credential_number: "87_654_321",
            user_id: user.id
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      # Log denied access attempt
      {:ok, log} =
        AccessLog.log_access(
          %{
            event_type: :denied,
            access_point_id: device.id,
            direction: :in,
            denial_reason: "No valid access grant found",
            credential_presented: "87_654_321",
            access_credential_id: credential.id,
            user_id: user.id,
            device_id: device.id
          },
          actor: %{tenant_id: tenant.id}
        )

      assert log.event_type == :denied
      assert log.denial_reason == "No valid access grant found"
    end

    test "credential suspension and reactivation" do
      tenant = create_tenant()
      user = create_user(tenant)
      admin = create_admin(tenant)

      {:ok, credential} =
        AccessCredential.issue(
          %{
            credential_type: :card,
            credential_number: "11_111_111",
            user_id: user.id
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      # Suspend credential
      {:ok, suspended} =
        AccessCredential.suspend(credential, %{},
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert suspended.status == :suspended

      # Reactivate credential
      {:ok, reactivated} =
        AccessCredential.reactivate(suspended, %{},
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      assert reactivated.status == :active
    end

    test "anti - passback violation detection" do
      tenant = create_tenant()
      user = create_user(tenant)
      admin = create_admin(tenant)
      site = create_site(tenant)
      zone = create_zone(tenant, site)

      {:ok, credential} =
        AccessCredential.issue(
          %{
            credential_type: :card,
            credential_number: "22_222_222",
            user_id: user.id
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      {:ok, apb} =
        AntiPassback.initialize(
          %{
            access_credential_id: credential.id,
            zone_id: zone.id,
            enforcement_level: :strict
          },
          actor: %{tenant_id: tenant.id, id: admin.id, role: "admin"}
        )

      # Try to enter when already outside (should work)
      {:ok, entered} = AntiPassback.record_entry(apb, %{}, actor: %{tenant_id: tenant.id})
      assert entered.current_state == :inside

      # Try to enter again without exiting (violation)
      {:ok, violation} =
        AntiPassback.record_violation(entered, %{}, actor: %{tenant_id: tenant.id})

      assert violation.violation_count == 1
    end
  end

  # Helper functions
  defp create_tenant do
    {:ok, tenant} =
      Indrajaal.Core.Tenant.create(%{
        name: "Test Tenant",
        slug: "test-tenant-#{System.unique_integer([:positive])}"
      })

    tenant
  end

  defp create_user(tenant) do
    {:ok, user} =
      Indrajaal.Accounts.User.create(
        %{
          email: "user#{System.unique_integer([:positive])}@example.com",
          name: "Test User"
        },
        actor: %{tenant_id: tenant.id}
      )

    user
  end

  defp create_admin(tenant) do
    {:ok, admin} =
      Indrajaal.Accounts.User.create(
        %{
          email: "admin#{System.unique_integer([:positive])}@example.com",
          name: "Test Admin"
        },
        actor: %{tenant_id: tenant.id}
      )

    admin
  end

  defp create_site(tenant) do
    {:ok, site} =
      Indrajaal.Sites.Site.create(
        %{
          name: "Test Site",
          address: "123 Test St"
        },
        actor: %{tenant_id: tenant.id}
      )

    site
  end

  defp create_zone(tenant, site) do
    {:ok, zone} =
      Indrajaal.Sites.Zone.create(
        %{
          name: "Test Zone",
          site_id: site.id
        },
        actor: %{tenant_id: tenant.id}
      )

    zone
  end

  defp create_reader_device(tenant, site) do
    # This would need to be adjusted based on your Device implementation
    {:ok, device} =
      Indrajaal.Devices.Device.create(
        %{
          name: "Card Reader 001",
          device_type: :reader,
          location: "Main Entrance"
        },
        actor: %{tenant_id: tenant.id}
      )

    device
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
