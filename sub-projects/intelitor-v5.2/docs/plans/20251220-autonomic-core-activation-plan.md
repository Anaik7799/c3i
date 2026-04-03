# 🧠 AUTONOMIC CORE ACTIVATION PLAN: FROM FORMALISM TO EXECUTION

**Version**: 4.0.0-AUTONOMIC-CORE
**Date**: 2025-12-20
**Status**: 🟢 **READY**
**Architect**: Gemini-2.0-Flash-Thinking (Cybernetic Architect)
**Context**: Phase 2 of SOPv5.11 - Activation of the verified autonomic nervous system.

## 1.0 🔭 OBSERVATION (Current State)

*   **Foundation**: Tailscale physics (Stream Alpha) and Quint/Agda Logic (Stream Beta) are established.
*   **Artifacts**: `OODA.qnt`, `Sentinel.qnt`, `FLAME.qnt` exist as verified blueprints.
*   **Codebase**: `OODA.Loop` has been refactored to match Quint. `Sentinel` exists but needs formal alignment. `FLAME` is not yet supervised in `application.ex`.
*   **Gap**: The "Brain" (OODA) is isolated from the "Muscles" (FLAME) and "Immune System" (Sentinel).

## 2.0 🧭 ORIENTATION (To-Be State)

**Goal**: A fully integrated **Autonomic Core** where:
1.  **Sentinel** enforces `ClusterQuorum` logic defined in `Sentinel.qnt`.
2.  **FLAME** scales resources according to `FLAMEExecution` logic in `FLAME.qnt`.
3.  **Supervision**: The OTP supervision tree (`application.ex`) correctly starts these components in the verified order.
4.  **Verification**: Runtime telemetry confirms strict adherence to LTL safety properties.

### 2.1 The Cybernetic Alignment Strategy
We will strictly map the Quint State Machines to Elixir GenServers:

| Quint Model | Elixir Component | Key Invariant to Enforce |
| :--- | :--- | :--- |
| `ClusterQuorum` | `Indrajaal.Cluster.Sentinel` | $\text{WritesEnabled} \iff \text{HasQuorum}$ |
| `FLAMEExecution` | `Indrajaal.FLAME.Supervisor` | $\text{ScaleUp} \implies \text{QuorumMaintained}$ |
| `OODALoop` | `Indrajaal.Cybernetic.OODA.Loop` | $\text{Action} \implies \text{Confidence} > 70\%$ |

## 3.0 ⚖️ DECISION (Execution Strategy)

We will execute **Task 40.0** using **Max Parallelization** across three synchronized streams.

### 🌊 Stream Delta: Sentinel Hardening (P0)
*   **Focus**: Immune System & Consensus.
*   **Agent**: Distributed Systems Engineer.
*   **Scope**:
    *   Refactor `Sentinel.ex` to match `Sentinel.qnt` states exactly.
    *   Implement "Apoptosis" (Self-Termination) on split-brain.
    *   Verify Tailscale DNS binding.

### 🌊 Stream Epsilon: FLAME Activation (P0)
*   **Focus**: Elastic Muscle & Scaling.
*   **Agent**: Platform Engineer.
*   **Scope**:
    *   Define `Indrajaal.FLAME.Pools` module.
    *   Update `application.ex` to supervise FLAME backend.
    *   Configure `config/runtime.exs` for FLAME backends (Local/K8s).

### 🌊 Stream Zeta: Integration & Homeostasis (P1)
*   **Focus**: Wiring & Feedback.
*   **Agent**: Systems Integrator.
*   **Scope**:
    *   Connect OODA Actor to FLAME scaler.
    *   Connect OODA Observer to Sentinel status.
    *   Verify system-wide homeostasis via Telemetry.

## 4.0 ⚡ ACTION (5-Level Execution Plan)

### 40.0 - Autonomic Core Activation (P0)
**Status**: pending | **Owner**: Executive Director

#### 40.1 - Stream Delta: Sentinel Hardening (P0)
**Goal**: Enforce `ClusterQuorum` invariants.

*   **40.1.1 - Sentinel State Refactor**
    *   *Spec*: Align `Sentinel.ex` struct with `Sentinel.qnt` (`clusterState`, `partitionedNodes`).
    *   *Action*: Implement `handle_info({:nodedown, ...})` with strict quorum checking.
*   **40.1.2 - Apoptosis Protocol**
    *   *Spec*: `intentionalLeave` action from Quint.
    *   *Action*: Trigger `System.stop/1` if `QuorumLost` persists > 5s.

#### 40.2 - Stream Epsilon: FLAME Activation (P0)
**Goal**: Enable verified elastic scaling.

*   **40.2.1 - FLAME Supervisor Config**
    *   *Action*: Define `Indrajaal.FLAME.Pools` with `intelligence`, `video`, `analytics` pools.
    *   *Action*: Add `FLAME.Pool` to `lib/indrajaal/application.ex`.
*   **40.2.2 - Backend Strategy**
    *   *Action*: Configure `FLAME.Backend.Local` for Dev/Test and `FLAME.K8sBackend` for Prod.

#### 40.3 - Stream Zeta: Cybernetic Integration (P1)
**Goal**: Close the control loop.

*   **40.3.1 - OODA-Sentinel Link**
    *   *Action*: Update `OODA.Observer` to read `Sentinel.get_status()`.
*   **40.3.2 - OODA-FLAME Link**
    *   *Action*: Update `OODA.Actor` to dispatch `FLAME.place_child/3` calls.

## 5.0 🛡️ SAFETY & CONSTRAINTS

*   **SC-AUTO-001**: **Supervisor Ordering**: Sentinel MUST start before FLAME to prevent runners joining a partitioned cluster.
*   **SC-AUTO-002**: **Identity Verification**: All FLAME runners MUST validate the parent node's Tailscale identity upon boot.
*   **SC-AUTO-003**: **Resource Bounds**: FLAME pools MUST have hard limits (`max: 10`) defined in config, matching `FLAME.qnt` constants.

## 6.0 🚀 KPI & METRICS

*   **Cluster Health**: 100% Quorum Uptime.
*   **Runner Latency**: < 500ms Spawn Time (Local).
*   **OODA Cycle**: < 1000ms Loop Latency.
*   **Verification**: 100% Alignment between `*.qnt` specs and `.ex` implementation.
