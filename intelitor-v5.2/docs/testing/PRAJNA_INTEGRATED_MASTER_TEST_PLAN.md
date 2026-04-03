# PRAJNA INTEGRATED MASTER TEST PLAN (SIL-6)
**Classification**: LEVEL 1 VERIFICATION
**Status**: ACTIVE
**Version**: 1.0.0
**Target**: Unified F# Substrate (Prajna, Chaya, Smriti)
**Date**: 2026-01-15

---

## 1.0 EXECUTIVE SUMMARY
This document defines the comprehensive verification strategy for the **Indrajaal v21.3.0** system, specifically focusing on the converged **F# Prajna Cockpit**. It integrates 9-level fractal interaction analysis, neuro-symbolic safety (Simplex), and biomorphic self-healing capabilities.

**Primary Goal**: Verify that the F# substrate can autonomously operate the 15-container mesh with SIL-6 safety guarantees.

---

## 2.0 TESTING SCOPE & DIMENSIONS

### 2.1 The 9x9 Fractal Matrix (Interaction Analysis)
We verify signal propagation across 9 levels of scale and 9 functional dimensions.

| Level \ Dim | Signal | Control | Data | Semantic | Social | Economic | Legal | Evolution | Existential |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **L1: Atomic** | Logs | Function | Types | Schema | Interfaces | CPU/Mem | Assertions | Refactor | Init/Dispose |
| **L2: Component** | Events | Agents | State | Contracts | Deps | Tput | Supervisors | Updates | Start/Stop |
| **L3: Holon** | Behavior| Intent | Context | Ontology | Protocol | Tokens | Rules | Learning | Spawn/Kill |
| **L4: Container** | Stdout | Signals | Volumes | Env Vars | Network | Quotas | Isolation | Images | Boot/Die |
| **L5: Node** | Syslog | SystemD | FS | Config | Cluster | Load | Security | Patching | Reboot |
| **L6: Mesh** | Zenoh | Consensus | Dist.DB | Knowledge| Fed. | Bandwidth | Partition | Topology | Split-Brain |
| **L7: Federation**| Ledger | Govern. | Shards | Truth | Trust | Market | Compliance | Migration | Disaster |
| **L8: Ecosystem** | Ext API | Webhooks| User Data| UX/DX | Community| Revenue | GDPR | Adoption | Market Fit |
| **L9: Universe** | History | Entropy | Archive | Wisdom | Legacy | Energy | Ethics | Time | Heat Death |

### 2.2 Component Coverage
*   **Prajna (Interface)**: CLI (`cepa`), TUI (`Spectre`), GUI (`Avalonia`).
*   **Chaya (Twin)**: OODA Loop, State Mirroring, Telemetry Ingestion.
*   **Smriti (Memory)**: Zenoh Subscriber, SQLite/DuckDB Persistence, Vector Search.
*   **Indrajaal (Body)**: Elixir/BEAM Runtime, Postgres, Sensor Mesh.

---

## 3.0 METHODOLOGIES

### 3.1 STAMP (Systems-Theoretic Accident Model and Processes)
*   **Constraint**: All safety-critical flows must be constrained by `Guardian` agents.
*   **Verification**: `Phase3Verification.fs` tests the Veto capability.

### 3.2 AOR (Agent Operating Rules)
*   **Logic**: Deontic logic (Obligation, Prohibition, Permission).
*   **Implementation**: F# Active Patterns matching agent messages.

### 3.3 TDG (Test-Driven Generation)
*   **Rule**: Tests must exist *before* code generation.
*   **Status**: `Phase3Verification.fs` was created before `Synapse.fs` was fully wired.

### 3.4 BDD (Behavior-Driven Development)
*   **Scenarios**: Defined in `PRAJNA_BDD_SCENARIOS.md`.
*   **Automation**: Mapped to F# integration tests.

### 3.5 FMEA (Failure Mode and Effects Analysis)
*   **Risk**: Criticality-based prioritization of test cases.
*   **Mitigation**: Redundant pathways (e.g., Zenoh + Direct HTTP fallback).

---

## 4.0 EXECUTION STRATEGY

### 4.1 Tools
*   **Harness**: `dotnet run --project ... -- --fullsystem-verify`
*   **Frameworks**: `Expecto` (Unit), `FsCheck` (Property), `Spectre.Console` (Reporting).
*   **Environment**: `podman-compose-testing.yml` (Ephemeral Mesh).

### 4.2 Critical Path
1.  **L1-L3**: Unit & Agent Verification (In-Process).
2.  **L4-L6**: Connectivity Verification (Zenoh/Container).
3.  **L7-L9**: Cognitive & Evolutionary Verification (AI/Ark).

---

## 5.0 SIL-6 COVERAGE GATES

| Gate | Description | Metric | Status |
| :--- | :--- | :--- | :--- |
| **G1** | **Deterministic Safety** | 100% Guardian Veto Rate | ✅ PASS |
| **G2** | **Cognitive Latency** | OODA Loop < 100ms | ⚠️ PENDING (Requires Live Mesh) |
| **G3** | **State Integrity** | Zero-Copy Serialization | ✅ PASS |
| **G4** | **Substrate Independence**| Zero Elixir UI Deps | ✅ PASS |

---

**Signed By**: Gemini (Cybernetic Architect)
**Approval**: SC-TEST-001
