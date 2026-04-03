defmodule Indrajaal.Sites.ZoneTest do
  use Indrajaal.DataCase
  import Indrajaal.SitesComprehensiveFactory
  alias Indrajaal.Sites.Zone
  alias Indrajaal.Sites

  describe "zone creation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, area: area}
    end

    test "creates zone with valid attributes", %{tenant: tenant, area: area} do
      attrs = %{
        name: "Workstation Zone A",
        code: "WZ-A",
        zone_type: "workstation",
        purpose: "individual_work",
        max_occupancy: 20,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.name == "Workstation Zone A"
      assert zone.code == "WZ-A"
      assert zone.zone_type == "workstation"
      assert zone.purpose == "individual_work"
      assert zone.area_id == area.id
      assert zone.status == "operational"
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Sites.create_zone(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
      assert error_msg =~ "code: is required"
      assert error_msg =~ "area_id: is required"
    end

    test "validates code uniqueness within area",
         %{tenant: tenant, area: area} do
      attrs = %{
        name: "Zone 1",
        code: "ZONE-001",
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, _zone1} = Sites.create_zone(attrs)

      # Try to create another zone with same code
      attrs2 = Map.put(attrs, :name, "Zone 2")
      assert {:error, error} = Sites.create_zone(attrs2)
      assert Exception.message(error) =~ "code: has already been taken"
    end

    test "allows same code across areas", %{tenant: tenant, area: area} do
      floor =
        area
        |> Ecto.assoc(:floor)
        |> Indrajaal.Repo.one!()

      area2 = insert(:area, floor_id: floor.id, tenant_id: tenant.id)

      attrs1 = %{
        name: "Meeting Zone",
        code: "MTG-001",
        area_id: area.id,
        tenant_id: tenant.id
      }

      attrs2 = %{
        name: "Meeting Zone",
        code: "MTG-001",
        area_id: area2.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone1} = Sites.create_zone(attrs1)
      assert {:ok, zone2} = Sites.create_zone(attrs2)
      assert zone1.code == zone2.code
      assert zone1.area_id != zone2.area_id
    end

    test "validates zone types", %{tenant: tenant, area: area} do
      valid_types = [
        "workstation",
        "meeting",
        "collaboration",
        "storage",
        "equipment",
        "circulation",
        "amenity",
        "security",
        "retail"
      ]

      for type <- valid_types do
        attrs = %{
          name: "#{String.capitalize(type)} Zone",
          code: "#{String.upcase(type)}-001",
          zone_type: type,
          area_id: area.id,
          tenant_id: tenant.id
        }

        assert {:ok, zone} = Sites.create_zone(attrs)
        assert zone.zone_type == type
      end
    end

    test "creates zone with access control", %{tenant: tenant, area: area} do
      attrs = %{
        name: "Secure Zone",
        code: "SEC-001",
        zone_type: "security",
        purpose: "monitoring",
        access_control_enabled: true,
        badge_reader_count: 2,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.access_control_enabled == true
      assert zone.badge_reader_count == 2
    end

    test "creates zone with surveillance", %{tenant: tenant, area: area} do
      attrs = %{
        name: "Monitored Zone",
        code: "MON-001",
        surveillance_enabled: true,
        camera_count: 4,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.surveillance_enabled == true
      assert zone.camera_count == 4
    end

    test "creates zone with occupancy tracking",
         %{tenant: tenant, area: area} do
      attrs = %{
        name: "Tracked Zone",
        code: "TRK-001",
        occupancy_tracking_enabled: true,
        max_occupancy: 50,
        current_occupancy: 0,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.occupancy_tracking_enabled == true
      assert zone.max_occupancy == 50
      assert zone.current_occupancy == 0
    end

    test "creates zone with environmental monitoring",
         %{tenant: tenant, area: area} do
      attrs = %{
        name: "Climate Zone",
        code: "CLM-001",
        environmental_monitoring: true,
        area_id: area.id,
        tenant_id: tenant.id,
        metadata: %{
          "sensors" => ["temperature", "humidity", "co2", "motion"],
          "hvac_zone" => "HVAC-3",
          "lighting_zone" => "LZ-5"
        }
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.environmental_monitoring == true
      assert "temperature" in zone.metadata["sensors"]
    end

    test "creates zone with boundaries", %{tenant: tenant, area: area} do
      boundaries = %{
        "type" => "polygon",
        "coordinates" => [
          %{"x" => 0, "y" => 0},
          %{"x" => 10, "y" => 0},
          %{"x" => 10, "y" => 10},
          %{"x" => 0, "y" => 10}
        ]
      }

      attrs = %{
        name: "Bounded Zone",
        code: "BND-001",
        boundaries: boundaries,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.boundaries["type"] == "polygon"
      assert length(zone.boundaries["coordinates"]) == 4
    end

    test "creates zone with metadata", %{tenant: tenant, area: area} do
      metadata = %{
        "security_level" => "high",
        "badge_readers" => ["north_entry", "south_entry"],
        "cameras" => ["PTZ-001", "PTZ-002", "Fixed-001"],
        "emergency_equipment" => ["fire_extinguisher", "first_aid", "aed"],
        "network_coverage" => "wifi_6",
        "power_outlets" => 20
      }

      attrs = %{
        name: "Tech Zone",
        code: "TECH-001",
        metadata: metadata,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.metadata["security_level"] == "high"
      assert length(zone.metadata["cameras"]) == 3
    end
  end

  describe "zone updates" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      zone = insert(:zone, area_id: area.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, area: area, zone: zone}
    end

    test "updates zone details", %{zone: zone} do
      attrs = %{
        name: "Updated Zone Name",
        purpose: "collaborative_work",
        max_occupancy: 30
      }

      assert {:ok, updated} = Sites.update_zone(zone, attrs)
      assert updated.name == "Updated Zone Name"
      assert updated.purpose == "collaborative_work"
      assert updated.max_occupancy == 30
    end

    test "updates occupancy", %{zone: zone} do
      # Set max first
      {:ok, zone} = Sites.update_zone(zone, %{max_occupancy: 25})

      # Update current occupancy
      assert {:ok, updated} = Sites.update_zone(zone, %{current_occupancy: 20})
      assert updated.current_occupancy == 20

      # Try to exceed max
      assert {:error, error} = Sites.update_zone(zone, %{current_occupancy: 30})
      assert Exception.message(error) =~ "current occupancy exceeds maximum"
    end

    test "updates security settings", %{zone: zone} do
      attrs = %{
        access_control_enabled: true,
        surveillance_enabled: true,
        badge_reader_count: 3,
        camera_count: 5
      }

      assert {:ok, updated} = Sites.update_zone(zone, attrs)
      assert updated.access_control_enabled == true
      assert updated.surveillance_enabled == true
      assert updated.badge_reader_count == 3
      assert updated.camera_count == 5
    end

    test "changes zone status", %{zone: zone} do
      # Maintenance mode
      assert {:ok, updated} = Sites.update_zone(zone, %{status: "maintenance"})
      assert updated.status == "maintenance"

      # Back to operational
      assert {:ok, updated} = Sites.update_zone(updated, %{status: "operational"})
      assert updated.status == "operational"
    end

    test "prevents code change", %{zone: zone} do
      assert {:error, error} = Sites.update_zone(zone, %{code: "NEW-CODE"})
      assert Exception.message(error) =~ "cannot change zone code"
    end

    test "updates environmental settings", %{zone: zone} do
      attrs = %{
        environmental_monitoring: true,
        metadata:
          Map.merge(zone.metadata || %{}, %{
            "temperature_setpoint" => 72,
            "humidity_target" => 45,
            "co2_threshold" => 1000,
            "lighting_level" => 500
          })
      }

      assert {:ok, updated} = Sites.update_zone(zone, attrs)
      assert updated.environmental_monitoring == true
      assert updated.metadata["temperature_setpoint"] == 72
    end

    test "updates zone boundaries", %{zone: zone} do
      new_boundaries = %{
        "type" => "polygon",
        "coordinates" => [
          %{"x" => 0, "y" => 0},
          %{"x" => 15, "y" => 0},
          %{"x" => 15, "y" => 15},
          %{"x" => 0, "y" => 15}
        ]
      }

      assert {:ok, updated} = Sites.update_zone(zone, %{boundaries: new_boundaries})

      assert updated.boundaries["coordinates"]
             |> List.last() == %{"x" => 0, "y" => 15}
    end
  end

  describe "zone queries" do
    setup do
      tenant = insert(:tenant)
      sites = bulk_create_sites(tenant, 3)
      buildings = bulk_create_buildings(tenant, sites, 10)
      floors = bulk_create_floors(tenant, buildings, 50)
      areas = bulk_create_areas(tenant, floors, 200)
      zones = bulk_create_zones(tenant, areas, 400)
      {:ok, tenant: tenant, areas: areas, zones: zones}
    end

    test "lists all zones for tenant", %{tenant: tenant, zones: zones} do
      result = Sites.list_zones!(tenant_id: tenant.id)
      assert length(result) >= length(zones)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "lists zones for area", %{areas: areas} do
      area = List.first(areas)

      zones =
        Sites.list_zones!(
          area_id: area.id,
          tenant_id: area.tenant_id
        )

      assert Enum.all?(zones, &(&1.area_id == area.id))
      assert length(zones) > 0
    end

    test "filters by zone type", %{tenant: tenant} do
      workstations =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [zone_type: "workstation"]
        )

      assert Enum.all?(workstations, &(&1.zone_type == "workstation"))
      assert length(workstations) > 0
    end

    test "filters by purpose", %{tenant: tenant} do
      meeting_zones =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [purpose: "meetings"]
        )

      assert Enum.all?(meeting_zones, &(&1.purpose == "meetings"))
    end

    test "filters by status", %{tenant: tenant} do
      operational =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [status: "operational"]
        )

      assert Enum.all?(operational, &(&1.status == "operational"))
    end

    test "filters by access control", %{tenant: tenant} do
      controlled =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [access_control_enabled: true]
        )

      assert Enum.all?(controlled, &(&1.access_control_enabled == true))
    end

    test "filters by surveillance", %{tenant: tenant} do
      monitored =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [surveillance_enabled: true]
        )

      assert Enum.all?(monitored, &(&1.surveillance_enabled == true))
    end

    test "filters by occupancy tracking", %{tenant: tenant} do
      tracked =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [occupancy_tracking_enabled: true]
        )

      assert Enum.all?(tracked, &(&1.occupancy_tracking_enabled == true))
    end

    test "searches by name", %{tenant: tenant} do
      workstation_zones =
        Sites.list_zones!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%workstation%"}]
        )

      assert Enum.all?(
               workstation_zones,
               &String.contains?(String.downcase(&1.name), "workstation")
             )
    end

    test "sorts by name", %{tenant: tenant} do
      zones =
        Sites.list_zones!(
          tenant_id: tenant.id,
          sort: [name: :asc],
          page: [limit: 50]
        )

      names = Enum.map(zones, & &1.name)
      assert names == Enum.sort(names)
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Sites.list_zones!(
          tenant_id: tenant.id,
          page: [limit: 100, offset: 0]
        )

      page2 =
        Sites.list_zones!(
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

  describe "zone occupancy management" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)

      zones =
        for i <- 1..5 do
          insert(:zone,
            name: "Zone #{i}",
            area_id: area.id,
            tenant_id: tenant.id
          )
        end

      {:ok, tenant: tenant, area: area, zones: zones}
    end

    test "tracks zone occupancy", %{zones: zones} do
      zone = List.first(zones)

      # Increment occupancy
      assert {:ok, updated} = Sites.increment_zone_occupancy(zone.id)
      assert updated.current_occupancy == zone.current_occupancy + 1

      # Decrement occupancy
      assert {:ok, updated} = Sites.decrement_zone_occupancy(updated.id)
      assert updated.current_occupancy == zone.current_occupancy
    end

    test "prevents over-capacity", %{zones: zones} do
      zone = List.first(zones)

      # Set to max capacity
      {:ok, zone} = Sites.update_zone(zone, %{current_occupancy: zone.max_occupancy})

      # Try to increment beyond max
      assert {:error, error} = Sites.increment_zone_occupancy(zone.id)
      assert Exception.message(error) =~ "zone at maximum capacity"
    end

    test "finds available zones", %{area: area} do
      available =
        Sites.find_available_zones(
          area_id: area.id,
          min_capacity: 5
        )

      assert Enum.all?(available, fn zone ->
               zone.max_occupancy - zone.current_occupancy >= 5
             end)
    end

    test "calculates area occupancy", %{area: area} do
      stats = Sites.calculate_area_zone_occupancy(area_id: area.id)

      assert Map.has_key?(stats, :total_capacity)
      assert Map.has_key?(stats, :current_occupancy)
      assert Map.has_key?(stats, :occupancy_rate)
      assert Map.has_key?(stats, :zones_at_capacity)
      assert stats.occupancy_rate >= 0
      assert stats.occupancy_rate <= 100
    end

    test "identifies crowded zones", %{area: area, tenant: tenant} do
      # Create a crowded zone
      {:ok, crowded} =
        Sites.create_zone(%{
          name: "Crowded Zone",
          code: "CROWD-001",
          occupancy_tracking_enabled: true,
          max_occupancy: 10,
          current_occupancy: 9,
          area_id: area.id,
          tenant_id: tenant.id
        })

      crowded_zones =
        Sites.find_crowded_zones(
          area_id: area.id,
          threshold_percentage: 85
        )

      assert Enum.any?(crowded_zones, &(&1.id == crowded.id))
    end
  end

  describe "zone security management" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, area: area}
    end

    test "creates high security zone", %{tenant: tenant, area: area} do
      attrs = %{
        name: "Classified Zone",
        code: "CLASS-001",
        zone_type: "security",
        purpose: "classified_operations",
        access_control_enabled: true,
        surveillance_enabled: true,
        badge_reader_count: 4,
        camera_count: 8,
        area_id: area.id,
        tenant_id: tenant.id,
        metadata: %{
          "security_level" => "maximum",
          "biometric_required" => true,
          "mantrap" => true,
          "two_person_rule" => true,
          "recording_retention_days" => 90
        }
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.metadata["security_level"] == "maximum"
      assert zone.metadata["biometric_required"] == true
    end

    test "finds zones by security level", %{tenant: tenant, area: area} do
      # Create zones with different security levels
      for {level, i} <- Enum.with_index(["basic", "standard", "enhanced", "maximum"]) do
        Sites.create_zone(%{
          name: "Security Zone #{i}",
          code: "SEC-#{i}",
          area_id: area.id,
          tenant_id: tenant.id,
          metadata: %{"security_level" => level}
        })
      end

      high_security =
        Sites.find_zones_by_security_level(
          tenant_id: tenant.id,
          min_level: "enhanced"
        )

      assert length(high_security) >= 2

      assert Enum.all?(high_security, fn zone ->
               zone.metadata["security_level"] in ["enhanced", "maximum"]
             end)
    end

    test "validates security requirements", %{tenant: tenant, area: area} do
      # High security zone without proper equipment
      attrs = %{
        name: "Insecure High Security",
        code: "INS-001",
        zone_type: "security",
        area_id: area.id,
        tenant_id: tenant.id,
        metadata: %{"security_level" => "maximum"},
        # Too few for maximum security
        camera_count: 1
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "insufficient cameras for security
        level"
    end

    test "tracks security incidents", %{tenant: tenant, area: area} do
      {:ok, zone} =
        Sites.create_zone(%{
          name: "Monitored Zone",
          code: "MON-001",
          surveillance_enabled: true,
          area_id: area.id,
          tenant_id: tenant.id,
          metadata: %{"incident_count" => 0}
        })

      # Record incident
      {:ok, updated} =
        Sites.record_zone_incident(zone.id, %{
          type: "unauthorized_access",
          timestamp: DateTime.utc_now(),
          resolved: false
        })

      assert updated.metadata["incident_count"] == 1
      assert updated.metadata["last_incident_type"] == "unauthorized_access"
    end
  end

  describe "zone environmental control" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, area: area}
    end

    test "creates climate controlled zone", %{tenant: tenant, area: area} do
      attrs = %{
        name: "Server Zone",
        code: "SRV-ZONE",
        zone_type: "equipment",
        environmental_monitoring: true,
        area_id: area.id,
        tenant_id: tenant.id,
        metadata: %{
          "hvac_zone" => "HVAC-DC - 1",
          "temperature_setpoint" => 68,
          "temperature_tolerance" => 2,
          "humidity_setpoint" => 45,
          "humidity_tolerance" => 5,
          "sensors" => ["temp_001", "temp_002", "humidity_001"],
          "cooling_redundancy" => "N + 1"
        }
      }

      assert {:ok, zone} = Sites.create_zone(attrs)
      assert zone.environmental_monitoring == true
      assert zone.metadata["temperature_setpoint"] == 68
    end

    test "finds zones with environmental alerts",
         %{tenant: tenant, area: area} do
      # Create zone with temperature issue
      {:ok, _} =
        Sites.create_zone(%{
          name: "Hot Zone",
          code: "HOT-001",
          environmental_monitoring: true,
          area_id: area.id,
          tenant_id: tenant.id,
          metadata: %{
            "temperature_setpoint" => 72,
            # Too hot
            "current_temperature" => 85,
            "alert_active" => true
          }
        })

      alert_zones = Sites.find_zones_with_environmental_alerts(tenant_id: tenant.id)

      assert length(alert_zones) >= 1
      assert Enum.all?(alert_zones, &(&1.metadata["alert_active"] == true))
    end

    test "updates environmental readings", %{tenant: tenant, area: area} do
      {:ok, zone} =
        Sites.create_zone(%{
          name: "Monitored Zone",
          code: "ENV-001",
          environmental_monitoring: true,
          area_id: area.id,
          tenant_id: tenant.id
        })

      readings = %{
        "temperature" => 71.5,
        "humidity" => 48.2,
        "co2_ppm" => 450,
        "timestamp" => DateTime.utc_now()
      }

      assert {:ok, updated} = Sites.update_zone_environmental_readings(zone.id, readings)
      assert updated.metadata["current_temperature"] == 71.5
      assert updated.metadata["current_humidity"] == 48.2
    end
  end

  describe "zone navigation and wayfinding" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)

      # Create connected zones
      zones =
        for i <- 1..5 do
          insert(:zone,
            name: "Zone #{i}",
            code: "Z-#{i}",
            area_id: area.id,
            tenant_id: tenant.id,
            metadata: %{
              "connected_zones" =>
                if(i > 1, do: ["Z-#{i - 1}"], else: []) ++
                  if(i < 5, do: ["Z-#{i + 1}"], else: [])
            }
          )
        end

      {:ok, tenant: tenant, area: area, zones: zones}
    end

    test "finds navigation path between zones", %{zones: zones} do
      zone1 = Enum.at(zones, 0)
      zone5 = Enum.at(zones, 4)

      path =
        Sites.find_zone_navigation_path(
          from_zone_id: zone1.id,
          to_zone_id: zone5.id
        )

      assert length(path) >= 2
      assert List.first(path).id == zone1.id
      assert List.last(path).id == zone5.id
    end

    test "identifies waypoint zones", %{area: area, tenant: tenant} do
      # Create waypoint zone
      {:ok, waypoint} =
        Sites.create_zone(%{
          name: "Navigation Hub",
          code: "NAV-HUB",
          zone_type: "circulation",
          purpose: "navigation",
          area_id: area.id,
          tenant_id: tenant.id,
          metadata: %{
            "waypoint" => true,
            "digital_signage" => true,
            "connected_zones" => ["Z-1", "Z-2", "Z-3", "Z-4", "Z-5"]
          }
        })

      waypoints = Sites.find_waypoint_zones(area_id: area.id)
      assert Enum.any?(waypoints, &(&1.id == waypoint.id))
    end

    test "calculates zone distances", %{zones: zones} do
      zone1 = Enum.at(zones, 0)
      zone3 = Enum.at(zones, 2)

      distance = Sites.calculate_zone_distance(zone1.id, zone3.id)
      assert distance > 0
    end
  end

  describe "zone usage analytics" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)

      zones =
        for i <- 1..20 do
          insert(:zone,
            area_id: area.id,
            tenant_id: tenant.id,
            zone_type: Enum.random(["workstation", "meeting", "collaboration", "amenity"]),
            occupancy_tracking_enabled: true,
            max_occupancy: 10 + :rand.uniform(20),
            metadata: %{
              # Weekly hours
              "usage_hours" => :rand.uniform(168),
              "peak_usage_time" => "#{8 + :rand.uniform(10)}:00",
              "avg_duration_minutes" => 30 + :rand.uniform(90)
            }
          )
        end

      {:ok, tenant: tenant, area: area, zones: zones}
    end

    test "analyzes zone utilization", %{area: area} do
      stats = Sites.analyze_zone_utilization(area_id: area.id)

      assert Map.has_key?(stats, :by_type)
      assert Map.has_key?(stats, :average_utilization)
      assert Map.has_key?(stats, :peak_zones)
      assert Map.has_key?(stats, :underutilized_zones)
    end

    test "finds underutilized zones", %{area: area, tenant: tenant} do
      # Create underutilized zone
      {:ok, underutilized} =
        Sites.create_zone(%{
          name: "Unused Zone",
          code: "UNUSED-001",
          area_id: area.id,
          tenant_id: tenant.id,
          # Very low usage
          metadata: %{"usage_hours" => 5}
        })

      underutilized_zones =
        Sites.find_underutilized_zones(
          area_id: area.id,
          min_usage_hours: 20
        )

      assert Enum.any?(underutilized_zones, &(&1.id == underutilized.id))
    end

    test "calculates zone efficiency metrics", %{zones: zones} do
      zone = List.first(zones)

      metrics = Sites.calculate_zone_efficiency(zone.id)

      assert Map.has_key?(metrics, :utilization_rate)
      assert Map.has_key?(metrics, :peak_occupancy_rate)
      assert Map.has_key?(metrics, :average_stay_duration)
      assert metrics.utilization_rate >= 0
      assert metrics.utilization_rate <= 100
    end

    test "generates zone usage heatmap", %{area: area} do
      heatmap =
        Sites.generate_zone_usage_heatmap(
          area_id: area.id,
          time_range: :week
        )

      assert is_map(heatmap)
      assert Map.has_key?(heatmap, :zones)
      assert Map.has_key?(heatmap, :time_slots)
      assert Map.has_key?(heatmap, :intensity_scale)
    end
  end

  describe "bulk zone operations" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id)
      {:ok, tenant: tenant, area: area}
    end

    test "bulk creates zones", %{tenant: tenant, area: area} do
      zones =
        for i <- 1..15 do
          %{
            name: "Bulk Zone #{i}",
            code: "BZ-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
            zone_type: "workstation",
            max_occupancy: 20,
            area_id: area.id,
            tenant_id: tenant.id
          }
        end

      assert {:ok, created} = Sites.bulk_create_zones(zones)
      assert length(created) == 15
    end

    test "bulk updates zone status", %{tenant: tenant, area: area} do
      # Create zones
      zones =
        for i <- 1..5 do
          {:ok, zone} =
            Sites.create_zone(%{
              name: "Status Zone #{i}",
              code: "SZ-#{i}",
              area_id: area.id,
              tenant_id: tenant.id
            })

          zone
        end

      zone_ids = Enum.map(zones, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_zones(
                 filter: [id: {:in, zone_ids}],
                 attributes: %{status: "maintenance"}
               )

      assert count == 5

      # Verify update
      updated = Sites.list_zones!(filter: [id: {:in, zone_ids}])
      assert Enum.all?(updated, &(&1.status == "maintenance"))
    end

    test "bulk enables security features", %{tenant: tenant, area: area} do
      # Create zones
      zones =
        for i <- 1..5 do
          {:ok, zone} =
            Sites.create_zone(%{
              name: "Security Zone #{i}",
              code: "SECZ-#{i}",
              area_id: area.id,
              tenant_id: tenant.id
            })

          zone
        end

      zone_ids = Enum.map(zones, & &1.id)

      assert {:ok, count} =
               Sites.bulk_update_zones(
                 filter: [id: {:in, zone_ids}],
                 attributes: %{
                   access_control_enabled: true,
                   surveillance_enabled: true,
                   badge_reader_count: 2,
                   camera_count: 3
                 }
               )

      assert count == 5
    end

    test "bulk resets zone occupancy", %{tenant: tenant, area: area} do
      # Create occupied zones
      zones =
        for i <- 1..10 do
          {:ok, zone} =
            Sites.create_zone(%{
              name: "Occupied Zone #{i}",
              code: "OCC-#{i}",
              occupancy_tracking_enabled: true,
              max_occupancy: 20,
              current_occupancy: 10 + :rand.uniform(10),
              area_id: area.id,
              tenant_id: tenant.id
            })

          zone
        end

      zone_ids = Enum.map(zones, & &1.id)

      assert {:ok, count} = Sites.bulk_reset_zone_occupancy(filter: [id: {:in, zone_ids}])

      assert count == 10

      # Verify reset
      reset_zones = Sites.list_zones!(filter: [id: {:in, zone_ids}])
      assert Enum.all?(reset_zones, &(&1.current_occupancy == 0))
    end
  end

  describe "zone validation" do
    setup do
      tenant = insert(:tenant)
      site = insert(:site, tenant_id: tenant.id)
      building = insert(:building, site_id: site.id, tenant_id: tenant.id)
      floor = insert(:floor, building_id: building.id, tenant_id: tenant.id)
      area = insert(:area, floor_id: floor.id, tenant_id: tenant.id, area_sqft: 5000)
      {:ok, tenant: tenant, area: area}
    end

    test "validates zone boundaries within area",
         %{tenant: tenant, area: area} do
      # Valid boundaries
      valid_boundaries = %{
        "type" => "rectangle",
        "coordinates" => [
          %{"x" => 0, "y" => 0},
          %{"x" => 50, "y" => 0},
          %{"x" => 50, "y" => 50},
          %{"x" => 0, "y" => 50}
        ]
      }

      attrs = %{
        name: "Valid Zone",
        code: "VALID-001",
        boundaries: valid_boundaries,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:ok, _} = Sites.create_zone(attrs)

      # Boundaries exceed area
      invalid_boundaries = %{
        "type" => "rectangle",
        "coordinates" => [
          %{"x" => 0, "y" => 0},
          %{"x" => 200, "y" => 0},
          %{"x" => 200, "y" => 200},
          %{"x" => 0, "y" => 200}
        ]
      }

      attrs = %{
        name: "Invalid Zone",
        code: "INVALID-001",
        boundaries: invalid_boundaries,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "zone boundaries exceed area limits"
    end

    test "validates zone overlaps", %{tenant: tenant, area: area} do
      # Create first zone
      boundaries1 = %{
        "type" => "rectangle",
        "coordinates" => [
          %{"x" => 0, "y" => 0},
          %{"x" => 10, "y" => 0},
          %{"x" => 10, "y" => 10},
          %{"x" => 0, "y" => 10}
        ]
      }

      {:ok, _} =
        Sites.create_zone(%{
          name: "Zone 1",
          code: "Z1",
          boundaries: boundaries1,
          area_id: area.id,
          tenant_id: tenant.id
        })

      # Try to create overlapping zone
      boundaries2 = %{
        "type" => "rectangle",
        "coordinates" => [
          %{"x" => 5, "y" => 5},
          %{"x" => 15, "y" => 5},
          %{"x" => 15, "y" => 15},
          %{"x" => 5, "y" => 15}
        ]
      }

      attrs = %{
        name: "Zone 2",
        code: "Z2",
        boundaries: boundaries2,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "zone boundaries overlap with
        existing zone"
    end

    test "validates security equipment requirements",
         %{tenant: tenant, area: area} do
      # Access control without badge readers
      attrs = %{
        name: "Insecure Zone",
        code: "INSEC-001",
        access_control_enabled: true,
        # Invalid
        badge_reader_count: 0,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "access control requires at least one badge reader"

      # Surveillance without cameras
      attrs = %{
        name: "Unmonitored Zone",
        code: "UNMON-001",
        surveillance_enabled: true,
        # Invalid
        camera_count: 0,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "surveillance requires at least one camera"
    end

    test "validates occupancy limits", %{tenant: tenant, area: area} do
      # Occupancy tracking without max occupancy
      attrs = %{
        name: "No Limit Zone",
        code: "NL-001",
        occupancy_tracking_enabled: true,
        # Invalid
        max_occupancy: nil,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "occupancy tracking requires max occupancy"

      # Current exceeds max
      attrs = %{
        name: "Over Capacity",
        code: "OC-001",
        max_occupancy: 10,
        # Invalid
        current_occupancy: 15,
        area_id: area.id,
        tenant_id: tenant.id
      }

      assert {:error, error} = Sites.create_zone(attrs)
      assert Exception.message(error) =~ "current occupancy exceeds maximum"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
