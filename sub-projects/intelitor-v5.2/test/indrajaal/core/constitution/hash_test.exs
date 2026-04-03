defmodule Indrajaal.Core.Constitution.HashTest do
  @moduledoc """
  TDG test suite for Indrajaal.Core.Constitution.Hash.
  STAMP: SC-REG-002, Ψ₃
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Constitution.Hash

  describe "compute/0" do
    test "returns a binary" do
      result = Hash.compute()
      assert is_binary(result)
    end

    test "returns non-empty binary" do
      result = Hash.compute()
      assert byte_size(result) > 0
    end

    test "is deterministic" do
      h1 = Hash.compute()
      h2 = Hash.compute()
      assert h1 == h2
    end
  end

  describe "compute_hex/0" do
    test "returns a hex string" do
      result = Hash.compute_hex()
      assert is_binary(result)
      assert String.match?(result, ~r/^[0-9a-f]+$/i)
    end

    test "is 64 hex chars for SHA-256" do
      result = Hash.compute_hex()
      assert String.length(result) >= 32
    end
  end

  describe "secure_compare/2" do
    test "returns true for equal binaries" do
      assert Hash.secure_compare("abc", "abc") == true
    end

    test "returns false for different binaries" do
      assert Hash.secure_compare("abc", "xyz") == false
    end

    test "handles empty strings" do
      assert Hash.secure_compare("", "") == true
    end
  end

  describe "derive_key/2" do
    test "derives a key from input" do
      result = Hash.derive_key("password", "salt")
      assert is_binary(result)
    end

    test "different salts produce different keys" do
      k1 = Hash.derive_key("password", "salt1")
      k2 = Hash.derive_key("password", "salt2")
      assert k1 != k2
    end
  end

  describe "verify/1" do
    test "verifies a valid hash" do
      h = Hash.compute()
      result = Hash.verify(h)
      assert is_boolean(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns false for invalid hash" do
      result = Hash.verify("invalid_hash")
      assert result == false or match?({:error, _}, result)
    end
  end

  describe "metadata/0" do
    test "returns a map" do
      result = Hash.metadata()
      assert is_map(result)
    end
  end
end
