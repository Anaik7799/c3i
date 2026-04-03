# Holon Immutable Register: Self-Verifying Evolvable State

**Version**: 1.1.0 | **Date**: 2026-01-17 | **Status**: FOUNDATIONAL
**Purpose**: Define blockchain-type immutable register with self-checking, self-repairing, evolvable, and extensible capabilities for holon core state and code.
**Related**: [HOLON_DATABASE_NAMING_SYSTEM.md](./HOLON_DATABASE_NAMING_SYSTEM.md) (UHI naming conventions)

## 0. Design Philosophy

> "Trust emerges from verifiability. Immortality requires incorruptibility."

The holon's state must be:
- **Immutable**: Once written, never changed (append-only)
- **Self-Checking**: Cryptographically verifiable at any time
- **Self-Repairing**: Detects and recovers from corruption
- **Evolvable**: Protocol can upgrade without breaking history
- **Extensible**: New capabilities added without forking

Unlike traditional blockchains, we don't need consensus across untrusted parties. We need **self-sovereign verification**—a holon must be able to prove its own integrity to itself and others.

## 1. Core Data Structures

### 1.1 The Holon Register (Merkle DAG)

```
┌─────────────────────────────────────────────────────────────────┐
│                     HOLON IMMUTABLE REGISTER                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Genesis Block (B₀)                                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ hash: SHA3-256(content)                                  │   │
│  │ prev: NULL (primordial)                                  │   │
│  │ height: 0                                                │   │
│  │ timestamp: HLC                                           │   │
│  │ genome_hash: SHA3-256(initial_genome)                    │   │
│  │ content: { type: :genesis, holon_id, parent_id, ... }    │   │
│  │ signature: Ed25519(holon_private_key, hash)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  Block B₁                                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ hash: SHA3-256(content || prev_hash)                     │   │
│  │ prev: hash(B₀)                                           │   │
│  │ height: 1                                                │   │
│  │ timestamp: HLC                                           │   │
│  │ merkle_root: root of content tree                        │   │
│  │ content: { type: :state_change, delta, ... }             │   │
│  │ signature: Ed25519(holon_private_key, hash)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  Block Bₙ ...                                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Block Types

| Type | Purpose | Content |
|------|---------|---------|
| `:genesis` | Holon creation | Initial genome, identity, parent reference |
| `:state_change` | State mutation | Delta from previous state |
| `:genome_evolution` | Schema/capability change | New genome version, migration |
| `:checkpoint` | Periodic snapshot | Full state hash, Merkle proof |
| `:repair` | Corruption recovery | Recovered data, repair proof |
| `:extension` | New capability | Extension manifest, code hash |
| `:replication` | Cross-holon sync | Merge proof, version vector |

### 1.3 Cryptographic Primitives

```elixir
defmodule Indrajaal.Holon.Crypto do
  @moduledoc """
  Cryptographic primitives for holon immutable register.

  Design choices:
  - SHA3-256: Quantum-resistant, no length extension attacks
  - Ed25519: Fast, small signatures, deterministic
  - BLAKE3: Fast hashing for large data (Merkle trees)
  - Argon2id: Key derivation (if needed)
  """

  # Hash algorithms (versioned for future upgrades)
  @hash_v1 :sha3_256
  @hash_v2 :blake3  # Future: faster for large data

  # Signature algorithm
  @sig_v1 :ed25519
  @sig_v2 :ed448   # Future: larger security margin

  @spec hash(binary(), version :: pos_integer()) :: binary()
  def hash(data, version \\ 1)
  def hash(data, 1), do: :crypto.hash(:sha3_256, data)
  def hash(data, 2), do: Blake3.hash(data)

  @spec sign(binary(), private_key :: binary()) :: binary()
  def sign(data, private_key) do
    :crypto.sign(:eddsa, :sha512, data, [private_key, :ed25519])
  end

  @spec verify(binary(), signature :: binary(), public_key :: binary()) :: boolean()
  def verify(data, signature, public_key) do
    :crypto.verify(:eddsa, :sha512, data, signature, [public_key, :ed25519])
  end
end
```

## 2. Self-Checking Mechanisms

### 2.1 Multi-Layer Verification

```
┌─────────────────────────────────────────────────────────────────┐
│                    VERIFICATION LAYERS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 5: Federation Attestation                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Multiple holons attest to each other's integrity        │    │
│  │ Quorum: 2f+1 (Byzantine fault tolerant)                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                  │
│  Layer 4: Cross-Holon Proof                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Parent/child holons verify each other                   │    │
│  │ Merkle proofs of inclusion                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                  │
│  Layer 3: Block Chain Integrity                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Each block hash includes previous block hash            │    │
│  │ Tampering detected by chain break                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                  │
│  Layer 2: Block Signature                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Ed25519 signature on block hash                         │    │
│  │ Only holon's private key can sign                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                  │
│  Layer 1: Content Hash                                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ SHA3-256 hash of block content                          │    │
│  │ Any bit flip detected                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Verification Schedule

| Check | Frequency | Scope | Action on Failure |
|-------|-----------|-------|-------------------|
| Block hash | Every read | Single block | Trigger repair |
| Chain continuity | Every 100 blocks | Block range | Rollback to checkpoint |
| Signature | On demand | Single block | Mark untrusted |
| Merkle root | Every checkpoint | Full state | Full resync |
| Cross-holon | Every 1 hour | Federation | Alert + isolate |

### 2.3 Verification Protocol

```elixir
defmodule Indrajaal.Holon.Verification do
  @moduledoc """
  Self-checking verification protocol.

  STAMP Constraints:
  - SC-REG-001: Verify before trust
  - SC-REG-002: Hash chain unbroken
  - SC-REG-003: Signature valid
  """

  @spec verify_block(Block.t()) :: {:ok, :verified} | {:error, :corrupted, reason}
  def verify_block(block) do
    with :ok <- verify_hash(block),
         :ok <- verify_signature(block),
         :ok <- verify_chain_link(block) do
      {:ok, :verified}
    end
  end

  @spec verify_chain(height_start :: non_neg_integer(), height_end :: non_neg_integer())
        :: {:ok, :chain_valid} | {:error, :chain_break, height}
  def verify_chain(start, stop) do
    # Walk chain, verify each link
    Enum.reduce_while(start..stop, :ok, fn height, _acc ->
      case verify_block_at_height(height) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, :chain_break, height, reason}}
      end
    end)
  end

  @spec full_verification(holon_id :: String.t()) :: VerificationReport.t()
  def full_verification(holon_id) do
    %VerificationReport{
      holon_id: holon_id,
      timestamp: HLC.now(),
      chain_integrity: verify_full_chain(holon_id),
      merkle_root_valid: verify_merkle_root(holon_id),
      signatures_valid: verify_all_signatures(holon_id),
      cross_holon_attestations: get_attestations(holon_id)
    }
  end
end
```

## 3. Self-Repairing Mechanisms

### 3.1 Repair Strategies

```
┌─────────────────────────────────────────────────────────────────┐
│                    REPAIR STRATEGY HIERARCHY                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Strategy 1: Reed-Solomon Error Correction                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Each block stored with RS(255,223) parity               │    │
│  │ Can recover up to 16 byte errors per 255-byte block     │    │
│  │ Automatic, no external data needed                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                    (if RS fails)                                │
│                              ▼                                  │
│  Strategy 2: Local Replica Recovery                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Check local replicas (different storage media)          │    │
│  │ Uses UHI-based paths (see HOLON_DATABASE_NAMING_SYSTEM) │    │
│  │ data/holons/{runtime}/{layer}/{domain}/{instance}/      │    │
│  │   └── state.sqlite.replica1, state.sqlite.replica2      │    │
│  │ Example: data/holons/ex/l3/kms/main/state.sqlite.r1     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                    (if local fails)                             │
│                              ▼                                  │
│  Strategy 3: Peer Recovery                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Request block from peer holons (parent, siblings)       │    │
│  │ Verify recovered block matches expected hash            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                    (if peer fails)                              │
│                              ▼                                  │
│  Strategy 4: Checkpoint Rollback                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Rollback to last verified checkpoint                    │    │
│  │ Replay events from DuckDB history                       │    │
│  │ Reconstruct corrupted blocks                            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                    (if checkpoint fails)                        │
│                              ▼                                  │
│  Strategy 5: Genesis Regeneration                               │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Full regeneration from DuckDB event history             │    │
│  │ Reconstruct entire state from append-only log           │    │
│  │ Last resort, may lose uncommitted state                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Error Correction Encoding

```elixir
defmodule Indrajaal.Holon.ErrorCorrection do
  @moduledoc """
  Reed-Solomon error correction for holon blocks.

  Uses RS(255,223) - 32 bytes of parity per 223 bytes of data.
  Can correct up to 16 byte errors or detect up to 32 byte errors.
  """

  # RS parameters
  @data_bytes 223
  @parity_bytes 32
  @block_size @data_bytes + @parity_bytes  # 255

  @spec encode(binary()) :: binary()
  def encode(data) do
    data
    |> chunk_to_blocks(@data_bytes)
    |> Enum.map(&add_parity/1)
    |> IO.iodata_to_binary()
  end

  @spec decode(binary()) :: {:ok, binary()} | {:error, :uncorrectable}
  def decode(encoded) do
    encoded
    |> chunk_to_blocks(@block_size)
    |> Enum.map(&correct_errors/1)
    |> collect_results()
  end

  @spec verify_and_repair(binary()) :: {:ok, binary(), repairs :: non_neg_integer()}
                                      | {:error, :beyond_repair}
  def verify_and_repair(encoded) do
    case decode(encoded) do
      {:ok, data, 0} -> {:ok, data, 0}
      {:ok, data, n} ->
        Logger.warning("Repaired #{n} byte errors in holon block")
        {:ok, data, n}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### 3.3 Repair Event Recording

Every repair is recorded in the immutable register:

```elixir
%Block{
  type: :repair,
  content: %{
    corrupted_block_height: 1234,
    corruption_type: :bit_flip,
    bytes_affected: 3,
    repair_strategy: :reed_solomon,
    repair_proof: %{
      original_hash: "abc...",
      corrected_hash: "abc...",  # Should match original
      error_positions: [45, 78, 156],
      syndromes: [...]
    },
    timestamp: HLC.now()
  }
}
```

## 4. Evolution Mechanisms

### 4.1 Protocol Versioning

```elixir
defmodule Indrajaal.Holon.Protocol do
  @moduledoc """
  Evolvable protocol with version negotiation.

  Key principle: Old holons can read new formats (forward compatible)
                 New holons can read old formats (backward compatible)
  """

  @current_version %{
    major: 1,
    minor: 0,
    patch: 0,
    features: [:sha3_256, :ed25519, :reed_solomon, :merkle_dag]
  }

  @spec can_read?(version :: map()) :: boolean()
  def can_read?(version) do
    version.major <= @current_version.major
  end

  @spec can_write?(version :: map()) :: boolean()
  def can_write?(version) do
    version.major == @current_version.major and
    version.minor <= @current_version.minor
  end

  @spec negotiate(local :: map(), remote :: map()) :: {:ok, map()} | {:error, :incompatible}
  def negotiate(local, remote) do
    common_features = MapSet.intersection(
      MapSet.new(local.features),
      MapSet.new(remote.features)
    )

    if MapSet.size(common_features) >= minimum_features() do
      {:ok, %{features: MapSet.to_list(common_features)}}
    else
      {:error, :incompatible}
    end
  end
end
```

### 4.2 Genome Evolution

```
┌─────────────────────────────────────────────────────────────────┐
│                    GENOME EVOLUTION FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Proposal                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ New genome version proposed                             │    │
│  │ Includes: schema changes, new capabilities, migrations  │    │
│  │ Recorded as :genome_proposal block                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  2. Shadow Testing                                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Run new genome in shadow mode                           │    │
│  │ Compare outputs with current genome                     │    │
│  │ Measure: correctness, performance, resource usage       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  3. Guardian Validation                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Safety kernel validates:                                │    │
│  │ - No STAMP constraint violations                        │    │
│  │ - Backward compatibility preserved                      │    │
│  │ - Rollback path exists                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  4. Migration                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Execute migration in transaction                        │    │
│  │ Record :genome_evolution block with:                    │    │
│  │ - Old genome hash                                       │    │
│  │ - New genome hash                                       │    │
│  │ - Migration proof                                       │    │
│  │ - Rollback instructions                                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  5. Activation                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ New genome becomes active                               │    │
│  │ Old genome retained for rollback window                 │    │
│  │ Announce to federation                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Code Evolution (Self-Modifying)

```elixir
defmodule Indrajaal.Holon.CodeEvolution do
  @moduledoc """
  Self-modifying code with cryptographic verification.

  All code changes are:
  1. Recorded in immutable register
  2. Signed by authorized keys
  3. Verified before execution
  4. Rollback-capable
  """

  @spec propose_code_change(module :: atom(), new_code :: binary(), reason :: String.t())
        :: {:ok, proposal_id} | {:error, reason}
  def propose_code_change(module, new_code, reason) do
    proposal = %{
      type: :code_evolution,
      module: module,
      old_code_hash: hash_module(module),
      new_code_hash: Crypto.hash(new_code),
      new_code_encrypted: encrypt_code(new_code),  # Encrypted at rest
      reason: reason,
      proposed_at: HLC.now(),
      proposer: current_holon_id()
    }

    # Record proposal (not yet active)
    {:ok, _block} = Register.append(:code_proposal, proposal)
  end

  @spec activate_code_change(proposal_id :: String.t()) :: :ok | {:error, reason}
  def activate_code_change(proposal_id) do
    with {:ok, proposal} <- get_proposal(proposal_id),
         :ok <- Guardian.validate_code_change(proposal),
         :ok <- shadow_test_code(proposal),
         {:ok, _} <- hot_load_module(proposal) do

      # Record activation
      Register.append(:code_activation, %{
        proposal_id: proposal_id,
        activated_at: HLC.now(),
        rollback_until: HLC.add(HLC.now(), :hours, 24)
      })
    end
  end
end
```

## 5. Extension Mechanisms

### 5.1 Extension Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXTENSION ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Core Holon (Immutable Foundation)                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ - Register (append-only blocks)                         │    │
│  │ - Crypto (hashing, signing, verification)               │    │
│  │ - Lifecycle (spawn, heal, evolve, die)                  │    │
│  │ - Verification (self-checking)                          │    │
│  │ - Repair (self-healing)                                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                    Extension Points                             │
│                              │                                  │
│  ┌───────────┬───────────┬───────────┬───────────┐              │
│  ▼           ▼           ▼           ▼           ▼              │
│ ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐                 │
│ │Store│   │Comm │   │Intel│   │Sense│   │Act  │                 │
│ │Ext  │   │Ext  │   │Ext  │   │Ext  │   │Ext  │                 │
│ └─────┘   └─────┘   └─────┘   └─────┘   └─────┘                 │
│                                                                 │
│  Examples:                                                      │
│  - Store: Vector DB, Graph DB, Time Series                      │
│  - Comm: Zenoh, gRPC, MQTT, Quantum Entanglement                │
│  - Intel: LLM, Reasoning, Planning                              │
│  - Sense: Telemetry, Events, Environment                        │
│  - Act: API Calls, Hardware Control, Spawning                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Extension Manifest

```elixir
defmodule Indrajaal.Holon.Extension do
  @moduledoc """
  Extension system for adding capabilities to holons.

  Extensions are:
  1. Cryptographically signed
  2. Sandboxed (limited capabilities)
  3. Recorded in register
  4. Revocable
  """

  @type manifest :: %{
    id: String.t(),
    name: String.t(),
    version: Version.t(),
    author: String.t(),
    author_pubkey: binary(),
    signature: binary(),

    # Capability requirements
    required_capabilities: [atom()],
    provided_capabilities: [atom()],

    # Resource limits
    max_memory_mb: pos_integer(),
    max_cpu_percent: float(),
    max_storage_mb: pos_integer(),

    # Code
    code_hash: binary(),
    code_url: String.t() | nil,
    code_embedded: binary() | nil,

    # Lifecycle hooks
    on_install: mfa() | nil,
    on_uninstall: mfa() | nil,
    on_upgrade: mfa() | nil
  }

  @spec install(manifest()) :: {:ok, extension_id} | {:error, reason}
  def install(manifest) do
    with :ok <- verify_signature(manifest),
         :ok <- check_capabilities(manifest),
         :ok <- Guardian.validate_extension(manifest),
         {:ok, code} <- fetch_and_verify_code(manifest) do

      # Record installation
      Register.append(:extension_install, %{
        manifest: manifest,
        installed_at: HLC.now(),
        code_hash: Crypto.hash(code)
      })

      # Load extension
      load_extension(manifest, code)
    end
  end
end
```

### 5.3 Capability System

```elixir
defmodule Indrajaal.Holon.Capabilities do
  @moduledoc """
  Object-capability security model for extensions.

  Extensions can only access capabilities they've been granted.
  Capabilities are unforgeable references.
  """

  # Core capabilities (always available to core)
  @core_capabilities [
    :register_read,
    :register_append,
    :crypto_hash,
    :crypto_sign,
    :crypto_verify,
    :lifecycle_spawn,
    :lifecycle_heal
  ]

  # Grantable capabilities
  @grantable_capabilities [
    :network_outbound,
    :network_inbound,
    :storage_extended,
    :compute_extended,
    :spawn_children,
    :federation_join,
    :code_evolution
  ]

  @spec grant(holon_id :: String.t(), capability :: atom(), granter :: String.t())
        :: {:ok, capability_token} | {:error, :unauthorized}
  def grant(holon_id, capability, granter) do
    if authorized_to_grant?(granter, capability) do
      token = generate_capability_token(holon_id, capability)
      Register.append(:capability_grant, %{
        holon_id: holon_id,
        capability: capability,
        token_hash: Crypto.hash(token),
        granted_by: granter,
        granted_at: HLC.now()
      })
      {:ok, token}
    else
      {:error, :unauthorized}
    end
  end

  @spec revoke(token :: binary()) :: :ok
  def revoke(token) do
    Register.append(:capability_revoke, %{
      token_hash: Crypto.hash(token),
      revoked_at: HLC.now()
    })
  end
end
```

## 6. Storage Schema

### 6.1 SQLite Schema Extensions

```sql
-- Immutable register (append-only)
CREATE TABLE register_blocks (
    height INTEGER PRIMARY KEY,
    hash BLOB NOT NULL UNIQUE,
    prev_hash BLOB,  -- NULL for genesis
    block_type TEXT NOT NULL,
    content BLOB NOT NULL,  -- CBOR encoded
    content_hash BLOB NOT NULL,
    merkle_root BLOB,
    signature BLOB NOT NULL,
    hlc_physical INTEGER NOT NULL,
    hlc_logical INTEGER NOT NULL,

    -- Error correction
    parity_data BLOB,  -- Reed-Solomon parity

    -- Indexing
    created_at TEXT DEFAULT (datetime('now'))
);

-- Prevent modifications (trigger-based immutability)
CREATE TRIGGER prevent_block_update
BEFORE UPDATE ON register_blocks
BEGIN
    SELECT RAISE(ABORT, 'SC-REG-004: Register blocks are immutable');
END;

CREATE TRIGGER prevent_block_delete
BEFORE DELETE ON register_blocks
BEGIN
    SELECT RAISE(ABORT, 'SC-REG-005: Register blocks cannot be deleted');
END;

-- Verification cache (can be rebuilt)
CREATE TABLE verification_cache (
    height INTEGER PRIMARY KEY,
    verified_at TEXT,
    verification_hash BLOB,
    chain_valid BOOLEAN,
    signature_valid BOOLEAN
);

-- Extension registry
CREATE TABLE extensions (
    id TEXT PRIMARY KEY,
    manifest BLOB NOT NULL,  -- CBOR encoded
    code_hash BLOB NOT NULL,
    installed_at TEXT NOT NULL,
    status TEXT DEFAULT 'active',  -- active, suspended, uninstalled
    capabilities TEXT  -- JSON array
);

-- Capability grants
CREATE TABLE capability_grants (
    token_hash BLOB PRIMARY KEY,
    holon_id TEXT NOT NULL,
    capability TEXT NOT NULL,
    granted_by TEXT NOT NULL,
    granted_at TEXT NOT NULL,
    revoked_at TEXT,  -- NULL if active
    UNIQUE(holon_id, capability, granted_at)
);
```

### 6.2 DuckDB Analytics Extensions

```sql
-- Block analytics
CREATE TABLE register_analytics AS
SELECT
    height,
    block_type,
    hlc_physical,
    LENGTH(content) as content_size,
    CASE WHEN parity_data IS NOT NULL THEN LENGTH(parity_data) ELSE 0 END as parity_size
FROM read_parquet('register_blocks_*.parquet');

-- Repair history
CREATE TABLE repair_events (
    repair_id TEXT,
    block_height INTEGER,
    corruption_type TEXT,
    bytes_affected INTEGER,
    repair_strategy TEXT,
    repaired_at TIMESTAMP,
    success BOOLEAN
);

-- Evolution lineage
CREATE TABLE genome_evolution (
    version INTEGER,
    parent_version INTEGER,
    genome_hash BLOB,
    changes_summary TEXT,
    evolved_at TIMESTAMP,
    fitness_score DOUBLE,
    PRIMARY KEY (version)
);

-- Extension usage analytics
CREATE TABLE extension_metrics (
    extension_id TEXT,
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    invocation_count INTEGER,
    error_count INTEGER,
    avg_latency_ms DOUBLE,
    resource_usage_mb DOUBLE
);
```

## 7. Implementation Checklist

### 7.1 Phase 1: Core Register
- [ ] Block structure implementation
- [ ] SHA3-256 hashing
- [ ] Ed25519 signing
- [ ] Chain verification
- [ ] SQLite storage

### 7.2 Phase 2: Self-Checking
- [ ] Multi-layer verification
- [ ] Verification scheduler
- [ ] Integrity reports
- [ ] Alert on corruption

### 7.3 Phase 3: Self-Repairing
- [ ] Reed-Solomon encoding
- [ ] Local replica management
- [ ] Peer recovery protocol
- [ ] Checkpoint system

### 7.4 Phase 4: Evolution
- [ ] Protocol versioning
- [ ] Genome evolution
- [ ] Code hot-loading
- [ ] Migration framework

### 7.5 Phase 5: Extensions
- [ ] Extension manifest
- [ ] Capability system
- [ ] Sandboxing
- [ ] Extension marketplace

## 8. UHI Naming Integration

### 8.1 Universal Holon Identifier (UHI)

The Immutable Register uses the Universal Holon Identifier (UHI) naming system for all database paths. See [HOLON_DATABASE_NAMING_SYSTEM.md](./HOLON_DATABASE_NAMING_SYSTEM.md) for full specification.

**UHI Format**: `{runtime}:{layer}:{domain}:{type}:{instance}`

| Component | Values | Example |
|-----------|--------|---------|
| runtime | ex, fs, zig, rs | ex |
| layer | l0-l7 | l3 |
| domain | kms, prj, grd, snt, imm, fnd, etc. | kms |
| type | srv, agt, reg, str, brg, pub, sub, wrk | srv |
| instance | holon instance name | main |

**Example UHI**: `ex:l3:kms:srv:main` → Elixir L3 KMS Service (main instance)

### 8.2 Register Database Paths

```
data/holons/{runtime}/{layer}/{domain}/{instance}/
├── register.duckdb      # Immutable register (analytics/history)
├── state.sqlite         # Current state (WAL mode)
├── state.sqlite.r1      # Replica 1
├── state.sqlite.r2      # Replica 2
├── history.duckdb       # Evolution history
└── manifest.json        # Holon metadata
```

### 8.3 Path Resolution

```elixir
# Elixir
{:ok, path} = DatabasePath.resolve("ex:l3:kms:srv:main:register")
# => "data/holons/ex/l3/kms/main/register.duckdb"

# F#
let path = DatabasePath.resolve fqdn
// => "data/holons/ex/l3/kms/main/register.duckdb"
```

### 8.4 Cross-Holon Replication Paths

When holons replicate data across runtimes, they use Zenoh for cross-runtime access:

| Access Type | Method | Constraint |
|-------------|--------|------------|
| LOCAL (same runtime) | Direct SQLite/DuckDB | SC-DBLOCAL-001 |
| CROSS (different runtime) | Zenoh pub/sub | SC-DBCROSS-001 |

**Zenoh Topic Pattern**: `indrajaal/db/{runtime}/{layer}/{domain}/{instance}/{operation}`

## 9. STAMP Constraints Summary

| Code | Constraint |
|------|------------|
| SC-REG-001 | All state changes via immutable register |
| SC-REG-002 | Hash chain must be unbroken |
| SC-REG-003 | All blocks must be signed |
| SC-REG-004 | Blocks are immutable (no update) |
| SC-REG-005 | Blocks cannot be deleted |
| SC-REG-006 | Reed-Solomon parity required |
| SC-REG-007 | Verification before trust |
| SC-REG-008 | Repair events must be recorded |
| SC-REG-009 | Evolution requires Guardian approval |
| SC-REG-010 | Extensions must be signed |

## 10. AOR Rules Summary

| Code | Rule |
|------|------|
| AOR-REG-001 | Append-only register for all mutations |
| AOR-REG-002 | Verify chain on startup |
| AOR-REG-003 | Sign every block |
| AOR-REG-004 | Repair before use on corruption |
| AOR-REG-005 | Shadow test before evolution |
| AOR-REG-006 | Capability check before action |
| AOR-REG-007 | Record all extensions |
| AOR-REG-008 | Rollback path required |

---

*"Immutability is the foundation of trust. Self-repair is the essence of life. Evolution is the path to immortality."*
