defmodule Intelitor.Sites.Zone do
  @moduledoc """
  Represents a security zone within a site or building.

  Zones define logical security boundaries that can span multiple
  physical areas and have specific monitoring and access requirements.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Sites,
    table: "zones"

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

      constraints max_length: 50,
                  match: ~S/^[A-Z][A-Z0-9_-]*$/
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :zone_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:public, :restricted, :secure, :critical, :emergency]
      default :public
    end

    attribute :security_level, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :access_control_type, :atom do
      public? true
      constraints one_of: [:open, :badge, :biometric, :multi_factor, :escort_required]
      default :open
    end

    attribute :monitoring_level, :atom do
      public? true
      constraints one_of: [:none, :motion, :continuous, :ai_enhanced]
      default :motion
    end

    attribute :allowed_roles, {:array, :string} do
      public? true
      default []
    end

    attribute :time_restrictions, :map do
      public? true
      default %{}
    end

    attribute :compliance_requirements, {:array, :string} do
      public? true
      default []
    end

    attribute :alarm_priority, :atom do
      public? true
      constraints one_of: [:low, :medium, :high, :critical]
      default :medium
    end

    attribute :auto_lockdown?, :boolean do
      public? true
      default false
    end

    attribute :visitor_allowed?, :boolean do
      public? true
      default true
    end

    attribute :recording_enabled?, :boolean do
      public? true
      default true
    end

    attribute :retention_days, :integer do
      public? true
      default 30
      constraints min: 1, max: 365
    end

    attribute :active?, :boolean do
      public? true
      default true
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

    belongs_to :building, Intelitor.Sites.Building do
      public? true
    end

    belongs_to :floor, Intelitor.Sites.Floor do
      public? true
    end

    belongs_to :parent_zone, __MODULE__ do
      public? true
    end

    has_many :child_zones, __MODULE__ do
      destination_attribute :parent_zone_id
      public? true
    end

    has_many :areas, Intelitor.Sites.Area do
      public? true
    end

    # TODO: Uncomment when Devices domain is implemented
    # has_many :devices, Intelitor.Devices.Device do
    #   public? true
    # end

    # TODO: Uncomment when Alarms domain is implemented
    # has_many :access_logs, Intelitor.Alarms.AccessLog do
    #   public? true
    # end
  end

  identities do
    identity :unique_code_per_site, [:site_id, :code]
  end

  actions do
    defaults [:read, :create, :update]
    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:active?, true)
    end

    update :deactivate do
      require_atomic? false
      accept []
      change set_attribute(:active?, false)
    end

    update :set_security_level do
      require_atomic? false
      argument :level, :atom do
        allow_nil? false
        constraints one_of: [:low, :medium, :high, :critical]
      end

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:security_level, arg(:level))

      # Adjust related settings based on security level
      change fn changeset, _context ->
        level = Ash.Changeset.get_argument(changeset, :level)

        changeset =
          case level do
            :critical ->
              changeset
              |> Ash.Changeset.change_attribute(:access_control_type, :multi_factor)
              |> Ash.Changeset.change_attribute(:monitoring_level, :ai_enhanced)
              |> Ash.Changeset.change_attribute(:alarm_priority, :critical)
              |> Ash.Changeset.change_attribute(:auto_lockdown?, true)
              |> Ash.Changeset.change_attribute(:visitor_allowed?, false)
              |> Ash.Changeset.change_attribute(:retention_days, 365)

            :high ->
              changeset
              |> Ash.Changeset.change_attribute(:access_control_type, :biometric)
              |> Ash.Changeset.change_attribute(:monitoring_level, :continuous)
              |> Ash.Changeset.change_attribute(:alarm_priority, :high)
              |> Ash.Changeset.change_attribute(:retention_days, 180)

            :medium ->
              changeset
              |> Ash.Changeset.change_attribute(:access_control_type, :badge)
              |> Ash.Changeset.change_attribute(:monitoring_level, :motion)
              |> Ash.Changeset.change_attribute(:alarm_priority, :medium)

            :low ->
              changeset
              |> Ash.Changeset.change_attribute(:monitoring_level, :none)
              |> Ash.Changeset.change_attribute(:alarm_priority, :low)
          end

        # Log the change
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        history = Map.get(metadata, "security_level_history", [])

        entry = %{
          "level" => level,
          "reason" => Ash.Changeset.get_argument(changeset, :reason),
          "timestamp" => DateTime.utc_now(),
          "changed_by" => changeset.context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "security_level_history", [entry | history])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :trigger_lockdown do
      require_atomic? false
      accept []

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:auto_lockdown?, true)

      change fn changeset, context ->
        # Trigger lockdown procedures
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        lockdowns = Map.get(metadata, "lockdown_history", [])

        entry = %{
          "triggered_at" => DateTime.utc_now(),
          "reason" => Ash.Changeset.get_argument(changeset, :reason),
          "triggered_by" => context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "lockdown_history", [entry | lockdowns])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    destroy :archive do
      require_atomic? false
      soft? true
      change set_attribute(:active?, false)
    end
  end

  calculations do
    calculate :is_high_security?, :boolean, expr(security_level in [:high, :critical])

    calculate :requires_escort?, :boolean, expr(access_control_type == :escort_required)

    calculate :area_count, :integer, expr(count(areas))

    # TODO: Uncomment when Devices domain is implemented
    # calculate :device_count, :integer, expr(count(devices))

    # calculate :active_device_count, :integer, expr(count(devices, query: [filter: expr(status == :active)]))

    calculate :access_log_count_24h, :integer do
      calculation fn records, _opts ->
        twenty_four_hours_ago = DateTime.utc_now() |> DateTime.add(-24, :hour)

        Enum.map(records, fn zone ->
          # This would need actual query implementation
          # Placeholder
          0
        end)
      end
    end

    calculate :compliance_status, :atom do
      calculation fn records, _opts ->
        Enum.map(records, fn zone ->
          # Check if all compliance requirements are met
          # This would need actual implementation based on requirements
          # Placeholder
          :compliant
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)
    validate string_length(:code, min: 2, max: 50)

    validate match(:code, ~S/^[A-Z][A-Z0-9_-]*$/) do
      message "must start with uppercase letter and contain only uppercase letters, numbers, underscores, and hyphens"
    end

    validate fn changeset, _context ->
      zone_type = Ash.Changeset.get_attribute(changeset, :zone_type)
      visitor_allowed = Ash.Changeset.get_attribute(changeset, :visitor_allowed?)

      if zone_type in [:critical, :secure] && visitor_allowed do
        {:error, field: :visitor_allowed?, message: "visitors not allowed in #{zone_type} zones"}
      else
        {:ok, changeset}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(^actor(:tenant_id) == tenant_id)
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if expr(^actor(:role) == "security_admin" and security_level != :critical)
    end

    policy action(:set_security_level) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if expr(^actor(:role) == "security_admin" and arg(:level) != :critical)
    end

    policy action(:trigger_lockdown) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      authorize_if actor_attribute_equals(:role, "security_operator")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :activate
    define :deactivate
    define :set_security_level
    define :trigger_lockdown
    define :get_by_code, action: :read, get_by: [:site_id, :code]
  end

  postgres do
    table "zones"
    repo Intelitor.Repo

    custom_indexes do
      index [:site_id, :code], unique: true
      index [:site_id, :zone_type]
      index [:site_id, :security_level]
      index [:building_id], where: "building_id IS NOT NULL"
      index [:floor_id], where: "floor_id IS NOT NULL"
      index [:parent_zone_id], where: "parent_zone_id IS NOT NULL"
      index [:active?], name: "zones_active_index", where: "active? = true"
    end
  end
end
