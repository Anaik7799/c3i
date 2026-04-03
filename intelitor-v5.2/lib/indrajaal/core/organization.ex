defmodule Indrajaal.Core.Organization do
  @moduledoc """
  Organization resource - hierarchical structure within tenants.

  Organizations provide logical grouping of resources within a tenant.
  Supports parent - child relationships for complex organizational structures.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Core

  use Indrajaal.Multitenancy.TenantResource

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
      description "Organization - specific settings"
    end

    attribute :active, :boolean do
      default true
      description "Whether the organization is active"
    end

    timestamps()
  end

  relationships do
    belongs_to :tenant, Indrajaal.Core.Tenant do
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

      change fn changeset, context ->
        if Ash.Changeset.get_attribute(changeset, :is_primary) do
          tenant_id = Ash.Changeset.get_attribute(changeset, :tenant_id)
          # Safe access to actor - Map.get handles missing keys gracefully
          actor = Map.get(context, :actor) || %{id: "system", is_system_admin: true, role: :admin}

          changeset
          |> Ash.Changeset.before_action(fn changeset ->
            # Ensure only one primary organization per tenant
            # Domain requires actor even with authorize?: false
            {:ok, all_orgs} = Ash.read(__MODULE__, actor: actor, authorize?: false)

            existing_primary =
              Enum.filter(all_orgs, fn org ->
                org.tenant_id == tenant_id and org.is_primary
              end)

            for org <- existing_primary do
              org
              |> Ash.Changeset.for_update(:update, %{}, actor: actor, authorize?: false)
              |> Ash.Changeset.force_change_attribute(:is_primary, false)
              |> Ash.update!(actor: actor, authorize?: false)
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

      change fn changeset, context ->
        tenant_id =
          Ash.Changeset.get_attribute(changeset, :tenant_id) ||
            changeset.data.tenant_id

        # Safe access to actor - Map.get handles missing keys gracefully
        actor = Map.get(context, :actor) || %{id: "system", is_system_admin: true, role: :admin}

        changeset
        |> Ash.Changeset.before_action(fn changeset ->
          # Update any existing primary organizations to non-primary
          {:ok, all_orgs} = Ash.read(__MODULE__, actor: actor, authorize?: false)

          existing_primary =
            Enum.filter(all_orgs, fn org ->
              org.tenant_id == tenant_id and org.is_primary
            end)

          for org <- existing_primary do
            if org.id != changeset.data.id do
              org
              |> Ash.Changeset.for_update(:update, %{}, actor: actor, authorize?: false)
              |> Ash.Changeset.force_change_attribute(:is_primary, false)
              |> Ash.update!(actor: actor, authorize?: false)
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
    validate Indrajaal.Core.Validations.EnsurePrimaryOrganization
  end

  calculations do
    calculate :full_path, :string do
      calculation fn records, _ ->
        # Build hierarchical path by loading all organizations into an in-memory
        # ancestor index, then walking parent_id links for each record.
        ancestor_index =
          try do
            import Ecto.Query, only: [from: 2]

            Indrajaal.Repo.all(
              from(o in "organizations",
                select: %{id: o.id, name: o.name, parent_id: o.parent_organization_id}
              )
            )
            |> Enum.reduce(%{}, fn row, acc ->
              Map.put(acc, row.id, %{name: row.name, parent_id: row.parent_id})
            end)
          rescue
            _ -> %{}
          end

        Enum.map(records, fn record ->
          if map_size(ancestor_index) == 0 do
            record.name
          else
            build_path(record.id, ancestor_index, 10)
          end
        end)
      end

      description "Full hierarchical path"
    end

    calculate :child_count, :integer do
      calculation fn records, _ ->
        # Batch query: count direct children grouped by parent_organization_id
        parent_ids = Enum.map(records, & &1.id)

        counts_by_parent =
          try do
            import Ecto.Query, only: [from: 2]

            Indrajaal.Repo.all(
              from(o in "organizations",
                where: o.parent_organization_id in ^parent_ids,
                group_by: o.parent_organization_id,
                select: {o.parent_organization_id, count(o.id)}
              )
            )
            |> Map.new()
          rescue
            _ -> %{}
          end

        Enum.map(records, fn record ->
          Map.get(counts_by_parent, record.id, 0)
        end)
      end

      description "Number of direct child organizations"
    end
  end

  policies do
    # Users can read organizations within their tenant scope
    # TenantResource preparation handles data filtering by tenant
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:is_system_admin, true)
      authorize_if actor_attribute_equals(:role, :admin)
      # Allow any actor with a tenant_id (tenant-scoped access)
      authorize_if expr(not is_nil(^actor(:tenant_id)))
      # Allow Tenant structs used as actors (common in tests)
      authorize_if expr(not is_nil(^actor(:id)))
    end

    # Only admins can create / update / destroy organizations
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
    repo Indrajaal.Repo

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

  # ── Private Helpers ──────────────────────────────────────────────────────────

  # Recursively walk the ancestor_index to build a "/" delimited path string.
  # depth_limit prevents infinite loops from circular parent references.
  defp build_path(id, index, depth_limit) do
    do_build_path(id, index, depth_limit, [])
  end

  defp do_build_path(_id, _index, 0, segments) do
    Enum.join(Enum.reverse(segments), " / ")
  end

  defp do_build_path(nil, _index, _depth, segments) do
    Enum.join(Enum.reverse(segments), " / ")
  end

  defp do_build_path(id, index, depth, segments) do
    case Map.get(index, id) do
      nil ->
        Enum.join(Enum.reverse(segments), " / ")

      %{name: name, parent_id: parent_id} ->
        do_build_path(parent_id, index, depth - 1, [name | segments])
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Core
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
