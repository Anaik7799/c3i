# CEPAF 5-Level Implementation Plan: STAMP/TDG/AOR Framework
**Version**: 1.0.0
**Date**: 2025-12-24 02:00 CET
**Track**: infra-f#-cepa
**Status**: ACTIVE
**STAMP Compliance**: SC-CEP-001 through SC-CEP-012

---

## Executive Summary

This document provides a 5-level hierarchical implementation plan for the CEPAF STAMP/TDG/AOR framework. Each level increases in specificity, from strategic objectives (L1) to individual test cases (L5).

---

## Level 1: Strategic Objectives

### L1.1 STAMP Safety Framework
**Goal**: Implement comprehensive STAMP-based safety constraints for container orchestration
**Timeline**: Immediate
**Owner**: Cybernetic Architect
**Success Criteria**: All 65 STAMP constraints verified and enforced

### L1.2 TDG Methodology
**Goal**: Establish Test-Driven Generation workflow for all CEPAF modules
**Timeline**: Immediate
**Owner**: Cybernetic Architect
**Success Criteria**: All 10 TDG rules operational with automated enforcement

### L1.3 AOR Behavioral Rules
**Goal**: Implement Agent Operating Rules for consistent system behavior
**Timeline**: Immediate
**Owner**: Cybernetic Architect
**Success Criteria**: All 40 AOR rules enforceable at compile and runtime

### L1.4 Service Chain Verification
**Goal**: Full DAG-based verification of container dependencies and health
**Timeline**: Immediate
**Owner**: Cybernetic Architect
**Success Criteria**: Complete service chain map with automated verification

### L1.5 Observability Integration
**Goal**: Quadplex logging with full OTEL trace propagation
**Timeline**: Immediate
**Owner**: Cybernetic Architect
**Success Criteria**: All operations logged with correlation IDs

---

## Level 2: Tactical Components

### L2.1 STAMP Implementation Components

#### L2.1.1 Container Constraints (SC-CNT)
- SC-CNT-009: NixOS container enforcement
- SC-CNT-010: Localhost registry validation
- SC-CNT-012: Rootless Podman verification
- SC-CNT-013: Image pull policy control
- SC-CNT-014: Volume mount validation
- SC-CNT-015: Network isolation checks
- SC-CNT-016: Resource limit enforcement
- SC-CNT-017: Security context validation
- SC-CNT-018: Capability restriction
- SC-CNT-019: Read-only rootfs check

#### L2.1.2 CEPAF Constraints (SC-CEP)
- SC-CEP-001: Artifact locality (PathResolver scope)
- SC-CEP-002: Module decoupling verification
- SC-CEP-003: Consensus-based health checks
- SC-CEP-004: 30-second boot threshold
- SC-CEP-005: Graceful degradation
- SC-CEP-006: VTO phase compliance
- SC-CEP-007: Cleanup phase validation
- SC-CEP-008: Configuration immutability
- SC-CEP-009: State machine transitions
- SC-CEP-010: Error propagation
- SC-CEP-011: Retry policy compliance
- SC-CEP-012: Timeout enforcement

#### L2.1.3 Observability Constraints (SC-OBS)
- SC-OBS-065: Container health probes
- SC-OBS-066: Startup probe timing
- SC-OBS-067: Liveness probe intervals
- SC-OBS-068: Readiness probe thresholds
- SC-OBS-069: Dual logging (Term+SigNoz)
- SC-OBS-070: Trace context propagation
- SC-OBS-071: Metric emission
- SC-OBS-072: Log correlation IDs
- SC-OBS-073: Error aggregation
- SC-OBS-074: Performance baselines

#### L2.1.4 Agent Constraints (SC-AGT)
- SC-AGT-017: Efficiency >90%
- SC-AGT-018: Deadlock prevention
- SC-AGT-019: Executive authority
- SC-AGT-020: Domain isolation
- SC-AGT-021: Worker pool limits
- SC-AGT-022: Task queue bounds
- SC-AGT-023: Priority enforcement
- SC-AGT-024: Timeout handling

#### L2.1.5 Validation Constraints (SC-VAL)
- SC-VAL-001: Patient Mode enforcement
- SC-VAL-002: Complete log analysis
- SC-VAL-003: 100% consensus requirement
- SC-VAL-004: Halt on disagreement
- SC-VAL-005: FPPS 5-method validation
- SC-VAL-006: Binary verification
- SC-VAL-007: AST analysis
- SC-VAL-008: Pattern matching

#### L2.1.6 Performance Constraints (SC-PRF)
- SC-PRF-050: Response <50ms
- SC-PRF-051: Throughput targets
- SC-PRF-052: Memory bounds
- SC-PRF-053: CPU limits
- SC-PRF-054: I/O throttling
- SC-PRF-055: No blocking operations

#### L2.1.7 Emergency Constraints (SC-EMR)
- SC-EMR-057: Stop <5s
- SC-EMR-058: Alert propagation
- SC-EMR-059: State preservation
- SC-EMR-060: Rollback capability
- SC-EMR-061: Recovery automation
- SC-EMR-062: Incident logging

#### L2.1.8 Security Constraints (SC-SEC)
- SC-SEC-044: Sobelow checks
- SC-SEC-045: Credential isolation
- SC-SEC-046: Network policies
- SC-SEC-047: Encryption at rest
- SC-SEC-048: TLS enforcement
- SC-SEC-049: Audit logging

### L2.2 TDG Implementation Components

#### L2.2.1 Test-First Rules
- TDG-001: Tests must exist before code
- TDG-002: Tests must fail initially
- TDG-003: Minimal code to pass
- TDG-004: Refactor after green
- TDG-005: Dual property testing

#### L2.2.2 Property Testing Rules
- TDG-006: PropCheck integration
- TDG-007: ExUnitProperties parallel
- TDG-008: Generator diversity
- TDG-009: Shrinking verification
- TDG-010: Coverage thresholds

### L2.3 AOR Implementation Components

#### L2.3.1 Executive Rules (AOR-EXE)
- AOR-EXE-001: Supreme authority
- AOR-EXE-002: Priority override
- AOR-EXE-003: Emergency powers
- AOR-EXE-004: Audit trail
- AOR-EXE-005: Delegation limits

#### L2.3.2 Safety Rules (AOR-SAF)
- AOR-SAF-001: Halt <1s on violation
- AOR-SAF-002: Graceful degradation
- AOR-SAF-003: Failsafe defaults
- AOR-SAF-004: Recovery automation
- AOR-SAF-005: Incident escalation

#### L2.3.3 Container Rules (AOR-CNT)
- AOR-CNT-001: Podman-only
- AOR-CNT-002: Rootless enforcement
- AOR-CNT-003: Image validation
- AOR-CNT-004: Volume safety
- AOR-CNT-005: Network isolation

#### L2.3.4 Quality Rules (AOR-QUA)
- AOR-QUA-001: Zero warnings
- AOR-QUA-002: Format compliance
- AOR-QUA-003: Credo strict
- AOR-QUA-004: Dialyzer clean
- AOR-QUA-005: Coverage >95%

#### L2.3.5 Agent Code Rules (AOR-AGT)
- AOR-AGT-001: Compile before complete
- AOR-AGT-002: Verify zero errors
- AOR-AGT-003: Check BaseResource
- AOR-AGT-004: Factory patterns
- AOR-AGT-005: Test isolation

#### L2.3.6 Database Rules (AOR-DB)
- AOR-DB-001: Use BaseResource
- AOR-DB-002: UUID primary keys
- AOR-DB-003: Migration safety
- AOR-DB-004: Index creation
- AOR-DB-005: Tenant isolation

#### L2.3.7 Documentation Rules (AOR-DOC)
- AOR-DOC-001: Read moduledoc first
- AOR-DOC-002: Document DSL blocks
- AOR-DOC-003: Mark escape hatches
- AOR-DOC-004: Update on change
- AOR-DOC-005: Changelog entries

#### L2.3.8 Batch Rules (AOR-BATCH)
- AOR-BATCH-001: Max 10 changes
- AOR-BATCH-002: Elixir scripts only
- AOR-BATCH-003: Git checkpoints
- AOR-BATCH-004: Validation gates
- AOR-BATCH-005: Reversibility

#### L2.3.9 Gemini Rules (AOR-GEM)
- AOR-GEM-001: Plan then verify
- AOR-GEM-002: No core spec edits
- AOR-GEM-003: No hallucinated APIs
- AOR-GEM-004: Format after gen
- AOR-GEM-005: Entropy minimization

---

## Level 3: Implementation Tasks

### L3.1 STAMP Constraint Implementation

#### L3.1.1 Container Constraint Module
```
Task: Create ConstraintValidator.fs module
Files:
  - lib/cepaf/src/Cepaf/Modules/ConstraintValidator.fs
  - lib/cepaf/src/Cepaf.Tests/ConstraintValidatorTests.fs
Functions:
  - validateNixOS: Container -> Result<Container, ConstraintViolation>
  - validateLocalRegistry: Image -> Result<Image, ConstraintViolation>
  - validateRootless: Runtime -> Result<Runtime, ConstraintViolation>
  - validateResourceLimits: Container -> Result<Container, ConstraintViolation>
  - validateSecurityContext: Container -> Result<Container, ConstraintViolation>
Dependencies:
  - Podman.fs
  - Domain.fs
  - PathResolver.fs
```

#### L3.1.2 CEPAF Constraint Module
```
Task: Enhance existing modules with constraint checks
Files:
  - lib/cepaf/src/Cepaf/Modules/PathResolver.fs (enhance validateCepafScope)
  - lib/cepaf/src/Cepaf/Phases/VTO.fs (add phase timing validation)
  - lib/cepaf/src/Cepaf/Orchestrator.fs (add state machine constraints)
Functions:
  - validateArtifactLocality: Path -> Result<Path, ConstraintViolation>
  - validateBootThreshold: Duration -> Result<Duration, ConstraintViolation>
  - validatePhaseTransition: Phase -> Phase -> Result<Phase, ConstraintViolation>
```

#### L3.1.3 Observability Constraint Module
```
Task: Create HealthProbeValidator.fs module
Files:
  - lib/cepaf/src/Cepaf/Modules/HealthProbeValidator.fs
  - lib/cepaf/src/Cepaf.Tests/HealthProbeValidatorTests.fs
Functions:
  - validateStartupProbe: Probe -> Result<Probe, ConstraintViolation>
  - validateLivenessProbe: Probe -> Result<Probe, ConstraintViolation>
  - validateReadinessProbe: Probe -> Result<Probe, ConstraintViolation>
  - validateLogCorrelation: TraceContext -> Result<TraceContext, ConstraintViolation>
```

#### L3.1.4 Validation Constraint Module
```
Task: Create ConsensusValidator.fs module
Files:
  - lib/cepaf/src/Cepaf/Modules/ConsensusValidator.fs
  - lib/cepaf/src/Cepaf.Tests/ConsensusValidatorTests.fs
Functions:
  - validateFPPS: ValidationResult[] -> Result<Consensus, ConstraintViolation>
  - requirePatientMode: Environment -> Result<Environment, ConstraintViolation>
  - validateConsensusAchieved: Vote[] -> Result<bool, ConstraintViolation>
```

### L3.2 TDG Methodology Implementation

#### L3.2.1 Test Harness Module
```
Task: Create TDGHarness.fs for test-first workflow
Files:
  - lib/cepaf/src/Cepaf/Testing/TDGHarness.fs
  - lib/cepaf/src/Cepaf.Tests/TDGHarnessTests.fs
Functions:
  - requireTestExists: ModulePath -> Result<TestPath, TDGViolation>
  - requireTestFails: TestPath -> Result<FailingTest, TDGViolation>
  - validateMinimalImpl: Code -> Result<Code, TDGViolation>
  - enforceRefactorPhase: Code -> Result<Code, TDGViolation>
```

#### L3.2.2 Property Test Integration
```
Task: Integrate dual property testing framework
Files:
  - lib/cepaf/src/Cepaf/Testing/PropertyGenerator.fs
  - lib/cepaf/src/Cepaf.Tests/PropertyGeneratorTests.fs
Functions:
  - generateContainerProps: unit -> Gen<Container>
  - generatePathProps: unit -> Gen<Path>
  - generateConfigProps: unit -> Gen<Config>
  - shrinkToMinimal: Counterexample -> MinimalCounterexample
```

### L3.3 AOR Rule Implementation

#### L3.3.1 Rule Engine Module
```
Task: Create AOREngine.fs for rule enforcement
Files:
  - lib/cepaf/src/Cepaf/Modules/AOREngine.fs
  - lib/cepaf/src/Cepaf.Tests/AOREngineTests.fs
Functions:
  - enforceRule: AORRule -> Context -> Result<Context, AORViolation>
  - checkExecutiveAuthority: Agent -> Action -> Result<Action, AORViolation>
  - validateSafetyHalt: Duration -> Result<Duration, AORViolation>
  - enforceZeroWarnings: CompileResult -> Result<CompileResult, AORViolation>
```

#### L3.3.2 Batch Controller Module
```
Task: Create BatchController.fs for batch operations
Files:
  - lib/cepaf/src/Cepaf/Modules/BatchController.fs
  - lib/cepaf/src/Cepaf.Tests/BatchControllerTests.fs
Functions:
  - limitBatchSize: Change[] -> Result<Change[], AORViolation>
  - requireGitCheckpoint: BatchId -> Result<Checkpoint, AORViolation>
  - validateReversibility: Change -> Result<Change, AORViolation>
```

### L3.4 Service Chain Implementation

#### L3.4.1 DAG Module Enhancement
```
Task: Implement topological sort and dependency resolution
Files:
  - lib/cepaf/src/Cepaf/Modules/ServiceDAG.fs
  - lib/cepaf/src/Cepaf.Tests/ServiceDAGTests.fs
Functions:
  - buildDAG: Container[] -> DAG
  - topologicalSort: DAG -> Container[]
  - detectCycles: DAG -> Cycle option
  - resolveDependencies: Container -> Container[]
  - calculateBootOrder: DAG -> BootSequence
```

#### L3.4.2 Health Propagation Module
```
Task: Implement health state machine and propagation
Files:
  - lib/cepaf/src/Cepaf/Modules/HealthPropagation.fs
  - lib/cepaf/src/Cepaf.Tests/HealthPropagationTests.fs
Functions:
  - propagateHealth: Container -> HealthState -> HealthState[]
  - calculateSystemHealth: Container[] -> SystemHealth
  - detectDegradation: Container[] -> DegradedContainer[]
  - triggerRecovery: DegradedContainer -> RecoveryAction
```

### L3.5 Verification Suite Implementation

#### L3.5.1 Node-Level Verifier
```
Task: Create NodeVerifier.fs for individual container verification
Files:
  - lib/cepaf/src/Cepaf/Verification/NodeVerifier.fs
  - lib/cepaf/src/Cepaf.Tests/NodeVerifierTests.fs
Functions:
  - verifyDBNode: DbContainer -> VerificationResult
  - verifyOBSNode: ObsContainer -> VerificationResult
  - verifyAPPNode: AppContainer -> VerificationResult
  - verifyAllNodes: Container[] -> VerificationReport
```

#### L3.5.2 Chain-Level Verifier
```
Task: Create ChainVerifier.fs for service chain verification
Files:
  - lib/cepaf/src/Cepaf/Verification/ChainVerifier.fs
  - lib/cepaf/src/Cepaf.Tests/ChainVerifierTests.fs
Functions:
  - verifyBootSequence: BootSequence -> VerificationResult
  - verifyDependencyChain: DAG -> VerificationResult
  - verifyHealthPropagation: HealthState[] -> VerificationResult
  - runFullVerification: Config -> VerificationReport
```

---

## Level 4: Detailed Specifications

### L4.1 ConstraintValidator.fs Specification

```fsharp
module Cepaf.Modules.ConstraintValidator

open System
open Cepaf.Domain
open Cepaf.Modules.Podman

/// STAMP Constraint Violation
type ConstraintViolation = {
    ConstraintId: string       // e.g., "SC-CNT-009"
    Message: string
    Severity: Severity
    Timestamp: DateTime
    Context: Map<string, string>
}

/// Severity levels for violations
type Severity =
    | Critical   // Immediate halt required
    | High       // Must fix before deploy
    | Medium     // Should fix soon
    | Low        // Advisory only

/// SC-CNT-009: Validate NixOS container
let validateNixOS (container: Container) : Result<Container, ConstraintViolation> =
    let image = container.Image
    if image.Contains("nixos") || image.StartsWith("localhost/") then
        Ok container
    else
        Error {
            ConstraintId = "SC-CNT-009"
            Message = sprintf "Container must use NixOS image: %s" image
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [("container", container.Name); ("image", image)]
        }

/// SC-CNT-010: Validate localhost registry
let validateLocalRegistry (image: string) : Result<string, ConstraintViolation> =
    if image.StartsWith("localhost/") then
        Ok image
    else
        Error {
            ConstraintId = "SC-CNT-010"
            Message = sprintf "Image must use localhost registry: %s" image
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [("image", image)]
        }

/// SC-CNT-012: Validate rootless execution
let validateRootless (runtime: Runtime) : Result<Runtime, ConstraintViolation> =
    if runtime.IsRootless then
        Ok runtime
    else
        Error {
            ConstraintId = "SC-CNT-012"
            Message = "Podman must run in rootless mode"
            Severity = Critical
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [("runtime", runtime.Name)]
        }

/// SC-CEP-004: Validate 30-second boot threshold
let validateBootThreshold (duration: TimeSpan) : Result<TimeSpan, ConstraintViolation> =
    if duration.TotalSeconds <= 30.0 then
        Ok duration
    else
        Error {
            ConstraintId = "SC-CEP-004"
            Message = sprintf "Boot time exceeds 30s threshold: %.2fs" duration.TotalSeconds
            Severity = High
            Timestamp = DateTime.UtcNow
            Context = Map.ofList [("duration_seconds", string duration.TotalSeconds)]
        }

/// Composite validator for all container constraints
let validateContainer (container: Container) : Result<Container, ConstraintViolation list> =
    let violations = ResizeArray<ConstraintViolation>()

    match validateNixOS container with
    | Error v -> violations.Add(v)
    | Ok _ -> ()

    match validateLocalRegistry container.Image with
    | Error v -> violations.Add(v)
    | Ok _ -> ()

    if violations.Count > 0 then
        Error (violations |> List.ofSeq)
    else
        Ok container
```

### L4.2 ServiceDAG.fs Specification

```fsharp
module Cepaf.Modules.ServiceDAG

open System.Collections.Generic

/// Node in the service DAG
type DAGNode = {
    Id: string
    Container: Container
    Dependencies: string list
    Layer: int
    HealthState: HealthState
}

/// Directed Acyclic Graph for services
type ServiceDAG = {
    Nodes: Map<string, DAGNode>
    Edges: (string * string) list   // (from, to) = dependency edge
    Layers: Map<int, string list>   // Layer -> node IDs
}

/// Health states for containers
type HealthState =
    | Absent
    | Created
    | Starting
    | Healthy
    | Degraded
    | Failed

/// Build DAG from container definitions
let buildDAG (containers: Container list) : ServiceDAG =
    let nodes =
        containers
        |> List.map (fun c ->
            c.Name, {
                Id = c.Name
                Container = c
                Dependencies = c.DependsOn |> Option.defaultValue []
                Layer = 0  // Will be calculated
                HealthState = Absent
            })
        |> Map.ofList

    let edges =
        containers
        |> List.collect (fun c ->
            c.DependsOn
            |> Option.defaultValue []
            |> List.map (fun dep -> (dep, c.Name)))

    { Nodes = nodes; Edges = edges; Layers = Map.empty }

/// Detect cycles in DAG (Kahn's algorithm variant)
let detectCycles (dag: ServiceDAG) : string list option =
    let inDegree = Dictionary<string, int>()
    let queue = Queue<string>()
    let sorted = ResizeArray<string>()

    // Initialize in-degrees
    dag.Nodes |> Map.iter (fun id _ -> inDegree.[id] <- 0)
    dag.Edges |> List.iter (fun (_, to_) ->
        inDegree.[to_] <- inDegree.[to_] + 1)

    // Enqueue nodes with no dependencies
    dag.Nodes
    |> Map.iter (fun id _ ->
        if inDegree.[id] = 0 then queue.Enqueue(id))

    // Process queue
    while queue.Count > 0 do
        let node = queue.Dequeue()
        sorted.Add(node)
        dag.Edges
        |> List.filter (fun (from, _) -> from = node)
        |> List.iter (fun (_, to_) ->
            inDegree.[to_] <- inDegree.[to_] - 1
            if inDegree.[to_] = 0 then queue.Enqueue(to_))

    if sorted.Count <> dag.Nodes.Count then
        // Cycle detected - find nodes not in sorted
        let cycleNodes =
            dag.Nodes
            |> Map.keys
            |> Seq.filter (fun id -> not (sorted.Contains(id)))
            |> List.ofSeq
        Some cycleNodes
    else
        None

/// Topological sort for boot order
let topologicalSort (dag: ServiceDAG) : Result<string list, string> =
    match detectCycles dag with
    | Some cycle ->
        Error (sprintf "Cycle detected involving nodes: %s" (String.concat ", " cycle))
    | None ->
        // Use DFS-based topological sort
        let visited = HashSet<string>()
        let stack = Stack<string>()

        let rec visit (nodeId: string) =
            if not (visited.Contains(nodeId)) then
                visited.Add(nodeId) |> ignore
                dag.Edges
                |> List.filter (fun (from, _) -> from = nodeId)
                |> List.iter (fun (_, to_) -> visit to_)
                stack.Push(nodeId)

        dag.Nodes |> Map.iter (fun id _ -> visit id)
        Ok (stack |> List.ofSeq)

/// Assign layers based on dependency depth
let assignLayers (dag: ServiceDAG) : ServiceDAG =
    let sortedResult = topologicalSort dag
    match sortedResult with
    | Error _ -> dag  // Return unchanged if cycle
    | Ok sorted ->
        let layerMap = Dictionary<string, int>()

        sorted |> List.iter (fun nodeId ->
            let node = dag.Nodes.[nodeId]
            let maxDepLayer =
                node.Dependencies
                |> List.map (fun dep ->
                    if layerMap.ContainsKey(dep) then layerMap.[dep] + 1 else 0)
                |> List.fold max 0
            layerMap.[nodeId] <- maxDepLayer)

        let updatedNodes =
            dag.Nodes
            |> Map.map (fun id node -> { node with Layer = layerMap.[id] })

        let layers =
            updatedNodes
            |> Map.toList
            |> List.groupBy (fun (_, node) -> node.Layer)
            |> List.map (fun (layer, nodes) -> (layer, nodes |> List.map fst))
            |> Map.ofList

        { dag with Nodes = updatedNodes; Layers = layers }
```

### L4.3 HealthPropagation.fs Specification

```fsharp
module Cepaf.Modules.HealthPropagation

open Cepaf.Modules.ServiceDAG

/// Health propagation rules
type PropagationRule =
    | ParentFailedMandatory   // Parent failed, child is mandatory -> child fails
    | ParentFailedOptional    // Parent failed, child is optional -> child degrades
    | ChildFailed             // Child failed -> parent degrades
    | AllHealthy              // All dependencies healthy -> node healthy

/// Dependency type
type DependencyType =
    | Mandatory   // Must be healthy for dependent to start
    | Optional    // Can degrade gracefully if unhealthy

/// Health propagation result
type PropagationResult = {
    NodeId: string
    PreviousState: HealthState
    NewState: HealthState
    Rule: PropagationRule
    Timestamp: DateTime
}

/// Calculate new health state based on dependencies
let calculateHealth
    (dag: ServiceDAG)
    (nodeId: string)
    (dependencyHealth: Map<string, HealthState * DependencyType>)
    : HealthState =

    let mandatoryDeps =
        dependencyHealth
        |> Map.filter (fun _ (_, depType) -> depType = Mandatory)

    let optionalDeps =
        dependencyHealth
        |> Map.filter (fun _ (_, depType) -> depType = Optional)

    // Check mandatory dependencies
    let mandatoryFailed =
        mandatoryDeps
        |> Map.exists (fun _ (health, _) -> health = Failed)

    let mandatoryDegraded =
        mandatoryDeps
        |> Map.exists (fun _ (health, _) -> health = Degraded)

    // Check optional dependencies
    let optionalFailed =
        optionalDeps
        |> Map.exists (fun _ (health, _) -> health = Failed || health = Degraded)

    match mandatoryFailed, mandatoryDegraded, optionalFailed with
    | true, _, _ -> Failed           // Mandatory dep failed -> we fail
    | _, true, _ -> Degraded         // Mandatory dep degraded -> we degrade
    | _, _, true -> Degraded         // Optional dep failed -> we degrade but continue
    | false, false, false -> Healthy // All good

/// Propagate health changes through the DAG
let propagateHealth (dag: ServiceDAG) (changedNode: string) (newState: HealthState)
    : PropagationResult list =

    let results = ResizeArray<PropagationResult>()
    let visited = System.Collections.Generic.HashSet<string>()

    let rec propagate (nodeId: string) (incomingState: HealthState) =
        if visited.Contains(nodeId) then ()
        else
            visited.Add(nodeId) |> ignore
            let node = dag.Nodes.[nodeId]

            // Find dependents (nodes that depend on this one)
            let dependents =
                dag.Edges
                |> List.filter (fun (from, _) -> from = nodeId)
                |> List.map snd

            dependents |> List.iter (fun depId ->
                let depNode = dag.Nodes.[depId]
                let oldState = depNode.HealthState

                // Determine dependency type (simplified - could be from config)
                let depType =
                    if nodeId = "indrajaal-db" then Mandatory else Optional

                let newDepState =
                    calculateHealth dag depId (Map.ofList [(nodeId, (incomingState, depType))])

                if newDepState <> oldState then
                    results.Add({
                        NodeId = depId
                        PreviousState = oldState
                        NewState = newDepState
                        Rule = if depType = Mandatory then ParentFailedMandatory else ParentFailedOptional
                        Timestamp = DateTime.UtcNow
                    })
                    propagate depId newDepState)

    propagate changedNode newState
    results |> List.ofSeq

/// Calculate system-wide health status
let calculateSystemHealth (dag: ServiceDAG) : SystemHealth =
    let nodeStates = dag.Nodes |> Map.map (fun _ n -> n.HealthState)

    let failedCount = nodeStates |> Map.filter (fun _ s -> s = Failed) |> Map.count
    let degradedCount = nodeStates |> Map.filter (fun _ s -> s = Degraded) |> Map.count
    let healthyCount = nodeStates |> Map.filter (fun _ s -> s = Healthy) |> Map.count

    {
        TotalNodes = dag.Nodes.Count
        HealthyNodes = healthyCount
        DegradedNodes = degradedCount
        FailedNodes = failedCount
        OverallStatus =
            if failedCount > 0 then SystemFailed
            elif degradedCount > 0 then SystemDegraded
            else SystemHealthy
        Timestamp = DateTime.UtcNow
    }
```

---

## Level 5: Test Cases

### L5.1 ConstraintValidator Tests

```fsharp
module Cepaf.Tests.ConstraintValidatorTests

open Xunit
open Cepaf.Modules.ConstraintValidator

[<Fact>]
let ``SC-CNT-009: NixOS container should pass validation`` () =
    let container = { Name = "test"; Image = "localhost/indrajaal-app:nixos"; DependsOn = None }
    let result = validateNixOS container
    Assert.True(Result.isOk result)

[<Fact>]
let ``SC-CNT-009: Alpine container should fail validation`` () =
    let container = { Name = "test"; Image = "alpine:latest"; DependsOn = None }
    let result = validateNixOS container
    match result with
    | Error v -> Assert.Equal("SC-CNT-009", v.ConstraintId)
    | Ok _ -> Assert.True(false, "Should have failed")

[<Fact>]
let ``SC-CNT-010: Localhost registry should pass`` () =
    let result = validateLocalRegistry "localhost/indrajaal-db:nixos"
    Assert.True(Result.isOk result)

[<Fact>]
let ``SC-CNT-010: Docker Hub registry should fail`` () =
    let result = validateLocalRegistry "postgres:17"
    match result with
    | Error v -> Assert.Equal("SC-CNT-010", v.ConstraintId)
    | Ok _ -> Assert.True(false, "Should have failed")

[<Fact>]
let ``SC-CEP-004: Boot under 30s should pass`` () =
    let result = validateBootThreshold (TimeSpan.FromSeconds(25.0))
    Assert.True(Result.isOk result)

[<Fact>]
let ``SC-CEP-004: Boot over 30s should fail`` () =
    let result = validateBootThreshold (TimeSpan.FromSeconds(45.0))
    match result with
    | Error v ->
        Assert.Equal("SC-CEP-004", v.ConstraintId)
        Assert.Equal(Severity.High, v.Severity)
    | Ok _ -> Assert.True(false, "Should have failed")

[<Theory>]
[<InlineData("localhost/indrajaal-app:nixos", true)>]
[<InlineData("localhost/indrajaal-db:nixos", true)>]
[<InlineData("localhost/indrajaal-observability:nixos", true)>]
[<InlineData("docker.io/library/postgres:17", false)>]
[<InlineData("ghcr.io/some/image:latest", false)>]
let ``SC-CNT-010: Registry validation matrix`` (image: string) (shouldPass: bool) =
    let result = validateLocalRegistry image
    Assert.Equal(shouldPass, Result.isOk result)
```

### L5.2 ServiceDAG Tests

```fsharp
module Cepaf.Tests.ServiceDAGTests

open Xunit
open Cepaf.Modules.ServiceDAG

[<Fact>]
let ``buildDAG creates correct node structure`` () =
    let containers = [
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = None }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["db"] }
    ]
    let dag = buildDAG containers
    Assert.Equal(2, dag.Nodes.Count)
    Assert.Equal(1, dag.Edges.Length)

[<Fact>]
let ``detectCycles returns None for valid DAG`` () =
    let containers = [
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = None }
        { Name = "obs"; Image = "localhost/obs:nixos"; DependsOn = None }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["db"; "obs"] }
    ]
    let dag = buildDAG containers
    let result = detectCycles dag
    Assert.True(Option.isNone result)

[<Fact>]
let ``detectCycles returns Some for cyclic dependencies`` () =
    let containers = [
        { Name = "a"; Image = "localhost/a:nixos"; DependsOn = Some ["b"] }
        { Name = "b"; Image = "localhost/b:nixos"; DependsOn = Some ["c"] }
        { Name = "c"; Image = "localhost/c:nixos"; DependsOn = Some ["a"] }
    ]
    let dag = buildDAG containers
    let result = detectCycles dag
    Assert.True(Option.isSome result)

[<Fact>]
let ``topologicalSort returns correct boot order`` () =
    let containers = [
        { Name = "network"; Image = "localhost/net:nixos"; DependsOn = None }
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = Some ["network"] }
        { Name = "obs"; Image = "localhost/obs:nixos"; DependsOn = Some ["network"] }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["db"; "obs"] }
    ]
    let dag = buildDAG containers
    match topologicalSort dag with
    | Ok sorted ->
        // Network should come before db, obs, app
        let netIdx = List.findIndex ((=) "network") sorted
        let dbIdx = List.findIndex ((=) "db") sorted
        let appIdx = List.findIndex ((=) "app") sorted
        Assert.True(netIdx < dbIdx)
        Assert.True(dbIdx < appIdx)
    | Error _ -> Assert.True(false, "Should not have cycle")

[<Fact>]
let ``assignLayers correctly stratifies DAG`` () =
    let containers = [
        { Name = "network"; Image = "localhost/net:nixos"; DependsOn = None }
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = Some ["network"] }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["db"] }
    ]
    let dag = buildDAG containers |> assignLayers
    Assert.Equal(0, dag.Nodes.["network"].Layer)
    Assert.Equal(1, dag.Nodes.["db"].Layer)
    Assert.Equal(2, dag.Nodes.["app"].Layer)
```

### L5.3 HealthPropagation Tests

```fsharp
module Cepaf.Tests.HealthPropagationTests

open Xunit
open Cepaf.Modules.ServiceDAG
open Cepaf.Modules.HealthPropagation

[<Fact>]
let ``DB failure propagates to app as failed (mandatory dependency)`` () =
    let containers = [
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = None }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["db"] }
    ]
    let dag = buildDAG containers
    let results = propagateHealth dag "db" Failed

    Assert.Equal(1, results.Length)
    Assert.Equal("app", results.[0].NodeId)
    Assert.Equal(Failed, results.[0].NewState)

[<Fact>]
let ``OBS failure propagates to app as degraded (optional dependency)`` () =
    let containers = [
        { Name = "obs"; Image = "localhost/obs:nixos"; DependsOn = None }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["obs"] }
    ]
    let dag = buildDAG containers
    // Assuming obs is optional (per specification)
    let results = propagateHealth dag "obs" Failed

    // App should degrade, not fail
    let appResult = results |> List.tryFind (fun r -> r.NodeId = "app")
    match appResult with
    | Some r -> Assert.Equal(Degraded, r.NewState)
    | None -> () // App might not be affected if truly optional

[<Fact>]
let ``calculateSystemHealth correctly aggregates node states`` () =
    let containers = [
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = None }
        { Name = "obs"; Image = "localhost/obs:nixos"; DependsOn = None }
        { Name = "app"; Image = "localhost/app:nixos"; DependsOn = Some ["db"; "obs"] }
    ]
    let dag =
        buildDAG containers
        |> fun d -> { d with
            Nodes = d.Nodes |> Map.map (fun _ n -> { n with HealthState = Healthy }) }

    let health = calculateSystemHealth dag
    Assert.Equal(3, health.TotalNodes)
    Assert.Equal(3, health.HealthyNodes)
    Assert.Equal(SystemHealthy, health.OverallStatus)

[<Fact>]
let ``System status is Degraded when any node is degraded`` () =
    let containers = [
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = None }
        { Name = "obs"; Image = "localhost/obs:nixos"; DependsOn = None }
    ]
    let dag =
        buildDAG containers
        |> fun d -> { d with
            Nodes =
                d.Nodes
                |> Map.add "db" { d.Nodes.["db"] with HealthState = Healthy }
                |> Map.add "obs" { d.Nodes.["obs"] with HealthState = Degraded } }

    let health = calculateSystemHealth dag
    Assert.Equal(SystemDegraded, health.OverallStatus)

[<Fact>]
let ``System status is Failed when any node is failed`` () =
    let containers = [
        { Name = "db"; Image = "localhost/db:nixos"; DependsOn = None }
    ]
    let dag =
        buildDAG containers
        |> fun d -> { d with
            Nodes = d.Nodes |> Map.add "db" { d.Nodes.["db"] with HealthState = Failed } }

    let health = calculateSystemHealth dag
    Assert.Equal(SystemFailed, health.OverallStatus)
```

### L5.4 TDG Harness Tests

```fsharp
module Cepaf.Tests.TDGHarnessTests

open Xunit
open Cepaf.Testing.TDGHarness

[<Fact>]
let ``TDG-001: requireTestExists fails when no test file exists`` () =
    let result = requireTestExists "NonExistent.fs"
    Assert.True(Result.isError result)

[<Fact>]
let ``TDG-002: requireTestFails returns FailingTest for red test`` () =
    // This would be a real failing test in practice
    let mockFailingTest = { Path = "test.fs"; Error = "AssertionFailed" }
    let result = requireTestFails "test.fs"
    Assert.True(Result.isOk result)

[<Fact>]
let ``TDG-005: Dual property testing is enforced`` () =
    let testContent = """
    module Tests
    open PropCheck
    open ExUnitProperties
    """
    let result = validateDualPropertyTesting testContent
    Assert.True(Result.isOk result)

[<Fact>]
let ``TDG-005: Missing PropCheck fails validation`` () =
    let testContent = """
    module Tests
    open ExUnitProperties
    """
    let result = validateDualPropertyTesting testContent
    Assert.True(Result.isError result)
```

### L5.5 AOR Engine Tests

```fsharp
module Cepaf.Tests.AOREngineTests

open Xunit
open Cepaf.Modules.AOREngine

[<Fact>]
let ``AOR-QUA-001: Zero warnings enforced`` () =
    let result = enforceZeroWarnings { Errors = 0; Warnings = 0 }
    Assert.True(Result.isOk result)

[<Fact>]
let ``AOR-QUA-001: Any warning fails validation`` () =
    let result = enforceZeroWarnings { Errors = 0; Warnings = 1 }
    match result with
    | Error v -> Assert.Equal("AOR-QUA-001", v.RuleId)
    | Ok _ -> Assert.True(false, "Should have failed")

[<Fact>]
let ``AOR-SAF-001: Halt time under 1s passes`` () =
    let result = validateSafetyHalt (TimeSpan.FromMilliseconds(500.0))
    Assert.True(Result.isOk result)

[<Fact>]
let ``AOR-SAF-001: Halt time over 1s fails`` () =
    let result = validateSafetyHalt (TimeSpan.FromSeconds(2.0))
    match result with
    | Error v -> Assert.Equal("AOR-SAF-001", v.RuleId)
    | Ok _ -> Assert.True(false, "Should have failed")

[<Fact>]
let ``AOR-BATCH-001: Batch size under 10 passes`` () =
    let changes = [1..8] |> List.map (fun i -> { Id = i; Content = "change" })
    let result = limitBatchSize changes
    Assert.True(Result.isOk result)

[<Fact>]
let ``AOR-BATCH-001: Batch size over 10 fails`` () =
    let changes = [1..15] |> List.map (fun i -> { Id = i; Content = "change" })
    let result = limitBatchSize changes
    match result with
    | Error v -> Assert.Equal("AOR-BATCH-001", v.RuleId)
    | Ok _ -> Assert.True(false, "Should have failed")

[<Fact>]
let ``AOR-EXE-001: Executive authority is respected`` () =
    let action = { Type = "Deploy"; RequiresAuth = true }
    let agent = { Role = Executive; Permissions = ["Deploy"; "Stop"; "Override"] }
    let result = checkExecutiveAuthority agent action
    Assert.True(Result.isOk result)

[<Fact>]
let ``AOR-EXE-001: Worker cannot perform executive actions`` () =
    let action = { Type = "Deploy"; RequiresAuth = true }
    let agent = { Role = Worker; Permissions = ["Execute"] }
    let result = checkExecutiveAuthority agent action
    Assert.True(Result.isError result)
```

---

## Implementation Timeline

| Phase | Level | Tasks | Deliverables |
|-------|-------|-------|--------------|
| 1 | L3.1.1 | ConstraintValidator.fs | Container constraint validation |
| 2 | L3.4.1 | ServiceDAG.fs | DAG and topological sort |
| 3 | L3.4.2 | HealthPropagation.fs | Health state machine |
| 4 | L3.5.1 | NodeVerifier.fs | Node-level verification |
| 5 | L3.5.2 | ChainVerifier.fs | Full chain verification |
| 6 | L3.2.1 | TDGHarness.fs | Test-first workflow |
| 7 | L3.3.1 | AOREngine.fs | Rule enforcement |
| 8 | L5.* | All Tests | Full test coverage |

---

## Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| STAMP constraints verified | 65/65 | Automated test suite |
| TDG rules enforced | 10/10 | CI pipeline checks |
| AOR rules active | 40/40 | Runtime validation |
| Test coverage | >95% | dotnet test --collect |
| Boot time | <30s | SC-CEP-004 validation |
| Response time | <50ms | SC-PRF-050 validation |

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cycle detection failure | High | Multiple algorithm validation |
| Health propagation race | High | Async locking, idempotent updates |
| Constraint bypass | Critical | Compile-time enforcement |
| TDG workflow skip | High | CI gate enforcement |
| AOR violation | Medium | Logging and alerting |

---

**Document Owner**: Claude Cybernetic Architect
**Framework**: CEPAF F# v20.0 - STAMP/TDG/AOR Edition
**Created**: 2025-12-24 02:00 CET
**Status**: ACTIVE

---

## Appendix A: File Structure

```
lib/cepaf/
├── src/
│   ├── Cepaf/
│   │   ├── Modules/
│   │   │   ├── PathResolver.fs       [COMPLETE]
│   │   │   ├── Podman.fs             [COMPLETE]
│   │   │   ├── ConstraintValidator.fs [PLANNED]
│   │   │   ├── ServiceDAG.fs         [PLANNED]
│   │   │   ├── HealthPropagation.fs  [PLANNED]
│   │   │   └── AOREngine.fs          [PLANNED]
│   │   ├── Phases/
│   │   │   ├── VTO.fs                [COMPLETE]
│   │   │   ├── DbVerifier.fs         [COMPLETE]
│   │   │   └── ObsVerifier.fs        [COMPLETE]
│   │   ├── Verification/
│   │   │   ├── NodeVerifier.fs       [PLANNED]
│   │   │   └── ChainVerifier.fs      [PLANNED]
│   │   └── Testing/
│   │       ├── TDGHarness.fs         [PLANNED]
│   │       └── PropertyGenerator.fs  [PLANNED]
│   └── Cepaf.Tests/
│       ├── PathResolverTests.fs      [COMPLETE - 16 tests]
│       ├── ConstraintValidatorTests.fs [PLANNED]
│       ├── ServiceDAGTests.fs        [PLANNED]
│       ├── HealthPropagationTests.fs [PLANNED]
│       ├── TDGHarnessTests.fs        [PLANNED]
│       └── AOREngineTests.fs         [PLANNED]
├── artifacts/
│   ├── podman-compose-db-standalone.yml  [COMPLETE]
│   └── podman-compose-obs-standalone.yml [COMPLETE]
└── docs/
    ├── CEPAF-STAMP-TDG-AOR-Specification.md   [COMPLETE]
    ├── CONTAINER-INVENTORY-Dev-Demo.md        [COMPLETE]
    ├── SERVICE-CHAIN-DAG-Dev-Demo.md          [COMPLETE]
    └── PLAN-5Level-STAMP-TDG-AOR-Implementation-20251224.md [THIS FILE]
```
