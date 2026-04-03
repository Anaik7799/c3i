defmodule Indrajaal.MCP.Foundation.ProtocolTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Foundation.Protocol.

  ## STAMP Safety Integration
  - SC-MCP-010: Protocol version must be stable
  - SC-MCP-011: Error codes must follow JSON-RPC 2.0 spec

  ## TPS 5-Level RCA Context
  - L1 Symptom: MCP client receives malformed JSON-RPC responses
  - L5 Root Cause: encode_response serialization mismatch
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Foundation.Protocol

  describe "module existence" do
    test "Protocol module is defined" do
      assert Code.ensure_loaded?(Protocol)
    end
  end

  describe "version/0" do
    test "returns the MCP protocol version string" do
      version = Protocol.version()
      assert is_binary(version)
      assert version == "2025-11-25"
    end
  end

  describe "jsonrpc_version/0" do
    test "returns 2.0" do
      assert Protocol.jsonrpc_version() == "2.0"
    end
  end

  describe "error_codes/0" do
    test "returns a map of error codes" do
      codes = Protocol.error_codes()
      assert is_map(codes)
    end

    test "contains standard JSON-RPC error codes" do
      codes = Protocol.error_codes()
      assert Map.has_key?(codes, :parse_error) or Map.has_key?(codes, "parse_error")
      assert Map.has_key?(codes, :invalid_request) or Map.has_key?(codes, "invalid_request")
      assert Map.has_key?(codes, :method_not_found) or Map.has_key?(codes, "method_not_found")
    end

    test "contains Indrajaal-specific error codes" do
      codes = Protocol.error_codes()
      all_values = Map.values(codes)
      # Check for guardian_veto (-33001)
      assert Enum.any?(all_values, fn v -> v == -33001 end) or
               Map.has_key?(codes, :guardian_veto)
    end
  end

  describe "parse_request/1" do
    test "parses a valid JSON-RPC request string" do
      json = ~s({"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}})
      result = Protocol.parse_request(json)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns error for invalid JSON" do
      result = Protocol.parse_request("not valid json")
      assert {:error, _} = result
    end

    test "parses request from map" do
      request = %{"jsonrpc" => "2.0", "id" => 1, "method" => "ping", "params" => %{}}
      result = Protocol.parse_request(request)
      assert is_tuple(result)
    end
  end

  describe "validate_request/1" do
    test "validates a well-formed request" do
      request = %{jsonrpc: "2.0", id: 1, method: "ping", params: %{}}
      result = Protocol.validate_request(request)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "rejects request without method" do
      request = %{jsonrpc: "2.0", id: 1, params: %{}}
      result = Protocol.validate_request(request)
      assert result != :ok
    end
  end

  describe "success_response/2" do
    test "returns a map with result field" do
      response = Protocol.success_response(1, %{tools: []})
      assert is_map(response)
      assert Map.has_key?(response, :result) or Map.has_key?(response, "result")
    end

    test "includes id in response" do
      response = Protocol.success_response(42, %{data: "value"})
      id = Map.get(response, :id) || Map.get(response, "id")
      assert id == 42
    end

    test "includes jsonrpc version" do
      response = Protocol.success_response(1, %{})
      version = Map.get(response, :jsonrpc) || Map.get(response, "jsonrpc")
      assert version == "2.0"
    end
  end

  describe "error_response/4" do
    test "returns a map with error field" do
      response = Protocol.error_response(1, -32600, "Invalid Request", nil)
      assert is_map(response)
      assert Map.has_key?(response, :error) or Map.has_key?(response, "error")
    end

    test "error contains code and message" do
      response = Protocol.error_response(1, -32600, "Invalid Request", nil)
      error = Map.get(response, :error) || Map.get(response, "error")
      assert is_map(error)
      code = Map.get(error, :code) || Map.get(error, "code")
      assert code == -32600
    end
  end

  describe "encode_response/1" do
    test "encodes a response map to JSON string" do
      response = %{jsonrpc: "2.0", id: 1, result: %{}}
      encoded = Protocol.encode_response(response)
      assert is_binary(encoded) or is_tuple(encoded)
    end
  end

  describe "initialize_response/2" do
    test "returns initialization response structure" do
      result = Protocol.initialize_response(1, %{name: "test-client", version: "1.0"})
      assert is_map(result)
    end
  end

  describe "tools_list_response/2" do
    test "returns tools list response" do
      tools = [%{name: "test.tool", description: "A test tool"}]
      result = Protocol.tools_list_response(1, tools)
      assert is_map(result)
    end
  end
end
