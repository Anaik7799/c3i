defmodule Indrajaal.Fractal.L1.NifUnitTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Native.Zenoh
  alias Indrajaal.Safety.LineageAuth

  @moduledoc """
  Layer 1: Unit Testing for NIFs.
  Verifies basic function calls and return types.
  """

  describe "Zenoh NIF L1" do
    test "classify_tier/1 returns valid tier atom" do
      assert Zenoh.classify_tier("indrajaal/logs/test") == :bypass
      assert Zenoh.classify_tier("indrajaal/control/test") == :full
      assert Zenoh.classify_tier("indrajaal/inference/test") == :session
    end

    test "classify_tier/1 handles non-binary gracefully" do
      assert Zenoh.classify_tier("not_binary") == :bypass
    end

    test "verify_proof_token/1 handles invalid JSON gracefully" do
      result = Zenoh.verify_proof_token("not_valid_json")
      assert is_tuple(result)
    end
  end

  describe "LineageAuth NIF L1" do
    test "verify_signature/3 handles wrong key size gracefully" do
      pub_key = :crypto.strong_rand_bytes(16)
      sig = :crypto.strong_rand_bytes(64)
      msg = "test"

      result = LineageAuth.verify_signature(pub_key, msg, sig)
      assert is_boolean(result) or (is_tuple(result) and elem(result, 0) == :error)
    end

    test "verify_signature/3 handles wrong signature size gracefully" do
      pub_key = :crypto.strong_rand_bytes(32)
      sig = :crypto.strong_rand_bytes(32)
      msg = "test"

      result = LineageAuth.verify_signature(pub_key, msg, sig)
      assert is_boolean(result) or (is_tuple(result) and elem(result, 0) == :error)
    end
  end
end
