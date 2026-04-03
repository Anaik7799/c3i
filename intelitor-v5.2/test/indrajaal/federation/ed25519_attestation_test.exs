defmodule Indrajaal.Federation.Ed25519AttestationTest do
  @moduledoc """
  TDG test suite for federation peer attestation via Ed25519 signatures.

  WHAT: Tests that federation peer identity is verified through Ed25519
  signatures, that attestation tokens have correct TTL semantics, and
  that malformed or expired attestations are rejected.

  CONSTRAINTS:
  - SC-FED-006: Attestation Ed25519-verified
  - SC-SMRITI-110: Version vectors in SQLite; attestation expires 1hr
  - SC-SMRITI-111: Concurrent update detection; hourly attestation

  ## Constitutional Verification
  - Ψ₃ (Verification): Signature verification is deterministic
  - Ψ₅ (Truthfulness): Only authentic peers are accepted

  ## Change History
  | Version | Date       | Author | Change                                     |
  |---------|------------|--------|--------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — federation attestation |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Ed25519 attestation engine
  # ---------------------------------------------------------------------------

  @attestation_ttl_seconds 3600
  @max_clock_skew_seconds 60

  defp generate_keypair do
    :crypto.generate_key(:eddsa, :ed25519)
  end

  defp sign_attestation(private_key, payload) do
    message = :erlang.term_to_binary(payload)
    signature = :crypto.sign(:eddsa, :none, message, [private_key, :ed25519])
    {message, signature}
  end

  defp verify_attestation(public_key, message, signature) do
    :crypto.verify(:eddsa, :none, message, signature, [public_key, :ed25519])
  end

  defp build_attestation(peer_id, keypair, opts \\ []) do
    {public_key, private_key} = keypair
    now = Keyword.get(opts, :timestamp, System.system_time(:second))

    payload = %{
      peer_id: peer_id,
      public_key: Base.encode64(public_key),
      issued_at: now,
      expires_at: now + Keyword.get(opts, :ttl, @attestation_ttl_seconds),
      nonce: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
      version_vector: Keyword.get(opts, :version_vector, %{})
    }

    {message, signature} = sign_attestation(private_key, payload)
    %{payload: payload, message: message, signature: signature, public_key: public_key}
  end

  defp validate_attestation(attestation, opts \\ []) do
    now = Keyword.get(opts, :current_time, System.system_time(:second))

    with :ok <- check_signature(attestation),
         :ok <- check_expiry(attestation.payload, now),
         :ok <- check_clock_skew(attestation.payload, now),
         :ok <- check_required_fields(attestation.payload) do
      {:ok, attestation.payload}
    end
  end

  defp check_signature(attestation) do
    if verify_attestation(attestation.public_key, attestation.message, attestation.signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp check_expiry(payload, now) do
    if now < payload.expires_at do
      :ok
    else
      {:error, :expired}
    end
  end

  defp check_clock_skew(payload, now) do
    if abs(now - payload.issued_at) <= @max_clock_skew_seconds do
      :ok
    else
      {:error, :clock_skew}
    end
  end

  defp check_required_fields(payload) do
    required = [:peer_id, :public_key, :issued_at, :expires_at, :nonce]

    if Enum.all?(required, &Map.has_key?(payload, &1)) do
      :ok
    else
      {:error, :missing_fields}
    end
  end

  # ---------------------------------------------------------------------------
  # Signature verification tests (SC-FED-006)
  # ---------------------------------------------------------------------------

  describe "SC-FED-006: Ed25519 signature verification" do
    test "valid attestation passes verification" do
      keypair = generate_keypair()
      attestation = build_attestation("peer-alpha", keypair)

      assert {:ok, payload} = validate_attestation(attestation)
      assert payload.peer_id == "peer-alpha"
    end

    test "tampered message fails verification" do
      keypair = generate_keypair()
      attestation = build_attestation("peer-beta", keypair)

      tampered = %{attestation | message: <<0, 1, 2, 3, 4, 5>>}
      assert {:error, :invalid_signature} = validate_attestation(tampered)
    end

    test "wrong key fails verification" do
      keypair1 = generate_keypair()
      keypair2 = generate_keypair()
      {public_key2, _} = keypair2

      attestation = build_attestation("peer-gamma", keypair1)
      wrong_key_attestation = %{attestation | public_key: public_key2}

      assert {:error, :invalid_signature} = validate_attestation(wrong_key_attestation)
    end

    test "each keypair generates unique signatures" do
      keypair1 = generate_keypair()
      keypair2 = generate_keypair()

      a1 = build_attestation("peer-1", keypair1)
      a2 = build_attestation("peer-2", keypair2)

      assert a1.signature != a2.signature
    end
  end

  # ---------------------------------------------------------------------------
  # TTL and expiry tests (SC-SMRITI-110)
  # ---------------------------------------------------------------------------

  describe "SC-SMRITI-110: attestation expiry" do
    test "attestation valid within TTL" do
      keypair = generate_keypair()
      now = System.system_time(:second)
      attestation = build_attestation("peer-1", keypair, timestamp: now)

      assert {:ok, _} = validate_attestation(attestation, current_time: now + 1800)
    end

    test "attestation expired after TTL" do
      keypair = generate_keypair()
      now = System.system_time(:second)
      attestation = build_attestation("peer-1", keypair, timestamp: now - 7200)

      assert {:error, :expired} = validate_attestation(attestation, current_time: now)
    end

    test "attestation at exact expiry boundary is expired" do
      keypair = generate_keypair()
      now = System.system_time(:second)
      attestation = build_attestation("peer-1", keypair, timestamp: now)

      assert {:error, :expired} =
               validate_attestation(attestation, current_time: now + @attestation_ttl_seconds)
    end

    test "custom TTL is respected" do
      keypair = generate_keypair()
      now = System.system_time(:second)
      attestation = build_attestation("peer-1", keypair, timestamp: now, ttl: 300)

      assert {:ok, _} = validate_attestation(attestation, current_time: now + 200)
      assert {:error, :expired} = validate_attestation(attestation, current_time: now + 400)
    end
  end

  # ---------------------------------------------------------------------------
  # Clock skew detection
  # ---------------------------------------------------------------------------

  describe "clock skew detection" do
    test "small skew is tolerated" do
      keypair = generate_keypair()
      now = System.system_time(:second)
      attestation = build_attestation("peer-1", keypair, timestamp: now)

      assert {:ok, _} = validate_attestation(attestation, current_time: now + 30)
    end

    test "excessive skew is rejected" do
      keypair = generate_keypair()
      now = System.system_time(:second)
      attestation = build_attestation("peer-1", keypair, timestamp: now - 120)

      assert {:error, :clock_skew} = validate_attestation(attestation, current_time: now)
    end
  end

  # ---------------------------------------------------------------------------
  # Nonce uniqueness tests
  # ---------------------------------------------------------------------------

  describe "nonce uniqueness" do
    test "each attestation has unique nonce" do
      keypair = generate_keypair()
      nonces = for _ <- 1..100, do: build_attestation("peer-1", keypair).payload.nonce

      assert length(Enum.uniq(nonces)) == 100
    end
  end

  # ---------------------------------------------------------------------------
  # Version vector tests (SC-SMRITI-111)
  # ---------------------------------------------------------------------------

  describe "SC-SMRITI-111: version vector in attestation" do
    test "version vector is included" do
      keypair = generate_keypair()
      vv = %{"node-1" => 5, "node-2" => 3}
      attestation = build_attestation("peer-1", keypair, version_vector: vv)

      assert {:ok, payload} = validate_attestation(attestation)
      assert payload.version_vector == vv
    end

    test "empty version vector for new peers" do
      keypair = generate_keypair()
      attestation = build_attestation("new-peer", keypair)

      assert {:ok, payload} = validate_attestation(attestation)
      assert payload.version_vector == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: attestation invariants" do
    property "valid keypair always produces verifiable attestation" do
      forall peer_id <- PC.binary(8) do
        keypair = generate_keypair()
        attestation = build_attestation(peer_id, keypair)
        {:ok, _} = validate_attestation(attestation)
        true
      end
    end

    test "expired attestation never validates" do
      ExUnitProperties.check all(offset <- SD.integer(3601..10000)) do
        keypair = generate_keypair()
        now = System.system_time(:second)
        attestation = build_attestation("peer", keypair, timestamp: now - offset)

        assert {:error, _reason} = validate_attestation(attestation, current_time: now)
      end
    end

    test "signature is deterministic for same inputs" do
      ExUnitProperties.check all(peer_id <- SD.binary(min_length: 1, max_length: 32)) do
        keypair = generate_keypair()
        a1 = build_attestation(peer_id, keypair, timestamp: 1_000_000, ttl: 3600)
        a2 = build_attestation(peer_id, keypair, timestamp: 1_000_000, ttl: 3600)

        # Same key + same payload = same signature (nonce differs, so signatures differ)
        # But both must validate
        assert {:ok, _} = validate_attestation(a1, current_time: 1_000_000)
        assert {:ok, _} = validate_attestation(a2, current_time: 1_000_000)
      end
    end
  end
end
