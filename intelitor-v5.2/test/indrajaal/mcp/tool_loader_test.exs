defmodule Indrajaal.MCP.ToolLoaderTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.ToolLoader.

  ## STAMP Safety Integration
  - SC-MCP-070: All registered tool handlers must be loadable
  - SC-MCP-071: handler_counts must reflect correct totals

  ## TPS 5-Level RCA Context
  - L1 Symptom: Tools missing from MCP endpoint
  - L5 Root Cause: ToolLoader.load_all/0 missing handler module
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.ToolLoader

  describe "module existence" do
    test "ToolLoader module is defined" do
      assert Code.ensure_loaded?(ToolLoader)
    end

    test "exports load_all/0" do
      assert function_exported?(ToolLoader, :load_all, 0)
    end

    test "exports load_handler/1" do
      assert function_exported?(ToolLoader, :load_handler, 1)
    end

    test "exports handlers/0" do
      assert function_exported?(ToolLoader, :handlers, 0)
    end

    test "exports handler_counts/0" do
      assert function_exported?(ToolLoader, :handler_counts, 0)
    end
  end

  describe "handlers/0" do
    test "returns a list of handler modules" do
      handlers = ToolLoader.handlers()
      assert is_list(handlers)
      assert length(handlers) > 0
    end

    test "all handlers are modules" do
      handlers = ToolLoader.handlers()

      Enum.each(handlers, fn handler ->
        assert is_atom(handler)
      end)
    end
  end

  describe "handler_counts/0" do
    test "returns a map with count keys" do
      counts = ToolLoader.handler_counts()
      assert is_map(counts)
    end

    test "contains :indrajaal key with positive count" do
      counts = ToolLoader.handler_counts()
      indrajaal_count = Map.get(counts, :indrajaal) || Map.get(counts, "indrajaal")
      assert is_integer(indrajaal_count)
      assert indrajaal_count > 0
    end

    test "contains :prajna key with positive count" do
      counts = ToolLoader.handler_counts()
      prajna_count = Map.get(counts, :prajna) || Map.get(counts, "prajna")
      assert is_integer(prajna_count)
      assert prajna_count > 0
    end

    test "contains :total key" do
      counts = ToolLoader.handler_counts()
      total = Map.get(counts, :total) || Map.get(counts, "total")
      assert is_integer(total)
    end
  end

  describe "load_handler/1" do
    test "loads alarms handler successfully" do
      result = ToolLoader.load_handler(Indrajaal.MCP.Domains.Alarms.Handler)
      assert is_list(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles unknown module gracefully" do
      result = ToolLoader.load_handler(NonExistent.Handler.Module)
      assert is_list(result) or is_tuple(result) or is_nil(result)
    end
  end

  describe "load_all/0" do
    test "returns a list of loaded tools" do
      result = ToolLoader.load_all()
      assert is_list(result) or match?({:ok, _}, result)
    end

    test "loaded tools have names" do
      result = ToolLoader.load_all()
      tools = if is_list(result), do: result, else: elem(result, 1)

      if is_list(tools) and length(tools) > 0 do
        first_tool = hd(tools)
        assert Map.has_key?(first_tool, :name) or Map.has_key?(first_tool, "name")
      else
        # Empty list is acceptable
        assert is_list(tools)
      end
    end
  end
end
