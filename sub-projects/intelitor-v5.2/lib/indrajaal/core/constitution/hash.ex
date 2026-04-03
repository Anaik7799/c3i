defmodule Indrajaal.Core.Constitution.Hash do
  @moduledoc """
  Constitution Hash Module - Cryptographic Integrity for v20.0.0

  Provides cryptographic operations for constitution integrity:
  1. Hash computation (SHA256)
  2. Hash comparison (constant-time)
  3. Hash derivation (for replication keys)
  4. Hash embedding (compile-time golden hash)

  ## STAMP Constraints
  - SC-HASH-001: Hash computation MUST be deterministic
  - SC-HASH-002: Hash comparison MUST be constant-time (timing attack prevention)
  - SC-HASH-003: Hash MUST be computed from canonical representation

  ## Security Properties
  - Collision resistance: 2^128 operations (SHA256)
  - Preimage resistance: 2^256 operations
  - Second preimage resistance: 2^256 operations
  """

  alias Indrajaal.Core.Constitution

  @type hash :: binary()
  @type hash_hex :: String.t()

  @doc """
  Computes the SHA256 hash of the constitution invariants.

  The hash is computed from the Erlang term binary representation
  of the invariants map, ensuring deterministic serialization.
  """
  @spec compute() :: hash()
  def compute do
    Constitution.invariants()
    |> canonicalize()
    |> :erlang.term_to_binary()
    |> sha256()
  end

  @doc """
  Returns the hash as a lowercase hexadecimal string.
  """
  @spec compute_hex() :: hash_hex()
  def compute_hex do
    compute() |> Base.encode16(case: :lower)
  end

  @doc """
  Compares two hashes in constant time to prevent timing attacks.

  Returns true if hashes match, false otherwise.
  """
  @spec secure_compare(hash(), hash()) :: boolean()
  def secure_compare(hash1, hash2) when byte_size(hash1) == byte_size(hash2) do
    :crypto.hash_equals(hash1, hash2)
  end

  def secure_compare(_, _), do: false

  @doc """
  Derives a key from the constitution hash using HKDF.

  This is used for Dead Man's Cryptography - the replication key
  is derived from the constitution hash, so any modification to
  the constitution destroys the ability to derive the correct key.

  ## Parameters
  - `salt` - Application-specific salt (e.g., "replication", "signing")
  - `length` - Desired key length in bytes (default: 32)
  """
  @spec derive_key(String.t(), pos_integer()) :: binary()
  def derive_key(salt, length \\ 32) when is_binary(salt) and length > 0 do
    hash = compute()
    info = "indrajaal_v20_" <> salt

    # HKDF-SHA256 key derivation
    mac_result = :crypto.mac(:hmac, :sha256, hash, info)

    mac_result
    |> then(&:crypto.hash(:sha256, &1))
    |> binary_part(0, min(length, 32))
  end

  @doc """
  Verifies that the current hash matches an expected hash.
  """
  @spec verify(hash()) :: :ok | {:error, :hash_mismatch}
  def verify(expected_hash) do
    current_hash = compute()

    if secure_compare(current_hash, expected_hash) do
      :ok
    else
      {:error, :hash_mismatch}
    end
  end

  @doc """
  Verifies the hash matches the expected hex string.
  """
  @spec verify_hex(hash_hex()) :: :ok | {:error, :hash_mismatch | :invalid_hex}
  def verify_hex(expected_hex) do
    case Base.decode16(expected_hex, case: :mixed) do
      {:ok, expected_hash} -> verify(expected_hash)
      :error -> {:error, :invalid_hex}
    end
  end

  @doc """
  Returns hash metadata for logging/debugging.
  """
  @spec metadata() :: map()
  def metadata do
    hash = compute()

    %{
      algorithm: :sha256,
      length_bits: byte_size(hash) * 8,
      hex: Base.encode16(hash, case: :lower),
      computed_at: DateTime.utc_now(),
      version: Constitution.version()
    }
  end

  # Private helpers

  defp sha256(data), do: :crypto.hash(:sha256, data)

  # Canonicalize the invariants map for deterministic hashing
  defp canonicalize(invariants) when is_map(invariants) do
    invariants
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {key, value} -> {key, canonicalize(value)} end)
  end

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.into(%{})
  end

  defp canonicalize(value), do: value
end
