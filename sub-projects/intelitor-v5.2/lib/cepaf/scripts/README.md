# CEPAF F# Test Scripts

**Version**: 2.1.0 | **Framework**: SOPv5.11 + STAMP + OODA + Biomorphic Swarm + OpenRouter AI
**Updated**: 2025-12-31

## Overview

This directory contains F# scripts for comprehensive runtime testing of the Indrajaal standalone environment. The scripts implement biomorphic swarm intelligence with Fast OODA loops for efficient parallel test execution, with AI-assisted validation via OpenRouter.

## Quick Start (Recommended)

```bash
# Enter devenv shell
devenv shell

# Start standalone stack (3 containers)
sa-up

# Check status
sa-status

# Run runtime tests
sa-test

# Run UX evaluation
sa-ux

# View logs
sa-logs

# Stop stack
sa-down
```

## Devenv Commands Reference

| Command | Description |
|---------|-------------|
| `sa-up` | Start prod standalone (3 containers) |
| `sa-down` | Stop standalone stack |
| `sa-clean` | Stop + remove volumes |
| `sa-status` | Show container status |
| `sa-logs [svc]` | Stream logs (default: indrajaal-ex-app-1) |
| `sa-db` | Start DB container only |
| `sa-obs` | Start observability only |
| `sa-app` | Start app container only |
| `sa-test` | Run runtime tests (swarm) |
| `sa-ux` | Run UX/UI evaluation |
| `sa-orchestrate` | Run test orchestrator |
| `cockpitf [cmd]` | F# Cockpit (deploy\|status\|test\|cleanup) |
| `cepaf-build` | Build F# projects |

---

## Scripts

### ProductionDeploymentOrchestrator.fsx

**Purpose**: Production-equivalent deployment orchestration with AI validation

**Features**:
- Full container stack deployment (3 services)
- OpenRouter AI integration for intelligent decisions
- OODA loop deployment control
- Mesh networking configuration
- Health check verification
- FLAME/Clustering validation

**Usage via devenv**:
```bash
sa-up        # Deploy stack
sa-status    # Check status
sa-down      # Stop stack
sa-clean     # Cleanup with volumes
```

**Direct usage** (if needed):
```bash
OPENROUTER_API_KEY=sk-xxx dotnet fsi ProductionDeploymentOrchestrator.fsx --deploy
dotnet fsi ProductionDeploymentOrchestrator.fsx --status
dotnet fsi ProductionDeploymentOrchestrator.fsx --cleanup
```

**3-Container Architecture**:
| Container | Ports | Services |
|-----------|-------|----------|
| indrajaal-db-prod | 5433 | PostgreSQL 17 + TimescaleDB |
| indrajaal-obs-prod | 4317/4318, 9090, 3000, 3100, 3301, 8080, 8123 | OTEL + Prometheus + Grafana + Loki + SigNoz + ClickHouse |
| indrajaal-ex-app-1 | 4000, 4001, 6379 | Phoenix + FLAME + Clustering + Redis |

---

### ComprehensiveRuntimeTests.fsx

**Purpose**: Full runtime test suite with AI validation (70+ scenarios)

**Features**:
- Infrastructure validation (10 scenarios)
- Dataflow testing (15 scenarios)
- Control flow testing (15 scenarios)
- Cockpit scenarios (25 scenarios)
- Evolvability checks (10 scenarios)
- OpenRouter AI-powered analysis
- Biomorphic swarm execution

**Usage via devenv**:
```bash
sa-test              # Run swarm mode tests
sa-orchestrate       # Run with orchestrator
```

**Direct usage** (if needed):
```bash
OPENROUTER_API_KEY=sk-xxx dotnet fsi ComprehensiveRuntimeTests.fsx --mode swarm
dotnet fsi ComprehensiveRuntimeTests.fsx --mode sequential
dotnet fsi ComprehensiveRuntimeTests.fsx --mode swarm --verbose
```

**Test Domains**:
| Domain | Scenarios | Description |
|--------|-----------|-------------|
| Infrastructure | 10 | DB, Redis, OTEL, Prometheus, Grafana, Loki, Network, FLAME, Clustering |
| Dataflow | 15 | API endpoints, DB read/write, Cache, Telemetry pipeline |
| ControlFlow | 15 | Circuit breaker, OODA timing, Auth, Error handling, Rate limiting |
| Cockpit | 25 | Prajna dashboard, AI Copilot, Dark mode, Navigation, Response time |
| Evolvability | 10 | Documentation, API versioning, Metrics, Logs, Configuration |

---

### RuntimeTestOrchestrator.fsx

**Purpose**: Biomorphic swarm test execution engine

**Features**:
- Fast OODA Loop (SC-OODA-001): <100ms cycle time
- Hysteresis Mode (SC-OODA-005): Prevents decision oscillation
- Concurrent Workers: Up to 10 parallel test executors
- Real-time Dashboard: Progress visualization
- Auto-scaling: Based on resource availability

**Usage via devenv**:
```bash
sa-orchestrate           # Default swarm mode
sa-orchestrate sequential  # Sequential mode
```

**Direct usage** (if needed):
```bash
dotnet fsi RuntimeTestOrchestrator.fsx --mode swarm
dotnet fsi RuntimeTestOrchestrator.fsx --mode sequential
dotnet fsi RuntimeTestOrchestrator.fsx --domain cockpit
dotnet fsi RuntimeTestOrchestrator.fsx --mode single --domain dataflow --scenario DF-DB-001
```

**Options**:
| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| `--mode` | swarm, sequential, single | swarm | Execution mode |
| `--domain` | dataflow, control_flow, cockpit, evolvability | all | Test domain |
| `--scenario` | ID | - | Specific scenario (single mode) |
| `--workers` | 1-10 | 10 | Max concurrent workers |
| `--verbose` | flag | false | Verbose output |

---

### CockpitUXEvaluator.fsx

**Purpose**: Comprehensive UX/UI/CX/DX evaluation of Prajna Cockpit

**Features**:
- Nielsen's 10 Usability Heuristics (H1-H10)
- UI Consistency Audit (Color, Typography, Components, Spacing)
- Customer Experience Metrics (Task Completion, SUS)
- Developer Experience Metrics (TTFMA, Documentation)
- Ergonomics Assessment (Keyboard, Accessibility)
- Information Architecture Evaluation
- Aesthetics Evaluation

**Usage via devenv**:
```bash
sa-ux    # Run full UX evaluation
```

**Direct usage** (if needed):
```bash
dotnet fsi CockpitUXEvaluator.fsx
```

**Evaluation Categories**:

| Category | Criteria | Weight |
|----------|----------|--------|
| UX Heuristics | Nielsen H1-H10 | 2.0x |
| UI Consistency | Color, Typography, Components, Spacing | 1.5x |
| Customer Experience | Task Completion, Time, Errors, SUS | 2.0x |
| Developer Experience | TTFMA, Docs, API, Errors | 1.5x |
| Ergonomics | Keyboard, Density, Latency, Dark Mode | 1.0x |
| Information Architecture | Navigation, Content, Dashboard | 1.0x |
| Aesthetics | Hierarchy, Brand, Modern Design | 0.5x |

**Score Interpretation**:
| Score | Rating | Description |
|-------|--------|-------------|
| 90-100% | EXCELLENT | Production ready |
| 70-89% | GOOD | Minor improvements needed |
| 50-69% | FAIR | Significant work required |
| 30-49% | NEEDS WORK | Major issues |
| 0-29% | CRITICAL | Blocking issues |

---

## Prerequisites

- devenv (recommended) or:
  - .NET SDK 10.0+ (for F# script execution)
  - Podman 5.4.1+ (for container services)
  - PostgreSQL running on port 5433
  - Elixir 1.19+ / OTP 28+ (for Phoenix)

## STAMP Compliance

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-OODA-001 | Cycle time <100ms | `OODACycleTargetMs = 100` |
| SC-OODA-005 | Hysteresis prevents oscillation | 10% margin, 3-cycle hold |
| SC-OODA-006 | AI orientation timeout | 20ms fallback |
| SC-SWARM-001 | Convergence threshold | 95% completion |
| SC-UX-001 | Nielsen compliance | All heuristics evaluated |

## Output

### RuntimeTestOrchestrator

Generates:
- Real-time dashboard during execution
- Final report with pass/fail summary
- `reports/runtime_test_YYYY-MM-DD.md` file

### CockpitUXEvaluator

Generates:
- Category breakdown with scores
- Recommendations for improvement
- Critical findings list

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Phoenix App | http://localhost:4000 | - |
| Health Check | http://localhost:4001/health | - |
| Prajna Cockpit | http://localhost:4000/prajna | - |
| AI Copilot | http://localhost:4000/prajna/copilot | - |
| Grafana | http://localhost:3000 | admin/indrajaal |
| Prometheus | http://localhost:9090 | - |
| Loki | http://localhost:3100 | - |
| SigNoz | http://localhost:3301 | - |
| ClickHouse | http://localhost:8123 | - |

## References

- [PRODUCTION_EQUIVALENT_RUNTIME_TESTING_PLAN.md](../../../docs/testing/PRODUCTION_EQUIVALENT_RUNTIME_TESTING_PLAN.md)
- [STANDALONE_RUNTIME_TESTING_PLAN.md](../../../docs/testing/STANDALONE_RUNTIME_TESTING_PLAN.md)
- [PRAJNA_5_LEVEL_SPECIFICATION.md](../../../docs/architecture/PRAJNA_5_LEVEL_SPECIFICATION.md)
- [podman-compose-prod-standalone.yml](../artifacts/podman-compose-prod-standalone.yml)
- [Nielsen's 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [OpenRouter API Documentation](https://openrouter.ai/docs)
