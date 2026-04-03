# SIL-6 Comprehensive Startup Mathematical Specification

## Document Control
| Field | Value |
|-------|-------|
| Version | 2.0.0 |
| Date | 2026-01-21 07:10 CEST |
| Author | Claude Opus 4.5 |
| Status | ACTIVE |
| STAMP | SC-BOOT-001 to SC-BOOT-100 |
| Compliance | IEC 61508 SIL-6 (Biomorphic Extended) |

---

## 1.0 Executive Summary

This specification defines the mathematically rigorous startup sequence for the Indrajaal SIL-6 Biomorphic Mesh system. It incorporates:

- **Graph Theory**: DAG with Kahn's algorithm for topological sorting
- **Critical Path Method (CPM)**: Optimal boot time calculation
- **Finite State Automata (DFA)**: Container lifecycle state machine
- **Control Theory**: Hysteresis for health check stability
- **Set Theory**: Configuration validation and completeness
- **Promise Theory**: Self-healing convergence guarantees
- **Railway Oriented Programming (ROP)**: Error handling composition

---

## 2.0 Mathematical Foundations

### 2.1 Boot Phase State Vector

**Definition**: The system state is represented by a 6-dimensional binary vector:

$$\vec{S} = [s_1, s_2, s_3, s_4, s_5, s_6] \in \{0, 1\}^6$$

where:
- $s_1$ = Compile status (1=successful)
- $s_2$ = Migrations status (1=applied)
- $s_3$ = Containers status (1=started)
- $s_4$ = Zenoh status (1=mesh operational)
- $s_5$ = Health status (1=all checks passing)
- $s_6$ = Quorum status (1=2oo3 achieved)

**Valid Startup Predicate**:
$$ValidStartup(\vec{S}) \iff \prod_{i=1}^{6} s_i = 1$$

**State Transition Function**:
$$\sigma: \vec{S} \times \mathcal{E} \to \vec{S}$$

where $\mathcal{E} = \{e_1, e_2, ..., e_n\}$ is the set of boot events.

**Monotonicity Theorem** (No regression allowed):
$$\forall i, t_1 < t_2: s_i(t_1) = 1 \implies s_i(t_2) = 1 \lor \text{Rollback}(t_2)$$

### 2.2 Container Dependency Graph (DAG)

**Definition**: Let $G = (V, E)$ be a directed acyclic graph where:
- $V = \{c_1, c_2, ..., c_{14}\}$ (14 containers)
- $E \subseteq V \times V$ (dependency edges)

**Topological Order Existence**:
$$\exists \tau: V \to \mathbb{N} \text{ such that } (u,v) \in E \implies \tau(u) < \tau(v)$$

**Kahn's Algorithm Complexity**: $O(|V| + |E|)$

**Cycle Detection Invariant**:
$$\nexists \text{ cycle in } G \iff |TopologicalSort(G)| = |V|$$

### 2.3 Critical Path Method (CPM)

For each container $c_i$ with duration $d_i$:

**Forward Pass**:
- $ES_i = \max_{j \in \text{pred}(i)} EF_j$
- $EF_i = ES_i + d_i$

**Backward Pass**:
- $LF_i = \min_{j \in \text{succ}(i)} LS_j$
- $LS_i = LF_i - d_i$

**Total Float**:
$$TF_i = LS_i - ES_i = LF_i - EF_i$$

**Critical Path**:
$$CP = \{c_i \mid TF_i = 0\}$$

**Project Duration**:
$$T_{total} = \max_{i} EF_i$$

### 2.4 Container Lifecycle DFA

**States**: $Q = \{NotFound, Created, Starting, Running, Healthy, Unhealthy, Stopping, Stopped, Failed, Degraded\}$

**Alphabet**: $\Sigma = \{Create, Start, HealthOk, HealthFail, Stop, Remove, Crash, Timeout, Degrade, Recover\}$

**Transition Function** $\delta: Q \times \Sigma \to Q$:

| Current State | Signal | Next State |
|---------------|--------|------------|
| NotFound | Create | Created |
| Created | Start | Starting |
| Starting | HealthOk | Running |
| Starting | HealthFail | Starting (retry) |
| Starting | Timeout | Failed |
| Running | HealthOk | Healthy |
| Running | HealthFail | Unhealthy |
| Healthy | HealthFail | Degraded |
| Degraded | HealthOk | Healthy |
| Degraded | HealthFail | Unhealthy |
| Unhealthy | HealthOk | Degraded |
| Unhealthy | Timeout | Failed |
| * | Stop | Stopping |
| Stopping | Timeout | Stopped |
| Stopped | Remove | NotFound |
| * | Crash | Failed |

**Accepting State**: $F = \{Healthy\}$

### 2.5 Hysteresis Control for Health Checks

**Configuration**:
```fsharp
type HysteresisConfig = {
    RequiredConsecutive: int  // N = 3 consecutive checks
    CheckIntervalMs: int      // T = 1000ms
    DebounceMs: int           // D = 500ms
    MaxHistory: int           // H = 100 checks
    DegradedThreshold: int    // K = 2 failures before degrade
}
```

**State Transition with Hysteresis**:
$$
Healthy(t) = \begin{cases}
1 & \text{if } \sum_{i=t-N+1}^{t} check(i) = N \\
0 & \text{if } \sum_{i=t-N+1}^{t} (1-check(i)) = N \\
Healthy(t-1) & \text{otherwise}
\end{cases}
$$

### 2.6 Quorum Mathematics

**Quorum Size for N nodes**:
$$Q(N) = \lfloor N/2 \rfloor + 1$$

For 3 Zenoh routers: $Q(3) = 2$ (2oo3 voting)

**Availability Function**:
$$A(N, f) = \begin{cases}
1 & \text{if } N - f \geq Q(N) \\
0 & \text{otherwise}
\end{cases}$$

**Probability of Quorum** (assuming independent failures with availability $p$):
$$P(quorum) = \sum_{k=Q(N)}^{N} \binom{N}{k} p^k (1-p)^{N-k}$$

For N=3, Q=2, p=0.99:
$$P(quorum) = \binom{3}{2}(0.99)^2(0.01) + \binom{3}{3}(0.99)^3 = 0.999702$$

### 2.7 Latency Budget Algebra

**Total E2E Latency Budget**: $L_{total} = 100ms$

**Composition**:
$$L_{total} = L_{publish} + L_{route} + L_{subscribe} + L_{process} + L_{aggregate}$$

**Budget Allocation**:
| Component | Budget | Constraint |
|-----------|--------|------------|
| $L_{publish}$ | 10ms | SC-ZTEST-003 |
| $L_{route}$ | 15ms | Network + router |
| $L_{subscribe}$ | 10ms | Zenoh delivery |
| $L_{process}$ | 15ms | Message parsing |
| $L_{aggregate}$ | 50ms | Dashboard update |

---

## 3.0 Boot Sequence Specification

### 3.1 Five-Phase Boot Model

| Phase | Name | Precondition | Postcondition | Timeout |
|-------|------|--------------|---------------|---------|
| S0 | Preflight | None | DAG validated, ports clear | 5s |
| S1 | Foundation | S0 complete | DB + Obs healthy | 30s |
| S2 | ZenohMesh | S1 complete | 2oo3 quorum achieved | 15s |
| S3 | Cognitive | S2 complete | Bridge + Cortex connected | 20s |
| S4 | Application | S3 complete | App seeds healthy | 60s |
| S5 | Homeostasis | S4 complete | Full system verified | 30s |

**Total Boot Time Target**: $T_{boot} \leq 120s$ (sequential)
**Optimized with Parallelization**: $T_{boot} \leq 90s$ (~25% savings)

### 3.2 Container Wave Architecture

```
WAVE 1 (Foundation - Sequential Critical)
├── indrajaal-db-prod
│   ├ IP: 172.28.0.20
│   ├ Port: 5433
│   ├ Memory: 4096MB
│   ├ Boot: 15s
│   ├ Dependencies: []
│   └ Criticality: P0
│
└── indrajaal-obs-prod (Parallel with DB after network ready)
    ├ IP: 172.28.0.30
    ├ Ports: 4317, 4318, 9090, 3000, 3100, 8123
    ├ Memory: 10240MB
    ├ Boot: 45s
    ├ Dependencies: []
    └ Criticality: P1

WAVE 2 (Control Plane - Parallel, 2oo3 Required)
├── zenoh-router-1 (IP: 172.28.0.40, Port: 7447)
├── zenoh-router-2 (IP: 172.28.0.41, Port: 7448)
└── zenoh-router-3 (IP: 172.28.0.42, Port: 7449)
    ├ Memory: 512MB each
    ├ Boot: 5s each
    ├ Dependencies: [indrajaal-db-prod]
    └ Criticality: P0 (Critical for quorum)

WAVE 3 (Cognitive Plane - Sequential after Quorum)
├── cepaf-bridge
│   ├ IP: 172.28.0.50
│   ├ Port: 9876
│   ├ Dependencies: [zenoh-router-1, zenoh-router-2, zenoh-router-3]
│   └ Criticality: P1
│
└── indrajaal-cortex
    ├ IP: 172.28.0.60
    ├ Port: 9877
    ├ Dependencies: [cepaf-bridge]
    └ Criticality: P1

WAVE 4 (Application Seed - Sequential Primary)
└── indrajaal-ex-app-1
    ├ IP: 172.28.0.10
    ├ Ports: 4000, 4001, 6379
    ├ Memory: 4096MB
    ├ Boot: 30s
    ├ Dependencies: [indrajaal-db-prod, indrajaal-obs-prod, cepaf-bridge]
    └ Criticality: P0

WAVE 5 (HA + Satellites - Parallel Non-Critical)
├── indrajaal-ex-app-2 (IP: 172.28.0.11)
├── indrajaal-ex-app-3 (IP: 172.28.0.12)
├── indrajaal-chaya (IP: 172.28.0.70, Port: 4002)
├── indrajaal-ml-runner-1 (IP: 172.28.0.80)
└── indrajaal-ml-runner-2 (IP: 172.28.0.81)
    ├ Dependencies: [indrajaal-ex-app-1]
    └ Criticality: P1-P2
```

### 3.3 State Vector Transitions

```
Phase      | State Vector          | Meaning
-----------|-----------------------|------------------
Initial    | [0,0,0,0,0,0]        | Preflight pending
S0 Done    | [1,0,0,0,0,0]        | Compile verified
S1 Done    | [1,1,1,0,0,0]        | DB + Obs ready
S2 Done    | [1,1,1,1,0,0]        | Zenoh mesh formed
Quorum     | [1,1,1,1,0,1]        | 2oo3 achieved
S3 Done    | [1,1,1,1,0,1]        | Cognitive plane up
S4 Done    | [1,1,1,1,1,1]        | App healthy
S5 Done    | [1,1,1,1,1,1]        | Homeostasis verified
```

---

## 4.0 Checkpoint Messaging Specification

### 4.1 Boot Checkpoints (CP-BOOT-*)

| ID | Topic | Trigger | State Vector Delta |
|----|-------|---------|-------------------|
| CP-BOOT-01 | `indrajaal/boot/preflight/start` | Boot initiated | [0,0,0,0,0,0] |
| CP-BOOT-02 | `indrajaal/boot/preflight/complete` | DAG validated | [1,0,0,0,0,0] |
| CP-BOOT-03 | `indrajaal/boot/foundation/db_ready` | PostgreSQL healthy | +$s_2$, +$s_3$ |
| CP-BOOT-04 | `indrajaal/boot/foundation/obs_ready` | Observability healthy | verify $s_3$ |
| CP-BOOT-05 | `indrajaal/boot/mesh/quorum` | 2oo3 achieved | +$s_4$, +$s_6$ |
| CP-BOOT-06 | `indrajaal/boot/cognitive/bridge` | CEPAF connected | verify $s_4$ |
| CP-BOOT-07 | `indrajaal/boot/cognitive/cortex` | Cortex online | verify $s_4$ |
| CP-BOOT-08 | `indrajaal/boot/app/seed_ready` | App-1 healthy | +$s_5$ |
| CP-BOOT-09 | `indrajaal/boot/homeostasis/verified` | All checks pass | verify all |
| CP-BOOT-10 | `indrajaal/boot/complete` | Boot successful | [1,1,1,1,1,1] |

### 4.2 Message Schema (JSON)

```json
{
  "checkpoint": "CP-BOOT-XX",
  "topic": "indrajaal/boot/{phase}/{event}",
  "message": "Human-readable description",
  "state_vector": "[1,1,1,0,0,0]",
  "timestamp": "2026-01-21T07:10:00.000Z",
  "phase": 1,
  "duration_ms": 1500,
  "container": "indrajaal-db-prod",
  "details": {
    "health_endpoint": "http://localhost:5433",
    "response_code": 200,
    "latency_ms": 45
  },
  "schema_version": "2.0.0"
}
```

### 4.3 Fallback Log Format (SC-ZTEST-008)

```
[ZTEST-CHECKPOINT] checkpoint={id} topic={topic} message={msg} state_vector={vec} timestamp={ts}
```

**Regex for Parsing**:
```regex
\[ZTEST-CHECKPOINT\] checkpoint=(?<checkpoint>[^\s]+) topic=(?<topic>[^\s]+) message=(?<message>[^\s]+) state_vector=(?<state_vector>\[[^\]]+\]) timestamp=(?<timestamp>[^\s]+)
```

---

## 5.0 Jidoka (Autonomation) Protocol

### 5.1 Stop-on-Defect Rules

| Condition | Action | Recovery |
|-----------|--------|----------|
| Compile error | HALT, log, alert | Fix and retry |
| DAG cycle detected | HALT, reject config | Manual intervention |
| P0 container fails | HALT wave, rollback | Restart from checkpoint |
| Quorum breach (< 2/3) | HALT app boot | Wait for recovery |
| Health check timeout | Retry with backoff | After 3 failures, escalate |
| State vector regression | IMMEDIATE HALT | Full rollback |

### 5.2 ANDON Signals (Visual Indicators)

```
GREEN  = Normal operation, all checks passing
YELLOW = Degraded state, non-critical failure
RED    = Critical failure, boot halted
BLUE   = Manual intervention required
```

### 5.3 Poka-Yoke (Error Prevention)

1. **Port Collision Prevention**: Pre-scour all ports before boot
2. **Dependency Validation**: Verify all dependencies before start
3. **Config Validation**: Type-check configuration at compile time
4. **State Vector Guard**: Prevent invalid state transitions

---

## 6.0 Hardening Specifications

### 6.1 Gap Remediations

| Gap ID | Description | Remediation | Priority |
|--------|-------------|-------------|----------|
| GAP-01 | Missing CP-BOOT-04 | Add obs_ready checkpoint | P0 |
| GAP-02 | No wave rollback | Implement transactional boot | P0 |
| GAP-03 | Hard 50ms timeout | Add retry with exponential backoff | P1 |
| GAP-04 | Fragile health checks | Implement hysteresis | P1 |
| GAP-05 | State not persisted | SQLite checkpoint storage | P0 |
| GAP-06 | No cascade on dep fail | Enforce dependency graph | P1 |
| GAP-07 | Single quorum check | Continuous quorum monitor | P0 |
| GAP-08 | No health hysteresis | Implement N-consecutive | P1 |
| GAP-09 | DAG check once | Re-validate per wave | P2 |
| GAP-10 | Metrics not aggregated | Auto-export on boot complete | P2 |

### 6.2 Configuration Centralization

**Single Source of Truth**: `lib/cepaf/src/Cepaf.Config/MeshConfig.fs`

**Eliminate Hardcoding**:
- Reference `MeshConfig.NetworkConfig.Ports.*` for all port values
- Reference `MeshConfig.TimeoutConfig.*` for all timeouts
- Reference `MeshConfig.ContainerConfig.*` for container specs

### 6.3 Error Recovery Protocol

**Railway Oriented Programming (ROP)**:

```fsharp
type BootResult<'T> =
    | Success of 'T * StateVector * Duration
    | Failure of BootError * StateVector * RollbackAction

let (>>=) result f =
    match result with
    | Success (value, state, duration) -> f value state duration
    | Failure (error, state, rollback) -> Failure (error, state, rollback)

let bootPhase phase f =
    try
        let checkpoint = checkpointBefore phase
        let result = f()
        checkpointAfter phase result
        Success (result, updateStateVector phase, measureDuration())
    with
    | ex ->
        logFailure phase ex
        Failure (BootError.fromException ex, currentStateVector(), rollbackTo checkpoint)
```

---

## 7.0 STAMP Constraints Summary

### 7.1 Boot Constraints (SC-BOOT-*)

| ID | Constraint | Severity |
|----|------------|----------|
| SC-BOOT-001 | State vector MUST be 6-dimensional binary | CRITICAL |
| SC-BOOT-002 | Monotonicity: no regression without rollback | CRITICAL |
| SC-BOOT-003 | DAG acyclicity MUST be verified before boot | CRITICAL |
| SC-BOOT-004 | Quorum = floor(N/2)+1 for N Zenoh nodes | CRITICAL |
| SC-BOOT-005 | Total boot time MUST be < 120s | HIGH |
| SC-BOOT-006 | P0 container failure MUST halt boot | CRITICAL |
| SC-BOOT-007 | State vector MUST be persisted after each phase | HIGH |
| SC-BOOT-008 | Health checks MUST use hysteresis (N=3) | HIGH |
| SC-BOOT-009 | All checkpoints MUST publish to Zenoh | HIGH |
| SC-BOOT-010 | Fallback log MUST be written before Zenoh | CRITICAL |

### 7.2 AOR Rules (AOR-BOOT-*)

| ID | Rule |
|----|------|
| AOR-BOOT-001 | ALWAYS verify state vector before phase transition |
| AOR-BOOT-002 | ALWAYS persist checkpoint before risky operation |
| AOR-BOOT-003 | NEVER skip dependency validation |
| AOR-BOOT-004 | ALWAYS implement rollback for P0 failures |
| AOR-BOOT-005 | ALWAYS use exponential backoff for retries |

---

## 8.0 Verification Matrix

### 8.1 Pre-Boot Verification

| Check | Method | Constraint |
|-------|--------|------------|
| Ports available | TCP probe | SC-BOOT-011 |
| Config valid | Type check | SC-BOOT-012 |
| DAG acyclic | Kahn's algorithm | SC-BOOT-003 |
| Dependencies present | File exists | SC-BOOT-013 |
| Environment complete | Env var check | SC-BOOT-014 |

### 8.2 Runtime Verification

| Check | Frequency | Constraint |
|-------|-----------|------------|
| Container health | 10s | SC-BOOT-008 |
| Quorum status | 10s | SC-BOOT-004 |
| State vector integrity | Per phase | SC-BOOT-001 |
| Checkpoint persisted | Per phase | SC-BOOT-007 |

---

## 9.0 Implementation Checklist

- [ ] Implement CP-BOOT-04 (obs_ready) checkpoint
- [ ] Add transactional rollback to wave failures
- [ ] Implement hysteresis health checks (N=3)
- [ ] Add state vector SQLite persistence
- [ ] Implement continuous quorum monitoring
- [ ] Centralize all port/timeout values to MeshConfig
- [ ] Add exponential backoff to health check retries
- [ ] Implement cascade failure on dependency breach
- [ ] Add per-wave DAG re-validation
- [ ] Auto-export metrics on boot completion

---

## 10.0 References

- `lib/cepaf/src/Cepaf/Mesh/SIL6BiomorphicOrchestrator.fs`
- `lib/cepaf/src/Cepaf/Mesh/ZenohCheckpoints.fs`
- `lib/cepaf/src/Cepaf/Mesh/DAG.fs`
- `lib/cepaf/src/Cepaf/Mesh/CPM.fs`
- `lib/cepaf/src/Cepaf/Mesh/FSM.fs`
- `lib/cepaf/src/Cepaf/Mesh/Hysteresis.fs`
- `lib/cepaf/src/Cepaf/Mesh/Core.fs`
- `lib/cepaf/src/Cepaf.Config/MeshConfig.fs`
- `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml`
- `.claude/rules/zenoh-test-messaging.md`
- `.claude/rules/fsharp-sil6-mesh.md`

---

*Generated by Claude Opus 4.5 for SIL-6 Biomorphic Mesh Startup Hardening*
