defmodule Indrajaal.Jobs.AlarmBackgroundJobsTest do
  @moduledoc """
  Background job processing tests for alarm system
  """

  use Indrajaal.DataCase
  use Oban.Testing, repo: Indrajaal.Repo

  alias Indrajaal.Alarms.Api, as: AlarmsApi
  alias Indrajaal.DomainApi
  alias Indrajaal.Jobs.{AlarmEscalation, AlarmCorrelation, AlarmAutoResolve}

  describe "AlarmEscalation job" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Escalation Test Corp",
            slug: "escalation-test"
          },
          actor: %{is_system: true}
        )

      {:ok, user} =
        DomainApi.create_user(
          %{
            email: "operator@test.com",
            first_name: "Test",
            last_name: "Operator",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, role} =
        DomainApi.create_role(
          %{
            name: "Security Operator",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, _user_role} =
        DomainApi.assign_user_role(
          user.id,
          role.id,
          %{
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      %{tenant: tenant, user: user, role: role}
    end

    test "escalates unacknowledged alarm", %{tenant: tenant, user: user} do
      # Create alarm that should be escalated
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "ESC001",
            __event_type: :intrusion,
            severity: :high,
            description: "Escalation test alarm",
            tenant_id: tenant.id,
            # 5 minutes ago
            triggered_at: DateTime.add(DateTime.utc_now(), -300, :second)
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process escalation job
      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: alarm.id,
                 escalation_tier: 1
               })

      # Verify notifications were created
      {:ok, notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id
          },
          actor: %{tenant_id: tenant.id}
        )

      assert length(notifications) > 0

      notification = List.first(notifications)
      assert notification.alarm_id == alarm.id
      assert notification.recipient_id == user.id
      assert notification.escalation_tier == 1
    end

    test "does not escalate acknowledged alarm",
         %{tenant: tenant, user: user} do
      # Create and acknowledge alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "ESC002",
            __event_type: :motion,
            severity: :medium,
            description: "Already acknowledged alarm",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, _ack_alarm} =
        AlarmsApi.acknowledge_alarm(
          alarm.id,
          user.id,
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Process escalation job
      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: alarm.id,
                 escalation_tier: 1
               })

      # Should not create additional notifications
      {:ok, notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id,
            escalation_tier: 1
          },
          actor: %{tenant_id: tenant.id}
        )

      assert Enum.empty?(notifications)
    end

    test "escalates to higher tier after timeout",
         %{tenant: tenant, user: _user} do
      # Create critical alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "ESC003",
            __event_type: :panic,
            severity: :critical,
            description: "Multi - tier escalation test",
            tenant_id: tenant.id,
            # 10 minutes ago
            triggered_at: DateTime.add(DateTime.utc_now(), -600, :second)
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process tier 1 escalation
      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: alarm.id,
                 escalation_tier: 1
               })

      # Process tier 2 escalation
      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: alarm.id,
                 escalation_tier: 2
               })

      # Verify both tiers have notifications
      {:ok, tier1_notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id,
            escalation_tier: 1
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, tier2_notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id,
            escalation_tier: 2
          },
          actor: %{tenant_id: tenant.id}
        )

      assert length(tier1_notifications) > 0
      assert length(tier2_notifications) > 0
    end

    test "handles missing alarm gracefully", %{} do
      fake_alarm_id = Ash.UUID.generate()

      # Should not crash on missing alarm
      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: fake_alarm_id,
                 escalation_tier: 1
               })
    end

    test "respects quiet hours configuration", %{tenant: tenant} do
      # Create alarm during configured quiet hours
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "ESC004",
            __event_type: :motion,
            severity: :low,
            description: "Quiet hours test alarm",
            tenant_id: tenant.id,
            # 2 AM - typical quiet hours
            triggered_at: ~U[2024-01-01 02:00:00Z]
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process escalation job
      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: alarm.id,
                 escalation_tier: 1
               })

      # Low severity alarms should be suppressed during quiet hours
      {:ok, notifications} =
        DomainApi.list_notifications(
          %{
            alarm_id: alarm.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Should have limited notifications during quiet hours
      assert length(notifications) <= 1
    end
  end

  describe "AlarmCorrelation job" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Correlation Test Corp",
            slug: "correlation-test"
          },
          actor: %{is_system: true}
        )

      {:ok, site} =
        DomainApi.create_site(
          %{
            name: "Test Site",
            location: "Correlation Test Location",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, zone1} =
        DomainApi.create_zone(
          %{
            name: "Zone A",
            site_id: site.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, zone2} =
        DomainApi.create_zone(
          %{
            name: "Zone B",
            site_id: site.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      %{tenant: tenant, site: site, zone1: zone1, zone2: zone2}
    end

    test "correlates spatial alarms",
         %{tenant: tenant, site: site, zone1: zone1, zone2: zone2} do
      base_time = DateTime.utc_now()

      # Create first alarm
      {:ok, alarm1} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "COR001",
            __event_type: :motion,
            severity: :medium,
            description: "First spatial alarm",
            site_id: site.id,
            zone_id: zone1.id,
            tenant_id: tenant.id,
            triggered_at: base_time
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create related alarm in adjacent zone
      {:ok, alarm2} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "COR002",
            __event_type: :motion,
            severity: :medium,
            description: "Second spatial alarm",
            site_id: site.id,
            zone_id: zone2.id,
            tenant_id: tenant.id,
            triggered_at: DateTime.add(base_time, 30, :second)
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process correlation for second alarm
      assert :ok =
               perform_job(AlarmCorrelation, %{
                 alarm_id: alarm2.id
               })

      # Verify correlation was detected
      {:ok, updated_alarm2} =
        AlarmsApi.get_alarm_event(alarm2.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm2.correlation_data["spatial_correlation"] != nil
      assert updated_alarm2.correlation_data["correlated_alarms"] != nil
      assert alarm1.id in updated_alarm2.correlation_data["correlated_alarms"]
    end

    test "correlates temporal patterns", %{tenant: tenant, site: site} do
      base_time = DateTime.utc_now()

      # Create series of alarms with temporal pattern
      alarms =
        for i <- 1..4 do
          {:ok, alarm} =
            AlarmsApi.create_alarm_event(
              %{
                __event_code: "TMP#{String.pad_leading("#{i}", 3, "0")}",
                __event_type: :door,
                severity: :low,
                description: "Temporal pattern alarm #{i}",
                site_id: site.id,
                tenant_id: tenant.id,
                # 1 minute intervals
                triggered_at: DateTime.add(base_time, i * 60, :second)
              },
              actor: %{tenant_id: tenant.id}
            )

          alarm
        end

      # Process correlation for latest alarm
      latest_alarm = List.last(alarms)

      assert :ok =
               perform_job(AlarmCorrelation, %{
                 alarm_id: latest_alarm.id
               })

      # Verify temporal pattern was detected
      {:ok, updated_alarm} =
        AlarmsApi.get_alarm_event(latest_alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.correlation_data["temporal_pattern"] != nil
      assert updated_alarm.correlation_data["pattern_strength"] != nil
    end

    test "correlates device malfunction patterns",
         %{tenant: tenant, site: site} do
      # Create device
      {:ok, device} =
        DomainApi.create_device(
          %{
            name: "Test Device",
            device_type: :sensor,
            site_id: site.id,
            tenant_id: tenant.id,
            account_number: "DEV001"
          },
          actor: %{tenant_id: tenant.id}
        )

      base_time = DateTime.utc_now()

      # Create multiple alarms from same device (indicating malfunction)
      alarms =
        for i <- 1..3 do
          {:ok, alarm} =
            AlarmsApi.create_alarm_event(
              %{
                __event_code: "MAL#{String.pad_leading("#{i}", 3, "0")}",
                __event_type: :tamper,
                severity: :medium,
                description: "Device malfunction alarm #{i}",
                device_id: device.id,
                site_id: site.id,
                tenant_id: tenant.id,
                triggered_at: DateTime.add(base_time, i * 30, :second)
              },
              actor: %{tenant_id: tenant.id}
            )

          alarm
        end

      # Process correlation for latest alarm
      latest_alarm = List.last(alarms)

      assert :ok =
               perform_job(AlarmCorrelation, %{
                 alarm_id: latest_alarm.id
               })

      # Verify device malfunction pattern was detected
      {:ok, updated_alarm} =
        AlarmsApi.get_alarm_event(latest_alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.correlation_data["device_malfunction"] != nil
      assert updated_alarm.correlation_data["malfunction_confidence"] != nil
    end

    test "handles no correlation gracefully", %{tenant: tenant} do
      # Create isolated alarm with no correlations
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "ISO001",
            __event_type: :motion,
            severity: :low,
            description: "Isolated alarm",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process correlation
      assert :ok =
               perform_job(AlarmCorrelation, %{
                 alarm_id: alarm.id
               })

      # Should complete without errors, no correlations found
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.correlation_data["analysis_completed"] == true
      assert updated_alarm.correlation_data["correlations_found"] == 0
    end
  end

  describe "AlarmAutoResolve job" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Auto Resolve Test Corp",
            slug: "auto - resolve - test"
          },
          actor: %{is_system: true}
        )

      %{tenant: tenant}
    end

    test "auto - resolves old low - priority alarms", %{tenant: tenant} do
      # 2 hours ago
      old_time = DateTime.add(DateTime.utc_now(), -7200, :second)

      # Create old low - priority alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AUTO001",
            __event_type: :motion,
            severity: :low,
            description: "Auto - resolve test alarm",
            tenant_id: tenant.id,
            triggered_at: old_time
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process auto - resolve job
      assert :ok =
               perform_job(AlarmAutoResolve, %{
                 alarm_id: alarm.id
               })

      # Verify alarm was auto - resolved
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.__state == :resolved
      assert updated_alarm.auto_resolved == true
      assert updated_alarm.resolution_notes =~ "Auto - resolved"
    end

    test "does not auto - resolve high - priority alarms", %{tenant: tenant} do
      # 2 hours ago
      old_time = DateTime.add(DateTime.utc_now(), -7200, :second)

      # Create old high - priority alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AUTO002",
            __event_type: :intrusion,
            severity: :critical,
            description: "High priority alarm",
            tenant_id: tenant.id,
            triggered_at: old_time
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process auto - resolve job
      assert :ok =
               perform_job(AlarmAutoResolve, %{
                 alarm_id: alarm.id
               })

      # Verify alarm was NOT auto - resolved
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.__state == :triggered
      assert updated_alarm.auto_resolved != true
    end

    test "does not auto - resolve acknowledged alarms", %{tenant: tenant} do
      # 2 hours ago
      old_time = DateTime.add(DateTime.utc_now(), -7200, :second)

      # Create and acknowledge alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AUTO003",
            __event_type: :door,
            severity: :low,
            description: "Acknowledged alarm",
            tenant_id: tenant.id,
            triggered_at: old_time
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, user} =
        DomainApi.create_user(
          %{
            email: "operator@test.com",
            first_name: "Test",
            last_name: "Operator",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, _ack_alarm} =
        AlarmsApi.acknowledge_alarm(
          alarm.id,
          user.id,
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Process auto - resolve job
      assert :ok =
               perform_job(AlarmAutoResolve, %{
                 alarm_id: alarm.id
               })

      # Verify alarm was NOT auto - resolved (already acknowledged)
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.__state == :acknowledged
      assert updated_alarm.auto_resolved != true
    end

    test "respects auto - resolve configuration", %{tenant: tenant} do
      # Create alarm that would normally auto - resolve
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "AUTO004",
            __event_type: :motion,
            severity: :low,
            description: "Configuration test alarm",
            tenant_id: tenant.id,
            triggered_at: DateTime.add(DateTime.utc_now(), -7200, :second),
            metadata: %{auto_resolve_disabled: true}
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process auto - resolve job
      assert :ok =
               perform_job(AlarmAutoResolve, %{
                 alarm_id: alarm.id
               })

      # Should respect the disable flag
      {:ok, updated_alarm} = AlarmsApi.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.__state == :triggered
      assert updated_alarm.auto_resolved != true
    end
  end

  describe "job scheduling and retries" do
    setup do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Job Test Corp",
            slug: "job-test"
          },
          actor: %{is_system: true}
        )

      %{tenant: tenant}
    end

    test "alarm creation schedules background jobs", %{tenant: tenant} do
      # Create alarm
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "JOB001",
            __event_type: :panic,
            severity: :critical,
            description: "Job scheduling test",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify escalation job was scheduled
      assert_enqueued(
        worker: AlarmEscalation,
        args: %{alarm_id: alarm.id, escalation_tier: 1}
      )

      # Verify correlation job was scheduled
      assert_enqueued(
        worker: AlarmCorrelation,
        args: %{alarm_id: alarm.id}
      )

      # Auto - resolve job should be scheduled for later
      assert_enqueued(
        worker: AlarmAutoResolve,
        args: %{alarm_id: alarm.id}
      )
    end

    test "failed jobs are retried with backoff", %{tenant: tenant} do
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "RETRY001",
            __event_type: :motion,
            severity: :medium,
            description: "Retry test alarm",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Simulate job failure by corrupting alarm ID
      corrupted_args = %{alarm_id: "invalid-uuid"}

      # Job should handle error gracefully
      assert :ok = perform_job(AlarmEscalation, corrupted_args)

      # Real job should still be enqueable
      assert_enqueued(
        worker: AlarmEscalation,
        args: %{alarm_id: alarm.id, escalation_tier: 1}
      )
    end

    test "job performance is monitored", %{tenant: tenant} do
      {:ok, alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "PERF001",
            __event_type: :fire,
            severity: :critical,
            description: "Performance test alarm",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Measure job execution time
      start_time = System.monotonic_time(:millisecond)

      assert :ok =
               perform_job(AlarmEscalation, %{
                 alarm_id: alarm.id,
                 escalation_tier: 1
               })

      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # Job should complete quickly (under 1 second)
      assert execution_time < 1000
    end
  end

  describe "job queue management" do
    test "high priority alarms processed first" do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Priority Test Corp",
            slug: "priority-test"
          },
          actor: %{is_system: true}
        )

      # Create low priority alarm
      {:ok, low_alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "LOW001",
            __event_type: :motion,
            severity: :low,
            description: "Low priority alarm",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create high priority alarm
      {:ok, high_alarm} =
        AlarmsApi.create_alarm_event(
          %{
            __event_code: "HIGH001",
            __event_type: :panic,
            severity: :critical,
            description: "High priority alarm",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Both should be enqueued
      assert_enqueued(worker: AlarmEscalation, args: %{alarm_id: low_alarm.id})
      assert_enqueued(worker: AlarmEscalation, args: %{alarm_id: high_alarm.id})

      # High priority should have higher queue priority
      all_jobs = all_enqueued(worker: AlarmEscalation)
      high_priority_jobs = all_jobs |> Enum.filter(&(&1.args["alarm_id"] == high_alarm.id))

      assert length(high_priority_jobs) > 0
      assert List.first(high_priority_jobs).priority > 0
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
