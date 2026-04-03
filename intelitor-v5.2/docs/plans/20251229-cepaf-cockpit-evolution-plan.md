# Implementation Plan: CEPAF & Cockpit Hyper-Evolution (v14.0)

**Date**: 20251229-1510 CEST
**Status**: DRAFT -> ACTIVE
**Focus**: CEPAF (Infrastructure) & Cockpit (Interface)
**Criticality**: 5-Level Complexity Scaling
**Author**: Gemini (Cybernetic Architect)

---

## Executive Summary

This plan operationalizes the "Deep Analysis (20251229-1500)" to transform CEPAF into a **Genetic Engine** and the Cockpit into a **Proprioceptive Neural Interface**. It is structured in 5 levels of increasing complexity and impact.

---

## Phase 1: Semiotic Standardization (The Grammar)
**Objective**: Transform CEPAF from scripts to a Type-Safe DSL using F#.
**Timeline**: Sprint 1-2
**Complexity**: Medium

### 1.0 - F# Computation Expressions [P1]
#### 1.1 - Define `Orchestrator` Builder
##### 1.1.1 - Define Ops Types
-   `type Op = Deploy | Rollback | Scale | HealthCheck`
##### 1.1.2 - Implement `Bind` and `Return`
-   Create the `orchestrate { ... }` computation expression in `lib/cepaf/OrchestratorDSL.fs`.
-   Enforce strict state transitions (e.g., cannot `Scale` if `HealthCheck` fails).

### 1.1 - Resource Grammar
#### 1.2.1 - Manifest Definition
-   Define `Infrastructure.fs` types for `Container`, `Network`, `Volume` that map strictly to NixOS/Podman constraints.

---

## Phase 2: Proprioceptive Visualization (The Senses)
**Objective**: Upgrade Cockpit to visualize Entropy and System Flow.
**Timeline**: Sprint 3-4
**Complexity**: High

### 2.0 - Entropy Heatmaps [P2]
#### 2.1 - Backend Metrics
##### 2.1.1 - Shannon Calculator
-   Implement `Indrajaal.Analytics.Entropy` to calculate $H(x) = -Sum p(x) S p(x) S p(x)$ on log streams.
-   Stream results to `system_entropy` topic on Zenoh.

#### 2.2 - Frontend Visualization
##### 2.2.1 - Graph Integration
-   Integrate `D3.js` or `Cytoscape.js` into a LiveView Hook.
-   Render system nodes. Color intensity = Entropy value.

### 2.1 - Particle Flow (Bus Viz)
#### 2.3.1 - WebGL Canvas
-   Add a WebGL layer over the graph.
-   Emit particles for every message on the Unified Bus. Speed/Color = Message Type/Latency.

---

## Phase 3: Predictive Control (The Oracle)
**Objective**: Implement Kalman Filters for predictive resource scaling in CEPAF.
**Timeline**: Sprint 5-6
**Complexity**: Very High

### 3.0 - Kalman Filtering [P2]
#### 3.1 - F# Math Kernel
##### 3.1.1 - Matrix Operations
-   Use `Math.NET Numerics` in CEPAF.
-   Implement `KalmanFilter.predict(state, measurement)` for CPU/RAM usage.

#### 3.2 - Predictive Scaling Agent
##### 3.2.1 - Integration
-   Feed `podman stats` data into the filter.
-   If `predicted_state > threshold`, trigger `Scale` op *before* the threshold is breached.

---

## Phase 4: Genetic Optimization (The Evolution)
**Objective**: Automate the tuning of infrastructure parameters via Genetic Algorithms.
**Timeline**: Sprint 7-8
**Complexity**: Extreme

### 4.0 - The CEPAF Breeder [P3]
#### 4.1 - Genome Definition
##### 4.1.1 - Parameters
-   Define mutable parameters: `BEAM Schedulers`, `Ecto Pool Size`, `Buffer Sizes`.
-   Create `Genome` record type in F#.

#### 4.2 - Evolution Loop
##### 4.2.1 - Fitness Function
-   $Fitness = rac{Throughput}{Latency 	imes ResourceCost}$.
##### 4.2.2 - Selection & Crossover
-   Run benchmark (Satellite).
-   Select top 2 configurations.
-   Crossover/Mutate parameters.
-   Deploy new generation to Staging.

---

## Phase 5: The Neural Link (The Symbiosis)
**Objective**: Full Generative UI and "Demon" Filtering.
**Timeline**: Sprint 9+
**Complexity**: Maximum

### 5.0 - Maxwell's Demon [P3]
#### 5.1 - Intelligent Log Filtering
##### 5.1.1 - AI Classifier
-   Train a lightweight classifier to score logs by "Information Gain".
-   Cockpit only displays logs with Score > Threshold by default.

### 5.1 - Generative Control Interface
#### 5.2.1 - Intent Parser
-   Connect the "Command Bar" in Cockpit to the Cortex.
-   Map Natural Language -> CEPAF DSL Ops.
-   "Reset the dev environment and show me error logs" ->
    `orchestrate { reset "dev"; show_logs "error" }`.

---

## Implementation Matrix

| ID | Task | Criticality | Layer | Technology |
|----|------|-------------|-------|------------|
| 1.0 | F# Orchestrator DSL | P1 | Semiotic | F# / .NET |
| 2.0 | Entropy Heatmaps | P2 | Sensory | Elixir / JS |
| 3.0 | Kalman Auto-Scale | P2 | Control | F# / Math.NET |
| 4.0 | Genetic Optimization | P3 | Evolutionary | F# |
| 5.0 | Generative UI | P3 | Cognitive | Elixir / AI |

---

## Next Steps

1.  **CEPAF**: Create `lib/cepaf/OrchestratorDSL.fs` prototype.
2.  **Cockpit**: Install `D3.js` assets and create a basic graph LiveView.
3.  **Math**: Add `Math.NET` to `lib/cepaf` dependencies.
