# SIL-6 Biomorphic Mesh Operational Runbook
**Version**: 21.1.0-BEP-V1
**Date**: 2026-01-05
**Compliance**: SC-SIL6-*, AOR-MESH-*, IEC 61508

---

## 0.0 Quick Start - Your Intelligent Operations Partner

**Indrajaal works WITH you, not just FOR you.** Here's how to think about it:

### The Conversation Model

Think of operating Indrajaal like talking to a trusted colleague:

| You Say | Command | Indrajaal Does |
|---------|---------|----------------|
| "Let's start working" | `sa-up` | Wakes up all systems in safe order |
| "How's everything?" | `sa-status` | Reports health of all components |
| "Check yourself thoroughly" | `sa-health` | Runs 5 independent diagnostic tests |
| "We're done for today" | `sa-down` | Saves state and shuts down safely |
| "Something's very wrong!" | `sa-emergency` | Stops everything in <5 seconds |

### Trust Indicators

When Indrajaal shows you status, look for these indicators:

| Indicator | Meaning | Action |
|-----------|---------|--------|
| **Healthy** / Green | All systems normal | Continue working |
| **Degraded** / Yellow | Some issues, still functional | Investigate with `sa-health` |
| **Unhealthy** / Red | System needs attention | Run `sa-clean && sa-up` |
| **Quorum: 3/3** | All voters agree | Full confidence |
| **Quorum: 2/3** | Majority agrees | Investigate the outlier |

### The Safety Promise

1. **Your data is always protected** - `sa-clean` preserves `data/kms/`
2. **No silent failures** - 5 independent methods check everything
3. **No rogue actions** - 2-out-of-3 voting prevents mistakes
4. **Emergency always works** - `sa-emergency` has <5s guarantee

### When In Doubt

```bash
sa-status      # First, check what's happening
sa-health      # If status looks bad, go deeper
sa-clean       # If health fails, clean slate
sa-up          # Fresh start with your data intact
```

---

## 1.0 Overview

This runbook provides operational procedures for the Panopticon SIL-6 Biomorphic Fractal Mesh. It covers:
- Daily operations
- Emergency response
- Health monitoring
- Apoptosis recovery

### 1.1 Operator Prerequisites

| Requirement | Verification |
|-------------|--------------|
| `devenv shell` active | `which sa-up` returns path |
| Podman 5.4.1+ | `podman --version` |
| .NET 10.0 | `dotnet --version` |
| Port 4000, 5433, 4317 available | `ss -tlnp` |

---

## 2.0 Daily Operations

### 2.1 Morning Startup Procedure

```bash
# 1. Enter development environment
devenv shell

# 2. Verify no orphan containers
sa-status
# If containers exist from previous session:
sa-down

# 3. Start fresh mesh
sa-up

# 4. Verify health
sa-health

# 5. Check 2oo3 consensus (production)
sa-verify
```

### 2.2 End-of-Day Shutdown

```bash
# 1. Verify all work is committed
git status

# 2. Graceful shutdown with checkpoint
sa-down

# 3. Verify clean termination
podman ps -a | grep indrajaal
# Should return empty

# 4. Optional: Clean containers (preserves data/kms/)
sa-clean
```

### 2.3 Health Check Procedure

```bash
# Quick health check
sa-status

# Detailed FPPS 5-point validation
sa-health

# Expected output:
# ╔═══════════════════════════════════════════════════════════════╗
# ║  PANOPTICON SIL-6 Biomorphic MESH STATUS           [TIMESTAMP]           ║
# ╠═══════════════════════════════════════════════════════════════╣
# ║  Container        │ Status  │ Health  │ Ports                 ║
# ║  indrajaal-app    │ Running │ Healthy │ 4000, 4001            ║
# ║  indrajaal-db     │ Running │ Healthy │ 5433                  ║
# ║  indrajaal-obs    │ Running │ Healthy │ 4317, 3000, 9090      ║
# ╠═══════════════════════════════════════════════════════════════╣
# ║  Mesh State: OPERATIONAL                                      ║
# ║  Quorum: 3/3 (100%)                                           ║
# ║  FPPS: 5/5 methods passing                                    ║
# ╚═══════════════════════════════════════════════════════════════╝
```

---

## 3.0 Emergency Response Procedures

### 3.1 Emergency Stop (SC-EMR-057)

**When to Use**: System unresponsive, critical failure, security breach

```bash
# Force stop within 5 seconds
sa-emergency --reason "critical failure"

# Verify termination
podman ps -a | grep indrajaal
```

**STAMP Constraint**: SC-EMR-057 - Emergency stop < 5 seconds

### 3.2 Apoptosis Recovery (6-Phase)

The Apoptosis protocol provides controlled self-destruction:

| Phase | Action | Duration |
|-------|--------|----------|
| 1. Initiated | Guardian approval | Immediate |
| 2. Notifying | Alert federation | 1-5s |
| 3. Draining | Close connections | 5-30s |
| 4. Checkpointing | Save state to DuckDB | 10-60s |
| 5. Terminating | Stop containers | 5-10s |
| 6. Terminated | Clean exit | Immediate |

**Recovery Procedure**:

```bash
# 1. Check for checkpoint files
ls -la data/kms/

# 2. Verify telemetry.duckdb integrity
du -h data/kms/telemetry.duckdb

# 3. Start fresh mesh
sa-up

# 4. Verify state restored
sa-health
```

### 3.3 Container Failure Recovery

| Failure Mode | Detection | Recovery |
|--------------|-----------|----------|
| indrajaal-app down | Port 4000 unreachable | `sa-up` |
| indrajaal-db down | Port 5433 unreachable | `sa-db` then `sa-up` |
| indrajaal-obs down | Port 4317 unreachable | `sa-obs` then `sa-up` |
| All containers down | `sa-status` shows 0 | `sa-clean && sa-up` |

---

## 4.0 Health Monitoring

### 4.1 FPPS 5-Method Validation

| Method | Purpose | Check Command |
|--------|---------|---------------|
| Pattern | Regex response validation | `sa-health --method pattern` |
| AST | Structural analysis | `sa-health --method ast` |
| Statistical | Latency/throughput | `sa-health --method statistical` |
| Binary | Checksum verification | `sa-health --method binary` |
| LineByLine | Exact comparison | `sa-health --method linebyline` |

### 4.2 2oo3 Voting Verification

```bash
# Production actuations require 2-out-of-3 consensus
sa-verify

# Voters:
# 1. Live Node - Actual container response
# 2. Shadow Node - Parallel validation
# 3. Formal Model - Expected behavior
```

### 4.3 Monitoring Endpoints

| Endpoint | URL | Purpose |
|----------|-----|---------|
| Phoenix Health | http://localhost:4000/health | App status |
| Prajna Cockpit | http://localhost:4000/prajna | C3I dashboard |
| AI Copilot | http://localhost:4000/prajna/copilot | AI assistant |
| Prometheus | http://localhost:9090 | Metrics |
| Grafana | http://localhost:3000 | Dashboards |

---

## 5.0 Troubleshooting Guide

### 5.1 Boot Failures

| Issue | Cause | Resolution |
|-------|-------|------------|
| Preflight fails | Port conflict | `sa-clean && sa-up` |
| Ignition timeout | Image missing | `podman images | grep indrajaal` |
| Lens fails | OTEL unreachable | Check `sa-obs` status |
| Convergence fails | Network issue | Check `172.31.0.0/16` |
| Ready hangs | Phoenix crash | Check `sa-logs indrajaal-app` |

### 5.2 Health Check Failures

| Issue | Cause | Resolution |
|-------|-------|------------|
| FPPS disagreement | State drift | `sa-down && sa-up` |
| Quorum lost | Container down | `sa-status` then `sa-up` |
| 2oo3 veto | Model mismatch | Update formal model |

### 5.3 Log Analysis

```bash
# View all container logs
sa-logs

# View specific container
sa-logs indrajaal-app
sa-logs indrajaal-db
sa-logs indrajaal-obs

# Follow logs in real-time
podman logs -f indrajaal-ex-app-1
```

---

## 6.0 Maintenance Procedures

### 6.1 Volume Cleanup

```bash
# Clean containers (preserves data/kms/)
sa-clean

# Nuclear clean (destroys all state)
sa-scour --confirm
# WARNING: Destroys telemetry history
```

### 6.2 Database Maintenance

```bash
# Access database console
db-console

# Run migrations
db-migrate

# Reset database
db-reset
```

### 6.3 Test Execution

```bash
# Run F# runtime tests
sa-test --mode swarm

# Run Elixir tests
test

# Generate coverage report
test-cover

# Run UX evaluation
sa-ux
```

---

## 7.0 Command Quick Reference

### 7.1 Primary Commands

| Command | Purpose | STAMP |
|---------|---------|-------|
| `sa-up` | Start mesh | SC-SIL6-001 |
| `sa-down` | Stop mesh | SC-SIL6-002 |
| `sa-status` | Show status | SC-SIL6-004 |
| `sa-health` | FPPS validation | SC-SIL6-005 |
| `sa-clean` | Clean containers | SC-SIL6-003 |
| `sa-scour` | Nuclear clean | SC-SIL6-007 |
| `sa-emergency` | Emergency stop | SC-EMR-057 |
| `sa-verify` | 2oo3 verification | SC-SIL6-006 |

### 7.2 Testing Commands

| Command | Purpose |
|---------|---------|
| `sa-test` | F# runtime tests |
| `sa-ux` | UX evaluation |
| `sa-orchestrate` | Test orchestrator |
| `test` | Elixir tests |
| `test-cover` | Coverage report |

### 7.3 Development Commands

| Command | Purpose |
|---------|---------|
| `compile` | Patient Mode compile |
| `quality` | Format + Credo |
| `quality-full` | + Dialyzer + Sobelow |
| `cepaf-build` | Build F# projects |

---

## 8.0 STAMP Constraints Reference

| ID | Constraint | Verification |
|----|------------|--------------|
| SC-SIL6-001 | 5-stage boot | `sa-up` output |
| SC-SIL6-002 | Checkpoint shutdown | `sa-down` output |
| SC-SIL6-003 | Preserve data/kms/ | `ls data/kms/` after clean |
| SC-SIL6-004 | Status < 30s | Time `sa-status` |
| SC-SIL6-005 | FPPS consensus | `sa-health` all 5 pass |
| SC-SIL6-006 | 2oo3 voting | `sa-verify` 2/3+ agree |
| SC-EMR-057 | Emergency < 5s | Time `sa-emergency` |

---

## 9.0 AOR Rules Reference

| ID | Rule |
|----|------|
| AOR-MESH-001 | Use `sa-up` for all mesh operations |
| AOR-MESH-002 | Checkpoint before shutdown |
| AOR-MESH-003 | 2oo3 consensus in production |
| AOR-MESH-004 | FPPS for health assessment |
| AOR-MESH-005 | Log 5-Order effects |
| AOR-MESH-006 | Federation version negotiation |
| AOR-MESH-007 | Guardian approval for apoptosis |
| AOR-MESH-008 | DigitalTwin is authoritative |
| AOR-MESH-009 | Jenkins for releases |
| AOR-MESH-010 | Emergency < 5s |

---

## 10.0 Related Documents

- AGENT_BOOTSTRAP.md - Agent onboarding
- CLAUDE.md / GEMINI.md - System specifications
- SIL6_MESH_CLI_USER_GUIDE.md - CLI reference
- TEST_DEMO_INTEGRATION_MATRIX.md - Test/demo scripts
