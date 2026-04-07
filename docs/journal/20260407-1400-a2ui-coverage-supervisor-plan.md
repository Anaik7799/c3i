# Journal: A2UI Coverage Supervisor Plan

**Date**: 2026-04-07T14:00Z
**STAMP**: SC-ULTRA-001 #4, SC-A2UI-002, SC-MATH-COV-001, SC-MUDA-001

---

## 1. Scope & Trigger

User requested comprehensive A2UI + live data testing with Playwright, full dynamic behavior verification per page x component x 3 runs, Allium spec verification, and Muda-compliant coverage (no repetition).

## 2. Pre-State Assessment

| Metric | Value |
|--------|-------|
| gleeunit tests | 3,114 passed |
| Playwright tests | 113 (static rendering, API validation) |
| A2UI component render tests | 0 (catalog registration tested, but not HTML/ANSI render) |
| Dynamic behavior tests | 0 (no live data refresh, SSE, dark cockpit transition tests) |
| Allium spec verification | 0 |

## 3. Coverage Gap Analysis (Muda — What's NOT Already Covered)

### Already Covered (DO NOT REPEAT):
- Page routing (31 routes tested in wisp_tui_content_test, e2e_full_stack_test)
- Nav graph (31 pages, SCC=1, PageRank — c5_navigation_test, verification_prometheus_test)
- Fractal BDD 31x7 (217 tests — fractal_bdd_31x7_test)
- NIF-backed API endpoints (c3i_nif_mcp_test — 36 tests)
- MoZ dispatch (c3i_nif_mcp_test — 7 tests)
- OODA test monitor (ooda_test_monitor_test — 19 tests)
- A2UI catalog count, L7 components (a2ui_component_compliance_test)
- Playwright: page load, nav, API, keyboard, sort, filter, SSE, dark cockpit CSS

### NOT Yet Covered (Gaps to Fill):
1. **A2UI HTML/ANSI render**: 233 component types × 2 targets = 466 assertions
2. **Tripartite equivalence**: render to all 3 targets, verify structural consistency
3. **Live data behavior**: API returns different data on consecutive calls (timestamps change)
4. **Component interaction**: genome grid cells, OODA tier clicks, proof chain blocks
5. **Allium spec**: entity names match code, rule names match GRL, invariant names match Psi checks

## 4. Execution Plan (Small Batches)

### Batch A: A2UI Render Tests — Core + Layout + Data (46 types, 92 tests)
File: `test/a2ui_render_batch_a_test.gleam`

### Batch B: A2UI Render Tests — Status + Interactive (34 types, 68 tests)
File: `test/a2ui_render_batch_b_test.gleam`

### Batch C: A2UI Render Tests — Visualization + Agent + Safety (36 types, 72 tests)
File: `test/a2ui_render_batch_c_test.gleam`

### Batch D: Playwright Dynamic Behavior (20 tests)
File: `test/playwright/e2e_dynamic_behavior.spec.ts`
- Live data refresh (timestamp changes between calls)
- Dark cockpit mode transition (set body class, verify card opacity)
- Genome grid LED colors
- AG-UI SSE event receipt
- Component demo section count

### Batch E: Allium Spec Cross-Reference (10 tests)
File: `test/allium_spec_crossref_test.gleam`
- Entity names from ignition.allium match code types
- Rule names match GRL rule strings
- Invariant names match Psi check names

## 5. Expected Results

| Batch | Tests | Time Est |
|-------|-------|----------|
| A | 92 | ~30s |
| B | 68 | ~20s |
| C | 72 | ~25s |
| D | 20 | ~60s (browser) |
| E | 10 | ~5s |
| **Total** | **262** | **~140s** |

Post-completion target: 3,114 + 262 = **3,376 gleeunit** + **133 Playwright**

## 6. Artifacts Impacted

- `test/a2ui_render_batch_a_test.gleam` (NEW)
- `test/a2ui_render_batch_b_test.gleam` (NEW)
- `test/a2ui_render_batch_c_test.gleam` (NEW)
- `test/playwright/e2e_dynamic_behavior.spec.ts` (NEW)
- `test/allium_spec_crossref_test.gleam` (NEW)
- `CLAUDE.md` — test metrics update
- `docs/journal/` — this journal + results journal

## 7. Behavioral Improvements Expected

- **Coverage**: CCM will increase from ~0.77 toward 0.85+ as C6 (Media/Rich) and C7 (AI Advisory) categories get tested
- **Reliability**: Every A2UI component type verified to render without crash
- **Regression**: Any future component catalog change caught immediately
- **Allium Alignment**: Spec-code drift detected automatically
