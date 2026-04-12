# Implementation Roadmap — From पूर्ण (Complete) to जीवित (Alive)
# कार्यान्वयन मार्गदर्शिका

**Date**: 2026-04-12
**From**: v22.10.1-PURNA (42/42 features built)
**To**: v23.0.0-JIVIT (100% activated, production-ready)
**Status**: APPROVED

---

## Phase 1: ACTIVATE (This Week) — तन्त्रिका सक्रिय

**Goal**: Transform passive modules into continuously running actors.
**Impact**: 21% alive → 100% alive.

### Task 1.1: OTP Actor — Freshness Monitor Loop
**Priority**: P0 | **Effort**: 4h | **Files**: server.gleam, new: actors/freshness_actor.gleam
**KPI Before**: 0 periodic NIF checks | **KPI After**: 6 NIF checks/minute

**Detailed Steps:**
1. Create `src/cepaf_gleam/actors/freshness_actor.gleam` (~150 lines)
2. Use `gleam/otp/actor` to create a gen_server-like process
3. State: `FreshnessActorState { monitor: FreshnessState, check_interval_ms: Int }`
4. On init: set timer for 10,000ms (10s)
5. On timer tick: call `freshness_monitor.check(state.monitor)`
6. If ControlAction != NoAction: execute action (log, reload, escalate)
7. Publish health to ETS via `beam_cache.put("freshness:status", ...)`
8. In server.gleam `start()`: spawn this actor after Mist starts
9. Tests: actor starts, timer fires, check produces result, ETS updated
10. `gleam build` + `gleam test` — 0 errors, 0 failures

### Task 1.2: OTP Actor — Self-Observer Loop
**Priority**: P0 | **Effort**: 4h | **Files**: new: actors/self_observer_actor.gleam
**KPI Before**: 0 invariant checks/minute | **KPI After**: 1 check/minute (60s cycle)

**Detailed Steps:**
1. Create `src/cepaf_gleam/actors/self_observer_actor.gleam` (~200 lines)
2. State: `SelfObserverActorState { observer: SelfObserverState, audit: AuditTrailState }`
3. On init: set timer for 60,000ms (60s)
4. On timer tick:
   a. Call `self_observer.check_all_invariants(current_state())`
   b. Build TruthAuditEntry from result
   c. Call `truth_audit.record(state.audit, entry)`
   d. If mismatch: publish to ETS `guard:observer:last_mismatch`
   e. Call `truth_audit.predict_next_failure(state.audit)` → log prediction
5. Publish audit summary to ETS: `truth:rate`, `truth:streak`, `truth:prediction`
6. In server.gleam: spawn after Mist starts
7. Tests: actor starts, check runs, audit accumulates, prediction works

### Task 1.3: OTP Actor — Guard Grid Loop
**Priority**: P0 | **Effort**: 4h | **Files**: new: actors/guard_grid_actor.gleam
**KPI Before**: Grid re-initialized each request | **KPI After**: Persistent grid in ETS

**Detailed Steps:**
1. Create `src/cepaf_gleam/actors/guard_grid_actor.gleam` (~200 lines)
2. State: `GuardGridActorState { grid: GuardGrid }`
3. On init: `guard_grid.init()` → store in ETS `guard:grid:state`
4. Accept messages:
   - `RecordVerdict(layer, module, verdict)` → update grid → store in ETS
   - `GetHealth` → reply with grid.health_score
   - `RunOODA` → full OODA cycle:
     a. Compute entropy, Rule 110, Lyapunov
     b. Run multi_rule_analysis() (10 CA rules)
     c. Evaluate 30 RETE-UL rules
     d. Execute highest priority action
     e. Record in ETS: `guard:ooda:last_action`, `guard:ooda:health`
5. Timer: run OODA every 10s
6. In server.gleam: spawn after Mist starts
7. Wire: invariant_gate sends RecordVerdict after each page guard
8. Wire: module_guard sends RecordVerdict after each API guard

### Task 1.4: Wire SLO Tracking into Request Pipeline
**Priority**: P1 | **Effort**: 2h | **Files**: router.gleam
**KPI Before**: 0 SLO events recorded | **KPI After**: Every request tracked

**Detailed Steps:**
1. In router.gleam `handle_request()`: wrap response pipeline
2. After route produces response:
   - Record `availability_slo`: status == 200
   - Record `latency_slo`: response time < 100ms (measure with `erlang:monotonic_time`)
   - Record `truth_slo`: guard passed (from invariant_gate result)
3. Store SLO state in ETS via beam_cache (since no actor yet)
4. Add `/api/v1/system/slo/live` endpoint reading from ETS
5. Tests: SLO events accumulate correctly

### Task 1.5: Wire Remaining 116 API Endpoints with module_guard
**Priority**: P1 | **Effort**: 3h | **Files**: router.gleam
**KPI Before**: 10/126 endpoints guarded | **KPI After**: 126/126 (100%)

**Detailed Steps:**
1. List all remaining `_json()` function calls in router.gleam
2. Wrap each with `module_guard.guard_json(output, endpoint_name, expected_field)`
3. For NIF-backed endpoints: use `module_guard.guard_nif(output, nif_name)`
4. For array endpoints: use `module_guard.guard_nif_array(output, nif_name)`
5. Build after every 10 endpoints to catch errors incrementally
6. Final: `gleam build` + `gleam test` — 0 errors

### Task 1.6: Wire Script Tags into All Remaining SSR Views
**Priority**: P1 | **Effort**: 2h | **Files**: system_views, domain_views, special_views
**KPI Before**: 10/31 views load JS | **KPI After**: 31/31 (100%)

**Detailed Steps:**
1. For each view that doesn't have a `<script>` tag:
   - Add `element.element("script", [attribute.attribute("src", "/static/{page}-grid.js?v=22.10.1")], [])`
2. Add static file routes in router.gleam for each new JS file
3. Build and verify

---

## Phase 2: RUST SUBCOMMANDS (This Week) — रस्ट आदेश

**Goal**: SC-RUST-TOOL-001 compliance. All operational tools in Rust.
**Impact**: Autonomous tooling without Claude.

### Task 2.1: `sa-plan-daemon fitness` Subcommand
**Priority**: P1 | **Effort**: 8h | **Files**: Rust — planning_daemon/src/fitness.rs + cli.rs
**KPI Before**: No fitness scoring | **KPI After**: `./sa-plan fitness` returns composite score

**Detailed Steps:**
1. Create `sub-projects/c3i/native/planning_daemon/src/fitness.rs` (~200 lines)
2. Implement fitness function:
   ```rust
   f = 0.30 × (tests/baseline) + 0.20 × (entropy/3.0) + 0.15 × (1000/build_ms)
     + 0.15 × (500/max_file) + 0.10 × (endpoints/30) + 0.10 × (1-warnings/10)
   ```
3. Shell out to `gleam build` and `gleam test` to get live metrics
4. Parse test count from output
5. Find max file size via `walkdir` crate
6. Count endpoints via regex on router.gleam
7. Output: JSON with score, grade (A/B/C/D), per-KPI breakdown
8. Add to cli.rs as `Fitness` subcommand
9. Add to `data/fitness-history.csv` for trend tracking
10. `cargo build` + `cargo test`

### Task 2.2: `sa-plan-daemon hot-reload` Subcommand
**Priority**: P1 | **Effort**: 4h | **Files**: Rust — planning_daemon/src/hot_reload_cmd.rs
**KPI Before**: Hot reload via HTTP only | **KPI After**: `./sa-plan hot-reload` from CLI

**Detailed Steps:**
1. Create `hot_reload_cmd.rs` (~100 lines)
2. Steps: `gleam build` → HTTP call to `localhost:4100/api/v1/reload` → report result
3. Verify build success before triggering reload
4. Output: modules reloaded, time taken, any errors
5. Add to cli.rs as `HotReload` subcommand

### Task 2.3: `sa-plan-daemon evolve-page` Subcommand
**Priority**: P2 | **Effort**: 12h | **Files**: Rust — planning_daemon/src/evolve_page.rs
**KPI Before**: Manual page evolution | **KPI After**: `./sa-plan evolve-page cockpit L5`

**Detailed Steps:**
1. Create `evolve_page.rs` (~400 lines)
2. Template system: read template files, substitute variables
3. Generate: JS file, SSR additions, WS handler snippet, test file, TUI view
4. Run `gleam build` to verify
5. Run `gleam test` to verify
6. Call `hot-reload` to activate
7. Output: files created, build result, test result

---

## Phase 3: ADVANCED INTELLIGENCE (This Month) — बुद्धि

**Goal**: Deeper pattern detection + predictive capability.
**Impact**: System predicts failures BEFORE they happen.

### Task 3.1: Persistent Guard Grid in ETS
**Priority**: P1 | **Effort**: 3h | **Files**: guard_grid_actor.gleam, guard_grid.gleam

**Detailed Steps:**
1. Guard grid actor (Task 1.3) stores grid state in ETS
2. Every module_guard call → sends RecordVerdict message to actor
3. Actor updates grid → re-computes entropy, Lyapunov
4. Dashboard WS reads from ETS instead of re-initializing grid
5. `/api/v1/system/guard-grid` reads persistent state

### Task 3.2: Connect Truth Audit to Self-Observer → Predictions
**Priority**: P1 | **Effort**: 2h | **Files**: self_observer_actor.gleam

**Detailed Steps:**
1. Self-observer actor (Task 1.2) already records to truth_audit
2. Add: after recording, call `truth_audit.predict_next_failure()`
3. If prediction confidence > 0.7: publish predictive alert to ETS
4. Dashboard shows: "Predicted: L1:nif_bridge may fail in next 2 hours (P=0.73)"

### Task 3.3: Additional Wolfram CA Rules
**Priority**: P2 | **Effort**: 4h | **Files**: guard_grid.gleam

**Detailed Steps:**
1. Add totalistic CA rules (sum of neighbors, not individual states)
2. Add 2D Wolfram on the 8×3 grid (not just 1D on 8 layers)
3. Add Brian's Brain (3-state: PASS/FAIL/RECOVERING)
4. Add Langton's Ant (trace failure propagation path)
5. Tests for each new rule

### Task 3.4: Mathematical Rules
**Priority**: P2 | **Effort**: 6h | **Files**: new: ha/math_analysis.gleam

**Detailed Steps:**
1. Kolmogorov complexity estimate: compress grid state, measure size
2. Mutual information I(layer_i; layer_j): which layers are coupled?
3. Transfer entropy TE(i→j): which layer CAUSES which? (directional)
4. Fractal dimension: are failures self-similar across scales?
5. Hurst exponent: are failures persistent (trend) or anti-persistent (mean-reverting)?

### Task 3.5: d(Health)/dt Calculus
**Priority**: P1 | **Effort**: 2h | **Files**: guard_grid.gleam or new: ha/health_calculus.gleam

**Detailed Steps:**
1. Store last N health scores (ring buffer in guard grid actor)
2. Compute first derivative: d(H)/dt = (H_now - H_prev) / Δt
3. Compute second derivative: d²(H)/dt² (acceleration of decline)
4. GR-030 already checks d(H)/dt < -0.1
5. Add: if d²(H)/dt² < 0 AND d(H)/dt < 0: "accelerating decline — EMERGENCY"

---

## Phase 4: AUTONOMOUS EVOLUTION (This Month) — स्व-विकास

**Goal**: System evolves itself without human intervention.
**Impact**: 24/7 improvement. Human only needed for novel situations.

### Task 4.1: CronCreate for 6-Hourly Evolution
**Priority**: P2 | **Effort**: 4h | **Files**: Claude RemoteTrigger/CronCreate

**Detailed Steps:**
1. Use Claude Code's CronCreate or RemoteTrigger
2. Schedule: every 6 hours
3. Prompt: "Run /fast-evolve on the highest-priority pending task"
4. Auto-commit results
5. Email summary to operator

### Task 4.2: Fitness-Gated Commits
**Priority**: P2 | **Effort**: 2h | **Files**: Rust fitness.rs + git hook

**Detailed Steps:**
1. Pre-commit hook calls `sa-plan-daemon fitness`
2. If score < 0.6 (Grade D): BLOCK commit with explanation
3. If score 0.6-0.8 (Grade C): WARN but allow
4. If score >= 0.8 (Grade B+): auto-commit
5. Log fitness score in commit message

### Task 4.3: Auto-Rollback on Fitness Regression
**Priority**: P2 | **Effort**: 3h | **Files**: Rust + rollback_controller integration

**Detailed Steps:**
1. Post-commit: run fitness check
2. Compare with previous score
3. If score dropped > 5%: auto-revert via `git revert HEAD`
4. Log rollback reason in truth audit
5. Alert operator

---

## Phase 5: PRODUCTION HARDENING (This Quarter) — उत्पादन

**Goal**: From development system to deployment-ready.
**Impact**: Can be deployed in real production environments.

### Task 5.1: OTP Release Packaging
**Priority**: P2 | **Effort**: 12h | **Files**: rebar3 config, .appup files

**Detailed Steps:**
1. Add rebar3 with Gleam plugin to build system
2. Create application callback module (otp_app.gleam)
3. Generate .rel (release specification)
4. Generate .appup per version (upgrade instructions)
5. Create sys.config template
6. Test: release upgrade from v22.10 to v23.0

### Task 5.2: CRDT State Synchronization
**Priority**: P3 | **Effort**: 20h | **Files**: new: substrate/crdt.gleam

**Detailed Steps:**
1. Implement G-Counter (grow-only counter) for distributed metrics
2. Implement OR-Set for distributed guard verdicts
3. Synchronize via Zenoh pub/sub
4. Merge function: mathematical CRDT merge (commutative, associative, idempotent)
5. Test: two nodes, network partition, merge after reunion

### Task 5.3: Multi-Region Zenoh Federation
**Priority**: P3 | **Effort**: 40h | **Files**: Zenoh config, gateway modules

**Detailed Steps:**
1. Configure Zenoh for multi-region routing
2. Region-aware key expressions: `indrajaal/{region}/health/**`
3. Cross-region health aggregation
4. Leader election across regions
5. Test: 3-region deployment with partition tolerance

### Task 5.4: IEC 61508 Evidence Package
**Priority**: P3 | **Effort**: 40h | **Files**: docs/certification/

**Detailed Steps:**
1. Safety Requirements Specification (SRS)
2. Safety Validation Plan
3. FMEA report (generated from fmea_generator.gleam)
4. Test coverage report (5,034 tests, Shannon H, CCM)
5. Formal verification evidence (TLA+ specs, ADT type proofs)
6. Runtime monitoring evidence (guard grid, truth audit)
7. Change management evidence (git history, Zettelkasten)

---

## Timeline Summary

```
WEEK 1: Phase 1 (Tasks 1.1-1.6) — ACTIVATE
  Day 1-2: OTP actors (1.1, 1.2, 1.3)
  Day 3: SLO wiring + API guards (1.4, 1.5)
  Day 4: Script tags + verification (1.6)
  Day 5: Integration testing

WEEK 2: Phase 2 (Tasks 2.1-2.3) — RUST
  Day 1-2: fitness subcommand (2.1)
  Day 3: hot-reload subcommand (2.2)
  Day 4-5: evolve-page subcommand (2.3)

WEEK 3-4: Phase 3 (Tasks 3.1-3.5) — INTELLIGENCE
  Persistent guard grid, truth predictions,
  additional CA rules, mathematical analysis, calculus

MONTH 2: Phase 4 (Tasks 4.1-4.3) — AUTONOMOUS
  CronCreate scheduling, fitness-gated commits, auto-rollback

MONTH 3: Phase 5 (Tasks 5.1-5.4) — PRODUCTION
  OTP releases, CRDT, multi-region, IEC 61508 certification
```

## Success Criteria

| Phase | Metric | Target |
|-------|--------|--------|
| 1 ACTIVATE | Active monitoring modules | 100% (was 21%) |
| 2 RUST | Operational subcommands | 3/3 in Rust |
| 3 INTELLIGENCE | Prediction accuracy | >70% |
| 4 AUTONOMOUS | Evolution sessions without human | 4/day |
| 5 PRODUCTION | SIL-4 evidence completeness | 100% |

---

*पूर्णात् जीवितं — From completeness arises life.*
*The system is built. Now it must breathe.*
