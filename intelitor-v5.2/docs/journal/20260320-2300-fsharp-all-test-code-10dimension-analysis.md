# F# Complete Test Codebase — Exhaustive 10-Dimension Analysis

**Date**: 2026-03-20 23:00 CEST
**Author**: Claude Opus 4.6
**Scope**: ALL F# test code across both test projects (Cepaf.Tests + Cepaf.IndrajaalTest)
**Predecessor**: `20260320-2200-fsharp-test-infrastructure-detailed-analysis.md` (covers TestAgent/RegressionRunner/PrometheusGate only)
**STAMP**: SC-TEST-001, SC-FFI-001, SC-FSH-030, SC-COV-004, SC-PROM-001, SC-ZTEST-*, SC-SYNC-PLAN-*, SC-VER-*, SC-CLI-*, SC-HMI-*, SC-BOOT-*, SC-AGT-*, SC-NAT-*, SC-MCP-TEST-*

---

## Inventory Summary

| Project | Active Files | LOC | Tests | Status |
|---------|-------------|-----|-------|--------|
| **Cepaf.Tests** | 40 (6 excluded) | ~13,500 | ~1,050+ | Primary |
| **Cepaf.IndrajaalTest** | 24 (incl. types/config/clients) | ~3,400 | ~180+ | Requires live app |
| **Total** | **64 active** | **~16,900** | **~1,230+** | |

### Cepaf.Tests — File Inventory (40 active files)

| File | LOC | Tests | Category | STAMP |
|------|-----|-------|----------|-------|
| `RopTests.fs` | 60 | 6 | Core/L1 | — |
| `OodaTests.fs` | 36 | 4 | Core/L1 | SC-OODA-001 |
| `OodaControllerTests.fs` | 161 | 24 | Core/L1 | SC-OODA-001 |
| `ConstraintsTests.fs` | 220 | 20 | Core/L1 | SC-VAL, SC-CNT, SC-AGT, SC-PRF |
| `PhicsTests.fs` | 204 | 24 | Core/L1 | SC-PRF-050 |
| `CyberneticAgentsTests.fs` | 387 | 30+ | Core/L1 | SC-AGT-017/018/019 |
| `BuilderTests.fs` | 70 | 2 | Core/L1 | SC-CNT-009 |
| `OrchestratorTests.fs` | 64 | 1 | Core/L3 | — |
| `CockpitTUITests.fs` | 483 | 42 | Cockpit/L1 | SC-HMI-001 |
| `FormalVerificationTests.fs` | 667 | 31 | Verification/L1 | SC-VER-* |
| `Unit/Core/ZenohFfiBridgeTests.fs` | 671 | 31 | Zenoh/L1 | SC-ZENOH-FFI-001..025 |
| `Unit/Core/ZenohNativeLifecycleTests.fs` | 574 | 21 | Zenoh/L1 | SC-NAT-001..004, SC-SESS-005 |
| `Unit/Core/ZenohFfiPerformanceTests.fs` | 407 | 17 | Zenoh/L4 | SC-ZTEST-003 |
| `Unit/Observability/OTELIntegrationTests.fs` | 267 | 28 | Observability/L1 | SC-OBS-071 |
| `Unit/Observability/HLCTests.fs` | 261 | 23 | Observability/L1 | — |
| `Unit/Cockpit/ThemeSimulatorTests.fs` | 679 | 89 | Cockpit/L1 | SC-HMI-* |
| `Unit/Mesh/DAGTests.fs` | 469 | 25 | Mesh/L1 | SC-BOOT-008 |
| `Unit/Mesh/FSMTests.fs` | 467 | 33 | Mesh/L1 | SC-BOOT-014 |
| `Unit/Mesh/CPMTests.fs` | 378 | 20 | Mesh/L1 | SC-BOOT-005 |
| `Unit/Mesh/HysteresisTests.fs` | 571 | 26 | Mesh/L1 | SC-OPT-002 |
| `Unit/Mesh/MathematicalSystemMonitorTests.fs` | 437 | 49 | Mesh/L1 | SC-AI-003, SC-PROM-001 |
| `Module/ZenohChannelTests.fs` | 236 | 20 | Zenoh/L2 | — |
| `Integration/ZenohElixirIntegrationTests.fs` | 1293 | 42 | Zenoh/L3 | SC-ZENOH-010..015 |
| `Performance/ZenohPerformanceTests.fs` | 807 | 20 | Zenoh/L4 | SC-PRF-050 |
| `Core/FSharpCapabilityTests.fs` | 661 | 75 | Core/L1 | SC-FSH-003/004/010/011 |
| `BDD/SpecFlowConfig.fs` | 294 | 0 | BDD/Framework | SC-COV-004 |
| `BDD/TestEvolutionSteps.fs` | 390 | 4 | BDD/L5 | SC-TEST-EVO-001..007 |
| `Unit/Planning/PlanningSyncTests.fs` | 793 | 100+ | Planning/L1 | SC-SYNC-PLAN-001..020 |
| `Unit/Testing/TestAgentTests.fs` | 192 | 25 | Testing/L1 | SC-MCP-TEST-001..004 |
| `Unit/Testing/TestToolsTests.fs` | 74 | 8 | Testing/L1 | SC-MCP-TEST-001 |
| `Unit/Testing/RegressionRunnerAsyncTests.fs` | 204 | 16 | Testing/L1 | SC-MCP-TEST-002 |
| `Unit/Testing/TestToolsLogsTests.fs` | 141 | 12 | Testing/L1 | SC-ZTEST-003, SC-ZTEST-008 |
| `Unit/Testing/PrometheusGateTests.fs` | 179 | 19 | Testing/L1 | SC-PROM-001, SC-PROM-004 |
| `Verification/SevenLevelFractalVerification.fs` | 942 | 5 (wrapping ~18 constraints) | Verification/L0-L7 | SC-VER-001..080 |
| `CockpitFCliTestPlan.fs` | 939 | 101 | CLI/L1-L7 | SC-CLI-001..008 |
| `UltimateFractalSystemTestPlan.fs` | 1209 | 202+ | System/L0-L7 | All SC-* families |
| `Program.fs` | 128 | 2 | Entry point | — |

### Cepaf.IndrajaalTest — File Inventory (24 files)

| File | LOC | Tests | Category |
|------|-----|-------|----------|
| `Types.fs` | 326 | — | Type definitions (19 categories) |
| `Config.fs` | 283 | — | ServerConfig, 50+ endpoints |
| `HttpClient.fs` | 319 | — | Auth-aware HTTP client |
| `SimplifiedTypes.fs` | 253 | — | Alternative type definitions |
| `SimplifiedHttpClient.fs` | 206 | — | Alternative HTTP client |
| `ZenohClient.fs` | 417 | — | Zenoh pub/sub via HTTP REST |
| `TestReporter.fs` | 304 | — | Serilog + ANSI reports |
| `WebSocketClient.fs` | 355 | — | Phoenix WebSocket protocol |
| `HealthTests.fs` | 272 | 15 | Health endpoints (p99 <100ms) |
| `AuthTests.fs` | 383 | 18 | Auth + security (SQLi, XSS) |
| `AlarmApiTests.fs` | ~200 | ~15 | Alarm CRUD |
| `DeviceApiTests.fs` | ~200 | ~15 | Device CRUD |
| `SiteApiTests.fs` | ~200 | ~15 | Site CRUD |
| `VideoApiTests.fs` | ~200 | ~10 | Video streams |
| `ConfigApiTests.fs` | ~150 | ~10 | Config API |
| `BatchApiTests.fs` | ~150 | ~10 | Batch operations |
| `AnalyticsApiTests.fs` | ~200 | ~15 | Analytics endpoints |
| `WebSocketTests.fs` | ~250 | ~12 | WebSocket protocol |
| `ChannelTests.fs` | ~200 | ~10 | Phoenix channels |
| `LiveViewTests.fs` | ~200 | ~8 | LiveView interaction |
| `IntegrationTests.fs` | ~250 | ~15 | Cross-domain flows |
| `SimplifiedTests.fs` | ~150 | ~10 | Simplified API |
| `ZenohTests.fs` | ~200 | ~10 | Zenoh key expressions |
| `Program.fs` / `SimplifiedProgram.fs` | 214 / 107 | — | Entry points |

### Excluded Files (6 — commented out of .fsproj)

| File | Reason |
|------|--------|
| `CockpitUIComponentTests.fs` | Material3/SituationalAwareness refactoring |
| `CockpitZenohTests.fs` | Same module refactoring |
| `PrajnaTests.fs` | Module refactoring needed |
| `ComprehensiveTestFramework.fs` | Module refactoring needed |
| `FractalRuntimeTestPlan.fs` | Fractal module refactoring |
| `ThemeSystemTests.fs` | Theme system module refactoring |

---

## Dimension 1: Control Plane

### 1.1 Test Execution Hierarchy

```
dotnet run --project Cepaf.Tests.fsproj -- [args]
    │  Standalone EXE (Expecto runner)
    ▼
Program.fs: runTestsWithCLIArgs [] args (testList "All Tests" [...])
    │  ~50 test list values explicitly wired
    ▼
Expecto.Tests parallel engine
    │  Parallel by default, sequential for testSequenced
    ├──▶ Unit tests (testCase, test "..." { })
    ├──▶ Async tests (testCaseAsync, testAsync)
    ├──▶ Property tests (testProperty + FsCheck 3.x)
    ├──▶ Sequenced tests (testSequenced for mutable state)
    └──▶ BDD scenarios (custom Given/When/Then DSL)

dotnet run --project Cepaf.IndrajaalTest.fsproj -- [--dev|--staging]
    │  Standalone EXE with auth handshake
    ▼
Program.fs: login → build test suites → runTestsWithCLIArgs
    │  parallel=true, parallelWorkers=4, stressMemoryLimit=0.8
    ├──▶ Health tests (HTTP probes)
    ├──▶ Auth tests (JWT + security injection)
    ├──▶ API tests (CRUD per domain)
    ├──▶ WebSocket tests (Phoenix protocol)
    ├──▶ Channel tests (topic pub/sub)
    ├──▶ LiveView tests (stateful UI)
    └──▶ Integration tests (cross-domain flows)
```

### 1.2 Control Channels

| Signal | Direction | Mechanism | Files |
|--------|-----------|-----------|-------|
| **Test discovery** | Manual → Program.fs | Explicit wiring of testList values | Program.fs |
| **Filter** | CLI → Expecto | `--filter-test-list`, `--filter-test-case`, `--filter` | All |
| **Parallel control** | Config → Expecto | `parallel=true`, `parallelWorkers=4` | IndrajaalTest Program.fs |
| **Sequential override** | Per-test | `testSequenced` wrapper | ZenohChannelTests.fs |
| **Stress limit** | Config → CLR | `stressMemoryLimit=0.8` | IndrajaalTest Program.fs |
| **Skip/offline** | Runtime → test | `skipIfOffline` pattern | IndrajaalTest (all API tests) |
| **BDD dispatch** | Regex → handler | `StepDefinition.Pattern` match | BDD/TestEvolutionSteps.fs |
| **Bash execution** | Test → OS | `Process.Start("bash", ...)` | SevenLevelFractalVerification.fs |
| **Mock injection** | Constructor → test | `MockZenohSession`, `PerformanceMockSession` | Integration, Performance tests |

### 1.3 Three Control Domains

**Domain A — Pure Unit Tests** (DAG, FSM, CPM, Hysteresis, HLC, OODA, Constraints, ROP, Capabilities)
- No external dependencies
- Pure function input→output verification
- FsCheck property-based generators for exhaustive coverage
- Deterministic, hermetic, fast (<100ms per test)

**Domain B — Mock-Based Integration** (ZenohElixirIntegration, ZenohPerformance, ZenohChannel)
- Self-contained `MockZenohSession` with `ConcurrentQueue<string * string>`
- `PerformanceMockSession` with throttling, queue depth, memory measurement
- Simulated pub/sub roundtrips without real Zenoh
- `testSequenced` for mutable state tests

**Domain C — Live System Tests** (SevenLevelFractalVerification, IndrajaalTest)
- Requires running processes (Elixir app, PostgreSQL, Zenoh router, containers)
- Spawns real OS subprocesses (`bash -c "mix compile"`, HTTP requests)
- Environment variable dependent (`LD_LIBRARY_PATH`, `SKIP_ZENOH_NIF`, `PATIENT_MODE`)
- Non-deterministic, environment-sensitive, slow (seconds to minutes)

### 1.4 Registration Control Flow (Critical F# Specificity)

Adding a test requires changes in **three places**:

1. **`.fsproj`** — add `<Compile Include="path/NewTests.fs" />` in correct dependency order
2. **Test file** — export `[<Tests>] let allTests = testList "Name" [...]`
3. **`Program.fs`** — add `Namespace.Module.allTests` to the composite test list

Missing any step silently excludes tests. There is no auto-discovery across files.

**Risk**: `UltimateFractalSystemTestPlan.fs` is compiled (in `.fsproj`) but NOT registered in `Program.fs` — its 202+ tests never execute in the main test run.

---

## Dimension 2: Code Organization

### 2.1 Directory Structure (Cepaf.Tests)

```
lib/cepaf/test/Cepaf.Tests/
├── Program.fs                          # Entry point (128 LOC, MUST BE LAST)
├── Core/                               # F# language capability tests
│   └── FSharpCapabilityTests.fs        # Units, Active Patterns, Composition (661 LOC)
├── Unit/                               # Pure unit tests (L1)
│   ├── Core/                           # Zenoh FFI bridge tests
│   │   ├── ZenohFfiBridgeTests.fs      # 31 tests, 12 formal invariants (671 LOC)
│   │   ├── ZenohNativeLifecycleTests.fs # SafeSession/Publisher/Subscriber (574 LOC)
│   │   └── ZenohFfiPerformanceTests.fs # Benchmarks, P99 percentiles (407 LOC)
│   ├── Observability/
│   │   ├── OTELIntegrationTests.fs     # TracerProvider, W3C traceparent (267 LOC)
│   │   └── HLCTests.fs                # Hybrid Logical Clock (261 LOC)
│   ├── Cockpit/
│   │   └── ThemeSimulatorTests.fs      # 89 tests, ARM safety (679 LOC)
│   ├── Mesh/                           # SIL-6 boot infrastructure
│   │   ├── DAGTests.fs                 # Kahn's algorithm, wave grouping (469 LOC)
│   │   ├── FSMTests.fs                 # Container state machine (467 LOC)
│   │   ├── CPMTests.fs                 # Critical Path Method (378 LOC)
│   │   ├── HysteresisTests.fs          # Health debouncing (571 LOC)
│   │   └── MathematicalSystemMonitorTests.fs # 17 disciplines (437 LOC)
│   ├── Planning/
│   │   └── PlanningSyncTests.fs        # Planning↔Chaya sync (793 LOC)
│   └── Testing/                        # MCP test infrastructure
│       ├── TestAgentTests.fs           # Actor lifecycle (192 LOC)
│       ├── TestToolsTests.fs           # MCP dispatch (74 LOC)
│       ├── RegressionRunnerAsyncTests.fs # CancellationToken (204 LOC)
│       ├── TestToolsLogsTests.fs       # Log buffer (141 LOC)
│       └── PrometheusGateTests.fs      # Proof tokens, DAG (179 LOC)
├── Module/                             # Module interaction tests (L2)
│   └── ZenohChannelTests.fs            # Channel write/filter/flush (236 LOC)
├── Integration/                        # Cross-system tests (L3)
│   └── ZenohElixirIntegrationTests.fs  # 12 test groups, MockSession (1293 LOC)
├── Performance/                        # Benchmark tests (L4)
│   └── ZenohPerformanceTests.fs        # Latency, throughput, memory (807 LOC)
├── BDD/                                # Gherkin-style tests (L5)
│   ├── SpecFlowConfig.fs               # BDD framework (294 LOC)
│   └── TestEvolutionSteps.fs           # OODA evolution steps (390 LOC)
├── Verification/                       # 7-level fractal verification
│   └── SevenLevelFractalVerification.fs # L0-L7 bash execution (942 LOC)
├── CockpitTUITests.fs                  # TUI rendering, golden files (483 LOC)
├── FormalVerificationTests.fs          # Mathematica/Quint/Agda DSL (667 LOC)
├── ConstraintsTests.fs                 # STAMP data models (220 LOC)
├── CyberneticAgentsTests.fs            # 50-agent hierarchy (387 LOC)
├── OodaTests.fs / OodaControllerTests.fs # OODA loop (36 + 161 LOC)
├── RopTests.fs                         # Railway-oriented programming (60 LOC)
├── PhicsTests.fs                       # PHICS latency monitoring (204 LOC)
├── BuilderTests.fs / OrchestratorTests.fs # Container build (70 + 64 LOC)
├── CockpitFCliTestPlan.fs              # CLI 7-level plan (939 LOC)
└── UltimateFractalSystemTestPlan.fs    # Ultimate system plan (1209 LOC)
```

### 2.2 Directory Structure (Cepaf.IndrajaalTest)

```
lib/cepaf/test/Cepaf.IndrajaalTest/
├── Program.fs / SimplifiedProgram.fs   # Two entry points (214 + 107 LOC)
├── Types.fs / SimplifiedTypes.fs       # Two type systems (326 + 253 LOC)
├── Config.fs                           # Server config, endpoints (283 LOC)
├── HttpClient.fs / SimplifiedHttpClient.fs # Two HTTP clients (319 + 206 LOC)
├── ZenohClient.fs                      # Zenoh REST + fractal keys (417 LOC)
├── TestReporter.fs                     # Serilog + ANSI + JSON/MD (304 LOC)
├── WebSocketClient.fs                  # Phoenix WS protocol (355 LOC)
├── HealthTests.fs                      # Health probes (272 LOC)
├── AuthTests.fs                        # Auth + security (383 LOC)
├── [Domain]ApiTests.fs × 6             # CRUD per domain (~200 LOC each)
├── WebSocketTests.fs                   # WS protocol tests (~250 LOC)
├── ChannelTests.fs                     # Phoenix channels (~200 LOC)
├── LiveViewTests.fs                    # LiveView interaction (~200 LOC)
├── IntegrationTests.fs                 # Cross-domain flows (~250 LOC)
└── ZenohTests.fs                       # Zenoh key expressions (~200 LOC)
```

### 2.3 LOC Distribution by Category

| Category | LOC | % | Files |
|----------|-----|---|-------|
| **Zenoh/FFI** | 4,188 | 24.8% | 6 files (Bridge, Lifecycle, Perf, Channel, Integration, ZenohPerf) |
| **Mesh/Boot** | 2,322 | 13.7% | 5 files (DAG, FSM, CPM, Hysteresis, MathMonitor) |
| **Verification/Plans** | 3,757 | 22.2% | 4 files (SevenLevel, FormalVerif, CockpitCLI, Ultimate) |
| **Cockpit/UI** | 1,162 | 6.9% | 2 files (TUI, ThemeSimulator) |
| **Core/OODA** | 1,122 | 6.6% | 6 files (ROP, OODA, OODACtrl, Constraints, PHICS, Capabilities) |
| **Planning/Sync** | 793 | 4.7% | 1 file (PlanningSyncTests) |
| **Testing/MCP** | 790 | 4.7% | 5 files (Agent, Tools, Runner, Logs, Prometheus) |
| **BDD** | 684 | 4.0% | 2 files (SpecFlowConfig, TestEvolution) |
| **Observability** | 528 | 3.1% | 2 files (OTEL, HLC) |
| **Container** | 521 | 3.1% | 3 files (Builder, Orchestrator, CyberneticAgents) |
| **IndrajaalTest** | ~3,400 | — | 24 files (separate project) |
| **Entry Points** | 449 | 2.7% | 3 files (Program.fs × 2, SimplifiedProgram) |

### 2.4 Namespace Organization

```
Cepaf.Tests (root namespace)
├── ProgramTests (inline in Program.fs)
├── BuilderTests
├── OrchestratorTests
├── CockpitTUITests
├── Unit.Core.ZenohFfiBridgeTests
├── Unit.Core.ZenohNativeLifecycleTests
├── Unit.Core.ZenohFfiPerformanceTests
├── Unit.Observability.OTELIntegrationTests
├── Unit.Observability.HLCTests
├── Unit.Cockpit.ThemeSimulatorTests
├── Unit.Mesh.{DAG,FSM,CPM,Hysteresis,MathematicalSystemMonitor}Tests
├── Unit.Planning.PlanningSyncTests
├── Unit.Testing.{TestAgent,TestTools,RegressionRunnerAsync,TestToolsLogs,PrometheusGate}Tests
├── Module.ZenohChannelTests
├── Integration.ZenohElixirIntegrationTests
├── Performance.ZenohPerformanceTests
├── Core.FSharpCapabilityTests
├── BDD.{SpecFlowConfig,TestEvolutionSteps}
└── Verification.ExpectoTests

Cepaf.IndrajaalTest (separate namespace)
├── Types / SimplifiedTypes (COLLISION: same namespace)
├── HttpClient / SimplifiedHttpClient (COLLISION: same namespace)
├── Config
├── ZenohClient
├── TestReporter
├── WebSocketClient
├── HealthTests, AuthTests, *ApiTests, WebSocketTests, etc.
└── Program / SimplifiedProgram
```

**Namespace collision note**: `Types.fs` and `SimplifiedTypes.fs` both declare `Cepaf.IndrajaalTest.Types`. The `.fsproj` only includes `SimplifiedTypes.fs` and `SimplifiedHttpClient.fs` — the originals are compiled but superseded by the simplified versions in the Compile list.

### 2.5 Module Coupling Analysis

| Module | Depends On | Depended By | Coupling |
|--------|-----------|-------------|----------|
| RopTests | Cepaf.Operations (AsyncResult) | None | LOW |
| OodaTests | Cepaf.Ooda (classify) | None | LOW |
| ZenohFfiBridgeTests | Cepaf.Zenoh.Core.ZenohFfiBridge | None | MEDIUM (13 FFI functions) |
| ZenohElixirIntegrationTests | Self-contained MockZenohSession | None | ISOLATED |
| ZenohPerformanceTests | Self-contained PerformanceMockSession | None | ISOLATED |
| PlanningSyncTests | Cepaf.Planning.DomainHelpers | None | MEDIUM |
| SevenLevelFractalVerification | OS subprocesses (bash) | None | HIGH (env-dependent) |
| TestAgentTests | Cepaf.Testing.TestAgent types only | None | LOW (type-only) |
| ThemeSimulatorTests | Cepaf.Cockpit (theme types) | None | MEDIUM |
| IndrajaalTest (all) | Live HTTP server | None | HIGH (external) |

---

## Dimension 3: Data Plane

### 3.1 Data Categories Across Test Code

| Category | Data Shape | Source | Volume | Storage |
|----------|-----------|--------|--------|---------|
| **Test inputs** | Record literals, DU constructors, FsCheck generators | In-code | KB | None (ephemeral) |
| **Assertions** | `Expect.equal actual expected "msg"` | In-code | Per-test | None |
| **Mock messages** | `(topic: string, payload: string)` tuples | ConcurrentQueue | ~100 per test | In-memory |
| **Performance measurements** | `Stopwatch.ElapsedMilliseconds`, `GC.GetTotalMemory` | Runtime | Per benchmark | Console output |
| **State machines** | FSM states, DAG nodes, CPM paths | Constructed in test | ~10-50 nodes | Ephemeral |
| **BDD context** | `Map<string, obj>` (mutable bag) | ScenarioContext | ~10 entries | Per-scenario |
| **Golden files** | TUI rendering snapshots | String comparison | ~500 chars each | In-code constants |
| **HTTP responses** | `HttpResponseMessage`, JSON bodies | Live server | ~1-10KB | Deserialized records |
| **WebSocket frames** | `PhoenixMessage` (JSON over WS) | Live server | ~100 bytes each | In-memory |
| **Subprocess output** | stdout/stderr strings | OS processes | ~1KB-1MB | Captured strings |
| **Proof tokens** | HMAC-SHA256 signed token records | Generated | ~200 bytes | Ephemeral |
| **State vectors** | `int array` (5-6 elements) | Constructed | ~40 bytes | Ephemeral |
| **Health assessments** | `HealthAssessment` record (score, disciplines, interactions) | MathMonitor | ~2KB | Ephemeral |
| **Zenoh key expressions** | `string` (topic paths) | Constants | ~50 bytes each | In-code |
| **Planning tasks** | `ChayaTask` records (id, title, status, priority) | Constructed | ~500 bytes each | Ephemeral |

### 3.2 FsCheck Generator Data Flows

| Generator | Type | Constraints | Used In |
|-----------|------|-------------|---------|
| `dagNodeGen` | `Gen<DagNode>` | duration 100-5000, wave 0-10, Criticality DU | DAGTests |
| `acyclicDagGen` | `Gen<DagNode list>` | 2-8 nodes, deps only reference earlier nodes | DAGTests |
| `containerStateGen` | `Gen<ContainerState>` | All FSM states equally weighted | FSMTests |
| `healthSampleGen` | `Gen<bool>` | True/False for healthy/unhealthy | HysteresisTests |
| `levelGen` | `Gen<int>` | 1-5 range | PrometheusGateTests |
| `commandGen` | `Gen<CliCommand>` | 69 DU cases | CockpitFCliTestPlan |
| `agentStateGen` | `Gen<AgentState>` | 4 DU states | CockpitTUITests |

### 3.3 Mock Architecture (Self-Contained Integration Testing)

**MockZenohSession** (`ZenohElixirIntegrationTests.fs`):
```
┌─────────────────────────────────────────┐
│ MockZenohSession                        │
│                                         │
│  MessageQueue: ConcurrentQueue<topic*payload>  │
│  Subscribers: Dictionary<topic, handler>       │
│  Connected: bool                               │
│                                         │
│  Publish(topic, payload) → enqueue      │
│  Subscribe(topic, handler) → register   │
│  FlushMessages() → deliver queued msgs  │
│  Close() → clear all                    │
└─────────────────────────────────────────┘
```

- 42 integration tests use this mock exclusively
- No real Zenoh connection required
- Supports concurrent publish/subscribe simulation
- Queue-based delivery simulates async behavior

**PerformanceMockSession** (`ZenohPerformanceTests.fs`):
```
┌─────────────────────────────────────────┐
│ PerformanceMockSession                  │
│                                         │
│  QueueDepth: int (throttling control)   │
│  LatencyMs: int (simulated delay)       │
│  Messages: ConcurrentQueue              │
│  MemoryBaseline: long                   │
│                                         │
│  Publish(topic, payload) → delay+enqueue │
│  GetQueueDepth() → backpressure signal  │
│  GetMemoryDelta() → memory growth       │
└─────────────────────────────────────────┘
```

- 20 performance tests use this mock
- Simulates throttling, backpressure, memory growth
- Allows deterministic latency measurement without Zenoh

### 3.4 Data Transformation Pipelines

**Pipeline 1 — OODA Error Classification**:
```
Exception input → classify (Active Pattern) → (Transient|Recoverable|Fatal, Network|Resource|Safety|Config, Critical|High|Medium)
```

**Pipeline 2 — Planning Sync**:
```
PlanningTask → convertToChayaTask → ChayaTask (bijective status: Pending↔todo, InProgress↔in_progress, Completed↔done)
```

**Pipeline 3 — DAG Topological Sort**:
```
DagNode list → topoSort (Kahn's) → Result<sorted list, CycleDetected> → wave grouping → critical path
```

**Pipeline 4 — HLC Timestamp**:
```
HLC.now() → {PhysicalTime: int64; LogicalCounter: int; NodeId: int} → toBytes → fromBytes → compare
```

**Pipeline 5 — MathematicalSystemMonitor Health**:
```
17 disciplines → maturityBase score → rpnPenalty → gapPenalty → healthScore = base - rpen - gpen → HealthAssessment
```

**Pipeline 6 — PrometheusGate Verification**:
```
(levels, timeout, isRunning, hasEmptyLevels) → 4-stage validation → Result<ProofToken, string>
```

### 3.5 Data Retention

All test data is ephemeral within the test process. No test writes persistent state. The SQLite databases referenced in source code (RegressionTracker) are in the **source under test**, not the test code itself.

Exception: `SevenLevelFractalVerification.fs` spawns bash subprocesses that may modify filesystem state (compilation artifacts in `_build/`).

---

## Dimension 4: Functions Provided

### 4.1 Test Function Count by Category

| Category | testCase | testCaseAsync | testProperty | testSequenced | BDD scenarios | Total |
|----------|----------|---------------|-------------|---------------|---------------|-------|
| Core/OODA | 54 | 6 | 3 | 0 | 0 | 63 |
| Zenoh/FFI | 69 | 0 | 0 | 20 | 0 | 89 |
| Mesh/Boot | 124 | 0 | ~15 | 0 | 0 | ~139 |
| Cockpit/UI | 131 | 0 | 7 | 0 | 0 | 138 |
| Observability | 51 | 0 | 0 | 0 | 0 | 51 |
| Planning | ~90 | 0 | 0 | 0 | 0 | ~90 |
| Testing/MCP | 80 | 0 | 0 | 0 | 0 | 80 |
| BDD | 0 | 0 | 0 | 0 | 4 | 4 |
| Verification | ~18 | 0 | 4 | 0 | 0 | ~22 |
| CLI Plan | ~97 | 0 | 4 | 0 | 0 | ~101 |
| System Plan | ~198 | 0 | 6 | 0 | 0 | ~204 |
| IndrajaalTest | ~150 | ~30 | 0 | 0 | 0 | ~180 |
| **Total** | **~1,062** | **~36** | **~39** | **~20** | **4** | **~1,161** |

### 4.2 Assertion Pattern Distribution

| Pattern | Count | Used In |
|---------|-------|---------|
| `Expect.equal` | ~350 | All files (primary assertion) |
| `Expect.isTrue` | ~400 | All files (including ~300 placeholder tests) |
| `Expect.isFalse` | ~30 | FSM, Constraints, Planning |
| `Expect.isOk` / `Expect.isError` | ~50 | ROP, PrometheusGate, DAG |
| `Expect.isNone` / `Expect.isSome` | ~20 | Planning, Config |
| `Expect.isGreaterThan` / `isLessThan` | ~40 | Performance, CPM, Timing |
| `Expect.floatClose` | ~15 | MathMonitor, CPM, Health |
| `Expect.throwsT<exn>` | ~10 | ZenohFfiBridge, Config |
| `Expect.isEmpty` | ~5 | DAG, Planning |
| `Expect.containsAll` | ~10 | Capabilities, Constraints |
| `Expect.stringContains` | ~15 | OTEL, JSON output |

### 4.3 Key Verification Functions (Non-Trivial Logic in Tests)

**Kahn's Algorithm Verification** (`DAGTests.fs`):
- Verifies topological order correctness: all dependencies appear before dependents
- Wave grouping: nodes at same depth execute together
- Critical path: longest path through DAG = minimum completion time
- FsCheck: random acyclic DAGs always produce valid topological orders

**FSM State Transition Verification** (`FSMTests.fs`):
- 8-state container lifecycle (NotFound→Created→Starting→Running→Healthy/Unhealthy→Stopping→Stopped/Failed)
- Flapping prevention: rapid healthy↔unhealthy transitions filtered
- FsCheck: random state sequences maintain FSM invariants

**Hysteresis Debounce Verification** (`HysteresisTests.fs`):
- Three modes: aggressive (threshold=2), default (threshold=3), conservative (threshold=5)
- Flapping detection: alternating health samples within window
- Recovery paths: consecutive healthy samples required to transition back
- FsCheck: random boolean sequences with configurable thresholds

**Critical Path Method** (`CPMTests.fs`):
- Forward pass (earliest start/finish) + backward pass (latest start/finish)
- Slack calculation: `LS - ES` determines which tasks are on critical path
- Real boot sequence: DB→OBS→Zenoh→App→Health with actual timing estimates
- SC-BOOT-005: total boot time < 60s verified

**12 Formal FFI Invariants** (`ZenohFfiBridgeTests.fs`):
```
INV-1:  open_count ≥ close_count (sessions never close more than opened)
INV-2:  publish_count ≥ 0 (non-negative monotonic counter)
INV-3:  subscribe_count ≥ 0 (non-negative monotonic counter)
INV-4:  error_count ≥ 0 (non-negative monotonic counter)
INV-5:  null_handle_count = f(null handle attempts) (exact match)
INV-6:  key_validate_count ≥ 0
INV-7:  backoff_count ≥ 0
INV-8:  simulated_bus_count ≥ 0
INV-9:  triple_write_count ≥ 0
INV-10: safe_session_count ≥ 0
INV-11: max_latency_ns ≥ 0 (non-negative, CAS-updated)
INV-12: all 27 atomic counters maintain SeqCst ordering
```

**Bijective Status Mapping** (`PlanningSyncTests.fs`):
- Forward: `Pending → todo`, `InProgress → in_progress`, `Completed → done`, `Blocked → blocked`
- Reverse: `todo → Pending`, `in_progress → InProgress`, `done → Completed`, `blocked → Blocked`
- Case-insensitive parsing with whitespace trimming
- Verified over 100 idempotent iterations (sync → re-sync produces identical state)
- Intentional lossy mapping: unknown statuses documented as data loss

**HMAC-SHA256 Proof Token** (`PrometheusGateTests.fs`):
- Token includes: GUID, timestamp, action string, HMAC hash
- Key derived from `MachineName + ProcessId`
- Unique tokens: 100 generated tokens all distinct
- DAG acyclicity: Kahn's algorithm on level dependency graph `{(1,2), (2,3), (1,4), (3,5), (4,5)}`

### 4.4 BDD Framework Functions (SpecFlowConfig.fs)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `createContext` | `unit → ScenarioContext` | Initialize mutable context bag |
| `given` | `string → (ScenarioContext → string[] → unit) → StepDefinition` | Define Given step |
| `when'` | `string → (ScenarioContext → string[] → unit) → StepDefinition` | Define When step |
| `then'` | `string → (ScenarioContext → string[] → unit) → StepDefinition` | Define Then step |
| `setContextValue` | `ScenarioContext → string → 'a → unit` | Store value in context |
| `getContextValue` | `ScenarioContext → string → 'a` | Retrieve value from context |
| `createFeature` | `string → string list → Feature` | Create Feature with tags |
| `createScenario` | `string → string list → Scenario` | Create Scenario with tags |
| `buildTestFromScenario` | `StepDefinition list → Scenario → Expecto.Test` | Convert scenario to test |

### 4.5 IndrajaalTest Client Functions

| Module | Key Functions | Purpose |
|--------|--------------|---------|
| **HttpClient** | `getJson`, `postJson`, `putJson`, `deleteJson`, `patchJson`, `getWithHeaders` | Auth-aware HTTP with JSON |
| **WebSocketClient** | `connect`, `joinChannel`, `leaveChannel`, `sendHeartbeat`, `sendMessage` | Phoenix WS protocol |
| **ZenohClient** | `publish`, `subscribe`, `getKeyExpressions`, `FractalLogSubscriber` | Zenoh REST API wrapper |
| **TestReporter** | `reportSuccess`, `reportFailure`, `generateJsonReport`, `generateMarkdownReport` | Serilog + ANSI reports |
| **Config** | `defaultConfig`, `devConfig`, `stagingConfig`, `endpoints` (50+) | Environment-specific config |

---

## Dimension 5: Extensibility

### 5.1 Extension Points Matrix

| Extension | Mechanism | Friction | Files to Change |
|-----------|-----------|---------|-----------------|
| **Add new unit test file** | Create .fs, add to .fsproj, wire in Program.fs | MEDIUM (3 locations) | 3 files |
| **Add test to existing file** | Add `testCase` to existing `testList` | LOW (1 location) | 1 file |
| **Add FsCheck property** | Add `testProperty` with `Gen<T>` | LOW (1 location) | 1 file |
| **Add BDD scenario** | Add `createScenario` + step definitions | MEDIUM (DSL knowledge) | 1 file |
| **Add new STAMP constraint test** | Follow SC-* naming, add to constraint DU | LOW | 1-2 files |
| **Add new mock session type** | Implement pub/sub interface class | MEDIUM (OOP in F#) | 1 file |
| **Add new API test domain** | Create `{Domain}ApiTests.fs` with CRUD tests | LOW (template exists) | 2 files (test + .fsproj) |
| **Add new performance benchmark** | Add `testCase` with `Stopwatch` + threshold | LOW | 1 file |
| **Add new fractal verification level** | Add case to `VerificationLevel` DU, implement module | HIGH (bash integration) | 1-2 files |
| **Add new CLI command category** | Add case to `CliCategory` DU, test list | MEDIUM | 1 file |

### 5.2 Test Pattern Templates

**Unit Test Pattern** (used ~700 times):
```fsharp
testCase "descriptive name" <| fun _ ->
    let input = constructInput()
    let result = moduleUnderTest.function input
    Expect.equal result expectedValue "explanation"
```

**FsCheck Property Pattern** (used ~39 times):
```fsharp
testProperty "property name" (fun (x: int) ->
    let result = f x
    result >= 0 && result <= 100
)
```

**Async Test Pattern** (used ~36 times):
```fsharp
testCaseAsync "async operation" <| async {
    let! result = asyncFunction()
    Expect.isOk result "should succeed"
}
```

**Mock Integration Pattern** (used ~62 times):
```fsharp
testSequenced (testCase "with mock" <| fun _ ->
    let mock = MockZenohSession()
    mock.Publish("topic", "payload")
    mock.FlushMessages()
    let received = mock.GetReceived("topic")
    Expect.equal received.Length 1 "one message"
)
```

**BDD Scenario Pattern** (used 4 times):
```fsharp
let scenario = createScenario "scenario name" ["@tag"]
    |> addStep (Given, "precondition")
    |> addStep (When, "action")
    |> addStep (Then, "assertion")
buildTestFromScenario stepDefinitions scenario
```

### 5.3 Placeholder vs Executable Test Ratio

| File | Executable | Placeholder (`Expect.isTrue true "..."`) | % Real |
|------|-----------|------------------------------------------|--------|
| CockpitFCliTestPlan.fs | ~15 | ~86 | 15% |
| UltimateFractalSystemTestPlan.fs | ~20 | ~182 | 10% |
| All other files | ~980+ | ~0 | 100% |
| **Total** | **~1,015** | **~268** | **79%** |

CockpitFCliTestPlan and UltimateFractalSystemTestPlan are primarily **specification documents expressed as test code** — they define what should be tested but most individual tests are `Expect.isTrue true "placeholder"`. They serve as a roadmap for test development rather than active verification.

### 5.4 Reusable Test Infrastructure

| Component | LOC | Reused By | Portability |
|-----------|-----|-----------|-------------|
| `SpecFlowConfig.fs` (BDD framework) | 294 | TestEvolutionSteps | HIGH — pure F# BDD |
| `MockZenohSession` (in integration tests) | ~100 | 42 tests | MEDIUM — embedded in test file |
| `PerformanceMockSession` (in perf tests) | ~80 | 20 tests | MEDIUM — embedded in test file |
| `FsCheck generators` (custom Gen<T>) | ~150 | DAG, FSM, Hysteresis, CLI | LOW — scattered per file |
| `HttpClient` / `WebSocketClient` | ~675 | All IndrajaalTest API tests | HIGH — separate files |

**Improvement opportunity**: Extract `MockZenohSession` and `PerformanceMockSession` into shared test utility files. Currently they're embedded in individual test files, preventing reuse.

---

## Dimension 6: Performance Monitoring & Benchmarking

### 6.1 Dedicated Performance Tests

**ZenohFfiPerformanceTests.fs** (17 tests):

| Test Group | Metric | Threshold | Method |
|-----------|--------|-----------|--------|
| `ffiAvailabilityPerf` | FFI availability check time | <100ms | `Stopwatch.ElapsedMilliseconds` |
| `keyExprValidationPerf` | 1000 key validations | <100ms total | Batch timing |
| `nullHandlePerf` | Null handle detection time | <1ms | `Stopwatch` |
| `simulatedPublishPerf` | 1000 simulated publishes | <500ms total, <0.5ms each | Batch + per-op |
| `tripleWritePerf` | Triple-write (SQLite+Zenoh+Log) time | <5ms per write | `Stopwatch` |
| `backoffPerf` | Exponential backoff convergence | Increases geometrically | Pattern verification |
| `sessionOpenClosePerf` | Session lifecycle time | <100ms | `Stopwatch` |
| `memoryTests` | 10K operations memory growth | <50MB delta | `GC.GetTotalMemory` |

P99 percentile calculation:
```fsharp
let sorted = latencies |> Array.sort
let p99Index = int (float sorted.Length * 0.99)
let p99 = sorted.[p99Index]
Expect.isLessThan p99 threshold "P99 within budget"
```

**ZenohPerformanceTests.fs** (20 tests):

| Test Group | Metric | Threshold | STAMP |
|-----------|--------|-----------|-------|
| PRF-F-001 | Receive latency | <1ms per message | SC-BRIDGE-003 |
| PRF-F-002 | Dashboard update | <50ms | SC-PRF-050 |
| PRF-F-003 | Throughput | >5K msg/sec | — |
| PRF-F-004 | Non-blocking UI | No blocking calls | SC-BRIDGE-001 |
| PRF-F-005 | Memory stability | <50MB for 10K messages | — |
| PRF-F-006 | Graceful throttling | Backpressure response | — |

### 6.2 Embedded Performance Assertions (in non-perf tests)

| File | Metric | Threshold | Context |
|------|--------|-----------|---------|
| `PhicsTests.fs` | PHICS latency | <50ms (SC-PRF-050) | Container health check |
| `CPMTests.fs` | Boot critical path | <60s (SC-BOOT-005) | Real boot sequence model |
| `OodaControllerTests.fs` | OODA cycle time | <100ms (SC-OODA-001) | Observe→Orient→Decide→Act |
| `CockpitTUITests.fs` | TUI render time | <100ms | Dark cockpit refresh |
| `IndrajaalTest/HealthTests.fs` | Health endpoint p99 | <100ms | 100 parallel requests |

### 6.3 Memory Benchmarking

Only `ZenohFfiPerformanceTests.memoryTests` and `ZenohPerformanceTests` (PRF-F-005) explicitly measure memory:

```fsharp
let baseline = GC.GetTotalMemory(true)
// ... perform 10K operations ...
let current = GC.GetTotalMemory(true)
let deltaKB = (current - baseline) / 1024L
Expect.isLessThan deltaKB (50L * 1024L) "Memory growth < 50MB"
```

### 6.4 Missing Performance Coverage

| Gap | Risk | Recommendation |
|-----|------|----------------|
| No compilation profiling (per-file timing) | Can't identify slow-compiling files | Add `--times` flag to `dotnet build` |
| No CPU utilization during tests | May violate 80% cap (feedback_cpu_limit.md) | Add `Process.GetCurrentProcess().TotalProcessorTime` |
| No test suite timing aggregation | Can't identify slowest test groups | Expecto's `--summary` provides this externally |
| No GC pressure measurement | Memory spikes undetected | Add `GC.CollectionCount` per generation |
| No thread pool saturation | Async tests may exhaust pool | Monitor `ThreadPool.GetAvailableThreads` |
| No Zenoh FFI latency histogram (in tests) | FFI has histogram in Rust, not validated in tests | Add histogram bucket verification tests |

---

## Dimension 7: Test Run Execution

### 7.1 Execution Model

**Cepaf.Tests** runs as a standalone `dotnet run` process:

```
dotnet run --project Cepaf.Tests.fsproj -- [args]
    │
    ├── JIT compilation (first run: ~3-5s, subsequent: ~1s)
    ├── Load all [<Tests>] test lists
    ├── Build composite test tree ("All Tests" with ~50 children)
    ├── Apply filters (--filter-test-list, --filter-test-case, --filter)
    ├── Execute tests (parallel by default)
    │   ├── testCase: synchronous, may run in parallel
    │   ├── testCaseAsync: async, parallel-safe
    │   ├── testProperty: FsCheck shrinking + replay
    │   ├── testSequenced: forced serial execution
    │   └── BDD: sequential step execution within scenario
    ├── Collect results
    └── Print summary (--summary flag)
```

**Cepaf.IndrajaalTest** runs with authentication:

```
dotnet run --project Cepaf.IndrajaalTest.fsproj -- [--dev] [--default-creds]
    │
    ├── Parse CLI args (--dev, --staging, --url, --default-creds)
    ├── Build ServerConfig (base URL, ports, timeout)
    ├── Attempt login to get JWT token
    │   ├── Success → store token, run full suite
    │   └── Failure → skip auth-required tests
    ├── Build test suites (Health, Auth, API, WS, Channel, LiveView)
    ├── Run with parallel=true, parallelWorkers=4
    └── Generate reports (JSON, Markdown via TestReporter)
```

### 7.2 Test Execution Speed Profile

| Category | Tests | Expected Duration | Bottleneck |
|----------|-------|-------------------|------------|
| Pure unit (DAG, FSM, HLC, ROP, etc.) | ~400 | <5s total | None (pure functions) |
| FsCheck property tests | ~39 | ~10-30s total | Shrinking on failure |
| Mock integration (Zenoh mock) | ~62 | ~5-10s total | ConcurrentQueue ops |
| Performance benchmarks | ~37 | ~30-60s total | Deliberate timing |
| Cockpit/Theme (89+42 tests) | ~131 | ~5-10s total | String rendering |
| Planning sync (100+ iterations) | ~100 | ~10-20s total | Idempotency loops |
| BDD scenarios | 4 | <2s total | Step dispatch |
| Placeholder tests | ~268 | ~1s total | Trivial assertions |
| **Cepaf.Tests Total** | **~1,050+** | **~60-120s** | FsCheck + Performance |
| IndrajaalTest (with live app) | ~180 | ~60-180s | HTTP latency, WS connect |
| SevenLevelFractalVerification | ~18 | **5-30min** | Subprocess compilation |

### 7.3 Parallel Execution Characteristics

| File | Parallelizable | Reason |
|------|----------------|--------|
| DAGTests, FSMTests, CPMTests | YES | Pure functions, no shared state |
| HysteresisTests | YES | Each test creates independent instance |
| ZenohFfiBridgeTests | YES (mostly) | Atomic counters, thread-safe |
| ZenohChannelTests | NO | `testSequenced` — shared mutable channel |
| ZenohElixirIntegrationTests | PARTIALLY | Each test creates own MockSession |
| PlanningSyncTests | YES | Each test creates independent mapping |
| CockpitTUITests | YES | Pure rendering functions |
| ThemeSimulatorTests | YES | Independent theme instances |
| SevenLevelFractalVerification | NO | Subprocess execution, shared filesystem |
| IndrajaalTest API tests | PARTIALLY | Parallel HTTP requests OK, shared auth token |

### 7.4 Environment Dependencies

| Environment Variable | Required By | Default | Effect When Missing |
|---------------------|------------|---------|---------------------|
| `LD_LIBRARY_PATH` | ZenohFfiBridgeTests | Not set | `DllNotFoundException` for `libzenoh_ffi.so` |
| `ZENOH_USE_NATIVE` | ZenohNativeLifecycleTests | `false` | Uses simulated mode (no real FFI) |
| `SKIP_ZENOH_NIF` | SevenLevelFractalVerification | `1` | Zenoh NIF not loaded in Elixir subprocess |
| `NO_TIMEOUT` | SevenLevelFractalVerification | `false` | Compilation may timeout |
| `PATIENT_MODE` | SevenLevelFractalVerification | `disabled` | Compilation in normal mode |
| `SERVER_URL` | IndrajaalTest | `http://localhost:4000` | Wrong target server |
| `TEST_USERNAME`/`TEST_PASSWORD` | IndrajaalTest | From `--default-creds` | Auth tests skip |

### 7.5 Test Isolation Guarantees

| Level | Isolation | Mechanism |
|-------|-----------|-----------|
| **Process** | Full | Each `dotnet run` is a separate OS process |
| **Test** | Partial | Expecto runs tests in parallel within same process |
| **State** | Varies | Pure tests: full. testSequenced: serialized. Mock-based: per-test instance |
| **Filesystem** | None | SevenLevelFractalVerification modifies `_build/` |
| **Network** | None | IndrajaalTest shares TCP connections |
| **Database** | None | No test writes to any database |

---

## Dimension 8: Optimizing Test Runs

### 8.1 Current Optimization Features

| Feature | Implementation | Impact | Files |
|---------|---------------|--------|-------|
| **Parallel by default** | Expecto `defaultConfig.parallel = true` | ~2-4x speedup on multi-core | Program.fs |
| **Worker limit** | `parallelWorkers = 4` (IndrajaalTest) | Prevents HTTP connection exhaustion | IndrajaalTest/Program.fs |
| **Memory limit** | `stressMemoryLimit = 0.8` (IndrajaalTest) | Prevents OOM under stress | IndrajaalTest/Program.fs |
| **Filter by name** | `--filter-test-list`, `--filter-test-case` | Run subset of tests | CLI args |
| **Sequential override** | `testSequenced` for mutable state tests | Prevents race conditions | ZenohChannelTests |
| **Skip when offline** | `skipIfOffline` pattern | Graceful degradation | IndrajaalTest |
| **Batch FFI checks** | 1000 operations in tight loop | Amortize JIT overhead | ZenohFfiPerformanceTests |

### 8.2 Unrealized Optimization Opportunities

| Opportunity | Description | Estimated Impact | Effort |
|-------------|-------------|------------------|--------|
| **Extract UltimateFractalSystemTestPlan** | Currently compiled but not registered in Program.fs — 202 tests wasted | +202 tests coverage OR 1209 LOC saved | LOW |
| **Separate slow tests** | Tag performance/verification tests for conditional inclusion | Faster CI for code-only changes | MEDIUM |
| **Shared MockZenohSession** | Extract to utility file, reuse across integration + performance | Reduce code duplication ~180 LOC | LOW |
| **FsCheck config tuning** | Reduce `MaxTest` for CI, increase for nightly | Faster CI, thorough nightly | LOW |
| **Incremental test runs** | Run only tests in files that changed (git-aware) | 90%+ skip rate on small changes | HIGH |
| **Compile-time test discovery** | Replace manual Program.fs wiring with source generator | Eliminate registration bugs | HIGH |
| **Activate excluded tests** | 6 files excluded for module refactoring | +6 test files coverage | MEDIUM (requires refactoring) |
| **Split ZenohElixirIntegrationTests** | 1293 LOC / 42 tests in one file | Better parallel granularity | LOW |
| **Pre-compiled test binary** | Cache `dotnet run` JIT via ReadyToRun | Save 3-5s startup per run | MEDIUM |

### 8.3 Test Categorization Strategy

Current categories (implicit in directory structure):
```
Unit/        → Fast, pure, parallelizable  (~600 tests, <10s)
Module/      → Moderate, mock-based        (~20 tests, <5s)
Integration/ → Moderate, mock-based        (~42 tests, <10s)
Performance/ → Slow, timing-sensitive      (~37 tests, ~60s)
BDD/         → Fast, step dispatch         (~4 tests, <2s)
Verification/→ Very slow, subprocess       (~18 tests, 5-30min)
Plans/       → Fast but mostly placeholder (~303 tests, <5s)
```

Recommended test tiers for CI:
```
Tier 1 (PR gate, <30s):     Unit + Module + Planning + BDD + Core
Tier 2 (Merge gate, <3min):  Tier 1 + Integration + Performance
Tier 3 (Nightly, <30min):    All + Verification + full FsCheck
Tier 4 (Release, hours):     Tier 3 + IndrajaalTest (live) + excluded tests
```

### 8.4 FsCheck Optimization

Current FsCheck usage: 39 testProperty calls across 7 files.

| File | Properties | Default MaxTest | Shrink Behavior |
|------|-----------|-----------------|-----------------|
| OodaControllerTests | 3 | 100 | Fast (small DU values) |
| DAGTests | ~5 | 100 | Medium (graph structures) |
| FSMTests | ~3 | 100 | Fast (state transitions) |
| HysteresisTests | ~4 | 100 | Medium (bool sequences) |
| CockpitTUITests | 7 | 100 | Fast (DU + determinism) |
| FormalVerificationTests | 3 | 100 | Medium (AST structures) |
| CockpitFCliTestPlan | 4 | 100 | Fast (enum values) |

No tests override `MaxTest`. CI could use `MaxTest=30` for speed; nightly could use `MaxTest=1000` for thoroughness.

---

## Dimension 9: Bottleneck Monitoring

### 9.1 Identified Bottlenecks

| Bottleneck | Location | Severity | Evidence |
|------------|----------|----------|----------|
| **Manual test registration** | Program.fs + .fsproj | HIGH | UltimateFractalSystemTestPlan compiled but not registered (202 tests silently skipped) |
| **Subprocess compilation** | SevenLevelFractalVerification | HIGH | 5-30 minutes for bash `mix compile` + `mix test` |
| **Single-file integration** | ZenohElixirIntegrationTests (1293 LOC) | MEDIUM | 42 tests in one file; can't parallelize at file level |
| **Placeholder inflation** | CockpitFCliTestPlan + UltimateFractalSystemTestPlan | MEDIUM | ~268 tests that always pass, inflating test count |
| **Namespace collision** | IndrajaalTest Types/HttpClient duplication | LOW | Two type systems compiled; only one used per entry point |
| **JIT startup** | `dotnet run` | LOW | 3-5s cold start per invocation |
| **Mock embedding** | MockZenohSession in integration file | LOW | Not reusable by performance tests (duplicate) |
| **FsCheck shrinking** | Property test failures | LOW | Shrinking can take minutes for complex generators |

### 9.2 Test Health Indicators (Currently Unmeasured)

| Indicator | Current Status | Recommended |
|-----------|---------------|-------------|
| **Flaky test rate** | Unknown | Track pass/fail ratio per test over 10+ runs |
| **Test duration variance** | Unknown | Flag tests with >2x variance across runs |
| **Coverage per file** | Coverlet configured (80% threshold) | Surface in CI dashboard |
| **Dead test detection** | Manual | Detect `Expect.isTrue true` patterns automatically |
| **Registration completeness** | Manual | Verify all .fsproj Compile entries have Program.fs wiring |
| **Import completeness** | Manual | Verify all `open` namespaces resolve |
| **Generator coverage** | Unknown | Measure FsCheck seed diversity |

### 9.3 Compilation Bottlenecks

F# compilation is sensitive to file order. Current `.fsproj` has 40 active `<Compile Include>` entries plus 6 excluded. Compilation is sequential — F# does NOT support parallel compilation within a project.

| Phase | Duration | Bottleneck |
|-------|----------|------------|
| Restore (NuGet) | ~2-5s | Network for first run, cached after |
| Compile (F#) | ~10-20s | Sequential file compilation, 40 files |
| JIT (first run) | ~3-5s | Assembly loading, type checking |
| Test execution | ~60-120s | FsCheck + Performance tests |

### 9.4 Mock Overhead Analysis

| Mock | Overhead Per Operation | Used In | Operations Per Test |
|------|----------------------|---------|-------------------|
| `MockZenohSession.Publish` | ~1μs (ConcurrentQueue.Enqueue) | Integration | 1-100 |
| `MockZenohSession.FlushMessages` | ~10μs (drain + dispatch) | Integration | 1-5 |
| `PerformanceMockSession.Publish` | ~0.5-5ms (simulated delay) | Performance | 100-10K |
| `PerformanceMockSession.GetMemoryDelta` | ~1ms (`GC.GetTotalMemory(true)`) | Performance | 1 |

Mock overhead is negligible for unit/integration tests. Performance tests intentionally add delay to measure behavior under load.

---

## Dimension 10: Tracking, Metrics & Optimization

### 10.1 Metrics Currently Tracked

| Metric | Source | Where Tracked | Queryable |
|--------|--------|---------------|-----------|
| Test count per run | Expecto `--summary` | Console output | Manual parsing |
| Pass/Fail/Skip | Expecto `--summary` | Console output | Manual parsing |
| Duration per test | Expecto internal | Console output (`[time]` prefix) | Manual parsing |
| Coverage % | Coverlet MSBuild | `coverage/` directory (opencover, cobertura, json) | CI integration |
| FFI atomic counters (27) | ZenohFfiBridge Rust | Test assertions | In-test only |
| Memory delta | `GC.GetTotalMemory` | Test assertions | In-test only |
| P99 latency | Sorted array percentile | Test assertions | In-test only |
| HMAC token uniqueness | Set cardinality | Test assertions (100 tokens) | In-test only |
| State vector | `int array` assertions | Test assertions | In-test only |
| Health score | `float` comparison | MathMonitor tests | In-test only |

### 10.2 Coverage Configuration

```xml
<!-- Cepaf.Tests.fsproj -->
<CollectCoverage>true</CollectCoverage>
<CoverletOutputFormat>opencover,cobertura,json</CoverletOutputFormat>
<CoverletOutput>./coverage/</CoverletOutput>
<Threshold>80</Threshold>
<ThresholdType>line,branch</ThresholdType>
<ThresholdStat>total</ThresholdStat>
```

Three output formats for different consumers:
- **opencover** — Visual Studio, JetBrains tools
- **cobertura** — CI/CD systems (Jenkins, GitHub Actions)
- **json** — Programmatic analysis

### 10.3 STAMP Constraint Coverage Matrix

| STAMP Family | Tests | Files | Coverage |
|-------------|-------|-------|----------|
| SC-ZENOH-FFI (001-025) | 31 | ZenohFfiBridgeTests | 100% of specified invariants |
| SC-NAT (001-004) | 21 | ZenohNativeLifecycleTests | Full lifecycle |
| SC-ZTEST (001-020) | ~20 | Various | Partial (8/20 explicitly tested) |
| SC-BOOT (005, 008, 014) | 78 | DAG, FSM, CPM Tests | Full (boot DAG, FSM states, critical path) |
| SC-OPT-002 | 26 | HysteresisTests | Full (3 debounce modes) |
| SC-SYNC-PLAN (001-020) | 100+ | PlanningSyncTests | Full (bijection, idempotency, events) |
| SC-PROM (001, 004) | 19 | PrometheusGateTests | Full (tokens, DAG) |
| SC-MCP-TEST (001-004) | 61 | Testing/* | Full (agent, tools, runner, logs) |
| SC-PRF-050 | 24 | PhicsTests, ZenohPerf | Full (50ms latency) |
| SC-AGT (017-019) | 30+ | CyberneticAgentsTests | Full (50-agent hierarchy) |
| SC-HMI-* | 131 | CockpitTUI, ThemeSimulator | Full (dark cockpit, ARM) |
| SC-OBS-071 | 28 | OTELIntegrationTests | Full (4 OTEL modules) |
| SC-VER (001-080) | ~18 | SevenLevelFractalVerification | Partial (5 test wrappers) |
| SC-CLI (001-008) | ~101 | CockpitFCliTestPlan | Partial (mostly placeholder) |
| SC-TEST-EVO (001-007) | 4 | TestEvolutionSteps | Full (BDD scenarios) |
| SC-FSH (003, 004, 010, 011) | 75 | FSharpCapabilityTests | Full (units, patterns, composition) |
| SC-AI-003 | 49 | MathematicalSystemMonitorTests | Full (17 disciplines) |

### 10.4 Test Quality Metrics

| Metric | Value | Assessment |
|--------|-------|------------|
| Total active test files | 64 | Comprehensive |
| Total tests | ~1,230+ | Good breadth |
| Executable tests | ~962 | 78% of total (rest are placeholders) |
| Property tests | 39 | Moderate (could expand) |
| Async tests | ~36 | Adequate for I/O-bound |
| BDD scenarios | 4 | Minimal — room for growth |
| Performance tests | 37 | Good (dedicated benchmarks) |
| Files with FsCheck | 7 | 17% of test files (could expand) |
| Mock-isolated tests | ~62 | Good (self-contained) |
| Live system tests | ~198 | Comprehensive when app running |
| Excluded test files | 6 | Technical debt (module refactoring) |
| Unregistered test files | 1 (Ultimate) | Silent coverage loss |
| STAMP families covered | 16+ | Comprehensive |
| LOC test / LOC source | ~16,900 / ~315,000 | 5.4% test-to-source ratio |

### 10.5 Optimization Recommendations (Prioritized)

| Priority | Recommendation | Impact | Effort |
|----------|---------------|--------|--------|
| **P0** | Register UltimateFractalSystemTestPlan in Program.fs OR remove from .fsproj | +202 tests or -1209 LOC dead code | LOW |
| **P0** | Convert placeholder tests to `skiptest "not yet implemented"` | Accurate test counts | LOW |
| **P1** | Extract MockZenohSession to shared utility file | Reduce duplication, enable reuse | LOW |
| **P1** | Add test tier tags (`[<Category("fast")>]`) for CI optimization | Faster PR gate, thorough nightly | MEDIUM |
| **P1** | Add flaky test detection (pass/fail tracking across runs) | Reliability improvement | MEDIUM |
| **P2** | Reduce SevenLevelFractalVerification to stub checks in CI | Save 5-30 min in CI | LOW |
| **P2** | Resolve 6 excluded test files (module refactoring) | +6 files, ~200+ tests | HIGH |
| **P2** | Add CPU utilization monitoring during test execution | Enforce 80% cap | LOW |
| **P3** | Implement compile-time test discovery (source generator) | Eliminate registration bugs | HIGH |
| **P3** | Split ZenohElixirIntegrationTests.fs (1293 LOC) | Better parallel granularity | MEDIUM |
| **P3** | Add Zenoh FFI latency histogram verification tests | Validate 4-bucket histogram in Rust | MEDIUM |
| **P3** | Resolve IndrajaalTest namespace collisions | Clean compilation | LOW |

### 10.6 Test Evolution Trajectory

```
Sprint 47 (2026-03-10): ~400 F# tests, 30 files
Sprint 48 (2026-03-11): ~450 F# tests, 33 files
Sprint 49 (2026-03-11): ~480 F# tests, 35 files
Sprint 50 (2026-03-18): ~500 F# tests, 37 files
Sprint 51 (2026-03-18): ~520 F# tests, 38 files
Sprint 52 (2026-03-19): ~530 F# tests, 39 files
Sprint 53 (2026-03-20): ~540 F# tests, 39 files
Sprint 54 (2026-03-20): ~549 F# tests, 40 files + 24 IndrajaalTest files
                         = 1,230+ total across both projects

Growth rate: ~20 tests/sprint, ~1 file/sprint
Projection: ~1,400 tests by Sprint 60 (at current rate)
```

---

## Architecture Quality Summary

| Dimension | Score (1-10) | Strengths | Weaknesses |
|-----------|-------------|-----------|------------|
| **1. Control Plane** | 8 | Three clear control domains (pure/mock/live); clean CLI filtering; BDD framework | Manual 3-step registration; no auto-discovery |
| **2. Code Organization** | 8 | Clean directory structure matching fractal levels; clear namespace hierarchy | Two test projects with namespace collisions; 1293-LOC integration file |
| **3. Data Plane** | 9 | Self-contained mocks; ephemeral test data; clean data transformation pipelines | No persistent test state tracking across runs |
| **4. Functions Provided** | 9 | 1,230+ tests; 12 formal invariants; bijective mapping verification; Kahn's DAG | ~268 placeholder tests inflate counts |
| **5. Extensibility** | 7 | Clean patterns for adding tests; BDD DSL; FsCheck generators | Manual registration; mock classes embedded in test files |
| **6. Performance** | 7 | Dedicated benchmark suite; P99 measurement; memory tracking; latency thresholds | No CPU monitoring; no thread pool tracking; no GC pressure measurement |
| **7. Test Run Execution** | 8 | Parallel by default; sequential override; offline skip; stress memory limit | Subprocess tests (SevenLevel) dominate runtime; no test tiers |
| **8. Optimizing Test Runs** | 6 | Basic parallelism; filter by name; FsCheck default config | No incremental runs; no test tiers; no pre-compiled binary; 202 unregistered tests |
| **9. Bottleneck Monitoring** | 5 | Coverage via Coverlet; mock overhead is negligible | No flaky detection; no duration variance; no registration completeness check |
| **10. Tracking/Metrics** | 7 | Coverlet 3-format output; STAMP constraint mapping; 16+ families covered | No cross-run trends; metrics only in test assertions; 5.4% test-to-source ratio |
| **Overall** | **7.4** | Comprehensive F# test codebase with strong formal verification (12 invariants, Kahn's DAG, bijective mappings, FsCheck properties), self-contained mocks, and SIL-6 safety constraint coverage | Main gaps: placeholder test inflation, manual registration overhead, missing test tiers for CI optimization, no flaky/variance tracking, 6 excluded files pending refactoring |

---

## Cross-References

| Document | Purpose |
|----------|---------|
| `20260320-2200-fsharp-test-infrastructure-detailed-analysis.md` | Deep dive into TestAgent/RegressionRunner/PrometheusGate (5 source files, 10 dimensions) |
| This document | Complete inventory and analysis of ALL F# test code (64 files, 10 dimensions) |
| CLAUDE.md §14.0 | BEP Test/Demo Integration & Fractal Testing Framework |
| CLAUDE.md §6.0 | F# Expecto Test Runner commands |
| `.claude/rules/zenoh-test-messaging.md` | SC-ZTEST-001 to SC-ZTEST-020 specification |
