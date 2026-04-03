# STAMP Safety Constraints for Distributed Mesh Architecture

**Document Control**

| Field | Value |
|-------|-------|
| Document ID | STAMP-DIST-001 |
| Version | 1.0.0 |
| Status | ACTIVE |
| Created | 2025-12-26T14:00:00+01:00 |
| Author | Cybernetic Architect |
| Classification | Safety-Critical |

---

## 1. Document Purpose

This document defines the STAMP (Systems-Theoretic Accident Model and Processes) safety constraints for the Indrajaal Distributed Mesh Architecture. These constraints ensure safe operation of the 6-Agent, 4-Worker, 1-Supervisor, 1-Dashboard architecture.

---

## 2. Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-26 | Cybernetic Architect | Initial release with 30 safety constraints |

---

## 3. Constraint Categories

### 3.1 FQUN Constraints (SC-DIST-001 to SC-DIST-010)

| ID | Constraint | Rationale | Verification |
|----|------------|-----------|--------------|
| SC-DIST-001 | All dynamic resources MUST have FQUN | Enables mesh-wide addressing | Unit test: FQUNTest |
| SC-DIST-002 | FQUNs MUST be Zenoh key-expression compatible | Enables pub/sub routing | Format validation |
| SC-DIST-003 | FQUNs MUST be deterministically derivable | Supports lookup without registry | Property test |
| SC-DIST-004 | FQUN registry MUST support mesh-wide lookup | Enables distributed discovery | Integration test |
| SC-DIST-005 | FQUN generation MUST complete < 1ms | Performance requirement | Benchmark test |
| SC-DIST-006 | FQUN collisions MUST be mathematically improbable | P(collision) < 10^-15 | Statistical analysis |
| SC-DIST-007 | FQUN format MUST be immutable once assigned | Referential integrity | Compile-time check |
| SC-DIST-008 | FQUN registry MUST survive node restart | Durability | Integration test |
| SC-DIST-009 | FQUN MUST contain node identifier | Distribution support | Format validation |
| SC-DIST-010 | FQUN MUST contain HLC timestamp | Causal ordering | Format validation |

### 3.2 Mesh Constraints (SC-MESH-001 to SC-MESH-010)

| ID | Constraint | Rationale | Verification |
|----|------------|-----------|--------------|
| SC-MESH-001 | Mesh supervisor MUST supervise all components | Unified management | Supervision test |
| SC-MESH-002 | Workers MUST be supervised by WorkerMesh | Worker lifecycle | Supervision test |
| SC-MESH-003 | Agents MUST be supervised by AgentMesh | Agent lifecycle | Supervision test |
| SC-MESH-004 | Mesh MUST restart failed components | Fault tolerance | Restart test |
| SC-MESH-005 | Mesh MUST publish health status every 30s | Observability | Telemetry test |
| SC-MESH-006 | Mesh MUST respond to control commands < 100ms | Responsiveness | Performance test |
| SC-MESH-007 | Mesh MUST support graceful shutdown | Clean termination | Shutdown test |
| SC-MESH-008 | Mesh MUST register its own FQUN | Self-referential | Init test |
| SC-MESH-009 | Mesh MUST handle component failures without cascade | Isolation | Failure test |
| SC-MESH-010 | Mesh status MUST reflect actual component states | Accuracy | State test |

### 3.3 Agent Constraints (SC-AGENT-001 to SC-AGENT-010)

| ID | Constraint | Rationale | Verification |
|----|------------|-----------|--------------|
| SC-AGENT-001 | All agents MUST implement BaseAgent behaviour | Consistency | Compile-time |
| SC-AGENT-002 | Agents MUST register FQUN on startup | Addressability | Init test |
| SC-AGENT-003 | Agents MUST publish heartbeat every 5s | Liveness | Heartbeat test |
| SC-AGENT-004 | Agents MUST unregister FQUN on termination | Cleanup | Terminate test |
| SC-AGENT-005 | Agents MUST respond to :ping within 100ms | Responsiveness | Ping test |
| SC-AGENT-006 | Agent commands MUST be logged | Auditability | Log test |
| SC-AGENT-007 | Agents MUST publish state every 10s | Observability | State test |
| SC-AGENT-008 | Agents MUST handle unknown commands gracefully | Robustness | Error test |
| SC-AGENT-009 | Agent metrics MUST be accessible | Monitoring | Metrics test |
| SC-AGENT-010 | Agent init failure MUST prevent startup | Fail-safe | Init test |

### 3.4 Worker Constraints (SC-WORKER-001 to SC-WORKER-010)

| ID | Constraint | Rationale | Verification |
|----|------------|-----------|--------------|
| SC-WORKER-001 | All workers MUST implement BaseWorker behaviour | Consistency | Compile-time |
| SC-WORKER-002 | Workers MUST register FQUN on startup | Addressability | Init test |
| SC-WORKER-003 | Workers MUST support job queuing | Workload management | Queue test |
| SC-WORKER-004 | Workers MUST implement backpressure | Overload protection | Backpressure test |
| SC-WORKER-005 | Worker job failures MUST be tracked | Observability | Metrics test |
| SC-WORKER-006 | Workers MUST support graceful shutdown | Clean termination | Shutdown test |
| SC-WORKER-007 | Worker queue depth MUST be bounded | Memory safety | Limit test |
| SC-WORKER-008 | Workers MUST publish metrics every 30s | Observability | Metrics test |
| SC-WORKER-009 | Worker job processing MUST be trackable | Traceability | Trace test |
| SC-WORKER-010 | Workers MUST handle job retry | Fault tolerance | Retry test |

---

## 4. Specific Agent Constraints

### 4.1 OODA Agent (SC-OODA-001 to SC-OODA-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-OODA-001 | OODA loop MUST complete in < 1s | Real-time control |
| SC-OODA-002 | Observations MUST be timestamped | Temporal ordering |
| SC-OODA-003 | Decisions MUST be logged with rationale | Auditability |
| SC-OODA-004 | Actions MUST be reversible or checkpointed | Recovery |
| SC-OODA-005 | Loop phases MUST be atomic | Consistency |

### 4.2 ACE Agent (SC-ACE-001 to SC-ACE-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-ACE-001 | MAPE-K loop MUST complete in < 5s | Adaptation speed |
| SC-ACE-002 | Monitor data MUST be validated | Data quality |
| SC-ACE-003 | Analysis MUST produce actionable insights | Utility |
| SC-ACE-004 | Plans MUST be validated before execution | Safety |
| SC-ACE-005 | Knowledge base MUST be persistent | Learning |

### 4.3 Cortex Agent (SC-CTX-001 to SC-CTX-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-CTX-001 | Stress scores MUST be normalized [0, 1] | Comparability |
| SC-CTX-002 | Reflex actions MUST complete < 50ms | Responsiveness |
| SC-CTX-003 | Homeostatic setpoints MUST be configurable | Flexibility |
| SC-CTX-004 | Sensor readings MUST be timestamped | Temporal ordering |
| SC-CTX-005 | Deviations MUST trigger alerts | Awareness |

### 4.4 Fractal Agent (SC-FRAC-001 to SC-FRAC-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-FRAC-001 | Log levels MUST be 0-4 (Critical to Debug) | Consistency |
| SC-FRAC-002 | Level changes MUST propagate to Zenoh | Distribution |
| SC-FRAC-003 | Log routing MUST complete < 1ms | Performance |
| SC-FRAC-004 | Batch flush MUST occur within timeout | Timeliness |
| SC-FRAC-005 | Boost mode MUST expire automatically | Safety |

### 4.5 CEPAF Agent (SC-CEPAF-001 to SC-CEPAF-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-CEPAF-001 | Container FQUNs MUST be generated | Addressability |
| SC-CEPAF-002 | Health checks MUST occur every 30s | Monitoring |
| SC-CEPAF-003 | Container operations MUST be logged | Auditability |
| SC-CEPAF-004 | Failed operations MUST be tracked | Reliability |
| SC-CEPAF-005 | Container state MUST sync to Zenoh | Visibility |

### 4.6 Sentinel Agent (SC-SEN-001 to SC-SEN-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-SEN-001 | Heartbeat MUST occur every 5s | Liveness |
| SC-SEN-002 | Quorum MUST be checked for writes | Consistency |
| SC-SEN-003 | Split-brain MUST be prevented | Safety |
| SC-SEN-004 | Leader election MUST use Raft consensus | Correctness |
| SC-SEN-005 | Dead nodes MUST be detected within 30s | Timeliness |

---

## 5. Worker Constraints

### 5.1 FLAME Worker (SC-FLAME-001 to SC-FLAME-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-FLAME-001 | Pool creation MUST complete < 5s | Responsiveness |
| SC-FLAME-002 | Job dispatch MUST complete < 10ms | Performance |
| SC-FLAME-003 | Pool scaling MUST respect cooldown | Stability |
| SC-FLAME-004 | Utilization MUST be tracked per pool | Optimization |
| SC-FLAME-005 | Pools MUST have FQUNs | Addressability |

### 5.2 Oban Worker (SC-OBAN-001 to SC-OBAN-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-OBAN-001 | Jobs MUST be persisted | Durability |
| SC-OBAN-002 | Retry policy MUST be enforced | Reliability |
| SC-OBAN-003 | Queues MUST support pause/resume | Control |
| SC-OBAN-004 | Job FQUNs MUST be generated | Traceability |
| SC-OBAN-005 | Failed jobs MUST be tracked | Observability |

### 5.3 Broadway Worker (SC-BWAY-001 to SC-BWAY-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-BWAY-001 | Pipeline creation MUST complete < 2s | Responsiveness |
| SC-BWAY-002 | Message latency MUST be < 100ms | Performance |
| SC-BWAY-003 | Batching MUST respect size/timeout | Efficiency |
| SC-BWAY-004 | Backpressure MUST prevent overflow | Safety |
| SC-BWAY-005 | Pipeline FQUNs MUST be generated | Addressability |

### 5.4 Batch Worker (SC-BATCH-001 to SC-BATCH-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-BATCH-001 | Batch atomicity MUST be ensured | Consistency |
| SC-BATCH-002 | Checkpoints MUST be saved periodically | Recovery |
| SC-BATCH-003 | Rollback MUST be supported | Error handling |
| SC-BATCH-004 | Progress MUST be tracked | Visibility |
| SC-BATCH-005 | Batch FQUNs MUST be generated | Traceability |

---

## 6. Dashboard Constraints (SC-DASH-001 to SC-DASH-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-DASH-001 | Status refresh MUST occur every 5s | Real-time |
| SC-DASH-002 | CEPAF integration MUST show containers | Visibility |
| SC-DASH-003 | Metrics MUST be aggregated from all sources | Completeness |
| SC-DASH-004 | Control commands MUST be executable | Operability |
| SC-DASH-005 | FQUN registry MUST be queryable | Discovery |

---

## 7. Zenoh Control Plane Constraints (SC-ZENOH-001 to SC-ZENOH-005)

| ID | Constraint | Rationale |
|----|------------|-----------|
| SC-ZENOH-001 | Control commands MUST route via Zenoh | Distribution |
| SC-ZENOH-002 | State MUST be published to Zenoh | Visibility |
| SC-ZENOH-003 | Heartbeats MUST use Zenoh topics | Liveness |
| SC-ZENOH-004 | Zenoh unavailability MUST be handled gracefully | Resilience |
| SC-ZENOH-005 | Topic naming MUST follow FQUN convention | Consistency |

---

## 8. Verification Matrix

| Constraint ID | Test Type | Test Location | Automated |
|---------------|-----------|---------------|-----------|
| SC-DIST-* | Unit/Property | test/distributed/fqun_test.exs | Yes |
| SC-MESH-* | Integration | test/distributed/mesh_test.exs | Yes |
| SC-AGENT-* | Unit | test/distributed/agents/*_test.exs | Yes |
| SC-WORKER-* | Unit | test/distributed/workers/*_test.exs | Yes |
| SC-DASH-* | Integration | test/distributed/dashboard_test.exs | Yes |
| SC-ZENOH-* | Integration | test/distributed/zenoh_test.exs | Yes |

---

## 9. Mathematical Invariants

### 9.1 FQUN Uniqueness

```
∀ fqun1, fqun2 ∈ FQUNRegistry:
  fqun1 ≠ fqun2 ⟺
    Layer(fqun1) ≠ Layer(fqun2) ∨
    Type(fqun1) ≠ Type(fqun2) ∨
    Namespace(fqun1) ≠ Namespace(fqun2) ∨
    Name(fqun1) ≠ Name(fqun2) ∨
    Instance(fqun1) ≠ Instance(fqun2)
```

### 9.2 Mesh Health

```
HealthStatus := |{c ∈ Components : Alive(c)}| / |Components|

Healthy ⟺ HealthStatus ≥ 0.9
Degraded ⟺ 0.5 ≤ HealthStatus < 0.9
Critical ⟺ HealthStatus < 0.5
```

### 9.3 Quorum

```
Quorum(n) := ⌊n/2⌋ + 1

QuorumMet ⟺ |AliveNodes| ≥ Quorum(|AllNodes|)
```

---

## 10. Compliance Statement

This STAMP constraints document is part of the Indrajaal safety-critical system specification. All constraints MUST be verified before deployment. Violations MUST trigger immediate remediation.

**Certification Status**: Pending verification of all 70 constraints.
