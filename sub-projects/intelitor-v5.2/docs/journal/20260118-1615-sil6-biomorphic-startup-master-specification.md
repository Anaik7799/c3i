# SIL-6 BIOMORPHIC STARTUP MASTER SPECIFICATION
## Mathematical Analysis | Zenoh Messaging | Fractal Architecture | Full System Control

**Timestamp**: 2026-01-18T16:15:00Z
**Version**: 21.2.4-SIL6-MASTER
**Author**: Claude Opus 4.5
**Session**: Comprehensive 7-Level RCA + Mathematical Startup Specification
**STAMP Constraints**: SC-BOOT-001 to SC-BOOT-050
**AOR Rules**: AOR-BOOT-001 to AOR-BOOT-030

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [7-Level Root Cause Analysis](#2-7-level-root-cause-analysis)
3. [Mathematical Foundations](#3-mathematical-foundations)
4. [Centralized Configuration Architecture](#4-centralized-configuration-architecture)
5. [F# Orchestrator Design](#5-f-orchestrator-design)
6. [Zenoh Messaging Protocol](#6-zenoh-messaging-protocol)
7. [Finite State Automata](#7-finite-state-automata)
8. [STAMP/AOR/FMEA/TDG Specifications](#8-stamp-aor-fmea-tdg-specifications)
9. [10-Degree Fractal Interaction Analysis](#9-10-degree-fractal-interaction-analysis)
10. [BDD Test Specifications](#10-bdd-test-specifications)
11. [Implementation Roadmap](#11-implementation-roadmap)

---

## 1. EXECUTIVE SUMMARY

### 1.1 Objective
Create a **deterministic, robust, resilient, documented, and transactional** startup system for the SIL-6 Biomorphic Fractal Mesh with:
- **100% verifiable boot sequence** via Zenoh checkpoints
- **Mathematical guarantees** via DAG topological sorting and CPM analysis
- **Zero magic values** - all configuration centralized in F# modules
- **Fast feedback** (<100ms) via Zenoh pub/sub (not log parsing)
- **Transactional rollback** on any failure

### 1.2 Key Metrics

| Metric | Current | Target | Method |
|--------|---------|--------|--------|
| Boot Time | 60-120s | 25-35s | Pre-compiled BEAM + CPM optimization |
| Config Sources | 15+ files | 1 source | F# MeshConfig.fs (authoritative) |
| Feedback Latency | 5-30s (logs) | <100ms | Zenoh checkpoint messages |
| Test Coverage | 68 tests | 150+ tests | BDD + smoke tests per checkpoint |
| Rollback Capability | Manual | Automatic | Transactional boot phases |

### 1.3 Mathematical Techniques Applied

| Technique | Application | F# Implementation |
|-----------|-------------|-------------------|
| **Topological Sorting** | Dependency resolution | Kahn's Algorithm in DAG module |
| **Critical Path Method** | Boot time optimization | CPM.calculateCriticalPath() |
| **Finite State Automata** | Lifecycle correctness | DFA with 7 states |
| **RCPSP** | Resource-constrained scheduling | Max 4 concurrent containers |
| **Merkle Trees** | Configuration integrity | Hash verification on boot |
| **Queuing Theory** | Optimal concurrency | Little's Law for backpressure |
| **Hysteresis** | Health check stability | N consecutive checks required |
| **Railway Oriented Programming** | Error handling | Result<Success, Failure> pipeline |

---

## 2. 7-LEVEL ROOT CAUSE ANALYSIS

### 2.1 Analysis Summary

```
ROOT CAUSE HIERARCHY
═══════════════════════════════════════════════════════════════════════════════
L7_ARCHITECTURE:  Elixir compilation at boot (30-60s) - pre-compile in image
L6_DESIGN:        Two boot models (5-stage vs 7-gate) cause confusion
L5_SYSTEM:        appStartPeriod = 900s (15 min!) should be 60s
L4_MODULE:        500ms poll × 30 retries = 15s per container
L3_LOGIC:         Sequential wave blocking, migration gate in W2→W3
L2_LOCAL:         Wave 4 (App) takes 20s, DB health 50s worst case
L1_SYMPTOM:       Boot time 60-120s (target <60s)
═══════════════════════════════════════════════════════════════════════════════
```

### 2.2 Detailed 7-Level Analysis

#### L7: ARCHITECTURE LEVEL (Root Cause)
**Finding**: Elixir compilation happens inside containers at boot time (30-60s)
**Evidence**: `MIX_ENV=prod mix deps.get && mix compile` in container command
**Fix**: Pre-compile BEAM files into Docker image during build

```dockerfile
# BEFORE (compile at boot)
CMD ["sh", "-c", "mix compile && mix phx.server"]

# AFTER (pre-compiled)
RUN MIX_ENV=prod mix compile
CMD ["mix", "phx.server"]
```

#### L6: DESIGN LEVEL
**Finding**: Two incompatible boot models exist
**Evidence**:
- SIL6MeshOrchestrator: S0→S1→S2→S3→S4 (5 stages)
- ComprehensiveStartupOrchestrator: G0→G1→G2→G3→G4→G5→G6 (7 gates)

**Fix**: Unified boot model with 7 phases

```fsharp
type BootPhase =
    | P0_Preflight     // Environment validation, port cleanup
    | P1_Foundation    // DB + Observability
    | P2_ControlPlane  // Zenoh 2oo3 routers
    | P3_Cognitive     // CEPAF Bridge + Cortex
    | P4_Application   // Primary app node (seed)
    | P5_Homeostasis   // Health verification
    | P6_Swarm         // HA replicas + satellites
```

#### L5: SYSTEM LEVEL
**Finding**: Over-conservative timeout configurations
**Evidence**:
- `start_period: 900s` (15 minutes!) for app containers
- Health check retries: 30 × 500ms = 15s per container

**Fix**: Tune timeouts based on actual boot times

```yaml
# BEFORE
start_period: 900s
retries: 30
interval: 30s

# AFTER (based on CPM analysis)
start_period: 60s
retries: 10
interval: 5s
```

#### L4: MODULE LEVEL
**Finding**: No exponential backoff in health polling
**Evidence**: Fixed 500ms poll interval

**Fix**: Exponential backoff sequence

```fsharp
let backoffSequence = [100; 200; 400; 800; 1600; 3200; 5000] // ms
```

#### L3: LOGIC LEVEL
**Finding**: Sequential wave blocking
**Evidence**: Wave 3 waits for ALL of Wave 2, even independent containers

**Fix**: DAG-based parallel execution with early exit

```fsharp
// Early exit when 2oo3 quorum achieved (don't wait for all 3)
let quorumAchieved = healthyRouters >= 2
if quorumAchieved then proceedToWave3()
```

#### L2: LOCAL LEVEL
**Finding**: App wave (W4) takes 20s due to compilation
**Evidence**: Container logs show `Compiling 1497 files (.ex)`

**Fix**: Pre-compiled containers + parallel HA node boot

#### L1: SYMPTOM LEVEL
**Finding**: Total boot time 60-120s
**Target**: 25-35s after all optimizations

---

## 3. MATHEMATICAL FOUNDATIONS

### 3.1 Directed Acyclic Graph (DAG) for Dependency Resolution

#### 3.1.1 Container Dependency Graph

```
                    ┌─────────────────────────────────────────┐
                    │           DAG STARTUP GRAPH             │
                    │         (14 Containers, 7 Waves)        │
                    └─────────────────────────────────────────┘

Wave 0 (Preflight):
    ∅ → [Environment Validation]
        └── Verify ports clear: 4000, 5433, 4317, 7447-7449

Wave 1 (Foundation):
    ┌──────────────┐
    │  DB-PROD     │ ←── No dependencies (root node)
    │  Port: 5433  │
    └──────────────┘
           │
           ▼
Wave 2 (Control Plane) - PARALLEL:
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │ ZENOH-R1     │   │ ZENOH-R2     │   │ ZENOH-R3     │
    │ Port: 7447   │   │ Port: 7448   │   │ Port: 7449   │
    └──────────────┘   └──────────────┘   └──────────────┘
           │                 │                   │
           └────────┬────────┴───────────────────┘
                    │ (2oo3 quorum: 2 of 3 required)
           ┌────────▼────────┐
    ┌──────────────┐   ┌──────────────┐
    │ OBS-PROD     │   │ ZENOH-PROXY  │
    │ Ports: 4317..│   │ (depends_on  │
    └──────────────┘   │  R1,R2,R3)   │
           │           └──────────────┘
           ▼                   │
Wave 3 (Cognitive) - Sequential:     │
    ┌──────────────┐           │
    │ CEPAF-BRIDGE │ ◄─────────┘
    │ Port: 9876   │
    └──────────────┘
           │
           ▼
    ┌──────────────┐
    │ CORTEX       │
    │ Port: 9877   │
    └──────────────┘
           │
           ▼
Wave 4 (Application):
    ┌──────────────┐
    │ APP-1 (Seed) │ ←── Depends on: DB, OBS, ZENOH-PROXY
    │ Port: 4000   │
    └──────────────┘
           │
           ▼
Wave 5 (HA + Satellites) - PARALLEL:
    ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
    │ APP-2   │ │ APP-3   │ │ CHAYA   │ │ ML-RUN1 │ │ ML-RUN2 │
    │ (HA)    │ │ (HA)    │ │ (Twin)  │ │ (FLAME) │ │ (FLAME) │
    └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

#### 3.1.2 Kahn's Algorithm for Topological Sort

```fsharp
/// Kahn's Algorithm implementation for DAG topological sorting
/// Returns: Either<CycleDetected, TopologicalOrder>
module DAG =

    type Node = {
        Id: string
        Container: string
        Dependencies: string list
        EstimatedDuration: int // milliseconds
        Wave: int
        Criticality: Criticality
    }

    type Criticality = P0_Critical | P1_High | P2_Medium | P3_Low

    /// Topological sort using Kahn's algorithm
    /// Complexity: O(V + E) where V = nodes, E = edges
    let topologicalSort (nodes: Node list) : Result<Node list, string list> =
        let mutable inDegree = nodes |> List.map (fun n -> n.Id, n.Dependencies.Length) |> Map.ofList
        let mutable adjacency = nodes |> List.map (fun n -> n.Id, []) |> Map.ofList

        // Build adjacency list (reverse dependencies)
        for node in nodes do
            for dep in node.Dependencies do
                adjacency <- adjacency |> Map.add dep (node.Id :: (adjacency.[dep]))

        // Find all nodes with no dependencies (in-degree = 0)
        let mutable queue = nodes |> List.filter (fun n -> n.Dependencies.IsEmpty) |> List.map (_.Id)
        let mutable sorted = []

        while not queue.IsEmpty do
            let current = queue |> List.head
            queue <- queue |> List.tail
            sorted <- current :: sorted

            // For each dependent, reduce in-degree
            for dependent in adjacency.[current] do
                inDegree <- inDegree |> Map.add dependent (inDegree.[dependent] - 1)
                if inDegree.[dependent] = 0 then
                    queue <- dependent :: queue

        // Check for cycles
        if sorted.Length <> nodes.Length then
            let cycleNodes = nodes |> List.filter (fun n -> inDegree.[n.Id] > 0) |> List.map (_.Id)
            Error cycleNodes
        else
            Ok (sorted |> List.rev |> List.map (fun id -> nodes |> List.find (fun n -> n.Id = id)))

    /// Cycle detection using DFS
    let detectCycles (nodes: Node list) : string list option =
        let visited = System.Collections.Generic.HashSet<string>()
        let recStack = System.Collections.Generic.HashSet<string>()

        let rec dfs nodeId =
            if recStack.Contains nodeId then Some [nodeId]
            elif visited.Contains nodeId then None
            else
                visited.Add nodeId |> ignore
                recStack.Add nodeId |> ignore
                let node = nodes |> List.find (fun n -> n.Id = nodeId)
                let cycle = node.Dependencies |> List.tryPick dfs
                recStack.Remove nodeId |> ignore
                cycle

        nodes |> List.tryPick (fun n -> dfs n.Id)
```

### 3.2 Critical Path Method (CPM)

#### 3.2.1 CPM Calculation

```fsharp
/// Critical Path Method for boot time optimization
/// Identifies the longest path through the dependency graph
module CPM =

    type Task = {
        Id: string
        Duration: int // milliseconds
        EarliestStart: int
        EarliestFinish: int
        LatestStart: int
        LatestFinish: int
        Slack: int
        OnCriticalPath: bool
    }

    /// Calculate critical path
    /// Returns: Total duration, critical path nodes, slack analysis
    let calculateCriticalPath (nodes: DAG.Node list) : Task list * int =
        let sorted = DAG.topologicalSort nodes |> Result.defaultWith (fun _ -> [])

        // Forward pass - calculate earliest times
        let mutable earliest = Map.empty<string, int * int>
        for node in sorted do
            let maxPredFinish =
                if node.Dependencies.IsEmpty then 0
                else node.Dependencies |> List.map (fun d -> snd earliest.[d]) |> List.max
            let es = maxPredFinish
            let ef = es + node.EstimatedDuration
            earliest <- earliest |> Map.add node.Id (es, ef)

        let totalDuration = sorted |> List.map (fun n -> snd earliest.[n.Id]) |> List.max

        // Backward pass - calculate latest times
        let mutable latest = Map.empty<string, int * int>
        for node in sorted |> List.rev do
            let minSuccStart =
                let successors = sorted |> List.filter (fun n -> n.Dependencies |> List.contains node.Id)
                if successors.IsEmpty then totalDuration
                else successors |> List.map (fun s -> fst latest.[s.Id]) |> List.min
            let lf = minSuccStart
            let ls = lf - node.EstimatedDuration
            latest <- latest |> Map.add node.Id (ls, lf)

        // Calculate slack and identify critical path
        let tasks = sorted |> List.map (fun node ->
            let (es, ef) = earliest.[node.Id]
            let (ls, lf) = latest.[node.Id]
            let slack = ls - es
            {
                Id = node.Id
                Duration = node.EstimatedDuration
                EarliestStart = es
                EarliestFinish = ef
                LatestStart = ls
                LatestFinish = lf
                Slack = slack
                OnCriticalPath = slack = 0
            })

        (tasks, totalDuration)

    /// Display critical path analysis
    let printCriticalPathAnalysis (tasks: Task list) (totalDuration: int) =
        printfn "╔═══════════════════════════════════════════════════════════════════╗"
        printfn "║              CRITICAL PATH ANALYSIS                                ║"
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║ Container        │ Duration │ ES    │ EF    │ Slack │ Critical?  ║"
        printfn "╠══════════════════╪══════════╪═══════╪═══════╪═══════╪════════════╣"
        for task in tasks do
            let critical = if task.OnCriticalPath then "★ YES" else "  no"
            printfn "║ %-16s │ %6dms │ %5d │ %5d │ %5d │ %10s ║"
                task.Id task.Duration task.EarliestStart task.EarliestFinish task.Slack critical
        printfn "╠═══════════════════════════════════════════════════════════════════╣"
        printfn "║ TOTAL CRITICAL PATH DURATION: %d ms (%d seconds)                  ║"
            totalDuration (totalDuration / 1000)
        printfn "╚═══════════════════════════════════════════════════════════════════╝"
```

#### 3.2.2 Expected Critical Path (After Optimization)

```
CRITICAL PATH (Optimized):
═══════════════════════════════════════════════════════════════════════════════
DB-PROD:        5s  │ PostgreSQL startup + pg_isready
  ↓
OBS-PROD:       3s  │ OTEL + Prometheus (parallel with Zenoh)
  ↓
ZENOH-QUORUM:   2s  │ 2oo3 quorum achieved (early exit)
  ↓
CEPAF-BRIDGE:   2s  │ F# JSON-RPC bridge
  ↓
CORTEX:         2s  │ F# AI brain
  ↓
APP-1:          8s  │ Pre-compiled Phoenix (no mix compile)
  ↓
HOMEOSTASIS:    3s  │ Health verification
═══════════════════════════════════════════════════════════════════════════════
TOTAL:         25s  (vs 60-120s current)
```

### 3.3 Resource Constrained Project Scheduling (RCPSP)

```fsharp
/// Resource-constrained scheduling using Little's Law
/// L = λW where L = avg items, λ = arrival rate, W = service time
module RCPSP =

    type ResourceConstraints = {
        MaxConcurrentContainers: int  // Limit to prevent I/O saturation
        MaxCpuCores: int
        MaxMemoryMB: int
        MaxDiskIOPS: int
    }

    /// Default constraints based on typical dev machine
    let defaultConstraints = {
        MaxConcurrentContainers = 4  // Prevents I/O thundering herd
        MaxCpuCores = 16
        MaxMemoryMB = 32768  // 32GB
        MaxDiskIOPS = 10000
    }

    /// Schedule waves respecting resource constraints
    let scheduleWithConstraints (waves: DAG.Node list list) (constraints: ResourceConstraints) =
        waves |> List.mapi (fun waveIdx nodes ->
            // Apply concurrency limit per wave
            let batches = nodes |> List.chunkBySize constraints.MaxConcurrentContainers
            (waveIdx, batches))
```

### 3.4 Hysteresis for Health Check Stability

```fsharp
/// Hysteresis implementation to prevent health check flapping
/// A service must remain in state for N consecutive checks
module Hysteresis =

    type HealthState = Healthy | Unhealthy | Unknown

    type HysteresisConfig = {
        RequiredConsecutive: int  // N consecutive checks required
        CheckIntervalMs: int
        DebounceMs: int           // Ignore state changes within this window
    }

    let defaultConfig = {
        RequiredConsecutive = 3
        CheckIntervalMs = 1000
        DebounceMs = 500
    }

    type HysteresisState = {
        CurrentState: HealthState
        ConsecutiveCount: int
        LastChangeTime: System.DateTime
        History: HealthState list
    }

    /// Apply hysteresis to health check result
    /// Only changes state after N consecutive checks in new state
    let applyHysteresis (config: HysteresisConfig) (state: HysteresisState) (newCheck: HealthState) : HysteresisState =
        let now = System.DateTime.UtcNow

        // Check debounce window
        let timeSinceLastChange = (now - state.LastChangeTime).TotalMilliseconds
        if timeSinceLastChange < float config.DebounceMs then
            state // No change during debounce
        elif newCheck = state.CurrentState then
            // Same state, reset consecutive counter
            { state with ConsecutiveCount = config.RequiredConsecutive; History = newCheck :: state.History }
        elif state.ConsecutiveCount <= 1 then
            // Threshold reached, transition to new state
            { CurrentState = newCheck
              ConsecutiveCount = config.RequiredConsecutive
              LastChangeTime = now
              History = newCheck :: state.History }
        else
            // Not enough consecutive checks yet
            { state with
                ConsecutiveCount = state.ConsecutiveCount - 1
                History = newCheck :: state.History }
```

---

## 4. CENTRALIZED CONFIGURATION ARCHITECTURE

### 4.1 Single Source of Truth: MeshConfig.fs

```fsharp
/// AUTHORITATIVE CONFIGURATION SOURCE
/// ALL ports, IPs, timeouts, and resource limits MUST be defined here
/// SC-CONFIG-001: All configuration MUST be in single location
/// SC-CONFIG-002: No magic values allowed outside this module
namespace Cepaf.Config

[<RequireQualifiedAccess>]
module MeshConfig =

    // ═══════════════════════════════════════════════════════════════════════
    // PORTS (Single Source - SC-CONSOL-002)
    // ═══════════════════════════════════════════════════════════════════════

    module Ports =
        // Application
        let phoenix = 4000
        let health = 4001
        let chaya = 4002
        let haNode2 = 4003
        let haNode3 = 4005

        // Database
        let postgres = 5433

        // Redis
        let redis = 6379

        // Observability
        let otelGrpc = 4317
        let otelHttp = 4318
        let prometheus = 9090
        let grafana = 3000
        let loki = 3100
        let signozFrontend = 3301
        let signozQuery = 8080
        let signozAlert = 9093
        let clickhouseHttp = 8123
        let clickhouseNative = 9000

        // Zenoh Control Plane (2oo3)
        let zenohRouter1Tcp = 7447
        let zenohRouter1Ws = 8448
        let zenohRouter1Rest = 8000
        let zenohRouter2Tcp = 7448
        let zenohRouter2Ws = 8449
        let zenohRouter2Rest = 8001
        let zenohRouter3Tcp = 7449
        let zenohRouter3Ws = 8450
        let zenohRouter3Rest = 8002

        // Cognitive Plane
        let cepafBridge = 9876
        let cortex = 9877

    // ═══════════════════════════════════════════════════════════════════════
    // IP ADDRESSES (Mesh Network 172.28.0.0/16)
    // ═══════════════════════════════════════════════════════════════════════

    module IPs =
        let subnet = "172.28.0.0/16"
        let gateway = "172.28.0.1"

        // Application Tier
        let app1 = "172.28.0.10"
        let app2 = "172.28.0.11"
        let app3 = "172.28.0.12"

        // Database Tier
        let db = "172.28.0.20"

        // Observability Tier
        let obs = "172.28.0.30"

        // Zenoh Control Plane
        let zenohRouter1 = "172.28.0.40"
        let zenohRouter2 = "172.28.0.41"
        let zenohRouter3 = "172.28.0.42"
        let zenohProxy = "172.28.0.43"

        // Cognitive Plane
        let cepafBridge = "172.28.0.50"
        let cortex = "172.28.0.60"

        // Digital Twin
        let chaya = "172.28.0.70"

        // ML Runners
        let mlRunner1 = "172.28.0.80"
        let mlRunner2 = "172.28.0.81"

    // ═══════════════════════════════════════════════════════════════════════
    // TIMEOUTS (SC-OPT-007: Tuned based on CPM analysis)
    // ═══════════════════════════════════════════════════════════════════════

    module Timeouts =
        // Boot Phase Timeouts (milliseconds)
        let preflightTotal = 10_000
        let dbStartup = 15_000
        let obsStartup = 10_000
        let zenohQuorum = 10_000
        let cognitiveStartup = 10_000
        let appStartup = 30_000  // Reduced from 900s to 30s (pre-compiled)
        let homeostasis = 10_000
        let swarmStartup = 30_000

        // Health Check Configuration
        let healthCheckInterval = 1_000
        let healthCheckTimeout = 5_000
        let healthCheckRetries = 10
        let healthStartPeriod = 60_000  // 1 minute (not 15 minutes)

        // Exponential Backoff Sequence
        let backoffSequence = [100; 200; 400; 800; 1600; 3200; 5000]

        // OODA Loop
        let oodaCycleMax = 100  // 100ms max per SC-OODA-001

        // Graceful Shutdown
        let lameDuckDrain = 5_000
        let gracefulShutdown = 10_000

    // ═══════════════════════════════════════════════════════════════════════
    // RESOURCE LIMITS
    // ═══════════════════════════════════════════════════════════════════════

    module Resources =
        type ContainerResources = {
            MemoryMB: int
            CpuCores: float
        }

        let database = { MemoryMB = 4096; CpuCores = 4.0 }
        let observability = { MemoryMB = 10240; CpuCores = 6.0 }
        let app = { MemoryMB = 10240; CpuCores = 8.0 }
        let zenohRouter = { MemoryMB = 512; CpuCores = 1.0 }
        let cognitive = { MemoryMB = 1024; CpuCores = 2.0 }
        let mlRunner = { MemoryMB = 4096; CpuCores = 4.0 }

    // ═══════════════════════════════════════════════════════════════════════
    // CONTAINER DEFINITIONS (14 containers)
    // ═══════════════════════════════════════════════════════════════════════

    module Containers =
        type Container = {
            Id: string
            Name: string
            Wave: int
            Dependencies: string list
            Criticality: string
            Ports: int list
            IP: string
            Resources: Resources.ContainerResources
        }

        let all = [
            { Id = "DB"; Name = "indrajaal-db-prod"; Wave = 1; Dependencies = []; Criticality = "P0";
              Ports = [Ports.postgres]; IP = IPs.db; Resources = Resources.database }
            { Id = "OBS"; Name = "indrajaal-obs-prod"; Wave = 2; Dependencies = ["DB"]; Criticality = "P1";
              Ports = [Ports.otelGrpc; Ports.prometheus; Ports.grafana; Ports.loki]; IP = IPs.obs; Resources = Resources.observability }
            { Id = "ZEN1"; Name = "zenoh-router-1"; Wave = 2; Dependencies = []; Criticality = "P0";
              Ports = [Ports.zenohRouter1Tcp]; IP = IPs.zenohRouter1; Resources = Resources.zenohRouter }
            { Id = "ZEN2"; Name = "zenoh-router-2"; Wave = 2; Dependencies = []; Criticality = "P0";
              Ports = [Ports.zenohRouter2Tcp]; IP = IPs.zenohRouter2; Resources = Resources.zenohRouter }
            { Id = "ZEN3"; Name = "zenoh-router-3"; Wave = 2; Dependencies = []; Criticality = "P0";
              Ports = [Ports.zenohRouter3Tcp]; IP = IPs.zenohRouter3; Resources = Resources.zenohRouter }
            { Id = "ZENPROXY"; Name = "zenoh-router"; Wave = 2; Dependencies = ["ZEN1"; "ZEN2"; "ZEN3"]; Criticality = "P0";
              Ports = []; IP = IPs.zenohProxy; Resources = Resources.zenohRouter }
            { Id = "BRIDGE"; Name = "cepaf-bridge"; Wave = 3; Dependencies = ["ZENPROXY"]; Criticality = "P1";
              Ports = [Ports.cepafBridge]; IP = IPs.cepafBridge; Resources = Resources.cognitive }
            { Id = "CORTEX"; Name = "indrajaal-cortex"; Wave = 3; Dependencies = ["ZENPROXY"; "BRIDGE"]; Criticality = "P1";
              Ports = [Ports.cortex]; IP = IPs.cortex; Resources = Resources.cognitive }
            { Id = "APP1"; Name = "indrajaal-ex-app-1"; Wave = 4; Dependencies = ["DB"; "OBS"; "ZENPROXY"]; Criticality = "P0";
              Ports = [Ports.phoenix; Ports.health; Ports.redis]; IP = IPs.app1; Resources = Resources.app }
            { Id = "APP2"; Name = "indrajaal-ex-app-2"; Wave = 5; Dependencies = ["APP1"]; Criticality = "P1";
              Ports = [Ports.haNode2]; IP = IPs.app2; Resources = Resources.app }
            { Id = "APP3"; Name = "indrajaal-ex-app-3"; Wave = 5; Dependencies = ["APP2"]; Criticality = "P1";
              Ports = [Ports.haNode3]; IP = IPs.app3; Resources = Resources.app }
            { Id = "CHAYA"; Name = "indrajaal-chaya"; Wave = 5; Dependencies = ["APP1"; "ZENPROXY"]; Criticality = "P2";
              Ports = [Ports.chaya]; IP = IPs.chaya; Resources = Resources.app }
            { Id = "ML1"; Name = "indrajaal-ml-runner-1"; Wave = 5; Dependencies = ["APP1"]; Criticality = "P2";
              Ports = []; IP = IPs.mlRunner1; Resources = Resources.mlRunner }
            { Id = "ML2"; Name = "indrajaal-ml-runner-2"; Wave = 5; Dependencies = ["ML1"]; Criticality = "P2";
              Ports = []; IP = IPs.mlRunner2; Resources = Resources.mlRunner }
        ]

        let byWave wave = all |> List.filter (fun c -> c.Wave = wave)
        let byId id = all |> List.find (fun c -> c.Id = id)
```

### 4.2 Configuration Validation at Boot

```fsharp
/// Configuration validation - MUST pass before boot proceeds
/// SC-CONSOL-005: Config validation MUST run at boot
module ConfigValidation =

    type ValidationResult =
        | Valid
        | Invalid of string list

    /// Validate all configuration at startup
    let validateAll () : ValidationResult =
        let errors = ResizeArray<string>()

        // Check port uniqueness
        let allPorts = [
            MeshConfig.Ports.phoenix; MeshConfig.Ports.health; MeshConfig.Ports.chaya
            MeshConfig.Ports.postgres; MeshConfig.Ports.redis
            MeshConfig.Ports.otelGrpc; MeshConfig.Ports.prometheus
            MeshConfig.Ports.zenohRouter1Tcp; MeshConfig.Ports.zenohRouter2Tcp; MeshConfig.Ports.zenohRouter3Tcp
            MeshConfig.Ports.cepafBridge; MeshConfig.Ports.cortex
        ]
        let duplicates = allPorts |> List.groupBy id |> List.filter (fun (_, g) -> g.Length > 1)
        if not duplicates.IsEmpty then
            errors.Add $"Duplicate ports detected: {duplicates |> List.map fst}"

        // Check IP uniqueness
        let allIPs = [
            MeshConfig.IPs.app1; MeshConfig.IPs.app2; MeshConfig.IPs.app3
            MeshConfig.IPs.db; MeshConfig.IPs.obs
            MeshConfig.IPs.zenohRouter1; MeshConfig.IPs.zenohRouter2; MeshConfig.IPs.zenohRouter3
            MeshConfig.IPs.cepafBridge; MeshConfig.IPs.cortex
            MeshConfig.IPs.chaya; MeshConfig.IPs.mlRunner1; MeshConfig.IPs.mlRunner2
        ]
        let ipDuplicates = allIPs |> List.groupBy id |> List.filter (fun (_, g) -> g.Length > 1)
        if not ipDuplicates.IsEmpty then
            errors.Add $"Duplicate IPs detected: {ipDuplicates |> List.map fst}"

        // Check timeout sanity
        if MeshConfig.Timeouts.appStartup > 120_000 then
            errors.Add "App startup timeout > 2 minutes - use pre-compiled containers"

        if MeshConfig.Timeouts.healthCheckInterval < 100 then
            errors.Add "Health check interval < 100ms - too aggressive"

        // Validate DAG acyclicity
        match DAG.detectCycles (MeshConfig.Containers.all |> List.map (fun c ->
            { DAG.Node.Id = c.Id; Container = c.Name; Dependencies = c.Dependencies;
              EstimatedDuration = 0; Wave = c.Wave; Criticality = DAG.P0_Critical })) with
        | Some cycle -> errors.Add $"Dependency cycle detected: {cycle}"
        | None -> ()

        if errors.Count = 0 then Valid
        else Invalid (errors |> Seq.toList)
```

---

## 5. F# ORCHESTRATOR DESIGN

### 5.1 Railway Oriented Programming (ROP)

```fsharp
/// Railway Oriented Programming for clean error handling
/// Success track: continues through pipeline
/// Failure track: short-circuits with error details
module Railway =

    type Result<'TSuccess, 'TFailure> =
        | Success of 'TSuccess
        | Failure of 'TFailure

    /// Bind operator (>>=)
    let bind f result =
        match result with
        | Success s -> f s
        | Failure e -> Failure e

    /// Map operator (<!>)
    let map f result =
        match result with
        | Success s -> Success (f s)
        | Failure e -> Failure e

    /// Apply Railway to startup pipeline
    let (>>=) = bind

    /// Startup pipeline using ROP
    let startupPipeline () =
        validateConfig ()
        >>= checkPortsAvailable
        >>= startWave1_Foundation
        >>= startWave2_ControlPlane
        >>= verifyZenohQuorum
        >>= startWave3_Cognitive
        >>= startWave4_Application
        >>= verifyHealth
        >>= startWave5_Swarm
        >>= publishBootComplete
```

### 5.2 Idempotent Operations

```fsharp
/// All operations MUST be idempotent
/// f(x) = f(f(x)) - running twice has same effect as once
module Idempotent =

    /// Ensure container is running (idempotent)
    /// GOOD: Checks first, starts only if needed
    let ensureContainerRunning (name: string) =
        match getContainerStatus name with
        | Running -> Success $"{name} already running"
        | Stopped -> startContainer name
        | NotFound -> createAndStartContainer name

    /// BAD: Non-idempotent (would fail if already running)
    // let startContainer name = execSync $"podman start {name}"

    /// Ensure port is available (idempotent)
    let ensurePortAvailable (port: int) =
        let processes = getProcessesOnPort port
        if processes.IsEmpty then
            Success $"Port {port} available"
        else
            for pid in processes do
                killProcess pid
            Success $"Port {port} cleared"
```

---

## 6. ZENOH MESSAGING PROTOCOL

### 6.1 Checkpoint Message Schema

```fsharp
/// Zenoh checkpoint messages for boot sequence
/// SC-ZTEST-003: Publish latency < 10ms per message
module ZenohCheckpoints =

    type CheckpointType =
        | BootPhaseStart
        | BootPhaseComplete
        | ContainerStarted
        | ContainerHealthy
        | QuorumAchieved
        | StateVectorUpdate
        | BootComplete
        | BootFailed

    type CheckpointMessage = {
        Type: CheckpointType
        CheckpointId: string          // e.g., "CP-BOOT-05"
        Phase: int                     // 0-6
        Timestamp: System.DateTime
        Container: string option
        Details: Map<string, string>
        StateVector: int list         // [1,1,1,0,0,0,0] for phases 0-6
        DurationMs: int option
    }

    /// Topic patterns for boot checkpoints
    module Topics =
        let bootPhaseStart phase = $"indrajaal/boot/phase/{phase}/start"
        let bootPhaseComplete phase = $"indrajaal/boot/phase/{phase}/complete"
        let containerStarted name = $"indrajaal/boot/container/{name}/started"
        let containerHealthy name = $"indrajaal/boot/container/{name}/healthy"
        let quorumStatus = "indrajaal/boot/zenoh/quorum"
        let stateVector = "indrajaal/boot/state_vector"
        let bootComplete = "indrajaal/boot/complete"
        let bootFailed = "indrajaal/boot/failed"

    /// Publish checkpoint via Zenoh
    let publishCheckpoint (session: ZenohSession) (msg: CheckpointMessage) =
        let topic =
            match msg.Type with
            | BootPhaseStart -> Topics.bootPhaseStart msg.Phase
            | BootPhaseComplete -> Topics.bootPhaseComplete msg.Phase
            | ContainerStarted -> Topics.containerStarted (msg.Container |> Option.defaultValue "unknown")
            | ContainerHealthy -> Topics.containerHealthy (msg.Container |> Option.defaultValue "unknown")
            | QuorumAchieved -> Topics.quorumStatus
            | StateVectorUpdate -> Topics.stateVector
            | BootComplete -> Topics.bootComplete
            | BootFailed -> Topics.bootFailed

        let payload = System.Text.Json.JsonSerializer.Serialize(msg)
        session.Publish(topic, payload)
```

### 6.2 State Vector Updates

```fsharp
/// State vector for boot progress tracking
/// Format: [P0, P1, P2, P3, P4, P5, P6] where 0=pending, 1=running, 2=complete, 3=failed
module StateVector =

    type PhaseState = Pending | Running | Complete | Failed

    type BootStateVector = {
        Phases: PhaseState array  // 7 phases
        Containers: Map<string, PhaseState>
        QuorumStatus: int * int   // (healthy, total)
        OverallHealth: float      // 0.0 - 1.0
        BootStartTime: System.DateTime
        LastUpdateTime: System.DateTime
    }

    let initial () = {
        Phases = Array.create 7 Pending
        Containers = Map.empty
        QuorumStatus = (0, 3)
        OverallHealth = 0.0
        BootStartTime = System.DateTime.UtcNow
        LastUpdateTime = System.DateTime.UtcNow
    }

    let updatePhase (phase: int) (state: PhaseState) (vector: BootStateVector) =
        let newPhases = vector.Phases |> Array.mapi (fun i s -> if i = phase then state else s)
        let health = float (newPhases |> Array.filter (fun s -> s = Complete) |> Array.length) / 7.0
        { vector with
            Phases = newPhases
            OverallHealth = health
            LastUpdateTime = System.DateTime.UtcNow }

    let toIntArray (vector: BootStateVector) =
        vector.Phases |> Array.map (function
            | Pending -> 0
            | Running -> 1
            | Complete -> 2
            | Failed -> 3)
```

### 6.3 Boot Checkpoint IDs

| Checkpoint ID | Phase | Trigger | Zenoh Topic |
|--------------|-------|---------|-------------|
| CP-BOOT-01 | P0 | Preflight start | `indrajaal/boot/phase/0/start` |
| CP-BOOT-02 | P0 | DAG validated | `indrajaal/boot/dag/validated` |
| CP-BOOT-03 | P1 | DB healthy | `indrajaal/boot/container/indrajaal-db-prod/healthy` |
| CP-BOOT-04 | P1 | OBS healthy | `indrajaal/boot/container/indrajaal-obs-prod/healthy` |
| CP-BOOT-05 | P2 | Zenoh 2oo3 quorum | `indrajaal/boot/zenoh/quorum` |
| CP-BOOT-06 | P3 | Bridge healthy | `indrajaal/boot/container/cepaf-bridge/healthy` |
| CP-BOOT-07 | P3 | Cortex healthy | `indrajaal/boot/container/indrajaal-cortex/healthy` |
| CP-BOOT-08 | P4 | App-1 healthy | `indrajaal/boot/container/indrajaal-ex-app-1/healthy` |
| CP-BOOT-09 | P5 | Homeostasis verified | `indrajaal/boot/phase/5/complete` |
| CP-BOOT-10 | P6 | All swarm nodes healthy | `indrajaal/boot/complete` |

---

## 7. FINITE STATE AUTOMATA

### 7.1 Container Lifecycle DFA

```fsharp
/// Deterministic Finite Automaton for container lifecycle
/// Prevents invalid state transitions
module ContainerFSM =

    /// Container states (Q)
    type ContainerState =
        | NotFound      // q0 - initial
        | Created       // q1
        | Starting      // q2
        | Running       // q3
        | Healthy       // q4 - accepting
        | Unhealthy     // q5
        | Stopping      // q6
        | Stopped       // q7
        | Failed        // q8 - error state

    /// Input signals (Σ)
    type Signal =
        | Create
        | Start
        | HealthOk
        | HealthFail
        | Stop
        | Remove
        | Crash
        | Timeout

    /// Transition function (δ)
    let transition (state: ContainerState) (signal: Signal) : ContainerState =
        match state, signal with
        // From NotFound
        | NotFound, Create -> Created
        | NotFound, _ -> NotFound

        // From Created
        | Created, Start -> Starting
        | Created, Remove -> NotFound
        | Created, _ -> Created

        // From Starting
        | Starting, HealthOk -> Running
        | Starting, Timeout -> Failed
        | Starting, Crash -> Failed
        | Starting, _ -> Starting

        // From Running
        | Running, HealthOk -> Healthy
        | Running, HealthFail -> Unhealthy
        | Running, Stop -> Stopping
        | Running, Crash -> Failed
        | Running, _ -> Running

        // From Healthy (accepting state)
        | Healthy, HealthFail -> Unhealthy
        | Healthy, Stop -> Stopping
        | Healthy, Crash -> Failed
        | Healthy, _ -> Healthy

        // From Unhealthy
        | Unhealthy, HealthOk -> Healthy
        | Unhealthy, Stop -> Stopping
        | Unhealthy, Crash -> Failed
        | Unhealthy, Timeout -> Failed
        | Unhealthy, _ -> Unhealthy

        // From Stopping
        | Stopping, Stop -> Stopped
        | Stopping, Crash -> Stopped
        | Stopping, Timeout -> Stopped
        | Stopping, _ -> Stopping

        // From Stopped
        | Stopped, Start -> Starting
        | Stopped, Remove -> NotFound
        | Stopped, _ -> Stopped

        // From Failed (error state)
        | Failed, Remove -> NotFound
        | Failed, Start -> Starting  // Allow retry
        | Failed, _ -> Failed

    /// Check if state is accepting (healthy)
    let isAccepting state = state = Healthy

    /// Check if state is error
    let isError state = state = Failed

    /// Validate transition is legal
    let validateTransition current signal =
        let next = transition current signal
        if next = current && signal <> HealthOk then
            Error $"Invalid transition from {current} with signal {signal}"
        else
            Ok next
```

### 7.2 Boot Phase State Machine

```
BOOT PHASE STATE MACHINE
═══════════════════════════════════════════════════════════════════════════════

     ┌───────────────────────────────────────────────────────────────┐
     │                                                               │
     ▼                                                               │
 ┌────────┐   validate   ┌────────┐   db+obs   ┌────────┐           │
 │   P0   │ ──────────▶  │   P1   │ ────────▶  │   P2   │           │
 │Preflt  │   success    │ Found  │  healthy   │CtrlPln │           │
 └────────┘              └────────┘            └────────┘           │
     │                        │                     │               │
     │ fail                   │ timeout             │ quorum        │
     ▼                        ▼                     ▼               │
 ┌────────┐              ┌────────┐           ┌────────┐   bridge   │
 │ FAILED │ ◄────────────│ FAILED │◄──────────│   P3   │ ──────────▶│
 └────────┘              └────────┘           │Cognit  │  +cortex   │
                                              └────────┘            │
                                                   │                │
                                                   │ healthy        │
                                                   ▼                │
                                              ┌────────┐            │
                                              │   P4   │ ──────────▶│
                                              │  App   │  app1 up   │
                                              └────────┘            │
                                                   │                │
                                                   │ verify         │
                                                   ▼                │
                                              ┌────────┐            │
                                              │   P5   │ ──────────▶│
                                              │ Homeo  │   pass     │
                                              └────────┘            │
                                                   │                │
                                                   │ swarm          │
                                                   ▼                │
                                              ┌────────┐            │
                                              │   P6   │────────────┘
                                              │ Swarm  │   all up
                                              └────────┘
                                                   │
                                                   │ complete
                                                   ▼
                                              ┌────────┐
                                              │ READY  │ (Accepting State)
                                              └────────┘
```

---

## 8. STAMP/AOR/FMEA/TDG SPECIFICATIONS

### 8.1 STAMP Constraints (SC-BOOT-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-BOOT-001 | Boot MUST complete in < 60s | CRITICAL | `time sa-up` < 60 |
| SC-BOOT-002 | DAG validation MUST precede any container start | CRITICAL | Checkpoint CP-BOOT-02 |
| SC-BOOT-003 | Zenoh 2oo3 quorum MUST be achieved before P3 | CRITICAL | Checkpoint CP-BOOT-05 |
| SC-BOOT-004 | All config MUST come from MeshConfig.fs | CRITICAL | Code scan for hardcoded values |
| SC-BOOT-005 | Config validation MUST pass before boot | CRITICAL | ConfigValidation.validateAll() |
| SC-BOOT-006 | State vector MUST be published via Zenoh every 1s | HIGH | Zenoh subscription |
| SC-BOOT-007 | Health checks MUST use exponential backoff | HIGH | Code review |
| SC-BOOT-008 | Hysteresis MUST prevent health flapping | HIGH | 3 consecutive checks |
| SC-BOOT-009 | Container FSM transitions MUST be validated | HIGH | validateTransition() |
| SC-BOOT-010 | Boot MUST be idempotent (re-runnable) | HIGH | Test: run sa-up twice |
| SC-BOOT-011 | Failed boot MUST trigger automatic rollback | CRITICAL | Rollback on P<N> failure |
| SC-BOOT-012 | All ports MUST be verified clear before boot | HIGH | Preflight check |
| SC-BOOT-013 | Pre-compiled BEAM MUST be in container image | CRITICAL | Dockerfile check |
| SC-BOOT-014 | No log parsing for boot status (Zenoh only) | MEDIUM | Code review |
| SC-BOOT-015 | Boot metrics MUST be recorded in DuckDB | MEDIUM | Telemetry query |

### 8.2 AOR Rules (AOR-BOOT-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-BOOT-001 | VALIDATE config before any boot operation | Pre-boot hook |
| AOR-BOOT-002 | PUBLISH checkpoint at each phase transition | Zenoh message |
| AOR-BOOT-003 | VERIFY DAG acyclicity before wave execution | Kahn's algorithm |
| AOR-BOOT-004 | USE exponential backoff for health polling | Backoff sequence |
| AOR-BOOT-005 | APPLY hysteresis to health state changes | 3 consecutive |
| AOR-BOOT-006 | ROLLBACK on phase failure (transactional) | Auto-rollback |
| AOR-BOOT-007 | RECORD boot duration for CPM analysis | Telemetry |
| AOR-BOOT-008 | SUBSCRIBE to boot checkpoints for monitoring | Zenoh subscriber |
| AOR-BOOT-009 | NEVER hardcode ports/IPs outside MeshConfig | Code scan |
| AOR-BOOT-010 | ALWAYS use idempotent operations | ensureXxx pattern |

### 8.3 FMEA Analysis

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| DB fails to start | 9 | 2 | 9 | 162 | Retry with backoff, pg_isready check |
| Zenoh quorum not achieved | 9 | 3 | 8 | 216 | 2oo3 voting, 10s timeout |
| App compilation timeout | 8 | 4 | 7 | 224 | Pre-compiled BEAM in image |
| Port conflict | 7 | 3 | 9 | 189 | Preflight port scan |
| Health check flapping | 6 | 5 | 6 | 180 | Hysteresis (3 consecutive) |
| DAG cycle | 9 | 1 | 10 | 90 | Static validation |
| Config mismatch | 7 | 4 | 5 | 140 | Hash verification |
| Network partition | 8 | 2 | 6 | 96 | Zenoh mesh redundancy |
| Container crash loop | 8 | 3 | 7 | 168 | Max restart count |
| Resource exhaustion | 7 | 2 | 5 | 70 | RCPSP constraints |

### 8.4 TDG (Test-Driven Generation) Specifications

```fsharp
/// Property-based tests for boot sequence
module BootTests =
    open FsCheck

    /// Property: Boot is idempotent
    let ``boot twice has same effect as once`` () =
        let state1 = boot() |> getState
        let state2 = boot() |> getState
        state1 = state2

    /// Property: DAG topological sort is valid
    let ``topological sort respects dependencies`` (nodes: Node list) =
        match DAG.topologicalSort nodes with
        | Ok sorted ->
            sorted |> List.forall (fun node ->
                let nodeIndex = sorted |> List.findIndex ((=) node)
                node.Dependencies |> List.forall (fun dep ->
                    let depIndex = sorted |> List.findIndex (fun n -> n.Id = dep)
                    depIndex < nodeIndex))
        | Error _ -> true  // Cycles are valid to detect

    /// Property: Health check with hysteresis is stable
    let ``hysteresis prevents flapping`` (checks: HealthState list) =
        let config = { RequiredConsecutive = 3; CheckIntervalMs = 100; DebounceMs = 50 }
        let finalState =
            checks |> List.fold (Hysteresis.applyHysteresis config) (Hysteresis.initial Healthy)
        // Count state changes should be <= checks.Length / 3
        let stateChanges = finalState.History |> List.pairwise |> List.filter (fun (a, b) -> a <> b) |> List.length
        stateChanges <= (checks.Length / 3 + 1)
```

---

## 9. 10-DEGREE FRACTAL INTERACTION ANALYSIS

### 9.1 Interaction Matrix (7 Levels × 10 Degrees)

| Degree | L1 Signal | L2 Local | L3 Logic | L4 Module | L5 System | L6 Design | L7 Arch |
|--------|-----------|----------|----------|-----------|-----------|-----------|---------|
| **D1: Immediate** | Port probe | Container status | FSM state | Health check | Boot phase | Wave execution | Mesh state |
| **D2: Adjacent** | Neighbor ports | Related containers | Dependent FSMs | Module deps | Phase deps | Wave deps | Cluster deps |
| **D3: Cascading** | Port chain | Container chain | State cascade | Module cascade | Phase cascade | Wave cascade | Cluster cascade |
| **D4: Temporal** | Probe timing | Startup timing | State duration | Module latency | Phase timing | Wave timing | Boot duration |
| **D5: Resource** | Port allocation | Container resources | State memory | Module memory | Phase CPU | Wave I/O | Cluster resources |
| **D6: Error** | Port conflict | Container failure | Invalid state | Module error | Phase failure | Wave failure | Boot failure |
| **D7: Recovery** | Port retry | Container restart | State rollback | Module recovery | Phase rollback | Wave rollback | Boot rollback |
| **D8: Monitoring** | Port metrics | Container metrics | State telemetry | Module telemetry | Phase metrics | Wave metrics | Boot metrics |
| **D9: Evolution** | Port migration | Container upgrade | State evolution | Module evolution | Phase evolution | Wave evolution | Arch evolution |
| **D10: Federation** | Port federation | Container federation | State sync | Module sync | Phase sync | Wave sync | Cluster federation |

### 9.2 Full Fractal Analysis (7 × 7 × 10)

```
FRACTAL DIMENSION ANALYSIS
═══════════════════════════════════════════════════════════════════════════════

L7 (Architecture) × D1-D10:
├── D1 (Immediate):  Full mesh state assessment (14 containers, 3 routers)
├── D2 (Adjacent):   Cluster dependencies (app nodes ↔ Zenoh ↔ DB)
├── D3 (Cascading):  Wave propagation (W1→W2→W3→W4→W5→W6)
├── D4 (Temporal):   Critical path duration (25-35s target)
├── D5 (Resource):   Total resource allocation (27GB RAM, 23 CPUs)
├── D6 (Error):      Boot failure modes (9 identified, RPN calculated)
├── D7 (Recovery):   Transactional rollback (per-wave checkpoints)
├── D8 (Monitoring): Zenoh telemetry (10 checkpoint topics)
├── D9 (Evolution):  Pre-compiled images, config consolidation
└── D10 (Federation): Multi-cluster sync (future: Tailscale mesh)

L6 (Design) × D1-D10:
├── D1 (Immediate):  Wave execution status (5 waves + preflight)
├── D2 (Adjacent):   Wave dependencies (W2 needs W1 DB, W3 needs W2 quorum)
├── D3 (Cascading):  Wave completion cascade (early exit on quorum)
├── D4 (Temporal):   Wave timing (W1: 5s, W2: 10s, W3: 4s, W4: 8s, W5: 5s)
├── D5 (Resource):   Wave concurrency (max 4 per RCPSP)
├── D6 (Error):      Wave failure handling (rollback to previous wave)
├── D7 (Recovery):   Wave rollback (container cleanup, port release)
├── D8 (Monitoring): Wave metrics (duration, container count, health)
├── D9 (Evolution):  Unified boot model (7 phases replacing 3 variants)
└── D10 (Federation): Wave sync across clusters

L5 (System) × D1-D10:
├── D1 (Immediate):  Phase status (P0-P6 state vector)
├── D2 (Adjacent):   Phase dependencies (P3 needs P2 quorum)
├── D3 (Cascading):  Phase completion triggers next phase
├── D4 (Temporal):   Phase timeouts (tuned from 900s to 60s)
├── D5 (Resource):   Phase resource allocation (memory limits)
├── D6 (Error):      Phase failure (auto-rollback, checkpoint restore)
├── D7 (Recovery):   Phase rollback (containers in phase stopped)
├── D8 (Monitoring): Phase telemetry (Zenoh checkpoints CP-BOOT-*)
├── D9 (Evolution):  Phase optimization (CPM critical path)
└── D10 (Federation): Phase sync across nodes

L4 (Module) × D1-D10:
├── D1 (Immediate):  Module health check result
├── D2 (Adjacent):   Module dependencies (FSM transitions)
├── D3 (Cascading):  Module dependency resolution (DAG sort)
├── D4 (Temporal):   Module latency (exponential backoff)
├── D5 (Resource):   Module memory/CPU allocation
├── D6 (Error):      Module error handling (ROP pipeline)
├── D7 (Recovery):   Module restart/retry logic
├── D8 (Monitoring): Module telemetry (function-level)
├── D9 (Evolution):  Module consolidation (Mesh.Core.fs)
└── D10 (Federation): Module replication

L3 (Logic) × D1-D10:
├── D1 (Immediate):  FSM current state
├── D2 (Adjacent):   FSM state transitions
├── D3 (Cascading):  FSM state chain (NotFound→Created→Starting→Healthy)
├── D4 (Temporal):   FSM state duration (hysteresis)
├── D5 (Resource):   FSM memory (state history)
├── D6 (Error):      FSM error state (Failed)
├── D7 (Recovery):   FSM recovery (restart from Stopped)
├── D8 (Monitoring): FSM telemetry (state changes)
├── D9 (Evolution):  FSM simplification
└── D10 (Federation): FSM sync across nodes

L2 (Local) × D1-D10:
├── D1 (Immediate):  Container status (podman inspect)
├── D2 (Adjacent):   Container dependencies (compose depends_on)
├── D3 (Cascading):  Container startup chain
├── D4 (Temporal):   Container startup duration
├── D5 (Resource):   Container resource limits
├── D6 (Error):      Container failure (restart policy)
├── D7 (Recovery):   Container restart
├── D8 (Monitoring): Container metrics (CPU, memory)
├── D9 (Evolution):  Container image updates
└── D10 (Federation): Container replication

L1 (Signal) × D1-D10:
├── D1 (Immediate):  Port availability probe
├── D2 (Adjacent):   Related ports check
├── D3 (Cascading):  Port chain verification
├── D4 (Temporal):   Port check timing
├── D5 (Resource):   Port allocation
├── D6 (Error):      Port conflict resolution
├── D7 (Recovery):   Port release and retry
├── D8 (Monitoring): Port metrics
├── D9 (Evolution):  Port migration
└── D10 (Federation): Port federation across hosts
```

---

## 10. BDD TEST SPECIFICATIONS

### 10.1 Feature: Boot Sequence

```gherkin
Feature: SIL-6 Biomorphic Mesh Boot Sequence
  As a system operator
  I want the mesh to boot deterministically
  So that I can rely on consistent startup behavior

  Background:
    Given no containers are running
    And all required ports are available
    And configuration validation passes

  @P0_Critical @SC-BOOT-001
  Scenario: Complete boot within SLA
    When I execute "sa-up"
    Then the boot should complete within 60 seconds
    And all 14 containers should be healthy
    And the state vector should be [2,2,2,2,2,2,2]

  @P0_Critical @SC-BOOT-002
  Scenario: DAG validation before boot
    When I execute "sa-up"
    Then checkpoint CP-BOOT-02 should be published
    And the DAG should have no cycles
    And all dependencies should be satisfied

  @P0_Critical @SC-BOOT-003
  Scenario: Zenoh 2oo3 quorum
    Given Wave 1 (Foundation) has completed
    When Wave 2 (Control Plane) executes
    Then at least 2 of 3 Zenoh routers should be healthy
    And checkpoint CP-BOOT-05 should be published with quorum status

  @P1_High @SC-BOOT-004
  Scenario: Configuration centralization
    When I scan the codebase for hardcoded ports
    Then all port references should trace to MeshConfig.Ports
    And no magic numbers should exist outside configuration modules

  @P1_High @SC-BOOT-007
  Scenario: Exponential backoff health checks
    When a container health check fails
    Then retry should use exponential backoff sequence [100, 200, 400, 800, 1600, 3200, 5000] ms
    And maximum 7 retries should be attempted

  @P1_High @SC-BOOT-008
  Scenario: Hysteresis prevents flapping
    Given container health is oscillating
    When 2 consecutive unhealthy checks occur
    Then the container should remain marked healthy
    When 3 consecutive unhealthy checks occur
    Then the container should transition to unhealthy

  @P0_Critical @SC-BOOT-011
  Scenario: Automatic rollback on failure
    Given Wave 3 (Cognitive) is in progress
    When the CEPAF bridge fails to start
    Then automatic rollback should trigger
    And all Wave 3 containers should be stopped
    And Wave 2 state should be preserved
    And checkpoint CP-BOOT-FAILED should be published

  @P2_Medium @SC-BOOT-010
  Scenario: Boot idempotency
    When I execute "sa-up" twice
    Then the second execution should detect running containers
    And only missing containers should be started
    And no duplicate containers should exist
```

### 10.2 Feature: Smoke Tests

```gherkin
Feature: Boot Smoke Tests
  As a system operator
  I want smoke tests to verify each boot phase
  So that I can catch failures early

  @Smoke @P0_Critical
  Scenario Outline: Container health smoke test
    Given container "<container>" is expected to be healthy
    When I check the health status
    Then the status should be "healthy"
    And the response time should be less than 5000ms

    Examples:
      | container              |
      | indrajaal-db-prod      |
      | indrajaal-obs-prod     |
      | zenoh-router-1         |
      | zenoh-router-2         |
      | zenoh-router-3         |
      | cepaf-bridge           |
      | indrajaal-cortex       |
      | indrajaal-ex-app-1     |
      | indrajaal-ex-app-2     |
      | indrajaal-ex-app-3     |
      | indrajaal-chaya        |
      | indrajaal-ml-runner-1  |
      | indrajaal-ml-runner-2  |

  @Smoke @P0_Critical
  Scenario: Zenoh connectivity smoke test
    Given all Zenoh routers are healthy
    When I publish a test message to "indrajaal/test/smoke"
    Then the message should be received within 100ms
    And the round-trip latency should be less than 50ms

  @Smoke @P1_High
  Scenario: Database connectivity smoke test
    Given the database container is healthy
    When I execute "SELECT 1" via psql
    Then the query should return 1
    And the query time should be less than 100ms

  @Smoke @P1_High
  Scenario: Phoenix endpoint smoke test
    Given the app container is healthy
    When I request GET /health
    Then the response status should be 200
    And the response should include node information
    And the response time should be less than 1000ms
```

---

## 11. IMPLEMENTATION ROADMAP

### 11.1 Phase Schedule

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| **Phase 1: Config Consolidation** | 1 day | MeshConfig.fs complete, validation added |
| **Phase 2: DAG & CPM** | 1 day | Kahn's algorithm, critical path analysis |
| **Phase 3: FSM & Hysteresis** | 1 day | Container FSM, hysteresis health checks |
| **Phase 4: Zenoh Messaging** | 1 day | Checkpoint protocol, state vector |
| **Phase 5: Orchestrator Rewrite** | 2 days | Railway-oriented boot pipeline |
| **Phase 6: BDD Tests** | 1 day | 50+ BDD scenarios |
| **Phase 7: Documentation** | 1 day | Update all docs, STAMP/AOR/FMEA |

### 11.2 Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/cepaf/src/Cepaf/Mesh/Core.fs` | CREATE | Centralized types, utilities |
| `lib/cepaf/src/Cepaf/Mesh/DAG.fs` | CREATE | Topological sort, cycle detection |
| `lib/cepaf/src/Cepaf/Mesh/CPM.fs` | CREATE | Critical path calculation |
| `lib/cepaf/src/Cepaf/Mesh/FSM.fs` | CREATE | Container state machine |
| `lib/cepaf/src/Cepaf/Mesh/Hysteresis.fs` | CREATE | Health check stability |
| `lib/cepaf/src/Cepaf/Mesh/ZenohCheckpoints.fs` | CREATE | Checkpoint messaging |
| `lib/cepaf/src/Cepaf/Mesh/Orchestrator.fs` | CREATE | Unified boot pipeline |
| `lib/cepaf/src/Cepaf.Config/MeshConfig.fs` | MODIFY | Add missing config |
| `lib/cepaf/scripts/SIL6BiomorphicOrchestrator.fsx` | CREATE | New unified script |
| `test/bdd/features/boot_sequence.feature` | CREATE | BDD scenarios |

### 11.3 Success Criteria

- [ ] Boot time < 60s (target 25-35s)
- [ ] All 14 containers healthy
- [ ] 100% BDD test pass rate
- [ ] Zero hardcoded values outside MeshConfig
- [ ] Zenoh checkpoints published for all phases
- [ ] Automatic rollback tested and verified
- [ ] CPM analysis shows optimized critical path
- [ ] Documentation updated to 5 levels of detail

---

## APPENDIX: REFERENCES

### A.1 Related Documents
- `CLAUDE.md` - System specification
- `docs/architecture/SIL6_MESH_STARTUP_SHUTDOWN_SPEC.md` - Wave specification
- `docs/architecture/ZENOH_TEST_MESSAGING_COMPREHENSIVE.md` - Zenoh protocol
- `.claude/rules/fsharp-sil6-mesh.md` - F# mesh rules

### A.2 Mathematical References
- Kahn, A.B. (1962). "Topological sorting of large networks"
- Kelley, J.E.; Walker, M.R. (1959). "Critical-Path Planning and Scheduling"
- Hopcroft, J.E.; Ullman, J.D. (1979). "Introduction to Automata Theory"
- Little, J.D.C. (1961). "A Proof for the Queuing Formula: L = λW"

### A.3 Pattern References
- Wlaschin, Scott. "Railway Oriented Programming"
- Burgess, Mark. "Promise Theory: Principles and Applications"
- Nygard, Michael T. "Release It!: Design and Deploy Production-Ready Software"

---

**Document Control**
- Created: 2026-01-18T16:15:00Z
- Author: Claude Opus 4.5
- Version: 1.0.0
- STAMP Compliance: SC-BOOT-001 to SC-BOOT-015
- AOR Compliance: AOR-BOOT-001 to AOR-BOOT-010
