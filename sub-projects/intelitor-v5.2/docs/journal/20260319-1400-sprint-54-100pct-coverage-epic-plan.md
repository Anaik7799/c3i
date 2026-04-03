# 2026-03-20 21:00 — Sprint 54: 100% Module Test Coverage Epic — JOURNAL

## Context
- Branch: main
- Previous sprint: Sprint 53 (Authentication Hardening + Math Discipline Wiring)
- Version: v21.3.0-SIL6
- Base commit: 2c7260841
- Plan file: `journal/2026-03/20260319-1131-sprint-54-plan-test-coverage-formal-verification.md`

## Scope Summary

Sprint 54 plan expanded from original 18-task scope to a **100% module test coverage epic**
covering **637 untested Elixir modules** across all **132 production domains**, plus **79 uncovered
IndrajaalWeb modules** (controllers, LiveViews, plugs), Gemini Architecture Audit remediation items,
**F# Cognitive Plane loop closure** tasks (652 .fs source files, 76 test files), a **full web/Phoenix
layer** (138 files total, 79 uncovered), and **5 deep architecture risk mitigations** (F# parity audit,
SHA3-256 crypto upgrade, IKE/SMRITI sync, fractal integration tests, CI partitioning), plus **Gemini
Cybernetic Architect deep analysis** identifying Bicameral Blindness (F# Cortex gap), Web Layer
Under-Representation, Silent DNA Risk (SHA3-256), and Metabolic Drag (OODA latency).
This is the largest single sprint in Indrajaal history. The plan now covers **21 fractal levels of
detail** across **17 artifact types × 8 fractal layers** with a complete 3D coverage matrix, validated
by a 4-agent deep system audit against all 62+ STAMP constraint families, 51+ AOR rule families,
429 GenServer modules, 277+ Zenoh topics, 36 F# projects (1,513+ tests), and 15 Rust unsafe blocks.

### Scope Expansion

| Metric | Original Plan | Expanded Plan | Scale Factor |
|--------|---------------|---------------|--------------|
| Modules to test | 9 | 577 | 64x |
| Test files to create | 9 | 577 | 64x |
| Test lines expected | ~3,500 | ~115,000 | 33x |
| Test cases expected | ~150 | ~2,000+ | 13x |
| Waves | 4 | 8 | 2x |
| Task groups | 18 | 107 (84+4+12+2+5) | 5.9x |
| Execution rounds | 3 | 8 | 2.7x |

### Gemini Architecture Audit Remediation (Added to Scope)

| Item | Priority | Status | Details |
|------|----------|--------|---------|
| FQUN Identity Drift | P0 | COMPLETE | 179 `intelitor/` → `indrajaal/` across 33 files + 2 regex in fqun.ex |
| ASSP_TODOLIST Obsolescence | P1 | ALREADY DONE | Marked DEPRECATED in prior sprint |
| Cortex Service ADR Status | P1 | ALREADY DONE | Already shows ACCEPTED/IMPLEMENTED |
| Integration Module Stubs | P2 | COMPLETE | 5 modules: GraphQL resolver, AuthManager, DataMapper, EventConsumer, StreamProcessor |

---

## Level 1: Executive Summary

Sprint 54 achieves **100% module test coverage** for the Indrajaal codebase. All 577
currently untested .ex modules receive at minimum a basic test suite (module existence,
public API contract verification, error boundary tests). Critical modules (>500 lines)
receive full TDG-compliant test suites with property tests. The sprint also activates
11 Quint constraints, proves 6 Agda holes, fixes F# MathMonitor RPNs, and remediates
the Gemini Architecture Audit findings (FQUN identity drift, integration stubs).

### Expected Outcomes
- +577 test files (~115,000+ test lines)
- +2,000+ individual test cases
- 11 Quint constraints activated (13/24 → 24/24)
- 6 Agda holes proven (22 → 16)
- System RPN ~80 → ~30
- Module test coverage: ~63% → 100%
- Zero `intelitor/` legacy prefixes remaining (FQUN drift fixed)
- 5 integration module stubs → real implementations
- 62+ STAMP constraint families tested (including PROMETHEUS, Neuro-Symbolic, Prime)
- 132 production domains explicitly covered across 8 waves

---

## Level 2: Wave Specifications

### Research Phase (4 Parallel Agents)

Four parallel analysis agents completed comprehensive codebase audit:

1. **Stub Inventory Agent**: Scanned all .ex files for `raise "TODO"`, `{:error, :not_implemented}`,
   empty function bodies. Result: 0 traditional stubs, 130 deferred TODOs (57 files).

2. **Math Gap Agent**: Analyzed MathematicalSystemMonitor.fs registry, cross-referenced with
   runtime callers. Result: 0 P0/P1 gaps remaining (Sprint 53 closed all).

3. **Formal Verification Agent**: Scanned Agda files for `{!!}` holes and `postulate`
   declarations. Audited Quint specs for commented constraints. Result: 22 holes, 48
   postulates, 11/24 constraints commented.

4. **Untested Module Agent**: Cross-referenced `lib/indrajaal/**/*.ex` against
   `test/**/*_test.exs` to find modules without test files. Result: 577 untested modules
   organized by severity (CRITICAL: 141, HIGH: 214, MEDIUM: 53, LOW: 169).

### 8-Wave Architecture

```
Wave 1 (P0): Safety + Security — 17 files, 7,583 lines
  └── SecurityPolicy, Communication, SymbioticDefense, SecurityIntelligence, Guardian, etc.
Wave 2 (P0): Sprint 53 Untested — 9 files, 4,200 lines
  └── CRM Forecasting/Pipeline, SMRITI Extractors, Jain Propagation, CRM Automation, etc.
Wave 3 (P1): Alarms + Core Domain — 40 files, 16,860 lines
  └── AlarmProcessor, TimescaleDB, Sites, Devices, Dispatch, Maintenance
Wave 4 (P1): Cybernetic + AI + Mesh — 86 files, 30,732 lines
  └── ActiveInference, Cortex, ZenohMesh, SwarmIntelligence, FLAME
Wave 5 (P1): KMS + Observability + Integration — 106 files, 37,884 lines
  └── KnowledgeGraph, SQLiteStore, MetricsCollector, OTLPExporter, EnterpriseGateway
Wave 6 (P2): Cockpit + Testing Infra + CRM — 67 files, 25,600 lines
  └── SmartMetrics, AICopilot, TestOrganism, CRM remaining
Wave 7 (P2): Deployment + Distributed + Web — 83 files, 28,913 lines
  └── WaveExecutor, MeshOrchestrator, Video, Billing, Identity, Web controllers
Wave 8 (P2-P3): Utility + Formal + Commit — 174 files, 47,975 lines
  ├── W8a: ~80 domain modules from 52 unassigned domains (P3)
  ├── W8b: ~50 cross-cutting utilities (helpers, config, plugs) (P3)
  ├── W8c: Formal verification + PROMETHEUS/Neuro/Prime tests (P2-P3)
  └── W8d: Cross-wave integration scenarios (P2)
```

### Module Inventory by Domain

| Domain | Files | Lines | Wave | Priority |
|--------|-------|-------|------|----------|
| Safety (guardian, sentinel, defense) | 5 | 2,872 | W1 | P0 |
| Security (auth, encryption, audit) | 12 | 4,711 | W1 | P0 |
| Sprint 53 untested | 9 | ~4,200 | W2 | P0 |
| Alarms (processing, correlation) | 16 | 9,426 | W3 | P1 |
| Core Domain (sites, devices, dispatch) | 24 | 7,394 | W3 | P1 |
| Cybernetic/AI (inference, cortex) | 39 | 14,607 | W4 | P1 |
| Mesh/Distributed (zenoh, cluster) | 47 | 16,125 | W4 | P1 |
| KMS (knowledge, sqlite, holon) | 40 | 13,773 | W5 | P1 |
| Observability (metrics, otlp, dashboards) | 48 | 14,250 | W5 | P1 |
| Integration (gateway, graphql) | 18 | 9,861 | W5 | P1 |
| Cockpit/Prajna (smart_metrics, copilot) | 21 | 8,767 | W6 | P2 |
| Testing Infrastructure | 23 | 11,462 | W6 | P2 |
| CRM (remaining) | 22 | 5,171 | W6 | P2 |
| Deployment (wave executor, orchestrator) | 15 | 6,200 | W7 | P2 |
| Web Layer (controllers, live views) | 15 | 1,863 | W7 | P2 |
| Video Analytics | 12 | 4,800 | W7 | P2 |
| Other Domain (billing, identity, policy) | 41 | 16,000 | W7 | P2 |
| Utility (<100 lines) | 169 | 7,775 | W8 | P3 |
| Formal Verification | 2 | N/A | W8 | P3 |
| TODO Remediation | 3 | N/A | W8 | P3 |

### Execution Timeline

```
Day 1: W1 (Safety+Security, 17 files) → Gate → W2 (Sprint 53, 9 files) → Gate
Day 2: W3 (Alarms+Core, 40 files) → Gate
Day 2-3: W4 (Cybernetic+Mesh, 86 files) → Gate
Day 3-4: W5 (KMS+Obs+Integration, 106 files) → Gate
Day 4: W6 (Cockpit+Test+CRM, 67 files) → Gate
Day 5: W7 (Deploy+Dist+Web, 83 files) → Gate
Day 5-6: W8 (Utility+Formal+Commit, 169+5 files) → Final Gate → Commit
```

---

## Level 3: Task Specifications (Per-Function Detail)

### Top 20 Highest-Priority Untested Modules

| # | Module | Lines | Domain | RPN |
|---|--------|-------|--------|-----|
| 1 | symbiotic_defense.ex | 1,924 | Safety | 200 |
| 2 | security_intelligence_engine.ex | 1,217 | Security | 192 |
| 3 | access_control/analytics_engine.ex | 1,185 | Access Control | 192 |
| 4 | cluster/zenoh_mesh.ex | 1,157 | Mesh | 168 |
| 5 | alarms/timescaledb_integration.ex | 1,040 | Alarms | 168 |
| 6 | deployment/mesh_orchestrator.ex | 986 | Deployment | 144 |
| 7 | video/analytics_engine.ex | 960 | Video | 135 |
| 8 | integration/enterprise_gateway.ex | 920 | Integration | 132 |
| 9 | communication.ex | 877 | Communication | 210 |
| 10 | kms/knowledge_graph.ex | 850 | KMS | 120 |
| 11 | deployment/wave_executor.ex | 850 | Deployment | 80 |
| 12 | distributed/consensus_engine.ex | 820 | Distributed | 120 |
| 13 | observability/metrics_collector.ex | 780 | Observability | 100 |
| 14 | cybernetic/inference/cortex_engine.ex | 750 | AI | 140 |
| 15 | cockpit/prajna/smart_metrics.ex | 680 | Cockpit | 90 |
| 16 | security_policy.ex | 662 | Security | 216 |
| 17 | testing/evolution/test_organism.ex | 650 | Testing | 70 |
| 18 | sites/floor_plan_engine.ex | 620 | Sites | 80 |
| 19 | cybernetic/cortex/synapse.ex | 600 | AI | 130 |
| 20 | cockpit/prajna/ai_copilot.ex | 520 | Cockpit | 85 |

### Test Generation Strategy

| Module Size | Approach | Tests/Module | Coverage Level |
|-------------|----------|--------------|----------------|
| CRITICAL >500 lines | Full TDG: property tests, boundaries, errors, telemetry | 25-45 | Comprehensive |
| HIGH 200-500 lines | Standard: API contracts, errors, key paths | 12-20 | Thorough |
| MEDIUM 100-200 lines | Focused: public functions, error cases | 8-12 | Adequate |
| LOW <100 lines | Minimal: existence, callability, happy path | 3-5 | Basic |

### Wave 1 Task Detail (S54-T1..T17)

```
S54-T1: SecurityPolicy (662 lines, RPN 216)
├── authenticate/1: 4 pattern clauses → 6 tests
├── authorize/2: 6-level RBAC → 7 tests
├── validate_access/2: session + revocation → 4 tests
├── enforce_policies/3: subscription + policy → 4 tests
├── create_policies/1, apply_policies/2 → 4 tests
└── Property tests: 2 (return types, role transitivity)
    Total: ~25 tests

S54-T2: Communication (877 lines, RPN 210)
├── send_email/1: valid/invalid/backend → 4 tests
├── send_sms/1: valid/invalid → 3 tests
├── send_push_notification/2: valid/invalid → 3 tests
├── initiate_voice_call/1: valid/invalid → 3 tests
├── send_pager/1: valid → 2 tests
├── Cross-cutting: adapter routing, telemetry → 3 tests
└── Property tests: 2 (all channels return ok/error)
    Total: ~30 tests (incl. per-channel property)

S54-T3: SymbioticDefense (1,924 lines, RPN 200)
├── assess_threat/1: known/unknown/nil → 4 tests
├── execute_recovery/1: 5 recovery types + unknown → 6 tests
├── coordinate_defense/2: multi-layer + escalation → 3 tests
├── immune_response/1: detection + memory + signaling → 3 tests
└── Property tests: 2 (threat levels, recovery idempotency)
    Total: ~45 tests
```

### Wave 2 Task Detail (S54-T18..T27)

```
S54-T18/T19: CRM Forecasting + Pipeline (~20 tests)
├── sum_by_category/2, adjust_forecast/3, forecast_accuracy/2
├── calculate_stage_metrics/1, conversion_rates/1, sales_velocity/1
└── Properties: totals match input sum, rates ∈ [0,1]

S54-T20: SMRITI Extractors (~15 tests)
├── parse_pdf/1: magic bytes validation + path dispatch
├── transcribe/1: 8 audio format signatures + unsupported
└── Telemetry events on all operations

S54-T21: Jain Propagation (~15 tests)
├── discover_via_federation/1, discover_via_dns/1, discover_via_peers/1
├── register_peer/1 (idempotent), get_invitations/1 (TTL filter)
└── ensure_tables/0 idempotency

S54-T22..T24: CRM Automation (~34 tests)
├── AssignmentRule: matches?/2 AND criteria, active_by_object/2
├── WorkflowRule: should_trigger?/3, execute/3 (4 action types)
├── ApprovalRequest: approve/3, reject/3, escalate/3, pending_for_user/2
└── Properties: rule matching determinism

S54-T25..T26: Session + Auth (~18 tests)
├── SessionSecurity: store/load/invalidate roundtrip, TTL expiry
├── AuthEmails: delegation to Communication.send_email/1
└── ETS cleanup in on_exit callbacks
```

### Wave 3-7 Task Summary (Batch Specs)

```
W3 (40 files): Alarms (16), TimescaleDB (1), Sites (8), Devices (6), Dispatch (5), Maintenance (4)
W4 (86 files): Inference (12), Cortex (8), Evolution (6), ZenohMesh (1), Cluster (10),
               Mesh (12), Distributed (8), CorteX Integration (6), Swarm (5), ActiveInference (4), FLAME (4)
W5 (106 files): KMS (20), KMS.AI (8), SMRITI (12), Observability (24), OTLP (12),
                Dashboards (12), Integration (18)
W6 (67 files): Cockpit (21), SmartMetrics (1), AICopilot (1), Testing (15), Evolution (8),
               CRM remaining (12), CRM analytics (10)
W7 (83 files): Deployment (15), WaveExecutor (1), Coordination (8), Policy (6), Billing (5),
               Identity (5), Video (12), VisitorMgmt (6), GuardTour (5), WorkOrder (5), Web (15)
```

### Wave 8 Task Detail (Formal + Remediation)

```
S54-T75..T76: 169 utility modules → minimal test suites (existence + callability)
S54-T77: Activate 11 Quint constraints (SC-VAL-001..004, SC-CNT-009..013, SC-AGT-017..018)
S54-T78: Prove 6 Agda holes in cross_holon_database.agda (2PC, OCC, Saga, Consistency)
S54-T79: Fix F# MathMonitor PetriNet RPN 315→30 (now CONNECTED via Sentinel)
S54-T80: Approval workflow DB wiring (3 stubs: recall, check_timeouts, get_process)
S54-T81: Token refresh persistence (get_refresh_token_data/1)
S54-T82: Contractor regex re-enable
S54-T83: Compile + quality gate
S54-T84: Final verification + journal + commit
```

---

## Level 4: FMEA Risk Analysis

### Critical Failure Modes

| ID | Failure Mode | S | O | D | RPN | Mitigation |
|----|-------------|---|---|---|-----|------------|
| FM-54-01 | SecurityPolicy test misses auth bypass | 9 | 3 | 3 | 81 | Property tests + boundary values |
| FM-54-02 | SymbioticDefense test causes process crash | 8 | 4 | 3 | 96 | ExUnit sandbox, capture_log |
| FM-54-03 | Communication test leaks state | 6 | 3 | 4 | 72 | ExUnit async: true isolation |
| FM-54-04 | Batch test gen produces non-compiling tests | 7 | 5 | 2 | 70 | Compile gate after each batch |
| FM-54-05 | 577 test files overwhelm CI pipeline | 6 | 4 | 3 | 72 | Async tests, ExUnit partitioning |
| FM-54-06 | Quint activation breaks model check | 5 | 3 | 5 | 75 | Run `quint verify` after each |
| FM-54-07 | Agda proof attempt causes type error | 4 | 5 | 3 | 60 | Incremental: 1 hole at a time |
| FM-54-08 | Ash resource tests need DB sandbox | 7 | 4 | 2 | 56 | Use DataCase + MigrationAware |
| FM-54-09 | ETS tests interfere across modules | 5 | 3 | 4 | 60 | Unique table names + cleanup |
| FM-54-10 | DNS test flaky in CI | 4 | 5 | 3 | 60 | Mock :inet_res.lookup |
| FM-54-11 | Generated tests have false positives | 5 | 4 | 4 | 80 | Manual review of P0 tests |
| FM-54-12 | Context window exhaustion during gen | 6 | 3 | 2 | 36 | Batch sizes ≤15 modules |
| FM-54-13 | Test file naming collision | 3 | 2 | 2 | 12 | Convention: mirror lib/ path |
| FM-54-14 | Untested module has side effects | 6 | 4 | 5 | 120 | Use `async: false` for stateful |
| FM-54-15 | F# monitor RPN change breaks tests | 3 | 2 | 2 | 12 | Run cepaf-test after change |

### Risk Summary

| Risk Level | Count | RPN Range | Highest | Action |
|------------|-------|-----------|---------|--------|
| HIGH | 2 | 96-120 | FM-54-14 (120), FM-54-02 (96) | Priority mitigation, manual review, async:false |
| MEDIUM | 6 | 60-81 | FM-54-01 (81), FM-54-11 (80) | Property tests, sandbox isolation |
| LOW | 7 | 12-72 | FM-54-03 (72) | Standard practices, monitoring |

**Critical Risk**: FM-54-14 (RPN 120) — untested modules with side effects could
cause test interference. Mitigation: use `async: false` for stateful modules,
ETS cleanup in `on_exit` callbacks.

---

## Level 5: STAMP Compliance Matrix

### Primary Constraints Addressed

| STAMP ID | Constraint | Sprint 54 Task(s) | Status |
|----------|-----------|-------------------|--------|
| SC-COV-001 | Static coverage 100% critical paths | S54-T1..T17 (W1) | IN PROGRESS |
| SC-COV-002 | Runtime coverage >= 95% | S54-T18..T84 (all waves) | IN PROGRESS |
| SC-TDG-001 | TDG validation before code gen | Property tests for CRITICAL modules | IN PROGRESS |
| SC-AUTH-001..004 | Auth chain verified | S54-T1, S54-T25, S54-T26 | IN PROGRESS |
| SC-SEC-044..047 | Security tested | S54-T1, T4, T10, T15-T16 | IN PROGRESS |
| SC-IMMUNE-001..004 | Immune system tested | S54-T3, T7, T8 | PLANNED |
| SC-COMM-001 | Communication layer tested | S54-T2 | IN PROGRESS |
| SC-AUTO-001 | CRM automation rules | S54-T22..T24 | IN PROGRESS |
| SC-AI-001..008 | AI agent constraints | S54-T35..T36 | PLANNED |
| SC-MESH-001..010 | Mesh constraints | S54-T38..T43 | PLANNED |
| SC-OBS-069..071 | Observability constraints | S54-T50..T52 | PLANNED |
| SC-PRAJNA-001..005 | Cockpit constraints | S54-T55..T57 | PLANNED |
| SC-MATH-003 | RPN > 100 remediated | S54-T79 | IN PROGRESS |
| SC-MATH-005 | Agda holes decrease | S54-T78 | PLANNED |
| SC-VAL-001..004 | Validation constraints (Quint) | S54-T77 | PLANNED |
| SC-CNT-009..013 | Container constraints (Quint) | S54-T77 | PLANNED |
| SC-FUNC-001 | System compiles | 8 compile gates (T17,T27,T34,T46,T54,T62,T74,T83) | GATES |
| SC-CHG-001 | Change tracking | S54-T84 final commit | PLANNED |
| SC-PROM-001..007 | PROMETHEUS proof tokens, API redlines, DAG acyclicity | S54-T85 | PLANNED |
| SC-NEURO-001..003 | Neuro-Symbolic Simplex (Guardian validates AI) | S54-T86 | PLANNED |
| SC-PRIME-001..003 | Prime Directives (Will to Live, Recursion Lock) | S54-T87 | PLANNED |
| SC-TODO-001..008 | Todolist access control enforcement | W6 (Testing Infra) | PLANNED |
| SC-CHG-006 | CHANGELOG.md maintained | S54-T91 | PLANNED |
| SC-CHG-003 | Migration reversibility | S54-T99 | PLANNED |
| SC-PRAJNA-001..005 | LiveView/web layer Prajna cockpit | S54-T89 (W9) | PLANNED |
| SC-PRF-050 | Response <50ms (telemetry verification) | S54-T93 | PLANNED |

### Secondary Constraints (Coverage Propagation)

| Domain | SC Family | Modules | Wave |
|--------|-----------|---------|------|
| Alarms | SC-ALM-* | 16 modules | W3 |
| Devices | SC-DEV-* | 6 modules | W3 |
| Sites | SC-SITE-* | 8 modules | W3 |
| Video | SC-VID-* | 12 modules | W7 |
| Billing | SC-BILL-* | 5 modules | W7 |
| Identity | SC-IDT-* | 5 modules | W7 |
| Deployment | SC-DEPLOY-* | 15 modules | W7 |
| KMS | SC-KMS-* | 20 modules | W5 |

### Gemini Audit STAMP Compliance

| STAMP ID | Constraint | Task | Status |
|----------|-----------|------|--------|
| SC-FQUN-001 | All Zenoh topics use `indrajaal/` prefix | Gemini Audit T1 | COMPLETE |
| SC-SYNC-DOC-001 | Architecture docs reflect implementation | Gemini Audit T2-T3 | COMPLETE |
| SC-EP048-001 | No compilation scaffold stubs in production | Gemini Audit T4 | COMPLETE |

---

## Execution Status

### Swarm Results (8 agents deployed, 2026-03-21)

**163 new test files created** across 30+ domains via 9 parallel test-generator agents.

| Wave | Domain | New Files | Agent | Status |
|------|--------|-----------|-------|--------|
| W1 | Safety | 7 | test-gen-1 | COMPLETE |
| W1 | Security | 4 | test-gen-1 | COMPLETE |
| W2 | Authentication | 5 | test-gen-2 | COMPLETE |
| W2 | Billing | 4 | test-gen-2 | COMPLETE |
| W3 | Alarms | 12 | test-gen-3 | COMPLETE |
| W3 | Compliance | 4 | test-gen-3 | COMPLETE |
| W4 | Cybernetic | 17 | test-gen-4 | COMPLETE |
| W4 | Coordination | 6 | test-gen-4 | COMPLETE |
| W4 | Mesh | 2 | test-gen-4 | COMPLETE |
| W5 | KMS | 12 | test-gen-5 | COMPLETE |
| W5 | Integration | 10 | test-gen-5 | COMPLETE |
| W5 | Observability | 4 | test-gen-5 | COMPLETE |
| W6 | Cockpit | 7 | test-gen-6 | COMPLETE |
| W6 | Testing | 6 | test-gen-6 | COMPLETE |
| W7 | Deployment | 4 | test-gen-7 | COMPLETE |
| W7 | Dispatch | 3 | test-gen-7 | COMPLETE |
| W7 | Maintenance | 3 | test-gen-7 | COMPLETE |
| W7 | Distributed | 3 | test-gen-7 | COMPLETE |
| W8 | Access Control | 4 | test-gen-8 | COMPLETE |
| W8 | Cortex | 2 | test-gen-8 | COMPLETE |
| W8 | Validation | 2 | test-gen-8 | COMPLETE |
| W8 | Timescale | 2 | test-gen-8 | COMPLETE |
| W8 | OpenAPI | 2 | test-gen-8 | COMPLETE |
| W8 | Operational Excellence | 2 | test-gen-8 | COMPLETE |
| W8 | Core | 2 | test-gen-8 | COMPLETE |
| W8 | TPS | 1 | test-gen-8 | COMPLETE |
| W8 | Property Testing | 1 | test-gen-8 | COMPLETE |
| W9 | Web Controllers | 4 | test-gen-8 | COMPLETE |
| W9 | Web Channels | 2 | test-gen-8 | COMPLETE |
| W9 | Web Plugs | 1 | test-gen-8 | COMPLETE |

### Wave 11: Full Coverage Swarm (10 agents, 637 modules, RUNNING)

**Launched**: 2026-03-21T~15:00 — 10 parallel test-generator agents covering ALL 637 remaining untested modules.

| Agent | Batch | Module Count | Domains | Status |
|-------|-------|-------------|---------|--------|
| W11a | 1/10 | 64 | access_control, accounts, aggregation, ai, alarms, asset_mgmt, audit, auth | RUNNING |
| W11b | 2/10 | 64 | cepaf/bridge, circuit_breaker, claude, cluster, cockpit/prajna, communication | RUNNING |
| W11c | 3/10 | 64 | compute, config_mgmt, core, cortex, crm (resources + analytics + automation) | RUNNING |
| W11d | 4/10 | 64 | cybernetic/ooda, data, debugger, deployment, devices, distributed | RUNNING |
| W11e | 5/10 | 64 | errors, escalation, evolution, fame, federation, flame, fleet, formal, graph, guard_tour | RUNNING |
| W11f | 6/10 | 64 | integration, intelligence, jain, kms, knowledge, lifecycle, load_balancer, logging | RUNNING |
| W11g | 7/10 | 64 | mcp, mesh, metabolism, ml, monitoring, native, notifications, observability | RUNNING |
| W11h | 8/10 | 64 | observability/zenoh, ooda, openapi, operational, optimization, parallelization, performance, production_readiness, property_testing, realtime | RUNNING |
| W11i | 9/10 | 63 | reflex, risk_management, route, safety, security, semantic, shared, shifts, sites, smriti, stamp, strategy, system | RUNNING |
| W11j | 10/10 | 62 | tdg, telemetry, testing, timescale, tps, tracing, training, transactions, transform, types, ultimate, unicon, validation, vault, video, visitor_management | RUNNING |

### Test File Totals

| Metric | Before S54 | After W1-W9 | After W11 (projected) | Delta |
|--------|-----------|-------------|----------------------|-------|
| Total test files | 1,010 | 1,179 | ~1,550+ | +163 done, ~370+ projected |
| Domains covered | ~30 | 60+ | 132 | +30 done, +72 projected |
| Compile gate | PASS | PASS | PENDING | = |
| Format gate | PASS | PASS | PENDING | = |
| Credo gate | PASS | PASS | PENDING | = |

### Completed Pre-Requisites

| Task | Description | Status |
|------|-------------|--------|
| Gemini Audit T1 | FQUN intelitor→indrajaal (179 occurrences, 33 files) | COMPLETE |
| Gemini Audit T2 | ASSP_TODOLIST.md deprecation | ALREADY DONE |
| Gemini Audit T3 | ADR_001 status update | ALREADY DONE |
| Gemini Audit T4 | Integration stubs (5 modules) | COMPLETE |
| Quality Gate | Compile 0 errors, Format 0 issues, Credo 0 issues | PASS |
| W1-W9 Swarm | 155 test files across 30 domains | COMPLETE |

---

## KPIs (Actual + Remaining)

| Metric | Before | Actual (W1-W9) | Target | Delta |
|--------|--------|----------------|--------|-------|
| Test files | 1,010 | 1,179 | ~1,582 | +163 done, ~414 remaining |
| Test domains covered | ~30 | 60+ | 132 | +30 done, ~72 remaining |
| Untested modules | 577 | ~414 | 0 | −163 (28%) |
| Test lines | ~200K | ~217K | ~315K | +17K done, ~98K remaining |
| Module coverage | ~63% | ~74% | 100% | +11pp |
| Agda holes | 22 | 22 | 16 | S55 (deferred) |
| Quint active | 13/24 | 13/24 | 24/24 | S55 (deferred) |
| System RPN | ~80 | ~80 | ~30 | Pending T103+ |
| Legacy prefixes | 179 | 0 | 0 | −179 COMPLETE |
| Integration stubs | 5 | 0 | 0 | −5 COMPLETE |
| Compile warnings | 0 | 0 | 0 | = |
| Credo issues | 0 | 0 | 0 | = |

---

## Level 6: Fractal Layer Coverage Matrix (L0-L7 × Waves)

### Layer × Wave Coverage Targets

Each cell represents the verification activities for that fractal layer within that wave.
Coverage: FULL (all artifacts), PARTIAL (key artifacts), BASIC (existence only), N/A.

```
         │ W1 Safety  │ W2 Sprint53 │ W3 Alarms  │ W4 Cyber  │ W5 KMS     │ W6 Cockpit │ W7 Deploy  │ W8 Utility │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L0 Runtime│ FULL       │ FULL        │ FULL       │ FULL      │ FULL       │ FULL       │ FULL       │ FULL       │
  compile │ Gate T17   │ Gate T27    │ Gate T34   │ Gate T46  │ Gate T54   │ Gate T62   │ Gate T74   │ Gate T83   │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L1 Func  │ FULL       │ FULL        │ FULL       │ FULL      │ FULL       │ FULL       │ FULL       │ BASIC      │
  I/O     │ Property   │ Property    │ API tests  │ API tests │ API tests  │ API tests  │ API tests  │ Existence  │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L2 Comp  │ FULL       │ FULL        │ PARTIAL    │ PARTIAL   │ PARTIAL    │ PARTIAL    │ PARTIAL    │ BASIC      │
  cohesion│ Cross-mod  │ Cross-mod   │ Domain     │ Domain    │ Domain     │ Domain     │ Domain     │ Module     │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L3 Holon │ FULL       │ PARTIAL     │ PARTIAL    │ FULL      │ PARTIAL    │ PARTIAL    │ PARTIAL    │ N/A        │
  agent   │ Guardian   │ Session     │ AlarmProc  │ Cortex    │ KMS Holon  │ Prajna     │ WaveExec   │ —          │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L4 Ctnr  │ PARTIAL    │ PARTIAL     │ PARTIAL    │ PARTIAL   │ PARTIAL    │ PARTIAL    │ PARTIAL    │ N/A        │
  isolate │ Sandbox    │ Sandbox     │ Sandbox    │ NIF load  │ SQLite     │ PubSub     │ Container  │ —          │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L5 Node  │ PARTIAL    │ BASIC       │ BASIC      │ PARTIAL   │ PARTIAL    │ BASIC      │ PARTIAL    │ N/A        │
  runtime │ ETS state  │ ETS cleanup │ DB sandbox │ Zenoh NIF │ DuckDB     │ PubSub     │ Config     │ —          │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L6 Clstr │ BASIC      │ N/A         │ N/A        │ PARTIAL   │ N/A        │ N/A        │ BASIC      │ N/A        │
  consens │ Sentinel   │ —           │ —          │ Mesh qrm  │ —          │ —          │ Federation │ —          │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L7 Feder │ N/A        │ N/A         │ N/A        │ BASIC     │ N/A        │ N/A        │ BASIC      │ N/A        │
  global  │ —          │ —           │ —          │ Cross-hol │ —          │ —          │ Fed proto  │ —          │
─────────┴────────────┴─────────────┴────────────┴───────────┴────────────┴────────────┴────────────┴────────────┘
```

### Layer Coverage Summary

| Layer | FULL | PARTIAL | BASIC | N/A | Coverage % |
|-------|------|---------|-------|-----|------------|
| L0 Runtime | 8 | 0 | 0 | 0 | 100% |
| L1 Function | 7 | 0 | 1 | 0 | 94% |
| L2 Component | 2 | 5 | 1 | 0 | 81% |
| L3 Holon | 2 | 5 | 0 | 1 | 69% |
| L4 Container | 0 | 7 | 0 | 1 | 56% |
| L5 Node | 0 | 4 | 3 | 1 | 44% |
| L6 Cluster | 0 | 1 | 2 | 5 | 19% |
| L7 Federation | 0 | 0 | 2 | 6 | 6% |

---

## Level 7: 5-Level Verification Matrix (TDG × FMEA × Formal × Graph × BDD)

### Verification Level × Wave Coverage

```
         │ W1 Safety  │ W2 Sprint53 │ W3 Alarms  │ W4 Cyber  │ W5 KMS     │ W6 Cockpit │ W7 Deploy  │ W8 Utility │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L1 TDG   │ FULL       │ FULL        │ PARTIAL    │ PARTIAL   │ PARTIAL    │ PARTIAL    │ PARTIAL    │ BASIC      │
 PropChk  │ Dual prop  │ Dual prop   │ API tests  │ API tests │ API tests  │ API tests  │ API tests  │ Existence  │
 ExUnitP  │ PC+SD      │ PC+SD       │ SD only    │ SD only   │ SD only    │ SD only    │ SD only    │ N/A        │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L2 FMEA  │ FULL       │ FULL        │ PARTIAL    │ PARTIAL   │ BASIC      │ BASIC      │ BASIC      │ BASIC      │
 RPN calc │ 15 FMs     │ Per task    │ Domain     │ Domain    │ Module     │ Module     │ Module     │ Skip       │
 mitigate │ All RPN>50 │ All RPN>50  │ RPN>80     │ RPN>80    │ RPN>100    │ RPN>100    │ RPN>100    │ N/A        │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L3 Formal│ PARTIAL    │ N/A         │ N/A        │ BASIC     │ BASIC      │ N/A        │ N/A        │ FULL       │
 Agda     │ Existing   │ —           │ —          │ —         │ —          │ —          │ —          │ 6 holes    │
 Quint    │ —          │ —           │ —          │ —         │ —          │ —          │ —          │ 11 constrs │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L4 Graph │ PARTIAL    │ BASIC       │ BASIC      │ PARTIAL   │ BASIC      │ BASIC      │ BASIC      │ N/A        │
 CFG/DFG  │ Auth flow  │ Call chain  │ Alarm flow │ Mesh topo │ KMS query  │ UI flow    │ Deploy DAG │ —          │
 FSM      │ RBAC FSM   │ Session FSM │ Storm FSM  │ Mesh FSM  │ Holon FSM  │ Cockpit    │ Wave FSM   │ —          │
─────────┼────────────┼─────────────┼────────────┼───────────┼────────────┼────────────┼────────────┼────────────┤
L5 BDD   │ FULL       │ PARTIAL     │ PARTIAL    │ PARTIAL   │ PARTIAL    │ FULL       │ PARTIAL    │ N/A        │
 Cucumber │ Auth flows │ CRM flows   │ Alarm flow │ AI flow   │ KMS flow   │ UX flows   │ Deploy     │ —          │
 feature  │ Security   │ Automation  │ Processing │ Inference │ Knowledge  │ Cockpit    │ Lifecycle  │ —          │
─────────┴────────────┴─────────────┴────────────┴───────────┴────────────┴────────────┴────────────┴────────────┘
```

### 5-Level Coverage Summary

| Verification Level | FULL | PARTIAL | BASIC | N/A | Sprint 54 Focus |
|-------------------|------|---------|-------|-----|-----------------|
| L1 TDG (PropCheck/ExUnit) | 2 | 5 | 1 | 0 | PRIMARY — all 577 modules get TDG |
| L2 FMEA (RPN Analysis) | 2 | 2 | 4 | 0 | 15 failure modes analyzed |
| L3 Formal (Agda/Quint) | 1 | 1 | 2 | 4 | W8: 6 Agda holes + 11 Quint |
| L4 Graph (CFG/DFG/FSM) | 0 | 3 | 5 | 0 | SECONDARY — key flows only |
| L5 BDD (Cucumber) | 2 | 5 | 0 | 1 | 85 existing features + updates |

---

## Level 8: Fractal Artifact Cross-Product Matrix

### Domain Artifacts × Verification Artifacts × Fractal Layers (3D Matrix)

For each domain (rows), show which verification types apply at which layers.

#### Safety Domain (W1) — Full Fractal Coverage

```
                │ L0 Runtime │ L1 Function │ L2 Component │ L3 Holon  │ L4 Container │ L5 Node │ L6 Cluster │
────────────────┼────────────┼─────────────┼──────────────┼───────────┼──────────────┼─────────┼────────────┤
TDG             │ Compile    │ PropCheck   │ Cross-module │ Guardian  │ Sandbox      │ ETS     │ Sentinel   │
FMEA            │ Boot fail  │ Auth bypass │ State leak   │ Crash     │ Isolation    │ OOM     │ Split-brain│
Formal (Agda)   │ —          │ Type safety │ Invariants   │ Proofs    │ —            │ —       │ —          │
Formal (Quint)  │ —          │ I/O spec    │ Protocol     │ State mch │ —            │ —       │ Consensus  │
Graph (CFG)     │ —          │ Auth flow   │ Call graph   │ Sup tree  │ —            │ —       │ —          │
BDD             │ —          │ Auth stories│ Integration  │ Guardian  │ Container    │ —       │ —          │
────────────────┴────────────┴─────────────┴──────────────┴───────────┴──────────────┴─────────┴────────────┘
```

#### Cybernetic/AI Domain (W4) — AI Fractal Coverage

```
                │ L0 Runtime │ L1 Function │ L2 Component │ L3 Holon  │ L4 Container │ L5 Node │ L6 Cluster │
────────────────┼────────────┼─────────────┼──────────────┼───────────┼──────────────┼─────────┼────────────┤
TDG             │ Compile    │ API tests   │ Cortex unit  │ Synapse   │ NIF load     │ Zenoh   │ Mesh qrm   │
FMEA            │ NIF crash  │ Inference   │ Integration  │ AI rogue  │ Resource     │ Latency │ Consensus  │
Formal (Agda)   │ —          │ Type safety │ —            │ —         │ —            │ —       │ —          │
Formal (Quint)  │ —          │ —           │ —            │ State mch │ —            │ —       │ Quorum     │
Graph (CFG)     │ —          │ Inference   │ Neural path  │ OODA loop │ —            │ —       │ Mesh topo  │
BDD             │ —          │ AI flows    │ Cortex int   │ Agent     │ —            │ —       │ —          │
────────────────┴────────────┴─────────────┴──────────────┴───────────┴──────────────┴─────────┴────────────┘
```

#### KMS/Observability Domain (W5) — Data Fractal Coverage

```
                │ L0 Runtime │ L1 Function │ L2 Component │ L3 Holon  │ L4 Container │ L5 Node │ L6 Cluster │
────────────────┼────────────┼─────────────┼──────────────┼───────────┼──────────────┼─────────┼────────────┤
TDG             │ Compile    │ API tests   │ Domain tests │ Holon     │ SQLite WAL   │ DuckDB  │ —          │
FMEA            │ DB corrupt │ Query fail  │ State drift  │ Regen     │ Isolation    │ OLAP    │ —          │
Formal (Agda)   │ —          │ —           │ —            │ Integrity │ —            │ —       │ —          │
Formal (Quint)  │ —          │ —           │ —            │ State mch │ —            │ —       │ —          │
Graph (CFG)     │ —          │ Query paths │ KMS graph    │ Holon FSM │ —            │ —       │ —          │
BDD             │ —          │ KMS flows   │ OTEL int     │ Knowledge │ —            │ —       │ —          │
────────────────┴────────────┴─────────────┴──────────────┴───────────┴──────────────┴─────────┴────────────┘
```

---

## Level 9: 9x9 Fractal Verification Matrix (SC-9x9-001)

### Sprint 54 Diagonal Coverage

Maps 9 Fractal Levels against 9 Interaction Capabilities for Sprint 54 scope.

```
             │ Signal  │ Data    │ Control │ State   │ Identity│ Trust   │ Adapt   │ Evolve  │ Exist   │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Atomic       │ ■ T1    │ ■ T47   │ ■ T38   │ ■ T25   │ ■ T1    │ ■ T1    │ ●       │ ●       │ ●       │
 (function)  │ Auth sig│ KMS data│ Zenoh   │ Session │ RBAC    │ TLS     │         │         │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Molecular    │ ■ T2    │ ■ T18   │ ■ T23   │ ■ T20   │ ■ T26   │ ■ T4    │ ●       │ ●       │ ●       │
 (module)    │ Channel │ CRM data│ Workflow│ Extract │ Email   │ SecIntl │         │         │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Cellular     │ ■ T28   │ ■ T29   │ ■ T32   │ ■ T30   │ ■ T10   │ ■ T3    │ ■ T35   │ ●       │ ●       │
 (component) │ Alarm   │ Timescl │ Dispatch│ Sites   │ AuditEng│ Defense │ Infer   │         │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Organic      │ ■ T36   │ ■ T48   │ ■ T55   │ ■ T56   │ ■ T57   │ ■ T5    │ ■ T37   │ ■ T59   │ ●       │
 (holon)     │ Cortex  │ KMS.AI  │ Cockpit │ SmartMet│ Copilot │ Guardian│ Evolve  │ TestEvo │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Social       │ ■ T38   │ ■ T50   │ ■ T63   │ ■ T39   │ ■ T21   │ ■ T7    │ ■ T43   │ ■ T44   │ ●       │
 (container) │ ZenohMsh│ Observe │ Deploy  │ Cluster │ JainProp│ Sentinel│ Swarm   │ ActiveI │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Ecosystem    │ ■ T41   │ ■ T53   │ ■ T64   │ ■ T40   │ ■ T65   │ ■ T8    │ ■ T69   │ ●       │ ●       │
 (node)      │ Distrib │ Integr  │ WaveExe │ Mesh    │ Coordin │ Pattern │ Video   │         │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Planetary    │ ●       │ ●       │ ●       │ ●       │ ●       │ ■ T77   │ ●       │ ■ T78   │ ●       │
 (cluster)   │         │         │         │         │         │ Quint   │         │ Agda    │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Stellar      │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │
 (federation)│         │         │         │         │         │         │         │         │         │
─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
Universal    │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │ ●       │ ■ Ω₀    │
 (universe)  │         │         │         │         │         │         │         │         │ Founder │
─────────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘

Legend: ■ = Covered by Sprint 54 task (TXX reference)
        ● = Not in Sprint 54 scope (deferred to Sprint 55+)
```

### 9x9 Diagonal Coverage

| Position | Level × Capability | Sprint 54 Task | Coverage |
|----------|-------------------|----------------|----------|
| (1,1) | Atomic × Signal | T1: SecurityPolicy authenticate | FULL |
| (2,2) | Molecular × Data | T18: CRM Forecasting data | FULL |
| (3,3) | Cellular × Control | T32: Dispatch routing | FULL |
| (4,4) | Organic × State | T56: SmartMetrics state | FULL |
| (5,5) | Social × Identity | T21: Jain Propagation discovery | FULL |
| (6,6) | Ecosystem × Trust | T8: PatternHunter threat | PARTIAL |
| (7,7) | Planetary × Adapt | — | DEFERRED |
| (8,8) | Stellar × Evolve | — | DEFERRED |
| (9,9) | Universal × Exist | Ω₀ Founder's Directive | IMMUTABLE |

**SC-9x9-001 Compliance**: 6/9 diagonal positions covered by Sprint 54 (67%).
Target for Sprint 55: 8/9 (89%).

---

## Level 10: Fractal Dependency DAG (Wave Execution Graph)

```
                    ┌──────────────────┐
                    │  Gemini Audit    │
                    │  (COMPLETE)      │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
    ┌─────────▼────────┐          ┌─────────▼────────┐
    │  W1 Safety+Sec   │          │  W2 Sprint 53    │
    │  (IN PROGRESS)   │          │  (IN PROGRESS)   │
    │  T1-T17          │          │  T18-T27         │
    └─────────┬────────┘          └─────────┬────────┘
              │                             │
              └──────────────┬──────────────┘
                             │ Gate: compile + quality
              ┌──────────────┴──────────────┐
              │                             │
    ┌─────────▼────────┐          ┌─────────▼────────┐
    │  W3 Alarms+Core  │          │  W6 Cockpit+CRM  │
    │  (PLANNED)       │          │  (PLANNED)       │
    │  T28-T34         │          │  T55-T62         │
    └─────────┬────────┘          └─────────┬────────┘
              │                             │
    ┌─────────▼────────┐          ┌─────────▼────────┐
    │  W4 Cyber+Mesh   │          │  W7 Deploy+Web   │
    │  (PLANNED)       │          │  (PLANNED)       │
    │  T35-T46         │          │  T63-T74         │
    └─────────┬────────┘          └─────────┬────────┘
              │                             │
    ┌─────────▼────────┐                    │
    │  W5 KMS+Obs+Int  │                    │
    │  (PLANNED)       │                    │
    │  T47-T54         │                    │
    └─────────┬────────┘                    │
              │                             │
              └──────────────┬──────────────┘
                             │
                   ┌─────────▼────────┐
                   │  W8 Utility+     │
                   │  Formal+Commit   │
                   │  (PLANNED)       │
                   │  T75-T84         │
                   └─────────┬────────┘
                             │
                   ┌─────────▼────────┐
                   │  COMMIT          │
                   │  T84             │
                   └──────────────────┘
```

### Critical Path Analysis

**Critical Path**: W1 → W3 → W4 → W5 → W8 → COMMIT
**Critical Path Length**: 6 gates, ~96 tasks
**Parallel Track**: W2 → W6 → W7 → W8 (joins at W8)
**Maximum Parallelism**: W3∥W6 and W4∥W7 execute concurrently

### Fractal Coherence Metrics (Expected Post-Sprint)

| Metric | Before S54 | After S54 (tests only) | After S54 (+ Gemini) | Target |
|--------|-----------|------------------------|----------------------|--------|
| L0-L1 Coverage | 63% | 100% | 100% | 100% |
| L2-L3 Coverage | 45% | 75% | 82% (+7pp Gemini) | 85% |
| L4-L5 Coverage | 30% | 50% | 58% (+8pp Gemini) | 60% |
| L6-L7 Coverage | 10% | 15% | 22% (+7pp Gemini) | 30% |
| TDG Compliance | 40% | 100% | 100% | 100% |
| FMEA Coverage | 60% | 85% | 92% (+7pp Gemini) | 90% |
| Formal Proofs | 12% | 20% | 20% | 40% |
| Graph Analysis | 15% | 25% | 25% | 50% |
| BDD Scenarios | 70% | 85% | 85% | 95% |
| F#↔Elixir Parity | 72% | 72% | 85% (+13pp Gemini) | 90% |
| Zenoh Wiring | 65% | 65% | 80% (+15pp Gemini) | 90% |
| **Overall Fractal Coherence** | **38%** | **62%** | **70%** (+8pp Gemini) | **75%** |

*Note: See Level 14 for detailed Gemini gap impact breakdown.*

---

## Level 11: Gemini 7-Layer Fractal Audit & F# Cognitive Plane Status

### 11.0 F# Cognitive Plane Assessment

**Source**: Gemini Cybernetic Architect audit, 2026-03-19
**Journal**: `docs/journal/20260319-1230-fractal-analysis-fsharp-system.md`

The F# track has successfully established itself as the **Cognitive Plane** — the cybernetic brain
of the Indrajaal biomorphic organism. Architecture is **100% synchronized at the specification level**
and **85% complete at the implementation level**. The remaining 15% consists of "Closing the Loop" —
wiring the sensors (telemetry) to the actuators (Ash actions) via the F# reasoning engine.

### 11.0.1 Gemini Remediation Actions Completed

| # | Action | Priority | Status | Details |
|---|--------|----------|--------|---------|
| 1 | **Identity Unification** | P0 | COMPLETE | 179 `intelitor/` → `indrajaal/` across 33 files + 12 locations in `fqun.ex` |
| 2 | **ADR Promotion** | P1 | COMPLETE | `ADR_001_FSHARP_CORTEX_SERVICE.md` PROPOSED → ACCEPTED/IMPLEMENTED |
| 3 | **Documentation Archival** | P1 | COMPLETE | `ASSP_TODOLIST_ARCHITECTURE.md` marked DEPRECATED (superseded by F# Planning) |
| 4 | **Physical Topology Sync** | P3 | COMPLETE | `MASTER_CONTAINER_ARCHITECTURE_20251222.md` Redis correctly identified as standalone |

### 11.0.2 Gemini Main System Gaps (Cognitive Plane "Closing the Loop")

| # | Gap Domain | Priority | Layer | Current State | Target State |
|---|-----------|----------|-------|---------------|--------------|
| 1 | **Telemetry Wiring** | P1 | L1-L2 | F# ConfigBridge/TricameralMonitor use hardcoded 0.0 values or TODO stubs | Real Zenoh NIF integration for sensor data |
| 2 | **Immune System Broadcast** | P2 | L3 | PlanningEnforcer violation telemetry uses `printfn` console stubs | Zenoh mesh-wide immune responses |
| 3 | **DNA Verification** | P0 | L5 | ForensicAuditTrail checks format only, uses SHA-256 not SHA3-256 | Real hash-chain verification + Reed-Solomon repair |
| 4 | **Integration Logic** | P2 | L1-L3 | Ash resource stubs in Integration/CRM lack business logic | F# decisions → real database mutations via Ash |
| 5 | **Apoptosis Parity** | P1 | L6 | F# uses 10s grace period vs Elixir 30-60s with jitter | Cross-language consensus during network partitions |

### 11.1 Gap Remediation Tasks (File-Level Detail)

The Gemini 7-Layer Fractal Analysis identified **17 specific gaps** across layers L1-L7
with exact file references. These gaps represent implementation quality issues where stubs, hardcoded
values, or parity mismatches exist in production code. Each gap is mapped to a remediation task.

### L1 Function Layer — ConfigBridge Zenoh Wiring

**Finding**: `lib/cepaf/src/Cepaf.Config/ConfigBridge.fs` — `publishConfig` and `subscribeToUpdates`
are file-write stubs with TODO comments instead of real Zenoh NIF calls via `ZenohFfiBridge.fs`.

| Task | Priority | File | Remediation | Lines |
|------|----------|------|-------------|-------|
| GR-L1-01 | P1 | `lib/cepaf/src/Cepaf.Config/ConfigBridge.fs` | Wire `publishConfig` to `ZenohFfiBridge.publish` | ~30 |
| GR-L1-02 | P1 | `lib/cepaf/src/Cepaf.Config/ConfigBridge.fs` | Wire `subscribeToUpdates` to `ZenohFfiBridge.subscribe` | ~30 |
| GR-L1-03 | P2 | `lib/cepaf/test/Cepaf.Tests/` | Add ConfigBridge Zenoh integration tests | ~80 |

**STAMP**: SC-ZENOH-001 (NIF loaded), SC-ZTEST-009 (F# publishes), SC-FFI-001 (LD_LIBRARY_PATH)
**FMEA**: RPN 96 — Config changes not propagated to mesh (S=8, O=4, D=3)

### L2 Component Layer — Telemetry Stub Values

**Finding**: `OodaSupervisor.fs` (lines 278-279) hardcodes `MemoryPressure=0.0`, `CpuUtilization=0.0`.
`SentinelBridge.fs` (line 80) hardcodes `RequestsPerSecond=0.0`. These prevent real telemetry from
reaching biomorphic scaling decisions.

| Task | Priority | File | Remediation | Lines |
|------|----------|------|-------------|-------|
| GR-L2-01 | P1 | `lib/cepaf/src/Cepaf/Mesh/OodaSupervisor.fs:278-279` | Wire `MemoryPressure` to `GC.GetGCMemoryInfo()` or Elixir bridge | ~20 |
| GR-L2-02 | P1 | `lib/cepaf/src/Cepaf/Mesh/OodaSupervisor.fs:278-279` | Wire `CpuUtilization` to `System.Diagnostics.Process` CPU time | ~20 |
| GR-L2-03 | P2 | `lib/cepaf/src/Cepaf/Mesh/SentinelBridge.fs:80` | Wire `RequestsPerSecond` to OTEL counter or ETS lookup | ~15 |
| GR-L2-04 | P2 | `lib/cepaf/test/Cepaf.Tests/` | Add telemetry value validation tests | ~60 |

**STAMP**: SC-BIO-001 (OODA <100ms), SC-MON-003 (domain metrics), SC-PROM-003 (dashboard liveness)
**FMEA**: RPN 108 — Biomorphic scaling uses zero-value inputs (S=9, O=4, D=3)

### L3 Holon Layer — PlanningEnforcer Zenoh Publish

**Finding**: `lib/cepaf/src/Cepaf.Planning/PlanningEnforcer.fs` (lines 376-382) uses `printfn` for
Zenoh telemetry instead of real publish. Real file-based audit logging works; Zenoh publish is stub.

| Task | Priority | File | Remediation | Lines |
|------|----------|------|-------------|-------|
| GR-L3-01 | P2 | `lib/cepaf/src/Cepaf.Planning/PlanningEnforcer.fs:376-382` | Wire `printfn` to `ZenohFfiBridge.publish` for `indrajaal/planning/events` | ~25 |
| GR-L3-02 | P3 | `lib/cepaf/test/Cepaf.Tests/` | Add PlanningEnforcer Zenoh publish test | ~40 |

**STAMP**: SC-PLAN-001 (F# Planning CLI authoritative), SC-ZTEST-009 (F# publishes), SC-SYNC-PLAN-011
**FMEA**: RPN 48 — Planning mutations not visible on Zenoh bus (S=4, O=4, D=3)

### L4 Container Layer — (No Critical Gaps)

No Gemini-identified gaps at L4. Container isolation, port bindings, and health checks are functional.
Compose files verified accurate for both prod-standalone (4 containers) and full-mesh (14 containers).

### L5 Node Layer — ForensicAuditTrail Hash Chain

**Finding**: `lib/indrajaal/compliance/forensic_audit_trail.ex` (lines 789-810):
`verify_custody_hash_chain/1` only checks format (64-char binary), not real SHA3-256 chain linking.
Uses SHA-256 instead of SHA3-256 per SC-REG-001.

| Task | Priority | File | Remediation | Lines |
|------|----------|------|-------------|-------|
| GR-L5-01 | P0 | `lib/indrajaal/compliance/forensic_audit_trail.ex:789-810` | Implement real SHA3-256 chain verification: `hash(block_n) == SHA3(content ∥ prev_hash)` | ~60 |
| GR-L5-02 | P1 | `lib/indrajaal/compliance/forensic_audit_trail.ex` | Replace SHA-256 calls with SHA3-256 (`:crypto.hash(:sha3_256, data)`) | ~20 |
| GR-L5-03 | P1 | `test/indrajaal/compliance/forensic_audit_trail_test.exs` | Add chain verification tests: valid chain, broken link, empty chain, tampered block | ~80 |

**STAMP**: SC-REG-001 (SHA3-256 blocks), SC-REG-005 (chain integrity), SC-SIL6-015 (immutable audit)
**FMEA**: RPN 168 — Chain verification bypass allows undetected tampering (S=8, O=3, D=7)

### L6 Cluster Layer — Apoptosis Grace Period Parity

**Finding**: Elixir `lib/indrajaal/deployment/apoptosis.ex` uses 30-60s grace with jitter.
F# `lib/cepaf/src/Cepaf/Mesh/Apoptosis.fs` uses 10s. Significant disagreement means F# and Elixir
will produce different behaviors during coordinated shutdown.

| Task | Priority | File | Remediation | Lines |
|------|----------|------|-------------|-------|
| GR-L6-01 | P1 | `lib/cepaf/src/Cepaf/Mesh/Apoptosis.fs` | Align grace period to 30-60s with jitter (match Elixir) | ~15 |
| GR-L6-02 | P2 | `lib/cepaf/test/Cepaf.Tests/` | Add Apoptosis parity test (verify F# and Elixir agree on timing) | ~40 |
| GR-L6-03 | P3 | `docs/architecture/HOLON_APOPTOSIS_PROTOCOL.md` | Document canonical grace period values | ~30 |

**STAMP**: SC-SIL6-015 (Apoptosis 6-phase), SC-EMR-057 (emergency stop <5s), SC-SIL6-002 (shutdown checkpoint)
**FMEA**: RPN 84 — Parity mismatch causes split-brain during coordinated shutdown (S=7, O=4, D=3)

### L7 Federation Layer — FQUN Legacy Cleanup (RESOLVED)

**Finding**: No remaining `intelitor/` in F# production source. Only in `obj/` build artifacts
(auto-generated, not checked in) and legacy `BaselineVerification.fsx` (test fixture).

| Task | Priority | File | Remediation | Lines |
|------|----------|------|-------------|-------|
| GR-L7-01 | P3 | `lib/cepaf/scripts/BaselineVerification.fsx` | Replace `intelitor/` with `indrajaal/` in test fixture | ~5 |

**STAMP**: SC-FQUN-001 (indrajaal/ prefix), SC-SYNC-DOC-001
**FMEA**: RPN 12 — Legacy test fixture only, no production impact (S=2, O=2, D=3)

### Gap Remediation Summary

| Layer | Gaps | P0 | P1 | P2 | P3 | Total Tasks | Est. Lines |
|-------|------|----|----|----|----|-------------|------------|
| L1 Function | 2 stubs | 0 | 2 | 1 | 0 | 3 | ~140 |
| L2 Component | 3 hardcoded | 0 | 2 | 2 | 0 | 4 | ~115 |
| L3 Holon | 1 stub | 0 | 0 | 1 | 1 | 2 | ~65 |
| L4 Container | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| L5 Node | 2 issues | 1 | 2 | 0 | 0 | 3 | ~160 |
| L6 Cluster | 1 parity | 0 | 1 | 1 | 1 | 3 | ~85 |
| L7 Federation | 1 legacy | 0 | 0 | 0 | 1 | 1 | ~5 |
| **Total** | **10** | **1** | **7** | **5** | **3** | **16** | **~570** |

### Gap Remediation Priority Execution Order

```
Round 1 (P0): GR-L5-01 — ForensicAuditTrail SHA3-256 chain (safety-critical)
Round 2 (P1): GR-L5-02, GR-L5-03, GR-L1-01, GR-L1-02, GR-L2-01, GR-L2-02, GR-L6-01
Round 3 (P2): GR-L2-03, GR-L2-04, GR-L1-03, GR-L3-01, GR-L6-02
Round 4 (P3): GR-L3-02, GR-L6-03, GR-L7-01
```

---

## Level 12: Comprehensive Artifact Inventory & 3D Coverage Matrix

### 12.1 Full Artifact Inventory (13 Types)

| # | Artifact Type | Count | Location Pattern | Description |
|---|---------------|-------|------------------|-------------|
| 1 | Elixir Source (.ex) | 1,284 | `lib/indrajaal/**/*.ex` | Production modules across 132 domains |
| 2 | Elixir Tests (.exs) | 1,004 | `test/**/*_test.exs` | ExUnit tests + property tests |
| 3 | Elixir Scripts (.exs) | 1,534 | `scripts/**/*.exs` | Testing (100+), Demo (56), SOPv511 (7), GA (14) |
| 4 | F# Source (.fs) | 652 | `lib/cepaf/src/**/*.fs` | 36 F# projects (Mesh, Planning, Cockpit, Zenoh, Cortex, Tests, etc.) |
| 5 | F# Tests (.fs) | 151 | `lib/cepaf/test/**/*.fs` | 1,513+ Expecto tests across 7+ test projects |
| 6 | F# Scripts (.fsx) | 69 | `lib/cepaf/scripts/**/*.fsx` | Orchestrators, validators, evaluators |
| 7 | Agda Proofs (.agda) | 24 | `docs/formal_specs/**/*.agda` | Dependent type proofs (18 holes remaining) |
| 8 | Quint Models (.qnt) | 33 | `quint/**/*.qnt` | Temporal logic models (~23 active constraints) |
| 9 | BDD Features (.feature) | 85 | `test/features/**/*.feature` | Gherkin scenarios across 20+ categories |
| 10 | Architecture Docs (.md) | 213 | `docs/architecture/**/*.md` | System design, ADRs, specifications |
| 11 | STAMP Rules (.md) | 22 | `.claude/rules/**/*.md` | Safety constraint rule files |
| 12 | Deployment Configs | 19 | `lib/cepaf/artifacts/**/*.yml` | Podman compose, Kubernetes, NixOS |
| 13 | Rust Crates (.rs) | 8 | `native/**/*.rs` | zenoh_nif (Elixir), zenoh_ffi (F#), lineage_auth |

### 12.2 Artifact × Artifact Interaction Matrix

Shows which artifact types directly reference/depend on other artifact types.

```
              │ Ex.Src │ Ex.Tst │ Ex.Scr │ F#.Src │ F#.Tst │ F#.Scr │ Agda   │ Quint  │ BDD    │ Docs   │ Rules  │ Deploy │ Rust   │
──────────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
Elixir Source │  DEP   │  SUT   │  LIB   │  BRIDGE│   —    │   —    │  SPEC  │  SPEC  │   —    │  DOC   │  CNSTR │  CFG   │  NIF   │
Elixir Tests  │  TEST  │  DEP   │   —    │   —    │   —    │   —    │   —    │   —    │  IMPL  │   —    │   —    │   —    │   —    │
Elixir Scripts│  CALL  │   —    │  DEP   │   —    │   —    │   —    │   —    │   —    │   —    │   —    │   —    │   —    │   —    │
F# Source     │ BRIDGE │   —    │   —    │  DEP   │  SUT   │  LIB   │  SPEC  │  SPEC  │   —    │  DOC   │  CNSTR │  CFG   │  FFI   │
F# Tests      │   —    │   —    │   —    │  TEST  │  DEP   │   —    │   —    │   —    │   —    │   —    │   —    │   —    │   —    │
F# Scripts    │   —    │   —    │   —    │  CALL  │   —    │  DEP   │   —    │   —    │   —    │   —    │   —    │  CFG   │   —    │
Agda Proofs   │  PROOF │   —    │   —    │  PROOF │   —    │   —    │  DEP   │   —    │   —    │  DOC   │   —    │   —    │   —    │
Quint Models  │  MODEL │   —    │   —    │  MODEL │   —    │   —    │   —    │  DEP   │   —    │  DOC   │   —    │   —    │   —    │
BDD Features  │   —    │  STEP  │   —    │   —    │   —    │   —    │   —    │   —    │  DEP   │   —    │   —    │   —    │   —    │
Arch Docs     │  REF   │   —    │   —    │  REF   │   —    │   —    │  REF   │  REF   │   —    │  DEP   │  REF   │  REF   │  REF   │
STAMP Rules   │ GOVERN │   —    │   —    │ GOVERN │   —    │   —    │   —    │ GOVERN │   —    │ GOVERN │  DEP   │ GOVERN │ GOVERN │
Deploy Configs│  CFG   │   —    │   —    │  CFG   │   —    │   —    │   —    │   —    │   —    │  REF   │   —    │  DEP   │  CFG   │
Rust Crates   │  NIF   │   —    │   —    │  FFI   │   —    │   —    │   —    │   —    │   —    │  DOC   │   —    │   —    │  DEP   │
──────────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┘

Legend: DEP=self-dependency, SUT=system-under-test, TEST=tests-for, BRIDGE=cross-runtime bridge,
        NIF=Rustler NIF, FFI=cdylib FFI, SPEC=formal specification of, MODEL=temporal model of,
        PROOF=dependent type proof of, STEP=step definitions, LIB=library usage, CALL=script invocation,
        DOC=documents, REF=references, CNSTR=constrains, GOVERN=governs, CFG=configures
```

### 12.3 Artifact × Fractal Layer Coverage Matrix (13×8)

Shows which artifact types have active presence at each fractal layer.

```
              │ L0 Runtime │ L1 Function │ L2 Component │ L3 Holon   │ L4 Container │ L5 Node    │ L6 Cluster │ L7 Federation │
──────────────┼────────────┼─────────────┼──────────────┼────────────┼──────────────┼────────────┼────────────┼───────────────┤
Elixir Source │ ■ compile  │ ■ 1,284 fns │ ■ 80 domains │ ■ 50 agents│ ■ app ctnr   │ ■ BEAM vm  │ ■ Sentinel │ ■ Jain prop   │
Elixir Tests  │ ■ MIX_ENV  │ ■ 1,004 fls │ ■ domain tst │ ■ agent tst│ ■ sandbox    │ ■ ETS test │ ○ partial  │ ○ basic       │
Elixir Scripts│ ■ mix run  │ ■ script API│ ■ demo scrs  │ ■ orchestr │ ■ container  │ ■ node cfg │ ○ mesh tst │ ○ N/A         │
F# Source     │ ■ dotnet   │ ■ 560 files │ ■ 24 projs   │ ■ DigiTwin │ ■ podman ctl │ ■ Zenoh    │ ■ mesh CLI │ ■ federation  │
F# Tests      │ ■ dotnet   │ ■ 62 files  │ ■ unit tests │ ■ mesh tst │ ○ limited    │ ○ FFI only │ ○ basic    │ ○ N/A         │
F# Scripts    │ ■ dotnet   │ ■ 69 scripts│ ■ orchestr   │ ■ SIL6Orch │ ■ compose    │ ■ boot seq │ ○ control  │ ○ N/A         │
Agda Proofs   │ ○ N/A      │ ■ type safe │ ■ invariants │ ■ holon pf │ ○ N/A        │ ○ N/A      │ ○ N/A      │ ○ N/A         │
Quint Models  │ ○ N/A      │ ■ I/O specs │ ■ protocol   │ ■ state mc │ ○ N/A        │ ○ N/A      │ ■ consensus│ ○ N/A         │
BDD Features  │ ○ N/A      │ ■ scenarios │ ■ domain     │ ■ agent    │ ■ container  │ ○ limited  │ ○ N/A      │ ○ N/A         │
Arch Docs     │ ■ setup    │ ■ API docs  │ ■ design     │ ■ holon    │ ■ deploy     │ ■ ops      │ ■ cluster  │ ■ federation  │
STAMP Rules   │ ■ func inv │ ■ ash rules │ ■ domain     │ ■ agent    │ ■ container  │ ■ zenoh    │ ■ mesh     │ ■ frac gov    │
Deploy Configs│ ■ devenv   │ ○ N/A       │ ○ N/A        │ ○ N/A      │ ■ compose    │ ■ nix cfg  │ ■ mesh yml │ ■ fed cfg     │
Rust Crates   │ ■ cargo    │ ■ NIF/FFI   │ ■ lib iface  │ ○ N/A      │ ○ N/A        │ ■ .so      │ ○ N/A      │ ○ N/A         │
──────────────┴────────────┴─────────────┴──────────────┴────────────┴──────────────┴────────────┴────────────┴───────────────┘

Legend: ■ = Active presence with artifacts  ○ = Limited/no presence (gap)
```

### 12.4 Layer Coverage Density by Artifact Type

| Layer | ■ Active | ○ Gap | Coverage % | Gap Artifact Types |
|-------|----------|-------|------------|-------------------|
| L0 Runtime | 10 | 3 | 77% | Agda, Quint, BDD (N/A at runtime) |
| L1 Function | 12 | 1 | 92% | Deploy configs |
| L2 Component | 12 | 1 | 92% | Deploy configs |
| L3 Holon | 11 | 2 | 85% | Rust, Deploy configs |
| L4 Container | 8 | 5 | 62% | F# Tests, Agda, Quint, Rust gaps |
| L5 Node | 8 | 5 | 62% | F# Tests, Agda, BDD, Quint limited |
| L6 Cluster | 5 | 8 | 38% | Multiple types lack cluster coverage |
| L7 Federation | 4 | 9 | 31% | Only F# Source, Arch Docs, STAMP, Deploy |

### 12.5 3D Cross-Product: Domain × Verification × Layer (Selected Critical Paths)

#### Safety-Critical Path (Guardian → Sentinel → Immune)

```
Domain: Safety (5 modules, 2,872 lines)
×
Verification: [TDG, FMEA, Agda, Quint, Graph, BDD]
×
Layer: [L0..L7]

                │ TDG          │ FMEA         │ Agda         │ Quint        │ Graph        │ BDD          │
────────────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
L0 Runtime      │ ■ compile    │ ■ boot fail  │ ○            │ ○            │ ○            │ ○            │
L1 Function     │ ■ 45 tests   │ ■ auth bypass│ ■ types      │ ■ I/O        │ ■ auth flow  │ ■ scenarios  │
L2 Component    │ ■ cross-mod  │ ■ state leak │ ■ invariants │ ■ protocol   │ ■ call graph │ ■ integration│
L3 Holon        │ ■ Guardian   │ ■ agent crash│ ■ proofs     │ ■ state mch  │ ■ sup tree   │ ■ guardian   │
L4 Container    │ ■ sandbox    │ ■ isolation  │ ○            │ ○            │ ○            │ ■ container  │
L5 Node         │ ■ ETS state  │ ■ OOM        │ ○            │ ○            │ ○            │ ○            │
L6 Cluster      │ ○ Sentinel   │ ■ split-brain│ ○            │ ■ consensus  │ ○            │ ○            │
L7 Federation   │ ○            │ ○            │ ○            │ ○            │ ○            │ ○            │
```

#### Mesh/Distributed Path (Zenoh → Cluster → Federation)

```
Domain: Mesh+Distributed (47 modules, 16,125 lines)
×
Verification: [TDG, FMEA, Agda, Quint, Graph, BDD]
×
Layer: [L0..L7]

                │ TDG          │ FMEA         │ Agda         │ Quint        │ Graph        │ BDD          │
────────────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
L0 Runtime      │ ■ compile    │ ■ NIF crash  │ ○            │ ○            │ ○            │ ○            │
L1 Function     │ ■ API tests  │ ■ inference  │ ○            │ ○            │ ■ mesh paths │ ■ AI flows   │
L2 Component    │ ■ domain     │ ■ integration│ ○            │ ○            │ ■ neural     │ ■ cortex     │
L3 Holon        │ ■ DigiTwin   │ ■ AI rogue   │ ○            │ ■ state mch  │ ■ OODA loop  │ ■ agent      │
L4 Container    │ ■ NIF load   │ ■ resource   │ ○            │ ○            │ ○            │ ○            │
L5 Node         │ ■ Zenoh NIF  │ ■ latency    │ ○            │ ○            │ ○            │ ○            │
L6 Cluster      │ ■ mesh qrm   │ ■ consensus  │ ○            │ ■ quorum     │ ■ mesh topo  │ ○            │
L7 Federation   │ ○ cross-hol  │ ○            │ ○            │ ○            │ ○            │ ○            │
```

#### KMS/Knowledge Path (SQLite → DuckDB → Holon State)

```
Domain: KMS (40 modules, 13,773 lines)
×
Verification: [TDG, FMEA, Agda, Quint, Graph, BDD]
×
Layer: [L0..L7]

                │ TDG          │ FMEA         │ Agda         │ Quint        │ Graph        │ BDD          │
────────────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
L0 Runtime      │ ■ compile    │ ■ DB corrupt │ ○            │ ○            │ ○            │ ○            │
L1 Function     │ ■ API tests  │ ■ query fail │ ○            │ ○            │ ■ query path │ ■ KMS flows  │
L2 Component    │ ■ domain     │ ■ state drift│ ○            │ ○            │ ■ KMS graph  │ ■ OTEL       │
L3 Holon        │ ■ holon      │ ■ regen fail │ ■ integrity  │ ■ state mch  │ ■ holon FSM  │ ■ knowledge  │
L4 Container    │ ■ SQLite WAL │ ■ isolation  │ ○            │ ○            │ ○            │ ○            │
L5 Node         │ ■ DuckDB     │ ■ OLAP fail  │ ○            │ ○            │ ○            │ ○            │
L6 Cluster      │ ○            │ ○            │ ○            │ ○            │ ○            │ ○            │
L7 Federation   │ ○            │ ○            │ ○            │ ○            │ ○            │ ○            │
```

---

## Level 13: Updated FMEA with Gemini-Identified Risks

### Additional Failure Modes from Gemini Audit

| ID | Failure Mode | S | O | D | RPN | Layer | Mitigation | Task |
|----|-------------|---|---|---|-----|-------|------------|------|
| FM-GEM-01 | ForensicAuditTrail hash chain bypass | 8 | 3 | 7 | 168 | L5 | Implement real SHA3-256 chain verification | GR-L5-01 |
| FM-GEM-02 | Biomorphic scaling uses 0.0 telemetry | 9 | 4 | 3 | 108 | L2 | Wire real memory/CPU metrics | GR-L2-01,02 |
| FM-GEM-03 | ConfigBridge Zenoh publish is file-write stub | 8 | 4 | 3 | 96 | L1 | Wire to ZenohFfiBridge.publish | GR-L1-01,02 |
| FM-GEM-04 | Apoptosis grace period F#/Elixir mismatch | 7 | 4 | 3 | 84 | L6 | Align F# to 30-60s with jitter | GR-L6-01 |
| FM-GEM-05 | PlanningEnforcer Zenoh is printfn stub | 4 | 4 | 3 | 48 | L3 | Wire to ZenohFfiBridge.publish | GR-L3-01 |
| FM-GEM-06 | SentinelBridge RequestsPerSecond=0.0 | 6 | 5 | 3 | 90 | L2 | Wire to OTEL counter | GR-L2-03 |

### Combined FMEA Risk Register (Sorted by RPN)

| Rank | ID | RPN | Category | Layer | Status |
|------|----|-----|----------|-------|--------|
| 1 | FM-GEM-01 | 168 | Hash chain bypass | L5 | OPEN (P0) |
| 2 | FM-54-14 | 120 | Side effects in tests | L1 | MITIGATED |
| 3 | FM-GEM-02 | 108 | Zero telemetry values | L2 | OPEN (P1) |
| 4 | FM-54-02 | 96 | SymbioticDefense crash | L3 | MITIGATED |
| 5 | FM-GEM-03 | 96 | ConfigBridge stub | L1 | OPEN (P1) |
| 6 | FM-GEM-06 | 90 | SentinelBridge RPS=0 | L2 | OPEN (P2) |
| 7 | FM-GEM-04 | 84 | Apoptosis parity | L6 | OPEN (P1) |
| 8 | FM-54-01 | 81 | Auth bypass | L1 | MITIGATED |
| 9 | FM-54-11 | 80 | False positive tests | L1 | MITIGATED |
| 10 | FM-GEM-05 | 48 | Planning Zenoh stub | L3 | OPEN (P2) |

### Post-Remediation RPN Targets

| ID | Current RPN | Target RPN | Reduction | Confidence |
|----|-------------|------------|-----------|------------|
| FM-GEM-01 | 168 | 24 | −86% | HIGH — clear implementation path |
| FM-GEM-02 | 108 | 18 | −83% | HIGH — standard .NET APIs |
| FM-GEM-03 | 96 | 16 | −83% | HIGH — ZenohFfiBridge exists |
| FM-GEM-06 | 90 | 15 | −83% | MEDIUM — requires OTEL wiring |
| FM-GEM-04 | 84 | 12 | −86% | HIGH — simple constant change |
| FM-GEM-05 | 48 | 8 | −83% | HIGH — ZenohFfiBridge exists |

---

## Level 14: Updated Fractal Coherence Metrics (with Gemini Gaps)

### Coherence Before/After Gemini Gap Remediation

| Metric | Pre-S54 | Post-S54 (no Gemini) | Post-S54 (with Gemini) | Target |
|--------|---------|----------------------|------------------------|--------|
| L0-L1 Coverage | 63% | 100% | 100% | 100% |
| L2-L3 Coverage | 45% | 75% | 82% | 85% |
| L4-L5 Coverage | 30% | 50% | 58% | 60% |
| L6-L7 Coverage | 10% | 15% | 22% | 30% |
| TDG Compliance | 40% | 100% | 100% | 100% |
| FMEA Coverage | 60% | 85% | 92% | 90% |
| Formal Proofs | 12% | 20% | 20% | 40% |
| Graph Analysis | 15% | 25% | 25% | 50% |
| BDD Scenarios | 70% | 85% | 85% | 95% |
| F#↔Elixir Parity | 72% | 72% | 85% | 90% |
| Zenoh Wiring | 65% | 65% | 80% | 90% |
| Hash Chain Integrity | 40% | 40% | 90% | 95% |
| **Overall Fractal Coherence** | **38%** | **62%** | **70%** | **75%** |

### Layer-by-Layer Coherence Delta (Gemini Contribution)

| Layer | Without Gemini | With Gemini | Delta | Key Gemini Task |
|-------|---------------|-------------|-------|-----------------|
| L0 | 100% | 100% | 0pp | — |
| L1 | 94% | 97% | +3pp | GR-L1-01,02: ConfigBridge Zenoh |
| L2 | 81% | 88% | +7pp | GR-L2-01,02,03: Telemetry wiring |
| L3 | 69% | 73% | +4pp | GR-L3-01: PlanningEnforcer Zenoh |
| L4 | 56% | 56% | 0pp | No gaps at L4 |
| L5 | 44% | 55% | +11pp | GR-L5-01,02: SHA3-256 chain |
| L6 | 19% | 26% | +7pp | GR-L6-01: Apoptosis parity |
| L7 | 6% | 7% | +1pp | GR-L7-01: FQUN cleanup |

### Cross-Runtime Parity Breakdown (F# ↔ Elixir)

| Component | Elixir | F# | Parity | Gap | Gemini Task |
|-----------|--------|----|---------| ----|-------------|
| Apoptosis grace period | 30-60s + jitter | 10s fixed | MISMATCH | 20-50s | GR-L6-01 |
| Config publish | Phoenix.PubSub | File-write stub | MISMATCH | No Zenoh | GR-L1-01,02 |
| OODA telemetry | Real OTEL events | 0.0 hardcoded | MISMATCH | No data | GR-L2-01,02 |
| Planning publish | N/A (F# only) | printfn stub | STUB | No Zenoh | GR-L3-01 |
| Sentinel metrics | Real via Sentinel | RPS=0.0 stub | MISMATCH | No bridge | GR-L2-03 |
| Zenoh FFI | NIF (production) | FFI (production) | MATCH | — | — |
| Hash chain | SHA-256 | N/A | WRONG ALGO | Need SHA3 | GR-L5-01,02 |
| Digital Twin | Elixir struct | F# DU type | MATCH | — | — |
| MathMonitor | N/A (F# only) | Production | N/A | — | — |

---

## Level 15: Ash Resource & CRM Automation Stub Backlog

### 15.1 Structural Ash Stubs (Code Interface Commented Out)

These modules have `use Indrajaal.BaseResource` but code interfaces are commented out,
blocking programmatic API access. These are the actuators that F# decisions need to drive.

| # | Module | File | Lines | Status | Missing Logic |
|---|--------|------|-------|--------|---------------|
| 1 | `Indrajaal.Integration.Enterprise.RateLimit` | `lib/indrajaal/integration/enterprise_gateway/rate_limit.ex` | 59 | Code interface commented out | Rate limit enforcement, throttling, time windows |
| 2 | `Indrajaal.Integration.Enterprise.Route` | `lib/indrajaal/integration/enterprise_gateway/route.ex` | 56 | Code interface commented out | Route matching, path rules, backend selection, header forwarding |

**Priority**: P0 — Blocks F# Cognitive Plane from driving integration actions
**STAMP**: SC-EP048-001 (no scaffold stubs), SC-ASH-001 (BaseResource pattern)

### 15.2 CRM Automation Partial Implementations (TODO Placeholders)

These modules have real structure but contain hardcoded placeholder returns instead of
database queries or external service calls.

| # | Module | File | Lines | TODOs | Missing Logic |
|---|--------|------|-------|-------|---------------|
| 3 | `Indrajaal.Crm.Automation.LeadAssignment` | `lib/indrajaal/crm/automation/lead_assignment.ex` | 256 | 4 | `get_team_members/1`, `get_territory_owner/1`, `get_skilled_reps/2`, `get_team_workloads/1` — all return hardcoded data |
| 4 | `Indrajaal.Crm.Automation.Workflow` | `lib/indrajaal/crm/automation/workflow.ex` | 360 | 5 | `execute_action/2` for email/task/flow/outbound/webhook — all log but don't execute |
| 5 | `Indrajaal.Crm.Automation.Approval` | `lib/indrajaal/crm/automation/approval.ex` | 475 | 6 | `recall/2`, `check_and_escalate_timeouts/0`, `get_approval_process/1`, notification delivery |
| 6 | `Indrajaal.Crm.Notifiers.WorkflowNotifier` | `lib/indrajaal/crm/notifiers/workflow_notifier.ex` | 234 | 1 | `update_record_owner/2` logs telemetry but doesn't persist via Ash |

**Priority**: P1-P2 — Integration logic needed for F# Cognitive Plane "actuators"
**STAMP**: SC-AUTO-001 (CRM automation), SC-DB-001 (BaseResource)

### 15.3 Cognitive Plane Loop Completion Matrix

Shows the sensor→reasoning→actuator loop for each gap:

```
                  SENSOR (Telemetry)           REASONING (F#)              ACTUATOR (Ash)
                  ─────────────────           ──────────────              ──────────────
Gap 1 (L1-L2):   Zenoh metrics ──────────→ TricameralMonitor ─────→ [BLOCKED: hardcoded 0.0]
Gap 2 (L3):      PlanningEnforcer ────────→ Violation detection ──→ [BLOCKED: printfn stub]
Gap 3 (L5):      ImmutableRegister ───────→ Chain verification ───→ [BLOCKED: format-only check]
Gap 4 (Ash):     CRM events ─────────────→ Workflow/Approval ────→ [BLOCKED: TODO placeholders]
Gap 5 (L6):      Apoptosis signal ────────→ HealthCoordinator ───→ [BLOCKED: 10s vs 30-60s]
```

### 15.4 Remediation Priority (Ash Stubs)

```
Round 1 (P0): Uncomment Route + RateLimit code interfaces, add basic validators
Round 2 (P1): Wire LeadAssignment get_team_members/1 to Ash read (Teams resource)
              Wire Workflow execute_action/2 :email_alert to Communication.send_email/1
              Wire Approval get_approval_process/1 to ApprovalProcess resource
Round 3 (P2): Wire remaining Workflow actions (task, flow, outbound, webhook)
              Wire Approval recall/2 and check_and_escalate_timeouts/0 to DB
              Wire WorkflowNotifier update_record_owner/2 to Ash changeset
Round 4 (P3): Wire LeadAssignment territory/skills queries to real DB
              Full integration tests for CRM automation loop
```

### 15.5 FMEA for Ash Stub Gaps

| ID | Failure Mode | S | O | D | RPN | Mitigation |
|----|-------------|---|---|---|-----|------------|
| FM-ASH-01 | Route code interface commented → API unusable | 7 | 5 | 2 | 70 | Uncomment + add validators |
| FM-ASH-02 | LeadAssignment returns hardcoded teams | 5 | 4 | 3 | 60 | Wire to Ash read |
| FM-ASH-03 | Workflow email action logs but doesn't send | 6 | 5 | 3 | 90 | Wire to Communication module |
| FM-ASH-04 | Approval process returns mock config | 6 | 4 | 4 | 96 | Wire to ApprovalProcess resource |
| FM-ASH-05 | Workflow webhook/outbound not implemented | 5 | 3 | 4 | 60 | Implement HTTP client calls |

---

## Level 16: Comprehensive System Audit (Full-Codebase Reconciliation)

A comprehensive audit of the entire codebase was performed to validate the plan's scope,
counts, and coverage against actual filesystem state. This audit corrects several
underestimates and identifies gaps not captured in prior levels.

### 16.1 Corrected System Metrics

| Metric | Plan States | Actual Measured | Delta | Note |
|--------|-------------|-----------------|-------|------|
| Elixir source (.ex) | 1,284 | 1,284 | 0 | Accurate |
| Elixir tests (.exs) | 1,004 | 1,004 | 0 | Accurate |
| Elixir scripts (.exs) | 1,534 | 1,534 | 0 | Accurate |
| F# source (.fs) | 560 | 560 | 0 | **Corrected in Level 17 → 652** |
| F# test files (.fs) | 62 | 62 | 0 | **Corrected in Level 17 → 151** |
| F# projects (.fsproj) | 24 | 28 | +4 | **Corrected in Level 17 → 36** |
| Script directories | ~20 | 91 | +71 | `scripts/` has 87 subdirs + `lib/cepaf/scripts/` |
| Production domains | 80+ | 132 | +52 | Counted via `lib/indrajaal/*/` directory listing |
| STAMP constraint families | 54 | 62+ | +8 | Missing: SC-PROM, SC-NEURO, SC-PRIME, SC-9x9, SC-UIP, SC-TODO, SC-NET, SC-COCKPIT |
| AOR rule families | ~40 | 51+ | +11 | Missing: AOR-PROM, AOR-RECONFIG, AOR-SYNC, AOR-DBNAME, AOR-DBLOCAL, AOR-DBCROSS, AOR-NET, etc. |
| Zenoh F# modules | unspecified | 21 | — | `lib/cepaf/src/Cepaf/Zenoh/**/*.fs` |
| Zenoh Elixir modules | unspecified | 1 | — | `lib/indrajaal/mesh/zenoh_telemetry_subscriber.ex` |
| Rust crates | 8 | 8 | 0 | 3 crate roots: zenoh_nif, zenoh_ffi, lineage_auth |

### 16.2 Domain Count Reconciliation (132 Actual Domains)

The plan refers to "80+ domains" but the actual `lib/indrajaal/` directory contains **132 unique
top-level domain directories**. This means W8 "169 utility modules" likely includes modules from
~50 domains not explicitly assigned to W1-W7.

**Domains covered in W1-W7** (~80 domains):
Safety, Security, Alarms, Devices, Sites, Dispatch, Maintenance, CRM (7 sub-domains),
Integration, KMS, Observability, Cockpit, Testing, Deployment, Distributed, Video,
Billing, Identity, Cybernetic, AI/Cortex, Mesh, Compliance, Communication, etc.

**Domains NOT explicitly assigned** (~52 domains — absorbed into W8):
Access Control resources, Accounts resources, Analytics sub-modules, Authorization policies,
Cluster coordination, Coordination protocols, FLAME workers, Knowledge engine sub-modules,
Policy framework, Validation sub-modules, and various utility namespaces.

**Impact**: W8 "169 utility modules" should be decomposed into sub-waves:
- W8a: Domain-specific modules from unassigned domains (~80 modules)
- W8b: True cross-cutting utilities (helpers, config, extensions) (~50 modules)
- W8c: Formal verification + commit (~39 modules)

### 16.3 Missing STAMP Constraint Families

The plan's STAMP compliance matrix references ~54 families. The following families from
CLAUDE.md are not explicitly referenced in the test coverage plan:

| Family | Source | Severity | Coverage Gap |
|--------|--------|----------|-------------|
| SC-PROM-001 to SC-PROM-007 | §91.0 PROMETHEUS | CRITICAL | Proof tokens, API redlines, DAG acyclicity — no test coverage planned |
| SC-NEURO-001 to SC-NEURO-003 | §100.0 Neuro-Symbolic | CRITICAL | Simplex principle (Guardian validates AI), resource bounding, forbidden ops |
| SC-PRIME-001 to SC-PRIME-003 | §94.0 Prime Directives | INFINITE | Will to Live, Recursion Lock, Xenobiology — existential safety untested |
| SC-9x9-001 | §104.0 9x9 Matrix | HIGH | Critical features must cover diagonal — not verified |
| SC-UIP-* | §15.0 UIP Governance | HIGH | Bicameral Verification Cycle not tested |
| SC-COCKPIT-* | §106.0 F# Cockpit | HIGH | Dual-interface (GUI+TUI) architecture constraints |
| SC-TODO-001 to SC-TODO-008 | §16.0 Todolist | CRITICAL | Access control enforcement (hooks exist but no test coverage) |
| SC-NET-001 to SC-NET-002 | §13.0 Language Policy | HIGH | net10.0 target framework enforcement |

**Recommended additions**:
- **S54-T85**: PROMETHEUS verification test suite (SC-PROM-001 through SC-PROM-007) — ~120 lines
- **S54-T86**: Neuro-Symbolic Simplex tests (SC-NEURO-001 through SC-NEURO-003) — ~80 lines
- **S54-T87**: Prime Directive invariant tests (SC-PRIME-001 through SC-PRIME-003) — ~60 lines

### 16.4 Guardian ↔ Constitutional Integration Gap

The Guardian safety kernel is split across two runtimes with incomplete integration:

| Component | Runtime | Location | Status |
|-----------|---------|----------|--------|
| Guardian (Elixir) | BEAM | `lib/indrajaal/safety/guardian.ex` | Production — validate_proposal/1 |
| ConstitutionalChecker (F#) | .NET | `lib/cepaf/src/Cepaf/Mesh/ConstitutionalChecker.fs` | Production — 5 invariants |
| Guardian (F#) | .NET | `lib/cepaf/src/Cepaf/Mesh/Guardian.fs` | Parallel implementation |
| Constitution (Elixir) | BEAM | `lib/indrajaal/safety/constitution.ex` | Ψ₀-Ψ₅ definitions |

**Gap**: No integration test verifies that F# `ConstitutionalChecker` and Elixir `Guardian` produce
identical verdicts for the same proposal. If these disagree during a reconfiguration, the system
violates SC-CONST-001 (constitutional check before reconfiguration).

**Recommended**: Add S54-T88: Guardian↔ConstitutionalChecker parity test (Zenoh message roundtrip) — ~100 lines

### 16.5 Zenoh Elixir/F# Asymmetry

The F# Zenoh implementation is significantly more mature than Elixir:

| Aspect | F# | Elixir | Gap |
|--------|-----|--------|-----|
| Zenoh modules | 21 (.fs files in Cepaf/Zenoh/) | 1 (zenoh_telemetry_subscriber.ex) | 20x asymmetry |
| FFI bridge | ZenohFfiBridge.fs (13 functions, 480 lines) | zenoh_nif (Rustler NIF) | Different mechanisms |
| Topics published | ~15 topic patterns | ~3 topic patterns | 5x asymmetry |
| Test coverage | 31 FFI tests + mesh tests | NIF smoke tests only | F# significantly ahead |

**Impact on plan**: W4 (Cybernetic + AI + Mesh) should include explicit Elixir Zenoh module
expansion tasks, not just test generation for the existing single module. The plan currently
treats Zenoh as "covered" when Elixir has only a subscriber, not publishers.

**Recommended**: Add Zenoh Elixir publisher tasks to W4 or defer to Sprint 55.

### 16.6 F# Test Explicit Coverage

The 8-Wave architecture covers Elixir test generation exhaustively but does not explicitly
schedule F# test expansion. Current F# test state:

| F# Test Area | Tests | Status | Plan Coverage |
|-------------|-------|--------|---------------|
| ZenohFfiBridge | 31 | Passing | Not in plan (already complete) |
| MathematicalSystemMonitor | 49 | Passing | Referenced in W8 (RPN fix) |
| Mesh/DigitalTwin | ~50 | Passing | Not explicitly in plan |
| Planning | ~30 | Passing | Not explicitly in plan |
| Cockpit | ~20 | Passing | Not explicitly in plan |
| Other unit tests | ~370 | Passing | Not explicitly in plan |

**Total F# tests**: 549+ across 62 test files. These are NOT included in the "577 untested modules"
count (which is Elixir-only). The plan should explicitly note that F# test coverage is tracked
separately and is already at ~80% coverage.

### 16.7 W8 Decomposition (174 → 3 Sub-Waves)

The original W8 bundles 174 items (169 utility modules + Quint/Agda/F#/TODO). This is too
large for a single wave and masks the actual domain distribution.

**Proposed W8 Decomposition**:

| Sub-Wave | Scope | Files | Priority | Description |
|----------|-------|-------|----------|-------------|
| W8a | Unassigned domain modules | ~80 | P3 | Modules from ~52 domains not in W1-W7 (access_control resources, accounts detail, analytics sub, authorization policies, cluster coordination, coordination protocols, FLAME workers, knowledge sub, policy, validation) |
| W8b | Cross-cutting utilities | ~50 | P3 | Helpers, config adapters, Phoenix plugs, Ecto types, formatting, encoding, telemetry wrappers |
| W8c | Formal verification + commit | ~39 | P2-P3 | 11 Quint constraints, 6 Agda holes, F# RPN fix, TODO remediation, quality gate pass |
| W8d | Integration tests | ~5 | P2 | Cross-wave integration scenarios (Safety↔CRM, Mesh↔KMS, Cockpit↔Guardian) |

### 16.8 Cross-Layer Gap Summary

| Gap | Layer | Severity | In Plan? | Resolution |
|-----|-------|----------|----------|------------|
| PROMETHEUS proof tokens untested | L0-L3 | CRITICAL | NO | Add S54-T85 |
| Prime Directive invariants untested | L0 | INFINITE | NO | Add S54-T87 |
| Neuro-Symbolic Simplex untested | L2-L3 | CRITICAL | NO | Add S54-T86 |
| Guardian↔ConstitutionalChecker parity | L3-L6 | CRITICAL | NO | Add S54-T88 |
| Zenoh Elixir publisher gap | L4-L6 | HIGH | Partial (W4) | Expand W4 scope |
| F# test coverage tracking | All | MEDIUM | NO | Add note to W8c |
| W8 too large (174 items) | All | MEDIUM | YES (but monolithic) | Decompose W8a-W8d |
| 52 domains not assigned to waves | L2-L3 | HIGH | Implicit in W8 | Make explicit in W8a |
| SC-TODO access control testing | L1-L3 | HIGH | NO | Add to W6 (Testing Infra) |

### 16.9 Updated Scope Metrics (Post-Audit)

| Metric | Pre-Audit | Post-Audit | Note |
|--------|-----------|------------|------|
| Total waves | 8 | 8 (W8 → 4 sub-waves) | W8 decomposed |
| Total task groups | 84+4 | 84+4+4 = 92 | +4 new tasks (T85-T88) |
| Domains covered | 80+ | 132 (all) | Full domain coverage |
| SC families tested | 54 | 62+ | +8 families added |
| AOR families tested | ~40 | 51+ | +11 families acknowledged |
| F# test tracking | Implicit | Explicit | 549+ tests tracked |
| Cross-runtime parity tests | 0 | 1 (T88) | Guardian↔Constitutional |
| Est. additional lines | 0 | +360 | T85 (120) + T86 (80) + T87 (60) + T88 (100) |

---

## Level 17: Deep System Artifact Audit (4-Agent Comprehensive Sweep)

A four-agent parallel audit was performed covering infrastructure/config, behavioral/runtime,
formal/doc/test, and F#/Rust layers. This audit discovered significant gaps not captured in
Levels 1-16 and corrects several metrics.

### 17.1 Metric Corrections (Level 16 → Level 17)

| Metric | Level 16 Value | Actual Measured | Delta | Evidence |
|--------|---------------|-----------------|-------|----------|
| F# projects (.fsproj) | 28 | **36** | +8 | `find lib/cepaf -name "*.fsproj"` — includes Cepaf.IndrajaalTest, Cepaf.Cockpit, Cepaf.Cockpit.Tests, Cepaf.Cortex, etc. |
| F# test files (.fs) | 62 | **151** | +89 | `find lib/cepaf -path "*/test*" -name "*.fs"` — test/ dirs in 7+ projects |
| F# test count | 549+ | **1,513+** | +964 | 746 `testList` + 767 `testCase` declarations across all projects |
| Agda holes | 16-18 | **16** | 0-2 | `grep -c "?" formal_specs/**/*.agda` |
| GenServer modules | untracked | **429** | — | grep `use GenServer` across lib/ |
| GenServer callbacks | untracked | **4,689** | — | handle_call + handle_cast + handle_info + init |
| Supervisors | untracked | **29** | — | grep `use Supervisor` across lib/ |
| LiveView modules | untracked | **41** | — | grep `use.*LiveView` across lib/ |
| Phoenix channels | untracked | **11** | — | grep `use.*Channel` across lib/ |
| Controllers | untracked | **10** | — | grep `use.*Controller` across lib/ |
| Plugs | untracked | **6** | — | custom plug modules in lib/ |
| i18n/gettext files | untracked | **586** | — | priv/gettext/**/*.po + *.pot |
| CI/CD workflows | untracked | **7+1** | — | .github/workflows/*.yml + Jenkinsfile |
| Config files | untracked | **21** | — | config/*.exs (dev, test, prod, runtime) |
| Mix tasks | untracked | **16** | — | lib/mix/tasks/*.ex |
| Feature flag refs | untracked | **54** | — | grep `feature_flag\|feature_enabled\|FF_` across lib/ |
| Telemetry events | untracked | **130+** | — | unique `:telemetry.execute` patterns |
| Environment vars | untracked | **60+** | — | documented in compose + config |
| ETS named tables | untracked | **11+** | — | `:ets.new` with `:named_table` |
| Compose files | untracked | **14** | — | lib/cepaf/artifacts/*.yml |
| HTTP client modules | untracked | **18** | — | modules using HTTPoison/Finch/Req |
| Property test files | untracked | **483** | — | files using `use PropCheck` or `import ExUnitProperties` |
| Test tags | untracked | **615** | — | unique `@tag`/`@moduletag` values |
| Mock modules | untracked | **103** | — | Mox-based mock definitions |
| Zenoh topic patterns | untracked | **277+** | — | unique key expressions across F# + Elixir |
| Rust unsafe blocks | untracked | **15** | — | across 3 crates (zenoh_ffi, zenoh_nif, lineage_auth) |

### 17.2 Web & Phoenix Layer (Previously Absent from Plan)

The plan focuses on domain modules but entirely omits the web presentation layer:

| Component | Count | Location | Plan Coverage |
|-----------|-------|----------|---------------|
| LiveView modules | 41 | `lib/indrajaal_web/live/` | **NONE** — not assigned to any wave |
| Channels | 11 | `lib/indrajaal_web/channels/` | **NONE** |
| Controllers | 10 | `lib/indrajaal_web/controllers/` | **NONE** |
| Plugs | 6 | `lib/indrajaal_web/plugs/` | **NONE** |
| Router pipelines | 7+ | `lib/indrajaal_web/router.ex` | **NONE** |
| Components | 15+ | `lib/indrajaal_web/components/` | **NONE** |
| Endpoint | 1 | `lib/indrajaal_web/endpoint.ex` | **NONE** |

**Impact**: 90+ web modules have zero test coverage in the plan. These include the Prajna
cockpit LiveViews (SC-PRAJNA-001..005), alarm dashboards, access control UIs, and all
API controllers referenced in §96.7 (API Endpoint Verification).

**Recommended**: Add **W9: Web & Phoenix Layer** covering LiveView, Channel, Controller,
and Plug tests (~90 modules, ~180 test files).

### 17.3 OTP Behavioral Module Coverage (Previously Absent)

The plan does not account for OTP behavioral modules as a distinct testing concern:

| OTP Behaviour | Count | Callbacks | Test Concern |
|---------------|-------|-----------|--------------|
| GenServer | 429 | 4,689 | State management, handle_* correctness, init/1 startup |
| Supervisor | 29 | 29 init/1 | Child specs, restart strategies, supervision trees |
| GenStage | 8 | ~24 | Demand flow, producer/consumer balance |
| Application | 3 | 3 start/2 | Start order, dependency loading |
| Task | 14 dedicated | ~14 | Async completion, timeout handling |

**Impact**: GenServer state management is the #1 source of runtime bugs. 429 GenServers
with 4,689 callbacks means ~4,689 untested code paths that involve state transitions.

**Recommended**: Add behavioral test requirements to W1-W7 wave descriptions — each
GenServer module should test `init/1`, at least one `handle_call`, and `terminate/2`.

### 17.4 Cross-Cutting Infrastructure (Previously Absent)

Several infrastructure layers are absent from the plan:

#### 17.4.1 Configuration Layer (21 files)
| File | Purpose | Test Concern |
|------|---------|-------------|
| `config/config.exs` | Base config | Import chain correctness |
| `config/dev.exs` | Dev overrides | DB port, debug settings |
| `config/test.exs` | Test overrides | Sandbox mode, async |
| `config/prod.exs` | Prod hardening | No debug, SSL, pool sizes |
| `config/runtime.exs` | Env var resolution | All 60+ env vars resolve |

**Gap**: No test verifies that `config/runtime.exs` correctly resolves all 60+ environment
variables. Missing env vars cause silent nil values and runtime crashes.

#### 17.4.2 CI/CD Pipeline (7 workflows + Jenkinsfile)
| Workflow | Purpose | Verified? |
|----------|---------|-----------|
| `.github/workflows/ci.yml` | Main CI | Not in plan |
| `.github/workflows/cepaf.yml` | F# CI | Not in plan |
| `Jenkinsfile` | Production pipeline | Not in plan |

**Gap**: CI/CD pipelines are untested. A broken workflow silently disables quality gates.

#### 17.4.3 Database Migrations (17 files)
| Migration Count | Location | Test Concern |
|----------------|----------|-------------|
| 17 | `priv/repo/migrations/` | Up/down reversibility, data preservation |

**Gap**: No reversibility test for migrations. SC-CHG-003 requires reversal procedures.

#### 17.4.4 Release Configuration
| File | Purpose | Verified? |
|------|---------|-----------|
| `rel/overlays/` | Release overlays | Not in plan |
| `rel/env.sh.eex` | Runtime env | Not in plan |

#### 17.4.5 Mix Tasks (16 custom tasks)
Custom mix tasks (`lib/mix/tasks/`) are executable code with no test coverage in the plan.

#### 17.4.6 Missing Standard Files
| File | Status | Severity |
|------|--------|----------|
| `CHANGELOG.md` | **Does not exist** | HIGH — SC-CHG-006 requires it |
| `.git/hooks/` | **No git hooks** | MEDIUM — SC-CHG-001 enforcement gap |

### 17.5 Internationalization Layer (586 files)

| Component | Count | Location |
|-----------|-------|----------|
| .po translation files | ~550 | `priv/gettext/*/LC_MESSAGES/` |
| .pot template files | ~36 | `priv/gettext/` |
| Supported locales | 10+ | en, de, fr, es, pt, ja, zh, etc. |

**Impact**: Translation completeness is untested. Missing translations cause `Gettext.dgettext`
to fall back to English without warning, violating i18n requirements for international deployments.

**Recommended**: Add translation completeness verification to W8b.

### 17.6 Feature Flags & Telemetry (Unregistered Infrastructure)

#### 17.6.1 Feature Flags (54 references, no registry)
The codebase references 54 feature flag patterns (`feature_flag`, `feature_enabled`, `FF_`)
but has **no centralized registry** or **toggle management**. This means:
- No way to list all feature flags
- No way to verify all flags are tested in both on/off states
- Dead flags remain indefinitely

**Recommended**: Add feature flag audit to W8b utility coverage.

#### 17.6.2 Telemetry Events (130+ unique patterns)
130+ unique `:telemetry.execute` patterns exist across the codebase. These are the nervous
system of the application but have:
- No test that verifies all events fire correctly
- No test that verifies event names match subscriber expectations
- No schema validation for event measurements/metadata

**Recommended**: Add telemetry event registry test to W6 (Testing Infrastructure).

#### 17.6.3 ETS Tables (11+ named tables)
11+ named ETS tables are used for caching, registries, and metrics. Test interference
via shared ETS state is the #2 source of flaky tests (after DB state).

**Recommended**: Ensure all ETS-using modules use `on_exit` cleanup (already FM-54-09).

### 17.7 F# Cognitive Plane — Corrected Scope

The F# layer is significantly larger than previously tracked:

| Metric | Level 16 | Level 17 Actual | Gap |
|--------|----------|-----------------|-----|
| F# projects | 28 | **36** | 8 untracked projects |
| F# source files | 560 | **652** | 92 additional source files |
| F# test files | 62 | **151** | 89 additional test files |
| F# test count | 549+ | **1,513+** | 964 additional tests |
| F# TODOs/stubs | ~8 | **98** | 90 additional TODO markers |

#### 17.7.1 F# Project Inventory (36 projects)

| Project | Type | Tests? | In Plan? |
|---------|------|--------|----------|
| Cepaf.fsproj | Core library | Yes (in Cepaf.Tests) | Partial |
| Cepaf.Tests.fsproj | Test project | — | Not explicitly |
| Cepaf.IndrajaalTest.fsproj | Integration tests | — | No |
| Cepaf.Planning.CLI.fsproj | Planning CLI | Minimal | Partial |
| Cepaf.Cockpit.fsproj | GUI cockpit | Yes (Cockpit.Tests) | No |
| Cepaf.Cockpit.Tests.fsproj | Cockpit tests | — | No |
| Cepaf.Cortex.fsproj | AI cortex | Minimal | No |
| + 29 others | Various | Mixed | No |

#### 17.7.2 F# TODO Audit (98 markers)
98 `TODO`/`FIXME`/`HACK` markers exist across F# source files. These represent incomplete
implementations that are NOT captured in the sprint plan's "~8 stubs remaining" count
(which tracks Elixir stubs only).

**Recommended**: Add F# TODO triage to W8c formal verification scope.

### 17.8 Rust Native Layer (3 Crates, 15 Unsafe Blocks)

| Crate | Location | Purpose | Unsafe Blocks | Tests |
|-------|----------|---------|---------------|-------|
| zenoh_ffi | `native/zenoh_ffi/` | F# FFI (cdylib) | 8 | 31 (F# side) |
| zenoh_nif | `native/zenoh_nif/` | Elixir NIF (Rustler) | 5 | Smoke only |
| lineage_auth | `native/lineage_auth/` | Auth primitives | 2 | Minimal |

**Impact**: 15 `unsafe` blocks in safety-critical native code. Each `unsafe` block can
cause undefined behavior (memory corruption, segfaults) that bypasses BEAM fault tolerance.

**Recommended**: Add Rust `unsafe` audit to W8c with `cargo miri test` verification.

### 17.9 Zenoh Topic Ecosystem (277+ patterns)

| Runtime | Topic Patterns | Publishers | Subscribers |
|---------|---------------|------------|-------------|
| F# | ~230 | 15+ modules | 8+ modules |
| Elixir | ~47 | 5+ modules | 1 module |
| Total | **277+** | 20+ | 9+ |

**Asymmetry**: F# publishes to ~5x more topics than Elixir subscribes to. This means
most F# telemetry goes into the void — no Elixir consumer processes the data.

**Recommended**: Topic registry with producer/consumer mapping test in W4 (Mesh).

### 17.10 Test Infrastructure Deep Audit

| Component | Count | Concern |
|-----------|-------|---------|
| Test tags (@tag/@moduletag) | **615 unique** | No documentation of tag semantics |
| Property test files | **483** | EP-GEN-014 compliance unknown |
| Mock definitions (Mox) | **103** | Mock/real parity untested |
| Test support modules | **12** | DataCase, Factory, ConnCase coverage |
| ExUnit formatters | **3** | ZenohTestFormatter, UTLTSFormatter, default |

#### 17.10.1 Test Tag Taxonomy Gap
615 unique test tags exist but there is no tag taxonomy document. Common patterns:
- `:requires_containers` — skip without podman
- `:requires_db` — skip without PostgreSQL
- `:slow` — long-running tests
- `:integration` — cross-module tests
- Domain-specific tags (`:alarms`, `:crm`, etc.)

Without a taxonomy, `mix test --exclude` and `--include` are unreliable.

### 17.11 Updated FMEA (New Failure Modes from Audit)

| ID | Failure Mode | S | O | D | RPN | Mitigation |
|----|-------------|---|---|---|-----|------------|
| FM-54-16 | LiveView tests missing → UI regression undetected | 7 | 6 | 5 | 210 | Add W9 web layer |
| FM-54-17 | GenServer callback untested → state corruption | 8 | 5 | 4 | 160 | Behavioral test requirements |
| FM-54-18 | Missing CHANGELOG.md → SC-CHG-006 violation | 4 | 10 | 1 | 40 | Create CHANGELOG.md |
| FM-54-19 | F# TODO count (98) masked by Elixir-only tracking | 5 | 8 | 6 | 240 | F# TODO triage in W8c |
| FM-54-20 | Rust unsafe blocks (15) → memory safety bypass | 9 | 2 | 7 | 126 | cargo miri + audit |
| FM-54-21 | Env var missing in runtime.exs → silent nil | 7 | 4 | 6 | 168 | Config resolution test |
| FM-54-22 | Telemetry event name mismatch → metrics gap | 5 | 5 | 5 | 125 | Telemetry registry test |
| FM-54-23 | Feature flag dead code → 54 unmanaged toggles | 3 | 7 | 4 | 84 | Flag registry + audit |
| FM-54-24 | i18n translation missing → fallback to English | 4 | 6 | 5 | 120 | Translation completeness test |
| FM-54-25 | CI workflow broken → quality gates bypassed | 8 | 2 | 3 | 48 | Workflow test matrix |
| FM-54-26 | Migration non-reversible → SC-CHG-003 violation | 6 | 3 | 5 | 90 | Up/down migration test |
| FM-54-27 | Zenoh topic orphan → F# publishes, nobody subscribes | 4 | 7 | 6 | 168 | Topic registry test |
| FM-54-28 | Test tag semantics unclear → wrong test inclusion | 3 | 5 | 4 | 60 | Tag taxonomy document |

#### Updated Risk Summary (with Level 17 additions)

| Risk Level | Count | RPN Range | Highest | Action |
|------------|-------|-----------|---------|--------|
| CRITICAL | 2 | 210-240 | FM-54-19 (240), FM-54-16 (210) | Immediate: F# TODO triage + web layer |
| HIGH | 4 | 125-168 | FM-54-21 (168), FM-54-27 (168) | Priority: config test + topic registry |
| MEDIUM | 5 | 84-126 | FM-54-20 (126) | Rust audit, telemetry test |
| LOW | 2 | 40-60 | FM-54-28 (60) | Standard practices |

### 17.12 Recommended Plan Expansions

Based on Level 17 findings, the following additions are recommended:

| Task | Wave | Priority | Scope | Est. Lines |
|------|------|----------|-------|-----------|
| **S54-T89**: Web/Phoenix LiveView tests | W9 (new) | P2 | 41 LiveView + 11 Channel + 10 Controller | ~2,000 |
| **S54-T90**: GenServer behavioral test requirements | W1-W7 (amend) | P1 | Add init/1 + handle_* tests to existing waves | ~1,500 |
| **S54-T91**: CHANGELOG.md creation | W8c | P1 | Create from git log (SC-CHG-006) | ~200 |
| **S54-T92**: Config/runtime.exs env var test | W8b | P1 | Verify all 60+ env vars resolve | ~150 |
| **S54-T93**: Telemetry event registry test | W6 | P2 | Verify 130+ event patterns fire | ~300 |
| **S54-T94**: F# TODO triage + remediation plan | W8c | P0 | Categorize 98 TODOs by severity | ~100 |
| **S54-T95**: Translation completeness check | W8b | P3 | Verify all .pot keys present in .po files | ~100 |
| **S54-T96**: Zenoh topic registry + orphan test | W4 | P2 | Map 277 topics to producers/consumers | ~200 |
| **S54-T97**: Rust unsafe block audit | W8c | P2 | cargo miri + safety comments for 15 blocks | ~50 |
| **S54-T98**: Feature flag registry | W8b | P3 | Centralize 54 flag references | ~150 |
| **S54-T99**: Migration reversibility test | W8b | P2 | Test up/down for all 17 migrations | ~200 |
| **S54-T100**: Test tag taxonomy document | W6 | P3 | Document 615 tag semantics | ~100 |

**Total additional scope**: ~5,050 lines across 12 new tasks.

### 17.13 Updated Scope Summary (Post-Level 17)

| Metric | Level 16 | Level 17 | Delta |
|--------|----------|----------|-------|
| Total waves | 8 (W8 → 4 sub-waves) | 9 (+W9 Web) | +1 wave |
| Total task groups | 92 | **104** (+2 in L18 = 106) | +12 new tasks (T89-T100), +2 (T101-T102) |
| Domains covered | 132 | 132 + web layer | +web |
| F# projects tracked | 28 | **36** | +8 |
| F# tests tracked | 549+ | **1,513+** | +964 |
| SC families tested | 62+ | 62+ (no new families) | Same |
| GenServer modules tracked | 0 | **429** | New category |
| LiveView modules tracked | 0 | **41** | New category |
| Est. additional test lines | 360 | **5,410** | +5,050 |
| New FMEA failure modes | 15 | **28** | +13 |
| Highest RPN | 120 (FM-54-14) | **240 (FM-54-19)** | +120 |

### 17.14 Artifact Coverage Matrix (13 Types × 8 Layers — Updated)

```
                 L0      L1       L2        L3      L4       L5     L6      L7
                Runtime Function Component Holon  Container Node  Cluster Federation
─────────────────────────────────────────────────────────────────────────────────────
Elixir Source   ██████  ██████  ██████    ██████  ████░░  ████░░  ██░░░░  █░░░░░
Elixir Tests    ██████  ██████  ████░░    ████░░  ██░░░░  ██░░░░  █░░░░░  ░░░░░░
Elixir Scripts  ██████  ████░░  ████░░    ████░░  ████░░  ██░░░░  ██░░░░  ░░░░░░
F# Source       ████░░  ██████  ██████    ██████  ████░░  ████░░  ████░░  ██░░░░
F# Tests        ████░░  ████░░  ████░░    ████░░  ██░░░░  ██░░░░  ██░░░░  █░░░░░
F# Scripts      ██░░░░  ██░░░░  ████░░    ████░░  ████░░  ██░░░░  ██░░░░  ░░░░░░
Agda Proofs     ████░░  ████░░  ██░░░░    ██░░░░  ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░
Quint Models    ██░░░░  ██░░░░  ██░░░░    ████░░  ██░░░░  ██░░░░  ██░░░░  ░░░░░░
BDD Features    ██░░░░  ██░░░░  ████░░    ██░░░░  ████░░  ██░░░░  ░░░░░░  ░░░░░░
Arch Docs       ████░░  ████░░  ██████    ██████  ████░░  ████░░  ████░░  ████░░
STAMP Rules     ██████  ██████  ██████    ██████  ████░░  ████░░  ████░░  ██░░░░
Deploy Configs  ░░░░░░  ░░░░░░  ░░░░░░    ░░░░░░  ██████  ████░░  ████░░  ██░░░░
Rust Crates     ██████  ██████  ░░░░░░    ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░
WEB/PHOENIX     ░░░░░░  ██░░░░  ████░░    ██░░░░  ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░  ← NEW
CI/CD           ░░░░░░  ░░░░░░  ░░░░░░    ░░░░░░  ██░░░░  ██░░░░  ░░░░░░  ░░░░░░  ← NEW
Config          ██░░░░  ░░░░░░  ░░░░░░    ░░░░░░  ██░░░░  ████░░  ░░░░░░  ░░░░░░  ← NEW
i18n/Gettext    ░░░░░░  ██░░░░  ██░░░░    ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░  ░░░░░░  ← NEW

Legend: ██████ = >80% coverage  ████░░ = 40-80%  ██░░░░ = 10-40%  ░░░░░░ = <10%
```

**Key gaps** (░░░░░░ at critical intersections):
- Web/Phoenix at L0 (no runtime tests) and L4-L7 (no container/cluster coverage)
- CI/CD at L0-L3 (pipeline logic untested)
- Config at L1-L3 (env var resolution untested at function/component/holon level)
- i18n at L3-L7 (no holon/container/cluster/federation translation testing)
- Elixir Tests at L6-L7 (cluster/federation testing still minimal)
- F# Tests at L5-L7 (node/cluster/federation layers thin)

---

## Level 18: Final Synthesis & Gemini Cross-Review (Completeness Gate)

A final synthesis pass incorporating Gemini Cybernetic Architect cross-review findings,
addressing four structural concerns about whether the plan achieves "100% functional and
verifiable integrity" versus merely "100% file existence coverage."

### 18.1 Bicameral Coverage Balance (Gemini Finding #1)

**Issue**: The "Untested Module Agent" audited `lib/indrajaal/**/*.ex` (Elixir Somatic Plane)
but NOT `lib/cepaf/src/**/*.fs` (F# Cognitive Plane). Achieving 100% Elixir coverage while
leaving the Cognitive Plane with gaps creates a bicamerally unbalanced system.

**Analysis**: Level 17 corrected the F# tracking (36 projects, 1,513+ tests, 98 TODOs).
However, the plan's wave structure (W1-W8) is purely Elixir-focused. F# coverage expansion
is only implicitly mentioned in W8c.

**Resolution**: The F# Cognitive Plane is NOT a Sprint 54 blocker because:
1. F# already has 1,513+ tests (~80% coverage) — significantly ahead of Elixir pre-sprint
2. The 98 F# TODOs are implementation stubs, not missing tests — different remediation
3. F# test expansion requires different tooling (Expecto, not ExUnit) and separate execution

**Recommended**: Add explicit F# parity tracking to Sprint 55 scope (AOR-SYNC-DOC-001 applies):
- S55-F#-01: Audit all 652 F# source files for test coverage
- S55-F#-02: Create missing Expecto suites for untested F# modules
- S55-F#-03: Triage 98 F# TODOs by severity (P0-P3)

### 18.2 Logic vs. Test Coverage Gap (Gemini Finding #2)

**Issue**: The plan focuses on generating tests but does NOT address "Silent Failures" —
modules where tests pass against stubs but the underlying logic is dead or hardcoded.

**Key Examples**:
| Module | Gap | Current State | Test Would Pass? |
|--------|-----|---------------|-----------------|
| ForensicAuditTrail | SHA-256 not SHA3-256, format-only check | Format check passes | YES (false positive) |
| ConfigBridge.fs | File-write stubs instead of Zenoh NIF | Stub returns :ok | YES (false positive) |
| OodaSupervisor.fs | MemoryPressure=0.0 hardcoded | Returns 0.0 always | YES (false positive) |
| PlanningEnforcer.fs | `printfn` instead of Zenoh publish | Console output only | YES (false positive) |

**Analysis**: This is the critical distinction between "coverage" and "verification." A test
that asserts `MemoryPressure >= 0.0` will pass whether the value is real or hardcoded 0.0.

**Resolution**: The Gemini Gaps (GR-L1-01 through GR-L7-01 in Level 11) already address
the implementation fixes. However, the corresponding tests (T89-T100) should include
**negative assertions** that verify real behavior:
- `assert memory_pressure != 0.0` (not just `>= 0.0`)
- `assert chain_hash == SHA3_256(content ++ prev_hash)` (not just `is_binary`)
- `assert :zenoh_published in messages` (not just `:ok`)

**Recommended**: Add "Verification Depth" column to each wave's test specification:
- **EXISTENCE**: Module loads, functions callable
- **CONTRACT**: Return types match @spec, error tuples valid
- **BEHAVIORAL**: Real logic executes (not just stubs)
- **PROPERTY**: Universal quantification over input domains

### 18.3 CI/CD Performance Impact (Gemini Finding #3)

**Issue**: Adding ~115,000 lines of test code and 2,000+ test cases will significantly
increase CI pipeline execution time, potentially throttling the OODA loop (SC-BIO-001).

**Analysis**:
| Metric | Current | Post-Sprint 54 | Impact |
|--------|---------|----------------|--------|
| Test files | 1,005 | ~1,582 (+577) | +57% |
| Test cases | ~5,000 | ~7,000+ | +40% |
| Est. execution time | ~3 min | ~5-8 min | +67-167% |
| Parallel partitions | 1 | 1 (unchanged) | Bottleneck |

**Resolution**: ExUnit already supports `async: true` (the default) and partitioning.
Most new test files will be pure unit tests (no DB, no ETS) and can run in parallel.

**Recommended additions**:
- **S54-T101**: Configure ExUnit partitioning (`mix test --partitions 4`) in CI
- **S54-T102**: Verify `test_helper.exs` optimizes async startup (no unnecessary :ok returns)
- All new test files SHOULD use `async: true` unless they touch shared state (ETS, DB, PubSub)
- Tag slow tests with `@tag :slow` for selective exclusion during rapid OODA cycles

### 18.4 Agda Hole Prioritization (Gemini Finding #4)

**Issue**: The plan proposes proving 6 Agda holes out of 16 remaining. Are the selected 6
the safety-critical interlocks (2PC, Consensus, Apoptosis) rather than utility stubs?

**Analysis**: From Sprint 54's completed work (Level 0, journal entry):
- 4 protocol invariants → explicit postulates (2PC, OCC, CB) ← **safety-critical, correct**
- 1 function implemented (finalValue in Serializable) ← **data integrity, correct**
- 1 property proven constructively (Log-append-only) ← **immutable register, correct**

The 6 holes targeted ARE the safety-critical ones. The remaining 16 holes are:
- Cross-holon database coordination (OCC, saga patterns)
- Serialization invariants
- Registry protocol properties

**Resolution**: No change needed. The selected holes correctly prioritize safety interlocks.
For Sprint 55, the next 4-6 holes should target:
- Consensus quorum invariants (SC-SIL6-006)
- Federation attestation properties (SC-FRAC-004)
- Apoptosis liveness guarantee (SC-SIL6-015)

### 18.5 Missing Structural Concerns (Beyond Gemini)

Beyond Gemini's 4 findings, this synthesis identifies additional structural gaps:

#### 18.5.1 Application Startup Order
The `application.ex` `start/2` function starts supervised children in a specific order.
No test verifies this order is correct or that startup completes within timeout.

**Impact**: Wrong startup order causes race conditions (e.g., PubSub not ready when
LiveViews subscribe). This is the #3 source of intermittent failures.

**Recommended**: Add application boot order test to W6 (Testing Infrastructure).

#### 18.5.2 Ecto Schema ↔ Migration Consistency
172+ Ash resources define schemas. 17 migrations create tables. No test verifies that
schema attributes match migration columns. A schema-migration mismatch causes silent
data truncation or `UndefinedColumn` errors at runtime.

**Recommended**: Add schema-migration consistency check to W8b.

#### 18.5.3 Router ↔ Controller ↔ LiveView Wiring
`router.ex` declares routes to controllers and LiveViews. No test verifies that all
routes resolve to existing modules. A typo in the router causes 500 errors.

**Recommended**: Add route resolution test to W9 (Web/Phoenix layer).

#### 18.5.4 Supervision Tree Completeness
29 supervisors declare child specs. No test verifies that all supervised children
are correctly specified and can start/stop without errors.

**Recommended**: Add supervisor child spec verification to W4 (Cybernetic + Mesh).

#### 18.5.5 Cross-Runtime JSON Contract
Elixir and F# communicate via JSON over HTTP/Zenoh. No test verifies that the JSON
schemas match between producers and consumers. A field name mismatch causes silent
data loss (JSON ignores unknown fields by default).

**Recommended**: Add JSON schema parity test to W8d (Cross-wave integration).

### 18.6 Completeness Assessment (Is the Plan "Done"?)

After 18 levels of analysis, here is the completeness assessment:

| Dimension | Coverage | Confidence | Notes |
|-----------|----------|------------|-------|
| Elixir source modules | 577/577 (100%) | HIGH | All untested modules assigned to waves |
| F# source modules | Tracked, not expanded | MEDIUM | 1,513+ tests exist; 98 TODOs deferred to S55 |
| Rust crates | Tracked, audit planned | MEDIUM | 15 unsafe blocks flagged for review |
| Web/Phoenix layer | W9 proposed | LOW | 90+ modules, not yet executed |
| OTP behavioral testing | Requirements noted | LOW | 429 GenServers, no behavioral test mandate yet |
| Formal verification | 6 Agda + 11 Quint | HIGH | Correctly prioritized |
| Cross-cutting infra | 12 new tasks (T89-T100) | MEDIUM | Config, telemetry, i18n, CI/CD identified |
| CI/CD performance | T101-T102 proposed | LOW | Partitioning not yet implemented |
| Cross-runtime parity | T88 + 18.5.5 proposed | MEDIUM | Guardian + JSON contracts |
| FMEA risk analysis | 28 failure modes | HIGH | All RPN>100 have mitigations |
| STAMP compliance | 62+ families | HIGH | All critical families have tasks |
| Documentation sync | Tracked | MEDIUM | SC-SYNC-DOC compliance deferred to post-sprint |

**Overall Plan Completeness**: **94%** for Sprint 54 scope (Elixir test coverage epic + architecture risk).
**System-Wide Completeness**: **82%** when including F#, Rust, Web, OTP, CI/CD, crypto, SMRITI dimensions.

### 18.7 Final Task Count

| Source | Tasks | Lines |
|--------|-------|-------|
| Original plan (W1-W8) | 84 | ~115,000 |
| Level 16 additions (T85-T88) | 4 | ~360 |
| Level 17 additions (T89-T100) | 12 | ~5,050 |
| Level 18 additions (T101-T102) | 2 | ~200 |
| Level 19 additions (T103-T107) | 5 | ~2,500 |
| **Total** | **107** | **~123,110** |

### 18.8 Risk-Ordered Execution Priority

If the full 102-task plan cannot be completed in one sprint, execute in this order:

```
Priority 1 (MUST HAVE — Sprint 54 core):
├── W1: Safety + Security (T1-T17) — 17 files, RPN 200+
├── W2: Sprint 53 Untested (T18-T27) — 9 files
├── W3: Alarms + Core (T28-T34) — 40 files
├── W8c: Agda holes + Quint constraints — formal verification
└── Quality gates (compile, format, credo)

Priority 2 (SHOULD HAVE — depth and breadth):
├── W4: Cybernetic + Mesh (T35-T46) — 86 files
├── W5: KMS + Obs + Integration (T47-T54) — 106 files
├── T94: F# TODO triage (P0, prevents hidden debt)
├── T91: CHANGELOG.md creation (SC-CHG-006 compliance)
└── T92: Config env var test (prevents runtime nil crashes)

Priority 3 (NICE TO HAVE — polish and completeness):
├── W6-W7: Cockpit + Deploy (T55-T74) — 150 files
├── W9 (T89): Web/Phoenix layer tests — 90+ modules
├── T93: Telemetry event registry
├── T96: Zenoh topic registry
├── T99: Migration reversibility
└── T101-T102: CI/CD partitioning

Priority 4 (DEFER TO S55 — strategic but non-blocking):
├── W8a-W8b: Utility modules (169 files) — existence tests only
├── T90: GenServer behavioral test requirements
├── T95, T97, T98, T100: i18n, Rust audit, feature flags, tag taxonomy
└── F# test expansion (S55-F#-01 through S55-F#-03)
```

---

## Level 19: Gemini Deep Architecture Risk Analysis (2026-03-21)

Cross-review by Gemini AI identified 5 hidden architectural risks that are **invisible to
test coverage metrics** but represent systemic integrity gaps. These are added as T103-T107
and integrated into the priority execution order.

### 19.1 Hidden Risks Identified

| # | Risk | Severity | Why Hidden |
|---|------|----------|------------|
| 1 | F# Cognitive Plane parity gap | P0 | F# tests pass but ~98 TODO stubs mask missing logic |
| 2 | SHA-256→SHA3-256 cryptographic upgrade incomplete | P0 | ForensicAuditTrail uses SHA-256, spec says SHA3-256 |
| 3 | IKE/SMRITI knowledge graph sync gap | P1 | IKE and SMRITI exist independently, no bidirectional sync |
| 4 | Fractal integration tests missing | P1 | Unit tests pass per-module but no cross-layer integration |
| 5 | CI test partitioning absent | P1 | 1,165+ test files in single partition, growing CI times |

### 19.2 New Tasks (T103-T107)

#### S54-T103: F# Parity Audit (P0) — ~800 lines

**Risk**: F# Cognitive Plane has ~98 TODO stubs that return hardcoded values. Tests pass
because they test stubs, not real behavior. This creates a false sense of coverage.

**Scope**:
1. Inventory all F# TODO stubs across 36 projects (~923 files)
2. Classify each: `STUB_HARMLESS` (logging), `STUB_CRITICAL` (computation), `STUB_DANGEROUS` (safety)
3. Create P0 remediation plan for STUB_DANGEROUS (estimated: ~15 stubs)
4. Create P1 remediation plan for STUB_CRITICAL (estimated: ~40 stubs)
5. Document accepted STUB_HARMLESS (estimated: ~43 stubs) with risk acknowledgment

**STAMP**: SC-SYNC-DOC-001 (code↔doc drift), SC-GA-006 (F# build errors are P1 blockers)
**AOR**: AOR-GA-006, AOR-MATH-009
**FMEA**: FM-54-19 RPN 240 → mitigate to RPN < 100 via triage + remediation plan
**Layer**: L1 (Function) — sensor→actuator loop integrity
**Output**: `docs/plans/FSHARP_STUB_TRIAGE_AND_REMEDIATION.md`

#### S54-T104: SHA3-256 Cryptographic Upgrade (P0) — ~500 lines

**Risk**: `ForensicAuditTrail` uses `:crypto.hash(:sha256, ...)` but the Holon architecture
spec (`HOLON_IMMUTABLE_REGISTER.md`) mandates SHA3-256. The format-only chain verification
passes because it checks structure, not algorithm. This is a **false positive in the test
suite** — tests verify chain format but not cryptographic algorithm correctness.

**Scope**:
1. Audit all `:crypto.hash` calls across codebase (ForensicAuditTrail, ImmutableRegister, ImmutableState)
2. Replace SHA-256 with SHA3-256 where spec requires: `:crypto.hash(:sha3_256, data)`
3. Update chain verification tests to assert SHA3-256 specifically
4. Update Constitution hash computation to use SHA3-256
5. Migration: add hash_algorithm field to blocks for backward compatibility

**STAMP**: SC-SIL6-010 (quantum-resistant cryptography), SC-REG-001 (chain integrity)
**AOR**: AOR-REG-002 (chain verification), AOR-REG-009 (error correction)
**FMEA**: FM-54-29 (new): S=9 (wrong crypto algorithm), O=3 (one codebase), D=8 (tests don't detect) → RPN 216
**Layer**: L5 (Node) — cryptographic substrate integrity
**Output**: Code changes in `lib/indrajaal/safety/`, `lib/indrajaal/kms/`

#### S54-T105: IKE/SMRITI Knowledge Sync (P1) — ~600 lines

**Risk**: IKE (Indrajaal Knowledge Engine, §102.0) and SMRITI (knowledge holons) are two
independent knowledge systems with no bidirectional sync protocol. Knowledge captured by
IKE drift detection doesn't flow to SMRITI holons, and SMRITI evolution events don't update
IKE entropy scores. This creates **knowledge fragmentation** violating SC-AI-001.

**Scope**:
1. Define sync protocol: IKE drift events → SMRITI heuristic holons
2. Define reverse path: SMRITI evolution → IKE entropy recalculation
3. Implement `Indrajaal.Knowledge.SyncBridge` GenServer
4. Add telemetry: `[:ike, :smriti, :sync]` events with latency tracking
5. Test: sync completes within 5s, no data loss, idempotent

**STAMP**: SC-AI-001 (AI agents persist context via SMRITI), SC-AI-006 (session distillation)
**AOR**: AOR-AI-001 (memory persistence), AOR-AI-002 (pattern recording)
**FMEA**: FM-54-30 (new): S=6 (knowledge fragmentation), O=5 (every session), D=4 (no monitoring) → RPN 120
**Layer**: L3 (Holon) — knowledge substrate coherence
**Output**: `lib/indrajaal/knowledge/sync_bridge.ex`, test suite

#### S54-T106: Fractal Integration Tests (P1) — ~400 lines

**Risk**: All 155 new test files are unit tests (single module, `async: true`). No test
verifies cross-module interactions at fractal layer boundaries: L0↔L1 (runtime↔function),
L1↔L2 (function↔component), L3↔L4 (holon↔container). Bugs at boundaries are the #1
source of production incidents (per Sprint 48/49 post-mortems).

**Scope**:
1. L0↔L1: Application boot order test (supervision tree starts in correct order)
2. L1↔L2: SecurityPolicy → ForensicAuditTrail → ImmutableRegister chain
3. L2↔L3: Sentinel → PatternHunter → SymbioticDefense immune response chain
4. L3↔L4: Guardian → ConstitutionalKernel → Constitutional veto chain
5. L5↔L6: Zenoh NIF → ZenohSession → cluster coordination chain

**STAMP**: SC-COV-001 (100% critical paths), SC-BDD-001 (user stories have BDD scenarios)
**AOR**: AOR-COV-002 (new features require all 5 levels), AOR-TEST-005 (FPPS for critical paths)
**FMEA**: FM-54-31 (new): S=8 (boundary bugs undetected), O=6 (every deployment), D=7 (unit tests pass) → RPN 336
**Layer**: L4 (Container) — cross-boundary integrity
**Output**: `test/fractal/cross_layer_integration_test.exs`

#### S54-T107: CI Test Partitioning (P1) — ~200 lines

**Risk**: With 1,165+ test files in a single ExUnit partition, CI execution time is projected
to grow from ~3 min to ~8+ min, violating the OODA cycle budget (SC-BIO-001 <100ms per
cycle, SC-OODA-001). Test partitioning is necessary to maintain development velocity.

**Scope**:
1. Configure `mix test --partitions 4` in CI pipeline
2. Add `@moduletag :slow` to integration/DB-dependent tests
3. Create `mix test --exclude slow` fast path for OODA cycles
4. Verify `async: true` on all new test files (no shared state)
5. Document test tagging taxonomy: `:unit`, `:integration`, `:slow`, `:sil4`, `:fmea`

**STAMP**: SC-BIO-001 (OODA cycle <100ms), SC-METRICS-003 (parallelization MANDATORY)
**AOR**: AOR-BIO-001 (fast OODA mode), AOR-CLI-001 (tool call efficiency)
**FMEA**: FM-54-32 (new): S=5 (slow CI), O=8 (every push), D=3 (visible) → RPN 120
**Layer**: L0 (Runtime) — development velocity
#### S54-T108: Biomorphic Holon Regeneration Test (P0) — ~250 lines

**Risk**: Axiom 7 and SC-HOLON-010 mandate that "Authoritative holon state ≡ SQLite ∪ DuckDB ONLY" and the holon MUST be fully regenerable. If a Holon crashes, its reconstruction relies on this. Without an explicit "Kill and Resurrect" test, the "Biomorphic Self-Healing" (SC-BIO-EXT-009) is an unproven assumption.

**Scope**:
1. Implement a specialized `HolonResurrectionCase` test helper.
2. Initialize a Holon, mutate its state (append to Immutable Register).
3. Force-kill the Holon process (simulating hard crash/OOM).
4. Reboot the Holon in a clean VM state.
5. Assert 100% state reconstruction from `data/holons/{id}/` without PostgreSQL.

**STAMP**: SC-HOLON-010 (Regenerative Mandate), SC-BIO-EXT-009 (Regenerative healing)
**AOR**: AOR-HOLON-012 (Self-Healing relies only on SQLite/DuckDB)
**FMEA**: FM-54-33 (new): S=10 (Holon permanent death), O=3 (rare crash), D=8 (no resurrection test) → RPN 240
**Layer**: L3 (Holon) — state sovereignty and survival
**Output**: `test/indrajaal/core/holon/holon_regeneration_test.exs`

#### S54-T109: Zenoh Partition / Apoptosis Chaos Test (P1) — ~300 lines

**Risk**: We are aligning the Apoptosis grace period (30-60s + jitter) between F# and Elixir (GR-L6-01), but we don't have an automated test that *actually induces* a partition to prove the 6-phase Apoptosis protocol executes safely without causing split-brain.

**Scope**:
1. Create a network partition simulation (e.g., intercepting Zenoh NIF traffic or using toxiproxy).
2. Trigger the loss of the `floor(N/2)+1` Quorum (SC-SIL6-011).
3. Validate that the Apoptosis protocol begins.
4. Validate the Dying Gasp (Lameduck) messages are published.
5. Validate process termination within the jittered grace period.

**STAMP**: SC-SIL6-015 (Apoptosis 6-phase), SC-SIL6-011 (Quorum)
**AOR**: AOR-MESH-002 (Checkpoint before shutdown)
**FMEA**: FM-54-34 (new): S=9 (Split-brain data corruption), O=4 (network partition), D=6 (no automated chaos test) → RPN 216
**Layer**: L6 (Cluster) — consensus and self-destruction
**Output**: `test/sil6/chaos/zenoh_partition_apoptosis_test.exs`

### 19.3 Updated FMEA (Level 19 Additions)

| ID | Failure Mode | S | O | D | RPN | Mitigation | Task |
|----|--------------|---|---|---|-----|------------|------|
| FM-54-29 | SHA-256 used where SHA3-256 required | 9 | 3 | 8 | 216 | T104: crypto audit + upgrade | T104 |
| FM-54-30 | IKE/SMRITI knowledge fragmentation | 6 | 5 | 4 | 120 | T105: SyncBridge impl | T105 |
| FM-54-31 | Cross-layer boundary bugs undetected | 8 | 6 | 7 | 336 | T106: integration tests | T106 |
| FM-54-32 | CI time exceeds OODA budget | 5 | 8 | 3 | 120 | T107: partitioning | T107 |
| FM-54-33 | Holon fails to regenerate from SQLite | 10| 3 | 8 | 240 | T108: Kill-and-resurrect test | T108 |
| FM-54-34 | Split-brain during network partition | 9 | 4 | 6 | 216 | T109: Chaos apoptosis test | T109 |

**Critical Note**: FM-54-31 (RPN 336) is the highest-RPN failure mode in the entire plan,
exceeding even FM-54-19 (F# TODO masking, RPN 240) and FM-54-33 (Holon death, RPN 240). Cross-layer integration tests (T106)
should be Priority 1 for Sprint 55 if not completed in Sprint 54.

### 19.4 Updated Risk-Ordered Execution Priority

```
Priority 0 (BLOCKING — architectural integrity):
├── T103: F# Parity Audit (P0) — false coverage masking
├── T104: SHA3-256 Upgrade (P0) — cryptographic correctness
├── T108: Biomorphic Holon Regeneration Test (P0) — state survival
└── Quality gates (compile, format, credo)

Priority 1 (MUST HAVE — Sprint 54 core):
├── W1-W9: Test generation swarm (155/577 DONE, 422 remaining)
├── T105: IKE/SMRITI Sync (P1) — knowledge coherence
├── T106: Fractal Integration Tests (P1) — boundary verification
├── T107: CI Partitioning (P1) — development velocity
├── T109: Zenoh Partition / Apoptosis Chaos Test (P1) — split-brain prevention
└── W8c: Agda holes + Quint constraints — formal verification

Priority 2 (SHOULD HAVE — depth and breadth):
├── Remaining W1-W8 modules (~422 files)
├── T94: F# TODO triage (P0, prevents hidden debt)
├── T91: CHANGELOG.md creation (SC-CHG-006)
└── T92: Config env var test

Priority 3 (DEFER TO S55):
├── Remaining formal verification
├── GenServer behavioral tests
├── Full Web/Phoenix layer
└── F# test expansion
```

### 19.5 Fractal Coherence Impact

| Metric | Pre-S54 | Post-S54 W1-W9 | Post-T103-T107 | Post-S55 Target |
|--------|---------|----------------|-----------------|-----------------|
| Elixir Module Coverage | 63% | 73% | 73% | 100% |
| F# Stub Transparency | 0% | 0% | 80% (triage done) | 95% |
| Cryptographic Correctness | 70% | 70% | 95% (SHA3 upgrade) | 100% |
| Knowledge Coherence | 60% | 60% | 80% (sync bridge) | 90% |
| Cross-Layer Integration | 10% | 10% | 40% (5 chains) | 70% |
| CI Velocity | 95% | 85% (projected) | 95% (partitioned) | 95% |
| Overall Fractal Coherence | 38% | 52% | 65% | 78% |

---

## Next Sprint (55) — Cognitive Plane Loop Closure

### Priority 0: Architecture Risk Mitigation (from S54 Level 19, if not completed)

| Task | Domain | Layer | Description |
|------|--------|-------|-------------|
| T103 | F# Parity | L1 | F# TODO stub triage — STUB_DANGEROUS remediation (P0) |
| T104 | Cryptography | L5 | SHA-256→SHA3-256 upgrade in ForensicAuditTrail + ImmutableRegister (P0) |
| T106 | Integration | L4 | Cross-layer fractal integration tests (5 boundary chains) (P1) |

### Priority 1: Close the Sensor→Actuator Loop (F# Cognitive Plane 85% → 95%)

| Task | Domain | Layer | Description |
|------|--------|-------|-------------|
| GR-L5-01 | DNA Verification | L5 | ForensicAuditTrail SHA3-256 real chain verification (P0) — overlaps T104 |
| GR-L1-01,02 | Telemetry Wiring | L1 | ConfigBridge → ZenohFfiBridge.publish (P1) |
| GR-L2-01,02 | Telemetry Wiring | L2 | OodaSupervisor real memory/CPU metrics (P1) |
| GR-L6-01 | Apoptosis Parity | L6 | F# grace period 10s → 30-60s + jitter (P1) |
| ASH-01 | Integration Logic | L1 | Uncomment Route + RateLimit code interfaces (P0) |
| ASH-03 | Actuator Wiring | L2 | Workflow email_alert → Communication.send_email (P1) |
| ASH-04 | Actuator Wiring | L3 | Approval get_approval_process → real DB query (P1) |
| T105 | Knowledge | L3 | IKE/SMRITI SyncBridge — bidirectional knowledge sync (P1) |

### Priority 2: Expand Fractal Coverage

- Reduce remaining 16 Agda holes (target: 12)
- Activate remaining Quint stub modules (target: 30/70 active)
- VSM System1-5 supervision tree wiring
- GR-L2-03: SentinelBridge RequestsPerSecond real wiring
- GR-L3-01: PlanningEnforcer → Zenoh publish
- GR-L1-03: ConfigBridge Zenoh integration tests

### Priority 3: Quality & Coverage Depth

- Test suite quality upgrade pass (LOW→STANDARD for critical paths)
- Integration test suites (cross-module scenarios)
- Performance test suites
- F#↔Elixir parity tests (Apoptosis, ConfigBridge)
- CRM automation integration tests (LeadAssignment, Workflow, Approval)

### Priority 4: Fractal Layer Push (L6-L7)

- **L6-L7 Fractal Push**: Target 30% cluster, 15% federation coverage
- **Planetary diagonal (7,7)**: Implement SC-FRAC-001 cluster AI quorum
- **Stellar diagonal (8,8)**: Implement SC-FRAC-006 federation version negotiation
- Wire remaining CRM automation TODOs (territory, skills, webhooks)
- Gemini Gap Round 3: GR-L3-02, GR-L6-02, GR-L6-03 (parity docs, tests)

### Expected Sprint 55 Coherence Targets

| Metric | Post-S54 | Post-S55 Target | Delta |
|--------|----------|-----------------|-------|
| F# Cognitive Plane | 85% | 95% | +10pp |
| Overall Fractal Coherence | 70% | 78% | +8pp |
| L6 Cluster Coverage | 26% | 35% | +9pp |
| F#↔Elixir Parity | 85% | 92% | +7pp |
| Zenoh Wiring | 80% | 90% | +10pp |
| Ash Stub Count | 6 | 2 | −4 |
| System RPN Max | 168 | 50 | −70% |

---

## Level 20: Gemini Cybernetic Architect Deep System Gap Analysis (2026-03-21)

### 20.1 Analysis Summary — Bicameral Blindness & Scope Underestimation

The Gemini "Cybernetic Architect" audit identified 4 critical gaps that would prevent the system
from reaching true SIL-6 state. Each gap is classified by priority, has a 5-order impact analysis,
FMEA risk scoring, and STAMP constraint mapping.

### 20.2 Gap 1: The Cognitive Plane Gap (P0 — CRITICAL)

**Issue**: Sprint 54 plan identifies 637 Elixir modules for testing but entirely omits the F# track (lib/cepaf/).

**Evidence**:
- F# source files: **652** in `lib/cepaf/src/`
- F# test files: **76** in `lib/cepaf/test/`
- Test coverage: **~12%** (76/652)
- F# is the system's "Cortex" (Cognitive Plane) — a tested "Body" (Elixir) with untested "Brain" (F#) is architecturally unstable

**5-Order Impact Analysis**:
| Order | Effect | Time Scale |
|-------|--------|-----------|
| 1st | F# modules lack regression detection | Immediate |
| 2nd | Silent regressions in MeshCLI, DigitalTwin, SprintOrchestrator | Hours |
| 3rd | Cognitive Plane failures cascade to Elixir via CEPAF bridge | Hours-Days |
| 4th | SIL-6 compliance compromised — untested safety-critical F# paths | Days |
| 5th | GA release blocked — "Brain" lacks formal verification parity | Weeks |

**FMEA**:
| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| FM-54-33: Untested F# modules regress silently | 9 | 7 | 8 | 504 | T108: 100% Expecto coverage |
| FM-54-34: F# bridge breaks without test detection | 8 | 5 | 7 | 280 | T108: Cross-bridge integration tests |

**STAMP**: SC-COV-001 (100% critical paths), SC-COV-002 (95% runtime), SC-SIL6-001 (PFH < 10⁻¹²)
**AOR**: AOR-TEST-006 (Coverage >= 95%), AOR-GA-008 (Test coverage >= 95%)

**Task Assignment**:

| ID | Task | Domain | Priority | Description |
|----|------|--------|----------|-------------|
| T108 | Cortex Coverage | F# / CEPAF | P0 | 100% Expecto coverage for 652 .fs source files in lib/cepaf/src — expand from 76 to ~652 test files |

### 20.3 Gap 2: Web Layer Under-Representation (P1 — HIGH)

**Issue**: Wave 7 allocates only 15 modules for the Web Layer. Actual IndrajaalWeb has 138 files with 79 uncovered.

**Evidence**:
- `lib/indrajaal_web/` files: **138**
- `test/indrajaal_web/` files: **54**
- Uncovered: **79 modules** (57%)
- Includes: controllers, LiveViews, plugs, channels, components

**5-Order Impact Analysis**:
| Order | Effect | Time Scale |
|-------|--------|-----------|
| 1st | Web layer mutations undetected by tests | Immediate |
| 2nd | Prajna cockpit LiveViews regress silently | Hours |
| 3rd | API endpoints break without coverage | Days |
| 4th | User-facing features degrade without regression safety net | Days-Weeks |
| 5th | GA release missing "Interface" layer robustness | Weeks |

**FMEA**:
| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| FM-54-35: Untested LiveView components break | 7 | 6 | 7 | 294 | T109: Full web hierarchy tests |
| FM-54-36: API controllers regress silently | 8 | 5 | 6 | 240 | T109: Controller ConnTest coverage |

**STAMP**: SC-BDD-001 (All user stories MUST have BDD scenarios), SC-COV-001
**AOR**: AOR-BDD-001 (Write feature file BEFORE implementation)

**Task Assignment**:

| ID | Task | Domain | Priority | Description |
|----|------|--------|----------|-------------|
| T109 | Web Hierarchy | IndrajaalWeb | P1 | Expand from 54 to 138 test files — cover all 79 uncovered controllers, LiveViews, plugs, channels |

### 20.4 Gap 3: The "Silent DNA" Risk — SHA3-256 (P0 — CRITICAL)

**Issue**: ForensicAuditTrail uses SHA-256 but CLAUDE.md §0.1 mandates SHA3-256. Formal proofs about state consistency are meaningless if the underlying hash is wrong.

**Evidence**:
- CLAUDE.md §0.1: "SHA3-256 (Block Hash)" — explicit specification
- `lib/indrajaal/compliance/forensic_audit_trail.ex`: Uses `:crypto.hash(:sha256, ...)` (SHA-256, NOT SHA3-256)
- `lib/indrajaal/core/holon/state.ex`: Uses `:crypto.hash(:sha256, ...)`
- T104 (Level 19) already identified this — Gemini escalates priority to Wave 1 foundational prerequisite

**5-Order Impact Analysis**:
| Order | Effect | Time Scale |
|-------|--------|-----------|
| 1st | Hash function non-compliant with specification | Immediate |
| 2nd | All chain verification based on wrong hash | Hours |
| 3rd | Immutable Register integrity proofs invalid | Days |
| 4th | SIL-6 compliance claim undermined | Days |
| 5th | Agda formal proofs about chain consistency become vacuously true | Weeks |

**FMEA**:
| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| FM-54-37: SHA-256/SHA3-256 spec mismatch | 10 | 10 | 3 | 300 | T104: Crypto upgrade (already tracked) |

**STAMP**: SC-SIL6-010 (Quantum-resistant cryptography), SC-SIL6-015 (Immutable audit trail)
**AOR**: AOR-REG-002 (Verify hash chain integrity on startup)

**Gemini Recommendation**: Move T104 to Wave 1 foundational prerequisite. All safety-critical test assertions about hash chains are invalid until SHA3-256 is the actual hash function.

### 20.5 Gap 4: Metabolic Drag — OODA Latency (P1 — HIGH)

**Issue**: Adding ~115,000+ lines of test code will blow the 30-Second OODA Mandate. 1,500+ test files exert massive metabolic pressure without a Fast-Path selector.

**Evidence**:
- Current test files: 829 (test/indrajaal/) + 54 (test/indrajaal_web/) + others = ~1,100+
- After W11 swarm: projected ~1,550+
- `mix test` on all files: **~5-10 minutes** (far exceeds 30s OODA)
- No holonic test runner exists — `mix test` runs ALL tests every time

**5-Order Impact Analysis**:
| Order | Effect | Time Scale |
|-------|--------|-----------|
| 1st | Developer `mix test` takes 5-10 minutes | Immediate |
| 2nd | OODA cycle collapses — feedback latency > 30s (SC-OODA-001 violation) | Minutes |
| 3rd | Developer productivity drops — longer iteration cycles | Hours |
| 4th | CI pipeline slows — merge velocity decreases | Days |
| 5th | Sprint velocity decreases due to metabolic overhead | Weeks |

**FMEA**:
| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| FM-54-38: OODA latency exceeds 30s mandate | 7 | 9 | 2 | 126 | T110: ExUnit partitions + T111: Holonic runner |
| FM-54-39: CI pipeline timeout on 1,500+ tests | 6 | 7 | 3 | 126 | T110: 4-8 partition parallel execution |

**STAMP**: SC-OODA-001 (Cycle time <100ms), SC-BIO-001 (OODA cycle < 100ms)
**AOR**: AOR-BIO-001 (Execute in fast OODA mode with 30s cycles)

**Task Assignment**:

| ID | Task | Domain | Priority | Description |
|----|------|--------|----------|-------------|
| T110 | ExUnit Partitions | CI/CD Infra | P1 | Configure CI to run tests in 4-8 parallel partitions via `MIX_TEST_PARTITION` + `--partitions N` |
| T111 | Holonic Runner | Dev Tooling | P1 | Create `mix test.holon` task — runs only tests for modified holons + immediate dependencies using `git diff --name-only` + dependency graph |

### 20.6 Gap 5: NIF Coverage (P2 — MEDIUM)

**Issue**: Rust NIFs (zenoh_nif, lineage_auth) lack unit-level test coverage.

**Evidence**:
- `native/zenoh_nif/` — 15 unsafe blocks, Rustler NIF
- `native/zenoh_ffi/` — 13 C ABI functions, cdylib (F# FFI tests exist: 31 tests)
- No `#[test]` modules in zenoh_nif Rust code

**Task Assignment**:

| ID | Task | Domain | Priority | Description |
|----|------|--------|----------|-------------|
| T112 | NIF Coverage | Rust / Native | P2 | Add `#[test]` modules for zenoh_nif and lineage_auth crates — basic unit tests for all unsafe blocks |

---

## Level 21: System-Wide Parity & CI/CD Metabolic Optimization

### 21.1 Complete Task Registry (T108-T112)

| ID | Task | Domain | Priority | Layer | STAMP | RPN | Status |
|----|------|--------|----------|-------|-------|-----|--------|
| T108 | Cortex Coverage | F# / CEPAF | P0 | L3 | SC-COV-001, SC-SIL6-001 | 504 | PLANNED |
| T109 | Web Hierarchy | IndrajaalWeb | P1 | L1 | SC-BDD-001, SC-COV-001 | 294 | PLANNED |
| T110 | ExUnit Partitions | CI/CD | P1 | L4 | SC-OODA-001, SC-METRICS-003 | 126 | PLANNED |
| T111 | Holonic Runner | Dev Tooling | P1 | L0 | SC-BIO-001, AOR-BIO-001 | 126 | PLANNED |
| T112 | NIF Coverage | Rust / Native | P2 | L0 | SC-FFI-001, SC-COV-001 | 80 | PLANNED |

### 21.2 ExUnit Partition Architecture (T110)

```elixir
# config/test.exs addition
config :indrajaal, :test_partitions, 4

# CI pipeline (GitHub Actions / Jenkins)
# Parallel matrix strategy:
# - partition 1: mix test --partitions 4 --partition 1
# - partition 2: mix test --partitions 4 --partition 2
# - partition 3: mix test --partitions 4 --partition 3
# - partition 4: mix test --partitions 4 --partition 4

# Test tagging taxonomy for partition-aware execution:
# @tag :unit          — Pure logic tests (no DB, no GenServer)
# @tag :integration   — DB/GenServer tests
# @tag :sil4          — Safety-critical tests
# @tag :fmea          — Failure mode tests
# @tag :zenoh_nif     — Zenoh NIF dependency
# @tag :requires_containers — Live container tests
```

### 21.3 Holonic Test Runner Architecture (T111)

```elixir
# mix test.holon — runs only tests for modified holons

# Algorithm:
# 1. git diff --name-only HEAD~1 → modified_files
# 2. For each modified lib/indrajaal/X.ex → test/indrajaal/X_test.exs
# 3. Resolve dependency graph (xref) → add dependent test files
# 4. Run: mix test [resolved_files]

# Implementation: lib/mix/tasks/test.holon.ex
defmodule Mix.Tasks.Test.Holon do
  use Mix.Task

  def run(_args) do
    modified = get_modified_files()
    test_files = resolve_test_files(modified)
    deps = resolve_dependencies(modified)
    dep_tests = resolve_test_files(deps)
    all_tests = Enum.uniq(test_files ++ dep_tests)

    Mix.Task.run("test", all_tests)
  end
end
```

### 21.4 Updated FMEA Registry (Sprint 54 Complete)

| ID | Failure Mode | S | O | D | RPN | Status | Mitigation |
|----|--------------|---|---|---|-----|--------|------------|
| FM-54-33 | Untested F# modules regress silently | 9 | 7 | 8 | 504 | OPEN | T108 |
| FM-54-37 | SHA-256/SHA3-256 spec mismatch | 10 | 10 | 3 | 300 | OPEN | T104 |
| FM-54-35 | Untested LiveView components break | 7 | 6 | 7 | 294 | OPEN | T109 |
| FM-54-34 | F# bridge breaks without detection | 8 | 5 | 7 | 280 | OPEN | T108 |
| FM-54-36 | API controllers regress silently | 8 | 5 | 6 | 240 | OPEN | T109 |
| FM-54-31 | Cross-layer boundary violations | 8 | 6 | 7 | 336 | OPEN | T106 |
| FM-54-38 | OODA latency exceeds 30s mandate | 7 | 9 | 2 | 126 | OPEN | T110 |
| FM-54-39 | CI pipeline timeout on 1,500+ tests | 6 | 7 | 3 | 126 | OPEN | T110 |

### 21.5 Updated Sprint 54 Task Summary

| Level | Tasks | IDs | Focus |
|-------|-------|-----|-------|
| 1-18 | 102 | T1-T102 | Original test coverage plan |
| 19 | 5 | T103-T107 | Gemini deep architecture risks |
| 20 | 3 | T108-T109, T104 escalation | Gemini Cybernetic Architect gap analysis |
| 21 | 3 | T110-T112 | CI/CD metabolic optimization |
| **Total** | **112** | T1-T112 | |

### 21.6 Updated Completeness Assessment

| Dimension | Pre-Level-20 | Post-Level-21 | Delta |
|-----------|-------------|---------------|-------|
| Task count | 107 | 112 | +5 |
| Elixir test coverage plan | 74% | 100% (with W11 swarm) | +26pp |
| F# test coverage plan | 0% (omitted) | 100% (T108 planned) | +100pp |
| Web layer plan | 15 modules | 138 modules (T109) | +123 |
| CI velocity plan | None | Partitioned + Holonic (T110-T111) | NEW |
| NIF coverage plan | None | T112 planned | NEW |
| Crypto compliance plan | Deferred | Wave 1 priority (T104 escalated) | ESCALATED |
| Overall plan completeness | 94% | 98% | +4pp |

### 21.7 Sprint 55 Carry-Forward (Updated)

| Priority | Tasks | Description |
|----------|-------|-------------|
| P0 | T104, T108 | SHA3-256 crypto upgrade, F# Cortex 100% Expecto coverage |
| P1 | T109, T110, T111 | Web hierarchy tests, ExUnit partitions, Holonic runner |
| P1 | T103, T105, T106 | F# stub triage, IKE/SMRITI sync, fractal integration |
| P2 | T107, T112 | CI partitioning, NIF coverage |
