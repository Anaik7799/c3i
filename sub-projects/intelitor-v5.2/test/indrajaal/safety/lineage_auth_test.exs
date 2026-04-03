defmodule Indrajaal.Safety.LineageAuthTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Safety.LineageAuth

  # NOTE: Ed25519 NIF validates public key is a valid curve point.
  # Random bytes will likely fail key validation with ArgumentError.
  # These tests verify correct NIF loading and proper error handling.

  describe "LineageAuth NIF" do
    test "rejects invalid signatures with proper key format" do
      # Use Erlang's crypto to generate a valid Ed25519 key pair
      {pubkey, _privkey} = :crypto.generate_key(:eddsa, :ed25519)

      # Test with invalid (random) signature - NIF should return false
      random_sig = :crypto.strong_rand_bytes(64)
      random_msg = "test message"

      # With valid key format but wrong signature, should return false
      assert false == LineageAuth.verify_signature(pubkey, random_msg, random_sig)
    end

    test "handles malformed input length" do
      # Bad arity/length should raise ArgumentError
      assert_raise ArgumentError, fn ->
        LineageAuth.verify_signature(<<1, 2>>, "msg", <<3, 4>>)
      end
    end

    test "handles random bytes - either rejects as invalid or returns false" do
      # Random 32 bytes may or may not be valid Ed25519 curve points
      # NIF should either:
      # 1. Raise ArgumentError (invalid curve point)
      # 2. Return false (valid point but wrong signature)
      random_pub = :crypto.strong_rand_bytes(32)
      random_msg = "test message"
      random_sig = :crypto.strong_rand_bytes(64)

      result =
        try do
          LineageAuth.verify_signature(random_pub, random_msg, random_sig)
        rescue
          ArgumentError -> :invalid_key
        end

      # Either outcome is acceptable - key invalid OR signature verification failed
      assert result in [false, :invalid_key]
    end
  end
end
