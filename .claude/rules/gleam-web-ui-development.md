---
paths: lib/cepaf_gleam/src/cepaf_gleam/ui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/agui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/a2ui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/testing/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/fractal/**/*.gleam, lib/indrajaal_gleam_web/src/**/*.gleam, lib/cepaf_gleam/test/**/*.gleam
---

# Gleam Fractal Agentic UI Development & Testing Protocol (v21.4.0-GLM)

## SUPREME MANDATE

**ALL C3I Web UI development MUST follow the Fractal Agentic UI approach: Penta-Stack
architecture, AG-UI 32-event protocol, A2UI declarative catalog, Lustre server
components as WebSocket transport, Triple-Interface mandate, Dark Cockpit 5-mode pattern,
8-category coverage gold standard, and Gleam type-safety guarantees. Every capability
MUST be simultaneously available across Lustre Web, Wisp REST, and TUI Terminal.**

This rule is the authoritative reference for all Gleam-based UI development, consolidating
findings from both the C3I and intelitor-v5.2 codebases.

---

## 1.0 Penta-Stack Architecture (SC-GLM-UI-001)

The C3I system exposes every UI capability through five simultaneous interface layers:

| Layer | Tech | Port | Path | Purpose |
|-------|------|------|------|---------|
| **Lustre Web SSR** | Lustre 5.6+ MVU | 4100 | `ui/lustre/*.gleam` | Server-side rendered HTML, no client JS |
| **Wisp REST API** | Wisp 1.0.0 HTTP | 4100 | `ui/wisp/*.gleam` | Typed JSON endpoints for all consumers |
| **TUI Terminal** | ANSI + Renderer | CLI | `ui/tui/*.gleam` | Dashboard with sparklines, progress bars |
| **Phoenix LiveView** | Elixir Phoenix | 4000 | `lib/indrajaal_web/live/` | Legacy backward compatibility |
| **F# CLI Fallback** | F# Console | CLI | `lib/cepaf/` | Safety kernel, dark cockpit fallback |

The first three layers (Lustre, Wisp, TUI) are the **Gleam Triple-Interface** and are the
primary development targets. Phoenix and F# remain maintained for backward compatibility.

### 1.1 Triple-Interface Mandate

**Every feature = 1 Lustre page + 1 Wisp endpoint + 1 TUI view.** (SC-GLM-UI-001)

Before marking any feature "done":
```
✓ Lustre page renders without client JS
✓ Wisp endpoint returns typed JSON (no string concatenation)
✓ TUI view displays ANSI-formatted terminal output
✓ All three share types exclusively from ui/domain.gleam
```

A feature implemented for only one interface is **67% incomplete**.

### 1.2 Shared Domain Types (SC-GLM-UI-009)

All types originate from `cepaf_gleam/ui/domain.gleam`. No per-interface duplication.

```gleam
// Canonical source: lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam

pub type Page {
  Dashboard | Planning | Immune | Knowledge | Zenoh | Cockpit
  | Verification | Substrate | Metabolic | Podman | Mcp | Kms | Telemetry
}

pub type HealthStatus {
  Healthy | Degraded(reason: String) | Critical(reason: String) | Unknown
}

pub type TelemetryPoint {
  TelemetryPoint(key: String, value: Float, timestamp: Int, unit: String)
}

pub type Action {
  Navigate(page: Page) | Refresh | Execute(command: String)
  | Subscribe(topic: String) | Unsubscribe(topic: String)
}

pub type RenderContext {
  RenderContext(
    page: Page,
    health: HealthStatus,
    telemetry: List(TelemetryPoint),
    zenoh_connected: Bool,
  )
}
```

---

## 2.0 STAMP Constraints (SC-GLM-UI)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-GLM-UI-001 | Triple-Interface: Lustre SSR + Wisp JSON + TUI ANSI for every capability | CRITICAL |
| SC-GLM-UI-002 | Lustre MVU pattern: Model/Msg/init/update/view — server-side on BEAM | HIGH |
| SC-GLM-UI-003 | Typed JSON via `gleam/json` — NO raw string concatenation | HIGH |
| SC-GLM-UI-004 | All UI modules MUST have C3I-SIL6-MSTS module contract header | MEDIUM |
| SC-GLM-UI-005 | Real-time telemetry via Zenoh PubSub subscription | HIGH |
| SC-GLM-UI-006 | Wisp HTTP binds to port 4100 — outside mesh range 4000-4010 | CRITICAL |
| SC-GLM-UI-007 | Every Wisp endpoint MUST have corresponding Lustre component AND TUI view | HIGH |
| SC-GLM-UI-008 | Dark Cockpit pattern: panels auto-hide when healthy (SC-HMI-010) | HIGH |
| SC-GLM-UI-009 | Shared types from `ui/domain.gleam` ONLY — no duplication | HIGH |
| SC-GLM-UI-010 | AG-UI SSE/WebSocket streaming for real-time dashboard updates | HIGH |

---

## 3.0 Lustre MVU Pattern

Every Lustre page component follows this canonical structure. Server-side only — no
client JavaScript emitted.

```gleam
//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/ui/lustre/{page}</module></identity>
////   <fractal-topology><layer>{L_LAYER}</layer></fractal-topology>
////   <compliance><stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002</stamp-controls></compliance>
//// </c3i-module>

import cepaf_gleam/ui/domain.{type Page, type RenderContext, type HealthStatus}
import lustre/element.{type Element}
import lustre/element/html
import lustre/attribute

/// Page-specific model (extends RenderContext with page state)
pub type Model {
  Model(context: RenderContext, loading: Bool, error: Option(String))
}

/// Page-specific messages
pub type Msg {
  Refresh
  HealthUpdated(status: HealthStatus)
  ZenohEvent(payload: String)
}

/// Initialize with RenderContext injected from server
pub fn init(ctx: RenderContext) -> Model {
  Model(context: ctx, loading: False, error: None)
}

/// Pure update — no side effects, deterministic
pub fn update(model: Model, msg: Msg) -> Model {
  case msg {
    Refresh -> Model(..model, loading: True)
    HealthUpdated(status) ->
      Model(..model, context: RenderContext(..model.context, health: status))
    ZenohEvent(_payload) -> model
  }
}

/// View: pure function from Model to Lustre Element tree
pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("page-container")], [
    html.h1([], [html.text("Page Title")]),
    // ... page content
  ])
}
```

### 3.1 Lustre View Modules (24 total)

| Module | Page | Fractal Layer |
|--------|------|---------------|
| `app.gleam` | Main dashboard entry | L5 Cognitive |
| `planning.gleam` | Task management | L3 Transaction |
| `immune.gleam` | Immune system status | L0 Constitutional |
| `knowledge.gleam` | Knowledge graph | L5 Cognitive |
| `zenoh_mesh.gleam` | Zenoh topology | L6 Ecosystem |
| `cockpit_view.gleam` | Cockpit overview | L5 Cognitive |
| `verification.gleam` | PROMETHEUS gates | L0 Constitutional |
| `substrate.gleam` | File system / SQLite | L3 Transaction |
| `metabolic.gleam` | Metabolic telemetry | L1 Atomic/Debug |
| `podman.gleam` | Container management | L4 System |
| `mcp.gleam` | MCP server status | L6 Ecosystem |
| `kms.gleam` | Key catalog | L0 Constitutional |
| `telemetry.gleam` | OTEL / metrics | L1 Atomic/Debug |
| + 11 planned pages | Fractal coverage L0-L7 | Various |

### 3.2 Lustre Effects as AG-UI Subscriptions (SC-AGUI-014)

```gleam
import lustre/effect.{type Effect}

/// Subscribe to an agent run — effect dispatches AG-UI messages into update
pub fn subscribe_to_agent(agent_id: String) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    register_zenoh_subscription(agent_id, fn(event) {
      dispatch(AgUiEventReceived(event))
    })
  })
}

/// Batch multiple subscriptions
pub fn init_subscriptions() -> Effect(Msg) {
  effect.batch([
    subscribe_to_agent("cortex"),
    subscribe_to_agent("sentinel"),
    subscribe_to_zenoh("indrajaal/health/**"),
  ])
}
```

---

## 4.0 Wisp REST API Pattern

### 4.1 Router Structure

```gleam
// lib/cepaf_gleam/src/cepaf_gleam/ui/wisp/router.gleam
// Port 4100 — outside mesh range 4000-4010 (SC-GLM-UI-006)

pub const default_port = 4100

pub fn route(path: String) -> String {
  case path {
    // Core pages
    "/health" | "/api/health"          -> health_json()
    "/api/v1/dashboard"                -> page_json(Dashboard)
    "/api/v1/planning"                 -> planning_json()
    "/api/v1/immune"                   -> immune_json()
    "/api/v1/knowledge"                -> knowledge_json()
    "/api/v1/zenoh"                    -> zenoh_json()
    "/api/v1/verification"             -> verification_json()
    // Domain endpoints
    "/api/v1/substrate"                -> substrate_json()
    "/api/v1/metabolic"                -> metabolic_json()
    "/api/v1/podman"                   -> podman_json()
    "/api/v1/mcp"                      -> mcp_json()
    "/api/v1/kms"                      -> kms_json()
    "/api/v1/telemetry"                -> telemetry_json()
    // AG-UI protocol routes
    "/ag-ui/run" | "/ag-ui/events"     -> agui_run_json(path)
    "/ag-ui/health"                    -> agui_sse.health_json()
    "/ag-ui/hitl/respond"              -> hitl_respond_json()
    _ -> not_found_json(path)
  }
}
```

### 4.2 Typed JSON Endpoint Pattern (SC-GLM-UI-003)

```gleam
import gleam/json
import wisp.{type Request, type Response}

/// Typed JSON endpoint — no raw string concatenation
pub fn handle_list(req: Request) -> Response {
  let data = fetch_domain_data()
  let body = json.to_string_tree(json.object([
    #("status", json.string("ok")),
    #("page", json.string("Planning")),
    #("data", json.array(data, encode_item)),
    #("timestamp", json.int(now_ms())),
  ]))
  wisp.json_response(body, 200)
}
```

### 4.3 Wisp API Modules (14 total)

| Module | Domain | Endpoints |
|--------|--------|-----------|
| `router.gleam` | All routes | Full dispatch table |
| `planning_api.gleam` | Tasks, OODA | `/api/v1/planning` |
| `immune_api.gleam` | Immune status | `/api/v1/immune` |
| `knowledge_api.gleam` | Graph, search | `/api/v1/knowledge` |
| `zenoh_api.gleam` | Mesh health | `/api/v1/zenoh` |
| `verification_api.gleam` | PROMETHEUS | `/api/v1/verification` |
| `cockpit_api.gleam` | Node status | `/api/cockpit/nodes` |
| `substrate_api.gleam` | DB / FS | `/api/v1/substrate` |
| `metabolic_api.gleam` | Metabolic | `/api/v1/metabolic` |
| `podman_api.gleam` | Containers | `/api/v1/podman` |
| `mcp_api.gleam` | MCP server | `/api/v1/mcp` |
| `kms_api.gleam` | Keys | `/api/v1/kms` |
| `telemetry_api.gleam` | OTEL | `/api/v1/telemetry` |
| `planning_routes.gleam` | Planning sub-router | `/api/planning/**` |

---

## 5.0 TUI Terminal Pattern

### 5.1 ANSI Rendering

```gleam
// lib/cepaf_gleam/src/cepaf_gleam/ui/tui/renderer.gleam
import cepaf_gleam/cockpit/visuals.{
  with_color, render_progress_bar, render_sparkline, render_table
}

pub fn render(context: RenderContext) -> String {
  let header = with_color("=== C3I COCKPIT ===", "cyan")
  let status = render_health_badge(context.health)
  let metrics = render_sparkline("CPU", context.telemetry)
  let zenoh = case context.zenoh_connected {
    True  -> with_color("[ZENOH CONNECTED]", "green")
    False -> with_color("[ZENOH DISCONNECTED]", "red")
  }
  header <> "\n" <> status <> "\n" <> metrics <> "\n" <> zenoh
}
```

### 5.2 Dark Cockpit 5-Mode State Machine

The `prajna/dark_cockpit.gleam` module implements the 5-mode state machine:

```gleam
pub type CockpitMode { Dark | Dim | NormalMode | Bright | EmergencyMode }

/// Mode derived automatically from unacknowledged alert severity
pub fn determine_mode(alerts: List(Alert)) -> CockpitMode {
  case critical_count, error_count, warning_count {
    c, _, _ if c > 0 -> EmergencyMode   // Any critical
    _, e, _ if e > 2 -> Bright          // Multiple errors
    _, e, _ if e > 0 -> NormalMode      // Any error
    _, _, w if w > 0 -> Dim             // Any warning
    _, _, _          -> Dark            // All healthy
  }
}
```

| Mode | Trigger | Display Behavior | Color Profile |
|------|---------|-----------------|---------------|
| Dark | No alerts | Minimal — gray defaults only | Monochrome |
| Dim | Warnings present | Subtle yellow indicators | Low-saturation |
| Normal | Errors present | Visible orange status | Standard |
| Bright | Multiple errors | High-visibility, large indicators | High-contrast |
| Emergency | Critical failures | Full illumination + ANSI flash | Red dominant |

### 5.3 Color Rich Profiles (SC-HMI-010)

Four selectable color profiles:
1. **Dark Cockpit** — Gray defaults, color ONLY on anomalies (default mode)
2. **Color Rich** — Vibrant colors for healthy states, linked to Zenoh metabolic telemetry
3. **Google Compliant** — WCAG 2.1 AA accessibility standard
4. **Functionally Clean** — Minimal, monochrome with semantic indicators only

Biomorphic feedback: Color saturation scales with Zenoh metabolic vitality score
(from `prajna/bio.gleam`). A healthy system glows; a degraded system fades to gray.

### 5.4 TUI View Modules (22 total)

| Module | Domain | ANSI Features |
|--------|--------|---------------|
| `renderer.gleam` | Core rendering engine | Colors, progress, sparklines, tables |
| `cockpit_view.gleam` | Cockpit overview | Multi-panel ANSI layout |
| `planning_view.gleam` | Task board | ASCII table, priority indicators |
| `immune_view.gleam` | Immune status | Pattern badges, threat level |
| `knowledge_view.gleam` | Graph summary | Node/edge counts, status |
| `zenoh_view.gleam` | Mesh topology | ASCII topology graph |
| `verification_view.gleam` | Gate results | Pass/fail matrix |
| `substrate_view.gleam` | DB / FS health | WAL status, file list |
| `metabolic_view.gleam` | Metabolic metrics | Sparkline time-series |
| `podman_view.gleam` | Container grid | Status grid with ports |
| `mcp_view.gleam` | MCP tools | Tool invocation history |
| `kms_view.gleam` | Key catalog | Key type / expiry list |
| `telemetry_view.gleam` | OTEL metrics | Trace count, latency bars |
| + 9 planned views | Fractal L0-L7 | Per-layer ANSI views |

---

## 6.0 AG-UI 32-Event Protocol (SC-AGUI)

### 6.1 All 32 Event Types

| Category | Count | Events |
|----------|-------|--------|
| **Lifecycle** | 5 | RunStarted, RunFinished, RunError, StepStarted, StepFinished |
| **Text** | 4 | TextMessageStart, TextMessageContent, TextMessageEnd, TextMessageChunk |
| **Tool** | 5 | ToolCallStart, ToolCallArgs, ToolCallEnd, ToolCallResult, ToolCallChunk |
| **State** | 3 | StateSnapshot, StateDelta (RFC 6902), MessagesSnapshot |
| **Activity** | 2 | ActivitySnapshot, ActivityDelta |
| **Reasoning** | 7 | ReasoningStart, ReasoningMessageStart, ReasoningMessageContent, ReasoningMessageEnd, ReasoningMessageChunk, ReasoningEnd, ReasoningEncryptedValue |
| **Special** | 4 | Raw, Custom, MetaEvent, Heartbeat |
| **TOTAL** | **32** | — |

```gleam
// lib/cepaf_gleam/src/cepaf_gleam/agui/events.gleam
pub type AgUiEvent {
  AgUiEvent(
    event_type: EventType,
    timestamp: Int,
    thread_id: String,
    run_id: String,
    payload: json.Json,
  )
}
```

### 6.2 Transport Layers

| Transport | Protocol | Direction | Use |
|-----------|----------|-----------|-----|
| **Lustre WebSocket** | DOM patches | Bidirectional | Real-time UI updates |
| **SSE fallback** | `text/event-stream` | Server→Client | Agent event streams |
| **Wisp REST** | HTTP JSON | Request/Response | Tool results, HITL decisions |
| **Zenoh PubSub** | Pub/Sub mesh | Bidirectional | A2A messaging, telemetry |

```
Agent Backend → AG-UI Events → Lustre Server Component → WebSocket → Browser
                             → SSE stream (fallback) → Browser
                             → Wisp /ag-ui/** → JSON response
                             → Zenoh indrajaal/agui/** → Mesh replication
```

### 6.3 AG-UI Module Map (`agui/`)

| Module | Lines | Purpose | STAMP |
|--------|-------|---------|-------|
| `events.gleam` | ~200 | 32 EventType ADT + constructors + serialization | SC-AGUI-001 |
| `state.gleam` | ~150 | RFC 6902 JSON Patch + SharedState management | SC-AGUI-003 |
| `tools.gleam` | ~200 | Tool call lifecycle + Args accumulation + HITL queue | SC-AGUI-004 |
| `sse.gleam` | ~150 | SSE connection + event dispatch (fallback transport) | SC-AGUI-002 |
| `zenoh_bus.gleam` | ~200 | Zenoh pub/sub + A2A messaging + event replay | SC-AGUI-001 |

### 6.4 HITL (Human-in-the-Loop) Pattern

HITL is MANDATORY for all L0 Constitutional operations (SC-AGUI-004).

```gleam
// 1. Agent requests approval (ToolCallStart)
AgUiEvent(
  event_type: ToolCallStart,
  payload: json.object([
    #("tool_call_id", json.string("approve-123")),
    #("tool_name", json.string("guardian_approve")),
    #("layer", json.string("L0_CONSTITUTIONAL")),
  ])
)

// 2. Lustre renders A2UI modal (user must approve)
// 3. User decides via Wisp endpoint
// POST /ag-ui/hitl/respond
// { "request_id": "approve-123", "decision": "approved" }

// 4. Agent receives ToolCallResult and continues
AgUiEvent(
  event_type: ToolCallResult,
  payload: json.object([
    #("tool_call_id", json.string("approve-123")),
    #("content", json.string("approved")),
    #("actor", json.string("human-operator")),
  ])
)
```

### 6.5 Wisp AG-UI Endpoints

| Path | Method | Purpose |
|------|--------|---------|
| `/ag-ui/run` | POST | Start an agent run, returns run_id |
| `/ag-ui/events` | GET (SSE) | Event stream for a run_id |
| `/ag-ui/health` | GET | AG-UI subsystem health |
| `/ag-ui/hitl/respond` | POST | Human HITL decision response |
| `/ag-ui/hitl/pending` | GET | List pending HITL requests |
| `/ag-ui/tools/result` | POST | Tool execution result callback |
| `/ag-ui/state` | GET | SharedState snapshot |

---

## 7.0 A2UI Declarative Component Catalog (SC-A2UI)

### 7.1 Principles

- Agents propose UI via **declarative JSON only** — NEVER executable code (SC-A2UI-001)
- Application owns the trusted catalog of pre-approved components (SC-A2UI-004)
- Flat ID-referenced list — LLM-friendly incremental generation
- Same JSON specification renders across Lustre (Web), Wisp (API), TUI (Terminal)
- All agent-proposed components must pass allowlist validation (SC-A2UI-002)

### 7.2 A2UI Module Map (`a2ui/`)

| Module | Purpose | STAMP |
|--------|---------|-------|
| `schema.gleam` | ComponentSpec, PropSpec, DataBinding types | SC-A2UI-001, SC-A2UI-005 |
| `catalog.gleam` | Trusted component registry + fractal layer access control | SC-A2UI-004 |
| `renderer.gleam` | A2UI JSON → Lustre Element / ANSI string mapping | SC-A2UI-003 |
| `bindings.gleam` | Data binding: state path → component prop | SC-A2UI-005 |
| `validator.gleam` | Security allowlist enforcement + layer access checks | SC-A2UI-002 |

### 7.3 Component Catalog (13+ types)

| A2UI Type | Layer | Lustre Renderer | TUI Renderer | Props |
|-----------|-------|----------------|-------------|-------|
| `badge` | L2 | `html.span.class("badge")` | `with_color(text)` | label, variant |
| `button` | L2 | `html.button.on_click` | `"[ACTION]"` | label, action, disabled |
| `data_table` | L3 | `html.table(rows)` | `render_table()` | headers, rows, sortable |
| `progress` | L4 | `html.div.progress-bar` | `render_progress_bar()` | value, max, label |
| `sparkline` | L1 | `svg.path` | `render_sparkline()` | data, width, height |
| `alert` | L0 | `html.div[role=alert]` | `with_color("ALERT")` | message, severity |
| `modal` | L0 | `html.dialog` | `"=== MODAL ==="` | title, body, actions |
| `ooda_ring` | L5 | Custom SVG | `O→O→D→A ASCII` | phase, latency |
| `reasoning` | L5 | `html.pre.streaming` | Streaming text | content, encrypted |
| `topology` | L6 | Custom SVG graph | ASCII graph | nodes, edges |
| `form_input` | L2 | `html.input` | `"[field]: "` | type, label, value |
| `select` | L2 | `html.select` | ASCII menu | options, selected |
| `slider` | L2 | `html.input[range]` | `"[===|===]"` | min, max, value |

### 7.4 A2UI JSON Example

```json
{
  "id": "health-badge-001",
  "component_type": "badge",
  "props": {
    "label": "Zenoh Connected",
    "variant": "healthy"
  },
  "binding": {
    "state_path": "$.zenoh.connected",
    "prop_name": "variant",
    "transform": "bool_to_health_variant"
  }
}
```

### 7.5 Fractal Layer Access Control

```gleam
// Only agents with L0 clearance can propose Constitutional components
pub fn can_access(agent_layer: FractalLayer, component_layer: FractalLayer) -> Bool {
  case agent_layer, component_layer {
    L0Constitutional, _ -> True          // L0 agents access all layers
    _, L0Constitutional -> False         // Non-L0 agents CANNOT propose L0 components
    L5Cognitive, L5Cognitive -> True
    L6Ecosystem, L6Ecosystem -> True
    // ... layer-specific rules
    _, _ -> agent_layer == component_layer
  }
}
```

---

## 8.0 Fractal Widget Architecture (L0-L7)

Each layer has dedicated widget modules under `fractal/`:

| Layer | Module | Primary Widgets | HITL Required |
|-------|--------|----------------|---------------|
| **L0 Constitutional** | `l0_constitutional.gleam` | Guardian approval, emergency stop, Psi invariant display, constitution hash | YES — mandatory |
| **L1 Atomic/Debug** | `l1_atomic_debug.gleam` | Debug trace viewer, NIF status, Zenoh session monitor, event log | No |
| **L2 Component** | `l2_component.gleam` | Forms, data grids, status badges, input controls, buttons | No |
| **L3 Transaction** | `l3_transaction.gleam` | State diff viewer, tool invocation panel, command history, DB status | No |
| **L4 System** | `l4_system.gleam` | Agent run monitor, step tracker, container health, port status | No |
| **L5 Cognitive** | `l5_cognitive.gleam` | Reasoning display, OODA ring, AI copilot panel, Cortex status | No |
| **L6 Ecosystem** | `l6_ecosystem.gleam` | Agent mesh topology, A2A messaging, quorum routers, collaboration | No |
| **L7 Federation** | `l7_federation.gleam` | Federation gateway, version vectors, attestation, peer discovery | Yes — federated |

### 8.1 L0 Constitutional Widgets

```gleam
// lib/cepaf_gleam/src/cepaf_gleam/fractal/l0_constitutional.gleam
// STAMP: SC-AGUI-004, SC-SAFETY-001, SC-GUARD-001

pub type ApprovalRequest {
  ApprovalRequest(
    request_id: String,
    operation: String,
    severity: ApprovalSeverity,
    requester_agent: String,
    timestamp: Int,
  )
}

pub type PsiCheck {
  PsiCheck(invariant: PsiInvariant, status: CheckStatus, evidence: String)
}

pub type PsiInvariant {
  Psi0Existence | Psi1Regeneration | Psi2History | Psi3Verification
  | Psi4HumanAlignment | Psi5Truthfulness | Omega0SymbioticSurvival
}
```

### 8.2 FractalElement Model

```gleam
pub type FractalElement {
  FractalElement(
    id: String,                           // FQUN — Fully Qualified Unit Name
    layer: FractalLayer,                  // L0-L7 placement
    element_type: ElementType,            // Widget, Panel, Dashboard, etc.
    agent_binding: Option(AgentBinding),  // Connected agent (if any)
    capabilities: List(Capability),       // What this element can do
  )
}

pub type Capability {
  EmitEvents | ReceiveEvents | ProposeUI | AcceptHITL
  | DelegateToSubAgent | PersistState | StreamContent
}
```

---

## 9.0 Testing Protocol — 8 Categories (C1-C8)

### 9.1 Mandatory Coverage Categories

| Cat | Name | Weight | Gate | What to Verify |
|-----|------|--------|------|---------------|
| C1 | Page Structure | 1.0 | Lustre element count >= 5 | `h1`, nav, sections, containers, footer |
| C2 | Status Badges | 1.5 | All 3 states visible | `Healthy` / `Degraded` / `Critical` rendered |
| C3 | Data Grids | 1.0 | >= 3 rows x >= 3 columns | Table structure, cell content |
| C4 | Timeline | 0.8 | Events in order | Timestamp ordering, history entries |
| C5 | Interactive | 1.2 | Click → state change | Buttons, forms, navigation transitions |
| C6 | Media/Rich | 0.8 | Assets load | SVG sparklines, progress bars, icons |
| C7 | AI Advisory | 1.5 | AG-UI events flow | SSE stream active, Zenoh publish verified |
| C8 | Action Button | 3.0 | Safety gates pass | Guardian approval + 2oo3 consensus |

**C8 carries the highest weight (3.0)** — safety-critical actions must verify Guardian
approval AND 2-out-of-3 consensus before state change.

### 9.2 Per-File Coverage Metadata

```gleam
// lib/cepaf_gleam/src/cepaf_gleam/testing/coverage_math.gleam

pub type FileCoverage {
  FileCoverage(
    file_name: String,
    page: String,
    priority: Priority,
    c1: Int,  // Page Structure features implemented
    c2: Int,  // Status Badge features
    c3: Int,  // Data Grid features
    c4: Int,  // Timeline features
    c5: Int,  // Interactive features
    c6: Int,  // Media/Rich features
    c7: Int,  // AI Advisory features
    c8: Int,  // Action Button features
    applicable_categories: List(String),
    expected_elements: Int,
    implemented_elements: Int,
  )
}
```

### 9.3 Source-First Mandate (AOR-COV-008)

ALWAYS read the Gleam source before writing test assertions:

1. Read `Model` type — defines data elements to verify in DOM
2. Read `Msg` type — defines interactions to exercise
3. Read `update()` — defines state transitions to test
4. Read `view()` — defines DOM structure expectations
5. Check Zenoh subscriptions — defines real-time data flows

---

## 10.0 Testing Math Gates (SC-MATH-COV)

ALL four gates MUST pass before a test module is considered complete:

| Gate | Threshold | Formula | STAMP |
|------|-----------|---------|-------|
| Shannon Entropy H | >= 2.5 bits | H = -sum(p_i * log2(p_i)) across C1-C8 | SC-MATH-COV-001 |
| CCM (Coverage Completeness) | >= 90% | CCM = sum(w_i * cov_i) / sum(w_i) | SC-MATH-COV-003 |
| ITQS (Integrated Test Quality) | >= 0.85 | ITQS = 0.4*H_norm + 0.4*CCM + 0.2*D | SC-MATH-COV-005 |
| Human Intent Alignment | >= 0.70 | Jaccard: |EXPECTED ∩ AS-IS| / |EXPECTED ∪ AS-IS| | SC-HINT-005 |

**Shannon Entropy**: Measures balance across 8 categories. H = 3.0 bits is maximum
(perfectly balanced). H < 2.5 means tests are over-concentrated in too few categories.

**CCM**: Weighted average using canonical weights. The weight vector is:
`[1.0, 1.5, 1.0, 0.8, 1.2, 0.8, 1.5, 3.0]` matching C1-C8.

**ITQS**: Composite score. Grade thresholds: A >= 0.90, B >= 0.80, C >= 0.70, D < 0.70.

**FSI (Feature Span Index)**: `implemented_elements / expected_elements` — measures
breadth of coverage across the declared feature surface.

### 10.1 Computing Gates in Gleam

```gleam
import cepaf_gleam/testing/coverage_math.{
  shannon_entropy, ccm, itqs, FileCoverage
}

let cov = FileCoverage(
  file_name: "planning_test.gleam",
  page: "Planning",
  priority: P1,
  c1: 3, c2: 2, c3: 4, c4: 1, c5: 3, c6: 2, c7: 2, c8: 1,
  applicable_categories: ["c1","c2","c3","c5","c7","c8"],
  expected_elements: 20,
  implemented_elements: 18,
)

let h = shannon_entropy(cov)          // >= 2.5 bits
let w = ccm(cov)                      // >= 0.90
let q = itqs(cov)                     // >= 0.85
```

---

## 11.0 Graph-Theory UI Testing (SC-UIGT)

### 11.1 Navigation Digraph

```
|V| = 13 pages (all Gleam Lustre views, per nav_graph.gleam)
|E| = 156 edges (nav bar creates near-complete bipartite subgraph: 13 * 12)
Density = 1.0 (complete graph — nav bar links all pages)
SCC = 1 (all pages in single strongly connected component)
PageRank used for test priority ordering
```

### 11.2 Per-Page LTS (Labeled Transition Systems)

For each Lustre page, derive an LTS from its types:

- **States**: from `Model` type fields and their value ranges
- **Labels**: from `Msg` type variants (events)
- **Transitions**: from `update()` pattern match branches
- Prime path coverage >= 0.95 required for Tier 1 pages (Dashboard, Planning, Immune)
- Prime path coverage >= 0.80 for Tier 2 pages

### 11.3 PubSub Channel Hypergraph

Each Zenoh topic subscription creates a hyperedge across the pages that subscribe to it.
The hypergraph is analyzed for:
- Isolation: no single topic failure should take down all pages
- Fanout: topics with > 5 subscribers get dedicated integration tests
- Latency paths: longest subscriber chains are identified for SLA verification

### 11.4 Chinese Postman Lower Bound

For mandatory navigation coverage, the Chinese Postman lower bound gives the minimum
number of E2E test steps needed. Because the nav graph is strongly connected, CPL = |E|.

### 11.5 Testing Modules (`testing/`)

| Module | Purpose | STAMP |
|--------|---------|-------|
| `nav_graph.gleam` | 13-page adjacency matrix, PageRank, SCC | SC-UIGT-001..014 |
| `coverage_math.gleam` | Shannon H, CCM, ITQS, FSI, D_EA | SC-MATH-COV-001..008 |
| `alignment.gleam` | Human Intent Jaccard alignment score | SC-HINT-001..008 |

---

## 12.0 Human Intent Protection (SC-HINT)

### 12.1 Inviolable Sections

Every page spec and UI module documentation MUST contain:

```markdown
## Human-Specified Intent
<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
<!-- Last modified by: [Human Name] on [YYYY-MM-DD] -->

### Functional Intent
[What this page MUST do from the operator's perspective]

### UX Requirements
[How the page MUST feel and behave]

### Safety Requirements
[Non-negotiable safety behaviors]

### Override Instructions
[Any instructions that override agent-generated behavior]
<!-- END HUMAN-ONLY -->
```

**Agents MUST NEVER modify, delete, or reformat this section.**

### 12.2 Alignment Score Formula

```
Alignment Score = |EXPECTED ∩ AS-IS| / |EXPECTED ∪ AS-IS|

EXPECTED = behaviors specified in Human-Specified Intent
AS-IS    = behaviors observed in Gleam source (Model, Msg, update, view)

Thresholds:
  >= 0.9 : ALIGNED      (green — no action required)
  0.7-0.9: DRIFT        (yellow — flag for human review)
  < 0.7  : MISALIGNED   (red — P1 alert, block agent modifications)
```

### 12.3 STAMP Constraints (SC-HINT)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-HINT-001 | Every page spec MUST contain `## Human-Specified Intent` section | CRITICAL |
| SC-HINT-002 | Agent MUST NEVER modify Human-Specified Intent section | CRITICAL |
| SC-HINT-004 | Human intent instructions OVERRIDE all agent-generated sections | CRITICAL |
| SC-HINT-005 | Agent MUST report alignment score between code and human intent | HIGH |
| SC-HINT-006 | Misalignment > 30% MUST trigger P1 alert | HIGH |
| SC-HINT-007 | Section MUST have `<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->` sentinel | CRITICAL |
| SC-HINT-008 | Agent MUST preserve human intent across ALL evolution cycles | CRITICAL |

---

## 13.0 Complete File Structure

```
lib/cepaf_gleam/src/cepaf_gleam/
  agui/                           # AG-UI Protocol (5 modules)
    events.gleam                  # 32 EventType ADT + constructors + serialization
    state.gleam                   # RFC 6902 JSON Patch + SharedState
    tools.gleam                   # Tool call lifecycle + HITL queue
    sse.gleam                     # SSE connection + event dispatch (fallback)
    zenoh_bus.gleam               # Zenoh pub/sub + A2A messaging + event replay

  a2ui/                           # A2UI Declarative Components (5 modules)
    schema.gleam                  # ComponentSpec, PropSpec, DataBinding types
    catalog.gleam                 # Trusted component registry + layer access
    renderer.gleam                # JSON → Lustre Element / ANSI string
    bindings.gleam                # State path → prop binding
    validator.gleam               # Security allowlist enforcement

  testing/                        # Test Framework (3 modules)
    nav_graph.gleam               # 13-page digraph + PageRank + SCC
    coverage_math.gleam           # Shannon H, CCM, ITQS, FSI, D_EA
    alignment.gleam               # Human Intent Jaccard alignment

  ui/                             # Triple-Interface
    domain.gleam                  # Shared types (CANONICAL — do not duplicate)
    lustre/                       # Web SSR (14 current + 10 planned)
      app.gleam                   # Main MVU entry point
      planning.gleam              # Planning / task board
      immune.gleam                # Immune system status
      knowledge.gleam             # Knowledge graph
      zenoh_mesh.gleam            # Zenoh topology
      cockpit_view.gleam          # Cockpit overview
      verification.gleam          # PROMETHEUS verification gates
      substrate.gleam             # File system / SQLite
      metabolic.gleam             # Metabolic telemetry
      podman.gleam                # Container management
      mcp.gleam                   # MCP server status
      kms.gleam                   # Key catalog
      telemetry.gleam             # OTEL metrics
    wisp/                         # REST API (14 modules)
      router.gleam                # HTTP router + /ag-ui/** endpoints
      planning_api.gleam          # Planning tasks JSON
      planning_routes.gleam       # Planning sub-router
      immune_api.gleam            # Immune status JSON
      knowledge_api.gleam         # Knowledge graph JSON
      zenoh_api.gleam             # Zenoh health JSON
      verification_api.gleam      # Verification status JSON
      cockpit_api.gleam           # Cockpit nodes JSON
      substrate_api.gleam         # Substrate status JSON
      metabolic_api.gleam         # Metabolic status JSON
      podman_api.gleam            # Container list JSON
      mcp_api.gleam               # MCP status JSON
      kms_api.gleam               # KMS catalog JSON
      telemetry_api.gleam         # Telemetry status JSON
    tui/                          # Terminal (13 current + 9 planned)
      renderer.gleam              # ANSI rendering engine (colors, bars, sparklines)
      cockpit_view.gleam          # Cockpit overview ANSI
      planning_view.gleam         # Planning board ANSI
      immune_view.gleam           # Immune status ANSI
      knowledge_view.gleam        # Knowledge graph ANSI
      zenoh_view.gleam            # Zenoh topology ANSI
      verification_view.gleam     # Verification gates ANSI
      substrate_view.gleam        # Substrate status ANSI
      metabolic_view.gleam        # Metabolic metrics ANSI
      podman_view.gleam           # Container grid ANSI
      mcp_view.gleam              # MCP tools ANSI
      kms_view.gleam              # Key catalog ANSI
      telemetry_view.gleam        # Telemetry metrics ANSI

  fractal/                        # Fractal Layer Widgets (8 modules, L0-L7)
    l0_constitutional.gleam       # Guardian, ApprovalRequest, PsiInvariant
    l1_atomic_debug.gleam         # Debug trace, event monitor, NIF status
    l2_component.gleam            # Forms, grids, badges, inputs
    l3_transaction.gleam          # State diff, tool panel, command history
    l4_system.gleam               # Run monitor, step tracker, container health
    l5_cognitive.gleam            # Reasoning display, OODA ring, AI copilot
    l6_ecosystem.gleam            # Mesh topology, A2A messages, quorum
    l7_federation.gleam           # Gateway, version vectors, attestation

  prajna/                         # Prajna Cognitive Modules
    dark_cockpit.gleam            # 5-mode cockpit state machine
    bio.gleam                     # Biomorphic feedback (metabolic vitality)
    neuro.gleam                   # Neural/cognitive substrate
    immune_system.gleam           # Immune system integration
    circuit_breaker.gleam         # Circuit breaker (drop queue > 100)
    smart_metrics.gleam           # Smart KPI computation
    orchestrator_cmd.gleam        # Orchestrator command handling

  cockpit/
    domain.gleam                  # Cockpit domain types
    visuals.gleam                 # with_color, render_progress_bar, render_sparkline

  verification/                   # PROMETHEUS + Graph Verification
    swarm.gleam                   # Swarm verification
    probes.gleam                  # Health probes

lib/indrajaal_gleam_web/src/
  indrajaal_gleam_web.gleam       # Web app entry point
  indrajaal_gleam_web/types.gleam # Web-specific types

lib/cepaf_gleam/test/             # Gleam unit tests
  cepaf_gleam/
    ui/lustre/*_test.gleam        # Lustre component tests
    ui/wisp/*_test.gleam          # Wisp endpoint tests
    ui/tui/*_test.gleam           # TUI view tests
    agui/*_test.gleam             # AG-UI event tests
    a2ui/*_test.gleam             # A2UI catalog tests
    testing/*_test.gleam          # Math framework tests
    fractal/*_test.gleam          # Fractal widget tests
```

---

## 14.0 Build and Test Commands

### 14.1 Gleam Build and Test

```bash
# Build Gleam subsystem
cd lib/cepaf_gleam && gleam build

# Run Gleam tests (gleeunit)
cd lib/cepaf_gleam && gleam test
```

### 14.2 Full Elixir Integration Compile (Canonical)

```bash
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --jobs 16
```

### 14.3 Full Test Suite

```bash
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
HEALTH_PORT=4051 \
MIX_ENV=test mix test
```

### 14.4 Wallaby E2E Tests (Gleam UI Coverage)

```bash
WALLABY_ENABLED=true \
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
HEALTH_PORT=4051 \
MIX_ENV=test mix test --only wallaby
```

**Note**: `HEALTH_PORT=4051` avoids mesh port range 4000-4010. Wisp API runs on 4100.

### 14.5 CPU Governor (High Load)

When CPU exceeds 80%, use the adaptive governor:

```bash
source scripts/cpu-governor.sh
governed_compile      # Adaptive parallelism
governed_test         # With HEALTH_PORT=4051
governed_wallaby      # Full E2E with governor
```

---

## 15.0 STAMP Constraints Summary

| Family | Range | Count | Domain |
|--------|-------|-------|--------|
| SC-GLM-UI | 001-010 | 10 | Triple interface, Lustre, Wisp, TUI, types |
| SC-AGUI | 001-017 | 17 | AG-UI 32-event protocol, transport, HITL |
| SC-A2UI | 001-005 | 5 | A2UI declarative catalog, JSON-only |
| SC-UIGT | 001-015 | 15 | UI graph theory (LTS, prime paths, PageRank) |
| SC-HINT | 001-008 | 8 | Human Intent protection, alignment >= 0.70 |
| SC-MATH-COV | 001-008 | 8 | Shannon H >= 2.5, CCM >= 90%, ITQS >= 0.85 |
| SC-HMI | 001-080 | 80 | HMI cockpit compliance, dark cockpit, accessibility |
| SC-VER | 001-079 | 79 | Fractal verification gates (L0-L7) |

---

## 16.0 Verification Checklist

Before any UI feature is marked complete, verify ALL of the following:

### Triple-Interface Completeness
- [ ] Lustre page renders without client JS (view function returns valid Element tree)
- [ ] Wisp endpoint returns typed JSON via `gleam/json` (no string concatenation)
- [ ] TUI view renders ANSI output for the same data
- [ ] All three use types from `ui/domain.gleam` — no duplication

### AG-UI Integration
- [ ] Page subscribes to AG-UI events via Lustre effects or Zenoh
- [ ] HITL flow implemented for any L0 Constitutional actions
- [ ] Relevant AG-UI event types emitted (minimum: RunStarted, StepStarted/Finished)
- [ ] SSE endpoint available at `/ag-ui/events` for the feature

### Test Coverage
- [ ] All 8 categories (C1-C8) addressed in test file
- [ ] Shannon Entropy H >= 2.5 bits
- [ ] CCM >= 0.90
- [ ] ITQS >= 0.85
- [ ] Human Intent alignment score >= 0.70
- [ ] Prime path coverage >= 0.95 for Tier 1 pages

### Dark Cockpit
- [ ] Healthy state hides panel (Dark mode) or shows minimal indicator
- [ ] Degraded state escalates to Dim or Normal mode
- [ ] Critical state triggers Emergency mode
- [ ] Mode determined by `determine_mode(alerts)` — never hardcoded

### Human Intent
- [ ] `## Human-Specified Intent` section present in module doc
- [ ] `<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->` sentinel present
- [ ] Section content not modified by any agent

---

## 17.0 Related Documents

- `docs/journal/20260403-1500-fractal-agentic-ui-system-design.md` — AG-UI design
- `docs/journal/20260403-1600-fractal-agentic-ui-lustre-wisp-alignment.md` — Lustre alignment
- `docs/journal/20260403-1700-gleam-testing-framework-graph-coverage-hitl.md` — Testing
- `docs/journal/20260403-1800-fractal-agentic-ui-comprehensive-implementation-plan.md` — Master plan
- `docs/PLANNING_WEBUI_DESIGN.md` — 8-panel dashboard design
- `.claude/rules/human-intent-protection.md` — SC-HINT full specification
- `.claude/rules/zenoh-telemetry-mandatory.md` — SC-ZENOH-001 requirements
- `.claude/rules/mandatory-compile-env.md` — SC-ENV-COMPILE canonical commands
- `.claude/rules/cpu-governor.md` — SC-CPU-GOV adaptive parallelism
- `.claude/agents/wallaby-coverage-engineer.md` — E2E test writing agent
- `.claude/agents/coverage-audit-agent.md` — Coverage math audit agent

---

## 18.0 Enforcement

This rule is:

- **MANDATORY**: All Gleam UI code must follow Fractal Agentic UI approach
- **TYPED**: No raw strings in JSON — use `gleam/json` always (SC-GLM-UI-003)
- **AGENTIC**: All UIs are agent-driven via AG-UI 32-event protocol (SC-AGUI-001)
- **DECLARATIVE**: Agent UI proposals via A2UI JSON only — no executable code (SC-A2UI-001)
- **TRIPLE-INTERFACE**: Every feature must exist in Lustre + Wisp + TUI simultaneously (SC-GLM-UI-001)
- **TESTED**: 8-category coverage with math gates (H >= 2.5, CCM >= 90%, ITQS >= 0.85)
- **PROTECTED**: Human-Specified Intent sections are inviolable (SC-HINT-001..008)
- **SUPERVISED**: HITL mandatory for all L0 Constitutional actions (SC-AGUI-004)
- **DARK-COCKPIT**: 5-mode state machine governs all display behavior (SC-HMI-010)
- **GRAPH-VERIFIED**: Navigation digraph + LTS prime paths verified per SC-UIGT
