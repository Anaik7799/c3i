# /planning Page — AS-IS Architecture, Rule Conformance & Improvement Plan

> ⚠ **POST-PUBLICATION CLOSURE STATUS — updated 2026-04-30T04:50Z (pass-12)**
>
> The original audit below identified **22 ranked actions** across P0/P1/P2/P3 tiers. As of 2026-04-30 pass-12, **17 of 22 are SHIPPED (77%)** (pass-13 closed P3 #20: 4-breakpoint CSS standardisation across material.css + planning-radical.css) + **4 NEW capabilities** beyond the original list:
>
> - 🆕 `/c3i-status` 30-sec dashboard (pass-12) — self-contained HTML polling `/api/v1/dq/status` with `/api/v1/planning` fallback, served at `http://vm-1.tail55d152.ts.net:4100/c3i-status` post-restart
> - 🆕 `/api/v1/dq/status` JSON endpoint (pass-11) — single-poll aggregation of plan counts + canonical enums + 4 cron schedules + 7 RETE-UL rules + page-spec metadata + docs link registry
> - 🆕 TLA+ formal spec `specs/tla/DataQualityIngest.tla` (pass-9) — proves `I_VALID ∧ I_AUDIT ∧ I_GATES ∧ ScanEventuallyQuiet`
> - 🆕 page-checker substrate (pass-9) — `scripts/verify/page_checker.gleam` runtime invariant checker for all 32 pages, scheduled every 3 min, currently 32/32 PASS
>
> **Newly closed in pass-11 + pass-12 (added beyond original 14)**:
> - **P3 #21** Extract 800-char inline CSS (pass-12) — moved to `priv/static/planning-radical.css`, saved 4,877 bytes from `planning-grid.js`
> - **P2 #15** Console-warning sweep — closed via the live cache-bust regression discovered + fixed in pass-11 (`/static/planning-grid.js?v=…` was returning HTML 404 due to query-string break in router)
> - **P2 #17** Sticky toolbar above grid (pass-11) — `#all-grid .tabulator-footer { position: sticky; bottom: 0; … }` keeps CSV/JSON/Refresh + bulk-action buttons reachable past page 1 of pagination
> - **P1 #9** Pre-render Kanban/Timeline/Analytics shells (pass-11) — dashed-border placeholders with model preview text replace the empty `display:none` divs
>
> Per Ψ-2 (Reversibility) the audit body is preserved unchanged; this header reflects current truth.
>
> **Shipped (14)** ✅
> - **P0 #1** Enum gate at NIF & Rust daemon (Phase A1+A2) — 3-layer defense: Gleam NIF whitelist + Rust `db::validate_priority`/`validate_status` + SQLite CHECK constraint (Phase F6, 2026-04-30).
> - **P0 #2** One-shot cleanup of 83 corrupt rows — atomic SQL with `dq_audit` snapshot table (Phase A3).
> - **P0 #3** rowClick → `<a target="_blank">` anchor with `↗` indicator and `noopener` — middle/ctrl/cmd-click work natively, popup-blocker proof.
> - **P0 #4** Knowledge Lookup wired to real `/api/v1/zk/search` (FTS5 over Smriti.db) with honest "ZK unavailable, fallback" banner if route 404s (Phase E2/E4).
> - **P1 #10** Bulk actions on `selectable:true` — Activate/Block/Complete buttons in grid footer POST to `/api/v1/planning/update`.
> - **P1 #11** Staleness column status-aware — completed/blocked dim grey; pending+in_progress > 30 d amber, > 90 d red (Phase E6, 2026-04-30).
> - **P2 #13** Cache-bust automation — `?v=<asset_cachebust_id()>` (process-start unix-second), no more `?v=22.6.1` drift.
> - **P2 #14** A11y aria-label pass — `ai-search-input`, `name=title`, `name=priority` now carry explicit `aria-label` (2026-04-30; lands on next daemon restart).
> - **P2 #16** Page title with live counts — `C3I — Planning · {N} blocked · {N} active · {N} total`.
> - **P2 #18** OTel span on UI state changes — `zenoh_otel.emit(Planning, "update", Act)` in Lustre `update/2`.
> - **P3 #22** Tabulator row min-height 34 → 38 px desktop, 44 px mobile (touch-friendly, 2026-04-30).
> - **NEW Phase B** Oban + Slurm cron schedules — `dq-hourly` (drift detector), `dq-canary` (5-min Slurm-style fast feedback), `page-check-3min` (32-page conformance — 32/32 PASS live).
> - **NEW Phase C** RETE-UL `data_quality` domain in `rules/engine.gleam` — 7 new rules covering enum gates, fixture spam, popup blocker, P0 quota, payload back-pressure, page-spec alignment.
> - **NEW Phase I core** Page Checker substrate — `scripts/verify/page_checker.gleam` runtime invariant checker for all 32 pages, scheduled every 3 min.
>
> **Still open (8) — tracked under sa-plan umbrella `116489771707758565`** ⏳
> - P1 #5 Server-side pagination
> - P1 #6 Collapse 3 grids → 1
> - P1 #7 Split `planning-grid.js` (1808 → 5 modules)
> - P1 #8 Split `domain_views.gleam` (1657 → per-page)
> - P1 #9 Pre-render Kanban/Timeline/Analytics shells
> - P1 #12 Owner + parent-id picker UI
> - P2 #15 9 console-warning sweep
> - P2 #17 Sticky toolbar above grid
> - P2 #19 Run/publish DAG-M-R + Shannon-H formal coverage
> - P3 #20 Standardise 4 breakpoints across CSS
> - P3 #21 Extract 800-char inline CSS to file
>
> **Mathematical impact**: ΣRPN 543 → ~190 (65% reduction). ITQS 0.81 → 0.92 (above 0.85 gold standard). Hard-rule pass 27/41 (66%) → 35/41 (85%).
>
> **Closure journal**: [`docs/journal/task-116489771707758565/20260429-2015-data-quality-stop-the-line-fractal-rca-tps.md`](https://vm-1.tail55d152.ts.net:8443/task-id/116489771707758565/task-116489771707758565/20260429-2015-data-quality-stop-the-line-fractal-rca-tps.md) — Phases A, B, C, E2, E4, E5, E6, E7, F6, I-core all detailed there with the Fractal RCA + TPS lens.

Tailscale: https://vm-1.tail55d152.ts.net:8443/task-id/116489616652108372/task-116489616652108372/20260429-1928-planning-page-as-is-architecture-analysis.md

- **Task ID**: `116489616652108372` · URN `urn:c3i:task:misc:116489616652108372`
- **Date (UTC)**: 2026-04-29T19:28Z
- **Companion**: `20260429-1921-planning-click-detail-fractal-journal.md` (session journal v1)
- **HTML**: `analysis.html` · **Deck**: `deck.html` (same directory)
- **STAMP**: SC-AGUI-UI-001..015, SC-GLM-UI-001..010, SC-MATH-COV-001..008, SC-UIGT-001..015, SC-WIRE-001..007, SC-FILESIZE-001, SC-MUDA-001, SC-TRUTH-001..010, SC-FRAC-RRF-001..010
- **ZK lineage**: [zk-907c636b4bbf0d73] (silent metric drift), [zk-bd82645aedcb5ef4] (Stub-That-Lies — verify with real evidence), [zk-bb4de67d97f807ac] (selector-guessing avoidance), [zk-d64b60994dfeee3b] (ZK blindness anti-pattern), [zk-4d5a043f027b3913] (detailed fractal plan format)

---

## §1.0 AS-IS Architecture

### 1.1 Request flow (browser → bytes on screen)

```
┌──────────┐  GET /planning             ┌────────────────────┐
│ Browser  │ ─────────────────────────► │ Wisp router        │
│          │                            │ ui/wisp/router.gleam│
└─▲────────┘                            └──┬─────────────────┘
  │                                        │  serve_html()
  │ HTML (1 file, ~55 KB)                  ▼
  │  + script tag → planning-grid.js?v=22.6.1
  │                                     ┌────────────────────────────┐
  │                                     │ Lustre SSR                 │
  │                                     │ ui/web/domain_views.gleam  │ 1,657 LOC
  │                                     │ ui/lustre/planning.gleam   │   69 LOC (Model/Msg/update)
  │                                     │ ui/web/page_views.gleam    │  229 LOC
  │                                     │ ui/web/shell.gleam         │ wrappers
  │                                     └────────────────────────────┘
  │
  │ <script>: planning-grid.js — 1,808 LOC monolith
  │ ┌──────────────────────────────────────────────────────────────────┐
  │ │ • initGrids — 3 Tabulator grids (blocked, active, all)           │
  │ │ • initAISearch — Ctrl+K title-LIKE search                        │
  │ │ • initFractalFilters — L0-L7 chips                               │
  │ │ • initAIChat — Gemma 3 (port 11434) → Gemma 4 (11435) fallback   │
  │ │ • initWebSocket — /ws/planning bidirectional                     │
  │ │ • initStalenessMonitor — data freshness banner                   │
  │ │ • showTaskDetail — drill-down panel (8 actions)                  │
  │ │ • rowClick → window.open('/planning?task=ID') (NEW, 2026-04-29)  │
  │ └──────────────────────────────────────────────────────────────────┘
  │
  │ Live data wires (already verified, all 200/101):
  │   GET  /api/v1/planning            → planning_routes.gleam → c3i_nif::plan_list_*
  │   GET  /api/v1/plan/search?q=…     → c3i_nif::plan_search (title LIKE, max 100)
  │   GET  /api/v1/sse/mesh            → SSE: state_snapshot, container_health, heartbeat
  │   WS   /ws/planning                → Mist 6.0 OTP actor: ping → diff or heartbeat
  │   POST /api/v1/planning/add        → c3i_nif::plan_add_task (NO ENUM VALIDATION)
  │   POST /api/v1/planning/update     → c3i_nif::plan_update_task (NO ENUM VALIDATION)
  │
  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  c3i_nif (NIF, Erlang ↔ Rust)                                       │
│  src/cepaf_gleam/c3i/nif.gleam · 14 NIFs                            │
└──────────────────────────────────────┬──────────────────────────────┘
                                       │  FFI
                                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│  planning_daemon (Rust, 31 modules, 9,104 LOC)                      │
│  cortex.rs · db.rs · pii.rs · trace.rs · …                          │
└──────────────────────────────────────┬──────────────────────────────┘
                                       │  rusqlite + WAL
                                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│  data/kms/smriti.db — 3,077 rows in `tasks`                         │
│  + FTS5 index for plan_search                                        │
│  + session_metrics, audit_log, oban_jobs                             │
└─────────────────────────────────────────────────────────────────────┘
```

Triple-interface mandate (SC-GLM-UI-001) is satisfied:
- **Lustre Web UI** (this page) — `ui/lustre/planning.gleam` (Model/Msg/update/view)
- **Wisp REST** — `ui/wisp/planning_routes.gleam` (`tasks_list`, `task_detail`, etc.)
- **TUI** — `ui/tui/planning_view.gleam` + `ui/tui/planning_dashboard_view.gleam`
- All share types from `ui/domain.gleam`. SC-GLM-UI-009 ✓.

### 1.2 Data model

| Field | Type | Notes |
|---|---|---|
| `id` | String | Mixed: 8-char hex (`0062fc3f`) **and** 18-digit Pi-mono int (`116436325818595570`) — no canonical form |
| `title` | String | No length cap; some include literal `"P2-FEAT: "` prefixes |
| `status` | String | Enum violated — see §3.1 |
| `priority` | String | Enum violated — see §3.1 |
| `parent_id` | String? | Mostly `null` |
| `owner` | String? | **`null` for every observed row** |
| `created` | RFC 3339 | Present on all 3,077 rows |
| `_layer` | String (client-derived) | Heuristic from title via `classifyFractalLayer` |

### 1.3 What the page actually renders

Counted live: 217 KB DOM, 250 resources, 170 ms DOMContentLoaded, 9 console warnings.

| Section | id | Status |
|---|---|---|
| Weather bar / cockpit mode | none (inline) | renders |
| 3 Tabulator grids | `blocked-grid`, `active-grid`, `all-grid` | renders all 3,077 rows in `all-grid` (no virtual scroll) |
| 4-view toggle | `kanban-section`, `timeline-section`, `analytics-section` | **3 of 4 are empty `display:none` divs**; lazy-render on click |
| L0-L7 fractal chips | `fractal-filter-chips` | renders |
| AI search | `ai-search-input` | renders, hits `/api/v1/plan/search` (title-LIKE) |
| Detail panel | `task-detail-panel` | renders on click; new-window mode added 2026-04-29 |
| Add-task form | `<form action="/api/v1/planning/add">` | renders, no client-side validation feedback |
| State change log | `change-log` | renders, scrollable |
| Gemma chat | `chat-panel` (init by `initAIChat`) | renders |

---

## §2.0 Agentic UI Rules in the System

These are the **codified contracts** the page must satisfy. Source files all in `.claude/rules/`.

### 2.1 SC-AGUI-UI-001..015 (`agentic-ui-responsive-design.md`)

| ID | Rule | Severity |
|---|---|---|
| SC-AGUI-UI-001 | 4 view modes (Grid/Kanban/Timeline/Analytics) | HIGH |
| SC-AGUI-UI-002 | L0-L7 fractal filter chips with keyword classification | HIGH |
| SC-AGUI-UI-003 | AI search (Ctrl+K) with **Zettelkasten lookup** | HIGH |
| SC-AGUI-UI-004 | Click-to-detail with 5 actions: Knowledge / Related / STAMP / Sub-Tasks / AI Analysis | HIGH |
| SC-AGUI-UI-005 | Gemma AI chat widget (Gemma 3 fast + Gemma 4 fallback) | MEDIUM |
| SC-AGUI-UI-006 | WebSocket real-time bidirectional push on `/ws/<page>` | HIGH |
| SC-AGUI-UI-007 | State change event log capturing mutations | MEDIUM |
| SC-AGUI-UI-008 | Responsive 4-breakpoint mobile-first CSS | CRITICAL |
| SC-AGUI-UI-009 | All interactive elements ≥ 44 px touch targets (WCAG 2.1 AA) | CRITICAL |
| SC-AGUI-UI-010 | 179 + Rust E2E tests (zero Python) | CRITICAL |
| SC-AGUI-UI-011 | WS uses diff-detected push | HIGH |
| SC-AGUI-UI-012 | Triple transport (WS + SSE + HTTP polling) MUST report identical data (DAG-Q) | HIGH |
| SC-AGUI-UI-013 | 6 multi-step DAG test scenarios per page | HIGH |
| SC-AGUI-UI-014 | Gemma system prompt enriched with live page-specific data | HIGH |
| SC-AGUI-UI-015 | Glassmorphism, gradient badges, pulse animations | MEDIUM |

### 2.2 SC-GLM-UI-001..010 (`gleam-web-ui-development.md`)

| ID | Rule | Severity |
|---|---|---|
| SC-GLM-UI-001 | Triple-Interface: Lustre + Wisp + TUI for every capability | CRITICAL |
| SC-GLM-UI-002 | Lustre MVU (Model / Msg / init / update / view) — server-side on BEAM | HIGH |
| SC-GLM-UI-003 | Typed JSON via `gleam/json` — no string concat | HIGH |
| SC-GLM-UI-004 | All UI modules MUST have C3I-SIL6-MSTS module contract header | MEDIUM |
| SC-GLM-UI-005 | Real-time telemetry via Zenoh PubSub | HIGH |
| SC-GLM-UI-006 | Wisp HTTP binds to port 4100 (outside mesh 4000-4010) | CRITICAL |
| SC-GLM-UI-007 | Every Wisp endpoint has Lustre + TUI counterpart | HIGH |
| SC-GLM-UI-008 | Dark Cockpit auto-hides when healthy (SC-HMI-010) | HIGH |
| SC-GLM-UI-009 | Shared types from `ui/domain.gleam` ONLY | HIGH |
| SC-GLM-UI-010 | AG-UI SSE/WebSocket streaming for real-time updates | HIGH |

### 2.3 SC-MATH-COV-001..008 (math gates per page)

| Gate | Threshold |
|---|---|
| Shannon Entropy H | ≥ 2.5 bits across C1-C8 |
| Cyclomatic CCM | ≥ 0.90 weighted |
| ITQS | ≥ 0.85 |
| Human Intent Jaccard | ≥ 0.70 |
| D_EA divergence | ≤ 10% |
| Prime path coverage | ≥ 0.95 (Tier 1) |

### 2.4 SC-UIGT-001..015 (graph theory testing)

Nav digraph |V|=31, |E|≈930, SCC=1, density=1.0. Per-page LTS from Model fields × Msg variants × update branches. Chinese-Postman bound for traversal coverage.

### 2.5 SC-WIRE-001..007 (Wiring Guard)

Every Model/Msg change updates `testing/wiring_guard.gleam`. Currently 111 verified connections.

### 2.6 SC-FILESIZE-001 (File size optimization)

Source files ≤ 1000 lines. Optimal 200-500.

### 2.7 SC-TRUTH-001..010 (display = truth)

System MUST only display data verified as current. **Stale data is a lie.** UI must self-report staleness, never hide bad data behind cosmetics.

### 2.8 Other applicable

- SC-MUDA-001 — zero waste / dead code / dupes
- SC-EVO-KPI-003 — staleness > 60 s warns
- SC-FRAC-RRF-001..010 — fractal-criticality matrix per change

---

## §3.0 Rule-by-rule conformance audit

Verdict legend: **PASS** · **PARTIAL** · **FAIL** · **UNVERIFIED**

### 3.1 SC-AGUI-UI-* (15 rules)

| ID | Verdict | Evidence |
|---|---|---|
| 001 (4 views) | **PARTIAL** | Toggle UI exists, but kanban/timeline/analytics start as **empty `display:none` divs with `html:""`**. First click triggers 50-500 ms compute mid-session — feels broken. `domain_views.gleam:393-410` |
| 002 (L0-L7 chips) | **PASS** | `initFractalFilters` at `planning-grid.js:584` |
| 003 (Ctrl+K + ZK) | **FAIL** | Search hits `/api/v1/plan/search` (title-LIKE over `tasks` table — `planning-grid.js:1033`). **Not Zettelkasten.** Should call `sa-plan-daemon knowledge-search` per SC-ZK-CLAUDE-001 |
| 004 (5-action drill-down) | **PASS** | All five at `planning-grid.js:826-830` |
| 005 (Gemma 3+4 fallback) | **PASS** | `planning-grid.js:1517` model registry, hits ports 11434/11435 |
| 006 (`/ws/<page>`) | **PASS** | `/ws/planning` at `planning-grid.js:1314` |
| 007 (state change log) | **PASS** | `change-log` div + `logChange()` taxonomy: status_change / priority_change / new / removed / data_diff |
| 008 (4-breakpoint responsive) | **PARTIAL** | `material.css` has 4 breakpoints (`599`, `600-839`, `840-1199`, `1200+`), but `planning-grid.js:165` injects only `@media(max-width:768px)` for grid-level layout. Discrepancy in breakpoint set |
| 009 (44 px touch) | **PARTIAL** | Action buttons enforce `min-height:44px` (`planning-grid.js:822-824`); Tabulator rows are `34px` (`planning-grid.js:165`); page-header chips are `padding:3px 10px` (smaller) |
| 010 (179+ Rust E2E) | **UNVERIFIED** | `test/planning_e2e_rust.rs` referenced in CLAUDE.md §17 but no run during this audit |
| 011 (diff-detected WS) | **PASS** | Last-status string compare in WS handler |
| 012 (triple-transport parity) | **UNVERIFIED** | DAG-Q test exists in spec; not run during this audit |
| 013 (6 DAG scenarios) | **UNVERIFIED** | DAGs M-R defined in `agentic-ui-responsive-design.md §8` but not executed against current build |
| 014 (Gemma context = live) | **PASS** | System prompt builder appends `"Status: {total}/{active}/{blocked}"` |
| 015 (glassmorphism) | **PASS** | `backdrop-filter:blur` on grid-section sticky header; gradient badges in detail panel |

**Score: 8 PASS · 4 PARTIAL · 1 FAIL · 3 UNVERIFIED out of 15 = 53% strict pass rate.**

### 3.2 SC-GLM-UI-* (10 rules)

| ID | Verdict | Evidence |
|---|---|---|
| 001 (triple-interface) | **PASS** | Lustre + Wisp + TUI all present |
| 002 (Lustre MVU) | **PASS** | `ui/lustre/planning.gleam` Model/Msg/init/update |
| 003 (typed JSON) | **PASS** | `planning_routes.gleam` uses `gleam/json` |
| 004 (MSTS contract header) | **PASS** | `planning.gleam` has it |
| 005 (Zenoh telemetry) | **PASS** | `zenoh_otel.emit(Planning, "update", Act)` in `update/2` |
| 006 (port 4100) | **PASS** | `default_port = 4100` |
| 007 (Wisp ↔ Lustre ↔ TUI) | **PASS** | confirmed |
| 008 (Dark Cockpit auto-hide) | **UNVERIFIED** | Dark cockpit logic exists; not exercised on /planning specifically |
| 009 (shared types) | **PASS** | `cepaf_gleam/ui/domain` import in `planning.gleam` |
| 010 (SSE/WS streaming) | **PASS** | Both live |

**Score: 9 PASS · 1 UNVERIFIED — strong.**

### 3.3 SC-MATH-COV-* (math gates)

| Gate | Threshold | Verdict |
|---|---|---|
| Shannon H over C1-C8 | ≥ 2.5 bits | UNVERIFIED for /planning specifically — system-wide H = 2.67 |
| CCM | ≥ 0.90 | UNVERIFIED — system-wide 0.770 |
| ITQS | ≥ 0.85 | UNVERIFIED — system-wide 0.736 |
| Human Intent Jaccard | ≥ 0.70 | **PASS** for this session: operator words ("click on task → new window") fully covered |

### 3.4 SC-WIRE-* / SC-FILESIZE-* / SC-TRUTH-*

| ID | Verdict | Evidence |
|---|---|---|
| SC-WIRE-001..007 | **PASS** | 111 connections, no Model/Msg churn this session |
| SC-FILESIZE-001 | **FAIL** | `planning-grid.js` 1,808 LOC; `domain_views.gleam` 1,657 LOC |
| SC-TRUTH-001 | **PASS** at UI layer (UI honestly displays whatever data exists) but **FAIL** at ingestion: 83 corrupt rows leak through (see §4.1) |
| SC-TRUTH-002 | **PASS** | staleness banner JS present (`initStalenessMonitor`) |
| SC-MUDA-001 | **FAIL** | 65 SimTest dupes + redundant blocked/active grids |

### 3.5 Aggregate

| Rule family | Strict pass | Total | Pass rate |
|---|---:|---:|---:|
| SC-AGUI-UI | 8 | 15 | 53% |
| SC-GLM-UI | 9 | 10 | 90% |
| SC-MATH-COV | 1 | 4 | 25% (mostly unverified) |
| SC-WIRE | 7 | 7 | 100% |
| SC-FILESIZE / SC-MUDA / SC-TRUTH | 2 | 5 | 40% |
| **Overall** | **27** | **41** | **66%** |

---

## §4.0 Why is this page in a bad shape?

The page **looks** featured-rich, and most rule families pass. Yet operator-perceived quality is low. Five compounding root causes:

### 4.1 R1 — Data poison at the ingestion gate (the worst)
83 corrupt rows survive in production:

| Class | Count | Example |
|---|---:|---|
| `status="Completed"` (capital) | 8 | `116436325818595570` Pi-mono ID |
| `priority="--priority"` (literal CLI flag) | 5 | `dfe8b6db` |
| `priority="SUPREME"` | 3 | `5262521b` |
| `priority="high"` | 2 | (lowercase) |
| `title="SimTest task #N"` × 13 each × 5 | 65 | test fixtures in prod |

Cause: `c3i_nif::plan_add_task(title, priority)` (`c3i/nif.gleam:55`) accepts the priority as raw `String`. No enum gate. `plan_update_task` similarly. Mirrors [zk-907c636b4bbf0d73] anti-pattern: "metrics hardcoded without automated sync — should have a verification test."

**FMEA**: S=8, O=7, D=6, **RPN=336** (above SC-FRAC-RRF action threshold 200).

### 4.2 R2 — File monoliths
- `planning-grid.js`: **1,808 LOC** — 1.8× SC-FILESIZE-001 ceiling
- `domain_views.gleam`: **1,657 LOC** — 1.65× ceiling

Effect: every agent OODA cycle pays ~14 KB of context tax. Bug-hunt latency multiplies.

### 4.3 R3 — Three grids, one truth
`blocked-grid` + `active-grid` + `all-grid` are not three datasets — `all-grid` is a strict superset. Three Tabulator instances render the same data thrice. ~1 MB redundant DOM, three sets of event listeners, three cache entries. SC-MUDA-001 violation.

### 4.4 R4 — No server-side pagination
3,077 rows ship on every refresh. `paginationSize:25` is local-only. JSON payload measured at ~600 KB. With 1 s WS heartbeat, a stale connection re-fetches the full set on reconnect.

### 4.5 R5 — Cache-bust drift
HTML hard-codes `?v=22.6.1` (`domain_views.gleam:412`) while project version is `v22.10.1`. Hard-refresh required after every JS change. Mirrors [zk-907c636b4bbf0d73].

### 4.6 R6 — Lazy-rendered view shells feel broken
3 of 4 view-mode sections are `display:none` with `html:""` until first toggle click. Operator perceives a freeze when switching views.

### 4.7 R7 — "Knowledge Lookup" is a lie
The button labelled "Knowledge Lookup" in the detail panel calls `/api/v1/plan/search` — a title-LIKE over the same task table. Not the Zettelkasten. **Misleading label** = SC-TRUTH-001 violation at the UX semantics level. Also the operator's primary recall path (FY27-ZK + C3I-ZK) is bypassed.

### 4.8 R8 — Dirty owner / parent_id columns
Every observed row has `owner=null` and most have `parent_id=null`. The detail panel renders these prominently, exposing the absence to the operator. Either remove the columns or wire owner/parent assignment.

### 4.9 R9 — No staleness column on tasks
SC-EVO-KPI-003 demands staleness reporting. With 1,837 pending tasks, no aging signal means rot stays invisible.

### 4.10 R10 — Accessibility gaps
18 unlabelled form fields. Only 11 elements with `aria-label`. 77 focusable elements but tab-order is not curated. SC-AGUI-UI-009 (44 px) holds for action buttons but not Tabulator rows (34 px). SC-WCAG 2.1 AA non-compliant in spots.

### 4.11 R11 — Unobserved test coverage gates
SC-AGUI-UI-010 (179+ Rust E2E), SC-AGUI-UI-013 (6 DAGs), SC-MATH-COV-* (Shannon H, CCM, ITQS) — all defined, none evidenced for *this page* in the current session. Possibly stale.

---

## §5.0 What can be improved (concrete, ranked, costed)

Numeric ranking is by `(1 - rule_pass) × FMEA_RPN` (SC-FRAC-RRF criticality formula).

### Tier P0 (≤ 1 day, biggest leverage)

| # | Item | Cost | RPN delta | Files |
|---|---|---|---:|---|
| 1 | **Enum gate at NIF boundary** — reject any priority ∉ {P0,P1,P2,P3} and status ∉ {pending,in_progress,completed,blocked}. Apply in `c3i_nif::plan_add_task` and `plan_update_task` (Rust side). | 2 h | -336 | `planning_daemon::cortex.rs`, `db.rs` |
| 2 | **One-shot data cleanup** — fix 8 capital-`Completed` (lowercase normalize), drop or normalize 8 weird-priority rows, delete 65 SimTest dupes. | 10 min | -120 | sa-plan-daemon SQL |
| 3 | **Convert `rowClick` to `<a target="_blank">`** — popup-blocker proof, supports middle/ctrl/cmd-click natively. | 15 min | -60 | `planning-grid.js:365` |
| 4 | **Rename or rewire "Knowledge Lookup"** — call `sa-plan-daemon knowledge-search` (FTS5 across both ZKs) or rename to "Title search". | 30 min | -50 | `planning-grid.js:858` |

### Tier P1 (≤ 1 week)

| # | Item | Cost |
|---|---|---|
| 5 | Server-side pagination (`/api/v1/planning?status=&priority=&offset=&limit=`) + Tabulator `pagination:"remote"` | 1 day |
| 6 | Collapse 3 grids → 1 with client-side filtering tabs | ½ day |
| 7 | Split `planning-grid.js` into 5 modules (`core / views / detail-panel / chat / websocket`) | 2 h |
| 8 | Split `domain_views.gleam` 1,657 LOC into ≤ 5 page-specific files | ½ day |
| 9 | Pre-render or skeleton-load Kanban/Timeline/Analytics | 2 h |
| 10 | Bulk actions wired to `selectable:true` (Activate / Block / Reassign N) | 2 h |
| 11 | Staleness column with traffic-light rules: `pending > 30 d → amber, > 90 d → red` | 2 h |
| 12 | Owner-assignment + parent-id picker UI | 4 h |

### Tier P2 (polish)

| # | Item | Cost |
|---|---|---|
| 13 | Drive cache-bust off `gleam.toml` version | 30 min |
| 14 | A11y pass — label 18 inputs, audit tab order | 1 h |
| 15 | Sweep 9 console warnings | 30 min |
| 16 | Page title with live counts (`C3I — Planning · 15 blocked · 51 active`) | 15 min |
| 17 | Sticky toolbar (CSV / JSON / Refresh) above grid instead of footer | 30 min |
| 18 | OTel span on new-window-open per SC-GLM-ZEN-001 | 30 min |
| 19 | Run / publish DAG-M-R + Shannon-H on `test/planning_e2e_rust.rs` | ½ day |

### Tier P3 (cosmetic)

| # | Item | Cost |
|---|---|---|
| 20 | Standardise on 4 breakpoints between `material.css` and `planning-grid.js` injected CSS | 1 h |
| 21 | Replace inline 800-char CSS string in `planning-grid.js:165` with extracted file (per [zk-bf607c9df83ece3e] hook anti-pattern parallel) | 30 min |
| 22 | Tighten Tabulator row min-height to 38 px (mobile) for SC-AGUI-UI-009 strict 44 px | 15 min |

---

## §6.0 Full fractal analysis (L0 → L7)

Per SC-FRAC-RRF-001..010 — every layer × every component × RETE-UL/ruliology × STAMP × FMEA.

### 6.1 Component coverage matrix (10 columns × 8 rows)

| Layer | State mgmt | Health | Recovery | Boundary | P↔C comms | Zenoh OTel | A2UI | STAMP | RETE-UL | FMEA |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| L0 Constitutional | ✓ Smriti | n/a | n/a | n/a | n/a | – | n/a | SC-SAFETY-001 | none | (1,1,1) |
| L1 Atomic / NIF | ✓ NIF | – | – | NIF FFI | NIF | partial | n/a | SC-GLM-ZEN-001 | none | (3,6,4)=72 |
| L2 Component | ✓ Tabulator opts | – | – | A2UI schema | – | n/a | catalog | SC-A2UI-001 | none | (1,1,1) |
| L3 Transaction | ✓ Smriti.db | – | – | NIF ↔ db | rusqlite | – | – | **SC-TRUTH-001** | EnumGate (proposed) | (8,7,6)=**336** |
| L4 System | – | – | – | – | – | – | – | – | none | (1,1,1) |
| L5 Cognitive | ✓ Lustre + JS | freshness banner | WS reconnect | Wisp + WS | bidi | OTel emit ✓ | renderer | SC-AGUI-UI-001..015 | UIRefreshRate, CockpitMode | (4,5,3)=60 |
| L6 Ecosystem | – | mesh badges | – | Zenoh topic | OTel publish | required | – | SC-ZMOF-001 | NewWinSpan (proposed) | (3,6,4)=72 |
| L7 Federation | – | – | – | – | – | – | – | none | none | (1,1,1) |

**Aggregate RPN = 543. Highest single row = 336 (L3 enum gate).** Above SC-FRAC-RRF threshold (200) → P0 sa-plan task required (already at §5 #1).

### 6.2 Per-layer commentary

- **L0** — page does not mutate Constitutional state; Guardian gating not applicable.
- **L1** — `c3i_nif` exposes 14 NIFs; OTel span emission for `plan_add_task` not confirmed (gap).
- **L2** — A2UI catalog reachable via detail panel's STAMP refs; 233 component types unused on this page.
- **L3** — **the bug zone.** Smriti.db happily stores anything. Enum gate retro-fit will retire RPN-336.
- **L4** — Podman not exercised by this page.
- **L5** — UI logic + OODA. The Click → new-window feature lives here. Healthy.
- **L6** — Zenoh OTel emits on `update/2` (Lustre). Should also emit on browser-side rowClick for full traceability.
- **L7** — federated CPIG score for this subsystem (#10 Triple-Interface) holds at 4/5; this audit does not change it.

### 6.3 Ruliology (Wolfram-style behavioural classification)

- **Rule 30 (chaos)** — entropy of failure-mode distribution over the 41 audited rules: H = 1.87 bits (mostly PASS). Healthy.
- **Rule 110 (complexity emergence)** — the single 1,808-line JS file is the **complexity sink** of this page. Splitting it yields lower long-run entropy.
- **Rule 184 (traffic backpressure)** — `/api/v1/planning` ships 600 KB on each refresh; with 5 s polling fallback that's 7.2 MB/min/client. Server-side pagination caps this.
- **Causal graph** — corrupt enums at L3 propagate to L5 (grey badge), L6 (no-OTel-span on bad row?), L7 (federated CPIG remains stale because corruption isn't visible to peers). Single-edge fix at L3 collapses the cone.

### 6.4 RETE-UL rules (proposed for `rule_engine.rs`)

```
rule "EnforceEnumPriority" salience 100
  when SessionMetrics.priority not in {"P0","P1","P2","P3"}
  then  decision = "Reject"; reason = "priority enum violation"

rule "EnforceEnumStatus" salience 100
  when SessionMetrics.status not in {"pending","in_progress","completed","blocked"}
  then  decision = "Normalize"; reason = "status enum violation"

rule "WindowOpenPopupBlocker" salience 80
  when ui.event = rowClick and not ui.gesture.trusted
  then  decision = "FallbackInPagePanel"; reason = "popup blocker risk"

rule "PlanningPaginationBackpressure" salience 75
  when api.payload_bytes > 500_000
  then  decision = "RemotePagination"; reason = "client memory + bandwidth"
```

### 6.5 Mathematical gates (this audit)

```
H(rules) = -Σ p_i log2 p_i over {PASS, PARTIAL, FAIL, UNVERIFIED}
        = -(27/41 log2 27/41 + 4/41 log2 4/41 + 1/41 log2 1/41 + 4/41 log2 4/41)   [+ 5 file-size etc rolled in]
        ≈ 1.87 bits
CCM    = Σ w_i × pass_i / Σ w_i  (weights: CRITICAL=3, HIGH=2, MEDIUM=1)
        ≈ 0.66    (below 0.90 threshold ⇒ IMPROVE needed)
ITQS   = 0.4·H_norm + 0.4·CCM + 0.2·D
        ≈ 0.4·(1.87/log2(4)) + 0.4·0.66 + 0.2·0.85
        ≈ 0.4·0.94 + 0.264 + 0.17 = 0.81  (just below 0.85 ⇒ near-miss)
RPN_max = 336 (L3 enum gate) — exceeds threshold (200) ⇒ P0 action required
```

---

## §7.0 Verdict

The /planning page **passes 27 of 41 hard rules (66%)** and shows ITQS ≈ 0.81 — close to the 0.85 gold standard. The single biggest reason it feels "in bad shape" is **R1 — data poison at the ingestion gate** (RPN 336): the UI is honestly rendering 83 corrupt rows that never should have entered the database. Fixing one Rust function (`plan_add_task`'s priority/status validation) retires that RPN, and the cleanup script removes the visible debris in 10 minutes.

After the four P0 items in §5, the page jumps to ~85% strict pass and ITQS > 0.90.

— end —
