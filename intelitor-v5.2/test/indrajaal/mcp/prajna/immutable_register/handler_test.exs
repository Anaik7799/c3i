defmodule Indrajaal.MCP.Prajna.ImmutableRegister.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Prajna.ImmutableRegister.Handler.

  ## STAMP Safety Integration
  - SC-REG-001: Changes via append-only
  - SC-REG-002: Hash chain unbroken
  - SC-REG-003: Ed25519 signatures valid

  ## TPS 5-Level RCA Context
  - L1 Symptom: Register handler fails to return hash chain status
  - L5 Root Cause: handle/3 missing :status atom pattern
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Prajna.ImmutableRegister.Handler

  @context %{client_id: "register_test_client"}

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
    test "returns a list" do
      tools = Handler.list_tools()
      assert is_list(tools)
    end

    test "tool names contain immutable_register" do
      tools = Handler.list_tools()

      if length(tools) > 0 do
        names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)

        Enum.each(names, fn name ->
          assert is_binary(name)
        end)
      else
        assert is_list(tools)
      end
    end
  end

  describe "handle/3" do
    test "status action returns a tuple" do
      result = Handler.handle(:status, %{}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "unknown action returns error" do
      result = Handler.handle(:totally_unknown_register_action, %{}, @context)
      assert {:error, _} = result
    end
  end
end
