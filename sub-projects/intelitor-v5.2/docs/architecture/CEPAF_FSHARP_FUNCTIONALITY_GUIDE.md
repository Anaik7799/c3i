# CEPAF F# Functionality Guide for AI Agents

**Version**: 21.3.0-SIL6 | **Date**: 2026-03-19 | **Status**: ACTIVE
**Audience**: Claude, Gemini, and all AI agents working with Indrajaal

---

## Executive Summary

CEPAF (Cybernetic Execution and Performance Architect Framework) is a **100K+ line F# framework** providing:

| Capability | Description | Entry Point |
|------------|-------------|-------------|
| **Container Orchestration** | Podman lifecycle management | `Cepaf.Modules.Podman` |
| **SIL-6 Biomorphic Mesh Networking** | Safety-critical distributed coordination | `Mesh/HealthCoordinator.fs` |
| **Prajna Cockpit** | AI-enhanced C3I interface | `Cockpit/Prajna.fs` |
| **Biomorphic OODA** | 100ms control loops | `Mesh/OodaSupervisor.fs` |
| **Observability** | Quadplex telemetry (4 channels) | `Observability/QuadplexLogger.fs` |
| **Federation Protocol** | Multi-cluster coordination (implemented) | `SIL6/FederationProtocol.fs` |

---

## 1. Core Architecture

### 1.1 Module Hierarchy

```
lib/cepaf/src/Cepaf/
├── Core/                    # Functional abstractions (Category Theory, Optics, Effects)
├── Modules/                 # Business logic (AOR Engine, Constraint Validator, Agents)
├── Mesh/                    # Distributed coordination (Health, OODA, Digital Twin)
├── Cockpit/                 # Prajna AI interface (Guardian, Sentinel, Immutable State)
├── Observability/           # Telemetry pipeline (Fractal logging, OTEL)
├── Zenoh/                   # Pub/sub communication
├── SIL6/                    # Safety-critical (Reed-Solomon, Rollback, Federation)
├── Knowledge/               # AI/ML integration (OpenRouter, DuckDB)
├── Bridge/                  # Elixir interop (Port handler, JSON-RPC)
└── Phases/                  # Orchestration phases (Build, Test, Verify)
```

### 1.2 Environment Types

```fsharp
type Environment =
    | DEV                      // Development (4 containers)
    | TEST                     // Test environment
    | DEMO                     // Demonstration mode
    | PROD                     // Production
    | SYSTEM_STANDALONE_DB_TEST // Database-only testing
    | SYSTEM_STANDALONE_OBS_TEST // Observability-only testing
    | MESH                     // Full mesh networking
    | SHADOW_MODE_EVAL         // Shadow deployment evaluation
```

---

## 2. Podman Container Management

### 2.1 Core Operations

| Function | Purpose | STAMP |
|----------|---------|-------|
| `Podman.getSocketPath(uid)` | Rootless/rootful socket detection | SC-POD-003 |
| `Podman.captureSystemInfo()` | SIL-2 compliance state capture | SC-CEP-003 |
| `Podman.inspect(id)` | Forensic container inspection | - |
| `Podman.start/stop/remove(id)` | Lifecycle control | SC-CNT-009 |
| `Podman.composeUp/Down(file)` | Stack orchestration | - |
| `Podman.orient(exitCode, stderr)` | Failure diagnosis (125/126/127) | - |

### 2.2 API Layer (`Cepaf.Podman/Api/`)

**Containers.fs**:
- `list(filters)`, `listAll()`, `listRunning()`
- `exists(id)`, `inspect(id)`
- `create()`, `start()`, `stop()`, `restart()`
- `logs()`, `stats()`, `wait()`, `kill()`, `remove()`

**Images.fs**: `list()`, `inspect()`, `pull()`, `push()`, `build()`, `remove()`, `prune()`

**Networks.fs**: `list()`, `create()`, `connect()`, `disconnect()`, `inspect()`, `remove()`

**Volumes.fs**: `list()`, `create()`, `inspect()`, `mount()`, `remove()`, `prune()`

**System.fs**: `info()`, `version()`, `ping()`, `df()`

### 2.3 Health Probes (`Cepaf.Podman/Health/Probes.fs`)

- HTTP endpoint probes with configurable paths
- TCP port connectivity checks
- Log pattern matching for readiness
- **Consensus-based health**: 3/5 checks required
- Timeout handling with circuit breaker

---

## 3. Observability & Telemetry

### 3.1 Quadplex Logger (4 OTEL Modules)

| Channel | Purpose | Output |
|---------|---------|--------|
| Console | Real-time display | ANSI colored terminal |
| File | Audit trail | Append-only logs |
| State | Version tracking | SQLite/DuckDB |
| Telemetry | Distributed streaming | Zenoh pub/sub |

**Interface**:
```fsharp
Info(message) / Warn() / Error() / Debug()
Emit(TelemetryEvent)
IncrementCounter(name, tags)
RecordHistogram(name, value, tags)
SetGauge(name, value)
StartTimer() / StartSpan(id) / EndSpan(id, status)
```

### 3.2 Telemetry Event Types

```fsharp
ProtocolStart/Complete          // Orchestration lifecycle
PhaseStart/Complete             // Phase transitions
TaskUpdate(task)                // Progress tracking
OodaTransition(phase, decision) // Control loop events
AnomalyDetected(desc, severity) // Anomaly alerts
SafetyAuditStarted/Complete     // STAMP audits
PodmanEventObserved             // Container state changes
GuardianValidation              // Safety approvals
GDEProposalGenerated/Validated  // Goal-directed evolution
FractalLogEvent                 // Hierarchical logging
ZenohEvolutionEvent             // Distributed events
```

### 3.3 Fractal Logging (`Observability/Fractal/`)

| Component | Purpose |
|-----------|---------|
| `HLC.fs` | Hybrid Logical Clocks for causality |
| `KeyExpression.fs` | Zenoh-compatible routing patterns |
| `ContentRouter.fs` | Smart message routing |
| `BatchEncoder.fs` | Message compression & batching |
| `PIIMasking.fs` | Sensitive data redaction |
| `WriteFilter.fs` | Pre-publish filtering & rate limiting |
| `OTELIntegration.fs` | OpenTelemetry protocol translation |
| `ZenohFractalPublisher.fs` | Real-time log streaming |

---

## 4. Prajna Cockpit Interface

### 4.1 Bio Layer - Life-Like Structures (`Cockpit/Prajna.fs`)

**Membrane**:
```fsharp
type Permeability = Closed | Selective | Open | Emergency
canPass(config, msgType, source) -> bool
```

**Holon State Machine**:
```
Dormant -> Awakening -> Active -> Stressed -> Healing -> Apoptotic
```

**Operations**:
- `createHolon(id, type, parent)` - Instantiate
- `transitionState(holon, newState)` - State changes
- `checkVitals(holon)` - Health assessment
- `getMessage(holon, msgType)` - Membrane-gated communication

### 4.2 AI Copilot (`Cockpit/AiCopilot.fs`)

**Configuration**:
```fsharp
model: "anthropic/claude-3.5-sonnet"
maxTokens: 500
temperature: 0.3
timeoutMs: 10000
```

**Capabilities**:
- `generateContext(state, focusArea)` - Analysis context creation
- `analyzeMetrics(nodeMetrics)` - Metric interpretation
- `detectAnomalies(data)` - Unusual pattern detection
- `suggestActions(state, severity)` - Recommendation engine
- `predictCapacity(trends)` - Resource forecasting

### 4.3 Guardian Integration (`Cockpit/GuardianIntegration.fs`)

**Pre-Approval Flow**:
```
Prajna.Command -> Guardian.validate(command, actor)
  ├─> Approved: Execute
  ├─> Vetoed(reason): Block + alert
  └─> Modified(plan): Execute modified version
```

**Operations**:
- `validateCommand(cmd, actor, context)` - Constraint checking
- `checkFoundersDirective(action)` - Goal alignment (SC-FOUNDER-*)
- `logApproval(cmd, result)` - Audit trail

### 4.4 Immutable State (`Cockpit/ImmutableState.fs`)

**Block Structure**:
```fsharp
type StateBlock = {
  id: string
  timestamp: DateTimeOffset
  operation: string
  previousHash: string      // SHA3-256 chain
  data: Map<string, obj>
  signature: Ed25519Signature
  protocolVersion: int
}
```

**Operations**:
- `appendBlock(operation, data)` - Immutable write
- `verifyChain()` - Hash chain validation
- `queryHistory(timeRange)` - Historical queries
- `computeMerkleRoot()` - State verification

---

## 5. Mesh Networking & Orchestration

### 5.1 Mesh CLI Commands (`Mesh/MeshCli.fs`)

| Command | Purpose | Equivalent |
|---------|---------|------------|
| `boot [--compose file]` | Start mesh | `sa-up` |
| `shutdown [--graceful]` | Stop mesh | `sa-down` |
| `clean [--remove-volumes]` | Cleanup | `sa-clean` |
| `status [--detailed]` | Show dashboard | `sa-status` |
| `logs [--service] [--follow]` | Stream logs | `sa-logs` |
| `test [--filter pattern]` | Run F# tests | `sa-test` |
| `dashboard [--refresh-ms]` | Interactive TUI | - |
| `supervisor [--cycle-ms]` | OODA biomorphic mode | - |

### 5.2 Health Coordinator (`Mesh/HealthCoordinator.fs`)

**Metrics**:
```fsharp
type ContainerHealthMetrics = {
  ContainerId: string
  Status: Healthy | Degraded | Unhealthy | Unknown | Unreachable
  HealthScore: float          // 0.0-1.0
  CpuUsage: float             // 0.0-100.0
  MemoryUsage: float
  ResponseTimeMs: int64
  LastHeartbeat: DateTime
  ConsecutiveFailures: int
}
```

**Quorum Voting (SIL-6 Biomorphic)**:
- Required quorum: `floor(N/2) + 1`
- Health check interval: 10s (SC-SIL6-001)
- Circuit breaker: 3 consecutive failures
- Split-brain detection -> Apoptosis trigger

### 5.3 OODA Supervisor (`Mesh/OodaSupervisor.fs`)

```
OBSERVE (20ms) -> ORIENT (30ms) -> DECIDE (30ms) -> ACT (20ms)
                                                       |
                 <--------- FEEDBACK ------------------+
```

**Cycle time**: <100ms (SC-BIO-001)

**[Updated Sprint 51]** ScaleUp/ScaleDown actions are fully functional implementations
(no longer placeholders). The OodaSupervisor executes real container scaling via Podman
and agent pool management based on metabolic energy levels.

### 5.4 Digital Twin (`Mesh/DigitalTwin.fs`)

- `createTwin(physicalId)` - Mirror creation
- `syncState(physical, digital)` - Bidirectional sync
- `detectDrift()` - Consistency checking
- `reconcile()` - Realignment
- `forecast(metrics)` - Predictive modeling

---

## 6. Safety & SIL-6 Biomorphic

### 6.1 Simplex Kernel (`Safety/SimplexKernel.fs`)

**Verdict Types**:
```fsharp
type SafetyVerdict =
    | Approved                  // Execute as-is
    | Vetoed of reason: string  // Block + explain
    | Modified of plan: string  // Execute modified version
```

**Operations**:
- `evaluate(command, targetId, state)` -> Verdict
- `checkConstraint(id, data)` -> bool
- `validateConstituents()` -> bool

### 6.2 Federation Protocol (`SIL6/FederationProtocol.fs`)

**Peer Status**:
```fsharp
type PeerStatus = Online | Offline | Upgrading | Degraded | Unknown
```

**Operations**:
- `negotiateVersion(localV, remoteV)` -> compatible?
- `attestPeer(peer)` -> bool (hourly verification)
- `notifyFederationUpgrade()` - Broadcast to peers

### 6.3 Rollback Manager (`SIL6/RollbackManager.fs`)

- `createCheckpoint()` -> checkpointId
- `rollbackTo(checkpointId)` -> Result
- `validateCheckpoint(id)` -> bool
- `pruneOldCheckpoints()` - 24-hour retention

### 6.4 Reed-Solomon Coding (`SIL6/ReedSolomon.fs`)

- `encode(data, parityBlocks)` -> EncodedData
- `decode(encodedData)` -> Result<data>
- `detectErrors(data)` -> bool
- `repairBlock(data, missingIdx)` -> Result

---

## 7. Bridge Integration (Elixir <-> F#)

### 7.1 Port Handler (`Bridge/PortHandler.fs`)

**Message Format (Elixir -> F#)**:
```json
{
  "command": "restart_container",
  "targetId": "container-uuid",
  "context": {"reason": "health_check_failed"}
}
```

**Response Format (F# -> Elixir)**:
```json
{
  "status": "ok | veto | error",
  "reason": "string (optional)"
}
```

**Flow**:
```
Elixir sends JSON
    ↓
PortHandler.handleMessage(json, state)
    ↓
SimplexKernel.evaluate()
    ↓
F# responds with verdict
    ↓
Elixir receives result
```

### 7.2 Zenoh Pub/Sub Keys

| Key Expression | Direction | Content |
|----------------|-----------|---------|
| `indrajaal/telemetry/elixir/**` | Elixir -> F# | Elixir metrics |
| `indrajaal/telemetry/fsharp/**` | F# -> Elixir | F# telemetry |
| `indrajaal/fractal/{l1..l5}/**` | Both | Fractal logs |
| `indrajaal/control/**` | Elixir -> F# | Commands |
| `indrajaal/kpi/**` | Both | KPI metrics |

---

## 8. Cybernetic Agents (`Modules/CyberneticAgents.fs`)

### 8.1 50-Agent Hierarchy

```
1 Executive Agent
├── 10 Domain Supervisors
│   └── Access, Alarms, Analytics, Auth, Compliance,
│       Devices, Integration, Intelligence, Observability, Security
├── 15 Functional Supervisors
│   └── Compile, Test, Quality, Deploy, Monitor, etc.
└── 24 Worker Agents
    └── Task execution
```

### 8.2 Agent Type

```fsharp
type Agent = {
  Id: string
  Name: string
  Level: AgentLevel
  Domain: Domain option
  Status: Idle | Active | Blocked | Failed | Terminated
  TaskQueue: string list
  Efficiency: float<efficiency>  // Must be >90%
  Parent: string option
  Children: string list
}
```

### 8.3 AOR Engine (`Modules/AOREngine.fs`)

**Key Rules**:
- AOR-EXE-001: Executive supremacy
- AOR-QUA-001: Zero warnings mandatory
- AOR-SAF-001: Halt <1s on violation
- AOR-CNT-001: Podman exclusive
- AOR-TEST-001: Compile before commit
- AOR-API-001-007: Rate limit awareness

---

## 9. Practical Agent Operations

### 9.1 Container Management Workflow

```fsharp
// OBSERVE
let podmanState = Podman.captureSystemInfo(logger, runner)
let containers = Containers.listAll(client)

// ORIENT
let health = HealthProbes.check(container)
let impact = ImpactAssessment(health, dependencies)

// DECIDE
if health.Status = Unhealthy then
    let action = RestartContainer(container.Id)

// ACT
let result = Podman.start(logger, runner, container.Id)

// VERIFY
let newHealth = HealthProbes.check(container)
assert (newHealth.Status = Healthy)
```

### 9.2 Safety-Critical Operations

```fsharp
// ALL mutations require Guardian approval
let command = {
    Command = "restart_container"
    TargetId = containerId
    Context = context
}

// Bridge sends to Elixir Guardian
let response = PortHandler.handleMessage(json, systemState)

match response.Status with
| "ok" ->
    executeCommand(command)
    TelemetryPublisher.publishEvent(GuardianValidation(approved=true))
| "veto" ->
    logger.Error(sprintf "Guardian veto: %s" response.Reason.Value)
```

### 9.3 Zenoh Publishing

```fsharp
let session = ZenohSession.createSession(config)

// Publish F# telemetry
session.publish(
    "indrajaal/telemetry/fsharp/metrics",
    JsonSerializer.Serialize({ cpu = 45.0; memory = 60.0 })
)

// Subscribe to Elixir telemetry
session.subscribe(
    "indrajaal/telemetry/elixir/**",
    fun msg -> logger.Info(sprintf "Received: %s" msg.Key)
)
```

---

## 10. STAMP Constraint Compliance

| STAMP ID | Module | Operation | Verification |
|----------|--------|-----------|--------------|
| SC-POD-003 | Podman | Socket verification | `getSocketPath()` |
| SC-CEP-001 | Domain | Artifact locality | Registry validation |
| SC-CNT-009 | Domain | NixOS exclusive | Environment check |
| SC-PRF-050 | HealthCoordinator | <50ms latency | Timeout enforcement |
| SC-OBS-069 | QuadplexLogger | Dual logging | 4 channels active |
| SC-OBS-071 | QuadplexLogger | 4 OTEL modules | ChannelCount check |
| SC-PRAJNA-001 | GuardianIntegration | Pre-approval | `handleMessage()` gate |
| SC-SIL6-001 | HealthCoordinator | 10s health checks | Timer interval |
| SC-SIL6-011 | HealthCoordinator | Quorum calculation | `floor(N/2)+1` |
| SC-BIO-001 | OodaSupervisor | OODA <100ms | Cycle timing |

---

## 11. Entry Points for Agents

### 11.1 Command-Line

```bash
# Main entry: Program.fs main()
cepa --env DEV --build --test --verify
cepa mesh boot              # SIL6 startup
cepa mesh status            # Dashboard
cepa mesh shutdown          # Graceful stop
```

### 11.2 Programmatic

```fsharp
// From Elixir via Port handler
PortHandler.handleMessage(json, systemState)

// From CLI commands
MeshCli.Execute(["boot"; "--compose"; "file.yml"])

// Direct orchestration
Orchestrator.runProtocol(logger, runner, config)
```

### 11.3 Background Services

| Service | Interval | Purpose |
|---------|----------|---------|
| MeshDashboard | 30s | Status refresh |
| OodaSupervisor | 100ms | OODA control loops |
| HealthCoordinator | 10s | Health consensus |
| ZenohSession | Continuous | Pub/sub messaging |
| TelemetryPublisher | Streaming | Event telemetry |

---

## 12. When to Use CEPAF

### Use F# CEPAF for:

1. **Container Operations** - All Podman lifecycle management
2. **Health Consensus** - Distributed health voting and quorum
3. **Safety Validation** - STAMP constraint checking via SimplexKernel
4. **OODA Loops** - Fast 100ms biomorphic control cycles
5. **Federation** - Multi-cluster coordination and attestation
6. **Rollback** - Checkpoint creation and recovery
7. **Zenoh Messaging** - High-performance pub/sub
8. **AI Copilot Queries** - OpenRouter/Anthropic integration
9. **Immutable State** - Blockchain-style audit trail
10. **Dashboard TUI** - Interactive terminal interface

### Use Elixir/Phoenix for:

1. **Web Interface** - Phoenix LiveView pages
2. **Business Logic** - Domain contexts and resources
3. **Database** - PostgreSQL via Ash Framework
4. **Guardian** - Safety approval decisions
5. **Sentinel** - Health monitoring source of truth
6. **REST API** - HTTP endpoints
7. **WebSocket** - Real-time browser updates

---

## Document Control

| Field | Value |
|-------|-------|
| Version | 21.1.0 |
| Created | 2026-01-05 |
| Author | Claude Opus 4.5 |
| STAMP | SC-DOC-001 |
| Lines of F# | 100,000+ |
| Test Suites | 365+ |

---

*This document serves as the authoritative reference for AI agents working with CEPAF F# functionality in the Indrajaal system.*
