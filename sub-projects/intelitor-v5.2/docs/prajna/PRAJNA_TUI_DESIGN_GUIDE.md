# PRAJNA TUI Design Guide
## Complete UI/UX/CX/DX Reference for C3I Mesh Cockpit

**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: SPECIFICATION
**Compliance**: NASA-STD-3000, MIL-STD-1472H, NUREG-0700, ISA-101, IEC 61508 SIL-2

---

## Document Suite Overview

This document serves as the master guide for the PRAJNA TUI system, integrating:

| Document | Purpose | Lines |
|----------|---------|-------|
| PRAJNA_5LEVEL_SPECIFICATION.md | Overall system architecture | 3000+ |
| PRAJNA_TUI_INFORMATION_ARCHITECTURE.md | Information elements & behaviors | 1448 |
| PRAJNA_TUI_COMPONENT_SYSTEM.md | Component framework & implementation | 1214 |
| **PRAJNA_TUI_DESIGN_GUIDE.md** (this) | UX/CX/DX integration guide | ~800 |

---

## 0. External Inspirations

### 0.1 LVGL XML Declarative Patterns

Inspired by [LVGL Pro XML](https://docs.lvgl.io/master/xml/index.html), PRAJNA TUI adopts:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LVGL-INSPIRED DECLARATIVE PATTERNS                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  COMPONENT HIERARCHY                                                         │
│  ────────────────────                                                        │
│  • Screens: Top-level containers (Dashboard, Mesh, Alarms, etc.)            │
│  • Components: Reusable custom elements (MetricCard, AlarmCard)             │
│  • Widgets: Atomic UI controls (Gauge, Sparkline, StatusDot)                │
│                                                                              │
│  DECLARATIVE UI DEFINITION                                                   │
│  ──────────────────────────                                                  │
│  Instead of procedural widget construction, define structure declaratively: │
│                                                                              │
│  %Screen{                                                                    │
│    id: :dashboard,                                                           │
│    layout: :grid,                                                            │
│    children: [                                                               │
│      %Row{height: 3, children: [%StatusBar{}]},                             │
│      %Row{height: 1, children: [%TabBar{active: :overview}]},               │
│      %Row{fill: true, children: [                                           │
│        %Column{width: "30%", children: [%SafetyPanel{}]},                   │
│        %Column{fill: true, children: [%NodesGrid{}]}                        │
│      ]}                                                                      │
│    ]                                                                         │
│  }                                                                           │
│                                                                              │
│  FLEX & GRID LAYOUT                                                          │
│  ────────────────────                                                        │
│  • Flex: Row/column-based flexible positioning                              │
│  • Grid: Two-dimensional cell-based arrangement                             │
│  • Constraints: Fixed, Percentage, Min, Max, Fill                           │
│                                                                              │
│  STYLE SEPARATION                                                            │
│  ──────────────────                                                          │
│  • Global theme: Dark cockpit palette                                       │
│  • Component styles: Per-widget type defaults                               │
│  • Local overrides: Instance-specific customization                         │
│                                                                              │
│  SUBJECTS (REACTIVE DATA BINDING)                                            │
│  ──────────────────────────────────                                          │
│  • Subjects: Observable data sources                                        │
│  • Auto-update: UI refreshes when subject changes                           │
│  • Example: %MetricCard{value: {:subject, "app-01:cpu"}}                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 0.2 Grafana Faro Observability Patterns

Inspired by [Grafana Faro](https://grafana.com/oss/faro/), PRAJNA TUI adopts:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FARO-INSPIRED OBSERVABILITY PATTERNS                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  THREE-TIER TELEMETRY ARCHITECTURE                                           │
│  ──────────────────────────────────                                          │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐          │
│  │  TUI AGENT      │───▶│  COLLECTOR      │───▶│  VISUALIZATION  │          │
│  │  (Frontend)     │    │  (Backend)      │    │  (TUI/SigNoz)   │          │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘          │
│        │                       │                       │                    │
│        ▼                       ▼                       ▼                    │
│  User interactions      Route to stores         Unified dashboards         │
│  Performance metrics    Correlation             Cross-signal views         │
│  Errors/exceptions      Aggregation             Drill-down                 │
│                                                                              │
│  LGTM SIGNAL CORRELATION                                                     │
│  ─────────────────────────                                                   │
│  • Logs (Loki) ─────────────┐                                               │
│  • Traces (Tempo) ──────────┼──▶ UNIFIED VIEW                               │
│  • Metrics (Mimir/Prom) ────┘                                               │
│                                                                              │
│  TUI applies this via correlated panels:                                    │
│  • Alarm event → Related traces → Error logs → Affected metrics            │
│                                                                              │
│  TELEMETRY SIGNALS CAPTURED                                                  │
│  ────────────────────────────                                                │
│  • Performance: Latency, throughput, error rates                            │
│  • Errors: Exceptions with context                                          │
│  • User activity: Sessions, actions, journeys                               │
│  • Logs: Application state, debug info                                      │
│  • Traces: Distributed request flow                                         │
│                                                                              │
│  CORRELATION VIEWS (Applied to TUI)                                          │
│  ───────────────────────────────────                                         │
│  • Alarm Investigation: Event → Correlated events → Traces → Logs          │
│  • Node Debugging: Metrics → Traces → Errors → Recent changes              │
│  • Incident Timeline: Chronological view of related signals                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 0.3 Integrated Widget Patterns

Combining LVGL declarative approach with Faro observability:

```elixir
# Declarative screen definition with reactive data binding
defmodule Prajna.TUI.Screens.AlarmInvestigation do
  @moduledoc """
  Faro-inspired correlation view for alarm investigation.
  Uses LVGL-style declarative layout.
  """

  use Prajna.TUI.DeclarativeScreen

  def definition do
    screen id: :alarm_investigation do
      row height: 3 do
        component StatusBar
      end

      row fill: true do
        column width: "40%" do
          # Primary alarm details
          component AlarmDetail, bind: {:subject, :selected_alarm}
        end

        column fill: true do
          # Faro-style correlation panels
          tabs do
            tab "Correlated Events" do
              component EventTimeline,
                bind: {:subject, :correlated_events},
                filter: {:alarm_correlation, :selected_alarm}
            end

            tab "Traces" do
              component TraceWaterfall,
                bind: {:subject, :related_traces},
                span_filter: {:alarm_context, :selected_alarm}
            end

            tab "Logs" do
              component LogViewer,
                bind: {:subject, :context_logs},
                time_range: {:around, :selected_alarm, :triggered_at}
            end

            tab "Metrics" do
              component MetricCorrelation,
                bind: {:subject, :related_metrics},
                entities: {:alarm_entities, :selected_alarm}
            end
          end
        end
      end
    end
  end
end
```

---

## 1. Design Philosophy

### 1.1 C3I Cockpit Principles

The PRAJNA TUI follows **Command, Control, Communications, and Intelligence (C3I)** cockpit design principles derived from aviation and control room standards:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         C3I DESIGN HIERARCHY                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LEVEL 1: SITUATIONAL AWARENESS                                              │
│  ─────────────────────────────────                                           │
│  • Single-glance system health (< 3 seconds to assess)                      │
│  • Alarm severity immediately visible                                       │
│  • Trend direction without reading numbers                                  │
│                                                                              │
│  LEVEL 2: OPERATIONAL CONTROL                                                │
│  ──────────────────────────────                                              │
│  • Actions accessible in ≤ 3 keystrokes                                     │
│  • Context-appropriate commands                                             │
│  • Two-step commit for critical operations                                  │
│                                                                              │
│  LEVEL 3: DIAGNOSTIC DEPTH                                                   │
│  ───────────────────────────                                                 │
│  • Drill-down to root cause                                                 │
│  • Timeline reconstruction                                                  │
│  • Correlation visualization                                                │
│                                                                              │
│  LEVEL 4: PREDICTIVE INTELLIGENCE                                            │
│  ──────────────────────────────────                                          │
│  • AI-powered insights (ADVISORY ONLY)                                      │
│  • Trend extrapolation                                                      │
│  • Anomaly detection                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Dark Cockpit Philosophy

**Principle**: Normal operation should be visually quiet. Deviations demand attention.

```
VISUAL PRIORITY LEVELS:

  NORMAL (Background)                    DEVIATION (Foreground)
  ────────────────────                   ──────────────────────
  • Gray/dark blue tones                 • Amber/red/cyan tones
  • Minimal visual weight                • High contrast
  • No animation                         • Motion/pulse for critical
  • Information present but quiet        • Information demands attention
```

### 1.3 Human Factors Compliance

| Standard | Requirement | Implementation |
|----------|-------------|----------------|
| NASA-STD-3000 | 7 ± 2 items in view | Max 7 nodes per row |
| MIL-STD-1472H | Response time feedback | All actions show spinner |
| NUREG-0700 | Alarm acknowledgment | Explicit ACK required |
| ISA-101 | Color coding | Red/Amber/Green severity |
| IEC 61508 | SIL-2 displays | Two-step critical commands |

---

## 2. User Experience (UX) Patterns

### 2.1 Information Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INFORMATION SCANNING PATH                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌───────────────────────────────────────────────────────────────────┐    │
│    │                     1. HEALTH BAR (Top)                           │    │
│    │    First scan: Overall system status in <1 second                │    │
│    └───────────────────────────────────────────────────────────────────┘    │
│                                    ↓                                         │
│    ┌───────────────────────────────────────────────────────────────────┐    │
│    │                   2. ALARM SUMMARY (Left)                         │    │
│    │    Second scan: Count of active issues by severity               │    │
│    └───────────────────────────────────────────────────────────────────┘    │
│                                    ↓                                         │
│    ┌────────────────────────────┐  ┌──────────────────────────────────┐    │
│    │  3. PRIMARY CONTENT        │  │  4. SUPPORTING CONTEXT           │    │
│    │     (Center/Left)          │  │     (Right Panel)                │    │
│    │     Main dashboard area    │  │     AI insights, quick actions  │    │
│    └────────────────────────────┘  └──────────────────────────────────┘    │
│                                    ↓                                         │
│    ┌───────────────────────────────────────────────────────────────────┐    │
│    │                    5. DETAIL/METRICS (Bottom)                     │    │
│    │    Sparklines, trends, secondary information                     │    │
│    └───────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Navigation Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NAVIGATION STRUCTURE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TAB NAVIGATION (Horizontal)                                                 │
│  ────────────────────────────                                                │
│  [1:Overview] [2:Mesh] [3:Alarms] [4:Commands] [5:Copilot] [6:Containers]   │
│                                                                              │
│  • Tab key cycles forward                                                   │
│  • Shift+Tab cycles backward                                                │
│  • Number keys (1-6) jump directly                                          │
│                                                                              │
│  FOCUS NAVIGATION (Within Tab)                                               │
│  ──────────────────────────────                                              │
│  • Arrow keys move focus between cards/items                                │
│  • Enter selects/activates focused item                                     │
│  • Escape cancels/goes back                                                 │
│                                                                              │
│  MODAL NAVIGATION (Overlays)                                                 │
│  ───────────────────────────                                                 │
│  • Modal captures all input until dismissed                                 │
│  • Tab cycles through modal fields                                          │
│  • Enter confirms, Escape cancels                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Interaction Patterns

| Pattern | Use Case | Key Binding | Feedback |
|---------|----------|-------------|----------|
| Select | Choose item from list | Enter | Highlight |
| Acknowledge | Confirm alarm | A | Status change |
| Arm | Prepare critical command | R/I/D | Modal appears |
| Confirm | Execute armed command | Enter + Code | Spinner → Result |
| Cancel | Abort operation | Escape | Modal closes |
| Drill-down | View details | Enter | Screen transition |
| Filter | Reduce list | F then type | Live filter |
| Search | Find item | / then type | Incremental search |

---

## 3. Customer Experience (CX) Considerations

### 3.1 Operator Personas

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PRIMARY PERSONAS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  👤 SECURITY OPERATOR (Primary User)                                         │
│  ───────────────────────────────────                                         │
│  Goals: Monitor alarms, dispatch response, maintain situational awareness  │
│  Context: 24/7 shifts, multiple screens, time pressure                      │
│  Needs: Fast alarm acknowledgment, clear severity, one-click dispatch       │
│                                                                              │
│  👤 SYSTEM ADMINISTRATOR (Technical User)                                    │
│  ─────────────────────────────────────────                                   │
│  Goals: Configure system, troubleshoot issues, optimize performance         │
│  Context: On-call, remote access, diagnostic focus                          │
│  Needs: Deep metrics, container control, log access, shell access           │
│                                                                              │
│  👤 SECURITY MANAGER (Supervisory User)                                      │
│  ──────────────────────────────────────                                      │
│  Goals: Overview reporting, compliance verification, trend analysis         │
│  Context: Periodic review, executive reporting, audit support               │
│  Needs: KPI dashboards, export capabilities, historical views               │
│                                                                              │
│  👤 INTEGRATION ENGINEER (Developer User)                                    │
│  ─────────────────────────────────────────                                   │
│  Goals: Debug integrations, verify data flow, test configurations           │
│  Context: Development environment, API testing, log analysis                │
│  Needs: Trace viewing, request debugging, configuration testing             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Workflow Optimization

**Alarm Response Workflow** (Optimized for < 30 seconds)

```
Step 1: Alarm triggers        → Visual + audible alert
Step 2: Operator sees alarm   → Auto-focused to new alarm
Step 3: Review details        → Inline preview, no navigation
Step 4: Acknowledge           → Single key: A
Step 5: Dispatch (if needed)  → Single key: D → Select team → Enter
Step 6: Verify dispatch       → Real-time status in alarm card
```

**Node Restart Workflow** (Two-Step Commit)

```
Step 1: Navigate to node      → Arrow keys to focus
Step 2: Initiate restart      → R key (ARM)
Step 3: Review modal          → Warning text, countdown visible
Step 4: Enter confirmation    → Type 4-digit code
Step 5: Confirm               → Enter
Step 6: Monitor progress      → Spinner → Success/Failure toast
```

### 3.3 Error Prevention & Recovery

| Error Type | Prevention | Recovery |
|------------|------------|----------|
| Accidental critical action | Two-step commit | Undo within 5s |
| Wrong target selection | Confirm modal shows target | Cancel and retry |
| Timeout during operation | Auto-cancel with message | Retry button |
| Network disconnection | Reconnect indicator | Auto-reconnect |
| Data staleness | Visual decay + warning | Manual refresh |

---

## 4. Developer Experience (DX) Guidelines

### 4.1 Component Development

```elixir
# Standard component structure
defmodule Prajna.TUI.Components.MyComponent do
  @moduledoc """
  Brief description of what this component displays.

  ## Layout
  ```
  ┌─ Title ─────────────┐
  │ Content area        │
  │ with details        │
  └─────────────────────┘
  ```

  ## STAMP Constraints
  - SC-HMI-XXX: Relevant constraint

  ## Examples
      MyComponent.render(%MyComponent{...}, area, buffer)
  """

  use Prajna.TUI.Widget

  # Struct definition with all fields
  defstruct [:field1, :field2, :focused]

  # Type specs
  @type t :: %__MODULE__{
    field1: term(),
    field2: term(),
    focused: boolean()
  }

  # Widget callback implementation
  @impl true
  def render(%__MODULE__{} = component, area, buffer) do
    # 1. Draw border/container
    buffer = draw_border(buffer, area, "Title")

    # 2. Calculate inner area
    inner = shrink(area, 1)

    # 3. Render content
    buffer = put_string(buffer, inner.x, inner.y, "Content")

    # 4. Return updated buffer
    buffer
  end

  # Optional: handle events
  @impl true
  def handle_event(%__MODULE__{} = component, event) do
    case event do
      {:key, ?\r} -> {component, [:select]}
      _ -> {component, []}
    end
  end

  # Optional: minimum size
  @impl true
  def min_size(%__MODULE__{}), do: {20, 4}
end
```

### 4.2 Testing Strategy

```elixir
# Component unit test
defmodule Prajna.TUI.Components.MyComponentTest do
  use ExUnit.Case, async: true

  alias Prajna.TUI.Components.MyComponent
  alias Prajna.TUI.Buffer

  describe "render/3" do
    test "renders border with title" do
      component = %MyComponent{field1: "test"}
      area = %{x: 0, y: 0, width: 20, height: 5}
      buffer = Buffer.new(20, 5)

      result = MyComponent.render(component, area, buffer)

      assert Buffer.get_string(result, 0, 0) =~ "Title"
    end

    test "respects minimum size" do
      component = %MyComponent{}
      assert MyComponent.min_size(component) == {20, 4}
    end
  end

  describe "handle_event/2" do
    test "enter key triggers select command" do
      component = %MyComponent{focused: true}

      {_component, commands} = MyComponent.handle_event(component, {:key, ?\r})

      assert :select in commands
    end
  end
end
```

### 4.3 Style Guide

**Naming Conventions**:
- Components: `PascalCase` (e.g., `MetricCard`, `AlarmCard`)
- Functions: `snake_case` (e.g., `render`, `handle_event`)
- Constants: `SCREAMING_SNAKE_CASE` for module attributes

**Documentation Requirements**:
- Every component must have `@moduledoc` with:
  - ASCII layout diagram
  - STAMP constraint references
  - Usage examples
- Every public function must have `@doc` and `@spec`

**Code Organization**:
```
lib/prajna/tui/
├── widget.ex              # Base behavior
├── buffer.ex              # Buffer operations
├── layout.ex              # Layout system
├── primitives/
│   ├── gauge.ex
│   ├── sparkline.ex
│   └── status_dot.ex
├── components/
│   ├── metric_card.ex
│   ├── alarm_card.ex
│   ├── node_card.ex
│   └── insight_card.ex
├── screens/
│   ├── dashboard.ex
│   ├── mesh.ex
│   └── alarms.ex
└── input.ex               # Keyboard handling
```

---

## 5. Visual Design System

### 5.1 Color System

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COLOR PALETTE                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SEMANTIC COLORS                                                             │
│  ────────────────                                                            │
│  ██ #22C55E  HEALTHY    - Normal operation, success                         │
│  ██ #F59E0B  CAUTION    - Attention needed, threshold approaching           │
│  ██ #FB923C  WARNING    - Action recommended                                │
│  ██ #EF4444  CRITICAL   - Immediate action required                         │
│  ██ #06B6D4  ADVISORY   - Informational, AI insight                         │
│  ██ #3B82F6  INFO       - General information                               │
│  ██ #A855F7  CORRELATION- Related items, links                              │
│                                                                              │
│  NEUTRAL COLORS                                                              │
│  ────────────────                                                            │
│  ██ #111827  BG_DARK    - Primary background                                │
│  ██ #1F2937  BG_SURFACE - Card/panel background                             │
│  ██ #374151  BORDER     - Borders, separators                               │
│  ██ #6B7280  DIM        - Secondary text, disabled                          │
│  ██ #9CA3AF  MUTED      - Placeholder, hint text                            │
│  ██ #D1D5DB  TEXT       - Primary text                                      │
│  ██ #F3F4F6  BRIGHT     - Emphasized text                                   │
│                                                                              │
│  INTERACTION COLORS                                                          │
│  ──────────────────                                                          │
│  ██ #06B6D4  FOCUS      - Focused element border                            │
│  ██ #1E40AF  SELECTED   - Selected element background                       │
│  ██ #374151  HOVER      - Hover state (where applicable)                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Typography

| Element | Style | Example |
|---------|-------|---------|
| Title | Bold, UPPERCASE | `MESH NODES` |
| Heading | Bold | `Active Alarms` |
| Label | Normal | `CPU:` |
| Value | Normal/Bold | `42%` |
| Dim | Dim color | `12 min ago` |
| Code | Monospace | `app-01` |

### 5.3 Spacing & Layout

```
SPACING UNITS:
  xs = 1 character
  sm = 2 characters
  md = 3 characters
  lg = 4 characters
  xl = 6 characters

COMPONENT SPACING:
  • Card padding: sm (2 chars)
  • Card margin: xs (1 char)
  • Section gap: md (3 chars)
  • Screen margin: sm (2 chars)

MINIMUM SIZES:
  • MetricCard: 24w × 4h
  • AlarmCard: 60w × 4h
  • NodeCard: 28w × 5h
  • InsightCard: 60w × 10h
```

---

## 6. Accessibility & Responsiveness

### 6.1 Keyboard Accessibility

All operations must be accessible via keyboard:

| Operation | Key | Context |
|-----------|-----|---------|
| Navigate tabs | 1-9, Tab | Global |
| Move focus | Arrow keys | Within pane |
| Activate/Select | Enter | Focused item |
| Cancel/Back | Escape | Any modal/selection |
| Help | ? | Global |
| Quit | q | Global |
| Command mode | : | Global |
| Filter | f | List views |
| Search | / | Global |

### 6.2 Terminal Size Handling

```
MINIMUM: 80 × 24 (Standard terminal)
  • Single-column layout
  • Abbreviated labels
  • Compact components

STANDARD: 120 × 40
  • Two-column layout
  • Full labels
  • Normal components

LARGE: 160+ × 50+
  • Three-column layout
  • Extended metrics
  • Larger sparklines
```

### 6.3 Color Blindness Support

- Never rely on color alone for meaning
- Always pair color with shape/icon:
  - Healthy: ● (circle)
  - Warning: ⚠ (triangle)
  - Critical: ☢ (radiation)
- Use patterns for graphs when color distinction is unclear

---

## 7. Integration with C3I Cockpit

### 7.1 Screen Mapping

| TUI Screen | Purpose | Primary Actions |
|------------|---------|-----------------|
| Overview | System status at a glance | Monitor |
| Mesh | Node topology | Select, Restart, Logs |
| Alarms | Active alarm management | ACK, Silence, Escalate |
| Commands | Critical operations | Arm, Confirm |
| Copilot | AI insights | Apply, Dismiss |
| Containers | Container health | Restart, Logs, Shell |
| Cluster | Distributed management | Scale, Failover |
| Settings | Configuration | Save, Reset |

### 7.2 PubSub Topics

```elixir
# Real-time update topics
"prajna:metrics"          # Metric updates per node
"prajna:alarms"           # Alarm lifecycle events
"prajna:insights"         # AI Copilot insights
"prajna:container_health" # Container status
"prajna:node_status"      # Mesh node events
"prajna:ooda_cycle"       # OODA loop phase changes
"prajna:commands"         # Command execution status
```

### 7.3 State Synchronization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STATE FLOW                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐      │
│  │   SmartMetrics  │ ──→  │    PubSub       │ ──→  │   TUI Model     │      │
│  │   (Backend)     │      │  (Broadcast)    │      │  (Frontend)     │      │
│  └─────────────────┘      └─────────────────┘      └─────────────────┘      │
│          ↑                                                  │               │
│          │                                                  │               │
│          │              User Actions                        │               │
│          └──────────────────────────────────────────────────┘               │
│                                                                              │
│  Update Frequency:                                                           │
│  • Metrics: 500ms push                                                       │
│  • Alarms: Event-driven                                                      │
│  • Insights: 10s analysis cycle                                              │
│  • Container: 5s polling                                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Quality Checklist

### 8.1 Component Checklist

- [ ] Has `@moduledoc` with ASCII layout
- [ ] References relevant STAMP constraints
- [ ] Implements `Widget` behavior
- [ ] Has `@spec` for all public functions
- [ ] Includes unit tests
- [ ] Respects minimum size requirements
- [ ] Handles focus state
- [ ] Uses semantic colors

### 8.2 Screen Checklist

- [ ] Follows information hierarchy
- [ ] Supports keyboard navigation
- [ ] Shows loading/error states
- [ ] Has help text (? key)
- [ ] Subscribes to relevant PubSub topics
- [ ] Handles staleness visualization
- [ ] Works at minimum terminal size

### 8.3 UX Checklist

- [ ] Single-glance health status
- [ ] Actions within 3 keystrokes
- [ ] Two-step for critical operations
- [ ] Feedback for all actions
- [ ] Clear error messages
- [ ] Undo/cancel available

---

## Appendix: Quick Reference

### Keyboard Shortcuts

```
GLOBAL:
  q     Quit
  ?     Help
  :     Command mode
  1-6   Jump to tab
  Tab   Next tab
  S-Tab Previous tab
  /     Search
  Esc   Cancel/Back

ALARMS:
  a     Acknowledge
  s     Silence (1h)
  e     Escalate
  f     Filter
  Enter View detail

MESH:
  r     Restart node
  l     View logs
  s     Shell into
  h     Health check
  Enter Select node

COMMANDS:
  r     Arm restart
  i     Arm isolate
  d     Arm drain
  Enter Confirm
  Esc   Cancel
```

### Status Icons

```
HEALTH:   ● Healthy  ◐ Degraded  ○ Offline  ☢ Critical
TRENDS:   ↑↑ Rising fast  ↑ Rising  → Stable  ↓ Falling  ↓↓ Falling fast
COMMANDS: ○ Idle  ◎ Armed  ◉ Executing  ✓ Success  ✗ Failed
SEVERITY: ☢ Critical  ⛔ Warning  ⚠ Caution  ℹ Advisory
```

---

**Document Control**
- Author: Claude Opus 4.5
- Framework: SOPv5.11 + STAMP + C3I Dark Cockpit
- Standards: NASA-STD-3000, MIL-STD-1472H, NUREG-0700, ISA-101, IEC 61508 SIL-2
