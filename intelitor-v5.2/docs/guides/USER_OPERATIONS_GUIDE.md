# Indrajaal User Operations Guide
**Version**: 21.3.0-SIL6 | **Updated**: 2026-01-11
**Framework**: SIL-6 Biomorphic Fractal Mesh | **Compliance**: IEC 61508 SIL-6, ISO 27001

---

## 1.0 Quick Start

```bash
# Enter development environment
devenv shell

# Start the entire system (4 containers)
sa-up

# Check system status
sa-status

# View help for all commands
help
```

---

## 2.0 System Architecture Overview

### 2.1 Container Stack (4-Container Production)

| Container | Ports | Services | Purpose |
|-----------|-------|----------|---------|
| **zenoh-router** | 7447 | Zenoh Router | Control plane |
| **indrajaal-db-prod** | 5433 | PostgreSQL 17 + TimescaleDB | Database layer |
| **indrajaal-obs-prod** | 4317, 4318, 9090, 3000, 3100 | OTEL + Prometheus + Grafana + Loki | Observability |
| **indrajaal-ex-app-1** | 4000, 4001, 6379 | Phoenix + HA + Clustering + Redis | Application |

### 2.2 Fractal Layers (L0-L7)

| Layer | Name | Description |
|-------|------|-------------|
| L0 | Runtime | BEAM VM, processes, schedulers |
| L1 | Function | Individual function execution |
| L2 | Component | Module-level organization |
| L3 | Holon | Agent/GenServer patterns |
| L4 | Container | Docker/Podman isolation |
| L5 | Node | Single Erlang node |
| L6 | Cluster | Multi-node coordination |
| L7 | Federation | Cross-organization mesh |

---

## 3.0 System Startup Commands

### 3.1 Primary Startup (Recommended)

```bash
# Enter devenv environment first (required)
devenv shell

# Start complete SIL-6 Biomorphic mesh with 5-stage boot
sa-up
```

**Boot Stages**:
1. **Preflight** - Port availability, image verification
2. **Ignition** - Container launch, network binding
3. **Lens** - Health check initialization, OTEL binding
4. **Convergence** - Inter-container communication
5. **Ready** - Mesh operational, TUI available

### 3.2 Partial Startup Options

```bash
# Start only database
sa-db

# Start only observability stack
sa-obs

# Start only application container
sa-app

# Start Phoenix server (requires db + containers)
app

# Start containers + Phoenix together
app-start

# Start Phoenix with IEx console for debugging
app-iex
```

### 3.3 SIL-6 Biomorphic Mesh (Full Cluster)

```bash
# Boot full SIL-6 biomorphic mesh (15 containers, 4-node Zenoh)
sa-mesh-boot

# Boot with specific mode
sa-mesh boot --mode cluster

# Check mesh status
sa-mesh-status
```

---

## 4.0 System Shutdown Commands

### 4.1 Graceful Shutdown (Recommended)

```bash
# Graceful shutdown with checkpointing
sa-down
```

**Shutdown Stages**:
1. Notify all services of pending shutdown
2. Drain active connections
3. Checkpoint state to DuckDB
4. Stop containers gracefully
5. Verify clean termination

### 4.2 Emergency Shutdown

```bash
# Emergency stop < 5 seconds (SC-EMR-057)
sa-emergency

# Emergency with reason logged
sa-emergency --reason "critical failure"
```

### 4.3 Cleanup Commands

```bash
# Clean containers (preserve data/kms/)
sa-clean

# Nuclear clean - remove everything including volumes
sa-scour

# Preflight cleanup (port substrate isolation)
sa-scour
```

---

## 5.0 System Status & Monitoring

### 5.1 Status Commands

```bash
# Quick container status
sa-status

# Detailed status with verbose output
sa-status --verbose

# JSON output for scripting
sa-status --json

# Health check with FPPS 5-point consensus
sa-health

# Deep health check
sa-health --deep
```

### 5.2 Log Access

```bash
# Stream logs from app container (default)
sa-logs

# Stream logs from specific container
sa-logs indrajaal-db-prod
sa-logs indrajaal-obs-prod
sa-logs indrajaal-ex-app-1

# Follow logs in real-time
podman logs -f indrajaal-ex-app-1
```

### 5.3 Monitoring Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| **Phoenix App** | http://localhost:4000 | - |
| **Prajna Cockpit** | http://localhost:4000/prajna | - |
| **AI Copilot** | http://localhost:4000/prajna/copilot | - |
| **Grafana** | http://localhost:3000 | admin/indrajaal |
| **Prometheus** | http://localhost:9090 | - |
| **Loki** | http://localhost:3100 | - |
| **Health Endpoint** | http://localhost:4001/health | - |

### 5.4 Biomorphic Dashboard

```bash
# Launch biomorphic monitoring dashboard
sa-dashboard

# Alternative
sa-monitor
```

---

## 6.0 Compilation & Quality Commands

### 6.1 Compilation

```bash
# Standard compile with Patient Mode + 16 schedulers
compile

# Strict compile (warnings as errors)
compile-strict

# Profiled compile with timing metrics
compile-profile

# Dependency graph analysis
compile-xref
```

**Environment Variables (Auto-Set)**:
- `NO_TIMEOUT=true`
- `PATIENT_MODE=enabled`
- `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"`
- `MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8`

### 6.2 Quality Gates

```bash
# Quick quality check (format + credo)
quality

# Full quality pipeline
quality-full
# Runs: format → credo → dialyzer → sobelow
```

---

## 7.0 Testing Commands

### 7.1 Test Execution

```bash
# Run all tests (NIF active, 16 schedulers)
test

# Run specific test file
test test/indrajaal/alarms/alarm_test.exs

# Run tests matching pattern
test --only property

# Run with coverage report
test-cover
```

**Environment Variables (Auto-Set)**:
- `SKIP_ZENOH_NIF=0` (NIF active)
- `MIX_ENV=test`
- `DATABASE_URL=ecto://postgres:postgres@localhost:5433/indrajaal_test`

### 7.2 Runtime Tests (F#)

```bash
# Run F# runtime test orchestrator
sa-test

# Run in swarm mode
sa-test --mode swarm

# Run UX/UI evaluation
sa-ux

# Full test orchestration
sa-orchestrate
```

### 7.3 Specialized Tests

```bash
# Observability test (OTEL + Prometheus + Grafana)
sa-test-obs

# Change control test (checkpoint + restore)
sa-test-cc

# Multiverse test (shadow universe forking)
sa-test-mv

# Zenoh mesh test
sa-test-zenoh

# Container agents test
sa-test-agents
```

---

## 8.0 Database Commands

```bash
# Setup database (create + migrate)
db-setup

# Reset database (drop + recreate + migrate)
db-reset

# Run pending migrations
db-migrate

# Open psql console
db-console
```

---

## 9.0 Checkpoint & Recovery

### 9.1 Creating Checkpoints

```bash
# Create full checkpoint (4-phase)
sa-checkpoint full

# Create specific phase checkpoint
sa-checkpoint 1   # Phase 1: File/KMS/Git
sa-checkpoint 2   # Phase 2: CRIU container state
sa-checkpoint 3   # Phase 3: Chandy-Lamport distributed
sa-checkpoint 4   # Phase 4: Multiverse verification

# Named checkpoint
sa-checkpoint manual
```

### 9.2 Verification & Restore

```bash
# Verify checkpoint integrity (46-test suite)
sa-checkpoint-verify

# List available checkpoints
sa-checkpoint-list

# Restore from checkpoint
sa-checkpoint-restore latest
sa-checkpoint-restore manual-20260111-1200
```

### 9.3 Shadow Universe (Multiverse)

```bash
# Fork shadow universe for testing
sa-fork shadow-test

# List checkpoints/forks
sa-restore
```

---

## 10.0 CEPAF / F# Cockpit

### 10.1 F# Build & Deploy

```bash
# Build all F# projects
cepaf-build

# Cockpit operations
cockpitf deploy   # Deploy cockpit
cockpitf status   # Check status
cockpitf test     # Run F# tests
cockpitf cleanup  # Clean artifacts
```

### 10.2 Mesh Control

```bash
# Control specific container
sa-control indrajaal-ex-app-1 status
sa-control indrajaal-ex-app-1 restart

# Monitor Zenoh container agents
sa-agents
```

---

## 11.0 Verification Commands

```bash
# 2oo3 voting verification (production actuations)
sa-verify

# 5-order effects verification
sa-verify --action deploy
```

**2oo3 Voters**:
1. **Live Node** - Actual container response
2. **Shadow Node** - Parallel validation container
3. **Formal Model** - Expected behavior specification

---

## 12.0 Project Management

```bash
# Show project tasks
todo

# Generate capability envelope dashboard
envelope

# Export envelope as JSON
envelope-json

# Save to journal
envelope-journal

# Show all available commands
help
```

---

## 13.0 Script Categories Inventory

### 13.1 SOPv5.11 Deployment Phases (147 scripts)

| Phase | Script | Purpose |
|-------|--------|---------|
| 1 | `phase_1_environment_setup.exs` | Environment preparation |
| 2 | `phase_2_container_deployment.exs` | Container orchestration |
| 3 | `phase_3_agent_architecture.exs` | 50-agent deployment |
| 4 | `phase_4_phics_integration.exs` | Hot-reload integration |
| 5 | `phase_5_compilation_setup.exs` | Compilation environment |
| 6 | `phase_6_monitoring_observability.exs` | Telemetry setup |
| 7 | `phase_7_security_compliance.exs` | Security hardening |

**Location**: `scripts/sopv511/`

### 13.2 Testing Scripts (107 scripts)

| Category | Pattern | Purpose |
|----------|---------|---------|
| TDG | `tdg_*.exs` | Test-Driven Generation |
| Container | `container_*.exs` | Health validation |
| Demo | `demo_*.exs` | Feature demonstrations |
| Coverage | `*coverage*.exs` | Test coverage analysis |
| STAMP | `stamp_*.exs` | Safety constraint validation |

**Location**: `scripts/testing/`

### 13.3 Demo Scripts (56 scripts)

| Domain | Script | Purpose |
|--------|--------|---------|
| Alarms | `alarms_enterprise_demo.exs` | Alarm workflows |
| Accounts | `accounts_enterprise_demo.exs` | User management |
| Access | `access_control_enterprise_demo.exs` | RBAC demo |
| Analytics | `analytics_enterprise_demo.exs` | Reporting |
| Compliance | `compliance_enterprise_demo.exs` | Audit/SLA |

**Location**: `scripts/demo/`

### 13.4 F# Scripts (14 scripts)

| Script | Purpose |
|--------|---------|
| `RuntimeTestOrchestrator.fsx` | Test orchestration |
| `CockpitUXEvaluator.fsx` | UX evaluation |
| `SIL6Orchestrator.fsx` | SIL-6 Biomorphic compliance |
| `SIL6MeshOrchestrator.fsx` | SIL-6 biomorphic mesh |
| `ComprehensiveRuntimeTests.fsx` | Integration tests |
| `KmsSil4Verification.fsx` | KMS verification |

**Location**: `lib/cepaf/scripts/`

---

## 14.0 Typical Workflows

### 14.1 Development Workflow

```bash
# Start environment
devenv shell

# Start containers
sa-up

# Make code changes
# ...

# Compile
compile

# Run tests
test

# Quality check
quality

# Shutdown
sa-down
```

### 14.2 Production Deployment

```bash
devenv shell

# Create checkpoint before deployment
sa-checkpoint full

# Verify checkpoint
sa-checkpoint-verify

# Deploy changes
sa-down
sa-up

# Verify deployment
sa-health
sa-verify

# Monitor
sa-dashboard
```

### 14.3 Emergency Recovery

```bash
# Emergency stop
sa-emergency --reason "critical issue"

# Clean environment
sa-scour --confirm

# Restore from checkpoint
sa-checkpoint-restore latest

# Verify
sa-health
```

### 14.4 Full GA Verification

```bash
devenv shell

# 1. Start mesh
sa-up

# 2. Compile verification
compile-strict

# 3. Quality gates
quality-full

# 4. Test with coverage
test-cover

# 5. F# verification
cepaf-build
cockpitf test

# 6. Runtime tests
sa-test --mode swarm

# 7. 2oo3 verification
sa-verify

# 8. Shutdown
sa-down
```

---

## 15.0 Troubleshooting

### 15.1 Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Port conflict | Another service using ports | `sa-clean && sa-up` |
| Container not starting | Image missing | Check `podman images` |
| Database connection | DB not running | `sa-db` first |
| Compilation timeout | Patient mode not set | Use `devenv shell` |
| Test failures | NIF not loaded | Ensure `SKIP_ZENOH_NIF=0` |

### 15.2 Debug Commands

```bash
# Check container status
podman ps -a

# Check port bindings
ss -tlnp | grep -E "(4000|5433|4317|9090)"

# Check logs
sa-logs indrajaal-ex-app-1

# Check compilation log
cat ./data/tmp/1-compile.log

# Check database connection
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "SELECT 1"
```

### 15.3 Recovery Procedures

```bash
# If containers won't start
sa-scour
sa-up

# If compilation fails
rm -rf _build deps
compile

# If tests hang
sa-emergency
sa-clean
sa-up
```

---

## 16.0 STAMP Constraints Reference

### 16.1 Key Operating Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SIL6-001 | 5-stage boot mandatory | CRITICAL |
| SC-SIL6-002 | Checkpoint before shutdown | HIGH |
| SC-SIL6-005 | FPPS consensus for health | HIGH |
| SC-SIL6-006 | 2oo3 voting for production | CRITICAL |
| SC-EMR-057 | Emergency stop < 5s | CRITICAL |
| SC-HOLON-001 | SQLite/DuckDB for state | CRITICAL |
| SC-TEST-005 | SKIP_ZENOH_NIF=0 mandatory | HIGH |
| SC-METRICS-003 | 16 schedulers for compile | HIGH |

### 16.2 AOR Rules Reference

| ID | Rule |
|----|------|
| AOR-MESH-001 | Use `sa-up` for all mesh operations |
| AOR-MESH-002 | Checkpoint before shutdown |
| AOR-MESH-003 | 2oo3 consensus in production |
| AOR-TEST-NIF-001 | All tests with NIF active |
| AOR-FUNC-001 | Verify compilation before commit |

---

## 17.0 Related Documentation

| Document | Location |
|----------|----------|
| SIL-6 Biomorphic Mesh CLI Guide | `docs/guides/SIL6_MESH_CLI_USER_GUIDE.md` |
| SOPv5.11 Operations | `docs/guides/sopv511_operations_manual.md` |
| Deployment Guide | `docs/guides/sopv511_deployment_guide.md` |
| Troubleshooting | `docs/guides/sopv511_troubleshooting_guide.md` |
| Testing Framework | `docs/guides/comprehensive-testing-rules.md` |
| CLAUDE.md | Root specification |
| GEMINI.md | AI Architecture specification |

---

**Document Control**
| Field | Value |
|-------|-------|
| Version | 21.3.0-SIL6 |
| Created | 2026-01-11 |
| Author | Claude Opus 4.5 |
| STAMP | SC-GA-001 to SC-GA-010 |
| Compliance | IEC 61508 SIL-6, ISO 27001 |
