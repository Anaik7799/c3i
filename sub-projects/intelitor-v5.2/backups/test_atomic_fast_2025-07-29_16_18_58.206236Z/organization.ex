defmodule Intelitor.Core.Organization do
  @moduledoc """
  Organization resource - hierarchical structure within tenants.

  Organizations provide logical grouping of resources within a tenant.
  Supports parent-child relationships for complex organizational structures.
  """

  use Intelitor.BaseResource,
    domain: Intelitor.Core,
    table: "organizations"

  use Intelitor.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 255
      description "Organization name"
    end

    attribute :code, :string do
      constraints max_length: 20
      description "Short code identifier"
    end

    attribute :is_primary, :boolean do
      default false
      description "Whether this is the primary organization for the tenant"
    end

    attribute :settings, :map do
      default %{}
      description "Organization-specific settings"
    end

    attribute :active, :boolean do
      default true
      description "Whether the organization is active"
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Intelitor.Core.Tenant do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :parent_organization, __MODULE__ do
      attribute_writable? true
      description "Parent in organizational hierarchy"
    end

    has_many :child_organizations, __MODULE__ do
      destination_attribute :parent_organization_id
      description "Child organizations"
    end
  end

  identities do
    identity :unique_code_per_tenant, [:tenant_id, :code]
  end

  actions do
    defaults [:read, :update, :destroy]
    create :create do
      accept [:name, :code, :is_primary, :settings, :active, :tenant_id, :parent_organization_id]
      primary? true

      change fn changeset, _context ->
        if Ash.Changeset.get_attribute(changeset, :is_primary) do
          tenant_id = Ash.Changeset.get_attribute(changeset, :tenant_id)

          changeset
          |> Ash.Changeset.before_action(fn changeset ->
            # Ensure only one primary organization per tenant
            {:ok, all_orgs} = Ash.read(__MODULE__)

            existing_primary =
              Enum.filter(all_orgs, fn org ->
                org.tenant_id == tenant_id and org.is_primary
              end)

            for org <- existing_primary do
              org |> Ash.Changeset.for_update(:update, %{is_primary: false}) |> Ash.update!()
            end

            changeset
          end)
        else
          changeset
        end
      end
    end

    update :set_primary do
      require_atomic? false
      accept []
      change set_attribute(:is_primary, true)

      change fn changeset, _context ->
        tenant_id =
          Ash.Changeset.get_attribute(changeset, :tenant_id) ||
            changeset.data.tenant_id

        changeset
        |> Ash.Changeset.before_action(fn changeset ->
          # Update any existing primary organizations to non-primary
          {:ok, all_orgs} = Ash.read(__MODULE__)

          existing_primary =
            Enum.filter(all_orgs, fn org ->
              org.tenant_id == tenant_id and org.is_primary
            end)

          for org <- existing_primary do
            if org.id != changeset.data.id do
              org |> Ash.Changeset.for_update(:update, %{is_primary: false}) |> Ash.update!()
            end
          end

          changeset
        end)
      end

      description "Set as primary organization"
    end

    update :deactivate do
      require_atomic? false
      accept []
      change set_attribute(:active, false)
      description "Deactivate organization"
    end

    update :activate do
      require_atomic? false
      accept []
      change set_attribute(:active, true)
      description "Activate organization"
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 255)

    validate string_length(:code, max: 20) do
      where present(:code)
    end

    # Ensure at least one primary organization per tenant
    validate Intelitor.Core.Validations.EnsurePrimaryOrganization
  end

  calculations do
    calculate :full_path, :string do
      calculation fn records, _ ->
        # Build hierarchical path
        # This would need recursive loading of parents
        Enum.map(records, fn record ->
          # Simplified - would build full path
          record.name
        end)
      end

      description "Full hierarchical path"
    end

    calculate :child_count, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn _record ->
          # Placeholder - would count children
          0
        end)
      end

      description "Number of direct child organizations"
    end
  end

  policies do
    # Users can read organizations they belong to
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:is_system_admin, true)
      authorize_if relates_to_actor_via([:teams, :members])
    end

    # Only admins can create/update/destroy organizations
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:is_system_admin, true)
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :organization_admin)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :create
    define :update
    define :destroy
    define :set_primary, action: :set_primary
    define :activate, action: :activate
    define :deactivate, action: :deactivate
  end

  postgres do
    table "organizations"
    repo Intelitor.Repo

    custom_indexes do
      index [:tenant_id, :code],
        unique: true,
        name: "organizations_unique_code_per_tenant_index",
        where: "code IS NOT NULL"

      index [:tenant_id, :is_primary],
        name: "organizations_primary_index",
        where: "is_primary = true"

      index [:tenant_id, :active],
        name: "organizations_active_index"

      index [:parent_organization_id],
        name: "organizations_hierarchy_index"
    end
  end
end
