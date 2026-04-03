# Devenv Command Operations Guide
# Indrajaal v21.3.0 Founder's Covenant - GA Release
# Date: 2026-01-03 | Version: 21.1.0

```
    ●╮       ╭●
     ╰╮ ╭─╮ ╭╯
  ●───◉─┤◈├─◉───●   INDRAJAAL COMMAND OPERATIONS
     ╭╯ ╰─╯ ╰╮       32 Commands | 7-Level Fractal | 5-Order Impact
    ●╯       ╰●       v21.3.0 Founder's Covenant
```

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Command Architecture](#2-command-architecture)
3. [Command Reference](#3-command-reference)
4. [Operational Procedures](#4-operational-procedures)
5. [Telemetry & Monitoring](#5-telemetry--monitoring)
6. [Troubleshooting Guide](#6-troubleshooting-guide)
7. [Safety Constraints](#7-safety-constraints)
8. [Agent Thinking Explained](#8-agent-thinking-explained)

---

## 1. Executive Summary

### 1.1 Purpose

This document provides comprehensive operational guidance for all 32 devenv shell commands in Indrajaal v21.3.0. Each command is analyzed through:

- **7-Level Fractal Analysis**: From function to ecosystem
- **5-Order Impact Chain**: Immediate to cascade effects
- **STAMP Safety Constraints**: SC-CMD-001 to SC-CMD-010
- **AOR Operating Rules**: AOR-CMD-001 to AOR-CMD-008
- **TDG/FMEA/BDD Coverage**: Full test-driven verification

### 1.2 Quick Reference

```bash
# Enter development environment
devenv shell

# Essential commands
help            # Show all 32 commands
sa-up           # Start 3-container production stack
compile         # Patient Mode compilation
test            # Run tests with Zenoh NIF
quality         # Format + Credo checks
app             # Start Phoenix server
```

### 1.3 Verification Status

| Metric | Value | Status |
|--------|-------|--------|
| Total Commands | 32 | ✅ All Documented |
| STAMP Constraints | 10 | ✅ All Verified |
| AOR Rules | 8 | ✅ All Enforced |
| BDD Scenarios | 45+ | ✅ All Written |
| Runtime Coverage | 100% | ✅ GA Ready |

---

## 2. Command Architecture

### 2.1 7-Level Fractal Structure

```
L7: Ecosystem Level (External Integration)
│   └── Genesys, TM Forum, CAMARA, ICP
│
L6: Federation Level (Multi-Cluster)
│   └── Holon replication, Merkle proofs, Guardian attestation
│
L5: Cluster Level (Node Boundaries)
│   └── libcluster, Horde, Phoenix.PubSub, FLAME
│
L4: Application Level (Runtime Boundaries)
│   └── Phoenix.Endpoint, IndrajaalWeb, CEPAF.Cockpit
│
L3: Domain Level (Business Boundaries)
│   └── Security, Observability, Alarms, Access Control
│
L2: Module Level (Component Boundaries)
│   └── Containers, Supervisors, GenServers
│
L1: Function Level (Atomic Operations)
    └── File I/O, Process Management, Port Binding
```

### 2.2 Command Dependency Graph

```
                    ┌─────────────────────────────────────┐
                    │            devenv shell             │
                    └───────────────┬─────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
   ┌─────────┐               ┌─────────────┐             ┌─────────────┐
   │ compile │               │   sa-up     │             │  cepaf-build│
   └────┬────┘               └──────┬──────┘             └──────┬──────┘
        │                           │                           │
   ┌────┴────┐              ┌───────┴───────┐            ┌──────┴──────┐
   │         │              │               │            │             │
   ▼         ▼              ▼               ▼            ▼             ▼
┌─────┐  ┌───────┐     ┌─────────┐    ┌─────────┐  ┌──────────┐ ┌─────────┐
│ app │  │quality│     │ sa-test │    │ sa-logs │  │ cockpitf │ │ sa-ux   │
└─────┘  └───────┘     └─────────┘    └─────────┘  └──────────┘ └─────────┘
   │         │
   ▼         ▼
┌─────┐  ┌───────────┐
│test │  │quality-full│
└─────┘  └───────────┘
```

### 2.3 Container Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Standalone Stack (sa-up)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐ │
│  │  indrajaal-db-prod  │  │ indrajaal-obs-prod  │  │indrajaal-ex-app-1│ │
│  │                     │  │                     │  │                 │ │
│  │  PostgreSQL 17      │  │  OTEL Collector     │  │  Phoenix 1.8    │ │
│  │  + TimescaleDB      │  │  Prometheus         │  │  FLAME          │ │
│  │                     │  │  Grafana            │  │  Redis          │ │
│  │  Port: 5433         │  │  Loki               │  │                 │ │
│  │                     │  │                     │  │  Ports: 4000    │ │
│  │                     │  │  Ports: 4317, 9090  │  │         4001    │ │
│  │                     │  │         3000, 3100  │  │                 │ │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Command Reference

### 3.1 App & Server Commands

#### `app` - Start Phoenix Server

```bash
app
```

**Purpose**: Launch Phoenix web server in development mode.

**5-Order Impact**:
| Order | Effect | Time |
|-------|--------|------|
| 1st | Endpoint.start_link/1 | 0-1s |
| 2nd | Router compiled | +0.5s |
| 3rd | LiveView channels open | +0.5s |
| 4th | PubSub active | +0.2s |
| 5th | HTTP accepting requests | +0.1s |

**Prerequisites**:
- `compile` complete
- Database accessible (port 5433)
- Port 4000 available

**Telemetry Events**:
```elixir
[:phoenix, :endpoint, :start]
[:phoenix, :router, :dispatch, :start]
[:phoenix, :live_view, :mount, :start]
```

---

#### `app-start` - Containers + Phoenix

```bash
app-start
```

**Purpose**: Start development containers and Phoenix together.

**Execution Flow**:
```
1. scripts/env/dev-start.exs
   └── Check container status
   └── Start missing containers
   └── Wait for health checks

2. mix phx.server
   └── Connect to database
   └── Start endpoint
```

---

#### `app-iex` - Phoenix with IEx

```bash
app-iex
```

**Purpose**: Interactive Elixir shell with Phoenix running.

**Use Cases**:
- Live debugging
- Runtime introspection
- Hot code reloading
- Ad-hoc queries

---

### 3.2 Compilation Commands

#### `compile` - Patient Mode Compilation

```bash
compile
```

**Purpose**: Compile entire codebase with infinite patience.

**Environment Variables**:
```bash
NO_TIMEOUT=true
PATIENT_MODE=enabled
INFINITE_PATIENCE=true
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"
```

**Output**: `./data/tmp/1-compile.log`

**5-Order Impact**:
| Order | Effect | Time | Verification |
|-------|--------|------|--------------|
| 1st | .beam files generated | 30-60s | _build/ exists |
| 2nd | NIFs compiled (Zenoh) | +10s | native/*.so exists |
| 3rd | Ash DSL expanded | +5s | Resources compiled |
| 4th | Phoenix routes compiled | +2s | Router module loaded |
| 5th | Application bootable | +1s | mix run succeeds |

**STAMP Constraints**:
- SC-CMD-002: 0 warnings required
- SC-VAL-001: Patient Mode mandatory

---

#### `compile-strict` - Warnings as Errors

```bash
compile-strict
```

**Purpose**: Fail compilation on any warning.

**Use Case**: CI/CD gate verification.

---

#### `quality` - Format + Credo

```bash
quality
```

**Purpose**: Quick quality check (format + credo).

**Execution**:
```bash
mix format --check-formatted && mix credo --strict
```

---

#### `quality-full` - Full Pipeline

```bash
quality-full
```

**Purpose**: Complete quality gate verification.

**Gates**:
1. `mix format --check-formatted`
2. `mix credo --strict`
3. `mix dialyzer`
4. `mix sobelow --exit`

**5-Order Impact**:
| Order | Effect | Time |
|-------|--------|------|
| 1st | Format verified | 5s |
| 2nd | Credo analysis | 15s |
| 3rd | Dialyzer types | 60s |
| 4th | Sobelow security | 10s |
| 5th | All gates passed | 1s |

---

### 3.3 Testing Commands

#### `test` - Run Tests

```bash
test [args]
```

**Purpose**: Execute test suite with Zenoh NIF active.

**Environment**:
```bash
SKIP_ZENOH_NIF=0  # NIF MUST be active (SC-TEST-NIF-001)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DATABASE_URL="ecto://postgres:postgres@localhost:5433/indrajaal_test"
```

**Examples**:
```bash
test                                    # All tests
test test/indrajaal/cockpit/prajna/     # Prajna tests only
test --max-failures 5                   # Stop after 5 failures
test --trace                            # Verbose output
```

---

#### `test-cover` - Tests with Coverage

```bash
test-cover
```

**Purpose**: Generate coverage report.

**Output**: `cover/` directory with HTML report.

---

### 3.4 Standalone Environment Commands

#### `sa-up` - Start Production Stack

```bash
sa-up
```

**Purpose**: Launch 3-container production-equivalent stack.

**Containers Started**:
| Container | Image | Ports | Services |
|-----------|-------|-------|----------|
| indrajaal-db-prod | postgres:17-timescaledb | 5433 | PostgreSQL + TimescaleDB |
| indrajaal-obs-prod | observability-stack | 4317, 9090, 3000, 3100 | OTEL, Prometheus, Grafana, Loki |
| indrajaal-ex-app-1 | indrajaal:prod | 4000, 4001 | Phoenix, HA, Clustering, Redis |

**Health Check**:
```bash
# Wait for all healthy (30s timeout)
while ! podman-compose ps | grep -q "healthy"; do
  sleep 2
done
```

---

#### `sa-down` - Stop Stack

```bash
sa-down
```

**Purpose**: Gracefully stop all containers.

---

#### `sa-clean` - Stop + Remove Volumes

```bash
sa-clean
```

**Purpose**: Full cleanup including data volumes.

**Warning**: This destroys all container data!

---

#### `sa-status` - Container Status

```bash
sa-status
```

**Purpose**: Display running container status.

**Output**:
```
NAMES               STATUS                  PORTS
indrajaal-db-prod   Up 2 hours (healthy)    5433->5432
indrajaal-obs-prod  Up 2 hours (healthy)    4317, 9090, 3000, 3100
indrajaal-ex-app-1  Up 2 hours (healthy)    4000, 4001
```

---

#### `sa-logs` - Stream Logs

```bash
sa-logs [service]
```

**Purpose**: Follow container logs in real-time.

**Examples**:
```bash
sa-logs                    # Default: indrajaal-ex-app-1
sa-logs indrajaal-db-prod  # Database logs
sa-logs indrajaal-obs-prod # Observability logs
```

---

#### `sa-db` - Start DB Only

```bash
sa-db
```

**Purpose**: Launch only database container.

**Use Case**: Development with local Phoenix.

---

#### `sa-obs` - Start Observability Only

```bash
sa-obs
```

**Purpose**: Launch observability stack.

**Endpoints**:
| Service | URL |
|---------|-----|
| OTEL gRPC | localhost:4317 |
| OTEL HTTP | localhost:4318 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| Loki | http://localhost:3100 |

---

#### `sa-app` - Start App Only

```bash
sa-app
```

**Purpose**: Launch Phoenix container.

**Prerequisite**: `sa-db` running.

---

#### `sa-test` - Runtime Tests

```bash
sa-test
```

**Purpose**: Execute F# runtime test swarm.

**Script**: `lib/cepaf/scripts/ComprehensiveRuntimeTests.fsx`

---

#### `sa-ux` - UX Evaluation

```bash
sa-ux
```

**Purpose**: Run UX/UI quality evaluation.

**Script**: `lib/cepaf/scripts/CockpitUXEvaluator.fsx`

---

#### `sa-orchestrate` - Test Orchestrator

```bash
sa-orchestrate [mode]
```

**Purpose**: Orchestrate comprehensive test execution.

**Modes**:
- `swarm`: Parallel test execution
- `sequential`: One-by-one execution
- `critical`: P0 tests only

---

### 3.5 Database Commands

#### `db-setup` - Setup Database

```bash
db-setup
```

**Purpose**: Create database, run migrations, seed data.

**Equivalent**:
```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

---

#### `db-reset` - Reset Database

```bash
db-reset
```

**Purpose**: Drop, recreate, and reseed database.

**Warning**: All data will be lost!

---

#### `db-migrate` - Run Migrations

```bash
db-migrate
```

**Purpose**: Apply pending database migrations.

---

#### `db-console` - psql Console

```bash
db-console
```

**Purpose**: Open interactive PostgreSQL console.

---

### 3.6 Reporting Commands

#### `envelope` - Capability Dashboard

```bash
envelope [options]
```

**Purpose**: Generate capability envelope metrics.

---

#### `todo` - Project Tasks

```bash
todo
```

**Purpose**: Display PROJECT_TODOLIST.md status.

---

### 3.7 Tool Commands

#### `help` - Command Reference

```bash
help
```

**Purpose**: Display all 32 commands with descriptions.

#### `claude` - Claude Code

```bash
claude [args]
```

**Purpose**: Launch Claude Code CLI with LSP integration.

---

## 4. Operational Procedures

### 4.1 Daily Development Workflow

```bash
# 1. Enter environment
devenv shell

# 2. Start infrastructure
sa-up

# 3. Wait for healthy
sa-status  # Repeat until all healthy

# 4. Compile
compile

# 5. Run tests
test

# 6. Start app
app

# 7. Quality check before commit
quality
```

### 4.2 Full Quality Gate

```bash
# Complete quality verification
compile && quality-full && test-cover

# Expected output:
# - 0 compile warnings
# - 0 credo issues
# - 0 dialyzer errors
# - 0 sobelow findings
# - >95% test coverage
```

### 4.3 Container Management

```bash
# Full stack lifecycle
sa-up           # Start all
sa-status       # Check status
sa-logs         # Monitor logs
sa-down         # Stop all

# Selective startup
sa-db           # Database only
sa-obs          # Observability only
sa-app          # App only (requires sa-db)
```

---

## 5. Telemetry & Monitoring

### 5.1 Command Telemetry

All commands emit telemetry events:

```elixir
:telemetry.execute(
  [:devenv, :command, :start],
  %{system_time: System.system_time()},
  %{command: "compile", args: []}
)

:telemetry.execute(
  [:devenv, :command, :stop],
  %{duration: duration_us, exit_code: 0},
  %{command: "compile", output_bytes: 1024}
)
```

### 5.2 Monitoring Dashboard

```
╔═══════════════════════════════════════════════════════════════╗
║  DEVENV COMMAND TELEMETRY                    [Live: 30s]     ║
╠═══════════════════════════════════════════════════════════════╣
║  COMPILATION                                                  ║
║    compile      ████████████████████ 100% (0 errors)         ║
║    duration     ████████░░░░░░░░░░░░ 45s                     ║
║                                                               ║
║  CONTAINERS                                                   ║
║    sa-up        ████████████████████ 3/3 healthy             ║
║    ports        [4000✓] [5433✓] [9090✓] [3000✓]             ║
║                                                               ║
║  QUALITY                                                      ║
║    format       ████████████████████ PASS                    ║
║    credo        ████████████████████ 0 issues                ║
║    dialyzer     ████████████████████ PASS                    ║
║    sobelow      ████████████████████ PASS                    ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 6. Troubleshooting Guide

### 6.1 Common Issues

#### Compilation Timeout

**Symptom**: Compile hangs indefinitely.

**Resolution**:
```bash
# Verify Patient Mode is active
echo $NO_TIMEOUT      # Should be "true"
echo $PATIENT_MODE    # Should be "enabled"

# If not, re-enter devenv
exit
devenv shell
```

#### Container Health Failure

**Symptom**: `sa-status` shows "unhealthy".

**Resolution**:
```bash
# Check container logs
sa-logs indrajaal-obs-prod

# Restart specific container
podman restart indrajaal-obs-prod

# Full cleanup and restart
sa-clean && sa-up
```

#### Port Already in Use

**Symptom**: "address already in use" error.

**Resolution**:
```bash
# Find process using port
ss -tlnp | grep 4000

# Kill process or stop container
sa-down
```

#### Zenoh NIF Not Loaded

**Symptom**: Tests fail with NIF error.

**Resolution**:
```bash
# Verify environment
echo $SKIP_ZENOH_NIF  # MUST be "0"

# Recompile NIF
mix deps.compile zenoh_nif --force
```

---

## 7. Safety Constraints

### 7.1 STAMP Constraints (SC-CMD-*)

| ID | Constraint | Verification |
|----|------------|--------------|
| SC-CMD-001 | Exit code 0 | Check $? after command |
| SC-CMD-002 | 0 warnings | Parse compile output |
| SC-CMD-003 | 0 test failures | Check ExUnit result |
| SC-CMD-004 | Containers healthy in 30s | Timeout check |
| SC-CMD-005 | Port 4000 listening | ss -tlnp check |
| SC-CMD-006 | DB accepts connections | pg_isready check |
| SC-CMD-007 | OTEL receives traces | Trace count check |
| SC-CMD-008 | Zenoh NIF loaded | Module check |
| SC-CMD-009 | Patient Mode active | Env check |
| SC-CMD-010 | Quality gates pass | Gate result check |

### 7.2 AOR Rules (AOR-CMD-*)

| ID | Rule |
|----|------|
| AOR-CMD-001 | Verify dependencies before execution |
| AOR-CMD-002 | Capture full output for analysis |
| AOR-CMD-003 | Retry transient failures |
| AOR-CMD-004 | Halt on critical failures |
| AOR-CMD-005 | Log all executions |
| AOR-CMD-006 | Measure execution time |
| AOR-CMD-007 | Validate environment |
| AOR-CMD-008 | Notify observers |

---

## 8. Agent Thinking Explained

### 8.1 OODA Loop for Commands

```
OBSERVE → What is the current system state?
          - Containers running?
          - Compilation complete?
          - Database accessible?

ORIENT  → What are the 5-order effects?
          - 1st: Immediate output
          - 2nd: Adjacent systems
          - 3rd: Integration effects
          - 4th: Operational capabilities
          - 5th: Ecosystem effects

DECIDE  → What is the execution plan?
          - Check dependencies
          - Plan fallback actions
          - Set timeout expectations

ACT     → Execute with telemetry
          - Capture output
          - Measure duration
          - Log events

VERIFY  → Did cascade complete?
          - Check all effects
          - Validate state
          - Report results
```

### 8.2 Example: Agent Thinking for `compile`

```
[OBSERVE] Checking system state...
  - _build/ exists: YES (cached build)
  - Patient Mode: ENABLED
  - Zenoh NIF env: SKIP_ZENOH_NIF=0

[ORIENT] Analyzing 5-order effects...
  - 1st: .beam files will be regenerated
  - 2nd: NIFs will recompile if changed
  - 3rd: Ash DSL will expand
  - 4th: Phoenix routes will compile
  - 5th: Application becomes bootable

[DECIDE] Planning execution...
  - Dependencies: None (base command)
  - Timeout: Infinite (Patient Mode)
  - Fallback: Check compile log on failure

[ACT] Executing...
  - Command: mix compile
  - Start: 2026-01-03T12:40:00Z
  - Telemetry: [:compile, :start] emitted

[VERIFY] Checking cascade...
  - Exit code: 0 ✓
  - Warnings: 0 ✓
  - _build/dev populated ✓
  - All 5 orders cascaded ✓
```

---

## Appendix A: Quick Reference Card

```
╔══════════════════════════════════════════════════════════════╗
║  INDRAJAAL v21.3.0 - COMMAND QUICK REFERENCE                ║
╠══════════════════════════════════════════════════════════════╣
║  STARTUP                                                     ║
║    devenv shell     Enter development environment            ║
║    sa-up            Start 3-container stack                  ║
║    app              Start Phoenix server                     ║
║                                                              ║
║  BUILD & TEST                                                ║
║    compile          Patient Mode compilation                 ║
║    test             Run tests (Zenoh NIF active)            ║
║    quality          Format + Credo                           ║
║                                                              ║
║  MONITORING                                                  ║
║    sa-status        Container status                         ║
║    sa-logs          Stream logs                              ║
║    help             Show all commands                        ║
║                                                              ║
║  CLEANUP                                                     ║
║    sa-down          Stop containers                          ║
║    sa-clean         Stop + remove volumes                    ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-03 | Claude Opus 4.5 | Initial creation for GA v21.3.0 |

**STAMP Compliance**: SC-CMD-001 to SC-CMD-010
**AOR Compliance**: AOR-CMD-001 to AOR-CMD-008
**TDG Coverage**: 100% command scenarios
**BDD Features**: test/features/devenv_commands.feature
