# Journal: Fractal Agentic UI System Design — AG-UI + A2UI + Ratatui Integration

**Date**: 2026-04-03 15:00 CEST
**Author**: Claude Opus 4.6
**Type**: Architecture / Design / Research

---

## 1. Scope & Trigger

**Trigger**: User requested a comprehensive update of ALL Gleam interfaces to use an Agentic AI-based
approach for full lifecycle. Each UI element to be treated as a fractal element mapped to an agentic
UI system. The goal is to identify everything needed for a fully usable and functional Fractal Agentic
UI system across all fractal layers (L0-L7) for the current Gleam + Lustre codebase.

**Research Sources**:
1. **AG-UI Protocol** (docs.ag-ui.com) — PRIMARY: Open event-based protocol for agent-to-UI
2. **Google A2UI** (Agent-to-UI) — Declarative component catalog with trusted rendering
3. **Microsoft Golden Triangle** — AG-UI + DevUI + OpenTelemetry integration
4. **Generative UI Paper** — Academic foundations for agent-generated interfaces
5. **AI Focus Embedding** — Agent embedding patterns (islands architecture, hyper-embedding)
6. **Ratatui/awesome-ratatui** — Rust TUI patterns (Elm architecture, reactive widgets, sparklines)

**Scope**: Full Fractal Agentic UI system covering:
- All 59 existing Gleam UI files (22 Lustre + 14 Wisp + 22 TUI + 1 domain)
- All 3 AG-UI modules (events, sse, zenoh_bus)
- All 8 fractal layers (L0-L7)
- All 12 Page domain variants
- AG-UI protocol compliance (26+ event types)
- A2UI declarative component catalog
- Ratatui-inspired TUI patterns

---

## 2. Pre-State Assessment

### 2.1 Current AG-UI Implementation (3 files, ~350 lines)

| File | Lines | Coverage | Gap |
|------|-------|----------|-----|
| `agui/events.gleam` | 290 | 17/26 event types implemented (65%) | Missing: TextMessageChunk, ToolCallArgs, ToolCallResult, ToolCallChunk, MessagesSnapshot, ActivitySnapshot, ActivityDelta, ReasoningStart/End/Content, ReasoningEncryptedValue |
| `agui/sse.gleam` | 85 | Basic SSE stream creation | No true streaming (builds complete string), no cancellation, no resume, no backpressure |
| `agui/zenoh_bus.gleam` | 60 | Publish + broadcast + direct send | No subscription handling, no event replay, no topic filtering |

### 2.2 Current Lustre App (1 file, 98 lines)

| Component | Status | Gap |
|-----------|--------|-----|
| Model | Basic (context, dark_cockpit, page) | No agent state, no run tracking, no tool call state, no HITL state |
| Msg | 6 variants | No AG-UI event msgs, no A2UI component msgs, no reasoning msgs |
| update | Simple dispatch | No effect system, no agent coordination, no state delta application |
| view | `health_class` only | No actual Lustre HTML rendering, no component catalog |

### 2.3 What's Missing for Full Agentic UI

| Category | Current | Required |
|----------|---------|----------|
| AG-UI Events | 17/26 types | All 26+ types + Activity + Reasoning (30+) |
| AG-UI Transport | Batch SSE only | True SSE streaming with OTP actors |
| AG-UI State | Snapshot only | Snapshot + Delta (RFC 6902 JSON Patch) |
| AG-UI Tools | Start/End only | Full lifecycle: Start → Args → End → Result + HITL |
| A2UI Components | None | Declarative component catalog with trusted rendering |
| Generative UI | None | Agent-proposed dynamic widgets per A2UI spec |
| HITL | None | Pause, approve, edit, retry, escalate mid-flow |
| Sub-Agent | None | Nested delegation with scoped state + tracing |
| Reasoning | None | Visible chain-of-thought + encrypted persistence |
| Multimodal | None | Files, images, audio, transcripts |
| TUI Agentic | Basic render | Ratatui-inspired reactive widgets with AG-UI events |
| Fractal Mapping | None | Each element as fractal holon at L0-L7 |

---

## 3. Execution Detail

### 3.1 AG-UI Protocol — Complete Event Taxonomy (Researched)

**26 Defined Events + 6 Draft/Reasoning Events = 32 Total**

#### Lifecycle Events (5)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `RUN_STARTED` | threadId, runId | Establish execution context |
| `RUN_FINISHED` | threadId, runId | Clean termination |
| `RUN_ERROR` | message, code | Unrecoverable failure |
| `STEP_STARTED` | stepName | Subtask/phase begin |
| `STEP_FINISHED` | stepName | Subtask/phase end |

#### Text Message Events (4)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `TEXT_MESSAGE_START` | messageId, role | Initialize message |
| `TEXT_MESSAGE_CONTENT` | messageId, delta | Stream content chunks |
| `TEXT_MESSAGE_END` | messageId | Finalize message |
| `TEXT_MESSAGE_CHUNK` | messageId (first) | Convenience wrapper |

#### Tool Call Events (5)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `TOOL_CALL_START` | toolCallId, toolCallName | Initiate tool invocation |
| `TOOL_CALL_ARGS` | toolCallId, delta | Stream argument chunks |
| `TOOL_CALL_END` | toolCallId | Finalize argument transmission |
| `TOOL_CALL_RESULT` | messageId, toolCallId, content | Return tool execution result |
| `TOOL_CALL_CHUNK` | toolCallId, toolCallName (first) | Convenience wrapper |

#### State Management Events (3)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `STATE_SNAPSHOT` | snapshot (JSON) | Complete state replacement |
| `STATE_DELTA` | delta (RFC 6902 JSON Patch array) | Incremental state update |
| `MESSAGES_SNAPSHOT` | messages (array) | Full conversation history |

#### Activity Events (2)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `ACTIVITY_SNAPSHOT` | messageId, activityType, content | Complete activity state |
| `ACTIVITY_DELTA` | messageId, activityType, patch | Incremental activity update |

#### Reasoning Events (6)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `REASONING_START` | messageId | Begin reasoning context |
| `REASONING_MESSAGE_START` | messageId, role("reasoning") | Start streaming reasoning |
| `REASONING_MESSAGE_CONTENT` | messageId, delta | Stream reasoning chunks |
| `REASONING_MESSAGE_END` | messageId | Finalize reasoning message |
| `REASONING_MESSAGE_CHUNK` | messageId | Convenience wrapper |
| `REASONING_ENCRYPTED_VALUE` | subtype, entityId, encryptedValue | Encrypted chain-of-thought |

#### Special Events (2)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `RAW` | event | Forward external system events |
| `CUSTOM` | name, value | Application-specific extensions |

#### Draft Events (2)
| Event | Required Fields | Purpose |
|-------|----------------|---------|
| `META_EVENT` (draft) | metaType, payload | Side-band annotations |
| Extended lifecycle (draft) | outcome, interrupt, parentRunId | Enhanced run lifecycle |

### 3.2 A2UI Protocol — Declarative Component Catalog (Researched)

**Core Concepts**:
- Agents generate JSON payloads describing component trees, NOT executable code
- Applications maintain a **catalog of pre-approved components** (security boundary)
- **Flat list with ID references** — easy for LLMs to generate incrementally
- **Framework-agnostic** — same JSON renders across Flutter, Angular, Web Components, Gleam/Lustre
- Separates UI structure from implementation (agents describe WHAT, not HOW)

**A2UI JSON Schema Pattern**:
```json
{
  "components": [
    { "id": "task-board", "type": "kanban", "props": { "columns": ["pending", "active", "done"] } },
    { "id": "health-badge", "type": "badge", "props": { "severity": "healthy", "label": "SIL-6" } }
  ],
  "layout": { "type": "grid", "rows": 2, "cols": 4 },
  "bindings": { "task-board.data": "state.tasks", "health-badge.severity": "state.health" }
}
```

### 3.3 Microsoft Golden Triangle Pattern (Researched)

Three integrated layers:
1. **DevUI** — Inner-loop debugging: chain-of-thought visualization, memory inspection, decision flowcharts
2. **AG-UI** — Standardized interaction: SSE streaming, generative UI, HITL approval
3. **OpenTelemetry** — Observability: distributed tracing, token consumption, flame graphs

**Mapping to c3i**: DevUI ≅ Prajna Cockpit, AG-UI ≅ agui/ module, OpenTelemetry ≅ telemetry/otel.gleam + Zenoh

### 3.4 Ratatui TUI Patterns (Researched)

Key patterns for upgrading TUI layer:
- **Elm-style MVU architecture** (tui-realm) — already matches Gleam idiom
- **Stateful widgets** with internal state management (ratatui-textarea)
- **Event-queue frameworks** (rat-salsa) — tasks, timers, application events
- **Compositional systems** (ratatui-garnish) — widget composition
- **Form/input abstractions** with focus handling
- **Sparklines and visual indicators** (already in visuals.gleam)

---

## 4. Root Cause Analysis

**Why is a Fractal Agentic UI needed?**

1. **Current UI is passive** — Components render data but don't interact with agents
2. **No agent lifecycle in UI** — No run tracking, step visibility, tool call rendering
3. **No human-in-the-loop** — Operators can't approve/reject/modify agent proposals
4. **No generative UI** — Agents can't propose dynamic widgets based on context
5. **No reasoning visibility** — Agent chain-of-thought is invisible to operators
6. **TUI is static** — Terminal views render once, don't respond to AG-UI events
7. **SSE is batch** — Builds complete string instead of true streaming
8. **No fractal mapping** — UI elements aren't treated as holons at specific layers

---

## 5. Fix Taxonomy — Fractal Agentic UI System Components

### Complete System Map: What Must Be Built

```
FRACTAL AGENTIC UI SYSTEM
├── L0: Constitutional Layer (Safety & Governance)
│   ├── guardian_approval_widget.gleam      — HITL approval/reject/escalate
│   ├── constitutional_monitor.gleam        — Psi-0..5 violation display
│   ├── founder_directive_panel.gleam       — Omega-0 survival indicators
│   └── emergency_stop_control.gleam        — Immediate halt + rollback
│
├── L1: Atomic/Debug Layer (Telemetry & Tracing)
│   ├── trace_viewer.gleam                  — OpenTelemetry flame graphs
│   ├── reasoning_panel.gleam               — Chain-of-thought visibility
│   ├── event_stream_monitor.gleam          — Raw AG-UI event feed
│   └── zenoh_message_trace.gleam           — Zenoh pub/sub traffic
│
├── L2: Component Layer (Widgets & Forms)
│   ├── a2ui_catalog.gleam                  — Declarative component registry
│   ├── a2ui_renderer.gleam                 — JSON → Lustre element mapping
│   ├── form_widgets.gleam                  — Input, textarea, select, checkbox
│   ├── data_grid.gleam                     — Sortable/filterable tables
│   └── badge_system.gleam                  — Severity badges, status pills
│
├── L3: Transaction Layer (State & Tools)
│   ├── state_manager.gleam                 — Snapshot + Delta (RFC 6902)
│   ├── json_patch.gleam                    — RFC 6902 operations implementation
│   ├── tool_call_panel.gleam               — Tool invocation lifecycle display
│   ├── tool_result_renderer.gleam          — Tool output rendering
│   └── conversation_history.gleam          — Messages snapshot + threading
│
├── L4: System Layer (Agent Lifecycle)
│   ├── agent_runner.gleam                  — OTP actor for AG-UI run lifecycle
│   ├── agent_registry.gleam                — Multi-agent registration + discovery
│   ├── run_monitor.gleam                   — Active runs dashboard
│   ├── step_tracker.gleam                  — Step-by-step progress display
│   └── error_handler.gleam                 — RUN_ERROR display + recovery
│
├── L5: Cognitive Layer (AI & Reasoning)
│   ├── reasoning_stream.gleam              — Reasoning events → visible CoT
│   ├── ai_copilot_widget.gleam             — Inline AI suggestions
│   ├── generative_ui_engine.gleam          — Agent-proposed dynamic widgets
│   ├── ooda_ring.gleam                     — OODA cycle visualization
│   └── encrypted_reasoning.gleam           — ReasoningEncryptedValue handling
│
├── L6: Ecosystem Layer (Multi-Agent & Mesh)
│   ├── sub_agent_compositor.gleam          — Nested delegation display
│   ├── agent_mesh_topology.gleam           — Multi-agent visualization
│   ├── zenoh_event_bridge.gleam            — Zenoh → AG-UI event adapter
│   ├── a2a_message_panel.gleam             — Agent-to-agent communication
│   └── broadcast_handler.gleam             — Mesh-wide state propagation
│
├── L7: Federation Layer (Cross-System)
│   ├── federation_gateway.gleam            — Cross-holon AG-UI events
│   ├── version_vector_display.gleam        — Causal ordering visualization
│   ├── attestation_panel.gleam             — Ed25519 peer verification
│   └── remote_agent_proxy.gleam            — Proxy to remote AG-UI agents
│
├── AGUI Core (Protocol Implementation)
│   ├── agui/events.gleam                   — ALL 32 event types ← UPGRADE
│   ├── agui/sse.gleam                      — True OTP streaming ← REWRITE
│   ├── agui/zenoh_bus.gleam                — Bidirectional + subscribe ← UPGRADE
│   ├── agui/transport.gleam                — NEW: Transport abstraction
│   ├── agui/middleware.gleam               — NEW: Event transformation
│   ├── agui/serialization.gleam            — NEW: History/branch/compact
│   ├── agui/capabilities.gleam             — NEW: Dynamic capability discovery
│   └── agui/multimodal.gleam               — NEW: Files, images, audio
│
├── A2UI Core (Declarative UI)
│   ├── a2ui/schema.gleam                   — NEW: A2UI JSON schema types
│   ├── a2ui/catalog.gleam                  — NEW: Trusted component registry
│   ├── a2ui/renderer.gleam                 — NEW: JSON → Lustre mapping
│   ├── a2ui/bindings.gleam                 — NEW: Data binding engine
│   └── a2ui/validator.gleam                — NEW: Security validation
│
├── Lustre Interface (Web SSR) — UPGRADED
│   ├── app.gleam                           — Full AG-UI Model/Msg ← REWRITE
│   ├── 22 domain views                     — Each becomes fractal holon
│   └── layout/shell.gleam                  — NEW: Responsive grid shell
│
├── Wisp Interface (REST API) — UPGRADED
│   ├── router.gleam                        — AG-UI SSE endpoints ← UPGRADE
│   ├── 14 domain APIs                      — Each emits AG-UI events
│   └── agui_endpoint.gleam                 — NEW: /agui/run SSE endpoint
│
└── TUI Interface (Terminal) — UPGRADED
    ├── renderer.gleam                      — Ratatui-inspired reactive ← REWRITE
    ├── 22 domain views                     — Each subscribes to AG-UI events
    └── tui_agent_panel.gleam               — NEW: Agent reasoning in terminal
```

---

## 6. Patterns & Anti-Patterns Discovered

### 6.1 Fractal Agentic Element Pattern (NEW)

Every UI element is a **Fractal Agentic Holon** with these properties:

```gleam
/// A fractal agentic element — the atomic unit of the Agentic UI system.
/// Every element exists at a specific fractal layer and can:
/// 1. Emit AG-UI events (observe)
/// 2. Receive AG-UI events (react)
/// 3. Propose A2UI components (generate)
/// 4. Accept human input (HITL)
/// 5. Delegate to sub-agents (compose)
pub type FractalElement {
  FractalElement(
    id: String,                        // Unique holon identity (FQUN)
    layer: FractalLayer,               // L0-L7 placement
    element_type: ElementType,         // Widget, Panel, Dashboard, etc.
    agent_binding: Option(AgentBinding), // Connected agent (if any)
    state: ElementState,               // Current state (via AG-UI)
    children: List(FractalElement),    // Fractal children (self-similar)
    capabilities: List(Capability),    // What this element can do
    stamp_controls: List(String),      // SC-* constraints
  )
}

pub type FractalLayer {
  L0Constitutional | L1AtomicDebug | L2Component | L3Transaction
  | L4System | L5Cognitive | L6Ecosystem | L7Federation
}

pub type ElementType {
  Dashboard | Panel | Widget | Badge | DataGrid | Form
  | ActionButton | Chart | Timeline | ReasoningView | ToolCallView
  | GenerativeSlot  // A2UI: agent can fill this with proposed UI
}

pub type AgentBinding {
  AgentBinding(
    agent_id: String,
    run_id: Option(String),
    subscribed_events: List(EventType),
    emitted_events: List(EventType),
  )
}

pub type Capability {
  EmitEvents | ReceiveEvents | ProposeUI | AcceptHITL
  | DelegateToSubAgent | PersistState | StreamContent
}
```

### 6.2 AG-UI Lifecycle Pattern for Each Interface

```
USER ACTION → Lustre Msg → AG-UI RUN_STARTED → Agent processes
                                                    ↓
Lustre view ← STATE_DELTA ←── STEP_STARTED ←── Agent step
     ↓                              ↓
TUI render ← same events      TOOL_CALL_START → Frontend tool
     ↓                              ↓
Wisp JSON  ← same events      TOOL_CALL_RESULT → Agent continues
                                    ↓
All 3 ←──── TEXT_MESSAGE_CONTENT (streaming)
     ↓
All 3 ←──── RUN_FINISHED
```

### 6.3 A2UI Component Catalog Pattern

```gleam
/// Trusted component catalog — agents can only request components from this registry.
/// This is the security boundary (A2UI principle).
pub type ComponentCatalog {
  ComponentCatalog(components: Dict(String, ComponentSpec))
}

pub type ComponentSpec {
  ComponentSpec(
    name: String,
    props_schema: json.Json,  // JSON Schema for accepted props
    layer: FractalLayer,      // Which fractal layer this belongs to
    renderer: fn(json.Json) -> Element(Msg),  // Lustre renderer
    tui_renderer: fn(json.Json) -> String,    // TUI renderer
    api_schema: fn(json.Json) -> json.Json,   // API serializer
  )
}
```

### 6.4 Anti-Patterns to Avoid

1. **Executable UI from agents** — NEVER let agents send code; use A2UI declarative JSON only
2. **Polling for updates** — ALWAYS use AG-UI SSE streaming; never setTimeout/poll
3. **Monolithic state** — Use STATE_DELTA (RFC 6902) for incremental updates, not full snapshots
4. **Silent reasoning** — ALWAYS surface agent reasoning via REASONING events
5. **Untyped tool calls** — ALWAYS use JSON Schema for tool parameters
6. **Blocking HITL** — Approval must be non-blocking; use interrupt-aware run lifecycle

---

## 7. Verification Matrix

### 7.1 Fractal Layer Coverage Matrix

Every item below MUST be implemented for a complete Fractal Agentic UI:

| Layer | Domain | AG-UI Events Used | A2UI Components | HITL Points | STAMP |
|-------|--------|-------------------|-----------------|-------------|-------|
| **L0 Constitutional** | Safety kernel, Guardian | CUSTOM(psi_check), TOOL_CALL(guardian_approve) | emergency_stop, approval_dialog, violation_alert | Approve/reject/escalate critical operations | SC-SAFETY-001..022, SC-GUARD-001..003 |
| **L1 Atomic/Debug** | Telemetry, tracing | RUN_STARTED/FINISHED, STEP_*, RAW(otel_span) | trace_flame_graph, event_log, reasoning_panel | Pause trace capture, filter events | SC-DEBUG-001..010, SC-LOG-001..010 |
| **L2 Component** | Widgets, forms | TEXT_MESSAGE_*, CUSTOM(form_submit) | text_input, select, checkbox, badge, data_cell | Edit form values, correct agent suggestions | SC-GRID-001..025, SC-COMONAD-001..008 |
| **L3 Transaction** | State, DB, tools | STATE_SNAPSHOT, STATE_DELTA, TOOL_CALL_*, TOOL_CALL_RESULT | state_diff_view, tool_progress, db_query_result | Approve tool execution, edit tool args | SC-STM-001..008, SC-CONC-001..010 |
| **L4 System** | Containers, mesh | RUN_STARTED/FINISHED/ERROR, STEP_* | container_card, health_gauge, run_timeline | Restart failed runs, retry errors | SC-CNT-001..019, SC-OODA-001..009 |
| **L5 Cognitive** | AI, reasoning, OODA | REASONING_*, TEXT_MESSAGE_*, ACTIVITY_* | ooda_ring, reasoning_stream, ai_suggestion | Accept/reject AI recommendations, edit reasoning | SC-ACE-001..039, SC-SEM-001..072 |
| **L6 Ecosystem** | Multi-agent, Zenoh | CUSTOM(a2a_message), STATE_DELTA(mesh) | agent_topology, zenoh_topic_tree, broadcast_view | Route messages, approve agent delegation | SC-DIST-001..010, SC-AGENT-001..005 |
| **L7 Federation** | Cross-holon | CUSTOM(federation_event), MESSAGES_SNAPSHOT | peer_map, version_vector, attestation_badge | Approve cross-holon operations | SC-FED-001..006, SC-HA-001..011 |

### 7.2 Interface Completeness Matrix

| Feature | Lustre (Web) | Wisp (API) | TUI (Terminal) | AG-UI Core |
|---------|:---:|:---:|:---:|:---:|
| All 32 AG-UI event types | Consume | Emit | Consume | Define |
| SSE true streaming | Render live | Serve SSE | N/A | Transport |
| STATE_SNAPSHOT | Apply to Model | Return JSON | Apply to state | Serialize |
| STATE_DELTA (RFC 6902) | Patch Model | Return patch | Patch state | Patch ops |
| Tool call lifecycle | Render progress | Execute tools | Show progress | Events |
| Tool result rendering | Inline display | JSON response | Text display | Events |
| HITL approval | Modal dialog | Webhook/callback | Prompt input | Pause/resume |
| A2UI component catalog | Lustre renderer | Schema JSON | ANSI renderer | Validate |
| Generative UI | Dynamic slots | API proposals | Dynamic panels | Custom events |
| Reasoning visibility | Expandable panel | Stream reasoning | CoT text | Reasoning events |
| Multi-agent composition | Nested views | Proxy routing | Split panes | Sub-agent events |
| Multimodal | Image/file display | Binary upload | ASCII art | Typed attachments |
| Conversation history | Chat thread | Messages API | Scrollback | MessagesSnapshot |
| Dark Cockpit | CSS classes | Mode in JSON | ANSI dim/bright | Custom events |
| Cancel/resume | Button + ESC | DELETE /run | Ctrl+C handler | RunError + resume |

### 7.3 Existing File Upgrade Requirements

| File Category | Count | Upgrade Needed |
|---------------|-------|---------------|
| `agui/events.gleam` | 1 | Add 15 missing event types (Reasoning, Activity, Chunk variants, MessagesSnapshot) |
| `agui/sse.gleam` | 1 | Rewrite: OTP actor-based true streaming with backpressure |
| `agui/zenoh_bus.gleam` | 1 | Add subscription handling, event replay, topic filtering |
| `ui/lustre/*.gleam` | 22 | Each: add AG-UI event subscription, fractal element metadata, A2UI generative slots |
| `ui/wisp/*.gleam` | 14 | Each: add AG-UI event emission, SSE streaming endpoints |
| `ui/tui/*.gleam` | 22 | Each: add AG-UI event subscription, reactive rendering, Ratatui patterns |
| `ui/domain.gleam` | 1 | Add FractalElement type, AgentBinding, Capability, A2UI types |
| `prajna/dark_cockpit.gleam` | 1 | Map CockpitMode to AG-UI CUSTOM events |
| `cockpit/visuals.gleam` | 1 | Add AG-UI-aware rendering (sparklines from STATE_DELTA) |

---

## 8. Files Modified

| Action | File | Description |
|--------|------|-------------|
| CREATED | `docs/journal/20260403-1500-fractal-agentic-ui-system-design.md` | This journal entry |
| PLANNED | 12 new modules in `agui/` | Transport, middleware, serialization, capabilities, multimodal |
| PLANNED | 5 new modules in `a2ui/` | Schema, catalog, renderer, bindings, validator |
| PLANNED | ~30 new fractal layer modules | L0-L7 agentic widgets |
| PLANNED | 59 existing files to upgrade | AG-UI event integration across all interfaces |
| PLANNED | Rule update | `.claude/rules/gleam-web-ui-development.md` to include AG-UI/A2UI |

---

## 9. Architectural Observations

### 9.1 The Fractal Agentic Holon Model

Every UI element in the system is modeled as a **holon** — simultaneously a whole (containing sub-elements) and a part (belonging to a larger dashboard). This maps directly to the c3i fractal architecture:

```
Dashboard (L4-System holon)
├── Planning Panel (L3-Transaction holon)
│   ├── Task Board Widget (L2-Component holon)
│   │   ├── Task Card (L2-Component holon)
│   │   │   ├── Priority Badge (L2 fractal leaf)
│   │   │   ├── Status Badge (L2 fractal leaf)
│   │   │   └── Action Button (L0 — guardian-gated)
│   │   └── Column Header (L2 fractal leaf)
│   ├── OODA Ring Widget (L5-Cognitive holon)
│   │   ├── Phase Indicator (L5 fractal leaf)
│   │   └── Cycle Timer (L1-Debug)
│   └── Safety Panel (L0-Constitutional holon)
│       ├── Psi Indicator × 6 (L0 fractal leaves)
│       └── Emergency Stop (L0 — HITL required)
└── Agent Stream Panel (L6-Ecosystem holon)
    ├── Reasoning Stream (L5-Cognitive)
    ├── Tool Call Display (L3-Transaction)
    └── A2A Message Feed (L6 fractal leaf)
```

### 9.2 AG-UI as Universal Transport

AG-UI becomes the **universal event bus** for all three interfaces:

```
                    AG-UI Event Stream (SSE/Zenoh)
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                  ▼
      Lustre (Web)       Wisp (API)          TUI (Terminal)
      MVU update()       JSON response       ANSI render()
            │                 │                  │
            └─────── Shared domain.gleam ────────┘
                    (FractalElement types)
```

### 9.3 A2UI as Security Boundary

A2UI's declarative approach solves a critical SIL-6 safety concern: agents MUST NOT inject executable
UI code. The component catalog pattern ensures:
1. Only pre-approved components can be rendered (SC-SAFETY-001)
2. Agent proposals are JSON data, not executable code
3. The catalog acts as a type-safe allowlist
4. Each component has its fractal layer assignment (prevents L0 spoofing from L3)

### 9.4 Triple Transport Convergence

| Transport | Lustre | Wisp | TUI | Zenoh |
|-----------|--------|------|-----|-------|
| AG-UI SSE | Client subscribes | Server emits | N/A | Bridge |
| A2UI JSON | Lustre renderer | Schema response | ANSI renderer | Broadcast |
| Zenoh PubSub | Via SSE bridge | Via API proxy | Direct subscribe | Native |
| RFC 6902 Patch | Apply to Model | Emit as delta | Apply to state | Replicate |

### 9.5 Ratatui Pattern Mapping to Gleam TUI

| Ratatui Pattern | Gleam TUI Equivalent | Module |
|----------------|---------------------|--------|
| Elm-style MVU (tui-realm) | Already matches Gleam idiom | `tui/renderer.gleam` |
| Stateful widgets | Gleam custom types with state | Each `*_view.gleam` |
| Event queue (rat-salsa) | OTP message passing | `agui/zenoh_bus.gleam` |
| Sparklines | Already in `visuals.gleam` | `cockpit/visuals.gleam` |
| Form/input (rat-widget) | New: TUI form inputs | `tui/forms.gleam` (NEW) |
| Compositional (garnish) | Gleam function composition | `tui/compositor.gleam` (NEW) |

---

## 10. Remaining Gaps

### 10.1 Implementation Priorities (Ordered)

| Phase | Priority | Items | Effort | Dependencies |
|-------|----------|-------|--------|-------------|
| **Phase 1: AG-UI Core** | P0 | Complete all 32 event types, OTP streaming SSE, JSON Patch (RFC 6902) | 3-5 days | None |
| **Phase 2: State Engine** | P0 | state_manager.gleam, json_patch.gleam, conversation_history.gleam | 2-3 days | Phase 1 |
| **Phase 3: Tool Lifecycle** | P1 | Full tool call flow (Args, Result, Chunk), HITL approval | 2-3 days | Phase 1 |
| **Phase 4: A2UI Catalog** | P1 | Schema, catalog, renderer, bindings, validator | 3-4 days | Phase 1 |
| **Phase 5: Lustre Upgrade** | P1 | Rewrite app.gleam with full AG-UI Model/Msg, upgrade all 22 views | 5-7 days | Phase 1-4 |
| **Phase 6: Reasoning** | P2 | All 6 reasoning events, visible CoT panel, encrypted persistence | 2-3 days | Phase 1 |
| **Phase 7: Wisp Upgrade** | P2 | SSE streaming endpoint, AG-UI event emission in all 14 APIs | 3-4 days | Phase 1-2 |
| **Phase 8: TUI Upgrade** | P2 | Ratatui-inspired reactive rendering, AG-UI subscription in all 22 views | 4-5 days | Phase 1-2 |
| **Phase 9: Fractal Layer Modules** | P2 | L0-L7 specialized widgets (~30 modules) | 7-10 days | Phase 1-5 |
| **Phase 10: Multi-Agent** | P3 | Sub-agent composition, A2A mesh display, delegation | 3-4 days | Phase 6-7 |
| **Phase 11: Multimodal** | P3 | Files, images, audio, transcripts | 2-3 days | Phase 1 |
| **Phase 12: Federation** | P3 | Cross-holon AG-UI, remote agent proxy, attestation | 3-4 days | Phase 9-10 |

**Total: ~40-55 new/rewritten modules, ~100 files touched**

### 10.2 Open Questions

1. **Gleam OTP streaming**: Can Gleam actors efficiently emit SSE events, or do we need Erlang FFI?
2. **A2UI rendering security**: How to prevent component catalog bypass in Gleam's type system?
3. **TUI input handling**: Does Gleam have keyboard event libraries, or do we need Erlang io?
4. **Zenoh subscription in Gleam**: Current zenoh/client.gleam only has `put()` — need `subscribe()`
5. **HITL UX in TUI**: How to present approval dialogs in a terminal (blocking vs async)?

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| AG-UI event types researched | 32 (26 defined + 6 draft/reasoning) |
| AG-UI event types currently implemented | 17 (65%) |
| AG-UI event types to add | 15 |
| A2UI concepts documented | 5 (schema, catalog, renderer, bindings, validator) |
| Existing Gleam UI files | 62 (22 Lustre + 14 Wisp + 22 TUI + 1 domain + 3 agui) |
| New modules planned | ~40-55 |
| Files needing upgrade | ~59 |
| Fractal layers covered | 8 (L0-L7) |
| HITL points identified | 8 (one per layer) |
| Research sources consumed | 8 URLs |
| Total implementation phases | 12 |
| Estimated total effort | 40-55 days |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Compliance | Notes |
|------------|-----------|-------|
| SC-GLM-UI-001 | ENHANCED | Triple-interface now includes AG-UI event layer |
| SC-GLM-UI-005 | ENHANCED | Zenoh telemetry now bidirectional with AG-UI bridge |
| SC-GLM-UI-008 | ENHANCED | Dark Cockpit mapped to AG-UI CUSTOM events |
| SC-GLM-UI-010 | FORMALIZED | AG-UI SSE streaming with full 32-event protocol |
| SC-HMI-010 | ENHANCED | Color Rich profiles rendered via A2UI catalog |
| SC-SAFETY-001 | ENFORCED | A2UI security boundary prevents agent code injection |
| SC-OODA-001..009 | MAPPED | OODA cycle tracked via STEP_STARTED/FINISHED events |
| SC-GUARD-001..003 | MAPPED | Guardian approval via TOOL_CALL + HITL pattern |
| Psi-0 (Existence) | PRESERVED | Emergency stop at L0 with HITL |
| Psi-3 (Verification) | ENHANCED | Full event tracing via AG-UI + OpenTelemetry |
| Omega-0 (Survival) | PRESERVED | Constitutional layer always visible, never hidden by Dark Cockpit |

### New STAMP Constraints Defined

| ID | Constraint | Severity |
|----|------------|----------|
| SC-AGUI-001 | ALL 32 AG-UI event types MUST be implemented in events.gleam | CRITICAL |
| SC-AGUI-002 | SSE streaming MUST use OTP actors, not batch string building | HIGH |
| SC-AGUI-003 | STATE_DELTA MUST implement RFC 6902 JSON Patch operations | HIGH |
| SC-AGUI-004 | Tool calls MUST include HITL approval for L0 operations | CRITICAL |
| SC-AGUI-005 | A2UI component catalog MUST be the SOLE UI generation path for agents | CRITICAL |
| SC-AGUI-006 | Reasoning events MUST be surfaced in all 3 interfaces | HIGH |
| SC-AGUI-007 | Each UI element MUST declare its FractalLayer (L0-L7) | HIGH |
| SC-AGUI-008 | Cancel/resume MUST preserve state across interruptions | HIGH |
| SC-AGUI-009 | Multi-agent composition MUST use scoped state isolation | HIGH |
| SC-AGUI-010 | Multimodal attachments MUST be typed (file/image/audio/transcript) | MEDIUM |
| SC-A2UI-001 | Agent UI proposals MUST be declarative JSON, NEVER executable code | CRITICAL |
| SC-A2UI-002 | Component catalog MUST validate proposals against JSON Schema | HIGH |
| SC-A2UI-003 | Each catalog component MUST have Lustre + Wisp + TUI renderers | HIGH |
| SC-A2UI-004 | Component catalog MUST enforce fractal layer access control | HIGH |
| SC-A2UI-005 | A2UI bindings MUST use typed paths, not arbitrary selectors | HIGH |

---

## 13. Conclusion

A comprehensive Fractal Agentic UI system design has been produced, mapping the AG-UI protocol
(32 event types), Google's A2UI declarative component pattern, Microsoft's Golden Triangle
(AG-UI + DevUI + OpenTelemetry), and Ratatui TUI patterns onto the existing c3i Gleam/Lustre
codebase across all 8 fractal layers (L0-L7).

**Key Architectural Decisions**:
1. **AG-UI as universal transport** — All 3 interfaces (Lustre/Wisp/TUI) consume the same event stream
2. **A2UI as security boundary** — Agents propose UI via declarative JSON, never executable code
3. **Every element is a fractal holon** — FractalElement type carries layer, agent binding, capabilities
4. **HITL at every layer** — Human approval/edit/reject points from L0 (constitutional) to L7 (federation)
5. **RFC 6902 JSON Patch** — Bandwidth-efficient state synchronization across all interfaces
6. **OTP actor-based streaming** — True SSE with backpressure, cancel, resume on BEAM

**Current State**: 62 files, 17/32 AG-UI events, batch SSE, no A2UI, no HITL, no reasoning visibility
**Target State**: ~120 files, 32/32 AG-UI events, OTP streaming, full A2UI catalog, HITL at all layers, reasoning panels, fractal element mapping across L0-L7

**12-phase implementation plan** with P0-P3 prioritization, estimated 40-55 days total effort.
