defmodule Indrajaal.Policy.UserRole do
  @moduledoc """
  Join table for User - Role many - to - many relationship.

  Tracks role assignments to __users with temporal and __contextual constraints.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Policy

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :assigned_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      public? true
    end

    attribute :assigned_by_id, :uuid do
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      public? true
    end

    attribute :scope_type, :atom do
      constraints one_of: [:global, :organization, :site, :custom]
      default :global
      public? true
    end

    attribute :scope_id, :uuid do
      public? true
    end

    attribute :conditions, :map do
      default %{}
      public? true
    end

    attribute :reason, :string do
      public? true
      constraints max_length: 500
    end

    attribute :approved?, :boolean do
      default true
      public? true
    end

    attribute :approved_at, :utc_datetime_usec do
      public? true
    end

    attribute :approved_by_id, :uuid do
      public? true
    end

    attribute :metadata, :map do
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
      allow_nil? false
    end

    belongs_to :user, Indrajaal.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :role, Indrajaal.Policy.Role do
      allow_nil? false
      public? true
    end

    belongs_to :assigned_by, Indrajaal.Accounts.User do
      define_attribute? false
      public? true
    end

    belongs_to :approved_by, Indrajaal.Accounts.User do
      define_attribute? false
      public? true
    end
  end

  identities do
    identity :unique_user_role_scope,
             [:tenant_id, :user_id, :role_id, :scope_type, :scope_id]
  end

  actions do
    defaults [:read, :destroy]

    create :assign do
      accept [:user_id, :role_id, :expires_at, :scope_type, :scope_id, :conditions, :reason]

      change set_attribute(:assigned_by_id, {:_actor, :id})
      change set_attribute(:assigned_at, &DateTime.utc_now/0)

      change fn changeset, __context ->
        # Auto - approve if assigner has permission
        # FIX 97: Changed _context to __context
        if can_auto_approve?(changeset, __context) do
          changeset
          |> Ash.Changeset.change_attribute(:approved?, true)
          |> Ash.Changeset.change_attribute(:approved_at, DateTime.utc_now())
          |> Ash.Changeset.change_attribute(
            :approved_by_id,
            __context[:actor][:id]
          )
        else
          Ash.Changeset.change_attribute(changeset, :approved?, false)
        end
      end
    end

    update :approve do
      require_atomic? false
      accept [:reason]

      change set_attribute(:approved?, true)
      change set_attribute(:approved_at, &DateTime.utc_now/0)
      change set_attribute(:approved_by_id, {:_actor, :id})
    end

    update :extend do
      require_atomic? false

      argument :new_expires_at, :utc_datetime_usec do
        allow_nil? false
      end

      argument :extension_reason, :string do
        allow_nil? false
      end

      validate fn changeset, __context ->
        new_expires = Ash.Changeset.get_argument(changeset, :new_expires_at)
        current_expires = Ash.Changeset.get_attribute(changeset, :expires_at)

        cond do
          is_nil(current_expires) ->
            {:error, "Cannot extend non - expiring role assignment"}

          DateTime.compare(new_expires, current_expires) != :gt ->
            {:error, "New expiration must be after current expiration"}

          true ->
            {:ok, changeset}
        end
      end

      change set_attribute(:expires_at, arg(:new_expires_at))

      change fn changeset, __context ->
        # AGENT GA FIX: removed underscore
        metadata = Ash.Changeset.get_attribute(changeset, :meta_data) || %{}
        extensions = Map.get(metadata, "extensions", [])

        extension = %{
          "extended_at" => DateTime.utc_now(),
          "extended_by" => __context[:actor][:id],
          "reason" => Ash.Changeset.get_argument(changeset, :extension_reason)
        }

        updated_metadata = Map.put(metadata, "extensions", [extension | extensions])
        Ash.Changeset.change_attribute(changeset, :metadata, updated_metadata)
      end
    end

    destroy :revoke do
      require_atomic? false

      change fn changeset, __context ->
        # Could log the revocation
        changeset
      end
    end
  end

  calculations do
    calculate :is_active?,
              :boolean,
              expr(approved? and (is_nil(expires_at) or expires_at > now()))

    calculate :is_expired?, :boolean, expr(not is_nil(expires_at) and expires_at <= now())

    calculate :days_until_expiry, :integer do
      calculation fn records, opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn ur ->
          case ur.expires_at do
            nil ->
              nil

            expires_at ->
              diff = DateTime.diff(expires_at, now, :day)
              max(0, diff)
          end
        end)
      end
    end

    calculate :effective_permissions, {:array, :map} do
      calculation fn records, opts ->
        Enum.map(records, fn user_role ->
          if user_role.is_active? do
            collect_effective_permissions(user_role)
          else
            []
          end
        end)
      end
    end
  end

  validations do
    validate fn changeset, __context ->
      expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)

      if expires_at &&
           DateTime.compare(
             expires_at,
             DateTime.utc_now()
           ) == :lt do
        {:error, field: :expires_at, message: "must be in the future"}
      else
        {:ok, changeset}
      end
    end

    validate fn changeset, __context ->
      scope_type = Ash.Changeset.get_attribute(changeset, :scope_type)
      scope_id = Ash.Changeset.get_attribute(changeset, :scope_id)

      case {scope_type, scope_id} do
        {:global, nil} -> {:ok, changeset}
        {:global, _} -> {:error, field: :scope_id, message: "must be nil for global scope"}
        {_, nil} -> {:error, field: :scope_id, message: "is _required for non - global scope"}
        _ -> {:ok, changeset}
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end

    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end

    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "security_admin")
    end
  end

  code_interface do
    define :assign, action: :assign
    define :read
    define :approve
    define :extend
    define :revoke, action: :destroy
    define :get_user_roles, action: :read, args: [:user_id]
  end

  postgres do
    table "user_roles"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :user_id, :role_id, :scope_type, :scope_id],
        unique: true,
        name: "user_roles_unique_assignment_index"

      index [:user_id, :approved?],
        name: "user_roles_user_approved_index",
        where: "approved? = true"

      index [:role_id]
      index [:expires_at], where: "expires_at IS NOT NULL"
      index [:assigned_by_id]
      index [:scope_type, :scope_id], where: "scope_type != 'global'"
    end
  end

  # Helper functions
  @spec can_auto_approve?(term(), term()) :: term()
  defp can_auto_approve?(_changeset, context) do
    # Check if the current actor has permission to auto - approve
    # For now, admins can auto - approve
    context[:actor][:role] in ["admin", "security_admin"]
  end

  @spec collect_effective_permissions(term()) :: term()
  defp collect_effective_permissions(_user_role) do
    # Collect permissions from role considering scope and conditions
    # This would include inherited permissions and apply conditions
    []
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Policy
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
