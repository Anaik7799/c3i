# Comprehensive Implementation Plan: Indrajaal v19.0 (Unified Evolution)

**Date**: 20251230-0000 CEST
**Subject**: Master Execution Roadmap (v10 -> v19)
**Status**: ACTIVE
**Author**: Gemini (Cybernetic Architect)

---

## 1.0 Phase 1: The Fractal Foundation (Sprint 1-2)
**Theme**: Safety, Structure, DNA.
**Goal**: Establish the immutable core that prevents future entropy.

### 1.1 Structural Foundations
*   [ ] **1.1.1** Define `Indrajaal.Core.Holon` Protocol (`lib/indrajaal/core/holon.ex`).
    *   Callbacks: `system1_ops`, `system3_control`, `system5_policy`.
*   [ ] **1.1.2** Implement `Indrajaal.Core.Constitution` (`lib/indrajaal/core/constitution.ex`).
    *   Hardcode `CLAUDE.md` hash.
    *   Implement `verify_self_integrity!/0`.

### 1.2 Cryptographic DNA
*   [ ] **1.2.1** Create Mix Compiler Hook (`lib/mix/tasks/compile.inject_dna.ex`).
    *   Hashes `docs/journal/20251229-2300-expanded-azimov-banks-protocol.md`.
    *   Injects into `@system_dna`.
*   [ ] **1.2.2** Update `Indrajaal.Safety.Guardian` to enforce DNA checks on IO.

---

## 2.0 Phase 2: The Cognitive Awakening (Sprint 3-4)
**Theme**: Intelligence, Prediction, Time.
**Goal**: Move from reactive heuristics to predictive physics.

### 2.1 Active Inference
*   [ ] **2.1.1** Implement `Indrajaal.AI.FreeEnergy` calculator.
    *   Input: Metric Stream.
    *   Output: Surprise Score ($D_{KL}$).
*   [ ] **2.1.2** Upgrade `Indrajaal.Observability` to support **Vector Embeddings** (`sqlite_vss`).
    *   Store logs as vectors for GraphRAG.

### 2.2 Temporal Engineering
*   [ ] **2.2.1** Enable **Zenoh Event Sourcing** in `lib/indrajaal/communication/unified_bus.ex`.
*   [ ] **2.2.2** Build "Time Travel" Debugger (`scripts/debug/chronos_replay.exs`).

---

## 3.0 Phase 3: The Economic & Ecological Expansion (Sprint 5-6)
**Theme**: Resources, Scale, Federation.
**Goal**: Autonomous resource management and horizontal growth.

### 3.1 Internal Economy
*   [ ] **3.1.1** Implement `Indrajaal.Economy.Bank`.
    *   Token: `ComputeCredit`.
*   [ ] **3.1.2** Implement **Vickrey Auction** logic in `Indrajaal.Coordination.Auctioneer`.

### 3.2 Mycelial Federation
*   [ ] **3.2.1** Implement `Indrajaal.Federation.Gossip`.
    *   Protocol: Epidemic state sharing.
*   [ ] **3.2.2** Implement **Genetic Antibody** propagation (`Indrajaal.Security.ImmuneSystem`).

---

## 4.0 Phase 4: The Nervous System Upgrade (Sprint 7-8)
**Theme**: Infrastructure as Grammar, Proprioceptive Interface.
**Goal**: Radical usability and control.

### 4.1 CEPAF Hyper-Evolution
*   [ ] **4.1.1** Create F# DSL `lib/cepaf/OrchestratorDSL.fs`.
    *   Computation Expression: `orchestrate { ... }`.
*   [ ] **4.1.2** Implement **Kalman Filter** scaling in `Indrajaal.Control.PredictiveScaler`.

### 4.2 The Proprioceptive Cockpit
*   [ ] **4.2.1** Add **Entropy Heatmap** visualization (D3.js) to Dashboard.
*   [ ] **4.2.2** Implement **Maxwell's Demon** (AI Log Filter) in `Indrajaal.Cockpit.Filter`.

---

## 5.0 Phase 5: The Viral Autopoiesis (Sprint 9+)
**Theme**: Jain Node, Survival, Incorruptibility.
**Goal**: The system becomes a self-replicating, benevolent organism.

### 5.1 The Jain Node
*   [ ] **5.1.1** Build `Indrajaal.Jain.Scout` (Network Discovery).
*   [ ] **5.1.2** Implement **Cryptographic Reproduction** (`Indrajaal.Jain.Propagator`).
    *   Key derivation from Constitution Hash.

### 5.2 The Explainability Layer
*   [ ] **5.2.1** Upgrade Logger to support **Causal Graphs**.
*   [ ] **5.2.2** Add "Constitution Citations" to all automated actions.

---

## 6.0 Critical Path (Immediate Next Steps)

1.  **Freeze**: Lock all `docs/journal/*` files as the Immutable Spec.
2.  **Scaffold**: Run `mix new indrajaal_core` structure update to support Holons.
3.  **Proof**: Write the first Agda proof for the `Non-Aggression` invariant.
