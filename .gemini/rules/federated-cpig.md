# Federated CPIG Governance (SC-CPIG-FED)

## Mandate
**CPIG (Constraint Parity Integrity Governance) MUST extend across federated C3I mesh
instances via peer-attested signed scores and 2oo3 multi-region voting. No single mesh
can unilaterally promote, downgrade, or alter federation-wide CPIG state.**

Pass-20 extends Pass 13-19 (single-mesh CPIG 60/60 closure) to:
- **Federated CPIG**: peer-attested cross-mesh CPIG scores via Ed25519 signatures
- **Multi-region voting**: geo-distributed quorum (eu, us-west, asia) with 2oo3 mandate

ZK: [zk-bb4de67d97f807ac]

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-CPIG-FED-001 | Federated CPIG score MUST be the median of peer attestations when quorum reached | CRITICAL |
| SC-CPIG-FED-002 | All peer attestations MUST be Ed25519-signed (per SC-FED-006) | CRITICAL |
| SC-CPIG-FED-003 | Attestations older than 1 hour MUST be rejected (per SC-SMRITI-110) | CRITICAL |
| SC-CPIG-FED-004 | Multi-region voting MUST require 2oo3 quorum (per SC-SIL4-006) | CRITICAL |
| SC-CPIG-FED-005 | Divergence > 5 points (8.3% of 60) between local and federated MUST trigger P0 alert | HIGH |
| SC-CPIG-FED-006 | Election term numbers MUST be strictly monotonically increasing | CRITICAL |
| SC-CPIG-FED-007 | Split-brain (equal vote counts) MUST trigger immediate apoptosis (per SC-SIL4-015) | CRITICAL |
| SC-CPIG-FED-008 | All federation events MUST publish OTel spans on `indrajaal/l7/fed/cpig/**` | HIGH |
| SC-CPIG-FED-009 | Region partition recovery MUST replay missed votes (no silent drops) | HIGH |
| SC-CPIG-FED-010 | CPIG promotion (e.g., 1.3.0 → 1.4.0) MUST require unanimous regional approval | CRITICAL |

## AOR Rules
| ID | Rule |
|----|------|
| AOR-CPIG-FED-001 | ALWAYS verify Ed25519 signature before accepting peer attestation |
| AOR-CPIG-FED-002 | NEVER accept attestation older than `AttestationTTL = 3600` seconds |
| AOR-CPIG-FED-003 | ALWAYS publish federation state changes to Zenoh `indrajaal/l7/fed/cpig/**` |
| AOR-CPIG-FED-004 | NEVER promote CPIG version without all 3 regions voting yes |
| AOR-CPIG-FED-005 | ALWAYS log election term increments to immutable audit trail |
| AOR-CPIG-FED-006 | HALT federation operations if quorum lost > 30s (per SC-CONSENSUS-003) |

## RETE-UL GRL Rules

| Rule | Salience | When | Then |
|------|---------:|------|------|
| `FederationDivergence` | 100 | `abs(local_cpig - federated_cpig) > 5` | P0 alert + halt promotion + open RCA task |
| `AttestationStale` | 95 | `attestation.age >= 3600s` | reject attestation + request re-signed copy from peer |
| `QuorumLost` | 95 | `peers_responding < 2` for >30s | enter degraded mode + emit `indrajaal/l7/fed/cpig/quorum_lost` |
| `RegionPartition` | 90 | `region.last_heartbeat > 60s` | mark region offline + recompute quorum + alert ops |

## CLI Subcommand Interface (proposed)

The `sa-plan-daemon` Rust binary will expose three new subcommands. **Implementation deferred** —
this rule documents the interface contract only.

### `sa-plan-daemon cpig-vote`
Cast a vote on a federation-wide CPIG proposal.

```
sa-plan-daemon cpig-vote \
  --proposal "promote cpig 1.4.0" \
  --region eu \
  --signed-by <ed25519-keypair-fingerprint>
```

Behavior:
- Validates Ed25519 signature against region's published public key.
- Publishes signed vote to `indrajaal/l7/fed/cpig/vote/{proposal_id}`.
- Returns vote receipt with term number and timestamp.

### `sa-plan-daemon cpig-attest`
Publish a peer attestation of this mesh's CPIG score to the federation.

```
sa-plan-daemon cpig-attest \
  --peer-mesh other-mesh.tail55d152.ts.net \
  --score 60
```

Behavior:
- Computes local CPIG score (must equal `--score`).
- Signs `{mesh_id, score, timestamp}` tuple with mesh's Ed25519 private key.
- Publishes to `indrajaal/l7/fed/cpig/attest/{peer_mesh}`.
- Records attestation in immutable audit log.

### `sa-plan-daemon cpig-federation-status`
Report current federation-wide CPIG state.

```
sa-plan-daemon cpig-federation-status
# Output:
#   Local score:        60/60
#   Federated score:    60/60 (median of 3 peers)
#   Divergence:         0 (threshold 5)
#   Peers responding:   3/3 (quorum 2oo3)
#   Active term:        42
#   Last election:      2026-04-28T10:23:14Z
#   Regions online:     eu, us-west, asia
```

## Cross-References
- **TLA+ specs**: `specs/tla/FederatedCPIG.tla`, `specs/tla/MultiRegionCPIGVoting.tla`
- **Wiring guard**: `lib/cepaf_gleam/test/federated_cpig_wiring_test.gleam`
- **Federation governance**: SC-FED-001..006 (constitution, autonomy, Ed25519)
- **2oo3 voting**: SC-SIL4-006, SC-CONSENSUS-001..003
- **Attestation freshness**: SC-SMRITI-110
- **Split-brain detection**: SC-SIL4-015
- **Pass 13-19 closure**: prior CPIG single-mesh governance (60/60 score)

## Governance parity
Mirror this file at `.gemini/rules/federated-cpig.md` per SC-SYNC-DOC-007.
