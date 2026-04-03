# Deployment Runbook

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-BOOT-001, SC-OPT-001, SC-SIL4-005

## Overview

Step-by-step runbook for deploying Indrajaal from cold start to production readiness.
Covers pre-flight checks, sa-up boot sequence, health verification, and post-deploy
validation. Target boot time: < 60 seconds (SC-OPT-001).

## Pre-Flight Checklist

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | No host _build/deps | `ls _build deps 2>&1` | "No such file" |
| 2 | Podman running | `podman info --format '{{.Host.RemoteSocket}}'` | Socket path |
| 3 | Network exists | `podman network ls \| grep indrajaal-mesh` | 1 row |
| 4 | Images present | `podman images \| grep localhost/` | 4 images |
| 5 | Ports free | `ss -tlnp \| grep -E '4000\|5433\|7447\|9090'` | Empty |
| 6 | CPU < 80% | `scripts/cpu-governor.sh check` | OK |
| 7 | Disk > 10GB free | `df -h /` | Sufficient |
| 8 | Env vars set | `env \| grep SKIP_ZENOH_NIF` | 0 |

## Boot Sequence (sa-up)

```bash
# 1. Execute boot
./sa-up

# Boot proceeds in mandatory order (SC-SIL4-005):
#   Wave 1: zenoh-router      (port 7447)
#   Wave 2: indrajaal-db-prod (port 5433)
#   Wave 3: indrajaal-obs-prod (ports 4317, 9090, 3000, 3100)
#   Wave 4: indrajaal-ex-app-1 (port 4000)
```

### Boot Stages (SC-SIL4-012: 5 Stages Mandatory)

| Stage | Name | Actions | Gate |
|-------|------|---------|------|
| S1 | Infrastructure | Zenoh router + DB start | Health check pass |
| S2 | Observability | OTEL collector + Grafana + Loki | Metrics flowing |
| S3 | Application | Elixir app + migrations | Compile + migrate |
| S4 | Mesh Join | Zenoh session + PubSub | Connected to router |
| S5 | Verification | 2oo3 voting + health | All nodes healthy |

## Health Verification

```bash
# Immediate post-boot checks
./sa-status                          # Health matrix (15 nodes)
./sa-verify                          # 2oo3 voting verification

# HTTP health probe
curl -s http://localhost:4000/health | jq .

# Zenoh mesh verification
curl -s http://localhost:8000/status  # Zenoh router status

# Container health
podman ps --format "table {{.Names}} {{.Status}} {{.Ports}}"
```

### Expected Health Response

```json
{
  "node": "indrajaal@indrajaal-ex-app-1",
  "status": "healthy",
  "zenoh": { "status": "connected", "router": "tcp/zenoh-router:7447" },
  "db": { "status": "connected", "pool_size": 10 },
  "otel": { "status": "exporting", "traces_per_sec": 5 }
}
```

## Post-Deploy Validation

| # | Validation | Command | Pass Criteria |
|---|-----------|---------|---------------|
| 1 | Compilation | `mix compile` (in container) | 0 errors, 0 warnings |
| 2 | DB migrations | `mix ecto.migrate` | Up to date |
| 3 | Zenoh mesh | `sa-status \| grep zenoh` | Connected |
| 4 | OTEL traces | Check Grafana dashboard | Traces flowing |
| 5 | Prajna UI | `curl localhost:4000` | 200 OK |
| 6 | 2oo3 voting | `sa-verify` | PASS |
| 7 | Digital Twin | Check sync timestamp | < 30s ago |

## Rollback Procedure

```bash
# If any post-deploy check fails:
./sa-down                            # Graceful shutdown (6 phases, SC-SIL4-013)

# Restore previous images
podman tag localhost/indrajaal-app:latest localhost/indrajaal-app:failed
podman tag localhost/indrajaal-app:v-previous localhost/indrajaal-app:latest

# Reboot with previous version
./sa-up
./sa-verify
```

## Shutdown Sequence (sa-down)

```bash
# Graceful shutdown (SC-SIL4-013: 6 Phases)
./sa-down

# Phase 1: Connection drain (30s timeout, SC-SIL4-008)
# Phase 2: Dying gasp checkpoint (SC-SIL4-007)
# Phase 3: App container stop
# Phase 4: Observability stop
# Phase 5: Database stop (after drain)
# Phase 6: Zenoh router stop (last)
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Boot > 120s | CPU contention | Check cpu-governor, reduce parallelism |
| Zenoh timeout | Router not ready | Wait for Wave 1 health check |
| NIF crash | Host _build conflict | `rm -rf _build deps` (Axiom 0.1) |
| Migration fail | DB not ready | Verify Wave 2 completed |
| Port conflict | Stale container | `podman rm -f <container>` |

## Related Documents

- CLAUDE.md Section 2.2 (Essential Commands)
- docs/architecture/SIL4_MESH_STARTUP_SHUTDOWN_SPEC.md
- docs/architecture/OPTIMAL_MESH_SIL4_SPEC.md
- .claude/rules/functional-invariant.md
