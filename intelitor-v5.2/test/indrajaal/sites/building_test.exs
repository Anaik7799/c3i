defmodule Indrajaal.Sites.BuildingTest do
  use Indrajaal.DataCase
  import Indrajaal.SitesComprehensiveFactory
  alias Indrajaal.Sites
  alias Indrajaal.Sites.Building

  describe "building creation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "creates building with valid attributes",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "Main Building",
        code: "MB - 001",
        building_type: "office",
        address: "123 Main St, Building A",
        floor_count: 5,
        total_area_sqft: 25_000,
        year_built: 2020,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:ok, building} = Sites.create_building(attrs)
      assert building.name == "Main Building"
      assert building.code == "MB - 001"
      assert building.building_type == "office"
      assert building.floor_count == 5
      assert building.site_id == site.id
      assert building.status == "operational"
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Sites.create_building(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
      assert error_msg =~ "code: is required"
      assert error_msg =~ "site_id: is required"
    end

    test "validates code uniqueness within site",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "Building 1",
        code: "BLD - 001",
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:ok, _building1} = Sites.create_building(attrs)
      assert {:error, error} = Sites.create_building(attrs)
      assert Exception.message(error) =~ "code: has already been taken"
    end

    test "allows same code across sites", %{tenant: tenant} do
      site1 = insert(:site, tenant_id: tenant.id)
      site2 = insert(:site, tenant_id: tenant.id)

      attrs1 = %{
        name: "Building A",
        code: "BLD - 001",
        site_id: site1.id,
        tenant_id: tenant.id
      }

      attrs2 = %{
        name: "Building B",
        code: "BLD - 001",
        site_id: site2.id,
        tenant_id: tenant.id
      }

      assert {:ok, building1} = Sites.create_building(attrs1)
      assert {:ok, building2} = Sites.create_building(attrs2)
      assert building1.code == building2.code
      assert building1.site_id != building2.site_id
    end

    test "validates building types", %{tenant: tenant, site: site} do
      valid_types = ["office", "industrial", "retail", "mixed_use", "residential", "warehouse"]

      for type <- valid_types do
        attrs = %{
          name: "#{String.capitalize(type)} Building",
          code: "#{String.upcase(type)}-001",
          building_type: type,
          site_id: site.id,
          tenant_id: tenant.id
        }

        assert {:ok, building} = Sites.create_building(attrs)
        assert building.building_type == type
      end
    end

    test "validates floor count", %{tenant: tenant, site: site} do
      # Valid floor count
      attrs = %{
        name: "Valid Floors",
        code: "VF - 001",
        floor_count: 10,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:ok, building} = Sites.create_building(attrs)
      assert building.floor_count == 10

      # Invalid floor count
      attrs = %{
        name: "Invalid Floors",
        code: "IF - 001",
        floor_count: -1,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, _} = Sites.create_building(attrs)
    end

    test "creates building with occupancy details",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "Occupancy Building",
        code: "OCC - 001",
        primary_use: "office_space",
        occupancy_type: "business",
        max_occupancy: 500,
        current_occupancy: 350,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:ok, building} = Sites.create_building(attrs)
      assert building.primary_use == "office_space"
      assert building.occupancy_type == "business"
      assert building.max_occupancy == 500
      assert building.current_occupancy == 350
    end

    test "creates building with accessibility features",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "Accessible Building",
        code: "ACC - 001",
        accessibility_compliant: true,
        has_parking: true,
        parking_spaces: 150,
        has_loading_dock: true,
        emergency_exits: 6,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:ok, building} = Sites.create_building(attrs)
      assert building.accessibility_compliant == true
      assert building.has_parking == true
      assert building.parking_spaces == 150
      assert building.has_loading_dock == true
      assert building.emergency_exits == 6
    end

    test "creates building with metadata", %{tenant: tenant, site: site} do
      metadata = %{
        "construction_material" => "steel",
        "roof_type" => "green",
        "hvac_system" => "geothermal",
        "energy_rating" => "A",
        "certifications" => ["LEED Platinum", "Energy Star"]
      }

      attrs = %{
        name: "Green Building",
        code: "GREEN - 001",
        metadata: metadata,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:ok, building} = Sites.create_building(attrs)
      assert building.metadata["energy_rating"] == "A"
      assert "LEED Platinum" in building.metadata["certifications"]
    end
  end

  describe "building updates" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site, building: building}
    end

    test "updates building details", %{building: building} do
      attrs = %{
        name: "Updated Building Name",
        floor_count: 8,
        total_area_sqft: 35_000
      }

      assert {:ok, updated} = Sites.update_building(building, attrs)
      assert updated.name == "Updated Building Name"
      assert updated.floor_count == 8
      assert updated.total_area_sqft == 35_000
    end

    test "updates occupancy", %{building: building} do
      attrs = %{
        current_occupancy: 400,
        max_occupancy: 600
      }

      assert {:ok, updated} = Sites.update_building(building, attrs)
      assert updated.current_occupancy == 400
      assert updated.max_occupancy == 600
    end

    test "validates occupancy limits", %{building: building} do
      # Set max occupancy first
      {:ok, building} = Sites.update_building(building, %{max_occupancy: 100})

      # Try to exceed max
      assert {:error, error} =
               Sites.update_building(building, %{
                 current_occupancy: 150
               })

      assert Exception.message(error) =~ "current occupancy exceeds maximum"
    end

    test "changes building status", %{building: building} do
      # Under maintenance
      assert {:ok, updated} =
               Sites.update_building(building, %{
                 status: "under_maintenance"
               })

      assert updated.status == "under_maintenance"

      # Back to operational
      assert {:ok, updated} =
               Sites.update_building(updated, %{
                 status: "operational"
               })

      assert updated.status == "operational"
    end

    test "prevents code change", %{building: building} do
      assert {:error, error} =
               Sites.update_building(building, %{
                 code: "NEW - CODE"
               })

      assert Exception.message(error) =~ "cannot change building code"
    end

    test "updates renovation info", %{building: building} do
      attrs = %{
        status: "under_renovation",
        metadata:
          Map.merge(building.metadata || %{}, %{
            "renovation_start" => "2025 - 07 - 31",
            "renovation_end" => "2025 - 07 - 31",
            "renovation_budget" => 1_000_000
          })
      }

      assert {:ok, updated} = Sites.update_building(building, attrs)
      assert updated.status == "under_renovation"
      assert updated.metadata["renovation_budget"] == 1_000_000
    end
  end

  describe "building queries" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 10)
      buildings = bulk_create_buildings(tenant, sites, 100)
      {:ok, tenant: tenant, sites: sites, buildings: buildings}
    end

    test "lists all buildings for tenant",
         %{tenant: tenant, buildings: buildings} do
      result = Sites.list_buildings!(tenant_id: tenant.id)
      assert length(result) >= length(buildings)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "lists buildings for site", %{sites: sites} do
      site = List.first(sites)

      buildings =
        Sites.list_buildings!(
          site_id: site.id,
          tenant_id: site.tenant_id
        )

      assert Enum.all?(buildings, &(&1.site_id == site.id))
    end

    test "filters by status", %{tenant: tenant} do
      operational =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          filter: [status: "operational"]
        )

      assert Enum.all?(operational, &(&1.status == "operational"))
    end

    test "filters by building type", %{tenant: tenant} do
      offices =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          filter: [building_type: "office"]
        )

      assert Enum.all?(offices, &(&1.building_type == "office"))
    end

    test "filters by floor count range", %{tenant: tenant} do
      high_rise =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          filter: [floor_count: {:>, 5}]
        )

      assert Enum.all?(high_rise, &(&1.floor_count > 5))
    end

    test "filters by year built", %{tenant: tenant} do
      modern =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          filter: [year_built: {:>=, 2020}]
        )

      assert Enum.all?(modern, &(&1.year_built >= 2020))
    end

    test "searches by name", %{tenant: tenant} do
      main_buildings =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%main%"}]
        )

      assert Enum.all?(main_buildings, &String.contains?(String.downcase(&1.name), "main"))
    end

    test "filters by accessibility", %{tenant: tenant} do
      accessible =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          filter: [accessibility_compliant: true]
        )

      assert Enum.all?(accessible, &(&1.accessibility_compliant == true))
    end

    test "sorts by name", %{tenant: tenant} do
      buildings =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          sort: [name: :asc]
        )

      names = Enum.map(buildings, & &1.name)
      assert names == Enum.sort(names)
    end

    test "sorts by floor count descending", %{tenant: tenant} do
      buildings =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          sort: [floor_count: :desc]
        )

      floor_counts = Enum.map(buildings, & &1.floor_count)
      assert floor_counts == Enum.sort(floor_counts, :desc)
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          page: [limit: 30, offset: 0]
        )

      page2 =
        Sites.list_buildings!(
          tenant_id: tenant.id,
          page: [limit: 30, offset: 30]
        )

      assert length(page1) == 30
      assert length(page2) >= 20

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "building statistics" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 10)
      buildings = bulk_create_buildings(tenant, sites, 100)
      {:ok, tenant: tenant, sites: sites, buildings: buildings}
    end

    test "counts buildings by type", %{tenant: tenant} do
      counts = Sites.count_buildings_by_type(tenant_id: tenant.id)

      assert counts["office"] > 0
      assert counts["industrial"] > 0

      total = Enum.sum(Map.values(counts))
      assert total >= 100
    end

    test "calculates total building area", %{tenant: tenant} do
      total_sqft = Sites.calculate_total_building_area(tenant_id: tenant.id)
      assert total_sqft > 0
    end

    test "calculates average building age", %{tenant: tenant} do
      avg_age = Sites.calculate_average_building_age(tenant_id: tenant.id)
      assert avg_age > 0
      # Reasonable age range
      assert avg_age < 100
    end

    test "identifies buildings needing maintenance", %{tenant: tenant} do
      # Create old building
      site = insert(:site, tenant_id: tenant.id)

      {:ok, old_building} =
        Sites.create_building(%{
          name: "Old Building",
          code: "OLD - 001",
          year_built: 1970,
          site_id: site.id,
          tenant_id: tenant.id,
          metadata: %{"last_major_renovation" => 1995}
        })

      maintenance_needed =
        Sites.find_buildings_needing_maintenance(
          tenant_id: tenant.id,
          age_threshold: 30
        )

      assert Enum.any?(maintenance_needed, &(&1.id == old_building.id))
    end

    test "calculates occupancy rates", %{tenant: tenant} do
      occupancy_stats = Sites.calculate_building_occupancy_rates(tenant_id: tenant.id)

      assert Map.has_key?(occupancy_stats, :average_occupancy_rate)
      assert Map.has_key?(occupancy_stats, :total_capacity)
      assert Map.has_key?(occupancy_stats, :total_occupied)
      assert occupancy_stats.average_occupancy_rate >= 0
      assert occupancy_stats.average_occupancy_rate <= 100
    end
  end

  describe "building capacity analysis" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "identifies over - capacity buildings", %{tenant: tenant, site: site} do
      # Create over - capacity building
      {:ok, crowded} =
        Sites.create_building(%{
          name: "Crowded Building",
          code: "CROWD - 001",
          max_occupancy: 100,
          current_occupancy: 95,
          site_id: site.id,
          tenant_id: tenant.id
        })

      over_capacity =
        Sites.find_buildings_near_capacity(
          tenant_id: tenant.id,
          threshold_percentage: 90
        )

      assert Enum.any?(over_capacity, &(&1.id == crowded.id))
    end

    test "finds available capacity", %{tenant: tenant, site: site} do
      # Create building with capacity
      {:ok, available} =
        Sites.create_building(%{
          name: "Available Building",
          code: "AVAIL - 001",
          max_occupancy: 200,
          current_occupancy: 50,
          site_id: site.id,
          tenant_id: tenant.id
        })

      available_buildings =
        Sites.find_buildings_with_capacity(
          tenant_id: tenant.id,
          min_available_spaces: 100
        )

      assert Enum.any?(available_buildings, &(&1.id == available.id))
    end

    test "analyzes parking utilization", %{tenant: tenant, site: site} do
      # Create buildings with parking
      {:ok, _} =
        Sites.create_building(%{
          name: "Parking Building 1",
          code: "PARK - 001",
          has_parking: true,
          parking_spaces: 200,
          current_occupancy: 150,
          site_id: site.id,
          tenant_id: tenant.id
        })

      {:ok, _} =
        Sites.create_building(%{
          name: "Parking Building 2",
          code: "PARK - 002",
          has_parking: true,
          parking_spaces: 100,
          current_occupancy: 120,
          site_id: site.id,
          tenant_id: tenant.id
        })

      parking_stats = Sites.analyze_parking_utilization(site_id: site.id)

      assert parking_stats.total_parking_spaces == 300
      # 150 + 120
      assert parking_stats.estimated_parking_demand == 270
      assert parking_stats.utilization_rate > 0
    end
  end

  describe "building compliance" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "identifies non - compliant buildings", %{tenant: tenant, site: site} do
      # Create non - compliant building
      {:ok, non_compliant} =
        Sites.create_building(%{
          name: "Non - Compliant Building",
          code: "NC - 001",
          accessibility_compliant: false,
          # Too few
          emergency_exits: 1,
          site_id: site.id,
          tenant_id: tenant.id
        })

      compliance_issues =
        Sites.find_compliance_issues(
          tenant_id: tenant.id,
          check_accessibility: true,
          min_emergency_exits: 2
        )

      assert Enum.any?(compliance_issues, &(&1.building_id == non_compliant.id))
    end

    test "validates fire safety requirements", %{tenant: tenant, site: site} do
      # High-rise requires more exits
      attrs = %{
        name: "High Rise",
        code: "HR - 001",
        floor_count: 20,
        # Too few for high - rise
        emergency_exits: 2,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_building(attrs)
      assert Exception.message(error) =~ "insufficient emergency exits
        for building size"
    end

    test "tracks inspection dates", %{tenant: tenant, site: site} do
      {:ok, building} =
        Sites.create_building(%{
          name: "Inspected Building",
          code: "INSP - 001",
          site_id: site.id,
          tenant_id: tenant.id,
          metadata: %{
            "last_fire_inspection" => Date.add(Date.utc_today(), -300),
            "last_safety_inspection" => Date.add(Date.utc_today(), -200),
            "last_structural_inspection" => Date.add(Date.utc_today(), -700)
          }
        })

      overdue =
        Sites.find_buildings_needing_inspection(
          tenant_id: tenant.id,
          fire_inspection_interval_days: 365,
          safety_inspection_interval_days: 180
        )

      assert Enum.any?(overdue, &(&1.id == building.id))
    end
  end

  describe "bulk operations" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "bulk creates buildings", %{tenant: tenant} do
      sites = bulk_create_sites(tenant, 5)
      buildings = bulk_create_buildings(tenant, sites, 50)

      assert length(buildings) >= 50
      assert Enum.all?(buildings, &(&1.tenant_id == tenant.id))

      # Verify distribution
      by_type = Enum.group_by(buildings, & &1.building_type)
      assert map_size(by_type) >= 3
    end

    test "bulk updates building status", %{tenant: tenant, site: site} do
      buildings =
        for i <- 1..5 do
          {:ok, building} =
            Sites.create_building(%{
              name: "Building #{i}",
              code: "BLD-#{i}",
              site_id: site.id,
              tenant_id: tenant.id
            })

          building
        end

      building_ids = Enum.map(buildings, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_buildings(
                 filter: [id: {:in, building_ids}],
                 attributes: %{status: "under_maintenance"}
               )

      assert count == 5

      # Verify update
      updated = Sites.list_buildings!(filter: [id: {:in, building_ids}])
      assert Enum.all?(updated, &(&1.status == "under_maintenance"))
    end

    test "bulk assigns energy ratings", %{tenant: tenant, site: site} do
      buildings =
        for i <- 1..10 do
          {:ok, building} =
            Sites.create_building(%{
              name: "Energy Building #{i}",
              code: "ENERGY-#{i}",
              site_id: site.id,
              tenant_id: tenant.id
            })

          building
        end

      building_ids = Enum.map(buildings, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_buildings(
                 filter: [id: {:in, building_ids}],
                 attributes: %{
                   metadata: %{"energy_rating" => "B", "rating_date" => Date.utc_today()}
                 }
               )

      assert count == 10
    end
  end

  describe "building validation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site}
    end

    test "validates area calculations", %{tenant: tenant, site: site} do
      # Floor count and area must be realistic
      attrs = %{
        name: "Impossible Building",
        code: "IMP - 001",
        floor_count: 2,
        # Too large for 2 floors
        total_area_sqft: 1_000_000,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_building(attrs)
      assert Exception.message(error) =~ "unrealistic floor area"
    end

    test "validates parking ratio", %{tenant: tenant, site: site} do
      # Parking spaces should be reasonable for occupancy
      attrs = %{
        name: "Bad Parking",
        code: "PARK - 001",
        max_occupancy: 1000,
        # Too few
        parking_spaces: 10,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_building(attrs)
      assert Exception.message(error) =~ "insufficient parking for occupancy"
    end

    test "validates year built", %{tenant: tenant, site: site} do
      # Future year
      attrs = %{
        name: "Future Building",
        code: "FUT - 001",
        year_built: Date.utc_today().year + 1,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_building(attrs)
      assert Exception.message(error) =~ "year built cannot be in the future"

      # Too old
      attrs = %{
        name: "Ancient Building",
        code: "ANC - 001",
        year_built: 1800,
        site_id: site.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_building(attrs)
      assert Exception.message(error) =~ "year built unrealistic"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
