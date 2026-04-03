defmodule Indrajaal.Devices.DeviceTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Devices.Device
  alias Indrajaal.Sites.Site

  describe "Device resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)

      {:ok, tenant: tenant, organization: organization, site: site}
    end

    test "creates a device with valid attributes",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "Main Entrance Camera",
        serial_number: "CAM - 001 - 2024",
        device_type: "ip_camera",
        manufacturer: "SecureTech",
        model: "ST - 4K - PRO",
        firmware_version: "2.1.5",
        hardware_version: "1.0",
        mac_address: "00:1A:2B:3C:4D:5E",
        ip_address: "192.168.1.100",
        status: :online,
        location_description: "Main entrance lobby",
        installation_date: ~D[2024-01-15],
        configuration: %{
          "resolution" => "4K",
          "fps" => 30,
          "compression" => "H.265"
        },
        site_id: site.id,
        tenant_id: tenant.id
      }

      {:ok, device} = Device.create(attrs)

      assert device.name == "Main Entrance Camera"
      assert device.serial_number == "CAM - 001 - 2024"
      assert device.device_type == "ip_camera"
      assert device.manufacturer == "SecureTech"
      assert device.model == "ST - 4K - PRO"
      assert device.status == :online
      assert device.mac_address == "00:1A:2B:3C:4D:5E"
      assert device.ip_address == "192.168.1.100"
      assert device.site_id == site.id
      assert device.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Device.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:serial_number]
      assert changeset.errors[:device_type]
      assert changeset.errors[:site_id]
    end

    test "validates unique serial number per tenant",
         %{tenant: tenant, site: site} do
      insert(:device,
        serial_number: "UNIQUE-123",
        tenant: tenant,
        site: site
      )

      {:error, changeset} =
        Device.create(%{
          name: "Another Device",
          serial_number: "UNIQUE-123",
          device_type: "sensor",
          site_id: site.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:serial_number]
    end

    test "validates MAC address format", %{tenant: tenant, site: site} do
      valid_macs = [
        "00:1A:2B:3C:4D:5E",
        "AA:BB:CC:DD:EE:FF",
        "12:34:56:78:9A:BC"
      ]

      invalid_macs = [
        "invalid-mac",
        "00:1A:2B:3C:4D",
        "00 - 1A - 2B - 3C - 4D - 5E",
        "00:1A:2B:3C:4D:5E:FF"
      ]

      for mac <- valid_macs do
        {:ok, _device} =
          Device.create(%{
            name: "Test Device",
            serial_number: "TEST-#{System.unique_integer()}",
            device_type: "sensor",
            mac_address: mac,
            site_id: site.id,
            tenant_id: tenant.id
          })
      end

      for mac <- invalid_macs do
        {:error, changeset} =
          Device.create(%{
            name: "Test Device",
            serial_number: "TEST-#{System.unique_integer()}",
            device_type: "sensor",
            mac_address: mac,
            site_id: site.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:mac_address]
      end
    end

    test "validates IP address format", %{tenant: tenant, site: site} do
      valid_ips = [
        "192.168.1.100",
        "10.0.0.1",
        "172.16.255.254",
        # IPv6
        "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
      ]

      invalid_ips = [
        "256.256.256.256",
        "192.168.1",
        "not - an - ip",
        "192.168.1.256"
      ]

      for ip <- valid_ips do
        {:ok, _device} =
          Device.create(%{
            name: "Test Device",
            serial_number: "TEST-#{System.unique_integer()}",
            device_type: "sensor",
            ip_address: ip,
            site_id: site.id,
            tenant_id: tenant.id
          })
      end

      for ip <- invalid_ips do
        {:error, changeset} =
          Device.create(%{
            name: "Test Device",
            serial_number: "TEST-#{System.unique_integer()}",
            device_type: "sensor",
            ip_address: ip,
            site_id: site.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:ip_address]
      end
    end

    test "updates device status with history tracking",
         %{tenant: tenant, site: site} do
      device =
        insert(:device,
          status: :online,
          tenant: tenant,
          site: site
        )

      {:ok, updated} =
        Device.set_status(device, %{
          status: :offline,
          reason: "Network connectivity lost"
        })

      assert updated.status == :offline
      assert updated.last_status_change != nil

      # Check status history in metadata
      assert updated.metadata["status_history"]
      history_entry = List.first(updated.metadata["status_history"])
      assert history_entry["status"] == :offline
      assert history_entry["reason"] == "Network connectivity lost"
    end

    test "performs device maintenance", %{tenant: tenant, site: site} do
      device =
        insert(:device,
          status: :online,
          tenant: tenant,
          site: site
        )

      {:ok, maintenance_device} =
        Device.start_maintenance(device, %{
          maintenance_type: "firmware_update",
          estimated_duration: 30
        })

      assert maintenance_device.status == :maintenance

      assert maintenance_device.metadata["maintenance_info"]["type"] ==
               "firmware_update"

      assert maintenance_device.metadata["maintenance_info"]["estimated_duration"] ==
               30

      {:ok, completed_device} =
        Device.complete_maintenance(maintenance_device, %{
          notes: "Firmware updated successfully"
        })

      assert completed_device.status == :online
      assert completed_device.metadata["maintenance_info"]["completed_at"]

      assert completed_device.metadata["maintenance_info"]["notes"] ==
               "Firmware updated successfully"
    end

    test "calculates device uptime", %{tenant: tenant, site: site} do
      device =
        insert(:device,
          status: :online,
          # 1 hour ago
          last_seen_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
          tenant: tenant,
          site: site
        )

      device_with_calc = Device.read!(device.id, load: [:uptime_hours])
      # Should be close to 1 hour
      assert device_with_calc.uptime_hours >= 0.9
      assert device_with_calc.uptime_hours <= 1.1
    end

    test "calculates health status", %{tenant: tenant, site: site} do
      # Healthy device
      healthy_device =
        insert(:device,
          status: :online,
          # 5 minutes ago
          last_seen_at: DateTime.utc_now() |> DateTime.add(-300, :second),
          tenant: tenant,
          site: site
        )

      healthy_with_calc = Device.read!(healthy_device.id, load: [:is_healthy?])
      assert healthy_with_calc.is_healthy? == true

      # Unhealthy device (offline for too long)
      unhealthy_device =
        insert(:device,
          status: :offline,
          # 2 hours ago
          last_seen_at: DateTime.utc_now() |> DateTime.add(-7200, :second),
          tenant: tenant,
          site: site
        )

      unhealthy_with_calc = Device.read!(unhealthy_device.id, load: [:is_healthy?])
      assert unhealthy_with_calc.is_healthy? == false
    end

    test "tracks firmware updates", %{tenant: tenant, site: site} do
      device =
        insert(:device,
          firmware_version: "1.0.0",
          tenant: tenant,
          site: site
        )

      {:ok, updated} =
        Device.update_firmware(device, %{
          firmware_version: "1.1.0",
          update_notes: "Security patches and bug fixes"
        })

      assert updated.firmware_version == "1.1.0"
      assert updated.metadata["firmware_history"]

      history_entry = List.first(updated.metadata["firmware_history"])
      assert history_entry["from_version"] == "1.0.0"
      assert history_entry["to_version"] == "1.1.0"
      assert history_entry["notes"] == "Security patches and bug fixes"
    end

    test "configures device settings", %{tenant: tenant, site: site} do
      device =
        insert(:device,
          device_type: "ip_camera",
          tenant: tenant,
          site: site
        )

      config = %{
        "resolution" => "1080p",
        "fps" => 25,
        "night_vision" => true,
        "motion_detection" => %{
          "enabled" => true,
          "sensitivity" => 75
        }
      }

      {:ok, configured} =
        Device.configure(device, %{
          configuration: config
        })

      assert configured.configuration["resolution"] == "1080p"
      assert configured.configuration["fps"] == 25
      assert configured.configuration["night_vision"] == true
      assert configured.configuration["motion_detection"]["sensitivity"] == 75
    end

    test "assigns device to zone", %{tenant: tenant, site: site} do
      zone = insert(:zone, tenant: tenant, site: site)
      device = insert(:device, tenant: tenant, site: site)

      {:ok, assigned} =
        Device.assign_to_zone(device, %{
          zone_id: zone.id
        })

      assert assigned.zone_id == zone.id

      # Verify assignment is logged
      assert assigned.metadata["zone_assignments"]
      assignment = List.first(assigned.metadata["zone_assignments"])
      assert assignment["zone_id"] == zone.id
      assert assignment["assigned_at"]
    end

    test "generates device reports", %{tenant: tenant, site: site} do
      device =
        insert(:device,
          status: :online,
          tenant: tenant,
          site: site
        )

      device_with_calc =
        Device.read!(device.id,
          load: [
            :is_healthy?,
            :uptime_hours,
            :days_since_maintenance,
            :firmware_age_days
          ]
        )

      assert is_boolean(device_with_calc.is_healthy?)
      assert is_number(device_with_calc.uptime_hours)
      assert is_integer(device_with_calc.days_since_maintenance)
      assert is_integer(device_with_calc.firmware_age_days)
    end

    test "enforces tenant isolation", %{site: site} do
      tenant1 = site.tenant
      tenant2 = insert(:tenant)
      site2 = insert(:site, tenant: tenant2)

      device1 = insert(:device, tenant: tenant1, site: site)
      device2 = insert(:device, tenant: tenant2, site: site2)

      # Query with tenant context
      tenant1_devices = Device.read!(tenant: tenant1)
      tenant2_devices = Device.read!(tenant: tenant2)

      assert length(tenant1_devices) == 1
      assert length(tenant2_devices) == 1
      assert Enum.any?(tenant1_devices, &(&1.id == device1.id))
      assert Enum.any?(tenant2_devices, &(&1.id == device2.id))
      refute Enum.any?(tenant1_devices, &(&1.id == device2.id))
      refute Enum.any!(tenant2_devices, &(&1.id == device1.id))
    end

    test "validates device type constraints", %{tenant: tenant, site: site} do
      # Test specific device type validations
      camera_attrs = %{
        name: "Test Camera",
        serial_number: "CAM - TEST - 001",
        device_type: "ip_camera",
        configuration: %{
          "resolution" => "4K",
          "fps" => 30
        },
        site_id: site.id,
        tenant_id: tenant.id
      }

      {:ok, camera} = Device.create(camera_attrs)
      assert camera.device_type == "ip_camera"

      # Sensor should have different valid configurations
      sensor_attrs = %{
        name: "Test Sensor",
        serial_number: "SENSOR - TEST - 001",
        device_type: "motion_sensor",
        configuration: %{
          "sensitivity" => 80,
          "range_meters" => 10
        },
        site_id: site.id,
        tenant_id: tenant.id
      }

      {:ok, sensor} = Device.create(sensor_attrs)
      assert sensor.device_type == "motion_sensor"
    end

    test "manages device alerts", %{tenant: tenant, site: site} do
      device = insert(:device, tenant: tenant, site: site)

      {:ok, device_with_alert} =
        Device.add_alert(device, %{
          alert_type: "low_battery",
          severity: "warning",
          message: "Battery level below 20%"
        })

      assert device_with_alert.metadata["active_alerts"]
      alert = List.first(device_with_alert.metadata["active_alerts"])
      assert alert["type"] == "low_battery"
      assert alert["severity"] == "warning"

      {:ok, device_cleared} =
        Device.clear_alert(device_with_alert, %{
          alert_type: "low_battery"
        })

      # Alert should be moved to resolved alerts
      assert device_cleared.metadata["resolved_alerts"]
      resolved = List.first(device_cleared.metadata["resolved_alerts"])
      assert resolved["type"] == "low_battery"
      assert resolved["resolved_at"]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
