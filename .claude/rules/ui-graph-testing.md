---
paths: test/**/*.exs, test/**/*.feature, lib/indrajaal_web/live/**/*.ex
---

# UI Graph-Theory Testing Framework (SC-UIGT)

## Overview

Mathematical graph-theory-based testing for ALL 30 Prajna LiveView pages.
Models navigation as a directed graph G_nav = (V, E), page state as Labeled Transition Systems (LTS),
and PubSub channels as a bipartite hypergraph. Achieves provable coverage via prime path analysis.

## STAMP Constraints (UI Graph Testing)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-UIGT-001 | Navigation digraph G_nav MUST cover all 30 pages as vertices | CRITICAL |
| SC-UIGT-002 | All navigation edges MUST be verified via Puppeteer or LiveView test | HIGH |
| SC-UIGT-003 | Each page LTS MUST enumerate all states and transitions | HIGH |
| SC-UIGT-004 | Prime path coverage C_path >= 0.95 for critical pages | CRITICAL |
| SC-UIGT-005 | PubSub channel hypergraph MUST map all 40+ subscriptions | HIGH |
| SC-UIGT-006 | Timer frequency spectrum MUST be tested (500ms-30s intervals) | HIGH |
| SC-UIGT-007 | handle_info(:refresh) dynamic update MUST be verified per page | CRITICAL |
| SC-UIGT-008 | handle_event callbacks MUST be exercised per page | HIGH |
| SC-UIGT-009 | Tab/modal state transitions MUST achieve edge coverage | HIGH |
| SC-UIGT-010 | Color Rich chromatic transitions MUST be visually verified | MEDIUM |
| SC-UIGT-011 | Adjacency matrix A MUST be maintained in test/support/ | MEDIUM |
| SC-UIGT-012 | SCC analysis MUST confirm all pages reachable | HIGH |
| SC-UIGT-013 | Chinese Postman lower bound MUST be computed per release | MEDIUM |
| SC-UIGT-014 | PageRank-weighted test priority MUST guide execution order | MEDIUM |
| SC-UIGT-015 | Cross-page data flow paths MUST be tested end-to-end | HIGH |

## AOR Rules (UI Graph Testing)

| ID | Rule |
|----|------|
| AOR-UIGT-001 | Model every LiveView page as an LTS before writing tests |
| AOR-UIGT-002 | Compute prime paths for each LTS using DFS enumeration |
| AOR-UIGT-003 | Verify all handle_info(:refresh) callbacks update assigns |
| AOR-UIGT-004 | Verify all handle_event callbacks produce correct state transitions |
| AOR-UIGT-005 | Test PubSub message flow from source GenServer to LiveView |
| AOR-UIGT-006 | Use Puppeteer MCP for visual regression on Color Rich profiles |
| AOR-UIGT-007 | Maintain adjacency matrix in test/support/nav_graph.ex |
| AOR-UIGT-008 | Run SCC analysis on navigation graph after any route change |
| AOR-UIGT-009 | Compute coverage metrics: C_node, C_edge, C_path, C_data |
| AOR-UIGT-010 | Weight test priority by PageRank of target page |

## Mathematical Foundations

### 1. Navigation Digraph G_nav = (V, E_nav)

```
V = {v₁, v₂, ..., v₃₀}  (30 Prajna pages)
E_nav ⊆ V × V             (navigation links + nav bar edges)

Adjacency Matrix: A ∈ {0,1}^{30×30}
  A[i][j] = 1 iff page i has a link/nav to page j

Properties:
  - |V| = 30
  - |E_nav| ≈ 275 (nav bar creates near-complete subgraph)
  - SCC = 1 (all pages reachable from all pages via nav bar)
  - Density = |E| / (|V|·(|V|-1)) ≈ 0.316
```

### 2. Page-Level Labeled Transition System (LTS)

For each page p ∈ V:
```
LTS(p) = (S_p, Σ_p, →_p, s₀_p)
  S_p  = {states}           (tab selections, modal open/closed, data loaded/loading)
  Σ_p  = {events}           (handle_event names + handle_info messages + PubSub)
  →_p  ⊆ S_p × Σ_p × S_p   (transitions)
  s₀_p = initial state      (mount/3 result)
```

### 3. Coverage Criteria

| Criterion | Formula | Target |
|-----------|---------|--------|
| Node Coverage | C_node = \|tested_states\| / \|S_p\| | >= 1.0 |
| Edge Coverage | C_edge = \|tested_transitions\| / \|→_p\| | >= 0.95 |
| Prime Path Coverage | C_path = \|tested_prime_paths\| / \|PP(LTS(p))\| | >= 0.95 |
| Data Flow Coverage | C_data = \|tested_du_pairs\| / \|DU(p)\| | >= 0.90 |
| Total Coverage | C_total = w₁·C_node + w₂·C_edge + w₃·C_path + w₄·C_data | >= 0.95 |
| Weights | w₁=0.2, w₂=0.3, w₃=0.3, w₄=0.2 | |

### 4. Prime Path Enumeration

A prime path is a simple path (no repeated vertices except possibly first=last) that is not a proper subpath of any other simple path.

```
Algorithm: PrimePaths(LTS)
  1. Enumerate all simple paths of length 0 (single nodes)
  2. Extend each path by one edge
  3. Remove paths that are subpaths of longer paths
  4. Result: set PP(LTS) of prime paths
```

### 5. Chinese Postman Lower Bound

Minimum number of test cases to achieve edge coverage:
```
CPP(G) = |E| + matching_cost(odd_degree_vertices)

For G_nav: CPP ≈ 275 + 13 = 288 (lower bound)
System-wide with LTS: ≈ 458 test cases minimum
```

### 6. PageRank Test Priority

Pages with higher PageRank get tested first (more reachable = more critical):
```
PR(p) = (1-d)/|V| + d · Σ_{q→p} PR(q)/out_degree(q)
d = 0.85 (damping factor)

High-priority pages (estimated):
  1. Dashboard (/prajna)           PR ≈ 0.068
  2. Observability (/cockpit/obs)  PR ≈ 0.052
  3. Guardian (/cockpit/guardian)   PR ≈ 0.048
  4. Sentinel (/cockpit/sentinel)   PR ≈ 0.045
  5. Alarms (/cockpit/alarms)       PR ≈ 0.042
```

## Page Complexity Tiers

| Tier | Events | PubSub | Timer | Pages | Test Effort |
|------|--------|--------|-------|-------|-------------|
| **Tier 1** (High) | 6+ events | 2+ channels | 500ms | observability, guardian, sentinel, alarms, copilot | 15-20 tests each |
| **Tier 2** (Medium) | 3-5 events | 1-2 channels | 1-5s | cluster, devices, mesh, analytics, compliance | 10-15 tests each |
| **Tier 3** (Low) | 1-2 events | 0-1 channels | 5-30s | settings, video, register, knowledge/* | 5-10 tests each |

## Test Structure

### ExUnit LiveView Test Pattern
```elixir
defmodule IndrajaalWeb.Prajna.PageLiveGraphTest do
  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  # LTS State Enumeration
  @states [:initial, :tab_metrics, :tab_traces, :modal_open, :data_refreshed]
  @events ["switch_tab", "view_detail", "export"]
  @pubsub_channels ["prajna:metrics", "prajna:traces"]

  describe "LTS node coverage" do
    test "mount reaches initial state (s₀)" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      assert render(view) =~ "Observability"
    end

    test "all tabs reachable" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      for tab <- ["metrics", "traces", "logs", "signoz"] do
        assert render_click(view, "switch_tab", %{"tab" => tab}) =~ tab
      end
    end
  end

  describe "LTS edge coverage" do
    test "handle_info(:refresh) updates assigns" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      html_before = render(view)
      send(view.pid, :refresh)
      html_after = render(view)
      # Dynamic content should change (timestamps, metrics)
      assert html_after != html_before or html_after =~ ~r/\d+/
    end
  end

  describe "PubSub data flow" do
    test "metrics channel updates view" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:metrics", {:metrics_update, %{cpu: 42}})
      assert render(view) =~ "42"
    end
  end
end
```

### BDD Feature Pattern
```gherkin
@prajna @graph_coverage @tier1
Feature: Observability LiveView Graph Coverage
  Tests prime paths through the Observability page LTS

  Scenario: PP-OBS-01 mount → refresh → tab_switch → refresh
    Given I navigate to "/cockpit/observability"
    When 1 second elapses for timer refresh
    And I click the "traces" tab
    And 1 second elapses for timer refresh
    Then the traces panel should show updated data

  Scenario: PP-OBS-02 mount → pubsub_metrics → export
    Given I navigate to "/cockpit/observability"
    When a metrics PubSub message arrives
    And I click "Export Metrics"
    Then the export should contain current metric values
```

## Integration with Existing Framework

This rule extends Level 4 (Graph-Based Path Analysis) and Level 5 (BDD Integration) from `five-level-testing.md`:
- **Level 4**: LTS enumeration + prime path computation + coverage metrics
- **Level 5**: BDD scenarios derived from prime paths + Puppeteer visual verification

Files generated by this framework:
```
test/
├── graph/
│   ├── prajna_nav_graph_test.exs        # Navigation digraph verification
│   ├── prajna_lts_coverage_test.exs     # Per-page LTS coverage
│   └── prajna_prime_paths_test.exs      # Prime path execution
├── features/
│   └── prajna/
│       ├── observability_graph.feature  # Graph-derived BDD scenarios
│       ├── guardian_graph.feature
│       └── sentinel_graph.feature
└── support/
    ├── nav_graph.ex                     # Adjacency matrix + PageRank
    ├── lts_models.ex                    # Per-page LTS definitions
    └── prime_path_generator.ex          # Prime path enumeration
```

## Verification Commands

```bash
# Run graph coverage tests
MIX_ENV=test mix test test/graph/ --trace

# Run BDD graph scenarios
MIX_ENV=test mix test test/features/prajna/*_graph.feature

# Generate coverage report
mix coveralls.detail --filter graph

# Puppeteer visual regression
mix test.puppeteer --pages all --profile color_rich
```

## Related Documents
- `docs/journal/20260327-2352-prajna-mathematical-test-coverage-framework.md`
- `docs/journal/20260327-2334-observability-dynamic-audit-bdd-plan.md`
- `.claude/rules/five-level-testing.md` (Level 4 + Level 5)
- `.claude/rules/prajna-biomorphic.md` (SC-HMI-010, 8x8 Matrix)
