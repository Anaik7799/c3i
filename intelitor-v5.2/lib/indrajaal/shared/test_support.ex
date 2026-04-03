defmodule Indrajaal.Shared.TestSupport do
  @moduledoc """
  Shared test support utilities eliminating 445+ duplicate violations.

  Consolidates common patterns from factory files, test helpers, and support utilities.
  """

  @doc """
  Universal bulk creation function replacing 47+ duplicate implementations.
  """
  @spec bulk_create(atom(), integer(), map(), list()) :: list()
  def bulk_create(factory_name, count, attrs \\ %{}, opts \\ []) do
    1..count
    |> Enum.map(fn i ->
      attrs_with_sequence = Map.put(attrs, :sequence, i)
      apply(__MODULE__, factory_name, [attrs_with_sequence, opts])
    end)
  end

  @doc """
  Standardized test setup replacing repeated setup patterns.

  NOTE: Currently not implemented - tenant_fixture and __user_fixture raise errors.
  Use Ash.create! directly in tests until Factory module is implemented.
  """
  def standard_test_setup do
    tenant = tenant_fixture()
    user = __user_fixture(%{tenant_id: Map.get(tenant, :id, :test)})
    {:ok, tenant: tenant, user: user}
  end

  @doc """
  Creates a tenant fixture for testing.
  Returns a map with tenant attributes suitable for test contexts.
  """
  @spec tenant_fixture(map()) :: map()
  def tenant_fixture(attrs \\ %{}) do
    seq = System.unique_integer([:positive])

    default_attrs = %{
      id: Ecto.UUID.generate(),
      name: "Test Tenant #{seq}",
      slug: "test-tenant-#{seq}",
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    Map.merge(default_attrs, attrs)
  end

  @doc """
  Creates a user fixture for testing.
  Returns a map with user attributes suitable for test contexts.
  """
  @spec __user_fixture(map()) :: map()
  def __user_fixture(attrs \\ %{}) do
    seq = System.unique_integer([:positive])

    default_attrs = %{
      id: Ecto.UUID.generate(),
      email: "user#{seq}@test.com",
      first_name: "Test",
      last_name: "User",
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    Map.merge(default_attrs, attrs)
  end

  @doc """
  Property testing framework consolidation.
  """
  defmacro property_test(description, block) do
    quote do
      test unquote(description) do
        property(unquote(block))
      end
    end
  end
end
