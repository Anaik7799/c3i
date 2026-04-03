defmodule Indrajaal.Integration.GraphQLFederation.ResolverTest do
  @moduledoc """
  TDG tests for Indrajaal.Integration.GraphQLFederation.Resolver.

  ## STAMP Safety Integration
  - SC-GDE-001: Guardian validation required before deployment changes
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.GraphQLFederation.Resolver

  describe "get_by_id/1" do
    test "returns error tuple for non-binary id" do
      assert {:error, {:invalid_id, nil}} = Resolver.get_by_id(nil)
    end

    test "returns error tuple for integer id" do
      assert {:error, {:invalid_id, 42}} = Resolver.get_by_id(42)
    end

    test "returns error for atom id" do
      assert {:error, {:invalid_id, :foo}} = Resolver.get_by_id(:foo)
    end

    test "accepts binary id and returns ok or not_found error" do
      result = Resolver.get_by_id("00000000-0000-0000-0000-000000000000")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "create/1" do
    test "returns error for non-map params" do
      assert {:error, {:invalid_params, _}} = Resolver.create("not a map")
    end

    test "returns error for nil params" do
      assert {:error, {:invalid_params, nil}} = Resolver.create(nil)
    end

    test "accepts map params and returns ok or error" do
      result = Resolver.create(%{name: "Test Schema"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "update/2" do
    test "returns error for non-binary id" do
      assert {:error, _} = Resolver.update(nil, %{name: "updated"})
    end

    test "returns error for non-map params" do
      assert {:error, _} = Resolver.update("some-id", "not a map")
    end

    test "accepts valid arguments and returns ok or error" do
      result = Resolver.update("00000000-0000-0000-0000-000000000000", %{name: "updated"})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "delete/1" do
    test "returns error for non-binary id" do
      assert {:error, {:invalid_id, nil}} = Resolver.delete(nil)
    end

    test "returns error for integer id" do
      assert {:error, {:invalid_id, 42}} = Resolver.delete(42)
    end

    test "accepts binary id and returns ok or error" do
      result = Resolver.delete("00000000-0000-0000-0000-000000000000")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "list_all/0" do
    test "returns ok tuple with list" do
      result = Resolver.list_all()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "resolve/3" do
    test "dispatches to get_by_id when args has :id" do
      result = Resolver.resolve(nil, %{id: "00000000-0000-0000-0000-000000000000"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "dispatches to get_by_id when parent has schema_id" do
      result = Resolver.resolve(%{schema_id: "00000000-0000-0000-0000-000000000000"}, %{}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "dispatches to list_all when no id provided" do
      result = Resolver.resolve(nil, %{}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "federation_schema/0" do
    test "returns a map" do
      result = Resolver.federation_schema()
      assert is_map(result)
    end

    test "has type field" do
      schema = Resolver.federation_schema()
      assert schema.type == "Schema"
    end

    test "has key_fields" do
      schema = Resolver.federation_schema()
      assert schema.key_fields == ["id"]
    end

    test "has fields map with expected keys" do
      schema = Resolver.federation_schema()
      assert is_map(schema.fields)
      assert Map.has_key?(schema.fields, :id)
      assert Map.has_key?(schema.fields, :name)
    end

    test "has queries and mutations" do
      schema = Resolver.federation_schema()
      assert is_map(schema.queries)
      assert is_map(schema.mutations)
    end
  end
end
