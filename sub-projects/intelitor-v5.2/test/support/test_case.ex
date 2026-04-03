defmodule Indrajaal.TestCase do
  @moduledoc """
  Base test case for all Indrajaal tests.
  Provides common functionality and helpers.
  """

  use ExUnit.CaseTemplate
  # UnifiedDemoTestFramework used in feature tests

  using do
    quote do
      import Indrajaal.TestCase
      import Indrajaal.Factory
      import Indrajaal.TestHelpers

      alias Indrajaal.Repo
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(Indrajaal.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    # Set up tenant context if needed
    tenant = if tags[:multi_tenant], do: create_test_tenant(), else: nil

    {:ok, tenant: tenant}
  end

  @doc """
  Creates a test tenant for multi-tenant tests
  """
  @spec create_test_tenant() :: any()
  def create_test_tenant do
    # SC-ASH3-004: Pass actor to Ash operations
    system_actor = %{is_system: true, permissions: [:all]}

    # Use :create action - only accepts name and slug
    # Actor must be passed to both for_create and Ash.create in Ash 3.x
    {:ok, tenant} =
      Indrajaal.Core.Tenant
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Test Tenant",
          slug: "test-#{:rand.uniform(9999)}"
        },
        actor: system_actor
      )
      |> Ash.create(actor: system_actor, authorize?: false)

    tenant
  end

  @doc """
  Sets the tenant context for a test
  """
  @spec set_tenant_context(any(), any()) :: any()
  def set_tenant_context(conn, tenant) do
    Ash.PlugHelpers.set_tenant(conn, tenant.id)
  end

  @doc """
  Asserts that a changeset has a specific error
  """
  @spec assert_changeset_error(term(), term(), term()) :: term()
  def assert_changeset_error(changeset, field, message) do
    errors = Keyword.get(changeset.errors, field, [])
    assert Enum.any?(errors, fn {msg, _} -> msg == message end)
  end

  @doc """
  Asserts that a result is an error tuple with specific reason
  """
  @spec assert_error_result(term(), term()) :: term()
  def assert_error_result({:error, reason}, expected_reason) do
    assert reason == expected_reason
  end
end
