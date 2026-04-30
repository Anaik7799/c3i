# UI-Refactor Roadmap — 4 Remaining P1 Audit Items

**Tailscale**: https://vm-1.tail55d152.ts.net:8443/task-id/116492633621406288/task-116492633621406288/20260430-1040-ui-refactor-roadmap-4-p1-items.md

**Plan ID**: `116492633621406288`
**Date**: 2026-04-30 10:40 CEST · **Type**: P1 audit roadmap · **Author**: Claude

ZK lineage cited (SC-ZK-IMP-001):
- [zk-3346fc607a1ef9e6] **Stub-That-Lies (RPN 729)** — every phase ships verifiable evidence (gleam test count, Playwright screenshots, real Smriti.db rows).
- [zk-bb4de67d97f807ac] **selector-guessing** — refactor uses Marionette MCP to discover live DOM selectors before rewriting, never `grep` over JS source.
- [zk-ac3a58d6023e60bd] Pass-21 lineage — this roadmap continues the autonomous arc beyond the 100% cross-cutting closure.

## §1. Status & Scope

After Pass-23 the four open P1 items are all UI-side refactors:

| # | Item | Effort | Risk | Type |
|---|---|---:|---|---|
| CP2 | P1 #6 Collapse 3 grids → 1 + filter chips | ½ d | M | UI behaviour |
| CP3 | P1 #7 Split `planning-grid.js` (1894 LOC) → 5 modules | 2 h | **H** | live JS refactor |
| CP4 | P1 #8 Split `domain_views.gleam` (1657 LOC) → per-page | ½ d | M | Gleam refactor |
| CP5 | P1 #12 Owner + parent-id picker UI | 4 h | L | new component |

These four close the remaining audit gap (currently 19/22 = 86% → target 22/22 = 100%).

## §2. Sequencing — Risk-Ascending

Execute in **risk-ascending** order. Each phase ships independently:

```
Phase 1 (lowest risk): CP5 P1 #12 owner+parent-id picker (4 h)
                       ↓
Phase 2:               CP2 P1 #6 collapse 3 grids → 1 (½ d)
                       ↓
Phase 3:               CP4 P1 #8 split domain_views.gleam (½ d)
                       ↓
Phase 4 (highest risk): CP3 P1 #7 split planning-grid.js (2 h, but H risk)
```

Rationale: each phase reduces blast-radius for the next. CP5 is pure-additive (new component, no edits). CP2 uses the Pass-23 paginated endpoint (already shipped). CP4 splits Gleam (compile-time safety net). CP3 is last — by then the surrounding planning-page substrate is fully stabilised and tested.

## §3. Phase 1 — CP5 P1 #12 Owner + Parent-ID Picker UI (4 h, Risk: L)

### Goal
A reusable Lustre component that lets the operator select an owner (string) and parent-id (UUID) when creating or editing a task.

### AS-IS
Tasks are created via `sa-plan add` CLI; owner is set via env or empty; parent-id is set via `--parent` flag. No UI surface for these fields on the planning page.

### TO-BE
- New file: `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/components/owner_parent_picker.gleam` (~150 LOC)
- Lustre MVU: `Model { owner: Option(String), parent_id: Option(String), open: Bool }`
- `Msg`: `OpenPicker`, `ClosePicker`, `SelectOwner(String)`, `SelectParent(String)`, `Submit`
- New Wisp endpoint: `GET /api/v1/picker/options?type=owner|parent` returning autocomplete list
- TUI view: `lib/cepaf_gleam/src/cepaf_gleam/ui/tui/owner_parent_picker_view.gleam`
- 12 gleeunit tests covering MVU transitions

### Acceptance
- gleam build / test pass
- New Wisp endpoint returns valid JSON (`/api/v1/picker/options?type=owner` → `[{"id":"...","name":"..."}]`)
- Component renders without client JS (Lustre SSR)
- TUI view shows autocomplete list

### STAMP
SC-GLM-UI-001 (triple interface) · SC-AGUI-UI-001 (4 view modes — picker is overlay) · SC-A2UI (component spec)

### Effort breakdown
- Component MVU: 1.5 h
- Wisp endpoint: 1 h
- TUI view: 0.5 h
- Tests + journal + diagram: 1 h

---

## §4. Phase 2 — CP2 P1 #6 Collapse 3 Grids → 1 + Filter Chips (½ d, Risk: M)

### Goal
Replace `blocked-grid` + `active-grid` + `all-grid` (currently 3 separate Tabulator instances on `/planning`) with a single grid + status filter chips (Pending/InProgress/Blocked/Completed).

### AS-IS
- 3 Tabulator instances each polling `/api/v1/plan/list/{status}`
- Wastes ~3× client memory and 3× backend roundtrips
- Operator switches by scrolling, not filtering

### TO-BE
- Single Tabulator instance on `/planning`
- Filter chips above grid: `[All] [Pending 12] [In Progress 4] [Blocked 1] [Completed 234]`
- Click chip → uses Pass-23 `/api/v1/planning/page?status=X&limit=100`
- Counts in chips refresh from `/api/v1/plan/status` (already exists)

### Files modified
- `lib/cepaf_gleam/priv/static/planning-grid.js` — replace 3 grid sections with 1 + chip handler (~50 LOC delta, NOT a full rewrite — surgical)
- `lib/cepaf_gleam/src/cepaf_gleam/ui/web/domain_views.gleam` — emit single grid + chip section in HTML

### Acceptance
- All 6 DAG-M-R Rust E2E tests still pass
- Playwright screenshot shows single grid + 4 chips
- Round-trip: click each chip, verify URL updates and grid contents change
- Mobile: chips wrap, grid scrolls horizontally (existing 4-BP CSS preserved)

### STAMP
SC-AGUI-UI-001 (4 view modes) · SC-AGUI-UI-013 (DAG-Q transport parity) · SC-MUDA-001 (waste reduction: 3 grids → 1)

### Effort breakdown
- JS edit: 1.5 h
- Gleam HTML emit: 1 h
- Tests + Playwright verify: 1 h
- Journal + diagram: 0.5 h

---

## §5. Phase 3 — CP4 P1 #8 Split `domain_views.gleam` (½ d, Risk: M)

### Goal
Reduce `lib/cepaf_gleam/src/cepaf_gleam/ui/web/domain_views.gleam` from 1657 LOC to per-page modules (~80-150 LOC each).

### AS-IS
1657-line monolith with `view_planning`, `view_dashboard`, `view_immune`, `view_knowledge`, `view_zenoh`, etc. all in one file. Slow incremental compile, hard to navigate.

### TO-BE
```
ui/web/
  domain_views.gleam  (slim aggregator, re-exports per-page; ~50 LOC)
  pages/
    planning_view.gleam
    dashboard_view.gleam
    immune_view.gleam
    knowledge_view.gleam
    zenoh_view.gleam
    verification_view.gleam
    ...
```

### Procedure (Gleam compile-time-safe)
1. For each `view_X` function, create new file `ui/web/pages/X_view.gleam`.
2. Move function + its private helpers to new file.
3. Add `pub fn view_X(...)` re-export from `domain_views.gleam`:
   ```gleam
   import cepaf_gleam/ui/web/pages/planning_view
   pub fn view_planning(...) { planning_view.view(...) }
   ```
4. `gleam build` after each move proves no breakage.
5. Once all moved: leave `domain_views.gleam` as a thin façade or delete callers' import line by line.

### Acceptance
- gleam build/test pass at every commit
- No file > 1000 LOC after split (SC-FILESIZE-001)
- All Lustre + Wisp + TUI consumers still compile

### STAMP
SC-FILESIZE-001 · SC-MUDA-001 · SC-WIRE-001 (wiring guard catches any forgotten re-export)

### Effort breakdown
- Per-page extraction (×8): 2.5 h (~20 min each)
- Re-export façade + verify: 1 h
- Journal + diagram: 0.5 h

---

## §6. Phase 4 — CP3 P1 #7 Split `planning-grid.js` (2 h, Risk: H)

### Goal
Reduce `lib/cepaf_gleam/priv/static/planning-grid.js` from 1894 LOC to 5 modules (~300-400 LOC each).

### AS-IS
1894-line IIFE wrapping all planning-page client code. Risk: refactor breaks the live page that everyone uses.

### TO-BE
Five `<script>` files loaded sequentially, each its own IIFE, sharing via `window.__planningGrid` namespace:

```
priv/static/
  planning-core.js       — config, classifyFractalLayer, fetchWithRetry, snapshotData (~250 LOC)
  planning-columns.js    — Tabulator column definitions, formatters (~250 LOC)
  planning-views.js      — createGrid, switchView, kanban, timeline, analytics (~450 LOC)
  planning-filters.js    — initFractalFilters, AI search, status chips (Pass-2 chip handler) (~350 LOC)
  planning-realtime.js   — WebSocket, SSE, Gemma chat, change log (~600 LOC)
```

Loaded by `domain_views.gleam` (or its post-Phase-3 split):
```html
<script src="/static/planning-core.js?v=...">
<script src="/static/planning-columns.js?v=...">
<script src="/static/planning-views.js?v=...">
<script src="/static/planning-filters.js?v=...">
<script src="/static/planning-realtime.js?v=...">
```

### Risk mitigation
Phase 4 is HIGHEST RISK — refactoring an actively-used 1894-line IIFE. Mitigation:
1. **Marionette MCP discovery first**: attach to live `/planning` page via `mcp__marionette__connect`, snapshot interactive elements, capture all current selectors and global names.
2. **Multiverse branch**: develop in `multiverse/cp3-split-planning-grid` for isolated testing.
3. **Playwright regression suite**: run all 6 DAG-M-R Rust E2E tests + take screenshots after each split.
4. **Incremental commits**: one IIFE moved per commit; each commit verified by `node` syntax check + Playwright re-run.
5. **Rollback contract**: any failure → `git revert` and the page is back to the working monolith.
6. **Operator confirmation gate**: do NOT merge to main until operator confirms screenshots match.

### Acceptance
- 6 DAG-M-R Rust E2E tests pass on the multiverse branch
- Playwright screenshots show all 4 view modes (grid/kanban/timeline/analytics) functional
- WebSocket reconnect works
- Gemma AI chat works
- Page loads ≤ original load time (5 small files cache better than 1 large)

### STAMP
SC-FILESIZE-001 · SC-AGUI-UI-013 · SC-WIRE-001

### Effort breakdown
- Marionette discovery: 30 min
- Five-module split + namespace wiring: 1 h
- Playwright regression + verification: 30 min

---

## §7. Cross-Cutting Test Strategy

Each phase MUST extend the existing test pyramid:

| Tier | Phase 1 (Picker) | Phase 2 (1 Grid) | Phase 3 (Gleam Split) | Phase 4 (JS Split) |
|---|---|---|---|---|
| Unit (gleeunit) | 12 MVU tests | 4 chip filter tests | per-extracted-page tests | n/a |
| Integration (Wisp testing) | picker endpoint | paginated chip API | per-page render | n/a |
| E2E (Rust + Playwright) | n/a | screenshot + DAG-M | DAG-Q parity | **DAG-M-R full suite** |
| Property (proptest) | n/a | n/a | n/a | n/a (JS scope) |
| Formal (TLA+/Agda) | n/a | n/a | n/a | n/a |

## §8. Risk Register (FMEA)

| Phase | Failure mode | S | O | D | RPN | Mitigation |
|---|---|---:|---:|---:|---:|---|
| 1 | Picker doesn't render | 4 | 2 | 1 | 8 | Lustre SSR catches at build |
| 1 | Wisp endpoint 500 | 5 | 2 | 2 | 20 | unit test |
| 2 | Chip click breaks grid | 6 | 3 | 2 | 36 | DAG-M E2E + Playwright |
| 2 | Filter race with WS | 7 | 3 | 3 | 63 | debounce in chip handler |
| 3 | Forgotten re-export | 8 | 4 | 1 | 32 | gleam compile errors immediately |
| 3 | Circular import | 7 | 2 | 2 | 28 | layer discipline (pages → domain_views, never reverse) |
| 4 | Live page breaks | **9** | 4 | 3 | **108** | multiverse branch + screenshot regression + operator gate |
| 4 | Order-of-load JS error | 8 | 5 | 4 | **160** | namespace check + console.error trap in CI |
| 4 | Cache busts wrong | 6 | 4 | 5 | 120 | per-file build hash |

**Top RPN risks**: Phase 4 #2 (160) load-order, #1 (108) live-page break. Both mitigated by multiverse + screenshot regression + operator gate.

## §9. Closure Targets

| Phase | Closes | Cumulative audit | Cumulative deliverables |
|---|---|---:|---:|
| Pass-23 (this) | P1 #5 | 19/22 (86%) | 31 |
| Pass-24 (Phase 1) | P1 #12 picker | 20/22 (91%) | 32 |
| Pass-25 (Phase 2) | P1 #6 grid collapse | 21/22 (95%) | 33 |
| Pass-26 (Phase 3) | P1 #8 domain_views split | 22/22 (100%) | 34 |
| Pass-27 (Phase 4) | P1 #7 planning-grid.js split | 22/22 (100%) | **35 / 100% audit + 100% cross-cutting** |

## §10. Verification Gates Per Pass

Every phase's pass MUST publish:
- gleam build → 0 errors, 0 warnings
- gleam test → ≥ 9280 passed (no regression)
- New tests added (count varies by phase)
- Diagram (graphviz DOT → PNG @ 120 dpi)
- 13-section journal per SC-JOURNAL
- Email pack with attachments via `sa-plan send-email`
- ZK ingest via `sa-plan ingest-docs`
- sa-plan task → `completed`

For Phase 4 (highest risk): also Playwright screenshot pack + Marionette MCP discovery JSON.

## §11. Out-of-Scope

- F# CEPAF rewrites (separate workstream)
- Pi-mono symbiosis evolution (already at 93 federated tools)
- New Wallaby browser tests (Rust E2E suite is canonical per SC-PD-RUST-ONLY-001..010)
- Mobile-first overhauls (4-BP CSS already shipped Pass-13)
- New OTel spans (existing `zenoh_otel.gleam` covers the spec)

## §12. Operator Decision Points

Before each phase, operator may:
1. **Approve and proceed** (default for Phases 1-3 given low/medium risk)
2. **Modify scope** (e.g. defer Phase 4 indefinitely if 22/22 audit not required)
3. **Substitute** (e.g. swap Phase 3 for a different audit item)

For Phase 4 specifically: operator gate on multiverse branch screenshot match before merge.

## §13. Conclusion

This roadmap charts the path from current 19/22 audit (86%) to 22/22 (100%) via four risk-ascending phases. Phase 1 (CP5 picker) is the safest next move; Phase 4 (CP3 JS split) is reserved last so the surrounding substrate is fully stabilised + tested before touching the live IIFE.

**Estimated total effort**: 4 h + 4 h + 4 h + 2 h ≈ **14 h** of focused work spread across 4 passes.

**Awaiting operator decision** for Phase 1 kickoff (Pass-24).
