defmodule Indrajaal.AccountsFactory do
  @moduledoc """
  Ash-compliant factories for the Accounts domain.
  SOPv5.11 Compliance: SC-DB-021, SC-FAC-001.
  """
  import Indrajaal.Test.SharedFactoryUtilities

  defmacro __using__(_) do
    quote do
      def user_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        user_attrs =
          %{
            email: sequence(:user_email, &"user#{&1}@test.example.com"),
            username: sequence(:user_username, &"user#{&1}"),
            full_name: "Test User",
            status: :active,
            role: :user,
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        {:ok, user} =
          Indrajaal.Accounts.User
          |> Ash.Changeset.for_create(:create, user_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        user
      end

      def profile_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        user_id =
          cond do
            Map.has_key?(attrs_map, :user_id) -> attrs_map[:user_id]
            Map.has_key?(attrs_map, :user) -> attrs_map[:user].id
            true -> insert(:user, tenant: tenant).id
          end

        profile_attrs =
          %{
            bio: "Test bio",
            user_id: user_id,
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:user)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        {:ok, profile} =
          Indrajaal.Accounts.Profile
          |> Ash.Changeset.for_create(:create, profile_attrs, actor: admin_actor)
          |> Ash.create(actor: admin_actor)

        profile
      end
    end
  end
end
