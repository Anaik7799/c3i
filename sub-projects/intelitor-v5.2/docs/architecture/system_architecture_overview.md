# System Architecture Overview

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-BOOT-001, SC-HA-001, SC-VER-074

## Overview

Indrajaal is a SIL-6 Biomorphic Fractal Mesh system built on a quad-stack architecture
(Phoenix LiveView + F# Bolero + Avalonia + Prajna TUI). It runs as 4 containers
orchestrated by Podman with Zenoh as the unified IPC mesh.

## Container Topology (prod-standalone)

```
+------------------------------------------------------------------+
|                    PODMAN HOST (NixOS, Rootless)                  |
|                    Network: indrajaal-mesh                        |
|                                                                   |
|  +--------------------+     +-----------------------------+      |
|  | zenoh-router       |     | indrajaal-obs-prod          |      |
|  | Port: 7447         |     | Ports: 4317, 9090, 3000,   |      |
|  | Role: Mesh coord.  |<--->|        3100                 |      |
|  | Stateless          |     | OTEL + Grafana + Loki       |      |
|  +--------+-----------+     +-------------+---------------+      |
|           |                               |                       |
|           |         Zenoh wire protocol   |                       |
|           |                               |                       |
|  +--------+-----------+     +-------------+---------------+      |
|  | indrajaal-db-prod  |     | indrajaal-ex-app-1          |      |
|  | Port: 5433         |     | Port: 4000                  |      |
|  | PostgreSQL (biz)   |<--->| Elixir/Phoenix + F# Mesh    |      |
|  | SQLite (holon)     |     | Zenoh NIF + OTEL            |      |
|  +--------------------+     +-----------------------------+      |
+------------------------------------------------------------------+
```

## Boot Order (Wave Model)

```
Wave 1: zenoh-router         (controller, port 7447)
  |
Wave 2: indrajaal-db-prod    (primary DB, port 5433)
  |
Wave 3: indrajaal-obs-prod   (observability stack)
  |
Wave 4: indrajaal-ex-app-1   (seed application node)
  |
Post:   Health verification + 2oo3 voting + Digital Twin sync
```

## Quad-Stack UI Architecture

```
+------------------------------------------------------------------+
|                         USER INTERFACES                           |
|                                                                   |
|  +------------------+  +------------------+  +-----------------+ |
|  | Phoenix LiveView |  | F# Bolero WebUI  |  | Avalonia GUI    | |
|  | Elixir / HEEx    |  | F# / WASM        |  | F# / .NET 10   | |
|  | Web Portal &     |  | High-Assurance   |  | Low-Latency     | |
|  | Admin Dashboard  |  | C3I Console      |  | Desktop         | |
|  | Port: 4000       |  | (Planned)        |  | (Planned)       | |
|  +------------------+  +------------------+  +-----------------+ |
|                                                                   |
|  +------------------------------------------------------------+ |
|  | Prajna TUI (Elixir / ANSI) — Emergency Terminal Interface   | |
|  +------------------------------------------------------------+ |
+------------------------------------------------------------------+
```

## VSM (Viable System Model) Layers

| System | Function | Implementation |
|--------|----------|---------------|
| S1 | Operations | App containers, device handlers |
| S2 | Coordination | Gossip protocol, PubSub, Zenoh sync |
| S3 | Control | Guardian, CPU Governor, feedback loops |
| S3* | Audit | Sporadic audit GenServer, compliance |
| S4 | Intelligence | Cortex AI, SMRITI knowledge, analytics |
| S5 | Policy | Constitutional kernel, Founder's Directive |

## Fractal Control Layers (L0-L7)

| Layer | Name | Scope |
|-------|------|-------|
| L0 | Constitution | Immutable axioms (Psi-0 to Psi-5) |
| L1 | Physical | Hardware, containers, network |
| L2 | Data | SQLite, DuckDB, PostgreSQL |
| L3 | Communication | Zenoh mesh, PubSub, OTEL |
| L4 | Safety | SIL-6 functions, Guardian, DMS |
| L5 | Intelligence | AI/ML, knowledge engine, analytics |
| L6 | Evolution | Morphogenic cycles, fitness evaluation |
| L7 | Federation | Cross-holon governance, attestation |

## Data Sovereignty

```
Authoritative State:
  SQLite  → Holon state, planning, knowledge (SC-HOLON-009)
  DuckDB  → Analytics, audit trail (append-only)

Business Data:
  PostgreSQL → Customer data, CRM, transactions
  (PostgreSQL ∩ HolonState = empty set)

State Recovery:
  Any holon can be fully reconstructed from SQLite + DuckDB files alone.
```

## Communication Fabric

```
+-------+     +-------+     +-------+
| App-1 |<--->| Zenoh |<--->| App-N |     Zenoh: Real-time telemetry,
+-------+     | Router|     +-------+     control plane, state sync
              +---+---+
                  |
              +---+---+
              | OTEL  |                   OTEL: Traces, metrics,
              | Stack |                   structured logging
              +-------+
```

## Key Metrics

| Metric | Target | Constraint |
|--------|--------|-----------|
| Boot time | < 60s | SC-OPT-001 |
| OODA cycle | < 100ms | SC-VER-041 |
| Emergency stop | < 5s | SC-VER-045 |
| DMS heartbeat | 100ms | SC-DMS-001 |
| Digital Twin sync | < 30s | SC-FUNC-008 |
| CPU hard limit | 85% | SC-CPU-GOV-001 |
| SQLite read latency | < 1ms | SC-XHOLON-020 |
| DuckDB query latency | < 10ms | SC-XHOLON-021 |

## Related Documents

- CLAUDE.md (complete system specification)
- docs/architecture/SIL6_7LAYER_FRACTAL_ARCHITECTURE.md
- docs/architecture/FRACTAL_CLUSTER_SIL4_MESH_SPECIFICATION.md
- docs/architecture/INTEGRATED_SYSTEM_ARCHITECTURE.md
