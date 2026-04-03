# PRAJNA TUI Information Architecture
## Informational Elements, Behaviors & Geometric Structures

**Version**: 1.0.0 | **Date**: 2025-12-27 | **Status**: DRAFT
**Compliance**: NASA-STD-3000, MIL-STD-1472H, ISA-101, IEC 61508 SIL-2

---

## Table of Contents

1. [Informational Element Taxonomy](#1-informational-element-taxonomy)
2. [Behavioral Patterns](#2-behavioral-patterns)
3. [Geometric Structures & Components](#3-geometric-structures--components)
4. [State Display Representations](#4-state-display-representations)
5. [Update Flow Visualizations](#5-update-flow-visualizations)
6. [Time Flow Representations](#6-time-flow-representations)
7. [DAG Graph Impact Visualization](#7-dag-graph-impact-visualization)
8. [Integrated Component Library](#8-integrated-component-library)
9. [STAMP Constraints](#9-stamp-constraints)

---

## 1. Informational Element Taxonomy

### 1.1 Primary Information Classes

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA INFORMATION ELEMENT HIERARCHY                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─ METRICS (Quantitative) ─────────────────────────────────────────────┐   │
│  │  • Scalar:     Single numeric value (CPU: 42%, Latency: 12ms)        │   │
│  │  • Vector:     Multi-dimensional tuple (Position: [x, y, z])         │   │
│  │  • Tensor:     N-dimensional array (Correlation Matrix)              │   │
│  │  • Time-Series: Ordered sequence over time domain                    │   │
│  │  • Histogram:  Distribution buckets with counts                      │   │
│  │  • Summary:    Statistical aggregates (p50, p95, p99, mean, stddev)  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ EVENTS (Discrete) ──────────────────────────────────────────────────┐   │
│  │  • Alarm:      Threshold violation requiring attention               │   │
│  │  • Alert:      Informational notification                            │   │
│  │  • Command:    User-initiated action request                         │   │
│  │  • Transition: State machine state change                            │   │
│  │  • Heartbeat:  Periodic liveness signal                              │   │
│  │  • Span:       Distributed trace segment with parent/child           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ ENTITIES (Structural) ──────────────────────────────────────────────┐   │
│  │  • Node:       Compute/service instance (app-01, db-01)              │   │
│  │  • Container:  Isolated runtime environment                          │   │
│  │  • Agent:      Autonomous actor (50 agents in hierarchy)             │   │
│  │  • Resource:   Ash domain resource (User, Alarm, Device)             │   │
│  │  • Connection: Network link between nodes                            │   │
│  │  • Pool:       Resource collection (FLAME pool, DB pool)             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ STATES (Categorical) ───────────────────────────────────────────────┐   │
│  │  • Health:     HEALTHY | DEGRADED | CRITICAL | UNKNOWN               │   │
│  │  • Lifecycle:  STARTING | RUNNING | STOPPING | STOPPED               │   │
│  │  • Mode:       NORMAL | MAINTENANCE | EMERGENCY | SAFE               │   │
│  │  • Phase:      OBSERVE | ORIENT | DECIDE | ACT (OODA)                │   │
│  │  • Consensus:  PENDING | QUORUM | SPLIT | UNIFIED                    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─ RELATIONSHIPS (Graph) ──────────────────────────────────────────────┐   │
│  │  • Hierarchy:  Parent → Child (Agent hierarchy, Site → Zone)         │   │
│  │  • Dependency: A depends-on B (Service mesh)                         │   │
│  │  • Causality:  A caused B (Alarm correlation)                        │   │
│  │  • Temporal:   A before B (Event sequence)                           │   │
│  │  • Topology:   A connected-to B (Network mesh)                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Information Element Properties

| Element Type | Cardinality | Volatility | Staleness Threshold | Update Pattern |
|--------------|-------------|------------|---------------------|----------------|
| Scalar Metric | 1 | High (Hz-kHz) | 5s | Push/Pull |
| Time-Series | N (bounded) | Medium | 30s | Append-only |
| Event | 1 per occurrence | Instantaneous | N/A | Push |
| Entity | 1 | Low | 60s | On-change |
| State | 1 | Medium | 10s | Transition |
| Relationship | N:M | Low | 120s | On-change |

### 1.3 Information Flow Categories

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INFORMATION FLOW PATTERNS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TELEMETRY FLOW (Bottom-Up)                                                  │
│  ─────────────────────────────                                               │
│  Sensors → Collectors → Aggregators → Stores → Visualizers                   │
│                                                                              │
│  Container Health Sensor                                                     │
│       ↓ [metrics: cpu, mem, io]                                              │
│  SmartMetrics Collector                                                      │
│       ↓ [aggregated + enriched]                                              │
│  TelemetryStore (CubDB/TimescaleDB)                                          │
│       ↓ [queryable]                                                          │
│  Dashboard Widgets                                                           │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  COMMAND FLOW (Top-Down)                                                     │
│  ─────────────────────────────                                               │
│  Operator → UI → Guardian → Executor → Target → Feedback                     │
│                                                                              │
│  Human Operator                                                              │
│       ↓ [intent: restart app-03]                                             │
│  Command Center (Two-Step)                                                   │
│       ↓ [armed command]                                                      │
│  Guardian Safety Check                                                       │
│       ↓ [approved/denied]                                                    │
│  Capability Router                                                           │
│       ↓ [routed to backend]                                                  │
│  Container/Process Executor                                                  │
│       ↓ [execution result]                                                   │
│  Feedback to UI                                                              │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  INSIGHT FLOW (Lateral)                                                      │
│  ─────────────────────────────                                               │
│  Data → Analysis → Inference → Recommendation → Advisory                     │
│                                                                              │
│  Raw Metrics                                                                 │
│       ↓ [statistical analysis]                                               │
│  Anomaly Detection                                                           │
│       ↓ [pattern matching]                                                   │
│  AI Copilot Inference                                                        │
│       ↓ [confidence-scored insight]                                          │
│  Recommendation Engine                                                       │
│       ↓ [actionable suggestion]                                              │
│  Human Advisory Display                                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Behavioral Patterns

### 2.1 State Machine Behaviors

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ENTITY STATE MACHINE ARCHETYPES                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LIFECYCLE STATE MACHINE (Nodes/Containers)                                  │
│  ───────────────────────────────────────────                                 │
│                                                                              │
│       ┌────────────┐                                                         │
│       │  UNKNOWN   │ ←────── Initial / Lost Contact                          │
│       └─────┬──────┘                                                         │
│             │ discovered                                                     │
│             ▼                                                                │
│       ┌────────────┐       timeout        ┌────────────┐                    │
│       │  STARTING  │ ───────────────────→ │  FAILED    │                    │
│       └─────┬──────┘                       └─────┬──────┘                    │
│             │ ready                              │ restart                   │
│             ▼                                    │                           │
│       ┌────────────┐ ←───────────────────────────┘                          │
│       │  RUNNING   │ ←─┐                                                     │
│       └─────┬──────┘   │ resume                                              │
│             │ drain    │                                                     │
│             ▼          │                                                     │
│       ┌────────────┐   │                                                     │
│       │  STOPPING  │ ──┘                                                     │
│       └─────┬──────┘                                                         │
│             │ terminated                                                     │
│             ▼                                                                │
│       ┌────────────┐                                                         │
│       │  STOPPED   │                                                         │
│       └────────────┘                                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  ALARM STATE MACHINE                                                         │
│  ───────────────────                                                         │
│                                                                              │
│       ┌────────────┐                                                         │
│       │  NORMAL    │ ←─────────────────────────────┐                        │
│       └─────┬──────┘                               │                        │
│             │ threshold_violated                   │ cleared                │
│             ▼                                      │                        │
│       ┌────────────┐      escalate     ┌──────────┴──┐                      │
│       │  ACTIVE    │ ────────────────→ │  ESCALATED  │                      │
│       └─────┬──────┘                   └─────────────┘                      │
│             │ acknowledged                   │                               │
│             ▼                                │ resolved                      │
│       ┌────────────┐                         │                               │
│       │  ACKED     │ ────────────────────────┘                              │
│       └─────┬──────┘                                                         │
│             │ silenced                                                       │
│             ▼                                                                │
│       ┌────────────┐       timeout                                           │
│       │  SILENCED  │ ────────────────→ [return to ACTIVE]                   │
│       └────────────┘                                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  COMMAND STATE MACHINE (Two-Step Commit)                                     │
│  ───────────────────────────────────────                                     │
│                                                                              │
│       ┌────────────┐                                                         │
│       │   IDLE     │ ←─────────────────────────────────────────┐            │
│       └─────┬──────┘                                           │            │
│             │ arm_command                                      │            │
│             ▼                                                  │ reset      │
│       ┌────────────┐ ◎     cancel / timeout (5min)            │            │
│       │   ARMED    │ ────────────────────────────────────────→┤            │
│       └─────┬──────┘                                           │            │
│             │ confirm_with_code                                │            │
│             ▼                                                  │            │
│       ┌────────────┐ ●                                         │            │
│       │ EXECUTING  │ ──────────────────────────────────────────┤            │
│       └─────┬──────┘                                           │            │
│             │ complete / fail                                  │            │
│             ▼                                                  │            │
│       ┌────────────┐                                           │            │
│       │  RESULT    │ ──────────────────────────────────────────┘            │
│       │  ✓ / ✗     │                                                        │
│       └────────────┘                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Reactive Behaviors

| Behavior | Trigger | Response | Latency Target |
|----------|---------|----------|----------------|
| **Threshold Breach** | Metric > threshold | Alarm generation | < 100ms |
| **Staleness Detection** | No update > 5s | Visual degradation | Real-time |
| **Trend Calculation** | New metric sample | Trend vector update | < 50ms |
| **Correlation** | Multiple events | Relationship inference | < 500ms |
| **Prediction** | Time-series pattern | Future value estimate | < 1s |
| **Anomaly Detection** | Statistical deviation | Insight generation | < 2s |

### 2.3 Temporal Behaviors

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TEMPORAL BEHAVIOR PATTERNS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DECAY FUNCTION (Staleness)                                                  │
│  ──────────────────────────                                                  │
│                                                                              │
│  Freshness = e^(-t/τ)  where τ = staleness threshold                        │
│                                                                              │
│  100% ┤████████████                                                          │
│   75% ┤            ████████                                                  │
│   50% ┤                    ████████ ← Visual warning threshold              │
│   25% ┤                            ████████                                  │
│    0% ┤                                    ████████ ← Data invalid          │
│       └────────────────────────────────────────────────────────────────      │
│        0s    5s    10s   15s   20s   25s   30s                               │
│                                                                              │
│  Visual Representation:                                                      │
│  • Fresh (0-5s):  Full color, solid indicator ●                             │
│  • Aging (5-15s): Reduced saturation, half indicator ◐                      │
│  • Stale (>15s):  Grayed out, empty indicator ○                             │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  TREND MOMENTUM                                                              │
│  ──────────────────                                                          │
│                                                                              │
│  Trend = Σ(Δvalue[i] × w[i]) / Σw[i]  (weighted moving derivative)          │
│                                                                              │
│  Visual Symbols:                                                             │
│  • ↑↑ Rising Fast  (+25%/min)    Red/Amber attention                        │
│  • ↑  Rising       (+5%/min)     Amber advisory                             │
│  • →  Stable       (±5%/min)     Normal (no indicator)                      │
│  • ↓  Falling      (-5%/min)     Green (if metric should decrease)          │
│  • ↓↓ Falling Fast (-25%/min)   Context-dependent                           │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  OSCILLATION DETECTION                                                       │
│  ─────────────────────                                                       │
│                                                                              │
│  Flapping = count(sign_changes) > threshold in window                       │
│                                                                              │
│  Visual: ⚡ icon indicates unstable/oscillating value                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Geometric Structures & Components

### 3.1 Primitive Geometric Elements

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PRIMITIVE GEOMETRIC VOCABULARY                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  POINT INDICATORS (0D)                                                       │
│  ─────────────────────                                                       │
│                                                                              │
│  ●  Solid Circle     - Active/Connected/Healthy                              │
│  ◐  Half Circle      - Partial/Degraded/Stale                               │
│  ○  Empty Circle     - Inactive/Disconnected/Unknown                         │
│  ◎  Target Circle    - Armed/Ready/Selected                                  │
│  ⊙  Bullseye         - Focused/Primary                                       │
│  ✓  Checkmark        - Complete/Success/Verified                             │
│  ✗  Cross            - Failed/Error/Rejected                                 │
│  !  Exclamation      - Warning/Attention                                     │
│  ?  Question         - Unknown/Pending                                       │
│  ⚠  Triangle         - Caution                                               │
│  ⛔ Stop Sign        - Warning/Blocked                                       │
│  ☢  Radiation        - Critical/Danger                                       │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  LINE INDICATORS (1D)                                                        │
│  ─────────────────────                                                       │
│                                                                              │
│  ─── Solid Line      - Connection/Active link                                │
│  ┄┄┄ Dotted Line     - Weak/Degraded link                                   │
│  ╌╌╌ Dashed Line     - Optional/Pending link                                │
│  ═══ Double Line     - Strong/Primary path                                   │
│  ~~~ Wavy Line       - Unstable/Oscillating                                  │
│                                                                              │
│  Arrow Variants:                                                             │
│  →  Right Arrow      - Flow direction                                        │
│  ↔  Bidirectional    - Two-way flow                                         │
│  ⟳  Circular         - Cycle/Loop                                           │
│  ↺  Counter-Clock    - Rollback/Undo                                        │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AREA INDICATORS (2D)                                                        │
│  ─────────────────────                                                       │
│                                                                              │
│  ▓▓▓▓▓░░░░░  Progress Bar    - Percentage complete                          │
│  ████████░░  Gauge Fill      - Current value vs max                          │
│  ▁▂▃▄▅▆▇█   Sparkline        - Time-series trend                            │
│  ┌─────────┐                                                                 │
│  │ Block   │  Block/Box      - Container/Region                             │
│  └─────────┘                                                                 │
│                                                                              │
│  Fill Patterns:                                                              │
│  ░  Light shade     - Low intensity / Background                            │
│  ▒  Medium shade    - Medium intensity                                       │
│  ▓  Dark shade      - High intensity                                         │
│  █  Solid block     - Full / Maximum                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Composite Widget Structures

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      COMPOSITE WIDGET GEOMETRIES                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  METRIC CARD (Scalar + Trend + Sparkline)                                    │
│  ──────────────────────────────────────────                                  │
│                                                                              │
│  ┌─ CPU Usage ─────────────────────────────┐                                │
│  │                                          │                                │
│  │     42% ↑                               │  ← Primary value + trend       │
│  │     ▁▂▃▄▅▄▃▄▅▆▇▆▅▄▃▄▅▆                  │  ← Sparkline history          │
│  │     ●───────────────────────────────────│  ← Freshness indicator        │
│  │                                          │                                │
│  └──────────────────────────────────────────┘                                │
│                                                                              │
│  Structure: [Label] [Value] [Trend] [Sparkline] [Staleness]                  │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  GAUGE WIDGET (Scalar + Thresholds)                                          │
│  ─────────────────────────────────────                                       │
│                                                                              │
│  ┌─ Memory ────────────────────────────────┐                                │
│  │                                          │                                │
│  │   [████████████████████░░░░░] 68%       │                                │
│  │   0%        50%        80%  90%  100%   │                                │
│  │             │          │    │           │                                │
│  │           Normal    Caution Warning     │                                │
│  │                                          │                                │
│  └──────────────────────────────────────────┘                                │
│                                                                              │
│  Color Zones:                                                                │
│  • 0-50%:   Normal (gray/blue)                                              │
│  • 50-80%:  Elevated (no color)                                             │
│  • 80-90%:  Caution (amber)                                                 │
│  • 90-100%: Warning (red)                                                   │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  ALARM BADGE (Event + Severity + Age)                                        │
│  ───────────────────────────────────────                                     │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ ⚠ CAUTION │ app-03 │ CPU trending high (45% ↑↑) │ 12 min │ [ACK]│       │
│  └──────────────────────────────────────────────────────────────────┘       │
│    ↑           ↑        ↑                            ↑         ↑            │
│  Severity   Source    Message                      Age      Action          │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  NODE TILE (Entity + State + Metrics)                                        │
│  ───────────────────────────────────────                                     │
│                                                                              │
│  ┌─ app-01 ●──────────────────────────────┐                                 │
│  │  Role: CONTROLLER                       │                                 │
│  │  CPU:  ▓▓▓▓░░░░░░ 42% ↑                │                                 │
│  │  MEM:  ▓▓▓▓▓▓▓░░░ 68% →                │                                 │
│  │  LAT:  12ms                             │                                 │
│  └─────────────────────────────────────────┘                                 │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  TIMELINE SPAN (Event + Duration + Context)                                  │
│  ──────────────────────────────────────────                                  │
│                                                                              │
│  14:30 ├───█████████─────────────────────────┤ 14:35                        │
│        │   ↑                                  │                              │
│        │   Span: http.request (4.2s)         │                              │
│        │   ├─ db.query (2.1s)                │                              │
│        │   └─ cache.lookup (0.3s)            │                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Layout Containers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LAYOUT CONTAINER PATTERNS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  FLEX LAYOUT (Proportional)                                                  │
│  ──────────────────────────                                                  │
│                                                                              │
│  Direction: Horizontal                    Direction: Vertical                │
│  ┌─────────┬───────────────┐             ┌───────────────────┐              │
│  │  1:3    │      3:3      │             │        1:3        │              │
│  │  (25%)  │     (75%)     │             ├───────────────────┤              │
│  └─────────┴───────────────┘             │                   │              │
│                                          │        3:3        │              │
│                                          │                   │              │
│                                          └───────────────────┘              │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  GRID LAYOUT (Fixed + Proportional)                                          │
│  ──────────────────────────────────                                          │
│                                                                              │
│  ┌──────────┬──────────────────────┬──────────┐                             │
│  │ Fixed    │     Proportional     │  Fixed   │  ← Columns                  │
│  │ 20 cols  │         *            │ 20 cols  │                             │
│  ├──────────┼──────────────────────┼──────────┤                             │
│  │          │                      │          │  ← Rows                     │
│  │          │       Content        │          │                             │
│  │ Sidebar  │        Area          │ Details  │                             │
│  │          │                      │          │                             │
│  ├──────────┼──────────────────────┼──────────┤                             │
│  │ Footer   │       Status         │  Actions │  ← Fixed height             │
│  └──────────┴──────────────────────┴──────────┘                             │
│                                                                              │
│  Constraint Types:                                                           │
│  • Length(n)    - Fixed n cells                                             │
│  • Percentage(p) - p% of available space                                    │
│  • Min(n)       - At least n cells                                          │
│  • Max(n)       - At most n cells                                           │
│  • Fill(w)      - Remaining space with weight w                             │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  STACK LAYOUT (Z-Order)                                                      │
│  ───────────────────────                                                     │
│                                                                              │
│        Layer 3: Modal Dialog (topmost, captures input)                      │
│          ┌───────────────────┐                                              │
│          │   Confirm Delete? │                                              │
│          │  [Yes]    [No]    │                                              │
│          └───────────────────┘                                              │
│                 ↑                                                            │
│        Layer 2: Tooltip/Popup                                               │
│          ┌─────────────┐                                                    │
│          │ Hover info  │                                                    │
│          └─────────────┘                                                    │
│                 ↑                                                            │
│        Layer 1: Main Content (base)                                         │
│          ┌─────────────────────────────┐                                    │
│          │      Dashboard Content      │                                    │
│          └─────────────────────────────┘                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. State Display Representations

### 4.1 State Encoding Matrix

| State Category | Visual Encoding | Color | Icon | Animation |
|----------------|-----------------|-------|------|-----------|
| **HEALTHY** | Solid, bright | Green/Cyan | ● | None |
| **DEGRADED** | Reduced saturation | Amber | ◐ | None |
| **CRITICAL** | High contrast | Red | ☢ | Pulse |
| **UNKNOWN** | Dim, desaturated | Gray | ? | None |
| **STARTING** | Building up | Blue | ◎ | Fill animation |
| **STOPPING** | Fading out | Gray | ◌ | Drain animation |
| **ARMED** | Attention | Amber | ◎ | Slow pulse |
| **EXECUTING** | Active | Cyan | ● | Spinner |

### 4.2 Multi-State Display Patterns

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       MULTI-STATE DISPLAY PATTERNS                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ENTITY STATUS SUMMARY (Multiple Entities, Same Type)                        │
│  ──────────────────────────────────────────────────────                      │
│                                                                              │
│  Nodes: ●●●◐○  (3 healthy, 1 degraded, 1 offline)                           │
│                                                                              │
│  Or with counts:                                                             │
│  Nodes: [● 3] [◐ 1] [○ 1]  Total: 5                                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  ALARM SEVERITY DISTRIBUTION                                                 │
│  ─────────────────────────────                                               │
│                                                                              │
│  ☢ Critical: 0   ⛔ Warning: 2   ⚠ Caution: 5   ℹ Advisory: 12              │
│                                                                              │
│  As stacked bar:                                                             │
│  [░░░░░░░░░░░░░░░░████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓]                         │
│   Advisory (12)    Caution (5)      Warning (2)                             │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  PHASE INDICATOR (Sequential States)                                         │
│  ──────────────────────────────────                                          │
│                                                                              │
│  OODA Cycle: [✓ Observe] [● Orient] [○ Decide] [○ Act]                      │
│                                                                              │
│  Or as progress:                                                             │
│  Phase 2/4: ████████████░░░░░░░░░░  ORIENT                                  │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  QUORUM STATUS (Consensus)                                                   │
│  ─────────────────────────                                                   │
│                                                                              │
│  Sentinel Quorum: ●●●○○  (3/5 required: 3)  ✓ QUORUM                        │
│                                                                              │
│  With roles:                                                                 │
│  ★ Leader  ● Follower  ● Follower  ○ Offline  ○ Offline                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 State Transition Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STATE TRANSITION REPRESENTATIONS                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TRANSITION TIMELINE (Recent State Changes)                                  │
│  ──────────────────────────────────────────                                  │
│                                                                              │
│  app-03:                                                                     │
│  ────────────────────────────────────────────────────────────────────        │
│  14:00      14:10      14:20      14:30      14:40      14:50       now     │
│    ├──HEALTHY──┼──DEGRADED──┼──HEALTHY──┼──DEGRADED──┤                      │
│              ↑           ↑           ↑                                       │
│         CPU spike    Recovered    CPU spike                                  │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  TRANSITION LOG (Event Stream)                                               │
│  ─────────────────────────────                                               │
│                                                                              │
│  14:45:23  app-03  HEALTHY → DEGRADED    "CPU > 80%"                        │
│  14:30:15  app-01  STARTING → RUNNING    "Ready"                            │
│  14:28:00  app-02  RUNNING → STOPPING    "Drain initiated"                  │
│  14:25:45  obs-01  DEGRADED → HEALTHY    "Latency recovered"                │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  ANIMATED TRANSITION (During Change)                                         │
│  ─────────────────────────────────────                                       │
│                                                                              │
│  Before:  [●] RUNNING                                                        │
│  During:  [◎] RUNNING → STOPPING  ▁▂▃▄ draining...                          │
│  After:   [○] STOPPED                                                        │
│                                                                              │
│  Animation frames:                                                           │
│  Frame 1: ●→◐                                                                │
│  Frame 2: ◐→◌                                                                │
│  Frame 3: ◌→○                                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Update Flow Visualizations

### 5.1 Data Flow Indicators

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       DATA FLOW VISUALIZATIONS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  THROUGHPUT INDICATOR (Rate of Updates)                                      │
│  ────────────────────────────────────────                                    │
│                                                                              │
│  Metric Stream:  ⬤⬤⬤⬤⬤  142/s    (bright = active flow)                    │
│  Event Stream:   ⬤⬤◯◯◯   23/s     (dim = low activity)                     │
│  Command Rate:   ◯◯◯◯◯   0/s      (empty = idle)                           │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  PIPELINE STAGE INDICATORS                                                   │
│  ────────────────────────────                                                │
│                                                                              │
│  Ingestion   →   Enrich   →   Store   →   Display                           │
│     ●             ●            ●            ●                                │
│   142/s         140/s        140/s        140/s                              │
│    0ms           2ms          5ms          8ms                               │
│                                                                              │
│  With bottleneck detection:                                                  │
│                                                                              │
│  Ingestion   →   Enrich   →   Store   →   Display                           │
│     ●             ●            ⚠            ●                                │
│   142/s         140/s         80/s        80/s  ← Backpressure              │
│    0ms           2ms         125ms        133ms                              │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  BUFFER LEVEL INDICATORS                                                     │
│  ──────────────────────────                                                  │
│                                                                              │
│  Input Buffer:   [████████████░░░░░░░░] 60%  12,000/20,000                   │
│  Output Buffer:  [████░░░░░░░░░░░░░░░░] 20%   4,000/20,000                   │
│                                                                              │
│  With high-water mark:                                                       │
│  Input Buffer:   [█████████████████▓▓▓] 85%  ⚠ Near limit                   │
│                                       ↑                                      │
│                                 High-water mark (80%)                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Command Flow Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      COMMAND FLOW VISUALIZATION                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  TWO-STEP COMMIT FLOW                                                        │
│  ────────────────────                                                        │
│                                                                              │
│  Step 1: ARM                         Step 2: CONFIRM                         │
│  ┌────────────────────────────┐     ┌────────────────────────────┐          │
│  │ ○ Idle                     │     │ ◎ Armed                    │          │
│  │         ↓ [Click ARM]      │     │         ↓ [Enter Code]     │          │
│  │ ◎ Armed (5:00 countdown)   │     │ ● Executing...             │          │
│  │         ↓ [Timeout]        │     │         ↓                  │          │
│  │ ○ Expired                  │     │ ✓ Success / ✗ Failed       │          │
│  └────────────────────────────┘     └────────────────────────────┘          │
│                                                                              │
│  Visual Armed State:                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ ◎ ARMED: RESTART app-03                                         │        │
│  │ Expires: 4:32  [████████████████░░░░]                           │        │
│  │                                                                  │        │
│  │ Enter code to confirm: [____]     [CONFIRM] [CANCEL]            │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  COMMAND HISTORY WITH STATUS                                                 │
│  ──────────────────────────────                                              │
│                                                                              │
│  TIME       TARGET    COMMAND      STATUS     DURATION                       │
│  ────────────────────────────────────────────────────────                   │
│  14:45:23   app-03    RESTART      ● Running   12s...                       │
│  14:40:15   app-01    HEALTH_CHECK ✓ Success   1.2s                         │
│  14:35:00   app-02    DRAIN        ✓ Success   45s                          │
│  14:30:45   app-03    RESTART      ✗ Failed    0s      (Guardian denied)    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Feedback Loop Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OODA LOOP VISUALIZATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CYCLE STATUS RING                                                           │
│  ──────────────────                                                          │
│                                                                              │
│              OBSERVE                                                         │
│                ●                                                             │
│           ╭───────╮                                                          │
│          ╱    ⟳    ╲        Cycle Time: 0.82s (< 1s ✓)                      │
│    ACT  ○           ◐  ORIENT   Quality: 98%                                 │
│          ╲         ╱        Confidence: 85%                                  │
│           ╰───────╯                                                          │
│                ○                                                             │
│             DECIDE                                                           │
│                                                                              │
│  Phase Indicators:                                                           │
│  ●  Current phase (bright)                                                   │
│  ◐  Transitioning                                                            │
│  ○  Pending phase (dim)                                                      │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  OODA TIMELINE (Last 10 Cycles)                                              │
│  ────────────────────────────────                                            │
│                                                                              │
│  Cycle:  1    2    3    4    5    6    7    8    9   10                     │
│  Time:  0.8  0.9  0.7  1.2  0.8  0.9  0.8  0.8  0.9  0.8                    │
│          ●    ●    ●    ⚠    ●    ●    ●    ●    ●    ●                     │
│                         ↑                                                    │
│                    Slow cycle (threshold: 1.0s)                              │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  CYBERNETIC CONTROL LOOP                                                     │
│  ───────────────────────────                                                 │
│                                                                              │
│     ┌───────────────────────────────────────────────────┐                   │
│     │                    SETPOINT                        │                   │
│     │                    (Target)                        │                   │
│     └───────────────────────┬───────────────────────────┘                   │
│                             │                                                │
│                             ▼                                                │
│     ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                   │
│     │   SENSOR    │ → │ CONTROLLER  │ → │  ACTUATOR   │                   │
│     │  (Observe)  │    │  (Decide)   │    │   (Act)     │                   │
│     └─────────────┘    └─────────────┘    └─────────────┘                   │
│            ↑                                    │                            │
│            │           FEEDBACK                 │                            │
│            └────────────────────────────────────┘                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Time Flow Representations

### 6.1 Time-Series Visualization Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TIME-SERIES VISUALIZATION TYPES                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SPARKLINE (Compact Inline Trend)                                            │
│  ─────────────────────────────────                                           │
│                                                                              │
│  Character Set: ▁▂▃▄▅▆▇█ (8 levels)                                         │
│                                                                              │
│  CPU: ▁▂▃▄▅▄▃▂▃▄▅▆▇▆▅▄▃▄▅▆ avg: 45%                                        │
│       └──────────────────────────┘                                           │
│         20 samples (10 minutes at 30s interval)                              │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  LINE CHART (Full Time-Series)                                               │
│  ─────────────────────────────                                               │
│                                                                              │
│  100% ┤                                                                      │
│   80% ┤         ╭──╮                                                         │
│   60% ┤     ╭──╯    ╰──╮    ╭──╮                                            │
│   40% ┤ ╭──╯            ╰──╯    ╰──╮                                        │
│   20% ┤─╯                          ╰──                                       │
│    0% ┼────┬────┬────┬────┬────┬────┬────                                    │
│       14:00 14:10 14:20 14:30 14:40 14:50 15:00                              │
│                                                                              │
│  Unicode line characters:                                                    │
│  ─ │ ┼ ┤ ├ ┬ ┴ ╭ ╮ ╯ ╰ (box drawing)                                       │
│  ⣿⣷⣶⣦⣤⣀⡀⠀ (braille for high-res)                                           │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  AREA CHART (Stacked Metrics)                                                │
│  ─────────────────────────────                                               │
│                                                                              │
│  100% ┤████████████████████████████████████████                             │
│   80% ┤▓▓▓▓▓▓▓▓▓▓▓▓████████████████████████▓▓▓▓                             │
│   60% ┤▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓████████████████▓▓▓▓▒▒▒▒                             │
│   40% ┤░░▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒░░░░                             │
│   20% ┤░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░                             │
│    0% ┼────────────────────────────────────────                              │
│                                                                              │
│  Legend: █ CPU  ▓ Memory  ▒ I/O Wait  ░ Idle                                │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  BAR CHART (Histogram / Categorical Time)                                    │
│  ─────────────────────────────────────────                                   │
│                                                                              │
│  Alarms by Hour:                                                             │
│  ┌─────────────────────────────────────────────────────────────┐            │
│  │                     ████                                     │            │
│  │         ████        ████  ████                               │            │
│  │  ████   ████  ████  ████  ████  ████        ████             │            │
│  │  ████   ████  ████  ████  ████  ████  ████  ████  ████      │            │
│  ├──00────04────08────12────16────20────24─────────────────────┤            │
│  └─────────────────────────────────────────────────────────────┘            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Time Window Controls

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       TIME WINDOW CONTROLS                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ZOOM CONTROL BAR                                                            │
│  ─────────────────                                                           │
│                                                                              │
│  [5m] [15m] [1h] [●6h] [24h] [7d] [30d] [Custom...]                         │
│                  ↑                                                           │
│            Current selection                                                 │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  TIME SCRUBBER                                                               │
│  ─────────────────                                                           │
│                                                                              │
│  ◀ ────────────────────────[▓▓▓▓▓▓▓]────────────────────────── ▶           │
│    │                        ↑ visible window                    │            │
│   Start                                                       End            │
│   (2025-12-26)                                        (2025-12-27)          │
│                                                                              │
│  Controls:                                                                   │
│  • Drag window to pan                                                        │
│  • Drag edges to resize                                                      │
│  • Click outside to jump                                                     │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  LIVE MODE INDICATOR                                                         │
│  ─────────────────────                                                       │
│                                                                              │
│  [● LIVE] ←→ [PAUSED]                                                        │
│                                                                              │
│  Live:   Auto-scroll to present, new data appends                           │
│  Paused: Time frozen, allows historical inspection                          │
│                                                                              │
│  Auto-resume after 30s of inactivity when paused                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Event Timeline Representations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      EVENT TIMELINE REPRESENTATIONS                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  VERTICAL EVENT LOG (Chronological)                                          │
│  ───────────────────────────────────                                         │
│                                                                              │
│  14:45:23 │ ⚠ app-03 │ CPU threshold exceeded (85%)                         │
│  14:44:15 │ ● app-01 │ Health check passed                                  │
│  14:43:00 │ → admin  │ Command issued: RESTART app-02                       │
│  14:42:30 │ ✓ app-02 │ Container restarted successfully                     │
│  14:40:00 │ ⛔ db-01  │ Connection pool exhausted                            │
│           │          │                                                       │
│     ↑     │    ↑     │     ↑                                                │
│   Time   Source    Message                                                   │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  HORIZONTAL TIMELINE (Swim Lanes)                                            │
│  ─────────────────────────────────                                           │
│                                                                              │
│           14:30    14:35    14:40    14:45    14:50    14:55                 │
│              │        │        │        │        │        │                  │
│  app-01  ────●────────●────────●────────●────────●────────●──                │
│  app-02  ────●────────●───✗────●────────●────────●────────●──                │
│  app-03  ────●────────●────────●───⚠────●────────●────────●──                │
│  db-01   ────●────────●────────●────────●───⛔───●────────●──                │
│                                                                              │
│  Markers:                                                                    │
│  ●  Normal heartbeat                                                         │
│  ✗  Failure event                                                            │
│  ⚠  Warning event                                                            │
│  ⛔ Critical event                                                           │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  CORRELATION VIEW (Aligned Events)                                           │
│  ───────────────────────────────────                                         │
│                                                                              │
│  Incident Timeline: High Latency Alert                                       │
│  ─────────────────────────────────────                                       │
│                                                                              │
│  14:40:00 ├─── db-01: Connection pool warning ───┐                          │
│  14:40:05 │                                      │                          │
│  14:40:10 ├─── app-01: Slow query detected ──────┼── Correlated             │
│  14:40:15 │                                      │                          │
│  14:40:20 ├─── app-02: Request timeout ──────────┼── Correlated             │
│  14:40:25 │                                      │                          │
│  14:40:30 ├─── ALERT: High latency threshold ────┘                          │
│                                                                              │
│  Root Cause: db-01 pool exhaustion                                          │
│  Impact: app-01, app-02 degraded service                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. DAG Graph Impact Visualization

### 7.1 Dependency Graph Structures

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEPENDENCY GRAPH STRUCTURES                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SERVICE DEPENDENCY MAP                                                      │
│  ──────────────────────                                                      │
│                                                                              │
│                    ┌─────────┐                                               │
│                    │ Gateway │                                               │
│                    │  (API)  │                                               │
│                    └────┬────┘                                               │
│                         │                                                    │
│           ┌─────────────┼─────────────┐                                     │
│           │             │             │                                     │
│           ▼             ▼             ▼                                     │
│      ┌─────────┐   ┌─────────┐   ┌─────────┐                                │
│      │ Auth    │   │ Alarms  │   │ Video   │                                │
│      │ Service │   │ Service │   │ Service │                                │
│      └────┬────┘   └────┬────┘   └────┬────┘                                │
│           │             │             │                                     │
│           └─────────────┼─────────────┘                                     │
│                         │                                                    │
│                         ▼                                                    │
│                    ┌─────────┐                                               │
│                    │   DB    │                                               │
│                    │ (PG17)  │                                               │
│                    └─────────┘                                               │
│                                                                              │
│  Edge Types:                                                                 │
│  ─── Sync dependency (blocking)                                             │
│  ┄┄┄ Async dependency (non-blocking)                                        │
│  ═══ Critical path                                                          │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  IMPACT PROPAGATION VIEW                                                     │
│  ───────────────────────────                                                 │
│                                                                              │
│  When DB fails:                                                              │
│                                                                              │
│                    ┌─────────┐                                               │
│                    │ Gateway │ ⚠ Degraded (3 deps affected)                 │
│                    └────┬────┘                                               │
│                         │                                                    │
│           ┌─────────────┼─────────────┐                                     │
│           │             │             │                                     │
│           ▼             ▼             ▼                                     │
│      ┌─────────┐   ┌─────────┐   ┌─────────┐                                │
│      │  Auth   │   │ Alarms  │   │  Video  │                                │
│      │   ⚠     │   │   ⚠     │   │   ⚠     │  All degraded                 │
│      └────┬────┘   └────┬────┘   └────┬────┘                                │
│           │             │             │                                     │
│           └─────────────┼─────────────┘                                     │
│                    ╔════╧════╗                                               │
│                    ║   DB    ║                                               │
│                    ║   ☢     ║  ← Root cause (CRITICAL)                     │
│                    ╚═════════╝                                               │
│                                                                              │
│  Visual encoding:                                                            │
│  • Double border: Root cause                                                 │
│  • ⚠ icon: Impacted by upstream failure                                     │
│  • Colored edges: Propagation path                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Trace Waterfall Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      TRACE WATERFALL VISUALIZATION                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DISTRIBUTED TRACE (Span Hierarchy)                                          │
│  ──────────────────────────────────                                          │
│                                                                              │
│  Trace ID: abc123... | Total Duration: 234ms | Spans: 12                    │
│                                                                              │
│  Service              0ms        50ms       100ms       150ms       200ms    │
│  ─────────────────────┼──────────┼──────────┼───────────┼──────────┼────    │
│                                                                              │
│  gateway              ████████████████████████████████████████████████       │
│  ├─ http.request      ████████████████████████████████████████████████       │
│  │                                                                           │
│  auth-service                ████████████                                    │
│  ├─ auth.validate            ████████████                                    │
│  │  └─ db.query                 ████████                                     │
│  │                                                                           │
│  alarms-service                           ████████████████████               │
│  ├─ alarms.list                           ████████████████████               │
│  │  ├─ db.query                                ████████████                  │
│  │  └─ cache.check                        ████                               │
│  │                                                                           │
│  video-service                                              ██████████       │
│  └─ video.metadata                                          ██████████       │
│                                                                              │
│  Legend:                                                                     │
│  ████  Span duration (colored by service)                                   │
│  ├─    Parent-child relationship                                            │
│  Error spans shown in red                                                    │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  SPAN DETAIL VIEW (Selected Span)                                            │
│  ─────────────────────────────────                                           │
│                                                                              │
│  ┌─ db.query ──────────────────────────────────────────────────────┐        │
│  │ Service: auth-service                                            │        │
│  │ Duration: 45ms                                                   │        │
│  │ Status: OK                                                       │        │
│  │                                                                  │        │
│  │ Attributes:                                                      │        │
│  │   db.system: postgresql                                          │        │
│  │   db.statement: SELECT * FROM users WHERE id = $1                │        │
│  │   db.rows_affected: 1                                            │        │
│  │                                                                  │        │
│  │ Events:                                                          │        │
│  │   [0ms] Query started                                            │        │
│  │   [42ms] Query completed                                         │        │
│  └──────────────────────────────────────────────────────────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 Agent Hierarchy DAG

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AGENT HIERARCHY DAG                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  50-AGENT ARCHITECTURE (3-Level Hierarchy)                                   │
│  ──────────────────────────────────────────                                  │
│                                                                              │
│                          ┌──────────────────┐                                │
│                          │    EXECUTIVE     │                                │
│                          │   (1 Agent)      │                                │
│                          │  ● Coordinating  │                                │
│                          └────────┬─────────┘                                │
│                                   │                                          │
│        ┌──────────┬───────────────┼───────────────┬──────────┐              │
│        │          │               │               │          │              │
│        ▼          ▼               ▼               ▼          ▼              │
│   ┌─────────┐ ┌─────────┐   ┌─────────┐   ┌─────────┐ ┌─────────┐          │
│   │ ACCESS  │ │ ALARMS  │   │  VIDEO  │   │  SITES  │ │ DEVICES │          │
│   │ Domain  │ │ Domain  │   │ Domain  │   │ Domain  │ │ Domain  │          │
│   │  ●      │ │  ●      │   │  ⚠      │   │  ●      │ │  ●      │          │
│   └────┬────┘ └────┬────┘   └────┬────┘   └────┬────┘ └────┬────┘          │
│        │          │               │               │          │              │
│    ┌───┴───┐  ┌───┴───┐     ┌───┴───┐     ┌───┴───┐    ┌───┴───┐          │
│    ▼       ▼  ▼       ▼     ▼       ▼     ▼       ▼    ▼       ▼          │
│   W1-W4   W5-W8   W9-W12   W13-W16   W17-W20   W21-W24                     │
│   (Workers for each domain)                                                 │
│                                                                              │
│  Visual Encoding:                                                            │
│  • Size: Reflects responsibility scope                                       │
│  • Color: Health status                                                      │
│  • Border: Selection/focus                                                   │
│  • Edge thickness: Communication volume                                      │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  COLLAPSED VIEW (Domain Summary)                                             │
│  ──────────────────────────────────                                          │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ EXECUTIVE [●]                                                    │        │
│  ├─────────────────────────────────────────────────────────────────┤        │
│  │ ACCESS   [●●●●]    ALARMS  [●●●●]    VIDEO   [●●◐●]            │        │
│  │ SITES    [●●●●]    DEVICES [●●●●]    ...                        │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                              │
│  Compact notation: [●●●●] = 4 healthy workers                               │
│                    [●●◐●] = 3 healthy, 1 degraded                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.4 Causal Chain Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CAUSAL CHAIN VISUALIZATION                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ROOT CAUSE ANALYSIS VIEW                                                    │
│  ────────────────────────                                                    │
│                                                                              │
│  Incident: Service Degradation (2025-12-27 14:40)                           │
│                                                                              │
│  ROOT CAUSE                                                                  │
│  ╔═══════════════════════════════════════════════════════════════╗          │
│  ║  14:40:00  DB Connection Pool Exhausted                       ║          │
│  ║            db-01 | max_connections: 100 | used: 100           ║          │
│  ╚═══════════════════════════════════╤═══════════════════════════╝          │
│                                      │                                       │
│                                      │ caused                                │
│                                      ▼                                       │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │  14:40:05  Query Timeouts                                     │          │
│  │            auth-service, alarms-service, video-service        │          │
│  └───────────────────────────┬───────────────────────────────────┘          │
│                              │                                               │
│               ┌──────────────┼──────────────┐                               │
│               │              │              │                               │
│               ▼              ▼              ▼                               │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐                      │
│  │ 14:40:10      │ │ 14:40:12      │ │ 14:40:15      │                      │
│  │ Auth slowdown │ │ Alarm delays  │ │ Video errors  │                      │
│  └───────────────┘ └───────────────┘ └───────────────┘                      │
│                              │                                               │
│                              │ aggregated                                    │
│                              ▼                                               │
│  ┌───────────────────────────────────────────────────────────────┐          │
│  │  14:40:30  User-Facing Alert: Service Degradation             │          │
│  │            Response time > 5s threshold                        │          │
│  └───────────────────────────────────────────────────────────────┘          │
│                                                                              │
│  Time to Root Cause: 30 seconds                                             │
│  Blast Radius: 3 services, ~1000 requests affected                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Integrated Component Library

### 8.1 Component Taxonomy

| Category | Component | Information Type | Behavior | Geometry |
|----------|-----------|------------------|----------|----------|
| **Metrics** | ScalarCard | Scalar + Trend | Reactive | Card |
| **Metrics** | GaugeWidget | Scalar + Thresholds | Threshold | Bar |
| **Metrics** | SparklineWidget | Time-Series | Temporal | Line |
| **Metrics** | ChartWidget | Multi-Series | Temporal | Area/Line |
| **Events** | AlarmBadge | Event + Severity | State Machine | Badge |
| **Events** | EventLog | Event Stream | Temporal | List |
| **Events** | TimelineWidget | Events + Time | Temporal | Timeline |
| **Entities** | NodeTile | Entity + State + Metrics | Lifecycle | Tile |
| **Entities** | TreeView | Hierarchy | Navigation | Tree |
| **Entities** | GraphView | Relationships | DAG | Graph |
| **State** | StatusIndicator | State | Discrete | Icon |
| **State** | PhaseIndicator | Sequential States | Progress | Progress |
| **State** | QuorumDisplay | Consensus | Voting | Dots |
| **Flow** | PipelineWidget | Flow Stages | Throughput | Pipeline |
| **Flow** | CommandTracker | Command + Status | Two-Step | Timeline |
| **Flow** | OODAWidget | Feedback Loop | Cyclic | Ring |
| **Graph** | DependencyMap | Service DAG | Impact | Graph |
| **Graph** | TraceWaterfall | Span Hierarchy | Temporal DAG | Gantt |
| **Graph** | CausalChain | Event DAG | Causality | Flow |

### 8.2 Component Composition Patterns

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COMPONENT COMPOSITION PATTERNS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PATTERN 1: CARD + DETAIL (Master-Detail)                                    │
│  ──────────────────────────────────────────                                  │
│                                                                              │
│  ┌──────────────────────┐     ┌─────────────────────────────────────┐       │
│  │ ● app-01  42% ↑      │ ←─→ │ app-01 Details                      │       │
│  │ ● app-02  38% →      │     │                                     │       │
│  │ ⚠ app-03  45% ↑↑     │     │ CPU:  ████████░░ 45%               │       │
│  │ ● app-04  31% ↓      │     │ MEM:  ██████░░░░ 65%               │       │
│  │ ● app-05  28% →      │     │ NET:  ███░░░░░░░ 18 Mbps           │       │
│  │                      │     │                                     │       │
│  │ [Select to view →]   │     │ Sparkline: ▁▂▃▄▅▆▇█▇▆▅▄▃▄▅▆       │       │
│  └──────────────────────┘     │                                     │       │
│     Master List               │ Alarms: 1 ⚠                        │       │
│                               │ [RESTART] [LOGS] [SHELL]           │       │
│                               └─────────────────────────────────────┘       │
│                                  Detail Panel                                │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  PATTERN 2: OVERVIEW + DRILL-DOWN (Hierarchical)                             │
│  ──────────────────────────────────────────────────                          │
│                                                                              │
│  Level 0: System Health                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ System: ● HEALTHY | Score: 94% | Nodes: 5/5 | Alarms: 7        │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                               │                                              │
│                               ▼ Click to expand                              │
│  Level 1: Node Grid                                                          │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐                         │
│  │app-01 │ │app-02 │ │app-03 │ │app-04 │ │app-05 │                         │
│  │ 42% ● │ │ 38% ● │ │ 45% ⚠ │ │ 31% ● │ │ 28% ● │                         │
│  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘                         │
│                               │                                              │
│                               ▼ Click node                                   │
│  Level 2: Node Detail (Full metrics, logs, actions)                         │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  PATTERN 3: TIMELINE + CORRELATION (Temporal)                                │
│  ─────────────────────────────────────────────                               │
│                                                                              │
│  ┌─ Timeline (Primary) ─────────────────────────────────────────────┐       │
│  │ 14:30      14:35      14:40      14:45      14:50               │       │
│  │   │          │          │          │          │                  │       │
│  │   ●──────────●─────✗────●──────────●──────────●                 │       │
│  │                     │                                            │       │
│  └─────────────────────│────────────────────────────────────────────┘       │
│                        │                                                     │
│                        ▼ Click event                                         │
│  ┌─ Correlated Events ───────────────────────────────────────────────┐      │
│  │ 14:40:00 db-01: Pool exhausted ← Root cause                       │      │
│  │ 14:40:05 auth-service: Query timeout                              │      │
│  │ 14:40:10 alarms-service: Query timeout                            │      │
│  │ 14:40:15 ALERT: Service degradation                               │      │
│  └───────────────────────────────────────────────────────────────────┘      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.3 State Synchronization Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STATE SYNCHRONIZATION MODEL                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  UNIDIRECTIONAL DATA FLOW (Elm Architecture)                                 │
│  ────────────────────────────────────────────                                │
│                                                                              │
│       ┌─────────────────────────────────────────────────────────┐           │
│       │                       MODEL                              │           │
│       │  (Application State: metrics, entities, events, UI)     │           │
│       └───────────────────────────┬─────────────────────────────┘           │
│                                   │                                          │
│                                   │ state                                    │
│                                   ▼                                          │
│       ┌─────────────────────────────────────────────────────────┐           │
│       │                        VIEW                              │           │
│       │  (Render components based on current state)             │           │
│       └───────────────────────────┬─────────────────────────────┘           │
│                                   │                                          │
│                                   │ user actions                             │
│                                   ▼                                          │
│       ┌─────────────────────────────────────────────────────────┐           │
│       │                      MESSAGE                             │           │
│       │  (UserClicked, MetricReceived, TimerTick, etc.)         │           │
│       └───────────────────────────┬─────────────────────────────┘           │
│                                   │                                          │
│                                   │ dispatch                                 │
│                                   ▼                                          │
│       ┌─────────────────────────────────────────────────────────┐           │
│       │                       UPDATE                             │           │
│       │  (Pure function: (Model, Msg) -> (Model, Cmd))          │           │
│       └───────────────────────────┬─────────────────────────────┘           │
│                                   │                                          │
│                                   │ new state + commands                     │
│                                   ▼                                          │
│       ┌─────────────────────────────────────────────────────────┐           │
│       │                      COMMANDS                            │           │
│       │  (Side effects: HTTP, WebSocket, Timers, Storage)       │           │
│       └───────────────────────────┬─────────────────────────────┘           │
│                                   │                                          │
│                                   │ async results                            │
│                                   └──────────────→ MESSAGE                   │
│                                                                              │
│  ─────────────────────────────────────────────────────────────────────────   │
│                                                                              │
│  MESSAGE TYPES FOR PRAJNA                                                    │
│  ──────────────────────────                                                  │
│                                                                              │
│  Telemetry Messages:                                                         │
│  • MetricReceived(node_id, metric_type, value, timestamp)                   │
│  • MetricStale(node_id, metric_type)                                        │
│  • EntityStateChanged(entity_id, old_state, new_state)                      │
│                                                                              │
│  Event Messages:                                                             │
│  • AlarmTriggered(alarm)                                                    │
│  • AlarmAcknowledged(alarm_id, user)                                        │
│  • CommandIssued(command)                                                   │
│  • CommandCompleted(command_id, result)                                     │
│                                                                              │
│  UI Messages:                                                                │
│  • TabSelected(tab_id)                                                      │
│  • NodeSelected(node_id)                                                    │
│  • TimeWindowChanged(start, end)                                            │
│  • RefreshRequested                                                         │
│                                                                              │
│  System Messages:                                                            │
│  • TickEvent(interval)                                                      │
│  • WindowResized(width, height)                                             │
│  • WebSocketMessage(payload)                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. STAMP Constraints

### 9.1 Information Display Constraints (SC-HMI-*)

| Constraint ID | Description | Verification |
|---------------|-------------|--------------|
| SC-HMI-001 | Dark Cockpit: Normal state nearly invisible | Visual audit |
| SC-HMI-002 | Anomalies in amber/red with trend indicators | Color compliance |
| SC-HMI-003 | Staleness visual decay after 5s threshold | Timing test |
| SC-HMI-004 | Two-step commit for critical commands | Interaction test |
| SC-HMI-005 | AI insights marked ADVISORY only | Label presence |

### 9.2 Information Element Constraints (SC-INFO-*)

| Constraint ID | Description | Verification |
|---------------|-------------|--------------|
| SC-INFO-001 | Metrics include timestamp and source | Schema validation |
| SC-INFO-002 | Events include severity classification | Enum check |
| SC-INFO-003 | Entities include lifecycle state | State machine |
| SC-INFO-004 | Relationships bidirectionally navigable | Graph traversal |
| SC-INFO-005 | Time-series bounded to retention window | Buffer limit |

### 9.3 Behavioral Constraints (SC-BEH-*)

| Constraint ID | Description | Verification |
|---------------|-------------|--------------|
| SC-BEH-001 | State transitions follow defined FSM | Model check |
| SC-BEH-002 | Threshold breaches generate alarms < 100ms | Latency test |
| SC-BEH-003 | Staleness detection real-time | Continuous |
| SC-BEH-004 | Commands require Guardian approval | Integration test |
| SC-BEH-005 | OODA cycle completes < 1s | Performance |

### 9.4 Geometric Constraints (SC-GEO-*)

| Constraint ID | Description | Verification |
|---------------|-------------|--------------|
| SC-GEO-001 | Layout adapts to terminal resize | Resize test |
| SC-GEO-002 | Critical info visible without scrolling | Layout audit |
| SC-GEO-003 | Modal dialogs centered and dismissable | Interaction |
| SC-GEO-004 | Graph layouts prevent edge overlap | Layout algorithm |
| SC-GEO-005 | Sparklines minimum 20 samples visible | Render test |

---

## Appendix A: Symbol Reference

```
STATUS INDICATORS
● Active/Healthy     ◐ Partial/Degraded    ○ Inactive/Unknown
◎ Armed/Ready        ⊙ Focused

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
```

---

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
Warning:        #EF4444 (red-500)       Action required
Critical:       #DC2626 (red-600)       + pulse animation

Success:        #10B981 (emerald-500)
Focus:          #3B82F6 (blue-500)
Selection:      #1E40AF (blue-800)
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-27
**Author**: Claude Code (Cybernetic Architect)
**Compliance**: NASA-STD-3000, MIL-STD-1472H, ISA-101, IEC 61508 SIL-2
