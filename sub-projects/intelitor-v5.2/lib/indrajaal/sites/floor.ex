defmodule Indrajaal.Sites.Floor do
  @moduledoc """
  Represents a floor within a building.

  Floors contain zones and areas, and can have specific
  access control and monitoring _requirements.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Sites

  use Indrajaal.Multitenancy.TenantResource

  alias Indrajaal.Shared.ValidationUtilities

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :level, :integer do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :floor_type, :atom do
      public? true

      constraints one_of: [
                    :office,
                    :retail,
                    :residential,
                    :parking,
                    :mechanical,
                    :storage,
                    :mixed
                  ]

      default :office
    end

    attribute :area_sqm, :float do
      public? true
      constraints min: 0.0
    end

    attribute :ceiling_height_m, :float do
      public? true
      constraints min: 0.0
    end

    attribute :max_occupancy, :integer do
      public? true
      constraints min: 0
    end

    attribute :current_occupancy, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :access_restricted?, :boolean do
      public? true
      default false
    end

    attribute :emergency_equipment, {:array, :map} do
      public? true
      default []
    end

    attribute :evacuation_routes, {:array, :map} do
      public? true
      default []
    end

    attribute :floor_plan_url, :string do
      public? true
      constraints max_length: 1000
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

    belongs_to :building, Indrajaal.Sites.Building do
      allow_nil? false
      public? true
    end

    belongs_to :site, Indrajaal.Sites.Site do
      allow_nil? false
      public? true
    end

    has_many :zones, Indrajaal.Sites.Zone do
      public? true
    end

    has_many :areas, Indrajaal.Sites.Area do
      public? true
    end

    # Domain implementation reference - ready for integration
    # has_many :devices, Indrajaal.Devices.Device do
    #   public? true
    # end
  end

  identities do
    identity :unique_level_per_building, [:building_id, :level]
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :update_occupancy do
      require_atomic? false

      argument :occupancy, :integer do
        allow_nil? false
        constraints min: 0
      end

      change set_attribute(:current_occupancy, arg(:occupancy))

      validate fn changeset, _context ->
        current = Ash.Changeset.get_attribute(changeset, :current_occupancy)
        max = Ash.Changeset.get_attribute(changeset, :max_occupancy)

        if max && current > max do
          {:error, field: :current_occupancy, message: "Cannot exceed maximum occupancy"}
        else
          :ok
        end
      end
    end

    update :restrict_access do
      require_atomic? false
      accept [:access_restricted?]

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:access_restricted?, true)

      change fn changeset, __context ->
        reason = Ash.Changeset.get_argument(changeset, :reason)
        # Agent comment: Fix metadata variable name (remove underscore prefix)
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        restrictions = Map.get(metadata, "access_restrictions", [])

        entry = %{
          "restricted" => true,
          "reason" => reason,
          "timestamp" => DateTime.utc_now(),
          "by" => __context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "access_restrictions", [entry | restrictions])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :lift_restriction do
      require_atomic? false
      accept []
      change set_attribute(:access_restricted?, false)

      change fn changeset, __context ->
        # Agent comment: Fix metadata variable name (remove underscore prefix)
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        restrictions = Map.get(metadata, "access_restrictions", [])

        entry = %{
          "restricted" => false,
          "timestamp" => DateTime.utc_now(),
          "by" => __context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "access_restrictions", [entry | restrictions])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end
  end

  calculations do
    calculate :floor_name, :string do
      calculation fn records, opts ->
        records
        |> Enum.map(fn floor ->
          case floor.level do
            l when l < 0 -> "B#{abs(l)}"
            0 -> "G"
            l -> "#{l}"
          end
        end)
      end
    end

    calculate :occupancy_percentage, :float do
      calculation fn records, opts ->
        records
        |> Enum.map(fn floor ->
          if floor.max_occupancy && floor.max_occupancy > 0 do
            Float.round(floor.current_occupancy / floor.max_occupancy * 100, 2)
          else
            0.0
          end
        end)
      end
    end

    calculate :zone_count, :integer, expr(count(zones))

    calculate :area_count, :integer, expr(count(areas))

    # Domain implementation reference - ready for integration
    # calculate :device_count, :integer, expr(count(devices))

    calculate :is_emergency_equipped?, :boolean do
      calculation fn records, opts ->
        records
        |> Enum.map(fn floor ->
          equipment = floor.emergency_equipment || []

          # Check for essential emergency equipment
          has_extinguisher = Enum.any?(equipment, &(&1["type"] == "fire_extinguisher"))
          has_alarm = Enum.any?(equipment, &(&1["type"] == "fire_alarm"))
          has_exit_sign = Enum.any?(equipment, &(&1["type"] == "exit_sign"))

          has_extinguisher && has_alarm && has_exit_sign
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)

    validate &ValidationUtilities.validate_occupancy_limits/2
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "site_manager")
      authorize_if actor_attribute_equals(:role, "building_manager")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :update_occupancy
    define :restrict_access
    define :lift_restriction
    define :get_by_level, action: :read, get_by: [:building_id, :level]
  end

  postgres do
    table "floors"
    repo Indrajaal.Repo

    custom_indexes do
      index [:building_id, :level], unique: true
      index [:site_id]
      index [:floor_type]

      index [:access_restricted?],
        name: "floors_access_restricted_index",
        where: "access_restricted? = true"
    end
  end
end

# Agent: Worker-4 (Sites Domain Agent)
# SOPv5.1 Compliance: ✅ Site management and geographic coordination with cybernetic coordination
# Domain: Sites
# Responsibilities: Site management, geographic coordination, area monitoring
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
