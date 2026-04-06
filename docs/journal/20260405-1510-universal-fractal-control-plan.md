# Plan: Indrajaal Universal Fractal Orchestrator (IUFO) & Full WebUI Control

**Created**: 20260405-1510 CEST
**Last Updated**: 20260406-0300 CEST
**Status**: DRAFT
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA)

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260405-1510 CEST | CREATED | Comprehensive fractal L0-L7 plan with full WebUI control | Gemini CLI |
| 20260406-0300 CEST | UPDATED | Expanded fractal components coverage and WebUI operational controls | Gemini CLI |

## Executive Summary
Establish a unified, biomorphic control plane using `cepaf_gleam` that covers all 8 fractal layers (L0-L7) and all system components. This plan activates full operational control via the Lustre WebUI and SSE-driven Agent UI, ensuring situational awareness and authoritative mesh management. This guarantees 100% of CLI capabilities (`sa-up`, `sa-down`, `sa-plan`, `db-migrate`, `sa-mesh`, etc.) are exposed directly through the Triple-Interface (WebUI/REST/TUI).

## 5-Level Detailed Plan

### 1.0 - L0 Constitutional: Integrity & Safety (Priority: P0)
#### 1.1 - Guardian & Constitutional Verifier (Priority: P0)
- 1.1.1.1.1 - Implement `lib/cepaf_gleam/src/cepaf_gleam/core/guardian.gleam` for P0 decision gating.
- 1.1.1.1.2 - Surface constitutional hash, Axiom status, and immutable STAMP constraints in WebUI L0 tab.
- 1.1.1.1.3 - WebUI Control: "Emergency Stop < 5s" (SC-EMR-057), "Halt Mutations" (Stabilize mode).
#### 1.2 - Safety Validator & SIL-6 Compliance (Priority: P0)
- 1.2.1.1.1 - Integrate Agda/Quint verified properties into runtime checks.
- 1.2.1.1.2 - WebUI Control: Execute `sa-verify` (5-order effects verification) directly from L0 dashboard.

### 2.0 - L1 Atomic/Debug: Observability & Probes (Priority: P1)
#### 2.1 - Observability Analyzer & Probes (Priority: P1)
- 2.1.1.1.1 - Map Zenoh OTel spans to WebUI real-time flame graphs.
- 2.1.1.1.2 - Implement L1 Debug panel for Zenoh session inspection, NIF health, and raw log streaming (`sa-logs [svc]`).
#### 2.2 - Substrate Guard & Code Debugger (Priority: P1)
- 2.2.1.1.1 - Real-time Axiom 0.1/0.2 violation monitoring and automated purging.
- 2.2.1.1.2 - WebUI Control: Trigger `sa-scour` (Port Substrate Isolation) and `sa-clean` (Shutdown + volume prune).

### 3.0 - L2 Component: Lifecycle & Actors (Priority: P1)
#### 3.1 - Gleam/OTP Supervision Tree (Priority: P1)
- 3.1.1.1.1 - Develop interactive supervisor visualization (Lustre UI) mapping all BEAM processes.
- 3.1.1.1.2 - WebUI Control: Start/stop/restart/trace controls for individual Gleam actors.
#### 3.2 - Build & Design Supervisor Enrichment (Priority: P2)
- 3.2.1.1.1 - Visualize build wave CPM (Critical Path Method) and parallel compilation metrics in WebUI.
- 3.2.1.1.2 - WebUI Control: Trigger `compile`, `compile-strict`, `test-sil6` directly from L2 UI.

### 4.0 - L3 Transaction: State & Persistence (Priority: P1)
#### 4.1 - Holon & Robustness Analyzer (Priority: P1)
- 4.1.1.1.1 - Enable full CRUD for SQLite planning database and `PROJECT_TODOLIST.md` sync via WebUI (replaces `sa-plan`).
- 4.1.1.1.2 - Implement state replayability dashboard for transaction debugging.
#### 4.2 - Oban Queue & Database Management (Priority: P2)
- 4.2.1.1.1 - Add L3 panel for background job status and retry orchestration.
- 4.2.1.1.2 - WebUI Control: Trigger `db-migrate`, `db-reset`, and `db-setup`.

### 5.0 - L4 System: Swarm & Resource Governance (Priority: P0)
#### 5.1 - Podman Orchestration (Priority: P0)
- 5.1.1.1.1 - Implement 16-container card grid (zenoh, cortex, db, etc.) with real-time CPU/Mem/Network metrics.
- 5.1.1.1.2 - WebUI Control: Enable atomic "Wave Ignition" (`sa-up`), "Apoptosis" (`sa-down`), and Container Restart toggles.
#### 5.2 - CPU Governor & Deploy Supervisor (Priority: P1)
- 5.2.1.1.1 - Visualize adaptive scheduler throttling based on load.
- 5.2.1.1.2 - WebUI Control: Access `cpu-status` and adjust `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` interactively.

### 6.0 - L5 Cognitive: OODA & Intelligence (Priority: P1)
#### 6.1 - OODA Supervisor & FMEA Analyzer (Priority: P1)
- 6.1.1.1.1 - Create 5-phase OODA cycle animation (Observe -> Orient -> Decide -> Act -> Verify).
- 6.1.1.1.2 - Implement "Reasoning Marquee" for CoT (Chain of Thought) visibility and FMEA risk scores.
- 6.1.1.1.3 - WebUI Control: Force OODA cycle execution (`sa-orch-ooda`), trigger LLM advisor.
#### 6.2 - Rule Engine (RETE-UL) Management (Priority: P1)
- 6.2.1.1.1 - Enable dynamic GRL rule toggling and fact injection via WebUI.

### 7.0 - L6 Ecosystem: Mesh & Quorum (Priority: P1)
#### 7.1 - Zenoh Mesh Analyzer & Swarm Verification (Priority: P1)
- 7.1.1.1.1 - Implement interactive mesh topology map (3 routers, 13 satellites).
- 7.1.1.1.2 - Surface 2oo3 quorum voting status, latency heatmaps, and partition alerts.
- 7.1.1.1.3 - WebUI Control: Run `sa-swarm-quorum`, `sa-swarm-bio`, and continuous mesh probes.
#### 7.2 - Immune Chaos Agent (Priority: P2)
- 7.2.1.1.1 - Display SymbioticDefense status and active antibodies.
- 7.2.1.1.2 - WebUI Control: Inject faults for chaos testing (`sa-test-agents`).

### 8.0 - L7 Federation: Multiverse & Architecture (Priority: P2)
#### 8.1 - Master Supervisor & Architect (Priority: P2)
- 8.1.1.1.1 - Enable cross-peer attestation, version vectors, and state-vector dashboard.
- 8.1.1.1.2 - WebUI Control: System-wide "Stabilize" (Halt Mutations) mode, `sa-checkpoint`, `sa-restore`, and `sa-fork`.

## WebUI Implementation Strategy (Penta-Stack)
- **Primary**: Gleam Lustre (SSR + Client-side hydrated) available on port 4100.
- **Backplane**: ZMOF (Zenoh-MCP-OTel Fractal) providing unified Pub/Sub.
- **Interface**: 8 Fractal Tabs (L0-L7) + 16 Container Grid + AG-UI SSE Stream for Agents.
- **Operational Parity**: 100% of bash CLI scripts mapped to Gleam Wisp endpoints and executable via WebUI buttons.

## Success Criteria
- [ ] L0-L7 fractal navigation fully operational in WebUI, tracking all components (Agents, Rules, Subsystems).
- [ ] 100% of mesh containers (16/16) controllable via authenticated WebUI sessions.
- [ ] OODA cycle reasoning visible in Agent UI during autonomous operations.
- [ ] All Gleam artifacts, Allium specs, and system state synchronized with current WebUI capabilities.
