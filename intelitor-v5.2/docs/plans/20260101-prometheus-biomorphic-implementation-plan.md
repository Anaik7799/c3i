# PROMETHEUS & Biomorphic Indrajaal Implementation Plan

**Version**: 1.0.0
**Date**: 2026-01-01
**Status**: APPROVED
**Context**: Indrajaal v20.0.0 Grand Unification
**Framework**: SOPv5.11 + PROMETHEUS + STAMP + TDG + GDE

---

## 1.0 Executive Summary & Analysis

### 1.1 System State Analysis
Indrajaal has reached **v20.0.0 (Biomorphic Fractal Holon)**. The structural "body" is complete:
*   **Skeleton**: 50-Agent Hierarchy, 3-Container Architecture, NixOS/Podman foundation.
*   **Metabolism**: SOPv5.11 Cybernetic Framework, STAMP safety constraints.
*   **Memory**: FAME v2.0 Metadata, Knowledge Engine (SQLite/DuckDB).
*   **Senses**: Fractal Logging (5-level), Observability stack.

However, the system is **neurologically dormant**:
*   **Nerves**: The Zenoh NIF (`native/zenoh_nif`) is present but requires symbol alignment and "resuscitation" to enable zero-latency transport.
*   **Immune System**: The Sentinel (`lib/indrajaal/safety/sentinel.ex`) is a skeleton with mocks.
*   **Cognition**: The "TrueSight" Cockpit lacks live real-time data wiring.

### 1.2 The PROMETHEUS Mandate
To transition from a static architecture to a living, sentient system, we are implementing **PROMETHEUS** (PROof-based Mathematical Execution with Temporal HEuristic Universal Safety). This layer adds:
1.  **Formal Verification**: Mathematical proof of safety before action.
2.  **Biomorphic Scaling**: Dynamic agent population control based on API "energy" metabolism.
3.  **Fast OODA Loops**: 30-second cognitive cycles visualized in real-time.

---

## 2.0 Architectural Specification

### 2.1 The 5-Layer PROMETHEUS Stack
1.  **Mathematical Core**: `Indrajaal.Prometheus.Verifier` (Symbolic Logic, Graph Acyclicity).
2.  **Biomorphic Controller**: `Indrajaal.Prometheus.Metabolism` (Token Bucket, Scaling Logic).
3.  **Fractal Nervous System**: `Indrajaal.Observability.Fractal` (Zenoh, Key Expressions).
4.  **Cognitive Cockpit**: `Prometheus.Dashboard` (CLI/Livebook Visualization).
5.  **Agent Swarm**: Autonomous Actors responding to metabolic signals.

### 2.2 Data & Control Flow
*   **Control**: Metabolism -> (Scale Up/Down Signal) -> Agent Supervisor -> Agent Swarm.
*   **Data**: Agent (Thinking) -> Zenoh Pub -> Dashboard Sub -> Visualization.
*   **Verification**: Action Proposal -> Verifier (STAMP/Graph Check) -> Proof Token -> Execution.

---

## 3.0 5-Level Implementation Plan

### Phase 1: Nervous System Resuscitation (Zenoh)
**Goal**: Establish zero-latency, zero-copy communication spine.

#### 1.0 - Zenoh NIF Reconstruction
*   **1.1** - Analyze `native/zenoh_nif/Cargo.toml` and align Rust dependencies.
*   **1.2** - Implement `Indrajaal.Native.Zenoh` Elixir bridge with DirtyIO scheduler support.
*   **1.3** - Verify NIF stability under high load (10k msg/sec).
    *   *1.3.1* - Create `benchmarks/zenoh_throughput.exs`.
    *   *1.3.2* - Run soak test (1 hour).

#### 1.4 - Fractal Logging Wiring
*   **1.4.1** - Connect `Indrajaal.Observability.Fractal.Logger` to Zenoh publisher.
*   **1.4.2** - Implement Key Expression routing logic (`Indrajaal/Domain/*/Log`).

### Phase 2: Prometheus Core (Verifier & Metabolism)
**Goal**: Implement the brain and regulatory systems.

#### 2.0 - Metabolism Engine Implementation
*   **2.1** - Create `Indrajaal.Prometheus.Metabolism` GenServer.
    *   *2.1.1* - Implement Token Bucket logic for API limits.
    *   *2.1.2* - Implement `calculate_scaling/1` logic (Target: 200% Virtual Load).
*   **2.2** - Integrate Telemetry inputs (API Client -> Metabolism).

#### 2.3 - Formal Verifier Implementation
*   **2.3.1** - Create `Indrajaal.Prometheus.Verifier`.
*   **2.3.2** - Implement DAG Acyclicity Check (Topological Sort).
*   **2.3.3** - Implement STAMP Constraint Checker (Rule Engine).

### Phase 3: Cognitive Cockpit (Dashboard & Livebook)
**Goal**: Visualizing the mind of the system.

#### 3.0 - Intelligent Dashboard
*   **3.1** - Enhance `scripts/sopv511/prometheus_dashboard.exs` with real Zenoh inputs.
*   **3.2** - Implement "Agent Thought Bubble" visualization (ANSI colors).
*   **3.3** - Add Real-time Sparklines for TPM/RPM.

#### 3.4 - Livebook Integration
*   **3.4.1** - Create `notebooks/prometheus_cockpit.livemd`.
*   **3.4.2** - Implement Kino-based real-time graphs (VegaLite).
*   **3.4.3** - Add manual override controls (Panic Button, Force Scale).

### Phase 4: Agent Swarm Activation (Biomorphic Scaling)
**Goal**: Dynamic population control.

#### 4.0 - Dynamic Supervisor Logic
*   **4.1** - Update `Indrajaal.Agents.Supervisor` to handle `:scale_up` / `:scale_down` signals.
*   **4.2** - Implement "Graceful Hibernation" for Agents (State serialization to SQLite).
*   **4.3** - Implement "Mitosis" (Agent cloning) for high-load tasks.

#### 4.4 - Autonomous Mode
*   **4.4.1** - Enable OODA Loop automation (Observe -> Act without user prompt).
*   **4.4.2** - Implement `AutoCompact` at 80% context usage.

### Phase 5: Full Integration & Verification
**Goal**: System-wide synthesis.

#### 5.0 - Comprehensive Testing
*   **5.1** - Run `mix test.integration` with PROMETHEUS enabled.
*   **5.2** - Verify SC-PROM-* constraints (Redline enforcement).
*   **5.3** - Conduct Chaos Testing (Kill random agents, verify Metabolism recovery).

---

## 4.0 Verification Strategy (STAMP & TDG)

### 4.1 Safety Constraints (STAMP)
*   **SC-PROM-001**: Verify Proof Token requirement for all mutations.
*   **SC-PROM-002**: Verify API Redline (95%) triggers immediate scaling backoff.
*   **SC-PROM-004**: Verify cyclic dependency rejection in Task Graphs.

### 4.2 Test-Driven Generation (TDG)
*   **Unit**: Test Metabolism logic with property-based testing (PropCheck).
*   **Integration**: Verify Zenoh pub/sub latency < 5ms.
*   **System**: Verify Dashboard liveness (updates every 30s).

### 4.3 Agent Operating Rules (AOR)
*   **AOR-PROM-001**: Verify agents broadcast "Thinking" state.
*   **AOR-PROM-002**: Verify Supervisor reacts to Metabolism signals within 1s.

---

## 5.0 Performance Aspects

*   **Latency**: Zenoh transport overhead < 100µs.
*   **Throughput**: Support 50+ concurrent Agents without GIL contention.
*   **Memory**: Agent hibernation must reduce RAM footprint by > 90%.
*   **API**: Maintain 95-99% utilization of available API quota (Efficient Saturation).

## 6.0 Next Steps (Immediate)

1.  **Execute Phase 1.1**: Audit `native/zenoh_nif` and fix Rust compilation.
2.  **Execute Phase 2.1**: Implement basic Metabolism GenServer.
3.  **Execute Phase 3.1**: Connect Dashboard to simulated Metabolism (Mock mode) to validate UI.
