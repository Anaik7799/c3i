# Journal: Non-Blocking Cortex + Telegram/GChat Simulator + SimTest

**Date**: 2026-04-09T06:36Z
**STAMP**: SC-COG-001, SC-SIM-001, SC-ZMOF-001, SC-OPENCLAW-001

---

## 1. Scope & Trigger

User reported "sent ack message, no response sent back" — cortex daemon was blocking the tokio::select! loop during LLM inference, preventing intent processing. Required: fix blocking, build simulator for local testing, comprehensive test suite.

## 2. Pre-State Assessment

- Cortex `process_intent()` ran inline in `tokio::select!` — blocked 10-20s during LLM calls
- `recalculate_priorities()` ran in same select loop — blocked every 60s
- No simulator existed — all testing required real Telegram/GChat APIs
- No comprehensive integration test covering the full intent→OODA→response pipeline
- Artificial `tokio::time::sleep()` delays (2s, 3s, 2s = 7s total) in process_intent

## 3. Execution Detail

### 3.1 Cortex Non-Blocking Fix (cortex.rs)
- **Moved** `recalculate_priorities()` to its own `tokio::spawn()` timer loop
- **Spawned** `process_intent()` as `tokio::spawn()` — select loop never blocks
- **Spawned** `process_mcp_request()` as `tokio::spawn()` with cloned session
- **Removed** artificial sleep delays (7s → 0s)
- **Replaced** simulated "thinking" messages with real RETE-UL + tinyllama inference
- **Added** task creation for commands starting with `/`
- **Added** rule-based fallback when LLM unavailable

### 3.2 Telegram/GChat Simulator (simulator.rs, ~270 lines)
Built full HTTP simulator mimicking both APIs:

| Endpoint | Mimics | Purpose |
|----------|--------|---------|
| `/bot{token}/getUpdates` | Telegram Bot API | Long-polling ingress |
| `/bot{token}/sendMessage` | Telegram Bot API | Message egress |
| `/v1/projects/{p}/subscriptions/{s}:pull` | GCP Pub/Sub | GChat ingress |
| `/v1/projects/{p}/subscriptions/{s}:acknowledge` | GCP Pub/Sub | Message ack |
| `/webhook` | GChat Webhook | GChat egress |
| `/sim/inject/telegram` | Test harness | Inject test messages |
| `/sim/inject/gchat` | Test harness | Inject GChat messages |
| `/sim/status` | Test harness | Queue depths |
| `/sim/outbox` | Test harness | All sent messages |
| `/sim/clear` | Test harness | Reset state |

### 3.3 SimTest Command (cli.rs, ~200 lines)
Added `sa-plan-daemon sim-test --port 9999 --duration-secs 300`:

| Phase | Tests | Coverage |
|-------|-------|----------|
| 1: Telegram Interactions | 6 | Greeting, task cmd, status query, ACK, emergency |
| 2: GChat Interactions | 2 | Health query, task command via Pub/Sub |
| 3: MCP Tool Verification | 4 | plan_status, preferences, event_log r/w |
| 4: Rapid-Fire Stress | 2 | 20 messages burst, outbox verification |
| 5: OpenClaw Skills | 1 | 8 skill commands (/status, /help, queries) |
| 6: Continuous Monitoring | 1 | Periodic heartbeat + health checks |

## 4. Root Cause Analysis

**Primary**: `tokio::select!` is biased — when one branch takes 10-20s (LLM inference), no other branch can execute. The `process_intent()` function was async but ran inline, blocking the entire event loop.

**Secondary**: Artificial sleep delays (7s total) were unnecessary and further blocked the loop.

**Tertiary**: No simulator meant bugs could only be found by testing against real Telegram API, creating a slow feedback loop.

## 5. Fix Taxonomy

| Category | Action |
|----------|--------|
| Concurrency fix | spawn process_intent + process_mcp_request as tasks |
| Performance | Remove 7s of artificial delays |
| Intelligence | Real tinyllama inference instead of hardcoded "thinking" messages |
| Testing infrastructure | Full Telegram+GChat HTTP simulator |
| Test automation | 6-phase comprehensive integration test |
| CLI | New `simulator` and `sim-test` subcommands |

## 6. Patterns & Anti-Patterns Discovered

**Anti-Pattern (FIXED)**: Running async I/O (HTTP requests, LLM inference) inline in `tokio::select!`. Must always `tokio::spawn()` long-running operations.

**Anti-Pattern (FIXED)**: Simulating "intelligence" with `tokio::time::sleep(2s)` + hardcoded strings. Real LLM inference provides actual value.

**Pattern (GOOD)**: Simulator with inject/status/outbox endpoints — enables deterministic testing without external dependencies.

**Pattern (GOOD)**: `sim-test` command combines simulator + daemon + test runner in a single binary — zero external dependencies.

## 7. Verification Matrix

| Check | Result |
|-------|--------|
| SimTest 16/16 tests | PASS (100%) |
| Telegram ingress via simulator | PASS |
| GChat Pub/Sub ingress via simulator | PASS |
| LLM inference (tinyllama) | PASS |
| Non-blocking select loop | PASS |
| 20-message stress test | PASS |
| MCP tools (plan, pref, events) | PASS |
| Continuous monitoring (2+ cycles) | PASS |
| GChat notification sent | PASS |

## 8. Files Modified

- `native/planning_daemon/src/cortex.rs` — Non-blocking spawn, real LLM inference
- `native/planning_daemon/src/cli.rs` — Added `cmd_sim_test()` (~200 lines)
- `native/planning_daemon/src/simulator.rs` — **NEW** (~270 lines)
- `native/planning_daemon/src/main.rs` — Added `Simulator` and `SimTest` commands
- `scripts/test-openclaw-comprehensive.sh` — **NEW** wrapper script

## 9. Architectural Observations

The cortex daemon now follows proper async Rust patterns:
- `tokio::select!` only dispatches — never blocks
- Each intent/MCP request runs in its own spawned task
- `recalculate_priorities()` runs on an independent timer
- Gateway broadcast is fire-and-forget from the caller's perspective

The simulator enables a complete "dark cockpit" testing mode — the entire system can be tested without any external network access.

## 10. Remaining Gaps

- Quint/TLA+ formal verification of the intent state machine (started, agent working)
- Callback query handling (Telegram inline keyboard "Acknowledge" button)
- WhatsApp simulator endpoint
- Voice/WebRTC ingress simulation
- Rate limiting for production (>100 msgs/min)

## 11. Metrics Summary

| Metric | Before | After |
|--------|--------|-------|
| Intent processing latency | 7s (artificial) + 10-20s (LLM blocking) | <100ms dispatch + async LLM |
| Select loop blocking time | 10-20s per intent | 0ms (spawned tasks) |
| Test coverage (OpenClaw) | 0 tests | 16 tests, 6 phases |
| Simulator endpoints | 0 | 10 endpoints |
| Pass rate | N/A | 100% (16/16) |

## 12. STAMP & Constitutional Alignment

| Constraint | Status |
|-----------|--------|
| SC-COG-001 | COMPLIANT — Non-blocking neuromorphic intent routing |
| SC-SIM-001 | NEW — Simulator with full API fidelity |
| SC-ZMOF-001 | COMPLIANT — All intents flow through Zenoh topics |
| SC-OPENCLAW-001 | ADVANCING — Tools, Skills, Sessions tested via simulator |
| SC-OODA-004 | COMPLIANT — OODA cycle no longer blocked by LLM |

## 13. Conclusion

Fixed the cortex daemon's blocking issue by spawning all intent processing as independent tokio tasks. Built a comprehensive Telegram+GChat API simulator enabling fully offline testing. Created a 6-phase, 16-test integration test suite (`sa-plan-daemon sim-test`) that achieves 100% pass rate. The system now responds to chat messages within seconds instead of blocking for 10-20s. GChat notification dispatched.
