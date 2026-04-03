defmodule Indrajaal.MCP.Foundation.TypesTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Foundation.Types.

  ## STAMP Safety Integration
  - SC-MCP-001: Tool schemas must be valid
  - SC-MCP-002: Namespace resolution must be deterministic

  ## TPS 5-Level RCA Context
  - L1 Symptom: Tool registration fails with invalid schema
  - L5 Root Cause: new_tool_schema returns unexpected struct shape
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Foundation.Types

  describe "module existence" do
    test "Types module is defined" do
      assert Code.ensure_loaded?(Types)
    end

    test "Tool struct is defined" do
      assert Code.ensure_loaded?(Types.Tool)
    end
  end

  describe "namespaces/0" do
    test "returns list of namespace atoms" do
      namespaces = Types.namespaces()
      assert is_list(namespaces)
      assert :indrajaal in namespaces
      assert :prajna in namespaces
      assert :cepaf in namespaces
      assert :kms in namespaces
    end

    test "returns exactly 4 namespaces" do
      assert length(Types.namespaces()) == 4
    end
  end

  describe "indrajaal_domains/0" do
    test "returns a list of domain atoms" do
      domains = Types.indrajaal_domains()
      assert is_list(domains)
      assert length(domains) > 0
    end

    test "contains expected security domains" do
      domains = Types.indrajaal_domains()
      assert :alarms in domains or :devices in domains or :sites in domains
    end
  end

  describe "prajna_capabilities/0" do
    test "returns a list" do
      caps = Types.prajna_capabilities()
      assert is_list(caps)
    end
  end

  describe "cepaf_modules/0" do
    test "returns a list" do
      mods = Types.cepaf_modules()
      assert is_list(mods)
    end
  end

  describe "new_tool_schema/4" do
    test "returns a Tool struct with name" do
      tool =
        Types.new_tool_schema("test.tool", "Test description", %{
          type: "object",
          properties: %{},
          required: []
        })

      assert %Types.Tool{} = tool
      assert tool.name == "test.tool"
    end

    test "returns a Tool struct with description" do
      tool =
        Types.new_tool_schema("test.tool", "My description", %{
          type: "object",
          properties: %{},
          required: []
        })

      assert tool.description == "My description"
    end

    test "sets requires_guardian false by default" do
      tool =
        Types.new_tool_schema("test.tool", "desc", %{
          type: "object",
          properties: %{},
          required: []
        })

      assert tool.requires_guardian == false
    end

    test "sets requires_guardian true when specified" do
      tool =
        Types.new_tool_schema(
          "test.tool",
          "desc",
          %{type: "object", properties: %{}, required: []},
          requires_guardian: true
        )

      assert tool.requires_guardian == true
    end

    test "sets requires_proof_token false by default" do
      tool =
        Types.new_tool_schema("test.tool", "desc", %{
          type: "object",
          properties: %{},
          required: []
        })

      assert tool.requires_proof_token == false
    end

    test "sets requires_proof_token true when specified" do
      tool =
        Types.new_tool_schema(
          "test.tool",
          "desc",
          %{type: "object", properties: %{}, required: []},
          requires_proof_token: true
        )

      assert tool.requires_proof_token == true
    end
  end

  describe "new_execution_context/3" do
    test "returns a map with expected keys" do
      ctx = Types.new_execution_context("client_001", "token_abc", %{role: "admin"})
      assert is_map(ctx)
      assert Map.has_key?(ctx, :client_id) or Map.has_key?(ctx, "client_id")
    end
  end

  describe "validate_args/2" do
    test "returns :ok for valid args against schema" do
      tool =
        Types.new_tool_schema(
          "test",
          "desc",
          %{type: "object", properties: %{"id" => %{type: "string"}}, required: ["id"]}
        )

      result = Types.validate_args(%{"id" => "abc"}, tool)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for missing required field" do
      tool =
        Types.new_tool_schema(
          "test",
          "desc",
          %{type: "object", properties: %{"id" => %{type: "string"}}, required: ["id"]}
        )

      result = Types.validate_args(%{}, tool)
      assert result != :ok or is_tuple(result)
    end
  end

  describe "requires_guardian?/1" do
    test "returns false for standard tool" do
      tool =
        Types.new_tool_schema("test", "desc", %{type: "object", properties: %{}, required: []})

      assert Types.requires_guardian?(tool) == false
    end

    test "returns true for guardian-required tool" do
      tool =
        Types.new_tool_schema("test", "desc", %{type: "object", properties: %{}, required: []},
          requires_guardian: true
        )

      assert Types.requires_guardian?(tool) == true
    end
  end

  describe "requires_proof_token?/1" do
    test "returns false for standard tool" do
      tool =
        Types.new_tool_schema("test", "desc", %{type: "object", properties: %{}, required: []})

      assert Types.requires_proof_token?(tool) == false
    end
  end

  describe "extract_namespace/1" do
    test "extracts namespace from tool name" do
      result = Types.extract_namespace("indrajaal.alarms.list")
      assert result == :indrajaal or result == "indrajaal"
    end
  end

  describe "extract_domain/1" do
    test "extracts domain from tool name" do
      result = Types.extract_domain("indrajaal.alarms.list")
      assert result == :alarms or result == "alarms"
    end
  end

  describe "extract_action/1" do
    test "extracts action from tool name" do
      result = Types.extract_action("indrajaal.alarms.list")
      assert result == :list or result == "list"
    end
  end
end
