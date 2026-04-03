# C3I Planning WebUI - SIL-6 Aligned Design & Implementation Plan

## Fractal Layer Coverage Matrix

This design maps every Planning capability to its Fractal Layer and ensures
complete L0-L7 coverage within the WebUI.

| Layer | Domain | Panel | Capabilities Exposed |
|-------|--------|-------|---------------------|
| **L0_CONSTITUTIONAL** | SafetyKernel | Panel 3 | Psi-0..5 checks, Omega-0, Guardian approval, emergency stop, threat level, quarantine |
| **L1_ATOMIC_DEBUG** | Telemetry/Tracing | AG-UI Stream | AG-UI events, OTel spans, Zenoh message trace, violation audit trail |
| **L2_COMPONENT** | Parser, Task CRUD | Panel 1 | Markdown parse/serialize, task create/update/filter/sort, field-level editing |
| **L3_TRANSACTION** | Enforcer, Graph, AccessControl, Chaya, MathOpt | Panels 4,5,7,8 | 5-layer enforcement, graph verification, access policy, digital twin sync, CPM scheduling |
| **L4_SYSTEM** | Orchestration, Boot | Panels 6,8 | 7-service mesh, container DFA (14 states), startup wave execution |
| **L5_COGNITIVE** | OODA Controller, Chat | Panel 2, Chat | Observe→Orient→Decide→Act loop, natural-language commands, agent reasoning |
| **L6_ECOSYSTEM** | ZenohAdapter, A2A | All Panels | Event publishing, inter-agent messaging, mesh state broadcast |
| **L7_FEDERATION** | Coordination, Distribution | Panel 6 | Cross-service task creation, quorum consensus, task distribution strategies |

## STAMP Constraint Traceability

| STAMP Control | Panel | Implementation |
|--------------|-------|----------------|
| SC-HMI-010 (Dark Cockpit) | All | Progressive disclosure: Dark/Dim/Normal/Bright/Emergency |
| SC-ENFORCE-001..025 | Panel 4 | 5-layer defense rings with real-time violation feed |
| SC-SAFETY-001..022 | Panel 3 | 10 constitutional check indicators + threat gauge |
| SC-GRAPH-001..005 | Panel 5 | Interactive SVG graph + 4-check verification |
| SC-OODA-001, SC-ORCH-004 | Panel 2 | OODA ring diagram with <100ms target tracking |
| SC-SYNC-PLAN-001..020 | Panel 7 | 5-phase sync progress + bidirectional status mapping |
| SC-MATH-001..014 | Panel 8 | Gantt chart + CPM metrics + DFA state machine |
| SC-GLM-UI-001 | All | Triple-interface: Lustre SSR + Wisp JSON + TUI ANSI |
| SC-GLM-UI-008 | All | Dark Cockpit: panels auto-hide when healthy |

## FMEA Risk Analysis per Panel

| Panel | Failure Mode | Effect | RPN | Mitigation |
|-------|-------------|--------|:---:|-----------|
| 1 Task Board | Task status shows stale data | Operator makes decisions on wrong state | 120 | AG-UI STATE_DELTA real-time push |
| 2 OODA | Cycle time exceeds 100ms unnoticed | SIL-6 timing violation | 189 | Red sparkline + audio alert at >100ms |
| 3 Safety | Constitutional check fails silently | Unsafe operation proceeds | 210 | Always-visible panel, REASONING events stream |
| 4 Enforcer | Circuit breaker opens but UI doesn't update | Blocked agent appears operational | 144 | CUSTOM("circuit_breaker") immediate push |
| 5 Graph | Access graph has undiscovered cycles | Deadlock in production | 168 | Auto-run verification on graph change |
| 6 Orchestration | Service goes offline but mesh shows green | False sense of health | 156 | Heartbeat timeout (5s) via Zenoh |
| 7 Chaya | Sync orphans accumulate silently | Data divergence between twins | 120 | Orphan count always visible, red if >0 |
| 8 Startup | Critical path miscalculated | Containers start in wrong order | 108 | Visual Gantt with dependency arrows |

## Design Philosophy
This WebUI follows three principles simultaneously:
1. **SIL-6 Dark Cockpit** (SC-HMI-010): Quiet when healthy, progressive disclosure on anomalies
2. **AG-UI Event Streaming**: Real-time SSE updates, not polling
3. **Generative UI** (Google A2UI): Agent-proposed dynamic widgets, interactive tools

## Architecture: 8-Panel Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│ [C3I PLANNING COCKPIT]          [🟢 SIL-6 NOMINAL]   [AG-UI ●] │
├─────────┬───────────────────────────────────────────────────────┤
│         │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  NAV    │  │ TASK     │ │ OODA     │ │ SAFETY   │ │ ENFORCE │ │
│         │  │ BOARD    │ │ CYCLE    │ │ KERNEL   │ │ SHIELD  │ │
│ Tasks   │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │
│ OODA    │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│ Safety  │  │ GRAPH    │ │ ORCH     │ │ CHAYA    │ │ STARTUP │ │
│ Enforce │  │ VERIFY   │ │ MESH     │ │ TWIN     │ │ OPTIM   │ │
│ Graph   │  └──────────┘ └──────────┘ └──────────┘ └─────────┘ │
│ Orch    │                                                       │
│ Chaya   │  ┌────────────────────────────────────────────────┐   │
│ Startup │  │              DETAIL PANEL                      │   │
│ Access  │  │  (context-sensitive, shows selected item)      │   │
│ ──────  │  └────────────────────────────────────────────────┘   │
│ AG-UI   │  ┌────────────────────────────────────────────────┐   │
│ Chat    │  │              AG-UI CHAT / SSE STREAM            │   │
│         │  └────────────────────────────────────────────────┘   │
└─────────┴───────────────────────────────────────────────────────┘
```

## Panel Specifications

### Panel 1: Task Board (UC-PLAN-001, UC-PLAN-002, UC-PLAN-013)
**Data Source:** `lustre/planning.gleam` model + `/api/planning/tasks`
**Layout:** 4-column Kanban: Pending | InProgress | Completed | Blocked
**Features:**
- Cards show: title, priority pill (P0=red, P1=orange, P2=blue, P3=grey), assignee avatar
- Drag-drop between columns triggers `TOOL_CALL("update_task_status", {id, new_status})`
- Click card → Detail Panel shows full task record (all 18 fields)
- "+New Task" button → modal with title, priority, parent_id, tags
- Filter bar: All | P0 | P1 | P2 | P3 | has_dependencies
- Sort: by priority, created_at, due_date
- AG-UI: `STATE_DELTA` patches move cards in real-time
- Dark Cockpit: Only shows if any tasks are Blocked (red highlight)

### Panel 2: OODA Cycle Monitor (UC-PLAN-005)
**Data Source:** `planning/ooda.gleam` + `/api/ooda/status`
**Layout:** 4-phase ring diagram: O→O→D→A
**Features:**
- Ring segments light up as each phase executes (AG-UI `STEP_STARTED/FINISHED`)
- Center shows: cycle count, last cycle time (ms), target (<100ms)
- Current assessment: Pattern classification badge (HealthDegradation/ResourceExhaustion/etc.)
- Decision display: selected ActionType with score
- History sparkline: last 60 cycle times (green if <100ms, red if >100ms)
- "Run OODA" button → `TOOL_CALL("ooda_trigger")`
- AG-UI: Full cycle streams as `RUN_STARTED → STEP(observe) → STEP(orient) → STEP(decide) → STEP(act) → RUN_FINISHED`
- Dark Cockpit: Only visible when Pattern != UnknownPattern

### Panel 3: Safety Kernel (UC-PLAN-004, UC-PLAN-011)
**Data Source:** `planning/safety_kernel.gleam` + `/api/safety/status` (new endpoint)
**Layout:** Shield icon with traffic-light indicators
**Features:**
- 10 constitutional check indicators (Psi-0 through Psi-5 + Omega-0..2 + Guardian)
- Each shows: Pass (green) / Fail (red) / Warning (yellow) / Not-Run (grey)
- Threat level gauge: 0.0 (green) → 1.0 (red)
- Guardian health indicator: healthy (green pulse) / unhealthy (red static)
- Active/Inactive toggle (requires two-key-turn via AG-UI interrupt)
- Quarantined agents list (red badges)
- "Emergency Stop" button (red, requires AG-UI interrupt confirmation)
- AG-UI: `REASONING_START/CONTENT/END` streams each Psi check in real-time
- Dark Cockpit: Always visible (safety-critical, SC-COCKPIT-001)

### Panel 4: Enforcer Shield (UC-PLAN-010)
**Data Source:** `planning/enforcer.gleam` + `/api/enforcer/status` (new endpoint)
**Layout:** 5-layer concentric rings (defense-in-depth)
**Features:**
- Ring 1 (outer): Agent Classification - shows Human/AI/System/Unknown counts
- Ring 2: Rate Limiting - current request rates per agent
- Ring 3: Circuit Breaker - open (red) / closed (green) per agent
- Ring 4: Path Validation - forbidden path hit count
- Ring 5 (center): Behavioral Analysis - suspicious pattern alerts
- Violation feed: scrolling list of recent violations (severity colored)
- Statistics card: total violations, by severity, by agent
- "Reset Circuit" button per agent → `TOOL_CALL("reset_circuit", {agent_id})`
- AG-UI: `CUSTOM("circuit_breaker")` events update rings in real-time
- Dark Cockpit: Only visible if any circuit is open or violation count > 0

### Panel 5: Graph Verification (UC-PLAN-007)
**Data Source:** `planning/graph_verification.gleam` + `/api/graph/verify`
**Layout:** Interactive SVG graph + verification checklist
**Features:**
- SVG/D3 force-directed graph of access control graph
- Nodes colored by type: Agent (blue), Method (green), File (grey), Decision (red/green)
- Edges: allowed (green) / forbidden (red dashed)
- Click node → highlight all reachable paths (BFS visualization)
- Verification checklist: 4 checks with pass/fail icons
  - SC-GRAPH-001: Deadlock Free ✓/✗
  - SC-GRAPH-002: Completeness ✓/✗
  - SC-GRAPH-003: Soundness ✓/✗
  - SC-GRAPH-005: Connectivity ✓/✗
- Graph stats card: nodes, edges, density, SCC count
- "Run Verification" button → AG-UI `STEP` events per check
- "Export DOT" button → downloads .dot file
- Dark Cockpit: Only visible if any check fails

### Panel 6: Orchestration Mesh (UC-PLAN-008)
**Data Source:** `planning/orchestration.gleam` + `/api/orchestration/status`
**Layout:** 7-node service mesh hexagonal grid
**Features:**
- 7 hexagonal nodes: Cortex, Prajna, Smriti, CEPAF, Planning, Chaya, Guardian
- Each shows: Online (green pulse) / Degraded (yellow) / Offline (grey)
- Edges between nodes show message flow (animated lines)
- Quorum indicator: ">50% online" badge (green/red)
- Message queue: recent inter-service messages with priority badges
- Task distribution strategy selector: RoundRobin / LeastLoaded / Priority / Affinity
- Distribution visualization: tasks flowing to nodes
- "Coordinate OODA" button → triggers cross-service OODA cycle
- AG-UI: `STATE_DELTA` updates node colors; `TOOL_CALL` shows coordination flow
- Dark Cockpit: Only visible if quorum is at risk (<60% online)

### Panel 7: Chaya Digital Twin (UC-PLAN-006)
**Data Source:** `planning/chaya.gleam` + `/api/chaya/sync`
**Layout:** Split view: Planning (left) ↔ Chaya (right)
**Features:**
- Side-by-side task lists showing Planning vs Chaya state
- Color-coded: synced (green), orphan (orange), mismatch (red)
- 5-phase sync progress bar: Read → DetectOrphans → Convert → Regenerate → Verify
- Phase details: tasks_processed, errors per phase
- Status mapping table: Planning status ↔ Chaya status (bijective proof)
- "Sync Now" button → AG-UI `STEP` events per phase
- Post-sync verification: count match ✓, status match ✓, orphans: 0
- AG-UI: `STATE_DELTA` updates both sides simultaneously
- Dark Cockpit: Only visible if orphans > 0 or mismatches > 0

### Panel 8: Startup Optimization (UC-PLAN-009)
**Data Source:** `planning/math_optimization.gleam` + `/api/math/optimize`
**Layout:** Gantt chart + DFA state machine
**Features:**
- Top: Gantt chart showing execution waves with container bars
  - Critical path highlighted in red
  - Slack shown as lighter extensions
  - Dependencies as arrows between bars
- Bottom: 14-state DFA diagram (interactive)
  - Current state highlighted per container
  - Valid transitions shown as clickable arrows
  - Invalid transitions greyed out
- CPM metrics card: total startup time, critical path containers, parallel waves
- "Optimize" button → recalculates CPM with current container defs
- Container definition editor: adjust startup_ms, dependencies
- AG-UI: `ACTIVITY_DELTA` updates Gantt progress during actual boot
- Dark Cockpit: Only visible during boot sequence or if any container is Failed

## Detail Panel (Context-Sensitive)

When any item is selected in panels 1-8, the Detail Panel shows:

| Context | Content |
|---------|---------|
| Task selected | Full 18-field task record, edit form, dependency graph, audit history |
| OODA cycle selected | Full observation list, assessment details, decision reasoning, action result |
| Safety check selected | Constitutional check details, Psi formula, pass/fail history |
| Violation selected | Full ViolationRecord, agent context, stack trace, remediation options |
| Graph node selected | Node properties, neighbors list, reachability from this node |
| Service selected | Service health history, message log, coordination history |
| Chaya task selected | Side-by-side Planning vs Chaya field comparison |
| Container selected | DFA state history, CPM metrics (ES/EF/LS/LF/Slack), dependency tree |

## AG-UI Chat Panel

A persistent chat interface at the bottom for natural-language interaction:

```
┌────────────────────────────────────────────────────────┐
│ [AI] System is healthy. 25/25 tasks completed.         │
│ [You] Show me blocked tasks with P0 priority           │
│ [AI] → TOOL_CALL("planning_query", {filter: "blocked", │
│         priority: "P0"})                                │
│ [AI] No P0 blocked tasks found. All P0 tasks complete. │
│ [You] Run the graph verification suite                  │
│ [AI] → STEP_STARTED("verify_deadlock_free")             │
│ [AI] → STEP_FINISHED("verify_deadlock_free": PASS)      │
│ [AI] → STEP_STARTED("verify_completeness")              │
│ [AI] All 4 checks passed. System is graph-verified.     │
│                                                         │
│ [Type a command or question...]                    [⏎]  │
└────────────────────────────────────────────────────────┘
```

Commands the chat understands:
- "create task: {title}" → UC-PLAN-001
- "update task {id} to {status}" → UC-PLAN-002
- "run ooda cycle" → UC-PLAN-005
- "sync chaya" → UC-PLAN-006
- "verify graph" → UC-PLAN-007
- "show safety status" → UC-PLAN-011
- "optimize startup" → UC-PLAN-009
- "show violations for {agent}" → UC-PLAN-010
- "check access: {agent} -> {resource}" → UC-PLAN-007
- "emergency stop: {reason}" → UC-PLAN-004

## New API Endpoints Required

| Endpoint | Method | Returns | Panel |
|----------|--------|---------|-------|
| `/api/planning/tasks` | GET | Full task list with all fields | 1 |
| `/api/planning/tasks` | POST | Create new task | 1 |
| `/api/planning/tasks/{id}` | PATCH | Update task status | 1 |
| `/api/planning/ooda/run` | POST | Trigger OODA cycle, return result | 2 |
| `/api/planning/ooda/history` | GET | Last N OODA cycles | 2 |
| `/api/planning/safety/status` | GET | Full SafetyKernel state | 3 |
| `/api/planning/safety/check` | POST | Run constitutional checks | 3 |
| `/api/planning/enforcer/status` | GET | Enforcer state + violations | 4 |
| `/api/planning/enforcer/reset/{agent}` | POST | Reset circuit breaker | 4 |
| `/api/planning/graph/verify` | POST | Run verification suite | 5 |
| `/api/planning/graph/dot` | GET | DOT language export | 5 |
| `/api/planning/orchestration/status` | GET | Service registry state | 6 |
| `/api/planning/orchestration/coordinate` | POST | Trigger coordination | 6 |
| `/api/planning/chaya/sync` | POST | Trigger 5-phase sync | 7 |
| `/api/planning/chaya/status` | GET | Current sync state | 7 |
| `/api/planning/math/optimize` | POST | Run CPM optimization | 8 |
| `/api/planning/math/dfa` | GET | DFA state for all containers | 8 |

## New Lustre Model (Replacing Minimal Existing)

```gleam
pub type PlanningDashboardModel {
  PlanningDashboardModel(
    // Panel 1: Tasks
    tasks: List(Task),
    task_filter: TaskFilter,
    selected_task_id: Option(String),
    // Panel 2: OODA
    ooda_cycles: List(OodaCycle),
    current_ooda_phase: Option(String),
    // Panel 3: Safety
    safety_state: SafetyState,
    constitutional_results: List(ConstitutionalCheck),
    quarantined_agents: List(String),
    // Panel 4: Enforcer
    violations: List(Violation),
    circuit_states: Dict(String, Bool),
    rate_limit_state: Dict(String, Int),
    // Panel 5: Graph
    access_graph: Option(GraphData),
    verification_results: List(VerificationCheck),
    // Panel 6: Orchestration
    services: Dict(String, ServiceState),
    messages: List(ServiceMessage),
    distribution_strategy: String,
    // Panel 7: Chaya
    sync_report: Option(SyncReport),
    sync_phase: Option(String),
    // Panel 8: Startup
    execution_waves: List(Wave),
    cpm_results: Dict(String, CpmData),
    container_states: Dict(String, String),
    // UI State
    active_panel: PanelId,
    cockpit_mode: CockpitMode,
    ag_ui_connected: Bool,
    chat_messages: List(ChatMessage),
  )
}
```

## Implementation Order

| Step | Task | Files | Est. |
|:----:|------|-------|:----:|
| 1 | New Lustre model + full Msg type | `ui/lustre/planning_dashboard.gleam` | 30m |
| 2 | 17 new Wisp API endpoints | `ui/wisp/planning_routes.gleam` | 30m |
| 3 | HTML shell with 8-panel CSS grid | `indrajaal_gleam_web.gleam` (planning page) | 30m |
| 4 | JavaScript: Kanban drag-drop + SVG graph | Embedded in HTML | 30m |
| 5 | JavaScript: AG-UI EventSource client | Embedded in HTML | 15m |
| 6 | JavaScript: Chat interface with TOOL_CALL rendering | Embedded in HTML | 15m |
| 7 | TUI: Enhanced planning_view with 8-panel ANSI layout | `ui/tui/planning_dashboard_view.gleam` | 20m |
| 8 | Tests for all new Lustre update/query functions | `test/planning_dashboard_test.gleam` | 20m |
| **Total** | | | **~3h** |

---

## Fractal Layer x Component x Behavioral Aspect Matrix

This matrix proves complete coverage: every fractal layer, every component, every behavioral aspect.

### L0_CONSTITUTIONAL x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| SafetyKernel Actor | State type (is_active, threat_level, guardian_health) | OTP gen_server message loop | BEAM process with crash recovery |
| Constitutional Checks | SafetyCheck DU (10 variants) | Exhaustive Psi/Omega evaluation | OTP call with timeout |
| ProofToken | Opaque String type | SHA-256 validation | Erlang crypto module |
| Emergency Stop | Result(Nil, String) | Cascade: local → mesh → SSE | Zenoh broadcast + AG-UI CUSTOM |
| Quarantine | List(String) | Add/remove/check membership | In-process state (actor) |

### L1_ATOMIC_DEBUG x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| AG-UI Events | 17-variant EventType | SSE frame serialization | Mist HTTP streaming |
| OTel Export | OTLP JSON payload | POST to collector:4318 | Hackney HTTP client |
| Zenoh Telemetry | Topic string patterns | Pub/sub with QoS | Zenoh C library via NIF |
| Violation Audit | ViolationRecord type | Append-only list | Pure Gleam List |
| SSE Stream | text/event-stream | data: {json}\n\n framing | Mist response body |

### L2_COMPONENT x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| Task CRUD | Task record (18 fields) | create/set/assign/tag/complete | Pure functional transforms |
| Parser | Regexp patterns | Line-by-line regex extraction | BEAM regexp NIF |
| Serializer | String builder | Task → "## id - title [STATUS]" | Pure string concatenation |
| Validator | PlanningError DU | InvalidTransition/NotFound/DB/Validation | Pattern matching |

### L3_TRANSACTION x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| Enforcer | RequestContext + AccessDecision | 5-layer pipeline evaluation | Pure (stateless per request) |
| Rate Limiter | RateLimitState (Dict counts) | Window-based counting | Pure Dict transforms |
| Circuit Breaker | ViolationRecord list | Open after N violations | Pure list filtering |
| Graph Verifier | Graph (nodes + edges) | DFS/BFS/Tarjan/Kahn algorithms | Pure recursive/iterative |
| Access Control | AccessPolicy (rules + default_deny) | First-match-wins rule evaluation | Pure list traversal |
| Chaya Sync | SyncReport (5 phases) | Read→Detect→Convert→Regen→Verify | Pure pipeline |
| Math CPM | CpmResult (ES/EF/LS/LF/Slack) | Forward/backward pass | Pure Dict transforms |
| Repository | SQL DDL + DML | INSERT OR REPLACE + SELECT | DuckDB FFI |

### L4_SYSTEM x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| Boot Sequence | BootState (5 stages) | Sequential stage execution | Pure fold |
| Container DFA | ContainerState (14 states) | Valid transition checking | Pure pattern match |
| Execution Waves | ExecutionWave list | Dependency-sorted parallel groups | Pure graph algorithm |
| Orchestration | Service registry (7 services) | Status tracking + health quorum | Pure Dict operations |

### L5_COGNITIVE x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| OODA Observe | Observation list | Health/Metric/Event constructors | Pure |
| OODA Orient | Assessment (Pattern + ImpactScope) | Error classification (8 patterns) | Pure string matching |
| OODA Decide | Decision (ActionType + score) | Score = Impact × (1-Risk) / Effort | Pure arithmetic |
| OODA Act | Result(String, String) | Execute decided action | Side-effect (stub) |
| Chat Interface | ChatMessage list | NL command → TOOL_CALL dispatch | AG-UI SSE + MCP |
| Generative UI | A2UI widget tree | Agent-proposed HTML/CSS/JS | Browser DOM rendering |

### L6_ECOSYSTEM x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| ZenohAdapter | Topic strings | Publish task/sync events | Zenoh NIF (graceful fallback) |
| A2A Bus | c3i/a2a/{src}/{tgt} topics | Direct messaging + broadcast | Zenoh pub/sub |
| AG-UI Fan-Out | c3i/agui/events/{agent} | Event distribution to mesh | Zenoh pub/sub |
| Mesh Broadcast | c3i/a2a/broadcast | Emergency stop + state sync | Zenoh pub/sub |

### L7_FEDERATION x Components

| Component | Structural | Behavioral | Runtime |
|-----------|-----------|-----------|---------|
| Task Distribution | Dict(String, List(String)) | RoundRobin/LeastLoaded/Priority/Affinity | Pure algorithms |
| Service Coordination | CoordinationResult | Cross-service task creation | Message passing |
| Guardian Consensus | String (approval token) | Request → Validate → Approve/Deny | Inter-service call |
| Health Quorum | Bool | >50% services online check | Pure count comparison |
| OODA Coordination | CoordinationResult | Cross-service O→O→D→A | Orchestrated pipeline |

---

## Use Case to Panel Mapping (Complete)

| UC | Name | Primary Panel | Supporting Panels | AG-UI Events |
|:--:|------|:------------:|:-----------------:|:-------------|
| 001 | Create Task | 1 Task Board | 3 Safety, 4 Enforcer | TOOL_CALL, STATE_DELTA |
| 002 | Update Status | 1 Task Board | 7 Chaya | TOOL_CALL, STATE_DELTA |
| 003 | Cold Start Init | 8 Startup | 1 Task Board | STEP (per stage) |
| 004 | Destructive Op | 3 Safety | Chat | REASONING, Interrupt |
| 005 | OODA Cycle | 2 OODA | 6 Orchestration | RUN, STEP (4 phases) |
| 006 | Chaya Sync | 7 Chaya | 1 Task Board | STEP (5 phases) |
| 007 | Graph Verify | 5 Graph | 4 Enforcer | STEP (4 checks) |
| 008 | Orchestration | 6 Orch Mesh | 2 OODA | STATE_DELTA, TOOL_CALL |
| 009 | Startup Optim | 8 Startup | 6 Orch | ACTIVITY_DELTA |
| 010 | 5-Layer Enforcer | 4 Enforcer | 3 Safety | CUSTOM (circuit) |
| 011 | Safety Kernel | 3 Safety | Chat | REASONING (Psi chain) |
| 012 | Zenoh Events | All | All | RAW (Zenoh passthrough) |
| 013 | Markdown Parse | 1 Task Board | 7 Chaya | STATE_SNAPSHOT |
| 014 | CLI Dispatch | Chat | All | TEXT_MESSAGE |

## Cockpit Mode Transition Rules

```
                        health >= 90%
DARK ◄──────────────────────────────────────── NORMAL
  │                                               │
  │ health < 90%                     health < 70%  │
  ▼                                               ▼
 DIM ────────────────────────────────────────► BRIGHT
  │                                               │
  │ health < 70%                   critical alert  │
  ▼                                               ▼
BRIGHT ──────────────────────────────────► EMERGENCY
```

| Mode | Visible Panels | Color | Sound |
|------|---------------|-------|-------|
| Dark | Safety only (always visible) | Black background, dim green text | Silent |
| Dim | Safety + any panel with warnings | Dark grey, amber accents | None |
| Normal | All 8 panels | Standard dark theme | None |
| Bright | All 8 panels, anomalies enlarged | Bright contrast, red accents | Chime on new alert |
| Emergency | Safety fullscreen, Emergency Stop prominent | Red overlay, white text | Continuous alarm |
