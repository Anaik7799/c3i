---
paths: lib/cepaf_gleam/test/**/*_test.gleam, lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/**/*.gleam, lib/cepaf_gleam/src/cepaf_gleam/testing/**/*.gleam
---
# UI Graph-Theory Testing Framework (SC-UIGT)
Graph-theory-based testing for all 22 Gleam Lustre pages. Navigation modeled as digraph G_nav=(V,E), page state as LTS from MVU types, AG-UI flow as bipartite hypergraph.
**Frameworks**: gleeunit (unit) | Wisp `testing` module (API E2E, no browser) | `testing/coverage_math.gleam` (metrics) | `testing/nav_graph.gleam` (PageRank, SCC)
# STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-UIGT-001 | G_nav MUST cover all 22 Lustre pages as vertices | CRITICAL |
| SC-UIGT-002 | All nav edges verified via Wisp API or gleeunit MVU test | HIGH |
| SC-UIGT-003 | Each page LTS MUST enumerate all Model states and Msg transitions | HIGH |
| SC-UIGT-004 | Prime path coverage >= 0.95 for Tier 1 pages | CRITICAL |
| SC-UIGT-005 | AG-UI event graph MUST map all 32 event types across pages | HIGH |
| SC-UIGT-006 | A2UI component graph MUST verify all 10 types per fractal layer | HIGH |
| SC-UIGT-007 | update(model, msg) transitions verified per Msg variant | CRITICAL |
| SC-UIGT-008 | Wisp router endpoints exercised via wisp/testing for every route | HIGH |
| SC-UIGT-009 | TUI render functions produce non-empty ANSI for all states | HIGH |
| SC-UIGT-010 | Dark Cockpit mode transitions verified | MEDIUM |
| SC-UIGT-011 | Adjacency matrix in nav_graph.gleam MUST remain current | MEDIUM |
| SC-UIGT-012 | SCC confirms all 22 pages reachable (scc_count() == 1) | HIGH |
| SC-UIGT-013 | Chinese Postman lower bound computed per release | MEDIUM |
| SC-UIGT-014 | PageRank-weighted test priority guides execution order | MEDIUM |
| SC-UIGT-015 | Cross-page AG-UI event flow tested E2E via Zenoh bus | HIGH |
# AOR Rules
| ID | Rule |
|----|------|
| AOR-UIGT-001 | Model each page as LTS (states=Model fields, labels=Msg variants) BEFORE writing tests |
| AOR-UIGT-002 | Compute prime paths via DFS in testing/prime_paths.gleam |
| AOR-UIGT-003 | Verify all update(model, Tick) and update(model, Refresh) transitions |
| AOR-UIGT-004 | Verify update exhaustiveness — Gleam compiler enforces via pattern match |
| AOR-UIGT-005 | Test AG-UI flow: agent emits -> zenoh_bus receives -> Lustre dispatches Msg |
| AOR-UIGT-006 | Use Wisp testing.get/testing.post for API E2E — no browser required |
| AOR-UIGT-007 | Maintain adjacency matrix in nav_graph.gleam — all_pages() lists all 22 |
| AOR-UIGT-008 | Run SCC analysis after any route change |
| AOR-UIGT-009 | Compute coverage: C_node, C_edge, C_path, C_data via coverage_math.gleam |
| AOR-UIGT-010 | Weight test priority by PageRank — test_priority_order() |
# Navigation Digraph G_nav
|V|=22 pages, |E|≈462 (complete via nav bar), SCC=1, density=1.0.
# 22-Page Vertex Set
| # | Page | Path | Module | Layer |
|---|------|------|--------|-------|
| 1 | Dashboard | /dashboard | lustre/app.gleam | L5 |
| 2 | Planning | /planning | lustre/planning.gleam | L3 |
| 3 | Immune | /immune | lustre/immune.gleam | L0 |
| 4 | Knowledge | /knowledge | lustre/knowledge.gleam | L3 |
| 5 | Zenoh | /zenoh | lustre/zenoh_mesh.gleam | L6 |
| 6 | Cockpit | /cockpit | lustre/cockpit_view.gleam | L5 |
| 7 | Verification | /verification | lustre/verification.gleam | L0 |
| 8 | Substrate | /substrate | lustre/substrate.gleam | L4 |
| 9 | Metabolic | /metabolic | lustre/metabolic.gleam | L4 |
| 10 | Podman | /podman | lustre/podman.gleam | L4 |
| 11 | Mcp | /mcp | lustre/mcp.gleam | L2 |
| 12 | Kms | /kms | lustre/kms.gleam | L2 |
| 13 | Telemetry | /telemetry | lustre/telemetry.gleam | L1 |
| 14-22 | Agents, Bridge, Config, Database, Git, Holon, Prajna, Smriti, PlanningDashboard | Various | lustre/*.gleam | L1-L6 |
# Page-Level LTS
For each page p: `LTS(p) = (S_p, Sigma_p, ->_p, s0_p)` where States=Model field combos, Labels=Msg ADT variants, Transitions=update() branches, s0=init() result.
**Gleam advantage**: Exhaustive pattern matching in update() means Sigma_p is provably complete.
# Coverage Criteria (testing/coverage_math.gleam)
| Criterion | Target | Gate |
|-----------|--------|------|
| Node C_node | >= 1.0 | All Model field combinations tested |
| Edge C_edge | >= 0.95 | All update() branches covered |
| Prime Path C_path | >= 0.95 Tier 1 | Maximal simple paths |
| Data Flow C_data | >= 0.90 | Def-use pairs in model fields |
| Total (0.2 node + 0.3 edge + 0.3 path + 0.2 data) | >= 0.95 | — |
**Math gates**: Shannon H >= 2.5, CCM >= 0.90, ITQS >= 0.85, D_EA <= 0.10.
**Prime paths**: Simple paths (no repeated vertices except cycle endpoints) not subpaths of longer ones. DFS enumeration -> each prime path = one `pub fn pp_xxx_test()`.
**Chinese Postman**: CPP = |E| + matching_cost(odd_degree). For G_nav: CPP ≈ 462. System-wide: ~600-700 test cases minimum.
**PageRank priority**: d=0.85, 30 iterations. Dashboard(0.055) > Cockpit(0.052) > Verification(0.050) > Agents(0.048) > Planning(0.047).
# Page Complexity Tiers
| Tier | Msgs | Fields | Pages | Tests |
|------|------|--------|-------|-------|
| 1 (High) | 6+ | 5+ | Dashboard, Cockpit, Agents, Verification, Planning, Immune | 15-20 |
| 2 (Medium) | 3-5 | 3-4 | Knowledge, Zenoh, Telemetry, Substrate, Metabolic, Podman, Smriti | 10-15 |
| 3 (Low) | 1-2 | 1-2 | Mcp, Kms, Bridge, Config, Database, Git, Holon, Prajna, PlanningDashboard | 5-10 |
# Test Patterns
# gleeunit MVU LTS Test
```gleam
// Test file mirrors page: agents_lts_test.gleam for agents.gleam
// Node coverage: init() -> verify defaults
// Edge coverage: update(model, EachMsgVariant) -> verify state change
// Prime paths: chained update() calls through multi-step sequences
import cepaf_gleam/ui/lustre/agents.{init, update, HierarchyLoaded, ...}
import gleeunit/should
pub fn init_returns_defaults_test() { init().total_agents |> should.equal(0) }
pub fn hierarchy_loaded_test() { update(init(), HierarchyLoaded(25,1,4,20)).total_agents |> should.equal(25) }
pub fn pp_load_then_efficiency_test() { init() |> update(_, HierarchyLoaded(20,1,4,15)) |> update(_, EfficiencyUpdated(0.92)) |> fn(m) { m.efficiency |> should.equal(0.92) } }
```
# Wisp API E2E Test
```gleam
// HTTP endpoint verification via wisp/testing (no browser)
import wisp/testing
pub fn dashboard_route_test() { testing.get("/api/dashboard", []) |> router.handle_request |> fn(r) { r.status |> should.equal(200) } }
```
# AG-UI Event Graph G_agui
32 event types mapped across pages. Key subscriptions: Dashboard(RunStarted,RunFinished,StateSnapshot) | Agents(StepStarted,StepFinished,ActivitySnapshot) | Cockpit(ToolCallStart,ToolCallEnd,ReasoningStart) | Verification(RunError,StateSnapshot,StateDelta) | Telemetry(TextMessageChunk,ReasoningMessageContent).
Coverage gate: All 32 types MUST have >= 1 subscribing page (SC-UIGT-005).
# A2UI Component Graph G_a2ui
10 component types stratified by fractal layer: L0(alert,modal) L1(sparkline,badge) L2(badge,button,data_table) L3(data_table,progress) L4(progress,data_table) L5(ooda_ring,reasoning) L6(topology) L7(topology).

# E2E Browser Testing (Playwright + Rust Integration)
**Mandate**: Test every aspect of Gleam webpages using Rust and Playwright code.
- **Static & Dynamic Behavior**: Every element per page MUST be verified for both static rendering and dynamic state changes natively in the DOM.
- **Full User Journeys**: Multi-page scenarios (e.g., Dashboard -> Planning -> Execute) MUST be fully traversed.
- **Tools**: Use `@playwright/test` for DOM automation. Invoke the Playwright suite from a Rust integration test (`cargo test --test e2e_playwright`) if bridging environments, or use `npx playwright test` as a CI validation gate.
- **Allium Spec**: All UI testing constraints are formalized in `specs/allium/ui_testing_framework.allium`.

# Criticality & Evolutionary Change Management
- **Rule**: ALL evolution and changes MUST only be made via the planning system (`sa-plan`), based on criticality prioritization. No shadow development is permitted.

# Agentic UI Evolution Cross-References
- **Master Prompt**: `.claude/commands/c3i-page-evolution.md` — 8-phase evolution with 179+ Rust E2E tests
- **Rule**: `.claude/rules/agentic-ui-responsive-design.md` — SC-AGUI-UI-001..015
- **DAG Scenarios**: 6 multi-step cross-component test paths (M-R) + 7 responsive sections (S-Y)
- **Rust E2E**: `test/planning_e2e_rust.rs` — 179-test binary replacing all Python verification
