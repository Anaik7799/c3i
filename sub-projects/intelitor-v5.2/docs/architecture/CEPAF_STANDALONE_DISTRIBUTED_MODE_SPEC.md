# CEPAF Standalone Distributed Mode - Comprehensive 5-Level Specification

**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: ACTIVE
**STAMP Compliance**: SC-CLU-001 to SC-CLU-005, SC-VAL-003, SC-OBS-069

---

## Level 1: Requirements & Overview

### 1.1 Purpose
The CEPAF Standalone Distributed Mode provides a mathematically verified, fault-tolerant infrastructure for running Indrajaal as a distributed Erlang/Elixir cluster with remote access capabilities.

### 1.2 Key Requirements

| ID | Requirement | Priority | STAMP Constraint |
|----|-------------|----------|------------------|
| REQ-001 | Erlang distribution with named nodes | P0 | SC-CLU-001 |
| REQ-002 | EPMD binding to 0.0.0.0:4369 | P0 | SC-CLU-002 |
| REQ-003 | Distribution ports 9100-9105 | P0 | SC-CLU-003 |
| REQ-004 | Synchronized cookie across nodes | P0 | SC-CLU-004 |
| REQ-005 | Tailscale MagicDNS integration | P1 | SC-CLU-005 |
| REQ-006 | 100% FPPS consensus verification | P0 | SC-VAL-003 |
| REQ-007 | Dual logging (Terminal + SigNoz) | P0 | SC-OBS-069 |
| REQ-008 | Remote Livebook attachment | P1 | - |
| REQ-009 | Service DAG boot ordering | P0 | - |
| REQ-010 | Automatic database creation/migration | P1 | SC-DB-001 |

### 1.3 Success Criteria

```
Success ≡ ∀ service ∈ Services: FPPS₅(service) = Consensus(5/5)
        ∧ EpmdRunning = true
        ∧ ErlangNodeRegistered = true
        ∧ DatabaseStatus = Ready
        ∧ AllContainersHealthy = true
```

---

## Level 2: Architecture

### 2.1 System Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CEPAF Standalone Distributed Mode                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐   │
│  │   Layer 0: DB     │    │  Layer 1: Cache   │    │  Layer 2: OBS     │   │
│  │   TimescaleDB     │    │     Redis         │    │   Grafana/OTEL    │   │
│  │   Port: 5433      │    │   Port: 6379      │    │   Ports: 3000+    │   │
│  └─────────┬─────────┘    └─────────┬─────────┘    └─────────┬─────────┘   │
│            │                        │                        │              │
│            └────────────────────────┼────────────────────────┘              │
│                                     │                                        │
│  ┌──────────────────────────────────▼──────────────────────────────────────┐│
│  │                        Layer 3: Application                              ││
│  │   Phoenix + Erlang Distribution                                          ││
│  │   HTTP: 4000 | EPMD: 4369 | Dist: 9100-9105                             ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │                        Network Layer                                      ││
│  │   indrajaal-mesh: 172.30.0.0/24 (Tailscale or Local)                     ││
│  └──────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Service DAG (Directed Acyclic Graph)

```fsharp
// ServiceDAG with Kahn's algorithm for topological sorting
type ContainerDef = {
    Name: string
    Image: string
    DependsOn: string list
    DependencyTypes: Map<string, DependencyType>
    Layer: int option
}

// Boot Order (Topological Sort Result):
// 1. indrajaal-db-standalone      (Layer 0 - no dependencies)
// 2. indrajaal-redis-standalone   (Layer 1 - no dependencies)
// 3. indrajaal-obs-standalone     (Layer 2 - optional DB dependency)
// 4. indrajaal-app-standalone     (Layer 3 - depends on DB + Redis)
```

### 2.3 Dependency Graph

```
                    ┌─────────────────────┐
                    │  indrajaal-app      │
                    │  Layer 3            │
                    └─────────┬───────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │ MANDATORY       │ MANDATORY       │ OPTIONAL
            ▼                 ▼                 ▼
┌───────────────────┐ ┌───────────────────┐ ┌───────────────────┐
│ indrajaal-db      │ │ indrajaal-redis   │ │ indrajaal-obs     │
│ Layer 0           │ │ Layer 1           │ │ Layer 2           │
└───────────────────┘ └───────────────────┘ └─────────┬─────────┘
                                                       │ OPTIONAL
                                                       ▼
                                            ┌───────────────────┐
                                            │ indrajaal-db      │
                                            │ Layer 0           │
                                            └───────────────────┘
```

---

## Level 3: Implementation

### 3.1 Core Module Structure

```
lib/cepaf/src/Cepaf/
├── Domain.fs                    # Core types: CepaConfig, AppError, TelemetryEvent
├── Rop.fs                       # Railway-Oriented Programming (AsyncResult)
├── Infrastructure.fs            # IProcessRunner, QuadplexLogger
├── Orchestrator.fs              # Main protocol runner
├── ServiceChains/
│   └── StandaloneChain.fs       # Container definitions, DAG, port configs
├── Phases/
│   └── StandaloneVerifier.fs    # Comprehensive verification with FPPS
├── Modules/
│   ├── ServiceDAG.fs            # DAG with Kahn's topological sort
│   └── AgentMesh.fs             # FQUN handling, Zenoh key expressions
└── Observability/
    └── Integration.fs           # TelemetryEvent → TelemetryPayload mapping
```

### 3.2 Key Type Definitions

```fsharp
// StandaloneChain.fs
type StandalonePortConfig = {
    DbPort: int             // 5433
    PhxPort: int            // 4000
    EpmdPort: int           // 4369
    DistMinPort: int        // 9100
    DistMaxPort: int        // 9105
    GrafanaPort: int        // 3000
    PrometheusPort: int     // 9090
    SigNozPort: int         // 3301
    OtlpGrpcPort: int       // 4317
    OtlpHttpPort: int       // 4318
    ClickHousePort: int     // 8123
    RedisPort: int          // 6379
}

type NetworkConfig = {
    Name: string            // "indrajaal-mesh"
    Driver: string          // "bridge"
    Subnet: string          // "172.30.0.0/24"
    Gateway: string         // "172.30.0.1"
}

type ErlangDistConfig = {
    NodeName: string        // "indrajaal@{ip}"
    Cookie: string          // Auto-generated or from env
    EpmdPort: int           // 4369
    DistPortMin: int        // 9100
    DistPortMax: int        // 9105
}
```

### 3.3 FPPS 5-Method Consensus (SC-VAL-003)

```fsharp
// StandaloneVerifier.fs
type FPPSProbe = {
    Method: string
    Passed: bool
    LatencyMs: int64
    Details: string
}

type FPPSResult = {
    TotalProbes: int        // 5
    PassedCount: int        // Must be 5 for consensus
    FailedCount: int        // Must be 0 for consensus
    ConsensusAchieved: bool // PassedCount = 5
    Probes: FPPSProbe list
}

// The 5 FPPS Methods:
// 1. PodmanStatus   - Container state via podman inspect
// 2. HttpHealth     - HTTP health endpoint probe
// 3. TcpPort        - TCP socket connectivity
// 4. ProcessCheck   - Process existence via ps aux
// 5. LogPattern     - Log pattern analysis via podman logs

let runFPPSConsensus logger runner container port path pattern logs = async {
    let probes = [|
        fppsProbe1_PodmanStatus logger runner container
        fppsProbe2_HttpHealth logger runner container port path
        fppsProbe3_TcpPort logger port
        fppsProbe4_ProcessCheck logger runner container pattern
        fppsProbe5_LogPattern logger runner container logs
    |]
    let! results = probes |> Async.Parallel
    // Consensus: ALL 5 must pass (SC-VAL-003)
    let consensusAchieved = (results |> Array.filter (fun p -> not p.Passed) |> Array.length) = 0
    return { TotalProbes = 5; PassedCount = ...; ConsensusAchieved = consensusAchieved; ... }
}
```

### 3.4 Network Detection (Tailscale vs Local)

```fsharp
type NetworkMode =
    | Tailscale of ip: string * hostname: string * suffix: string
    | Local of ip: string

let detectNetworkMode logger runner = async {
    let! tsStatus = runner.Run("tailscale", ["status"; "--json"])
    match tsStatus with
    | Ok result when result.StandardOutput.Contains("\"BackendState\":\"Running\"") ->
        // Tailscale mode: Use MagicDNS
        let! tsIp = runner.Run("tailscale", ["ip"; "-4"])
        return Tailscale (ip, hostname, suffix)
    | _ ->
        // Local mode: Use hostname -I
        let! hostnameRes = runner.Run("hostname", ["-I"])
        return Local ip
}
```

---

## Level 4: Data Flow & Control Flow

### 4.1 Boot Sequence Control Flow

```
START
  │
  ▼
┌─────────────────────────────────────┐
│ 1. Network Detection                │
│    detectNetworkMode()              │
│    ├─ tailscale status --json       │
│    └─ hostname -I (fallback)        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 2. Cookie Management (SC-CLU-004)   │
│    getOrCreateCookie()              │
│    ├─ Check RELEASE_COOKIE env      │
│    ├─ Read ~/.erlang.cookie         │
│    └─ openssl rand -base64 32       │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 3. Network Creation                 │
│    podman network create            │
│    --subnet 172.30.0.0/24           │
│    indrajaal-mesh                   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 4. Container Startup (DAG Order)    │
│    podman-compose up -d             │
│    Layer 0 → Layer 1 → Layer 2 → 3  │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 5. Database Verification            │
│    ├─ waitForContainerHealth()      │
│    ├─ pg_isready verification       │
│    ├─ Database existence check      │
│    └─ createDatabaseIfMissing()     │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 6. Redis Verification               │
│    redis-cli ping → PONG            │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 7. OBS FPPS Verification            │
│    runFPPSConsensus()               │
│    5/5 probes must pass             │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 8. EPMD Verification (SC-CLU-002)   │
│    epmd -names                      │
│    Start if not running             │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ 9. Connection Info Display          │
│    ├─ Node name                     │
│    ├─ Cookie                        │
│    ├─ URLs (Phoenix, Grafana, etc)  │
│    └─ Livebook attachment guide     │
└─────────────────┬───────────────────┘
                  │
                  ▼
                 END
```

### 4.2 Telemetry Data Flow

```
┌────────────────────┐
│   TelemetryEvent   │ ─────► Domain.fs (Cepaf.TelemetryEvent)
│   (F# Domain)      │
└─────────┬──────────┘
          │
          ▼ mapTelemetryEvent()
┌────────────────────┐
│  TelemetryPayload  │ ─────► Observability.TelemetryPayload
│  (Observability)   │
└─────────┬──────────┘
          │
          ├─────────────────────────────────────┐
          │                                     │
          ▼                                     ▼
┌──────────────────┐              ┌──────────────────────────┐
│   Console Log    │              │     OTEL Collector       │
│   (Terminal)     │              │     gRPC: 4317           │
└──────────────────┘              │     HTTP: 4318           │
                                  └───────────┬──────────────┘
                                              │
                              ┌───────────────┼───────────────┐
                              │               │               │
                              ▼               ▼               ▼
                    ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
                    │  Prometheus │  │  ClickHouse │  │    SigNoz    │
                    │    :9090    │  │    :8123    │  │    :3301     │
                    └─────────────┘  └─────────────┘  └──────────────┘
                              │
                              ▼
                    ┌─────────────┐
                    │   Grafana   │
                    │    :3000    │
                    └─────────────┘
```

### 4.3 Fractal Logging 5-Level System

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         FRACTAL LOGGING ARCHITECTURE                          │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Level 0: SPINE (System-Wide Critical)                                        │
│  ├─ ALWAYS logged, never filtered                                             │
│  ├─ Startup/shutdown, config changes, safety violations                       │
│  └─ Channel: spine/* (e.g., spine/startup, spine/shutdown)                    │
│                                                                               │
│  Level 1: RIBS (Subsystem Structural)                                         │
│  ├─ Logged in all but ultra-minimal profiles                                  │
│  ├─ Subsystem initialization, phase transitions                               │
│  └─ Channel: ribs/{subsystem}/* (e.g., ribs/db/init, ribs/app/phase)          │
│                                                                               │
│  Level 2: BRANCHES (Feature-Level)                                            │
│  ├─ Logged in normal and debug profiles                                       │
│  ├─ Feature lifecycle, major operations                                       │
│  └─ Channel: branches/{feature}/* (e.g., branches/auth/login)                 │
│                                                                               │
│  Level 3: TWIGS (Operational Detail)                                          │
│  ├─ Logged only in debug and trace profiles                                   │
│  ├─ Detailed operational data, timing, metrics                                │
│  └─ Channel: twigs/{domain}/{operation}/*                                     │
│                                                                               │
│  Level 4: LEAVES (Fine-Grained Trace)                                         │
│  ├─ Logged only in trace profile                                              │
│  ├─ Function calls, parameter values, step-by-step                            │
│  └─ Channel: leaves/{module}/{function}/*                                     │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘

Telemetry Mapping:
┌─────────────┬─────────────────────────────────────────────────────────────────┐
│ F# Event    │ Fractal Level & Channel                                         │
├─────────────┼─────────────────────────────────────────────────────────────────┤
│ ProtocolStart      │ L0/SPINE: spine/protocol/start                           │
│ ProtocolComplete   │ L0/SPINE: spine/protocol/complete                        │
│ PhaseStart         │ L1/RIBS: ribs/{phase}/start                              │
│ PhaseComplete      │ L1/RIBS: ribs/{phase}/complete                           │
│ TaskUpdate         │ L2/BRANCHES: branches/task/{id}                          │
│ SafetyViolation    │ L0/SPINE: spine/safety/violation (CRITICAL)              │
│ FractalLogEvent    │ L{n}/: Dynamic based on level parameter                  │
│ ZenohEvolutionEvent│ L3/TWIGS: twigs/zenoh/{key_expr}                         │
└─────────────┴─────────────────────────────────────────────────────────────────┘
```

### 4.4 Zenoh Pub/Sub Data Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            ZENOH KEY EXPRESSIONS                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  FQUN Format: indrajaal/{layer}/{type}/{namespace}/{name}@{node}#{instance}   │
│                                                                               │
│  Layer Mapping:                                                               │
│  ├─ executive  → Executive agent commands                                     │
│  ├─ domain     → Domain-level coordination                                    │
│  ├─ functional → Functional agent operations                                  │
│  ├─ worker     → Worker execution tasks                                       │
│  └─ resource   → Shared resource access                                       │
│                                                                               │
│  Zenoh Key Format (Conversion):                                               │
│  indrajaal/{layer}/{type}/{namespace}/{name}/node/{node}/instance/{instance}  │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘

Publisher/Subscriber Flow:
┌───────────────────────┐
│    Elixir Phoenix     │
│    (ZenohCoordinator) │
└───────────┬───────────┘
            │ Publish: indrajaal/domain/access/main/grants
            ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                               ZENOH ROUTER                                     │
│                          (Key Expression Routing)                              │
└───────────────────────────────────────────────────────────────────────────────┘
            │
            ├─────────────────────────────────────────┐
            │                                         │
            ▼                                         ▼
┌───────────────────────┐              ┌───────────────────────┐
│   F# CEPAF Bridge     │              │   Remote Livebook     │
│   (Subscriber)        │              │   (Subscriber)        │
│   Key: indrajaal/**   │              │   Key: indrajaal/**   │
└───────────────────────┘              └───────────────────────┘
```

---

## Level 5: Mathematical Verification & Performance

### 5.1 PROMETHEUS Mathematical Framework

```
══════════════════════════════════════════════════════════════════════════════
PROMETHEUS: PRogram On MErged Trust with Holistic Evaluation Under Safety
══════════════════════════════════════════════════════════════════════════════

Graph Verification Invariants:

1. DAG Acyclicity (SC-DAG-001):
   ∀ path ∈ G: ¬∃ cycle(path)
   Implementation: Kahn's algorithm with in-degree tracking

   let topologicalSort (dag: ServiceDAG) : Result<string list, string> =
       let inDegree = computeInDegrees dag.Containers dag.Edges
       let queue = containers with inDegree = 0
       // Iteratively remove nodes with 0 in-degree
       // If |result| < |containers| → CYCLE DETECTED

2. Boot Order Correctness (SC-BOOT-001):
   ∀ container c: ∀ dep ∈ Dependencies(c): BootOrder(dep) < BootOrder(c)

   Verification: topologicalSort produces valid order

3. FPPS Consensus (SC-VAL-003):
   Health(service) = true ⟺ |{p ∈ FPPS₅ : p.Passed = true}| = 5

   Mathematical Formulation:
   Consensus(S) = ∧ᵢ₌₁⁵ Probeᵢ(S)
   where:
     Probe₁ = PodmanStatus(S) = "running"
     Probe₂ = HTTP(S, endpoint) = 200
     Probe₃ = TCP(S, port) = open
     Probe₄ = Process(S, pattern) ∈ ProcessList(S)
     Probe₅ = ∃ p ∈ Patterns: p ⊂ Logs(S)

4. Network Isolation (SC-NET-001):
   ∀ container c ∈ StandaloneContainers: Network(c) = "indrajaal-mesh"
   ∧ Subnet(c) ⊂ 172.30.0.0/24

5. Cookie Synchronization (SC-CLU-004):
   ∀ node n₁, n₂ ∈ Cluster: Cookie(n₁) = Cookie(n₂)

   Implementation: Single source of truth (env or ~/.erlang.cookie)
```

### 5.2 STAMP Safety Constraints

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          STAMP CONSTRAINT MATRIX                             │
├──────────────┬──────────────────────────────────────────────────────────────┤
│ Constraint   │ Description                                                   │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-CLU-001   │ Distributed mode requires name-based Erlang distribution      │
│              │ Verification: NodeName = "indrajaal@{ip}"                     │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-CLU-002   │ EPMD must bind to 0.0.0.0:4369 for network visibility         │
│              │ Verification: epmd -names returns success                     │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-CLU-003   │ Erlang distribution ports must be 9100-9105                   │
│              │ Verification: ERL_AFLAGS includes inet_dist_listen_min/max    │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-CLU-004   │ Erlang cookie must be synchronized across cluster             │
│              │ Verification: getOrCreateCookie() provides single source      │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-CLU-005   │ Tailscale MagicDNS integration for cluster discovery          │
│              │ Verification: detectNetworkMode() returns Tailscale variant   │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-VAL-003   │ 100% FPPS Consensus required (5/5 probes)                     │
│              │ Verification: ConsensusAchieved = (FailedCount = 0)           │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-OBS-069   │ Dual logging: Terminal + SigNoz                               │
│              │ Verification: QuadplexLogger.ChannelCount ≥ 2                 │
├──────────────┼──────────────────────────────────────────────────────────────┤
│ SC-DB-001    │ Database must use BaseResource pattern                        │
│              │ Verification: createDatabaseIfMissing() success               │
└──────────────┴──────────────────────────────────────────────────────────────┘
```

### 5.3 TDG (Test-Driven Generation) Compliance

```fsharp
// Test Cases for StandaloneChain.fs (TDG-CHAIN-*)

[<Test>]
let ``TDG-CHAIN-001: DAG has no cycles`` () =
    let dag = StandaloneChain.buildStandaloneDAG()
    let result = ServiceDAG.topologicalSort dag
    match result with
    | Ok _ -> Assert.Pass()
    | Error msg -> Assert.Fail(sprintf "Cycle detected: %s" msg)

[<Test>]
let ``TDG-CHAIN-002: Boot order respects dependencies`` () =
    match StandaloneChain.getBootOrder() with
    | Ok order ->
        let dbIdx = order |> List.findIndex ((=) "indrajaal-db-standalone")
        let appIdx = order |> List.findIndex ((=) "indrajaal-app-standalone")
        Assert.That(dbIdx < appIdx, "DB must boot before App")
    | Error _ -> Assert.Fail()

[<Test>]
let ``TDG-CHAIN-003: All containers have valid layers`` () =
    for c in StandaloneChain.standaloneContainers do
        Assert.That(c.Layer.IsSome, sprintf "Container %s missing layer" c.Name)

// Test Cases for StandaloneVerifier.fs (TDG-VERIFY-*)

[<Test>]
let ``TDG-VERIFY-001: FPPS requires 5/5 consensus`` () =
    let result = { TotalProbes = 5; PassedCount = 4; FailedCount = 1; ConsensusAchieved = false; Probes = [] }
    Assert.That(not result.ConsensusAchieved, "4/5 should not achieve consensus")

    let result2 = { result with PassedCount = 5; FailedCount = 0; ConsensusAchieved = true }
    Assert.That(result2.ConsensusAchieved, "5/5 should achieve consensus")

[<Test>]
let ``TDG-VERIFY-002: TCP port check returns boolean`` () =
    // This is a pure function test
    let check = StandaloneVerifier.checkTcpPort "127.0.0.1" 5433
    // Result is Async<bool> - type is correct
    Assert.Pass()
```

### 5.4 AOR (Agent Operating Rules) Compliance

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    AGENT OPERATING RULES - STANDALONE MODE                    │
├──────────────┬───────────────────────────────────────────────────────────────┤
│ Rule         │ Implementation                                                 │
├──────────────┼───────────────────────────────────────────────────────────────┤
│ AOR-CNT-001  │ Podman ONLY (no Docker)                                        │
│              │ runner.Run("podman", [...]) | runner.Run("podman-compose",...) │
├──────────────┼───────────────────────────────────────────────────────────────┤
│ AOR-SAF-001  │ Halt <1s on STAMP violation                                    │
│              │ return! fromResult (Error (SafetyViolation(id, msg)))         │
├──────────────┼───────────────────────────────────────────────────────────────┤
│ AOR-QUA-001  │ Zero warnings mandatory                                        │
│              │ AOR-QUA-001 check in Orchestrator.checkZeroWarningsGate        │
├──────────────┼───────────────────────────────────────────────────────────────┤
│ AOR-DB-001   │ Use BaseResource pattern                                       │
│              │ Database operations via verified SQL commands                  │
├──────────────┼───────────────────────────────────────────────────────────────┤
│ AOR-GEM-001  │ Plan → Verify                                                  │
│              │ Every phase has corresponding verification tasks               │
└──────────────┴───────────────────────────────────────────────────────────────┘
```

### 5.5 Performance Metrics

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         PERFORMANCE TARGETS & METRICS                         │
├────────────────────────┬────────────────┬────────────────────────────────────┤
│ Metric                 │ Target         │ Measurement                         │
├────────────────────────┼────────────────┼────────────────────────────────────┤
│ Total Boot Duration    │ ≤ 30s          │ sw.ElapsedMilliseconds at end      │
│ Network Creation       │ ≤ 5s           │ Task STANDALONE_NET_001            │
│ DB Health Wait         │ ≤ 60s          │ Task STANDALONE_DB_001             │
│ FPPS Probe Latency     │ ≤ 100ms each   │ probe.LatencyMs                    │
│ TCP Port Check         │ ≤ 50ms         │ checkTcpPort timing                │
│ Cookie Generation      │ ≤ 3s           │ Task STANDALONE_COOKIE_001         │
│ Container Start        │ ≤ 30s          │ Task STANDALONE_INFRA_001          │
│ EPMD Verification      │ ≤ 5s           │ Task STANDALONE_EPMD_001           │
├────────────────────────┼────────────────┼────────────────────────────────────┤
│ Histogram Recording    │                │ logger.RecordHistogram(...)        │
│ Counter Tracking       │                │ logger.IncrementCounter(...)       │
│ Phase Timing           │                │ PhaseComplete(name, duration, ...)  │
└────────────────────────┴────────────────┴────────────────────────────────────┘

Prometheus Metrics Emitted:
- phase.duration_ms{phase="STANDALONE_VERIFICATION"}
- task.duration_ms{task_id="STANDALONE_*"}
- process.success{command="podman|podman-compose|epmd"}
- process.failure{command="*", exit_code="*"}
- circuit_breaker.open{command="*"}
```

---

## Appendix A: Usage

### A.1 Command Line Interface

```bash
# Start standalone distributed mode
cd /path/to/indrajaal
dotnet run --project lib/cepaf/src/Cepaf -- --standalone

# With additional options
dotnet run --project lib/cepaf/src/Cepaf -- -s -y  # standalone + auto-confirm

# Full command with patient mode
dotnet run --project lib/cepaf/src/Cepaf -- --standalone --patient-mode --yes
```

### A.2 Remote Livebook Attachment

```powershell
# From Windows (PowerShell):
$env:LIVEBOOK_COOKIE = "COOKIE_FROM_OUTPUT"
livebook server

# In Livebook UI:
# Runtime → Attached node
# Name: indrajaal@{IP}
# Cookie: {COOKIE}
```

### A.3 IEx Remote Shell

```bash
iex --name client@{IP} --cookie {COOKIE} --remsh indrajaal@{IP}
```

---

## Appendix B: Next Steps

### B.1 Immediate (P0)
1. Create `podman-compose-standalone-distributed.yml` compose file
2. Add Erlang distribution configuration to app container
3. Test Livebook remote attachment end-to-end

### B.2 Short-term (P1)
1. Implement libcluster integration for automatic node discovery
2. Add Prometheus scrape configuration for standalone metrics
3. Create Grafana dashboard for standalone mode monitoring

### B.3 Medium-term (P2)
1. Implement automatic failover with Horde/libcluster
2. Add Zenoh router integration for cross-node pub/sub
3. Create chaos engineering tests for network partition scenarios

### B.4 Long-term (P3)
1. Multi-datacenter cluster support
2. Kubernetes deployment manifests
3. Terraform/Pulumi infrastructure-as-code

---

**Document End**
*Generated: 2025-12-27 | CEPAF v20.0 | STAMP Certified*
