defmodule Indrajaal.Sites.LocationTest do
  use Indrajaal.DataCase
  import Indrajaal.SitesComprehensiveFactory
  alias Indrajaal.Sites.Location
  alias Indrajaal.Sites

  describe "location creation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, zone: zone}
    end

    test "creates location with valid attributes",
         %{tenant: tenant, zone: zone} do
      attrs = %{
        name: "Desk 001",
        code: "D-001",
        location_type: "desk",
        coordinates: %{"x" => 10.5, "y" => 20.3, "z" => 0},
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, location} = Sites.create_location(attrs)
      assert location.name == "Desk 001"
      assert location.code == "D-001"
      assert location.location_type == "desk"
      assert location.coordinates["x"] == 10.5
      assert location.zone_id == zone.id
      assert location.status == "available"
    end

    test "validates __required fields", %{tenant: tenant} do
      assert {:error, error} = Sites.create_location(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is __required"
      assert error_msg =~ "code: is __required"
      assert error_msg =~ "zone_id: is __required"
    end

    test "validates code uniqueness within zone",
         %{tenant: tenant, zone: zone} do
      attrs = %{
        name: "Location 1",
        code: "LOC-001",
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, _location1} = Sites.create_location(attrs)

      # Try to create another location with same code
      attrs2 = Map.put(attrs, :name, "Location 2")
      assert {:error, error} = Sites.create_location(attrs2)
      assert Exception.message(error) =~ "code: has already been taken"
    end

    test "allows same code across zones", %{tenant: tenant, zone: zone} do
      area =
        zone
        |> Ecto.assoc(:area)
        |> Indrajaal.Repo.one!()

      zone2 = insert(:zone, area_id: area.id, tenant_id: tenant.id)

      attrs1 = %{
        name: "Desk A",
        code: "DESK-001",
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      attrs2 = %{
        name: "Desk A",
        code: "DESK-001",
        zone_id: zone2.id,
        tenant_id: tenant.id
      }

      assert {:ok, location1} = Sites.create_location(attrs1)
      assert {:ok, location2} = Sites.create_location(attrs2)
      assert location1.code == location2.code
      assert location1.zone_id != location2.zone_id
    end

    test "validates location types", %{tenant: tenant, zone: zone} do
      valid_types = [
        "desk",
        "cubicle",
        "hot_desk",
        "conference_table",
        "shelf",
        "rack",
        "cabinet",
        "safe",
        "checkout",
        "display",
        "waypoint"
      ]

      for type <- valid_types do
        attrs = %{
          name: "#{String.capitalize(type)} Location",
          code: "#{String.upcase(type)}-001",
          location_type: type,
          zone_id: zone.id,
          tenant_id: tenant.id
        }

        assert {:ok, location} = Sites.create_location(attrs)
        assert location.location_type == type
      end
    end

    test "creates assignable location", %{tenant: tenant, zone: zone} do
      attrs = %{
        name: "Assigned Desk",
        code: "AD-001",
        location_type: "desk",
        is_assignable: true,
        assigned_to: "EMP-12_345",
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, location} = Sites.create_location(attrs)
      assert location.is_assignable == true
      assert location.assigned_to == "EMP-12_345"
      assert location.status == "occupied"
    end

    test "creates bookable location", %{tenant: tenant, zone: zone} do
      attrs = %{
        name: "Conference Room A",
        code: "CONF-A",
        location_type: "conference_table",
        is_bookable: true,
        capacity: 12,
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, location} = Sites.create_location(attrs)
      assert location.is_bookable == true
      assert location.capacity == 12
    end

    test "creates location with QR and NFC", %{tenant: tenant, zone: zone} do
      attrs = %{
        name: "Smart Location",
        code: "SMART-001",
        qr_code: "QR-SMART - 001",
        nfc_tag: "NFC-SMART - 001",
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, location} = Sites.create_location(attrs)
      assert location.qr_code == "QR-SMART - 001"
      assert location.nfc_tag == "NFC-SMART - 001"
    end

    test "creates location with metadata", %{tenant: tenant, zone: zone} do
      metadata = %{
        "equipment" => ["monitor", "keyboard", "mouse", "docking_station"],
        "amenities" => ["adjustable_desk", "ergonomic_chair"],
        "network_ports" => 4,
        "power_outlets" => 6,
        "window_view" => true,
        "last_sanitized" => DateTime.utc_now()
      }

      attrs = %{
        name: "Premium Desk",
        code: "PREM-001",
        location_type: "desk",
        metadata: metadata,
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, location} = Sites.create_location(attrs)
      assert "monitor" in location.metadata["equipment"]
      assert location.metadata["network_ports"] == 4
    end

    test "creates location with precise coordinates",
         %{tenant: tenant, zone: zone} do
      coords = %{
        "x" => 12.345,
        "y" => 67.890,
        "z" => 2.5,
        "orientation" => 90,
        "grid_ref" => "B4"
      }

      attrs = %{
        name: "Precise Location",
        code: "PREC-001",
        coordinates: coords,
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, location} = Sites.create_location(attrs)
      assert location.coordinates["x"] == 12.345
      assert location.coordinates["orientation"] == 90
      assert location.coordinates["grid_ref"] == "B4"
    end
  end

  describe "location updates" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)
      location = insert(:location, zone_id: zone.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, zone: zone, location: location}
    end

    test "updates location details", %{location: location} do
      attrs = %{
        name: "Updated Location Name",
        capacity: 8,
        status: "maintenance"
      }

      assert {:ok, updated} = Sites.update_location(location, attrs)
      assert updated.name == "Updated Location Name"
      assert updated.capacity == 8
      assert updated.status == "maintenance"
    end

    test "assigns location to __user", %{location: location} do
      attrs = %{
        is_assignable: true,
        assigned_to: "EMP-54_321",
        status: "occupied"
      }

      assert {:ok, updated} = Sites.update_location(location, attrs)
      assert updated.assigned_to == "EMP-54_321"
      assert updated.status == "occupied"
    end

    test "unassigns location", %{location: location} do
      # First assign
      {:ok, location} =
        Sites.update_location(location, %{
          is_assignable: true,
          assigned_to: "EMP-11_111",
          status: "occupied"
        })

      # Then unassign
      assert {:ok, updated} =
               Sites.update_location(location, %{
                 assigned_to: nil,
                 status: "available"
               })

      assert updated.assigned_to == nil
      assert updated.status == "available"
    end

    test "changes location status", %{location: location} do
      statuses = ["available", "occupied", "reserved", "maintenance", "unavailable"]

      for status <- statuses do
        assert {:ok, updated} = Sites.update_location(location, %{status: status})
        assert updated.status == status
      end
    end

    test "pr__events code change", %{location: location} do
      assert {:error, error} = Sites.update_location(location, %{code: "NEW-CODE"})
      assert Exception.message(error) =~ "cannot change location code"
    end

    test "updates equipment list", %{location: location} do
      attrs = %{
        metadata:
          Map.merge(location.metadata || %{}, %{
            "equipment" => ["new_monitor", "standing_desk_converter", "webcam"],
            "equipment_updated" => Date.utc_today()
          })
      }

      assert {:ok, updated} = Sites.update_location(location, attrs)
      assert "webcam" in updated.metadata["equipment"]
      assert updated.metadata["equipment_updated"] == Date.utc_today()
    end

    test "updates booking settings", %{location: location} do
      attrs = %{
        is_bookable: true,
        metadata:
          Map.merge(location.metadata || %{}, %{
            "min_booking_duration" => 30,
            "max_booking_duration" => 240,
            "advance_booking_days" => 14,
            "auto_release_minutes" => 15
          })
      }

      assert {:ok, updated} = Sites.update_location(location, attrs)
      assert updated.is_bookable == true
      assert updated.metadata["max_booking_duration"] == 240
    end

    test "updates coordinates", %{location: location} do
      new_coords = %{
        "x" => 15.0,
        "y" => 25.0,
        "z" => 0,
        "moved_date" => Date.utc_today()
      }

      assert {:ok, updated} = Sites.update_location(location, %{coordinates: new_coords})
      assert updated.coordinates["x"] == 15.0
      assert updated.coordinates["moved_date"] == Date.utc_today()
    end
  end

  describe "location queries" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 2)
      buildings = bulk_create_buildings(tenant, sites, 5)
      floors = bulk_create_floors(tenant, buildings, 20)
      areas = bulk_create_areas(tenant, floors, 100)
      zones = bulk_create_zones(tenant, areas, 300)
      locations = bulk_create_locations(tenant, zones, 500)
      {:ok, tenant: tenant, zones: zones, locations: locations}
    end

    test "lists all locations for tenant",
         %{tenant: tenant, locations: locations} do
      result = Sites.list_locations!(tenant_id: tenant.id)
      assert length(result) >= length(locations)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "lists locations for zone", %{zones: zones} do
      zone = List.first(zones)

      locations =
        Sites.list_locations!(
          zone_id: zone.id,
          tenant_id: zone.tenant_id
        )

      assert Enum.all?(locations, &(&1.zone_id == zone.id))
      assert length(locations) > 0
    end

    test "filters by location type", %{tenant: tenant} do
      desks =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [location_type: "desk"]
        )

      assert Enum.all?(desks, &(&1.location_type == "desk"))
      assert length(desks) > 0
    end

    test "filters by status", %{tenant: tenant} do
      available =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [status: "available"]
        )

      assert Enum.all?(available, &(&1.status == "available"))
    end

    test "filters assignable locations", %{tenant: tenant} do
      assignable =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [is_assignable: true]
        )

      assert Enum.all?(assignable, &(&1.is_assignable == true))
    end

    test "filters bookable locations", %{tenant: tenant} do
      bookable =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [is_bookable: true]
        )

      assert Enum.all?(bookable, &(&1.is_bookable == true))
    end

    test "filters by capacity", %{tenant: tenant} do
      large_locations =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [capacity: {:>=, 10}]
        )

      assert Enum.all?(large_locations, &(&1.capacity >= 10))
    end

    test "filters unassigned locations", %{tenant: tenant} do
      unassigned =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [assigned_to: nil, is_assignable: true]
        )

      assert Enum.all?(unassigned, &(&1.assigned_to == nil))
      assert Enum.all?(unassigned, &(&1.is_assignable == true))
    end

    test "searches by name", %{tenant: tenant} do
      desk_locations =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%desk%"}]
        )

      assert Enum.all?(desk_locations, &String.contains?(String.downcase(&1.name), "desk"))
    end

    test "searches by QR code", %{tenant: tenant} do
      # Find location with specific QR pattern
      qr_locations =
        Sites.list_locations!(
          tenant_id: tenant.id,
          filter: [qr_code: {:ilike, "QR-%"}]
        )

      assert Enum.all?(qr_locations, &String.starts_with?(&1.qr_code || "", "QR-"))
    end

    test "sorts by name", %{tenant: tenant} do
      locations =
        Sites.list_locations!(
          tenant_id: tenant.id,
          sort: [name: :asc],
          page: [limit: 50]
        )

      names = Enum.map(locations, & &1.name)
      assert names == Enum.sort(names)
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Sites.list_locations!(
          tenant_id: tenant.id,
          page: [limit: 100, offset: 0]
        )

      page2 =
        Sites.list_locations!(
          tenant_id: tenant.id,
          page: [limit: 100, offset: 100]
        )

      assert length(page1) == 100
      assert length(page2) >= 50

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "location assignment management" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)

      # Create assignable locations
      locations =
        for i <- 1..20 do
          insert(:location,
            zone_id: zone.id,
            tenant_id: tenant.id,
            location_type: "desk",
            is_assignable: true,
            assigned_to: if(i <= 10, do: "EMP-#{1000 + i}", else: nil),
            status: if(i <= 10, do: "occupied", else: "available")
          )
        end

      {:ok, tenant: tenant, zone: zone, locations: locations}
    end

    test "finds available desks", %{zone: zone} do
      available = Sites.find_available_desks(zone_id: zone.id)

      assert length(available) == 10
      assert Enum.all?(available, &(&1.assigned_to == nil))
      assert Enum.all?(available, &(&1.status == "available"))
    end

    test "assigns location to employee", %{locations: locations} do
      available_location = Enum.find(locations, &(&1.assigned_to == nil))

      assert {:ok, assigned} =
               Sites.assign_location(
                 available_location.id,
                 "EMP-9999"
               )

      assert assigned.assigned_to == "EMP-9999"
      assert assigned.status == "occupied"
    end

    test "pr__events double assignment", %{locations: locations} do
      occupied_location = Enum.find(locations, &(&1.assigned_to != nil))

      assert {:error, error} =
               Sites.assign_location(
                 occupied_location.id,
                 "EMP-8888"
               )

      assert Exception.message(error) =~ "location already assigned"
    end

    test "bulk assigns locations", %{locations: locations} do
      available_ids =
        locations
        |> Enum.filter(&(&1.assigned_to == nil))
        |> Enum.take(5)
        |> Enum.map(& &1.id)

      assignments =
        for {id, i} <- Enum.with_index(available_ids) do
          %{location_id: id, employee_id: "EMP-#{2000 + i}"}
        end

      assert {:ok, count} = Sites.bulk_assign_locations(assignments)
      assert count == 5
    end

    test "finds locations by employee", %{tenant: tenant} do
      employee_locations =
        Sites.find_locations_by_employee(
          tenant_id: tenant.id,
          employee_id: "EMP-1005"
        )

      assert length(employee_locations) == 1
      assert List.first(employee_locations).assigned_to == "EMP-1005"
    end

    test "generates assignment report", %{zone: zone} do
      report = Sites.generate_assignment_report(zone_id: zone.id)

      assert report.total_assignable == 20
      assert report.assigned_count == 10
      assert report.available_count == 10
      assert report.utilization_rate == 50.0
    end
  end

  describe "location booking management" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)

      # Create bookable locations
      locations =
        for i <- 1..10 do
          insert(:location,
            zone_id: zone.id,
            tenant_id: tenant.id,
            location_type: "conference_table",
            is_bookable: true,
            capacity: 6 + i * 2,
            status: if(rem(i, 3) == 0, do: "reserved", else: "available"),
            metadata: %{
              "amenities" => ["projector", "whiteboard", "conference_phone"],
              "booking_rules" => %{
                "min_duration" => 30,
                "max_duration" => 240,
                "advance_days" => 30
              }
            }
          )
        end

      {:ok, tenant: tenant, zone: zone, locations: locations}
    end

    test "finds available conference rooms", %{zone: zone} do
      available =
        Sites.find_available_bookable_locations(
          zone_id: zone.id,
          min_capacity: 10,
          __required_amenities: ["projector"]
        )

      assert length(available) > 0
      assert Enum.all?(available, &(&1.capacity >= 10))
      assert Enum.all?(available, &(&1.status == "available"))
      assert Enum.all?(available, &("projector" in &1.metadata["amenities"]))
    end

    test "reserves location", %{locations: locations} do
      available = Enum.find(locations, &(&1.status == "available"))

      reservation = %{
        start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
        end_time: DateTime.add(DateTime.utc_now(), 7200, :second),
        reserved_by: "EMP-5555"
      }

      assert {:ok, reserved} = Sites.reserve_location(available.id, reservation)
      assert reserved.status == "reserved"

      assert reserved.metadata["current_reservation"]["reserved_by"] ==
               "EMP-5555"
    end

    test "validates booking duration", %{locations: locations} do
      location = List.first(locations)

      # Too short
      short_reservation = %{
        start_time: DateTime.utc_now(),
        # 15 minutes
        end_time: DateTime.add(DateTime.utc_now(), 900, :second),
        reserved_by: "EMP-1111"
      }

      assert {:error, error} = Sites.reserve_location(location.id, short_reservation)
      assert Exception.message(error) =~ "booking duration below minimum"

      # Too long
      long_reservation = %{
        start_time: DateTime.utc_now(),
        # 5 hours
        end_time: DateTime.add(DateTime.utc_now(), 18_000, :second),
        reserved_by: "EMP-2222"
      }

      assert {:error, error} = Sites.reserve_location(location.id, long_reservation)
      assert Exception.message(error) =~ "booking duration exceeds maximum"
    end

    test "checks location availability", %{locations: locations} do
      location = List.first(locations)

      # Check future time slot
      start_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      end_time = DateTime.add(DateTime.utc_now(), 5400, :second)

      available =
        Sites.check_location_availability(
          location.id,
          start_time,
          end_time
        )

      assert available == true
    end

    test "auto-releases expired reservations", %{locations: locations} do
      # Create expired reservation
      expired_location = Enum.find(locations, &(&1.status == "reserved"))

      if expired_location do
        {:ok, updated} =
          Sites.update_location(expired_location, %{
            metadata:
              Map.merge(expired_location.metadata, %{
                "current_reservation" => %{
                  "end_time" => DateTime.add(DateTime.utc_now(), -900, :second),
                  "auto_release" => true
                }
              })
          })

        # Run auto-release
        released = Sites.auto_release_expired_reservations(tenant_id: expired_location.tenant_id)

        assert released > 0
      end
    end
  end

  describe "location wayfinding" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)

      # Create locations with coordinates
      locations =
        for i <- 1..20 do
          insert(:location,
            zone_id: zone.id,
            tenant_id: tenant.id,
            coordinates: %{
              "x" => rem(i, 5) * 10.0,
              "y" => div(i - 1, 5) * 10.0,
              "z" => 0
            },
            metadata: %{
              "waypoint" => rem(i, 5) == 0,
              "landmark" => i in [1, 10, 20],
              "emergency_exit" => i in [5, 15]
            }
          )
        end

      {:ok, tenant: tenant, zone: zone, locations: locations}
    end

    test "finds nearest location", %{locations: locations} do
      from_coords = %{"x" => 12.0, "y" => 12.0, "z" => 0}

      nearest =
        Sites.find_nearest_location(
          zone_id: List.first(locations).zone_id,
          coordinates: from_coords
        )

      assert nearest != nil
      assert Map.has_key?(nearest, :distance)
    end

    test "finds locations within radius", %{zone: zone} do
      center = %{"x" => 20.0, "y" => 20.0, "z" => 0}

      nearby =
        Sites.find_locations_within_radius(
          zone_id: zone.id,
          center: center,
          radius: 15.0
        )

      assert length(nearby) > 0

      assert Enum.all?(nearby, fn loc ->
               distance = calculate_2d_distance(center, loc.coordinates)
               distance <= 15.0
             end)
    end

    test "finds waypoint locations", %{zone: zone} do
      waypoints = Sites.find_waypoint_locations(zone_id: zone.id)

      assert length(waypoints) > 0
      assert Enum.all?(waypoints, &(&1.metadata["waypoint"] == true))
    end

    test "finds emergency exits", %{zone: zone} do
      exits =
        Sites.find_emergency_locations(
          zone_id: zone.id,
          type: "emergency_exit"
        )

      assert length(exits) > 0
      assert Enum.all?(exits, &(&1.metadata["emergency_exit"] == true))
    end

    test "calculates path between locations", %{locations: locations} do
      location1 = Enum.at(locations, 0)
      location2 = Enum.at(locations, 19)

      path =
        Sites.calculate_location_path(
          from_location_id: location1.id,
          to_location_id: location2.id
        )

      assert length(path) >= 2
      assert List.first(path).id == location1.id
      assert List.last(path).id == location2.id
    end

    test "generates location grid map", %{zone: zone} do
      grid = Sites.generate_location_grid(zone_id: zone.id)

      assert is_map(grid)
      assert Map.has_key?(grid, :locations)
      assert Map.has_key?(grid, :dimensions)
      assert Map.has_key?(grid, :cell_size)
    end
  end

  describe "location equipment tracking" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)

      locations =
        Enum.map(1..10, fn i ->
          equipment =
            ["monitor", "keyboard", "mouse"] ++
              if(rem(i, 4) == 0, do: ["projector"], else: [])

          insert(:location,
            zone_id: zone.id,
            tenant_id: tenant.id,
            location_type:
              if(
                rem(
                  i,
                  3
                ) == 2,
                do: "conference_table",
                else: "desk"
              ),
            metadata: %{
              "equipment" => equipment,
              "equipment_condition" => %{
                "monitor" => if(i > 5, do: "good", else: "needs_replacement"),
                "last_inventory" => Date.add(Date.utc_today(), -i * 10)
              }
            }
          )
        end)

      {:ok, tenant: tenant, zone: zone, locations: locations}
    end

    test "finds locations with specific equipment", %{zone: zone} do
      locations_with_projector =
        Sites.find_locations_with_equipment(
          zone_id: zone.id,
          equipment: "projector"
        )

      assert length(locations_with_projector) > 0
      assert Enum.all?(locations_with_projector, &("projector" in &1.metadata["equipment"]))
    end

    test "identifies equipment needing replacement", %{tenant: tenant} do
      needs_replacement = Sites.find_equipment_needing_replacement(tenant_id: tenant.id)

      assert length(needs_replacement) > 0

      assert Enum.all?(needs_replacement, fn loc ->
               Enum.any?(loc.metadata["equipment_condition"] || %{}, fn {_, condition} ->
                 condition == "needs_replacement"
               end)
             end)
    end

    test "updates equipment inventory", %{locations: locations} do
      location = List.first(locations)

      new_equipment = ["monitor_4k", "wireless_keyboard", "wireless_mouse", "webcam"]

      assert {:ok, updated} =
               Sites.update_location_equipment(
                 location.id,
                 new_equipment
               )

      assert updated.metadata["equipment"] == new_equipment
      assert updated.metadata["last_equipment_update"] == Date.utc_today()
    end

    test "tracks equipment issues", %{locations: locations} do
      location = List.first(locations)

      issue = %{
        equipment: "monitor",
        issue_type: "flickering",
        reported_by: "EMP-3333",
        priority: "medium"
      }

      assert {:ok, updated} = Sites.report_equipment_issue(location.id, issue)
      assert length(updated.metadata["equipment_issues"]) == 1
    end

    test "generates equipment inventory report", %{zone: zone} do
      report = Sites.generate_equipment_inventory_report(zone_id: zone.id)

      assert Map.has_key?(report, :total_items)
      assert Map.has_key?(report, :by_type)
      assert Map.has_key?(report, :replacement_needed)
      assert Map.has_key?(report, :inventory_age)
    end
  end

  describe "location sanitization tracking" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, zone: zone}
    end

    test "tracks sanitization", %{tenant: tenant, zone: zone} do
      {:ok, location} =
        Sites.create_location(%{
          name: "Sanitized Desk",
          code: "SD-001",
          zone_id: zone.id,
          tenant_id: tenant.id
        })

      sanitization = %{
        sanitized_by: "STAFF-001",
        method: "deep_clean",
        products_used: ["disinfectant", "sanitizer"],
        # 4 hours
        next_due: DateTime.add(DateTime.utc_now(), 14_400, :second)
      }

      assert {:ok, updated} = Sites.record_location_sanitization(location.id, sanitization)
      assert updated.metadata["last_sanitized_by"] == "STAFF-001"
      assert updated.metadata["sanitization_method"] == "deep_clean"
    end

    test "finds locations needing sanitization",
         %{tenant: tenant, zone: zone} do
      # Create locations with old sanitization
      for i <- 1..5 do
        Sites.create_location(%{
          name: "Desk #{i}",
          code: "D-#{i}",
          zone_id: zone.id,
          tenant_id: tenant.id,
          metadata: %{
            "last_sanitized" => DateTime.add(DateTime.utc_now(), -i * 3600, :second),
            "sanitization_interval_hours" => 4
          }
        })
      end

      needs_sanitization =
        Sites.find_locations_needing_sanitization(
          zone_id: zone.id,
          max_hours_since_sanitized: 4
        )

      assert length(needs_sanitization) >= 3
    end

    test "generates sanitization schedule", %{zone: zone} do
      schedule =
        Sites.generate_sanitization_schedule(
          zone_id: zone.id,
          interval_hours: 4
        )

      assert is_list(schedule)
      assert Enum.all?(schedule, &Map.has_key?(&1, :location_id))
      assert Enum.all?(schedule, &Map.has_key?(&1, :scheduled_time))
    end
  end

  describe "bulk location operations" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, zone: zone}
    end

    test "bulk creates locations", %{tenant: tenant, zone: zone} do
      locations =
        for i <- 1..25 do
          %{
            name: "Bulk Location #{i}",
            code: "BL-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
            location_type: "desk",
            zone_id: zone.id,
            tenant_id: tenant.id
          }
        end

      assert {:ok, created} = Sites.bulk_create_locations(locations)
      assert length(created) == 25
    end

    test "bulk updates location status", %{tenant: tenant, zone: zone} do
      # Create locations
      locations =
        for i <- 1..10 do
          {:ok, location} =
            Sites.create_location(%{
              name: "Status Location #{i}",
              code: "SL-#{i}",
              zone_id: zone.id,
              tenant_id: tenant.id
            })

          location
        end

      location_ids = Enum.map(locations, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_locations(
                 filter: [id: {:in, location_ids}],
                 attributes: %{status: "maintenance"}
               )

      assert count == 10

      # Verify update
      updated = Sites.list_locations!(filter: [id: {:in, location_ids}])
      assert Enum.all?(updated, &(&1.status == "maintenance"))
    end

    test "bulk assigns locations", %{tenant: tenant, zone: zone} do
      # Create assignable locations
      locations =
        for i <- 1..5 do
          {:ok, location} =
            Sites.create_location(%{
              name: "Assignable #{i}",
              code: "ASN-#{i}",
              location_type: "desk",
              is_assignable: true,
              zone_id: zone.id,
              tenant_id: tenant.id
            })

          location
        end

      assignments =
        Enum.map(Enum.with_index(locations), fn {loc, i} ->
          %{location_id: loc.id, employee_id: "EMP-#{7000 + i}"}
        end)

      assert {:ok, count} = Sites.bulk_assign_locations(assignments)
      assert count == 5
    end

    test "bulk releases reservations", %{tenant: tenant, zone: zone} do
      # Create reserved locations
      locations =
        for i <- 1..5 do
          {:ok, location} =
            Sites.create_location(%{
              name: "Reserved #{i}",
              code: "RES-#{i}",
              location_type: "conference_table",
              is_bookable: true,
              status: "reserved",
              zone_id: zone.id,
              tenant_id: tenant.id,
              metadata: %{
                "current_reservation" => %{
                  "reserved_by" => "EMP-#{8000 + i}",
                  "end_time" => DateTime.add(DateTime.utc_now(), 3600, :second)
                }
              }
            })

          location
        end

      location_ids = Enum.map(locations, & &1.id)

      assert {:ok, count} = Sites.bulk_release_reservations(filter: [id: {:in, location_ids}])

      assert count == 5

      # Verify release
      released = Sites.list_locations!(filter: [id: {:in, location_ids}])
      assert Enum.all?(released, &(&1.status == "available"))
    end
  end

  describe "location validation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)

      zone =
        insert(:zone,
          area_id: area.id,
          tenant_id: tenant.id,
          boundaries: %{
            "type" => "rectangle",
            "coordinates" => [
              %{"x" => 0, "y" => 0},
              %{"x" => 50, "y" => 0},
              %{"x" => 50, "y" => 30},
              %{"x" => 0, "y" => 30}
            ]
          }
        )

      {:ok, tenant: tenant, zone: zone}
    end

    test "validates coordinates within zone", %{tenant: tenant, zone: zone} do
      # Valid coordinates
      attrs = %{
        name: "Valid Location",
        code: "VL-001",
        coordinates: %{"x" => 25, "y" => 15, "z" => 0},
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_location(attrs)

      # Coordinates outside zone
      attrs = %{
        name: "Invalid Location",
        code: "IL-001",
        coordinates: %{"x" => 60, "y" => 40, "z" => 0},
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_location(attrs)
      assert Exception.message(error) =~ "coordinates outside zone boundaries"
    end

    test "validates location overlap", %{tenant: tenant, zone: zone} do
      # Create first location
      {:ok, _} =
        Sites.create_location(%{
          name: "Location 1",
          code: "L1",
          coordinates: %{"x" => 10, "y" => 10, "z" => 0},
          zone_id: zone.id,
          tenant_id: tenant.id
        })

      # Try to create overlapping location (too close)
      attrs = %{
        name: "Location 2",
        code: "L2",
        # Too close
        coordinates: %{"x" => 10.5, "y" => 10.5, "z" => 0},
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_location(attrs)
      assert Exception.message(error) =~ "location too close to existing
        location"
    end

    test "validates capacity for location type",
         %{tenant: tenant, zone: zone} do
      # Desk with too high capacity
      attrs = %{
        name: "Big Desk",
        code: "BD-001",
        location_type: "desk",
        # Too high for desk
        capacity: 10,
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_location(attrs)
      assert Exception.message(error) =~ "invalid capacity for location type"

      # Conference table with reasonable capacity
      attrs = %{
        name: "Conference Table",
        code: "CT-001",
        location_type: "conference_table",
        capacity: 10,
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_location(attrs)
    end

    test "validates bookable __requirements", %{tenant: tenant, zone: zone} do
      # Bookable without capacity
      attrs = %{
        name: "Bookable No Capacity",
        code: "BNC-001",
        is_bookable: true,
        capacity: nil,
        zone_id: zone.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_location(attrs)
      assert Exception.message(error) =~ "bookable locations require capacity"
    end

    test "validates equipment for location type",
         %{tenant: tenant, zone: zone} do
      # Server rack without proper equipment
      attrs = %{
        name: "Empty Rack",
        code: "ER-001",
        location_type: "server_rack",
        zone_id: zone.id,
        tenant_id: tenant.id,
        metadata: %{
          # No equipment
          "equipment" => []
        }
      }

      assert {:error, error} = Sites.create_location(attrs)
      assert Exception.message(error) =~ "server rack __requires equipment list"
    end
  end

  # Helper function
  defp calculate_2d_distance(point1, point2) do
    dx = point1["x"] - point2["x"]
    dy = point1["y"] - point2["y"]
    :math.sqrt(dx * dx + dy * dy)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
