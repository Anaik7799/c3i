# Phase 4 Implementation Plan: Directed Telescope & Bicameral Cortex (7-Level)

**Date**: 2026-01-07 12:45 CEST
**Status**: APPROVED | **Context**: SIL-6 Biomorphic Fractal Mesh
**Target**: OODA Latency < 10ms, System Viability Index (SVI) > 0.8

## Executive Summary
This plan details the execution of Phase 4 using a 7-level fractal decomposition. It focuses on standing up the `indrajaal-cortex` (F#) service, establishing the Zenoh bridge, and activating the evolutionary "Directed Telescope."

---

## 7-Level Implementation Hierarchy

### Level 1: Strategic (The Goal)
**31.1.4.0.0.0.0 - Establish Evolutionary Self-Awareness (Phase 4)**
*   **Criticality**: **P0 (CRITICAL)** - Essential for long-term SIL-6 compliance.
*   **Objective**: Transition from Homeostasis to Teleology.
*   **Success Criteria**: `indrajaal-cortex` service running, `0xEV01` pulse active, SVI metric visible.

### Level 2: Architectural (The Topology)
**31.1.4.1.0.0.0 - Materialize the Cognitive Plane (Cortex Service)**
*   **Criticality**: **P0** - Infrastructure prerequisite.
*   **Objective**: Deploy the F#/.NET 10 Worker Service container alongside the Elixir App.

**31.1.4.2.0.0.0 - Innervate the Somatic Bridge (Zenoh Mesh)**
*   **Criticality**: **P0** - Communication prerequisite.
*   **Objective**: Establish high-speed, low-latency IPC between Elixir (Body) and F# (Brain).

### Level 3: Holonic (The Components)
**31.1.4.3.0.0.0 - Implement the "Founder's Directive" Governor**
*   **Criticality**: **P1 (HIGH)** - Safety logic.
*   **Objective**: Encode the immutable safety axioms into the F# binary.

**31.1.4.4.0.0.0 - Activate the "Directed Telescope" Scanner**
*   **Criticality**: **P1** - Observability logic.
*   **Objective**: Implement the periodic "Deep Breath" scan for entropy calculation.

### Level 4: Operational (The Workflow)
**31.1.4.1.1.0.0 - Cortex Service Scaffolding**
*   **Criticality**: **P0**
*   **Activity**: Create .NET solution, Dockerfile, and Compose entry.

**31.1.4.2.1.0.0 - Elixir Zenoh Bridge Implementation**
*   **Criticality**: **P0**
*   **Activity**: Implement `Indrajaal.Bridge.Cortex` GenServer.

**31.1.4.2.2.0.0 - F# Zenoh Adapter Implementation**
*   **Criticality**: **P0**
*   **Activity**: Implement `Cepaf.Zenoh.Adapter` in .NET.

### Level 5: Implementation (The Tasks)
**31.1.4.1.1.1.0 - Initialize .NET 10 Worker Service**
*   **Criticality**: P0
*   **Detail**: `dotnet new worker -n Indrajaal.Cortex`

**31.1.4.1.1.2.0 - Containerize Cortex**
*   **Criticality**: P0
*   **Detail**: Create `Dockerfile.cortex` (Multi-stage build).

**31.1.4.1.1.3.0 - Update Orchestration**
*   **Criticality**: P0
*   **Detail**: Add `cortex` service to `podman-compose.yml`.

**31.1.4.2.1.1.0 - Add Zenoh Dependency (Elixir)**
*   **Criticality**: P0
*   **Detail**: Add `zenohex` to `mix.exs`.

**31.1.4.2.2.1.0 - Add Zenoh Dependency (F#)**
*   **Criticality**: P0
*   **Detail**: Add `Zenoh.Net` via NuGet.

### Level 6: Atomic (The Steps)
**31.1.4.1.1.1.1 - Create Solution Structure**
*   **Criticality**: P1
*   **Command**: `mkdir -p lib/cortex && cd lib/cortex && dotnet new sln`

**31.1.4.1.1.2.1 - Write Dockerfile**
*   **Criticality**: P0
*   **Command**: `write_file Dockerfile.cortex` (Optimized for size).

**31.1.4.3.1.1.1 - Port RuntimeTestOrchestrator Logic**
*   **Criticality**: P1
*   **Action**: Refactor `RuntimeTestOrchestrator.fsx` into `Indrajaal.Cortex.Orchestration.dll`.

### Level 7: Sub-Atomic (The Code/Commands)
**31.1.4.1.1.1.1.1 - Execute Scaffold Command**
*   **Criticality**: P0
*   **Code**: `dotnet new worker -n Indrajaal.Cortex -o lib/cortex/src/Indrajaal.Cortex`

**31.1.4.2.1.1.1.1 - Configure Mix Deps**
*   **Criticality**: P0
*   **Code**: `{:zenohex, "~> 0.1"}` in `mix.exs`

---

## Criticality Analysis Summary

| Level | Criticality | Justification |
| :--- | :--- | :--- |
| **Infrastructure (Cortex)** | **P0 (CRITICAL)** | Without the Cortex container, Phase 4 cannot exist. It is the physical substrate for the new logic. |
| **Connectivity (Zenoh)** | **P0 (CRITICAL)** | Without the bridge, the Brain is disconnected from the Body. System is paralyzed. |
| **Safety Logic (Directive)** | **P1 (HIGH)** | Essential for SIL-6, but the system can technically *run* (unsafely) without it during dev. |
| **Metrics (Telescope)** | **P2 (MEDIUM)** | Telemetry is valuable but not blocking for the initial "Skeleton" boot. |

## Execution Sequence (Critical Path)

1.  **SCAFFOLD** (L5: 31.1.4.1.1.1.0) -> Create the .NET project.
2.  **CONTAINERIZE** (L5: 31.1.4.1.1.2.0) -> Dockerfile creation.
3.  **ORCHESTRATE** (L5: 31.1.4.1.1.3.0) -> Podman Compose update.
4.  **CONNECT** (L5: 31.1.4.2.*) -> Establish Zenoh link.
5.  **ACTIVATE** (L5: 31.1.4.3.*) -> Deploy "Founder's Directive".
