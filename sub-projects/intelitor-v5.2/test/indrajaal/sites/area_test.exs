defmodule Indrajaal.Sites.AreaTest do
  use Indrajaal.DataCase
  import Indrajaal.SitesComprehensiveFactory
  import Indrajaal.AccountsFixtures
  alias Indrajaal.Sites.Area
  alias Indrajaal.Sites

  describe "area creation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, site: site, building: building, floor: floor}
    end

    test "creates area with valid attributes",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Open Office Area",
        code: "OOA-001",
        area_type: "office",
        area_sqft: 2500,
        occupancy_limit: 50,
        access_level: "employee",
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.name == "Open Office Area"
      assert area.code == "OOA-001"
      assert area.area_type == "office"
      assert area.area_sqft == 2500
      assert area.floor_id == floor.id
      assert area.status == "active"
    end

    test "validates __required fields", %{tenant: tenant} do
      assert {:error, error} = Sites.create_area(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is __required"
      assert error_msg =~ "code: is __required"
      assert error_msg =~ "floor_id: is __required"
    end

    test "validates code uniqueness within floor",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Area 1",
        code: "AREA-001",
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, _area1} = Sites.create_area(attrs)

      # Try to create another area with same code
      attrs2 = Map.put(attrs, :name, "Area 2")
      assert {:error, error} = Sites.create_area(attrs2)
      assert Exception.message(error) =~ "code: has already been taken"
    end

    test "allows same code across floors",
         %{tenant: tenant, building: building} do
      floor1 = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      floor2 = insert(:floor, building_id: building.id, tenant_id: tenant.id, floor_number: 2)

      attrs1 = %{
        name: "Conference Area",
        code: "CONF-001",
        floor_id: floor1.id,
        tenant_id: tenant.id
      }

      attrs2 = %{
        name: "Conference Area",
        code: "CONF-001",
        floor_id: floor2.id,
        tenant_id: tenant.id
      }

      assert {:ok, area1} = Sites.create_area(attrs1)
      assert {:ok, area2} = Sites.create_area(attrs2)
      assert area1.code == area2.code
      assert area1.floor_id != area2.floor_id
    end

    test "validates area types", %{tenant: tenant, floor: floor} do
      valid_types = [
        "office",
        "conference",
        "lobby",
        "storage",
        "mechanical",
        "restroom",
        "kitchen",
        "amenity",
        "security",
        "retail"
      ]

      for type <- valid_types do
        attrs = %{
          name: "#{String.capitalize(type)} Area",
          code: "#{String.upcase(type)}-001",
          area_type: type,
          floor_id: floor.id,
          tenant_id: tenant.id
        }

        assert {:ok, area} = Sites.create_area(attrs)
        assert area.area_type == type
      end
    end

    test "validates access levels", %{tenant: tenant, floor: floor} do
      valid_levels = ["public", "employee", "restricted", "maintenance", "security", "executive"]

      for level <- valid_levels do
        attrs = %{
          name: "#{String.capitalize(level)} Access Area",
          code: "#{String.upcase(level)}-001",
          access_level: level,
          floor_id: floor.id,
          tenant_id: tenant.id
        }

        assert {:ok, area} = Sites.create_area(attrs)
        assert area.access_level == level
      end
    end

    test "creates secure area", %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Server Room",
        code: "SRV-001",
        area_type: "mechanical",
        access_level: "restricted",
        is_secure: true,
        climate_controlled: true,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.is_secure == true
      assert area.climate_controlled == true
      assert area.access_level == "restricted"
    end

    test "creates area with occupancy details",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Conference Room A",
        code: "CONF-A",
        area_type: "conference",
        area_sqft: 500,
        occupancy_limit: 20,
        current_occupancy: 5,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.occupancy_limit == 20
      assert area.current_occupancy == 5
    end

    test "creates area with environmental controls",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Data Center Area",
        code: "DC-001",
        area_type: "mechanical",
        climate_controlled: true,
        has_windows: false,
        natural_light: false,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.climate_controlled == true
      assert area.has_windows == false
      assert area.natural_light == false
    end

    test "creates area with metadata", %{tenant: tenant, floor: floor} do
      metadata = %{
        "equipment" => ["av_system", "whiteboard", "video_conferencing"],
        "amenities" => ["coffee", "water_fountain"],
        "booking_enabled" => true,
        "max_booking_duration" => 4,
        "special_requirements" => ["badge_access", "training_required"]
      }

      attrs = %{
        name: "Executive Conference",
        code: "EXEC-CONF",
        area_type: "conference",
        metadata: metadata,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.metadata["booking_enabled"] == true
      assert "av_system" in area.metadata["equipment"]
    end
  end

  describe "area updates" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, floor: floor, area: area}
    end

    test "updates area details", %{area: area} do
      attrs = %{
        name: "Updated Area Name",
        area_sqft: 3000,
        occupancy_limit: 60
      }

      assert {:ok, updated} = Sites.update_area(area, attrs)
      assert updated.name == "Updated Area Name"
      assert updated.area_sqft == 3000
      assert updated.occupancy_limit == 60
    end

    test "updates access level", %{area: area} do
      assert {:ok, updated} = Sites.update_area(area, %{access_level: "restricted"})
      assert updated.access_level == "restricted"
    end

    test "updates occupancy", %{area: area} do
      # Set limit first
      {:ok, area} = Sites.update_area(area, %{occupancy_limit: 50})

      # Update current occupancy
      assert {:ok, updated} = Sites.update_area(area, %{current_occupancy: 40})
      assert updated.current_occupancy == 40

      # Try to exceed limit
      assert {:error, error} = Sites.update_area(area, %{current_occupancy: 60})
      assert Exception.message(error) =~ "current occupancy exceeds limit"
    end

    test "changes area status", %{area: area} do
      # Under maintenance
      assert {:ok, updated} = Sites.update_area(area, %{status: "maintenance"})
      assert updated.status == "maintenance"

      # Back to active
      assert {:ok, updated} = Sites.update_area(updated, %{status: "active"})
      assert updated.status == "active"
    end

    test "pr__events code change", %{area: area} do
      assert {:error, error} = Sites.update_area(area, %{code: "NEW-CODE"})
      assert Exception.message(error) =~ "cannot change area code"
    end

    test "updates security settings", %{area: area} do
      attrs = %{
        is_secure: true,
        access_level: "restricted",
        metadata:
          Map.merge(area.metadata || %{}, %{
            "badge_readers" => ["entry", "exit"],
            "cameras" => 4,
            "motion_sensors" => true
          })
      }

      assert {:ok, updated} = Sites.update_area(area, attrs)
      assert updated.is_secure == true
      assert updated.access_level == "restricted"
      assert updated.metadata["cameras"] == 4
    end

    test "updates environmental settings", %{area: area} do
      attrs = %{
        climate_controlled: true,
        metadata:
          Map.merge(area.metadata || %{}, %{
            "temperature_setpoint" => 72,
            "humidity_control" => true,
            "air_changes_per_hour" => 6
          })
      }

      assert {:ok, updated} = Sites.update_area(area, attrs)
      assert updated.climate_controlled == true
      assert updated.metadata["temperature_setpoint"] == 72
    end
  end

  describe "area queries" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 5)
      buildings = bulk_create_buildings(tenant, sites, 20)
      floors = bulk_create_floors(tenant, buildings, 100)
      areas = bulk_create_areas(tenant, floors, 300)
      {:ok, tenant: tenant, floors: floors, areas: areas}
    end

    test "lists all areas for tenant", %{tenant: tenant, areas: areas} do
      result = Sites.list_areas!(tenant_id: tenant.id)
      assert length(result) >= length(areas)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "lists areas for floor", %{floors: floors} do
      floor = List.first(floors)

      areas =
        Sites.list_areas!(
          floor_id: floor.id,
          tenant_id: floor.tenant_id
        )

      assert Enum.all?(areas, &(&1.floor_id == floor.id))
      assert length(areas) > 0
    end

    test "filters by area type", %{tenant: tenant} do
      offices =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [area_type: "office"]
        )

      assert Enum.all?(offices, &(&1.area_type == "office"))
      assert length(offices) > 0
    end

    test "filters by access level", %{tenant: tenant} do
      restricted =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [access_level: "restricted"]
        )

      assert Enum.all?(restricted, &(&1.access_level == "restricted"))
    end

    test "filters by status", %{tenant: tenant} do
      active =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [status: "active"]
        )

      assert Enum.all?(active, &(&1.status == "active"))
    end

    test "filters secure areas", %{tenant: tenant} do
      secure =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [is_secure: true]
        )

      assert Enum.all?(secure, &(&1.is_secure == true))
    end

    test "filters climate controlled areas", %{tenant: tenant} do
      climate_controlled =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [climate_controlled: true]
        )

      assert Enum.all?(climate_controlled, &(&1.climate_controlled == true))
    end

    test "filters by area size", %{tenant: tenant} do
      large_areas =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [area_sqft: {:>, 5000}]
        )

      assert Enum.all?(large_areas, &(&1.area_sqft > 5000))
    end

    test "searches by name", %{tenant: tenant} do
      conference_areas =
        Sites.list_areas!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%conference%"}]
        )

      assert Enum.all?(
               conference_areas,
               &String.contains?(String.downcase(&1.name), "conference")
             )
    end

    test "sorts by name", %{tenant: tenant} do
      areas =
        Sites.list_areas!(
          tenant_id: tenant.id,
          sort: [name: :asc]
        )

      names = Enum.map(areas, & &1.name)
      assert names == Enum.sort(names)
    end

    test "sorts by area size", %{tenant: tenant} do
      areas =
        Sites.list_areas!(
          tenant_id: tenant.id,
          sort: [area_sqft: :desc]
        )

      sizes = Enum.map(areas, & &1.area_sqft)
      assert sizes == Enum.sort(sizes, :desc)
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Sites.list_areas!(
          tenant_id: tenant.id,
          page: [limit: 50, offset: 0]
        )

      page2 =
        Sites.list_areas!(
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

  describe "area statistics" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)

      areas =
        for i <- 1..10 do
          insert(:area,
            name: "Area #{i}",
            area_sqft: 1000,
            floor_id: floor.id,
            tenant_id: tenant.id
          )
        end

      {:ok, tenant: tenant, floor: floor, areas: areas}
    end

    test "calculates total area for floor", %{floor: floor} do
      total_sqft = Sites.calculate_total_area_sqft(floor_id: floor.id)
      assert total_sqft > 0
    end

    test "counts areas by type", %{floor: floor} do
      counts = Sites.count_areas_by_type(floor_id: floor.id)

      assert is_map(counts)
      assert Map.has_key?(counts, "office")
      assert Map.has_key?(counts, "conference")
    end

    test "calculates floor occupancy", %{floor: floor} do
      occupancy = Sites.calculate_floor_area_occupancy(floor_id: floor.id)

      assert Map.has_key?(occupancy, :total_capacity)
      assert Map.has_key?(occupancy, :current_occupancy)
      assert Map.has_key?(occupancy, :occupancy_rate)
      assert occupancy.occupancy_rate >= 0
      assert occupancy.occupancy_rate <= 100
    end

    test "identifies crowded areas", %{floor: floor, tenant: tenant} do
      # Create a crowded area
      {:ok, crowded} =
        Sites.create_area(%{
          name: "Crowded Conference",
          code: "CROWD-001",
          occupancy_limit: 20,
          current_occupancy: 19,
          floor_id: floor.id,
          tenant_id: tenant.id
        })

      crowded_areas =
        Sites.find_crowded_areas(
          floor_id: floor.id,
          threshold_percentage: 90
        )

      assert Enum.any?(crowded_areas, &(&1.id == crowded.id))
    end

    test "finds available conference rooms", %{floor: floor, tenant: tenant} do
      # Create available conference room
      {:ok, available} =
        Sites.create_area(%{
          name: "Available Conference",
          code: "AVAIL-001",
          area_type: "conference",
          occupancy_limit: 12,
          current_occupancy: 0,
          floor_id: floor.id,
          tenant_id: tenant.id
        })

      available_rooms =
        Sites.find_available_conference_rooms(
          floor_id: floor.id,
          min_capacity: 10
        )

      assert Enum.any?(available_rooms, &(&1.id == available.id))
    end

    test "analyzes area utilization", %{floor: floor} do
      utilization = Sites.analyze_area_utilization(floor_id: floor.id)

      assert Map.has_key?(utilization, :by_type)
      assert Map.has_key?(utilization, :average_occupancy_rate)
      assert Map.has_key?(utilization, :peak_areas)
      assert Map.has_key?(utilization, :underutilized_areas)
    end
  end

  describe "area booking and scheduling" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, floor: floor}
    end

    test "creates bookable area", %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Meeting Room 101",
        code: "MTG-101",
        area_type: "conference",
        is_bookable: true,
        booking_advance_days: 30,
        min_booking_duration: 30,
        max_booking_duration: 240,
        floor_id: floor.id,
        tenant_id: tenant.id,
        metadata: %{
          "booking_enabled" => true,
          "__require_approval" => false,
          "auto_release_minutes" => 15
        }
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.is_bookable == true
      assert area.booking_advance_days == 30
    end

    test "finds bookable areas", %{tenant: tenant, floor: floor} do
      # Create bookable areas
      for i <- 1..5 do
        Sites.create_area(%{
          name: "Bookable Room #{i}",
          code: "BOOK-#{i}",
          area_type: "conference",
          is_bookable: true,
          occupancy_limit: 8 + i * 2,
          floor_id: floor.id,
          tenant_id: tenant.id
        })
      end

      bookable =
        Sites.find_bookable_areas(
          floor_id: floor.id,
          min_capacity: 10
        )

      assert length(bookable) >= 3
      assert Enum.all?(bookable, &(&1.is_bookable == true))
      assert Enum.all?(bookable, &(&1.occupancy_limit >= 10))
    end

    test "validates booking constraints", %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Restricted Booking Room",
        code: "RBR-001",
        area_type: "conference",
        is_bookable: true,
        min_booking_duration: 60,
        # Invalid: max < min
        max_booking_duration: 30,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_area(attrs)
      assert Exception.message(error) =~ "max booking duration must be
        greater than min"
    end
  end

  describe "area access control" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, floor: floor}
    end

    test "creates area with badge access __requirements",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Secure Lab",
        code: "LAB-001",
        area_type: "office",
        access_level: "restricted",
        is_secure: true,
        badge_access_required: true,
        floor_id: floor.id,
        tenant_id: tenant.id,
        metadata: %{
          "access_groups" => ["lab_staff", "researchers"],
          "time_restrictions" => %{
            "weekdays" => "07:00-19:00",
            "weekends" => "closed"
          }
        }
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.badge_access_required == true
      assert "lab_staff" in area.metadata["access_groups"]
    end

    test "finds areas by access group", %{tenant: tenant, floor: floor} do
      # Create areas with access groups
      {:ok, _} =
        Sites.create_area(%{
          name: "Engineering Lab",
          code: "ENG-LAB",
          floor_id: floor.id,
          tenant_id: tenant.id,
          metadata: %{"access_groups" => ["engineering", "facilities"]}
        })

      {:ok, _} =
        Sites.create_area(%{
          name: "Executive Suite",
          code: "EXEC-001",
          floor_id: floor.id,
          tenant_id: tenant.id,
          metadata: %{"access_groups" => ["executives", "admin"]}
        })

      engineering_areas =
        Sites.find_areas_by_access_group(
          tenant_id: tenant.id,
          access_group: "engineering"
        )

      assert length(engineering_areas) >= 1

      assert Enum.all?(engineering_areas, fn area ->
               "engineering" in (area.metadata["access_groups"] || [])
             end)
    end

    test "validates executive area __requirements",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Executive Conference",
        code: "EXEC-CONF",
        area_type: "conference",
        access_level: "executive",
        floor_id: floor.id,
        tenant_id: tenant.id,
        metadata: %{
          # Invalid for executive areas
          "visitor_escort_required" => false
        }
      }

      assert {:error, error} = Sites.create_area(attrs)
      assert Exception.message(error) =~ "executive areas require visitor
        escort"
    end
  end

  describe "area environmental monitoring" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, floor: floor}
    end

    test "creates area with environmental sensors",
         %{tenant: tenant, floor: floor} do
      attrs = %{
        name: "Clean Room",
        code: "CLEAN-001",
        area_type: "mechanical",
        climate_controlled: true,
        floor_id: floor.id,
        tenant_id: tenant.id,
        metadata: %{
          "sensors" => ["temperature", "humidity", "pressure", "particulate"],
          "temperature_range" => %{"min" => 68, "max" => 72},
          "humidity_range" => %{"min" => 40, "max" => 60},
          "air_changes_per_hour" => 20,
          "hepa_filtration" => true
        }
      }

      assert {:ok, area} = Sites.create_area(attrs)
      assert area.climate_controlled == true
      assert "particulate" in area.metadata["sensors"]
      assert area.metadata["hepa_filtration"] == true
    end

    test "finds areas needing environmental attention",
         %{tenant: tenant, floor: floor} do
      # Create area with environmental issues
      {:ok, _} =
        Sites.create_area(%{
          name: "Hot Server Room",
          code: "HOT-SRV",
          area_type: "mechanical",
          climate_controlled: true,
          floor_id: floor.id,
          tenant_id: tenant.id,
          metadata: %{
            # Too hot
            "current_temperature" => 85,
            "temperature_range" => %{"min" => 65, "max" => 75}
          }
        })

      problem_areas =
        Sites.find_environmental_issues(
          tenant_id: tenant.id,
          check_temperature: true
        )

      assert length(problem_areas) >= 1
    end
  end

  describe "bulk area operations" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, floor: floor}
    end

    test "bulk creates areas", %{tenant: tenant, floor: floor} do
      areas =
        for i <- 1..10 do
          %{
            name: "Area #{i}",
            code: "AREA-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
            area_type: "office",
            area_sqft: 1000,
            floor_id: floor.id,
            tenant_id: tenant.id
          }
        end

      assert {:ok, created} = Sites.bulk_create_areas(areas)
      assert length(created) == 10
    end

    test "bulk updates area status", %{tenant: tenant, floor: floor} do
      # Create areas
      areas =
        for i <- 1..5 do
          {:ok, area} =
            Sites.create_area(%{
              name: "Update Area #{i}",
              code: "UPD-#{i}",
              floor_id: floor.id,
              tenant_id: tenant.id
            })

          area
        end

      area_ids = Enum.map(areas, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_areas(
                 filter: [id: {:in, area_ids}],
                 attributes: %{status: "maintenance"}
               )

      assert count == 5

      # Verify update
      updated = Sites.list_areas!(filter: [id: {:in, area_ids}])
      assert Enum.all?(updated, &(&1.status == "maintenance"))
    end

    test "bulk assigns access levels", %{tenant: tenant, floor: floor} do
      # Create areas
      areas =
        for i <- 1..5 do
          {:ok, area} =
            Sites.create_area(%{
              name: "Access Area #{i}",
              code: "ACC-#{i}",
              floor_id: floor.id,
              tenant_id: tenant.id
            })

          area
        end

      area_ids = Enum.map(areas, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_areas(
                 filter: [id: {:in, area_ids}],
                 attributes: %{
                   access_level: "restricted",
                   is_secure: true,
                   badge_access_required: true
                 }
               )

      assert count == 5
    end
  end

  describe "area validation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id, area_sqft: 10_000)
      {:ok, tenant: tenant, floor: floor}
    end

    test "validates area size against floor", %{tenant: tenant, floor: floor} do
      # Valid area size
      attrs = %{
        name: "Valid Size Area",
        code: "VSA-001",
        area_sqft: 2000,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_area(attrs)

      # Area too large for floor
      attrs = %{
        name: "Too Large Area",
        code: "TLA-001",
        # Larger than floor
        area_sqft: 15_000,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_area(attrs)
      assert Exception.message(error) =~ "area size exceeds floor size"
    end

    test "validates total areas don't exceed floor",
         %{tenant: tenant, floor: floor} do
      # Create areas that fill the floor
      for i <- 1..4 do
        Sites.create_area(%{
          name: "Quarter Area #{i}",
          code: "QTR-#{i}",
          # 4 * 2400 = 9600
          area_sqft: 2400,
          floor_id: floor.id,
          tenant_id: tenant.id
        })
      end

      # Try to add area that would exceed floor
      attrs = %{
        name: "Overflow Area",
        code: "OVF-001",
        # Would total 10_600 > 10_000
        area_sqft: 1000,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_area(attrs)
      assert Exception.message(error) =~ "total area exceeds floor capacity"
    end

    test "validates occupancy density", %{tenant: tenant, floor: floor} do
      # Reasonable density
      attrs = %{
        name: "Normal Density",
        code: "ND-001",
        area_sqft: 1000,
        # 20 sqft per person
        occupancy_limit: 50,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_area(attrs)

      # Too dense
      attrs = %{
        name: "Too Dense",
        code: "TD-001",
        area_sqft: 1000,
        # 5 sqft per person - too dense
        occupancy_limit: 200,
        floor_id: floor.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_area(attrs)
      assert Exception.message(error) =~ "occupancy density exceeds safety
        limits"
    end

    test "validates conference room __requirements",
         %{tenant: tenant, floor: floor} do
      # Conference room without proper amenities
      attrs = %{
        name: "Basic Conference",
        code: "BC-001",
        area_type: "conference",
        occupancy_limit: 20,
        floor_id: floor.id,
        tenant_id: tenant.id,
        metadata: %{
          # No AV equipment
          "equipment" => []
        }
      }

      assert {:error, error} = Sites.create_area(attrs)
      assert Exception.message(error) =~ "conference rooms require AV equipment"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
