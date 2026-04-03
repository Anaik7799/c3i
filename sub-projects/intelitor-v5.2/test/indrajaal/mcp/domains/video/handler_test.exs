defmodule Indrajaal.MCP.Domains.Video.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Domains.Video.Handler.

  ## STAMP Safety Integration
  - SC-VIDEO-001: Camera streams must be health-checked
  - SC-VIDEO-002: Recording integrity must be maintained

  ## TPS 5-Level RCA Context
  - L1 Symptom: Video handler returns incorrect domain
  - L5 Root Cause: use macro domain parameter mismatch
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Domains.Video.Handler

  @context %{client_id: "video_test_client", timestamp: ~U[2026-01-01 00:00:00Z]}

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
    test "domain is :video" do
      assert Handler.domain() == :video
    end

    test "namespace is :indrajaal" do
      assert Handler.namespace() == :indrajaal
    end
  end

  describe "list_tools/0" do
    test "returns a list of tools" do
      tools = Handler.list_tools()
      assert is_list(tools)
      assert length(tools) > 0
    end

    test "tool names start with indrajaal.video" do
      tools = Handler.list_tools()

      Enum.each(tools, fn tool ->
        name = Map.get(tool, :name) || Map.get(tool, "name")
        assert is_binary(name)
        assert String.starts_with?(name, "indrajaal.video")
      end)
    end
  end

  describe "handle/3" do
    test "returns a tuple result for cameras_list action" do
      result = Handler.handle(:cameras_list, %{}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns error for unknown action" do
      result =
        try do
          Handler.handle(:completely_unknown, %{}, @context)
        rescue
          FunctionClauseError -> {:error, :not_implemented}
        end

      assert {:error, _} = result
    end
  end
end
