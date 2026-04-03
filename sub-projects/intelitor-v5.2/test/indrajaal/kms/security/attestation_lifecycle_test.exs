defmodule Indrajaal.KMS.Security.AttestationLifecycleTest do
  @moduledoc """
  P2-FEAT: KMS key rotation lifecycle test — generate/rotate/revoke/verify.

  WHAT: Validates attestation lifecycle: key generation, attestation creation,
        capability token management, and trust verification.
  WHY: SC-SMRITI-100 (authenticated channels), SC-SMRITI-110 (1hr TTL),
       SC-REG-003 (Ed25519 signing), SC-REG-015 (unforgeable tokens).
  CONSTRAINTS: SC-SMRITI-100, SC-SMRITI-110, SC-SMRITI-111, SC-REG-003, SC-REG-015
  TASK: af80bf52
  """
  use ExUnit.Case, async: false

  alias Indrajaal.KMS.Security.Attestation

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure ETS table for capability tokens exists
    try do
      :ets.new(:smriti_capability_tokens, [:set, :public, :named_table])
    rescue
      ArgumentError -> :ok
    end

    # Ensure ETS table for revocation list exists
    try do
      :ets.new(:smriti_revoked_tokens, [:set, :public, :named_table])
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  # ============================================================
  # Attestation Generation
  # ============================================================

  describe "attestation generation" do
    test "generate/1 creates attestation for holon" do
      result = Attestation.generate("test-holon-001")
      assert {:ok, attestation} = result
      assert attestation.holon_id == "test-holon-001"
      assert is_binary(attestation.signature)
      assert is_binary(attestation.public_key)
    end

    test "attestation has valid expiration" do
      {:ok, attestation} = Attestation.generate("test-holon-002")
      assert %DateTime{} = attestation.timestamp
      assert %DateTime{} = attestation.expires_at
      assert DateTime.compare(attestation.expires_at, attestation.timestamp) == :gt
    end

    test "attestation TTL is 3600 seconds" do
      {:ok, attestation} = Attestation.generate("test-holon-003")
      diff = DateTime.diff(attestation.expires_at, attestation.timestamp, :second)
      assert diff == Attestation.attestation_ttl()
    end

    test "attestation includes merkle root" do
      {:ok, attestation} = Attestation.generate("test-holon-004")
      assert is_binary(attestation.merkle_root)
    end

    test "attestation includes version" do
      {:ok, attestation} = Attestation.generate("test-holon-005")
      assert is_binary(attestation.version)
    end

    test "different holons get different signatures" do
      {:ok, att1} = Attestation.generate("holon-a")
      {:ok, att2} = Attestation.generate("holon-b")
      assert att1.signature != att2.signature
    end
  end

  # ============================================================
  # Attestation Verification
  # ============================================================

  describe "attestation verification" do
    test "verify/1 accepts valid attestation" do
      {:ok, attestation} = Attestation.generate("verify-holon-001")
      result = Attestation.verify(attestation)
      assert {:ok, :valid} = result
    end

    test "expired attestation is detected" do
      {:ok, attestation} = Attestation.generate("verify-holon-002")

      # Manually expire the attestation
      expired = %{attestation | expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)}
      result = Attestation.verify(expired)
      assert {:ok, :expired} = result
    end

    test "tampered signature is detected" do
      {:ok, attestation} = Attestation.generate("verify-holon-003")

      # Tamper with the signature
      tampered = %{attestation | signature: :crypto.strong_rand_bytes(64)}
      result = Attestation.verify(tampered)
      assert {:ok, :invalid} = result
    end
  end

  # ============================================================
  # Capability Token Management
  # ============================================================

  describe "capability token lifecycle" do
    test "create_capability/2 creates valid token" do
      result = Attestation.create_capability(:sync, "target-holon-001")
      assert {:ok, token} = result
      assert token.subject == "target-holon-001"
      assert :sync in token.capabilities
    end

    test "capability token has required fields" do
      {:ok, token} = Attestation.create_capability(:read, "target-holon-002")
      assert is_binary(token.id)
      assert is_binary(token.issuer)
      assert %DateTime{} = token.issued_at
      assert %DateTime{} = token.expires_at
      assert is_binary(token.signature)
    end

    test "multiple capabilities can be granted" do
      {:ok, token} = Attestation.create_capability([:sync, :read], "target-holon-003")
      assert :sync in token.capabilities
      assert :read in token.capabilities
    end

    test "invalid capability type is rejected" do
      result = Attestation.create_capability(:invalid_cap, "target-holon-004")
      assert {:error, :invalid_capability} = result
    end

    test "verify_capability/1 validates token" do
      {:ok, token} = Attestation.create_capability(:write, "target-holon-005")
      result = Attestation.verify_capability(token)
      assert {:ok, capabilities} = result
      assert :write in capabilities
    end

    test "supported capability types are defined" do
      types = Attestation.capability_types()
      assert is_list(types)
      assert :sync in types
      assert :read in types
      assert :write in types
      assert :admin in types
      assert :replicate in types
    end
  end

  # ============================================================
  # Token Revocation
  # ============================================================

  describe "token revocation" do
    test "revoke_capability/1 returns ok" do
      {:ok, token} = Attestation.create_capability(:sync, "revoke-target-001")
      result = Attestation.revoke_capability(token.id)
      assert result == :ok
    end

    test "revoked token fails verification" do
      {:ok, token} = Attestation.create_capability(:read, "revoke-target-002")
      :ok = Attestation.revoke_capability(token.id)

      result = Attestation.verify_capability(token)
      assert {:error, _reason} = result
    end
  end

  # ============================================================
  # Trust Level
  # ============================================================

  describe "trust level assessment" do
    test "trust_level/1 returns float between 0 and 1" do
      {:ok, level} = Attestation.trust_level("trust-holon-001")
      assert is_float(level)
      assert level >= 0.0
      assert level <= 1.0
    end

    test "unknown holon has baseline trust" do
      {:ok, level} = Attestation.trust_level("unknown-holon-#{System.unique_integer()}")
      assert is_float(level)
    end
  end

  # ============================================================
  # Capability Listing
  # ============================================================

  describe "capability listing" do
    test "list_capabilities/0 returns list" do
      {:ok, tokens} = Attestation.list_capabilities()
      assert is_list(tokens)
    end

    test "created capabilities appear in list" do
      {:ok, token} = Attestation.create_capability(:sync, "list-target-001")
      {:ok, tokens} = Attestation.list_capabilities()

      token_ids = Enum.map(tokens, & &1.id)
      assert token.id in token_ids
    end
  end
end
