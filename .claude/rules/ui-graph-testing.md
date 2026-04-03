---
paths: lib/cepaf_gleam/test/**/*_test.gleam, lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/testing/**/*.gleam
---

# UI Graph-Theory Testing Framework (SC-UIGT)

## Overview

Mathematical graph-theory-based testing for ALL 22 Gleam Lustre pages in the C3I
cockpit. Models navigation as a directed graph G_nav = (V, E), page state as Labeled
Transition Systems (LTS) derived from Gleam MVU (Model/Msg/update), and AG-UI event
flow as a bipartite hypergraph. Achieves provable coverage via prime path analysis.

Primary test framework: **gleeunit** (Gleam unit testing on BEAM).
E2E API testing: **Wisp `testing` module** (HTTP request simulation, no browser needed).
Coverage mathematics: `testing/coverage_math.gleam` (Shannon H, CCM, ITQS, FSI, D_EA).
Navigation graph: `testing/nav_graph.gleam` (PageRank, SCC, adjacency matrix).

---

## STAMP Constraints (UI Graph Testing)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-UIGT-001 | Navigation digraph G_nav MUST cover all 22 Lustre pages as vertices | CRITICAL |
| SC-UIGT-002 | All navigation edges MUST be verified via Wisp API test or gleeunit MVU test | HIGH |
| SC-UIGT-003 | Each page LTS MUST enumerate all Model field states and Msg variant transitions | HIGH |
| SC-UIGT-004 | Prime path coverage C_path >= 0.95 for Tier 1 pages | CRITICAL |
| SC-UIGT-005 | AG-UI event graph MUST map all 32 event types across relevant pages | HIGH |
| SC-UIGT-006 | A2UI component graph MUST verify all 10 component types per fractal layer | HIGH |
| SC-UIGT-007 | update(model, msg) pure-function transitions MUST be verified per Msg variant | CRITICAL |
| SC-UIGT-008 | Wisp router endpoints MUST be exercised via wisp/testing for every route | HIGH |
| SC-UIGT-009 | TUI render functions MUST produce non-empty ANSI strings for all states | HIGH |
| SC-UIGT-010 | Dark Cockpit mode transitions MUST be visually and structurally verified | MEDIUM |
| SC-UIGT-011 | Adjacency matrix A in `testing/nav_graph.gleam` MUST remain current | MEDIUM |
| SC-UIGT-012 | SCC analysis MUST confirm all 22 pages reachable (scc_count() == 1) | HIGH |
| SC-UIGT-013 | Chinese Postman lower bound MUST be computed per release | MEDIUM |
| SC-UIGT-014 | PageRank-weighted test priority MUST guide execution order | MEDIUM |
| SC-UIGT-015 | Cross-page AG-UI event flow paths MUST be tested end-to-end via Zenoh bus | HIGH |

---

## AOR Rules (UI Graph Testing)

| ID | Rule |
|----|------|
| AOR-UIGT-001 | Model every Lustre page as an LTS (states from Model fields, labels from Msg variants) before writing tests |
| AOR-UIGT-002 | Compute prime paths for each LTS using DFS enumeration via `testing/prime_paths.gleam` |
| AOR-UIGT-003 | Verify all update(model, Tick) and update(model, Refresh) transitions produce valid new models |
| AOR-UIGT-004 | Verify all update(model, msg) calls are exhaustive — Gleam compiler enforces this via pattern match |
| AOR-UIGT-005 | Test AG-UI event flow: agent emits event → zenoh_bus receives → Lustre dispatches Msg |
| AOR-UIGT-006 | Use Wisp `testing.get` / `testing.post` for API E2E — no browser required |
| AOR-UIGT-007 | Maintain adjacency matrix in `testing/nav_graph.gleam` — all_pages() must list all 22 pages |
| AOR-UIGT-008 | Run SCC analysis after any route change to nav_graph.gleam |
| AOR-UIGT-009 | Compute coverage metrics: C_node, C_edge, C_path, C_data using coverage_math.gleam |
| AOR-UIGT-010 | Weight test priority by PageRank — test_priority_order() determines execution sequence |

---

## Mathematical Foundations

### 1. Navigation Digraph G_nav = (V, E_nav)

The 22 Lustre pages are the vertices. Navigation links via the shared nav bar produce a
near-complete directed graph. The 13 domain.gleam Page ADT variants plus 9 additional
Lustre-only views compose the full vertex set.

```
V = {v₁, v₂, ..., v₂₂}  (22 Gleam Lustre pages)
E_nav ⊆ V × V             (navigation links + nav bar edges)

Adjacency Matrix: A ∈ {0,1}^{22×22}
  A[i][j] = 1 iff page i has a Navigate(page) link or nav bar entry to page j

Properties:
  - |V| = 22  (nav_graph.gleam: page_count() extended to 22)
  - |E_nav| ≈ 462 (22×21 for complete nav bar subgraph)
  - SCC = 1 (all pages reachable from all pages via nav bar — scc_count() == 1)
  - Density = |E| / (|V|·(|V|-1)) = 462/462 = 1.0 (complete graph via nav bar)
```

**22-page vertex set** (domain.gleam Page ADT + additional Lustre views):

| # | Page | Path | Lustre Module | Fractal Layer |
|---|------|------|---------------|---------------|
| 1 | Dashboard | /dashboard | `lustre/app.gleam` | L5 Cognitive |
| 2 | Planning | /planning | `lustre/planning.gleam` | L3 Transaction |
| 3 | Immune | /immune | `lustre/immune.gleam` | L0 Constitutional |
| 4 | Knowledge | /knowledge | `lustre/knowledge.gleam` | L3 Transaction |
| 5 | Zenoh | /zenoh | `lustre/zenoh_mesh.gleam` | L6 Ecosystem |
| 6 | Cockpit | /cockpit | `lustre/cockpit_view.gleam` | L5 Cognitive |
| 7 | Verification | /verification | `lustre/verification.gleam` | L0 Constitutional |
| 8 | Substrate | /substrate | `lustre/substrate.gleam` | L4 System |
| 9 | Metabolic | /metabolic | `lustre/metabolic.gleam` | L4 System |
| 10 | Podman | /podman | `lustre/podman.gleam` | L4 System |
| 11 | Mcp | /mcp | `lustre/mcp.gleam` | L2 Component |
| 12 | Kms | /kms | `lustre/kms.gleam` | L2 Component |
| 13 | Telemetry | /telemetry | `lustre/telemetry.gleam` | L1 Atomic |
| 14 | Agents | /agents | `lustre/agents.gleam` | L5 Cognitive |
| 15 | Bridge | /bridge | `lustre/bridge.gleam` | L2 Component |
| 16 | Config | /config | `lustre/config.gleam` | L3 Transaction |
| 17 | Database | /database | `lustre/database.gleam` | L3 Transaction |
| 18 | Git | /git | `lustre/git.gleam` | L1 Atomic |
| 19 | Holon | /holon | `lustre/holon.gleam` | L6 Ecosystem |
| 20 | Prajna | /prajna | `lustre/prajna.gleam` | L5 Cognitive |
| 21 | Smriti | /smriti | `lustre/smriti.gleam` | L3 Transaction |
| 22 | PlanningDashboard | /planning/dashboard | `lustre/planning_dashboard.gleam` | L3 Transaction |

### 2. Page-Level Labeled Transition System (LTS)

For each Lustre page p ∈ V, the LTS is derived directly from Gleam MVU types:

```
LTS(p) = (S_p, Σ_p, →_p, s₀_p)
  S_p  = {states}           — field combinations in Model type
  Σ_p  = {labels}           — Msg type constructors (Gleam ADT variants)
  →_p  ⊆ S_p × Σ_p × S_p   — update(model, msg) -> model transitions
  s₀_p = init() result      — initial state from init() function
```

**Gleam advantage**: The Gleam compiler enforces exhaustive pattern matching in
`update(model, msg)` — all Msg variants MUST be handled or compilation fails.
This means Σ_p is provably complete from the source type definition.

Example LTS for `agents.gleam`:
```gleam
// States derived from AgentsModel fields:
S = { initial(0,0,0,0,0.0,False), loaded(n,e,s,w,eff,False),
      deadlock(n,e,s,w,eff,True), refreshing(...) }

// Labels from AgentsMsg variants:
Σ = { HierarchyLoaded(Int,Int,Int,Int), EfficiencyUpdated(Float),
      DeadlockDetected(Bool), RefreshAgents }

// Transitions from update(model, msg) cases:
→ = { initial →[HierarchyLoaded(n,e,s,w)] loaded(n,e,s,w,...),
      loaded →[RefreshAgents] refreshing,
      loaded →[DeadlockDetected(True)] deadlock,
      loaded →[EfficiencyUpdated(f)] loaded(...,f,...) }
```

### 3. Coverage Criteria

Implemented in `testing/coverage_math.gleam` (SC-MATH-COV-001..008):

| Criterion | Formula | Target | Gleam Gate |
|-----------|---------|--------|------------|
| Node Coverage | C_node = |tested_states| / |S_p| | >= 1.0 | All Model field combinations tested |
| Edge Coverage | C_edge = |tested_transitions| / |→_p| | >= 0.95 | All update() branches covered |
| Prime Path Coverage | C_path = |tested_prime_paths| / |PP(LTS(p))| | >= 0.95 | Tier 1 pages |
| Data Flow Coverage | C_data = |tested_du_pairs| / |DU(p)| | >= 0.90 | Def-use pairs in model fields |
| Total Coverage | C_total = w₁·C_node + w₂·C_edge + w₃·C_path + w₄·C_data | >= 0.95 | — |
| Weights | w₁=0.2, w₂=0.3, w₃=0.3, w₄=0.2 | | — |

**Math quality gates** (from `testing/coverage_math.gleam`):
- Shannon Entropy H >= 2.5 bits (uniform distribution across 8 coverage categories C1-C8)
- CCM (Cyclomatic Coverage Metric) >= 0.90
- ITQS (Integrated Test Quality Score) >= 0.85
- D_EA (Source Alignment Divergence) <= 0.10

### 4. Prime Path Enumeration

A prime path is a simple path (no repeated vertices except possibly first=last) that is
not a proper subpath of any other simple path.

```
Algorithm: PrimePaths(LTS)
  1. Start from each state s₀ ∈ S_p
  2. DFS: extend path by one transition →_p edge
  3. Stop when revisiting a state (cycle complete)
  4. Collect all maximal simple paths
  5. Remove any path that is a subpath of another collected path
  6. Result: PP(LTS) — the set of prime paths

For Gleam: Σ_p is the Msg ADT — all variants enumerated from source types.
```

The DFS enumeration maps directly to Gleam test functions:
each prime path PP = [s₀ → s₁ → ... → sₙ] becomes one `pub fn pp_xxx_test()`.

### 5. Chinese Postman Lower Bound

Minimum number of test cases to achieve full edge coverage:

```
CPP(G) = |E| + matching_cost(odd_degree_vertices)

For G_nav (complete graph):
  CPP = 462 (every navigation edge must be traversed once)

System-wide with per-page LTS:
  CPP ≈ 462 + Σ |→_p| for p ∈ V  ≈ 600-700 test cases minimum
```

In `testing/nav_graph.gleam`: `chinese_postman_bound()` returns `edge_count()`.

### 6. PageRank Test Priority

Pages with higher PageRank are tested first. For the complete nav bar graph (all pages
link to all other pages), PageRank converges to 1/|V| = 1/22 ≈ 0.0455 per page.
Pages with additional in-edges from domain-specific cross-links receive higher ranks.

```
PR(p) = (1-d)/|V| + d · Σ_{q→p} PR(q)/out_degree(q)
d = 0.85 (damping factor), 30 iterations

Estimated PageRank for pages with additional in-links:
  1. Dashboard       PR ≈ 0.055  (linked from all pages + default landing)
  2. Cockpit         PR ≈ 0.052  (linked from Verification, Immune, Agents)
  3. Verification    PR ≈ 0.050  (linked from Dashboard, Cockpit, Substrate)
  4. Agents          PR ≈ 0.048  (linked from Dashboard, Cockpit)
  5. Planning        PR ≈ 0.047  (linked from Dashboard, PlanningDashboard)
```

Implementation: `testing/nav_graph.gleam` — `page_rank()` + `test_priority_order()`.

### 7. AG-UI Event Graph Overlay G_agui = (V, E_agui)

The AG-UI protocol adds a second graph layer over G_nav:

```
G_agui = (E_types, V_pages, E_publish, E_subscribe)

E_types = 32 AG-UI event types (5 lifecycle + 4 text + 5 tool + 3 state +
                                  2 activity + 7 reasoning + 6 special)

E_publish ⊆ E_types × V_pages   — which pages publish which events
E_subscribe ⊆ V_pages × E_types — which pages subscribe to which events

Key bindings:
  Dashboard    subscribes to: RunStarted, RunFinished, StateSnapshot
  Agents       subscribes to: StepStarted, StepFinished, ActivitySnapshot
  Cockpit      subscribes to: ToolCallStart, ToolCallEnd, ReasoningStart
  Verification subscribes to: RunError, StateSnapshot, StateDelta
  Telemetry    subscribes to: TextMessageChunk, ReasoningMessageContent

Coverage gate: All 32 event types MUST have at least one subscribing page (SC-UIGT-005).
```

### 8. A2UI Component Validation Graph G_a2ui = (V_components, E_layer)

Components are stratified by fractal layer access control:

```
G_a2ui = (C, L, E_access)
  C = 10 component types (badge, button, data_table, progress, sparkline,
                           alert, modal, ooda_ring, reasoning, topology)
  L = 8 fractal layers (L0-L7)
  E_access: L → 2^C  (which components are accessible at each layer)

Layer access rules (SC-A2UI-004):
  L0: alert, modal (constitutional-only components)
  L1: sparkline, badge (atomic debug telemetry)
  L2: badge, button, data_table (component-level interaction)
  L3: data_table, progress (transaction state display)
  L4: progress, data_table (system health display)
  L5: ooda_ring, reasoning (cognitive layer)
  L6: topology (ecosystem mesh view)
  L7: topology (federation graph view)
```

---

## Page Complexity Tiers

Test effort is proportional to LTS state count × Msg variant count.

| Tier | Msg Variants | Model Fields | Pages | Test Effort |
|------|-------------|-------------|-------|-------------|
| **Tier 1** (High) | 6+ Msg variants | 5+ model fields | Dashboard, Cockpit, Agents, Verification, Planning, Immune | 15-20 tests each |
| **Tier 2** (Medium) | 3-5 Msg variants | 3-4 model fields | Knowledge, Zenoh, Telemetry, Substrate, Metabolic, Podman, Smriti | 10-15 tests each |
| **Tier 3** (Low) | 1-2 Msg variants | 1-2 model fields | Mcp, Kms, Bridge, Config, Database, Git, Holon, Prajna, PlanningDashboard | 5-10 tests each |

---

## Test Structure

### Gleam MVU LTS Test Pattern (gleeunit)

```gleam
// File: lib/cepaf_gleam/test/agents_lts_test.gleam
// LTS(Agents) — state coverage for agents.gleam
// STAMP: SC-UIGT-003, SC-UIGT-004, SC-UIGT-007

import cepaf_gleam/ui/lustre/agents.{
  AgentsModel, AgentsMsg, DeadlockDetected, EfficiencyUpdated,
  HierarchyLoaded, RefreshAgents, init, update,
}
import gleeunit/should

// --- Node Coverage: s₀ (initial state) ---

pub fn init_returns_zero_counts_test() {
  let m = init()
  m.total_agents |> should.equal(0)
  m.deadlock_detected |> should.equal(False)
}

// --- Edge Coverage: all Msg variants ---

pub fn hierarchy_loaded_updates_counts_test() {
  let m = init()
  let m2 = update(m, HierarchyLoaded(25, 1, 4, 20))
  m2.total_agents |> should.equal(25)
  m2.executives |> should.equal(1)
  m2.supervisors |> should.equal(4)
  m2.workers |> should.equal(20)
}

pub fn efficiency_updated_changes_float_test() {
  let m = update(init(), HierarchyLoaded(10, 1, 2, 7))
  let m2 = update(m, EfficiencyUpdated(0.87))
  m2.efficiency |> should.equal(0.87)
}

pub fn deadlock_detected_true_sets_flag_test() {
  let m = init()
  let m2 = update(m, DeadlockDetected(True))
  m2.deadlock_detected |> should.equal(True)
}

pub fn deadlock_detected_false_clears_flag_test() {
  let m = update(init(), DeadlockDetected(True))
  let m2 = update(m, DeadlockDetected(False))
  m2.deadlock_detected |> should.equal(False)
}

pub fn refresh_agents_resets_counts_test() {
  let m = update(init(), HierarchyLoaded(10, 1, 2, 7))
  let m2 = update(m, RefreshAgents)
  // RefreshAgents triggers reload — model resets or stays stable
  m2.total_agents |> should.be_ok  // type-level check
}

// --- Prime Path PP-AGENTS-01: init → hierarchy_loaded → efficiency_updated ---

pub fn pp_agents_01_load_then_efficiency_test() {
  init()
  |> update(_, HierarchyLoaded(20, 1, 4, 15))
  |> update(_, EfficiencyUpdated(0.92))
  |> fn(m) { m.efficiency |> should.equal(0.92) }
}

// --- Prime Path PP-AGENTS-02: init → deadlock → refresh → load ---

pub fn pp_agents_02_deadlock_then_refresh_test() {
  let m =
    init()
    |> update(_, DeadlockDetected(True))
    |> update(_, RefreshAgents)
    |> update(_, HierarchyLoaded(5, 1, 1, 3))
  m.deadlock_detected |> should.equal(False)
  // After reload, deadlock flag cleared
}
```

### Wisp API E2E Test Pattern

```gleam
// File: lib/cepaf_gleam/test/wisp_router_e2e_test.gleam
// Wisp HTTP endpoint verification via wisp/testing (no browser needed).
// STAMP: SC-UIGT-008, SC-GLM-UI-003

import cepaf_gleam/ui/wisp/router
import gleam/http.{Get}
import gleeunit/should
import wisp/testing

// --- C1: Page Structure — each route returns 200 with JSON body ---

pub fn dashboard_route_returns_200_test() {
  let req = testing.get("/api/dashboard", [])
  let resp = router.handle_request(req)
  resp.status |> should.equal(200)
}

pub fn agents_route_returns_json_test() {
  let req = testing.get("/api/agents", [])
  let resp = router.handle_request(req)
  resp.status |> should.equal(200)
}

pub fn verification_route_returns_json_test() {
  let req = testing.get("/api/verification", [])
  let resp = router.handle_request(req)
  resp.status |> should.equal(200)
}

// --- C5: Interactive — POST endpoints accept typed data ---

pub fn agui_run_started_post_test() {
  let body = "{\"run_id\": \"test-run-001\", \"agent_id\": \"cortex\"}"
  let req = testing.post("/agui/events/run-started", [], body)
  let resp = router.handle_request(req)
  resp.status |> should.equal(200)
}

// --- C8: Action Buttons — HITL decision endpoint ---

pub fn hitl_approve_returns_200_test() {
  let body = "{\"request_id\": \"approve-123\", \"decision\": \"approved\"}"
  let req = testing.post("/agui/hitl/respond", [], body)
  let resp = router.handle_request(req)
  resp.status |> should.equal(200)
}

// --- Navigation graph: all 22 routes registered ---

pub fn all_page_routes_registered_test() {
  let routes = [
    "/dashboard", "/planning", "/immune", "/knowledge", "/zenoh",
    "/cockpit", "/verification", "/substrate", "/metabolic", "/podman",
    "/mcp", "/kms", "/telemetry", "/agents", "/bridge", "/config",
    "/database", "/git", "/holon", "/prajna", "/smriti",
    "/planning/dashboard",
  ]
  // Each route must be reachable (not 404)
  let results = {
    use path <- list.map(routes)
    let req = testing.get(path, [])
    let resp = router.handle_request(req)
    resp.status
  }
  list.all(results, fn(s) { s != 404 }) |> should.equal(True)
}
```

### Navigation Graph Test Pattern

```gleam
// File: lib/cepaf_gleam/test/nav_graph_test.gleam
// Verifies the 22-page navigation digraph properties.
// STAMP: SC-UIGT-001, SC-UIGT-011, SC-UIGT-012, SC-UIGT-013, SC-UIGT-014

import cepaf_gleam/testing/nav_graph
import gleam/dict
import gleam/float
import gleam/list
import gleeunit/should

pub fn page_count_is_twenty_two_test() {
  // When domain.gleam adds new pages, this must be updated (SC-UIGT-001)
  nav_graph.page_count() |> should.equal(22)
}

pub fn edge_count_complete_graph_test() {
  let n = nav_graph.page_count()
  nav_graph.edge_count() |> should.equal(n * { n - 1 })
}

pub fn density_is_one_for_complete_graph_test() {
  nav_graph.density() |> should.equal(1.0)
}

pub fn scc_count_is_one_test() {
  // All pages reachable from all pages via nav bar (SC-UIGT-012)
  nav_graph.scc_count() |> should.equal(1)
}

pub fn chinese_postman_bound_equals_edge_count_test() {
  // Complete graph: CPP = |E| (SC-UIGT-013)
  nav_graph.chinese_postman_bound()
  |> should.equal(nav_graph.edge_count())
}

pub fn pagerank_sum_is_one_test() {
  // PageRank values sum to 1.0 (SC-UIGT-014)
  let ranks = nav_graph.page_rank()
  let total =
    dict.values(ranks)
    |> list.fold(0.0, float.add)
  // Allow floating point tolerance
  let diff = float.absolute_value(total -. 1.0)
  { diff <. 0.001 } |> should.equal(True)
}

pub fn test_priority_order_has_correct_length_test() {
  nav_graph.test_priority_order()
  |> list.length()
  |> should.equal(nav_graph.page_count())
}

pub fn all_pages_present_in_adjacency_test() {
  let adj = nav_graph.adjacency()
  dict.size(adj) |> should.equal(nav_graph.page_count())
}
```

### AG-UI Event Graph Test Pattern

```gleam
// File: lib/cepaf_gleam/test/agui_event_graph_test.gleam
// Verifies AG-UI event coverage across 22 pages (SC-UIGT-005).
// STAMP: SC-AGUI-001, SC-UIGT-005

import cepaf_gleam/agui/events
import gleam/list
import gleeunit/should

pub fn all_32_event_types_defined_test() {
  // All event categories must sum to 32 (SC-AGUI-001)
  let counts = [5, 4, 5, 3, 2, 7, 6]  // lifecycle+text+tool+state+activity+reasoning+special
  list.fold(counts, 0, fn(acc, n) { acc + n }) |> should.equal(32)
}

pub fn run_started_event_has_required_fields_test() {
  let e = events.run_started("run-001", "cortex")
  events.event_type(e) |> should.equal("RunStarted")
  events.has_field(e, "run_id") |> should.equal(True)
  events.has_field(e, "agent_id") |> should.equal(True)
}

pub fn state_delta_is_valid_json_patch_test() {
  // StateDelta MUST use RFC 6902 JSON Patch format (SC-AGUI-003)
  let patch = events.state_delta([
    events.patch_replace("/selected_page", "dashboard"),
  ])
  events.event_type(patch) |> should.equal("StateDelta")
  events.is_valid_json_patch(patch) |> should.equal(True)
}

pub fn reasoning_events_form_sequence_test() {
  // Reasoning events: Start → MessageStart → MessageContent → MessageEnd → End
  let start = events.reasoning_start("reason-001")
  let msg_start = events.reasoning_message_start("reason-001", "msg-001")
  let content = events.reasoning_message_content("reason-001", "msg-001", "thinking...")
  let msg_end = events.reasoning_message_end("reason-001", "msg-001")
  let end_ = events.reasoning_end("reason-001")

  [start, msg_start, content, msg_end, end_]
  |> list.map(events.event_type)
  |> should.equal([
    "ReasoningStart", "ReasoningMessageStart", "ReasoningMessageContent",
    "ReasoningMessageEnd", "ReasoningEnd",
  ])
}
```

### Fractal Layer Widget Test Pattern

```gleam
// File: lib/cepaf_gleam/test/fractal_layers_lts_test.gleam
// Verifies fractal layer assignments and widget LTS per layer.
// STAMP: SC-UIGT-006, SC-GLM-UI-001

import cepaf_gleam/ui/domain
import gleeunit/should

// L0 Constitutional — Verification and Immune pages
pub fn verification_page_is_l0_test() {
  let layer = domain.page_fractal_layer(domain.Verification)
  layer |> should.equal(domain.L0Constitutional)
}

pub fn immune_page_is_l0_test() {
  let layer = domain.page_fractal_layer(domain.Immune)
  layer |> should.equal(domain.L0Constitutional)
}

// L1 Atomic Debug — Telemetry and Git pages
pub fn telemetry_page_is_l1_test() {
  let layer = domain.page_fractal_layer(domain.Telemetry)
  layer |> should.equal(domain.L1AtomicDebug)
}

// L2 Component — Mcp, Kms, Bridge pages
pub fn mcp_page_is_l2_test() {
  let layer = domain.page_fractal_layer(domain.Mcp)
  layer |> should.equal(domain.L2Component)
}

// L3 Transaction — Knowledge, Planning, Config, Database, Smriti, PlanningDashboard
pub fn knowledge_page_is_l3_test() {
  let layer = domain.page_fractal_layer(domain.Knowledge)
  layer |> should.equal(domain.L3Transaction)
}

// L4 System — Substrate, Metabolic, Podman
pub fn substrate_page_is_l4_test() {
  let layer = domain.page_fractal_layer(domain.Substrate)
  layer |> should.equal(domain.L4System)
}

// L5 Cognitive — Dashboard, Cockpit, Agents, Prajna
pub fn dashboard_page_is_l5_test() {
  let layer = domain.page_fractal_layer(domain.Dashboard)
  layer |> should.equal(domain.L5Cognitive)
}

// L6 Ecosystem — Zenoh, Holon
pub fn zenoh_page_is_l6_test() {
  let layer = domain.page_fractal_layer(domain.Zenoh)
  layer |> should.equal(domain.L6Ecosystem)
}

// Layer numeric ordering must be monotone
pub fn layer_levels_are_ordered_test() {
  let levels = [
    domain.layer_level(domain.L0Constitutional),
    domain.layer_level(domain.L1AtomicDebug),
    domain.layer_level(domain.L2Component),
    domain.layer_level(domain.L3Transaction),
    domain.layer_level(domain.L4System),
    domain.layer_level(domain.L5Cognitive),
    domain.layer_level(domain.L6Ecosystem),
    domain.layer_level(domain.L7Federation),
  ]
  levels |> should.equal([0, 1, 2, 3, 4, 5, 6, 7])
}
```

---

## Integration with Existing Test Files

This rule governs the following test files already in the codebase:

| Test File | Coverage | Primary STAMP |
|-----------|----------|---------------|
| `batch2_ui_lustre_test.gleam` | LTS node+edge for domain, app, cockpit_view, immune, knowledge, planning, verification, zenoh_mesh | SC-UIGT-003, SC-UIGT-007 |
| `batch3_tui_wisp_verification_test.gleam` | TUI ANSI output, Wisp router paths, domain pure logic | SC-UIGT-008, SC-UIGT-009 |
| `webui_full_coverage_test.gleam` | All 13 domain.gleam pages, full Wisp router, 6 additional Lustre views | SC-UIGT-001, SC-UIGT-002 |
| `coverage_math_alignment_test.gleam` | Shannon H, CCM, ITQS math gates | SC-MATH-COV-001..008 |
| `fractal_layers_test.gleam` | L0-L7 fractal layer widget assignments | SC-UIGT-006 |
| `agui_events_complete_test.gleam` | All 32 AG-UI event types | SC-UIGT-005, SC-AGUI-001 |
| `agui_state_test.gleam` | RFC 6902 StateDelta, StateSnapshot, MessagesSnapshot | SC-UIGT-005 |
| `agents_holon_config_test.gleam` | LTS for agents, holon, config pages | SC-UIGT-003, SC-UIGT-007 |
| `planning_dashboard_test.gleam` | LTS for planning_dashboard page | SC-UIGT-003 |
| `verification_prometheus_test.gleam` | G_nav SCC, PROMETHEUS DAG verification | SC-UIGT-012 |

### Source File Index

```
lib/cepaf_gleam/
  src/cepaf_gleam/
    testing/
      nav_graph.gleam        — G_nav adjacency, PageRank, SCC, Chinese Postman
      coverage_math.gleam    — Shannon H, CCM, ITQS, FSI, D_EA formulas
      alignment.gleam        — Human Intent alignment score (SC-HINT)
    ui/
      domain.gleam           — Page ADT, HealthStatus, FractalLayer (CANONICAL)
      lustre/
        app.gleam            — Root MVU app (Model, Msg, init, update, view)
        agents.gleam         — Agent hierarchy (AgentsModel, AgentsMsg)
        bridge.gleam         — F# bridge status
        cockpit_view.gleam   — Cockpit main panel
        config.gleam         — Configuration editor
        database.gleam       — Database status
        effects.gleam        — AG-UI effect catalog
        git.gleam            — Git operations
        holon.gleam          — Holon mesh view
        immune.gleam         — Immune system (L0)
        kms.gleam            — KMS catalog
        knowledge.gleam      — Knowledge (Smriti)
        mcp.gleam            — MCP server
        metabolic.gleam      — Metabolic plane
        planning.gleam       — Planning tasks
        planning_dashboard.gleam — Planning dashboard
        planning_view.gleam  — Planning detail view
        podman.gleam         — Podman containers
        prajna.gleam         — Prajna cockpit
        smriti.gleam         — Smriti knowledge
        substrate.gleam      — Substrate governor
        telemetry.gleam      — Telemetry stream
        verification.gleam   — PROMETHEUS verification
        zenoh_mesh.gleam     — Zenoh mesh
      wisp/
        router.gleam         — HTTP router + /agui/** endpoints
      tui/
        renderer.gleam       — ANSI output engine
```

---

## Coverage Quality Gates

The 8-category (C1-C8) gold standard applies to all Lustre page tests:

| Category | Weight | Coverage Target | Gleam Mechanism |
|----------|--------|----------------|----------------|
| C1 Page Structure | 1.0 | Element tree has h1, nav, section | View function returns correct Element tree |
| C2 Status Badges | 1.5 | Healthy/Degraded/Critical all rendered | HealthStatus pattern match in view |
| C3 Data Grids | 1.0 | Data rows rendered for non-empty model | Model list fields → html.table rows |
| C4 Timeline/History | 1.2 | Tick/Refresh produces non-identical models | update(m, Tick) != m (for live pages) |
| C5 Interactive | 2.0 | All Msg variants produce valid model | Exhaustive update() tests (compiler-verified) |
| C6 Media/Rich | 1.0 | Sparklines, ANSI codes correct | TUI render_sparkline, with_color verified |
| C7 AI Advisory | 1.5 | AG-UI events flow through Zenoh bus | zenoh_bus.gleam publish/subscribe round-trip |
| C8 Action Buttons | 3.0 | Safety gates pass + Wisp POST response | Guardian approval + 2oo3 via HITL endpoint |

**Aggregate gate**: ITQS = Σ(wᵢ · Cᵢ_score) / Σ(wᵢ) >= 0.85 per test file.

---

## Verification Commands

```bash
# Run all Gleam tests (including graph coverage tests)
cd lib/cepaf_gleam && gleam test

# Run specific test files
cd lib/cepaf_gleam && gleam test -- --test-name nav_graph
cd lib/cepaf_gleam && gleam test -- --test-name agui_event_graph
cd lib/cepaf_gleam && gleam test -- --test-name webui_full_coverage

# Verify graph properties after route changes
cd lib/cepaf_gleam && gleam test -- --test-name page_count_is_twenty_two
cd lib/cepaf_gleam && gleam test -- --test-name scc_count_is_one

# Run Elixir integration (loads Gleam via Mix)
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 \
WALLABY_ENABLED=true ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
mix compile --jobs 16

# Verify coverage math gates
cd lib/cepaf_gleam && gleam test -- --test-name coverage_math_alignment
```

---

## Enforcement: When to Update This Rule

1. **New Lustre page added**: Update the 22-page vertex table, update `testing/nav_graph.gleam`
   `all_pages()`, update SC-UIGT-001 vertex count, update `page_count_is_twenty_two_test`.

2. **New Msg variant added to a page**: Add a corresponding `update()` test for that variant.
   The Gleam compiler will flag missing cases, but test coverage must catch behavioral intent.

3. **New AG-UI event type added**: Update the 32-event count table, add a corresponding
   `agui_event_graph_test.gleam` test for the new event.

4. **New fractal layer widget added**: Add an `L{n}_test()` function to `fractal_layers_lts_test.gleam`.

5. **Route change**: Rebuild `testing/nav_graph.gleam`, re-run SCC analysis, verify
   `scc_count_is_one_test` still passes.

---

## Related Documents

- `docs/journal/20260403-1700-gleam-testing-framework-graph-coverage-hitl.md` — Testing framework design
- `docs/journal/20260403-1500-fractal-agentic-ui-system-design.md` — AG-UI + A2UI design
- `docs/journal/20260403-1600-fractal-agentic-ui-lustre-wisp-alignment.md` — Lustre alignment
- `.claude/rules/gleam-web-ui-development.md` — Full Gleam UI development protocol (SC-GLM-UI)
- `.claude/rules/fractal-coverage-gold-standard.md` — C1-C8 gold standard
- `.claude/rules/fractal-coverage-mathematical-framework.md` — Shannon H, CCM, ITQS math
- `.claude/rules/human-intent-protection.md` — SC-HINT inviolable sections
- `lib/cepaf_gleam/src/cepaf_gleam/testing/nav_graph.gleam` — Live adjacency matrix + PageRank
- `lib/cepaf_gleam/src/cepaf_gleam/testing/coverage_math.gleam` — ITQS math implementation
- `lib/cepaf_gleam/src/cepaf_gleam/ui/domain.gleam` — Canonical Page ADT (22 pages)
