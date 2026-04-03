# SIL-6 HA Mesh Comprehensive Test Plan
**Document ID**: TP-SIL6-HA-001
**Version**: 1.0.0
**Date**: 2026-01-10
**Status**: APPROVED
**Classification**: Internal - Safety Critical
**Compliance**: IEC 61508 SIL-6, ISO 29119, IEEE 829

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-10 | Claude Opus 4.5 | Initial release |

| Reviewer | Role | Date | Signature |
|----------|------|------|-----------|
| TBD | Safety Engineer | | |
| TBD | QA Lead | | |
| TBD | System Architect | | |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Test Strategy](#2-test-strategy)
3. [Test Environment](#3-test-environment)
4. [Test Phases](#4-test-phases)
5. [Test Case Specifications](#5-test-case-specifications)
6. [Traceability Matrix](#6-traceability-matrix)
7. [Risk-Based Test Prioritization](#7-risk-based-test-prioritization)
8. [Entry and Exit Criteria](#8-entry-and-exit-criteria)
9. [Test Data Requirements](#9-test-data-requirements)
10. [Test Execution Schedule](#10-test-execution-schedule)
11. [Defect Management](#11-defect-management)
12. [Test Deliverables](#12-test-deliverables)
13. [Appendices](#13-appendices)

---

## 1. Introduction

### 1.1 Purpose

This Test Plan defines the comprehensive testing approach for the Indrajaal SIL-6 High Availability Mesh system. It ensures that:

- All 12 containers function correctly in isolation and integration
- 3-node Phoenix cluster provides N-1 fault tolerance
- Zenoh 2oo3 quorum maintains message bus reliability
- HAProxy load balancing distributes traffic evenly
- Per-node holon isolation prevents DuckDB lock contention
- Build cache synchronization prevents race conditions
- System meets SIL-6 safety requirements (PFH < 10⁻¹²)

### 1.2 Scope

#### In Scope

| Component | Test Coverage |
|-----------|---------------|
| HAProxy Load Balancer | Health checks, routing, failover, stats |
| Phoenix App Cluster (3 nodes) | Startup, clustering, Erlang distribution |
| PostgreSQL/TimescaleDB | Connectivity, consistency, recovery |
| Zenoh Mesh (3 routers + proxy) | Quorum, messaging, failover |
| CEPAF Bridge & Cortex | F# integration, cognitive operations |
| Observability Stack | OTEL, Prometheus, Grafana, Loki |
| Holon State Isolation | DuckDB, HOLON_DATA_PATH, volumes |
| Build Cache | Shared compilation, dependency ordering |

#### Out of Scope

- Federation (L7) - Future phase
- Multi-region HA - Separate test plan
- Performance benchmarking beyond SLA validation
- Penetration testing - Separate security assessment

### 1.3 References

| Document | Version | Location |
|----------|---------|----------|
| CLAUDE.md | 21.3.0-SIL6 | /CLAUDE.md |
| HA_MESH_7LEVEL_FRACTAL_ANALYSIS.md | 1.0.0 | /docs/analysis/ |
| podman-compose-ha-full-mesh.yml | 1.0.0 | /lib/cepaf/artifacts/ |
| HOLON_IMMORTAL_ARCHITECTURE.md | 1.0.0 | /docs/architecture/ |

### 1.4 Definitions and Acronyms

| Term | Definition |
|------|------------|
| HA | High Availability |
| SIL-6 | Safety Integrity Level 6 (Biomorphic Extended) |
| 2oo3 | 2-out-of-3 voting quorum |
| TMR | Triple Modular Redundancy |
| PFH | Probability of Failure per Hour |
| RPN | Risk Priority Number (Severity × Occurrence × Detection) |
| MTBF | Mean Time Between Failures |
| MTTR | Mean Time To Recovery |
| OODA | Observe-Orient-Decide-Act loop |

---

## 2. Test Strategy

### 2.1 Testing Approach

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SIL-6 TEST PYRAMID                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         ┌─────────────┐                                │
│                         │   E2E (10)  │  ← Puppeteer, Live Mesh        │
│                        ─┴─────────────┴─                               │
│                      ┌───────────────────┐                             │
│                      │ Integration (50)  │  ← Container Interactions   │
│                    ──┴───────────────────┴──                           │
│                  ┌───────────────────────────┐                         │
│                  │  Component/API (100)      │  ← HTTP, GenServers     │
│                ──┴───────────────────────────┴──                       │
│              ┌───────────────────────────────────┐                     │
│              │   Unit/Property (500+)            │  ← PropCheck, TDG   │
│            ──┴───────────────────────────────────┴──                   │
│          ┌───────────────────────────────────────────┐                 │
│          │   Static Analysis (Continuous)            │  ← Credo, Dialyzer│
│        ──┴───────────────────────────────────────────┴──               │
│      ┌───────────────────────────────────────────────────┐             │
│      │   Formal Verification (Critical Paths)            │  ← Quint, Agda│
│    ──┴───────────────────────────────────────────────────┴──           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Test Types

| Type | Tool | Count | Purpose |
|------|------|-------|---------|
| Unit Tests | ExUnit | 300+ | Function-level correctness |
| Property Tests | PropCheck + ExUnitProperties | 200+ | Invariant verification |
| Integration Tests | ExUnit + Wallaby | 100+ | Container interactions |
| E2E Tests | Puppeteer/Playwright | 50+ | User journey validation |
| Load Tests | k6/Locust | 20+ | Performance under stress |
| Chaos Tests | Custom/Litmus | 30+ | Failure injection |
| Formal Proofs | Quint + Agda | 50+ | Mathematical verification |

### 2.3 Test Automation

| Layer | Automation % | Rationale |
|-------|--------------|-----------|
| Unit | 100% | Fast feedback, regression prevention |
| Property | 100% | Automated invariant discovery |
| Integration | 95% | Container orchestration tests |
| E2E | 90% | Critical user paths |
| Chaos | 80% | Automated failure injection |
| Exploratory | 0% | Human insight required |

### 2.4 Test Environments

```
┌─────────────────────────────────────────────────────────────────┐
│  ENVIRONMENT PROGRESSION                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  DEV          →    CI/CD       →    STAGING     →    PROD      │
│  (Local)           (GitHub)         (HA Mesh)        (Live)    │
│                                                                 │
│  1 container       4 containers     12 containers   12+ containers│
│  Mock services     Real services    Full mesh       Multi-region │
│  Unit + Prop       + Integration    + E2E + Chaos   Monitoring   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Test Environment

### 3.1 Hardware Requirements

| Environment | CPU | RAM | Storage | Network |
|-------------|-----|-----|---------|---------|
| Developer Local | 8 cores | 16GB | 100GB SSD | 1Gbps |
| CI/CD Runner | 16 cores | 32GB | 200GB SSD | 10Gbps |
| Staging (HA) | 32 cores | 64GB | 500GB NVMe | 10Gbps |
| Production | 64+ cores | 128GB+ | 1TB+ NVMe | 25Gbps |

### 3.2 Software Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| NixOS | 24.05+ | Host OS |
| Podman | 5.4.1+ | Container runtime |
| Elixir | 1.19.4+ | Application runtime |
| OTP | 28+ | BEAM VM |
| PostgreSQL | 17+ | Database |
| TimescaleDB | 2.x | Time-series extension |
| .NET SDK | 10.0 | F# runtime |
| Zenoh | 1.0.0 | Message bus |

### 3.3 Container Architecture

```yaml
# 12-Container HA Mesh Topology
containers:
  tier_1_infrastructure:
    - indrajaal-db-ha:       172.31.0.20:5433   # PostgreSQL
    - indrajaal-obs-ha:      172.31.0.30:4317   # Observability

  tier_2_messaging:
    - zenoh-ha-1:            172.31.0.40:7447   # Router 1
    - zenoh-ha-2:            172.31.0.41:7447   # Router 2
    - zenoh-ha-3:            172.31.0.42:7447   # Router 3
    - zenoh-ha-proxy:        172.31.0.43        # Proxy

  tier_3_cognitive:
    - cepaf-bridge-ha:       172.31.0.50:9876   # F# Bridge
    - indrajaal-cortex-ha:   172.31.0.51:9877   # AI Cortex

  tier_4_application:
    - indrajaal-ex-app-1:    172.31.0.10:4000   # Phoenix 1
    - indrajaal-ex-app-2:    172.31.0.11:4000   # Phoenix 2
    - indrajaal-ex-app-3:    172.31.0.12:4000   # Phoenix 3

  tier_5_load_balancer:
    - indrajaal-haproxy:     172.31.0.5:4000    # HAProxy
```

### 3.4 Network Configuration

| Network | Subnet | Purpose |
|---------|--------|---------|
| indrajaal-ha-mesh | 172.31.0.0/16 | Internal container network |
| Host Bridge | localhost | External access |

### 3.5 Volume Configuration

| Volume | Mount Point | Purpose | Shared |
|--------|-------------|---------|--------|
| ha_db_data | /var/lib/postgresql/pgdata | PostgreSQL data | No |
| ha_obs_data | /data | Observability data | No |
| ha_app1_data | /app/data | App-1 holon state | No |
| ha_app2_data | /app/data | App-2 holon state | No |
| ha_app3_data | /app/data | App-3 holon state | No |
| ha_build_cache | /workspace/_build | Compiled artifacts | Yes |
| ha_deps_cache | /workspace/deps | Dependencies | Yes |

---

## 4. Test Phases

### 4.1 Phase Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    TEST PHASE TIMELINE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Phase 1        Phase 2          Phase 3         Phase 4      Phase 5  │
│  UNIT           INTEGRATION      SYSTEM          ACCEPTANCE   RELEASE  │
│  ────────       ───────────      ──────          ──────────   ───────  │
│                                                                         │
│  Property       Container        E2E             UAT          Sign-off │
│  Static         API              Chaos           Performance  Deploy   │
│  TDG            Cluster          Failover        Security              │
│                                                                         │
│  ◄─── 3 days ──►◄─── 5 days ───►◄─── 5 days ──►◄─── 3 days ►◄─ 1 day ►│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Phase 1: Unit & Property Testing

**Duration**: 3 days
**Automation**: 100%
**Parallelization**: Full

| Activity | Tests | Tool | Criteria |
|----------|-------|------|----------|
| Unit tests | 300+ | ExUnit | 100% pass |
| Property tests | 200+ | PropCheck | 100% pass |
| Static analysis | N/A | Credo, Dialyzer | 0 issues |
| Code coverage | N/A | ExCoveralls | ≥95% |
| TDG validation | 50+ | Custom | All generated |

**Test Categories**:

```elixir
# L0: Runtime
test/sil6/l0_runtime_test.exs
  - Scheduler configuration
  - Memory bounds
  - GC behavior

# L1: Function
test/sil6/l1_function_test.exs
  - I/O contracts
  - Type safety
  - Guard clauses

# L2: Component
test/sil6/l2_component_test.exs
  - API boundaries
  - Module cohesion
  - Domain contexts

# L3: Holon
test/sil6/l3_holon_test.exs
  - GenServer state
  - Supervisor trees
  - State machines
```

### 4.3 Phase 2: Integration Testing

**Duration**: 5 days
**Automation**: 95%
**Environment**: CI/CD + Local HA

| Activity | Tests | Tool | Criteria |
|----------|-------|------|----------|
| Container integration | 50+ | ExUnit | 100% pass |
| API integration | 30+ | ExUnit + HTTP | 100% pass |
| Database integration | 20+ | Ecto sandbox | 100% pass |
| Cluster integration | 15+ | Distributed Erlang | 100% pass |
| Zenoh integration | 15+ | NIF tests | 100% pass |

**Test Categories**:

```elixir
# L4: Container
test/sil6/l4_container_test.exs
  - Port mapping
  - Volume mounts
  - Network isolation

# L5: Node
test/sil6/l5_node_test.exs
  - Health checks
  - Dependency ordering
  - Resource limits

# L6: Cluster
test/sil6/l6_cluster_test.exs
  - Erlang distribution
  - Zenoh quorum
  - HAProxy routing
```

### 4.4 Phase 3: System Testing

**Duration**: 5 days
**Automation**: 90%
**Environment**: Full HA Mesh (12 containers)

| Activity | Tests | Tool | Criteria |
|----------|-------|------|----------|
| E2E scenarios | 50+ | Puppeteer | 100% pass |
| Failover testing | 20+ | Custom | Recovery < 60s |
| Chaos testing | 30+ | Litmus/Custom | N-1 survival |
| Load testing | 10+ | k6 | SLA met |
| Quorum testing | 15+ | Custom | 2oo3 maintained |

**Test Categories**:

```gherkin
# BDD Features
test/features/ha_mesh/ha_load_balancing.feature    # 7 scenarios
test/features/ha_mesh/zenoh_quorum.feature         # 6 scenarios
test/features/ha_mesh/holon_isolation.feature      # 5 scenarios
test/features/ha_mesh/e2e_scenarios.feature        # 29 scenarios
```

### 4.5 Phase 4: Acceptance Testing

**Duration**: 3 days
**Automation**: 80%
**Environment**: Staging

| Activity | Tests | Tool | Criteria |
|----------|-------|------|----------|
| UAT scenarios | 20+ | Manual + Auto | All accepted |
| Performance validation | 10+ | k6 | p99 < 200ms |
| Security scan | N/A | Sobelow | 0 critical |
| Compliance check | N/A | Checklist | All passed |

### 4.6 Phase 5: Release Testing

**Duration**: 1 day
**Automation**: 50%
**Environment**: Production-equivalent

| Activity | Tests | Tool | Criteria |
|----------|-------|------|----------|
| Smoke tests | 10 | Automated | 100% pass |
| Rollback validation | 5 | Manual | Successful |
| Monitoring validation | N/A | Grafana | Dashboards working |
| Sign-off | N/A | Manual | Approved |

---

## 5. Test Case Specifications

### 5.1 Test Case Template

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TEST CASE: TC-HA-XXX                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Title:        [Descriptive title]                                       │
│ Priority:     P0/P1/P2/P3                                               │
│ Type:         Unit/Integration/E2E/Chaos/Performance                    │
│ Automation:   Automated/Manual/Hybrid                                   │
│ STAMP:        [SC-XXX-XXX references]                                   │
│ FMEA:         [FM-XXX references]                                       │
│ Requirements: [REQ-XXX references]                                      │
├─────────────────────────────────────────────────────────────────────────┤
│ Preconditions:                                                          │
│   - [Condition 1]                                                       │
│   - [Condition 2]                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│ Test Steps:                                                             │
│   1. [Action 1]                                                         │
│   2. [Action 2]                                                         │
│   3. [Verification]                                                     │
├─────────────────────────────────────────────────────────────────────────┤
│ Expected Results:                                                       │
│   - [Expected outcome 1]                                                │
│   - [Expected outcome 2]                                                │
├─────────────────────────────────────────────────────────────────────────┤
│ Pass Criteria:     [Specific criteria]                                  │
│ Fail Criteria:     [Failure conditions]                                 │
│ Cleanup:           [Post-test cleanup]                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Critical Test Cases

#### TC-HA-001: HAProxy Load Distribution

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TEST CASE: TC-HA-001                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Title:        HAProxy distributes load evenly across 3 app nodes        │
│ Priority:     P0                                                        │
│ Type:         Integration                                               │
│ Automation:   Automated                                                 │
│ STAMP:        SC-HA-001                                                 │
│ FMEA:         FM-002 (Misrouting)                                       │
├─────────────────────────────────────────────────────────────────────────┤
│ Preconditions:                                                          │
│   - HA mesh running with 12 healthy containers                          │
│   - HAProxy configured for round-robin                                  │
│   - All 3 app nodes passing health checks                               │
├─────────────────────────────────────────────────────────────────────────┤
│ Test Steps:                                                             │
│   1. Send 1000 HTTP requests to HAProxy (localhost:4000/api/health)     │
│   2. Track which backend handles each request                           │
│   3. Calculate distribution across app-1, app-2, app-3                  │
│   4. Verify variance is within tolerance                                │
├─────────────────────────────────────────────────────────────────────────┤
│ Expected Results:                                                       │
│   - app-1 receives 333 ± 33 requests (10% tolerance)                    │
│   - app-2 receives 333 ± 33 requests                                    │
│   - app-3 receives 334 ± 33 requests                                    │
│   - No requests fail                                                    │
│   - p99 latency < 100ms                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│ Pass Criteria:     Distribution variance < 10%                          │
│ Fail Criteria:     Any backend receives <25% or >40% of requests        │
│ Cleanup:           None required                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

#### TC-HA-002: Node Failover

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TEST CASE: TC-HA-002                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Title:        Service continues after single node failure               │
│ Priority:     P0                                                        │
│ Type:         Chaos                                                     │
│ Automation:   Automated                                                 │
│ STAMP:        SC-HA-002, SC-HA-009                                      │
│ FMEA:         FM-003, FM-004, FM-005 (App crash)                        │
├─────────────────────────────────────────────────────────────────────────┤
│ Preconditions:                                                          │
│   - HA mesh running with all containers healthy                         │
│   - Traffic flowing through HAProxy                                     │
│   - Monitoring enabled                                                  │
├─────────────────────────────────────────────────────────────────────────┤
│ Test Steps:                                                             │
│   1. Start continuous load (100 req/s)                                  │
│   2. Stop app-2 container: podman stop indrajaal-ex-app-2               │
│   3. Wait for HAProxy health check to fail (max 30s)                    │
│   4. Verify traffic redistributes to app-1 and app-3                    │
│   5. Count failed requests during failover                              │
│   6. Start app-2 container                                              │
│   7. Verify app-2 rejoins cluster                                       │
├─────────────────────────────────────────────────────────────────────────┤
│ Expected Results:                                                       │
│   - HAProxy removes app-2 within 30s                                    │
│   - Failed requests during failover < 5                                 │
│   - Traffic redistributes 50/50 to remaining nodes                      │
│   - App-2 recovers and rejoins within 5 minutes                         │
│   - Alert generated for node failure                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Pass Criteria:     < 5 failed requests, recovery < 5 minutes            │
│ Fail Criteria:     > 10 failed requests OR no recovery                  │
│ Cleanup:           Restart app-2 if not recovered                       │
└─────────────────────────────────────────────────────────────────────────┘
```

#### TC-HA-003: Zenoh Quorum

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TEST CASE: TC-HA-003                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Title:        Zenoh maintains 2oo3 quorum after single router failure   │
│ Priority:     P0                                                        │
│ Type:         Chaos                                                     │
│ Automation:   Automated                                                 │
│ STAMP:        SC-HA-003                                                 │
│ FMEA:         FM-010, FM-011 (Zenoh failure)                            │
├─────────────────────────────────────────────────────────────────────────┤
│ Preconditions:                                                          │
│   - All 3 Zenoh routers healthy                                         │
│   - Zenoh proxy connected                                               │
│   - Message flow active                                                 │
├─────────────────────────────────────────────────────────────────────────┤
│ Test Steps:                                                             │
│   1. Start message producer (10 msg/s to indrajaal/test/*)              │
│   2. Start message consumer subscribing to same topic                   │
│   3. Stop zenoh-ha-1: podman stop zenoh-ha-1                            │
│   4. Verify messages continue flowing                                   │
│   5. Check quorum status shows "degraded" but "functional"              │
│   6. Restart zenoh-ha-1                                                 │
│   7. Verify quorum returns to "healthy"                                 │
├─────────────────────────────────────────────────────────────────────────┤
│ Expected Results:                                                       │
│   - No messages lost during router failure                              │
│   - Quorum maintained with 2 routers                                    │
│   - Message latency increases < 50ms                                    │
│   - Router rejoins mesh after restart                                   │
├─────────────────────────────────────────────────────────────────────────┤
│ Pass Criteria:     0 messages lost, quorum maintained                   │
│ Fail Criteria:     Message loss > 0 OR quorum lost                      │
│ Cleanup:           Restart zenoh-ha-1 if needed                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### TC-HA-004: DuckDB Lock Isolation

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TEST CASE: TC-HA-004                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Title:        Per-node holon isolation prevents DuckDB lock contention  │
│ Priority:     P0                                                        │
│ Type:         Integration                                               │
│ Automation:   Automated                                                 │
│ STAMP:        SC-HA-005, SC-HOLON-008                                   │
│ FMEA:         FM-012 (DuckDB lock contention)                           │
├─────────────────────────────────────────────────────────────────────────┤
│ Preconditions:                                                          │
│   - HOLON_DATA_PATH set to /app/data/holons for each app                │
│   - Each app has separate volume (ha_app1_data, ha_app2_data, etc.)     │
│   - All apps healthy                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Test Steps:                                                             │
│   1. Trigger state write on app-1 via API                               │
│   2. Simultaneously trigger state write on app-2                        │
│   3. Simultaneously trigger state write on app-3                        │
│   4. Verify all writes succeed                                          │
│   5. Check DuckDB files exist in separate paths                         │
│   6. Verify no lock timeout errors in logs                              │
├─────────────────────────────────────────────────────────────────────────┤
│ Expected Results:                                                       │
│   - All 3 writes complete within 100ms                                  │
│   - No "Conflicting lock" errors                                        │
│   - Each app has its own prajna_register.duckdb                         │
│   - State is isolated per node                                          │
├─────────────────────────────────────────────────────────────────────────┤
│ Pass Criteria:     0 lock errors, all writes succeed                    │
│ Fail Criteria:     Any lock contention error                            │
│ Cleanup:           None required                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

#### TC-HA-005: Build Cache Ordering

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TEST CASE: TC-HA-005                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ Title:        App-2 and App-3 wait for App-1 to compile                 │
│ Priority:     P0                                                        │
│ Type:         Integration                                               │
│ Automation:   Automated                                                 │
│ STAMP:        SC-HA-007                                                 │
│ FMEA:         FM-013 (Build cache race)                                 │
├─────────────────────────────────────────────────────────────────────────┤
│ Preconditions:                                                          │
│   - Build cache cleared (fresh start)                                   │
│   - podman-compose-ha-full-mesh.yml has service_healthy dependency      │
│   - Mesh is stopped                                                     │
├─────────────────────────────────────────────────────────────────────────┤
│ Test Steps:                                                             │
│   1. Clear build cache: podman volume rm ha_build_cache                 │
│   2. Start HA mesh: podman-compose up -d                                │
│   3. Monitor startup sequence                                           │
│   4. Verify app-1 compiles first                                        │
│   5. Verify app-2 starts ONLY after app-1 healthy                       │
│   6. Verify app-3 starts ONLY after app-1 healthy                       │
│   7. Check no UndefinedFunctionError in logs                            │
├─────────────────────────────────────────────────────────────────────────┤
│ Expected Results:                                                       │
│   - app-1 compiles for ~15 minutes                                      │
│   - app-1 health check passes                                           │
│   - app-2, app-3 start only after app-1 healthy                         │
│   - app-2, app-3 skip compilation (cache hit)                           │
│   - No module undefined errors                                          │
├─────────────────────────────────────────────────────────────────────────┤
│ Pass Criteria:     Correct startup order, no undefined errors           │
│ Fail Criteria:     app-2/3 start before app-1 healthy                   │
│ Cleanup:           None (mesh running is success state)                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Complete Test Case Inventory

| ID | Title | Priority | Type | STAMP | Status |
|----|-------|----------|------|-------|--------|
| TC-HA-001 | Load Distribution | P0 | Integration | SC-HA-001 | Ready |
| TC-HA-002 | Node Failover | P0 | Chaos | SC-HA-002 | Ready |
| TC-HA-003 | Zenoh Quorum | P0 | Chaos | SC-HA-003 | Ready |
| TC-HA-004 | DuckDB Lock Isolation | P0 | Integration | SC-HA-005 | Ready |
| TC-HA-005 | Build Cache Ordering | P0 | Integration | SC-HA-007 | Ready |
| TC-HA-006 | Database Consistency | P0 | Integration | SC-HA-004 | Ready |
| TC-HA-007 | Erlang Cluster Formation | P0 | Integration | SC-HA-006 | Ready |
| TC-HA-008 | Observability Pipeline | P1 | Integration | SC-HA-008 | Ready |
| TC-HA-009 | Emergency Stop | P0 | System | SC-HA-009 | Ready |
| TC-HA-010 | State Recovery | P0 | System | SC-HA-010 | Ready |
| TC-HA-011 | Split Brain Prevention | P0 | Chaos | SC-HA-011 | Ready |
| TC-HA-012 | Health Check Accuracy | P1 | Integration | SC-HA-012 | Ready |
| TC-HA-013 | CEPAF Bridge Integration | P1 | Integration | - | Ready |
| TC-HA-014 | Cortex AI Operations | P2 | Integration | - | Ready |
| TC-HA-015 | Prajna Cockpit E2E | P1 | E2E | SC-PRAJNA-* | Ready |
| TC-HA-016 | Two-Node Degradation | P1 | Chaos | - | Ready |
| TC-HA-017 | Full Cluster Restart | P1 | System | - | Ready |
| TC-HA-018 | Rolling Update | P2 | System | - | Ready |
| TC-HA-019 | Checkpoint/Restore | P1 | System | SC-UCR-* | Ready |
| TC-HA-020 | Sustained Load | P1 | Performance | - | Ready |

---

## 6. Traceability Matrix

### 6.1 Requirements to Test Cases

| Requirement | Description | Test Cases | Coverage |
|-------------|-------------|------------|----------|
| REQ-HA-001 | 3-node HA cluster | TC-HA-001, TC-HA-002, TC-HA-016 | 100% |
| REQ-HA-002 | N-1 fault tolerance | TC-HA-002, TC-HA-003 | 100% |
| REQ-HA-003 | < 60s failover | TC-HA-002, TC-HA-009 | 100% |
| REQ-HA-004 | 2oo3 Zenoh quorum | TC-HA-003 | 100% |
| REQ-HA-005 | Per-node state isolation | TC-HA-004 | 100% |
| REQ-HA-006 | Shared build cache | TC-HA-005 | 100% |
| REQ-HA-007 | Database consistency | TC-HA-006 | 100% |
| REQ-HA-008 | Full observability | TC-HA-008 | 100% |
| REQ-HA-009 | p99 < 200ms | TC-HA-001, TC-HA-020 | 100% |
| REQ-HA-010 | SIL-6 compliance | All TC-HA-* | 100% |

### 6.2 STAMP Constraints to Test Cases

| STAMP ID | Constraint | Test Cases | Verification |
|----------|------------|------------|--------------|
| SC-HA-001 | Load balancer distribution | TC-HA-001 | Automated |
| SC-HA-002 | Failed node removal < 30s | TC-HA-002 | Automated |
| SC-HA-003 | Zenoh 2oo3 quorum | TC-HA-003 | Automated |
| SC-HA-004 | Database write atomicity | TC-HA-006 | Automated |
| SC-HA-005 | DuckDB lock isolation | TC-HA-004 | Automated |
| SC-HA-006 | Erlang cookie consistency | TC-HA-007 | Automated |
| SC-HA-007 | Build cache ordering | TC-HA-005 | Automated |
| SC-HA-008 | Observability aggregation | TC-HA-008 | Automated |
| SC-HA-009 | Failover < 5s | TC-HA-009 | Automated |
| SC-HA-010 | Holon SQLite/DuckDB recovery | TC-HA-010 | Automated |
| SC-HA-011 | Split brain prevention | TC-HA-011 | Automated |
| SC-HA-012 | Health checks every 30s | TC-HA-012 | Automated |

### 6.3 FMEA to Test Cases

| FMEA ID | Failure Mode | RPN | Test Cases | Mitigation Verified |
|---------|--------------|-----|------------|---------------------|
| FM-001 | HAProxy failure | 20 | TC-HA-001 | Yes |
| FM-002 | HAProxy misrouting | 36 | TC-HA-001 | Yes |
| FM-003 | App-1 crash | 30 | TC-HA-002 | Yes |
| FM-004 | App-2 crash | 30 | TC-HA-002 | Yes |
| FM-005 | App-3 crash | 30 | TC-HA-002 | Yes |
| FM-006 | 2 apps crash | 32 | TC-HA-016 | Yes |
| FM-007 | All apps crash | 10 | TC-HA-017 | Yes |
| FM-008 | PostgreSQL crash | 20 | TC-HA-006 | Yes |
| FM-009 | PostgreSQL corruption | 40 | TC-HA-019 | Yes |
| FM-010 | Zenoh-1 crash | 18 | TC-HA-003 | Yes |
| FM-011 | Zenoh-1,2 crash | 18 | TC-HA-003 | Yes |
| FM-012 | DuckDB lock | 12* | TC-HA-004 | Yes |
| FM-013 | Build cache race | 24* | TC-HA-005 | Yes |
| FM-014 | Network partition | 54 | TC-HA-011 | Yes |

*Mitigated RPN (original: FM-012=84, FM-013=120)

---

## 7. Risk-Based Test Prioritization

### 7.1 Risk Assessment Matrix

```
              IMPACT
              Low    Med    High   Critical
         ┌────────┬────────┬────────┬────────┐
    High │   P2   │   P1   │   P0   │   P0   │
         ├────────┼────────┼────────┼────────┤
L   Med  │   P3   │   P2   │   P1   │   P0   │
I        ├────────┼────────┼────────┼────────┤
K   Low  │   P3   │   P3   │   P2   │   P1   │
E        ├────────┼────────┼────────┼────────┤
L   Rare │   P3   │   P3   │   P3   │   P2   │
Y        └────────┴────────┴────────┴────────┘
```

### 7.2 Priority Distribution

| Priority | Count | % of Total | Execution Order |
|----------|-------|------------|-----------------|
| P0 (Critical) | 11 | 55% | First - No skip |
| P1 (High) | 6 | 30% | Second - Minimal skip |
| P2 (Medium) | 2 | 10% | Third - Can defer |
| P3 (Low) | 1 | 5% | Last - Optional |

### 7.3 P0 Test Execution Order

| Order | Test Case | Rationale |
|-------|-----------|-----------|
| 1 | TC-HA-005 | Build cache ordering - blocks all else |
| 2 | TC-HA-007 | Erlang cluster - required for distribution |
| 3 | TC-HA-004 | DuckDB isolation - prevents locks |
| 4 | TC-HA-003 | Zenoh quorum - message bus foundation |
| 5 | TC-HA-006 | Database consistency - data integrity |
| 6 | TC-HA-001 | Load distribution - validates routing |
| 7 | TC-HA-002 | Node failover - N-1 tolerance |
| 8 | TC-HA-009 | Emergency stop - safety critical |
| 9 | TC-HA-010 | State recovery - data recovery |
| 10 | TC-HA-011 | Split brain - consistency |
| 11 | TC-HA-017 | Full restart - disaster recovery |

---

## 8. Entry and Exit Criteria

### 8.1 Phase Entry Criteria

| Phase | Entry Criteria |
|-------|----------------|
| **Phase 1: Unit** | - Code compiles with 0 errors/warnings |
|  | - All dependencies installed |
|  | - Test framework configured |
| **Phase 2: Integration** | - Phase 1 exit criteria met |
|  | - CI/CD pipeline operational |
|  | - Container images built |
| **Phase 3: System** | - Phase 2 exit criteria met |
|  | - Full HA mesh deployable |
|  | - Monitoring configured |
| **Phase 4: Acceptance** | - Phase 3 exit criteria met |
|  | - All P0 tests passing |
|  | - Performance baselines established |
| **Phase 5: Release** | - Phase 4 exit criteria met |
|  | - UAT signed off |
|  | - Rollback plan documented |

### 8.2 Phase Exit Criteria

| Phase | Exit Criteria |
|-------|---------------|
| **Phase 1: Unit** | - 100% unit tests pass |
|  | - 100% property tests pass |
|  | - Code coverage ≥ 95% |
|  | - Static analysis: 0 issues |
| **Phase 2: Integration** | - 100% integration tests pass |
|  | - All containers start correctly |
|  | - API contracts validated |
|  | - Database connectivity verified |
| **Phase 3: System** | - 100% P0 tests pass |
|  | - ≥ 95% P1 tests pass |
|  | - Failover time < 60s |
|  | - No data loss during chaos |
| **Phase 4: Acceptance** | - UAT scenarios accepted |
|  | - p99 latency < 200ms |
|  | - Security scan: 0 critical |
|  | - Documentation complete |
| **Phase 5: Release** | - Smoke tests pass in staging |
|  | - Rollback validated |
|  | - Sign-off obtained |
|  | - Release notes published |

### 8.3 Test Suspension Criteria

| Condition | Action |
|-----------|--------|
| > 10% P0 tests failing | Suspend testing, investigate |
| Infrastructure failure | Pause until resolved |
| Critical defect found | Block on fix |
| Data loss detected | Emergency stop |

### 8.4 Test Resumption Criteria

| Condition | Action |
|-----------|--------|
| Root cause identified | Resume with fix |
| Infrastructure restored | Continue from checkpoint |
| Critical defect fixed | Re-run affected tests |
| Data integrity confirmed | Full regression |

---

## 9. Test Data Requirements

### 9.1 Test Data Categories

| Category | Description | Source | Volume |
|----------|-------------|--------|--------|
| Seed Data | Initial database state | Fixtures | 1000 records |
| Load Data | Performance testing | Generated | 100K records |
| Edge Cases | Boundary conditions | Manual | 500 cases |
| Failure Data | Chaos injection | Generated | 100 scenarios |

### 9.2 Test Data Management

```elixir
# Factory pattern for test data
defmodule Indrajaal.TestFactory do
  use ExMachina.Ecto, repo: Indrajaal.Repo

  def site_factory do
    %Indrajaal.Sites.Site{
      name: sequence(:site_name, &"Test Site #{&1}"),
      address: Faker.Address.street_address(),
      status: :active
    }
  end

  def alarm_factory do
    %Indrajaal.Alarms.Alarm{
      site: build(:site),
      severity: Enum.random([:low, :medium, :high, :critical]),
      message: Faker.Lorem.sentence(),
      timestamp: DateTime.utc_now()
    }
  end
end
```

### 9.3 Data Isolation

| Environment | Data Source | Isolation |
|-------------|-------------|-----------|
| Unit Tests | In-memory | Per-test |
| Integration | Ecto Sandbox | Per-test |
| System | Dedicated DB | Per-run |
| Performance | Separate instance | Persistent |

---

## 10. Test Execution Schedule

### 10.1 Daily Schedule (CI/CD)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DAILY CI/CD PIPELINE                                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  00:00 ─────► 02:00 ─────► 04:00 ─────► 06:00 ─────► 08:00            │
│                                                                         │
│  Nightly      Full         Report      Ready for    Dev team           │
│  Build        Regression   Generation  Review       starts             │
│                                                                         │
│  ┌─────┐     ┌─────────┐  ┌─────────┐  ┌─────────┐                     │
│  │Build│────►│Unit+Prop│──►│Integrate│──►│E2E+Load│                    │
│  └─────┘     └─────────┘  └─────────┘  └─────────┘                     │
│                                                                         │
│  Triggers:                                                              │
│  - Every push to main                                                   │
│  - Every PR                                                             │
│  - Nightly at 00:00 UTC                                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Sprint Schedule

| Day | Activity | Tests Run |
|-----|----------|-----------|
| Mon | Sprint planning | Smoke |
| Tue | Development | Unit, Property |
| Wed | Development | Unit, Property, Integration |
| Thu | Integration | Integration, API |
| Fri | System testing | E2E, Chaos |
| Sat | Automated overnight | Full regression |
| Sun | Automated overnight | Load, Performance |

### 10.3 Release Schedule

| Day | Activity | Sign-off |
|-----|----------|----------|
| T-5 | Code freeze | Dev Lead |
| T-4 | Full regression | QA Lead |
| T-3 | Performance testing | Architect |
| T-2 | UAT | Product Owner |
| T-1 | Staging deployment | Ops Lead |
| T-0 | Production release | Release Manager |

---

## 11. Defect Management

### 11.1 Defect Severity

| Severity | Definition | SLA |
|----------|------------|-----|
| S1 - Critical | Service down, data loss | 4 hours |
| S2 - Major | Feature broken, workaround exists | 24 hours |
| S3 - Minor | Cosmetic, minor impact | 1 week |
| S4 - Trivial | Enhancement, nice-to-have | Backlog |

### 11.2 Defect Workflow

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│   New   │────►│  Triage │────►│Assigned │────►│  Fixed  │────►│ Verified│
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
                    │                │               │               │
                    │                │               │               │
                    ▼                ▼               ▼               ▼
               ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
               │Duplicate│     │ Blocked │     │Re-opened│     │ Closed  │
               └─────────┘     └─────────┘     └─────────┘     └─────────┘
```

### 11.3 Defect Classification

| Category | Examples |
|----------|----------|
| Functional | Wrong output, missing feature |
| Performance | Slow response, timeout |
| Security | Vulnerability, auth bypass |
| Usability | Confusing UI, poor UX |
| Reliability | Crash, hang, data loss |
| Compatibility | Browser, OS, version issues |

---

## 12. Test Deliverables

### 12.1 Documents

| Deliverable | Description | Owner | Due |
|-------------|-------------|-------|-----|
| Test Plan | This document | QA Lead | T-10 |
| Test Cases | Detailed specifications | QA Team | T-7 |
| Test Data | Fixtures and generators | QA Team | T-5 |
| Test Report | Execution results | QA Lead | T-1 |
| Defect Report | Open issues summary | QA Lead | T-1 |
| Coverage Report | Code coverage metrics | Automation | Daily |

### 12.2 Automation Artifacts

| Artifact | Location | Format |
|----------|----------|--------|
| Unit Tests | test/sil6/*.exs | ExUnit |
| Property Tests | test/sil6/*.exs | PropCheck |
| BDD Features | test/features/ha_mesh/*.feature | Gherkin |
| Integration Tests | test/sil6/*_integration_test.exs | ExUnit |
| Load Scripts | scripts/testing/load/*.exs | Elixir |
| Chaos Scripts | scripts/testing/chaos/*.exs | Elixir |

### 12.3 Reports

| Report | Frequency | Audience |
|--------|-----------|----------|
| Daily Test Summary | Daily | Dev Team |
| Sprint Test Report | Weekly | All stakeholders |
| Coverage Trend | Weekly | QA, Dev Leads |
| Defect Aging | Weekly | Management |
| Release Readiness | Per release | Release Manager |

---

## 13. Appendices

### Appendix A: Test Commands

```bash
# Unit and Property Tests
MIX_ENV=test mix test test/sil6/ha_mesh_fractal_test.exs

# Integration Tests (requires HA mesh)
MIX_ENV=test mix test test/sil6/ha_mesh_integration_test.exs --include integration

# All SIL-6 Tests
MIX_ENV=test mix test test/sil6/

# With coverage
MIX_ENV=test mix test test/sil6/ --cover

# Specific tags
MIX_ENV=test mix test --only sil6 --only swarm

# Exclude destructive
MIX_ENV=test mix test --exclude destructive
```

### Appendix B: HA Mesh Commands

```bash
# Start HA mesh
podman-compose -f lib/cepaf/artifacts/podman-compose-ha-full-mesh.yml up -d

# Check status
podman ps --format "{{.Names}}\t{{.Status}}"

# View logs
podman logs -f indrajaal-ex-app-1

# Stop mesh
podman-compose -f lib/cepaf/artifacts/podman-compose-ha-full-mesh.yml down

# Clean volumes
podman volume prune -f
```

### Appendix C: Monitoring Endpoints

| Service | URL | Credentials |
|---------|-----|-------------|
| HAProxy Stats | http://localhost:8404/stats | - |
| Grafana | http://localhost:3000 | admin/indrajaal |
| Prometheus | http://localhost:9090 | - |
| Prajna Cockpit | http://localhost:4000/prajna | - |

### Appendix D: Test Environment Variables

```bash
# Required for SIL-6 tests
export SKIP_ZENOH_NIF=0
export PATIENT_MODE=enabled
export NO_TIMEOUT=true
export SIL_LEVEL=6
export HA_MODE=true

# Database
export DATABASE_URL=ecto://postgres:postgres@localhost:5433/indrajaal_test
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5433
```

### Appendix E: Approval Sign-off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| QA Lead | | | |
| Dev Lead | | | |
| Architect | | | |
| Safety Engineer | | | |
| Release Manager | | | |

---

**END OF TEST PLAN**

*Document generated by Claude Opus 4.5 for Indrajaal SIL-6 HA Mesh*
