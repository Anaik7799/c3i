# C3I Planning Subsystem - Exhaustive Use Cases

## Document Purpose
This document defines every use case of the Planning subsystem, derived from complete analysis of the F# CEPAF implementation (7,500+ lines across 24 files) and the current Gleam C3I implementation (8 files, 24 pub functions). Each use case includes actors, preconditions, flow, postconditions, STAMP constraints, error modes, and Gleam implementation status.

---

## UC-PLAN-001: Create Task

**Actor:** Human, AI Agent, System Process
**Fractal Layer:** L3_TRANSACTION
**STAMP:** SC-ENFORCE-001, SC-SAFETY-001, SC-SYNC-PLAN-004
**Criticality:** HIGH

### Preconditions
- Planning.db schema exists (Tasks table with indexes)
- SafetyKernel is active
- Agent has valid RequestContext

### Main Flow
1. Agent submits title, optional priority (P0-P4), optional parent ID
2. PlanningEnforcer validates access (5-layer: agent classification, rate limit, circuit breaker, path check, pattern check)
3. SafetyKernel validates operation (Constitutional Psi-0..Psi-5, Omega-0, operational checks)
4. System generates UUID, parses priority (default P2), creates TaskItem with `Pending` status
5. Repository.saveTask executes `INSERT OR REPLACE INTO Tasks`
6. ZenohAdapter publishes `TaskCreated` event to `indrajaal/planning/events`
7. Backup: atomic write to PROJECT_TODOLIST.md
8. Sync: replicate to Chaya.db via `convertToChayaTask`

### Postconditions
- Task persisted in Planning.db with unique ID
- Task visible in PROJECT_TODOLIST.md
- TaskCreated event published to Zenoh (checkpoint CP-PLAN-01)
- Chaya.db has replica with status mapping (Pending -> "todo")

### Error Modes
| Error | FMEA RPN | Handling |
|-------|----------|----------|
| Agent denied by enforcer | 90 | Return `Error("Access denied: {reason}")` |
| Circuit breaker open | 120 | Return `CircuitOpen(agent_id, violation_count)` |
| Safety kernel veto | 189 | Return `Error("Safety violation: {check}")` |
| DB write failure | 144 | Return `Error("Database error")` |
| Zenoh publish failure | 45 | Fire-and-forget (logged, not blocking) |

### Gleam Status
| Step | F# Function | Gleam Equivalent | Status |
|------|------------|------------------|--------|
| Enforcement | `PlanningEnforcer.enforceAccess` | `enforcer.enforce_access` | PARTIAL (no rate limit, no config) |
| Safety | `SafetyKernel.validateOperation` | `safety_kernel.start` (actor) | PARTIAL (no constitutional checks) |
| Create | `Manager.addTask` | `task.create` | IMPLEMENTED |
| Persist | `Repository.saveTask` | `repository.save_task` | IMPLEMENTED |
| Zenoh | `ZenohAdapter.publish(TaskCreated)` | NOT IMPLEMENTED | MISSING |
| Backup | `Manager.updateBackup` | `parser.serialize_todolist` | PARTIAL (no atomic write) |
| Chaya sync | `Manager.syncTaskToChaya` | NOT IMPLEMENTED | MISSING |

---

## UC-PLAN-002: Update Task Status

**Actor:** Human, AI Agent, System Process
**Fractal Layer:** L3_TRANSACTION
**STAMP:** SC-ENFORCE-001, SC-SYNC-PLAN-007

### Preconditions
- Task exists in Planning.db
- New status is a valid transition (Pending->InProgress, InProgress->Completed, etc.)

### Main Flow
1. Agent submits task ID and new status string
2. PlanningEnforcer validates access
3. Repository.getTask looks up existing task
4. Parse new status, validate transition (no Completed->Pending)
5. Update task record, bump version
6. Repository.saveTask (upsert)
7. ZenohAdapter publishes `TaskUpdated` event
8. Backup + Chaya sync

### Postconditions
- Task status updated in Planning.db
- `updated_at` timestamp refreshed
- Version incremented
- If status = Completed, `completed_at` set

### Error Modes
| Error | Handling |
|-------|----------|
| Task not found | Return `Error("Task not found")` |
| Invalid transition | Return `InvalidTransition(from, to)` |
| Agent denied | Return `Denied(reason, violation)` |

### Gleam Status
| Step | Status |
|------|--------|
| Status update logic | IMPLEMENTED (`manager.update_task_status`) |
| Find by ID | IMPLEMENTED (`manager.find_task`) |
| Transition validation | PARTIAL (no `Blocked` handling) |
| Zenoh event | MISSING |

---

## UC-PLAN-003: Cold Start Initialization

**Actor:** System (boot sequence)
**Fractal Layer:** L4_SYSTEM
**STAMP:** SC-SYNC-PLAN-004, SC-SYNC-PLAN-014

### Preconditions
- System booting for the first time or after DB wipe

### Main Flow
1. `Repository.ensureDbExists()` creates Tasks table with indexes
2. Check if DB is empty AND PROJECT_TODOLIST.md exists on disk
3. If both: parse markdown file into TaskItem list
4. PlanningEnforcer validates cold-start import permission
5. Save all parsed tasks to DB
6. Publish `TaskCreated` events for each task
7. If DB already has data: skip import (idempotent)

### Gleam Status
| Step | Status |
|------|--------|
| DB schema creation | IMPLEMENTED (`repository.ensure_db_exists`) |
| Markdown parsing | IMPLEMENTED (`parser.parse_todolist`) |
| Conditional import | MISSING (no empty-check + import logic) |

---

## UC-PLAN-004: Destructive Operation (Clear All Tasks)

**Actor:** System Process (requires Guardian approval)
**Fractal Layer:** L0_CONSTITUTIONAL
**STAMP:** SC-SAFETY-001, SC-FUNC-003
**Criticality:** DAL-A / CRITICAL

### Preconditions
- SafetyKernel must be active
- Operation must pass ALL constitutional checks (Psi-0 through Psi-5)
- Operation must pass Founder's Directive (Omega-0)
- Guardian must be healthy and approve

### Main Flow
1. Build `OperationProposal` with `RequiresGuardian=true`, `RequiresConstitutional=true`
2. Constitutional checks:
   - Psi-0 (Existence): operation "delete_all" → FAIL
   - Psi-2 (History): operation "truncate" → FAIL
   - Psi-3 (Verification): operation "delete_block" → FAIL
   - Psi-5 (Truthfulness): operation "falsify_log" → FAIL
3. Operational checks: state consistency, audit trail, rollback capability
4. If ALL pass: generate Guardian token (SHA-256), execute DELETE FROM Tasks
5. If ANY fail: reject with safety event log

### Postconditions
- Either all tasks deleted with full audit trail
- Or operation rejected with SafetyEvent logged

### Gleam Status
| Step | Status |
|------|--------|
| Constitutional checks (Psi-0..5) | IMPLEMENTED (in safety_kernel actor) |
| Guardian approval | PARTIAL (token is placeholder) |
| Rollback wrapper | IMPLEMENTED (`execute_with_rollback`) |
| Emergency stop | MISSING |

---

## UC-PLAN-005: OODA Cycle Execution

**Actor:** System, Chaya Digital Twin
**Fractal Layer:** L5_COGNITIVE
**STAMP:** SC-OODA-001, SC-PLAN-022
**Criticality:** HIGH (must complete <100ms per SC-ORCH-004)

### Preconditions
- At least one data source (container health, metrics, events)

### Main Flow
1. **Observe**: Collect observations from health checks, metrics, events
   - `fromHealthCheck`: Healthy→Info, Unhealthy→Critical, NoHealthcheck→Warning
   - `fromMetric`: above-threshold→Warning, below→Info
   - `fromEvent`: container events → tagged Observations
2. **Orient**: Classify observations into patterns
   - Error classification: HealthDegradation, ContainerStartup, ContainerFailure, ResourceExhaustion, NetworkIssue, SecurityViolation
   - Impact assessment: SingleContainer vs System scope
3. **Decide**: Select course of action
   - No recommendations → NoAction
   - Single → return it
   - Multiple → EmergencyStop prioritized over all others
   - Score = Impact × (1 - Risk) / Effort
4. **Act**: Execute selected action
   - Restart container, stop container, kill process, send alert
5. **Complete**: Record cycle time, check <100ms target

### Postconditions
- OODACycle record with all phases
- CycleTimeMs recorded
- If action taken: container state changed + event logged

### Gleam Status: **ENTIRELY MISSING** (0 of 12 functions implemented)

---

## UC-PLAN-006: Chaya Sync Protocol (5-Phase)

**Actor:** System (scheduled or CLI-triggered)
**Fractal Layer:** L3_TRANSACTION
**STAMP:** SC-SYNC-PLAN-001 through SC-SYNC-PLAN-020

### Main Flow
1. **Phase 1**: Read all tasks from Planning.db (SOLE authoritative source)
2. **Phase 2**: Detect orphan Chaya tasks not in Planning.db
3. **Phase 3**: Convert each task via `convertToChayaTask`, save to Chaya.db
4. **Phase 4**: Regenerate PROJECT_TODOLIST.md from Planning.db
5. **Phase 5**: Post-sync verification:
   - Count match (Planning.db count == Chaya.db count)
   - Status match for ALL tasks (bijective mapping verified)
6. **Audit**: Write to ChayaEventLog table
7. **Zenoh**: Publish SyncStarted → SyncCompleted/SyncFailed

### Status Mapping (Bijective)
| Planning | Chaya | Roundtrip |
|----------|-------|-----------|
| Pending | "todo" | Lossless |
| InProgress | "in_progress" | Lossless |
| Completed | "done" | Lossless |
| Blocked | "blocked" | Lossless |
| Unknown(s) | "todo" | LOSSY (safe default) |

### Gleam Status: **ENTIRELY MISSING** (no Chaya module exists)

---

## UC-PLAN-007: Access Control Graph Verification

**Actor:** System (startup verification)
**Fractal Layer:** L0_CONSTITUTIONAL
**STAMP:** SC-GRAPH-001 through SC-GRAPH-005, SC-TODO-001 through SC-TODO-008

### Main Flow
1. Build access control graph: Agent → Method → File → Decision
2. Agent → DirectMethod edges marked `IsAllowed=false`
3. Agent → AuthorizedMethod (CLI/API) edges marked `IsAllowed=true`
4. Run 4-check verification suite:
   - **DeadlockFree** (SC-GRAPH-001): DAG check via cycle detection
   - **Completeness** (SC-GRAPH-002): all agents have at least one decision path
   - **Soundness**: no unauthorized access paths exist
   - **ServiceConnectivity** (SC-GRAPH-005): critical services are reachable
5. Calculate GraphStats: density, degree distribution, SCC count
6. Generate DOT visualization for audit

### Gleam Status: **ENTIRELY MISSING** (0 of 22 functions implemented)

---

## UC-PLAN-008: Service Orchestration (Multi-Service Coordination)

**Actor:** System (Orchestration layer)
**Fractal Layer:** L6_ECOSYSTEM
**STAMP:** SC-ORCH-001 through SC-ORCH-015

### Services: Cortex, Prajna, Smriti, CEPAF, Planning, Chaya, Guardian (7 total)

### Sub-Use Cases

**UC-PLAN-008a: Task Creation Coordination**
1. Planning creates task
2. Prajna validates (Guardian approval if critical)
3. Smriti stores in knowledge base
4. Chaya receives notification

**UC-PLAN-008b: OODA Cycle Coordination**
1. Gather health from all 7 services
2. Calculate: >50% healthy?
3. Decide: escalate if degraded
4. Execute: restart degraded services
5. Must complete in <100ms (SC-ORCH-004)

**UC-PLAN-008c: Task Distribution**
1. Receive task list and node count
2. Distribute using strategy: RoundRobin, LeastLoaded, PriorityBased, AffinityBased
3. Ensure all tasks assigned

### Gleam Status: **ENTIRELY MISSING** (0 of 21 functions implemented)

---

## UC-PLAN-009: Startup Optimization (Mathematical)

**Actor:** System (boot sequence)
**Fractal Layer:** L4_SYSTEM
**STAMP:** SC-MATH-001 through SC-MATH-050

### Main Flow
1. Build DAG from 15 container definitions with dependency edges
2. Cycle detection (DFS with color marking)
3. Topological sort (Kahn's algorithm) → execution waves
4. Critical Path Method (CPM): forward/backward pass → ES/EF/LS/LF/Slack
5. RCPSP list scheduling with resource constraints (memory, CPU cores)
6. DFA state transitions (14-state container lifecycle)
7. Generate optimization advice targeting critical path bottleneck

### Container DFA States (14)
NotCreated → Created → Starting → Running → Healthy → Unhealthy → Degraded → Lameduck → Draining → Checkpointing → Stopping → Stopped → Failed → Removed

### Gleam Status
| Component | Status |
|-----------|--------|
| Boot sequence types | IMPLEMENTED (`core/boot.gleam` - 5 stages) |
| DAG/Topo sort | MISSING |
| CPM | MISSING |
| RCPSP | MISSING |
| 14-state DFA | MISSING (only 5 stages exist) |

---

## UC-PLAN-010: PlanningEnforcer (5-Layer Defense-in-Depth)

**Actor:** All agents
**Fractal Layer:** L3_TRANSACTION
**STAMP:** SC-ENFORCE-001 through SC-ENFORCE-025

### Validation Layers
1. **Layer 1 (Agent Classification)**: Unknown agents denied by default
2. **Layer 2 (Rate Limiting)**: Max N requests/second per agent
3. **Layer 3 (Circuit Breaker)**: Open after 3 violations per agent; reset requires Guardian token
4. **Layer 4 (Path Validation)**: Forbidden paths/patterns matching
5. **Layer 5 (Behavioral Analysis)**: Suspicious operation pattern detection

### F# Functions (17 total)
| Function | Purpose | Gleam Status |
|----------|---------|-------------|
| `classifyAgent` | Map context to AgentType | MISSING |
| `recordViolation` | Log + persist violation | MISSING |
| `getViolationCount` | Per-agent count | MISSING |
| `isCircuitOpen` | Check breaker state | MISSING |
| `resetCircuitBreaker` | Guardian-approved reset | MISSING |
| `validateRequest` | 5-layer pipeline | MISSING |
| `registerHook` | Extension hooks | MISSING |
| `enforceAccess` | Main entry point | PARTIAL |
| `getAgentViolations` | Query by agent | MISSING |
| `getViolationsByTimeRange` | Query by time | MISSING |
| `getViolationsBySeverity` | Query by severity | MISSING |
| `getCircuitOpenAgents` | List blocked agents | MISSING |
| `getStatistics` | Enforcement stats | MISSING |
| `updateConfig` | Runtime config update | MISSING |
| `exportAuditLog` | Export to file | MISSING |
| `clearViolationHistory` | Admin clear | MISSING |
| `getAgentReport` | Per-agent report | MISSING |

---

## UC-PLAN-011: SafetyKernel Pre/Post Execution

**Actor:** System (Guardian integration)
**Fractal Layer:** L0_CONSTITUTIONAL
**STAMP:** SC-SAFETY-001 through SC-SAFETY-022

### Constitutional Checks (Psi-0 through Psi-5)
| Check | Invariant | Blocked Operations |
|-------|-----------|-------------------|
| Psi-0 | Existence | delete_all, terminate, destroy |
| Psi-1 | Regeneration | Uses of PostgreSQL (SC-HOLON-006) |
| Psi-2 | History | truncate_history, delete_history |
| Psi-3 | Verification | modify_block, delete_block |
| Psi-4 | Human Alignment | (no specific blocks) |
| Psi-5 | Truthfulness | falsify_log, hide_event, delete_evidence |

### Founder's Directive (Omega-0)
| Directive | Check |
|-----------|-------|
| Omega-0.1 | Operation does not undermine founder lineage |
| Omega-0.6 | Resource usage within allocated bounds |
| Omega-0.7 | No hidden side channels |

### F# Functions (18 total)
| Function | Gleam Status |
|----------|-------------|
| `validateOperation` | PARTIAL (actor-based) |
| `monitorExecution` | MISSING |
| `checkAutoHalt` | MISSING |
| `verifyPostExecution` | MISSING |
| `emergencyStop` | MISSING |
| `rollbackToSafe` | MISSING |
| `quarantineAgent` | MISSING |
| `getStatus` | PARTIAL (actor msg) |
| `getSafetyEvents` | MISSING |
| `getQuarantinedAgents` | MISSING |
| `getActiveOperations` | MISSING |
| `isQuarantined` | MISSING |
| `getThreatLevel` | MISSING |
| `resetThreatLevel` | MISSING |
| `activate/deactivate` | MISSING |
| `checkGuardianHealth` | MISSING |

---

## UC-PLAN-012: Zenoh Event Publishing

**Actor:** System (event-driven)
**Fractal Layer:** L6_ECOSYSTEM
**STAMP:** SC-ZTEST-001, SC-ZTEST-008, SC-SYNC-PLAN-011

### Events & Topics
| Event | Topic | Checkpoint |
|-------|-------|------------|
| TaskCreated | `indrajaal/planning/events` | CP-PLAN-01 |
| TaskUpdated | `indrajaal/planning/events` | CP-PLAN-02 |
| TaskCompleted | `indrajaal/planning/events` | CP-PLAN-03 |
| SyncStarted | `indrajaal/planning/sync` | CP-PLAN-SYNC-01 |
| SyncCompleted | `indrajaal/planning/sync` | CP-PLAN-SYNC-02 |
| SyncFailed | `indrajaal/planning/sync` | CP-PLAN-SYNC-03 |

### Gleam Status: **ENTIRELY MISSING** (no ZenohAdapter module exists in planning/)

---

## UC-PLAN-013: Markdown Parsing & Generation

**Actor:** System
**Fractal Layer:** L2_COMPONENT
**STAMP:** SC-PLAN-002

### Parsing Formats
1. Header tasks: `## N.N.N - Title (PN) [STATUS]`
2. Checkbox tasks: `- [x] N.N.N - Title`
3. F# also supports AI-assisted parsing via OpenRouter (fallback to regex)

### Gleam Status: **IMPLEMENTED** (`parser.parse_todolist`, `parser.serialize_todolist`)

---

## UC-PLAN-014: CLI Command Dispatch

**Actor:** Human (terminal)
**Fractal Layer:** L5_COGNITIVE

### Commands
| Command | F# | Gleam Status |
|---------|-----|-------------|
| `status` | Task counts by status/priority | IMPLEMENTED |
| `add <title> [priority] [parent]` | Create task | MISSING (cli only has status/start/complete/sync) |
| `update <id> <status>` | Update status | MISSING |
| `list [status]` | List tasks | MISSING |
| `start <id>` | Set InProgress | IMPLEMENTED |
| `complete <id>` | Set Completed | IMPLEMENTED |
| `backup` | Create timestamped backup | MISSING |
| `sync` | Git sync | PARTIAL |

---

## IMPLEMENTATION GAP SUMMARY

| Category | F# Functions | Gleam Implemented | MISSING |
|----------|-------------|-------------------|---------|
| Task CRUD | 11 | 6 | **5** |
| Enforcer (5-layer) | 17 | 1 | **16** |
| Safety Kernel | 18 | 3 | **15** |
| OODA Controller | 12 | 0 | **12** |
| Graph Verification | 22 | 0 | **22** |
| Access Control | 14 | 0 | **14** |
| Orchestration | 21 | 0 | **21** |
| Zenoh Adapter | 5 | 0 | **5** |
| Chaya Integration | 8 | 0 | **8** |
| Math Optimization | 15 | 1 | **14** |
| Parser/CLI | 6 | 5 | **1** |
| **TOTAL** | **149** | **16** | **133** |

**Replication Rate: 10.7%** (16/149 functions implemented)

---

## PRIORITY EXECUTION ORDER

### Wave 1 (Safety-Critical / L0)
1. SafetyKernel full implementation (15 functions)
2. AccessControl module (14 functions)
3. GraphVerification module (22 functions)

### Wave 2 (Core Planning / L2-L3)
4. Enforcer 5-layer pipeline (16 functions)
5. ZenohAdapter (5 functions)
6. Task CRUD gaps (5 functions)

### Wave 3 (Orchestration / L5-L6)
7. OODA Controller (12 functions)
8. Orchestration + ServiceRegistry (21 functions)
9. Chaya Integration (8 functions)

### Wave 4 (Mathematical / L4)
10. Startup Optimization (14 functions)
