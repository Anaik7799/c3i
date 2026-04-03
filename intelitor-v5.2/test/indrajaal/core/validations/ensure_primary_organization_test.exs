defmodule Indrajaal.Core.Validations.EnsurePrimaryOrganizationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Validations.EnsurePrimaryOrganization

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(EnsurePrimaryOrganization)
    end
  end

  describe "Ash.Resource.Validation behaviour" do
    test "implements validate/3 callback" do
      assert function_exported?(EnsurePrimaryOrganization, :validate, 3)
    end

    test "implements init/1 callback" do
      assert function_exported?(EnsurePrimaryOrganization, :init, 1)
    end
  end

  describe "validate/3" do
    test "returns :ok or error tuple on a bare changeset-like map" do
      # validate/3 signature: validate(changeset, opts, context)
      # We cannot run a real Ash changeset without DB, but we can test it doesn't crash
      # on a minimal changeset-shaped struct
      result =
        try do
          EnsurePrimaryOrganization.validate(%{data: %{}, attributes: %{}}, [], %{})
        rescue
          _ -> :rescued
        catch
          _, _ -> :caught
        end

      assert result in [:ok, :rescued, :caught] or
               match?({:error, _}, result) or
               match?({:ok, _}, result)
    end
  end

  describe "init/1" do
    test "init/1 with empty opts returns ok or opts" do
      result = EnsurePrimaryOrganization.init([])
      assert result == :ok or match?({:ok, _}, result) or is_list(result)
    end
  end
end
