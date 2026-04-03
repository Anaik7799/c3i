# Gemini Instruction: CEPAF Standalone Environment Setup

**Version**: 21.3.0-SIL6
**Protocol ID**: `GEM-INST-001`
**Subject**: Rapid Provisioning of CEPAF Standalone Environment
**Target**: Gemini Agent (SOPv5.11 Compliance)
**Date**: 2026-01-11
**Compliance**: SIL-6 Biomorphic Fractal Mesh

## 1. Objective
To quickly and reliably set up the full Standalone Execution Environment (Database, Observability, Application) using devenv commands, ensuring full execution readiness for all containers.

## 2. Core Constraints (STAMP)
*   **SC-ENV-001**: All operations MUST be executed within `devenv shell` to ensure tool availability (.NET, Podman).
*   **SC-ORD-001**: Container orchestration handled automatically by standalone compose.
*   **SC-CFG-001**: Use production-equivalent standalone stack.

## 3. Quick Start (Recommended)

```bash
# Enter devenv shell
devenv shell

# Start standalone stack (4 containers: Zenoh, DB, Obs, App)
sa-up

# Check status
sa-status

# View logs
sa-logs
```

## 4. Devenv Commands Reference

| Command | Description |
|---------|-------------|
| `sa-up` | Start prod standalone (4 containers) |
| `sa-down` | Stop standalone stack |
| `sa-clean` | Stop + remove volumes |
| `sa-status` | Show container status |
| `sa-logs [svc]` | Stream logs (default: indrajaal-ex-app-1) |
| `sa-db` | Start DB container only |
| `sa-obs` | Start observability only |
| `sa-app` | Start app container only |
| `sa-test` | Run runtime tests (swarm) |
| `sa-ux` | Run UX/UI evaluation |
| `cockpitf [cmd]` | F# Cockpit operations |
| `cepaf-build` | Build F# projects |

## 5. Manual Fallback Protocol

If devenv commands are unavailable, execute manually:

```bash
# Start full stack
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml up -d

# Check status
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml ps

# View logs
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml logs -f indrajaal-ex-app-1

# Stop
podman-compose -f lib/cepaf/artifacts/podman-compose-prod-standalone.yml down
```

For individual containers:
```bash
# Database only
podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml up -d

# Observability only
podman-compose -f lib/cepaf/artifacts/podman-compose-obs-standalone.yml up -d

# App only
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml up -d
```

## 6. Verification State

The setup is considered **COMPLETE** when:
1.  `zenoh-router` is `Up` and `healthy`
2.  `indrajaal-db-prod` is `Up` and `healthy`
3.  `indrajaal-obs-prod` is `Up` and `healthy`
4.  `indrajaal-ex-app-1` is `Up`
5.  Database port `5433` is reachable
6.  Phoenix at http://localhost:4000 responds

Verify with:
```bash
sa-status
curl -s http://localhost:4000/health | jq '.status'
```

## 7. Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Phoenix App | http://localhost:4000 | - |
| Prajna Cockpit | http://localhost:4000/prajna | - |
| AI Copilot | http://localhost:4000/prajna/copilot | - |
| Health | http://localhost:4000/health | - |
| Grafana | http://localhost:3000 | admin/indrajaal |
| Prometheus | http://localhost:9090 | - |

## 8. Debugging

```bash
# Logs (devenv)
sa-logs indrajaal-ex-app-1
sa-logs indrajaal-db-prod

# Network check
podman network ls | grep indrajaal

# Container inspect
podman inspect indrajaal-ex-app-1
```

## 9. Related Documents
- USER_OPERATIONS_GUIDE.md - Daily operations and command reference
- SIL6_MESH_CLI_USER_GUIDE.md - Mesh operations
- OPERATIONAL_RUNBOOK.md - Operating procedures
- AGENT_BOOTSTRAP.md - Agent onboarding
