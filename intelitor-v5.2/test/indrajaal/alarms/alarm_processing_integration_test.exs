defmodule Indrajaal.Alarms.AlarmProcessingIntegrationTest do
  use Indrajaal.DataCase

  alias Indrajaal.Alarms.ProcessingEngine
  alias Indrajaal.Alarms.Api
  alias Indrajaal.TenantsFixtures
  alias Indrajaal.SitesFixtures
  alias Indrajaal.DevicesFixtures

  describe "alarm processing integration" do
    setup do
      # Create test data
      tenant = TenantsFixtures.tenant_fixture()
      site = SitesFixtures.site_fixture(%{tenant_id: tenant.id})
      zone = SitesFixtures.zone_fixture(%{site_id: site.id})

      device =
        DevicesFixtures.device_fixture(%{
          site_id: site.id,
          zone_id: zone.id,
          tenant_id: tenant.id
        })

      # Start the processing engine
      {:ok, _pid} = ProcessingEngine.start_link([])

      %{tenant: tenant, site: site, zone: zone, device: device}
    end

    test "processes alarm from device event", %{device: device, tenant: tenant} do
      # Create a device event
      device_event = %{
        tenant_id: tenant.id,
        source_device_id: device.id,
        event_type: :intrusion,
        location_id: device.site_id,
        raw_data: %{
          signal: "motion_detected",
          zone: "01"
        }
      }

      # Process the alarm
      assert {:ok, alarm} = ProcessingEngine.process_alarm(device_event)

      # Verify alarm was created with correct attributes
      assert alarm.tenant_id == tenant.id
      assert alarm.device_id == device.id
      assert alarm.event_type == :intrusion
      assert alarm.state == :triggered
      assert alarm.severity in [:high, :critical]
      assert alarm.priority >= 7

      # Verify severity factors were calculated
      assert Map.has_key?(alarm.severity_factors, :factors)
      assert length(alarm.severity_factors.factors) == 6

      # Verify alarm can be retrieved via API
      assert {:ok, fetched_alarm} =
               Api.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})

      assert fetched_alarm.id == alarm.id
    end

    test "handles SIA DC-09 protocol events", %{tenant: tenant} do
      # Simulate SIA DC-09 binary data
      sia_data = <<0x10, 0x01, 0x42, 0x41, 0x30, 0x31, 0x30, 0x30, 0x31>>

      # Process SIA event
      assert {:ok, alarm} = ProcessingEngine.handle_sia_event(sia_data)

      # Verify alarm was created from SIA data
      assert alarm.event_type == :intrusion
      assert alarm.metadata["protocol"] == "SIA-DC09"
    end

    test "handles API-based alarm events", %{device: device, tenant: tenant} do
      # Create API event params
      api_params = %{
        device_id: device.id,
        event_type: :fire,
        event_code: "FA001",
        severity: :critical,
        description: "Smoke detected in server room",
        metadata: %{
          sensor_type: "photoelectric",
          smoke_level: 85
        }
      }

      # Process API event
      assert {:ok, alarm} = ProcessingEngine.handle_api_event(api_params, tenant.id)

      # Verify alarm attributes
      assert alarm.event_type == :fire
      assert alarm.severity == :critical
      assert alarm.priority == 10
      assert alarm.description == "Smoke detected in server room"
      assert alarm.metadata["api_version"] == "v1"
    end

    test "alarm state transitions work correctly", %{device: device, tenant: tenant} do
      # Create an alarm
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            tenant_id: tenant.id,
            device_id: device.id,
            site_id: device.site_id,
            event_type: :intrusion,
            event_code: "INT001",
            description: "Motion detected"
          },
          actor: %{tenant_id: tenant.id}
        )

      assert alarm.state == :triggered

      # Acknowledge the alarm
      user_id = Ecto.UUID.generate()

      {:ok, acknowledged} =
        Api.acknowledge_alarm(alarm.id, user_id, actor: %{tenant_id: tenant.id})

      assert acknowledged.state == :acknowledged
      assert acknowledged.acknowledged_by == user_id
      assert acknowledged.acknowledged_at != nil
      assert acknowledged.response_time_seconds > 0

      # Begin investigation
      {:ok, investigating} =
        Api.begin_investigation(alarm.id, user_id, actor: %{tenant_id: tenant.id})

      assert investigating.state == :investigating
      assert investigating.investigating_by == user_id
      assert investigating.investigating_at != nil

      # Resolve the alarm
      {:ok, resolved} =
        Api.resolve_alarm(
          alarm.id,
          user_id,
          "False alarm - testing sensors",
          actor: %{tenant_id: tenant.id}
        )

      assert resolved.state == :resolved
      assert resolved.resolved_by == user_id
      assert resolved.resolved_at != nil
      assert resolved.resolution_notes == "False alarm - testing sensors"
      assert resolved.resolution_time_seconds > 0
    end

    test "correlation updates work correctly", %{device: device, tenant: tenant} do
      # Create multiple alarms
      {:ok, alarm1} = create_test_alarm(device, tenant)
      {:ok, alarm2} = create_test_alarm(device, tenant)
      {:ok, alarm3} = create_test_alarm(device, tenant)

      # Create correlation group
      group_id = Ecto.UUID.generate()

      # Update correlation for all alarms
      {:ok, updated1} =
        Api.update_alarm_correlation(
          alarm1,
          %{
            correlation_group_id: group_id,
            correlated_events: [alarm2.id, alarm3.id],
            correlation_data: %{
              pattern: "perimeter_probe",
              confidence: 0.85
            }
          },
          actor: %{tenant_id: tenant.id}
        )

      assert updated1.correlation_group_id == group_id
      assert length(updated1.correlated_events) == 2
      assert updated1.correlation_data["pattern"] == "perimeter_probe"
    end

    test "active alarms query works correctly", %{device: device, tenant: tenant} do
      # Create mix of alarm states
      {:ok, active1} = create_test_alarm(device, tenant)
      {:ok, active2} = create_test_alarm(device, tenant)
      {:ok, resolved} = create_test_alarm(device, tenant)

      # Resolve one alarm
      Api.resolve_alarm(resolved.id, Ecto.UUID.generate(), "Test", actor: %{tenant_id: tenant.id})

      # Query active alarms
      {:ok, active_alarms} = Api.get_active_alarms(actor: %{tenant_id: tenant.id})

      # Should only return non-resolved alarms
      assert length(active_alarms) == 2

      assert Enum.all?(
               active_alarms,
               &(&1.state in [:triggered, :acknowledged, :investigating])
             )
    end

    test "alarm statistics calculation", %{device: device, tenant: tenant} do
      # Create various alarms
      {:ok, critical} = create_test_alarm(device, tenant, %{severity: :critical})
      {:ok, high} = create_test_alarm(device, tenant, %{severity: :high})
      {:ok, medium} = create_test_alarm(device, tenant, %{severity: :medium})
      {:ok, false_alarm} = create_test_alarm(device, tenant)

      # Mark one as false alarm
      Api.mark_false_alarm(
        false_alarm.id,
        Ecto.UUID.generate(),
        "Testing",
        actor: %{tenant_id: tenant.id}
      )

      # Get statistics
      {:ok, stats} =
        Api.get_alarm_statistics(
          %{site_id: device.site_id},
          actor: %{tenant_id: tenant.id}
        )

      assert stats.total_alarms == 4
      assert stats.by_severity[:critical] == 1
      assert stats.by_severity[:high] == 1
      assert stats.by_severity[:medium] == 1
      assert stats.by_state[:false_alarm] == 1
      assert stats.false_alarm_rate == 25.0
    end
  end

  # Helper function to create test alarms
  defp create_test_alarm(device, tenant, attrs \\ %{}) do
    default_attrs = %{
      tenant_id: tenant.id,
      device_id: device.id,
      site_id: device.site_id,
      event_type: :intrusion,
      event_code: "TEST#{:rand.uniform(9999)}",
      description: "Test alarm",
      severity: :high
    }

    Api.create_alarm_event(
      Map.merge(default_attrs, attrs),
      actor: %{tenant_id: tenant.id}
    )
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
