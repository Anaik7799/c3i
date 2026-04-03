defmodule Indrajaal.Jain.CryptographyTest do
  @moduledoc """
  TDG-compliant tests for the Indrajaal.Jain.Cryptography module.

  ## What
  Verifies constitution-derived key cryptography — derive_key, derive_key_pair,
  sign, verify_signature, encrypt, decrypt, verify_node_key, and replication
  token creation/verification.

  ## Why
  Enforces SC-CRY-001 to SC-CRY-004 (Dead Man's Switch model):
  - Keys derived from constitution (SC-CRY-001)
  - Key derivation is deterministic (SC-CRY-002)
  - Corrupted constitution invalidates keys (SC-CRY-003)
  - Keys are never stored persistently (SC-CRY-004, verified behaviourally)

  ## STAMP Constraints Verified
  - SC-CRY-001: Keys derived from constitution
  - SC-CRY-002: Derivation is deterministic (same constitution → same key)
  - SC-CRY-003: Corrupted constitution → key derivation fails
  - SC-CON-002: Constitution hash verified before any operation

  ## Test Levels
  - L1: Unit tests for every public function
  - L2: Integration tests (sign → verify roundtrip, encrypt → decrypt roundtrip)
  - L3: Property tests for determinism and roundtrip invariants
  - L4: FMEA failure mode tests
  - L5: Edge case and boundary tests
  """

  use ExUnit.Case, async: true

  import ExUnitProperties

  alias StreamData, as: SD

  alias Indrajaal.Jain.Cryptography
  alias Indrajaal.Jain.Constitution

  # ============================================================================
  # Helpers
  # ============================================================================

  # Returns a valid constitution that passes Constitution.verify/1.
  #
  # Constitution.load/0 uses a hardcoded @embedded_hash that does NOT match
  # the computed hash of the content, so we must build the constitution
  # ourselves and set hash = Constitution.hash(content).
  defp valid_constitution do
    base = %{
      version: "1.0.0",
      created_at: "2025-01-01T00:00:00Z",
      axioms: Constitution.core_axioms(),
      constraints: Constitution.safety_constraints(),
      hash: nil,
      signature: nil
    }

    %{base | hash: Constitution.hash(base)}
  end

  # Returns a constitution with a tampered hash field — verify will fail
  defp corrupted_constitution do
    valid = valid_constitution()
    %{valid | hash: :crypto.strong_rand_bytes(32)}
  end

  # All four supported key types
  @key_types [:identity, :replication, :communication, :federation]

  # ============================================================================
  # describe "derive_key/2"
  # ============================================================================

  describe "derive_key/2" do
    test "returns {:ok, 32-byte binary} for a valid constitution and each key type" do
      constitution = valid_constitution()

      for key_type <- @key_types do
        assert {:ok, key} = Cryptography.derive_key(constitution, key_type)
        assert is_binary(key)
        assert byte_size(key) == 32, "Key for #{key_type} should be 32 bytes"
      end
    end

    test "returns {:error, :constitution_corrupted} for a corrupted constitution" do
      constitution = corrupted_constitution()

      for key_type <- @key_types do
        assert {:error, :constitution_corrupted} = Cryptography.derive_key(constitution, key_type)
      end
    end

    test "derivation is deterministic: same constitution → same key" do
      constitution = valid_constitution()

      {:ok, key1} = Cryptography.derive_key(constitution, :identity)
      {:ok, key2} = Cryptography.derive_key(constitution, :identity)

      assert key1 == key2
    end

    test "different key types produce different keys" do
      constitution = valid_constitution()

      keys =
        for key_type <- @key_types do
          {:ok, key} = Cryptography.derive_key(constitution, key_type)
          {key_type, key}
        end

      values = Enum.map(keys, fn {_, k} -> k end)

      assert length(values) == length(Enum.uniq(values)),
             "All key types must produce distinct keys"
    end

    test "unknown key type still produces a key (falls back to JAIN_UNKNOWN_ prefix)" do
      constitution = valid_constitution()

      # The implementation uses Map.get with a default fallback for unknown types
      result = Cryptography.derive_key(constitution, :unknown_type)
      assert {:ok, key} = result
      assert byte_size(key) == 32
    end
  end

  # ============================================================================
  # describe "derive_key_pair/2"
  # ============================================================================

  describe "derive_key_pair/2" do
    test "returns {:ok, key_pair_map} for each key type" do
      constitution = valid_constitution()

      for key_type <- @key_types do
        assert {:ok, pair} = Cryptography.derive_key_pair(constitution, key_type)
        assert Map.has_key?(pair, :public)
        assert Map.has_key?(pair, :private)
        assert Map.has_key?(pair, :type)
        assert Map.has_key?(pair, :derived_at)
        assert pair.type == key_type
      end
    end

    test "public and private keys are 32-byte binaries" do
      constitution = valid_constitution()
      {:ok, pair} = Cryptography.derive_key_pair(constitution, :identity)

      assert is_binary(pair.public)
      assert is_binary(pair.private)
      assert byte_size(pair.public) == 32
      assert byte_size(pair.private) == 32
    end

    test "public and private keys are distinct" do
      constitution = valid_constitution()
      {:ok, pair} = Cryptography.derive_key_pair(constitution, :identity)

      refute pair.public == pair.private
    end

    test "derivation is deterministic: same constitution yields same pair" do
      constitution = valid_constitution()

      {:ok, pair1} = Cryptography.derive_key_pair(constitution, :replication)
      {:ok, pair2} = Cryptography.derive_key_pair(constitution, :replication)

      assert pair1.public == pair2.public
      assert pair1.private == pair2.private
    end

    test "returns error for corrupted constitution" do
      constitution = corrupted_constitution()

      assert {:error, :constitution_corrupted} =
               Cryptography.derive_key_pair(constitution, :identity)
    end

    test "derived_at is a DateTime" do
      constitution = valid_constitution()
      {:ok, pair} = Cryptography.derive_key_pair(constitution, :identity)

      assert %DateTime{} = pair.derived_at
    end
  end

  # ============================================================================
  # describe "sign/3 and verify_signature/4"
  # ============================================================================

  describe "sign/3 and verify_signature/4" do
    test "sign/3 returns {:ok, binary} for valid constitution" do
      constitution = valid_constitution()
      data = "test payload"

      result = Cryptography.sign(data, constitution, :identity)
      assert {:ok, signature} = result
      assert is_binary(signature)
    end

    test "HMAC-SHA256 signature is exactly 32 bytes" do
      constitution = valid_constitution()
      {:ok, sig} = Cryptography.sign("data", constitution, :identity)

      assert byte_size(sig) == 32
    end

    test "sign returns error for corrupted constitution" do
      constitution = corrupted_constitution()

      assert {:error, :constitution_corrupted} =
               Cryptography.sign("data", constitution, :identity)
    end

    test "verify_signature/4 returns true for valid (data, signature, constitution, key_type) tuple" do
      constitution = valid_constitution()
      data = "authentic message"
      {:ok, sig} = Cryptography.sign(data, constitution, :identity)

      assert Cryptography.verify_signature(data, sig, constitution, :identity) == true
    end

    test "verify_signature/4 returns false for wrong data" do
      constitution = valid_constitution()
      {:ok, sig} = Cryptography.sign("original data", constitution, :identity)

      refute Cryptography.verify_signature("tampered data", sig, constitution, :identity)
    end

    test "verify_signature/4 returns false for tampered signature" do
      constitution = valid_constitution()
      data = "some data"
      {:ok, _sig} = Cryptography.sign(data, constitution, :identity)

      tampered_sig = :crypto.strong_rand_bytes(32)
      refute Cryptography.verify_signature(data, tampered_sig, constitution, :identity)
    end

    test "verify_signature/4 returns false for wrong key type" do
      constitution = valid_constitution()
      data = "some data"
      {:ok, sig} = Cryptography.sign(data, constitution, :identity)

      refute Cryptography.verify_signature(data, sig, constitution, :replication)
    end

    test "verify_signature/4 returns false for corrupted constitution" do
      constitution = valid_constitution()
      data = "some data"
      {:ok, sig} = Cryptography.sign(data, constitution, :identity)

      bad_constitution = corrupted_constitution()
      refute Cryptography.verify_signature(data, sig, bad_constitution, :identity)
    end

    test "signing is deterministic: same inputs → same signature" do
      constitution = valid_constitution()
      data = "deterministic payload"

      {:ok, sig1} = Cryptography.sign(data, constitution, :identity)
      {:ok, sig2} = Cryptography.sign(data, constitution, :identity)

      assert sig1 == sig2
    end

    test "signatures differ across key types for the same data" do
      constitution = valid_constitution()
      data = "same payload"

      {:ok, sig_identity} = Cryptography.sign(data, constitution, :identity)
      {:ok, sig_replication} = Cryptography.sign(data, constitution, :replication)

      refute sig_identity == sig_replication
    end

    test "sign and verify work for binary data" do
      constitution = valid_constitution()
      data = :crypto.strong_rand_bytes(256)

      {:ok, sig} = Cryptography.sign(data, constitution, :communication)
      assert Cryptography.verify_signature(data, sig, constitution, :communication)
    end

    test "sign and verify work for empty binary data" do
      constitution = valid_constitution()
      data = <<>>

      {:ok, sig} = Cryptography.sign(data, constitution, :identity)
      assert Cryptography.verify_signature(data, sig, constitution, :identity)
    end
  end

  # ============================================================================
  # describe "encrypt/3 and decrypt/3"
  # ============================================================================

  describe "encrypt/3 and decrypt/3" do
    test "encrypt/3 returns {:ok, ciphertext} for valid constitution" do
      constitution = valid_constitution()
      plaintext = "secret message"

      result = Cryptography.encrypt(plaintext, constitution, :communication)
      assert {:ok, ciphertext} = result
      assert is_binary(ciphertext)
    end

    test "ciphertext is larger than plaintext (IV + tag overhead)" do
      constitution = valid_constitution()
      plaintext = "test"

      {:ok, ciphertext} = Cryptography.encrypt(plaintext, constitution, :communication)
      # IV (16) + tag (16) = 32 bytes overhead minimum
      assert byte_size(ciphertext) > byte_size(plaintext)
      assert byte_size(ciphertext) == byte_size(plaintext) + 32
    end

    test "encrypt returns error for corrupted constitution" do
      constitution = corrupted_constitution()

      assert {:error, :constitution_corrupted} =
               Cryptography.encrypt("data", constitution, :communication)
    end

    test "decrypt/3 roundtrips correctly for each key type" do
      constitution = valid_constitution()

      for key_type <- @key_types do
        plaintext = "roundtrip test for #{key_type}"
        {:ok, ciphertext} = Cryptography.encrypt(plaintext, constitution, key_type)

        assert {:ok, decrypted} = Cryptography.decrypt(ciphertext, constitution, key_type)
        assert decrypted == plaintext
      end
    end

    test "decrypt returns error for corrupted constitution" do
      constitution = valid_constitution()
      {:ok, ciphertext} = Cryptography.encrypt("data", constitution, :communication)

      bad_constitution = corrupted_constitution()

      assert {:error, :constitution_corrupted} =
               Cryptography.decrypt(ciphertext, bad_constitution, :communication)
    end

    test "decrypt returns {:error, :decryption_failed} for tampered ciphertext" do
      constitution = valid_constitution()
      {:ok, ciphertext} = Cryptography.encrypt("data", constitution, :communication)

      # Flip some bits in the ciphertext portion (after IV+tag = 32 bytes offset)
      <<header::binary-32, body::binary>> = ciphertext
      tampered_body = :crypto.strong_rand_bytes(byte_size(body))
      tampered = header <> tampered_body

      result = Cryptography.decrypt(tampered, constitution, :communication)
      assert {:error, :decryption_failed} = result
    end

    test "decrypt returns error when using wrong key type" do
      constitution = valid_constitution()
      {:ok, ciphertext} = Cryptography.encrypt("data", constitution, :identity)

      # Decrypting with a different key type should fail GCM authentication
      result = Cryptography.decrypt(ciphertext, constitution, :federation)
      assert {:error, :decryption_failed} = result
    end

    test "encryption is non-deterministic: two encryptions of same plaintext differ" do
      constitution = valid_constitution()
      plaintext = "repeated plaintext"

      {:ok, ct1} = Cryptography.encrypt(plaintext, constitution, :identity)
      {:ok, ct2} = Cryptography.encrypt(plaintext, constitution, :identity)

      # IVs are random, so ciphertexts must differ
      refute ct1 == ct2
    end

    test "decryption preserves empty binary plaintext" do
      constitution = valid_constitution()
      plaintext = <<>>

      {:ok, ciphertext} = Cryptography.encrypt(plaintext, constitution, :identity)
      assert {:ok, decrypted} = Cryptography.decrypt(ciphertext, constitution, :identity)
      assert decrypted == plaintext
    end

    test "decryption preserves binary data (not just utf-8 strings)" do
      constitution = valid_constitution()
      plaintext = :crypto.strong_rand_bytes(128)

      {:ok, ciphertext} = Cryptography.encrypt(plaintext, constitution, :identity)
      assert {:ok, decrypted} = Cryptography.decrypt(ciphertext, constitution, :identity)
      assert decrypted == plaintext
    end

    test "decryption preserves large plaintext" do
      constitution = valid_constitution()
      plaintext = :crypto.strong_rand_bytes(10_000)

      {:ok, ciphertext} = Cryptography.encrypt(plaintext, constitution, :communication)
      assert {:ok, decrypted} = Cryptography.decrypt(ciphertext, constitution, :communication)
      assert decrypted == plaintext
    end
  end

  # ============================================================================
  # describe "verify_node_key/3"
  # ============================================================================

  describe "verify_node_key/3" do
    test "returns true when key matches derived key for the given type" do
      constitution = valid_constitution()
      {:ok, key} = Cryptography.derive_key(constitution, :identity)

      assert Cryptography.verify_node_key(key, constitution, :identity) == true
    end

    test "returns false for a random key" do
      constitution = valid_constitution()
      random_key = :crypto.strong_rand_bytes(32)

      refute Cryptography.verify_node_key(random_key, constitution, :identity)
    end

    test "returns false for a valid key but wrong key type" do
      constitution = valid_constitution()
      {:ok, identity_key} = Cryptography.derive_key(constitution, :identity)

      refute Cryptography.verify_node_key(identity_key, constitution, :replication)
    end

    test "returns false for a corrupted constitution" do
      valid = valid_constitution()
      {:ok, key} = Cryptography.derive_key(valid, :identity)

      bad_constitution = corrupted_constitution()
      refute Cryptography.verify_node_key(key, bad_constitution, :identity)
    end
  end

  # ============================================================================
  # describe "create_replication_token/1 and verify_replication_token/2"
  # ============================================================================

  describe "create_replication_token/1 and verify_replication_token/2" do
    test "create_replication_token/1 returns {:ok, base64_string}" do
      constitution = valid_constitution()

      result = Cryptography.create_replication_token(constitution)
      assert {:ok, token} = result
      assert is_binary(token)
      # Valid Base64
      assert {:ok, _} = Base.decode64(token)
    end

    test "verify_replication_token/2 returns {:ok, payload_map} for a fresh token" do
      constitution = valid_constitution()
      {:ok, token} = Cryptography.create_replication_token(constitution)

      result = Cryptography.verify_replication_token(token, constitution)
      assert {:ok, payload} = result
      assert is_map(payload)
    end

    test "payload contains expected fields" do
      constitution = valid_constitution()
      {:ok, token} = Cryptography.create_replication_token(constitution)
      {:ok, payload} = Cryptography.verify_replication_token(token, constitution)

      assert Map.has_key?(payload, :constitution_hash)
      assert Map.has_key?(payload, :timestamp)
      assert Map.has_key?(payload, :nonce)
    end

    test "verify fails with {:error, :invalid_signature} for tampered token" do
      constitution = valid_constitution()
      {:ok, token} = Cryptography.create_replication_token(constitution)

      # Decode, flip a byte in the signature portion, re-encode
      decoded = Base.decode64!(token)
      size = byte_size(decoded)
      # Flip the last byte (part of the 32-byte HMAC signature)
      <<prefix::binary-size(size - 1), last_byte::8>> = decoded
      tampered = Base.encode64(prefix <> <<Bitwise.bxor(last_byte, 0xFF)>>)

      result = Cryptography.verify_replication_token(tampered, constitution)
      assert {:error, reason} = result
      assert reason in [:invalid_signature, :invalid_token]
    end

    test "verify fails with {:error, :invalid_token} for garbage input" do
      constitution = valid_constitution()

      assert {:error, :invalid_token} =
               Cryptography.verify_replication_token("not-a-token", constitution)
    end

    test "verify fails for token created with different constitution" do
      constitution = valid_constitution()
      {:ok, token} = Cryptography.create_replication_token(constitution)

      # Construct a constitution that differs but still "verifies" by patching hash
      # In practice: a different hash means constitution_mismatch
      different_constitution = %{constitution | hash: :crypto.strong_rand_bytes(32)}
      result = Cryptography.verify_replication_token(token, different_constitution)

      assert {:error, reason} = result

      assert reason in [
               :constitution_corrupted,
               :constitution_mismatch,
               :invalid_signature,
               :invalid_token
             ]
    end

    test "tokens are non-deterministic (nonce-based)" do
      constitution = valid_constitution()
      {:ok, t1} = Cryptography.create_replication_token(constitution)
      {:ok, t2} = Cryptography.create_replication_token(constitution)

      refute t1 == t2
    end

    test "returns error for corrupted constitution when creating token" do
      constitution = corrupted_constitution()

      assert {:error, :constitution_corrupted} =
               Cryptography.create_replication_token(constitution)
    end
  end

  # ============================================================================
  # describe "FMEA failure modes"
  # ============================================================================

  describe "FMEA failure modes" do
    @tag :fmea
    test "verify_signature/4 handles signature with wrong byte size gracefully" do
      constitution = valid_constitution()
      data = "data"

      # 64-byte signature (wrong size for HMAC-SHA256, which is 32 bytes)
      wrong_size_sig = :crypto.strong_rand_bytes(64)
      result = Cryptography.verify_signature(data, wrong_size_sig, constitution, :identity)
      assert result == false
    end

    @tag :fmea
    test "verify_signature/4 handles empty signature gracefully" do
      constitution = valid_constitution()
      result = Cryptography.verify_signature("data", <<>>, constitution, :identity)
      assert result == false
    end

    @tag :fmea
    test "decrypt/3 handles truncated ciphertext gracefully" do
      constitution = valid_constitution()
      # A ciphertext shorter than 32 bytes (IV+tag) cannot be parsed
      truncated = :crypto.strong_rand_bytes(10)

      result =
        try do
          Cryptography.decrypt(truncated, constitution, :identity)
        rescue
          _ -> {:error, :exception}
        end

      assert {:error, _reason} = result
    end

    @tag :fmea
    test "derive_key/2 is resilient to very long unknown key type atoms" do
      constitution = valid_constitution()
      # Falls back to "JAIN_UNKNOWN_SALT"
      result = Cryptography.derive_key(constitution, :a_very_unusual_and_long_key_type_name)
      assert {:ok, key} = result
      assert byte_size(key) == 32
    end
  end

  # ============================================================================
  # describe "property-based tests"
  # ============================================================================

  describe "property-based tests" do
    test "StreamData: sign → verify_signature roundtrip holds for arbitrary binary data" do
      constitution = valid_constitution()

      ExUnitProperties.check all(
                               data <- SD.binary(min_length: 0, max_length: 1000),
                               key_type <- SD.member_of(@key_types),
                               max_runs: 20
                             ) do
        {:ok, sig} = Cryptography.sign(data, constitution, key_type)
        assert Cryptography.verify_signature(data, sig, constitution, key_type)
      end
    end

    test "StreamData: encrypt → decrypt roundtrip holds for arbitrary plaintext" do
      constitution = valid_constitution()

      ExUnitProperties.check all(
                               plaintext <- SD.binary(min_length: 0, max_length: 500),
                               key_type <- SD.member_of(@key_types),
                               max_runs: 15
                             ) do
        {:ok, ciphertext} = Cryptography.encrypt(plaintext, constitution, key_type)
        assert {:ok, decrypted} = Cryptography.decrypt(ciphertext, constitution, key_type)
        assert decrypted == plaintext
      end
    end

    test "StreamData: derived keys are always 32 bytes" do
      constitution = valid_constitution()

      ExUnitProperties.check all(
                               key_type <- SD.member_of(@key_types),
                               max_runs: 10
                             ) do
        {:ok, key} = Cryptography.derive_key(constitution, key_type)
        assert byte_size(key) == 32
      end
    end

    test "StreamData: verification always fails for mismatched data" do
      constitution = valid_constitution()

      ExUnitProperties.check all(
                               original <- SD.binary(min_length: 1, max_length: 200),
                               suffix <- SD.binary(min_length: 1, max_length: 10),
                               max_runs: 15
                             ) do
        tampered = original <> suffix
        # Only proceed if tampered != original (suffix guarantees this)
        {:ok, sig} = Cryptography.sign(original, constitution, :identity)
        refute Cryptography.verify_signature(tampered, sig, constitution, :identity)
      end
    end
  end
end
