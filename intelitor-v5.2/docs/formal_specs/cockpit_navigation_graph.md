# Cockpit Navigation Directed Graph — Mathematical Model

**Date**: 20260328-0030 CEST
**Author**: Claude Opus 4.6
**STAMP**: SC-HMI-011 (8x8 Matrix), SC-PORTAL-001, SC-PORTAL-002
**Version**: v1.0.0

---

## 1. Graph Definition

The Prajna Cockpit is modeled as a directed graph $G = (V, E)$ where:

- $V$ = set of vertices (pages/states)
- $E \subseteq V \times V$ = set of directed edges (navigation links)
- $w: E \to \{nav, tab, link, action\}$ = edge type function

### 1.1 Vertex Set $V$ (28 cockpit routes + intra-page states)

#### Level 0: Entry Points
```
v₀  = /cockpit                    (Overview/PrajnaLive)
```

#### Level 1: Primary Navigation (prajna_nav — 9 items)
```
v₁  = /cockpit/mesh               (MeshLive)
v₂  = /cockpit/alarms             (AlarmsLive)
v₃  = /cockpit/commands           (CommandsLive)
v₄  = /cockpit/ai-copilot         (CopilotLive)
v₅  = /cockpit/containers         (ContainersLive)
v₆  = /cockpit/cluster            (ClusterLive)
v₇  = /cockpit/observability      (ObservabilityLive)
v₈  = /cockpit/settings           (SettingsLive)
```

#### Level 2: Secondary Pages (sidebar/portal navigation)
```
v₉  = /cockpit/startup            (StartupLive)
v₁₀ = /cockpit/shutdown           (ShutdownLive)
v₁₁ = /cockpit/diagnostics        (DiagnosticsLive)
v₁₂ = /cockpit/test-evolution     (TestCockpitLive)
v₁₃ = /cockpit/knowledge          (KnowledgeLive)
v₁₄ = /cockpit/knowledge/developer (DeveloperLive)
v₁₅ = /cockpit/knowledge/product  (ProductLive)
v₁₆ = /cockpit/knowledge/sre      (SRELive)
v₁₇ = /cockpit/sentinel           (SentinelDashboardLive)
v₁₈ = /cockpit/guardian           (GuardianDashboardLive)
v₁₉ = /cockpit/register           (RegisterLive)
v₂₀ = /cockpit/threat             (ThreatLive)
v₂₁ = /cockpit/health-sparklines  (HealthSparklineLive)
v₂₂ = /cockpit/guardian-approval  (GuardianLive)
v₂₃ = /cockpit/git-intelligence   (GitIntelligenceLive)
v₂₄ = /cockpit/access-control     (AccessControlLive)
v₂₅ = /cockpit/devices            (DevicesLive)
v₂₆ = /cockpit/video              (VideoLive)
v₂₇ = /cockpit/analytics          (AnalyticsLive)
v₂₈ = /cockpit/compliance         (ComplianceLive)
v₂₉ = /cockpit/dashboard          (PrajnaLive :dashboard)
```

#### Level 3: Intra-Page States (Observability page)
```
v₇ₐ = observability:metrics       (Metrics tab - default)
v₇ᵦ = observability:traces        (Traces tab)
v₇꜀ = observability:logs          (Logs tab)
v₇ᵈ = observability:signoz        (SigNoz tab)
v₇ₑ = observability:trace_detail  (Trace expanded)
```

$|V| = 30$ pages + $5$ intra-page states = $35$ vertices total

### 1.2 Edge Set $E$

#### Navigation Edges (prajna_nav component — bidirectional mesh)
The prajna_nav creates a **complete subgraph** $K_9$ among the 9 primary pages:

```
E_nav = {(vᵢ, vⱼ) | vᵢ, vⱼ ∈ {v₀..v₈}, i ≠ j}
|E_nav| = 9 × 8 = 72 directed edges
```

#### Cross-Page Link Edges
```
(v₇꜀, v₁₁)    observability:logs → diagnostics    [link: "GO TO DIAGNOSTICS"]
(v₁₃, v₁₄)    knowledge → knowledge/developer     [link: sub-navigation]
(v₁₃, v₁₅)    knowledge → knowledge/product       [link: sub-navigation]
(v₁₃, v₁₆)    knowledge → knowledge/sre           [link: sub-navigation]
```

#### Intra-Page Tab Edges (Observability)
```
(v₇ₐ, v₇ᵦ)    metrics → traces                    [tab: switch_tab]
(v₇ₐ, v₇꜀)    metrics → logs                      [tab: switch_tab]
(v₇ₐ, v₇ᵈ)    metrics → signoz                    [tab: switch_tab]
(v₇ᵦ, v₇ₐ)    traces → metrics                    [tab: switch_tab]
(v₇ᵦ, v₇꜀)    traces → logs                       [tab: switch_tab]
(v₇ᵦ, v₇ᵈ)    traces → signoz                     [tab: switch_tab]
(v₇꜀, v₇ₐ)    logs → metrics                      [tab: switch_tab]
(v₇꜀, v₇ᵦ)    logs → traces                       [tab: switch_tab]
(v₇꜀, v₇ᵈ)    logs → signoz                       [tab: switch_tab]
(v₇ᵈ, v₇ₐ)    signoz → metrics                    [tab: switch_tab]
(v₇ᵈ, v₇ᵦ)    signoz → traces                     [tab: switch_tab]
(v₇ᵈ, v₇꜀)    signoz → logs                       [tab: switch_tab]
```

Tab edges form $K_4$ (complete graph on 4 tab states): $|E_{tab}| = 12$

#### Trace Detail Edges
```
(v₇ᵦ, v₇ₑ)    traces → trace_detail               [action: view_trace]
(v₇ₑ, v₇ᵦ)    trace_detail → traces               [action: view_trace (toggle)]
```

### 1.3 Total Edge Count

```
|E| = |E_nav| + |E_cross| + |E_tab| + |E_trace|
    = 72 + 4 + 12 + 2
    = 90 directed edges
```

---

## 2. Adjacency Matrix $A$ (Primary Navigation Subgraph)

For the 9 primary nav pages $\{v₀, v₁, ..., v₈\}$:

```
     v₀ v₁ v₂ v₃ v₄ v₅ v₆ v₇ v₈
v₀ [ 0  1  1  1  1  1  1  1  1 ]
v₁ [ 1  0  1  1  1  1  1  1  1 ]
v₂ [ 1  1  0  1  1  1  1  1  1 ]
v₃ [ 1  1  1  0  1  1  1  1  1 ]
v₄ [ 1  1  1  1  0  1  1  1  1 ]
v₅ [ 1  1  1  1  1  0  1  1  1 ]
v₆ [ 1  1  1  1  1  1  0  1  1 ]
v₇ [ 1  1  1  1  1  1  1  0  1 ]
v₈ [ 1  1  1  1  1  1  1  1  0 ]

A = J₉ - I₉  (all-ones matrix minus identity)
```

**Properties**:
- **Strongly connected**: Yes ($K_9$ is trivially strongly connected)
- **Diameter**: 1 (any page reachable from any other in 1 hop)
- **Out-degree**: $\delta^+(v) = 8$ for all primary nav pages
- **In-degree**: $\delta^-(v) = 8$ for all primary nav pages

### 2.1 Adjacency Matrix (Observability Intra-Page Tab States)

```
        metrics  traces  logs  signoz  detail
metrics [  0       1      1      1       0   ]
traces  [  1       0      1      1       1   ]
logs    [  1       1      0      1       0   ]
signoz  [  1       1      1      0       0   ]
detail  [  0       1      0      0       0   ]
```

**Properties**:
- Tab subgraph $K_4$ (metrics, traces, logs, signoz) is strongly connected
- `detail` is only reachable from `traces` and only returns to `traces`
- `detail` is a **pendant vertex** (degree 1 in the undirected version)

---

## 3. Graph-Theoretic Analysis

### 3.1 Strongly Connected Components (SCC)

Using Tarjan's algorithm on the full graph:

```
SCC₁ = {v₀, v₁, v₂, v₃, v₄, v₅, v₆, v₇, v₈}     (primary nav — K₉)
SCC₂ = {v₇ₐ, v₇ᵦ, v₇꜀, v₇ᵈ}                        (observability tabs — K₄)
SCC₃ = {v₇ₑ}                                          (trace detail — singleton)
SCC₄ = {v₉}  ... {v₂₉}                               (secondary pages — singletons
                                                        unless they have prajna_nav)
```

Pages WITH prajna_nav component: v₀-v₈ (primary), plus some secondary pages
that import PrajnaComponents and render prajna_nav.

Pages WITHOUT prajna_nav: Accessed only from navigation portal or direct URL.

### 3.2 Bow-Tie Structure

```
         ┌─────────────────────────────────────────┐
         │                                          │
    IN   │              SCC (Core)                  │   OUT
  ┌────┐ │  ┌────────────────────────────────────┐ │ ┌────┐
  │Nav │→│  │  K₉ = {Overview, Mesh, Alarms,     │ │→│    │
  │Port│ │  │   Commands, Copilot, Containers,   │ │ │ -  │
  │ al │ │  │   Cluster, Observability, Settings} │ │ │    │
  └────┘ │  └────────────────────────────────────┘ │ └────┘
         │                                          │
         │    ↕ prajna_nav links (K₉ complete)     │
         │                                          │
         └─────────────────────────────────────────┘
              │
              ▼ (cross-page links from nav portal)
         ┌─────────────────────────────────────────┐
         │  TENDRILS (secondary pages)              │
         │  v₉-v₂₉: sentinel, guardian, register,  │
         │  threat, health-sparklines, etc.         │
         │  (reachable from portal, some have       │
         │   prajna_nav making them part of SCC)    │
         └─────────────────────────────────────────┘
```

### 3.3 Reachability Matrix $R$

$R = (A + I)^{|V|} > 0$ (Boolean closure)

For primary nav pages: $R[i][j] = 1$ for all $i, j \in \{0..8\}$
For secondary pages: $R[i][j] = 1$ iff page $j$ has a navigation link from page $i$

### 3.4 PageRank Analysis

In $K_9$, all pages have equal PageRank: $PR(v_i) = 1/9 \approx 0.111$

This is expected — the prajna_nav creates a uniform mesh where no page has structural advantage.

### 3.5 Path Coverage for Testing

**Minimum paths to cover all edges** (Chinese Postman Problem on directed $K_9$):

For $K_9$: Every vertex has equal in/out-degree = 8.
The graph is Eulerian (balanced in/out degrees).
An Eulerian circuit exists and covers all 72 edges in exactly 72 steps.

**Example Eulerian circuit** (one of many):
```
v₀→v₁→v₂→v₃→v₄→v₅→v₆→v₇→v₈→v₀→v₂→v₁→v₃→v₂→v₄→v₃→v₅→v₄→v₆→v₅→v₇→v₆→v₈→v₇→...
```

**For tab testing** ($K_4$ on observability):
Eulerian circuit on 4 tabs = 12 transitions:
```
metrics→traces→logs→signoz→metrics→logs→traces→signoz→traces→metrics→signoz→logs→metrics
```

---

## 4. Observability Page Data Flow Graph (DAG)

### 4.1 Data Sources (BEAM Intrinsics)

```
                    ┌─── :erlang.memory(:total) ──────────────────┐
                    │                                              │
                    ├─── :erlang.system_info(:process_count) ─────┤
                    │                                              │
    BEAM Runtime ───┼─── :erlang.system_info(:schedulers_online) ─┼──→ update_metrics()
                    │                                              │      │
                    ├─── :erlang.statistics(:run_queue) ──────────┤      ├→ request_rate
                    │                                              │      ├→ error_rate
                    ├─── :erlang.ports() ─────────────────────────┤      ├→ p99_latency
                    │                                              │      ├→ active_connections
                    ├─── :erlang.statistics(:reductions) ─────────┤      ├→ db_pool_used
                    │                                              │      ├→ flame_utilization
                    ├─── :erlang.statistics(:wall_clock) ─────────┘      └→ *_history (6 lists)
                    │
                    ├─── Code.ensure_loaded?/1 ──────→ update_otel_status()
                    │                                      │
                    ├─── Application.started_applications() ┤  ├→ modules[].active
                    │                                      │  ├→ modules[].metric_value
                    └─── Node.list/0 ──────────────────────┘  └→ connected
```

### 4.2 Derived Value Graph

```
metrics.request_rate ─┐
metrics.error_rate ───┼──→ calculate_health_score() ──→ prajna_header.health_score
metrics.p99_latency ──┘
                      ├──→ count_alarms() ────────────→ prajna_header.alarm_count

metrics.*_history ────────→ calculate_trend() ─────────→ trend_indicator component
                            │
                            └→ {:rising_fast, :rising, :stable, :falling, :falling_fast}

metrics.value ────────────→ threshold_check() ─────────→ alarm_level
                            │
                            └→ {:normal, :caution, :warning}

alarm_level ──────────────→ kpi_value_class() ─────────→ CSS class (color)
                          →  sparkline_class() ────────→ sparkline color
```

### 4.3 Timer-Driven Update Cycle (500ms)

```
:timer ──(500ms)──→ :refresh message
                        │
                        ├→ update_metrics(socket)      [BEAM intrinsics → metrics map]
                        ├→ update_traces(socket)       [jitter existing + generate new every 5s]
                        ├→ update_otel_status(socket)  [Code.ensure_loaded? checks]
                        ├→ update_signoz_status(socket)[derived from OTEL module count]
                        └→ update_node_count(socket)   [Node.list/0]
                              │
                              └→ LiveView diff pushed to client via WebSocket
```

---

## 5. State Space Analysis

### 5.1 Observability Page State Vector

```
S = (active_tab, selected_trace, metrics, traces, otel_status, signoz_status,
     node_count, total_nodes, trace_tick)
```

**State space cardinality**:
- `active_tab`: 4 values
- `selected_trace`: |traces| + 1 (nil or one of N traces)
- `metrics`: continuous (6 real-valued fields + 6 bounded-length lists)
- `traces`: ordered list of up to 10 trace maps
- `otel_status.connected`: 2 values
- `otel_status.modules[i].active`: $2^4 = 16$ combinations
- `signoz_status.healthy`: 2 values
- `node_count`: N (positive integer)
- `trace_tick`: unbounded counter

**Finite abstract state space** (for model checking):
```
|S_abstract| = 4 × 11 × 16 × 2 × 2 = 2,816 abstract states
```

### 5.2 Invariants

```
INV-1: active_tab ∈ {:metrics, :traces, :logs, :signoz}
INV-2: 0 ≤ metrics.error_rate
INV-3: 0 ≤ metrics.p99_latency
INV-4: length(metrics.*_history) ≤ sparkline_length (= 30)
INV-5: length(traces) ≤ 10
INV-6: node_count ≤ total_nodes
INV-7: trace_tick monotonically increasing
INV-8: health_score ∈ [0, 100]
INV-9: alarm_level ∈ {:normal, :caution, :warning}
INV-10: selected_trace = nil ∨ selected_trace ∈ traces
```

### 5.3 Temporal Properties (CTL)

```
AG(active_tab ∈ {metrics, traces, logs, signoz})     -- always valid tab
AG(EF(metrics updated))                               -- metrics always eventually update
AG(error_rate > 1.0 → alarm_level = warning)          -- threshold always enforced
AG(trace_tick' = trace_tick + 1)                       -- tick always increments
AF(length(traces) > 0)                                -- traces eventually appear
AG(selected_trace ≠ nil → active_tab = traces)        -- detail only on traces tab
```

---

## 6. Test Path Coverage Matrix (8×8 Fractal)

Per SC-HMI-011, applying the 8 Elements × 8 Layers matrix to the Observability page:

### 8 Elements
```
E₁ = Tab Navigation       (switch_tab event)
E₂ = KPI Cards            (request_rate, error_rate, p99_latency)
E₃ = Resource Cards       (connections, db_pool, flame)
E₄ = Sparklines           (6 history visualizations)
E₅ = Trace Explorer       (view_trace, span expansion)
E₆ = OTEL Status          (4 module checks + endpoint)
E₇ = SigNoz Panel         (health, traces/min, metrics/min)
E₈ = Action Buttons       (open_signoz, export_metrics)
```

### 8 Layers
```
L₁ = Data Source           (BEAM intrinsic that feeds the element)
L₂ = Computation           (derived/computed value)
L₃ = State Update          (socket assign mutation)
L₄ = Diff Generation       (LiveView change tracking)
L₅ = DOM Rendering         (HEEx template output)
L₆ = Visual Feedback       (color, class, trend indicator)
L₇ = User Interaction      (click, hover, navigation)
L₈ = Side Effect           (flash, PubSub, external action)
```

### Coverage Matrix (✓ = path exists, ○ = N/A)

```
        L₁    L₂    L₃    L₄    L₅    L₆    L₇    L₈
E₁ Tab  ○     ○     ✓     ✓     ✓     ✓     ✓     ○     5/8
E₂ KPI  ✓     ✓     ✓     ✓     ✓     ✓     ○     ○     6/8
E₃ Res  ✓     ✓     ✓     ✓     ✓     ✓     ○     ○     6/8
E₄ Spk  ✓     ✓     ✓     ✓     ✓     ✓     ○     ○     6/8
E₅ Trc  ✓     ✓     ✓     ✓     ✓     ✓     ✓     ○     7/8
E₆ OTEL ✓     ✓     ✓     ✓     ✓     ✓     ○     ○     6/8
E₇ Sig  ✓     ✓     ✓     ✓     ✓     ✓     ○     ○     6/8
E₈ Act  ○     ○     ○     ○     ✓     ○     ✓     ✓     3/8

Total: 45/64 = 70.3% path coverage
```

**Missing paths** (improvement opportunities):
- E₁ Tab: No data source (tabs are static) — acceptable
- E₂/E₃ KPI/Resource: No user interaction beyond viewing — could add click-to-detail
- E₈ Actions: Minimal data flow — flash messages only, no persistent state change

---

## 7. Minimum Test Suite for Full Edge Coverage

### 7.1 Navigation Edge Coverage (72 edges)

An Eulerian circuit on $K_9$ covers all 72 nav edges in a single path.
Practical test: visit each page from every other page = 72 navigation assertions.

### 7.2 Tab Edge Coverage (12 edges)

Eulerian circuit on $K_4$: 12 tab switches.
```
Test sequence: metrics→traces→logs→signoz→metrics→logs→traces→signoz→traces→metrics→signoz→logs→metrics
```

### 7.3 Data Flow Coverage (45 paths)

Each path in the 8×8 matrix requires a test that verifies:
1. Source data is read correctly
2. Computation produces expected output
3. State is updated
4. LiveView diff is generated
5. DOM reflects the state
6. Visual feedback matches alarm/trend level
7. User interaction triggers correct event
8. Side effects execute correctly

### 7.4 Threshold Boundary Tests

```
error_rate:  {0.0, 0.49, 0.50, 0.51, 0.99, 1.00, 1.01}  — 7 boundary values
p99_latency: {0, 49, 50, 51, 99, 100, 101}                — 7 boundary values
resource %:  {0, 74, 75, 76, 89, 90, 91, 100}             — 8 boundary values
```

Total boundary tests: 7 + 7 + 8 = 22 tests

### 7.5 Total Minimum Test Count

```
Navigation:  72  (edge coverage)
Tabs:        12  (edge coverage)
Data paths:  45  (8×8 matrix)
Boundaries:  22  (threshold values)
Invariants:  10  (from §5.2)
Temporal:     6  (from §5.3)
Edge cases:   4  (empty traces, all OTEL inactive, cluster change, zero ports)
───────────────
Total:      171  minimum tests for full coverage
```

---

## 8. Related STAMP Constraints

| ID | Constraint | Coverage |
|----|------------|----------|
| SC-HMI-001 | Dark Cockpit defaults | L₆ (visual feedback layer) |
| SC-HMI-008 | 4.5:1 contrast ratio | L₅ (DOM rendering layer) |
| SC-HMI-011 | 8×8 matrix coverage | Full matrix (§6) |
| SC-OBS-069 | Dual logging (Term+SigNoz) | E₆, E₇ (OTEL/SigNoz elements) |
| SC-OBS-071 | 4 OTEL modules active | E₆ L₁ (data source check) |
| SC-TEL-003 | Sparklines for metrics | E₄ (sparkline element) |
| SC-PRF-050 | Updates < 50ms latency | L₄ (diff generation timing) |
| SC-PORTAL-001 | All routes linked | Navigation graph completeness |
| SC-PORTAL-002 | All routes return 200 | Reachability verification |

---

## 9. Algorithms Applied

1. **Tarjan's SCC** — identify strongly connected components in navigation graph
2. **Hierholzer's algorithm** — find Eulerian circuit for minimum edge coverage test path
3. **PageRank** — verify no page has disproportionate structural importance
4. **BFS/DFS crawl** — build adjacency matrix from router.ex + component templates
5. **Chinese Postman** — minimum cost traversal covering all edges
6. **Boundary Value Analysis** — systematic threshold testing
7. **CTL model checking** — temporal property verification (via Quint spec)
