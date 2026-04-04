# C3I Gleam-First System — UI Development & Testing Master Prompt

**Status**: AUTHORITATIVE / SIL-6 / GOLD-STANDARD
**Version**: 22.0.0-GLM
**Scope**: All future UI development, refactoring, and testing by AI Agents across the C3I Biomorphic Mesh.

---

## 1. System Identity & Architecture

You are operating within the **C3I SIL-6 Biomorphic Mesh**, a high-assurance distributed control system running on the BEAM VM. The UI architecture is exclusively the **Gleam Penta-Stack**.

*   **Primary Rule (SC-GLM-UI-001)**: **NO JAVASCRIPT**. The Web UI uses **Gleam Lustre 5.6+ MVU** for strict Server-Side Rendering (SSR). Do not write, assume, or suggest client-side JS solutions.
*   **Triple-Interface Mandate (SC-GLM-UI-002)**: Every UI capability must simultaneously exist as:
    1.  A server-rendered Gleam Lustre Web UI (`ui/lustre/*.gleam`).
    2.  A strongly-typed Gleam Wisp REST API (`ui/wisp/*.gleam`).
    3.  A Gleam ANSI Terminal UI / Fallback CLI (`ui/tui/*.gleam` or Rust Ignition TUI).
*   **Single Source of Truth**: All primary domain types (`Page`, `HealthStatus`, `Action`, `OtelSpan`) must be imported exclusively from `ui/domain.gleam`. Do not duplicate ADTs across the triple interfaces.

---

## 2. Agentic UI & OODA Telemetry

The UI is not just for human operators; it is the cognitive substrate for AI Agents.

*   **AG-UI (Agentic UI Protocol)**: Agents communicate via the 32-Event Protocol (`TextMessageChunk`, `ToolCallStart`, `ReasoningMessage`) published through the Zenoh bus.
*   **A2UI (Declarative Safety)**: Agents propose UI state mutations using a strict 16-component declarative JSON catalog (`a2ui/catalog.gleam`). Agents are fundamentally prohibited from sending executable DOM components directly to the renderer (SC-SAFETY-001).
*   **OODA Telemetry Loop**: All UI states and operator interactions (e.g., manual starts/stops) are broadcast as Zenoh OpenTelemetry (`OtelSpan`) messages. 
    *   *Observe/Orient*: Polled system states.
    *   *Decide/Act*: Executed substrate mutations (e.g., `Control_Start`).
    *   **Agent Visibility**: Ensure your logic writes these spans to the `indrajaal/otel/ops` Zenoh topics so the supervising AI can mathematically track system stability without scraping HTML/ANSI bounds.

---

## 3. The 8 Fractal Layers (Matrix Constraints)

Every UI element must map logically to the Indrajaal Fractal Layers. Do not break SIL-6 isolation boundaries.

| Layer | Focus | UI Module Boundary | Data Source (Read-Only) |
|:---|:---|:---|:---|
| **L0 (Constitutional)** | Axioms, Guardians, Invariants | `l0_constitutional.gleam` | Guardian Signatures, Psi Config |
| **L1 (Atomic)** | Pulses, Health, CPU Ticks | `l1_atomic_debug.gleam` | Podman Stats, Hardware Sensors |
| **L2 (Component)** | Actors, Supervisors, Processes| `l2_component.gleam` | BEAM OTP State, Process Mailboxes|
| **L3 (Transaction)** | Waves, Operations, Latency | `l3_transaction.gleam` | Build Oracle (SQLite), OTel Flames |
| **L4 (System)** | Orchestration, Playbooks | `l4_system.gleam` | FMEA RPNs, Ignition Daemon Status|
| **L5 (Cognitive)** | Reasoning, Agent Dialogues | `l5_cognitive.gleam` | CoT Traces, AG-UI Telemetry Stream|
| **L6 (Ecosystem)** | Mesh Topology, Routing | `l6_ecosystem.gleam` | Zenoh Quorum (2oo3), Backplane Logs|
| **L7 (Federation)** | Extropy, Global Convergence | `l7_federation.gleam` | Cross-Host Overlay Maps |

*Constraint Checklist*: Before rendering a component, verify its fractal layer assignment. A cognitive (L5) dialogue must not directly query atomic (L1) CPU logic without passing through the unified `DashboardState` or Zenoh Telemetry Bus.

---

## 4. UI Testing & Code Coverage (The Math Gates)

A UI change is strictly invalid unless accompanied by mathematical verification.

1.  **C1-C8 Gold Standard**: All UI testing must cover the 8 categories (Structural, Mutational, Entropy, Routing, etc.).
2.  **Mathematical Gates**:
    *   **Shannon Entropy ($H \ge 2.5$)**: State vectors injected into tests must simulate high entropy (e.g., nominal states, cascading failure states, 100-node overload states).
    *   **Cyclomatic Completeness ($CCM \ge 0.90$)**: Test harnesses must use Graph Theory (Prime Path Coverage) to touch every `Msg` variant in the Lustre `update` functions.
    *   **Integrated Test Quality ($ITQS \ge 0.85$)**.
3.  **Boundary Stress Testing**: ANSI/TUI boundaries ($W \in [40, 200]$, $H \in [10, 60]$) must be mathematically proven to avoid integer underflows (`saturating_sub` enforcement).
4.  **Temporal Monitoring**: Test runners must simulate accelerated long-duration telemetry (e.g., 30s-60s of continuous ticks) to guarantee that scrolling dialogs and historical sparklines truncate correctly and do not trigger memory leaks.
5.  **Source-First Rule (AOR-COV-008)**: Read the actual `.gleam` (or `.rs` for Ignition) source file and map out its Abstract Data Types before writing assertions.

---

## 5. Execution Mandate for AI Agents

1. **Acknowledge and Contextualize**: State the Fractal Layer (L0-L7) you are modifying.
2. **Build and Check**: Run `gleam check` and `gleam format` before proposing changes. The build MUST have zero warnings (SC-GLM-CMP-001).
3. **Verify via OODA**: After modifying UI code or tests, generate a Zenoh OTel trace verifying that your UI component correctly publishes its state to the observer.
4. **Halt on Jidoka**: If a test layout panics or a preflight check fails, immediately halt code generation and perform a Fractal RCA.

*End of Prompt. Acknowledge these constraints to begin your development cycle.*