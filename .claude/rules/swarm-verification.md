# Swarm Verification Protocol (SC-SWARM-VERIFY)

## SUPREME MANDATE

**ALL 16 SIL-6 genome containers MUST be verified across ALL 7 verification actions and ALL 8 fractal layers (L0-L7).**

Verification uses capability-based partitioning: containers with full capability receive deep verification; all others receive baseline liveness checks. No container is ever excluded from any verification action.

---

## 1.0 STAMP Constraints (SC-SWARM-VERIFY)

### 1.1 Core Verification Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-001 | ALL 16 genome containers MUST be included in every verification action | CRITICAL |
| SC-SWARM-VERIFY-002 | OODA verification MUST cover 5 tiers (Agent/Intelligence/Knowledge/Cortex/Strategy) | CRITICAL |
| SC-SWARM-VERIFY-003 | Observability pipeline MUST verify closed-loop: OTEL → Prometheus → Grafana → Zenoh → Dashboard | CRITICAL |
| SC-SWARM-VERIFY-004 | Control plane verification MUST include command → Zenoh → container → feedback round-trip | HIGH |
| SC-SWARM-VERIFY-005 | Agent probe MUST connect to embedded F# agent and query health/capabilities | HIGH |
| SC-SWARM-VERIFY-006 | Fractal verification MUST verify all 8 layers (L0-L7) with inter-layer consistency | CRITICAL |
| SC-SWARM-VERIFY-007 | Full verification MUST aggregate all sub-verification results with compliance percentage | HIGH |
| SC-SWARM-VERIFY-008 | Trace injection MUST verify per-container trace propagation for all 16 containers | HIGH |

### 1.2 Container Coverage Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-010 | ContainerCategory DU MUST classify all 16 containers into 8 categories | CRITICAL |
| SC-SWARM-VERIFY-011 | ElixirApp category MUST include: ex-app-1, ex-app-2, ex-app-3, chaya | HIGH |
| SC-SWARM-VERIFY-012 | FsharpBridge category MUST include: cepaf-bridge | HIGH |
| SC-SWARM-VERIFY-013 | FsharpCortex category MUST include: indrajaal-cortex | HIGH |
| SC-SWARM-VERIFY-014 | ZenohRouter category MUST include: zenoh-router, zenoh-router-1, -2, -3 | HIGH |
| SC-SWARM-VERIFY-015 | Database category MUST include: indrajaal-db-prod | HIGH |
| SC-SWARM-VERIFY-016 | Observability category MUST include: indrajaal-obs-prod | HIGH |
| SC-SWARM-VERIFY-017 | AiCompute category MUST include: indrajaal-ollama, indrajaal-mojo | HIGH |
| SC-SWARM-VERIFY-018 | MlRunner category MUST include: indrajaal-ml-runner-1, indrajaal-ml-runner-2 | HIGH |

### 1.3 Capability-Based Partitioning Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-020 | OODA-capable containers (6): ex-app-1, ex-app-2, ex-app-3, chaya, cortex, cepaf-bridge | HIGH |
| SC-SWARM-VERIFY-021 | F# agent containers (6): ex-app-1, ex-app-2, ex-app-3, chaya, cepaf-bridge, cortex | HIGH |
| SC-SWARM-VERIFY-022 | Non-capable containers MUST receive baseline liveness verification (alive + port + processes + uptime + Zenoh) | CRITICAL |
| SC-SWARM-VERIFY-023 | Capability partitioning MUST NOT exclude any container from any action | CRITICAL |

### 1.4 OODA Tier Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-030 | Agent tier latency MUST be < 30ms | HIGH |
| SC-SWARM-VERIFY-031 | Intelligence tier latency MUST be < 100ms | HIGH |
| SC-SWARM-VERIFY-032 | Knowledge tier latency MUST be < 1ms (ETS semantic cache) | HIGH |
| SC-SWARM-VERIFY-033 | Cortex tier latency MUST be < 50ms | HIGH |
| SC-SWARM-VERIFY-034 | Strategy tier latency MUST be < 1000ms | MEDIUM |

### 1.5 Fractal Layer Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-040 | L0 Constitutional MUST verify guardian, constitution hash, psi invariants, founder directive | CRITICAL |
| SC-SWARM-VERIFY-041 | L1 Atomic/Debug MUST verify debug telemetry, NIF loaded, Zenoh session | HIGH |
| SC-SWARM-VERIFY-042 | L2 Component MUST verify GenServer health, supervisor trees, ETS tables | HIGH |
| SC-SWARM-VERIFY-043 | L3 Transaction MUST verify DB pool, SQLite WAL, DuckDB, Oban queues | HIGH |
| SC-SWARM-VERIFY-044 | L4 System MUST verify container health, port bindings, volumes, network | HIGH |
| SC-SWARM-VERIFY-045 | L5 Cognitive MUST verify cortex, OODA cycle, AI models, knowledge base | HIGH |
| SC-SWARM-VERIFY-046 | L6 Ecosystem MUST verify mesh topology, quorum routers, 2oo3 voting | CRITICAL |
| SC-SWARM-VERIFY-047 | L7 Federation MUST verify peer discovery, version vectors, attestation | HIGH |
| SC-SWARM-VERIFY-048 | Non-primary containers per layer MUST receive baseline fractal checks (alive + Zenoh + service) | CRITICAL |

### 1.6 Observability & Trace Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-050 | OTEL Collector on port 4317 MUST be reachable | CRITICAL |
| SC-SWARM-VERIFY-051 | OTEL Health on port 13133 MUST respond | HIGH |
| SC-SWARM-VERIFY-052 | Prometheus on port 9090 MUST return runtime info | HIGH |
| SC-SWARM-VERIFY-053 | Grafana on port 3000 MUST return health OK | MEDIUM |
| SC-SWARM-VERIFY-054 | Zenoh backbone on port 7447 MUST be reachable | CRITICAL |
| SC-SWARM-VERIFY-055 | Per-container trace propagation MUST verify category-specific telemetry | HIGH |

### 1.7 MCP Protocol Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-SWARM-VERIFY-060 | MCP tool `swarm_verify` MUST accept `action` as required parameter | HIGH |
| SC-SWARM-VERIFY-061 | MCP response MUST include `stamp` array with relevant SC-* references | MEDIUM |
| SC-SWARM-VERIFY-062 | MCP response MUST include `duration_ms` and `timestamp` fields | MEDIUM |
| SC-SWARM-VERIFY-063 | MCP dispatch MUST return `None` for unrecognized tool names (chain passthrough) | HIGH |
| SC-SWARM-VERIFY-064 | Invalid action MUST return `invalidParams` error with valid action list | MEDIUM |

---

## 2.0 AOR Rules (AOR-SWARM-VERIFY)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-SWARM-VERIFY-001 | ALWAYS verify all 16 containers in every action — never filter by capability alone | Mandatory |
| AOR-SWARM-VERIFY-002 | ALWAYS partition containers by capability: full verification for capable, baseline for rest | Mandatory |
| AOR-SWARM-VERIFY-003 | NEVER exclude non-running containers from the result — report them as "not running" | Mandatory |
| AOR-SWARM-VERIFY-004 | ALWAYS include Zenoh mesh visibility check in baseline verification | Mandatory |
| AOR-SWARM-VERIFY-005 | ALWAYS report per-container results, not just aggregate counts | Mandatory |
| AOR-SWARM-VERIFY-006 | ALWAYS use `nc -z` for TCP probing (TcpClient unavailable in .NET 10 minimal) | Mandatory |
| AOR-SWARM-VERIFY-007 | ALWAYS use `podman exec` for in-container commands, not direct shell | Mandatory |
| AOR-SWARM-VERIFY-008 | ALWAYS classify containers via `classifyContainer` before routing verification | Mandatory |
| AOR-SWARM-VERIFY-009 | ALWAYS verify fractal layer checks for primary containers + baseline for non-primary | Mandatory |
| AOR-SWARM-VERIFY-010 | NEVER hardcode container lists in handlers — reference `allContainers` constant | Mandatory |
| AOR-SWARM-VERIFY-011 | ALWAYS include `summary` field with `passed_checks` and `total_checks` in results | Mandatory |
| AOR-SWARM-VERIFY-012 | ALWAYS update SwarmVerificationState on each verification action | Mandatory |
| AOR-SWARM-VERIFY-013 | ALWAYS timeout podman commands at 15000ms to prevent blocking | Mandatory |
| AOR-SWARM-VERIFY-014 | ALWAYS report compliance percentage in full verification | Mandatory |
| AOR-SWARM-VERIFY-015 | ALWAYS include STAMP constraint references in response `stamp` array | Mandatory |

---

## 3.0 FMEA (Failure Mode and Effects Analysis)

### 3.1 Per-Action FMEA

| Failure Mode | Action | Severity | Occurrence | Detection | RPN | Mitigation |
|---|---|---|---|---|---|---|
| Container not running | All | 7 | 4 | 2 | 56 | Baseline reports "not running" with graceful degradation |
| Podman exec timeout (>15s) | All | 6 | 3 | 3 | 54 | 15s timeout with error message; does not block pipeline |
| Zenoh router unreachable | ooda, control, fractal | 9 | 2 | 1 | 18 | TCP probe with 2s timeout; reported as failed check |
| OTEL Collector down | observability, inject_trace | 8 | 3 | 1 | 24 | Health endpoint probe; pipeline reports partial completion |
| F# agent binary missing | agent_probe | 5 | 2 | 3 | 30 | Graceful fallback to baseline liveness check |
| Database pg_isready fails | control, fractal (L3) | 7 | 2 | 1 | 14 | Reported as degraded; doesn't halt verification |
| AI model offline | fractal (L5), inject_trace | 4 | 4 | 2 | 32 | Baseline alive check; no deep model verification |
| Wrong container category | All | 8 | 1 | 4 | 32 | Default to ElixirApp; comprehensive pattern matching |
| MCP JSON serialization error | All | 6 | 1 | 2 | 12 | try/catch with fallback error response |
| Stale state in SwarmVerificationState | full | 3 | 3 | 5 | 45 | State timestamps allow staleness detection |
| Network partition (container reachable but mesh disconnected) | control, ooda | 8 | 2 | 3 | 48 | Zenoh mesh check separate from container liveness |
| Prometheus scrape lag (15-30s) | inject_trace | 4 | 6 | 4 | 96 | Note in response about retry for full round-trip |
| MlRunner baseline insufficient | agent_probe | 3 | 5 | 3 | 45 | liveness + service check adequate for ML containers |
| Fractal baseline missing for non-primary containers | fractal | 7 | 1 | 2 | 14 | Baseline function covers alive + Zenoh + service |
| All containers down simultaneously | full | 9 | 1 | 1 | 9 | Full result reports 0 passed, 0% compliance |

### 3.2 Per-Category FMEA

| Category | Containers | Full Capability | Baseline Fallback | Max RPN |
|---|---|---|---|---|
| ElixirApp | 4 (app-1,2,3, chaya) | OODA, agent probe, all fractal layers | alive + port + processes + uptime + Zenoh | 56 |
| FsharpBridge | 1 (cepaf-bridge) | OODA, agent probe, L0 Constitutional | alive + Zenoh + bridge binary | 30 |
| FsharpCortex | 1 (indrajaal-cortex) | OODA, agent probe, L5 Cognitive | alive + Zenoh + cortex binary | 30 |
| ZenohRouter | 4 (router, -1, -2, -3) | L6 Ecosystem, mesh topology | alive + port 7447 + mesh | 18 |
| Database | 1 (indrajaal-db-prod) | L3 Transaction, pg_isready | alive + port 5433 + pg_stat | 14 |
| Observability | 1 (indrajaal-obs-prod) | Observability pipeline, OTEL collector | alive + port 4317 + health | 24 |
| AiCompute | 2 (ollama, mojo) | L5 Cognitive participant | alive + service check | 32 |
| MlRunner | 2 (ml-runner-1, -2) | None (baseline only) | alive + service check | 45 |

---

## 4.0 Coverage Matrix (Actions × Containers × Layers)

### 4.1 Action × Container Coverage

| Container | ooda | observability | control | agent_probe | fractal | inject_trace | full |
|---|---|---|---|---|---|---|---|
| zenoh-router | baseline | pipeline | category-aware | baseline | L6 primary + all baseline | backbone check | all |
| indrajaal-db-prod | baseline | pipeline | pg_isready | baseline | L3 primary + all baseline | pg_stat check | all |
| indrajaal-obs-prod | baseline | pipeline core | OTEL env | baseline | L4 primary + all baseline | collector core | all |
| zenoh-router-1 | baseline | pipeline | category-aware | baseline | L6 primary + all baseline | backbone check | all |
| zenoh-router-2 | baseline | pipeline | category-aware | baseline | L6 primary + all baseline | backbone check | all |
| zenoh-router-3 | baseline | pipeline | category-aware | baseline | L6 primary + all baseline | backbone check | all |
| indrajaal-ex-app-1 | full OODA 5-tier | pipeline | full Zenoh env | full agent probe | L0,L1,L2,L3,L5,L7 primary | OTEL env vars | all |
| indrajaal-ex-app-2 | full OODA 5-tier | pipeline | full Zenoh env | full agent probe | L1,L2 primary + all baseline | OTEL env vars | all |
| indrajaal-ex-app-3 | full OODA 5-tier | pipeline | full Zenoh env | full agent probe | L1,L2 primary + all baseline | OTEL env vars | all |
| indrajaal-chaya | full OODA 5-tier | pipeline | full Zenoh env | full agent probe | L1,L2 primary + all baseline | OTEL env vars | all |
| cepaf-bridge | full OODA 5-tier | pipeline | full Zenoh env | full agent probe | L0,L7 primary + all baseline | F# Zenoh telemetry | all |
| indrajaal-cortex | full OODA 5-tier | pipeline | full Zenoh env | full agent probe | L5 primary + all baseline | F# Zenoh telemetry | all |
| indrajaal-ollama | baseline | pipeline | alive check | baseline | L5 primary + all baseline | service alive | all |
| indrajaal-mojo | baseline | pipeline | alive check | baseline | all baseline | service alive | all |
| indrajaal-ml-runner-1 | baseline | pipeline | alive check | baseline | all baseline | service alive | all |
| indrajaal-ml-runner-2 | baseline | pipeline | alive check | baseline | all baseline | service alive | all |

### 4.2 Fractal Layer × Container Coverage

| Layer | Primary Containers | Baseline (remaining) | Total |
|---|---|---|---|
| L0 Constitutional | 2 (ex-app-1, cepaf-bridge) | 14 | 16 |
| L1 Atomic/Debug | 16 (allContainers) | 0 | 16 |
| L2 Component | 6 (oodaContainers) | 10 | 16 |
| L3 Transaction | 2 (ex-app-1, db-prod) | 14 | 16 |
| L4 System | 16 (allContainers) | 0 | 16 |
| L5 Cognitive | 3 (cortex, ollama, ex-app-1) | 13 | 16 |
| L6 Ecosystem | 4 (4x zenoh-router) | 12 | 16 |
| L7 Federation | 3 (zenoh-router, ex-app-1, cepaf-bridge) | 13 | 16 |

---

## 5.0 Architecture

### 5.1 Module: `Cepaf.Sentinel.MCP.Tools.SwarmVerificationTools`
- **File**: `lib/cepaf/src/Cepaf.Sentinel.MCP/Tools/SwarmVerificationTools.fs`
- **Lines**: ~1339
- **MCP Tool**: `swarm_verify` (single tool, 7 actions)
- **Dispatch**: Chain participant — returns `Some response` if handled, `None` to pass

### 5.2 Container Classification

```fsharp
type ContainerCategory =
    | ElixirApp      // ex-app-1, ex-app-2, ex-app-3, chaya
    | FsharpBridge   // cepaf-bridge
    | FsharpCortex   // indrajaal-cortex
    | ZenohRouter    // zenoh-router, zenoh-router-1, -2, -3
    | Database       // indrajaal-db-prod
    | Observability  // indrajaal-obs-prod
    | AiCompute      // indrajaal-ollama, indrajaal-mojo
    | MlRunner       // indrajaal-ml-runner-1, indrajaal-ml-runner-2
```

### 5.3 Verification Flow

```
swarm_verify(action) → dispatch(state, "swarm_verify", args, id)
    │
    ├─ "ooda"          → handleOoda → per-container OODA tier checks (full or baseline)
    ├─ "observability"  → handleObservability → 5-stage pipeline + per-container telemetry
    ├─ "control"       → handleControl → category-aware control plane round-trip
    ├─ "agent_probe"   → handleAgentProbe → F# agent deep probe or baseline liveness
    ├─ "fractal"       → handleFractal → L0-L7 primary checks + baseline for all non-primary
    ├─ "inject_trace"  → handleInjectTrace → 4-stage pipeline + per-container trace propagation
    └─ "full"          → handleFull → aggregate ooda + observability + control + agent + fractal
```

---

## 6.0 Zenoh Telemetry Topics

| Key Expression | Direction | Purpose |
|---|---|---|
| `indrajaal/swarm/verify/result` | Publish | Complete verification result JSON |
| `indrajaal/swarm/verify/ooda` | Publish | OODA tier compliance data |
| `indrajaal/swarm/verify/fractal/{level}` | Publish | Per-layer fractal results |
| `indrajaal/swarm/verify/health` | Publish | Aggregate swarm health score |

---

## 7.0 Related Constraints

| This Rule | Related | Relationship |
|---|---|---|
| SC-SWARM-VERIFY-001 | SC-IGNITE-008 | Genome coverage: verification matches ignition genome |
| SC-SWARM-VERIFY-002 | SC-OODA-001 to SC-OODA-009 | OODA tier definitions from cybernetic core |
| SC-SWARM-VERIFY-006 | SC-VER-074, SC-FRACTAL-001 | Fractal depth from 7-level verification framework |
| SC-SWARM-VERIFY-010 | SC-IGNITE-008 | ContainerCategory mirrors ImageCategory variants |
| SC-SWARM-VERIFY-022 | SC-SIL4-006 | Baseline checks ensure no container is invisible to SIL verification |
| SC-SWARM-VERIFY-050 | SC-MON-001 to SC-MON-006 | Observability constraints from monitoring framework |
| SC-SWARM-VERIFY-054 | SC-ZENOH-001 | Zenoh backbone from telemetry mandate |

---

## 8.0 Constitutional Alignment

- **Psi-0 (Existence)**: Verification ensures all 16 containers are alive and accounted for
- **Psi-3 (Verification Capability)**: The swarm verification IS the verification capability for the mesh
- **Omega-5 (Validation Consensus)**: Full verification aggregates 5+ subsystem verifications
- **SC-FUNC-002**: Core services operational — swarm verify is the primary evidence
- **SC-VER-031**: All containers healthy — swarm verify provides this metric

---

## 9.0 Enforcement

This rule is:
- **MANDATORY**: All swarm verification actions must include all 16 containers
- **AUDITED**: Verification results logged to Immutable Register via MCP
- **GATED**: Boot sequence completion depends on swarm verification passing
- **MEASURABLE**: Compliance percentage (0-100%) reported on every full verification
