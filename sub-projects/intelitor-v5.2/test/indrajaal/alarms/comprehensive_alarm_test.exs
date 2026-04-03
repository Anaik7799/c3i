defmodule Indrajaal.Alarms.ComprehensiveAlarmTest do
  use Indrajaal.DataCase, async: false

  alias Indrajaal.Alarms.{AlarmEvent, IncidentType, ProcessingEngine, Api}
  import Indrajaal.DomainApi

  @moduledoc """
  Comprehensive test suite for alarm processing functionality.
  Tests all aspects of alarm creation, processing, state transitions,
  severity evaluation, and cross-domain integration.
  """

  setup do
    # Create test tenant and related data
    {:ok, tenant} =
      create_tenant(%{
        name: "Test Security Company",
        slug: "test-security-#{:rand.uniform(9999)}",
        settings: %{}
      })

    {:ok, org} =
      create_organization(
        %{
          tenant_id: tenant.id,
          name: "Test HQ",
          type: :headquarters,
          primary?: true
        },
        actor: %{tenant_id: tenant.id}
      )

    {:ok, user} =
      create_user(
        %{
          tenant_id: tenant.id,
          email: "test_operator@example.com",
          username: "test_operator_#{:rand.uniform(9999)}",
          first_name: "Test",
          last_name: "Operator",
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!",
          role: :operator,
          status: :active
        },
        actor: %{tenant_id: tenant.id}
      )

    {:ok, site} =
      create_site(
        %{
          tenant_id: tenant.id,
          organization_id: org.id,
          name: "Test Facility",
          code: "TEST001",
          address: "123 Test Street",
          city: "Test City",
          state: "TC",
          country: "US",
          postal_code: "12_345",
          timezone: "America/New_York",
          status: :active
        },
        actor: %{tenant_id: tenant.id}
      )

    {:ok, zone} =
      create_zone(
        %{
          tenant_id: tenant.id,
          site_id: site.id,
          name: "Secure Area",
          code: "Z001",
          zone_type: :restricted,
          criticality: :high,
          active?: true
        },
        actor: %{tenant_id: tenant.id}
      )

    {:ok, device_type} =
      create_device_type(
        %{
          tenant_id: tenant.id,
          name: "Motion Sensor",
          code: "MS001",
          category: :sensor,
          manufacturer: "SecureTech",
          model: "MT-5000",
          capabilities: ["motion", "tamper", "temperature"]
        },
        actor: %{tenant_id: tenant.id}
      )

    {:ok, device} =
      create_device(
        %{
          tenant_id: tenant.id,
          name: "Main Entry Motion",
          serial_number: "MS#{:rand.uniform(99_999)}",
          device_type_id: device_type.id,
          location_id: zone.id,
          status: :online,
          configuration: %{
            "sensitivity" => "high",
            "delay_seconds" => 0
          }
        },
        actor: %{tenant_id: tenant.id}
      )

    {:ok, incident_type} =
      create_incident_type(
        %{
          tenant_id: tenant.id,
          name: "Intrusion",
          code: "INT",
          category: :security,
          priority: 8,
          default_severity: :high,
          requires_dispatch?: true,
          sia_codes: ["BA", "BB"],
          description: "Unauthorized entry detected",
          response_instructions: "Dispatch security team immediately"
        },
        actor: %{tenant_id: tenant.id}
      )

    # Start the processing engine
    start_supervised!(ProcessingEngine)

    %{
      tenant: tenant,
      org: org,
      user: user,
      site: site,
      zone: zone,
      device: device,
      device_type: device_type,
      incident_type: incident_type,
      actor: %{tenant_id: tenant.id}
    }
  end

  describe "alarm creation" do
    test "creates alarm via API", %{
      tenant: tenant,
      site: site,
      zone: zone,
      device: device,
      incident_type: incident_type,
      actor: actor
    } do
      attrs = %{
        event_code: "INT001",
        event_type: :intrusion,
        severity: :high,
        site_id: site.id,
        zone_id: zone.id,
        device_id: device.id,
        description: "Motion detected in secure area",
        incident_type_id: incident_type.id
      }

      assert {:ok, alarm} = Api.create_alarm_event(attrs, actor: actor)
      assert alarm.event_code == "INT001"
      assert alarm.event_type == :intrusion
      assert alarm.state == :triggered
      assert alarm.severity == :high
      assert alarm.site_id == site.id
      assert alarm.tenant_id == tenant.id
    end

    test "creates alarm via Ash changeset", %{
      tenant: tenant,
      site: site,
      device: device,
      actor: actor
    } do
      assert {:ok, alarm} =
               AlarmEvent
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   event_code: "TEST002",
                   event_type: :tamper,
                   site_id: site.id,
                   device_id: device.id,
                   description: "Device tamper detected"
                 },
                 actor: actor
               )
               |> Ash.create!(authorize?: false)

      assert alarm.state == :triggered
      # Default for tamper
      assert alarm.priority == 6
    end

    test "processes device event through engine", %{tenant: tenant, device: device, zone: zone} do
      device_event = %{
        tenant_id: tenant.id,
        source_device_id: device.id,
        event_type: :panic,
        event_code: "PA001",
        location_id: zone.id,
        description: "Panic button activated",
        metadata: %{
          "source" => "manual",
          "user" => "guard_01"
        }
      }

      assert {:ok, alarm} = ProcessingEngine.process_alarm(device_event)
      assert alarm.event_type == :panic
      assert alarm.state == :triggered
      assert alarm.severity_factors != %{}
    end
  end

  describe "alarm state transitions" do
    setup %{site: site, device: device, actor: actor} do
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            event_code: "TEST003",
            event_type: :intrusion,
            site_id: site.id,
            device_id: device.id,
            description: "Test alarm for transitions"
          },
          actor: actor
        )

      %{alarm: alarm}
    end

    test "acknowledges alarm", %{alarm: alarm, user: user, actor: actor} do
      assert alarm.state == :triggered
      assert alarm.acknowledged_by == nil

      assert {:ok, ack_alarm} = Api.acknowledge_alarm(alarm.id, user.id, actor: actor)
      assert ack_alarm.state == :acknowledged
      assert ack_alarm.acknowledged_by == user.id
      assert ack_alarm.acknowledged_at != nil
      assert ack_alarm.response_time_seconds > 0
    end

    test "begins investigation", %{alarm: alarm, user: user, actor: actor} do
      # First acknowledge
      {:ok, alarm} = Api.acknowledge_alarm(alarm.id, user.id, actor: actor)

      assert {:ok, inv_alarm} = Api.begin_investigation(alarm.id, user.id, actor: actor)
      assert inv_alarm.state == :investigating
      assert inv_alarm.investigating_by == user.id
      assert inv_alarm.investigating_at != nil
    end

    test "resolves alarm", %{alarm: alarm, user: user, actor: actor} do
      # Progress through states
      {:ok, alarm} = Api.acknowledge_alarm(alarm.id, user.id, actor: actor)
      {:ok, alarm} = Api.begin_investigation(alarm.id, user.id, actor: actor)

      resolution_notes = "Verified secure - authorized personnel"

      assert {:ok, resolved} =
               Api.resolve_alarm(alarm.id, user.id, resolution_notes, actor: actor)

      assert resolved.state == :resolved
      assert resolved.resolved_by == user.id
      assert resolved.resolution_notes == resolution_notes
      assert resolved.resolution_time_seconds > 0
    end

    test "marks as false alarm", %{alarm: alarm, user: user, actor: actor} do
      {:ok, alarm} = Api.acknowledge_alarm(alarm.id, user.id, actor: actor)

      reason = "Equipment malfunction - sensor needs calibration"
      assert {:ok, false_alarm} = Api.mark_false_alarm(alarm.id, user.id, reason, actor: actor)
      assert false_alarm.state == :false_alarm
      assert false_alarm.false_alarm_reason == reason
    end
  end

  describe "severity evaluation" do
    test "updates alarm severity with factors", %{site: site, device: device, actor: actor} do
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            event_code: "TEST004",
            event_type: :fire,
            severity: :medium,
            site_id: site.id,
            device_id: device.id,
            description: "Smoke detected"
          },
          actor: actor
        )

      severity_factors = %{
        factors: [
          %{factor: :base_severity, weight: 1.8, reason: "Event type: fire"},
          %{factor: :time_based, weight: 1.5, reason: "After hours in high security area"},
          %{factor: :location_criticality, weight: 2.0, reason: "Location criticality: critical"}
        ],
        calculated_at: DateTime.utc_now(),
        total_weight: 5.4
      }

      assert {:ok, updated} =
               Api.update_alarm_severity(alarm, :critical, severity_factors, actor: actor)

      assert updated.severity == :critical
      assert updated.severity_factors == severity_factors
    end
  end

  describe "alarm queries" do
    setup %{site: site, device: device, user: user, actor: actor} do
      # Create multiple alarms in different states
      {:ok, alarm1} =
        Api.create_alarm_event(
          %{
            event_code: "Q001",
            event_type: :intrusion,
            site_id: site.id,
            device_id: device.id,
            description: "Query test 1"
          },
          actor: actor
        )

      {:ok, alarm2} =
        Api.create_alarm_event(
          %{
            event_code: "Q002",
            event_type: :panic,
            site_id: site.id,
            device_id: device.id,
            description: "Query test 2"
          },
          actor: actor
        )

      # Acknowledge one
      {:ok, alarm2} = Api.acknowledge_alarm(alarm2.id, user.id, actor: actor)

      # Resolve another
      {:ok, alarm3} =
        Api.create_alarm_event(
          %{
            event_code: "Q003",
            event_type: :tamper,
            site_id: site.id,
            device_id: device.id,
            description: "Query test 3"
          },
          actor: actor
        )

      {:ok, alarm3} = Api.acknowledge_alarm(alarm3.id, user.id, actor: actor)
      {:ok, alarm3} = Api.resolve_alarm(alarm3.id, user.id, "Test resolution", actor: actor)

      %{alarms: [alarm1, alarm2, alarm3]}
    end

    test "lists all alarms", %{actor: actor, alarms: alarms} do
      {:ok, all_alarms} = Api.list_alarm_events(%{}, actor: actor)
      assert length(all_alarms) >= 3

      alarm_ids = Enum.map(all_alarms, & &1.id)

      for alarm <- alarms do
        assert alarm.id in alarm_ids
      end
    end

    test "gets active alarms only", %{actor: actor} do
      {:ok, active} = Api.get_active_alarms(actor: actor)

      # Should not include resolved alarms
      for alarm <- active do
        assert alarm.state not in [:resolved, :false_alarm]
      end
    end

    test "gets recent alarms", %{actor: actor} do
      {:ok, recent} = Api.get_recent_alarms(5, actor: actor)

      # All should be within last 5 minutes
      five_min_ago = DateTime.add(DateTime.utc_now(), -300, :second)

      for alarm <- recent do
        assert DateTime.compare(alarm.triggered_at, five_min_ago) == :gt
      end
    end

    test "gets alarm by ID", %{actor: actor, alarms: [alarm1 | _]} do
      {:ok, found} = Api.get_alarm_event(alarm1.id, actor: actor)
      assert found.id == alarm1.id
      assert found.event_code == alarm1.event_code
    end

    test "counts alarms by state", %{actor: actor} do
      {:ok, triggered_count} = Api.count_alarms_by_state(:triggered, actor: actor)
      {:ok, ack_count} = Api.count_alarms_by_state(:acknowledged, actor: actor)
      {:ok, resolved_count} = Api.count_alarms_by_state(:resolved, actor: actor)

      assert triggered_count >= 1
      assert ack_count >= 1
      assert resolved_count >= 1
    end
  end

  describe "alarm statistics" do
    setup %{site: site, device: device, user: user, actor: actor} do
      # Create alarms with different severities and states
      alarms =
        for i <- 1..5 do
          severity = Enum.random([:low, :medium, :high, :critical])
          event_type = Enum.random([:intrusion, :panic, :fire, :tamper])

          {:ok, alarm} =
            Api.create_alarm_event(
              %{
                event_code: "STAT#{i}",
                event_type: event_type,
                severity: severity,
                site_id: site.id,
                device_id: device.id,
                description: "Statistics test #{i}"
              },
              actor: actor
            )

          # Acknowledge some
          if rem(i, 2) == 0 do
            {:ok, alarm} = Api.acknowledge_alarm(alarm.id, user.id, actor: actor)

            # Resolve one
            if i == 4 do
              {:ok, alarm} = Api.resolve_alarm(alarm.id, user.id, "Test", actor: actor)
            end

            alarm
          else
            alarm
          end
        end

      %{alarms: alarms}
    end

    test "calculates alarm statistics", %{site: site, actor: actor} do
      {:ok, stats} =
        Api.get_alarm_statistics(
          %{
            site_id: site.id,
            start_date: Date.add(Date.utc_today(), -1)
          },
          actor: actor
        )

      assert stats.total_alarms >= 5
      assert is_map(stats.by_severity)
      assert is_map(stats.by_state)
      assert is_map(stats.by_event_type)
      assert is_number(stats.average_response_time)
      assert is_number(stats.average_resolution_time)
      assert is_number(stats.false_alarm_rate)
    end
  end

  describe "correlation and storm suppression" do
    test "updates correlation data", %{site: site, device: device, actor: actor} do
      # Create related alarms
      {:ok, alarm1} =
        Api.create_alarm_event(
          %{
            event_code: "CORR001",
            event_type: :intrusion,
            site_id: site.id,
            device_id: device.id,
            description: "Correlation test 1"
          },
          actor: actor
        )

      {:ok, alarm2} =
        Api.create_alarm_event(
          %{
            event_code: "CORR002",
            event_type: :intrusion,
            site_id: site.id,
            device_id: device.id,
            description: "Correlation test 2"
          },
          actor: actor
        )

      correlation_data = %{
        correlation_group_id: Ecto.UUID.generate(),
        parent_event_id: alarm1.id,
        correlated_events: [alarm2.id],
        correlation_data: %{
          "type" => "spatial",
          "confidence" => 0.85,
          "distance_meters" => 10
        }
      }

      assert {:ok, updated} =
               Api.update_alarm_correlation(alarm2, correlation_data, actor: actor)

      assert updated.correlation_group_id == correlation_data.correlation_group_id
      assert updated.parent_event_id == alarm1.id
      assert alarm2.id in updated.correlated_events
    end

    test "marks alarm as storm suppressed", %{site: site, device: device, actor: actor} do
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            event_code: "STORM001",
            event_type: :tamper,
            site_id: site.id,
            device_id: device.id,
            description: "Storm test"
          },
          actor: actor
        )

      assert {:ok, suppressed} = Api.mark_storm_suppressed(alarm, actor: actor)
      assert suppressed.storm_suppressed == true
      assert suppressed.metadata["storm_suppressed_at"] != nil
    end
  end

  describe "multi-tenant isolation" do
    test "prevents cross-tenant access", %{site: site, device: device, actor: actor} do
      # Create alarm for tenant 1
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            event_code: "ISO001",
            event_type: :intrusion,
            site_id: site.id,
            device_id: device.id,
            description: "Isolation test"
          },
          actor: actor
        )

      # Create second tenant
      {:ok, tenant2} =
        create_tenant(%{
          name: "Other Company",
          slug: "other-#{:rand.uniform(9999)}",
          settings: %{}
        })

      # Try to access alarm with different tenant actor
      actor2 = %{tenant_id: tenant2.id}

      # Should not find the alarm
      assert {:error, %Ash.Error.Query.NotFound{}} =
               Api.get_alarm_event(alarm.id, actor: actor2)

      # Should not list the alarm
      {:ok, alarms} = Api.list_alarm_events(%{}, actor: actor2)
      assert Enum.empty?(alarms)
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
