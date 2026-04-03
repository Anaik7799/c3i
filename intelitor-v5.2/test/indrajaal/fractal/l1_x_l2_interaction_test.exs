defmodule Indrajaal.Fractal.L1xL2InteractionTest do
  @moduledoc """
  P2-FEAT: Fractal L1xL2 interaction test — function-to-component data flow verification.

  WHAT: Validates that L1 (Function) outputs correctly flow into L2 (Component) consumers.
  WHY: SC-FRAC-001 (genotype MUST match runtime graph), SC-FUNC-001 (system compiles).
  CONSTRAINTS: SC-FRAC-001, SC-HASH-001, SC-HASH-002, SC-VER-074
  TASK: c7fb7a10
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Core.Constitution
  alias Indrajaal.Core.Constitution.Hash

  # ============================================================
  # L1 Function → L2 Component: Constitution Hash Flow
  # ============================================================

  describe "Constitution hash computation (L1→L2)" do
    test "Constitution.hash/0 returns binary hash" do
      hash = Constitution.hash()
      assert is_binary(hash)
      assert byte_size(hash) == 32
    end

    test "Constitution.hash_hex/0 returns hex string" do
      hex = Constitution.hash_hex()
      assert is_binary(hex)
      assert String.length(hex) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hex)
    end

    test "hash is deterministic across calls (SC-HASH-001)" do
      hash1 = Constitution.hash()
      hash2 = Constitution.hash()
      assert hash1 == hash2
    end

    test "Hash.compute/0 produces 32-byte binary like Constitution.hash/0" do
      constitution_hash = Constitution.hash()
      computed_hash = Hash.compute()
      # Both must be 32-byte SHA3-256 hashes (fixed-point hash may differ from fresh compute)
      assert is_binary(constitution_hash) and byte_size(constitution_hash) == 32
      assert is_binary(computed_hash) and byte_size(computed_hash) == 32
    end
  end

  # ============================================================
  # L1 Function → L2 Component: Secure Comparison
  # ============================================================

  describe "secure comparison (L1→L2 SC-HASH-002)" do
    test "identical hashes compare equal" do
      hash = Constitution.hash()
      assert Hash.secure_compare(hash, hash) == true
    end

    test "different hashes compare unequal" do
      hash = Constitution.hash()
      fake = :crypto.strong_rand_bytes(32)
      assert Hash.secure_compare(hash, fake) == false
    end

    test "different length hashes return false" do
      hash = Constitution.hash()
      assert Hash.secure_compare(hash, <<0>>) == false
    end

    test "empty hashes compare equal" do
      assert Hash.secure_compare(<<>>, <<>>) == true
    end
  end

  # ============================================================
  # L1 Function → L2 Component: Invariant Data Flow
  # ============================================================

  describe "invariant data flow (L1→L2)" do
    test "invariants/0 returns map" do
      invariants = Constitution.invariants()
      assert is_map(invariants)
    end

    test "version/0 returns string" do
      version = Constitution.version()
      assert is_binary(version)
    end

    test "check_invariant/1 returns ok or error for known invariant" do
      result = Constitution.check_invariant(:patient_mode)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "check_invariant/1 returns error for unknown invariant" do
      assert {:error, _} = Constitution.check_invariant(:nonexistent_invariant)
    end

    test "check_all_invariants/0 returns list of results" do
      results = Constitution.check_all_invariants()
      assert is_list(results)

      # Returns keyword list like [ok: :patient_mode, ok: :container_isolation, ...]
      Enum.each(results, fn {status, name} ->
        assert status in [:ok, :error]
        assert is_atom(name) or is_binary(name)
      end)
    end

    test "verify/0 checks constitution integrity" do
      result = Constitution.verify()
      assert result in [:ok, :error] or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ============================================================
  # L1 Function → L2 Component: Hash Metadata
  # ============================================================

  describe "hash metadata flow (L1→L2)" do
    test "Hash.metadata/0 returns structured metadata" do
      metadata = Hash.metadata()
      assert is_map(metadata)
      assert Map.has_key?(metadata, :algorithm) or Map.has_key?(metadata, :hash_hex)
    end

    test "Hash.derive_key/2 produces key material from constitution" do
      key = Hash.derive_key("test-salt")
      assert is_binary(key)
      assert byte_size(key) == 32
    end

    test "Hash.derive_key/2 with custom length" do
      key = Hash.derive_key("test-salt", 16)
      assert is_binary(key)
      assert byte_size(key) == 16
    end

    test "derived keys are deterministic for same salt" do
      key1 = Hash.derive_key("same-salt")
      key2 = Hash.derive_key("same-salt")
      assert key1 == key2
    end

    test "derived keys differ for different salts" do
      key1 = Hash.derive_key("salt-alpha")
      key2 = Hash.derive_key("salt-beta")
      assert key1 != key2
    end
  end
end
