# Mathematical Startup Optimization Framework
## Phase 3.5 - Formal Mathematical Foundations for SIL-6 Distributed System Boot

**Version**: 21.2.4-SIL6
**Date**: 2026-01-18
**Author**: Claude Opus 4.5
**STAMP**: SC-MATH-001 to SC-MATH-050

---

## Executive Summary

This document specifies the formal mathematical foundations for optimizing distributed system startup sequences. The framework implements five core mathematical techniques applied across a 7-layer fractal architecture with 10 interaction degrees, providing 350-cell analysis coverage.

### Key Deliverables
- **Graph Theory**: DAG representation, topological ordering, cycle detection
- **Critical Path Method (CPM)**: Boot time optimization via slack analysis
- **Resource Scheduling (RCPSP)**: Memory/CPU-bounded startup
- **State Machine (DFA)**: Container lifecycle formalization
- **Set Theory**: Configuration drift detection

---

## 1. Mathematical Foundations

### 1.1 Graph Theory for Startup Dependencies

**Problem**: Container startup has implicit dependencies that form a directed acyclic graph (DAG).

**Formal Definition**:
```
G = (V, E) where:
  V = {containers} = {db, obs, zenoh-1, zenoh-2, zenoh-3, bridge, cortex, app-1, app-2, app-3, chaya, ml-1, ml-2}
  E = {(u, v) | u must start before v}
```

**Implementation Algorithms**:

#### 1.1.1 Topological Sort (Kahn's Algorithm)

```fsharp
// Kahn's Algorithm with generation grouping
let topologicalSortWithGenerations (graph: DirectedGraph<'T>) : 'T list list =
    let inDegree = Dictionary<'T, int>()
    let generations = ResizeArray<'T list>()

    // Initialize in-degrees
    for node in graph.Nodes do
        inDegree.[node] <- 0
    for (_, target) in graph.Edges do
        inDegree.[target] <- inDegree.[target] + 1

    // Process by generations
    let mutable remaining = Set.ofSeq graph.Nodes
    while not (Set.isEmpty remaining) do
        let ready = remaining |> Set.filter (fun n -> inDegree.[n] = 0) |> Set.toList
        if List.isEmpty ready then failwith "Cycle detected"
        generations.Add(ready)
        for node in ready do
            remaining <- Set.remove node remaining
            for (src, tgt) in graph.Edges do
                if src = node then inDegree.[tgt] <- inDegree.[tgt] - 1

    generations |> Seq.toList
```

**Output**: Containers grouped by generation (parallel-safe within generation)
```
Gen 0: [db]
Gen 1: [obs, zenoh-1, zenoh-2, zenoh-3]
Gen 2: [bridge, cortex]
Gen 3: [app-1]
Gen 4: [app-2, app-3, chaya]
Gen 5: [ml-1, ml-2]
```

#### 1.1.2 Cycle Detection (DFS with Color Marking)

```fsharp
// DFS with white/gray/black color marking
type Color = White | Gray | Black

let detectCycle (graph: DirectedGraph<'T>) : 'T list option =
    let color = Dictionary<'T, Color>()
    let parent = Dictionary<'T, 'T option>()

    for node in graph.Nodes do
        color.[node] <- White
        parent.[node] <- None

    let rec dfs node =
        color.[node] <- Gray
        for (_, neighbor) in graph.Edges |> Seq.filter (fun (s, _) -> s = node) do
            match color.[neighbor] with
            | Gray ->
                // Back edge found - reconstruct cycle
                Some (reconstructCycle parent node neighbor)
            | White ->
                parent.[neighbor] <- Some node
                match dfs neighbor with
                | Some cycle -> Some cycle
                | None -> None
            | Black -> None
        |> function
        | Some cycle -> Some cycle
        | None ->
            color.[node] <- Black
            None

    graph.Nodes |> Seq.tryPick (fun n -> if color.[n] = White then dfs n else None)
```

**STAMP Constraint**: SC-GRAPH-001 - DAG MUST be acyclic before scheduling

#### 1.1.3 Transitive Reduction

```fsharp
// Remove redundant edges while preserving reachability
let transitiveReduction (graph: DirectedGraph<'T>) : DirectedGraph<'T> =
    let reachable = computeTransitiveClosure graph
    let reducedEdges =
        graph.Edges
        |> Seq.filter (fun (u, v) ->
            // Keep edge only if no alternative path exists
            not (graph.Nodes |> Seq.exists (fun w ->
                w <> u && w <> v && reachable(u, w) && reachable(w, v)
            ))
        )
        |> Set.ofSeq
    { Nodes = graph.Nodes; Edges = reducedEdges }
```

---

### 1.2 Critical Path Method (CPM)

**Problem**: Identify which containers determine total boot time and where optimization effort should focus.

**Formal Model**:
```
For each task A with duration t(A):
  Forward Pass:
    ES(A) = max(EF(predecessors)) or 0 if no predecessors
    EF(A) = ES(A) + t(A)

  Backward Pass:
    LF(A) = min(LS(successors)) or EF(A) if no successors
    LS(A) = LF(A) - t(A)

  Slack = LS(A) - ES(A) = LF(A) - EF(A)
  Critical Path = Tasks where Slack = 0
```

**Implementation**:

```fsharp
type CPMTask = {
    Id: string
    Duration: float
    Predecessors: string list
}

type CPMResult = {
    EarliestStart: float
    EarliestFinish: float
    LatestStart: float
    LatestFinish: float
    Slack: float
    IsCritical: bool
}

let calculateCPM (tasks: CPMTask list) : Map<string, CPMResult> =
    let taskMap = tasks |> List.map (fun t -> t.Id, t) |> Map.ofList

    // Forward pass (recursive with memoization)
    let rec earliestFinish taskId (memo: Map<string, float>) =
        match Map.tryFind taskId memo with
        | Some ef -> ef, memo
        | None ->
            let task = taskMap.[taskId]
            let es =
                if List.isEmpty task.Predecessors then 0.0
                else task.Predecessors |> List.map (fun p -> fst (earliestFinish p memo)) |> List.max
            let ef = es + task.Duration
            ef, Map.add taskId ef memo

    // Backward pass
    let rec latestStart taskId projectEnd (memo: Map<string, float>) =
        match Map.tryFind taskId memo with
        | Some ls -> ls, memo
        | None ->
            let task = taskMap.[taskId]
            let successors = tasks |> List.filter (fun t -> List.contains taskId t.Predecessors)
            let lf =
                if List.isEmpty successors then projectEnd
                else successors |> List.map (fun s -> fst (latestStart s.Id projectEnd memo)) |> List.min
            let ls = lf - task.Duration
            ls, Map.add taskId ls memo

    // Build results
    let efMemo = tasks |> List.fold (fun m t -> snd (earliestFinish t.Id m)) Map.empty
    let projectEnd = efMemo |> Map.values |> Seq.max
    let lsMemo = tasks |> List.fold (fun m t -> snd (latestStart t.Id projectEnd m)) Map.empty

    tasks |> List.map (fun t ->
        let ef = efMemo.[t.Id]
        let es = ef - t.Duration
        let ls = lsMemo.[t.Id]
        let lf = ls + t.Duration
        let slack = ls - es
        t.Id, {
            EarliestStart = es
            EarliestFinish = ef
            LatestStart = ls
            LatestFinish = lf
            Slack = slack
            IsCritical = abs slack < 0.001
        }
    ) |> Map.ofList
```

**Example Analysis** (15-container mesh):

| Container | Duration | ES | EF | LS | LF | Slack | Critical |
|-----------|----------|----|----|----|----|-------|----------|
| db | 15s | 0 | 15 | 0 | 15 | 0 | YES |
| obs | 10s | 0 | 10 | 5 | 15 | 5 | NO |
| zenoh-1 | 5s | 15 | 20 | 15 | 20 | 0 | YES |
| zenoh-2 | 5s | 15 | 20 | 17 | 22 | 2 | NO |
| zenoh-3 | 5s | 15 | 20 | 17 | 22 | 2 | NO |
| bridge | 3s | 20 | 23 | 20 | 23 | 0 | YES |
| cortex | 5s | 20 | 25 | 23 | 28 | 3 | NO |
| app-1 | 8s | 23 | 31 | 23 | 31 | 0 | YES |
| app-2 | 8s | 31 | 39 | 31 | 39 | 0 | YES |
| app-3 | 8s | 31 | 39 | 33 | 41 | 2 | NO |

**Critical Path**: db → zenoh-1 → bridge → app-1 → app-2
**Total Duration**: 39s
**Optimization Insight**: Reducing db startup from 15s to 10s saves 5s total

---

### 1.3 Resource Constrained Project Scheduling (RCPSP)

**Problem**: Memory and CPU are finite; containers cannot all start simultaneously.

**Formal Model**:
```
Resources: R = {memory: 32GB, cpu: 16 cores, iops: 10000}
Constraint: ∀t, ∀k : ∑(R_{j,k} × active_j(t)) ≤ Capacity_k
```

**Container Resource Requirements**:

| Container | Memory | CPU | IOPS |
|-----------|--------|-----|------|
| db | 8GB | 4 | 5000 |
| obs | 4GB | 2 | 1000 |
| zenoh-* | 512MB | 0.5 | 500 |
| bridge | 1GB | 1 | 200 |
| cortex | 2GB | 2 | 500 |
| app-* | 4GB | 2 | 2000 |
| chaya | 2GB | 1 | 500 |
| ml-* | 4GB | 4 | 1000 |

**List Scheduling Heuristic**:

```fsharp
type Resource = { Id: string; Capacity: int }
type ResourceRequirement = { TaskId: string; ResourceId: string; Amount: int }
type ResourceSchedule = { TaskId: string; StartTime: int; EndTime: int }

let listSchedule
    (tasks: CPMTask list)
    (resources: Resource list)
    (requirements: ResourceRequirement list)
    : ResourceSchedule list =

    let resourceUsage = Dictionary<string, int[]>()
    for r in resources do
        resourceUsage.[r.Id] <- Array.zeroCreate 1000  // Time horizon

    let scheduled = ResizeArray<ResourceSchedule>()
    let topoOrder = topologicalSort tasks

    for taskId in topoOrder do
        let task = tasks |> List.find (fun t -> t.Id = taskId)
        let taskReqs = requirements |> List.filter (fun r -> r.TaskId = taskId)
        let duration = int task.Duration

        // Find earliest feasible start time
        let predecessorEnd =
            task.Predecessors
            |> List.map (fun p -> (scheduled |> Seq.find (fun s -> s.TaskId = p)).EndTime)
            |> List.fold max 0

        let rec findFeasibleStart t =
            let feasible = taskReqs |> List.forall (fun req ->
                let resource = resources |> List.find (fun r -> r.Id = req.ResourceId)
                [t .. t + duration - 1] |> List.forall (fun time ->
                    resourceUsage.[req.ResourceId].[time] + req.Amount <= resource.Capacity
                )
            )
            if feasible then t else findFeasibleStart (t + 1)

        let startTime = findFeasibleStart predecessorEnd

        // Allocate resources
        for req in taskReqs do
            for time in startTime .. startTime + duration - 1 do
                resourceUsage.[req.ResourceId].[time] <-
                    resourceUsage.[req.ResourceId].[time] + req.Amount

        scheduled.Add({ TaskId = taskId; StartTime = startTime; EndTime = startTime + duration })

    scheduled |> Seq.toList
```

**Resource-Constrained Schedule**:
```
Time:  0----5----10---15---20---25---30---35---40---45
       |    |    |    |    |    |    |    |    |    |
db:    [========15s========]
obs:       [===10s===]
zenoh-1:              [=5s=]
zenoh-2:                   [=5s=]  (delayed: memory)
zenoh-3:                        [=5s=]  (delayed: memory)
bridge:                    [3s]
cortex:                         [==5s==]
app-1:                               [====8s====]
app-2:                                         [====8s====]
...
```

---

### 1.4 Finite State Automata (DFA) for Container Lifecycle

**Problem**: Formalize valid container state transitions to prevent illegal operations.

**Formal Definition**:
```
DFA = (Q, Σ, δ, q₀, F) where:
  Q = {NotCreated, Created, Starting, Running, Healthy, Unhealthy,
       Degraded, Lameduck, Draining, Checkpointing, Stopping, Stopped, Failed, Removed}

  Σ = {Create, Start, HealthPass, HealthFail, Degrade, Recover,
       InitiateShutdown, DrainComplete, CheckpointDone, Stop, Kill, Crash, Remove, Restart}

  δ: Q × Σ → Q (transition function)
  q₀ = NotCreated
  F = {Healthy, Running, Degraded}  (accepting/operational states)
```

**State Transition Diagram**:

```
                              ┌──────────────┐
                              │  NotCreated  │
                              └──────┬───────┘
                                     │ Create
                                     ▼
                              ┌──────────────┐
                              │   Created    │
                              └──────┬───────┘
                                     │ Start
                                     ▼
                              ┌──────────────┐
                              │   Starting   │
                              └──────┬───────┘
                          HealthPass │ │ HealthFail
                   ┌─────────────────┘ └─────────────────┐
                   ▼                                     ▼
            ┌──────────────┐                      ┌──────────────┐
            │   Healthy    │◄─────Recover────────│  Unhealthy   │
            └──────┬───────┘                      └──────┬───────┘
                   │ Degrade                             │
                   ▼                                     │ (3 fails)
            ┌──────────────┐                             ▼
            │   Degraded   │                      ┌──────────────┐
            └──────┬───────┘                      │    Failed    │
                   │ InitiateShutdown             └──────────────┘
                   ▼
            ┌──────────────┐
            │   Lameduck   │ (stop accepting traffic)
            └──────┬───────┘
                   │ DrainComplete
                   ▼
            ┌──────────────┐
            │   Draining   │ (finish in-flight requests)
            └──────┬───────┘
                   │ CheckpointDone
                   ▼
            ┌──────────────┐
            │Checkpointing │ (save state to register)
            └──────┬───────┘
                   │ Stop
                   ▼
            ┌──────────────┐
            │   Stopped    │──────Remove───────▶ Removed
            └──────────────┘
```

**Implementation**:

```fsharp
type ContainerState =
    | NotCreated | Created | Starting | Running | Healthy | Unhealthy
    | Degraded | Lameduck | Draining | Checkpointing | Stopping | Stopped | Failed | Removed

type ContainerEvent =
    | Create | Start | HealthPass | HealthFail | Degrade | Recover
    | InitiateShutdown | DrainComplete | CheckpointDone | Stop | Kill | Crash | Remove | Restart

let transition (state: ContainerState) (event: ContainerEvent) : ContainerState option =
    match state, event with
    // Creation & startup
    | NotCreated, Create -> Some Created
    | Created, Start -> Some Starting
    | Starting, HealthPass -> Some Healthy
    | Starting, HealthFail -> Some Unhealthy

    // Health transitions
    | Healthy, HealthFail -> Some Unhealthy
    | Healthy, Degrade -> Some Degraded
    | Unhealthy, HealthPass -> Some Healthy
    | Unhealthy, HealthFail -> Some Failed  // After 3 consecutive failures
    | Degraded, Recover -> Some Healthy

    // Graceful shutdown sequence (SIL-6 Apoptosis)
    | Healthy, InitiateShutdown -> Some Lameduck
    | Degraded, InitiateShutdown -> Some Lameduck
    | Lameduck, DrainComplete -> Some Draining
    | Draining, CheckpointDone -> Some Checkpointing
    | Checkpointing, Stop -> Some Stopped

    // Cleanup
    | Stopped, Remove -> Some Removed
    | Failed, Remove -> Some Removed
    | Stopped, Restart -> Some Starting

    // Emergency
    | _, Kill -> Some Stopped
    | _, Crash -> Some Failed

    // Invalid transition
    | _ -> None

// Validate transition before execution
let validateTransition state event =
    match transition state event with
    | Some newState -> Ok newState
    | None -> Error (sprintf "Invalid transition: %A --[%A]--> ?" state event)
```

**STAMP Constraints**:
- SC-DFA-001: All container operations MUST follow DFA transitions
- SC-DFA-002: Invalid transitions MUST be rejected
- SC-DFA-003: Graceful shutdown MUST traverse Lameduck → Draining → Checkpointing → Stopped

---

### 1.5 Set Theory for Configuration Management

**Problem**: Detect configuration drift between expected and actual states.

**Formal Operations**:
```
Union:        Config_merged = Base ∪ Override
Intersection: Config_common = Base ∩ Override
Difference:   Config_missing = Expected \ Actual
Symmetric Δ:  Config_drift = (Expected \ Actual) ∪ (Actual \ Expected)
```

**Implementation**:

```fsharp
type ConfigItem = { Key: string; Value: string; Source: string }

module ConfigurationSets =
    let union (a: ConfigItem list) (b: ConfigItem list) : ConfigItem list =
        let aKeys = a |> List.map (fun i -> i.Key) |> Set.ofList
        let bOnly = b |> List.filter (fun i -> not (Set.contains i.Key aKeys))
        a @ bOnly

    let intersection (a: ConfigItem list) (b: ConfigItem list) : ConfigItem list =
        let bKeys = b |> List.map (fun i -> i.Key) |> Set.ofList
        a |> List.filter (fun i -> Set.contains i.Key bKeys)

    let difference (a: ConfigItem list) (b: ConfigItem list) : ConfigItem list =
        let bKeys = b |> List.map (fun i -> i.Key) |> Set.ofList
        a |> List.filter (fun i -> not (Set.contains i.Key bKeys))

    let symmetricDifference a b =
        (difference a b) @ (difference b a)

    type DriftReport = {
        Missing: ConfigItem list    // Expected but not found
        Extra: ConfigItem list      // Found but not expected
        Changed: (ConfigItem * ConfigItem) list  // Different values
    }

    let detectDrift (expected: ConfigItem list) (actual: ConfigItem list) : DriftReport =
        let expectedMap = expected |> List.map (fun i -> i.Key, i) |> Map.ofList
        let actualMap = actual |> List.map (fun i -> i.Key, i) |> Map.ofList

        {
            Missing = difference expected actual
            Extra = difference actual expected
            Changed =
                intersection expected actual
                |> List.choose (fun e ->
                    let a = actualMap.[e.Key]
                    if e.Value <> a.Value then Some (e, a) else None
                )
        }
```

**Drift Detection Example**:
```
Expected Config:
  PHOENIX_PORT=4000
  DB_POOL_SIZE=20
  ZENOH_ROUTER=tcp://zenoh:7447

Actual Config:
  PHOENIX_PORT=4001          <- CHANGED
  DB_POOL_SIZE=20            <- OK
  EXTRA_VAR=true             <- EXTRA

Drift Report:
  Missing: [ZENOH_ROUTER]
  Extra: [EXTRA_VAR]
  Changed: [(PHOENIX_PORT, 4000 -> 4001)]
```

---

## 2. 10-Degree Fractal Analysis Matrix

### 2.1 Fractal Layers (L0-L7)

| Layer | Name | Scope | Startup Concern |
|-------|------|-------|-----------------|
| L0 | Runtime | Code compilation | Mix compile, NIF load |
| L1 | Function | I/O contracts | Health check functions |
| L2 | Component | Module boundaries | GenServer startup |
| L3 | Holon | Agent supervision | Supervisor trees |
| L4 | Container | Isolation | Podman lifecycle |
| L5 | Node | Process runtime | BEAM VM startup |
| L6 | Cluster | Consensus | Quorum formation |
| L7 | Federation | Cross-holon | Protocol negotiation |

### 2.2 Interaction Degrees (D1-D10)

| Degree | Name | Time Scale | Description |
|--------|------|------------|-------------|
| D1 | Immediate | Milliseconds | Direct action result |
| D2 | Adjacent | Seconds | First-order dependencies |
| D3 | Integration | Seconds-Minutes | System integration effects |
| D4 | Operational | Minutes | Capability unlock |
| D5 | Ecosystem | Minutes-Hours | External service effects |
| D6 | Behavioral | Hours | Usage pattern emergence |
| D7 | Adaptive | Days | System adaptation |
| D8 | Evolutionary | Weeks | Architecture evolution |
| D9 | Generational | Months | Major version changes |
| D10 | Existential | Years | System survival |

### 2.3 Analysis Matrix (7×10 = 70 cells per technique × 5 techniques = 350 cells)

Example cells for Graph Theory:

| Layer | D1 | D2 | D3 | D4 | D5 |
|-------|----|----|----|----|----|
| L0 Runtime | Compile check | NIF dependency | Phoenix ready | Tests runnable | Build artifact |
| L1 Function | I/O valid | Call graph | Module linking | API available | Documentation |
| L2 Component | Module boot | Dependency resolution | Integration | Service ready | Release note |
| L3 Holon | Agent spawn | Supervision | Coordination | Capability | Learning |
| L4 Container | Create | Health check | Network join | Endpoint | Scaling |
| L5 Node | Process start | Port binding | Service mesh | Load balance | Federation |
| L6 Cluster | Quorum form | Consensus | Replication | Failover | Split brain |
| L7 Federation | Protocol negotiation | Attestation | State sync | Cross-holon | Evolution |

---

## 3. STAMP Constraints

| ID | Constraint | Severity | Implementation |
|----|------------|----------|----------------|
| SC-MATH-001 | DAG MUST be acyclic before scheduling | CRITICAL | CycleDetection.detectCycle |
| SC-MATH-002 | CPM critical path MUST be identified | HIGH | CriticalPathMethod.calculate |
| SC-MATH-003 | RCPSP resource bounds MUST be respected | CRITICAL | RCPSP.listSchedule |
| SC-MATH-004 | DFA transitions MUST be valid | CRITICAL | ContainerDFA.transition |
| SC-MATH-005 | Config drift MUST be detected | HIGH | ConfigurationSets.detectDrift |
| SC-GRAPH-001 | Topological sort MUST complete | CRITICAL | TopologicalSort.sort |
| SC-GRAPH-002 | Transitive reduction MUST preserve reachability | HIGH | TransitiveReduction.reduce |
| SC-CPM-001 | Forward pass ES/EF MUST be correct | CRITICAL | CPM.forwardPass |
| SC-CPM-002 | Backward pass LS/LF MUST be correct | CRITICAL | CPM.backwardPass |
| SC-CPM-003 | Slack calculation MUST identify critical tasks | HIGH | CPM.calculateSlack |
| SC-RCPSP-001 | Resource usage MUST NOT exceed capacity | CRITICAL | RCPSP.validateSchedule |
| SC-DFA-001 | All operations MUST follow DFA | CRITICAL | DFA.validateTransition |
| SC-DFA-002 | Graceful shutdown MUST traverse 6 phases | CRITICAL | DFA.validateApoptosis |

---

## 4. Files Reference

| File | Lines | Purpose |
|------|-------|---------|
| `MathematicalStartupOptimization.fs` | ~1200 | Core mathematical framework |
| `StartupOptimizationPlan.fs` | ~800 | Integration with planning system |
| `Cepaf.Planning.fsproj` | - | Project reference |

---

## 5. Build Verification

```bash
# Build verification
dotnet build lib/cepaf/src/Cepaf.Planning/Cepaf.Planning.fsproj
# Result: Build succeeded. 0 Error(s)

# Test verification (when tests exist)
dotnet test lib/cepaf/tests/Cepaf.Planning.Tests/
```

---

## 6. Related Documents

- Plan: `/home/an/.claude/plans/recursive-growing-pudding.md`
- CLAUDE.md: System specification
- STAMP constraints reference

---

---

## 7. Phase 4: Full Swarm Implementation

### 7.1 EnhancedSwarmOrchestrator.fsx

Location: `lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx`

The Enhanced Swarm Orchestrator implements all Phase 3.5 mathematical foundations:

```fsharp
// Key modules implemented:
module GraphTheory       // 15-container DAG, topological sort, cycle detection
module CriticalPathMethod // CPM with ES/EF/LS/LF calculations
module ContainerDFA      // 14-state lifecycle state machine
module QuorumVerification // 2oo3 Zenoh quorum with early exit
module BiomorphicHealth  // Sentinel, PatternHunter, SymbioticDefense checks
module SevenLevelRCA     // 7-Level Root Cause Analysis on failure
module SwarmOrchestration // Wave-based boot with transactional rollback
```

### 7.2 15-Container Architecture

| Wave | Containers | IP Range | Purpose |
|------|------------|----------|---------|
| 1 | indrajaal-db-prod | 172.30.0.20 | Foundation (PostgreSQL) |
| 2 | indrajaal-obs-prod, zenoh-router-{1,2,3} | 172.30.0.30-42 | Observability + Zenoh 2oo3 |
| 3 | cepaf-bridge, indrajaal-cortex | 172.30.0.50-60 | Cognitive Plane |
| 4 | indrajaal-ex-app-1 | 172.30.0.10 | Primary Application |
| 5 | indrajaal-ex-app-{2,3}, chaya, ml-runner-{1,2} | 172.30.0.11-15, 70-71 | HA + Satellites |

### 7.3 CLI Commands

```bash
# Boot full swarm
dotnet fsi EnhancedSwarmOrchestrator.fsx -- boot

# Graceful shutdown
dotnet fsi EnhancedSwarmOrchestrator.fsx -- down

# View critical path analysis
dotnet fsi EnhancedSwarmOrchestrator.fsx -- cpm

# View DAG
dotnet fsi EnhancedSwarmOrchestrator.fsx -- dag

# Check Zenoh quorum
dotnet fsi EnhancedSwarmOrchestrator.fsx -- quorum

# Check biomorphic systems
dotnet fsi EnhancedSwarmOrchestrator.fsx -- bio

# Run 7-Level RCA
dotnet fsi EnhancedSwarmOrchestrator.fsx -- rca "failure message"
```

### 7.4 Resource Requirements

| Resource | Total | Notes |
|----------|-------|-------|
| Memory | ~40GB | All 15 containers |
| CPU | 32 cores | Recommended |
| Disk | 50GB | Volumes and images |
| Network | 2 subnets | External (172.30.x.x) + Internal (172.31.x.x) |

### 7.5 STAMP Constraints (Phase 4)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-SWARM-001 | DAG must be acyclic | `GraphTheory.detectCycle()` |
| SC-SWARM-002 | Wave boot with dependencies | `topologicalSortWithGenerations()` |
| SC-SWARM-003 | P0 failure aborts boot | Priority check in wave loop |
| SC-SWARM-004 | 2oo3 quorum required | `QuorumVerification.verifyQuorum()` |
| SC-SWARM-005 | Biomorphic health check | `BiomorphicHealth.verifyBiomorphicSystems()` |
| SC-SWARM-006 | 7-Level RCA on failure | `SevenLevelRCA.executeRCA()` |
| SC-SWARM-007 | Graceful shutdown | Reverse wave order with checkpointing |

---

**Document Control**

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0.0 | 2026-01-18 | Claude Opus 4.5 | Initial creation |
| 1.1.0 | 2026-01-18 | Claude Opus 4.5 | Added Phase 4 implementation details |
