# 2026-03-20 20:00 — Sprint 54: 100% Test Coverage Epic — PLAN

## Context
- Branch: main
- Previous sprint: Sprint 53 (Authentication Hardening + Math Discipline Wiring)
- Version: v21.3.0-SIL6
- Base commit: 2c7260841

## Summary

Sprint 54 is a **multi-wave test coverage epic** targeting 100% module test coverage
across the entire Indrajaal codebase. Research identified **577 untested modules**
(198,747 lines) requiring test suites. The sprint also addresses formal verification
gaps (22 Agda holes, 11 commented Quint constraints) and residual TODOs.

### Scope Scale

| Category | Files | Lines | Priority |
|----------|-------|-------|----------|
| CRITICAL (>500 lines) | 141 | 107,313 | P0-P1 |
| HIGH (200-500 lines) | 214 | 76,225 | P1-P2 |
| MEDIUM (100-200 lines) | 53 | 7,434 | P2 |
| LOW (<100 lines) | 169 | 7,775 | P3 |
| **TOTAL** | **577** | **198,747** | — |

### Research Inputs (4 parallel analysis agents)

1. **Stub Inventory**: 0 traditional stubs remaining. 130 TODOs across 57 files — mostly
   deferred integrations (email/HTTP), scaffold defaults, and observability enhancements.
   3 MEDIUM-priority items: approval DB wiring, token refresh, contractor regex.

2. **Math Gap Registry**: 0 P0/P1 gaps. 5 P2 (CategoryTheory Agda, VSM supervision,
   SwarmIntelligence convergence). 14 P3 (benchmarks, adaptive tuning, FPPS modularization).
   PetriNets RPN still 315 in F# monitor despite being CONNECTED — needs update.

3. **Formal Verification**: 22 Agda holes in 8 files, 48 postulates in 10 files.
   11/24 Quint constraints commented (SC-VAL, SC-CNT, SC-AGT). Only ~12% of 641+
   STAMP constraints have active Quint specs. ~31% average L0-L7 coverage.

4. **Test Coverage Inventory**: 577 untested .ex files across all domains. Top 20 by
   severity include symbiotic_defense.ex (1,924 lines), security_intelligence_engine.ex
   (1,217), access_control/analytics_engine.ex (1,185), cluster/zenoh_mesh.ex (1,157),
   alarms/timescaledb_integration.ex (1,040).

---

## Sprint 54 Plan: 8 Waves, 96 Task Groups, Multi-Round

### Architecture: Batched Test Generation

577 modules are grouped into **8 waves** by domain criticality (FMEA-ranked).
Each wave generates test suites for a domain cluster, followed by compile+quality gates.

```
Wave 1 (P0): Safety + Security — 17 files, 7,583 lines
Wave 2 (P0): Sprint 53 Untested — 9 files, 4,200 lines
Wave 3 (P1): Alarms + Core Domain — 40 files, 16,860 lines
Wave 4 (P1): Cybernetic + AI + Mesh — 86 files, 30,732 lines
Wave 5 (P1): KMS + Observability + Integration — 106 files, 37,884 lines
Wave 6 (P2): Cockpit + Testing Infra + CRM — 67 files, 25,600 lines
Wave 7 (P2): Deployment + Distributed + Web — 83 files, 28,913 lines
Wave 8 (P3): Utility + Low-Priority + Formal Verification — 169 files, 47,975 lines
```

### Execution Strategy

Given the scale (577 files), this sprint uses **parallel agent test generation**:
- Each wave deploys test-generator agents (up to 10 parallel)
- Tests are generated in batches of 10-15 modules
- Compile gate after each batch
- Quality gate after each wave
- Estimated: 8 rounds of execution

---

## Level 1: Executive Summary

Sprint 54 achieves **100% module test coverage** for the Indrajaal codebase. All 577
currently untested .ex modules receive at minimum a basic test suite (module existence,
public API contract verification, error boundary tests). Critical modules (>500 lines)
receive full TDG-compliant test suites with property tests. The sprint also activates
11 Quint constraints, proves 6 Agda holes, and fixes F# MathMonitor RPNs.

Expected outcomes:
- +577 test files (~115,000+ test lines)
- +2,000+ individual test cases
- 11 Quint constraints activated (13/24 → 24/24)
- 6 Agda holes proven (22 → 16)
- System RPN ~80 → ~30
- Module test coverage: ~63% → 100%

---

## Level 2: Wave Specifications

### Wave 1 — Safety + Security (P0, GA-BLOCKING)

**Goal**: Test suites for all safety-critical and security modules. These are the
highest-risk untested modules — a security bug here has maximum blast radius.

| Task ID | Module | Lines | Tests | RPN |
|---------|--------|-------|-------|-----|
| S54-T1 | security_policy.ex | 662 | ~25 | 216 |
| S54-T2 | communication.ex | 877 | ~30 | 210 |
| S54-T3 | symbiotic_defense.ex | 1,924 | ~45 | 200 |
| S54-T4 | security_intelligence_engine.ex | 1,217 | ~35 | 192 |
| S54-T5 | guardian.ex (safety/) | 385 | ~20 | 180 |
| S54-T6 | guardian_verifier.ex | 280 | ~15 | 168 |
| S54-T7 | sentinel_health.ex | 312 | ~18 | 160 |
| S54-T8 | pattern_hunter.ex | 289 | ~15 | 156 |
| S54-T9 | threat_analyzer.ex | 267 | ~14 | 150 |
| S54-T10 | security_audit.ex | 234 | ~12 | 144 |
| S54-T11 | access_control/analytics_engine.ex | 1,185 | ~35 | 192 |
| S54-T12 | compliance/audit_engine.ex | 378 | ~20 | 168 |
| S54-T13 | authentication/*.ex (remaining) | ~450 | ~20 | 160 |
| S54-T14 | authorization/*.ex (remaining) | ~320 | ~15 | 148 |
| S54-T15 | encryption/*.ex | ~280 | ~12 | 140 |
| S54-T16 | security/*.ex (remaining) | ~440 | ~18 | 135 |
| S54-T17 | Gate: compile + format + credo | — | — | — |

**Files**: 17 modules, 7,583 lines
**Expected**: ~350 tests, ~7,000 test lines
**STAMP**: SC-AUTH-001..004, SC-SEC-044..047, SC-IMMUNE-001..004, SC-COV-001

### Wave 2 — Sprint 53 Untested Modules (P0)

**Goal**: Cover all new implementations from Sprint 53 that shipped without tests.

| Task ID | Module | Lines | Tests | RPN |
|---------|--------|-------|-------|-----|
| S54-T18 | crm/analytics/forecasting.ex | 149 | ~15 | 120 |
| S54-T19 | crm/analytics/pipeline.ex | 252 | ~18 | 120 |
| S54-T20 | smriti/senses/extractors.ex | 349 | ~20 | 90 |
| S54-T21 | jain/propagation.ex | 408 | ~20 | 54 |
| S54-T22 | crm/automation/assignment_rule.ex | 98 | ~12 | 36 |
| S54-T23 | crm/automation/workflow_rule.ex | 120 | ~15 | 36 |
| S54-T24 | crm/automation/approval_request.ex | 180 | ~18 | 36 |
| S54-T25 | accounts/session_security.ex | 84 | ~10 | 72 |
| S54-T26 | accounts/authentication.ex (emails) | 44 | ~8 | 60 |
| S54-T27 | Gate: compile + format + credo | — | — | — |

**Files**: 9 modules, ~4,200 lines (from Sprint 53 new code)
**Expected**: ~136 tests, ~2,700 test lines
**STAMP**: SC-COMM-001, SC-AUTO-001, SC-COV-002

### Wave 3 — Alarms + Core Domain Logic (P1)

**Goal**: Test suites for the alarm processing chain and core domain modules.

| Task ID | Modules | Count | Lines | RPN Range |
|---------|---------|-------|-------|-----------|
| S54-T28 | alarms/*.ex | 16 | 9,426 | 90-168 |
| S54-T29 | alarms/timescaledb_integration.ex | 1 | 1,040 | 168 |
| S54-T30 | sites/*.ex | 8 | 3,200 | 80-120 |
| S54-T31 | devices/*.ex | 6 | 2,800 | 80-110 |
| S54-T32 | dispatch/*.ex | 5 | 2,100 | 70-100 |
| S54-T33 | maintenance/*.ex | 4 | 1,294 | 60-90 |
| S54-T34 | Gate: compile + format + credo | — | — | — |

**Files**: 40 modules, ~16,860 lines
**Expected**: ~400 tests, ~8,000 test lines
**STAMP**: SC-COV-001, SC-COV-002

### Wave 4 — Cybernetic + AI + Mesh (P1)

**Goal**: Test suites for the intelligent subsystem — AI inference, mesh networking,
cybernetic control loops.

| Task ID | Modules | Count | Lines | RPN Range |
|---------|---------|-------|-------|-----------|
| S54-T35 | cybernetic/inference/*.ex | 12 | 5,200 | 80-140 |
| S54-T36 | cybernetic/cortex/*.ex | 8 | 3,600 | 80-130 |
| S54-T37 | cybernetic/evolution/*.ex | 6 | 2,400 | 70-120 |
| S54-T38 | cluster/zenoh_mesh.ex | 1 | 1,157 | 168 |
| S54-T39 | cluster/*.ex (remaining) | 10 | 4,200 | 70-120 |
| S54-T40 | mesh/*.ex | 12 | 4,500 | 60-100 |
| S54-T41 | distributed/*.ex | 8 | 3,200 | 60-100 |
| S54-T42 | cortex_integration/*.ex | 6 | 2,400 | 50-90 |
| S54-T43 | swarm/*.ex | 5 | 2,100 | 50-80 |
| S54-T44 | active_inference_runtime/*.ex | 4 | 1,600 | 50-80 |
| S54-T45 | flame/*.ex | 4 | 375 | 40-60 |
| S54-T46 | Gate: compile + format + credo | — | — | — |

**Files**: 86 modules, ~30,732 lines
**Expected**: ~650 tests, ~13,000 test lines
**STAMP**: SC-AI-001..008, SC-MESH-001..010, SC-BRIDGE-001..005

### Wave 5 — KMS + Observability + Integration (P1)

**Goal**: Test suites for knowledge management, observability stack, and integration modules.

| Task ID | Modules | Count | Lines | RPN Range |
|---------|---------|-------|-------|-----------|
| S54-T47 | kms/*.ex | 20 | 7,500 | 60-120 |
| S54-T48 | kms/ai/*.ex | 8 | 2,800 | 60-100 |
| S54-T49 | smriti/*.ex (remaining) | 12 | 3,473 | 50-90 |
| S54-T50 | observability/*.ex | 24 | 8,100 | 50-100 |
| S54-T51 | observability/otlp/*.ex | 12 | 3,200 | 50-80 |
| S54-T52 | observability/dashboards/*.ex | 12 | 2,950 | 40-70 |
| S54-T53 | integration/*.ex | 18 | 9,861 | 60-120 |
| S54-T54 | Gate: compile + format + credo | — | — | — |

**Files**: 106 modules, ~37,884 lines
**Expected**: ~800 tests, ~16,000 test lines
**STAMP**: SC-OBS-069..071, SC-AI-001, SC-HOLON-009

### Wave 6 — Cockpit + Testing Infra + CRM (P2)

**Goal**: Test suites for the Prajna cockpit, testing infrastructure, and CRM domain.

| Task ID | Modules | Count | Lines | RPN Range |
|---------|---------|-------|-------|-----------|
| S54-T55 | cockpit/prajna/*.ex | 21 | 8,767 | 50-100 |
| S54-T56 | cockpit/prajna/smart_metrics.ex | 1 | 680 | 90 |
| S54-T57 | cockpit/prajna/ai_copilot.ex | 1 | 520 | 85 |
| S54-T58 | testing/*.ex | 15 | 7,200 | 40-80 |
| S54-T59 | testing/evolution/*.ex | 8 | 4,262 | 40-70 |
| S54-T60 | crm/*.ex (remaining) | 12 | 3,200 | 30-60 |
| S54-T61 | crm/analytics/*.ex (remaining) | 10 | 1,971 | 30-50 |
| S54-T62 | Gate: compile + format + credo | — | — | — |

**Files**: 67 modules, ~25,600 lines (estimated)
**Expected**: ~500 tests, ~10,000 test lines
**STAMP**: SC-PRAJNA-001..005, SC-TDG-001..003

### Wave 7 — Deployment + Distributed + Web (P2)

**Goal**: Test suites for deployment orchestration, distributed systems, and web layer.

| Task ID | Modules | Count | Lines | RPN Range |
|---------|---------|-------|-------|-----------|
| S54-T63 | deployment/*.ex | 15 | 6,200 | 40-80 |
| S54-T64 | deployment/wave_executor.ex | 1 | 850 | 80 |
| S54-T65 | coordination/*.ex | 8 | 3,200 | 40-70 |
| S54-T66 | policy/*.ex | 6 | 2,400 | 40-60 |
| S54-T67 | billing/*.ex | 5 | 2,000 | 30-50 |
| S54-T68 | identity/*.ex | 5 | 1,800 | 30-50 |
| S54-T69 | video/*.ex (analytics, streaming) | 12 | 4,800 | 50-90 |
| S54-T70 | visitor_management/*.ex | 6 | 2,400 | 30-50 |
| S54-T71 | guard_tour/*.ex | 5 | 1,800 | 30-50 |
| S54-T72 | work_order/*.ex | 5 | 1,600 | 30-50 |
| S54-T73 | indrajaal_web/**/*.ex (remaining) | 15 | 1,863 | 20-40 |
| S54-T74 | Gate: compile + format + credo | — | — | — |

**Files**: 83 modules, ~28,913 lines (estimated)
**Expected**: ~600 tests, ~12,000 test lines
**STAMP**: SC-CNT-009..012, SC-PRF-050

### Wave 8 — Utility + Low-Priority + Formal Verification (P3)

**Goal**: Cover remaining utility modules (<100 lines), activate Quint constraints,
prove Agda holes, fix F# monitor, remediate TODOs.

| Task ID | Target | Count/Description |
|---------|--------|-------------------|
| S54-T75 | Utility modules <100 lines (batch 1-5) | 85 files, ~3,900 lines |
| S54-T76 | Utility modules <100 lines (batch 6-10) | 84 files, ~3,875 lines |
| S54-T77 | Activate 11 commented Quint constraints | STAMPConstraints.qnt |
| S54-T78 | Reduce 6 Agda holes (cross_holon_database.agda) | 6 proofs |
| S54-T79 | Fix F# MathMonitor PetriNet RPN 315→30 | MathematicalSystemMonitor.fs |
| S54-T80 | Approval workflow DB wiring (3 stubs) | approval.ex |
| S54-T81 | Token refresh persistence | token_refresh.ex |
| S54-T82 | Contractor regex re-enable | contractor_management.ex |
| S54-T83 | Gate: compile + format + credo | — |
| S54-T84 | Final verification + journal + commit | — |

**Files**: 169 utility + 3 TODO files + 2 formal spec files
**Expected**: ~350 tests, ~7,000 test lines
**STAMP**: SC-MATH-005, SC-FUNC-001, SC-CHG-001

---

## Level 3: Task Specifications (Per-Function Detail)

### S54-T1: SecurityPolicy Test Suite

**File**: `test/indrajaal/security_policy_test.exs` (~600 lines)
**Module**: `lib/indrajaal/security_policy.ex` (662 lines, 7 functions)

```
authenticate/1 (4 pattern clauses)
├── Test: valid credentials with email+password → {:ok, user}
├── Test: valid credentials with token → {:ok, user}
├── Test: invalid password → {:error, :invalid_credentials}
├── Test: missing email → {:error, :invalid_credentials}
├── Test: nil input → {:error, :invalid_credentials}
└── Property: authenticate always returns {:ok, _} | {:error, _}

authorize/2 (6-level RBAC)
├── Test: super_admin can access all resources
├── Test: admin can access admin-level resources
├── Test: operator cannot access admin resources
├── Test: viewer has read-only access
├── Test: guest has minimal access
├── Test: unknown role → {:error, :unauthorized}
└── Property: role hierarchy is transitive

validate_access/2
├── Test: valid user + valid resource → :ok
├── Test: expired session → {:error, :session_expired}
└── Test: revoked access → {:error, :access_revoked}

enforce_policies/3, enforce_subscription_security/3
├── Test: active subscription → :ok
├── Test: expired subscription → {:error, :subscription_expired}
└── Test: policy violation → {:error, :policy_violation}

create_policies/1, apply_policies/2
├── Test: create valid policy set → {:ok, policies}
├── Test: apply policies to request → filtered result
└── Test: conflicting policies → most restrictive wins
```

### S54-T2: Communication Test Suite

**File**: `test/indrajaal/communication_test.exs` (~700 lines)
**Module**: `lib/indrajaal/communication.ex` (877 lines, 5 channels)

```
send_email/1
├── Test: valid email params → {:ok, _}
├── Test: missing recipient → {:error, :invalid_recipient}
├── Test: console backend logs message
└── Test: telemetry event emitted

send_sms/1
├── Test: valid phone + message → {:ok, _}
├── Test: invalid phone format → {:error, :invalid_phone}
└── Test: telemetry event emitted

send_push_notification/2
├── Test: valid device_token + payload → {:ok, _}
├── Test: missing device_token → {:error, :invalid_device}
└── Test: telemetry event emitted

initiate_voice_call/1
├── Test: valid call params → {:ok, _}
├── Test: missing phone → {:error, _}
└── Test: telemetry event emitted

send_pager/1
├── Test: valid pager params → {:ok, _}
└── Test: telemetry event emitted

Cross-cutting:
├── Property: all channels return {:ok, _} | {:error, _}
├── Test: backend adapter selection (console vs production)
└── Test: telemetry events on every send
```

### S54-T3: SymbioticDefense Test Suite

**File**: `test/indrajaal/safety/symbiotic_defense_test.exs` (~900 lines)
**Module**: `lib/indrajaal/safety/symbiotic_defense.ex` (1,924 lines)

```
assess_threat/1
├── Test: known threat pattern → {:threat, level, details}
├── Test: unknown pattern → {:safe, :no_threat}
├── Test: nil input → {:error, :invalid_input}
└── Property: threat level ∈ [:low, :medium, :high, :critical]

execute_recovery/1
├── Test: process restart recovery
├── Test: circuit breaker activation
├── Test: tenant isolation
├── Test: emergency shutdown
└── Test: unknown recovery type → {:error, :unknown}

coordinate_defense/2
├── Test: multi-layer defense coordination
├── Test: escalation protocol
└── Test: telemetry emission

immune_response/1
├── Test: pattern detection → antibody generation
├── Test: memory immune response (faster on repeat)
└── Test: cross-module immune signaling
```

### S54-T4: SecurityIntelligenceEngine Test Suite

**File**: `test/indrajaal/security/security_intelligence_engine_test.exs` (~600 lines)
**Module**: `lib/indrajaal/security/security_intelligence_engine.ex` (1,217 lines)

```
analyze_security_event/1
├── Test: intrusion detection → alert generated
├── Test: access anomaly → risk scored
├── Test: compliance violation → logged

generate_intelligence_report/1
├── Test: valid time range → report with metrics
├── Test: empty data → empty report

correlate_events/2
├── Test: related events grouped
├── Test: unrelated events separated
└── Property: correlation is symmetric
```

### S54-T11: AccessControl AnalyticsEngine Test Suite

**File**: `test/indrajaal/access_control/analytics_engine_test.exs` (~600 lines)
**Module**: `lib/indrajaal/access_control/analytics_engine.ex` (1,185 lines)

```
generate_access_report/1
├── Test: valid params → report with metrics
├── Test: date range filtering
├── Test: user-level drill-down

analyze_patterns/1
├── Test: anomaly detection in access logs
├── Test: peak usage identification
└── Property: pattern scores ∈ [0.0, 1.0]
```

### S54-T18..T26: Sprint 53 Module Tests (Detailed)

```
Forecasting (S54-T18):
├── sum_by_category/2: groups and sums correctly
├── adjust_forecast/3: applies adjustment factor
├── forecast_accuracy/2: computes MAPE-like metric
└── Property: sum_by_category totals match input sum

Pipeline (S54-T19):
├── calculate_stage_metrics/1: correct stage counts
├── conversion_rates/1: rates between 0.0-1.0
├── sales_velocity/1: positive velocity for valid data
├── win_rate/1: win_rate ∈ [0.0, 1.0]
└── Property: conversion_rates values ≤ 1.0

SMRITI Extractors (S54-T20):
├── parse_pdf/1: valid PDF binary (magic bytes %PDF) → {:ok, metadata}
├── parse_pdf/1: invalid binary → {:error, :invalid_pdf}
├── parse_pdf/1: path dispatch → reads file then parses
├── transcribe/1: MP3/WAV/OGG/FLAC/M4A/AAC/WMA/AIFF signatures
├── transcribe/1: unknown format → {:error, :unsupported_format}
└── telemetry events emitted for all operations

Jain Propagation (S54-T21):
├── discover_via_federation/1: Constitution endpoints + ETS announced peers
├── discover_via_dns/1: DNS SRV lookup returns addresses
├── discover_via_peers/1: registered peers returned from ETS
├── register_peer/1: registers new peer, idempotent
├── get_invitations/1: TTL-expired entries filtered
├── get_cached_assessment/1: TTL-expired entries filtered
└── ensure_tables/0: creates tables if not exist, idempotent

CRM Assignment (S54-T22):
├── matches?/2: AND criteria evaluation
├── matches?/2: String.to_existing_atom safety
└── active_by_object/2: sorted by order, active only

CRM Workflow (S54-T23):
├── should_trigger?/3: inactive rule → false, trigger_type matching
├── execute/3: field_update, email_alert, create_task, unknown action
└── telemetry events emitted

CRM Approval (S54-T24):
├── approve/3: advances step, marks :approved at final
├── reject/3: marks :rejected with history
├── escalate/3: advances without approving
└── pending_for_user/2: returns pending requests

Session Security (S54-T25):
├── store_session/1 + load_session/1: roundtrip
├── load_session/1: TTL expired → nil
├── invalidate_session/1: removed from ETS
└── get_active_sessions_for_user/1: filters by user_id

Auth Emails (S54-T26):
├── send_confirmation_email/2: delegates to Communication.send_email/1
└── send_password_reset_email/2: delegates to Communication.send_email/1
```

### S54-T28..T33: Alarms + Core Domain (Batch Specs)

```
Alarms domain (S54-T28, 16 files):
├── alarm_processor.ex: process/1, classify/1, correlate/2
├── alarm_engine.ex: evaluate_rules/2, apply_actions/2
├── alarm_correlation.ex: correlate_batch/1, find_root_cause/1
├── alarm_notification.ex: notify/2, escalate/2
├── alarm_storm_detector.ex: detect_storm/1, storm_active?/0
├── zone_mapper.ex: map_to_zone/2, zone_hierarchy/1
└── [10 more alarm modules with basic contract tests]

TimescaleDB Integration (S54-T29, 1,040 lines):
├── insert_alarm_event/1: hypertable insertion
├── query_alarm_history/2: time-range queries
├── aggregate_alarm_stats/1: TimescaleDB continuous aggregates
└── retention_policy/0: data lifecycle management

Sites (S54-T30, 8 files): basic CRUD + hierarchy tests
Devices (S54-T31, 6 files): health matrix + status tests
Dispatch (S54-T32, 5 files): assignment + routing tests
Maintenance (S54-T33, 4 files): work order + scheduling tests
```

### S54-T35..T45: Cybernetic + AI + Mesh (Batch Specs)

```
Cybernetic Inference (S54-T35, 12 files):
├── active_inference.ex: infer_system_state/1, FEP cycle
├── bayesian_engine.ex: update_beliefs/2, posterior/2
├── prediction_engine.ex: predict/2, evaluate/2
└── [9 more inference modules]

Cortex (S54-T36, 8 files):
├── cortex_supervisor.ex: child_spec, supervision tree
├── synapse.ex: process_signal/2, neural_routing/1
└── [6 more cortex modules]

Zenoh Mesh (S54-T38, 1,157 lines):
├── connect/1: Zenoh session establishment
├── publish/3: topic publishing
├── subscribe/2: topic subscription
├── mesh_health/0: aggregate mesh status
└── cluster_membership/0: node list

[Remaining batches follow similar pattern]
```

### S54-T47..T53: KMS + Observability + Integration (Batch Specs)

```
KMS (S54-T47, 20 files):
├── knowledge_graph.ex: add_node/2, add_edge/3, query/2
├── sqlite_store.ex: fetch_all/2, insert/3, update/3
├── holon_state.ex: save_state/2, load_state/1
└── [17 more KMS modules]

Observability (S54-T50, 24 files):
├── metrics_collector.ex: collect/1, aggregate/2
├── otlp_exporter.ex: export_spans/1, export_metrics/1
├── trace_log_correlation.ex: correlate/2
├── dashboard_templates.ex: render/2
└── [20 more observability modules]

Integration (S54-T53, 18 files):
├── enterprise_gateway.ex: route/2, authenticate/1
├── graphql_federation.ex: resolve/3, schema/0
├── rest_adapter.ex: forward/3
└── [15 more integration modules]
```

### S54-T75..T76: Utility Modules (Batch Generation)

For 169 modules <100 lines, generate minimal test suites:

```elixir
# Template for utility module test
defmodule Indrajaal.{Module}Test do
  use ExUnit.Case, async: true

  describe "module" do
    test "exists and is compiled" do
      assert Code.ensure_loaded?(Indrajaal.{Module})
    end

    test "public functions are callable" do
      # Auto-generated from module_info(:exports)
      funs = Indrajaal.{Module}.__info__(:functions)
      assert length(funs) > 0
    end
  end
end
```

### S54-T77: Quint Constraint Activation

**File**: `docs/formal_specs/quint/STAMPConstraints.qnt`

Activate 11 commented constraints:
```
SC-VAL-001: Patient Mode only
SC-VAL-002: Analyze complete logs
SC-VAL-003: 100% consensus
SC-VAL-004: Halt on disagreement
SC-CNT-009: NixOS/Podman only
SC-CNT-010: Localhost registry
SC-CNT-011: (container constraint)
SC-CNT-012: Rootless
SC-CNT-013: (container constraint)
SC-AGT-017: Agent efficiency > 90%
SC-AGT-018: No deadlocks
```

Uncomment imports: FPPSConsensus, PatientModeProtocol, ContainerProtocol

### S54-T78: Agda Hole Reduction

**File**: `docs/formal_specs/cross_holon_database.agda` (6 holes)

```
Hole 1 (line ~208): 2PC commit atomicity — prove both-or-neither
Hole 2 (line ~271): OCC conflict detection invariant
Hole 3 (line ~295): Conflict resolution correctness
Hole 4 (line ~399): Log append-only property
Hole 5 (line ~420): Saga compensation correctness
Hole 6 (line ~445): Cross-holon read consistency
```

### S54-T79: F# MathMonitor PetriNet RPN Fix

**File**: `lib/cepaf/src/Cepaf/Mesh/MathematicalSystemMonitor.fs`

Fix PetriNets entry:
- RPN: 315 → 30 (now CONNECTED with 1 caller via Sentinel)
- Maturity: Isolated → Partial
- Gap: remove from P1 registry, add note about Sprint 53 wiring

### S54-T80..T82: TODO Remediation

```
S54-T80 (approval.ex): Wire 3 DB stubs (recall, check_timeouts, get_process)
S54-T81 (token_refresh.ex): Implement get_refresh_token_data/1 persistence
S54-T82 (contractor_management.ex): Re-enable regex validation
```

---

## Level 4: FMEA Risk Analysis

### Critical Failure Modes

| ID | Failure Mode | S | O | D | RPN | Mitigation |
|----|-------------|---|---|---|-----|------------|
| FM-54-01 | SecurityPolicy test misses auth bypass | 9 | 3 | 3 | 81 | Property tests + boundary values |
| FM-54-02 | SymbioticDefense test causes process crash | 8 | 4 | 3 | 96 | ExUnit sandbox, capture_log |
| FM-54-03 | Communication test leaks state to other tests | 6 | 3 | 4 | 72 | ExUnit async: true isolation |
| FM-54-04 | Batch test gen produces non-compiling tests | 7 | 5 | 2 | 70 | Compile gate after each batch |
| FM-54-05 | 577 test files overwhelm CI pipeline | 6 | 4 | 3 | 72 | Async tests, ExUnit partitioning |
| FM-54-06 | Quint activation breaks model check | 5 | 3 | 5 | 75 | Run `quint verify` after each |
| FM-54-07 | Agda proof attempt causes type error | 4 | 5 | 3 | 60 | Incremental: 1 hole at a time |
| FM-54-08 | Ash resource tests need DB sandbox | 7 | 4 | 2 | 56 | Use DataCase + MigrationAware |
| FM-54-09 | ETS tests interfere across modules | 5 | 3 | 4 | 60 | Unique table names + cleanup |
| FM-54-10 | Propagation DNS test flaky in CI | 4 | 5 | 3 | 60 | Mock :inet_res.lookup |
| FM-54-11 | Generated tests have false positives | 5 | 4 | 4 | 80 | Manual review of P0 tests |
| FM-54-12 | Context window exhaustion during gen | 6 | 3 | 2 | 36 | Batch sizes ≤15 modules |
| FM-54-13 | Test file naming collision | 3 | 2 | 2 | 12 | Convention: mirror lib/ path |
| FM-54-14 | Untested module has side effects | 6 | 4 | 5 | 120 | Use `async: false` for stateful |
| FM-54-15 | F# monitor RPN change breaks tests | 3 | 2 | 2 | 12 | Run cepaf-test after change |

### Risk Summary

| Risk Level | Count | RPN Range | Action |
|------------|-------|-----------|--------|
| HIGH | 2 | 96-120 | Priority mitigation, manual review |
| MEDIUM | 6 | 60-81 | Standard mitigation |
| LOW | 7 | 12-72 | Monitor |

---

## Level 5: STAMP Compliance Matrix

### Primary Constraints Addressed

| STAMP ID | Constraint | Sprint 54 Task(s) | Status |
|----------|-----------|-------------------|--------|
| SC-COV-001 | Static coverage 100% critical paths | S54-T1..T17 (W1) | PLANNED |
| SC-COV-002 | Runtime coverage >= 95% | S54-T18..T84 (all waves) | PLANNED |
| SC-AUTH-001 | Authentication chain verified | S54-T1 | PLANNED |
| SC-AUTH-002 | Authorization RBAC tested | S54-T1 | PLANNED |
| SC-AUTH-003 | Session security tested | S54-T25 | PLANNED |
| SC-AUTH-004 | Credential validation | S54-T1, S54-T26 | PLANNED |
| SC-SEC-044 | Security policy enforcement | S54-T1, S54-T4 | PLANNED |
| SC-SEC-047 | Encryption tested | S54-T15 | PLANNED |
| SC-IMMUNE-001 | Sentinel monitors health | S54-T7, S54-T8 | PLANNED |
| SC-IMMUNE-004 | PatternHunter detection | S54-T8 | PLANNED |
| SC-COMM-001 | Communication layer tested | S54-T2 | PLANNED |
| SC-AUTO-001 | CRM automation rules | S54-T22..T24 | PLANNED |
| SC-AI-001..008 | AI agent constraints | S54-T35..T36 | PLANNED |
| SC-MESH-001..010 | Mesh constraints | S54-T38..T43 | PLANNED |
| SC-OBS-069..071 | Observability constraints | S54-T50..T52 | PLANNED |
| SC-PRAJNA-001..005 | Cockpit constraints | S54-T55..T57 | PLANNED |
| SC-MATH-003 | RPN > 100 remediated | S54-T79 | PLANNED |
| SC-MATH-005 | Agda holes decrease | S54-T78 | PLANNED |
| SC-VAL-001..004 | Validation constraints | S54-T77 | PLANNED |
| SC-CNT-009..013 | Container constraints | S54-T77 | PLANNED |
| SC-FUNC-001 | System compiles | S54-T17,T27,T34,T46,T54,T62,T74,T83 | GATES |
| SC-CHG-001 | Change tracking | S54-T84 | PLANNED |
| SC-TDG-001 | TDG compliance | All test tasks | PLANNED |

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

---

## KPIs (Expected)

| Metric | Before | Target | Delta |
|--------|--------|--------|-------|
| Untested modules | 577 | 0 | −577 |
| Test files | 1,005 | ~1,582 | +577 |
| Test lines | ~200K | ~315K | +115K |
| Individual test cases | ~5,000 | ~7,000+ | +2,000+ |
| Module test coverage | ~63% | 100% | +37% |
| Agda holes | 22 | 16 | −6 |
| Quint active | 13/24 | 24/24 | +11 |
| System RPN | ~80 | ~30 | −62.5% |
| Stubs (MEDIUM) | 3 | 0 | −3 |
| Compile warnings | 0 | 0 | = |
| Credo issues | 0 | 0 | = |

## Execution Strategy

8-round implementation with compile+quality gates:

| Round | Waves | Tasks | Est. Time |
|-------|-------|-------|-----------|
| R1 | W1 (Safety+Security) | S54-T1..T17 | Day 1 |
| R2 | W2 (Sprint 53) | S54-T18..T27 | Day 1 |
| R3 | W3 (Alarms+Core) | S54-T28..T34 | Day 2 |
| R4 | W4 (Cybernetic+Mesh) | S54-T35..T46 | Day 2-3 |
| R5 | W5 (KMS+Obs+Integration) | S54-T47..T54 | Day 3-4 |
| R6 | W6 (Cockpit+Test+CRM) | S54-T55..T62 | Day 4 |
| R7 | W7 (Deploy+Dist+Web) | S54-T63..T74 | Day 5 |
| R8 | W8 (Utility+Formal+Commit) | S54-T75..T84 | Day 5-6 |

### Test Generation Approach

**CRITICAL modules (>500 lines)**: Full TDG-compliant test suites
- Property tests with PropCheck/StreamData
- Boundary value analysis
- Error path coverage
- Telemetry verification
- ~25-45 tests per module

**HIGH modules (200-500 lines)**: Standard test suites
- Public API contract tests
- Error boundary tests
- Key business logic paths
- ~12-20 tests per module

**MEDIUM modules (100-200 lines)**: Focused test suites
- Public function contract tests
- Error cases
- ~8-12 tests per module

**LOW modules (<100 lines)**: Minimal test suites
- Module existence verification
- Public function callability
- Basic happy-path test per function
- ~3-5 tests per module

## Dependency Graph (Simplified)

```
W1 (T1-T17) ──── Gate ────┐
W2 (T18-T27) ─── Gate ────┤
                           ├── W3 (T28-T34) ── Gate ──┐
                           │                           ├── W4 (T35-T46) ── Gate ──┐
                           │                           │                          │
                           │                           └── W5 (T47-T54) ── Gate ──┤
                           │                                                      │
                           └── W6 (T55-T62) ── Gate ──┐                          │
                                                       ├── W7 (T63-T74) ── Gate ──┤
                                                       │                          │
                                                       └── W8 (T75-T84) ── Gate ──┘
                                                                                   │
                                                                              COMMIT
```

W1 and W2 run first (P0 safety-critical). W3-W5 and W6-W7 can run in parallel tracks
after their prerequisites pass. W8 is the final wave with formal verification + commit.

## Next Sprint (55)

- Reduce remaining 16 Agda holes (ZenohProofs, PlanningOrchestration)
- Activate remaining Quint stub modules (FPPSConsensus, PatientModeProtocol)
- VSM System1-5 supervision tree wiring (P2 math gap)
- SwarmIntelligence convergence metrics to Zenoh (P2 math gap)
- Test suite quality improvement pass (upgrade LOW→STANDARD for critical paths)
- Integration test suites (cross-module test scenarios)
- Performance test suites (latency, throughput benchmarks)
