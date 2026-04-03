defmodule Intelitor.Integration.AlarmLifecycleTest do
  @moduledoc """
  Complete alarm lifecycle integration tests covering creation through resolution.
  Uses Factory pattern for proper actor context and relationship management.
  """

  use Intelitor.DataCase
  # Oban testing requires proper Oban configuration - skip for now
  # use Oban.Testing, repo: Intelitor.Repo

  alias Intelitor.Alarms.AlarmEvent

  import Ash.Expr
  require Ash.Query

  # Helper to create alarm with proper relationship management
  defp create_alarm(attrs, site, actor, tenant_id) do
    AlarmEvent
    |> Ash.Changeset.for_create(:create, attrs, actor: actor, tenant: tenant_id)
    |> Ash.Changeset.manage_relationship(:site, site, type: :append_and_remove)
    |> Ash.create(actor: actor, tenant: tenant_id)
  end

  defp create_alarm!(attrs, site, actor, tenant_id) do
    {:ok, alarm} = create_alarm(attrs, site, actor, tenant_id)
    alarm
  end

  describe "complete alarm lifecycle" do
    setup do
      # Create test tenant and infrastructure using factory
      # Factory handles proper actor context and relationship management
      tenant = Intelitor.Factory.insert(:tenant)
      organization = Intelitor.Factory.insert(:organization, tenant: tenant)
      site = Intelitor.Factory.insert(:site, tenant: tenant, organization: organization)
      device_type = Intelitor.Factory.insert(:device_type, tenant: tenant)

      device =
        Intelitor.Factory.insert(:device, tenant: tenant, device_type: device_type, site: site)

      user = Intelitor.Factory.insert(:user, tenant: tenant)

      actor = %{is_system_admin: true, role: "admin", tenant_id: tenant.id}

      %{
        tenant: tenant,
        organization: organization,
        site: site,
        device: device,
        device_type: device_type,
        user: user,
        actor: actor
      }
    end

    test "creates alarm event with valid attributes", %{
      tenant: tenant,
      site: site,
      device: device,
      actor: actor
    } do
      alarm_attrs = %{
        event_code: "BA001",
        event_type: :intrusion,
        severity: :high,
        description: "Motion detected in secure area",
        device_id: device.id,
        site_id: site.id,
        raw_data: %{"sensor" => "motion_1"}
      }

      {:ok, alarm} = create_alarm(alarm_attrs, site, actor, tenant.id)

      # Verify initial state
      assert alarm.state == :triggered
      assert alarm.severity == :high
      assert alarm.event_type == :intrusion
      assert alarm.device_id == device.id
      assert alarm.site_id == site.id
    end

    test "acknowledges alarm with user tracking", %{
      tenant: tenant,
      site: site,
      device: device,
      user: user,
      actor: actor
    } do
      # Create alarm
      alarm =
        create_alarm!(
          %{
            event_code: "ACK001",
            event_type: :intrusion,
            severity: :medium,
            description: "Test alarm for acknowledgment",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      # Acknowledge the alarm
      {:ok, acknowledged} =
        alarm
        |> Ash.Changeset.for_update(:acknowledge, %{acknowledged_by: user.id},
          actor: actor,
          tenant: tenant.id
        )
        |> Ash.update(actor: actor, tenant: tenant.id)

      # Verify acknowledgment
      assert acknowledged.state == :acknowledged
      assert acknowledged.acknowledged_by == user.id
      assert acknowledged.acknowledged_at != nil
    end

    test "resolves alarm with resolution tracking", %{
      tenant: tenant,
      site: site,
      device: device,
      user: user,
      actor: actor
    } do
      # Create and acknowledge alarm
      alarm =
        create_alarm!(
          %{
            event_code: "RES001",
            event_type: :intrusion,
            severity: :medium,
            description: "Test alarm for resolution",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      {:ok, acknowledged} =
        alarm
        |> Ash.Changeset.for_update(:acknowledge, %{acknowledged_by: user.id},
          actor: actor,
          tenant: tenant.id
        )
        |> Ash.update(actor: actor, tenant: tenant.id)

      # Resolve the alarm
      {:ok, resolved} =
        acknowledged
        |> Ash.Changeset.for_update(:resolve, %{resolved_by: user.id},
          actor: actor,
          tenant: tenant.id
        )
        |> Ash.update(actor: actor, tenant: tenant.id)

      # Verify resolution
      assert resolved.state == :resolved
      assert resolved.resolved_by == user.id
      assert resolved.resolved_at != nil
    end

    test "marks alarm as false alarm", %{
      tenant: tenant,
      site: site,
      device: device,
      user: user,
      actor: actor
    } do
      # Create and acknowledge alarm
      alarm =
        create_alarm!(
          %{
            event_code: "FA001",
            event_type: :panic,
            severity: :critical,
            description: "Panic button activated",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      {:ok, acknowledged} =
        alarm
        |> Ash.Changeset.for_update(:acknowledge, %{acknowledged_by: user.id},
          actor: actor,
          tenant: tenant.id
        )
        |> Ash.update(actor: actor, tenant: tenant.id)

      # Mark as false alarm
      {:ok, false_alarm} =
        acknowledged
        |> Ash.Changeset.for_update(
          :mark_false_alarm,
          %{
            resolved_by: user.id,
            false_alarm_reason: "Accidental activation during cleaning"
          },
          actor: actor,
          tenant: tenant.id
        )
        |> Ash.update(actor: actor, tenant: tenant.id)

      # Verify false alarm state
      assert false_alarm.state == :false_alarm
      assert false_alarm.resolved_by == user.id
      assert false_alarm.false_alarm_reason == "Accidental activation during cleaning"
    end
  end

  describe "multi-tenant isolation" do
    test "alarms are isolated between tenants" do
      # Create two separate tenants using factory
      tenant1 = Intelitor.Factory.insert(:tenant)
      org1 = Intelitor.Factory.insert(:organization, tenant: tenant1)
      site1 = Intelitor.Factory.insert(:site, tenant: tenant1, organization: org1)
      actor1 = %{is_system_admin: true, role: "admin", tenant_id: tenant1.id}

      tenant2 = Intelitor.Factory.insert(:tenant)
      org2 = Intelitor.Factory.insert(:organization, tenant: tenant2)
      site2 = Intelitor.Factory.insert(:site, tenant: tenant2, organization: org2)
      actor2 = %{is_system_admin: true, role: "admin", tenant_id: tenant2.id}

      # Create alarm for tenant1
      alarm1 =
        create_alarm!(
          %{
            event_code: "T1001",
            event_type: :intrusion,
            severity: :medium,
            description: "Tenant 1 alarm",
            site_id: site1.id,
            raw_data: %{}
          },
          site1,
          actor1,
          tenant1.id
        )

      # Create alarm for tenant2
      alarm2 =
        create_alarm!(
          %{
            event_code: "T2001",
            event_type: :intrusion,
            severity: :medium,
            description: "Tenant 2 alarm",
            site_id: site2.id,
            raw_data: %{}
          },
          site2,
          actor2,
          tenant2.id
        )

      # Verify each alarm was created
      assert alarm1.id != nil
      assert alarm2.id != nil
      assert alarm1.id != alarm2.id

      # Query alarms for each tenant
      {:ok, tenant1_alarms} =
        AlarmEvent
        |> Ash.Query.filter(expr(site_id == ^site1.id))
        |> Ash.read(actor: actor1, tenant: tenant1.id)

      {:ok, tenant2_alarms} =
        AlarmEvent
        |> Ash.Query.filter(expr(site_id == ^site2.id))
        |> Ash.read(actor: actor2, tenant: tenant2.id)

      # Verify tenant isolation
      assert Enum.any?(tenant1_alarms, &(&1.id == alarm1.id))
      assert not Enum.any?(tenant1_alarms, &(&1.id == alarm2.id))

      assert Enum.any?(tenant2_alarms, &(&1.id == alarm2.id))
      assert not Enum.any?(tenant2_alarms, &(&1.id == alarm1.id))
    end
  end

  describe "alarm filtering" do
    setup do
      tenant = Intelitor.Factory.insert(:tenant)
      organization = Intelitor.Factory.insert(:organization, tenant: tenant)
      site = Intelitor.Factory.insert(:site, tenant: tenant, organization: organization)
      device_type = Intelitor.Factory.insert(:device_type, tenant: tenant)

      device =
        Intelitor.Factory.insert(:device, tenant: tenant, device_type: device_type, site: site)

      actor = %{is_system_admin: true, role: "admin", tenant_id: tenant.id}

      %{tenant: tenant, site: site, device: device, actor: actor}
    end

    test "filters alarms by severity", %{tenant: tenant, site: site, device: device, actor: actor} do
      # Create alarms with different severities
      _low =
        create_alarm!(
          %{
            event_code: "LOW1",
            event_type: :intrusion,
            severity: :low,
            description: "Low",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      _medium =
        create_alarm!(
          %{
            event_code: "MED1",
            event_type: :intrusion,
            severity: :medium,
            description: "Medium",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      high =
        create_alarm!(
          %{
            event_code: "HIGH1",
            event_type: :intrusion,
            severity: :high,
            description: "High",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      # Filter by high severity
      {:ok, high_alarms} =
        AlarmEvent
        |> Ash.Query.filter(expr(severity == :high and site_id == ^site.id))
        |> Ash.read(actor: actor, tenant: tenant.id)

      assert length(high_alarms) == 1
      assert hd(high_alarms).id == high.id
    end

    test "filters alarms by state", %{tenant: tenant, site: site, device: device, actor: actor} do
      user = Intelitor.Factory.insert(:user, tenant: tenant)

      # Create triggered alarm
      triggered =
        create_alarm!(
          %{
            event_code: "TRIG1",
            event_type: :intrusion,
            severity: :medium,
            description: "Triggered",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      # Create and acknowledge another alarm
      alarm2 =
        create_alarm!(
          %{
            event_code: "ACK2",
            event_type: :intrusion,
            severity: :medium,
            description: "To Acknowledge",
            device_id: device.id,
            site_id: site.id,
            raw_data: %{}
          },
          site,
          actor,
          tenant.id
        )

      {:ok, acknowledged} =
        alarm2
        |> Ash.Changeset.for_update(:acknowledge, %{acknowledged_by: user.id},
          actor: actor,
          tenant: tenant.id
        )
        |> Ash.update(actor: actor, tenant: tenant.id)

      # Filter by triggered state
      {:ok, triggered_alarms} =
        AlarmEvent
        |> Ash.Query.filter(expr(state == :triggered and site_id == ^site.id))
        |> Ash.read(actor: actor, tenant: tenant.id)

      assert length(triggered_alarms) == 1
      assert hd(triggered_alarms).id == triggered.id

      # Filter by acknowledged state
      {:ok, acknowledged_alarms} =
        AlarmEvent
        |> Ash.Query.filter(expr(state == :acknowledged and site_id == ^site.id))
        |> Ash.read(actor: actor, tenant: tenant.id)

      assert length(acknowledged_alarms) == 1
      assert hd(acknowledged_alarms).id == acknowledged.id
    end
  end
end
