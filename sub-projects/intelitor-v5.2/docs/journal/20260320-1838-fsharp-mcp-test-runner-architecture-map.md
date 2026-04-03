# 2026-03-20 18:38 — F# MCP Test Runner Architecture Map

## Context
- Branch: main
- Purpose: Complete architecture map of F# MCP-based test runner for OTel improvement planning
- Related: `20260320-1831-comprehensive-otel-capture-improvement-pass.md` (9 issues identified)

## Summary

Full inventory of the F# MCP test runner — 3,590 lines across 8 core modules, 5 MCP tools,
5 regression levels, SC-ZTEST-008 triple-write, PrometheusGate validation.

---

## Data Flow

```
Claude MCP Client (test_fsharp_start)
  |
.mcp.json -> cepaf-sentinel-mcp binary
  |
Program.fs (stdio JSON-RPC loop)
  ├─ reads: JSON-RPC 2.0 request lines from stdin
  ├─ dispatches to Tools (ZenohTools, SentinelTools, TestTools)
  ├─ writes: JSON-RPC response lines to stdout
  └─ logs: diagnostics to stderr
  |
TestTools.fs (dispatch + MCP tool definitions)
  ├─ validates args & calls TestAgent.start()
  ├─ buffers failures to LogBuffer (max 100 entries)
  └─ returns JSON: {ok: true, run_id: "run-20260320-120000-123"}
  |
TestAgent.fs (MailboxProcessor actor)
  ├─ Start command:
  │   ├─ validate PrometheusGate (SC-PROM-001 proof token)
  │   ├─ generate runId
  │   ├─ create CancellationTokenSource
  │   ├─ post RunInfo to internal loop
  │   └─ Async.Start(executeRun) in background
  │
  ├─ executeRun (async):
  │   ├─ CP-AGENT-01: publishCheckpoint (start)
  │   ├─ map TestConfig -> RegressionRunner.RunConfig
  │   ├─ call RegressionRunner.runAsync (with CancellationToken)
  │   ├─ publish CP-AGENT-02 (running checkpoint)
  │   ├─ map AsyncRunResult -> RunResult
  │   ├─ CP-AGENT-03: publishCheckpoint (done with failures)
  │   └─ post RunCompleted to inbox
  │
  └─ Loop processes:
      ├─ RunCompleted: update history, publish CP-AGENT-03 health summary
      ├─ RunFailed: update status
      ├─ QueryStatus: async reply
      └─ GetResults: return truncated history
  |
RegressionRunner.fs (Level orchestration)
  ├─ Level 1: mix compile (warnings-as-errors)
  ├─ Level 2: mix test --trace
  ├─ Level 3: mix test test/sil6/ --trace
  ├─ Level 4: format + credo
  ├─ Level 5: health checks (ports, git, db, f# build)
  ├─ Subprocess outputs captured to LevelOutputs map
  ├─ Each level has live ANSI dashboard
  ├─ Publishes CP-REG-01 through CP-REG-12 via ZenohProgress
  └─ Returns AsyncRunResult with LevelResults, StateVector, ExitCode
  |
ZenohPublish.fs (SC-ZTEST-008 triple-write)
  ├─ Step 1: Log fallback to stderr [ZTEST-CHECKPOINT] (ALWAYS)
  ├─ Step 2: Native Zenoh publish via ZenohFfiBridge (best-effort)
  └─ Step 3: Structured JSON to stdout (bridge consumption)
```

---

## File Inventory

### Core Modules

| # | File | Lines | Role |
|---|------|-------|------|
| 1 | `lib/cepaf/src/Cepaf.Sentinel.MCP/Program.fs` | 153 | MCP stdio loop, state lifecycle |
| 2 | `lib/cepaf/src/Cepaf.Sentinel.MCP/Protocol/McpProtocol.fs` | 229 | JSON-RPC 2.0 serialization |
| 3 | `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/TestTools.fs` | 231 | 5 MCP tool defs + dispatch |
| 4 | `lib/cepaf/src/Cepaf/Testing/TestAgent.fs` | 442 | MailboxProcessor actor |
| 5 | `lib/cepaf/src/Cepaf/Testing/RegressionRunner.fs` | 1838 | 5-level orchestration |
| 6 | `lib/cepaf/src/Cepaf/Testing/PrometheusGate.fs` | 161 | Config validation, proof tokens |
| 7 | `lib/cepaf/src/Cepaf/Mesh/ZenohPublish.fs` | 105 | SC-ZTEST-008 triple-write |
| 8 | `lib/cepaf/src/Cepaf/Observability/Types.fs` | 431 | LogLevel, TraceContext, Quadplex |
| | **TOTAL** | **3,590** | |

### Observability Modules (OTel Integration Points)

| File | Lines | Key OTel Feature |
|------|-------|------------------|
| `lib/cepaf/src/Cepaf/Observability/Fractal/OTELIntegration.fs` | 489 | ActivitySourceBridge, dual-emit, baggage |
| `lib/cepaf/src/Cepaf/Observability/Fractal/Types.fs` | 471 | FractalLevel L1-L5, Priority P0-P3 |
| `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohFfiBridge.fs` | ~480 | 13 DllImport wrappers, native Zenoh |
| `lib/cepaf/src/Cepaf/Zenoh/Core/ZenohTypes.fs` | ~120 | SessionConfig, PublisherConfig |

### Test Files

| File | Tests | Coverage |
|------|-------|----------|
| `lib/cepaf/test/Cepaf.Tests/Unit/Testing/TestToolsTests.fs` | ~10 | MCP dispatch, tool defs |
| `lib/cepaf/test/Cepaf.Tests/Unit/Testing/RegressionRunnerAsyncTests.fs` | ~15 | Async exec, cancellation |
| `lib/cepaf/test/Cepaf.Tests/Unit/Testing/TestAgentTests.fs` | ~12 | Lifecycle, concurrency |

---

## Key Types

### TestAgent.fs
```fsharp
type TestConfig = { Levels: int list; TimeoutSeconds: int; Verbose: bool }
type RunInfo = { RunId: string; Config: TestConfig; StartTime: DateTime; Cts: CancellationTokenSource }
type RunResult = { RunId: string; ExitCode: int; LevelResults: Map<int, LevelResult>; StateVector: int array }
type LevelResult = { Level: int; Status: LevelStatus; DurationMs: int64; Details: string }
type TestStatus = Idle | Running of RunInfo | Completed of RunResult | Failed of string
type TestCommand = Start | Stop | QueryStatus | GetResults
type InternalMsg = Cmd of TestCommand | RunCompleted of RunResult | RunFailed of string
```

### RegressionRunner.fs
```fsharp
type RegressionLevel = L1_Compilation | L2_FullTests | L3_SIL6Tests | L4_QualityGates | L5_SystemHealth
type RunConfig = { Levels: RegressionLevel list; Verbose: bool; ReportOnly: bool }
type AsyncRunResult = { RunId: string; LevelStatuses: Map; LevelOutputs: Map; StateVector: int array; ExitCode: int }
```

### PrometheusGate.fs
```fsharp
type ProofToken = { TokenId: string; IssuedAt: DateTime; Action: string; Hash: string }
// DAG: 1->2, 2->3, 1->4, 3->5, 4->5 (Kahn's algorithm)
```

---

## Checkpoint Families

### CP-AGENT-* (TestAgent publishes)
| ID | Topic Pattern | Trigger |
|----|---------------|---------|
| CP-AGENT-01 | `indrajaal/test/fsharp/agent/{runId}/start` | Run starts |
| CP-AGENT-02 | `indrajaal/test/fsharp/agent/{runId}/status` | Running |
| CP-AGENT-03 | `indrajaal/test/fsharp/agent/{runId}/done` | Run complete |
| CP-AGENT-04 | `indrajaal/test/fsharp/agent/{runId}/stop` | Cancelled |
| CP-AGENT-05 | `indrajaal/test/fsharp/agent/{runId}/error` | Error |

### CP-REG-* (RegressionRunner publishes)
| ID | Topic Pattern | Trigger |
|----|---------------|---------|
| CP-REG-01 | `indrajaal/regression/run/{runId}/start` | Run start |
| CP-REG-02..11 | `indrajaal/regression/level/{name}/start|complete` | Level phases |
| CP-REG-12 | `indrajaal/regression/run/{runId}/complete` | Run complete |

---

## Environment Variables (SC-METRICS-003)
```
SKIP_ZENOH_NIF=0
NO_TIMEOUT=true
PATIENT_MODE=enabled
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8
ZENOH_USE_NATIVE=true
LD_LIBRARY_PATH=$PWD/target/release:$LD_LIBRARY_PATH
```

---

## MCP Configuration (.mcp.json)
```json
"sentinel-zenoh": {
  "command": "bash",
  "args": ["-c", "export LD_LIBRARY_PATH=... && exec ./cepaf-sentinel-mcp"],
  "env": {"ZENOH_USE_NATIVE": "true"}
}
```

5 MCP Tools: `test_fsharp_start`, `test_fsharp_stop`, `test_fsharp_status`, `test_fsharp_results`, `test_fsharp_logs`

---

## STAMP Constraints Covered
- SC-MCP-TEST-001..004: Concurrent run prevention, cancellation <1s, status <50ms, results
- SC-ZTEST-001..008: Checkpoint uniqueness, latency <10ms, log fallback FIRST
- SC-PROM-001..005: Proof tokens, DAG acyclic, <5ms verification
- SC-SIL6-004: Health summary for Homeostasis PID
- SC-METRICS-003: 16 schedulers mandatory

## AOR Rules Covered
- AOR-FAG-002: MailboxProcessor for lock-free state
- AOR-ZTEST-004/008: Async publishing, log fallback first
- AOR-PROM-001/004: Autonomous verification, proof tokens
- AOR-FFI-006: SC-ZTEST-008 triple-write preserved

---

## OTel Issues to Address (from improvement pass)

9 issues identified in `20260320-1831-comprehensive-otel-capture-improvement-pass.md`:
- **#1 P0**: tracing.ex stale service identity
- **#2 P1**: F# blocking Async.RunSynchronously in OTELFractalDecorator.wrap
- **#3 P1**: F# OTELBaggage process-global ConcurrentDictionary
- **#4 P1**: No F# TracerProvider bootstrap (dual-emit always standalone)
- **#5 P2**: F# setParentFromTraceparent wrong .NET pattern
- **#6 P2**: Elixir TracePropagator not wired to ZenohTestFormatter
- **#7 P2**: Elixir tracing.ex missing 11/30 domains
- **#8 P3**: Rust tracing not forwarded to OTel
- **#9 P3**: P3 sampling=0.0 vs Psi-2

## KPIs
- Core modules: 8 files, 3,590 lines
- OTel modules: 4 files, ~1,560 lines
- Test files: 3 files, ~100 tests
- Checkpoint families: 2 (CP-AGENT, CP-REG), 17 total IDs
- MCP tools: 5
- Regression levels: 5
