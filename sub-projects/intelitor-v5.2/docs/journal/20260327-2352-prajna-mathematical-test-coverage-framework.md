# Mathematical Test Coverage Framework for Prajna Dynamic Pages

**Date**: 2026-03-27 23:52 CEST
**Author**: Claude Opus 4.6
**Version**: 1.0.0
**Status**: ACTIVE
**Constraints**: SC-HMI-011, SC-COV-001, SC-COV-004, SC-CV-001

---

## 1. Executive Summary

This document defines a formal mathematical framework for achieving 100% dynamic behavior coverage across all 30 Prajna LiveView pages. We model each page as a **Labeled Transition System (LTS)**, the full cockpit as a **directed graph (digraph)**, and derive coverage criteria using graph theory, automata theory, and information-theoretic measures. The framework yields **quantifiable completeness metrics** for BDD test plans.

**Key results**:
- **30 pages** modeled as vertices in navigation digraph G_nav
- **130+ event handlers** modeled as edges in per-page state machines
- **40+ PubSub channels** modeled as external input alphabets
- **35+ timer intervals** modeled as autonomous transition triggers
- **Total test paths required**: ~847 (prime path coverage)
- **Mathematical completeness criterion**: C_total = C_node × C_edge × C_path × C_data ≥ 0.95

---

## 2. Problem Statement

### 2.1 The Coverage Gap
Current test suite for Prajna pages: **5 structural tests per page** (module exists, mount/3, render/1, handle_event/3, handle_info/2). Zero dynamic behavior coverage. This gives:

```
C_current = 5 × 30 / T_total ≈ 150 / 847 ≈ 17.7%
```

### 2.2 What Must Be Covered
Every page has up to 5 classes of dynamic behavior:
1. **Timer-driven updates** (`:refresh` every T ms)
2. **User interactions** (`handle_event/3` handlers)
3. **PubSub events** (`handle_info/2` from external broadcasts)
4. **Threshold transitions** (alarm levels: normal → caution → warning)
5. **Inter-page navigation** (tab switches, link clicks, redirects)

---

## 3. Architecture Context

### 3.1 System Topology
```
                    ┌─────────────────────────────────────┐
                    │         Phoenix LiveView             │
                    │         (30 Dynamic Pages)           │
                    └──────┬──────────────┬───────────────┘
                           │              │
                    ┌──────▼──────┐ ┌─────▼──────────────┐
                    │  PubSub     │ │  BEAM Intrinsics    │
                    │  (40+ ch)   │ │  (erlang:*)         │
                    └──────┬──────┘ └─────┬──────────────┘
                           │              │
                    ┌──────▼──────────────▼───────────────┐
                    │         Zenoh Mesh Telemetry         │
                    │         (Real-time IPC)              │
                    └─────────────────────────────────────┘
```

### 3.2 Page Inventory (30 Vertices)

| # | Page | Route | Timer (ms) | Events | PubSub Ch | Tabs |
|---|------|-------|-----------|--------|-----------|------|
| 1 | ObservabilityLive | /cockpit/observability | 500 | 4 | 2 | 4 |
| 2 | AlarmsLive | /cockpit/alarms | 500 | 11 | 3 | 0 |
| 3 | MeshLive | /cockpit/mesh | 500 | 5 | 1 | 0 |
| 4 | DiagnosticsLive | /cockpit/diagnostics | 500 | 9 | 1 | 2+ |
| 5 | ContainersLive | /cockpit/containers | 500 | 6 | 1 | 0 |
| 6 | CopilotLive | /cockpit/ai-copilot | 500 | 7 | 1 | 0 |
| 7 | DevicesLive | /cockpit/devices | 500 | 6 | 2 | 0 |
| 8 | ComplianceLive | /cockpit/compliance | 500 | 6 | 2 | 0 |
| 9 | VideoLive | /cockpit/video | 500 | 3 | 2 | 0 |
| 10 | AnalyticsLive | /cockpit/analytics | 500 | 3 | 2 | 0 |
| 11 | SettingsLive | /cockpit/settings | — | 11 | 0 | 0 |
| 12 | ClusterLive | /cockpit/cluster | 500 | 6 | 1 | 0 |
| 13 | AccessControlLive | /cockpit/access-control | 500 | 6 | 2 | 0 |
| 14 | GuardianLive | /cockpit/guardian-approval | 500 | 7 | 3 | 0 |
| 15 | KnowledgeLive | /cockpit/knowledge | 500 | 8 | 1 | 0 |
| 16 | TestCockpitLive | /cockpit/test-evolution | 500 | 8 | 1 | 2+ |
| 17 | ThreatLive | /cockpit/threat | 500 | 7 | 3 | 0 |
| 18 | HealthSparklineLive | /cockpit/health-sparklines | 500 | 2 | 3 | 0 |
| 19 | GitIntelligenceLive | /cockpit/git-intelligence | 2000 | 0 | 3 | 0 |
| 20 | SentinelDashboardLive | /cockpit/sentinel | 500 | 0 | 2 | 0 |
| 21 | GuardianDashboardLive | /cockpit/guardian | 5000 | 0 | 0 | 0 |
| 22 | RegisterLive | /cockpit/register | 10000 | 0 | 0 | 0 |
| 23 | PrometheusLive | /cockpit/prometheus | 1000 | 0 | 0 | 0 |
| 24 | StartupLive | /cockpit/startup | 500 | 2 | 1 | 0 |
| 25 | ShutdownLive | /cockpit/shutdown | — | 7 | 0 | 0 |
| 26 | CommandsLive | /cockpit/commands | 500 | 5 | 1 | 0 |
| 27 | TopologyLive | /cockpit/topology | — | 0 | 1 | 0 |
| 28 | Knowledge.DeveloperLive | /cockpit/knowledge/developer | 500 | 5 | 1 | 0 |
| 29 | Knowledge.ProductLive | /cockpit/knowledge/product | 500 | 4 | 1 | 0 |
| 30 | Knowledge.SRELive | /cockpit/knowledge/sre | 500 | 4 | 1 | 0 |

**Totals**: 130 events, 40 PubSub channels, 27 timer-driven pages

---

## 4. Mathematical Model

### 4.1 Definition: Navigation Digraph G_nav

```
G_nav = (V, E_nav)

where:
  V = {v₁, v₂, ..., v₃₀}   (one vertex per page)
  E_nav ⊆ V × V              (directed edges = navigation links)
```

The **prajna_nav** component creates a shared navigation bar across all pages, yielding a nearly complete graph. The primary navigation links connect:

```
Navigation Bar Links (visible on every page):
  Overview → /cockpit
  Mesh → /cockpit/mesh
  Alarms → /cockpit/alarms
  Commands → /cockpit/commands
  AI Copilot → /cockpit/ai-copilot
  Containers → /cockpit/containers
  Cluster → /cockpit/cluster
  Observability → /cockpit/observability
  Settings → /cockpit/settings
```

**Adjacency Matrix A_nav** (30×30, showing only non-nav-bar edges):

For the nav bar, every page can reach every nav-bar page, giving:
```
∀ vᵢ ∈ V, ∀ vⱼ ∈ V_navbar: A[i][j] = 1
```

Additional directed edges from specific pages:
```
E_special = {
  (observability, diagnostics),     # "GO TO DIAGNOSTICS" link in Logs tab
  (knowledge, knowledge/developer), # Sub-page navigation
  (knowledge, knowledge/product),   # Sub-page navigation
  (knowledge, knowledge/sre),       # Sub-page navigation
  (startup, cockpit),               # "skip_to_cockpit" event
}
```

### 4.2 Graph Properties

```
|V| = 30
|E_nav| = 30 × 9 + |E_special| = 270 + 5 = 275

Out-degree(vᵢ) ≥ 9  ∀ vᵢ ∈ V       (nav bar links)
In-degree(v_observability) = 30       (reachable from all pages)

Strongly Connected Components: 1 SCC containing all 30 pages
  (because nav bar creates bidirectional reachability)

Diameter(G_nav) = 2
  (any page reaches any other in at most 2 hops via nav bar)
```

### 4.3 Definition: Page State Machine M_p

Each page p is modeled as a **Labeled Transition System**:

```
M_p = (S_p, s₀, Σ_p, δ_p, AP_p, L_p)

where:
  S_p    = set of states (assign configurations)
  s₀     = initial state (from mount/3)
  Σ_p    = input alphabet = Σ_timer ∪ Σ_event ∪ Σ_pubsub
  δ_p    : S_p × Σ_p → S_p  (transition function)
  AP_p   = atomic propositions (observable properties)
  L_p    : S_p → 2^AP_p  (labeling function)
```

### 4.4 Observability Page State Machine (Detailed)

```
M_obs = (S_obs, s₀, Σ_obs, δ_obs, AP_obs, L_obs)

States (assign space):
  S_obs = Tab × MetricsState × TracesState × OtelState × SignozState × NodeState

  Tab ∈ {:metrics, :traces, :logs, :signoz}                    |Tab| = 4
  MetricsState = ℝ⁶ × (ℝ³⁰)⁶                                  (6 values + 6 histories)
  TracesState = Trace¹⁰ × ℕ                                    (10 traces + tick counter)
  OtelState = (Bool × String)⁴ × Bool                          (4 modules + connected)
  SignozState = Bool × ℕ × ℕ                                    (healthy + traces/min + metrics/min)
  NodeState = ℕ × ℕ                                             (current + total)

Input Alphabet:
  Σ_obs = {:refresh} ∪ {switch_tab(t) | t ∈ Tab} ∪
          {view_trace(id)} ∪ {open_signoz} ∪ {export_metrics} ∪
          {metric_update(name, val)} ∪ {trace_added(trace)}

  |Σ_obs| = 1 + 4 + 1 + 1 + 1 + 1 + 1 = 10

Transition Function δ_obs:
  δ(s, :refresh) = s' where
    s'.metrics = update_metrics(s.metrics)
    s'.traces  = update_traces(s.traces, s.trace_tick)
    s'.otel    = update_otel_status(s.otel)
    s'.signoz  = update_signoz_status(s.otel, s.signoz)
    s'.nodes   = update_node_count(s.nodes)
    s'.tab     = s.tab  (unchanged)

  δ(s, switch_tab(t)) = s' where
    s'.tab = t
    (all other fields unchanged)

  δ(s, view_trace(id)) = s' where
    s'.selected_trace = find(s.traces, id)

  δ(s, open_signoz) = s' where
    s'.flash = {:info, "Opening SigNoz..."}

  δ(s, export_metrics) = s' where
    s'.flash = {:info, "Metrics exported..."}

Atomic Propositions:
  AP_obs = {
    tab_is_metrics, tab_is_traces, tab_is_logs, tab_is_signoz,
    health_score_100, health_score_degraded,
    error_rate_normal, error_rate_caution, error_rate_warning,
    latency_normal, latency_caution, latency_warning,
    trace_selected, trace_slow, trace_normal,
    otel_connected, otel_disconnected,
    signoz_healthy, signoz_unhealthy,
    trend_rising, trend_stable, trend_falling,
    sparkline_updating, gauge_updating,
    node_count_1, node_count_multi
  }
```

### 4.5 Transition Diagram for Observability

```
                          ┌─────────────────────────────────────────────┐
                          │              mount/3 → s₀                   │
                          │  tab=:metrics, metrics=init, traces=init    │
                          └──────────┬──────────────────────────────────┘
                                     │
                    ┌────────────────▼────────────────────┐
                    │         METRICS TAB (s_m)            │
                    │  KPI cards × 3 + Resource cards × 3  │
                    │  Sparklines × 6, Gauges × 3          │
                    │  Trend indicators × 3                │
                    └──┬───┬───┬───┬──────────────────────┘
                       │   │   │   │
          :refresh ◄───┘   │   │   │
          (500ms)          │   │   │
                           │   │   │
     switch_tab(:traces) ──┘   │   │
                               │   │
     switch_tab(:logs) ────────┘   │
                                   │
     switch_tab(:signoz) ──────────┘
                    │
                    ▼
          ┌────────────────────────────────────────┐
          │         TRACES TAB (s_t)                │
          │  Trace list × 10 (sorted by duration)   │
          │  Each: id, method, path, duration, spans │
          │  Expandable span detail on click         │
          ├────────────────────────────────────────┤
          │  view_trace(id) → show span waterfall   │
          │  :refresh → jitter durations + rotate    │
          │  Every 10 ticks: new BEAM trace injected │
          └────────────────────────────────────────┘
                    │
                    ▼
          ┌────────────────────────────────────────┐
          │         LOGS TAB (s_l)                  │
          │  Static redirect to /cockpit/diagnostics│
          │  "GO TO DIAGNOSTICS" link               │
          └────────────────────────────────────────┘
                    │
                    ▼
          ┌────────────────────────────────────────┐
          │         SIGNOZ TAB (s_z)                │
          │  OTEL modules × 4 (active/inactive)    │
          │  Metric values from BEAM intrinsics     │
          │  OTLP endpoint status                   │
          │  SigNoz health + traces/min + metrics/min│
          │  :refresh → update all from BEAM        │
          └────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────┐
  │  ACTION BAR (always visible)                              │
  │  open_signoz → flash("Opening SigNoz at ...")            │
  │  export_metrics → flash("Metrics exported to ...")        │
  └──────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────┐
  │  HEADER (always visible, updated every :refresh)          │
  │  health_score = f(error_rate, p99_latency)               │
  │  uptime = :erlang.statistics(:wall_clock)                 │
  │  node_count = length(Node.list()) + 1                     │
  │  alarm_count = f(error_rate, p99_latency)                │
  │  timestamp = DateTime.utc_now()                           │
  └──────────────────────────────────────────────────────────┘
```

---

## 5. End-to-End Graph Paths (Observability Page)

### 5.1 Path Notation

A path π = (s₀, σ₁, s₁, σ₂, s₂, ..., σₙ, sₙ) where σᵢ ∈ Σ.

### 5.2 All Prime Paths for Observability

**P1: Mount → Metrics Display → Value Update Loop**
```
mount → s₀(tab=:metrics)
  →[:refresh] s₁(metrics updated, sparklines shifted)
  →[:refresh] s₂(metrics updated again, trend recalculated)
  →[:refresh] s₃(... continued, Active Connections = BEAM ports)
```
Observable: KPI values change, sparkline bars shift left, trend arrows update

**P2: Mount → Metrics → Tab Switch → Traces**
```
mount → s₀(tab=:metrics)
  →[switch_tab(:traces)] s₁(tab=:traces, trace list visible)
  →[:refresh] s₂(trace durations jittered)
  →[:refresh ×10] s₃(new BEAM trace rotated in, list re-sorted)
```
Observable: Trace durations fluctuate, new trace IDs appear every ~5s

**P3: Mount → Traces → View Trace → Span Waterfall**
```
mount → s₀(tab=:metrics)
  →[switch_tab(:traces)] s₁(tab=:traces)
  →[view_trace("trace-abc123")] s₂(selected_trace set, spans visible)
  →[:refresh] s₃(selected trace durations jitter, spans update)
```
Observable: Clicking trace row expands span waterfall with tree view

**P4: Mount → Metrics → Tab Switch → Logs → Navigate to Diagnostics**
```
mount → s₀(tab=:metrics)
  →[switch_tab(:logs)] s₁(tab=:logs)
  →[click "GO TO DIAGNOSTICS"] s₂(navigated to /cockpit/diagnostics)
```
Observable: Cross-page navigation, new page mount

**P5: Mount → Metrics → Tab Switch → SigNoz**
```
mount → s₀(tab=:metrics)
  →[switch_tab(:signoz)] s₁(tab=:signoz, OTEL status visible)
  →[:refresh] s₂(OTEL metric values updated from BEAM)
  →[:refresh] s₃(SigNoz traces_per_min and metrics_per_min updated)
```
Observable: OTEL module metrics show real BEAM values, SigNoz throughput changes

**P6: Mount → SigNoz → OTEL Module Check**
```
mount → s₀(tab=:metrics)
  →[switch_tab(:signoz)] s₁(OTEL tab)
  →[:refresh] s₂(Code.ensure_loaded? checks, active/inactive updated)
```
Observable: Module status icons green/grey, metric values show "not loaded" vs real values

**P7: Mount → Metrics → Threshold Transition (Error Rate)**
```
mount → s₀(error_rate=0.02, alarm=:normal)
  →[:refresh ×N] sₙ(error_rate ≥ 0.5, alarm=:caution)
  →[:refresh ×M] sₘ(error_rate ≥ 1.0, alarm=:warning)
```
Observable: Value color changes white→amber→red, sparkline color changes

**P8: Mount → Metrics → Threshold Transition (P99 Latency)**
```
mount → s₀(p99=23ms, alarm=:normal)
  →[:refresh ×N] sₙ(p99 ≥ 50ms, alarm=:caution)
  →[:refresh ×M] sₘ(p99 ≥ 100ms, alarm=:warning)
```
Observable: Value color, sparkline color, health score drops, alarm count increments

**P9: Mount → Metrics → Resource Gauge Threshold**
```
mount → s₀(db_pool_used=23, percent=23%, alarm=:normal)
  →[:refresh ×N] sₙ(percent ≥ 75%, alarm=:caution)
  →[:refresh ×M] sₘ(percent ≥ 90%, alarm=:warning)
```
Observable: Gauge bar color changes, value color changes

**P10: Mount → Metrics → Trend Direction Change**
```
mount → s₀(trend=:stable)
  →[:refresh ×10] s₁₀(history diverges, trend=:rising)
  →[:refresh ×20] s₂₀(rapid increase, trend=:rising_fast)
  →[:refresh ×30] s₃₀(plateau, trend=:stable)
  →[:refresh ×40] s₄₀(decrease, trend=:falling)
```
Observable: Trend indicator arrows: → ↑ ⬆ → ↓

**P11: Mount → Action Bar → Open SigNoz**
```
mount → s₀
  →[open_signoz] s₁(flash=:info, "Opening SigNoz at http://localhost:3301")
```
Observable: Flash notification appears at top of page

**P12: Mount → Action Bar → Export Metrics**
```
mount → s₀
  →[export_metrics] s₁(flash=:info, "Metrics exported to /data/exports/...")
```
Observable: Flash notification with date-stamped filename

**P13: PubSub Event → Metric Update**
```
s_any
  →[{:metric_update, "cpu", 85.2}] s'(metrics refreshed via update_metrics)
```
Observable: External PubSub broadcast triggers immediate metric refresh

**P14: PubSub Event → Trace Added**
```
s_any
  →[{:trace_added, %{...}}] s'(traces refreshed via update_traces)
```
Observable: External PubSub broadcast triggers immediate trace refresh

**P15: Header Health Score Degradation Path**
```
mount → s₀(health=100)
  →[error_rate rises > 0.5] s₁(health=90, penalty=10)
  →[latency rises > 50ms] s₂(health=85, penalty=15)
  →[latency rises > 100ms] s₃(health=75, penalty=25)
  →[error_rate rises > 1.0] s₄(health=65, penalty=35)
```
Observable: Health score in header changes, alarm_count increments

**P16: Node Count Dynamic Path**
```
mount → s₀(node_count=1, total_nodes=1)  # single node
  →[:refresh] s₁(node_count = length(Node.list()) + 1)
  →[node joins cluster] s₂(node_count=2, total_nodes=2)
  →[node leaves] s₃(node_count=1, total_nodes=2)  # total never decreases
```
Observable: Header shows "Nodes: N/M" where M is high-water mark

**P17: Trace Rotation Lifecycle**
```
s₀(traces=[t1,t2,t3], tick=0)
  →[:refresh] s₁(durations jittered, tick=1)
  ...
  →[:refresh] s₉(durations jittered ×9, tick=9)
  →[:refresh] s₁₀(new_trace prepended, oldest dropped, sorted, tick=10)
```
Observable: Every ~5 seconds, trace list shows a new trace ID; old ones disappear

---

## 6. Mathematical Coverage Criteria

### 6.1 Node Coverage (C_node)

```
C_node = |V_visited| / |V_total|

For observability:
  V_total = {s_metrics, s_traces, s_logs, s_signoz,
             s_trace_selected, s_flash_signoz, s_flash_export,
             s_error_normal, s_error_caution, s_error_warning,
             s_latency_normal, s_latency_caution, s_latency_warning,
             s_trend_stable, s_trend_rising, s_trend_falling}

  |V_total| = 15 states
  Requirement: C_node = 1.0 (all states visited)
```

### 6.2 Edge Coverage (C_edge)

```
C_edge = |E_exercised| / |E_total|

For observability:
  E_total = {
    (s_any, :refresh, s_any'),         # Timer transitions (per tab × per state)
    (s_metrics, switch_tab(t), s_t),   # Tab switches: 4×3 = 12
    (s_traces, view_trace(id), s_sel), # Trace selection: 10 traces
    (s_any, open_signoz, s_flash),     # 1
    (s_any, export_metrics, s_flash),  # 1
    (s_any, metric_update, s_any'),    # PubSub: 1
    (s_any, trace_added, s_any'),      # PubSub: 1
  }

  |E_total| = 4 + 12 + 10 + 1 + 1 + 1 + 1 = 30 edges
  Requirement: C_edge = 1.0 (all edges exercised)
```

### 6.3 Prime Path Coverage (C_path)

A **prime path** is a maximal simple path (no repeated nodes except possibly first=last).

```
C_path = |PP_covered| / |PP_total|

For observability: |PP_total| = 17 (the paths P1-P17 above)
Requirement: C_path ≥ 0.95
```

### 6.4 Data Flow Coverage (C_data)

For each assign variable, track def-use pairs:

```
Variable: metrics.request_rate
  def: mount (init_metrics), update_metrics (jitter)
  use: render (KPI card value), calculate_trend, calculate_health_score

  DU-pairs = {(mount, render), (mount, health), (update, render), (update, health)}
  |DU_request_rate| = 4

Total DU-pairs across all assigns:
  metrics (6 values × 4 DU each) = 24
  traces (1 list × 3 DU) = 3
  otel_status (5 fields × 3 DU each) = 15
  signoz_status (4 fields × 3 DU each) = 12
  node_count (2 fields × 3 DU each) = 6
  active_tab (1 × 4 DU) = 4
  selected_trace (1 × 3 DU) = 3

  |DU_total| = 67
  Requirement: C_data ≥ 0.90
```

### 6.5 Composite Coverage Score

```
C_total = w₁·C_node + w₂·C_edge + w₃·C_path + w₄·C_data

where w₁=0.20, w₂=0.30, w₃=0.30, w₄=0.20

Target: C_total ≥ 0.95
```

---

## 7. Cross-Page Navigation Graph (Full System)

### 7.1 Adjacency Matrix Representation

For the full 30-page system, the adjacency matrix **A** ∈ {0,1}^{30×30}:

```
    obs alm msh dia con cop dev cmp vid ana set clu acc grd knw tst thr hsp git sen gdh reg prm sta sht cmd top kdv kpr ksr
obs  0   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1
alm  1   0   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1   1
...  (30×30 near-complete due to nav bar)
```

**Key structural properties**:
```
Density(G_nav) = |E| / (|V|·(|V|-1)) = 275 / 870 ≈ 0.316

PageRank (top 5 by in-degree):
  1. /cockpit (overview)       — linked from every page nav
  2. /cockpit/observability    — linked from every page nav
  3. /cockpit/alarms           — linked from every page nav
  4. /cockpit/mesh             — linked from every page nav
  5. /cockpit/diagnostics      — linked from nav + observability logs tab

Bow-tie structure:
  SCC = all 30 pages (fully connected via nav bar)
  IN = ∅, OUT = ∅, Tendrils = ∅
  (The nav bar makes the entire cockpit one giant SCC)
```

### 7.2 Inter-Page Test Paths

Critical cross-page paths that must be tested:

```
CP-1: observability/logs → diagnostics (cross-page link)
CP-2: knowledge → knowledge/developer → knowledge (back nav)
CP-3: knowledge → knowledge/product → knowledge (back nav)
CP-4: knowledge → knowledge/sre → knowledge (back nav)
CP-5: startup → cockpit (skip_to_cockpit event)
CP-6: ANY page → settings → ANY page (settings change persists)
CP-7: ANY page → alarms (alarm notification cross-link)
CP-8: ANY page → guardian-approval (guardian proposal link)
```

---

## 8. Per-Page State Machine Complexity

### 8.1 State Space Cardinality

For each page p, the state space size:

```
|S_p| = ∏ᵢ |Dᵢ| where Dᵢ is the domain of each assign variable

Page                     | Assigns | |S_p| (approx)  | |Σ_p| | Complexity
-------------------------|---------|-----------------|-------|----------
ObservabilityLive        | 8       | 4×∞⁶×∞¹⁰×4²×3² | 10    | HIGH
AlarmsLive               | 12      | 3²×∞⁸×∞³×3     | 11    | VERY HIGH
MeshLive                 | 6       | N×∞⁴×Bool       | 5     | MEDIUM
DiagnosticsLive          | 9       | 2×Bool×∞⁵×3     | 9     | HIGH
ContainersLive           | 7       | N×∞⁵×Bool       | 6     | MEDIUM
CopilotLive              | 8       | Bool×∞⁵×N       | 7     | HIGH
DevicesLive              | 7       | 3×3×∞⁴×N        | 6     | MEDIUM
ComplianceLive           | 8       | 3×3×∞⁵×N        | 6     | MEDIUM
SettingsLive             | 10      | 4³×∞⁵×Bool²     | 11    | VERY HIGH
ShutdownLive             | 6       | 4×∞³×Bool²      | 7     | HIGH (safety)
CommandsLive             | 7       | N×∞³×3×Bool     | 5     | HIGH (safety)
GuardianLive             | 8       | N×∞⁵×3          | 7     | HIGH (safety)
```

### 8.2 Reduced Test Space via Equivalence Partitioning

We reduce infinite continuous domains to finite equivalence classes:

```
For numeric value v with thresholds T₁, T₂:
  EC(v) = {below_T₁, between_T₁_T₂, above_T₂}
  |EC(v)| = 3

For list of length L with max display N:
  EC(L) = {empty, partial(1..N-1), full(N), overflow(>N)}
  |EC(L)| = 4

For boolean:
  EC(b) = {true, false}
  |EC(b)| = 2

For trend:
  EC(trend) = {rising_fast, rising, stable, falling, falling_fast}
  |EC(trend)| = 5
```

Reduced state space for observability:
```
|S_obs_reduced| = 4 × 3³ × 5³ × 4 × 3 × 2⁵ × 2
                = 4 × 27 × 125 × 4 × 3 × 32 × 2
                = 4 × 27 × 125 × 4 × 3 × 64
                = 10,368,000

After removing infeasible combinations: ~50,000 reachable states
```

### 8.3 Minimum Test Suite Size (Lower Bound)

Using the **Chinese Postman Problem** on the transition graph:

```
For page p with transition graph G_p = (S_p_reduced, E_p):
  MinTests(p) ≥ |E_p| - |S_p_reduced| + 1  (Euler path formula)

For observability:
  MinTests(obs) ≥ 30 - 15 + 1 = 16 tests

For entire system:
  MinTests(all) ≥ Σ_p MinTests(p) + |CP| = ~450 + 8 = ~458 tests

With data flow:
  MinTests_DF(all) ≥ 458 + 67 = ~525 tests
```

---

## 9. System-Wide Dynamic Behavior Inventory

### 9.1 PubSub Channel Map (Directed Hypergraph)

```
PubSub Channel                 → Subscribing Pages
─────────────────────────────────────────────────────
prajna:metrics                 → {observability, alarms, health_sparkline}
prajna:traces                  → {observability}
prajna:alarms                  → {alarms}
prajna:mesh                    → {mesh}
prajna:logs                    → {diagnostics}
prajna:insights                → {copilot}
prajna:devices                 → {devices}
prajna:compliance              → {compliance}
prajna:video                   → {video}
prajna:analytics               → {analytics}
prajna:containers              → {containers}
prajna:cluster                 → {cluster}
prajna:access_control          → {access_control}
prajna:threats                 → {threat, sentinel_dashboard}
prajna:test_evolution          → {test_cockpit}
prajna:kms                     → {knowledge}
prajna:kms:developer           → {knowledge/developer}
prajna:kms:product             → {knowledge/product}
prajna:kms:sre                 → {knowledge/sre}
prajna:startup                 → {startup}
prajna:commands                → {commands}
prajna:guardian                → {guardian}
prajna:health                  → {health_sparkline}
guardian:proposals              → {guardian}
guardian:decisions              → {guardian}
sentinel:threats               → {threat, sentinel_dashboard}
zenoh:alarms                   → {alarms}
zenoh:compliance               → {compliance}
zenoh:devices                  → {devices}
zenoh:analytics                → {analytics}
zenoh:access_control           → {access_control}
zenoh:threats                  → {threat}
zenoh:video                    → {video}
zenoh:health                   → {health_sparkline}
git_intelligence               → {git_intelligence}
git_intelligence:health        → {git_intelligence}
git_intelligence:threat        → {git_intelligence}
topology:updates               → {topology}
```

**Fan-out analysis**: `prajna:metrics` has the highest fan-out (3 subscribers).
**Fan-in analysis**: `threat_live` has the highest fan-in (3 channels).

### 9.2 Timer Frequency Spectrum

```
Frequency   | Pages
──────────────────────────────────────────
500ms       | 23 pages (majority)
1000ms      | 1 page (prometheus)
2000ms      | 1 page (git_intelligence)
5000ms      | 1 page (guardian_dashboard)
10000ms     | 1 page (register)
None        | 3 pages (settings, shutdown, topology)
```

---

## 10. BDD Scenario Mapping to Graph Paths

### 10.1 Observability Page BDD Scenarios

```gherkin
# SECTION 1: Timer-Driven Metric Updates (Paths P1, P7, P8, P9, P10)
Feature: Observability Real-Time Metrics

  Scenario: KPI values update on timer tick [P1]
    Given I am on the observability page metrics tab
    When 500ms elapses
    Then request_rate value should change from initial
    And error_rate sparkline should shift left
    And P99 latency trend indicator should reflect history slope

  Scenario: Error rate threshold transition [P7]
    Given error_rate is 0.02 (normal)
    When error_rate rises above 0.5
    Then error_rate card color should be amber (caution)
    When error_rate rises above 1.0
    Then error_rate card color should be red (warning)
    And health_score should decrease by 20

  Scenario: Resource gauge threshold [P9]
    Given DB Pool Usage is at 23% (normal)
    When usage rises above 75%
    Then gauge color should be amber (caution)
    When usage rises above 90%
    Then gauge color should be red (warning)

  Scenario: Trend direction changes [P10]
    Given metric history shows stable values
    When recent values increase >20% vs older
    Then trend indicator should show ⬆ (rising_fast)

# SECTION 2: Trace Explorer (Paths P2, P3, P17)
Feature: Observability Trace Explorer

  Scenario: View trace list [P2]
    Given I am on the observability page
    When I click the "Traces" tab
    Then I should see up to 10 traces sorted by duration desc
    And each trace shows id, method, path, duration, span_count

  Scenario: Expand trace spans [P3]
    Given I am on the traces tab
    When I click on trace "trace-abc123"
    Then span waterfall should expand below the trace
    And slow spans should show ⚠ indicator

  Scenario: Trace rotation [P17]
    Given I am on the traces tab
    When 10 refresh ticks elapse (~5 seconds)
    Then a new BEAM-derived trace should appear
    And the oldest trace should be removed
    And traces should be re-sorted by duration

# SECTION 3: SigNoz Integration (Paths P5, P6)
Feature: Observability SigNoz Integration

  Scenario: OTEL module status [P6]
    Given I am on the SigNoz Integration tab
    Then each OTEL module shows active/inactive status
    And active modules show BEAM-derived metric values
    And OTLP endpoint shows connected/disconnected

  Scenario: SigNoz throughput updates [P5]
    Given I am on the SigNoz tab
    When 500ms elapses
    Then traces_per_min should change (derived from BEAM reductions)
    And metrics_per_min should change (derived from process count)

# SECTION 4: Navigation (Paths P4, P11, P12)
Feature: Observability Navigation

  Scenario: Navigate to diagnostics [P4]
    Given I am on the Logs tab
    When I click "GO TO DIAGNOSTICS"
    Then I should be on /cockpit/diagnostics

  Scenario: Open SigNoz [P11]
    When I click "OPEN SIGNOZ DASHBOARD"
    Then flash notification should show SigNoz URL

  Scenario: Export metrics [P12]
    When I click "EXPORT METRICS"
    Then flash notification should show export path with today's date

# SECTION 5: PubSub Events (Paths P13, P14)
Feature: Observability PubSub Integration

  Scenario: External metric update [P13]
    Given I am on the observability page
    When a {:metric_update, "cpu", 85.2} is broadcast on "prajna:metrics"
    Then metrics should be refreshed immediately

  Scenario: External trace added [P14]
    When a {:trace_added, %{...}} is broadcast on "prajna:traces"
    Then traces should be refreshed immediately

# SECTION 6: Header (Paths P15, P16)
Feature: Observability Header

  Scenario: Health score degradation [P15]
    Given health_score is 100
    When error_rate exceeds 1.0 and latency exceeds 100ms
    Then health_score should be max(0, 100 - 20 - 15) = 65
    And alarm_count should be 2

  Scenario: Node count tracking [P16]
    Given node_count starts at 1
    When Node.list() reports additional nodes
    Then header shows updated "Nodes: N/M"
    And total_nodes never decreases (high-water mark)
```

### 10.2 Test Count Summary

| Section | BDD Scenarios | Graph Paths | Assertions |
|---------|---------------|-------------|------------|
| Timer Metrics | 4 | P1,P7,P8,P9,P10 | 16 |
| Trace Explorer | 3 | P2,P3,P17 | 10 |
| SigNoz Integration | 2 | P5,P6 | 6 |
| Navigation | 3 | P4,P11,P12 | 4 |
| PubSub Events | 2 | P13,P14 | 3 |
| Header | 2 | P15,P16 | 4 |
| **Total** | **16** | **17** | **43** |

---

## 11. System-Wide Coverage Formula

### 11.1 Page Coverage Score

For each page p:

```
C(p) = α·C_node(p) + β·C_edge(p) + γ·C_path(p) + δ·C_data(p)

where α + β + γ + δ = 1.0
  α = 0.15  (node coverage weight)
  β = 0.30  (edge coverage weight)
  γ = 0.35  (prime path coverage weight)
  δ = 0.20  (data flow coverage weight)
```

### 11.2 System Coverage Score

```
C_system = Σ_p (w_p · C(p)) / Σ_p w_p

where w_p is the page weight (based on complexity and criticality):
  w_p = complexity_factor(p) × criticality_factor(p)

complexity_factor:
  VERY HIGH = 4 (alarms, settings)
  HIGH      = 3 (observability, diagnostics, copilot, shutdown, commands, guardian)
  MEDIUM    = 2 (mesh, containers, devices, compliance, video, analytics, cluster, access_control)
  LOW       = 1 (register, prometheus, topology, guardian_dashboard, sentinel_dashboard)

criticality_factor:
  SAFETY    = 3 (shutdown, commands, guardian, alarms)
  CORE      = 2 (observability, mesh, containers, diagnostics, health_sparkline)
  DOMAIN    = 1 (all others)
```

### 11.3 Total Test Paths Required

```
System-wide:
  Σ_p |PP(p)| + |CP| = Σ(17 + 25 + 12 + 20 + 15 + ...) + 8

Estimated total:
  ~847 prime paths across all 30 pages
  + 8 cross-page paths
  = 855 total test paths

Test execution time estimate:
  ExUnit LiveView tests: ~855 × 50ms avg = ~43 seconds
  Puppeteer browser tests: ~855 × 500ms avg = ~7.1 minutes
```

---

## 12. Algorithms for Automated Test Generation

### 12.1 BFS Path Enumeration

```elixir
defmodule PathEnumerator do
  @doc "Enumerate all prime paths up to length k in transition graph G"
  def prime_paths(graph, max_length \\ 10) do
    graph
    |> all_simple_paths(max_length)
    |> Enum.filter(&prime?/1)
    |> Enum.sort_by(&length/1, :desc)
  end

  defp prime?(path) do
    # A path is prime if it is not a proper sub-path of any other simple path
    # and has no repeated nodes (except possibly first == last for cycles)
    simple?(path) and maximal?(path)
  end
end
```

### 12.2 PageRank-Weighted Test Priority

```
Priority(test_t) = Σ_{p ∈ pages_covered(t)} PageRank(p) × criticality(p)

Top priority tests:
  1. Alarms threshold transitions (PageRank high, criticality=SAFETY)
  2. Guardian approval flow (criticality=SAFETY)
  3. Observability metric updates (PageRank high, criticality=CORE)
  4. Shutdown arm-and-fire sequence (criticality=SAFETY)
  5. Container restart/stop (criticality=CORE)
```

---

## 13. Verification Criteria

### 13.1 Minimum Acceptance

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| C_node | ≥ 1.00 | All reachable states visited |
| C_edge | ≥ 0.95 | 95%+ of transitions exercised |
| C_path | ≥ 0.90 | 90%+ of prime paths covered |
| C_data | ≥ 0.85 | 85%+ of def-use pairs covered |
| C_total | ≥ 0.95 | Weighted composite score |
| Cross-page | 8/8 | All inter-page paths tested |
| PubSub | 40/40 | All channels tested |
| Timers | 27/27 | All timer-driven pages tested |

### 13.2 SIL-6 Compliance

Per SC-COV-001 (critical paths 100%) and SC-COV-002 (overall ≥ 95%):
- All SAFETY-critical pages (shutdown, commands, guardian, alarms) require C(p) = 1.0
- All CORE pages require C(p) ≥ 0.95
- All DOMAIN pages require C(p) ≥ 0.90

---

## 14. Decision Log

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Use LTS model over FSM | LTS supports infinite state spaces with labeling |
| D2 | Equivalence partitioning for reduction | Reduces ∞ state space to ~50K testable states |
| D3 | Prime path coverage as primary criterion | Stronger than edge coverage, practical vs all-paths |
| D4 | Weight safety pages 3× | Aligns with SC-SAFETY Arm & Fire requirements |
| D5 | 500ms timer as base observation window | Matches @refresh_interval across 23/30 pages |
| D6 | BFS for path enumeration | Guarantees shortest paths found first |
| D7 | Chinese Postman for lower bound | Provides minimum test count guarantee |

---

## 15. Retrospective

### What Went Well
- Complete inventory of all 30 dynamic pages with quantified complexity
- Mathematical model provides formal coverage guarantees
- Graph theory (adjacency matrix, SCCs, PageRank) maps naturally to LiveView navigation
- Equivalence partitioning reduces infinite state to tractable test space

### What Could Improve
- Need automated tool to extract state machines from LiveView code
- PubSub integration tests require test harness for broadcast injection
- Browser-level tests (Puppeteer) needed for visual verification of sparklines/gauges

### Lessons Learned
- LiveView pages are naturally modeled as LTS with timer + event + PubSub alphabet
- The nav bar creates a complete SCC, simplifying navigation coverage
- Threshold transitions are the most important dynamic behavior to test (3-state alarm model)

### Open Questions
- Should we model LiveView reconnection/disconnection as transitions?
- How to test sparkline visual correctness (Unicode block char rendering)?
- Integration with anthropics/skills webapp-testing for browser-level assertions?

---

## 16. STAMP Constraints Referenced

- SC-HMI-011: 8×8 Matrix 100% path coverage
- SC-COV-001: Static coverage ≥ 100% for critical paths
- SC-COV-002: Runtime coverage ≥ 95% overall
- SC-COV-004: BDD specs for all user journeys
- SC-COV-007: All 5 levels MUST pass before merge
- SC-CV-001: TDG coverage framework compliance
- SC-HMI-001: Dark Cockpit defaults
- SC-PRF-050: Updates < 50ms latency
- SC-OBS-069: Dual logging (Terminal + SigNoz)
