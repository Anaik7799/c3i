defmodule Indrajaal.AssetManagement.AssetLocation do
  @moduledoc """
  Physical and logical locations for asset placement tracking.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AssetManagement

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    attribute :location_type, :atom do
      constraints one_of: [
                    :building,
                    :floor,
                    :room,
                    :rack,
                    :desk,
                    :vehicle,
                    :warehouse,
                    :storage,
                    :field,
                    :virtual
                  ]

      allow_nil? false
    end

    attribute :location_code, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :address, :string do
      constraints max_length: 500
    end

    attribute :latitude, :decimal do
      constraints precision: 10, scale: 8
    end

    attribute :longitude, :decimal do
      constraints precision: 11, scale: 8
    end

    attribute :capacity, :integer do
      constraints min: 1
    end

    attribute :current_utilization, :integer do
      default 0
      constraints min: 0
    end

    attribute :environmental_conditions, :map do
      default %{}
    end

    attribute :access_restrictions, {:array, :string} do
      default []
    end

    attribute :is_secure, :boolean do
      default false
    end

    attribute :is_active, :boolean do
      default true
    end

    timestamps()
  end

  relationships do
    belongs_to :parent_location, Indrajaal.AssetManagement.AssetLocation do
      attribute_writable? true
    end

    belongs_to :site, Indrajaal.Sites.Site do
      attribute_writable? true
    end

    has_many :child_locations, Indrajaal.AssetManagement.AssetLocation do
      destination_attribute :parent_location_id
    end

    has_many :assets, Indrajaal.AssetManagement.Asset do
      destination_attribute :current_location_id
    end
  end

  calculations do
    calculate :utilization_percentage, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.capacity && record.capacity > 0 do
            current = record.current_utilization || 0
            Decimal.div(Decimal.mult(current, 100), record.capacity)
          else
            nil
          end
        end)
      end
    end

    calculate :available_capacity, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.capacity do
            current = record.current_utilization || 0
            record.capacity - current
          else
            nil
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    create :create_location do
      argument :name, :string do
        allow_nil? false
      end

      argument :location_code, :string do
        allow_nil? false
      end

      argument :location_type, :atom do
        allow_nil? false
      end

      change set_attribute(:name, arg(:name))
      change set_attribute(:location_code, arg(:location_code))
      change set_attribute(:location_type, arg(:location_type))
    end

    update :update_utilization do
      require_atomic? false

      argument :utilization_change, :integer do
        allow_nil? false
      end

      change fn changeset, _ ->
        current = changeset.data.current_utilization || 0
        change = Ash.Changeset.get_argument(changeset, :utilization_change)
        new_utilization = max(0, current + change)
        Ash.Changeset.change_attribute(changeset, :current_utilization, new_utilization)
      end
    end

    update :set_coordinates do
      require_atomic? false

      argument :latitude, :decimal do
        allow_nil? false
      end

      argument :longitude, :decimal do
        allow_nil? false
      end

      change set_attribute(:latitude, arg(:latitude))
      change set_attribute(:longitude, arg(:longitude))
    end

    update :activate do
      require_atomic? false
      change set_attribute(:is_active, true)
    end

    update :deactivate do
      require_atomic? false
      change set_attribute(:is_active, false)
    end
  end

  validations do
    validate compare(:current_utilization, less_than_or_equal_to: :capacity),
      message: "Current utilization cannot exceed capacity",
      where: [present(:capacity)]
  end

  code_interface do
    define :create
    define :create_location
    define :update_utilization
    define :set_coordinates
    define :activate
    define :deactivate
  end

  postgres do
    table "asset_locations"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :location_code], unique: true
      index [:tenant_id, :location_type]
      index [:tenant_id, :is_active]
      index [:tenant_id, :parent_location_id]
      index [:tenant_id, :site_id]

      index [:tenant_id, :latitude, :longitude],
        where: "latitude IS NOT NULL AND longitude IS NOT NULL"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
