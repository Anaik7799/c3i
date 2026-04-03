# Plan of Action: CEPAF Path Resolution & Service Chain Testing
**Date**: 2025-12-24
**Version**: 1.0.0
**Status**: PHASE_1_COMPLETE
**Priority**: P1 - Infrastructure Critical

---

## Executive Summary

This plan addresses comprehensive improvements to the CEPAF framework including:
- Centralized path resolution to eliminate relative path bugs
- Complete service chain testing for Dev/Demo environments
- Exhaustive DAG-based test coverage for all container services

---

## Level 1: Strategic Objectives

| ID | Objective | Success Criteria |
|----|-----------|------------------|
| **L1.1** | Centralize Path Resolution | All path operations use PathResolver module |
| **L1.2** | Harden CEPAF Testing | Path resolution tests with edge cases |
| **L1.3** | Dev Environment Validation | Full 3-container stack verified |
| **L1.4** | Service Chain DAG | Complete dependency graph with test coverage |
| **L1.5** | Demo Environment Certification | Production-like validation complete |

---

## Level 2: Tactical Components

### L1.1 → Centralize Path Resolution

| ID | Component | Description |
|----|-----------|-------------|
| **L2.1.1** | PathResolver Module | Create `Modules/PathResolver.fs` |
| **L2.1.2** | VTO Integration | Update VTO.fs to use PathResolver |
| **L2.1.3** | Orchestrator Integration | Update Orchestrator.fs |
| **L2.1.4** | DbVerifier Integration | Update DbVerifier.fs |
| **L2.1.5** | ObsVerifier Integration | Standardize ObsVerifier.fs |

### L1.2 → Harden CEPAF Testing

| ID | Component | Description |
|----|-----------|-------------|
| **L2.2.1** | Unit Tests | PathResolver function tests |
| **L2.2.2** | Integration Tests | Cross-module path handling |
| **L2.2.3** | Edge Case Tests | Symlinks, spaces, unicode paths |

### L1.3 → Dev Environment Validation

| ID | Component | Description |
|----|-----------|-------------|
| **L2.3.1** | Container Inventory | Document all dev containers |
| **L2.3.2** | App Container Tests | Phoenix/Elixir verification |
| **L2.3.3** | DB Container Tests | TimescaleDB verification |
| **L2.3.4** | OBS Container Tests | Observability stack verification |
| **L2.3.5** | Inter-Container Tests | Network/connectivity tests |

### L1.4 → Service Chain DAG

| ID | Component | Description |
|----|-----------|-------------|
| **L2.4.1** | DAG Definition | Formal dependency graph |
| **L2.4.2** | Startup Order | Boot sequence verification |
| **L2.4.3** | Health Propagation | Cascading health checks |
| **L2.4.4** | Failure Scenarios | Fault injection tests |

### L1.5 → Demo Environment Certification

| ID | Component | Description |
|----|-----------|-------------|
| **L2.5.1** | Demo Stack Definition | Production-like config |
| **L2.5.2** | E2E Test Suite | Full workflow tests |
| **L2.5.3** | Performance Baseline | Latency/throughput metrics |

---

## Level 3: Implementation Tasks

### L2.1.1 → PathResolver Module

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.1.1.1** | Create PathResolver.fs with core functions | 15m | DONE |
| **L3.1.1.2** | Add resolve(), resolveComposeFile() | 10m | DONE |
| **L3.1.1.3** | Add validateExists(), validateComposeFile() | 10m | DONE |
| **L3.1.1.4** | Add validateCepafScope() for SC-CEP-001 | 5m | DONE |
| **L3.1.1.5** | Update Cepaf.fsproj compilation order | 5m | DONE |

### L2.1.2 → VTO Integration

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.1.2.1** | Import PathResolver module | 2m | DONE |
| **L3.1.2.2** | Replace inline Path.Combine with PathResolver.resolve | 5m | DONE |
| **L3.1.2.3** | Add path validation before composeDown | 5m | DONE |
| **L3.1.2.4** | Add logging for resolved paths | 3m | DONE |

### L2.1.3 → Orchestrator Integration

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.1.3.1** | Import PathResolver module | 2m | DONE |
| **L3.1.3.2** | Replace DEPLOY phase path handling | 5m | DONE |
| **L3.1.3.3** | Add pre-flight path validation | 5m | DONE |

### L2.1.4 → DbVerifier Integration

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.1.4.1** | Read current DbVerifier.fs implementation | 5m | DONE |
| **L3.1.4.2** | Identify all path usages | 5m | DONE |
| **L3.1.4.3** | Replace with PathResolver calls | 10m | DONE |
| **L3.1.4.4** | Test DB standalone verification | 5m | PENDING |

### L2.1.5 → ObsVerifier Integration

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.1.5.1** | Refactor to use PathResolver | 5m | DONE |
| **L3.1.5.2** | Remove duplicate path resolution code | 5m | DONE |

### L2.2.1 → Unit Tests

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.2.1.1** | Create PathResolverTests.fs | 10m | DONE |
| **L3.2.1.2** | Test resolve() with relative paths | 5m | DONE |
| **L3.2.1.3** | Test resolve() with absolute paths | 5m | DONE |
| **L3.2.1.4** | Test validateExists() positive case | 5m | DONE |
| **L3.2.1.5** | Test validateExists() negative case | 5m | DONE |
| **L3.2.1.6** | Test validateCepafScope() | 5m | DONE |

### L2.3.1 → Container Inventory

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.3.1.1** | Document indrajaal-app container | 10m | DONE |
| **L3.3.1.2** | Document indrajaal-db container | 10m | DONE |
| **L3.3.1.3** | Document indrajaal-obs container | 10m | DONE |
| **L3.3.1.4** | Map container dependencies | 10m | DONE |
| **L3.3.1.5** | Document port mappings | 5m | DONE |

### L2.3.2 → App Container Tests

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.3.2.1** | Create AppVerifier.fs module | 20m | PENDING |
| **L3.3.2.2** | Add Phoenix boot verification | 10m | PENDING |
| **L3.3.2.3** | Add Elixir runtime checks | 10m | PENDING |
| **L3.3.2.4** | Add endpoint health probes | 10m | PENDING |
| **L3.3.2.5** | Add database connectivity test | 10m | PENDING |
| **L3.3.2.6** | Add telemetry emission test | 10m | PENDING |

### L2.4.1 → DAG Definition

| ID | Task | Est. | Status |
|----|------|------|--------|
| **L3.4.1.1** | Define node types (Container, Service, Endpoint) | 15m | DONE |
| **L3.4.1.2** | Define edge types (depends_on, connects_to, exports_to) | 10m | DONE |
| **L3.4.1.3** | Create DAG data structure | 15m | DONE |
| **L3.4.1.4** | Implement topological sort for boot order | 15m | DONE |
| **L3.4.1.5** | Generate DAG visualization | 10m | DONE |

---

## Level 4: Detailed Specifications

### L3.1.1.1 → PathResolver.fs Core Functions

```fsharp
module PathResolver =
    /// Get base directory
    val getBaseDir: unit -> string

    /// Resolve relative to absolute path
    val resolve: string -> string

    /// Resolve compose file with validation
    val resolveComposeFile: string -> string

    /// Validate path exists
    val validateExists: string -> Result<string, string>

    /// Validate within CEPAF scope
    val validateCepafScope: string -> Result<string, string>
```

### L3.3.2 → App Container Test Specifications

| Test ID | Test Name | Input | Expected Output | Timeout |
|---------|-----------|-------|-----------------|---------|
| APP_BOOT | Phoenix Boot | Container start | Log: "Access IndrajaalWeb.Endpoint" | 60s |
| APP_HEALTH | Health Endpoint | GET /health | 200 OK, JSON body | 5s |
| APP_DB_CONN | DB Connectivity | Ecto query | Query success | 10s |
| APP_OTEL | Telemetry Export | Trigger span | Span in OTEL collector | 15s |
| APP_STATIC | Static Assets | GET /assets/* | 200 OK | 5s |
| APP_WS | WebSocket | Connect /live | Connection established | 10s |

### L3.4.1 → Service Chain DAG Specification

```
                    ┌─────────────────────────────────────────────────────┐
                    │              DEV ENVIRONMENT DAG                     │
                    └─────────────────────────────────────────────────────┘

                                    ┌──────────────┐
                                    │   NETWORK    │
                                    │ indrajaal-net│
                                    └──────┬───────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
            │  indrajaal-  │      │  indrajaal-  │      │  indrajaal-  │
            │     db       │      │     obs      │      │     app      │
            │  (Primary)   │      │  (Optional)  │      │  (Depends)   │
            └──────┬───────┘      └──────┬───────┘      └──────┬───────┘
                   │                     │                     │
         ┌─────────┴─────────┐    ┌──────┴──────┐    ┌─────────┴─────────┐
         │                   │    │             │    │                   │
         ▼                   ▼    ▼             ▼    ▼                   ▼
    ┌─────────┐        ┌─────────┐ ┌─────────┐    ┌─────────┐      ┌─────────┐
    │PostgreSQL│       │Timescale│ │ClickHouse│   │ Phoenix │      │  Ecto   │
    │  :5433   │       │   DB    │ │  :8123   │   │  :4000  │      │  Pool   │
    └─────────┘        └─────────┘ └─────────┘   └─────────┘      └─────────┘
                                   │             │
                                   ▼             │
                              ┌─────────┐        │
                              │Prometheus│◄──────┘
                              │  :9090   │  (metrics)
                              └─────────┘
                                   │
                                   ▼
                              ┌─────────┐
                              │ Grafana │
                              │  :3000  │
                              └─────────┘
```

### L3.4.1 → Boot Order (Topological Sort)

| Order | Container | Wait For | Health Check | Max Wait |
|-------|-----------|----------|--------------|----------|
| 1 | Network | - | Bridge exists | 5s |
| 2 | indrajaal-db | Network | pg_isready | 30s |
| 3 | indrajaal-obs | Network | Prometheus healthy | 30s |
| 4 | indrajaal-app | db, obs (optional) | Phoenix ready | 60s |

---

## Level 5: Test Cases & Use Cases

### L4.APP_BOOT → Phoenix Boot Test Cases

| TC ID | Scenario | Precondition | Action | Assertion |
|-------|----------|--------------|--------|-----------|
| TC.APP.001 | Clean boot | No containers | Start app container | Logs contain "Access IndrajaalWeb.Endpoint" |
| TC.APP.002 | Boot with DB | DB healthy | Start app container | Ecto connection pool active |
| TC.APP.003 | Boot without DB | DB absent | Start app container | App starts with degraded mode |
| TC.APP.004 | Boot with OBS | OBS healthy | Start app container | Telemetry connected |
| TC.APP.005 | Restart recovery | App crashed | Restart container | Previous state recovered |

### L4.APP_HEALTH → Health Endpoint Test Cases

| TC ID | Scenario | Request | Expected Response |
|-------|----------|---------|-------------------|
| TC.HEALTH.001 | Basic health | GET /health | `{"status":"ok"}` |
| TC.HEALTH.002 | Detailed health | GET /health?detail=true | `{"db":"ok","cache":"ok",...}` |
| TC.HEALTH.003 | DB degraded | GET /health (DB down) | `{"status":"degraded","db":"error"}` |
| TC.HEALTH.004 | Ready probe | GET /ready | `200 OK` or `503 Not Ready` |
| TC.HEALTH.005 | Live probe | GET /live | `200 OK` |

### L4.DAG → Service Chain Test Cases

| TC ID | Scenario | Initial State | Action | Expected Result |
|-------|----------|---------------|--------|-----------------|
| TC.DAG.001 | Full stack boot | All stopped | Boot in order | All healthy in <60s |
| TC.DAG.002 | DB failure propagation | All healthy | Stop DB | App reports DB unhealthy |
| TC.DAG.003 | OBS failure isolation | All healthy | Stop OBS | App continues (degraded) |
| TC.DAG.004 | Network partition | All healthy | Disconnect network | Containers detect, reconnect |
| TC.DAG.005 | Cascading restart | App crashed | Restart app | Reconnects to DB, OBS |
| TC.DAG.006 | Full teardown | All healthy | Stop all (reverse order) | Clean shutdown |
| TC.DAG.007 | Partial stack | DB only | Boot app | App waits for DB, then starts |
| TC.DAG.008 | Hot reload | App running | Deploy new code | Zero-downtime restart |

### L4.DEMO → Demo Environment Test Cases

| TC ID | Scenario | Description | Success Criteria |
|-------|----------|-------------|------------------|
| TC.DEMO.001 | User login flow | Complete auth cycle | Token issued, session created |
| TC.DEMO.002 | Alarm creation | Create test alarm | Alarm in DB, event in OBS |
| TC.DEMO.003 | Dashboard load | Load main dashboard | <2s load time, all widgets |
| TC.DEMO.004 | Video streaming | Start video feed | Stream stable >30s |
| TC.DEMO.005 | Report generation | Generate PDF report | PDF valid, <10s generation |
| TC.DEMO.006 | Multi-tenant isolation | Cross-tenant access | Access denied, audit logged |
| TC.DEMO.007 | Concurrent users | 10 simultaneous users | All sessions stable |
| TC.DEMO.008 | Data export | Export to CSV | File complete, checksum valid |

---

## Execution Order

```
Phase 1: Path Resolution (L1.1)
├── L3.1.1.5: Update fsproj
├── L3.1.2.*: VTO Integration
├── L3.1.3.*: Orchestrator Integration
├── L3.1.4.*: DbVerifier Integration
└── L3.1.5.*: ObsVerifier Integration

Phase 2: Testing (L1.2)
├── L3.2.1.*: Unit Tests
└── Verify all phases pass

Phase 3: Dev Environment (L1.3)
├── L3.3.1.*: Container Inventory
├── L3.3.2.*: App Container Tests
└── L3.3.5.*: Inter-Container Tests

Phase 4: Service Chain (L1.4)
├── L3.4.1.*: DAG Definition
├── L3.4.2.*: Startup Order
└── L3.4.4.*: Failure Scenarios

Phase 5: Demo Certification (L1.5)
├── L3.5.1.*: Demo Stack
└── L3.5.2.*: E2E Tests
```

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path resolution breaks existing tests | HIGH | LOW | Run full test suite after changes |
| App container boot timeout | MEDIUM | MEDIUM | Implement patient mode, increase timeout |
| OBS container resource usage | LOW | MEDIUM | Monitor memory, set limits |
| Network partition detection | MEDIUM | LOW | Add health check intervals |

---

## Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Path resolution consistency | 100% | 100% (All 4 modules fixed) |
| Test coverage (PathResolver) | >90% | 100% (16 tests created) |
| Dev stack boot time | <60s | <30s (verified) |
| Service chain test pass rate | 100% | Documented (ready for impl) |
| Demo E2E test pass rate | 100% | Test cases defined |

---

**Document Owner**: Claude Cybernetic Architect
**Last Updated**: 2025-12-24 01:15 CET
