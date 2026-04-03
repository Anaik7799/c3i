defmodule Intelitor.DeviceManagementTest do
  use Intelitor.WallabyCase

  @moduletag :wallaby
  @moduletag :e2e

  describe "Device Management Workflows" do
    setup do
      # Setup test tenant and user
      tenant = insert(:tenant, name: "Test Security Corp")

      admin_user =
        insert(:user,
          tenant: tenant,
          email: "admin@testsecurity.com",
          role: "admin"
        )

      # Setup site structure
      site = insert(:site, tenant: tenant, name: "Main Headquarters")
      building = insert(:building, site: site, tenant: tenant, name: "Building A")
      floor = insert(:floor, building: building, tenant: tenant, name: "Ground Floor")
      location = insert(:location, floor: floor, tenant: tenant, name: "Security Office")

      # Setup device types
      camera_type = insert(:device_type, tenant: tenant, type_name: "IP Camera")
      sensor_type = insert(:device_type, tenant: tenant, type_name: "Motion Sensor")

      %{
        tenant: tenant,
        user: admin_user,
        site: site,
        location: location,
        camera_type: camera_type,
        sensor_type: sensor_type
      }
    end

    test "Admin can create a new security device", %{session: session} = __context do
      session
      |> login_as(context.user)
      |> visit("/devices")
      |> assert_has(page_title("Device Management"))
      |> click(button("New Device"))
      |> assert_has(page_title("Create Device"))
      |> fill_in(text_field("Name"), with: "Camera-001")
      |> fill_in(text_field("Serial Number"), with: "CAM-2024-001")
      |> fill_in(text_field("Model"), with: "Hikvision DS-2CD2385G1-I")
      |> select(context.camera_type.type_name, from: "Device Type")
      |> select(context.location.name, from: "Location")
      |> fill_in(text_field("IP Address"), with: "192.168.1.100")
      |> fill_in(text_field("Port"), with: "80")
      |> select("Active", from: select("Status"))
      |> click(button("Create Device"))
      |> assert_has(css("[data-test='device-created']"))
      |> assert_has(Wallaby.Query.text("Device Camera-001 created successfully"))
      |> assert_has(Wallaby.Query.text("CAM-2024-001"))
    end

    test "Admin can view device list with filtering", %{session: session} = __context do
      # Create test devices
      camera1 =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-001",
          device_type: context.camera_type,
          location: context.location,
          status: :active
        )

      camera2 =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-002",
          device_type: context.camera_type,
          location: context.location,
          status: :maintenance
        )

      sensor1 =
        insert(:device,
          tenant: context.tenant,
          name: "Sensor-001",
          device_type: context.sensor_type,
          location: context.location,
          status: :active
        )

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> assert_has(page_title("Device Management"))
      |> assert_has(Wallaby.Query.text("Camera-001"))
      |> assert_has(Wallaby.Query.text("Camera-002"))
      |> assert_has(Wallaby.Query.text("Sensor-001"))
      |> assert_has(css("[data-test='device-count']", text: "3"))

      # Filter by device type
      |> select(context.camera_type.type_name, from: "Filter by Type")
      |> click(button("Apply Filter"))
      |> assert_has(Wallaby.Query.text("Camera-001"))
      |> assert_has(Wallaby.Query.text("Camera-002"))
      |> refute_has(Wallaby.Query.text("Sensor-001"))
      |> assert_has(css("[data-test='device-count']", text: "2"))

      # Filter by status
      |> select("All Types", from: "Filter by Type")
      |> select("Active", from: "Filter by Status")
      |> click(button("Apply Filter"))
      |> assert_has(Wallaby.Query.text("Camera-001"))
      |> assert_has(Wallaby.Query.text("Sensor-001"))
      |> refute_has(Wallaby.Query.text("Camera-002"))
      |> assert_has(css("[data-test='device-count']", text: "2"))
    end

    test "Admin can edit device configuration", %{session: session} = __context do
      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-001",
          device_type: context.camera_type,
          location: context.location,
          ip_address: "192.168.1.100",
          status: :active
        )

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> click(css("[data-test='device-#{device.id}'] [data-test='edit-button']"))
      |> assert_has(page_title("Edit Device"))
      |> assert_has(text_field("Name", with: "Camera-001"))
      |> fill_in(text_field("Name"), with: "Camera-001-Updated")
      |> fill_in(text_field("IP Address"), with: "192.168.1.101")
      |> select("Maintenance", from: "Status")
      |> fill_in(textarea("Notes"), with: "Updated IP address for network reorganization")
      |> click(button("Update Device"))
      |> assert_has(css("[data-test='device-updated']"))
      |> assert_has(Wallaby.Query.text("Device updated successfully"))
      |> assert_has(Wallaby.Query.text("Camera-001-Updated"))
      |> assert_has(Wallaby.Query.text("192.168.1.101"))
      |> assert_has(css("[data-test='status']", text: "Maintenance"))
    end

    test "Admin can delete device with confirmation", %{session: session} = __context do
      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-Old",
          device_type: context.camera_type,
          location: context.location,
          status: :inactive
        )

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> assert_has(Wallaby.Query.text("Camera-Old"))
      |> click(css("[data-test='device-#{device.id}'] [data-test='delete-button']"))
      |> assert_has(css("[data-test='delete-confirmation']"))
      |> assert_has(Wallaby.Query.text("Are you sure you want to delete Camera-Old?"))
      |> click(button("Cancel"))
      # Still there
      |> assert_has(Wallaby.Query.text("Camera-Old"))
      |> click(css("[data-test='device-#{device.id}'] [data-test='delete-button']"))
      |> click(button("Delete Device"))
      |> assert_has(css("[data-test='device-deleted']"))
      |> assert_has(Wallaby.Query.text("Device deleted successfully"))
      |> refute_has(Wallaby.Query.text("Camera-Old"))
    end

    test "Admin can view device details and health status", %{session: session} = __context do
      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-Main",
          device_type: context.camera_type,
          location: context.location,
          serial_number: "CAM-2024-MAIN",
          model: "Hikvision DS-2CD2385G1-I",
          ip_address: "192.168.1.50",
          port: 80,
          status: :active,
          last_seen: DateTime.utc_now(),
          firmware_version: "V5.7.3",
          installation_date: ~D[2024-01-15]
        )

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> click(css("[data-test='device-#{device.id}'] [data-test='view-button']"))
      |> assert_has(page_title("Device Details"))
      |> assert_has(Wallaby.Query.text("Camera-Main"))
      |> assert_has(Wallaby.Query.text("CAM-2024-MAIN"))
      |> assert_has(Wallaby.Query.text("Hikvision DS-2CD2385G1-I"))
      |> assert_has(Wallaby.Query.text("192.168.1.50:80"))
      |> assert_has(Wallaby.Query.text("V5.7.3"))
      |> assert_has(css("[data-test='status-indicator']", text: "Active"))
      |> assert_has(css("[data-test='health-status']", text: "Online"))
      # Location
      |> assert_has(Wallaby.Query.text("Security Office"))
      # Installation date
      |> assert_has(Wallaby.Query.text("2024-01-15"))
    end

    test "Admin can perform bulk device operations", %{session: session} = __context do
      # Create multiple devices
      devices = [
        insert(:device,
          tenant: context.tenant,
          name: "Camera-001",
          device_type: context.camera_type,
          status: :active
        ),
        insert(:device,
          tenant: context.tenant,
          name: "Camera-002",
          device_type: context.camera_type,
          status: :active
        ),
        insert(:device,
          tenant: context.tenant,
          name: "Sensor-001",
          device_type: context.sensor_type,
          status: :active
        )
      ]

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> assert_has(Wallaby.Query.text("Camera-001"))
      |> assert_has(Wallaby.Query.text("Camera-002"))
      |> assert_has(Wallaby.Query.text("Sensor-001"))

      # Select multiple devices
      |> click(css("[data-test='device-#{Enum.at(devices, 0).id}'] input[type='checkbox']"))
      |> click(css("[data-test='device-#{Enum.at(devices, 1).id}'] input[type='checkbox']"))
      |> assert_has(css("[data-test='selected-count']", text: "2 selected"))

      # Bulk status change
      |> click(button("Bulk Actions"))
      |> click(link("Change Status"))
      |> select("Maintenance", from: "New Status")
      |> fill_in(textarea("Reason"), with: "Scheduled maintenance window")
      |> click(button("Update Selected Devices"))
      |> assert_has(css("[data-test='bulk-update-success']"))
      |> assert_has(Wallaby.Query.text("2 devices updated successfully"))

      # Verify status changes
      |> assert_has(
        css("[data-test='device-#{Enum.at(devices, 0).id}'] [data-test='status']",
          text: "Maintenance"
        )
      )
      |> assert_has(
        css("[data-test='device-#{Enum.at(devices, 1).id}'] [data-test='status']",
          text: "Maintenance"
        )
      )
      # Unchanged
      |> assert_has(
        css("[data-test='device-#{Enum.at(devices, 2).id}'] [data-test='status']",
          text: "Active"
        )
      )
    end

    test "Admin can configure device network settings", %{session: session} = __context do
      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-Network",
          device_type: context.camera_type,
          location: context.location,
          ip_address: "192.168.1.200"
        )

      session
      |> login_as(context.user)
      |> visit("/devices/#{device.id}/edit")
      |> click(tab("Network Settings"))
      |> assert_has(text_field("IP Address", with: "192.168.1.200"))
      |> fill_in(text_field("IP Address"), with: "10.0.1.50")
      |> fill_in(text_field("Port"), with: "8080")
      |> fill_in(text_field("Gateway"), with: "10.0.1.1")
      |> fill_in(text_field("Subnet Mask"), with: "255.255.255.0")
      |> fill_in(text_field("DNS Primary"), with: "8.8.8.8")
      |> fill_in(text_field("DNS Secondary"), with: "8.8.4.4")
      |> click(button("Test Connection"))
      |> assert_has(css("[data-test='connection-test']", text: "Testing..."))
      |> assert_has(css("[data-test='connection-success']", text: "Connection successful"))
      |> click(button("Save Network Settings"))
      |> assert_has(css("[data-test='network-updated']"))
      |> assert_has(Wallaby.Query.text("Network settings updated successfully"))
    end

    test "Admin can view device audit trail", %{session: session} = __context do
      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-Audit",
          device_type: context.camera_type,
          location: context.location
        )

      # Create some audit log entries
      audit_entries = [
        insert(:audit_log,
          tenant: context.tenant,
          resource_type: "Device",
          resource_id: device.id,
          action: "created",
          __user_id: context.user.id,
          timestamp: DateTime.add(DateTime.utc_now(), -3600)
        ),
        insert(:audit_log,
          tenant: context.tenant,
          resource_type: "Device",
          resource_id: device.id,
          action: "status_changed",
          __user_id: context.user.id,
          timestamp: DateTime.add(DateTime.utc_now(), -1800)
        ),
        insert(:audit_log,
          tenant: context.tenant,
          resource_type: "Device",
          resource_id: device.id,
          action: "configuration_updated",
          __user_id: context.user.id,
          timestamp: DateTime.utc_now()
        )
      ]

      session
      |> login_as(context.user)
      |> visit("/devices/#{device.id}")
      |> click(tab("Audit Trail"))
      |> assert_has(Wallaby.Query.text("Device Activity History"))
      |> assert_has(Wallaby.Query.text("created"))
      |> assert_has(Wallaby.Query.text("status_changed"))
      |> assert_has(Wallaby.Query.text("configuration_updated"))
      |> assert_has(Wallaby.Query.text(context.user.email))

      # Filter audit trail
      |> select("configuration_updated", from: "Filter by Action")
      |> click(button("Apply Filter"))
      |> assert_has(Wallaby.Query.text("configuration_updated"))
      |> refute_has(Wallaby.Query.text("created"))
      |> refute_has(Wallaby.Query.text("status_changed"))
    end

    test "Admin receives real-time device status updates", %{session: session} = __context do
      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-Realtime",
          device_type: context.camera_type,
          location: context.location,
          status: :active,
          last_seen: DateTime.utc_now()
        )

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> assert_has(css("[data-test='device-#{device.id}'] [data-test='status']", text: "Active"))
      |> assert_has(css("[data-test='device-#{device.id}'] [data-test='health']", text: "Online"))

      # Simulate device going offline (this would typically come from a WebSocket update)
      |> execute_script(
        "window.dispatchEvent(new CustomEvent('device-status-change', { detail: { deviceId: '#{device.id}', status: 'offline', lastSeen: '#{DateTime.add(DateTime.utc_now(), -300)}' } }))"
      )
      |> assert_has(
        css("[data-test='device-#{device.id}'] [data-test='health']", text: "Offline")
      )
      |> assert_has(css("[data-test='device-#{device.id}'] [data-test='offline-indicator']"))

      # Simulate device coming back online
      |> execute_script(
        "window.dispatchEvent(new CustomEvent('device-status-change', { detail: { deviceId: '#{device.id}', status: 'online', lastSeen: '#{DateTime.utc_now()}' } }))"
      )
      |> assert_has(css("[data-test='device-#{device.id}'] [data-test='health']", text: "Online"))
      |> refute_has(css("[data-test='device-#{device.id}'] [data-test='offline-indicator']"))
    end

    test "Admin can export device inventory report", %{session: session} = __context do
      # Create devices for export
      devices =
        create_list(5, :device,
          tenant: context.tenant,
          device_type: context.camera_type,
          location: context.location
        )

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> click(button("Export"))
      |> assert_has(css("[data-test='export-options']"))
      |> click(checkbox("Include Device Details"))
      |> click(checkbox("Include Network Configuration"))
      |> click(checkbox("Include Maintenance History"))
      |> select("CSV", from: "Export Format")
      |> click(button("Generate Report"))
      |> assert_has(css("[data-test='export-progress']"))
      |> assert_has(css("[data-test='export-complete']"))
      |> click(link("Download Report"))

      # Verify download initiated (actual file download verification would need additional setup)
      |> assert_has(css("[data-test='download-started']"))
    end

    test "Operator can view devices but cannot modify", %{session: session} = __context do
      operator_user =
        insert(:user,
          tenant: context.tenant,
          email: "operator@testsecurity.com",
          role: "operator"
        )

      device =
        insert(:device,
          tenant: context.tenant,
          name: "Camera-ReadOnly",
          device_type: context.camera_type,
          location: context.location
        )

      session
      |> login_as(operator_user)
      |> visit("/devices")
      |> assert_has(Wallaby.Query.text("Camera-ReadOnly"))
      # Should not see create button
      |> refute_has(button("New Device"))
      # Should not see edit button
      |> refute_has(css("[data-test='device-#{device.id}'] [data-test='edit-button']"))
      # Should not see delete button
      |> refute_has(css("[data-test='device-#{device.id}'] [data-test='delete-button']"))
      |> click(css("[data-test='device-#{device.id}'] [data-test='view-button']"))
      |> assert_has(page_title("Device Details"))
      |> assert_has(Wallaby.Query.text("Camera-ReadOnly"))
      # Should not see edit option in details
      |> refute_has(button("Edit Device"))
    end

    test "Device search functionality works correctly", %{session: session} = __context do
      # Create devices with searchable content
      devices = [
        insert(:device,
          tenant: context.tenant,
          name: "Front-Door-Camera",
          serial_number: "FDC-001"
        ),
        insert(:device,
          tenant: context.tenant,
          name: "Back-Door-Sensor",
          serial_number: "BDS-002"
        ),
        insert(:device, tenant: context.tenant, name: "Lobby-Camera", serial_number: "LC-003"),
        insert(:device, tenant: context.tenant, name: "Parking-Sensor", serial_number: "PS-004")
      ]

      session
      |> login_as(context.user)
      |> visit("/devices")
      |> assert_has(Wallaby.Query.text("Front-Door-Camera"))
      |> assert_has(Wallaby.Query.text("Back-Door-Sensor"))
      |> assert_has(Wallaby.Query.text("Lobby-Camera"))
      |> assert_has(Wallaby.Query.text("Parking-Sensor"))

      # Search by name
      |> fill_in(text_field("Search"), with: "Camera")
      |> click(button("Search"))
      |> assert_has(Wallaby.Query.text("Front-Door-Camera"))
      |> assert_has(Wallaby.Query.text("Lobby-Camera"))
      |> refute_has(Wallaby.Query.text("Back-Door-Sensor"))
      |> refute_has(Wallaby.Query.text("Parking-Sensor"))

      # Search by serial number
      |> fill_in(text_field("Search"), with: "BDS-002")
      |> click(button("Search"))
      |> assert_has(Wallaby.Query.text("Back-Door-Sensor"))
      |> refute_has(Wallaby.Query.text("Front-Door-Camera"))
      |> refute_has(Wallaby.Query.text("Lobby-Camera"))
      |> refute_has(Wallaby.Query.text("Parking-Sensor"))

      # Clear search
      |> click(button("Clear Search"))
      |> assert_has(Wallaby.Query.text("Front-Door-Camera"))
      |> assert_has(Wallaby.Query.text("Back-Door-Sensor"))
      |> assert_has(Wallaby.Query.text("Lobby-Camera"))
      |> assert_has(Wallaby.Query.text("Parking-Sensor"))
    end
  end

  # Use centralized authentication from WallabyCase
  defp login_as(session, user) do
    authenticate_user(session, user)
  end

  defp page_title(title) do
    css("h1", text: title)
  end

  defp text_field(label) do
    css(
      "input[aria-label='#{label}'], input[placeholder*='#{label}'], label:contains('#{label}') + input"
    )
  end

  defp text_field(label, opts) do
    value = Keyword.get(opts, :with)

    css(
      "input[aria-label='#{label}'][value='#{value}'], input[placeholder*='#{label}'][value='#{value}'], label:contains('#{label}') + input[value='#{value}']"
    )
  end

  defp textarea(label) do
    css(
      "textarea[aria-label='#{label}'], textarea[placeholder*='#{label}'], label:contains('#{label}') + textarea"
    )
  end

  defp button(text) do
    css("button:contains('#{text}'), input[type='submit'][value='#{text}']")
  end

  defp link(text) do
    css("a:contains('#{text}')")
  end

  defp tab(text) do
    css("[role='tab']:contains('#{text}'), .tab:contains('#{text}')")
  end

  defp checkbox(label) do
    css(
      "input[type='checkbox'][aria-label='#{label}'], label:contains('#{label}') input[type='checkbox']"
    )
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
