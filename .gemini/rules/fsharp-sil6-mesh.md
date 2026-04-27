---
paths:
- lib/cepaf/**/*.fs
- lib/cepaf/**/*.fsproj
- lib/cepaf/artifacts/**/*.yml
- lib/cepaf/scripts/**/*.fsx
---
# F# SIL-6 Mesh Orchestration Rules
# Overview
This rule file governs all F# SIL-6 mesh operations including swarming, observability, cortex integration, and multiverse capabilities.
# Cross-Cutting Constraint References
> SC-NET-001/002, AOR-NET-001: All F# projects MUST target net10.0 — see GEMINI.md §13.0
> SC-FFI-001/002: F# Zenoh FFI tests MUST set LD_LIBRARY_PATH, ZENOH_USE_NATIVE=true — see GEMINI.md §13.0
> SC-CEP-005: All F# orchestration MUST be pre-compiled (no .fsx in production) — see GEMINI.md §13.0
> SC-DBNAME-001 to SC-DBNAME-010: UHI database naming for cross-holon references — see GEMINI.md §5.0
# STAMP Constraints (F# Mesh)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-MESH-001 | SIL6MeshOrchestrator.fsx is unified entry point | CRITICAL |
| SC-MESH-002 | All mesh ops use Digital Twin state management | HIGH |
| SC-MESH-003 | Boot sequence is transactional (rollback on fail) | CRITICAL |
| SC-MESH-004 | Zenoh telemetry mandatory on all nodes (SC-ZENOH-001) | CRITICAL |
| SC-MESH-005 | Quorum voting for health decisions | HIGH |
| SC-MESH-006 | FPPS 5-method consensus for critical checks | HIGH |
| SC-MESH-007 | Checkpoint before shutdown | HIGH |
| SC-MESH-008 | Shadow universe requires explicit approval | MEDIUM |
| SC-MESH-009 | All state changes logged to telemetry | MEDIUM |
| SC-MESH-010 | Graceful degradation before failure | HIGH |
| SC-MESH-011 | Health checks MUST verify Biological Pulse (Zenoh pub/sub) | CRITICAL |
# AOR Rules
> AOR-MESH-001 to AOR-MESH-010 — defined in GEMINI.md §9.0
> Key: Use `sa-up` for mesh ops, checkpoint before shutdown, 2oo3 consensus, FPPS validation, Digital Twin authoritative
# Boot Sequence Stages
```
S0_PREFLIGHT    →  Environment validation, port scouring, cleanup
S1_INFRASTRUCTURE →  DB + Observability containers
S2_ZENOH_MESH   →  Zenoh router + control plane
S3_APP_SEED     →  Application seed node with health wait
S4_HOMEOSTASIS  →  Health check, quorum, Cortex verification
```
# Available Commands
| Command | Description |
|---------|-------------|
| `sa-mesh boot` | Full SIL-6 biomorphic mesh boot sequence |
| `sa-mesh down` | Graceful shutdown with checkpoint |
| `sa-mesh status` | Show Digital Twin + quorum + Zenoh status |
| `sa-mesh-test [type]` | Run tests: obs, cc, mv, zenoh, agents, or all |
| `sa-test-obs` | Test observability stack (OTEL, Prometheus, Grafana, SigNoz) |
| `sa-test-cc` | Test change control (checkpoint/restore) |
| `sa-test-mv` | Test multiverse (shadow universe forking) |
| `sa-test-zenoh` | Test Zenoh router connectivity |
| `sa-test-agents` | Test Zenoh container agents |
| `sa-agents` | Run Zenoh container agent monitoring |
| `sa-control <c> <cmd>` | Control container (start/stop/restart/health/metrics) |
| `sa-checkpoint [name]` | Create state checkpoint |
| `sa-restore [name]` | Restore from checkpoint |
| `sa-fork [name]` | Fork shadow universe for testing |
# Digital Twin State
```fsharp
type DigitalTwin = {
Holons: Dictionary<string, HolonState>    // Node states
FractalState: Map<FractalLayer, bool>     // L0-L7 verification
GlobalHealth: float                        // 0-100%
QuorumStatus: QuorumStatus                 // Achieved/NotAchieved
ZenohMeshActive: bool                      // All nodes connected
CortexConnected: bool                      // F#/Elixir bridge
ObservabilityActive: bool                  // Full stack running
}
```
# Fractal Layers
| Layer | Description | Verified By |
|-------|-------------|-------------|
| L0_Runtime | System compiles and boots | S0_PREFLIGHT |
| L1_Function | I/O contracts valid | Health checks |
| L2_Component | Module cohesion | S1_INFRASTRUCTURE |
| L3_Holon | Agent logic sound | S2_ZENOH_MESH |
| L4_Container | Isolation maintained | S3_APP_SEED |
| L5_Node | Runtime stable | S3_APP_SEED |
| L6_Cluster | Consensus holds | S4_HOMEOSTASIS |
| L7_Federation | Global invariants | S4_HOMEOSTASIS |
# Observability Stack
| Component | Port | Purpose |
|-----------|------|---------|
| OTEL Collector | 4317, 4318 | Telemetry ingestion |
| Prometheus | 9090 | Metrics storage |
| Grafana | 3000 | Visualization |
| Loki | 3100 | Log aggregation |
| Zenoh Router | 7447 | Real-time pub/sub |
# Change Control Workflow
```
1. Create checkpoint before risky operation
$ sa-checkpoint pre-upgrade
2. Perform operation
$ sa-mesh down && sa-mesh boot
3. On failure, restore checkpoint
$ sa-restore pre-upgrade-20260110-123456
4. For testing, fork shadow universe
$ sa-fork experiment-1
```
# Multiverse Capability
Shadow universes allow isolated testing:
- Fork from any checkpoint
- Isolated container instances
- No impact on production state
- Requires Guardian approval per SC-UCR-011
# 5-Order Effects (Mesh Boot)
| Order | Effect |
|-------|--------|
| 1st | Containers start, ports bound |
| 2nd | Health checks pass, Zenoh mesh forms |
| 3rd | Quorum achieved, cluster consensus |
| 4th | Services available, tests runnable |
| 5th | GA deployable, production ready |
# Integration Points
# Elixir Backend
- Health endpoint: `http://localhost:4000/api/health`
- Guardian API: `http://localhost:4000/api/prajna/guardian/*`
- Sentinel API: `http://localhost:4000/api/prajna/sentinel/*`
# Zenoh Telemetry
- Health topic: `indrajaal/mesh/health`
- Metrics topic: `indrajaal/container/{name}/metrics`
- Control topic: `indrajaal/mesh/control`
# Zenoh Container Agents (SC-ZENOH-010 to SC-ZENOH-015)
Each container has a Zenoh agent that publishes state and accepts control commands.
# Topic Patterns
| Topic Pattern | Purpose |
|---------------|---------|
| `indrajaal/container/{name}/health` | Container health status (JSON) |
| `indrajaal/container/{name}/metrics` | CPU, memory, network metrics |
| `indrajaal/container/{name}/control` | Control commands (published on execution) |
| `indrajaal/container/{name}/state` | Full container state snapshot |
| `indrajaal/container/{name}/alerts` | Alert notifications |
# Container State Model
```fsharp
type ContainerState = {
Name: string        // Container name
Status: string      // running, stopped, paused
Health: string      // healthy, unhealthy, starting
Uptime: string      // Duration since start
CpuPercent: float   // CPU usage percentage
MemoryMB: int       // Memory usage in MB
NetworkRx: int64    // Network bytes received
NetworkTx: int64    // Network bytes transmitted
LastCheck: DateTime // Last health check time
}
```
# Control Commands
| Command | Description |
|---------|-------------|
| `Start` | Start container |
| `Stop` | Stop container |
| `Restart` | Restart container |
| `Pause` | Pause container |
| `Resume` | Resume paused container |
| `HealthCheck` | Trigger health check and publish status |
| `GetMetrics` | Publish current metrics |
| `GetState` | Publish full state snapshot |
# Usage Examples
```bash
# Monitor all containers
sa-agents
# Control specific container
sa-control indrajaal-db-prod health
sa-control indrajaal-ex-app-1 restart
sa-control indrajaal-obs-prod metrics
# Test Zenoh agents
sa-test-agents
```
# STAMP Constraints (Zenoh Agents)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ZENOH-010 | Container agents publish health every 30s | HIGH |
| SC-ZENOH-011 | Control commands logged to telemetry | MEDIUM |
| SC-ZENOH-012 | Unhealthy containers trigger alerts | HIGH |
| SC-ZENOH-013 | Metrics include CPU, memory, network | MEDIUM |
| SC-ZENOH-014 | State snapshots include full container info | MEDIUM |
| SC-ZENOH-015 | All agent operations are non-blocking | HIGH |
# Error Handling
```
Boot failure → Rollback to previous state
Zenoh disconnect → Retry with exponential backoff
Health degradation → Alert, graceful degradation
Quorum lost → Apoptosis trigger condition
```
# Smoke Test Zenoh Messaging (SC-ZTEST-*)
The `SmokeTestPublisher.fs` module provides Zenoh checkpoint messaging for smoke tests, replacing log-based verification with <100ms real-time feedback.
# Checkpoint IDs
| Checkpoint | ID | Description |
|------------|-----|-------------|
| Batch Start | CP-SMOKE-01 | Smoke test batch starting |
| API Complete | CP-SMOKE-02 | API endpoint tests complete |
| Database Complete | CP-SMOKE-03 | Database consistency tests complete |
| Zenoh Complete | CP-SMOKE-04 | Zenoh connectivity tests complete |
| Performance Complete | CP-SMOKE-05 | Performance baseline tests complete |
| Security Complete | CP-SMOKE-06 | Security validation tests complete |
| Resilience Complete | CP-SMOKE-07 | Resilience tests complete |
| All Complete | CP-SMOKE-08 | All smoke tests finished |
# Topic Patterns
```
indrajaal/smoke/
├── batch/{batchId}/start      # Batch starting
├── batch/{batchId}/progress   # Progress updates
├── batch/{batchId}/complete   # Batch complete
├── node/{nodeId}/result       # Per-node summary
├── category/{cat}/complete    # Category completion
├── test/{testId}/result       # Individual test result
└── summary                    # Overall summary
```
# STAMP Constraints (Smoke Test Messaging)
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ZTEST-001 | All checkpoints MUST have unique topic | CRITICAL |
| SC-ZTEST-002 | Messages MUST include checkpoint ID | CRITICAL |
| SC-ZTEST-003 | Publish latency < 10ms per message | HIGH |
| SC-ZTEST-004 | Publisher MUST be non-blocking (async) | CRITICAL |
| SC-ZTEST-005 | Orchestrator aggregate update < 100ms | HIGH |
| SC-ZTEST-006 | Boot checkpoints MUST include state vector | HIGH |
| SC-ZTEST-007 | Test failures MUST include full context (evidence + details) | HIGH |
| SC-ZTEST-008 | No log parsing for test results - pure Zenoh pub/sub | CRITICAL |
# AOR Rules (Smoke Test Publishing)
| ID | Rule |
|----|------|
| AOR-ZTEST-001 | Use SmokeTestOrchestrator.createState() to initialize test batch |
| AOR-ZTEST-002 | Record every test result with recordResult() |
| AOR-ZTEST-003 | Publish completion message via Zenoh at batch end |
| AOR-ZTEST-004 | Include evidence list in all test results |
| AOR-ZTEST-005 | Use printSummary() for console output |
# Usage Pattern
```fsharp
open Cepaf.Mesh
// Initialize
let state = SmokeTestOrchestrator.createState "indrajaal-ex-app-1"
// Record results
let result = SmokeTestPublisher.createTestResult
"API-001" API P0_Critical Passed 45L
"HTTP 200 OK" ["HTTP 200"; "JSON valid"] None
SmokeTestOrchestrator.recordResult state result
// Completion
let summary = SmokeTestOrchestrator.getCompletionMessage state
// Publish to: indrajaal/smoke/batch/{batchId}/complete
SmokeTestOrchestrator.printSummary state
```
# Related Documents
- `lib/cepaf/scripts/SIL6MeshOrchestrator.fsx` - Main orchestrator
- `lib/cepaf/src/Cepaf/Mesh/*.fs` - Core mesh modules
- `lib/cepaf/src/Cepaf/Mesh/SmokeTestPublisher.fs` - Smoke test Zenoh publisher
- `lib/cepaf/src/Cepaf/Mesh/SIL6BiomorphicOrchestrator.fs` - Unified SIL-6 orchestrator
- `lib/cepaf/src/Cepaf/Mesh/ZenohCheckpoints.fs` - Boot checkpoint messaging
- `.gemini/rules/zenoh-telemetry-mandatory.md` - Zenoh constraints
- `GEMINI.md` - Master system specification