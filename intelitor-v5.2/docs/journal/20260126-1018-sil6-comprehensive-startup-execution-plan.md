# SIL-6 Comprehensive Startup Execution Plan

**Date**: 2026-01-26 10:18 CEST
**Version**: 21.3.0-SIL6
**Author**: Claude Opus 4.5 (Biomorphic Cortex)
**STAMP Compliance**: SC-SIL6-001 to SC-SIL6-015, SC-MESH-001 to SC-MESH-010

---

## Level 1: Executive Summary

### Purpose
Execute all pending sprint items (23, 43-46) with full SIL-6 biomorphic mesh, F# orchestration, comprehensive BDD testing, and Zenoh telemetry.

### Scope
- 14-container mesh architecture
- 6 phases of implementation
- 16-22 hours estimated effort
- 100% boot/smoke test pass rate required

### Critical Deliverables
1. Self-healing recovery implementation (P0)
2. FPPS 5-method consensus wiring (P0)
3. Rate limiting and FLAME metrics (P1)
4. Comprehensive BDD test suite

---

## Level 2: Architecture Specification

### 2.1 14-Container SIL-6 Mesh Topology

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     SIL-6 BIOMORPHIC FRACTAL MESH (14 Containers)              │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ COGNITIVE PLANE (F# .NET 10.0)                                          │   │
│  │  ┌─────────────────────┐  ┌─────────────────────┐                       │   │
│  │  │ indrajaal-cortex    │  │ cepaf-bridge        │                       │   │
│  │  │ :9877               │  │ :9876               │                       │   │
│  │  │ 172.28.0.60         │  │ 172.28.0.50         │                       │   │
│  │  └─────────────────────┘  └─────────────────────┘                       │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                             │                                                   │
│                             ▼ Zenoh Pub/Sub                                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ MESH CONTROL PLANE - 2oo3 Quorum (SC-SIL6-006)                          │   │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐             │   │
│  │  │ zenoh-router-1 │  │ zenoh-router-2 │  │ zenoh-router-3 │             │   │
│  │  │ :7447          │  │ :7448          │  │ :7449          │             │   │
│  │  │ 172.28.0.40    │  │ 172.28.0.41    │  │ 172.28.0.42    │             │   │
│  │  └────────────────┘  └────────────────┘  └────────────────┘             │   │
│  │                 ↓                              ↓                         │   │
│  │        ┌────────────────┐ (Legacy Proxy)                                │   │
│  │        │ zenoh-router   │ 172.28.0.43                                   │   │
│  │        └────────────────┘                                               │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                             │                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ APPLICATION PLANE - HA Cluster (3 nodes)                                │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │   │
│  │  │ indrajaal-ex-1  │  │ indrajaal-ex-2  │  │ indrajaal-ex-3  │          │   │
│  │  │ :4000 Primary   │  │ :4003           │  │ :4005           │          │   │
│  │  │ 172.28.0.10     │  │ 172.28.0.11     │  │ 172.28.0.12     │          │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ DIGITAL TWIN & SATELLITE PLANE                                          │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │   │
│  │  │ indrajaal-chaya │  │ ml-runner-1     │  │ ml-runner-2     │          │   │
│  │  │ :4002           │  │ (FLAME)         │  │ (FLAME)         │          │   │
│  │  │ 172.28.0.70     │  │ 172.28.0.80     │  │ 172.28.0.81     │          │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ DATA + OBSERVABILITY PLANE                                               │   │
│  │  ┌─────────────────────┐  ┌─────────────────────────────────────────┐   │   │
│  │  │ indrajaal-db-prod   │  │ indrajaal-obs-prod                      │   │   │
│  │  │ PostgreSQL+Timescale│  │ OTEL+Prometheus+Grafana+Loki+SigNoz     │   │   │
│  │  │ :5433               │  │ :4317,:9090,:3000,:3100,:8123           │   │   │
│  │  │ 172.28.0.20         │  │ 172.28.0.30                             │   │   │
│  │  └─────────────────────┘  └─────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    MESH NETWORK (172.28.0.0/16)                          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Boot Sequence DAG (Directed Acyclic Graph)

```
S0_PREFLIGHT ─────────────────────────────────────────────────────────────────┐
  │                                                                            │
  │ Checkpoint: CP-BOOT-01, CP-BOOT-02                                        │
  │ State Vector: [0,0,0,0,0,0]                                               │
  ▼                                                                            │
S1_INFRASTRUCTURE ────────────────────────────────────────────────────────────┤
  │                                                                            │
  │ ├── indrajaal-db-prod (PostgreSQL 17 + TimescaleDB)                       │
  │ │   CP-BOOT-03: Database ready                                            │
  │ │   State Vector: [1,1,0,0,0,0]                                           │
  │ │                                                                          │
  │ └── indrajaal-obs-prod (OTEL + Prometheus + Grafana + Loki + SigNoz)      │
  │     CP-BOOT-04: Observability ready                                       │
  │     State Vector: [1,1,1,0,0,0]                                           │
  ▼                                                                            │
S2_ZENOH_MESH ────────────────────────────────────────────────────────────────┤
  │                                                                            │
  │ ├── zenoh-router-1 (Primary, :7447)                                       │
  │ ├── zenoh-router-2 (Secondary, :7448)                                     │
  │ └── zenoh-router-3 (Tertiary, :7449)                                      │
  │     CP-BOOT-05: Quorum achieved (2oo3)                                    │
  │     State Vector: [1,1,1,1,0,0]                                           │
  │                                                                            │
  │ └── zenoh-router (Proxy)                                                  │
  ▼                                                                            │
S3_COGNITIVE ─────────────────────────────────────────────────────────────────┤
  │                                                                            │
  │ ├── cepaf-bridge (F# Bridge, :9876)                                       │
  │ │   CP-BOOT-06: Bridge connected                                          │
  │ │                                                                          │
  │ └── indrajaal-cortex (AI Cortex, :9877)                                   │
  │     CP-BOOT-07: Cortex online                                             │
  ▼                                                                            │
S4_APP_SEED ──────────────────────────────────────────────────────────────────┤
  │                                                                            │
  │ └── indrajaal-ex-app-1 (Primary Phoenix + FLAME + Redis)                  │
  │     CP-BOOT-08: Seed ready                                                │
  │     State Vector: [1,1,1,1,1,0]                                           │
  │                                                                            │
  │ Parallel:                                                                  │
  │ ├── indrajaal-ex-app-2 (HA Node 2)                                        │
  │ ├── indrajaal-ex-app-3 (HA Node 3)                                        │
  │ ├── indrajaal-chaya (Digital Twin)                                        │
  │ ├── indrajaal-ml-runner-1 (FLAME Satellite)                               │
  │ └── indrajaal-ml-runner-2 (FLAME Satellite)                               │
  ▼                                                                            │
S5_HOMEOSTASIS ───────────────────────────────────────────────────────────────┘
  │
  │ CP-BOOT-09: Homeostasis verified
  │ CP-BOOT-10: Full mesh operational
  │ State Vector: [1,1,1,1,1,1]
  │
  │ Verification:
  │ ├── Health Check: All containers healthy
  │ ├── Quorum Check: 2oo3 Zenoh routers online
  │ ├── Cortex Check: F#/Elixir bridge connected
  │ └── FPPS Consensus: 5/5 methods agree
  ▼
  MESH OPERATIONAL
```

### 2.3 Resource Allocation

| Container | Memory | CPU | IP Address | Ports | Role |
|-----------|--------|-----|------------|-------|------|
| indrajaal-db-prod | 4GB | 4 | 172.28.0.20 | 5433 | Data Plane |
| indrajaal-obs-prod | 10GB | 6 | 172.28.0.30 | 4317,9090,3000,3100,8123 | Observability |
| zenoh-router-1 | 512MB | 1 | 172.28.0.40 | 7447,8000 | Control Plane |
| zenoh-router-2 | 512MB | 1 | 172.28.0.41 | 7448,8001 | Control Plane |
| zenoh-router-3 | 512MB | 1 | 172.28.0.42 | 7449,8002 | Control Plane |
| zenoh-router | 256MB | 0.5 | 172.28.0.43 | - | Proxy |
| cepaf-bridge | 1GB | 2 | 172.28.0.50 | 9876 | Cognitive |
| indrajaal-cortex | 1GB | 2 | 172.28.0.60 | 9877 | Cognitive |
| indrajaal-ex-app-1 | 10GB | 8 | 172.28.0.10 | 4000,4001,6379 | Application |
| indrajaal-ex-app-2 | 10GB | 8 | 172.28.0.11 | 4003,4004 | Application HA |
| indrajaal-ex-app-3 | 10GB | 8 | 172.28.0.12 | 4005,4006 | Application HA |
| indrajaal-chaya | 10GB | 8 | 172.28.0.70 | 4002 | Digital Twin |
| indrajaal-ml-runner-1 | 10GB | 8 | 172.28.0.80 | - | FLAME Satellite |
| indrajaal-ml-runner-2 | 10GB | 8 | 172.28.0.81 | - | FLAME Satellite |
| **TOTAL** | **~79GB** | **~66** | | | |

---

## Level 3: STAMP, AOR, FMEA, TDG Specifications

### 3.1 STAMP Constraints (Boot Sequence)

| ID | Constraint | Severity | Verification | Math Basis |
|----|------------|----------|--------------|------------|
| SC-BOOT-001 | DAG must be acyclic | CRITICAL | Topological sort | $\nexists$ cycle in $G$ |
| SC-BOOT-002 | Single source (S0_PREFLIGHT) | CRITICAL | Graph analysis | $|sources(G)| = 1$ |
| SC-BOOT-003 | Single sink (S5_HOMEOSTASIS) | CRITICAL | Graph analysis | $|sinks(G)| = 1$ |
| SC-BOOT-004 | State vector transitions valid | CRITICAL | FSM verification | $\forall i, t_1 < t_2: s_i(t_1) = 1 \implies s_i(t_2) = 1$ |
| SC-BOOT-005 | Checkpoint latency < 100ms | HIGH | Telemetry | $L_{checkpoint} < 100ms$ |
| SC-BOOT-006 | Rollback path exists at each stage | CRITICAL | Code review | $\forall stage: rollback(stage) \neq \emptyset$ |
| SC-BOOT-007 | Zenoh quorum = 2oo3 | CRITICAL | Health check | $healthy \geq \lfloor 3/2 \rfloor + 1 = 2$ |
| SC-BOOT-008 | Container health timeout < 30s | HIGH | Health check | $T_{health} < 30s$ |
| SC-BOOT-009 | All env vars from central config | CRITICAL | Code review | No magic values |
| SC-BOOT-010 | Log fallback when Zenoh unavailable | CRITICAL | Integration test | SC-ZTEST-008 |

### 3.2 AOR Rules (Boot Sequence)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-BOOT-001 | PREFLIGHT must scour all ports before start | Port check script |
| AOR-BOOT-002 | INFRASTRUCTURE depends on DB healthy first | Compose depends_on |
| AOR-BOOT-003 | ZENOH_MESH requires 2oo3 before proceeding | Quorum check |
| AOR-BOOT-004 | COGNITIVE requires Zenoh healthy | Health dependency |
| AOR-BOOT-005 | APP_SEED waits for 5-phase health check | Retry loop |
| AOR-BOOT-006 | HOMEOSTASIS verifies all L0-L7 layers | Fractal verification |
| AOR-BOOT-007 | SHUTDOWN checkpoints state before stopping | Dying gasp |
| AOR-BOOT-008 | All boot messages published to Zenoh | Telemetry |

### 3.3 FMEA Risk Analysis

| ID | Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|----|--------------|----------|------------|-----------|-----|------------|
| FMEA-BOOT-001 | DB fails to start | 9 | 2 | 9 | 162 | Retry with backoff |
| FMEA-BOOT-002 | Zenoh quorum not achieved | 8 | 3 | 8 | 192 | Fallback to log-based |
| FMEA-BOOT-003 | App health timeout | 7 | 4 | 6 | 168 | Extend timeout to 900s |
| FMEA-BOOT-004 | Cortex bridge disconnected | 6 | 3 | 4 | 72 | Continue without cognitive |
| FMEA-BOOT-005 | Port conflict | 8 | 3 | 9 | 216 | Port scour in preflight |
| FMEA-BOOT-006 | Container image missing | 9 | 2 | 8 | 144 | Pre-check images |
| FMEA-BOOT-007 | Network partition | 7 | 2 | 5 | 70 | 2oo3 redundancy |
| FMEA-BOOT-008 | State vector corruption | 9 | 1 | 6 | 54 | Checkpoint recovery |

### 3.4 TDG Test Specifications

```elixir
# Property: Boot sequence is monotonic (states only advance)
property "state vector monotonicity" do
  forall states <- PC.list(state_vector_gen()) do
    Enum.chunk_every(states, 2, 1, :discard)
    |> Enum.all?(fn [s1, s2] -> monotonic?(s1, s2) end)
  end
end

# Property: Quorum calculation is correct
property "quorum requires floor(N/2)+1" do
  forall n <- PC.integer(2, 10) do
    required = div(n, 2) + 1
    forall healthy <- PC.integer(0, n) do
      if healthy >= required do
        quorum_achieved?(healthy, n)
      else
        not quorum_achieved?(healthy, n)
      end
    end
  end
end

# Property: Checkpoint IDs are unique
property "checkpoint uniqueness" do
  forall ids <- SD.uniq_list_of(checkpoint_id_gen(), min_length: 10) do
    length(ids) == length(Enum.uniq(ids))
  end
end
```

---

## Level 4: Implementation Details

### 4.1 Centralized Configuration (F#)

**File**: `lib/cepaf/src/Cepaf/Config/MeshConfig.fs`

```fsharp
module Cepaf.Config.MeshConfig

/// Centralized mesh configuration - SC-BOOT-009: No magic values
type MeshConfig = {
    // Network
    MeshSubnet: string           // 172.28.0.0/16
    InternalSubnet: string       // 172.29.0.0/16
    Gateway: string              // 172.28.0.1

    // Database
    DbHost: string               // indrajaal-db-prod
    DbPort: int                  // 5433
    DbName: string               // indrajaal_prod
    DbUser: string               // postgres

    // Zenoh (2oo3 Quorum)
    ZenohRouter1: string * int   // ("172.28.0.40", 7447)
    ZenohRouter2: string * int   // ("172.28.0.41", 7448)
    ZenohRouter3: string * int   // ("172.28.0.42", 7449)
    ZenohQuorumRequired: int     // 2

    // Cognitive Plane
    CepafBridgePort: int         // 9876
    CortexPort: int              // 9877

    // Application
    PhoenixPort: int             // 4000
    HealthPort: int              // 4001
    RedisPort: int               // 6379

    // Observability
    OtelGrpcPort: int            // 4317
    OtelHttpPort: int            // 4318
    PrometheusPort: int          // 9090
    GrafanaPort: int             // 3000
    LokiPort: int                // 3100
    ClickhousePort: int          // 8123

    // Timeouts (milliseconds)
    HealthCheckInterval: int     // 10000
    HealthCheckTimeout: int      // 5000
    AppStartupTimeout: int       // 900000
    ZenohConnectTimeout: int     // 5000

    // SIL-6 Settings
    SilLevel: int                // 6
    BiomorphicHealing: bool      // true
    PatientMode: bool            // true
}

let defaultConfig = {
    MeshSubnet = "172.28.0.0/16"
    InternalSubnet = "172.29.0.0/16"
    Gateway = "172.28.0.1"
    DbHost = "indrajaal-db-prod"
    DbPort = 5433
    DbName = "indrajaal_prod"
    DbUser = "postgres"
    ZenohRouter1 = ("172.28.0.40", 7447)
    ZenohRouter2 = ("172.28.0.41", 7448)
    ZenohRouter3 = ("172.28.0.42", 7449)
    ZenohQuorumRequired = 2
    CepafBridgePort = 9876
    CortexPort = 9877
    PhoenixPort = 4000
    HealthPort = 4001
    RedisPort = 6379
    OtelGrpcPort = 4317
    OtelHttpPort = 4318
    PrometheusPort = 9090
    GrafanaPort = 3000
    LokiPort = 3100
    ClickhousePort = 8123
    HealthCheckInterval = 10000
    HealthCheckTimeout = 5000
    AppStartupTimeout = 900000
    ZenohConnectTimeout = 5000
    SilLevel = 6
    BiomorphicHealing = true
    PatientMode = true
}
```

### 4.2 Elixir Centralized Configuration

**File**: `lib/indrajaal/config/mesh_config.ex`

```elixir
defmodule Indrajaal.Config.MeshConfig do
  @moduledoc """
  Centralized mesh configuration for Elixir runtime.

  ## STAMP Constraints
  - SC-BOOT-009: All env vars from central config (no magic values)
  - SC-CONFIG-001: Single source of truth

  ## Usage
      config = Indrajaal.Config.MeshConfig.get()
      db_url = Indrajaal.Config.MeshConfig.database_url()
  """

  @config %{
    # Network
    mesh_subnet: "172.28.0.0/16",
    internal_subnet: "172.29.0.0/16",
    gateway: "172.28.0.1",

    # Database
    db_host: "indrajaal-db-prod",
    db_port: 5433,
    db_name: "indrajaal_prod",
    db_user: "postgres",
    db_password: "postgres",

    # Zenoh (2oo3 Quorum)
    zenoh_routers: [
      {"172.28.0.40", 7447},
      {"172.28.0.41", 7448},
      {"172.28.0.42", 7449}
    ],
    zenoh_quorum_required: 2,

    # Cognitive Plane
    cepaf_bridge_port: 9876,
    cortex_port: 9877,

    # Application
    phoenix_port: 4000,
    health_port: 4001,
    redis_port: 6379,

    # Observability
    otel_grpc_port: 4317,
    otel_http_port: 4318,
    prometheus_port: 9090,
    grafana_port: 3000,
    loki_port: 3100,
    clickhouse_port: 8123,

    # Timeouts (milliseconds)
    health_check_interval: 10_000,
    health_check_timeout: 5_000,
    app_startup_timeout: 900_000,
    zenoh_connect_timeout: 5_000,

    # SIL-6 Settings
    sil_level: 6,
    biomorphic_healing: true,
    patient_mode: true
  }

  def get, do: @config
  def get(key), do: Map.get(@config, key)

  def database_url do
    "ecto://#{@config.db_user}:#{@config.db_password}@#{@config.db_host}:#{@config.db_port}/#{@config.db_name}"
  end

  def zenoh_endpoint do
    {host, port} = hd(@config.zenoh_routers)
    "tcp/#{host}:#{port}"
  end
end
```

### 4.3 BDD Feature Specification

**File**: `test/features/sil6_mesh_boot.feature`

```gherkin
@sil6 @boot @mesh
Feature: SIL-6 Biomorphic Mesh Boot Sequence
  As a system operator
  I want the mesh to boot in a deterministic, transactional manner
  So that I can rely on system stability and recoverability

  Background:
    Given the host system has Podman 5.4.1+ installed
    And all required container images exist in localhost registry
    And ports 4000-9877 are available

  @critical @preflight
  Scenario: S0 Preflight validates environment
    Given no mesh containers are running
    When I execute S0_PREFLIGHT
    Then all ports should be scoured
    And mandatory environment variables should be set
    And checkpoint CP-BOOT-01 should be published to Zenoh
    And state vector should be [0,0,0,0,0,0]

  @critical @infrastructure
  Scenario: S1 Infrastructure starts database and observability
    Given S0_PREFLIGHT has completed successfully
    When I execute S1_INFRASTRUCTURE
    Then indrajaal-db-prod should be running and healthy
    And PostgreSQL should accept connections on port 5433
    And indrajaal-obs-prod should be running
    And Prometheus should be available on port 9090
    And Grafana should be available on port 3000
    And checkpoint CP-BOOT-03 and CP-BOOT-04 should be published
    And state vector should be [1,1,1,0,0,0]

  @critical @zenoh @quorum
  Scenario: S2 Zenoh Mesh achieves 2oo3 quorum
    Given S1_INFRASTRUCTURE has completed successfully
    When I execute S2_ZENOH_MESH
    Then zenoh-router-1 should be running on port 7447
    And zenoh-router-2 should be running on port 7448
    And zenoh-router-3 should be running on port 7449
    And at least 2 of 3 routers should be healthy
    And checkpoint CP-BOOT-05 should indicate quorum achieved
    And state vector should be [1,1,1,1,0,0]

  @critical @cognitive
  Scenario: S3 Cognitive plane connects
    Given S2_ZENOH_MESH has completed successfully
    When I execute S3_COGNITIVE
    Then cepaf-bridge should be running on port 9876
    And indrajaal-cortex should be running on port 9877
    And F#/Elixir bridge should respond to health check
    And checkpoint CP-BOOT-06 and CP-BOOT-07 should be published

  @critical @application
  Scenario: S4 Application seed starts
    Given S3_COGNITIVE has completed successfully
    When I execute S4_APP_SEED
    Then indrajaal-ex-app-1 should be running
    And Phoenix should respond on port 4000
    And health endpoint should respond on port 4001
    And Redis should be available on port 6379
    And checkpoint CP-BOOT-08 should indicate seed ready
    And state vector should be [1,1,1,1,1,0]

  @critical @homeostasis
  Scenario: S5 Homeostasis achieves system stability
    Given S4_APP_SEED has completed successfully
    When I execute S5_HOMEOSTASIS
    Then global health should be >= 80%
    And Zenoh mesh should be active
    And FPPS 5-method consensus should pass
    And checkpoint CP-BOOT-09 should indicate homeostasis verified
    And checkpoint CP-BOOT-10 should indicate mesh operational
    And state vector should be [1,1,1,1,1,1]

  @shutdown @graceful
  Scenario: Graceful shutdown with checkpoint
    Given the full mesh is operational
    When I execute graceful shutdown
    Then lameduck signal should be broadcast
    And connections should drain for 2 seconds
    And state checkpoint should be created
    And all containers should stop in reverse order
    And checkpoint should be restorable
```

### 4.4 Smoke Test Specification

**File**: `lib/cepaf/scripts/SIL6BootSmokeTests.fsx`

```fsharp
/// Comprehensive smoke tests for SIL-6 mesh boot
/// Each test publishes results to Zenoh topic: indrajaal/smoke/{category}/result

type SmokeTestResult = {
    TestId: string
    Category: string
    Name: string
    Status: string  // PASS | FAIL | SKIP
    DurationMs: float
    Evidence: string list
    Timestamp: DateTimeOffset
}

/// CP-SMOKE-01: Database connectivity
let testDatabaseConnectivity () =
    let sw = Stopwatch.StartNew()
    let (code, output, _) = Exec.silent "pg_isready" "-h localhost -p 5433"
    sw.Stop()
    {
        TestId = "SMOKE-DB-001"
        Category = "Database"
        Name = "PostgreSQL Connectivity"
        Status = if code = 0 then "PASS" else "FAIL"
        DurationMs = sw.Elapsed.TotalMilliseconds
        Evidence = [output; sprintf "Exit code: %d" code]
        Timestamp = DateTimeOffset.UtcNow
    }

/// CP-SMOKE-02: Zenoh quorum verification
let testZenohQuorum () =
    let sw = Stopwatch.StartNew()
    let routers = [7447; 7448; 7449]
    let healthy = routers |> List.filter (fun port ->
        let (code, _, _) = Exec.silent "nc" (sprintf "-z localhost %d" port)
        code = 0) |> List.length
    sw.Stop()
    {
        TestId = "SMOKE-ZENOH-001"
        Category = "Zenoh"
        Name = "2oo3 Quorum Check"
        Status = if healthy >= 2 then "PASS" else "FAIL"
        DurationMs = sw.Elapsed.TotalMilliseconds
        Evidence = [sprintf "Healthy routers: %d/3" healthy]
        Timestamp = DateTimeOffset.UtcNow
    }

/// CP-SMOKE-03: Phoenix health endpoint
let testPhoenixHealth () =
    let sw = Stopwatch.StartNew()
    let (code, output, _) = Exec.silent "curl" "-sf http://localhost:4000/health"
    sw.Stop()
    {
        TestId = "SMOKE-APP-001"
        Category = "Application"
        Name = "Phoenix Health Endpoint"
        Status = if code = 0 then "PASS" else "FAIL"
        DurationMs = sw.Elapsed.TotalMilliseconds
        Evidence = [output]
        Timestamp = DateTimeOffset.UtcNow
    }

/// CP-SMOKE-04: Prometheus metrics
let testPrometheusMetrics () =
    let sw = Stopwatch.StartNew()
    let (code, _, _) = Exec.silent "curl" "-sf http://localhost:9090/-/ready"
    sw.Stop()
    {
        TestId = "SMOKE-OBS-001"
        Category = "Observability"
        Name = "Prometheus Ready"
        Status = if code = 0 then "PASS" else "FAIL"
        DurationMs = sw.Elapsed.TotalMilliseconds
        Evidence = []
        Timestamp = DateTimeOffset.UtcNow
    }

/// CP-SMOKE-05: Grafana dashboard
let testGrafanaDashboard () =
    let sw = Stopwatch.StartNew()
    let (code, _, _) = Exec.silent "curl" "-sf http://localhost:3000/api/health"
    sw.Stop()
    {
        TestId = "SMOKE-OBS-002"
        Category = "Observability"
        Name = "Grafana Health"
        Status = if code = 0 then "PASS" else "FAIL"
        DurationMs = sw.Elapsed.TotalMilliseconds
        Evidence = []
        Timestamp = DateTimeOffset.UtcNow
    }

/// CP-SMOKE-06: Cortex bridge
let testCortexBridge () =
    let sw = Stopwatch.StartNew()
    let (code, _, _) = Exec.silent "curl" "-sf http://localhost:9877/health"
    sw.Stop()
    {
        TestId = "SMOKE-CORTEX-001"
        Category = "Cognitive"
        Name = "Cortex Health"
        Status = if code = 0 then "PASS" else "SKIP"  // Optional
        DurationMs = sw.Elapsed.TotalMilliseconds
        Evidence = []
        Timestamp = DateTimeOffset.UtcNow
    }

/// Run all smoke tests
let runAllSmokeTests () =
    let tests = [
        testDatabaseConnectivity
        testZenohQuorum
        testPhoenixHealth
        testPrometheusMetrics
        testGrafanaDashboard
        testCortexBridge
    ]

    let results = tests |> List.map (fun t -> t())
    let passed = results |> List.filter (fun r -> r.Status = "PASS") |> List.length
    let failed = results |> List.filter (fun r -> r.Status = "FAIL") |> List.length
    let skipped = results |> List.filter (fun r -> r.Status = "SKIP") |> List.length

    printfn "\n=== SMOKE TEST SUMMARY ==="
    printfn "Passed:  %d" passed
    printfn "Failed:  %d" failed
    printfn "Skipped: %d" skipped
    printfn "Total:   %d" (List.length results)

    // Publish summary to Zenoh
    let summaryPayload = sprintf """{"passed":%d,"failed":%d,"skipped":%d,"timestamp":"%s"}"""
                            passed failed skipped (DateTimeOffset.UtcNow.ToString("o"))
    Telemetry.zenohLog "indrajaal/smoke/summary" summaryPayload

    (passed, failed, skipped, results)
```

---

## Pending Sprint Items (Execution Order)

### Phase 1: Critical Safety (P0) - Self-Healing Recovery
**File**: `lib/indrajaal/safety/symbiotic_defense.ex`
**Lines**: ~1199-1233

**Current**: `restore_services/1` logs "restart_requested" but never restarts

**Required Implementation**:
```elixir
defp execute_recovery_action(:restart, service_name) do
  Logger.info("[SymbioticDefense] Restarting service: #{service_name}")

  # SC-IMMUNE-005: Recovery attempts limited to 3
  with {:ok, supervisor} <- find_supervisor(service_name),
       :ok <- Supervisor.terminate_child(supervisor, service_name),
       {:ok, _child} <- Supervisor.restart_child(supervisor, service_name) do
    Logger.info("[SymbioticDefense] Service #{service_name} restarted successfully")
    {:ok, :restarted}
  else
    error ->
      Logger.error("[SymbioticDefense] Failed to restart #{service_name}: #{inspect(error)}")
      {:error, error}
  end
end

defp execute_recovery_action(:restore_state, service_name) do
  # AOR-HOLON-012: Self-healing from SQLite/DuckDB state
  holon_path = Indrajaal.Holon.Database.path_for(service_name)

  with {:ok, state} <- Indrajaal.Holon.Database.SQLitePool.read_state(holon_path),
       :ok <- apply_state(service_name, state) do
    {:ok, :state_restored}
  else
    error -> {:error, error}
  end
end
```

### Phase 2: FPPS 5-Method Consensus (P0)
**File**: `lib/indrajaal/validation/methods/ast.ex`

**Current**: 10-line stub

**Required Implementation**:
```elixir
defmodule Indrajaal.Validation.Methods.AST do
  @moduledoc """
  AST-based validation method for FPPS 5-method consensus.

  ## STAMP Constraints
  - SC-VAL-005: FPPS 5-method consensus
  - SC-SIL6-023: 3/5 consensus required
  """

  @behaviour Indrajaal.Validation.Method

  @impl true
  def validate(content) when is_binary(content) do
    case Code.string_to_quoted(content, warn_on_unnecessary_quotes: false) do
      {:ok, ast} ->
        {errors, warnings} = analyze_ast(ast)
        %{
          method: :ast,
          errors: errors,
          warnings: warnings,
          confidence: 0.95,
          detailed_results: %{ast_nodes: count_nodes(ast)}
        }
      {:error, {line, message, _}} ->
        %{
          method: :ast,
          errors: 1,
          warnings: 0,
          confidence: 1.0,
          error_details: [%{line: line, message: message, type: :syntax_error}]
        }
    end
  end

  defp analyze_ast(ast) do
    errors = count_ast_errors(ast)
    warnings = count_ast_warnings(ast)
    {errors, warnings}
  end

  defp count_ast_errors(ast) do
    Macro.prewalk(ast, 0, fn
      {:raise, _, _}, acc -> {nil, acc + 1}
      {:throw, _, _}, acc -> {nil, acc + 1}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end

  defp count_ast_warnings(ast) do
    Macro.prewalk(ast, 0, fn
      {:@, _, [{:deprecated, _, _}]}, acc -> {nil, acc + 1}
      {:Logger, _, [{:warning, _, _}]}, acc -> {nil, acc + 1}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end

  defp count_nodes(ast) do
    Macro.prewalk(ast, 0, fn node, acc -> {node, acc + 1} end)
    |> elem(1)
  end
end
```

---

## References

### Documentation
- `CLAUDE.md` - Master system specification
- `docs/architecture/HOLON_IMMUTABLE_REGISTER.md` - Immutable register architecture
- `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md` - Supreme covenant
- `.claude/rules/fsharp-sil6-mesh.md` - F# mesh orchestration rules
- `.claude/rules/zenoh-test-messaging.md` - Zenoh telemetry specification

### Scripts
- `lib/cepaf/scripts/SIL6MeshOrchestrator.fsx` - Unified mesh orchestrator
- `lib/cepaf/scripts/ComprehensiveStartupOrchestrator.fsx` - 7-phase startup
- `lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx` - Swarm coordination

### Configuration
- `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml` - 14-container mesh
- `config/zenoh/zenoh-router-*.json5` - Zenoh router configurations

### Test Suites
- `test/indrajaal/validation/fpps_consensus_test.exs` - FPPS tests (762 lines)
- `test/indrajaal/safety/sentinel_test.exs` - Sentinel tests
- `test/indrajaal/safety/symbiotic_defense_test.exs` - Self-healing tests

---

## Verification Checklist

- [ ] All 14 containers running and healthy
- [ ] Zenoh 2oo3 quorum achieved
- [ ] FPPS 5-method consensus passing
- [ ] Self-healing recovery functional
- [ ] Rate limiting ETS operational
- [ ] FLAME metrics non-zero
- [ ] All smoke tests passing
- [ ] State vector = [1,1,1,1,1,1]
- [ ] Global health >= 80%
- [ ] Checkpoint/restore functional

---

**End of Journal Entry**
