# Agent Operating Rules (AOR) for Distributed Mesh Architecture

**Document Control**

| Field | Value |
|-------|-------|
| Document ID | AOR-DIST-001 |
| Version | 1.0.0 |
| Status | ACTIVE |
| Created | 2025-12-26T14:30:00+01:00 |
| Author | Cybernetic Architect |
| Classification | Operational |

---

## 1. Document Purpose

This document defines the Agent Operating Rules (AOR) for the Indrajaal Distributed Mesh Architecture. These rules govern the behavior of all agents, workers, supervisors, and the dashboard in the distributed system.

---

## 2. Change History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-26 | Cybernetic Architect | Initial release with 50 operating rules |

---

## 3. Core Operating Rules

### 3.1 FQUN Rules (AOR-FQUN-001 to AOR-FQUN-010)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FQUN-001 | Every component MUST register its FQUN before becoming operational | Compile-time + Init check |
| AOR-FQUN-002 | FQUN registration MUST include component metadata | Runtime validation |
| AOR-FQUN-003 | FQUN MUST be unregistered on component termination | Terminate callback |
| AOR-FQUN-004 | FQUN lookup failures MUST be logged at WARNING level | Logger policy |
| AOR-FQUN-005 | FQUN generation MUST use HLC for instance ID | Implementation |
| AOR-FQUN-006 | FQUN registry MUST be queried for duplicates before registration | Init check |
| AOR-FQUN-007 | FQUN format violations MUST halt component startup | Fail-fast |
| AOR-FQUN-008 | FQUN-related errors MUST be telemetered | Telemetry policy |
| AOR-FQUN-009 | FQUN MUST be included in all Zenoh publications | Publish policy |
| AOR-FQUN-010 | FQUN registry access MUST be thread-safe | ETS configuration |

### 3.2 Mesh Supervision Rules (AOR-MESH-001 to AOR-MESH-010)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-MESH-001 | DistributedMesh MUST start before any dependent services | Supervision order |
| AOR-MESH-002 | AgentMesh MUST use :one_for_one supervision strategy | Supervisor config |
| AOR-MESH-003 | WorkerMesh MUST use :one_for_one supervision strategy | Supervisor config |
| AOR-MESH-004 | Mesh MUST limit restarts to 10 per 60 seconds | Supervisor config |
| AOR-MESH-005 | Mesh MUST log all component start/stop events | Logger policy |
| AOR-MESH-006 | Mesh health check MUST NOT block for more than 1 second | Timeout policy |
| AOR-MESH-007 | Mesh MUST handle supervisor shutdown gracefully | Terminate callback |
| AOR-MESH-008 | Mesh control commands MUST be authenticated | Security policy |
| AOR-MESH-009 | Mesh status MUST be published every 30 seconds | Scheduler |
| AOR-MESH-010 | Mesh MUST propagate shutdown signals to all children | Supervisor behavior |

### 3.3 Agent Behavior Rules (AOR-AGENT-001 to AOR-AGENT-015)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-AGENT-001 | Agents MUST implement all BaseAgent callbacks | Compile-time |
| AOR-AGENT-002 | Agent init MUST complete within 5 seconds | Timeout |
| AOR-AGENT-003 | Agents MUST handle :ping synchronously | GenServer callback |
| AOR-AGENT-004 | Agent commands MUST return {:ok, result} or {:error, reason} | Type spec |
| AOR-AGENT-005 | Agents MUST increment command_count for each command | State update |
| AOR-AGENT-006 | Agent heartbeat MUST NOT perform blocking operations | Async policy |
| AOR-AGENT-007 | Agents MUST NOT modify FQUN after initialization | Immutability |
| AOR-AGENT-008 | Agent state MUST be serializable to JSON | State design |
| AOR-AGENT-009 | Agents MUST handle unknown commands with {:error, :unknown_command} | Error handling |
| AOR-AGENT-010 | Agent metrics MUST include uptime_seconds | Metrics spec |
| AOR-AGENT-011 | Agents MUST log at INFO level on startup | Logger policy |
| AOR-AGENT-012 | Agents MUST log at INFO level on termination | Logger policy |
| AOR-AGENT-013 | Agent-specific handle_agent_info MUST be implemented if needed | Optional callback |
| AOR-AGENT-014 | Agents MUST respect scheduled intervals for periodic tasks | Scheduler discipline |
| AOR-AGENT-015 | Agents MUST publish state after significant changes | State publishing |

### 3.4 Worker Behavior Rules (AOR-WORKER-001 to AOR-WORKER-015)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-WORKER-001 | Workers MUST implement all BaseWorker callbacks | Compile-time |
| AOR-WORKER-002 | Worker queue MUST NOT exceed max_queue_size | Backpressure |
| AOR-WORKER-003 | Workers MUST process jobs in FIFO order by default | Queue behavior |
| AOR-WORKER-004 | Worker job results MUST be {:ok, result}, {:error, reason}, or {:retry, reason} | Type spec |
| AOR-WORKER-005 | Workers MUST track jobs_submitted, jobs_completed, jobs_failed | Metrics |
| AOR-WORKER-006 | Workers MUST implement async job submission | API requirement |
| AOR-WORKER-007 | Worker retries MUST include backoff | Retry policy |
| AOR-WORKER-008 | Workers MUST NOT block on job processing for heartbeat | Async design |
| AOR-WORKER-009 | Workers MUST report queue depth in metrics | Observability |
| AOR-WORKER-010 | Workers MUST calculate success_rate accurately | Metrics accuracy |
| AOR-WORKER-011 | Workers MUST handle worker_init failure with {:stop, reason} | Fail-fast |
| AOR-WORKER-012 | Workers MUST log job failures at WARNING level | Logger policy |
| AOR-WORKER-013 | Workers MUST support submit_job and submit_job_async | API completeness |
| AOR-WORKER-014 | Workers MUST NOT process jobs when paused | State behavior |
| AOR-WORKER-015 | Workers MUST unregister FQUN on termination | Cleanup |

---

## 4. Specific Agent Rules

### 4.1 OODA Agent Rules (AOR-OODA-001 to AOR-OODA-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-OODA-001 | OODA loop phases MUST execute in order: Observe → Orient → Decide → Act | State machine |
| AOR-OODA-002 | Observations MUST be stored with timestamp | Data structure |
| AOR-OODA-003 | Orientation MUST consider historical context | Algorithm |
| AOR-OODA-004 | Decisions MUST be logged with confidence score | Logging |
| AOR-OODA-005 | Actions MUST be validated before execution | Pre-check |

### 4.2 ACE Agent Rules (AOR-ACE-001 to AOR-ACE-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-ACE-001 | MAPE-K phases MUST execute in order: Monitor → Analyze → Plan → Execute | State machine |
| AOR-ACE-002 | Knowledge base MUST be consulted before planning | Algorithm |
| AOR-ACE-003 | Plans MUST include rollback steps | Plan structure |
| AOR-ACE-004 | Execution MUST verify preconditions | Pre-check |
| AOR-ACE-005 | Knowledge updates MUST trigger adaptation | Feedback loop |

### 4.3 Cortex Agent Rules (AOR-CTX-001 to AOR-CTX-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CTX-001 | Stress calculation MUST use weighted sensor inputs | Algorithm |
| AOR-CTX-002 | Reflexes MUST be triggered by matching stimulus | Pattern matching |
| AOR-CTX-003 | Homeostasis MUST compare against setpoints | Control logic |
| AOR-CTX-004 | Tolerance violations MUST generate adjustments | Feedback |
| AOR-CTX-005 | Sensor readings MUST be validated for range | Input validation |

### 4.4 Fractal Agent Rules (AOR-FRAC-001 to AOR-FRAC-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FRAC-001 | Log level MUST be validated (0-4) | Input validation |
| AOR-FRAC-002 | Level changes MUST be published to Zenoh | Publish policy |
| AOR-FRAC-003 | Module-level overrides MUST take precedence | Priority logic |
| AOR-FRAC-004 | Boost expiry MUST restore original level | Timer callback |
| AOR-FRAC-005 | Route configuration MUST validate route names | Input validation |

### 4.5 CEPAF Agent Rules (AOR-CEPAF-001 to AOR-CEPAF-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CEPAF-001 | Container registration MUST generate FQUN | Registration logic |
| AOR-CEPAF-002 | Health checks MUST be scheduled automatically | Timer |
| AOR-CEPAF-003 | Container operations MUST update operation count | State update |
| AOR-CEPAF-004 | Container not found MUST return {:error, :not_found} | Error handling |
| AOR-CEPAF-005 | Health status MUST be published to Zenoh | Publish policy |

### 4.6 Sentinel Agent Rules (AOR-SEN-001 to AOR-SEN-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-SEN-001 | Node registration MUST update quorum size | State update |
| AOR-SEN-002 | Heartbeat MUST be published every 5 seconds | Timer |
| AOR-SEN-003 | Vote requests MUST validate term number | Consensus logic |
| AOR-SEN-004 | Dead nodes MUST be detected after 30 seconds | Health check |
| AOR-SEN-005 | Quorum loss MUST be logged at WARNING | Logger policy |

---

## 5. Worker-Specific Rules

### 5.1 FLAME Worker Rules (AOR-FLAME-001 to AOR-FLAME-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-FLAME-001 | Pool creation MUST generate pool FQUN | Registration |
| AOR-FLAME-002 | Pool scaling MUST respect cooldown period | Timer check |
| AOR-FLAME-003 | Dispatch MUST validate pool exists and is active | Pre-check |
| AOR-FLAME-004 | Utilization updates MUST trigger scaling check | State update |
| AOR-FLAME-005 | Pool destruction MUST unregister FQUN | Cleanup |

### 5.2 Oban Worker Rules (AOR-OBAN-001 to AOR-OBAN-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-OBAN-001 | Job scheduling MUST generate job FQUN | Registration |
| AOR-OBAN-002 | Job state transitions MUST be tracked | State machine |
| AOR-OBAN-003 | Retry MUST respect max_attempts | Policy check |
| AOR-OBAN-004 | Paused queues MUST NOT execute jobs | State check |
| AOR-OBAN-005 | Cancelled jobs MUST unregister FQUN | Cleanup |

### 5.3 Broadway Worker Rules (AOR-BWAY-001 to AOR-BWAY-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-BWAY-001 | Pipeline creation MUST generate pipeline FQUN | Registration |
| AOR-BWAY-002 | Buffer overflow MUST return {:error, :buffer_full} | Backpressure |
| AOR-BWAY-003 | Batch processing MUST update pipeline metrics | State update |
| AOR-BWAY-004 | Paused pipelines MUST NOT process messages | State check |
| AOR-BWAY-005 | Pipeline destruction MUST unregister FQUN | Cleanup |

### 5.4 Batch Worker Rules (AOR-BATCH-001 to AOR-BATCH-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-BATCH-001 | Batch creation MUST generate batch FQUN | Registration |
| AOR-BATCH-002 | Checkpoints MUST be saved at configured intervals | Scheduler |
| AOR-BATCH-003 | Rollback MUST restore from last checkpoint | Recovery logic |
| AOR-BATCH-004 | Batch failures MUST update failed count | State update |
| AOR-BATCH-005 | Batch cancellation MUST unregister FQUN | Cleanup |

---

## 6. Dashboard Rules (AOR-DASH-001 to AOR-DASH-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-DASH-001 | Dashboard MUST register FQUN on startup | Init |
| AOR-DASH-002 | Refresh MUST occur every 5 seconds | Timer |
| AOR-DASH-003 | Status MUST aggregate from all mesh sources | Data collection |
| AOR-DASH-004 | Control commands MUST delegate to DistributedMesh | Command routing |
| AOR-DASH-005 | Render MUST handle missing data gracefully | Error handling |

---

## 7. Zenoh Control Plane Rules (AOR-ZENOH-001 to AOR-ZENOH-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-ZENOH-001 | Publications MUST include timestamp | Payload structure |
| AOR-ZENOH-002 | Subscriptions MUST handle callback errors | Error handling |
| AOR-ZENOH-003 | Topic names MUST follow FQUN convention | Naming policy |
| AOR-ZENOH-004 | Zenoh unavailability MUST NOT crash components | Error handling |
| AOR-ZENOH-005 | Control commands MUST be validated before execution | Security |

---

## 8. Error Handling Rules (AOR-ERR-001 to AOR-ERR-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-ERR-001 | Errors MUST be logged with context | Logger policy |
| AOR-ERR-002 | Recoverable errors MUST NOT terminate components | Error handling |
| AOR-ERR-003 | Unrecoverable errors MUST propagate to supervisor | Fail-fast |
| AOR-ERR-004 | Error telemetry MUST be emitted | Telemetry |
| AOR-ERR-005 | Error messages MUST be actionable | Message design |

---

## 9. Performance Rules (AOR-PERF-001 to AOR-PERF-005)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-PERF-001 | Synchronous calls MUST timeout after 5 seconds | GenServer.call |
| AOR-PERF-002 | Heartbeat processing MUST complete < 10ms | Performance |
| AOR-PERF-003 | State serialization MUST NOT block | Async design |
| AOR-PERF-004 | FQUN lookup MUST complete < 1ms | Performance |
| AOR-PERF-005 | Batch operations MUST use efficient data structures | Design |

---

## 10. Compliance Statement

All components in the Distributed Mesh Architecture MUST comply with these Agent Operating Rules. Violations MUST be logged and may trigger automated remediation.

**Enforcement Level**: MANDATORY
**Audit Frequency**: Continuous (automated) + Quarterly (manual review)
