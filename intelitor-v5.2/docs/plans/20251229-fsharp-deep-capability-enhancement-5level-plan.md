# F# Deep Capability Enhancement - 5-Level Plan
## Version 2.0.0 | Date: 2025-12-29 | Status: IN_PROGRESS

---

# LEVEL 1: EXECUTIVE SUMMARY

## 1.1 Objective
Apply the three F# capability modules (Units of Measure, Active Patterns, Function Composition)
deeply and creatively across the entire CEPAF F# codebase to achieve:
- **Type Safety**: Eliminate all runtime unit confusion
- **Pattern Matching**: Classify errors, health, container states semantically
- **Composition**: Enable fluent, functional pipelines

## 1.2 Scope
- **258 F# files** in lib/cepaf/
- **Focus Areas**: Podman, Observability, Cockpit, Modules, Phases, ServiceChains
- **Outcome**: 100% type-safe timing, comprehensive Active Pattern coverage

## 1.3 STAMP Constraints
| ID | Constraint | Application |
|----|------------|-------------|
| SC-FSH-003 | Active Patterns for classification | Error, Health, Container, Agent status |
| SC-FSH-004 | Units of Measure | All timeouts, ports, memory sizes |
| SC-FSH-010 | Kleisli composition | Pipeline operations |
| SC-FSH-011 | tap/applyIf | Side-effect handling |

---

# LEVEL 2: DOMAIN ARCHITECTURE

## 2.1 Enhancement Domains

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         F# CAPABILITY ENHANCEMENT MAP                         │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐   │
│  │  PODMAN DOMAIN      │  │  OBSERVABILITY      │  │  COCKPIT/DASHBOARD  │   │
│  │  (16 files)         │  │  (18 files)         │  │  (12 files)         │   │
│  │                     │  │                     │  │                     │   │
│  │  • Domain/Types.fs  │  │  • Fractal/Types.fs │  │  • ThemeSystem.fs   │   │
│  │  • Domain/Errors.fs │  │  • Fractal/HLC.fs   │  │  • Prajna.fs        │   │
│  │  • Health/Probes.fs │  │  • QuadplexLogger   │  │  • AiCopilot.fs     │   │
│  │  • Safety/Constr.fs │  │  • MetricsCollector │  │  • Material3.fs     │   │
│  │  • Events/Stream.fs │  │  • Dashboard.fs     │  │  • Domain.fs        │   │
│  │  • Api/*.fs         │  │  • Channels.fs      │  │  • Cockpit.fs       │   │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘   │
│                                                                               │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐   │
│  │  MODULES            │  │  SERVICE CHAINS     │  │  PHASES             │   │
│  │  (12 files)         │  │  (3 files)          │  │  (11 files)         │   │
│  │                     │  │                     │  │                     │   │
│  │  • AOREngine.fs     │  │  • DevChain.fs      │  │  • Builder.fs       │   │
│  │  • OodaController   │  │  • ObsChain.fs      │  │  • Tester.fs        │   │
│  │  • CyberneticAgents │  │  • StandaloneChain  │  │  • DbVerifier.fs    │   │
│  │  • HealthPropag.fs  │  │                     │  │  • AppVerifier.fs   │   │
│  │  • AgentMesh.fs     │  │                     │  │  • ObsVerifier.fs   │   │
│  │  • Podman.fs        │  │                     │  │  • VTO.fs           │   │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘   │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 2.2 Enhancement Categories

### Category A: Units of Measure (SC-FSH-004)
- All `TimeSpan` constants → type-safe `float<sec>` or `float<ms>`
- All port numbers → `int<port>`
- All memory sizes → `int64<bytes>` or typed wrappers
- All efficiency thresholds → `float<percent>`

### Category B: Active Patterns (SC-FSH-003)
- `PodmanError` → ErrorRecoverability, ErrorDomain patterns
- `ContainerStatus` → ContainerState pattern
- `HealthStatus` → HealthClassification pattern
- `AgentStatus` → AgentClassification pattern
- `ValidationResult` → ValidationOutcome pattern
- `FractalLevel` → Level classification patterns

### Category C: Function Composition (SC-FSH-010/011)
- Validation pipelines → Kleisli composition
- Result handling → tapOk/tapError
- Conditional operations → applyIf
- Builder patterns → compose with tap

---

# LEVEL 3: FILE-BY-FILE ENHANCEMENT PLAN

## 3.1 Podman Domain (Priority: HIGH)

### 3.1.1 Domain/Types.fs
**Current State**: Well-structured types, but uses raw TimeSpan
**Enhancements**:
```fsharp
// ADD: Import Core capabilities
open Cepaf.Core.Units
open Cepaf.Core.ActivePatterns
open Cepaf.Core.Composition

// ADD: Active Pattern for ContainerStatus classification
let (|Running|Stopped|Failed|Transitional|) = function
    | ContainerStatus.Running -> Running
    | ContainerStatus.Exited _ | ContainerStatus.Dead _ -> Stopped
    | ContainerStatus.Paused | ContainerStatus.Restarting -> Transitional
    | _ -> Failed

// ADD: Type-safe client config
type TypeSafeClientConfig = {
    Socket: PodmanSocket
    ApiVersion: string
    Timeout: float<sec>
    RetryCount: int
    RetryDelay: float<sec>
}
```

### 3.1.2 Domain/Errors.fs
**Current State**: Good error types, needs Active Patterns
**Enhancements**:
```fsharp
// ADD: Active Patterns for error classification
let (|Recoverable|NonRecoverable|) error =
    if isRetryable error then Recoverable else NonRecoverable

let (|ConnectionError|ResourceError|SafetyError|ValidationError|) = function
    | SocketNotFound _ | ConnectionRefused _ | ConnectionTimeout _ -> ConnectionError
    | ContainerNotFound _ | ImageNotFound _ | VolumeNotFound _ -> ResourceError
    | SafetyConstraintViolation _ -> SafetyError
    | ValidationFailed _ | InvalidParameter _ -> ValidationError
    | _ -> ConnectionError
```

### 3.1.3 Health/Probes.fs
**Current State**: Uses TimeSpan directly
**Enhancements**:
```fsharp
// ADD: Type-safe probe configuration
type TypeSafeProbeConfig = {
    Interval: float<sec>
    Timeout: float<sec>
    Retries: int
    StartPeriod: float<sec>
}

module TypeSafeProbeConfig =
    let defaults = {
        Interval = 30.0<sec>
        Timeout = 30.0<sec>
        Retries = 3
        StartPeriod = 0.0<sec>
    }
```

### 3.1.4 Safety/Constraints.fs
**Current State**: Uses raw int64 for thresholds
**Enhancements**:
```fsharp
// ADD: Type-safe safety thresholds
let maxBlockingThreshold = Timeout.fromMs 50.0<ms>
let emergencyStopTimeout = Timeout.fromSec 5.0<sec>

// ADD: Active Pattern for violation severity
let (|CriticalViolation|WarningViolation|InfoViolation|) = function
    | { Severity = Critical } -> CriticalViolation
    | { Severity = Warning } -> WarningViolation
    | { Severity = Info } -> InfoViolation
```

## 3.2 Observability Domain (Priority: HIGH)

### 3.2.1 Fractal/Types.fs
**Enhancements**:
```fsharp
// ADD: Type-safe TTL
type TypeSafeLens = {
    Target: string
    Depth: FractalLevel
    Filter: Map<string, string>
    Ttl: float<sec>  // Instead of TtlMs: int64
}

// ADD: Active Pattern for fractal level classification
let (|DebugLevel|TraceLevel|ProductionLevel|) = function
    | FractalLevel.L1 | FractalLevel.L2 -> DebugLevel
    | FractalLevel.L3 -> TraceLevel
    | FractalLevel.L4 | FractalLevel.L5 -> ProductionLevel
```

### 3.2.2 Fractal/HLC.fs
**Enhancements**:
```fsharp
// ADD: Type-safe drift checking
let maxAcceptableDrift = Duration.ms 100.0

// ADD: Active Pattern for timestamp comparison
let (|Before|After|Concurrent|) (a, b) =
    match compare a b with
    | -1 -> Before
    | 1 -> After
    | _ when areConcurrent a b -> Concurrent
    | _ -> Concurrent
```

### 3.2.3 MetricsCollector.fs
**Enhancements**:
```fsharp
// ADD: Type-safe metric values
[<Measure>] type cpu_percent
[<Measure>] type memory_mb
[<Measure>] type latency_ms

type TypeSafeMetrics = {
    CpuUsage: float<cpu_percent>
    MemoryUsed: float<memory_mb>
    RequestLatency: float<latency_ms>
}
```

## 3.3 Modules Domain (Priority: HIGH)

### 3.3.1 CyberneticAgents.fs
**Enhancements**:
```fsharp
// ADD: Type-safe efficiency threshold
[<Measure>] type percent
let efficiencyThreshold = 90.0<percent>

// ADD: Active Pattern for agent classification
let (|ActiveAgent|IdleAgent|BlockedAgent|FailedAgent|) agent =
    match agent.Status with
    | Active _ -> ActiveAgent
    | Idle -> IdleAgent
    | Blocked _ -> BlockedAgent
    | Failed _ | Terminated -> FailedAgent
```

### 3.3.2 ServiceDAG.fs
**Enhancements**:
```fsharp
// ADD: Composition for DAG traversal
let traverseDAG =
    getNodes
    >=> filterReady
    >=> sortTopologically
    >=> executeInOrder

// ADD: Tap for side effects
let executeWithLogging =
    executeNode
    |> tap (fun node -> log $"Executing {node.Name}")
```

## 3.4 Cockpit Domain (Priority: MEDIUM)

### 3.4.1 ThemeSystem.fs
**Enhancements**:
```fsharp
// ADD: Type-safe color temperature
[<Measure>] type kelvin
let dayTemperature = 6500.0<kelvin>
let nightTemperature = 3500.0<kelvin>

// ADD: Active Pattern for breakpoint
let (|MobileLayout|TabletLayout|DesktopLayout|UltraWideLayout|) ctx =
    match detectBreakpoint ctx with
    | Compact -> MobileLayout
    | Standard -> TabletLayout
    | Wide -> DesktopLayout
    | UltraWide -> UltraWideLayout
```

### 3.4.2 Prajna.fs
**Already enhanced** - verify integration complete

## 3.5 Phases Domain (Priority: MEDIUM)

### 3.5.1 Builder.fs, Tester.fs, VTO.fs
**Enhancements**:
```fsharp
// ADD: Composition for build pipeline
let buildPipeline =
    loadSpec
    >=> validateSpec
    >=> compileCode
    >=> runTests
    >=> package

// ADD: Type-safe build timeouts
let compileTimeout = Timeout.fromMin 10.0
let testTimeout = Timeout.fromMin 30.0
```

## 3.6 ServiceChains Domain (Priority: MEDIUM)

### 3.6.1 DevChain.fs, ObsChain.fs
**Enhancements**:
```fsharp
// ADD: Chain composition
let devChain =
    startDb
    >=> waitForReady
    >=> startApp
    >=> verifyHealth
    >=> runTests
```

---

# LEVEL 4: NEW CAPABILITY MODULES

## 4.1 Core/DomainPatterns.fs (NEW)
Comprehensive Active Patterns for all domain types:

```fsharp
namespace Cepaf.Core

/// Domain-wide Active Patterns for semantic classification
/// STAMP: SC-FSH-003
module DomainPatterns =

    open Cepaf.Podman.Domain
    open Cepaf.Observability.Fractal
    open Cepaf.Modules.CyberneticAgents

    // Container Lifecycle Patterns
    let (|ContainerHealthy|ContainerDegraded|ContainerFailed|ContainerUnknown|) container =
        match container.State.Status with
        | ContainerStatus.Running ->
            match container.State.Health with
            | Some { Status = HealthStatus.Healthy } -> ContainerHealthy
            | Some { Status = HealthStatus.Unhealthy _ } -> ContainerDegraded
            | Some { Status = HealthStatus.Starting } -> ContainerDegraded
            | _ -> ContainerUnknown
        | ContainerStatus.Exited code when code = 0 -> ContainerFailed
        | ContainerStatus.Dead _ -> ContainerFailed
        | _ -> ContainerUnknown

    // Error Severity Patterns
    let (|CriticalError|HighError|MediumError|LowError|) error =
        match PodmanError.getSeverity error with
        | "CRITICAL" -> CriticalError
        | "HIGH" -> HighError
        | "MEDIUM" -> MediumError
        | _ -> LowError

    // Fractal Log Routing Patterns
    let (|NeverDrop|Sample10|Sample1|DebugOnly|) level =
        match Priority.fromLevel level with
        | Priority.P0 -> NeverDrop
        | Priority.P1 -> Sample10
        | Priority.P2 -> Sample1
        | Priority.P3 -> DebugOnly

    // Agent Hierarchy Patterns
    let (|Leadership|Supervision|Execution|) agent =
        match agent.Level with
        | Executive -> Leadership
        | DomainSupervisor | FunctionalSupervisor -> Supervision
        | Worker -> Execution
```

## 4.2 Core/DomainUnits.fs (NEW)
Domain-specific Units of Measure:

```fsharp
namespace Cepaf.Core

/// Domain-specific Units of Measure
/// STAMP: SC-FSH-004
module DomainUnits =

    // Efficiency and Performance
    [<Measure>] type percent
    [<Measure>] type cpu_percent
    [<Measure>] type memory_percent

    // Sampling and Rates
    [<Measure>] type sample_rate
    [<Measure>] type events_per_sec

    // Container Resources
    [<Measure>] type container_cpu  // millicores
    [<Measure>] type container_mem  // MiB

    // Network
    [<Measure>] type bandwidth_mbps
    [<Measure>] type latency_us  // microseconds

    // Fractal Logging
    [<Measure>] type log_level  // 1-5
    [<Measure>] type priority_level  // 0-3

    // Type-safe efficiency
    type Efficiency = float<percent>

    module Efficiency =
        let threshold = 90.0<percent>
        let fromFloat (f: float) : Efficiency = f * 1.0<percent>
        let isCompliant (e: Efficiency) = e >= threshold

    // Type-safe sampling
    type SamplingRate = float<sample_rate>

    module SamplingRate =
        let full = 1.0<sample_rate>
        let tenPercent = 0.1<sample_rate>
        let onePercent = 0.01<sample_rate>
        let disabled = 0.0<sample_rate>
```

## 4.3 Core/Pipelines.fs (NEW)
Reusable composition pipelines:

```fsharp
namespace Cepaf.Core

/// Reusable composition pipelines for common operations
/// STAMP: SC-FSH-010, SC-FSH-011
module Pipelines =

    open Cepaf.Core.Composition

    // Result pipeline operators
    let (>=>) = Kleisli.compose
    let (>>=) result f = Result.bind f result
    let (>>|) result f = Result.map f result

    // Async Result pipeline
    module AsyncResult =
        let map f ar = async {
            let! r = ar
            return Result.map f r
        }

        let bind f ar = async {
            let! r = ar
            match r with
            | Ok v -> return! f v
            | Error e -> return Error e
        }

        let (>>=) ar f = bind f ar
        let (>>|) ar f = map f ar

        /// Kleisli for async results
        let composeAsync f g x = async {
            let! r = f x
            match r with
            | Ok v -> return! g v
            | Error e -> return Error e
        }

        let (>=>) f g = composeAsync f g

    // Validation pipeline
    module Validation =
        type ValidationResult<'T> = Result<'T, string list>

        let combine (r1: ValidationResult<'T>) (r2: ValidationResult<'T>) =
            match r1, r2 with
            | Ok v, Ok _ -> Ok v
            | Error e1, Error e2 -> Error (e1 @ e2)
            | Error e, Ok _ | Ok _, Error e -> Error e

        let validate predicate error value =
            if predicate value then Ok value
            else Error [error]

        let chain validators value =
            validators
            |> List.map (fun v -> v value)
            |> List.fold combine (Ok value)

    // Retry pipeline
    module Retry =
        open System.Threading.Tasks

        let withRetry maxAttempts delay operation = async {
            let rec loop attempt = async {
                try
                    return! operation
                with ex ->
                    if attempt < maxAttempts then
                        do! Async.Sleep(delay)
                        return! loop (attempt + 1)
                    else
                        return raise ex
            }
            loop 1
        }

        let withExponentialBackoff maxAttempts baseDelay operation =
            let rec loop attempt = async {
                try
                    return! operation
                with ex ->
                    if attempt < maxAttempts then
                        let delay = baseDelay * (pown 2 attempt)
                        do! Async.Sleep(delay)
                        return! loop (attempt + 1)
                    else
                        return raise ex
            }
            loop 0
```

---

# LEVEL 5: EXECUTION PLAN

## 5.1 Phase 1: Core Infrastructure (Est. Changes: ~10 files)
- [x] Core/Units.fs - COMPLETED
- [x] Core/ActivePatterns.fs - COMPLETED
- [x] Core/Composition.fs - COMPLETED
- [ ] Core/DomainPatterns.fs - NEW
- [ ] Core/DomainUnits.fs - NEW
- [ ] Core/Pipelines.fs - NEW

## 5.2 Phase 2: Podman Domain (Est. Changes: ~8 files)
- [ ] Domain/Types.fs - Add Active Patterns, TypeSafe config
- [ ] Domain/Errors.fs - Add Error classification patterns
- [ ] Health/Probes.fs - Type-safe timeouts
- [ ] Safety/Constraints.fs - Type-safe thresholds
- [ ] Events/Stream.fs - Composition pipelines
- [ ] Api/Containers.fs - Async result composition
- [ ] Client/HttpClient.fs - Type-safe timeouts

## 5.3 Phase 3: Observability (Est. Changes: ~8 files)
- [ ] Fractal/Types.fs - Type-safe TTL, Active Patterns
- [ ] Fractal/HLC.fs - Type-safe drift, comparison patterns
- [ ] Fractal/ContentRouter.fs - Composition pipelines
- [ ] Fractal/BatchEncoder.fs - Type-safe batch sizes
- [ ] MetricsCollector.fs - Domain-specific units
- [ ] QuadplexLogger.fs - Already enhanced, verify
- [ ] Dashboard.fs - Composition for rendering

## 5.4 Phase 4: Modules & Cockpit (Est. Changes: ~10 files)
- [ ] CyberneticAgents.fs - Type-safe efficiency, patterns
- [ ] AOREngine.fs - Already enhanced, verify
- [ ] HealthPropagation.fs - Already enhanced, verify
- [ ] ServiceDAG.fs - Composition pipelines
- [ ] ThemeSystem.fs - Type-safe colors
- [ ] Prajna.fs - Already enhanced, verify
- [ ] AiCopilot.fs - Composition for AI flows

## 5.5 Phase 5: Phases & ServiceChains (Est. Changes: ~6 files)
- [ ] Builder.fs - Build pipeline composition
- [ ] Tester.fs - Test pipeline composition
- [ ] VTO.fs - Verification patterns
- [ ] DevChain.fs - Chain composition
- [ ] ObsChain.fs - Chain composition
- [ ] StandaloneChain.fs - Chain composition

## 5.6 Phase 6: Testing & Verification
- [ ] Update FSharpCapabilityTests.fs with new patterns
- [ ] Add DomainPatternsTests.fs
- [ ] Add PipelinesTests.fs
- [ ] Build verification
- [ ] Full test run

---

# SUMMARY

| Phase | Files | Priority | Status |
|-------|-------|----------|--------|
| 1. Core Infrastructure | 6 | P0 | 50% Complete |
| 2. Podman Domain | 8 | P0 | Pending |
| 3. Observability | 8 | P0 | Pending |
| 4. Modules & Cockpit | 10 | P1 | Partial |
| 5. Phases & Chains | 6 | P1 | Pending |
| 6. Testing | 4 | P0 | Pending |

**Total Estimated Files**: ~42 files
**New Files**: 3
**Existing Modified**: ~39

---

*STAMP Compliance: SC-FSH-003, SC-FSH-004, SC-FSH-010, SC-FSH-011*
*Framework: SOPv5.11 + TDG*
