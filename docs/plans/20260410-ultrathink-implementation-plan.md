# Ultrathink Implementation Plan — SC-ULTRA-001

**Date**: 2026-04-10
**Version**: v22.5.0-CORTEX
**STAMP**: SC-ULTRA-001, SC-ZMOF-001, SC-HA-001, SC-SIL4-001
**Mandate**: RIGID, IMMUTABLE GOALS — no deviation permitted
**Status**: 33% implemented (2/10 features ≥80%, 3/10 at <10%)

---

## 1. Current State Assessment

| # | Feature | Implemented | LOC | Gap |
|---|---------|------------|-----|-----|
| 1 | Decentralized Emergent Ignition | **5%** | 140 | No peer gossip protocol |
| 2 | Zenoh-Native CRDT State | **0%** | 0 | Core abstraction absent |
| 3 | Zero-IP Identity Routing | **2%** | 100 | No routing table |
| 4 | Homomorphic Tripartite UI | **85%** | 3,200 | Isomorphic proof + lustre_renderer 9/233 |
| 5 | Continuous Formal Verification | **5%** | 200 | No Apalache CI integration |
| 6 | Embedded SLM Kernels (WASM) | **0%** | 0 | No WASM compilation |
| 7 | Crypto Verifiable Event Log | **10%** | 100 | No hash chain |
| 8 | Stochastic Apoptosis | **40%** | 500 | Deterministic only |
| 9 | OpenClaw Ecosystem | **90%** | 2,000 | UI controls needed |
| 10 | HA Seamless Upgrades | **50%** | 138 | Rolling upgrade missing |

**Weighted completion**: 33% → Target: 100%

---

## 2. Mathematical Framework

### 2.1 Priority Score

```
CPS(f) = 0.30 × Dependency_norm + 0.30 × Risk_norm + 0.20 × Effort_inv + 0.20 × Value_norm

Dependency_norm = 1.0 if no blockers, 0.0 if blocked by all others
Risk_norm = RPN / RPN_max (failure risk of NOT implementing)
Effort_inv = 1.0 - (estimated_days / max_days) (prefer lower effort)
Value_norm = architectural_value / 10 (how much it enables other features)
```

### 2.2 Dependency Graph

```
                    ┌── [2] CRDT State ──────────────────────┐
                    │         ↑                              │
[1] Gossip Boot ────┤    (requires)                          ↓
         ↑          │                               [7] Event Sourcing
    (requires)      └── [3] Zero-IP Identity                 ↑
         │                    ↑                         (requires)
[10] HA Upgrades ─────── (requires)                          │
         ↑                                           [5] Formal Verify
    (enhances)                                               ↑
         │                                              (validates)
[8] Stoch. Apoptosis                                         │
                                                    [6] SLM WASM Kernels

[4] Tripartite UI ─── independent ─── [9] OpenClaw ─── independent
```

### 2.3 Implementation Phases

```
Phase 0 (NOW):     [4] Tripartite UI + [9] OpenClaw     (near-complete, quick wins)
Phase 1 (CORE):    [2] CRDT + [7] Event Sourcing        (foundational data layer)
Phase 2 (NETWORK): [3] Zero-IP + [10] HA Upgrades       (transport layer)
Phase 3 (BOOT):    [1] Gossip Boot + [8] Apoptosis      (autonomous lifecycle)
Phase 4 (VERIFY):  [5] Formal Verify + [6] SLM WASM     (cognitive + proof)
```

---

## 3. Feature Specifications

### Phase 0: Quick Wins (Sprint 1-2)

---

### F4: Homomorphic Tripartite UI — 85% → 100%

**RPN**: S(4)×O(6)×D(3) = 72 | **CPS**: 0.78 | **Effort**: 15 days

**What exists**: A2UI catalog (233 types), renderer.gleam (tripartite HTML/JSON/ANSI), 38 Lustre pages, 18 Wisp endpoints, 32 TUI views.

**What's missing**:
1. lustre_renderer.gleam: 9/233 → 233/233 component types
2. Mathematical functor proof: F: SwarmState → UIRepresentation is a homomorphism
3. Automated equivalence checker: verify HTML(s) ≅ JSON(s) ≅ ANSI(s) for any state s

**Implementation**:

```
Phase 0a (10 days): A2UI Lustre Renderer Completion
  Wave A: 50 form components (input, select, slider, checkbox, etc.)
  Wave B: 60 data viz (chart, sparkline, gauge, heatmap, etc.)
  Wave C: 60 layout (tabs, accordion, sidebar, toolbar, etc.)
  Wave D: 63 specialized (ooda_ring, pipeline_waterfall, etc.)

Phase 0b (5 days): Isomorphic Functor Proof
  - Define category C_state (objects=SwarmState, morphisms=state transitions)
  - Define category C_html, C_json, C_ansi (objects=rendered output)
  - Prove: render_html ∘ update = update_dom ∘ render_html (commutative)
  - Implement: render_tripartite_test(state) → assert(html ≅ json ≅ ansi)
  - File: testing/isomorphic_proof.gleam
```

**Mathematical structure**:
```
Functor F: C_state → C_ui where
  F(s) = (render_html(s), render_json(s), render_ansi(s))
  F(f: s₁ → s₂) = (patch_html(f), patch_json(f), patch_ansi(f))

Homomorphism condition:
  F(f ∘ g) = F(f) ∘ F(g)  ∀ state transitions f, g

Equivalence relation:
  html(s) ≅ json(s) ≅ ansi(s) iff
  ∀ component c ∈ s: props(c) preserved across all 3 renderings
```

**FMEA**:
| Failure Mode | S | O | D | RPN | Mitigation |
|-------------|---|---|---|-----|------------|
| Agent proposes unsupported component | 4 | 6 | 3 | 72 | Expand renderer to 233 |
| Semantic drift between renderers | 5 | 4 | 5 | 100 | Isomorphic proof + regression test |
| A2UI XSS via agent-proposed content | 8 | 2 | 3 | 48 | validator.gleam allowlist |

---

### F9: OpenClaw Ecosystem — 90% → 100%

**RPN**: S(3)×O(3)×D(3) = 27 | **CPS**: 0.65 | **Effort**: 5 days

**What exists**: 73 MCP tools, 34 skills, CLI fully operational.

**What's missing**:
1. WebUI control panel for all 73 MCP tools (browse, invoke, view results)
2. Skill-tool bidirectional mapping (skills calling tools, tools triggering skills)

**Implementation**:
```
- Lustre: ui/lustre/openclaw.gleam — tool catalog browser, invoke form, result viewer
- Wisp: ui/wisp/openclaw_api.gleam — POST /api/v1/openclaw/invoke
- TUI: ui/tui/openclaw_view.gleam — interactive tool selector
- Wire: skill_loader.gleam → moz/system.gleam bidirectional dispatch
```

---

### Phase 1: Foundational Data Layer (Sprint 3-5)

---

### F2: Zenoh-Native CRDT State Backplane — 0% → 100%

**RPN**: S(9)×O(5)×D(8) = 360 | **CPS**: 0.92 | **Effort**: 30 days

**This is the most critical missing piece.** All decentralized features depend on it.

**Design**:

```gleam
// crdt/types.gleam — Core CRDT abstractions

pub type CrdtValue {
  LwwRegister(value: String, timestamp: Int, node_id: String)
  GCounter(counts: Dict(String, Int))
  PNCounter(positive: Dict(String, Int), negative: Dict(String, Int))
  ORSet(elements: Dict(String, #(String, Int)))  // element -> (add_tag, timestamp)
  MVRegister(values: List(#(String, Int, String)))  // (value, timestamp, node_id)
}

pub type CrdtOp {
  LwwSet(key: String, value: String, timestamp: Int, node_id: String)
  GCounterIncr(key: String, node_id: String, delta: Int)
  ORSetAdd(key: String, element: String, tag: String, timestamp: Int)
  ORSetRemove(key: String, element: String, tag: String)
}

pub type MergeResult {
  MergeResult(value: CrdtValue, conflicts_resolved: Int)
}
```

**Implementation plan**:

```
Sprint 3 (10 days): Core CRDT Types + Merge Semantics
  - crdt/types.gleam — LWW-Register, G-Counter, PN-Counter, OR-Set, MV-Register
  - crdt/merge.gleam — merge(a, b) → MergeResult for each type
  - crdt/ops.gleam — apply_op(state, op) → state for each operation
  - Property tests: commutativity, associativity, idempotency
  - File: test/crdt_properties_test.gleam

Sprint 4 (10 days): Zenoh Transport Integration
  - crdt/zenoh_sync.gleam — publish ops to Zenoh, subscribe to peer ops
  - crdt/state_store.gleam — SQLite-backed CRDT state with version vectors
  - Topic: indrajaal/crdt/{node_id}/{key} for ops
  - Topic: indrajaal/crdt/anti-entropy/{node_id} for full-state sync
  - Anti-entropy: periodic merkle-hash comparison, delta sync on mismatch

Sprint 5 (10 days): Replace File Locks + Integration
  - Replace .active_sessions/ directory with CRDT-backed session registry
  - Replace mutable SQLite state mutations with CRDT op log
  - Integration tests: 3-node convergence within 1s
  - Chaos test: network partition → merge → convergence
```

**Mathematical structure**:

```
A CRDT (Conflict-free Replicated Data Type) satisfies:

1. Commutativity: merge(a, b) = merge(b, a)
2. Associativity: merge(merge(a, b), c) = merge(a, merge(b, c))
3. Idempotency: merge(a, a) = a

For LWW-Register:
  merge(LWW(v₁, t₁, n₁), LWW(v₂, t₂, n₂)) =
    if t₁ > t₂ then LWW(v₁, t₁, n₁)
    else if t₂ > t₁ then LWW(v₂, t₂, n₂)
    else if n₁ > n₂ then LWW(v₁, t₁, n₁)  // tie-break by node_id
    else LWW(v₂, t₂, n₂)

For G-Counter:
  merge(G(c₁), G(c₂)) = G({k: max(c₁[k], c₂[k]) ∀ k ∈ keys(c₁) ∪ keys(c₂)})
  value(G(c)) = Σ c[k] ∀ k

For OR-Set (Observed-Remove):
  add(s, e) = s ∪ {(e, unique_tag)}
  remove(s, e) = s \ {(e, t) : t ∈ observed_tags(e)}
  merge(s₁, s₂) = (s₁ ∪ s₂) \ removed_in_both
```

**FMEA**:
| Failure Mode | S | O | D | RPN | Mitigation |
|-------------|---|---|---|-----|------------|
| State divergence across nodes | 9 | 5 | 8 | 360 | CRDT guarantees eventual consistency |
| Timestamp clock skew | 7 | 4 | 5 | 140 | HLC (Hybrid Logical Clock) |
| Merge conflict data loss | 9 | 3 | 6 | 162 | MV-Register preserves all concurrent writes |
| Anti-entropy storm (large delta) | 6 | 3 | 4 | 72 | Merkle tree delta sync |

---

### F7: Cryptographically Verifiable Event Sourcing Log — 10% → 100%

**RPN**: S(8)×O(4)×D(7) = 224 | **CPS**: 0.85 | **Effort**: 20 days

**Design**:

```gleam
// eventsource/types.gleam

pub type EventEntry {
  EventEntry(
    sequence: Int,
    timestamp: Int,
    event_type: String,
    payload: String,
    prev_hash: String,       // SHA-256 of previous entry
    hash: String,            // SHA-256 of this entry
    signature: String,       // Ed25519 signature by node
    node_id: String,
  )
}

pub type EventLog {
  EventLog(
    entries: List(EventEntry),
    head_hash: String,
    chain_length: Int,
    merkle_root: String,
  )
}
```

**Implementation plan**:

```
Sprint 3 (parallel with CRDT):
  Week 1 (5 days): Hash Chain Core
    - eventsource/chain.gleam — append_event(), verify_chain(), compute_hash()
    - eventsource/merkle.gleam — build_tree(), verify_proof(), delta_proof()
    - Ed25519 signing via existing crypto NIF
    - Property test: chain integrity (tamper any entry → verification fails)

  Week 2 (5 days): Zenoh Transport
    - eventsource/publisher.gleam — publish events to indrajaal/events/{node_id}
    - eventsource/subscriber.gleam — subscribe + verify incoming events
    - eventsource/replication.gleam — full-chain sync on node join

Sprint 4 (10 days): Integration
    - Replace audit_log.rs append-only with hash-chained events
    - Replace TransactionTrace SQLite inserts with event log entries
    - Migrate PipelineTracer to emit signed events
    - Implement tamper detection alarm (SC-ALARM integration)
    - Test: inject tampered event → system detects within 100ms
```

**Mathematical structure**:

```
Hash Chain:
  H(e_0) = SHA256(e_0.payload || e_0.timestamp || "genesis")
  H(e_i) = SHA256(e_i.payload || e_i.timestamp || H(e_{i-1}))

Verification:
  valid(chain) ⟺ ∀ i > 0: H(e_i) == SHA256(e_i.payload || e_i.timestamp || e_{i-1}.hash)

Merkle Tree:
  leaf(e_i) = H(e_i)
  node(l, r) = SHA256(l || r)
  root = top of balanced binary tree

Proof of inclusion:
  prove(e_i) = list of sibling hashes from leaf to root
  verify(e_i, proof, root) = recompute root from e_i + proof siblings
```

---

### Phase 2: Transport Layer (Sprint 6-8)

---

### F3: Zero-IP Identity Routing — 2% → 100%

**RPN**: S(8)×O(4)×D(7) = 224 | **CPS**: 0.80 | **Effort**: 20 days

**Design**:

```gleam
// identity/types.gleam

pub type DeviceIdentity {
  DeviceIdentity(
    zid: String,              // Zenoh session ID (permanent)
    public_key: String,       // Ed25519 public key
    device_name: String,      // human-readable
    capabilities: List(String), // ["compute", "storage", "gateway"]
    joined_at: Int,           // Unix timestamp
  )
}

pub type RoutingEntry {
  RoutingEntry(
    target_zid: String,
    topic_prefix: String,     // indrajaal/{layer}/{domain}/
    last_seen: Int,
    latency_ms: Int,
    trust_level: TrustLevel,
  )
}

pub type TrustLevel {
  Founder     // Operator's primary device
  Verified    // ECDSA-paired device
  Provisional // Recently joined, not yet verified
  Untrusted   // Unknown device
}
```

**Implementation**:
```
Sprint 6 (10 days): Identity + Pairing
  - identity/keypair.gleam — generate Ed25519 keypair, store in Smriti
  - identity/pairing.gleam — ECDSA challenge-response device pairing
  - identity/registry.gleam — CRDT-backed device registry (uses F2)
  - CLI: sa-plan pair <device-name> → generates QR code / pairing token

Sprint 7 (10 days): Zero-IP Routing
  - identity/router.gleam — ZID-based routing table (no IP addresses)
  - Remove all TCP/IP direct connections from container orchestration
  - All container-to-container: via Zenoh ZID topic addressing
  - Mutual authentication: verify Ed25519 signature on every Zenoh message
  - Test: boot mesh with zero IP configuration → all communication via ZID
```

---

### F10: HA Seamless Upgrades — 50% → 100%

**RPN**: S(8)×O(3)×D(5) = 120 | **CPS**: 0.72 | **Effort**: 15 days

**Design**:

```gleam
// ha/rolling_upgrade.gleam

pub type UpgradeState {
  Idle
  Planning(nodes: List(String), target_version: String)
  Upgrading(current_node: String, remaining: List(String), completed: List(String))
  Verifying(node: String, checks: List(HealthCheck))
  RollingBack(node: String, reason: String)
  Complete(duration_ms: Int, nodes_upgraded: Int)
}

pub type UpgradeStep {
  DrainNode(zid: String)           // Stop accepting new intents
  WaitDrain(zid: String, max_ms: Int)  // Wait for active intents to complete
  StopNode(zid: String)           // Graceful shutdown
  UpgradeNode(zid: String, version: String)  // Deploy new binary
  StartNode(zid: String)          // Boot with new version
  VerifyNode(zid: String)         // Run health checks
  ResumeNode(zid: String)         // Accept new intents
}
```

**Implementation**:
```
Sprint 7 (parallel with Zero-IP):
  Week 1 (5 days): Rolling Upgrade Sequencer
    - ha/rolling_upgrade.gleam — state machine for N-node upgrade
    - ha/version_negotiation.gleam — ensure backward compatibility
    - Upgrade order: Backup → Standby → Primary (Primary last)

  Week 2 (5 days): Wire + Test
    - Wire to leadership.gleam lease management
    - Wire to cortex.gleam graceful drain (complete active OODA loops)
    - Test: 3-node cluster, upgrade one at a time, 0 dropped intents
    - TLA+ spec: specs/tla/RollingUpgrade.tla (prove 0 intent loss)

Sprint 8 (5 days): SIL-6 Timing + Chaos
    - SIL-6 timing bounds: upgrade step < 30s per node
    - Chaos test: kill node mid-upgrade → remaining nodes continue
    - Version matrix: define which versions can coexist
```

---

### Phase 3: Autonomous Lifecycle (Sprint 9-11)

---

### F1: Decentralized Emergent Ignition — 5% → 100%

**RPN**: S(8)×O(3)×D(8) = 192 | **CPS**: 0.76 | **Effort**: 25 days

**Depends on**: F2 (CRDT), F3 (Zero-IP), F10 (HA)

**Design**:

```gleam
// gossip/protocol.gleam

pub type GossipMessage {
  Heartbeat(zid: String, version: String, state_hash: String)
  PeerList(peers: List(DeviceIdentity))
  BootProposal(genome: List(ContainerSpec), proposer_zid: String)
  BootVote(proposal_hash: String, voter_zid: String, approve: Bool)
  AntiEntropy(merkle_root: String, level: Int, hashes: List(String))
}

pub type BootConsensus {
  BootConsensus(
    proposal: List(ContainerSpec),
    votes: Dict(String, Bool),      // zid → approve
    quorum: Int,                     // ⌊N/2⌋ + 1
    decided: Bool,
  )
}
```

**Implementation**:
```
Sprint 9 (10 days): Gossip Protocol Core
  - gossip/protocol.gleam — SWIM-style failure detection (ping, ping-req, suspect)
  - gossip/membership.gleam — peer discovery without orchestrator
  - gossip/dissemination.gleam — piggybacked state on heartbeats
  - Fanout: each node gossips to √N random peers per round

Sprint 10 (10 days): Leaderless Boot
  - gossip/boot.gleam — propose genome, collect votes, reach consensus
  - gossip/dag_free.gleam — replace hard-coded DAG with emergent ordering
  - Container start order derived from dependency graph in genome
  - No single orchestrator — any node can propose boot

Sprint 11 (5 days): Anti-Entropy + Convergence
  - gossip/anti_entropy.gleam — merkle tree state comparison
  - On hash mismatch: request delta from peer
  - Convergence test: 5 nodes, kill 2, recover → full state within 10s
```

**Mathematical structure**:

```
SWIM Protocol:
  Every T_gossip seconds, node i:
    1. Select k = ⌈log₂(N)⌉ random peers
    2. Send Heartbeat(i, version, state_hash)
    3. If peer j doesn't respond within T_timeout:
       - Enter SUSPECT state for j
       - Ask k' peers to ping j (indirect probe)
       - If no response within T_suspect: declare j DEAD
    4. Piggyback membership changes on heartbeats

  Dissemination guarantee:
    With fanout k = ⌈log₂(N)⌉ and rounds r = ⌈3·log₂(N)⌉:
    P(all nodes receive update) > 1 - N·e^(-k) ≈ 1 - ε

  Boot Consensus (simplified Raft-free):
    1. Any node proposes genome hash
    2. Peers vote within T_vote = 5s
    3. If votes ≥ ⌊N/2⌋ + 1: boot proceeds
    4. If timeout: re-propose with incremented epoch
```

---

### F8: Continuous Stochastic Apoptosis — 40% → 100%

**RPN**: S(6)×O(4)×D(5) = 120 | **CPS**: 0.65 | **Effort**: 15 days

**Design**:

```gleam
// chaos/apoptosis.gleam

pub type ApoptosisConfig {
  ApoptosisConfig(
    mean_lifespan_hours: Float,    // e.g., 72.0 hours
    variance_hours: Float,         // e.g., 24.0 hours
    min_lifespan_hours: Float,     // e.g., 1.0 hour (safety floor)
    max_concurrent_deaths: Int,    // e.g., 1 (prevent cascade)
    excluded_containers: List(String), // ["db-prod", "zenoh-router"]
  )
}

pub type ContainerLifespan {
  ContainerLifespan(
    container: String,
    born_at: Int,
    scheduled_death: Int,   // sampled from distribution
    actual_death: Option(Int),
    resurrections: Int,
  )
}
```

**Implementation**:
```
Sprint 10 (parallel with Gossip Boot):
  Week 1 (5 days): Stochastic Lifecycle
    - chaos/apoptosis.gleam — sample lifespans from log-normal distribution
    - chaos/scheduler.gleam — schedule container deaths, enforce constraints
    - Log-normal: ln(T) ~ N(μ=ln(72h), σ=0.5) → median 72h, 95% in [24h, 216h]
    - Safety: never kill db-prod, zenoh-router, or >1 container simultaneously

  Week 2 (5 days): Chaos Framework
    - chaos/injection.gleam — inject failures: kill, pause, network partition
    - chaos/observer.gleam — measure recovery time, verify anti-fragility
    - Metric: Mean Time To Recovery (MTTR) < 30s for any single container

Sprint 11 (5 days): Adaptive + Integration
    - chaos/adaptive.gleam — adjust lifespan based on system health
    - If health > 0.9: shorten lifespans (more chaos = more anti-fragile)
    - If health < 0.7: lengthen lifespans (reduce chaos during stress)
    - Integration with Prajna immune system (auto-healing response)
```

**Mathematical structure**:

```
Container lifespan T follows log-normal distribution:
  ln(T) ~ N(μ, σ²)
  
  E[T] = e^(μ + σ²/2)
  Var[T] = (e^(σ²) - 1) · e^(2μ + σ²)

For μ = ln(72), σ = 0.5:
  E[T] ≈ 81.5 hours
  Median[T] = 72 hours
  P(T < 24h) ≈ 2.5%
  P(T > 216h) ≈ 2.5%

Anti-fragility metric:
  AF(system) = MTTR_stressed / MTTR_calm
  Target: AF < 1.0 (system recovers FASTER under stress)
```

---

### Phase 4: Cognitive + Proof (Sprint 12-15)

---

### F5: Continuous Formal Verification — 5% → 100%

**RPN**: S(7)×O(5)×D(7) = 245 | **CPS**: 0.82 | **Effort**: 25 days

**Design**:

```
Sprint 12 (10 days): TLA+ Spec Expansion
  - specs/tla/CrdtMerge.tla — prove CRDT merge commutativity/associativity
  - specs/tla/GossipBoot.tla — prove boot consensus terminates
  - specs/tla/RollingUpgrade.tla — prove 0 intent loss during upgrade
  - specs/tla/EventChain.tla — prove hash chain integrity invariant
  - specs/tla/Apoptosis.tla — prove max 1 concurrent death

Sprint 13 (10 days): Apalache Integration
  - scripts/formal/apalache_check.sh — run Apalache on all TLA+ specs
  - Integration into sa-verify CLI: sa-plan verify --formal
  - CI gate: Apalache must pass on every PR touching L0/L1 code
  - Bounded model checking: k=20 steps, 5 nodes

Sprint 14 (5 days): Allium → TLA+ Translation
  - allium/translator.gleam — convert Allium entities/rules to TLA+ modules
  - Automated: every allium entity maps to TLA+ VARIABLE
  - Every allium rule maps to TLA+ action with preconditions/postconditions
  - Drift detection: if Allium spec diverges from TLA+, flag violation
```

---

### F6: Embedded SLM Cognitive Kernels (WASM) — 0% → 100%

**RPN**: S(5)×O(3)×D(8) = 120 | **CPS**: 0.58 | **Effort**: 30 days

**Design**:

```
Sprint 13 (parallel with Apalache):
  Week 1 (5 days): WASM Runtime
    - Add wasmtime dependency to Cargo.toml
    - wasm/runtime.gleam — NIF wrapper for wasmtime::Engine
    - wasm/module.gleam — load/instantiate WASM modules
    - Benchmark: module instantiation < 5ms

  Week 2 (5 days): Model Preparation
    - Quantize gemma-2b to GGUF format (4-bit, ~1.5GB)
    - Compile inference loop to WASM via wasm32-wasi target
    - Test: inference on single prompt < 15ms for classification

Sprint 14 (10 days): Integration
    - wasm/classifier.gleam — semantic anomaly classification
    - Integration into cortex.gleam: classify intent locally before cloud tier
    - Tier 0 (new): WASM SLM classification < 15ms
    - If SLM classifies with confidence > 0.9: skip cloud tiers entirely
    - Fallback: if WASM fails, proceed to existing 6-tier cascade

Sprint 15 (10 days): Edge Deployment
    - wasm/edge.gleam — deploy models to edge nodes via Zenoh
    - Model versioning: hash-verified distribution
    - A/B testing: route 10% traffic to WASM, compare accuracy
    - Metric: classification accuracy ≥ 95% vs cloud model
```

---

## 4. Criticality × FMEA × Effort Matrix

| # | Feature | S | O | D | RPN | Criticality | Effort (days) | Phase | CPS |
|---|---------|---|---|---|-----|-------------|---------------|-------|-----|
| 2 | CRDT State | 9 | 5 | 8 | **360** | 10 | 30 | 1 | **0.92** |
| 5 | Formal Verify | 7 | 5 | 7 | **245** | 8 | 25 | 4 | **0.82** |
| 7 | Event Sourcing | 8 | 4 | 7 | **224** | 9 | 20 | 1 | **0.85** |
| 3 | Zero-IP | 8 | 4 | 7 | **224** | 8 | 20 | 2 | **0.80** |
| 1 | Gossip Boot | 8 | 3 | 8 | **192** | 8 | 25 | 3 | **0.76** |
| 10 | HA Upgrades | 8 | 3 | 5 | **120** | 7 | 15 | 2 | **0.72** |
| 8 | Apoptosis | 6 | 4 | 5 | **120** | 6 | 15 | 3 | **0.65** |
| 6 | SLM WASM | 5 | 3 | 8 | **120** | 5 | 30 | 4 | **0.58** |
| 4 | Tripartite UI | 4 | 6 | 3 | **72** | 5 | 15 | 0 | **0.78** |
| 9 | OpenClaw | 3 | 3 | 3 | **27** | 3 | 5 | 0 | **0.65** |
| | **TOTAL** | | | | **1,704** | | **200 days** | | |

---

## 5. Sprint Timeline

| Sprint | Weeks | Phase | Features | Effort | Risk Eliminated |
|--------|-------|-------|----------|--------|----------------|
| S1-S2 | W1-W4 | 0 | F4 (Tripartite 85→100%) + F9 (OpenClaw 90→100%) | 20d | 99 RPN (6%) |
| S3-S5 | W5-W10 | 1 | F2 (CRDT 0→100%) + F7 (Event Log 10→100%) | 50d | 584 RPN (34%) |
| S6-S8 | W11-W16 | 2 | F3 (Zero-IP 2→100%) + F10 (HA 50→100%) | 35d | 344 RPN (20%) |
| S9-S11 | W17-W22 | 3 | F1 (Gossip 5→100%) + F8 (Apoptosis 40→100%) | 40d | 312 RPN (18%) |
| S12-S15 | W23-W30 | 4 | F5 (Formal 5→100%) + F6 (SLM 0→100%) | 55d | 365 RPN (21%) |
| **TOTAL** | **30 weeks** | | **10/10 features at 100%** | **200 days** | **1,704 RPN (100%)** |

---

## 6. Risk Elimination Curve

```
RPN remaining:
1704 ┤████████████████████████████████████████
     │
1605 ┤███████████████████████████████████████  ← Phase 0 (-99)
     │
1021 ┤█████████████████████████               ← Phase 1 (-584)
     │
 677 ┤████████████████                         ← Phase 2 (-344)
     │
 365 ┤█████████                                ← Phase 3 (-312)
     │
   0 ┤                                         ← Phase 4 (-365)
     └──────────────────────────────────────
      S1   S3   S5   S7   S9  S11  S13  S15
```

---

## 7. Success Criteria (from original ultrathink mandate)

- [ ] Apalache/TLA+ in CI/CD (F5)
- [ ] Complete removal of hardcoded IP addresses (F3)
- [ ] 100% of agents as Gleam OTP actors (F4/F9)
- [ ] Sub-millisecond OODA loop latency via FRP (F8 adaptive)
- [ ] CRDT state convergence < 1s for 5 nodes (F2)
- [ ] Hash chain tamper detection < 100ms (F7)
- [ ] WASM SLM inference < 15ms (F6)
- [ ] Zero dropped intents during rolling upgrade (F10)
- [ ] Leaderless gossip boot with 0 orchestrator involvement (F1)
- [ ] Stochastic apoptosis MTTR < 30s (F8)

---

## 8. Estimated LOC by Feature

| Feature | Gleam LOC | Rust LOC | TLA+ LOC | Test LOC | Total |
|---------|-----------|----------|----------|----------|-------|
| F1 Gossip Boot | 800 | 200 | 150 | 400 | 1,550 |
| F2 CRDT State | 1,200 | 0 | 200 | 600 | 2,000 |
| F3 Zero-IP | 600 | 100 | 100 | 300 | 1,100 |
| F4 Tripartite | 1,500 | 0 | 0 | 500 | 2,000 |
| F5 Formal Verify | 300 | 0 | 800 | 200 | 1,300 |
| F6 SLM WASM | 400 | 600 | 0 | 300 | 1,300 |
| F7 Event Sourcing | 800 | 200 | 150 | 400 | 1,550 |
| F8 Apoptosis | 600 | 100 | 100 | 400 | 1,200 |
| F9 OpenClaw | 300 | 0 | 0 | 150 | 450 |
| F10 HA Upgrades | 500 | 100 | 200 | 300 | 1,100 |
| **TOTAL** | **7,000** | **1,300** | **1,700** | **3,550** | **13,550** |

Current system: ~42,000 LOC. After ultrathink core (F1-F10): ~55,550 LOC (+32%).

---

## 9. Extended Ultrathink Features (F11-F18)

Beyond the original 10-item mandate, 8 additional features leverage existing system capabilities to their full potential.

### F11: Predictive Observability (Causal Inference)

**RPN**: S(6)×O(4)×D(6) = 144 | **Phase**: 4 (parallel with F5/F6) | **Effort**: 20 days

**What exists**: PipelineTracer produces rich trace data (TransactionTrace + TransactionSummary). Mojo container exists (`indrajaal-mojo`). OTel spans flow via Zenoh.

**What's missing**: Causal inference model. Preemptive failure prediction. Anomaly scoring from span patterns.

**Design**:
```
- Feed OTel spans from indrajaal/otel/span/** into time-series model on Mojo
- Granger causality: does latency spike in stage X predict failure in stage Y?
- Anomaly detection: z-score on stage latencies → preemptive alert
- Output: indrajaal/l5/cog/predict/{intent_type} → "P(failure) = 0.73, likely stage: inference"
- Gleam UI: prediction panel in PipelineTracer view (P1-4)
```

**Mathematical structure**:
```
Granger Causality:
  X Granger-causes Y if:
  Var(Y_t | Y_{t-1..t-p}) > Var(Y_t | Y_{t-1..t-p}, X_{t-1..t-p})

Anomaly score:
  z_i = (x_i - μ_window) / σ_window
  Alert if |z_i| > 3.0 for any stage
```

---

### F12: Functional Reactive OODA (FRP Stream Actors)

**RPN**: S(5)×O(5)×D(6) = 150 | **Phase**: 3 (with F1/F8) | **Effort**: 20 days

**What exists**: 52 GRL rules across 13 domains in `rule_engine.rs` (961 LOC). Gleam `rules/engine.gleam` (386 LOC) with NIF bridge. Sequential `evaluate_*()` calls.

**What's missing**: Stream-processing actor per RETE-UL domain. Continuous wavefront evaluation. FRP composition.

**Design**:
```gleam
// rules/stream.gleam — FRP OODA rule evaluation

pub type RuleStream {
  RuleStream(
    domain: String,
    actor: Subject(RuleStreamMsg),
    last_result: RuleResult,
    evaluation_count: Int,
    avg_latency_us: Float,
  )
}

pub type RuleStreamMsg {
  NewFacts(facts: List(Fact))       // Push new facts → immediate evaluation
  Subscribe(subscriber: Subject(RuleResult))  // Get notified on decision change
  Tick                              // Periodic re-evaluation
}
```

**Implementation**:
```
Sprint 9 (10 days): FRP Rule Actors
  - rules/stream.gleam — one OTP actor per domain (13 actors)
  - Each actor: subscribes to Zenoh facts topic, evaluates on change, publishes decision
  - Latency target: <1ms per evaluation (RETE-UL NIF already achieves this)
  - Continuous: facts flow in → decisions flow out (no polling)

Sprint 10 (10 days): Wavefront Composition
  - rules/wavefront.gleam — compose 13 domain actors into unified OODA wavefront
  - Decision fusion: combine outputs from all domains into single OODA decision
  - Conflict resolution: salience-weighted priority when domains disagree
  - Metric: end-to-end OODA cycle < 30ms (currently ~100ms target)
```

---

### F13: Multiparty Session Types (Deadlock-Free Zenoh)

**RPN**: S(7)×O(3)×D(8) = 168 | **Phase**: 4 (with F5) | **Effort**: 25 days

**What exists**: Zenoh has 45+ topic namespaces. NIF boundary is untyped string-in/string-out. MoZ protocol has request/response topics.

**What's missing**: Compile-time proof of deadlock-freedom. Session type annotations. Protocol verification.

**Design**:
```gleam
// session/types.gleam — Multiparty Session Types

pub type SessionType {
  Send(message_type: String, continuation: SessionType)
  Receive(message_type: String, continuation: SessionType)
  Choice(branches: List(#(String, SessionType)))
  Offer(branches: List(#(String, SessionType)))
  End
  Rec(var: String, body: SessionType)  // recursive session
}

// MoZ protocol as session type:
// Client: Send(Request) → Receive(Response) → End
// Server: Receive(Request) → Send(Response) → End
// Duality check: client_type = dual(server_type)
```

**Implementation**:
```
Sprint 12 (10 days): Session Type Core
  - session/types.gleam — session type ADT
  - session/duality.gleam — dual(type) → type, verify client/server compatibility
  - session/checker.gleam — compile-time protocol verification via Gleam types

Sprint 13 (10 days): Protocol Annotations
  - Annotate all MoZ request/response pairs with session types
  - Annotate Zenoh Pub/Sub protocols with session types
  - Verify: no deadlocks possible in annotated protocols

Sprint 14 (5 days): NIF Boundary Typing
  - Type the NIF FFI boundary (currently string-in/string-out)
  - Verify: NIF calls satisfy session type contracts
```

---

### F14: Genetic Bootstrapping (RL Boot Optimization)

**RPN**: S(4)×O(3)×D(6) = 72 | **Phase**: 3 (with F1/F8) | **Effort**: 15 days

**What exists**: 400-scenario simulator (`simulator.rs`, 349 LOC). Boot DAG is hand-coded in `types.rs`. 7-tier boot hierarchy.

**What's missing**: Shadow universe for RL exploration. Fitness function for boot sequences. Evolutionary optimizer.

**Design**:
```
Sprint 10 (10 days): Shadow Universe
  - chaos/shadow.gleam — run boot sequences in simulation mode
  - chaos/fitness.gleam — score: f(boot) = 1/latency × success_rate × resource_efficiency
  - chaos/evolution.gleam — genetic algorithm: mutate boot order, crossover, select

Sprint 11 (5 days): Integration
  - Feed best boot sequence into gossip boot proposal (F1)
  - A/B test: hand-coded DAG vs evolved sequence
  - Metric: boot time improvement target 30%
```

**Mathematical structure**:
```
Genetic Algorithm:
  Population: P = {boot_sequence_1, ..., boot_sequence_N}
  Fitness: f(seq) = Σ_i (1/latency_i × success_i) / |seq|
  Selection: tournament(k=3)
  Crossover: order crossover (OX) preserving container dependencies
  Mutation: swap two non-dependent containers with probability p=0.1
  Termination: f_best stable for 50 generations or f_best > threshold
```

---

### F15: Proof-Carrying Agent Proposals

**RPN**: S(8)×O(3)×D(7) = 168 | **Phase**: 4 (with F5/F6) | **Effort**: 20 days

**What exists**: cortex.gleam dispatches MoZ unverified. Guardian approval is boolean (approve/reject). L0 constitutional Psi checks are assertions, not proofs.

**What's missing**: Agent outputs formal proof with each proposal. Guardian verifies proof before approval.

**Design**:
```gleam
// proof/types.gleam

pub type ProofCarryingProposal {
  ProofCarryingProposal(
    action: String,
    preconditions: List(Assertion),
    postconditions: List(Assertion),
    proof: ProofTerm,         // Agda/Quint proof term
    verified: Bool,
  )
}

pub type ProofTerm {
  TrivialProof                // Action has no preconditions
  InductionProof(base: String, step: String)
  CaseAnalysis(cases: List(#(String, ProofTerm)))
  WitnessProof(witness: String)  // Constructive proof with witness value
}
```

**Implementation**:
```
Sprint 13 (10 days): Proof Framework
  - proof/types.gleam — proof term ADT
  - proof/verifier.gleam — verify proof against pre/postconditions
  - proof/generator.gleam — generate trivial proofs for safe operations

Sprint 14 (10 days): Guardian Integration
  - Wire proof verification into l0_constitutional.gleam approval flow
  - Agent must submit proof with each L0 operation
  - Guardian checks: proof_valid? → approve. proof_invalid? → reject with reason.
  - Fallback: if no proof engine available, require 2oo3 human approval
```

---

### F16: RETE-UL Rule Engine Evolution

**RPN**: S(6)×O(4)×D(5) = 120 | **Phase**: 2 (with F3/F10) | **Effort**: 15 days

**What exists**: 52 GRL rules, 13 domains, `rule_engine.rs` (961 LOC). Gleam `rules/engine.gleam` (386 LOC) with all 13 domains mirrored. NIF bridge working.

**What's missing**: Hot-reload rules without recompile. Rule versioning. Rule authoring UI. Conflict detection between rules.

**Design**:
```
Sprint 6 (5 days): Hot-Reload Rules
  - rules/hot_reload.gleam — load GRL from Smriti.db instead of compiled constants
  - rules/versioning.gleam — track rule versions, rollback to previous on failure
  - Zenoh: publish rule updates to indrajaal/l5/cog/rules/{domain}

Sprint 7 (5 days): Rule Authoring UI
  - Lustre: lustre/rule_editor.gleam — GRL editor with syntax highlighting
  - Wisp: wisp/rules_api.gleam — GET/PUT /api/v1/rules/{domain}
  - TUI: tui/rule_editor_view.gleam — inline GRL editing

Sprint 8 (5 days): Conflict Detection
  - rules/conflict.gleam — detect overlapping preconditions with conflicting decisions
  - rules/coverage.gleam — compute rule coverage (what fact combinations are unhandled?)
  - Alert: uncovered fact combinations → suggest new rules
```

---

### F17: Gemma4 Local Intelligence Layer

**RPN**: S(5)×O(5)×D(5) = 125 | **Phase**: 2 (with F3/F10) | **Effort**: 15 days

**What exists**: Gemma4 at port 11435 as Tier 3 inference fallback. Gemma3 at port 11434 as Tier 4. Circuit breakers. Currently inference-only (question→answer).

**What's missing**: Local fine-tuning on system logs. Specialized classifiers (intent, anomaly, severity). Embedding generation for RAG. Proactive monitoring.

**Design**:
```
Sprint 6 (5 days): Specialized Classifiers
  - Create Ollama modelfiles for 3 specialized tasks:
    1. intent_classifier — classify operator intents (30+ categories)
    2. anomaly_detector — classify OTel spans as normal/anomalous
    3. severity_scorer — score threat severity 0.0-1.0
  - Deploy as named models on Ollama gemma4 instance
  - Cortex: route to specialized model instead of general gemma4

Sprint 7 (5 days): Local Embeddings
  - Generate embeddings via gemma4 /api/embeddings endpoint
  - Store in Smriti semantic.gleam vector tables
  - Replace external embedding dependency with local generation
  - RAG context retrieval via local cosine similarity

Sprint 8 (5 days): Proactive Monitoring
  - Feed system health metrics to anomaly_detector every 10s
  - If anomaly_score > 0.7: publish to indrajaal/l5/cog/predict/anomaly
  - Gleam: subscribe in cortex.gleam → trigger preemptive OODA cycle
  - Dashboard: anomaly prediction timeline in telemetry page
```

---

### F18: Ruliology Subsystem Completion

**RPN**: S(4)×O(4)×D(5) = 80 | **Phase**: 3 (with F1/F8) | **Effort**: 15 days

**What exists**: `ruliology.rs` (929 LOC) with CellularAutomaton, MultiwaySystem, CausalGraph, ProductionSystem, Hypergraph. `c3i-ruliology.wl` (671 LOC) Wolfram spec. 7 pre-built automata.

**What's missing**: Gleam UI for ruliology. NIF bridge for ruliology functions. Interactive exploration. Rule evolution (mutate rules, measure fitness).

**Design**:
```
Sprint 9 (5 days): Ruliology NIF Bridge
  - Add NIF functions: ruliology_automaton_step, ruliology_multiway_evolve,
    ruliology_causal_graph, ruliology_production_fire
  - Gleam: rules/ruliology.gleam — type-safe wrappers

Sprint 10 (5 days): Ruliology UI (Triple-Interface)
  - Lustre: lustre/ruliology.gleam — cellular automaton grid (SVG), multiway graph,
    causal graph visualization, production system fire button
  - Wisp: wisp/ruliology_api.gleam — GET /api/v1/ruliology/{type}
  - TUI: tui/ruliology_view.gleam — ANSI block automaton + rule table

Sprint 11 (5 days): Rule Evolution
  - rules/evolution.gleam — mutate GRL rules, measure fitness on test scenarios
  - Fitness: f(ruleset) = correct_decisions / total_scenarios × (1 / avg_latency)
  - Evolutionary loop: mutate → evaluate → select → repeat
  - Guard: evolved rules must pass all existing test assertions before promotion
```

---

## 10. Extended Feature Matrix

| # | Feature | S | O | D | RPN | Phase | Effort | Depends On |
|---|---------|---|---|---|-----|-------|--------|-----------|
| 11 | Predictive Observability | 6 | 4 | 6 | **144** | 4 | 20d | F7 (event log) |
| 12 | FRP OODA Wavefront | 5 | 5 | 6 | **150** | 3 | 20d | F16 (rule engine) |
| 13 | Multiparty Session Types | 7 | 3 | 8 | **168** | 4 | 25d | F5 (formal verify) |
| 14 | Genetic Bootstrapping | 4 | 3 | 6 | **72** | 3 | 15d | F1 (gossip boot) |
| 15 | Proof-Carrying Proposals | 8 | 3 | 7 | **168** | 4 | 20d | F5, F13 |
| 16 | RETE-UL Evolution | 6 | 4 | 5 | **120** | 2 | 15d | — |
| 17 | Gemma4 Intelligence | 5 | 5 | 5 | **125** | 2 | 15d | — |
| 18 | Ruliology Completion | 4 | 4 | 5 | **80** | 3 | 15d | — |

---

## 11. Revised Sprint Timeline (18 features)

| Sprint | Weeks | Phase | Features | Days | Cumulative |
|--------|-------|-------|----------|------|-----------|
| S1-S2 | W1-W4 | 0 | F4, F9 | 20 | 20 |
| S3-S5 | W5-W10 | 1 | F2, F7 | 50 | 70 |
| S6-S8 | W11-W16 | 2 | F3, F10, **F16**, **F17** | 65 | 135 |
| S9-S11 | W17-W22 | 3 | F1, F8, **F12**, **F14**, **F18** | 85 | 220 |
| S12-S15 | W23-W30 | 4 | F5, F6, **F11**, **F13**, **F15** | 105 | 325 |
| **TOTAL** | **30 weeks** | | **18 features** | **325 days** | |

---

## 12. Revised LOC Estimates

| Feature | Gleam | Rust | TLA+ | Test | Total |
|---------|-------|------|------|------|-------|
| F1-F10 (original) | 7,000 | 1,300 | 1,700 | 3,550 | 13,550 |
| F11 Predict | 400 | 200 | 0 | 200 | 800 |
| F12 FRP OODA | 800 | 0 | 100 | 400 | 1,300 |
| F13 Session Types | 1,000 | 0 | 300 | 500 | 1,800 |
| F14 Genetic Boot | 500 | 100 | 0 | 300 | 900 |
| F15 Proof Proposals | 700 | 0 | 200 | 300 | 1,200 |
| F16 Rule Engine Evo | 600 | 100 | 0 | 300 | 1,000 |
| F17 Gemma4 Intel | 400 | 100 | 0 | 200 | 700 |
| F18 Ruliology | 500 | 200 | 0 | 300 | 1,000 |
| **TOTAL** | **11,900** | **2,000** | **2,300** | **6,050** | **22,250** |

Current system: ~42,000 LOC. After full ultrathink (F1-F18): ~64,250 LOC (+53%).
