# Fractal Logging System - Full Integration Plan

**Version**: 1.0.0
**Date**: 2025-12-26
**Author**: Claude Opus 4.5 (Cybernetic Architect)
**Status**: ACTIVE
**Compliance**: SOPv5.11, STAMP Safety Framework

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [As-Is State Analysis](#2-as-is-state-analysis)
3. [Gap Analysis](#3-gap-analysis)
4. [5-Level Root Cause Analysis](#4-5-level-root-cause-analysis)
5. [To-Be Architecture](#5-to-be-architecture)
6. [5-Level Implementation Plan](#6-5-level-implementation-plan)
7. [Test Strategy](#7-test-strategy)
8. [Usage Guide](#8-usage-guide)
9. [DAG Path Coverage Matrix](#9-dag-path-coverage-matrix)
10. [Intermodule Integration Map](#10-intermodule-integration-map)

---

## 1. Executive Summary

### 1.1 Current State

The Indrajaal v5.2 codebase has a sophisticated **5-Level Fractal Logging System** implemented in `lib/indrajaal/observability/fractal/` with 12 core modules. However, this system is currently **underutilized** - only 0% of business logic modules actively use it.

| Metric | Value |
|--------|-------|
| Total modules using Logger | 336 |
| Modules using Fractal Logging | 0 |
| Fractal System Code Coverage | 6%-90.7% |
| STAMP Constraints Implemented | 8 (SC-LOG-001 to SC-LOG-008) |

### 1.2 Goal

**100% integration** of all application logging with the Fractal Logging System, enabling:
- 5-level observability (L1-L5)
- Automatic PII masking
- Bloom filter deduplication
- Load shedding at CPU > 90%
- Zenoh-style key expression routing
- HLC causal timestamps
- OpenTelemetry trace correlation

### 1.3 Key Benefits

1. **Unified Observability**: Single logging API across all domains
2. **Dynamic Control**: Runtime boost system for debugging
3. **Safety Compliance**: STAMP SC-LOG constraints enforcement
4. **Performance**: <500ns per log decision, auto-throttling
5. **Distributed Tracing**: Seamless OTel integration

---

## 2. As-Is State Analysis

### 2.1 Current Logging Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CURRENT LOGGING ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    BUSINESS DOMAINS (336 modules)                 │   │
│  │  Accounts, Alarms, AccessControl, Devices, Video, Analytics...   │   │
│  └────────────────────────────┬─────────────────────────────────────┘   │
│                               │                                          │
│                               ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Logger.info/debug/warn/error                  │   │
│  └────────────────────────────┬─────────────────────────────────────┘   │
│                               │                                          │
│               ┌───────────────┼───────────────┐                          │
│               ▼               ▼               ▼                          │
│  ┌────────────────┐ ┌─────────────────┐ ┌──────────────────┐            │
│  │ Console Backend│ │ LoggerJSON      │ │ LoggerTraceContext│            │
│  │ (local output) │ │ (SigNoz export) │ │ (trace injection) │            │
│  └────────────────┘ └─────────────────┘ └──────────────────┘            │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                  FRACTAL LOGGING (UNUSED)                         │   │
│  │  FractalControl, WriteFilter, BatchEncoder, HLC, ContentRouter    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Entry Points Inventory

| Entry Point | Location | Usage Count | Fractal? |
|-------------|----------|-------------|----------|
| `Logger.*` | stdlib | 336 modules | No |
| `DualLogging.log_*` | observability/dual_logging.ex | 5 modules | No |
| `Logging.log_domain_event` | observability/logging.ex | 19 domains | No |
| `Logging.log_stamp_event` | observability/logging.ex | ~10 modules | No |
| `Logging.log_security_event` | observability/logging.ex | ~20 modules | No |
| `fractal_log()` | fractal/logger.ex | 0 modules | Yes |
| `@fractal` decorator | fractal/decorator.ex | 0 modules | Yes |

### 2.3 Fractal System Module Coverage

| Module | Coverage | Lines | Status |
|--------|----------|-------|--------|
| write_filter.ex | 90.7% | 602 | Good |
| content_router.ex | 84.9% | 661 | Good |
| fractal_control.ex | 79.9% | 1028 | Good |
| otel_integration.ex | 77.9% | 613 | Good |
| batch_encoder.ex | 76.8% | 933 | Good |
| decorator.ex | 75.0% | 429 | Good |
| supervisor.ex | 62.5% | 227 | Needs Work |
| logger.ex | 47.6% | 535 | Needs Work |
| hlc.ex | 47.1% | 211 | Needs Work |
| pii_masker.ex | 40.0% | 249 | Needs Work |
| key_expression.ex | 22.0% | 264 | Critical |
| cybernetic_controller.ex | 6.0% | 488 | Critical |
| **fractal.ex (CLI)** | 0.0% | 888 | Critical |

---

## 3. Gap Analysis

### 3.1 Critical Gaps

| Gap ID | Description | Impact | Priority |
|--------|-------------|--------|----------|
| GAP-001 | No business modules use Fractal | Zero 5-level visibility | P0 |
| GAP-002 | `@fractal` decorator not functional | Manual integration required | P0 |
| GAP-003 | 6 modules under 50% coverage | Untested code paths | P1 |
| GAP-004 | No Ash resource integration | Domain CRUD not traced | P1 |
| GAP-005 | No Oban job integration | Background jobs not traced | P1 |
| GAP-006 | No Phoenix LiveView integration | UI events not traced | P2 |
| GAP-007 | Boost system has no dashboard | Debugging visibility limited | P2 |
| GAP-008 | CyberneticController at 6% | OODA loop barely tested | P1 |

### 3.2 Integration Points Missing

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MISSING INTEGRATIONS                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                │
│  │ Ash Domain  │ ──X─│   Fractal   │──X──│   Oban      │                │
│  │ Resources   │     │   Logging   │     │   Jobs      │                │
│  └─────────────┘     └─────────────┘     └─────────────┘                │
│         X                  X                   X                         │
│         │                  │                   │                         │
│  ┌──────▼──────┐     ┌─────▼─────┐     ┌──────▼──────┐                  │
│  │ Phoenix     │     │ Telemetry │     │ GenServer   │                  │
│  │ Controllers │     │ Events    │     │ Processes   │                  │
│  └─────────────┘     └───────────┘     └─────────────┘                  │
│                                                                          │
│  Legend: ──X── = Missing Integration                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. 5-Level Root Cause Analysis

### L1: Atomic Level (Code-Level)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| `@fractal` macro only stores opts | decorator.ex:25-30 | Add `on_definition` hook |
| No `use Fractal.Logger` anywhere | grep results: 0 matches | Add to all domains |
| Direct Logger calls bypass Fractal | 336 modules | Wrapper function needed |

### L2: Component Level (Module-Level)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| Fractal modules are self-contained | No external callers | Create integration layer |
| logging.ex doesn't call Fractal | Wrapper uses Logger | Add Fractal routing |
| Domain instrumentation bypasses | 19 domains direct Logger | Add Fractal hooks |

### L3: Transaction Level (Flow-Level)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| Business flows not traced | No L3 trace IDs in domains | Inject trace context |
| Ash operations have no hooks | Resource callbacks missing | Add Ash middleware |
| Oban jobs standalone | No Fractal telemetry | Add job instrumentation |

### L4: System Level (Architecture-Level)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| Two parallel logging systems | Fractal + Logger | Unify under Fractal |
| No central logging policy | Each module decides | Use FractalControl |
| Missing observability dashboard | No boost visibility | Create CLI/LiveView |

### L5: Cognitive Level (Design-Level)

| Finding | Evidence | Resolution |
|---------|----------|------------|
| Fractal not part of developer workflow | No documentation | Create usage guide |
| No enforcement mechanism | Code compiles without | Add Credo check |
| Missing governance | No policy management | Use CyberneticController |

---

## 5. To-Be Architecture

### 5.1 Target Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TO-BE: UNIFIED FRACTAL LOGGING                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    BUSINESS DOMAINS (336 modules)                 │   │
│  │          use Indrajaal.Observability.Fractal.Logger               │   │
│  └────────────────────────────┬─────────────────────────────────────┘   │
│                               │                                          │
│                               ▼                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    FRACTAL LOGGING API                            │   │
│  │  fractal_log(level, key_expr, message, metadata)                  │   │
│  │  @fractal depth: :l3, aspect: :business                           │   │
│  └────────────────────────────┬─────────────────────────────────────┘   │
│                               │                                          │
│  ┌────────────────────────────▼─────────────────────────────────────┐   │
│  │                     FRACTAL CONTROL PLANE                         │   │
│  ├──────────────────────────────────────────────────────────────────┤   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐  │   │
│  │  │ FractalCtrl │ │ WriteFilter │ │ BatchEncoder│ │    HLC     │  │   │
│  │  │ (Policy)    │ │ (Dedup)     │ │ (Compress)  │ │ (Timestamp)│  │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘  │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐  │   │
│  │  │ContentRouter│ │  PIIMasker  │ │ KeyExpr     │ │ Cybernetic │  │   │
│  │  │ (Routing)   │ │ (Safety)    │ │ (Patterns)  │ │ (OODA)     │  │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘  │   │
│  └────────────────────────────┬─────────────────────────────────────┘   │
│                               │                                          │
│               ┌───────────────┼───────────────┐                          │
│               ▼               ▼               ▼                          │
│  ┌────────────────┐ ┌─────────────────┐ ┌──────────────────┐            │
│  │ Console Backend│ │ SigNoz (OTel)   │ │ SIEM Integration │            │
│  │ (L4/L5 only)   │ │ (All levels)    │ │ (Security events)│            │
│  └────────────────┘ └─────────────────┘ └──────────────────┘            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Key Expression Hierarchy

```
Indrajaal/
├── Accounts/
│   ├── Authentication/**    → L3 default, boost to L1 for debugging
│   ├── Session/**           → L3 default
│   └── User/**              → L4 default
├── Alarms/
│   ├── Critical/**          → L3 default, always L2 for security
│   ├── Processing/**        → L4 default
│   └── Correlation/**       → L3 default
├── AccessControl/
│   ├── Grant/**             → L2 default (security-critical)
│   ├── Deny/**              → L2 default (security-critical)
│   └── Validate/**          → L3 default
├── Devices/
│   ├── Failsafe/**          → L2 default (safety-critical)
│   ├── Status/**            → L4 default
│   └── Telemetry/**         → L5 default
├── Video/
│   ├── Stream/**            → L4 default (high volume)
│   ├── Recording/**         → L3 default
│   └── Analytics/**         → L4 default
└── Infrastructure/
    ├── OODA/**              → L5 default (cognitive)
    ├── Cortex/**            → L5 default
    └── Cluster/**           → L3 default
```

### 5.3 Level Mapping

| Level | Name | Default Policy | Log Volume | Use Case |
|-------|------|----------------|------------|----------|
| L1 | Atomic | Boost-only | Very High | Function args, hex dumps |
| L2 | Component | Security-only | High | GenServer state, ETS |
| L3 | Transaction | Business flows | Medium | Trace IDs, transactions |
| L4 | System | Default | Low | Node health, metrics |
| L5 | Cognitive | Always | Very Low | AI decisions, hypotheses |

---

## 6. 5-Level Implementation Plan

### Level 1: Foundation (Code-Level)

**Duration**: Phase 1
**Files to Modify**: 5

| Step | File | Change | STAMP |
|------|------|--------|-------|
| 1.1 | decorator.ex | Implement `on_definition` hook for `@fractal` | SC-LOG-001 |
| 1.2 | logger.ex | Add `use` macro for easy integration | SC-LOG-003 |
| 1.3 | fractal_control.ex | Add key expression auto-registration | SC-LOG-005 |
| 1.4 | pii_masker.ex | Add domain-specific masking rules | SC-LOG-003 |
| 1.5 | key_expression.ex | Complete wildcard matching | SC-LOG-008 |

**Deliverables**:
- Working `@fractal` decorator
- `use Indrajaal.Observability.Fractal.Logger` macro
- Auto-registration of key expressions

### Level 2: Component (Module-Level)

**Duration**: Phase 2
**Files to Modify**: 12

| Step | File | Change | STAMP |
|------|------|--------|-------|
| 2.1 | logging.ex | Route through Fractal | SC-LOG-001 |
| 2.2 | domain_logger.ex | Add Fractal delegation | SC-LOG-001 |
| 2.3 | error_logger.ex | Add Fractal delegation | SC-LOG-001 |
| 2.4 | telemetry_enhancement.ex | Emit Fractal events | SC-LOG-004 |
| 2.5 | otel_integration.ex | Bi-directional sync | SC-LOG-004 |
| 2.6 | cybernetic_controller.ex | Complete OODA implementation | SC-LOG-002 |

**Deliverables**:
- All logging wrappers use Fractal
- Telemetry events flow to Fractal
- CyberneticController fully functional

### Level 3: Transaction (Flow-Level)

**Duration**: Phase 3
**Files to Modify**: 19+ (all domains)

| Step | Domain | Change | Priority |
|------|--------|--------|----------|
| 3.1 | Accounts | Add `use Fractal.Logger`, L3 for auth | P0 |
| 3.2 | Alarms | Add `use Fractal.Logger`, L2 for critical | P0 |
| 3.3 | AccessControl | Add `use Fractal.Logger`, L2 for security | P0 |
| 3.4 | Devices | Add `use Fractal.Logger`, L2 for failsafe | P0 |
| 3.5 | Video | Add `use Fractal.Logger`, L4 for streams | P1 |
| 3.6 | Analytics | Add `use Fractal.Logger`, L4 default | P1 |
| 3.7+ | Remaining | Progressive integration | P2 |

**Deliverables**:
- All domains integrated with Fractal
- Key expressions defined per domain
- Default policies configured

### Level 4: System (Architecture-Level)

**Duration**: Phase 4
**Files to Create**: 5

| Step | Component | Purpose |
|------|-----------|---------|
| 4.1 | Ash.Fractal.Middleware | Automatic resource tracing |
| 4.2 | Oban.Fractal.Plugin | Job lifecycle tracing |
| 4.3 | Phoenix.Fractal.Plug | Request/response tracing |
| 4.4 | mix fractal.dashboard | Enhanced CLI dashboard |
| 4.5 | FractalLive.Dashboard | Phoenix LiveView dashboard |

**Deliverables**:
- Framework integrations
- Operational dashboards
- Real-time boost management

### Level 5: Cognitive (Governance-Level)

**Duration**: Phase 5
**Components**: 3

| Step | Component | Purpose |
|------|-----------|---------|
| 5.1 | CyberneticController | Autonomous policy adjustment |
| 5.2 | Credo.FractalCheck | Enforce Fractal usage |
| 5.3 | GDE.LoggingGoal | Goal-directed logging evolution |

**Deliverables**:
- Self-tuning logging policies
- Development-time enforcement
- Continuous improvement loop

---

## 7. Test Strategy

### 7.1 Coverage Targets

| Module | Current | Target | Gap |
|--------|---------|--------|-----|
| write_filter.ex | 90.7% | 100% | 9.3% |
| content_router.ex | 84.9% | 100% | 15.1% |
| fractal_control.ex | 79.9% | 100% | 20.1% |
| otel_integration.ex | 77.9% | 100% | 22.1% |
| batch_encoder.ex | 76.8% | 100% | 23.2% |
| decorator.ex | 75.0% | 100% | 25.0% |
| supervisor.ex | 62.5% | 100% | 37.5% |
| logger.ex | 47.6% | 100% | 52.4% |
| hlc.ex | 47.1% | 100% | 52.9% |
| pii_masker.ex | 40.0% | 100% | 60.0% |
| key_expression.ex | 22.0% | 100% | 78.0% |
| cybernetic_controller.ex | 6.0% | 100% | 94.0% |
| fractal.ex (CLI) | 0.0% | 100% | 100.0% |

### 7.2 Test Categories

#### Unit Tests (Existing + New)

| Category | Existing | New Required |
|----------|----------|--------------|
| FractalControl | 62 | +15 (load shedding edge cases) |
| WriteFilter | 42 | +5 (rotation edge cases) |
| BatchEncoder | 28 | +10 (compression edge cases) |
| Decorator | 31 | +20 (macro transformation) |
| OtelIntegration | 32 | +8 (baggage propagation) |
| ContentRouter | 27 | +10 (backend selection) |
| CyberneticController | 3 | +40 (OODA loop coverage) |
| KeyExpression | 5 | +30 (wildcard matching) |
| PIIMasker | 8 | +20 (pattern detection) |
| HLC | 10 | +15 (clock drift) |
| Logger | 15 | +25 (emission paths) |
| Supervisor | 8 | +10 (failure scenarios) |

#### Property Tests (TDG Compliant)

| Property | Module | Generator |
|----------|--------|-----------|
| No false negatives | WriteFilter | PC.list(PC.binary()) |
| Monotonic timestamps | HLC | PC.list(PC.pos_integer()) |
| Compression ratio >65% | BatchEncoder | PC.list(entries) |
| PII masking complete | PIIMasker | PC.oneof([email, ssn, card]) |
| Key matching correct | KeyExpression | key_expr_generator() |
| Policy enforcement | FractalControl | level_policy_generator() |

#### Integration Tests

| Scenario | Modules Involved | Expected Outcome |
|----------|------------------|------------------|
| Domain log flow | Domain → Fractal → OTel | Trace ID present |
| Boost activation | CLI → FractalControl → Logger | L1 logs visible |
| Load shedding | CPU spike → FractalControl | L1-L3 suppressed |
| PII in logs | Business → PIIMasker → Logger | Masked output |
| Batch encoding | Multiple logs → BatchEncoder → Wire | Compressed payload |
| Key routing | Log → ContentRouter → Backend | Correct destination |

### 7.3 DAG Path Coverage

```
              ┌─────────────────────────────────────────────────────┐
              │                  TEST DAG PATHS                      │
              └─────────────────────────────────────────────────────┘

Path 1: Happy Path (L4 System Log)
  fractal_log(:l4, key, msg)
    → should_log?() ✓
    → should_emit?() ✓
    → emit_to_backends()
    → [Logger, OTel]

Path 2: Rejection Path (L1 without boost)
  fractal_log(:l1, key, msg)
    → should_log?() ✗
    → (dropped)

Path 3: Boost Path (L1 with boost)
  add_boost(key_expr, :l1)
    → fractal_log(:l1, key, msg)
    → should_log?() ✓ (boost match)
    → emit_to_backends()

Path 4: Deduplication Path
  fractal_log(same_key, same_msg)
    → should_emit?() ✗ (bloom filter)
    → (deduplicated)

Path 5: Load Shedding Path
  CPU > 90%
    → fractal_log(:l3, key, msg)
    → load_shedding?() ✓
    → (dropped)

Path 6: PII Masking Path
  fractal_log(msg_with_email)
    → PIIMasker.mask()
    → emit (masked)

Path 7: Routing Path
  fractal_log(:l2, "Security/**")
    → ContentRouter.route()
    → [:siem, :postgresql]

Path 8: Batch Path
  100 logs within 10ms
    → BatchEncoder.add()
    → flush_batch()
    → (single wire message)
```

---

## 8. Usage Guide

### 8.1 Quick Start

```elixir
# In your module
defmodule MyModule do
  use Indrajaal.Observability.Fractal.Logger

  def my_function(arg) do
    # Log at L4 (system level - default visible)
    fractal_log(:l4, "MyModule/my_function", "Processing", %{arg: arg})

    # Log at L3 (transaction level - for business flows)
    fractal_l3("Starting transaction", %{trace_id: get_trace_id()})

    # Log at L1 (atomic level - only with boost)
    fractal_l1("Debug: arg bytes", %{bytes: :erlang.term_to_binary(arg)})

    do_work(arg)
  end
end
```

### 8.2 Using the Decorator

```elixir
defmodule MyModule do
  use Indrajaal.Observability.Fractal.Decorator

  @fractal depth: :l3, aspect: :business, mask: [:password, :ssn]
  def sensitive_operation(user_id, password) do
    # Function entry/exit automatically logged at L3
    # Password will be masked in logs
    authenticate(user_id, password)
  end

  @fractal depth: :l1, skip_entry: true
  def hot_path(data) do
    # Only exit logged, at L1 (requires boost to see)
    transform(data)
  end
end
```

### 8.3 Boost System

```bash
# Activate L1 logging for authentication debugging
mix fractal.boost "Indrajaal/Accounts/Authentication/**" --level l1 --ttl 5m

# Activate L2 for all alarm processing
mix fractal.boost "Indrajaal/Alarms/**" --level l2 --ttl 30m

# List active boosts
mix fractal.boosts

# Remove a boost
mix fractal.unboost "Indrajaal/Accounts/Authentication/**"
```

### 8.4 Dashboard

```bash
# Full dashboard view
mix fractal.dashboard

# Compact single-line view
mix fractal.dashboard --compact

# JSON output for scripting
mix fractal.dashboard --json

# Watch mode (auto-refresh every 2s)
mix fractal.dashboard --watch
```

### 8.5 Key Expression Patterns

| Pattern | Matches | Use Case |
|---------|---------|----------|
| `Indrajaal/Alarms/*` | Direct children only | Single domain |
| `Indrajaal/Alarms/**` | All descendants | Entire subtree |
| `Indrajaal/*/Critical` | Any domain's Critical | Cross-domain |
| `Indrajaal/Accounts/Auth*` | Auth, Authentication, etc. | Prefix match |

### 8.6 Level Selection Guide

| Situation | Level | Rationale |
|-----------|-------|-----------|
| Function arguments | L1 | Very verbose, boost-only |
| GenServer state | L2 | Component debugging |
| User login | L3 | Business flow |
| App startup | L4 | System health |
| AI decision | L5 | Cognitive audit |
| Security event | L2/L3 | Always visible |
| Performance metric | L4 | Regular monitoring |
| Error with stack | L3 | Needs investigation |

---

## 9. DAG Path Coverage Matrix

### 9.1 Inter-Module Call Paths

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        INTERMODULE CALL GRAPH                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Logger.ex ─────┬───► FractalControl.ex ─────► WriteFilter.ex            │
│       │         │            │                       │                   │
│       │         │            ▼                       ▼                   │
│       │         └───► ContentRouter.ex        BatchEncoder.ex            │
│       │                      │                       │                   │
│       ▼                      ▼                       ▼                   │
│  PIIMasker.ex         KeyExpression.ex         HLC.ex                   │
│       │                      │                       │                   │
│       └──────────────────────┴───────────────────────┘                   │
│                              │                                           │
│                              ▼                                           │
│                    OtelIntegration.ex                                    │
│                              │                                           │
│                              ▼                                           │
│                 CyberneticController.ex                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Path Coverage Table

| Path ID | Source | Target | Status | Test File |
|---------|--------|--------|--------|-----------|
| P001 | Logger | FractalControl | ✓ Covered | fractal_control_test.exs |
| P002 | Logger | PIIMasker | ✓ Covered | decorator_test.exs |
| P003 | FractalControl | WriteFilter | ✓ Covered | write_filter_test.exs |
| P004 | FractalControl | ContentRouter | ✓ Covered | content_router_test.exs |
| P005 | WriteFilter | BatchEncoder | Partial | batch_encoder_test.exs |
| P006 | ContentRouter | KeyExpression | ✗ Gap | NEW: key_expr_integration_test.exs |
| P007 | ContentRouter | OtelIntegration | ✓ Covered | otel_integration_test.exs |
| P008 | BatchEncoder | HLC | ✓ Covered | hlc_test.exs (implicit) |
| P009 | OtelIntegration | Cybernetic | ✗ Gap | NEW: cybernetic_otel_test.exs |
| P010 | ALL | Supervisor | Partial | supervisor_test.exs |

---

## 10. Intermodule Integration Map

### 10.1 External Dependencies

| Fractal Module | External Dependency | Integration Type |
|----------------|---------------------|------------------|
| Logger | Elixir.Logger | Backend delegation |
| OtelIntegration | OpenTelemetry | Span/Baggage API |
| ContentRouter | :telemetry | Event emission |
| WriteFilter | :atomics | Concurrent counter |
| BatchEncoder | :zlib | Compression |
| HLC | System.monotonic_time | Time source |
| Supervisor | Elixir.Supervisor | OTP behavior |

### 10.2 Full System Integration Points

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    FULL SYSTEM INTEGRATION MAP                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Phoenix.Router ──► Plug.Fractal ──► Request Tracing                    │
│        │                                                                 │
│        ▼                                                                 │
│  Controllers ──► use Fractal.Logger ──► L3 Logging                      │
│        │                                                                 │
│        ▼                                                                 │
│  Ash.Domain ──► Ash.Fractal.Middleware ──► CRUD Tracing                 │
│        │                                                                 │
│        ▼                                                                 │
│  Oban.Worker ──► Oban.Fractal.Plugin ──► Job Tracing                    │
│        │                                                                 │
│        ▼                                                                 │
│  GenServer ──► @fractal decorator ──► State Tracing                     │
│        │                                                                 │
│        ▼                                                                 │
│  Ecto.Repo ──► Telemetry ──► Query Tracing                              │
│        │                                                                 │
│        └───────────► Fractal Logging System ◄───────────┘               │
│                              │                                           │
│                              ▼                                           │
│              ┌───────────────┴───────────────┐                          │
│              │                               │                           │
│        Console/SigNoz              CyberneticController                  │
│         (Export)                    (Governance)                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Appendix A: STAMP Safety Constraints

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-LOG-001 | Async dispatch | Task.start for all emissions |
| SC-LOG-002 | Auto-throttle | Load shedding at CPU > 90% |
| SC-LOG-003 | PII masking | PIIMasker.mask() on all content |
| SC-LOG-004 | Trace linking | L3 TraceID in all L1/L2 logs |
| SC-LOG-005 | Boost TTL | Max 1 hour, enforced in FractalControl |
| SC-LOG-006 | HLC timestamps | HLC.now() for L3+ logs |
| SC-LOG-007 | Batch flush | Within 10ms, BatchEncoder |
| SC-LOG-008 | FNR < 1% | Bloom filter in WriteFilter |

---

## Appendix B: Metrics & KPIs

| KPI | Target | Measurement |
|-----|--------|-------------|
| Log decision latency | <500ns | WriteFilter.should_emit?() timing |
| Deduplication rate | >80% | WriteFilter stats |
| Compression ratio | >65% | BatchEncoder stats |
| False negative rate | <1% | WriteFilter bloom accuracy |
| Coverage | 100% | mix test --cover |
| STAMP compliance | 8/8 | All SC-LOG-* enforced |

---

**Document End**

*Generated by Claude Opus 4.5 - Cybernetic Architect*
*Compliance: SOPv5.11 + STAMP + TDG*
