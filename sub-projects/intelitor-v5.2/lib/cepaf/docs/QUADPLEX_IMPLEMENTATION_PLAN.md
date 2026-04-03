# CEPAF Quadplex Implementation Plan
**Version**: 1.0.0 | **Date**: 2025-12-23 | **Status**: APPROVED
**Estimated Effort**: 6 Implementation Phases

---

## Executive Summary

This document provides a detailed, step-by-step implementation plan for integrating full Quadplex observability into CEPAF#. The plan is organized into 6 phases with specific deliverables, acceptance criteria, and STAMP compliance checkpoints.

---

## Phase Overview

| Phase | Name | Priority | Files | Tests |
|-------|------|----------|-------|-------|
| **1** | Core Types & Interfaces | P0 | 2 | 15 |
| **2** | Channel Implementations | P0 | 4 | 40 |
| **3** | Central Logger Refactor | P0 | 2 | 25 |
| **4** | Integration & Migration | P1 | 8 | 20 |
| **5** | Testing & Validation | P1 | 3 | 50 |
| **6** | Documentation & Hardening | P2 | 4 | 10 |

**Total**: 23 files, 160 tests

---

## Phase 1: Core Types & Interfaces

### 1.1 Objectives
- Define all Quadplex type definitions in F#
- Create interface contracts for channels
- Establish STAMP-compliant type system

### 1.2 Deliverables

#### File 1: `lib/cepaf/src/Cepaf/Observability/Types.fs`

```fsharp
// Contents:
// - LogLevel discriminated union
// - TraceContext record type
// - LogMetadata record type
// - EventCategory discriminated union (12 categories)
// - TelemetryPayload discriminated union (18 variants)
// - QuadplexEvent record type
// - QuadplexConfig record type
// - FileFormat, OtlpProtocol unions
// - ILogChannel interface
// - ITelemetryExporter interface
// - IStateStore interface
// - Default configuration values
```

**Key Types to Implement:**

```fsharp
type LogLevel = Trace | Debug | Info | Warning | Error | Critical

type TraceContext = {
    TraceId: string
    SpanId: string
    ParentSpanId: string option
    TraceFlags: byte
    TraceState: string
}

type EventCategory =
    | Protocol | Phase | Task | Safety | Container
    | Performance | Security | Agent | OODA | Phics
    | Database | Network

type ILogChannel =
    abstract Write: QuadplexEvent -> unit
    abstract Flush: unit -> unit
    abstract IsEnabled: LogLevel -> bool
```

#### File 2: `lib/cepaf/src/Cepaf/Observability/TraceContext.fs`

```fsharp
// Contents:
// - TraceContext generation functions
// - Span ID generation
// - W3C Trace Context parsing
// - Context propagation helpers
// - Sampling decision functions
```

### 1.3 Acceptance Criteria

- [ ] All types compile without warnings
- [ ] Types are JSON-serializable
- [ ] Default config passes validation
- [ ] Interface contracts are complete
- [ ] XML documentation on all public types

### 1.4 Test Requirements

| Test | Description | Type |
|------|-------------|------|
| Types_LogLevel_Ordering | LogLevel values are ordered correctly | Unit |
| Types_TraceContext_Generation | TraceId/SpanId format validation | Unit |
| Types_QuadplexEvent_Serialization | JSON round-trip | Property |
| Types_Config_Defaults | Default values are valid | Unit |
| Types_Interface_Contracts | Interfaces are implementable | Unit |

### 1.5 STAMP Compliance

- **SC-OBS-071**: Types support 4-channel architecture
- **SC-VAL-003**: Types support consensus validation

---

## Phase 2: Channel Implementations

### 2.1 Objectives
- Implement all 4 logging channels
- Ensure thread-safety and performance
- Support graceful degradation

### 2.2 Deliverables

#### Channel 1: `lib/cepaf/src/Cepaf/Observability/ConsoleChannel.fs`

**Features:**
- Serilog-based console output
- Color-coded severity levels
- Structured message formatting
- Progress bar rendering for tasks
- Configurable minimum level
- Thread-safe writes

**Implementation Notes:**
```fsharp
// Use Serilog.Sinks.Console with AnsiConsoleTheme
// Implement ILogChannel interface
// Support rich formatting with {Properties}
// Handle ANSI escape codes for progress bars
```

#### Channel 2: `lib/cepaf/src/Cepaf/Observability/FileChannel.fs`

**Features:**
- JSON Lines format (default)
- Log rotation by size
- Configurable retention
- Async buffered writes
- Atomic file operations
- Structured text fallback

**Implementation Notes:**
```fsharp
// Use FileStream with FileShare.Read
// Implement rotation with timestamp suffix
// Buffer writes for performance
// Use lock object for thread safety
```

#### Channel 3: `lib/cepaf/src/Cepaf/Observability/TelemetryChannel.fs`

**Features:**
- OTLP/gRPC export (primary)
- OTLP/HTTP fallback
- Batch processing
- Retry with exponential backoff
- Graceful degradation on failure
- Resource attribute enrichment

**Implementation Notes:**
```fsharp
// Use ConcurrentQueue for batching
// Implement background worker for flushing
// Map QuadplexEvent to OTLP LogRecord
// Handle connection failures gracefully
// Track export success rate
```

#### Channel 4: `lib/cepaf/src/Cepaf/Observability/StateTrackerChannel.fs`

**Features:**
- SQLite persistence
- Event history table
- Task log table
- System state (key-value)
- Metrics storage
- Span storage for traces
- Query interface

**Implementation Notes:**
```fsharp
// Use Microsoft.Data.Sqlite
// Create tables on initialization
// Support UPSERT for state updates
// Index on timestamp, category, trace_id
// Implement pruning for retention
```

### 2.3 Acceptance Criteria

- [ ] All channels implement ILogChannel
- [ ] Console output is readable and colored
- [ ] File rotation works at configured size
- [ ] OTLP export succeeds with SigNoz
- [ ] SQLite persists across restarts
- [ ] No data loss under load

### 2.4 Test Requirements

| Test | Description | Type |
|------|-------------|------|
| Console_ColorOutput | Colors match severity | Unit |
| Console_ProgressBar | Progress renders correctly | Unit |
| File_Rotation | Rotates at size limit | Integration |
| File_Retention | Old logs are pruned | Integration |
| File_JsonFormat | Valid JSON Lines | Property |
| Telemetry_BatchSize | Respects batch config | Unit |
| Telemetry_Retry | Retries on failure | Unit |
| Telemetry_Degradation | Continues on OTLP failure | Unit |
| StateTracker_Events | Events are persisted | Integration |
| StateTracker_Tasks | Tasks are logged | Integration |
| StateTracker_Query | Query returns results | Integration |
| StateTracker_Prune | Old data is pruned | Integration |
| Channel_ThreadSafety | Concurrent writes safe | Property |

### 2.5 STAMP Compliance

- **SC-OBS-069**: Console + File = dual logging
- **SC-OBS-071**: 4 channels implemented
- **SC-VAL-001**: No interruption (async writes)

---

## Phase 3: Central Logger Refactor

### 3.1 Objectives
- Refactor existing QuadplexLogger
- Add trace context management
- Implement structured event emission
- Add metrics collection

### 3.2 Deliverables

#### File: `lib/cepaf/src/Cepaf/Observability/QuadplexLogger.fs`

**Public API:**

```fsharp
type QuadplexLogger(config: QuadplexConfig) =
    // Trace Management
    member StartTrace: name: string -> string
    member StartSpan: name: string -> string
    member EndSpan: name: string * durationMs: int64 * status: string -> unit

    // Standard Logging
    member Trace: msg: string * ?category: EventCategory -> unit
    member Debug: msg: string * ?category: EventCategory -> unit
    member Info: msg: string * ?category: EventCategory -> unit
    member Warning: msg: string * ?category: EventCategory -> unit
    member Error: msg: string * ?err: AppError * ?ex: exn -> unit
    member Critical: msg: string * ?ex: exn -> unit

    // Structured Events
    member Emit: telemetryEvent: TelemetryPayload -> unit

    // Metrics
    member LogMetric: name: string * value: float * ?unit: string * ?tags: Map<string, string> -> unit

    // State Management
    member SetState: key: string * value: string -> unit
    member GetState: key: string -> string option
    member QueryEvents: category: EventCategory option * level: LogLevel option * limit: int -> obj list

    // Lifecycle
    member Flush: unit -> unit
    interface IDisposable
```

#### File: `lib/cepaf/src/Cepaf/Observability/MetricsCollector.fs`

**Features:**
- Histogram support
- Counter support
- Gauge support
- Timer helper
- Metric aggregation
- Periodic flush

### 3.3 Migration Plan

**Step 1**: Create new QuadplexLogger in Observability folder
**Step 2**: Add adapter methods for existing API
**Step 3**: Update Infrastructure.fs to use new logger
**Step 4**: Deprecate old implementation
**Step 5**: Remove old code after validation

### 3.4 Acceptance Criteria

- [ ] All existing tests pass
- [ ] Trace context propagates correctly
- [ ] Metrics are collected and exported
- [ ] State is persisted and queryable
- [ ] No performance regression

### 3.5 Test Requirements

| Test | Description | Type |
|------|-------------|------|
| Logger_TraceContext | Trace/Span IDs propagate | Unit |
| Logger_AllLevels | All log levels work | Unit |
| Logger_Emit | All payload types handled | Unit |
| Logger_Metrics | Metrics are recorded | Unit |
| Logger_State | State CRUD operations | Unit |
| Logger_Query | Events are queryable | Integration |
| Logger_Flush | All channels flushed | Unit |
| Logger_Dispose | Resources released | Unit |

---

## Phase 4: Integration & Migration

### 4.1 Objectives
- Update all phases to use new logger
- Add observability to all components
- Ensure backward compatibility

### 4.2 Files to Update

| File | Changes |
|------|---------|
| `Infrastructure.fs` | Use new QuadplexLogger, remove old |
| `Orchestrator.fs` | Add trace spans, emit phase events |
| `Phases/AceVerifier.fs` | Add container event telemetry |
| `Phases/DbVerifier.fs` | Add database metrics |
| `Phases/VTO.fs` | Add cleanup metrics |
| `Phases/Builder.fs` | Add build metrics |
| `Phases/FormalVerification.fs` | Add verification metrics |
| `Modules/Phics.fs` | Add latency metrics |
| `Modules/CyberneticAgents.fs` | Add agent metrics |
| `OodaController.fs` | Add OODA cycle metrics |

### 4.3 Integration Points

**Orchestrator:**
```fsharp
let runProtocol logger runner config = asyncResult {
    let traceId = logger.StartTrace("CEPAF_PROTOCOL")

    logger.Emit(ProtocolStart DateTimeOffset.UtcNow)

    // ... phases ...

    logger.Emit(ProtocolComplete(duration, true))
    logger.Flush()
}
```

**Phase Pattern:**
```fsharp
let execute logger runner config = asyncResult {
    let spanId = logger.StartSpan("PHASE_NAME")
    logger.Emit(PhaseStart("PHASE_NAME", Map.empty))

    // ... tasks ...

    logger.Emit(PhaseComplete("PHASE_NAME", duration, true, metrics))
    logger.EndSpan("PHASE_NAME", duration, "OK")
}
```

### 4.4 Acceptance Criteria

- [ ] All phases emit trace spans
- [ ] All phases emit phase events
- [ ] Metrics are collected for all operations
- [ ] Existing functionality unchanged
- [ ] No new compiler warnings

---

## Phase 5: Testing & Validation

### 5.1 Objectives
- Comprehensive test coverage
- Property-based testing
- Integration tests with SigNoz
- STAMP compliance validation

### 5.2 Deliverables

#### File: `lib/cepaf/test/Cepaf.Tests/QuadplexTests.fs`

**Test Categories:**

1. **Unit Tests** (30)
   - Type serialization
   - Configuration validation
   - Channel behavior
   - Logger methods

2. **Property Tests** (10)
   - Event routing (all events reach all channels)
   - Thread safety (concurrent writes)
   - Trace context propagation
   - Metric aggregation

3. **Integration Tests** (10)
   - SigNoz export
   - SQLite persistence
   - File rotation
   - Full protocol trace

### 5.3 STAMP Compliance Tests

```fsharp
[<Tests>]
let stampComplianceTests =
    testList "STAMP Observability Compliance" [
        testCase "SC-OBS-069: Dual logging enabled" <| fun _ ->
            let config = defaultConfig
            Expect.isTrue config.ConsoleEnabled "Console must be enabled"
            Expect.isTrue config.FileEnabled "File must be enabled"

        testCase "SC-OBS-071: 4 channels attached" <| fun _ ->
            let logger = QuadplexLogger(defaultConfig)
            // Verify all 4 channels are active
            Expect.equal (logger.ChannelCount) 4 "Must have 4 channels"

        testCase "SC-VAL-001: No interruption under load" <| fun _ ->
            let logger = QuadplexLogger(defaultConfig)
            let events = [1..10000] |> List.map (fun i ->
                async { logger.Info(sprintf "Event %d" i) }
            )
            Async.Parallel events |> Async.RunSynchronously |> ignore
            // No exceptions = passed
    ]
```

### 5.4 Test Environment

**Requirements:**
- SigNoz running on localhost:4317
- SQLite write permissions
- Console output capture

**Setup Script:**
```bash
# Start SigNoz for integration tests
podman-compose -f podman-compose-obs-standalone.yml up -d
```

---

## Phase 6: Documentation & Hardening

### 6.1 Objectives
- Complete API documentation
- Operational runbooks
- Performance tuning guide
- Monitoring dashboards

### 6.2 Deliverables

#### Documentation Files

1. **API Reference** (`docs/api/quadplex-api.md`)
   - All public types
   - All public methods
   - Usage examples

2. **Operations Guide** (`docs/ops/quadplex-operations.md`)
   - Configuration reference
   - Troubleshooting guide
   - Performance tuning

3. **Dashboard Definitions** (`artifacts/dashboards/`)
   - Grafana dashboard JSON
   - SigNoz dashboard config

4. **Runbooks** (`docs/runbooks/`)
   - Log analysis procedures
   - Trace debugging
   - Metric alerting

### 6.3 Performance Hardening

**Optimizations:**
- Object pooling for events
- Pre-allocated buffers
- Batch size tuning
- Async I/O everywhere
- GC pressure reduction

**Benchmarks:**
- 10,000 events/second target
- <1ms p99 latency for emit
- <10MB memory overhead

---

## Implementation Schedule

### Week 1: Foundation
- [ ] Phase 1: Core Types
- [ ] Phase 2: Console + File Channels
- [ ] Initial tests

### Week 2: Telemetry
- [ ] Phase 2: Telemetry + StateTracker
- [ ] Phase 3: Logger Refactor
- [ ] Integration tests

### Week 3: Integration
- [ ] Phase 4: All integrations
- [ ] Phase 5: Full test suite
- [ ] STAMP validation

### Week 4: Hardening
- [ ] Phase 6: Documentation
- [ ] Performance optimization
- [ ] Production readiness review

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| SigNoz unavailable | Graceful degradation, local-only mode |
| SQLite corruption | WAL mode, periodic backups |
| Performance regression | Benchmarks, async everywhere |
| Breaking changes | Adapter pattern, deprecation period |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Test coverage | >90% |
| STAMP compliance | 100% |
| Event throughput | >10K/s |
| p99 latency | <1ms |
| Memory overhead | <10MB |
| Zero data loss | 100% |

---

## Appendix: File Tree

```
lib/cepaf/src/Cepaf/
├── Observability/
│   ├── Types.fs                 [NEW - Phase 1]
│   ├── TraceContext.fs          [NEW - Phase 1]
│   ├── ConsoleChannel.fs        [NEW - Phase 2]
│   ├── FileChannel.fs           [NEW - Phase 2]
│   ├── TelemetryChannel.fs      [NEW - Phase 2]
│   ├── StateTrackerChannel.fs   [NEW - Phase 2]
│   ├── QuadplexLogger.fs        [NEW - Phase 3]
│   └── MetricsCollector.fs      [NEW - Phase 3]
├── Infrastructure.fs            [MODIFY - Phase 4]
├── Orchestrator.fs              [MODIFY - Phase 4]
├── Phases/
│   ├── AceVerifier.fs           [MODIFY - Phase 4]
│   ├── DbVerifier.fs            [MODIFY - Phase 4]
│   ├── VTO.fs                   [MODIFY - Phase 4]
│   ├── Builder.fs               [MODIFY - Phase 4]
│   └── FormalVerification.fs    [MODIFY - Phase 4]
└── Modules/
    ├── Phics.fs                 [MODIFY - Phase 4]
    └── CyberneticAgents.fs      [MODIFY - Phase 4]

lib/cepaf/test/Cepaf.Tests/
└── QuadplexTests.fs             [NEW - Phase 5]

lib/cepaf/docs/
├── QUADPLEX_CEPAF_ARCHITECTURE.md  [CREATED]
├── QUADPLEX_IMPLEMENTATION_PLAN.md [THIS FILE]
├── api/
│   └── quadplex-api.md          [NEW - Phase 6]
└── ops/
    └── quadplex-operations.md   [NEW - Phase 6]
```

---

**Document Control**
- Author: Claude Code (Cybernetic Architect)
- Version: 1.0.0
- Status: APPROVED
- Created: 2025-12-23T23:45:00+01:00
