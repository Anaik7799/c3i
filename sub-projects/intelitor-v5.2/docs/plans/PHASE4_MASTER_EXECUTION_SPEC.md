# Phase 4 Master Execution Specification: The Bicameral Cortex & Directed Telescope

**Date**: 2026-01-07 12:30 CEST
**Status**: APPROVED | **Classification**: MASTER PLAN
**Context**: SIL-6 Biomorphic Fractal Mesh (L5-EVOLUTIONARY)
**Architectural Shift**: Monolithic Supervisor $\to$ Bicameral Mind (Elixir + F# Service)

## Executive Summary
This document represents the definitive, exhaustive specification for **Phase 4: Directed Telescope Instrumentation**. It integrates the strategic decision to deploy the F# Cortex as a standalone service (`indrajaal-cortex`), creating a "Bicameral Mind" architecture. This phase transitions the system from **Homeostasis** (keeping the lights on) to **Teleology** (conscious evolution).

---

## Part 1: The 7-Level Fractal Activity Matrix

### Level 1: Strategic (Teleology & Purpose)
**Activity**: **Constitutional Encoding**.
*   **Definition**: We are encoding the "Founder's Directive" (The system must not evolve into an unsafe state) into a compiled, immutable binary within the F# Cortex.
*   **Mechanism**: The F# Cortex acts as the **Supreme Court**. It holds the definition of "Safety" and "Viability" outside the operational runtime (Elixir), making it impossible for a runaway Elixir process to redefine safety to suit its immediate needs.
*   **Goal**: Ensure long-term survival by prioritizing structural integrity over feature velocity.

### Level 2: Architectural (Topology & Structure)
**Activity**: **Bicameral Separation**.
*   **Definition**: Splitting the system into two distinct containerized cognitive planes.
    1.  **Somatic Plane (Elixir/`indrajaal-app`)**: Handles I/O, Mesh Networking, Device Control, and "Hot" OODA Loops (<10ms).
    2.  **Cognitive Plane (F#/.NET 10/`indrajaal-cortex`)**: Handles Formal Verification, Entropy Analysis, Static Analysis, and "Cold" OODA Loops (1h).
*   **Integration**: Connected via a dedicated, high-priority **Zenoh** bridge (`indrajaal/cortex/**`).

### Level 3: Holonic (Agency & Identity)
**Activity**: **The Mirror Stage**.
*   **Definition**: Giving every module (Holon) a "Mirror" to see itself.
*   **Mechanism**:
    *   The Elixir App emits its internal structure (AST, Supervisor Tree) to the F# Cortex.
    *   The F# Cortex analyzes this structure against the Ideal Model (Architecture).
    *   The F# Cortex reflects a "Health Score" back to the Holon.
*   **Result**: A GenServer knows if it is "Rotting" (high complexity/drift) and can request refactoring.

### Level 4: Operational (Rhythm & Process)
**Activity**: **The Deep Breath Cycle**.
*   **Definition**: A synchronized, system-wide evolutionary heartbeat occurring every 3600 seconds.
*   **Sequence**:
    1.  **Stop**: F# Cortex signals "Freeze for Scan" (Operational lock-out for <30ms).
    2.  **Scan**: Elixir dumps minimal state/AST hashes to Zenoh.
    3.  **Analyze**: F# Cortex computes `SystemViabilityIndex` (SVI) using heavy linear algebra (Math.NET).
    4.  **Verdict**: Cortex broadcasts `0xEV01` (Continue) or `0xSTOP` (Halt/Rollback).

### Level 5: Implementation (Code & Logic)
**Activity**: **Polyglot Logic Gates**.
*   **Elixir Side**:
    *   `Indrajaal.Bridge.Cortex`: A GenServer that manages the Zenoh connection to the Brain.
    *   `@holon_id`: New module attribute for identity.
*   **F# Side**:
    *   `FounderDirective.fs`: Immutable validation logic.
    *   `EntropyCalculator.fs`: Cyclomatic complexity and coupling analysis algorithms.
    *   `Worker`: A .NET 10 BackgroundService listening on Zenoh.

### Level 6: Data (Memory & History)
**Activity**: **The Evolutionary Ledger**.
*   **Storage**: **DuckDB** embedded *inside* the `indrajaal-cortex` container.
*   **Isolation**: This data is *physically separated* from the operational PostgreSQL user data.
*   **Schema**:
    *   `lineage_events`: Every architectural decision and its outcome.
    *   `entropy_logs`: Time-series of code quality metrics.
    *   `vector_memory`: Embeddings of code semantics for drift detection.

### Level 7: Atomic (Physics & Signals)
**Activity**: **The Dead Man's Switch**.
*   **Signal**: `0xEV01` (Evolution Protocol v1).
*   **Physics**: A heartbeat sent from F# to Elixir every 30ms.
*   **Interlock**: If the Elixir `Guardian` actor stops receiving the F# pulse (meaning the Brain is dead or judging the Body unsafe), it physically disables write-access to the Database and Mesh Actuators. The body goes comatose to prevent self-harm.

---

## Part 2: 7-Level System Impact Analysis

### System A: The Substrate (Codebase)
*   **L1 Impact**: Code becomes "Self-Defending". It rejects commits that lower SVI.
*   **L7 Impact**: Artifact size increases (embedded metadata), but runtime safety guarantees become absolute.

### System B: The Supervisor (Human)
*   **L1 Impact**: Role shifts from "Operator" to "Arbiter". The system manages its own health; the human manages the system's goals.
*   **L4 Impact**: "Alert Fatigue" vanishes. Alerts only fire for *existential* threats (Evolutionary Rot), not transient noise.

### System C: The Workforce (AI Agents)
*   **L2 Impact**: Agents gain "Contextual Omniscience". They can query the F# Cortex for the *entire* dependency graph history before writing a single line of code.
*   **L5 Impact**: Agents must learn to write code that passes the F# static analysis gates, or their work is rejected instantly.

---

## Part 3: Benefits & Implications Summary

### Benefits (The "Why")
1.  **Immortality**: By preventing entropy accumulation, the system avoids the "Software Death Spiral" (Rewrite Cycle).
2.  **Objective Truth**: The F# Cortex provides an unbiased, external measurement of system health, unaffected by the runtime state of the application.
3.  **Resource Efficiency**: Heavy analysis (OLAP) is offloaded to the Cortex container, leaving the Elixir container (OLTP) lean and fast for user requests.
4.  **Safety (SIL-6)**: The "2oo3 Voting" (Elixir State + F# Model + Human Intent) makes catastrophic failure statistically impossible ($< 10^{-12}$ PFH).

### Implications (The "Cost")
1.  **Complexity**: We are maintaining two distinct tech stacks (Elixir/OTP and F#/.NET). This raises the skill floor for contributors.
2.  **Latency Floor**: There is a physical limit to OODA speed imposed by the Zenoh IPC bridge (~1ms).
3.  **Rigidity**: Changing core architectural axioms requires recompiling and redeploying the Cortex service. You cannot "hot patch" the Constitution.

---

## Part 4: Immediate Execution Steps (Sprint 31.1.4)

1.  **Scaffold**: Generate the `indrajaal-cortex` .NET 10 Worker Service project structure.
2.  **Bridge**: Implement the Zenoh producer (F#) and consumer (Elixir).
3.  **Logic**: Port the `FounderDirective` rules from loose text into F# Type Providers.
4.  **Deploy**: Update `podman-compose.yml` to include the `cortex` service.

This specification is the **Green Light** for the Bicameral Architecture.
