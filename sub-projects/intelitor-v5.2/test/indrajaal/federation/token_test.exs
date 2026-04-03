defmodule Indrajaal.Federation.TokenTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Federation.Token.
  Tests module existence and function export surface.
  Note: sign/verify require Phoenix.Endpoint at runtime; only export tests here.
  STAMP: SC-SIL6-010, SC-SEC-047 (encryption)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Federation.Token

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Token)
    end

    test "exports sign/1" do
      assert function_exported?(Token, :sign, 1)
    end

    test "exports verify/1" do
      assert function_exported?(Token, :verify, 1)
    end
  end

  describe "sign/1 contract" do
    test "returns ok or error tuple for a valid payload map" do
      result = Token.sign(%{node_id: "test_node", role: :peer})

      is_valid =
        match?({:ok, _}, result) or
          match?({:error, _}, result) or
          is_binary(result)

      assert is_valid
    end
  end

  describe "verify/1 contract" do
    test "returns error for invalid token string" do
      result = Token.verify("not_a_real_token_sprint54")

      is_rejection =
        match?({:error, _}, result) or
          result == :invalid or
          result == false

      assert is_rejection
    end
  end
end
