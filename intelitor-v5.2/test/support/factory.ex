defmodule Indrajaal.Factory do
  @moduledoc """
  Main factory for creating test data with enterprise-grade bulk data generation.
  Compliance: SC-FAC-001 through SC-FAC-012.
  """

  use ExMachina

  # Import shared utilities
  import Indrajaal.Test.SharedFactoryUtilities, except: [merge_attributes: 2, sequence: 2]

  # Import domain factories using Ash.Changeset pattern
  use Indrajaal.CoreFactory
  use Indrajaal.AccountsFactory

  # Legacy/Non-Ash factories can still use ExMachina default behavior
  # but for Ash resources, the domain factories call Ash.create directly.

  @doc """
  Override insert to handle Ash resources that are already persisted by the factory.
  """
  def insert(factory_name, attrs \\ %{}) do
    # build/2 executes the factory function (e.g., user_factory)
    # which returns an already-inserted Ash struct.
    record = build(factory_name, attrs)

    case record do
      %{__meta__: %{state: :loaded}} ->
        # Already persisted via Ash.create in the domain factory
        record

      _ ->
        # For non-Ash resources, use Ecto strategy or manual insert
        Indrajaal.Repo.insert!(record)
    end
  end

  # Guard tour factories - define inline for now
  def checkpoint_factory(attrs \\ %{}) do
    attrs_map = normalize_attrs(attrs)
    {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

    org_id =
      cond do
        Map.has_key?(attrs_map, :organization_id) -> attrs_map[:organization_id]
        Map.has_key?(attrs_map, :organization) -> attrs_map[:organization].id
        true -> insert(:organization, tenant: tenant).id
      end

    checkpoint_attrs =
      %{
        name: sequence(:checkpoint_name, &"Checkpoint #{&1}"),
        organization_id: org_id,
        tenant_id: tenant.id
      }
      |> merge_attributes(attrs_map)
      |> Map.delete(:tenant)
      |> Map.delete(:organization)

    admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

    {:ok, checkpoint} =
      Indrajaal.Devices.Checkpoint
      |> Ash.Changeset.for_create(:create, checkpoint_attrs, actor: admin_actor)
      |> Ash.create(actor: admin_actor)

    checkpoint
  end

  # ... other bulk generation helpers (simplified for brevity or moved to domain factories)
  def create_bulk_users(tenant, count) do
    Enum.map(1..count, fn _ -> insert(:user, tenant: tenant) end)
  end
end
