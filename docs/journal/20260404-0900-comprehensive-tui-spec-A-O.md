# Indrajaal Ignition TUI — Master UI Agentic Creation Spec
## 7-Level Component Detail + Cross-Page Navigation (Parts A-O)

---

## PART A — APPLICATION BLUEPRINT

```
APPLICATION BLUEPRINT
├── A1. App Identity
├── A2. Page Inventory
├── A3. Navigation Architecture
├── A4. Global Design System
├── A5. Shared Layout Shell
└── A6. Cross-Cutting Concerns
```

### A1. App Identity

```yaml
app:
  name:        "Indrajaal Ignition Daemon TUI"
  purpose:     "SIL-6 Biomorphic Mesh Pre-Flight, Boot, and Verification"
  audience:    "Level-3 Systems Operators, Chaos Engineers"
  tone:        "industrial-precision | data-dense | cybernetic"
  framework:   "Rust + Ratatui + Crossterm"
  backend:     "Crossterm (AlternateScreen, RawMode)"
  routing:     "State-based Tab Indexing (0-9)"
  state:       "DashboardState struct (Global Mutex/Arc in future, local loop currently)"
  a11y_target: "WCAG 2.1 AA (Keyboard-first navigation)"
  breakpoints:
    compact:  "80×24"
    standard: "120×40"
    wide:     "200×60"
```

---

### A2. Page Inventory (Tab Index)

Define every page before writing any code. Each entry is a contract.

| Page ID  | Route/Index | Title        | Access  | Role in App                         |
|----------|-------------|--------------|---------|-------------------------------------|
| P-SWRM   | 0           | Swarm        | admin   | Lifecycle hub, container status     |
| P-GOV    | 1           | Governor     | admin   | Substrate telemetry, heatmaps       |
| P-CHK    | 2           | Checks       | admin   | Preflight/Verify results, Quorum    |
| P-TRC    | 3           | Trace (OTel) | admin   | OpenTelemetry flame graphs, latency |
| P-TOP    | 4           | Topology     | admin   | DAG visualization of mesh           |
| P-BLD    | 5           | Build Oracle | admin   | EMA adaptive timeout predictions    |
| P-NIF    | 6           | NIF Validator| admin   | ELF binary inspection, Glibc checks |
| P-RCV    | 7           | Recovery     | admin   | FMEA Top-5 playbooks, hitl actions  |
| P-LOG    | 8           | Raw Logs     | admin   | `tui-logger` centralized console    |
| P-AGT    | 9           | Agent UI     | admin   | DevUI Copilot, cognitive state      |

> Rule: The daemon cannot route to any index outside 0-9. Out of bounds must modulo wrap.

---

### A3. Navigation Architecture

#### A3.1 — Navigation Structure Map

```
APP SHELL (Terminal Frame)
├── Header (persistent, 4 rows)
│   ├── System Identity / Clock / Uptime
│   ├── Phase Indicator (Preflight, Launching, Complete)
│   ├── Agent CoT Marquee (Scrolling DevUI Trace)
│   └── Mesh Integrity Gauge (Running / Total)
│
├── TabBar (persistent, 2 rows)
│   └── Tabs 0-9 (Horizontal list, active tab highlighted Cyan)
│
├── ContentArea (flex-1)
│   └── match state.tab_index { ... } ← Page Content
│
└── Footer (persistent, 3 rows)
    └── Keybindings / Last Refresh Timestamp
```

#### A3.2 — Navigation State Rules

```
Active state:   Tab title enclosed in spaces, fg(Cyan).bold()
Hover state:    N/A (Terminal UI without mouse)
Focus state:    Row selection in tables uses bg(Rgb(40,50,80)).fg(White).bold()
Collapsed:      N/A
Breadcrumb:     N/A (Flat Tab structure)
Deep link:      N/A (Single process lifecycle)
Transitions:    Instantaneous buffer swap via Crossterm backend.
```

---

### A4. Global Design System (Ratatui Colors)

All components MUST reference these tokens mapped from `ConsoleChannel.fs`.

```rust
const INDRAJAAL_CYAN: Color    = Color::Rgb(0, 200, 220);    // Borders, Headers
const INDRAJAAL_GREEN: Color   = Color::Rgb(80, 220, 100);   // Success, Running
const INDRAJAAL_YELLOW: Color  = Color::Rgb(240, 200, 50);   // Warning, Degraded
const INDRAJAAL_RED: Color     = Color::Rgb(240, 60, 60);    // Critical, Failed
const INDRAJAAL_MAGENTA: Color = Color::Rgb(200, 100, 240);  // Trace, Zenoh
const INDRAJAAL_DIM: Color     = Color::Rgb(120, 120, 130);  // Secondary Text
const INDRAJAAL_BG: Color      = Color::Rgb(15, 15, 25);     // App Background
const INDRAJAAL_BORDER: Color  = Color::Rgb(50, 80, 120);    // Block Outlines
```

---

### A6. Cross-Cutting Concerns

| Concern            | Rule |
|--------------------|------|
| Loading states     | Display `[WAITING]` or `▱▱▱` in empty sparklines. |
| Error states       | Red text, `❌` icon, and push trace to Tab 8 (Raw Logs). |
| Empty states       | `No data yet. Run preflight.` displayed in dimmed text. |
| Keyboard nav       | `Tab/Right`, `Shift+Tab/Left` for navigation. `Up/Down` for selection. |
| Logging Output     | Captured exclusively by `tui-logger` (no `stdout()` leakage). |

---

## PART B — 7 LEVELS OF COMPONENT DETAIL

### COMPONENT: OTelFlameGraph (Trace Tab)
──────────────────────────────────────────────────────────────

**LEVEL 1 — IDENTITY**
  name:         OTelFlameGraph
  type:         display / data-viz
  page-role:    Visualize check latency relative to EMA timeout budget
  reusable:     yes (used in Trace Tab rows)
  a11y-role:    text visualization

**LEVEL 2 — STRUCTURE**
  root:         `String` formatted within a `Cell`
  ├── Emoji Indicator (`🔥`, `🟧`, `🟩`)
  ├── Filled Blocks (`▰`)
  └── Empty Blocks (`▱`)

**LEVEL 3 — LAYOUT**
  container:    Constraint::Length(22) within the Table Row.
  alignment:    Left-aligned text string.

**LEVEL 4 — VISUAL STYLE**
  fg_color:     Calculated based on `ratio = duration / timeout`. 
                `<0.5 = Green, <0.8 = Yellow, >0.8 = Red`.
  font:         Terminal monospace.

**LEVEL 5 — STATE MATRIX**
  │ State           │ Visual Treatment                             │
  │ default         │ `🟩 ▰▰▰▰▱▱▱▱▱▱▱▱▱▱` (Green)                  │
  │ warning         │ `🟧 ▰▰▰▰▰▰▰▰▰▰▱▱▱▱` (Yellow)                 │
  │ critical        │ `🔥 ▰▰▰▰▰▰▰▰▰▰▰▰▰▰` (Red)                    │
  │ no_budget       │ `⚡ 45ms` (Dim, raw text)                      │

**LEVEL 6 — BEHAVIOUR**
  data refresh:     On phase completion, a new `TraceEntry` is pushed. The `draw_trace_tab` maps the ratio to the string dynamically on every tick.

**LEVEL 7 — DATA CONTRACT**
  props:
    duration_ms: u64
    timeout_ms: u64
  logic:         ratio = min(duration / timeout, 1.0)
                 filled = ratio * 15 blocks

---

### COMPONENT: DependencyDAG (Topology Tab)
──────────────────────────────────────────────────────────────

**LEVEL 1 — IDENTITY**
  name:         DependencyDAG
  type:         display / data-viz
  page-role:    ASCII Directed Acyclic Graph showing boot hierarchy.
  reusable:     no (Topology specific)

**LEVEL 2 — STRUCTURE**
  root:         `Paragraph` composed of `Line` and `Span` vectors.
  ├── Node      (`● indrajaal-db-prod`)
  ├── Edge      (`─────`)

**LEVEL 3 — LAYOUT**
  container:    Full screen, center aligned.

**LEVEL 4 — VISUAL STYLE**
  node fg:      `INDRAJAAL_GREEN` if Running, `INDRAJAAL_RED` if Failed.
  edge fg:      `INDRAJAAL_DIM` standard, `INDRAJAAL_RED` if connection broken.

**LEVEL 5 — STATE MATRIX**
  │ State           │ Visual Treatment                             │
  │ active          │ Solid `●` with Green text.                   │
  │ degraded        │ Half `◐` with Yellow text.                   │
  │ waiting         │ Hollow `○` with Dim text.                    │

**LEVEL 6 — BEHAVIOUR**
  updates:          Reflects the `health` field of `ContainerRow` in state.

**LEVEL 7 — DATA CONTRACT**
  consumes:     `state.containers`

---

## PART C — PAGE DESCRIPTIONS

### C.1: P-SWRM (Swarm Lifecycle Tab)
**Identity**: Tab 0. The central command hub for the container lifecycle.
**Layout**: Mesh Matrix (Top 20%), Details Table with Sparklines (Bottom 80%).
**Components**: `StateSparkline`, `ContainerStatusTable`.
**Behavior**: Users press `Down`/`Up` to select containers. The metadata pane responds to this selection.

### C.2: P-AGT (Agent UI Copilot)
**Identity**: Tab 9. The DevUI view.
**Layout**: Horizontal split. 70% Dialogue, 30% Cognitive State.
**Components**: `CortexDialogueBox`, `ConfidenceMeter`, `ActiveDirectivesList`.
**Behavior**: The Dialogue Box receives new lines as the orchestrator executes commands. The Confidence Meter shifts dynamically from 0-100 based on the EMA timeout predictions.

---

## PART I — RATATUI COMPONENT ARCHITECTURE

### I1. Widget Trait Taxonomy
The ignition daemon relies primarily on `Widget for &State` stateless rendering. The actual state is hoisted globally into the `DashboardState` object, passed immutably to the `draw_*_tab` functions on every tick.

### I2. Rendering Pipeline
1.  Tick triggers every `100ms` for events, `2000ms` for podman data pulls.
2.  `terminal.draw(|f| draw_ui(f, &state))`
3.  `draw_ui` routes to `draw_header`, `draw_tabs`, `match tab_index`, and `draw_footer`.
4.  Crossterm backend flushes the diff to the AlternateScreen.

---

## PART J — CONTROL & DATA FLOW ARCHITECTURE

### J1. TEA Event Loop
1.  **Poll**: `event::poll` listens for KeyCodes.
2.  **Dispatch**: `Up/Down` modifies `state.selected_container` or `state.trace_scroll`.
3.  **Update**: Background `tokio` tasks (like `cmd_full`) mutate the global state (in a production environment via `Arc<Mutex>`, here simulated sequentially via the test loops).
4.  **Render**: Synchronous layout recalculation and frame draw.

---

## PART O — UNIFIED CLOSED-LOOP: GEMINI + BDD + DAG

The Ratatui application has been wired with a closed-loop testing mode (`--test-ui`).
When invoked:
1.  The app bypasses the physical stdout rendering (preventing test runner pollution).
2.  It spins up a 120x40 `TestBackend`.
3.  It executes **50 complete rendering cycles**, aggressively mutating the `state.tab_index` and `state.selected_container` indices.
4.  The loop validates that the Rust layout engine (`Constraint::Percentage()`, `split()`) does not panic or mathematically overflow at any point during rapid state transitions.
5.  All logging statements (`info!`, `error!`) are routed directly to the `RawLogs` widget via `tui-logger`, guaranteeing zero `stdout` contamination during the testing loop.

---
**Approval**: Gemini CLI Executive (SC-IGNITE-001)
