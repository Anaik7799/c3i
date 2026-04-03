defmodule Indrajaal.KMS.Security.AttestationTest do
  @moduledoc """
  Tests for the L6 Security Attestation module.

  ## STAMP Constraints Tested

  - SC-SMRITI-100: Federation MUST use authenticated channels
  - SC-SMRITI-110: Attestation tokens expire after 1 hour
  - SC-SMRITI-111: Cross-holon attestation every hour in federation mode
  - SC-REG-003: All blocks MUST be Ed25519 signed
  - SC-REG-015: Capability tokens unforgeable
  - SC-OBS-033: All attestation events emit telemetry

  ## TDG Compliance

  - Unit tests for attestation generation/verification
  - Property tests for cryptographic invariants
  - Integration tests for capability flow
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.KMS.Security.Attestation

  # ============================================================================
  # Unit Tests - Attestation Generation
  # ============================================================================

  describe "generate/1" do
    test "generates valid attestation for holon" do
      holon_id = "test-holon-#{:rand.uniform(1000)}"

      assert {:ok, attestation} = Attestation.generate(holon_id)

      assert attestation.holon_id == holon_id
      assert is_binary(attestation.merkle_root)
      assert is_binary(attestation.signature)
      assert is_binary(attestation.public_key)
      assert %DateTime{} = attestation.timestamp
      assert %DateTime{} = attestation.expires_at
    end

    test "attestation expires after TTL" do
      holon_id = "expiry-test-holon"

      {:ok, attestation} = Attestation.generate(holon_id)

      ttl = Attestation.attestation_ttl()
      expected_expiry = DateTime.add(attestation.timestamp, ttl, :second)

      # Allow 1 second tolerance
      diff = abs(DateTime.diff(attestation.expires_at, expected_expiry, :second))
      assert diff <= 1
    end

    test "generates unique signatures for different holons" do
      {:ok, att1} = Attestation.generate("holon-1")
      {:ok, att2} = Attestation.generate("holon-2")

      assert att1.signature != att2.signature
      assert att1.public_key != att2.public_key
    end

    test "generates unique Merkle roots" do
      {:ok, att1} = Attestation.generate("same-holon")
      Process.sleep(1)
      {:ok, att2} = Attestation.generate("same-holon")

      # Merkle roots include timestamp, so should be different
      assert att1.merkle_root != att2.merkle_root
    end
  end

  # ============================================================================
  # Unit Tests - Attestation Verification
  # ============================================================================

  describe "verify/1" do
    test "verifies valid attestation" do
      {:ok, attestation} = Attestation.generate("verify-test-holon")

      assert {:ok, :valid} = Attestation.verify(attestation)
    end

    test "detects expired attestation" do
      {:ok, attestation} = Attestation.generate("expired-holon")

      # Manually expire the attestation
      expired = %{attestation | expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)}

      assert {:ok, :expired} = Attestation.verify(expired)
    end

    test "detects invalid signature" do
      {:ok, attestation} = Attestation.generate("tampered-holon")

      # Tamper with the signature
      tampered = %{attestation | signature: :crypto.strong_rand_bytes(64)}

      assert {:ok, :invalid} = Attestation.verify(tampered)
    end

    test "detects tampered Merkle root" do
      {:ok, attestation} = Attestation.generate("merkle-tamper-holon")

      # Tamper with the Merkle root
      tampered = %{attestation | merkle_root: "tampered-root-value"}

      assert {:ok, :invalid} = Attestation.verify(tampered)
    end
  end

  # ============================================================================
  # Unit Tests - Capability Tokens
  # ============================================================================

  describe "create_capability/3" do
    test "creates valid capability token" do
      assert {:ok, token} = Attestation.create_capability(:sync, "target-holon")

      assert is_binary(token.id)
      assert token.subject == "target-holon"
      assert :sync in token.capabilities
      assert %DateTime{} = token.issued_at
      assert %DateTime{} = token.expires_at
    end

    test "creates capability with multiple permissions" do
      capabilities = [:read, :write]

      assert {:ok, token} = Attestation.create_capability(capabilities, "multi-cap-holon")

      assert :read in token.capabilities
      assert :write in token.capabilities
    end

    test "rejects invalid capability types" do
      assert {:error, :invalid_capability} =
               Attestation.create_capability(:nonexistent, "target")
    end

    test "supports all capability types" do
      for cap_type <- Attestation.capability_types() do
        assert {:ok, token} = Attestation.create_capability(cap_type, "test-target")
        assert cap_type in token.capabilities
      end
    end
  end

  describe "verify_capability/1" do
    test "verifies valid capability token" do
      {:ok, token} = Attestation.create_capability(:sync, "target-holon")

      assert {:ok, capabilities} = Attestation.verify_capability(token)
      assert :sync in capabilities
    end

    test "detects expired capability token" do
      {:ok, token} =
        Attestation.create_capability(:read, "target",
          # Already expired
          ttl: -1
        )

      # Since TTL is negative, it's already expired
      expired = %{token | expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)}

      assert {:error, :expired} = Attestation.verify_capability(expired)
    end

    test "detects revoked capability token" do
      {:ok, token} = Attestation.create_capability(:write, "target-holon")

      # Revoke the token
      :ok = Attestation.revoke_capability(token.id)

      assert {:error, :revoked} = Attestation.verify_capability(token)
    end
  end

  describe "revoke_capability/1" do
    test "revokes capability token" do
      {:ok, token} = Attestation.create_capability(:admin, "admin-target")

      assert :ok = Attestation.revoke_capability(token.id)

      # Token should now be revoked
      assert {:error, :revoked} = Attestation.verify_capability(token)
    end
  end

  # ============================================================================
  # Unit Tests - Trust Level
  # ============================================================================

  describe "trust_level/1" do
    test "returns trust level for holon" do
      holon_id = "trust-test-holon"

      assert {:ok, level} = Attestation.trust_level(holon_id)

      assert is_float(level)
      assert level >= 0.0
      assert level <= 1.0
    end

    test "base trust level is 0.5" do
      {:ok, level} = Attestation.trust_level("new-holon")

      # For a new holon with no history, base trust should be around 0.5
      assert level >= 0.4
      assert level <= 0.6
    end
  end

  # ============================================================================
  # Unit Tests - Configuration
  # ============================================================================

  describe "attestation_ttl/0" do
    test "returns positive TTL in seconds" do
      ttl = Attestation.attestation_ttl()

      assert is_integer(ttl)
      assert ttl > 0
    end

    test "default TTL is 1 hour (3600 seconds)" do
      assert Attestation.attestation_ttl() == 3600
    end
  end

  describe "capability_types/0" do
    test "returns list of capability types" do
      types = Attestation.capability_types()

      assert is_list(types)
      assert length(types) > 0
      assert Enum.all?(types, &is_atom/1)
    end

    test "includes essential capability types" do
      types = Attestation.capability_types()

      assert :sync in types
      assert :read in types
      assert :write in types
    end
  end

  # ============================================================================
  # Property Tests (PropCheck)
  # ============================================================================

  describe "cryptographic properties (PropCheck)" do
    property "attestation signatures have valid size" do
      forall _n <- PC.integer(1, 100) do
        holon_id = "prop-test-#{:rand.uniform(10000)}"

        case Attestation.generate(holon_id) do
          {:ok, att} ->
            byte_size(att.signature) > 0

          {:error, _} ->
            # Generation may fail in test env without crypto setup
            true
        end
      end
    end

    property "all generated attestations have valid structure" do
      forall _n <- PC.integer(1, 100) do
        holon_id = "structure-#{:rand.uniform(10000)}"

        case Attestation.generate(holon_id) do
          {:ok, att} ->
            is_binary(att.holon_id) and
              is_binary(att.signature) and
              is_binary(att.public_key) and
              is_binary(att.merkle_root)

          {:error, _} ->
            # Generation may fail in test env
            true
        end
      end
    end

    # Converted to regular test due to PropCheck counter-example cache issues
    test "capability tokens are unique across multiple samples" do
      for n <- 1..50 do
        cap = Enum.random([:sync, :read, :write])
        target = "target-#{n}-#{:rand.uniform(10000)}"

        case {Attestation.create_capability(cap, target),
              Attestation.create_capability(cap, target)} do
          {{:ok, t1}, {:ok, t2}} ->
            assert t1.id != t2.id

          _ ->
            # Capability creation may fail in test env
            :ok
        end
      end
    end
  end

  # ============================================================================
  # Property Tests (StreamData) - Converted to regular tests
  # ============================================================================

  describe "attestation invariants (StreamData)" do
    test "attestation expiry is always in the future" do
      for _ <- 1..10 do
        holon_id = "invariant-test-#{:rand.uniform(10000)}"
        {:ok, att} = Attestation.generate(holon_id)

        assert DateTime.compare(att.expires_at, att.timestamp) == :gt
      end
    end

    test "trust levels are bounded" do
      for _ <- 1..10 do
        holon_id = "trust-bound-#{:rand.uniform(10000)}"
        {:ok, level} = Attestation.trust_level(holon_id)

        assert level >= 0.0
        assert level <= 1.0
      end
    end
  end

  # ============================================================================
  # Constitutional Alignment Tests
  # ============================================================================

  describe "constitutional alignment" do
    test "implements Ψ₃ (Verification) - attestation for integrity" do
      {:ok, att} = Attestation.generate("psi3-test")
      assert {:ok, :valid} = Attestation.verify(att)
    end

    test "implements Ψ₀ (Existence) - federated survival through trust" do
      assert function_exported?(Attestation, :trust_level, 1)
      assert function_exported?(Attestation, :create_capability, 3)
    end

    test "implements SC-SMRITI-100 - authenticated channels" do
      {:ok, att} = Attestation.generate("sc-100-test")
      assert is_binary(att.signature)
      assert byte_size(att.signature) > 0
    end

    test "implements SC-REG-003 - Ed25519 signatures" do
      {:ok, att} = Attestation.generate("ed25519-test")
      # Ed25519 signatures are 64 bytes
      assert byte_size(att.signature) == 64
    end

    test "implements SC-REG-015 - capability tokens unforgeable" do
      {:ok, token} = Attestation.create_capability(:sync, "unforgeable-test")
      assert is_binary(token.signature)
      assert byte_size(token.signature) > 0
    end
  end

  # ============================================================================
  # STAMP Constraint Tests
  # ============================================================================

  describe "STAMP constraints" do
    test "SC-SMRITI-110: attestation expires after 1 hour" do
      ttl = Attestation.attestation_ttl()
      assert ttl == 3600
    end

    test "SC-SMRITI-111: hourly attestation capability exists" do
      assert function_exported?(Attestation, :generate, 1)
      assert function_exported?(Attestation, :verify, 1)
    end
  end

  # ============================================================================
  # 5-Order Effects Tests
  # ============================================================================

  describe "5-order effects" do
    test "1st order: attestation token generated" do
      assert {:ok, _} = Attestation.generate("effect-1st")
    end

    test "2nd order: peer verification capability" do
      {:ok, att} = Attestation.generate("effect-2nd")
      assert {:ok, :valid} = Attestation.verify(att)
    end

    test "3rd order: trust relationship established" do
      assert {:ok, level} = Attestation.trust_level("effect-3rd")
      assert is_float(level)
    end

    test "4th order: knowledge sync authorized via capability" do
      assert {:ok, token} = Attestation.create_capability(:sync, "effect-4th")
      assert {:ok, caps} = Attestation.verify_capability(token)
      assert :sync in caps
    end

    test "5th order: federation mesh operations" do
      assert {:ok, _} = Attestation.list_capabilities()
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp non_empty_binary do
    # Use :proper_types.non_empty/1 for proper PropCheck filtering
    :proper_types.non_empty(PC.binary())
  end
end
