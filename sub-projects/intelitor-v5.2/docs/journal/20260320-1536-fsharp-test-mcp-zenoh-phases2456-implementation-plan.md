# 2026-03-21 16:30 — F# Test-MCP-Zenoh Integration: Phases 2, 4, 5, 6 Implementation Plan

## Context
- Branch: main
- Recent commits: 2421a4213 feat(sprint-54): Add SIL-6 Zenoh partition apoptosis chaos test
- Design doc: `journal/2026-03/20260320-1434-fsharp-test-mcp-zenoh-comprehensive-fractal-analysis.md`
- Phase 1 & 3 complete: `journal/2026-03/20260320-1522-fsharp-test-mcp-zenoh-phase1-phase3-implementation.md`
- Implementation scope: Phases 2, 4, 5, 6 (remaining phases)

## Summary

Implementation plan for the remaining 4 phases of the F# Test-MCP-Zenoh integration. Phase 1 (Core Agent — MailboxProcessor actor, 19 tests) and Phase 3 (MCP Tooling — 4 tools, 9 tests) are complete with 28/28 tests passing.

## Phase 2: Execution Hook-Up (P0)

Wire TestAgent to real test execution via RegressionRunner.

- Add `runAsync: RunConfig -> CancellationToken -> Async<int>` to RegressionRunner
- Thread CancellationToken through Subprocess.run/runMix/runStreaming
- Replace TestAgent.executeRun mock with RegressionRunner.runAsync call
- Map TestConfig → RunConfig (levels, timeout)
- STAMP: SC-MCP-TEST-002 (stop propagation <1s)

### Files
| Action | File |
|--------|------|
| MODIFY | `lib/cepaf/src/Cepaf/Testing/RegressionRunner.fs` |
| MODIFY | `lib/cepaf/src/Cepaf/Testing/TestAgent.fs` |
| CREATE | `lib/cepaf/test/Cepaf.Tests/Unit/Testing/RegressionRunnerAsyncTests.fs` |

## Phase 4: Telemetry & Data Plane (P1)

Add real Zenoh session injection, test_fsharp_logs MCP tool, result buffering.

- Call ZenohPublish.setNativeSession during TestAgent.create if ZENOH_USE_NATIVE=true
- Add 5th MCP tool `test_fsharp_logs` — returns last N failure stack traces
- Buffer recent results in TestToolsState (ResizeArray, max 100)
- STAMP: SC-ZTEST-008 (log fallback), SC-ZTEST-003 (<10ms publish)

### Files
| Action | File |
|--------|------|
| MODIFY | `lib/cepaf/src/Cepaf/Testing/TestAgent.fs` |
| MODIFY | `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/TestTools.fs` |
| MODIFY | `lib/cepaf/src/Cepaf.Sentinel.MCP/Program.fs` |
| CREATE | `lib/cepaf/test/Cepaf.Tests/Unit/Testing/TestToolsLogsTests.fs` |

## Phase 5: PROMETHEUS Integration (P1)

Add proof token gate and DAG verification before test mutations.

- Create PrometheusGate.fs with verifyTestStart (config validation + HMAC-SHA256 proof token)
- DAG verification: topological sort of level dependencies via Kahn's algorithm
- Gate test_fsharp_start through PrometheusGate before spawning
- Add CP-AGENT-01..05 to Elixir checkpoint_messages.ex
- STAMP: SC-PROM-001 (proof token), SC-PROM-004 (DAG acyclicity)

### Files
| Action | File |
|--------|------|
| CREATE | `lib/cepaf/src/Cepaf/Testing/PrometheusGate.fs` |
| CREATE | `lib/cepaf/test/Cepaf.Tests/Unit/Testing/PrometheusGateTests.fs` |
| MODIFY | `lib/cepaf/src/Cepaf/Testing/TestAgent.fs` |
| MODIFY | `lib/cepaf/src/Cepaf/Cepaf.fsproj` |
| MODIFY | `lib/indrajaal/testing/checkpoint_messages.ex` |

## Phase 6: SIL-6 Homeostasis Wiring (P2)

Wire F# test telemetry into Elixir biomorphic stack.

- Add :test_pass_rate to Homeostasis PID controller stress metrics
- OODA loop observe/decide phases include test health
- PatternHunter: 3 test anomaly patterns (declining rate, duration spike, failure cluster)
- ZenohTestOrchestrator: aggregate CP-AGENT-* messages
- STAMP: SC-SIL6-004 (neural-immune <50ms), SC-BIO-001 (OODA <100ms)

### Files
| Action | File |
|--------|------|
| MODIFY | `lib/indrajaal/cortex/homeostasis/controller.ex` |
| MODIFY | `lib/indrajaal/cybernetic/ooda/loop.ex` |
| MODIFY | `lib/indrajaal/safety/pattern_hunter.ex` |
| MODIFY | `lib/indrajaal/testing/zenoh_test_orchestrator.ex` |
| MODIFY | `lib/cepaf/src/Cepaf/Testing/TestAgent.fs` |
| CREATE | `test/indrajaal/testing/fsharp_agent_integration_test.exs` |

## Execution Order

```
Phase 2 (P0) ──→ Phase 4 (P1) ──→ Phase 5 (P1) ──→ Phase 6 (P2)
```

## sa-plan Tasks (12 tasks added)

| ID | Title | Priority | Phase |
|----|-------|----------|-------|
| 065c86a0 | Phase 2: Add CancellationToken to RegressionRunner.run | P0 | 2 |
| 6ca9b8f0 | Phase 2: Wire TestAgent.executeRun to RegressionRunner.runAsync | P0 | 2 |
| 7367ebdc | Phase 2: Integration test — start/run/stop lifecycle | P0 | 2 |
| 82f30699 | Phase 4: Inject ZenohPublish.setNativeSession in TestAgent.create | P1 | 4 |
| 97687eaf | Phase 4: Add test_fsharp_logs MCP tool (5th tool) | P1 | 4 |
| 9e0a59d4 | Phase 4: Buffer recent results in TestToolsState | P1 | 4 |
| b150eb67 | Phase 5: Implement PrometheusGate.fs (proof token + DAG) | P1 | 5 |
| e938bfaf | Phase 5: Gate test_fsharp_start through PrometheusGate.verifyTestStart | P1 | 5 |
| a597b3c6 | Phase 5: Add CP-AGENT-01..05 to checkpoint_messages.ex | P1 | 5 |
| 7c6471a6 | Phase 6: Wire test_pass_rate into Homeostasis PID controller | P2 | 6 |
| 5f5f45ed | Phase 6: Register test anomaly patterns in PatternHunter | P2 | 6 |
| 56429995 | Phase 6: Add F# agent aggregation to ZenohTestOrchestrator | P2 | 6 |

## KPIs
- Files to change: 17 (6 new + 11 modified)
- Estimated lines: ~800-1000
- Tests to add: ~40-60
- Phases: 4 (2→4→5→6)
