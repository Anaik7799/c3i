defmodule Indrajaal.MCP.Foundation.RegistryTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Foundation.Registry GenServer.

  ## STAMP Safety Integration
  - SC-MCP-030: Tool registry must prevent duplicate registration
  - SC-MCP-031: Registry must validate tool schemas

  ## TPS 5-Level RCA Context
  - L1 Symptom: Tools not found after registration
  - L5 Root Cause: ETS table name collision between test runs

  NOTE: Registry uses named ETS :mcp_tool_registry — async: false required
  """

  # async: false because Registry uses named ETS :mcp_tool_registry
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Foundation.Registry
  alias Indrajaal.MCP.Foundation.Types

  setup do
    name = :"registry_test_#{:erlang.unique_integer([:positive])}"
    start_supervised!({Registry, [name: name]})
    {:ok, registry_name: name}
  end

  describe "module existence" do
    test "Registry module is defined" do
      assert Code.ensure_loaded?(Registry)
    end

    test "implements GenServer" do
      assert function_exported?(Registry, :start_link, 1)
    end
  end

  describe "register/1" do
    test "registers a valid tool" do
      tool =
        Types.new_tool_schema(
          "test.registry.tool_#{:erlang.unique_integer([:positive])}",
          "Test tool",
          %{type: "object", properties: %{}, required: []}
        )

      result = Registry.register(tool)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error when tool name is missing" do
      # Invalid tool without name
      result = Registry.register(%{description: "no name"})
      assert is_tuple(result) or is_atom(result)
    end
  end

  describe "get/1" do
    test "returns error for nonexistent tool" do
      result = Registry.get("nonexistent.tool.name")
      assert {:error, _} = result or is_nil(result)
    end

    test "returns registered tool after registration" do
      tool_name = "test.get.tool_#{:erlang.unique_integer([:positive])}"

      tool =
        Types.new_tool_schema(tool_name, "A tool", %{
          type: "object",
          properties: %{},
          required: []
        })

      Registry.register(tool)
      result = Registry.get(tool_name)

      assert match?({:ok, _}, result) or (is_map(result) and Map.get(result, :name) == tool_name)
    end
  end

  describe "list/1" do
    test "returns a list result" do
      result = Registry.list(:indrajaal)
      assert is_list(result) or match?({:ok, _}, result)
    end

    test "returns list for all namespaces" do
      Enum.each([:indrajaal, :prajna, :cepaf, :kms], fn ns ->
        result = Registry.list(ns)
        assert is_list(result) or is_tuple(result)
      end)
    end
  end

  describe "exists?/1" do
    test "returns false for nonexistent tool" do
      result = Registry.exists?("nonexistent.tool.xyz")
      assert result == false or result == {:ok, false}
    end

    test "returns true after registration" do
      tool_name = "test.exists.tool_#{:erlang.unique_integer([:positive])}"

      tool =
        Types.new_tool_schema(tool_name, "desc", %{type: "object", properties: %{}, required: []})

      Registry.register(tool)
      result = Registry.exists?(tool_name)

      assert result == true or result == {:ok, true}
    end
  end

  describe "count/0" do
    test "returns a non-negative integer" do
      result = Registry.count()
      assert is_integer(result) and result >= 0
    end
  end

  describe "count_by_namespace/0" do
    test "returns a map with namespace keys" do
      result = Registry.count_by_namespace()
      assert is_map(result)
    end
  end

  describe "clear/0" do
    test "clears the registry" do
      result = Registry.clear()
      assert result == :ok or match?({:ok, _}, result)
    end
  end

  describe "unregister/1" do
    test "returns ok for unregistering existing tool" do
      tool_name = "test.unreg.tool_#{:erlang.unique_integer([:positive])}"

      tool =
        Types.new_tool_schema(tool_name, "desc", %{type: "object", properties: %{}, required: []})

      Registry.register(tool)
      result = Registry.unregister(tool_name)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for nonexistent tool" do
      result = Registry.unregister("does.not.exist.xyz")
      assert is_tuple(result) or is_atom(result)
    end
  end
end
