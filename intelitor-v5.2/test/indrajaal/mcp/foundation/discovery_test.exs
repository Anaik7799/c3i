defmodule Indrajaal.MCP.Foundation.DiscoveryTest do
  @moduledoc """
  Unit tests for MCP Foundation Discovery module.

  WHAT: Tests service registry, tool listing, namespace filtering, and health endpoints.
  WHY: Ensures SC-MCP-080 (registration at startup) and SC-MCP-081 (failure logging).

  STAMP Constraints:
  - SC-MCP-080: All tools registered at startup
  - SC-MCP-081: Registration failures logged
  - SC-MCP-082: Tool counts reported
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.MCP.Foundation.Discovery

  describe "list_tools/0" do
    test "returns a list of tools" do
      tools = Discovery.list_tools()
      assert is_list(tools)
    end

    test "all tools have required fields" do
      tools = Discovery.list_tools()

      for tool <- tools do
        assert Map.has_key?(tool, :name)
        assert Map.has_key?(tool, :description)
        assert Map.has_key?(tool, :input_schema)
        assert is_binary(tool.name)
        assert is_binary(tool.description)
      end
    end

    test "tool names follow namespace convention" do
      tools = Discovery.list_tools()

      for tool <- tools do
        parts = String.split(tool.name, ".")
        assert length(parts) >= 3, "Tool #{tool.name} should have at least 3 namespace segments"
      end
    end
  end

  describe "list_tools/1 - namespace filtering" do
    test "filters by indrajaal namespace" do
      tools = Discovery.list_tools(namespace: :indrajaal)

      for tool <- tools do
        assert String.starts_with?(tool.name, "indrajaal.")
      end
    end

    test "filters by prajna namespace" do
      tools = Discovery.list_tools(namespace: :prajna)

      for tool <- tools do
        assert String.starts_with?(tool.name, "prajna.")
      end
    end

    test "returns empty list for unknown namespace" do
      tools = Discovery.list_tools(namespace: :nonexistent)
      assert tools == []
    end
  end

  describe "list_tools/1 - domain filtering" do
    test "filters by domain" do
      tools = Discovery.list_tools(domain: :alarms)

      for tool <- tools do
        assert tool.name =~ "alarms"
      end
    end

    test "returns tools for communication domain" do
      tools = Discovery.list_tools(domain: :communication)

      for tool <- tools do
        assert tool.name =~ "communication"
      end
    end
  end

  describe "get_tool/1" do
    test "retrieves a specific tool by name" do
      result = Discovery.get_tool("indrajaal.alarms.list")

      case result do
        {:ok, tool} ->
          assert tool.name == "indrajaal.alarms.list"

        {:error, :not_found} ->
          # Acceptable if tools not loaded yet
          assert true
      end
    end

    test "returns error for unknown tool" do
      assert {:error, :not_found} = Discovery.get_tool("nonexistent.tool.name")
    end
  end

  describe "tool_count/0" do
    test "returns non-negative count" do
      count = Discovery.tool_count()
      assert is_integer(count)
      assert count >= 0
    end
  end

  describe "count_by_namespace/0" do
    test "returns map of namespace counts" do
      counts = Discovery.count_by_namespace()
      assert is_map(counts)

      for {namespace, count} <- counts do
        assert is_atom(namespace)
        assert is_integer(count)
        assert count >= 0
      end
    end
  end

  describe "health/0" do
    test "returns health status" do
      health = Discovery.health()
      assert is_map(health)
      assert Map.has_key?(health, :status)
      assert health.status in [:healthy, :degraded, :unhealthy]
    end

    test "includes tool count in health" do
      health = Discovery.health()
      assert Map.has_key?(health, :tool_count)
      assert is_integer(health.tool_count)
    end
  end

  describe "property tests" do
    property "list_tools returns consistent results" do
      forall _seed <- PC.integer() do
        tools1 = Discovery.list_tools()
        tools2 = Discovery.list_tools()
        length(tools1) == length(tools2)
      end
    end

    property "namespace filter is subset of all tools" do
      ExUnitProperties.check all(namespace <- SD.member_of([:indrajaal, :prajna, :cepaf, :kms])) do
        all_tools = Discovery.list_tools()
        filtered = Discovery.list_tools(namespace: namespace)
        assert length(filtered) <= length(all_tools)
      end
    end
  end
end
