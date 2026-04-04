---
name: sa
description: allowed-tools: Bash(podman-compose:*), Bash(podman:*), Bash(curl:*), mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__zenoh_session, mcp__sentinel-zenoh__zenoh_query
---
---

# Standalone Environment Command (SC-CNT-009, SC-CNT-012)

Manage the SIL-6 Biomorphic Mesh container stack with Zenoh health verification.

## Commands:
- **up**: Start all 15 containers via 7-tier boot + verify Zenoh mesh + Sentinel health check
- **down**: Graceful shutdown with health verification
- **status**: Container status + Zenoh mesh state + Sentinel health
- **logs**: Stream logs (add service name for specific)
- **clean**: Stop and remove volumes

## Container Architecture (15-Container SIL-6 Genome):

### Tier 1: Zenoh Control Plane
| Container | Ports | Category |
|-----------|-------|----------|
| zenoh-router | 7447 | PulledFromRegistry |

### Tier 2: Database Layer
| Container | Ports | Category |
|-----------|-------|----------|
| indrajaal-db-prod | 5433 | BuiltFromDockerfile |

### Tier 3: Observability
| Container | Ports | Category |
|-----------|-------|----------|
| indrajaal-obs-prod | 4317/4318, 9090, 3000, 3100 | BuiltFromDockerfile |

### Tier 4: Quorum Routers
| Container | Ports | Category |
|-----------|-------|----------|
| zenoh-router-1 | 7448 | SharedImage (zenoh-router) |
| zenoh-router-2 | 7449 | SharedImage (zenoh-router) |
| zenoh-router-3 | 7450 | SharedImage (zenoh-router) |

### Tier 5: Cognitive Layer
| Container | Ports | Category |
|-----------|-------|----------|
| cepaf-bridge | — | BuiltFromDockerfile |
| indrajaal-cortex | — | BuiltFromDockerfile |

### Tier 6: Seed + Twin + Ollama
| Container | Ports | Category |
|-----------|-------|----------|
| indrajaal-ex-app-1 | 4000, 4001 | BuiltFromDockerfile |
| indrajaal-chaya | 4002 | SharedImage (indrajaal-ex-app-1) |
| indrajaal-ollama | 11434 | PulledFromRegistry |

### Tier 7: HA + ML Runners
| Container | Ports | Category |
|-----------|-------|----------|
| indrajaal-ex-app-2 | 4010 | SharedImage (indrajaal-ex-app-1) |
| indrajaal-ex-app-3 | 4020 | SharedImage (indrajaal-ex-app-1) |
| indrajaal-ml-runner-1 | — | SharedImage (indrajaal-ollama) |
| indrajaal-ml-runner-2 | — | SharedImage (indrajaal-ollama) |

**Totals**: 5 BuiltFromDockerfile + 2 PulledFromRegistry + 8 SharedImage = 15 containers

## Compose file:
```bash
podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml $ARGUMENTS
```

## Post-Up Verification (MANDATORY):
After `up`, verify system health via MCP:
1. Check Sentinel: `sentinel(action: "health")` — expect score > 60
2. Open Zenoh: `zenoh_session(action: "open")` — verify router connection
3. Query metrics: `zenoh_query(action: "metrics")` — verify FFI operational
4. Check endpoints:
   ```bash
   curl -sf http://localhost:4000/api/health
   curl -sf http://localhost:9090/-/healthy
   ```
5. Report unified status dashboard

## Mathematical Foundation

**Container Availability**: $A = \frac{MTBF}{MTBF + MTTR}$ — uptime fraction per container

**System Readiness**: $R_c = \prod_{i=1}^{n} A_i$ — joint availability of $n$ serial containers

**Health Score**: $H_{cluster} = \frac{\sum_{i} w_i \cdot H_i}{\sum_{i} w_i}$ — weighted aggregate health

**Boot Latency**: $T_{boot} = \max_i(T_i) + T_{healthcheck}$ — parallel boot + sequential health verification

## STAMP Constraints
| ID | Constraint |
|----|------------|
| SC-CNT-009 | NixOS/Podman only |
| SC-CNT-012 | Rootless containers |
| SC-EMR-057 | Emergency stop < 5s |
| SC-SIL6-001 | 5-stage boot sequence |

## Post-Down Verification:
After `down`, confirm clean shutdown:
```bash
podman ps --filter name=indrajaal --format "{{.Names}}"
```
Should return empty.
