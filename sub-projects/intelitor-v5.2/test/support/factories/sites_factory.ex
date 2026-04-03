import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.SitesFactory do
  @moduledoc """
  Factory definitions for Sites domain.
  Created as part of HYPERSPEED Wave 1 factory infrastructure.
  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  defmacro __using__(_) do
    quote do
      @spec site_factory(any()) :: any()
      def site_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle organization dependency - create one if not provided
        # Note: Call factory function directly, not insert/2, because Ash factories
        # return already-persisted records and ExMachina insert would try to re-insert
        organization_id =
          cond do
            Map.has_key?(attrs_map, :organization_id) ->
              attrs_map[:organization_id]

            Map.has_key?(attrs_map, :organization) ->
              attrs_map[:organization].id

            true ->
              org = organization_factory(%{tenant: tenant})
              org.id
          end

        site_attrs =
          %{
            name: sequence(:site_name, fn n -> "Site #{n}" end),
            code: sequence(:site_code, fn n -> "SITE-#{n}" end),
            description: "Test Site Description",
            address: %{street: "123 Test St"},
            timezone: "UTC",
            status: "active",
            metadata: %{},
            tenant_id: tenant.id,
            organization_id: organization_id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:organization)
          |> Map.delete(:settings)
          |> Map.delete(:active)
          |> Map.delete(:city)
          |> Map.delete(:country)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, site} =
          Ash.create(
            Indrajaal.Sites.Site,
            site_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        site
      end

      @spec building_factory(any()) :: any()
      def building_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle site dependency
        site =
          case Map.pop(attrs_map, :site) do
            {nil, _} ->
              case Map.get(attrs_map, :site_id) do
                nil -> insert(:site, tenant_id: tenant.id)
                _site_id -> nil
              end

            {site, _} ->
              site
          end

        building_attrs =
          %{
            name: sequence(:building_name, fn n -> "Building #{n}" end),
            code: sequence(:building_code, fn n -> "BLD-#{n}" end),
            description: "Test Building",
            building_type: :main,
            floor_count: 3,
            underground_levels: 1,
            total_area_sqm: 5000.0,
            year_built: 2020,
            status: :active,
            metadata: %{},
            tenant_id: tenant.id,
            site_id: if(site, do: site.id, else: attrs_map[:site_id])
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:site)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, building} =
          Ash.create(
            Indrajaal.Sites.Building,
            building_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        building
      end

      @spec floor_factory(any()) :: any()
      def floor_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle building dependency (which creates site if needed)
        building =
          case Map.pop(attrs_map, :building) do
            {nil, _} ->
              case Map.get(attrs_map, :building_id) do
                nil -> insert(:building, tenant_id: tenant.id)
                _building_id -> nil
              end

            {building, _} ->
              building
          end

        # Get site_id from building if not provided
        site_id =
          cond do
            Map.has_key?(attrs_map, :site_id) -> attrs_map[:site_id]
            building -> building.site_id
            true -> insert(:site, tenant_id: tenant.id).id
          end

        floor_attrs =
          %{
            name: sequence(:floor_name, fn n -> "Floor #{n}" end),
            level: sequence(:floor_level, fn n -> n end),
            description: "Test Floor",
            floor_type: :office,
            area_sqm: 1000.0,
            ceiling_height_m: 3.0,
            max_occupancy: 50,
            current_occupancy: 0,
            access_restricted?: false,
            metadata: %{},
            tenant_id: tenant.id,
            building_id: if(building, do: building.id, else: attrs_map[:building_id]),
            site_id: site_id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:building)
          |> Map.delete(:site)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, floor} =
          Ash.create(
            Indrajaal.Sites.Floor,
            floor_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        floor
      end

      unquote(sites_factory_part_2())
    end
  end

  defp sites_factory_part_2 do
    quote do
      @spec zone_factory(any()) :: any()
      def zone_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle site dependency
        site =
          case Map.pop(attrs_map, :site) do
            {nil, _} ->
              case Map.get(attrs_map, :site_id) do
                nil -> insert(:site, tenant_id: tenant.id)
                _site_id -> nil
              end

            {site, _} ->
              site
          end

        # Handle optional building dependency
        building_id =
          case Map.pop(attrs_map, :building) do
            {nil, _} -> Map.get(attrs_map, :building_id)
            {%{id: id}, _} -> id
          end

        zone_attrs =
          %{
            name: sequence(:zone_name, fn n -> "Zone #{n}" end),
            code: sequence(:zone_code, fn n -> "ZN-#{n}" end),
            description: "Test Zone",
            zone_type: :public,
            security_level: :medium,
            access_control_type: :card_only,
            capacity: 100,
            active?: true,
            monitored?: true,
            metadata: %{},
            tenant_id: tenant.id,
            site_id: if(site, do: site.id, else: attrs_map[:site_id]),
            building_id: building_id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:site)
          |> Map.delete(:building)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, zone} =
          Ash.create(
            Indrajaal.Sites.Zone,
            zone_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        zone
      end

      @spec area_factory(any()) :: any()
      def area_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle zone dependency (creates site if needed)
        zone =
          case Map.pop(attrs_map, :zone) do
            {nil, _} ->
              case Map.get(attrs_map, :zone_id) do
                nil -> insert(:zone, tenant_id: tenant.id)
                _zone_id -> nil
              end

            {zone, _} ->
              zone
          end

        # Get site_id from zone if not provided
        site_id =
          cond do
            Map.has_key?(attrs_map, :site_id) -> attrs_map[:site_id]
            zone -> zone.site_id
            true -> insert(:site, tenant_id: tenant.id).id
          end

        # Handle optional building and floor dependencies
        building_id =
          case Map.pop(attrs_map, :building) do
            {nil, _} -> Map.get(attrs_map, :building_id)
            {%{id: id}, _} -> id
          end

        floor_id =
          case Map.pop(attrs_map, :floor) do
            {nil, _} -> Map.get(attrs_map, :floor_id)
            {%{id: id}, _} -> id
          end

        area_attrs =
          %{
            name: sequence(:area_name, fn n -> "Area #{n}" end),
            code: sequence(:area_code, fn n -> "AREA-#{n}" end),
            description: "Test Area",
            area_type: :office,
            area_sqm: 50.0,
            max_occupancy: 10,
            current_occupancy: 0,
            access_level: :employees,
            climate_controlled?: true,
            has_windows?: false,
            emergency_exit?: false,
            booking_enabled?: false,
            status: :available,
            metadata: %{},
            tenant_id: tenant.id,
            site_id: site_id,
            zone_id: if(zone, do: zone.id, else: attrs_map[:zone_id]),
            building_id: building_id,
            floor_id: floor_id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:site)
          |> Map.delete(:zone)
          |> Map.delete(:building)
          |> Map.delete(:floor)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, area} =
          Ash.create(
            Indrajaal.Sites.Area,
            area_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        area
      end

      @spec location_factory(any()) :: any()
      def location_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        # Handle site dependency
        site =
          case Map.pop(attrs_map, :site) do
            {nil, _} ->
              case Map.get(attrs_map, :site_id) do
                nil -> insert(:site, tenant_id: tenant.id)
                _site_id -> nil
              end

            {site, _} ->
              site
          end

        location_attrs =
          %{
            name: sequence(:location_name, fn n -> "Location #{n}" end),
            code: sequence(:location_code, fn n -> "LOC-#{n}" end),
            description: "Test Location",
            location_type: :point,
            coordinates: %{latitude: 40.7128, longitude: -74.0060},
            metadata: %{},
            tenant_id: tenant.id,
            site_id: if(site, do: site.id, else: attrs_map[:site_id])
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:site)

        system_admin = %{id: "system", is_system_admin: true}

        {:ok, location} =
          Ash.create(
            Indrajaal.Sites.Location,
            location_attrs,
            action: :create,
            authorize?: false,
            actor: system_admin
          )

        location
      end
    end
  end
end

# Agent: Worker-4 (Sites Domain Agent)
# SOPv5.11 Compliance: Sites domain factory definitions
# Domain: Sites/Testing
# Responsibilities: Site, building, floor, zone, area, location factory generation
# Multi-Agent Architecture: Integrated with factory infrastructure
# Cybernetic Feedback: Active feedback loops for test data quality
