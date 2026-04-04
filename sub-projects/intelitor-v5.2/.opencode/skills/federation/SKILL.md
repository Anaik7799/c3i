---
name: federation
description: Federation monitoring — cross-holon communication, version negotiation, peer attestation via Zenoh
---
---

# Federation Monitoring (SC-FRAC-001 to SC-FRAC-006, SC-SIL6-011)

Cross-holon federation: peer discovery, protocol version negotiation, attestation, and distributed governance.

## Usage
```
/federation status      # Federation health and peer count
/federation peers       # List peer holons with version vectors
/federation attest      # Verify peer attestation (hourly)
/federation negotiate   # Protocol version negotiation status
/federation topology    # Federation graph topology
```

## Federation Architecture
```
     Holon A (L7)
    ╱    │    ╲
   ╱     │     ╲
Holon B  │  Holon D
   ╲     │     ╱
    ╲    │    ╱
     Holon C (L7)

All communication via Zenoh:
  indrajaal/federation/**
```

## Verification Steps
1. Check Sentinel health: `sentinel(action: "health")`
2. Query federation status: `zenoh_query(action: "get", key: "indrajaal/federation/status")`
3. Subscribe to peer events: `zenoh_sub(action: "subscribe", key: "indrajaal/federation/peers/**")`
4. Poll peer heartbeats: `zenoh_sub(action: "poll", id: "{id}", limit: 20)`
5. Verify attestation cycle (every 3600s per SC-REG-012)
6. Check protocol version compatibility across peers
7. Validate quorum: $Q(N) = \lfloor N/2 \rfloor + 1$
8. Publish federation health: `zenoh_pub(key: "indrajaal/federation/health", payload: "{json}")`

## Federation Topics (Zenoh Key Expressions)
| Topic | Direction | Purpose |
|-------|-----------|---------|
| `indrajaal/federation/peers/{id}` | Pub/Sub | Peer heartbeat |
| `indrajaal/federation/attest/{id}` | Publish | Attestation proof |
| `indrajaal/federation/negotiate` | Pub/Sub | Version negotiation |
| `indrajaal/federation/quorum` | Pub/Sub | Consensus voting |
| `indrajaal/federation/reconfig` | Publish | Reconfiguration events |

## Quorum & Consensus
| Mode | Formula | Use Case |
|------|---------|----------|
| Strict | $Q = N$ (unanimity) | Constitutional changes |
| Majority | $Q = \lfloor N/2 \rfloor + 1$ | Normal operations |
| 2oo3 | $Q = 2$ of $N=3$ | Safety-critical voting |
| Weighted | $Q = \sum w_i \geq W_{threshold}$ | Priority-weighted |

## Mathematical Foundation

**Quorum Formula** (SC-SIL6-011):

$$Q(N) = \lfloor N/2 \rfloor + 1$$

**Byzantine Fault Tolerance**:

$$N \geq 3f + 1 \text{ where } f = \text{max Byzantine faults}$$

For $f=1$ (single Byzantine): $N \geq 4$ peers minimum.

**Federation Attestation** (SC-REG-012):

$$\text{Attest}(h_a, h_b) = \text{Sign}_{h_a}(\text{H}_{chain}(h_b) \| t_{attestation})$$

Peer $h_a$ signs the hash chain root of peer $h_b$ every hour.

**Version Vector Ordering**:

$$V_a \leq V_b \iff \forall i : V_a[i] \leq V_b[i]$$

Partial order enables causal consistency without global clock.

**Protocol Negotiation** (SC-REG-010):

$$P_{compat} = \max\{v : v \in V_a \cap V_b\}$$

Negotiate highest mutually supported protocol version.

**Federation Availability**:

$$A_{fed} = 1 - \prod_{i=1}^{N} (1 - A_i) \quad \text{(parallel redundancy)}$$

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-FRAC-001 | Cluster-level AI quorum consensus |
| SC-FRAC-006 | Federation version negotiation |
| SC-SIL6-011 | Quorum = floor(N/2) + 1 |
| SC-REG-010 | Protocol version negotiation |
| SC-REG-012 | Federation attestation hourly |
| SC-SIL6-006 | 2oo3 voting MANDATORY |
