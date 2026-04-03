defmodule Indrajaal.Federation.TrustChainTest do
  @moduledoc """
  Tests for Indrajaal.Federation.TrustChain.

  validate_chain/2 is currently a placeholder that always returns true,
  so the tests document the observable contract and guard against
  accidental regressions if a real implementation is wired in.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Federation.TrustChain

  describe "validate_chain/2 - basic contract" do
    test "returns true for a normal current/previous token pair" do
      assert TrustChain.validate_chain("token_b", "token_a") == true
    end

    test "returns true when both tokens are the same string" do
      assert TrustChain.validate_chain("token_x", "token_x") == true
    end

    test "returns a boolean, never crashes" do
      result = TrustChain.validate_chain("any_token", "any_parent")
      assert is_boolean(result)
    end
  end

  describe "validate_chain/2 - edge inputs" do
    test "accepts empty-string tokens without raising" do
      result = TrustChain.validate_chain("", "")
      assert is_boolean(result)
    end

    test "accepts binary token values" do
      result = TrustChain.validate_chain(<<1, 2, 3>>, <<4, 5, 6>>)
      assert is_boolean(result)
    end

    test "accepts nil tokens without raising" do
      result = TrustChain.validate_chain(nil, nil)
      assert is_boolean(result)
    end

    test "accepts atom tokens without raising" do
      result = TrustChain.validate_chain(:genesis, :root)
      assert is_boolean(result)
    end
  end

  describe "validate_chain/2 - module contract" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TrustChain)
    end

    test "validate_chain/2 is exported" do
      assert function_exported?(TrustChain, :validate_chain, 2)
    end

    test "validate_chain/2 does not accept zero arguments" do
      refute function_exported?(TrustChain, :validate_chain, 0)
    end

    test "validate_chain/2 does not accept one argument" do
      refute function_exported?(TrustChain, :validate_chain, 1)
    end
  end

  describe "validate_chain/2 - return-value stability" do
    test "same inputs yield the same result on repeated calls" do
      r1 = TrustChain.validate_chain("cur", "prev")
      r2 = TrustChain.validate_chain("cur", "prev")
      assert r1 == r2
    end

    test "current-token argument is the first positional argument" do
      # Documents argument order: validate_chain(current, previous)
      result = TrustChain.validate_chain("current_token", "previous_token")
      assert is_boolean(result)
    end
  end
end
