# C3I Planning Page — Comprehensive Specification & Documentation

**Version**: 2.1.0
**Date**: 2026-04-11
**Layer**: L3_TRANSACTION
**STAMP**: SC-GLM-UI-001, SC-A2UI-001, SC-AGUI-001, SC-TODO-001, SC-MUDA-001
**URL**: `https://<host>:4100/planning`

---

## 1. Executive Summary

The Planning page is the operational command center for the C3I Indrajaal system's task management lifecycle. It provides a multi-view, real-time, agentic interface to 2,710+ tasks stored in Smriti.db via the Rust `sa-plan-daemon` NIF bridge. The page implements the Triple-Interface Mandate (SC-GLM-UI-001) across Lustre SSR, Wisp REST API, and TUI ANSI — all sharing types from `ui/domain.gleam`.

### Key Metrics

| Metric | Value |
|--------|-------|
| Total source lines | 8,405 across 10 files |
| DOM elements | 16 interactive containers |
| API endpoints | 8 (all NIF-backed) |
| Live tasks | 2,710+ from Smriti.db |
| View modes | 4 (Grid, Kanban, Timeline, Analytics) |
| Refresh interval | 1s (active tasks), 5s (views), 30s (full) |
| Fractal layers | L0-L7 classification and filtering |
| AG-UI events | 15 handlers (32-event protocol) |
| Gleam tests | 3,835 passed, 0 failures |
| State change types | 5 (status, priority, new, removed, data_diff) |

---

## 2. Architecture

### 2.1 Triple-Interface Implementation

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLANNING PAGE ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  BROWSER (SSR)         WISP REST API          TUI TERMINAL      │
│  ┌──────────────┐     ┌──────────────┐     ┌���─────────────┐    │
│  │ page_views   │     │ router.gleam │     │ planning_    │    │
│  │ .gleam       │     │ 8 endpoints  │     │ view.gleam   │    │
│  │ (3,503 LOC)  │     │ NIF-backed   │     │ (53 LOC)     │    │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘    │
│         │                    │                     │             │
│  ┌──────▼───────┐     ┌──────▼───────┐     ┌──────▼───────┐    │
│  │ planning-    │     │ c3i_nif.gleam│     │ planning_    │    │
│  │ grid.js      │     │ (7 plan NIFs)│     │ dashboard_   │    │
│  │ (1,169 LOC)  │     │              │     │ view.gleam   │    │
│  └──────┬───────┘     └──────┬───────┘     │ (377 LOC)    │    │
│         │                    │              └───────────��──┘    │
│         ▼                    ▼                                   │
│  ┌─────────────────────────────────┐                            │
│  │   Rust sa-plan-daemon (NIF)     │                            │
│  │   → Smriti.db (SQLite)          │                            │
│  │   → 2,710+ tasks               ��                            │
│  └─────────────────────────────────┘                            │
│                                                                  │
│  LUSTRE MVU MODEL                                               │
│  ┌──────────────────────────────────────────────────┐           │
│  │ planning.gleam (66 LOC) — PlanningModel/Msg      │           │
│  │ planning_dashboard.gleam (1,483 LOC) — 8-Panel   │           │
│  │   45 Msg variants, 8 panels, 5 cockpit modes     │           │
│  └────���──────────────────────────────��──────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 File Inventory

| File | Lines | Purpose | Layer |
|------|-------|---------|-------|
| `priv/static/planning-grid.js` | 1,169 | Multi-view interactive grid, Kanban, Timeline, Analytics, AI search, fractal filters, state change log | L3 |
| `ui/web/page_views.gleam` | 3,503 | SSR HTML rendering for all 26+ pages including planning | L2 |
| `ui/lustre/planning.gleam` | 66 | Lustre MVU model: PlanningModel, PlanningMsg, init/update | L3 |
| `ui/lustre/planning_dashboard.gleam` | 1,483 | 8-Panel dashboard: DashboardModel (45 Msg variants), AG-UI, A2UI, HITL | L3 |
| `ui/wisp/planning_routes.gleam` | 657 | 17 typed JSON API endpoints for dashboard panels | L3 |
| `ui/wisp/planning_api.gleam` | 52 | Task JSON codec helpers | L3 |
| `ui/wisp/router.gleam` | (partial) | Route dispatch including 8 plan/* NIF endpoints + search | L2 |
| `ui/tui/planning_view.gleam` | 53 | TUI compact planning view with status badges | L3 |
| `ui/tui/planning_dashboard_view.gleam` | 377 | TUI 8-panel ANSI cockpit | L3 |
| `test/planning_dashboard_test.gleam` | 787 | C1-C8 coverage tests | Test |
| `test/planning_wiring_test.gleam` | 258 | Wiring guard + AG-UI + A2UI tests | Test |

---

## 3. Feature Specification

### 3.1 Multi-View System

The planning page offers 4 interchangeable views of the same task data:

| View | Key | Description | Refresh Rate |
|------|-----|-------------|--------------|
| **Grid** | `1` | Tabulator 6.3 data grids — sortable, filterable, paginated. 3 sub-grids: Blocked, Active, All | Active: 1s, All: 30s |
| **Kanban** | `2` | 4-column board (Pending / Active / Blocked / Done) with priority-sorted cards, fractal layer indicators, task count badges | 5s |
| **Timeline** | `3` | Gantt-style horizontal bars showing task creation date and duration, color-coded by priority, with opacity by status | 5s |
| **Analytics** | `4` | Key metrics dashboard, priority distribution stacked bar, fractal layer distribution grid, status flow visualization | 5s |

### 3.2 Fractal Layer Classification (L0-L7)

Every task is automatically classified into a fractal layer based on title keyword matching:

| Layer | Label | Color | Keywords | Example |
|-------|-------|-------|----------|---------|
| L0 | Constitutional | `#ff6b6b` | guardian, constitutional, psi, safety, emergency, sil4, sil6, prime | "Add Guardian approval gate" |
| L1 | Atomic/Debug | `#ffd93d` | nif, debug, trace, telemetry, otel, atomic, ffi | "Fix NIF crash isolation" |
| L2 | Component | `#6bcb77` | parser, component, form, badge, input, catalog, a2ui | "A2UI catalog validation" |
| L3 | Transaction | `#4d96ff` | planning, task, state, db, sqlite, smriti, transaction, crud | "Add task CRUD endpoint" |
| L4 | System | `#9b59b6` | podman, container, system, boot, build, image, docker | "Fix container health check" |
| L5 | Cognitive | `#00d4aa` | ooda, cortex, mcp, agent, llm, inference, reasoning, cognitive | "Implement OODA decide phase" |
| L6 | Ecosystem | `#e74c3c` | zenoh, mesh, topology, quorum, cluster, ecosystem | "Zenoh router reconnect" |
| L7 | Federation | `#f39c12` | federation, gateway, version, consensus, multi-node | "Version vector sync" |

**Default**: Tasks not matching any keywords are classified as L3 (Transaction).

### 3.3 AI Search & Knowledge Integration

The AI search bar (`Ctrl+K`) provides dual-mode search:

1. **Local grid filter**: Instantly filters the Tabulator grid by title substring match
2. **Zettelkasten knowledge lookup**: Queries `/api/v1/plan/search?q=<query>` which calls `c3i_nif.plan_search()` — a Rust NIF that performs LIKE matching against Smriti.db with up to 100 results

**Debounce**: 200ms after last keystroke before search fires.

### 3.4 Click-to-Detail Drill-Down

Clicking any task row (in any view) opens an expanded detail panel with:

| Action Button | Color | Function |
|---------------|-------|----------|
| Knowledge Lookup | Teal | Calls `/api/v1/plan/search?q=<title>` and renders Zettelkasten results |
| Related Tasks | Teal | Finds tasks with 2+ shared words (length > 3) from allTaskData |
| STAMP Refs | Amber | Extracts `SC-[A-Z]+-\d+` patterns from task title |
| Sub-Tasks | Purple | Filters allTaskData for tasks with matching `parent_id` |
| AI Analysis | Gold | Combines risk assessment, layer context, age analysis, STAMP refs, and knowledge lookup |

### 3.5 Real-Time Update Architecture

```
┌─────────────────────────────────────────────────────┐
│              REFRESH CYCLE ARCHITECTURE               │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Every 1s ─┬─ Fetch /api/v1/plan/list/in_progress   │
│            ├─ Compute snapshot diff (snapshotData)   │
│            ├─ Highlight changed rows (CSS animation) │
│            └─ Log mutations to change feed            │
│                                                       │
│  Every 5s ─┬─ Fetch all 3 grids (if non-grid view)  │
│            └─ Re-render Kanban/Timeline/Analytics    │
│                                                       │
│  Every 30s ┬─ Full refresh all 3 grids               │
│            ├─ Update analytics badges                │
│            ├─ Update mini stacked bar chart           │
│            └─ Detect status/priority/new/removed     │
│                                                       │
│  ROW-LEVEL DIFF DETECTION                            │
│  ┌───────────────────────────────────────────┐       │
│  │ snapshotData(data) → {id: "status|pri|t"} │       │
│  │ findChangedIds(old, new) → [id1, id2...]  │       │
│  │ highlightChangedRows(grid, ids) → CSS anim│       │
│  │ detectAndLogChanges(old, new) → change log│       │
│  └───────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

### 3.6 State Change Event Log

The change log captures every mutation detected during refresh cycles:

| Event Type | Color | Trigger |
|------------|-------|---------|
| `status_change` | Amber | Task status field changed (e.g., pending → in_progress) |
| `priority_change` | Purple | Task priority field changed (e.g., P2 → P1) |
| `new_task` | Green | Task ID exists in new snapshot but not old |
| `task_removed` | Red | Task ID exists in old snapshot but not new |
| `data_diff` | Teal | Summary: N rows changed across grids |

**Capacity**: Last 50 entries, displayed as scrollable feed with 15 visible.

---

## 4. State Machine Specification

### 4.1 PlanningModel (Simple View)

```
States: { tasks: List(PlanningTask), filter: TaskFilter, selected_id: Option(String) }

TaskFilter ADT:
  AllTasks | PendingOnly | InProgressOnly | CompletedOnly | BlockedOnly

Transitions:
  init() → PlanningModel(tasks: [], filter: AllTasks, selected_id: None)

  SetFilter(f) → model { filter: f }
  SelectTask(id) → model { selected_id: Some(id) }
  RefreshTasks → model (no-op, triggers side effect)
  TasksLoaded(tasks) → model { tasks: tasks }
```

### 4.2 DashboardModel (8-Panel Cockpit)

```
States: 33 fields across 8 panels + UI state
  Panel 1 (Tasks): tasks, task_filter, selected_task
  Panel 2 (OODA): ooda_phase, ooda_cycle_count, last_cycle_ms, ooda_pattern, ooda_decision
  Panel 3 (Safety): safety_active, threat_level, guardian_healthy, safety_checks, quarantined
  Panel 4 (Enforcer): total_violations, open_circuits, recent_violations
  Panel 5 (Graph): graph_node_count, graph_edge_count, graph_checks, graph_dot
  Panel 6 (Orchestration): services, quorum, distribution_strategy
  Panel 7 (Chaya): sync_phases, orphan_count, mismatch_count, last_sync
  Panel 8 (Startup): waves, critical_path, total_startup_ms
  UI: active_panel, cockpit_mode, ag_ui_connected, chat_messages

Msg ADT: 45 variants
  Task: SetTaskFilter, SelectTask, TasksLoaded, TaskStatusChanged
  OODA: OodaPhaseChanged, OodaCycleCompleted
  Safety: SafetyChecksLoaded, ThreatLevelChanged, AgentQuarantined
  Enforcer: ViolationRecorded, CircuitOpened, CircuitClosed
  Graph: GraphLoaded, GraphChecksRan
  Orchestration: ServicesUpdated, QuorumChanged, SetDistributionStrategy
  Chaya: SyncStarted, SyncPhaseCompleted, SyncFinished
  Startup: WavesComputed, CriticalPathFound
  UI: SetActivePanel, CockpitModeChanged, AgUiConnected, ChatMessageReceived,
      RefreshAll, NextCockpitMode, SelectPanel, CloseDetail
  AG-UI (15): AgUiRunStarted/Finished/Error, AgUiStepStarted/Finished,
              AgUiTextContent, AgUiStateSnapshot, AgUiStateDelta,
              AgUiToolCallStart/End/Result, AgUiReasoningContent
  HITL (3): HitlApprovalRequested, HitlUserApproved, HitlUserRejected
  A2UI (1): A2uiComponentProposed
```

### 4.3 Cockpit Mode State Machine

```
                ┌──────────────────────────────────────┐
                │       COCKPIT MODE TRANSITIONS        │
                └──────────────────────────────────────┘

  health_score = 0.4 × safety + 0.3 × enforcer + 0.3 × services

  ┌────────┐  health<0.3  ┌──────────────┐
  │  Dark  │ ◄──────────  │  EmergencyMode│
  │ ≥0.9   │              │   <0.3        │
  └───┬────┘              └──────┬────────┘
      │ <0.9                     │ ≥0.3
      ▼                          ▼
  ┌────────┐   <0.7      ┌────────┐
  │  Dim   │ ──────────► │ Normal │
  │ ≥0.7   │              │ ≥0.5   │
  └────────┘              └───┬────┘
                              │ <0.5
                              ▼
                         ┌────────┐
                         │ Bright │
                         │ ≥0.3   │
                         └────────┘

  Dark:      health ≥ 0.9  — Minimal gray, suppress nominal cards
  Dim:       health ≥ 0.7  — Subtle yellow accents, warnings visible
  Normal:    health ≥ 0.5  — Standard display, all elements visible
  Bright:    health ≥ 0.3  — High contrast, enlarged critical elements
  Emergency: health < 0.3  — Red dominant, pulsing borders, full illumination
```

### 4.4 JavaScript View State Machine

```
  currentView ∈ { "grid", "kanban", "timeline", "analytics" }

  Transitions:
    switchView("grid")      → show grid-section, hide others
    switchView("kanban")    → show kanban-section, render kanban cards
    switchView("timeline")  → show timeline-section, render gantt bars
    switchView("analytics") → show analytics-section, render metrics

  activeFractalFilter ∈ { null, "L0", "L1", ..., "L7" }

  Transitions:
    click All Layers   → activeFractalFilter = null, clear grid filter
    click L{n} chip    → activeFractalFilter = "L{n}", filter grid by _layer
```

---

## 5. API Specification

### 5.1 NIF-Backed Endpoints (Rust → SQLite)

| Endpoint | Method | Response | NIF Function |
|----------|--------|----------|--------------|
| `/api/v1/plan/status` | GET | `{"active":N,"pending":N,"completed":N,"blocked":N,"total":N}` | `plan_status()` |
| `/api/v1/plan/pending` | GET | `[{task}...]` (non-completed) | `plan_list_pending()` |
| `/api/v1/plan/list/pending` | GET | `[{task}...]` (status=pending) | `plan_list_by_status("pending")` |
| `/api/v1/plan/list/in_progress` | GET | `[{task}...]` (status=in_progress) | `plan_list_by_status("in_progress")` |
| `/api/v1/plan/list/completed` | GET | `[{task}...]` (status=completed) | `plan_list_by_status("completed")` |
| `/api/v1/plan/list/blocked` | GET | `[{task}...]` (status=blocked) | `plan_list_by_status("blocked")` |
| `/api/v1/plan/list/all` | GET | `[{task}...]` (all statuses) | `plan_list_by_status("all")` |
| `/api/v1/plan/search?q=<query>` | GET | `[{task}...]` (LIKE match, max 100) | `plan_search(query)` |

### 5.2 Task JSON Schema

```json
{
  "id": "0062fc3f",
  "title": "P2-FEAT: Add Emergency stop 5s compliance test",
  "status": "completed",
  "priority": "P2",
  "parent_id": null,
  "owner": null,
  "created": "2026-03-27T16:25:11.2467740Z"
}
```

### 5.3 Dashboard Panel Endpoints (17 total)

| # | Endpoint | Panel | Returns |
|---|----------|-------|---------|
| 1 | `/api/planning/tasks` | Tasks | Task list + counts |
| 2 | `/api/planning/tasks/{id}` | Tasks | Single task detail |
| 3 | `/api/ooda/status` | OODA | Current cycle phase |
| 4 | `/api/ooda/history` | OODA | Last 5 cycles |
| 5 | `/api/safety/status` | Safety | Kernel state |
| 6 | `/api/safety/check` | Safety | Constitutional validation |
| 7 | `/api/enforcer/status` | Enforcer | Violations + circuits |
| 8 | `/api/enforcer/reset` | Enforcer | Circuit breaker reset |
| 9 | `/api/graph/verify` | Graph | Access graph verification |
| 10 | `/api/graph/dot` | Graph | DOT visualization |
| 11 | `/api/orchestration/live` | Services | Registry + quorum |
| 12 | `/api/orchestration/coordinate` | Services | OODA coordination |
| 13 | `/api/chaya/status` | Chaya | Last sync + phases |
| 14 | `/api/chaya/sync` | Chaya | Run 5-phase sync |
| 15 | `/api/math/optimize` | Startup | CPM optimization |
| 16 | `/api/math/dfa` | Startup | 14 container states |
| 17 | `/api/dashboard/state` | Full | Complete dashboard JSON |

---

## 6. Visual Design Specification

### 6.1 Color Palette

| Element | Color | Hex | Usage |
|---------|-------|-----|-------|
| Accent/Primary | Teal | `#00d4aa` | Active states, links, highlights |
| Success | Green | `#3dd68c` | Completed, healthy |
| Warning | Amber | `#f5a623` | Degraded, stale |
| Critical | Red | `#ff4757` / `#ff6b81` | Blocked, errors |
| P0 Priority | Red gradient | `#ff4757 → #ff6b81` | Critical safety tasks |
| P1 Priority | Amber gradient | `#ffa502 → #ffbe76` | Core feature tasks |
| P2 Priority | Green gradient | `#2ed573 → #7bed9f` | Routine tasks |
| P3 Priority | Muted gray | `#7a8fa6` | Nice-to-have tasks |
| Background | Deep navy | `#0a0e17` | Page background |
| Card bg | Dark panel | `#141922` | Card containers |
| Border | Subtle blue-gray | `#1e2a3a` | Borders and dividers |
| Text | Light gray | `#e0e6ed` | Primary text |
| Muted text | Blue-gray | `#7a8fa6` | Secondary text, labels |

### 6.2 CSS Effects

- **Glassmorphism**: `backdrop-filter: blur(8px-16px)` on cards, panels, headers
- **Gradient badges**: `linear-gradient(135deg, color1, color2)` for priority/status
- **Glow shadows**: `box-shadow: 0 2px 10px rgba(color, 0.35)` on P0 badges
- **Pulse animations**: `pulse-active` (2s) for in-progress, `pulse-blocked` (2.5s) for blocked
- **Row change highlight**: `rowPulse` animation (1.8s ease-out) on data update
- **Hover lift**: `transform: translateY(-2px)` with `transition: 0.2s`
- **Fade-in**: `fadeSlideIn` (0.3s) for detail panel reveal

### 6.3 Responsive Breakpoints

| Width | Layout |
|-------|--------|
| > 1400px | Full 4-column Kanban, wide grids |
| 768-1400px | 2-column Kanban, stacked grids |
| < 768px | Single column, full-width cards |

---

## 7. Keyboard Shortcuts

| Key | Context | Action |
|-----|---------|--------|
| `1` | Global (not in input) | Switch to Grid view |
| `2` | Global (not in input) | Switch to Kanban view |
| `3` | Global (not in input) | Switch to Timeline view |
| `4` | Global (not in input) | Switch to Analytics view |
| `Ctrl+K` / `Cmd+K` | Global | Focus AI search bar |
| `R` | Global (not in input) | Refresh all data |
| `Esc` | With detail panel open | Close detail panel |
| `Esc` | In search bar | Clear search and blur |

---

## 8. User Journeys

### 8.1 Task Triage Journey

```
1. Navigate to /planning
2. View weather bar: system mood at a glance (☀️ Clear / ⛅ Partly cloudy / 🌧️ Stormy)
3. Check progress rings: completion %, P0 safety %, container health, total tasks
4. Scan blocked tasks grid (red accent, auto-sorted by priority)
5. Click blocked task → detail panel opens
6. Click "Knowledge Lookup" → Zettelkasten context for the task
7. Click "Related Tasks" → find similar tasks that may have been resolved
8. Decide: unblock or escalate
```

### 8.2 Sprint Planning Journey

```
1. Press 2 → switch to Kanban view
2. Filter by L5 (Cognitive) → see only cognitive tasks
3. Scan Pending column (sorted by priority)
4. Click task card → detail panel with AI Analysis
5. Review risk level, age, STAMP refs
6. Repeat for each candidate task
7. Press 4 → Analytics view for velocity metrics
8. Review status flow: Pending → Active → Blocked → Done
```

### 8.3 Real-Time Monitoring Journey

```
1. Open /planning and leave it running
2. Watch heartbeat dot (green = live connection)
3. Active tasks grid refreshes every 1 second
4. Row turns teal briefly when data changes (row-changed animation)
5. State Change Log section captures every mutation
6. Status bar shows: "13 blocked | 47 active | 2710 total · 3 changed · 13:45:22 · 2s ago"
7. Analytics badges update in real-time
```

### 8.4 Knowledge Discovery Journey

```
1. Press Ctrl+K → focus search bar
2. Type "zenoh" → grid filters instantly, Zettelkasten searches async
3. Results show: "42 tasks match · 100 knowledge results"
4. Click a search result → detail panel
5. Click "STAMP Refs" → see SC-ZENOH-001, SC-ZENOH-002 etc.
6. Click "AI Analysis" → risk assessment with knowledge context
7. Press Esc → clear search, return to full grid
```

### 8.5 Incident Response Journey

```
1. Weather bar shows 🌧️ Stormy (health score < 60)
2. Check blocked tasks grid for P0 items
3. Use AI search: "critical failure"
4. Click result → Knowledge Lookup reveals prior RCA from journal
5. Review "Decision Support Scenarios" table for playbook
6. Check Pipeline Performance section for inference latency
7. Press 4 → Analytics view for fractal layer distribution
8. Identify if L0 (Constitutional) or L4 (System) tasks are affected
```

---

## 9. Testing Specification

### 9.1 Test Coverage (C1-C8)

| Category | Weight | Tests | Status |
|----------|--------|-------|--------|
| C1 Page Structure | 1.0 | init tests, empty state verification | PASS |
| C2 Status Badges | 1.5 | cockpit mode colors, status rendering | PASS |
| C3 Data Grids | 1.0 | task list, service panels, 3+ rows | PASS |
| C4 Timeline | 0.8 | OODA cycle ordering, timestamp validation | PASS |
| C5 Interactive | 1.2 | drag-drop, filter, panel selection | PASS |
| C6 Media/Rich | 0.8 | SVG progress rings, sparklines | PASS |
| C7 AI Advisory | 1.5 | AG-UI event lifecycle, tool calls | PASS |
| C8 Action Button | 3.0 | HITL approval, cockpit escalation | PASS |

### 9.2 Test Files

| File | Tests | Coverage Area |
|------|-------|---------------|
| `planning_dashboard_test.gleam` | 787 lines | init, update (45 variants), health_score, cockpit mode, query helpers, TUI render |
| `planning_wiring_test.gleam` | 258 lines | Wiring guard, AG-UI lifecycle, HITL approval, A2UI catalog, Zenoh topics, tool registry, health score composite |

### 9.3 Math Gates

| Gate | Threshold | Current | Status |
|------|-----------|---------|--------|
| Shannon Entropy H | ≥ 2.5 bits | 2.67 bits | PASS |
| CCM | ≥ 0.90 | 0.770 | IMPROVING |
| ITQS | ≥ 0.85 | 0.736 | IMPROVING |
| Tab Coverage | 100% | 100% (31/31) | PASS |

---

## 10. STAMP Compliance Matrix

| ID | Constraint | Status | Verification |
|----|------------|--------|--------------|
| SC-GLM-UI-001 | Triple-Interface mandate | PASS | Lustre + Wisp + TUI all present |
| SC-GLM-UI-002 | Lustre MVU pattern | PASS | Model/Msg/init/update/view |
| SC-GLM-UI-003 | Typed JSON (no string concat) | PASS | gleam/json used throughout |
| SC-GLM-UI-004 | MSTS module contract header | PASS | XML header on planning_dashboard.gleam |
| SC-GLM-UI-007 | Every Wisp endpoint has Lustre+TUI | PASS | 17 endpoints + views |
| SC-GLM-UI-008 | Dark cockpit auto-hide | PASS | 5-mode state machine |
| SC-GLM-UI-009 | Shared types from domain.gleam | PASS | No type duplication |
| SC-AGUI-001 | AG-UI 32-event protocol | PASS | 15 handlers in DashboardMsg |
| SC-AGUI-004 | HITL for L0 operations | PASS | HitlApprovalRequested/Approved/Rejected |
| SC-A2UI-001 | Declarative component catalog | PASS | A2uiComponentProposed handler |
| SC-TODO-001 | NIF-backed task management | PASS | 8 endpoints via c3i_nif |
| SC-MUDA-001 | Zero compilation warnings | PASS | Dead code removed |
| SC-GLM-ZEN-001 | OTel spans via zenoh_otel | PASS | Span publishing for state changes |
| SC-WIRE-001 | Wiring guard compiles first | PASS | planning.init() in wiring_guard.gleam |

---

## 11. Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                     DATA FLOW: PLANNING PAGE                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  USER                                                              │
│   │                                                                │
│   ├── Browser GET /planning                                        │
│   │    └── Wisp router → page_views.planning_view(state)          │
│   │         ├── c3i_nif.plan_status() → live counts               │
│   │         ├─��� c3i_nif.plan_list_pending() → pending tasks       │
│   │         └── Renders SSR HTML + loads planning-grid.js         │
│   │                                                                │
│   ├── planning-grid.js onLoad                                      │
│   │    ├── fetch /api/v1/plan/list/blocked → Tabulator grid       │
│   │    ├── fetch /api/v1/plan/list/in_progress → Tabulator grid   │
│   │    ├── fetch /api/v1/plan/list/all → Tabulator grid           │
│   ���    ├── initFractalFilters() → L0-L7 chips                    │
│   │    ├── initAISearch() → search bar event listeners            │
│   │    └── startRefreshTimers() → 1s/5s/30s intervals            │
│   │                                                                │
│   ├── Every 1 second (activeTimer)                                 │
│   │    ├── fetch /api/v1/plan/list/in_progress                    │
│   │    ├── snapshotData() → hash current state                    │
│   │    ├── findChangedIds() → detect row-level changes            │
│   │    ├── highlightChangedRows() → CSS animation                 │
│   │    └── (no change log for active-only refresh)                │
│   │                                                                │
│   ├── Every 30 seconds (refreshTimer)                              │
│   │    ├── fetch all 3 grids in parallel                          │
│   │    ├── detectAndLogChanges() → log status/priority/new/remove │
│   │    ├── renderAnalyticsBadges() → update badge counts          │
│   │    ├── renderMiniChart() → update stacked bar                 │
│   │    └── renderChangeLog() → update mutation feed               │
│   │                                                                │
│   ├── AI Search (user types in search bar)                        │
│   │    ├── debounce 200ms                                          │
│   │    ├── grid.setFilter("title", "like", query) → local filter  │
│   │    └── fetch /api/v1/plan/search?q=<query> → knowledge results│
│   │                                                                │
│   └── Row Click (user clicks task)                                 │
│        ├── showTaskDetail(taskData) → render detail panel          │
│        ├── Knowledge → fetch /api/v1/plan/search                  │
│        ├── Related → filter allTaskData by word similarity         │
│        ├── STAMP → regex match SC-[A-Z]+-\d+ in title             │
│        ├── Sub-Tasks → filter by parent_id                        │
│        └── AI Analysis → aggregate risk + layer + knowledge       │
│                                                                    │
│  RUST NIF BRIDGE                                                   │
│   │                                                                │
│   ├── c3i_nif.plan_status() → Smriti.db SELECT counts             │
│   ├── c3i_nif.plan_list_pending() → WHERE status != 'completed'   │
│   ├── c3i_nif.plan_list_by_status(s) → WHERE status = s           │
│   └── c3i_nif.plan_search(q) → WHERE title LIKE '%q%' LIMIT 100  │
│                                                                    │
│  SMRITI.DB (SQLite)                                                │
│   └── 2,710 tasks with id, title, status, priority, parent_id,   │
│       owner, created fields                                        │
└────���────────────────────────────────��────────────────────────────┘
```

---

## 12. Ruliology — Behavioral Rules

### 12.1 Data Integrity Rules

| Rule | Description | Enforcement |
|------|-------------|-------------|
| R-DATA-001 | All task data MUST originate from Smriti.db via NIF | No hardcoded task data in JS |
| R-DATA-002 | Task ID is the canonical primary key | Used for diff detection and detail lookup |
| R-DATA-003 | Snapshot comparison MUST use status + priority + title hash | Prevents false-positive change detection |
| R-DATA-004 | Search results MUST be capped at 100 | Prevents OOM on broad queries |
| R-DATA-005 | Fractal layer classification is heuristic (keyword-based) | No manual classification required |

### 12.2 Refresh Rules

| Rule | Description | Interval |
|------|-------------|----------|
| R-REFRESH-001 | Active tasks refresh MUST be ≤ 1 second | 1000ms |
| R-REFRESH-002 | Full refresh MUST be ≤ 30 seconds | 30000ms |
| R-REFRESH-003 | View-specific refresh for non-grid views | 5000ms |
| R-REFRESH-004 | Failed fetches MUST retry with exponential backoff | 1s × attempt |
| R-REFRESH-005 | Maximum retry count is 3 | RETRY_COUNT = 3 |
| R-REFRESH-006 | Heartbeat indicator MUST reflect connection health | Green/Amber/Red |

### 12.3 UI Rules

| Rule | Description | Priority |
|------|-------------|----------|
| R-UI-001 | View toggle MUST preserve fractal filter state | HIGH |
| R-UI-002 | Kanban cards sorted by priority (P0 first) | HIGH |
| R-UI-003 | Timeline shows max 50 most recent tasks | MEDIUM |
| R-UI-004 | Analytics re-renders on every data refresh | MEDIUM |
| R-UI-005 | Detail panel scrolls into view on open | LOW |
| R-UI-006 | Esc key closes detail panel before clearing search | HIGH |
| R-UI-007 | Status badges use pulse animations for active/blocked only | MEDIUM |
| R-UI-008 | Task age color: >30d red, >7d amber, else gray | LOW |

### 12.4 Safety Rules

| Rule | Description | STAMP Ref |
|------|-------------|-----------|
| R-SAFE-001 | No direct writes to PROJECT_TODOLIST.md | SC-TODO-001 |
| R-SAFE-002 | All mutations go through sa-plan-daemon | SC-ENFORCE-001 |
| R-SAFE-003 | Search input is URL-encoded before fetch | SC-SEC-001 |
| R-SAFE-004 | HTML in task titles is NOT rendered (text only in grid) | SC-SEC-003 |
| R-SAFE-005 | Detail panel sanitizes apostrophes in JSON serialization | SC-SEC-003 |

---

## 13. Performance Characteristics

| Metric | Value | Method |
|--------|-------|--------|
| Initial page load | ~45 KB HTML + 67 KB JS | SSR + CDN Tabulator |
| Time to first grid render | ~1-2s | Parallel 3-API fetch + Tabulator init |
| Active task refresh latency | < 200ms | Single API call + diff + highlight |
| Full refresh latency | < 500ms | 3 parallel API calls + analytics |
| Search debounce | 200ms | Prevents excessive API calls |
| Memory (JS heap) | ~15-20 MB | 2,710 tasks × 3 grid instances |
| Tabulator render (2,710 rows) | ~100ms | Virtualized pagination (25 per page) |

---

## 14. Dependencies

| Dependency | Version | Purpose | Source |
|------------|---------|---------|--------|
| Tabulator | 6.3.1 | Data grid library | CDN (unpkg) |
| Lustre | 5.6+ | Gleam SSR framework | Hex package |
| Wisp | 2.2.2 | HTTP framework | Hex package |
| c3i_nif | Internal | Rust NIF bridge | `native/c3i_nif/` |
| Smriti.db | SQLite | Task storage | `data/smriti/planning.db` |

---

## 15. Known Limitations & Future Work

| Item | Status | Description |
|------|--------|-------------|
| Drag-and-drop Kanban | Planned | Currently read-only; needs POST to sa-plan-daemon for status change |
| WebSocket push | Planned | Currently poll-based; Zenoh → SSE would enable true real-time |
| Gemma 4 agent integration | Planned | AI Analysis currently uses NIF search; could invoke Gemma for deeper analysis |
| Offline support | Not planned | Requires Service Worker + IndexedDB cache |
| Task creation UI | Planned | Currently tasks created only via sa-plan CLI |
| Timeline zoom/pan | Planned | Currently fixed scale based on oldest task |
| Export from Kanban/Timeline | Planned | Currently only Grid view has CSV/JSON export |

---

**Document Version**: 2.1.0
**Author**: Claude Opus 4.6 + Human Operator
**STAMP Compliance**: SC-SYNC-DOC-002, SC-INST-001
**Fractal Layer**: L3_TRANSACTION → L5_COGNITIVE (documentation spans planning + knowledge)
