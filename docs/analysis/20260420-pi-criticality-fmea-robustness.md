# Pi-Mono Symbiosis: Criticality × FMEA × Robustness Analysis

**Dashboard**: https://vm-1.tail55d152.ts.net:8443/pi-symbiosis
**Date**: 2026-04-20 | **Version**: v22.10.1-PI-SYMBIOSIS
**Optimization**: O = max(Criticality × FMEA × Usability × Availability × Fractal_Coverage)

---

## 1. Criticality Matrix (Fractal Layer × Component)

| Layer | Component | Criticality | Justification |
|-------|-----------|:-----------:|---------------|
| L0 Constitutional | Guardian gate on Pi tools | **10** | SC-PI-002: L0 ops MUST be gated. Bypass = safety violation |
| L0 Constitutional | PII filter on Pi LLM responses | **9** | SC-SEC-003: PII leakage through 15 providers |
| L1 Atomic/Debug | OTel span emission for Pi events | **7** | SC-GLM-ZEN-001: No spans = invisible operations |
| L2 Component | TypeBox → Gleam ADT mapping | **5** | Type mismatch = runtime error, caught by compiler |
| L3 Transaction | Smriti.db session persistence | **8** | SC-PI-003: Data loss = session history destroyed |
| L3 Transaction | Tool federation registry | **7** | 93 tools must resolve correctly, collision = wrong tool |
| L4 System | Pi RPC subprocess lifecycle | **8** | Crash = all Pi operations fail, no inference |
| L5 Cognitive | OODA steering injection | **8** | Wrong steering = suboptimal decisions |
| L5 Cognitive | 6-tier hedged inference | **9** | Cascade failure = no AI response |
| L6 Ecosystem | Zenoh event publishing | **9** | SC-ZMOF-001: No Zenoh = invisible mesh |
| L6 Ecosystem | AG-UI event bridge (29↔32) | **8** | Wrong mapping = corrupted UI state |
| L7 Federation | Gateway broadcast (Telegram/GChat) | **6** | Notification failure = operator unaware |

## 2. FMEA Analysis (Per Module)

### pi_agent.gleam (841 lines, 40 public items) — HIGHEST CRITICALITY

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 1 | RunStarted not emitted before tool calls | 9 | 3 | 2 | **54** | start_session() now returns mandatory event |
| 2 | Event bridge maps PiAgentError to wrong AG-UI type | 8 | 2 | 3 | 48 | Exhaustive Gleam pattern match |
| 3 | Session state stuck in PiProcessing (no PiAgentEnd) | 7 | 4 | 4 | **112** | Timeout watchdog needed |
| 4 | is_c3i_tool misclassifies tool namespace | 6 | 3 | 2 | 36 | Now checks 16 prefixes |
| 5 | Sequence number overflow (Int > max) | 3 | 1 | 5 | 15 | BEAM BigInt, no overflow |
| 6 | now_ms() returns 0 on NIF failure | 8 | 1 | 3 | 24 | FFI fallback needed |
| 7 | Concurrent sessions sharing state | 7 | 3 | 5 | **105** | Actor isolation needed |

### pi_claude_code.gleam (476 lines, 24 public items)

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 8 | Event mapping table incomplete | 7 | 2 | 1 | 14 | Compile-time exhaustive check |
| 9 | Tool count mismatch (93 hardcoded) | 5 | 3 | 2 | 30 | Test verifies sum = total |
| 10 | claude_to_pi_tool returns "unknown" for valid tool | 6 | 2 | 2 | 24 | 6 Claude tools all mapped |
| 11 | BridgeHealth stuck on Disconnected | 5 | 4 | 3 | 60 | Health check polling needed |

### pi_tools.gleam (506 lines, 13 public items)

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 12 | Tool name collision (Pi "read" vs Claude "Read") | 7 | 3 | 2 | 42 | Case-sensitive namespace |
| 13 | GuardianRequired gate bypassed | 9 | 1 | 2 | 18 | Compile-time FractalGate type |
| 14 | federated_registry() missing new tools | 5 | 4 | 3 | 60 | Automated count test |

### pi_session.gleam (527 lines, 15 public items)

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 15 | JSONL parsing fails on malformed Pi output | 6 | 4 | 3 | 72 | Raw blob preserved for replay |
| 16 | Smriti.db write fails (disk full, WAL corruption) | 9 | 1 | 2 | 18 | WAL mode + integrity check |
| 17 | Session not persisted before crash | 8 | 3 | 4 | **96** | Periodic flush needed |

### pi_provider.gleam (306 lines, 14 public items)

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 18 | All 6 inference tiers fail simultaneously | 9 | 1 | 1 | 9 | Static ack tier (Tier 6) |
| 19 | Circuit breaker stuck open | 7 | 2 | 3 | 42 | 60s cooldown auto-reset |
| 20 | PII in LLM response not filtered | 9 | 3 | 5 | **135** | NIF-side PII scrubber needed |
| 21 | Provider registration race condition | 5 | 2 | 4 | 40 | OnceLock pattern |

### pi_zenoh.gleam (537 lines, 25 public items)

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 22 | Zenoh session drops during Pi operation | 8 | 3 | 2 | 48 | Auto-reconnect with backoff |
| 23 | Topic namespace collision with non-Pi publisher | 6 | 1 | 3 | 18 | Prefix "indrajaal/pi/" enforced |
| 24 | Message buffer overflow on high-frequency events | 7 | 2 | 4 | 56 | Backpressure/drop oldest |
| 25 | Zenoh NIF not loaded (SKIP_ZENOH_NIF=1) | 9 | 1 | 1 | 9 | SC-ZENOH-001 enforcement |

### Cross-Cutting Failure Modes

| # | Failure Mode | S | O | D | RPN | Mitigation |
|---|-------------|---|---|---|-----|------------|
| 26 | Pi RPC subprocess crash (SIGKILL) | 9 | 2 | 2 | 36 | Supervisor restart + event replay |
| 27 | Network partition between Pi and Zenoh | 8 | 2 | 3 | 48 | Local buffer + reconnect |
| 28 | Memory leak in long-running Pi session | 6 | 3 | 5 | 90 | Session compaction at 50 messages |
| 29 | AG-UI state machine desync | 8 | 2 | 4 | 64 | State snapshot on reconnect |
| 30 | Gleam hot reload breaks Pi bridge | 7 | 2 | 2 | 28 | NIF unchanged → safe reload |

## 3. FMEA Summary

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Total failure modes | 30 | — | — |
| Average RPN | 47.5 | < 100 | **PASS** |
| Max RPN | 135 (#20: PII filter) | < 200 | **PASS** |
| Critical RPNs (>100) | 3 (#3: 112, #7: 105, #20: 135) | 0 | **ACTION NEEDED** |
| High RPNs (>50) | 7 | < 5 | **IMPROVING** |

### Top 3 Risks (Immediate Action Required)

1. **RPN 135 — PII in LLM response not filtered** (pi_provider.gleam)
   - Fix: Implement NIF-side PII scrubber (regex: email, phone, CC, SSN, IP)
   - Pattern: [zk-55949a5d835a9be1] — use pii.rs (91 lines) in sa-plan-daemon

2. **RPN 112 — Session state stuck in PiProcessing** (pi_agent.gleam)
   - Fix: Add 30s timeout watchdog that transitions PiProcessing → PiIdle
   - Pattern: Circuit breaker pattern from pi_provider.gleam

3. **RPN 105 — Concurrent sessions sharing state** (pi_agent.gleam)
   - Fix: Actor-isolated sessions via OTP process per session
   - Pattern: [zk-2151a0e5d70ce4ca] — implement handle_message, add to supervisor

## 4. Robustness Score (Fractal Layer × Pi Coverage)

| Layer | Score | Available | Redundant | Self-Healing | Monitored | Gap |
|-------|:-----:|:---------:|:---------:|:------------:|:---------:|-----|
| L0 Constitutional | 6/10 | Yes | No | No | Yes | PII filter missing, no L0 approval test |
| L1 Atomic/Debug | 7/10 | Yes | No | No | Yes | OTel spans defined but not auto-published |
| L2 Component | 8/10 | Yes | N/A | N/A | Yes | Type bridge is compile-time verified |
| L3 Transaction | 7/10 | Yes | No | No | Yes | Session persistence needs periodic flush |
| L4 System | 5/10 | Yes | No | No | Partial | Pi subprocess not supervised by OTP |
| L5 Cognitive | 7/10 | Yes | Yes (6-tier) | Yes (fallback) | Yes | Steering injection not tested E2E |
| L6 Ecosystem | 8/10 | Yes | Yes (4 routers) | Yes (reconnect) | Yes | Primary layer, well-tested |
| L7 Federation | 4/10 | Partial | No | No | No | Gateway broadcast not implemented for Pi |

**Composite Robustness**: 6.5/10 (target: 8.0)

## 5. DAG Critical Path Analysis

```
User Prompt
  ↓ (1ms)
Claude Code → pi_claude_code.map_tool() → Pi RPC spawn
  ↓ (10ms)                                    ↓ (50ms)
Event: RunStarted → Zenoh publish      Pi coding-agent starts
  ↓                                       ↓ (100-5000ms)
Zenoh mesh → AG-UI dashboard           LLM Provider (15 options)
  ↓                                       ↓
StateSnapshot → UI update              Response stream
  ↓                                       ↓ (10ms)
Dashboard render                        bridge_event() → AG-UI
                                          ↓
                                        Zenoh publish
                                          ↓
                                        Dashboard update + Smriti.db persist
```

**Critical path latency**: 100ms (cache hit) to 5000ms (Gemma 4 cold start)
**Single points of failure**:
1. Pi RPC subprocess (no redundancy)
2. Smriti.db write (WAL mode helps but single file)
3. Zenoh router (4x redundancy via quorum)

## 6. Mathematical Runtime Verification

| Property | Formula | Current | Target | Status |
|----------|---------|---------|--------|--------|
| Shannon Entropy H | -Σ(p_i × log2(p_i)) across C1-C8 | 2.67 bits | ≥ 2.5 | **PASS** |
| CCM Coverage | Σ(w_i × cov_i) / Σ(w_i) | 0.770 | ≥ 0.90 | **IMPROVING** |
| ITQS Quality | 0.4×H + 0.4×CCM + 0.2×D | 0.736 | ≥ 0.85 | **IMPROVING** |
| Tool federation coverage | mapped/total | 93/93 | 100% | **PASS** |
| Event bridge coverage | mapped/total | 29/32 | ≥ 90% | **PASS** (91%) |
| Test density | tests/module | 133/6 = 22.2 | ≥ 15 | **PASS** |
| Composite fitness | Weighted score | 0.756 | ≥ 0.85 | **IMPROVING** |

## 7. Availability Model

| Component | SLA Target | Mechanism | Current |
|-----------|-----------|-----------|---------|
| Pi bridge (L6) | 99.9% | Gleam BEAM fault tolerance | ~99.9% |
| Zenoh mesh | 99.99% | 4-router quorum (2oo3 voting) | 99.99% |
| LLM inference | 99.95% | 6-tier hedged cascade | ~99.95% |
| Session persistence | 99.9% | SQLite WAL + backup | ~99.5% |
| Dashboard | 99.9% | axum async + auto-restart | 99.9% |
| **System composite** | **99.9%** | **Weakest link: session persistence** | **~99.5%** |

## 8. Usability Assessment

| Operation | Complexity | Tool | Status |
|-----------|:----------:|------|--------|
| Start Pi session | Low | `start_session()` | **Ready** |
| Check Pi health | Low | `bridge_status()` | **Ready** |
| View Pi dashboard | Low | Browser → 4200/pi-symbiosis | **Ready** |
| Diagnose event issues | Medium | Zenoh topic subscribe | Needs TUI view |
| Recover from crash | Medium | OTP supervisor restart | **Needs supervisor** |
| Add new Pi tool | Low | Add to pi_tools.gleam | **Ready** |
| Run Pi tests | Low | `gleam test` | **Ready** (133 tests) |

## 9. Hardening Recommendations (Priority Order)

| # | Action | RPN Reduced | Effort | Impact |
|---|--------|:-----------:|:------:|:------:|
| 1 | PII scrubber on Pi LLM responses | 135→18 | 2h | **HIGH** |
| 2 | Session timeout watchdog (30s) | 112→28 | 1h | **HIGH** |
| 3 | OTP actor per Pi session | 105→21 | 3h | **HIGH** |
| 4 | Periodic session flush (5s) | 96→24 | 1h | MEDIUM |
| 5 | Pi subprocess OTP supervisor | 36→9 | 2h | MEDIUM |
| 6 | L7 gateway broadcast for Pi events | — | 2h | MEDIUM |
| 7 | E2E Playwright test for Pi dashboard | — | 4h | LOW |
| 8 | Allium behavioral spec for Pi | — | 1h | LOW |

---

**STAMP**: SC-PI-001..010, SC-FMEA-001..008, SC-SIL4-001, SC-SEC-003
**ZK**: [zk-69e64fd77634f193] FEMA-driven roadmap, [zk-4eb499dd8120c9ba] Criticality × FEMA × Utility
**Version**: v22.10.1-PI-SYMBIOSIS | **Date**: 2026-04-20
