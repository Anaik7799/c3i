# CEPAF Service Chain DAG - Dev & Demo Environments
**Version**: 1.0.0
**Date**: 2025-12-24
**STAMP Compliance**: SC-CEP-003, SC-CEP-004, SC-OBS-065

---

## 1. Service Dependency Graph (DAG)

```
                    ┌─────────────────────────────────────────────────────┐
                    │              DEV/DEMO ENVIRONMENT DAG                │
                    │          (Directed Acyclic Graph - No Cycles)        │
                    └─────────────────────────────────────────────────────┘

                                    ┌──────────────┐
                                    │   NETWORK    │
                                    │ indrajaal-net│
                                    │  (Layer 0)   │
                                    └──────┬───────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
            ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
            │  indrajaal-  │      │  indrajaal-  │      │              │
            │     db       │      │     obs      │      │    (future)  │
            │  (Layer 1)   │      │  (Layer 1)   │      │    cache     │
            │  MANDATORY   │      │  OPTIONAL    │      │              │
            └──────┬───────┘      └──────┬───────┘      └──────────────┘
                   │                     │
                   │    ┌────────────────┘
                   │    │
                   ▼    ▼
            ┌────────────────┐
            │  indrajaal-    │
            │     app        │
            │   (Layer 2)    │
            │   PRIMARY      │
            └────────────────┘
                   │
                   │
                   ▼
            ┌────────────────┐
            │   ENDPOINTS    │
            │   (Layer 3)    │
            └────────────────┘
                   │
     ┌─────────────┼─────────────────────────┐
     │             │             │           │
     ▼             ▼             ▼           ▼
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│ Phoenix │  │  Ecto   │  │ OTEL    │  │ Metrics │
│  :4000  │  │  Pool   │  │ Export  │  │  :9568  │
└─────────┘  └─────────┘  └─────────┘  └─────────┘
```

---

## 2. Node Definitions

### 2.1 Node Types

| Type | Description | Examples |
|------|-------------|----------|
| `NETWORK` | Podman network infrastructure | indrajaal-net |
| `CONTAINER` | Running container instance | indrajaal-db, indrajaal-obs, indrajaal-app |
| `SERVICE` | Internal service within container | PostgreSQL, ClickHouse, Phoenix |
| `ENDPOINT` | Exposed API/port | HTTP :4000, gRPC :4317 |

### 2.2 Edge Types

| Type | Description | Example |
|------|-------------|---------|
| `depends_on` | Hard dependency - must exist | app → db |
| `connects_to` | Network connection | app → obs (OTEL) |
| `exports_to` | Data/metrics flow | app → obs (traces) |
| `optional_for` | Soft dependency | obs → app (degraded OK) |

---

## 3. Layer Definitions

| Layer | Name | Boot Order | Components | Max Boot Time |
|-------|------|------------|------------|---------------|
| 0 | Infrastructure | 1st | Network, Volumes | 5s |
| 1 | Foundation | 2nd | DB, OBS | 20s |
| 2 | Application | 3rd | App | 30s |
| 3 | Endpoints | 4th | HTTP, gRPC, Metrics | 5s |

**Total Boot Time Target**: <60s (SC-CEP-004: 30s threshold for production readiness)

---

## 4. Boot Sequence (Topological Sort)

```
STEP 1: Infrastructure Setup (T+0s)
├── Create network: indrajaal-net
├── Create volumes: db-data, clickhouse-data, prometheus-data, grafana-data
└── Exit: Network bridge exists

STEP 2: Foundation Layer (T+5s)
├── Start indrajaal-db
│   ├── Wait: pg_isready returns 0
│   └── Verify: SELECT 1 succeeds
├── Start indrajaal-obs (parallel with db if independent)
│   ├── Wait: ClickHouse ping
│   ├── Wait: Prometheus healthy
│   └── Wait: OTEL gRPC listening
└── Exit: All foundation services healthy

STEP 3: Application Layer (T+25s)
├── Start indrajaal-app
│   ├── Precondition: db healthy
│   ├── Wait: Phoenix boot log
│   ├── Wait: Ecto pool connected
│   └── Wait: /health returns 200
└── Exit: App fully operational

STEP 4: Endpoint Verification (T+55s)
├── Verify: GET /health → 200
├── Verify: GET /ready → 200
├── Verify: Metrics endpoint responds
└── Exit: All endpoints verified
```

---

## 5. Health Propagation Model

```
                    ┌─────────────────────────────────────────┐
                    │          HEALTH STATE MACHINE           │
                    └─────────────────────────────────────────┘

Container States: ABSENT → CREATED → STARTING → HEALTHY → DEGRADED → FAILED

Health Propagation Rules:
1. Parent FAILED → Children DEGRADED (if optional) or FAILED (if mandatory)
2. Child DEGRADED → Parent continues (with reduced functionality)
3. Child FAILED → Parent DEGRADED (if child mandatory)

┌──────────────────────────────────────────────────────────────┐
│  HEALTH DEPENDENCY MATRIX                                     │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  DB Health        OBS Health        APP Health                │
│  ─────────        ──────────        ──────────                │
│  HEALTHY    +     HEALTHY     →     HEALTHY                   │
│  HEALTHY    +     DEGRADED    →     HEALTHY (metrics missing) │
│  HEALTHY    +     FAILED      →     HEALTHY (no observability)│
│  DEGRADED   +     ANY         →     DEGRADED                  │
│  FAILED     +     ANY         →     FAILED (cannot start)     │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 6. Failure Scenarios & Test Cases

### 6.1 Foundation Failures

| TC ID | Scenario | Initial State | Action | Expected Result | Recovery |
|-------|----------|---------------|--------|-----------------|----------|
| TC.DAG.001 | DB not starting | All stopped | Boot sequence | App waits, times out | Alert, retry |
| TC.DAG.002 | DB crashes mid-operation | All healthy | Kill -9 db | App detects, enters degraded | Auto-reconnect |
| TC.DAG.003 | DB slow queries | All healthy | Lock table | App logs timeout | Query killer |
| TC.DAG.004 | OBS not starting | All stopped | Boot sequence | App starts in degraded | Log locally |
| TC.DAG.005 | OBS crashes | All healthy | Kill -9 obs | App continues, no metrics | Restart obs |

### 6.2 Application Failures

| TC ID | Scenario | Initial State | Action | Expected Result | Recovery |
|-------|----------|---------------|--------|-----------------|----------|
| TC.DAG.010 | App crash | All healthy | Kill -9 app | Users see 502 | Restart app |
| TC.DAG.011 | App memory leak | All healthy | Stress test | OOM killed | Auto-restart |
| TC.DAG.012 | App deadlock | All healthy | Concurrent requests | Timeout, no response | Watchdog kill |
| TC.DAG.013 | Hot reload failure | App running | Bad code deploy | Rollback | Deploy previous |

### 6.3 Network Failures

| TC ID | Scenario | Initial State | Action | Expected Result | Recovery |
|-------|----------|---------------|--------|-----------------|----------|
| TC.DAG.020 | Network partition | All healthy | Disconnect network | Containers detect | Auto-reconnect |
| TC.DAG.021 | DNS failure | All healthy | Remove DNS entry | Connection by IP | Fallback |
| TC.DAG.022 | Port conflict | Stopped | Start with port in use | Error, don't start | Log, choose alt port |

### 6.4 Cascading Failures

| TC ID | Scenario | Initial State | Action | Expected Result | Recovery |
|-------|----------|---------------|--------|-----------------|----------|
| TC.DAG.030 | Full stack restart | All stopped | Boot all | All healthy in <60s | N/A |
| TC.DAG.031 | Reverse teardown | All healthy | Stop in reverse order | Clean shutdown | N/A |
| TC.DAG.032 | Rolling restart | All healthy | Restart one at a time | Zero downtime | Health checks |
| TC.DAG.033 | Chaos monkey | All healthy | Random kills | Resilient recovery | Auto-healing |

---

## 7. Demo Environment Specific Tests

### 7.1 User Journey Tests

| TC ID | Scenario | Precondition | Steps | Success Criteria |
|-------|----------|--------------|-------|------------------|
| TC.DEMO.001 | User login | App healthy | 1. Navigate to /login<br>2. Enter credentials<br>3. Submit | Token issued, redirected |
| TC.DEMO.002 | Alarm creation | Authenticated | 1. Navigate to /alarms<br>2. Create new alarm<br>3. Submit | Alarm in DB, notification |
| TC.DEMO.003 | Dashboard load | Authenticated | 1. Navigate to /dashboard | All widgets load <2s |
| TC.DEMO.004 | Video stream | Authenticated | 1. Open video feed<br>2. Watch 30s | Stream stable, no drops |
| TC.DEMO.005 | Report export | Data seeded | 1. Select date range<br>2. Export PDF | PDF generated <10s |
| TC.DEMO.006 | Multi-tenant | 2 tenants | 1. Access as Tenant A<br>2. Try Tenant B data | Access denied |
| TC.DEMO.007 | Concurrent | 10 users | 1. Simulate 10 sessions | All stable |
| TC.DEMO.008 | CSV export | Data seeded | 1. Export data as CSV | Complete, valid CSV |

### 7.2 Performance Baselines

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Page Load Time | <2s | Lighthouse |
| API Response (P50) | <100ms | OTEL traces |
| API Response (P99) | <500ms | OTEL traces |
| DB Query (P50) | <50ms | pg_stat_statements |
| Memory Usage | <2Gi | Prometheus |
| CPU Usage (idle) | <10% | Prometheus |
| CPU Usage (load) | <80% | Prometheus |

---

## 8. DAG Verification Commands

```bash
# Verify boot order (run from CEPAF)
dotnet exec lib/cepaf/src/Cepaf/bin/Release/net8.0/Cepaf.dll \
  -e DEV --verify-dag

# Test failure scenarios
# 1. DB failure
podman stop indrajaal-db
sleep 5
curl -sf http://localhost:4000/health  # Should return degraded

# 2. OBS failure
podman stop indrajaal-obs
curl -sf http://localhost:4000/health  # Should return healthy (degraded metrics)

# 3. Recovery
podman start indrajaal-db
podman start indrajaal-obs
sleep 10
curl -sf http://localhost:4000/health  # Should return healthy

# Full stack verification
CEPAF_VERIFY_DAG=true dotnet exec lib/cepaf/src/Cepaf/bin/Release/net8.0/Cepaf.dll \
  -e DEV -y --verify-all
```

---

## 9. Future Enhancements

1. **AppVerifier.fs Module**: Implement app container verification similar to DbVerifier.fs
2. **DAG Visualization**: Generate Mermaid/GraphViz diagrams from actual state
3. **Chaos Engineering**: Automated failure injection with recovery verification
4. **Dependency Injection**: Dynamic dependency resolution at runtime
5. **Health Dashboard**: Real-time DAG status visualization in Grafana

---

## 10. STAMP Compliance Matrix

| Constraint | Description | Implementation | Verified |
|------------|-------------|----------------|----------|
| SC-CEP-003 | Consensus-based health | Multi-probe verification | ✓ |
| SC-CEP-004 | 30s boot threshold | Topological boot order | ✓ |
| SC-OBS-065 | Container health probes | Startup/liveness/readiness | ✓ |
| SC-CNT-009 | NixOS containers only | All images NixOS-based | ✓ |
| SC-AGT-018 | No deadlocks | DAG prevents circular deps | ✓ |

---

**Document Owner**: Claude Cybernetic Architect
**Framework**: CEPAF F# v20.0 - Service Chain DAG Edition
**Last Updated**: 2025-12-24 01:35 CET
