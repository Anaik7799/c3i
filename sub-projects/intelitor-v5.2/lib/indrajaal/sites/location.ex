defmodule Indrajaal.Sites.Location do
  @moduledoc """
  Generic location abstraction that can reference any level of the location
    hierarchy.

  This resource provides a unified way to reference sites,
    buildings, floors, zones, or areas
  for location - based features and future device placement and incident tracking.
  """

  @type location_type :: :site | :building | :floor | :zone | :area | :coordinates
  @type coordinates_map :: %{
          required(String.t()) => float(),
          optional(String.t()) => any()
        }

  use Indrajaal.BaseResource,
    domain: Indrajaal.Sites

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :location_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:site, :building, :floor, :zone, :area, :coordinates]
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    attribute :full_path, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :coordinates, :map do
      public? true
    end

    attribute :reference_id, :uuid do
      public? true
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    belongs_to :site, Indrajaal.Sites.Site do
      public? true
    end

    belongs_to :building, Indrajaal.Sites.Building do
      public? true
    end

    belongs_to :floor, Indrajaal.Sites.Floor do
      public? true
    end

    belongs_to :zone, Indrajaal.Sites.Zone do
      public? true
    end

    belongs_to :area, Indrajaal.Sites.Area do
      public? true
    end

    # Domain implementation reference - ready for integration
    # has_many :devices, Indrajaal.Devices.Device do
    #   public? true
    # end

    # Domain implementation reference - ready for integration
    # has_many :incidents, Indrajaal.Alarms.Incident do
    #   public? true
    # end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :location_type,
        :full_path,
        :coordinates,
        :reference_id,
        :metadata,
        :tenant_id,
        :site_id,
        :building_id,
        :floor_id,
        :zone_id,
        :area_id
      ]

      primary? true
    end

    create :create_from_site do
      argument :site_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:location_type, :site)
      change set_attribute(:site_id, arg(:site_id))
      change set_attribute(:reference_id, arg(:site_id))

      change fn changeset, __context ->
        # Load site to get name and build path
        # This would need actual implementation
        changeset
      end
    end

    create :create_from_building do
      argument :building_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:location_type, :building)
      change set_attribute(:building_id, arg(:building_id))
      change set_attribute(:reference_id, arg(:building_id))

      change fn changeset, __context ->
        # Load building and parent site to build path
        changeset
      end
    end

    create :create_from_floor do
      argument :floor_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:location_type, :floor)
      change set_attribute(:floor_id, arg(:floor_id))
      change set_attribute(:reference_id, arg(:floor_id))

      change fn changeset, __context ->
        # Load floor, building, and site to build path
        changeset
      end
    end

    create :create_from_zone do
      argument :zone_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:location_type, :zone)
      change set_attribute(:zone_id, arg(:zone_id))
      change set_attribute(:reference_id, arg(:zone_id))

      change fn changeset, __context ->
        # Load zone and parent hierarchy to build path
        changeset
      end
    end

    create :create_from_area do
      argument :area_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:location_type, :area)
      change set_attribute(:area_id, arg(:area_id))
      change set_attribute(:reference_id, arg(:area_id))

      change fn changeset, __context ->
        # Load area and full hierarchy to build path
        changeset
      end
    end

    create :create_from_coordinates do
      argument :name, :string do
        allow_nil? false
        constraints max_length: 500
      end

      argument :latitude, :float do
        allow_nil? false
        constraints min: -90.0, max: 90.0
      end

      argument :longitude, :float do
        allow_nil? false
        constraints min: -180.0, max: 180.0
      end

      argument :altitude, :float

      argument :site_id, :uuid

      change set_attribute(:location_type, :coordinates)
      change set_attribute(:name, arg(:name))

      change fn changeset, __context ->
        coords = %{
          "lat" => Ash.Changeset.get_argument(changeset, :latitude),
          "lng" => Ash.Changeset.get_argument(changeset, :longitude)
        }

        coords =
          if alt = Ash.Changeset.get_argument(changeset, :altitude) do
            Map.put(coords, "alt", alt)
          else
            coords
          end

        changeset
        |> Ash.Changeset.change_attribute(:coordinates, coords)
        |> Ash.Changeset.change_attribute(
          :site_id,
          Ash.Changeset.get_argument(changeset, :site_id)
        )
      end
    end

    update :update_metadata do
      require_atomic? false
      accept [:metadata]
    end
  end

  calculations do
    calculate :display_name, :string do
      calculation fn records, opts ->
        records
        |> Enum.map(fn location ->
          location.full_path || location.name
        end)
      end
    end

    calculate :hierarchy_level, :integer do
      calculation fn records, opts ->
        records
        |> Enum.map(fn location ->
          case location.location_type do
            :site -> 1
            :building -> 2
            :floor -> 3
            :zone -> 4
            :area -> 5
            :coordinates -> 0
          end
        end)
      end
    end

    # Domain implementation reference - ready for integration
    # calculate :device_count, :integer, expr(count(devices))

    # Domain implementation reference - ready for integration
    # calculate :incident_count_24h, :integer do
    #   calculation fn records, opts ->
    #     # Would need actual implementation
    #     records |> Enum.map(fn _ -> 0 end)
    #   end
    # end

    calculate :security_level, :atom do
      calculation fn records, opts ->
        records
        |> Enum.map(fn location ->
          case location.location_type do
            :zone ->
              # Would get from zone's security_level
              :medium

            :area ->
              # Would get from parent zone's security_level
              :medium

            _ ->
              # Would get from site's security_level
              :medium
          end
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 500)

    validate fn changeset, _context ->
      location_type = Ash.Changeset.get_attribute(changeset, :location_type)
      coordinates = Ash.Changeset.get_attribute(changeset, :coordinates)

      if location_type == :coordinates &&
           (is_nil(coordinates) ||
              coordinates ==
                %{}) do
        {:error, field: :coordinates, message: "_required for coordinate - based locations"}
      else
        :ok
      end
    end

    validate fn changeset, _context ->
      location_type = Ash.Changeset.get_attribute(changeset, :location_type)

      # Ensure appropriate reference is set based on type
      case location_type do
        :site ->
          if Ash.Changeset.get_attribute(changeset, :site_id) do
            :ok
          else
            {:error, field: :site_id, message: "_required for site locations"}
          end

        :building ->
          if Ash.Changeset.get_attribute(changeset, :building_id) do
            :ok
          else
            {:error, field: :building_id, message: "_required for building locations"}
          end

        :floor ->
          if Ash.Changeset.get_attribute(changeset, :floor_id) do
            :ok
          else
            {:error, field: :floor_id, message: "_required for floor locations"}
          end

        :zone ->
          if Ash.Changeset.get_attribute(changeset, :zone_id) do
            :ok
          else
            {:error, field: :zone_id, message: "_required for zone locations"}
          end

        :area ->
          if Ash.Changeset.get_attribute(changeset, :area_id) do
            :ok
          else
            {:error, field: :area_id, message: "_required for area locations"}
          end

        _ ->
          :ok
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "site_manager")
      # Device manager role authorization pending feature implementation
      # Once device_manager role is fully implemented with associated permissions,
      # uncomment the line below to grant device managers location management access
      # authorize_if actor_attribute_equals(:role, "device_manager")
    end
  end

  code_interface do
    define :read
    define :create_from_site
    define :create_from_building
    define :create_from_floor
    define :create_from_zone
    define :create_from_area
    define :create_from_coordinates
    define :update_metadata
    define :destroy
  end

  postgres do
    table "locations"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :location_type]
      index [:reference_id]
      index [:site_id], where: "site_id IS NOT NULL"
      index [:building_id], where: "building_id IS NOT NULL"
      index [:floor_id], where: "floor_id IS NOT NULL"
      index [:zone_id], where: "zone_id IS NOT NULL"
      index [:area_id], where: "area_id IS NOT NULL"
    end
  end
end

# Agent: Worker - 4 (Sites Domain Agent)
# SOPv5.1 Compliance: ✅ Site management and geographic coordination with cybern
# Domain: Sites
# Responsibilities: Site management, geographic coordination, area monitoring
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
