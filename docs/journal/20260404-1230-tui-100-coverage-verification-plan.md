# TUI 100% Coverage Verification Plan — All 12 Tabs

**Date**: 2026-04-04 12:30 CEST
**Author**: OpenCode Autonomous Agent
**Version**: v21.5.0-GLM
**Scope**: Complete wiring verification of all 12 TUI tabs, all elements, all state paths, all fractal layers. 100% functional coverage target.

---

## 1. Pre-State Assessment

### 1.1 Current Test Posture

| Metric | Value | Target | Gap |
|--------|-------|--------|-----|
| Total production LOC | 16,127 | — | — |
| Total tests | 253 | 500+ | -247 |
| Tests per 100 LOC | 1.57 | 3.0+ | -1.43 |
| Modules with tests | 13/20 (65%) | 20/20 (100%) | -7 |
| TUI tests (tui.rs) | 38 | 100+ | -62 |
| TUI tabs with ≥3 tests | 0/12 | 12/12 | -12 |
| TUI tabs with 0 tests | 3/12 (Tabs 8,9,10) | 0/12 | -3 |
| SC-TUI-TEST rules satisfied | 2/10 | 10/10 | -8 |

### 1.2 Per-Tab Coverage Matrix

| Tab | Name | Elements | Tests | Coverage | Wiring |
|-----|------|----------|-------|----------|--------|
| 0 | Swarm | 6 | 2 | ~40% | FULLY WIRED |
| 1 | Governor | 5 | 2 | ~40% | PARTIAL (heatmap static) |
| 2 | Checks | 4 | 2 | ~40% | PARTIAL (preflight/verify not populated) |
| 3 | Trace | 2 | 2 | ~40% | NOT WIRED (trace_entries never populated) |
| 4 | Topology | 3 | 1 | ~20% | FULLY WIRED |
| 5 | Build | 2 | 1 | ~20% | FULLY WIRED |
| 6 | NIF | 2 | 1 | ~20% | PARTIAL (nif_results/libc not populated) |
| 7 | Recovery | 2 | 1 | ~20% | PARTIAL (history not populated) |
| 8 | Fractal | 1 | 0 | **0%** | FULLY WIRED (L5-L7 always 0/0) |
| 9 | Security | 3 | 0 | **0%** | PARTIAL (libc not populated) |
| 10 | Raw Logs | 1 | 0 | **0%** | NOT WIRED (external crate) |
| 11 | Agent UI | 2 | 1 | ~20% | NOT WIRED (all hardcoded) |

### 1.3 Wiring Gaps in `refresh_state()`

| Field | Populated? | Tab(s) Using | Impact |
|-------|-----------|--------------|--------|
| `preflight_results` | ❌ NO | Tab 2 | Always shows "No checks run yet" |
| `verify_results` | ❌ NO | Tab 2 | Always shows "No checks run yet" |
| `trace_entries` | ❌ NO | Tab 3 | Always shows empty instructions |
| `total_preflight_ms` | ❌ NO | NONE | Dead field |
| `total_verify_ms` | ❌ NO | NONE | Dead field |
| `nif_results` | ❌ NO | Tab 6 | Always shows empty instructions |
| `libc_flavor` | ❌ NO | Tab 6, 9 | Always "unknown" |
| `recovery_history` | ❌ NO | Tab 7 | Always shows standby text |
| `boot_timeline` | ❌ NO | NONE | Dead field |
| `errors_60s` | ❌ NO | NONE | Dead field |
| `phase` | ❌ NO | Header | Always "Idle" |
| `active_playbooks` | ❌ NO | Tab 7 | Always empty |

### 1.4 Dead Code Fields

| Field | Declared | Read By Any Tab? | Recommendation |
|-------|----------|-----------------|----------------|
| `errors_60s` | Line 95 | NO | Remove or wire to Tab 0 |
| `total_preflight_ms` | Line 104 | NO | Remove or wire to Tab 2 |
| `total_verify_ms` | Line 106 | NO | Remove or wire to Tab 2 |
| `boot_timeline` | Line 113 | NO | Remove or wire to Tab 4 |

---

## 2. 100% Coverage Verification Plan

### Phase 1: Fix Wiring Gaps (P0 — Foundation)

**Goal**: Every field in `DashboardState` that is read by a tab MUST be populated by `refresh_state()`.

| Task | Field | Fix | Est Lines |
|------|-------|-----|-----------|
| 1.1 | `preflight_results` | Call `preflight::run_all()` in refresh_state, map to CheckResult | +30 |
| 1.2 | `verify_results` | Call `verify::run_all()` in refresh_state, map to CheckResult | +30 |
| 1.3 | `trace_entries` | Populate from recent log events during ignition | +40 |
| 1.4 | `nif_results` | Call `nif_validator::validate_all_nifs()` in refresh_state | +30 |
| 1.5 | `libc_flavor` | Call `nif_validator::detect_libc_flavor()` in refresh_state | +10 |
| 1.6 | `recovery_history` | Read from recovery execution log | +20 |
| 1.7 | `phase` | Update based on ignition state machine | +15 |
| 1.8 | `active_playbooks` | Update from active recovery operations | +15 |
| 1.9 | Remove dead fields | `errors_60s`, `total_preflight_ms`, `total_verify_ms`, `boot_timeline` | -20 |

### Phase 2: Missing Tab Tests (P0 — Tabs 8,9,10)

**Goal**: Every tab MUST have at least 3 tests (SC-TUI-TEST-001).

| Test | Tab | State | What to Verify |
|------|-----|-------|---------------|
| `test_draw_fractal_tab_default` | 8 | Default | No panic, L0-L7 headers visible |
| `test_draw_fractal_tab_with_containers` | 8 | Populated | Health bars, percentages, overall score |
| `test_draw_fractal_tab_no_containers` | 8 | Empty | All layers 0/0, overall 0% |
| `test_draw_security_tab_default` | 9 | Default | No panic, 3 panels visible |
| `test_draw_security_tab_contaminated` | 9 | Contaminated | Red CONTAMINATED banner |
| `test_draw_security_tab_musl` | 9 | musl libc | Yellow libc warning |
| `test_draw_logs_tab_default` | 10 | Default | Widget renders without panic |

### Phase 3: Populate-State Tests (P1 — All Tabs)

**Goal**: Every tab tested with realistic populated data, not just defaults.

| Test | Tab | What to Verify |
|------|-----|---------------|
| `test_draw_topology_tab_with_containers` | 4 | Health-colored nodes, DAG waves |
| `test_draw_build_tab_with_ema_data` | 5 | EMA table, bar chart, color coding |
| `test_draw_build_tab_db_unhealthy` | 5 | Warning banner for missing DB |
| `test_draw_nif_tab_with_results` | 6 | NIF table, pass/fail counts |
| `test_draw_nif_tab_contaminated` | 6 | Red contamination banner |
| `test_draw_recovery_tab_with_history` | 7 | Active playbooks, recovery counts |
| `test_draw_recovery_tab_all_playbooks` | 7 | All 15 rows render |
| `test_draw_agentui_tab_content` | 11 | Dialogue text, confidence score |
| `test_draw_checks_tab_with_preflight` | 2 | Preflight results with pass/fail icons |
| `test_draw_checks_tab_with_verify` | 2 | Verify results with pass/fail icons |
| `test_draw_trace_tab_with_entries` | 3 | Already exists — add flame bar assertions |
| `test_draw_governor_tab_with_history` | 1 | Sparkline with cpu_history data |

### Phase 4: Helper Function Tests (P1)

| Test | Function | What to Verify |
|------|----------|---------------|
| `test_sv_span_pass` | `sv_span()` | Green ✓ for true |
| `test_sv_span_fail` | `sv_span()` | Red ✗ for false |
| `test_failure_mode_label_all_15` | `failure_mode_label()` | All 15 labels correct |
| `test_failure_mode_container_all_15` | `failure_mode_container()` | All 15 mappings correct |

### Phase 5: State Transition Tests (P1)

| Test | What to Verify |
|------|---------------|
| `test_tab_cycling_all_12_indices` | All 12 tabs reachable via Tab/Shift+Tab |
| `test_backward_tab_cycling_from_zero` | Tab 0 + BackTab → Tab 11 |
| `test_all_ignition_phases_render` | Already exists — extend to all tabs |
| `test_trace_scroll_bounds` | Up at 0 stays 0, Down increases |
| `test_selected_container_bounds` | Up at 0 stays 0, Down bounded by len |

### Phase 6: types.rs Tests (P0 — 786 lines, 0 tests)

| Test | Function | What to Verify |
|------|----------|---------------|
| `test_quorum_threshold_2oo3` | `quorum_threshold(3)` | Returns 2 |
| `test_quorum_threshold_5` | `quorum_threshold(5)` | Returns 3 |
| `test_state_vector_all_valid` | `StateVector::is_valid()` | All true → valid |
| `test_state_vector_one_false` | `StateVector::is_valid()` | One false → invalid |
| `test_state_vector_all_false` | `StateVector::is_valid()` | All false → invalid |
| `test_dependency_graph_empty` | `DependencyGraph::calculate_waves()` | Empty graph → empty waves |
| `test_dependency_graph_linear` | `DependencyGraph::calculate_waves()` | A→B→C → 3 waves |
| `test_dependency_graph_parallel` | `DependencyGraph::calculate_waves()` | A→B, A→C → 2 waves |
| `test_boot_checkpoint_topic` | `BootCheckpoint::topic()` | All 10 variants |
| `test_boot_checkpoint_id` | `BootCheckpoint::id()` | All 10 variants |
| `test_health_status_default` | `HealthStatus` | Default is Unknown |
| `test_criticality_ordering` | `Criticality` | P0 > P1 > P2 > P3 |

### Phase 7: preflight.rs Tests (P0 — 1,331 lines, 0 tests)

| Test | Function | What to Verify |
|------|----------|---------------|
| `test_pf_check_result_pass` | `CheckResult` | Pass result structure |
| `test_pf_check_result_fail` | `CheckResult` | Fail result structure |
| `test_preflight_report_summary` | `PreflightReport` | Summary calculation |
| `test_preflight_all_passed` | `PreflightReport` | all_passed = true |
| `test_preflight_one_failed` | `PreflightReport` | all_passed = false |

### Phase 8: Content Assertion Tests (P2)

| Test | What to Assert |
|------|---------------|
| `test_swarm_tab_container_names_in_output` | Container names appear in rendered buffer |
| `test_governor_tab_cpu_gauge_label` | CPU percentage in gauge label |
| `test_checks_tab_state_vector_valid` | "VALID" text when all true |
| `test_trace_tab_flame_bar_ratio` | Flame bar width proportional to duration/timeout |
| `test_topology_tab_tier_labels` | Tier 0-4 labels present |
| `test_fractal_tab_layer_count` | 8 layers (L0-L7) displayed |
| `test_security_tab_panel_count` | 3 panels rendered |
| `test_recovery_tab_rpn_ordering` | RPN values in descending order |

### Phase 9: Edge Case Tests (P2)

| Test | What to Verify |
|------|---------------|
| `test_all_tabs_at_minimum_80x24` | All 12 tabs render at 80x24 |
| `test_all_tabs_at_ultrawide_300x80` | All 12 tabs render at extreme size |
| `test_build_tab_no_db` | "not found" banner |
| `test_nif_tab_unknown_libc` | "unknown" libc with yellow warning |
| `test_recovery_tab_empty_playbooks` | Table still renders 15 rows |
| `test_fractal_tab_no_containers` | All layers show 0/0, overall 0% |

---

## 3. Test Execution Plan

### 3.1 Test Count Targets

| Phase | New Tests | Cumulative Total |
|-------|-----------|-----------------|
| Current | — | 253 |
| Phase 1 | 0 (wiring fixes only) | 253 |
| Phase 2 | 7 | 260 |
| Phase 3 | 12 | 272 |
| Phase 4 | 4 | 276 |
| Phase 5 | 5 | 281 |
| Phase 6 | 12 | 293 |
| Phase 7 | 5 | 298 |
| Phase 8 | 8 | 306 |
| Phase 9 | 6 | 312 |

**Target: 312+ tests (from 253 current)**

### 3.2 Coverage Targets Per Tab

| Tab | Current Tests | Target Tests | Coverage % Target |
|-----|--------------|--------------|-------------------|
| 0 Swarm | 2 | 5 | 80% |
| 1 Governor | 2 | 4 | 80% |
| 2 Checks | 2 | 5 | 80% |
| 3 Trace | 2 | 4 | 80% |
| 4 Topology | 1 | 4 | 80% |
| 5 Build | 1 | 4 | 80% |
| 6 NIF | 1 | 4 | 80% |
| 7 Recovery | 1 | 4 | 80% |
| 8 Fractal | 0 | 3 | 80% |
| 9 Security | 0 | 3 | 80% |
| 10 Raw Logs | 0 | 2 | 60% (external crate limitation) |
| 11 Agent UI | 1 | 3 | 80% |

### 3.3 SC-TUI-TEST Compliance Matrix

| Rule | Requirement | Current Status | Target |
|------|------------|---------------|--------|
| SC-TUI-TEST-001 | ≥3 tests per tab | 0/12 tabs | 12/12 tabs |
| SC-TUI-TEST-002 | Snapshot tests | 0 | 36 (12 tabs × 3 viewports) |
| SC-TUI-TEST-003 | Color palette verification | 0 | 12 (1 per tab) |
| SC-TUI-TEST-004 | 3 viewport rendering | 2 tests (9 tabs) | 36 tests (12 tabs) |
| SC-TUI-TEST-005 | Keyboard shortcuts | 0 | 6 |
| SC-TUI-TEST-006 | Default state valid | ✓ MET | ✓ MET |
| SC-TUI-TEST-007 | No panics on empty data | Partial | ✓ MET |
| SC-TUI-TEST-008 | Status bar accuracy | 0 | 3 |
| SC-TUI-TEST-009 | Tab highlight | 0 | 2 |
| SC-TUI-TEST-010 | Health colors | 0 | 4 |

---

## 4. Implementation Order

1. **Phase 6** (types.rs tests) — foundation, no dependencies, pure functions
2. **Phase 1** (wiring fixes) — unblock all other phases
3. **Phase 2** (Tabs 8,9,10 tests) — close 0% coverage gaps
4. **Phase 4** (helper function tests) — quick wins
5. **Phase 3** (populate-state tests) — comprehensive tab coverage
6. **Phase 5** (state transition tests) — navigation verification
7. **Phase 7** (preflight.rs tests) — large module coverage
8. **Phase 8** (content assertions) — visual verification
9. **Phase 9** (edge cases) — boundary stress testing

---

## 5. Verification Gates

Before declaring 100% coverage achieved:

- [ ] `cargo test` passes with 312+ tests, 0 failures
- [ ] `cargo check` passes with 0 errors
- [ ] All 12 tabs have ≥3 tests (SC-TUI-TEST-001)
- [ ] All wiring gaps resolved (no dead fields, no unpopulated state)
- [ ] All 10 SC-TUI-TEST rules satisfied
- [ ] types.rs has ≥12 tests
- [ ] preflight.rs has ≥5 tests
- [ ] All tabs tested at 3 viewports (80x24, 120x40, 200x60)

---

**Version**: v21.5.0-GLM
**Status**: Plan created, ready for execution
**Next Action**: Phase 6 — types.rs tests (pure functions, no dependencies)
