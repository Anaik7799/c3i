# Zenoh Topic Hierarchy Reference

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-ZENOH-006, SC-BRIDGE-005

## Overview

All Zenoh key expressions in Indrajaal follow the `indrajaal/**` namespace. This
document provides the complete topic hierarchy tree, subscriber/publisher ownership,
and QoS settings for each branch.

## Full Hierarchy Tree

```
indrajaal/
|
+-- health/
|   +-- {node}/                      # Per-node health status (10s interval)
|   +-- cluster/                     # Cluster-wide health summary
|   +-- dms/                         # Dead Man's Switch heartbeat (100ms)
|
+-- metrics/
|   +-- {node}/
|   |   +-- cpu/                     # CPU utilization metrics
|   |   +-- memory/                  # Memory utilization
|   |   +-- disk/                    # Disk I/O metrics
|   |   +-- network/                 # Network throughput
|   |   +-- beam/                    # BEAM VM metrics (schedulers, processes)
|   +-- otel/                        # OpenTelemetry export bridge
|
+-- logs/
|   +-- cluster/
|   |   +-- node-{N}/               # Structured logs per node
|   +-- fractal/
|       +-- L{1-7}/                  # Per-layer fractal logs
|
+-- cpu/
|   +-- governor/
|       +-- status/                  # CPU governor JSON payload
|       +-- metrics/                 # Governor PID controller output
|
+-- cluster/
|   +-- events/                      # Cluster join/leave/partition events
|   +-- gossip/                      # Gossip protocol messages
|   +-- quorum/                      # 2oo3 voting state
|   +-- topology/                    # Current mesh topology
|
+-- sentinel/
|   +-- threats/                     # Security threat alerts
|   +-- guardian/                    # Guardian decisions
|   +-- audit/                       # Audit trail events
|
+-- prajna/
|   +-- kpi/                         # Cockpit KPI dashboard data
|   +-- events/                      # UI event stream
|   +-- copilot/                     # AI copilot interactions
|
+-- planning/
|   +-- events/                      # Task created/updated/completed
|   +-- sprints/                     # Sprint lifecycle events
|   +-- status/                      # Current planning state
|
+-- math/
|   +-- health/                      # Mathematical discipline health (CP-MATH-01)
|   +-- entropy/                     # Shannon entropy measurements
|   +-- ooda/                        # OODA cycle timing
|   +-- mso/                         # MSO Buchi automaton state
|
+-- smriti/
|   +-- knowledge/                   # Knowledge ingestion events
|   +-- federation/                  # Cross-holon knowledge sync
|   +-- evolution/                   # Evolution history events
|
+-- git/
|   +-- commits/                     # Git commit telemetry
|   +-- metrics/                     # Repository health metrics
|   +-- intelligence/                # Git intelligence analysis
|
+-- hint/
|   +-- misalignment/               # Human intent misalignment alerts
|
+-- cortex/
|   +-- inference/                   # AI inference requests/results
|   +-- models/                      # Model registry updates
|
+-- vsm/
|   +-- S{1-5}/                      # VSM subsystem health per system
|   +-- homeostasis/                 # Homeostatic controller output
|
+-- federation/
    +-- attestation/                 # Ed25519 attestation exchange
    +-- partition/                   # Partition detection alerts
    +-- sync/                        # Cross-holon sync status
```

## Topic Ownership Matrix

| Topic Branch | Publisher | Subscriber(s) | QoS |
|-------------|-----------|---------------|-----|
| `health/{node}` | Each app node | Prajna, Sentinel | Reliable |
| `health/dms` | DMS GenServer | Guardian | Best-effort (100ms) |
| `metrics/{node}/**` | OTEL bridge | Grafana, Prajna | Best-effort |
| `logs/**` | Fractal Logger | Loki, Prajna | Reliable |
| `cpu/governor/**` | CPU Governor | Prajna dashboard | Best-effort |
| `cluster/events` | Gossip protocol | All nodes | Reliable |
| `cluster/quorum` | 2oo3 voter | Guardian, Prajna | Reliable |
| `sentinel/threats` | Sentinel MCP | Guardian, Prajna | Reliable |
| `planning/events` | F# Planning CLI | Prajna, SMRITI | Reliable |
| `math/health` | MathMonitor (F#) | Prajna dashboard | Best-effort |
| `smriti/**` | SMRITI GenServer | Federation peers | Reliable |
| `git/**` | GitTelemetryCollector | Prajna LiveView | Best-effort |
| `federation/**` | Federation gateway | All federated nodes | Reliable |

## Key Expression Patterns

| Pattern | Meaning |
|---------|---------|
| `indrajaal/**` | All topics (admin subscription) |
| `indrajaal/health/*` | All node health topics |
| `indrajaal/metrics/indrajaal-ex-app-1/**` | All metrics from app-1 |
| `indrajaal/logs/fractal/L3/**` | All L3 fractal logs |
| `indrajaal/cluster/*` | All cluster coordination |

## Environment Configuration

```bash
ZENOH_ENABLED=true
ZENOH_ROUTER_ENDPOINT=tcp/zenoh-router:7447
ZENOH_MODE=client
QUADPLEX_ZENOH=true
QUADPLEX_ZENOH_TOPIC=indrajaal/logs/cluster/node-{N}
```

## Related Documents

- CLAUDE.md (Zenoh Telemetry Mandatory)
- .claude/rules/zenoh-telemetry-mandatory.md
- docs/architecture/ZENOH_UNIVERSAL_INTEGRATION_PLAN_V3.md
- docs/architecture/MESH_NETWORKING_DESIGN.md
