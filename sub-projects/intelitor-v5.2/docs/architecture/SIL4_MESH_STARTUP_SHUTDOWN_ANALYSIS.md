# SIL-6 Biomorphic Mesh Orchestration: Analysis and Implementation Specification

**Version**: 1.0.0 | **Date**: 2026-01-04 | **Status**: SPECIFICATION
**Author**: Claude Opus 4.5 | **Framework**: SOPv5.11 + STAMP + TDG

---

## Executive Summary

This document specifies the architecture, implementation, and verification approach for a SIL-6 Biomorphic compliant mesh orchestration system. The system manages a 3-container production mesh (DB, App, Obs) with strict SLA guarantees: **10 seconds for startup**, **5 seconds for shutdown**.

The solution implements:
- **Digital Twin architecture** with SQLite/DuckDB duality for every container
- **Wave-based startup** with Kahn's algorithm for dependency resolution
- **Fast OODA loops** (< 100ms) at each orchestration step
- **Zenoh pub/sub** for real-time control plane telemetry
- **Fractal logging** at 5 levels with full transparency
- **REST API** for programmatic control with detailed feedback
- **tview-based CLI** integrated with CEPAF F# cockpit

---

## Table of Contents

1. [AS-IS Analysis](#1-as-is-analysis)
2. [TO-BE Architecture](#2-to-be-architecture)
3. [Digital Twin Specification](#3-digital-twin-specification)
4. [Data Flow Architecture](#4-data-flow-architecture)
5. [Control Flow Specification](#5-control-flow-specification)
6. [Transaction Behavior](#6-transaction-behavior)
7. [OODA Loop Implementation](#7-ooda-loop-implementation)
8. [Zenoh Telemetry Integration](#8-zenoh-telemetry-integration)
9. [REST API Specification](#9-rest-api-specification)
10. [Timeline Dashboard](#10-timeline-dashboard)
11. [Implementation Approach](#11-implementation-approach)
12. [Test Approach](#12-test-approach)
13. [Code Approach](#13-code-approach)
14. [STAMP Constraints](#14-stamp-constraints)
15. [FMEA Analysis](#15-fmea-analysis)
16. [TDG Test Requirements](#16-tdg-test-requirements)
17. [AOR Rules](#17-aor-rules)

---

## 1. AS-IS Analysis

### 1.1 Current Implementation

The current mesh orchestration is implemented across several files:

| File | Purpose | Lines |
|------|---------|-------|
| `lib/cepaf/scripts/SIL6Orchestrator.fsx` | Main orchestration script | ~400 |
| `lib/cepaf/src/Cepaf/Orchestrator/OptimalMesh.fs` | Core mesh types | 84 |
| `devenv.nix` (sa-* commands) | CLI entry points | 50 |
| `podman-compose-prod-standalone.yml` | Container definitions | 150 |

#### Current Startup Flow
```
┌─────────────────────────────────────────────────────────────────┐
│  CURRENT sa-up FLOW (Sequential, ~45-60 seconds)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Parse podman-compose-prod-standalone.yml                    │
│     └─ Time: 500ms                                               │
│                                                                  │
│  2. Start DB container (indrajaal-db-prod)                      │
│     ├─ Pull image if needed: 0-30s                              │
│     ├─ Create container: 2s                                      │
│     ├─ Wait for PostgreSQL ready: 10-20s                        │
│     └─ Time: 12-52s                                              │
│                                                                  │
│  3. Start OBS container (indrajaal-obs-prod)                    │
│     ├─ Create container: 2s                                      │
│     ├─ Wait for OTEL healthy: 5-10s                             │
│     └─ Time: 7-12s                                               │
│                                                                  │
│  4. Start APP container (indrajaal-ex-app-1)                    │
│     ├─ Create container: 3s                                      │
│     ├─ Wait for Phoenix ready: 10-15s                           │
│     └─ Time: 13-18s                                              │
│                                                                  │
│  TOTAL: 32-82 seconds (exceeds 10s SLA)                         │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Issues with Current Approach

| Issue ID | Description | Severity | Root Cause |
|----------|-------------|----------|------------|
| **AS-001** | No SLA enforcement | CRITICAL | Missing timeout/deadline mechanism |
| **AS-002** | Sequential startup | HIGH | No parallel wave optimization |
| **AS-003** | No digital twin state | HIGH | Container state not cached locally |
| **AS-004** | Blocking health checks | MEDIUM | Synchronous polling, no async |
| **AS-005** | No timeline visibility | MEDIUM | Missing progress dashboard |
| **AS-006** | CLI-only interface | LOW | No REST API for programmatic access |
| **AS-007** | No OODA loop metrics | MEDIUM | Missing cycle time telemetry |
| **AS-008** | Static configuration | LOW | No runtime reconfiguration |
| **AS-009** | No fractal logging | MEDIUM | Single log level, no Zenoh integration |
| **AS-010** | Missing rollback | HIGH | No automatic rollback on failure |

### 1.3 5-Level Root Cause Analysis (RCA)

```
WHY is startup slow? (>10s SLA)
├─ L1: Sequential container startup
│   └─ WHY? No wave-based parallelization
│       └─ L2: Dependencies not analyzed upfront
│           └─ WHY? No DAG construction
│               └─ L3: Missing Kahn's algorithm implementation
│                   └─ WHY? Original design assumed simple linear startup
│                       └─ L4: No SIL-6 Biomorphic requirements during initial design
│                           └─ L5: ROOT CAUSE: Missing formal SLA specification
│
├─ L1: Blocking health checks
│   └─ WHY? Synchronous HTTP polling
│       └─ L2: No async health check infrastructure
│           └─ WHY? F# async not leveraged
│               └─ L3: Script-based implementation vs module
│                   └─ L4: Quick prototype prioritized over architecture
│                       └─ L5: ROOT CAUSE: Technical debt from MVP phase
│
├─ L1: No pre-warmed containers
│   └─ WHY? Cold start every time
│       └─ L2: No container pooling
│           └─ WHY? Single-use lifecycle assumed
│               └─ L3: No lameduck/warmup pattern
│                   └─ L4: Ops patterns not implemented
│                       └─ L5: ROOT CAUSE: Missing SRE best practices
```

### 1.4 TPS (Toyota Production System) Analysis

| TPS Principle | Current State | Gap |
|---------------|---------------|-----|
| **Jidoka** (Stop on defect) | No automatic halt | Need circuit breaker |
| **Heijunka** (Level load) | Burst startup | Need wave-based smoothing |
| **Kaizen** (Continuous improvement) | Static config | Need adaptive tuning |
| **Just-in-Time** | All containers always | Need on-demand startup |
| **Genchi Genbutsu** (Go see) | No visibility | Need timeline dashboard |
| **Poka-Yoke** (Error-proofing) | Manual verification | Need automated checks |

---

## 2. TO-BE Architecture

### 2.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SIL-6 Biomorphic MESH ORCHESTRATION ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      CONTROL PLANE (F# Cockpit)                      │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │    │
│  │  │   OODA      │  │  Timeline   │  │   REST      │  │   tview    │  │    │
│  │  │ Controller  │  │  Dashboard  │  │    API      │  │    TUI     │  │    │
│  │  │  (<100ms)   │  │  (10s ref)  │  │  (OpenAPI)  │  │ (ANSI)     │  │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘  │    │
│  │         │                │                │               │          │    │
│  │  ┌──────┴────────────────┴────────────────┴───────────────┴──────┐  │    │
│  │  │                    UNIFIED CONTROL BUS                         │  │    │
│  │  │         (Zenoh pub/sub: indrajaal/mesh/control/**)            │  │    │
│  │  └──────┬────────────────┬────────────────┬───────────────┬──────┘  │    │
│  └─────────┼────────────────┼────────────────┼───────────────┼─────────┘    │
│            │                │                │               │               │
│  ┌─────────┴────────────────┴────────────────┴───────────────┴─────────┐    │
│  │                         DIGITAL TWIN LAYER                           │    │
│  │  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐          │    │
│  │  │  DB Twin    │      │  App Twin   │      │  Obs Twin   │          │    │
│  │  │ ┌─────────┐ │      │ ┌─────────┐ │      │ ┌─────────┐ │          │    │
│  │  │ │ Geno    │ │      │ │ Geno    │ │      │ │ Geno    │ │          │    │
│  │  │ │(Static) │ │      │ │(Static) │ │      │ │(Static) │ │          │    │
│  │  │ ├─────────┤ │      │ ├─────────┤ │      │ ├─────────┤ │          │    │
│  │  │ │ Pheno   │ │      │ │ Pheno   │ │      │ │ Pheno   │ │          │    │
│  │  │ │(Dynamic)│ │      │ │(Dynamic)│ │      │ │(Dynamic)│ │          │    │
│  │  │ └─────────┘ │      │ └─────────┘ │      │ └─────────┘ │          │    │
│  │  └──────┬──────┘      └──────┬──────┘      └──────┬──────┘          │    │
│  └─────────┼────────────────────┼────────────────────┼──────────────────┘    │
│            │                    │                    │                       │
│  ┌─────────┴────────────────────┴────────────────────┴──────────────────┐    │
│  │                      CONTAINER SUBSTRATE                              │    │
│  │  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐           │    │
│  │  │ indrajaal-  │      │ indrajaal-  │      │ indrajaal-  │           │    │
│  │  │  db-prod    │      │  app-prod   │      │  obs-prod   │           │    │
│  │  │  :5433      │      │  :4000      │      │  :4317      │           │    │
│  │  └─────────────┘      └─────────────┘      └─────────────┘           │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    TELEMETRY PLANE (Zenoh)                           │    │
│  │  indrajaal/mesh/twin/**    → Digital twin state                      │    │
│  │  indrajaal/mesh/health/**  → Health checks                           │    │
│  │  indrajaal/mesh/ooda/**    → OODA loop metrics                       │    │
│  │  indrajaal/mesh/timeline/**→ Progress events                         │    │
│  │  indrajaal/mesh/log/**     → Fractal logs (L1-L5)                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 SLA Specifications

| Metric | Target | Measurement | Enforcement |
|--------|--------|-------------|-------------|
| **Startup Time** | ≤ 10 seconds | First container start → All healthy | Deadline timer |
| **Shutdown Time** | ≤ 5 seconds | Shutdown signal → All stopped | Deadline timer |
| **OODA Cycle** | ≤ 100 ms | Observe start → Act complete | Telemetry |
| **Health Check** | ≤ 500 ms | Request → Response | Timeout |
| **Twin Sync** | ≤ 50 ms | Event → Twin update | Telemetry |
| **Dashboard Refresh** | Every 10 seconds | Timer-based | Watchdog |

### 2.3 Wave-Based Startup (Kahn's Algorithm)

```
┌─────────────────────────────────────────────────────────────────┐
│  WAVE-BASED STARTUP (10 SECOND SLA)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  T=0s    WAVE 0: PREPARE (Parallel)                             │
│          ├─ Parse compose file                    [50ms]        │
│          ├─ Validate images exist                 [100ms]       │
│          ├─ Initialize digital twins              [50ms]        │
│          └─ Setup Zenoh channels                  [100ms]       │
│              DEADLINE: T+500ms                                   │
│                                                                  │
│  T=0.5s  WAVE 1: DATABASE (Critical Path)                       │
│          ├─ Create DB container                   [1000ms]      │
│          ├─ Start DB container                    [500ms]       │
│          ├─ Async health probe (pg_isready)       [2000ms max]  │
│          └─ Update twin: MeshReady                [50ms]        │
│              DEADLINE: T+4s                                      │
│                                                                  │
│  T=4s    WAVE 2: PARALLEL SERVICES                              │
│          ├─ Create/Start OBS container            [1000ms]      │
│          │   └─ Async health probe (OTEL)         [2000ms max]  │
│          ├─ Create/Start APP container            [1000ms]      │
│          │   └─ Async health probe (Phoenix)      [3000ms max]  │
│          └─ Update twins: MeshReady               [50ms]        │
│              DEADLINE: T+9s                                      │
│                                                                  │
│  T=9s    WAVE 3: VERIFICATION                                   │
│          ├─ FPPS 5-method consensus               [500ms]       │
│          ├─ Generate proof tokens                 [100ms]       │
│          ├─ Publish success to Zenoh              [50ms]        │
│          └─ Update timeline dashboard             [50ms]        │
│              DEADLINE: T+10s                                     │
│                                                                  │
│  T≤10s   MESH READY ✓                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.4 Lameduck Shutdown (5 Second SLA)

```
┌─────────────────────────────────────────────────────────────────┐
│  LAMEDUCK SHUTDOWN (5 SECOND SLA)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  T=0s    PHASE 0: SIGNAL                                        │
│          ├─ Set all twins to MeshLameduck         [10ms]        │
│          ├─ Publish shutdown intent to Zenoh      [20ms]        │
│          └─ Stop accepting new requests           [10ms]        │
│              DEADLINE: T+100ms                                   │
│                                                                  │
│  T=0.1s  PHASE 1: DRAIN (Parallel)                              │
│          ├─ APP: Drain active connections         [2000ms max]  │
│          ├─ OBS: Flush telemetry buffers          [500ms max]   │
│          └─ DB: Complete active transactions      [1000ms max]  │
│              DEADLINE: T+2.5s                                    │
│                                                                  │
│  T=2.5s  PHASE 2: STOP (Parallel)                               │
│          ├─ Stop APP container                    [500ms]       │
│          ├─ Stop OBS container                    [500ms]       │
│          ├─ Stop DB container                     [500ms]       │
│          └─ Update twins: MeshOff                 [50ms]        │
│              DEADLINE: T+4s                                      │
│                                                                  │
│  T=4s    PHASE 3: CLEANUP                                       │
│          ├─ Persist twin state to DuckDB          [200ms]       │
│          ├─ Close Zenoh channels                  [100ms]       │
│          └─ Generate shutdown report              [100ms]       │
│              DEADLINE: T+5s                                      │
│                                                                  │
│  T≤5s    MESH STOPPED ✓                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Digital Twin Specification

### 3.1 Twin Data Structure

```fsharp
/// Immutable genotype - static container configuration
type HolonGenotype = {
    Id: string                      // Unique identifier (e.g., "db-primary")
    Role: HolonRole                 // Persistence | Compute | Observability
    Image: string                   // Container image reference
    ImageDigest: string             // SHA256 digest for integrity
    Port: int                       // Primary exposed port
    HealthEndpoint: string          // Health check URL/command
    Dependencies: string list       // Container IDs this depends on
    SecurityPosture: SecurityConfig // Caps, NoNewPrivs, ReadOnly
    ResourceLimits: ResourceConfig  // CPU, Memory limits
    CreatedAt: DateTimeOffset       // Genotype creation timestamp
    GitCommit: string               // Source commit hash
}

/// Mutable phenotype - runtime container state
type HolonPhenotype = {
    mutable Status: MeshServiceStatus  // Off|Starting|Ready|Lameduck|Failsafe
    mutable ContainerId: string        // Podman container ID
    mutable IP: string                 // Container IP address
    mutable PID: int                   // Main process ID
    mutable StartedAt: DateTimeOffset option
    mutable LastHealthCheck: DateTimeOffset option
    mutable HealthScore: float         // 0.0 - 1.0
    mutable Metrics: MetabolicMetrics  // CPU, Mem, Rx, Tx
    mutable ProofToken: string         // SIL6 verification token
    mutable Divergence: float          // Drift from expected state
}

/// Complete digital twin
type NodeTwin = {
    Geno: HolonGenotype         // Static configuration
    Pheno: HolonPhenotype       // Dynamic state
    History: DuckDbConnection   // Evolution history (append-only)
    State: SqliteConnection     // Real-time state (WAL mode)
}

/// Service status state machine
type MeshServiceStatus =
    | MeshOff                   // Not running
    | MeshStarting              // Container created, not healthy
    | MeshReady                 // Healthy and accepting traffic
    | MeshLameduck              // Draining, no new requests
    | MeshFailsafe              // Error state, intervention required
```

### 3.2 Twin State Machine

```
                    ┌──────────────────────────────────────────┐
                    │                                          │
                    ▼                                          │
    ┌─────────┐  create  ┌──────────┐  healthy  ┌─────────┐   │
    │ MeshOff │─────────▶│ Starting │─────────▶│ MeshReady│   │
    └─────────┘          └──────────┘          └─────────┘   │
         ▲                    │                     │         │
         │                    │ timeout             │ shutdown │
         │                    ▼                     ▼         │
         │              ┌──────────┐          ┌──────────┐   │
         │              │ Failsafe │◀─────────│ Lameduck │   │
         │              └──────────┘  timeout └──────────┘   │
         │                    │                     │         │
         │                    │ reset               │ stopped │
         └────────────────────┴─────────────────────┘─────────┘
```

### 3.3 SQLite State Schema (Real-time)

```sql
-- Twin real-time state (WAL mode, single file per holon)
CREATE TABLE twin_state (
    id TEXT PRIMARY KEY,              -- Holon ID
    status TEXT NOT NULL,             -- MeshServiceStatus
    container_id TEXT,                -- Podman container ID
    ip_address TEXT,                  -- Container IP
    pid INTEGER,                      -- Main process PID
    health_score REAL DEFAULT 0.0,    -- 0.0 - 1.0
    cpu_percent REAL,                 -- CPU usage %
    mem_bytes INTEGER,                -- Memory usage bytes
    rx_bytes INTEGER,                 -- Network received
    tx_bytes INTEGER,                 -- Network transmitted
    proof_token TEXT,                 -- SIL6 verification
    divergence REAL DEFAULT 0.0,      -- State drift
    started_at TEXT,                  -- ISO8601 timestamp
    last_health_check TEXT,           -- ISO8601 timestamp
    updated_at TEXT NOT NULL          -- ISO8601 timestamp
);

-- Version vector for conflict resolution
CREATE TABLE version_vector (
    holon_id TEXT PRIMARY KEY,
    vector TEXT NOT NULL,             -- JSON: {"node1": 5, "node2": 3}
    updated_at TEXT NOT NULL
);
```

### 3.4 DuckDB History Schema (Append-only)

```sql
-- Evolution history (columnar, append-only)
CREATE TABLE twin_history (
    event_id UUID DEFAULT gen_random_uuid(),
    holon_id TEXT NOT NULL,
    event_type TEXT NOT NULL,         -- StateChange|HealthCheck|Error|Metric
    old_status TEXT,
    new_status TEXT,
    details JSON,                     -- Event-specific data
    proof_token TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now(),
    PRIMARY KEY (holon_id, timestamp)
);

-- Metric time series
CREATE TABLE metric_series (
    holon_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,        -- cpu|memory|network_rx|network_tx
    value DOUBLE NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create hypertable-like partitioning
-- Partition by day for efficient time-range queries
```

---

## 4. Data Flow Architecture

### 4.1 Startup Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STARTUP DATA FLOW                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                            │
│  │ CLI Command  │ sa-up / REST POST /api/mesh/start                         │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────┐     ┌─────────────────────────────────────┐               │
│  │ OrchestratorController │ ──▶ Parse compose.yml                           │
│  └──────┬───────┘     │    ──▶ Build dependency DAG                         │
│         │             │    ──▶ Initialize digital twins                     │
│         │             └─────────────────────────────────────┘               │
│         ▼                                                                    │
│  ┌──────────────┐                                                            │
│  │ WaveExecutor │ Kahn's Algorithm                                          │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│    ┌────┴────────────────────────────────────────────────────┐              │
│    │                                                          │              │
│    ▼                        ▼                        ▼        │              │
│  ┌─────────┐          ┌─────────┐          ┌─────────┐       │              │
│  │ Wave 0  │──parallel─│ Wave 1  │──after──│ Wave 2  │       │              │
│  │ Prepare │          │ DB      │          │ App+Obs │       │              │
│  └────┬────┘          └────┬────┘          └────┬────┘       │              │
│       │                    │                    │             │              │
│       ▼                    ▼                    ▼             │              │
│  ┌─────────────────────────────────────────────────────┐     │              │
│  │              PODMAN API (REST)                       │     │              │
│  │  POST /containers/create                             │     │              │
│  │  POST /containers/{id}/start                         │     │              │
│  │  GET  /containers/{id}/json                          │     │              │
│  └─────────────────────────────────────────────────────┘     │              │
│       │                    │                    │             │              │
│       ▼                    ▼                    ▼             │              │
│  ┌─────────────────────────────────────────────────────┐     │              │
│  │              HEALTH CHECK (Async)                    │     │              │
│  │  DB:  pg_isready -h 172.28.0.20 -p 5433             │     │              │
│  │  App: curl http://172.28.0.10:4000/health           │     │              │
│  │  Obs: curl http://172.28.0.30:4317/health           │     │              │
│  └─────────────────────────────────────────────────────┘     │              │
│       │                    │                    │             │              │
│       ▼                    ▼                    ▼             │              │
│  ┌─────────────────────────────────────────────────────┐     │              │
│  │              DIGITAL TWIN UPDATE                     │     │              │
│  │  SQLite: UPDATE twin_state SET status = 'Ready'     │     │              │
│  │  DuckDB: INSERT INTO twin_history (...)             │     │              │
│  │  Zenoh:  PUT indrajaal/mesh/twin/{id}/status        │     │              │
│  └─────────────────────────────────────────────────────┘     │              │
│                                                               │              │
│    └────────────────────────────────────────────────────┘    │              │
│         │                                                     │              │
│         ▼                                                     │              │
│  ┌──────────────┐                                             │              │
│  │ FPPS Verify  │ 5-method consensus                          │              │
│  └──────┬───────┘                                             │              │
│         │                                                     │              │
│         ▼                                                     │              │
│  ┌──────────────┐                                             │              │
│  │ Proof Token  │ Ed25519 signed, SHA3-256 hash               │              │
│  │ Generation   │                                             │              │
│  └──────┬───────┘                                             │              │
│         │                                                     │              │
│         ▼                                                     │              │
│  ┌──────────────┐                                             │              │
│  │ Response     │ 200 OK + Timeline + Proof                   │              │
│  └──────────────┘                                             │              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Shutdown Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SHUTDOWN DATA FLOW                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐                                                            │
│  │ CLI Command  │ sa-down / REST POST /api/mesh/stop                        │
│  └──────┬───────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 0: LAMEDUCK SIGNAL (100ms)                                     │   │
│  │  ├─ For each twin: Pheno.Status ← MeshLameduck                       │   │
│  │  ├─ Zenoh: PUT indrajaal/mesh/control/shutdown                       │   │
│  │  └─ APP: Set /admin/lameduck header                                  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 1: DRAIN (2.5s max, parallel)                                  │   │
│  │  ├─ APP: Wait for active_connections = 0                             │   │
│  │  ├─ OBS: Flush OpenTelemetry batch                                   │   │
│  │  └─ DB:  Wait for active_queries = 0                                 │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 2: STOP (1.5s max, reverse dependency order)                   │   │
│  │  ├─ POST /containers/app/stop                                        │   │
│  │  ├─ POST /containers/obs/stop                                        │   │
│  │  └─ POST /containers/db/stop                                         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ PHASE 3: PERSIST (1s max)                                            │   │
│  │  ├─ DuckDB: INSERT shutdown event into twin_history                  │   │
│  │  ├─ SQLite: UPDATE twin_state SET status = 'Off'                     │   │
│  │  ├─ Zenoh:  Close session                                            │   │
│  │  └─ Generate shutdown report                                         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │                                                                    │
│         ▼                                                                    │
│  ┌──────────────┐                                                            │
│  │ Response     │ 200 OK + Shutdown Report + Duration                       │
│  └──────────────┘                                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Control Flow Specification

### 5.1 OODA Controller State Machine

```fsharp
type OodaState =
    | Observe of ObserveContext
    | Orient of OrientContext
    | Decide of DecideContext
    | Act of ActContext
    | Complete of Result<OodaOutcome, OodaError>

type OodaController = {
    State: OodaState
    CycleCount: int64
    LastCycleTime: TimeSpan
    AverageCycleTime: TimeSpan
    MaxCycleTime: TimeSpan  // 100ms target
}

/// OODA cycle implementation
let runOodaCycle (controller: OodaController) (input: OodaInput) : Async<OodaController> = async {
    let cycleStart = Stopwatch.StartNew()

    // OBSERVE: Gather current state (target: 20ms)
    let! observeResult = observe input
    let observeTime = cycleStart.Elapsed

    // ORIENT: Analyze and contextualize (target: 30ms)
    let! orientResult = orient observeResult
    let orientTime = cycleStart.Elapsed - observeTime

    // DECIDE: Select action (target: 20ms)
    let! decideResult = decide orientResult
    let decideTime = cycleStart.Elapsed - observeTime - orientTime

    // ACT: Execute action (target: 30ms)
    let! actResult = act decideResult
    let actTime = cycleStart.Elapsed - observeTime - orientTime - decideTime

    cycleStart.Stop()

    // Emit telemetry
    do! emitOodaTelemetry {
        CycleId = Guid.NewGuid()
        TotalTime = cycleStart.Elapsed
        ObserveTime = observeTime
        OrientTime = orientTime
        DecideTime = decideTime
        ActTime = actTime
        Outcome = actResult
    }

    return {
        controller with
            State = Complete actResult
            CycleCount = controller.CycleCount + 1L
            LastCycleTime = cycleStart.Elapsed
            AverageCycleTime = updateAverage controller cycleStart.Elapsed
    }
}
```

### 5.2 Wave Executor Control Flow

```fsharp
/// Dependency graph for wave construction
type DependencyGraph = {
    Nodes: Map<string, HolonGenotype>
    Edges: Map<string, string list>  // node -> dependencies
}

/// Wave represents parallel execution group
type Wave = {
    Index: int
    Holons: HolonGenotype list
    Deadline: TimeSpan
}

/// Build waves using Kahn's algorithm
let buildWaves (graph: DependencyGraph) : Wave list =
    let inDegree =
        graph.Nodes
        |> Map.map (fun id _ ->
            graph.Edges
            |> Map.filter (fun _ deps -> List.contains id deps)
            |> Map.count)

    let rec buildWavesRec (remaining: Map<string, int>) (waveIndex: int) (waves: Wave list) =
        let ready =
            remaining
            |> Map.filter (fun _ degree -> degree = 0)
            |> Map.keys
            |> Seq.toList

        if List.isEmpty ready then
            waves
        else
            let wave = {
                Index = waveIndex
                Holons = ready |> List.choose (fun id -> Map.tryFind id graph.Nodes)
                Deadline = calculateDeadline waveIndex
            }

            let updated =
                remaining
                |> Map.filter (fun id _ -> not (List.contains id ready))
                |> Map.map (fun id degree ->
                    let deps = Map.tryFind id graph.Edges |> Option.defaultValue []
                    degree - (deps |> List.filter (fun d -> List.contains d ready) |> List.length))

            buildWavesRec updated (waveIndex + 1) (wave :: waves)

    buildWavesRec inDegree 0 [] |> List.rev

/// Execute waves with deadline enforcement
let executeWaves (waves: Wave list) (twins: Map<string, NodeTwin>) : Async<Result<unit, WaveError>> = async {
    let overallDeadline = TimeSpan.FromSeconds(10.0)
    let startTime = DateTimeOffset.UtcNow

    for wave in waves do
        let waveStart = DateTimeOffset.UtcNow
        let elapsed = waveStart - startTime

        if elapsed > overallDeadline then
            return Error (DeadlineExceeded { Elapsed = elapsed; Deadline = overallDeadline })

        // Execute holons in wave in parallel
        let! results =
            wave.Holons
            |> List.map (fun holon -> executeHolon holon twins wave.Deadline)
            |> Async.Parallel

        // Check for failures
        let failures = results |> Array.choose (function Error e -> Some e | _ -> None)
        if not (Array.isEmpty failures) then
            return Error (WaveFailure { Wave = wave.Index; Errors = failures |> Array.toList })

    return Ok ()
}
```

---

## 6. Transaction Behavior

### 6.1 Container Startup Transaction

```fsharp
/// Transaction for starting a single container
type StartupTransaction = {
    HolonId: string
    Phase: TransactionPhase
    StartedAt: DateTimeOffset
    Timeout: TimeSpan
    Rollback: unit -> Async<unit>
}

type TransactionPhase =
    | TxPrepare          // Validate prerequisites
    | TxCreate           // Create container
    | TxStart            // Start container
    | TxHealthCheck      // Wait for healthy
    | TxVerify           // FPPS verification
    | TxCommit           // Update twin, generate proof
    | TxRollback         // Undo on failure

/// Execute startup transaction with automatic rollback
let executeStartupTx (twin: NodeTwin) : Async<Result<ProofToken, TxError>> = async {
    let tx = {
        HolonId = twin.Geno.Id
        Phase = TxPrepare
        StartedAt = DateTimeOffset.UtcNow
        Timeout = TimeSpan.FromSeconds(4.0)  // Per-container timeout
        Rollback = fun () -> rollbackContainer twin
    }

    try
        // Phase 1: Prepare
        do! validatePrerequisites twin
        let tx = { tx with Phase = TxCreate }

        // Phase 2: Create
        let! containerId = createContainer twin.Geno
        twin.Pheno.ContainerId <- containerId
        twin.Pheno.Status <- MeshStarting
        let tx = { tx with Phase = TxStart }

        // Phase 3: Start
        do! startContainer containerId
        let tx = { tx with Phase = TxHealthCheck }

        // Phase 4: Health Check (async with timeout)
        let! healthy =
            healthCheckWithTimeout twin.Geno.HealthEndpoint (TimeSpan.FromSeconds(2.0))

        if not healthy then
            return Error (HealthCheckFailed { HolonId = twin.Geno.Id })

        let tx = { tx with Phase = TxVerify }

        // Phase 5: FPPS Verification
        let! fppsResult = runFppsConsensus twin
        if not fppsResult.Consensus then
            return Error (FppsConsensusFailed { Result = fppsResult })

        let tx = { tx with Phase = TxCommit }

        // Phase 6: Commit
        twin.Pheno.Status <- MeshReady
        twin.Pheno.HealthScore <- 1.0

        let! proofToken = generateProofToken twin
        twin.Pheno.ProofToken <- proofToken

        // Persist to SQLite
        do! persistTwinState twin

        // Append to DuckDB history
        do! appendTwinHistory twin "StateChange" { OldStatus = "Off"; NewStatus = "Ready" }

        // Publish to Zenoh
        do! publishTwinUpdate twin

        return Ok proofToken

    with ex ->
        // Automatic rollback on any failure
        do! tx.Rollback()
        return Error (TransactionFailed { Phase = tx.Phase; Exception = ex })
}
```

### 6.2 Shutdown Transaction

```fsharp
/// Transaction for graceful shutdown
let executeShutdownTx (twin: NodeTwin) : Async<Result<ShutdownReport, TxError>> = async {
    let startTime = DateTimeOffset.UtcNow

    try
        // Phase 0: Lameduck
        twin.Pheno.Status <- MeshLameduck
        do! publishTwinUpdate twin

        // Phase 1: Drain
        do! drainWithTimeout twin (TimeSpan.FromSeconds(2.0))

        // Phase 2: Stop
        do! stopContainer twin.Pheno.ContainerId
        twin.Pheno.Status <- MeshOff

        // Phase 3: Persist
        do! persistTwinState twin
        do! appendTwinHistory twin "StateChange" { OldStatus = "Lameduck"; NewStatus = "Off" }

        let duration = DateTimeOffset.UtcNow - startTime

        return Ok {
            HolonId = twin.Geno.Id
            Duration = duration
            DrainedConnections = twin.Pheno.Metrics.ActiveConnections
            FlushedTelemetry = true
        }

    with ex ->
        // Force stop on drain timeout
        do! forceStopContainer twin.Pheno.ContainerId
        twin.Pheno.Status <- MeshOff
        return Error (ShutdownFailed { HolonId = twin.Geno.Id; Exception = ex })
}
```

### 6.3 Transaction Behavior by Container Type

| Container | Create Time | Health Check | Drain Time | Stop Time |
|-----------|-------------|--------------|------------|-----------|
| **DB (PostgreSQL)** | 1.0s | pg_isready (2.0s max) | Transaction complete (1.0s) | 0.5s |
| **App (Phoenix)** | 1.0s | HTTP /health (3.0s max) | Connection drain (2.0s) | 0.5s |
| **Obs (OTEL)** | 0.5s | HTTP /health (1.0s max) | Buffer flush (0.5s) | 0.3s |

---

## 7. OODA Loop Implementation

### 7.1 Fast OODA Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  OODA LOOP (<100ms per cycle, 10 cycles per second max)        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  OBSERVE (20ms budget)                                    │   │
│  │  ├─ Read all twin phenotypes from SQLite                  │   │
│  │  ├─ Collect Podman container stats                        │   │
│  │  ├─ Sample health endpoints                               │   │
│  │  └─ Receive Zenoh messages (non-blocking)                 │   │
│  └───────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  ORIENT (30ms budget)                                     │   │
│  │  ├─ Calculate health scores                               │   │
│  │  ├─ Detect state divergence                               │   │
│  │  ├─ Identify SLA violations                               │   │
│  │  ├─ Classify anomalies                                    │   │
│  │  └─ Update mental model                                   │   │
│  └───────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  DECIDE (20ms budget)                                     │   │
│  │  ├─ If all healthy: continue monitoring                   │   │
│  │  ├─ If degraded: trigger healing                          │   │
│  │  ├─ If failed: escalate to failsafe                       │   │
│  │  ├─ If SLA breach: adjust parameters                      │   │
│  │  └─ Select action with highest utility                    │   │
│  └───────────────────────────────────────────────────────────┘   │
│                           │                                      │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  ACT (30ms budget)                                        │   │
│  │  ├─ Execute container commands                            │   │
│  │  ├─ Update twin state                                     │   │
│  │  ├─ Emit telemetry                                        │   │
│  │  ├─ Update dashboard                                      │   │
│  │  └─ Log to fractal logger                                 │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 OODA Metrics Telemetry

```fsharp
type OodaCycleMetrics = {
    CycleId: Guid
    StartedAt: DateTimeOffset
    TotalDuration: TimeSpan

    // Phase durations
    ObserveDuration: TimeSpan
    OrientDuration: TimeSpan
    DecideDuration: TimeSpan
    ActDuration: TimeSpan

    // Quality metrics
    TwinsObserved: int
    AnomaliesDetected: int
    ActionsExecuted: int
    SlaViolations: int

    // SLA compliance
    UnderBudget: bool  // < 100ms
    BudgetRemaining: TimeSpan
}

/// Zenoh topic for OODA telemetry
let publishOodaMetrics (metrics: OodaCycleMetrics) : Async<unit> = async {
    let topic = $"indrajaal/mesh/ooda/{metrics.CycleId}"
    do! zenohPut topic (JsonSerializer.Serialize(metrics))
}
```

---

## 8. Zenoh Telemetry Integration

### 8.1 Topic Hierarchy

```
indrajaal/mesh/
├── control/                    # Control plane (commands)
│   ├── start                   # Start mesh command
│   ├── stop                    # Stop mesh command
│   ├── restart/{holon_id}      # Restart specific holon
│   └── config/{holon_id}       # Configuration updates
│
├── twin/                       # Digital twin state
│   ├── {holon_id}/status       # Current status (Off|Starting|Ready|...)
│   ├── {holon_id}/health       # Health score (0.0-1.0)
│   ├── {holon_id}/metrics      # Metabolic metrics (CPU, Mem, Net)
│   └── {holon_id}/proof        # SIL6 proof token
│
├── ooda/                       # OODA loop telemetry
│   ├── cycle/{cycle_id}        # Per-cycle metrics
│   └── aggregate               # Aggregated statistics
│
├── timeline/                   # Progress tracking
│   ├── wave/{wave_id}          # Wave progress
│   ├── holon/{holon_id}        # Per-holon progress
│   └── overall                 # Overall mesh progress
│
├── health/                     # Health checks
│   ├── {holon_id}/check        # Health check results
│   └── fpps/{holon_id}         # FPPS consensus results
│
└── log/                        # Fractal logs
    ├── L1/{holon_id}           # Critical errors
    ├── L2/{holon_id}           # Errors
    ├── L3/{holon_id}           # Warnings
    ├── L4/{holon_id}           # Info
    └── L5/{holon_id}           # Debug/Trace
```

### 8.2 F# Zenoh Integration

```fsharp
module ZenohMesh =
    open System
    open FSharp.Control

    /// Zenoh session wrapper
    type ZenohSession = {
        Session: nativeptr<unit>  // Rust FFI pointer
        Publishers: Map<string, ZenohPublisher>
        Subscribers: Map<string, ZenohSubscriber>
    }

    /// Initialize Zenoh for mesh orchestration
    let initSession (config: ZenohConfig) : Async<ZenohSession> = async {
        let! session = ZenohFFI.openSession config

        // Create publishers for each topic category
        let! controlPub = ZenohFFI.declarePublisher session "indrajaal/mesh/control/**"
        let! twinPub = ZenohFFI.declarePublisher session "indrajaal/mesh/twin/**"
        let! oodaPub = ZenohFFI.declarePublisher session "indrajaal/mesh/ooda/**"
        let! timelinePub = ZenohFFI.declarePublisher session "indrajaal/mesh/timeline/**"
        let! logPub = ZenohFFI.declarePublisher session "indrajaal/mesh/log/**"

        return {
            Session = session
            Publishers = Map [
                ("control", controlPub)
                ("twin", twinPub)
                ("ooda", oodaPub)
                ("timeline", timelinePub)
                ("log", logPub)
            ]
            Subscribers = Map.empty
        }
    }

    /// Publish twin state update
    let publishTwinState (session: ZenohSession) (twin: NodeTwin) : Async<unit> = async {
        let pub = session.Publishers.["twin"]
        let topic = $"indrajaal/mesh/twin/{twin.Geno.Id}/status"
        let payload = {|
            status = twin.Pheno.Status.ToString()
            health = twin.Pheno.HealthScore
            containerId = twin.Pheno.ContainerId
            ip = twin.Pheno.IP
            timestamp = DateTimeOffset.UtcNow
        |}
        do! ZenohFFI.put pub topic (JsonSerializer.Serialize(payload))
    }

    /// Publish fractal log entry
    let publishLog (session: ZenohSession) (level: int) (holonId: string) (message: string) : Async<unit> = async {
        let pub = session.Publishers.["log"]
        let topic = $"indrajaal/mesh/log/L{level}/{holonId}"
        let payload = {|
            level = level
            holonId = holonId
            message = message
            timestamp = DateTimeOffset.UtcNow
        |}
        do! ZenohFFI.put pub topic (JsonSerializer.Serialize(payload))
    }
```

---

## 9. REST API Specification

### 9.1 OpenAPI Endpoints

```yaml
openapi: 3.1.0
info:
  title: Indrajaal Mesh Orchestration API
  version: 1.0.0
  description: SIL-6 Biomorphic compliant mesh startup/shutdown API

paths:
  /api/mesh/start:
    post:
      summary: Start mesh with SLA guarantee
      description: Start all containers with 10 second SLA
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                timeout_seconds:
                  type: integer
                  default: 10
                verbose:
                  type: boolean
                  default: false
                wave_parallel:
                  type: boolean
                  default: true
      responses:
        '200':
          description: Mesh started successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/StartupResponse'
        '408':
          description: SLA timeout exceeded
        '500':
          description: Startup failed

  /api/mesh/stop:
    post:
      summary: Stop mesh with graceful drain
      description: Stop all containers with 5 second SLA
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                timeout_seconds:
                  type: integer
                  default: 5
                force:
                  type: boolean
                  default: false
      responses:
        '200':
          description: Mesh stopped successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ShutdownResponse'

  /api/mesh/status:
    get:
      summary: Get mesh status
      responses:
        '200':
          description: Current mesh status
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MeshStatus'

  /api/mesh/twin/{holonId}:
    get:
      summary: Get digital twin state
      parameters:
        - name: holonId
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Twin state
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TwinState'

  /api/mesh/timeline:
    get:
      summary: Get timeline dashboard data
      responses:
        '200':
          description: Timeline with plan vs actuals
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Timeline'

  /api/mesh/ooda/metrics:
    get:
      summary: Get OODA loop metrics
      parameters:
        - name: last_n
          in: query
          schema:
            type: integer
            default: 100
      responses:
        '200':
          description: OODA cycle metrics
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/OodaCycleMetrics'

components:
  schemas:
    StartupResponse:
      type: object
      properties:
        success: { type: boolean }
        duration_ms: { type: integer }
        sla_met: { type: boolean }
        waves_executed: { type: integer }
        holons:
          type: array
          items:
            $ref: '#/components/schemas/HolonStartupResult'
        proof_token: { type: string }
        timeline:
          $ref: '#/components/schemas/Timeline'

    HolonStartupResult:
      type: object
      properties:
        id: { type: string }
        status: { type: string }
        duration_ms: { type: integer }
        health_score: { type: number }
        container_id: { type: string }
        ip: { type: string }

    MeshStatus:
      type: object
      properties:
        overall_status: { type: string }
        holons:
          type: array
          items:
            $ref: '#/components/schemas/TwinState'
        last_ooda_cycle: { type: string, format: date-time }
        sla_compliance:
          type: object
          properties:
            startup_p99: { type: integer }
            shutdown_p99: { type: integer }

    TwinState:
      type: object
      properties:
        genotype:
          type: object
          properties:
            id: { type: string }
            role: { type: string }
            image: { type: string }
            port: { type: integer }
        phenotype:
          type: object
          properties:
            status: { type: string }
            container_id: { type: string }
            ip: { type: string }
            health_score: { type: number }
            metrics:
              type: object
              properties:
                cpu_percent: { type: number }
                mem_bytes: { type: integer }
                rx_bytes: { type: integer }
                tx_bytes: { type: integer }

    Timeline:
      type: object
      properties:
        started_at: { type: string, format: date-time }
        deadline: { type: string, format: date-time }
        current_wave: { type: integer }
        total_waves: { type: integer }
        tasks:
          type: array
          items:
            type: object
            properties:
              id: { type: string }
              name: { type: string }
              planned_start_ms: { type: integer }
              planned_duration_ms: { type: integer }
              actual_start_ms: { type: integer }
              actual_duration_ms: { type: integer }
              status: { type: string }
              parallel_with: { type: array, items: { type: string } }
```

### 9.2 REST API Implementation (F#)

```fsharp
module MeshApi =
    open Giraffe
    open Microsoft.AspNetCore.Http

    /// Start mesh handler
    let startMesh : HttpHandler =
        fun next ctx -> task {
            let! request = ctx.BindJsonAsync<StartRequest>()
            let timeout = TimeSpan.FromSeconds(float request.TimeoutSeconds)

            let! result = MeshOrchestrator.start timeout request.Verbose

            match result with
            | Ok response ->
                return! json response next ctx
            | Error (DeadlineExceeded _) ->
                ctx.SetStatusCode 408
                return! json {| error = "SLA timeout exceeded" |} next ctx
            | Error err ->
                ctx.SetStatusCode 500
                return! json {| error = err.ToString() |} next ctx
        }

    /// Stop mesh handler
    let stopMesh : HttpHandler =
        fun next ctx -> task {
            let! request = ctx.BindJsonAsync<StopRequest>()
            let timeout = TimeSpan.FromSeconds(float request.TimeoutSeconds)

            let! result = MeshOrchestrator.stop timeout request.Force

            match result with
            | Ok response -> return! json response next ctx
            | Error err ->
                ctx.SetStatusCode 500
                return! json {| error = err.ToString() |} next ctx
        }

    /// API routes
    let routes : HttpHandler =
        choose [
            POST >=> route "/api/mesh/start" >=> startMesh
            POST >=> route "/api/mesh/stop" >=> stopMesh
            GET >=> route "/api/mesh/status" >=> getStatus
            GET >=> routef "/api/mesh/twin/%s" getTwin
            GET >=> route "/api/mesh/timeline" >=> getTimeline
            GET >=> route "/api/mesh/ooda/metrics" >=> getOodaMetrics
        ]
```

---

## 10. Timeline Dashboard

### 10.1 Dashboard Layout (tview)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│  INDRAJAAL MESH ORCHESTRATION                                 [10s refresh]   │
│  Status: ████████████████████ READY                           SLA: ✓ 8.2s     │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  TIMELINE (Plan vs Actual)                                                     │
│  ┌───────────────────────────────────────────────────────────────────────────┐ │
│  │ T=0s        2s         4s         6s         8s        10s               │ │
│  │ ├──────────┼──────────┼──────────┼──────────┼──────────┤                 │ │
│  │ │                                                                        │ │
│  │ │ WAVE 0: Prepare                                                        │ │
│  │ │ ████ Plan: 0-500ms                                                     │ │
│  │ │ ███  Actual: 0-420ms ✓                                                 │ │
│  │ │                                                                        │ │
│  │ │ WAVE 1: Database                                                       │ │
│  │ │     ██████████████████ Plan: 500ms-4s                                  │ │
│  │ │     █████████████████  Actual: 420ms-3.8s ✓                            │ │
│  │ │                                                                        │ │
│  │ │ WAVE 2: App + Obs (Parallel)                                          │ │
│  │ │                      ████████████████████ Plan: 4s-9s                 │ │
│  │ │                      ██████████████████   Actual: 3.8s-8.0s ✓         │ │
│  │ │                                                                        │ │
│  │ │ WAVE 3: Verify                                                         │ │
│  │ │                                           ████ Plan: 9s-10s            │ │
│  │ │                                           ██   Actual: 8.0s-8.2s ✓    │ │
│  │ │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│  HOLONS                           OODA METRICS                                  │
│  ┌─────────────────────────────┐  ┌─────────────────────────────────────────┐  │
│  │ db-primary   ███████████ ✓  │  │ Cycle Time:  45ms avg (100ms budget)   │  │
│  │   Status: Ready             │  │ Cycles/sec:  22                         │  │
│  │   Health: 100%              │  │ Observe:     12ms avg                   │  │
│  │   IP: 172.28.0.20:5433      │  │ Orient:      15ms avg                   │  │
│  │   CPU: 2.3%  Mem: 128MB     │  │ Decide:      8ms avg                    │  │
│  │                             │  │ Act:         10ms avg                   │  │
│  │ app-1        ███████████ ✓  │  │ Budget Used: ███████░░░ 45%            │  │
│  │   Status: Ready             │  └─────────────────────────────────────────┘  │
│  │   Health: 100%              │                                                │
│  │   IP: 172.28.0.10:4000      │  ZENOH TELEMETRY                              │
│  │   CPU: 5.1%  Mem: 256MB     │  ┌─────────────────────────────────────────┐  │
│  │                             │  │ Published:   1,247 msgs                 │  │
│  │ obs-1        ███████████ ✓  │  │ Received:    523 msgs                   │  │
│  │   Status: Ready             │  │ Topics:      15 active                  │  │
│  │   Health: 100%              │  │ Latency:     2.3ms avg                  │  │
│  │   IP: 172.28.0.30:4317      │  └─────────────────────────────────────────┘  │
│  │   CPU: 1.2%  Mem: 64MB      │                                                │
│  └─────────────────────────────┘                                                │
│                                                                                 │
│  COMMANDS: [s]tart  [x]stop  [r]estart  [d]etails  [l]ogs  [q]uit              │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Dashboard Data Model

```fsharp
type DashboardState = {
    MeshStatus: MeshOverallStatus
    Holons: Map<string, HolonDashboardView>
    Timeline: TimelineView
    OodaMetrics: OodaAggregate
    ZenohStats: ZenohStatistics
    LastUpdate: DateTimeOffset
    RefreshInterval: TimeSpan
}

type TimelineView = {
    StartedAt: DateTimeOffset
    Deadline: DateTimeOffset
    CurrentWave: int
    TotalWaves: int
    Tasks: TimelineTask list
}

type TimelineTask = {
    Id: string
    Name: string
    PlannedStart: TimeSpan
    PlannedDuration: TimeSpan
    ActualStart: TimeSpan option
    ActualDuration: TimeSpan option
    Status: TaskStatus
    ParallelWith: string list
    Progress: float  // 0.0 - 1.0
}

type TaskStatus =
    | Pending
    | Running
    | Completed
    | Failed
    | Skipped

/// Render dashboard with ANSI escape codes
let renderDashboard (state: DashboardState) : string =
    let sb = StringBuilder()

    // Header
    sb.AppendLine($"{ANSI.CYAN}╔{'═' |> String.replicate 78}╗{ANSI.RESET}")
    sb.AppendLine($"{ANSI.CYAN}║{ANSI.RESET}  INDRAJAAL MESH ORCHESTRATION                                 [10s refresh]   {ANSI.CYAN}║{ANSI.RESET}")

    // Status bar
    let statusColor = if state.MeshStatus = Ready then ANSI.GREEN else ANSI.YELLOW
    let statusBar = renderProgressBar state.MeshStatus.Progress 20
    sb.AppendLine($"{ANSI.CYAN}║{ANSI.RESET}  Status: {statusColor}{statusBar}{ANSI.RESET} {state.MeshStatus}                           SLA: {renderSlaStatus state.SlaMet}     {ANSI.CYAN}║{ANSI.RESET}")

    // Timeline section
    sb.AppendLine(renderTimeline state.Timeline)

    // Holons section
    sb.AppendLine(renderHolons state.Holons)

    // OODA metrics
    sb.AppendLine(renderOodaMetrics state.OodaMetrics)

    // Commands
    sb.AppendLine($"{ANSI.CYAN}║{ANSI.RESET}  COMMANDS: [s]tart  [x]stop  [r]estart  [d]etails  [l]ogs  [q]uit              {ANSI.CYAN}║{ANSI.RESET}")
    sb.AppendLine($"{ANSI.CYAN}╚{'═' |> String.replicate 78}╝{ANSI.RESET}")

    sb.ToString()
```

---

## 11. Implementation Approach

### 11.1 Phase Breakdown

| Phase | Focus | Duration | Deliverables |
|-------|-------|----------|--------------|
| **Phase 1** | Core Types & Twin Layer | 2 days | HolonGenotype, HolonPhenotype, NodeTwin, SQLite/DuckDB schemas |
| **Phase 2** | Wave Executor | 2 days | Kahn's algorithm, parallel wave execution, deadline enforcement |
| **Phase 3** | OODA Controller | 2 days | Fast OODA loop, telemetry, metrics |
| **Phase 4** | Zenoh Integration | 2 days | Topic hierarchy, publishers, subscribers |
| **Phase 5** | REST API | 1 day | OpenAPI endpoints, handlers |
| **Phase 6** | tview Dashboard | 2 days | TUI layout, ANSI rendering, keyboard handling |
| **Phase 7** | Integration & Test | 3 days | End-to-end testing, SLA validation |

### 11.2 File Structure

```
lib/cepaf/src/Cepaf/
├── Mesh/
│   ├── Types.fs                  # HolonGenotype, HolonPhenotype, NodeTwin
│   ├── Twin.fs                   # Digital twin management
│   ├── Wave.fs                   # Wave executor with Kahn's algorithm
│   ├── Ooda.fs                   # OODA controller
│   ├── Transaction.fs            # Startup/shutdown transactions
│   └── Supervisor.fs             # Agent supervisor per container
│
├── Telemetry/
│   ├── ZenohMesh.fs              # Zenoh pub/sub integration
│   └── FractalLog.fs             # 5-level fractal logging
│
├── Api/
│   ├── Routes.fs                 # REST API routes
│   ├── Handlers.fs               # Request handlers
│   └── OpenApi.fs                # OpenAPI schema generation
│
├── Dashboard/
│   ├── TviewApp.fs               # tview application
│   ├── Layout.fs                 # Dashboard layout
│   ├── Timeline.fs               # Timeline rendering
│   ├── Ansi.fs                   # ANSI escape codes
│   └── Keyboard.fs               # Keyboard event handling
│
└── Persistence/
    ├── SqliteTwin.fs             # SQLite real-time state
    └── DuckDbHistory.fs          # DuckDB evolution history
```

### 11.3 Integration with sa-* Commands

```nix
# devenv.nix updates
sa-up = ''
  echo "Starting mesh with SIL-6 Biomorphic orchestration..."
  dotnet run --project lib/cepaf/src/Cepaf.Mesh -- start --timeout 10 --verbose
'';

sa-down = ''
  echo "Stopping mesh with graceful drain..."
  dotnet run --project lib/cepaf/src/Cepaf.Mesh -- stop --timeout 5
'';

sa-status = ''
  echo "Mesh status:"
  dotnet run --project lib/cepaf/src/Cepaf.Mesh -- status --json
'';

sa-dashboard = ''
  echo "Opening mesh dashboard..."
  dotnet run --project lib/cepaf/src/Cepaf.Mesh -- dashboard
'';

sa-timeline = ''
  echo "Mesh timeline:"
  dotnet run --project lib/cepaf/src/Cepaf.Mesh -- timeline
'';
```

---

## 12. Test Approach

### 12.1 TDG Test Pyramid

```
                    ╱╲
                   ╱  ╲
                  ╱ E2E╲               5 tests
                 ╱──────╲
                ╱ Integ  ╲            25 tests
               ╱──────────╲
              ╱  Property   ╲         50 tests
             ╱──────────────╲
            ╱     Unit       ╲       100 tests
           ╱──────────────────╲
          ╱    F# Expecto      ╲    180 total
         ╱━━━━━━━━━━━━━━━━━━━━━━╲
```

### 12.2 Test Categories

| Category | Tests | Focus |
|----------|-------|-------|
| **Unit** | 100 | Types, pure functions, state machines |
| **Property** | 50 | Wave ordering, OODA timing, health thresholds |
| **Integration** | 25 | Podman API, Zenoh pub/sub, SQLite/DuckDB |
| **E2E** | 5 | Full startup/shutdown with SLA verification |

### 12.3 Property Tests (FsCheck)

```fsharp
module MeshPropertyTests =
    open FsCheck
    open FsCheck.Xunit

    /// Wave ordering preserves dependencies
    [<Property>]
    let ``wave ordering respects dependencies`` (graph: DependencyGraph) =
        let waves = Wave.buildWaves graph
        waves
        |> List.pairwise
        |> List.forall (fun (w1, w2) ->
            w2.Holons
            |> List.forall (fun h ->
                h.Dependencies
                |> List.forall (fun dep ->
                    w1.Holons |> List.exists (fun h' -> h'.Id = dep))))

    /// OODA cycle completes within budget
    [<Property>]
    let ``OODA cycle under 100ms`` (inputs: OodaInput list) =
        inputs
        |> List.map (fun input ->
            let sw = Stopwatch.StartNew()
            let _ = Ooda.runCycle input |> Async.RunSynchronously
            sw.Stop()
            sw.Elapsed < TimeSpan.FromMilliseconds(100.0))
        |> List.forall id

    /// Startup completes within SLA
    [<Property(MaxTest = 10)>]
    let ``startup within 10 second SLA`` () =
        let sw = Stopwatch.StartNew()
        let result = MeshOrchestrator.start (TimeSpan.FromSeconds(10.0)) false |> Async.RunSynchronously
        sw.Stop()
        match result with
        | Ok _ -> sw.Elapsed <= TimeSpan.FromSeconds(10.0)
        | Error _ -> false  // Any error is a failure

    /// Shutdown completes within SLA
    [<Property(MaxTest = 10)>]
    let ``shutdown within 5 second SLA`` () =
        // First start
        let _ = MeshOrchestrator.start (TimeSpan.FromSeconds(10.0)) false |> Async.RunSynchronously

        let sw = Stopwatch.StartNew()
        let result = MeshOrchestrator.stop (TimeSpan.FromSeconds(5.0)) false |> Async.RunSynchronously
        sw.Stop()
        match result with
        | Ok _ -> sw.Elapsed <= TimeSpan.FromSeconds(5.0)
        | Error _ -> false
```

### 12.4 Integration Tests

```fsharp
module MeshIntegrationTests =
    open Expecto

    [<Tests>]
    let tests = testList "Mesh Integration" [
        testAsync "Podman container lifecycle" {
            // Create
            let! containerId = Podman.createContainer testGenotype
            Expect.isNotEmpty containerId "Container should be created"

            // Start
            do! Podman.startContainer containerId
            let! status = Podman.getContainerStatus containerId
            Expect.equal status "running" "Container should be running"

            // Health check
            let! healthy = Podman.waitForHealthy containerId (TimeSpan.FromSeconds(5.0))
            Expect.isTrue healthy "Container should become healthy"

            // Stop
            do! Podman.stopContainer containerId
            let! status = Podman.getContainerStatus containerId
            Expect.equal status "exited" "Container should be stopped"

            // Cleanup
            do! Podman.removeContainer containerId
        }

        testAsync "Zenoh pub/sub round trip" {
            let! session = ZenohMesh.initSession ZenohConfig.Default

            let received = ref None
            let! _ = ZenohMesh.subscribe session "indrajaal/mesh/test/**" (fun msg ->
                received := Some msg)

            do! ZenohMesh.publish session "indrajaal/mesh/test/ping" "hello"
            do! Async.Sleep 100

            Expect.isSome !received "Should receive message"
            Expect.equal (!received).Value "hello" "Message content should match"

            do! ZenohMesh.close session
        }

        testAsync "SQLite twin state persistence" {
            let twin = createTestTwin "test-holon"

            // Write
            do! SqliteTwin.persist twin

            // Read
            let! loaded = SqliteTwin.load twin.Geno.Id
            Expect.equal loaded.Pheno.Status twin.Pheno.Status "Status should persist"

            // Update
            twin.Pheno.Status <- MeshReady
            do! SqliteTwin.persist twin

            let! reloaded = SqliteTwin.load twin.Geno.Id
            Expect.equal reloaded.Pheno.Status MeshReady "Updated status should persist"
        }
    ]
```

---

## 13. Code Approach

### 13.1 F# Best Practices

| Practice | Enforcement |
|----------|-------------|
| Immutable by default | Use `let` not `let mutable` except for Pheno |
| Result types for errors | `Result<'T, 'E>` instead of exceptions |
| Async everywhere | `Async<'T>` for all I/O operations |
| Type-driven design | Discriminated unions for state machines |
| Property-based tests | FsCheck for all pure functions |
| No null | `Option<'T>` instead of null |

### 13.2 Error Handling Strategy

```fsharp
/// All mesh errors are discriminated union
type MeshError =
    // SLA errors
    | DeadlineExceeded of { Elapsed: TimeSpan; Deadline: TimeSpan }
    | WaveTimeout of { WaveIndex: int; Elapsed: TimeSpan }

    // Container errors
    | ContainerCreateFailed of { HolonId: string; Message: string }
    | ContainerStartFailed of { HolonId: string; Message: string }
    | HealthCheckFailed of { HolonId: string; Attempts: int }

    // Verification errors
    | FppsConsensusFailed of { HolonId: string; Votes: int; Required: int }
    | ProofTokenInvalid of { HolonId: string; Reason: string }

    // System errors
    | PodmanUnavailable
    | ZenohSessionFailed of { Reason: string }
    | DatabaseError of { Operation: string; Message: string }

/// Error logging with fractal levels
let logError (err: MeshError) : Async<unit> = async {
    let level, message =
        match err with
        | DeadlineExceeded d -> 1, $"SLA deadline exceeded: {d.Elapsed} > {d.Deadline}"
        | WaveTimeout w -> 1, $"Wave {w.WaveIndex} timed out after {w.Elapsed}"
        | ContainerCreateFailed c -> 2, $"Container {c.HolonId} create failed: {c.Message}"
        | ContainerStartFailed c -> 2, $"Container {c.HolonId} start failed: {c.Message}"
        | HealthCheckFailed h -> 2, $"Health check failed for {h.HolonId} after {h.Attempts} attempts"
        | FppsConsensusFailed f -> 2, $"FPPS consensus failed for {f.HolonId}: {f.Votes}/{f.Required}"
        | ProofTokenInvalid p -> 3, $"Invalid proof token for {p.HolonId}: {p.Reason}"
        | PodmanUnavailable -> 1, "Podman daemon unavailable"
        | ZenohSessionFailed z -> 2, $"Zenoh session failed: {z.Reason}"
        | DatabaseError d -> 2, $"Database {d.Operation} failed: {d.Message}"

    do! FractalLog.log level message
}
```

### 13.3 Dependency Injection Pattern

```fsharp
/// Dependencies for mesh orchestration
type MeshDependencies = {
    Podman: IPodmanClient
    Zenoh: IZenohSession
    TwinStore: ITwinStore
    HistoryStore: IHistoryStore
    Logger: IFractalLogger
    Clock: IClock
}

/// Create production dependencies
let createProductionDeps () : Async<MeshDependencies> = async {
    let! podman = PodmanClient.create "unix:///run/user/1000/podman/podman.sock"
    let! zenoh = ZenohSession.open ZenohConfig.Default
    let twinStore = SqliteTwinStore.create "data/holons/mesh/twins.db"
    let historyStore = DuckDbHistoryStore.create "data/holons/mesh/history.duckdb"
    let logger = ZenohFractalLogger.create zenoh

    return {
        Podman = podman
        Zenoh = zenoh
        TwinStore = twinStore
        HistoryStore = historyStore
        Logger = logger
        Clock = SystemClock()
    }
}

/// Create test dependencies with mocks
let createTestDeps (mockPodman: IPodmanClient) : MeshDependencies = {
    Podman = mockPodman
    Zenoh = InMemoryZenoh()
    TwinStore = InMemoryTwinStore()
    HistoryStore = InMemoryHistoryStore()
    Logger = ConsoleLogger()
    Clock = FakeClock()
}
```

---

## 14. STAMP Constraints

### 14.1 Mesh Orchestration Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-MESH-001 | Startup MUST complete within 10 seconds | CRITICAL | Timer + test |
| SC-MESH-002 | Shutdown MUST complete within 5 seconds | CRITICAL | Timer + test |
| SC-MESH-003 | OODA cycle MUST complete within 100ms | HIGH | Telemetry |
| SC-MESH-004 | Health checks MUST complete within 500ms | HIGH | Timeout |
| SC-MESH-005 | Twin state MUST be persisted before status change | CRITICAL | Transaction |
| SC-MESH-006 | All state changes MUST be logged to DuckDB | HIGH | Audit |
| SC-MESH-007 | Proof tokens MUST be Ed25519 signed | CRITICAL | Crypto verify |
| SC-MESH-008 | Wave execution MUST respect dependency order | CRITICAL | DAG validation |
| SC-MESH-009 | Dashboard MUST refresh every 10 seconds | MEDIUM | Watchdog |
| SC-MESH-010 | Zenoh messages MUST be published within 50ms | HIGH | Telemetry |
| SC-MESH-011 | Container rollback MUST occur on failure | CRITICAL | Integration test |
| SC-MESH-012 | Lameduck drain MUST complete before stop | HIGH | Integration test |
| SC-MESH-013 | FPPS consensus MUST reach 5/5 agreement | CRITICAL | Voting |
| SC-MESH-014 | SQLite WAL mode MUST be enabled | HIGH | Config check |
| SC-MESH-015 | DuckDB history MUST be append-only | CRITICAL | Schema constraint |

### 14.2 SIL-6 Biomorphic Compliance Matrix

| IEC 61508 Requirement | Implementation | Evidence |
|----------------------|----------------|----------|
| **Systematic Capability SC 4** | Formal specification | This document |
| **Hardware Fault Tolerance 1** | Digital twins + rollback | Transaction system |
| **Safe Failure Fraction ≥ 99%** | Fail-safe defaults | All containers → MeshFailsafe on error |
| **Proof Test Coverage 99%** | Property tests | FsCheck test suite |
| **Diagnostic Coverage 99%** | Health checks + OODA | Continuous monitoring |
| **Common Cause Factor < 2%** | Independent paths | Podman API + Zenoh + REST |
| **Lambda (PFD) < 10^-8/h** | Redundant verification | FPPS 5-method consensus |

---

## 15. FMEA Analysis

### 15.1 Failure Mode Table

| ID | Failure Mode | Effect | S | O | D | RPN | Mitigation |
|----|--------------|--------|---|---|---|-----|------------|
| FM-001 | Container create timeout | Startup fails | 8 | 3 | 4 | 96 | Pre-pull images, retry with backoff |
| FM-002 | Health check never passes | Container stuck in Starting | 7 | 4 | 3 | 84 | Timeout + auto-rollback |
| FM-003 | Podman API unavailable | All operations fail | 9 | 2 | 5 | 90 | Pre-check API, circuit breaker |
| FM-004 | Zenoh connection lost | Telemetry gaps | 5 | 4 | 4 | 80 | Reconnect with backoff, buffer locally |
| FM-005 | SQLite write failure | State not persisted | 8 | 2 | 3 | 48 | WAL mode, retry, failsafe |
| FM-006 | DuckDB append failure | History gap | 6 | 2 | 4 | 48 | Queue + retry, audit log |
| FM-007 | OODA cycle exceeds 100ms | Dashboard lag | 4 | 5 | 2 | 40 | Budget monitoring, throttle |
| FM-008 | FPPS consensus fails | Proof not generated | 7 | 3 | 3 | 63 | Retry, manual approval path |
| FM-009 | Drain timeout | Data loss risk | 7 | 3 | 4 | 84 | Force stop with warning |
| FM-010 | Dependency cycle in DAG | Startup deadlock | 9 | 1 | 8 | 72 | Validate DAG at parse time |

### 15.2 Risk Priority Numbers

- **RPN > 100**: Requires immediate redesign (None)
- **RPN 50-100**: Requires mitigation before release (FM-001, FM-002, FM-003, FM-004, FM-008, FM-009, FM-010)
- **RPN < 50**: Monitor and improve (FM-005, FM-006, FM-007)

---

## 16. TDG Test Requirements

### 16.1 Dual Property Testing

```fsharp
// All property tests must use both FsCheck and StreamData patterns
// per SC-PROP-023 and SC-PROP-024

open FsCheck
open FsCheck.Xunit
open Hedgehog  // F# equivalent of StreamData

module TdgMeshTests =
    // FsCheck property (PropCheck pattern)
    [<Property>]
    let ``FsCheck: wave count equals ceil of holon count / parallelism`` (holons: NonEmptyArray<HolonGenotype>) =
        let waves = Wave.buildWaves { Nodes = holons.Get |> Array.map (fun h -> h.Id, h) |> Map.ofArray; Edges = Map.empty }
        waves.Length <= holons.Get.Length

    // Hedgehog property (StreamData pattern)
    let ``Hedgehog: all holons appear exactly once`` = property {
        let! holons = Gen.list (Range.linear 1 10) Generators.holonGenotype
        let graph = { Nodes = holons |> List.map (fun h -> h.Id, h) |> Map.ofList; Edges = Map.empty }
        let waves = Wave.buildWaves graph
        let allHolons = waves |> List.collect (fun w -> w.Holons) |> List.map (fun h -> h.Id)
        return allHolons |> List.distinct = allHolons
    }
```

### 16.2 Coverage Requirements

| Module | Line Coverage | Branch Coverage | Property Tests |
|--------|--------------|-----------------|----------------|
| Types.fs | 100% | 100% | 10 |
| Twin.fs | 95% | 90% | 15 |
| Wave.fs | 100% | 100% | 20 |
| Ooda.fs | 95% | 90% | 10 |
| Transaction.fs | 90% | 85% | 10 |
| **Total** | **95%** | **90%** | **65** |

---

## 17. AOR Rules

### 17.1 Mesh-Specific AOR Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-MESH-001 | VERIFY container image exists before create | Pre-check in Wave 0 |
| AOR-MESH-002 | LOG all state transitions to Zenoh | Mandatory telemetry |
| AOR-MESH-003 | ROLLBACK on any failure during startup | Transaction guard |
| AOR-MESH-004 | PERSIST twin state before status change | SQLite write-ahead |
| AOR-MESH-005 | TIMEOUT all Podman API calls at 5 seconds | HTTP client config |
| AOR-MESH-006 | RETRY transient failures with exponential backoff | Circuit breaker |
| AOR-MESH-007 | DRAIN connections before container stop | Lameduck phase |
| AOR-MESH-008 | REFRESH dashboard at exactly 10 second intervals | Timer with jitter |
| AOR-MESH-009 | VALIDATE DAG acyclicity before wave execution | Kahn's algorithm check |
| AOR-MESH-010 | EMIT OODA metrics after every cycle | Zenoh publisher |

### 17.2 Integration with Existing AOR Rules

This specification integrates with and extends:

- **AOR-HOLON-001 through AOR-HOLON-020**: SQLite/DuckDB twin storage
- **AOR-REG-001 through AOR-REG-012**: Immutable register for proof tokens
- **AOR-BIO-001 through AOR-BIO-007**: Biomorphic execution patterns
- **AOR-CLI-001 through AOR-CLI-004**: REST API design
- **AOR-GA-001 through AOR-GA-008**: GA release verification

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Digital Twin** | Software representation of a physical container with genotype (static config) and phenotype (dynamic state) |
| **FPPS** | Five-Point Verification System: Pattern, AST, Stat, Binary, LineByLine consensus |
| **Genotype** | Immutable configuration defining a holon's identity and capabilities |
| **Holon** | Self-contained unit that is both whole and part of a larger system |
| **Lameduck** | Graceful shutdown state where no new requests are accepted but existing ones complete |
| **OODA** | Observe-Orient-Decide-Act cybernetic control loop |
| **Phenotype** | Mutable runtime state reflecting current container health and metrics |
| **Proof Token** | Ed25519 signed, SHA3-256 hashed verification of successful operation |
| **SIL-6 Biomorphic** | Safety Integrity Level 4, highest level per IEC 61508 |
| **Wave** | Group of containers that can start in parallel after their dependencies are satisfied |

---

## Appendix B: References

1. IEC 61508: Functional Safety of E/E/PE Systems
2. CLAUDE.md v21.3.0: System Specification
3. NASA-STD-3000: Human-System Integration Standards
4. NUREG-0700: Human-System Interface Design Review Guidelines
5. Google SRE: Lameduck Draining Pattern
6. Zenoh Documentation: https://zenoh.io/docs/

---

**Document Control**

| Field | Value |
|-------|-------|
| Status | SPECIFICATION |
| Version | 1.0.0 |
| Created | 2026-01-04 |
| Author | Claude Opus 4.5 |
| STAMP | SC-MESH-001 to SC-MESH-015 |
| AOR | AOR-MESH-001 to AOR-MESH-010 |
| Review | Pending |

---

*End of Document*
