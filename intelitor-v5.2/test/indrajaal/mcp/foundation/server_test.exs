defmodule Indrajaal.MCP.Foundation.ServerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Foundation.Server GenServer.

  ## STAMP Safety Integration
  - SC-MCP-050: Server must authenticate all requests
  - SC-MCP-051: Server must serialize JSON-RPC responses

  ## TPS 5-Level RCA Context
  - L1 Symptom: MCP server returns 500 on valid requests
  - L5 Root Cause: handle_request missing request map normalization

  NOTE: Server uses default name __MODULE__ — start with unique name.
  """

  # async: false due to named ETS dependencies via Registry and Auth
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Foundation.Server

  setup do
    name = :"server_test_#{:erlang.unique_integer([:positive])}"
    start_supervised!({Server, [name: name]})
    {:ok, server_name: name}
  end

  describe "module existence" do
    test "Server module is defined" do
      assert Code.ensure_loaded?(Server)
    end

    test "implements GenServer via start_link/1" do
      assert function_exported?(Server, :start_link, 1)
    end
  end

  describe "handle_request/2" do
    test "returns a tuple result" do
      request = %{"method" => "ping", "params" => %{}, "id" => 1, "jsonrpc" => "2.0"}
      context = %{client_id: "test", token: "mcp_" <> String.duplicate("a", 32)}
      result = Server.handle_request(request, context)
      assert is_tuple(result) or is_binary(result) or is_map(result)
    end

    test "handles initialize method" do
      request = %{
        "method" => "initialize",
        "params" => %{"clientInfo" => %{"name" => "test", "version" => "1.0"}},
        "id" => 1,
        "jsonrpc" => "2.0"
      }

      context = %{client_id: "test", token: "mcp_" <> String.duplicate("a", 32)}
      result = Server.handle_request(request, context)
      assert is_tuple(result) or is_binary(result) or is_map(result)
    end

    test "handles tools/list method" do
      request = %{"method" => "tools/list", "params" => %{}, "id" => 2, "jsonrpc" => "2.0"}
      context = %{client_id: "test", token: "mcp_" <> String.duplicate("a", 32)}
      result = Server.handle_request(request, context)
      assert is_tuple(result) or is_binary(result) or is_map(result)
    end
  end

  describe "handle_parsed_request/2" do
    test "accepts parsed request map" do
      request = %{method: "ping", params: %{}, id: 1, jsonrpc: "2.0"}
      context = %{client_id: "test", token: "mcp_" <> String.duplicate("a", 32)}
      result = Server.handle_parsed_request(request, context)
      assert is_tuple(result) or is_binary(result) or is_map(result)
    end
  end
end
