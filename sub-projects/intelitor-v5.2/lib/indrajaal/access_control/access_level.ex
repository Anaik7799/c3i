defmodule Indrajaal.AccessControl.AccessLevel do
  # PHASE N: Access control patterns unified

  @moduledoc """
  Defines access permission levels that can be assigned to credentials.
  Hierarchical access levels with time and location restrictions.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.AccessControlDomain

  use Indrajaal.Multitenancy.TenantResource

  require Ash.Query

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :code, :string do
      allow_nil? false
      constraints max_length: 20
    end

    attribute :description, :string

    attribute :priority, :integer do
      default 100
      constraints min: 0, max: 999
    end

    attribute :access_points, {:array, :uuid} do
      default []
    end

    attribute :time_restrictions, :map do
      default %{}
      # Structure: %{monday: %{start: "08:00", end: "18:00"}, ...}
    end

    attribute :__require_escort, :boolean, default: false
    attribute :__require_dual_auth, :boolean, default: false
    attribute :max_occupancy, :integer

    attribute :status, :atom do
      constraints one_of: [:active, :inactive]
      default :active
    end

    timestamps()
  end

  relationships do
    belongs_to :parent_level, __MODULE__
    has_many :child_levels, __MODULE__, destination_attribute: :parent_level_id

    has_many :access_grants, Indrajaal.AccessControl.AccessGrant
  end

  identities do
    identity :unique_code, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :code,
        :description,
        :priority,
        :access_points,
        :time_restrictions,
        :__require_escort,
        :__require_dual_auth,
        :max_occupancy,
        :parent_level_id
      ]
    end

    read :get_by_code do
      argument :code, :string do
        allow_nil? false
      end

      filter expr(code == ^arg(:code))
    end

    read :list_active do
      filter expr(status == :active)
    end
  end

  calculations do
    calculate :effective_access_points, {:array, :uuid} do
      calculation fn records, _ ->
        # Include parent level access points
        Enum.map(records, fn record ->
          parent_points =
            if record.parent_level do
              record.parent_level.access_points || []
            else
              []
            end

          Enum.uniq(record.access_points ++ parent_points)
        end)
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end
  end

  code_interface do
    define :create, action: :create
    define :get_by_code, args: [:code]
    define :list_active
  end

  postgres do
    table "access_levels"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Security access control and policy enforcement with cyb
# Domain: Access control
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
