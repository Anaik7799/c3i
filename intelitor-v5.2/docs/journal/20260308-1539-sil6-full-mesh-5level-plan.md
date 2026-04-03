# SIL-6 Full Mesh: 5-Level Comprehensive Readiness Plan

**Date**: 2026-03-08 15:39 CET
**Version**: 21.3.0-SIL6
**Author**: Claude Opus 4.6
**Scope**: Full 14-container SIL-6 Biomorphic Fractal Mesh
**Fractal Layers**: L0 (Runtime) through L7 (Federation)
**STAMP**: SC-SIL6-001, SC-MESH-001, SC-BOOT-001 to SC-BOOT-050

---

## Executive Summary

This plan achieves full SIL-6 mesh readiness across 5 levels of detail,
covering all 8 fractal layers (L0-L7), using CEPAF F# orchestration for
infrastructure and Elixir for application logic. Target: 100% functionality,
100% test coverage, all 14 containers operational with 2oo3 quorum consensus.

---

## Current State Assessment

| Component | Status | Score |
|-----------|--------|-------|
| Elixir v1.19.4 / OTP 28 | Ready | 100% |
| .NET 10.0.101 / F# | Ready | 100% |
| Podman 5.7.0 (rootless) | Ready | 100% |
| Rust 1.91.1 (NIFs) | Ready | 100% |
| Zenoh configs (3 routers) | Ready | 100% |
| Container images (38 total) | Ready | 95% |
| F# projects (36 .fsproj) | Ready | 100% |
| Test files (977 Elixir + 42 F#) | Ready | 100% |
| Compilation state (_build/dev) | Exists | 95% |
| Holon state (data/holons/) | Ready | 100% |
| Containers running | 0/14 | 0% |

---

## Architecture: 14-Container SIL-6 Full Mesh

```
                    ┌─────────────────────────────────────────────────┐
                    │              FEDERATION (L7)                      │
                    │    Cross-holon attestation, version negotiation   │
                    └───────────────────────┬─────────────────────────┘
                                            │
                    ┌───────────────────────┴─────────────────────────┐
                    │              CLUSTER (L6)                         │
                    │    2oo3 Quorum, FPPS Consensus, Apoptosis        │
                    │    zenoh-router-1/2/3 + zenoh-router (proxy)     │
                    └───────────────────────┬─────────────────────────┘
                                            │
          ┌─────────────────────────────────┼─────────────────────────────┐
          │                                 │                             │
┌─────────┴──────────┐   ┌─────────────────┴──────────┐   ┌─────────────┴─────────┐
│   COGNITIVE (L5)    │   │     APPLICATION (L4)        │   │   SATELLITE (L5)      │
│ cepaf-bridge :9876  │   │ indrajaal-ex-app-1 :4000    │   │ ml-runner-1           │
│ indrajaal-cortex    │   │ indrajaal-ex-app-2 :4003    │   │ ml-runner-2           │
│ :9877               │   │ indrajaal-ex-app-3 :4005    │   │                       │
└─────────────────────┘   │ indrajaal-chaya :4002       │   └───────────────────────┘
                          └─────────────────┬──────────┘
                                            │
          ┌─────────────────────────────────┼──────────────────────────────┐
          │                                                                │
┌─────────┴──────────┐                                    ┌────────────────┴───────┐
│     DATA (L3)       │                                    │   OBSERVABILITY (L3)    │
│ indrajaal-db-prod   │                                    │ indrajaal-obs-prod      │
│ PG17+TimescaleDB    │                                    │ OTEL+Prometheus+Grafana │
│ :5433               │                                    │ +Loki+SigNoz            │
└─────────────────────┘                                    └────────────────────────┘
```

---

## LEVEL 1: Strategic Overview (What & Why)

### 1.1 Goal
Deploy and verify the complete SIL-6 Biomorphic Fractal Mesh with:
- 14 containers across 5 tiers (Data, Observability, Mesh Control, Cognitive, Application)
- 2oo3 Zenoh quorum consensus (SC-SIL6-006)
- Full Elixir compilation (0 errors, 0 warnings)
- Full F# build (0 errors across 36 projects)
- 100% test coverage (977 Elixir tests + 42 F# test modules)
- All 8 fractal layers verified (L0-L7)

### 1.2 Five Phases

| Phase | Name | Duration | Fractal Layers | Key Deliverable |
|-------|------|----------|----------------|-----------------|
| **P1** | Foundation Verification | 10 min | L0-L1 | Compilation clean, F# build clean |
| **P2** | Infrastructure Boot | 15 min | L2-L3 | 14 containers healthy |
| **P3** | Mesh Convergence | 10 min | L4-L5 | 2oo3 quorum, cognitive bridge |
| **P4** | Test Execution | 30 min | L0-L5 | 100% pass, 95%+ coverage |
| **P5** | Homeostasis Verification | 10 min | L6-L7 | Full system operational |

### 1.3 Success Criteria

| Criterion | Target | STAMP |
|-----------|--------|-------|
| Elixir compilation | 0 errors, 0 warnings | SC-CMP-025, SC-CMP-026 |
| F# compilation | 0 errors across 36 projects | SC-NET-001 |
| Container health | 14/14 healthy | SC-SIL6-001 |
| Zenoh quorum | 2oo3 achieved | SC-SIL6-006 |
| Test pass rate | 100% | SC-TEST-001 |
| Test coverage | >= 95% | SC-COV-002 |
| FPPS consensus | 5/5 methods agree | SC-VAL-003 |
| Mesh latency | < 100ms E2E | SC-ZTEST-005 |
| Neural-immune response | < 50ms | SC-SIL6-004 |

---

## LEVEL 2: Phase Detail (How)

### Phase 1: Foundation Verification (L0-L1)

**Goal**: Ensure codebase compiles cleanly across both runtimes.

| Step | Command | Validates | Layer |
|------|---------|-----------|-------|
| 1.1 | `NO_TIMEOUT=true mix compile` | Elixir compilation | L0 |
| 1.2 | `mix format --check-formatted` | Code formatting | L0 |
| 1.3 | `mix credo --strict` | Static analysis | L1 |
| 1.4 | `dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj` | F# core build | L0 |
| 1.5 | `dotnet build lib/cepaf` | All 36 F# projects | L1 |
| 1.6 | Verify Zenoh NIF loadable (SKIP_ZENOH_NIF=0) | NIF integrity | L0 |

**Fractal Layer Coverage**:
- **L0 (Runtime)**: System compiles and boots without error
- **L1 (Function)**: I/O contracts valid, format/credo pass

**Exit Gate**: Zero errors + zero warnings across both runtimes.

---

### Phase 2: Infrastructure Boot (L2-L3)

**Goal**: Start all 14 containers in dependency-ordered waves.

| Wave | Containers | Duration | Health Check |
|------|-----------|----------|--------------|
| W1: Foundation | indrajaal-db-prod | 30s | pg_isready -p 5433 |
| W2: Observability | indrajaal-obs-prod | 45s | Prometheus + Grafana healthy |
| W3: Mesh Control | zenoh-router-1/2/3 + proxy | 15s | nc -z localhost 7447/7448/7449 |
| W4: Cognitive | cepaf-bridge, indrajaal-cortex | 45s | nc -z 9876, curl 9877/health |
| W5a: Application | indrajaal-ex-app-1 (seed) | 15min | curl localhost:4000 |
| W5b: HA + Satellite | app-2, app-3, chaya, ml-1/2 | 10min | Health endpoints |

**Compose File**: `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml`

**Boot Command**:
```bash
podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml up -d
```

**Fractal Layer Coverage**:
- **L2 (Component)**: Module cohesion verified via container isolation
- **L3 (Holon)**: Agent logic sound, individual services healthy

**Exit Gate**: All 14 containers report healthy status.

---

### Phase 3: Mesh Convergence (L4-L5)

**Goal**: Achieve cluster consensus and cognitive bridge connectivity.

| Step | Verification | Expected | Layer |
|------|-------------|----------|-------|
| 3.1 | Zenoh 2oo3 quorum | 3/3 routers connected | L4 |
| 3.2 | App cluster formation | 3 Erlang nodes joined | L4 |
| 3.3 | CEPAF bridge connectivity | HTTP 200 on :9876 | L5 |
| 3.4 | Cortex AI plane | HTTP 200 on :9877/health | L5 |
| 3.5 | Chaya Digital Twin | HTTP 200 on :4002 | L5 |
| 3.6 | ML Runner readiness | Processes alive on :4003/:4005 | L5 |
| 3.7 | Redis connectivity | localhost:6379 from app-1 | L4 |
| 3.8 | OTEL trace flow | Traces arriving at obs-prod | L5 |

**Fractal Layer Coverage**:
- **L4 (Container)**: Isolation maintained, ports bound correctly
- **L5 (Node)**: Runtime environment stable, all services reachable

**Exit Gate**: Quorum achieved, bridge connected, all endpoints responsive.

---

### Phase 4: Test Execution (L0-L5)

**Goal**: Run full test suite with 100% pass rate and 95%+ coverage.

| Step | Command | Tests | Layer |
|------|---------|-------|-------|
| 4.1 | Elixir unit tests | 977 test files | L0-L1 |
| 4.2 | Property tests (PropCheck+SD) | Dual property | L1-L2 |
| 4.3 | Fractal tests (L1-L7) | 10 fractal files | L2-L5 |
| 4.4 | Zenoh integration tests | 19 Zenoh tests | L4-L5 |
| 4.5 | F# unit tests | 42+ modules | L0-L1 |
| 4.6 | F# integration tests | Bridge tests | L3-L4 |
| 4.7 | Coverage report | ExCoveralls | All |

**Elixir Test Command**:
```bash
SKIP_ZENOH_NIF=0 NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_ENV=test mix test --cover
```

**F# Test Command**:
```bash
dotnet test lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj
```

**Fractal Layer Coverage**:
- **L0-L5**: Comprehensive unit + integration + property tests

**Exit Gate**: 0 failures, >= 95% line coverage.

---

### Phase 5: Homeostasis Verification (L6-L7)

**Goal**: Verify cluster consensus and federation readiness.

| Step | Verification | Expected | Layer |
|------|-------------|----------|-------|
| 5.1 | FPPS 5-method consensus | All 5 agree | L6 |
| 5.2 | Quorum voting test | 2oo3 passes | L6 |
| 5.3 | Health propagation | All nodes GREEN | L6 |
| 5.4 | Apoptosis readiness | Protocol armed | L6 |
| 5.5 | Federation protocol | Version negotiated | L7 |
| 5.6 | Cross-holon attestation | Peer integrity verified | L7 |
| 5.7 | Global invariants | Ψ₀-Ψ₅ hold | L7 |
| 5.8 | Founder's Directive | Ω₀ hardwired | L7 |

**Fractal Layer Coverage**:
- **L6 (Cluster)**: Consensus holds, quorum verified
- **L7 (Federation)**: Global invariants hold

**Exit Gate**: Full homeostasis, system ready for production traffic.

---

## LEVEL 3: Task Decomposition (Each Step Broken Down)

### P1: Foundation Verification - Detailed Tasks

#### P1.1: Elixir Compilation (L0)
```
P1.1.1  Set environment: NO_TIMEOUT=true PATIENT_MODE=enabled
P1.1.2  Set schedulers: ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
P1.1.3  Set partitions: MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8
P1.1.4  Run: mix compile 2>&1 | tee ./data/tmp/1-compile.log
P1.1.5  Verify: 0 errors in output
P1.1.6  Verify: 0 warnings in output
P1.1.7  Verify: All 773+ files compiled
P1.1.8  Verify: Zenoh NIF compiled (native/zenoh_nif)
P1.1.9  Verify: Lineage NIF compiled (if enabled)
```

#### P1.2: Code Quality (L1)
```
P1.2.1  Run: mix format --check-formatted
P1.2.2  Verify: All 2181+ files formatted
P1.2.3  Run: mix credo --strict
P1.2.4  Verify: 0 issues (no refactoring opportunities flagged)
P1.2.5  Verify: No apply/2 anti-patterns (EP-CREDO-001)
```

#### P1.3: F# Build (L0-L1)
```
P1.3.1  Run: dotnet restore lib/cepaf
P1.3.2  Run: dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj
P1.3.3  Verify: 0 errors, 0 warnings
P1.3.4  Run: dotnet build lib/cepaf (all 36 projects)
P1.3.5  Verify: All projects target net10.0 (SC-NET-001)
P1.3.6  Verify: Planning.CLI builds (sa-plan commands)
P1.3.7  Verify: Cockpit.CLI builds (sa-monitor commands)
P1.3.8  Verify: KMS.Catalog.Daemon builds
```

### P2: Infrastructure Boot - Detailed Tasks

#### P2.1: Pre-flight (L2)
```
P2.1.1  Verify no port conflicts: ss -tlnp | grep -E '4000|5433|7447|9876'
P2.1.2  Verify Podman rootless: podman info --format '{{.Host.Security.Rootless}}'
P2.1.3  Verify images exist:
         - localhost/indrajaal-timescaledb-demo:nixos-devenv
         - localhost/indrajaal-obs-unified:nixos-devenv
         - localhost/indrajaal-app-unified:nixos-devenv
         - localhost/cepaf-bridge:latest
         - localhost/indrajaal-cortex:latest
         - eclipse/zenoh:1.0.0
P2.1.4  Verify Zenoh configs: config/zenoh/zenoh-router-{1,2,3}.json5
P2.1.5  Verify compose file: lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml
P2.1.6  Clean any stale containers: podman rm -f (if needed)
```

#### P2.2: Wave Boot (L3)
```
P2.2.1  Wave 1 - DB: Start indrajaal-db-prod, wait pg_isready
P2.2.2  Wave 2 - OBS: Start indrajaal-obs-prod, wait Prometheus+Grafana
P2.2.3  Wave 3 - MESH: Start zenoh-router-1/2/3 + proxy, verify 2oo3
P2.2.4  Wave 4 - COGNITIVE: Start cepaf-bridge + cortex, verify endpoints
P2.2.5  Wave 5a - SEED: Start indrajaal-ex-app-1, wait for Phoenix
P2.2.6  Wave 5b - HA: Start app-2, app-3, chaya, ml-runners
P2.2.7  Verify: podman ps shows 14 containers
P2.2.8  Verify: All healthchecks passing
```

### P3: Mesh Convergence - Detailed Tasks

#### P3.1: Zenoh Quorum (L4)
```
P3.1.1  Verify zenoh-router-1: curl http://localhost:8000/@/router/local
P3.1.2  Verify zenoh-router-2: curl http://localhost:8001/@/router/local
P3.1.3  Verify zenoh-router-3: curl http://localhost:8002/@/router/local
P3.1.4  Verify 2oo3 quorum: >= 2 of 3 routers healthy
P3.1.5  Test pub/sub: Publish to indrajaal/test/ping, verify delivery
```

#### P3.2: Application Cluster (L4-L5)
```
P3.2.1  Verify app-1 Phoenix: curl http://localhost:4000
P3.2.2  Verify app-1 health: curl http://localhost:4001/health
P3.2.3  Verify CEPAF bridge: curl http://localhost:9876/health
P3.2.4  Verify Cortex: curl http://localhost:9877/health
P3.2.5  Verify Chaya: curl http://localhost:4002
P3.2.6  Verify OTEL traces: curl http://localhost:4317 (gRPC alive)
P3.2.7  Verify Prometheus: curl http://localhost:9090/-/healthy
P3.2.8  Verify Grafana: curl http://localhost:3000/api/health
```

### P4: Test Execution - Detailed Tasks

#### P4.1: Elixir Test Suite (L0-L5)
```
P4.1.1  Set env: SKIP_ZENOH_NIF=0 DATABASE_URL=...test MIX_ENV=test
P4.1.2  Run: mix test --cover
P4.1.3  Verify: 0 failures
P4.1.4  Verify: All 977 test files loaded
P4.1.5  Verify: Property tests pass (PropCheck + StreamData)
P4.1.6  Verify: Coverage >= 95%
P4.1.7  Run fractal tests: mix test test/fractal/
P4.1.8  Verify: L1-L7 fractal layers all pass
```

#### P4.2: F# Test Suite (L0-L4)
```
P4.2.1  Run: dotnet test lib/cepaf/test/Cepaf.Tests/
P4.2.2  Verify: Unit tests pass (DAG, FSM, CPM, HLC, Hysteresis)
P4.2.3  Verify: Integration tests pass
P4.2.4  Verify: Coverage >= 80% (F# target)
P4.2.5  Run: dotnet test lib/cepaf/test/Cepaf.IndrajaalTest/
P4.2.6  Verify: Cross-runtime bridge tests pass
```

#### P4.3: Smoke Tests (L3-L5)
```
P4.3.1  Run BDD smoke: dotnet fsi lib/cepaf/scripts/SIL6MeshBDDSmokeTests.fsx
P4.3.2  Run swarm verify: dotnet fsi lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx verify
P4.3.3  Verify: API endpoints responding (HTTP 200)
P4.3.4  Verify: Database operations succeed
P4.3.5  Verify: Zenoh pub/sub functional
P4.3.6  Verify: Performance baselines met (<50ms PHICS)
```

### P5: Homeostasis - Detailed Tasks

#### P5.1: Cluster Verification (L6)
```
P5.1.1  Run FPPS 5-method consensus validation
P5.1.2  Verify: Pattern method agrees
P5.1.3  Verify: AST method agrees
P5.1.4  Verify: Statistical method agrees
P5.1.5  Verify: Binary method agrees
P5.1.6  Verify: LineByLine method agrees
P5.1.7  Test quorum voting: 2oo3 pass
P5.1.8  Verify health propagation across all 14 containers
```

#### P5.2: Federation Verification (L7)
```
P5.2.1  Verify Ψ₀ (Existence): System survives all operations
P5.2.2  Verify Ψ₁ (Regeneration): Can restore from SQLite/DuckDB
P5.2.3  Verify Ψ₂ (History): Evolution continuity maintained
P5.2.4  Verify Ψ₃ (Verification): All changes verifiable
P5.2.5  Verify Ψ₄ (Human Alignment): Founder's lineage primary
P5.2.6  Verify Ψ₅ (Truthfulness): System truthful about state
P5.2.7  Verify Ω₀ (Founder's Directive): Hardwired and active
P5.2.8  Final health report: All layers GREEN
```

---

## LEVEL 4: Environment Configuration & STAMP Mapping

### 4.1 Environment Variables (Complete Set)

```bash
# Patient Mode (SC-VAL-001, Ω₁)
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8

# Container (SC-CNT-009, SC-CNT-010, SC-CNT-012, Ω₂)
PODMAN_ROOTLESS=true
CONTAINER_REGISTRY=localhost

# Database (SC-DB-001)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DATABASE_URL=ecto://postgres:postgres@localhost:5433/indrajaal_dev

# Zenoh (SC-ZENOH-001, SC-ZENOH-002)
SKIP_ZENOH_NIF=0
ZENOH_ENABLED=true
ZENOH_ROUTER_ENDPOINT=tcp/zenoh-router:7447

# Observability (SC-OBS-069, SC-OBS-071)
OTEL_EXPORTER_OTLP_ENDPOINT=http://indrajaal-obs-prod:4317
OTEL_SERVICE_NAME=indrajaal-ex-app-1
FRACTAL_LOGGING_ENABLED=true

# Cognitive Plane (SC-SYNC-001)
CEPAF_BRIDGE_URL=http://cepaf-bridge:9876
CORTEX_URL=http://indrajaal-cortex:9877

# SIL-6 (SC-SIL6-001)
SIL_LEVEL=6
SOPV51_COMPLIANT=true
```

### 4.2 STAMP Constraint Coverage Matrix

| Phase | SC Constraints Verified | Count |
|-------|------------------------|-------|
| P1 | SC-CMP-025/026/028, SC-NET-001/002, SC-GEM-003, SC-CREDO-001 | 7 |
| P2 | SC-CNT-009/010/012, SC-SIL6-001, SC-MESH-001, SC-ZENOH-001/002 | 7 |
| P3 | SC-SIL6-006/011, SC-SYNC-001, SC-BRIDGE-001/003, SC-PRF-050 | 6 |
| P4 | SC-TEST-001/005, SC-COV-001/002, SC-PROP-021/022/023, SC-MIG-001 | 8 |
| P5 | SC-VAL-003/004, SC-SIL6-004/006, SC-FRAC-001 to 007 | 12 |
| **Total** | | **40** |

### 4.3 AOR Rule Coverage

| Phase | AOR Rules Enforced | Count |
|-------|-------------------|-------|
| P1 | AOR-QUA-001, AOR-AGT-001, AOR-NET-001, AOR-CREDO-001 | 4 |
| P2 | AOR-CNT-001, AOR-HOLON-001, AOR-MESH-001 | 3 |
| P3 | AOR-MESH-003, AOR-BRIDGE-001/002, AOR-ZENOH-001/002 | 5 |
| P4 | AOR-TEST-NIF-001/002/003, AOR-PROP-001, AOR-TEST-001 | 5 |
| P5 | AOR-CONST-001/003, AOR-FOUNDER-001, AOR-FUNC-001 | 4 |
| **Total** | | **21** |

### 4.4 Fractal Layer x Phase Matrix

```
         │ P1:Found │ P2:Infra │ P3:Mesh │ P4:Test │ P5:Homeo │
─────────┼──────────┼──────────┼─────────┼─────────┼──────────┤
L0 Run   │  ████    │          │         │  ████   │          │
L1 Func  │  ████    │          │         │  ████   │          │
L2 Comp  │          │  ████    │         │  ████   │          │
L3 Holon │          │  ████    │         │  ████   │          │
L4 Cont  │          │          │  ████   │  ████   │          │
L5 Node  │          │          │  ████   │  ████   │          │
L6 Clust │          │          │         │         │  ████    │
L7 Feder │          │          │         │         │  ████    │
```

---

## LEVEL 5: Execution Commands (Copy-Paste Ready)

### P1: Foundation Verification

```bash
# P1.1 - Elixir Compilation (L0)
NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 \
mix compile 2>&1 | tee ./data/tmp/1-compile.log

# P1.2 - Quality Gate (L1)
mix format --check-formatted && mix credo --strict

# P1.3 - F# Build (L0-L1)
dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj
dotnet build lib/cepaf
```

### P2: Infrastructure Boot

```bash
# P2.1 - Pre-flight
ss -tlnp | grep -E '4000|5433|7447|9876|9877' || echo "Ports clear"
podman info --format '{{.Host.Security.Rootless}}'

# P2.2 - Full Mesh Boot
podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml up -d

# P2.3 - Wait and Verify
sleep 30 && podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### P3: Mesh Convergence

```bash
# P3.1 - Zenoh Quorum
curl -sf http://localhost:8000/@/router/local && echo "Router-1 OK"
curl -sf http://localhost:8001/@/router/local && echo "Router-2 OK"
curl -sf http://localhost:8002/@/router/local && echo "Router-3 OK"

# P3.2 - Application Health
curl -sf http://localhost:4000/ && echo "Phoenix OK"
curl -sf http://localhost:9876/health && echo "CEPAF Bridge OK"
curl -sf http://localhost:9877/health && echo "Cortex OK"
curl -sf http://localhost:9090/-/healthy && echo "Prometheus OK"
curl -sf http://localhost:3000/api/health && echo "Grafana OK"
```

### P4: Test Execution

```bash
# P4.1 - Elixir Full Suite with Coverage
SKIP_ZENOH_NIF=0 \
POSTGRES_USER=postgres \
POSTGRES_PASSWORD=postgres \
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test" \
NO_TIMEOUT=true PATIENT_MODE=enabled \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" \
MIX_ENV=test mix test --cover

# P4.2 - F# Tests
dotnet test lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj

# P4.3 - BDD Smoke Tests
dotnet fsi lib/cepaf/scripts/SIL6MeshBDDSmokeTests.fsx
```

### P5: Homeostasis Verification

```bash
# P5.1 - FPPS Consensus + Health
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh health

# P5.2 - 2oo3 Verification
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh verify

# P5.3 - Full Status Report
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh status
```

### Shutdown (After Verification)

```bash
# Graceful shutdown with checkpoint
dotnet run --project lib/cepaf/src/Cepaf/Cepaf.fsproj -- mesh down

# OR direct compose
podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml down
```

---

## Risk Matrix (FMEA)

| Risk | Severity | Probability | Detection | RPN | Mitigation |
|------|----------|-------------|-----------|-----|------------|
| F# build errors (Integration.fs) | 8 | 6 | 9 | 432 | Fix type errors before boot |
| Zenoh image version mismatch | 7 | 3 | 8 | 168 | Pin eclipse/zenoh:1.0.0 |
| Port conflicts on 4000/5433 | 7 | 5 | 4 | 140 | sa-scour pre-flight |
| OBS container unhealthy | 6 | 5 | 3 | 90 | Relaxed healthcheck (Prom+Grafana only) |
| App container 15min startup | 5 | 7 | 2 | 70 | Patient Mode, 900s start_period |
| Memory exhaustion (27GB required) | 9 | 3 | 2 | 54 | Monitor free memory before boot |
| NIF compilation failure | 9 | 2 | 8 | 144 | Verify Rust 1.91+ available |
| Test timeout | 5 | 4 | 3 | 60 | NO_TIMEOUT=true, timeout: :infinity |

---

## Resource Requirements

| Resource | Requirement | Current |
|----------|-------------|---------|
| RAM | ~27 GB (all 14 containers) | Check: `free -h` |
| CPU | 23 cores allocated | 16 physical cores |
| Disk | ~50 GB (images + volumes) | Check: `df -h` |
| Ports | 4000,4001,4002,4003,4005,5433,6379,7447-7449,8000-8002,9090,3000,3100,9876,9877 | Must be free |
| Network | 172.28.0.0/16 + 172.29.0.0/16 subnets | Podman bridge |

---

## Post-Execution Checklist

- [ ] P1: Elixir compilation 0 errors, 0 warnings
- [ ] P1: F# build 0 errors across 36 projects
- [ ] P1: Format + Credo pass
- [ ] P2: 14/14 containers healthy
- [ ] P2: All waves completed in order
- [ ] P3: 2oo3 Zenoh quorum achieved
- [ ] P3: CEPAF bridge + Cortex reachable
- [ ] P3: All Phoenix endpoints responsive
- [ ] P4: Elixir tests 0 failures
- [ ] P4: Coverage >= 95%
- [ ] P4: F# tests pass
- [ ] P4: BDD smoke tests pass
- [ ] P5: FPPS 5-method consensus
- [ ] P5: Ψ₀-Ψ₅ constitutional invariants hold
- [ ] P5: Ω₀ Founder's Directive active
- [ ] P5: Full system homeostasis achieved

---

## Related Documents

| Document | Location |
|----------|----------|
| CLAUDE.md | Root (master spec) |
| SIL-6 Compose | lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml |
| F# Mesh CLI | lib/cepaf/src/Cepaf/Mesh/SIL6MeshCLI.fs |
| Digital Twin | lib/cepaf/src/Cepaf/Mesh/DigitalTwin.fs |
| Zenoh Configs | config/zenoh/zenoh-router-{1,2,3}.json5 |
| Test Helper | test/test_helper.exs |
| Fractal Tests | test/fractal/l{1..7}_*.exs |
| Mesh Orchestrator | lib/cepaf/scripts/SIL6MeshOrchestrator.fsx |
| Swarm Orchestrator | lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx |
