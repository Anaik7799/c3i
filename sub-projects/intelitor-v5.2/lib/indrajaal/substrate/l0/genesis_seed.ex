defmodule Indrajaal.Substrate.L0.GenesisSeed do
  @moduledoc """
  ## Design Intent
  L0 substrate genesis seed — pure functional module representing the founding
  identity and constitution of a holon. The genesis seed is the immutable DNA of
  the holon: it stores the founding parameters that were cryptographically committed
  at birth and can never be altered.

  A valid genesis seed contains:
    - `holon_id`           — unique UUID identifying this holon instance
    - `constitution_hash`  — SHA-256 hex digest of the L0 constitution document
    - `genesis_timestamp`  — UTC datetime of holon birth (ISO 8601)
    - `founder_pubkey`     — Base16 public key of the founding operator
    - `version`            — constitution version string (e.g. "21.3.1-SIL6")

  All functions are pure (no GenServer, no side effects). The module is intentionally
  minimal — it is the axiom from which all other substrate layers derive identity.

  Verification rules:
    1. `holon_id` must be a non-empty binary (ideally UUID format)
    2. `constitution_hash` must be a 64-character hex string (SHA-256)
    3. `genesis_timestamp` must be a parseable ISO 8601 UTC datetime
    4. `founder_pubkey` must be a non-empty binary
    5. `version` must be a non-empty binary

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L0 — ENFORCED
  - SC-SAFETY-009: Ψ₀ (Existence) validated for all operations — ENFORCED
  - SC-HASH-001: Deterministic hash computation — ENFORCED
  - SC-HASH-003: Canonical representation — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type holon_id :: String.t()
  @type constitution_hash :: String.t()
  @type genesis_timestamp :: String.t()
  @type founder_pubkey :: String.t()
  @type version :: String.t()

  @type t :: %__MODULE__{
          holon_id: holon_id(),
          constitution_hash: constitution_hash(),
          genesis_timestamp: genesis_timestamp(),
          founder_pubkey: founder_pubkey(),
          version: version()
        }

  defstruct [:holon_id, :constitution_hash, :genesis_timestamp, :founder_pubkey, :version]

  @version "21.3.1-SIL6"
  @sha256_hex_length 64

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new genesis seed struct.

  Required keys in `params`:
    - `:holon_id`          — unique binary identifier
    - `:constitution_hash` — 64-hex-character SHA-256 digest
    - `:genesis_timestamp` — ISO 8601 UTC string, e.g. "2026-03-28T00:00:00Z"
    - `:founder_pubkey`    — non-empty binary (hex-encoded Ed25519 pubkey)

  Optional:
    - `:version`           — defaults to #{@version}

  Returns `{:ok, t()}` on success, `{:error, reason}` on invalid params.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(params) when is_map(params) do
    seed = %__MODULE__{
      holon_id: Map.get(params, :holon_id, ""),
      constitution_hash: Map.get(params, :constitution_hash, ""),
      genesis_timestamp: Map.get(params, :genesis_timestamp, ""),
      founder_pubkey: Map.get(params, :founder_pubkey, ""),
      version: Map.get(params, :version, @version)
    }

    case verify(seed) do
      :ok -> {:ok, seed}
      {:error, _} = err -> err
    end
  end

  def new(_), do: {:error, "params must be a map"}

  @doc """
  Verify a genesis seed struct.

  Returns `:ok` if all fields are structurally valid, or `{:error, reason}`.

  Note: this performs structural validation only. Cryptographic signature
  verification of `founder_pubkey` against a signature is out of scope for
  this pure module.
  """
  @spec verify(t()) :: :ok | {:error, String.t()}
  def verify(%__MODULE__{} = seed) do
    with :ok <- validate_holon_id(seed.holon_id),
         :ok <- validate_constitution_hash(seed.constitution_hash),
         :ok <- validate_genesis_timestamp(seed.genesis_timestamp),
         :ok <- validate_founder_pubkey(seed.founder_pubkey),
         :ok <- validate_version(seed.version) do
      :ok
    end
  end

  def verify(_), do: {:error, "not a GenesisSeed struct"}

  @doc """
  Serialize a genesis seed to a plain map (e.g. for storage or JSON encoding).
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = seed) do
    %{
      holon_id: seed.holon_id,
      constitution_hash: seed.constitution_hash,
      genesis_timestamp: seed.genesis_timestamp,
      founder_pubkey: seed.founder_pubkey,
      version: seed.version
    }
  end

  @doc """
  Reconstruct a genesis seed from a plain map (reverse of `to_map/1`).
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    new(%{
      holon_id: Map.get(map, :holon_id, Map.get(map, "holon_id", "")),
      constitution_hash: Map.get(map, :constitution_hash, Map.get(map, "constitution_hash", "")),
      genesis_timestamp: Map.get(map, :genesis_timestamp, Map.get(map, "genesis_timestamp", "")),
      founder_pubkey: Map.get(map, :founder_pubkey, Map.get(map, "founder_pubkey", "")),
      version: Map.get(map, :version, Map.get(map, "version", @version))
    })
  end

  def from_map(_), do: {:error, "argument must be a map"}

  @doc """
  Compute a canonical fingerprint of this seed as a hex string.
  The fingerprint is deterministic: same inputs → same output (SC-HASH-001).
  """
  @spec fingerprint(t()) :: String.t()
  def fingerprint(%__MODULE__{} = seed) do
    canonical =
      "#{seed.holon_id}|#{seed.constitution_hash}|#{seed.genesis_timestamp}|#{seed.founder_pubkey}|#{seed.version}"

    :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
  end

  # ---------------------------------------------------------------------------
  # Private validators
  # ---------------------------------------------------------------------------

  @spec validate_holon_id(term()) :: :ok | {:error, String.t()}
  defp validate_holon_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp validate_holon_id(_), do: {:error, "holon_id must be a non-empty binary"}

  @spec validate_constitution_hash(term()) :: :ok | {:error, String.t()}
  defp validate_constitution_hash(h)
       when is_binary(h) and byte_size(h) == @sha256_hex_length do
    if String.match?(h, ~r/^[0-9a-fA-F]{64}$/) do
      :ok
    else
      {:error, "constitution_hash must be a 64-character hex string"}
    end
  end

  defp validate_constitution_hash(_),
    do: {:error, "constitution_hash must be a 64-character hex string"}

  @spec validate_genesis_timestamp(term()) :: :ok | {:error, String.t()}
  defp validate_genesis_timestamp(ts) when is_binary(ts) and byte_size(ts) > 0 do
    case DateTime.from_iso8601(ts) do
      {:ok, _, _} -> :ok
      _ -> {:error, "genesis_timestamp must be a valid ISO 8601 UTC datetime"}
    end
  end

  defp validate_genesis_timestamp(_),
    do: {:error, "genesis_timestamp must be a non-empty ISO 8601 string"}

  @spec validate_founder_pubkey(term()) :: :ok | {:error, String.t()}
  defp validate_founder_pubkey(k) when is_binary(k) and byte_size(k) > 0, do: :ok
  defp validate_founder_pubkey(_), do: {:error, "founder_pubkey must be a non-empty binary"}

  @spec validate_version(term()) :: :ok | {:error, String.t()}
  defp validate_version(v) when is_binary(v) and byte_size(v) > 0, do: :ok
  defp validate_version(_), do: {:error, "version must be a non-empty binary"}
end
