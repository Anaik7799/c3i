defmodule Intelitor.DomainIntegrationTest do
  use Intelitor.DataCase

  alias Intelitor.Core.{Tenant, Organization}
  alias Intelitor.Accounts.{User, Team}
  alias Intelitor.Policy.{Role, Permission, UserRole}
  alias Intelitor.Sites.{Site, Building, Zone}
  alias Intelitor.Devices.{Device, Camera}
  alias Intelitor.Alarms.AlarmEvent
  alias Intelitor.Integrations.{Webhook, ApiConnection}

  describe "cross-domain integration" do
    setup do
      # Create tenant and organization
      tenant = insert(:tenant, name: "Integration Test Tenant")

      organization =
        insert(:organization,
          tenant: tenant,
          name: "Test Security Company"
        )

      # Create admin user
      admin_user =
        insert(:user,
          tenant: tenant,
          email: "admin@test.com"
        )

      # Create admin role and permissions
      admin_role =
        insert(:role,
          tenant: tenant,
          name: "admin",
          description: "System Administrator"
        )

      site_permission =
        insert(:permission,
          tenant: tenant,
          name: "site.manage",
          description: "Manage sites"
        )

      device_permission =
        insert(:permission,
          tenant: tenant,
          name: "device.manage",
          description: "Manage devices"
        )

      # Assign permissions to role
      insert(:role_permission,
        tenant: tenant,
        role: admin_role,
        permission: site_permission
      )

      insert(:role_permission,
        tenant: tenant,
        role: admin_role,
        permission: device_permission
      )

      # Assign role to user
      insert(:user_role,
        tenant: tenant,
        user: admin_user,
        role: admin_role
      )

      {:ok,
       tenant: tenant, organization: organization, admin_user: admin_user, admin_role: admin_role}
    end

    test "complete security monitoring workflow", %{
      tenant: tenant,
      organization: organization,
      admin_user: admin_user
    } do
      # 1. Create a site
      {:ok, site} =
        Site.create(%{
          name: "Corporate Headquarters",
          code: "HQ-001",
          description: "Main office building",
          address: %{
            "line1" => "123 Business Ave",
            "city" => "Tech City",
            "__state" => "CA",
            "postal_code" => "12345"
          },
          coordinates: %{"lat" => 37.7749, "lng" => -122.4194},
          site_type: :office,
          security_level: :high,
          max_occupancy: 1000,
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      # 2. Create building within site
      {:ok, building} =
        Building.create(%{
          name: "Main Building",
          code: "MB-001",
          description: "Primary office building",
          building_type: :main,
          floor_count: 10,
          site_id: site.id,
          tenant_id: tenant.id
        })

      # 3. Create security zone
      {:ok, zone} =
        Zone.create(%{
          name: "Executive Floor Zone",
          code: "EXEC-001",
          description: "High security executive area",
          zone_type: :secure,
          security_level: :critical,
          access_control_type: :biometric,
          monitoring_level: :ai_enhanced,
          site_id: site.id,
          building_id: building.id,
          tenant_id: tenant.id
        })

      # 4. Create security device (camera)
      {:ok, camera} =
        Camera.create(%{
          name: "Executive Entrance Camera",
          serial_number: "CAM-001-HQ",
          device_type: "ip_camera",
          manufacturer: "SecureTech",
          model: "ST-4K-001",
          firmware_version: "2.1.0",
          ip_address: "192.168.1.100",
          status: :online,
          location_description: "Executive floor main entrance",
          resolution: "4K",
          ptz_capable?: true,
          night_vision?: true,
          audio_enabled?: true,
          recording_enabled?: true,
          motion_detection?: true,
          site_id: site.id,
          building_id: building.id,
          zone_id: zone.id,
          tenant_id: tenant.id
        })

      # 5. Create webhook for alarm notifications
      {:ok, webhook} =
        Webhook.create(%{
          name: "Security Alarm Webhook",
          url: "https://api.securitypartner.com/webhooks/alarms",
          events: ["alarm.triggered", "device.offline"],
          active?: true,
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      # 6. Create API connection for external integration
      {:ok, api_connection} =
        ApiConnection.create(%{
          name: "Video Management System",
          connection_type: :onvif,
          base_url: "http://192.168.1.100:80",
          username: "admin",
          password: "secure123",
          enabled?: true,
          organization_id: organization.id,
          tenant_id: tenant.id
        })

      # 7. Trigger an alarm __event
      {:ok, alarm} =
        AlarmEvent.create(%{
          event_type: "motion_detected",
          severity: :high,
          source_type: :camera,
          source_id: camera.id,
          description: "Unauthorized motion detected in executive area",
          location_data: %{
            "site_id" => site.id,
            "building_id" => building.id,
            "zone_id" => zone.id
          },
          tenant_id: tenant.id
        })

      # 8. Verify all entities were created successfully
      assert site.name == "Corporate Headquarters"
      assert building.site_id == site.id
      assert zone.site_id == site.id
      assert zone.security_level == :critical
      assert camera.zone_id == zone.id
      assert camera.status == :online
      assert webhook.active? == true
      assert api_connection.enabled? == true
      assert alarm.severity == :high
      assert alarm.source_id == camera.id

      # 9. Test tenant isolation
      other_tenant = insert(:tenant)

      # These queries should only return data for the correct tenant
      tenant_sites = Site.read!(tenant: tenant)
      other_tenant_sites = Site.read!(tenant: other_tenant)

      assert length(tenant_sites) == 1
      assert Enum.empty?(other_tenant_sites)
      assert Enum.any?(tenant_sites, &(&1.id == site.id))

      # 10. Test relationships and calculations
      site_with_calculations =
        Site.read!(site.id,
          load: [
            :building_count,
            :zone_count,
            :is_active?,
            :occupancy_percentage
          ]
        )

      assert site_with_calculations.building_count == 1
      assert site_with_calculations.zone_count == 1
      assert site_with_calculations.is_active? == true
      assert site_with_calculations.occupancy_percentage == 0.0

      # 11. Test zone security level automation
      assert zone.access_control_type == :biometric
      assert zone.monitoring_level == :ai_enhanced
      assert zone.auto_lockdown? == true
      assert zone.visitor_allowed? == false

      # 12. Test webhook success rate calculation
      webhook_with_calc = Webhook.read!(webhook.id, load: [:success_rate, :is_healthy?])
      # No calls yet
      assert webhook_with_calc.success_rate == 0.0
      # No failures
      assert webhook_with_calc.is_healthy? == true

      # 13. Test API connection health
      api_with_calc = ApiConnection.read!(api_connection.id, load: [:is_healthy?])
      # Not connected yet
      assert api_with_calc.is_healthy? == false

      # 14. Test updating occupancy
      {:ok, updated_site} = Site.update_occupancy(site, %{occupancy: 250})
      assert updated_site.current_occupancy == 250

      updated_with_calc = Site.read!(updated_site.id, load: [:occupancy_percentage])
      assert updated_with_calc.occupancy_percentage == 25.0

      # 15. Test zone lockdown
      {:ok, locked_zone} =
        Zone.trigger_lockdown(zone, %{
          reason: "Security breach detected"
        })

      assert locked_zone.auto_lockdown? == true

      # Verify lockdown was recorded in metadata
      assert Map.has_key?(locked_zone.metadata, "lockdown_history")
      lockdown_entries = locked_zone.metadata["lockdown_history"]
      assert length(lockdown_entries) == 1
      assert List.first(lockdown_entries)["reason"] == "Security breach detected"
    end

    test "multi-tenant data isolation", %{tenant: tenant, organization: organization} do
      # Create data for first tenant
      site1 = insert(:site, tenant: tenant, organization: organization)
      device1 = insert(:device, tenant: tenant, site: site1)

      # Create second tenant with its own data
      tenant2 = insert(:tenant)
      org2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: org2)
      device2 = insert(:device, tenant: tenant2, site: site2)

      # Verify tenant1 can only see its own data
      tenant1_sites = Site.read!(tenant: tenant)
      tenant1_devices = Device.read!(tenant: tenant)

      assert length(tenant1_sites) == 1
      assert length(tenant1_devices) == 1
      assert Enum.any?(tenant1_sites, &(&1.id == site1.id))
      assert Enum.any?(tenant1_devices, &(&1.id == device1.id))
      refute Enum.any?(tenant1_sites, &(&1.id == site2.id))
      refute Enum.any?(tenant1_devices, &(&1.id == device2.id))

      # Verify tenant2 can only see its own data
      tenant2_sites = Site.read!(tenant: tenant2)
      tenant2_devices = Device.read!(tenant: tenant2)

      assert length(tenant2_sites) == 1
      assert length(tenant2_devices) == 1
      assert Enum.any?(tenant2_sites, &(&1.id == site2.id))
      assert Enum.any?(tenant2_devices, &(&1.id == device2.id))
      refute Enum.any?(tenant2_sites, &(&1.id == site1.id))
      refute Enum.any!(tenant2_devices, &(&1.id == device1.id))
    end

    test "policy-based access control", %{
      tenant: tenant,
      organization: organization,
      admin_user: admin_user
    } do
      # Create regular user without admin permissions
      regular_user =
        insert(:user,
          tenant: tenant,
          email: "user@test.com",
          role: "user"
        )

      user_role =
        insert(:role,
          tenant: tenant,
          name: "user",
          description: "Regular User"
        )

      read_permission =
        insert(:permission,
          tenant: tenant,
          name: "site.read",
          description: "Read sites"
        )

      insert(:role_permission,
        tenant: tenant,
        role: user_role,
        permission: read_permission
      )

      insert(:user_role,
        tenant: tenant,
        user: regular_user,
        role: user_role
      )

      site = insert(:site, tenant: tenant, organization: organization)

      # Admin should be able to read and modify
      admin_sites = Site.read!(actor: admin_user, tenant: tenant)
      assert length(admin_sites) == 1

      # Regular user should only be able to read
      user_sites = Site.read!(actor: regular_user, tenant: tenant)
      assert length(user_sites) == 1

      # Regular user should not be able to create sites
      {:error, _} =
        Site.create(
          %{
            name: "Unauthorized Site",
            code: "UNAUTH-001",
            organization_id: organization.id,
            tenant_id: tenant.id
          },
          actor: regular_user
        )
    end

    test "alarm workflow with device integration", %{tenant: tenant, organization: organization} do
      # Create the infrastructure
      site = insert(:site, tenant: tenant, organization: organization)
      zone = insert(:zone, tenant: tenant, site: site, security_level: :high)
      camera = insert(:camera, tenant: tenant, site: site, zone: zone)

      # Create alarm __event from camera
      {:ok, alarm} =
        AlarmEvent.create(%{
          event_type: "motion_detected",
          severity: :medium,
          source_type: :camera,
          source_id: camera.id,
          description: "Motion detected by camera #{camera.name}",
          location_data: %{
            "site_id" => site.id,
            "zone_id" => zone.id,
            "camera_id" => camera.id
          },
          tenant_id: tenant.id
        })

      # Verify alarm was created with correct relationships
      assert alarm.source_id == camera.id
      assert alarm.source_type == :camera
      assert alarm.location_data["site_id"] == site.id
      assert alarm.location_data["zone_id"] == zone.id

      # Test alarm escalation based on zone security level
      if zone.security_level in [:high, :critical] do
        assert alarm.severity in [:medium, :high, :critical]
      end

      # Create webhook for alarm notifications
      webhook =
        insert(:webhook,
          tenant: tenant,
          organization: organization,
          events: ["alarm.triggered"],
          active?: true
        )

      # Simulate webhook call
      {:ok, _} = Webhook.record_success(webhook)

      updated_webhook = Webhook.read!(webhook.id)
      assert updated_webhook.total_calls == 1
      assert updated_webhook.failure_count == 0
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
