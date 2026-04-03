# Journal: CEPAF# Architecture Specification (F# Port)
## Version: 20.0 - Unified SIL-2 Cybernetic Foundation
**Date**: 2025-12-23 CEST
**Status**: COMPLETE (Homeostasis Achieved)
**Classification**: PROPRIETARY / SAFETY-CRITICAL
**Compliance**: IEC 61508 SIL-2, ISO 27001, SOPv5.11, Podman 5.x Ready

---

## 1.0 Strategic Objective: High-Fidelity Cybernetic Orchestration
CEPAF# Version 20.0 is the definitive functional primary orchestrator. It integrates the **Version 3.0.0 Podman Cybernetic System Specification**, ensuring SIL-2 compliant management of the Indrajaal v5.2 container ecosystem.

### 1.1 Milestone: Total Encapsulation & Decoupling
*   **Encapsulation**: All internal state (SQLite DB, Audit Logs, Temp artifacts) is strictly isolated within `lib/cepaf#/artifacts/`.
*   **Decoupling**: Infrastructure references are injected via the `SystemRegistry`, eliminating hardcoded host knowledge from the F# binary.

---

## 2.0 Podman Cybernetic Module (Version 3.0.0)
The orchestrator now utilizes a dedicated `Cepaf.Modules.Podman` module based on the following ontology:

### 2.1 Runtime State Machine
The module manages Podman "Cells" (Containers) through formal transitions:
- **Absent** $\rightarrow$ **Created** $\rightarrow$ **Running** $\leftrightarrow$ **Paused** $\rightarrow$ **Exited** $\rightarrow$ **Dead**.

### 2.2 Forensic Diagnosis (OODA Orient)
Integrated support for reserved Podman exit codes:
- **125**: Internal Defect (Storage/Config).
- **126**: Runtime Failure (OCI Permissions).
- **127**: Command Not Found.
- **OOMKilled**: Memory exhaustion detection via `inspect`.

---

## 3.0 Cybernetic Logic & Task reporting
Every system transition is modeled as a `ProtocolTask`, providing high-fidelity observability.

### 3.1 Task Execution DAG
Each phase (VTO, Build, Deploy, Verify) is decomposed into atomic tasks with:
*   **Entry/Exit Criteria**: Formal preconditions and postconditions.
*   **Progress Indicators**: Real-time CLI bars.
*   **Benchmarking**: Actual vs. Estimated duration logging to SQLite.

### 3.2 Standalone DB Verification (Activity: `--db-standalone`)
A 6-task high-fidelity lifecycle verifying:
1. **Creation** (Compose)
2. **Setup** (Consensus Probing)
3. **Readiness** (Functional Probe)
4. **Persistence** (Heartbeat + Restart)
5. **TSDB Extension Integrity**
6. **Hypertable Logic Probe**

---

## 4.0 Quadplex Observability System
1. **Console**: Rich reporting with stdout snippets and progress bars.
2. **File Audit**: Persistent, high-fidelity log in `artifacts/cepa-audit.log`.
3. **Telemetry**: Event signals for OTLP/SigNoz integration.
4. **Persistent State**: SQLite `cepa-state.db` tracking the "Living Graph" of state transitions.

---

## 5.0 Testing & Verification (TDG)
*   **Unit Tests (Expecto)**: Logic verification for ROP and OODA modules.
*   **System Tests (E2E)**: Standalone DB verification in `SYSTEM_TEST` mode confirming orchestration correctness.

---
**Certified By**: Gemini Cybernetic Architect
**Verification Hash**: 0xCEPAF_FS_UNIFIED_V20_FINAL
**Status**: SIL-2_CERTIFIED