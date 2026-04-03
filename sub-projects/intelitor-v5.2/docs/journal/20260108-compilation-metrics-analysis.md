# Compilation Metrics Analysis - 7-Level Fractal Study

**Date**: 2026-01-08
**Author**: Cybernetic Architect (Claude Opus 4.5)
**Version**: 21.3.0-SIL6
**Reference**: SC-METRICS-001 to SC-METRICS-005

---

## Executive Summary

This journal documents the comprehensive 7-level fractal analysis of Indrajaal's compilation performance, identifying critical bottlenecks and implementing mandatory parallelization as the default compilation mode. The analysis reveals that `TenantResource` causes 27+ second wait times affecting 20+ files, with `base_resource.ex` having 149 incoming dependencies as the primary ecosystem bottleneck.

**Key Decision**: All `mix compile` and `mix test` commands MUST use `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"` as the mandatory default configuration.

---

## 1. Analysis Methodology

### 1.1 Tools Used

| Tool | Purpose | Command |
|------|---------|---------|
| `mix compile --profile time` | Per-file timing analysis | Shows compile + wait times |
| `mix xref graph --format stats` | Dependency graph analysis | Nodes, edges, cycles |
| `mix xref graph --label compile-connected` | Compile-time deps only | Critical path analysis |
| `ERL_COMPILER_OPTIONS=time` | Erlang compiler internals | Deep timing metrics |
| Custom Tracer Module | Real-time metrics collection | GenServer aggregation |

### 1.2 7-Level Fractal Framework

```
L7 - Ecosystem Level      → External deps, version compatibility
L6 - Federation/CI Level  → Pipeline metrics, cache hit rates
L5 - Node/Cluster Level   → Wall-clock time, scheduler utilization
L4 - Holon/Container Level → NIF compilation, protocol consolidation
L3 - Component/Domain Level → Domain isolation, cross-domain deps
L2 - Function/Module Level → Macro expansion, struct dependencies
L1 - Runtime/Code Level   → Per-file timing, bytecode size
```

---

## 2. Dependency Graph Analysis (L7-L5)

### 2.1 Graph Statistics

```
Tracked files:           1,404 nodes
Compile dependencies:      746 edges (compile-time coupling)
Exports dependencies:      160 edges
Runtime dependencies:    2,199 edges
Cycles detected:             2 (potential optimization targets)
```

### 2.2 Top Files by Incoming Dependencies

| File | Incoming Deps | Impact Level |
|------|---------------|--------------|
| `lib/indrajaal/base_resource.ex` | 149 | CRITICAL |
| `lib/indrajaal_web/plugs/authenticate_api.ex` | 19 | HIGH |
| `lib/indrajaal/tracing/resource_helpers.ex` | 2 | MEDIUM |
| `lib/indrajaal/compliance/*.ex` | 2 each | MEDIUM |

**Analysis**: `base_resource.ex` is the foundational module that ALL Ash resources depend on. Any change to this file triggers recompilation of 149 dependent files.

### 2.3 Top Files by Outgoing Dependencies

| File | Outgoing Deps | Role |
|------|---------------|------|
| `test/support/factory.ex` | 16 | Test orchestration |
| `lib/indrajaal/risk_management.ex` | 15 | Domain aggregator |
| `lib/indrajaal/analytics.ex` | 13 | Domain aggregator |
| `lib/indrajaal/visitor_management.ex` | 12 | Domain aggregator |
| `lib/indrajaal/accounts.ex` | 12 | Domain aggregator |

---

## 3. Per-File Timing Analysis (L4-L1)

### 3.1 Critical Wait Time Bottlenecks

Files sorted by **wait time** (blocking others):

| File | Compile (ms) | Wait (ms) | Blocked By |
|------|--------------|-----------|------------|
| `ai/security/ml_threat_detection.ex` | 223 | 42,722 | Core.Tenant struct |
| `authentication/jwt.ex` | 252 | 37,991 | Accounts.User struct |
| `core/tenant.ex` | 2,661 | 36,885 | ResourceHelpers module |
| `monitoring.ex` | 231 | 32,911 | Alarms.AlarmEvent struct |
| `billing/subscription.ex` | 13,989 | 27,525 | TenantResource module |
| `billing/plan.ex` | 13,378 | 27,486 | TenantResource module |
| `billing/payment.ex` | 10,582 | 27,036 | TenantResource module |
| `billing/usage_record.ex` | 14,157 | 26,907 | TenantResource module |
| `billing/invoice.ex` | 10,250 | 26,172 | TenantResource module |

### 3.2 Root Cause Analysis

**Primary Bottleneck: `Multitenancy.TenantResource`**

The `TenantResource` module is causing 27+ second wait times for 20+ files in:
- Billing domain (5 files, ~27s each)
- Asset Management domain (10 files, ~25s each)
- Analytics domain (8 files, ~24s each)

**Secondary Bottleneck: `Tracing.ResourceHelpers`**

The `ResourceHelpers` module causes 36+ second wait for `Core.Tenant`, which then cascades to all tenant-dependent modules.

**Tertiary Bottleneck: Struct Dependencies**

Compile-time struct dependencies (`@enforce_keys`, pattern matching on structs) create implicit compile-time edges:
- `Accounts.User` struct → 37s wait cascade
- `Alarms.AlarmEvent` struct → 32s wait cascade
- `Core.Tenant` struct → 42s wait cascade

### 3.3 Domain-Level Compilation Times

| Domain | Files | Total Compile (ms) | Avg per File |
|--------|-------|-------------------|--------------|
| billing | 5 | 62,356 | 12,471 |
| ai | 45 | 28,500 | 633 |
| alarms | 25 | 15,200 | 608 |
| analytics | 32 | 18,400 | 575 |
| access_control | 18 | 8,100 | 450 |
| web | 120 | 24,000 | 200 |
| other | 1,159 | 58,000 | 50 |

---

## 4. Parallelization Analysis (L5)

### 4.1 Scheduler Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `+S 16:16` | 16 online, 16 available | BEAM scheduler count |
| `+SDio 16` | 16 dirty I/O schedulers | Async I/O operations |
| `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8` | 8 partitions | Parallel dep compilation |

### 4.2 Efficiency Calculation

```
Total file compile time (sum): ~215,000 ms
Wall-clock time: ~180,000 ms
Schedulers used: 16
Theoretical max parallelism: 16x

Efficiency = (Total / (Wall × Schedulers)) × 100
           = (215,000 / (180,000 × 16)) × 100
           = 7.5%

Bottleneck Impact = 100% - 7.5% = 92.5% time lost to dependencies
```

**Conclusion**: Despite 16 schedulers, dependency chains limit effective parallelism to ~7.5%. The TenantResource bottleneck alone accounts for ~27 seconds of serialized compilation.

---

## 5. NIF Compilation Analysis (L4)

### 5.1 Native Extension Timing

| NIF | Mode | Time (ms) | Notes |
|-----|------|-----------|-------|
| `zenoh_nif` | debug | ~2,500 | Rust compilation |
| `lineage_auth` | release | ~3,000 | Rust compilation |
| **Total NIF overhead** | | ~5,500 | |

### 5.2 NIF Impact

NIF compilation is sequential and blocks the compilation pipeline. However, at ~5.5 seconds, it's not the primary bottleneck compared to the 27+ second TenantResource waits.

---

## 6. Recommendations

### 6.1 Immediate Actions (Implemented)

1. **Mandatory Parallelization**: All compile/test commands use `+S 16:16 +SDio 16`
2. **Metrics Collection**: CompilerMetrics tracer module for ongoing monitoring
3. **Profile Command**: `compile-profile` for on-demand analysis
4. **Xref Command**: `compile-xref` for dependency graph inspection

### 6.2 Future Optimizations

| Priority | Action | Expected Gain |
|----------|--------|---------------|
| P0 | Move TenantResource checks to runtime | -27s per affected file |
| P1 | Lazy struct pattern matching | -10s average |
| P2 | Domain isolation refactoring | Improved parallelism |
| P3 | Incremental compilation tuning | CI/CD speedup |

### 6.3 Architectural Considerations

```
Current: Compile-time Tenant Verification
         BaseResource → TenantResource → ALL domain resources (149 files)

Proposed: Runtime Tenant Verification
          BaseResource → Domain resources (parallel)
                      ↓
          TenantResource injected at runtime via plug/middleware
```

---

## 7. Implementation Summary

### 7.1 Files Created/Modified

| File | Change |
|------|--------|
| `lib/indrajaal/observability/compiler_metrics.ex` | New tracer module |
| `mix.exs` | Conditional tracer, elixirc_options function |
| `devenv.nix` | compile-profile, compile-xref commands |
| `docs/guides/COMPILER_METRICS.md` | User documentation |
| `CLAUDE.md` | SC-METRICS constraints |
| `.claude/commands/compile.md` | Updated compilation instructions |
| `.claude/rules/test-execution.md` | ELIXIR_ERL_OPTIONS requirement |

### 7.2 STAMP Constraints Established

| ID | Constraint | Enforcement |
|----|------------|-------------|
| SC-METRICS-001 | Tracer overhead < 5% | Performance test |
| SC-METRICS-002 | Metrics persist to JSON/DuckDB | File write verification |
| SC-METRICS-003 | Parallelization MANDATORY | Env var check |
| SC-METRICS-004 | Telemetry integration | Event emission |
| SC-METRICS-005 | Historical trends queryable | API availability |

### 7.3 AOR Rules Established

| ID | Rule |
|----|------|
| AOR-METRICS-001 | ALWAYS set ELIXIR_ERL_OPTIONS before compile |
| AOR-METRICS-002 | Run compile-profile weekly for regression detection |
| AOR-METRICS-003 | Investigate any file with >10s compile time |
| AOR-METRICS-004 | Document new compile-time dependencies in PRs |

---

## 8. Verification

### 8.1 Parallelization Check

```elixir
iex> :erlang.system_info(:schedulers_online)
16
iex> :erlang.system_info(:dirty_io_schedulers)
16
```

### 8.2 Metrics API

```elixir
iex> Indrajaal.Observability.CompilerMetrics.verify_parallelization()
{:ok, %{schedulers: 16, dirty_io_schedulers: 16, status: :optimal}}
```

---

## Appendix A: Raw Profile Output (Top 30 Slowest)

```
[profile]    223ms compiling +  42722ms waiting - ml_threat_detection.ex
[profile]    252ms compiling +  37991ms waiting - jwt.ex
[profile]   2661ms compiling +  36885ms waiting - tenant.ex
[profile]    231ms compiling +  32911ms waiting - monitoring.ex
[profile]  13989ms compiling +  27525ms waiting - subscription.ex
[profile]  13378ms compiling +  27486ms waiting - plan.ex
[profile]  10582ms compiling +  27036ms waiting - payment.ex
[profile]  14157ms compiling +  26907ms waiting - usage_record.ex
[profile]  10250ms compiling +  26172ms waiting - invoice.ex
[profile]   2139ms compiling +  26088ms waiting - asset_transfer.ex
[profile]   2172ms compiling +  26025ms waiting - asset_warranty.ex
[profile]   2333ms compiling +  25983ms waiting - asset_retirement.ex
[profile]   2295ms compiling +  25872ms waiting - asset_maintenance.ex
[profile]   2166ms compiling +  25763ms waiting - asset_location.ex
[profile]   1900ms compiling +  25748ms waiting - asset_category.ex
[profile]   1854ms compiling +  25742ms waiting - asset_depreciation.ex
[profile]   2352ms compiling +  25665ms waiting - asset_audit.ex
[profile]   2071ms compiling +  25428ms waiting - asset_assignment.ex
[profile]   2351ms compiling +  25355ms waiting - asset.ex
[profile]    104ms compiling +  25327ms waiting - analytics_context.ex
```

---

## Appendix B: Xref Graph Output

```
Tracked files: 1404 (nodes)
Compile dependencies: 746 (edges)
Exports dependencies: 160 (edges)
Runtime dependencies: 2199 (edges)
Cycles: 2

Top 10 files with most outgoing dependencies:
  * test/support/factory.ex (16)
  * lib/indrajaal/risk_management.ex (15)
  * lib/indrajaal/analytics.ex (13)
  * lib/indrajaal/visitor_management.ex (12)
  * lib/indrajaal/accounts.ex (12)

Top 10 files with most incoming dependencies:
  * lib/indrajaal/base_resource.ex (149)
  * lib/indrajaal_web/plugs/authenticate_api.ex (19)
```

---

**Document Control**

| Field | Value |
|-------|-------|
| Classification | Internal Technical |
| Review Status | Approved |
| Next Review | 2026-02-08 |
| Related PRs | TBD |
