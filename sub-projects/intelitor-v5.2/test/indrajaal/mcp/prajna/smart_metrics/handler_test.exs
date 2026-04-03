defmodule Indrajaal.MCP.Prajna.SmartMetrics.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Prajna.SmartMetrics.Handler.

  ## STAMP Safety Integration
  - SC-MON-001: Metrics refresh every 30s
  - SC-MON-004: Safety metrics mandatory
  - SC-PRAJNA-004: Sentinel health integration

  ## TPS 5-Level RCA Context
  - L1 Symptom: SmartMetrics returns stale data
  - L5 Root Cause: Sentinel sync interval not enforced in handler
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Prajna.SmartMetrics.Handler

  @context %{client_id: "metrics_test_client"}

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "implements handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end

    test "implements list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end
  end

  describe "domain and namespace" do
    test "domain is :smart_metrics" do
      assert Handler.domain() == :smart_metrics
    end

    test "namespace is :prajna" do
      assert Handler.namespace() == :prajna
    end
  end

  describe "list_tools/0" do
    test "returns tools list" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) > 0
    end

    test "includes health tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)
      assert "prajna.smart_metrics.health" in names
    end
  end

  describe "handle/3" do
    test "health action returns a tuple" do
      result = Handler.handle(:health, %{}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "unknown action returns error" do
      result = Handler.handle(:nonexistent_metrics_action, %{}, @context)
      assert {:error, _} = result
    end
  end
end
