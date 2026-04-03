defmodule Indrajaal.Jain.Cryptography do
  @moduledoc """
  Dead Man's Cryptography - Constitution-Derived Keys for v20.0.0

  Implements cryptographic key derivation tied to constitution:
  - Keys derived from constitution hash
  - Corruption invalidates all keys
  - Prevents unauthorized replication
  - Ensures constitutional integrity

  ## Dead Man's Switch Model

  Key = KDF(Constitution_Hash, Salt, Iterations)

  If Constitution is modified:
  - Hash changes
  - Keys become invalid
  - Node cannot replicate
  - Node becomes sterile

  This creates a "dead man's switch" - corruption kills the node.

  ## Key Types
  - **Identity Key**: Proves node identity
  - **Replication Key**: Authorizes replication
  - **Communication Key**: Encrypts inter-node communication
  - **Federation Key**: Proves federation membership

  ## STAMP Constraints
  - SC-CRY-001: Keys MUST be derived from constitution
  - SC-CRY-002: Key derivation MUST be deterministic
  - SC-CRY-003: Corrupted constitution MUST invalidate keys
  - SC-CRY-004: Keys MUST NOT be stored persistently
  """

  require Logger

  alias Indrajaal.Jain.Constitution

  @type key_type :: :identity | :replication | :communication | :federation
  @type key :: binary()

  @type key_pair :: %{
          public: key(),
          private: key(),
          type: key_type(),
          derived_at: DateTime.t()
        }

  # KDF iterations (high for security)
  @kdf_iterations 100_000

  # Key lengths
  @key_length 32

  # Salt prefixes for different key types
  @salt_prefixes %{
    identity: "JAIN_IDENTITY_KEY_V1_",
    replication: "JAIN_REPLICATION_KEY_V1_",
    communication: "JAIN_COMMUNICATION_KEY_V1_",
    federation: "JAIN_FEDERATION_KEY_V1_"
  }

  @doc """
  Derives a key from the constitution.
  """
  @spec derive_key(Constitution.constitution(), key_type()) :: {:ok, key()} | {:error, term()}
  def derive_key(constitution, key_type) do
    # First verify constitution (SC-CRY-001)
    case Constitution.verify(constitution) do
      :ok ->
        salt = get_salt(key_type)
        key = do_derive_key(constitution.hash, salt)
        {:ok, key}

      {:error, :corrupted} ->
        {:error, :constitution_corrupted}
    end
  end

  @doc """
  Derives a key pair (public/private) from the constitution.
  """
  @spec derive_key_pair(Constitution.constitution(), key_type()) ::
          {:ok, key_pair()} | {:error, term()}
  def derive_key_pair(constitution, key_type) do
    case derive_key(constitution, key_type) do
      {:ok, seed} ->
        # Use seed to generate keypair deterministically
        {public, private} = generate_keypair_from_seed(seed)

        pair = %{
          public: public,
          private: private,
          type: key_type,
          derived_at: DateTime.utc_now()
        }

        {:ok, pair}

      error ->
        error
    end
  end

  @doc """
  Signs data using a derived key.
  """
  @spec sign(binary(), Constitution.constitution(), key_type()) ::
          {:ok, binary()} | {:error, term()}
  def sign(data, constitution, key_type) do
    case derive_key(constitution, key_type) do
      {:ok, key} ->
        signature = :crypto.mac(:hmac, :sha256, key, data)
        {:ok, signature}

      error ->
        error
    end
  end

  @doc """
  Verifies a signature using a derived key.
  """
  @spec verify_signature(binary(), binary(), Constitution.constitution(), key_type()) :: boolean()
  def verify_signature(data, signature, constitution, key_type) do
    case sign(data, constitution, key_type) do
      {:ok, expected_signature} ->
        # Constant-time comparison
        secure_compare(signature, expected_signature)

      {:error, _} ->
        false
    end
  end

  @doc """
  Encrypts data using a derived key.
  """
  @spec encrypt(binary(), Constitution.constitution(), key_type()) ::
          {:ok, binary()} | {:error, term()}
  def encrypt(plaintext, constitution, key_type) do
    case derive_key(constitution, key_type) do
      {:ok, key} ->
        # Generate random IV
        iv = :crypto.strong_rand_bytes(16)

        # Encrypt with AES-GCM
        {ciphertext, tag} =
          :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, "", true)

        # Return IV + tag + ciphertext
        {:ok, iv <> tag <> ciphertext}

      error ->
        error
    end
  end

  @doc """
  Decrypts data using a derived key.
  """
  @spec decrypt(binary(), Constitution.constitution(), key_type()) ::
          {:ok, binary()} | {:error, term()}
  def decrypt(encrypted, constitution, key_type) do
    case derive_key(constitution, key_type) do
      {:ok, key} ->
        # Extract IV, tag, ciphertext
        <<iv::binary-16, tag::binary-16, ciphertext::binary>> = encrypted

        # Decrypt with AES-GCM
        case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false) do
          plaintext when is_binary(plaintext) ->
            {:ok, plaintext}

          :error ->
            {:error, :decryption_failed}
        end

      error ->
        error
    end
  end

  @doc """
  Verifies that a node's key matches its constitution.
  """
  @spec verify_node_key(binary(), Constitution.constitution(), key_type()) :: boolean()
  def verify_node_key(node_key, constitution, key_type) do
    case derive_key(constitution, key_type) do
      {:ok, expected_key} ->
        secure_compare(node_key, expected_key)

      {:error, _} ->
        false
    end
  end

  @doc """
  Creates a replication token (proof of valid constitution).
  """
  @spec create_replication_token(Constitution.constitution()) ::
          {:ok, binary()} | {:error, term()}
  def create_replication_token(constitution) do
    payload = %{
      constitution_hash: Base.encode64(constitution.hash),
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      nonce: Base.encode64(:crypto.strong_rand_bytes(16))
    }

    payload_binary = :erlang.term_to_binary(payload)

    case sign(payload_binary, constitution, :replication) do
      {:ok, signature} ->
        token = Base.encode64(payload_binary <> signature)
        {:ok, token}

      error ->
        error
    end
  end

  @doc """
  Verifies a replication token.
  """
  @spec verify_replication_token(binary(), Constitution.constitution()) ::
          {:ok, map()} | {:error, term()}
  def verify_replication_token(token, constitution) do
    try do
      decoded = Base.decode64!(token)
      payload_size = byte_size(decoded) - 32
      <<payload_binary::binary-size(payload_size), signature::binary-32>> = decoded

      if verify_signature(payload_binary, signature, constitution, :replication) do
        payload = :erlang.binary_to_term(payload_binary)

        # Verify constitution hash matches
        if Base.decode64!(payload.constitution_hash) == constitution.hash do
          {:ok, payload}
        else
          {:error, :constitution_mismatch}
        end
      else
        {:error, :invalid_signature}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end

  # Private helpers

  defp get_salt(key_type) do
    prefix = Map.get(@salt_prefixes, key_type, "JAIN_UNKNOWN_")
    prefix <> "SALT"
  end

  defp do_derive_key(constitution_hash, salt) do
    # PBKDF2 key derivation
    :crypto.pbkdf2_hmac(:sha256, constitution_hash, salt, @kdf_iterations, @key_length)
  end

  defp generate_keypair_from_seed(seed) do
    # Use seed to generate deterministic keypair
    # In production, would use proper Ed25519 or similar
    private = :crypto.hash(:sha256, seed <> "PRIVATE")
    public = :crypto.hash(:sha256, seed <> "PUBLIC")
    {public, private}
  end

  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp secure_compare(a, b) do
    # Constant-time comparison
    :crypto.hash_equals(a, b)
  end
end
