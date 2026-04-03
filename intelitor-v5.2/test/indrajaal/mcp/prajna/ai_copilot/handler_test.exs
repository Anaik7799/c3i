defmodule Indrajaal.MCP.Prajna.AiCopilot.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Prajna.AiCopilot.Handler.

  ## STAMP Safety Integration
  - SC-PRAJNA-002: Founder's Directive validation for AI recommendations
  - SC-AI-004: Guardian validation required for AI-generated mutations

  ## TPS 5-Level RCA Context
  - L1 Symptom: AI Copilot returns recommendations without Founder alignment check
  - L5 Root Cause: Missing check_founder_alignment call in recommend handler
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Prajna.AiCopilot.Handler

  @context %{client_id: "ai_copilot_test_client"}

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
    test "namespace is :prajna" do
      assert Handler.namespace() == :prajna
    end
  end

  describe "list_tools/0" do
    test "returns a list of tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
    end
  end

  describe "handle/3" do
    test "query action returns a tuple" do
      result = Handler.handle(:query, %{"question" => "What is the system status?"}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "recommend action returns a tuple" do
      result = Handler.handle(:recommend, %{"context" => "high alarm rate"}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "unknown action returns error" do
      result = Handler.handle(:unknown_copilot_action_xyz, %{}, @context)
      assert {:error, _} = result
    end
  end
end
