# 5-Level Hybrid Grid Execution Plan

**Date**: 2026-01-01 14:00:00 CET
**Version**: 1.0.0
**Status**: ACTIVE

---

## L0-SPINE: Strategic Architecture

### Mission
Complete the 5-Layer Hybrid Grid Architecture implementation to achieve biomorphic survival capability.

### Layers Summary
| Layer | Name | Paradigm | Completion | Critical Path |
|-------|------|----------|------------|---------------|
| L0 | Constitutional | Power Grid | 95% | Constitution Verifier |
| L1 | Safety | Power Grid | 90% | Guardian, Sentinel |
| L2 | Mesh | Internet/SDN | 75% | TailscaleMesh, StateTeleporter |
| L3 | Trust | Financial | 60% | ImmutableRegister, FounderDirective, CapabilityTokens |
| L4 | Cognitive | Brain | 70% | FastOODA, TrainingGym |

### Success Criteria
- All 5 layers operational with cross-layer integration
- STAMP constraints SC-GRID-001 to SC-GRID-025 satisfied
- 286 formal verification tests passing
- Zero compile warnings, zero test failures

---

## L1-THORAX: Component Breakdown

### 1. Layer 3 Trust Components (Priority: P0)

#### 1.1 ImmutableRegister Enhancement
**Current State**: 40% complete
**Target State**: 100% complete

| Component | Status | STAMP |
|-----------|--------|-------|
| Ed25519 keypair generation | PARTIAL | SC-REG-003 |
| Real block signing | MISSING | SC-GRID-016 |
| Merkle root calculation | MISSING | SC-REG-011 |
| Cross-holon attestation | MISSING | SC-REG-013 |
| Self-repair logic | MISSING | SC-REG-004 |
| handle_call implementations | MISSING | - |

#### 1.2 FounderDirective Enhancement
**Current State**: 80% complete
**Target State**: 100% complete

| Component | Status | STAMP |
|-----------|--------|-------|
| evaluate_action/1 | BASIC | SC-FOUNDER-001 |
| Goal priority scoring | MISSING | SC-FOUNDER-002 |
| Resource benefit calculation | MISSING | SC-FOUNDER-008 |

#### 1.3 CapabilityToken Module
**Current State**: 0% complete
**Target State**: 100% complete

| Component | Status | STAMP |
|-----------|--------|-------|
| Token generation | MISSING | SC-REG-015 |
| Token verification | MISSING | SC-GRID-017 |
| Token revocation | MISSING | SC-GRID-018 |

### 2. Layer 4 Cognitive Components (Priority: P1)

#### 2.1 TrainingGym Learning Loop
**Current State**: 60% complete
**Target State**: 100% complete

| Component | Status | STAMP |
|-----------|--------|-------|
| Feedback recording | PARTIAL | AOR-CAE-003 |
| Model update loop | MISSING | SC-GDE-002 |
| Reinforcement signal | MISSING | SC-GRID-022 |

### 3. Layer 2 Mesh Components (Priority: P1)

#### 3.1 StateTeleporter File I/O
**Current State**: 50% complete
**Target State**: 100% complete

| Component | Status | STAMP |
|-----------|--------|-------|
| serialize/1 | PARTIAL | SC-HOLON-009 |
| deserialize/1 | PARTIAL | SC-HOLON-009 |
| File write with checksum | MISSING | SC-HOLON-017 |
| File read with verification | MISSING | SC-HOLON-014 |

---

## L2-SEGMENT: Function-Level Specifications

### 2.1 ImmutableRegister Functions

```elixir
# Required Ed25519 functions
@spec generate_ed25519_keypair() :: {public_key :: binary(), secret_key :: binary()}
@spec sign_block(block_hash :: String.t(), keypair :: tuple()) :: binary()
@spec verify_signature(block :: block(), public_key :: binary()) :: boolean()

# Required Merkle functions
@spec calculate_merkle_root(chain :: list(block())) :: String.t()
@spec get_merkle_proof(chain :: list(block()), index :: non_neg_integer()) :: {:ok, list()} | {:error, :not_found}

# Required GenServer handlers
handle_call(:public_key, _from, state)
handle_call({:attest, holon_id, their_hash, their_pubkey}, _from, state)
handle_call({:merkle_proof, block_index}, _from, state)
handle_call(:repair, _from, state)
```

### 2.2 FounderDirective Functions

```elixir
# Enhanced evaluate_action
@spec evaluate_action_with_scoring(action :: map(), state :: map()) ::
  {:approved, score :: float()} | {:rejected, reason :: String.t(), score :: float()}

# Goal priority evaluation
@spec calculate_goal_alignment(action :: map()) :: {goal :: 1..3, score :: float()}
```

### 2.3 CapabilityToken Functions

```elixir
@spec generate_token(holon_id :: String.t(), capabilities :: list(atom()), ttl :: pos_integer()) ::
  {:ok, token :: String.t()} | {:error, term()}

@spec verify_token(token :: String.t(), required_capability :: atom()) ::
  :valid | {:invalid, reason :: atom()}

@spec revoke_token(token :: String.t()) :: :ok | {:error, :not_found}
```

---

## L3-FIBER: Implementation Details

### 3.1 Ed25519 Implementation

```elixir
# Generate Ed25519 keypair using Erlang crypto
defp generate_ed25519_keypair do
  # :crypto.generate_key(:eddsa, :ed25519) returns {public, secret}
  {public_key, secret_key} = :crypto.generate_key(:eddsa, :ed25519)
  {public_key, secret_key}
end

# Sign a block hash with Ed25519
defp sign_block(hash, {_public_key, secret_key}) do
  # Convert hex hash to binary for signing
  hash_binary = Base.decode16!(hash, case: :lower)
  :crypto.sign(:eddsa, :sha256, hash_binary, [secret_key, :ed25519])
end

# Verify signature
defp verify_signature(%{hash: hash, signature: signature}, public_key) do
  hash_binary = Base.decode16!(hash, case: :lower)
  :crypto.verify(:eddsa, :sha256, hash_binary, signature, [public_key, :ed25519])
end
```

### 3.2 Merkle Root Implementation

```elixir
# Calculate Merkle root from chain
defp calculate_merkle_root([]), do: hash_leaf("genesis")
defp calculate_merkle_root(chain) do
  leaves = Enum.map(chain, fn block -> hash_leaf(block.hash) end)
  build_merkle_tree(leaves)
end

defp hash_leaf(data) do
  :crypto.hash(:sha3_256, data) |> Base.encode16(case: :lower)
end

defp build_merkle_tree([single]), do: single
defp build_merkle_tree(leaves) do
  # Pad to even length
  padded = if rem(length(leaves), 2) == 1, do: leaves ++ [List.last(leaves)], else: leaves

  # Combine pairs
  pairs = Enum.chunk_every(padded, 2)
  next_level = Enum.map(pairs, fn [left, right] ->
    :crypto.hash(:sha3_256, left <> right) |> Base.encode16(case: :lower)
  end)

  build_merkle_tree(next_level)
end
```

### 3.3 Cross-Holon Attestation

```elixir
# Create attestation for another holon
def handle_call({:attest, holon_id, their_head_hash, their_public_key}, _from, state) do
  attestation = %{
    attester_id: state.name,
    attested_holon: holon_id,
    attested_hash: their_head_hash,
    attested_pubkey: their_public_key,
    timestamp: DateTime.utc_now(),
    our_head_hash: state.head_hash,
    signature: sign_attestation(state.keypair, holon_id, their_head_hash)
  }

  new_attestations = Map.put(state.attestations, holon_id, attestation)
  new_state = %{state | attestations: new_attestations}

  Logger.info("[ImmutableRegister] Attested holon #{holon_id} - SC-REG-013")

  {:reply, {:ok, attestation}, new_state}
end

defp sign_attestation({_pub, secret}, holon_id, their_hash) do
  payload = "#{holon_id}|#{their_hash}"
  :crypto.sign(:eddsa, :sha256, payload, [secret, :ed25519])
end
```

### 3.4 Self-Repair Logic

```elixir
def handle_call(:repair, _from, state) do
  case find_corruption(state.chain) do
    {:ok, :no_corruption} ->
      {:reply, {:ok, 0}, state}

    {:error, {:corrupted_at, index}} ->
      # Truncate chain to last valid block
      {valid_chain, _corrupted} = Enum.split(state.chain, index)

      repair_event = %{
        timestamp: DateTime.utc_now(),
        corrupted_index: index,
        blocks_removed: length(state.chain) - index
      }

      new_state = %{
        state
        | chain: valid_chain,
          block_count: length(valid_chain),
          head_hash: if(valid_chain == [], do: "genesis", else: hd(valid_chain).hash),
          repair_log: [repair_event | state.repair_log]
      }

      Logger.warning("[ImmutableRegister] Repaired chain - removed #{repair_event.blocks_removed} blocks")

      {:reply, {:ok, repair_event.blocks_removed}, new_state}
  end
end

defp find_corruption(chain) do
  case verify_chain_with_signatures(chain) do
    :ok -> {:ok, :no_corruption}
    {:error, {:broken_chain, index}} -> {:error, {:corrupted_at, index}}
    {:error, {:invalid_signature, index}} -> {:error, {:corrupted_at, index}}
  end
end
```

---

## L4-GOSSAMER: Micro-Details & Edge Cases

### 4.1 Ed25519 Edge Cases

| Case | Handling |
|------|----------|
| Empty keypair | Generate fresh on init |
| Invalid signature format | Return {:error, :invalid_signature} |
| Key size != 32 bytes | Reject with {:error, :invalid_key_size} |
| Signature verification timeout | Log warning, return false |

### 4.2 Merkle Tree Edge Cases

| Case | Handling |
|------|----------|
| Empty chain | Return hash of "genesis" |
| Single block | Return block hash directly |
| Odd number of blocks | Duplicate last block for padding |
| Very long chain (>10k) | Use incremental merkle updates |

### 4.3 Attestation Edge Cases

| Case | Handling |
|------|----------|
| Attesting unknown holon | Log warning, proceed |
| Attestation to self | Reject with {:error, :self_attestation} |
| Expired attestation (>24h) | Mark as stale, request refresh |
| Conflicting attestation | Log conflict, keep both |

### 4.4 Repair Edge Cases

| Case | Handling |
|------|----------|
| Genesis block corrupted | Full reset to fresh state |
| All blocks corrupted | Return {:error, :unrecoverable} |
| Partial signature damage | Remove damaged blocks only |
| Repair during append | Queue append, complete repair first |

---

## Execution Order

1. **Phase 1**: Complete ImmutableRegister (L3-FIBER tasks)
2. **Phase 2**: Enhance FounderDirective (L3-FIBER tasks)
3. **Phase 3**: Create CapabilityToken module (L2-SEGMENT)
4. **Phase 4**: TrainingGym integration (L1-THORAX)
5. **Phase 5**: StateTeleporter I/O (L1-THORAX)
6. **Phase 6**: Integration test suite (L0-SPINE)

---

## STAMP Constraint Verification

| Constraint | Component | Verification Method |
|------------|-----------|---------------------|
| SC-REG-003 | Ed25519 signing | Unit test key generation |
| SC-REG-011 | Merkle root | Property test tree construction |
| SC-REG-013 | Attestation | Integration test cross-holon |
| SC-REG-004 | Self-repair | Fault injection test |
| SC-GRID-016 | Block signing | All blocks have valid Ed25519 signature |
| SC-FOUNDER-001 | Action eval | All actions scored against goals |

---

## Document Control

| Field | Value |
|-------|-------|
| Created | 2026-01-01 |
| Author | Claude Opus 4.5 |
| Classification | Technical Plan |
| Review Required | Yes |
