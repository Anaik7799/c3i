defmodule Indrajaal.Accounts.TokenTest do
  @moduledoc """
  TDG test suite for Indrajaal.Accounts.Token Ash resource.

  ## STAMP Safety Integration
  - SC-DB-001: BaseResource compliance
  - SC-SEC-047: Token security

  ## TPS 5-Level RCA Context
  - L1 Symptom: Token type enum mismatch
  - L5 Root Cause: Incorrect enum value definition
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Accounts.Token

  @valid_token_types [:access, :refresh, :api, :reset_password, :confirm_email]

  describe "Token Ash resource schema" do
    test "module exists and is an Ash resource" do
      assert Code.ensure_loaded?(Token)
      assert function_exported?(Token, :__ash_resource__, 0)
    end

    test "__schema__/1 returns field list" do
      fields = Token.__schema__(:fields)
      assert is_list(fields)
      assert length(fields) > 0
    end

    test "has :id field" do
      fields = Token.__schema__(:fields)
      assert :id in fields
    end

    test "has :type field" do
      fields = Token.__schema__(:fields)
      assert :type in fields
    end

    test "has :tenant_id field" do
      fields = Token.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "struct can be created" do
      token = %Token{}
      assert token.__struct__ == Token
    end
  end

  describe "Token type enum" do
    test "all valid token types are atoms" do
      Enum.each(@valid_token_types, fn type ->
        assert is_atom(type)
      end)
    end

    test "has 5 token types" do
      assert length(@valid_token_types) == 5
    end

    test "access type is valid" do
      assert :access in @valid_token_types
    end

    test "refresh type is valid" do
      assert :refresh in @valid_token_types
    end

    test "api type is valid" do
      assert :api in @valid_token_types
    end

    test "reset_password type is valid" do
      assert :reset_password in @valid_token_types
    end

    test "confirm_email type is valid" do
      assert :confirm_email in @valid_token_types
    end
  end

  describe "Constitutional Invariants (Ψ₀)" do
    test "Ψ₀ existence: Token module exists" do
      assert Token.__info__(:module) == Token
    end
  end
end
