# Architecture: Standalone App Container System
## Version: 1.0.0 | Date: 2025-12-24 | Status: PRODUCTION
## Compliance: SOPv5.11 + STAMP + TDG + IEC 61508 SIL-2

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Overview](#2-system-overview)
3. [Component Architecture](#3-component-architecture)
4. [DAG Execution Model](#4-dag-execution-model)
5. [Container Infrastructure](#5-container-infrastructure)
6. [Service Dependencies](#6-service-dependencies)
7. [Logging Architecture](#7-logging-architecture)
8. [Telemetry & Observability](#8-telemetry--observability)
9. [Network Architecture](#9-network-architecture)
10. [Security Architecture](#10-security-architecture)
11. [Data Flow Architecture](#11-data-flow-architecture)
12. [Failure Modes & Recovery](#12-failure-modes--recovery)
13. [Compliance Matrix](#13-compliance-matrix)

---

## 1. Executive Summary

### 1.1 Purpose

The Standalone App Container System provides a fully isolated, reproducible environment for running the Indrajaal Phoenix/Elixir application with comprehensive observability, health monitoring, and DAG-based verification.

### 1.2 Key Characteristics

| Attribute | Value |
|-----------|-------|
| Runtime | Elixir 1.19.4 / OTP 28 / NixOS |
| Container Engine | Podman 5.4.1+ (Rootless) |
| Database | PostgreSQL 17 + TimescaleDB |
| Observability | OpenTelemetry + SigNoz |
| Compilation Mode | Patient Mode (NO_TIMEOUT) |
| Verification | 7-Phase DAG (21 Tasks) |

### 1.3 Architecture Principles

1. **Container Isolation**: All execution within NixOS/Podman containers
2. **Patient Mode**: No timeouts during compilation/startup
3. **Zero-Defect**: Compilation must produce 0 warnings/errors
4. **Observable**: Full telemetry from boot to runtime
5. **Reproducible**: Deterministic builds via Nix

---

## 2. System Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           HOST SYSTEM (NixOS/Linux)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        PODMAN CONTAINER RUNTIME                          ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐   ││
│  │  │  indrajaal-app    │  │  indrajaal-db     │  │  indrajaal-obs    │   ││
│  │  │  ───────────────  │  │  ───────────────  │  │  ───────────────  │   ││
│  │  │  Phoenix/Elixir   │  │  PostgreSQL 17    │  │  SigNoz/OTEL     │   ││
│  │  │  Port: 4000       │  │  Port: 5433       │  │  Port: 4317      │   ││
│  │  │  Bandit HTTP      │  │  TimescaleDB      │  │  ClickHouse      │   ││
│  │  │  OODA Loop        │  │  Extensions       │  │  Grafana         │   ││
│  │  └─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘   ││
│  │            │                      │                      │              ││
│  │            └──────────────────────┴──────────────────────┘              ││
│  │                                   │                                      ││
│  │                    ┌──────────────┴──────────────┐                      ││
│  │                    │     CONTAINER NETWORKS       │                      ││
│  │                    │  app-standalone-net (bridge) │                      ││
│  │                    │  db-standalone-net (bridge)  │                      ││
│  │                    │  obs-standalone-net (bridge) │                      ││
│  │                    └─────────────────────────────┘                      ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         HOST VOLUME MOUNTS                               ││
│  │  /home/an/dev/ver/indrajaal-v5.2 -> /workspace:z (Application Code)     ││
│  │  tmpfs -> /var/log/claude (Ephemeral Logs)                              ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Container Specifications

| Container | Image | Purpose | Resources |
|-----------|-------|---------|-----------|
| indrajaal-app | `localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv` | Phoenix Application | 4-8GB RAM, 4-8 CPU |
| indrajaal-db | `localhost/indrajaal-db:pg17-timescale` | Database | 2-4GB RAM, 2-4 CPU |
| indrajaal-obs | `localhost/indrajaal-obs:signoz-latest` | Observability | 2-4GB RAM, 2-4 CPU |

---

## 3. Component Architecture

### 3.1 Application Layer Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INTELITOR APPLICATION LAYER                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                           PHOENIX FRAMEWORK                              ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │  Endpoint   │  │  Router     │  │  Controllers│  │  LiveView   │    ││
│  │  │  (Bandit)   │  │  (Plug)     │  │  (REST API) │  │  (WebSocket)│    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                           ASH FRAMEWORK                                  ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │  Domains    │  │  Resources  │  │  Actions    │  │  Policies   │    ││
│  │  │  (10 Total) │  │  (BaseRes)  │  │  (CRUD+)    │  │  (RBAC)     │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        CYBERNETIC SUBSYSTEM                              ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │  OODA Loop  │  │  Cortex     │  │  Sensors    │  │  Reflexes   │    ││
│  │  │  (Observe)  │  │  (Analyze)  │  │  (Monitor)  │  │  (React)    │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        INFRASTRUCTURE SERVICES                           ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │  Ecto/Repo  │  │  PubSub     │  │  Oban       │  │  Guardian   │    ││
│  │  │  (Database) │  │  (Realtime) │  │  (Jobs)     │  │  (Auth)     │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Ash Domain Structure

| Domain | Purpose | Resources |
|--------|---------|-----------|
| Indrajaal.Core | Core entities | Tenant, User, Organization |
| Indrajaal.Accounts | User management | Account, Session, Token |
| Indrajaal.Policy | Access control | Policy, Rule, Permission |
| Indrajaal.Sites | Location management | Site, Zone, Area |
| Indrajaal.AccessControlDomain | Physical access | AccessPoint, Credential |
| Indrajaal.Analytics | Reporting | Dashboard, Report, Metric |
| Indrajaal.GuardTour | Patrol management | Tour, Checkpoint, Scan |
| Indrajaal.CommunicationDomain | Notifications | Message, Channel, Alert |
| Indrajaal.AssetManagement | Asset tracking | Asset, Category, Location |
| Indrajaal.RiskManagement | Risk assessment | Risk, Control, Assessment |

### 3.3 Supervision Tree

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SUPERVISION TREE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Indrajaal.Application (Application)                                         │
│  │                                                                           │
│  ├── Indrajaal.Repo (Ecto.Repo)                                             │
│  │   └── Postgrex.Connection pool                                           │
│  │                                                                           │
│  ├── Indrajaal.PubSub (Phoenix.PubSub)                                      │
│  │   └── Phoenix.PubSub.PG2 adapter                                         │
│  │                                                                           │
│  ├── IndrajaalWeb.Endpoint (Phoenix.Endpoint)                               │
│  │   ├── Bandit HTTP Server                                                 │
│  │   └── Phoenix.LiveView.Socket                                            │
│  │                                                                           │
│  ├── Indrajaal.Cybernetic.OODA.Loop (GenServer)                             │
│  │   ├── Observe phase (telemetry collection)                               │
│  │   ├── Orient phase (context analysis)                                    │
│  │   ├── Decide phase (strategy selection)                                  │
│  │   └── Act phase (execution)                                              │
│  │                                                                           │
│  ├── Indrajaal.Cortex.Supervisor (Supervisor)                               │
│  │   ├── StressAnalyzer (GenServer)                                         │
│  │   ├── HealthSensor (GenServer)                                           │
│  │   └── ContainerHealthTelemetry (GenServer)                               │
│  │                                                                           │
│  ├── Oban (Oban.Supervisor)                                                 │
│  │   ├── Oban.Notifier                                                      │
│  │   ├── Oban.Peer                                                          │
│  │   └── Oban.Queue.Producer (per queue)                                    │
│  │                                                                           │
│  ├── Indrajaal.TelemetryMetricsWorker (GenServer)                           │
│  │   └── Periodic metrics collection                                        │
│  │                                                                           │
│  └── Indrajaal.Observability.Supervisor (Supervisor)                        │
│      ├── QuadplexLogger (structured logging)                                │
│      ├── TriplexLogger (legacy logging)                                     │
│      └── AlertIntegration (alerting)                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. DAG Execution Model

### 4.1 Phase Overview

The container lifecycle follows a 7-phase Directed Acyclic Graph (DAG) with 21 atomic tasks:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DAG EXECUTION PHASES                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PHASE 0: PREREQUISITES (3 tasks)                                           │
│  ├── P0.1_IMG: Verify container image exists                                │
│  ├── P0.2_NET: Create/verify networks                                       │
│  └── P0.3_DB:  Verify database container healthy                            │
│                                                                              │
│  PHASE 1: CREATION (1 task)                                                 │
│  └── P1.1_CNT: Create and start app container                               │
│                                                                              │
│  PHASE 2: SETUP (4 tasks)                                                   │
│  ├── P2.1_HEX: Install Hex package manager                                  │
│  ├── P2.2_REB: Install Rebar3 build tool                                    │
│  ├── P2.3_DEP: Fetch dependencies (mix deps.get)                            │
│  └── P2.4_CMP: Compile dependencies (mix deps.compile)                      │
│                                                                              │
│  PHASE 3: DATABASE (3 tasks)                                                │
│  ├── P3.1_CONN: Verify database connectivity                                │
│  ├── P3.2_CRE:  Create database (mix ecto.create)                           │
│  └── P3.3_MIG:  Run migrations (mix ecto.migrate)                           │
│                                                                              │
│  PHASE 4: COMPILATION (4 tasks)                                             │
│  ├── P4.1_MIX: Compile application (mix compile)                            │
│  ├── P4.2_AST: Build assets (optional)                                      │
│  ├── P4.3_DIG: Phoenix digest (optional)                                    │
│  └── P4.4_WAR: Verify zero warnings (SC-CMP-025)                            │
│                                                                              │
│  PHASE 5: STARTUP (1 task)                                                  │
│  └── P5.1_PHX: Start Phoenix server (mix phx.server)                        │
│                                                                              │
│  PHASE 6: HEALTH (3 tasks)                                                  │
│  ├── P6.1_TCP: TCP port probe (4000, 4001, 9568)                            │
│  ├── P6.2_HTTP: HTTP health endpoint (/health)                              │
│  └── P6.3_LOG:  Log pattern verification                                    │
│                                                                              │
│  PHASE 7: VERIFICATION (3 tasks)                                            │
│  ├── P7.1_API: API endpoint testing                                         │
│  ├── P7.2_OBS: Telemetry verification                                       │
│  └── P7.3_E2E: End-to-end validation                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 DAG Dependency Graph

```
                         [START]
                            │
                ┌───────────┼───────────┐
                ▼           ▼           ▼
           [P0.1_IMG] [P0.2_NET]   [P0.3_DB]
                │           │           │
                └───────────┴─────┬─────┘
                                  ▼
                             [P1.1_CNT]
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
               [P2.1_HEX]────►[P2.2_REB]   [P3.1_CONN]
                                  │             │
                                  ▼             │
                             [P2.3_DEP]         │
                                  │             │
                                  ▼             │
                             [P2.4_CMP]         │
                                  │             │
                    ┌─────────────┴─────────────┘
                    ▼
               [P3.2_CRE]
                    │
                    ▼
               [P3.3_MIG]
                    │
                    ▼
               [P4.1_MIX]
                    │
          ┌─────────┼─────────┬─────────┐
          ▼         ▼         ▼         ▼
     [P4.2_AST][P4.3_DIG][P4.4_WAR] [P5.1_PHX]
          │         │         │         │
          └─────────┴─────────┴─────────┘
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
               [P6.1_TCP][P6.2_HTTP][P6.3_LOG]
                    │         │         │
                    └─────────┴─────────┘
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
               [P7.1_API][P7.2_OBS][P7.3_E2E]
                    │         │         │
                    └─────────┴─────────┘
                              │
                              ▼
                         [SIL_READY]
```

### 4.3 Task State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TASK STATE MACHINE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                      ┌──────────┐                                           │
│                      │  ABSENT  │ (Initial state)                           │
│                      └────┬─────┘                                           │
│                           │ create_task()                                   │
│                           ▼                                                 │
│                      ┌──────────┐                                           │
│               ┌──────│ PENDING  │──────┐                                    │
│               │      └────┬─────┘      │                                    │
│               │           │ start()    │ skip()                             │
│               │           ▼            ▼                                    │
│               │      ┌──────────┐ ┌──────────┐                              │
│               │      │ RUNNING  │ │ SKIPPED  │                              │
│               │      └────┬─────┘ └──────────┘                              │
│               │           │                                                 │
│               │     ┌─────┴─────┐                                          │
│               │     │           │                                          │
│               │ complete()  fail()                                         │
│               │     │           │                                          │
│               │     ▼           ▼                                          │
│               │ ┌──────────┐ ┌──────────┐                                  │
│               │ │ COMPLETE │ │  FAILED  │                                  │
│               │ └──────────┘ └────┬─────┘                                  │
│               │                   │ retry()                                │
│               │                   │                                        │
│               └───────────────────┘                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Container Infrastructure

### 5.1 Image Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         IMAGE HIERARCHY                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 0: NixOS Base                                                     ││
│  │  nixos/nix:25.05                                                         ││
│  │  └── Nix package manager, systemd, base utilities                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 1: Elixir Runtime                                                 ││
│  │  localhost/indrajaal-sopv51-base:nixos-25.05                            ││
│  │  └── Erlang/OTP 28, Elixir 1.19.4, PostgreSQL client                    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 2: Development Environment                                        ││
│  │  localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv               ││
│  │  └── Hex, Rebar3, Node.js, build tools, devenv profile                  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Container Configuration

```yaml
# Container Specification
container:
  name: indrajaal-app-debug
  image: localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv

  resources:
    limits:
      memory: 8G
      cpus: 8
    reservations:
      memory: 4G
      cpus: 4

  ports:
    - "4000:4000"   # HTTP API (Bandit)
    - "4001:4001"   # LiveDashboard
    - "9568:9568"   # Prometheus metrics

  volumes:
    - /home/an/dev/ver/indrajaal-v5.2:/workspace:z
    - tmpfs:/var/log/claude

  environment:
    # Runtime
    MIX_ENV: test
    ELIXIR_ERL_OPTIONS: "+S 10:10 +fnu +W w"

    # Patient Mode
    NO_TIMEOUT: "true"
    PATIENT_MODE: "enabled"
    INFINITE_PATIENCE: "true"

    # Debug
    MIX_DEBUG: "1"
    LOGGER_LEVEL: debug
    ECTO_DEBUG: "true"

    # Phoenix
    PHX_SERVER: "true"
    PHX_HOST: 0.0.0.0
    PHX_PORT: 4000

    # Database
    DATABASE_URL: ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone

  healthcheck:
    test: ["CMD-SHELL", "curl -sf http://localhost:4000/health || exit 1"]
    interval: 10s
    timeout: 10s
    retries: 60
    start_period: 600s
```

---

## 6. Service Dependencies

### 6.1 Dependency Matrix

| Service | Depends On | Required | Timeout |
|---------|------------|----------|---------|
| Phoenix Endpoint | Ecto.Repo, PubSub | Yes | 30s |
| Ecto.Repo | PostgreSQL | Yes | 60s |
| Oban | Ecto.Repo | Yes | 30s |
| OODA Loop | Telemetry, Cortex | No | 10s |
| Cortex Sensors | Telemetry | No | 10s |
| PubSub | None | Yes | 5s |
| Guardian | Secret Key | Yes | 5s |

### 6.2 Startup Order

```
1. [BOOT]        Erlang VM starts
2. [KERNEL]      :kernel, :stdlib load
3. [ELIXIR]      :elixir, :logger, :mix load
4. [CONFIG]      runtime.exs evaluated
5. [REPO]        Indrajaal.Repo connects to PostgreSQL
6. [PUBSUB]      Phoenix.PubSub starts
7. [OBAN]        Oban supervisor starts
8. [TELEMETRY]   OpenTelemetry initializes
9. [ENDPOINT]    Phoenix.Endpoint starts (Bandit HTTP)
10. [OODA]       Cybernetic OODA loop activates
11. [CORTEX]     Cortex sensors begin monitoring
12. [READY]      Application ready for traffic
```

---

## 7. Logging Architecture

### 7.1 Log Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LOGGING ARCHITECTURE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 1: Elixir Logger                                                  ││
│  │  ────────────────────────────────────────────────────────────────────── ││
│  │  Config: config :logger, level: :debug                                   ││
│  │  Format: "$time $metadata[$level] $message\n"                            ││
│  │  Metadata: :all (pid, module, function, line, domain)                   ││
│  └────────────────────────────────────┬────────────────────────────────────┘│
│                                       │                                      │
│                          ┌────────────┴────────────┐                        │
│                          ▼                         ▼                        │
│  ┌───────────────────────────────┐  ┌───────────────────────────────┐      │
│  │  Console Backend              │  │  LoggerJSON Backend            │      │
│  │  ─────────────────────────── │  │  ─────────────────────────────│      │
│  │  Output: stdout/stderr        │  │  Output: Structured JSON       │      │
│  │  Format: Human-readable       │  │  Format: Datadog-compatible    │      │
│  │  Purpose: Developer feedback  │  │  Purpose: SigNoz ingestion     │      │
│  └───────────────────────────────┘  └───────────────────────────────┘      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 2: Quadplex Logger (Domain-Aware)                                 ││
│  │  ────────────────────────────────────────────────────────────────────── ││
│  │  Channels:                                                               ││
│  │    - security: Authentication, authorization, access control            ││
│  │    - business: Domain operations, transactions, workflows               ││
│  │    - performance: Latency, throughput, resource usage                   ││
│  │    - system: Infrastructure, lifecycle, health                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Layer 3: OTEL Trace Correlation                                         ││
│  │  ────────────────────────────────────────────────────────────────────── ││
│  │  trace_id: Distributed trace identifier                                  ││
│  │  span_id: Current operation span                                         ││
│  │  parent_span_id: Parent operation                                        ││
│  │  service.name: indrajaal-app-debug                                       ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Log Format Specification

```json
{
  "timestamp": "2025-12-24T08:00:00.000000Z",
  "level": "info",
  "message": "Request completed",
  "logger": {
    "thread_name": "#PID<0.911.0>",
    "method_name": "Elixir.IndrajaalWeb.HealthController.comprehensive/2",
    "file_name": "lib/indrajaal_web/controllers/health_controller.ex",
    "line": 45
  },
  "domain": ["elixir", "phoenix", "request"],
  "syslog": {
    "hostname": "app-debug",
    "severity": "info",
    "timestamp": "2025-12-24T08:00:00.000Z"
  },
  "trace": {
    "trace_id": "abc123def456",
    "span_id": "span789",
    "parent_span_id": "parent456"
  },
  "context": {
    "request_id": "GIQX5EG_8_5zHbgAAAKB",
    "user_id": null,
    "tenant_id": null
  }
}
```

### 7.3 Debug Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `LOGGER_LEVEL` | debug | Enable all log levels |
| `MIX_DEBUG` | 1 | Mix task debugging |
| `ECTO_DEBUG` | true | SQL query logging |
| `OTEL_LOG_LEVEL` | debug | OpenTelemetry debug |
| `CEPAF_DEBUG` | 1 | CEPAF framework debug |
| `CEPAF_VERBOSE` | 1 | Verbose CEPAF output |
| `DEBUG_ERRORS` | true | Detailed Phoenix errors |

---

## 8. Telemetry & Observability

### 8.1 Telemetry Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OBSERVABILITY STACK                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        APPLICATION LAYER                                 ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │ :telemetry  │  │ OpenTelemetry│  │ Prometheus  │  │ LoggerJSON  │    ││
│  │  │  (Events)   │  │  (Traces)   │  │  (Metrics)  │  │  (Logs)     │    ││
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    ││
│  │         │                │                │                │            ││
│  │         └────────────────┴────────────────┴────────────────┘            ││
│  │                                   │                                      ││
│  │                                   ▼                                      ││
│  │                        ┌─────────────────────┐                          ││
│  │                        │  OTLP Exporter      │                          ││
│  │                        │  (gRPC :4317)       │                          ││
│  │                        └──────────┬──────────┘                          ││
│  └───────────────────────────────────┼─────────────────────────────────────┘│
│                                      │                                       │
│                                      ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        SIGNOZ COLLECTOR                                  ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │  Receivers  │─▶│ Processors  │─▶│  Exporters  │─▶│ ClickHouse  │    ││
│  │  │  (OTLP)     │  │  (Batch)    │  │  (Native)   │  │  (Storage)  │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                      │                                       │
│                                      ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        VISUALIZATION                                     ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │  SigNoz UI  │  │  Grafana    │  │  Alerts     │  │  Dashboards │    ││
│  │  │  (:3301)    │  │  (:3000)    │  │  (Rules)    │  │  (Custom)   │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 Metrics Collected

| Metric | Type | Labels | Purpose |
|--------|------|--------|---------|
| `phoenix.endpoint.stop.duration` | Histogram | path, method, status | Request latency |
| `ecto.repo.query.total_time` | Histogram | source, query | Database latency |
| `vm.memory.total` | Gauge | - | Memory usage |
| `vm.total_run_queue_lengths.total` | Gauge | - | Scheduler load |
| `oban.job.stop.duration` | Histogram | queue, worker | Job execution time |
| `ooda.cycle.count` | Counter | - | OODA loop iterations |
| `ooda.cycle.latency` | Histogram | - | OODA cycle timing |

### 8.3 Health Probes

| Probe | Endpoint | Purpose | Checks |
|-------|----------|---------|--------|
| Liveness | `/healthz` | Is the process alive? | BEAM VM, memory, scheduler |
| Readiness | `/ready` | Can it serve traffic? | Database, Redis, PubSub, Telemetry |
| Startup | `/startup` | Has it finished starting? | Application, Endpoint, Supervision tree |
| Comprehensive | `/health` | Full status report | All of the above + metrics |

---

## 9. Network Architecture

### 9.1 Network Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NETWORK TOPOLOGY                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        HOST NETWORK                                      ││
│  │                                                                          ││
│  │  External Access:                                                        ││
│  │    http://localhost:4000  → indrajaal-app:4000 (API)                    ││
│  │    http://localhost:4001  → indrajaal-app:4001 (Dashboard)              ││
│  │    http://localhost:9568  → indrajaal-app:9568 (Metrics)                ││
│  │    http://localhost:5433  → indrajaal-db:5433 (PostgreSQL)              ││
│  │    http://localhost:4317  → indrajaal-obs:4317 (OTLP)                   ││
│  │    http://localhost:3301  → indrajaal-obs:3301 (SigNoz UI)              ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                      │                                       │
│                                      ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                    PODMAN BRIDGE NETWORKS                                ││
│  │                                                                          ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │  app-standalone-net (172.20.0.0/16)                              │    ││
│  │  │    └── indrajaal-app-debug (172.20.0.2)                         │    ││
│  │  └─────────────────────────────────────────────────────────────────┘    ││
│  │                              │                                           ││
│  │                              │ (connected)                               ││
│  │                              ▼                                           ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │  db-standalone-net (172.21.0.0/16)                               │    ││
│  │  │    ├── indrajaal-db-standalone (172.21.0.2)                           │    ││
│  │  │    └── indrajaal-app-debug (172.21.0.3) [joined]                │    ││
│  │  └─────────────────────────────────────────────────────────────────┘    ││
│  │                              │                                           ││
│  │                              │ (connected)                               ││
│  │                              ▼                                           ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │  obs-standalone-net (172.22.0.0/16)                              │    ││
│  │  │    ├── indrajaal-obs (172.22.0.2)                               │    ││
│  │  │    └── indrajaal-app-debug (172.22.0.3) [joined]                │    ││
│  │  └─────────────────────────────────────────────────────────────────┘    ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 DNS Resolution

| Hostname | Resolves To | Network |
|----------|-------------|---------|
| `indrajaal-db-standalone` | 172.21.0.2 | db-standalone-net |
| `indrajaal-app-debug` | 172.20.0.2 | app-standalone-net |
| `indrajaal-obs` | 172.22.0.2 | obs-standalone-net |
| `db` | 172.21.0.2 | (alias via external_links) |

---

## 10. Security Architecture

### 10.1 Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SECURITY ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Layer 1: Container Isolation                                                │
│  ├── Rootless Podman (no root privileges)                                   │
│  ├── User namespace isolation                                                │
│  ├── Network namespace isolation                                             │
│  └── seccomp/AppArmor profiles                                              │
│                                                                              │
│  Layer 2: Network Security                                                   │
│  ├── Bridge network isolation                                                │
│  ├── No inter-container traffic by default                                  │
│  ├── Explicit network joining required                                       │
│  └── Host port binding restrictions                                          │
│                                                                              │
│  Layer 3: Application Security                                               │
│  ├── Guardian JWT authentication                                             │
│  ├── Ash policy-based authorization                                          │
│  ├── CSRF protection (Phoenix)                                               │
│  └── Content Security Policy headers                                         │
│                                                                              │
│  Layer 4: Data Security                                                      │
│  ├── Ecto encrypted fields                                                   │
│  ├── Database connection encryption (SSL)                                    │
│  ├── Secrets via environment variables                                       │
│  └── No secrets in container images                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Secret Management

| Secret | Source | Usage |
|--------|--------|-------|
| `SECRET_KEY_BASE` | Environment | Phoenix session signing |
| `GUARDIAN_SECRET_KEY` | Environment | JWT signing |
| `DATABASE_URL` | Environment | Database credentials |
| `POSTGRES_PASSWORD` | Environment | Database password |

---

## 11. Data Flow Architecture

### 11.1 Request Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         REQUEST FLOW                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Client Request                                                              │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────────┐                                                            │
│  │   Bandit    │  HTTP/1.1 or HTTP/2                                        │
│  │   Server    │  Port 4000                                                 │
│  └──────┬──────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌─────────────┐                                                            │
│  │  Endpoint   │  Telemetry.start(:phoenix, :endpoint, :start)             │
│  │   Plugs     │  - Plug.RequestId                                          │
│  │             │  - Plug.Telemetry                                          │
│  │             │  - Plug.Static                                             │
│  │             │  - Plug.Session                                            │
│  └──────┬──────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌─────────────┐                                                            │
│  │   Router    │  Route matching                                            │
│  │             │  - Pipeline selection                                      │
│  │             │  - Scope resolution                                        │
│  └──────┬──────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌─────────────┐                                                            │
│  │ Controller  │  Business logic                                            │
│  │   Action    │  - Ash domain calls                                        │
│  │             │  - Ecto queries                                            │
│  └──────┬──────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌─────────────┐                                                            │
│  │    View     │  Response rendering                                        │
│  │   Render    │  - JSON encoding                                           │
│  │             │  - Template rendering                                      │
│  └──────┬──────┘                                                            │
│         │                                                                    │
│         ▼                                                                    │
│  ┌─────────────┐                                                            │
│  │  Response   │  Telemetry.stop(:phoenix, :endpoint, :stop)               │
│  │   Sent      │  - Status code                                             │
│  │             │  - Headers                                                 │
│  │             │  - Body                                                    │
│  └─────────────┘                                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Failure Modes & Recovery

### 12.1 Failure Matrix

| Component | Failure Mode | Detection | Recovery | RTO |
|-----------|-------------|-----------|----------|-----|
| Phoenix Endpoint | Port not binding | TCP probe | Restart container | 30s |
| Ecto.Repo | DB connection lost | Query timeout | Reconnect pool | 10s |
| OODA Loop | GenServer crash | Supervisor | Automatic restart | 1s |
| Oban | Queue processing halt | Job backlog | Restart worker | 5s |
| PubSub | Message delivery fail | Subscription check | Rejoin | 2s |

### 12.2 Circuit Breaker Patterns

```elixir
# Circuit breaker states
@states [:closed, :open, :half_open]

# Thresholds
@failure_threshold 5        # Open after 5 failures
@reset_timeout 30_000       # Try again after 30s
@success_threshold 3        # Close after 3 successes
```

---

## 13. Compliance Matrix

### 13.1 STAMP Safety Constraints

| Constraint | Description | Verification |
|------------|-------------|--------------|
| SC-CNT-009 | NixOS/Podman execution | Container runtime check |
| SC-CNT-010 | localhost/ registry only | Image source validation |
| SC-VAL-001 | Patient Mode enabled | Env var verification |
| SC-CMP-025 | Zero compilation warnings | Compile log analysis |
| SC-CMP-026 | All files compiled | File count verification |
| SC-OBS-069 | Dual logging active | Log output validation |
| SC-PRF-050 | Response time <50ms | Latency monitoring |

### 13.2 Compliance Verification

```bash
# Verify STAMP compliance
mix stamp.verify --all

# Expected output:
# SC-CNT-009: PASS (NixOS container detected)
# SC-CNT-010: PASS (localhost/ registry)
# SC-VAL-001: PASS (Patient Mode enabled)
# SC-CMP-025: PASS (0 warnings)
# SC-OBS-069: PASS (Dual logging active)
```

---

## Appendix A: Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-24 | Claude Code | Initial architecture document |

## Appendix B: References

1. SOPv5.11 Cybernetic Execution Framework
2. STAMP Safety Constraint Documentation
3. TDG Test-Driven Generation Methodology
4. Phoenix Framework Documentation
5. Ash Framework Documentation
6. OpenTelemetry Specification
