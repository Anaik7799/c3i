# PRAJNA MASTER VERIFICATION PLAN: FULL SYSTEM CONVERGENCE
**Classification**: LEVEL 1 VERIFICATION
**Status**: ACTIVE
**Target**: 100% F# Substrate (Prajna, Chaya, Smriti)
**Date**: 2026-01-15

---

## 1.0 OBJECTIVE
To perform a **Full System Check** of the unified Indrajaal architecture, validating the complete migration to the F# substrate. This includes **Prajna** (The Interface), **Chaya** (The Digital Twin), and **Smriti** (The Memory), ensuring they operate as a cohesive, safety-critical organism.

**Constraint**: All CLI, GUI, and TUI components MUST be F#-based. No legacy Elixir UI components are permitted in the verification path.

---

## 2.0 THE 9x9 INTERACTION ANALYSIS (FRACTAL COVERAGE)
We will verify signal propagation across the 9 levels of the fractal hierarchy.

| Level | Verification Target | Test Method |
| :--- | :--- | :--- |
| **L1: Atomic** | F# Functions, Types, Units | `Expecto` Unit Tests |
| **L2: Component** | Agents (Orchestrator, Synapse) | Agent Lifecycle Check |
| **L3: Holon** | Digital Twin (Chaya) State | OODA Loop Latency Test |
| **L4: Container** | Podman Resources | Resource Limit Verification |
| **L5: Node** | Persistence (SQLite/DuckDB) | ACID Transaction Test |
| **L6: Mesh** | Zenoh Consensus (Smriti) | Pub/Sub Consistency Check |
| **L7: Federation** | Knowledge Graph | Entropy/Drift Calculation |
| **L8: Ecosystem** | External API (OpenRouter) | Neuro-Symbolic Handshake |
| **L9: Universe** | Long-Term Archive (Ark) | *Simulated Ark Export* |

---

## 3.0 COMPONENT VERIFICATION STRATEGY

### 3.1 PRAJNA (The Interface)
*   **CLI**: Verify `dotnet run -- --help` and specific commands (`--phase3-verify`).
*   **TUI**: Verify `Spectre.Console` rendering of the "Panopticon" dashboard.
*   **GUI**: Verify `Avalonia` view models (Headless/Simulated for CI environment).

### 3.2 CHAYA (The Digital Twin)
*   **OODA Loop**: Verify the Observe-Orient-Decide-Act cycle completes < 100ms.
*   **Self-Healing**: Verify `Guardian` vetoes unsafe ops and `Synapse` suggests fixes.

### 3.3 SMRITI (The Memory)
*   **Hydration**: Verify `SmritiSubscriber` correctly populates local state from Zenoh.
*   **Consistency**: Verify state updates are broadcast and reflected.

---

## 4.0 BDD SCENARIOS (prajna_system.feature)

```gherkin
Feature: Full System Convergence

  Scenario: The Awakening (System Boot)
    Given the F# runtime is initialized
    And the Zenoh mesh is active
    When the Orchestrator starts the "Chaya" digital twin
    Then the "Smriti" memory should be hydrated from the mesh
    And the "Prajna" dashboard should display "System Online"

  Scenario: Neuro-Symbolic Safety (Simplex)
    Given the system is in "Shadow Mode"
    When the "Synapse" AI proposes a "Destructive Action" (rm -rf)
    Then the "Guardian" safety kernel should VETO the proposal
    And the event should be logged to "Smriti" audit trails

  Scenario: 9-Level Fractal Coherence
    When a signal is injected at L1 (Atomic Function)
    Then it should be observable at L6 (Mesh Telemetry)
    And it should update the L7 (Knowledge Graph) entropy score
```

---

## 5.0 EXECUTION PLAN

1.  **Implement `FullSystemVerification.fs`**: A comprehensive F# script/module to run the 9x9 sweep.
2.  **Wire up CLI**: Add `--full-system-verify` flag.
3.  **Execute**: Run the verification.
4.  **Report**: Generate `FULL_SYSTEM_VERIFICATION_REPORT.md`.
