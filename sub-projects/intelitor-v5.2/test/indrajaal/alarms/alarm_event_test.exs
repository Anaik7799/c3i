defmodule Indrajaal.Alarms.AlarmEventTest do
  use Indrajaal.DataCase

  alias Indrajaal.Alarms.AlarmEvent
  alias Indrajaal.AshFactory
  alias Indrajaal.Core.{Tenant, Organization}
  alias Indrajaal.Devices.{Device, DeviceType}
  alias Indrajaal.Sites.Site

  describe "AlarmEvent resource" do
    setup do
      tenant = AshFactory.insert(:tenant)

      organization = AshFactory.insert(:organization, %{tenant_id: tenant.id})

      site =
        AshFactory.insert(:site, %{
          tenant_id: tenant.id,
          organization_id: organization.id
        })

      # Create a device type first
      device_type =
        DeviceType
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Camera",
          category: :camera,
          manufacturer: "Test Corp",
          model: "TC - 100",
          tenant_id: tenant.id
        })
        |> Ash.create!(actor: %{is_system: true}, authorize?: false)

      device =
        AshFactory.insert(:device, %{
          tenant_id: tenant.id,
          site_id: site.id,
          device_type_id: device_type.id
        })

      {:ok,
       tenant: tenant,
       organization: organization,
       site: site,
       device: device,
       device_type: device_type}
    end

    test "creates an alarm eventwith valid attributes", %{
      tenant: tenant,
      site: site,
      device: device
    } do
      attrs = %{
        event_type: "motion_detected",
        severity: :medium,
        source_type: :device,
        source_id: device.id,
        description: "Motion detected in restricted area",
        location_data: %{
          "site_id" => site.id,
          "device_id" => device.id,
          "coordinates" => %{"x" => 100, "y" => 200}
        },
        event_data: %{
          "motion_strength" => 85,
          "detection_zone" => "zone_1",
          "timestamp" => DateTime.utc_now()
        },
        tenant_id: tenant.id
      }

      {:ok, alarm} = AshFactory.insert(:alarm_event, attrs)

      assert alarm.event_type == "motion_detected"
      assert alarm.severity == :medium
      assert alarm.source_type == :device
      assert alarm.source_id == device.id
      assert alarm.description == "Motion detected in restricted area"
      assert alarm.status == :new
      assert alarm.location_data["site_id"] == site.id
      assert alarm.event_data["motion_strength"] == 85
      assert alarm.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = AlarmEvent.create(%{tenant_id: tenant.id})

      assert changeset.errors[:event_type]
      assert changeset.errors[:severity]
      assert changeset.errors[:source_type]
      assert changeset.errors[:description]
    end

    test "automatically assigns priority based on severity",
         %{tenant: tenant, device: device} do
      # Critical severity should get high priority
      {:ok, critical_alarm} =
        AlarmEvent.create(%{
          event_type: "security_breach",
          severity: :critical,
          source_type: :device,
          source_id: device.id,
          description: "Security breach detected",
          tenant_id: tenant.id
        })

      assert critical_alarm.priority == :high

      # Low severity should get low priority
      {:ok, low_alarm} =
        AlarmEvent.create(%{
          event_type: "sensor_check",
          severity: :low,
          source_type: :device,
          source_id: device.id,
          description: "Routine sensor check",
          tenant_id: tenant.id
        })

      assert low_alarm.priority == :low
    end

    test "acknowledges alarm with user tracking",
         %{tenant: tenant, device: device} do
      user = insert(:user, tenant: tenant)

      alarm =
        insert(:alarm_event,
          status: :new,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      {:ok, acknowledged} =
        AlarmEvent.acknowledge(alarm, %{
          acknowledged_by: user.id,
          notes: "Investigating motion detection"
        })

      assert acknowledged.status == :acknowledged
      assert acknowledged.acknowledged_by == user.id
      assert acknowledged.acknowledged_at != nil
      assert acknowledged.notes == "Investigating motion detection"
    end

    test "escalates alarm through severity levels",
         %{tenant: tenant, device: device} do
      alarm =
        insert(:alarm_event,
          severity: :low,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      {:ok, escalated} =
        AlarmEvent.escalate(alarm, %{
          severity: :high,
          escalation_reason: "No response within SLA timeframe"
        })

      assert escalated.severity == :high
      assert escalated.priority == :high
      assert escalated.metadata["escalation_history"]

      escalation = List.first(escalated.metadata["escalation_history"])
      assert escalation["from_severity"] == "low"
      assert escalation["to_severity"] == "high"
      assert escalation["reason"] == "No response within SLA timeframe"
    end

    test "resolves alarm with resolution tracking",
         %{tenant: tenant, device: device} do
      user = insert(:user, tenant: tenant)

      alarm =
        insert(:alarm_event,
          status: :acknowledged,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      {:ok, resolved} =
        AlarmEvent.resolve(alarm, %{
          resolved_by: user.id,
          resolution: "False alarm - cleaning staff movement",
          resolution_time: DateTime.utc_now()
        })

      assert resolved.status == :resolved
      assert resolved.resolved_by == user.id
      assert resolved.resolved_at != nil
      assert resolved.resolution == "False alarm - cleaning staff movement"
    end

    test "calculates response time", %{tenant: tenant, device: device} do
      # Create alarm 30 minutes ago
      created_time =
        DateTime.utc_now()
        |> DateTime.add(-1800, :second)

      alarm =
        insert(:alarm_event,
          status: :new,
          inserted_at: created_time,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      # Acknowledge now
      user = insert(:user, tenant: tenant)

      {:ok, acknowledged} =
        AlarmEvent.acknowledge(alarm, %{
          acknowledged_by: user.id
        })

      alarm_with_calc = AlarmEvent.read!(acknowledged.id, load: [:response_time_minutes])
      assert alarm_with_calc.response_time_minutes >= 29
      # Allow some tolerance
      assert alarm_with_calc.response_time_minutes <= 31
    end

    test "calculates SLA compliance", %{tenant: tenant, device: device} do
      # Alarm responded to quickly (within SLA)
      ack_time =
        DateTime.utc_now()
        |> DateTime.add(-300, :second)

      insert_time =
        DateTime.utc_now()
        |> DateTime.add(-600, :second)

      quick_alarm =
        insert(:alarm_event,
          severity: :medium,
          status: :acknowledged,
          # 5 minutes ago
          acknowledged_at: ack_time,
          # 10 minutes ago
          inserted_at: insert_time,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      quick_with_calc = AlarmEvent.read!(quick_alarm.id, load: [:is_within_sla?])
      assert quick_with_calc.is_within_sla? == true

      # Alarm that took too long to respond
      slow_ack_time =
        DateTime.utc_now()
        |> DateTime.add(-300, :second)

      slow_insert_time =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)

      slow_alarm =
        insert(:alarm_event,
          severity: :critical,
          status: :acknowledged,
          # 5 minutes ago
          acknowledged_at: slow_ack_time,
          # 1 hour ago
          inserted_at: slow_insert_time,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      slow_with_calc = AlarmEvent.read!(slow_alarm.id, load: [:is_within_sla?])
      assert slow_with_calc.is_within_sla? == false
    end

    test "filters alarms by severity and status",
         %{tenant: tenant, device: device} do
      # Create alarms with different severities
      insert(:alarm_event,
        severity: :low,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      insert(:alarm_event,
        severity: :medium,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      insert(:alarm_event,
        severity: :high,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      insert(:alarm_event,
        severity: :critical,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      # Filter by high severity and above
      high_severity_alarms =
        AlarmEvent.read!(
          tenant: tenant,
          filter: [severity: [:high, :critical]]
        )

      assert length(high_severity_alarms) == 2
      assert Enum.all?(high_severity_alarms, &(&1.severity in [:high, :critical]))

      # Filter by new status
      new_alarms =
        AlarmEvent.read!(
          tenant: tenant,
          filter: [status: :new]
        )

      # All alarms start as :new
      assert length(new_alarms) == 4
      assert Enum.all?(new_alarms, &(&1.status == :new))
    end

    test "tracks alarm correlation", %{tenant: tenant, device: device} do
      parent_alarm =
        insert(:alarm_event,
          event_type: "door_breach",
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      # Create related alarm
      {:ok, related_alarm} =
        AlarmEvent.create(%{
          event_type: "motion_detected",
          severity: :medium,
          source_type: :device,
          source_id: device.id,
          description: "Motion detected after door breach",
          parent_alarm_id: parent_alarm.id,
          tenant_id: tenant.id
        })

      assert related_alarm.parent_alarm_id == parent_alarm.id

      # Load parent with children
      parent_with_children = AlarmEvent.read!(parent_alarm.id, load: [:child_alarms])
      assert length(parent_with_children.child_alarms) == 1
      assert Enum.any?(parent_with_children.child_alarms, &(&1.id == related_alarm.id))
    end

    test "manages alarm suppression", %{tenant: tenant, device: device} do
      alarm =
        insert(:alarm_event,
          status: :new,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      suppressed_until =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)

      {:ok, suppressed} =
        AlarmEvent.suppress(alarm, %{
          suppression_reason: "Scheduled maintenance window",
          # 1 hour
          suppressed_until: suppressed_until
        })

      assert suppressed.status == :suppressed
      assert suppressed.metadata["suppression_reason"] == "Scheduled maintenance
        window"
      assert suppressed.metadata["suppressed_until"]

      # Test automatic unsuppression
      {:ok, unsuppressed} = AlarmEvent.unsuppress(suppressed)
      assert unsuppressed.status == :new
    end

    test "validates event data based on event type",
         %{tenant: tenant, device: device} do
      # Motion detection should have specific data
      motion_attrs = %{
        event_type: "motion_detected",
        severity: :medium,
        source_type: :device,
        source_id: device.id,
        description: "Motion detected",
        event_data: %{
          "motion_strength" => 75,
          "detection_zone" => "zone_1"
        },
        tenant_id: tenant.id
      }

      {:ok, motion_alarm} = AlarmEvent.create(motion_attrs)
      assert motion_alarm.event_data["motion_strength"] == 75

      # Door access should have different data structure
      door_attrs = %{
        event_type: "door_access",
        severity: :low,
        source_type: :device,
        source_id: device.id,
        description: "Door access granted",
        event_data: %{
          "card_id" => "12_345",
          "access_granted" => true,
          "user_id" => "user_123"
        },
        tenant_id: tenant.id
      }

      {:ok, door_alarm} = AlarmEvent.create(door_attrs)
      assert door_alarm.event_data["card_id"] == "12_345"
      assert door_alarm.event_data["access_granted"] == true
    end

    test "enforces tenant isolation", %{device: device} do
      tenant1 = device.tenant
      tenant2 = insert(:tenant)
      site2 = insert(:site, tenant: tenant2)
      device2 = insert(:device, tenant: tenant2, site: site2)

      alarm1 = insert(:alarm_event, tenant: tenant1, source_type: :device, source_id: device.id)

      alarm2 =
        insert(:alarm_event, tenant: tenant2, source_type: :device, source_id: device2.id)

      tenant1_alarms = AlarmEvent.read!(tenant: tenant1)
      tenant2_alarms = AlarmEvent.read!(tenant: tenant2)

      assert length(tenant1_alarms) == 1
      assert length(tenant2_alarms) == 1
      assert Enum.any?(tenant1_alarms, &(&1.id == alarm1.id))
      assert Enum.any?(tenant2_alarms, &(&1.id == alarm2.id))
      refute Enum.any?(tenant1_alarms, &(&1.id == alarm2.id))
      refute Enum.any!(tenant2_alarms, &(&1.id == alarm1.id))
    end

    test "creates alarm from device trigger",
         %{tenant: tenant, site: site, device: device} do
      # Test creating alarm from device event
      trigger_data = %{
        device_id: device.id,
        trigger_type: "motion",
        sensor_value: 85,
        threshold: 70,
        location: %{
          "zone" => "perimeter",
          "sector" => "north"
        }
      }

      {:ok, alarm} =
        AlarmEvent.create_from_device_trigger(%{
          device_id: device.id,
          trigger_data: trigger_data,
          tenant_id: tenant.id
        })

      assert alarm.source_type == :device
      assert alarm.source_id == device.id
      assert alarm.event_type == "device_trigger"
      assert alarm.event_data["trigger_type"] == "motion"
      assert alarm.event_data["sensor_value"] == 85
    end

    test "calculates alarm statistics", %{tenant: tenant, device: device} do
      # Create various alarms
      insert(:alarm_event,
        severity: :low,
        status: :resolved,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      insert(:alarm_event,
        severity: :medium,
        status: :acknowledged,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      insert(:alarm_event,
        severity: :high,
        status: :new,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      insert(:alarm_event,
        severity: :critical,
        status: :new,
        tenant: tenant,
        source_type: :device,
        source_id: device.id
      )

      all_alarms = AlarmEvent.read!(tenant: tenant)
      assert length(all_alarms) == 4

      # Test various filters
      unresolved = AlarmEvent.read!(tenant: tenant, filter: [status: [:new, :acknowledged]])
      assert length(unresolved) == 3

      critical_alarms = AlarmEvent.read!(tenant: tenant, filter: [severity: :critical])
      assert length(critical_alarms) == 1
    end

    test "manages alarm workflow states", %{tenant: tenant, device: device} do
      alarm =
        insert(:alarm_event,
          status: :new,
          tenant: tenant,
          source_type: :device,
          source_id: device.id
        )

      user = insert(:user, tenant: tenant)

      # New -> Acknowledged
      {:ok, ack_alarm} = AlarmEvent.acknowledge(alarm, %{acknowledged_by: user.id})
      assert ack_alarm.status == :acknowledged

      # Acknowledged -> In Progress
      {:ok, progress_alarm} =
        AlarmEvent.start_investigation(ack_alarm, %{
          investigator_id: user.id,
          investigation_notes: "Starting investigation"
        })

      assert progress_alarm.status == :in_progress

      # In Progress -> Resolved
      {:ok, resolved_alarm} =
        AlarmEvent.resolve(progress_alarm, %{
          resolved_by: user.id,
          resolution: "Issue resolved"
        })

      assert resolved_alarm.status == :resolved
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
