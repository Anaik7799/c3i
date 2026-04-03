defmodule Indrajaal.CoreFactory do
  @moduledoc """
  Ash-compliant factories for the Core domain.
  SOPv5.11 Compliance: SC-DB-021, SC-FAC-001.
  """
  import Indrajaal.Test.SharedFactoryUtilities

  defmacro __using__(_) do
    quote do
      def tenant_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)

        # SC-DB-004: Align factory with Tenant resource schema (slug instead of code)
        tenant_attrs =
          %{
            name: sequence(:tenant_name, &"Tenant #{&1}"),
            slug: sequence(:tenant_slug, &"tenant-#{&1}"),
            status: :active,
            subscription_tier: :free
          }
          |> merge_attributes(attrs_map)

        # Tenant creation typically doesn't require an actor in setup,
        # but we use a system actor if DomainRequiresActor is enforced.
        admin_actor = %{is_system_admin: true}

        {:ok, tenant} =
          Indrajaal.Core.Tenant
          |> Ash.Changeset.for_create(:create, tenant_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        tenant
      end

      def organization_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        org_attrs =
          %{
            name: sequence(:org_name, &"Organization #{&1}"),
            code: sequence(:org_code, &"ORG#{&1}"),
            is_primary: false,
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        admin_actor = apply(Indrajaal.ActorHelpers, :admin_actor, [tenant.id])

        {:ok, organization} =
          Indrajaal.Core.Organization
          |> Ash.Changeset.for_create(:create, org_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        organization
      end
    end
  end
end
