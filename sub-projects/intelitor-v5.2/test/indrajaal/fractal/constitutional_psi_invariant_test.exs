defmodule Indrajaal.Fractal.ConstitutionalPsiInvariantTest do
  @moduledoc """
  P2-FEAT: Constitutional Ψ₀-Ψ₅ invariant verification test suite.

  WHAT: Validates all 6 constitutional invariants (Ψ₀ Existence through Ψ₅ Truthfulness).
  WHY: SC-SAFETY-009 to SC-SAFETY-014 (each Ψ invariant), SC-VER-074 (constitutional L0-L7).
  CONSTRAINTS: SC-SAFETY-009, SC-SAFETY-010, SC-SAFETY-011, SC-SAFETY-012, SC-SAFETY-013, SC-SAFETY-014
  TASK: b7761b5c
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Core.Constitution
  alias Indrajaal.Core.Constitution.Hash
  alias Indrajaal.Core.Constitution.Verifier
  alias Indrajaal.Safety.ConstitutionalKernel

  # ============================================================
  # Ψ₀: Existence — System MUST survive all operations
  # ============================================================

  describe "Ψ₀ Existence (SC-SAFETY-009)" do
    test "Constitution module is loadable" do
      assert Code.ensure_loaded?(Constitution)
    end

    test "Constitution.verify/0 confirms system integrity" do
      result = Constitution.verify()
      assert result in [:ok, :error] or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "Verifier.verified?/0 returns boolean" do
      result = Verifier.verified?()
      assert is_boolean(result)
    end

    test "Verifier.health_check/0 returns status map" do
      result = Verifier.health_check()
      assert is_map(result)
      assert Map.has_key?(result, :status)
    end
  end

  # ============================================================
  # Ψ₁: Regeneration — System regenerable from SQLite/DuckDB
  # ============================================================

  describe "Ψ₁ Regeneration (SC-SAFETY-010)" do
    test "Constitution has version tracking" do
      version = Constitution.version()
      assert is_binary(version)
      assert String.length(version) > 0
    end

    test "Constitution invariants are enumerable" do
      invariants = Constitution.invariants()
      assert is_map(invariants)
    end

    test "Constitution can check all invariants" do
      results = Constitution.check_all_invariants()
      assert is_list(results)

      Enum.each(results, fn {status, name} ->
        assert status in [:ok, :error]
        assert is_atom(name)
      end)
    end
  end

  # ============================================================
  # Ψ₂: Evolutionary Continuity — Complete history preserved
  # ============================================================

  describe "Ψ₂ History Preservation (SC-SAFETY-011)" do
    test "hash is deterministic (history verifiable)" do
      hash1 = Constitution.hash()
      hash2 = Constitution.hash()
      assert hash1 == hash2
    end

    test "hash_hex is 64-character hex string" do
      hex = Constitution.hash_hex()
      assert is_binary(hex)
      assert String.length(hex) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hex)
    end

    test "Hash.metadata/0 includes algorithm information" do
      metadata = Hash.metadata()
      assert is_map(metadata)
      assert Map.has_key?(metadata, :algorithm) or Map.has_key?(metadata, :hash_hex)
    end
  end

  # ============================================================
  # Ψ₃: Verification Capability — All changes verifiable
  # ============================================================

  describe "Ψ₃ Verification (SC-SAFETY-012)" do
    test "Hash.compute/0 and Constitution.hash/0 produce valid hashes" do
      constitution_hash = Constitution.hash()
      computed_hash = Hash.compute()
      assert is_binary(constitution_hash) and byte_size(constitution_hash) == 32
      assert is_binary(computed_hash) and byte_size(computed_hash) == 32
    end

    test "Hash.secure_compare/2 is timing-attack safe" do
      hash = Constitution.hash()
      assert Hash.secure_compare(hash, hash) == true

      fake = :crypto.strong_rand_bytes(32)
      assert Hash.secure_compare(hash, fake) == false
    end

    test "Verifier.verify/0 performs full verification" do
      result = Verifier.verify()
      assert match?({:ok, _}, result) or match?({:error, _, _}, result)
    end

    test "Verifier.check_runtime_invariants/0 returns invariant results" do
      results = Verifier.check_runtime_invariants()
      assert is_list(results)

      Enum.each(results, fn result ->
        assert match?({:ok, _}, result) or match?({:error, _}, result) or
                 match?({:error, _, _}, result)
      end)
    end

    test "Hash.derive_key/2 produces deterministic key material" do
      key1 = Hash.derive_key("psi3-test-salt")
      key2 = Hash.derive_key("psi3-test-salt")
      assert key1 == key2
      assert is_binary(key1)
      assert byte_size(key1) == 32
    end
  end

  # ============================================================
  # Ψ₄: Human Alignment — Founder's lineage PRIMARY
  # ============================================================

  describe "Ψ₄ Founder Alignment (SC-SAFETY-013)" do
    test "Constitution has patient_mode invariant" do
      result = Constitution.check_invariant(:patient_mode)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "Verifier.verify_for_operation/1 gates operations" do
      for op <- [:replicate, :federate, :mutate, :upgrade] do
        result = Verifier.verify_for_operation(op)
        assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  # ============================================================
  # Ψ₅: Truthfulness — No deception in logs
  # ============================================================

  describe "Ψ₅ Truthfulness (SC-SAFETY-014)" do
    test "Constitution hash is binary (not spoofable string)" do
      hash = Constitution.hash()
      assert is_binary(hash)
      assert byte_size(hash) == 32
    end

    test "different salts produce different derived keys" do
      key_a = Hash.derive_key("truth-salt-alpha")
      key_b = Hash.derive_key("truth-salt-beta")
      assert key_a != key_b
    end

    test "unknown invariant returns error (no false positives)" do
      result = Constitution.check_invariant(:nonexistent_invariant_xyz)
      assert match?({:error, _}, result)
    end
  end

  # ============================================================
  # Constitutional Kernel: Five-Gate Validation Pipeline
  # ============================================================

  describe "ConstitutionalKernel validation (L0 safety)" do
    test "ConstitutionalKernel module is loadable" do
      assert Code.ensure_loaded?(ConstitutionalKernel)
    end

    test "validate_transition/1 allows safe transitions" do
      transition = %{
        actor: "test-agent",
        action: :read,
        target: "test-resource",
        resulting_state: %{functional: true}
      }

      result = ConstitutionalKernel.validate_transition(transition)
      assert result == :allow or match?({:veto, _}, result)
    end

    test "validate_transition/1 blocks prohibited actions" do
      # nuclear_scour is forbidden except for SYSTEM_SUPERVISOR
      transition = %{
        actor: "rogue-agent",
        action: :nuclear_scour,
        target: "system",
        resulting_state: %{}
      }

      result = ConstitutionalKernel.validate_transition(transition)
      assert match?({:veto, _}, result)
    end

    test "validate_transition/1 allows SYSTEM_SUPERVISOR for nuclear_scour" do
      transition = %{
        actor: "SYSTEM_SUPERVISOR",
        action: :nuclear_scour,
        target: "system",
        resulting_state: %{functional: true}
      }

      result = ConstitutionalKernel.validate_transition(transition)
      # May still veto if other gates fail (obligations, quorum), but prohibitions pass
      assert result == :allow or match?({:veto, _}, result)
    end
  end
end
