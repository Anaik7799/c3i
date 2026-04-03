# SIL6 Mesh TUI Implementation Plan
## Biomorphic Kernel Orchestration with Distributed Systems Algorithm Integration

**Version**: 1.0.0 | **Date**: 2026-01-04 | **Status**: ACTIVE
**STAMP**: SC-SIL6-*, SC-CLU-*, SC-OODA-*, SC-TPS-001
**Compliance**: IEC 61508 SIL-6 Biomorphic, ODTP-v20

---

## Document Control

| Field | Value |
|-------|-------|
| Author | Cybernetic Architect |
| Created | 2026-01-04 |
| STAMP Refs | SC-SIL6-001 to SC-SIL6-010, SC-CLU-001 to SC-CLU-005 |
| AOR Refs | AOR-TPS-001 to AOR-TPS-003, AOR-OODA-001 to AOR-OODA-005 |

---

## 1. EXECUTIVE SUMMARY

This document defines the implementation plan for a **SIL-6 Biomorphic compliant Mesh TUI** that orchestrates container startup/shutdown with:
- **10s SLA** for mesh readiness
- **Digital Twin** topology tracking
- **Transaction Semantics** for reliable state transitions
- **OODA Loop** integration for continuous monitoring
- **5-Level Fractal Logging** with Zenoh telemetry

### Key Deliverables

| Deliverable | Purpose | STAMP |
|-------------|---------|-------|
| `MeshStartup.fs` | Boot orchestration with dependency DAG | SC-SIL6-001 |
| `MeshShutdown.fs` | Graceful shutdown with transaction semantics | SC-SIL6-002 |
| `MeshDashboard.fs` | Real-time KPI dashboard (10s refresh) | SC-SIL6-003 |
| `FractalLogger.fs` | 5-level logging with Zenoh publish | SC-OBS-069 |
| `DigitalTwin.fs` | Topology & state tracking | SC-CLU-002 |

---

## 2. ALGORITHM ANALYSIS: OPTIMAL STRATEGIES

Based on analysis of Linux systemd, Windows SCM, Automotive ECU, and Google-scale (Borg/Omega) techniques, the following algorithms are selected for integration:

### 2.1 PHASE 1: STARTUP ALGORITHMS

#### 2.1.1 Dependency-Aware Parallelization (SELECTED: HIGH PRIORITY)

**Source**: Linux systemd unit dependencies
**Reference**: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html

**Technique**:
```
Before= / After= / Requires= / Wants= semantics
Parallel execution of independent units
Socket/D-Bus activation for lazy start
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Boot Speed** | 60-80% faster than serial | DAG computation overhead | IMPLEMENT |
| **Reliability** | Explicit dependency enforcement | Configuration complexity | IMPLEMENT |
| **Debugging** | Clear dependency chain | Harder parallel tracing | MITIGATE with telemetry |

**Implementation in Indrajaal**:
```fsharp
// ServiceDAG.fs enhancement
type ServiceUnit = {
    Name: string
    After: string list      // Must start after these
    Requires: string list   // Hard dependencies
    Wants: string list      // Soft dependencies
    Type: StartType         // Simple | Socket | OneShot | Notify
}

// Topological sort for parallel waves
let computeStartOrder (units: ServiceUnit list) : Wave list
```

**Why Implement**: Our SIL-6 Biomorphic requirement demands deterministic boot order. Parallel waves with dependency tracking achieves both speed (10s SLA) and reliability.

---

#### 2.1.2 Socket Activation / Lazy Loading (PARTIAL: MEDIUM PRIORITY)

**Source**: systemd socket activation
**Reference**: https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html

**Technique**:
```
Create listening sockets BEFORE service starts
Service inherits socket on first connection
Enables true on-demand activation
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Resource Efficiency** | Services only run when needed | Complexity in socket handoff | PARTIAL |
| **First-Request Latency** | Reduced if pre-warmed | Cold start penalty | MITIGATE |
| **Container Compatibility** | Not native to Podman | Requires custom implementation | DEFER to Phase 2 |

**Implementation in Indrajaal**:
```fsharp
// Pre-bind ports, container starts on first request
type SocketActivation =
    | Enabled of port: int * timeout: TimeSpan
    | Disabled

// Only implement for APP container (Phoenix)
// DB and OBS require immediate availability
```

**Why Partial**: Socket activation conflicts with SIL-6 Biomorphic determinism. We implement pre-binding for health checks but require containers to be fully running.

---

#### 2.1.3 Static Topology Caching (SELECTED: HIGH PRIORITY)

**Source**: Automotive AUTOSAR (startup time minimization)
**Reference**: https://www.autosar.org/standards/classic-platform

**Technique**:
```
Cache dependency graph at build time
Pre-computed startup order
Golden image of known-good state
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Boot Speed** | Eliminates runtime DAG computation | Stale cache risk | IMPLEMENT with validation |
| **Reliability** | Deterministic order every time | Must invalidate on topology change | IMPLEMENT |
| **SIL-6 Biomorphic Compliance** | Required for certification | Validation overhead | REQUIRED |

**Implementation in Indrajaal**:
```fsharp
// DigitalTwin.fs - Static topology cache
type TopologyCache = {
    Version: string
    Hash: string              // SHA256 of config
    StartOrder: Wave list
    CreatedAt: DateTimeOffset
    ValidatedAt: DateTimeOffset option
}

// Validation on every boot
let validateCache (cache: TopologyCache) (current: Config) : bool =
    hash current = cache.Hash
```

**Why Implement**: SIL-6 Biomorphic requires deterministic behavior. Static topology caching with validation provides both speed and safety.

---

#### 2.1.4 Staggered Start with Jitter (SELECTED: MEDIUM PRIORITY)

**Source**: Windows Service Control Manager (SCM)
**Reference**: https://learn.microsoft.com/en-us/windows/win32/services/service-startup

**Technique**:
```
Delayed start for non-critical services
Random jitter to prevent thundering herd
Group-based priority levels
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Resource Contention** | Prevents CPU/IO spikes | Slower total boot | IMPLEMENT for workers |
| **Thundering Herd** | Eliminates concurrent startup storms | Jitter adds unpredictability | IMPLEMENT with bounds |
| **SIL-6 Biomorphic Compliance** | Bounded jitter is acceptable | Must document jitter range | IMPLEMENT |

**Implementation in Indrajaal**:
```fsharp
// Jitter only for worker containers, not critical path
type StartDelay =
    | Immediate                           // Critical path (DB, OBS)
    | Delayed of ms: int                  // Non-critical
    | Jittered of baseMs: int * maxMs: int // Workers with jitter

// Example: Workers start 1000-2000ms after critical path
let workerDelay = Jittered(1000, 2000)
```

**Why Implement**: Prevents resource contention during parallel wave startup. Jitter bounded to maintain 10s SLA.

---

### 2.2 PHASE 2: LOGGING ALGORITHMS

#### 2.2.1 Structured Metadata Injection (SELECTED: HIGH PRIORITY)

**Source**: Dapper/OpenTelemetry distributed tracing
**Reference**: https://research.google/pubs/dapper-a-large-scale-distributed-systems-tracing-infrastructure/

**Technique**:
```
TraceID, SpanID, OperationID in every log line
Correlation across containers
Fractal level tagging (L1-L5)
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Debugging** | Full request tracing | Metadata overhead | IMPLEMENT |
| **Compliance** | Required for SIL-6 Biomorphic audit | Storage increase | REQUIRED |
| **Performance** | Enables sampling | Context propagation cost | IMPLEMENT |

**Implementation in Indrajaal**:
```fsharp
// FractalLogger.fs
type LogContext = {
    TraceId: string
    SpanId: string
    ParentSpanId: string option
    OperationId: string
    FractalLevel: Level       // L1_Unit to L5_Ecosystem
    Node: string
    Container: string
    Timestamp: DateTimeOffset
}

// Every log entry includes context
let log level ctx message =
    Zenoh.publish $"indrajaal/logs/{ctx.FractalLevel}"
        { Context = ctx; Level = level; Message = message }
```

**Why Implement**: Mandatory for SIL-6 Biomorphic traceability. Already have Zenoh infrastructure.

---

#### 2.2.2 Head-Based Sampling with Tail Preservation (SELECTED: HIGH PRIORITY)

**Source**: Google Dapper sampling strategy
**Reference**: https://research.google/pubs/dapper-a-large-scale-distributed-systems-tracing-infrastructure/

**Technique**:
```
Sample at trace head (first request)
All or nothing within trace
Preserve tails (errors, slow requests)
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Storage** | 90% reduction | Miss some data | IMPLEMENT with tail preservation |
| **Debugging** | Coherent traces | Sampling rate tuning | IMPLEMENT |
| **SIL-6 Biomorphic** | Must preserve all errors | No error sampling | REQUIRED |

**Implementation in Indrajaal**:
```fsharp
type SamplingDecision =
    | Sample of rate: float    // 1.0 = 100%, 0.1 = 10%
    | ForceKeep                // Errors, slow traces
    | ForceDrop                // Debug noise

let shouldSample (ctx: LogContext) (level: LogLevel) : bool =
    match level with
    | Error | Critical -> true  // Never sample errors
    | _ when ctx.FractalLevel <= L2_Component -> true  // Keep low-level
    | _ -> Random.NextDouble() < samplingRate
```

**Why Implement**: Essential for production log volume management while maintaining SIL-6 Biomorphic error traceability.

---

#### 2.2.3 Async Binary Streaming with Circular Buffers (SELECTED: HIGH PRIORITY)

**Source**: High-performance logging systems
**Reference**: Internal pattern from embedded systems

**Technique**:
```
Binary log format (not JSON)
Circular buffer for burst absorption
Async flush to prevent blocking
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Performance** | 10x faster than JSON | Binary complexity | IMPLEMENT |
| **Latency** | Non-blocking writes | Buffer overflow risk | IMPLEMENT with overflow handling |
| **Debugging** | Requires decoder | Harder to read raw | MITIGATE with tooling |

**Implementation in Indrajaal**:
```fsharp
// Circular buffer for burst absorption
type LogBuffer = {
    Buffer: byte array
    WritePos: int ref
    ReadPos: int ref
    Capacity: int
    OverflowCount: int64 ref
}

// Binary format: [timestamp:8][level:1][ctx_len:2][ctx:N][msg_len:2][msg:N]
let writeBinary (buffer: LogBuffer) (entry: LogEntry) =
    // Lock-free append with overflow detection
```

**Why Implement**: Required for 10s SLA - cannot block on logging.

---

### 2.3 PHASE 3: SHUTDOWN ALGORITHMS

#### 2.3.1 Pre-Shutdown Notification (SELECTED: CRITICAL)

**Source**: Windows SERVICE_CONTROL_PRESHUTDOWN
**Reference**: https://learn.microsoft.com/en-us/windows/win32/services/service-control-handler-function

**Technique**:
```
Send PRESHUTDOWN 2-5 minutes before shutdown
Services can prepare (flush caches, drain connections)
Timeout enforcement
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Data Integrity** | Complete flush before stop | Longer shutdown time | REQUIRED |
| **Connection Draining** | Zero dropped requests | Delay | IMPLEMENT with SLA |
| **SIL-6 Biomorphic** | Required for deterministic shutdown | Complexity | REQUIRED |

**Implementation in Indrajaal**:
```fsharp
type ShutdownPhase =
    | PreShutdown of timeoutMs: int  // Notify, prepare
    | Draining of timeoutMs: int      // Accept no new, finish existing
    | Stopping of timeoutMs: int      // Graceful stop
    | Killing                         // Force kill
    | Terminated

// Staged shutdown with timeouts
let shutdownSequence = [
    PreShutdown 5000    // 5s to prepare
    Draining 10000      // 10s to drain
    Stopping 3000       // 3s graceful
    Killing             // Force
]
```

**Why Implement**: Critical for SIL-6 Biomorphic determinism. Database must flush before container stops.

---

#### 2.3.2 Connection Draining (SELECTED: CRITICAL)

**Source**: Google Borg lameduck state
**Reference**: https://research.google/pubs/large-scale-cluster-management-at-google-with-borg/

**Technique**:
```
Mark container as "lameduck" (accepting no new connections)
Finish existing requests
Timeout and force after grace period
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **Zero Downtime** | No dropped requests | Extended shutdown | IMPLEMENT |
| **User Experience** | Seamless transitions | Infrastructure complexity | IMPLEMENT |
| **SIL-6 Biomorphic** | Required for graceful degradation | Timeout management | REQUIRED |

**Implementation in Indrajaal**:
```fsharp
type LameduckState = {
    EnteredAt: DateTimeOffset
    ActiveConnections: int
    TimeoutAt: DateTimeOffset
    HealthStatus: string  // "lameduck"
}

// Health check returns "lameduck" -> no new requests routed
let setLameduck (container: string) =
    DigitalTwin.updateState container (fun s ->
        { s with Status = "lameduck"; HealthStatus = "lameduck" })
    // Existing requests continue until drain timeout
```

**Why Implement**: Essential for zero-downtime operations. Our Phoenix app must drain before stop.

---

#### 2.3.3 Dying Gasp State Save (SELECTED: CRITICAL)

**Source**: Automotive ECU shutdown protocol
**Reference**: AUTOSAR shutdown specifications

**Technique**:
```
Last-moment state persistence
Battery-backed or capacitor-powered flush
Checksum-validated state dump
```

**Tradeoff Analysis**:

| Aspect | Benefit | Cost | Decision |
|--------|---------|------|----------|
| **State Recovery** | Resume from exact state | Implementation complexity | IMPLEMENT |
| **SIL-6 Biomorphic** | Required for recoverability | Verification overhead | REQUIRED |
| **Debugging** | Post-mortem analysis | Storage for state dumps | IMPLEMENT |

**Implementation in Indrajaal**:
```fsharp
// DigitalTwin.fs - State checkpoint on shutdown
type StateCheckpoint = {
    Timestamp: DateTimeOffset
    Hash: string
    State: Map<string, HolonState>
    ActiveOperations: OperationId list
    PendingWrites: Write list
}

// Called in PreShutdown phase
let saveCheckpoint (twin: DigitalTwin) =
    let checkpoint = createCheckpoint twin
    // Write to SQLite (fast, durable)
    SqliteStore.write "dying_gasp" checkpoint
    // Publish to Zenoh for observers
    Zenoh.publish "indrajaal/shutdown/checkpoint" checkpoint
```

**Why Implement**: SIL-6 Biomorphic requires full recoverability. State checkpoint enables restart from known state.

---

### 2.4 GOOGLE-SCALE TECHNIQUES

#### 2.4.1 Predictive Oversubscription (DEFERRED: LOW PRIORITY)

**Source**: Google Borg
**Reference**: https://research.google/pubs/large-scale-cluster-management-at-google-with-borg/

**Tradeoff**: Our 3-container architecture doesn't benefit from bin-packing optimization. **DEFER**.

---

#### 2.4.2 Pod Disruption Budgets (ADAPTED: MEDIUM PRIORITY)

**Source**: Kubernetes
**Reference**: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/

**Technique**:
```
Minimum available instances during operations
Rolling updates with budget enforcement
```

**Implementation Adaptation**:
```fsharp
// Quorum-based disruption budget
type DisruptionBudget = {
    MinHealthy: int        // Minimum healthy containers
    MaxUnavailable: int    // Maximum simultaneous failures
}

// For our 3-container stack:
let budget = { MinHealthy = 2; MaxUnavailable = 1 }

// Never stop DB while APP is running
// Never stop OBS during active tracing
```

**Why Adapt**: Ensures minimum viable stack during maintenance.

---

#### 2.4.3 Maglev Consistent Hashing (DEFERRED: NOT APPLICABLE)

**Source**: Google Maglev
**Reference**: https://research.google/pubs/maglev-a-fast-and-reliable-software-network-load-balancer/

**Tradeoff**: Single-node standalone deployment doesn't require load balancing. **DEFER to cluster mode**.

---

## 3. AS-IS vs TO-BE ARCHITECTURE

### 3.1 AS-IS: Current State

```
┌─────────────────────────────────────────────────────────────┐
│                    CURRENT ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  SIL6Orchestrator.fsx (F# Script)                           │
│  ├─ initializeTwin() - Static dictionary                    │
│  ├─ OBP.scour() - Port cleanup (5 ports)                    │
│  ├─ OBP.bootNode() - Serial podman-compose up               │
│  ├─ Parallel wave (app-1..3 + obs) - Basic async            │
│  └─ OBP.monitorKPIs() - 10s dashboard refresh               │
│                                                              │
│  GAPS:                                                       │
│  ✗ No dependency DAG (hardcoded order)                      │
│  ✗ No health check integration (assumed success)            │
│  ✗ No transaction semantics (no rollback)                   │
│  ✗ No structured logging (printfn only)                     │
│  ✗ No shutdown draining (immediate kill)                    │
│  ✗ No state checkpoint (no recovery data)                   │
│  ✗ No Zenoh telemetry integration                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 TO-BE: Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TARGET ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │             MESH ORCHESTRATION LAYER              │      │
│  │  (F# Frozen Core - SIL-6 Biomorphic Certified)               │      │
│  ├───────────────────────────────────────────────────┤      │
│  │                                                   │      │
│  │  DigitalTwin.fs                                   │      │
│  │  ├─ HolonGenotype (Static Config)                 │      │
│  │  ├─ HolonPhenotype (Runtime State)                │      │
│  │  ├─ TopologyCache (Validated DAG)                 │      │
│  │  └─ StateCheckpoint (Recovery Data)               │      │
│  │                                                   │      │
│  │  MeshStartup.fs                                   │      │
│  │  ├─ DependencyDAG (Topological Sort)              │      │
│  │  ├─ ParallelWaves (Bounded Parallelism)           │      │
│  │  ├─ JitteredStart (1-2s for workers)              │      │
│  │  ├─ HealthGate (Weighted Checks)                  │      │
│  │  └─ Transaction (Rollback on Failure)             │      │
│  │                                                   │      │
│  │  MeshShutdown.fs                                  │      │
│  │  ├─ PreShutdownNotify (5s)                        │      │
│  │  ├─ ConnectionDraining (10s, Lameduck)            │      │
│  │  ├─ GracefulStop (3s)                             │      │
│  │  ├─ DyingGasp (State Checkpoint)                  │      │
│  │  └─ ForceKill (Timeout)                           │      │
│  │                                                   │      │
│  │  MeshDashboard.fs                                 │      │
│  │  ├─ KPIStream (10s Refresh)                       │      │
│  │  ├─ OODALoop (30s Cycle)                          │      │
│  │  ├─ HealthMatrix (Weighted)                       │      │
│  │  └─ TUIRenderer (Terminal.Gui)                    │      │
│  │                                                   │      │
│  │  FractalLogger.fs                                 │      │
│  │  ├─ StructuredMetadata (TraceID, SpanID)          │      │
│  │  ├─ HeadSampling (Tail Preservation)              │      │
│  │  ├─ CircularBuffer (Burst Absorption)             │      │
│  │  └─ ZenohPublish (Async)                          │      │
│  │                                                   │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │              ELIXIR BRIDGE LAYER                  │      │
│  │  (Runtime Integration)                            │      │
│  ├───────────────────────────────────────────────────┤      │
│  │  • ZenohMesh.ex ↔ Zenoh Pub/Sub                   │      │
│  │  • Sentinel.ex ↔ Health Consensus                 │      │
│  │  • FailoverManager.ex ↔ Process Migration         │      │
│  │  • StandaloneConfig.ex ↔ Cluster Config           │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │              CONTAINER LAYER                      │      │
│  │  (Podman Rootless)                                │      │
│  ├───────────────────────────────────────────────────┤      │
│  │  • indrajaal-db-prod (PostgreSQL 17)              │      │
│  │  • indrajaal-obs-prod (OTEL + Grafana + SigNoz)   │      │
│  │  • indrajaal-ex-app-1 (Phoenix + Redis + FLAME)   │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. IMPLEMENTATION TIMELINE

### Phase 1: Core Modules (Week 1)

| Module | Description | STAMP | Priority |
|--------|-------------|-------|----------|
| `DigitalTwin.fs` | Genotype/Phenotype/Cache | SC-CLU-002 | P0 |
| `MeshStartup.fs` | DAG + Waves + Health | SC-SIL6-001 | P0 |
| `MeshShutdown.fs` | Drain + Checkpoint | SC-SIL6-002 | P0 |

### Phase 2: Observability (Week 2)

| Module | Description | STAMP | Priority |
|--------|-------------|-------|----------|
| `FractalLogger.fs` | Structured + Sampling | SC-OBS-069 | P0 |
| `MeshDashboard.fs` | TUI + KPIs | SC-SIL6-003 | P1 |
| Zenoh Integration | Pub/Sub bindings | SC-BRIDGE-005 | P1 |

### Phase 3: CLI Integration (Week 3)

| Task | Description | STAMP | Priority |
|------|-------------|-------|----------|
| `sa-*` Commands | Wire to new modules | SC-CMD-010+ | P0 |
| `devenv.nix` | Update command defs | - | P0 |
| Verification | 10s SLA validation | SC-SIL6-010 | P0 |

---

## 5. STAMP CONSTRAINTS

### New Constraints for Mesh TUI

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL6-001 | Mesh startup MUST complete in <10s | CRITICAL |
| SC-SIL6-002 | Shutdown MUST drain connections before stop | CRITICAL |
| SC-SIL6-003 | Dashboard MUST refresh every 10s | HIGH |
| SC-SIL6-004 | State checkpoint MUST occur on shutdown | CRITICAL |
| SC-SIL6-005 | Dependency DAG MUST be validated on boot | CRITICAL |
| SC-SIL6-006 | Health checks MUST use weighted scoring | HIGH |
| SC-SIL6-007 | Parallel waves MUST respect dependency order | CRITICAL |
| SC-SIL6-008 | Jitter MUST be bounded (1-2s) | MEDIUM |
| SC-SIL6-009 | Logs MUST include TraceID/SpanID | HIGH |
| SC-SIL6-010 | Recovery MUST use dying gasp checkpoint | CRITICAL |

---

## 6. AOR RULES

### New Operating Rules

| ID | Rule |
|----|------|
| AOR-SIL6-001 | Validate topology cache before startup |
| AOR-SIL6-002 | Rollback all containers if any critical failure |
| AOR-SIL6-003 | Enter lameduck state before shutdown |
| AOR-SIL6-004 | Save dying gasp checkpoint in PreShutdown |
| AOR-SIL6-005 | Publish all state changes to Zenoh |
| AOR-SIL6-006 | Use head-based sampling for logs |
| AOR-SIL6-007 | Never sample error logs |
| AOR-SIL6-008 | Apply jitter only to non-critical path |
| AOR-SIL6-009 | Verify health consensus before marking ready |
| AOR-SIL6-010 | 5-level RCA on repeated failures (Jidoka) |

---

## 7. TECHNIQUE SELECTION MATRIX

### Final Selection Summary

| Technique | Source | Status | Priority | Rationale |
|-----------|--------|--------|----------|-----------|
| Dependency-Aware Parallelization | systemd | SELECTED | HIGH | Required for 10s SLA |
| Socket Activation | systemd | PARTIAL | MEDIUM | Only for health pre-bind |
| Static Topology Caching | AUTOSAR | SELECTED | HIGH | SIL-6 Biomorphic determinism |
| Staggered Start with Jitter | Windows | SELECTED | MEDIUM | Prevent thundering herd |
| Structured Metadata Injection | Dapper | SELECTED | HIGH | Traceability required |
| Head-Based Sampling | Dapper | SELECTED | HIGH | Log volume management |
| Async Binary Streaming | Embedded | SELECTED | HIGH | Non-blocking requirement |
| Pre-Shutdown Notification | Windows | SELECTED | CRITICAL | Data integrity |
| Connection Draining | Borg | SELECTED | CRITICAL | Zero downtime |
| Dying Gasp State Save | AUTOSAR | SELECTED | CRITICAL | Recoverability |
| Pod Disruption Budgets | K8s | ADAPTED | MEDIUM | Minimum viable stack |
| Predictive Oversubscription | Borg | DEFERRED | LOW | Not applicable to 3-node |
| Maglev Hashing | Google | DEFERRED | N/A | Not applicable to standalone |

---

## 8. REFERENCES

### Primary Sources

1. **systemd Unit Files**: https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
2. **systemd Socket Activation**: https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html
3. **Windows Service Control**: https://learn.microsoft.com/en-us/windows/win32/services/service-control-handler-function
4. **AUTOSAR Classic Platform**: https://www.autosar.org/standards/classic-platform
5. **Google Borg**: https://research.google/pubs/large-scale-cluster-management-at-google-with-borg/
6. **Google Dapper**: https://research.google/pubs/dapper-a-large-scale-distributed-systems-tracing-infrastructure/
7. **Kubernetes Pod Disruptions**: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/
8. **Google Maglev**: https://research.google/pubs/maglev-a-fast-and-reliable-software-network-load-balancer/

### Internal References

- `CLAUDE.md` - System specification
- `GEMINI.md` - Cybernetic architect protocol
- `docs/architecture/HOLON_FOUNDERS_DIRECTIVE.md` - Founder's covenant
- `lib/cepaf/src/Cepaf/Modules/ServiceDAG.fs` - Existing DAG implementation
- `lib/indrajaal/cluster/sentinel.ex` - Health consensus

---

## 9. NEXT STEPS

1. **Implement DigitalTwin.fs** with Genotype/Phenotype split
2. **Implement MeshStartup.fs** with DAG-based parallel waves
3. **Implement MeshShutdown.fs** with drain/checkpoint
4. **Implement FractalLogger.fs** with Zenoh publish
5. **Implement MeshDashboard.fs** with Terminal.Gui TUI
6. **Wire to sa-* commands** in devenv.nix
7. **Verify 10s SLA** with comprehensive testing

---

*Document generated by Cybernetic Architect per SC-DOC-001*
