# PRAJNA C3I Mesh Cockpit - 5-Level Specification Document

**Version**: 2.0.0 (Unified with Biomorphic Blueprint) | **Date**: 2025-12-28 | **Status**: ACTIVE
**Author**: Cybernetic Architect (Gemini/Claude)
**Core Specification**: [PRAJNA_BIOMORPHIC_BLUEPRINT.md](./PRAJNA_BIOMORPHIC_BLUEPRINT.md)
**Integration Analysis**: [PRAJNA_SYSTEMATIC_INTEGRATION_ANALYSIS.md](./PRAJNA_SYSTEMATIC_INTEGRATION_ANALYSIS.md)
**STAMP**: SC-C3I-001 to SC-C3I-004, SC-HMI-001 to SC-HMI-004, SC-AI-001 to SC-AI-004, SC-BIO-*

---

## Table of Contents

- [Level 1: Executive Overview](#level-1-executive-overview)
- [Level 2: Architecture & Design](#level-2-architecture--design)
- [Level 3: Component Specifications](#level-3-component-specifications)
- [Level 4: Implementation Details](#level-4-implementation-details)
- [Level 5: Operational Procedures](#level-5-operational-procedures)
- [Appendix A: PROMETHEUS Verification](#appendix-a-prometheus-verification)
- [Appendix B: STAMP Compliance Matrix](#appendix-b-stamp-compliance-matrix)
- [Appendix C: TDG Test-Driven Generation](#appendix-c-tdg-test-driven-generation)
- [Appendix D: AOR Agent Operating Rules](#appendix-d-aor-agent-operating-rules)
- [Appendix E: Fractal Logging & Telemetry](#appendix-e-fractal-logging--telemetry)
- [Appendix F: Zenoh Dataflow](#appendix-f-zenoh-dataflow)
- [Appendix G: Livebook Dashboards](#appendix-g-livebook-dashboards)
- [Appendix J: C3I Visual Display Principles](#appendix-j-c3i-visual-display-principles)
- [Appendix K: Essential Research Canon & Design Standards](#appendix-k-essential-research-canon--design-standards)
- [Appendix M: Terminal User Interface (TUI) Reference Implementations](#appendix-m-terminal-user-interface-tui-reference-implementations)

---

# Level 1: Executive Overview

## L1.1 Mission Statement

**PRAJNA** (Predictive Risk Analysis & Judgment for Network Autonomics) is a safety-critical Command, Control, Communications, and Intelligence (C3I) cockpit for distributed system monitoring. It implements the "Dark Cockpit" philosophy from aviation and nuclear control systems, where normalcy is invisible and only deviations demand attention.

## L1.2 Core Objectives

| Objective | Description | Success Criteria |
|-----------|-------------|------------------|
| **Situational Awareness** | Real-time visibility into distributed mesh health | <100ms latency for metric updates |
| **Predictive Intelligence** | AI-powered anomaly detection and forecasting | Confidence scores ≥0.8 for predictions |
| **Safe Command Execution** | Two-step commit for critical operations | 100% command audit logging |
| **Human-in-the-Loop** | AI advisory with human decision authority | SC-AI-001 compliance |

## L1.3 System Scope

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRAJNA C3I MESH COCKPIT                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        PRESENTATION LAYER                           │    │
│  │  Terminal.Gui (TUI)  │  Phoenix LiveView  │  Livebook Dashboards   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    ↕                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      INTELLIGENCE LAYER (Elixir)                    │    │
│  │  SmartMetrics │ AiCopilot │ Orchestrator │ DarkCockpit │ PROMETHEUS │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    ↕                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     COORDINATION LAYER (CEPAF F#)                   │    │
│  │     Domain.fs  │  Safety.fs  │  Telemetry  │  PROMETHEUS Bridge     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    ↕                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                       DATA PLANE (Zenoh)                            │    │
│  │  c3i/units/**  │  c3i/alarms/**  │  c3i/ctrl/**  │  prometheus/**   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## L1.4 Key Performance Indicators (KPIs)

| KPI | Target | Measurement |
|-----|--------|-------------|
| Metric Update Latency | <50ms | SC-PRF-050 |
| UI Refresh Rate | 10Hz | DarkCockpit.render() |
| AI Analysis Interval | 10s | AiCopilot.@analysis_interval_ms |
| Staleness Detection | 5s | SmartMetrics.@staleness_threshold_ms |
| Command Audit Coverage | 100% | Orchestrator.audit() |
| PROMETHEUS Verification | <10ms | verify_routing_graph/3 |

## L1.5 Compliance Requirements

| Standard | Description | PRAJNA Implementation |
|----------|-------------|----------------------|
| NASA-STD-3000 | Human-System Integration | Dark Cockpit philosophy |
| NUREG-0700 | Nuclear HMI Guidelines | Trend vectors, analog displays |
| MIL-STD-1472H | Human Engineering | Icon system, color palette |
| IEC 61508 SIL-2 | Functional Safety | Two-step commit, PROMETHEUS |
| ISO 27001 | Information Security | Command audit logging |

---

# Level 2: Architecture & Design

## L2.1 Architectural Principles

### L2.1.1 Dark Cockpit Philosophy (SC-HMI-001)

```
NORMAL STATE:          DEVIATION STATE:
┌─────────────┐        ┌─────────────┐
│ · · · · · · │        │ · · ⚠ · · · │
│ · · · · · · │        │ · · ↑↑ · ⛔ · │
│ · · · · · · │        │ ☢ · · · · · │
│             │        │             │
│  Gray/Blue  │        │ Amber/Red   │
│  "All OK"   │        │ "Attention" │
└─────────────┘        └─────────────┘
```

**Principle**: The cockpit shows almost nothing when everything is fine. Operators are alerted only to deviations.

### L2.1.2 Trend Vectors (SC-HMI-002)

Smart Metrics show not just values but their trajectory:

```
CPU: 42% ↑↑    = Value is 42% and rising fast
MEM: 68% →     = Value is 68% and stable
LAT: 25ms ↓    = Value is 25ms and falling
```

| Icon | Trend | Condition |
|------|-------|-----------|
| ↑↑ | Rising Fast | >10% increase |
| ↑ | Rising | Any increase |
| → | Stable | No change |
| ↓ | Falling | Any decrease |
| ↓↓ | Falling Fast | >10% decrease |

### L2.1.3 Staleness Detection (SC-HMI-003)

```
FRESH DATA (< 5s):     STALE DATA (> 5s):
┌─────────────┐        ┌─────────────┐
│ CPU: 42% ↑  │        │ CPU: 42% ◐  │
│ ● Connected │        │ ◐ Stale     │
│             │        │ [faded]     │
└─────────────┘        └─────────────┘
```

### L2.1.4 Two-Step Commit (SC-HMI-004)

Critical commands require explicit confirmation:

```
STEP 1: ARM            STEP 2: CONFIRM
┌─────────────────┐    ┌─────────────────┐
│ ◎ RESTART armed │    │ ● RESTART exec  │
│                 │    │                 │
│ Expires: 4:58   │    │ Running...      │
│                 │    │                 │
│ [CONFIRM] [X]   │    │ ✓ Acknowledged  │
└─────────────────┘    └─────────────────┘
```

## L2.2 Module Architecture

```
lib/indrajaal/cockpit/prajna/
├── domain.ex           # L2.2.1 - Type definitions & domain logic
├── smart_metrics.ex    # L2.2.2 - ETS-backed metrics with trends
├── ai_copilot.ex       # L2.2.3 - AI/LLM integration
├── dark_cockpit.ex     # L2.2.4 - ANSI terminal rendering
├── orchestrator.ex     # L2.2.5 - State machine & coordination
└── supervisor.ex       # L2.2.6 - OTP supervision tree

lib/cepaf/src/Cepaf/
├── Domain.fs           # L2.2.7 - F# domain events
├── Cockpit/
│   ├── Domain.fs       # L2.2.8 - PRAJNA types in F#
│   ├── DarkCockpitUI.fs# L2.2.9 - F# ANSI rendering
│   └── Cockpit.fs      # L2.2.10 - F# orchestrator
└── Bridge/Commands/
    └── Safety.fs       # L2.2.11 - PROMETHEUS commands
```

## L2.3 Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          PRAJNA DATA FLOW                                 │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌────────────────┐                                                       │
│  │ External       │    Telemetry                                          │
│  │ Data Sources   │──────────────┐                                        │
│  │ (Containers,   │              │                                        │
│  │  Nodes, API)   │              ▼                                        │
│  └────────────────┘    ┌─────────────────┐                               │
│                        │  SmartMetrics   │                               │
│                        │  (ETS Store)    │                               │
│  ┌────────────────┐    │                 │    ┌─────────────────┐        │
│  │ Zenoh Pub/Sub  │───▶│ - record/4      │───▶│ Phoenix PubSub  │        │
│  │ c3i/units/**   │    │ - compute_trend │    │ prajna:metrics  │        │
│  └────────────────┘    │ - check_stale   │    └────────┬────────┘        │
│                        └─────────────────┘             │                  │
│                               │                        │                  │
│                               │ health_summary         │                  │
│                               ▼                        ▼                  │
│                        ┌─────────────────┐    ┌─────────────────┐        │
│                        │   AiCopilot     │    │   DarkCockpit   │        │
│                        │                 │    │   (Terminal)    │        │
│                        │ - detect_anomal │    │                 │        │
│                        │ - LLM analysis  │    │ - render()      │        │
│                        │ - predictions   │    │ - format_bar()  │        │
│                        └────────┬────────┘    └─────────────────┘        │
│                                 │                                         │
│                                 │ insights                                │
│                                 ▼                                         │
│                        ┌─────────────────┐                               │
│                        │   Orchestrator  │                               │
│                        │                 │                               │
│                        │ - state machine │                               │
│                        │ - command exec  │                               │
│                        │ - audit log     │                               │
│                        └─────────────────┘                               │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

## L2.4 Control Flow Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        PRAJNA CONTROL FLOW                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  USER ACTION                                                              │
│       │                                                                   │
│       ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐     │
│  │                    ORCHESTRATOR STATE MACHINE                    │     │
│  ├─────────────────────────────────────────────────────────────────┤     │
│  │                                                                  │     │
│  │  COMMAND FLOW:                                                   │     │
│  │  ┌─────────┐   arm_command   ┌─────────┐  confirm   ┌─────────┐ │     │
│  │  │  IDLE   │ ───────────────▶│  ARMED  │ ──────────▶│EXECUTING│ │     │
│  │  │    ○    │                 │    ◎    │            │    ●    │ │     │
│  │  └─────────┘                 └────┬────┘            └────┬────┘ │     │
│  │                                   │ timeout/cancel       │       │     │
│  │                                   ▼                      ▼       │     │
│  │                              ┌─────────┐           ┌─────────┐   │     │
│  │                              │CANCELLED│           │   ACK   │   │     │
│  │                              │    ✗    │           │    ✓    │   │     │
│  │                              └─────────┘           └─────────┘   │     │
│  │                                                                  │     │
│  │  CRITICAL COMMAND GUARD:                                         │     │
│  │  ┌───────────────────────────────────────────────────────────┐  │     │
│  │  │ IF Domain.critical_command?(cmd) THEN                      │  │     │
│  │  │   requires_confirmation: true                              │  │     │
│  │  │   armed_timeout: 5 minutes                                 │  │     │
│  │  │   audit("ARMED: #{cmd_id}")                               │  │     │
│  │  │ ELSE                                                       │  │     │
│  │  │   direct_execute()                                         │  │     │
│  │  └───────────────────────────────────────────────────────────┘  │     │
│  │                                                                  │     │
│  └─────────────────────────────────────────────────────────────────┘     │
│                                                                           │
│  VIEW FLOW:                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│  │ Overview │ ←─▶│   Mesh   │ ←─▶│  Alarms  │ ←─▶│ Commands │           │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘           │
│       ↕               ↕               ↕               ↕                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐           │
│  │    AI    │ ←─▶│ NodeDtl  │ ←─▶│ Timeline │ ←─▶│ Settings │           │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘           │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

## L2.5 Interrelationship Map

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA COMPONENT INTERRELATIONSHIPS                    │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│                        ┌─────────────┐                                    │
│                   ┌───▶│  Supervisor │◀───┐                               │
│                   │    └──────┬──────┘    │                               │
│                   │           │           │                               │
│           starts  │     starts│     starts│                               │
│                   │           ▼           │                               │
│    ┌──────────────┴───┐  ┌────────┐  ┌───┴──────────────┐                │
│    │   SmartMetrics   │  │Orchest │  │    AiCopilot     │                │
│    │   (GenServer)    │  │ rator  │  │   (GenServer)    │                │
│    └────────┬─────────┘  └───┬────┘  └────────┬─────────┘                │
│             │                │                │                           │
│     ETS:    │                │                │     calls                 │
│  prajna_    │     manages    │                │  SmartMetrics.all()      │
│  metrics    ▼     state      ▼                ▼                           │
│    ┌────────────┐  ┌─────────────────┐  ┌────────────────┐               │
│    │   ETS      │  │  CockpitState   │  │  OpenRouter    │               │
│    │  Tables    │  │  (GenServer     │  │  Client (LLM)  │               │
│    └────────────┘  │   state)        │  └────────────────┘               │
│             ▲      └────────┬────────┘            │                       │
│             │               │                     │                       │
│     reads   │               │ renders             │ verifies              │
│             │               ▼                     ▼                       │
│    ┌────────────────┐  ┌─────────────┐  ┌────────────────┐               │
│    │  DarkCockpit   │◀─│   Terminal  │  │   PROMETHEUS   │               │
│    │  (UI Render)   │  │   Output    │  │  (Verification)│               │
│    └────────────────┘  └─────────────┘  └────────────────┘               │
│                                                                           │
│  DEPENDENCIES:                                                            │
│  ─────────────                                                            │
│  Orchestrator ──calls──▶ SmartMetrics.record/4                           │
│  Orchestrator ──calls──▶ AiCopilot.analyze_now/0                         │
│  AiCopilot ────calls──▶ SmartMetrics.all/0                               │
│  AiCopilot ────calls──▶ OpenRouterClient.chat/2                          │
│  OpenRouter ───calls──▶ PROMETHEUS.verify_routing_graph/3                │
│  DarkCockpit ──reads──▶ SmartMetrics ETS tables                          │
│                                                                           │
│  PUBSUB CHANNELS:                                                         │
│  ────────────────                                                         │
│  prajna:metrics  ─▶ metric_updated, metric_stale                         │
│  prajna:insights ─▶ insights_updated                                     │
│  prajna:commands ─▶ command_armed, command_executed                      │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## L2.6 Biomorphic Architecture (v2.0)

PRAJNA v2.0 introduces a **Fractal Holarchy** where every system component implements a standard biological interface.

### L2.6.1 The Holon Invariant
Every addressable entity (Process, Container, Cluster) must expose:
1.  **Vital Signs**: `Health`, `Stress`, `Energy`.
2.  **Intent**: Current teleological goal (e.g., `:healing`, `:processing`).
3.  **Membrane**: An input filter that rejects non-conforming messages.

### L2.6.2 The Nervous System
*   **Spinal Reflex**: Local `Nx` models for <50ms decisions.
*   **Cortical Logic**: Cloud LLM for strategic planning.
*   **Thalamus**: Router deciding between Reflex and Cortex.

---

# Level 3: Component Specifications

## L3.1 Domain Types (domain.ex) & Bio Types (bio/types.ex)

### L3.1.1 Core Domain Types
*(See existing L3.1.1)*

### L3.1.5 Biological Types (New in v2.0)

```elixir
# Standard State Vector
@type vital_signs :: %Prajna.Bio.VitalSigns{
  health: float(),   # 0.0 - 1.0
  stress: float(),   # 0.0 - 1.0
  energy: float(),   # 0.0 - 1.0
  intent: atom()     # Current FSM state
}

# Universal Message Envelope
@type genetic_payload :: %Prajna.Bio.GeneticPayload{
  genome_hash: String.t(), # Schema version
  dna: map(),              # Data
  markers: [atom()]        # Immune tags
}
```

```elixir
# Trend Vectors - shows trajectory, not just value
@type trend :: :rising | :rising_fast | :falling | :falling_fast | :stable

# Connection Status with staleness
@type conn_status :: :connected | :stale | :degraded | :disconnected

# Dark Cockpit Alarm Levels
@type alarm_level :: :normal | :advisory | :caution | :warning | :critical

# Two-Step Commit States
@type command_state :: :idle | :armed | :executing | :acknowledged | :failed

# Mesh Node Roles
@type node_role :: :supervisor | :controller | :worker | :observer | :gateway

# AI Insight Types
@type insight_type :: :anomaly | :prediction | :recommendation | :correlation | :root_cause | :summary

# View Modes
@type view_mode :: :overview | :mesh | :alarms | :commands | :ai | :dashboard
```

### L3.1.2 Smart Metric Structure

```elixir
@type smart_metric :: %{
  value: number(),              # Current value
  previous_value: number()|nil, # Last value (for trend)
  last_updated: DateTime.t(),   # Timestamp
  trend: trend(),               # Computed trend
  level: alarm_level(),         # Threshold evaluation
  thresholds: thresholds()|nil, # Threshold config
  unit: String.t(),             # Display unit
  label: String.t(),            # Human label
  sparkline: list(float())      # Last 60 values
}
```

### L3.1.3 Threshold Structure

```elixir
@type thresholds :: %{
  advisory_low: number()|nil,   # Blue level low
  advisory_high: number()|nil,  # Blue level high
  caution_low: number()|nil,    # Amber level low
  caution_high: number()|nil,   # Amber level high
  warning_low: number()|nil,    # Red level low
  warning_high: number()|nil    # Red level high
}
```

### L3.1.4 Function Specifications

| Function | Signature | Purpose |
|----------|-----------|---------|
| `trend_icon/1` | `trend() -> String.t()` | Returns ↑↑/↑/→/↓/↓↓ |
| `alarm_icon/1` | `alarm_level() -> String.t()` | Returns ·/ℹ/⚠/⛔/☢ |
| `status_icon/1` | `conn_status() -> String.t()` | Returns ●/◐/○ |
| `create_smart_metric/3` | `(label, value, opts) -> smart_metric()` | Factory |
| `update_metric/2` | `(metric, value) -> smart_metric()` | Updates with trend |
| `stale?/2` | `(metric, timeout_s) -> boolean()` | Staleness check |
| `evaluate_level/2` | `(value, thresholds) -> alarm_level()` | Threshold eval |

## L3.2 SmartMetrics Engine (smart_metrics.ex)

### L3.2.1 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SMART METRICS ENGINE                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                      GenServer Process                          │ │
│  │  State: %{started_at, metrics_recorded, last_staleness_check}  │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                               │                                      │
│           ┌───────────────────┼───────────────────┐                  │
│           ▼                   ▼                   ▼                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │ :prajna_metrics │  │:prajna_history  │  │  Staleness      │      │
│  │   (ETS Table)   │  │  (ETS Table)    │  │  Checker        │      │
│  │                 │  │                 │  │  (1s interval)  │      │
│  │ {id, metric}    │  │ {id, history}   │  │                 │      │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### L3.2.2 Configuration Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `@staleness_threshold_ms` | 5000 | Metric stale after 5s |
| `@sparkline_length` | 20 | History buffer size |
| `@table` | `:prajna_metrics` | Primary ETS table |
| `@history_table` | `:prajna_history` | History ETS table |

### L3.2.3 API Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `start_link/1` | `(opts) -> {:ok, pid}` | Start GenServer |
| `record/4` | `(id, label, value, opts)` | Record metric |
| `get/1` | `(id) -> metric\|nil` | Get single metric |
| `all/0` | `() -> [{id, metric}]` | Get all metrics |
| `get_by_pattern/1` | `(pattern) -> [{id, metric}]` | Pattern match |
| `stale_metrics/0` | `() -> [{id, metric}]` | Get stale metrics |
| `alarmed_metrics/0` | `() -> [{id, metric}]` | Get alarmed metrics |
| `health_summary/0` | `() -> map()` | System health summary |
| `configure_thresholds/2` | `(id, thresholds)` | Set thresholds |
| `delete/1` | `(id)` | Delete metric |
| `clear/0` | `()` | Clear all metrics |

### L3.2.4 Health Summary Structure

```elixir
%{
  total_metrics: integer(),      # Total metric count
  stale_count: integer(),        # Stale metric count
  alarmed_count: integer(),      # Alarmed metric count
  by_level: %{                   # Breakdown by level
    normal: integer(),
    advisory: integer(),
    caution: integer(),
    warning: integer(),
    critical: integer()
  },
  health_score: integer(),       # 0-100 score
  status: atom()                 # :healthy/:warning/:critical
}
```

## L3.3 AI Copilot (ai_copilot.ex)

### L3.3.1 Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                       AI COPILOT ENGINE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                 LOCAL ANALYTICS (Always On)                   │   │
│  │  detect_local_anomalies/0:                                    │   │
│  │  - CPU threshold violations                                   │   │
│  │  - Stale metric detection                                     │   │
│  │  - Alarmed metric aggregation                                 │   │
│  │  - Trend analysis                                             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                               │                                      │
│                               ▼                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              LLM ENHANCEMENT (Optional - OpenRouter)          │   │
│  │  request_llm_analysis/1:                                      │   │
│  │  - Deep pattern analysis                                      │   │
│  │  - Natural language explanations                              │   │
│  │  - Root cause identification                                  │   │
│  │  - Action recommendations                                     │   │
│  │                                                               │   │
│  │  PROMETHEUS INTEGRATION:                                      │   │
│  │  - verify_routing_graph/3 before LLM call                    │   │
│  │  - check_exclusivity_constraint/2                            │   │
│  │  - check_simplex_principle/2                                 │   │
│  │  - check_confidence_threshold/1                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                               │                                      │
│                               ▼                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    INSIGHT AGGREGATOR                         │   │
│  │  - Merge local + LLM insights                                 │   │
│  │  - Deduplicate and rank by confidence                        │   │
│  │  - Apply TTL (5 minutes default)                             │   │
│  │  - Publish to prajna:insights                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### L3.3.2 Configuration Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `@insight_ttl_seconds` | 300 | Insight expiry (5 min) |
| `@analysis_interval_ms` | 10000 | Auto-analysis (10s) |
| `@max_insights` | 50 | Max stored insights |

### L3.3.3 Insight Structure

```elixir
@type ai_insight :: %{
  id: String.t(),                 # Unique ID
  type: insight_type(),           # :anomaly/:prediction/etc
  level: alarm_level(),           # Severity
  title: String.t(),              # Short title
  description: String.t(),        # Detailed description
  related_nodes: [String.t()],    # Associated nodes
  related_alarms: [String.t()],   # Associated alarms
  confidence: float(),            # 0.0-1.0 confidence
  generated_at: DateTime.t(),     # Creation time
  expires_at: DateTime.t()|nil,   # Expiry time
  action_items: [String.t()]      # Recommended actions
}
```

### L3.3.4 PROMETHEUS Integration

```elixir
# Before any LLM call:
routing_proposal = %{
  source: :synapse,
  target: :openrouter,
  model: "anthropic/claude-3.5-sonnet",
  confidence: 1.0,
  guardian_approved: true
}

case OpenRouterClient.validate_routing_proposal(routing_proposal) do
  {:ok, _} -> proceed_with_llm_call()
  {:error, {:constraint_violation, reason}} -> halt_with_reason(reason)
end
```

## L3.4 Orchestrator (orchestrator.ex)

### L3.4.1 State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR STATE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  %{                                                                  │
│    cockpit: %{                    # CockpitState                    │
│      operator_id: String.t(),     # Current operator                │
│      session_id: String.t(),      # Session UUID                    │
│      started_at: DateTime.t(),    # Session start                   │
│      nodes: %{id => node},        # Mesh nodes                      │
│      zones: %{id => zone},        # Zone configs                    │
│      alarms: %{id => alarm},      # Active alarms                   │
│      pending_commands: %{id => cmd}, # Armed commands               │
│      command_history: [cmd],      # Executed commands               │
│      insights: [insight],         # AI insights                     │
│      ai_enabled: boolean(),       # AI toggle                       │
│      current_view: view_mode(),   # Active view                     │
│      selected_node_id: String.t()|nil,                              │
│      messages_received: integer(),# Telemetry count                 │
│      monitor_only: boolean(),     # Read-only mode                  │
│      simulation_mode: boolean()   # Sim active                      │
│    },                                                                │
│    ui_running: boolean(),         # UI active                       │
│    simulation_running: boolean(), # Sim active                      │
│    spinner_frame: integer(),      # Animation frame                 │
│    audit_log: [String.t()]        # Audit entries                   │
│  }                                                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### L3.4.2 Command Execution Flow

```
USER                ORCHESTRATOR              TARGET
 │                      │                       │
 │ arm_command(node,cmd)│                       │
 ├─────────────────────▶│                       │
 │                      │ critical_command?     │
 │                      ├──────────────────────▶│ (check)
 │                      │                       │
 │ {:ok, cmd_id}        │ state: :armed         │
 │◀─────────────────────┤ armed_at: now()       │
 │                      │ audit("ARMED")        │
 │                      │                       │
 │ confirm_command(id)  │                       │
 ├─────────────────────▶│                       │
 │                      │ state: :executing     │
 │                      │ executed_at: now()    │
 │                      │ audit("CONFIRMED")    │
 │                      │                       │
 │                      │ execute_command()     │
 │                      ├──────────────────────▶│
 │                      │                       │
 │                      │ {:ok/:error, msg}     │
 │                      │◀──────────────────────┤
 │                      │                       │
 │                      │ state: :ack/:failed   │
 │                      │ audit("ACK/FAILED")   │
 │                      │ move to history       │
 │                      │                       │
```

---

# Level 4: Implementation Details

## L4.1 ETS Table Design

### L4.1.1 Metrics Table (:prajna_metrics)

```erlang
%% Table creation
:ets.new(:prajna_metrics, [
  :named_table,
  :public,
  :set,
  read_concurrency: true
])

%% Entry format
{metric_id :: binary(), metric :: smart_metric()}

%% Example entry
{"zone-alpha.node-01.cpu", %{
  value: 42.5,
  previous_value: 40.2,
  last_updated: ~U[2025-12-27 03:30:00Z],
  trend: :rising,
  level: :normal,
  thresholds: %{caution_high: 75.0, warning_high: 90.0},
  unit: "%",
  label: "CPU",
  sparkline: [42.5, 40.2, 38.9, 41.1, ...]
}}
```

### L4.1.2 History Table (:prajna_history)

```erlang
%% Table creation
:ets.new(:prajna_history, [
  :named_table,
  :public,
  :set
])

%% Entry format
{metric_id :: binary(), history :: [float()]}
```

## L4.2 Trend Computation Algorithm

```elixir
defp compute_trend(old_value, new_value, previous_trend)
  when is_number(old_value) and is_number(new_value) do

  diff = new_value - old_value
  percent_change = if old_value != 0 do
    abs(diff / old_value) * 100
  else
    abs(diff)
  end

  cond do
    # Rising fast: >10% increase OR already rising + continued increase
    diff > 0 and (percent_change > 10 or previous_trend == :rising) ->
      if percent_change > 10, do: :rising_fast, else: :rising

    diff > 0 ->
      :rising

    # Falling fast: >10% decrease OR already falling + continued decrease
    diff < 0 and (percent_change > 10 or previous_trend == :falling) ->
      if percent_change > 10, do: :falling_fast, else: :falling

    diff < 0 ->
      :falling

    true ->
      :stable
  end
end
```

## L4.3 Staleness Detection Algorithm

```elixir
def stale_metrics do
  now = System.monotonic_time(:millisecond)

  :ets.tab2list(@table)
  |> Enum.filter(fn {_, metric} ->
    staleness = now - metric_to_mono_time(metric)
    staleness > @staleness_threshold_ms  # 5000ms
  end)
end

defp metric_to_mono_time(%{mono_time: mono_time}), do: mono_time
defp metric_to_mono_time(_), do: 0
```

## L4.4 Health Score Calculation

```elixir
def health_summary do
  metrics = all()
  total = length(metrics)

  # Count by level
  {normal, advisory, caution, warning, critical} =
    Enum.reduce(metrics, {0, 0, 0, 0, 0}, fn {_, m}, {n, a, c, w, cr} ->
      case m.level do
        :normal -> {n + 1, a, c, w, cr}
        :advisory -> {n, a + 1, c, w, cr}
        :caution -> {n, a, c + 1, w, cr}
        :warning -> {n, a, c, w + 1, cr}
        :critical -> {n, a, c, w, cr + 1}
      end
    end)

  # Weighted score: normal=100, advisory=80, caution=50, warning=20, critical=0
  health_score = if total > 0 do
    ((normal * 100 + advisory * 80 + caution * 50 + warning * 20 + critical * 0) / total)
    |> round()
  else
    100
  end

  %{
    total_metrics: total,
    health_score: health_score,
    status: health_status(health_score, stale_count, critical)
  }
end
```

## L4.5 ANSI Color Rendering

```elixir
# Color palette (Dark Cockpit)
@colors %{
  normal: "\e[90m",     # Gray (dark)
  advisory: "\e[96m",   # Cyan
  caution: "\e[93m",    # Yellow/Amber
  warning: "\e[91m",    # Red
  critical: "\e[91;5m", # Red + blink
  reset: "\e[0m"
}

def render_metric(metric) do
  color = @colors[metric.level]
  trend = Domain.trend_icon(metric.trend)

  "#{color}#{metric.label}: #{format_value(metric.value)}#{metric.unit} #{trend}#{@colors.reset}"
end
```

---

# Level 5: Operational Procedures

## L5.1 Startup Sequence

```bash
# 1. Ensure containers are running
elixir scripts/performance/podman_direct_manager.exs --status

# 2. Start the application
iex -S mix

# 3. Start PRAJNA supervisor
iex> {:ok, _} = Indrajaal.Cockpit.Prajna.Supervisor.start_link()

# 4. Start simulation (optional)
iex> Indrajaal.Cockpit.Prajna.Orchestrator.start_simulation()

# 5. Start UI rendering
iex> Indrajaal.Cockpit.Prajna.Orchestrator.start_ui()
```

## L5.2 Operational Commands

```elixir
# Get current state
state = Orchestrator.state()

# Change view
Orchestrator.change_view(:mesh)
Orchestrator.change_view(:alarms)
Orchestrator.change_view(:ai)

# Select a node for detail
Orchestrator.select_node("node-01")

# Get metrics
SmartMetrics.all()
SmartMetrics.stale_metrics()
SmartMetrics.alarmed_metrics()
SmartMetrics.health_summary()

# AI Copilot
AiCopilot.insights()
AiCopilot.high_confidence_insights(0.9)
AiCopilot.analyze_now()

# Two-step command execution
{:ok, cmd_id} = Orchestrator.arm_command("node-01", :restart)
:ok = Orchestrator.confirm_command(cmd_id)
# OR
:ok = Orchestrator.cancel_command(cmd_id)

# Audit log
Orchestrator.audit_log(50)
```

## L5.3 Shutdown Sequence

```elixir
# 1. Stop simulation
Orchestrator.stop_simulation()

# 2. Stop UI
Orchestrator.stop_ui()

# 3. System continues to run for monitoring
# Full stop requires application restart
```

## L5.4 Troubleshooting

| Symptom | Cause | Resolution |
|---------|-------|------------|
| Metrics stale | Data source stopped | Check Zenoh publishers |
| AI insights missing | LLM not configured | Set OPENROUTER_API_KEY |
| Commands fail | Monitor-only mode | Set monitor_only: false |
| UI not rendering | UI not started | Call start_ui() |
| PROMETHEUS violations | Safety constraint | Check SC-* constraint logs |

---

# Appendix A: PROMETHEUS Verification

## A.1 Graph Verification Framework

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PROMETHEUS VERIFICATION LAYER                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  BEFORE PROMETHEUS:                                                          │
│    Synapse → OpenRouter → (hope it's safe) → Execute                        │
│                                                                              │
│  AFTER PROMETHEUS:                                                           │
│    Synapse → PROMETHEUS.verify() → OpenRouter → Guardian → Execute          │
│              ↓ (if fails)                                                    │
│              HALT with constraint violation                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## A.2 Invariants Checked

| Invariant | Constraint | Description |
|-----------|------------|-------------|
| `inv_openrouter_exclusivity` | SC-GVF-003 | Synapse cannot route directly to external AI |
| `inv_simplex_principle` | SC-NEURO-001 | All AI routes must pass through Guardian |
| `inv_confidence_threshold` | SC-GVF-004 | Routes require confidence ≥ 0.8 |

## A.3 Verification Functions

```elixir
@spec verify_routing_graph(atom(), String.t(), keyword()) :: {:ok, :verified} | {:error, term()}
def verify_routing_graph(source, target_model, opts \\ []) do
  confidence = Keyword.get(opts, :confidence, 1.0)
  guardian_approved = Keyword.get(opts, :guardian_approved, false)

  with :ok <- check_exclusivity_constraint(source, target_model),
       :ok <- check_simplex_principle(source, guardian_approved),
       :ok <- check_confidence_threshold(confidence) do
    {:ok, :verified}
  end
end
```

## A.4 Routing Graph State

```elixir
def get_routing_graph_state do
  %{
    nodes: [:cortex, :synapse, :openrouter, :guardian, :gde],
    edges: [
      {:cortex, :synapse},
      {:synapse, :openrouter},
      {:openrouter, :guardian},
      {:guardian, :gde}
    ],
    forbidden_edges: [
      {:synapse, :openai},
      {:synapse, :anthropic},
      {:synapse, :google}
    ],
    external_ai_providers: ["openai", "anthropic", "google", "mistral", "meta"],
    invariants: [
      :inv_openrouter_exclusivity,
      :inv_simplex_principle,
      :inv_confidence_threshold
    ],
    verified_at: DateTime.utc_now()
  }
end
```

## A.5 Mathematical Formalization

```
# Routing Graph G = (V, E)
V = {cortex, synapse, openrouter, guardian, gde}
E ⊆ V × V

# Invariant: Exclusivity
∀ (s, t) ∈ E : s = synapse ⟹ t ∉ ExternalAI

# Invariant: Simplex Principle
∀ (s, t) ∈ E : s ∉ {guardian, gde} ⟹ guardian_approved(s, t)

# Invariant: Confidence Threshold
∀ (s, t, c) ∈ Route : c ≥ 0.8
```

---

# Appendix B: STAMP Compliance Matrix

## B.1 PRAJNA STAMP Constraints

| Constraint ID | Description | Implementation | Status |
|---------------|-------------|----------------|--------|
| SC-C3I-001 | Data-centric architecture (Zenoh) | Domain.telemetry_key/2 | COMPLIANT |
| SC-C3I-002 | Safety-critical HMI (NASA-STD-3000) | DarkCockpit philosophy | COMPLIANT |
| SC-C3I-003 | AI advisory mode | SC-AI-001 compliance | COMPLIANT |
| SC-C3I-004 | Audit logging | Orchestrator.audit() | COMPLIANT |
| SC-HMI-001 | Dark Cockpit philosophy | Gray/blue defaults | COMPLIANT |
| SC-HMI-002 | Trend vectors displayed | Domain.trend_icon/1 | COMPLIANT |
| SC-HMI-003 | Staleness detection (5s) | SmartMetrics.stale_metrics/0 | COMPLIANT |
| SC-HMI-004 | Two-step commit | critical_command?/1 | COMPLIANT |
| SC-AI-001 | AI suggestions advisory only | Human in the loop | COMPLIANT |
| SC-AI-002 | Confidence scores displayed | insight.confidence | COMPLIANT |
| SC-AI-003 | AI recommendations logged | audit() | COMPLIANT |
| SC-AI-004 | Graceful degradation | Local analytics fallback | COMPLIANT |
| SC-PRF-050 | Metric updates <50ms | ETS direct access | COMPLIANT |
| SC-GVF-003 | Synapse no direct external AI | PROMETHEUS | COMPLIANT |
| SC-NEURO-001 | Simplex principle | PROMETHEUS | COMPLIANT |

---

# Appendix C: TDG Test-Driven Generation

## C.1 Test File Inventory

```
test/indrajaal/cockpit/prajna/
├── domain_test.exs            # Domain type tests
├── smart_metrics_test.exs     # Metrics engine tests
├── ai_copilot_test.exs        # AI Copilot tests
├── orchestrator_test.exs      # Orchestrator tests
└── prometheus_test.exs        # PROMETHEUS verification tests
```

## C.2 Test Coverage Requirements

| Component | Test Type | Coverage Target |
|-----------|-----------|-----------------|
| Domain | Unit | 100% functions |
| SmartMetrics | Unit + Integration | 95% lines |
| AiCopilot | Unit + Mock LLM | 90% branches |
| Orchestrator | Integration | 90% state transitions |
| PROMETHEUS | Property | 100% invariants |

## C.3 Property Testing (PropCheck)

```elixir
property "verify_routing_graph always returns valid result type" do
  forall {source, model, confidence, approved} <- proposal_generator() do
    result = OpenRouterClient.verify_routing_graph(
      source, model,
      confidence: confidence,
      guardian_approved: approved
    )

    case result do
      {:ok, :verified} -> true
      {:error, {:constraint_violation, _}} -> true
      _ -> false
    end
  end
end
```

---

# Appendix D: AOR Agent Operating Rules

## D.1 PRAJNA-Specific AORs

| Rule ID | Description | Enforcement |
|---------|-------------|-------------|
| AOR-PRAJNA-001 | Trend vectors must be computed on every update | SmartMetrics.update_metric/2 |
| AOR-PRAJNA-002 | Staleness check every 1 second | schedule_staleness_check/0 |
| AOR-PRAJNA-003 | AI insights expire after 5 minutes | @insight_ttl_seconds |
| AOR-PRAJNA-004 | Critical commands require two-step | critical_command?/1 |
| AOR-PRAJNA-005 | All commands must be audit logged | audit/1 |
| AOR-PRAJNA-006 | PROMETHEUS verification before LLM | validate_routing_proposal/1 |
| AOR-PRAJNA-007 | Health score recalculated on demand | health_summary/0 |
| AOR-PRAJNA-008 | Sparkline limited to 60 samples | Enum.take(60) |

---

# Appendix E: Fractal Logging & Telemetry

## E.1 Fractal Logging Integration

```elixir
# Fractal log decorator
@fractal_meta %{
  domain: :prajna,
  component: :smart_metrics,
  level: 2
}

def record(metric_id, label, value, opts \\ []) do
  Indrajaal.Observability.Fractal.log(@fractal_meta, fn ->
    # Record logic here
  end)
end
```

## E.2 Telemetry Events

```elixir
# Metric recorded event
:telemetry.execute(
  [:indrajaal, :prajna, :metric, :recorded],
  %{value: value, latency_us: latency},
  %{metric_id: metric_id, trend: trend, level: level}
)

# AI analysis event
:telemetry.execute(
  [:indrajaal, :prajna, :ai, :analysis],
  %{duration_ms: duration, insight_count: count},
  %{llm_used: llm_used, confidence_avg: avg}
)

# Command event
:telemetry.execute(
  [:indrajaal, :prajna, :command, :executed],
  %{},
  %{command: command, node_id: node_id, result: result}
)
```

## E.3 OTEL Spans

```elixir
# AI Copilot analysis span
OpentelemetryTelemetry.start_span("prajna.ai.analyze", %{
  attributes: [
    {"prajna.llm.enabled", state.llm_enabled},
    {"prajna.metrics.count", metrics_count}
  ]
})
```

---

# Appendix F: Zenoh Dataflow

## F.1 Key Expression Space

```
c3i/                              # PRAJNA namespace
├── units/{zone}/{node}/telemetry # Metric telemetry
├── alarms/{severity}/{id}        # Alarm events
├── ctrl/{node}/{subsystem}/set   # Control commands
├── config/{node}                 # Configuration
└── ai/insights/{type}            # AI insights

prometheus/                       # PROMETHEUS namespace
├── verifications                 # Verification events
├── violations                    # Violation alerts
└── graph_state                   # Live graph state
```

## F.2 Message Formats

### Telemetry Message
```json
{
  "key": "c3i/units/zone-alpha/node-01/telemetry",
  "payload": {
    "cpu": 42.5,
    "memory": 68.2,
    "latency": 25.0,
    "timestamp": "2025-12-27T03:30:00Z"
  }
}
```

### Alarm Message
```json
{
  "key": "c3i/alarms/warning/alm-001",
  "payload": {
    "node_id": "node-01",
    "level": "warning",
    "category": "cpu",
    "message": "CPU exceeds 90% threshold",
    "occurred_at": "2025-12-27T03:30:00Z"
  }
}
```

### PROMETHEUS Verification
```json
{
  "key": "prometheus/verifications",
  "payload": {
    "proposal_id": "prop-abc123",
    "source": "synapse",
    "target": "openrouter",
    "model": "anthropic/claude-3.5-sonnet",
    "confidence": 1.0,
    "result": "verified",
    "constraints": {
      "exclusivity": "passed",
      "simplex": "passed",
      "confidence": "passed"
    },
    "timestamp": "2025-12-27T03:30:00Z"
  }
}
```

## F.3 Control Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        ZENOH DATAFLOW CONTROL                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TELEMETRY FLOW (Pub/Sub):                                                  │
│  ┌──────────┐   publish   ┌─────────────┐   subscribe   ┌──────────────┐   │
│  │ External │ ──────────▶ │   Zenoh     │ ────────────▶ │ SmartMetrics │   │
│  │ Sources  │             │   Router    │               │   .record()  │   │
│  └──────────┘             └─────────────┘               └──────────────┘   │
│                                                                             │
│  COMMAND FLOW (Get/Put):                                                    │
│  ┌──────────┐   put       ┌─────────────┐   get         ┌──────────────┐   │
│  │Orchestr- │ ──────────▶ │   Zenoh     │ ────────────▶ │   Target     │   │
│  │   ator   │             │   Storage   │               │    Node      │   │
│  └──────────┘             └─────────────┘               └──────────────┘   │
│                                                                             │
│  PROMETHEUS FLOW (Pub/Sub):                                                 │
│  ┌──────────┐  publish    ┌─────────────┐   subscribe   ┌──────────────┐   │
│  │OpenRouter│ ──────────▶ │   Zenoh     │ ────────────▶ │  Dashboard   │   │
│  │  Client  │             │prometheus/**│               │   /CEPAF     │   │
│  └──────────┘             └─────────────┘               └──────────────┘   │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

---

# Appendix G: Livebook Dashboards

## G.1 Dashboard Inventory

| Dashboard | Purpose | Update Rate |
|-----------|---------|-------------|
| `prajna_overview.livemd` | System health overview | 1s |
| `prajna_metrics.livemd` | Real-time metrics with charts | 500ms |
| `prajna_alarms.livemd` | Active alarms with trends | 1s |
| `prajna_ai.livemd` | AI insights visualization | 10s |
| `prometheus_graph.livemd` | Routing graph visualization | 5s |

## G.2 Overview Dashboard Structure

```elixir
# prajna_overview.livemd

# PRAJNA C3I Mesh Cockpit - Overview

## Health Summary

```elixir
health = Indrajaal.Cockpit.Prajna.SmartMetrics.health_summary()

Kino.Markdown.new("""
| Metric | Value |
|--------|-------|
| Status | #{health.status} |
| Score | #{health.health_score}% |
| Total | #{health.total_metrics} |
| Stale | #{health.stale_count} |
| Alarmed | #{health.alarmed_count} |
""")
```

## Real-time Metrics Chart

```elixir
metrics = Indrajaal.Cockpit.Prajna.SmartMetrics.all()

data = Enum.map(metrics, fn {id, m} ->
  %{id: id, value: m.value, trend: to_string(m.trend), level: to_string(m.level)}
end)

Kino.DataTable.new(data)
```

## Sparkline Visualization

```elixir
cpu_metrics = Indrajaal.Cockpit.Prajna.SmartMetrics.get_by_pattern("*.cpu")

Enum.map(cpu_metrics, fn {id, m} ->
  chart_data = Enum.with_index(m.sparkline) |> Enum.map(fn {v, i} -> %{x: i, y: v} end)

  VegaLite.new(width: 200, height: 50)
  |> VegaLite.data_from_values(chart_data)
  |> VegaLite.mark(:line)
  |> VegaLite.encode_field(:x, "x", type: :quantitative)
  |> VegaLite.encode_field(:y, "y", type: :quantitative)
end)
|> Kino.Layout.grid(columns: 3)
```
```

## G.3 PROMETHEUS Graph Dashboard

```elixir
# prometheus_graph.livemd

# PROMETHEUS Routing Graph Visualization

## Current Graph State

```elixir
graph = Indrajaal.AI.OpenRouterClient.get_routing_graph_state()

# Create Mermaid diagram
mermaid = """
graph LR
#{Enum.map(graph.edges, fn {from, to} -> "  #{from} --> #{to}" end) |> Enum.join("\n")}
"""

Kino.Mermaid.new(mermaid)
```

## Verification Statistics

```elixir
# Live verification count
Kino.Frame.new()
|> Kino.Frame.render(fn frame ->
  Process.sleep(5000)
  stats = get_prometheus_stats()
  Kino.Frame.render(frame, Kino.Markdown.new("Verifications: #{stats.total}"))
end)
```
```

---

# Appendix H: Performance Considerations

## H.1 Performance Targets

| Operation | Target | Actual | Status |
|-----------|--------|--------|--------|
| Metric record | <1ms | ~0.5ms | OK |
| Metric read | <0.1ms | ~0.05ms | OK |
| Trend compute | <0.1ms | ~0.02ms | OK |
| Health summary | <10ms | ~5ms | OK |
| AI analysis | <5s | ~2s | OK |
| PROMETHEUS verify | <10ms | ~1ms | OK |
| UI render | <50ms | ~20ms | OK |

## H.2 Optimization Strategies

1. **ETS with read_concurrency**: Parallel metric reads
2. **Monotonic time for staleness**: Avoids DateTime overhead
3. **Sparkline limit (60)**: Bounded memory growth
4. **Insight TTL (5min)**: Automatic cleanup
5. **Batch PubSub broadcasts**: Reduced message overhead

## H.3 Resource Limits

| Resource | Limit | Enforcement |
|----------|-------|-------------|
| Metrics per table | 10,000 | Application limit |
| Sparkline length | 60 | Enum.take(60) |
| Insights cached | 50 | @max_insights |
| Audit log entries | 1,000 | Enum.take(1000) |
| Command history | 100 | Enum.take(100) |

---

# Appendix I: Next Steps

## I.1 Immediate Tasks

1. **Create comprehensive test suite** covering all components
2. **Implement Livebook dashboards** for real-time visualization
3. **Add PROMETHEUS property tests** for invariant verification
4. **Integrate fractal logging** throughout PRAJNA modules

## I.2 Short-Term Roadmap

1. Terminal.Gui implementation for cross-platform TUI
2. Phoenix LiveView dashboard integration
3. Zenoh native subscription handlers
4. CEPAF F# bridge enhancement

## I.3 Long-Term Vision

1. Multi-tenant cockpit support
2. Historical metric analysis with TimescaleDB
3. ML-based anomaly detection training
4. Distributed cockpit synchronization

---

# Appendix J: C3I Visual Display Principles (Laux, Wickens, NASA)

**Reference**: Laux, L., Howell, W., Lane, N. (1993). "Visual Display Principles for C3I System Tasks" - ResearchGate
**Supplemental**: Wickens, C.D. (1992). Engineering Psychology and Human Performance
**Standards**: NASA-STD-3000, MIL-STD-1472H, NUREG-0700

---

## J.1 Core Philosophy: The Supervisory Control Paradigm

Laux's central thesis is that modern C3I is not about "controlling" but about **Supervisory Control**. The operator does not fly the plane; they manage the automation that flies the plane.

### J.1.1 Design Rule

> **The UI must answer "What is the automation doing?" not just "What is the sensor reading?"**

### J.1.2 Application to PRAJNA

| Principle | PRAJNA Implementation |
|-----------|----------------------|
| **Automation States** | Explicitly display mesh mode: `[AUTO-HEALING]`, `[MANUAL-OVERRIDE]`, `[CONVERGING]` |
| **Intent vs. Status** | Display Target next to Current: `Speed: 45m/s [Target: 50m/s]` |
| **System Mode** | Header shows: `OODA: [ORIENT] │ Mode: AUTO │ Guardian: ACTIVE` |

### J.1.3 Supervisory Control Loop

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    SUPERVISORY CONTROL PARADIGM                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  OPERATOR                                                                    │
│     │                                                                        │
│     │ monitors                                                               │
│     ▼                                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                    PRAJNA COCKPIT DISPLAY                                ││
│  │                                                                          ││
│  │  "WHAT is the automation doing?"                                         ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │ MESH STATUS: [AUTO-HEALING]     Guardian: ACTIVE ✓              │    ││
│  │  │ Target: 5 nodes healthy         Current: 4 nodes healthy        │    ││
│  │  │ Action: Restarting node-03      ETA: 45s                        │    ││
│  │  └─────────────────────────────────────────────────────────────────┘    ││
│  │                                                                          ││
│  │  NOT just "What is the sensor reading?"                                  ││
│  │  ┌─────────────────────────────────────────────────────────────────┐    ││
│  │  │ Node-01: CPU 42% │ Node-02: CPU 38% │ Node-03: OFFLINE          │    ││
│  │  └─────────────────────────────────────────────────────────────────┘    ││
│  │                                                                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│     │                                                                        │
│     │ intervenes (if needed)                                                 │
│     ▼                                                                        │
│  AUTOMATION (OODA Loop, Guardian, Auto-Healing)                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## J.2 The 13 Fundamental Display Principles (Wickens & Laux)

These are the industry-standard cognitive rules referenced in and derived from this body of research.

### J.2.1 Category A: Perceptual Principles (Seeing)

#### Principle 1: Make Displays Legible

> **Rule**: Contrast is king. In a CLI, never use Dark Blue on Black. Use bold/bright text only for emphasis.

| Do | Don't |
|----|-------|
| `\e[96mCRITICAL\e[0m` (Cyan on dark) | `\e[34mCRITICAL\e[0m` (Blue on dark) |
| Bold for emphasis only | All-caps everything |
| Gray for normal | Multiple bright colors |

#### Principle 2: Avoid Absolute Judgment Limits

> **Rule**: Humans cannot distinguish between 5 shades of red. Use distinct variables: **Shape (Icon) + Color + Position**.

```
CLI IMPLEMENTATION:
Don't just change text color. Add a symbol:

[!] Error        ← Icon + Color + Position
[i] Info         ← Icon + Color + Position
[✓] Success      ← Icon + Color + Position

PRAJNA ICONS (3 variables per alarm):
☢ CRITICAL      ← Shape + Red + Blinking
⛔ WARNING      ← Shape + Red + Solid
⚠ CAUTION       ← Shape + Amber + Solid
ℹ ADVISORY      ← Shape + Cyan + Solid
· NORMAL        ← Shape + Gray + Solid
```

#### Principle 3: Top-Down Processing

> **Rule**: People see what they expect to see. If a signal is unexpected, it must be **salient** (flashing/inverse video) to break the mental model.

```elixir
# PRAJNA Implementation: Unexpected events use inverse video + blink
def render_critical_alarm(alarm) do
  if unexpected?(alarm) do
    "\e[7m\e[5m#{alarm.message}\e[0m"  # Inverse + Blink
  else
    "\e[91m#{alarm.message}\e[0m"       # Standard red
  end
end
```

#### Principle 4: Redundancy Gain

> **Rule**: Express the same message in two physical forms.

```
PRAJNA MULTI-MODAL ALERTING:
┌────────────────────────────────────────┐
│ VISUAL: Color (Red) + Text ("CRITICAL")│
│         + Position (Top Bar)            │
│                                         │
│ AUDITORY: System Bell (\a) for P0 alarm│
│                                         │
│ SPATIAL: Always top-left position      │
└────────────────────────────────────────┘
```

#### Principle 5: Discriminability

> **Rule**: Similarity causes confusion.

| Confusing | Discriminable |
|-----------|---------------|
| `Node 1` vs `Node 11` | `Node-01` vs `Node-11` |
| `app-a` vs `app-A` | `alpha` vs `ALPHA` |
| Similar colors | Distinct shapes |

```
PRAJNA NODE NAMING:
Bad:  node-1, node-2, node-11, node-12
Good: alpha-01, alpha-02, bravo-01, bravo-02

Or use distinct aliases:
zone-alpha.node-aurora
zone-alpha.node-boreal
zone-bravo.node-cascade
```

---

### J.2.2 Category B: Mental Model Principles (Understanding)

#### Principle 6: Pictorial Realism

> **Rule**: The display should look like the variable it represents.

```
PRAJNA BAR ORIENTATION:
If temperature goes "up", the bar should grow "up" (vertical), not sideways.

VERTICAL (Correct for "levels"):     HORIZONTAL (Correct for "progress"):
     100%│████                       [████████████░░░░░░░░] 60%
      75%│████                       Progress → Direction matches motion
      50%│████
      25%│
       0%│
         Temperature

CLI ASCII Implementation:
CPU Load (vertical concept): █ █ █ ▄ ▁  (bars go up)
Progress (horizontal):       [████░░░░░░] 40%
```

#### Principle 7: Principle of the Moving Part

> **Rule**: The movement of the display element should match the user's mental model of motion.

```
PRAJNA TRAFFIC FLOW:

If traffic is flowing INTO a node:
    ──▶ [NODE] ◀──     ← Arrows point IN

If traffic is flowing OUT of a node:
    ◀── [NODE] ──▶     ← Arrows point OUT

Data Flow:
    Source ───────▶ [PROCESSOR] ───────▶ Sink
          tx: 1.2MB/s              rx: 0.8MB/s
```

#### Principle 8: Ecological Interface Design (EID)

> **Rule**: Display the **constraints (limits)**, not just the data.

```
PRAJNA CONSTRAINT VISUALIZATION:

Don't show:    CPU: 80%

Do show:       CPU: [████████░░] 80%  (Limit: 90%)
                          ↑ Distance to disaster

SAFETY MARGIN BAR:
┌─────────────────────────────────────────────────────────────┐
│ [█████████████████████░░░▒▒▒▒▒▒XXXX] 72%                   │
│  ↑ Safe Zone        ↑ Caution  ↑ Danger                    │
│  (Green 0-75%)      (Amber)    (Red 90-100%)               │
│                                                             │
│ Current: 72% │ Margin to Caution: 3% │ Margin to Limit: 18%│
└─────────────────────────────────────────────────────────────┘
```

---

### J.2.3 Category C: Attention Principles (Focus)

#### Principle 9: Minimizing Information Access Cost

> **Rule**: Frequently used data must be visible without keystrokes.

```
PRAJNA PERSISTENT FOOTER:
┌─────────────────────────────────────────────────────────────────────────────┐
│                           [MAIN CONTENT AREA]                                │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ ● HEALTHY 94% │ Nodes: 5/5 │ Alarms: 2 ⚠ │ OODA: 850ms │ 14:32:45 CET      │
└─────────────────────────────────────────────────────────────────────────────┘
         ↑ ALWAYS VISIBLE - No keystrokes required
```

#### Principle 10: Proximity Compatibility Principle

> **Rule**: Things that are mentally related should be spatially close.

```
PRAJNA RELATED METRICS GROUPING:

BAD (separated):                    GOOD (proximate):
┌──────────────────┐               ┌──────────────────┐
│ ELECTRICAL       │               │ POWER SYSTEM     │
│ Voltage: 240V    │               │ Voltage: 240V    │
└──────────────────┘               │ Current: 2.5A    │
                                   │ Power:   600W    │
┌──────────────────┐               │ Status:  OK      │
│ LOAD             │               └──────────────────┘
│ Current: 2.5A    │
└──────────────────┘
```

#### Principle 11: Principle of Multiple Resources

> **Rule**: Distribute load between visual and auditory channels.

```elixir
# PRAJNA MULTI-CHANNEL ALERTING:

def alert_critical(alarm) do
  # Visual: Red text, top position
  render_critical_visual(alarm)

  # Auditory: System bell (offloads visual cortex)
  if alarm.level == :critical do
    IO.write("\a")  # ASCII BEL character
  end
end

# This allows operator to be looking elsewhere
# and still receive critical alerts via audio
```

---

### J.2.4 Category D: Memory Principles (Recall)

#### Principle 12: Predictive Aiding

> **Rule**: Humans are bad at predicting the future. The computer should do it.

```
PRAJNA TREND VECTORS (Derivative Display):

Current Value Only:           With Prediction:
Temp: 50°C                    Temp: 50°C (↑ 2°C/s) → 70°C in 10s
                                   ↑ Shows trajectory + ETA

CPU: 42%                      CPU: 42% ↑↑ (Rising Fast)
                              Prediction: 80% in 5 min

PREDICTIVE BAR:
[Current]─────────────▸[Predicted]
[████████░░░░░░░░░░░░░░▸████████████░░░░]
    42%                        68% (predicted)
```

#### Principle 13: Knowledge in the World (vs. in the Head)

> **Rule**: Don't make the user memorize commands.

```
PRAJNA CONTEXT-SENSITIVE HINT BAR:

Always display available actions at bottom:
┌─────────────────────────────────────────────────────────────────────────────┐
│                           [MAIN CONTENT]                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ [F1] Help  [F2] Map  [F3] Alarms  [F5] Refresh  [Esc] Back  [Q] Quit       │
└─────────────────────────────────────────────────────────────────────────────┘

CONTEXT CHANGES HINTS:
Normal View:     [F1] Help  [F2] Map  [Enter] Select
Node Selected:   [R] Restart  [I] Isolate  [L] Logs  [Esc] Deselect
Command Armed:   [Enter] Confirm  [Esc] Cancel  [T] Timer: 4:58
```

---

## J.3 C3I Specific Tasks (Laux's Extensions)

Laux identifies specific "Cognitive Primitives" in C3I that need explicit UI support:

### J.3.1 Detection: "Is something there?"

```
PRAJNA SIGNAL SNIFFER PANE:
┌─ SIGNAL ACTIVITY (Zenoh) ─────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ c3i/units/alpha/node-01/telemetry ─ 142 msg/s                              │
│ c3i/units/alpha/node-02/telemetry ─ 138 msg/s                              │
│ c3i/alarms/caution/alm-042 ────── 1 msg (new)                             │
└────────────────────────────────────────────────────────────────────────────┘
          ↑ Low contrast background activity proves system is alive
            Bright text only for notable events
```

### J.3.2 Localization: "Where is it?"

```
PRAJNA TOPOLOGY TREE:
┌─ LOCATION ─────────────────────────────────────────────────────────────────┐
│                                                                             │
│  Zone A                                                                     │
│  └─ Subnet 4                                                                │
│     └─ Node 12  ◀── SELECTED                                               │
│        ├─ CPU: 42%                                                          │
│        ├─ Memory: 68%                                                       │
│        └─ Status: Healthy                                                   │
│                                                                             │
│  Breadcrumb: Zone A > Subnet 4 > Node 12                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### J.3.3 Diagnosis: "What is it?"

```
PRAJNA DRILL-DOWN VIEW:

Press [Enter] on a node to isolate its logs from global stream:

┌─ NODE-12 DIAGNOSTIC VIEW ──────────────────────────────────────────────────┐
│                                                                             │
│  ISOLATED LOGS (filtered from global stream):                               │
│  14:32:45.123 [INFO] Heartbeat received                                     │
│  14:32:45.234 [WARN] Memory pressure detected                               │
│  14:32:45.345 [INFO] GC cycle completed (45ms)                             │
│  14:32:46.123 [INFO] Heartbeat received                                     │
│                                                                             │
│  CORRELATED EVENTS:                                                         │
│  • High memory coincides with report generation job                        │
│  • Similar pattern observed on Node-08 yesterday                           │
│                                                                             │
│  AI DIAGNOSIS (Confidence: 0.85):                                          │
│  "Memory spike likely caused by scheduled report. Non-critical."           │
│                                                                             │
│  [Esc] Return to Overview  [L] Full Logs  [A] Actions                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### J.3.4 Projection: "What will it do?"

```
PRAJNA "GHOST" VALUES (Preview before confirm):

User types: "Shutdown Node-03"

┌─ COMMAND PREVIEW ──────────────────────────────────────────────────────────┐
│                                                                             │
│  ⚠ IMPACT PROJECTION                                                       │
│                                                                             │
│  CURRENT STATE:          PROJECTED STATE (after shutdown):                 │
│  ┌────────────────┐      ┌────────────────┐                                │
│  │   [Gateway]    │      │   [Gateway]    │                                │
│  │       │        │      │       │        │                                │
│  │   ┌───┴───┐    │      │   ┌───┴───┐    │                                │
│  │   │       │    │      │   │       │    │                                │
│  │ [N1]   [N2]  [N3]│    │ [N1]   [N2]  [░░]│  ◀── Node-03 offline         │
│  │   │       │    │      │   │       │    │                                │
│  │ [N4]   [N5]    │      │ [N4]   [N5]    │                                │
│  └────────────────┘      └────────────────┘                                │
│                                                                             │
│  ⚠ WARNING: Zone B will lose redundancy                                    │
│  ⚠ WARNING: Load on N1, N2 will increase ~33%                             │
│                                                                             │
│  [Enter] Confirm Shutdown    [Esc] Cancel                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## J.4 Implementation Checklist

### J.4.1 The "Salience" Filter

Implement a logic layer that calculates a "Salience Score" for every event. Only events with Score > 50 trigger a UI popup.

```elixir
# Reference: Signal Detection Theory (d-prime)
defmodule Prajna.Salience do
  @doc """
  Calculate salience score for an event.
  Score > 50 triggers visual popup.
  Score > 80 triggers audio alert.
  Score 100 triggers emergency mode.
  """
  def calculate_score(event) do
    base_score = severity_score(event.level)
    novelty_boost = if unexpected?(event), do: 20, else: 0
    recency_boost = if first_occurrence?(event), do: 15, else: 0
    impact_boost = calculate_impact_radius(event) * 2

    min(100, base_score + novelty_boost + recency_boost + impact_boost)
  end

  defp severity_score(:critical), do: 80
  defp severity_score(:warning), do: 60
  defp severity_score(:caution), do: 40
  defp severity_score(:advisory), do: 20
  defp severity_score(:normal), do: 0
end
```

### J.4.2 The "Common Operational Picture" (COP)

Every screen must have a standardized header showing global context:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PRAJNA │ ● HEALTHY │ 14:32:45 CET │ Nodes: 5/5 │ Alarms: 2 ⚠ │ OODA: 850ms │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        [SCREEN-SPECIFIC CONTENT]                             │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ [F1] Help  [F2] Map  [F3] Alarms  [F5] Refresh  [Esc] Back  [Q] Quit       │
└─────────────────────────────────────────────────────────────────────────────┘
      ↑ COP Header (always visible)              ↑ Context Hints (always visible)
```

### J.4.3 The "Closure" Principle

Every action must have a clear beginning, middle, and end:

```
PRAJNA COMMAND LIFECYCLE:

1. INITIATION (Beginning):
   ┌──────────────────────────────────────┐
   │ Command: RESTART node-03             │
   │ Status: ◎ ARMED                      │
   │ Confirm within: 4:58                 │
   └──────────────────────────────────────┘

2. EXECUTION (Middle):
   ┌──────────────────────────────────────┐
   │ Command: RESTART node-03             │
   │ Status: ● EXECUTING ⟳                │
   │ Progress: [████████░░░░░░░░] 45%     │
   └──────────────────────────────────────┘

3. COMPLETION (End):
   ┌──────────────────────────────────────┐
   │ Command: RESTART node-03             │
   │ Status: ✓ SUCCESS                    │
   │ Duration: 12.3s                      │
   │ [Press any key to return]            │
   └──────────────────────────────────────┘

   OR

   ┌──────────────────────────────────────┐
   │ Command: RESTART node-03             │
   │ Status: ✗ FAILED                     │
   │ Error: Connection timeout            │
   │ [R] Retry  [L] Logs  [Esc] Dismiss   │
   └──────────────────────────────────────┘
```

---

## J.5 STAMP Constraints (Appendix J)

| Constraint ID | Principle | Description | Implementation |
|---------------|-----------|-------------|----------------|
| SC-VDP-001 | Supervisory Control | Show automation state, not just data | Header shows `[AUTO-HEALING]` mode |
| SC-VDP-002 | Legibility | High contrast, no blue-on-black | `@colors` palette in DarkCockpit |
| SC-VDP-003 | Redundancy Gain | Multi-modal alerting (visual + audio) | `\a` bell for critical alarms |
| SC-VDP-004 | Discriminability | Distinct node naming | `zone-alpha.node-01` format |
| SC-VDP-005 | Pictorial Realism | Bars match mental model of direction | Vertical bars for levels |
| SC-VDP-006 | EID Constraints | Show limits, not just values | Safety margin bars |
| SC-VDP-007 | Access Cost | Persistent status footer | Always-visible health bar |
| SC-VDP-008 | Proximity | Related metrics grouped | Power: V + I + W together |
| SC-VDP-009 | Predictive Aiding | Show trend vectors | `↑↑` / `→` / `↓↓` icons |
| SC-VDP-010 | Knowledge in World | Context-sensitive hints | Bottom hint bar |
| SC-VDP-011 | Detection | Signal activity pane | Zenoh traffic visualization |
| SC-VDP-012 | Localization | Topology tree with breadcrumb | Hierarchical navigation |
| SC-VDP-013 | Diagnosis | Drill-down isolation | Press Enter to filter logs |
| SC-VDP-014 | Projection | Ghost values before confirm | Impact preview panel |
| SC-VDP-015 | Salience Filter | Score-based popup threshold | `Salience.calculate_score/1` |
| SC-VDP-016 | COP | Standardized header on all screens | Global status bar |
| SC-VDP-017 | Closure | Begin/Middle/End for all commands | Command lifecycle UI |

---

## J.6 References

1. Laux, L., Howell, W., Lane, N. (1993). "Visual Display Principles for C3I System Tasks". ResearchGate.
2. Wickens, C.D. (1992). "Engineering Psychology and Human Performance". HarperCollins.
3. NASA-STD-3000, Vol. 1: Crew Systems and Habitability. Human-System Integration Standards.
4. MIL-STD-1472H: Human Engineering Design Criteria for Military Systems.
5. NUREG-0700: Human-System Interface Design Review Guidelines. Nuclear Regulatory Commission.

---

# Appendix K: Essential Research Canon & Design Standards

## K.1 Overview

This appendix catalogs the essential papers, reports, and design standards that form the "canon" of high-performance HMI for safety-critical systems. These documents move beyond basic UX ("user friendliness") to **Cognitive Engineering** (optimizing the brain's ability to process data under stress).

---

## K.2 The Core Source Document

### K.2.1 Visual Display Principles for C3I System Tasks (1993)

| Field | Value |
|-------|-------|
| **Authors** | Laux, L., Howell, W., Lane, D. |
| **Source** | U.S. Army Research Institute for the Behavioral and Social Sciences (ARI) |
| **Type** | Technical Report |

**Key Contribution**: This report bridges the gap between cognitive psychology and actual screen design. It introduced the concept that C3I is not about "control" but **Supervisory Control**—managing the automation that manages the mesh.

**Critical Principles for PRAJNA**:

1. **Principle of Predictive Aiding**: The UI must display future states (vectors), not just current states.

2. **Principle of Pictorial Realism**: If a value represents a physical quantity (e.g., bandwidth), the interface element must behave physically (e.g., a "pipe" getting wider, not just a number increasing).

---

## K.3 The "Holy Trinity" of C3I Design Theories

These three papers are the theoretical foundation for every modern mission-critical system (SpaceX, F-35, Nuclear Control).

### K.3.1 Situation Awareness (The "Brain" Model)

| Field | Value |
|-------|-------|
| **Paper** | Toward a Theory of Situation Awareness in Dynamic Systems (1995) |
| **Author** | Mica Endsley (Former Chief Scientist, US Air Force) |
| **Citation** | Human Factors, 37(1), 32-64 |

**Why PRAJNA needs it**: It defines the **3 Levels of SA** that the F# Types must support:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ENDSLEY'S SITUATION AWARENESS MODEL                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LEVEL 1: PERCEPTION          "What are the numbers?"                       │
│  ─────────────────            The raw Zenoh telemetry data                  │
│  Implementation: SmartMetric.value, raw sensor readings                      │
│                                                                              │
│  LEVEL 2: COMPREHENSION       "Is the system healthy?"                      │
│  ──────────────────           Aggregated meaning                            │
│  Implementation: Health enum, alarm_level, status classification            │
│                                                                              │
│  LEVEL 3: PROJECTION          "Will it crash in 5 mins?"                    │
│  ─────────────────            Future state prediction                       │
│  Implementation: Trend vector (↑↑/↑/→/↓/↓↓), sparkline extrapolation       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Design Rule**: Your UI **fails** if it forces the user to do Level 2/3 math in their head. The UI must **render the meaning**, not the data.

```elixir
# BAD: User must calculate health from raw numbers
"CPU: 87%, Memory: 92%, Disk: 78%"

# GOOD: UI pre-computes Level 2 (Comprehension)
"System: ⚠ CAUTION - Resources approaching limits"

# BEST: UI provides Level 3 (Projection)
"System: ⚠ CAUTION ↑↑ - Will exceed threshold in ~12 minutes"
```

### K.3.2 Ecological Interface Design (The "Mesh" Model)

| Field | Value |
|-------|-------|
| **Paper** | Ecological Interface Design for Military Command and Control (2004) |
| **Authors** | Burns, C. & Hajdukiewicz, J. |
| **Source** | University of Waterloo / DRDC Canada |

**Why PRAJNA needs it**: Standard UI design (User-Centered) fails for complex meshes because users don't know what the mesh *can do* in failure modes. EID focuses on visualizing the **Constraints**.

**Design Rule**: Do not just draw a map of nodes. Draw the **Work Domain Analysis (WDA)**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ECOLOGICAL INTERFACE DESIGN (EID)                         │
│                        Work Domain Analysis View                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ABSTRACTION LEVELS:                                                         │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  PURPOSE: "Keep the mesh operational with <100ms latency"             │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              │                                               │
│                              ▼                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  FLOWS: Data flow (→→→)   Power flow (⚡)   Control flow (⟳)         │  │
│  │                                                                       │  │
│  │     Sensors ──────→ Controllers ──────→ Actuators                    │  │
│  │        ↑               ↑    ↓               ↓                        │  │
│  │        └───────────────┘    └───────────────┘                        │  │
│  │            Feedback             Feedback                              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              │                                               │
│                              ▼                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  CONSTRAINTS: Safety margins that cannot be violated                  │  │
│  │                                                                       │  │
│  │     CPU: ████████████████████░░░░ 80%                                │  │
│  │                              └── SAFETY MARGIN ──┘                    │  │
│  │                                                                       │  │
│  │     Memory: ██████████████████████░░ 90%                             │  │
│  │                                    └── DANGER ──┘                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key EID Elements to Implement**:

1. **Show the Flow**: Data/Power moving between nodes
2. **Show the Boundaries**: Max bandwidth, battery limits, safety margins
3. **Show the Constraints**: What the system *cannot* do, not just what it's doing

### K.3.3 Multiple Resource Theory (The "Attention" Model)

| Field | Value |
|-------|-------|
| **Paper** | Engineering Psychology and Human Performance |
| **Author** | Christopher Wickens |
| **Publisher** | HarperCollins (Standard university textbook) |

**Why PRAJNA needs it**: It explains why operators miss red flashing lights when they are reading text. The brain has **separate channels** for different modalities.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WICKENS' MULTIPLE RESOURCE THEORY                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  MODALITY CHANNELS (Independent Processing):                                │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │  VISUAL-SPATIAL │  │  VISUAL-VERBAL  │  │    AUDITORY     │             │
│  │  ─────────────  │  │  ────────────   │  │  ───────────    │             │
│  │  Maps           │  │  Text logs      │  │  Beeps/bells    │             │
│  │  Topology       │  │  Labels         │  │  Voice alerts   │             │
│  │  Sparklines     │  │  Commands       │  │  Alarm tones    │             │
│  │  Bar charts     │  │  Status text    │  │                 │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│         │                    │                    │                         │
│         └────────────────────┴────────────────────┘                         │
│                              │                                               │
│                              ▼                                               │
│                    ┌─────────────────┐                                      │
│                    │  CENTRAL BRAIN  │                                      │
│                    │  (Integration)  │                                      │
│                    └─────────────────┘                                      │
│                                                                              │
│  DESIGN RULE: Use DIFFERENT channels for CONCURRENT information!            │
│  ─────────────────────────────────────────────────────────────              │
│  ✓ Visual map + Audio alert = GOOD (parallel processing)                   │
│  ✗ Text log + Text popup = BAD (channel conflict)                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Design Rule**: Modality Separation.
- Use **Text/Visuals** for spatial tasks (Map, Topology)
- Use **Audio (Beeps)** for alerts
- **Never** require reading a log while listening to a voice loop

---

## K.4 The Hard Standards (The "Bible" of Specs)

These reports contain the **exact lookup tables** for colors, blink rates, and font sizes.

### K.4.1 NUREG-0700 (The Nuclear Standard)

| Field | Value |
|-------|-------|
| **Title** | Human-System Interface Design Review Guidelines |
| **Source** | U.S. Nuclear Regulatory Commission (NRC) |
| **Sections** | Chapter 1 (Information Display), Chapter 7 (Alarms) |

**Relevance**: This is the gold standard for "Process Control." It deals with the exact same problem as PRAJNA: monitoring thousands of variables where 99% are static and 1% are critical.

**Key Concept**: "The Dark Board" (Paragraph 1.1)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     NUREG-0700: THE DARK BOARD PRINCIPLE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  WRONG: "Christmas Tree" Control Room                                        │
│  ──────────────────────────────────                                          │
│  ┌───────────────────────────────────────┐                                  │
│  │ 🔴 🟢 🔴 🟢 🟢 🔴 🟢 🔴 🔴 🟢 🔴 🟢  │  ← Everything lit up              │
│  │ 🟢 🔴 🟢 🔴 🔴 🟢 🔴 🟢 🟢 🔴 🟢 🔴  │    (operator fatigue)             │
│  │ 🔴 🟢 🔴 🟢 🟢 🔴 🟢 🔴 🔴 🟢 🔴 🟢  │                                   │
│  └───────────────────────────────────────┘                                  │
│                                                                              │
│  RIGHT: "Dark Board" (PRAJNA Default)                                        │
│  ─────────────────────────────────────                                       │
│  ┌───────────────────────────────────────┐                                  │
│  │ · · · · · · · · · · · ·              │  ← Normal = invisible            │
│  │ · · · 🟡 · · · · · · · ·              │    Only deviations visible       │
│  │ · · · · · · · · · · · ·              │                                   │
│  └───────────────────────────────────────┘                                  │
│                                                                              │
│  RULE: If a system is NORMAL, NO lights should be ON.                        │
│        Only DEVIATIONS are illuminated.                                      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### K.4.2 MIL-STD-1472H (The Military Standard)

| Field | Value |
|-------|-------|
| **Title** | Department of Defense Design Criteria Standard: Human Engineering |
| **Sections** | Section 5 (Visual Displays), Section 6 (Controls) |

**Relevance**: Section 5 defines exactly how to prevent "Mode Confusion."

**Key Concept**: "The Two-Step Actuation" (Section 5.9)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              MIL-STD-1472H: TWO-STEP ACTUATION FOR CRITICAL COMMANDS         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  No lethal/irreversible command can be executed with ONE button.             │
│  It MUST be:  SELECT → ARM → EXECUTE                                         │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  STEP 1: SELECT                                                      │    │
│  │  ─────────────                                                       │    │
│  │  User chooses target: "RESTART node-03"                              │    │
│  │  State: IDLE ○                                                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  STEP 2: ARM                                                         │    │
│  │  ──────────                                                          │    │
│  │  User presses [A] to arm command                                     │    │
│  │  State: ARMED ◎  (Countdown: 5:00)                                   │    │
│  │  Visual feedback: Command highlighted in AMBER                       │    │
│  │  Audio feedback: Single tone                                         │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  STEP 3: EXECUTE                                                     │    │
│  │  ─────────────                                                       │    │
│  │  User presses [C] to confirm execution                               │    │
│  │  State: EXECUTING ● (Progress bar shown)                             │    │
│  │  Visual feedback: Command highlighted in RED during execution        │    │
│  │  Audio feedback: Confirmation tone on success                        │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  PRAJNA Implementation: SC-HMI-004 (Two-Step Commit)                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### K.4.3 NASA-STD-3000 (The Space Standard)

| Field | Value |
|-------|-------|
| **Title** | Man-Systems Integration Standards |
| **Volume** | Volume 1, Chapter 9 (Displays) |
| **Status** | Superseded by NASA-STD-3001 but principles remain valid |

**Relevance**: Defines display requirements for life-critical monitoring.

**Key Concept**: "Trend Displays" (Section 9.4)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                NASA-STD-3000: MANDATORY TREND INDICATORS                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NASA requires that critical life-support metrics ALWAYS show a trend        │
│  arrow indicating the RATE OF CHANGE.                                        │
│                                                                              │
│  WRONG (Current state only):                                                 │
│  ───────────────────────────                                                 │
│  ┌───────────────────────────────┐                                          │
│  │  O2 Level: 21%               │  ← Is it rising or falling? Unknown!      │
│  │  CO2 Level: 0.04%            │                                           │
│  │  Cabin Pressure: 14.7 psi    │                                           │
│  └───────────────────────────────┘                                          │
│                                                                              │
│  RIGHT (State + Trend):                                                      │
│  ────────────────────────                                                    │
│  ┌───────────────────────────────┐                                          │
│  │  O2 Level: 21% →             │  ← Stable (holding at 21%)                │
│  │  CO2 Level: 0.04% ↑          │  ← Rising (may need scrubber action)      │
│  │  Cabin Pressure: 14.7 psi ↓↓ │  ← Falling fast (LEAK DETECTED!)          │
│  └───────────────────────────────┘                                          │
│                                                                              │
│  PRAJNA Implementation: SC-HMI-002 (Trend Vectors)                           │
│                                                                              │
│  Trend Encoding:                                                             │
│    ↑↑  Rising Fast   (> +10%/sample)                                        │
│    ↑   Rising        (> 0)                                                  │
│    →   Stable        (= 0 ± tolerance)                                      │
│    ↓   Falling       (< 0)                                                  │
│    ↓↓  Falling Fast  (< -10%/sample)                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## K.5 Synthesized Design Cheat Sheet

Based on the documents above, here are the **non-negotiable requirements** for PRAJNA implementation:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA COGNITIVE ENGINEERING CHEAT SHEET                  │
│                   (Synthesized from Canon Documents)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DOMAIN        RULE                    SOURCE          IMPLEMENTATION       │
│  ────────────────────────────────────────────────────────────────────────── │
│                                                                              │
│  COLOR         "Quiet Dark"            NUREG-0700      Normal = Grey         │
│                                                        Warning = Orange      │
│                                                        Critical = Red        │
│                                                        NO "Green OK" lights  │
│                                                                              │
│  LOGIC         Level 3 SA              Endsley         Create `Trend` type   │
│                                                        Calculate derivative  │
│                                                        Render ↑ or ↓         │
│                                                                              │
│  LAYOUT        Functional Grouping     EID (Burns)     Don't list A-Z        │
│                                                        Group by Function:    │
│                                                        "Sensors", "Movers"   │
│                                                                              │
│  SAFETY        Feedback Loop           Laux/Norman     Show spinner (wait)   │
│                                                        Show "Done" only when │
│                                                        Mesh confirms state   │
│                                                                              │
│  ALERTS        Salience Filter         Wickens         Background "Sniffer"  │
│                                                        Foreground "Beacon"   │
│                                                        Trigger on severity>80│
│                                                                              │
│  AUDIO         Modality Separation     Wickens         Use \a bell for alert │
│                                                        Never text+text       │
│                                                        Visual + Audio = OK   │
│                                                                              │
│  COMMANDS      Two-Step Actuation      MIL-STD-1472H   Select → Arm → Execute│
│                                                        Timeout on armed      │
│                                                        Require explicit OK   │
│                                                                              │
│  TREND         Predictive Aiding       NASA-STD-3000   Always show vector    │
│                                                        ↑↑/↑/→/↓/↓↓ encoding │
│                                                        Sparklines for 1hr    │
│                                                                              │
│  CONTEXT       Knowledge in World      Laux            Hint bar at bottom    │
│                                                        Context-sensitive     │
│                                                        No memorization need  │
│                                                                              │
│  NAMING        Discriminability        Wickens         zone-alpha.node-01    │
│                                                        Not "Node 1"          │
│                                                        3+ distinct props     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## K.6 STAMP Constraints (Appendix K)

| Constraint ID | Standard | Requirement | PRAJNA Implementation |
|---------------|----------|-------------|----------------------|
| SC-SA-001 | Endsley (1995) | Support Level 1 Perception | Raw Zenoh metrics displayed |
| SC-SA-002 | Endsley (1995) | Support Level 2 Comprehension | Health enum, alarm_level computed |
| SC-SA-003 | Endsley (1995) | Support Level 3 Projection | Trend vectors, sparkline extrapolation |
| SC-EID-001 | Burns (2004) | Show system constraints | Safety margin bars |
| SC-EID-002 | Burns (2004) | Show data flows | Topology with connection lines |
| SC-EID-003 | Burns (2004) | Show boundaries | Max thresholds visualized |
| SC-MRT-001 | Wickens | Modality separation | Visual + Audio, never text+text |
| SC-MRT-002 | Wickens | Parallel processing | Map (spatial) + Bell (audio) |
| SC-NRC-001 | NUREG-0700 | Dark Board principle | Gray default, only deviations lit |
| SC-NRC-002 | NUREG-0700 | No Christmas Tree | Minimal indicators when normal |
| SC-MIL-001 | MIL-STD-1472H | Two-step actuation | Arm → Confirm flow |
| SC-MIL-002 | MIL-STD-1472H | Prevent mode confusion | Clear state indicators |
| SC-NASA-001 | NASA-STD-3000 | Trend displays mandatory | ↑↑/↑/→/↓/↓↓ on all metrics |
| SC-NASA-002 | NASA-STD-3000 | Rate of change visible | Derivative calculation |

---

## K.7 F# Situation Awareness Module Specification

The following F# module implements Endsley's Level 2 & 3 logic:

```fsharp
/// PRAJNA Situation Awareness Module
/// Implements Endsley (1995) 3-Level SA Model
///
/// Takes raw Zenoh streams, keeps history buffer, calculates derivative (trend),
/// outputs "Semantic State" for UI rendering.
module Prajna.SituationAwareness

open System

/// Level 1: Raw perception (just the number)
type RawMetric = {
    Value: float
    Timestamp: DateTime
    Source: string
}

/// Level 2: Comprehension (what it means)
type SemanticState =
    | Normal      // All within bounds
    | Advisory    // Worth noting
    | Caution     // Needs attention soon
    | Warning     // Needs attention now
    | Critical    // Emergency

/// Level 3: Projection (where it's going)
type TrendVector =
    | RisingFast   // > +10%/sample
    | Rising       // > 0
    | Stable       // ≈ 0
    | Falling      // < 0
    | FallingFast  // < -10%/sample

/// Full SA context for rendering
type SAContext = {
    Level1_Value: float
    Level2_State: SemanticState
    Level3_Trend: TrendVector
    TimeToThreshold: TimeSpan option    // Projection: "Will exceed in X"
    Confidence: float                    // 0.0 - 1.0
}

/// History buffer for trend calculation
type MetricHistory = {
    Values: float list       // Last N samples
    Timestamps: DateTime list
    MaxSamples: int          // Typically 60 (1 hour at 1/min)
}

/// Calculate trend from history buffer
let calculateTrend (history: MetricHistory) : TrendVector =
    match history.Values with
    | [] | [_] -> Stable
    | current :: previous :: _ ->
        let delta = current - previous
        let percentChange = if previous <> 0.0 then abs(delta / previous) * 100.0 else 0.0

        if delta > 0.0 && percentChange > 10.0 then RisingFast
        elif delta > 0.0 then Rising
        elif delta < 0.0 && percentChange > 10.0 then FallingFast
        elif delta < 0.0 then Falling
        else Stable

/// Project time to threshold crossing
let projectTimeToThreshold (history: MetricHistory) (threshold: float) : TimeSpan option =
    match history.Values, history.Timestamps with
    | v1 :: v2 :: _, t1 :: t2 :: _ when v1 <> v2 ->
        let rate = (v1 - v2) / (t1 - t2).TotalSeconds
        if rate > 0.0 && v1 < threshold then
            let secondsRemaining = (threshold - v1) / rate
            Some (TimeSpan.FromSeconds(secondsRemaining))
        else None
    | _ -> None

/// Evaluate semantic state from thresholds
let evaluateState (value: float) (thresholds: Map<SemanticState, float>) : SemanticState =
    if Map.containsKey Critical thresholds && value >= thresholds.[Critical] then Critical
    elif Map.containsKey Warning thresholds && value >= thresholds.[Warning] then Warning
    elif Map.containsKey Caution thresholds && value >= thresholds.[Caution] then Caution
    elif Map.containsKey Advisory thresholds && value >= thresholds.[Advisory] then Advisory
    else Normal

/// Build full SA context for UI rendering
let buildSAContext (metric: RawMetric) (history: MetricHistory) (thresholds: Map<SemanticState, float>) : SAContext =
    let trend = calculateTrend history
    let state = evaluateState metric.Value thresholds
    let warningThreshold = thresholds |> Map.tryFind Warning |> Option.defaultValue 90.0
    let timeToThreshold = projectTimeToThreshold history warningThreshold

    {
        Level1_Value = metric.Value
        Level2_State = state
        Level3_Trend = trend
        TimeToThreshold = timeToThreshold
        Confidence = 0.95  // Could be calculated from sample variance
    }
```

---

## K.8 References (Full Bibliography)

### Primary Sources

1. **Laux, L., Howell, W., Lane, N.** (1993). *Visual Display Principles for C3I System Tasks*. U.S. Army Research Institute for the Behavioral and Social Sciences. Technical Report 991.

2. **Endsley, M.R.** (1995). Toward a Theory of Situation Awareness in Dynamic Systems. *Human Factors*, 37(1), 32-64.

3. **Burns, C.M., & Hajdukiewicz, J.R.** (2004). *Ecological Interface Design*. CRC Press.

4. **Wickens, C.D.** (1992). *Engineering Psychology and Human Performance* (2nd ed.). HarperCollins.

### Standards

5. **NUREG-0700** (Rev. 3, 2020). *Human-System Interface Design Review Guidelines*. U.S. Nuclear Regulatory Commission.

6. **MIL-STD-1472H** (2020). *Department of Defense Design Criteria Standard: Human Engineering*.

7. **NASA-STD-3000** (1995). *Man-Systems Integration Standards* (Volumes 1-4). NASA.

8. **NASA-STD-3001** (2019). *NASA Space Flight Human-System Standard* (Supersedes NASA-STD-3000).

### Supporting Literature

9. **Rasmussen, J.** (1983). Skills, Rules, and Knowledge; Signals, Signs, and Symbols, and Other Distinctions in Human Performance Models. *IEEE Transactions on Systems, Man, and Cybernetics*, SMC-13(3), 257-266.

10. **Norman, D.A.** (1988). *The Design of Everyday Things*. Basic Books.

11. **Vicente, K.J., & Rasmussen, J.** (1992). Ecological Interface Design: Theoretical Foundations. *IEEE Transactions on Systems, Man, and Cybernetics*, 22(4), 589-606.

12. **Woods, D.D., & Hollnagel, E.** (2006). *Joint Cognitive Systems: Patterns in Cognitive Systems Engineering*. CRC Press.

---

## Appendix L: Master Bibliography and Design Framework

### L.1 Foundational Research (Cognitive Engineering)

Use these papers to understand the "Why" behind every pixel. These documents prove that the UI is designed for the human brain, not just for the data.

| Document / Paper | Author / Source | Key Concept for Cockpit |
|------------------|-----------------|------------------------|
| Visual Display Principles for C3I System Tasks | Laux, Howell, Lane (1993) | **Supervisory Control**: The user is not a pilot; they are a manager of automation. The UI must show intent (Target vs Actual) and prediction (Trend Vectors). |
| Toward a Theory of Situation Awareness | Mica Endsley (1995) | **3 Levels of SA**: Types must explicitly model: 1. Perception (Raw Data), 2. Comprehension (Health State), 3. Projection (Time to Failure). |
| Ecological Interface Design (EID) | Burns & Hajdukiewicz (2004) | **Work Domain Analysis**: Don't just visualize the "nodes" (physical); visualize the "flow" and "constraints" (functional). |
| Engineering Psychology and Human Performance | Christopher Wickens | **Salience & Clutter**: Explains why operators miss red lights. Justifies using "Quiet Dark" principles (gray text for normal states). |
| Human Factors in Safety-Critical Systems | Redmill & Rajan (1997) | **Mode Confusion**: The leading cause of accidents. Justifies "Two-Step Commit" (Arm → Fire) requirement for commands. |

### L.2 Industrial Standards (The "Specs")

#### L.2.1 ISA-101: High-Performance HMI Standard

- **Source**: International Society of Automation (ISA)
- **Core Philosophy**: "Gray Backgrounds, Muted Colors"

**Color Rules (SC-ISA-001 to SC-ISA-005)**:

| Element | Color | Hex Code |
|---------|-------|----------|
| Background | Dark Grey | `#2d2d2d` |
| Background Alt | Black | `#000000` |
| Lines/Text | Light Grey | `#b0b0b0` |
| Action Color | White | `#ffffff` |
| Priority 1 (Critical) | Red + Flash + Square | `#ff0000` |
| Priority 2 (Warning) | Amber + Static + Triangle | `#ffaa00` |
| Priority 3 (Advisory) | Blue + Static | `#00aaff` |

#### L.2.2 ASM Consortium: Process Control Standard

- **Source**: Abnormal Situation Management (ASM) Consortium
- **Core Philosophy**: "Effective Operator Display Design"

**The Rule**: **Trend > Value** (SC-ASM-001)

> Never show a digital value (e.g., 45.2) without a 2-hour trend sparkline next to it.

**Implementation**: Every Metric type must carry a `History: float list` to render sparklines.

```elixir
# SC-ASM-001 Compliance: Every metric has history for sparkline
defmodule Indrajaal.Cockpit.Prajna.SmartMetric do
  defstruct [
    :value,
    :unit,
    :level,
    :trend,
    history: [],        # Last N values for sparkline (SC-ASM-001)
    timestamps: [],     # Corresponding timestamps
    threshold_warning: nil,
    threshold_critical: nil
  ]
end
```

#### L.2.3 MIL-STD-1472H: Military Human Engineering Standard

- **Source**: US Department of Defense
- **Core Philosophy**: "Design Criteria for Human Engineering"

**Feedback Latency Requirements (SC-MIL-001 to SC-MIL-004)**:

| Latency | User Experience | Requirement |
|---------|-----------------|-------------|
| < 0.1s | Instant feel | Keypress, button click |
| < 1.0s | Uninterrupted flow | Screen switch, navigation |
| > 1.0s | **Must show "Busy/Spinner"** | Loading indicator |
| > 10s | **Must show "Percent Complete"** | Progress bar |

### L.3 Software Architecture (Safety-Critical Code)

#### L.3.1 NASA "Power of 10" Rules (Adapted for Elixir)

- **Source**: Gerard Holzmann (NASA JPL)

**Application to PRAJNA**:

1. **No Unbounded Loops** (SC-NASA-001): All subscription loops must have a watchdog timeout
2. **No Dynamic Memory Post-Init** (SC-NASA-002): Pre-allocate buffers for high-frequency paths
3. **Data Isolation** (SC-NASA-003): UI process and mesh listener share no mutable state

```elixir
# SC-NASA-003: Actor model isolation via GenServer/MailboxProcessor
defmodule Indrajaal.Cockpit.Prajna.MeshListener do
  use GenServer

  # No shared mutable state - communicate via messages only
  def handle_cast({:metric_update, metric}, state) do
    # Process metric in isolated state
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", {:update, metric})
    {:noreply, state}
  end
end
```

#### L.3.2 Circuit Breaker Pattern

**Concept**: If the UI receives too many messages (e.g., a message storm from a dying node), it must not freeze.

**STAMP Constraint**: SC-CIRCUIT-001: Drop non-critical telemetry when queue > 100 messages.

```elixir
# SC-CIRCUIT-001: Circuit breaker for message storms
defmodule Indrajaal.Cockpit.Prajna.CircuitBreaker do
  @moduledoc """
  Circuit breaker for PRAJNA mesh listener.
  Prevents UI freeze during message storms.

  CONSTRAINTS:
    - SC-CIRCUIT-001: Drop telemetry when queue > 100
    - SC-CIRCUIT-002: Log dropped messages for post-mortem
    - SC-PRF-050: Maintain < 50ms response time
  """

  @queue_threshold 100

  def should_process?(mailbox_length, message_type) do
    cond do
      mailbox_length > @queue_threshold and message_type == :telemetry ->
        # Drop non-critical telemetry
        Logger.warning("Circuit breaker: dropping telemetry, queue=#{mailbox_length}")
        false

      mailbox_length > @queue_threshold * 2 ->
        # Critical: only process alarms
        message_type == :alarm

      true ->
        true
    end
  end
end
```

### L.4 Evaluation Metrics

**Key Performance Indicators for C3I Cockpit Quality**:

| Metric | Definition | Target | STAMP Constraint |
|--------|------------|--------|------------------|
| Time to Detect (TTD) | Time from "Node Failure" to "User Eyes on Pixel" | **< 2 seconds** | SC-EVAL-001 |
| Time to Recover (TTR) | Time from "User Decision" to "System Stabilized" | System Dependent | SC-EVAL-002 |
| SAGAT Score | Pause simulation, ask user: "Which node has lowest battery?" | **> 90% Accuracy** | SC-EVAL-003 |
| False Alarm Rate | Percentage of "Red Alerts" that were noise | **< 5%** | SC-EVAL-004 |

### L.5 Reference Implementations

#### L.5.1 NASA Open MCT

- **Source**: NASA Mission Control Technologies (Open Source)
- **URL**: https://github.com/nasa/openmct
- **Relevance**: Gold standard for "Hierarchical Telemetry" information architecture
- **Key Patterns**:
  - Composition-based object model
  - Time conductor for playback
  - Layout system for operator customization

#### L.5.2 ISA-101 Style Guide

- **Source**: International Society of Automation
- **Relevance**: Correct color palettes for industrial HMI
- **Key Patterns**:
  - Gray-scale defaults
  - Alarm hierarchy colors
  - Animation rules for status changes

### L.6 Additional STAMP Constraints from Standards

Based on the Master Bibliography, these additional constraints are defined:

```
SC-ISA-001: Background color MUST be #2d2d2d or darker
SC-ISA-002: Normal state text MUST be gray (#b0b0b0)
SC-ISA-003: Critical alarms MUST use red (#ff0000) with flash
SC-ISA-004: Warning alarms MUST use amber (#ffaa00)
SC-ISA-005: Advisory alarms MUST use blue (#00aaff)

SC-ASM-001: Every numeric value MUST have accompanying sparkline

SC-MIL-001: Keypress feedback < 100ms
SC-MIL-002: Screen transition < 1000ms
SC-MIL-003: Operations > 1s MUST show spinner
SC-MIL-004: Operations > 10s MUST show progress bar

SC-NASA-001: No unbounded loops (watchdog mandatory)
SC-NASA-002: No post-init dynamic allocation in hot paths
SC-NASA-003: UI and mesh threads share no mutable state

SC-CIRCUIT-001: Drop telemetry when queue > 100 messages
SC-CIRCUIT-002: Log all dropped messages

SC-EVAL-001: Time to Detect < 2 seconds
SC-EVAL-002: Time to Recover measured and logged
SC-EVAL-003: SAGAT score > 90% in operator testing
SC-EVAL-004: False alarm rate < 5%
```

---

# Appendix M: Terminal User Interface (TUI) Reference Implementations

This appendix catalogs terminal-based user interface patterns, libraries, and reference implementations relevant to PRAJNA C3I development. TUI-based interfaces offer advantages for operations centers: low latency, SSH accessibility, resource efficiency, and proven reliability in safety-critical environments.

## M.1 NOC Widget Design Principles

**Source**: LogicMonitor NOC Widget Documentation
**URL**: https://www.logicmonitor.com/support/noc-widget-creation
**Relevance**: Enterprise NOC dashboard patterns

### M.1.1 Key Design Patterns

| Pattern | Description | PRAJNA Application |
|---------|-------------|-------------------|
| **Color-Coded Alerts** | Critical (red), Error (orange), Warning (yellow), Normal (green) | ISA-101 compliant palette |
| **Grid vs Table Mode** | Grid for heat maps, Table for detailed data | Dashboard layout options |
| **Alert Status Filtering** | Selectively show/hide severity levels | Alarm Center filtering |
| **Token Insertion** | Dynamic labels using `##RESOURCEGROUP##` syntax | Dynamic metric naming |

### M.1.2 Display Modes

- **Grid Mode**: Best for capacity visualization, heat map patterns
- **Table Mode**: Configurable columns, per-item detail
- **Icon Toggle**: Maximize space efficiency

## M.2 TUI Library Ecosystem

**Source**: awesome-tuis Collection
**URL**: https://github.com/rothgar/awesome-tuis
**Relevance**: Library selection for terminal interface development

### M.2.1 Core TUI Libraries by Language

#### Go Libraries (Primary for PRAJNA CLI tools)

| Library | Description | Use Case |
|---------|-------------|----------|
| **Bubbletea** | Elm-inspired functional TUI framework | Event loops, state management |
| **tview** | Rich terminal widgets | Interactive dashboards |
| **tcell** | Low-level terminal rendering | Custom rendering |
| **Lipgloss** | Styling library | Consistent visual design |
| **Bubbles** | Reusable UI components | Common widgets |

#### Rust Libraries (High-performance components)

| Library | Description | Use Case |
|---------|-------------|----------|
| **Ratatui** | Active TUI crate (fork of tui-rs) | Real-time dashboards |
| **crossterm** | Cross-platform terminal manipulation | Input handling |

#### Python Libraries (Scripting and prototyping)

| Library | Description | Use Case |
|---------|-------------|----------|
| **Rich** | Rich text and beautiful formatting | Log output formatting |
| **Textual** | Modern TUI framework | Rapid prototyping |
| **blessed** | Practical terminal apps | Simple utilities |
| **urwid** | Console UI library | Complex forms |

#### C/C++ Libraries (System-level integration)

| Library | Description | Use Case |
|---------|-------------|----------|
| **ncurses** | Classic terminal library | Low-level control |
| **FTXUI** | Functional C++ TUI | Performance-critical UIs |

### M.2.2 System Monitoring Reference Applications

| Application | Description | Key Features |
|-------------|-------------|--------------|
| **htop** | Interactive process viewer | Resource bars, tree view |
| **btop++** | Resource monitor | Graphs, themes, extensible |
| **bottom** | Customizable system monitor | Configurable layouts |
| **k9s** | Kubernetes TUI | Resource navigation, logs |
| **lazydocker** | Docker management | Container lifecycle |

## M.3 CLAWS: AWS Resource Management TUI

**Source**: CLAWS Project
**URL**: https://github.com/clawscli/claws
**Relevance**: Complex resource management TUI patterns

### M.3.1 Interaction Model

```
Navigation Paradigms:
├── Vim-style: h/j/k/l for movement
├── Tab/Shift+Tab for widget focus
├── Arrow keys for selection
├── Colon (:) for command mode
└── Mouse support for clicking/scrolling
```

### M.3.2 Command System Pattern

| Pattern | Example | PRAJNA Application |
|---------|---------|-------------------|
| **Resource Navigation** | `:ec2/instances` | `:mesh/nodes`, `:alarms/active` |
| **Sorting** | `:sort column` | `:sort severity`, `:sort age` |
| **Filtering** | `:tag Env=prod` | `:filter level=critical` |
| **Search** | Fuzzy match | Instant filtering |

### M.3.3 Architecture Layers

```
CLAWS Architecture (applicable to PRAJNA TUI):

┌─────────────────────────────────────────┐
│           UI Layer (Bubbletea)          │
├─────────────────────────────────────────┤
│          Renderer Interface             │
│   (Terminal display abstraction)        │
├─────────────────────────────────────────┤
│          Action Framework               │
│   (Command execution handlers)          │
├─────────────────────────────────────────┤
│        DAO (Data Access Object)         │
│   (Backend API abstraction)             │
├─────────────────────────────────────────┤
│         Service Registry                │
│   (Resource types and aliases)          │
└─────────────────────────────────────────┘
```

## M.4 CoreFreq: Real-Time CPU Monitoring TUI

**Source**: CoreFreq Project
**URL**: https://github.com/cyring/CoreFreq
**Relevance**: High-frequency real-time metrics display

### M.4.1 Display Requirements

- **Minimum Dimensions**: 80 columns width, dynamic height
- **Terminal Support**: VT100, ANSI colors, optional transparency
- **Rendering**: Stalls if terminal too small (graceful degradation)

### M.4.2 View Modes

| Mode | Flag | Description |
|------|------|-------------|
| Top Monitor | (default) | Real-time performance |
| Dashboard | `-d` | Comprehensive overview |
| Sensors | `-C` | Temperature monitoring |
| Voltage | `-V` | Power supply metrics |
| Power | `-W` | Energy consumption |
| Topology | `-m` | CPU & cache hierarchy |
| System Info | `-s` | Processor specifications |

### M.4.3 Real-Time Metrics Patterns

```
Metric Display Features:
├── Frequency: Core frequencies with base clock
├── Performance: IPS/IPC/CPI per-core breakdowns
├── Thermal: Temperature with unit conversion (C/F)
├── Power States: C-state tracking, turbo status
└── Color Themes: Multiple selectable palettes
```

## M.5 termui: Go Terminal Dashboard Library

**Source**: gizak/termui
**URL**: https://github.com/gizak/termui
**Relevance**: Widget-based dashboard construction

### M.5.1 Widget Inventory

| Category | Widgets | PRAJNA Usage |
|----------|---------|--------------|
| **Data Viz** | BarChart, StackedBarChart, PieChart, Gauge, Sparkline | Metric cards |
| **Plotting** | Canvas (braille), Plot (scatter/line) | Trend visualization |
| **Text** | Paragraph, List, Tree, Table | Logs, node lists |
| **Navigation** | Tabs | View switching |
| **Media** | Image | Status icons |

### M.5.2 Layout System

```go
// Relative Grid Layout
ui.SetRect(0, 0, termWidth, termHeight)
grid := ui.NewGrid()
grid.Set(
    ui.NewRow(0.3,
        ui.NewCol(0.5, widget1),
        ui.NewCol(0.5, widget2),
    ),
    ui.NewRow(0.7, widget3),
)

// Absolute Positioning
widget.SetRect(x1, y1, x2, y2)
```

### M.5.3 Event Handling

```go
events := ui.PollEvents()
for {
    e := <-events
    switch e.ID {
    case "q", "<C-c>":
        return
    case "<Resize>":
        // Handle terminal resize
    }
}
```

## M.6 Nerdlog: Distributed Log Viewer TUI

**Source**: Nerdlog Project
**URL**: https://github.com/dimonomid/nerdlog
**Relevance**: Multi-host log aggregation and visualization

### M.6.1 Core Design Philosophy

- **Remote-First**: SSH-based, no central server required
- **Fast Query**: Analysis done on remote nodes
- **Distributed**: Parallel queries across hosts
- **Timeline Histogram**: Visual log intensity analysis

### M.6.2 Navigation Paradigms

| Mode | Keys | Description |
|------|------|-------------|
| **Conventional** | Tab, Arrows, PgUp/PgDn | Standard navigation |
| **Browser-like** | Alt+Left/Right, F5 | History, refresh |
| **Vim-like** | h/j/k/l, Esc, : | Modal navigation |

### M.6.3 Query Architecture

```
Distributed Query Flow:

Host-1 ─┐
Host-2 ─┼─→ [SSH Query] ─→ [Filter/Aggregate] ─→ [Merged Display]
Host-N ─┘

Per-host data returned:
├── Up to 250 messages per logstream
├── Timeline histogram data
└── Connection status indicators
```

### M.6.4 Visual Status Indicators

| Icon/Color | Meaning |
|------------|---------|
| 🟢 Green | Connected, healthy |
| 🟠 Orange | Degraded, partial |
| 🔴 Red | Disconnected, error |

## M.7 otel-tui: OpenTelemetry Terminal Viewer

**Source**: otel-tui Project
**URL**: https://github.com/ymtdzzz/otel-tui
**Relevance**: OTEL traces, metrics, logs visualization

### M.7.1 Supported Protocols

| Protocol | Port | Description |
|----------|------|-------------|
| OTLP gRPC | 4317 | Standard OTEL protocol |
| OTLP HTTP | 4318 | HTTP variant |
| Zipkin | 9411 | Optional trace format |
| Prometheus | Custom | Metrics scraping |

### M.7.2 Visualization Dashboards

#### Traces Dashboard
```
Trace Visualization:
├── Distributed trace hierarchy
├── Span timeline with duration bars
├── Service topology view
├── Filtering by service/operation
└── Trace detail panel
```

#### Metrics Dashboard
```
Metric Types Rendered:
├── Gauge: Current value with sparkline
├── Sum: Cumulative with rate calculation
├── Histogram: Distribution visualization
└── Real-time streaming with filtering
```

#### Logs Dashboard
```
Log Features:
├── Filterable log stream
├── Trace/Span correlation
├── Log body clipboard (press 'y')
└── Severity-based coloring
```

### M.7.3 Memory Management

- **Buffer Limit**: 1000 service root spans
- **Log Retention**: 1000 log entries
- **Rotation**: FIFO eviction when full

## M.8 PRAJNA TUI Implementation Guidelines

Based on the reference implementations above, these patterns are recommended for PRAJNA terminal interfaces:

### M.8.1 Recommended Stack

```
PRAJNA TUI Technology Stack:

┌─────────────────────────────────────────┐
│     Bubbletea (Event Loop/State)        │
├─────────────────────────────────────────┤
│     Lipgloss (Styling/Colors)           │
├─────────────────────────────────────────┤
│     Bubbles (Widget Components)         │
├─────────────────────────────────────────┤
│     termui (Charts/Gauges)              │
└─────────────────────────────────────────┘
```

### M.8.2 Navigation Standards

| Key | Action | Notes |
|-----|--------|-------|
| `j/k` | Up/Down | Vim-style |
| `h/l` | Left/Right | Panel navigation |
| `Tab` | Next widget | Focus cycling |
| `Esc` | Normal mode | Exit command mode |
| `:` | Command mode | Vim-like commands |
| `q` | Quit | With confirmation for unsafe |
| `/` | Search | Fuzzy filtering |
| `?` | Help | Show key bindings |

### M.8.3 STAMP Constraints for TUI

```
SC-TUI-001: Terminal minimum 80x24, graceful stall if smaller
SC-TUI-002: Refresh rate configurable (100ms to 5s)
SC-TUI-003: Color themes MUST include high-contrast option
SC-TUI-004: All actions MUST have keyboard shortcuts
SC-TUI-005: Mouse support optional, keyboard always works
SC-TUI-006: Screen updates < 50ms for real-time feel
SC-TUI-007: Memory-bounded buffers with FIFO eviction
SC-TUI-008: SSH-compatible (no local-only features)
```

### M.8.4 Widget Mapping to PRAJNA Components

| PRAJNA Component | TUI Widget | Library |
|------------------|------------|---------|
| Health Score | Gauge | termui |
| Metric Trends | Sparkline | termui |
| Node List | Table/Tree | Bubbles |
| Alarm Feed | List | Bubbles |
| CPU/Memory Bars | BarChart | termui |
| Topology Graph | Canvas | termui |
| Log Viewer | Paginated List | Custom |
| Command Input | TextInput | Bubbles |

---

*Document generated by Cybernetic Architect*
*PRAJNA C3I Mesh Cockpit Specification v1.0.0*
*Updated 2025-12-27 with TUI Reference Implementations*
