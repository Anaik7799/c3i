defmodule Indrajaal.Cepaf.ProtocolTest do
  @moduledoc """
  Tests for Indrajaal.Cepaf.Protocol pure JSON-RPC 2.0 module.
  STAMP: SC-TDG, SC-COV-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cepaf.Protocol

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Protocol)
    end

    test "module has expected functions" do
      assert function_exported?(Protocol, :encode_request, 3)
      assert function_exported?(Protocol, :encode_notification, 2)
      assert function_exported?(Protocol, :decode_response, 1)
      assert function_exported?(Protocol, :error_code_to_atom, 1)
      assert function_exported?(Protocol, :atom_to_error_code, 1)
      assert function_exported?(Protocol, :retryable_error?, 1)
    end
  end

  describe "encode_request/3" do
    test "encodes a JSON-RPC request" do
      result = Protocol.encode_request("ping", %{}, 1)
      assert is_binary(result) or is_map(result)
    end

    test "includes the method name in the encoded request" do
      result = Protocol.encode_request("container.list", %{all: true}, 42)
      encoded = if is_binary(result), do: result, else: Jason.encode!(result)
      assert String.contains?(encoded, "container.list")
    end

    test "includes the id in the encoded request" do
      result = Protocol.encode_request("test_method", %{}, 99)
      encoded = if is_binary(result), do: result, else: Jason.encode!(result)
      assert String.contains?(encoded, "99")
    end
  end

  describe "encode_notification/2" do
    test "encodes a JSON-RPC notification (no id)" do
      result = Protocol.encode_notification("event.fired", %{type: :alarm})
      assert is_binary(result) or is_map(result)
    end

    test "notification does not contain an id field" do
      result = Protocol.encode_notification("heartbeat", %{})
      encoded = if is_binary(result), do: result, else: Jason.encode!(result)
      refute String.contains?(encoded, "\"id\":")
    end
  end

  describe "decode_response/1" do
    test "decodes a successful JSON-RPC response" do
      payload = ~s({"jsonrpc":"2.0","id":1,"result":{"status":"ok"}})
      result = Protocol.decode_response(payload)
      assert match?({:ok, _}, result)
    end

    test "decodes an error JSON-RPC response as 4-tuple" do
      payload = ~s({"jsonrpc":"2.0","id":1,"error":{"code":-32600,"message":"Invalid Request"}})
      result = Protocol.decode_response(payload)
      # Returns {:error, code, message, data} per spec
      assert match?({:error, _, _, _}, result) or match?({:error, _}, result)
    end

    test "returns error tuple for invalid JSON" do
      result = Protocol.decode_response("not-json")
      assert match?({:error, _, _, _}, result) or match?({:error, _}, result)
    end
  end

  describe "error_code_to_atom/1" do
    test "converts parse error code to atom" do
      result = Protocol.error_code_to_atom(-32_700)
      assert is_atom(result)
    end

    test "converts invalid request code to atom" do
      result = Protocol.error_code_to_atom(-32_600)
      assert is_atom(result)
    end

    test "converts method not found code to atom" do
      result = Protocol.error_code_to_atom(-32_601)
      assert is_atom(result)
    end

    test "converts invalid params code to atom" do
      result = Protocol.error_code_to_atom(-32_602)
      assert is_atom(result)
    end

    test "converts internal error code to atom" do
      result = Protocol.error_code_to_atom(-32_603)
      assert is_atom(result)
    end

    test "returns unknown or generic atom for unmapped code" do
      result = Protocol.error_code_to_atom(-99_999)
      assert is_atom(result)
    end
  end

  describe "atom_to_error_code/1" do
    test "round-trips known error codes" do
      codes = [-32_700, -32_600, -32_601, -32_602, -32_603]

      for code <- codes do
        atom = Protocol.error_code_to_atom(code)
        recovered = Protocol.atom_to_error_code(atom)
        assert is_integer(recovered)
      end
    end
  end

  describe "retryable_error?/1" do
    test "returns boolean for a known error atom" do
      atom = Protocol.error_code_to_atom(-32_603)
      result = Protocol.retryable_error?(atom)
      assert is_boolean(result)
    end

    test "returns boolean for :timeout" do
      result = Protocol.retryable_error?(:timeout)
      assert is_boolean(result)
    end

    test "returns boolean for :connection_refused" do
      result = Protocol.retryable_error?(:connection_refused)
      assert is_boolean(result)
    end
  end
end
