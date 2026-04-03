# Unified Fractal Evolution Plan: Indrajaal v13.0 (2025-2026)

**Date**: 20251229-1400 CEST
**Status**: DRAFT -> ACTIVE
**Framework**: SOPv5.11 + Fractal Mandate
**Criticality**: Risk-Adjusted Implementation Strategy
**Author**: Gemini (Cybernetic Architect)

---

## Executive Summary

This plan integrates the **Theoretical** (Active Inference, Constructor Theory), **Structural** (Hyper-Structures, Economies), and **Fractal** (Holons, Self-Similarity) concepts into a concrete, 5-level execution roadmap. It transforms Indrajaal from a "Safety-Critical System" into an "Autopoietic Civilization."

**Guiding Principle**: Evolution must be **Fractal**. We do not build "features"; we evolve "Holons" that replicate the system's DNA at every scale.

---

## Phase 1: The Fractal Foundation (Safety & Structure)
**Objective**: Establish the immutable laws of self-similarity and secure the "System DNA" against entropy.
**Timeline**: Immediate (Sprint 1-2)
**Criticality**: **P0 (System Survival)**

### 1.0 - The Holon Standard (Recursive Structure) [P0]
#### 1.1 - Define the Universal Holon Protocol
##### 1.1.1 - Create `Indrajaal.Core.Holon` Behaviour
###### 1.1.1.1 - Define Callbacks
-   `system1_ops()`: The doing function.
-   `system3_control()`: The resource/guard function.
-   `system5_policy()`: The identity/STAMP verification.
###### 1.1.1.2 - Implement Default Holon Macro
-   Provide `use Indrajaal.Holon` that injects default VSM layers into any GenServer.

#### 1.2 - DNA Replication & Verification
##### 1.2.1 - Embed System DNA (`CLAUDE.md` Hash)
###### 1.2.1.1 - Compiler Hook
-   Create a custom Mix task/compiler hook that hashes `CLAUDE.md` and injects it into `@system_dna` module attribute of *every* compiled file.
###### 1.2.1.2 - Runtime Handshake
-   Update `Indrajaal.Communication.Protocol` to reject messages from nodes/agents with mismatched DNA hashes (unless valid upgrade path).

---

## Phase 2: The Cognitive Awakening (Intelligence & Time)
**Objective**: Transition from reactive OODA loops to predictive Active Inference and gain mastery over temporal causality.
**Timeline**: Short-Term (Sprint 3-4)
**Criticality**: **P1 (Core Capability)**

### 2.0 - Active Inference Implementation [P1]
#### 2.1 - The Predictive Cortex
##### 2.1.1 - Define Generative Models
###### 2.1.1.1 - System State Distribution $P(S)$
-   Model "Ideal State" as a distribution of metrics (e.g., Latency ~ N(20ms, 5ms)).
###### 2.1.1.2 - Surprise Metric Calculation
-   Implement `Indrajaal.AI.FreeEnergy` to calculate Kullback-Leibler divergence between sensory input and model.

#### 2.2 - Temporal Engineering (Chronistics)
##### 2.2.1 - Time-Travel Debugging Infrastructure
###### 2.2.1.1 - Zenoh Event Sourcing
-   Configure Zenoh to persist the "Unified Control Bus" stream to disk with high-resolution timestamps.
###### 2.2.1.2 - The "Rewind" Interface
-   Create a script `scripts/debug/chronos_replay.exs` that re-injects historical messages into a sandboxed test container.

---

## Phase 3: The Economic Engine (Resource & Value)
**Objective**: Replace static scheduling with dynamic, fractal market dynamics to optimize resource allocation efficiently.
**Timeline**: Medium-Term (Sprint 5-6)
**Criticality**: **P2 (Optimization)**

### 3.0 - Internal Resource Markets [P2]
#### 3.1 - The Compute Auction (Vickrey Mechanism)
##### 3.1.1 - Token Definition
###### 3.1.1.1 - `ComputeCredit` Struct
-   Define struct with fields: `priority`, `ttl`, `owner_id`.
###### 3.1.1.2 - Wallet Implementation
-   Add "Wallet" state to every Agent Holon. Critical Agents (Executive) get infinite supply; Workers get limited budgets.

#### 3.2 - Dynamic Load Balancing
##### 3.2.1 - Auctioneer Agent
###### 3.2.1.1 - Bid Evaluation Logic
-   Implement logic to award FLAME runners to the highest bidder (Criticality * Urgency).
###### 3.2.1.2 - Congestion Pricing
-   Automatically raise base price during high load (dampening oscillation).

---

## Phase 4: The Ecological Expansion (Federation & Interface)
**Objective**: Scale horizontally into a "Forest" of nodes and provide generative interfaces for human-system symbiosis.
**Timeline**: Long-Term (Sprint 7-8)
**Criticality**: **P2 (Expansion)**

### 4.0 - Mycelial Federation [P2]
#### 4.1 - Swarm Learning & Discovery
##### 4.1.1 - Gossip Protocol (Epidemic)
###### 4.1.1.1 - State Propagation
-   Implement a lightweight gossip protocol on Tailscale to share "Holographic State" (Cluster Health, Threat Level) efficiently.
###### 4.1.1.2 - Antibody Sharing
-   When a node identifies a threat pattern, propagate the "Signature" to all peers immediately.

### 4.1 - Generative Interface [P3]
#### 4.2.1 - Intent-Based UI
###### 4.2.1.1 - Natural Language to HEEx
-   Train/Tune a small LLM (Flash-Lite) to convert user intent ("Show me red alarms") into valid Phoenix LiveView filter params or HEEx templates.
###### 4.2.1.2 - Sandboxed Rendering
-   Render generated UIs in an `iframe` or restricted LiveView process to prevent XSS/Injection.

---

## Phase 5: The Substrate Optimization (Physical Physics)
**Objective**: Minimize the gap between software and hardware to achieve maximum performance and zero attack surface.
**Timeline**: Future (Sprint 9+)
**Criticality**: **P3 (Perfection)**

### 5.0 - Biomorphic Substrate [P3]
#### 5.1 - Rust Native Acceleration
##### 5.1.1 - "Hot Path" Replacement
###### 5.1.1.1 - Identify Bottlenecks
-   Use `mix profile.fprof` to find the top 3 CPU-bound functions (likely FPPS regex or Graph traversals).
###### 5.1.1.2 - Rustler NIF Implementation
-   Rewrite these specific Holons in Rust using Rustler for memory safety and speed.

#### 5.2 - Memetic Engineering
##### 5.2.1 - The Pattern Hunter
###### 5.2.1.1 - AST Analysis
-   Create an agent that scans the AST for "Anti-Patterns" (e.g., `Enum.map |> Enum.filter`).
###### 5.2.1.2 - Memetic Infection
-   Automatically generate PRs to "infect" the code with the "Superior Meme" (e.g., `Stream.filter |> Stream.map`).

---

## Implementation Matrix (Complexity vs. Impact)

| ID | Task | Criticality | Complexity | Impact | Target Layer |
|----|------|-------------|------------|--------|--------------|
| 1.1 | Holon Protocol | P0 | Medium | High | Structural |
| 1.2 | DNA Embedding | P0 | Low | Critical | Safety |
| 2.1 | Active Inference | P1 | High | Transformative | Cognitive |
| 2.2 | Time Travel | P1 | High | High | Temporal |
| 3.1 | Compute Auction | P2 | Medium | High | Economic |
| 4.1 | Swarm Gossip | P2 | Medium | High | Ecological |
| 5.1 | Rust NIFs | P3 | High | Medium | Substrate |

---

## Next Steps (Immediate)

1.  **Freeze Specs**: Lock `docs/journal/` contents as the source of truth.
2.  **Scaffold Phase 1**: Begin defining the `Indrajaal.Core.Holon` behaviour.
3.  **Update Todolist**: Ingest this plan into `PROJECT_TODOLIST.md`.
