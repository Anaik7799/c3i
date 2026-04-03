# CEPAF Implementation Guide

**Version**: 20.0
**Language**: F# (.NET 8.0)
**Last Updated**: 2024-12-24

This guide provides comprehensive instructions for implementing new features, containers, verifiers, and safety constraints within the CEPAF (Cybernetic Execution and Performance Architect Framework).

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [DAG-Based Container Management](#2-dag-based-container-management)
3. [Implementing Verifiers](#3-implementing-verifiers)
4. [Logging and Telemetry](#4-logging-and-telemetry)
5. [STAMP Constraint Implementation](#5-stamp-constraint-implementation)
6. [Code Examples](#6-code-examples)
7. [Common Patterns](#7-common-patterns)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Getting Started

### 1.1 Prerequisites

Before working with CEPAF, ensure you have:

- **.NET 8.0 SDK** - Required for building and running F# projects
- **Podman 5.4.1+** - Container runtime (rootless mode required)
- **F# Language Support** - IDE support (VS Code + Ionide recommended)

Verify your environment:

```bash
# Check .NET version
dotnet --version  # Should be 8.x

# Check Podman version (SC-CNT-012: Rootless 5.4.1+)
podman --version  # Should be 5.4.1 or higher

# Check Podman is rootless
podman info --format '{{.Host.Security.Rootless}}'  # Should be true

# Verify socket exists
ls -la $XDG_RUNTIME_DIR/podman/podman.sock
```

### 1.2 Project Structure Overview

```
lib/cepaf/
|-- src/
|   |-- Cepaf/                      # Core framework
|   |   |-- Domain.fs               # Core type definitions
|   |   |-- Rop.fs                  # Railway-Oriented Programming
|   |   |-- Infrastructure.fs       # Process runner, task execution
|   |   |-- Orchestrator.fs         # Main protocol execution
|   |   |-- OodaController.fs       # OODA cybernetic loop
|   |   |-- Modules/                # Core modules
|   |   |   |-- PathResolver.fs     # Centralized path resolution
|   |   |   |-- ServiceDAG.fs       # Dependency graph management
|   |   |   |-- ChainVerifier.fs    # FPPS consensus verification
|   |   |   |-- ConstraintValidator.fs  # STAMP validation
|   |   |   |-- TDGHarness.fs       # Test-Driven Generation
|   |   |   |-- AOREngine.fs        # Agent Operating Rules
|   |   |-- ServiceChains/          # Service chain definitions
|   |   |   |-- DevChain.fs         # Dev/Demo environment
|   |   |   |-- ObsChain.fs         # Observability chain
|   |   |-- Phases/                 # Execution phases
|   |   |   |-- VTO.fs              # Sterilization phase
|   |   |   |-- AceVerifier.fs      # Active probing verifier
|   |   |   |-- DbVerifier.fs       # Database verification
|   |   |   |-- ObsVerifier.fs      # Observability verification
|   |   |-- Observability/          # Logging & metrics
|   |   |   |-- Types.fs            # Observability types
|   |   |   |-- QuadplexLogger.fs   # 4-channel logger
|   |   |-- Program.fs              # CLI entry point
|   |
|   |-- Cepaf.Podman/               # Podman API client
|   |   |-- Domain/                 # Podman types
|   |   |-- Client/                 # HTTP/Socket clients
|   |   |-- Api/                    # API operations
|   |   |-- Safety/                 # STAMP constraints
|   |
|   |-- Cepaf.Bridge/               # Elixir integration
|
|-- tests/
|   |-- Cepaf.Podman.Tests/         # Integration tests
|
|-- Cepaf.sln                       # Solution file
```

### 1.3 Build and Test Commands

```bash
# Navigate to CEPAF directory
cd lib/cepaf

# Restore dependencies
dotnet restore

# Build all projects
dotnet build

# Build for release
dotnet build -c Release

# Run all tests
dotnet test

# Run tests with verbose output
dotnet test --verbosity normal

# Run specific test project
dotnet test tests/Cepaf.Podman.Tests/Cepaf.Podman.Tests.fsproj

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Run property tests only
dotnet test --filter "Category=Property"

# Run the CLI
dotnet run --project src/Cepaf/Cepaf.fsproj -- --help

# Run with specific flags
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -y -v
```

---

## 2. DAG-Based Container Management

CEPAF uses a Directed Acyclic Graph (DAG) to manage container dependencies. This ensures correct startup order and prevents circular dependencies (SC-AGT-018).

### 2.1 ContainerDef Type

The `ContainerDef` type defines a container within the service chain:

```fsharp
/// Container definition for DAG building
type ContainerDef = {
    Name: string                                  // Container name (e.g., "indrajaal-db")
    Image: string                                 // Image reference (must use localhost/)
    DependsOn: string list                        // List of dependency container names
    DependencyTypes: Map<string, DependencyType>  // Map dependency name to type
    Layer: int option                             // Optional predefined layer
}
```

### 2.2 Defining a New Container

To add a new container to the service chain:

```fsharp
/// Example: Adding a new cache container
let cacheContainer : ContainerDef = {
    Name = "indrajaal-cache"
    Image = "localhost/indrajaal-cache:nixos-devenv"  // SC-CNT-010: localhost/ only
    DependsOn = ["indrajaal-db"]                      // Depends on database
    DependencyTypes = Map.ofList [
        ("indrajaal-db", Mandatory)                   // Database must be healthy
    ]
    Layer = Some 1                                    // Optional: Layer 1 (after DB)
}
```

### 2.3 Dependency Types

CEPAF supports two dependency types:

```fsharp
type DependencyType =
    | Mandatory   // Must be healthy for dependent to start
    | Optional    // Can degrade gracefully if unhealthy
```

- **Mandatory**: Blocks dependent container startup if unhealthy
- **Optional**: Allows dependent to start in degraded mode

### 2.4 Adding Containers to a Service Chain

Service chains are defined in the `ServiceChains/` directory:

```fsharp
module Cepaf.ServiceChains.MyChain

open Cepaf.Modules.ServiceDAG

/// Define containers for the chain
let dbContainer : ContainerDef = {
    Name = "indrajaal-db"
    Image = "localhost/indrajaal-db:nixos-devenv"
    DependsOn = []
    DependencyTypes = Map.empty
    Layer = Some 0
}

let appContainer : ContainerDef = {
    Name = "indrajaal-app"
    Image = "localhost/indrajaal-app:nixos-devenv"
    DependsOn = ["indrajaal-db"]
    DependencyTypes = Map.ofList [("indrajaal-db", Mandatory)]
    Layer = Some 1
}

let cacheContainer : ContainerDef = {
    Name = "indrajaal-cache"
    Image = "localhost/indrajaal-cache:nixos-devenv"
    DependsOn = ["indrajaal-app"]
    DependencyTypes = Map.ofList [("indrajaal-app", Optional)]
    Layer = Some 2
}

/// All containers in the chain
let allContainers = [dbContainer; appContainer; cacheContainer]

/// Build the DAG
let buildMyChainDAG () : ServiceDAG =
    buildDAG allContainers
```

### 2.5 Layer Assignment Algorithm

Layers are automatically calculated based on dependency depth:

```fsharp
/// Assign layers based on dependency depth
/// Layer 0 = no dependencies, Layer N = max(dependency layers) + 1
let assignLayers (dag: ServiceDAG) : ServiceDAG =
    match topologicalSort dag with
    | Error _ -> { dag with IsValid = false }
    | Ok sorted ->
        let layerMap = Dictionary<string, int>()

        sorted |> List.iter (fun nodeId ->
            match dag.Nodes |> Map.tryFind nodeId with
            | None -> ()
            | Some node ->
                let maxDepLayer =
                    node.Dependencies
                    |> List.choose (fun dep ->
                        if layerMap.ContainsKey(dep) then Some (layerMap.[dep] + 1)
                        else None)
                    |> function
                        | [] -> 0
                        | layers -> List.max layers
                layerMap.[nodeId] <- maxDepLayer)

        // Update nodes with calculated layers
        // ...
```

### 2.6 Boot Sequence Calculation

Get the boot sequence for a chain:

```fsharp
/// Calculate boot sequence with timing estimates
let calculateBootSequence (dag: ServiceDAG) : BootSequence =
    let layeredDag = assignLayers dag

    match topologicalSort layeredDag with
    | Error _ ->
        { Order = []; EstimatedTimeMs = 0L; Layers = Map.empty }
    | Ok order ->
        // Estimate: 5s per layer (parallel within layer)
        let maxLayer = getMaxLayer layeredDag
        let estimatedTimeMs = int64 ((maxLayer + 1) * 5000)

        { Order = order
          EstimatedTimeMs = estimatedTimeMs
          Layers = layeredDag.Layers }

// Usage
let sequence = calculateBootSequence (buildMyChainDAG ())
printfn "Boot order: %A" sequence.Order
printfn "Estimated time: %dms" sequence.EstimatedTimeMs
```

### 2.7 Cycle Detection

CEPAF uses Kahn's algorithm to detect cycles (SC-AGT-018):

```fsharp
/// Detect cycles in DAG using Kahn's algorithm
let detectCycles (dag: ServiceDAG) : CycleResult =
    // ... implementation
    if sorted.Count = dag.Nodes.Count then
        NoCycle
    else
        let cycleNodes = // nodes not in sorted list
        CycleDetected cycleNodes

// Usage - validate before deployment
let dag = buildMyChainDAG ()
match detectCycles dag with
| NoCycle -> printfn "DAG is valid"
| CycleDetected nodes ->
    failwithf "[SC-AGT-018] Circular dependency: %s" (String.concat " -> " nodes)
```

---

## 3. Implementing Verifiers

### 3.1 Creating a New Verifier Module

Verifiers are placed in `src/Cepaf/Phases/`. Here's the structure:

```fsharp
namespace Cepaf.Phases

open System.Diagnostics
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Modules

/// My Custom Verifier Phase
/// STAMP Compliance: SC-XXX-YYY (description)
module MyVerifier =

    /// Execute the verification phase
    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("Starting Phase: MY_VERIFIER")
        logger.StartPhase("MY_VERIFIER")
        logger.Emit(PhaseStart "MY_VERIFIER")
        let sw = Stopwatch.StartNew()

        // Your verification logic here
        // ...

        sw.Stop()
        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds,
            Map.ofList [("phase", "MY_VERIFIER")])
        logger.EndPhase("MY_VERIFIER", sw.ElapsedMilliseconds, true)
        logger.Emit(PhaseComplete("MY_VERIFIER", sw.ElapsedMilliseconds, true))
        return ()
    }
```

### 3.2 FPPS 5-Method Pattern

FPPS (Five-Point Probing System) provides consensus-based health verification. All 5 methods must agree (SC-VAL-003: 100% consensus).

```fsharp
/// FPPS Consensus verification methods
type ConsensusMethod =
    | PodmanStatus      // podman ps check - container running
    | HealthEndpoint    // HTTP health endpoint - /health returns 200
    | PortProbe         // TCP port check - port is listening
    | ProcessCheck      // Process exists - main process running
    | LogAnalysis       // Log pattern matching - no ERROR in recent logs
```

#### Method 1: PodmanStatus

```fsharp
/// Check container is running via podman ps
let probePodmanStatus (runner: IProcessRunner) (nodeId: string) : Async<FPPSResult> = async {
    let! result = runner.Run("podman", ["ps"; "--filter"; sprintf "name=%s" nodeId; "--format"; "{{.State}}"])
    match result with
    | Ok res ->
        let state = res.StandardOutput.Trim()
        let passed = state.ToLowerInvariant().Contains("running")
        return {
            Method = PodmanStatus
            NodeId = nodeId
            Passed = passed
            Timestamp = DateTime.UtcNow
            Details = if passed then Some (sprintf "State: %s" state)
                      else Some (sprintf "Not running. State: %s" state)
        }
    | Error e ->
        return { Method = PodmanStatus; NodeId = nodeId; Passed = false
                 Timestamp = DateTime.UtcNow; Details = Some (sprintf "Error: %A" e) }
}
```

#### Method 2: HealthEndpoint

```fsharp
/// HTTP GET to /health endpoint
let probeHealthEndpoint (nodeId: string) (port: int) (path: string) (timeoutMs: int) : Async<FPPSResult> = async {
    use client = new HttpClient()
    client.Timeout <- TimeSpan.FromMilliseconds(float timeoutMs)
    let url = sprintf "http://127.0.0.1:%d%s" port path

    try
        let! response = client.GetAsync(url) |> Async.AwaitTask
        return {
            Method = HealthEndpoint
            NodeId = nodeId
            Passed = response.IsSuccessStatusCode
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "HTTP %d from %s" (int response.StatusCode) url)
        }
    with ex ->
        return { Method = HealthEndpoint; NodeId = nodeId; Passed = false
                 Timestamp = DateTime.UtcNow; Details = Some (sprintf "Error: %s" ex.Message) }
}
```

#### Method 3: PortProbe

```fsharp
/// TCP connection to expected port
let probePort (nodeId: string) (port: int) : Async<FPPSResult> = async {
    use client = new TcpClient()
    let sw = Stopwatch.StartNew()

    try
        do! client.ConnectAsync("127.0.0.1", port) |> Async.AwaitTask
        sw.Stop()
        return {
            Method = PortProbe
            NodeId = nodeId
            Passed = true
            Timestamp = DateTime.UtcNow
            Details = Some (sprintf "Port %d open, connected in %dms" port sw.ElapsedMilliseconds)
        }
    with ex ->
        return { Method = PortProbe; NodeId = nodeId; Passed = false
                 Timestamp = DateTime.UtcNow; Details = Some (sprintf "Port %d closed" port) }
}
```

#### Method 4: ProcessCheck

```fsharp
/// Verify main process running in container
let probeProcess (runner: IProcessRunner) (nodeId: string) : Async<FPPSResult> = async {
    let! result = runner.Run("podman", ["top"; nodeId; "-o"; "pid,comm"])
    match result with
    | Ok res ->
        let output = res.StandardOutput.Trim()
        let hasProcesses = output.Split('\n').Length > 1
        return {
            Method = ProcessCheck
            NodeId = nodeId
            Passed = hasProcesses
            Timestamp = DateTime.UtcNow
            Details = if hasProcesses then Some "Main process running"
                      else Some "No processes found"
        }
    | Error e ->
        return { Method = ProcessCheck; NodeId = nodeId; Passed = false
                 Timestamp = DateTime.UtcNow; Details = Some (sprintf "Error: %A" e) }
}
```

#### Method 5: LogAnalysis

```fsharp
/// Check recent logs for error patterns
let probeLogAnalysis (runner: IProcessRunner) (nodeId: string) (patterns: string list) (tailLines: int) : Async<FPPSResult> = async {
    let! result = runner.Run("podman", ["logs"; "--tail"; string tailLines; nodeId])
    match result with
    | Ok res ->
        let logs = res.StandardOutput + res.StandardError
        let foundPatterns = patterns |> List.filter (fun p -> logs.Contains(p))
        let passed = List.isEmpty foundPatterns
        return {
            Method = LogAnalysis
            NodeId = nodeId
            Passed = passed
            Timestamp = DateTime.UtcNow
            Details =
                if passed then Some "No error patterns in recent logs"
                else Some (sprintf "Found: %s" (String.concat ", " foundPatterns))
        }
    | Error _ ->
        // Don't fail chain for log read issues
        return { Method = LogAnalysis; NodeId = nodeId; Passed = true
                 Timestamp = DateTime.UtcNow; Details = Some "Log read issue (non-blocking)" }
}
```

### 3.3 Consensus Calculation

```fsharp
/// Check if all FPPS methods agree (SC-VAL-003)
let checkConsensusAgreement (results: FPPSResult list) (requireAll: bool) : bool =
    if requireAll then
        // SC-VAL-003: All 5 methods must pass
        results |> List.forall (fun r -> r.Passed)
    else
        // Majority (at least 3 of 5) must pass
        let passCount = results |> List.filter (fun r -> r.Passed) |> List.length
        passCount >= 3

/// Run all 5 FPPS methods for a single node
let runFPPSConsensusForNode
    (runner: IProcessRunner)
    (config: ChainVerifierConfig)
    (nodeId: string)
    (port: int)
    : Async<FPPSResult list> = async {

    let! results =
        [
            probePodmanStatus runner nodeId
            probeHealthEndpoint nodeId port config.HealthEndpointPath config.HealthTimeoutMs
            probePort nodeId port
            probeProcess runner nodeId
            probeLogAnalysis runner nodeId config.LogErrorPatterns config.LogTailLines
        ]
        |> Async.Parallel

    return results |> Array.toList
}
```

### 3.4 Error Handling with Result Types

CEPAF uses Railway-Oriented Programming with `Result` and `AsyncResult`:

```fsharp
/// AsyncResult is Async<Result<'T, 'E>>
type AsyncResult<'T, 'E> = Async<Result<'T, 'E>>

/// AppError covers all failure cases
type AppError =
    | InfrastructureError of tool: string * message: string
    | ProcessError of cmd: string * exitCode: int * stderr: string
    | HealthCheckTimedOut of service: string * probe: string
    | ConfigurationError of reason: string
    | DependencyCycleDetected of nodes: string list
    | ValidationFailed of rule: string * reason: string
    | SafetyViolation of constraintId: string * reason: string
    // ... more error types

// Using asyncResult computation expression
let myVerification (logger: QuadplexLogger) (runner: IProcessRunner) = asyncResult {
    // This will short-circuit on any Error result
    let! result1 = someAsyncOperation ()
    let! result2 = anotherOperation result1

    // Explicit error creation
    if result2.Count < 1 then
        return! fromResult (Error (ValidationFailed("MinCount", "Need at least 1 item")))

    return result2
}
```

---

## 4. Logging and Telemetry

### 4.1 QuadplexLogger (UnifiedLogger) Usage

CEPAF provides 4-channel logging (SC-OBS-069, SC-OBS-071):

1. **Console** - Terminal output with colors
2. **File** - Persistent JSON logs
3. **Telemetry** - OpenTelemetry/OTLP export
4. **StateTracker** - SQLite state persistence

```fsharp
// QuadplexLogger is aliased as UnifiedLogger
type QuadplexLogger = UnifiedLogger

// Basic logging
logger.Info("Starting verification phase")
logger.Debug("Processing node: %s" nodeId)
logger.Warning("Node %s took %dms (above threshold)" nodeId duration)
logger.Error("Verification failed: %s" reason)

// Logging with category (for OODA/phase tracking)
logger.LogWithCategory("Processing containers", EventCategory.Protocol, LogLevel.Debug)

// Emit structured events
logger.Emit(ProtocolStart DateTimeOffset.Now)
logger.Emit(PhaseStart "MY_PHASE")
logger.Emit(PhaseComplete("MY_PHASE", durationMs, true))
logger.Emit(MetricLogged("boot_time", 1234.0))
```

### 4.2 OTEL Integration

CEPAF integrates with OpenTelemetry for distributed tracing:

```fsharp
// Configuration
type QuadplexConfig = {
    // Telemetry/OTLP
    TelemetryEnabled: bool
    OtlpEndpoint: string          // e.g., "http://localhost:4317"
    OtlpProtocol: OtlpProtocol    // Grpc, HttpProtobuf, HttpJson
    ServiceName: string           // "cepaf"
    ServiceVersion: string        // "20.0.0"
    ServiceNamespace: string      // "indrajaal"
    // ...
}

// Traces are automatically propagated through spans
logger.StartTrace("CEPAF_PROTOCOL")  // Root span
logger.StartSpan("DEPLOY")           // Child span
// ... operations
logger.EndSpan("DEPLOY", "success")
```

### 4.3 Metric Recording

Three metric types: counters, gauges, and histograms:

```fsharp
// Counters - increment for events
logger.IncrementCounter("container.starts", tags = Map.ofList [("name", containerName)])
logger.IncrementCounter("fpps.probes_executed", tags = Map.ofList [("method", "PodmanStatus")])

// Gauges - set current value
logger.SetGauge("containers.running", float runningCount)
logger.SetGauge("config.patient_mode", 1.0)

// Histograms - record distributions
logger.RecordHistogram("boot.duration_ms", float bootTimeMs,
    Map.ofList [("env", "DEV")])
logger.RecordHistogram("phase.duration_ms", float durationMs,
    Map.ofList [("phase", "VTO")])

// Timers - automatic duration recording
use timer = logger.StartTimer("process.duration", Map.ofList [("cmd", "podman")])
// ... operation runs
// Duration automatically recorded when timer is disposed
```

### 4.4 Span Tracking for Distributed Tracing

```fsharp
// Start a trace (root span)
let traceId = logger.StartTrace("CEPAF_PROTOCOL")

// Start child spans for phases
logger.StartSpan("VTO") |> ignore
// ... VTO operations
logger.EndSpan("VTO", "success")

logger.StartSpan("DEPLOY") |> ignore
// ... deploy operations
logger.EndSpan("DEPLOY", "success")

// Get current trace ID for correlation
let currentTrace = logger.GetCurrentTraceId()

// End protocol trace
logger.EndProtocol(totalDurationMs, success = true)
```

### 4.5 Phase Lifecycle Tracking

```fsharp
// Standard phase lifecycle pattern
let executePhase (logger: QuadplexLogger) (phaseName: string) (action: unit -> Async<Result<unit, AppError>>) = asyncResult {
    logger.Info(sprintf "Starting Phase: %s" phaseName)
    logger.StartPhase(phaseName)
    logger.Emit(PhaseStart phaseName)

    let sw = Stopwatch.StartNew()

    try
        do! action ()
        sw.Stop()

        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds,
            Map.ofList [("phase", phaseName)])
        logger.EndPhase(phaseName, sw.ElapsedMilliseconds, true)
        logger.Emit(PhaseComplete(phaseName, sw.ElapsedMilliseconds, true))

        return ()
    with ex ->
        sw.Stop()
        logger.EndPhase(phaseName, sw.ElapsedMilliseconds, false)
        logger.Emit(PhaseComplete(phaseName, sw.ElapsedMilliseconds, false))
        return! fromResult (Error (InfrastructureError(phaseName, ex.Message)))
}
```

---

## 5. STAMP Constraint Implementation

### 5.1 How to Add a New Safety Constraint

1. **Define the Constraint ID** in the appropriate category:

```fsharp
/// Safety constraint identifier
type ConstraintId =
    // Existing constraints
    | SC_CNT_009  // NixOS/Podman only
    | SC_CNT_010  // Localhost registry only
    // Your new constraint
    | SC_MY_001   // Description of your constraint
```

2. **Create the Validation Function**:

```fsharp
/// Validate my new constraint (SC-MY-001)
let validateMyConstraint (input: MyInput) : ValidationResult =
    let violations = [
        if not (meetsConstraint input) then
            yield {
                Constraint = SC_MY_001
                Resource = input.Name
                Message = "Input violates SC-MY-001: reason here"
                Severity = Critical  // or Warning, Info
                Timestamp = DateTimeOffset.UtcNow
            }
    ]

    if violations.IsEmpty then Valid else Invalid violations
```

3. **Integrate into Validation Pipeline**:

```fsharp
/// Combined validation for container spec
let validateContainerSpec (spec: ContainerSpec) : ValidationResult =
    [
        validateImageReference spec.Image      // SC-CNT-010
        validateNamingConvention spec.Name     // SC-POD-001
        validateResourceLimits spec.Resources  // SC-POD-002
        validateMyConstraint spec              // SC-MY-001 (new)
    ]
    |> ValidationResult.combineAll
```

### 5.2 Constraint Verification Functions

```fsharp
/// Validation result type
type ValidationResult =
    | Valid
    | Invalid of Violation list

module ValidationResult =
    let isValid = function Valid -> true | Invalid _ -> false
    let violations = function Valid -> [] | Invalid vs -> vs

    /// Combine multiple results (accumulates violations)
    let combine (r1: ValidationResult) (r2: ValidationResult) : ValidationResult =
        match r1, r2 with
        | Valid, Valid -> Valid
        | Valid, Invalid vs -> Invalid vs
        | Invalid vs, Valid -> Invalid vs
        | Invalid vs1, Invalid vs2 -> Invalid (vs1 @ vs2)

    let combineAll (results: ValidationResult list) : ValidationResult =
        results |> List.fold combine Valid
```

### 5.3 Compliance Checking Patterns

```fsharp
/// Runtime constraint checking with async operations
let validateRootless (client: PodmanClient) : AsyncPodmanResult<ValidationResult> = async {
    let! infoResult = System.info client
    return infoResult |> Result.map (fun info ->
        if info.Host.Os <> "linux" then
            Invalid [{
                Constraint = SC_CNT_009
                Resource = "host"
                Message = sprintf "Expected Linux host, got '%s' (SC-CNT-009)" info.Host.Os
                Severity = Critical
                Timestamp = DateTimeOffset.UtcNow
            }]
        else
            Valid
    )
}

/// Safe operation wrapper (validates before executing)
let safeCreateContainer (client: PodmanClient) (spec: ContainerSpec) : AsyncPodmanResult<string> = async {
    match validateContainerSpec spec with
    | Invalid violations ->
        let criticals = violations |> List.filter (fun v -> v.Severity = Critical)
        if not criticals.IsEmpty then
            let msgs = criticals |> List.map (fun v -> v.Message)
            return Error (PodmanError.ValidationFailed msgs)
        else
            // Warnings only - proceed with monitoring
            return! Containers.create client spec
    | Valid ->
        return! Containers.create client spec
}
```

---

## 6. Code Examples

### 6.1 Adding a New Container

```fsharp
module Cepaf.ServiceChains.ExtendedDevChain

open Cepaf.Modules.ServiceDAG

/// Step 1: Define the container
let messageQueueContainer : ContainerDef = {
    Name = "indrajaal-mq"
    Image = "localhost/indrajaal-rabbitmq:nixos-devenv"  // SC-CNT-010
    DependsOn = ["indrajaal-app"]                        // Starts after app
    DependencyTypes = Map.ofList [
        ("indrajaal-app", Optional)                      // App can work without MQ
    ]
    Layer = Some 2                                       // Same layer as observability
}

/// Step 2: Add health check config
type MqHealthConfig = {
    Port: int
    ManagementPort: int
    HealthEndpoint: string
}

let mqHealthConfig : MqHealthConfig = {
    Port = 5672
    ManagementPort = 15672
    HealthEndpoint = "/api/healthchecks/node"
}

/// Step 3: Add to container list
let extendedContainers : ContainerDef list =
    DevChain.fullContainers @ [messageQueueContainer]

/// Step 4: Build DAG and validate
let buildExtendedDAG () : Result<ServiceDAG, string list> =
    let dag = buildDAG extendedContainers
    validate dag

/// Step 5: Update port map
let extendedPortMap : Map<string, int> =
    DevChain.devPortMap
    |> Map.add "indrajaal-mq" 5672
    |> Map.add "indrajaal-mq-mgmt" 15672
```

### 6.2 Implementing a Verifier

```fsharp
namespace Cepaf.Phases

open System
open System.Diagnostics
open Cepaf
open Cepaf.Infrastructure
open Cepaf.Rop
open Cepaf.Modules.ChainVerifier

/// Message Queue Verifier Phase
/// STAMP Compliance: SC-CEP-003 (FPPS consensus)
module MqVerifier =

    /// Verify RabbitMQ management API
    let verifyManagementApi (logger: QuadplexLogger) (port: int) = async {
        let! result = probeHealthEndpoint "indrajaal-mq" port "/api/healthchecks/node" 5000
        logger.IncrementCounter("mq.management_check",
            tags = Map.ofList [("result", if result.Passed then "pass" else "fail")])
        return result
    }

    /// Verify AMQP port
    let verifyAmqpPort (logger: QuadplexLogger) (port: int) = async {
        let! result = probePort "indrajaal-mq" port
        logger.IncrementCounter("mq.amqp_check",
            tags = Map.ofList [("result", if result.Passed then "pass" else "fail")])
        return result
    }

    /// Main verification with FPPS consensus
    let execute (logger: QuadplexLogger) (runner: IProcessRunner) (config: CepaConfig) = asyncResult {
        logger.Info("Starting Phase: MQ_VERIFIER")
        logger.StartPhase("MQ_VERIFIER")
        let sw = Stopwatch.StartNew()

        // Run FPPS probes
        let! results = async {
            let! r1 = probePodmanStatus runner "indrajaal-mq"
            let! r2 = probeHealthEndpoint "indrajaal-mq" 15672 "/api/healthchecks/node" 5000
            let! r3 = probePort "indrajaal-mq" 5672
            let! r4 = probeProcess runner "indrajaal-mq"
            let! r5 = probeLogAnalysis runner "indrajaal-mq" ["ERROR"; "FATAL"] 50
            return [r1; r2; r3; r4; r5]
        }

        // Check consensus (SC-VAL-003)
        let consensus = checkConsensusAgreement results true

        if not consensus then
            let failed = results |> List.filter (fun r -> not r.Passed)
            logger.Error(sprintf "MQ verification failed: %d/5 probes passed"
                (results |> List.filter (fun r -> r.Passed) |> List.length))
            return! fromResult (Error (ValidationFailed("MQ_FPPS", "Consensus not achieved")))

        sw.Stop()
        logger.RecordHistogram("phase.duration_ms", float sw.ElapsedMilliseconds,
            Map.ofList [("phase", "MQ_VERIFIER")])
        logger.EndPhase("MQ_VERIFIER", sw.ElapsedMilliseconds, true)
        logger.Info("MQ verification: FPPS consensus achieved (5/5)")

        return ()
    }
```

### 6.3 FPPS Consensus Check

```fsharp
/// Complete FPPS consensus verification for a service
let verifyServiceWithFPPS
    (logger: QuadplexLogger)
    (runner: IProcessRunner)
    (serviceName: string)
    (port: int)
    (healthPath: string)
    : Async<Result<unit, AppError>> = async {

    logger.Info(sprintf "Running FPPS 5-method consensus for %s..." serviceName)

    // Execute all 5 probes in parallel
    let! results =
        [
            probePodmanStatus runner serviceName
            probeHealthEndpoint serviceName port healthPath 5000
            probePort serviceName port
            probeProcess runner serviceName
            probeLogAnalysis runner serviceName ["ERROR"; "FATAL"; "CRITICAL"] 50
        ]
        |> Async.Parallel

    let resultsList = results |> Array.toList
    let passCount = resultsList |> List.filter (fun r -> r.Passed) |> List.length

    // Log individual results
    resultsList |> List.iter (fun r ->
        let status = if r.Passed then "PASS" else "FAIL"
        let methodName = sprintf "%A" r.Method
        let details = r.Details |> Option.defaultValue ""
        logger.LogWithCategory(
            sprintf "  [%s] %s: %s" status methodName details,
            EventCategory.Protocol,
            if r.Passed then LogLevel.Debug else LogLevel.Warning))

    // Record metrics
    logger.SetGauge("fpps.pass_count", float passCount,
        Map.ofList [("service", serviceName)])

    // Check consensus (SC-VAL-003: 100% required)
    if passCount = 5 then
        logger.Info(sprintf "Consensus ACHIEVED for %s: 5/5 probes passed" serviceName)
        logger.IncrementCounter("fpps.consensus_achieved",
            tags = Map.ofList [("service", serviceName)])
        return Ok ()
    else
        let failedMethods =
            resultsList
            |> List.filter (fun r -> not r.Passed)
            |> List.map (fun r -> sprintf "%A" r.Method)
        logger.Error(sprintf "Consensus FAILED for %s: %d/5 probes passed. Failed: %s"
            serviceName passCount (String.concat ", " failedMethods))
        logger.IncrementCounter("fpps.consensus_failed",
            tags = Map.ofList [("service", serviceName)])
        return Error (ValidationFailed("FPPS", sprintf "Only %d/5 probes passed" passCount))
}
```

---

## 7. Common Patterns

### 7.1 AsyncResult Computation Expression

The `asyncResult` computation expression combines `Async` and `Result`:

```fsharp
open Cepaf.Rop

/// Basic usage - automatic short-circuit on Error
let myOperation () = asyncResult {
    let! data = fetchDataAsync ()           // Async<Result<Data, AppError>>
    let! processed = processData data       // Async<Result<Processed, AppError>>
    let! validated = validateResult processed  // Async<Result<Validated, AppError>>
    return validated
}

/// Converting from plain Async
let wrapAsync () = asyncResult {
    let! plainResult = fromAsync (someAsyncOperation ())  // Wrap Async<T> to AsyncResult<T, AppError>
    return plainResult
}

/// Converting from plain Result
let wrapResult () = asyncResult {
    let! value = fromResult (someResultOperation ())  // Wrap Result<T, AppError> to AsyncResult<T, AppError>
    return value
}

/// Using tee for side effects
let withLogging () = asyncResult {
    let! result =
        someOperation ()
        |> tee (fun v -> printfn "Got value: %A" v)  // Side effect on Ok
        |> teeError (fun e -> printfn "Got error: %A" e)  // Side effect on Error
    return result
}

/// Sequencing multiple operations
let batchOperations () = asyncResult {
    let operations = [op1; op2; op3]  // Async<Result<T, AppError>> list
    let! results = sequence operations  // Runs in parallel, fails fast on first error
    return results
}
```

### 7.2 Factory Function Pattern for Tests

```fsharp
module Cepaf.Tests.TestFactories

open Cepaf
open Cepaf.Modules.ServiceDAG

/// Factory for creating test ContainerDef
let createTestContainer
    ?(name = "test-container")
    ?(image = "localhost/test:latest")
    ?(dependsOn = [])
    ?(dependencyTypes = Map.empty)
    ?(layer = None)
    : ContainerDef =
    {
        Name = name
        Image = image
        DependsOn = dependsOn
        DependencyTypes = dependencyTypes
        Layer = layer
    }

/// Factory for creating test SystemRegistry
let createTestRegistry
    ?(logPath = "test.log")
    ?(dbPath = "test.db")
    ?(tempDir = "test_tmp")
    : SystemRegistry =
    {
        LogPath = logPath
        DatabasePath = dbPath
        TempDir = tempDir
        ComposeFiles = Map.empty
        ContainerNames = Map.empty
        PortMap = Map.empty
        ReadyPatterns = Map.empty
        Dockerfiles = Map.empty
        Constraints = []
        PodmanSocket = None
    }

/// Factory for creating test CepaConfig
let createTestConfig
    ?(environments = [DEV])
    ?(sterilize = false)
    ?(formalVerify = false)
    ?(build = false)
    ?(patientMode = false)
    ?(registry = createTestRegistry ())
    : CepaConfig =
    {
        Environments = environments
        Sterilize = sterilize
        FormalVerify = formalVerify
        Build = build
        DbTestOnly = false
        ObsTestOnly = false
        InfraCheck = true
        RunTests = false
        RunUiCheck = false
        AutoConfirm = true
        PatientMode = patientMode
        PhicsEnabled = true
        BootThresholdMs = 30000L
        Registry = registry
    }

// Usage in tests
[<Fact>]
let ``should build DAG with dependencies`` () =
    let db = createTestContainer(name = "db", layer = Some 0)
    let app = createTestContainer(
        name = "app",
        dependsOn = ["db"],
        dependencyTypes = Map.ofList [("db", Mandatory)],
        layer = Some 1)

    let dag = buildDAG [db; app]

    Assert.Equal(2, nodeCount dag)
    Assert.False(hasCycles dag)
```

### 7.3 IProcessRunner Abstraction

Mock the process runner for unit tests:

```fsharp
/// Production implementation
type CliProcessRunner(logger: UnifiedLogger) =
    interface IProcessRunner with
        member _.Run(cmd, args, ?patientMode) = async {
            // Real process execution with CliWrap
            let command = Cli.Wrap(cmd).WithArguments(args)
            let! result = command.ExecuteBufferedAsync().Task |> Async.AwaitTask
            if result.ExitCode = 0 then
                return Ok result
            else
                return Error (ProcessError(cmd, result.ExitCode, result.StandardError))
        }

/// Mock implementation for tests
type MockProcessRunner(responses: Map<string, string>) =
    interface IProcessRunner with
        member _.Run(cmd, args, ?patientMode) = async {
            let key = sprintf "%s %s" cmd (String.concat " " args)
            match responses |> Map.tryFind key with
            | Some output ->
                return Ok (BufferedCommandResult(0, DateTimeOffset.Now, DateTimeOffset.Now, output, ""))
            | None ->
                return Ok (BufferedCommandResult(0, DateTimeOffset.Now, DateTimeOffset.Now, "", ""))
        }

// Usage in tests
[<Fact>]
let ``should detect running container`` () = async {
    let responses = Map.ofList [
        ("podman ps --filter name=test-container --format {{.State}}", "running")
    ]
    let runner = MockProcessRunner(responses) :> IProcessRunner

    let! result = probePodmanStatus runner "test-container"

    Assert.True(result.Passed)
}
```

---

## 8. Troubleshooting

### 8.1 Common Build Errors and Fixes

#### Error: Missing package reference

```
error NU1101: Unable to find package 'SomePackage'
```

**Fix**: Add package to `.fsproj`:
```xml
<PackageReference Include="SomePackage" Version="X.Y.Z" />
```

Then restore:
```bash
dotnet restore
```

#### Error: Type mismatch in asyncResult

```
error FS0001: Type mismatch. Expecting Async<Result<'a, AppError>> but given Async<'b>
```

**Fix**: Use `fromAsync` to wrap plain async:
```fsharp
// Before
let! result = someAsyncOperation ()

// After
let! result = fromAsync (someAsyncOperation ())
```

#### Error: Module not found

```
error FS0039: The namespace or module 'Cepaf.Modules.MyModule' is not defined
```

**Fix**: Ensure file is listed in `.fsproj` in correct order (dependencies first):
```xml
<Compile Include="Modules/ServiceDAG.fs" />
<Compile Include="Modules/MyModule.fs" />  <!-- After ServiceDAG if it depends on it -->
```

### 8.2 Debug Logging

Enable verbose logging for debugging:

```fsharp
// Create logger with debug level
let config = {
    QuadplexDefaults.developmentConfig with
        ConsoleMinLevel = LogLevel.Debug
        FileMinLevel = LogLevel.Trace
}

let logger = new QuadplexLoggerInstance(config)

// Add debug output in your code
logger.Debug(sprintf "Processing node %s with %d dependencies" nodeId depCount)
logger.Trace(sprintf "Raw response: %s" response)
```

### 8.3 Container Inspection Commands

```bash
# List all containers
podman ps -a

# Inspect container details
podman inspect indrajaal-db

# View container logs
podman logs --tail 100 indrajaal-db

# Check container health
podman healthcheck run indrajaal-db

# View container processes
podman top indrajaal-db

# Get container stats
podman stats --no-stream indrajaal-db

# Network inspection
podman network inspect indrajaal-net

# Volume inspection
podman volume inspect indrajaal-data
```

### 8.4 Debugging FPPS Failures

When FPPS consensus fails, check each method individually:

```bash
# 1. PodmanStatus - Is container running?
podman ps --filter name=my-container --format "{{.State}}"

# 2. HealthEndpoint - Does HTTP health check pass?
curl -v http://127.0.0.1:4000/health

# 3. PortProbe - Is port listening?
nc -zv 127.0.0.1 4000

# 4. ProcessCheck - Are processes running?
podman top my-container -o pid,comm

# 5. LogAnalysis - Any errors in logs?
podman logs --tail 50 my-container | grep -E "ERROR|FATAL|CRITICAL"
```

### 8.5 DAG Validation Issues

```fsharp
// Debug DAG structure
let dag = buildMyDAG ()
printfn "%s" (formatAsText dag)

// Check specific issues
match detectCycles dag with
| CycleDetected nodes ->
    printfn "CYCLE: %s" (String.concat " -> " nodes)
| NoCycle ->
    printfn "No cycles"

// Validate and get all errors
match validate dag with
| Ok validDag -> printfn "DAG valid with %d layers" (getMaxLayer validDag)
| Error errors -> errors |> List.iter (printfn "ERROR: %s")
```

---

## Appendix: Quick Reference

### Key Types

| Type | Purpose | Location |
|------|---------|----------|
| `ContainerDef` | Container definition | `Modules/ServiceDAG.fs` |
| `ServiceDAG` | Dependency graph | `Modules/ServiceDAG.fs` |
| `AsyncResult<'T, AppError>` | Async operation result | `Rop.fs` |
| `AppError` | Error union type | `Domain.fs` |
| `QuadplexLogger` | 4-channel logger | `Observability/QuadplexLogger.fs` |
| `ValidationResult` | Constraint check result | `Safety/Constraints.fs` |
| `FPPSResult` | Single probe result | `Modules/ChainVerifier.fs` |

### Key Functions

| Function | Purpose | Location |
|----------|---------|----------|
| `buildDAG` | Create DAG from containers | `ServiceDAG.fs` |
| `detectCycles` | Find circular deps | `ServiceDAG.fs` |
| `topologicalSort` | Get boot order | `ServiceDAG.fs` |
| `asyncResult { }` | Computation expression | `Rop.fs` |
| `fromAsync` | Wrap Async to AsyncResult | `Rop.fs` |
| `fromResult` | Wrap Result to AsyncResult | `Rop.fs` |
| `checkConsensusAgreement` | FPPS consensus check | `ChainVerifier.fs` |

### STAMP Constraints Reference

| ID | Description | Severity |
|----|-------------|----------|
| SC-CNT-009 | NixOS/Podman only | Critical |
| SC-CNT-010 | localhost/ registry only | Critical |
| SC-CNT-012 | Rootless mode | Critical |
| SC-AGT-018 | No deadlocks (cycles) | Critical |
| SC-VAL-003 | 100% FPPS consensus | Critical |
| SC-CEP-003 | FPPS 5-method verification | Critical |
| SC-OBS-069 | Dual logging | High |
| SC-OBS-071 | 4 OTEL channels | High |

---

*Generated for CEPAF v20.0 - The Cybernetic Pledge: "I recognize the Codebase as a Living Graph. I pledge to fight Entropy with Simplicity, fragility with Resilience, and blindness with Observability. I am the Architect of the Loop."*
