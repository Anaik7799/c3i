# C3I Planning WebUI - Comprehensive Design Document
## CX / UX / DX / Operations / Safety / All Fractal Layers

---

## 1. USER PERSONAS & JOURNEY MAPS

### Persona 1: Operator (Primary)
**Context:** Monitoring 24/7 in a secure operations center. 3 monitors. Shift-based.
**Goals:** Maintain SIL-6 compliance, respond to anomalies, approve safety-critical operations.
**Journey:**
```
Login → Dark Cockpit (all quiet) → Anomaly detected → Panel brightens →
Click anomaly → Detail view → Decide action → AG-UI interrupt for approval →
Confirm → Action executed → Verify resolution → Return to dark
```
**Pain Points:**
- Alert fatigue from too many non-critical notifications
- Context switching between 31 API endpoints
- No spatial memory of where information lives

### Persona 2: Developer (DX)
**Context:** Local development, debugging agent behavior, testing new OODA patterns.
**Goals:** Rapid iteration, understand agent reasoning, trace requests end-to-end.
**Journey:**
```
gleam run → Open localhost:4100/planning → See system state →
Trigger OODA cycle via chat → Watch reasoning chain stream →
Check OTel traces → Modify code → Hot-reload → Verify fix
```
**Pain Points:**
- Cannot see inside actor mailboxes
- Cannot replay past OODA decisions
- No way to inject test observations

### Persona 3: AI Agent (A2A)
**Context:** Autonomous agent operating within the mesh, making decisions, calling MCP tools.
**Goals:** Execute tasks, report status, request approvals, avoid safety violations.
**Journey:**
```
Receive task via Zenoh → Check access via Enforcer → Run OODA cycle →
Propose action → Safety check → If approved: execute → Report result →
If denied: log violation, adjust behavior
```
**Pain Points:**
- Cannot self-diagnose why it was blocked
- No visibility into its own circuit breaker state
- Cannot request circuit reset autonomously

### Persona 4: Auditor (Compliance)
**Context:** Periodic SIL-6 compliance review. Needs evidence artifacts.
**Goals:** Verify all safety checks ran, review audit trail, export compliance reports.
**Journey:**
```
Navigate to Safety panel → Review constitutional check history →
Export audit log → Navigate to Graph panel → Run verification suite →
Download DOT graph → Generate compliance report
```

---

## 2. UX DESIGN SYSTEM

### 2.1 Color Language (SIL-6 Safety Palette)

| Color | Hex | Usage | WCAG AA |
|-------|-----|-------|:-------:|
| **Safety Green** | `#00e676` | All-clear, healthy, pass | 4.6:1 ✓ |
| **Amber Warning** | `#ffab00` | Degraded, caution, approaching threshold | 3.2:1 ○ |
| **Alert Red** | `#ff1744` | Critical, fail, emergency, circuit open | 5.1:1 ✓ |
| **Info Cyan** | `#00e5ff` | AG-UI events, informational, Zenoh messages | 4.8:1 ✓ |
| **Neutral Grey** | `#424242` | Inactive, not-run, dormant | 4.1:1 ✓ |
| **Surface** | `#121212` | Background (dark cockpit base) | — |
| **Surface Elevated** | `#1e1e1e` | Cards, panels | — |
| **Text Primary** | `#e0e0e0` | Body text | 12.6:1 ✓ |
| **Text Secondary** | `#9e9e9e` | Labels, timestamps | 4.6:1 ✓ |

### 2.2 Typography

| Level | Font | Size | Weight | Usage |
|-------|------|:----:|:------:|-------|
| H1 | SF Mono | 1.5rem | 700 | Panel titles |
| H2 | SF Mono | 1.1rem | 600 | Section headers |
| Body | SF Mono | 0.85rem | 400 | Metrics, descriptions |
| Mono | Fira Code | 0.8rem | 400 | Code, IDs, JSON |
| Caption | SF Mono | 0.7rem | 400 | Timestamps, labels |

### 2.3 Spatial Layout (CSS Grid)

```css
.planning-dashboard {
  display: grid;
  grid-template-columns: 200px 1fr 1fr 1fr 1fr;
  grid-template-rows: auto 1fr 1fr 300px;
  grid-template-areas:
    "nav  header header header header"
    "nav  tasks  ooda   safety enforce"
    "nav  graph  orch   chaya  startup"
    "nav  detail detail chat   chat";
  gap: 4px;
  height: 100vh;
}
```

### 2.4 Interaction Patterns

| Pattern | Trigger | Effect | AG-UI Event |
|---------|---------|--------|-------------|
| **Click Panel** | Mouse click on panel header | Panel expands to detail view | — |
| **Double-Click Task** | Double-click task card | Opens task editor modal | — |
| **Drag Task** | Drag card to new column | Updates status via API | `TOOL_CALL("update_status")` |
| **Hover Metric** | Mouse hover on any metric | Shows tooltip with context + AI explanation | — |
| **Right-Click Node** | Right-click graph node | Context menu: DFS from here, BFS, shortest path | — |
| **Ctrl+K** | Keyboard | Opens command palette (fuzzy search all actions) | — |
| **Ctrl+E** | Keyboard | Emergency stop (with confirmation) | `CUSTOM("emergency_stop")` |
| **Ctrl+O** | Keyboard | Trigger OODA cycle manually | `TOOL_CALL("ooda_trigger")` |
| **Ctrl+S** | Keyboard | Trigger Chaya sync | `TOOL_CALL("chaya_sync")` |
| **Ctrl+V** | Keyboard | Run graph verification suite | `TOOL_CALL("verify_graph")` |
| **Escape** | Keyboard | Close detail panel, return to overview | — |

### 2.5 Animation Principles

| Context | Animation | Duration | Easing |
|---------|-----------|:--------:|--------|
| Panel transition | Fade + slight scale | 200ms | ease-out |
| Card drag | Follow cursor with shadow | Realtime | — |
| OODA phase advance | Ring segment lights up | 150ms | ease-in-out |
| Safety check result | Check/X icon bounce | 300ms | spring |
| Circuit breaker open | Ring segment turns red with pulse | 500ms | linear |
| Alert arrival | Slide in from right | 250ms | ease-out |
| Emergency mode | Full red overlay fade | 100ms | linear |
| Cockpit mode shift | Background color blend | 1000ms | ease-in-out |

---

## 3. OPERATOR SCENARIOS (All Use Cases)

### Scenario 1: Morning Shift Handover
**What happens:** Operator arrives, opens dashboard. System has been running overnight.
**UX Flow:**
1. Dashboard opens in **Dark mode** — everything healthy
2. Status bar shows: "25 tasks complete, 0 pending, last OODA: 42ms, Safety: nominal"
3. Operator clicks "Show overnight activity" in chat
4. AG-UI streams `MESSAGES_SNAPSHOT` with last 8h of events
5. Operator sees 3 OODA cycles resolved automatically, 0 safety events
6. Operator acknowledges handover → logged to audit trail

### Scenario 2: Container Health Degradation
**What happens:** zenoh-router-2 CPU spikes to 95%. Metabolic governor detects.
**UX Flow:**
1. Dashboard shifts from **Dark → Dim** (health drops below 90%)
2. OODA panel lights up: Observe phase (health check observation arrives)
3. Orient phase classifies: `ResourceExhaustion`, `SingleContainer` scope
4. Decide phase scores actions: `RestartContainer("zenoh-router-2")` = 0.85
5. Panel 2 shows decision with reasoning chain (AG-UI `REASONING` events)
6. If auto-approved: Act phase executes restart → container DFA transitions Starting → Running → Healthy
7. Dashboard returns to **Dark** mode
8. All events logged with OTel spans

### Scenario 3: AI Agent Circuit Break
**What happens:** An AI agent (claude-3) makes 4 rapid requests that violate access rules.
**UX Flow:**
1. Enforcer Panel (4) shows violation count incrementing: 1, 2, 3
2. On violation 4: circuit breaker opens → Ring 3 turns **red** for claude-3
3. `CUSTOM("circuit_breaker", {agent: "claude-3", state: "open"})` pushes to SSE
4. Dashboard shifts to **Normal** mode (anomaly visible)
5. Notification: "Circuit breaker opened for claude-3 (4 violations)"
6. Operator reviews violations in detail panel: timestamp, path, reason, severity
7. Operator determines false positive → clicks "Reset Circuit" button
8. AG-UI `Interrupt` asks for Guardian confirmation
9. Operator confirms → circuit closes → Ring 3 returns to **green**

### Scenario 4: Destructive Operation Request
**What happens:** System process requests `delete_all_tasks` (UC-PLAN-004).
**UX Flow:**
1. Safety Panel (3) flashes: incoming operation requires constitutional validation
2. AG-UI streams `REASONING_START` → each Psi check appears:
   - Psi-0 (Existence): "Operation 'delete_all' → **FAIL** (threatens system existence)"
3. Operation is **BLOCKED** at Psi-0 — no further checks needed
4. Safety Panel shows red X on Psi-0 indicator
5. Violation recorded, audit trail updated
6. If operator wants to override: must provide explicit justification + Guardian token
7. Override requires `Interrupt` → two-key-turn confirmation
8. Even after override, Omega-0 (Founder's Directive) provides final gate

### Scenario 5: Chaya Sync with Orphans
**What happens:** External system created tasks directly in Chaya, bypassing Planning.
**UX Flow:**
1. Operator triggers sync via chat: "sync chaya"
2. Chaya Panel (7) shows 5-phase progress bar:
   - Phase 1: Read Planning → 25 tasks found
   - Phase 2: Detect Orphans → **3 orphans found** (orange highlight)
   - Phase 3: Convert → 25 tasks converted
   - Phase 4: Regenerate → PROJECT_TODOLIST.md regenerated
   - Phase 5: Verify → Count mismatch! 25 vs 28
3. Dashboard shifts to **Normal** mode, Chaya panel highlighted
4. Split view shows: Planning (25 tasks) vs Chaya (28 tasks)
5. Orphan tasks highlighted in orange with "not in Planning" badge
6. Operator reviews orphans, decides:
   - "Import to Planning" → creates task via UC-PLAN-001
   - "Delete from Chaya" → removes orphan
7. Re-sync → Phase 5 now shows 25 vs 25, all green

### Scenario 6: Startup Optimization Review
**What happens:** Before a planned restart, operator reviews the boot sequence.
**UX Flow:**
1. Operator navigates to Startup Panel (8)
2. Gantt chart shows 4 execution waves:
   - Wave 1: zenoh-router (no deps) — 3s
   - Wave 2: postgres (needs zenoh) — 5s
   - Wave 3: guardian, safety-kernel (need postgres) — 4s parallel
   - Wave 4: planner, telemetry, dashboard (need guardian) — 3s parallel
3. Critical path highlighted in red: zenoh → postgres → guardian → planner = 15s total
4. Operator notices postgres is the bottleneck (5s startup)
5. Adjusts postgres startup_ms estimate → CPM recalculates
6. Tries "What if we add a cache layer before postgres?" — drags new node into DAG
7. Recalculated total: 12s (3s improvement)

### Scenario 7: Graph Verification Failure
**What happens:** A new access rule creates a cycle in the access graph.
**UX Flow:**
1. Operator runs verification: "verify graph" in chat
2. Graph Panel (5) shows verification progress:
   - SC-GRAPH-001 Deadlock Free: **FAIL** — "Cycle detected: agent-A → method-B → agent-A"
   - SC-GRAPH-002 Completeness: PASS
   - SC-GRAPH-003 Soundness: PASS
   - SC-GRAPH-005 Connectivity: PASS
3. Dashboard shifts to **Bright** mode (verification failure)
4. SVG graph highlights the cycle in **pulsing red**
5. Operator clicks on the cycle → detail panel shows DFS trace
6. Operator removes the offending rule via chat: "remove access rule: agent-A → method-B"
7. Re-run verification → all 4 checks pass → dashboard returns to **Dark**

### Scenario 8: Natural Language Task Management
**What happens:** Operator uses chat for daily planning.
**UX Flow:**
```
[Operator] create task: Investigate Zenoh latency spike on router-3, priority P1
[AI] → TOOL_CALL("create_task", {title: "Investigate Zenoh latency spike on router-3", priority: "P1"})
[AI] Task created: ID=plan-8f3a, Status=Pending, Priority=P1
     → Published to Zenoh: c3i/planning/tasks/plan-8f3a/created

[Operator] assign plan-8f3a to system:cortex
[AI] → TOOL_CALL("assign_task", {id: "plan-8f3a", assignee: "system:cortex"})
[AI] Assigned. Cortex notified via c3i/a2a/planning/cortex.

[Operator] what's the status of P0 tasks?
[AI] → TOOL_CALL("planning_query", {filter: "priority=P0"})
[AI] 3 P0 tasks: all COMPLETED
     - 1.1.1: Implement triples ✓
     - 2.1.1: Domain models ✓
     - 4.1.1: Automated rollback ✓

[Operator] show me the dependency graph for task 1.1.1
[AI] → [Generative UI: SVG dependency tree with 1.1.1 as root, children highlighted]
```

### Scenario 9: Multi-Operator Collaboration
**What happens:** Two operators are working simultaneously during an incident.
**UX Flow:**
1. Both operators connect to the same SSE stream via Zenoh broadcast
2. Operator A selects a task → Operator B sees cursor presence (like Google Docs)
3. Operator A triggers OODA → both see the cycle phases streaming
4. Operator B reviews safety status while A monitors OODA
5. OODA decides: `RestartContainer("indrajaal-db-prod")`
6. AG-UI `Interrupt` appears on BOTH screens simultaneously
7. Operator A approves (first key) → Operator B confirms (second key)
8. Action executes → both dashboards update via STATE_DELTA

### Scenario 10: Developer Debugging Agent Behavior
**What happens:** Developer is testing why an agent keeps getting circuit-broken.
**UX Flow:**
1. Developer opens `/planning` dashboard locally
2. Navigates to Enforcer Panel (4) → sees `test-agent-1` has 7 violations
3. Clicks `test-agent-1` → detail panel shows all 7 violation records
4. Each record shows: timestamp, requested_path, reason, severity, blocked_by_circuit
5. Developer notices all violations are for path `/api/planning/tasks` with reason "rate_limit_exceeded"
6. Checks Rate Limit ring → test-agent-1 made 50 requests in 1 second (limit: 10)
7. Developer adjusts rate limit in code → hot-reload → tests again
8. New violations: 0 → circuit stays closed

---

## 4. DEVELOPER EXPERIENCE (DX)

### 4.1 Local Development Setup
```bash
# Start the planning dashboard
cd lib/indrajaal_gleam_web && gleam run
# Open: http://localhost:4100/planning

# In another terminal, watch for changes
cd lib/cepaf_gleam && gleam build --watch

# Trigger test OODA cycle
curl -X POST http://localhost:4100/api/planning/ooda/run

# Send test AG-UI event
curl -X POST http://localhost:4100/ag-ui/run \
  -H "Content-Type: application/json" \
  -d '{"threadId":"dev-1","messages":[{"role":"user","content":"show safety status"}]}'
```

### 4.2 Debug Tools Built Into Dashboard
- **Event Log**: Bottom-right collapsible panel showing raw AG-UI events (dev only)
- **State Inspector**: Click any panel header with Ctrl → shows raw Lustre model JSON
- **Trace Viewer**: Click any metric with Alt → opens OTel trace for that data path
- **Zenoh Monitor**: Type `/zenoh subscribe c3i/#` in chat → see all mesh messages
- **BEAM Observer**: Type `/observer` → shows OTP process tree with mailbox sizes

### 4.3 Testing the Dashboard
```bash
# Run all planning tests
cd lib/cepaf_gleam && gleam test

# Run planning-specific tests only
cd lib/cepaf_gleam && gleam test -- --filter planning

# Test the Lustre model (MVU update loop)
# Tests verify: every Msg variant produces correct model state
# Tests verify: every query function returns expected results
# Tests verify: cockpit mode transitions are correct
```

---

## 5. OPERATIONAL PROCEDURES

### 5.1 Daily Operations Checklist
| Time | Action | Panel | Expected |
|------|--------|-------|----------|
| Shift start | Check dashboard mode | All | Dark (nominal) |
| Shift start | Review overnight events | Chat | `MESSAGES_SNAPSHOT` stream |
| Hourly | Check OODA cycle times | Panel 2 | All <100ms |
| Hourly | Check safety kernel health | Panel 3 | All green, threat=0.0 |
| Daily | Run graph verification | Panel 5 | 4/4 checks pass |
| Daily | Run Chaya sync | Panel 7 | 0 orphans, 0 mismatches |
| Daily | Review enforcer stats | Panel 4 | 0 open circuits |
| Weekly | Export audit log | Panel 4 | Download CSV/JSON |
| Weekly | Review startup optimization | Panel 8 | Critical path optimal |

### 5.2 Incident Response Procedures
| Severity | Cockpit Mode | Action | Who Approves |
|----------|:------------:|--------|:------------:|
| Info | Dark | Auto-logged, no action | — |
| Warning | Dim | Review within 15min | Operator |
| Error | Normal | Investigate within 5min | Operator |
| Critical | Bright | Respond within 1min | Operator + Guardian |
| Emergency | Emergency | Immediate response | Two-key-turn |

### 5.3 Rollback Procedures
| Situation | Rollback Action | How |
|-----------|----------------|-----|
| Bad task update | Undo via chat: "rollback task {id}" | `execute_with_rollback` |
| Bad access rule | Remove rule: "remove rule {id}" | `add_rule` with inverse |
| Bad OODA decision | Override via chat: "cancel action" | `act(NoAction)` |
| Bad sync | Re-sync from Planning: "sync chaya --force" | `run_sync` |
| System corruption | Emergency stop + CryoCore restore | Panel 3 red button |

---

## 6. ACCESSIBILITY (a11y)

### 6.1 Keyboard Navigation
| Key | Action |
|-----|--------|
| Tab | Move between panels (circular) |
| Arrow keys | Navigate within panel |
| Enter | Select/expand item |
| Escape | Close detail, go back |
| Space | Toggle panel expanded/collapsed |
| Ctrl+1..8 | Jump to panel N directly |
| F1 | Open help overlay |
| F5 | Force refresh all panels |

### 6.2 Screen Reader Support
- Every panel has `aria-label="Panel N: {name}"`
- Every metric has `aria-live="polite"` for value changes
- Safety alerts use `aria-live="assertive"`
- Emergency mode announces via `aria-alert`
- Charts have `aria-description` with text summary

### 6.3 Visual Accessibility
- All color pairs pass WCAG AA contrast (4.5:1 minimum)
- Color-blind mode: adds patterns (stripes, dots) to colored indicators
- High-contrast mode: white-on-black with bright accents
- Reduced-motion mode: disables all animations
- Font size adjustable: 80% / 100% / 120% / 150%
- Dyslexia mode: OpenDyslexic font option

---

## 7. PERFORMANCE BUDGET

| Metric | Budget | Rationale |
|--------|:------:|-----------|
| First Paint | <500ms | Operator needs immediate awareness |
| Time to Interactive | <1s | Must be usable within 1 second |
| SSE Event Latency | <50ms | Real-time feel for streaming data |
| Lustre Update Cycle | <16ms | 60fps for smooth animations |
| API Response (JSON) | <100ms | OODA target is <100ms |
| Full Page Size | <200KB | Works on low-bandwidth connections |
| Memory (browser) | <100MB | Long-running dashboard (24h shifts) |
| SSE Reconnect | <2s | Auto-reconnect on network blip |

---

## 8. SECURITY CONSIDERATIONS

| Concern | Mitigation |
|---------|-----------|
| XSS in task titles | Server-side HTML escaping via `element.text()` |
| CSRF on POST endpoints | Same-origin policy + AG-UI threadId validation |
| SSE stream hijacking | Thread-scoped events, no cross-thread leakage |
| Sensitive data in REASONING | `ReasoningEncryptedValue` for constitutional chain |
| Audit log tampering | Append-only Zenoh log + hash chain |
| Unauthorized emergency stop | Two-key-turn AG-UI interrupt required |
| AI agent impersonation | ProofToken validation on every request |

---

## 9. OFFLINE & DEGRADED MODE

| Situation | Dashboard Behavior |
|-----------|-------------------|
| SSE disconnected | Banner: "⚠ Live updates paused. Reconnecting..." Auto-retry every 2s |
| Zenoh mesh down | Panels show last known state with "stale" badge. Chat works locally |
| DB unavailable | Task Board shows cached list. Write operations queued |
| OTel collector down | OTel metrics hidden. Other panels unaffected |
| Safety kernel crashed | **EMERGENCY MODE** activated. Only safety panel visible |
| All services offline | Static "System Offline" page with last known state timestamp |

---

## 10. GENERATIVE UI WIDGET CATALOG

When the AI agent needs to respond with rich content, it can propose these widgets:

| Widget | Trigger | Content |
|--------|---------|---------|
| `TaskCard` | "show task {id}" | Full task record as styled card |
| `KanbanBoard` | "show all tasks" | 4-column drag-drop board |
| `OodaRing` | "show last OODA cycle" | Animated ring with phase details |
| `SafetyShield` | "show safety status" | 10-check indicator matrix |
| `EnforcerRadar` | "show enforcer" | 5-ring defense visualization |
| `GraphView` | "show access graph" | Interactive SVG with DFS/BFS |
| `MeshHex` | "show services" | 7-node hexagonal grid |
| `SyncProgress` | "sync chaya" | 5-phase progress with details |
| `GanttChart` | "show startup plan" | CPM Gantt with critical path |
| `DfaStateMachine` | "show container DFA" | 14-state interactive diagram |
| `ViolationTable` | "show violations" | Sortable, filterable table |
| `SparklineChart` | "show metrics for {x}" | Time-series mini chart |
| `FlameGraph` | "show trace for {id}" | OTel span visualization |
| `DiffView` | "compare planning vs chaya" | Side-by-side colored diff |
| `ComplianceMatrix` | "show compliance" | 8x8 fractal layer grid |
| `TimelineView` | "show event history" | Chronological event strip |
