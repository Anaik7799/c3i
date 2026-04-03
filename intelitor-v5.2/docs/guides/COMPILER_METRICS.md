# Compiler Metrics Guide (SC-METRICS-001)

**Version**: 21.3.0-SIL6
**Updated**: 2026-01-11
**Compliance**: IEC 61508 SIL-6, ISO 27001, GDPR

## Overview

This guide documents the 7-level fractal compilation metrics system for Indrajaal v21.3.0-SIL6, implementing SC-METRICS-001 through SC-METRICS-005 constraints.

## Quick Start

```bash
# Enter devenv shell
devenv shell

# Standard compilation (16 schedulers active by default)
compile

# Profiled compilation with timing metrics
compile-profile

# Dependency graph analysis
compile-xref
```

## 7-Level Fractal Analysis

### L1 - Runtime/Code Level
- Per-file compilation time (ms)
- Per-file wait time for dependencies (ms)
- Bytecode size per module (bytes)

### L2 - Function/Module Level
- Module complexity metrics
- Macro expansion overhead
- Struct dependency chains

### L3 - Component/Domain Level
- Domain-level compilation times
- Cross-domain dependency hotspots

### L4 - Holon/Container Level
- Container compilation overhead
- NIF compilation times (Zenoh, LineageAuth)

### L5 - Node/Cluster Level
- Total compilation wall-clock time
- Scheduler utilization (+S 16:16)
- Parallelization efficiency

### L6 - Federation/CI Level
- CI/CD pipeline metrics
- Build cache hit rates

### L7 - Ecosystem Level
- Dependency update impact
- External library overhead

## Current Bottleneck Analysis

Based on `compile-profile` output:

| File | Compile | Wait | Blocked By |
|------|---------|------|------------|
| `billing/subscription.ex` | 14s | 27.5s | TenantResource |
| `billing/plan.ex` | 13.4s | 27.5s | TenantResource |
| `core/tenant.ex` | 2.7s | 36.9s | ResourceHelpers |
| `ai/domain.ex` | 1.3s | 0s | - |
| `access_control_domain.ex` | 1.4s | 0s | - |

**Root Cause**: `Multitenancy.TenantResource` causes 27+ second wait times for 20+ files.

## STAMP Constraints

| ID | Constraint | Status |
|----|------------|--------|
| SC-METRICS-001 | Tracer overhead < 5% | COMPLIANT |
| SC-METRICS-002 | Metrics persist to JSON/DuckDB | COMPLIANT |
| SC-METRICS-003 | 16 schedulers MANDATORY (+S 16:16 +SDio 16) | COMPLIANT |
| SC-METRICS-004 | Telemetry integration | COMPLIANT |
| SC-METRICS-005 | Historical trends queryable | COMPLIANT |
| SC-METRICS-006 | 7-level fractal analysis (L1-L7) | COMPLIANT |
| SC-METRICS-007 | Parallel deps (PARTITION_COUNT=8) | COMPLIANT |

## Configuration

### Environment Variables (Always Set via devenv.nix)

```bash
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"  # 16 schedulers, 16 dirty I/O
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8    # Parallel dep compilation
NO_TIMEOUT=true                          # Patient Mode
PATIENT_MODE=enabled                     # Patient Mode
```

### Optional Tracer Activation

```bash
# Enable tracer for subsequent compilations (after bootstrap)
COMPILE_TRACER=1 mix compile
```

## DevEnv Commands

| Command | Description |
|---------|-------------|
| `compile` | Standard compilation with 16 schedulers |
| `compile-strict` | Compilation with warnings as errors |
| `compile-profile` | Profiled compilation with timing analysis |
| `compile-xref` | Dependency graph statistics |

## Metrics API

```elixir
# Get last compilation metrics
Indrajaal.Observability.CompilerMetrics.get_last_compilation()

# Get historical stats (last 7 days)
Indrajaal.Observability.CompilerMetrics.get_historical_stats(days: 7)

# Get slowest files
Indrajaal.Observability.CompilerMetrics.get_slowest_files(20)

# Get domain breakdown
Indrajaal.Observability.CompilerMetrics.get_domain_breakdown()

# Verify parallelization settings
Indrajaal.Observability.CompilerMetrics.verify_parallelization()

# Print formatted summary
Indrajaal.Observability.CompilerMetrics.print_summary()
```

## Output Locations

| Path | Content |
|------|---------|
| `data/tmp/1-compile.log` | Standard compilation log |
| `data/metrics/compile-profile-*.log` | Profiled compilation logs |
| `data/metrics/compilation_metrics.json` | Latest metrics JSON |
| `data/metrics/compilation_history.json` | Historical metrics |

## Xref Graph Stats

Run `compile-xref` to see:

```
Tracked files: 1404 (nodes)
Compile dependencies: 746 (edges)
Exports dependencies: 160 (edges)
Runtime dependencies: 2199 (edges)
Cycles: 2

Top files with most incoming dependencies:
  * lib/indrajaal/base_resource.ex (149)
  * lib/indrajaal_web/plugs/authenticate_api.ex (19)
```

## Optimization Recommendations

1. **Reduce TenantResource Coupling**: Move multitenancy checks to runtime
2. **Lazy Struct Loading**: Use `@derive` for struct dependencies
3. **Domain Isolation**: Reduce cross-domain compile-time deps
4. **Incremental Builds**: Use `mix compile --no-all-warnings`

## Telemetry Events

```elixir
# Event: [:indrajaal, :compilation, :complete]
# Measurements: duration_ms, files_compiled, warnings, errors, efficiency
# Metadata: session_id, schedulers
```

## Related Documents

- `CLAUDE.md` - SC-METRICS constraints (v21.3.0-SIL6)
- `docs/guides/USER_OPERATIONS_GUIDE.md` - User operations and commands
- `docs/guides/comprehensive-compilation-system.md` - Full compilation system
- `lib/indrajaal/observability/compiler_metrics.ex` - Tracer implementation
- `mix.exs` - Compiler options configuration
- `devenv.nix` - Environment setup
