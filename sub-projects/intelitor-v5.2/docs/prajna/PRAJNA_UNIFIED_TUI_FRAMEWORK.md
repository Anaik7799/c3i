# PRAJNA UNIFIED TUI FRAMEWORK
## Cross-Language Terminal UI Specification for C3I Mesh Cockpit

**Version**: 2.0.0-UNIFIED | **Date**: 2025-12-27 | **Status**: SPECIFICATION
**Languages**: Elixir (Primary) | F# (CEPAF Bridge) | Livebook (Analytics)
**Compliance**: NASA-STD-3000, MIL-STD-1472H, NUREG-0700, ISA-101, IEC 61508 SIL-2, Material 3

---

## Document Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA TUI DOCUMENTATION SUITE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LEVEL 0: UNIFIED FRAMEWORK (This Document)                                  │
│  ──────────────────────────────────────────                                  │
│  Master specification synthesizing all TUI components                        │
│                                                                              │
│  LEVEL 1: ARCHITECTURE DOCUMENTS                                             │
│  ─────────────────────────────────                                           │
│  ├─ PRAJNA_5LEVEL_SPECIFICATION.md      (System architecture)               │
│  ├─ PRAJNA_TUI_INFORMATION_ARCHITECTURE.md (Data models)                    │
│  ├─ PRAJNA_TUI_COMPONENT_SYSTEM.md      (Component library)                 │
│  └─ PRAJNA_TUI_DESIGN_GUIDE.md          (UX/CX/DX patterns)                 │
│                                                                              │
│  LEVEL 2: IMPLEMENTATION GUIDES                                              │
│  ────────────────────────────────                                            │
│  ├─ Elixir TUI Implementation           (Phoenix.LiveView + Ratatui-style) │
│  ├─ F# Dashboard Implementation         (CEPAF observability bridge)       │
│  └─ Livebook Analytics                  (Real-time visualization)          │
│                                                                              │
│  LEVEL 3: SCREEN SPECIFICATIONS                                              │
│  ─────────────────────────────────                                           │
│  ├─ Startup/Shutdown Sequences                                              │
│  ├─ Operational Dashboards                                                  │
│  └─ Domain-Specific Views                                                   │
│                                                                              │
│  LEVEL 4: COMPONENT CATALOG                                                  │
│  ────────────────────────────                                                │
│  ├─ Primitives (Gauge, Sparkline, StatusDot)                               │
│  ├─ Composites (MetricCard, AlarmCard, NodeCard)                           │
│  └─ Layouts (Grid, Flex, Stack)                                            │
│                                                                              │
│  LEVEL 5: VERIFICATION & TESTING                                             │
│  ─────────────────────────────────                                           │
│  ├─ PROMETHEUS Mathematical Verification                                    │
│  ├─ Graph Theory Specifications                                             │
│  └─ STAMP Constraint Validation                                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART I: SYSTEM OVERVIEW

## 1. System Scope & Coverage

### 1.1 Indrajaal Platform Overview

The PRAJNA TUI provides unified cockpit experience for the complete Indrajaal Security Monitoring Platform:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INTELITOR SYSTEM COVERAGE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  BUSINESS DOMAINS (30+)                                                      │
│  ─────────────────────                                                       │
│  Access Control    Alarms           Video           Dispatch                │
│  Visitor Mgmt      Compliance       Analytics       Sites                   │
│  Devices           Fleet            Maintenance     Communication           │
│  Training          Shifts           Environmental   Intelligence            │
│  Guard Tours       Risk Mgmt        Billing         Integration             │
│                                                                              │
│  TECHNICAL INFRASTRUCTURE                                                    │
│  ────────────────────────                                                    │
│  50 Agents         3 Containers     19 Ash Resources                        │
│  2,280+ Endpoints  149+ Demos       242 STAMP Constraints                   │
│                                                                              │
│  CONTAINER STACK                                                             │
│  ────────────────                                                            │
│  indrajaal-app     Phoenix/4000     Elixir Runtime                          │
│  indrajaal-db      PostgreSQL/5433  TimescaleDB                             │
│  indrajaal-obs     SigNoz/8123      OpenTelemetry                           │
│                                                                              │
│  LANGUAGE STACK                                                              │
│  ──────────────                                                              │
│  Elixir            Primary app logic, LiveView dashboards                   │
│  F#                CEPAF infrastructure, observability bridges              │
│  Livebook          Interactive analytics, real-time graphs                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Five-Level Detail Structure

Every aspect of this specification follows a 5-level detail hierarchy:

| Level | Name | Purpose | Audience |
|-------|------|---------|----------|
| L1 | Overview | 30-second understanding | Executives, Managers |
| L2 | Concepts | Key principles and rationale | Architects, Leads |
| L3 | Specifications | Detailed requirements | Developers, Testers |
| L4 | Implementation | Code patterns and examples | Implementers |
| L5 | Verification | Proofs, tests, validation | QA, Safety Engineers |

---

## 2. Cross-Language Architecture

### 2.1 Language Responsibilities

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CROSS-LANGUAGE ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                           ELIXIR LAYER                                  ││
│  │  ─────────────────────────────────────                                  ││
│  │  • Phoenix.LiveView dashboards (primary TUI)                           ││
│  │  • Ratatui-style terminal components                                    ││
│  │  • Real-time PubSub subscriptions                                       ││
│  │  • Elm Architecture (Model-Update-View)                                 ││
│  │  • OODA loop orchestration                                              ││
│  │  • Guardian safety integration                                          ││
│  │                                                                          ││
│  │  Entry Points:                                                          ││
│  │  • /cockpit/* - LiveView TUI routes                                     ││
│  │  • Prajna.TUI.* - Component modules                                     ││
│  │  • Prajna.Dashboard.* - Screen definitions                              ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                              ↕ Port/NIF                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                            F# LAYER (CEPAF)                             ││
│  │  ─────────────────────────────────────────                              ││
│  │  • Infrastructure monitoring dashboards                                 ││
│  │  • Container health visualization                                       ││
│  │  • Fractal logging display                                              ││
│  │  • Zenoh dataflow visualization                                         ││
│  │  • PROMETHEUS verification bridge                                       ││
│  │                                                                          ││
│  │  Entry Points:                                                          ││
│  │  • Cepaf.Dashboard.* - F# TUI modules                                   ││
│  │  • Cepaf.Observability.Fractal.* - Logging viz                          ││
│  │  • Cepaf.Bridge.Server - Elixir communication                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                              ↕ HTTP/WebSocket                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         LIVEBOOK LAYER                                  ││
│  │  ─────────────────────────────────────                                  ││
│  │  • Interactive analytics notebooks                                      ││
│  │  • Real-time streaming graphs (Kino, VegaLite)                         ││
│  │  • Ad-hoc system exploration                                            ││
│  │  • Performance profiling visualization                                  ││
│  │  • STAMP constraint verification                                        ││
│  │                                                                          ││
│  │  Entry Points:                                                          ││
│  │  • livebook/prajna_analytics.livemd                                     ││
│  │  • livebook/system_health.livemd                                        ││
│  │  • livebook/incident_investigation.livemd                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Shared Abstractions

Both Elixir and F# implementations share these core abstractions:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LANGUAGE-AGNOSTIC ABSTRACTIONS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  INFORMATION ELEMENTS (Shared Data Model)                                    │
│  ─────────────────────────────────────────                                   │
│                                                                              │
│  Metric = {                                                                  │
│    id: UUID,                                                                 │
│    name: String,                                                             │
│    value: Float | Int,                                                       │
│    unit: String,                                                             │
│    timestamp: DateTime,                                                      │
│    source: EntityRef,                                                        │
│    trend: Trend,                                                             │
│    staleness: Duration                                                       │
│  }                                                                           │
│                                                                              │
│  Alarm = {                                                                   │
│    id: UUID,                                                                 │
│    severity: Critical | Warning | Caution | Advisory,                       │
│    source: EntityRef,                                                        │
│    message: String,                                                          │
│    triggered_at: DateTime,                                                   │
│    acknowledged: Boolean,                                                    │
│    state: Active | Acked | Silenced | Resolved                              │
│  }                                                                           │
│                                                                              │
│  Entity = {                                                                  │
│    id: UUID,                                                                 │
│    type: Node | Container | Agent | Resource,                               │
│    name: String,                                                             │
│    health: Healthy | Degraded | Critical | Unknown,                         │
│    lifecycle: Starting | Running | Stopping | Stopped,                      │
│    metadata: Map                                                            │
│  }                                                                           │
│                                                                              │
│  WIDGET TRAIT (Shared Behavior)                                              │
│  ──────────────────────────────                                              │
│                                                                              │
│  trait Widget {                                                              │
│    render(area: Rect, buffer: Buffer) -> Buffer                             │
│    handle_event(event: Event) -> (Self, Commands)                           │
│    min_size() -> (Width, Height)                                            │
│  }                                                                           │
│                                                                              │
│  LAYOUT CONSTRAINTS (Shared System)                                          │
│  ───────────────────────────────────                                         │
│                                                                              │
│  Constraint = Fixed(n) | Percentage(p) | Min(n) | Max(n) | Fill             │
│  Direction = Horizontal | Vertical                                          │
│  Layout = { direction, constraints, margin, spacing }                       │
│                                                                              │
│  COLOR PALETTE (Shared Theme)                                                │
│  ────────────────────────────                                                │
│                                                                              │
│  Background:  #111827    Surface:     #1F2937                               │
│  Border:      #374151    Text:        #D1D5DB                               │
│  Healthy:     #22C55E    Caution:     #F59E0B                               │
│  Warning:     #FB923C    Critical:    #EF4444                               │
│  Advisory:    #06B6D4    Info:        #3B82F6                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART II: DESIGN SYSTEM

## 3. Material 3 Integration

### 3.1 Material 3 Principles for TUI

Adapting Material 3 design language for terminal interfaces:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MATERIAL 3 TUI ADAPTATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  M3 PRINCIPLE: DYNAMIC COLOR                                                 │
│  ────────────────────────────                                                │
│  • Terminal: Use semantic color tokens (not arbitrary hex)                  │
│  • Primary: Focus/selection states                                          │
│  • Secondary: Supporting content                                            │
│  • Tertiary: Accent elements                                                │
│  • Error: Critical/warning states                                           │
│  • Surface: Container backgrounds                                           │
│                                                                              │
│  TUI COLOR TOKENS (Dark Theme)                                               │
│  ─────────────────────────────                                               │
│  --md-sys-color-primary:         #06B6D4  (cyan-500)                        │
│  --md-sys-color-on-primary:      #FFFFFF                                    │
│  --md-sys-color-secondary:       #6B7280  (gray-500)                        │
│  --md-sys-color-tertiary:        #A855F7  (purple-500)                      │
│  --md-sys-color-error:           #EF4444  (red-500)                         │
│  --md-sys-color-surface:         #1F2937  (gray-800)                        │
│  --md-sys-color-on-surface:      #D1D5DB  (gray-300)                        │
│  --md-sys-color-background:      #111827  (gray-900)                        │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  M3 PRINCIPLE: ELEVATION                                                     │
│  ────────────────────────                                                    │
│  • Terminal: Use border weight and brightness for depth                     │
│  • Level 0: No border (background)                                          │
│  • Level 1: Single line border (cards)                                      │
│  • Level 2: Double line border (focused)                                    │
│  • Level 3: Bright border (modal/popup)                                     │
│                                                                              │
│  ELEVATION MAPPING                                                           │
│  ──────────────────                                                          │
│  Level 0:  Background, no border                                            │
│  Level 1:  ┌─────────┐  Single gray border                                  │
│            │ Card    │                                                       │
│            └─────────┘                                                       │
│  Level 2:  ┌─────────┐  Single cyan border (focused)                        │
│            │ Focused │                                                       │
│            └─────────┘                                                       │
│  Level 3:  ╔═════════╗  Double border (modal)                               │
│            ║ Modal   ║                                                       │
│            ╚═════════╝                                                       │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  M3 PRINCIPLE: SHAPE                                                         │
│  ────────────────────                                                        │
│  • Terminal: Use Unicode box-drawing for rounded/sharp corners              │
│  • Rounded: ╭ ╮ ╰ ╯ (informational)                                         │
│  • Square: ┌ ┐ └ ┘ (interactive)                                            │
│  • Heavy: ┏ ┓ ┗ ┛ (emphasized)                                              │
│                                                                              │
│  SHAPE TOKENS                                                                │
│  ─────────────                                                               │
│  shape-small:    Single-line corners                                        │
│  shape-medium:   Standard box-drawing                                       │
│  shape-large:    Double-line borders                                        │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  M3 PRINCIPLE: MOTION                                                        │
│  ─────────────────────                                                       │
│  • Terminal: ASCII animation frames                                         │
│  • Spinner: ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏                                            │
│  • Progress: ░ ▒ ▓ █                                                        │
│  • Pulse: Brightness variation (normal → bright → normal)                  │
│                                                                              │
│  MOTION TOKENS                                                               │
│  ──────────────                                                              │
│  duration-short:  100ms  (instant feedback)                                 │
│  duration-medium: 300ms  (transitions)                                      │
│  duration-long:   500ms  (complex animations)                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Material 3 Component Mapping

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    M3 COMPONENT → TUI MAPPING                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  M3 COMPONENT           TUI EQUIVALENT                                       │
│  ─────────────          ──────────────                                       │
│                                                                              │
│  Card                   ┌─ Title ───────────────┐                           │
│                         │ Content area          │                           │
│                         └───────────────────────┘                           │
│                                                                              │
│  Button (Filled)        [▓▓ ACTION ▓▓]                                      │
│  Button (Outlined)      [ ACTION ]                                          │
│  Button (Text)          ACTION                                              │
│                                                                              │
│  Chip                   [● Label] or [Label ×]                              │
│                                                                              │
│  Badge                  (3) or ⚠                                            │
│                                                                              │
│  Progress (Linear)      [████████████░░░░░░░░] 60%                          │
│  Progress (Circular)    ◐ (partial) or ⟳ (spinning)                         │
│                                                                              │
│  Switch                 [●───] ON  or [───○] OFF                            │
│                                                                              │
│  TextField              Label: [________________]                            │
│                                                                              │
│  Select/Dropdown        [Selected Item ▼]                                   │
│                                                                              │
│  Dialog                 ╔════════════════════════╗                          │
│                         ║ Title                  ║                          │
│                         ╟────────────────────────╢                          │
│                         ║ Content                ║                          │
│                         ╟────────────────────────╢                          │
│                         ║ [Cancel]     [Confirm] ║                          │
│                         ╚════════════════════════╝                          │
│                                                                              │
│  Snackbar               ┌──────────────────────────────────────┐            │
│                         │ ✓ Message text              [UNDO]  │            │
│                         └──────────────────────────────────────┘            │
│                                                                              │
│  Tabs                   [●Tab1] [Tab2] [Tab3]                               │
│                                                                              │
│  NavigationRail         │ ◆ │                                               │
│  (Vertical)             │ ○ │                                               │
│                         │ ○ │                                               │
│                                                                              │
│  List Item              ├─ ● Icon  Primary text                             │
│                         │         Secondary text                            │
│                                                                              │
│  Divider                ────────────────────────────                        │
│                                                                              │
│  FAB (Floating)         [+] (positioned in corner)                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Unified Component Library

### 4.1 Primitive Components

#### 4.1.1 StatusIndicator (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: StatusIndicator                                                  │
│  ────────────────────────────                                                │
│                                                                              │
│  PURPOSE: Display entity health/state as single character with color        │
│                                                                              │
│  VARIANTS:                                                                   │
│  ● HEALTHY   (green)     Normal operation                                   │
│  ◐ DEGRADED  (amber)     Partial functionality                              │
│  ○ OFFLINE   (gray)      Disconnected/unknown                               │
│  ☢ CRITICAL  (red+pulse) Immediate action required                          │
│  ◎ ARMED     (amber)     Command pending confirmation                       │
│  ⊙ FOCUSED   (cyan)      Currently selected                                 │
│                                                                              │
│  STALENESS OVERLAY:                                                          │
│  Fresh (0-5s):    Full brightness                                           │
│  Recent (5-15s):  80% brightness                                            │
│  Aging (15-30s):  60% brightness                                            │
│  Stale (30-60s):  40% brightness + ⚠                                        │
│  Expired (>60s):  20% brightness + ⚠⚠                                       │
│                                                                              │
│  L4: ELIXIR IMPLEMENTATION                                                   │
│  ─────────────────────────                                                   │
│  defmodule Prajna.TUI.Primitives.StatusIndicator do                         │
│    use Prajna.TUI.Widget                                                     │
│    @spec render(status, staleness, area, buffer) :: buffer                  │
│  end                                                                         │
│                                                                              │
│  L4: F# IMPLEMENTATION                                                       │
│  ─────────────────────                                                       │
│  module Cepaf.Dashboard.StatusIndicator =                                   │
│    let render status staleness (area: Rect) (buffer: Buffer) =              │
│      // Implementation                                                       │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-HMI-001: Color-coded by state                                           │
│  SC-HMI-004: Staleness decay visible                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.1.2 TrendArrow (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: TrendArrow                                                       │
│  ─────────────────────                                                       │
│                                                                              │
│  PURPOSE: Display metric trend direction and velocity                        │
│                                                                              │
│  VARIANTS:                                                                   │
│  ↑↑ RISING_FAST   (red)    >20%/min increase                                │
│  ↑  RISING        (amber)  5-20%/min increase                               │
│  →  STABLE        (gray)   ±5%/min                                          │
│  ↓  FALLING       (green)  5-20%/min decrease                               │
│  ↓↓ FALLING_FAST  (green)  >20%/min decrease                                │
│  ⚡ OSCILLATING   (amber)  Rapid sign changes                               │
│                                                                              │
│  ALGORITHM:                                                                  │
│  trend = Σ(Δvalue[i] × weight[i]) / Σweight[i]  (weighted moving average)  │
│  velocity = |trend| / time_window                                           │
│                                                                              │
│  L5: VERIFICATION                                                            │
│  ─────────────────                                                           │
│  ∀ metric m, trend(m) ∈ {↑↑, ↑, →, ↓, ↓↓, ⚡}                               │
│  SC-HMI-002: Trend always visible with metric value                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.1.3 Gauge (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: Gauge                                                            │
│  ────────────────                                                            │
│                                                                              │
│  PURPOSE: Horizontal progress bar with threshold zones                       │
│                                                                              │
│  VISUAL:                                                                     │
│  [████████████████████░░░░░░░░░░] 68%                                       │
│   0%        50%        80%  90%  100%                                       │
│            Normal    Caution Warning                                        │
│                                                                              │
│  THRESHOLD ZONES:                                                            │
│  0-50%:    Normal (gray fill)                                               │
│  50-80%:   Elevated (blue fill)                                             │
│  80-90%:   Caution (amber fill)                                             │
│  90-100%:  Warning (red fill)                                               │
│                                                                              │
│  PROPERTIES:                                                                 │
│  - value: current value                                                      │
│  - max: maximum value                                                        │
│  - thresholds: {caution: 50, warning: 80, critical: 90}                     │
│  - show_percentage: boolean                                                  │
│  - show_markers: boolean                                                     │
│                                                                              │
│  L4: ELIXIR                                                                  │
│  ────────────                                                                │
│  %Gauge{value: 68, max: 100, thresholds: %{caution: 50, warning: 80}}       │
│                                                                              │
│  L4: F#                                                                      │
│  ───────                                                                     │
│  { Value = 68; Max = 100; Thresholds = {Caution=50; Warning=80} }           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.1.4 Sparkline (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: Sparkline                                                        │
│  ───────────────────                                                         │
│                                                                              │
│  PURPOSE: Compact time-series visualization in single row                    │
│                                                                              │
│  VISUAL:                                                                     │
│  ▁▂▃▄▅▆▇█▇▆▅▄▃▄▅▆▇█▇▆  (20 samples)                                        │
│                                                                              │
│  CHARACTER SET (8 levels):                                                   │
│  ▁ = 1/8,  ▂ = 2/8,  ▃ = 3/8,  ▄ = 4/8                                     │
│  ▅ = 5/8,  ▆ = 6/8,  ▇ = 7/8,  █ = 8/8                                     │
│                                                                              │
│  HIGH-RESOLUTION (Braille, 4 levels per char):                               │
│  ⣀⣤⣶⣿⡿⠿⠛⠋  (for 2x resolution)                                            │
│                                                                              │
│  NORMALIZATION:                                                              │
│  level = round((value - min) / (max - min) × 7)                             │
│  clamp(level, 0, 7)                                                         │
│                                                                              │
│  PROPERTIES:                                                                 │
│  - data: list of numeric values                                              │
│  - width: number of characters                                               │
│  - min/max: optional fixed range                                             │
│  - color: fill color                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Composite Components

#### 4.2.1 MetricCard (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: MetricCard                                                       │
│  ─────────────────────                                                       │
│                                                                              │
│  PURPOSE: Display single metric with value, trend, history, and gauge        │
│                                                                              │
│  LAYOUT (28w × 4h):                                                          │
│  ┌─ CPU Usage ─────────────────┐                                            │
│  │ 42% ↑   ▁▂▃▄▅▆▅▄▃▄▅▆▇█▇▆   │  Row 1: Value + Trend + Sparkline          │
│  │ [████████████░░░░░] Caution │  Row 2: Gauge + Status                      │
│  │ ●──────────────────────── 5s│  Row 3: Freshness indicator                │
│  └─────────────────────────────┘                                            │
│                                                                              │
│  COMPOSITION:                                                                │
│  - Border with title                                                         │
│  - Value display with unit                                                   │
│  - TrendArrow                                                                │
│  - Sparkline (last N samples)                                               │
│  - Gauge with thresholds                                                     │
│  - StatusIndicator with staleness                                           │
│                                                                              │
│  PROPERTIES:                                                                 │
│  - name: string                                                              │
│  - value: number                                                             │
│  - unit: string (%, ms, MB, etc.)                                           │
│  - trend: trend enum                                                         │
│  - history: list of values                                                   │
│  - thresholds: threshold config                                              │
│  - last_update: timestamp                                                    │
│                                                                              │
│  L4: ELIXIR                                                                  │
│  ────────────                                                                │
│  defmodule Prajna.TUI.Components.MetricCard do                              │
│    use Prajna.TUI.Widget                                                     │
│    alias Prajna.TUI.Primitives.{Gauge, Sparkline, TrendArrow}               │
│                                                                              │
│    defstruct [:name, :value, :unit, :trend, :history,                       │
│               :thresholds, :last_update]                                     │
│                                                                              │
│    @impl true                                                                │
│    def render(%__MODULE__{} = card, area, buffer) do                        │
│      buffer                                                                  │
│      |> draw_border(area, card.name)                                        │
│      |> render_value_row(card, shrink(area, 1))                             │
│      |> render_gauge_row(card, shrink(area, 1))                             │
│      |> render_freshness_row(card, shrink(area, 1))                         │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  L4: F#                                                                      │
│  ───────                                                                     │
│  type MetricCard = {                                                         │
│    Name: string                                                              │
│    Value: float                                                              │
│    Unit: string                                                              │
│    Trend: Trend                                                              │
│    History: float list                                                       │
│    Thresholds: ThresholdConfig                                              │
│    LastUpdate: DateTime                                                      │
│  }                                                                           │
│                                                                              │
│  module MetricCard =                                                         │
│    let render (card: MetricCard) (area: Rect) (buffer: Buffer) =            │
│      buffer                                                                  │
│      |> drawBorder area card.Name                                           │
│      |> renderValueRow card (shrink area 1)                                 │
│      |> renderGaugeRow card (shrink area 1)                                 │
│      |> renderFreshnessRow card (shrink area 1)                             │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-HMI-001: Dark cockpit colors                                            │
│  SC-HMI-002: Trend always visible                                           │
│  SC-HMI-004: Staleness decay                                                │
│  SC-INFO-001: Timestamp and source included                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.2.2 AlarmCard (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: AlarmCard                                                        │
│  ────────────────────                                                        │
│                                                                              │
│  PURPOSE: Display alarm with severity, source, message, and actions          │
│                                                                              │
│  LAYOUT (60w × 4h):                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ ⚠ CAUTION │ app-03 │ CPU trending high (45% ↑↑)                  │ Row 1 │
│  │   Age: 12 min │ Occurrences: 3 │ Source: SmartMetrics            │ Row 2 │
│  │   [ACK] [SILENCE 1h] [ESCALATE] [VIEW NODE]                      │ Row 3 │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                              │
│  SEVERITY ICONS:                                                             │
│  ☢ CRITICAL  (red, pulsing)                                                 │
│  ⛔ WARNING   (orange)                                                       │
│  ⚠ CAUTION   (amber)                                                        │
│  ℹ ADVISORY  (cyan)                                                         │
│                                                                              │
│  ACTIONS:                                                                    │
│  - ACK: Acknowledge alarm (A key)                                           │
│  - SILENCE: Suppress for duration (S key)                                   │
│  - ESCALATE: Increase severity (E key)                                      │
│  - VIEW: Navigate to source entity (Enter key)                              │
│                                                                              │
│  STATES:                                                                     │
│  - Active: Awaiting acknowledgment                                          │
│  - Acknowledged: Operator aware                                             │
│  - Silenced: Temporarily suppressed                                         │
│  - Resolved: Condition cleared                                              │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-HMI-001: Severity color-coded (ISA-101)                                 │
│  SC-INFO-002: Severity classification required                              │
│  NUREG-0700: Explicit acknowledgment                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 4.2.3 NodeCard (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: NodeCard                                                         │
│  ───────────────────                                                         │
│                                                                              │
│  PURPOSE: Display mesh node with health, metrics, and quick actions          │
│                                                                              │
│  LAYOUT (30w × 5h):                                                          │
│  ┌─ ★ app-01 ─────────────────────┐                                         │
│  │ ● HEALTHY    CPU: 42% ↑        │  Row 1: Health + CPU                    │
│  │              MEM: 68% →        │  Row 2: Memory                          │
│  │ Uptime: 25d  Lat: 12ms         │  Row 3: Uptime + Latency                │
│  │ [RESTART] [LOGS] [SHELL]       │  Row 4: Actions                         │
│  └────────────────────────────────┘                                         │
│                                                                              │
│  ROLE ICONS:                                                                 │
│  ★ SUPERVISOR  (Leader node)                                                │
│  ◆ CONTROLLER  (Domain controller)                                          │
│  ● WORKER      (Processing node)                                            │
│  ◇ GATEWAY     (Edge node)                                                  │
│                                                                              │
│  ACTIONS (Two-Step for critical):                                            │
│  - RESTART: Graceful restart (R key) → Arm → Confirm                        │
│  - LOGS: View container logs (L key)                                        │
│  - SHELL: Interactive shell (S key)                                         │
│  - ISOLATE: Network isolation (I key) → Arm → Confirm                       │
│  - DRAIN: Connection drain (D key) → Arm → Confirm                          │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-HMI-003: Two-step commit for RESTART/ISOLATE/DRAIN                      │
│  SC-INFO-003: Lifecycle state visible                                       │
│  NASA-STD-3000: ≤7 items visible                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART III: SCREEN SPECIFICATIONS

## 5. Lifecycle Screens

### 5.1 Startup Sequence Screen (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCREEN: StartupSequence                                                     │
│  ──────────────────────────                                                  │
│                                                                              │
│  PURPOSE: Visualize system initialization progress across all subsystems     │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  ██████╗ ██████╗  █████╗      ██╗███╗   ██╗ █████╗                      ││
│  │  ██╔══██╗██╔══██╗██╔══██╗     ██║████╗  ██║██╔══██╗                     ││
│  │  ██████╔╝██████╔╝███████║     ██║██╔██╗ ██║███████║                     ││
│  │  ██╔═══╝ ██╔══██╗██╔══██║██   ██║██║╚██╗██║██╔══██║                     ││
│  │  ██║     ██║  ██║██║  ██║╚█████╔╝██║ ╚████║██║  ██║                     ││
│  │  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝ ╚════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝                     ││
│  │                  C3I MESH COCKPIT v2.0.0                                 ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  PHASE 1: INFRASTRUCTURE                           [████████░░] 80%     ││
│  │  ├─ ✓ Telemetry System initialized                                      ││
│  │  ├─ ✓ Database connection established (PostgreSQL 17)                   ││
│  │  ├─ ✓ PubSub started (Phoenix.PubSub)                                   ││
│  │  ├─ ● Redis cache connecting...                                         ││
│  │  └─ ○ Oban background jobs (pending)                                    ││
│  │                                                                          ││
│  │  PHASE 2: SAFETY SYSTEMS                           [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ Guardian (Simplex gatekeeper)                                     ││
│  │  ├─ ○ Dead Man's Switch (heartbeat)                                     ││
│  │  ├─ ○ Envelope constraints (safety bounds)                              ││
│  │  └─ ○ Sentinel (quorum monitor)                                         ││
│  │                                                                          ││
│  │  PHASE 3: DISTRIBUTED SYSTEMS                      [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ Cluster formation (Tailscale DNS)                                 ││
│  │  ├─ ○ FLAME pools (Intelligence, Video, Analytics)                     ││
│  │  ├─ ○ OODA loop activation                                              ││
│  │  └─ ○ Zenoh coordination                                                ││
│  │                                                                          ││
│  │  PHASE 4: AGENT ARCHITECTURE                       [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ Executive agent (1)                                               ││
│  │  ├─ ○ Domain agents (10)                                                ││
│  │  ├─ ○ Functional agents (15)                                            ││
│  │  └─ ○ Worker agents (24)                                                ││
│  │                                                                          ││
│  │  PHASE 5: CONTAINER ORCHESTRATION                  [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ indrajaal-app (Phoenix)                                           ││
│  │  ├─ ○ indrajaal-db (PostgreSQL)                                         ││
│  │  └─ ○ indrajaal-obs (SigNoz)                                            ││
│  │                                                                          ││
│  │  ┌────────────────────────────────────────────────────────────────────┐ ││
│  │  │  STARTUP LOG (live)                                                 │ ││
│  │  │  [12:34:56.123] Starting IndrajaalWeb.Telemetry...                  │ ││
│  │  │  [12:34:56.234] Ecto repo connected to PostgreSQL 17                │ ││
│  │  │  [12:34:56.345] Phoenix.PubSub started                              │ ││
│  │  │  [12:34:56.456] Connecting to Redis...                              │ ││
│  │  └────────────────────────────────────────────────────────────────────┘ ││
│  │                                                                          ││
│  │  Estimated time remaining: 45 seconds                                   ││
│  │  [ABORT STARTUP]                                        [SKIP TO COCKPIT]││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  PHASES:                                                                     │
│  1. Infrastructure: DB, PubSub, Cache, Background Jobs                      │
│  2. Safety: Guardian, DMS, Envelope, Sentinel                               │
│  3. Distributed: Cluster, FLAME, OODA, Zenoh                                │
│  4. Agents: Executive → Domain → Functional → Workers                       │
│  5. Containers: App → DB → Obs                                              │
│                                                                              │
│  STATE TRANSITIONS:                                                          │
│  ○ Pending → ● In Progress → ✓ Complete → ✗ Failed                         │
│                                                                              │
│  CONTROLS:                                                                   │
│  - ABORT: Cancel startup, safe shutdown                                     │
│  - SKIP: Jump to cockpit (partial initialization warning)                   │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-EMR-057: Abort completes <5s                                            │
│  SC-AGT-017: Agent initialization sequenced                                 │
│  SC-CNT-009: Container dependency ordering                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Shutdown Sequence Screen (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCREEN: ShutdownSequence                                                    │
│  ────────────────────────                                                    │
│                                                                              │
│  PURPOSE: Graceful system shutdown with state preservation                   │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  ⚠ SYSTEM SHUTDOWN INITIATED                                            ││
│  │                                                                          ││
│  │  Initiated by: operator@indrajaal.local                                 ││
│  │  Started at: 2025-12-27 18:00:00 CET                                    ││
│  │  Mode: GRACEFUL (30s drain timeout)                                     ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  PHASE 1: CONNECTION DRAINING                      [████████░░] 80%     ││
│  │  ├─ ✓ New connections blocked                                           ││
│  │  ├─ ✓ WebSocket clients notified (45 clients)                           ││
│  │  ├─ ● Active requests draining (12 remaining)                           ││
│  │  └─ ○ Phoenix endpoint shutdown (pending)                               ││
│  │                                                                          ││
│  │  PHASE 2: BACKGROUND JOBS                          [███░░░░░░░] 30%     ││
│  │  ├─ ✓ Oban job queue paused                                             ││
│  │  ├─ ● In-flight jobs completing (3 remaining)                           ││
│  │  └─ ○ Job state persisted (pending)                                     ││
│  │                                                                          ││
│  │  PHASE 3: STATE PRESERVATION                       [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ Cockpit state snapshot                                            ││
│  │  ├─ ○ Metric history exported                                           ││
│  │  ├─ ○ Command audit log finalized                                       ││
│  │  └─ ○ CubDB state synced                                                ││
│  │                                                                          ││
│  │  PHASE 4: DISTRIBUTED TEARDOWN                     [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ FLAME pools drained                                               ││
│  │  ├─ ○ Cluster membership released                                       ││
│  │  ├─ ○ Zenoh subscriptions closed                                        ││
│  │  └─ ○ Tailscale node deregistered                                       ││
│  │                                                                          ││
│  │  PHASE 5: CONTAINER SHUTDOWN                       [░░░░░░░░░░]  0%     ││
│  │  ├─ ○ indrajaal-app stopped                                             ││
│  │  ├─ ○ indrajaal-obs stopped                                             ││
│  │  └─ ○ indrajaal-db stopped (last)                                       ││
│  │                                                                          ││
│  │  ┌────────────────────────────────────────────────────────────────────┐ ││
│  │  │  SHUTDOWN LOG                                                       │ ││
│  │  │  [18:00:00.123] Initiating graceful shutdown...                     │ ││
│  │  │  [18:00:00.234] Blocking new connections                            │ ││
│  │  │  [18:00:00.456] Notifying 45 WebSocket clients                      │ ││
│  │  │  [18:00:01.789] Draining 15 active requests...                      │ ││
│  │  └────────────────────────────────────────────────────────────────────┘ ││
│  │                                                                          ││
│  │  Estimated time remaining: 45 seconds                                   ││
│  │  [⛔ FORCE IMMEDIATE SHUTDOWN]                        [ABORT SHUTDOWN]  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  SHUTDOWN MODES:                                                             │
│  • GRACEFUL: Full drain, state preservation (default)                       │
│  • IMMEDIATE: Skip drain, minimal state save                                │
│  • EMERGENCY: Instant termination (data loss possible)                      │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-EMR-057: Stop <5s on FORCE                                              │
│  SC-EMR-060: Rollback capability preserved                                  │
│  SC-OBS-069: Logs persisted before shutdown                                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Operational Dashboards

### 6.1 Main Dashboard (Overview)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCREEN: MainDashboard                                                       │
│  ─────────────────────                                                       │
│                                                                              │
│  PURPOSE: Primary operational view - single glance system status             │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─ PRAJNA C3I MESH COCKPIT ───────────────────────────────────────────────┐│
│  │ ● HEALTHY │ Score: 94% │ Uptime: 25d 14h │ Nodes: 5/5 │ 2025-12-27 14:32││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │ [●Overview] [Mesh] [Alarms] [Commands] [Copilot] [Containers] [Settings]││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  ┌─ SAFETY STATUS ─────────────────────────────────────────────────────┐││
│  │  │ Guardian: ● ACTIVE    DMS: ● HEALTHY    Envelope: ● OK    Sentinel: 3/3│
│  │  │ Violations: 0         Heartbeats: 4,285  Utilization: 72%  Quorum: ✓ ││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  ┌─ MESH NODES (5) ────────────────┐ ┌─ AI COPILOT ───────────────────┐ ││
│  │  │ app-01  CPU: 42% ↑  MEM: 68% → ✓│ │ ● System Status: HEALTHY       │ ││
│  │  │ app-02  CPU: 38% →  MEM: 71% ↑ ✓│ │   Confidence: 0.95             │ ││
│  │  │ app-03  CPU: 45% ↑↑ MEM: 65% ↓ ⚠│ │                                │ ││
│  │  │ app-04  CPU: 31% ↓  MEM: 59% → ✓│ │ ⚠ Prediction: Disk cleanup     │ ││
│  │  │ app-05  CPU: 28% →  MEM: 62% → ✓│ │   in 3 days (conf: 0.78)       │ ││
│  │  │                                  │ │                                │ ││
│  │  │ [View Topology]                  │ │ [View All Insights]            │ ││
│  │  └──────────────────────────────────┘ └────────────────────────────────┘ ││
│  │                                                                          ││
│  │  ┌─ ACTIVE ALARMS (2) ──────────────────────────────────────────────────┐││
│  │  │ ⚠ app-03: CPU trending high (45% ↑↑)              12 min ago  [ACK] │││
│  │  │ ℹ obs: SigNoz trace latency elevated              45 min ago  [ACK] │││
│  │  │                                                                       │││
│  │  │ [View Alarm Center]                                                   │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  ┌─ CONTAINERS ──────────────┐ ┌─ OODA CYCLE ───────────────────────────┐││
│  │  │ APP  ● 4000  [████░] 42%  │ │ Phase: ORIENT ⟳  Cycle: 0.82s (< 1s ✓)│││
│  │  │ DB   ● 5433  [███░░] 31%  │ │ Quality: 98% ✓   Confidence: 85% ✓    │││
│  │  │ OBS  ⚠ 8123  [██░░░] 22%  │ │ Anomalies: 0     Actions Pending: 1   │││
│  │  └───────────────────────────┘ └─────────────────────────────────────────┘││
│  │                                                                          ││
│  │  ┌─ QUICK METRICS SPARKLINES ────────────────────────────────────────────┐│
│  │  │ CPU  ▂▃▄▅▄▃▂▃▄▅▆▅▄▃▄▅▆▇▆▅  avg: 38%                                 ││
│  │  │ MEM  ▅▅▅▅▅▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆  avg: 65%                                 ││
│  │  │ LAT  ▁▁▁▂▁▁▁▁▂▃▂▁▁▁▁▂▁▁▁▁  avg: 12ms                                ││
│  │  └───────────────────────────────────────────────────────────────────────┘│
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  INFORMATION HIERARCHY (C3I):                                                │
│  1. Health bar: <1s assessment                                               │
│  2. Safety status: Critical systems                                          │
│  3. Mesh nodes: Resource overview                                            │
│  4. AI Copilot: Predictive insights                                         │
│  5. Active alarms: Items requiring attention                                 │
│  6. Containers: Infrastructure health                                        │
│  7. OODA cycle: Control loop status                                          │
│  8. Quick metrics: Trend sparklines                                          │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  NASA-STD-3000: <3s to assess system health                                  │
│  SC-HMI-001: Dark cockpit (normal nearly invisible)                          │
│  SC-HMI-002: Trends visible with all metrics                                 │
│  SC-HMI-005: AI marked "ADVISORY ONLY"                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Alarm Center (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCREEN: AlarmCenter                                                         │
│  ───────────────────                                                         │
│                                                                              │
│  PURPOSE: Comprehensive alarm management and investigation                   │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─ ALARM CENTER ──────────────────────────────────────────────────────────┐│
│  │ [Overview] [Mesh] [●Alarms] [Commands] [Copilot] [Containers] [Settings]││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  ┌─ ALARM SUMMARY ──────────────────────────────────────────────────────┐││
│  │  │ ☢ Critical: 0  ⛔ Warning: 0  ⚠ Caution: 2  ℹ Advisory: 5  Total: 7  │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  Filter: [All ▼] [Active ▼] [Last 24h ▼]  Search: [________________] 🔍 ││
│  │                                                                          ││
│  │  ┌─ ACTIVE ALARMS ──────────────────────────────────────────────────────┐││
│  │  │                                                                       │││
│  │  │  ⚠ CAUTION │ app-03 │ CPU trending high (45% ↑↑)                     │││
│  │  │    Age: 12 min │ Occurrences: 3 │ Source: SmartMetrics               │││
│  │  │    AI Insight: Consider load balancing to app-04 (31% CPU)           │││
│  │  │    [ACK] [SILENCE 1h] [ESCALATE] [VIEW NODE]                         │││
│  │  │  ──────────────────────────────────────────────────────────────────  │││
│  │  │                                                                       │││
│  │  │  ⚠ CAUTION │ app-01 │ Memory approaching threshold (68% ↑)          │││
│  │  │    Age: 28 min │ Occurrences: 1 │ Source: SmartMetrics               │││
│  │  │    AI Insight: Normal growth pattern, monitor for next 30 min        │││
│  │  │    [ACK] [SILENCE 1h] [ESCALATE] [VIEW NODE]                         │││
│  │  │                                                                       │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  ┌─ ALARM TRENDS (24h) ──────────────────────────────────────────────────┐│
│  │  │      ☢ ⛔ ⚠ ℹ                                                         ││
│  │  │  6 ─┤                                                                 ││
│  │  │  4 ─┤     ██                                                          ││
│  │  │  2 ─┤  ██ ██ ██    ██          ██                                     ││
│  │  │  0 ─┼──██─██─██────██──────────██─────────────────────────────        ││
│  │  │     00  04  08  12  16  20  24                                        ││
│  │  └───────────────────────────────────────────────────────────────────────┘│
│  │                                                                          ││
│  │  [ACK ALL ADVISORY] [EXPORT REPORT] [CONFIGURE THRESHOLDS]              ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  KEYBOARD SHORTCUTS:                                                         │
│  a - Acknowledge focused alarm                                               │
│  s - Silence for 1 hour                                                      │
│  e - Escalate severity                                                       │
│  f - Open filter panel                                                       │
│  / - Search alarms                                                           │
│  Enter - View alarm details                                                  │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  NUREG-0700: Alarm requires explicit acknowledgment                          │
│  SC-INFO-002: Severity classification for all alarms                         │
│  SC-BEH-002: Threshold breach generates alarm <100ms                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Command Center (Two-Step Commit)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SCREEN: CommandCenter                                                       │
│  ─────────────────────                                                       │
│                                                                              │
│  PURPOSE: Two-step commit operations for critical commands                   │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─ COMMAND CENTER ────────────────────────────────────────────────────────┐│
│  │ [Overview] [Mesh] [Alarms] [●Commands] [Copilot] [Containers] [Settings]││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  ┌─ ARMED COMMAND ◎ ────────────────────────────────────────────────────┐││
│  │  │                                                                       │││
│  │  │  ⚠ RESTART PENDING CONFIRMATION                                      │││
│  │  │                                                                       │││
│  │  │  Target: app-03                                                       │││
│  │  │  Command: RESTART (graceful)                                          │││
│  │  │  Armed by: operator@indrajaal.local                                   │││
│  │  │  Armed at: 2025-12-27 14:32:15                                        │││
│  │  │  Expires in: 4:32                                                     │││
│  │  │                                                                       │││
│  │  │  ┌──────────────────────────────────────────────────────────────────┐│││
│  │  │  │  This is a CRITICAL command requiring two-step confirmation.    ││││
│  │  │  │  The node will be restarted, causing temporary unavailability.  ││││
│  │  │  │  Active connections will be drained (30s timeout).              ││││
│  │  │  └──────────────────────────────────────────────────────────────────┘│││
│  │  │                                                                       │││
│  │  │  Enter confirmation code: [____]                                      │││
│  │  │                                                                       │││
│  │  │  [CONFIRM RESTART]                               [CANCEL]            │││
│  │  │                                                                       │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  ┌─ AVAILABLE COMMANDS ─────────────────────────────────────────────────┐││
│  │  │                                                                       │││
│  │  │  Select Target: [app-03 ▼]                                           │││
│  │  │                                                                       │││
│  │  │  CRITICAL (Two-Step):                                                 │││
│  │  │  [⛔ POWER OFF] [⛔ RESTART] [⛔ ISOLATE] [⛔ HIBERNATE] [⛔ SHUTDOWN] │││
│  │  │                                                                       │││
│  │  │  STANDARD (Immediate):                                                │││
│  │  │  [POWER ON] [HEALTH CHECK] [CLEAR ALARMS] [RESUME NETWORK]           │││
│  │  │                                                                       │││
│  │  │  SCALING:                                                             │││
│  │  │  [SCALE FLAME +] [SCALE FLAME -] [SET LOAD BALANCER]                 │││
│  │  │                                                                       │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  ┌─ COMMAND HISTORY (Last 10) ──────────────────────────────────────────┐││
│  │  │ ✓ 14:28:45 │ app-02 │ HEALTH_CHECK │ Success │ 1.2s                  │││
│  │  │ ✓ 14:15:22 │ app-01 │ CLEAR_ALARMS │ Success │ 0.3s                  │││
│  │  │ ✓ 13:45:00 │ app-05 │ RESTART      │ Success │ 45.2s                 │││
│  │  │ ✗ 12:30:15 │ app-03 │ ISOLATE      │ Cancelled │ - (Guardian denied)│││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  TWO-STEP COMMIT FLOW:                                                       │
│  1. Select target and command                                                │
│  2. Click command → ARMED state (60s timeout)                               │
│  3. Enter 4-digit confirmation code                                          │
│  4. Click CONFIRM → Execute                                                  │
│  5. View result in history                                                   │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-HMI-003: Two-step commit for all critical operations                     │
│  SC-BEH-004: Commands require Guardian approval                              │
│  IEC 61508: SIL-2 displays for safety-critical actions                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART IV: DATA FLOW & CONTROL

## 7. Telemetry & Observability Integration

### 7.1 Fractal Logging Display (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: FractalLogViewer                                                 │
│  ───────────────────────────                                                 │
│                                                                              │
│  PURPOSE: Display 5-level fractal logging hierarchy from CEPAF               │
│                                                                              │
│  FRACTAL LEVELS:                                                             │
│  L0 (SPINE):    System-wide critical events (rare, high priority)           │
│  L1 (THORAX):   Major domain transitions (important milestones)             │
│  L2 (SEGMENT):  Significant operations (normal operations)                  │
│  L3 (FIBER):    Detailed debugging (verbose mode only)                      │
│  L4 (GOSSAMER): Ultra-fine tracing (development only)                       │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─ FRACTAL LOG VIEWER ────────────────────────────────────────────────────┐│
│  │ Level: [L0-L2 ▼]  Filter: [____________]  [● LIVE TAIL]                 ││
│  ├─────────────────────────────────────────────────────────────────────────┤│
│  │                                                                          ││
│  │  L0 █ 14:32:45.123 [SPINE] Guardian approved: RESTART app-03           ││
│  │  L1 ▓ 14:32:45.234 [THORAX] OODA cycle: ORIENT → DECIDE                ││
│  │  L2 ▒ 14:32:45.345 [SEGMENT] SmartMetrics: cpu.app-03 = 45%            ││
│  │  L2 ▒ 14:32:45.456 [SEGMENT] PubSub broadcast: prajna:metrics          ││
│  │  L1 ▓ 14:32:46.123 [THORAX] Alarm triggered: CPU_HIGH app-03           ││
│  │  L2 ▒ 14:32:46.234 [SEGMENT] AI Copilot analysis started               ││
│  │  L2 ▒ 14:32:46.345 [SEGMENT] Insight generated: anomaly_cpu            ││
│  │                                                                          ││
│  │  ── Fractal Density Graph (1 min window) ───────────────────────────── ││
│  │  L0 ░                                     █                              ││
│  │  L1 ░░    █   ░    █       ░░░   █      ██  █                           ││
│  │  L2 ████████████████████████████████████████████████████████            ││
│  │      0     10    20    30    40    50    60                             ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  VISUAL ENCODING:                                                            │
│  █ L0 (SPINE):    Full block, red/yellow                                   │
│  ▓ L1 (THORAX):   Dark shade, amber                                        │
│  ▒ L2 (SEGMENT):  Medium shade, cyan                                       │
│  ░ L3 (FIBER):    Light shade, gray                                        │
│  · L4 (GOSSAMER): Dot, dim gray                                            │
│                                                                              │
│  L4: F# IMPLEMENTATION                                                       │
│  ─────────────────────                                                       │
│  module Cepaf.Dashboard.FractalLogViewer =                                  │
│    type FractalLevel = Spine | Thorax | Segment | Fiber | Gossamer         │
│                                                                              │
│    type LogEntry = {                                                         │
│      Level: FractalLevel                                                     │
│      Timestamp: DateTime                                                     │
│      Source: string                                                          │
│      Message: string                                                         │
│      KeyExpression: string  // Zenoh key                                    │
│    }                                                                         │
│                                                                              │
│    let render (entries: LogEntry list) (area: Rect) (buffer: Buffer) =      │
│      // Implementation                                                       │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-OBS-069: Dual logging (terminal + SigNoz)                               │
│  SC-FRACTAL-001: Level filtering must be reversible                          │
│  SC-FRACTAL-002: Density graph updated every second                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Zenoh Dataflow Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: ZenohDataflowViewer                                              │
│  ──────────────────────────────                                              │
│                                                                              │
│  PURPOSE: Visualize Zenoh pub/sub key expressions and message flow           │
│                                                                              │
│  ZENOH KEY EXPRESSION HIERARCHY:                                             │
│  indrajaal/v1/                                                               │
│  ├─ metrics/                                                                 │
│  │  ├─ nodes/{node_id}/cpu                                                  │
│  │  ├─ nodes/{node_id}/memory                                               │
│  │  └─ containers/{container_id}/health                                     │
│  ├─ events/                                                                  │
│  │  ├─ alarms/{severity}/{alarm_id}                                        │
│  │  └─ commands/{command_id}                                                │
│  ├─ control/                                                                 │
│  │  ├─ ooda/{phase}                                                         │
│  │  └─ safety/{constraint_id}                                               │
│  └─ insights/                                                                │
│     └─ copilot/{insight_type}/{entity_id}                                   │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─ ZENOH DATAFLOW ────────────────────────────────────────────────────────┐│
│  │                                                                          ││
│  │  KEY EXPRESSION TREE                    MESSAGE FLOW                     ││
│  │  ┌───────────────────────┐             ┌──────────────────────────────┐ ││
│  │  │ ▼ indrajaal/v1        │             │ Rate: 142 msg/s              │ ││
│  │  │   ▼ metrics           │             │                              │ ││
│  │  │     ● nodes/app-01/*  │────────────▶│ ████████████████░░░░  80%   │ ││
│  │  │     ● nodes/app-02/*  │             │ ████████████░░░░░░░░  60%   │ ││
│  │  │     ◐ nodes/app-03/*  │             │ ████████████████████ 100%   │ ││
│  │  │   ▶ events            │             │                              │ ││
│  │  │   ▶ control           │             │ Active subscriptions: 23     │ ││
│  │  │   ▶ insights          │             │ Publishers: 8                │ ││
│  │  └───────────────────────┘             └──────────────────────────────┘ ││
│  │                                                                          ││
│  │  RECENT MESSAGES                                                         ││
│  │  ┌──────────────────────────────────────────────────────────────────────┐││
│  │  │ 14:32:45.123 → indrajaal/v1/metrics/nodes/app-03/cpu                │││
│  │  │               {value: 45, trend: "rising_fast"}                     │││
│  │  │ 14:32:45.234 → indrajaal/v1/events/alarms/caution/a-12345          │││
│  │  │               {source: "app-03", message: "CPU high"}               │││
│  │  │ 14:32:45.345 → indrajaal/v1/control/ooda/orient                    │││
│  │  │               {cycle: 847, quality: 0.98}                           │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  VISUAL ENCODING:                                                            │
│  ● Active subscription with recent messages                                 │
│  ◐ Subscription with stale data                                             │
│  ○ Inactive subscription                                                     │
│  → Message direction indicator                                               │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-ZENOH-001: Key expression hierarchy follows spec                         │
│  SC-ZENOH-002: Message rate displayed per subscription                       │
│  SC-OBS-071: OTEL correlation with Zenoh messages                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Control Flow & OODA Integration

### 8.1 OODA Cycle Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: OODACycleViewer                                                  │
│  ──────────────────────────                                                  │
│                                                                              │
│  PURPOSE: Display OODA (Observe-Orient-Decide-Act) control loop status       │
│                                                                              │
│  OODA PHASES:                                                                │
│  OBSERVE:  Collect telemetry data from all sources                          │
│  ORIENT:   Analyze data, detect anomalies, correlate events                 │
│  DECIDE:   Generate recommendations, evaluate options                        │
│  ACT:      Execute approved actions, verify results                          │
│                                                                              │
│  LAYOUT:                                                                     │
│  ┌─ OODA CONTROL LOOP ─────────────────────────────────────────────────────┐│
│  │                                                                          ││
│  │           OBSERVE                                                        ││
│  │              ●                                                           ││
│  │          ╭───────╮           Cycle Time: 0.82s                          ││
│  │         ╱    ⟳    ╲          Quality: 98%                               ││
│  │   ACT  ○           ◐  ORIENT  Confidence: 85%                           ││
│  │         ╲         ╱          Anomalies: 0                               ││
│  │          ╰───────╯           Actions Pending: 1                         ││
│  │              ○                                                           ││
│  │           DECIDE                                                         ││
│  │                                                                          ││
│  │  PHASE DETAILS                                                           ││
│  │  ┌──────────────────────────────────────────────────────────────────────┐││
│  │  │ OBSERVE (current)                                                    │││
│  │  │   Sources: SmartMetrics, ContainerHealth, Sentinel, PubSub           │││
│  │  │   Metrics collected: 142/s                                           │││
│  │  │   Events processed: 23 (last cycle)                                  │││
│  │  │   Latency: 12ms                                                      │││
│  │  ├──────────────────────────────────────────────────────────────────────┤││
│  │  │ ORIENT (last)                                                        │││
│  │  │   Anomalies detected: 1 (app-03 CPU)                                 │││
│  │  │   Correlations found: 3                                              │││
│  │  │   AI insights generated: 2                                           │││
│  │  │   Duration: 245ms                                                    │││
│  │  ├──────────────────────────────────────────────────────────────────────┤││
│  │  │ DECIDE                                                               │││
│  │  │   Recommendations: 1 (scale app-03 load)                             │││
│  │  │   Approved: 0 (awaiting operator)                                    │││
│  │  │   Rejected: 0                                                        │││
│  │  ├──────────────────────────────────────────────────────────────────────┤││
│  │  │ ACT                                                                  │││
│  │  │   Pending actions: 1                                                 │││
│  │  │   Executing: 0                                                       │││
│  │  │   Completed (last hour): 5                                           │││
│  │  └──────────────────────────────────────────────────────────────────────┘││
│  │                                                                          ││
│  │  CYCLE HISTORY (Last 10)                                                 ││
│  │  Cycle:  1    2    3    4    5    6    7    8    9   10                 ││
│  │  Time:  0.8  0.9  0.7  1.2  0.8  0.9  0.8  0.8  0.9  0.8                ││
│  │          ●    ●    ●    ⚠    ●    ●    ●    ●    ●    ●                 ││
│  │                         ↑                                                ││
│  │                   Slow cycle (>1s threshold)                             ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  PHASE INDICATORS:                                                           │
│  ●  Current phase (bright, animating)                                       │
│  ◐  Transitioning to next phase                                             │
│  ○  Completed/pending phase (dim)                                           │
│  ⟳  Cycle direction indicator                                               │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-BEH-005: OODA cycle completes <1s                                        │
│  SC-OODA-001: All four phases must complete each cycle                       │
│  SC-OODA-002: Slow cycles (>1s) generate warning                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART V: PROMETHEUS VERIFICATION

## 9. Mathematical Verification Framework

### 9.1 Graph Theory Specifications

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PROMETHEUS VERIFICATION: Graph Theory                                       │
│  ─────────────────────────────────────                                       │
│                                                                              │
│  PURPOSE: Formal verification of system properties using graph theory        │
│                                                                              │
│  GRAPH DEFINITIONS:                                                          │
│                                                                              │
│  1. AGENT HIERARCHY GRAPH G_A = (V_A, E_A)                                   │
│     V_A = {a₁, a₂, ..., a₅₀}  (50 agents)                                   │
│     E_A = {(a_i, a_j) | a_i supervises a_j}                                 │
│     Properties:                                                              │
│       - DAG (Directed Acyclic Graph)                                        │
│       - Single root (Executive agent)                                        │
│       - Max depth = 3                                                        │
│       - |E_A| = 49 (tree structure)                                         │
│                                                                              │
│  2. DEPENDENCY GRAPH G_D = (V_D, E_D)                                        │
│     V_D = {services, containers, resources}                                  │
│     E_D = {(v_i, v_j) | v_i depends on v_j}                                 │
│     Properties:                                                              │
│       - DAG (no circular dependencies)                                       │
│       - Topological ordering exists                                          │
│       - Critical path identifiable                                           │
│                                                                              │
│  3. CAUSAL GRAPH G_C = (V_C, E_C)                                            │
│     V_C = {events}                                                           │
│     E_C = {(e_i, e_j) | e_i caused e_j}                                     │
│     Properties:                                                              │
│       - DAG (causality is acyclic)                                          │
│       - Temporal ordering preserved                                          │
│       - Root cause identifiable                                              │
│                                                                              │
│  FORMAL PROPERTIES TO VERIFY:                                                │
│                                                                              │
│  P1. Agent Reachability                                                      │
│      ∀ a ∈ V_A : ∃ path from Executive to a                                 │
│      (All agents reachable from executive)                                   │
│                                                                              │
│  P2. Dependency Acyclicity                                                   │
│      ¬∃ cycle in G_D                                                         │
│      (No circular dependencies)                                              │
│                                                                              │
│  P3. Causal Transitivity                                                     │
│      (e_i → e_j) ∧ (e_j → e_k) ⟹ (e_i → e_k)                               │
│      (Causality is transitive)                                               │
│                                                                              │
│  P4. Impact Propagation Bound                                                │
│      ∀ v ∈ V_D : |descendants(v)| ≤ k                                       │
│      (Blast radius is bounded)                                               │
│                                                                              │
│  VERIFICATION CODE (Elixir):                                                 │
│  ──────────────────────────────                                              │
│  defmodule Prajna.Verification.GraphTheory do                               │
│    @moduledoc "PROMETHEUS graph verification"                                │
│                                                                              │
│    def verify_agent_reachability(graph) do                                  │
│      executive = find_root(graph)                                            │
│      all_agents = Graph.vertices(graph)                                      │
│                                                                              │
│      Enum.all?(all_agents, fn agent ->                                      │
│        Graph.reachable(graph, executive, agent)                             │
│      end)                                                                    │
│    end                                                                       │
│                                                                              │
│    def verify_dependency_acyclicity(graph) do                               │
│      case Graph.topsort(graph) do                                           │
│        {:ok, _order} -> true                                                │
│        {:error, :cycle} -> false                                            │
│      end                                                                     │
│    end                                                                       │
│                                                                              │
│    def verify_impact_bound(graph, max_descendants) do                       │
│      Enum.all?(Graph.vertices(graph), fn v ->                               │
│        length(Graph.descendants(graph, v)) <= max_descendants               │
│      end)                                                                    │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  VERIFICATION CODE (F#):                                                     │
│  ──────────────────────────                                                  │
│  module Cepaf.Verification.GraphTheory =                                    │
│    let verifyAgentReachability (graph: DirectedGraph<'a>) =                 │
│      let executive = findRoot graph                                          │
│      let allAgents = Graph.vertices graph                                    │
│      allAgents |> Seq.forall (fun agent ->                                  │
│        Graph.isReachable graph executive agent)                             │
│                                                                              │
│    let verifyDependencyAcyclicity (graph: DirectedGraph<'a>) =              │
│      match Graph.topologicalSort graph with                                 │
│      | Some _ -> true                                                        │
│      | None -> false  // Cycle detected                                     │
│                                                                              │
│    let verifyImpactBound (graph: DirectedGraph<'a>) maxDescendants =        │
│      Graph.vertices graph                                                    │
│      |> Seq.forall (fun v ->                                                │
│        (Graph.descendants graph v |> Seq.length) <= maxDescendants)         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 STAMP Constraint Verification

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PROMETHEUS VERIFICATION: STAMP Constraints                                  │
│  ──────────────────────────────────────────                                  │
│                                                                              │
│  PURPOSE: Verify all 242 STAMP safety constraints at runtime                 │
│                                                                              │
│  CONSTRAINT CATEGORIES:                                                      │
│                                                                              │
│  SC-VAL (Validation): 10 constraints                                         │
│  SC-CNT (Container): 15 constraints                                          │
│  SC-AGT (Agents): 12 constraints                                             │
│  SC-CMP (Compilation): 8 constraints                                         │
│  SC-SEC (Security): 18 constraints                                           │
│  SC-PRF (Performance): 15 constraints                                        │
│  SC-EMR (Emergency): 10 constraints                                          │
│  SC-OBS (Observability): 12 constraints                                      │
│  SC-HMI (Human-Machine Interface): 10 constraints                            │
│  SC-INFO (Information): 8 constraints                                        │
│  SC-BEH (Behavioral): 10 constraints                                         │
│  SC-GEO (Geometric): 8 constraints                                           │
│  ... (remaining categories)                                                  │
│                                                                              │
│  VERIFICATION FRAMEWORK:                                                     │
│                                                                              │
│  defmodule Prajna.Verification.STAMP do                                     │
│    @constraints [                                                            │
│      # HMI Constraints                                                       │
│      %{id: "SC-HMI-001", desc: "Dark cockpit colors", verify: &verify_dark_cockpit/1},
│      %{id: "SC-HMI-002", desc: "Trend indicators visible", verify: &verify_trends/1},
│      %{id: "SC-HMI-003", desc: "Two-step commit", verify: &verify_two_step/1},
│      %{id: "SC-HMI-004", desc: "Staleness decay", verify: &verify_staleness/1},
│      %{id: "SC-HMI-005", desc: "AI marked advisory", verify: &verify_ai_advisory/1},
│                                                                              │
│      # Behavioral Constraints                                                │
│      %{id: "SC-BEH-001", desc: "FSM consistency", verify: &verify_fsm/1},   │
│      %{id: "SC-BEH-002", desc: "Threshold <100ms", verify: &verify_threshold_latency/1},
│      %{id: "SC-BEH-003", desc: "Staleness real-time", verify: &verify_staleness_realtime/1},
│      %{id: "SC-BEH-004", desc: "Guardian approval", verify: &verify_guardian/1},
│      %{id: "SC-BEH-005", desc: "OODA <1s", verify: &verify_ooda_cycle/1},   │
│                                                                              │
│      # ... 232 more constraints                                             │
│    ]                                                                         │
│                                                                              │
│    def verify_all(state) do                                                 │
│      results = Enum.map(@constraints, fn c ->                               │
│        {c.id, c.verify.(state)}                                             │
│      end)                                                                    │
│                                                                              │
│      violations = Enum.filter(results, fn {_id, result} -> not result end) │
│      {violations == [], violations}                                         │
│    end                                                                       │
│                                                                              │
│    # Example constraint verifier                                             │
│    defp verify_ooda_cycle(%{ooda: %{last_cycle_time: time}}) do             │
│      time < 1000  # milliseconds                                            │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  CONTINUOUS VERIFICATION:                                                    │
│                                                                              │
│  defmodule Prajna.Verification.Continuous do                                │
│    use GenServer                                                             │
│                                                                              │
│    def handle_info(:verify, state) do                                       │
│      case STAMP.verify_all(state) do                                        │
│        {true, []} ->                                                        │
│          {:noreply, state}                                                   │
│        {false, violations} ->                                               │
│          handle_violations(violations)                                       │
│          {:noreply, state}                                                   │
│      end                                                                     │
│    end                                                                       │
│                                                                              │
│    defp handle_violations(violations) do                                    │
│      # Log to fractal logger (L0 SPINE)                                     │
│      # Notify Guardian                                                       │
│      # Trigger alarms                                                        │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART VI: IMPLEMENTATION GUIDE

## 10. Elixir Implementation

### 10.1 Module Structure

```
lib/prajna/tui/
├── widget.ex                    # Base widget behavior
├── buffer.ex                    # Buffer operations
├── layout.ex                    # Layout system
├── staleness.ex                 # Staleness tracking
├── two_step_commit.ex           # Two-step commit flow
├── subscriptions.ex             # PubSub integration
│
├── primitives/
│   ├── status_indicator.ex
│   ├── trend_arrow.ex
│   ├── gauge.ex
│   ├── sparkline.ex
│   └── progress.ex
│
├── components/
│   ├── metric_card.ex
│   ├── alarm_card.ex
│   ├── node_card.ex
│   ├── insight_card.ex
│   ├── trace_waterfall.ex
│   ├── event_timeline.ex
│   ├── log_viewer.ex
│   └── ooda_viewer.ex
│
├── screens/
│   ├── startup_sequence.ex
│   ├── shutdown_sequence.ex
│   ├── dashboard.ex
│   ├── mesh_topology.ex
│   ├── alarm_center.ex
│   ├── command_center.ex
│   ├── copilot.ex
│   ├── containers.ex
│   ├── cluster.ex
│   └── settings.ex
│
├── input/
│   ├── keyboard.ex
│   ├── navigation.ex
│   └── commands.ex
│
└── verification/
    ├── graph_theory.ex
    ├── stamp.ex
    └── continuous.ex
```

### 10.2 LiveView Integration

```elixir
defmodule IndrajaalWeb.Live.Prajna.DashboardLive do
  @moduledoc """
  Main PRAJNA C3I Cockpit LiveView.

  Implements Elm Architecture with real-time PubSub updates.
  """

  use IndrajaalWeb, :live_view

  alias Prajna.TUI.Screens.Dashboard
  alias Prajna.TUI.Subscriptions
  alias Prajna.TUI.Staleness

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Subscriptions.subscribe_all()
      :timer.send_interval(500, self(), :tick)
    end

    {:ok, assign(socket, model: init_model())}
  end

  @impl true
  def handle_info({:metric_update, node_id, metrics}, socket) do
    model = update_metrics(socket.assigns.model, node_id, metrics)
    {:noreply, assign(socket, model: model)}
  end

  @impl true
  def handle_info({:alarm_event, alarm}, socket) do
    model = update_alarms(socket.assigns.model, alarm)
    {:noreply, assign(socket, model: model)}
  end

  @impl true
  def handle_info(:tick, socket) do
    model = update_staleness(socket.assigns.model)
    {:noreply, assign(socket, model: model)}
  end

  @impl true
  def handle_event("key", %{"key" => key}, socket) do
    {model, commands} = handle_key(socket.assigns.model, key)
    socket = execute_commands(socket, commands)
    {:noreply, assign(socket, model: model)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="prajna-dashboard" phx-window-keydown="key">
      <.dashboard model={@model} />
    </div>
    """
  end

  defp init_model do
    %{
      active_tab: :overview,
      focus_path: [],
      modal: nil,
      metrics: %{},
      alarms: [],
      nodes: %{},
      insights: [],
      containers: %{},
      ooda: %{phase: :observe, cycle_time: 0},
      armed_command: nil
    }
  end
end
```

---

## 11. F# Implementation

### 11.1 Module Structure

```
lib/cepaf/src/Cepaf/Dashboard/
├── Widget.fs                    # Base widget interface
├── Buffer.fs                    # Buffer operations
├── Layout.fs                    # Layout system
├── Staleness.fs                 # Staleness tracking
│
├── Primitives/
│   ├── StatusIndicator.fs
│   ├── TrendArrow.fs
│   ├── Gauge.fs
│   └── Sparkline.fs
│
├── Components/
│   ├── MetricCard.fs
│   ├── FractalLogViewer.fs
│   ├── ZenohDataflowViewer.fs
│   └── ContainerHealth.fs
│
├── Screens/
│   ├── InfrastructureDashboard.fs
│   └── ObservabilityDashboard.fs
│
└── Verification/
    ├── GraphTheory.fs
    └── StampConstraints.fs
```

### 11.2 Core Types

```fsharp
namespace Cepaf.Dashboard

open System

/// Core types for cross-language compatibility
module Types =
    /// Health status (matches Elixir)
    type Health = Healthy | Degraded | Critical | Unknown

    /// Trend direction (matches Elixir)
    type Trend = RisingFast | Rising | Stable | Falling | FallingFast | Oscillating

    /// Alarm severity (matches Elixir)
    type Severity = Critical | Warning | Caution | Advisory

    /// Metric data
    type Metric = {
        Id: Guid
        Name: string
        Value: float
        Unit: string
        Timestamp: DateTime
        Source: string
        Trend: Trend
        StalenessSeconds: int
    }

    /// Alarm data
    type Alarm = {
        Id: Guid
        Severity: Severity
        Source: string
        Message: string
        TriggeredAt: DateTime
        Acknowledged: bool
    }

    /// Fractal log level
    type FractalLevel = Spine | Thorax | Segment | Fiber | Gossamer

    /// Log entry
    type LogEntry = {
        Level: FractalLevel
        Timestamp: DateTime
        Source: string
        Message: string
        ZenohKey: string option
    }

/// Widget interface (matches Elixir Widget behavior)
module Widget =
    type Rect = { X: int; Y: int; Width: int; Height: int }

    type Cell = { Char: char; FgColor: string; BgColor: string }

    type Buffer = { Cells: Map<int * int, Cell>; Width: int; Height: int }

    type IWidget =
        abstract member Render: Rect -> Buffer -> Buffer
        abstract member MinSize: unit -> int * int

    type IStatefulWidget<'State> =
        inherit IWidget
        abstract member HandleEvent: 'State -> obj -> 'State * obj list
```

### 11.3 Component Example

```fsharp
namespace Cepaf.Dashboard.Components

open Cepaf.Dashboard.Types
open Cepaf.Dashboard.Widget

/// Fractal log viewer component
module FractalLogViewer =
    type Model = {
        Entries: LogEntry list
        FilterLevel: FractalLevel
        SearchTerm: string option
        LiveTail: bool
        ScrollOffset: int
    }

    let levelChar = function
        | Spine -> '█'
        | Thorax -> '▓'
        | Segment -> '▒'
        | Fiber -> '░'
        | Gossamer -> '·'

    let levelColor = function
        | Spine -> "#EF4444"    // Red
        | Thorax -> "#F59E0B"   // Amber
        | Segment -> "#06B6D4"  // Cyan
        | Fiber -> "#6B7280"    // Gray
        | Gossamer -> "#374151" // Dark gray

    let render (model: Model) (area: Rect) (buffer: Buffer) : Buffer =
        // Draw border
        let buffer = drawBorder buffer area "FRACTAL LOG VIEWER"

        // Draw filter bar
        let inner = shrink area 1
        let filterLine = sprintf "Level: [%A ▼]  Filter: [%s]  [%s LIVE TAIL]"
                            model.FilterLevel
                            (model.SearchTerm |> Option.defaultValue "")
                            (if model.LiveTail then "●" else "○")
        let buffer = putString buffer inner.X inner.Y filterLine

        // Draw log entries
        let visibleEntries =
            model.Entries
            |> List.filter (fun e -> e.Level <= model.FilterLevel)
            |> List.skip model.ScrollOffset
            |> List.truncate (inner.Height - 3)

        visibleEntries
        |> List.indexed
        |> List.fold (fun buf (idx, entry) ->
            let y = inner.Y + 2 + idx
            let prefix = sprintf "%c %s [%s]"
                            (levelChar entry.Level)
                            (entry.Timestamp.ToString("HH:mm:ss.fff"))
                            entry.Source
            let line = sprintf "%s %s" prefix entry.Message
            putString buf inner.X y line
        ) buffer
```

---

## 12. Livebook Analytics

### 12.1 Real-Time Dashboard Notebook

```elixir
# livebook/prajna_analytics.livemd

# PRAJNA Analytics Dashboard

```elixir
Mix.install([
  {:kino, "~> 0.12"},
  {:kino_vega_lite, "~> 0.1"},
  {:vega_lite, "~> 0.1"},
  {:phoenix_pubsub, "~> 2.0"}
])
```

## System Health Overview

```elixir
# Subscribe to PubSub
Phoenix.PubSub.subscribe(Indrajaal.PubSub, "prajna:metrics")

# Create real-time health gauge
health_frame = Kino.Frame.new()

spawn(fn ->
  Stream.interval(1000)
  |> Stream.each(fn _ ->
    health = calculate_system_health()
    gauge = VegaLite.new(width: 200, height: 200)
    |> VegaLite.data_from_values([%{value: health}])
    |> VegaLite.mark(:arc, inner_radius: 50)
    |> VegaLite.encode_field(:theta, "value", type: :quantitative)
    |> VegaLite.encode(:color, value: health_color(health))

    Kino.Frame.render(health_frame, gauge)
  end)
  |> Stream.run()
end)

health_frame
```

## Metrics Sparklines

```elixir
# Real-time sparkline grid
metrics_grid = Kino.Frame.new()

spawn(fn ->
  receive do
    {:metric_update, node_id, metrics} ->
      sparklines = render_sparklines(node_id, metrics)
      Kino.Frame.render(metrics_grid, sparklines)
  end
end)

metrics_grid
```

## STAMP Constraint Status

```elixir
# Constraint verification results
constraints = Prajna.Verification.STAMP.verify_all(current_state())

constraints
|> Enum.group_by(fn {id, _} -> String.split(id, "-") |> Enum.at(1) end)
|> Enum.map(fn {category, items} ->
  passed = Enum.count(items, fn {_, result} -> result end)
  total = length(items)
  %{category: category, passed: passed, total: total, pct: passed / total * 100}
end)
|> Kino.DataTable.new()
```
```

---

# PART VII: APPENDICES

## Appendix A: Symbol Reference

```
STATUS INDICATORS
● Active/Healthy     ◐ Partial/Degraded    ○ Inactive/Unknown
◎ Armed/Ready        ⊙ Focused             ☢ Critical

SEVERITY ICONS
ℹ Advisory          ⚠ Caution             ⛔ Warning           ☢ Critical

TREND ARROWS
↑↑ Rising Fast      ↑ Rising              → Stable
↓ Falling           ↓↓ Falling Fast       ⚡ Oscillating

ACTION RESULTS
✓ Success           ✗ Failure             ? Pending

FLOW INDICATORS
→ Direction         ↔ Bidirectional       ⟳ Cycle

GRAPH ELEMENTS
▼ Expanded          ▶ Collapsed           ├─ Branch            └─ Last Branch

FILL PATTERNS
░ Light (25%)       ▒ Medium (50%)        ▓ Dark (75%)         █ Full (100%)

SPARKLINE CHARACTERS
▁ 1/8               ▂ 2/8                 ▃ 3/8                ▄ 4/8
▅ 5/8               ▆ 6/8                 ▇ 7/8                █ 8/8

FRACTAL LOG LEVELS
█ L0 SPINE          ▓ L1 THORAX           ▒ L2 SEGMENT
░ L3 FIBER          · L4 GOSSAMER

BOX DRAWING
┌ ┐ └ ┘ ─ │ ├ ┤ ┬ ┴ ┼ (single)
╔ ╗ ╚ ╝ ═ ║ ╠ ╣ ╦ ╩ ╬ (double)
╭ ╮ ╰ ╯ (rounded)

SPINNERS
⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏ (braille)
◴ ◷ ◶ ◵ (quarters)
```

## Appendix B: Color Palette

```
ISA-101 HIGH-PERFORMANCE HMI COLORS (Dark Theme)

Background:     #111827 (gray-900)
Surface:        #1F2937 (gray-800)
Border:         #374151 (gray-700)

Text Primary:   #F9FAFB (gray-50)
Text Secondary: #D1D5DB (gray-300)
Text Muted:     #6B7280 (gray-500)

Normal:         #374151 (gray-700)      Nearly invisible
Advisory:       #06B6D4 (cyan-500)      Informational
Caution:        #F59E0B (amber-500)     Attention needed
Warning:        #FB923C (orange-400)    Action recommended
Critical:       #EF4444 (red-500)       Action required
Critical+Pulse: #DC2626 (red-600)       + animation

Success:        #22C55E (green-500)
Focus:          #3B82F6 (blue-500)
Selection:      #1E40AF (blue-800)
Correlation:    #A855F7 (purple-500)

MATERIAL 3 TOKEN MAPPING
Primary:        #06B6D4 (cyan-500)
On-Primary:     #FFFFFF
Secondary:      #6B7280 (gray-500)
Tertiary:       #A855F7 (purple-500)
Error:          #EF4444 (red-500)
Surface:        #1F2937 (gray-800)
On-Surface:     #D1D5DB (gray-300)
```

## Appendix C: Keyboard Shortcuts

```
GLOBAL:
  q       Quit
  ?       Help
  :       Command mode
  1-9     Jump to tab
  Tab     Next tab
  S-Tab   Previous tab
  /       Search
  Esc     Cancel/Back

ALARMS:
  a       Acknowledge
  s       Silence (1h)
  e       Escalate
  f       Filter
  Enter   View detail

MESH:
  r       Restart node (ARM)
  l       View logs
  s       Shell into
  h       Health check
  i       Isolate (ARM)
  d       Drain (ARM)
  Enter   Select node

COMMANDS:
  Enter   Confirm armed
  Esc     Cancel armed
  0-9     Enter confirmation code

COPILOT:
  Enter   Apply recommendation
  d       Dismiss insight
  v       View related entity

CONTAINERS:
  r       Restart container
  l       View logs
  s       Shell into
```

## Appendix D: STAMP Constraint Index

| ID | Category | Description |
|----|----------|-------------|
| SC-HMI-001 | HMI | Dark cockpit: normal nearly invisible |
| SC-HMI-002 | HMI | Anomalies in amber/red with trends |
| SC-HMI-003 | HMI | Two-step commit for critical commands |
| SC-HMI-004 | HMI | Staleness visual decay after 5s |
| SC-HMI-005 | HMI | AI insights marked ADVISORY only |
| SC-INFO-001 | Information | Metrics include timestamp and source |
| SC-INFO-002 | Information | Events include severity classification |
| SC-INFO-003 | Information | Entities include lifecycle state |
| SC-BEH-001 | Behavioral | State transitions follow defined FSM |
| SC-BEH-002 | Behavioral | Threshold breaches generate alarms <100ms |
| SC-BEH-003 | Behavioral | Staleness detection real-time |
| SC-BEH-004 | Behavioral | Commands require Guardian approval |
| SC-BEH-005 | Behavioral | OODA cycle completes <1s |
| SC-GEO-001 | Geometric | Layout adapts to terminal resize |
| SC-GEO-002 | Geometric | Critical info visible without scrolling |
| SC-OODA-001 | OODA | All four phases complete each cycle |
| SC-OODA-002 | OODA | Slow cycles (>1s) generate warning |
| SC-ZENOH-001 | Zenoh | Key expression hierarchy follows spec |
| SC-ZENOH-002 | Zenoh | Message rate displayed per subscription |
| SC-FRACTAL-001 | Fractal | Level filtering reversible |
| SC-FRACTAL-002 | Fractal | Density graph updated every second |

(Full list: 242 constraints across 20 categories)

---

---

# PART VIII: INTELLIGENT & GENERATIVE UI SYSTEM

## 13. OpenRouter LLM Integration

### 13.1 AI-Powered UI Intelligence (L2: Concepts)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INTELLIGENT UI ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        STABLE CORE LAYER                                ││
│  │  ─────────────────────────────────────────                              ││
│  │  • Information Model (Metrics, Alarms, Entities, Events)               ││
│  │  • Ash Resources (19 domain resources)                                  ││
│  │  • STAMP Constraints (242 verified invariants)                          ││
│  │  • Safety Envelope (Guardian, DMS, Sentinel)                            ││
│  │  • Graph Structures (Agent hierarchy, dependencies, causality)          ││
│  │                                                                          ││
│  │  INVARIANT: Core never changes at runtime                               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                              ↕ Semantic API                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                      ADAPTIVE PRESENTATION LAYER                        ││
│  │  ─────────────────────────────────────────────                          ││
│  │  • Component Registry (dynamic loading)                                 ││
│  │  • Layout Engine (constraint-based, responsive)                         ││
│  │  • Theme System (runtime switchable)                                    ││
│  │  • Navigation Graph (learnable)                                         ││
│  │  • Behavior Rules (AI-suggested optimizations)                          ││
│  │                                                                          ││
│  │  MUTABLE: Presentation evolves based on usage patterns                  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                              ↕ OpenRouter API                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                       AI INTELLIGENCE LAYER                             ││
│  │  ─────────────────────────────────────────                              ││
│  │  • OpenRouter Multi-Model Gateway                                       ││
│  │    - Claude 3.5 Sonnet (UI reasoning, insights)                        ││
│  │    - GPT-4o (natural language parsing)                                  ││
│  │    - Llama 3.1 70B (fast local inference)                              ││
│  │  • Generative UI Engine                                                 ││
│  │  • Usage Pattern Learner                                                ││
│  │  • Context-Aware Recommendations                                        ││
│  │  • Anomaly Explanation Generator                                        ││
│  │                                                                          ││
│  │  ADVISORY: AI suggestions require operator confirmation (SC-HMI-005)   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 13.2 OpenRouter Integration (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPONENT: OpenRouterIntegration                                            │
│  ─────────────────────────────────                                           │
│                                                                              │
│  PURPOSE: Multi-model LLM gateway for intelligent UI generation             │
│                                                                              │
│  API CONFIGURATION:                                                          │
│  Base URL: https://openrouter.ai/api/v1                                      │
│  Auth: OPENROUTER_API_KEY (env var)                                          │
│                                                                              │
│  MODEL SELECTION STRATEGY:                                                   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Task Type              │ Model                    │ Reason              ││
│  ├────────────────────────┼──────────────────────────┼─────────────────────┤│
│  │ UI Layout Generation   │ claude-3.5-sonnet        │ Spatial reasoning   ││
│  │ Alarm Explanation      │ claude-3.5-sonnet        │ Technical accuracy  ││
│  │ Command Suggestions    │ gpt-4o                   │ Intent parsing      ││
│  │ Pattern Detection      │ llama-3.1-70b            │ Low latency         ││
│  │ Documentation Gen      │ claude-3.5-sonnet        │ Long-form coherence ││
│  │ Quick Insights         │ llama-3.1-8b             │ Sub-100ms response  ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  L4: ELIXIR IMPLEMENTATION                                                   │
│  ─────────────────────────                                                   │
│  defmodule Prajna.AI.OpenRouterClient do                                    │
│    @moduledoc """                                                            │
│    OpenRouter multi-model client for intelligent UI generation.             │
│                                                                              │
│    STAMP: SC-AI-001 (AI is advisory only)                                   │
│    STAMP: SC-SEC-047 (encrypted API communication)                          │
│    """                                                                       │
│                                                                              │
│    @base_url "https://openrouter.ai/api/v1"                                 │
│                                                                              │
│    @models %{                                                                │
│      ui_generation: "anthropic/claude-3.5-sonnet",                          │
│      alarm_explanation: "anthropic/claude-3.5-sonnet",                      │
│      command_parsing: "openai/gpt-4o",                                      │
│      pattern_detection: "meta-llama/llama-3.1-70b",                         │
│      quick_insight: "meta-llama/llama-3.1-8b"                               │
│    }                                                                         │
│                                                                              │
│    def generate_ui_layout(context, constraints) do                          │
│      prompt = build_ui_prompt(context, constraints)                          │
│      chat(@models.ui_generation, prompt, max_tokens: 2000)                  │
│    end                                                                       │
│                                                                              │
│    def explain_alarm(alarm, system_context) do                              │
│      prompt = """                                                            │
│      Analyze this alarm in context of the system state:                     │
│      Alarm: #{inspect(alarm)}                                               │
│      System: #{inspect(system_context)}                                     │
│                                                                              │
│      Provide:                                                                │
│      1. Root cause hypothesis (confidence 0-1)                              │
│      2. Recommended actions (ranked)                                        │
│      3. Related alarms/metrics to monitor                                   │
│      """                                                                     │
│      chat(@models.alarm_explanation, prompt)                                │
│    end                                                                       │
│                                                                              │
│    def suggest_navigation(user_patterns, current_context) do                │
│      prompt = build_navigation_prompt(user_patterns, current_context)       │
│      chat(@models.pattern_detection, prompt, max_tokens: 500)               │
│    end                                                                       │
│                                                                              │
│    defp chat(model, prompt, opts \\ []) do                                  │
│      headers = [                                                             │
│        {"Authorization", "Bearer #{api_key()}"},                            │
│        {"HTTP-Referer", "https://indrajaal.local"},                         │
│        {"X-Title", "Prajna C3I Cockpit"}                                    │
│      ]                                                                       │
│                                                                              │
│      body = %{                                                               │
│        model: model,                                                         │
│        messages: [%{role: "user", content: prompt}],                        │
│        max_tokens: opts[:max_tokens] || 1000,                               │
│        temperature: opts[:temperature] || 0.7                               │
│      }                                                                       │
│                                                                              │
│      case Finch.request(build_request(body, headers)) do                    │
│        {:ok, %{status: 200, body: body}} ->                                 │
│          parse_response(body)                                                │
│        {:error, reason} ->                                                   │
│          {:error, reason}                                                    │
│      end                                                                     │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  L5: STAMP CONSTRAINTS                                                       │
│  ──────────────────────                                                      │
│  SC-AI-001: All AI outputs marked "ADVISORY ONLY"                           │
│  SC-AI-002: Human confirmation required for actions                          │
│  SC-AI-003: Response timeout <5s (fallback to local)                        │
│  SC-AI-004: API errors gracefully degraded                                   │
│  SC-SEC-047: TLS 1.3 for all API calls                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 14. Generative UI System

### 14.1 Dynamic Component Generation (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SYSTEM: GenerativeUI                                                        │
│  ─────────────────────                                                       │
│                                                                              │
│  PURPOSE: Generate and adapt UI components based on system state            │
│                                                                              │
│  COMPONENT GENERATION FLOW:                                                  │
│                                                                              │
│    ┌───────────────┐    ┌───────────────┐    ┌───────────────┐              │
│    │ System State  │───▶│ AI Analyzer   │───▶│ Layout DSL    │              │
│    │ (metrics,     │    │ (context +    │    │ (component    │              │
│    │ alarms, etc.) │    │ patterns)     │    │ specs)        │              │
│    └───────────────┘    └───────────────┘    └───────────────┘              │
│                                ↓                     ↓                       │
│                         ┌───────────────┐    ┌───────────────┐              │
│                         │ Human Review  │◀───│ Component     │              │
│                         │ (optional)    │    │ Renderer      │              │
│                         └───────────────┘    └───────────────┘              │
│                                                      ↓                       │
│                                              ┌───────────────┐              │
│                                              │ Live UI       │              │
│                                              └───────────────┘              │
│                                                                              │
│  LAYOUT DSL (Declarative Component Specification):                           │
│                                                                              │
│  %Layout{                                                                    │
│    type: :grid,                                                              │
│    columns: 3,                                                               │
│    rows: 2,                                                                  │
│    gap: 1,                                                                   │
│    children: [                                                               │
│      %Component{type: :metric_card, source: "cpu.app-01", span: 1},        │
│      %Component{type: :metric_card, source: "mem.app-01", span: 1},        │
│      %Component{type: :alarm_card, filter: %{severity: :critical}, span: 1},│
│      %Component{type: :sparkline_row, sources: ["cpu.*"], span: 3}         │
│    ]                                                                         │
│  }                                                                           │
│                                                                              │
│  CONTEXT-AWARE GENERATION RULES:                                             │
│                                                                              │
│  Rule 1: Critical Alarm → Expand Alarm Panel                                │
│    condition: count(alarms, severity: :critical) > 0                        │
│    action: promote(:alarm_center, :primary_focus)                           │
│                                                                              │
│  Rule 2: High CPU → Show Node Details                                        │
│    condition: any(metrics, name: "cpu.*", value: > 80%)                     │
│    action: insert(:node_detail, source: highest_cpu_node())                 │
│                                                                              │
│  Rule 3: Operator Preference → Adapt Layout                                  │
│    condition: user_preference("dashboard.layout") == "compact"              │
│    action: set_layout(:compact_grid)                                        │
│                                                                              │
│  Rule 4: OODA Phase → Highlight Relevant Data                                │
│    condition: ooda.current_phase == :orient                                 │
│    action: highlight(:correlation_panel)                                    │
│                                                                              │
│  L4: ELIXIR IMPLEMENTATION                                                   │
│  ─────────────────────────                                                   │
│  defmodule Prajna.TUI.GenerativeUI do                                       │
│    @moduledoc """                                                            │
│    Generates and adapts UI layouts based on system state.                   │
│                                                                              │
│    Architecture:                                                             │
│    - Stable Core: Information model never changes                           │
│    - Adaptive Presentation: Layout/components evolve                        │
│    """                                                                       │
│                                                                              │
│    alias Prajna.AI.OpenRouterClient                                         │
│    alias Prajna.TUI.{LayoutDSL, ComponentRegistry}                          │
│                                                                              │
│    defstruct [:base_layout, :active_rules, :user_preferences,               │
│               :generation_history, :learning_model]                          │
│                                                                              │
│    def generate_layout(state, context) do                                   │
│      # 1. Evaluate context-aware rules                                       │
│      triggered_rules = evaluate_rules(state.active_rules, context)          │
│                                                                              │
│      # 2. Apply rule transformations                                         │
│      layout = apply_transformations(state.base_layout, triggered_rules)     │
│                                                                              │
│      # 3. AI enhancement (if enabled and latency budget allows)             │
│      layout = maybe_ai_enhance(layout, context, state.user_preferences)     │
│                                                                              │
│      # 4. Validate against STAMP constraints                                │
│      validate_layout!(layout)                                                │
│                                                                              │
│      layout                                                                  │
│    end                                                                       │
│                                                                              │
│    def learn_from_interaction(state, interaction) do                        │
│      # Update learning model based on user behavior                          │
│      model = UsagePatternLearner.update(state.learning_model, interaction)  │
│                                                                              │
│      # Generate new optimization rules                                       │
│      new_rules = generate_optimization_rules(model)                          │
│                                                                              │
│      %{state | learning_model: model, active_rules: merge_rules(state.active_rules, new_rules)}
│    end                                                                       │
│                                                                              │
│    defp maybe_ai_enhance(layout, context, prefs) when prefs.ai_enabled do  │
│      case OpenRouterClient.suggest_layout_optimization(layout, context) do │
│        {:ok, suggestion} ->                                                 │
│          if prefs.auto_apply_ai do                                          │
│            apply_suggestion(layout, suggestion)                             │
│          else                                                                │
│            queue_suggestion_for_review(layout, suggestion)                  │
│            layout                                                            │
│          end                                                                 │
│        {:error, _} ->                                                       │
│          layout  # Graceful degradation                                     │
│      end                                                                     │
│    end                                                                       │
│                                                                              │
│    defp maybe_ai_enhance(layout, _context, _prefs), do: layout             │
│  end                                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 14.2 Learning & Evolution Framework (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SYSTEM: LearningEvolution                                                   │
│  ──────────────────────────                                                  │
│                                                                              │
│  PURPOSE: Enable TUI to learn from usage and evolve over time               │
│                                                                              │
│  EVOLUTION PRINCIPLES (OODA/AEE/CEA):                                        │
│                                                                              │
│  1. OODA (Observe-Orient-Decide-Act)                                         │
│     ───────────────────────────────                                          │
│     OBSERVE: Collect interaction telemetry                                   │
│       - Click/navigation patterns                                            │
│       - Time spent on screens                                                │
│       - Feature usage frequency                                              │
│       - Error/retry patterns                                                 │
│                                                                              │
│     ORIENT: Analyze patterns                                                 │
│       - Identify common workflows                                            │
│       - Detect friction points                                               │
│       - Correlate with system states                                         │
│                                                                              │
│     DECIDE: Generate hypotheses                                              │
│       - "Moving Alarm Center to top would reduce clicks"                    │
│       - "Adding CPU sparkline to node cards improves response"              │
│       - "Compact mode preferred during incidents"                           │
│                                                                              │
│     ACT: Apply and measure                                                   │
│       - A/B test layout variants                                            │
│       - Collect feedback                                                     │
│       - Rollback if metrics decline                                          │
│                                                                              │
│  2. AEE (Autonomous Execution Environment)                                   │
│     ──────────────────────────────────────                                   │
│     - Self-tuning refresh rates                                              │
│     - Adaptive staleness thresholds                                          │
│     - Auto-scaling chart resolutions                                         │
│                                                                              │
│  3. CEA (Cybernetic Evolution Architecture)                                  │
│     ─────────────────────────────────────                                    │
│     - Genetic algorithms for layout optimization                             │
│     - Fitness function: task completion time + error rate                    │
│     - Crossover: combine successful layout patterns                          │
│     - Mutation: introduce random variations                                  │
│                                                                              │
│  LEARNING MODEL:                                                             │
│                                                                              │
│  defmodule Prajna.TUI.UsagePatternLearner do                                │
│    @moduledoc """                                                            │
│    Learns from user interactions to optimize UI behavior.                   │
│                                                                              │
│    Uses:                                                                     │
│    - Markov chains for navigation prediction                                │
│    - Bayesian inference for preference learning                             │
│    - Reinforcement learning for layout optimization                         │
│    """                                                                       │
│                                                                              │
│    defstruct [                                                               │
│      :navigation_markov,     # P(next_screen | current_screen)              │
│      :feature_usage,         # Frequency counts                              │
│      :time_distributions,    # Time spent per screen                        │
│      :context_correlations,  # (system_state → user_action)                │
│      :layout_fitness,        # Layout variant → success metrics             │
│      :generation            # Evolution generation number                   │
│    ]                                                                         │
│                                                                              │
│    def update(model, %Interaction{type: :navigation} = i) do                │
│      transition = {i.from_screen, i.to_screen}                              │
│      markov = update_markov(model.navigation_markov, transition)            │
│      %{model | navigation_markov: markov}                                   │
│    end                                                                       │
│                                                                              │
│    def predict_next_screen(model, current_screen) do                        │
│      model.navigation_markov                                                 │
│      |> Map.get(current_screen, %{})                                        │
│      |> Enum.max_by(fn {_, prob} -> prob end, fn -> {:unknown, 0} end)     │
│    end                                                                       │
│                                                                              │
│    def generate_optimized_layout(model, base_layout, fitness_fn) do         │
│      # Genetic algorithm for layout optimization                             │
│      population = initialize_population(base_layout, 20)                    │
│                                                                              │
│      Enum.reduce(1..50, population, fn generation, pop ->                   │
│        # Evaluate fitness                                                    │
│        scored = Enum.map(pop, fn layout ->                                  │
│          {layout, fitness_fn.(layout, model)}                               │
│        end)                                                                  │
│                                                                              │
│        # Selection                                                           │
│        top_half = scored                                                     │
│        |> Enum.sort_by(fn {_, score} -> score end, :desc)                  │
│        |> Enum.take(10)                                                     │
│        |> Enum.map(fn {layout, _} -> layout end)                           │
│                                                                              │
│        # Crossover & mutation                                                │
│        crossover(top_half) ++ mutate(top_half)                              │
│      end)                                                                    │
│      |> Enum.max_by(&fitness_fn.(&1, model))                               │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  EVOLUTION CONSTRAINTS:                                                      │
│  ─────────────────────                                                       │
│  SC-EVOL-001: Core information model NEVER changes                          │
│  SC-EVOL-002: Safety-critical displays immutable                            │
│  SC-EVOL-003: Evolution requires offline validation                          │
│  SC-EVOL-004: Rollback capability preserved                                  │
│  SC-EVOL-005: Max 1 layout change per session                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART IX: MATHEMATICAL FOUNDATIONS

## 15. Category Theory Structures

### 15.1 Categorical UI Composition (L2: Concepts)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  MATHEMATICAL FOUNDATION: Category Theory                                    │
│  ─────────────────────────────────────────                                   │
│                                                                              │
│  The PRAJNA TUI system is structured as a category where:                    │
│                                                                              │
│  OBJECTS:                                                                    │
│  • Components (MetricCard, AlarmCard, NodeCard, ...)                        │
│  • Screens (Dashboard, AlarmCenter, CommandCenter, ...)                     │
│  • States (Model, Props, Context)                                            │
│  • Events (Click, Key, Alarm, Metric)                                        │
│                                                                              │
│  MORPHISMS:                                                                  │
│  • render: Component → Buffer                                                │
│  • handle_event: (Component, Event) → (Component, Commands)                 │
│  • transform: Layout → Layout                                                │
│  • validate: Layout → Verified Layout | Error                                │
│                                                                              │
│  COMPOSITION:                                                                │
│  • Sequential: f ∘ g (render after update)                                  │
│  • Parallel: f ⊗ g (simultaneous rendering)                                 │
│  • Monoidal: Identity layout, tensor product of grids                       │
│                                                                              │
│  FUNCTOR EXAMPLES:                                                           │
│                                                                              │
│  1. State Functor F: Model → View                                            │
│     Maps state changes to visual updates                                     │
│     Preserves structure: F(model1 ∘ model2) = F(model1) ∘ F(model2)         │
│                                                                              │
│  2. Event Functor G: Event → Command                                         │
│     Maps user events to system commands                                      │
│     Preserves composition of event handlers                                  │
│                                                                              │
│  3. Layout Functor H: Constraint → Rect                                      │
│     Maps layout constraints to concrete rectangles                           │
│     Preserves grid structure                                                 │
│                                                                              │
│  NATURAL TRANSFORMATIONS:                                                    │
│                                                                              │
│  η: Theme → Components                                                       │
│    Applies theme consistently across all components                          │
│    Naturality: For all f: A → B,                                            │
│                η_B ∘ Theme(f) = Components(f) ∘ η_A                         │
│                                                                              │
│  APPLICATIVE STRUCTURE:                                                      │
│                                                                              │
│  Component composition is applicative:                                       │
│  pure: a → Component a                                                       │
│  (<*>): Component (a → b) → Component a → Component b                       │
│                                                                              │
│  Example: Layout combination                                                 │
│  grid_layout = pure grid <*> header_component <*> body_component            │
│                                                                              │
│  MONAD STRUCTURE:                                                            │
│                                                                              │
│  Component rendering forms a monad:                                          │
│  return: a → Render a                                                        │
│  (>>=): Render a → (a → Render b) → Render b                                │
│                                                                              │
│  Example:                                                                    │
│  render_dashboard = do                                                       │
│    header <- render_header(model)                                            │
│    body <- render_body(model)                                                │
│    return combine(header, body)                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.2 Formal Specification Languages (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  FORMAL METHODS: Mathematica, Agda, Quint                                    │
│  ─────────────────────────────────────────                                   │
│                                                                              │
│  1. MATHEMATICA SPECIFICATION (Blueprint Layer)                              │
│  ─────────────────────────────────────────────                               │
│                                                                              │
│  (* TUI Component Algebra *)                                                 │
│  Component[name_, props_] := <|                                              │
│    "type" -> name,                                                           │
│    "props" -> props,                                                         │
│    "render" -> RenderFunction[name]                                          │
│  |>;                                                                         │
│                                                                              │
│  (* Grid Layout Composition *)                                               │
│  GridLayout[components_, cols_] :=                                           │
│    Partition[components, cols] // Map[RowLayout];                           │
│                                                                              │
│  (* Staleness Decay Function *)                                              │
│  StalenessBrightness[age_] := Max[0.2, 1 - 0.8 * (age / 60)];               │
│                                                                              │
│  (* STAMP Constraint Verification *)                                         │
│  VerifyConstraint[SC-HMI-001] :=                                            │
│    AllTrue[Components, NormalStateColor[#] == Gray700 &];                   │
│                                                                              │
│  (* Graph Invariants *)                                                      │
│  AgentReachability[G_] :=                                                    │
│    ConnectedGraphQ[G] && VertexCount[G] == 50;                              │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  2. AGDA PROOF (Eternal Truth Layer)                                         │
│  ────────────────────────────────────                                        │
│                                                                              │
│  -- Component composition is associative                                     │
│  module Prajna.TUI.Proofs where                                             │
│                                                                              │
│  open import Data.Product                                                    │
│  open import Relation.Binary.PropositionalEquality                          │
│                                                                              │
│  -- Widget type                                                              │
│  record Widget (A : Set) : Set where                                        │
│    field                                                                     │
│      render : Rect → Buffer → Buffer                                        │
│      minSize : ℕ × ℕ                                                        │
│                                                                              │
│  -- Composition is associative                                               │
│  comp-assoc : ∀ {A B C D} (f : A → B) (g : B → C) (h : C → D)              │
│             → (h ∘ g) ∘ f ≡ h ∘ (g ∘ f)                                    │
│  comp-assoc f g h = refl                                                    │
│                                                                              │
│  -- Staleness is monotonic                                                   │
│  staleness-mono : ∀ (t₁ t₂ : ℕ) → t₁ ≤ t₂                                  │
│                 → brightness t₁ ≥ brightness t₂                             │
│  staleness-mono = ...                                                        │
│                                                                              │
│  -- Layout constraints are satisfiable                                       │
│  layout-satisfiable : ∀ (constraints : List Constraint)                     │
│                     → ∃ (rect : Rect) → satisfies rect constraints          │
│  layout-satisfiable = ...                                                    │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  3. QUINT MODEL CHECKING (Behavioral Verification)                           │
│  ──────────────────────────────────────────────────                          │
│                                                                              │
│  // TUI State Machine                                                        │
│  module PrajnaTUI {                                                          │
│    type Screen = Dashboard | AlarmCenter | CommandCenter | Mesh | Settings  │
│                                                                              │
│    type UIState = {                                                          │
│      activeScreen: Screen,                                                   │
│      focusPath: List[string],                                               │
│      modal: Option[Modal],                                                   │
│      armedCommand: Option[Command]                                          │
│    }                                                                         │
│                                                                              │
│    // Navigation invariant: always on valid screen                           │
│    invariant validScreen {                                                   │
│      state.activeScreen in allScreens                                       │
│    }                                                                         │
│                                                                              │
│    // Two-step commit: armed before execute                                  │
│    invariant twoStepCommit {                                                 │
│      forall cmd in executedCommands:                                        │
│        cmd.isCritical implies wasArmedBefore(cmd)                           │
│    }                                                                         │
│                                                                              │
│    // Modal exclusivity: at most one modal                                   │
│    invariant singleModal {                                                   │
│      state.modal.isDefined implies not state.armedCommand.isDefined         │
│    }                                                                         │
│                                                                              │
│    // Temporal property: alarms eventually acknowledged                      │
│    temporal alarmAcknowledgment {                                           │
│      forall alarm in criticalAlarms:                                        │
│        eventually(alarm.acknowledged or alarm.resolved)                     │
│    }                                                                         │
│                                                                              │
│    // Action: navigate to screen                                             │
│    action navigate(target: Screen) {                                        │
│      state' = { ...state, activeScreen: target, focusPath: [] }            │
│    }                                                                         │
│                                                                              │
│    // Action: arm command (two-step commit)                                  │
│    action armCommand(cmd: Command) {                                        │
│      require cmd.isCritical                                                 │
│      require state.armedCommand.isEmpty                                     │
│      state' = { ...state, armedCommand: Some(cmd) }                        │
│    }                                                                         │
│  }                                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 15.3 Graph Theory Structures (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  GRAPH STRUCTURES: UI Navigation & Dependencies                              │
│  ─────────────────────────────────────────────                               │
│                                                                              │
│  1. NAVIGATION GRAPH G_nav = (Screens, Transitions)                          │
│  ──────────────────────────────────────────────────                          │
│                                                                              │
│     ┌─────────────┐                                                          │
│     │  Dashboard  │◀────────────────────────────────────────┐               │
│     └──────┬──────┘                                         │               │
│            │                                                 │               │
│     ┌──────┼──────┬──────────────┬──────────────┐           │               │
│     ▼      ▼      ▼              ▼              ▼           │               │
│  ┌─────┐┌─────┐┌─────┐     ┌─────────┐   ┌──────────┐       │               │
│  │Mesh ││Alarm││Cmds │     │Copilot  │   │Containers│       │               │
│  └──┬──┘└──┬──┘└──┬──┘     └────┬────┘   └────┬─────┘       │               │
│     │      │      │             │             │              │               │
│     └──────┴──────┴─────────────┴─────────────┴──────────────┘               │
│                                                                              │
│  Properties:                                                                 │
│  • Strongly connected (all screens reachable from all screens)               │
│  • Diameter ≤ 2 (any screen in ≤2 clicks)                                   │
│  • Hub = Dashboard (highest degree)                                          │
│                                                                              │
│  2. COMPONENT DEPENDENCY GRAPH G_dep = (Components, Dependencies)            │
│  ─────────────────────────────────────────────────────────────               │
│                                                                              │
│     MetricCard                                                               │
│        │                                                                     │
│        ├── Gauge (value, thresholds)                                        │
│        ├── Sparkline (history)                                              │
│        ├── TrendArrow (trend)                                               │
│        └── StatusIndicator (staleness)                                      │
│                                                                              │
│     AlarmCard                                                                │
│        │                                                                     │
│        ├── StatusIndicator (severity)                                       │
│        └── ActionButtons (handlers)                                         │
│                                                                              │
│  Properties:                                                                 │
│  • DAG (no circular dependencies)                                            │
│  • Max depth = 3                                                             │
│  • Leaf nodes = Primitives                                                   │
│                                                                              │
│  3. EVENT PROPAGATION GRAPH G_event = (Handlers, Propagation)                │
│  ──────────────────────────────────────────────────────────                  │
│                                                                              │
│     KeyEvent                                                                 │
│        │                                                                     │
│        ├── GlobalHandler (shortcuts)                                        │
│        │      │                                                             │
│        │      ├── NavigationHandler (1-9, Tab)                             │
│        │      └── CommandHandler (q, ?)                                    │
│        │                                                                     │
│        └── ScreenHandler (screen-specific)                                  │
│               │                                                              │
│               └── ComponentHandler (focused component)                      │
│                                                                              │
│  Properties:                                                                 │
│  • Event bubbling (child → parent)                                          │
│  • Event capture (parent → child)                                           │
│  • Stop propagation on handled                                              │
│                                                                              │
│  GRAPH ALGORITHMS FOR UI:                                                    │
│                                                                              │
│  defmodule Prajna.TUI.GraphAlgorithms do                                    │
│    @moduledoc "Graph algorithms for navigation and layout"                  │
│                                                                              │
│    # Shortest path for navigation                                            │
│    def navigation_path(from, to) do                                         │
│      Graph.dijkstra(navigation_graph(), from, to)                           │
│    end                                                                       │
│                                                                              │
│    # Topological sort for render order                                       │
│    def render_order(components) do                                          │
│      dependency_graph(components)                                            │
│      |> Graph.topsort()                                                     │
│    end                                                                       │
│                                                                              │
│    # Cycle detection for layout validation                                   │
│    def validate_no_cycles(layout) do                                        │
│      case Graph.find_cycle(layout_graph(layout)) do                         │
│        nil -> :ok                                                            │
│        cycle -> {:error, {:cycle, cycle}}                                   │
│      end                                                                     │
│    end                                                                       │
│                                                                              │
│    # Impact analysis for changes                                             │
│    def affected_components(changed_component) do                            │
│      dependency_graph()                                                      │
│      |> Graph.reachable_neighbors(changed_component)                        │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART X: INTEGRATED VERIFICATION

## 16. TDG (Test-Driven Generation) for UI

### 16.1 Component Test Specifications (L5: Verification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TDG: Test-Driven UI Generation                                              │
│  ───────────────────────────────                                             │
│                                                                              │
│  PRINCIPLE: Tests MUST exist and FAIL before component implementation       │
│                                                                              │
│  DUAL PROPERTY TESTING (PropCheck + ExUnitProperties):                       │
│                                                                              │
│  defmodule Prajna.TUI.Components.MetricCardTest do                          │
│    use ExUnit.Case                                                           │
│    use PropCheck                                                             │
│    import ExUnitProperties, except: [property: 2, property: 3, check: 2]    │
│    alias PropCheck.BasicTypes, as: PC                                       │
│    alias StreamData, as: SD                                                 │
│                                                                              │
│    # PropCheck: Structural properties                                        │
│    property "render fits within bounds" do                                  │
│      forall {value, max_val} <- PC.tuple([PC.pos_integer(), PC.pos_integer()]) do
│        card = build_metric_card(value, max_val)                             │
│        area = %Rect{x: 0, y: 0, width: 30, height: 4}                       │
│        buffer = MetricCard.render(card, area, Buffer.new(30, 4))            │
│                                                                              │
│        # All rendered cells within bounds                                    │
│        Enum.all?(buffer.cells, fn {{x, y}, _} ->                           │
│          x >= 0 and x < 30 and y >= 0 and y < 4                            │
│        end)                                                                  │
│      end                                                                     │
│    end                                                                       │
│                                                                              │
│    # ExUnitProperties: Behavioral properties                                 │
│    check all(                                                                │
│      value <- SD.integer(0..100),                                           │
│      threshold <- SD.integer(50..90)                                        │
│    ) do                                                                      │
│      card = build_metric_card(value, 100, threshold: threshold)             │
│      gauge = extract_gauge(card)                                            │
│                                                                              │
│      # Threshold coloring correct                                            │
│      if value > threshold do                                                │
│        assert gauge.color in [:amber, :red]                                 │
│      else                                                                    │
│        assert gauge.color == :gray                                          │
│      end                                                                     │
│    end                                                                       │
│                                                                              │
│    # STAMP constraint verification                                           │
│    test "SC-HMI-004: staleness decay visible" do                           │
│      fresh_card = build_metric_card(42, 100, staleness: 0)                  │
│      stale_card = build_metric_card(42, 100, staleness: 45)                 │
│                                                                              │
│      fresh_brightness = extract_brightness(fresh_card)                      │
│      stale_brightness = extract_brightness(stale_card)                      │
│                                                                              │
│      assert fresh_brightness > stale_brightness                             │
│      assert stale_brightness >= 0.4  # SC-HMI-004 minimum                  │
│    end                                                                       │
│                                                                              │
│    # AOR constraint verification                                             │
│    test "AOR-HMI-001: critical alarms always visible" do                    │
│      layout = build_dashboard_layout()                                      │
│      critical_alarm = build_alarm(:critical)                                │
│                                                                              │
│      # Even in compact mode, critical alarms visible                         │
│      compact_layout = apply_mode(layout, :compact)                          │
│      rendered = render_layout(compact_layout, [critical_alarm])             │
│                                                                              │
│      assert alarm_visible?(rendered, critical_alarm)                        │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  TDG WORKFLOW:                                                               │
│  ─────────────                                                               │
│  1. Write tests (must fail initially)                                        │
│  2. Generate minimal implementation                                          │
│  3. Verify tests pass                                                        │
│  4. Add STAMP constraint tests                                               │
│  5. Verify STAMP compliance                                                  │
│  6. Property-based testing for edge cases                                    │
│  7. Integration with Livebook validation                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 17. AOR (Agent Operating Rules) for UI

### 17.1 UI-Specific Operating Rules (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  AOR: Agent Operating Rules for UI                                           │
│  ──────────────────────────────────                                          │
│                                                                              │
│  AOR-UI-001: DARK COCKPIT DEFAULT                                            │
│  ─────────────────────────────────                                           │
│  All components MUST default to near-invisible state.                        │
│  Only anomalies highlighted.                                                 │
│                                                                              │
│  Implementation:                                                             │
│  def default_color(component_state) do                                      │
│    case component_state do                                                   │
│      :normal -> @gray_700                                                    │
│      :advisory -> @cyan_500                                                  │
│      :caution -> @amber_500                                                  │
│      :warning -> @orange_400                                                 │
│      :critical -> @red_500                                                   │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AOR-UI-002: TWO-STEP COMMIT REQUIRED                                        │
│  ─────────────────────────────────────                                       │
│  Critical operations MUST use two-step commit.                               │
│  Armed state expires after 60 seconds.                                       │
│                                                                              │
│  Critical operations: RESTART, SHUTDOWN, ISOLATE, DRAIN, POWER_OFF          │
│                                                                              │
│  Implementation:                                                             │
│  def execute_command(command, state) do                                     │
│    if critical?(command) do                                                  │
│      case state.armed_command do                                            │
│        nil -> {:arm, command}                                               │
│        ^command -> {:execute, command}                                      │
│        _other -> {:error, :wrong_command_armed}                             │
│      end                                                                     │
│    else                                                                      │
│      {:execute, command}                                                     │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AOR-UI-003: AI ADVISORY ONLY                                                │
│  ─────────────────────────────                                               │
│  AI suggestions MUST be marked advisory.                                     │
│  Human confirmation required for ALL AI-suggested actions.                   │
│                                                                              │
│  Implementation:                                                             │
│  def render_ai_insight(insight) do                                          │
│    """                                                                       │
│    ┌─ AI INSIGHT (ADVISORY ONLY) ────────────────────────────────────────┐  │
│    │ #{insight.message}                                                   │  │
│    │                                                                      │  │
│    │ Confidence: #{insight.confidence}                                    │  │
│    │                                                                      │  │
│    │ ⚠ This is a suggestion. Human operator makes final decision.       │  │
│    │                                                                      │  │
│    │ [APPLY] [DISMISS]                                                    │  │
│    └──────────────────────────────────────────────────────────────────────┘  │
│    """                                                                       │
│  end                                                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AOR-UI-004: STALENESS VISIBLE                                               │
│  ─────────────────────────────                                               │
│  Data staleness MUST be visually indicated.                                  │
│  Decay starts at 5 seconds, minimum brightness at 60 seconds.                │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AOR-UI-005: TREND CONTEXT                                                   │
│  ─────────────────────────                                                   │
│  All numeric values MUST show trend indicators.                              │
│  History sparkline SHOULD be visible when space permits.                     │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AOR-UI-006: GRACEFUL DEGRADATION                                            │
│  ─────────────────────────────────                                           │
│  If AI service unavailable, fall back to static layout.                      │
│  If metrics stale, show last known with warning.                             │
│  If component fails, show placeholder with error.                            │
│                                                                              │
│  Implementation:                                                             │
│  def render_with_fallback(component, data) do                               │
│    try do                                                                    │
│      component.render(data)                                                  │
│    rescue                                                                    │
│      e ->                                                                    │
│        Logger.error("Component render failed: #{inspect(e)}")               │
│        render_error_placeholder(component.name, e)                          │
│    end                                                                       │
│  end                                                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AOR-UI-007: OODA ALIGNMENT                                                  │
│  ─────────────────────────                                                   │
│  UI updates MUST align with OODA cycle phases.                               │
│  Observe phase: collect user interactions                                    │
│  Orient phase: update displays                                               │
│  Decide phase: show recommendations                                          │
│  Act phase: highlight executing actions                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART XI: STABLE CORE ARCHITECTURE

## 18. Immutable Information Model

### 18.1 Core Data Structures (L3: Specification)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  STABLE CORE: Information Model                                              │
│  ───────────────────────────────                                             │
│                                                                              │
│  PRINCIPLE: The core information model NEVER changes at runtime.             │
│  Only the presentation layer (TUI, GUI, Graphics) can evolve.               │
│                                                                              │
│  IMMUTABLE TYPES:                                                            │
│                                                                              │
│  @type metric :: %{                                                          │
│    id: UUID.t(),                                                             │
│    name: String.t(),                                                         │
│    value: number(),                                                          │
│    unit: String.t(),                                                         │
│    timestamp: DateTime.t(),                                                  │
│    source: entity_ref(),                                                     │
│    trend: trend(),                                                           │
│    staleness_seconds: non_neg_integer()                                      │
│  }                                                                           │
│                                                                              │
│  @type alarm :: %{                                                           │
│    id: UUID.t(),                                                             │
│    severity: :critical | :warning | :caution | :advisory,                   │
│    source: entity_ref(),                                                     │
│    message: String.t(),                                                      │
│    triggered_at: DateTime.t(),                                               │
│    acknowledged: boolean(),                                                  │
│    state: :active | :acked | :silenced | :resolved                          │
│  }                                                                           │
│                                                                              │
│  @type entity :: %{                                                          │
│    id: UUID.t(),                                                             │
│    type: :node | :container | :agent | :resource,                           │
│    name: String.t(),                                                         │
│    health: :healthy | :degraded | :critical | :unknown,                     │
│    lifecycle: :starting | :running | :stopping | :stopped,                  │
│    metadata: map()                                                           │
│  }                                                                           │
│                                                                              │
│  @type event :: %{                                                           │
│    id: UUID.t(),                                                             │
│    type: atom(),                                                             │
│    source: entity_ref(),                                                     │
│    payload: map(),                                                           │
│    timestamp: DateTime.t(),                                                  │
│    correlation_id: UUID.t() | nil                                           │
│  }                                                                           │
│                                                                              │
│  SEMANTIC API:                                                               │
│  ─────────────                                                               │
│  The presentation layer accesses data ONLY through semantic queries:        │
│                                                                              │
│  defmodule Prajna.Core.SemanticAPI do                                       │
│    @moduledoc """                                                            │
│    Stable semantic API between core and presentation layers.                │
│    This interface NEVER changes - only presentation can evolve.             │
│    """                                                                       │
│                                                                              │
│    # Metrics                                                                 │
│    def get_metric(node_id, metric_name)                                     │
│    def list_metrics(filter \\ %{})                                          │
│    def subscribe_metrics(pattern)                                           │
│                                                                              │
│    # Alarms                                                                  │
│    def list_active_alarms(severity \\ :all)                                 │
│    def acknowledge_alarm(alarm_id, operator_id)                             │
│    def silence_alarm(alarm_id, duration_minutes)                            │
│                                                                              │
│    # Entities                                                                │
│    def get_entity(entity_id)                                                │
│    def list_entities(type \\ :all)                                          │
│    def get_entity_health(entity_id)                                         │
│                                                                              │
│    # Commands                                                                │
│    def arm_command(command, target, operator_id)                            │
│    def confirm_command(command_id, confirmation_code)                       │
│    def cancel_armed_command(command_id)                                     │
│                                                                              │
│    # OODA                                                                    │
│    def get_ooda_state()                                                     │
│    def get_current_cycle()                                                  │
│  end                                                                         │
│                                                                              │
│  STABILITY GUARANTEE:                                                        │
│  ─────────────────────                                                       │
│  SC-CORE-001: Core types immutable at runtime                               │
│  SC-CORE-002: Semantic API version-locked                                   │
│  SC-CORE-003: All evolution in presentation layer                           │
│  SC-CORE-004: Core passes all STAMP constraints                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

**Document Control**
- Version: 3.0.0-UNIFIED-INTELLIGENT
- Date: 2025-12-27
- Author: Claude Opus 4.5 (Cybernetic Architect)
- Languages: Elixir, F#, Livebook
- AI Integration: OpenRouter (Claude 3.5 Sonnet, GPT-4o, Llama 3.1)
- Framework: SOPv5.11 + STAMP + C3I Dark Cockpit + Material 3 + OODA/AEE/CEA
- Mathematical: Category Theory + Graph Theory + Mathematica + Agda + Quint
- Standards: NASA-STD-3000, MIL-STD-1472H, NUREG-0700, ISA-101, IEC 61508 SIL-2
- Architecture: Stable Core + Evolvable Presentation + AI Advisory Layer
- Synthesized From:
  - PRAJNA_TUI_INFORMATION_ARCHITECTURE.md (1448 lines)
  - PRAJNA_TUI_COMPONENT_SYSTEM.md (1536 lines)
  - PRAJNA_TUI_DESIGN_GUIDE.md (809 lines)
  - Total synthesis: 3,793 lines → unified framework + AI/generative extensions
