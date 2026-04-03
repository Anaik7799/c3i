defmodule Indrajaal.Sites.FloorTest do
  use Indrajaal.DataCase
  import Indrajaal.SitesComprehensiveFactory
  alias Indrajaal.Sites.Floor
  alias Indrajaal.Sites

  describe "floor creation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site, building: building}
    end

    test "creates floor with valid attributes",
         %{tenant: tenant, building: building} do
      attrs = %{
        name: "1st Floor",
        floor_number: 1,
        floor_type: "standard",
        area_sqft: 5000,
        ceiling_height_ft: 10.0,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, floor} = Sites.create_floor(attrs)
      assert floor.name == "1st Floor"
      assert floor.floor_number == 1
      assert floor.floor_type == "standard"
      assert floor.area_sqft == 5000
      assert floor.building_id == building.id
      assert floor.status == "operational"
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Sites.create_floor(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
      assert error_msg =~ "floor_number: is required"
      assert error_msg =~ "building_id: is required"
    end

    test "validates floor number uniqueness within building", %{
      tenant: tenant,
      building: building
    } do
      attrs = %{
        name: "Floor 1",
        floor_number: 1,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, _floor1} = Sites.create_floor(attrs)

      # Try to create another floor with same number
      attrs2 = Map.put(attrs, :name, "Another Floor 1")
      assert {:error, error} = Sites.create_floor(attrs2)
      assert Exception.message(error) =~ "floor_number: has already been taken"
    end

    test "allows same floor number across buildings",
         %{tenant: tenant, site: site} do
      building1 = insert(:building, site_id: site.id, tenant_id: tenant.id)
      building2 = insert(:building, site_id: site.id, tenant_id: tenant.id)

      attrs1 = %{
        name: "1st Floor",
        floor_number: 1,
        building_id: building1.id,
        tenant_id: tenant.id
      }

      attrs2 = %{
        name: "1st Floor",
        floor_number: 1,
        building_id: building2.id,
        tenant_id: tenant.id
      }

      assert {:ok, floor1} = Sites.create_floor(attrs1)
      assert {:ok, floor2} = Sites.create_floor(attrs2)
      assert floor1.floor_number == floor2.floor_number
      assert floor1.building_id != floor2.building_id
    end

    test "validates floor types", %{tenant: tenant, building: building} do
      valid_types = [
        "basement",
        "ground",
        "standard",
        "mezzanine",
        "penthouse",
        "mechanical",
        "roof"
      ]

      for type <- valid_types do
        attrs = %{
          name: "#{String.capitalize(type)} Floor",
          floor_number: Enum.random(1..10),
          floor_type: type,
          building_id: building.id,
          tenant_id: tenant.id
        }

        assert {:ok, floor} = Sites.create_floor(attrs)
        assert floor.floor_type == type
      end
    end

    test "creates basement floors with negative numbers",
         %{tenant: tenant, building: building} do
      attrs = %{
        name: "Basement Level 1",
        floor_number: -1,
        floor_type: "basement",
        area_sqft: 5000,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, floor} = Sites.create_floor(attrs)
      assert floor.floor_number == -1
      assert floor.floor_type == "basement"
    end

    test "creates floor with accessibility features",
         %{tenant: tenant, building: building} do
      attrs = %{
        name: "Accessible Floor",
        floor_number: 1,
        is_accessible: true,
        has_elevator_access: true,
        has_stair_access: true,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, floor} = Sites.create_floor(attrs)
      assert floor.is_accessible == true
      assert floor.has_elevator_access == true
      assert floor.has_stair_access == true
    end

    test "creates floor with occupancy limits",
         %{tenant: tenant, building: building} do
      attrs = %{
        name: "Office Floor",
        floor_number: 3,
        occupancy_limit: 150,
        current_occupancy: 75,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, floor} = Sites.create_floor(attrs)
      assert floor.occupancy_limit == 150
      assert floor.current_occupancy == 75
    end

    test "creates floor with metadata", %{tenant: tenant, building: building} do
      metadata = %{
        "fire_exits" => 4,
        "restrooms" => 2,
        "emergency_equipment" => ["fire_extinguisher", "first_aid", "aed", "emergency_phone"],
        "hvac_zones" => 3,
        "renovation_year" => 2023
      }

      attrs = %{
        name: "Modern Floor",
        floor_number: 5,
        metadata: metadata,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, floor} = Sites.create_floor(attrs)
      assert floor.metadata["fire_exits"] == 4
      assert "aed" in floor.metadata["emergency_equipment"]
    end
  end

  describe "floor updates" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, building: building, floor: floor}
    end

    test "updates floor details", %{floor: floor} do
      attrs = %{
        name: "Updated Floor Name",
        area_sqft: 6000,
        ceiling_height_ft: 12.0
      }

      assert {:ok, updated} = Sites.update_floor(floor, attrs)
      assert updated.name == "Updated Floor Name"
      assert updated.area_sqft == 6000
      assert updated.ceiling_height_ft == 12.0
    end

    test "updates occupancy", %{floor: floor} do
      # Set limit first
      {:ok, floor} = Sites.update_floor(floor, %{occupancy_limit: 100})

      # Update current occupancy
      assert {:ok, updated} = Sites.update_floor(floor, %{current_occupancy: 80})
      assert updated.current_occupancy == 80

      # Try to exceed limit
      assert {:error, error} = Sites.update_floor(floor, %{current_occupancy: 120})
      assert Exception.message(error) =~ "current occupancy exceeds limit"
    end

    test "updates accessibility status", %{floor: floor} do
      attrs = %{
        is_accessible: true,
        has_elevator_access: true
      }

      assert {:ok, updated} = Sites.update_floor(floor, attrs)
      assert updated.is_accessible == true
      assert updated.has_elevator_access == true
    end

    test "changes floor status", %{floor: floor} do
      # Under renovation
      assert {:ok, updated} = Sites.update_floor(floor, %{status: "under_renovation"})
      assert updated.status == "under_renovation"

      # Back to operational
      assert {:ok, updated} = Sites.update_floor(updated, %{status: "operational"})
      assert updated.status == "operational"
    end

    test "prevents floor number change", %{floor: floor} do
      assert {:error, error} = Sites.update_floor(floor, %{floor_number: 99})
      assert Exception.message(error) =~ "cannot change floor number"
    end

    test "updates emergency information", %{floor: floor} do
      metadata =
        Map.merge(floor.metadata || %{}, %{
          "fire_exits" => 6,
          "emergency_assembly_point" => "North parking lot",
          "evacuation_capacity" => 200
        })

      assert {:ok, updated} = Sites.update_floor(floor, %{metadata: metadata})
      assert updated.metadata["fire_exits"] == 6
      assert updated.metadata["emergency_assembly_point"] == "North parking lot"
    end
  end

  describe "floor queries" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 5)
      buildings = bulk_create_buildings(tenant, sites, 20)
      floors = bulk_create_floors(tenant, buildings, 200)
      {:ok, tenant: tenant, buildings: buildings, floors: floors}
    end

    test "lists all floors for tenant", %{tenant: tenant, floors: floors} do
      result = Sites.list_floors!(tenant_id: tenant.id)
      assert length(result) >= length(floors)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "lists floors for building", %{buildings: buildings} do
      building = List.first(buildings)

      floors =
        Sites.list_floors!(
          building_id: building.id,
          tenant_id: building.tenant_id
        )

      assert Enum.all?(floors, &(&1.building_id == building.id))
      assert length(floors) > 0
    end

    test "filters by floor type", %{tenant: tenant} do
      basement_floors =
        Sites.list_floors!(
          tenant_id: tenant.id,
          filter: [floor_type: "basement"]
        )

      assert Enum.all?(basement_floors, &(&1.floor_type == "basement"))
    end

    test "filters by status", %{tenant: tenant} do
      operational =
        Sites.list_floors!(
          tenant_id: tenant.id,
          filter: [status: "operational"]
        )

      assert Enum.all?(operational, &(&1.status == "operational"))
    end

    test "filters by accessibility", %{tenant: tenant} do
      accessible =
        Sites.list_floors!(
          tenant_id: tenant.id,
          filter: [is_accessible: true]
        )

      assert Enum.all?(accessible, &(&1.is_accessible == true))
    end

    test "filters by elevator access", %{tenant: tenant} do
      with_elevator =
        Sites.list_floors!(
          tenant_id: tenant.id,
          filter: [has_elevator_access: true]
        )

      assert Enum.all?(with_elevator, &(&1.has_elevator_access == true))
    end

    test "sorts by floor number", %{buildings: buildings} do
      building = List.first(buildings)

      floors =
        Sites.list_floors!(
          building_id: building.id,
          tenant_id: building.tenant_id,
          sort: [floor_number: :asc]
        )

      floor_numbers = Enum.map(floors, & &1.floor_number)
      assert floor_numbers == Enum.sort(floor_numbers)
    end

    test "filters by area range", %{tenant: tenant} do
      large_floors =
        Sites.list_floors!(
          tenant_id: tenant.id,
          filter: [area_sqft: {:>, 10_000}]
        )

      assert Enum.all?(large_floors, &(&1.area_sqft > 10_000))
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Sites.list_floors!(
          tenant_id: tenant.id,
          page: [limit: 50, offset: 0]
        )

      page2 =
        Sites.list_floors!(
          tenant_id: tenant.id,
          page: [limit: 50, offset: 50]
        )

      assert length(page1) == 50
      assert length(page2) >= 30

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "floor statistics" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)

      floors =
        for i <- 1..10 do
          insert(:floor,
            name: "Floor #{i}",
            floor_number: i,
            area_sqft: 5000,
            building_id: building.id,
            tenant_id: tenant.id
          )
        end

      {:ok, tenant: tenant, building: building, floors: floors}
    end

    test "calculates total floor area for building", %{building: building} do
      total_area = Sites.calculate_total_floor_area(building_id: building.id)
      # 10 floors * 5000 sqft
      assert total_area == 50_000
    end

    test "calculates building occupancy", %{building: building} do
      occupancy = Sites.calculate_building_occupancy(building_id: building.id)

      # 10 floors * 100
      assert occupancy.total_capacity == 1000
      assert occupancy.current_occupancy > 500
      assert occupancy.occupancy_rate > 50
    end

    test "identifies crowded floors", %{building: building} do
      # Create a crowded floor
      {:ok, crowded} =
        Sites.create_floor(%{
          name: "Crowded Floor",
          floor_number: 11,
          occupancy_limit: 100,
          current_occupancy: 95,
          building_id: building.id,
          tenant_id: building.tenant_id
        })

      crowded_floors =
        Sites.find_crowded_floors(
          building_id: building.id,
          threshold_percentage: 90
        )

      assert Enum.any?(crowded_floors, &(&1.id == crowded.id))
    end

    test "analyzes floor utilization patterns", %{building: building} do
      patterns = Sites.analyze_floor_utilization(building_id: building.id)

      assert Map.has_key?(patterns, :average_utilization)
      assert Map.has_key?(patterns, :peak_floors)
      assert Map.has_key?(patterns, :underutilized_floors)
      assert patterns.average_utilization > 0
    end
  end

  describe "floor safety and compliance" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, building: building}
    end

    test "validates emergency exit requirements",
         %{tenant: tenant, building: building} do
      # Large floor needs multiple exits
      attrs = %{
        name: "Large Floor",
        floor_number: 1,
        area_sqft: 20_000,
        occupancy_limit: 500,
        building_id: building.id,
        tenant_id: tenant.id,
        # Too few for occupancy
        metadata: %{"fire_exits" => 2}
      }

      assert {:error, error} = Sites.create_floor(attrs)
      assert Exception.message(error) =~ "insufficient emergency exits"
    end

    test "tracks safety equipment", %{tenant: tenant, building: building} do
      {:ok, floor} =
        Sites.create_floor(%{
          name: "Safety Floor",
          floor_number: 1,
          building_id: building.id,
          tenant_id: tenant.id,
          metadata: %{
            "fire_extinguishers" => 10,
            "emergency_phones" => 4,
            "aed_locations" => ["North hallway", "South hallway"],
            "fire_alarm_panels" => 2
          }
        })

      safety_compliant = Sites.check_floor_safety_compliance(floor.id)
      assert safety_compliant == true
    end

    test "identifies floors needing inspection",
         %{tenant: tenant, building: building} do
      {:ok, floor} =
        Sites.create_floor(%{
          name: "Old Floor",
          floor_number: 1,
          building_id: building.id,
          tenant_id: tenant.id,
          metadata: %{
            "last_inspection" => Date.add(Date.utc_today(), -400)
          }
        })

      needs_inspection =
        Sites.find_floors_needing_inspection(
          tenant_id: tenant.id,
          inspection_interval_days: 365
        )

      assert Enum.any?(needs_inspection, &(&1.id == floor.id))
    end
  end

  describe "floor navigation and wayfinding" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)

      floors =
        for i <- 1..10 do
          insert(:floor,
            name: "Floor #{i}",
            floor_number: i,
            building_id: building.id,
            tenant_id: tenant.id,
            has_elevator_access: rem(i, 2) == 0,
            has_stairs_access: true
          )
        end

      {:ok, tenant: tenant, building: building, floors: floors}
    end

    test "finds accessible route between floors", %{floors: floors} do
      floor1 = Enum.at(floors, 0)
      floor3 = Enum.at(floors, 2)

      route =
        Sites.find_accessible_route(
          from_floor_id: floor1.id,
          to_floor_id: floor3.id,
          requires_wheelchair_access: true
        )

      assert route.method == "elevator"
      assert route.accessible == true
    end

    test "calculates evacuation routes", %{building: building} do
      routes = Sites.calculate_evacuation_routes(building_id: building.id)

      assert length(routes) > 0
      assert Enum.all?(routes, &(&1.exit_type in ["stair", "elevator", "emergency"]))
    end

    test "identifies floors with limited access",
         %{tenant: tenant, building: building} do
      # Create floor with only stair access
      {:ok, limited} =
        Sites.create_floor(%{
          name: "Limited Access Floor",
          floor_number: 6,
          has_elevator_access: false,
          has_stair_access: true,
          building_id: building.id,
          tenant_id: tenant.id
        })

      limited_access = Sites.find_limited_access_floors(building_id: building.id)
      assert Enum.any?(limited_access, &(&1.id == limited.id))
    end
  end

  describe "bulk floor operations" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, building: building}
    end

    test "bulk creates floors for building",
         %{tenant: tenant, building: building} do
      floors =
        for i <- 1..10 do
          %{
            name: "Floor #{i}",
            floor_number: i,
            area_sqft: 5000,
            building_id: building.id,
            tenant_id: tenant.id
          }
        end

      assert {:ok, created} = Sites.bulk_create_floors(floors)
      assert length(created) == 10
    end

    test "bulk updates floor status", %{tenant: tenant, building: building} do
      floors =
        for i <- 1..5 do
          insert(:floor,
            floor_number: i,
            building_id: building.id,
            tenant_id: tenant.id
          )
        end

      floor_ids = Enum.map(floors, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_floors(
                 filter: [id: {:in, floor_ids}],
                 attributes: %{status: "under_maintenance"}
               )

      assert count == 5

      # Verify update
      updated = Sites.list_floors!(filter: [id: {:in, floor_ids}])
      assert Enum.all?(updated, &(&1.status == "under_maintenance"))
    end

    test "bulk updates accessibility features",
         %{tenant: tenant, building: building} do
      # Create floors
      floors =
        for i <- 1..5 do
          insert(:floor,
            floor_number: i,
            building_id: building.id,
            tenant_id: tenant.id,
            is_accessible: false
          )
        end

      floor_ids = Enum.map(floors, & &1.id)

      # Add elevator access
      assert {:ok, count} =
               Sites.bulk_update_floors(
                 filter: [id: {:in, floor_ids}],
                 attributes: %{
                   is_accessible: true,
                   has_elevator_access: true,
                   metadata: %{"accessibility_upgrade" => Date.utc_today()}
                 }
               )

      assert count == 5
    end
  end

  describe "floor validation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id, floor_count: 5)
      {:ok, tenant: tenant, building: building}
    end

    test "validates floor number within building limits",
         %{tenant: tenant, building: building} do
      # Valid floor number
      attrs = %{
        name: "Valid Floor",
        floor_number: 3,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_floor(attrs)

      # Floor number too high
      attrs = %{
        name: "Invalid Floor",
        # Building only has 5 floors
        floor_number: 10,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_floor(attrs)
      assert Exception.message(error) =~ "floor number exceeds building
        floor count"
    end

    test "validates area against building footprint",
         %{tenant: tenant, building: building} do
      # Set building area
      {:ok, building} = Sites.update_building(building, %{total_area_sqft: 50_000})

      # Floor area too large
      attrs = %{
        name: "Huge Floor",
        floor_number: 1,
        # Too large for 5-floor building
        area_sqft: 15_000,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_floor(attrs)
      assert Exception.message(error) =~ "floor area exceeds reasonable
        building footprint"
    end

    test "validates ceiling height by floor type",
         %{tenant: tenant, building: building} do
      # Basement with high ceiling
      attrs = %{
        name: "Tall Basement",
        floor_number: -1,
        floor_type: "basement",
        # Unusually high for basement
        ceiling_height_ft: 20.0,
        building_id: building.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_floor(attrs)
      assert Exception.message(error) =~ "unusual ceiling height for floor type"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
