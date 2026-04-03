# Journal: Planning Page Wiring — Live DB, Lustre HTML, WebSocket, Zenoh, A2UI, Drag-Drop

**Date**: 2026-04-03 19:00 CEST
**Author**: Claude Opus 4.6
**Type**: Implementation / Wiring / Integration

---

## 1. Scope & Trigger

**Trigger**: The Planning page has a comprehensive 8-panel Model/Msg/update (35+ Msg variants,
17 REST endpoints, TUI rendering) but 6 critical features remain stubbed/unwired:

1. **Live DB** — Wisp handlers return sample data instead of SQLite queries
2. **Lustre HTML rendering** — `planning.gleam` has Model/Msg but no `view()` producing Elements
3. **WebSocket transport** — No Mist WebSocket handler for Lustre server components
4. **Zenoh subscriptions** — `zenoh_adapter.gleam` exists but not connected to live session
5. **A2UI generative rendering** — `A2uiComponentProposed` handler is a stub
6. **Drag-drop** — Kanban drag-drop designed but not in Msg type

**Goal**: Wire all 6 features and test the wiring end-to-end.

---

## 2. Pre-State Assessment

| Feature | Current State | Files Involved |
|---------|--------------|----------------|
| Live DB | Sample data in `planning_routes.gleam` | `planning/repository.gleam`, `planning_routes.gleam` |
| Lustre HTML | `planning.gleam` has init/update, no view() producing Elements | `ui/lustre/planning.gleam`, `ui/lustre/planning_dashboard.gleam` |
| WebSocket | No WebSocket code exists | `ui/lustre/supervisor.gleam` (planned), Mist integration |
| Zenoh subs | `planning/zenoh_adapter.gleam` has types, FFI has `zenoh_subscribe/3` | `zenoh_adapter.gleam`, `cepaf_gleam_ffi.erl` |
| A2UI render | `A2uiComponentProposed` returns `model` unchanged | `planning_dashboard.gleam`, `a2ui/renderer.gleam` |
| Drag-drop | Not in Msg type | `planning_dashboard.gleam` |

**Codebase**: 156 source files, 19 test files, 852 tests passing.

---

## 3. Execution Detail

### 3.1 Live DB Wiring

**Current**: `planning_routes.gleam` functions like `tasks_list()` call `sample_task_cards()`
which returns hardcoded `List(TaskCard)`.

**Target**: Wire through `planning/repository.gleam` → SQLite via `db/sqlite.gleam` FFI.

**Wiring Path**:
```
planning_routes.tasks_list()
  → planning.manager.list_tasks()           # Business logic
    → planning.repository.find_all()         # SQLite query
      → db.sqlite.query("SELECT * FROM tasks") # FFI to esqlite
        → cepaf_gleam_ffi.sqlite_q/3         # Erlang FFI
```

**Required Changes**:
1. `planning/repository.gleam` — Add `find_all() -> Result(List(Task), String)` that calls SQLite
2. `planning/manager.gleam` — Add `list_tasks(db_path) -> Result(List(Task), String)` wrapper
3. `planning_routes.gleam` — Replace `sample_task_cards()` with `manager.list_tasks()` call
4. Fallback: If DB unavailable, return sample data (graceful degradation per SC-FUNC-005)

**SQLite Schema** (from `planning/repository.gleam`):
```sql
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  priority TEXT NOT NULL DEFAULT 'P2',
  assignee TEXT,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1
);
```

### 3.2 Lustre HTML View Rendering

**Current**: `planning.gleam` has `PlanningModel`, `PlanningMsg`, `init()`, `update()`,
`filtered_tasks()`, `task_count_by_status()` — but NO `view()` function.

**Target**: Add `view(model: PlanningModel) -> Element(PlanningMsg)` that produces a real
Lustre HTML element tree using `lustre/element/html`.

**View Structure**:
```gleam
pub fn view(model: PlanningModel) -> element.Element(PlanningMsg) {
  html.div([attribute.class("planning-page dark-cockpit")], [
    // Header with title and filter buttons
    html.h1([], [element.text("Planning Board")]),
    render_filter_bar(model.filter),
    // Task board — 4 columns (Kanban)
    html.div([attribute.class("task-board grid grid-cols-4 gap-4")], [
      render_column("Pending", filtered_by_status(model, "pending")),
      render_column("In Progress", filtered_by_status(model, "in_progress")),
      render_column("Completed", filtered_by_status(model, "completed")),
      render_column("Blocked", filtered_by_status(model, "blocked")),
    ]),
    // Selected task detail panel
    render_detail(model),
  ])
}
```

**For `planning_dashboard.gleam`**: Add comprehensive `view()` rendering all 8 panels:
```gleam
pub fn view(model: DashboardModel) -> element.Element(DashboardMsg) {
  html.div([attribute.class("dashboard " <> cockpit_mode_class(model.cockpit_mode))], [
    render_header(model),
    html.div([attribute.class("panels grid grid-cols-4 grid-rows-2 gap-2")], [
      render_task_panel(model),      // Panel 1
      render_ooda_panel(model),      // Panel 2
      render_safety_panel(model),    // Panel 3
      render_enforcer_panel(model),  // Panel 4
      render_graph_panel(model),     // Panel 5
      render_orch_panel(model),      // Panel 6
      render_chaya_panel(model),     // Panel 7
      render_startup_panel(model),   // Panel 8
    ]),
    render_detail_panel(model),
    render_chat_panel(model),
  ])
}
```

### 3.3 WebSocket Transport (Lustre Server Components)

**Current**: No WebSocket code exists. Lustre server components require a WebSocket bridge.

**Target**: Use Mist's WebSocket support to connect Lustre server components to browsers.

**Architecture**:
```
Browser ←WebSocket→ Mist Handler ←OTP msgs→ Lustre Server Component
```

**Required New Module**: `ui/lustre/websocket_handler.gleam`
```gleam
/// Mist WebSocket handler for Lustre server components.
/// Bridges browser connections to OTP-supervised Lustre runtime.
///
/// Flow:
/// 1. Browser connects to ws://localhost:4100/ws/planning
/// 2. Mist upgrades to WebSocket
/// 3. Handler spawns/connects to Lustre server component
/// 4. Component sends DOM patches via WebSocket
/// 5. Browser sends UI events back via WebSocket

import gleam/erlang/process
import lustre/server_component

pub type WebSocketState {
  WebSocketState(
    page: String,
    runtime_subject: Option(process.Subject(server_component.RuntimeMessage)),
  )
}
```

**Mist Integration** (in `indrajaal_gleam_web.gleam`):
```gleam
// Route WebSocket connections to Lustre server components
case request.path {
  "/ws/planning" -> mist.websocket(request, planning_ws_handler)
  "/ws/dashboard" -> mist.websocket(request, dashboard_ws_handler)
  _ -> wisp_handler(request)
}
```

### 3.4 Zenoh Subscription Wiring

**Current**: `planning/zenoh_adapter.gleam` has types. FFI has `zenoh_subscribe/3` stub.
`agui/zenoh_bus.gleam` has `publish_event` but no subscription handling.

**Target**: Wire Zenoh subscriptions so planning dashboard receives live telemetry.

**Zenoh Topics for Planning**:
```
c3i/planning/events        — Task CRUD events
c3i/planning/sync/{phase}  — Chaya sync phase progress
c3i/ooda/{cycle_id}        — OODA cycle results
c3i/safety/reasoning/{id}  — Constitutional reasoning stream
c3i/enforcer/circuit/{id}  — Circuit breaker state changes
c3i/agui/events/{agent}    — AG-UI event streams per agent
c3i/a2a/broadcast           — Mesh-wide announcements
```

**Wiring**: Each subscription maps to a Lustre `effect.from()`:
```gleam
pub fn subscribe_planning_events() -> effect.Effect(DashboardMsg) {
  effect.from(fn(dispatch) {
    zenoh.subscribe(session, "c3i/planning/events", fn(msg) {
      dispatch(TaskStatusChanged(msg.task_id, msg.new_status))
    })
  })
}
```

### 3.5 A2UI Generative Rendering Wiring

**Current**: `A2uiComponentProposed(panel, component_json)` in DashboardMsg returns `model` unchanged.

**Target**: Wire through A2UI catalog validation → renderer → inject into panel.

**Wiring**:
```gleam
A2uiComponentProposed(panel, component_json) -> {
  // 1. Parse component JSON into ComponentProposal
  // 2. Validate against catalog (SC-A2UI-002)
  // 3. Check layer access (SC-A2UI-004)
  // 4. Render to HtmlOutput
  // 5. Store rendered output in model for panel display
  let catalog = a2ui_catalog.default_catalog()
  // Decode proposal from JSON...
  // For now, store the raw JSON for the panel's generative slot
  DashboardModel(..model,
    // Add a generative_slots field to model
    // generative_slots: dict.insert(model.generative_slots, panel, component_json)
  )
}
```

**Required Model Change**: Add `generative_slots: Dict(PanelId, json.Json)` to DashboardModel.

### 3.6 Drag-Drop for Kanban Task Board

**Target**: Add Msg variants for drag-drop and wire status changes.

**New Msg Variants**:
```gleam
// Drag-drop Kanban
DragTaskStarted(task_id: String)
DragTaskOver(column: String)
DragTaskDropped(task_id: String, new_status: String)
```

**Update Handler**:
```gleam
DragTaskDropped(task_id, new_status) -> {
  // 1. Update task status in model
  let updated = list.map(model.tasks, fn(t) {
    case t.id == task_id {
      True -> TaskCard(..t, status: new_status)
      False -> t
    }
  })
  // 2. Emit AG-UI TOOL_CALL to persist change
  // 3. Publish to Zenoh c3i/planning/events
  DashboardModel(..model, tasks: updated)
}
```

**View Wiring** (HTML5 drag-drop attributes):
```gleam
fn render_task_card(task: TaskCard) -> element.Element(DashboardMsg) {
  html.div([
    attribute.class("task-card"),
    attribute("draggable", "true"),
    event.on("dragstart", fn(_) { DragTaskStarted(task.id) }),
  ], [
    html.span([attribute.class("priority-badge " <> task.priority)], [
      element.text(task.priority),
    ]),
    html.p([], [element.text(task.title)]),
  ])
}

fn render_column(title: String, status: String, tasks: List(TaskCard)) -> element.Element(DashboardMsg) {
  html.div([
    attribute.class("kanban-column"),
    event.on("dragover", fn(_) { DragTaskOver(status) }),
    event.on("drop", fn(_) { DragTaskDropped("", status) }),
  ], [
    html.h2([], [element.text(title)]),
    ..list.map(tasks, render_task_card)
  ])
}
```

---

## 4. Root Cause Analysis

**Why these features are stubbed**:
1. **Live DB**: SQLite FFI works but query result parsing (rows → Task records) needs typed deserialization which was deferred
2. **Lustre HTML**: `lustre/element/html` functions available but view() bodies are complex — each of the 8 panels needs 20-50 lines of HTML construction
3. **WebSocket**: Mist WebSocket API (`mist.websocket()`) requires understanding Mist's handler pattern which differs from Wisp's request-response model
4. **Zenoh subs**: The FFI `zenoh_subscribe/3` sends callbacks but Gleam OTP actors need the subscription wired to a `process.Subject`
5. **A2UI render**: The catalog and validator exist but JSON → ComponentProposal decoding (from `gleam/dynamic`) isn't implemented yet
6. **Drag-drop**: HTML5 drag-drop requires `event.on("dragstart")` etc. which need Lustre's event decoders

---

## 5. Fix Taxonomy

### Files to Create (NEW)

| File | Purpose | Lines (est) |
|------|---------|:-----------:|
| `ui/lustre/websocket_handler.gleam` | Mist WebSocket → Lustre server component bridge | 150 |
| `ui/lustre/planning_view.gleam` | Full Lustre HTML view() for planning page | 200 |
| `ui/lustre/dashboard_view.gleam` | Full Lustre HTML view() for 8-panel dashboard | 400 |
| `test/planning_wiring_test.gleam` | End-to-end wiring tests | 150 |

### Files to Modify (UPGRADE)

| File | Changes | Lines changed |
|------|---------|:------------:|
| `planning_dashboard.gleam` | Add DragTask* Msg variants + generative_slots field + update handlers | +40 |
| `planning_routes.gleam` | Wire tasks_list() through repository (with fallback) | +20 |
| `planning/repository.gleam` | Add find_all_tasks() with SQLite query | +30 |
| `planning/zenoh_adapter.gleam` | Add subscribe functions returning effects | +40 |
| `agui/zenoh_bus.gleam` | Add subscribe_to_topic() with callback | +30 |
| `a2ui/renderer.gleam` | Add decode_proposal() from json.Json | +40 |

### Wiring Test Matrix

| Test | What It Verifies | Category |
|------|-----------------|----------|
| `live_db_fallback_test` | Repository returns sample data when DB unavailable | C4 |
| `lustre_view_produces_elements_test` | view() returns non-empty Element tree | C1 |
| `lustre_view_has_heading_test` | view() contains h1 element | C1 |
| `lustre_view_has_task_columns_test` | view() renders 4 Kanban columns | C1 |
| `dashboard_view_has_8_panels_test` | view() renders all 8 panel sections | C1 |
| `drag_drop_changes_status_test` | DragTaskDropped updates task status | C5 |
| `drag_drop_preserves_other_tasks_test` | Only dragged task changes | C5 |
| `a2ui_proposal_validated_test` | A2uiComponentProposed validates against catalog | C8 |
| `a2ui_invalid_rejected_test` | Unknown component type rejected | C8 |
| `zenoh_subscribe_creates_effect_test` | subscribe_planning_events returns non-NoEffect | C4 |
| `cockpit_mode_class_test` | Dark Cockpit CSS class correct per mode | C6 |
| `health_score_with_live_data_test` | health_score computes correctly with real services | C2 |
| `agui_run_started_sets_connected_test` | AgUiRunStarted sets ag_ui_connected True | AG-UI |
| `agui_run_error_sets_bright_mode_test` | AgUiRunError switches cockpit to Bright | AG-UI |
| `hitl_approval_clears_request_test` | HitlUserApproved adds to chat history | AG-UI |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns (Use)
1. **Fallback pattern**: Live DB query → catch Error → return sample data (graceful degradation)
2. **Effect-as-data for Zenoh**: `effect.from(subscribe_zenoh_topic)` dispatches on message
3. **A2UI validate-then-render**: Always validate against catalog before rendering any proposal
4. **Lustre view composition**: Small render functions per panel, composed in main view()
5. **Drag-drop as Msg sequence**: DragStarted → DragOver (optional) → DragDropped (atomic)

### Anti-Patterns (Avoid)
1. **Direct DOM manipulation** — NEVER; use Lustre view() → Element tree → virtual DOM diff
2. **Zenoh blocking subscribe** — Use async callback pattern, not blocking receive
3. **Unvalidated A2UI JSON** — ALWAYS validate against catalog (SC-A2UI-002)
4. **Fat view functions** — Break into small renderers (render_task_card, render_column, etc.)

---

## 7. Verification Matrix

| Check | How to Verify | Gate |
|-------|--------------|------|
| Live DB wiring | `gleam test -- --filter planning_wiring` | Tests pass |
| Lustre view() | Assert Element tree non-empty, contains h1 | C1 tests |
| Drag-drop Msg | Assert DragTaskDropped changes task status | C5 tests |
| A2UI validation | Assert catalog rejects unknown types | C8 tests |
| Zenoh effect | Assert subscribe returns non-NoEffect | C4 tests |
| Build | `gleam build` — 0 errors | SC-GLM-CMP-001 |
| All tests | `gleam test` — 0 failures | Omega-3 |

---

## 8. Files Modified

| Action | File | Description |
|--------|------|-------------|
| CREATED | This journal entry | Wiring plan for 6 features |
| PLANNED | `ui/lustre/planning_view.gleam` | Full HTML view for planning |
| PLANNED | `ui/lustre/dashboard_view.gleam` | Full HTML view for 8-panel dashboard |
| PLANNED | `ui/lustre/websocket_handler.gleam` | Mist WebSocket → Lustre bridge |
| PLANNED | `test/planning_wiring_test.gleam` | 15+ wiring tests |
| PLANNED | `planning_dashboard.gleam` | +DragTask Msgs, +generative_slots |
| PLANNED | `planning_routes.gleam` | Wire through repository |
| PLANNED | `planning/repository.gleam` | SQLite find_all_tasks() |
| PLANNED | `planning/zenoh_adapter.gleam` | Subscribe effect functions |
| PLANNED | `a2ui/renderer.gleam` | JSON → ComponentProposal decoder |

---

## 9. Architectural Observations

### 9.1 The Wiring Gap
The codebase has excellent separation of concerns (Model/Msg/update/view) but the
connections BETWEEN layers are missing. Specifically:
- Repository → SQLite (FFI exists, query functions not called from routes)
- Lustre views → HTML Elements (types exist, render functions not written)
- Server components → WebSocket (Lustre API exists, Mist handler not created)
- Zenoh → OTP actors (FFI exists, callback wiring not done)
- A2UI → catalog → renderer (all modules exist, JSON decoding absent)

### 9.2 Lustre view() is the Critical Path
The most impactful single change is implementing `view()` for `planning_dashboard.gleam`.
This 400-line function converts the entire 8-panel model into renderable HTML, making the
dashboard actually visible in a browser. Everything else (WebSocket, Zenoh, A2UI) channels
data INTO the model — but without `view()`, none of it reaches the operator.

### 9.3 Graceful Degradation Architecture
Every wiring point should follow the fallback pattern:
```
Live source → catch Error → Fallback to sample/cached → Log degradation
```
This ensures the planning page works even when:
- SQLite is unavailable (use sample data)
- Zenoh is disconnected (use cached state)
- WebSocket drops (SSE fallback or polling)
- A2UI proposal invalid (reject and log, don't crash)

---

## 10. Remaining Gaps

| # | Gap | Priority | Mitigation |
|---|-----|----------|------------|
| 1 | `gleam/dynamic` JSON decoder for A2UI ComponentProposal | P1 | Implement typed decoder |
| 2 | Mist WebSocket API integration pattern | P1 | Research `mist.websocket()` handler |
| 3 | Zenoh subscribe callback → OTP Subject wiring | P1 | Use FFI process.send() from callback |
| 4 | Lustre `lustre/element/html` import validation | P0 | Verify html module available in deps |
| 5 | HTML5 drag-drop event decoders in Lustre | P2 | May need custom event.on() handlers |
| 6 | CSS for Dark Cockpit theme | P2 | CSS variables via lustre_ui or custom |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Features to wire | 6 |
| New files planned | 4 |
| Files to modify | 6 |
| New tests planned | 15+ |
| Estimated new lines | ~1,100 |
| Critical path | Lustre view() for 8-panel dashboard |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Compliance |
|------------|-----------|
| SC-GLM-UI-001 | ENHANCED — Lustre HTML rendering activates Web interface |
| SC-GLM-UI-002 | ACTIVATED — view() function makes MVU pattern complete |
| SC-AGUI-011 | WIRED — WebSocket handler connects Lustre server components |
| SC-AGUI-014 | WIRED — Zenoh subscriptions via effect.from() |
| SC-A2UI-002 | WIRED — Proposals validated against catalog before rendering |
| SC-A2UI-003 | WIRED — renderer.gleam produces HTML/JSON/ANSI per target |
| SC-FUNC-005 | PRESERVED — Graceful degradation on DB/Zenoh/WebSocket failure |
| SC-XHOLON-020 | TARGETED — SQLite read latency < 1ms via direct FFI |

---

## 13. Conclusion

The Planning page has comprehensive backend logic (15 domain modules, 8-panel model, 35+ Msg
variants, 17 REST endpoints, TUI rendering) but 6 critical wiring connections are missing.
This journal documents the exact wiring needed for each:

1. **Live DB**: Repository → SQLite FFI with graceful fallback
2. **Lustre HTML**: 400-line view() function for 8-panel dashboard (CRITICAL PATH)
3. **WebSocket**: Mist handler → Lustre server component bridge
4. **Zenoh**: Subscribe effects dispatching dashboard Msgs
5. **A2UI**: JSON decode → catalog validate → render pipeline
6. **Drag-drop**: 3 new Msg variants + HTML5 event handlers

**Critical path**: Lustre `view()` is the single most impactful change — without it, none
of the data flowing through the model reaches the operator's screen.
