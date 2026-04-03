import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.AccessControlFactory do
  @moduledoc """
  Factory definitions for Access Control domain.
  SOPv5.11 Compliant | TDG Methodology | STAMP Safety Verified
  """

  defmacro __using__(_) do
    quote do
      @spec access_credential_factory(any()) :: any()
      def access_credential_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        user = attrs_map[:user] || insert(:user, tenant: tenant)

        credential_attrs =
          %{
            credential_type: :card,
            credential_number: sequence(:credential_number, &"CARD-#{&1}"),
            user_id: user.id,
            status: :active,
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:user)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        {:ok, credential} =
          Indrajaal.AccessControl.AccessCredential
          |> Ash.Changeset.for_create(:issue, credential_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        credential
      end

      @spec access_level_factory(any()) :: any()
      def access_level_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        level_attrs =
          %{
            name: sequence(:access_level_name, &"Access Level #{&1}"),
            code: sequence(:access_level_code, &"LEVEL-#{&1}"),
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        {:ok, level} =
          Indrajaal.AccessControl.AccessLevel
          |> Ash.Changeset.for_create(:create, level_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        level
      end

      @spec access_grant_factory(any()) :: any()
      def access_grant_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        user = attrs_map[:user] || insert(:user, tenant: tenant)

        credential =
          attrs_map[:access_credential] || insert(:access_credential, tenant: tenant, user: user)

        level = attrs_map[:access_level] || insert(:access_level, tenant: tenant)

        grant_attrs =
          %{
            grant_type: :permanent,
            access_credential_id: credential.id,
            access_level_id: level.id,
            status: :active,
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:user)
          |> Map.delete(:access_credential)
          |> Map.delete(:access_level)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        {:ok, grant} =
          Indrajaal.AccessControl.AccessGrant
          |> Ash.Changeset.for_create(:grant, grant_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        grant
      end
    end
  end
end
