defmodule Intelitor.Policy.RolePermission do
  @moduledoc """
  Join table for Role-Permission many-to-many relationship.

  Tracks which permissions are assigned to which roles with additional metadata.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Policy,
    table: "role_permissions"

  use Intelitor.Multitenancy.TenantResource

  import Intelitor.Shared.PolicyPatterns

  attributes do
    uuid_primary_key :id

    attribute :granted_at, :utc_datetime_usec do
      default &DateTime.utc_now/0
      public? true
    end

    attribute :granted_by_id, :uuid do
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
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

    attribute :metadata, :map do
      default %{}
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
    end

    belongs_to :role, Intelitor.Policy.Role do
      allow_nil? false
      public? true
    end

    belongs_to :permission, Intelitor.Policy.Permission do
      allow_nil? false
      public? true
    end

    belongs_to :granted_by, Intelitor.Accounts.User do
      define_attribute? false
      public? true
    end
  end

  identities do
    identity :unique_role_permission, [:tenant_id, :role_id, :permission_id]
  end

  actions do
    defaults [:read, :create, :destroy]

    create :grant do
      accept [:role_id, :permission_id, :expires_at, :conditions, :reason]

      change set_attribute(:granted_by_id, {:_actor, :id})
      change set_attribute(:granted_at, &DateTime.utc_now/0)
    end

    update :update_conditions do
      require_atomic? false
      accept [:conditions, :expires_at]

      change set_attribute(:granted_by_id, {:_actor, :id})
    end

    destroy :revoke do
      require_atomic? false
      change fn changeset, _context ->
        # Could log the revocation here
        changeset
      end
    end
  end

  calculations do
    calculate :is_active?, :boolean, expr(is_nil(expires_at) or expires_at > now())

    calculate :days_until_expiry, :integer do
      calculation fn records, _opts ->
        now = DateTime.utc_now()

        Enum.map(records, fn rp ->
          case rp.expires_at do
            nil ->
              nil

            expires_at ->
              diff = DateTime.diff(expires_at, now, :day)
              max(0, diff)
          end
        end)
      end
    end

    calculate :is_conditional?, :boolean, expr(conditions != %{})
  end

  validations do
    validate fn changeset, _context ->
      expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)

      if expires_at && DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
        {:error, field: :expires_at, message: "must be in the future"}
      else
        {:ok, changeset}
      end
    end
  end

  policies do
    admin_and_security_admin_policies()
  end

  code_interface do
    define :grant, action: :grant
    define :read
    define :revoke, action: :destroy
    define :update_conditions
  end

  postgres do
    table "role_permissions"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :role_id, :permission_id], unique: true
      index [:role_id]
      index [:permission_id]
      index [:expires_at], where: "expires_at IS NOT NULL"
      index [:granted_by_id]
    end
  end
end
