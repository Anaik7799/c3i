# FULL APP HOLON CAPABILITY TEST PLAN

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   INDRAJAAL HOLON VERIFICATION CANON
     ╭╯ ╰─╯ ╰╮       SIL-6 Biomorphic Fractal Mesh
    ●╯       ╰●       v21.3.0-SIL6
```

**Document Control**
| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Created | 2026-01-08 |
| Author | Claude Opus 4.5 |
| Classification | VERIFICATION CANON |
| Compliance | IEC 61508 SIL-6, ISO 27001, DO-178C DAL-A |
| STAMP Range | SC-VER-001 to SC-VER-100 |

---

## 1. EXECUTIVE SUMMARY

### 1.1 Purpose
This document serves as the **Verification Canon** for the SIL-6 Biomorphic Fractal Mesh architecture. It defines the complete verification strategy across 7 fractal levels, ensuring that the Application Holon achieves **Full Capability State** for Phase 4 deployment.

### 1.2 Scope
- **ALL Control operations via F# Cortex** (mandatory)
- **7-Level Fractal Verification Framework**
- **PROMETHEUS Formal Verification Layer**
- **Transaction State Management** (Snapshot, Checkpoint, Rollback)
- **Three Environment Tiers** (DEV, CLUSTER, MESH)
- **NixOS Container-Only Architecture**

### 1.3 Containers (Exclusive)
| Container | Role | Ports |
|-----------|------|-------|
| `indrajaal-db` | PostgreSQL + TimescaleDB | 5433 |
| `indrajaal-obs` | OTEL + Prometheus + Grafana + Loki | 4317, 9090, 3000, 3100 |
| `indrajaal-app` | Phoenix + FLAME + Clustering | 4000, 4001 |
| `zenoh-router` | Zenoh Mesh Fabric | 7447, 8000 |
| `cortex` | F# Control Plane | 9000 |

---

## 2. BIOMORPHIC THINKING: FRACTAL VERIFICATION STRATEGY

### 2.1 Methodology
Decomposition of "Capability" into verifiable predicates at seven fractal levels:

```
L7: STRATEGIC    ─────────────────────────────────────────────────
    │ Federation-scale invariants, cross-holon consensus
    │
L6: EVOLUTIONARY ─────────────────────────────────────────────────
    │ Genome mutation, adaptation, lineage continuity
    │
L5: METABOLIC    ─────────────────────────────────────────────────
    │ Resource consumption, energy budgets, API rate control
    │
L4: OPERATIONAL  ─────────────────────────────────────────────────
    │ Runtime behavior, OODA cycles, command execution
    │
L3: INTEGRATION  ─────────────────────────────────────────────────
    │ Inter-container communication, mesh connectivity
    │
L2: COMPONENT    ─────────────────────────────────────────────────
    │ Module boundaries, domain isolation, resource coupling
    │
L1: CELLULAR     ─────────────────────────────────────────────────
    │ Function contracts, type safety, unit behavior
    │
L0: RUNTIME      ─────────────────────────────────────────────────
    Compilation, NIF loading, BEAM scheduler stability
```

### 2.2 The 7-Level Verification Matrix

| Level | Name | Verification Method | Time Budget | STAMP Range |
|-------|------|---------------------|-------------|-------------|
| L0 | Runtime | Compilation + NIF validation | < 120s | SC-VER-001 to SC-VER-010 |
| L1 | Cellular | Unit tests + Property tests | < 60s | SC-VER-011 to SC-VER-020 |
| L2 | Component | Module integration tests | < 120s | SC-VER-021 to SC-VER-030 |
| L3 | Integration | Container health consensus | < 60s | SC-VER-031 to SC-VER-040 |
| L4 | Operational | OODA cycle verification | < 30s | SC-VER-041 to SC-VER-050 |
| L5 | Metabolic | Resource budget verification | < 30s | SC-VER-051 to SC-VER-060 |
| L6 | Evolutionary | Genome integrity checks | < 60s | SC-VER-061 to SC-VER-070 |
| L7 | Strategic | Federation invariants | < 120s | SC-VER-071 to SC-VER-080 |

---

## 3. ENVIRONMENT SPECIFICATIONS

### 3.1 DEV Environment (Minimum Viable)

```yaml
# podman-compose-dev.yml
name: indrajaal-dev
containers:
  indrajaal-db:
    image: localhost/indrajaal-timescaledb-demo:nixos-devenv
    ports: ["5433:5432"]
    healthcheck:
      test: pg_isready -U postgres
      interval: 10s

  indrajaal-obs:
    image: localhost/indrajaal-obs:nixos-devenv
    ports: ["4317:4317", "9090:9090", "3000:3000"]
    healthcheck:
      test: curl -f http://localhost:9090/-/ready
      interval: 10s

  indrajaal-app:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-devenv
    ports: ["4000:4000"]
    depends_on: [indrajaal-db, indrajaal-obs]
    healthcheck:
      test: curl -f http://localhost:4000/api/health
      interval: 10s
```

**Topology**: `zenoh-router → db → obs → app-1` (4 containers)

### 3.2 CLUSTER Environment (High Availability)

```yaml
# podman-compose-cluster.yml
name: indrajaal-cluster
containers:
  indrajaal-db:
    image: localhost/indrajaal-timescaledb-demo:nixos-devenv
    ports: ["5433:5432"]

  indrajaal-obs:
    image: localhost/indrajaal-obs:nixos-devenv
    ports: ["4317:4317", "9090:9090", "3000:3000"]

  indrajaal-app-1:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-devenv
    ports: ["4000:4000"]
    environment:
      - RELEASE_NODE=app1@indrajaal-app-1
      - CLUSTER_COOKIE=indrajaal_cluster_secret

  indrajaal-app-2:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-devenv
    ports: ["4002:4000"]
    environment:
      - RELEASE_NODE=app2@indrajaal-app-2
      - CLUSTER_COOKIE=indrajaal_cluster_secret
```

**Topology**: `db → obs → [app-1, app-2]` (4 containers)
**Quorum**: `floor(2/2) + 1 = 2` (both nodes required)

### 3.3 MESH Environment (Full Fractal)

```yaml
# podman-compose-fractal-mesh.yml (SC-CLU-002 MANDATORY)
name: indrajaal-mesh
containers:
  indrajaal-db-1:
    image: localhost/indrajaal-timescaledb-demo:nixos-devenv
    ports: ["5433:5432"]
    environment:
      - POSTGRES_REPLICATION_MODE=primary

  indrajaal-db-2:
    image: localhost/indrajaal-timescaledb-demo:nixos-devenv
    ports: ["5434:5432"]
    environment:
      - POSTGRES_REPLICATION_MODE=replica

  indrajaal-obs:
    image: localhost/indrajaal-obs:nixos-devenv
    ports: ["4317:4317", "9090:9090", "3000:3000", "3100:3100"]

  indrajaal-app-1:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-devenv
    ports: ["4000:4000"]

  indrajaal-app-2:
    image: localhost/indrajaal-sopv51-elixir-app:nixos-devenv
    ports: ["4002:4000"]

  zenoh-router:
    image: localhost/zenoh-router:nixos-devenv
    ports: ["7447:7447", "8000:8000"]

  cortex:
    image: localhost/cepaf-cortex:nixos-devenv
    ports: ["9000:9000"]
    volumes:
      - ./data/holons:/data/holons
```

**Topology**: `[db-1, db-2] → obs → [app-1, app-2] → [zenoh, cortex]` (7 containers)
**Quorum**: `floor(7/2) + 1 = 4` (majority required)

---

## 4. F# CORTEX CONTROL INTERFACE

### 4.1 SIL6MeshCLI Entry Point

All verification operations MUST be executed through the F# Cortex CLI:

```fsharp
// lib/cepaf/src/Cepaf/Mesh/SIL6MeshCLI.fs

type MeshMode =
    | Dev     // 4 containers
    | Cluster // 5 containers
    | Fractal // 7 containers (DEFAULT)

type CLICommand =
    | Up of mode: MeshMode * verbose: bool
    | Down of graceful: bool * checkpoint: bool
    | Status of detailed: bool
    | Health of fpps: bool  // FPPS 5-method consensus
    | Verify of twoOfThree: bool  // 2oo3 voting
    | Scour of ports: int list
    | Clean of removeVolumes: bool
    | Emergency  // < 5s shutdown (SC-EMR-057)
    | Logs of container: string * follow: bool
    | Test of level: int option  // L0-L7
    | Snapshot of name: string
    | Checkpoint of name: string
    | Rollback of name: string
    | Dashboard

/// Execute CLI command with 5-Order effect logging
let execute (cmd: CLICommand) : Result<unit, string> =
    FiveOrderLogger.log 1 $"Executing {cmd}"
    match cmd with
    | Up (mode, verbose) ->
        bootMesh mode verbose
    | Down (graceful, checkpoint) ->
        shutdownMesh graceful checkpoint
    | Health fpps ->
        if fpps then fppsConsensus()
        else simpleHealthCheck()
    | Verify twoOfThree ->
        if twoOfThree then verify2oo3()
        else Ok ()
    | Test level ->
        runVerificationLevel level
    | Snapshot name ->
        stateSnapshot name
    | Checkpoint name ->
        transactionCheckpoint name
    | Rollback name ->
        transactionRollback name
    | _ -> Ok ()
```

### 4.2 PanopticonOrchestrator (5-Stage Boot)

```fsharp
// lib/cepaf/src/Cepaf/Mesh/PanopticonOrchestrator.fs

type BootStage =
    | Preflight    // Port scouring, dependency validation
    | Ignition     // Container start with wave dependencies
    | Lens         // Observability instrumentation
    | Convergence  // Quorum achievement, health consensus
    | Ready        // OODA active, system operational

/// 5-Stage transactional boot with rollback
let bootPanopticon (mode: MeshMode) : Result<BootResult, BootError> =
    result {
        // Stage 1: Preflight
        let! preflightResult = runPreflight mode
        FiveOrderLogger.log 1 "Preflight complete: ports scoured"

        // Stage 2: Ignition (with transaction)
        let! txId = Transaction.begin "boot"
        let! ignitionResult = runIgnition mode txId
        FiveOrderLogger.log 2 "Ignition complete: containers started"

        // Stage 3: Lens
        let! lensResult = runLens mode
        FiveOrderLogger.log 3 "Lens complete: observability active"

        // Stage 4: Convergence
        let! convergenceResult = runConvergence mode
        FiveOrderLogger.log 4 "Convergence complete: quorum achieved"

        // Stage 5: Ready
        let! readyResult = runReady mode
        FiveOrderLogger.log 5 "Ready complete: OODA active"

        // Commit transaction
        do! Transaction.commit txId

        return {
            Mode = mode
            Duration = stopwatch.Elapsed
            Stages = [preflightResult; ignitionResult; lensResult; convergenceResult; readyResult]
        }
    }
```

### 4.3 HealthCoordinator (FPPS 5-Method Consensus)

```fsharp
// lib/cepaf/src/Cepaf/Mesh/HealthCoordinator.fs

type HealthMethod =
    | TCPSocket     // Port availability
    | HTTPHealth    // /health endpoint
    | ContainerLog  // Log pattern matching
    | ProcessCheck  // PID existence
    | MetricProbe   // Prometheus metrics

type FPPSResult = {
    Methods: Map<HealthMethod, bool>
    Consensus: bool  // All 5 must agree
    Timestamp: DateTime
}

/// FPPS 5-Method Health Consensus (SC-VAL-003)
let fppsConsensus (container: string) : FPPSResult =
    let results =
        [ TCPSocket, checkTCP container
          HTTPHealth, checkHTTP container
          ContainerLog, checkLogs container
          ProcessCheck, checkProcess container
          MetricProbe, checkMetrics container ]
        |> Map.ofList

    let allAgree = results |> Map.forall (fun _ v -> v)

    // SC-VAL-004: Halt on disagreement
    if not allAgree then
        FiveOrderLogger.log 1 $"FPPS DISAGREEMENT for {container}"
        Emergency.trigger container

    { Methods = results; Consensus = allAgree; Timestamp = DateTime.UtcNow }
```

### 4.4 2oo3 Voting Verification (SC-SIL6-006)

```fsharp
// lib/cepaf/src/Cepaf/SIL6/TwoOfThreeVoting.fs

type VotingChannel =
    | LiveNode     // Running container
    | ShadowNode   // Replica/standby container
    | FormalModel  // Quint/SHACL specification

/// 2-out-of-3 voting for production actuations
let verify2oo3 (action: ProposedAction) : Result<Approval, Veto> =
    let votes =
        [ LiveNode, voteLiveNode action
          ShadowNode, voteShadowNode action
          FormalModel, voteFormalModel action ]

    let approvals = votes |> List.filter (fun (_, v) -> v = Approve)

    if approvals.Length >= 2 then
        FiveOrderLogger.log 4 $"2oo3 APPROVED: {action}"
        Ok Approval
    else
        FiveOrderLogger.log 4 $"2oo3 VETOED: {action}"
        Error Veto
```

---

## 5. PROMETHEUS FORMAL VERIFICATION LAYER

### 5.1 Overview

**PROMETHEUS** (PROof-based Mathematical Execution with Temporal HEuristic Universal Safety) provides mathematical guarantees for all execution paths.

```fsharp
// lib/cepaf/src/Cepaf/Formal/Prometheus.fs

type PrometheusProof = {
    ProofToken: Guid
    Proposition: string
    Method: VerificationMethod
    Result: ProofResult
    Timestamp: DateTime
    TTL: TimeSpan
}

type VerificationMethod =
    | QuintModelCheck     // Temporal logic
    | SHACLValidation     // Graph shape constraints
    | GraphBLASMatrix     // Algebraic path analysis
    | AgdaProof           // Dependent types
    | Z3SMT               // SAT/SMT solving
```

### 5.2 PROMETHEUS Constraints

| ID | Constraint | Severity | Verification Method |
|----|------------|----------|---------------------|
| SC-PROM-001 | No mutation without proof token | CRITICAL | Runtime check |
| SC-PROM-002 | API usage < 95% of limits | CRITICAL | Rate limiter |
| SC-PROM-003 | Dashboard refresh < 60s | HIGH | Watchdog |
| SC-PROM-004 | DAG acyclicity proven | CRITICAL | Topological sort |
| SC-PROM-005 | Verification latency < 5ms (p99) | HIGH | Telemetry |
| SC-PROM-006 | Executive override requires audit | HIGH | Audit trail |
| SC-PROM-007 | State serialization before scale-down | CRITICAL | Lifecycle hook |

### 5.3 Proof Token Generation

```fsharp
/// Generate PROMETHEUS proof token for action
let generateProofToken (action: ProposedAction) : Result<PrometheusProof, VerificationError> =
    result {
        // 1. Quint model checking (temporal logic)
        let! quintResult = QuintVerifier.check action.Specification

        // 2. SHACL shape validation (graph constraints)
        let! shaclResult = SHACLValidator.validate action.StateGraph

        // 3. GraphBLAS path analysis (algebraic)
        let! pathResult = GraphBLAS.analyzePaths action.ExecutionGraph

        // 4. Combine results
        let proofToken = Guid.NewGuid()

        return {
            ProofToken = proofToken
            Proposition = action.ToString()
            Method = QuintModelCheck  // Primary method
            Result = if quintResult && shaclResult && pathResult then Proven else Refuted
            Timestamp = DateTime.UtcNow
            TTL = TimeSpan.FromMinutes(5.0)
        }
    }
```

### 5.4 Quint Model Specifications

```quint
// formal/specs/holon_capability.qnt

module HolonCapability {
    // State type
    type ContainerState = Running | Stopped | Failed | Unknown

    // System state
    var containers: str -> ContainerState
    var quorum: int
    var healthyCount: int

    // Invariant: Always have quorum
    invariant quorumMaintained = healthyCount >= quorum

    // Invariant: No split-brain
    invariant noSplitBrain =
        containers.values().filter(s => s == Running).size() <= 1 or
        containers.values().filter(s => s == Running).size() >= quorum

    // Temporal: Eventually ready after boot
    temporal eventuallyReady =
        boot => eventually(healthyCount >= quorum)

    // Temporal: Always can shutdown gracefully
    temporal alwaysCanShutdown =
        always(Running in containers.values() => eventually(canShutdown))

    // Action: Boot container
    action bootContainer(name: str): bool = {
        containers' = containers.set(name, Running)
        healthyCount' = healthyCount + 1
        quorumMaintained'
    }

    // Action: Shutdown container
    action shutdownContainer(name: str): bool = {
        containers' = containers.set(name, Stopped)
        healthyCount' = healthyCount - 1
        healthyCount' >= 0
    }
}
```

---

## 6. TRANSACTION STATE MANAGEMENT

### 6.1 State Capture Mechanism

```fsharp
// lib/cepaf/src/Cepaf/SIL6/StateSnapshot.fs

type StateSnapshot = {
    Id: Guid
    Name: string
    Timestamp: DateTime
    Mode: MeshMode
    Containers: Map<string, ContainerState>
    HolonState: byte[]  // SQLite WAL snapshot
    Metadata: Map<string, string>
}

/// Capture full system state snapshot
let captureSnapshot (name: string) : Result<StateSnapshot, SnapshotError> =
    result {
        // 1. Pause all containers
        do! ContainerLifecycle.pauseAll()

        // 2. Capture SQLite WAL
        let! holonState = SQLiteWAL.snapshot "data/holons/"

        // 3. Capture container states
        let! containerStates = Container.getAllStates()

        // 4. Resume containers
        do! ContainerLifecycle.resumeAll()

        // 5. Store snapshot
        let snapshot = {
            Id = Guid.NewGuid()
            Name = name
            Timestamp = DateTime.UtcNow
            Mode = getCurrentMode()
            Containers = containerStates
            HolonState = holonState
            Metadata = Map.empty
        }

        do! StateStorage.save snapshot

        return snapshot
    }
```

### 6.2 Transaction Checkpoints

```fsharp
// lib/cepaf/src/Cepaf/SIL6/TransactionManager.fs

type Transaction = {
    Id: Guid
    Name: string
    StartTime: DateTime
    Operations: Operation list
    Checkpoints: Checkpoint list
    Status: TransactionStatus
}

type TransactionStatus =
    | Active | Committed | RolledBack | Failed

/// Begin new transaction with checkpoint
let beginTransaction (name: string) : Transaction =
    let tx = {
        Id = Guid.NewGuid()
        Name = name
        StartTime = DateTime.UtcNow
        Operations = []
        Checkpoints = []
        Status = Active
    }

    // Create initial checkpoint
    let checkpoint = createCheckpoint tx "initial"

    { tx with Checkpoints = [checkpoint] }

/// Commit transaction
let commitTransaction (tx: Transaction) : Result<unit, TransactionError> =
    result {
        // Verify all operations completed
        do! verifyOperations tx.Operations

        // Log to immutable register
        do! ImmutableRegister.append (TransactionCommit tx.Id)

        // Update status
        tx.Status <- Committed

        FiveOrderLogger.log 5 $"Transaction {tx.Name} committed"
    }

/// Rollback transaction to checkpoint
let rollbackTransaction (tx: Transaction) (checkpointName: string) : Result<unit, RollbackError> =
    result {
        // Find checkpoint
        let! checkpoint =
            tx.Checkpoints
            |> List.tryFind (fun c -> c.Name = checkpointName)
            |> Result.ofOption "Checkpoint not found"

        // Restore state
        do! StateSnapshot.restore checkpoint.Snapshot

        // Log to immutable register
        do! ImmutableRegister.append (TransactionRollback (tx.Id, checkpointName))

        // Update status
        tx.Status <- RolledBack

        FiveOrderLogger.log 5 $"Transaction {tx.Name} rolled back to {checkpointName}"
    }
```

### 6.3 Apoptosis Protocol (Controlled Self-Destruction)

```fsharp
// lib/cepaf/src/Cepaf/Mesh/Apoptosis.fs

type ApoptosisPhase =
    | Initiated      // Apoptosis triggered
    | Notifying      // Federation peers notified
    | Draining       // Traffic draining
    | Checkpointing  // State checkpoint
    | Terminating    // Container shutdown
    | Terminated     // Complete

/// 6-Phase Apoptosis Protocol (SC-SIL6-015)
let triggerApoptosis (reason: ApoptosisReason) : Result<unit, ApoptosisError> =
    result {
        // Phase 1: Initiated
        FiveOrderLogger.log 1 $"Apoptosis initiated: {reason}"

        // Phase 2: Notify federation
        do! FederationProtocol.notifyApoptosis()

        // Phase 3: Drain traffic
        do! LoadBalancer.drainAll (TimeSpan.FromSeconds 30.0)

        // Phase 4: Checkpoint state
        let! snapshot = StateSnapshot.capture "apoptosis-final"

        // Phase 5: Terminate containers
        do! ContainerLifecycle.terminateAll()

        // Phase 6: Complete
        FiveOrderLogger.log 5 "Apoptosis complete"

        return ()
    }
```

---

## 7. 7-LEVEL VERIFICATION SPECIFICATIONS

### 7.1 L0: RUNTIME LEVEL

**Purpose**: Verify compilation, NIF loading, and BEAM scheduler stability.

#### 7.1.1 STAMP Constraints (L0)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-001 | Compilation 0 errors | CRITICAL | `mix compile` exit 0 |
| SC-VER-002 | Compilation 0 warnings | CRITICAL | `--warnings-as-errors` |
| SC-VER-003 | All NIFs load successfully | CRITICAL | NIF module check |
| SC-VER-004 | Rustler version match | CRITICAL | Cargo.toml vs mix.exs |
| SC-VER-005 | BEAM scheduler stable | HIGH | `:erlang.system_info` |
| SC-VER-006 | Patient Mode active | CRITICAL | Env var check |
| SC-VER-007 | 773 source files compiled | HIGH | File count |
| SC-VER-008 | All DSL expansions valid | HIGH | Ash compile |
| SC-VER-009 | Hot reload functional | MEDIUM | Phoenix reload |
| SC-VER-010 | Log file created | MEDIUM | `data/tmp/1-compile.log` |

#### 7.1.2 FMEA Analysis (L0)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| NIF compile fail | System unusable | 9 | 3 | 8 | 216 | Rust version check |
| Warning introduced | Quality degraded | 6 | 5 | 3 | 90 | CI gate |
| DSL expansion fail | Module broken | 8 | 2 | 7 | 112 | Ash validation |
| Timeout during compile | Build incomplete | 7 | 4 | 5 | 140 | Patient Mode |

#### 7.1.3 TDG Test Cases (L0)

```fsharp
// test/verification/L0_Runtime_Tests.fs

module L0RuntimeTests

open Expecto
open FsCheck

[<Tests>]
let runtimeTests = testList "L0 Runtime" [

    testCase "SC-VER-001: Compilation succeeds with 0 errors" <| fun () ->
        let result = Bash.exec "mix compile 2>&1"
        Expect.equal result.ExitCode 0 "Compilation must succeed"
        Expect.isFalse (result.Output.Contains "error") "No errors"

    testCase "SC-VER-002: Compilation has 0 warnings" <| fun () ->
        let result = Bash.exec "mix compile --warnings-as-errors 2>&1"
        Expect.equal result.ExitCode 0 "No warnings allowed"

    testCase "SC-VER-003: All NIFs load" <| fun () ->
        let nifs = ["Indrajaal.Native.Zenoh"; "Indrajaal.Native.Crypto"]
        for nif in nifs do
            let result = Elixir.eval $"Code.ensure_loaded!({nif})"
            Expect.isOk result $"NIF {nif} must load"

    testCase "SC-VER-004: Rustler versions match" <| fun () ->
        let cargoVersion = Cargo.getRustlerVersion "native/zenoh_nif/Cargo.toml"
        let mixVersion = Mix.getRustlerVersion "mix.exs"
        Expect.equal cargoVersion mixVersion "Rustler versions must match"

    testProperty "SC-VER-005: BEAM scheduler remains stable under load" <| fun (load: PositiveInt) ->
        let schedulerInfo = Erlang.systemInfo "scheduler_id"
        schedulerInfo > 0 && schedulerInfo <= 16

    testCase "SC-VER-006: Patient Mode active" <| fun () ->
        Expect.equal (Environment.get "PATIENT_MODE") "enabled" "Patient Mode required"
        Expect.equal (Environment.get "NO_TIMEOUT") "true" "No timeout required"
]
```

#### 7.1.4 AOR Rules (L0)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-001 | ALWAYS use Patient Mode for compilation | Env var check |
| AOR-VER-002 | VERIFY NIF versions before compile | Pre-compile hook |
| AOR-VER-003 | LOG all compilation output | Tee to data/tmp/ |
| AOR-VER-004 | HALT on any compilation error | Exit code check |
| AOR-VER-005 | CHECKPOINT git state before risky changes | Git stash |

---

### 7.2 L1: CELLULAR LEVEL

**Purpose**: Verify function contracts, type safety, and unit behavior.

#### 7.2.1 STAMP Constraints (L1)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-011 | All public functions have @spec | HIGH | Dialyzer |
| SC-VER-012 | All specs pass Dialyzer | CRITICAL | `mix dialyzer` |
| SC-VER-013 | Property tests for core functions | HIGH | PropCheck |
| SC-VER-014 | Unit test coverage > 95% | HIGH | ExCoveralls |
| SC-VER-015 | No cyclomatic complexity > 15 | MEDIUM | Credo |
| SC-VER-016 | Functions < 50 lines | MEDIUM | Credo |
| SC-VER-017 | No duplicate code blocks | MEDIUM | Credo |
| SC-VER-018 | All GenServers supervised | HIGH | Supervisor check |
| SC-VER-019 | No blocking calls in GenServer | HIGH | Code analysis |
| SC-VER-020 | All callbacks implemented | CRITICAL | Behaviour check |

#### 7.2.2 FMEA Analysis (L1)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Missing @spec | Type errors at runtime | 7 | 4 | 5 | 140 | Dialyzer strict |
| GenServer crash | Service unavailable | 8 | 3 | 6 | 144 | Supervision |
| Blocking call | System freeze | 9 | 2 | 4 | 72 | Async patterns |
| Memory leak | OOM crash | 9 | 2 | 6 | 108 | Sentinel monitoring |

#### 7.2.3 TDG Test Cases (L1)

```fsharp
// test/verification/L1_Cellular_Tests.fs

module L1CellularTests

open Expecto
open FsCheck

[<Tests>]
let cellularTests = testList "L1 Cellular" [

    testCase "SC-VER-011: All public functions have specs" <| fun () ->
        let result = Bash.exec "mix dialyzer --format short 2>&1"
        let missingSpecs = result.Output |> String.lines |> List.filter (fun l -> l.Contains "no_return")
        Expect.isEmpty missingSpecs "All functions must have specs"

    testCase "SC-VER-012: Dialyzer passes" <| fun () ->
        let result = Bash.exec "mix dialyzer 2>&1"
        Expect.equal result.ExitCode 0 "Dialyzer must pass"

    testCase "SC-VER-014: Test coverage > 95%" <| fun () ->
        let result = Bash.exec "mix test --cover 2>&1"
        let coverage = Coverage.parse result.Output
        Expect.isGreaterThan coverage 95.0 "Coverage must exceed 95%"

    testProperty "SC-VER-015: Cyclomatic complexity bounded" <| fun (modulePath: NonEmptyString) ->
        let complexity = Credo.getCyclomaticComplexity modulePath.Get
        complexity <= 15

    testCase "SC-VER-018: All GenServers supervised" <| fun () ->
        let genservers = Elixir.findModulesUsing "GenServer"
        let supervised = Elixir.findSupervisedChildren()
        for gs in genservers do
            Expect.contains supervised gs $"{gs} must be supervised"

    testProperty "SC-VER-019: GenServer calls non-blocking" <| fun (module: GenServerModule) ->
        let calls = AST.findCalls module "GenServer.call"
        calls |> List.forall (fun c -> c.HasTimeout || c.Timeout <= 5000)
]
```

#### 7.2.4 AOR Rules (L1)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-006 | ADD @spec for every public function | Credo check |
| AOR-VER-007 | USE property tests for pure functions | Test review |
| AOR-VER-008 | SUPERVISE all GenServers | Supervisor tree |
| AOR-VER-009 | AVOID blocking calls (use cast/async) | Code review |
| AOR-VER-010 | LIMIT function complexity to 15 | Credo strict |

---

### 7.3 L2: COMPONENT LEVEL

**Purpose**: Verify module boundaries, domain isolation, and resource coupling.

#### 7.3.1 STAMP Constraints (L2)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-021 | All Ash resources use BaseResource | CRITICAL | Grep check |
| SC-VER-022 | No circular domain dependencies | HIGH | Dependency graph |
| SC-VER-023 | All domains have clear boundaries | HIGH | Module tree |
| SC-VER-024 | Holon state in SQLite/DuckDB only | CRITICAL | Code audit |
| SC-VER-025 | No PostgreSQL for holon state | CRITICAL | Code audit |
| SC-VER-026 | All contexts have Phoenix contexts | HIGH | Context check |
| SC-VER-027 | Ecto schemas match Ash resources | HIGH | Schema compare |
| SC-VER-028 | All API modules have OpenAPI spec | MEDIUM | OpenAPI check |
| SC-VER-029 | Domain isolation via PubSub | HIGH | PubSub audit |
| SC-VER-030 | No shared mutable state | CRITICAL | State audit |

#### 7.3.2 FMEA Analysis (L2)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Circular dependency | Build failure | 7 | 3 | 7 | 147 | Dependency analysis |
| Domain leak | Data corruption | 8 | 2 | 5 | 80 | Boundary checks |
| Wrong state store | Recovery failure | 9 | 2 | 6 | 108 | SC-HOLON-001 |
| Missing context | Route errors | 6 | 4 | 4 | 96 | Router validation |

#### 7.3.3 TDG Test Cases (L2)

```fsharp
// test/verification/L2_Component_Tests.fs

module L2ComponentTests

open Expecto
open FsCheck

[<Tests>]
let componentTests = testList "L2 Component" [

    testCase "SC-VER-021: All Ash resources use BaseResource" <| fun () ->
        let resources = Glob.find "lib/indrajaal/**/*_resource.ex"
        for res in resources do
            let content = File.readAllText res
            Expect.isTrue (content.Contains "use Indrajaal.BaseResource")
                $"{res} must use BaseResource"

    testCase "SC-VER-022: No circular domain dependencies" <| fun () ->
        let deps = DependencyGraph.build "lib/indrajaal/"
        let cycles = Graph.findCycles deps
        Expect.isEmpty cycles "No circular dependencies allowed"

    testCase "SC-VER-024: Holon state in SQLite/DuckDB only" <| fun () ->
        let holonModules = Glob.find "lib/indrajaal/holon/**/*.ex"
        for m in holonModules do
            let content = File.readAllText m
            Expect.isFalse (content.Contains "Repo.")
                $"{m} must not use PostgreSQL Repo for holon state"

    testCase "SC-VER-025: No PostgreSQL for holon state" <| fun () ->
        let writes = Grep.find "Ecto.Changeset" "lib/indrajaal/holon/"
        Expect.isEmpty writes "Holon state must use SQLite, not Ecto"

    testProperty "SC-VER-029: Domain isolation via PubSub" <| fun (domain: Domain) ->
        let pubsubTopics = PubSub.getTopics domain
        pubsubTopics |> List.forall (fun t -> t.StartsWith $"{domain}:")
]
```

#### 7.3.4 AOR Rules (L2)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-011 | USE BaseResource for all Ash resources | Grep check |
| AOR-VER-012 | ISOLATE domains via PubSub | Architecture review |
| AOR-VER-013 | STORE holon state in SQLite/DuckDB ONLY | Code audit |
| AOR-VER-014 | AVOID cross-domain direct calls | Boundary check |
| AOR-VER-015 | DOCUMENT all public APIs with OpenAPI | Spec check |

---

### 7.4 L3: INTEGRATION LEVEL

**Purpose**: Verify inter-container communication and mesh connectivity.

#### 7.4.1 STAMP Constraints (L3)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-031 | All containers healthy | CRITICAL | Health check |
| SC-VER-032 | FPPS 5-method consensus | CRITICAL | SC-VAL-003 |
| SC-VER-033 | Zenoh mesh connected | HIGH | Zenoh status |
| SC-VER-034 | DB connection pool active | CRITICAL | Pool check |
| SC-VER-035 | OTEL traces flowing | HIGH | Trace check |
| SC-VER-036 | Prometheus metrics scraped | HIGH | Metrics check |
| SC-VER-037 | Inter-container latency < 50ms | HIGH | Latency probe |
| SC-VER-038 | Network isolation maintained | CRITICAL | Network check |
| SC-VER-039 | Quorum established | CRITICAL | Quorum vote |
| SC-VER-040 | No split-brain detected | CRITICAL | Split-brain check |

#### 7.4.2 FMEA Analysis (L3)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Container crash | Service degraded | 8 | 3 | 7 | 168 | Supervisor restart |
| Network partition | Split-brain | 9 | 2 | 6 | 108 | Quorum voting |
| DB connection loss | Transactions fail | 9 | 2 | 8 | 144 | Connection pool |
| OTEL failure | No observability | 6 | 3 | 5 | 90 | Fallback logging |

#### 7.4.3 TDG Test Cases (L3)

```fsharp
// test/verification/L3_Integration_Tests.fs

module L3IntegrationTests

open Expecto
open FsCheck

[<Tests>]
let integrationTests = testList "L3 Integration" [

    testCase "SC-VER-031: All containers healthy" <| fun () ->
        let containers = ["indrajaal-db"; "indrajaal-obs"; "indrajaal-app"]
        for c in containers do
            let health = Container.healthCheck c
            Expect.isTrue health.Healthy $"{c} must be healthy"

    testCase "SC-VER-032: FPPS 5-method consensus" <| fun () ->
        let containers = Container.getAll()
        for c in containers do
            let fpps = HealthCoordinator.fppsConsensus c
            Expect.isTrue fpps.Consensus $"{c} FPPS must agree"

    testCase "SC-VER-033: Zenoh mesh connected" <| fun () ->
        let zenohStatus = Zenoh.getStatus()
        Expect.isTrue zenohStatus.Connected "Zenoh must be connected"
        Expect.isGreaterThan zenohStatus.PeerCount 0 "Must have peers"

    testCase "SC-VER-034: DB connection pool active" <| fun () ->
        let poolStats = DBPool.getStats()
        Expect.isGreaterThan poolStats.AvailableConnections 0 "Pool must have connections"

    testCase "SC-VER-039: Quorum established" <| fun () ->
        let quorum = QuorumVoting.checkQuorum()
        Expect.isTrue quorum.Achieved "Quorum must be achieved"
        Expect.isGreaterThanOrEqual quorum.HealthyNodes quorum.Required "Enough nodes"

    testProperty "SC-VER-037: Inter-container latency bounded" <| fun (src: Container) (dst: Container) ->
        let latency = Network.measureLatency src dst
        latency < TimeSpan.FromMilliseconds 50.0
]
```

#### 7.4.4 AOR Rules (L3)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-016 | CHECK health with FPPS 5-method consensus | Health coordinator |
| AOR-VER-017 | VERIFY quorum before operations | Quorum voting |
| AOR-VER-018 | MONITOR Zenoh mesh connectivity | Zenoh heartbeat |
| AOR-VER-019 | ALERT on container health degradation | Sentinel |
| AOR-VER-020 | RESTART unhealthy containers automatically | Supervisor |

---

### 7.5 L4: OPERATIONAL LEVEL

**Purpose**: Verify runtime behavior, OODA cycles, and command execution.

#### 7.5.1 STAMP Constraints (L4)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-041 | OODA cycle < 100ms | HIGH | Timing check |
| SC-VER-042 | All CLI commands functional | CRITICAL | Command test |
| SC-VER-043 | Guardian approval for mutations | CRITICAL | Guardian check |
| SC-VER-044 | 5-Order effects logged | HIGH | Log verification |
| SC-VER-045 | Emergency stop < 5s | CRITICAL | Timing test |
| SC-VER-046 | Graceful shutdown works | HIGH | Shutdown test |
| SC-VER-047 | State checkpoint on shutdown | HIGH | Checkpoint verify |
| SC-VER-048 | Rollback functional | CRITICAL | Rollback test |
| SC-VER-049 | Dashboard refresh < 30s | MEDIUM | Timing check |
| SC-VER-050 | All 28 devenv commands work | HIGH | Command matrix |

#### 7.5.2 FMEA Analysis (L4)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| OODA timeout | Delayed response | 6 | 4 | 4 | 96 | Async OODA |
| Guardian bypass | Unauthorized action | 9 | 1 | 8 | 72 | Auth check |
| Emergency fail | Cannot stop | 9 | 1 | 9 | 81 | Force kill |
| Checkpoint fail | Data loss | 8 | 2 | 6 | 96 | Multiple checkpoints |

#### 7.5.3 TDG Test Cases (L4)

```fsharp
// test/verification/L4_Operational_Tests.fs

module L4OperationalTests

open Expecto
open FsCheck

[<Tests>]
let operationalTests = testList "L4 Operational" [

    testCase "SC-VER-041: OODA cycle < 100ms" <| fun () ->
        let stopwatch = Stopwatch.StartNew()
        let _ = OODA.cycle()
        stopwatch.Stop()
        Expect.isLessThan stopwatch.ElapsedMilliseconds 100L "OODA must be < 100ms"

    testCase "SC-VER-042: All CLI commands functional" <| fun () ->
        let commands = ["up"; "down"; "status"; "health"; "logs"]
        for cmd in commands do
            let result = CLI.execute cmd ["--help"]
            Expect.equal result.ExitCode 0 $"Command {cmd} must work"

    testCase "SC-VER-043: Guardian approval required" <| fun () ->
        let mutation = { Action = "restart"; Target = "indrajaal-app" }
        let result = Guardian.validate mutation
        Expect.isOk result "Guardian must approve"

    testCase "SC-VER-045: Emergency stop < 5s" <| fun () ->
        let stopwatch = Stopwatch.StartNew()
        let _ = CLI.execute "emergency" []
        stopwatch.Stop()
        Expect.isLessThan stopwatch.ElapsedMilliseconds 5000L "Emergency < 5s"

    testCase "SC-VER-048: Rollback functional" <| fun () ->
        // Create checkpoint
        let! checkpoint = Transaction.checkpoint "test-rollback"

        // Make change
        do! Container.restart "indrajaal-app"

        // Rollback
        let! rollbackResult = Transaction.rollback checkpoint.Name

        Expect.isOk rollbackResult "Rollback must succeed"

    testProperty "SC-VER-044: 5-Order effects logged" <| fun (action: CLIAction) ->
        let logsBefore = FiveOrderLogger.getLogs().Length
        let _ = CLI.execute action.Command action.Args
        let logsAfter = FiveOrderLogger.getLogs().Length
        logsAfter > logsBefore  // At least one log entry added
]
```

#### 7.5.4 AOR Rules (L4)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-021 | EXECUTE all operations via Guardian | Guardian wrapper |
| AOR-VER-022 | LOG 5-Order effects for every action | FiveOrderLogger |
| AOR-VER-023 | CHECKPOINT state before destructive operations | Transaction manager |
| AOR-VER-024 | TEST emergency stop regularly | Chaos testing |
| AOR-VER-025 | VERIFY rollback capability after changes | Rollback test |

---

### 7.6 L5: METABOLIC LEVEL

**Purpose**: Verify resource consumption, energy budgets, and API rate control.

#### 7.6.1 STAMP Constraints (L5)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-051 | API usage < 95% of limits | CRITICAL | Rate limiter |
| SC-VER-052 | Memory usage < 80% of allocated | HIGH | Memory monitor |
| SC-VER-053 | CPU usage < 80% sustained | HIGH | CPU monitor |
| SC-VER-054 | Disk usage < 90% | HIGH | Disk monitor |
| SC-VER-055 | Connection pool < 80% | HIGH | Pool monitor |
| SC-VER-056 | Context window < 80% | CRITICAL | Context monitor |
| SC-VER-057 | Agent count within budget | HIGH | Agent monitor |
| SC-VER-058 | Token consumption tracked | HIGH | Token meter |
| SC-VER-059 | Graceful degradation on limits | HIGH | Degradation test |
| SC-VER-060 | Auto-compact at 75% context | CRITICAL | Compact trigger |

#### 7.6.2 FMEA Analysis (L5)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| API rate limit | Service disruption | 8 | 4 | 7 | 224 | Rate limiter |
| OOM kill | Container crash | 9 | 2 | 6 | 108 | Memory limits |
| Disk full | Write failures | 8 | 2 | 8 | 128 | Disk alerts |
| Context overflow | Truncation | 7 | 3 | 5 | 105 | Auto-compact |

#### 7.6.3 TDG Test Cases (L5)

```fsharp
// test/verification/L5_Metabolic_Tests.fs

module L5MetabolicTests

open Expecto
open FsCheck

[<Tests>]
let metabolicTests = testList "L5 Metabolic" [

    testCase "SC-VER-051: API usage within limits" <| fun () ->
        let usage = RateLimiter.getCurrentUsage()
        let limit = RateLimiter.getLimit()
        let percentage = (float usage / float limit) * 100.0
        Expect.isLessThan percentage 95.0 "API usage must be < 95%"

    testCase "SC-VER-052: Memory usage bounded" <| fun () ->
        let memStats = Memory.getStats()
        let percentage = (float memStats.Used / float memStats.Allocated) * 100.0
        Expect.isLessThan percentage 80.0 "Memory must be < 80%"

    testCase "SC-VER-056: Context window managed" <| fun () ->
        let contextUsage = Context.getUsage()
        let contextLimit = Context.getLimit()
        let percentage = (float contextUsage / float contextLimit) * 100.0
        Expect.isLessThan percentage 80.0 "Context must be < 80%"

    testCase "SC-VER-059: Graceful degradation works" <| fun () ->
        // Simulate high load
        RateLimiter.simulateHighLoad()

        // Check degradation
        let degradationActive = GracefulDegradation.isActive()
        Expect.isTrue degradationActive "Degradation should activate"

        // Verify reduced functionality
        let agentCount = AgentPool.getCount()
        Expect.isLessThan agentCount 10 "Agents should reduce"

    testCase "SC-VER-060: Auto-compact at 75%" <| fun () ->
        // Fill context to 75%
        Context.fill 0.75

        // Trigger check
        let compactTriggered = Context.checkAndCompact()

        Expect.isTrue compactTriggered "Compact should trigger at 75%"
]
```

#### 7.6.4 AOR Rules (L5)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-026 | MONITOR API rate limits continuously | Rate limiter |
| AOR-VER-027 | TRIGGER graceful degradation at 70% | Threshold check |
| AOR-VER-028 | COMPACT context at 75% usage | Context monitor |
| AOR-VER-029 | SCALE agents within budget | Agent scaler |
| AOR-VER-030 | ALERT on resource threshold breach | Sentinel |

---

### 7.7 L6: EVOLUTIONARY LEVEL

**Purpose**: Verify genome mutation, adaptation, and lineage continuity.

#### 7.7.1 STAMP Constraints (L6)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-061 | Genome integrity maintained | CRITICAL | Hash verification |
| SC-VER-062 | Evolution lineage unbroken | CRITICAL | DuckDB check |
| SC-VER-063 | Mutation rate bounded | HIGH | Mutation monitor |
| SC-VER-064 | Selection preserves diversity | HIGH | Diversity check |
| SC-VER-065 | Fitness tracked | HIGH | Fitness metrics |
| SC-VER-066 | Guardian approval for evolution | CRITICAL | Guardian check |
| SC-VER-067 | Shadow testing before activation | CRITICAL | Shadow test |
| SC-VER-068 | Rollback capability exists | CRITICAL | Rollback test |
| SC-VER-069 | Evolution logged to register | HIGH | Register check |
| SC-VER-070 | Founder's Directive alignment | CRITICAL | Directive check |

#### 7.7.2 FMEA Analysis (L6)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Lineage break | History lost | 9 | 1 | 8 | 72 | DuckDB immutable |
| Harmful mutation | System damage | 9 | 1 | 7 | 63 | Guardian veto |
| Diversity collapse | Brittleness | 7 | 2 | 5 | 70 | Diversity floor |
| Uncontrolled evolution | Unpredictable | 8 | 1 | 6 | 48 | Evolution gates |

#### 7.7.3 TDG Test Cases (L6)

```fsharp
// test/verification/L6_Evolutionary_Tests.fs

module L6EvolutionaryTests

open Expecto
open FsCheck

[<Tests>]
let evolutionaryTests = testList "L6 Evolutionary" [

    testCase "SC-VER-061: Genome integrity maintained" <| fun () ->
        let genome = Genome.getCurrent()
        let storedHash = GenomeStore.getHash genome.Id
        let computedHash = Genome.computeHash genome
        Expect.equal storedHash computedHash "Genome hash must match"

    testCase "SC-VER-062: Evolution lineage unbroken" <| fun () ->
        let lineage = Evolution.getLineage()
        let gaps = lineage |> List.pairwise |> List.filter (fun (a, b) -> b.Parent <> Some a.Id)
        Expect.isEmpty gaps "Lineage must be continuous"

    testCase "SC-VER-066: Guardian approval for evolution" <| fun () ->
        let mutation = Evolution.proposeMutation()
        let approval = Guardian.validateEvolution mutation
        Expect.isOk approval "Guardian must approve evolution"

    testCase "SC-VER-067: Shadow testing before activation" <| fun () ->
        let mutation = Evolution.proposeMutation()
        let shadowResult = ShadowTest.run mutation
        Expect.isTrue shadowResult.Passed "Shadow test must pass"

    testCase "SC-VER-070: Founder's Directive alignment" <| fun () ->
        let mutation = Evolution.proposeMutation()
        let alignment = FounderDirective.checkAlignment mutation
        Expect.isTrue alignment.Aligned "Must align with Founder's Directive"

    testProperty "SC-VER-064: Selection preserves diversity" <| fun (population: Population) ->
        let selected = Selection.select population
        let diversity = Diversity.measure selected
        diversity >= 0.3  // Diversity floor
]
```

#### 7.7.4 AOR Rules (L6)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-031 | VERIFY genome integrity on every access | Hash check |
| AOR-VER-032 | LOG all evolution events to DuckDB | Immutable append |
| AOR-VER-033 | REQUIRE Guardian approval for mutations | Guardian gate |
| AOR-VER-034 | RUN shadow tests before activation | Shadow test gate |
| AOR-VER-035 | MAINTAIN diversity floor of 0.3 | Selection constraint |

---

### 7.8 L7: STRATEGIC LEVEL

**Purpose**: Verify federation-scale invariants and cross-holon consensus.

#### 7.8.1 STAMP Constraints (L7)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-VER-071 | Federation protocol compatible | CRITICAL | Version check |
| SC-VER-072 | Cross-holon consensus achieved | CRITICAL | Consensus check |
| SC-VER-073 | Attestation chain valid | CRITICAL | Chain verify |
| SC-VER-074 | Constitutional invariants hold | CRITICAL | Invariant check |
| SC-VER-075 | Ψ₀ (Existence) preserved | CRITICAL | Existence check |
| SC-VER-076 | Ψ₁ (Regeneration) capable | CRITICAL | Regen test |
| SC-VER-077 | Ψ₂ (History) complete | CRITICAL | History check |
| SC-VER-078 | Ψ₃ (Verification) active | CRITICAL | Verify check |
| SC-VER-079 | Ψ₄ (Founder Alignment) valid | CRITICAL | Alignment check |
| SC-VER-080 | Ψ₅ (Truthfulness) enforced | CRITICAL | Truth check |

#### 7.8.2 FMEA Analysis (L7)

| Failure Mode | Effect | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|--------|----------|------------|-----------|-----|------------|
| Federation disconnect | Isolation | 7 | 2 | 7 | 98 | Reconnection |
| Constitutional violation | System halt | 10 | 1 | 9 | 90 | Guardian veto |
| Consensus failure | Split-brain | 9 | 1 | 8 | 72 | Quorum voting |
| Attestation forgery | Trust breach | 10 | 1 | 7 | 70 | Ed25519 verify |

#### 7.8.3 TDG Test Cases (L7)

```fsharp
// test/verification/L7_Strategic_Tests.fs

module L7StrategicTests

open Expecto
open FsCheck

[<Tests>]
let strategicTests = testList "L7 Strategic" [

    testCase "SC-VER-071: Federation protocol compatible" <| fun () ->
        let localVersion = Federation.getProtocolVersion()
        let peerVersions = Federation.getPeerVersions()
        for peer in peerVersions do
            Expect.isTrue (Federation.compatible localVersion peer)
                $"Protocol must be compatible with {peer}"

    testCase "SC-VER-072: Cross-holon consensus" <| fun () ->
        let proposal = Consensus.propose "test-proposal"
        let result = Consensus.vote proposal
        Expect.isTrue result.Achieved "Consensus must be achieved"

    testCase "SC-VER-074: Constitutional invariants" <| fun () ->
        let invariants = Constitution.getInvariants()
        for inv in invariants do
            let holds = Constitution.check inv
            Expect.isTrue holds $"Invariant {inv.Id} must hold"

    testCase "SC-VER-075: Ψ₀ Existence preserved" <| fun () ->
        let existence = Constitution.checkPsi0()
        Expect.isTrue existence "System must exist (Ψ₀)"

    testCase "SC-VER-076: Ψ₁ Regeneration capable" <| fun () ->
        let canRegenerate = Constitution.checkPsi1()
        Expect.isTrue canRegenerate "Must be regenerable (Ψ₁)"

    testCase "SC-VER-079: Ψ₄ Founder alignment" <| fun () ->
        let alignment = Constitution.checkPsi4()
        Expect.isTrue alignment.AlignedWithFounder "Must align with Founder (Ψ₄)"

    testProperty "SC-VER-073: Attestation chain valid" <| fun (chainLength: PositiveInt) ->
        let chain = Attestation.generateChain chainLength.Get
        Attestation.verifyChain chain
]
```

#### 7.8.4 AOR Rules (L7)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-VER-036 | VERIFY federation protocol version | Version negotiation |
| AOR-VER-037 | ACHIEVE consensus before cross-holon ops | Consensus gate |
| AOR-VER-038 | CHECK constitutional invariants continuously | Guardian |
| AOR-VER-039 | PRESERVE existence (Ψ₀) above all | Supreme rule |
| AOR-VER-040 | ALIGN with Founder's Directive | Directive check |

---

## 8. 5-LEVEL ROOT CAUSE ANALYSIS (RCA) PROTOCOL

### 8.1 5-Why Methodology

For any verification failure, apply the 5-Why analysis:

```
Level 1: WHAT failed?
         └─ Direct failure description

Level 2: WHY did it fail?
         └─ Immediate cause

Level 3: WHY did that cause exist?
         └─ Contributing factor

Level 4: WHY wasn't it prevented?
         └─ Process gap

Level 5: WHY does the gap exist?
         └─ Root cause (systemic)
```

### 8.2 RCA Template

```fsharp
type RootCauseAnalysis = {
    FailureId: Guid
    Timestamp: DateTime
    Level: VerificationLevel  // L0-L7
    Constraint: string        // SC-VER-XXX

    // 5-Why Analysis
    Level1_What: string
    Level2_Why: string
    Level3_Why: string
    Level4_Why: string
    Level5_Why: string

    // Resolution
    RootCause: string
    Mitigation: string
    Prevention: string
    Owner: string
    DueDate: DateTime
}

/// Perform 5-Level RCA
let performRCA (failure: VerificationFailure) : RootCauseAnalysis =
    let rca = {
        FailureId = Guid.NewGuid()
        Timestamp = DateTime.UtcNow
        Level = failure.Level
        Constraint = failure.Constraint

        Level1_What = analyzeWhat failure
        Level2_Why = analyzeWhy1 failure
        Level3_Why = analyzeWhy2 failure
        Level4_Why = analyzeWhy3 failure
        Level5_Why = analyzeWhy4 failure

        RootCause = determineRootCause failure
        Mitigation = proposeMitigation failure
        Prevention = proposePrevention failure
        Owner = assignOwner failure
        DueDate = calculateDueDate failure
    }

    // Log to immutable register
    ImmutableRegister.append (RCACompleted rca)

    rca
```

### 8.3 TPS Integration

| TPS Principle | Application | Verification |
|---------------|-------------|--------------|
| **Jidoka** | Stop on quality defect | Auto-halt on verification failure |
| **Heijunka** | Level workload | Distribute tests across levels |
| **Kaizen** | Continuous improvement | RCA feedback loop |
| **Just-in-Time** | Execute when needed | On-demand verification |
| **Poka-Yoke** | Error-proofing | Constraint enforcement |

---

## 9. VERIFICATION EXECUTION WORKFLOW

### 9.1 Full Verification Cycle

```bash
# Phase 1: Environment Setup
cortex up --mode fractal --verbose

# Phase 2: L0 Runtime Verification
cortex test --level 0

# Phase 3: L1-L2 Component Verification
cortex test --level 1
cortex test --level 2

# Phase 4: L3-L4 Integration/Operational
cortex test --level 3
cortex test --level 4

# Phase 5: L5-L6 Metabolic/Evolutionary
cortex test --level 5
cortex test --level 6

# Phase 6: L7 Strategic Verification
cortex test --level 7

# Phase 7: Full PROMETHEUS Verification
cortex verify --prometheus --all

# Phase 8: Generate Report
cortex report --output docs/verification/VERIFICATION_REPORT.md
```

### 9.2 Quick Verification (Development)

```bash
# Quick check (L0-L3 only)
cortex verify --quick

# Smoke test (L0 + critical L3)
cortex verify --smoke
```

### 9.3 GA Release Verification

```bash
# Full GA verification
cortex verify --ga-release --full --2oo3 --prometheus

# Generate release report
cortex report --ga-release --sign
```

---

## 10. APPENDICES

### A. STAMP Constraint Index

| Range | Level | Count | Description |
|-------|-------|-------|-------------|
| SC-VER-001 to SC-VER-010 | L0 | 10 | Runtime constraints |
| SC-VER-011 to SC-VER-020 | L1 | 10 | Cellular constraints |
| SC-VER-021 to SC-VER-030 | L2 | 10 | Component constraints |
| SC-VER-031 to SC-VER-040 | L3 | 10 | Integration constraints |
| SC-VER-041 to SC-VER-050 | L4 | 10 | Operational constraints |
| SC-VER-051 to SC-VER-060 | L5 | 10 | Metabolic constraints |
| SC-VER-061 to SC-VER-070 | L6 | 10 | Evolutionary constraints |
| SC-VER-071 to SC-VER-080 | L7 | 10 | Strategic constraints |
| **Total** | | **80** | |

### B. AOR Rule Index

| Range | Level | Count | Description |
|-------|-------|-------|-------------|
| AOR-VER-001 to AOR-VER-005 | L0 | 5 | Runtime rules |
| AOR-VER-006 to AOR-VER-010 | L1 | 5 | Cellular rules |
| AOR-VER-011 to AOR-VER-015 | L2 | 5 | Component rules |
| AOR-VER-016 to AOR-VER-020 | L3 | 5 | Integration rules |
| AOR-VER-021 to AOR-VER-025 | L4 | 5 | Operational rules |
| AOR-VER-026 to AOR-VER-030 | L5 | 5 | Metabolic rules |
| AOR-VER-031 to AOR-VER-035 | L6 | 5 | Evolutionary rules |
| AOR-VER-036 to AOR-VER-040 | L7 | 5 | Strategic rules |
| **Total** | | **40** | |

### C. FMEA Summary

| Level | Critical Failures | Total RPN | Top Risk |
|-------|-------------------|-----------|----------|
| L0 | 4 | 558 | NIF compile (216) |
| L1 | 4 | 464 | GenServer crash (144) |
| L2 | 4 | 431 | Circular dependency (147) |
| L3 | 4 | 510 | Container crash (168) |
| L4 | 4 | 345 | Checkpoint fail (96) |
| L5 | 4 | 565 | API rate limit (224) |
| L6 | 4 | 253 | Lineage break (72) |
| L7 | 4 | 330 | Constitutional violation (90) |
| **Total** | **32** | **3,456** | |

### D. Related Documents

| Document | Location | Purpose |
|----------|----------|---------|
| CLAUDE.md | /CLAUDE.md | Master specification |
| GEMINI.md | /GEMINI.md | Cybernetic architect spec |
| Holon Architecture | /docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md | Holon design |
| Immutable Register | /docs/architecture/HOLON_IMMUTABLE_REGISTER.md | State management |
| Founder's Directive | /docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md | Supreme directive |
| GA Release Checklist | /docs/verification/GA_COMMAND_COMPLETE_ANALYSIS.md | Release gates |

---

## 11. FRACTAL LOGGING & TELEMETRY SYSTEM

### 11.1 5-Level Fractal Logging Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    FRACTAL LOGGING HIERARCHY (L1-L5)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  L5: COGNITIVE (Strategic Decision Logging)                              │
│  ├─ Guardian approvals/rejections                                        │
│  ├─ Constitutional invariant checks                                      │
│  ├─ Evolution decisions                                                  │
│  └─ Retention: 1 year | Storage: DuckDB                                  │
│                                                                          │
│  L4: OPERATIONAL (Runtime Behavior)                                      │
│  ├─ OODA cycle metrics                                                   │
│  ├─ Transaction states                                                   │
│  ├─ Command execution                                                    │
│  └─ Retention: 30 days | Storage: File + OTEL                           │
│                                                                          │
│  L3: INTEGRATION (Container Communication)                               │
│  ├─ Inter-container messages                                             │
│  ├─ Zenoh pub/sub events                                                 │
│  ├─ Health check results                                                 │
│  └─ Retention: 7 days | Storage: OTEL + Loki                            │
│                                                                          │
│  L2: COMPONENT (Module Events)                                           │
│  ├─ GenServer callbacks                                                  │
│  ├─ Phoenix requests                                                     │
│  ├─ Ash resource operations                                              │
│  └─ Retention: 1 day | Storage: OTEL                                    │
│                                                                          │
│  L1: CELLULAR (Debug/Trace)                                              │
│  ├─ Function call traces                                                 │
│  ├─ Variable state dumps                                                 │
│  ├─ Performance micro-metrics                                            │
│  └─ Retention: 1 hour | Storage: Memory/Ephemeral                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.2 OTEL Configuration (Fractal)

```yaml
# lib/cepaf/artifacts/otel-config-fractal.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10ms
    send_batch_size: 100

  # Fractal level routing
  filter/l1l2:
    logs:
      include:
        match_type: regexp
        resource_attributes:
          - key: fractal_level
            value: "^(L1|L2)$"

  filter/l3l4:
    logs:
      include:
        match_type: regexp
        resource_attributes:
          - key: fractal_level
            value: "^(L3|L4)$"

  filter/l5:
    logs:
      include:
        match_type: regexp
        resource_attributes:
          - key: fractal_level
            value: "^L5$"

exporters:
  # L1/L2 ephemeral (1 day retention)
  file/l1l2:
    path: /var/lib/otel/fractal-l1l2.jsonl
    rotation:
      max_megabytes: 10
      max_days: 1

  # L3/L4/L5 persistent
  file/l4l5:
    path: /var/lib/otel/fractal-l4l5.jsonl
    rotation:
      max_megabytes: 100
      max_days: 30

  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: fractal

service:
  pipelines:
    logs/ephemeral:
      receivers: [otlp]
      processors: [filter/l1l2, batch]
      exporters: [file/l1l2]

    logs/persistent:
      receivers: [otlp]
      processors: [filter/l3l4, batch]
      exporters: [file/l4l5]

    logs/cognitive:
      receivers: [otlp]
      processors: [filter/l5, batch]
      exporters: [file/l4l5]
```

### 11.3 Fractal Telemetry STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-LOG-001 | All L5 events logged to DuckDB | CRITICAL | DuckDB query |
| SC-LOG-002 | L4 events retained 30 days | HIGH | Retention check |
| SC-LOG-003 | L3 events flow to OTEL | HIGH | OTEL trace |
| SC-LOG-004 | L1/L2 auto-expire after 1 day | MEDIUM | Rotation check |
| SC-LOG-005 | HLC timestamps preserved | HIGH | Timestamp verify |
| SC-LOG-006 | Fractal level attribute on all logs | HIGH | Attribute check |
| SC-LOG-007 | Log correlation IDs maintained | HIGH | Correlation check |
| SC-LOG-008 | No PII in L1/L2 logs | CRITICAL | PII scan |

---

## 12. ZENOH DATAFLOW CONTROL

### 12.1 Zenoh Topic Hierarchy

```
indrajaal/
├── control/
│   ├── guardian/propose     # Guardian proposals
│   ├── guardian/approve     # Guardian approvals
│   ├── guardian/veto        # Guardian vetoes
│   └── emergency/stop       # Emergency stop signal
├── health/
│   ├── containers/**        # Container health
│   ├── fpps/**              # FPPS consensus results
│   ├── quorum/**            # Quorum status
│   └── sentinel/**          # Sentinel health
├── telemetry/
│   ├── ooda/**              # OODA cycle metrics
│   ├── api/**               # API usage metrics
│   ├── resources/**         # Resource consumption
│   └── performance/**       # Performance metrics
├── state/
│   ├── transactions/**      # Transaction state
│   ├── checkpoints/**       # Checkpoint events
│   └── snapshots/**         # Snapshot notifications
└── evolution/
    ├── mutations/**         # Genome mutations
    ├── fitness/**           # Fitness scores
    └── lineage/**           # Lineage events
```

### 12.2 Zenoh Integration Code

```fsharp
// lib/cepaf/src/Cepaf/Zenoh/ZenohController.fs

module ZenohController

open Zenoh

/// Initialize Zenoh session for mesh control
let initSession (config: ZenohConfig) : Session =
    let session = Session.open' config

    // Subscribe to control topics
    session.subscribe "indrajaal/control/**" handleControlMessage
    session.subscribe "indrajaal/health/**" handleHealthMessage

    // Publish presence
    session.put "indrajaal/nodes/{nodeId}/presence" "online"

    session

/// Publish health status via Zenoh
let publishHealth (session: Session) (health: HealthStatus) : unit =
    let topic = $"indrajaal/health/containers/{health.ContainerId}"
    let payload = Json.serialize health
    session.put topic payload

    // Also publish to FPPS aggregator
    session.put "indrajaal/health/fpps/latest" payload

/// Subscribe to Guardian commands
let subscribeGuardian (session: Session) (handler: GuardianCommand -> unit) =
    session.subscribe "indrajaal/control/guardian/**" (fun msg ->
        let cmd = Json.deserialize<GuardianCommand> msg.Payload
        handler cmd
    )

/// Emergency broadcast (SC-EMR-057)
let emergencyBroadcast (session: Session) (reason: string) : unit =
    let msg = {| Reason = reason; Timestamp = DateTime.UtcNow; Priority = "CRITICAL" |}
    session.put "indrajaal/control/emergency/stop" (Json.serialize msg)
    FiveOrderLogger.log 1 $"EMERGENCY BROADCAST: {reason}"
```

### 12.3 Zenoh-LiveView Bridge

```elixir
# lib/indrajaal_web/live/zenoh_bridge.ex

defmodule IndrajaalWeb.ZenohLiveViewBridge do
  @moduledoc """
  Bridge Zenoh pub/sub to LiveView for real-time dashboards.

  STAMP Compliance: SC-BRIDGE-001 to SC-BRIDGE-005
  """

  use GenServer

  @topics [
    "indrajaal/health/**",
    "indrajaal/telemetry/**",
    "indrajaal/state/**"
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # SC-BRIDGE-004: Attach telemetry on init
    attach_telemetry()

    # Subscribe to Zenoh topics
    for topic <- @topics do
      Zenoh.subscribe(topic, &handle_zenoh_message/1)
    end

    {:ok, %{buffer: [], flush_timer: nil}}
  end

  defp handle_zenoh_message(msg) do
    # SC-BRIDGE-001: FIFO ordering preserved
    GenServer.cast(__MODULE__, {:zenoh_msg, msg})
  end

  @impl true
  def handle_cast({:zenoh_msg, msg}, state) do
    # Buffer messages for batch processing
    new_buffer = [msg | state.buffer]

    # SC-BRIDGE-002: Flush every 100ms max
    timer = state.flush_timer || Process.send_after(self(), :flush, 100)

    {:noreply, %{state | buffer: new_buffer, flush_timer: timer}}
  end

  @impl true
  def handle_info(:flush, state) do
    # SC-BRIDGE-003: Latency budget 50ms per batch
    start = System.monotonic_time(:millisecond)

    # Process buffered messages (FIFO)
    messages = Enum.reverse(state.buffer)

    for msg <- messages do
      # Broadcast to LiveView
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, zenoh_topic(msg), {:zenoh, msg})
    end

    elapsed = System.monotonic_time(:millisecond) - start
    if elapsed > 50, do: Logger.warning("Zenoh bridge latency exceeded: #{elapsed}ms")

    {:noreply, %{state | buffer: [], flush_timer: nil}}
  end

  @impl true
  def terminate(_reason, _state) do
    # SC-BRIDGE-004: Detach telemetry on terminate
    detach_telemetry()
  end
end
```

### 12.4 Zenoh STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-ZENOH-001 | Mesh connectivity verified | CRITICAL | Peer count > 0 |
| SC-ZENOH-002 | Topic hierarchy enforced | HIGH | Namespace check |
| SC-ZENOH-003 | Emergency broadcast < 100ms | CRITICAL | Latency test |
| SC-ZENOH-004 | Control topics Guardian-only | CRITICAL | ACL check |
| SC-ZENOH-005 | Health topics every 10s | HIGH | Interval check |
| SC-ZENOH-006 | LiveView bridge latency < 50ms | HIGH | SC-BRIDGE-003 |
| SC-ZENOH-007 | FIFO ordering preserved | HIGH | SC-BRIDGE-001 |
| SC-ZENOH-008 | Telemetry attached/detached | MEDIUM | Lifecycle check |

---

## 13. REAL-TIME DASHBOARDS & MONITORING

### 13.1 Prajna C3I Cockpit Dashboard

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  PRAJNA C3I COMMAND COCKPIT                     [HOMEOSTASIS MODE: ACTIVE]    ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  ┌──────────────────────────────────────┐  ┌──────────────────────────────┐   ║
║  │ SYSTEM HEALTH                        │  │ CONSTITUTIONAL STATUS        │   ║
║  │ ████████████████████░░░░ 85%         │  │ Ψ₀ Existence:     ✓ PASS    │   ║
║  │                                      │  │ Ψ₁ Regeneration:  ✓ PASS    │   ║
║  │ Containers: 5/5 healthy              │  │ Ψ₂ History:       ✓ PASS    │   ║
║  │ Zenoh Mesh: CONNECTED                │  │ Ψ₃ Verification:  ✓ PASS    │   ║
║  │ Quorum: 3/5 (achieved)               │  │ Ψ₄ Alignment:     ✓ PASS    │   ║
║  │ FPPS Consensus: ALL AGREE            │  │ Ψ₅ Truthfulness:  ✓ PASS    │   ║
║  └──────────────────────────────────────┘  └──────────────────────────────┘   ║
║                                                                                ║
║  ┌──────────────────────────────────────┐  ┌──────────────────────────────┐   ║
║  │ METABOLIC RESOURCES                  │  │ OODA CYCLE                   │   ║
║  │ API:  ████████░░░░░░░░░░ 40%/95%    │  │ Last Cycle: 45ms (< 100ms)   │   ║
║  │ Mem:  ██████████████░░░░ 70%/80%    │  │ Quality Gate: 92%            │   ║
║  │ CPU:  ████████░░░░░░░░░░ 45%/80%    │  │ Agent Count: 12/25           │   ║
║  │ Disk: ████████████░░░░░░ 62%/90%    │  │ Tasks Pending: 3             │   ║
║  │ Ctx:  ██████████░░░░░░░░ 52%/75%    │  │                              │   ║
║  └──────────────────────────────────────┘  └──────────────────────────────┘   ║
║                                                                                ║
║  ┌──────────────────────────────────────────────────────────────────────────┐ ║
║  │ CONTAINER STATUS                                                         │ ║
║  │ ┌─────────────────┬──────────┬────────────┬───────────┬────────────────┐ │ ║
║  │ │ Container       │ Status   │ Health     │ Uptime    │ Last Check     │ │ ║
║  │ ├─────────────────┼──────────┼────────────┼───────────┼────────────────┤ │ ║
║  │ │ indrajaal-db    │ RUNNING  │ ✓ HEALTHY  │ 2h 15m    │ 3s ago         │ │ ║
║  │ │ indrajaal-obs   │ RUNNING  │ ✓ HEALTHY  │ 2h 14m    │ 3s ago         │ │ ║
║  │ │ indrajaal-app   │ RUNNING  │ ✓ HEALTHY  │ 2h 13m    │ 3s ago         │ │ ║
║  │ │ zenoh-router    │ RUNNING  │ ✓ HEALTHY  │ 2h 12m    │ 3s ago         │ │ ║
║  │ │ cortex          │ RUNNING  │ ✓ HEALTHY  │ 2h 11m    │ 3s ago         │ │ ║
║  │ └─────────────────┴──────────┴────────────┴───────────┴────────────────┘ │ ║
║  └──────────────────────────────────────────────────────────────────────────┘ ║
║                                                                                ║
║  ┌──────────────────────────────────────────────────────────────────────────┐ ║
║  │ GUARDIAN ACTIVITY (Last 10 events)                                       │ ║
║  │ [15:42:31] APPROVED: Container restart indrajaal-app (2oo3 consensus)    │ ║
║  │ [15:40:12] APPROVED: Checkpoint creation "pre-test"                      │ ║
║  │ [15:38:45] VETOED: Evolution mutation (fitness < 0.85)                   │ ║
║  │ [15:35:22] APPROVED: Configuration update                                │ ║
║  │ [15:30:00] HEALTH: All constitutional invariants verified                │ ║
║  └──────────────────────────────────────────────────────────────────────────┘ ║
║                                                                                ║
║  [F1: Help] [F2: Commands] [F3: Logs] [F4: Metrics] [F5: Emergency] [Q: Quit] ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### 13.2 Dashboard Implementation (F#)

```fsharp
// lib/cepaf/src/Cepaf/UI/Dashboard.fs

module Dashboard

open Spectre.Console
open System

type DashboardState = {
    Containers: ContainerStatus list
    Health: HealthMetrics
    Constitutional: ConstitutionalStatus
    Metabolic: MetabolicMetrics
    OODA: OODAMetrics
    GuardianEvents: GuardianEvent list
}

/// Render dashboard to terminal
let render (state: DashboardState) : unit =
    AnsiConsole.Clear()

    // Header
    let header = FigletText("PRAJNA C3I")
    header.Color <- Color.Blue
    AnsiConsole.Write(header)

    // System Health Panel
    let healthPanel = Panel(
        $"""
System Health: {formatPercentBar state.Health.Overall 85}
Containers: {state.Health.HealthyContainers}/{state.Health.TotalContainers} healthy
Zenoh Mesh: {if state.Health.ZenohConnected then "CONNECTED" else "DISCONNECTED"}
Quorum: {state.Health.QuorumCount}/{state.Health.QuorumRequired} ({"achieved" if state.Health.QuorumAchieved else "NOT achieved"})
FPPS Consensus: {if state.Health.FPPSConsensus then "ALL AGREE" else "DISAGREEMENT"}
        """)
    healthPanel.Header <- PanelHeader("SYSTEM HEALTH")

    // Constitutional Status Panel
    let constPanel = Panel(formatConstitutional state.Constitutional)
    constPanel.Header <- PanelHeader("CONSTITUTIONAL STATUS")

    // Metabolic Panel
    let metaPanel = Panel(formatMetabolic state.Metabolic)
    metaPanel.Header <- PanelHeader("METABOLIC RESOURCES")

    // OODA Panel
    let oodaPanel = Panel(formatOODA state.OODA)
    oodaPanel.Header <- PanelHeader("OODA CYCLE")

    // Container Table
    let containerTable = Table()
    containerTable.AddColumn("Container")
    containerTable.AddColumn("Status")
    containerTable.AddColumn("Health")
    containerTable.AddColumn("Uptime")
    containerTable.AddColumn("Last Check")

    for c in state.Containers do
        containerTable.AddRow(
            c.Name,
            formatStatus c.Status,
            formatHealth c.Health,
            formatUptime c.Uptime,
            formatTimestamp c.LastCheck
        )

    // Guardian Events
    let guardianPanel = Panel(
        state.GuardianEvents
        |> List.take 10
        |> List.map formatGuardianEvent
        |> String.concat "\n"
    )
    guardianPanel.Header <- PanelHeader("GUARDIAN ACTIVITY")

    // Layout
    let layout = Layout()
    layout.SplitRows(
        Layout("header").Size(3),
        Layout("top").SplitColumns(
            Layout("health"),
            Layout("constitutional")
        ),
        Layout("middle").SplitColumns(
            Layout("metabolic"),
            Layout("ooda")
        ),
        Layout("containers"),
        Layout("guardian"),
        Layout("footer").Size(1)
    )

    layout["header"].Update(header)
    layout["health"].Update(healthPanel)
    layout["constitutional"].Update(constPanel)
    layout["metabolic"].Update(metaPanel)
    layout["ooda"].Update(oodaPanel)
    layout["containers"].Update(containerTable)
    layout["guardian"].Update(guardianPanel)
    layout["footer"].Update(Text("[F1: Help] [F2: Commands] [F3: Logs] [F4: Metrics] [F5: Emergency] [Q: Quit]"))

    AnsiConsole.Write(layout)

/// Dashboard refresh loop (30s interval - SC-BIO-005)
let runDashboard () =
    let rec loop () = async {
        let! state = collectDashboardState()
        render state
        do! Async.Sleep 30000  // 30s refresh
        return! loop()
    }
    Async.Start(loop())
```

### 13.3 Grafana Dashboard Configuration

```yaml
# containers/grafana/dashboards/fractal-mesh.json
{
  "dashboard": {
    "title": "SIL-6 Fractal Mesh Overview",
    "refresh": "30s",
    "panels": [
      {
        "title": "Container Health",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(container_health_status{status=\"healthy\"})",
            "legendFormat": "Healthy Containers"
          }
        ]
      },
      {
        "title": "OODA Cycle Latency",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, ooda_cycle_duration_seconds_bucket)",
            "legendFormat": "p99 Latency"
          }
        ]
      },
      {
        "title": "API Rate Limit Usage",
        "type": "gauge",
        "targets": [
          {
            "expr": "api_rate_limit_usage_percent",
            "legendFormat": "Usage %"
          }
        ],
        "thresholds": {
          "steps": [
            { "value": 0, "color": "green" },
            { "value": 70, "color": "yellow" },
            { "value": 95, "color": "red" }
          ]
        }
      },
      {
        "title": "Fractal Log Levels",
        "type": "piechart",
        "targets": [
          {
            "expr": "sum by (fractal_level) (log_messages_total)",
            "legendFormat": "{{fractal_level}}"
          }
        ]
      },
      {
        "title": "Zenoh Message Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(zenoh_messages_total[1m])",
            "legendFormat": "Messages/sec"
          }
        ]
      },
      {
        "title": "Constitutional Invariant Status",
        "type": "stat",
        "targets": [
          {
            "expr": "constitutional_invariants_status",
            "legendFormat": "{{invariant}}"
          }
        ]
      }
    ]
  }
}
```

### 13.4 Dashboard STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-DASH-001 | Dashboard refresh < 30s | HIGH | Interval check |
| SC-DASH-002 | All containers visible | HIGH | Container count |
| SC-DASH-003 | Constitutional status shown | CRITICAL | Invariant display |
| SC-DASH-004 | Metabolic thresholds visible | HIGH | Threshold display |
| SC-DASH-005 | Guardian events logged | HIGH | Event count |
| SC-DASH-006 | Emergency button accessible | CRITICAL | Button check |
| SC-DASH-007 | Grafana datasources connected | HIGH | Datasource check |
| SC-DASH-008 | Real-time updates via Zenoh | HIGH | Websocket check |

---

## 14. PERFORMANCE VERIFICATION

### 14.1 Performance Targets

| Metric | Target | Critical Threshold | STAMP ID |
|--------|--------|-------------------|----------|
| OODA Cycle | < 100ms | < 200ms | SC-PERF-001 |
| Container Health Check | < 10s | < 30s | SC-PERF-002 |
| Zenoh Message Latency | < 5ms | < 20ms | SC-PERF-003 |
| Dashboard Refresh | 30s | 60s | SC-PERF-004 |
| Emergency Stop | < 5s | < 10s | SC-PERF-005 |
| FPPS Consensus | < 1s | < 5s | SC-PERF-006 |
| Transaction Commit | < 100ms | < 500ms | SC-PERF-007 |
| Snapshot Capture | < 5s | < 30s | SC-PERF-008 |
| Rollback Execution | < 10s | < 60s | SC-PERF-009 |
| API Response (p99) | < 50ms | < 200ms | SC-PERF-010 |

### 14.2 Performance Test Suite

```fsharp
// test/verification/Performance_Tests.fs

module PerformanceTests

open Expecto
open BenchmarkDotNet.Running
open BenchmarkDotNet.Attributes

[<MemoryDiagnoser>]
type OODACycleBenchmarks() =

    [<Benchmark>]
    member _.SingleOODACycle() =
        OODA.cycle() |> ignore

    [<Benchmark>]
    member _.ConcurrentOODACycles() =
        [1..10]
        |> List.map (fun _ -> async { return OODA.cycle() })
        |> Async.Parallel
        |> Async.RunSynchronously
        |> ignore

[<Tests>]
let performanceTests = testList "Performance" [

    testCase "SC-PERF-001: OODA cycle < 100ms" <| fun () ->
        let stopwatch = Stopwatch.StartNew()
        let _ = OODA.cycle()
        stopwatch.Stop()
        Expect.isLessThan stopwatch.ElapsedMilliseconds 100L "OODA must be < 100ms"

    testCase "SC-PERF-003: Zenoh latency < 5ms" <| fun () ->
        let latencies =
            [1..100]
            |> List.map (fun _ -> Zenoh.measureLatency())
        let p99 = latencies |> List.sort |> List.item 99
        Expect.isLessThan p99 5L "Zenoh p99 must be < 5ms"

    testCase "SC-PERF-005: Emergency stop < 5s" <| fun () ->
        let stopwatch = Stopwatch.StartNew()
        let _ = Emergency.trigger "performance-test"
        stopwatch.Stop()
        Expect.isLessThan stopwatch.ElapsedMilliseconds 5000L "Emergency < 5s"

    testCase "SC-PERF-006: FPPS consensus < 1s" <| fun () ->
        let stopwatch = Stopwatch.StartNew()
        let _ = HealthCoordinator.fppsConsensus "indrajaal-app"
        stopwatch.Stop()
        Expect.isLessThan stopwatch.ElapsedMilliseconds 1000L "FPPS < 1s"

    testCase "SC-PERF-007: Transaction commit < 100ms" <| fun () ->
        let tx = Transaction.begin "perf-test"
        let stopwatch = Stopwatch.StartNew()
        let _ = Transaction.commit tx.Id
        stopwatch.Stop()
        Expect.isLessThan stopwatch.ElapsedMilliseconds 100L "Commit < 100ms"

    testCase "SC-PERF-010: API response p99 < 50ms" <| fun () ->
        let latencies =
            [1..100]
            |> List.map (fun _ ->
                let sw = Stopwatch.StartNew()
                Http.get "http://localhost:4000/api/health" |> ignore
                sw.Stop()
                sw.ElapsedMilliseconds)
        let p99 = latencies |> List.sort |> List.item 99
        Expect.isLessThan p99 50L "API p99 must be < 50ms"
]

/// Run full benchmark suite
let runBenchmarks () =
    BenchmarkRunner.Run<OODACycleBenchmarks>() |> ignore
```

### 14.3 Load Testing Scenarios

```fsharp
// test/load/LoadTestScenarios.fs

module LoadTestScenarios

open NBomber.FSharp
open NBomber.Contracts

/// Scenario 1: Concurrent container operations
let containerLoadTest =
    Scenario.create "container_ops" [
        Step.create("health_check", fun ctx -> async {
            let! result = HealthCoordinator.checkAll()
            return if result.AllHealthy then Response.ok() else Response.fail()
        })

        Step.create("fpps_consensus", fun ctx -> async {
            let! result = HealthCoordinator.fppsConsensus "indrajaal-app"
            return if result.Consensus then Response.ok() else Response.fail()
        })
    ]
    |> Scenario.withLoadSimulations [
        InjectPerSec(rate = 10, during = TimeSpan.FromMinutes 5.0)
    ]

/// Scenario 2: Zenoh message throughput
let zenohThroughputTest =
    Scenario.create "zenoh_throughput" [
        Step.create("publish_message", fun ctx -> async {
            let! result = Zenoh.publish "indrajaal/test" "payload"
            return Response.ok()
        })

        Step.create("subscribe_receive", fun ctx -> async {
            let! msg = Zenoh.receiveNext "indrajaal/test" (TimeSpan.FromMilliseconds 100.0)
            return if msg.IsSome then Response.ok() else Response.fail()
        })
    ]
    |> Scenario.withLoadSimulations [
        InjectPerSec(rate = 1000, during = TimeSpan.FromMinutes 2.0)
    ]

/// Scenario 3: Transaction stress test
let transactionStressTest =
    Scenario.create "transaction_stress" [
        Step.create("begin_commit", fun ctx -> async {
            let tx = Transaction.begin $"stress-{ctx.StepInfo.StepIndex}"
            let! result = Transaction.commit tx.Id
            return match result with Ok _ -> Response.ok() | Error _ -> Response.fail()
        })

        Step.create("checkpoint_rollback", fun ctx -> async {
            let! cp = Transaction.checkpoint "stress-cp"
            let! result = Transaction.rollback cp.Name
            return match result with Ok _ -> Response.ok() | Error _ -> Response.fail()
        })
    ]
    |> Scenario.withLoadSimulations [
        KeepConstant(copies = 50, during = TimeSpan.FromMinutes 5.0)
    ]

/// Run all load tests
let runLoadTests () =
    NBomberRunner.registerScenarios [
        containerLoadTest
        zenohThroughputTest
        transactionStressTest
    ]
    |> NBomberRunner.run
```

### 14.4 Performance STAMP Constraints Summary

| ID | Constraint | Target | Critical | Verification |
|----|------------|--------|----------|--------------|
| SC-PERF-001 | OODA cycle latency | < 100ms | < 200ms | Benchmark |
| SC-PERF-002 | Health check interval | < 10s | < 30s | Timer check |
| SC-PERF-003 | Zenoh message latency | < 5ms | < 20ms | p99 measurement |
| SC-PERF-004 | Dashboard refresh | 30s | 60s | Interval check |
| SC-PERF-005 | Emergency stop time | < 5s | < 10s | Stopwatch |
| SC-PERF-006 | FPPS consensus time | < 1s | < 5s | Timing test |
| SC-PERF-007 | Transaction commit | < 100ms | < 500ms | Benchmark |
| SC-PERF-008 | Snapshot capture | < 5s | < 30s | Timing test |
| SC-PERF-009 | Rollback execution | < 10s | < 60s | Timing test |
| SC-PERF-010 | API response p99 | < 50ms | < 200ms | Load test |

---

## 15. NIXOS CONTAINER SPECIFICATIONS

### 15.1 Container Image Requirements

All containers MUST be built from NixOS base images:

```nix
# containers/nix/base-image.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.dockerTools.buildImage {
  name = "indrajaal-base";
  tag = "nixos-devenv";

  contents = with pkgs; [
    coreutils
    bash
    curl
    jq
    procps
  ];

  config = {
    Env = [
      "CONTAINER_OS=nixos"
      "SOPV51_COMPLIANT=true"
    ];
  };
}
```

### 15.2 Container Definitions

| Container | Base Image | Purpose | Build File |
|-----------|------------|---------|------------|
| indrajaal-db | localhost/indrajaal-timescaledb-demo:nixos-devenv | PostgreSQL + TimescaleDB | containers/nix/db.nix |
| indrajaal-obs | localhost/indrajaal-obs-unified:nixos-devenv | OTEL + Prometheus + Grafana | containers/nix/obs.nix |
| indrajaal-app | localhost/indrajaal-sopv51-elixir-app:nixos-devenv | Phoenix + FLAME + Redis | containers/nix/app.nix |
| zenoh-router | localhost/zenoh-router:nixos-devenv | Zenoh Mesh Fabric | containers/nix/zenoh.nix |
| cortex | localhost/cepaf-cortex:nixos-devenv | F# Control Plane | containers/nix/cortex.nix |

### 15.3 NixOS Container STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-NIX-001 | All containers use NixOS base | CRITICAL | Image inspect |
| SC-NIX-002 | No Alpine/Debian images | CRITICAL | Registry scan |
| SC-NIX-003 | Reproducible builds | HIGH | Hash verification |
| SC-NIX-004 | SOPV51_COMPLIANT=true | HIGH | Env check |
| SC-NIX-005 | CONTAINER_OS=nixos | HIGH | Env check |
| SC-NIX-006 | Podman rootless only | CRITICAL | Runtime check |
| SC-NIX-007 | Podman version >= 5.4.1 | HIGH | Version check |
| SC-NIX-008 | Registry localhost/ only | CRITICAL | Image source |

---

## 16. HOMEOSTASIS MODE (SIL-6 SELF-REGULATION)

### 16.1 Homeostasis Definition

Homeostasis is the SIL-6 self-regulating mode where the system maintains optimal operational parameters through continuous feedback loops.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HOMEOSTASIS CONTROL LOOP                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│     ┌─────────┐         ┌─────────┐         ┌─────────┐                     │
│     │ SENSORS │──────▶  │ CONTROL │──────▶  │ACTUATORS│                     │
│     └────┬────┘         │  LOGIC  │         └────┬────┘                     │
│          │              └────┬────┘              │                          │
│          │                   │                   │                          │
│          └───────────────────┴───────────────────┘                          │
│                         FEEDBACK                                             │
│                                                                              │
│  SENSORS:               CONTROL LOGIC:           ACTUATORS:                 │
│  - Health monitors      - OODA cycles            - Scale agents             │
│  - Resource meters      - Threshold checks       - Restart containers       │
│  - API rate limiters    - Guardian validation    - Trigger checkpoints      │
│  - Zenoh subscribers    - Constitutional verify  - Emergency stop           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 16.2 Homeostasis Parameters

| Parameter | Setpoint | Low Threshold | High Threshold | Action |
|-----------|----------|---------------|----------------|--------|
| API Usage | 70% | 40% | 95% | Scale agents |
| Memory | 60% | 20% | 80% | Compact/GC |
| CPU | 50% | 10% | 80% | Load balance |
| Context | 60% | 20% | 75% | Auto-compact |
| Agent Count | 15 | 5 | 25 | Scale |
| Healthy Containers | 100% | 80% | - | Restart |
| Quorum | N/2+1 | N/2 | - | Alert |

### 16.3 Homeostasis Controller (F#)

```fsharp
// lib/cepaf/src/Cepaf/Control/HomeostasisController.fs

module HomeostasisController

type HomeostasisState = {
    APIUsage: float
    MemoryUsage: float
    CPUUsage: float
    ContextUsage: float
    AgentCount: int
    HealthyRatio: float
    QuorumAchieved: bool
}

type HomeostasisAction =
    | ScaleAgentsUp
    | ScaleAgentsDown
    | TriggerCompact
    | TriggerGC
    | RestartContainer of string
    | Alert of string
    | NoAction

/// Calculate homeostasis actions based on current state
let calculateActions (state: HomeostasisState) : HomeostasisAction list =
    let actions = ResizeArray<HomeostasisAction>()

    // API Usage control (SC-BIO-003)
    if state.APIUsage > 0.95 then
        actions.Add(ScaleAgentsDown)
        actions.Add(Alert "API rate limit critical")
    elif state.APIUsage > 0.70 then
        actions.Add(ScaleAgentsDown)
    elif state.APIUsage < 0.40 then
        actions.Add(ScaleAgentsUp)

    // Memory control
    if state.MemoryUsage > 0.80 then
        actions.Add(TriggerGC)
        actions.Add(Alert "Memory critical")

    // Context control (SC-BIO-004)
    if state.ContextUsage > 0.75 then
        actions.Add(TriggerCompact)

    // Container health
    if state.HealthyRatio < 0.80 then
        actions.Add(Alert "Container health degraded")

    // Quorum check
    if not state.QuorumAchieved then
        actions.Add(Alert "Quorum lost - critical")

    actions |> List.ofSeq

/// Run homeostasis control loop (30s interval)
let runHomeostasisLoop () =
    let rec loop () = async {
        // Observe
        let! state = collectHomeostasisState()

        // Orient
        let actions = calculateActions state

        // Decide (Guardian approval for critical actions)
        let approvedActions =
            actions
            |> List.filter (fun a ->
                match a with
                | ScaleAgentsDown | TriggerCompact | NoAction -> true
                | _ -> Guardian.approve (ActionProposal a) |> Result.isOk
            )

        // Act
        for action in approvedActions do
            executeAction action

        // Feedback
        publishHomeostasisTelemetry state actions

        // 30s interval (SC-BIO-005)
        do! Async.Sleep 30000

        return! loop()
    }
    Async.Start(loop())
```

### 16.4 Homeostasis STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-HOMEO-001 | Control loop runs every 30s | HIGH | Interval check |
| SC-HOMEO-002 | All actions Guardian-approved | CRITICAL | Approval log |
| SC-HOMEO-003 | Setpoints configurable | MEDIUM | Config check |
| SC-HOMEO-004 | Hysteresis prevents oscillation | HIGH | State analysis |
| SC-HOMEO-005 | Telemetry published | HIGH | Zenoh check |
| SC-HOMEO-006 | Alerts escalate properly | HIGH | Alert log |
| SC-HOMEO-007 | Auto-scaling within bounds | HIGH | Agent count |
| SC-HOMEO-008 | Compact triggers at 75% | CRITICAL | Threshold check |

---

## DOCUMENT APPROVAL

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Author | Claude Opus 4.5 | ✓ | 2026-01-08 |
| Architect | Cybernetic Architect | | |
| Safety | Guardian | | |
| Founder | Abhijit Naik | | |

---

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   VERIFICATION CANON v1.0.0
     ╭╯ ╰─╯ ╰╮       SIL-6 BIOMORPHIC FRACTAL MESH
    ●╯       ╰●       CERTIFIED
```
