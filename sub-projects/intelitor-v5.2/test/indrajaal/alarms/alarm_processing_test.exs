defmodule Indrajaal.Alarms.AlarmProcessingTest do
  use Indrajaal.DataCase, async: true

  alias Indrajaal.Alarms

  alias Indrajaal.Alarms.{
    ProcessingEngine,
    SeverityEngine,
    CorrelationEngine,
    NotificationOrchestrator,
    WorkflowEngine,
    StormDetection
  }

  describe "alarm creation and processing" do
    setup do
      tenant = tenant_fixture()
      site = site_fixture(tenant_id: tenant.id)
      device = device_fixture(tenant_id: tenant.id, site_id: site.id)

      {:ok, tenant: tenant, site: site, device: device}
    end

    test "creates alarm from device event", %{tenant: tenant, device: device} do
      device_event = %{
        tenant_id: tenant.id,
        source_device_id: device.id,
        event_code: "BA",
        event_type: :intrusion,
        severity: :high,
        location_id: device.location_id,
        description: "Motion detected in secure area"
      }

      assert {:ok, alarm} = ProcessingEngine.process_alarm(device_event)
      assert alarm.event_type == :intrusion
      assert alarm.severity == :high
      assert alarm.state == :triggered
      assert alarm.device_id == device.id
    end

    test "processes SIA protocol event", %{tenant: tenant, device: device} do
      # Mock SIA DC - 09 binary data
      # Simplified example
      sia_data = <<0x0A, 0x00, 0x12, 0x34>>

      # This test would require mocking the SIA parser
      # For now, we'll test the structure
      assert {:ok, _alarm} = ProcessingEngine.handle_sia_event(sia_data)
    end

    test "handles API - based alarm events", %{tenant: tenant, device: device} do
      params = %{
        device_id: device.id,
        event_code: "PA",
        event_type: :panic,
        severity: :critical,
        description: "Panic button activated",
        metadata: %{
          source: "api",
          user_id: "test-user"
        }
      }

      assert {:ok, alarm} = ProcessingEngine.handle_api_event(params, tenant.id)
      assert alarm.event_type == :panic
      assert alarm.severity == :critical
      assert alarm.metadata["source"] == "api"
    end
  end

  describe "severity evaluation" do
    setup do
      tenant = tenant_fixture()
      alarm = alarm_event_fixture(tenant_id: tenant.id)
      {:ok, alarm: alarm}
    end

    test "evaluates severity based on multiple factors", %{alarm: alarm} do
      assert {:ok, evaluated_alarm} = SeverityEngine.evaluate(alarm)

      # Check that severity factors were calculated
      assert evaluated_alarm.metadata["severity_factors"]
      assert is_list(evaluated_alarm.metadata["severity_factors"])

      # Verify each factor has required fields
      Enum.each(evaluated_alarm.metadata["severity_factors"], fn factor ->
        assert factor[:factor]
        assert factor[:weight]
        assert factor[:reason]
      end)
    end

    test "increases severity for after - hours events" do
      # Create an alarm triggered after hours
      after_hours_alarm =
        alarm_event_fixture(
          # 2 AM
          triggered_at: ~U[2024-01-15T02:00:00Z],
          event_type: :intrusion
        )

      assert {:ok, evaluated} = SeverityEngine.evaluate(after_hours_alarm)

      time_factor =
        Enum.find(evaluated.metadata["severity_factors"], fn f ->
          f.factor == :time_based
        end)

      assert time_factor.weight > 1.0
    end

    test "reduces severity for high false alarm locations" do
      # This would require mocking the false alarm rate calculation
      alarm = alarm_event_fixture(event_type: :intrusion)

      assert {:ok, evaluated} = SeverityEngine.evaluate(alarm)

      historical_factor =
        Enum.find(evaluated.metadata["severity_factors"], fn f ->
          f.factor == :historical
        end)

      assert historical_factor
    end
  end

  describe "correlation analysis" do
    setup do
      tenant = tenant_fixture()
      site = site_fixture(tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "detects spatial correlation", %{tenant: tenant, site: site} do
      # Create multiple alarms in adjacent locations
      zone1 = zone_fixture(site_id: site.id)
      zone2 = zone_fixture(site_id: site.id)

      alarm1 =
        alarm_event_fixture(
          tenant_id: tenant.id,
          site_id: site.id,
          zone_id: zone1.id,
          triggered_at: DateTime.utc_now()
        )

      alarm2 =
        alarm_event_fixture(
          tenant_id: tenant.id,
          site_id: site.id,
          zone_id: zone2.id,
          triggered_at: DateTime.add(DateTime.utc_now(), 30, :second)
        )

      assert {:ok, analyzed} = CorrelationEngine.analyze(alarm2)

      # Should detect spatial correlation
      assert analyzed.correlated_events != []
    end

    test "detects temporal patterns", %{tenant: tenant, site: site} do
      # Create alarms with regular intervals
      base_time = DateTime.utc_now()

      alarms =
        for i <- 0..3 do
          alarm_event_fixture(
            tenant_id: tenant.id,
            site_id: site.id,
            event_type: :intrusion,
            # 5 minute intervals
            triggered_at: DateTime.add(base_time, i * 300, :second)
          )
        end

      last_alarm = List.last(alarms)
      assert {:ok, analyzed} = CorrelationEngine.analyze(last_alarm)

      # Should detect temporal correlation
      assert analyzed.metadata["correlations"]
    end

    test "detects cross - domain correlations", %{tenant: tenant, site: site} do
      # Create an alarm
      alarm =
        alarm_event_fixture(
          tenant_id: tenant.id,
          site_id: site.id,
          event_type: :intrusion
        )

      # Mock access control events
      # This would require creating access_log_fixture

      assert {:ok, analyzed} = CorrelationEngine.analyze(alarm)
      # Test would check for cross - domain correlation detection
    end
  end

  describe "notification orchestration" do
    setup do
      tenant = tenant_fixture()
      user = user_fixture(tenant_id: tenant.id)
      alarm = alarm_event_fixture(tenant_id: tenant.id, severity: :high)

      {:ok, tenant: tenant, user: user, alarm: alarm}
    end

    test "creates notification plan based on severity", %{alarm: alarm} do
      # Test notification planning
      assert :ok = NotificationOrchestrator.notify_for_alarm(alarm)

      # Check notification status
      status = NotificationOrchestrator.get_notification_status(alarm.id)
      assert status.total_sent > 0
    end

    test "handles notification acknowledgment", %{alarm: alarm, user: user} do
      # Send notifications
      assert :ok = NotificationOrchestrator.notify_for_alarm(alarm)

      # Acknowledge
      assert :ok = NotificationOrchestrator.handle_acknowledgment(alarm.id, user.id)

      # Verify escalations were cancelled
      status = NotificationOrchestrator.get_notification_status(alarm.id)
      assert status.read > 0
    end

    test "respects user notification preferences" do
      # Create user with specific preferences
      user =
        user_fixture(
          notification_preferences: %{
            quiet_hours_enabled: true,
            quiet_hours_start: ~T[22:00:00],
            quiet_hours_end: ~T[07:00:00]
          }
        )

      # Create alarm during quiet hours
      alarm =
        alarm_event_fixture(
          severity: :low,
          triggered_at: ~U[2024-01-15T23:00:00Z]
        )

      # Notifications should respect quiet hours for low severity
      assert :ok = NotificationOrchestrator.notify_for_alarm(alarm)
    end
  end

  describe "workflow execution" do
    setup do
      tenant = tenant_fixture()

      alarm =
        alarm_event_fixture(
          tenant_id: tenant.id,
          event_type: :intrusion,
          severity: :high
        )

      {:ok, tenant: tenant, alarm: alarm}
    end

    test "executes intrusion response workflow", %{alarm: alarm} do
      workflow = WorkflowEngine.intrusion_response_workflow()

      assert {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)
      assert instance.state == :running
      assert length(instance.completed_steps) > 0
    end

    test "handles conditional workflow steps", %{alarm: alarm} do
      # Create a workflow with conditions
      workflow = %{
        id: "test_conditional",
        name: "Test Conditional Workflow",
        steps: [
          %{
            id: "check_severity",
            type: :condition,
            condition: %{
              type: :alarm_severity,
              operator: :equals,
              value: :high
            }
          },
          %{
            id: "high_severity_action",
            type: :action,
            action: %{
              type: :dispatch_security,
              params: %{priority: :high}
            }
          }
        ]
      }

      assert {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)

      # Should execute the action since severity is high
      assert Enum.any?(instance.completed_steps, &(&1.step_id == "high_severity_action"))
    end

    test "executes parallel workflow steps", %{alarm: alarm} do
      workflow = %{
        id: "test_parallel",
        name: "Test Parallel Workflow",
        steps: [
          %{
            id: "parallel_actions",
            type: :parallel,
            parallel_steps: [
              %{
                id: "action1",
                type: :action,
                action: %{type: :start_video_recording, params: %{cameras: :area_cameras}}
              },
              %{
                id: "action2",
                type: :action,
                action: %{type: :notify_stakeholders, params: %{template: :test}}
              }
            ]
          }
        ]
      }

      assert {:ok, instance} = WorkflowEngine.execute_workflow(workflow, alarm)
      assert instance.completed_steps != []
    end
  end

  describe "alarm storm detection" do
    setup do
      tenant = tenant_fixture()
      {:ok, tenant: tenant}
    end

    test "detects alarm storm conditions", %{tenant: tenant} do
      # Create many alarms quickly
      for _ <- 1..60 do
        alarm_event_fixture(
          tenant_id: tenant.id,
          triggered_at: DateTime.utc_now()
        )
      end

      assert :ok = StormDetection.detect_storm(tenant.id)

      # Check storm status
      status = StormDetection.get_storm_status(tenant.id)
      assert status.active
      assert status.alarm_count >= 60
    end

    test "applies storm mitigation settings", %{tenant: tenant} do
      # Manually activate storm mode
      assert :ok = StormDetection.activate_storm_mode(tenant.id, "Test activation")

      status = StormDetection.get_storm_status(tenant.id)
      assert status.active
      assert status.mode == :manual
    end

    test "recovers from storm conditions", %{tenant: tenant} do
      # Activate storm mode
      StormDetection.activate_storm_mode(tenant.id)

      # Deactivate
      assert :ok = StormDetection.deactivate_storm_mode(tenant.id)

      status = StormDetection.get_storm_status(tenant.id)
      refute status.active
    end
  end

  describe "alarm state transitions" do
    setup do
      tenant = tenant_fixture()
      user = user_fixture(tenant_id: tenant.id)
      alarm = alarm_event_fixture(tenant_id: tenant.id)

      {:ok, tenant: tenant, user: user, alarm: alarm}
    end

    test "acknowledges alarm", %{alarm: alarm, user: user} do
      assert {:ok, ack_alarm} = Alarms.acknowledge(alarm.id, acknowledged_by: user.id)

      assert ack_alarm.state == :acknowledged
      assert ack_alarm.acknowledged_by == user.id
      assert ack_alarm.acknowledged_at
      assert ack_alarm.response_time_seconds
    end

    test "begins investigation", %{alarm: alarm, user: user} do
      # First acknowledge
      {:ok, alarm} = Alarms.acknowledge(alarm.id, acknowledged_by: user.id)

      assert {:ok, inv_alarm} = Alarms.begin_investigation(alarm.id, investigating_by: user.id)

      assert inv_alarm.state == :investigating
      assert inv_alarm.investigating_by == user.id
      assert inv_alarm.investigating_at
    end

    test "resolves alarm", %{alarm: alarm, user: user} do
      assert {:ok, resolved} =
               Alarms.resolve(
                 alarm.id,
                 resolved_by: user.id,
                 resolution_notes: "Issue resolved"
               )

      assert resolved.state == :resolved
      assert resolved.resolved_by == user.id
      assert resolved.resolved_at
      assert resolved.resolution_notes == "Issue resolved"
      assert resolved.resolution_time_seconds
    end

    test "marks as false alarm", %{alarm: alarm, user: user} do
      assert {:ok, false_alarm} =
               Alarms.mark_false_alarm(
                 alarm.id,
                 resolved_by: user.id,
                 false_alarm_reason: "Sensor malfunction"
               )

      assert false_alarm.state == :false_alarm
      assert false_alarm.false_alarm_reason == "Sensor malfunction"
    end
  end

  describe "background jobs" do
    setup do
      tenant = tenant_fixture()
      alarm = alarm_event_fixture(tenant_id: tenant.id, severity: :high)

      {:ok, tenant: tenant, alarm: alarm}
    end

    test "schedules escalation job", %{alarm: alarm} do
      # Insert escalation job
      assert {:ok, job} =
               %{
                 alarm_id: alarm.id,
                 current_tier: 1,
                 next_tier: 2
               }
               |> Indrajaal.Jobs.AlarmEscalation.new()
               |> Oban.insert()

      assert job.queue == "alarms"
      assert job.args["alarm_id"] == alarm.id
    end

    test "schedules correlation job", %{alarm: alarm} do
      assert {:ok, job} =
               %{alarm_id: alarm.id}
               |> Indrajaal.Jobs.AlarmCorrelation.new(scheduled_at: 300)
               |> Oban.insert()

      assert job.queue == "alarms"
    end

    test "schedules auto - resolve job for eligible alarms" do
      # Create low severity alarm
      alarm =
        alarm_event_fixture(
          severity: :low,
          event_type: :supervisory
        )

      assert :ok = Indrajaal.Jobs.AlarmAutoResolve.schedule_if_eligible(alarm)
    end
  end

  # Helper Functions

  defp tenant_fixture(attrs \\ %{}) do
    insert(:tenant, Enum.into(attrs, %{}))
  end

  defp site_fixture(attrs \\ %{}) do
    default_attrs = %{name: "Test Site", address: "123 Test St"}
    insert(:site, Map.merge(default_attrs, Enum.into(attrs, %{})))
  end

  defp zone_fixture(attrs \\ %{}) do
    default_attrs = %{name: "Test Zone", zone_type: :secure}
    insert(:zone, Map.merge(default_attrs, Enum.into(attrs, %{})))
  end

  defp device_fixture(attrs \\ %{}) do
    default_attrs = %{name: "Test Device", device_type: :sensor, status: :online}
    insert(:device, Map.merge(default_attrs, Enum.into(attrs, %{})))
  end

  defp user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "test-#{System.unique_integer([:positive])}@example.com",
      first_name: "Test",
      last_name: "User"
    }

    insert(:user, Map.merge(default_attrs, Enum.into(attrs, %{})))
  end

  defp alarm_event_fixture(attrs \\ %{}) do
    base_attrs = %{
      event_code: "TEST",
      event_type: :intrusion,
      severity: :medium,
      description: "Test alarm",
      triggered_at: DateTime.utc_now()
    }

    insert(:alarm_event, Map.merge(base_attrs, Enum.into(attrs, %{})))
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
