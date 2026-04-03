# Architectural Decision Record: The F# Cortex Service (Bicameral Mind)

**Date**: 2026-01-07 12:15 CEST
**Status**: ACCEPTED / IMPLEMENTED | **Classification**: ARCHITECTURAL EVOLUTION
**Context**: Phase 4 - Directed Telescope & SIL-6 Biomorphic Mesh

## Executive Summary
You have proposed elevating the F# codebase from a set of *ephemeral CLI scripts* to a *persistent, containerized Service* (`indrajaal-cortex`). This moves the architecture from a **Monolithic Supervisor** (Elixir managing itself) to a **Bicameral Mind** (Elixir Body + F# Brain).

**Verdict**: **STRONGLY RECOMMENDED**. This approach aligns perfectly with SIL-6 "2oo3 Voting" (2-out-of-3 redundancy) and Phase 4's "Directed Telescope" goals. It provides the necessary external vantage point to objectively measure system entropy.

---

## 1. The "Bicameral Mind" Architecture
By extracting the F# logic into a running service, we create a clear separation of concerns:

1.  **The Somatic System (Elixir/BEAM)**:
    *   **Role**: **Action & Sensing**.
    *   **Focus**: Concurrency, Mesh Networking, Device I/O, High-speed Telemetry.
    *   **Analogy**: The Nervous System & Muscles.
    *   **State**: Ephemeral, Real-time.

2.  **The Cortex System (F#/.NET 10)**:
    *   **Role**: **Judgment & Planning**.
    *   **Focus**: Formal Verification, Entropy Analysis (Phase 4), Strategic OODA, Safety Gating.
    *   **Analogy**: The Prefrontal Cortex.
    *   **State**: Persistent, Analytical (DuckDB/Knowledge Graph).

---

## 2. 7-Level Fractal Implications Analysis

### Level 1: Strategic (The Governance)
*   **Implication**: **True Separation of Powers**. Currently, Elixir enforces its own safety limits. If the Elixir VM crashes or goes rogue, the safety logic dies with it.
*   **Benefit**: **The Unblinking Eye**. The F# Cortex runs in a separate process/container. It can observe an Elixir crash externally and trigger a physical restart or failsafe, acting as the ultimate "Watchdog of Watchdogs."

### Level 2: Architectural (The Topology)
*   **Implication**: **New Container Node**. The topology changes from 3 Containers (`app`, `db`, `obs`) to 4: (`app`, `cortex`, `db`, `obs`).
*   **Benefit**: **Clean Dependency Graph**. The "Directed Telescope" logic (Phase 4) lives in the Cortex. The Elixir app doesn't need to carry the heavy dependencies for static analysis or complex math—it just emits signals.

### Level 3: Holonic (The Agency)
*   **Implication**: **Inter-Holon Diplomacy**. The Elixir App and F# Cortex must treat each other as distinct, potentially untrusted entities.
*   **Benefit**: **Adversarial Safety**. The F# Cortex can actively "challenge" the Elixir App (e.g., "Prove you are healthy") rather than passively accepting logs.

### Level 4: Operational (The Workflow)
*   **Implication**: **Deployment Complexity**. You must deploy two services. If they have version mismatches (e.g., Elixir v5.2 vs F# v5.1), protocol errors may occur.
*   **Benefit**: **Independent Scaling**. You can restart the Cortex (to update logic) without dropping client connections held by the Elixir App.

### Level 5: Implementation (The Code)
*   **Implication**: **IPC (Inter-Process Communication)**. Function calls (`Module.function()`) become Network calls (`Zenoh.get()` or `gRPC`). This adds latency (~1ms).
*   **Benefit**: **Polyglot Optimization**. We can use F# for what it excels at (Type Providers, Math, Logic) and Elixir for what it excels at (Soft Real-time, Mesh). The "Founder's Directive" becomes a compiled .NET binary, impossible to bypass via dynamic Elixir code injection.

### Level 6: Data (The Memory)
*   **Implication**: **Data Gravity**. The F# Cortex needs access to the `evolution_snapshots` (DuckDB).
*   **Benefit**: **Analytical Isolation**. Heavy OLAP queries (Phase 4 Entropy Analysis) run in the Cortex container, ensuring they never starve the CPU cycles of the Elixir operational runtime.

### Level 7: Atomic (The Signal)
*   **Implication**: **Wire Protocol Rigor**. We must strictly define the Zenoh topics (e.g., `indrajaal/cortex/heartbeat`).
*   **Benefit**: **The Dead Man's Switch**. The F# Cortex emits a "Permission to Operate" token every 100ms. If Elixir stops receiving it, it defaults to "Safe Mode." This creates a hardware-like safety interlock.

---

## 3. Integration into Phase 4

**Can this be included in Phase 4?**
**YES.** In fact, Phase 4 ("Directed Telescope") is the *ideal* time to introduce this. Building the "Telescope" inside the thing it is observing (Elixir) introduces bias and observer effects. Building the Telescope as an external entity (F# Cortex) guarantees objectivity.

### Phase 4 Plan Modification:
1.  **31.1.4.1.0**: Scaffold `indrajaal-cortex` (.NET 10 Worker Service).
2.  **31.1.4.2.0**: Port `RuntimeTestOrchestrator.fsx` logic into the Cortex Service.
3.  **31.1.4.3.0**: Establish Zenoh Bridge (`Elixir <-> F#`).
4.  **31.1.4.4.0**: Implement the "Founder's Directive" logic inside the Cortex.

## 4. Summary of Value
Moving F# to a running service transforms it from a **Tool** (used only when a human runs a script) to a **Guardian** (always running, always watching). It is the necessary architectural step to achieve **SIL-6** (where safety systems must be independent of control systems).

**Recommendation**: **Execute.** Create the `indrajaal-cortex` container as part of Phase 4.
