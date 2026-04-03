---
description: SIL-6 Biomorphic mesh lifecycle — boot, shutdown, health, verify via Zenoh + Sentinel MCP
allowed-tools: mcp__sentinel-zenoh__zenoh_session, mcp__sentinel-zenoh__zenoh_pub, mcp__sentinel-zenoh__zenoh_sub, mcp__sentinel-zenoh__zenoh_query, mcp__sentinel-zenoh__sentinel, mcp__sentinel-zenoh__checkpoint_op, mcp__sentinel-zenoh__test_fsharp_start, mcp__sentinel-zenoh__test_fsharp_status, mcp__sentinel-zenoh__test_fsharp_results, Bash(podman-compose:*), Bash(podman:*), Bash(curl:*), Read
argument-hint: [boot|down|status|health|verify|emergency]
---

# SIL-6 Biomorphic Mesh Operations (SC-SIL6-001 to SC-SIL6-015)

Full mesh lifecycle management with Zenoh telemetry verification and Sentinel health monitoring.

## Usage
```
/mesh boot        # Full 5-stage boot with Zenoh verification
/mesh down        # Graceful shutdown with checkpoint
/mesh status      # Container health + Zenoh mesh + Sentinel
/mesh health      # FPPS 5-point consensus health check
/mesh verify      # 2oo3 voting verification + invariant check
/mesh emergency   # Force stop < 5 seconds (SC-EMR-057)
```

## Boot Sequence (5 Stages)
```
S0_PREFLIGHT    →  Environment validation, port scouring
S1_INFRASTRUCTURE →  DB + Observability containers
S2_ZENOH_MESH   →  Zenoh router + control plane
S3_APP_SEED     →  Application seed node with health wait
S4_HOMEOSTASIS  →  Health check, quorum, Cortex verification
```

### Boot Workflow
1. Pre-check sentinel: `sentinel(action: "status")`
2. Start containers:
   ```bash
   podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml up -d
   ```
3. Open Zenoh session: `zenoh_session(action: "open")`
4. Subscribe to health: `zenoh_sub(action: "subscribe", key: "indrajaal/health/**")`
5. Verify mesh: `zenoh_query(action: "verify")`
6. Check health: `sentinel(action: "health")`
7. Run F# regression: `test_fsharp_start(levels: [1,5])`
8. Report boot status with fractal layer verification

### Shutdown Workflow
1. Create checkpoint: `checkpoint_op(action: "quick")`
2. Publish shutdown signal: `zenoh_pub(key: "indrajaal/control/shutdown", payload: "graceful")`
3. Stop containers:
   ```bash
   podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml down
   ```
4. Close Zenoh: `zenoh_session(action: "close")`
5. Verify clean shutdown: no orphan processes

### Status Workflow
1. Container health:
   ```bash
   podman ps --filter name=indrajaal --format "{{.Names}} {{.Status}}"
   ```
2. Zenoh mesh: `zenoh_query(action: "metrics")`
3. Sentinel health: `sentinel(action: "health")`
4. Threat assessment: `sentinel(action: "threats")`
5. Generate unified dashboard

### Health Workflow (FPPS 5-Point Consensus)
1. **Pattern**: Check container status patterns
2. **AST**: Verify boot state machine transitions
3. **Statistical**: Query Zenoh metrics for anomalies
4. **Binary**: Verify FFI bridge operational
5. **LineByLine**: Check each container health endpoint
All 5 MUST agree (SC-VAL-003)

### Verify Workflow (2oo3 Voting)
1. **Live Node**: Check actual container state
2. **Shadow Node**: Compare with Digital Twin state
3. **Formal Model**: Verify invariants via `zenoh_query(action: "verify")`
Consensus: 2 out of 3 must agree (SC-SIL6-006)

### Emergency Stop (SC-EMR-057: < 5 seconds)
```bash
podman-compose -f lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml kill
```

## 15-Container Architecture
| Container | Ports | Layer |
|-----------|-------|-------|
| indrajaal-db-prod | 5433 | L2 Data |
| indrajaal-obs-prod | 4317/9090/3000/3100 | L4 Observability |
| indrajaal-ex-app-1 | 4000/4001/6379 | L3 Application |
| zenoh-router-1..3 | 7447..7449 | L5 Control Plane |
| indrajaal-cortex | 9877 | L6 Cognitive |
| cepaf-bridge | 9876 | L5 Orchestration |
| indrajaal-chaya | 4002 | L4 Digital Twin |
| ml-runner-1..2 | - | L3 ML Workers |

## Zenoh Health Topics
| Topic | Interval | Content |
|-------|----------|---------|
| indrajaal/health/{node} | 10s | Node health JSON |
| indrajaal/container/{name}/health | 30s | Container health |
| indrajaal/mesh/health | 30s | Global mesh health |
| indrajaal/cluster/events | Event-driven | Cluster state changes |

## Mathematical Foundation

**Graph Topology**: $G = (V, E)$ where $V$ = containers (15), $E$ = Zenoh connections

**DAG Acyclicity** (Kahn's algorithm): Boot order is a topological sort of $G$

**Fault Tree**: $P(\text{mesh\_fail}) = 1 - \prod_{i=1}^{n}(1 - P(\text{node\_fail}_i))$

**Quorum**: $Q(N) = \lfloor N/2 \rfloor + 1$ — minimum healthy nodes for consensus

**Availability**: $A_{mesh} = \prod_{i=1}^{k} A_i$ for $k$ serial dependencies, $A_{mesh} = 1 - \prod_{i=1}^{n}(1-A_i)$ for $n$ redundant

## STAMP Constraints
| ID | Key Requirement |
|----|-----------------|
| SC-SIL6-001 | Mesh boot MUST complete 5 stages |
| SC-SIL6-002 | Shutdown MUST checkpoint state |
| SC-SIL6-006 | 2oo3 voting MANDATORY |
| SC-SIL6-011 | Quorum = floor(N/2)+1 |
| SC-SIL6-015 | Apoptosis 6-phase protocol |
| SC-EMR-057 | Emergency stop < 5 seconds |
