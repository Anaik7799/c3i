defmodule Intelitor.Sites.Building do
  @moduledoc """
  Represents a building within a site.

  Buildings contain floors and can have their own security parameters
  and access control requirements.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Sites,
    table: "buildings"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
    end

    attribute :code, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :building_type, :atom do
      public? true
      constraints one_of: [:main, :annex, :parking, :utility, :storage, :other]
      default :main
    end

    attribute :floor_count, :integer do
      public? true
      default 1
      constraints min: 1
    end

    attribute :underground_levels, :integer do
      public? true
      default 0
      constraints min: 0
    end

    attribute :total_area_sqm, :float do
      public? true
      constraints min: 0.0
    end

    attribute :year_built, :integer do
      public? true
      constraints min: 1800, max: 2100
    end

    attribute :last_renovation, :integer do
      public? true
      constraints min: 1800, max: 2100
    end

    attribute :access_points, {:array, :map} do
      public? true
      default []
    end

    attribute :emergency_exits, {:array, :map} do
      public? true
      default []
    end

    attribute :amenities, {:array, :string} do
      public? true
      default []
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:active, :maintenance, :renovation, :closed]
      default :active
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :site, Intelitor.Sites.Site do
      allow_nil? false
      public? true
    end

    has_many :floors, Intelitor.Sites.Floor do
      public? true
    end

    has_many :zones, Intelitor.Sites.Zone do
      public? true
    end

    # TODO: Uncomment when Devices domain is implemented
    # has_many :devices, Intelitor.Devices.Device do
    #   public? true
    # end
  end

  identities do
    identity :unique_code_per_site, [:site_id, :code]
  end

  actions do
    defaults [:read, :create, :update, :destroy]
    update :set_status do
      require_atomic? false
      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:active, :maintenance, :renovation, :closed]
      end

      argument :reason, :string do
        constraints max_length: 500
      end

      change set_attribute(:status, arg(:status))

      # Create status history entry when status changes
      change fn changeset, _context ->
        if Ash.Changeset.changing_attribute?(changeset, :status) do
          old_status = changeset.data.status
          new_status = Ash.Changeset.get_attribute(changeset, :status)
          reason = Ash.Changeset.get_argument(changeset, :reason)

          # In a real implementation, this would create a status history record
          # For now, we'll add the change to metadata
          metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
          status_history = Map.get(metadata, "status_history", [])

          new_entry = %{
            "from_status" => old_status,
            "to_status" => new_status,
            "reason" => reason,
            "changed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }

          updated_metadata = Map.put(metadata, "status_history", [new_entry | status_history])
          Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
        else
          changeset
        end
      end
    end
  end

  calculations do
    calculate :is_active?, :boolean, expr(status == :active)

    calculate :total_floors, :integer, expr(floor_count + underground_levels)

    calculate :floor_numbers, {:array, :string} do
      calculation fn records, _opts ->
        Enum.map(records, fn building ->
          underground = for i <- building.underground_levels..1, i > 0, do: "B#{i}"
          above_ground = for i <- 1..building.floor_count, do: "#{i}"
          Enum.reverse(underground) ++ above_ground
        end)
      end
    end

    calculate :zone_count, :integer, expr(count(zones))

    # TODO: Uncomment when Devices domain is implemented
    # calculate :device_count, :integer, expr(count(devices))

    calculate :needs_renovation?, :boolean do
      calculation fn records, _opts ->
        current_year = Date.utc_today().year

        Enum.map(records, fn building ->
          last_work = building.last_renovation || building.year_built
          last_work && current_year - last_work > 20
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)
    validate string_length(:code, min: 1, max: 50)

    validate fn changeset, _context ->
      year_built = Ash.Changeset.get_attribute(changeset, :year_built)
      last_renovation = Ash.Changeset.get_attribute(changeset, :last_renovation)

      if year_built && last_renovation && last_renovation < year_built do
        {:error, field: :last_renovation, message: "cannot be before year built"}
      else
        {:ok, changeset}
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
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :set_status
    define :list_by_site, action: :read, args: [:site_id]
  end

  postgres do
    table "buildings"
    repo Intelitor.Repo

    custom_indexes do
      index [:site_id, :code], unique: true
      index [:site_id, :status]
      index [:building_type]
    end
  end
end
