# Panoptic Swarm Ignition & Multilayer Swarm Parallelization (SC-SWARM, SC-IGNITE)

## SUPREME MANDATE

**The system MUST default to Full Parallelization Multilayer Swarm mode for ALL commands, operations, and executions.**

## STAMP/AOR Reference
> SC-SWARM-001 to SC-SWARM-005, SC-IGNITE-001 to SC-IGNITE-008, AOR-SWARM-001, AOR-IGNITE-001
> Key: Panoptic Ignition uses F# `cepaf` engine for Genetic Re-Synthesis.
> Key: Task planning MUST use hierarchical numbering via `sa-plan`. Tasks MUST NEVER be deleted/overwritten.

---

## 1.0 Full Parallelization
- All compilations, tests, and orchestrations MUST utilize maximum available hardware concurrency.
- `ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16"` and `mix compile --jobs 16` are MANDATORY.
- SC-CPU-GOV OVERRIDES fixed parallelism when CPU > 80%.

## 2.0 Panoptic Swarm Ignition v2.0

### 2.1 Architecture Overview
The Panoptic Ignition pipeline is a 3-file F# system that orchestrates the 16-container SIL-6 Biomorphic Mesh:

| File | Lines | Purpose |
|------|-------|---------|
| `lib/cepaf/src/Cepaf/Mesh/PanopticIgnition.fs` | ~830 | Orchestrator: genome, synthesis, boot, health |
| `lib/cepaf/src/Cepaf/Mesh/BuildStreamMonitor.fs` | ~462 | Streaming podman build output parser |
| `lib/cepaf/src/Cepaf/Mesh/BuildHistory.fs` | ~317 | SQLite-backed persistent build timing + EMA |

**Total**: ~1,609 lines across 3 files.

### 2.2 15-Container SIL-6 Genome (sil6Genome)

Static YAML configurations are deprecated; mathematical F# ADTs define the "Genome" via the `ImageCategory` discriminated union:

```fsharp
type ImageCategory =
    | BuiltFromDockerfile of dockerfileName: string * dockerfilePath: string
    | PulledFromRegistry of registryImage: string
    | SharedImage of sourceContainer: string
```

**Complete Genome Map (16 containers)**:

| # | Container | Category | Source |
|---|-----------|----------|--------|
| 1 | indrajaal-db-prod | BuiltFromDockerfile | Dockerfile.db |
| 2 | indrajaal-obs-prod | BuiltFromDockerfile | Dockerfile.observability |
| 3 | indrajaal-ex-app-1 | BuiltFromDockerfile | Dockerfile.sopv51-app |
| 4 | cepaf-bridge | BuiltFromDockerfile | Dockerfile.cepaf-bridge |
| 5 | indrajaal-cortex | BuiltFromDockerfile | Dockerfile.cortex |
| 6 | zenoh-router | PulledFromRegistry | eclipse/zenoh:latest |
| 7 | indrajaal-ollama | PulledFromRegistry | ollama/ollama:latest |
| 8 | indrajaal-mojo | PulledFromRegistry | modular/max-serving:latest |
| 9 | zenoh-router-1 | SharedImage | zenoh-router |
| 10 | zenoh-router-2 | SharedImage | zenoh-router |
| 11 | zenoh-router-3 | SharedImage | zenoh-router |
| 12 | indrajaal-ex-app-2 | SharedImage | indrajaal-ex-app-1 |
| 13 | indrajaal-ex-app-3 | SharedImage | indrajaal-ex-app-1 |
| 14 | indrajaal-chaya | SharedImage | indrajaal-ex-app-1 |
| 15 | indrajaal-ml-runner-1 | SharedImage | indrajaal-ollama |
| 16 | indrajaal-ml-runner-2 | SharedImage | indrajaal-ollama |

**Category Counts**: 5 BuiltFromDockerfile + 3 PulledFromRegistry + 8 SharedImage = 16 total.

### 2.3 7-Tier Boot Hierarchy

Boot proceeds tier-by-tier with `Async.Parallel` within multi-container tiers (SC-SWARM-001):

| Tier | Containers | Health Check | Timeout |
|------|-----------|--------------|---------|
| 1: Zenoh Control Plane | zenoh-router | TCP port 7447 | 30s |
| 2: Database Layer | indrajaal-db-prod | pg_isready -p 5433 | 60s |
| 3: Observability | indrajaal-obs-prod | TCP port 4317 (OTEL) | 45s |
| 4: Quorum Routers | zenoh-router-1, -2, -3 | TCP port 7447 (PARALLEL) | 30s |
| 5: Cognitive Layer | indrajaal-cortex, cepaf-bridge | container inspect (PARALLEL) | 60s |
| 6: Seed + Twin + Ollama | indrajaal-ex-app-1, indrajaal-chaya, indrajaal-ollama | TCP 4000/4002/11434 (PARALLEL) | 60s |
| 7: HA + ML + Mojo | app-2, app-3, ml-runner-1, ml-runner-2, indrajaal-mojo | container inspect (PARALLEL) | 60s |

### 2.4 Image Staleness Detection

4-way skip logic for each container in `geneticResynthesis`:

```
EXISTS? ──NO──→ FULL SYNTHESIS (build/pull)
  │
  YES
  │
INTEGRAL? ──NO──→ REBUILD (Dockerfile drift detected)
  │
  YES
  │
FRESH? ──NO──→ REBUILD (image age > maxImageAgeHours, default 168h = 7 days)
  │
  YES
  │
SKIP ──→ Image is valid, no action needed
```

### 2.5 BuildHistory Persistence

SQLite-backed with WAL mode (SC-XHOLON-001) at `lib/cepaf/artifacts/build-history.db`:

- **EMA calculation**: `alpha=0.3` — updated on each successful build via UPSERT
- **Tables**: `build_history` (raw records) + `build_ema` (aggregated EMA per container)
- **BuildRecord fields**: ContainerName, Action, Success, DurationMs, ImageSizeBytes, CacheHits, CacheMisses, StepCount, Timestamp, Error
- **Action types**: "build", "pull", "shared", "skip", "boot"
- **ETA display**: Before synthesis, queries EMA for expected duration

### 2.6 Zenoh Telemetry

The Ignition Sequence publishes high-fidelity progress via Zenoh:

| Key Expression | Payload | When |
|---------------|---------|------|
| `indrajaal/ignition/progress` | JSON: container, phase, status | Each synthesis step |
| `indrajaal/ignition/thinking` | String: human-readable status | Real-time dashboard |
| `indrajaal/build/history` | JSON: BuildRecord | After each build |
| `indrajaal/health/{container}` | JSON: health check result | After each boot |

---

## 3.0 Autonomous Supervisor Mode
- Agents MUST operate in FULL AUTONOMOUS MODE and FULL PERMISSIONS MODE until the goal is complete.
- If an issue occurs, trigger the 7-Level Fractal RCA immediately.
- Agents MUST act as the "Supervisor Agent", monitoring the `indrajaal/ignition/progress` and `indrajaal/health/*` topics.

## 4.0 Task Planning (F#-ONLY)
- ALL task planning MUST use hierarchical numbering (e.g., 1.0, 1.1, 1.1.1).
- ALL tasks MUST be added via the F# Planning CLI (`sa-plan` / `Cepaf.Planning.CLI`).
- `mix todo` is STRICTLY FORBIDDEN.
- Existing tasks MUST NEVER be deleted or overwritten. Use Status Updates (Completed, Blocked, Failed).

---

## 5.0 STAMP Constraints (Ignition)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-IGNITE-001 | Genomic Re-Synthesis MUST perform step-by-step breakdown of container builds (L0-L1) | CRITICAL |
| SC-IGNITE-002 | Architectural control checks (L0-L7) MUST be enforced at every ignition stage | CRITICAL |
| SC-IGNITE-003 | 7-Level Fractal RCA MUST be executed automatically on any boot failure | HIGH |
| SC-IGNITE-004 | High-fidelity dashboard MUST show "Thinking" and real-time synthesis progress | HIGH |
| SC-IGNITE-005 | BuildHistory MUST persist build timing to SQLite with WAL mode and EMA estimation | HIGH |
| SC-IGNITE-006 | Multi-container tiers MUST boot in parallel via Async.Parallel (SC-SWARM-001) | HIGH |
| SC-IGNITE-007 | Image staleness detection MUST trigger rebuild when age > maxImageAgeHours (168h default) | MEDIUM |
| SC-IGNITE-008 | sil6Genome MUST cover all 16 containers across 3 ImageCategory variants | CRITICAL |

## 6.0 AOR Rules (Ignition)

| ID | Rule |
|----|------|
| AOR-IGNITE-001 | ALWAYS run `geneticResynthesis` before `igniteMesh` to ensure images are current |
| AOR-IGNITE-002 | NEVER skip health checks — every container MUST pass type-specific health verification |
| AOR-IGNITE-003 | ALWAYS call `BuildHistory.ensureSchema()` at start of geneticResynthesis |
| AOR-IGNITE-004 | ALWAYS record build results to BuildHistory for EMA feedback loop |
| AOR-IGNITE-005 | Tier boot failures MUST halt the pipeline — do not proceed to next tier |

---

## 7.0 Swarm Verification Integration

The Panoptic Ignition pipeline integrates with deep swarm verification via the `swarm_verify` MCP tool (SC-SWARM-VERIFY-001 to SC-SWARM-VERIFY-064). After ignition completes, verification SHOULD be run to confirm all 16 containers are healthy across all 7 actions and 8 fractal layers.

| Verification Action | Post-Ignition Coverage |
|---|---|
| `ooda` | 5-tier OODA compliance across all 16 containers |
| `observability` | Closed-loop pipeline: OTEL→Prometheus→Grafana→Zenoh |
| `control` | Control plane round-trip per container category |
| `agent_probe` | Embedded F# agent health + Zenoh subscriptions |
| `fractal` | L0-L7 layer depth with inter-layer consistency |
| `inject_trace` | Synthetic trace propagation across all 16 containers |
| `full` | Aggregate all above with compliance percentage |

**Full specification**: `.claude/rules/swarm-verification.md`
**Skill command**: `/swarm-verify [action] [options]`
**MCP tool**: `swarm_verify` via `sentinel-zenoh` MCP server
