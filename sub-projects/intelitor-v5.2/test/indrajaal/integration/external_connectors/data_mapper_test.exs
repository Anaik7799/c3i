defmodule Indrajaal.Integration.ExternalConnectors.DataMapperTest do
  @moduledoc """
  TDG test suite for Indrajaal.Integration.ExternalConnectors.DataMapper.

  ## STAMP Safety Integration
  - SC-PRF-055: No blocking operations
  - SC-PRF-050: Response transformation < 50ms

  ## TPS 5-Level RCA Context
  - L1 Symptom: Field mapping silently drops fields
  - L5 Root Cause: Missing ETS table initialization or incorrect key format
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.ExternalConnectors.DataMapper

  setup do
    DataMapper.ensure_table()
    :ok
  end

  describe "ensure_table/0" do
    test "returns :ok on first call" do
      assert :ok = DataMapper.ensure_table()
    end

    test "is idempotent — safe to call multiple times" do
      assert :ok = DataMapper.ensure_table()
      assert :ok = DataMapper.ensure_table()
      assert :ok = DataMapper.ensure_table()
    end
  end

  describe "validate_mapping/1" do
    test "accepts empty map" do
      assert :ok = DataMapper.validate_mapping(%{})
    end

    test "accepts map with field_map" do
      assert :ok = DataMapper.validate_mapping(%{field_map: %{name: "full_name"}})
    end

    test "accepts map with transforms containing functions" do
      assert :ok =
               DataMapper.validate_mapping(%{
                 transforms: %{name: &String.upcase/1}
               })
    end

    test "accepts map with defaults" do
      assert :ok = DataMapper.validate_mapping(%{defaults: %{status: "active"}})
    end

    test "returns error for non-map schema" do
      assert {:error, _} = DataMapper.validate_mapping("not a map")
      assert {:error, _} = DataMapper.validate_mapping(nil)
      assert {:error, _} = DataMapper.validate_mapping([])
    end

    test "returns error for transforms with non-functions" do
      assert {:error, _} =
               DataMapper.validate_mapping(%{
                 transforms: %{name: "not a function"}
               })
    end

    test "returns error for invalid field_map type" do
      assert {:error, _} = DataMapper.validate_mapping(%{field_map: "not a map"})
    end
  end

  describe "update_mappings/2 and get_mappings/1" do
    test "stores and retrieves a mapping" do
      connector_id = "test_connector_#{:erlang.unique_integer([:positive])}"
      mapping = %{field_map: %{name: "full_name"}}

      assert :ok = DataMapper.update_mappings(connector_id, mapping)
      assert {:ok, stored} = DataMapper.get_mappings(connector_id)
      assert stored == mapping
    end

    test "returns not_found for unknown connector" do
      assert {:error, :not_found} = DataMapper.get_mappings("nonexistent_connector_xyz")
    end

    test "replaces existing mapping on update" do
      connector_id = "replace_test_#{:erlang.unique_integer([:positive])}"
      mapping1 = %{field_map: %{a: "b"}}
      mapping2 = %{field_map: %{c: "d"}}

      :ok = DataMapper.update_mappings(connector_id, mapping1)
      :ok = DataMapper.update_mappings(connector_id, mapping2)

      {:ok, stored} = DataMapper.get_mappings(connector_id)
      assert stored == mapping2
    end

    test "returns error for invalid schema" do
      assert {:error, _} = DataMapper.update_mappings("any", "not a map")
    end
  end

  describe "transform_request/3 — passthrough when no mapping" do
    test "returns data unchanged when no mapping exists" do
      connector_id = "no_map_connector_#{:erlang.unique_integer([:positive])}"
      data = %{name: "Alice", age: 30}

      assert {:ok, result} = DataMapper.transform_request(connector_id, "op", data)
      assert result == data
    end
  end

  describe "transform_request/3 — with field_map" do
    test "renames keys according to field_map" do
      connector_id = "rename_test_#{:erlang.unique_integer([:positive])}"

      :ok =
        DataMapper.update_mappings(connector_id, %{field_map: %{name: "full_name", age: "years"}})

      data = %{name: "Bob", age: 25}
      assert {:ok, result} = DataMapper.transform_request(connector_id, "op", data)
      assert Map.has_key?(result, "full_name")
      assert Map.has_key?(result, "years")
      refute Map.has_key?(result, :name)
      refute Map.has_key?(result, :age)
    end

    test "applies defaults for missing keys" do
      connector_id = "defaults_test_#{:erlang.unique_integer([:positive])}"
      :ok = DataMapper.update_mappings(connector_id, %{defaults: %{status: "active"}})

      data = %{name: "Carol"}
      assert {:ok, result} = DataMapper.transform_request(connector_id, "op", data)
      assert Map.get(result, :status) == "active"
    end

    test "applies transform functions to values" do
      connector_id = "transform_test_#{:erlang.unique_integer([:positive])}"

      :ok =
        DataMapper.update_mappings(connector_id, %{
          transforms: %{name: &String.upcase/1}
        })

      data = %{name: "dave"}
      assert {:ok, result} = DataMapper.transform_request(connector_id, "op", data)
      assert result.name == "DAVE"
    end
  end

  describe "transform_response/3" do
    test "returns data unchanged when no mapping exists" do
      connector_id = "no_map_resp_#{:erlang.unique_integer([:positive])}"
      data = %{full_name: "Eve", years: 40}

      assert {:ok, result} = DataMapper.transform_response(connector_id, "op", data)
      assert result == data
    end

    test "inverts field_map when transforming response" do
      connector_id = "invert_test_#{:erlang.unique_integer([:positive])}"
      :ok = DataMapper.update_mappings(connector_id, %{field_map: %{name: "full_name"}})

      # Response comes with remote key "full_name", should map back to local :name
      data = %{"full_name" => "Frank"}
      assert {:ok, result} = DataMapper.transform_response(connector_id, "op", data)
      assert Map.has_key?(result, :name)
    end
  end

  describe "transform_request/3 — non-map data passthrough" do
    test "returns data as-is when not a map" do
      assert {:ok, "some string"} =
               DataMapper.transform_request("any", "op", "some string")
    end
  end

  describe "generic CRUD API" do
    test "list_all/0 returns ok tuple with list" do
      assert {:ok, list} = DataMapper.list_all()
      assert is_list(list)
    end

    test "get_by_id/1 returns ok tuple" do
      result = DataMapper.get_by_id("some_id")
      assert match?({:ok, _}, result)
    end

    test "create/1 with connector_id returns ok tuple" do
      connector_id = "create_test_#{:erlang.unique_integer([:positive])}"
      params = %{connector_id: connector_id, field_map: %{}}
      assert {:ok, created} = DataMapper.create(params)
      assert created.id == connector_id
    end

    test "create/1 without connector_id generates id" do
      assert {:ok, created} = DataMapper.create(%{some_field: "value"})
      assert is_binary(created.id)
    end

    test "update/2 stores and returns updated params" do
      connector_id = "update_test_#{:erlang.unique_integer([:positive])}"
      params = %{field_map: %{}}
      assert {:ok, updated} = DataMapper.update(connector_id, params)
      assert updated.id == connector_id
    end

    test "delete/1 returns ok with deleted marker" do
      connector_id = "delete_test_#{:erlang.unique_integer([:positive])}"
      :ok = DataMapper.update_mappings(connector_id, %{})
      assert {:ok, %{deleted: true}} = DataMapper.delete(connector_id)
    end
  end
end
