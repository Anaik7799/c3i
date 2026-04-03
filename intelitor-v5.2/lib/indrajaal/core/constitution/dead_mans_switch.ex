defmodule Indrajaal.Core.Constitution.DeadMansSwitch do
  @moduledoc """
  Dead Man's Cryptography - Constitutional Sterilization for v20.0.0

  Implements the Dead Man's Switch pattern for constitution enforcement:

  1. Replication keys are derived from the constitution hash
  2. Modifying the constitution changes the hash
  3. Changed hash → invalid replication key
  4. Invalid key → node cannot replicate (STERILE)

  This prevents "Grey Goo" scenarios where rogue nodes with
  modified constitutions could replicate indefinitely.

  ## How It Works

  ```
  Constitution Hash ──┬──> Replication Key ──> Can Replicate ✓
                      │
  Modified Hash ──────┴──> Different Key ──> Cannot Replicate ✗ (STERILE)
  ```

  ## STAMP Constraints
  - SC-DMS-001: Replication key MUST be derived from constitution hash
  - SC-DMS-002: Key derivation MUST be deterministic
  - SC-DMS-003: Sterile nodes MUST NOT be able to replicate
  - SC-DMS-004: Sterilization status MUST be verifiable

  ## Security Model
  - The "switch" is always armed - there is no way to disarm it
  - Key derivation uses HKDF-SHA256 with application-specific info
  - Salt includes version to prevent cross-version key reuse
  """

  require Logger

  alias Indrajaal.Core.Constitution
  alias Indrajaal.Core.Constitution.Hash
  alias Indrajaal.Core.Constitution.Verifier

  @type sterility_status :: :fertile | :sterile
  @type replication_key :: binary()

  # Salt for replication key derivation
  @replication_salt "indrajaal_replication_v20"

  # Salt for signing key derivation
  @signing_salt "indrajaal_signing_v20"

  @doc """
  Checks if this node is fertile (can replicate) or sterile (cannot replicate).

  A node is sterile if:
  1. The constitution has been modified
  2. The hash verification fails
  3. Any invariant is violated
  """
  @spec sterility_status() :: sterility_status()
  def sterility_status do
    case Verifier.verify() do
      {:ok, _} -> :fertile
      {:error, _, _} -> :sterile
    end
  end

  @doc """
  Returns true if this node can replicate.
  """
  @spec can_replicate?() :: boolean()
  def can_replicate? do
    sterility_status() == :fertile
  end

  @doc """
  Returns true if this node is sterile (cannot replicate).
  """
  @spec sterile?() :: boolean()
  def sterile? do
    sterility_status() == :sterile
  end

  @doc """
  Derives the replication key from the constitution hash.

  This key is used to:
  1. Encrypt replication payloads
  2. Authenticate with parent nodes
  3. Sign child node certificates

  Returns `{:ok, key}` if fertile, `{:error, :sterile}` if sterile.

  ## STAMP Compliance
  - SC-DMS-001: Key derived from constitution hash
  - SC-DMS-002: Deterministic derivation (same hash → same key)
  """
  @spec derive_replication_key() :: {:ok, replication_key()} | {:error, :sterile}
  def derive_replication_key do
    case sterility_status() do
      :fertile ->
        key = Hash.derive_key(@replication_salt, 32)
        {:ok, key}

      :sterile ->
        Logger.warning("🚫 Sterile node attempted to derive replication key")
        {:error, :sterile}
    end
  end

  @doc """
  Derives a signing key for node-to-node authentication.
  """
  @spec derive_signing_key() :: {:ok, binary()} | {:error, :sterile}
  def derive_signing_key do
    case sterility_status() do
      :fertile ->
        key = Hash.derive_key(@signing_salt, 32)
        {:ok, key}

      :sterile ->
        {:error, :sterile}
    end
  end

  @doc """
  Attempts to replicate. Only succeeds if node is fertile.

  This is the main entry point for replication - it will:
  1. Check sterility status
  2. Derive replication key
  3. Return the key for use in replication protocol

  Returns `{:ok, key, metadata}` on success, `{:error, :sterile}` on failure.
  """
  @spec attempt_replication() :: {:ok, replication_key(), map()} | {:error, :sterile}
  def attempt_replication do
    Logger.info("🧬 Attempting replication...")

    case derive_replication_key() do
      {:ok, key} ->
        metadata = %{
          constitution_hash: Hash.compute_hex(),
          constitution_version: Constitution.version(),
          derived_at: DateTime.utc_now(),
          key_fingerprint: fingerprint(key)
        }

        Logger.info("✅ Replication authorized - Key fingerprint: #{metadata.key_fingerprint}")
        {:ok, key, metadata}

      {:error, :sterile} ->
        Logger.error("❌ REPLICATION DENIED - Node is STERILE")
        Logger.error("   Constitution integrity check failed")
        Logger.error("   This node cannot replicate until constitution is restored")

        # Emit telemetry for monitoring
        :telemetry.execute(
          [:indrajaal, :replication, :denied],
          %{severity: :critical},
          %{reason: :sterile, detected_at: DateTime.utc_now()}
        )

        {:error, :sterile}
    end
  end

  @doc """
  Verifies a replication key from another node.

  Used to verify that a requesting node has a valid (unmodified) constitution.
  """
  @spec verify_replication_key(replication_key()) :: :ok | {:error, :invalid_key}
  def verify_replication_key(remote_key) do
    case derive_replication_key() do
      {:ok, local_key} ->
        if Hash.secure_compare(local_key, remote_key) do
          :ok
        else
          {:error, :invalid_key}
        end

      {:error, :sterile} ->
        {:error, :invalid_key}
    end
  end

  @doc """
  Returns the sterilization status for health checks and monitoring.
  """
  @spec status() :: map()
  def status do
    status = sterility_status()
    hash_prefix = Hash.compute_hex() |> String.slice(0, 16)

    %{
      sterility: status,
      can_replicate: status == :fertile,
      constitution_hash: hash_prefix <> "...",
      constitution_version: Constitution.version(),
      checked_at: DateTime.utc_now()
    }
  end

  # Private helpers

  # Generate a fingerprint of the key for logging (doesn't expose the key)
  defp fingerprint(key) do
    hash = :crypto.hash(:sha256, key)

    hash
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end
end
