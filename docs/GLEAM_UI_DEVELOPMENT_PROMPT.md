# Gleam UI Development Prompt — C3I Cockpit (v21.4.0-GLM)

This document is the definitive orientation prompt for any AI agent (Claude, Gemini, or
other) beginning a Gleam UI development or testing session in the C3I system. Read it
fully before writing or modifying any code.

---

## 1. System Context

**C3I is a Gleam-first cybernetic command-and-control cockpit for distributed mesh
orchestration running on the BEAM VM.**

| Dimension | Value |
|-----------|-------|
| Primary language | Gleam (type-safe, BEAM VM, hot reload) |
| UI framework | Lustre 5.6+ MVU — server-side rendered, NO client-side JavaScript |
| API framework | Wisp 2.2.2 (HTTP/JSON at port 4100) |
| Terminal UI | ANSI renderer (`cockpit/visuals.gleam`) |
| Telemetry bus | Zenoh pub/sub mesh (`zenoh/client.gleam`) |
| Agent protocol | AG-UI 32-event streaming protocol |
| UI component schema | A2UI declarative JSON catalog |
| Backend | Elixir/Phoenix on port 4000 (legacy, maintained for backwards compat) |
| Compute bridge | F# CEPAF (`lib/cepaf/`) |

**Gleam codebase root**: `lib/cepaf_gleam/src/cepaf_gleam/`

All UI source lives under `ui/`, with supporting subsystems in `agui/`, `a2ui/`,
`fractal/`, `testing/`, and `verification/`.

---

## 2. Triple-Interface Mandate (SC-GLM-UI-001)

Every UI capability MUST be implemented exactly three times, sharing types from
`ui/domain.gleam`. Implementing only one or two interfaces means the feature is
incomplete.

| Interface | Framework | Path | Port | Constraint |
|-----------|-----------|------|------|-----------|
| Lustre (Web SSR) | Lustre 5.6+ MVU | `ui/lustre/*.gleam` | 4100 | SC-GLM-UI-002 |
| Wisp (REST API) | Wisp HTTP/JSON | `ui/wisp/*.gleam` | 4100 | SC-GLM-UI-003 |
| TUI (Terminal) | ANSI renderer | `ui/tui/*.gleam` | CLI | SC-GLM-UI-004 |

**Done checklist for any new feature:**
```
[ ] Lustre page renders without client JS
[ ] Wisp endpoint returns typed JSON (no string concatenation)
[ ] TUI view displays ANSI terminal output
[ ] All three import types from ui/domain.gleam only
[ ] No per-interface type duplication
```

---

## 3. Source File Map

### Canonical Types (start here for every task)
```
ui/domain.gleam              Shared Page, HealthStatus, TelemetryPoint, Action, RenderContext
```

### Lustre Web UI — 24 modules
```
ui/lustre/app.gleam          Main MVU application + AG-UI Msg variants
ui/lustre/effects.gleam      AG-UI effect catalog (subscribe_to_agent, emit_event)
ui/lustre/planning.gleam     Planning page component
ui/lustre/planning_view.gleam
ui/lustre/planning_dashboard.gleam
ui/lustre/cockpit_view.gleam
ui/lustre/verification.gleam
ui/lustre/immune.gleam
ui/lustre/knowledge.gleam
ui/lustre/zenoh_mesh.gleam
ui/lustre/substrate.gleam
ui/lustre/metabolic.gleam
ui/lustre/podman.gleam
ui/lustre/mcp.gleam
ui/lustre/kms.gleam
ui/lustre/telemetry.gleam
ui/lustre/prajna.gleam
ui/lustre/agents.gleam
ui/lustre/holon.gleam
ui/lustre/git.gleam
ui/lustre/database.gleam
ui/lustre/smriti.gleam
ui/lustre/config.gleam
ui/lustre/bridge.gleam
```

### Wisp REST API — 16 modules
```
ui/wisp/router.gleam         HTTP router — port 4100, all /api/** routes
ui/wisp/planning_api.gleam
ui/wisp/planning_routes.gleam
ui/wisp/cockpit_api.gleam
ui/wisp/verification_api.gleam
ui/wisp/immune_api.gleam
ui/wisp/knowledge_api.gleam
ui/wisp/zenoh_api.gleam
ui/wisp/substrate_api.gleam
ui/wisp/metabolic_api.gleam
ui/wisp/podman_api.gleam
ui/wisp/mcp_api.gleam
ui/wisp/kms_api.gleam
ui/wisp/telemetry_api.gleam
```

### TUI Terminal — 22 modules
```
ui/tui/renderer.gleam        ANSI rendering engine (top-level)
ui/tui/cockpit_view.gleam
ui/tui/planning_view.gleam
ui/tui/planning_dashboard_view.gleam
ui/tui/verification_view.gleam
ui/tui/immune_view.gleam
ui/tui/knowledge_view.gleam
ui/tui/zenoh_view.gleam
ui/tui/substrate_view.gleam
ui/tui/metabolic_view.gleam
ui/tui/podman_view.gleam
ui/tui/mcp_view.gleam
ui/tui/kms_view.gleam
ui/tui/telemetry_view.gleam
ui/tui/prajna_view.gleam
ui/tui/agents_view.gleam
ui/tui/holon_view.gleam
ui/tui/git_view.gleam
ui/tui/database_view.gleam
ui/tui/bridge_view.gleam
ui/tui/smriti_view.gleam
ui/tui/config_view.gleam
```

### AG-UI Protocol — 5 modules
```
agui/events.gleam    32 EventType ADT + SSE serialization
agui/state.gleam     RFC 6902 JSON Patch + SharedState management
agui/tools.gleam     Tool call lifecycle + HITL approval queue
agui/sse.gleam       SSE connection + event dispatch
agui/zenoh_bus.gleam Zenoh publish/subscribe + A2A messaging
```

### A2UI Component Catalog — 5 modules
```
a2ui/schema.gleam    ComponentSpec, PropSpec, BindingSpec types
a2ui/catalog.gleam   Trusted component registry (security boundary)
a2ui/renderer.gleam  A2UI JSON -> Lustre Element rendering
a2ui/bindings.gleam  State path -> component prop binding
a2ui/validator.gleam Security allowlist enforcement
```

### Fractal Layer Widgets — 8 modules (L0-L7)
```
fractal/l0_constitutional.gleam   Guardian, emergency stop, Psi invariants
fractal/l1_atomic_debug.gleam     Debug telemetry, NIF loaded, Zenoh session
fractal/l2_component.gleam        GenServer health, supervisor trees, ETS tables
fractal/l3_transaction.gleam      DB pool, SQLite WAL, DuckDB, Oban queues
fractal/l4_system.gleam           Container health, port bindings, volumes
fractal/l5_cognitive.gleam        Cortex, OODA cycle, AI models, knowledge base
fractal/l6_ecosystem.gleam        Mesh topology, quorum routers, 2oo3 voting
fractal/l7_federation.gleam       Peer discovery, version vectors, attestation
```

### Testing Framework — 3 modules
```
testing/coverage_math.gleam  Shannon H, CCM, FMEA RPN, FSI, D_EA, ITQS formulas
testing/nav_graph.gleam      22-page digraph, PageRank, SCC analysis
testing/alignment.gleam      Human Intent alignment score computation
```

### Verification — 4 modules
```
verification/prometheus.gleam        PROMETHEUS DAG path safety proofs
verification/graph_verification.gleam SCC, cycle detection, reachability
verification/probes.gleam            Runtime health probes
verification/swarm.gleam             16-container swarm health verification
```

---

## 4. Key Patterns

### 4.1 Lustre MVU (Web SSR)

Every Lustre page component follows this exact structure. There is no `mount` (that is
the Elixir LiveView pattern). Gleam Lustre uses `init`, `update`, `view`.

```gleam
/// Lustre component for {Domain} plane (SC-GLM-UI-001).
/// Imports shared types from ui/domain — no duplication (SC-GLM-UI-009).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-009

import cepaf_gleam/ui/domain.{type HealthStatus, type RenderContext}
import lustre/element.{type Element}
import lustre/element/html
import lustre/attribute

/// Page-local model (fields, not duplicate types)
pub type Model {
  Model(
    context: RenderContext,
    items: List(Item),
    selected: option.Option(String),
  )
}

/// Page messages — exhaustive ADT (Gleam enforces coverage at compile time)
pub type Msg {
  SelectItem(id: String)
  Refresh
  ItemsLoaded(List(Item))
}

pub fn init(ctx: RenderContext) -> Model {
  Model(context: ctx, items: [], selected: option.None)
}

/// Pure update — NO side effects here
pub fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SelectItem(id) -> Model(..model, selected: option.Some(id))
    Refresh -> model
    ItemsLoaded(items) -> Model(..model, items: items)
  }
}

/// View — returns Lustre Element tree
pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("page")], [
    html.h1([], [element.text("Domain")]),
    render_status(model.context.health),
    render_items(model.items),
  ])
}
```

**Key insight**: Gleam's exhaustive pattern matching on `Msg` ADTs gives compile-time
coverage guarantees. Every `case msg` must handle every variant or the compiler refuses
to build.

### 4.2 Wisp REST Endpoint

```gleam
/// Wisp API for {Domain} plane (SC-GLM-UI-001, SC-GLM-UI-003).
/// Typed JSON only — NO raw string concatenation (SC-GLM-UI-003).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007

import gleam/json
import wisp.{type Request, type Response}

/// List endpoint — returns JSON array
pub fn handle_list(req: Request) -> Response {
  let items = fetch_items()  // from domain service
  let body =
    json.object([
      #("status", json.string("ok")),
      #("count", json.int(list.length(items))),
      #("items", json.array(items, encode_item)),
    ])
    |> json.to_string_tree
  wisp.json_response(body, 200)
}

fn encode_item(item: Item) -> json.Json {
  json.object([
    #("id", json.string(item.id)),
    #("name", json.string(item.name)),
  ])
}
```

**Never** use `"{ \"key\": \"" <> value <> "\" }"`. Always use `gleam/json`.

### 4.3 TUI ANSI Renderer

```gleam
/// TUI view for {Domain} (SC-GLM-UI-001).
/// Renders to ANSI string via cockpit/visuals.gleam primitives.
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-004

import cepaf_gleam/cockpit/visuals
import cepaf_gleam/ui/domain.{type RenderContext}

pub fn render(ctx: RenderContext) -> String {
  let header = visuals.with_color("=== DOMAIN ===", "cyan")
  let status = render_health(ctx.health)
  let body = render_items()
  string.join([header, status, body], "\n")
}

fn render_health(health) -> String {
  case health {
    Healthy -> visuals.with_color("HEALTHY", "green")
    Degraded(reason) -> visuals.with_color("DEGRADED: " <> reason, "yellow")
    Critical(reason) -> visuals.with_color("CRITICAL: " <> reason, "red")
    Unknown -> visuals.with_color("UNKNOWN", "gray")
  }
}
```

### 4.4 AG-UI Event Flow

Agents communicate with the UI through the AG-UI event stream. Lustre server components
ARE the transport — they push DOM patches via WebSocket.

```gleam
// Agent emits AG-UI events (in agui/events.gleam)
let event = AgUiEvent(
  event_type: TextMessageContent,
  timestamp: now_ms(),
  thread_id: thread_id,
  run_id: run_id,
  payload: json.object([#("content", json.string("thinking..."))]),
)

// Lustre subscribes to agent events as an effect (in ui/lustre/effects.gleam)
pub fn subscribe_to_agent(agent_id: String) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    register_agent_subscription(agent_id, fn(event) {
      dispatch(AgUiEventReceived(event))
    })
  })
}

// Multiple agent subscriptions run in parallel
effect.batch([
  subscribe_to_agent("cortex"),
  subscribe_to_agent("sentinel"),
  subscribe_to_agent("guardian"),
])
```

### 4.5 A2UI Agent-Proposed UI

Agents propose UI elements via JSON spec. The renderer converts specs to Lustre elements.
Agents NEVER send executable code — only declarative component requests.

```gleam
// Agent proposes a badge component via JSON
// { "type": "badge", "props": { "label": "SIL-6", "variant": "success" } }

// Validator checks against trusted catalog (security boundary)
case catalog.lookup(catalog, spec.component_type) {
  Ok(registered) -> renderer.render(spec, state)
  Error(Nil) -> Error("Component not in trusted catalog")
}

// Renderer maps to Lustre element
pub fn render_badge(props: dict.Dict(String, json.Json)) -> Element(msg) {
  let label = get_string_prop(props, "label", "")
  let variant = get_string_prop(props, "variant", "default")
  html.span([attribute.class("badge badge-" <> variant)], [element.text(label)])
}
```

### 4.6 Fractal Layer Composition

Fractal widgets compose hierarchically. Higher layers embed lower layer widgets.

```gleam
// L5 Cognitive widget includes L1 debug info
pub fn render_ooda_widget(state: OodaState) -> Element(msg) {
  html.div([attribute.class("fractal-l5")], [
    l1_atomic_debug.render_zenoh_status(state.zenoh),   // L1 embedded in L5
    render_ooda_cycle(state.cycle),
    render_ai_models(state.models),
  ])
}

// L0 Constitutional widget gates all actions
pub fn render_guardian_gate(request: ApprovalRequest) -> Element(msg) {
  html.div([attribute.class("fractal-l0 hitl-gate")], [
    html.h3([], [element.text("Guardian Approval Required")]),
    html.p([], [element.text(request.description)]),
    html.button([on_click(Approve(request.request_id))], [element.text("Approve")]),
    html.button([on_click(Reject(request.request_id))], [element.text("Reject")]),
  ])
}
```

---

## 5. AG-UI 32-Event Protocol

All 32 event types are defined in `agui/events.gleam`. Every event type MUST be handled
by the AG-UI infrastructure (SC-AGUI-001).

| Category | Count | Events |
|----------|-------|--------|
| Lifecycle | 5 | RunStarted, RunFinished, RunError, StepStarted, StepFinished |
| Text | 4 | TextMessageStart, TextMessageContent, TextMessageEnd, TextMessageChunk |
| Tool | 5 | ToolCallStart, ToolCallArgs, ToolCallEnd, ToolCallResult, ToolCallChunk |
| State | 3 | StateSnapshot, StateDelta (RFC 6902 JSON Patch), MessagesSnapshot |
| Activity | 2 | ActivitySnapshot, ActivityDelta |
| Reasoning | 7 | ReasoningStart, ReasoningMessageStart, ReasoningMessageContent, ReasoningMessageEnd, ReasoningMessageChunk, ReasoningEnd, ReasoningEncryptedValue |
| Special | 6 | Raw, Custom, MetaEvent, TextMessageChunk (streaming), ToolCallChunk (streaming), ReasoningMessageChunk |

**When each fires:**
- `RunStarted` / `RunFinished` / `RunError` — outer execution lifecycle
- `StepStarted` / `StepFinished` — OODA cycle steps, tool execution steps
- `TextMessage*` — streaming agent text responses to the cockpit
- `ToolCall*` — tool invocation (with HITL gate at L0 for critical tools)
- `StateSnapshot` / `StateDelta` — shared state sync (RFC 6902 patch format)
- `Reasoning*` — visible chain-of-thought for transparency
- `ActivitySnapshot` / `ActivityDelta` — agent activity tracking
- `Custom` / `Raw` / `MetaEvent` — extension points for specialized events

**Transport layers:**
- Lustre WebSocket: DOM patches down + user events up (primary, real-time)
- Wisp REST `/agui/**`: Tool results, HITL decisions, queries (request/response)
- Zenoh `indrajaal/agui/**`: Mesh replication, A2A messages (telemetry)

---

## 6. A2UI Component Catalog

All components are in `a2ui/catalog.gleam`. Agents may only request components from this
trusted registry — the catalog is the security boundary (SC-A2UI-002).

| A2UI Type | Layer | Required Props | Description |
|-----------|-------|---------------|-------------|
| `alert` | L0 | `severity`, `message` | Safety alert with dismiss |
| `modal` | L0 | `title`, `content` | HITL approval dialog |
| `emergency_stop` | L0 | `label` | Emergency stop button |
| `sparkline` | L1 | `data`, `label` | Real-time telemetry sparkline |
| `debug_trace` | L1 | `trace_id`, `events` | Debug trace display |
| `badge` | L2 | `label`, `variant` | Status badge |
| `button` | L2 | `label`, `action` | Action button |
| `progress` | L2 | `value`, `max`, `label` | Progress bar |
| `data_table` | L3 | `columns`, `rows` | Data grid |
| `diff_view` | L3 | `before`, `after` | State diff viewer |
| `container_card` | L4 | `name`, `status`, `uptime` | Container status card |
| `run_monitor` | L4 | `run_id`, `steps` | Agent run tracker |
| `ooda_ring` | L5 | `phase`, `latency_ms` | OODA cycle visualization |
| `reasoning` | L5 | `content`, `streaming` | Agent reasoning display |
| `topology` | L6 | `nodes`, `edges` | Mesh topology graph |
| `agent_card` | L6 | `agent_id`, `capabilities` | Agent mesh card |
| `version_vector` | L7 | `node_id`, `vector` | Federation version vector |

**Access control**: L0 components require Guardian approval before render. L5+ components
require the requesting agent to have `ProposeUI` capability declared.

---

## 7. Testing Requirements

### 7.1 Eight-Category Gold Standard (C1-C8)

Every Lustre page component MUST have test coverage across all 8 categories.

| Cat | Name | Weight | What to Test in Gleam |
|-----|------|--------|-----------------------|
| C1 | Page Structure | 1.0 | Model has required fields, view returns Element, init does not panic |
| C2 | Status Badges | 1.5 | All HealthStatus variants render correctly (Healthy/Degraded/Critical/Unknown) |
| C3 | Data Grids | 1.0 | List rendering with 0, 1, N items; empty state shown |
| C4 | Timeline | 0.8 | Temporal data sorted correctly, refresh state transition |
| C5 | Interactive | 1.2 | Each Msg variant produces expected Model change in update() |
| C6 | Media / Rich | 0.8 | Sparklines, SVG elements, ANSI color strings present |
| C7 | AI Advisory | 1.5 | AG-UI event dispatch changes model state, SSE payload serializes |
| C8 | Action Buttons | 3.0 | Safety gates (L0 Guardian approval required for destructive actions) |

### 7.2 Mathematical Quality Gates

All three gates must pass before a test file is considered complete:

| Gate | Formula | Threshold |
|------|---------|-----------|
| Shannon Entropy H | H = -Σ pᵢ log₂(pᵢ) across test categories | H >= 2.5 bits |
| Coverage Completeness CCM | weighted(covered) / weighted(total) | CCM >= 0.90 |
| Integrated Test Quality ITQS | w_c·C + w_t·T + w_q·Q + w_s·S | ITQS >= 0.85 |

Computed by `testing/coverage_math.gleam`. All formulas are pure functions.

### 7.3 Graph-Theory UI Testing

The 22 Gleam pages form a navigation digraph:
- |V| = 22 (one vertex per Lustre page)
- |E| ~ 400 (nav bar creates near-complete subgraph)
- SCC = 1 (all pages must be mutually reachable)
- PageRank determines test priority order (higher rank = test first)

Per-page Labeled Transition Systems (LTS):
- States derived from `Model` type fields
- Labels derived from `Msg` type variants
- Transitions derived from `update()` pattern match clauses
- Prime path coverage >= 0.95 for Tier-1 pages (Dashboard, Planning, Cockpit)

### 7.4 Human Intent Alignment

Every Gleam UI module must achieve an alignment score >= 0.70 between documented intent
and actual implementation. The score is:

```
Alignment = |EXPECTED ∩ AS-IS| / |EXPECTED ∪ AS-IS|
```

Where EXPECTED is parsed from the `/// Human-Specified Intent` doc comment section and
AS-IS is derived from Model fields, Msg variants, and view output.

Score < 0.70 blocks all agent modifications to that module.

### 7.5 Writing Gleam Tests

```gleam
// lib/cepaf_gleam/test/cepaf_gleam/ui/lustre/planning_test.gleam
import cepaf_gleam/ui/lustre/planning.{
  AllTasks, PendingOnly, PlanningModel, PlanningTask, SetFilter, TasksLoaded,
  init, update,
}
import gleeunit/should

pub fn init_creates_empty_model_test() {
  let model = init()
  model.tasks |> should.equal([])
  model.selected_id |> should.equal(option.None)
}

pub fn set_filter_updates_model_test() {
  let model = init() |> update(SetFilter(PendingOnly))
  model.filter |> should.equal(PendingOnly)
}

pub fn tasks_loaded_populates_list_test() {
  let task = PlanningTask("t1", "Fix bug", "pending", "P1", option.None)
  let model = init() |> update(TasksLoaded([task]))
  model.tasks |> should.equal([task])
}
```

### 7.6 Wisp API Tests

```gleam
import wisp/testing

pub fn list_endpoint_returns_200_test() {
  let req = testing.get("/api/planning/tasks", [])
  let resp = planning_api.handle_list(req)
  resp.status |> should.equal(200)
}
```

---

## 8. Build and Test Commands

### Gleam only

```bash
# Build — zero warnings required (SC-GLM-CMP-001)
cd /home/an/dev/ver/c3i/lib/cepaf_gleam && gleam build

# Test — all tests must pass
cd /home/an/dev/ver/c3i/lib/cepaf_gleam && gleam test

# Format check
cd /home/an/dev/ver/c3i/lib/cepaf_gleam && gleam format --check
```

### Full system compile (Elixir + Gleam integration)

```bash
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile --jobs 16
```

All flags are mandatory — see `.claude/rules/mandatory-compile-env.md` for rationale.

### Full system test

```bash
SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
MIX_ENV=test mix test
```

### Wallaby E2E (browser integration)

```bash
WALLABY_ENABLED=true \
SKIP_ZENOH_NIF=0 \
NO_TIMEOUT=true \
PATIENT_MODE=enabled \
HEALTH_PORT=4051 \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_ENV=test mix test --only wallaby
```

---

## 9. Constraint Families

| Family | Count | Governs |
|--------|-------|---------|
| SC-GLM-UI | 10 | Triple interface mandate, Lustre/Wisp/TUI patterns, shared types |
| SC-AGUI | 17 | AG-UI 32-event protocol, Lustre server components, HITL |
| SC-A2UI | 5 | A2UI declarative catalog, JSON-only proposals, allowlist |
| SC-UIGT | 15 | UI graph testing (22-page digraph, LTS, prime paths, PageRank) |
| SC-HINT | 8 | Human Intent protection, alignment score >= 0.70 |
| SC-MATH-COV | 8 | Shannon H, CCM, ITQS, FSI, D_EA quality gates |
| SC-HMI | 80 | Human-Machine Interface (dark cockpit, color profiles, accessibility) |
| SC-VER | 79 | Fractal verification gates (L0-L7 layers) |
| SC-FRACTAL | 5 | Fractal layer widget composition, genotype topology |
| SC-PROM | 7 | PROMETHEUS DAG verification, proof gates |

**Critical constraints to check first for any UI task:**
- SC-GLM-UI-001 — triple interface (Lustre + Wisp + TUI)
- SC-GLM-UI-003 — typed JSON, never string concatenation
- SC-GLM-UI-009 — types from `ui/domain.gleam` only
- SC-AGUI-004 — HITL mandatory at L0 Constitutional operations
- SC-HINT-002 — never modify `<!-- HUMAN-ONLY -->` sections

---

## 10. Common Tasks Quick Reference

### Adding a New Page

1. Add the page variant to `ui/domain.gleam` `Page` type and `page_to_path/1`
2. Create `ui/lustre/{name}.gleam` with `Model`, `Msg`, `init`, `update`, `view`
3. Create `ui/wisp/{name}_api.gleam` with JSON handlers
4. Create `ui/tui/{name}_view.gleam` with `render(ctx)` function
5. Register the route in `ui/wisp/router.gleam`
6. Add navigation entry in `ui/lustre/app.gleam`
7. Write tests covering C1-C8 in `test/cepaf_gleam/ui/lustre/{name}_test.gleam`

```bash
# Verify all three compile after adding
cd lib/cepaf_gleam && gleam build
```

### Adding an AG-UI Event Handler

1. The event type already exists in `agui/events.gleam` — do not add new types
2. Add the new `Msg` variant to the affected Lustre page
3. Add the handler in `update()` — Gleam will catch any missing cases at compile time
4. Wire the subscription in `ui/lustre/effects.gleam`

```gleam
// In ui/lustre/effects.gleam
pub fn on_text_chunk(dispatch: fn(Msg) -> Nil) -> Effect(Msg) {
  effect.from(fn(_) {
    subscribe_to_event(TextMessageChunk, fn(event) {
      dispatch(AgUiChunkReceived(event.payload))
    })
  })
}
```

### Creating an A2UI Component

1. Add the component spec to `a2ui/catalog.gleam` `default_catalog()`
2. Add the Lustre renderer case in `a2ui/renderer.gleam`
3. Add the TUI renderer case in `a2ui/renderer.gleam` (TUI branch)
4. Run `cd lib/cepaf_gleam && gleam build` — compiler enforces exhaustive matches

```gleam
// In a2ui/catalog.gleam — add to default_catalog list
#("my_widget", ComponentSpec(
  "my_widget",
  L3Transaction,
  "My widget description",
  [PropSpec("data", JsonProp, "The data to display")],
  [PropSpec("compact", BoolProp, "Compact mode")],
))
```

### Adding a Fractal Layer Widget

1. Open the relevant `fractal/l{N}_{name}.gleam` module
2. Add your widget type and render function following the existing pattern
3. Import and embed in the parent Lustre page component
4. The `[C3I-SIL6-MSTS]` module contract header is mandatory — copy from existing file

```gleam
//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/fractal/l2_component</module></identity>
////   <fractal-topology><layer>L2_COMPONENT</layer></fractal-topology>
////   <compliance><stamp-controls>SC-VER-042, SC-AGUI-004</stamp-controls></compliance>
//// </c3i-module>
```

### Writing Tests for a Page

Source-first rule (AOR-COV-008): always read the `.gleam` source before writing tests.

1. Read `ui/lustre/{name}.gleam` — extract Model fields, Msg variants, helper functions
2. Read `ui/wisp/{name}_api.gleam` — extract JSON encoding functions
3. Read `ui/tui/{name}_view.gleam` — extract render function signature
4. Write tests covering the 8 categories (see Section 7.1)
5. Compute ITQS using `testing/coverage_math.gleam` helpers

---

## 11. Anti-Patterns to Avoid

| Anti-Pattern | Why It Is Wrong | Correct Approach |
|-------------|-----------------|-----------------|
| Client-side JavaScript | Violates SC-GLM-UI-002: Lustre is server-rendered only | All interactivity via Lustre MVU on BEAM |
| Raw string JSON: `"{ \"x\": " <> v <> "}"` | Violates SC-GLM-UI-003: brittle, untypeable | Use `gleam/json` object/array/string/int |
| Defining `Page` in wisp module | Violates SC-GLM-UI-009: type duplication | Import from `ui/domain.gleam` only |
| Implementing only Lustre without Wisp + TUI | Violates SC-GLM-UI-001: 67% incomplete feature | Implement all three or mark as incomplete |
| Direct state mutation in view | Gleam is purely functional — view must be pure | Move mutations to `update()` |
| Modifying `<!-- HUMAN-ONLY -->` sections | Violates SC-HINT-002: inviolable contract | Leave section byte-for-byte unchanged |
| Adding new AG-UI event types | Protocol is fixed at 32 types | Use `Custom` or `Raw` for extensions |
| Sending executable code from agent to UI | Violates SC-A2UI-001: security boundary | Use A2UI JSON spec — declarative only |
| Skipping fractal layer `[C3I-SIL6-MSTS]` header | Missing compliance trace | Copy header from existing fractal module |
| Using port 4000-4010 for Gleam UI | Violates SC-GLM-UI-006: mesh port range | Use port 4100 (Wisp) or CLI (TUI) |
| Wisp endpoint without corresponding TUI view | Violates SC-GLM-UI-007 | TUI view is mandatory for every API |
| `use` with async effects that block | Lustre effects must be non-blocking | Use `effect.from` with callback dispatch |

---

## 12. Domain Types Reference (ui/domain.gleam)

```gleam
// Pages (all must be handled in router and nav)
pub type Page {
  Dashboard | Planning | Immune | Knowledge | Zenoh | Cockpit
  | Verification | Substrate | Metabolic | Podman | Mcp | Kms | Telemetry
}

// Health status (all must render in every interface)
pub type HealthStatus {
  Healthy
  Degraded(reason: String)
  Critical(reason: String)
  Unknown
}

// Telemetry data — sourced from Zenoh
pub type TelemetryPoint {
  TelemetryPoint(key: String, value: Float, timestamp: Int, unit: String)
}

// Actions — same semantics in Web, API, and TUI
pub type Action {
  Navigate(page: Page)
  Refresh
  Execute(command: String)
  Subscribe(topic: String)
  Unsubscribe(topic: String)
}

// Session state carried across all three interfaces
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

## 13. Related Documents

| Document | Purpose |
|----------|---------|
| `.claude/rules/gleam-web-ui-development.md` | Full Gleam UI rule (master reference) |
| `docs/journal/20260403-1500-fractal-agentic-ui-system-design.md` | AG-UI + A2UI design |
| `docs/journal/20260403-1600-fractal-agentic-ui-lustre-wisp-alignment.md` | Lustre transport correction |
| `docs/journal/20260403-1700-gleam-testing-framework-graph-coverage-hitl.md` | Testing framework |
| `docs/journal/20260403-1800-fractal-agentic-ui-comprehensive-implementation-plan.md` | 12-phase plan |
| `docs/PLANNING_WEBUI_DESIGN.md` | 8-panel dashboard design spec |
| `.claude/rules/fractal-coverage-gold-standard.md` | 8-category E2E standard |
| `.claude/rules/fractal-coverage-mathematical-framework.md` | Coverage math formulas |
| `.claude/rules/ui-graph-testing.md` | Graph-theory UI testing |
| `.claude/rules/human-intent-protection.md` | SC-HINT inviolable sections |
| `.claude/rules/mandatory-compile-env.md` | Required env vars for compile/test |

---

**Version**: 21.4.0-GLM
**Gleam codebase root**: `/home/an/dev/ver/c3i/lib/cepaf_gleam/src/cepaf_gleam/`
**Last updated**: 2026-04-03
