# CEPAF Architecture Documentation

**Version**: 1.0.0
**Last Updated**: 2024-12-24
**Status**: Active
**STAMP Compliance**: IEC 61508 SIL-2, ISO 27001

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Core Modules](#3-core-modules)
4. [Container Infrastructure](#4-container-infrastructure)
5. [STAMP Safety Constraints](#5-stamp-safety-constraints)
6. [AOR (Agent Operating Rules)](#6-aor-agent-operating-rules)
7. [Integration Points](#7-integration-points)
8. [Appendix](#appendix)

---

## 1. Executive Summary

### 1.1 Purpose and Goals

CEPAF (Container Execution Protocol Architecture Framework) is an F# framework designed for
safety-critical container orchestration within the Indrajaal project. It provides:

- **Deterministic Container Boot Sequencing**: Topologically sorted service chains ensure
  correct startup order with dependency resolution.
- **STAMP Safety Methodology**: All operations comply with Systems-Theoretic Accident Model
  and Processes (STAMP) safety constraints.
- **FPPS 5-Method Consensus**: Health verification uses Five-Point Proactive Sensing for
  100% consensus-based validation.
- **Dual Logging (Quadplex)**: Terminal + SigNoz + File + StateTracker channels per SC-OBS-069.
- **4 OTEL Modules**: Traces, Metrics, Logs, and Profiles per SC-OBS-071.

### 1.2 Key Design Principles

```
+-----------------------------------------------------------------------+
|                    CEPAF DESIGN PRINCIPLES                            |
+-----------------------------------------------------------------------+
| 1. SAFETY-FIRST: All operations enforce STAMP constraints             |
| 2. CONSENSUS-BASED: 5-method FPPS required for health verification    |
| 3. DETERMINISTIC: DAG-based topological ordering for boot sequences   |
| 4. OBSERVABLE: Quadplex logging to 4 channels simultaneously          |
| 5. ISOLATED: NixOS containers, rootless Podman, localhost/ registry   |
| 6. RECOVERABLE: Emergency halt <1s, rollback capability               |
+-----------------------------------------------------------------------+
```

### 1.3 STAMP Safety Methodology

STAMP (Systems-Theoretic Accident Model and Processes) provides the safety framework:

| Component       | STAMP Role                          | CEPAF Implementation                |
|-----------------|-------------------------------------|-------------------------------------|
| Control Actions | Container start/stop/health         | ServiceDAG topological order        |
| Feedback        | Health probes, log analysis         | FPPS 5-method consensus             |
| Constraints     | SC-* safety constraints             | AOREngine enforcement               |
| Hazards         | Deadlocks, cascading failures       | Cycle detection, layer isolation    |

---

## 2. System Architecture

### 2.1 Layer Architecture (L0-L3)

```
+============================================================================+
|                         CEPAF LAYER ARCHITECTURE                           |
+============================================================================+

LAYER 3: VISUALIZATION (Frontend + Dashboards)
+---------------------------+---------------------------+
|    obs-frontend           |     obs-grafana           |
|    (SigNoz UI:8080)       |     (Grafana:3000)        |
|    Deps: query-service    |     Deps: clickhouse,otel |
+---------------------------+---------------------------+
                              |
                              v
LAYER 2: QUERY & APPLICATION
+---------------------------+---------------------------+
|    obs-query-service      |     indrajaal-app         |
|    (API:8085)             |     (Phoenix:4000)        |
|    Deps: clickhouse,otel  |     Deps: indrajaal-db    |
+---------------------------+---------------------------+
                              |
                              v
LAYER 1: INGESTION & SIDECARS
+---------------------------+---------------------------+------------------+
|    obs-otel-collector     |   localhost:6379 (integrated Redis)         | indrajaal-nginx  |
|    (gRPC:4317,HTTP:4318)  |   (Redis:6379)            | (HTTP:80)        |
|    Deps: clickhouse       |   Deps: app               | Deps: app        |
+---------------------------+---------------------------+------------------+
                              |
                              v
LAYER 0: FOUNDATION (No Dependencies)
+---------------------------+---------------------------+
|    obs-clickhouse         |     indrajaal-db          |
|    (HTTP:8123,TCP:9000)   |     (PostgreSQL:5433)     |
|    Deps: none             |     Deps: none            |
+---------------------------+---------------------------+
```

### 2.2 Module Dependency Graph

```
+============================================================================+
|                      CEPAF MODULE DEPENDENCY GRAPH                         |
+============================================================================+

                    +------------------+
                    |    Program.fs    |  Entry point, CLI
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
     +--------v--------+           +--------v--------+
     |  Orchestrator   |           |   OodaController|  OODA loop
     +--------+--------+           +--------+--------+
              |                             |
   +----------+----------+                  |
   |          |          |                  |
   v          v          v                  v
+------+  +------+  +------+         +-----------+
|  VTO |  |Phases|  |Steril|         | AOREngine |
+------+  +------+  +------+         +-----------+
   |         |         |                   |
   |    +----+----+    |                   |
   |    |    |    |    |                   |
   v    v    v    v    v                   v
+----------+----------+----------+    +----------+
|DbVerifier|AppVerifier|ObsVerifier|  |TDGHarness|
+----------+----------+----------+    +----------+
              |
              v
    +------------------+
    |   ServiceDAG     |  DAG construction, topo sort
    +--------+---------+
             |
   +---------+---------+
   |                   |
   v                   v
+----------+     +----------+
| DevChain |     | ObsChain |  Service chain definitions
+----------+     +----------+
             |
             v
    +------------------+
    |   PathResolver   |  Centralized path management
    +------------------+
             |
             v
    +------------------+
    |  QuadplexLogger  |  4-channel logging
    +------------------+
```

### 2.3 Container Topology

#### Dev/Demo Environment (3-Container)

```
+============================================================================+
|               DEV/DEMO CONTAINER TOPOLOGY (3-Container)                    |
+============================================================================+

                        indrajaal-net (172.30.0.0/24)
        +---------------------------------------------------------+
        |                                                         |
        |   +----------------+                                    |
        |   | indrajaal-db   | 172.30.0.10                        |
        |   | PostgreSQL 17  |                                    |
        |   | TimescaleDB    |                                    |
        |   | Port: 5433     |                                    |
        |   +-------+--------+                                    |
        |           |                                             |
        |           | TCP:5433 (Mandatory)                        |
        |           v                                             |
        |   +----------------+                                    |
        |   | indrajaal-app  | 172.30.0.20                        |
        |   | Phoenix/Elixir |                                    |
        |   | Port: 4000     |                                    |
        |   +-------+--------+                                    |
        |           |                                             |
        |           | HTTP:4000 (Optional - graceful degradation) |
        |           v                                             |
        |   +----------------+                                    |
        |   | indrajaal-obs  | 172.30.0.30                        |
        |   | SigNoz/Grafana |                                    |
        |   | OTLP/Prometheus|                                    |
        |   | Ports: 3000,   |                                    |
        |   |   4317,8123    |                                    |
        |   +----------------+                                    |
        |                                                         |
        +---------------------------------------------------------+

Boot Order: db (L0) -> app (L1) -> obs (L2)
Estimated Boot Time: 30s (10s per layer)
```

#### Observability Stack (5-Container)

```
+============================================================================+
|              OBSERVABILITY CONTAINER TOPOLOGY (5-Container)                |
+============================================================================+

                      indrajaal-obs-net (172.31.0.0/24)
        +---------------------------------------------------------+
        |                                                         |
        |   Layer 0: Storage                                      |
        |   +------------------+                                  |
        |   | obs-clickhouse   | 172.31.0.10                      |
        |   | HTTP:8123        |                                  |
        |   | TCP:9000         |                                  |
        |   | Native:9009      |                                  |
        |   +--------+---------+                                  |
        |            |                                            |
        |            v                                            |
        |   Layer 1: Ingestion                                    |
        |   +------------------+                                  |
        |   | obs-otel-collector| 172.31.0.20                     |
        |   | gRPC:4317        |                                  |
        |   | HTTP:4318        |                                  |
        |   | Metrics:8888     |                                  |
        |   +--------+---------+                                  |
        |            |                                            |
        |            v                                            |
        |   Layer 2: Query                                        |
        |   +------------------+                                  |
        |   | obs-query-service| 172.31.0.30                      |
        |   | API:8085         |                                  |
        |   +--------+---------+                                  |
        |            |                                            |
        |     +------+------+                                     |
        |     |             |                                     |
        |     v             v                                     |
        |   Layer 3: Visualization                                |
        |   +----------+ +----------+                             |
        |   |obs-frontend|obs-grafana|                            |
        |   | UI:8080  | | UI:3000  |                             |
        |   | 172.31.0.40| 172.31.0.50|                           |
        |   +----------+ +----------+                             |
        |                                                         |
        +---------------------------------------------------------+

Boot Order: clickhouse -> otel-collector -> query-service -> frontend,grafana
Estimated Boot Time: 120s (30s per layer)
```

---

## 3. Core Modules

### 3.1 PathResolver

**File**: `src/Cepaf/Modules/PathResolver.fs`
**STAMP Compliance**: SC-CEP-001 (Locality), SC-CEP-002 (Decoupling)

PathResolver provides centralized path management for all CEPAF operations.

```
+============================================================================+
|                         PATHRESOLVER ARCHITECTURE                          |
+============================================================================+

                        +-------------------+
                        |   PathResolver    |
                        +-------------------+
                                 |
        +------------+-----------+-----------+------------+
        |            |           |           |            |
        v            v           v           v            v
+-------------+ +---------+ +---------+ +---------+ +-----------+
|resolveCompose|  resolve |validatePath|getArtifact|getContainer|
|    File     |          |   Exists   |   Dir    |   Config   |
+-------------+ +---------+ +---------+ +---------+ +-----------+
```

**Key Types**:

| Type              | Description                                        |
|-------------------|----------------------------------------------------|
| ServiceContainer  | Enum: Db, App, Obs                                 |
| DeploymentEnv     | Enum: Dev, Test, Demo, Prod                        |
| ArtifactType      | Enum: Logs, Data, Config, State, Temp              |
| ServiceChainPaths | Record: compose files, container names, ports      |
| ContainerConfig   | Record: name, image, paths, ports, health check    |

**Key Functions**:

| Function                    | Purpose                                     |
|-----------------------------|---------------------------------------------|
| `resolve`                   | Convert relative to absolute path           |
| `resolveComposeFile`        | Get compose file absolute path              |
| `validateComposeFile`       | Verify compose file exists                  |
| `getServiceChainPaths`      | Get 3-container topology paths              |
| `resolveContainerConfig`    | Get container config with resolved paths    |
| `validateStampScope`        | Verify path is within CEPAF scope           |

### 3.2 ServiceDAG

**File**: `src/Cepaf/Modules/ServiceDAG.fs`
**STAMP Compliance**: SC-CEP-003 (Consensus), SC-CEP-004 (30s boot), SC-AGT-018 (No deadlocks)

ServiceDAG manages the container dependency graph for boot sequencing.

```
+============================================================================+
|                          SERVICE DAG STRUCTURE                             |
+============================================================================+

                    +------------------+
                    |    ServiceDAG    |
                    +------------------+
                    | Nodes: Map<id,DAGNode>
                    | Edges: (from,to,type) list
                    | Layers: Map<int,ids>
                    | BootSequence: string list
                    | IsValid: bool
                    +------------------+

    DAGNode:
    +------------------+
    | Id: string       |
    | Container: ContainerDef
    | Dependencies: string list
    | Dependents: string list
    | Layer: int
    | HealthState: enum
    | BootOrder: int option
    +------------------+

    ContainerDef:
    +------------------+
    | Name: string     |
    | Image: string    |
    | DependsOn: string list
    | DependencyTypes: Map<string,DependencyType>
    | Layer: int option
    +------------------+
```

**Algorithms**:

| Algorithm          | Purpose                               | Complexity |
|--------------------|---------------------------------------|------------|
| `detectCycles`     | Kahn's algorithm for cycle detection  | O(V+E)     |
| `topologicalSort`  | DFS-based topological ordering        | O(V+E)     |
| `assignLayers`     | Compute layer from dependency depth   | O(V+E)     |

**Dependency Types**:

| Type      | Behavior                                               |
|-----------|--------------------------------------------------------|
| Mandatory | Dependent cannot start until dependency is Healthy     |
| Optional  | Dependent can start in degraded mode if dep unhealthy  |

### 3.3 DevChain

**File**: `src/Cepaf/ServiceChains/DevChain.fs`
**STAMP Compliance**: SC-CEP-003, SC-CEP-004, SC-CNT-009/010/012

DevChain defines the dev/demo environment service chain with 6 containers across 3 layers.

**Container Definitions**:

| Layer | Container        | Image                                        | Dependencies     | Ports        |
|-------|------------------|----------------------------------------------|------------------|--------------|
| L0    | indrajaal-db     | localhost/indrajaal-timescaledb-demo:nixos   | none             | 5433         |
| L1    | indrajaal-app    | localhost/indrajaal-sopv51-elixir-app:nixos  | db (Mandatory)   | 4000         |
| L1    | localhost:6379 (integrated Redis)  | localhost/localhost:6379 (integrated Redis)-demo:nixos         | app (Mandatory)  | 6379         |
| L1    | indrajaal-nginx  | localhost/indrajaal-nginx-demo:nixos         | app (Mandatory)  | 80           |
| L2    | indrajaal-obs    | localhost/indrajaal-prometheus-demo:nixos    | app (Optional)   | 9090         |
| L2    | indrajaal-grafana| localhost/indrajaal-grafana-demo:nixos       | obs (Mandatory)  | 3000         |

### 3.4 ObsChain

**File**: `src/Cepaf/ServiceChains/ObsChain.fs`
**STAMP Compliance**: SC-OBS-069, SC-OBS-071, SC-CNT-009/010/012

ObsChain defines the observability stack with 5 containers across 4 layers.

**Container Definitions**:

| Layer | Container          | Image                                      | Dependencies              | Ports              |
|-------|--------------------|--------------------------------------------|---------------------------|--------------------|
| L0    | obs-clickhouse     | localhost/indrajaal-clickhouse:nixos       | none                      | 8123,9000,9009     |
| L1    | obs-otel-collector | localhost/indrajaal-otel-collector:nixos   | clickhouse (Mandatory)    | 4317,4318,8888     |
| L2    | obs-query-service  | localhost/indrajaal-signoz-query:nixos     | clickhouse (M), otel (O)  | 8085               |
| L3    | obs-frontend       | localhost/indrajaal-signoz-frontend:nixos  | query-service (Mandatory) | 8080               |
| L3    | obs-grafana        | localhost/indrajaal-grafana:nixos          | clickhouse (M), otel (O)  | 3000               |

### 3.5 Verifiers (FPPS Pattern)

**Files**: `src/Cepaf/Phases/DbVerifier.fs`, `AppVerifier.fs`, `ObsVerifier.fs`
**STAMP Compliance**: SC-VAL-003 (100% FPPS Consensus)

The verifiers implement the FPPS (Five-Point Proactive Sensing) 5-method consensus pattern:

```
+============================================================================+
|                    FPPS 5-METHOD CONSENSUS PATTERN                         |
+============================================================================+

                    +------------------+
                    |  FPPS Consensus  |
                    +------------------+
                             |
        +--------+-----------+-----------+---------+
        |        |           |           |         |
        v        v           v           v         v
    +------+ +-------+ +--------+ +--------+ +-----+
    |Method| |Method | |Method  | |Method  | |Method|
    |  1   | |   2   | |   3    | |   4    | |  5  |
    +------+ +-------+ +--------+ +--------+ +-----+
    Podman   Health    Port      Process   Log
    Status   Endpoint  Probe     Check     Analysis

    Result: CONSENSUS if ALL 5 methods PASS
            FAILURE   if ANY method FAILS (SC-VAL-003)
```

**Method Details**:

| # | Method          | Implementation                              | Pass Criteria              |
|---|-----------------|---------------------------------------------|----------------------------|
| 1 | PodmanStatus    | `podman ps --filter name=X --format State`  | State = "running"          |
| 2 | HealthEndpoint  | HTTP GET `/health` or `/api/health`         | HTTP 200 OK                |
| 3 | PortProbe       | TCP connection to service port              | Connection succeeds        |
| 4 | ProcessCheck    | `podman exec X ps aux`                      | Required processes found   |
| 5 | LogAnalysis     | `podman logs --tail 100 X`                  | "ready"/"started" pattern  |

---

## 4. Container Infrastructure

### 4.1 Three-Container Architecture

The minimal production topology for dev/demo environments:

```
+============================================================================+
|                    3-CONTAINER ARCHITECTURE (db, app, obs)                 |
+============================================================================+

Service: indrajaal-db
+-----------------------------------------------------------------------+
| Container: indrajaal-db                                               |
| Image:     localhost/indrajaal-timescaledb-demo:nixos-devenv          |
| Port:      5433 (PostgreSQL)                                          |
| Health:    pg_isready -U indrajaal -d indrajaal_dev -p 5433 -h localhost |
| Volumes:   pgdata:/var/lib/postgresql/data                            |
| STAMP:     SC-CNT-009,010,012 | SC-DB-001,019,031                     |
+-----------------------------------------------------------------------+

Service: indrajaal-app
+-----------------------------------------------------------------------+
| Container: indrajaal-app                                              |
| Image:     localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv   |
| Port:      4000 (Phoenix HTTP)                                        |
| Health:    curl -sf http://localhost:4000/health                      |
| Depends:   indrajaal-db (Mandatory)                                   |
| STAMP:     SC-CNT-009,010,012 | SC-PRF-050 (<50ms)                    |
+-----------------------------------------------------------------------+

Service: indrajaal-obs
+-----------------------------------------------------------------------+
| Container: indrajaal-obs                                              |
| Image:     localhost/indrajaal-prometheus-demo:nixos-devenv           |
| Ports:     3000 (Grafana), 4317 (OTLP gRPC), 8123 (ClickHouse)        |
| Health:    curl -sf http://localhost:3000/api/health                  |
| Depends:   indrajaal-app (Optional)                                   |
| STAMP:     SC-OBS-069,071 | SC-CNT-009,010,012                        |
+-----------------------------------------------------------------------+
```

### 4.2 Full Six-Container Architecture

Extended topology with sidecars:

```
+============================================================================+
|                 6-CONTAINER ARCHITECTURE (Full Dev Chain)                  |
+============================================================================+

Layer 0: Foundation
+-----------------+
| indrajaal-db    |  PostgreSQL 17 + TimescaleDB
+-----------------+

Layer 1: Application + Sidecars
+-----------------+-----------------+-----------------+
| indrajaal-app   | localhost:6379 (integrated Redis) | indrajaal-nginx |
| Phoenix/Elixir  | Caching Layer   | Reverse Proxy   |
+-----------------+-----------------+-----------------+

Layer 2: Observability
+-----------------+-----------------+
| indrajaal-obs   | indrajaal-grafana|
| SigNoz/Prom     | Dashboards       |
+-----------------+-----------------+
```

### 4.3 Port Mappings

**Dev Chain Ports**:

| Service          | Internal Port | External Port | Protocol | Purpose            |
|------------------|---------------|---------------|----------|--------------------|
| indrajaal-db     | 5432          | 5433          | TCP      | PostgreSQL         |
| indrajaal-app    | 4000          | 4000          | HTTP     | Phoenix            |
| localhost:6379 (integrated Redis)  | 6379          | 6379          | TCP      | Redis              |
| indrajaal-nginx  | 80            | 80            | HTTP     | Reverse Proxy      |
| indrajaal-obs    | 9090          | 9090          | HTTP     | Prometheus         |
| indrajaal-grafana| 3000          | 3000          | HTTP     | Grafana            |

**Observability Chain Ports**:

| Service            | Internal Ports    | External Ports    | Purpose                   |
|--------------------|-------------------|-------------------|---------------------------|
| obs-clickhouse     | 8123,9000,9009    | 8123,9000,9009    | ClickHouse HTTP/TCP/Native|
| obs-otel-collector | 4317,4318,8888    | 4317,4318,8888    | OTLP gRPC/HTTP, Metrics   |
| obs-query-service  | 8085              | 8085              | SigNoz Query API          |
| obs-frontend       | 8080              | 8080              | SigNoz Web UI             |
| obs-grafana        | 3000              | 3000              | Grafana Dashboards        |

### 4.4 Health Check Configurations

**Database Health Check**:
```yaml
healthcheck:
  test: ["CMD", "pg_isready", "-U", "indrajaal", "-d", "indrajaal_dev", "-p", "5433", "-h", "localhost"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

**Application Health Check**:
```yaml
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:4000/health"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 120s
```

**Observability Health Check**:
```yaml
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:3000/api/health"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s
```

---

## 5. STAMP Safety Constraints

### 5.1 Full Constraint List

```
+============================================================================+
|                        STAMP SAFETY CONSTRAINTS                            |
+============================================================================+

CATEGORY: VAL (Validation)
+-----------+------------------------------------------------------------+
| SC-VAL-001| Patient Mode only - NO_TIMEOUT=true required               |
| SC-VAL-002| Analyze COMPLETE logs - no truncation                      |
| SC-VAL-003| 100% FPPS Consensus required - 5/5 methods must pass       |
| SC-VAL-004| Halt on disagreement - any FPPS method failure stops boot  |
+-----------+------------------------------------------------------------+

CATEGORY: CNT (Container)
+-----------+------------------------------------------------------------+
| SC-CNT-009| NixOS/Podman only - no Docker/Alpine                       |
| SC-CNT-010| localhost/ registry only - no external registries          |
| SC-CNT-012| Rootless execution - no root containers                    |
+-----------+------------------------------------------------------------+

CATEGORY: AGT (Agents)
+-----------+------------------------------------------------------------+
| SC-AGT-017| Efficiency >90% - agent task completion rate               |
| SC-AGT-018| No deadlocks - cycle detection in DAG mandatory            |
| SC-AGT-019| Executive Authority - supreme control                      |
+-----------+------------------------------------------------------------+

CATEGORY: CMP (Compilation)
+-----------+------------------------------------------------------------+
| SC-CMP-025| 0 Warnings - compilation must be warning-free              |
| SC-CMP-026| All 773 files - complete codebase compilation              |
| SC-CMP-028| No interruption - patient mode prevents timeout            |
+-----------+------------------------------------------------------------+

CATEGORY: SEC (Security)
+-----------+------------------------------------------------------------+
| SC-SEC-044| Sobelow check - security analysis required                 |
| SC-SEC-047| Encryption - TLS/SSL for sensitive data                    |
+-----------+------------------------------------------------------------+

CATEGORY: PRF (Performance)
+-----------+------------------------------------------------------------+
| SC-PRF-050| Response <50ms - API latency threshold                     |
| SC-PRF-055| No blocking ops - async operations required                |
+-----------+------------------------------------------------------------+

CATEGORY: EMR (Emergency)
+-----------+------------------------------------------------------------+
| SC-EMR-057| Stop <5s - container stop timeout                          |
| SC-EMR-060| Rollback capability - state recovery required              |
+-----------+------------------------------------------------------------+

CATEGORY: OBS (Observability)
+-----------+------------------------------------------------------------+
| SC-OBS-069| Dual Log (Term+SigNoz) - two logging channels minimum      |
| SC-OBS-071| 4 OTEL modules - Traces, Metrics, Logs, Profiles           |
+-----------+------------------------------------------------------------+

CATEGORY: POD (Podman)
+-----------+------------------------------------------------------------+
| SC-POD-001| Pod naming convention - indrajaal-* prefix                 |
| SC-POD-002| Resource limits required - memory/CPU limits               |
| SC-POD-003| Health check required - all containers                     |
| SC-POD-004| Restart policy required - on-failure or always             |
| SC-POD-005| Image source validation - localhost/ prefix                |
| SC-POD-006| Network isolation - dedicated networks                     |
| SC-POD-007| Volume mount validation - /home/ scope only                |
| SC-POD-008| Security context required - read-only rootfs               |
+-----------+------------------------------------------------------------+

CATEGORY: CEP (CEPAF)
+-----------+------------------------------------------------------------+
| SC-CEP-001| Locality - PathResolver scope validation                   |
| SC-CEP-002| Decoupling - no hardcoded paths                            |
| SC-CEP-003| Consensus - 5-method FPPS for health                       |
| SC-CEP-004| 30s boot threshold - per-layer timing                      |
+-----------+------------------------------------------------------------+
```

### 5.2 Container Constraints (SC-CNT-*)

**SC-CNT-009: NixOS Containers Only**

All container images must be NixOS-based:
- Image name must contain "nixos" substring
- No Docker/Alpine base images allowed
- Reproducible builds via Nix flakes

**SC-CNT-010: localhost/ Registry Only**

All images must use localhost/ registry prefix:
```
VALID:   localhost/indrajaal-app:nixos-25.05
INVALID: docker.io/library/postgres:17
INVALID: ghcr.io/some/image:latest
```

**SC-CNT-012: Rootless Execution**

Podman must run in rootless mode:
- No `--privileged` flag
- No root user in containers
- User namespace mapping enabled

### 5.3 Observability Constraints (SC-OBS-*)

**SC-OBS-069: Dual Logging**

Minimum two logging channels required:
```
Channel 1: Terminal (stdout/stderr)
Channel 2: SigNoz (OTLP export)
Optional:  File (local persistence)
Optional:  StateTracker (in-memory)
```

**SC-OBS-071: 4 OTEL Modules**

Required OpenTelemetry modules:

| Module   | Purpose                    | Endpoint         |
|----------|----------------------------|------------------|
| Traces   | Distributed tracing        | OTLP gRPC :4317  |
| Metrics  | Time-series metrics        | OTLP HTTP :4318  |
| Logs     | Structured logging         | OTLP gRPC :4317  |
| Profiles | Runtime profiling          | pprof/OTLP       |

---

## 6. AOR (Agent Operating Rules)

### 6.1 Overview

AOR (Agent Operating Rules) are runtime-enforced behavioral constraints for all CEPAF agents.

**File**: `src/Cepaf/Modules/AOREngine.fs`

### 6.2 Rule Categories

```
+============================================================================+
|                      AOR RULE CATEGORIES                                   |
+============================================================================+

+-------------+------------------------------------------+------------------+
| Category    | Description                              | Severity         |
+-------------+------------------------------------------+------------------+
| Executive   | AOR-EXE-* : Executive authority rules    | Critical         |
| Safety      | AOR-SAF-* : Safety halt/response rules   | Critical         |
| Container   | AOR-CNT-* : Container operation rules    | Critical/High    |
| Quality     | AOR-QUA-* : Code quality rules           | High             |
| Agent       | AOR-AGT-* : Agent behavior rules         | High             |
| Database    | AOR-DB-*  : Database operation rules     | High             |
| Documentation| AOR-DOC-* : Documentation rules         | Medium           |
| Batch       | AOR-BATCH-*: Batch operation rules       | High             |
| Gemini      | AOR-GEM-* : Gemini agent rules           | High             |
+-------------+------------------------------------------+------------------+
```

### 6.3 Critical Rules

**AOR-SAF-001: Emergency Halt (<1s)**

```
Rule:     System must halt within 1 second on STAMP violation
Severity: CRITICAL
Action:   Immediate halt, flush logs, record metrics
```

Implementation:
```fsharp
let enforceHalt (logger: UnifiedLogger) (violation: AORViolation) : HaltResult =
    let sw = Stopwatch.StartNew()
    logger.Flush()
    sw.Stop()
    let isCompliant = sw.ElapsedMilliseconds < 1000L
    { Success = isCompliant; DurationMs = sw.ElapsedMilliseconds; Message = ... }
```

**AOR-CNT-001: Podman Only**

```
Rule:     Container operations must use Podman exclusively
Severity: CRITICAL
Violation: Docker runtime detected -> immediate failure
```

**AOR-QUA-001: Zero Warnings**

```
Rule:     Compilation must produce zero warnings
Severity: HIGH
Validation: error_count = 0 AND warning_count = 0
```

### 6.4 Compliance Checking

```
+============================================================================+
|                    AOR COMPLIANCE CHECK FLOW                               |
+============================================================================+

                    +------------------+
                    | Create Context   |
                    | (operation type) |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |  Add Context Data|
                    | (runtime, agent, |
                    |  target, etc.)   |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    | Check All Rules  |
                    | (iterate allRules)|
                    +--------+---------+
                             |
              +--------------+--------------+
              |                             |
              v                             v
     +--------+--------+           +--------+--------+
     |   Rule Passes   |           |   Rule Fails    |
     |  (add to passed)|           | (create violation)|
     +-----------------+           +--------+--------+
                                            |
                                            v
                                   +--------+--------+
                                   | Critical?       |
                                   +--------+--------+
                                            |
                              +-------------+-------------+
                              |                           |
                              v                           v
                     +--------+--------+         +--------+--------+
                     | CriticalViolation|        | NonCompliant    |
                     | -> enforceHalt   |        | (log warning)   |
                     +-----------------+         +-----------------+
```

### 6.5 Compliance Report Structure

```fsharp
type ComplianceReport = {
    Status: ComplianceStatus        // Compliant | NonCompliant | CriticalViolation
    RulesChecked: string list       // Rule IDs that were evaluated
    RulesPassed: string list        // Rule IDs that passed
    RulesSkipped: string list       // Rule IDs not applicable
    Violations: AORViolation list   // Detailed violation records
    GeneratedAt: DateTimeOffset     // Report timestamp
    CheckDurationMs: int64          // Time to run all checks
    Context: RuleContext            // Context that was evaluated
}
```

---

## 7. Integration Points

### 7.1 Elixir/Phoenix Integration

**Files**: `lib/indrajaal/cepaf/client.ex`, `lib/indrajaal/cepaf/bridge.ex`, `lib/indrajaal/cepaf/protocol.ex`

The CEPAF framework integrates with Elixir via JSON-RPC over stdio:

```
+============================================================================+
|                    ELIXIR/CEPAF INTEGRATION                                |
+============================================================================+

Elixir Application                    CEPAF Framework (F#)
+-----------------+                   +-------------------+
|                 |                   |                   |
| Cepaf.Client    | <-- JSON-RPC -->  | Cepaf.Bridge      |
| (high-level API)|     (stdio)       | (server)          |
|                 |                   |                   |
+-----------------+                   +-------------------+
        |                                     |
        v                                     v
+-----------------+                   +-------------------+
| Cepaf.Bridge    |                   | Commands/         |
| (port process)  |                   | Container.fs      |
+-----------------+                   | Health.fs         |
        |                             | Safety.fs         |
        v                             | System.fs         |
+-----------------+                   +-------------------+
| Cepaf.Protocol  |                          |
| (JSON-RPC codec)|                          v
+-----------------+                   +-------------------+
                                      | Cepaf.Podman      |
                                      | (API client)      |
                                      +-------------------+
```

**Client API Examples**:

```elixir
# Container operations
{:ok, id} = Cepaf.Client.create_container(%{
  name: "indrajaal-db",
  image: "localhost/indrajaal-timescaledb-demo:nixos-devenv",
  ports: [%{host: 5433, container: 5433}]
})
:ok = Cepaf.Client.start_container(id)

# Health checks
{:ok, :healthy} = Cepaf.Client.health_check(id)

# Safety validation (SC-CNT-010)
{:ok, :valid} = Cepaf.Client.validate_image("localhost/my-image:tag")
{:ok, {:invalid, violations}} = Cepaf.Client.validate_image("docker.io/image:tag")

# Emergency operations (SC-EMR-057)
:ok = Cepaf.Client.emergency_stop(id, 5)  # 5 second timeout
```

### 7.2 OpenTelemetry Configuration

**OTEL Collector Config** (`otel-collector-config.yaml`):

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  prometheus:
    config:
      scrape_configs:
        - job_name: 'indrajaal-app'
          static_configs:
            - targets: ['indrajaal-app:4000']
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
      disk:
  filelog:
    include: [/var/log/*.log]

processors:
  batch:
    timeout: 5s
    send_batch_size: 512
  memory_limiter:
    limit_mib: 512
  resourcedetection:
    detectors: [env, system]

exporters:
  clickhouse:
    endpoint: tcp://obs-clickhouse:9000
    database: signoz_traces
  prometheus:
    endpoint: 0.0.0.0:8889
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, memory_limiter]
      exporters: [clickhouse, logging]
    metrics:
      receivers: [otlp, prometheus, hostmetrics]
      processors: [batch]
      exporters: [clickhouse, prometheus]
    logs:
      receivers: [otlp, filelog]
      processors: [batch]
      exporters: [clickhouse, logging]
```

**Elixir OTLP Configuration**:

```elixir
# config/config.exs
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: {:otlp, protocol: :grpc, endpoint: "http://localhost:4317"},
  resource: [
    service: [name: "indrajaal", namespace: "indrajaal-ns"]
  ]

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"

config :opentelemetry, :processors,
  batch: [
    scheduled_delay_ms: 5000,
    max_queue_size: 512
  ]
```

### 7.3 SigNoz/Grafana Dashboards

**SigNoz Endpoints**:

| Endpoint                  | Purpose                    |
|---------------------------|----------------------------|
| http://localhost:8080     | SigNoz Web UI              |
| http://localhost:8085/api/v1/traces | Traces API      |
| http://localhost:8085/api/v1/metrics| Metrics API     |
| http://localhost:8085/api/v1/logs   | Logs API        |

**Grafana Datasources**:

| Datasource   | Type       | URL                                |
|--------------|------------|------------------------------------|
| ClickHouse   | clickhouse | http://obs-clickhouse:8123         |
| Prometheus   | prometheus | http://obs-otel-collector:8889     |

**Required Dashboards**:

1. **System Overview**: CPU, Memory, Disk, Network
2. **Container Metrics**: Per-container resource usage
3. **Trace Analysis**: Request latency, error rates

---

## Appendix

### A. File Locations

| Component           | Path                                           |
|---------------------|------------------------------------------------|
| PathResolver        | `lib/cepaf/src/Cepaf/Modules/PathResolver.fs`  |
| ServiceDAG          | `lib/cepaf/src/Cepaf/Modules/ServiceDAG.fs`    |
| DevChain            | `lib/cepaf/src/Cepaf/ServiceChains/DevChain.fs`|
| ObsChain            | `lib/cepaf/src/Cepaf/ServiceChains/ObsChain.fs`|
| DbVerifier          | `lib/cepaf/src/Cepaf/Phases/DbVerifier.fs`     |
| ObsVerifier         | `lib/cepaf/src/Cepaf/Phases/ObsVerifier.fs`    |
| AOREngine           | `lib/cepaf/src/Cepaf/Modules/AOREngine.fs`     |
| Constraints         | `lib/cepaf/src/Cepaf.Podman/Safety/Constraints.fs` |
| Elixir Client       | `lib/indrajaal/cepaf/client.ex`                |
| Elixir Bridge       | `lib/indrajaal/cepaf/bridge.ex`                |

### B. Command Reference

```bash
# Build CEPAF
cd lib/cepaf && dotnet build

# Run tests
dotnet test

# Run standalone DB verification
dotnet run --project src/Cepaf -- -d -e DEV -y

# Run standalone OBS verification
dotnet run --project src/Cepaf -- -o -e DEV -y

# Run full verification
dotnet run --project src/Cepaf -- -e DEV -y --verify
```

### C. Environment Variables

| Variable           | Default | Description                           |
|--------------------|---------|---------------------------------------|
| CEPAF_LOG_LEVEL    | INFO    | Logging level (DEBUG, INFO, WARN)     |
| CEPAF_PATIENT_MODE | false   | Enable patient mode (no timeouts)     |
| CEPAF_BOOT_THRESHOLD_MS | 30000 | Maximum boot time per layer (ms)  |
| PODMAN_SOCKET      | auto    | Podman socket path (rootless default) |

### D. Glossary

| Term    | Definition                                                  |
|---------|-------------------------------------------------------------|
| CEPAF   | Container Execution Protocol Architecture Framework         |
| DAG     | Directed Acyclic Graph                                      |
| FPPS    | Five-Point Proactive Sensing (5-method consensus)           |
| OTEL    | OpenTelemetry                                               |
| STAMP   | Systems-Theoretic Accident Model and Processes              |
| VTO     | Verification, Testing, Observability (lifecycle protocol)   |
| AOR     | Agent Operating Rules                                       |
| SC-*    | Safety Constraint identifier                                |

---

*Document generated for CEPAF v1.0.0 - Indrajaal Safety-Critical System*
