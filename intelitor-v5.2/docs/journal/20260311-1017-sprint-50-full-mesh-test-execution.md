# Sprint 50: Full SIL-6 Mesh Boot & Test Execution

**Date**: 2026-03-11 10:17 CET
**Sprint**: 50 (Infrastructure & Test Validation)
**Author**: Claude Opus 4.6
**Mode**: Autonomous, Criticality-Based

---

## Level 1: Executive Summary

Sprint 50 targets full SIL-6 mesh boot with all 14 containers, end-to-end test execution, and resolution of any test failures. This is the first complete system validation since Sprint 49's safety infrastructure overhaul.

**Objective**: Boot full mesh → Run all tests → Fix failures → Verify quality gates → Commit.

---

## Level 2: Detailed Task Plan

### Wave DAG

```
Wave 0 (Infra P0) ──────> Wave 1 (DB Setup P0) ──> Wave 2 (Test Run P0)
   │                                                        │
   │ Clean old containers                          ┌────────┴────────┐
   │ Boot SIL-6 mesh (14 nodes)                    v                 v
   │ Verify health                          Wave 3 (Fix P1)   Wave 4 (Verify P2)
   │                                               │                 │
   │                                               └────────┬────────┘
   │                                                        v
   │                                                Wave 5 (Commit P2)
```

### Task Table

| ID | Task | P | Wave | Description |
|----|------|---|------|-------------|
| 50.0.1 | Clean stale containers | P0 | 0 | Remove all exited containers and stale volumes |
| 50.0.2 | Boot SIL-6 full mesh | P0 | 0 | Start all 14 containers via podman-compose |
| 50.0.3 | Verify mesh health | P0 | 0 | All containers healthy, ports listening |
| 50.1.1 | Database setup | P0 | 1 | Create + migrate test database |
| 50.1.2 | Verify DB connectivity | P0 | 1 | pg_isready + Ecto connection test |
| 50.2.1 | Run full test suite | P0 | 2 | SKIP_ZENOH_NIF=0 mix test |
| 50.2.2 | Capture test results | P0 | 2 | Record pass/fail/skip counts |
| 50.3.1 | Fix test failures | P1 | 3 | Diagnose and fix any failures |
| 50.3.2 | Re-run failed tests | P1 | 3 | Verify fixes resolve failures |
| 50.4.1 | Quality gate verification | P2 | 4 | compile + format + credo + F# build |
| 50.4.2 | Coverage report | P2 | 4 | mix test --cover (if feasible) |
| 50.5.1 | Journal + memory update | P2 | 5 | Record results |
| 50.5.2 | Commit | P2 | 5 | Commit any fixes |

---

## Level 3: Infrastructure Architecture

### SIL-6 Full Mesh (14 Containers)

| Container | Role | Port | Health Check |
|-----------|------|------|--------------|
| indrajaal-db-prod | PostgreSQL 17 + TimescaleDB | 5433 | pg_isready |
| indrajaal-obs-prod | OTEL + Prometheus + Grafana + Loki | 4317/9090/3000/3100 | HTTP /health |
| indrajaal-ex-app-1 | Phoenix Primary (Seed) | 4000/4001 | HTTP /health |
| zenoh-router-1 | Zenoh Control Plane | 7447 | TCP connect |
| zenoh-router-2 | Zenoh Control Plane | 7448 | TCP connect |
| zenoh-router-3 | Zenoh Control Plane | 7449 | TCP connect |
| indrajaal-cortex | Cognitive Plane (AI) | 9877 | HTTP /health |
| cepaf-bridge | Orchestration Bridge | 9876 | HTTP /health |
| indrajaal-chaya | Digital Twin | 4002 | HTTP /health |
| indrajaal-ex-app-2 | Phoenix Replica | - | HTTP /health |
| indrajaal-ex-app-3 | Phoenix Replica | - | HTTP /health |
| indrajaal-ml-runner-1 | ML Satellite | - | Process check |
| indrajaal-ml-runner-2 | ML Satellite | - | Process check |
| zenoh-router | Legacy router | - | TCP connect |

### Network Topology

```
indrajaal-mesh (172.28.0.0/16)
├── DB:       172.28.0.20
├── OBS:      172.28.0.30
├── APP-1:    172.28.0.10
├── Zenoh-1:  172.28.0.40
├── Zenoh-2:  172.28.0.41
├── Zenoh-3:  172.28.0.42
├── Cortex:   172.28.0.50
├── Bridge:   172.28.0.51
└── Chaya:    172.28.0.52

indrajaal-internal (172.29.0.0/16)
└── DB + APP internal communication
```

---

## Level 4: Execution Strategy

### Gate Definitions

| Gate | Command | Pass Criteria |
|------|---------|---------------|
| G0 | `podman ps --filter status=running` | ≥3 core containers healthy |
| G1 | `pg_isready -h localhost -p 5433` | Exit 0 |
| G2 | `mix test` | 0 failures |
| G3 | `mix compile --warnings-as-errors` | 0 warnings |
| G4 | `mix credo --strict` | 0 issues |

### Fallback Strategy

If full SIL-6 mesh fails to boot (image issues, resource constraints):
1. **Fallback 1**: Boot prod-standalone (4 containers: DB + OBS + APP + Zenoh)
2. **Fallback 2**: Boot DB-only (1 container) — sufficient for test suite
3. **Fallback 3**: Skip container-dependent tests, verify compilation only

### Test Categories

| Category | Estimated Count | DB Required | Container Required |
|----------|----------------|-------------|-------------------|
| Unit tests | ~400 | No | No |
| Property tests | ~50 | No | No |
| Integration tests | ~100 | Yes | No |
| Container tests | ~30 | Yes | Yes |
| SIL-6 mesh tests | ~210 | Yes | Yes (full mesh) |

---

## Level 5: 5-Order Effect Analysis

### Expected Effects

| Order | Effect |
|-------|--------|
| 1st | All 14 containers running, ports bound, health checks passing |
| 2nd | Database created and migrated, Ecto sandbox operational |
| 3rd | Full test suite executes, pass/fail counts known |
| 4th | Any failures diagnosed and fixed, coverage measured |
| 5th | System validated end-to-end, GA readiness confirmed |

### FMEA Risk Analysis

| Failure Mode | S | O | D | RPN | Mitigation |
|--------------|---|---|---|-----|------------|
| Container images missing | 8 | 3 | 9 | 216 | Fallback to prod-standalone |
| Port conflicts | 7 | 4 | 4 | 112 | Clean stale containers first |
| DB migration fails | 7 | 3 | 6 | 126 | Reset DB, re-migrate |
| Test timeout (Patient Mode) | 5 | 4 | 3 | 60 | Increase timeout |
| OOM on full mesh | 6 | 3 | 5 | 90 | Fallback to 4-container |
| Zenoh NIF load failure | 8 | 2 | 7 | 112 | Set SKIP_ZENOH_NIF=0 |

---

## References

- Sprint 49 commit: 7f6910191
- Compose file: `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml`
- Fallback compose: `lib/cepaf/artifacts/podman-compose-prod-standalone.yml`
- STAMP: SC-SIL6-001, SC-CNT-009, SC-CMD-010, SC-EMR-057
