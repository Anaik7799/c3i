defmodule Indrajaal.Integration.AlarmLifecycleTest do
  @moduledoc """
  Complete alarm lifecycle integration tests covering creation through
    resolution
  """

  use Indrajaal.DataCase
  use Oban.Testing, repo: Indrajaal.Repo

  alias Indrajaal.Alarms.Api
  alias Indrajaal.Alarms.ProcessingEngine
  alias Indrajaal.DomainApi

  describe "complete alarm lifecycle" do
    setup do
      # Create test tenant and infrastructure
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Test Security Corp",
            slug: "test-security-corp"
          },
          actor: %{is_system: true}
        )

      {:ok, organization} =
        DomainApi.create_organization(
          %{
            name: "Test Organization",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, site} =
        DomainApi.create_site(
          %{
            name: "Test Site",
            location: "Test Location",
            tenant_id: tenant.id,
            organization_id: organization.id
          },
          actor: %{tenant_id: tenant.id}
        )

      {:ok, device} =
        DomainApi.create_device(
          %{
            name: "Test Device",
            device_type: :panel,
            site_id: site.id,
            tenant_id: tenant.id,
            account_number: "TEST001"
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

      %{
        tenant: tenant,
        organization: organization,
        site: site,
        device: device,
        user: user
      }
    end

    test "complete workflow from trigger to resolution", %{
      tenant: tenant,
      site: site,
      device: device,
      user: user
    } do
      # Step 1: Create alarm __event
      alarm_attrs = %{
        __event_code: "BA001",
        __event_type: :intrusion,
        severity: :high,
        description: "Motion detected in secure area",
        device_id: device.id,
        site_id: site.id,
        tenant_id: tenant.id,
        triggered_at: DateTime.utc_now()
      }

      {:ok, alarm} = Api.create_alarm_event(alarm_attrs, actor: %{tenant_id: tenant.id})

      # Verify initial __state
      assert alarm.__state == :triggered
      assert alarm.severity == :high
      assert alarm.__event_type == :intrusion
      assert alarm.device_id == device.id
      assert alarm.site_id == site.id

      # Step 2: Test acknowledgment
      {:ok, acknowledged_alarm} =
        Api.acknowledge_alarm(
          alarm.id,
          user.id,
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Verify acknowledgment
      assert acknowledged_alarm.__state == :acknowledged
      assert acknowledged_alarm.acknowledged_by == user.id
      assert acknowledged_alarm.acknowledged_at != nil

      # Step 3: Begin investigation
      {:ok, investigating_alarm} =
        Api.begin_investigation(
          alarm.id,
          user.id,
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Verify investigation __state
      assert investigating_alarm.__state == :investigating
      assert investigating_alarm.investigating_by == user.id

      # Step 4: Resolve alarm
      {:ok, resolved_alarm} =
        Api.resolve_alarm(
          alarm.id,
          user.id,
          "False alarm - maintenance activity",
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Verify resolution
      assert resolved_alarm.__state == :resolved
      assert resolved_alarm.resolved_by == user.id
      assert resolved_alarm.resolution_notes == "False alarm - maintenance
        activity"
      assert resolved_alarm.resolved_at != nil

      # Step 5: Verify alarm statistics
      {:ok, stats} = Api.get_alarm_statistics(%{}, actor: %{tenant_id: tenant.id})

      assert stats.total_alarms >= 1
      assert stats.by_state[:resolved] >= 1
      assert stats.by_severity[:high] >= 1
      assert is_float(stats.average_response_time)
      assert is_float(stats.average_resolution_time)
    end

    test "false alarm workflow",
         %{tenant: tenant, device: device, user: user} do
      # Create alarm
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            __event_code: "FA001",
            __event_type: :panic,
            severity: :critical,
            description: "Panic button activated",
            device_id: device.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Acknowledge immediately
      {:ok, acknowledged_alarm} =
        Api.acknowledge_alarm(
          alarm.id,
          user.id,
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Mark as false alarm
      {:ok, false_alarm} =
        Api.mark_false_alarm(
          alarm.id,
          user.id,
          "Accidental activation during cleaning",
          actor: %{tenant_id: tenant.id, id: user.id}
        )

      # Verify false alarm __state
      assert false_alarm.__state == :false_alarm
      assert false_alarm.resolved_by == user.id
      assert false_alarm.false_alarm_reason == "Accidental activation during
        cleaning"
    end

    test "alarm escalation workflow", %{tenant: tenant, device: device} do
      # Create high - priority alarm that should escalate
      {:ok, alarm} =
        Api.create_alarm_event(
          %{
            __event_code: "ES001",
            __event_type: :fire,
            severity: :critical,
            description: "Fire detected",
            device_id: device.id,
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Verify escalation job was enqueued
      assert_enqueued(
        worker: Indrajaal.Jobs.AlarmEscalation,
        args: %{alarm_id: alarm.id}
      )

      # Process escalation job
      perform_job(Indrajaal.Jobs.AlarmEscalation, %{alarm_id: alarm.id})

      # Verify alarm was escalated (implementation dependent)
      {:ok, updated_alarm} = Api.get_alarm_event(alarm.id, actor: %{tenant_id: tenant.id})
      assert updated_alarm.metadata["escalation_tier"] != nil
    end
  end

  describe "multi-tenant isolation" do
    test "alarms are isolated between tenants" do
      # Create two separate tenants
      {:ok, tenant1} =
        DomainApi.create_tenant(
          %{
            name: "Tenant 1",
            slug: "tenant-1"
          },
          actor: %{is_system: true}
        )

      {:ok, tenant2} =
        DomainApi.create_tenant(
          %{
            name: "Tenant 2",
            slug: "tenant-2"
          },
          actor: %{is_system: true}
        )

      # Create alarm for tenant1
      {:ok, alarm1} =
        Api.create_alarm_event(
          %{
            __event_code: "T1001",
            __event_type: :intrusion,
            severity: :medium,
            description: "Tenant 1 alarm",
            tenant_id: tenant1.id
          },
          actor: %{tenant_id: tenant1.id}
        )

      # Create alarm for tenant2
      {:ok, alarm2} =
        Api.create_alarm_event(
          %{
            __event_code: "T2001",
            __event_type: :intrusion,
            severity: :medium,
            description: "Tenant 2 alarm",
            tenant_id: tenant2.id
          },
          actor: %{tenant_id: tenant2.id}
        )

      # Verify tenant1 cannot see tenant2's alarm
      {:error, _} = Api.get_alarm_event(alarm2.id, actor: %{tenant_id: tenant1.id})

      # Verify tenant2 cannot see tenant1's alarm
      {:error, _} = Api.get_alarm_event(alarm1.id, actor: %{tenant_id: tenant2.id})

      # Verify each tenant only sees their own alarms
      {:ok, tenant1_alarms} = Api.list_alarm_events(%{}, actor: %{tenant_id: tenant1.id})
      {:ok, tenant2_alarms} = Api.list_alarm_events(%{}, actor: %{tenant_id: tenant2.id})

      assert Enum.any?(tenant1_alarms, &(&1.id == alarm1.id))
      assert not Enum.any?(tenant1_alarms, &(&1.id == alarm2.id))

      assert Enum.any?(tenant2_alarms, &(&1.id == alarm2.id))
      assert not Enum.any?(tenant2_alarms, &(&1.id == alarm1.id))
    end
  end

  describe "alarm correlation" do
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
            location: "Test Location",
            tenant_id: tenant.id
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create adjacent zones
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

    test "detects spatial correlation",
         %{tenant: tenant, site: site, zone1: zone1, zone2: zone2} do
      # Create first alarm in zone1
      {:ok, alarm1} =
        Api.create_alarm_event(
          %{
            __event_code: "SP001",
            __event_type: :motion,
            severity: :medium,
            description: "Motion in Zone A",
            site_id: site.id,
            zone_id: zone1.id,
            tenant_id: tenant.id,
            triggered_at: DateTime.utc_now()
          },
          actor: %{tenant_id: tenant.id}
        )

      # Create second alarm in adjacent zone2 shortly after
      {:ok, alarm2} =
        Api.create_alarm_event(
          %{
            __event_code: "SP002",
            __event_type: :motion,
            severity: :medium,
            description: "Motion in Zone B",
            site_id: site.id,
            zone_id: zone2.id,
            tenant_id: tenant.id,
            triggered_at: DateTime.add(DateTime.utc_now(), 30, :second)
          },
          actor: %{tenant_id: tenant.id}
        )

      # Process correlation
      perform_job(Indrajaal.Jobs.AlarmCorrelation, %{alarm_id: alarm2.id})

      # Verify correlation was detected
      {:ok, updated_alarm2} = Api.get_alarm_event(alarm2.id, actor: %{tenant_id: tenant.id})
      assert updated_alarm2.correlation_data["spatial_correlation"] != nil
    end

    test "detects temporal patterns", %{tenant: tenant, site: site} do
      base_time = DateTime.utc_now()

      # Create series of alarms with temporal pattern
      alarms =
        for i <- 1..5 do
          {:ok, alarm} =
            Api.create_alarm_event(
              %{
                __event_code: "TP#{String.pad_leading("#{i}", 3, "0")}",
                __event_type: :door,
                severity: :low,
                description: "Door __event #{i}",
                site_id: site.id,
                tenant_id: tenant.id,
                triggered_at: DateTime.add(base_time, i * 60, :second)
              },
              actor: %{tenant_id: tenant.id}
            )

          alarm
        end

      # Process correlation for latest alarm
      latest_alarm = List.last(alarms)
      perform_job(Indrajaal.Jobs.AlarmCorrelation, %{alarm_id: latest_alarm.id})

      # Verify temporal pattern was detected
      {:ok, updated_alarm} =
        Api.get_alarm_event(latest_alarm.id, actor: %{tenant_id: tenant.id})

      assert updated_alarm.correlation_data["temporal_pattern"] != nil
    end
  end

  describe "performance under load" do
    @tag :performance
    test "handles concurrent alarm creation" do
      {:ok, tenant} =
        DomainApi.create_tenant(
          %{
            name: "Load Test Corp",
            slug: "load-test"
          },
          actor: %{is_system: true}
        )

      # Create 100 alarms concurrently
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            Api.create_alarm_event(
              %{
                __event_code: "LT#{String.pad_leading("#{i}", 3, "0")}",
                __event_type: :motion,
                severity: :low,
                description: "Load test alarm #{i}",
                tenant_id: tenant.id
              },
              actor: %{tenant_id: tenant.id}
            )
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 30_000)

      # Verify all alarms were created successfully
      successful_creations = Enum.count(results, &match?({:ok, _}, &1))
      # 95% success rate minimum
      assert successful_creations >= 95

      # Verify alarms are retrievable
      {:ok, all_alarms} = Api.list_alarm_events(%{}, actor: %{tenant_id: tenant.id})
      assert length(all_alarms) >= successful_creations
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
