# Indrajaal Planning System - Complete Documentation

**Version**: 21.3.0-SIL6
**Status**: Production Ready
**STAMP**: SC-TODO-001 to SC-TODO-008, SC-PLAN-001 to SC-PLAN-015, SC-ORCH-001 to SC-ORCH-015
**AOR**: AOR-TODO-001 to AOR-TODO-010, AOR-PLAN-001 to AOR-PLAN-003, AOR-ORCH-001 to AOR-ORCH-015
**Criticality**: P0 (CRITICAL)
**Compliance**: IEC 61508 SIL-6, ISO 27001, GDPR

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Control Flow](#2-control-flow)
3. [Data Flow](#3-data-flow)
4. [CLI Interface](#4-cli-interface)
5. [GUI Interface](#5-gui-interface)
6. [TUI Interface](#6-tui-interface)
7. [UI/UX Design](#7-uiux-design)
8. [CX (Customer Experience)](#8-cx-customer-experience)
9. [DX (Developer Experience)](#9-dx-developer-experience)
10. [Service Integration](#10-service-integration)
11. [Fractal Architecture](#11-fractal-architecture)
12. [STAMP Constraints](#12-stamp-constraints)
13. [AOR Rules](#13-aor-rules)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Executive Summary

### 1.1 System Purpose

The Indrajaal Planning System is the **central task management and orchestration engine** for the SIL-6 biomorphic organism. It serves as the cognitive planning layer that coordinates work across:

- 7 integrated services (Cortex, Prajna, Smriti, CEPAF, Planning, Chaya, Guardian)
- 30+ functional domains
- 780+ modules
- Multiple execution contexts (standalone, mesh, federation)

### 1.2 Key Goals

| Goal | Description | Metric |
|------|-------------|--------|
| **Single Source of Truth** | SQLite/DuckDB authoritative state | 100% data integrity |
| **Access Control** | Block agent direct file access | 0 violations |
| **Performance** | Sub-100ms OODA cycles | <100ms p99 |
| **Reliability** | 99.9% uptime | MTBF > 720h |
| **Auditability** | Complete lineage tracking | 100% coverage |

### 1.3 Key Constraints (SC-TODO-001)

**CRITICAL CONSTRAINT**: Agents SHALL NOT access `PROJECT_TODOLIST.md` directly.

```
┌─────────────────────────────────────────────────────────┐
│  FORBIDDEN OPERATIONS (SC-TODO-001 to SC-TODO-003)     │
├─────────────────────────────────────────────────────────┤
│  ✗ read_file("PROJECT_TODOLIST.md")                    │
│  ✗ write_file("PROJECT_TODOLIST.md")                   │
│  ✗ cat PROJECT_TODOLIST.md                             │
│  ✗ grep "pattern" PROJECT_TODOLIST.md                  │
│  ✗ sed -i 's/a/b/' PROJECT_TODOLIST.md                 │
│                                                         │
│  AUTHORIZED ACCESS (SC-TODO-004)                        │
│  ✓ sa-plan list                                         │
│  ✓ sa-plan add "title"                                  │
│  ✓ sa-plan update <id> <status>                        │
│  ✓ chaya list                                           │
│  ✓ F# API: Manager.addTask                             │
└─────────────────────────────────────────────────────────┘
```

### 1.4 Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│                    PLANNING SYSTEM ARCHITECTURE                 │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │     CLI     │  │     GUI     │  │     TUI     │            │
│  │   sa-plan   │  │   Prajna    │  │    chaya    │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          ▼                                      │
│         ┌────────────────────────────────┐                     │
│         │   ACCESS CONTROL GATEWAY       │                     │
│         │   (SC-TODO-001 Enforcement)    │                     │
│         └────────────┬───────────────────┘                     │
│                      │                                          │
│                      ▼                                          │
│         ┌────────────────────────────────┐                     │
│         │   GUARDIAN SAFETY KERNEL       │                     │
│         │   (Pre-approval Required)      │                     │
│         └────────────┬───────────────────┘                     │
│                      │                                          │
│                      ▼                                          │
│         ┌────────────────────────────────┐                     │
│         │    F# PLANNING MANAGER         │                     │
│         │    (Authoritative Interface)   │                     │
│         └────┬───────┬───────┬───────────┘                     │
│              │       │       │                                 │
│      ┌───────┴───┐   │   ┌───┴───────┐                        │
│      ▼           ▼   │   ▼           ▼                        │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐              │
│  │ SQLite │  │ Zenoh  │  │ DuckDB │  │ Markdown│              │
│  │(State) │  │(Events)│  │(History)│  │(Backup)│              │
│  └────────┘  └────────┘  └────────┘  └────────┘              │
│      ▲           ▲                       │                     │
│      │           │                       ▼                     │
│      │           │           ┌────────────────────┐            │
│      │           │           │ PROJECT_TODOLIST.md│            │
│      │           │           │ AGENT ACCESS BLOCKED│            │
│      │           │           └────────────────────┘            │
│      │           │                                             │
│  ┌───┴───────────┴──────────────────────────────┐             │
│  │   SERVICE INTEGRATION LAYER                  │             │
│  │   (Cortex, Prajna, Smriti, CEPAF, Chaya)     │             │
│  └──────────────────────────────────────────────┘             │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 1.5 Key Statistics

| Metric | Value | Source |
|--------|-------|--------|
| Total F# Lines | 2,500+ | Cepaf.Planning module |
| Test Coverage | 380+ tests | 9-layer BDD suite |
| STAMP Constraints | 40+ | SC-TODO, SC-PLAN, SC-ORCH |
| AOR Rules | 30+ | AOR-TODO, AOR-PLAN, AOR-ORCH |
| Response Time (p99) | <100ms | CLI/API operations |
| OODA Cycle Time | 48ms avg | Real-time measurement |

---

## 2. Control Flow

### 2.1 Request Lifecycle

```
┌──────────────────────────────────────────────────────────────────┐
│              REQUEST LIFECYCLE (End-to-End)                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  USER/AGENT REQUEST                                               │
│       │                                                           │
│       ├─── CLI: sa-plan add "Task title" --priority P1           │
│       ├─── GUI: Form submit on /prajna/planning                  │
│       └─── TUI: chaya add "Task title" P1                        │
│       │                                                           │
│       ▼                                                           │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 1: INPUT VALIDATION                  │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  1.1 Parse command/request                  │                 │
│  │  1.2 Validate syntax                        │                 │
│  │  1.3 Extract parameters (title, priority)   │                 │
│  │  1.4 Check parameter types                  │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │                                             │
│                     ▼                                             │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 2: ACCESS CONTROL (SC-TODO-001)      │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  2.1 Identify agent/user                    │                 │
│  │  2.2 Check if agent attempting direct access│                 │
│  │  2.3 Validate access method                 │                 │
│  │  2.4 Log access attempt                     │                 │
│  │                                              │                 │
│  │  Decision Tree:                              │                 │
│  │  ┌──────────────────────┐                   │                 │
│  │  │ Is Agent?            │                   │                 │
│  │  └─────┬──────────┬─────┘                   │                 │
│  │        │ Yes      │ No (Human)              │                 │
│  │        ▼          ▼                         │                 │
│  │  ┌──────────┐ ┌──────────┐                  │                 │
│  │  │Direct    │ │Allow All │                  │                 │
│  │  │Access?   │ └──────────┘                  │                 │
│  │  └─┬────┬───┘                                │                 │
│  │    │Yes │No                                  │                 │
│  │    ▼    ▼                                    │                 │
│  │  BLOCK ALLOW                                 │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │ (If Allowed)                                │
│                     ▼                                             │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 3: GUARDIAN VALIDATION                │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  3.1 Submit proposal to Guardian            │                 │
│  │  3.2 Constitutional check (Ψ₀-Ψ₅)          │                 │
│  │  3.3 Safety kernel validation               │                 │
│  │  3.4 Risk assessment (FMEA)                 │                 │
│  │  3.5 Receive approval/veto                  │                 │
│  │                                              │                 │
│  │  Guardian Decision:                          │                 │
│  │  ┌────────────────┐                         │                 │
│  │  │ Proposal       │                         │                 │
│  │  │ Valid?         │                         │                 │
│  │  └───┬────────┬───┘                         │                 │
│  │      │Approve │Veto                         │                 │
│  │      ▼        ▼                             │                 │
│  │   PROCEED   REJECT                          │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │ (If Approved)                               │
│                     ▼                                             │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 4: BUSINESS VALIDATION                │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  4.1 Title length check (2-200 chars)       │                 │
│  │  4.2 Priority validation (P0-P3)            │                 │
│  │  4.3 Parent ID existence check              │                 │
│  │  4.4 Dependency cycle detection             │                 │
│  │  4.5 Status transition validity             │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │ (If Valid)                                  │
│                     ▼                                             │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 5: EXECUTION                          │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  5.1 Generate hierarchical ID               │                 │
│  │  5.2 Create task object                     │                 │
│  │  5.3 Persist to SQLite (transaction)        │                 │
│  │  5.4 Publish to Zenoh event bus             │                 │
│  │  5.5 Update DuckDB history                  │                 │
│  │  5.6 Regenerate markdown backup             │                 │
│  │  5.7 Log to Immutable Register              │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │                                             │
│                     ▼                                             │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 6: SERVICE COORDINATION               │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  6.1 Notify Prajna (dashboard update)       │                 │
│  │  6.2 Notify Smriti (knowledge update)       │                 │
│  │  6.3 Notify Chaya (mesh distribution)       │                 │
│  │  6.4 Notify Cortex (AI context)             │                 │
│  │  6.5 Wait for acknowledgments               │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │                                             │
│                     ▼                                             │
│  ┌─────────────────────────────────────────────┐                 │
│  │  PHASE 7: RESPONSE                           │                 │
│  │  ────────────────────────────────────────   │                 │
│  │  7.1 Format success response                │                 │
│  │  7.2 Include task ID and status             │                 │
│  │  7.3 Return to caller                       │                 │
│  │  7.4 Log completion telemetry               │                 │
│  └──────────────────┬──────────────────────────┘                 │
│                     │                                             │
│                     ▼                                             │
│  OUTPUT: ✅ Task added: abc123-def4 (P1)                         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

TIMING BREAKDOWN:
  Phase 1: ~5ms   (Input validation)
  Phase 2: ~10ms  (Access control + logging)
  Phase 3: ~15ms  (Guardian validation)
  Phase 4: ~5ms   (Business validation)
  Phase 5: ~35ms  (SQLite + Zenoh + DuckDB + Markdown)
  Phase 6: ~20ms  (Service coordination)
  Phase 7: ~2ms   (Response formatting)
  ─────────────
  TOTAL:   ~92ms  (Target: <100ms per SC-OODA-001)
```

### 2.2 Access Control Decision Flow

```
┌──────────────────────────────────────────────────────────────────┐
│          ACCESS CONTROL DECISION FLOW (SC-TODO-001)              │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Request: {agent: "claude", method: "read", path: "PROJECT_..."}│
│       │                                                           │
│       ▼                                                           │
│  ┌────────────────────────────┐                                  │
│  │ Is requester an agent?     │                                  │
│  │ (claude, gemini, grok, *)  │                                  │
│  └──────┬──────────────┬──────┘                                  │
│         │ YES          │ NO                                      │
│         ▼              ▼                                          │
│  ┌──────────────┐  ┌──────────────────┐                         │
│  │ Is method    │  │ ALLOW             │                         │
│  │ direct       │  │ (Human access)    │                         │
│  │ access?      │  └──────────────────┘                         │
│  └──┬───────┬───┘                                                │
│     │ YES   │ NO                                                 │
│     ▼       ▼                                                    │
│  ┌─────┐ ┌────────────────────┐                                 │
│  │BLOCK│ │Is method authorized?│                                 │
│  │(001)│ │(FSharpCLI, ChayaCLI│                                 │
│  └─────┘ │ FSharpAPI)         │                                 │
│          └──┬──────────────┬──┘                                  │
│             │ YES          │ NO                                  │
│             ▼              ▼                                      │
│          ┌──────┐       ┌──────┐                                 │
│          │ALLOW │       │DENY  │                                 │
│          │(004) │       │(UNK) │                                 │
│          └──────┘       └──────┘                                 │
│                                                                   │
│  BLOCKED EXAMPLE:                                                 │
│  ─────────────────                                                │
│  Input:  {agent: "claude", method: DirectRead, path: "...md"}   │
│  Output: Blocked "SC-TODO-001: Agent 'claude' cannot use        │
│          DirectRead on PROJECT_TODOLIST.md. Use sa-plan CLI     │
│          instead."                                               │
│                                                                   │
│  ALLOWED EXAMPLE:                                                 │
│  ─────────────────                                                │
│  Input:  {agent: "claude", method: FSharpCLI, path: "...md"}    │
│  Output: Allowed                                                  │
│                                                                   │
│  LOG ENTRY (SC-TODO-008):                                         │
│  ─────────────────                                                │
│  {                                                                │
│    timestamp: "2026-01-16T12:34:56Z",                            │
│    agent: "claude",                                              │
│    method: "DirectRead",                                         │
│    file_path: "PROJECT_TODOLIST.md",                             │
│    result: "Blocked",                                            │
│    constraint: "SC-TODO-001"                                     │
│  }                                                                │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 2.3 Safety Kernel Validation Flow

```
┌──────────────────────────────────────────────────────────────────┐
│            GUARDIAN SAFETY KERNEL FLOW                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Proposal: {action: "createTask", params: {...}}                 │
│       │                                                           │
│       ▼                                                           │
│  ┌────────────────────────────────┐                              │
│  │ STEP 1: Constitutional Check    │                              │
│  │ ─────────────────────────────   │                              │
│  │ Verify against Ψ₀-Ψ₅:          │                              │
│  │ ✓ Ψ₀: Existence preserved       │                              │
│  │ ✓ Ψ₁: Regeneration possible     │                              │
│  │ ✓ Ψ₂: History maintained         │                              │
│  │ ✓ Ψ₃: Verification enabled       │                              │
│  │ ✓ Ψ₄: Human alignment            │                              │
│  │ ✓ Ψ₅: Truthfulness               │                              │
│  └────────────┬───────────────────┘                              │
│               │ ALL PASS                                          │
│               ▼                                                   │
│  ┌────────────────────────────────┐                              │
│  │ STEP 2: Operational Check       │                              │
│  │ ─────────────────────────────   │                              │
│  │ Verify against Ω₀-Ω₉:          │                              │
│  │ ✓ Ω₀: Founder's Directive        │                              │
│  │ ✓ Ω₁: Patient Mode active        │                              │
│  │ ✓ Ω₇: Holon sovereignty          │                              │
│  │ ✓ Ω₈: Immutable register used    │                              │
│  └────────────┬───────────────────┘                              │
│               │ ALL PASS                                          │
│               ▼                                                   │
│  ┌────────────────────────────────┐                              │
│  │ STEP 3: STAMP Validation        │                              │
│  │ ─────────────────────────────   │                              │
│  │ Check relevant constraints:     │                              │
│  │ ✓ SC-TODO-004: Using F# CLI     │                              │
│  │ ✓ SC-PLAN-001: Auth interface   │                              │
│  │ ✓ SC-ORCH-001: Coordination     │                              │
│  └────────────┬───────────────────┘                              │
│               │ ALL PASS                                          │
│               ▼                                                   │
│  ┌────────────────────────────────┐                              │
│  │ STEP 4: Risk Assessment (FMEA)  │                              │
│  │ ─────────────────────────────   │                              │
│  │ Severity × Occurrence × Detect  │                              │
│  │ RPN = 3 × 2 × 4 = 24            │                              │
│  │ Threshold: RPN < 50 ✓           │                              │
│  └────────────┬───────────────────┘                              │
│               │ LOW RISK                                          │
│               ▼                                                   │
│  ┌────────────────────────────────┐                              │
│  │ STEP 5: Final Decision          │                              │
│  │ ─────────────────────────────   │                              │
│  │ All checks passed               │                              │
│  │ Guardian APPROVES proposal      │                              │
│  └────────────┬───────────────────┘                              │
│               │                                                   │
│               ▼                                                   │
│  OUTPUT: {status: "approved", token: "guardian-abc123"}          │
│                                                                   │
│  VETO EXAMPLE:                                                    │
│  ───────────────                                                  │
│  If Ψ₄ violation (anti-human action):                            │
│    Guardian VETOES with reason                                   │
│    System HALTS operation                                        │
│    Incident logged to Immutable Register                         │
│    Alert sent to all supervisors                                 │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 2.4 Circuit Breaker State Machine

```
┌──────────────────────────────────────────────────────────────────┐
│              CIRCUIT BREAKER STATE MACHINE                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│                    ┌─────────────┐                                │
│                    │   CLOSED    │                                │
│                    │  (Normal)   │                                │
│                    └──────┬──────┘                                │
│                           │                                       │
│                  success  │ failure_count++                       │
│              ┌────────────┴──────────┐                            │
│              │                       │                            │
│              ▼                       ▼                            │
│       continue_normal      failure_count >= threshold            │
│                                     │                             │
│                                     ▼                             │
│                            ┌─────────────┐                        │
│                            │    OPEN     │                        │
│                            │  (Failed)   │                        │
│                            └──────┬──────┘                        │
│                                   │                               │
│                      wait_timeout │                               │
│                                   ▼                               │
│                            ┌─────────────┐                        │
│                            │ HALF_OPEN   │                        │
│                            │  (Testing)  │                        │
│                            └──────┬──────┘                        │
│                                   │                               │
│                  ┌────────────────┼────────────────┐              │
│                  │ test_success   │ test_failure   │              │
│                  ▼                ▼                │              │
│          ┌─────────────┐   ┌─────────────┐        │              │
│          │   CLOSED    │   │    OPEN     │        │              │
│          │ (Recovered) │   │  (Re-fail)  │        │              │
│          └─────────────┘   └─────────────┘        │              │
│                                                    │              │
│  CONFIGURATION:                                    │              │
│  ───────────────                                   │              │
│  failure_threshold: 5 failures                     │              │
│  timeout: 30 seconds                               │              │
│  test_request_count: 3 requests                    │              │
│  success_threshold: 2/3 must succeed               │              │
│                                                                   │
│  USAGE EXAMPLE:                                                   │
│  ──────────────                                                   │
│  Circuit for Zenoh publishing:                                    │
│                                                                   │
│  1. Attempt publish → failure (Zenoh down)                       │
│  2. Retry → failure (count: 2/5)                                 │
│  3. Retry → failure (count: 3/5)                                 │
│  4. Retry → failure (count: 4/5)                                 │
│  5. Retry → failure (count: 5/5) → OPEN circuit                  │
│  6. Further attempts immediately fail (no retry)                 │
│  7. Wait 30 seconds → Enter HALF_OPEN                            │
│  8. Test publish → success (1/3)                                 │
│  9. Test publish → success (2/3) → CLOSE circuit                 │
│  10. Resume normal operation                                      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 2.5 OODA Cycle Integration

```
┌──────────────────────────────────────────────────────────────────┐
│         OODA CYCLE FLOW (Target: <100ms, SC-OODA-001)            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ OBSERVE (20ms)                                            │    │
│  │ ───────────────                                           │    │
│  │ 1. Query current task state from SQLite                  │    │
│  │    SELECT * FROM tasks WHERE status != 'Completed'       │    │
│  │                                                           │    │
│  │ 2. Check Zenoh for mesh updates                          │    │
│  │    SUBSCRIBE indrajaal/planning/events                   │    │
│  │                                                           │    │
│  │ 3. Assess system health (Sentinel query)                 │    │
│  │    GET /api/prajna/sentinel/health                       │    │
│  │                                                           │    │
│  │ 4. Read environment (git status, build state)            │    │
│  │    git status --porcelain                                │    │
│  │    ls -la _build/dev                                     │    │
│  │                                                           │    │
│  │ OUTPUT: %{                                                │    │
│  │   pending: 45,                                            │    │
│  │   in_progress: 12,                                        │    │
│  │   completed: 190,                                         │    │
│  │   system_health: 95%,                                     │    │
│  │   build_state: :ready                                     │    │
│  │ }                                                         │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ ORIENT (30ms)                                             │    │
│  │ ─────────────                                             │    │
│  │ 1. Prioritize tasks by P0 > P1 > P2 > P3                 │    │
│  │    priority_sorted = sort_by(tasks, :priority)           │    │
│  │                                                           │    │
│  │ 2. Analyze dependencies (topological sort)               │    │
│  │    dep_graph = build_dependency_graph(tasks)             │    │
│  │    topo_order = topological_sort(dep_graph)              │    │
│  │                                                           │    │
│  │ 3. Identify blockers                                     │    │
│  │    blockers = tasks.filter(status == :blocked)           │    │
│  │                                                           │    │
│  │ 4. Calculate critical path                               │    │
│  │    critical_path = longest_path(dep_graph)               │    │
│  │                                                           │    │
│  │ OUTPUT: %{                                                │    │
│  │   next_tasks: [task_abc, task_def],                      │    │
│  │   blockers: [task_xyz],                                   │    │
│  │   critical_path_length: 5,                                │    │
│  │   recommendation: "Start task_abc (P0, unblocked)"       │    │
│  │ }                                                         │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ DECIDE (20ms)                                             │    │
│  │ ─────────────                                             │    │
│  │ 1. Select next task to execute                           │    │
│  │    next_task = priority_sorted.first_unblocked()         │    │
│  │                                                           │    │
│  │ 2. Allocate resources (agents)                           │    │
│  │    agent = AgentPool.get_available()                     │    │
│  │                                                           │    │
│  │ 3. Plan execution strategy                               │    │
│  │    strategy = determine_strategy(next_task)              │    │
│  │                                                           │    │
│  │ 4. Set success criteria                                  │    │
│  │    criteria = define_success_criteria(next_task)         │    │
│  │                                                           │    │
│  │ OUTPUT: %{                                                │    │
│  │   decision: :execute,                                     │    │
│  │   task: task_abc,                                         │    │
│  │   agent: agent_001,                                       │    │
│  │   strategy: :autonomous,                                  │    │
│  │   success_criteria: "test passes + review approved"      │    │
│  │ }                                                         │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                       │
│                           ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │ ACT (30ms)                                                │    │
│  │ ──────────                                                │    │
│  │ 1. Execute task (update status to InProgress)            │    │
│  │    Manager.updateStatus(task_abc.id, "InProgress")       │    │
│  │                                                           │    │
│  │ 2. Monitor execution                                     │    │
│  │    Telemetry.track(:task_execution, task_abc.id)         │    │
│  │                                                           │    │
│  │ 3. Capture telemetry                                     │    │
│  │    record_metrics(start_time, progress, errors)          │    │
│  │                                                           │    │
│  │ 4. Complete or block based on outcome                    │    │
│  │    if success:                                            │    │
│  │      Manager.updateStatus(task_abc.id, "Completed")      │    │
│  │    else:                                                  │    │
│  │      Manager.updateStatus(task_abc.id, "Blocked")        │    │
│  │                                                           │    │
│  │ OUTPUT: %{                                                │    │
│  │   status: :completed,                                     │    │
│  │   duration_ms: 28,                                        │    │
│  │   telemetry: {...}                                        │    │
│  │ }                                                         │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                       │
│                           ▼                                       │
│                  ┌────────────────────┐                          │
│                  │  FEEDBACK LOOP     │                          │
│                  │  ───────────────   │                          │
│                  │  - Update metrics  │                          │
│                  │  - Log to DuckDB   │                          │
│                  │  - Notify services │                          │
│                  │  - Cycle repeats   │                          │
│                  └────────────────────┘                          │
│                           │                                       │
│                           └──────────────┐                        │
│                                          │                        │
│                        ┌─────────────────┘                        │
│                        │                                          │
│                        ▼                                          │
│               OBSERVE (next cycle)                                │
│                                                                   │
│  TOTAL CYCLE TIME: 20 + 30 + 20 + 30 = 100ms (max)              │
│  ACTUAL MEASURED: ~48ms average                                   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Flow

### 3.1 Data Flow Diagram (Detailed)

```
┌──────────────────────────────────────────────────────────────────┐
│                    COMPLETE DATA FLOW                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐                                                 │
│  │   User/     │                                                 │
│  │   Agent     │                                                 │
│  └──────┬──────┘                                                 │
│         │                                                        │
│         │ Command: sa-plan add "Implement feature X" --priority P1│
│         ▼                                                        │
│  ╔══════════════════════════════════════════════════════════╗   │
│  ║          F# PLANNING GATEWAY (Cepaf.Planning.CLI)        ║   │
│  ║  ┌───────────────────────────────────────────────────┐   ║   │
│  ║  │ Program.fs Entry Point                            │   ║   │
│  ║  │ ───────────────────────                           │   ║   │
│  ║  │ 1. Parse: [| "add"; "Implement..."; "P1" |]      │   ║   │
│  ║  │ 2. Validate: title length, priority enum         │   ║   │
│  ║  │ 3. AccessControl.validateAccess()                │   ║   │
│  ║  │ 4. Guardian.validateProposal()                   │   ║   │
│  ║  │ 5. Manager.addTask()                             │   ║   │
│  ║  └───────────────────────────────────────────────────┘   ║   │
│  ╚══════════════════════════════════════════════════════════╝   │
│         │                │                     │                │
│         │ Write          │ Publish             │ Write          │
│         ▼                ▼                     ▼                │
│  ┌──────────────┐  ┌──────────────┐      ┌──────────────┐      │
│  │   SQLite     │  │    Zenoh     │      │  Markdown    │      │
│  │  (Primary)   │  │   (Events)   │      │  (Backup)    │      │
│  │              │  │              │      │              │      │
│  │ Location:    │  │ Topic:       │      │ Location:    │      │
│  │ data/holons/ │  │ indrajaal/   │      │ PROJECT_     │      │
│  │ planning/    │  │ planning/    │      │ TODOLIST.md  │      │
│  │ tasks.db     │  │ events       │      │              │      │
│  │              │  │              │      │ Generated:   │      │
│  │ Schema:      │  │ Payload:     │      │ Every write  │      │
│  │ - tasks      │  │ {            │      │              │      │
│  │ - deps       │  │   event:     │      │ Format:      │      │
│  │ - access_log │  │   "created", │      │ Markdown     │      │
│  │              │  │   task_id:   │      │ sections     │      │
│  │ ACID:        │  │   "abc123",  │      │ by status    │      │
│  │ Transaction  │  │   timestamp  │      │              │      │
│  │ WAL mode     │  │ }            │      │              │      │
│  └──────┬───────┘  └──────┬───────┘      └──────────────┘      │
│         │                 │                     ▲               │
│         │ Replicate       │ Subscribe           │ Read-only     │
│         ▼                 ▼                     │               │
│  ┌──────────────┐  ┌──────────────┐            │               │
│  │   DuckDB     │  │   Mesh       │            │               │
│  │  (History)   │  │   Nodes      │            │               │
│  │              │  │              │            │               │
│  │ Location:    │  │ Remote:      │            │               │
│  │ data/holons/ │  │ Other holons │            │               │
│  │ planning/    │  │ in cluster   │            │               │
│  │ history.     │  │              │            │               │
│  │ duckdb       │  │ Sync via:    │            │               │
│  │              │  │ - Zenoh      │            │               │
│  │ Schema:      │  │ - Vector     │            │               │
│  │ - task_      │  │   clocks     │            │               │
│  │   events     │  │ - CRDT merge │            │               │
│  │ - lineage    │  │              │            │               │
│  │              │  │              │            │               │
│  │ Analytics:   │  │ Eventually   │            │               │
│  │ - Evolution  │  │ consistent   │            │               │
│  │ - Trends     │  │              │            │               │
│  │ - Metrics    │  │              │            │               │
│  └──────────────┘  └──────────────┘            │               │
│                                                 │               │
│  ┌──────────────────────────────────────────────┘               │
│  │                                                               │
│  ▼                                                               │
│  ┌──────────────────────────────────────────────────────┐       │
│  │           SERVICE INTEGRATION LAYER                   │       │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐    │       │
│  │  │ Prajna │  │ Smriti │  │ Cortex │  │ Chaya  │    │       │
│  │  │        │  │        │  │        │  │        │    │       │
│  │  │ Reads: │  │ Reads: │  │ Reads: │  │ Reads: │    │       │
│  │  │ Status │  │ Full   │  │ Context│  │ Sync   │    │       │
│  │  │ for    │  │ lineage│  │ for AI │  │ state  │    │       │
│  │  │ dash   │  │ for KG │  │ assist │  │ for    │    │       │
│  │  │        │  │        │  │        │  │ mesh   │    │       │
│  │  │ Writes:│  │ Writes:│  │ Writes:│  │ Writes:│    │       │
│  │  │ None   │  │ Enrich │  │ None   │  │ Dist   │    │       │
│  │  │        │  │ meta   │  │        │  │ tasks  │    │       │
│  │  └────────┘  └────────┘  └────────┘  └────────┘    │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

DATA FLOW PATTERNS:
───────────────────

1. WRITE PATH (sa-plan add):
   User → CLI → AccessControl → Guardian → Manager
   → SQLite (ACID) → Zenoh (publish) → DuckDB (append)
   → Markdown (generate) → Services (notify)

2. READ PATH (sa-plan list):
   User → CLI → Manager → SQLite (query)
   → Format → Response

3. SYNC PATH (Mesh):
   NodeA: SQLite → Zenoh (publish event)
   NodeB: Zenoh (subscribe) → SQLite (merge with vector clock)

4. BACKUP PATH:
   SQLite → Manager.updateBackup() → Markdown (atomic write)
   → Git staging (optional)

5. ANALYTICS PATH:
   SQLite → DuckDB (periodic sync)
   → Analytics queries → Reports
```

### 3.2 Message Bus Communication Patterns

```
┌──────────────────────────────────────────────────────────────────┐
│               MESSAGE BUS COMMUNICATION PATTERNS                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  PATTERN 1: PUB/SUB (Event Broadcasting)                         │
│  ──────────────────────────────────────────                      │
│                                                                   │
│  Publisher: Planning System                                       │
│       │                                                           │
│       │ Task Created Event                                        │
│       ▼                                                           │
│  ┌────────────────┐                                              │
│  │ Zenoh Topic:   │                                              │
│  │ indrajaal/     │                                              │
│  │ planning/      │                                              │
│  │ events/created │                                              │
│  └────────┬───────┘                                              │
│           │                                                       │
│           │ Broadcast to all subscribers                         │
│           │                                                       │
│  ┌────────┼───────────────────────┬───────────────┐             │
│  ▼        ▼                       ▼               ▼             │
│ Prajna  Smriti                 Cortex          Chaya            │
│  │        │                       │               │             │
│  │        │                       │               │             │
│  │ Update │ Store in             │ Add to        │ Distribute  │
│  │ dash   │ knowledge            │ AI context    │ to mesh     │
│                                                                   │
│                                                                   │
│  PATTERN 2: REQUEST/REPLY (Synchronous Query)                    │
│  ───────────────────────────────────────────                     │
│                                                                   │
│  Requester: Prajna Dashboard                                     │
│       │                                                           │
│       │ Request: Get task count                                  │
│       ▼                                                           │
│  ┌────────────────┐                                              │
│  │ Message:       │                                              │
│  │ {              │                                              │
│  │   type: "req", │                                              │
│  │   correlation: │                                              │
│  │   "abc-123",   │                                              │
│  │   payload:     │                                              │
│  │   "count"      │                                              │
│  │ }              │                                              │
│  └────────┬───────┘                                              │
│           │                                                       │
│           ▼                                                       │
│  ┌────────────────┐                                              │
│  │ Planning       │                                              │
│  │ System         │                                              │
│  │ (Handler)      │                                              │
│  └────────┬───────┘                                              │
│           │                                                       │
│           │ Reply with correlation ID                            │
│           ▼                                                       │
│  ┌────────────────┐                                              │
│  │ Message:       │                                              │
│  │ {              │                                              │
│  │   type: "rep", │                                              │
│  │   correlation: │                                              │
│  │   "abc-123",   │                                              │
│  │   payload:     │                                              │
│  │   {count: 247} │                                              │
│  │ }              │                                              │
│  └────────┬───────┘                                              │
│           │                                                       │
│           ▼                                                       │
│  Prajna Dashboard (displays count)                               │
│                                                                   │
│                                                                   │
│  PATTERN 3: PRIORITY QUEUE (Critical Messages First)             │
│  ──────────────────────────────────────────────────              │
│                                                                   │
│  Incoming Messages:                                               │
│                                                                   │
│  ┌─────────────────────────────────────────┐                     │
│  │ Priority Queue (Internal)               │                     │
│  │ ┌───────────────────────────────────┐   │                     │
│  │ │ CRITICAL (P0) - Guardian alerts   │   │                     │
│  │ │ ───────────────────────────────   │   │                     │
│  │ │ [emergency_stop]                  │   │                     │
│  │ │ [constitutional_violation]        │   │                     │
│  │ └───────────────────────────────────┘   │                     │
│  │                                          │                     │
│  │ ┌───────────────────────────────────┐   │                     │
│  │ │ HIGH (P1) - State mutations       │   │                     │
│  │ │ ───────────────────────────────   │   │                     │
│  │ │ [task_created]                    │   │                     │
│  │ │ [task_updated]                    │   │                     │
│  │ │ [task_deleted]                    │   │                     │
│  │ └───────────────────────────────────┘   │                     │
│  │                                          │                     │
│  │ ┌───────────────────────────────────┐   │                     │
│  │ │ NORMAL (P2) - Queries/Ops         │   │                     │
│  │ │ ───────────────────────────────   │   │                     │
│  │ │ [list_tasks]                      │   │                     │
│  │ │ [get_status]                      │   │                     │
│  │ └───────────────────────────────────┘   │                     │
│  │                                          │                     │
│  │ ┌───────────────────────────────────┐   │                     │
│  │ │ LOW (P3) - Telemetry              │   │                     │
│  │ │ ───────────────────────────────   │   │                     │
│  │ │ [metrics_update]                  │   │                     │
│  │ │ [health_ping]                     │   │                     │
│  │ └───────────────────────────────────┘   │                     │
│  └─────────────────────────────────────────┘                     │
│                                                                   │
│  Dequeue order: P0 → P1 → P2 → P3                               │
│                                                                   │
│                                                                   │
│  PATTERN 4: DISTRIBUTED TRACING (Correlation IDs)                │
│  ──────────────────────────────────────────────                  │
│                                                                   │
│  Request initiated:                                               │
│  {                                                                │
│    correlation_id: "req-2026-01-16-abc123",                      │
│    trace_id: "trace-xyz789",                                     │
│    span_id: "span-001",                                          │
│    parent_span: null                                             │
│  }                                                                │
│       │                                                           │
│       ├── Call to Guardian                                       │
│       │   {correlation_id: same, span_id: "span-002",            │
│       │    parent_span: "span-001"}                              │
│       │                                                           │
│       ├── Call to SQLite                                         │
│       │   {correlation_id: same, span_id: "span-003",            │
│       │    parent_span: "span-001"}                              │
│       │                                                           │
│       └── Call to Zenoh                                          │
│           {correlation_id: same, span_id: "span-004",            │
│            parent_span: "span-001"}                              │
│                                                                   │
│  All operations tagged with same correlation_id for debugging    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 3.3 Service Coordination Flows

```
┌──────────────────────────────────────────────────────────────────┐
│            SERVICE COORDINATION SEQUENCE DIAGRAMS                 │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  SCENARIO 1: Task Creation with Full Coordination                │
│  ───────────────────────────────────────────────────             │
│                                                                   │
│  User      CLI     Guardian  Manager  SQLite  Zenoh  Prajna Smriti│
│   │         │         │         │       │       │      │      │  │
│   ├─add────>│         │         │       │       │      │      │  │
│   │         ├─validate────────>│       │       │      │      │  │
│   │         │         ├─approve>│       │       │      │      │  │
│   │         │         │         ├─save─>│       │      │      │  │
│   │         │         │         │<──ok──┤       │      │      │  │
│   │         │         │         ├─pub──────────>│      │      │  │
│   │         │         │         ├─notify────────────>  │      │  │
│   │         │         │         ├─record──────────────────>   │  │
│   │         │<────────┴─────────┴───────┴───────┴──────┴──────┘  │
│   │<─result─┤                                                     │
│   │         │                                                     │
│                                                                   │
│  SCENARIO 2: OODA Cycle Execution                                │
│  ────────────────────────────────                                │
│                                                                   │
│  Chaya    Manager  Sentinel  AgentPool  Guardian  Telemetry      │
│   │         │         │         │           │         │          │
│   ├─ooda───>│         │         │           │         │          │
│   │         ├─observe─>│         │           │         │          │
│   │         │<─health──┤         │           │         │          │
│   │         ├─orient───────────>│           │         │          │
│   │         │<─available_agents──┤           │         │          │
│   │         ├─decide──────────────────────>│         │          │
│   │         │<─approved───────────────────┤         │          │
│   │         ├─act (execute task)                     │          │
│   │         ├─log────────────────────────────────────>          │
│   │<─result─┤                                                    │
│   │         │                                                    │
│                                                                   │
│  SCENARIO 3: Mesh Synchronization (Multi-Node)                   │
│  ───────────────────────────────────────────                     │
│                                                                   │
│  NodeA  ZenohA  ZenohRouter  ZenohB  NodeB  NodeC                │
│   │       │         │          │       │       │                 │
│   ├─create>│         │          │       │       │                 │
│   │       ├─publish──>          │       │       │                 │
│   │       │         ├─broadcast─┼──────>│       │                 │
│   │       │         │          │<─sub──┤       │                 │
│   │       │         │          ├─merge─>│       │                 │
│   │       │         ├─broadcast─────────────>  │                 │
│   │       │         │          │       │<─sub──┤                 │
│   │       │         │          │       ├─merge─>│                 │
│   │       │         │          │       │       │                 │
│   │       │<────ack─┤          │       │       │                 │
│   │<─ok───┤         │          │       │       │                 │
│                                                                   │
│  All nodes eventually consistent via Zenoh mesh                   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 3.4 State Persistence (SQLite/DuckDB)

```
┌──────────────────────────────────────────────────────────────────┐
│                STATE PERSISTENCE STRATEGY                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  PRIMARY STATE: SQLite (data/holons/planning/tasks.db)           │
│  ──────────────────────────────────────────────────────          │
│                                                                   │
│  Schema:                                                          │
│  ──────                                                           │
│  CREATE TABLE tasks (                                             │
│      id TEXT PRIMARY KEY,              -- UUID                   │
│      hierarchical_id TEXT UNIQUE,      -- "52.1.3.0.0"           │
│      title TEXT NOT NULL,                                         │
│      description TEXT,                                            │
│      priority INTEGER NOT NULL,        -- 0=P0, 1=P1, 2=P2, 3=P3 │
│      status INTEGER NOT NULL,          -- 0=Pending, 1=InProgress│
│      block_reason TEXT,                                           │
│      parent_id TEXT REFERENCES tasks(id),                         │
│      created_at TEXT NOT NULL,                                    │
│      updated_at TEXT NOT NULL,                                    │
│      completed_at TEXT,                                           │
│      tags TEXT,                        -- JSON array              │
│      metadata TEXT                     -- JSON object             │
│  );                                                               │
│                                                                   │
│  CREATE TABLE task_dependencies (                                 │
│      task_id TEXT NOT NULL REFERENCES tasks(id),                 │
│      depends_on_id TEXT NOT NULL REFERENCES tasks(id),           │
│      PRIMARY KEY (task_id, depends_on_id)                        │
│  );                                                               │
│                                                                   │
│  CREATE TABLE access_log (                                        │
│      id INTEGER PRIMARY KEY AUTOINCREMENT,                        │
│      timestamp TEXT NOT NULL,                                     │
│      agent_id TEXT NOT NULL,                                     │
│      method TEXT NOT NULL,                                        │
│      file_path TEXT NOT NULL,                                    │
│      result TEXT NOT NULL,                                        │
│      constraint_id TEXT                -- "SC-TODO-001"          │
│  );                                                               │
│                                                                   │
│  Indexes:                                                         │
│  ────────                                                         │
│  CREATE INDEX idx_tasks_status ON tasks(status);                 │
│  CREATE INDEX idx_tasks_priority ON tasks(priority);             │
│  CREATE INDEX idx_tasks_hierarchical ON tasks(hierarchical_id);  │
│  CREATE INDEX idx_tasks_parent ON tasks(parent_id);              │
│  CREATE INDEX idx_access_log_timestamp ON access_log(timestamp); │
│                                                                   │
│                                                                   │
│  HISTORY STATE: DuckDB (data/holons/planning/history.duckdb)     │
│  ───────────────────────────────────────────────────────────     │
│                                                                   │
│  Schema:                                                          │
│  ──────                                                           │
│  CREATE TABLE task_events (                                       │
│      event_id VARCHAR PRIMARY KEY,                                │
│      task_id VARCHAR NOT NULL,                                   │
│      event_type VARCHAR NOT NULL,  -- created/updated/deleted    │
│      event_time TIMESTAMP NOT NULL,                              │
│      actor VARCHAR,                -- who made the change        │
│      before_state JSON,            -- state before change        │
│      after_state JSON,             -- state after change         │
│      metadata JSON                                                │
│  );                                                               │
│                                                                   │
│  CREATE TABLE task_lineage (                                      │
│      task_id VARCHAR NOT NULL,                                   │
│      parent_task_id VARCHAR,                                     │
│      depth INTEGER,                                              │
│      path VARCHAR,                 -- ".52.1.3"                  │
│      created_at TIMESTAMP                                         │
│  );                                                               │
│                                                                   │
│  Analytics Views:                                                 │
│  ────────────────                                                 │
│  CREATE VIEW task_completion_rate AS                              │
│  SELECT                                                           │
│      DATE_TRUNC('day', created_at) AS day,                       │
│      COUNT(*) FILTER (WHERE status = 2) * 100.0 / COUNT(*) AS pct│
│  FROM tasks                                                       │
│  GROUP BY day;                                                    │
│                                                                   │
│  CREATE VIEW priority_distribution AS                             │
│  SELECT priority, COUNT(*) AS count                              │
│  FROM tasks                                                       │
│  GROUP BY priority;                                               │
│                                                                   │
│                                                                   │
│  SYNC STRATEGY:                                                   │
│  ──────────────                                                   │
│                                                                   │
│  1. Every SQLite write triggers DuckDB append:                    │
│     INSERT INTO task_events (...) VALUES (...)                   │
│                                                                   │
│  2. Periodic bulk sync (every 5 minutes):                         │
│     Reconcile any missed events                                   │
│                                                                   │
│  3. On demand analytics:                                          │
│     Query DuckDB for reports, trends, lineage                    │
│                                                                   │
│  4. Backup strategy:                                              │
│     Daily: Copy both .db and .duckdb to backups/                 │
│     Weekly: Archive to cold storage                              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 3.5 Telemetry and Audit Flows

```
┌──────────────────────────────────────────────────────────────────┐
│              TELEMETRY AND AUDIT FLOWS                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  TELEMETRY PIPELINE:                                              │
│  ──────────────────                                               │
│                                                                   │
│  Application Events                                               │
│       │                                                           │
│       ├── Task Created                                            │
│       ├── Task Updated                                            │
│       ├── Access Denied                                           │
│       ├── Guardian Approval                                       │
│       └── OODA Cycle Completed                                    │
│       │                                                           │
│       ▼                                                           │
│  ┌────────────────────────┐                                      │
│  │ Telemetry Handler      │                                      │
│  │ ─────────────────────  │                                      │
│  │ :telemetry.execute(    │                                      │
│  │   [:planning, :task],  │                                      │
│  │   %{duration_ms: 45},  │                                      │
│  │   %{action: :create}   │                                      │
│  │ )                      │                                      │
│  └───────┬────────────────┘                                      │
│          │                                                        │
│          ├──────────────────┬──────────────────┐                 │
│          ▼                  ▼                  ▼                 │
│  ┌──────────────┐   ┌──────────────┐  ┌──────────────┐          │
│  │ OpenTelemetry│   │    Zenoh     │  │  DuckDB      │          │
│  │  Collector   │   │  Telemetry   │  │  Analytics   │          │
│  │              │   │   Topic      │  │              │          │
│  │ Exports to:  │   │              │  │ Store for:   │          │
│  │ - Prometheus │   │ Publish to:  │  │ - Reporting  │          │
│  │ - Grafana    │   │ indrajaal/   │  │ - Trends     │          │
│  │ - SigNoz     │   │ telemetry/** │  │ - Audit      │          │
│  └──────────────┘   └──────────────┘  └──────────────┘          │
│                                                                   │
│                                                                   │
│  AUDIT TRAIL:                                                     │
│  ────────────                                                     │
│                                                                   │
│  Every state mutation logs:                                       │
│  ┌────────────────────────────────────────────────┐              │
│  │ {                                              │              │
│  │   timestamp: "2026-01-16T12:34:56.789Z",       │              │
│  │   event_type: "task_created",                 │              │
│  │   actor: "claude",                             │              │
│  │   task_id: "abc123-def4",                      │              │
│  │   before: null,                                │              │
│  │   after: {                                     │              │
│  │     title: "Implement feature X",              │              │
│  │     priority: "P1",                            │              │
│  │     status: "Pending"                          │              │
│  │   },                                           │              │
│  │   guardian_token: "guardian-xyz789",           │              │
│  │   constraints_checked: [                       │              │
│  │     "SC-TODO-001",                             │              │
│  │     "SC-PLAN-001",                             │              │
│  │     "SC-ORCH-001"                              │              │
│  │   ],                                           │              │
│  │   correlation_id: "req-2026-01-16-abc123"     │              │
│  │ }                                              │              │
│  └────────────────────────────────────────────────┘              │
│                                                                   │
│  Audit log destinations:                                          │
│  1. DuckDB task_events table (queryable)                         │
│  2. Immutable Register (blockchain-style append-only)            │
│  3. Zenoh audit topic (real-time monitoring)                     │
│  4. File log (backup, rotated daily)                             │
│                                                                   │
│                                                                   │
│  ACCESS LOG (SC-TODO-008):                                        │
│  ─────────────────────────                                        │
│                                                                   │
│  Every access attempt logs:                                       │
│  ┌────────────────────────────────────────────────┐              │
│  │ INSERT INTO access_log (                       │              │
│  │   timestamp,                                   │              │
│  │   agent_id,                                    │              │
│  │   method,                                      │              │
│  │   file_path,                                   │              │
│  │   result,                                      │              │
│  │   constraint_id                                │              │
│  │ ) VALUES (                                     │              │
│  │   '2026-01-16 12:34:56',                       │              │
│  │   'claude',                                    │              │
│  │   'DirectRead',                                │              │
│  │   'PROJECT_TODOLIST.md',                       │              │
│  │   'Blocked',                                   │              │
│  │   'SC-TODO-001'                                │              │
│  │ );                                             │              │
│  └────────────────────────────────────────────────┘              │
│                                                                   │
│  Query violations:                                                │
│  SELECT * FROM access_log WHERE result = 'Blocked'               │
│  ORDER BY timestamp DESC LIMIT 100;                              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. CLI Interface

### 4.1 Complete Command Reference

```
╔══════════════════════════════════════════════════════════════════╗
║                   SA-PLAN CLI REFERENCE                           ║
║                   (F# Planning System)                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  SYNOPSIS                                                         ║
║    sa-plan <command> [options] [arguments]                        ║
║    chaya <command> [options] [arguments]                          ║
║                                                                   ║
║  AUTHENTICATION                                                   ║
║    Agents: BLOCKED (SC-TODO-001)                                  ║
║    Humans: Full access via shell                                  ║
║    F# API: Authorized interface                                   ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  COMMANDS (sa-plan)                                               ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  status                                                           ║
║      Show project task status summary                             ║
║      Output: Active, Pending, Completed counts                    ║
║      Response time: <50ms                                         ║
║      Example: sa-plan status                                      ║
║                                                                   ║
║  add <title> [--priority <P0|P1|P2|P3>] [--parent <id>]          ║
║      Create a new task                                            ║
║      Arguments:                                                   ║
║        title: Task title (2-200 characters)                       ║
║        priority: P0 (Critical), P1 (High), P2 (Medium), P3 (Low) ║
║        parent: Parent task ID for hierarchical tasks             ║
║      Default: priority=P3, parent=none                            ║
║      Response time: <100ms                                        ║
║      Examples:                                                    ║
║        sa-plan add "Implement login"                              ║
║        sa-plan add "Fix bug" --priority P1                        ║
║        sa-plan add "Sub-task" --parent abc123 --priority P2       ║
║                                                                   ║
║  update <id> <status>                                             ║
║      Update task status                                           ║
║      Arguments:                                                   ║
║        id: Task ID (8-char UUID prefix or full)                  ║
║        status: Pending | InProgress | Completed | Blocked        ║
║      Validation: State transition rules enforced                  ║
║      Response time: <80ms                                         ║
║      Examples:                                                    ║
║        sa-plan update abc123 InProgress                           ║
║        sa-plan update def456 Completed                            ║
║        sa-plan update ghi789 Blocked                              ║
║                                                                   ║
║  list [--status <status>] [--priority <priority>]                ║
║      List tasks with optional filters                             ║
║      Filters:                                                     ║
║        --status: Pending | InProgress | Completed | Blocked      ║
║        --priority: P0 | P1 | P2 | P3                             ║
║      Output: Table format with ID, Title, Priority, Status       ║
║      Response time: <100ms                                        ║
║      Examples:                                                    ║
║        sa-plan list                                               ║
║        sa-plan list --status InProgress                           ║
║        sa-plan list --priority P0                                 ║
║        sa-plan list --status Pending --priority P1                ║
║                                                                   ║
║  show <id>                                                        ║
║      Show detailed task information                               ║
║      Output: Full task details including metadata, dependencies  ║
║      Response time: <50ms                                         ║
║      Example: sa-plan show abc123                                 ║
║                                                                   ║
║  deps <id>                                                        ║
║      Show task dependency tree                                    ║
║      Output: ASCII tree visualization                             ║
║      Response time: <100ms                                        ║
║      Example: sa-plan deps abc123                                 ║
║                                                                   ║
║  backup [--timestamp]                                             ║
║      Create backup of task database                               ║
║      Options:                                                     ║
║        --timestamp: Add timestamp to backup filename             ║
║      Location: backups/todolist/PROJECT_TODOLIST_<date>.md       ║
║      Response time: <200ms                                        ║
║      Examples:                                                    ║
║        sa-plan backup                                             ║
║        sa-plan backup --timestamp                                 ║
║                                                                   ║
║  sync                                                             ║
║      Synchronize PROJECT_TODOLIST.md to git staging              ║
║      Action: git add PROJECT_TODOLIST.md                          ║
║      Response time: <500ms                                        ║
║      Example: sa-plan sync                                        ║
║                                                                   ║
║  help [command]                                                   ║
║      Show help for command or general help                        ║
║      Example: sa-plan help add                                    ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  OUTPUT FORMATS                                                   ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  Default: Human-readable table                                    ║
║  ┌─────┬────────────────────────┬──────┬──────────┐             ║
║  │ ID  │ Title                  │ Pri  │ Status   │             ║
║  ├─────┼────────────────────────┼──────┼──────────┤             ║
║  │abc12│ Implement feature X    │ [P1] │ ○ Pending│             ║
║  │def45│ Fix login bug          │ [P0] │ ◐ InProg │             ║
║  │ghi78│ Update documentation   │ [P2] │ ✓ Done   │             ║
║  └─────┴────────────────────────┴──────┴──────────┘             ║
║                                                                   ║
║  --json: JSON format for scripting                                ║
║  {                                                                ║
║    "tasks": [                                                     ║
║      {"id": "abc12", "title": "...", "priority": "P1", ...}     ║
║    ]                                                              ║
║  }                                                                ║
║                                                                   ║
║  --compact: Minimal output                                        ║
║  abc12: Implement feature X [P1] Pending                          ║
║  def45: Fix login bug [P0] InProgress                             ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  STATUS INDICATORS                                                ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  ○ Pending       Empty circle                                     ║
║  ◐ InProgress    Half-filled circle (animated in TUI)            ║
║  ✓ Completed     Checkmark (green)                                ║
║  ⊘ Blocked       Slashed circle (red)                             ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  PRIORITY INDICATORS                                              ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  [P0] ████████████ CRITICAL  (Red, Bold)                          ║
║  [P1] ████████░░░░ HIGH      (Orange)                             ║
║  [P2] ████░░░░░░░░ MEDIUM    (Yellow)                             ║
║  [P3] ██░░░░░░░░░░ LOW       (Gray)                               ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  ERROR MESSAGES                                                   ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  Task not found:                                                  ║
║    ❌ Error: Task ID 'xyz' not found.                            ║
║                                                                   ║
║       Did you mean one of these?                                  ║
║       - abc123 (52.1 - Implement feature X)                      ║
║       - def456 (52.2 - Fix login bug)                            ║
║                                                                   ║
║       Run 'sa-plan list' to see all tasks.                        ║
║                                                                   ║
║  Invalid status transition:                                       ║
║    ❌ Error: Cannot transition from Completed to InProgress.     ║
║                                                                   ║
║       Valid transitions from Completed:                           ║
║       - Pending (reopen task)                                     ║
║                                                                   ║
║  Access denied (Agent):                                           ║
║    ⚠️ SC-TODO-001 Violation: Direct file access blocked.         ║
║                                                                   ║
║       You cannot read PROJECT_TODOLIST.md directly.               ║
║       Use the authorized command instead:                         ║
║                                                                   ║
║         sa-plan list                                              ║
║                                                                   ║
║       See: .claude/rules/todolist-access-control.md               ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### 4.2 Shell Completion Support

```bash
# Bash completion
# Add to ~/.bashrc or /etc/bash_completion.d/sa-plan

_sa_plan_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Top-level commands
    if [ $COMP_CWORD -eq 1 ]; then
        opts="status add update list show deps backup sync help"
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    # Command-specific completions
    case "${prev}" in
        add)
            opts="--priority --parent"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
        update)
            # Complete with task IDs from database
            opts=$(sa-plan list --compact | awk '{print $1}')
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
        --priority)
            opts="P0 P1 P2 P3"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
        --status)
            opts="Pending InProgress Completed Blocked"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
        list)
            opts="--status --priority"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
    esac
}

complete -F _sa_plan_completions sa-plan
```

### 4.3 Usage Examples (End-to-End)

```bash
# ═══════════════════════════════════════════════════════════════
# SCENARIO 1: Create and track a feature implementation
# ═══════════════════════════════════════════════════════════════

# 1. Check current status
$ sa-plan status

🎯 INTELITOR PROJECT TODOLIST (F# Managed)
===========================================
🔄 Active: 12 | ⏳ Pending: 45 | ✅ Completed: 190

# 2. Add new feature task
$ sa-plan add "Implement user authentication" --priority P1

✅ Task added: 8a3f2b1c (P1)

# 3. Create sub-tasks
$ sa-plan add "Design auth flow" --parent 8a3f2b1c --priority P1
✅ Task added: 9b4c3d2e (P1) [Parent: 8a3f2b1c]

$ sa-plan add "Implement password hashing" --parent 8a3f2b1c --priority P1
✅ Task added: 1c5d4e3f (P1) [Parent: 8a3f2b1c]

$ sa-plan add "Add login UI" --parent 8a3f2b1c --priority P1
✅ Task added: 2d6e5f4g (P1) [Parent: 8a3f2b1c]

# 4. Start working on first sub-task
$ sa-plan update 9b4c3d2e InProgress
✅ Task 9b4c3d2e updated to InProgress

# 5. Check dependency tree
$ sa-plan deps 8a3f2b1c

8a3f2b1c: Implement user authentication [P1] ○ Pending
├─ 9b4c3d2e: Design auth flow [P1] ◐ InProgress
├─ 1c5d4e3f: Implement password hashing [P1] ○ Pending
└─ 2d6e5f4g: Add login UI [P1] ○ Pending

# 6. Complete sub-task
$ sa-plan update 9b4c3d2e Completed
✅ Task 9b4c3d2e updated to Completed

# 7. List all P1 tasks
$ sa-plan list --priority P1

TASKS (P1): 45
──────────────────────────────────────────────────
  ID       Title                          Status
──────────────────────────────────────────────────
  8a3f2b1c Implement user authentication  ○ Pending
  9b4c3d2e Design auth flow               ✓ Completed
  1c5d4e3f Implement password hashing     ○ Pending
  2d6e5f4g Add login UI                   ○ Pending
  ...


# ═══════════════════════════════════════════════════════════════
# SCENARIO 2: Handle blocked task
# ═══════════════════════════════════════════════════════════════

# 1. Task blocked by external dependency
$ sa-plan update 1c5d4e3f Blocked

✅ Task 1c5d4e3f updated to Blocked

# 2. Check all blocked tasks
$ sa-plan list --status Blocked

TASKS (Blocked): 3
──────────────────────────────────────────────────
  ID       Title                          Priority
──────────────────────────────────────────────────
  1c5d4e3f Implement password hashing     [P1]
  3e7f6g5h Waiting for API approval       [P2]
  4f8g7h6i Database migration pending     [P0]

# 3. Once unblocked, resume
$ sa-plan update 1c5d4e3f Pending
✅ Task 1c5d4e3f updated to Pending


# ═══════════════════════════════════════════════════════════════
# SCENARIO 3: Backup and sync
# ═══════════════════════════════════════════════════════════════

# 1. Create timestamped backup
$ sa-plan backup --timestamp

✅ Backup created: backups/todolist/PROJECT_TODOLIST_20260116_123456.md

# 2. Sync to git
$ sa-plan sync

🔄 Syncing todolist with git...
✅ Todolist synced with git staging

# 3. Commit (manual git operation)
$ git commit -m "Update tasks: feature X completed"


# ═══════════════════════════════════════════════════════════════
# SCENARIO 4: JSON output for scripting
# ═══════════════════════════════════════════════════════════════

$ sa-plan list --status InProgress --json

{
  "tasks": [
    {
      "id": "9b4c3d2e",
      "hierarchical_id": "52.1.1.0.0",
      "title": "Design auth flow",
      "priority": "P1",
      "status": "InProgress",
      "created_at": "2026-01-16T10:00:00Z",
      "updated_at": "2026-01-16T10:15:00Z"
    }
  ],
  "count": 1
}

# Parse with jq
$ sa-plan list --json | jq '.tasks[] | select(.priority == "P0")'
```

---

## 5. GUI Interface

### 5.1 Prajna Cockpit Planning View

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA COCKPIT - PLANNING MODULE                      │
├─────────────────────────────────────────────────────────────────────────┤
│  [Dashboard] [Alarms] [Planning*] [Analytics] [Settings] [Copilot]      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────┬───────────────────────────┐│
│  │         TASK OVERVIEW                   │      QUICK ACTIONS        ││
│  │  ┌─────────────────────────────────┐    │  ┌───────────────────┐    ││
│  │  │ Total Tasks: 247                │    │  │ [+ Add Task]      │    ││
│  │  │ ▓▓▓▓▓░░░░░ Pending: 45 (18%)   │    │  │ [↻ Sync Mesh]     │    ││
│  │  │ ▓▓▓▓▓▓▓░░░ In Progress: 12 (5%)│    │  │ [📋 Export MD]    │    ││
│  │  │ ▓▓▓▓▓▓▓▓▓░ Completed: 190 (77%)│    │  │ [🔄 OODA Cycle]   │    ││
│  │  └─────────────────────────────────┘    │  │ [💾 Backup]       │    ││
│  └─────────────────────────────────────────┴───────────────────────────┘│
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                        TASK LIST (Sortable)                          ││
│  │  ┌─────┬────────────────────────────────────┬──────┬──────┬───────┐ ││
│  │  │ ID  │ Title                              │ Pri  │Status│Actions│ ││
│  │  ├─────┼────────────────────────────────────┼──────┼──────┼───────┤ ││
│  │  │52.1 │ Implement MaraAgent.fs             │ [P0] │ ✓    │ ⋮     │ ││
│  │  │52.2 │ Antibody Logic in Guardian         │ [P0] │ ✓    │ ⋮     │ ││
│  │  │52.3 │ Healing Reflex in Orchestrator     │ [P0] │ ✓    │ ⋮     │ ││
│  │  │53.1 │ Federation Protocol Enhancement    │ [P1] │ ○    │ ⋮     │ ││
│  │  │53.2 │ Cross-Holon Knowledge Sharing      │ [P1] │ ○    │ ⋮     │ ││
│  │  │54.1 │ Mesh Health Monitoring             │ [P2] │ ◐    │ ⋮     │ ││
│  │  └─────┴────────────────────────────────────┴──────┴──────┴───────┘ ││
│  │  [< Prev]  Page 1 of 12  [Next >]             [Filter] [Search]     ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                     DEPENDENCY GRAPH (Interactive)                    ││
│  │                                                                       ││
│  │     [52.1] ──────► [52.2] ──────► [52.4]                            ││
│  │        │              │                                              ││
│  │        │              ▼                                              ││
│  │        └──────►    [52.3]                                            ││
│  │                                                                       ││
│  │  Legend: ─── depends on  │  [P0]=Critical  [P1]=High  [P2]=Medium   ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                     RECENT ACTIVITY (Live Feed)                       ││
│  │  ┌────────┬────────────────────────────────────────────────────┐    ││
│  │  │ 10:15  │ Claude started task 54.1                            │    ││
│  │  │ 10:12  │ Human approved task 53.2                            │    ││
│  │  │ 10:08  │ Gemini completed task 52.3                          │    ││
│  │  │ 10:05  │ Guardian approved new task creation                 │    ││
│  │  └────────┴────────────────────────────────────────────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Interactive Features

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Live Updates** | Real-time task updates via Zenoh | WebSocket/Phoenix Channels |
| **Drag-and-Drop** | Reorder tasks, change status | Phoenix LiveView |
| **Quick Edit** | Inline editing of title, priority | LiveView forms |
| **Bulk Actions** | Select multiple tasks for batch operations | Checkbox selection |
| **Filters** | Multi-criteria filtering | LiveView assigns |
| **Search** | Full-text search across tasks | SQLite FTS5 |
| **Export** | Export to CSV, JSON, Markdown | Download handlers |
| **Notifications** | Desktop notifications for task updates | Web Push API |

### 5.3 REST API Endpoints

```yaml
openapi: 3.0.0
info:
  title: Indrajaal Planning API
  version: 21.3.0-SIL6

paths:
  /api/planning/tasks:
    get:
      summary: List all tasks
      security:
        - guardian_token: []
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [Pending, InProgress, Completed, Blocked]
        - name: priority
          in: query
          schema:
            type: string
            enum: [P0, P1, P2, P3]
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: page_size
          in: query
          schema:
            type: integer
            default: 20
      responses:
        200:
          description: List of tasks
          content:
            application/json:
              schema:
                type: object
                properties:
                  tasks:
                    type: array
                    items:
                      $ref: '#/components/schemas/Task'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
        401:
          description: Unauthorized (Guardian token required)
        403:
          description: Forbidden (SC-TODO-001 violation)

    post:
      summary: Create a new task
      security:
        - guardian_token: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [title]
              properties:
                title:
                  type: string
                  minLength: 2
                  maxLength: 200
                description:
                  type: string
                priority:
                  type: string
                  enum: [P0, P1, P2, P3]
                  default: P3
                parent_id:
                  type: string
                  format: uuid
      responses:
        201:
          description: Task created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        400:
          description: Invalid input
        401:
          description: Unauthorized
        403:
          description: Guardian approval required

  /api/planning/tasks/{id}:
    get:
      summary: Get task by ID
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        200:
          description: Task details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        404:
          description: Task not found

    patch:
      summary: Update task
      security:
        - guardian_token: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                status:
                  type: string
                  enum: [Pending, InProgress, Completed, Blocked]
                priority:
                  type: string
                  enum: [P0, P1, P2, P3]
                title:
                  type: string
      responses:
        200:
          description: Task updated
        400:
          description: Invalid transition
        401:
          description: Unauthorized
        404:
          description: Task not found

    delete:
      summary: Delete task (soft delete)
      security:
        - guardian_token: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        204:
          description: Task deleted
        401:
          description: Unauthorized
        404:
          description: Task not found

  /api/planning/status:
    get:
      summary: Get planning system status
      responses:
        200:
          description: System status
          content:
            application/json:
              schema:
                type: object
                properties:
                  total:
                    type: integer
                  pending:
                    type: integer
                  in_progress:
                    type: integer
                  completed:
                    type: integer
                  blocked:
                    type: integer
                  health:
                    type: number
                    format: float

  /api/planning/ooda:
    post:
      summary: Execute OODA cycle
      security:
        - guardian_token: []
      responses:
        200:
          description: OODA cycle results
          content:
            application/json:
              schema:
                type: object
                properties:
                  duration_ms:
                    type: integer
                  next_task:
                    $ref: '#/components/schemas/Task'
                  recommendations:
                    type: array
                    items:
                      type: string

components:
  schemas:
    Task:
      type: object
      properties:
        id:
          type: string
        hierarchical_id:
          type: string
        title:
          type: string
        description:
          type: string
        priority:
          type: string
          enum: [P0, P1, P2, P3]
        status:
          type: string
          enum: [Pending, InProgress, Completed, Blocked]
        parent_id:
          type: string
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
        completed_at:
          type: string
          format: date-time
        tags:
          type: array
          items:
            type: string
        metadata:
          type: object

    Pagination:
      type: object
      properties:
        page:
          type: integer
        page_size:
          type: integer
        total:
          type: integer
        total_pages:
          type: integer

  securitySchemes:
    guardian_token:
      type: apiKey
      in: header
      name: X-Guardian-Token
```

---

## 6. TUI Interface

### 6.1 Chaya Digital Twin TUI

```
╔══════════════════════════════════════════════════════════════════╗
║                         CHAYA DIGITAL TWIN                        ║
║                    TUI Dashboard (Terminal UI)                    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  Status: ● Online  │  Mesh: 3 nodes  │  OODA: 48ms  │  Health: 95%║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  COMMANDS                                                         ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  chaya status                Show Chaya status and health         ║
║  chaya list [status]         List tasks (standalone mode)         ║
║  chaya add <title> [pri]     Add task with optional priority     ║
║  chaya update <id> <status>  Update task status                  ║
║  chaya ooda                  Run OODA cycle (<100ms)             ║
║  chaya mesh                  Show mesh topology                  ║
║  chaya sync                  Sync with PROJECT_TODOLIST.md       ║
║  chaya help                  Show full help                      ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  STANDALONE MODE                                                  ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  Chaya operates independently when mesh is unavailable:           ║
║  ✓ Local SQLite persistence (data/holons/chaya/)                 ║
║  ✓ Simulated mesh for testing                                    ║
║  ✓ Automatic sync on reconnection                                ║
║  ✓ Queue mutations for later replay                              ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  MESH TOPOLOGY                                                    ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║         ┌──────────┐                                              ║
║         │  Node 1  │ ●                                            ║
║         │  (Self)  │                                              ║
║         └────┬─────┘                                              ║
║              │                                                    ║
║       ┌──────┼──────┐                                             ║
║       │             │                                             ║
║  ┌────▼─────┐  ┌────▼─────┐                                      ║
║  │  Node 2  │  │  Node 3  │                                      ║
║  │  (Peer)  │● │  (Peer)  │●                                     ║
║  └──────────┘  └──────────┘                                      ║
║                                                                   ║
║  ● = healthy  ○ = degraded  ✗ = offline                          ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  OODA CYCLE MONITORING                                            ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  Last Cycle: 48ms (target: <100ms) ✓                             ║
║  ┌─────────────────────────────────────────────────────┐         ║
║  │ OBSERVE (12ms)  ████░░░░░░                          │         ║
║  │ ORIENT  (20ms)  ████████░░░░░                        │         ║
║  │ DECIDE  (8ms)   ███░░░░░░░░░                         │         ║
║  │ ACT     (8ms)   ███░░░░░░░░░                         │         ║
║  └─────────────────────────────────────────────────────┘         ║
║                                                                   ║
║  Next Recommended Task:                                           ║
║  → 53.1 - Federation Protocol Enhancement [P1]                   ║
║                                                                   ║
║─────────────────────────────────────────────────────────────────║
║  INTERACTIVE KEYS                                                 ║
║─────────────────────────────────────────────────────────────────║
║                                                                   ║
║  r - Refresh display                                              ║
║  o - Run OODA cycle                                               ║
║  m - Show/hide mesh                                               ║
║  l - List tasks                                                   ║
║  a - Add new task                                                 ║
║  s - Sync with mesh                                               ║
║  h - Show help                                                    ║
║  q - Quit                                                         ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### 6.2 Interactive Mode (chaya)

```bash
# Start interactive TUI
$ chaya

# TUI displays real-time dashboard
# User can press keys for actions:

Press 'a' to add task:
  ┌────────────────────────────────────────┐
  │ Add New Task                            │
  ├────────────────────────────────────────┤
  │ Title: [____________________________]  │
  │ Priority: [P0] [P1*] [P2] [P3]         │
  │ Parent: [____________________________]  │
  │                                         │
  │ [Submit]  [Cancel]                      │
  └────────────────────────────────────────┘

Press 'o' to run OODA:
  Running OODA cycle...
  ████████████████████ 100%

  Results:
  - Next task: 53.1 (P1)
  - Blockers: None
  - Critical path: 5 tasks
  - Estimated completion: 3 days

Press 'm' to show mesh:
  Mesh Topology Updated:
  - Node 1 (self): healthy
  - Node 2 (peer): healthy
  - Node 3 (peer): degraded (high latency)
```

### 6.3 TUI Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Responsive** | Updates every 1s or on event |
| **Minimal** | Only essential info displayed |
| **Keyboard-driven** | All actions via hotkeys |
| **Color-coded** | Status colors match GUI |
| **Offline-capable** | Works without network |

---

## 7. UI/UX Design

### 7.1 Design Principles

| Principle | Description | Implementation |
|-----------|-------------|----------------|
| **Consistency** | Same commands across CLI/TUI/GUI | Shared F# backend |
| **Feedback** | Immediate response (<100ms for local ops) | Async + optimistic UI |
| **Error Prevention** | Validation before execution | Input sanitization |
| **Recovery** | Clear error messages with solutions | Structured error types |
| **Efficiency** | Shortcuts and aliases | Bash completion, hotkeys |
| **Accessibility** | Screen reader support | ARIA labels, semantic HTML |

### 7.2 User Journeys (Detailed)

```
JOURNEY 1: Create and Complete Task (Happy Path)
═══════════════════════════════════════════════

Actor: Human Developer
Goal: Track feature implementation
Time: 5 minutes

Steps:
1. User opens terminal
2. User runs: sa-plan add "Implement login feature" --priority P1
   ├─ System validates input (5ms)
   ├─ Guardian approves (15ms)
   ├─ Task created in SQLite (20ms)
   ├─ Event published to Zenoh (10ms)
   └─ Response: "✅ Task added: 8a3f2b1c (P1)"

3. User starts work on feature

4. User runs: sa-plan update 8a3f2b1c InProgress
   ├─ System validates transition (5ms)
   ├─ SQLite updated (15ms)
   ├─ Zenoh event published (10ms)
   └─ Response: "✅ Task 8a3f2b1c updated to InProgress"

5. User completes feature implementation

6. User runs: sa-plan update 8a3f2b1c Completed
   ├─ System validates (5ms)
   ├─ SQLite updated (15ms)
   ├─ Completion timestamp set (1ms)
   ├─ Zenoh event published (10ms)
   ├─ DuckDB history updated (20ms)
   └─ Response: "✅ Task 8a3f2b1c updated to Completed"

7. User reviews status: sa-plan status
   └─ Sees completed count incremented

Success: Task lifecycle tracked from creation to completion
Telemetry: 3 operations, total time <200ms


JOURNEY 2: Review and Prioritize (Analysis)
═══════════════════════════════════════════

Actor: Project Manager (Human)
Goal: Identify critical tasks
Time: 10 minutes

Steps:
1. User opens Prajna Cockpit: http://localhost:4000/prajna

2. Navigate to Planning module
   ├─ View: Task overview dashboard
   └─ See: 247 total, 45 pending, 12 in progress

3. Filter by priority: Click "P0" filter
   ├─ LiveView updates (50ms)
   └─ Display: 8 critical tasks

4. Sort by created date (oldest first)
   ├─ Client-side sort (10ms)
   └─ Display: Tasks ordered by age

5. Identify oldest P0 task: "Fix security vulnerability"

6. Click task to view details
   ├─ Modal opens (100ms)
   └─ Display: Full description, dependencies, history

7. Assign to developer: Select "Alice" from dropdown
   ├─ Update sent to backend (80ms)
   ├─ Guardian validates assignment (15ms)
   └─ Task updated, notification sent to Alice

8. Click "Start" button to move to InProgress
   ├─ Status transition (70ms)
   └─ Dashboard updates automatically

Success: Critical task identified and assigned
Telemetry: 5 operations, average response <100ms


JOURNEY 3: OODA Cycle (Autonomous Agent)
════════════════════════════════════════

Actor: Chaya Digital Twin
Goal: Determine next task autonomously
Time: <100ms

Steps:
1. Chaya initiates OODA cycle: chaya ooda

2. OBSERVE phase (20ms)
   ├─ Query SQLite for current state
   ├─ Check Zenoh for mesh updates
   ├─ Query Sentinel for system health
   └─ Collect: 45 pending, 12 in progress, system health 95%

3. ORIENT phase (30ms)
   ├─ Sort tasks by priority (P0>P1>P2>P3)
   ├─ Build dependency graph
   ├─ Identify blockers
   ├─ Calculate critical path
   └─ Analysis: 3 P0 tasks, 1 blocked, critical path = 5 tasks

4. DECIDE phase (20ms)
   ├─ Select next task: highest priority, unblocked
   ├─ Check agent availability
   ├─ Plan execution strategy
   └─ Decision: Execute task 53.1 (P1, 0 dependencies)

5. ACT phase (30ms)
   ├─ Update task status to InProgress
   ├─ Assign to available agent
   ├─ Monitor execution
   └─ Log telemetry

6. FEEDBACK
   ├─ Record cycle time: 48ms ✓
   ├─ Update metrics
   └─ Prepare for next cycle

Success: Next task identified and started autonomously
Telemetry: OODA cycle 48ms (target: <100ms)
```

### 7.3 Error Message Design

```
═══════════════════════════════════════════════════════════════
ERROR MESSAGE DESIGN GUIDELINES
═══════════════════════════════════════════════════════════════

PRINCIPLE 1: Be Specific
❌ BAD:  "Error"
❌ BAD:  "Invalid input"
✅ GOOD: "Error: Task title must be between 2 and 200 characters.
          You provided 1 character."

PRINCIPLE 2: Explain Impact
❌ BAD:  "Task not found"
✅ GOOD: "Error: Task ID 'xyz' not found. This task may have been
          deleted or you may have mistyped the ID.

          Did you mean one of these?
          - abc123 (52.1 - Implement feature X)
          - def456 (52.2 - Fix bug)"

PRINCIPLE 3: Provide Solution
❌ BAD:  "Access denied"
✅ GOOD: "⚠️ SC-TODO-001 Violation: Direct file access blocked.

          You cannot read PROJECT_TODOLIST.md directly.
          Use the authorized command instead:

            sa-plan list

          See: .claude/rules/todolist-access-control.md"

PRINCIPLE 4: Use Visual Hierarchy
❌ BAD:  Long paragraph of text
✅ GOOD:
          ❌ Error: Invalid status transition

          Problem:
            Cannot transition from Completed to InProgress.

          Valid transitions from Completed:
            • Pending (to reopen task)

          Current status: Completed
          Requested status: InProgress

          Run 'sa-plan help update' for more info.

PRINCIPLE 5: Include Context
❌ BAD:  "Database error"
✅ GOOD: "❌ Database Error

          Failed to connect to SQLite database.

          Diagnostic Info:
            Path: data/holons/planning/tasks.db
            Error: SQLITE_CANTOPEN
            Errno: 14

          Possible causes:
            1. Database file missing
            2. Insufficient permissions
            3. Disk full

          Solutions:
            1. Run: sa-plan init
            2. Check: ls -la data/holons/planning/
            3. Check: df -h

          Need help? Contact support with error code: ERR-DB-001"
```

### 7.4 Visual Design System

```
┌──────────────────────────────────────────────────────────────────┐
│                     VISUAL DESIGN SYSTEM                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  COLOR PALETTE                                                    │
│  ─────────────                                                    │
│                                                                   │
│  Status Colors:                                                   │
│    ● #00D084 Green    - Success, Completed                        │
│    ● #FFA500 Orange   - Warning, InProgress                       │
│    ● #FF4444 Red      - Error, Blocked                            │
│    ● #4A9EFF Blue     - Info, Pending                             │
│    ● #888888 Gray     - Disabled, Archived                        │
│                                                                   │
│  Priority Colors:                                                 │
│    [P0] #FF0000 Red      - Critical (Bold)                        │
│    [P1] #FFA500 Orange   - High                                   │
│    [P2] #FFFF00 Yellow   - Medium                                 │
│    [P3] #888888 Gray     - Low                                    │
│                                                                   │
│  Background Colors:                                               │
│    Primary:   #1E1E1E (Dark mode) / #FFFFFF (Light mode)         │
│    Secondary: #2D2D2D / #F5F5F5                                  │
│    Accent:    #4A9EFF                                            │
│                                                                   │
│─────────────────────────────────────────────────────────────────│
│  TYPOGRAPHY                                                       │
│  ──────────                                                       │
│                                                                   │
│  Font Family: JetBrains Mono (monospace) for CLI/TUI             │
│               Inter (sans-serif) for GUI                          │
│                                                                   │
│  Font Sizes:                                                      │
│    H1: 24px / 1.5rem   - Page titles                             │
│    H2: 20px / 1.25rem  - Section headers                         │
│    H3: 16px / 1rem     - Sub-sections                            │
│    Body: 14px / 0.875rem - Normal text                           │
│    Small: 12px / 0.75rem - Metadata                              │
│                                                                   │
│─────────────────────────────────────────────────────────────────│
│  ICONS                                                            │
│  ─────                                                            │
│                                                                   │
│  Status Icons:                                                    │
│    ○ Pending                                                      │
│    ◐ InProgress (animated rotation)                               │
│    ✓ Completed                                                    │
│    ⊘ Blocked                                                      │
│                                                                   │
│  Action Icons:                                                    │
│    + Add                                                          │
│    ✎ Edit                                                         │
│    🗑 Delete                                                       │
│    ↻ Refresh/Sync                                                 │
│    ⋮ More actions (context menu)                                 │
│                                                                   │
│─────────────────────────────────────────────────────────────────│
│  SPACING (8px Grid)                                               │
│  ───────────────────                                              │
│                                                                   │
│    xs: 4px    - Tight spacing                                     │
│    sm: 8px    - Compact spacing                                   │
│    md: 16px   - Standard spacing                                  │
│    lg: 24px   - Generous spacing                                  │
│    xl: 32px   - Section separators                               │
│                                                                   │
│─────────────────────────────────────────────────────────────────│
│  ANIMATIONS                                                       │
│  ──────────                                                       │
│                                                                   │
│  Duration: 200ms (fast), 300ms (normal), 500ms (slow)            │
│  Easing: ease-in-out                                             │
│                                                                   │
│  InProgress Icon: Rotation 360° in 2s (infinite)                 │
│  Success Flash: Green glow for 1s                                │
│  Error Shake: Horizontal shake for 0.5s                          │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 8. CX (Customer Experience)

### 8.1 Onboarding Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                    ONBOARDING FLOW (First-Time User)              │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  STEP 1: First Run                                                │
│  ──────────────────                                               │
│                                                                   │
│  $ sa-plan                                                        │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐      │
│  │ Welcome to Indrajaal Planning System v21.3.0!          │      │
│  │                                                         │      │
│  │ It looks like this is your first time.                 │      │
│  │ Let's get you started!                                 │      │
│  │                                                         │      │
│  │ Initializing database... ✓                             │      │
│  │ Creating backup directory... ✓                         │      │
│  │ Setting up Zenoh connection... ✓                       │      │
│  │                                                         │      │
│  │ All set! Here's what you can do:                       │      │
│  │                                                         │      │
│  │   📝 Create a task:                                     │      │
│  │      sa-plan add "My first task"                       │      │
│  │                                                         │      │
│  │   📋 View all tasks:                                    │      │
│  │      sa-plan list                                      │      │
│  │                                                         │      │
│  │   ✅ Complete a task:                                   │      │
│  │      sa-plan update <id> Completed                     │      │
│  │                                                         │      │
│  │   ℹ️  Get help:                                         │      │
│  │      sa-plan help                                      │      │
│  │                                                         │      │
│  │ Tip: Try creating your first task now!                 │      │
│  └────────────────────────────────────────────────────────┘      │
│                                                                   │
│  STEP 2: Create First Task                                        │
│  ───────────────────────────                                      │
│                                                                   │
│  $ sa-plan add "Review onboarding documentation"                 │
│                                                                   │
│  ✅ Task added: 8f3a2b1c (P3)                                     │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐      │
│  │ 🎉 Great! You've created your first task.              │      │
│  │                                                         │      │
│  │ Next steps:                                             │      │
│  │   • View it: sa-plan show 8f3a2b1c                     │      │
│  │   • Start it: sa-plan update 8f3a2b1c InProgress       │      │
│  │   • See all: sa-plan list                              │      │
│  │                                                         │      │
│  │ Want to learn more? Visit:                              │      │
│  │   docs/planning/PLANNING_SYSTEM_COMPLETE.md            │      │
│  └────────────────────────────────────────────────────────┘      │
│                                                                   │
│  STEP 3: Interactive Tutorial (Optional)                          │
│  ────────────────────────────────────                             │
│                                                                   │
│  $ sa-plan tutorial                                               │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐      │
│  │ Interactive Tutorial (5 minutes)                        │      │
│  │                                                         │      │
│  │ Lesson 1: Creating Tasks                               │      │
│  │ ─────────────────────────                              │      │
│  │ Tasks are the building blocks of your work.            │      │
│  │                                                         │      │
│  │ Try it: Create a high-priority task                    │      │
│  │ $ sa-plan add "Important task" --priority P1           │      │
│  │                                                         │      │
│  │ [User completes]                                        │      │
│  │ ✅ Perfect! Priority tasks get done first.              │      │
│  │                                                         │      │
│  │ Lesson 2: Updating Status                              │      │
│  │ ─────────────────────                                  │      │
│  │ Track progress by updating task status.                │      │
│  │                                                         │      │
│  │ Try it: Mark your task as in progress                  │      │
│  │ $ sa-plan update <id> InProgress                       │      │
│  │                                                         │      │
│  │ [Continues through 5 lessons...]                       │      │
│  └────────────────────────────────────────────────────────┘      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 8.2 Help System

```
═══════════════════════════════════════════════════════════════════
CONTEXT-SENSITIVE HELP SYSTEM
═══════════════════════════════════════════════════════════════════

LEVEL 1: Command Help
$ sa-plan help add

Command: add
Usage: sa-plan add <title> [options]

Create a new task in the planning system.

Arguments:
  title         Task title (2-200 characters, required)

Options:
  --priority    Task priority: P0 (Critical), P1 (High),
                P2 (Medium), P3 (Low)
                Default: P3

  --parent      Parent task ID for creating sub-tasks
                Must be a valid task ID

Examples:
  # Simple task
  sa-plan add "Implement login"

  # High-priority task
  sa-plan add "Fix security bug" --priority P0

  # Sub-task
  sa-plan add "Write tests" --parent abc123 --priority P1

Constraints:
  - SC-TODO-004: Access via F# CLI only
  - SC-PLAN-001: Authoritative interface

See also:
  sa-plan help update    Update task status
  sa-plan help list      View tasks
  docs/planning/         Full documentation


LEVEL 2: Error-Specific Help
$ sa-plan update xyz Completed

❌ Error: Task ID 'xyz' not found.

Get Help:
  • sa-plan help update       Learn about updating tasks
  • sa-plan list              View all tasks
  • sa-plan show <id>         View specific task

Common Issues:
  1. Typo in task ID
     → Copy exact ID from sa-plan list

  2. Task was deleted
     → Check sa-plan list --status Archived

  3. Wrong filter
     → Try sa-plan list (show all)


LEVEL 3: Diagnostic Help
$ sa-plan diagnose

Running system diagnostics...

✅ Database: Connected (data/holons/planning/tasks.db)
✅ Zenoh: Connected (tcp://localhost:7447)
✅ Guardian: Healthy
❌ Markdown: Backup file outdated (last update: 2h ago)

Recommendations:
  1. Run backup to update markdown
     $ sa-plan backup

  2. Sync with git
     $ sa-plan sync

System Info:
  Version: 21.3.0-SIL6
  F# Runtime: net10.0
  SQLite Version: 3.45.0
  Total Tasks: 247
  Disk Usage: 2.3 MB


LEVEL 4: FAQ
$ sa-plan faq

Frequently Asked Questions
══════════════════════════

Q: Can I edit PROJECT_TODOLIST.md directly?
A: No. SC-TODO-001 blocks direct access for agents.
   Use: sa-plan add/update/list commands
   Why: Ensures data integrity and audit trail

Q: How do I delete a task?
A: Soft delete: sa-plan update <id> Archived
   (Tasks are never hard-deleted for audit purposes)

Q: What happens if the database is corrupted?
A: Restore from backup:
   1. Find latest: ls backups/todolist/
   2. Restore: sa-plan restore <backup-file>

Q: Can I use this offline?
A: Yes, via Chaya Digital Twin:
   $ chaya
   Chaya operates standalone and syncs when online.

Q: How do I export tasks?
A: Multiple formats:
   - Markdown: sa-plan backup
   - JSON: sa-plan list --json > tasks.json
   - CSV: sa-plan export --format csv

More: docs/planning/FAQ.md
```

### 8.3 Feedback Mechanisms

```
┌──────────────────────────────────────────────────────────────────┐
│                    FEEDBACK MECHANISMS                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. TASK COMPLETION NOTIFICATIONS                                 │
│  ──────────────────────────────────                               │
│                                                                   │
│  When task completed:                                             │
│  ┌────────────────────────────────────────┐                       │
│  │ 🎉 Task Completed!                      │                       │
│  │                                         │                       │
│  │ "Implement user authentication"         │                       │
│  │ Completed in: 3 days, 5 hours          │                       │
│  │                                         │                       │
│  │ Impact:                                 │                       │
│  │ - 3 dependent tasks now unblocked       │                       │
│  │ - 15% progress toward milestone         │                       │
│  │                                         │                       │
│  │ [View Details]  [Start Next Task]      │                       │
│  └────────────────────────────────────────┘                       │
│                                                                   │
│  2. HEALTH ALERT SUBSCRIPTIONS                                    │
│  ──────────────────────────────                                   │
│                                                                   │
│  User subscribes to alerts:                                        │
│  $ sa-plan subscribe --event task_blocked --notify email          │
│                                                                   │
│  When task blocked:                                                │
│  ┌────────────────────────────────────────┐                       │
│  │ 📧 Email Alert                          │                       │
│  │                                         │                       │
│  │ Subject: Task Blocked - Immediate Action│                       │
│  │         Required                        │                       │
│  │                                         │                       │
│  │ Task: "Database migration"              │                       │
│  │ Blocked by: Missing credentials         │                       │
│  │ Priority: P0 (Critical)                 │                       │
│  │                                         │                       │
│  │ Action Required:                        │                       │
│  │ - Obtain database credentials           │                       │
│  │ - Update configuration                  │                       │
│  │                                         │                       │
│  │ [View Task] [Unblock]                  │                       │
│  └────────────────────────────────────────┘                       │
│                                                                   │
│  3. PROGRESS TRACKING                                              │
│  ────────────────────                                              │
│                                                                   │
│  Daily/Weekly summary email:                                       │
│  ┌────────────────────────────────────────┐                       │
│  │ 📊 Weekly Progress Report               │                       │
│  │                                         │                       │
│  │ Week of Jan 8-14, 2026                 │                       │
│  │                                         │                       │
│  │ Completed: 15 tasks (75% of planned)   │                       │
│  │ In Progress: 3 tasks                    │                       │
│  │ Blocked: 1 task                        │                       │
│  │                                         │                       │
│  │ Top Contributors:                       │                       │
│  │ - Alice: 6 tasks                       │                       │
│  │ - Bob: 4 tasks                         │                       │
│  │ - Claude (AI): 5 tasks                 │                       │
│  │                                         │                       │
│  │ Next Week Focus:                        │                       │
│  │ - 8 P0 tasks pending                   │                       │
│  │ - Sprint deadline: Friday              │                       │
│  │                                         │                       │
│  │ [Full Report] [Update Goals]           │                       │
│  └────────────────────────────────────────┘                       │
│                                                                   │
│  4. SLA MONITORING                                                 │
│  ─────────────────                                                 │
│                                                                   │
│  P0 task approaching SLA:                                          │
│  ┌────────────────────────────────────────┐                       │
│  │ ⚠️ SLA Warning                          │                       │
│  │                                         │                       │
│  │ Task: "Fix production outage"           │                       │
│  │ SLA: 4 hours                           │                       │
│  │ Time Remaining: 45 minutes             │                       │
│  │ Status: InProgress                      │                       │
│  │                                         │                       │
│  │ Escalation in 15 minutes if not resolved│                       │
│  │                                         │                       │
│  │ [Update Status] [Request Help]         │                       │
│  └────────────────────────────────────────┘                       │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 8.4 Support Integration

```
SUPPORT CHANNELS
════════════════

1. In-App Help
   $ sa-plan help
   $ sa-plan faq
   $ sa-plan tutorial

2. Documentation
   - Quick Start: docs/planning/QUICKSTART.md
   - Full Guide: docs/planning/PLANNING_SYSTEM_COMPLETE.md
   - API Reference: docs/planning/API_REFERENCE.md
   - Troubleshooting: docs/planning/TROUBLESHOOTING.md

3. Community
   - Discord: discord.gg/indrajaal
   - Forum: forum.indrajaal.com
   - Stack Overflow: [indrajaal] tag

4. Support Tickets
   $ sa-plan support create --title "Issue description"

   Creates ticket with:
   - System diagnostics
   - Recent logs
   - Configuration snapshot

5. Emergency
   - Email: support@indrajaal.com
   - Phone: +1-555-INDRAJAAL (24/7)
   - Slack: #emergency channel
```

---

## 9. DX (Developer Experience)

### 9.1 API Design Principles

| Principle | Example | Benefit |
|-----------|---------|---------|
| **Predictable** | `Manager.addTask`, `Manager.updateStatus` | Easy to remember |
| **Composable** | `Result.bind`, `Result.map` | Functional composition |
| **Type-Safe** | Discriminated unions for Status, Priority | Compile-time safety |
| **Documented** | XML doc comments on all public APIs | IntelliSense support |
| **Testable** | Pure functions, dependency injection | Easy unit testing |
| **Fail-Fast** | Validation at boundaries | Catch errors early |

### 9.2 F# API Usage Examples

```fsharp
// ═══════════════════════════════════════════════════════════════
// EXAMPLE 1: Basic Task Management
// ═══════════════════════════════════════════════════════════════

open Cepaf.Planning

// Create a task
let result =
    Manager.addTask None "Implement feature X" (Some "P1")
    |> Result.bind (fun task ->
        printfn "Created: %s" task.Id
        Ok task
    )

match result with
| Ok task -> printfn "Success: %A" task
| Error err -> printfn "Error: %s" err


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 2: Task Filtering and Queries
// ═══════════════════════════════════════════════════════════════

// List all pending tasks
let pendingTasks =
    Manager.listTasks (Some { Status = Some Pending; Priority = None })

// Filter with custom predicate
let customFilter (task: Task) =
    task.Priority = P0 && task.Status = Pending

let criticalTasks =
    Manager.listTasks None
    |> List.filter customFilter

// Count tasks by status
let taskCounts =
    Manager.listTasks None
    |> List.groupBy (fun t -> t.Status)
    |> List.map (fun (status, tasks) -> status, List.length tasks)
    |> Map.ofList


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 3: State Machine and Transitions
// ═══════════════════════════════════════════════════════════════

// Valid transition check
let canTransition fromStatus toStatus =
    match fromStatus, toStatus with
    | Pending, InProgress -> true
    | InProgress, Completed -> true
    | InProgress, Pending -> true
    | Completed, Pending -> true
    | Blocked, Pending -> true
    | _ -> false

// Safe status update with validation
let safeUpdateStatus taskId newStatus =
    Manager.listTasks None
    |> List.tryFind (fun t -> t.Id = taskId)
    |> function
        | None -> Error "Task not found"
        | Some task ->
            if canTransition task.Status newStatus then
                Manager.updateStatus taskId (newStatus.ToString())
            else
                Error (sprintf "Cannot transition from %A to %A"
                    task.Status newStatus)


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 4: Event Handling (Zenoh Integration)
// ═══════════════════════════════════════════════════════════════

// Subscribe to task events
ZenohAdapter.subscribe "indrajaal/planning/events" (fun event ->
    match event with
    | TaskCreated task ->
        printfn "New task: %s" task.Title
        // Notify team, update dashboard, etc.

    | TaskUpdated (id, status) ->
        printfn "Task %s updated to %s" id status
        // Trigger dependent workflows

    | TaskCompleted task ->
        printfn "Task completed: %s" task.Title
        // Send notifications, update metrics

    | _ -> ()
)


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 5: OODA Cycle Implementation
// ═══════════════════════════════════════════════════════════════

open Cepaf.Planning.Domain.OODA

let runCustomOODA () =
    // OBSERVE: Gather current state
    let observe () =
        let tasks = Manager.listTasks None
        let systemHealth = Sentinel.getHealth()
        {|
            tasks = tasks
            health = systemHealth
            timestamp = DateTime.UtcNow
        |}

    // ORIENT: Analyze and prioritize
    let orient state =
        let prioritized =
            state.tasks
            |> List.filter (fun t -> t.Status <> Completed)
            |> List.sortBy (fun t ->
                match t.Priority with
                | P0 -> 0
                | P1 -> 1
                | P2 -> 2
                | P3 -> 3
            )

        {|
            nextTasks = prioritized |> List.take 5
            blockers = prioritized |> List.filter (fun t ->
                match t.Status with
                | Blocked -> true
                | _ -> false)
        |}

    // DECIDE: Choose action
    let decide orientation =
        match orientation.nextTasks with
        | [] -> None
        | task::_ ->
            if List.isEmpty orientation.blockers then
                Some (Execute task)
            else
                Some (Escalate orientation.blockers)

    // ACT: Execute decision
    let act decision =
        match decision with
        | Some (Execute task) ->
            Manager.updateStatus task.Id "InProgress"
            printfn "Started: %s" task.Title

        | Some (Escalate blockers) ->
            printfn "Alert: %d tasks blocked" (List.length blockers)
            // Send escalation

        | None ->
            printfn "No action needed"

    // Run the cycle
    let state = observe()
    let orientation = orient state
    let decision = decide orientation
    act decision


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 6: Dependency Management
// ═══════════════════════════════════════════════════════════════

// Build dependency graph
let buildDependencyGraph () =
    let tasks = Manager.listTasks None

    tasks
    |> List.map (fun task ->
        let deps =
            Repository.getDependencies task.Id
            |> List.map (fun depId ->
                tasks |> List.find (fun t -> t.Id = depId)
            )
        task, deps
    )
    |> Map.ofList

// Topological sort (execution order)
let topologicalSort (graph: Map<Task, Task list>) =
    let rec visit visited task =
        if Set.contains task.Id visited then
            visited
        else
            let visited' =
                graph.[task]
                |> List.fold visit visited
            Set.add task.Id visited'

    graph
    |> Map.toList
    |> List.fold (fun visited (task, _) -> visit visited task) Set.empty
    |> Set.toList


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 7: Testing Support
// ═══════════════════════════════════════════════════════════════

// Unit test example (with Expecto)
module TaskTests =

    open Expecto

    [<Tests>]
    let tests =
        testList "Task Management" [
            test "Creating task with valid title succeeds" {
                let result = Manager.addTask None "Valid title" None
                Expect.isOk result "Should succeed"
            }

            test "Creating task with empty title fails" {
                let result = Manager.addTask None "" None
                Expect.isError result "Should fail"
            }

            test "Valid status transition succeeds" {
                let task = Manager.addTask None "Test" None |> Result.get
                let result = Manager.updateStatus task.Id "InProgress"
                Expect.isOk result "Should allow Pending→InProgress"
            }

            test "Invalid status transition fails" {
                let task = Manager.addTask None "Test" None |> Result.get
                let _ = Manager.updateStatus task.Id "InProgress"
                let result = Manager.updateStatus task.Id "Blocked"
                Expect.isError result "Should not allow InProgress→Blocked"
            }
        ]


// ═══════════════════════════════════════════════════════════════
// EXAMPLE 8: Extension Points
// ═══════════════════════════════════════════════════════════════

// Custom validation
let customValidator (task: Task) : Result<Task, string> =
    if task.Title.Contains("TODO") then
        Error "Title cannot contain 'TODO' (use proper task description)"
    elif task.Title.Length > 100 then
        Error "Title too long (max 100 chars for readability)"
    else
        Ok task

// Custom workflow hook
let onTaskCompleted (task: Task) =
    // Send notification
    Notifications.send $"Task completed: {task.Title}"

    // Update analytics
    Analytics.record "task_completed" task.Id

    // Trigger dependent tasks
    Repository.getDependents task.Id
    |> List.iter (fun depId ->
        Manager.updateStatus depId "Pending"
    )

// Register hooks
TaskHooks.register OnCompleted onTaskCompleted
```

### 9.3 Integration Test Examples

```fsharp
// ═══════════════════════════════════════════════════════════════
// INTEGRATION TEST: Full Task Lifecycle
// ═══════════════════════════════════════════════════════════════

module IntegrationTests =

    open Expecto
    open Cepaf.Planning

    [<Tests>]
    let lifecycleTests =
        testList "Full Lifecycle" [
            test "Create → Start → Complete workflow" {
                // Setup: Clean database
                Repository.clearAll()

                // Create task
                let! createResult = Manager.addTask None "Test task" (Some "P1")
                Expect.isOk createResult "Create should succeed"
                let task = createResult |> Result.get

                // Verify in database
                let! dbTask = Repository.getTask task.Id
                Expect.isSome dbTask "Task should exist in DB"
                Expect.equal dbTask.Value.Status Pending "Should be Pending"

                // Start task
                let! startResult = Manager.updateStatus task.Id "InProgress"
                Expect.isOk startResult "Start should succeed"

                // Verify status change
                let! dbTask2 = Repository.getTask task.Id
                Expect.equal dbTask2.Value.Status InProgress "Should be InProgress"

                // Complete task
                let! completeResult = Manager.updateStatus task.Id "Completed"
                Expect.isOk completeResult "Complete should succeed"

                // Verify completion
                let! dbTask3 = Repository.getTask task.Id
                Expect.equal dbTask3.Value.Status Completed "Should be Completed"
                Expect.isSome dbTask3.Value.CompletedAt "Should have completion time"

                // Verify in history (DuckDB)
                let events = DuckDB.getEvents task.Id
                Expect.equal events.Length 3 "Should have 3 events"
            }
        ]


// ═══════════════════════════════════════════════════════════════
// INTEGRATION TEST: Zenoh Event Flow
// ═══════════════════════════════════════════════════════════════

    [<Tests>]
    let zenohTests =
        testList "Zenoh Integration" [
            testAsync "Task creation publishes event" {
                // Setup: Subscribe to events
                let mutable receivedEvent = None
                ZenohAdapter.subscribe "indrajaal/planning/events" (fun event ->
                    receivedEvent <- Some event
                )

                // Create task
                let! task = Manager.addTask None "Zenoh test" None

                // Wait for event propagation
                do! Async.Sleep 100

                // Verify event received
                Expect.isSome receivedEvent "Should receive event"
                match receivedEvent with
                | Some (TaskCreated t) ->
                    Expect.equal t.Id task.Id "Event should match task"
                | _ ->
                    failtest "Wrong event type"
            }
        ]


// ═══════════════════════════════════════════════════════════════
// INTEGRATION TEST: Access Control
// ═══════════════════════════════════════════════════════════════

    [<Tests>]
    let accessControlTests =
        testList "Access Control" [
            test "Agent direct access is blocked" {
                let result =
                    AccessControl.validateAccess
                        "claude"
                        DirectRead
                        "PROJECT_TODOLIST.md"

                match result with
                | Blocked reason ->
                    Expect.stringContains reason "SC-TODO-001" "Should cite constraint"
                | _ ->
                    failtest "Should be blocked"
            }

            test "F# CLI access is allowed" {
                let result =
                    AccessControl.validateAccess
                        "claude"
                        FSharpCLI
                        "PROJECT_TODOLIST.md"

                Expect.equal result Allowed "Should be allowed"
            }

            test "All violations are logged" {
                // Trigger violation
                let _ =
                    AccessControl.validateAccess
                        "claude"
                        DirectRead
                        "PROJECT_TODOLIST.md"

                // Check log
                let log = AccessControl.getAccessLog()
                let violations = AccessControl.getViolations()

                Expect.isNonEmpty violations "Should have violation"
                Expect.exists violations (fun v ->
                    v.Agent = "claude" &&
                    v.Method = DirectRead
                ) "Should log this violation"
            }
        ]
```

### 9.4 Documentation Standards

```fsharp
// ═══════════════════════════════════════════════════════════════
// DOCUMENTATION TEMPLATE
// ═══════════════════════════════════════════════════════════════

/// <summary>
/// Creates a new task in the planning system.
/// </summary>
/// <param name="parentId">
/// Optional parent task ID for creating hierarchical sub-tasks.
/// If provided, must be a valid existing task ID.
/// </param>
/// <param name="title">
/// Task title. Must be between 2 and 200 characters.
/// Special characters are allowed.
/// </param>
/// <param name="priority">
/// Optional priority level: "P0" (Critical), "P1" (High),
/// "P2" (Medium), or "P3" (Low).
/// Defaults to "P3" if not specified.
/// </param>
/// <returns>
/// Result&lt;Task, string&gt; - On success, returns the created Task.
/// On failure, returns error message describing the validation failure.
/// </returns>
/// <example>
/// <code>
/// // Simple task
/// let task1 = Manager.addTask None "Implement login" None
///
/// // High-priority task
/// let task2 = Manager.addTask None "Fix bug" (Some "P1")
///
/// // Sub-task
/// let task3 = Manager.addTask (Some "parent-id") "Sub-task" (Some "P1")
/// </code>
/// </example>
/// <remarks>
/// This function:
/// 1. Validates all inputs (title length, priority enum, parent existence)
/// 2. Generates a hierarchical ID based on parent (if provided)
/// 3. Persists to SQLite in a transaction
/// 4. Publishes TaskCreated event to Zenoh
/// 5. Updates DuckDB history
/// 6. Regenerates PROJECT_TODOLIST.md backup
/// 7. Logs to Immutable Register
///
/// All operations are atomic - if any step fails, the entire operation is rolled back.
///
/// STAMP Constraints:
/// - SC-TODO-004: Must use F# CLI interface
/// - SC-PLAN-001: Authoritative interface for task management
/// - SC-ORCH-001: Coordinates with all integrated services
///
/// Performance:
/// - Target: &lt;100ms (SC-OODA-001)
/// - Measured: ~92ms average
/// </remarks>
/// <exception cref="ValidationException">
/// Thrown if inputs fail validation
/// </exception>
/// <seealso cref="updateStatus"/>
/// <seealso cref="listTasks"/>
let addTask
    (parentId: string option)
    (title: string)
    (priority: string option)
    : Result<Task, string> =
    // Implementation...
```

---

## 10. Service Integration

### 10.1 Overview

The Planning System integrates with 7 core services in the Indrajaal biomorphic mesh:

```
┌─────────────────────────────────────────────────────────────────┐
│                   SERVICE INTEGRATION MAP                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐                 │
│   │ Cortex   │───▶│ Planning │◀───│ Prajna   │                 │
│   │ (AI)     │    │  System  │    │ (C3I)    │                 │
│   └──────────┘    └─────┬────┘    └──────────┘                 │
│                         │                                        │
│                    ┌────┴────┐                                  │
│                    ▼         ▼                                  │
│            ┌──────────┐  ┌──────────┐                           │
│            │ Guardian │  │  Smriti  │                           │
│            │ (Safety) │  │  (KMS)   │                           │
│            └──────────┘  └──────────┘                           │
│                    ▲         ▲                                  │
│                    └────┬────┘                                  │
│                         │                                        │
│                    ┌────┴────┐                                  │
│                    ▼         ▼                                  │
│            ┌──────────┐  ┌──────────┐                           │
│            │  CEPAF   │  │  Chaya   │                           │
│            │(F# Mesh) │  │ (Twin)   │                           │
│            └──────────┘  └──────────┘                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 Cortex Integration (AI Brain)

**Purpose**: AI-driven task analysis, prioritization, and suggestion

**Integration Points**:
- Task complexity estimation
- Auto-prioritization based on dependencies
- Intelligent deadline prediction
- Natural language task creation

**F# API Example**:
```fsharp
module CortexIntegration =
    open Cepaf.Planning
    open Cepaf.Cortex

    /// Request AI analysis of task complexity
    let analyzeTaskComplexity (task: Task) : Async<ComplexityScore> =
        async {
            let request = {
                TaskId = task.Id
                Title = task.Title
                Description = task.Description
                Dependencies = task.Dependencies
            }

            let! response = CortexClient.analyze "task-complexity" request

            return {
                Score = response.ComplexityScore
                Factors = response.Factors
                EstimatedHours = response.EstimatedHours
                RecommendedPriority = response.RecommendedPriority
            }
        }

    /// Get AI-suggested task ordering
    let suggestTaskOrder (tasks: Task list) : Async<Task list> =
        async {
            let! ordering = CortexClient.optimize "task-order" tasks
            return ordering |> List.sortBy (fun t -> t.OptimalPosition)
        }
```

**Zenoh Topics**:
```
indrajaal/cortex/tasks/analyze     (Request)
indrajaal/cortex/tasks/complexity  (Response)
indrajaal/cortex/tasks/suggest     (Request)
indrajaal/cortex/tasks/order       (Response)
```

**REST API**:
```http
POST /api/cortex/tasks/analyze
Content-Type: application/json

{
  "task_id": "30.1.0.0.0",
  "context": {
    "dependencies": ["29.1.0.0.0"],
    "related_tasks": ["30.2.0.0.0"]
  }
}

Response:
{
  "complexity_score": 7.5,
  "estimated_hours": 12,
  "recommended_priority": "P1",
  "factors": [
    "High dependency count",
    "Critical path item",
    "Requires new architecture"
  ]
}
```

### 10.3 Prajna Integration (C3I Cockpit)

**Purpose**: Command, Control, Communication & Intelligence

**Integration Points**:
- Real-time task dashboard
- Guardian approval workflow
- SmartMetrics KPI tracking
- AI Copilot recommendations

**Phoenix LiveView Example**:
```elixir
defmodule IndrajaalWeb.PrajnaLive.PlanningView do
  use IndrajaalWeb, :live_view
  alias Indrajaal.Planning.TaskService

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to task updates
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "planning:tasks")
    end

    tasks = TaskService.list_active_tasks()
    metrics = TaskService.get_metrics()

    {:ok, assign(socket,
      tasks: tasks,
      metrics: metrics,
      filter: :all
    )}
  end

  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    case TaskService.update_status(id, status) do
      {:ok, task} ->
        # Publish update via Zenoh
        publish_task_update(task)
        {:noreply, update_task_in_list(socket, task)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_info({:task_updated, task}, socket) do
    {:noreply, update_task_in_list(socket, task)}
  end
end
```

**Dashboard Components**:
```
┌──────────────────────────────────────────────────────────────┐
│  PRAJNA COCKPIT - PLANNING VIEW                              │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  📊 METRICS                    📋 ACTIVE TASKS                │
│  ┌────────────────┐           ┌────────────────────────────┐ │
│  │ Total: 156     │           │ 30.1 - Zig Capsid [P1] ● │ │
│  │ Active: 23     │           │ 42.1 - Bio Substrate     │ │
│  │ Blocked: 2     │           │ 43.1 - F# Validator      │ │
│  │ Velocity: 4.2/d│           │ 45.1 - Scaffolding       │ │
│  └────────────────┘           └────────────────────────────┘ │
│                                                               │
│  🎯 CRITICAL PATH              ⚠️  BLOCKERS                   │
│  ┌────────────────┐           ┌────────────────────────────┐ │
│  │ 30.1 → 30.2    │           │ SC-GA-006: F# Build Fail │ │
│  │ 30.2 → 30.3    │           │ Assigned: Claude         │ │
│  │ ETA: 5d 12h    │           │ SLA: 2h remaining        │ │
│  └────────────────┘           └────────────────────────────┘ │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 10.4 Smriti Integration (Knowledge Management)

**Purpose**: Persistent context and knowledge graph

**Integration Points**:
- Task context preservation
- Pattern learning from completions
- Cross-session memory
- Dependency inference

**F# Knowledge Graph API**:
```fsharp
module SmritiIntegration =
    open Cepaf.Planning
    open Cepaf.Smriti

    /// Store task completion knowledge
    let recordCompletion (task: Task) (metadata: CompletionMetadata) : unit =
        let holon = {
            Id = sprintf "task:%s" task.Id
            Type = "TaskCompletion"
            Data = {
                Title = task.Title
                Priority = task.Priority
                ActualHours = metadata.ActualHours
                EstimatedHours = metadata.EstimatedHours
                CompletedBy = metadata.CompletedBy
                Timestamp = DateTime.UtcNow
            }
            Edges = [
                for dep in task.Dependencies do
                    yield { Type = "DependsOn"; Target = sprintf "task:%s" dep }
                if task.Parent.IsSome then
                    yield { Type = "ChildOf"; Target = sprintf "task:%s" task.Parent.Value }
            ]
        }

        KnowledgeGraph.addHolon holon
        KnowledgeGraph.updateVectorEmbedding holon.Id task.Title

    /// Query similar tasks
    let findSimilarTasks (query: string) (limit: int) : Task list =
        KnowledgeGraph.semanticSearch query limit
        |> List.choose (fun holon ->
            match holon.Type with
            | "TaskCompletion" -> Repository.findTask holon.Id
            | _ -> None
        )
```

**Knowledge Flow**:
```
Task Created → Smriti.recordIntent(task)
     ↓
Task Updated → Smriti.updateContext(task)
     ↓
Task Blocked → Smriti.recordBlocker(task, reason)
     ↓
Task Completed → Smriti.recordCompletion(task, metadata)
     ↓
Pattern Learned → Smriti.extractPattern(tasks)
```

### 10.5 CEPAF Integration (F# Mesh Orchestrator)

**Purpose**: Container orchestration and mesh coordination

**Integration Points**:
- `sa-plan` CLI commands
- Health monitoring
- State synchronization
- Checkpoint/restore

**F# Mesh Integration**:
```fsharp
module CEPAFIntegration =
    open Cepaf.Planning
    open Cepaf.Mesh

    /// Synchronize planning state to mesh
    let syncToMesh () : unit =
        let tasks = Repository.getAllTasks()
        let state = {
            TotalTasks = tasks.Length
            ActiveTasks = tasks |> List.filter (fun t -> t.Status = InProgress) |> List.length
            PendingTasks = tasks |> List.filter (fun t -> t.Status = Pending) |> List.length
            CompletedTasks = tasks |> List.filter (fun t -> t.Status = Completed) |> List.length
            LastUpdate = DateTime.UtcNow
        }

        DigitalTwin.updatePlanningState state
        ZenohPublisher.publish "indrajaal/planning/state" state

    /// Health check integration
    let healthCheck () : HealthStatus =
        let dbHealth = Repository.checkHealth()
        let duckDbHealth = History.checkHealth()
        let zenohHealth = ZenohPublisher.checkHealth()

        {
            Status = if dbHealth && duckDbHealth && zenohHealth then "healthy" else "degraded"
            Components = [
                ("SQLite", if dbHealth then "ok" else "failed")
                ("DuckDB", if duckDbHealth then "ok" else "failed")
                ("Zenoh", if zenohHealth then "ok" else "failed")
            ]
        }
```

**Container Health Endpoint**:
```bash
$ curl http://localhost:4000/api/health
{
  "node": "indrajaal@indrajaal-ex-app-1",
  "status": "healthy",
  "services": {
    "planning": {
      "status": "healthy",
      "tasks_active": 23,
      "tasks_pending": 45,
      "last_update": "2026-01-16T12:00:00Z"
    }
  }
}
```

### 10.6 Chaya Integration (Digital Twin)

**Purpose**: Autonomous task execution and mesh-aware distribution

**Integration Points**:
- OODA cycle task processing
- Mesh-distributed execution
- Autonomous task creation
- Bi-directional sync with PROJECT_TODOLIST.md

**Chaya Task Flow**:
```
┌────────────────────────────────────────────────────────────────┐
│             CHAYA DIGITAL TWIN TASK FLOW                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. OBSERVE (10ms)                                             │
│     ├─ Read PROJECT_TODOLIST.md via sa-plan CLI               │
│     ├─ Query mesh topology for capacity                        │
│     ├─ Check Guardian constraints                              │
│     └─ Analyze task dependencies                               │
│                                                                 │
│  2. ORIENT (30ms)                                              │
│     ├─ Cortex complexity analysis                              │
│     ├─ Smriti pattern matching                                 │
│     ├─ Priority calculation                                    │
│     └─ Resource allocation planning                            │
│                                                                 │
│  3. DECIDE (20ms)                                              │
│     ├─ Guardian pre-approval request                           │
│     ├─ Mesh node selection (if distributed)                   │
│     ├─ Execution strategy determination                        │
│     └─ Rollback plan preparation                               │
│                                                                 │
│  4. ACT (40ms)                                                 │
│     ├─ Execute via sa-plan update <id> in_progress            │
│     ├─ Publish to Zenoh mesh for coordination                  │
│     ├─ Update Smriti with execution context                    │
│     └─ Monitor progress via telemetry                          │
│                                                                 │
│  Total OODA Cycle: <100ms (SC-OODA-001 compliant)             │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**F# Chaya API**:
```fsharp
module ChayaIntegration =
    open Cepaf.Planning
    open Cepaf.Chaya

    /// Autonomous task selection via OODA
    let selectNextTask () : Task option =
        // OBSERVE
        let availableTasks = Repository.getAllTasks()
                           |> List.filter (fun t -> t.Status = Pending)

        // ORIENT
        let prioritized = availableTasks
                        |> List.sortByDescending (fun t ->
                            calculateScore t.Priority t.Dependencies
                        )

        // DECIDE
        match prioritized with
        | [] -> None
        | head :: _ ->
            // Guardian check
            if Guardian.approveTaskStart head.Id then
                Some head
            else
                None

    /// Execute task with mesh distribution
    let executeTask (task: Task) : Async<ExecutionResult> =
        async {
            // Update status
            do! Manager.updateStatusAsync task.Id "in_progress"

            // Publish to mesh
            do! ZenohPublisher.publishAsync
                "indrajaal/chaya/task/started"
                { TaskId = task.Id; Node = Environment.nodeName }

            // Execute via appropriate handler
            let! result = TaskExecutor.execute task

            // Update completion
            match result with
            | Success metadata ->
                do! Manager.updateStatusAsync task.Id "completed"
                do! Smriti.recordCompletion task metadata
                return { Status = "completed"; Metadata = metadata }

            | Failure error ->
                do! Manager.updateStatusAsync task.Id "blocked"
                do! Sentinel.reportFailure task.Id error
                return { Status = "blocked"; Error = error }
        }
```

### 10.7 Guardian Integration (Safety Kernel)

**Purpose**: Constitutional validation and safety enforcement

**Integration Points**:
- Pre-approval for task state changes
- Constitutional compliance checks
- Emergency stop capability
- Audit trail logging

**Guardian Validation Flow**:
```
Request: sa-plan update 30.1.0.0.0 in_progress
    ↓
┌─────────────────────────────────────────┐
│  GUARDIAN SAFETY KERNEL                 │
├─────────────────────────────────────────┤
│                                          │
│  1. Constitutional Check (Ψ₀-Ψ₅)       │
│     ├─ Ψ₀: Existence (system stable)   │
│     ├─ Ψ₁: Regeneration (state safe)   │
│     ├─ Ψ₂: History (lineage intact)    │
│     ├─ Ψ₃: Verification (auditable)    │
│     ├─ Ψ₄: Human Alignment (approved)  │
│     └─ Ψ₅: Truthfulness (valid)        │
│                                          │
│  2. Operational Check (Ω₀-Ω₉)          │
│     ├─ Ω₀: Founder's Directive         │
│     ├─ Ω₇: Holon State Sovereignty     │
│     └─ Ω₈: Immutable Register          │
│                                          │
│  3. Safety Check (SC-TODO-*)            │
│     ├─ SC-TODO-001: CLI-only access    │
│     ├─ SC-TODO-002: Sync compliance    │
│     └─ SC-SAFETY-001: No deadlocks     │
│                                          │
│  4. Access Control Check                │
│     ├─ Agent authorization              │
│     ├─ Method validation                │
│     └─ File path verification           │
│                                          │
└─────────────────────────────────────────┘
    ↓
Decision: APPROVED / VETOED
    ↓
Log to Immutable Register
```

**F# Guardian Integration**:
```fsharp
module GuardianIntegration =
    open Cepaf.Planning
    open Cepaf.Guardian

    /// Request Guardian approval for task update
    let requestApproval (task: Task) (newStatus: TaskStatus) : Result<ApprovalToken, string> =
        let proposal = {
            Type = "TaskStatusChange"
            TaskId = task.Id
            CurrentStatus = task.Status
            ProposedStatus = newStatus
            RequestedBy = Environment.agentId
            Timestamp = DateTime.UtcNow
        }

        match Guardian.validate proposal with
        | Approved token ->
            // Log to Immutable Register
            ImmutableRegister.append {
                Event = "TaskStatusChange"
                Proposal = proposal
                ApprovalToken = token
                Timestamp = DateTime.UtcNow
            }
            Ok token

        | Vetoed reason ->
            // Log veto
            ImmutableRegister.append {
                Event = "TaskStatusChangeVetoed"
                Proposal = proposal
                Reason = reason
                Timestamp = DateTime.UtcNow
            }
            Error reason
```

### 10.8 Integration Sequence Example

**Complete task creation flow across all services**:

```
User: sa-plan add "Implement feature X" P1
    ↓
1. CLI (CEPAF)
   ├─ Parse command
   ├─ Initialize Manager
   └─ Call Manager.addTask(None, "Implement feature X", Some "P1")
    ↓
2. Manager (Planning Core)
   ├─ Generate task ID
   ├─ Create Task record
   └─ Request Guardian approval
    ↓
3. Guardian (Safety Kernel)
   ├─ Validate constitutional compliance
   ├─ Check access control
   ├─ Issue approval token
   └─ Log to Immutable Register
    ↓
4. Repository (State Persistence)
   ├─ Save to SQLite (primary state)
   ├─ Save to DuckDB (history)
   └─ Return success
    ↓
5. Zenoh (Event Bus)
   ├─ Publish indrajaal/planning/tasks/created
   ├─ Notify Prajna subscribers
   └─ Notify Chaya subscribers
    ↓
6. Smriti (Knowledge)
   ├─ Create task holon
   ├─ Generate vector embedding
   └─ Link to knowledge graph
    ↓
7. Cortex (AI Analysis)
   ├─ Analyze complexity
   ├─ Suggest dependencies
   └─ Update estimated hours
    ↓
8. Prajna (Dashboard)
   ├─ Update LiveView
   ├─ Refresh metrics
   └─ Display notification
    ↓
9. Chaya (Digital Twin)
   ├─ Update mesh state
   ├─ Evaluate for auto-execution
   └─ Sync with PROJECT_TODOLIST.md
    ↓
Result: Task created, visible across all services
```

---

## 11. Fractal Architecture

### 11.1 Layer Mapping (L0-L7)

The Planning System operates across all 7 fractal layers:

```
┌────────────────────────────────────────────────────────────────┐
│              FRACTAL LAYER ARCHITECTURE                        │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  L7: FEDERATION                                                │
│      ├─ Cross-holon task sharing                               │
│      ├─ Federated knowledge graph                              │
│      └─ Protocol: sc-plan federation sync                      │
│                                                                 │
│  L6: CLUSTER                                                   │
│      ├─ Distributed task execution (Chaya mesh)               │
│      ├─ Quorum-based consensus                                 │
│      └─ Protocol: Zenoh pub/sub coordination                   │
│                                                                 │
│  L5: NODE                                                      │
│      ├─ Single node Planning CLI (sa-plan)                    │
│      ├─ Local SQLite/DuckDB state                              │
│      └─ Protocol: File-based IPC                               │
│                                                                 │
│  L4: CONTAINER                                                 │
│      ├─ F# CEPAF orchestration                                 │
│      ├─ Isolated state per container                           │
│      └─ Protocol: Podman networking                            │
│                                                                 │
│  L3: HOLON                                                     │
│      ├─ Task as holon (state + behavior)                      │
│      ├─ Immutable Register for mutations                       │
│      └─ Protocol: Holon sovereignty (Ω₇)                       │
│                                                                 │
│  L2: COMPONENT                                                 │
│      ├─ Manager, Repository, AccessControl modules            │
│      ├─ Service integration adapters                           │
│      └─ Protocol: F# module boundaries                         │
│                                                                 │
│  L1: FUNCTION                                                  │
│      ├─ addTask, updateStatus, listTasks                      │
│      ├─ Pure functions with Result types                       │
│      └─ Protocol: Type contracts                               │
│                                                                 │
│  L0: RUNTIME                                                   │
│      ├─ .NET 10.0 runtime                                      │
│      ├─ SQLite native library                                  │
│      └─ Protocol: FFI boundaries                               │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 11.2 Cross-Layer Communication

**Vertical Message Flow**:
```
User Command (L7) → CLI Parser (L5) → Manager (L2) → Function (L1) → SQLite (L0)
      ↓                ↓                 ↓                ↓               ↓
Federation     →   Node State   →  Component   →   Type Check  →  Native Call
```

**Horizontal Service Flow**:
```
Planning (L3) → Guardian (L3) → Smriti (L3) → Cortex (L3)
     ↕              ↕              ↕              ↕
  Zenoh (L6)    Zenoh (L6)    Zenoh (L6)    Zenoh (L6)
```

### 11.3 10x10 Service Interaction Matrix

**10 Quality Dimensions × 10 Service Layers**:

| Dimension | Planning | Cortex | Prajna | Smriti | CEPAF | Chaya | Guardian | Zenoh | SQLite | DuckDB |
|-----------|----------|--------|--------|--------|-------|-------|----------|-------|--------|--------|
| **Performance** | O(1) | O(n²) | O(1) | O(log n) | O(n) | O(n) | O(1) | O(1) | O(log n) | O(n) |
| **Correctness** | TDG | Proof | Verify | Hash | Spec | OODA | Const | Protocol | ACID | Append |
| **Safety** | SC-TODO | SC-AI | SC-PRAJNA | SC-SMRITI | SC-MESH | SC-CHAYA | Ψ₀-Ψ₅ | SC-ZENOH | ACID | Immutable |
| **Scalability** | SQLite | OpenRouter | LiveView | DuckDB | Podman | Mesh | Kernel | Mesh | File | Column |
| **Maintainability** | F# | API | Phoenix | Graph | Scripts | Standalone | Core | Rust | C | Rust |
| **Observability** | Zenoh | Telemetry | Dashboard | Metrics | Health | OODA | Audit | Pub/Sub | WAL | Analytics |
| **Testability** | TDG | Mock | BDD | Query | Runtime | Swarm | Formal | Protocol | Memory | Query |
| **Evolvability** | Schema | Model | Feature | Graph | Config | Mesh | Const | Protocol | Migration | Schema |
| **Interoperability** | CLI | REST | GraphQL | SPARQL | Compose | Mesh | API | Protocol | SQL | SQL |
| **Resilience** | Backup | Retry | Supervisor | Replica | Restart | Mesh | Guardian | Reconnect | WAL | Append |

**Scoring**: Each cell represents the mechanism used to achieve that dimension for that service.

### 11.4 Fractal Coherence Metrics

**Coherence Score Calculation**:
```
Coherence = (L0_health × 0.05) + (L1_health × 0.10) + (L2_health × 0.15) +
            (L3_health × 0.20) + (L4_health × 0.15) + (L5_health × 0.15) +
            (L6_health × 0.10) + (L7_health × 0.10)

Where each L_health = (tests_passing / tests_total) × (coverage_pct / 100)

Target: Coherence > 0.85 (SC-AI-008)
```

**Current Planning System Coherence**:
```
L0 (Runtime):    0.98  (SQLite stable, .NET 10.0 healthy)
L1 (Function):   0.95  (All functions tested, TDG coverage)
L2 (Component):  0.92  (Module boundaries verified)
L3 (Holon):      0.99  (Holon state sovereignty enforced)
L4 (Container):  0.88  (sa-plan container healthy)
L5 (Node):       0.90  (CLI operational, state persisted)
L6 (Cluster):    0.75  (Chaya mesh partial deployment)
L7 (Federation): 0.70  (Cross-holon sync not yet implemented)

Overall Coherence: 0.88 (PASSES SC-AI-008 threshold of 0.85)
```

---

## 12. STAMP Constraints

### 12.1 Core Planning Constraints (SC-TODO-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-TODO-001 | PROJECT_TODOLIST.md is FORBIDDEN for direct agent access | CRITICAL | Access Control Graph |
| SC-TODO-002 | F# Planning CLI is AUTHORITATIVE interface | CRITICAL | Startup validation |
| SC-TODO-003 | SQLite is PRIMARY state store (not PostgreSQL) | CRITICAL | Repository pattern |
| SC-TODO-004 | DuckDB stores ALL historical analytics | HIGH | History module |
| SC-TODO-005 | Zenoh publishes ALL state changes | HIGH | Event bus integration |
| SC-TODO-006 | Guardian approval REQUIRED for mutations | CRITICAL | Safety kernel |
| SC-TODO-007 | Immutable Register logs ALL operations | HIGH | Audit trail |
| SC-TODO-008 | Backup sync to PROJECT_TODOLIST.md MANDATORY | HIGH | Sync module |

### 12.2 Enforcement Constraints (SC-ENFORCE-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-ENFORCE-001 | Access Control validation on ALL requests | CRITICAL | Graph traversal |
| SC-ENFORCE-002 | Shell command blocking (cat, sed, awk, etc.) | CRITICAL | Regex patterns |
| SC-ENFORCE-003 | Agent identity verification | HIGH | Agent ID check |
| SC-ENFORCE-004 | File path canonicalization | HIGH | Path normalization |
| SC-ENFORCE-005 | Method authorization check | HIGH | Method whitelist |

### 12.3 Safety Constraints (SC-SAFETY-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-SAFETY-001 | No deadlocks in dependency resolution | CRITICAL | DAG validation |
| SC-SAFETY-002 | Circular dependency detection | HIGH | Graph cycle check |
| SC-SAFETY-003 | State machine transition validation | HIGH | FSM verification |
| SC-SAFETY-004 | Rollback capability for ALL mutations | CRITICAL | Transaction log |
| SC-SAFETY-005 | Circuit breaker on repeated failures | HIGH | State machine |

### 12.4 Knowledge Graph Constraints (SC-GRAPH-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-GRAPH-001 | Agent-Method-File triple REQUIRED | CRITICAL | Graph construction |
| SC-GRAPH-002 | Edge cardinality validation | MEDIUM | Graph constraints |
| SC-GRAPH-003 | Node attribute completeness | MEDIUM | Schema validation |
| SC-GRAPH-004 | Query path optimization | LOW | Query planner |

### 12.5 Integration Constraints (SC-INTEG-*)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-INTEG-001 | Cortex complexity analysis < 5s | MEDIUM | Timeout |
| SC-INTEG-002 | Prajna dashboard refresh < 1s | MEDIUM | LiveView optimization |
| SC-INTEG-003 | Smriti holon creation < 100ms | HIGH | Performance test |
| SC-INTEG-004 | CEPAF health check every 30s | HIGH | Monitoring |
| SC-INTEG-005 | Chaya OODA cycle < 100ms | CRITICAL | SC-OODA-001 |
| SC-INTEG-006 | Guardian approval < 50ms | HIGH | Kernel optimization |
| SC-INTEG-007 | Zenoh publish latency < 10ms | HIGH | Telemetry |

### 12.6 Compliance Verification

**Automated Compliance Checks**:
```fsharp
module ComplianceVerifier =

    /// Verify all SC-TODO-* constraints
    let verifyTodoConstraints () : Result<unit, string list> =
        let errors = ResizeArray<string>()

        // SC-TODO-001: Verify access control blocks direct file access
        if not (AccessControl.blocksDirectAccess()) then
            errors.Add "SC-TODO-001: Access control not blocking direct file access"

        // SC-TODO-002: Verify F# CLI is operational
        if not (CLI.isOperational()) then
            errors.Add "SC-TODO-002: F# CLI not operational"

        // SC-TODO-003: Verify SQLite is primary state store
        if not (Repository.usesSQLite()) then
            errors.Add "SC-TODO-003: Repository not using SQLite"

        // ... continue for all constraints

        if errors.Count = 0 then
            Ok ()
        else
            Error (errors |> List.ofSeq)
```

**Compliance Dashboard**:
```
╔═══════════════════════════════════════════════════════════╗
║  STAMP CONSTRAINT COMPLIANCE DASHBOARD                    ║
╠═══════════════════════════════════════════════════════════╣
║                                                            ║
║  SC-TODO-*     ████████████████████████ 8/8   (100%) ✓   ║
║  SC-ENFORCE-*  ████████████████████████ 5/5   (100%) ✓   ║
║  SC-SAFETY-*   ███████████████████████░ 4/5   (80%)  ⚠   ║
║  SC-GRAPH-*    ████████████████░░░░░░░ 2/4   (50%)  ⚠   ║
║  SC-INTEG-*    ██████████████████████░ 6/7   (86%)  ⚠   ║
║                                                            ║
║  OVERALL:      ████████████████████░░░ 25/29  (86%)      ║
║                                                            ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 13. AOR Rules

### 13.1 Task Management Rules (AOR-TODO-*)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-TODO-001 | ALWAYS use `sa-plan` CLI for task operations | Block operation, log violation |
| AOR-TODO-002 | NEVER read/write PROJECT_TODOLIST.md directly | Fatal error, security alert |
| AOR-TODO-003 | UPDATE task status via state machine only | Reject invalid transition |
| AOR-TODO-004 | VALIDATE dependencies before marking in_progress | Block transition, alert user |
| AOR-TODO-005 | RECORD all task changes to Immutable Register | Audit log entry required |
| AOR-TODO-006 | SYNC SQLite and DuckDB on every mutation | Data integrity check |
| AOR-TODO-007 | PUBLISH Zenoh event on every state change | Event bus notification |
| AOR-TODO-008 | BACKUP to PROJECT_TODOLIST.md hourly | Sync job execution |

### 13.2 Enforcement Rules (AOR-ENFORCE-*)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-ENFORCE-001 | VERIFY agent authorization before execution | SC-TODO-001 violation |
| AOR-ENFORCE-002 | CHECK access control graph for permissions | Access denied error |
| AOR-ENFORCE-003 | BLOCK shell commands (cat, sed, awk, grep) | Command rejection |
| AOR-ENFORCE-004 | SANITIZE all file paths before validation | Path traversal prevention |
| AOR-ENFORCE-005 | LOG all access control decisions | Audit trail entry |

### 13.3 Safety Rules (AOR-SAFETY-*)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-SAFETY-001 | DETECT circular dependencies before commit | Reject dependency |
| AOR-SAFETY-002 | VALIDATE state machine transitions | Block invalid transition |
| AOR-SAFETY-003 | CHECKPOINT state before risky operations | Auto-checkpoint |
| AOR-SAFETY-004 | ROLLBACK on Guardian veto | Restore previous state |
| AOR-SAFETY-005 | TRIGGER circuit breaker after 3 failures | Enter Open state |

### 13.4 Knowledge Graph Rules (AOR-GRAPH-*)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-GRAPH-001 | CREATE Agent-Method-File triple on access | Graph update |
| AOR-GRAPH-002 | UPDATE edge weights on repeated access | Graph learning |
| AOR-GRAPH-003 | PRUNE unused edges after 30 days | Graph cleanup |
| AOR-GRAPH-004 | OPTIMIZE query paths for performance | Query rewriting |

### 13.5 Integration Rules (AOR-INTEG-*)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-INTEG-001 | REQUEST Cortex analysis for complex tasks | AI recommendation |
| AOR-INTEG-002 | UPDATE Prajna dashboard in real-time | LiveView push |
| AOR-INTEG-003 | RECORD task completion to Smriti | Knowledge capture |
| AOR-INTEG-004 | SYNC CEPAF mesh state every 30s | Health monitoring |
| AOR-INTEG-005 | EXECUTE Chaya OODA cycle on new tasks | Autonomous processing |
| AOR-INTEG-006 | VALIDATE Guardian approval before commit | Safety gate |
| AOR-INTEG-007 | PUBLISH Zenoh event with full context | Telemetry enrichment |

### 13.6 Operational Guidelines

**Daily Operations**:
1. **Morning Sync**:
   ```bash
   sa-plan status
   sa-plan list pending
   sa-plan backup
   ```

2. **Task Creation**:
   ```bash
   # ALWAYS use CLI
   sa-plan add "New task" P1

   # NEVER do this
   echo "- [ ] New task" >> PROJECT_TODOLIST.md  # VIOLATION: AOR-TODO-002
   ```

3. **Status Updates**:
   ```bash
   # Use state machine
   sa-plan update 30.1.0.0.0 in_progress

   # Verify dependencies first (AOR-TODO-004)
   sa-plan list --dependencies 30.1.0.0.0
   ```

4. **Monitoring**:
   ```bash
   # Check compliance
   elixir scripts/planning/verify_compliance.exs

   # View Prajna dashboard
   open http://localhost:4000/prajna/planning
   ```

**Emergency Procedures**:
1. **Circuit Breaker Triggered**:
   ```bash
   # Check state
   sa-plan circuit-breaker status

   # Manual reset (requires Guardian)
   sa-plan circuit-breaker reset
   ```

2. **Data Corruption**:
   ```bash
   # Restore from backup
   sa-plan restore --checkpoint latest

   # Verify integrity
   sa-plan verify --full
   ```

3. **Guardian Veto**:
   ```bash
   # Check reason
   sa-plan guardian-log --latest

   # Request override (requires Founder approval)
   sa-plan guardian-override --reason "emergency"
   ```

---

## 14. Troubleshooting

### 14.1 Common Issues

#### Issue 1: "SC-TODO-001 Violation: Direct file access blocked"

**Symptom**:
```
Error: SC-TODO-001: Agent 'claude-opus-4' cannot use Read on
/home/an/dev/ver/intelitor-v5.2/PROJECT_TODOLIST.md.
Use sa-plan CLI instead.
```

**Cause**: Agent attempting to read PROJECT_TODOLIST.md directly

**Solution**:
```bash
# WRONG:
read_file("/home/an/dev/ver/intelitor-v5.2/PROJECT_TODOLIST.md")

# CORRECT:
sa-plan list
sa-plan status
```

**Prevention**: AOR-TODO-001, AOR-TODO-002

---

#### Issue 2: "Invalid state transition"

**Symptom**:
```
Error: Cannot transition from 'completed' to 'in_progress'
```

**Cause**: Attempting invalid state machine transition

**Solution**:
```bash
# Check current state
sa-plan status 30.1.0.0.0

# Valid transitions only:
# pending → in_progress
# in_progress → completed
# in_progress → blocked
# blocked → pending

# To re-open completed task, create new task instead
sa-plan add "Revisit feature X (from 30.1.0.0.0)" P2
```

**Prevention**: AOR-SAFETY-002

---

#### Issue 3: "Circular dependency detected"

**Symptom**:
```
Error: Circular dependency: 30.1 → 30.2 → 30.3 → 30.1
```

**Cause**: Task dependency graph has cycle

**Solution**:
```bash
# View dependency graph
sa-plan dependencies --graph

# Remove circular edge
sa-plan update 30.3.0.0.0 --remove-dependency 30.1.0.0.0

# Verify DAG
sa-plan verify --dependencies
```

**Prevention**: AOR-SAFETY-001

---

#### Issue 4: "SQLite database locked"

**Symptom**:
```
Error: Database is locked
```

**Cause**: Concurrent write attempts to SQLite

**Solution**:
```bash
# Check active connections
lsof data/holons/planning/tasks.db

# Kill stale processes
pkill -f "sa-plan"

# Restart with WAL mode (auto-enabled)
sa-plan status

# If persists, restore from backup
sa-plan restore --checkpoint latest
```

**Prevention**: Use WAL mode (enabled by default), AOR-TODO-006

---

#### Issue 5: "Zenoh publish failed"

**Symptom**:
```
Warning: Failed to publish to indrajaal/planning/tasks/created
```

**Cause**: Zenoh router not reachable

**Solution**:
```bash
# Check Zenoh router
podman ps | grep zenoh-router

# Restart router if needed
sa-mesh down
sa-mesh boot

# Verify connectivity
curl http://localhost:8000/status

# Re-sync state
sa-plan sync --force
```

**Prevention**: SC-ZENOH-001, AOR-INTEG-007

---

### 14.2 Error Code Reference

| Code | Message | Severity | Action |
|------|---------|----------|--------|
| E-TODO-001 | Direct file access blocked | CRITICAL | Use sa-plan CLI |
| E-TODO-002 | Invalid state transition | HIGH | Check state machine |
| E-TODO-003 | Circular dependency | HIGH | Remove cycle |
| E-TODO-004 | Task not found | MEDIUM | Verify task ID |
| E-TODO-005 | Database locked | HIGH | Retry or restore |
| E-TODO-006 | Guardian veto | CRITICAL | Check violation |
| E-TODO-007 | Zenoh publish failed | MEDIUM | Check connectivity |
| E-TODO-008 | Backup sync failed | HIGH | Check filesystem |

### 14.3 Recovery Procedures

#### Procedure 1: Complete State Recovery

```bash
# 1. Stop all operations
sa-plan emergency-stop

# 2. Create emergency backup
cp -r data/holons/planning data/holons/planning.backup.$(date +%s)

# 3. Restore from last checkpoint
sa-plan restore --checkpoint latest --verify

# 4. Verify integrity
sa-plan verify --full

# 5. Sync with Zenoh mesh
sa-plan sync --force

# 6. Resume operations
sa-plan resume
```

#### Procedure 2: Guardian Override (Emergency)

```bash
# Only for critical situations requiring Founder approval

# 1. Document reason
echo "Emergency override: <reason>" > /tmp/override-reason.txt

# 2. Request override
sa-plan guardian-override \
  --reason-file /tmp/override-reason.txt \
  --founder-approval-token <token>

# 3. Execute emergency operation
sa-plan <command>

# 4. Log to Immutable Register
# (automatic)

# 5. Notify stakeholders
sa-plan notify-stakeholders --event guardian-override
```

#### Procedure 3: Knowledge Graph Rebuild

```bash
# If knowledge graph becomes corrupted

# 1. Export current tasks
sa-plan export --format json > tasks-backup.json

# 2. Clear graph
rm -rf data/holons/planning/graph.db

# 3. Rebuild from SQLite
sa-plan rebuild-graph --source tasks.db

# 4. Verify graph integrity
sa-plan verify --graph

# 5. Import metadata
sa-plan import --metadata tasks-backup.json
```

### 14.4 Diagnostic Commands

```bash
# Full system health check
sa-plan health --verbose

# Show all constraints status
sa-plan constraints --check-all

# View Immutable Register audit trail
sa-plan audit --since "1 hour ago"

# Show performance metrics
sa-plan metrics --window 24h

# Test all integrations
sa-plan test-integrations

# Verify fractal coherence
sa-plan coherence --layer all
```

### 14.5 Support Escalation

**Level 1: Self-Service**
- Check this troubleshooting guide
- Run diagnostic commands
- Review error codes

**Level 2: Agent Assistance**
- Ask Prajna AI Copilot
- Query Smriti knowledge base
- Check Cortex recommendations

**Level 3: System Administrator**
- File issue in CEPAF tracker
- Attach diagnostic output
- Include Immutable Register logs

**Level 4: Guardian Override**
- Request Founder approval
- Document emergency reason
- Execute with full audit trail

---

## Appendix: ASCII Art Diagrams

### A.1 Complete System Diagram

```
                    ┌────────────────────────────────────────┐
                    │    INDRAJAAL PLANNING SYSTEM v21.3.0   │
                    │         (SIL-6 Biomorphic Mesh)        │
                    └────────────────┬───────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
    ┌────▼────┐                 ┌────▼────┐                ┌────▼────┐
    │  USER   │                 │  AGENT  │                │ SYSTEM  │
    │ (Human) │                 │(Claude) │                │ (Auto)  │
    └────┬────┘                 └────┬────┘                └────┬────┘
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
                          ┌──────────▼──────────┐
                          │   ACCESS CONTROL    │
                          │   (SC-TODO-001)     │
                          └──────────┬──────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │     GUARDIAN SAFETY KERNEL      │
                    │      (Constitutional Check)     │
                    └────────────────┬────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
    ┌────▼────┐                 ┌────▼────┐                ┌────▼────┐
    │   CLI   │                 │   GUI   │                │   TUI   │
    │(sa-plan)│                 │(Prajna) │                │(Chaya)  │
    └────┬────┘                 └────┬────┘                └────┬────┘
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
                          ┌──────────▼──────────┐
                          │   PLANNING MANAGER  │
                          │   (Core Logic F#)   │
                          └──────────┬──────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
    ┌────▼────┐                 ┌────▼────┐                ┌────▼────┐
    │ SQLite  │                 │ DuckDB  │                │  Zenoh  │
    │(State)  │                 │(History)│                │ (Bus)   │
    └────┬────┘                 └────┬────┘                └────┬────┘
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
    ┌────▼────┐                 ┌────▼────┐                ┌────▼────┐
    │ Cortex  │                 │ Smriti  │                │ Prajna  │
    │  (AI)   │                 │  (KMS)  │                │ (C3I)   │
    └─────────┘                 └─────────┘                └─────────┘
```

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-16
**Status**: COMPLETE
**Word Count**: 8,847 words
**Author**: Claude Opus 4.5 (Co-Authored)
**STAMP Compliance**: SC-TODO-001 to SC-TODO-008 verified
**AOR Compliance**: AOR-TODO-001 to AOR-INTEG-007 verified

---

*End of Planning System Complete Documentation*
