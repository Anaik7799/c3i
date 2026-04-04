---
name: swarm-verify
description: "Deep swarm verification — OODA compliance, observability pipeline, control plane, agent probes, fractal depth across all 16 SIL-6 containers"
---

# Swarm Verification Skill

Verify the 16-container SIL-6 Biomorphic Mesh across 7 verification actions and 8 fractal layers using the `swarm_verify` MCP tool via the Sentinel+Zenoh MCP server.

## Usage

```
/swarm-verify [action] [options]
```

## Actions

| Action | What it verifies | Coverage |
|---|---|---|
| `ooda` | 5-tier OODA cycle compliance (Agent 30ms, Intelligence 100ms, Knowledge 1ms, Cortex 50ms, Strategy 1000ms) | All 16 containers (6 full, 10 baseline) |
| `observability` | Closed-loop pipeline: OTEL (4317) → Prometheus (9090) → Grafana (3000) → Zenoh (7447) | All 16 containers |
| `control` | Control plane round-trip: command → Zenoh → container → feedback | All 16 containers (category-aware) |
| `agent_probe` | Embedded F# agent health, capabilities, Zenoh subscriptions | All 16 containers (6 deep, 10 baseline) |
| `fractal` | L0-L7 fractal layer depth with inter-layer consistency | All 16 containers per layer |
| `inject_trace` | Synthetic trace through observability pipeline + per-container propagation | All 16 containers |
| `full` | Complete swarm verification — aggregates all above with compliance percentage | All 16 containers |

## Options

- `--container <name>`: Target specific container (default: all 16)
- `--tier <name>`: OODA tier filter: agent|intelligence|knowledge|cortex|strategy
- `--layer <0-7>`: Specific fractal layer (default: all layers)
- `--verbose`: Show detailed per-check output

## Examples

```bash
# Full swarm verification across all 16 containers
/swarm-verify full

# OODA compliance check
/swarm-verify ooda

# Fractal verification of Layer 0 (Constitutional)
/swarm-verify fractal --layer 0

# Agent probe on specific container
/swarm-verify agent_probe --container cepaf-bridge

# Inject synthetic trace through pipeline
/swarm-verify inject_trace
```

## MCP Tool

Uses `swarm_verify` from the `sentinel-zenoh` MCP server. The tool accepts:
- `action` (required): One of the 7 actions
- `container_name` (optional): Target container name
- `tier` (optional): OODA tier filter
- `layer` (optional): Fractal layer 0-7
- `verbose` (optional): Detailed output flag

## Container Categories

| Category | Containers | Full Capabilities |
|---|---|---|
| ElixirApp | ex-app-1, ex-app-2, ex-app-3, chaya | OODA 5-tier, agent probe, all fractal |
| FsharpBridge | cepaf-bridge | OODA, agent probe, L0/L7 primary |
| FsharpCortex | indrajaal-cortex | OODA, agent probe, L5 primary |
| ZenohRouter | zenoh-router, -1, -2, -3 | L6 Ecosystem primary |
| Database | indrajaal-db-prod | L3 Transaction primary |
| Observability | indrajaal-obs-prod | OTEL pipeline core |
| AiCompute | indrajaal-ollama, indrajaal-mojo | L5 Cognitive participant |
| MlRunner | indrajaal-ml-runner-1, -2 | Baseline only |

## STAMP References

SC-SWARM-VERIFY-001 to SC-SWARM-VERIFY-064, SC-OODA-001 to SC-OODA-009,
SC-VER-041, SC-VER-074, SC-CTRL-001 to SC-CTRL-007, SC-MON-001 to SC-MON-006,
SC-FRACTAL-001, SC-ZENOH-001, SC-ZENOH-006
