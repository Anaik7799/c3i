# SIL-6 Mesh State Capture & Recovery - 7-Level Fractal Impact Analysis

**Version**: 1.0.0
**Date**: 2026-01-09
**STAMP Compliance**: SC-IMPACT-*, SC-FRACTAL-*
**Author**: Claude Opus 4.5 (Cybernetic Architect)
**Reference**: MESH_STATE_CAPTURE_AND_RECOVERY.md

---

## Executive Summary

This document provides a comprehensive 7-level fractal analysis of the Mesh State Capture and Recovery system, analyzing every component's impact across all VSM (Viable System Model) layers and their cascading ripple effects throughout the SIL-6 Biomorphic Fractal Mesh architecture.

---

## 7-Level Fractal Hierarchy Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         7-LEVEL FRACTAL HIERARCHY                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  L7 ─ FEDERATION    │ Cross-holon trust, protocol negotiation, global state    │
│         │                                                                        │
│         ▼                                                                        │
│  L6 ─ CLUSTER       │ Multi-node consensus, distributed state, quorum          │
│         │                                                                        │
│         ▼                                                                        │
│  L5 ─ NODE          │ Single machine resources, OS-level services              │
│         │                                                                        │
│         ▼                                                                        │
│  L4 ─ CONTAINER     │ Isolated runtime environments, network namespaces        │
│         │                                                                        │
│         ▼                                                                        │
│  L3 ─ HOLON         │ Self-contained autonomous units, agent logic             │
│         │                                                                        │
│         ▼                                                                        │
│  L2 ─ COMPONENT     │ Module boundaries, service interfaces, APIs              │
│         │                                                                        │
│         ▼                                                                        │
│  L1 ─ FUNCTION      │ Individual functions, I/O contracts, unit logic          │
│         │                                                                        │
│         ▼                                                                        │
│  L0 ─ RUNTIME       │ BEAM VM, NIFs, system calls, memory management           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. ARTIFACT CATEGORY: Podman-Compose Configuration Files

### 1.1 Primary Artifact: `podman-compose-prod-standalone.yml`

#### L0 - RUNTIME Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Process spawning | Container runtime creates isolated Linux namespaces | CRITICAL | ↑L1-L7 |
| Memory mapping | Each container gets dedicated memory space (12GB APP, 4GB DB, 10GB OBS) | HIGH | ↑L1-L4 |
| CPU scheduling | SC-METRICS-003: 16 schedulers, 16 dirty I/O via ELIXIR_ERL_OPTIONS | CRITICAL | ↑L1-L3 |
| Network stack | Virtual interfaces created for 172.28.0.0/16 mesh network | HIGH | ↑L4-L6 |
| Filesystem layers | OverlayFS mounts for container layers + volume binds | MEDIUM | ↑L1-L4 |

**Ripple Analysis (L0 → L7):**
```
L0: Container runtime initializes → cgroups, namespaces, seccomp
  ↓
L1: Process isolation enables → safe function execution without interference
  ↓
L2: Module boundaries enforced → OTP applications run in isolated containers
  ↓
L3: Holon autonomy achieved → each container is self-governing unit
  ↓
L4: Container orchestration → podman-compose manages lifecycle
  ↓
L5: Node resources allocated → host OS provides compute/memory/network
  ↓
L6: Cluster potential → compose can scale to multi-container deployments
  ↓
L7: Federation ready → standardized interfaces enable cross-holon trust
```

#### L1 - FUNCTION Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Health checks | `pg_isready`, `curl` health endpoints called periodically | HIGH | ↑L2-L4 |
| Port binding | Functions exposed on specific ports (5433, 4000, 4317, etc.) | CRITICAL | ↑L2-L6 |
| Environment injection | ENV vars passed to container runtime affect function behavior | HIGH | ↑L2-L3 |
| Volume mounts | File I/O functions access host paths via bind mounts | MEDIUM | ↑L2-L4 |

**Ripple Analysis (L1 → L7):**
```
L1: Health check function → returns boolean health status
  ↓
L2: Supervisor module → aggregates health from multiple endpoints
  ↓
L3: Holon health → composite health score computed
  ↓
L4: Container orchestrator → restart policy triggered on failure
  ↓
L5: Node watchdog → OS-level service management engaged
  ↓
L6: Cluster health → quorum recalculated on container state change
  ↓
L7: Federation heartbeat → propagate health to peer holons
```

#### L2 - COMPONENT Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Service discovery | Containers find each other via DNS (indrajaal-db-prod, etc.) | CRITICAL | ↑L3-L6 |
| API contracts | OTEL gRPC (4317), Prometheus (9090), Phoenix HTTP (4000) | CRITICAL | ↑L3-L7 |
| Database connectivity | Ecto pool connects to PostgreSQL at 172.28.0.20:5433 | CRITICAL | ↑L3-L5 |
| Message queues | Redis (6379) provides pub/sub within APP container | HIGH | ↑L3-L4 |

**Ripple Analysis (L2 → L7):**
```
L2: Service interface → API endpoint responds
  ↓
L3: Holon integration → Ash domains query/mutate via API
  ↓
L4: Container network → cross-container communication via mesh network
  ↓
L5: Host networking → NAT/port forwarding to external clients
  ↓
L6: Cluster routing → load balancer distributes traffic
  ↓
L7: Federation API → external holons access via standardized protocols
```

#### L3 - HOLON Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| State sovereignty | Each container maintains its own holon state (SQLite/DuckDB) | CRITICAL | ↑L4-L7 |
| Agent deployment | 50 agents distributed across container runtime | HIGH | ↑L4-L6 |
| Cognitive autonomy | OODA loops run independently within each container | HIGH | ↑L4-L5 |
| Recovery boundary | Container restart triggers holon regeneration | CRITICAL | ↑L4-L6 |

**Corruption Impact Matrix (L3):**
| If Corrupted | Immediate Effect | Cascade Effect | Recovery Action |
|--------------|------------------|----------------|-----------------|
| compose file | Containers won't start | All L4-L7 functions fail | Restore from backup |
| network config | Inter-service comms fail | Holon isolation | Rebuild networks |
| volume mounts | State persistence lost | Data corruption risk | Restore KMS state |
| env vars | Misconfigured runtime | Subtle bugs, crashes | Re-inject from backup |

#### L4 - CONTAINER Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Lifecycle management | podman-compose up/down orchestrates 4 containers | CRITICAL | ↑L5-L7 |
| Resource isolation | Memory/CPU limits prevent noisy neighbor | HIGH | ↑L5-L6 |
| Network namespaces | Virtual networks isolate traffic flows | HIGH | ↑L5-L6 |
| Volume persistence | Named volumes survive container restarts | CRITICAL | ↑L5-L6 |

**5-Order Effect Chain (L4):**
```
1st ORDER: podman-compose up → containers created
2nd ORDER: Networks established → inter-container routing active
3rd ORDER: Health checks pass → services ready for traffic
4th ORDER: Zenoh mesh forms → real-time telemetry flows
5th ORDER: System operational → ready for user workloads
```

#### L5 - NODE Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Host resources | 27GB RAM, 23 CPU cores allocated across containers | CRITICAL | ↑L6-L7 |
| Storage I/O | Container layers + volumes use host disk | HIGH | ↑L6 |
| Network stack | Host provides NAT, port forwarding, DNS resolution | HIGH | ↑L6-L7 |
| Security | Rootless podman provides user-namespace isolation | CRITICAL | ↑L6-L7 |

#### L6 - CLUSTER Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Multi-container coordination | 4 containers form minimal viable cluster | CRITICAL | ↑L7 |
| Quorum requirements | floor(4/2)+1 = 3 containers for decisions | HIGH | ↑L7 |
| State replication | DuckDB analytics replicated for redundancy | MEDIUM | ↑L7 |
| Failover capability | Container restart on host failure | HIGH | ↑L7 |

#### L7 - FEDERATION Impact
| Aspect | Impact | Severity | Ripple |
|--------|--------|----------|--------|
| Protocol compatibility | Standard compose format enables portability | MEDIUM | External |
| Cross-holon trust | Compose defines network security boundaries | HIGH | External |
| Version negotiation | Container image tags enable version coordination | MEDIUM | External |
| Global state sync | Federation peers can reconstruct from compose | MEDIUM | External |

---

## 2. ARTIFACT CATEGORY: Nix Container Definitions

### 2.1 Primary Artifact: `containers/indrajaal-timescaledb-demo.nix`

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | Binary packages | PostgreSQL 17 + TimescaleDB binaries deterministic | CRITICAL | 15-30 min rebuild |
| L1 | SQL functions | TimescaleDB hypertable functions available | HIGH | N/A (rebuild) |
| L2 | Ecto adapters | Database connection pooling configured | HIGH | Config restore |
| L3 | Ash schemas | All domain data stored and accessible | CRITICAL | Data restore |
| L4 | Container image | 875MB image provides isolated DB runtime | CRITICAL | Image rebuild |
| L5 | Host storage | PostgreSQL data directory on host volume | CRITICAL | Volume restore |
| L6 | Cluster data | Shared database for all app instances | CRITICAL | Full restore |
| L7 | Federation | Database provides authoritative business data | CRITICAL | Cross-site restore |

**Corruption Cascade Analysis:**
```
If indrajaal-timescaledb-demo.nix is corrupted:
  │
  ├─► L0: Cannot build PostgreSQL binary → no database executable
  │     │
  │     └─► L1: No SQL functions → all queries fail
  │           │
  │           └─► L2: Ecto connections fail → application errors
  │                 │
  │                 └─► L3: Ash domains cannot persist → data loss risk
  │                       │
  │                       └─► L4: Container won't start → compose fails
  │                             │
  │                             └─► L5: No database service on node
  │                                   │
  │                                   └─► L6: Cluster has no data store
  │                                         │
  │                                         └─► L7: Federation cannot sync

RECOVERY PATH:
  1. Restore .nix file from backup (checksums.sha256)
  2. Rebuild image: nix build .#indrajaal-timescaledb-demo
  3. Load image: podman load < result
  4. Restore data volume: cp backup/kms/* data/kms/
  5. Restart compose: sa-up

TIME TO RECOVERY: 15-30 minutes (rebuild) + data restore time
```

### 2.2 Primary Artifact: `containers/enhanced-app-nixos.nix`

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | BEAM runtime | Erlang/OTP 28 with 16 schedulers | CRITICAL | 20-45 min rebuild |
| L1 | NIF functions | Zenoh NIF, LineageAuth NIF compiled | CRITICAL | 20 min rebuild |
| L2 | Phoenix framework | HTTP/WS endpoints, LiveView | CRITICAL | Rebuild |
| L3 | Ash domains | All 10 domain modules | CRITICAL | Rebuild |
| L4 | App container | 9.39GB unified image | CRITICAL | 30 min rebuild |
| L5 | Node runtime | Elixir release with embedded Redis | CRITICAL | Rebuild |
| L6 | Cluster nodes | Multiple app instances possible | HIGH | Scale rebuild |
| L7 | API gateway | External clients access Phoenix | CRITICAL | Federation notify |

**5-Order Ripple from Corruption:**
```
1st ORDER (Immediate):
  - Nix build fails
  - Container image cannot be created

2nd ORDER (Minutes):
  - sa-up cannot start app container
  - Phoenix server offline
  - Health checks fail

3rd ORDER (Minutes-Hours):
  - All HTTP/WS connections fail
  - LiveView dashboards blank
  - API clients receive 503

4th ORDER (Hours):
  - Monitoring alerts fire
  - Agent swarm cannot execute
  - OODA loops stall

5th ORDER (Hours-Days):
  - Business operations impacted
  - Data not being processed
  - SLA violations
  - Federation peers lose trust
```

### 2.3 Primary Artifact: `devenv.nix`

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | Shell environment | PATH, env vars, tools configured | CRITICAL | 5 min restore |
| L1 | CLI commands | All sa-* commands defined | CRITICAL | 5 min restore |
| L2 | Build tools | mix, dotnet, podman accessible | CRITICAL | Immediate |
| L3 | Development flow | Entire dev workflow depends on this | CRITICAL | 5 min restore |
| L4 | Container builds | Nix build commands defined | HIGH | Rebuild |
| L5 | Host integration | Shell integrates with host OS | HIGH | Re-enter shell |
| L6 | Team workflow | Shared dev environment config | MEDIUM | Git restore |
| L7 | CI/CD | Pipeline uses same devenv | MEDIUM | Pipeline update |

**Critical Commands Defined in devenv.nix:**
```nix
sa-up       → dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh up
sa-down     → dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh down
sa-health   → dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh health
sa-status   → dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh status
compile     → PATIENT_MODE=enabled mix compile
test        → SKIP_ZENOH_NIF=0 mix test
quality     → mix format && mix credo --strict
```

**If devenv.nix is corrupted:**
```
IMPACT CHAIN:
  L0: Shell won't activate → "devenv shell" fails
    ↓
  L1: No CLI commands → cannot run sa-up, compile, test
    ↓
  L2: No build tools → cannot compile Elixir or F#
    ↓
  L3: Development stops → no changes can be made
    ↓
  L4: Containers orphaned → existing containers continue but no management
    ↓
  L5: Host fallback → must use raw podman/mix commands
    ↓
  L6: Team blocked → shared workflow broken
    ↓
  L7: Release blocked → CI/CD pipeline fails

RECOVERY:
  1. cp backups/mesh-state-*/nix/devenv.nix ./
  2. direnv allow (if using direnv)
  3. devenv shell (re-enter environment)

TIME: 5 minutes
```

---

## 3. ARTIFACT CATEGORY: F# Orchestration Scripts

### 3.1 Primary Artifact: `sa-up.fsx`

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | .NET runtime | F# interpreter executes script | HIGH | Restore script |
| L1 | Shell commands | podman-compose, health check calls | CRITICAL | Restore script |
| L2 | Service orchestration | Wave-based startup sequence | CRITICAL | Restore script |
| L3 | Holon boot | All 4 containers started in order | CRITICAL | Restore script |
| L4 | Container lifecycle | Creates, starts, monitors containers | CRITICAL | Restore script |
| L5 | Node activation | Brings up all services on node | CRITICAL | Restore script |
| L6 | Cluster formation | Establishes 4-container cluster | CRITICAL | Restore script |
| L7 | Mesh activation | System becomes operational | CRITICAL | Restore script |

**Wave-Based Startup Sequence:**
```
WAVE 1: INFRASTRUCTURE (L0-L2)
├─ Create networks (indrajaal-mesh, indrajaal-internal)
├─ Start indrajaal-db-prod
├─ Wait: pg_isready -h localhost -p 5433
└─ Governance.fsx: Log "Wave 1 Complete"

WAVE 2: OBSERVABILITY (L2-L3)
├─ Start indrajaal-obs-prod
├─ Wait: curl localhost:13133/health
├─ Verify: Prometheus scraping active
└─ Governance.fsx: Log "Wave 2 Complete"

WAVE 3: APPLICATION (L3-L4)
├─ Start indrajaal-ex-app-1
├─ Wait: curl localhost:4000/health
├─ Verify: Redis ping, Phoenix endpoints
└─ Governance.fsx: Log "Wave 3 Complete"

WAVE 4: VERIFICATION (L4-L6)
├─ Run FPPS 5-method health check
├─ Verify Zenoh mesh connectivity
├─ Publish mesh-ready event
└─ Governance.fsx: Log "MESH OPERATIONAL"
```

**If sa-up.fsx is corrupted:**
```
IMPACT CHAIN:
  L0: Script parse error → F# interpreter fails
    ↓
  L1: No container commands → services don't start
    ↓
  L2: No service orchestration → random startup order
    ↓
  L3: Holon state inconsistent → possible data corruption
    ↓
  L4: Container chaos → orphaned containers possible
    ↓
  L5: Node unstable → services in unknown state
    ↓
  L6: Cluster broken → quorum cannot form
    ↓
  L7: System offline → no external access

RECOVERY:
  1. cp backups/mesh-state-*/scripts/sa-up.fsx ./
  2. Verify: dotnet fsi --exec sa-up.fsx --help
  3. Execute: sa-up

TIME: 2 minutes (restore) + 5 minutes (startup)
```

### 3.2 Primary Artifact: `lib/cepaf/scripts/Governance.fsx`

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | Logging engine | Console output, file logging | HIGH | Restore |
| L1 | Utility functions | Exec, StreamExec, logging helpers | CRITICAL | Restore |
| L2 | Compilation metrics | SC-METRICS-003/004 compliance tracking | HIGH | Restore |
| L3 | Policy enforcement | Mandatory env vars, throttling | CRITICAL | Restore |
| L4 | Script foundation | All sa-*.fsx scripts depend on this | CRITICAL | Restore |
| L5 | Telemetry capture | Execution logs persisted | HIGH | Restore |
| L6 | Cross-script coordination | Shared policy engine | CRITICAL | Restore |
| L7 | Audit compliance | Execution audit trail | HIGH | Restore |

**Governance.fsx provides:**
```fsharp
// SC-METRICS-003: MANDATORY PARALLELIZATION
let mandatoryEnvVars = [
    ("ELIXIR_ERL_OPTIONS", "+S 16:16 +SDio 16")
    ("NO_TIMEOUT", "true")
    ("PATIENT_MODE", "enabled")
    ("INFINITE_PATIENCE", "true")
    ("MIX_OS_DEPS_COMPILE_PARTITION_COUNT", "8")
    ("SKIP_ZENOH_NIF", "0")
]

// Logging levels
Info, Success, Warn, Fail, Stream

// Execution wrappers
Exec command args        // Synchronous
StreamExec command args  // Async with real-time output
```

**Dependency Chain (scripts using Governance.fsx):**
```
Governance.fsx
├── sa-up.fsx         (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-down.fsx       (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-health.fsx     (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-test.fsx       (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-clean.fsx      (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-status.fsx     (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-verify.fsx     (#load "lib/cepaf/scripts/Governance.fsx")
├── sa-emergency.fsx  (#load "lib/cepaf/scripts/Governance.fsx")
└── sa-multiverse.fsx (#load "lib/cepaf/scripts/Governance.fsx")

CORRUPTION IMPACT:
  If Governance.fsx corrupted → ALL 9 scripts fail to execute
  Cascade failure across entire infrastructure management
```

---

## 4. ARTIFACT CATEGORY: KMS State Database

### 4.1 Primary Artifact: `data/kms/core.db` (SQLite)

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | SQLite engine | B-tree storage, WAL journaling | CRITICAL | Data restore |
| L1 | SQL queries | Read/write core system state | CRITICAL | Data restore |
| L2 | Holon modules | State persistence layer | CRITICAL | Data restore |
| L3 | Holon identity | Core holon configuration stored | CRITICAL | Data restore |
| L4 | Container state | Persisted across container restarts | CRITICAL | Data restore |
| L5 | Node state | Survives node reboots via volume | CRITICAL | Data restore |
| L6 | Cluster state | Authoritative source for cluster | CRITICAL | Data restore |
| L7 | Federation state | Holon identity for federation | CRITICAL | Data restore |

**Data Categories in core.db:**
```sql
-- System configuration
system_config (key, value, updated_at)

-- Holon identity
holon_identity (id, name, version, created_at)

-- Constitutional state
constitution (invariant_id, status, last_verified)

-- Guardian state
guardian_state (approval_queue, veto_log, active_proposals)

-- Agent registry
agents (id, type, status, last_heartbeat)
```

**Corruption Impact Analysis:**
```
If core.db is corrupted:

L0 IMPACT:
  - SQLite PRAGMA integrity_check fails
  - Page corruption detected
  - WAL cannot replay

L1-L2 IMPACT:
  - Queries return errors
  - State reads fail
  - Write operations crash

L3 IMPACT:
  - Holon identity unknown
  - Constitutional state lost
  - Guardian decisions lost
  - Agent registry corrupted

L4-L5 IMPACT:
  - Container restart loses all memory
  - Node has no persistent state

L6-L7 IMPACT:
  - Cluster has no authoritative source
  - Federation peers reject corrupt holon

RECOVERY:
  1. Stop all containers: sa-down
  2. Restore from backup: cp backups/mesh-state-*/kms/core.db data/kms/
  3. Verify integrity: sqlite3 data/kms/core.db "PRAGMA integrity_check"
  4. Restart: sa-up

TIME: 5-10 minutes
```

### 4.2 Primary Artifact: `data/kms/holons.db` (SQLite)

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | SQLite WAL | Concurrent reads, atomic writes | CRITICAL | Data restore |
| L1 | Version vectors | Conflict-free replication state | CRITICAL | Data restore |
| L2 | Holon state machines | FSM states persisted | CRITICAL | Data restore |
| L3 | All holon instances | Individual holon configurations | CRITICAL | Data restore |
| L4 | Container holon mapping | Which holon runs where | HIGH | Data restore |
| L5 | Node holon allocation | Holons distributed across nodes | HIGH | Data restore |
| L6 | Cluster holon registry | Global holon inventory | CRITICAL | Data restore |
| L7 | Federation holon sync | Cross-holon attestation | CRITICAL | Data restore |

### 4.3 Primary Artifact: `data/kms/analytics.duckdb` (DuckDB)

#### Full 7-Level Impact Matrix

| Level | Component | Impact | Severity | Recovery Time |
|-------|-----------|--------|----------|---------------|
| L0 | Columnar storage | Efficient analytics queries | HIGH | Data restore |
| L1 | SQL analytics | Complex aggregations, windows | HIGH | Data restore |
| L2 | Metrics modules | Historical KPI storage | HIGH | Data restore |
| L3 | Holon evolution history | Complete lineage record | CRITICAL | Data restore |
| L4 | Container metrics | Resource usage history | MEDIUM | Data restore |
| L5 | Node analytics | Host-level metrics history | MEDIUM | Data restore |
| L6 | Cluster trends | Multi-node performance analysis | MEDIUM | Data restore |
| L7 | Federation analytics | Cross-holon comparisons | LOW | Data restore |

---

## 5. ARTIFACT CATEGORY: Container Images

### 5.1 Primary Image: `localhost/indrajaal-app-unified:nixos-devenv`

#### Full 7-Level Impact Matrix

| Level | Component | Size | Impact | Severity |
|-------|-----------|------|--------|----------|
| L0 | BEAM VM | ~200MB | Erlang runtime, schedulers | CRITICAL |
| L1 | NIFs | ~50MB | Zenoh NIF, LineageAuth NIF | CRITICAL |
| L2 | Phoenix | ~500MB | Web framework, LiveView | CRITICAL |
| L3 | Ash domains | ~300MB | All 10 domain modules | CRITICAL |
| L4 | Base image | ~3GB | NixOS base + dependencies | CRITICAL |
| L5 | Release | ~2GB | Compiled BEAM release | CRITICAL |
| L6 | Redis | ~100MB | Embedded cache | HIGH |
| L7 | Total | 9.39GB | Complete app container | CRITICAL |

**Image Layer Analysis:**
```
┌────────────────────────────────────────────────────────────────────┐
│  indrajaal-app-unified:nixos-devenv (9.39 GB)                      │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Layer 7: Application Release (2 GB)                               │
│  ├── _build/prod/rel/indrajaal/                                    │
│  └── Compiled BEAM bytecode                                        │
│                                                                     │
│  Layer 6: Nix Store Dependencies (3 GB)                            │
│  ├── /nix/store/*-elixir-1.19/                                    │
│  ├── /nix/store/*-erlang-28/                                      │
│  └── /nix/store/*-nodejs/                                         │
│                                                                     │
│  Layer 5: Phoenix Framework (500 MB)                               │
│  ├── deps/phoenix/                                                 │
│  ├── deps/phoenix_live_view/                                       │
│  └── deps/phoenix_html/                                            │
│                                                                     │
│  Layer 4: Ash Framework (300 MB)                                   │
│  ├── deps/ash/                                                     │
│  ├── deps/ash_postgres/                                            │
│  └── lib/indrajaal/domains/                                        │
│                                                                     │
│  Layer 3: NIFs (50 MB)                                             │
│  ├── native/zenoh_nif/                                             │
│  └── native/lineage_auth_nif/                                      │
│                                                                     │
│  Layer 2: Redis Embedded (100 MB)                                  │
│  └── /nix/store/*-redis/                                          │
│                                                                     │
│  Layer 1: NixOS Base (3 GB)                                        │
│  └── /nix/store/base packages                                      │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

**If Image Corrupted:**
```
CORRUPTION DETECTION:
  - podman inspect fails
  - Container won't start
  - Layers fail checksum

RECOVERY OPTIONS:

Option A: Rebuild from Nix (30-45 min)
  nix build .#indrajaal-app-unified
  podman load < result

Option B: Restore from image backup
  ./scripts/infrastructure/mesh-image-recovery.sh backups/images-*.tar

Option C: Pull from registry (if available)
  podman pull registry.example.com/indrajaal-app-unified:nixos-devenv
```

---

## 6. COMPREHENSIVE RIPPLE IMPACT MATRIX

### 6.1 Cross-Artifact Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         ARTIFACT DEPENDENCY & RIPPLE GRAPH                           │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                           TIER 1: FOUNDATION                                  │   │
│  │                                                                               │   │
│  │  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │   │
│  │  │  flake.nix  │────▶│ devenv.nix  │────▶│ Governance  │                    │   │
│  │  │   (Nix)     │     │  (Shell)    │     │    .fsx     │                    │   │
│  │  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                    │   │
│  │         │                   │                   │                            │   │
│  └─────────┼───────────────────┼───────────────────┼────────────────────────────┘   │
│            │                   │                   │                                 │
│            ▼                   ▼                   ▼                                 │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                           TIER 2: CONTAINER BUILD                             │   │
│  │                                                                               │   │
│  │  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │   │
│  │  │timescaledb  │     │ obs-unified │     │ app-unified │                    │   │
│  │  │   .nix      │     │    .nix     │     │    .nix     │                    │   │
│  │  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                    │   │
│  │         │                   │                   │                            │   │
│  └─────────┼───────────────────┼───────────────────┼────────────────────────────┘   │
│            │                   │                   │                                 │
│            ▼                   ▼                   ▼                                 │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                           TIER 3: CONTAINER IMAGES                            │   │
│  │                                                                               │   │
│  │  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │   │
│  │  │indrajaal-db │     │indrajaal-obs│     │indrajaal-app│                    │   │
│  │  │   :nixos    │     │   :nixos    │     │   :nixos    │                    │   │
│  │  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                    │   │
│  │         │                   │                   │                            │   │
│  └─────────┼───────────────────┼───────────────────┼────────────────────────────┘   │
│            │                   │                   │                                 │
│            └───────────────────┼───────────────────┘                                 │
│                                ▼                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                           TIER 4: ORCHESTRATION                               │   │
│  │                                                                               │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │   │
│  │  │             podman-compose-prod-standalone.yml                       │    │   │
│  │  └────────────────────────────────┬────────────────────────────────────┘    │   │
│  │                                   │                                          │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │   │
│  │  │ sa-up   │  │sa-down  │  │sa-health│  │sa-status│  │sa-verify│          │   │
│  │  │  .fsx   │  │  .fsx   │  │  .fsx   │  │  .fsx   │  │  .fsx   │          │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘          │   │
│  │                                                                              │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                   │                                                  │
│                                   ▼                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                           TIER 5: RUNTIME STATE                               │   │
│  │                                                                               │   │
│  │  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │   │
│  │  │  core.db    │     │ holons.db   │     │analytics.db │                    │   │
│  │  │  (SQLite)   │     │  (SQLite)   │     │  (DuckDB)   │                    │   │
│  │  └─────────────┘     └─────────────┘     └─────────────┘                    │   │
│  │                                                                              │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Failure Mode Propagation Matrix

| Corrupted Artifact | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 | RPN |
|-------------------|----|----|----|----|----|----|----|----|-----|
| flake.nix | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | 432 |
| devenv.nix | ⚠️ | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | 288 |
| Governance.fsx | ✓ | ❌ | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | 336 |
| *.nix (container) | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | 384 |
| Container image | ✓ | ✓ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ⚠️ | 320 |
| compose.yml | ✓ | ✓ | ✓ | ⚠️ | ❌ | ❌ | ❌ | ❌ | 288 |
| sa-up.fsx | ✓ | ✓ | ✓ | ✓ | ❌ | ❌ | ❌ | ❌ | 256 |
| core.db | ✓ | ✓ | ✓ | ❌ | ⚠️ | ⚠️ | ❌ | ❌ | 280 |
| holons.db | ✓ | ✓ | ✓ | ❌ | ⚠️ | ⚠️ | ❌ | ❌ | 280 |
| analytics.duckdb | ✓ | ✓ | ✓ | ⚠️ | ✓ | ✓ | ⚠️ | ⚠️ | 144 |
| otel-config.yaml | ✓ | ✓ | ⚠️ | ⚠️ | ⚠️ | ✓ | ✓ | ✓ | 108 |

Legend: ❌ = Broken, ⚠️ = Degraded, ✓ = Functional

---

## 7. RECOVERY TIME OBJECTIVES (RTO) BY LEVEL

| Level | Component | RTO Target | Recovery Method |
|-------|-----------|------------|-----------------|
| L0 | Runtime | 5 min | Restore + restart |
| L1 | Functions | 5 min | Restore + restart |
| L2 | Components | 10 min | Restore + restart |
| L3 | Holons | 15 min | Restore + restart + verify |
| L4 | Containers | 15 min | Image load/rebuild |
| L5 | Node | 20 min | Full state restore |
| L6 | Cluster | 30 min | Multi-node restore |
| L7 | Federation | 60 min | Cross-site coordination |

---

## 8. STAMP CONSTRAINTS (Impact Analysis)

| ID | Constraint | Level | Severity |
|----|------------|-------|----------|
| SC-IMPACT-001 | Corruption at L0-L2 cascades to ALL higher levels | L0-L7 | CRITICAL |
| SC-IMPACT-002 | L3 (Holon) corruption affects L4-L7 but L0-L2 may continue | L3-L7 | HIGH |
| SC-IMPACT-003 | L4-L5 corruption is contained if images exist | L4-L5 | HIGH |
| SC-IMPACT-004 | L6-L7 corruption requires multi-site recovery | L6-L7 | MEDIUM |
| SC-IMPACT-005 | All P0 artifacts MUST have verified backups | ALL | CRITICAL |
| SC-IMPACT-006 | Recovery scripts MUST be tested monthly | ALL | HIGH |
| SC-IMPACT-007 | RTO < 15 min for single-node recovery | L0-L5 | HIGH |

---

## 9. AOR RULES (Impact Analysis)

| ID | Rule |
|----|------|
| AOR-IMPACT-001 | Before ANY change, identify affected levels |
| AOR-IMPACT-002 | Changes to L0-L2 artifacts require full system test |
| AOR-IMPACT-003 | L3 changes require holon integrity verification |
| AOR-IMPACT-004 | L4-L5 changes require container health validation |
| AOR-IMPACT-005 | L6-L7 changes require federation notification |
| AOR-IMPACT-006 | Document 5-order ripple effects for every change |
| AOR-IMPACT-007 | Maintain backup for each affected level |

---

## 10. QUICK REFERENCE: Recovery by Corruption Scenario

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         RECOVERY DECISION TREE                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  SYMPTOM: System won't start                                                    │
│  │                                                                              │
│  ├─► Check 1: devenv shell works?                                              │
│  │   └─► NO: Restore devenv.nix from backup                                    │
│  │                                                                              │
│  ├─► Check 2: sa-up runs without errors?                                       │
│  │   └─► NO: Restore sa-up.fsx and Governance.fsx                             │
│  │                                                                              │
│  ├─► Check 3: Container images exist?                                          │
│  │   └─► NO: Rebuild via nix build OR restore from image backup               │
│  │                                                                              │
│  ├─► Check 4: Compose file valid?                                              │
│  │   └─► NO: Restore podman-compose-prod-standalone.yml                        │
│  │                                                                              │
│  └─► Check 5: KMS state corrupt?                                               │
│      └─► YES: Restore data/kms/*.db from backup                               │
│                                                                                  │
│  NUCLEAR OPTION: Full restore from mesh-state-*.tar.gz                         │
│  ./scripts/infrastructure/mesh-recovery.sh backups/mesh-state-*.tar.gz         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

**Document Control**
| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-09 |
| Author | Claude Opus 4.5 |
| STAMP | SC-IMPACT-001 to SC-IMPACT-007 |
| AOR | AOR-IMPACT-001 to AOR-IMPACT-007 |
| Related | MESH_STATE_CAPTURE_AND_RECOVERY.md |
