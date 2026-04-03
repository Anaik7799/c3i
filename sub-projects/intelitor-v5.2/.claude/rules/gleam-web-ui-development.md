---
paths: lib/cepaf_gleam/src/cepaf_gleam/ui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/agui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/a2ui/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/testing/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/fractal/**/*.gleam, lib/indrajaal_gleam_web/src/**/*.gleam, lib/cepaf_gleam/test/**/*.gleam
---

# Gleam Fractal Agentic UI Development & Testing Protocol (SC-GLM-UI + SC-AGUI + SC-A2UI)

## SUPREME MANDATE

**ALL c3i Web UI development MUST follow the Fractal Agentic UI approach: AG-UI protocol
(32 event types), A2UI declarative component catalog, Lustre server components as transport,
Triple-Interface mandate, Dark Cockpit pattern, 8-category coverage gold standard, and
Gleam type-safety guarantees.**

This rule consolidates AG-UI, A2UI, Lustre, Wisp, TUI, graph-theory testing, mathematical
coverage framework, Human Intent protection, and PROMETHEUS verification into a single
reference for Gleam-based Fractal Agentic UI development.

---

## 1.0 Architecture: Triple-Interface Mandate (SC-GLM-UI-001)

Every UI capability MUST be implemented across all 3 interfaces simultaneously:

| Interface | Framework | Path | Port | Purpose |
|-----------|-----------|------|------|---------|
| **Lustre (Web SSR)** | Lustre 5.6+ MVU | `ui/lustre/*.gleam` | 4100 | Server-side rendered HTML, no client JS |
| **Wisp (REST API)** | Wisp HTTP/JSON | `ui/wisp/*.gleam` | 4100 | Typed JSON API for external consumers |
| **TUI (Terminal)** | ANSI rendering | `ui/tui/*.gleam` | — | Terminal dashboard with sparklines |

**Shared types MUST come from `ui/domain.gleam`** — no per-interface type duplication (SC-GLM-UI-009).

### Domain Types (Canonical Source: `cepaf_gleam/ui/domain.gleam`)
```gleam
pub type Page { Dashboard | Planning | Immune | Knowledge | Zenoh | Cockpit
  | Verification | Substrate | Metabolic | Podman | Mcp | Kms | Telemetry }
pub type HealthStatus { Healthy | Degraded(reason: String) | Critical(reason: String) | Unknown }
pub type TelemetryPoint { TelemetryPoint(key: String, value: Float, timestamp: Int, unit: String) }
pub type Action { Navigate(page: Page) | Refresh | Execute(command: String)
  | Subscribe(topic: String) | Unsubscribe(topic: String) }
pub type RenderContext { RenderContext(page: Page, health: HealthStatus, ...) }
```

---

## 2.0 STAMP Constraints (SC-GLM-UI)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-GLM-UI-001 | Triple-interface: Lustre SSR + Wisp JSON + TUI ANSI for every capability | CRITICAL |
| SC-GLM-UI-002 | Lustre MVU pattern: Model/Msg/init/update/view — server-side on BEAM | HIGH |
| SC-GLM-UI-003 | Typed JSON via `gleam/json` — NO raw string concatenation | HIGH |
| SC-GLM-UI-004 | All UI modules MUST have C3I-SIL6-MSTS module contract header | MEDIUM |
| SC-GLM-UI-005 | Real-time telemetry via Zenoh PubSub subscription | HIGH |
| SC-GLM-UI-006 | Wisp HTTP binds to port 4100 — outside mesh range 4000-4010 | CRITICAL |
| SC-GLM-UI-007 | Every Wisp endpoint MUST have corresponding Lustre component AND TUI view | HIGH |
| SC-GLM-UI-008 | Dark Cockpit pattern: panels auto-hide when healthy (SC-HMI-010) | HIGH |
| SC-GLM-UI-009 | Shared types from `ui/domain.gleam` ONLY — no duplication | HIGH |
| SC-GLM-UI-010 | AG-UI SSE streaming for real-time dashboard updates | HIGH |

---

## 3.0 Dark Cockpit Pattern (SC-HMI-010)

### Progressive Disclosure Modes
```
Dark       -> All healthy, minimal display (gray defaults)
Dim        -> Warnings present, subtle indicators
Normal     -> Errors present, visible status
Bright     -> Multiple errors, high-visibility alerts
Emergency  -> Critical failures, full illumination + audio
```

### Implementation (`prajna/dark_cockpit.gleam`)
- `CockpitMode` ADT: `Dark | Dim | NormalMode | Bright | EmergencyMode`
- `determine_mode(alerts)` — derives mode from unacknowledged alert counts
- Mode transitions are automatic based on alert severity

### Color Rich Profiles (4 selectable, SC-HMI-010)
1. **Dark Cockpit** — Gray defaults, color only on anomalies
2. **Color Rich** — Vibrant colors for healthy states, linked to Zenoh telemetry
3. **Google Compliant** — WCAG 2.1 AA accessibility
4. **Functionally Clean** — Minimal, monochrome with semantic indicators

---

## 4.0 Web UI Design Pattern: 8-Panel Dashboard

Reference: `docs/PLANNING_WEBUI_DESIGN.md`

```
+-----------------------------------------------------+
| [C3I COCKPIT]              [SIL-6 STATUS]  [AG-UI]  |
+------+----------------------------------------------+
|      |  TASK BOARD  |  OODA CYCLE  |  SAFETY KERNEL |
| NAV  |  GRAPH VERIFY|  ORCH MESH   |  CHAYA TWIN    |
|      |             DETAIL PANEL                      |
|      |             AG-UI CHAT / SSE STREAM           |
+------+----------------------------------------------+
```

Each panel maps to a Fractal Layer (L0-L7) and has FMEA risk analysis.

---

## 5.0 Lustre Component Pattern (MVU)

Every Lustre page component follows this structure:

```gleam
//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/ui/lustre/{page}</module></identity>
////   <compliance><stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002</stamp-controls></compliance>
//// </c3i-module>

import cepaf_gleam/ui/domain.{type Page, type RenderContext, ...}
import lustre/element.{type Element}
import lustre/element/html
import lustre/attribute

/// Page-specific model
pub type Model { Model(context: RenderContext, ...) }

/// Page-specific messages
pub type Msg { ... }

/// Initialize with RenderContext
pub fn init(ctx: RenderContext) -> Model { ... }

/// Update: pure function, no side effects
pub fn update(model: Model, msg: Msg) -> Model { ... }

/// View: render to Lustre HTML elements
pub fn view(model: Model) -> Element(Msg) { ... }
```

---

## 6.0 Wisp API Pattern

```gleam
/// Wisp API for {Domain} plane (SC-GLM-UI-001, SC-GLM-UI-003).
/// Typed JSON via gleam/json — no raw strings (SC-GLM-UI-003).
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-003, SC-GLM-UI-007

import gleam/json
import wisp.{type Request, type Response}

pub fn handle_list(req: Request) -> Response {
  let data = ... // fetch from domain service
  let body = json.to_string_tree(json.object([
    #("status", json.string("ok")),
    #("data", json.array(data, encode_item)),
  ]))
  wisp.json_response(body, 200)
}
```

---

## 7.0 TUI View Pattern

```gleam
/// TUI view for {Domain} (SC-GLM-UI-001).
import cepaf_gleam/cockpit/visuals.{with_color, render_progress_bar, render_sparkline}

pub fn render(context: RenderContext) -> String {
  let header = with_color("=== {DOMAIN} ===", "cyan")
  let body = ... // ANSI-formatted status lines
  header <> "\n" <> body
}
```

---

## 8.0 Testing Protocol

### 8.1 Gleam Unit Tests (gleeunit)
- Path: `lib/cepaf_gleam/test/**/*_test.gleam`
- Framework: gleeunit with `should` assertions
- Every Lustre component, Wisp endpoint, and TUI view MUST have unit tests

### 8.2 E2E Browser Testing (Adapted from Wallaby Gold Standard)

The Elixir Wallaby framework principles apply to Gleam UI with adaptation:

**8 Mandatory Test Categories (C1-C8):**

| Cat | Name | Weight | What to Test |
|-----|------|--------|-------------|
| C1 | Page Structure | 1.0 | h1 heading, nav presence, section structure |
| C2 | Status/Badge | 1.5 | Dynamic badges, severity indicators, health status |
| C3 | Data Grid/Summary | 1.0 | Key-value data, tables, service entries |
| C4 | Timeline/History | 1.2 | Timer refresh stability, temporal data |
| C5 | Interactive | 2.0 | Navigation, form submission, state changes |
| C6 | Media/Rich | 1.0 | Semantic CSS classes, sparklines, SVG, charts |
| C7 | AI/Advisory | 1.5 | Metric interpretation, contextual analysis |
| C8 | Action Buttons | 3.0 | DUAL: status change AND feedback per action |

**Quality Gates:**
- Shannon Entropy H >= 2.5 bits (balanced across categories)
- CCM >= 0.90 (weighted coverage completeness)
- ITQS >= 0.85 per file
- D_EA <= 0.10 (source alignment divergence)

### 8.3 Source-First Mandate (AOR-COV-008)
ALWAYS read the Gleam source (`.gleam`) BEFORE writing test selectors:
1. Read module types and functions
2. Extract Model fields -> data elements to verify
3. Extract Msg variants -> interactions to test
4. Extract view function -> DOM structure expectations
5. Check Zenoh subscriptions -> real-time data flows

### 8.4 Wisp API Testing
```gleam
import gleeunit/should
import wisp/testing

pub fn list_endpoint_returns_json_test() {
  let req = testing.get("/api/planning/tasks", [])
  let resp = handle_list(req)
  resp.status |> should.equal(200)
  // Verify JSON structure
}
```

---

## 9.0 Human-Specified Intent (SC-HINT)

Every page spec or Gleam UI module documentation MUST include:
```
## Human-Specified Intent
<!-- HUMAN-ONLY: DO NOT AUTO-MODIFY -->
[Only humans may edit this section]
<!-- END HUMAN-ONLY -->
```

Agents MUST NEVER modify this section. Alignment Score MUST be >= 0.7.

---

## 10.0 AG-UI Protocol (SC-AGUI-001..017) — Agentic UI Event System

### 10.1 AG-UI Core Architecture
AG-UI is the universal event bus connecting agents to all 3 interfaces. Lustre server
components handle the WebSocket transport; Wisp handles REST; Zenoh handles telemetry.

```
Agent Backend → AG-UI Events → Lustre Server Component → WebSocket → Browser
                             → Wisp REST API → JSON response
                             → TUI OTP messages → ANSI terminal
                             → Zenoh PubSub → Mesh replication
```

### 10.2 AG-UI Event Types (32 total — ALL MUST be implemented per SC-AGUI-001)

| Category | Events | Purpose |
|----------|--------|---------|
| Lifecycle (5) | RunStarted, RunFinished, RunError, StepStarted, StepFinished | Execution context |
| Text (4) | TextMessageStart, TextMessageContent, TextMessageEnd, TextMessageChunk | Streaming text |
| Tool (5) | ToolCallStart, ToolCallArgs, ToolCallEnd, ToolCallResult, ToolCallChunk | Tool invocation |
| State (3) | StateSnapshot, StateDelta (RFC 6902), MessagesSnapshot | State sync |
| Activity (2) | ActivitySnapshot, ActivityDelta | Activity tracking |
| Reasoning (7) | ReasoningStart, ReasoningMessageStart/Content/End/Chunk, ReasoningEnd, ReasoningEncryptedValue | Visible CoT |
| Special (4) | Raw, Custom, MetaEvent | Extension points |

### 10.3 AG-UI Module Map (`agui/`)

| Module | Purpose | STAMP |
|--------|---------|-------|
| `events.gleam` | 32 EventType ADT + constructors + SSE serialization | SC-AGUI-001 |
| `state.gleam` | RFC 6902 JSON Patch (add/replace/remove/move/copy/test) + SharedState | SC-AGUI-003 |
| `tools.gleam` | Tool call lifecycle + Args accumulation + HITL queue | SC-AGUI-004 |
| `reasoning.gleam` | Reasoning event handlers + encrypted CoT persistence | SC-AGUI-006 |
| `activity.gleam` | Activity snapshot/delta management | SC-AGUI-008 |
| `capabilities.gleam` | Dynamic capability discovery endpoint | SC-AGUI-001 |
| `middleware.gleam` | Event transformation pipeline (intercept, transform, forward) | SC-AGUI-001 |
| `multimodal.gleam` | Typed attachments (file, image, audio, transcript) | SC-AGUI-010 |
| `sse.gleam` | SSE connection + event dispatch (fallback transport) | SC-AGUI-002 |
| `zenoh_bus.gleam` | Zenoh publish/subscribe + A2A messaging + event replay | SC-AGUI-001 |

### 10.4 Lustre Server Components AS AG-UI Transport (SC-AGUI-011..017)

Lustre server components run on BEAM and push DOM patches via WebSocket:

```gleam
// Each page is an OTP-supervised Lustre server component
lustre.supervised(dashboard_app(), args)  // SC-AGUI-012

// Dynamic per-agent-run UI instances
lustre.factory(agent_run_viewer_app())    // SC-AGUI-013

// AG-UI subscriptions via Lustre effects
effect.from(fn(dispatch) {                // SC-AGUI-014
  subscribe_to_agent(agent_id, fn(event) {
    dispatch(AgUiEventReceived(event))
  })
})

// Parallel agent subscriptions
effect.batch([                            // SC-AGUI-017
  subscribe_to_agent("cortex"),
  subscribe_to_agent("sentinel"),
])
```

**Transport Layer**:
- Lustre WebSocket: DOM patches (down) + UI events (up) — BIDIRECTIONAL
- Wisp REST: Tool results, HITL decisions, queries — REQUEST/RESPONSE (SC-AGUI-015)
- Zenoh PubSub: AG-UI events, A2A messages, telemetry — BIDIRECTIONAL

---

## 11.0 A2UI Declarative Component Catalog (SC-A2UI-001..005)

### 11.1 Principles
- Agents propose UI via declarative JSON — NEVER executable code (SC-A2UI-001)
- Application maintains trusted catalog of pre-approved components
- Flat ID-referenced list — LLM-friendly incremental generation
- Same JSON renders across Lustre (Web), Wisp (API), TUI (Terminal)

### 11.2 A2UI Module Map (`a2ui/`)

| Module | Purpose | STAMP |
|--------|---------|-------|
| `schema.gleam` | ComponentSpec, PropSpec, BindingSpec types | SC-A2UI-001 |
| `catalog.gleam` | Trusted component registry + fractal layer access control | SC-A2UI-004 |
| `renderer.gleam` | A2UI JSON -> Lustre Element mapping | SC-A2UI-003 |
| `bindings.gleam` | Data binding (state path -> component prop) | SC-A2UI-005 |
| `validator.gleam` | Security validation (allowlist enforcement) | SC-A2UI-002 |

### 11.3 Component Catalog

| A2UI Type | Lustre Renderer | TUI Renderer | Layer |
|-----------|----------------|-------------|-------|
| badge | html.span with class | with_color(text) | L2 |
| button | html.button with on_click | "[action]" text | L2 |
| data_table | html.table(rows) | render_table() | L3 |
| progress | html.div progress bar | render_progress_bar() | L4 |
| sparkline | svg.path | render_sparkline() | L1 |
| alert | html.div role="alert" | with_color("ALERT") | L0 |
| modal | html.dialog | "=== MODAL ===" | L0 |
| ooda_ring | Custom SVG | O->O->D->A ASCII | L5 |
| reasoning | html.pre streaming | Streaming text | L5 |
| topology | Custom SVG graph | ASCII graph | L6 |

---

## 12.0 Fractal Agentic Element Model

Every UI element is a **Fractal Agentic Holon** with:

```gleam
pub type FractalElement {
  FractalElement(
    id: String,                        // Unique holon identity (FQUN)
    layer: FractalLayer,               // L0-L7 placement
    element_type: ElementType,         // Widget, Panel, Dashboard, etc.
    agent_binding: Option(AgentBinding), // Connected agent (if any)
    capabilities: List(Capability),    // What this element can do
  )
}

pub type FractalLayer {
  L0Constitutional | L1AtomicDebug | L2Component | L3Transaction
  | L4System | L5Cognitive | L6Ecosystem | L7Federation
}

pub type Capability {
  EmitEvents | ReceiveEvents | ProposeUI | AcceptHITL
  | DelegateToSubAgent | PersistState | StreamContent
}
```

---

## 13.0 Graph-Theory UI Testing (SC-UIGT)

### 22-Page Navigation Digraph
- |V| = 22 pages (all Lustre views)
- |E| ~ 400 edges (nav bar creates near-complete subgraph)
- SCC = 1 (all pages reachable)
- PageRank for test priority ordering

### Per-Page LTS
- States derived from Model type fields
- Labels derived from Msg type variants
- Transitions derived from update() pattern matches
- Prime path coverage >= 0.95 for Tier 1 pages

### Testing modules (`testing/`)

| Module | Purpose | STAMP |
|--------|---------|-------|
| `nav_graph.gleam` | Adjacency matrix, PageRank, SCC | SC-UIGT-001..014 |
| `lts.gleam` | Labeled Transition Systems per page | SC-UIGT-003 |
| `prime_paths.gleam` | DFS prime path enumeration | SC-UIGT-004 |
| `coverage_math.gleam` | Shannon entropy, CCM, FMEA RPN, FSI, D_EA, ITQS | SC-MATH-COV-001..008 |
| `alignment.gleam` | Human Intent alignment score | SC-HINT-001..008 |
| `feature_case.gleam` | E2E test helpers (HTTP API assertions) | SC-COV-001..008 |
| `element_assertions.gleam` | Lustre Element tree structural assertions | SC-COV-009..022 |

---

## 14.0 HITL (Human-in-the-Loop) Pattern

```gleam
// Agent requests approval via TOOL_CALL
AgUiToolCallStart(tool_call_id: "approve-123", tool_name: "guardian_approve")

// Frontend shows modal dialog (A2UI modal component)
// User clicks Approve/Reject/Escalate

// Response sent via Wisp REST
POST /agui/hitl/respond { "request_id": "approve-123", "decision": "approved" }

// Agent receives result and continues
AgUiToolCallResult(tool_call_id: "approve-123", content: "approved")
```

HITL is MANDATORY for L0 Constitutional operations (SC-AGUI-004).

---

## 15.0 File Structure (Complete)

```
lib/cepaf_gleam/src/cepaf_gleam/
  agui/                    # AG-UI Protocol (10 modules)
    events.gleam           # 32 event types + constructors + SSE
    state.gleam            # RFC 6902 JSON Patch + SharedState
    tools.gleam            # Tool call lifecycle + HITL queue
    reasoning.gleam        # Reasoning events + encrypted CoT
    activity.gleam         # Activity snapshot/delta
    capabilities.gleam     # Dynamic capability discovery
    middleware.gleam        # Event transformation pipeline
    multimodal.gleam       # Typed attachments
    sse.gleam              # SSE fallback transport
    zenoh_bus.gleam        # Zenoh pub/sub + A2A messaging
  a2ui/                    # A2UI Declarative Components (5 modules)
    schema.gleam           # Component/Prop/Binding specs
    catalog.gleam          # Trusted component registry
    renderer.gleam         # JSON -> Lustre Element
    bindings.gleam         # State path -> prop binding
    validator.gleam        # Security allowlist
  testing/                 # Test Framework (7 modules)
    nav_graph.gleam        # 22-page digraph + PageRank
    lts.gleam              # Labeled Transition Systems
    prime_paths.gleam      # DFS prime path enumeration
    coverage_math.gleam    # Shannon H, CCM, ITQS, FSI, D_EA
    alignment.gleam        # Human Intent alignment score
    feature_case.gleam     # E2E test helpers
    element_assertions.gleam # Lustre Element assertions
  ui/                      # Triple-Interface
    domain.gleam           # Shared types (CANONICAL)
    lustre/                # Web SSR (22+ modules + infra)
      app.gleam            # Main MVU with AG-UI Msg
      supervisor.gleam     # OTP supervisor for all pages
      factory.gleam        # Per-agent-run dynamic instances
      effects.gleam        # AG-UI effect catalog
      layout.gleam         # 8-panel dashboard grid
      {22 domain views}    # Each a lustre.component()
    wisp/                  # REST API (14+ modules + AG-UI)
      router.gleam         # HTTP router + /agui/** endpoints
      agui_handler.gleam   # AG-UI run/tool/hitl handlers
      {14 domain APIs}     # JSON API endpoints
    tui/                   # Terminal (22+ modules)
      renderer.gleam       # ANSI rendering engine
      agent_panel.gleam    # Agent reasoning in TUI
      {22 domain views}    # ANSI dashboard views
  fractal/                 # Fractal Layer Widgets (L0-L7)
    l0/                    # Constitutional: guardian, emergency stop
    l1/                    # Debug: trace viewer, event monitor
    l2/                    # Component: forms, data grids, badges
    l3/                    # Transaction: state diff, tool panel
    l4/                    # System: run monitor, step tracker
    l5/                    # Cognitive: reasoning, OODA, AI copilot
    l6/                    # Ecosystem: agent mesh, A2A messages
    l7/                    # Federation: gateway, version vectors
  verification/            # PROMETHEUS + Graph Verification
    prometheus.gleam       # DAG path safety proofs
    graph_verification.gleam # SCC, cycle detection
    coverage_audit.gleam   # ITQS computation for all tests
  cockpit/
    domain.gleam           # Cockpit domain types
    visuals.gleam          # Colors, progress bars, sparklines
  prajna/
    dark_cockpit.gleam     # 5-mode state machine

lib/indrajaal_gleam_web/src/
  indrajaal_gleam_web.gleam  # Web app entry point
  indrajaal_gleam_web/types.gleam

src/rust/                  # Rust utility crates (SC-NIF-001)
  c3i_agui_ideas/          # AG-UI idea FMEA ranking
  c3i_swarm_generator/     # Swarm generation
  c3i_coverage_audit/      # Coverage math from .gleam files
  c3i_nav_graph/           # Graph analysis (PageRank, SCC)
  c3i_prometheus_verify/   # DAG verification + proofs
```

---

## 16.0 Compile & Test Commands

```bash
# Gleam build (SC-GLM-CMP-001: zero warnings)
cd lib/cepaf_gleam && gleam build

# Gleam test (SC-GLM-CMP-004: BEAM target)
cd lib/cepaf_gleam && gleam test

# Rust NIF build (SC-GLM-NIF-005: zero warnings)
cd src/rust/c3i_coverage_audit && cargo build --release

# Full Elixir integration
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
mix compile --jobs 16
```

---

## 17.0 STAMP Constraints Summary

**AG-UI Protocol**: SC-AGUI-001..017
**A2UI Catalog**: SC-A2UI-001..005
**Gleam UI**: SC-GLM-UI-001..010
**HMI**: SC-HMI-001..080
**Coverage**: SC-COV-001..022
**Math Coverage**: SC-MATH-COV-001..008
**Graph Testing**: SC-UIGT-001..015
**Human Intent**: SC-HINT-001..008
**Visual Data**: SC-VDP-001..017
**Grid**: SC-GRID-001..025
**Comonads**: SC-COMONAD-001..008
**Effects**: SC-EFFECT-001..010
**State Machine**: SC-STM-001..008
**Theme**: SC-THEME-001..006
**Arrows**: SC-ARROW-001..012

---

## 18.0 Related Documents

- `docs/journal/20260403-1800-fractal-agentic-ui-comprehensive-implementation-plan.md` — Master plan
- `docs/journal/20260403-1500-fractal-agentic-ui-system-design.md` — AG-UI design
- `docs/journal/20260403-1600-fractal-agentic-ui-lustre-wisp-alignment.md` — Lustre correction
- `docs/journal/20260403-1700-gleam-testing-framework-graph-coverage-hitl.md` — Testing framework
- `docs/PLANNING_WEBUI_DESIGN.md` — 8-Panel dashboard design
- `.claude/rules/fractal-coverage-gold-standard.md` — 8-category E2E standard
- `.claude/rules/fractal-coverage-mathematical-framework.md` — Coverage math
- `.claude/rules/ui-graph-testing.md` — Graph-theory UI testing
- `.claude/rules/prajna-biomorphic.md` — Color Rich, 8x8 matrix
- `.claude/rules/human-intent-protection.md` — SC-HINT inviolable sections
- `.claude/rules/five-level-testing.md` — 6-level testing (Level 6 = E2E)
- `.claude/agents/wallaby-coverage-engineer.md` — E2E test writing agent
- `.claude/agents/coverage-audit-agent.md` — Coverage math audit agent
- `.claude/agents/prajna-operator.md` — Cockpit operator agent

---

## 19.0 Enforcement

This rule is:
- **MANDATORY**: All Gleam UI code must follow Fractal Agentic UI approach
- **TYPED**: No raw strings in JSON — use `gleam/json` always (SC-GLM-UI-003)
- **AGENTIC**: All UIs are agent-driven via AG-UI protocol (SC-AGUI-001)
- **DECLARATIVE**: Agent UI proposals via A2UI JSON only (SC-A2UI-001)
- **TESTED**: 8-category coverage with mathematical quality gates (H >= 2.5, ITQS >= 0.85)
- **AUDITED**: Coverage entropy and ITQS computed per module
- **PROTECTED**: Human-Specified Intent sections are inviolable (SC-HINT-001..008)
- **SUPERVISED**: Each page is an OTP-supervised Lustre server component (SC-AGUI-012)
- **VERIFIED**: PROMETHEUS DAG verification for navigation safety
