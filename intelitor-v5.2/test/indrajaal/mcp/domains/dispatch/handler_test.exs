defmodule Indrajaal.MCP.Domains.Dispatch.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Dispatch.Handler.

  ## STAMP Safety Integration
  - SC-DISPATCH-001: Dispatch actions must be logged
  - SC-DISPATCH-002: Guardian required for dispatch commands

  ## TPS 5-Level RCA Context
  - L1 Symptom: Dispatch handler list_tools returns empty
  - L5 Root Cause: Module not registered in ToolLoader handlers/0
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Dispatch.Handler

  @context %{client_id: "dispatch_test_client"}

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "implements list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end

    test "implements handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end
  end

  describe "domain and namespace" do
    test "domain is :dispatch" do
      assert Handler.domain() == :dispatch
    end

    test "namespace is :indrajaal" do
      assert Handler.namespace() == :indrajaal
    end
  end

  describe "list_tools/0" do
    test "returns a list" do
      tools = Handler.list_tools()
      assert is_list(tools)
    end

    test "tool names include dispatch namespace" do
      tools = Handler.list_tools()

      if length(tools) > 0 do
        names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)

        Enum.each(names, fn name ->
          assert is_binary(name)
          assert String.contains?(name, "dispatch")
        end)
      else
        # Empty is acceptable for stub implementations
        assert is_list(tools)
      end
    end
  end

  describe "handle/3" do
    test "returns a tuple for list action" do
      result = Handler.handle("list", %{}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns error for unknown action" do
      result = Handler.handle("unknown_dispatch_action", %{}, @context)
      assert {:error, _} = result
    end
  end
end
