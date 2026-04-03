defmodule Indrajaal.Policy.Permission do
  @moduledoc """
  Represents granular permissions in the system.

  Permissions define specific actions that can be performed on resources.
  They are assigned to roles rather than directly to __users.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Policy

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :code, :string do
      allow_nil? false
      public? true

      constraints max_length: 100,
                  match: ~r/^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$/
    end

    attribute :resource, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :action, :string do
      allow_nil? false
      public? true
      constraints max_length: 50
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :category, :atom do
      constraints one_of: [:crud, :admin, :system, :custom]
      default :crud
      public? true
    end

    attribute :scope, :atom do
      constraints one_of: [:global, :tenant, :organization, :own]
      default :tenant
      public? true
    end

    attribute :conditions, :map do
      default %{}
      public? true
    end

    attribute :risk_level, :atom do
      constraints one_of: [:low, :medium, :high, :critical]
      default :low
      public? true
    end

    attribute :_requires_mfa?, :boolean do
      default false
      public? true
    end

    attribute :active?, :boolean do
      default true
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    many_to_many :roles, Indrajaal.Policy.Role do
      through Indrajaal.Policy.RolePermission
      source_attribute :id
      source_attribute_on_join_resource :permission_id
      destination_attribute :id
      destination_attribute_on_join_resource :role_id
      public? true
    end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :update, :destroy]

    # AGENT NOTE: Explicit create action for factory usage
    create :create do
      accept [
        :name,
        :code,
        :resource,
        :action,
        :description,
        :category,
        :scope,
        :conditions,
        :risk_level,
        :_requires_mfa?,
        :active?
      ]

      primary? true
    end

    create :create_batch do
      argument :permissions, {:array, :map} do
        allow_nil? false
      end

      change fn changeset, __context ->
        permissions = Ash.Changeset.get_argument(changeset, :permissions)

        # This would typically create multiple permissions in a transaction
        # For now, we'll focus on the pattern
        changeset
      end
    end

    update :toggle_active do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :active?)
        Ash.Changeset.change_attribute(changeset, :active?, !current)
      end
    end

    update :update_conditions do
      require_atomic? false
      accept [:conditions]

      validate fn changeset, __context ->
        conditions = Ash.Changeset.get_attribute(changeset, :conditions)

        if valid_conditions?(conditions) do
          {:ok, changeset}
        else
          {:error, "Invalid condition format"}
        end
      end
    end
  end

  calculations do
    calculate :is_high_risk?, :boolean, expr(risk_level in [:high, :critical])

    calculate :role_count,
              :integer,
              expr(count(roles, query: [filter: expr(is_nil(archived_at))]))

    calculate :formatted_code, :string, expr(resource <> ":" <> action)

    calculate :effective_scope, :atom do
      calculation fn records, opts ->
        Enum.map(records, fn permission ->
          determine_effective_scope(permission)
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 3, max: 100)
    validate string_length(:code, min: 3, max: 100)

    validate match(:code, ~r/^[a-z][a-z0-9_]*:[a-z][a-z0-9_]*$/) do
      message "must be in format 'resource:action' with lowercase letters, numbers, and underscores"
    end

    validate fn changeset, __context ->
      resource = Ash.Changeset.get_attribute(changeset, :resource)
      action = Ash.Changeset.get_attribute(changeset, :action)
      code = Ash.Changeset.get_attribute(changeset, :code)

      expected_code = "#{resource}:#{action}"

      if code == expected_code do
        {:ok, changeset}
      else
        {:error, field: :code, message: "must match resource:action format"}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")

      authorize_if expr(
                     ^actor(:role) == "security_admin" and
                       category !=
                         :system
                   )
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")

      authorize_if expr(
                     ^actor(:role) == "security_admin" and
                       category !=
                         :system
                   )
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")

      authorize_if expr(
                     ^actor(:role) == "security_admin" and
                       category !=
                         :system
                   )
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :toggle_active
    define :get_by_code, action: :read, get_by: [:code]
    define :list_by_resource, action: :read, args: [:resource]
  end

  postgres do
    table "permissions"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:tenant_id, :resource, :action]
      index [:category]
      index [:risk_level]
      index [:active?], name: "permissions_active_index", where: "active? = true"
    end
  end

  # Helper functions
  @spec valid_conditions?(term()) :: term()
  defp valid_conditions?(conditions) when is_map(conditions) do
    # Validate condition structure
    # This would check for valid operators, fields, etc.
    true
  end

  @spec valid_conditions?(term()) :: term()
  defp valid_conditions?(_), do: false

  defp determine_effective_scope(permission) do
    # Logic to determine effective scope based on conditions
    # For now, return the defined scope
    permission.scope
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Policy
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
