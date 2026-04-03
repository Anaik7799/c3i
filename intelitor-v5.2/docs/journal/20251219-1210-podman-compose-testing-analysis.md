# Podman-Compose Testing Infrastructure Analysis

**Date**: 2025-12-19T12:10:00+01:00
**Session**: Container Testing Infrastructure Validation
**STAMP Compliance**: SC-CNT-009, SC-CNT-010, SC-CNT-012

---

## Executive Summary

Comprehensive analysis of `podman-compose-testing.yml` to ensure testing infrastructure works without problems. Found that host-based testing is fully functional, but app containers have compilation issues due to stale volume artifacts.

---

## Container Status Dashboard

| Container | Status | Health | Issue |
|-----------|--------|--------|-------|
| indrajaal-db-primary | Up 14h | healthy | PostgreSQL:5433 accepting connections |
| indrajaal-db-replica | Up 14h | healthy | Missing role (standalone, not true replica) |
| indrajaal-app-1 | Crash loop | starting | mimerl compilation fails |
| indrajaal-app-2 | Exited (1) | - | mimerl compilation fails |
| indrajaal-app-3 | Exited (1) | - | mimerl compilation fails |
| indrajaal-obs | Up 14h | healthy | Prometheus placeholder working |

---

## Root Cause Analysis

### Issue: App Container Compilation Failure

**Error Message:**
```
** (Mix) Could not compile dependency :mimerl,
"/workspace/.mix/elixir/1-19-otp-28/rebar3 bare compile
--paths /workspace/_build/test/lib/*/ebin" command failed.
```

**Cause:** Volume mounts create stale/incompatible build artifacts:
- `indrajaal-v52_app1_deps`, `indrajaal-v52_app1_build`
- `indrajaal-v52_app2_deps`, `indrajaal-v52_app2_build`
- `indrajaal-v52_app3_deps`, `indrajaal-v52_app3_build`

**Impact:** App containers cannot start. However, this does NOT affect host-based testing.

---

## Testing Infrastructure Validation

### Host-Based Testing Status

| Component | Status | Details |
|-----------|--------|---------|
| Database connection | WORKING | localhost:5433 accepting connections |
| Ecto migrations | WORKING | Migrations run successfully |
| Test execution | WORKING | Tests execute (found test code bug) |
| CAFE framework | WORKING | Discovered 514 tests |

### Database Connectivity Test

```sql
-- Primary Database (WORKING)
SELECT 'Database OK' as status, current_timestamp as time;
   status    |             time
-------------+-------------------------------
 Database OK | 2025-12-19 12:09:17.647615+00

-- Replica Database (ISSUE)
psql: error: FATAL: role "indrajaal" does not exist
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TESTING ARCHITECTURE (172.31.0.0/24)                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  DATABASE CLUSTER                                                       │
│  ┌─────────────────────────┐    ┌─────────────────────────┐            │
│  │ indrajaal-db-primary    │    │ indrajaal-db-replica    │            │
│  │ 172.31.0.10:5433        │    │ 172.31.0.11:5434        │            │
│  │ TimescaleDB + PostGIS   │    │ PgBouncer:6432          │            │
│  │ 4GB RAM / 2 CPU         │    │ 4GB RAM / 2 CPU         │            │
│  │ STATUS: HEALTHY         │    │ STATUS: HEALTHY (*)     │            │
│  └─────────────────────────┘    └─────────────────────────┘            │
│                                                                         │
│  APPLICATION CLUSTER (FAILING)                                          │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐                 │
│  │ app-1         │ │ app-2         │ │ app-3         │                 │
│  │ 172.31.0.20   │ │ 172.31.0.21   │ │ 172.31.0.22   │                 │
│  │ :4000         │ │ :4001         │ │ :4002         │                 │
│  │ 4GB/4CPU      │ │ 4GB/4CPU      │ │ 4GB/4CPU      │                 │
│  │ CRASH LOOP    │ │ EXITED (1)    │ │ EXITED (1)    │                 │
│  └───────────────┘ └───────────────┘ └───────────────┘                 │
│                                                                         │
│  OBSERVABILITY                                                          │
│  ┌─────────────────────────────────────────────────────┐               │
│  │ indrajaal-obs (172.31.0.30)                         │               │
│  │ Prometheus:9090 | Grafana:3000                      │               │
│  │ 2GB RAM / 1 CPU | STATUS: HEALTHY                   │               │
│  └─────────────────────────────────────────────────────┘               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Testing Requirements

### Minimum (Host-based `mix test`)
- **REQUIRED**: `indrajaal-db-primary` (PostgreSQL on port 5433)
- All other containers are optional for host-based testing

### Full Cluster (Container-based Phoenix)
- `indrajaal-db-primary` - Primary database
- `indrajaal-db-replica` - Connection pooling (optional)
- `indrajaal-app-{1,2,3}` - Application nodes (need fix)
- `indrajaal-obs` - Observability (optional)

---

## Remediation Steps

### Fix App Container Volumes

```bash
# Stop all containers
podman-compose -f podman-compose-testing.yml down

# Remove stale build volumes
podman volume rm indrajaal-v52_app1_deps indrajaal-v52_app1_build
podman volume rm indrajaal-v52_app2_deps indrajaal-v52_app2_build
podman volume rm indrajaal-v52_app3_deps indrajaal-v52_app3_build

# Restart with fresh volumes
podman-compose -f podman-compose-testing.yml up -d
```

### Run Tests Now (Host-Based)

```bash
# Set environment and run tests
POSTGRES_USER=indrajaal \
POSTGRES_PASSWORD=indrajaal_test \
DATABASE_URL="ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test" \
MIX_ENV=test mix test

# Or use CAFE framework
POSTGRES_USER=indrajaal \
POSTGRES_PASSWORD=indrajaal_test \
DATABASE_URL="ecto://indrajaal:indrajaal_test@localhost:5433/indrajaal_test" \
MIX_ENV=test mix cafe.execute --dry-run
```

---

## CAFE Framework Test Discovery

```
Test Discovery Results:
═══════════════════════════════════════════════════════════════════
🔴 C1_CRITICAL: 8 tests
🟠 C2_HIGH: 22 tests
🟡 C3_MEDIUM: 84 tests
🟢 C4_LOW: 120 tests
⚪ C5_OPTIONAL: 280 tests

📈 Total: 514 tests discovered
═══════════════════════════════════════════════════════════════════
```

---

## Verdict

| Aspect | Status | Notes |
|--------|--------|-------|
| YAML Syntax | VALID | No parse errors |
| Database Containers | WORKING | Primary healthy, replica standalone |
| App Containers | FAILING | Stale volumes cause mimerl build failure |
| Host-Based Testing | WORKING | Can run `mix test` from host |
| CAFE Framework | WORKING | Discovers all 514 tests |

**Conclusion**: Testing infrastructure IS FUNCTIONAL for host-based `mix test`. App containers need volume cleanup to fix mimerl compilation for full cluster operation.

---

## STAMP Compliance

- **SC-CNT-009**: NixOS containers ONLY - COMPLIANT (all images from localhost/)
- **SC-CNT-010**: localhost/ registry ONLY - COMPLIANT
- **SC-CNT-012**: Rootless Podman - COMPLIANT
- **SC-CNT-014**: Resource isolation - COMPLIANT (limits defined)

---

## Files Analyzed

- `/home/an/dev/ver/indrajaal-v5.2/podman-compose-testing.yml` (371 lines)
- `/home/an/dev/ver/indrajaal-v5.2/lib/mix/tasks/cafe.execute.ex` (467 lines)

---

**Document Generated**: 2025-12-19T12:10:00+01:00
**Author**: Claude Code (Opus 4.5)
**Session**: Container Infrastructure Analysis
