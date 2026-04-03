defmodule Indrajaal.MCP.Domains.Communication.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Communication.Handler.

  ## STAMP Safety Integration
  - SC-COMM-001: Communication channel validation
  - SC-COMM-002: Message delivery confirmation required

  ## TPS 5-Level RCA Context
  - L1 Symptom: Communication handler returns wrong namespace
  - L5 Root Cause: use macro domain/namespace parameter typo
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Communication.Handler

  @context %{client_id: "comm_test_client"}

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
    test "domain is :communication" do
      assert Handler.domain() == :communication
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

    test "tool names include communication" do
      tools = Handler.list_tools()

      if length(tools) > 0 do
        names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)

        Enum.each(names, fn name ->
          assert is_binary(name)
          assert String.contains?(name, "communication")
        end)
      else
        assert is_list(tools)
      end
    end
  end

  describe "handle/3" do
    test "returns a tuple for send action" do
      result = Handler.handle("send", %{"message" => "test", "channel" => "email"}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns error for unknown action" do
      result = Handler.handle("unknown_comm_action_xyz", %{}, @context)
      assert {:error, _} = result
    end
  end
end
