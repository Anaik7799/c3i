defmodule Indrajaal.Policy.Role do
  @moduledoc """
  Represents authorization roles in the system.

  Roles define sets of permissions that can be assigned to __users.
  Supports hierarchical roles with inheritance.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Policy,
    extensions: [AshAdmin.Resource, AshJsonApi.Resource]

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

      constraints max_length: 50,
                  match: ~S/^[A - Z][A - Z0 - 9_]*$/
    end

    attribute :description, :string do
      public? true
      constraints max_length: 1000
    end

    attribute :system_role?, :boolean do
      default false
      public? true
    end

    attribute :assignable?, :boolean do
      default true
      public? true
    end

    attribute :level, :integer do
      default 0
      public? true
      constraints min: 0, max: 99
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    attribute :archived_at, :utc_datetime_usec do
      public? false
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    belongs_to :parent_role, __MODULE__ do
      public? true
    end

    has_many :child_roles, __MODULE__ do
      destination_attribute :parent_role_id
      public? true
    end

    many_to_many :permissions, Indrajaal.Policy.Permission do
      through Indrajaal.Policy.RolePermission
      source_attribute :id
      source_attribute_on_join_resource :role_id
      destination_attribute :id
      destination_attribute_on_join_resource :permission_id
      public? true
    end

    many_to_many :__users, Indrajaal.Accounts.User do
      through Indrajaal.Policy.UserRole
      source_attribute :id
      source_attribute_on_join_resource :role_id
      destination_attribute :id
      destination_attribute_on_join_resource :user_id
      public? true
    end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :update]

    # AGENT NOTE: Explicit create action for factory usage
    create :create do
      accept [:name, :code, :description, :system_role?, :assignable?, :level, :metadata]
      primary? true
    end

    destroy :archive do
      require_atomic? false
      soft? true
      change set_attribute(:archived_at, &DateTime.utc_now/0)
      change set_attribute(:assignable?, false)
    end

    update :restore do
      require_atomic? false
      accept []
      change set_attribute(:archived_at, nil)
      change set_attribute(:assignable?, true)
    end

    update :add_permission do
      require_atomic? false

      argument :permission_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:permission_id, :permissions, type: :append)
    end

    update :remove_permission do
      require_atomic? false

      argument :permission_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:permission_id, :permissions, type: :remove)
    end

    update :set_parent do
      require_atomic? false
      argument :parent_role_id, :uuid

      validate fn changeset, __context ->
        # Pr_event circular references
        parent_id = Ash.Changeset.get_argument(changeset, :parent_role_id)
        role_id = Ash.Changeset.get_data(changeset, :id)

        if parent_id && parent_id != role_id do
          {:ok, changeset}
        else
          {:error, "Role cannot be its own parent"}
        end
      end

      change set_attribute(:parent_role_id, arg(:parent_role_id))
    end
  end

  calculations do
    calculate :is_active?, :boolean, expr(is_nil(archived_at))

    calculate :permission_count, :integer, expr(count(permissions))

    calculate :__user_count,
              :integer,
              expr(count(__users, query: [filter: expr(_status == :active)]))

    calculate :full_path, :string do
      calculation fn records, opts ->
        Enum.map(records, fn role ->
          build_role_path(role)
        end)
      end
    end

    calculate :all_permissions, {:array, :map} do
      calculation fn records, opts ->
        Enum.map(records, fn role ->
          collect_all_permissions(role)
        end)
      end
    end
  end

  validations do
    validate string_length(:name, min: 3, max: 100)
    validate string_length(:code, min: 2, max: 50)

    validate match(:code, ~S/^[A - Z][A - Z0 - 9_]*$/) do
      message "must start with uppercase letter
    and contain only uppercase letters, numbers, and underscores"
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
      authorize_if relating_to_actor(:__users)
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if expr(^actor(:role) == "security_admin" and not system_role?)
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if expr(^actor(:role) == "security_admin" and not system_role?)
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if expr(^actor(:role) == "security_admin" and not system_role?)
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :archive, action: :archive
    define :restore
    define :add_permission
    define :remove_permission
    define :get_by_code, action: :read, get_by: [:code]
  end

  json_api do
    type "role"

    routes do
      base("/roles")

      get(:read)
      index :read
      post(:create)
      patch(:update)
      delete(:archive)
    end
  end

  postgres do
    table "roles"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :code], unique: true
      index [:tenant_id, :system_role?], name: "roles_tenant_system_index"
      index [:parent_role_id], where: "parent_role_id IS NOT NULL"
      index [:archived_at], where: "archived_at IS NOT NULL"
      index [:level]
    end
  end

  # Helper functions
  @spec build_role_path(term()) :: term()
  defp build_role_path(role) do
    case role.parent_role do
      nil -> role.name
      parent -> "#{build_role_path(parent)} > #{role.name}"
    end
  end

  @spec collect_all_permissions(term()) :: term()
  defp collect_all_permissions(role) do
    own_permissions =
      Enum.map(role.permissions || [], fn perm ->
        %{
          id: perm.id,
          code: perm.code,
          resource: perm.resource,
          action: perm.action,
          inherited: false
        }
      end)

    inherited_permissions =
      case role.parent_role do
        nil ->
          []

        parent ->
          parent
          |> collect_all_permissions()
          |> Enum.map(&Map.put(&1, :inherited, true))
      end

    Enum.uniq_by(own_permissions ++ inherited_permissions, & &1.code)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Policy
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
