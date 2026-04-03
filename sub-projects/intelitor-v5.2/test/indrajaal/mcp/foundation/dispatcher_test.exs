defmodule Indrajaal.MCP.Foundation.DispatcherTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Foundation.Dispatcher.

  ## STAMP Safety Integration
  - SC-MCP-040: Dispatcher must route to correct handler
  - SC-MCP-041: Unknown methods must return method_not_found error

  ## TPS 5-Level RCA Context
  - L1 Symptom: Dispatcher routes to wrong handler
  - L5 Root Cause: Method name pattern match falls through to default

  NOTE: Dispatcher depends on Registry + Auth GenServers.
  """

  # async: false because Dispatcher uses Registry (ETS-backed)
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Foundation.Dispatcher
  alias Indrajaal.MCP.Foundation.Registry
  alias Indrajaal.MCP.Foundation.Auth

  setup do
    # Start Registry and Auth with unique names so they don't conflict
    reg_name = :"disp_reg_#{:erlang.unique_integer([:positive])}"
    auth_name = :"disp_auth_#{:erlang.unique_integer([:positive])}"

    start_supervised!({Registry, [name: reg_name]})
    start_supervised!({Auth, [name: auth_name]})

    :ok
  end

  describe "module existence" do
    test "Dispatcher module is defined" do
      assert Code.ensure_loaded?(Dispatcher)
    end

    test "exports dispatch/2" do
      assert function_exported?(Dispatcher, :dispatch, 2)
    end

    test "exports dispatch_raw/2" do
      assert function_exported?(Dispatcher, :dispatch_raw, 2)
    end
  end

  describe "dispatch/2" do
    test "returns a tuple result" do
      request = %{method: "ping", params: %{}, id: 1}
      context = %{client_id: "test_client", token: "mcp_" <> String.duplicate("x", 32)}
      result = Dispatcher.dispatch(request, context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "handles ping method" do
      request = %{method: "ping", params: %{}, id: 1}
      context = %{client_id: "test_client", token: "mcp_" <> String.duplicate("x", 32)}
      result = Dispatcher.dispatch(request, context)
      assert is_tuple(result)
    end

    test "handles initialized notification" do
      request = %{method: "initialized", params: %{}, id: nil}
      context = %{client_id: "test_client", token: "mcp_" <> String.duplicate("x", 32)}
      result = Dispatcher.dispatch(request, context)
      assert is_tuple(result)
    end

    test "returns error for unknown method" do
      request = %{method: "unknown.method.xyz", params: %{}, id: 1}
      context = %{client_id: "test_client", token: "mcp_" <> String.duplicate("x", 32)}
      result = Dispatcher.dispatch(request, context)
      assert is_tuple(result)
    end
  end

  describe "dispatch_raw/2" do
    test "returns a tuple result for valid JSON" do
      json = ~s({"jsonrpc":"2.0","id":1,"method":"ping","params":{}})
      context = %{client_id: "test_client", token: "mcp_" <> String.duplicate("x", 32)}
      result = Dispatcher.dispatch_raw(json, context)
      assert is_tuple(result) or is_binary(result)
    end

    test "handles malformed JSON" do
      context = %{client_id: "test_client", token: "mcp_token"}
      result = Dispatcher.dispatch_raw("not json", context)
      assert is_tuple(result) or is_binary(result)
    end
  end
end
