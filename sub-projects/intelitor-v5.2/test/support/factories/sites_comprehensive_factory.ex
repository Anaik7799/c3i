defmodule Indrajaal.SitesComprehensiveFactory do
  @moduledoc """
  Comprehensive factory definitions for Sites domain with bulk data generation.
  Implements realistic site, building, floor, area, and zone patterns for enterprise testing.

  Provides bulk creation functions for:
  - Sites with various types and regions
  - Buildings with multiple types and configurations
  - Floors with proper level assignments
  - Areas with different types and occupancy settings
  - Zones with security levels

  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  import Indrajaal.Factory

  @building_types [:main, :annex, :parking, :utility, :storage, :other]
  @floor_types [:office, :retail, :residential, :parking, :mechanical, :storage, :mixed]
  @area_types [
    :office,
    :conference_room,
    :break_room,
    :restroom,
    :storage,
    :server_room,
    :lobby,
    :hallway
  ]
  @zone_types [:public, :restricted, :secure, :critical, :emergency]
  @security_levels [:low, :medium, :high, :critical]

  @doc """
  Bulk creates sites for a given tenant.

  ## Examples

      sites = bulk_create_sites(tenant, 10)
      sites = bulk_create_sites(tenant, 50, region: :north)
  """
  @spec bulk_create_sites(map(), integer(), keyword()) :: [map()]
  def bulk_create_sites(tenant, count, opts \\ []) do
    regions = [:north, :south, :east, :west, :central]
    types = ["office", "warehouse", "retail", "manufacturing", "datacenter"]

    Enum.map(1..count, fn i ->
      attrs = %{
        tenant_id: tenant.id,
        name: "Site #{i}_#{System.unique_integer([:positive])}",
        code: "SITE-#{i}-#{System.unique_integer([:positive])}",
        description: "Test Site #{i}",
        address: %{street: "#{100 + i} Test Street"},
        timezone: "UTC",
        status: "active",
        metadata: %{
          "region" => opts |> Keyword.get(:region, Enum.random(regions)) |> to_string(),
          "type" => Keyword.get(opts, :type, Enum.random(types))
        }
      }

      insert(:site, attrs)
    end)
  end

  @doc """
  Bulk creates buildings for sites.

  ## Examples

      buildings = bulk_create_buildings(tenant, sites, 100)
  """
  @spec bulk_create_buildings(map(), [map()], integer(), keyword()) :: [map()]
  def bulk_create_buildings(tenant, sites, count, opts \\ []) do
    buildings_per_site = max(1, div(count, length(sites)))

    sites
    |> Enum.flat_map(fn site ->
      Enum.map(1..buildings_per_site, fn i ->
        attrs = %{
          tenant_id: tenant.id,
          site_id: site.id,
          name: "Building #{i}_#{System.unique_integer([:positive])}",
          code: "BLD-#{i}-#{System.unique_integer([:positive])}",
          description: "Test Building #{i}",
          building_type: Keyword.get(opts, :building_type, Enum.random(@building_types)),
          floor_count: :rand.uniform(10) + 1,
          underground_levels: :rand.uniform(3) - 1,
          total_area_sqm: :rand.uniform(10_000) + 1000.0,
          year_built: 1990 + :rand.uniform(34),
          status: :active,
          metadata: %{}
        }

        insert(:building, attrs)
      end)
    end)
    |> Enum.take(count)
  end

  @doc """
  Bulk creates floors for buildings.

  ## Examples

      floors = bulk_create_floors(tenant, buildings, 200)
  """
  @spec bulk_create_floors(map(), [map()], integer(), keyword()) :: [map()]
  def bulk_create_floors(tenant, buildings, count, opts \\ []) do
    floors_per_building = max(1, div(count, length(buildings)))

    buildings
    |> Enum.flat_map(fn building ->
      # Get the site_id from the building
      site_id = building.site_id

      Enum.map(1..floors_per_building, fn level ->
        attrs = %{
          tenant_id: tenant.id,
          building_id: building.id,
          site_id: site_id,
          name: "Floor #{level}",
          level: level,
          description: "Floor level #{level}",
          floor_type: Keyword.get(opts, :floor_type, Enum.random(@floor_types)),
          area_sqm: :rand.uniform(2000) + 500.0,
          ceiling_height_m: 2.5 + :rand.uniform() * 2,
          max_occupancy: :rand.uniform(100) + 20,
          current_occupancy: :rand.uniform(50),
          access_restricted?: :rand.uniform(10) > 8,
          metadata: %{}
        }

        insert(:floor, attrs)
      end)
    end)
    |> Enum.take(count)
  end

  @doc """
  Bulk creates zones for sites or areas.

  ## Examples

      zones = bulk_create_zones(tenant, sites, 50)
      zones = bulk_create_zones(tenant, areas, 50)  # Also works with areas
  """
  @spec bulk_create_zones(map(), [map()], integer(), keyword()) :: [map()]
  def bulk_create_zones(tenant, parents, count, opts \\ []) do
    zones_per_parent = max(1, div(count, length(parents)))

    parents
    |> Enum.flat_map(fn parent ->
      # Support both sites and areas as parents
      site_id = Map.get(parent, :site_id) || parent.id
      area_id = if Map.has_key?(parent, :floor_id), do: parent.id, else: nil

      Enum.map(1..zones_per_parent, fn i ->
        attrs = %{
          tenant_id: tenant.id,
          site_id: site_id,
          area_id: area_id,
          name: "Zone #{i}_#{System.unique_integer([:positive])}",
          code: "ZN-#{i}-#{System.unique_integer([:positive])}",
          description: "Test Zone #{i}",
          zone_type: Keyword.get(opts, :zone_type, Enum.random(@zone_types)),
          security_level: Keyword.get(opts, :security_level, Enum.random(@security_levels)),
          access_control_type: Enum.random([:open, :card_only, :biometric, :dual_auth]),
          capacity: :rand.uniform(200) + 50,
          active?: true,
          monitored?: true,
          metadata: %{}
        }

        insert(:zone, attrs)
      end)
    end)
    |> Enum.take(count)
  end

  @doc """
  Bulk creates areas for floors.

  ## Examples

      areas = bulk_create_areas(tenant, floors, 300)
  """
  @spec bulk_create_areas(map(), [map()], integer(), keyword()) :: [map()]
  def bulk_create_areas(tenant, floors, count, opts \\ []) do
    areas_per_floor = max(1, div(count, length(floors)))

    floors
    |> Enum.flat_map(fn floor ->
      # Create a zone for this floor's areas if needed
      zone =
        insert(:zone, %{
          tenant_id: tenant.id,
          site_id: floor.site_id,
          name: "Zone for Floor #{floor.level}_#{System.unique_integer([:positive])}",
          code: "ZN-FL#{floor.level}-#{System.unique_integer([:positive])}",
          zone_type: :public,
          security_level: :medium,
          access_control_type: :card_only
        })

      Enum.map(1..areas_per_floor, fn i ->
        attrs = %{
          tenant_id: tenant.id,
          site_id: floor.site_id,
          building_id: floor.building_id,
          floor_id: floor.id,
          zone_id: zone.id,
          name: "Area #{i}_#{System.unique_integer([:positive])}",
          code: "AREA-#{i}-#{System.unique_integer([:positive])}",
          description: "Test Area #{i}",
          area_type: Keyword.get(opts, :area_type, Enum.random(@area_types)),
          area_sqm: :rand.uniform(100) + 10.0,
          max_occupancy: :rand.uniform(30) + 5,
          current_occupancy: :rand.uniform(15),
          access_level: Enum.random([:public, :employees, :authorized, :restricted]),
          status: :available,
          metadata: %{}
        }

        insert(:area, attrs)
      end)
    end)
    |> Enum.take(count)
  end

  @location_types [:desk, :workstation, :storage, :equipment, :access_point, :sensor]

  @doc """
  Bulk creates locations for zones.

  ## Examples

      locations = bulk_create_locations(tenant, zones, 500)
  """
  @spec bulk_create_locations(map(), [map()], integer(), keyword()) :: [map()]
  def bulk_create_locations(tenant, zones, count, opts \\ []) do
    locations_per_zone = max(1, div(count, length(zones)))

    zones
    |> Enum.flat_map(fn zone ->
      Enum.map(1..locations_per_zone, fn i ->
        attrs = %{
          tenant_id: tenant.id,
          zone_id: zone.id,
          site_id: zone.site_id,
          name: "Location #{i}_#{System.unique_integer([:positive])}",
          location_type: Keyword.get(opts, :location_type, Enum.random(@location_types)),
          coordinates: %{
            "x" => :rand.uniform() * 100,
            "y" => :rand.uniform() * 100,
            "z" => 0
          },
          metadata: %{}
        }

        insert(:location, attrs)
      end)
    end)
    |> Enum.take(count)
  end

  @doc """
  Creates a complete site hierarchy with buildings, floors, zones, and areas.

  ## Examples

      hierarchy = create_site_hierarchy(tenant, sites: 2, buildings_per_site: 3)
  """
  @spec create_site_hierarchy(map(), keyword()) :: map()
  def create_site_hierarchy(tenant, opts \\ []) do
    site_count = Keyword.get(opts, :sites, 1)
    buildings_per_site = Keyword.get(opts, :buildings_per_site, 2)
    floors_per_building = Keyword.get(opts, :floors_per_building, 3)
    areas_per_floor = Keyword.get(opts, :areas_per_floor, 5)

    sites = bulk_create_sites(tenant, site_count)
    buildings = bulk_create_buildings(tenant, sites, site_count * buildings_per_site)
    floors = bulk_create_floors(tenant, buildings, length(buildings) * floors_per_building)
    areas = bulk_create_areas(tenant, floors, length(floors) * areas_per_floor)

    %{
      sites: sites,
      buildings: buildings,
      floors: floors,
      areas: areas
    }
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.11 Compliance: Site factory bulk generation for comprehensive testing
# Domain: Sites/Testing
# Responsibilities: Bulk site data generation, hierarchy creation
# Multi-Agent Architecture: Integrated with factory infrastructure
# Cybernetic Feedback: Active feedback loops for test data quality
