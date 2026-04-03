defmodule Indrajaal.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Indrajaal.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  # UnifiedDemoTestFramework used in feature tests

  using do
    quote do
      alias Indrajaal.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Indrajaal.DataCase
      import Indrajaal.TestCase

      # Import factory functions but override insert for Ash resources
      import Indrajaal.Factory, except: [insert: 1, insert: 2]

      # Import test helpers for bulk creation functions
      import Indrajaal.TestHelpers

      # Custom insert function for Ash resources
      defp insert(factory_name, attrs \\ %{}) do
        Indrajaal.DataCase.ash_insert(factory_name, attrs)
      end

      # Ash testing helpers
      import Ash.Test
    end
  end

  setup tags do
    Indrajaal.DataCase.setup_sandbox(tags)
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  @spec setup_sandbox(term()) :: term()
  def setup_sandbox(tags) do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(Indrajaal.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset or Ash errors into a map of messages.

  Supports both `Ecto.Changeset` (Ecto-backed resources) and
  `Ash.Error.Invalid` (Ash 3.x resources).

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  @spec errors_on(Ecto.Changeset.t() | Ash.Error.Invalid.t() | term()) :: map()
  def errors_on(%Ash.Error.Invalid{errors: errors}) do
    Enum.reduce(errors, %{}, fn error, acc ->
      field = Map.get(error, :field) || Map.get(error, :attribute)

      if field do
        message =
          case error do
            %{message: msg} when is_binary(msg) -> msg
            %{message: msg} when is_atom(msg) -> to_string(msg)
            _ -> "is invalid"
          end

        Map.update(acc, field, [message], &(&1 ++ [message]))
      else
        acc
      end
    end)
  end

  def errors_on(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # Fallback: attempt Ecto.Changeset traverse for unknown types (e.g. wrapped errors)
  def errors_on(other) do
    try do
      Ecto.Changeset.traverse_errors(other, fn {message, opts} ->
        Regex.replace(~r"%{(\w+)}", message, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
    rescue
      _ -> %{}
    end
  end

  @doc """
  Returns a random tenant for testing.
  """
  @spec random_tenant() :: term()
  def random_tenant do
    Indrajaal.TestCase.create_test_tenant()
  end

  @doc """
  Sets the tenant context for testing.
  """
  @spec set_tenant(binary() | integer()) :: term()
  def set_tenant(tenant_id) do
    Process.put(:current_tenant, tenant_id)
  end

  @doc """
  Insert function for Ash resources that handles the fact that factories
  create already-persisted records.
  """
  @spec ash_insert(binary(), map()) :: term()
  def ash_insert(factory_name, attrs \\ %{}) do
    # Call the factory function directly to get the persisted record
    factory_fun = String.to_atom("#{factory_name}_factory")
    apply(Indrajaal.Factory, factory_fun, [attrs])
  end
end
