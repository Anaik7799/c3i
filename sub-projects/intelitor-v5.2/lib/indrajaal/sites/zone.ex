defmodule Indrajaal.Sites.Zone do
  @moduledoc """
  Represents a security zone within a site or building.

  Zones define logical security boundaries that can span multiple
  physical areas and have specific monitoring and access _requirements.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Sites

  use Indrajaal.Multitenancy.TenantResource

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
      constraints max_length: 50, match: ~S/^[A - Z][A - Z0 - 9_-]*$/
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
      allow_nil? false
      public? true
      constraints one_of: [:open, :card_only, :biometric, :dual_auth, :manual_approval]
      default :card_only
    end

    attribute :capacity, :integer do
      public? true
      constraints min: 0
    end

    attribute :active?, :boolean do
      public? true
      default true
    end

    attribute :monitored?, :boolean do
      public? true
      default true
    end

    attribute :environmental_controls, :map do
      public? true
      default %{}
    end

    attribute :emergency_procedures, {:array, :map} do
      public? true
      default []
    end

    attribute :operating_hours, :map do
      public? true
      default %{}
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
      allow_nil? false
      public? true
    end

    belongs_to :building, Indrajaal.Sites.Building do
      public? true
    end

    belongs_to :floor, Indrajaal.Sites.Floor do
      public? true
    end

    belongs_to :parent_zone, __MODULE__ do
      public? true
    end

    has_many :child_zones, __MODULE__ do
      destination_attribute :parent_zone_id
      public? true
    end

    has_many :areas, Indrajaal.Sites.Area do
      public? true
    end

    # Domain implementation reference - ready for integration
    # has_many :devices, Indrajaal.Devices.Device do
    #   public? true
    # end

    # Domain implementation reference - ready for integration
    # has_many :access_points, Indrajaal.AccessControl.AccessPoint do
    #   public? true
    # end
  end

  identities do
    identity :unique_code_per_site, [:site_id, :code]
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :set_security_level do
      require_atomic? false

      argument :level, :atom do
        allow_nil? false
        constraints one_of: [:low, :medium, :high, :critical]
      end

      argument :reason, :string do
        constraints max_length: 500
      end

      change set_attribute(:security_level, arg(:level))

      change fn changeset, __context ->
        level = Ash.Changeset.get_argument(changeset, :level)
        # Agent comment: Fix metadata variable name (remove underscore prefix)
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        history = Map.get(metadata, "security_level_history", [])

        entry = %{
          "level" => level,
          "reason" => Ash.Changeset.get_argument(changeset, :reason),
          "timestamp" => DateTime.utc_now(),
          "changed_by" => __context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "security_level_history", [entry | history])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    update :trigger_lockdown do
      require_atomic? false

      argument :reason, :string do
        allow_nil? false
        constraints max_length: 500
      end

      change set_attribute(:active?, true)

      change fn changeset, __context ->
        # Trigger lockdown procedures
        # Agent comment: Fix metadata variable name (remove underscore prefix)
        metadata = Ash.Changeset.get_attribute(changeset, :metadata) || %{}
        lockdowns = Map.get(metadata, "lockdown_history", [])

        entry = %{
          "triggered_at" => DateTime.utc_now(),
          "reason" => Ash.Changeset.get_argument(changeset, :reason),
          "triggered_by" => __context[:actor][:id]
        }

        updated_metadata = Map.put(metadata, "lockdown_history", [entry | lockdowns])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    destroy :archive do
      require_atomic? false
      change set_attribute(:active?, false)
    end
  end

  calculations do
    calculate :is_secure?, :boolean do
      calculation fn records, opts ->
        records
        |> Enum.map(fn zone ->
          zone.security_level in [:high, :critical]
        end)
      end
    end

    calculate :has_parent?, :boolean, expr(not is_nil(parent_zone_id))

    calculate :child_zone_count, :integer, expr(count(child_zones))

    calculate :area_count, :integer, expr(count(areas))

    # Domain implementation reference - ready for integration
    # calculate :device_count, :integer, expr(count(devices))

    calculate :is_operational?, :boolean do
      calculation fn records, opts ->
        records
        |> Enum.map(fn zone ->
          zone.active? && zone.monitored?
        end)
      end
    end

    calculate :security_score, :integer do
      calculation fn records, opts ->
        records
        |> Enum.map(fn zone ->
          base_score =
            case zone.security_level do
              :low -> 25
              :medium -> 50
              :high -> 75
              :critical -> 100
            end

          # Adjust based on zone type
          type_modifier =
            case zone.zone_type do
              :public -> 0
              :restricted -> 10
              :secure -> 20
              :critical -> 30
              :emergency -> 40
            end

          # Adjust based on access control
          access_modifier =
            case zone.access_control_type do
              :open -> -10
              :card_only -> 0
              :biometric -> 10
              :dual_auth -> 20
              :manual_approval -> 30
            end

          min(100, max(0, base_score + type_modifier + access_modifier))
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)
    validate string_length(:code, min: 1, max: 50)

    validate fn changeset, _context ->
      capacity = Ash.Changeset.get_attribute(changeset, :capacity)
      zone_type = Ash.Changeset.get_attribute(changeset, :zone_type)

      # Emergency zones must have capacity defined
      if zone_type == :emergency && is_nil(capacity) do
        {:error, field: :capacity, message: "Emergency zones must have defined capacity"}
      else
        :ok
      end
    end

    validate fn changeset, _context ->
      security_level = Ash.Changeset.get_attribute(changeset, :security_level)
      access_control_type = Ash.Changeset.get_attribute(changeset, :access_control_type)

      # Critical security level _requires biometric or dual auth
      if security_level == :critical && access_control_type in [:open, :card_only] do
        {:error,
         field: :access_control_type,
         message: "Critical security zones require biometric or dual authentication"}
      else
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
      authorize_if actor_attribute_equals(:role, "security_manager")
    end

    policy action(:set_security_level) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_manager")
    end

    policy action(:trigger_lockdown) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_manager")
      authorize_if actor_attribute_equals(:role, "emergency_responder")
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :set_security_level
    define :trigger_lockdown
    define :archive
    define :list_by_site, action: :read, args: [:site_id]
    define :list_by_security_level, action: :read, args: [:security_level]
  end

  postgres do
    table "zones"
    repo Indrajaal.Repo

    custom_indexes do
      index [:site_id, :code], unique: true
      index [:site_id, :zone_type]
      index [:site_id, :security_level]
      index [:building_id], where: "building_id IS NOT NULL"
      index [:floor_id], where: "floor_id IS NOT NULL"
      index [:parent_zone_id], where: "parent_zone_id IS NOT NULL"
      index [:active?], name: "zones_active_index"
    end
  end
end

# Agent: Worker-4 (Sites Domain Agent)
# SOPv5.1 Compliance: ✅ Site management and geographic coordination with cybernetic coordination
# Domain: Sites
# Responsibilities: Site management, geographic coordination, area monitoring
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
