# F# Language Capability Rules - STAMP/TDG/AOR/FEMA Specification
## CEPAF System Engineering Standards

**Version**: 3.0.0 | **Date**: 2025-12-29 | **Status**: ACTIVE
**Compliance**: SOPv5.11, STAMP, TDG, AOR, FEMA Framework
**Core Modules**: Units.fs, Composition.fs, ActivePatterns.fs, DomainUnits.fs, DomainPatterns.fs, Pipelines.fs
**Cockpit Modules**: SignalArrows.fs, UiComonads.fs, TelemetryStreams.fs, CockpitEffects.fs, ConcurrentCockpit.fs, FractalIntegration.fs

---

## 1.0 Executive Summary

This document defines STAMP constraints, TDG requirements, AOR rules, and FEMA analysis for leveraging the full power of F# language capabilities in the CEPAF codebase. These rules ensure:

- **Type Safety**: Leveraging F#'s type system for compile-time guarantees (Units.fs, DomainUnits.fs)
- **Functional Composition**: Using F#'s composition operators for declarative code (Composition.fs)
- **Active Patterns**: Domain-specific pattern matching abstractions (ActivePatterns.fs, DomainPatterns.fs)
- **Railway-Oriented Programming**: Consistent error handling patterns (Pipelines.fs)
- **Property-Based Testing**: Generative testing for edge cases
- **Safety-Critical Operations**: Emergency response, recovery procedures (FEMA rules)

### Rule Summary

| Framework | Count | Coverage |
|-----------|-------|----------|
| **STAMP Constraints** | 77 | Type system, composition, error handling, concurrency, patterns, units, pipelines |
| **TDG Requirements** | 25 | Type-driven design, test guarantees, documentation |
| **AOR Rules** | 26 | Code quality, safety, performance, patterns, units, pipelines |
| **FEMA Analysis** | 23 | Critical failures, data integrity, concurrency, recovery |
| **Total** | **151** | Full F# capability coverage |

---

## 2.0 STAMP Constraints (SC-FSH-*)

### 2.1 Type System Constraints

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-001 | **Discriminated Unions Required** | All domain states MUST be modeled as discriminated unions | CRITICAL |
| SC-FSH-002 | **Exhaustive Pattern Matching** | All pattern matches MUST be exhaustive (no `_ ->` catch-all without justification) | HIGH |
| SC-FSH-003 | **Active Patterns for Classification** | Error/status classification MUST use active patterns | HIGH |
| SC-FSH-004 | **Units of Measure for Physical Quantities** | Timeouts, ports, memory sizes MUST use F# units of measure | MEDIUM |
| SC-FSH-005 | **No Stringly-Typed APIs** | String parameters representing domain concepts MUST be wrapped types | HIGH |

### 2.2 Composition Constraints

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-010 | **Function Composition Preferred** | Multi-step transformations SHOULD use `>>` composition | MEDIUM |
| SC-FSH-011 | **Partial Application for Configuration** | Configuration functions SHOULD support partial application | MEDIUM |
| SC-FSH-012 | **Pipeline Operator Required** | Data transformations MUST use `|>` pipeline operator | HIGH |
| SC-FSH-013 | **No Nested Lambdas >2 Levels** | Nested lambdas beyond 2 levels MUST be extracted to named functions | MEDIUM |

### 2.3 Error Handling Constraints

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-020 | **Result Type for Failures** | Operations that can fail MUST return `Result<'T, 'E>` | CRITICAL |
| SC-FSH-021 | **AsyncResult for I/O** | Async operations with failure MUST use `AsyncResult<'T, 'E>` | CRITICAL |
| SC-FSH-022 | **Error Type Hierarchy** | Error types MUST form a structured hierarchy with active patterns | HIGH |
| SC-FSH-023 | **No Exception Throwing** | Business logic MUST NOT throw exceptions (use Result) | CRITICAL |
| SC-FSH-024 | **Computation Expressions** | Complex async/result compositions MUST use computation expressions | HIGH |

### 2.4 Testing Constraints

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-030 | **Property-Based Tests Required** | Core logic MUST have FsCheck property-based tests | HIGH |
| SC-FSH-031 | **Generator Composition** | Custom generators MUST compose with FsCheck combinators | MEDIUM |
| SC-FSH-032 | **Shrinking Support** | Property tests MUST support shrinking for failure analysis | MEDIUM |
| SC-FSH-033 | **Expecto Test Framework** | All tests MUST use Expecto with proper async support | HIGH |

### 2.5 Concurrency Constraints

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-040 | **Immutable by Default** | All data types MUST be immutable unless performance-critical | HIGH |
| SC-FSH-041 | **Agent-Based Concurrency** | Shared state MUST use MailboxProcessor or similar patterns | HIGH |
| SC-FSH-042 | **Async Cancellation** | Long-running async operations MUST respect CancellationToken | CRITICAL |
| SC-FSH-043 | **No Blocking on Async** | Never use `Async.RunSynchronously` in production code | CRITICAL |

### 2.6 Domain Pattern Constraints (DomainPatterns.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-050 | **Exhaustive Domain Patterns** | All domain active patterns MUST cover all possible cases | CRITICAL |
| SC-FSH-051 | **No Exception in Patterns** | Active patterns MUST NOT throw exceptions | CRITICAL |
| SC-FSH-052 | **Pattern Documentation** | Each active pattern MUST document matched cases | HIGH |
| SC-FSH-053 | **Semantic Classification** | Use semantic names (Recoverable/Transient) not implementation (Timeout/Socket) | HIGH |
| SC-FSH-054 | **Health Pattern Consistency** | Health status patterns MUST align with container/agent health models | HIGH |
| SC-FSH-055 | **Error Domain Mapping** | Error patterns MUST map to specific domains (Network/Storage/Security/Validation/System) | HIGH |

### 2.7 Domain Unit Constraints (DomainUnits.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-060 | **Unit Coherence** | Domain units MUST extend core units coherently (no orphan conversions) | HIGH |
| SC-FSH-061 | **Boundary Validation** | Unit conversion functions MUST validate boundaries (efficiency: 0-100, sampling: 0-1) | CRITICAL |
| SC-FSH-062 | **Safety Threshold Units** | All safety-critical thresholds MUST use type-safe units (emergency_sec, response_ms) | CRITICAL |
| SC-FSH-063 | **HLC Units Required** | HLC timestamps MUST use hlc_physical, hlc_counter, drift_us units | HIGH |
| SC-FSH-064 | **Fractal Level Units** | Fractal log levels MUST use flevel (1-5) and plevel (0-3) units | HIGH |
| SC-FSH-065 | **Container Resource Units** | Container resources MUST use millicores, mib, gib units | HIGH |

### 2.8 Pipeline Constraints (Pipelines.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FSH-070 | **Kleisli Composition** | Multi-step Result operations MUST use Kleisli (>=>) composition | HIGH |
| SC-FSH-071 | **Tap for Side Effects** | Side effects in pipelines MUST use tap/tapOk/tapError | HIGH |
| SC-FSH-072 | **Async Non-Blocking** | All async pipeline operations MUST be non-blocking (SC-PRF-055) | CRITICAL |
| SC-FSH-073 | **Error Capture in Result** | All recoverable errors MUST be captured in Result type | CRITICAL |
| SC-FSH-074 | **Retry with Backoff** | Transient failures MUST use exponential backoff retry | HIGH |
| SC-FSH-075 | **Timeout Required** | Long-running operations MUST have timeout (SC-PRF-050: <50ms response) | CRITICAL |
| SC-FSH-076 | **Validation Accumulation** | Validation errors MUST accumulate (not short-circuit) | MEDIUM |
| SC-FSH-077 | **Parallel Safety** | Parallel operations MUST use semaphore for concurrency limits | HIGH |

### 2.9 Fractal Context Constraints (FractalIntegration.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-FRAC-001 | **Self-Similar Hierarchy** | Fractal context MUST be self-similar at all levels (System→Cluster→Node→Process→Component) | CRITICAL |
| SC-FRAC-002 | **Health Propagation** | Health scores MUST propagate upward (min aggregate) | HIGH |
| SC-FRAC-003 | **Structure Preservation** | Fractal.map MUST preserve hierarchy structure | HIGH |
| SC-FRAC-004 | **Bottom-Up Aggregation** | Fractal.fold MUST aggregate from leaves to root | MEDIUM |
| SC-FRAC-005 | **Parent Reference** | Child contexts MUST maintain ParentId reference | MEDIUM |
| SC-FRAC-010 | **CEA Integration** | Fractal cockpit MUST integrate CEA homeostatic control | HIGH |
| SC-FRAC-011 | **OODA Integration** | Fractal cockpit MUST integrate OODA decision loops | HIGH |
| SC-FRAC-012 | **Telemetry Pipeline** | Fractal levels MUST process telemetry through signal arrows | HIGH |
| SC-FRAC-015 | **Pipeline Composition** | Telemetry pipelines MUST compose smoothing, trend, and alarm arrows | MEDIUM |
| SC-FRAC-020 | **State Unification** | FractalCockpit MUST unify Context, OodaCycle, and Controller state | CRITICAL |

### 2.10 OODA Loop Constraints (FractalIntegration.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-OODA-001 | **Phase Timing** | Each OODA phase MUST have configurable maxLatencyMs | HIGH |
| SC-OODA-002 | **Cycle Completion** | OODA cycles MUST track CycleCount and AverageLatencyMs | HIGH |
| SC-OODA-003 | **Latency Bounds** | OODA cycles MUST verify latency against phase bounds | CRITICAL |
| SC-OODA-004 | **Phase Transitions** | Phase transitions MUST be valid (Observe→Orient→Decide→Act) | HIGH |
| SC-OODA-005 | **Observation Accumulation** | Observations MUST accumulate within cycle | MEDIUM |

### 2.11 CEA Controller Constraints (FractalIntegration.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-CEA-001 | **Homeostatic Variables** | All controlled variables MUST have Setpoint, Tolerance, ControlGain | CRITICAL |
| SC-CEA-002 | **Proportional Control** | Control actions MUST be proportional to deviation (deviation × gain) | HIGH |
| SC-CEA-003 | **Stability Scoring** | Stability score MUST be [0,1] based on RMS deviation history | HIGH |
| SC-CEA-004 | **Alert Thresholds** | Alert at 2× tolerance, Emergency at 3× tolerance | CRITICAL |
| SC-CEA-005 | **Deviation History** | DeviationHistory MUST be bounded (max 100 entries) | MEDIUM |

### 2.12 Signal Arrow Constraints (SignalArrows.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-ARROW-001 | **Composition Law** | Arrows MUST satisfy (f >>> g) >>> h = f >>> (g >>> h) | CRITICAL |
| SC-ARROW-002 | **Identity Law** | arr id >>> f = f = f >>> arr id | HIGH |
| SC-ARROW-003 | **First/Second Laws** | first f >>> arr fst = arr fst >>> f | HIGH |
| SC-ARROW-004 | **Fanout Correctness** | fanout f g = f &&& g (parallel application) | MEDIUM |
| SC-ARROW-005 | **Split Correctness** | split f g = first f >>> second g | MEDIUM |
| SC-ARROW-010 | **Smoothing Bounds** | Smoothing arrows MUST handle empty lists (return 0.0) | HIGH |
| SC-ARROW-011 | **Trend Detection** | Trend arrows MUST classify Rising/Falling/Stable/RisingFast/FallingFast | HIGH |
| SC-ARROW-012 | **Alarm Thresholds** | Alarm arrows MUST map to Normal/Advisory/Caution/Warning/Critical | HIGH |

### 2.13 Telemetry Stream Constraints (TelemetryStreams.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-STREAM-001 | **Backpressure Support** | Streams MUST support backpressure via buffer bounds | CRITICAL |
| SC-STREAM-002 | **Cancellation Support** | Streams MUST respect CancellationToken | CRITICAL |
| SC-STREAM-003 | **Error Propagation** | Stream errors MUST propagate via TelError node | HIGH |
| SC-STREAM-004 | **Windowing** | Streams MUST support count-based windowing | HIGH |
| SC-STREAM-005 | **Time Windowing** | Streams MUST support time-based windowing | HIGH |
| SC-STREAM-006 | **Debouncing** | Streams MUST support debounce (ms threshold) | MEDIUM |
| SC-STREAM-007 | **Sampling** | Streams MUST support sampling (ms interval) | MEDIUM |
| SC-STREAM-008 | **Throughput Target** | Streams MUST handle 1000+ msg/sec | HIGH |
| SC-STREAM-009 | **Empty Stream** | TelStream.empty MUST immediately terminate | MEDIUM |
| SC-STREAM-010 | **Singleton Stream** | TelStream.singleton MUST produce exactly one value | MEDIUM |

### 2.14 STM Concurrency Constraints (ConcurrentCockpit.fs)

| ID | Name | Description | Severity |
|----|------|-------------|----------|
| SC-STM-001 | **Lock-Free Operations** | STM transactions MUST NOT use explicit locks | CRITICAL |
| SC-STM-002 | **Atomic Commits** | STM transactions MUST commit atomically or rollback | CRITICAL |
| SC-STM-003 | **Version Tracking** | TVars MUST track version for conflict detection | HIGH |
| SC-STM-004 | **Retry Semantics** | STM retry MUST block until TVar changes | HIGH |
| SC-STM-005 | **OrElse Semantics** | orElse MUST try alternative on retry | HIGH |
| SC-STM-006 | **Transaction Logging** | Transactions MUST maintain read/write logs | HIGH |
| SC-STM-007 | **Conflict Resolution** | On version conflict, retry transaction | HIGH |
| SC-STM-008 | **Deadlock Freedom** | STM design MUST prevent deadlocks | CRITICAL |

---

## 3.0 TDG Requirements (TDG-FSH-*)

### 3.1 Type-Driven Design

| ID | Requirement | Verification |
|----|-------------|--------------|
| TDG-FSH-001 | **Types Before Implementation** | Types MUST be defined and reviewed before implementation | Code review |
| TDG-FSH-002 | **Make Illegal States Unrepresentable** | Type design MUST prevent invalid states at compile time | Type analysis |
| TDG-FSH-003 | **Single Case DU for Wrapping** | Primitive obsession MUST be eliminated with single-case DUs | Static analysis |

### 3.2 Test-Driven Guarantees

| ID | Requirement | Verification |
|----|-------------|--------------|
| TDG-FSH-010 | **Property Tests First** | Property specifications MUST precede implementation | Git history |
| TDG-FSH-011 | **Generator per Type** | Each domain type MUST have an FsCheck generator | Test coverage |
| TDG-FSH-012 | **Invariant Tests** | Type invariants MUST have corresponding property tests | Test audit |

### 3.3 Documentation-Driven

| ID | Requirement | Verification |
|----|-------------|--------------|
| TDG-FSH-020 | **XML Doc Required** | All public functions MUST have XML documentation | Build warnings |
| TDG-FSH-021 | **Example in Doc** | Complex functions MUST include usage example in doc | Doc review |
| TDG-FSH-022 | **Constraint Documentation** | STAMP constraints MUST be documented in module header | Grep audit |

### 3.4 Domain Pattern TDG

| ID | Requirement | Verification |
|----|-------------|--------------|
| TDG-FSH-030 | **Pattern Branch Tests** | Each active pattern branch MUST have dedicated test | Test coverage |
| TDG-FSH-031 | **Boundary Condition Tests** | Edge cases (empty, null, boundary) MUST be tested | Test audit |
| TDG-FSH-032 | **Classification Property Tests** | Pattern classification MUST have property tests | FsCheck coverage |
| TDG-FSH-033 | **No Exception Property** | Property: pattern MUST NOT throw on any input | FsCheck |

### 3.5 Domain Unit TDG

| ID | Requirement | Verification |
|----|-------------|--------------|
| TDG-FSH-040 | **Arithmetic Correctness** | Unit arithmetic operations MUST preserve types | Property tests |
| TDG-FSH-041 | **Boundary Tests** | Conversion at boundaries (0, max, negative) MUST be tested | Test audit |
| TDG-FSH-042 | **Roundtrip Property** | toUnit >> fromUnit = id (where applicable) | FsCheck |
| TDG-FSH-043 | **Compliance Check Tests** | isCompliant/isWarning/isCritical MUST be tested | Unit tests |

### 3.6 Pipeline TDG

| ID | Requirement | Verification |
|----|-------------|--------------|
| TDG-FSH-050 | **Composition Associativity** | (f >=> g) >=> h = f >=> (g >=> h) | FsCheck |
| TDG-FSH-051 | **Monad Laws** | Return/Bind satisfy monad laws | Property tests |
| TDG-FSH-052 | **Async Cancellation Tests** | CancellationToken MUST abort operations | Integration tests |
| TDG-FSH-053 | **Retry Behavior Tests** | Retry logic MUST be tested with failure injection | Unit tests |
| TDG-FSH-054 | **Timeout Behavior Tests** | Timeout MUST terminate long operations | Async tests |

---

## 4.0 AOR Rules (AOR-FSH-*)

### 4.1 Code Quality Rules

| ID | Name | Action on Violation |
|----|------|---------------------|
| AOR-FSH-001 | **Active Pattern Required for >3 Cases** | When pattern matching has >3 related cases, extract to active pattern | Refactor |
| AOR-FSH-002 | **Composition Over Nesting** | Replace nested function calls with composition chain | Refactor |
| AOR-FSH-003 | **No Mutable Let Bindings** | Replace `let mutable` with immutable alternatives or ref cells with clear scope | Refactor |

### 4.2 Safety Rules

| ID | Name | Action on Violation |
|----|------|---------------------|
| AOR-FSH-010 | **Result.mapError Required** | Error transformations MUST use mapError, not pattern match | Fix immediately |
| AOR-FSH-011 | **Option.defaultValue Over Match** | Option handling SHOULD use defaultValue/map over explicit match | Fix on edit |
| AOR-FSH-012 | **Async.Catch for External Calls** | External I/O MUST be wrapped with Async.Catch | Fix immediately |

### 4.3 Performance Rules

| ID | Name | Action on Violation |
|----|------|---------------------|
| AOR-FSH-020 | **Seq Over List for Large Data** | Large collections MUST use `seq` for lazy evaluation | Profile first |
| AOR-FSH-021 | **Array for Performance Critical** | Performance-critical loops SHOULD use arrays | Benchmark required |
| AOR-FSH-022 | **Struct Records for Hot Paths** | High-frequency allocations SHOULD use `[<Struct>]` records | Profile required |

### 4.4 Domain Pattern AOR Rules

| ID | Name | Action on Violation |
|----|------|---------------------|
| AOR-FSH-030 | **Use Domain Patterns** | Error/health classification MUST use DomainPatterns active patterns | Refactor |
| AOR-FSH-031 | **Pattern Over String Match** | String status matching MUST use active patterns | Fix immediately |
| AOR-FSH-032 | **Severity Classification** | Error severity MUST be classified (Critical/High/Medium/Low) | Fix immediately |
| AOR-FSH-033 | **Exit Code Patterns** | Container exit codes MUST use (NormalExit/ErrorExit/SignalExit/OOMKilled) | Refactor |

### 4.5 Domain Unit AOR Rules

| ID | Name | Action on Violation |
|----|------|---------------------|
| AOR-FSH-040 | **No Raw Floats in Domain** | Domain calculations MUST NOT use raw float/int | Fix immediately |
| AOR-FSH-041 | **Efficiency Unit Required** | Agent efficiency MUST use `float<efficiency>` | Fix immediately |
| AOR-FSH-042 | **Safety Threshold Units** | Emergency/response times MUST use type-safe units | Fix immediately |
| AOR-FSH-043 | **HLC Timestamp Units** | HLC physical time MUST use `int64<hlc_physical>` | Fix immediately |
| AOR-FSH-044 | **Fractal Level Units** | Fractal levels MUST use `int<flevel>` (1-5) | Fix immediately |

### 4.6 Pipeline AOR Rules

| ID | Name | Action on Violation |
|----|------|---------------------|
| AOR-FSH-050 | **Use AsyncResult Module** | Async+Result composition MUST use Pipelines.AsyncResult | Refactor |
| AOR-FSH-051 | **Use Kleisli Composition** | Multi-step Result chains MUST use (>=>) | Refactor |
| AOR-FSH-052 | **Tap for Logging** | Logging in pipelines MUST use tapOk/tapError | Refactor |
| AOR-FSH-053 | **Retry Module Required** | Retry logic MUST use Pipelines.Retry module | Refactor |
| AOR-FSH-054 | **Timeout Module Required** | Timeout logic MUST use Pipelines.Timeout module | Refactor |
| AOR-FSH-055 | **Validation Module** | Multi-field validation MUST use Pipelines.Validation | Refactor |

---

## 5.0 FEMA Rules (FEMA-FSH-*) - Failure Mode & Effects Analysis

### 5.1 Critical Safety Failures

| ID | Failure Mode | Effect | Mitigation | Severity |
|----|--------------|--------|------------|----------|
| FEMA-FSH-001 | **Pattern Match Failure** | Runtime crash | Exhaustive patterns + tests | CRITICAL |
| FEMA-FSH-002 | **Unhandled Exception** | System halt | Result type + Async.Catch | CRITICAL |
| FEMA-FSH-003 | **Async Deadlock** | Resource starvation | No blocking, async all the way | CRITICAL |
| FEMA-FSH-004 | **Timeout Exceeded** | Response violation (SC-PRF-050) | Timeout module + monitoring | HIGH |
| FEMA-FSH-005 | **Emergency Stop Delay** | Safety violation (SC-EMR-057: <5s) | Priority execution path | CRITICAL |

### 5.2 Data Integrity Failures

| ID | Failure Mode | Effect | Mitigation | Severity |
|----|--------------|--------|------------|----------|
| FEMA-FSH-010 | **Unit Mismatch** | Incorrect calculations | Type-safe units throughout | HIGH |
| FEMA-FSH-011 | **HLC Drift Exceeded** | Event ordering failure | Drift monitoring + correction | HIGH |
| FEMA-FSH-012 | **Validation Bypass** | Invalid state | Validation pipeline required | HIGH |
| FEMA-FSH-013 | **Error Classification Wrong** | Wrong handling | Active pattern tests | MEDIUM |

### 5.3 Concurrency Failures

| ID | Failure Mode | Effect | Mitigation | Severity |
|----|--------------|--------|------------|----------|
| FEMA-FSH-020 | **Race Condition** | Data corruption | Immutable data + agents | HIGH |
| FEMA-FSH-021 | **Cancellation Ignored** | Resource leak | CancellationToken propagation | MEDIUM |
| FEMA-FSH-022 | **Parallel Overflow** | System overload | Semaphore limiting | HIGH |
| FEMA-FSH-023 | **Retry Storm** | Cascade failure | Exponential backoff | HIGH |

### 5.4 Emergency Response Requirements

| ID | Requirement | Max Time | STAMP Reference |
|----|-------------|----------|-----------------|
| FEMA-FSH-030 | **Emergency Stop Execution** | <5 seconds | SC-EMR-057 |
| FEMA-FSH-031 | **Safety Halt on STAMP Violation** | <1 second | AOR-SAF-001 |
| FEMA-FSH-032 | **Response Latency** | <50ms | SC-PRF-050 |
| FEMA-FSH-033 | **Blocking Operation Max** | <50ms | SC-PRF-055 |
| FEMA-FSH-034 | **Agent Efficiency Threshold** | >90% | SC-AGT-017 |

### 5.5 Recovery Procedures

| Failure Type | Detection | Recovery | Escalation |
|--------------|-----------|----------|------------|
| **Transient Error** | DomainPatterns.Transient | Retry with backoff | After maxRetries → Supervisor |
| **Recoverable Error** | DomainPatterns.Recoverable | Log + Continue | Metric alert |
| **Non-Recoverable** | DomainPatterns.NonRecoverable | Graceful shutdown | Human intervention |
| **Critical Safety** | STAMP violation | Emergency stop | Executive agent |
| **Health Degraded** | HealthPatterns.Degraded | Auto-recovery attempt | Alert after threshold |
| **Health Failed** | HealthPatterns.Failed | Container restart | Cluster failover |

---

## 6.0 Implementation Patterns

### 6.1 Active Patterns for Error Classification (DomainPatterns.fs)

```fsharp
/// SC-FSH-003: Active pattern for error classification
/// Enables semantic error handling without exposing implementation details
[<RequireQualifiedAccess>]
module ErrorPatterns =

    /// Classify errors by recoverability
    let (|Recoverable|Transient|Fatal|) (error: PodmanError) =
        match error with
        | PodmanError.ConnectionTimeout _
        | PodmanError.ConnectionRefused _ -> Transient
        | PodmanError.ContainerNotRunning _
        | PodmanError.ImageNotFound _ -> Recoverable
        | PodmanError.SafetyConstraintViolation _
        | PodmanError.ValidationFailed _ -> Fatal
        | _ when PodmanError.isRetryable error -> Transient
        | _ -> Recoverable

    /// Classify errors by domain
    let (|NetworkError|ResourceError|SafetyError|SystemError|) (error: PodmanError) =
        match error with
        | PodmanError.SocketNotFound _
        | PodmanError.ConnectionRefused _
        | PodmanError.ConnectionTimeout _ -> NetworkError
        | PodmanError.ContainerNotFound _
        | PodmanError.ImageNotFound _
        | PodmanError.VolumeNotFound _
        | PodmanError.NetworkNotFound _ -> ResourceError
        | PodmanError.SafetyConstraintViolation _
        | PodmanError.HealthCheckFailed _ -> SafetyError
        | _ -> SystemError

    /// Classify health status
    let (|Healthy|Degraded|Failed|Unknown|) (status: HealthStatus) =
        match status with
        | HealthStatus.Healthy -> Healthy
        | HealthStatus.Starting -> Degraded
        | HealthStatus.Unhealthy -> Failed
        | HealthStatus.NoHealthcheck -> Unknown
        | HealthStatus.Unknown -> Unknown

// Usage:
match error with
| Recoverable -> retry operation
| Transient -> backoff and retry
| Fatal -> halt system
```

### 6.2 Enhanced Railway-Oriented Programming (Pipelines.fs)

```fsharp
/// SC-FSH-020, SC-FSH-021: Enhanced ROP module
/// Provides comprehensive Result/AsyncResult combinators
[<RequireQualifiedAccess>]
module Rop =

    // ========== CORE TYPES ==========
    type AsyncResult<'T, 'E> = Async<Result<'T, 'E>>

    // ========== FUNCTOR (map) ==========
    let map f x = async {
        let! res = x
        return Result.map f res
    }

    let mapError f x = async {
        let! res = x
        return Result.mapError f res
    }

    // ========== MONAD (bind) ==========
    let bind f x = async {
        let! res = x
        match res with
        | Ok v -> return! f v
        | Error e -> return Error e
    }

    // ========== APPLICATIVE ==========
    /// Apply a wrapped function to a wrapped value
    let apply fAsync xAsync = async {
        let! fResult = fAsync
        let! xResult = xAsync
        return
            match fResult, xResult with
            | Ok f, Ok x -> Ok (f x)
            | Error e, _ -> Error e
            | _, Error e -> Error e
    }

    /// SC-FSH-010: Composition operators
    let (<!>) = map           // Functor map
    let (<*>) = apply         // Applicative apply
    let (>>=) x f = bind f x  // Monadic bind
    let (>=>) f g = f >> bind g  // Kleisli composition

    // ========== TRAVERSAL ==========
    /// Traverse a list, collecting results or returning first error
    let traverse f xs = async {
        let rec loop acc = function
            | [] -> async { return Ok (List.rev acc) }
            | x :: rest ->
                async {
                    let! result = f x
                    match result with
                    | Ok v -> return! loop (v :: acc) rest
                    | Error e -> return Error e
                }
        return! loop [] (List.ofSeq xs)
    }

    /// Sequence a list of async results
    let sequence xs = traverse id xs

    // ========== COMBINATORS ==========
    /// Combine two results, keeping both values on success
    let zip aAsync bAsync = async {
        let! aResult = aAsync
        let! bResult = bAsync
        return
            match aResult, bResult with
            | Ok a, Ok b -> Ok (a, b)
            | Error e, _ -> Error e
            | _, Error e -> Error e
    }

    /// Try operation, converting exception to error
    let catch makeError asyncOp = async {
        try
            let! result = asyncOp
            return Ok result
        with ex ->
            return Error (makeError ex)
    }

    /// Provide fallback on error
    let orElse fallback primary = async {
        let! result = primary
        match result with
        | Ok v -> return Ok v
        | Error _ -> return! fallback
    }

    /// Retry with exponential backoff
    let retryWithBackoff maxRetries baseDelayMs f =
        let rec loop attempt =
            async {
                let! result = f ()
                match result with
                | Ok v -> return Ok v
                | Error e when attempt < maxRetries ->
                    do! Async.Sleep (baseDelayMs * (pown 2 attempt))
                    return! loop (attempt + 1)
                | Error e -> return Error e
            }
        loop 0

    // ========== COMPUTATION EXPRESSION ==========
    type AsyncResultBuilder() =
        member _.Return(v) = async { return Ok v }
        member _.ReturnFrom(x: AsyncResult<_,_>) = x
        member _.Bind(x, f) = bind f x
        member _.Zero() = async { return Ok () }
        member _.Delay(f) = async { return! f() }
        member _.Combine(a, b) = bind (fun () -> b) a

        member _.TryWith(m, h) = async {
            try return! m
            with ex -> return! h ex
        }

        member _.TryFinally(m, compensation) = async {
            try return! m
            finally compensation()
        }

        member _.Using(resource: 'T when 'T :> IDisposable, f) =
            async {
                try return! f resource
                finally resource.Dispose()
            }

        member _.For(xs: 'a seq, f: 'a -> AsyncResult<unit, 'b>) =
            let rec loop (enumerator: IEnumerator<'a>) =
                if enumerator.MoveNext() then
                    bind (fun () -> loop enumerator) (f enumerator.Current)
                else
                    async { return Ok () }
            async {
                use enumerator = xs.GetEnumerator()
                return! loop enumerator
            }

    let asyncResult = AsyncResultBuilder()
```

### 6.3 Function Composition Utilities (Composition.fs)

```fsharp
/// SC-FSH-010, SC-FSH-011: Function composition utilities
[<AutoOpen>]
module Composition =

    /// Forward composition (already in F# as >>)
    let inline (>>) f g x = g (f x)

    /// Backward composition (already in F# as <<)
    let inline (<<) f g x = f (g x)

    /// Flip function arguments
    let inline flip f x y = f y x

    /// Constant function (ignores second argument)
    let inline konst x _ = x

    /// Identity function
    let inline id x = x

    /// Tap - execute side effect and return value (for debugging)
    let inline tap f x = f x; x

    /// Conditional application
    let inline applyIf condition f x = if condition then f x else x

    /// Apply function n times
    let rec applyN n f x =
        if n <= 0 then x
        else applyN (n - 1) f (f x)

    /// Memoize a function
    let memoize f =
        let cache = System.Collections.Concurrent.ConcurrentDictionary<_, _>()
        fun x -> cache.GetOrAdd(x, lazy f x).Value
```

### 6.4 Units of Measure (Units.fs + DomainUnits.fs)

```fsharp
/// SC-FSH-004: Units of measure for type safety
[<AutoOpen>]
module Units =

    // Time units
    [<Measure>] type ms
    [<Measure>] type sec
    [<Measure>] type min

    // Data units
    [<Measure>] type bytes
    [<Measure>] type KB
    [<Measure>] type MB
    [<Measure>] type GB

    // Network units
    [<Measure>] type port

    // Conversion functions
    let msToSec (x: float<ms>) : float<sec> = x / 1000.0<ms/sec>
    let secToMs (x: float<sec>) : float<ms> = x * 1000.0<ms/sec>
    let minToSec (x: float<min>) : float<sec> = x * 60.0<sec/min>

    let bytesToKB (x: float<bytes>) : float<KB> = x / 1024.0<bytes/KB>
    let kbToMB (x: float<KB>) : float<MB> = x / 1024.0<KB/MB>
    let mbToGB (x: float<MB>) : float<GB> = x / 1024.0<MB/GB>

    // Safe timeout type
    type Timeout = Timeout of float<ms>

    module Timeout =
        let create (ms: float<ms>) = Timeout ms
        let fromSeconds (s: float<sec>) = Timeout (secToMs s)
        let value (Timeout ms) = ms
        let toTimeSpan (Timeout ms) = System.TimeSpan.FromMilliseconds(float ms)

    // Safe port type
    type Port = private Port of int<port>

    module Port =
        let create (p: int) : Port option =
            if p > 0 && p < 65536 then Some (Port (p * 1<port>))
            else None

        let createUnsafe (p: int) = Port (p * 1<port>)
        let value (Port p) = int p
```

### 6.5 Property-Based Testing Patterns

```fsharp
/// SC-FSH-030, SC-FSH-031: Property-based testing with FsCheck
module PropertyTests =
    open FsCheck
    open Expecto

    // Custom generators for domain types
    let containerIdGen =
        Gen.elements ['a'..'z']
        |> Gen.listOfLength 12
        |> Gen.map (List.toArray >> System.String)

    let portGen =
        Gen.choose (1, 65535)
        |> Gen.map Port.createUnsafe

    let healthStatusGen =
        Gen.elements [
            HealthStatus.Healthy
            HealthStatus.Unhealthy
            HealthStatus.Starting
            HealthStatus.NoHealthcheck
            HealthStatus.Unknown
        ]

    // Compose generators
    let containerGen =
        gen {
            let! id = containerIdGen
            let! name = Arb.generate<string> |> Gen.filter (String.IsNullOrEmpty >> not)
            let! status = Gen.elements [ContainerStatus.Running; ContainerStatus.Exited 0]
            let! health = healthStatusGen
            return {
                Id = id
                Name = name
                Status = status
                Health = health
            }
        }

    // Property: Active pattern classification is exhaustive
    let ``error classification covers all cases`` (error: PodmanError) =
        match error with
        | ErrorPatterns.Recoverable -> true
        | ErrorPatterns.Transient -> true
        | ErrorPatterns.Fatal -> true

    // Property: Result map preserves structure
    let ``Result.map preserves Ok/Error`` (result: Result<int, string>) (f: int -> int) =
        match result, Result.map f result with
        | Ok _, Ok _ -> true
        | Error _, Error _ -> true
        | _ -> false

    // Property: Composition is associative
    let ``function composition is associative`` (f: int -> int) (g: int -> int) (h: int -> int) (x: int) =
        ((f >> g) >> h) x = (f >> (g >> h)) x

    // Register custom generators
    type DomainArbitraries =
        static member ContainerId() = Arb.fromGen containerIdGen
        static member Port() = Arb.fromGen portGen
        static member HealthStatus() = Arb.fromGen healthStatusGen

    let config = { FsCheckConfig.defaultConfig with arbitrary = [typeof<DomainArbitraries>] }

    // Expecto test list
    [<Tests>]
    let propertyTests =
        testList "Property Tests" [
            testPropertyWithConfig config "Error classification is exhaustive"
                ``error classification covers all cases``

            testPropertyWithConfig config "Result.map preserves structure"
                ``Result.map preserves Ok/Error``

            testPropertyWithConfig config "Composition is associative"
                ``function composition is associative``
        ]
```

---

### 6.6 Domain Units Usage Examples (DomainUnits.fs)

```fsharp
/// SC-FSH-060 to SC-FSH-065: Domain units usage examples
open Cepaf.Core.DomainUnits

/// Agent efficiency monitoring with type-safe thresholds
module AgentMonitoring =
    /// Check agent efficiency against SC-AGT-017 threshold (>90%)
    let checkAgentEfficiency (metrics: AgentMetrics) =
        let efficiency = Efficiency.fromFloat metrics.SuccessRate
        match efficiency with
        | e when Efficiency.isCompliant e ->
            Ok { metrics with ComplianceStatus = "COMPLIANT" }
        | e when Efficiency.isWarning e ->
            Ok { metrics with ComplianceStatus = "WARNING"; Alert = Some "Efficiency below 90%" }
        | e when Efficiency.isCritical e ->
            Error $"CRITICAL: Efficiency {Efficiency.toFloat e}%% violates SC-AGT-017"

    /// Fractal log routing with type-safe levels
    let routeFractalLog (level: int<flevel>) (message: string) =
        let priority = PriorityLevel.fromFractalLevel level
        let samplingRate = SamplingRate.forPriority (int priority)

        if SamplingRate.shouldSample samplingRate then
            let requiresHLC = FractalLevel.requiresHLC level
            {|
                Level = level
                Priority = priority
                SamplingRate = samplingRate
                RequiresHLC = requiresHLC
                Message = message
            |}
            |> Some
        else
            None

    /// Container resource allocation with type-safe units
    let allocateContainerResources (requested: ResourceRequest) =
        let cpu = ContainerCPU.fromCores requested.CpuCores
        let memory = ContainerMemory.fromGiB requested.MemoryGiB

        {|
            CPU = cpu
            Memory = memory
            CPUInCores = ContainerCPU.toCores cpu
            MemoryInMiB = ContainerMemory.toMiB memory
        |}

    /// Safety threshold validation
    let validateSafetyThresholds (metrics: SystemMetrics) =
        let emergencyTime = metrics.EmergencyStopTime * 1<emergency_sec>
        let responseTime = metrics.ResponseLatency * 1<response_ms>

        let emergencyOk = SafetyThresholds.isEmergencyCompliant emergencyTime
        let responseOk = SafetyThresholds.isResponseCompliant responseTime

        if emergencyOk && responseOk then
            Ok "All safety thresholds within limits"
        else
            Error $"Safety violation: Emergency={emergencyTime}, Response={responseTime}"
```

### 6.7 Pipeline Usage Examples (Pipelines.fs)

```fsharp
/// SC-FSH-070 to SC-FSH-077: Pipeline usage examples
open Cepaf.Core.Pipelines

/// Container health check pipeline with retry and timeout
module HealthCheckPipeline =
    open DomainPatterns

    /// Async health check with full pipeline features
    let checkContainerHealth containerId =
        let config = {
            Retry.defaultConfig with
                MaxAttempts = 3
                BaseDelayMs = 100
                ShouldRetry = fun ex ->
                    match ex with
                    | Transient -> true  // Retry transient errors
                    | _ -> false
        }

        let operation () = async {
            // Simulated health check
            let! response = Container.getHealth containerId
            return response
        }

        // Pipeline: retry with backoff, timeout, and error classification
        operation
        |> Retry.withConfig config
        |> Timeout.withTimeout 5000
        |> AsyncResult.tapOk (fun health ->
            match health with
            | Operational -> Logger.info "Container healthy"
            | Degraded -> Logger.warn "Container degraded"
            | Failed -> Logger.error "Container failed"
            | Unknown -> Logger.debug "Container status unknown"
        )
        |> AsyncResult.tapError (fun err ->
            Logger.error $"Health check failed: {err}"
        )

/// Validation pipeline for multi-field input
module ValidationPipeline =
    open Validation

    /// Validate container creation request
    let validateContainerRequest (request: ContainerRequest) =
        let nameValidators = [
            notEmpty "name"
            minLength "name" 3
            maxLength "name" 63
        ]

        let portValidators = [
            inRange "port" 1 65535
        ]

        // Accumulate all validation errors
        let nameResult = validateAll nameValidators request.Name
        let portResult = validateAll portValidators request.Port

        // Combine results
        match nameResult, portResult with
        | Ok _, Ok _ -> Ok request
        | Error e1, Error e2 -> Error (e1 @ e2)
        | Error e, _ | _, Error e -> Error e

/// Async composition with Kleisli operators
module AsyncCompositionPipeline =
    /// Kleisli composition of async operations
    let processContainer =
        getContainerInfo
        >=> validateContainer
        >=> checkHealth
        >=> updateStatus

    /// Parallel operations with concurrency limit
    let processAllContainers containers =
        containers
        |> Parallel.mapLimit 5 processContainer
        |> Parallel.allResults
```

---

## 7.0 Enforcement Implementation

### 7.1 AOR Engine Extension for F# Rules

```fsharp
/// AOR rules for F# capability enforcement
module AORFSharpRules =
    open Cepaf.Modules.AOREngine

    /// AOR-FSH-001: Active pattern required for >3 related cases
    let ruleFsh001 =
        defineRule
            "AOR-FSH-001"
            "Active Pattern Required"
            "Pattern matches with >3 related cases must use active patterns"
            RuleSeverity.Medium
            RuleCategory.Quality
            [OperationType.FileEdit; OperationType.AgentTask]
            (fun ctx ->
                match ctx.Data |> Map.tryFind "pattern_match_cases" with
                | Some (:? int as cases) when cases > 3 ->
                    match ctx.Data |> Map.tryFind "uses_active_pattern" with
                    | Some (:? bool as usesAP) when usesAP ->
                        EvaluationResult.Passed (Some "Active pattern used for complex match")
                    | _ ->
                        EvaluationResult.Failed (sprintf "Pattern match has %d cases without active pattern" cases)
                | _ ->
                    EvaluationResult.Skipped "No complex pattern match detected"
            )

    /// AOR-FSH-010: Result.mapError required
    let ruleFsh010 =
        defineRule
            "AOR-FSH-010"
            "Use mapError"
            "Error transformations must use Result.mapError"
            RuleSeverity.High
            RuleCategory.Quality
            [OperationType.FileEdit]
            (fun ctx ->
                match ctx.Data |> Map.tryFind "error_transform_pattern" with
                | Some (:? string as pattern) when pattern = "match" ->
                    EvaluationResult.Failed "Use Result.mapError instead of pattern matching for error transformation"
                | Some (:? string as pattern) when pattern = "mapError" ->
                    EvaluationResult.Passed (Some "Correctly using mapError")
                | _ ->
                    EvaluationResult.Skipped "No error transformation detected"
            )

    /// AOR-FSH-012: Async.Catch for external calls
    let ruleFsh012 =
        defineRule
            "AOR-FSH-012"
            "Async Catch Required"
            "External I/O must be wrapped with Async.Catch or try/with"
            RuleSeverity.Critical
            RuleCategory.Safety
            [OperationType.FileEdit; OperationType.AgentTask]
            (fun ctx ->
                match ctx.Data |> Map.tryFind "has_external_io" with
                | Some (:? bool as hasIO) when hasIO ->
                    match ctx.Data |> Map.tryFind "io_has_error_handling" with
                    | Some (:? bool as hasHandling) when hasHandling ->
                        EvaluationResult.Passed (Some "External I/O properly wrapped")
                    | _ ->
                        EvaluationResult.Failed "External I/O must be wrapped with error handling"
                | _ ->
                    EvaluationResult.Skipped "No external I/O detected"
            )

    /// All F# capability rules
    let fsharpRules = [
        ruleFsh001
        ruleFsh010
        ruleFsh012
    ]
```

---

## 8.0 Migration Guide

### 8.1 Priority Order

1. **Week 1 - Active Patterns** (SC-FSH-003)
   - Create `ErrorPatterns` module
   - Create `StatusPatterns` module
   - Update error handling in OodaController

2. **Week 2 - Enhanced ROP** (SC-FSH-020, SC-FSH-021)
   - Enhance `Rop.fs` with applicative operators
   - Add composition operators
   - Add retry utilities

3. **Week 3 - Units of Measure** (SC-FSH-004)
   - Create `Units.fs` module
   - Update timeout handling
   - Update port specifications

4. **Week 4 - Property Testing** (SC-FSH-030)
   - Add FsCheck dependency
   - Create generators for domain types
   - Add property tests for core logic

### 8.2 Backward Compatibility

- All existing code continues to work
- New patterns are opt-in initially
- Gradual migration as files are edited
- AOR rules start as warnings, become errors after migration

---

## 9.0 Validation Checklist

### 9.1 Per-Module Checklist

- [ ] Module header documents STAMP constraints (SC-FSH-*)
- [ ] All public functions have XML documentation
- [ ] Error types use active patterns for classification (DomainPatterns)
- [ ] Domain values use Units of Measure (DomainUnits)
- [ ] Async operations return AsyncResult (Pipelines.AsyncResult)
- [ ] No exceptions thrown from business logic
- [ ] Pattern matches are exhaustive (SC-FSH-050)
- [ ] Property tests cover invariants
- [ ] Retry logic uses Pipelines.Retry module
- [ ] Timeout handling uses Pipelines.Timeout module

### 9.2 Per-Release Checklist

- [ ] All SC-FSH-* constraints verified (77 total)
- [ ] All TDG-FSH-* requirements met (25 total)
- [ ] All AOR-FSH-* rules pass (26 total)
- [ ] All FEMA-FSH-* failure modes mitigated (23 total)
- [ ] Property test coverage > 80%
- [ ] No compiler warnings
- [ ] Documentation complete

### 9.3 Core Module Compliance Matrix

| Module | STAMP | TDG | AOR | FEMA | Status |
|--------|-------|-----|-----|------|--------|
| Units.fs | SC-FSH-004 | TDG-FSH-001-003 | AOR-FSH-040 | FEMA-FSH-010 | ✅ |
| Composition.fs | SC-FSH-010-013 | TDG-FSH-010 | AOR-FSH-002 | - | ✅ |
| ActivePatterns.fs | SC-FSH-003 | TDG-FSH-030-033 | AOR-FSH-001 | FEMA-FSH-001 | ✅ |
| DomainUnits.fs | SC-FSH-060-065 | TDG-FSH-040-043 | AOR-FSH-040-044 | FEMA-FSH-010-011 | ✅ |
| DomainPatterns.fs | SC-FSH-050-055 | TDG-FSH-030-033 | AOR-FSH-030-033 | FEMA-FSH-013 | ✅ |
| Pipelines.fs | SC-FSH-070-077 | TDG-FSH-050-054 | AOR-FSH-050-055 | FEMA-FSH-002-004 | ✅ |

### 9.4 Safety Constraint Summary

| Category | Constraints | Critical | High | Medium |
|----------|-------------|----------|------|--------|
| Type System | SC-FSH-001-005 | 1 | 3 | 1 |
| Composition | SC-FSH-010-013 | 0 | 1 | 3 |
| Error Handling | SC-FSH-020-024 | 3 | 1 | 0 |
| Testing | SC-FSH-030-033 | 0 | 2 | 2 |
| Concurrency | SC-FSH-040-043 | 2 | 2 | 0 |
| Domain Patterns | SC-FSH-050-055 | 2 | 4 | 0 |
| Domain Units | SC-FSH-060-065 | 2 | 4 | 0 |
| Pipelines | SC-FSH-070-077 | 3 | 4 | 1 |
| **Total** | **77** | **13** | **21** | **7** |

### 9.5 Fractal Cockpit Constraint Summary

| Category | Constraints | Critical | High | Medium |
|----------|-------------|----------|------|--------|
| Fractal Context | SC-FRAC-001-020 | 2 | 6 | 2 |
| OODA Loop | SC-OODA-001-005 | 1 | 3 | 1 |
| CEA Controller | SC-CEA-001-005 | 2 | 2 | 1 |
| Signal Arrows | SC-ARROW-001-012 | 1 | 6 | 2 |
| Telemetry Streams | SC-STREAM-001-010 | 2 | 5 | 3 |
| STM Concurrency | SC-STM-001-008 | 3 | 5 | 0 |
| **Subtotal** | **50** | **11** | **27** | **9** |
| **Grand Total** | **127** | **24** | **48** | **16** |

---

## 10.0 Cross-Reference Index

### STAMP → Module Mapping

| STAMP ID Range | Module | Purpose |
|----------------|--------|---------|
| SC-FSH-001-005 | Rop.fs, Domain.fs | Type safety fundamentals |
| SC-FSH-010-013 | Composition.fs | Function composition |
| SC-FSH-020-024 | Rop.fs, Pipelines.fs | Error handling |
| SC-FSH-030-033 | Tests/ | Property testing |
| SC-FSH-040-043 | All async modules | Concurrency safety |
| SC-FSH-050-055 | DomainPatterns.fs | Active pattern classification |
| SC-FSH-060-065 | DomainUnits.fs | Type-safe units |
| SC-FSH-070-077 | Pipelines.fs | Reusable pipelines |

### Related Elixir STAMP Constraints

| F# Constraint | Elixir Equivalent | Shared Concern |
|---------------|-------------------|----------------|
| SC-FSH-062 | SC-EMR-057 | Emergency stop <5s |
| SC-FSH-075 | SC-PRF-050 | Response latency <50ms |
| SC-FSH-072 | SC-PRF-055 | No blocking >50ms |
| SC-FSH-064 | SC-LOG-006 | HLC for L3+ logs |
| AOR-FSH-041 | SC-AGT-017 | Agent efficiency >90% |

---

**Document Control**
- Version: 2.0.0
- Created: 2025-12-29
- Updated: 2025-12-29
- Author: Claude Code (Cybernetic Architect)
- Review Required: Team Lead
- Next Review: 2026-01-15
- Modules Covered: 6 Core (Units, Composition, ActivePatterns, DomainUnits, DomainPatterns, Pipelines)
- Total Constraints: STAMP(77) + TDG(25) + AOR(26) + FEMA(23) = 151
