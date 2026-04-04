# Operational Architecture

## 1. Biomorphic Execution Mode (Default)

25 agents, 2-layer supervision. OODA step < 100ms (cycle < 30ms).

**Context Management**: 200K budget. Checkpoint at 75K (37%). /compact at 150K (75%). Minimal mode at 180K (90%).

**Agent Hierarchy**: EXEC-001 (orchestrator, opus) -> 4 supervisors (context/domain/test/quality, sonnet) -> 20 workers (compile/test/credo/fix/doc/explore, haiku)

**Quality Gates** (before task complete): 0 compile errors+warnings, format check, credo strict, all tests pass, STAMP verified.

## 2. Panoptic Swarm Ignition (SC-IGNITE)

F# engine orchestrates 16-container SIL-6 Biomorphic Mesh.

**Files**: PanopticIgnition.fs (~830 lines) + BuildStreamMonitor.fs (~462) + BuildHistory.fs (~317)

### 16-Container Genome (sil6Genome)
| # | Container | Category | Source |
|---|-----------|----------|--------|
| 1-5 | db-prod, obs-prod, ex-app-1, cepaf-bridge, cortex | BuiltFromDockerfile | Various Dockerfiles |
| 6-8 | zenoh-router, ollama, mojo | PulledFromRegistry | eclipse/zenoh, ollama/ollama, modular/max-serving |
| 9-16 | zenoh-router-1/2/3, ex-app-2/3, chaya, ml-runner-1/2 | SharedImage | From items 6,3,7 |

### 7-Tier Boot Hierarchy
1. Zenoh Control Plane (zenoh-router, TCP 7447, 30s)
2. Database (db-prod, pg_isready 5433, 60s)
3. Observability (obs-prod, TCP 4317, 45s)
4. Quorum Routers (zenoh-router-1/2/3, PARALLEL, 30s)
5. Cognitive (cortex + cepaf-bridge, PARALLEL, 60s)
6. Seed + Twin (ex-app-1 + chaya + ollama, PARALLEL, 60s)
7. HA + ML (app-2/3 + ml-runners + mojo, PARALLEL, 60s)

**Image Staleness**: EXISTS? -> INTEGRAL? -> FRESH (<168h)? -> SKIP or REBUILD
**BuildHistory**: SQLite WAL at lib/cepaf/artifacts/build-history.db, EMA alpha=0.3

### Zenoh Topics
`indrajaal/ignition/progress` (JSON per step) | `indrajaal/ignition/thinking` (human-readable) | `indrajaal/build/history` (BuildRecord) | `indrajaal/health/{container}` (health check)

## 3. Swarm Verification (SC-SWARM-VERIFY)

ALL 16 containers verified across 7 actions and 8 fractal layers (L0-L7).

**MCP Tool**: `swarm_verify` with action parameter

| Action | What it verifies |
|--------|-----------------|
| ooda | 5-tier OODA: Agent(<30ms) Intelligence(<100ms) Knowledge(<1ms) Cortex(<50ms) Strategy(<1s) |
| observability | Pipeline: OTEL(4317) -> Prometheus(9090) -> Grafana(3000) -> Zenoh(7447) -> Dashboard |
| control | Command -> Zenoh -> container -> feedback round-trip per category |
| agent_probe | Embedded F# agent health + Zenoh subscriptions |
| fractal | L0-L7 primary checks + baseline for all non-primary containers |
| inject_trace | Synthetic trace propagation across all 16 containers |
| full | Aggregate all above with compliance percentage |

**Capability partitioning**: OODA-capable (6): ex-app-1/2/3, chaya, cortex, cepaf-bridge. Non-capable get baseline liveness (alive + port + processes + uptime + Zenoh).

**Container categories**: ElixirApp(4) FsharpBridge(1) FsharpCortex(1) ZenohRouter(4) Database(1) Observability(1) AiCompute(2) MlRunner(2)

## 4. Zenoh Telemetry (SC-ZENOH)

**Zenoh MUST be running at ALL times on ALL nodes.** SKIP_ZENOH_NIF=0 is MANDATORY.

| ID | Constraint | Severity |
|----|------------|----------|
| SC-ZENOH-001 | Zenoh NIF MUST be loaded on ALL nodes | CRITICAL |
| SC-ZENOH-002 | Zenoh router MUST be reachable from ALL app nodes | CRITICAL |
| SC-ZENOH-003 | ZenohTelemetrySubscriber MUST be connected | CRITICAL |
| SC-ZENOH-007 | Zenoh health included in /health endpoint | CRITICAL |
| SC-ZENOH-008 | Container MUST NOT start if Zenoh unavailable | CRITICAL |

**Startup**: zenoh-router(7447) -> health pass -> app starts -> NIF loads -> subscriber connects -> /health reports zenoh: connected -> joins cluster

**Key expressions**: `indrajaal/health/{node}` `indrajaal/metrics/{node}/**` `indrajaal/logs/{node}/**` `indrajaal/cluster/events` `indrajaal/sentinel/threats` `indrajaal/prajna/kpi`

**Violation**: CRITICAL ALERT -> BLOCK deployments -> ESCALATE -> LOG to Immutable Register -> auto-remediation attempt
