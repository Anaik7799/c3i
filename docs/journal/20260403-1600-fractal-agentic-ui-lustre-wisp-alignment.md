# Journal: Fractal Agentic UI — Lustre & Wisp Ecosystem Alignment

**Date**: 2026-04-03 16:00 CEST
**Author**: Claude Opus 4.6
**Type**: Architecture / Design / Research (Addendum to 20260403-1500)

---

## 1. Scope & Trigger

**Trigger**: User requested alignment of the Fractal Agentic UI system design (from journal
20260403-1500) with the actual Lustre and Wisp ecosystem capabilities. Research Lustre server
components, effect system, full-stack patterns, and Wisp HTTP framework to ensure the design
maps precisely to what these frameworks provide.

**Additional Research Sources** (beyond the 8 from previous journal):
1. **Lustre hexdocs** (hexdocs.pm/lustre) — Framework API, server components, effects
2. **Lustre full-stack guide** — Monorepo pattern, SSR + hydration, shared types
3. **Lustre GitHub** (lustre-labs/lustre) — Source architecture, server_component module
4. **Lustre UI** (lustre-labs/ui) — Component library, themes, accessible widgets
5. **Wisp docs** (gleam-wisp.github.io/wisp) — HTTP framework, middleware, routing
6. **gleam-lustre-wisp-fullstack** — Reference implementation of Lustre+Wisp full-stack

---

## 2. Pre-State Assessment

The previous journal (20260403-1500) designed the Fractal Agentic UI system but treated
Lustre as a simple MVU renderer without accounting for:
- **Lustre Server Components** — full server-side MVU with WebSocket/SSE transport to client
- **Lustre Effect System** — managed side effects as data (`effect.from`, `effect.batch`)
- **Lustre `application()` vs `simple()`** — effects-capable vs effects-free
- **Lustre `start_server_component()`** — headless server runtime with OTP supervision
- **Lustre `factory()`** — dynamic instance creation for multi-agent UIs
- **Lustre `supervised()`** — OTP child spec for fault-tolerant components
- **Wisp's actual capabilities** — no WebSocket/SSE built-in; JSON + routing + middleware only

This addendum corrects and deepens the architecture with precise Lustre/Wisp API alignment.

---

## 3. Execution Detail

### 3.1 Lustre Application Types — What We Have and What to Use

Lustre provides **5 application constructors** with increasing capability:

| Constructor | Effects | State | Use For |
|------------|---------|-------|---------|
| `lustre.element(view)` | No | No | Static HTML rendering |
| `lustre.simple(init, update, view)` | No | Yes | Simple pages without side effects |
| `lustre.application(init, update, view)` | **Yes** | Yes | **Full agentic pages** — HTTP, timers, AG-UI events |
| `lustre.component(init, update, view, options)` | **Yes** | Yes | **Encapsulated agentic widgets** — reusable, isolated state |
| `lustre.start_server_component(app, args)` | **Yes** | Yes | **Server-driven agentic dashboard** — OTP-supervised, client via WebSocket |

**Decision**: The Fractal Agentic UI MUST use `lustre.application()` for pages and
`lustre.component()` for reusable fractal elements. Server components via
`lustre.start_server_component()` are the **primary runtime** for the agent-driven dashboard.

### 3.2 Lustre Server Components — The AG-UI Transport Layer

**THIS IS THE KEY INSIGHT**: Lustre server components already provide exactly what AG-UI needs
for the Web interface:

```
Lustre Server Component Architecture:
  Server (BEAM)                    Client (Browser)
  ┌───────────────┐               ┌───────────────┐
  │ Model (state) │──DOM patches──▶│ Minimal JS    │
  │ Update (logic)│◀──UI events───│ Runtime        │
  │ View (render) │               │ (DOM patching) │
  │ Effects (IO)  │               └───────────────┘
  └───────────────┘
       ↕ OTP messages
  ┌───────────────┐
  │ AG-UI Agent   │
  │ (backend)     │
  └───────────────┘
```

**Transport**: Three options via `TransportMethod`:
1. **WebSocket** (default) — Bidirectional, real-time DOM patches + client events
2. **ServerSentEvents** — Unidirectional server-to-client push (AG-UI SSE compatible!)
3. **Polling** — Fallback

**Protocol**: Server sends `ClientMessage` (encoded via `client_message_to_json()`),
client decodes and patches DOM. Client sends events, server decodes via
`runtime_message_decoder()`.

**OTP Integration**:
- `lustre.supervised(app, args)` → OTP child spec for supervisor trees
- `lustre.factory(app)` → Dynamic instance creation (one per agent run!)
- `server_component.register_subject()` → Receive messages from other OTP processes
- `server_component.select()` → Selective message routing

### 3.3 Lustre Effect System — How AG-UI Events Become Effects

Lustre effects are **data describing side effects**, not executed immediately. This maps
perfectly to AG-UI's event-driven model:

```gleam
import lustre/effect

/// AG-UI effect: subscribe to agent event stream
fn subscribe_to_agent(agent_id: String) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    // Connect to AG-UI SSE endpoint
    // On each event, dispatch appropriate Msg
    start_sse_listener(agent_id, fn(event) {
      case event.event_type {
        events.TextMessageContent -> dispatch(AgentTextDelta(event))
        events.StateSnapshot -> dispatch(AgentStateSnapshot(event))
        events.StateDelta -> dispatch(AgentStateDelta(event))
        events.ToolCallStart -> dispatch(AgentToolCallStarted(event))
        events.RunFinished -> dispatch(AgentRunFinished(event))
        events.RunError -> dispatch(AgentRunError(event))
        _ -> Nil
      }
    })
  })
}

/// AG-UI effect: start an agent run
fn start_agent_run(input: RunInput) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    // POST to /agui/run endpoint, receive SSE stream
    http_post_sse("/agui/run", encode_run_input(input), fn(event) {
      dispatch(AgUiEventReceived(event))
    })
  })
}

/// AG-UI effect: send tool result back to agent
fn send_tool_result(tool_call_id: String, result: String) -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    http_post("/agui/tool-result", encode_tool_result(tool_call_id, result))
    dispatch(ToolResultSent(tool_call_id))
  })
}
```

**`effect.batch()`** for parallel AG-UI operations:
```gleam
fn init(args) -> #(Model, effect.Effect(Msg)) {
  #(
    initial_model(),
    effect.batch([
      subscribe_to_agent("cortex"),
      subscribe_to_agent("sentinel"),
      load_state_snapshot(),
      start_heartbeat_timer(),
    ])
  )
}
```

### 3.4 Lustre Component — Fractal Agentic Widget Pattern

Each fractal element becomes a Lustre `component()`:

```gleam
import lustre
import lustre/component
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/attribute
import lustre/event

/// Fractal Agentic Widget: Safety Kernel Panel (L0 Constitutional)
/// Each widget is a self-contained Lustre component with:
/// - Own Model/Msg/update/view cycle
/// - AG-UI event subscription via effects
/// - A2UI generative slot for agent-proposed content
/// - HITL approval capability

pub type Model {
  Model(
    psi_checks: List(PsiCheck),
    threat_level: ThreatLevel,
    pending_approval: Option(ApprovalRequest),
    agent_run_id: Option(String),
    reasoning_visible: Bool,
  )
}

pub type Msg {
  // AG-UI lifecycle
  AgentRunStarted(run_id: String)
  AgentStepUpdate(step: String, status: StepStatus)
  AgentRunFinished
  AgentRunError(message: String)
  // AG-UI state
  StateSnapshotReceived(snapshot: json.Json)
  StateDeltaReceived(patches: List(JsonPatch))
  // AG-UI reasoning
  ReasoningChunk(delta: String)
  ReasoningFinished
  // HITL
  ApprovalRequested(request: ApprovalRequest)
  UserApproved(request_id: String)
  UserRejected(request_id: String)
  UserEscalated(request_id: String)
  // A2UI generative
  GenerativeUIProposed(components: List(A2UIComponent))
  // Internal
  ToggleReasoning
  Tick
}

pub fn safety_kernel_component() -> lustre.App(Nil, Model, Msg) {
  lustre.component(
    init,
    update,
    view,
    [
      component.on_attribute_change("agent-id", DecodeAgentId),
      component.on_attribute_change("threat-level", DecodeThreatLevel),
    ],
  )
}
```

### 3.5 Wisp — AG-UI HTTP Endpoints

Wisp serves as the HTTP layer. It does NOT have WebSocket/SSE built-in, but:
- Lustre server components handle WebSocket transport independently
- Wisp handles REST API endpoints (tool results, run initiation, state queries)
- Mist (Wisp's underlying HTTP server) supports WebSocket via `mist.websocket()`

**Corrected Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│                    GLEAM BEAM RUNTIME                        │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ Wisp Router   │    │ Lustre Server │    │ Zenoh Client │  │
│  │ (REST API)    │    │ Components    │    │ (PubSub)     │  │
│  │ Port 4100     │    │ (WebSocket)   │    │ Port 7447    │  │
│  │               │    │ Port 4100/ws  │    │              │  │
│  │ POST /agui/run│    │ /ws/dashboard │    │ c3i/agui/**  │  │
│  │ POST /agui/   │    │ /ws/planning  │    │ c3i/a2a/**   │  │
│  │   tool-result │    │ /ws/safety    │    │              │  │
│  │ GET  /api/**  │    │ /ws/{page}    │    │              │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                    │           │
│         └───────────────────┼────────────────────┘           │
│                             │                                │
│                    ┌────────▼────────┐                       │
│                    │  AG-UI Event    │                       │
│                    │  Bus (OTP)      │                       │
│                    │  - Run manager  │                       │
│                    │  - State store  │                       │
│                    │  - Tool router  │                       │
│                    └────────┬────────┘                       │
│                             │                                │
│              ┌──────────────┼──────────────┐                │
│              ▼              ▼              ▼                 │
│         ┌────────┐    ┌────────┐    ┌────────┐             │
│         │ Agent  │    │ Agent  │    │ Agent  │             │
│         │Cortex  │    │Sentinel│    │Planning│             │
│         └────────┘    └────────┘    └────────┘             │
└─────────────────────────────────────────────────────────────┘
```

### 3.6 Lustre Server Component Per Page — The Fractal Dashboard

Each page in the dashboard is a **separate Lustre server component** supervised by OTP:

```gleam
import lustre
import gleam/otp/static_supervisor

/// C3I Agentic Dashboard Supervisor
/// Each page is a supervised Lustre server component
pub fn start_dashboard() {
  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.add(lustre.supervised(dashboard_app(), DashboardArgs))
  |> static_supervisor.add(lustre.supervised(planning_app(), PlanningArgs))
  |> static_supervisor.add(lustre.supervised(safety_app(), SafetyArgs))
  |> static_supervisor.add(lustre.supervised(immune_app(), ImmuneArgs))
  |> static_supervisor.add(lustre.supervised(zenoh_app(), ZenohArgs))
  |> static_supervisor.add(lustre.supervised(verification_app(), VerificationArgs))
  |> static_supervisor.add(lustre.supervised(telemetry_app(), TelemetryArgs))
  // ... all 12 Page variants as supervised server components
  |> static_supervisor.start_link()
}
```

For **dynamic agent instances**, use `lustre.factory()`:
```gleam
/// Factory for spawning per-agent-run UI instances
pub fn agent_run_factory() {
  lustre.factory(agent_run_viewer_app())
}

/// When a new agent run starts, spawn a dedicated viewer
fn handle_new_run(factory, run_id, agent_id) {
  factory_supervisor.start_child(factory, RunViewerArgs(run_id, agent_id))
}
```

### 3.7 Full Msg Type — AG-UI + A2UI + Lustre Aligned

```gleam
/// Complete Msg type for an agentic page, aligned with Lustre's update pattern
pub type Msg {
  // ── Navigation ─────────────────────────────────────────
  NavigateTo(page: Page)
  UrlChanged(url: String)

  // ── AG-UI Lifecycle ────────────────────────────────────
  AgUiRunStarted(thread_id: String, run_id: String)
  AgUiRunFinished(thread_id: String, run_id: String)
  AgUiRunError(message: String, code: String)
  AgUiStepStarted(step_name: String)
  AgUiStepFinished(step_name: String)

  // ── AG-UI Text Messages ────────────────────────────────
  AgUiTextStart(message_id: String, role: String)
  AgUiTextContent(message_id: String, delta: String)
  AgUiTextEnd(message_id: String)

  // ── AG-UI Tool Calls ───────────────────────────────────
  AgUiToolCallStart(tool_call_id: String, tool_name: String)
  AgUiToolCallArgs(tool_call_id: String, delta: String)
  AgUiToolCallEnd(tool_call_id: String)
  AgUiToolCallResult(tool_call_id: String, content: String)

  // ── AG-UI State ────────────────────────────────────────
  AgUiStateSnapshot(snapshot: json.Json)
  AgUiStateDelta(patches: List(JsonPatchOp))
  AgUiMessagesSnapshot(messages: List(ConversationMessage))

  // ── AG-UI Activity ─────────────────────────────────────
  AgUiActivitySnapshot(message_id: String, activity_type: String, content: json.Json)
  AgUiActivityDelta(message_id: String, patch: List(JsonPatchOp))

  // ── AG-UI Reasoning ────────────────────────────────────
  AgUiReasoningStart(message_id: String)
  AgUiReasoningContent(message_id: String, delta: String)
  AgUiReasoningEnd(message_id: String)

  // ── HITL (Human-in-the-Loop) ───────────────────────────
  HitlApprovalRequested(request: ApprovalRequest)
  HitlUserApproved(request_id: String)
  HitlUserRejected(request_id: String)
  HitlUserEdited(request_id: String, edited_value: String)
  HitlUserEscalated(request_id: String)

  // ── A2UI Generative UI ─────────────────────────────────
  A2uiComponentsProposed(components: List(A2UIComponent))
  A2uiComponentAccepted(component_id: String)
  A2uiComponentRejected(component_id: String)

  // ── Zenoh Telemetry ────────────────────────────────────
  ZenohTelemetryReceived(point: TelemetryPoint)
  ZenohHealthUpdated(status: HealthStatus)
  ZenohConnectionChanged(connected: Bool)

  // ── Dark Cockpit ───────────────────────────────────────
  CockpitModeChanged(mode: CockpitMode)
  ToggleDarkCockpit

  // ── Internal ───────────────────────────────────────────
  Tick
  NoOp
}
```

### 3.8 Effect Catalog — AG-UI Effects for Lustre

```gleam
/// AG-UI effects that map to Lustre's effect system
pub fn agui_effects() -> Dict(String, fn(json.Json) -> effect.Effect(Msg)) {
  dict.from_list([
    // Start an agent run — returns SSE stream of AG-UI events
    #("start_run", fn(input) {
      effect.from(fn(dispatch) {
        post_sse("/agui/run", input, fn(event) {
          dispatch(decode_agui_event(event))
        })
      })
    }),

    // Subscribe to Zenoh topic for real-time telemetry
    #("subscribe_zenoh", fn(config) {
      effect.from(fn(dispatch) {
        zenoh_subscribe(config, fn(msg) {
          dispatch(ZenohTelemetryReceived(decode_telemetry(msg)))
        })
      })
    }),

    // Send tool result back to agent
    #("send_tool_result", fn(result) {
      effect.from(fn(dispatch) {
        post_json("/agui/tool-result", result)
        dispatch(NoOp)
      })
    }),

    // HITL: send approval decision
    #("send_approval", fn(decision) {
      effect.from(fn(dispatch) {
        post_json("/agui/hitl/respond", decision)
        dispatch(NoOp)
      })
    }),

    // Request A2UI component generation from agent
    #("request_generative_ui", fn(context) {
      effect.from(fn(dispatch) {
        post_json("/agui/a2ui/propose", context, fn(response) {
          dispatch(A2uiComponentsProposed(decode_a2ui(response)))
        })
      })
    }),
  ])
}
```

### 3.9 Wisp Router — AG-UI Endpoints

```gleam
/// Wisp router with AG-UI endpoints
/// Wisp handles REST; Lustre server_component handles WebSocket
pub fn handle_request(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    // AG-UI Protocol Endpoints
    ["agui", "run"] -> handle_agui_run(req)           // POST: start agent run
    ["agui", "tool-result"] -> handle_tool_result(req) // POST: tool result
    ["agui", "hitl", "respond"] -> handle_hitl(req)    // POST: HITL decision
    ["agui", "a2ui", "propose"] -> handle_a2ui(req)    // POST: request generative UI
    ["agui", "health"] -> agui_health_response()       // GET: protocol health
    ["agui", "capabilities"] -> capabilities_response() // GET: capability discovery

    // Existing API endpoints (from current router.gleam)
    ["api", "health"] -> health_json_response()
    ["api", "v1", domain] -> domain_api_response(domain)
    ["api", domain, action] -> domain_action_response(domain, action)

    // Static assets (Lustre client runtime JS)
    ["static", ..rest] -> wisp.serve_static(req, under: "/static", from: "/priv/static")

    // SSR: Serve Lustre-rendered HTML with embedded server component client
    _ -> serve_lustre_ssr(req)
  }
}
```

### 3.10 Lustre UI Component Library Integration

`lustre_ui` (v1.0.0-rc.1) provides:
- **Accessible, themed components** with CSS variables
- **Semantic HTML** (no div soup)
- **Design tokens** for colors, spacing, typography

**Mapping to A2UI Catalog**:

| A2UI Component Type | Lustre UI Widget | Fractal Layer |
|---------------------|-----------------|---------------|
| `text_input` | lustre_ui/input | L2 Component |
| `select` | lustre_ui/select | L2 Component |
| `checkbox` | lustre_ui/checkbox | L2 Component |
| `badge` | lustre_ui/badge | L2 Component |
| `button` | lustre_ui/button | L2 Component |
| `card` | lustre_ui/card | L2 Component |
| `modal` | lustre_ui/modal | L0 (HITL approval) |
| `progress` | lustre_ui/progress | L4 System |
| `alert` | lustre_ui/alert | L0 Constitutional |
| `tab_group` | lustre_ui/tabs | L2 Component |
| `data_table` | Custom (lustre/html) | L3 Transaction |
| `sparkline` | Custom (SVG via lustre/element/svg) | L1 Debug |
| `topology_graph` | Custom (SVG) | L6 Ecosystem |
| `ooda_ring` | Custom (SVG) | L5 Cognitive |
| `gantt_chart` | Custom (SVG) | L3 Transaction |
| `reasoning_stream` | Custom (streaming text) | L5 Cognitive |
| `approval_dialog` | lustre_ui/modal + buttons | L0 Constitutional |
| `emergency_stop` | Custom (prominent button) | L0 Constitutional |

### 3.11 Full-Stack Architecture (Lustre + Wisp + AG-UI)

```
┌────────────────────────────────────────────────────────────────┐
│  BROWSER (Client)                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Lustre Client Runtime (minimal JS, ~8KB)                │   │
│  │  - Receives DOM patches via WebSocket                    │   │
│  │  - Sends UI events back to server                        │   │
│  │  - Renders A2UI components from catalog                  │   │
│  │  - Dark Cockpit CSS via lustre_ui theme variables        │   │
│  └─────────────────────────────────────────────────────────┘   │
│              ▲ WebSocket (DOM patches + events)                 │
└──────────────┼─────────────────────────────────────────────────┘
               │
┌──────────────┼─────────────────────────────────────────────────┐
│  BEAM SERVER │                                                  │
│              ▼                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Lustre Server Components (OTP supervised)               │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │Dashboard │ │Planning  │ │Safety    │ │Immune    │  │   │
│  │  │Component │ │Component │ │Component │ │Component │  │   │
│  │  │(L4-Sys)  │ │(L3-Txn)  │ │(L0-Const)│ │(L6-Eco)  │  │   │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │   │
│  │       └─────────────┼─────────────┼─────────────┘       │   │
│  │                     ▼                                    │   │
│  │            ┌─────────────────┐                           │   │
│  │            │  AG-UI Event    │                           │   │
│  │            │  Manager (OTP)  │                           │   │
│  │            │  - Run lifecycle│                           │   │
│  │            │  - State store  │                           │   │
│  │            │  - Tool router  │                           │   │
│  │            │  - HITL queue   │                           │   │
│  │            └────────┬────────┘                           │   │
│  └─────────────────────┼───────────────────────────────────┘   │
│                        │                                        │
│  ┌─────────────────────┼───────────────────────────────────┐   │
│  │  Wisp HTTP Router    │                                   │   │
│  │  - POST /agui/run    │ (start agent, return SSE)         │   │
│  │  - POST /agui/tool   │ (tool results)                    │   │
│  │  - POST /agui/hitl   │ (approval decisions)              │   │
│  │  - GET  /api/**      │ (domain REST APIs)                │   │
│  │  - GET  /static/**   │ (client runtime + CSS)            │   │
│  └─────────────────────┼───────────────────────────────────┘   │
│                        │                                        │
│  ┌─────────────────────▼───────────────────────────────────┐   │
│  │  Backend Agents (Cortex, Sentinel, Planning, ...)        │   │
│  │  - Emit AG-UI events                                     │   │
│  │  - Process via Zenoh PubSub                              │   │
│  │  - Request tool execution                                │   │
│  │  - Propose A2UI components                               │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

---

## 4. Root Cause Analysis

**Why Lustre/Wisp alignment is critical**:

1. **Lustre server components ARE the AG-UI transport** — No need to build custom WebSocket; Lustre handles DOM patching over WebSocket natively
2. **Lustre effects ARE the AG-UI effect system** — `effect.from()` maps directly to subscribing to agent event streams
3. **Lustre factories ARE the multi-agent UI** — `lustre.factory()` spawns per-agent-run viewers dynamically
4. **Lustre supervision IS the SIL-6 reliability** — `lustre.supervised()` provides OTP fault tolerance for each page
5. **Wisp handles REST, not WebSocket** — Previous design incorrectly assumed Wisp would serve SSE; Lustre server components handle real-time transport

---

## 5. Fix Taxonomy — Corrected Module Structure

### 5.1 Corrections to Previous Design

| Previous Design (20260403-1500) | Corrected Design | Reason |
|--------------------------------|-------------------|--------|
| Custom SSE via `agui/sse.gleam` batch string | Lustre server components via WebSocket | Lustre handles transport natively |
| `agui/transport.gleam` (planned) | Not needed — Lustre `TransportMethod` | WebSocket/SSE/Polling already in Lustre |
| Wisp serves SSE | Wisp serves REST only | Wisp has no SSE; Mist/Lustre handle WebSocket |
| Manual DOM patching | Lustre's virtual DOM diff + patch | Built into the framework |
| Custom state sync | Lustre Model as state + AG-UI deltas applied in update() | Native MVU pattern |
| Each page is a function | Each page is a `lustre.supervised()` OTP process | Fault tolerance per page |
| TUI is static render | TUI subscribes to same OTP events as Lustre server components | Shared event bus |

### 5.2 Corrected Module Map

```
FRACTAL AGENTIC UI SYSTEM (Lustre + Wisp Aligned)
│
├── agui/                          # AG-UI Protocol Core
│   ├── events.gleam               # UPGRADE: All 32 event types (add 15 missing)
│   ├── state.gleam                # NEW: RFC 6902 JSON Patch + state management
│   ├── tools.gleam                # NEW: Tool call lifecycle + result handling
│   ├── reasoning.gleam            # NEW: 6 reasoning event types
│   ├── activity.gleam             # NEW: Activity snapshot/delta events
│   ├── hitl.gleam                 # NEW: Human-in-the-loop approval queue
│   ├── run_manager.gleam          # NEW: OTP GenServer for run lifecycle
│   ├── middleware.gleam           # NEW: Event transformation pipeline
│   ├── capabilities.gleam         # NEW: Dynamic capability discovery
│   ├── multimodal.gleam           # NEW: Typed attachments (file/image/audio)
│   ├── zenoh_bus.gleam            # UPGRADE: Add subscribe + event replay
│   └── sse.gleam                  # KEEP: Fallback SSE for non-WebSocket clients
│
├── a2ui/                          # A2UI Declarative Component System
│   ├── schema.gleam               # NEW: A2UI JSON schema types
│   ├── catalog.gleam              # NEW: Trusted component registry
│   ├── renderer.gleam             # NEW: A2UI JSON → Lustre Element mapping
│   ├── bindings.gleam             # NEW: Data binding (state path → component prop)
│   └── validator.gleam            # NEW: Security validation (allowlist enforcement)
│
├── ui/                            # Triple-Interface (unchanged structure)
│   ├── domain.gleam               # UPGRADE: Add FractalElement, AgentBinding types
│   │
│   ├── lustre/                    # Web SSR — NOW Lustre server components
│   │   ├── app.gleam              # REWRITE: lustre.application() with full Msg
│   │   ├── supervisor.gleam       # NEW: OTP supervisor for all page components
│   │   ├── factory.gleam          # NEW: lustre.factory() for per-run viewers
│   │   ├── effects.gleam          # NEW: AG-UI effect catalog
│   │   ├── layout.gleam           # NEW: Dashboard grid shell (lustre_ui)
│   │   └── {22 domain views}      # UPGRADE: Each becomes lustre.component()
│   │
│   ├── wisp/                      # REST API — AG-UI endpoints added
│   │   ├── router.gleam           # UPGRADE: Add /agui/** endpoints
│   │   ├── agui_handler.gleam     # NEW: AG-UI run/tool/hitl handlers
│   │   └── {14 domain APIs}       # KEEP: Existing REST endpoints
│   │
│   └── tui/                       # Terminal — reactive + AG-UI subscription
│       ├── renderer.gleam         # UPGRADE: Subscribe to OTP events from AG-UI bus
│       ├── agent_panel.gleam      # NEW: Agent reasoning + tool calls in TUI
│       └── {22 domain views}      # UPGRADE: React to AG-UI state deltas
│
├── fractal/                       # Fractal Layer Widgets (NEW)
│   ├── l0_constitutional/         # Guardian, emergency stop, Psi checks
│   ├── l1_atomic_debug/           # Trace viewer, event monitor
│   ├── l2_component/              # Reusable widgets (lustre.component())
│   ├── l3_transaction/            # State diff, tool call, DB query
│   ├── l4_system/                 # Container health, run lifecycle
│   ├── l5_cognitive/              # OODA ring, reasoning, AI copilot
│   ├── l6_ecosystem/              # Agent mesh, Zenoh topology
│   └── l7_federation/             # Peer map, attestation, remote proxy
│
├── cockpit/                       # Cockpit Support
│   ├── domain.gleam               # KEEP
│   ├── visuals.gleam              # KEEP
│   └── dark_cockpit_theme.gleam   # NEW: lustre_ui CSS variables for Dark Cockpit
│
└── prajna/
    └── dark_cockpit.gleam         # UPGRADE: Emit AG-UI CUSTOM events on mode change
```

---

## 6. Patterns & Anti-Patterns Discovered

### 6.1 Pattern: Lustre Server Component as Fractal Holon

Each page component is an OTP-supervised Lustre server component that:
1. Maintains its own Model (fractal state)
2. Receives AG-UI events via OTP messages (not HTTP polling)
3. Pushes DOM patches to connected browser clients via WebSocket
4. Can be restarted independently by the supervisor (fault isolation)
5. Can spawn child components via `lustre.factory()` for sub-agents

This IS the fractal holon — self-contained, fault-tolerant, self-similar at every scale.

### 6.2 Pattern: Effect-as-Data for AG-UI

Lustre's effect system (`effect.from()`) is the CORRECT way to handle AG-UI:
- Effects describe what to do, not execute it directly
- The runtime manages effect execution
- Effects return messages via `dispatch()`
- `effect.batch()` enables parallel AG-UI subscriptions
- `effect.none()` for updates with no side effects

### 6.3 Pattern: A2UI via Lustre Component Catalog

The A2UI trusted component catalog maps to a `Dict(String, fn(json.Json) -> Element(Msg))`:
- Agent proposes JSON: `{"type": "badge", "props": {"severity": "critical"}}`
- Catalog looks up "badge" → returns Lustre renderer function
- Renderer produces `lustre/element/html` elements
- Untrusted component types are rejected (security boundary)

### 6.4 Anti-Pattern: Don't Bypass Lustre's DOM Patching

Previous design planned manual DOM manipulation. WRONG. Lustre's virtual DOM diff+patch
is the transport. AG-UI STATE_DELTA should be applied to the Lustre Model, which triggers
a view re-render, which Lustre automatically diffs and patches via WebSocket.

### 6.5 Anti-Pattern: Don't Use Wisp for Real-Time

Wisp is request-response only (no WebSocket/SSE built-in). Real-time updates MUST go
through Lustre server components (WebSocket) or Mist (raw WebSocket/SSE if needed).

---

## 7. Verification Matrix

| Check | Status | Evidence |
|-------|--------|----------|
| Lustre server_component researched | PASS | WebSocket/SSE/Polling transport, ClientMessage protocol |
| Lustre effect system researched | PASS | effect.from, effect.batch, effect.none, effect.map |
| Lustre application types researched | PASS | simple, application, component, start_server_component, supervised, factory |
| Lustre UI library researched | PASS | Themed components, CSS variables, accessible widgets |
| Wisp capabilities clarified | PASS | REST only, no WebSocket/SSE; JSON + routing + middleware |
| Full-stack pattern researched | PASS | Monorepo: client/server/shared, SSR + hydration |
| Architecture corrected | PASS | Lustre server components replace custom SSE transport |
| Effect mapping documented | PASS | AG-UI events → Lustre effects via effect.from() |
| Module structure corrected | PASS | Removed redundant transport.gleam; added supervisor.gleam, factory.gleam |
| Fractal layer completeness | PASS | L0-L7 all mapped to Lustre components |

---

## 8. Files Modified

| Action | File | Description |
|--------|------|-------------|
| CREATED | `docs/journal/20260403-1600-fractal-agentic-ui-lustre-wisp-alignment.md` | This addendum journal |
| SUPERSEDES | Previous journal's architecture diagram | Corrected: Lustre server components as transport |
| SUPERSEDES | Previous journal's Wisp SSE assumption | Corrected: Wisp = REST only |
| SUPERSEDES | Previous journal's custom transport plan | Corrected: Use Lustre TransportMethod |

---

## 9. Architectural Observations

### 9.1 Lustre Server Components ARE the "Golden Path"

The most significant finding is that Lustre server components already solve 80% of what
AG-UI needs for the Web interface:
- **Server-side state** → Lustre Model
- **Server-to-client push** → Lustre WebSocket DOM patches
- **Client-to-server events** → Lustre event handlers sent via WebSocket
- **OTP supervision** → `lustre.supervised()` and `lustre.factory()`
- **Effect management** → `lustre/effect`

The remaining 20% (AG-UI event protocol, A2UI catalog, HITL queue, reasoning visibility)
is what we build ON TOP of Lustre, not instead of it.

### 9.2 Three-Layer Transport Architecture

| Layer | Technology | Direction | Content |
|-------|-----------|-----------|---------|
| **DOM Transport** | Lustre WebSocket | Bidirectional | DOM patches ↓, UI events ↑ |
| **API Transport** | Wisp REST | Request-Response | Tool results, HITL decisions, queries |
| **Telemetry Transport** | Zenoh PubSub | Bidirectional | AG-UI events, A2A messages, metrics |

### 9.3 The Effect Functor

AG-UI events map through a functor to Lustre effects:

```
AG-UI Event Stream → decode → Lustre Msg → update(model, msg) → #(model, effect)
                                                                      ↓
                                                              Lustre runtime
                                                              executes effect
                                                                      ↓
                                                              effect dispatches
                                                              new Msg (loop)
```

This is a proper functional reactive loop — no imperative state mutation anywhere.

---

## 10. Remaining Gaps

| # | Gap | Priority | Mitigation |
|---|-----|----------|------------|
| 1 | Lustre client runtime JS delivery mechanism | P1 | `server_component.script()` inline or Wisp static serve |
| 2 | Mist WebSocket setup for Lustre server components | P1 | Research `mist.websocket()` integration |
| 3 | Zenoh NIF subscription in Gleam (currently put-only) | P1 | Erlang FFI for zenoh_subscribe |
| 4 | lustre_ui component availability (pre-release) | P2 | Use base lustre/element/html if lustre_ui incomplete |
| 5 | Browser E2E testing for Lustre server components | P2 | Adapt Wallaby or use Playwright |
| 6 | TUI keyboard input handling in Gleam | P2 | Erlang io module FFI |
| 7 | A2UI JSON Schema validation in Gleam | P2 | Build minimal validator or port from JS |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| Lustre API functions researched | 15+ (simple, application, component, start_server_component, supervised, factory, dispatch, send, shutdown, etc.) |
| Lustre transport methods | 3 (WebSocket, SSE, Polling) |
| Lustre effect functions | 7 (from, none, batch, before_paint, after_paint, map, provide) |
| Wisp capabilities confirmed | REST only (no WebSocket/SSE) |
| Architecture corrections | 5 (transport, state sync, DOM patching, supervision, Wisp role) |
| New modules planned (corrected) | ~25-30 (down from 40-55 — Lustre handles transport/DOM) |
| Existing modules to upgrade | 59 (unchanged) |
| Full-stack reference apps studied | 1 (gleam-lustre-wisp-fullstack-webapp) |

---

## 12. STAMP & Constitutional Alignment

| Constraint | Compliance | Notes |
|------------|-----------|-------|
| SC-GLM-UI-001 | DEEPENED | Triple-interface now uses Lustre server components (Web), Wisp (API), TUI |
| SC-GLM-UI-002 | CORRECTED | MVU via `lustre.application()` with effects, not `lustre.simple()` |
| SC-GLM-UI-006 | CLARIFIED | Wisp REST on port 4100; Lustre WebSocket on same port via Mist |
| SC-GLM-UI-007 | PRESERVED | Every Wisp endpoint still has Lustre component AND TUI view |
| SC-FUNC-005 | ENHANCED | Container auto-heal maps to `lustre.supervised()` per page |
| SC-SIL4-001 | MAPPED | Fail-safe via OTP supervision — crashed page restarts independently |
| SC-OODA-004 | MAPPED | OODA < 100ms tracked via Lustre effects + AG-UI STEP timing |

### Revised STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-AGUI-011 | Lustre server components MUST be the primary Web transport (not custom WebSocket) | CRITICAL |
| SC-AGUI-012 | Each page MUST be a `lustre.supervised()` OTP child | HIGH |
| SC-AGUI-013 | Dynamic agent UIs MUST use `lustre.factory()` for per-run instances | HIGH |
| SC-AGUI-014 | AG-UI event subscriptions MUST use `effect.from()` pattern | HIGH |
| SC-AGUI-015 | Wisp MUST handle REST only; real-time via Lustre server components | CRITICAL |
| SC-AGUI-016 | A2UI catalog MUST map to lustre_ui components where available | MEDIUM |
| SC-AGUI-017 | `effect.batch()` MUST be used for parallel agent subscriptions | MEDIUM |

---

## 13. Conclusion

This addendum corrects and deepens the Fractal Agentic UI design with precise Lustre/Wisp
ecosystem alignment. The key insight is that **Lustre server components already provide
the transport, state management, and supervision that AG-UI needs** — we build the agentic
protocol layer ON TOP of Lustre, not alongside it.

**Corrected Architecture Summary**:
- **Lustre server components** = AG-UI Web transport (WebSocket DOM patches)
- **Lustre effects** = AG-UI event subscription mechanism (`effect.from()`)
- **Lustre supervised** = SIL-6 fault tolerance per page
- **Lustre factory** = Dynamic per-agent-run UI instances
- **Wisp** = REST API only (tool results, HITL decisions, domain queries)
- **Zenoh** = Telemetry transport (agent events, A2A messages)
- **A2UI catalog** = Maps to lustre_ui + custom components per fractal layer
- **TUI** = Subscribes to same OTP event bus as Lustre server components

This is a fundamentally simpler and more correct architecture than the previous journal,
reducing planned new modules from ~40-55 to ~25-30 by leveraging what Lustre already provides.
