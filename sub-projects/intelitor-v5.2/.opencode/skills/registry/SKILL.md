---
name: registry
description: Immutable Register description: allowed-tools: mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__checkpoint_op, mcp__sentinel-zenoh__zenoh_query, Read, Grep, Glob Unified Checkpoint Registry — append-only blocks, hash chains, Merkle proofs
---
---

# Immutable Register & UCR (SC-REG-001 to SC-REG-012, SC-UCR-001 to SC-UCR-015)

Cryptographically-signed append-only state mutation log with self-verifying hash chains and error correction.

## Usage
```
/registry verify        # Verify hash chain integrity
/registry chain         # Display recent block chain
/registry merkle        # Generate Merkle proof for state
/registry integrity     # Full integrity check (SHA3 + RS)
/registry export        # Export register for backup
```

## Register Architecture (Ω₈)
Every state mutation flows through the Immutable Register:
1. Content arrives → Ed25519 signature (SC-REG-003)
2. Hash chain: `SHA3(content | prev_hash)` (Ω₈)
3. Reed-Solomon RS(255,223) encoding (SC-REG-009)
4. Append to chain (never modify/delete)
5. Publish event to Zenoh `indrajaal/register/events`

## Verification Steps
1. Check Sentinel health: `sentinel(action: "health")`
2. Verify chain integrity: `zenoh_query(action: "get", key: "indrajaal/register/integrity")`
3. Check checkpoint state: `checkpoint_op(action: "verify")`
4. Grep for chain verification on startup (SC-REG-002)
5. Validate Ed25519 signatures on blocks
6. Check Reed-Solomon parity (16 symbol correction)
7. Generate Merkle proofs on demand (SC-REG-011)

## Block Structure
```
┌──────────────────────────────────────────┐
│ Block N                                   │
├──────────────────────────────────────────┤
│ prev_hash: SHA3-256(Block N-1)           │
│ content:   {mutation data}                │
│ timestamp: ISO 8601 UTC                   │
│ signature: Ed25519(content | prev_hash)   │
│ parity:    RS(255,223) error correction   │
│ hash:      SHA3-256(all above)            │
└──────────────────────────────────────────┘
```

## UCR 4-Phase Architecture
| Phase | Scope | Time | STAMP |
|-------|-------|------|-------|
| 1 | FileSystem + KMS + Git | <10s | SC-UCR-001 |
| 2 | Container state (CRIU) | <30s | SC-UCR-002 |
| 3 | Zenoh mesh (Chandy-Lamport) | <30s | SC-UCR-003 |
| 4 | Multiverse verification (46 tests) | <60s | SC-UCR-004 |

## Mathematical Foundation

**Hash Chain Integrity**:

$$\forall b_i : H(b_i) = \text{SHA3}(content_i \| H(b_{i-1})) \implies \text{chain\_valid}$$

**Reed-Solomon Error Correction** RS(255,223):

$$d_{min} = n - k + 1 = 33, \quad t = \lfloor d_{min}/2 \rfloor = 16 \text{ symbols}$$

Corrects up to 16 symbol errors per block. Forney algorithm for error location + magnitude.

**Merkle Proof Verification**:

$$\text{Verify}(leaf, proof, root) : H(H(\ldots H(leaf \| sibling_1) \ldots) \| sibling_k) = root$$

Proof size: $O(\log_2 N)$ for $N$ blocks.

**Append-Only Entropy**:

$$H_{register} = -\sum_{i=1}^{N} p(b_i) \log_2 p(b_i) \geq H_{register-1}$$

Register entropy is monotonically non-decreasing (information is never destroyed).

**Federation Attestation** (SC-REG-012):

$$\text{Attest}(h_a, h_b) = \text{Sign}_{h_a}(H_{chain}(h_b) \| t) \quad \forall t \mod 3600 = 0$$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-REG-001 | All mutations via append-only register |
| SC-REG-003 | Ed25519 signed blocks |
| SC-REG-009 | Reed-Solomon RS(255,223) encoding |
| SC-REG-011 | Merkle proofs on demand |
| SC-REG-012 | Federation attestation hourly |
| SC-UCR-001 | 4-phase checkpoint architecture |
| SC-UCR-012 | All 7 state locations captured |
| SC-UCR-015 | Rollback path MUST exist |
