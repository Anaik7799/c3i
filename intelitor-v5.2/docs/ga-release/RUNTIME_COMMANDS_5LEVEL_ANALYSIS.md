# Runtime Commands 5-Level Analysis Plan
**Version**: 21.3.0-SIL6 GA Release | **Date**: 2026-01-03 (Updated: 2026-03-19) | **Status**: VERIFIED

## Executive Summary

This document provides a 5-level fractal analysis of ALL runtime commands for 100% functional coverage verification before GA release.

---

## Level 1: Command Categories (L1 - System View)

### L1.1 Devenv Shell Commands (102 commands: 32 core + 70 extended)
| Category | Commands | Count |
|----------|----------|-------|
| **App & Server** | `app`, `app-start`, `app-iex` | 3 |
| **Compilation** | `compile`, `compile-strict` | 2 |
| **Quality** | `quality`, `quality-full` | 2 |
| **Testing** | `test`, `test-cover` | 2 |
| **Standalone** | `sa-up`, `sa-down`, `sa-clean`, `sa-status`, `sa-logs`, `sa-db`, `sa-obs`, `sa-app`, `sa-test`, `sa-ux`, `sa-orchestrate` | 11 |
| **Database** | `db-setup`, `db-reset`, `db-migrate`, `db-console` | 4 |
| **CEPAF/F#** | `cockpitf`, `cepaf-build` | 2 |
| **Reporting** | `envelope`, `envelope-json`, `envelope-journal`, `todo` | 4 |
| **Other** | `help`, `claude` | 2 |

### L1.2 Mix Tasks (Custom)
| Category | Tasks | Count |
|----------|-------|-------|
| **Validation** | `validate.ep014`, `validate.headers`, `fame.validate` | 3 |
| **Container** | `container.health`, `container.status` | 2 |
| **Fractal** | `fractal.dashboard` | 1 |
| **Capability** | `capability.envelope` | 1 |
| **Holon** | `holon.verify` | 1 |
| **CAFE** | `cafe.execute` | 1 |
| **Quality** | `quality.check` | 1 |
| **OpenAPI** | `openapi.generate` | 1 |

### L1.3 Environment Variables
| Variable | Purpose | Default |
|----------|---------|---------|
| `NO_TIMEOUT` | Patient mode | `true` |
| `PATIENT_MODE` | Compilation patience | `enabled` |
| `INFINITE_PATIENCE` | Never timeout | `true` |
| `SKIP_ZENOH_NIF` | NIF loading | `0` (active) |
| `POSTGRES_USER` | DB user | `postgres` |
| `POSTGRES_PASSWORD` | DB password | `postgres` |
| `DATABASE_URL` | Connection string | `ecto://...` |
| `MIX_ENV` | Environment | `dev` |
| `PHX_SERVER` | Start server | `true` |
| `LOG_DIRECTORY` | Log path | `./data/tmp` |

---

## Level 2: Command Dependencies (L2 - Component View)

### L2.1 Container Stack Dependencies
```
┌─────────────────────────────────────────────────────────────┐
│                    STANDALONE STACK                          │
├─────────────────────────────────────────────────────────────┤
│  sa-up ──────┬──► indrajaal-db-prod (PostgreSQL:5433)       │
│              ├──► indrajaal-obs-prod (OTEL/Grafana:3000)    │
│              ├──► indrajaal-ex-app-1 (Phoenix:4000)         │
│              └──► zenoh-router (Zenoh:7447)                 │
├─────────────────────────────────────────────────────────────┤
│  sa-db ──────────► indrajaal-db-prod ONLY                   │
│  sa-obs ─────────► indrajaal-obs-prod ONLY                  │
│  sa-app ─────────► indrajaal-ex-app-1 ONLY                  │
└─────────────────────────────────────────────────────────────┘
```

### L2.2 File Dependencies
| Command | Required Files |
|---------|----------------|
| `sa-up` | `lib/cepaf/artifacts/podman-compose-prod-standalone.yml` |
| `sa-db` | `lib/cepaf/artifacts/podman-compose-db-standalone.yml` |
| `sa-obs` | `lib/cepaf/artifacts/podman-compose-obs-standalone.yml` |
| `sa-app` | `lib/cepaf/artifacts/podman-compose-app-standalone.yml` |
| `sa-test` | `lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx` |
| `sa-ux` | `lib/cepaf/scripts/CockpitUXEvaluator.fsx` |
| `sa-orchestrate` | `lib/cepaf/scripts/RuntimeTestOrchestrator.fsx` |
| `cockpitf` | `lib/cepaf/scripts/CockpitOperations.fsx` |
| `app-start` | `scripts/env/dev-start.exs` |

### L2.3 Service Port Matrix
| Service | Port | Protocol | Container |
|---------|------|----------|-----------|
| Phoenix | 4000 | HTTP | app-prod |
| Health | 4001 | HTTP | app-prod |
| PostgreSQL | 5433 | TCP | db-prod |
| Redis | 6379 | TCP | app-prod |
| Grafana | 3000 | HTTP | obs-prod |
| Prometheus | 9090 | HTTP | obs-prod |
| Loki | 3100 | HTTP | obs-prod |
| OTEL gRPC | 4317 | gRPC | obs-prod |
| OTEL HTTP | 4318 | HTTP | obs-prod |
| Zenoh Router | 7447 | TCP | zenoh-router |
| Zenoh Admin | 8000 | HTTP | zenoh-router |

---

## Level 3: Command Specifications (L3 - Function View)

### L3.1 App & Server Commands

#### L3.1.1 `app` - Start Phoenix Server
- **Implementation**: `mix phx.server`
- **Prerequisites**: Database running, deps compiled
- **Success Criteria**: HTTP 200 on localhost:4000
- **Failure Modes**: DB connection, port conflict, compilation error
- **STAMP**: SC-CMD-001, SC-PRF-050

#### L3.1.2 `app-start` - Full Stack Start
- **Implementation**: `elixir scripts/env/dev-start.exs && mix phx.server`
- **Prerequisites**: Podman, container images
- **Success Criteria**: All 4 containers (prod-standalone) + Phoenix running
- **Failure Modes**: Container start failure, script error
- **STAMP**: SC-CMD-002, SC-CNT-009

#### L3.1.3 `app-iex` - Interactive Phoenix
- **Implementation**: `iex -S mix phx.server`
- **Prerequisites**: Same as `app`
- **Success Criteria**: IEx prompt with Phoenix running
- **Failure Modes**: Same as `app` + IEx failures
- **STAMP**: SC-CMD-003

### L3.2 Compilation Commands

#### L3.2.1 `compile` - Patient Mode Compile
- **Implementation**: `NO_TIMEOUT=true PATIENT_MODE=enabled mix compile`
- **Prerequisites**: deps.get completed
- **Success Criteria**: 0 errors, output to log
- **Failure Modes**: Syntax error, missing deps, NIF compile
- **STAMP**: SC-CMD-004, SC-CMP-025

#### L3.2.2 `compile-strict` - Warnings as Errors
- **Implementation**: `mix compile --warnings-as-errors`
- **Prerequisites**: Same as compile
- **Success Criteria**: 0 errors, 0 warnings
- **Failure Modes**: Any warning treated as error
- **STAMP**: SC-CMD-005, SC-CMP-026

### L3.3 Quality Commands

#### L3.3.1 `quality` - Basic Quality
- **Implementation**: `mix format --check-formatted && mix credo --strict`
- **Prerequisites**: Compiled code
- **Success Criteria**: Format OK, Credo 0 issues
- **Failure Modes**: Format violations, Credo warnings
- **STAMP**: SC-CMD-006

#### L3.3.2 `quality-full` - Full Pipeline
- **Implementation**: Format + Credo + Dialyzer + Sobelow
- **Prerequisites**: PLT built for Dialyzer
- **Success Criteria**: All 4 tools pass
- **Failure Modes**: Type errors, security issues
- **STAMP**: SC-CMD-007, SC-SEC-044

### L3.4 Testing Commands

#### L3.4.1 `test` - Run Tests
- **Implementation**: `SKIP_ZENOH_NIF=0 MIX_ENV=test mix test`
- **Prerequisites**: Test DB, compiled
- **Success Criteria**: 0 failures
- **Failure Modes**: Test failures, DB issues, NIF errors
- **STAMP**: SC-CMD-008, SC-TEST-005

#### L3.4.2 `test-cover` - Coverage Report
- **Implementation**: `mix test --cover`
- **Prerequisites**: Same as test
- **Success Criteria**: Coverage >95%
- **Failure Modes**: Low coverage
- **STAMP**: SC-CMD-009, SC-COV-001

### L3.5 Standalone Commands

#### L3.5.1 `sa-up` - Start Stack
- **Implementation**: `podman-compose -f .../podman-compose-prod-standalone.yml up -d`
- **Prerequisites**: Podman, images built
- **Success Criteria**: 4 containers running (zenoh-router + db + obs + app); 15 containers for full-mesh
- **Failure Modes**: Image pull, port conflict, resource limits
- **STAMP**: SC-CMD-010, SC-CNT-009

#### L3.5.2 `sa-down` - Stop Stack
- **Implementation**: `podman-compose ... down`
- **Prerequisites**: Stack running
- **Success Criteria**: All containers stopped
- **Failure Modes**: Orphan processes
- **STAMP**: SC-CMD-011

#### L3.5.3 `sa-clean` - Clean Stack
- **Implementation**: `podman-compose ... down -v`
- **Prerequisites**: None
- **Success Criteria**: Containers + volumes removed
- **Failure Modes**: Volume in use
- **STAMP**: SC-CMD-012

#### L3.5.4 `sa-status` - Stack Status
- **Implementation**: `podman-compose ... ps`
- **Prerequisites**: None
- **Success Criteria**: Status displayed
- **Failure Modes**: None expected
- **STAMP**: SC-CMD-013

#### L3.5.5 `sa-logs` - Stream Logs
- **Implementation**: `podman-compose ... logs -f [service]`
- **Prerequisites**: Container exists
- **Success Criteria**: Logs streaming
- **Failure Modes**: Container not found
- **STAMP**: SC-CMD-014

#### L3.5.6 `sa-db` - DB Only
- **Implementation**: `podman-compose -f ...-db-standalone.yml up -d`
- **Prerequisites**: Podman
- **Success Criteria**: PostgreSQL on 5433
- **Failure Modes**: Port conflict
- **STAMP**: SC-CMD-015

#### L3.5.7 `sa-obs` - Observability Only
- **Implementation**: `podman-compose -f ...-obs-standalone.yml up -d`
- **Prerequisites**: Podman
- **Success Criteria**: Grafana on 3000, Prometheus on 9090
- **Failure Modes**: Port conflicts
- **STAMP**: SC-CMD-016

#### L3.5.8 `sa-app` - App Only
- **Implementation**: `podman-compose -f ...-app-standalone.yml up -d`
- **Prerequisites**: DB running
- **Success Criteria**: Phoenix on 4000
- **Failure Modes**: DB connection
- **STAMP**: SC-CMD-017

#### L3.5.9 `sa-test` - Runtime Tests
- **Implementation**: `dotnet fsi .../ComprehensiveRuntimeTests.fsx --mode swarm`
- **Prerequisites**: .NET 10, stack running
- **Success Criteria**: All tests pass
- **Failure Modes**: F# script error, endpoint failures
- **STAMP**: SC-CMD-018

#### L3.5.10 `sa-ux` - UX Evaluation
- **Implementation**: `dotnet fsi .../CockpitUXEvaluator.fsx`
- **Prerequisites**: .NET 10, stack running
- **Success Criteria**: UX report generated
- **Failure Modes**: Script error
- **STAMP**: SC-CMD-019

#### L3.5.11 `sa-orchestrate` - Test Orchestrator
- **Implementation**: `dotnet fsi .../RuntimeTestOrchestrator.fsx --mode [mode]`
- **Prerequisites**: .NET 10, stack running
- **Success Criteria**: Orchestrated tests complete
- **Failure Modes**: Mode not found, test failures
- **STAMP**: SC-CMD-020

### L3.6 Database Commands

#### L3.6.1 `db-setup` - Setup DB
- **Implementation**: `mix ecto.setup`
- **Prerequisites**: PostgreSQL running
- **Success Criteria**: DB created, migrations run
- **Failure Modes**: Connection error, migration failure
- **STAMP**: SC-CMD-021, SC-MIG-001

#### L3.6.2 `db-reset` - Reset DB
- **Implementation**: `mix ecto.reset`
- **Prerequisites**: PostgreSQL running
- **Success Criteria**: DB dropped and recreated
- **Failure Modes**: Active connections blocking drop
- **STAMP**: SC-CMD-022

#### L3.6.3 `db-migrate` - Run Migrations
- **Implementation**: `mix ecto.migrate`
- **Prerequisites**: DB exists
- **Success Criteria**: All migrations applied
- **Failure Modes**: Migration conflict, schema error
- **STAMP**: SC-CMD-023, SC-MIG-002

#### L3.6.4 `db-console` - DB Console
- **Implementation**: `PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d indrajaal_dev`
- **Prerequisites**: PostgreSQL running
- **Success Criteria**: psql prompt
- **Failure Modes**: Auth failure, connection refused
- **STAMP**: SC-CMD-024

### L3.7 CEPAF Commands

#### L3.7.1 `cockpitf` - F# Cockpit
- **Implementation**: `dotnet fsi lib/cepaf/scripts/CockpitOperations.fsx [cmd]`
- **Prerequisites**: .NET 10
- **Success Criteria**: Operation completes
- **Failure Modes**: Invalid command, F# error
- **STAMP**: SC-CMD-025

#### L3.7.2 `cepaf-build` - Build F#
- **Implementation**: `cd lib/cepaf && dotnet build`
- **Prerequisites**: .NET 10
- **Success Criteria**: Build succeeded
- **Failure Modes**: Compile error
- **STAMP**: SC-CMD-026, SC-NET-001

### L3.8 Reporting Commands

#### L3.8.1 `envelope` - Capability Dashboard
- **Implementation**: `mix capability.envelope`
- **Prerequisites**: Compiled
- **Success Criteria**: Dashboard displayed
- **Failure Modes**: Missing data
- **STAMP**: SC-CMD-027

#### L3.8.2 `todo` - Project Tasks
- **Implementation**: `mix todo.status`
- **Prerequisites**: None
- **Success Criteria**: Tasks listed
- **Failure Modes**: None
- **STAMP**: SC-CMD-028

---

## Level 4: Test Scenarios (L4 - Procedure View)

### L4.1 Startup Scenarios

| ID | Scenario | Steps | Expected | STAMP |
|----|----------|-------|----------|-------|
| SC-START-001 | Cold Start | `sa-up` → `sa-status` → `curl :4000/health` | All green | SC-CMD-010 |
| SC-START-002 | DB First | `sa-db` → `sa-obs` → `sa-app` | Sequential start | SC-CMD-015,16,17 |
| SC-START-003 | Dev Mode | `app` (with devenv services) | Phoenix on :4000 | SC-CMD-001 |
| SC-START-004 | Full Dev | `app-start` | Containers + Phoenix | SC-CMD-002 |
| SC-START-005 | Interactive | `app-iex` | IEx + Phoenix | SC-CMD-003 |

### L4.2 Development Scenarios

| ID | Scenario | Steps | Expected | STAMP |
|----|----------|-------|----------|-------|
| SC-DEV-001 | Code Change | Edit → `compile` → `test` | Green | SC-CMD-004,008 |
| SC-DEV-002 | Strict Build | `compile-strict` | 0 warnings | SC-CMD-005 |
| SC-DEV-003 | Quality Check | `quality` | Format + Credo OK | SC-CMD-006 |
| SC-DEV-004 | Full Quality | `quality-full` | All gates pass | SC-CMD-007 |
| SC-DEV-005 | Coverage | `test-cover` | >95% | SC-CMD-009 |

### L4.3 Database Scenarios

| ID | Scenario | Steps | Expected | STAMP |
|----|----------|-------|----------|-------|
| SC-DB-001 | Fresh Setup | `sa-db` → `db-setup` | DB ready | SC-CMD-015,021 |
| SC-DB-002 | Reset Cycle | `db-reset` | Clean slate | SC-CMD-022 |
| SC-DB-003 | Migration | `db-migrate` | Schema updated | SC-CMD-023 |
| SC-DB-004 | Debug | `db-console` | psql active | SC-CMD-024 |

### L4.4 Operational Scenarios

| ID | Scenario | Steps | Expected | STAMP |
|----|----------|-------|----------|-------|
| SC-OPS-001 | Shutdown | `sa-down` | Clean stop | SC-CMD-011 |
| SC-OPS-002 | Cleanup | `sa-clean` | Volumes removed | SC-CMD-012 |
| SC-OPS-003 | Status Check | `sa-status` | Container list | SC-CMD-013 |
| SC-OPS-004 | Log Debug | `sa-logs indrajaal-ex-app-1` | Streaming | SC-CMD-014 |

### L4.5 Testing Scenarios

| ID | Scenario | Steps | Expected | STAMP |
|----|----------|-------|----------|-------|
| SC-TEST-001 | Unit Tests | `test` | 0 failures | SC-CMD-008 |
| SC-TEST-002 | Runtime Tests | `sa-test` | F# tests pass | SC-CMD-018 |
| SC-TEST-003 | UX Eval | `sa-ux` | Report generated | SC-CMD-019 |
| SC-TEST-004 | Orchestrated | `sa-orchestrate swarm` | All pass | SC-CMD-020 |

### L4.6 F# Scenarios

| ID | Scenario | Steps | Expected | STAMP |
|----|----------|-------|----------|-------|
| SC-FSHARP-001 | Build | `cepaf-build` | Build OK | SC-CMD-026 |
| SC-FSHARP-002 | Deploy | `cockpitf deploy` | Deployed | SC-CMD-025 |
| SC-FSHARP-003 | Status | `cockpitf status` | Status shown | SC-CMD-025 |
| SC-FSHARP-004 | Cleanup | `cockpitf cleanup` | Cleaned | SC-CMD-025 |

---

## Level 5: Verification Matrix (L5 - Validation View)

### L5.1 STAMP Constraints (SC-CMD-*)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-CMD-001 | `app` SHALL start Phoenix on :4000 | HIGH | HTTP 200 |
| SC-CMD-002 | `app-start` SHALL start containers first | HIGH | ps check |
| SC-CMD-003 | `app-iex` SHALL provide IEx prompt | MEDIUM | TTY test |
| SC-CMD-004 | `compile` SHALL use Patient Mode | CRITICAL | Env check |
| SC-CMD-005 | `compile-strict` SHALL fail on warnings | HIGH | Warning test |
| SC-CMD-006 | `quality` SHALL run format+credo | HIGH | Output check |
| SC-CMD-007 | `quality-full` SHALL include dialyzer | HIGH | PLT check |
| SC-CMD-008 | `test` SHALL set SKIP_ZENOH_NIF=0 | CRITICAL | Env check |
| SC-CMD-009 | `test-cover` SHALL report coverage | HIGH | Report check |
| SC-CMD-010 | `sa-up` SHALL start 4 containers (prod-standalone) | CRITICAL | ps count |
| SC-CMD-011 | `sa-down` SHALL stop all containers | HIGH | ps empty |
| SC-CMD-012 | `sa-clean` SHALL remove volumes | HIGH | volume ls |
| SC-CMD-013 | `sa-status` SHALL show container status | LOW | Output |
| SC-CMD-014 | `sa-logs` SHALL stream logs | LOW | Output |
| SC-CMD-015 | `sa-db` SHALL start PostgreSQL | HIGH | Port 5433 |
| SC-CMD-016 | `sa-obs` SHALL start Grafana/Prometheus | HIGH | Ports 3000,9090 |
| SC-CMD-017 | `sa-app` SHALL start Phoenix container | HIGH | Port 4000 |
| SC-CMD-018 | `sa-test` SHALL run F# tests | HIGH | Exit 0 |
| SC-CMD-019 | `sa-ux` SHALL generate UX report | MEDIUM | Output |
| SC-CMD-020 | `sa-orchestrate` SHALL accept mode arg | MEDIUM | Args |
| SC-CMD-021 | `db-setup` SHALL create DB | HIGH | DB exists |
| SC-CMD-022 | `db-reset` SHALL drop+recreate | HIGH | Fresh DB |
| SC-CMD-023 | `db-migrate` SHALL apply migrations | HIGH | Version |
| SC-CMD-024 | `db-console` SHALL open psql | MEDIUM | Prompt |
| SC-CMD-025 | `cockpitf` SHALL execute F# script | HIGH | Exit 0 |
| SC-CMD-026 | `cepaf-build` SHALL use .NET 10 | CRITICAL | SDK check |
| SC-CMD-027 | `envelope` SHALL show capability | LOW | Output |
| SC-CMD-028 | `todo` SHALL list tasks | LOW | Output |

### L5.2 AOR Rules (AOR-CMD-*)

| ID | Rule | Description |
|----|------|-------------|
| AOR-CMD-001 | `sa-up` before `app` | Containers must run before dev server |
| AOR-CMD-002 | `compile` before `test` | Code must compile before testing |
| AOR-CMD-003 | `db-setup` before `app` | Database must exist before server |
| AOR-CMD-004 | `sa-db` before `sa-app` | DB container before app container |
| AOR-CMD-005 | `cepaf-build` before `cockpitf` | Build before run |
| AOR-CMD-006 | `quality` in CI | Always run quality before merge |
| AOR-CMD-007 | `test-cover` for GA | Coverage required for release |
| AOR-CMD-008 | `sa-clean` for fresh start | Use clean for reproducibility |

### L5.3 TDG Test Specifications

| Test ID | Command | Property | Generator |
|---------|---------|----------|-----------|
| TDG-CMD-001 | `app` | Idempotent start | N/A |
| TDG-CMD-002 | `compile` | Deterministic output | Source files |
| TDG-CMD-003 | `test` | Consistent results | Test files |
| TDG-CMD-004 | `sa-up` | Container count = 4 (prod-standalone) | N/A |
| TDG-CMD-005 | `sa-status` | Valid JSON parseable | N/A |
| TDG-CMD-006 | `db-migrate` | Monotonic versions | Migration files |
| TDG-CMD-007 | `quality` | Boolean pass/fail | Source files |

### L5.4 FMEA Analysis

| Command | Failure Mode | Effect | Severity | Detection | RPN | Mitigation |
|---------|--------------|--------|----------|-----------|-----|------------|
| `sa-up` | Image not found | Stack fails | 8 | 9 | 72 | Pre-pull images |
| `sa-up` | Port conflict | Container crash | 7 | 8 | 56 | Port check script |
| `compile` | NIF compile fail | Build blocked | 9 | 3 | 27 | Rust toolchain check |
| `compile` | OOM | Build killed | 8 | 5 | 40 | Memory limit check |
| `test` | DB not ready | Tests fail | 6 | 7 | 42 | Wait-for-db script |
| `db-setup` | Connection refused | Setup fails | 7 | 8 | 56 | Retry with backoff |
| `cockpitf` | .NET not found | Script fails | 6 | 9 | 54 | SDK version check |

### L5.5 GA Release Verification Checklist

- [ ] **L5.5.1** All 102 devenv commands tested (32 core verified)
- [ ] **L5.5.2** All custom mix tasks verified
- [ ] **L5.5.3** All container compositions valid
- [ ] **L5.5.4** All F# scripts execute
- [ ] **L5.5.5** All ports accessible
- [ ] **L5.5.6** All env variables documented
- [ ] **L5.5.7** All STAMP constraints verified
- [ ] **L5.5.8** All AOR rules enforced
- [ ] **L5.5.9** All TDG tests pass
- [ ] **L5.5.10** All FMEA mitigations in place

---

## Appendix A: Command Quick Reference

```bash
# === STARTUP ===
devenv shell          # Enter environment
sa-up                 # Start 4 containers (prod-standalone)
sa-status             # Verify running
app                   # Start Phoenix

# === DEVELOPMENT ===
compile               # Build with patience
compile-strict        # Build with warnings as errors
test                  # Run test suite
test-cover            # Run with coverage
quality               # Format + Credo
quality-full          # Full pipeline

# === DATABASE ===
db-setup              # Initialize
db-migrate            # Apply migrations
db-reset              # Drop + recreate
db-console            # psql shell

# === OPERATIONS ===
sa-down               # Stop stack
sa-clean              # Stop + remove volumes
sa-logs [svc]         # Stream logs
help                  # Command reference

# === F# COCKPIT ===
cepaf-build           # Build F# projects
cockpitf deploy       # Deploy cockpit
cockpitf status       # Check status
cockpitf test         # Run tests
cockpitf cleanup      # Clean resources

# === REPORTING ===
envelope              # Capability dashboard
todo                  # Project tasks
```

---

## Appendix B: Use Case Scenarios

### UC-001: Developer Onboarding
1. Clone repository
2. `devenv shell`
3. `sa-up`
4. `db-setup`
5. `app`
6. Access http://localhost:4000

### UC-002: Feature Development
1. `devenv shell`
2. `sa-status` (ensure stack running)
3. Edit code
4. `compile`
5. `test`
6. `quality`
7. Commit

### UC-003: CI/CD Pipeline
1. `compile-strict`
2. `test-cover`
3. `quality-full`
4. `cepaf-build`
5. `sa-test`

### UC-004: Production Debug
1. `sa-logs indrajaal-ex-app-1`
2. `db-console`
3. IEx via `app-iex`

### UC-005: Clean Environment
1. `sa-down`
2. `sa-clean`
3. `podman system prune`
4. `sa-up`

---

**Document Control**
- Author: Claude Opus 4.5
- Reviewed: Pending
- Approved: Pending for GA v21.3.0-SIL6
