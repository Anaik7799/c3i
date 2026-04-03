# Production-Equivalent Runtime Testing Plan
**Version**: 1.0.0 | **Date**: 2025-12-29 | **Status**: EXECUTION READY
**Framework**: SOPv5.11 + STAMP + OODA + Biomorphic Swarm + Full Mesh
**Scope**: 100% Coverage - Dataflow, Control Flow, Cockpit, UX/UI/CX/DX, Evolvability

---

## L1: Executive Summary

### Mission Objective
Deploy a production-equivalent standalone environment with full mesh networking, Tailscale integration, FLAME distributed processing, and clustering capabilities, then execute comprehensive runtime testing achieving 100% coverage across all dimensions.

### Target Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRODUCTION-EQUIVALENT STANDALONE MESH                     │
│                    Tailscale + FLAME + Clustering + Full Observability       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
    ┌─────────────────────────────────┼─────────────────────────────────┐
    │                                 │                                 │
    ▼                                 ▼                                 ▼
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  MESH LAYER     │         │  APP CLUSTER    │         │  OBS STACK      │
│  (Tailscale)    │         │  (FLAME Pool)   │         │  (Full Telemetry│
├─────────────────┤         ├─────────────────┤         ├─────────────────┤
│ • MagicDNS      │         │ • Phoenix App   │         │ • OTEL Collector│
│ • Mesh Routes   │         │ • FLAME Workers │         │ • Prometheus    │
│ • ACL Policies  │         │ • Cortex Loops  │         │ • Grafana       │
│ • Exit Nodes    │         │ • Prajna Cockpit│         │ • Loki          │
└─────────────────┘         └─────────────────┘         └─────────────────┘
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
                          ┌──────────┴──────────┐
                          │                     │
                          ▼                     ▼
                  ┌───────────────┐     ┌───────────────┐
                  │   DATA TIER   │     │   CACHE TIER  │
                  │  (PostgreSQL  │     │   (Redis)     │
                  │  + Timescale) │     │               │
                  └───────────────┘     └───────────────┘
```

### Success Criteria Matrix

| Dimension | Target | Measurement | Priority |
|-----------|--------|-------------|----------|
| Infrastructure Setup | 100% | All 8 containers running | P0 |
| Mesh Connectivity | 100% | All nodes in Tailscale mesh | P0 |
| FLAME Pool | Active | Workers spawnable | P0 |
| Clustering | 3+ nodes | Distributed state sync | P0 |
| Dataflow Coverage | 100% | All data paths validated | P0 |
| Control Flow Coverage | 100% | All branches exercised | P0 |
| Cockpit Scenarios | 100% | All user journeys | P0 |
| UX Heuristics | >85% | Nielsen's 10 score | P1 |
| UI Consistency | >95% | Design system compliance | P1 |
| CX Net Promoter | >70 | User satisfaction | P1 |
| DX Efficiency | <5min | TTFMA | P1 |
| Evolvability Index | >0.8 | Architectural fitness | P2 |

---

## L2: Infrastructure Architecture

### 2.1 Container Topology (8 Containers)

| Container | Image | Ports | Role | Resources |
|-----------|-------|-------|------|-----------|
| `indrajaal-ex-app-1` | localhost/indrajaal-app:prod | 4000, 4001 | Phoenix + FLAME | 4GB RAM, 4 CPU |
| `indrajaal-db-prod` | localhost/indrajaal-timescaledb:prod | 5433 | PostgreSQL + TimescaleDB | 2GB RAM, 2 CPU |
| `indrajaal-redis-prod` | localhost/indrajaal-redis:prod | 6379 | Cache + PubSub | 512MB RAM, 1 CPU |
| `indrajaal-otel-prod` | localhost/indrajaal-otel:prod | 4317, 4318 | OTEL Collector | 512MB RAM, 1 CPU |
| `indrajaal-prometheus-prod` | localhost/indrajaal-prometheus:prod | 9090 | Metrics | 1GB RAM, 1 CPU |
| `indrajaal-grafana-prod` | localhost/indrajaal-grafana:prod | 3000 | Dashboards | 512MB RAM, 1 CPU |
| `indrajaal-loki-prod` | localhost/indrajaal-loki:prod | 3100 | Log Aggregation | 1GB RAM, 1 CPU |
| `indrajaal-tailscale-prod` | localhost/indrajaal-tailscale:prod | - | Mesh Networking | 256MB RAM, 1 CPU |

### 2.2 Network Architecture

```yaml
Networks:
  indrajaal-mesh:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1

  indrajaal-internal:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.29.0.0/16

Port Mappings:
  Phoenix HTTP:     4000 -> 172.28.0.10:4000
  Phoenix Health:   4001 -> 172.28.0.10:4001
  PostgreSQL:       5433 -> 172.28.0.20:5433
  Redis:            6379 -> 172.28.0.21:6379
  OTEL gRPC:        4317 -> 172.28.0.30:4317
  OTEL HTTP:        4318 -> 172.28.0.30:4318
  Prometheus:       9090 -> 172.28.0.31:9090
  Grafana:          3000 -> 172.28.0.32:3000
  Loki:             3100 -> 172.28.0.33:3100
```

### 2.3 Tailscale Mesh Configuration

```yaml
Tailscale Config:
  AuthKey: ${TAILSCALE_AUTH_KEY}
  Hostname: indrajaal-standalone
  Routes:
    - 172.28.0.0/16  # Mesh network
    - 172.29.0.0/16  # Internal network
  ExitNode: false
  AcceptDNS: true
  MagicDNS: true

ACL Policy:
  Groups:
    - group:indrajaal-admin
    - group:indrajaal-operator
  TagOwners:
    tag:indrajaal-app:
      - group:indrajaal-admin
    tag:indrajaal-db:
      - group:indrajaal-admin
```

### 2.4 FLAME Pool Configuration

```elixir
# config/prod_standalone.exs
config :flame,
  backend: FLAME.LocalBackend,
  min_pool_size: 2,
  max_pool_size: 10,
  idle_shutdown_after: :timer.minutes(5),
  boot_timeout: :timer.seconds(30),
  single_use: false,

  # Podman backend for production
  podman_backend: [
    image: "localhost/indrajaal-flame-worker:prod",
    network: "indrajaal-mesh",
    memory_limit: "1g",
    cpu_quota: 100_000
  ]

# FLAME Pool Definition
defmodule Indrajaal.FLAME.WorkerPool do
  use FLAME.Pool,
    name: :worker_pool,
    min: 2,
    max: 10,
    max_concurrency: 5,
    idle_shutdown_after: :timer.minutes(5)
end
```

### 2.5 Clustering Configuration

```elixir
# config/prod_standalone.exs
config :libcluster,
  topologies: [
    standalone_mesh: [
      strategy: Cluster.Strategy.Gossip,
      config: [
        port: 45892,
        if_addr: "0.0.0.0",
        multicast_addr: "230.1.1.251",
        multicast_ttl: 1
      ]
    ],
    tailscale_dns: [
      strategy: Indrajaal.Cluster.Strategies.TailscaleDNS,
      config: [
        query: "indrajaal-*.tailnet.ts.net",
        node_basename: "indrajaal"
      ]
    ]
  ]

# Distributed State
config :indrajaal,
  distributed_state: [
    adapter: Indrajaal.Distributed.HordeAdapter,
    registry: Indrajaal.Distributed.Registry,
    supervisor: Indrajaal.Distributed.Supervisor
  ]
```

---

## L3: Test Execution Plan

### 3.1 Phase 1: Infrastructure Deployment (10 min)

```bash
# Step 1: Start full production-equivalent stack
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d

# Step 2: Wait for health checks
./scripts/testing/wait_for_health.sh --timeout 120

# Step 3: Initialize Tailscale mesh
./scripts/mesh/init_tailscale_mesh.sh

# Step 4: Verify FLAME pool
./scripts/testing/verify_flame_pool.sh

# Step 5: Verify clustering
./scripts/testing/verify_cluster.sh
```

### 3.2 Phase 2: Dataflow Testing (15 min)

| Test Suite | Scenarios | Coverage Target |
|------------|-----------|-----------------|
| DF-DB | CRUD, Transactions, Queries, Migrations | 100% |
| DF-API | REST, WebSocket, GraphQL | 100% |
| DF-EVT | Telemetry, PubSub, OODA Sensors | 100% |
| DF-CACHE | Redis Operations, Session State | 100% |
| DF-MESH | Tailscale Routes, DNS Resolution | 100% |
| DF-FLAME | Worker Spawn, Task Distribution | 100% |
| DF-CLUSTER | State Sync, Leader Election | 100% |

### 3.3 Phase 3: Control Flow Testing (15 min)

| Test Suite | Scenarios | Coverage Target |
|------------|-----------|-----------------|
| CF-OODA | Normal Cycle, Hysteresis, AI Fallback | 100% |
| CF-CB | Circuit Breaker States, Recovery | 100% |
| CF-AUTH | JWT Lifecycle, MFA, Session | 100% |
| CF-FLAME | Pool Scaling, Worker Lifecycle | 100% |
| CF-CLUSTER | Node Join/Leave, Failover | 100% |
| CF-MESH | Route Changes, DNS Updates | 100% |

### 3.4 Phase 4: Cockpit Testing (20 min)

| Test Suite | Scenarios | Coverage Target |
|------------|-----------|-----------------|
| CK-OP | Operator Journeys (3) | 100% |
| CK-AD | Admin Journeys (3) | 100% |
| CK-UX-H | Nielsen Heuristics (10) | >85% |
| CK-UI | Consistency (4) | >95% |
| CK-CX | Customer Experience (4) | >70 NPS |
| CK-DX | Developer Experience (4) | <5min TTFMA |
| CK-ERG | Ergonomics (4) | WCAG AA |
| CK-IA | Information Architecture (3) | 100% |
| CK-AES | Aesthetics (3) | >85% |

### 3.5 Phase 5: Evolvability Assessment (10 min)

| Test Suite | Scenarios | Target |
|------------|-----------|--------|
| AF | Fitness Functions (4) | >0.8 index |
| EXT | Extensibility (3) | Plugins work |
| MNT | Maintainability (3) | Complexity <10 |
| ADP | Adaptability (3) | Config external |

---

## L4: F# Execution Scripts

### 4.1 Production Deployment Orchestrator

```fsharp
// ProductionDeploymentOrchestrator.fsx
// Orchestrates full production-equivalent deployment

module ProductionDeployment =
    type ContainerStatus = Starting | Running | Healthy | Failed
    type MeshStatus = Disconnected | Connecting | Connected | Routing
    type FlameStatus = Idle | Spawning | Active | Scaling
    type ClusterStatus = Standalone | Discovering | Joined | Synced

    type DeploymentState = {
        Containers: Map<string, ContainerStatus>
        Mesh: MeshStatus
        Flame: FlameStatus
        Cluster: ClusterStatus
        StartedAt: DateTime
    }

    let deploymentSequence = [
        ("Database", "indrajaal-db-prod")
        ("Redis", "indrajaal-redis-prod")
        ("OTEL", "indrajaal-otel-prod")
        ("Prometheus", "indrajaal-prometheus-prod")
        ("Grafana", "indrajaal-grafana-prod")
        ("Loki", "indrajaal-loki-prod")
        ("Tailscale", "indrajaal-tailscale-prod")
        ("Application", "indrajaal-ex-app-1")
    ]
```

### 4.2 Comprehensive Runtime Test Suite

```fsharp
// ComprehensiveRuntimeTests.fsx
// Full test coverage with biomorphic swarm

module ComprehensiveTests =
    // Test Categories
    type TestPhase =
        | Infrastructure
        | Dataflow
        | ControlFlow
        | Cockpit
        | Evolvability

    // Full Test Manifest (100 scenarios)
    let testManifest = [
        // Infrastructure (8)
        { Phase = Infrastructure; Id = "INF-001"; Name = "Container Health" }
        { Phase = Infrastructure; Id = "INF-002"; Name = "Network Connectivity" }
        { Phase = Infrastructure; Id = "INF-003"; Name = "Tailscale Mesh" }
        { Phase = Infrastructure; Id = "INF-004"; Name = "FLAME Pool" }
        { Phase = Infrastructure; Id = "INF-005"; Name = "Cluster Discovery" }
        { Phase = Infrastructure; Id = "INF-006"; Name = "Database Connection" }
        { Phase = Infrastructure; Id = "INF-007"; Name = "Redis Connection" }
        { Phase = Infrastructure; Id = "INF-008"; Name = "OTEL Pipeline" }

        // Dataflow (17)
        { Phase = Dataflow; Id = "DF-DB-001"; Name = "CRUD Lifecycle" }
        { Phase = Dataflow; Id = "DF-DB-002"; Name = "Transaction Atomicity" }
        { Phase = Dataflow; Id = "DF-DB-003"; Name = "Query Optimization" }
        { Phase = Dataflow; Id = "DF-DB-004"; Name = "Migration Integrity" }
        { Phase = Dataflow; Id = "DF-API-001"; Name = "REST Endpoints" }
        { Phase = Dataflow; Id = "DF-API-002"; Name = "WebSocket Channels" }
        { Phase = Dataflow; Id = "DF-API-003"; Name = "GraphQL Operations" }
        { Phase = Dataflow; Id = "DF-EVT-001"; Name = "Telemetry Events" }
        { Phase = Dataflow; Id = "DF-EVT-002"; Name = "PubSub Messages" }
        { Phase = Dataflow; Id = "DF-EVT-003"; Name = "OODA Observations" }
        { Phase = Dataflow; Id = "DF-CACHE-001"; Name = "Redis Get/Set" }
        { Phase = Dataflow; Id = "DF-CACHE-002"; Name = "Session State" }
        { Phase = Dataflow; Id = "DF-MESH-001"; Name = "Tailscale Routes" }
        { Phase = Dataflow; Id = "DF-MESH-002"; Name = "MagicDNS Resolution" }
        { Phase = Dataflow; Id = "DF-FLAME-001"; Name = "Worker Spawn" }
        { Phase = Dataflow; Id = "DF-FLAME-002"; Name = "Task Distribution" }
        { Phase = Dataflow; Id = "DF-CLUSTER-001"; Name = "State Sync" }

        // Control Flow (14)
        { Phase = ControlFlow; Id = "CF-OODA-001"; Name = "Normal Cycle" }
        { Phase = ControlFlow; Id = "CF-OODA-002"; Name = "Hysteresis Mode" }
        { Phase = ControlFlow; Id = "CF-OODA-003"; Name = "AI Fallback" }
        { Phase = ControlFlow; Id = "CF-CB-001"; Name = "Circuit Breaker States" }
        { Phase = ControlFlow; Id = "CF-CB-002"; Name = "Recovery Behavior" }
        { Phase = ControlFlow; Id = "CF-AUTH-001"; Name = "JWT Lifecycle" }
        { Phase = ControlFlow; Id = "CF-AUTH-002"; Name = "MFA Flow" }
        { Phase = ControlFlow; Id = "CF-FLAME-001"; Name = "Pool Scaling Up" }
        { Phase = ControlFlow; Id = "CF-FLAME-002"; Name = "Pool Scaling Down" }
        { Phase = ControlFlow; Id = "CF-FLAME-003"; Name = "Worker Crash Recovery" }
        { Phase = ControlFlow; Id = "CF-CLUSTER-001"; Name = "Node Join" }
        { Phase = ControlFlow; Id = "CF-CLUSTER-002"; Name = "Node Leave" }
        { Phase = ControlFlow; Id = "CF-CLUSTER-003"; Name = "Leader Election" }
        { Phase = ControlFlow; Id = "CF-MESH-001"; Name = "Route Failover" }

        // Cockpit (41)
        { Phase = Cockpit; Id = "CK-OP-001"; Name = "Morning Shift Startup" }
        { Phase = Cockpit; Id = "CK-OP-002"; Name = "Alert Response" }
        { Phase = Cockpit; Id = "CK-OP-003"; Name = "AI Copilot Query" }
        { Phase = Cockpit; Id = "CK-AD-001"; Name = "User Management" }
        { Phase = Cockpit; Id = "CK-AD-002"; Name = "System Configuration" }
        { Phase = Cockpit; Id = "CK-AD-003"; Name = "Report Generation" }
        // ... UX Heuristics H01-H10
        // ... UI Consistency 001-004
        // ... CX Metrics 001-004
        // ... DX Metrics 001-004
        // ... Ergonomics 001-004
        // ... IA 001-003
        // ... Aesthetics 001-003

        // Evolvability (13)
        { Phase = Evolvability; Id = "AF-001"; Name = "Modularity Index" }
        { Phase = Evolvability; Id = "AF-002"; Name = "Coupling Score" }
        { Phase = Evolvability; Id = "AF-003"; Name = "Cohesion Score" }
        { Phase = Evolvability; Id = "AF-004"; Name = "Test Coverage" }
        { Phase = Evolvability; Id = "EXT-001"; Name = "Plugin Architecture" }
        { Phase = Evolvability; Id = "EXT-002"; Name = "Feature Flags" }
        { Phase = Evolvability; Id = "EXT-003"; Name = "API Versioning" }
        { Phase = Evolvability; Id = "MNT-001"; Name = "Code Complexity" }
        { Phase = Evolvability; Id = "MNT-002"; Name = "Technical Debt" }
        { Phase = Evolvability; Id = "MNT-003"; Name = "Documentation Currency" }
        { Phase = Evolvability; Id = "ADP-001"; Name = "Config Externalization" }
        { Phase = Evolvability; Id = "ADP-002"; Name = "Database Agnosticism" }
        { Phase = Evolvability; Id = "ADP-003"; Name = "UI Theming" }
    ]
```

---

## L5: Execution Commands

### 5.1 Full Deployment + Test Sequence

```bash
#!/bin/bash
# scripts/testing/run_production_equivalent_tests.sh

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  PRODUCTION-EQUIVALENT RUNTIME TESTING                        ║"
echo "║  Full Mesh + Tailscale + FLAME + Clustering                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Phase 1: Deploy Infrastructure
echo "▶ Phase 1: Deploying Infrastructure..."
dotnet fsi lib/cepaf/scripts/ProductionDeploymentOrchestrator.fsx --deploy

# Phase 2: Verify Infrastructure
echo "▶ Phase 2: Verifying Infrastructure..."
dotnet fsi lib/cepaf/scripts/InfrastructureVerifier.fsx --all

# Phase 3: Run Comprehensive Tests (Biomorphic Swarm)
echo "▶ Phase 3: Running Comprehensive Tests..."
dotnet fsi lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx --mode swarm --parallel 10

# Phase 4: Generate Reports
echo "▶ Phase 4: Generating Reports..."
dotnet fsi lib/cepaf/scripts/TestReportGenerator.fsx --format html,md,json

echo "═══════════════════════════════════════════════════════════════"
echo "COMPLETE: All tests executed"
echo "Reports: reports/production_test_$(date +%Y%m%d)/"
```

### 5.2 Quick Start Commands

```bash
# Full automated execution
./scripts/testing/run_production_equivalent_tests.sh

# Manual step-by-step

# 1. Deploy production-equivalent stack
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d

# 2. Wait for services
./scripts/testing/wait_for_health.sh --timeout 120

# 3. Initialize mesh
./scripts/mesh/init_tailscale_mesh.sh

# 4. Run F# deployment orchestrator
dotnet fsi lib/cepaf/scripts/ProductionDeploymentOrchestrator.fsx --verify

# 5. Run comprehensive tests
dotnet fsi lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx --mode swarm

# 6. Run UX evaluation
dotnet fsi lib/cepaf/scripts/CockpitUXEvaluator.fsx

# 7. Generate final report
dotnet fsi lib/cepaf/scripts/TestReportGenerator.fsx
```

---

## STAMP Safety Constraints

| Constraint | Description | Verification |
|------------|-------------|--------------|
| SC-INF-001 | All 8 containers must be healthy | Health check pass |
| SC-MESH-001 | Tailscale mesh connected | Route verification |
| SC-FLAME-001 | FLAME pool active | Worker spawn test |
| SC-CLUSTER-001 | Cluster sync complete | State consistency |
| SC-OODA-001 | Cycle time <100ms | Performance test |
| SC-OODA-005 | Hysteresis active | Oscillation test |
| SC-UX-001 | Nielsen H1-H10 | >85% score |
| SC-PRF-050 | Response <50ms | Load test |

---

## Access Points (Production-Equivalent)

| Service | URL | Credentials |
|---------|-----|-------------|
| Phoenix App | http://localhost:4000 | - |
| Health Check | http://localhost:4001/health | - |
| Prajna Cockpit | http://localhost:4000/prajna | - |
| AI Copilot | http://localhost:4000/prajna/copilot | - |
| LiveDashboard | http://localhost:4000/dev/dashboard | - |
| Grafana | http://localhost:3000 | admin/indrajaal |
| Prometheus | http://localhost:9090 | - |
| Loki | http://localhost:3100 | - |

---

## References

- `docs/architecture/TAILSCALE_MESH_MASTER_SPECIFICATION.md`
- `docs/architecture/FLAME_MESH_STRATEGY.md`
- `docs/architecture/MESH_NETWORKING_DESIGN.md`
- `journal/2025-12/20251229-2100-comprehensive-standalone-fsharp-testing-architecture.md`
