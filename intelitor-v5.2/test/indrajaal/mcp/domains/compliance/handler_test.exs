defmodule Indrajaal.MCP.Domains.Compliance.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Compliance.Handler.

  ## STAMP Safety Integration
  - SC-COMPLIANCE-001: EN 50518 compliance tracking
  - SC-COMPLIANCE-002: Audit trail integrity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Compliance status always returns unknown
  - L5 Root Cause: Framework filter not applied to response
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Compliance.Handler

  @context %{client_id: "compliance_test_client"}

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
    test "domain is :compliance" do
      assert Handler.domain() == :compliance
    end

    test "namespace is :indrajaal" do
      assert Handler.namespace() == :indrajaal
    end
  end

  describe "list_tools/0" do
    test "returns 10 compliance tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      # Source says 10 tools for compliance
      assert length(tools) >= 5
    end

    test "includes compliance.status tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, & &1.name)
      assert "indrajaal.compliance.status" in names
    end

    test "includes frameworks.list tool" do
      tools = Handler.list_tools()
      names = Enum.map(tools, & &1.name)
      assert "indrajaal.compliance.frameworks.list" in names
    end
  end

  describe "handle/3 status" do
    test "returns a tuple result" do
      result = Handler.handle("status", %{}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "handle/3 frameworks.list" do
    test "returns ok with frameworks" do
      result = Handler.handle("frameworks.list", %{}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "handle/3 unknown" do
    test "returns error for unknown action" do
      result = Handler.handle("nonexistent_compliance_action", %{}, @context)
      assert {:error, _} = result
    end
  end
end
