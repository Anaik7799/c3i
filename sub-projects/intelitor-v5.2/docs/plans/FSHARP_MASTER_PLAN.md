# F# Master Plan: CEPAF, Prajna & Cockpit (The Plasma Engine)

**Date**: 2026-01-02T23:59:00+01:00
**Author**: Cybernetic Architect (Gemini)
**Status**: Strategic Roadmap
**Technology**: F# (.NET 10.0), Zenoh, DuckDB
**Objective**: To implement the High-Assurance/High-Performance "Plasma Engine" (CEPAF#) and the "Frozen Core" Cockpit.

## 1. Executive Summary

While Elixir (Indrajaal) manages the **Runtime** and **OODA Loop** (The Nervous System), F# (CEPAF) manages the **Infrastructure**, **Heavy Ingestion**, and **Safety Verification** (The Skeleton & Muscles).

This plan defines the F# implementation for:
1.  **CEPAF**: The Cybernetic Execution & Performance Architecture Framework.
2.  **Prajna#**: The Cognitive Backend (Knowledge Graph ingestion).
3.  **Cockpit#**: The "Frozen Core" Emergency TUI (Terminal UI).

---

## 2. 5-Level Implementation Plan

### L5: CEPAF# CORE (The Infrastructure Engine)
**Goal**: Safe, statically typed orchestration of the underlying OS/Substrate.

#### L5.1: Container Orchestration (The Podman Wrapper)
*   **Module**: `Cepaf.Podman`
*   **Function**: Strongly typed wrapper around `podman` CLI/API.
*   **Safety**: Validates container specs against STAMP constraints *before* execution.
*   **Tasks**:
    *   Implement `Podman.run_verified(spec)`
    *   Implement `Podman.health_check(id)`

#### L5.2: Formal Verification Runner
*   **Module**: `Cepaf.Verification`
*   **Function**: Runs Quint/Agda checks as part of the build/deploy cycle.
*   **Tasks**:
    *   Implement `Quint.verify(model_path)`
    *   Implement `Agda.check(proof_path)`

### L4: PRAJNA# (The Cognitive Backend)
**Goal**: High-throughput knowledge ingestion and vector management.

#### L4.1: Knowledge Engine (IKE-F#)
*   **Module**: `Cepaf.Knowledge`
*   **Function**: Bulk ingestion of logs/metrics into DuckDB.
*   **Why F#?**: Performance (structs, spans) and Type Safety for schema mapping.
*   **Tasks**:
    *   Implement `DuckDB.bulk_insert(stream)`
    *   Implement `Schema.validate(data)`

#### L4.2: Context Manager
*   **Module**: `Cepaf.Prajna.Context`
*   **Function**: Manages the "Long Term Memory" context window for the AI.
*   **Tasks**:
    *   Implement `Context.prune(strategy)`
    *   Implement `Context.summarize(text)`

### L3: COCKPIT# (The Frozen Core)
**Goal**: A standalone, static binary TUI for emergency control when the BEAM is down.

#### L3.1: Terminal UI
*   **Module**: `Cepaf.Cockpit`
*   **Tech**: `Terminal.Gui` (or Spectre.Console).
*   **Function**:
    *   View System Status (via Zenoh/Files).
    *   Emergency Restart (Indrajaal).
    *   View Immutable Register (DuckDB).
*   **Tasks**:
    *   Implement `MainView` (Dashboard).
    *   Implement `EmergencyPanel` (Actions).

### L2: THE BRIDGE (Zenoh Integration)
**Goal**: Seamless communication with Elixir.

#### L2.1: Zenoh Subscriber
*   **Module**: `Cepaf.Bridge.Zenoh`
*   **Function**: Subscribes to `indrajaal/**` for state updates.
*   **Tasks**:
    *   Bind Rust Zenoh via C-Interop or use .NET binding.
    *   Expose `Stream<Message>` to F# actors.

### L1: THE TYPE SYSTEM (The Shared Truth)
**Goal**: Shared types between Elixir (specs) and F# (implementation).

#### L1.1: Shared Schema Definition
*   **Module**: `Cepaf.Core.Types`
*   **Function**: Defines `Holon`, `Metric`, `Threat`, `Action` types.
*   **Constraint**: Must match Elixir Ecto schemas (verified by tests).

---

## 3. Integration Strategy

### 3.1 The "Sidecar" Model
CEPAF# runs as a **Sidecar Process** to the Elixir Node.
*   **Communication**: Zenoh (Fast), DuckDB (State), Localhost HTTP (Control).
*   **Lifecycle**: Supervised by `Indrajaal` (Elixir starts F# binary).

### 3.2 The "Emergency" Model
If Elixir dies, **Systemd** restarts CEPAF# in "Emergency Mode".
*   **Cockpit#** becomes the primary interface.
*   **Objective**: Restore the Holon.

---

## 4. Implementation Roadmap (Sprint 31/32)

### Phase 1: Core & Podman (Sprint 31)
*   Refine `Cepaf.Podman` to be STAMP-compliant.
*   Implement `Cepaf.Verification` for Quint runner.

### Phase 2: Knowledge & Bridge (Sprint 31)
*   Implement `Cepaf.Knowledge` (DuckDB).
*   Establish Zenoh Bridge.

### Phase 3: Cockpit# (Sprint 32)
*   Build the TUI for emergency control.
*   "The Black Box Recorder" - visible even in crash state.

---

*This plan establishes F# as the "Indestructible Skeleton" supporting the "Elixir Nervous System".*
