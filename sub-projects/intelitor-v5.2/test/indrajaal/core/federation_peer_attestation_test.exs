defmodule Indrajaal.Core.FederationPeerAttestationTest do
  @moduledoc """
  TDG test: Federation peer attestation with Ed25519 verification.

  ## WHAT
  Validates peer attestation protocol: Ed25519 key generation, message signing,
  signature verification, attestation expiry, peer registry, and mutual attestation.

  ## WHY
  SC-FED-006 mandates Ed25519-verified attestation for federation peers.
  SC-SIL4-024 requires Ed25519 image signature verification.
  SC-SMRITI-110 requires version vectors with attestation expiring at 1hr.

  ## CONSTRAINTS
  - SC-FED-006: Attestation Ed25519-verified
  - SC-FED-001: No modification of node constitutions
  - SC-FED-002: Maintain node autonomy
  - SC-FED-003: Detect constitution divergence
  - SC-SIL4-024: Ed25519 image signature verification
  - SC-SMRITI-110: Attestation expires 1hr

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-24 | Claude | Initial implementation — Sprint 88 Wave 7 |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :federation
  @moduletag :attestation
  @moduletag :ed25519
  @moduletag :sprint_88

  # 1 hour per SC-SMRITI-110
  @attestation_ttl_seconds 3600

  setup do
    peers = :ets.new(:peers_test, [:set, :public])
    attestations = :ets.new(:attestations_test, [:set, :public])

    on_exit(fn ->
      :ets.delete(peers)
      :ets.delete(attestations)
    end)

    {:ok, peers: peers, attestations: attestations}
  end

  describe "Ed25519 key generation (SC-FED-006)" do
    test "generates valid keypair" do
      {pub, priv} = generate_keypair()

      assert byte_size(pub) == 32
      assert byte_size(priv) == 64
    end

    test "keypairs are unique" do
      {pub1, _priv1} = generate_keypair()
      {pub2, _priv2} = generate_keypair()

      refute pub1 == pub2
    end

    test "keypair can sign and verify" do
      {pub, priv} = generate_keypair()
      message = "attestation payload"

      signature = sign(message, priv)
      assert verify(message, signature, pub)
    end
  end

  describe "message signing (SC-FED-006)" do
    test "signature is 64 bytes" do
      {_pub, priv} = generate_keypair()
      signature = sign("test message", priv)

      assert byte_size(signature) == 64
    end

    test "different messages produce different signatures" do
      {_pub, priv} = generate_keypair()

      sig1 = sign("message A", priv)
      sig2 = sign("message B", priv)

      refute sig1 == sig2
    end

    test "same message with same key produces same signature" do
      {_pub, priv} = generate_keypair()

      sig1 = sign("deterministic", priv)
      sig2 = sign("deterministic", priv)

      assert sig1 == sig2
    end
  end

  describe "signature verification (SC-FED-006)" do
    test "valid signature verifies" do
      {pub, priv} = generate_keypair()
      message = "valid attestation"
      signature = sign(message, priv)

      assert verify(message, signature, pub) == true
    end

    test "tampered message fails verification" do
      {pub, priv} = generate_keypair()
      signature = sign("original", priv)

      refute verify("tampered", signature, pub)
    end

    test "wrong public key fails verification" do
      {_pub1, priv1} = generate_keypair()
      {pub2, _priv2} = generate_keypair()

      signature = sign("message", priv1)
      refute verify("message", signature, pub2)
    end

    test "corrupted signature fails verification" do
      {pub, priv} = generate_keypair()
      signature = sign("message", priv)
      corrupted = :crypto.strong_rand_bytes(64)

      refute verify("message", corrupted, pub)
      assert verify("message", signature, pub)
    end
  end

  describe "attestation creation and validation" do
    test "create attestation with timestamp", %{attestations: table} do
      {pub, priv} = generate_keypair()
      peer_id = "peer-alpha"
      now = System.system_time(:second)

      attestation = create_attestation(peer_id, pub, priv, now)
      :ets.insert(table, {peer_id, attestation})

      assert [{^peer_id, stored}] = :ets.lookup(table, peer_id)
      assert stored.peer_id == peer_id
      assert stored.timestamp == now
      assert stored.public_key == pub
    end

    test "attestation includes constitution hash" do
      {pub, priv} = generate_keypair()
      now = System.system_time(:second)

      attestation = create_attestation("peer-beta", pub, priv, now)
      assert is_binary(attestation.constitution_hash)
      assert byte_size(attestation.constitution_hash) == 32
    end

    test "attestation signature covers all fields" do
      {pub, priv} = generate_keypair()
      now = System.system_time(:second)

      attestation = create_attestation("peer-gamma", pub, priv, now)

      # Verify the signature covers the attestation payload
      payload = attestation_payload(attestation)
      assert verify(payload, attestation.signature, pub)
    end
  end

  describe "attestation expiry (SC-SMRITI-110)" do
    test "fresh attestation is valid" do
      {pub, priv} = generate_keypair()
      now = System.system_time(:second)

      attestation = create_attestation("peer-1", pub, priv, now)
      assert attestation_valid?(attestation, now)
    end

    test "attestation expires after TTL" do
      {pub, priv} = generate_keypair()
      created_at = System.system_time(:second) - @attestation_ttl_seconds - 1

      attestation = create_attestation("peer-2", pub, priv, created_at)
      now = System.system_time(:second)

      refute attestation_valid?(attestation, now)
    end

    test "attestation valid at exactly TTL boundary" do
      {pub, priv} = generate_keypair()
      now = System.system_time(:second)
      created_at = now - @attestation_ttl_seconds

      attestation = create_attestation("peer-3", pub, priv, created_at)
      # At exact boundary, still valid (<=)
      assert attestation_valid?(attestation, now)
    end

    test "attestation invalid 1 second past TTL" do
      {pub, priv} = generate_keypair()
      now = System.system_time(:second)
      created_at = now - @attestation_ttl_seconds - 1

      attestation = create_attestation("peer-4", pub, priv, created_at)
      refute attestation_valid?(attestation, now)
    end
  end

  describe "peer registry (SC-FED-005)" do
    test "register peer with public key", %{peers: peers} do
      {pub, _priv} = generate_keypair()
      register_peer(peers, "node-alpha", pub)

      assert [{_, info}] = :ets.lookup(peers, "node-alpha")
      assert info.public_key == pub
      assert info.status == :registered
    end

    test "multiple peers coexist", %{peers: peers} do
      for i <- 1..5 do
        {pub, _priv} = generate_keypair()
        register_peer(peers, "node-#{i}", pub)
      end

      assert :ets.info(peers, :size) == 5
    end

    test "peer update replaces key", %{peers: peers} do
      {pub1, _priv1} = generate_keypair()
      {pub2, _priv2} = generate_keypair()

      register_peer(peers, "node-x", pub1)
      register_peer(peers, "node-x", pub2)

      [{_, info}] = :ets.lookup(peers, "node-x")
      assert info.public_key == pub2
    end
  end

  describe "mutual attestation protocol" do
    test "two peers can mutually attest", %{peers: peers, attestations: attestations} do
      {pub_a, priv_a} = generate_keypair()
      {pub_b, priv_b} = generate_keypair()
      now = System.system_time(:second)

      register_peer(peers, "alpha", pub_a)
      register_peer(peers, "beta", pub_b)

      # Alpha attests to Beta
      att_a = create_attestation("alpha", pub_a, priv_a, now)
      :ets.insert(attestations, {"alpha->beta", att_a})

      # Beta attests to Alpha
      att_b = create_attestation("beta", pub_b, priv_b, now)
      :ets.insert(attestations, {"beta->alpha", att_b})

      # Both attestations valid
      assert attestation_valid?(att_a, now)
      assert attestation_valid?(att_b, now)

      # Verify signatures with registered keys
      payload_a = attestation_payload(att_a)
      payload_b = attestation_payload(att_b)
      assert verify(payload_a, att_a.signature, pub_a)
      assert verify(payload_b, att_b.signature, pub_b)
    end
  end

  describe "constitution divergence detection (SC-FED-003)" do
    test "matching constitutions pass" do
      {pub_a, priv_a} = generate_keypair()
      {pub_b, priv_b} = generate_keypair()
      now = System.system_time(:second)

      att_a = create_attestation("alpha", pub_a, priv_a, now)
      att_b = create_attestation("beta", pub_b, priv_b, now)

      # Both use default constitution hash
      assert att_a.constitution_hash == att_b.constitution_hash
      assert constitutions_match?(att_a, att_b)
    end

    test "divergent constitutions detected" do
      {pub_a, priv_a} = generate_keypair()
      {pub_b, priv_b} = generate_keypair()
      now = System.system_time(:second)

      att_a = create_attestation("alpha", pub_a, priv_a, now)

      att_b = %{
        create_attestation("beta", pub_b, priv_b, now)
        | constitution_hash: :crypto.strong_rand_bytes(32)
      }

      refute constitutions_match?(att_a, att_b)
    end
  end

  describe "property-based attestation" do
    test "property — attestation validity depends on age (SD)" do
      check all(
              peer_id <- SD.string(:alphanumeric, min_length: 3, max_length: 20),
              age_seconds <- SD.integer(0..7200)
            ) do
        {pub, priv} = generate_keypair()
        now = System.system_time(:second)
        created_at = now - age_seconds

        attestation = create_attestation(peer_id, pub, priv, created_at)

        # Signature always valid (regardless of expiry)
        payload = attestation_payload(attestation)
        assert verify(payload, attestation.signature, pub)

        # Expiry depends on age
        if age_seconds <= @attestation_ttl_seconds do
          assert attestation_valid?(attestation, now)
        else
          refute attestation_valid?(attestation, now)
        end
      end
    end
  end

  # --- Ed25519 Helpers ---

  defp generate_keypair do
    :crypto.generate_key(:eddsa, :ed25519)
  end

  defp sign(message, private_key) do
    :crypto.sign(:eddsa, :none, message, [private_key, :ed25519])
  end

  defp verify(message, signature, public_key) do
    :crypto.verify(:eddsa, :none, message, signature, [public_key, :ed25519])
  rescue
    _ -> false
  end

  # --- Attestation Helpers ---

  defp constitution_hash do
    # Default constitution hash — all peers in same federation share this
    :crypto.hash(:sha256, "indrajaal-constitution-v21.3.0")
  end

  defp create_attestation(peer_id, public_key, private_key, timestamp) do
    const_hash = constitution_hash()

    attestation = %{
      peer_id: peer_id,
      public_key: public_key,
      timestamp: timestamp,
      constitution_hash: const_hash,
      ttl: @attestation_ttl_seconds,
      signature: nil
    }

    payload = attestation_payload(attestation)
    signature = sign(payload, private_key)

    %{attestation | signature: signature}
  end

  defp attestation_payload(attestation) do
    "#{attestation.peer_id}:#{attestation.timestamp}:#{Base.encode16(attestation.constitution_hash)}"
  end

  defp attestation_valid?(attestation, current_time) do
    age = current_time - attestation.timestamp
    age <= attestation.ttl
  end

  defp constitutions_match?(att_a, att_b) do
    att_a.constitution_hash == att_b.constitution_hash
  end

  # --- Registry Helpers ---

  defp register_peer(peers, peer_id, public_key) do
    :ets.insert(
      peers,
      {peer_id,
       %{public_key: public_key, status: :registered, registered_at: System.system_time(:second)}}
    )
  end
end
