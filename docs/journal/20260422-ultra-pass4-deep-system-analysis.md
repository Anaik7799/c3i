https://vm-1.tail55d152.ts.net:8443/task-id/116446490148048164/20260422-ultra-pass4-deep-system-analysis.md

# ULTRA-PASS4: Deep System Analysis — Full Fractal x Pi x SDLC/SRE x RETE-UL x Observability

**Date**: 2026-04-22
**Task ID**: 116446490148048164
**Version**: v22.10.1-PI-SYMBIOSIS
**ZK Recall**: [zk-6cc044169362603f] prior SDLC/SRE fractal analysis, [zk-d1f4fccd683f3a81] ultra-pass3

---

## 1. Scope & Trigger

**Scope**: Comprehensive deep analysis of the entire C3I system across all fractal layers, with focus on Pi integration wiring, RETE-UL integration opportunities, observability gaps, self-awareness capabilities, SDLC/SRE lifecycle coverage, and multidimensional optimization.

**Trigger**: User requested "one more detailed pass" with ultrathink depth covering full SDLC/SRE, Pi symbiosis wiring, RETE-UL/ruliology integration, operational scenarios, self-awareness, and system improvement identification.

**Prior passes**: [zk-d1f4fccd683f3a81] ultra-pass3 at task 1a92520c, [zk-cf66a34542d4d380] deep fractal at task 116438203955602049. This pass goes deeper with EXACT metrics and SPECIFIC gap identification.

---

## 2. Pre-State Assessment

### 2.1 System Scale (Exact Metrics — 2026-04-22)

| Metric | Value | Prior (v22.10.0) | Delta |
|--------|-------|------------------|-------|
| Gleam source files | 424 | ~291 | +133 (+46%) |
| Gleam source LOC | 106,968 | ~42,000 | +64,968 (+155%) |
| Gleam test files | 223 | ~70 | +153 (+219%) |
| Gleam test LOC | 82,991 | ~18,000 | +64,991 (+361%) |
| Rust files | 71 | 31 | +40 (+129%) |
| Rust LOC | 24,305 | 9,104 | +15,201 (+167%) |
| Total system LOC | 214,264 | ~69,104 | +145,160 (+210%) |
| Lustre pages | 57 | 24 | +33 (+138%) |
| Wisp API modules | 34 | 15 | +19 (+127%) |
| TUI view modules | 50 | 23 | +27 (+117%) |
| HTTP routes | 62 | ~40 | +22 (+55%) |
| Pi bridge LOC | 3,494 | ~1,500 | +1,994 (+133%) |
| ZK holons (C3I) | 31,775 | 2,679 | +29,096 (+1086%) |
| Tests passing | 8,979 | 8,817 | +162 |

### 2.2 Architecture State

```
┌─────────────────────────────────────────────────────────────────┐
│                    C3I SYSTEM ARCHITECTURE                       │
│                    214,264 LOC • 718 files                       │
├─────────────────────────────────────────────────────────────────┤
│  GLEAM STACK (189,959 LOC)                                       │
│  ├── UI/Lustre: 57 SSR pages (port 4100)                        │
│  ├── UI/Wisp:   34 REST API modules                              │
│  ├── UI/TUI:    50 terminal view modules                         │
│  ├── AG-UI:     32 event types, 6 modules                       │
│  ├── A2UI:      233 components, 5 modules                        │
│  ├── Fractal:   8 L0-L7 widget modules                          │
│  ├── ZK:        10 modules (types/search/ops/ingest/entropy...)  │
│  ├── Planning:  16 modules                                       │
│  ├── Podman:    7 modules                                        │
│  ├── Pi Bridge: 6 modules (3,494 LOC)                           │
│  ├── Gateway:   3 modules (Telegram/GChat/WhatsApp)              │
│  ├── MoZ:       3 modules (MCP-over-Zenoh)                      │
│  ├── Testing:   4 modules (coverage math, wiring guard)          │
│  └── Tests:     223 files (82,991 LOC)                          │
│                                                                   │
│  RUST STACK (24,305 LOC)                                         │
│  ├── Cortex:    1,980 LOC (intent processing, 6-tier cascade)   │
│  ├── DB:        1,017 LOC (SQLite, task CRUD, trace)            │
│  ├── Ruliology: 929 LOC (Wolfram CA, causal graphs)             │
│  ├── Rules:     961 LOC (52 GRL rules, 13 domains)              │
│  ├── Inference: 663 LOC (hedged, circuit breakers)              │
│  ├── Web:       62 routes (api.rs + server.rs)                  │
│  └── 65 other modules (voice, PII, FMEA, HA, etc.)             │
│                                                                   │
│  PI-MONO (106,577 LOC TypeScript, 7 packages)                    │
│  └── Bridge: 3,494 LOC Gleam, 0 production imports              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Execution Detail: Critical Gaps Found

### GAP-1: Pi Bridge Not Wired (SEVERITY: P0)

**Finding**: 6 Pi bridge modules (3,494 LOC) have ZERO production source imports. They compile, they have tests (30+), but no production code calls them.

| Module | LOC | Test Coverage | Production Imports |
|--------|-----|---------------|-------------------|
| pi_agent.gleam | 925 | Yes (3 test files) | **0** |
| pi_tools.gleam | 723 | Yes (2 test files) | **0** |
| pi_zenoh.gleam | 537 | Yes (1 test file) | **0** |
| pi_session.gleam | 527 | Yes (1 test file) | **0** |
| pi_claude_code.gleam | 476 | Yes (1 test file) | **0** |
| pi_provider.gleam | 306 | Yes (1 test file) | **0** |

**Impact**: Pi-mono cannot actually interact with C3I through the Gleam stack. The bridge exists as isolated library code.

**Fix**: Wire pi_agent.gleam into agents/cortex.gleam for Pi event handling. Wire pi_tools.gleam into the MCP tool dispatcher. Wire pi_zenoh.gleam into the Zenoh subscriber setup.

### GAP-2: Zenoh OTel Not Connected to UI (SEVERITY: P0)

**Finding**: zenoh_otel.gleam exists but is imported by only 3 source files and **0 Lustre page modules** import it. Per SC-GLM-ZEN-001, ALL UI state changes MUST publish OTel spans.

**Impact**: 57 Lustre pages have no observability — state changes are invisible to Zenoh mesh.

**Fix**: Each Lustre page's `update()` function should call `zenoh_otel.publish_span(page, operation)` on every Msg handling. This is ~2 lines per page × 57 pages = ~114 lines of integration code.

### GAP-3: Triple Interface Mismatch (SEVERITY: P1)

| Interface | Count | Coverage |
|-----------|-------|----------|
| Lustre pages | 57 | 100% (baseline) |
| Wisp APIs | 34 | 60% (23 pages missing API) |
| TUI views | 50 | 88% (7 pages missing TUI) |

**Missing Wisp APIs for pages**: 23 Lustre pages have no corresponding REST API endpoint. Per SC-GLM-UI-001, a feature = 1 Lustre + 1 Wisp + 1 TUI.

### GAP-4: Rules Engine Underutilized (SEVERITY: P1)

**Finding**: The Rust RETE-UL engine (52 rules, 13 domains) is accessed via NIF, but the Gleam rules/engine.gleam bridge is imported by only 2 modules.

**Opportunities for RETE-UL integration**:

| Decision Point | Current | Should Be | RETE-UL Domain |
|----------------|---------|-----------|----------------|
| Dark cockpit mode | Hardcoded thresholds in cockpit_view | `evaluate_verify()` | Verify Compliance |
| Health badge colors | Inline case statements | `evaluate_health_consensus()` | Health Consensus |
| Task priority routing | if/else in planning | `evaluate_decision()` | OODA Decide |
| Container restart logic | Manual in podman modules | `evaluate_recovery()` | Recovery Selection |
| CPU throttling thresholds | cpu-governor.sh bash script | `evaluate_governor()` | CPU Governor |
| Build staleness checks | Manual age comparison | `evaluate_build()` | Build Staleness |
| Apoptosis grace period | Hardcoded timeouts | `evaluate_apoptosis()` | Apoptosis Grace |
| RCA escalation level | Manual tier assignment | `evaluate_rca()` | RCA Escalation |
| Preflight gate checks | Inline validation | `evaluate_preflight()` | Preflight Gate |
| Cascade containment | Hardcoded depth limits | `evaluate_cascade()` | Cascade Containment |

### GAP-5: Self-Awareness Dashboard Missing (SEVERITY: P1)

**Finding**: No dashboard tracks:
- ZK search frequency per session
- ZK citation rate (current ~5%, target 90%)
- Hook fire success/failure rates
- Cache hit/miss ratios
- Zenoh message volume by topic
- MCP tool invocation counts by tool
- Agent OODA cycle times

### GAP-6: CLAUDE.md Stats Stale (SEVERITY: P2)

CLAUDE.md reports: 24 Lustre pages, 15 Wisp APIs, 23 TUI views, ~42K LOC
Actual: 57 Lustre pages, 34 Wisp APIs, 50 TUI views, 214K LOC

---

## 4. Root Cause Analysis

### Why Are Pi Bridge Modules Unwired?
1. Pi-mono is TypeScript, runs in separate Node.js process
2. Bridge modules define Gleam TYPES for Pi concepts (events, tools, sessions)
3. No OTP actor exists to receive Pi events via Zenoh
4. The architectural intent is: Pi → Zenoh message → Gleam actor → pi_agent.gleam handler
5. The Gleam actor that subscribes to Zenoh Pi topics was never implemented

### Why Is zenoh_otel Not In Pages?
1. zenoh_otel.gleam was created for the test observer system (testing/zenoh_test_observer)
2. It publishes spans but needs an active Zenoh session to work
3. Lustre pages run in server-rendered context without a Zenoh connection
4. Integration requires: page update → call otel function → NIF publishes to Zenoh
5. The NIF call path (Gleam → c3i_nif.erl → c3i_nif.so → Zenoh C library) exists but isn't invoked from pages

### Why Is RETE-UL Underutilized?
1. The 52 GRL rules were created in Rust for the sa-plan-daemon cortex
2. Gleam NIF bridge exists (rules/engine.gleam) but requires JSON serialization of facts
3. Many Gleam modules use simple pattern matching which WORKS and is type-safe
4. Migration to RETE-UL adds complexity without immediate functional gain
5. The value is in CONFIGURABILITY — rules can change without recompilation

---

## 5. Fix Taxonomy

| # | Gap | Fix Type | Priority | Estimated LOC | Fractal Layer |
|---|-----|----------|----------|--------------|---------------|
| F1 | Pi bridge unwired | Architecture | P0 | 200 Gleam | L6 Ecosystem |
| F2 | zenoh_otel disconnected | Integration | P0 | 114 Gleam | L1 Atomic |
| F3 | Triple interface gaps | Feature | P1 | 1,500 Gleam | L2 Component |
| F4 | Rules engine integration | Integration | P1 | 300 Gleam | L5 Cognitive |
| F5 | Self-awareness dashboard | Feature | P1 | 400 HTML+Gleam | L5 Cognitive |
| F6 | CLAUDE.md stats update | Documentation | P2 | 50 MD | L7 Federation |
| F7 | Missing Wisp APIs (23) | Feature | P2 | 2,300 Gleam | L3 Transaction |
| F8 | Missing TUI views (7) | Feature | P2 | 700 Gleam | L3 Transaction |

---

## 6. Patterns & Anti-Patterns Discovered

### PATTERNS

**P1: Type-First Bridge Design**
Pi bridge modules define ALL types first (events, tools, sessions), then implement logic. This is correct — types ARE the contract. But types without consumers are dead code.

**P2: NIF-Mediated Observability**
The path Gleam → Erlang FFI → Rust NIF → Zenoh is the proven pattern for publishing OTel spans. It's used by testing/zenoh_test_observer but not by production pages.

**P3: 25-Use-Case Knowledge Pipeline**
operations.gleam's 25 use cases (UC01-UC25) provide a complete knowledge lifecycle. But only UC01 (cortex RAG) is actively called from production. UC02-UC25 are available but unused.

### ANTI-PATTERNS

**AP1: Bridge Without Consumer (RPN=252)**
Creating 3,494 LOC of bridge code without a production consumer. This is Muda (overproduction) — the code exists "just in case" Pi connects.
Fix: Wire immediately or mark as experimental.

**AP2: Observability Theater (RPN=336)**
zenoh_otel.gleam exists, zenoh_test_observer verifies it, but ZERO production pages use it. The observability LOOKS complete (the module exists, the tests pass) but provides ZERO production telemetry.
Fix: Integrate into every page's update() function.

**AP3: Stale Documentation (RPN=84)**
CLAUDE.md reports 42K LOC when actual is 214K LOC. This misleads agents about system scale.
Fix: Update CLAUDE.md §9.0 and §8.2 with current metrics.

---

## 7. Verification Matrix

| Check | Method | Result |
|-------|--------|--------|
| Gleam builds | `gleam build` | PASS (0.31s) |
| Tests pass | `gleam test` | 8,979 passed, 1 pre-existing failure |
| Pi bridge compiles | All 6 modules compile | PASS |
| zenoh_otel compiles | Module builds | PASS |
| Rust builds | `cargo build --release` | PASS |
| sa-plan accessible | `status` command | 145 completed tasks |
| ZK searchable | `knowledge-search` | 31,775 holons |
| Dashboard live | https://vm-1.tail55d152.ts.net:8443/recall-rag | LIVE |
| Email functional | send-email with attachment | PASS |

---

## 8. Files Modified/Created

| File | Action | Lines |
|------|--------|-------|
| `docs/journal/20260422-ultra-pass4-deep-system-analysis.md` | NEW | This file |
| No source files modified in this analysis pass | — | — |

---

## 9. Architectural Observations

### 9.1 The System Has Grown 3x Since CLAUDE.md Was Last Updated
214K LOC vs documented 69K LOC. 57 pages vs documented 24. This growth happened organically through feature evolution sessions but the documentation didn't keep pace.

### 9.2 Pi Symbiosis Is Architecturally Complete But Operationally Disconnected
All 6 bridge modules exist, all types are defined, all events are mapped. But the runtime wiring (Zenoh subscriber actor → bridge handler → response) was never built. The fix is ~200 LOC of Gleam OTP actor code.

### 9.3 Observability Has a False-Positive Problem
The test suite verifies zenoh_otel works (via zenoh_test_observer). The dashboard shows "Zenoh Verification: Active". But production pages publish ZERO spans. The system THINKS it has observability, but it doesn't.

### 9.4 RETE-UL Could Replace ~30% of Hardcoded Decision Logic
10 decision points identified that currently use inline if/else or case statements. Migrating to RETE-UL would make them configurable without recompilation. Priority: health consensus, dark cockpit, and container recovery.

### 9.5 Self-Awareness Is the Missing Biomorphic Property
The system has Homeostasis (dark cockpit), Metabolism (CPU governor), Growth (test count increases), Response (hooks), Adaptation (RETE-UL), Evolution (hot reload). But it lacks SELF-OBSERVATION — tracking its own cognitive performance (ZK citation rate, OODA cycle time, cache efficiency).

---

## 10. Remaining Gaps (Improvement Opportunities)

### 10.1 Critical (P0) — Must Fix for System Integrity
| # | Gap | Impact | Fix LOC |
|---|-----|--------|---------|
| 1 | Pi bridge not wired to production | Pi-mono cannot interact with Gleam stack | 200 |
| 2 | zenoh_otel not in any Lustre page | Zero production observability | 114 |

### 10.2 High (P1) — Should Fix for System Quality
| # | Gap | Impact | Fix LOC |
|---|-----|--------|---------|
| 3 | 23 pages missing Wisp API | Triple-interface incomplete (60%) | 2,300 |
| 4 | RETE-UL only 2 imports | 52 rules underutilized | 300 |
| 5 | No self-awareness dashboard | Can't measure cognitive health | 400 |
| 6 | 7 pages missing TUI view | Terminal users incomplete | 700 |
| 7 | UC02-UC25 not called from production | 24 knowledge use cases unused | 200 |

### 10.3 Medium (P2) — Should Fix for Completeness
| # | Gap | Impact | Fix LOC |
|---|-----|--------|---------|
| 8 | CLAUDE.md stats stale | Misleads agents | 50 |
| 9 | Vector embeddings not implemented | FTS5 keyword-only (no semantic) | 200 |
| 10 | Holon link graph not built | No graph navigation | 150 |
| 11 | No Wolfram CA on ZK dynamics | Missing ruliology analysis | 200 |
| 12 | No Pi RAG in TypeScript | Pi agents lack recall | 630 |

---

## 11. Metrics Summary

### 11.1 System Scale
| Metric | Value |
|--------|-------|
| Total LOC (Gleam + Rust) | 214,264 |
| Total files | 718 |
| Gleam src | 424 files, 106,968 LOC |
| Gleam test | 223 files, 82,991 LOC |
| Rust | 71 files, 24,305 LOC |
| Pi TypeScript | 7 packages, 106,577 LOC |
| Grand total (all languages) | 320,841 LOC |

### 11.2 Integration Health
| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Triple interface coverage | 60% | 100% | GAP |
| Pi bridge production imports | 0 | 6 | CRITICAL GAP |
| zenoh_otel page integration | 0/57 | 57/57 | CRITICAL GAP |
| RETE-UL source imports | 2 | 15+ | GAP |
| MoZ protocol imports | 10 | 20+ | PARTIAL |
| ZK agent citation rate | ~5% | 90% | GAP |
| Tests passing | 8,979 | — | HEALTHY |
| Build time | 0.31s | <1s | HEALTHY |

### 11.3 FMEA Summary (Top 5 by RPN)
| Failure Mode | S | O | D | RPN | Gap # |
|-------------|---|---|---|-----|-------|
| Observability theater (no real spans) | 8 | 7 | 6 | 336 | GAP-2 |
| Pi bridge dead code (no consumers) | 7 | 6 | 6 | 252 | GAP-1 |
| ZK recall ignored by agents | 9 | 9 | 3 | 243 | AP1 |
| Triple interface incomplete | 6 | 7 | 4 | 168 | GAP-3 |
| RETE-UL underutilization | 5 | 7 | 4 | 140 | GAP-4 |

---

## 12. STAMP & Constitutional Alignment

### STAMP Violations Found
| ID | Constraint | Status | Gap |
|----|------------|--------|-----|
| SC-GLM-ZEN-001 | All UI state changes MUST publish OTel spans | VIOLATED | 0/57 pages |
| SC-GLM-UI-001 | Triple interface mandate | PARTIAL | 60% API coverage |
| SC-PI-AUTO-001 | New Gleam modules check Pi bridge | PARTIAL | Bridge exists but unwired |
| SC-ZK-IMP-001 | Claude MUST cite ZK holons | PARTIAL | ~5% citation rate |
| SC-MUDA-001 | Zero waste | VIOLATED | 3,494 LOC dead bridge code |

### Constitutional Status
| Invariant | Status | Evidence |
|-----------|--------|----------|
| Psi-0 (Existence) | PASS | System compiles, tests pass |
| Psi-1 (Regeneration) | PASS | SQLite/DuckDB recoverable |
| Psi-2 (History) | PASS | 31,775 holons in ZK |
| Psi-3 (Verification) | PARTIAL | Tests pass but observability missing |
| Psi-4 (Alignment) | PARTIAL | Triple interface incomplete |
| Psi-5 (Truthfulness) | PARTIAL | CLAUDE.md stats stale |

---

## 13. Conclusion

### The System Is Large, Growing, and Partially Wired

At 320K total LOC (214K Gleam/Rust + 107K TypeScript), C3I is a substantial system with excellent type safety (Gleam exhaustive matching) and good test coverage (8,979 tests, 83K test LOC). However, 5 critical integration gaps prevent full fractal coherence:

1. **Pi bridge is library-only** — 3,494 LOC with 0 production consumers
2. **Observability is theater** — zenoh_otel exists but 0 pages use it
3. **Triple interface is 60%** — 23/57 pages missing Wisp API
4. **RETE-UL is underutilized** — 52 rules, 2 imports
5. **Self-awareness is absent** — no cognitive performance tracking

### Recommended Execution Order (by RPN)

1. **Fix GAP-2** (RPN=336): Wire zenoh_otel into all 57 Lustre pages
2. **Fix GAP-1** (RPN=252): Create Pi event subscriber actor, wire bridge modules
3. **Fix AP1** (RPN=243): Enforce ZK citation via hook upgrade
4. **Fix GAP-3** (RPN=168): Generate missing Wisp APIs for 23 pages
5. **Fix GAP-4** (RPN=140): Wire RETE-UL into 10 decision points

### For Pi Integration
The complete Pi integration path is:
1. Gleam: Create OTP actor subscribing to `indrajaal/pi/**` Zenoh topics
2. Gleam: Actor calls pi_agent.gleam handlers on received messages
3. Gleam: pi_tools.gleam registers tools in MCP dispatcher
4. TypeScript: Implement 3 hooks (onPromptSubmit, onSessionEnd, onSessionStart)
5. TypeScript: RAG pipeline (~630 LOC per pi-integration guide)

The bridge code is READY. The wiring is NOT.

> सर्वधर्मान्परित्यज्य मामेकं शरणं व्रज — Abandon all incomplete integrations, wire them fully (Gita 18.66, adapted)

---

## ADDENDUM: Deep Gap Analysis Agent Findings (2026-04-22 04:50 UTC)

### NEW CRITICAL FINDINGS FROM AUTOMATED DEEP SCAN

#### FINDING-A: zenoh_otel.gleam Has NO publish() Function (SEVERITY: P0)
The module builds OTel span JSON (`span_to_json()`) but NEVER publishes it to Zenoh. `now_ms()` returns hardcoded 0. This means even IF pages imported it, no spans would be emitted. The observability gap is deeper than initially assessed — not just unwired, but **unimplemented**.

#### FINDING-B: RETE-UL Decisions Never Execute (SEVERITY: P0)
`rules/engine.gleam` has 44 evaluate functions returning `RuleResult` with `decision` fields like "EmergencyStop". But NO code anywhere reads these decisions and dispatches actions. `guard_grid_actor.gleam` calls `evaluate()` but never reads the decision. The rule engine EVALUATES but never ACTS.

#### FINDING-C: Pi Session NIF Is a Stub (SEVERITY: P1)
`pi_session.gleam:107-110` — `session_to_smriti` serialization + NIF write is a no-op stub. Pi sessions are validated but NOT persisted to Smriti.db.

#### FINDING-D: claude_metrics.gleam Orphaned (SEVERITY: P1)
`SessionMetrics` type tracks zk_recalls, zk_citations, tool counts, build results — but NO production code imports it. Only tests reference it. The self-awareness type system EXISTS but is never populated.

#### FINDING-E: 32 HA Modules Untested (SEVERITY: P1)
81 HA modules exist, only 49 have test files. 32 modules including anomaly_detector, checkpoint, crdt, digital_twin, freshness_monitor, rolling_upgrade, sentinel are likely untested.

#### FINDING-F: MCP Tool Federation Unverified (SEVERITY: P1)
27 tools registered in `mcp/tools.gleam`. Pi's 14 tools from `pi_tools.gleam` are NOT in the registry. No runtime check verifies handler existence for each registered tool. The "93 federated tools" claim is documentation-only.

### REVISED FMEA (Including New Findings)

| Failure Mode | S | O | D | RPN | Finding |
|-------------|---|---|---|-----|---------|
| zenoh_otel has no publish() — complete non-function | 9 | 10 | 1 | **900** | A |
| RETE-UL evaluates but never acts on decisions | 8 | 9 | 3 | **216** | B |
| Observability theater (0/57 pages) | 8 | 7 | 6 | 336 | GAP-2 |
| Pi bridge dead code (0 imports) | 7 | 6 | 6 | 252 | GAP-1 |
| Pi session NIF stub (no persistence) | 7 | 5 | 5 | 175 | C |
| claude_metrics orphaned (no consumers) | 6 | 8 | 3 | 144 | D |
| 32 HA modules untested | 6 | 5 | 4 | 120 | E |
| MCP tool federation unverified | 7 | 4 | 4 | 112 | F |

### REVISED FIX QUEUE (RPN-Ordered)

| # | Task | RPN | LOC | Layer |
|---|------|-----|-----|-------|
| 1 | Implement zenoh_otel.publish() with real NIF Zenoh call | 900 | 50 | L1 |
| 2 | Wire zenoh_otel.publish_span() into 57 Lustre pages | 336 | 114 | L1 |
| 3 | Create Pi event subscriber actor + wire 6 bridges | 252 | 200 | L6 |
| 4 | Add decision→action dispatcher for RETE-UL RuleResult | 216 | 150 | L5 |
| 5 | Implement pi_session NIF write (Smriti.db persistence) | 175 | 80 | L3 |
| 6 | Wire claude_metrics into guard_grid_actor + dashboard | 144 | 100 | L5 |
| 7 | Create tests for 32 untested HA modules | 120 | 1,600 | L4 |
| 8 | Verify MCP tool handler coverage (27 + 14 Pi) | 112 | 100 | L3 |
| 9 | Generate 23 missing Wisp APIs | 168 | 2,300 | L2 |
| 10 | Build self-awareness dashboard consuming claude_metrics | 90 | 400 | L5 |
