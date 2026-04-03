# C3I AG-UI Integration Plan

## Architecture: The Golden Triangle for Indrajaal

The C3I system maps perfectly to the **Golden Triangle** pattern:
1. **AG-UI** (Agent-User Interaction) -- Replaces our static Wisp JSON API with streaming, event-driven protocol
2. **MCP** (Model Context Protocol) -- Already implemented in `mcp/server.gleam`
3. **OpenTelemetry** -- Already wired via `telemetry/exporter.gleam` to collector at `localhost:4318`

```
┌─────────────────────────────────────────────────────────────────┐
│                     C3I Golden Triangle                         │
│                                                                 │
│  ┌──────────┐     AG-UI Events (SSE)     ┌──────────────────┐  │
│  │ Frontend  │◄═══════════════════════════│ Gleam BEAM       │  │
│  │ (Browser) │════════════════════════════►│ (Wisp + Mist)   │  │
│  │           │     User Messages          │                  │  │
│  └──────────┘                             │  ┌────────────┐  │  │
│       │                                   │  │ AG-UI      │  │  │
│       │                                   │  │ Event      │  │  │
│       │                                   │  │ Emitter    │  │  │
│       │                                   │  └─────┬──────┘  │  │
│       │                                   │        │         │  │
│       │                                   │  ┌─────┴──────┐  │  │
│       │                                   │  │ OTP Actors │  │  │
│       │                                   │  │ (Planning, │  │  │
│       │                                   │  │  Safety,   │  │  │
│       │                                   │  │  Zenoh)    │  │  │
│       │                                   │  └─────┬──────┘  │  │
│       │                                   │        │         │  │
│       │     ┌───────────┐                 │  ┌─────┴──────┐  │  │
│       │     │ MCP       │◄────────────────│  │ MCP Server │  │  │
│       │     │ Clients   │  stdio/JSON-RPC │  │ (5 tools)  │  │  │
│       │     └───────────┘                 │  └────────────┘  │  │
│       │                                   │                  │  │
│       │     ┌───────────┐                 │  ┌────────────┐  │  │
│       └────►│ OTel      │◄────────────────│  │ Exporter   │  │  │
│             │ Collector  │  OTLP/HTTP     │  │ (OTLP)     │  │  │
│             │ :4318      │                │  └────────────┘  │  │
│             └───────────┘                 └──────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Zenoh Mesh (3 routers)                │   │
│  │  Events, Telemetry, State Sync via pub/sub               │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## AG-UI Event Mapping to C3I Domains

### Event Types → C3I Fractal Layers

| AG-UI Event | C3I Usage | Fractal Layer |
|---|---|---|
| `RUN_STARTED` / `RUN_FINISHED` | OODA cycle lifecycle | L5_COGNITIVE |
| `STEP_STARTED` / `STEP_FINISHED` | Planning task execution steps | L3_TRANSACTION |
| `TEXT_MESSAGE_START/CONTENT/END` | Agent reasoning output (Dark Cockpit) | L5_COGNITIVE |
| `TOOL_CALL_START/ARGS/END` | MCP tool invocation visibility | L5_COGNITIVE |
| `TOOL_CALL_RESULT` | MCP tool output (planning_query, verification_run) | L5_COGNITIVE |
| `STATE_SNAPSHOT` | Full mesh state broadcast | L6_ECOSYSTEM |
| `STATE_DELTA` | Incremental telemetry updates (JSON Patch) | L1_ATOMIC_DEBUG |
| `MESSAGES_SNAPSHOT` | Chat history / OODA observation log | L3_TRANSACTION |
| `ACTIVITY_SNAPSHOT/DELTA` | Planning task progress, Verification runs | L2_COMPONENT |
| `RAW` | Zenoh native events passthrough | L6_ECOSYSTEM |
| `CUSTOM` | Safety alerts, Circuit breaker events | L0_CONSTITUTIONAL |
| `REASONING_*` | SafetyKernel constitutional reasoning chain | L0_CONSTITUTIONAL |

### Implementation Approach: SSE Endpoint

The AG-UI protocol is transport-agnostic but recommends **Server-Sent Events (SSE)** for HTTP. Our Mist server can emit SSE by:

1. Client POSTs to `/ag-ui/run` with `RunAgentInput` (threadId, runId, messages, tools, context)
2. Server returns `text/event-stream` response
3. Server emits typed AG-UI events as SSE frames
4. Client processes events to update UI state

```gleam
// Proposed AG-UI SSE endpoint pattern
pub fn handle_agui_run(req: Request) -> Response {
  // 1. Parse RunAgentInput from POST body
  // 2. Start OTP actor for this run
  // 3. Return SSE stream that emits AG-UI events
  //    - RUN_STARTED
  //    - STEP_STARTED("planning_query")
  //    - TOOL_CALL_START/ARGS/END
  //    - TEXT_MESSAGE_START/CONTENT/END (streaming response)
  //    - STATE_DELTA (incremental mesh updates)
  //    - RUN_FINISHED
}
```

### Generative UI (A2UI) Integration

Per the Google research paper and AG-UI's A2UI spec, agents can propose UI widget trees that the frontend validates and mounts. For C3I:

| C3I Domain | Generative Widget | Description |
|---|---|---|
| Cockpit | `MeshNodeGrid` | Dynamic grid of container health cards |
| Planning | `TaskKanbanBoard` | Drag-drop task board generated from agent planning |
| Verification | `ComplianceMatrix` | Color-coded fractal layer compliance grid |
| Telemetry | `SparklineChart` | Real-time metrics visualization |
| Immune | `ThreatGauge` | Threat level indicator with animation |
| Zenoh | `TopologyGraph` | Interactive mesh topology visualization |

### Shared State (Read/Write)

AG-UI's shared state pattern maps directly to our existing architecture:
- **STATE_SNAPSHOT**: Full `RenderContext` (page, health, telemetry, zenoh_connected)
- **STATE_DELTA**: JSON Patch operations for incremental updates
- Backed by Zenoh pub/sub for real-time distribution across mesh nodes

### Human-in-the-Loop (Interrupts)

Critical for SIL-6 compliance:
- **SafetyKernel** constitutional checks can pause execution (RUN_FINISHED with outcome="interrupt")
- **Guardian approval** requests map to AG-UI interrupt pattern
- **Two-key-turn** operations (Prajna Orchestrator) use interrupt for second confirmation

## Implementation Phases

### Phase 1: AG-UI Event Types in Gleam
Create `src/cepaf_gleam/agui/events.gleam` with all 16 event types as Gleam custom types.

### Phase 2: SSE Transport
Add `/ag-ui/run` SSE endpoint to Wisp router using Mist streaming response.

### Phase 3: Agent Adapter
Wire existing OTP actors (SafetyKernel, Planning Manager) to emit AG-UI events.

### Phase 4: Frontend Client
Update the HTML shell to use EventSource API for SSE consumption.

### Phase 5: Generative UI Widgets
Define widget schemas that agents can propose for dynamic UI rendering.

## Compatibility Matrix

| Protocol | C3I Status | Integration Point |
|---|---|---|
| **AG-UI** (Agent↔User) | PLANNED | Wisp SSE endpoint + Lustre frontend |
| **MCP** (Agent↔Tools) | IMPLEMENTED | `mcp/server.gleam` (5 tools, stdio transport) |
| **A2A** (Agent↔Agent) | NATURAL FIT | Zenoh pub/sub already provides inter-agent communication |
| **OpenTelemetry** | IMPLEMENTED | `telemetry/exporter.gleam` → OTel collector :4318 |
