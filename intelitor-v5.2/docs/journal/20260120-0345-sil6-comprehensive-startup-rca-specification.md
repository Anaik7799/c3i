# SIL-6 Comprehensive Startup RCA & Mathematical Specification

**Date**: 2026-01-20 03:45 CEST
**Version**: 21.3.0-SIL6
**Author**: Claude Opus 4.5
**Status**: ACTIVE

---

## Executive Summary

This specification documents a comprehensive 7-Level Root Cause Analysis (RCA) of the Indrajaal SIL-6 biomorphic mesh startup system, incorporating mathematical foundations from Graph Theory, Critical Path Method (CPM), Resource-Constrained Project Scheduling (RCPSP), Deterministic Finite Automata (DFA), Set Theory, Control Theory, Merkle Trees, Queuing Theory, Promise Theory, and Railway Oriented Programming.

---

## 1.0 7-Level Root Cause Analysis

### 1.1 RCA Findings Matrix

| Level | Issue | Root Cause | Impact (RPN) | Solution | Constraint |
|-------|-------|------------|--------------|----------|------------|
| **L1-Physical** | Port conflicts | No preflight scouring | 216 | `sa-scour` preflight | SC-BOOT-001 |
| **L2-Component** | Migration gaps | Missing Jidoka Gate 3 | 270 | Oban table verification | SC-BOOT-002 |
| **L3-Holon** | State vector loss | No SQLite persistence | 189 | DAG state tracking | SC-ZTEST-006 |
| **L4-Container** | Serial boot | No wave parallelization | 144 | 5-wave parallel boot | SC-SIL6-009 |
| **L5-Node** | Zenoh quorum fails | No 2oo3 verification | 189 | floor(N/2)+1 voting | SC-SIL6-006 |
| **L6-Cluster** | Digital Twin desync | 30s+ state lag | 168 | Real-time Zenoh pub/sub | SC-MESH-008 |
| **L7-Federation** | No rollback | Missing UCR Phase 4 | 252 | Transactional boot | SC-UCR-015 |

### 1.2 5-Why Analysis (L2 Migration Issue)

```
Why 1: App containers restart in loop
Why 2: Oban distributed coordination fails
Why 3: oban_peers table missing
Why 4: Migration verification skipped
Why 5: No Jidoka gate for migrations (ROOT CAUSE)
```

---

## 2.0 Mathematical Foundations

### 2.1 Graph Theory - Container DAG

**Definition**: Boot sequence modeled as Directed Acyclic Graph G = (V, E)

```
V = {db, obs, z1, z2, z3, zp, bridge, cortex, app1, app2, app3, chaya, ml1, ml2}
|V| = 14 containers

E = {(db→obs), (db→app1), (obs→app1), (z1→zp), (z2→zp), (z3→zp),
     (zp→bridge), (bridge→cortex), (zp→app1), (cortex→app1),
     (app1→app2), (app2→app3), (app1→chaya), (app1→ml1), (ml1→ml2)}
|E| = 15 dependencies
```

**Topological Sort (Kahn's Algorithm)**:
```
Wave 1: [db]
Wave 2: [obs, z1, z2, z3]
Wave 3: [zp, bridge]
Wave 4: [cortex, app1]
Wave 5: [app2, app3, chaya, ml1, ml2]
```

**Acyclicity Verification**:
$$\nexists \text{ path } p: v \to v \text{ for any } v \in V$$

### 2.2 Critical Path Method (CPM)

**Duration Estimates (seconds)**:
| Container | Optimistic | Most Likely | Pessimistic | Expected |
|-----------|------------|-------------|-------------|----------|
| db | 5 | 8 | 15 | 8.67 |
| obs | 8 | 12 | 20 | 12.67 |
| zenoh-* | 3 | 5 | 10 | 5.50 |
| bridge | 2 | 3 | 5 | 3.17 |
| cortex | 3 | 5 | 10 | 5.50 |
| app1 | 15 | 25 | 45 | 26.67 |
| app2/3 | 10 | 15 | 25 | 15.83 |
| chaya | 5 | 8 | 15 | 8.67 |
| ml-* | 3 | 5 | 10 | 5.50 |

**Critical Path**: db → obs → app1 → app2 → app3
**CPL = 8.67 + 12.67 + 26.67 + 15.83 + 15.83 = 79.67 seconds**

**Float Calculation**:
$$Float(v) = LS(v) - ES(v)$$

### 2.3 Resource-Constrained Project Scheduling (RCPSP)

**Resource Constraints**:
```fsharp
type ResourceConstraints = {
    MaxCPU: int           // 23 CPUs total
    MaxMemory: int        // 27GB RAM total
    MaxParallel: int      // 5 containers per wave
    ZenohQuorum: int      // floor(N/2)+1 = 2 minimum
}
```

**Resource Allocation**:
| Wave | Containers | CPU | Memory | Parallel |
|------|------------|-----|--------|----------|
| 1 | db | 2 | 4GB | 1 |
| 2 | obs, z1, z2, z3 | 4 | 8GB | 4 |
| 3 | zp, bridge | 2 | 2GB | 2 |
| 4 | cortex, app1 | 6 | 6GB | 2 |
| 5 | app2, app3, chaya, ml1, ml2 | 9 | 7GB | 5 |

### 2.4 Deterministic Finite Automata (DFA) - State Machine

**DFA Definition**: M = (Q, Σ, δ, q₀, F)

```
Q = {S0_Init, S1_Preflight, S2_Foundation, S3_Mesh, S4_Cognitive, S5_App, S6_HA, S7_Ready, S_Failed}
Σ = {start, preflight_pass, foundation_pass, mesh_quorum, cognitive_pass, app_healthy, ha_ready, failure}
q₀ = S0_Init
F = {S7_Ready}
```

**Transition Function δ**:
| Current State | Input | Next State |
|---------------|-------|------------|
| S0_Init | start | S1_Preflight |
| S1_Preflight | preflight_pass | S2_Foundation |
| S1_Preflight | failure | S_Failed |
| S2_Foundation | foundation_pass | S3_Mesh |
| S3_Mesh | mesh_quorum | S4_Cognitive |
| S4_Cognitive | cognitive_pass | S5_App |
| S5_App | app_healthy | S6_HA |
| S6_HA | ha_ready | S7_Ready |
| * | failure | S_Failed |

### 2.5 Set Theory - Configuration Management

**Configuration Universe**:
$$\mathcal{U} = \mathcal{P} \cup \mathcal{T} \cup \mathcal{R} \cup \mathcal{E}$$

Where:
- $\mathcal{P}$ = Ports = {4000, 4001, 4002, 5433, 6379, 7447, 7448, 7449, 9090, 9876, 9877, ...}
- $\mathcal{T}$ = Timeouts = {5000, 10000, 30000, 60000, 120000}
- $\mathcal{R}$ = Resources = {CPU: [1..4], Memory: [256MB..8GB]}
- $\mathcal{E}$ = Environment = {NO_TIMEOUT, PATIENT_MODE, SKIP_ZENOH_NIF, ...}

**Port Conflict Detection**:
$$\forall p_i, p_j \in \mathcal{P}: i \neq j \implies p_i \neq p_j$$

### 2.6 Control Theory - Feedback Loops

**PID Controller for Health**:
```
e(t) = HealthTarget - HealthActual
u(t) = Kp·e(t) + Ki·∫e(τ)dτ + Kd·de(t)/dt

Where:
- Kp = 0.5 (proportional gain)
- Ki = 0.1 (integral gain)
- Kd = 0.05 (derivative gain)
- HealthTarget = 0.95 (95%)
```

**Hysteresis Thresholds**:
```fsharp
type HysteresisConfig = {
    HealthyThreshold: float      // 0.80
    UnhealthyThreshold: float    // 0.60
    CriticalThreshold: float     // 0.40
    DeadThreshold: float         // 0.20
}
```

### 2.7 Merkle Trees - Configuration Integrity

**Configuration Hash Tree**:
```
                    [Root Hash]
                   /           \
          [Config Hash]     [State Hash]
         /      |      \       /    \
     [Ports] [Timeouts] [Env] [DB] [Zenoh]
```

**Verification**:
$$H_{root} = SHA3(H_{config} \| H_{state})$$
$$H_{config} = SHA3(H_{ports} \| H_{timeouts} \| H_{env})$$

### 2.8 Queuing Theory - Little's Law

**Startup Queue Model**:
$$L = \lambda \cdot W$$

Where:
- L = Average containers in boot queue
- λ = Container arrival rate (containers/second)
- W = Average boot time per container

**For Wave-Based Boot**:
- λ = 14 containers / 5 waves = 2.8 containers/wave
- W = 15.93 seconds average per wave
- L = 2.8 × 15.93 = 44.6 container-seconds utilization

### 2.9 Promise Theory - Container Dependencies

**Promise Algebra**:
```
Promise(db, obs): "I will provide PostgreSQL on 5433"
Promise(obs, db): "I accept your PostgreSQL promise"
Promise(zenoh[1..3], mesh): "I will form 2oo3 quorum"
Promise(app1, db): "I require DATABASE_URL"
Promise(app1, zenoh): "I require ZENOH_ROUTER_ENDPOINT"
```

**Composite Promises**:
$$P_{mesh} = P_{z1} \land P_{z2} \land P_{z3}$$
$$Quorum(P_{mesh}) = \sum P_i \geq 2$$

### 2.10 Railway Oriented Programming - Error Handling

**Result Type**:
```fsharp
type BootResult<'T> =
    | Success of 'T
    | Failure of BootError list

type BootError =
    | PortConflict of port: int
    | ContainerTimeout of name: string * timeout: int
    | QuorumFailure of healthy: int * required: int
    | MigrationMissing of table: string
    | HealthCheckFailed of endpoint: string
```

**Bind Operator (>>=)**:
```fsharp
let (>>=) result f =
    match result with
    | Success x -> f x
    | Failure errors -> Failure errors

// Boot pipeline
validatePreflight ()
>>= startFoundation
>>= establishMesh
>>= launchCognitive
>>= bootApplication
>>= enableHA
>>= verifyHomeostasis
```

---

## 3.0 State Vector Algebra

### 3.1 Definition

$$\vec{S} = [s_1, s_2, s_3, s_4, s_5, s_6] \in \{0, 1, \_\}^6$$

| Index | Component | 0 | 1 | _ |
|-------|-----------|---|---|---|
| 1 | Compile | Invalid | Valid | Pending |
| 2 | Migrations | Missing | Complete | Checking |
| 3 | Containers | Unhealthy | Healthy | Starting |
| 4 | Zenoh | Disconnected | Connected | Connecting |
| 5 | Health | Failing | Passing | Probing |
| 6 | Quorum | Lost | Achieved | Voting |

### 3.2 Valid Startup Predicate

$$ValidStartup(\vec{S}) \iff \prod_{i=1}^{6} s_i = 1$$

### 3.3 Stage-Specific State Vectors

| Stage | State Vector | Required Components |
|-------|--------------|---------------------|
| S0_Init | [_,_,_,_,_,_] | None |
| S1_Preflight | [1,_,_,_,_,_] | Compile |
| S2_Foundation | [1,1,1,_,_,_] | +Migrations, +Containers |
| S3_Mesh | [1,1,1,1,_,_] | +Zenoh |
| S4_App | [1,1,1,1,1,_] | +Health |
| S5_Ready | [1,1,1,1,1,1] | +Quorum |

### 3.4 Monotonicity Theorem

$$\forall i, t_1 < t_2: s_i(t_1) = 1 \implies s_i(t_2) = 1$$

(Once a component is valid, it remains valid unless failure)

---

## 4.0 Jidoka Quality Gates (自働化)

### 4.1 Seven Quality Gates

| Gate | Name | Check | HALT Condition | Recovery |
|------|------|-------|----------------|----------|
| G1 | Environment | .NET 10.0, Podman 5.4+, Ports | Missing dependency | Install dependency |
| G2 | F# Build | `dotnet build` 0 errors | Compilation error | Fix code |
| G3 | Migrations | oban_peers, oban_jobs exist | Table missing | Run migrations |
| G4 | Infrastructure | pg_isready, OTEL receiver | Container unhealthy | Restart container |
| G5 | Zenoh Quorum | 2oo3 voting (≥2 healthy) | Quorum lost | Wait/restart router |
| G6 | Application | /health 200 OK, Oban alive | Endpoint down | Check logs, restart |
| G7 | Homeostasis | FPPS 5-point (≥3/5) | Consensus failed | RCA, targeted fix |

### 4.2 FMEA Risk Priority Numbers

| Gate | Failure Mode | S | O | D | RPN | Mitigation |
|------|--------------|---|---|---|-----|------------|
| G1 | .NET missing | 9 | 2 | 9 | 162 | devenv.nix |
| G2 | F# compile error | 9 | 4 | 7 | 252 | CI gate |
| G3 | Migration missing | 9 | 5 | 6 | **270** | Jidoka halt |
| G4 | DB connection fail | 8 | 3 | 7 | 168 | Health retry |
| G5 | Zenoh quorum lost | 9 | 3 | 7 | 189 | 2oo3 voting |
| G6 | App crash loop | 8 | 4 | 6 | 192 | Supervisor |
| G7 | FPPS disagreement | 7 | 2 | 7 | 98 | RCA |

**Critical RPN Threshold**: 200 (G2, G3, G6 require immediate attention)

---

## 5.0 Centralized Configuration Structure

### 5.1 F# CentralizedConfig Module

```fsharp
module CentralizedConfig =

    module Ports =
        let phoenixPrimary = 4000
        let phoenixHA = [4003; 4005]
        let healthEndpoint = 4001
        let chaya = 4002
        let postgres = 5433
        let redis = 6379
        let zenohRouters = [7447; 7448; 7449]
        let zenohWS = [8448; 8449; 8450]
        let zenohREST = [8000; 8001; 8002]
        let cepafBridge = 9876
        let cortex = 9877
        let otelGrpc = 4317
        let otelHttp = 4318
        let prometheus = 9090
        let grafana = 3000
        let loki = 3100

    module Timeouts =
        let healthCheck = 5000        // ms
        let containerStart = 30000    // ms
        let bootTotal = 120000        // ms per SC-OPT-001
        let zenohConnect = 10000      // ms
        let quorumVoting = 15000      // ms
        let backoffIntervals = [| 100; 200; 400; 800; 1600; 3200; 5000 |]

    module Resources =
        let dbCPU = 2
        let dbMemory = "4g"
        let obsCPU = 2
        let obsMemory = "4g"
        let appCPU = 3
        let appMemory = "2g"
        let zenohCPU = 1
        let zenohMemory = "512m"

    module Environment =
        let noTimeout = "true"
        let patientMode = "enabled"
        let infinitePatience = "true"
        let skipZenohNif = "0"
        let zenohEnabled = "true"
        let schedulers = "+S 16:16 +SDio 16"

    module Quorum =
        let totalNodes = 3
        let minimumHealthy = 2    // floor(3/2)+1
        let votingTimeout = 15000

    module StateVector =
        let dimensions = 6
        let initialState = [| 0; 0; 0; 0; 0; 0 |]
        let targetState = [| 1; 1; 1; 1; 1; 1 |]
```

### 5.2 Configuration Validation

```fsharp
let validateConfig () : BootResult<unit> =
    let portSet = Set.ofList allPorts
    if Set.count portSet <> List.length allPorts then
        Failure [PortConflict 0]
    else
        Success ()
```

---

## 6.0 Zenoh Checkpoint Messaging

### 6.1 Boot Checkpoints (CP-BOOT-*)

| ID | Topic | Trigger | State Vector |
|----|-------|---------|--------------|
| CP-BOOT-01 | indrajaal/boot/preflight/start | Startup initiated | [0,0,0,0,0,0] |
| CP-BOOT-02 | indrajaal/boot/preflight/complete | DAG validated | [1,0,0,0,0,0] |
| CP-BOOT-03 | indrajaal/boot/foundation/db_ready | PostgreSQL healthy | [1,1,1,0,0,0] |
| CP-BOOT-04 | indrajaal/boot/foundation/obs_ready | Observability ready | [1,1,1,0,0,0] |
| CP-BOOT-05 | indrajaal/boot/mesh/quorum | 2oo3 achieved | [1,1,1,1,0,0] |
| CP-BOOT-06 | indrajaal/boot/cognitive/bridge | CEPAF connected | [1,1,1,1,0,0] |
| CP-BOOT-07 | indrajaal/boot/cognitive/cortex | Cortex online | [1,1,1,1,0,0] |
| CP-BOOT-08 | indrajaal/boot/app/seed_ready | App1 healthy | [1,1,1,1,1,0] |
| CP-BOOT-09 | indrajaal/boot/homeostasis/verified | FPPS pass | [1,1,1,1,1,1] |
| CP-BOOT-10 | indrajaal/boot/complete | Mesh operational | [1,1,1,1,1,1] |

### 6.2 Log Fallback (SC-ZTEST-008)

```
[ZTEST-CHECKPOINT] checkpoint={id} topic={topic} message={msg} state_vector={vec} timestamp={ts}
```

---

## 7.0 Performance Targets

| Stage | Target | Maximum | Constraint |
|-------|--------|---------|------------|
| S0_Preflight | 3s | 5s | SC-OPT-001 |
| S1_Foundation | 15s | 30s | SC-OPT-002 |
| S2_Mesh | 10s | 20s | SC-OPT-003 |
| S3_Cognitive | 8s | 15s | SC-OPT-004 |
| S4_App | 25s | 45s | SC-OPT-005 |
| S5_HA | 12s | 25s | SC-OPT-006 |
| **TOTAL** | **73s** | **140s** | SC-SIL6-001 |

**Latency Budget** (SC-ZTEST-005):
- Zenoh publish: <10ms
- Zenoh route: <15ms
- Zenoh subscribe: <10ms
- Process: <15ms
- Aggregate: <50ms
- **E2E Total**: <100ms

---

## 8.0 STAMP Constraints Summary

| ID | Constraint | Severity |
|----|------------|----------|
| SC-BOOT-001 | Environment verification passes | CRITICAL |
| SC-BOOT-002 | Infrastructure containers healthy | CRITICAL |
| SC-BOOT-003 | Zenoh mesh quorum achieved | CRITICAL |
| SC-BOOT-004 | Application seed operational | CRITICAL |
| SC-BOOT-005 | FPPS 5-point consensus | CRITICAL |
| SC-SIL6-001 | Boot completes in 5 stages | CRITICAL |
| SC-SIL6-006 | 2oo3 voting MANDATORY | CRITICAL |
| SC-MESH-003 | Transactional boot (rollback on fail) | CRITICAL |
| SC-ZTEST-006 | State vector in boot messages | HIGH |
| SC-ZTEST-008 | Log fallback when Zenoh unavailable | CRITICAL |
| SC-UCR-015 | Rollback path MUST exist | CRITICAL |

---

## 9.0 AOR Rules Summary

| ID | Rule |
|----|------|
| AOR-MESH-001 | Use `sa-mesh` for all mesh operations |
| AOR-MESH-002 | Checkpoint before shutdown |
| AOR-MESH-003 | Verify Zenoh on all nodes |
| AOR-ZTEST-002 | Publish checkpoints at all phases |
| AOR-ZTEST-008 | Log fallback before Zenoh attempt |
| AOR-FUNC-005 | Rollback on functional degradation |
| AOR-FUNC-008 | HALT on invariant violation (Jidoka) |

---

## 10.0 Implementation Checklist

- [x] 7-Level RCA completed
- [x] Mathematical foundations documented
- [x] State vector algebra defined
- [x] Jidoka quality gates specified
- [x] Centralized configuration structure
- [x] Zenoh checkpoint messaging defined
- [x] Performance targets set
- [x] STAMP constraints mapped
- [x] AOR rules documented
- [ ] F# orchestration code updated
- [ ] BDD tests for all containers
- [ ] Smoke tests executed
- [ ] 3 comprehensive review passes

---

## References

- CLAUDE.md §5.0 STAMP Constraints
- .claude/rules/zenoh-test-messaging.md
- .claude/rules/fsharp-sil6-mesh.md
- .claude/rules/functional-invariant.md
- lib/cepaf/scripts/ComprehensiveStartupOrchestrator.fsx
- lib/cepaf/scripts/EnhancedSwarmOrchestrator.fsx
- test/features/startup/*.feature
