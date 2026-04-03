defmodule Indrajaal.Maintenance.EquipmentTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.Tenant
  alias Indrajaal.Maintenance.{Equipment, WorkOrder, Task, Schedule}
  alias Indrajaal.Sites.Site

  describe "Equipment resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)

      {:ok, tenant: tenant, organization: organization, site: site}
    end

    test "creates equipment with valid attributes",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "HVAC System Unit 1",
        equipment_type: :hvac,
        manufacturer: "Carrier",
        model: "30XA - 1002",
        serial_number: "SN - HVAC - 001 - 2024",
        installation_date: Date.utc_today() |> Date.add(-365),
        warranty_expiry: Date.utc_today() |> Date.add(730),
        status: :operational,
        location_description: "Rooftop, North Building",
        specifications: %{
          "capacity" => "100 tons",
          "refrigerant" => "R - 410A",
          "voltage" => "480V",
          "phases" => 3
        },
        site_id: site.id,
        tenant_id: tenant.id
      }

      {:ok, equipment} = Equipment.create(attrs)

      assert equipment.name == "HVAC System Unit 1"
      assert equipment.equipment_type == :hvac
      assert equipment.manufacturer == "Carrier"
      assert equipment.model == "30XA - 1002"
      assert equipment.serial_number == "SN - HVAC - 001 - 2024"
      assert equipment.status == :operational
      assert equipment.specifications["capacity"] == "100 tons"
      assert equipment.site_id == site.id
      assert equipment.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Equipment.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:equipment_type]
      assert changeset.errors[:serial_number]
      assert changeset.errors[:site_id]
    end

    test "validates equipment type", %{tenant: tenant, site: site} do
      valid_types = [
        :hvac,
        :elevator,
        :generator,
        :fire_system,
        :security_camera,
        :access_control,
        :lighting,
        :plumbing,
        :electrical,
        :network
      ]

      for type <- valid_types do
        {:ok, _equipment} =
          Equipment.create(%{
            name: "Test Equipment",
            equipment_type: type,
            serial_number: "TEST-#{System.unique_integer()}",
            site_id: site.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Equipment.create(%{
          name: "Test Equipment",
          equipment_type: :invalid_type,
          serial_number: "TEST - INVALID",
          site_id: site.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:equipment_type]
    end

    test "schedules maintenance", %{tenant: tenant, site: site} do
      equipment = insert(:equipment, tenant: tenant, site: site)

      maintenance_data = %{
        maintenance_type: "preventive",
        scheduled_date: Date.utc_today() |> Date.add(30),
        # 4 hours
        estimated_duration: 240,
        technician: "John Smith",
        description: "Quarterly HVAC filter replacement and inspection",
        priority: "routine"
      }

      {:ok, scheduled_equipment} = Equipment.schedule_maintenance(equipment, maintenance_data)

      assert scheduled_equipment.metadata["maintenance_schedule"]
      maintenance = List.first(scheduled_equipment.metadata["maintenance_schedule"])
      assert maintenance["type"] == "preventive"
      assert maintenance["technician"] == "John Smith"
      assert maintenance["priority"] == "routine"
    end

    test "tracks equipment status changes", %{tenant: tenant, site: site} do
      equipment = insert(:equipment, tenant: tenant, site: site, status: :operational)

      # Equipment goes offline
      {:ok, offline_equipment} =
        Equipment.update_status(equipment, %{
          status: :offline,
          status_reason: "System error detected",
          reported_by: "Facility Manager"
        })

      assert offline_equipment.status == :offline
      assert offline_equipment.metadata["status_history"]

      status_change = List.first(offline_equipment.metadata["status_history"])
      assert status_change["from_status"] == "operational"
      assert status_change["to_status"] == "offline"
      assert status_change["reason"] == "System error detected"

      # Equipment back online
      {:ok, online_equipment} =
        Equipment.update_status(offline_equipment, %{
          status: :operational,
          status_reason: "Repairs completed",
          reported_by: "Technician"
        })

      assert online_equipment.status == :operational
    end

    test "calculates equipment age and warranty status",
         %{tenant: tenant, site: site} do
      # Equipment under warranty
      under_warranty =
        insert(:equipment,
          tenant: tenant,
          site: site,
          # 1 year old
          installation_date: Date.utc_today() |> Date.add(-365),
          # 1 year left
          warranty_expiry: Date.utc_today() |> Date.add(365)
        )

      # Equipment out of warranty
      out_of_warranty =
        insert(:equipment,
          tenant: tenant,
          site: site,
          # ~7 years old
          installation_date: Date.utc_today() |> Date.add(-2555),
          # Expired 1 year ago
          warranty_expiry: Date.utc_today() |> Date.add(-365)
        )

      under_calc = Equipment.read!(under_warranty.id, load: [:age_in_years, :is_under_warranty?])
      out_calc = Equipment.read!(out_of_warranty.id, load: [:age_in_years, :is_under_warranty?])

      # ~1 year
      assert under_calc.age_in_years >= 0.9 && under_calc.age_in_years <= 1.1
      # ~7 years
      assert out_calc.age_in_years >= 6.5 && out_calc.age_in_years <= 7.5
      assert under_calc.is_under_warranty? == true
      assert out_calc.is_under_warranty? == false
    end

    test "enforces tenant isolation", %{site: site} do
      tenant1 = site.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: organization2)

      equipment1 = insert(:equipment, tenant: tenant1, site: site)
      equipment2 = insert(:equipment, tenant: tenant2, site: site2)

      tenant1_equipment = Equipment.read!(tenant: tenant1)
      tenant2_equipment = Equipment.read!(tenant: tenant2)

      assert length(tenant1_equipment) == 1
      assert length(tenant2_equipment) == 1
      assert Enum.any?(tenant1_equipment, &(&1.id == equipment1.id))
      assert Enum.any?(tenant2_equipment, &(&1.id == equipment2.id))
      refute Enum.any?(tenant1_equipment, &(&1.id == equipment2.id))
      refute Enum.any?(tenant2_equipment, &(&1.id == equipment1.id))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
