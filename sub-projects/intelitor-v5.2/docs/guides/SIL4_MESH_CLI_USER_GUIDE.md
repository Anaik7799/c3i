# SIL-6 Biomorphic Mesh CLI User Guide
**Version**: 21.3.0-SIL6
**Date**: 2026-01-11
**Compliance**: SC-SIL6-*, AOR-MESH-*

---

## 1.0 Overview

The SIL-6 Biomorphic Mesh CLI provides unified command interface for the Panopticon SIL-6 Biomorphic Fractal Mesh architecture. All mesh operations follow the **Biomorphic Evolutionary Plan (BEP)** and implement 5-stage transactional boot with FPPS consensus validation.

### 1.1 Core Concepts

| Concept | Description |
|---------|-------------|
| **Panopticon** | 5-layer "Directed Telescope" architecture |
| **2oo3 Voting** | 2-out-of-3 consensus for production actuations |
| **FPPS** | 5-Point Parallel System validation |
| **Quorum** | `floor(N/2)+1` for cluster decisions |
| **Apoptosis** | 6-phase controlled self-destruction |

---

## 2.0 Quick Start

```bash
# Enter development environment
devenv shell

# Start mesh (5-stage boot)
sa-up

# Check status
sa-status

# Verify health (FPPS)
sa-health

# Graceful shutdown
sa-down
```

---

## 3.0 Command Reference

### 3.1 Primary Mesh Commands

#### sa-up - Boot Mesh
Starts the **SIL-6 Biomorphic Fractal Mesh** (15 Containers) via the comprehensive orchestrator.

```bash
sa-up [--mode dev|cluster|fractal] [--skip-preflight]
```

**Architecture (15 Containers)**:
1. **Data Plane**: `indrajaal-db-prod` (PostgreSQL + TimescaleDB)
2. **Observability**: `indrajaal-obs-prod` (OTEL, Prometheus, Grafana, Loki, SigNoz)
3. **Control Plane**: `zenoh-router-1`, `zenoh-router-2`, `zenoh-router-3` (2oo3 Quorum)
4. **Cognitive Plane**: `cepaf-bridge`, `indrajaal-cortex` (AI Brain)
5. **Application Plane**: `indrajaal-ex-app-1`, `indrajaal-ex-app-2`, `indrajaal-ex-app-3` (HA Cluster)
6. **Digital Twin**: `indrajaal-chaya` (Founder's Twin)
7. **Satellite Plane**: `indrajaal-ml-runner-1`, `indrajaal-ml-runner-2` (Ephemeral Compute)

**Boot Stages**:
1. **Preflight** - Container image verification, port availability
2. **Ignition** - Container launch, network binding
3. **Lens** - Health check initialization, OTEL binding
4. **Convergence** - Inter-container communication & Zenoh mesh formation
5. **Ready** - TUI cockpit launch, mesh operational

**STAMP**: SC-SIL6-001

---

#### sa-down - Shutdown Mesh
Transactional shutdown of the full mesh with state checkpointing.

```bash
sa-down [--force] [--skip-checkpoint]
```

**Shutdown Stages**:
1. Notify all services (incl. Chaya & Runners) of pending shutdown
2. Drain active connections
3. Checkpoint state to DuckDB
4. Stop containers gracefully
5. Verify clean termination

**STAMP**: SC-SIL6-002

---

#### sa-status - Mesh Status
Shows container health and mesh state for all 15 nodes.

```bash
sa-status [--verbose] [--json]
```

**Output**:
```
╔═══════════════════════════════════════════════════════════════╗
║  SIL-6 BIOMORPHIC MESH STATUS           [2026-01-12 10:00:00] ║
╠═══════════════════════════════════════════════════════════════╣
║  Container        │ Status  │ Health  │ Role                  ║
║  ─────────────────┼─────────┼─────────┼─────────────────────  ║
║  indrajaal-db     │ Running │ Healthy │ Data Plane            ║
║  zenoh-router-1   │ Running │ Healthy │ Control (Leader)      ║
║  indrajaal-app-1  │ Running │ Healthy │ App (Primary)         ║
║  indrajaal-app-2  │ Running │ Healthy │ App (Secondary)       ║
║  indrajaal-chaya  │ Running │ Healthy │ Digital Twin          ║
║  ml-runner-1      │ Running │ Healthy │ Satellite (Compute)   ║
║  ml-runner-2      │ Running │ Healthy │ Satellite (Compute)   ║
╠═══════════════════════════════════════════════════════════════╣
║  Mesh State: OPERATIONAL                                      ║
║  Quorum: 3/3 (100%)                                           ║
║  FPPS: 5/5 methods passing                                    ║
╚═══════════════════════════════════════════════════════════════╝
```

**STAMP**: SC-SIL6-004

---

#### sa-health - FPPS Health Validation
Runs 5-Point Parallel System consensus validation across the fractal mesh.

```bash
sa-health [--container <name>] [--deep]
```

**STAMP**: SC-SIL6-005

---

#### sa-clean - Clean Containers
Stops the mesh and removes volumes (Standard Clean).

```bash
sa-clean [--volumes] [--preserve-kms]
```

**STAMP**: SC-SIL6-003

---

#### sa-scour - Nuclear Clean
Complete system reset including all volumes and artifacts. Maps to `mesh clean`.

```bash
sa-scour [--confirm]
```

**Warning**: Destroys all state including telemetry history.

**STAMP**: SC-SIL6-007

---

#### sa-emergency - Emergency Stop
Force stop within 5 seconds.

```bash
sa-emergency [--reason <text>]
```

**STAMP**: SC-EMR-057

---

#### sa-verify - 2oo3 Voting Verification
Validates 2-out-of-3 consensus for production actuations.

```bash
sa-verify [--action <name>]
```

**2oo3 Voters**:
- **Live Node** - Actual container response
- **Shadow Node** - Parallel validation container
- **Formal Model** - Expected behavior specification

**STAMP**: SC-SIL6-006

---

### 3.2 Testing Commands

#### sa-test - Runtime Tests
Runs F# runtime test orchestrator.

```bash
sa-test [--mode swarm|sequential] [--filter <pattern>]
```

**Test Categories**:
- Unit tests (Expecto)
- Property tests (FsCheck)
- Integration tests
- FPPS consensus tests
- 2oo3 voting tests

---

#### sa-ux - UX Evaluation
Runs cockpit UX/UI/CX/DX evaluation.

```bash
sa-ux [--report-format html|json|md]
```

---

#### sa-orchestrate - Test Orchestrator
Runs comprehensive test orchestration.

```bash
sa-orchestrate [--parallel 4] [--timeout 30m]
```

---

## 4.0 Test & Demo Integration (BEP)

### 4.1 Elixir Test Scripts (100+)

| Category | Scripts | Command |
|----------|---------|---------|
| TDG Validation | `tdg_*.exs` | `elixir scripts/testing/tdg_validator.exs` |
| Container Health | `container_*.exs` | `elixir scripts/testing/container_health_validator.exs` |
| Demo Validation | `demo_*.exs` | `elixir scripts/testing/demo_execution_validator.exs` |
| Coverage | `*coverage*.exs` | `elixir scripts/testing/test_coverage_analysis.exs` |
| STAMP/GDE | `stamp_*.exs` | `elixir scripts/testing/stamp_gde_validation_framework.exs` |

### 4.2 Demo Scripts (56+)

| Domain | Script | Purpose |
|--------|--------|---------|
| Alarms | `alarms_enterprise_demo.exs` | Alarm processing workflow |
| Accounts | `accounts_enterprise_demo.exs` | User/tenant management |
| Access Control | `access_control_enterprise_demo.exs` | RBAC demonstration |
| Analytics | `analytics_enterprise_demo.exs` | Reporting/dashboards |
| Compliance | `compliance_enterprise_demo.exs` | Audit/SLA validation |

### 4.3 F# Test Scripts (15+)

| Script | Purpose |
|--------|---------|
| `RuntimeTestOrchestrator.fsx` | Comprehensive test coordination |
| `CockpitUXEvaluator.fsx` | UX/UI evaluation |
| `SIL6Orchestrator.fsx` | SIL-6 Biomorphic compliance testing |
| `ComprehensiveRuntimeTests.fsx` | Integration test suite |
| `KmsSil4Verification.fsx` | KMS state verification |

### 4.4 Integrated Test Workflow

```bash
# 1. Start mesh
sa-up

# 2. Run F# runtime tests
sa-test --mode swarm

# 3. Run Elixir TDG validation
elixir scripts/testing/tdg_validator.exs

# 4. Run demo scenarios
elixir scripts/demo/continuous_enterprise_demo_executor.exs

# 5. Run UX evaluation
sa-ux

# 6. Generate coverage report
test-cover

# 7. Verify 2oo3 consensus
sa-verify

# 8. Shutdown
sa-down
```

---

## 5.0 STAMP Constraints

| ID | Constraint | Command |
|----|------------|---------|
| SC-SIL6-001 | 5-stage boot | `sa-up` |
| SC-SIL6-002 | Checkpoint shutdown | `sa-down` |
| SC-SIL6-003 | Preserve data/kms/ | `sa-clean` |
| SC-SIL6-004 | Status < 30s | `sa-status` |
| SC-SIL6-005 | FPPS consensus | `sa-health` |
| SC-SIL6-006 | 2oo3 voting | `sa-verify` |
| SC-SIL6-007 | Nuclear clean | `sa-scour` |
| SC-SIL6-011 | Quorum N/2+1 | (automatic) |
| SC-SIL6-015 | Apoptosis 6-phase | (automatic) |
| SC-EMR-057 | Emergency < 5s | `sa-emergency` |

---

## 6.0 AOR Rules

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

## 7.0 Troubleshooting

### 7.1 Boot Failures

| Issue | Cause | Resolution |
|-------|-------|------------|
| Preflight fails | Port conflict | `sa-clean && sa-up` |
| Ignition timeout | Image missing | `podman images` check |
| Convergence fails | Network issue | Check `172.31.0.0/16` |

### 7.2 Health Failures

| Issue | Cause | Resolution |
|-------|-------|------------|
| FPPS disagreement | State drift | `sa-down && sa-up` |
| Quorum lost | Container down | `sa-status` then `sa-up` |
| 2oo3 veto | Model mismatch | Update formal model |

### 7.3 Emergency Recovery

```bash
# Force stop everything
sa-emergency --reason "critical failure"

# Nuclear clean
sa-scour --confirm

# Fresh start
sa-up
```

---

## 8.0 Integration with Prajna Cockpit

The SIL-6 Biomorphic Mesh CLI integrates with the Prajna C3I Cockpit:

| URL | Purpose |
|-----|---------|
| http://localhost:4000/prajna | Main cockpit |
| http://localhost:4000/prajna/copilot | AI assistant |
| http://localhost:3000 | Grafana dashboards |
| http://localhost:9090 | Prometheus metrics |

---

## 9.0 Related Documents

- AGENT_BOOTSTRAP.md - Agent context injection
- CLAUDE.md / GEMINI.md - System specifications
- docs/plans/BEP_V1_DOCUMENTATION_PLAN.md - BEP documentation plan
- journal/2026-01/20260105-* - BEP analysis journal
