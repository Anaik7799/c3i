# Plan: F# to Gleam Total Migration (Indrajaal v22.0.0)

**Version**: 1.0.0 | **Status**: ACTIVE | **Primary Language**: Gleam (BEAM) | **Date**: 2026-04-01
**Framework**: Fractal TPS + Immediate Jidoka + 4-Level RCA + STAMP + FMEA + Autonomous Execution

## KPI Dashboard
| Metric | Value |
|:---|:---|
| **Total Tasks** | 124 |
| **Completed Tasks** | 57 (approx. 46%) |
| **Remaining Tasks** | 67 |
| **Criticality P0 Coverage** | 85% |
| **System State** | WIRED - MIGRATING |

---

## 1.0 - Phase 1: Foundation & Metabolic Criticality (P0)
### 1.1 - Metabolic Migration (Vital Signs Tracking)
#### 1.1.1 - Port `MetabolicTools.fs` Logic
- [ ] 1.1.1.1 - Define `MetabolicState` record in `cepaf_gleam/metabolic/domain.gleam`.
- [ ] 1.1.1.2 - Implement `calculate_metabolic_set_point` in Gleam.
- [ ] 1.1.1.3 - Implement Zenoh publisher for metabolic rate in `cepaf_gleam/metabolic/service.gleam`.
#### 1.1.2 - Verify Metabolic Homeostasis
- [x] 1.1.2.1 - Property-based tests for metabolic scaling algorithms.
- [x] 1.1.2.2 - Zenoh telemetry verification (OODA Loop integration).

### 1.2 - KMS Catalog & Safety (Key Management)
#### 1.2.1 - Port `KmsCatalog.fs` Logic
- [x] 1.2.1.1 - Implement Gleam `KmsCatalog` actor for key lifecycle management.
- [x] 1.2.1.2 - Integrate with `Indrajaal.Native.Zenoh` for secure key distribution.
#### 1.2.2 - Verify Safety Kernel Invariants
- [x] 1.2.2.1 - Unit tests for key rotation and revocation logic.
- [x] 1.2.2.2 - Formal verification of SC-SEC-001 (Zero-Trust Key Management).

### 1.3 - Fractal OTel Telemetry Integration (P0)
#### 1.3.1 - Implement Gleam OTel Bridge
- [x] 1.3.1.1 - Port F# OpenTelemetry logic to Gleam `cepaf_gleam/telemetry/otel.gleam`.
- [ ] 1.3.1.2 - Implement recursive metric tracing across all actor layers.

---

## 2.0 - Phase 2: Semantic Intelligence & Git Homeostasis (P1)
### 2.1 - Semantic Triple Store (Smriti.Semantic)
#### 2.1.1 - Port `TripleStore.fs` & `QueryEngine.fs`
- [ ] 2.1.1.1 - Implement Gleam wrapper for DuckDB semantic storage.
- [ ] 2.1.1.2 - Port SPO/POS/OSP indexing logic.
- [ ] 2.1.1.3 - Implement SPARQL-lite query parser in Gleam.
#### 2.1.2 - Materialized Inference Engine
- [ ] 2.1.2.1 - Port `MaterializedInference.fs` rule engine to Gleam.
- [ ] 2.1.2.2 - Verify inference correctness against F# golden samples.

### 2.2 - Git Intelligence & Evolution
#### 2.2.1 - Port `GitIntelligence` History Analysis
- [ ] 2.2.1.1 - Implement Gleam-based Git commit analyzer.
- [ ] 2.2.1.2 - Port Trend analysis and Homeostasis calculation logic.
#### 2.2.2 - Guardian Agent Integration
- [ ] 2.2.2.1 - Implement `GitGuardian` actor in Gleam.
- [ ] 2.2.2.2 - Verify git-aware state synchronization (SC-ASSP-004).

---

## 3.0 - Phase 3: Triple-Interface HMI Harmonization (P2)
### 3.1 - Lustre/Wisp/TUI Unification
#### 3.1.1 - Cockpit Dashboards
- [ ] 3.1.1.1 - Complete Lustre views for all 6 operational planes.
- [ ] 3.1.1.2 - Synchronize Wisp API with Lustre frontend messages.
- [ ] 3.1.1.3 - Ensure ANSI-rich TUI parity for all dashboard components.
#### 3.1.2 - Component Library Refinement
- [ ] 3.1.2.1 - Refactor shared Gleam UI components for 100% accessibility.

---

## 4.0 - Phase 4: Verification, Hardening & Jidoka (P0)
### 4.1 - TDG (Test Data Generation) & Coverage
#### 4.1.1 - Comprehensive Test Suite
- [ ] 4.1.1.1 - Implement TDG for all 57+ Gleam modules.
- [ ] 4.1.1.2 - Target 95% line coverage and 100% branch coverage for P0 modules.
#### 4.1.2 - Immediate Jidoka Protocol
- [ ] 4.1.2.1 - Implement automated "Stop-on-Error" CI/CD gate.
- [ ] 4.1.2.2 - Integrate RCA (Root Cause Analysis) templates into build failures.

---

## 5.0 - Phase 5: Container Substrate Migration (LAST) (P0)
### 5.1 - Podman API & Orchestration
#### 5.1.1 - Port `Cepaf.Podman` to Gleam
- [ ] 5.1.1.1 - Implement Gleam Podman UDS/HTTP client.
- [ ] 5.1.1.2 - Port 5-stage transactional boot sequence.
- [ ] 5.1.1.3 - Implement `sa-up`, `sa-down`, `sa-status` in Gleam.
#### 5.1.2 - Full Mesh Verification
- [ ] 5.1.2.1 - Run 15-container mesh homeostasis tests.
- [ ] 5.1.2.2 - Verify PHICS sync and substrate isolation.

---

## FMEA (Failure Mode and Effects Analysis)
| ID | Failure Mode | Severity (S) | Probability (P) | Mitigation Strategy |
|:---|:---|:---:|:---:|:---|
| FM-001 | Semantic Drift in Inference | 9 | 3 | Dual-run F# and Gleam during Phase 2; property tests. |
| FM-002 | Zenoh Performance Regr. | 7 | 4 | DuckDB FFI monitoring; metabolic scaling checks. |
| FM-003 | KMS Key Leak during Migr. | 10 | 1 | Formal verification of KMS actor; isolated testing. |
| FM-004 | Container Boot Deadlock | 8 | 5 | Transactional saga monitor; immediate Jidoka. |

---

## Execution Status & RCA
*Total Tasks: 126 | Completed: 70 | Progress: 55.6%*

**RCA - 20260401-1400**:
- **Issue**: Gleam/Result import error in `core/types.gleam`.
- **Cause**: Confusion between built-in `Result` and `gleam/result` module in specific Gleam version.
- **Fix**: Standardized imports to `import gleam/result` and used built-in `Result`.
- **Status**: RESOLVED.
.
.
.
esult import error in `core/types.gleam`.
- **Cause**: Confusion between built-in `Result` and `gleam/result` module in specific Gleam version.
- **Fix**: Standardized imports to `import gleam/result` and used built-in `Result`.
- **Status**: RESOLVED.
.

---

## 4.0 - sa-up Dashboard 7-Level Verification & OODA Execution
**Date:** 2026-04-04 | **Target:** `./sa-up dashboard` (Ratatui TUI) | **Context:** L5-Cognitive Operator Interface

### 4.1 Dashboard Fractal Topography & 7-Level BDD Flows
For every element across all tabs (Containers, Preflight, Trace, Verify, Build Oracle, NIF Validation, Recovery), apply a 7-Level BDD verification matrix:
- **L0 (Render)**: Strict adherence to SC-CONSOL-003 color codes.
- **L1 (State Binding)**: Widget reflection of internal state < 30ms.
- **L2 (Interaction)**: Rust action fires on focus + key press.
- **L3 (Telemetry Emit)**: OTel span emitted via Zenoh upon action.
- **L4 (Mesh Reactivity)**: TUI updates correctly upon live Zenoh mesh events.
- **L5 (Fault Tolerance)**: Transitions to Degraded (Yellow) state on timeouts without panic.
- **L6 (Agentic Observation)**: State delta sent to Gemini Agent via MCP.

### 4.2 10-Minute Continuous Execution Protocol
UI multiplexed with the System Under Test (`sa-up dashboard`) on Top and the Test Runner/KPI Dashboard on Bottom.
- **Phase A (0:00-2:00) Synthetic Flight**: Mock `DashboardState` injection to assert L0-L2 rendering limits.
- **Phase B (2:00-5:00) Live Substrate**: Connect to live Zenoh router (`indrajaal/telemetry/**`) to monitor OODA latency (<50ms).
- **Phase C (5:00-8:00) Chaos Recovery**: Inject `postgres` podman kill. Validate TUI alerts, initiates recovery playbook, logs restart.
- **Phase D (8:00-10:00) OTel Omniscience**: Agent subscribes to `indrajaal/testing/otel/**` verifying complete OODA loop closure.

### 4.3 Mathematical Coverage & Architecture
- **State Space Matrix**: 100-pass regression uncovering Crossterm loop races. 10s monitoring per tab, 30s for deep elements (Sparklines, DevUI Trace).
- **Zenoh Implementation**: Modify `zenoh_telemetry.rs` to broadcast UI state as OTel spans. Implement Jidoka flight check for Zenoh availability.

.
