# Gleam Planning System: Usage, Use Cases, and Behavior

## 1. Introduction
The Gleam planning layer in C3I (`cepaf_gleam/planning`) acts as the core task management, orchestration, and cognitive loop (OODA) controller for the fractal biomorphic mesh. It is designed for high-assurance, SIL-6 compliant environments where strict access controls, safety checks, and immutable state are required.

## 2. How the Planning Layer is Used and Called

### By Humans (Operators)
Humans interact with the planning system primarily through the CLI entrypoint (`sa-plan`) and the Web UI Dashboard.
The CLI commands currently supported include:
- `sa-plan status`: Lists all tasks, showing their ID, status, and title.
- `sa-plan start <id>`: Transitions a task's status from Pending to InProgress.
- `sa-plan complete <id>`: Transitions a task's status to Completed.
- `sa-plan sync`: Parses `PROJECT_TODOLIST.md` and synchronizes the tasks into the authoritative database (DuckDB/SQLite fallback).

### By Coding Agents and System Processes
Agents are strictly bound by the `PlanningEnforcer` and `SafetyKernel`. They do NOT interact with the system without passing through a 5-layer defense-in-depth pipeline:
1. **Agent Classification:** Unknown agents are denied.
2. **Rate Limiting:** Restrictions on requests/second.
3. **Circuit Breaker:** Opens after 3 violations, requiring a Guardian token to reset.
4. **Path Validation:** Checks for forbidden paths/patterns.
5. **Behavioral Analysis:** Detects suspicious operation patterns.

Agents trigger planning functionality via **Zenoh IPC** or restricted CLI execution. Any state mutation proposed by an agent (e.g., creating a task or deciding an action in the OODA loop) is verified against:
- **Constitutional Checks (Psi-0 to Psi-5):** Ensures existence, history, verification, and truthfulness invariants.
- **Founder's Directive (Omega-0):** Checks resource boundaries.

---

## 3. Exhaustive Use Case Scenarios & Expected Behavior

Based on the system's specification and current Gleam implementation state, here are the defined use cases:

### UC-PLAN-001: Create Task
- **Actors:** Human, AI Agent, System
- **Flow:** An agent submits a task title and priority. The Enforcer and SafetyKernel validate the request. The system generates a UUID, persists the task (Pending status), publishes a `TaskCreated` Zenoh event, and synchronizes with the markdown backup and Chaya twin.
- **Behavior:** The task is immutably stored, broadcasted via Zenoh, and backed up atomically.

### UC-PLAN-002: Update Task Status
- **Actors:** Human, AI Agent, System
- **Flow:** Agent requests a status change (e.g., Pending -> InProgress). Validated for valid state transitions (e.g., cannot transition from Completed to Pending).
- **Behavior:** Task version is bumped, updated in the DB, and a `TaskUpdated` event is published.

### UC-PLAN-003: Cold Start Initialization
- **Actors:** System
- **Flow:** Upon boot, if the DB is empty, the system reads `PROJECT_TODOLIST.md`, parses the tasks, validates permissions, and seeds the database.
- **Behavior:** Idempotent database initialization and hydration from the markdown source of truth.

### UC-PLAN-004: Destructive Operation
- **Actors:** System (Requires Guardian Approval)
- **Flow:** Critical actions like clearing all tasks trigger a `RequiresGuardian` and `RequiresConstitutional` validation pipeline.
- **Behavior:** Fails immediately on Psi-0 (Existence) or Psi-2 (History) violations. Requires a two-key-turn Guardian token to override. Full audit trails are generated.

### UC-PLAN-005: OODA Cycle Execution (Observe-Orient-Decide-Act)
- **Actors:** System, Chaya Digital Twin
- **Flow:** Collects container/mesh health metrics (Observe), classifies errors/threats (Orient), scores actions (Decide), and executes mitigation like container restarts (Act).
- **Behavior:** Completes in <100ms. OODA records and cycle times are logged.

### UC-PLAN-006: Chaya Sync Protocol (5-Phase)
- **Actors:** System
- **Flow:** Reads tasks from Planning.db, detects orphans in Chaya, converts tasks, regenerates `PROJECT_TODOLIST.md`, and verifies count and status parity.
- **Behavior:** Ensures the Chaya digital twin is perfectly bijective with the Planning source of truth.

### UC-PLAN-007: Access Control Graph Verification
- **Actors:** System
- **Flow:** Builds an access DAG (Agent -> Method -> File). Runs checks for DeadlockFree, Completeness, Soundness, and ServiceConnectivity.
- **Behavior:** Generates a DOT visualization and graph statistics for compliance audits.

### UC-PLAN-008: Service Orchestration
- **Actors:** System
- **Flow:** Coordinates workflows across Cortex, Prajna, Smriti, CEPAF, Planning, Chaya, and Guardian. Distributes tasks using RoundRobin, LeastLoaded, PriorityBased, or AffinityBased strategies.
- **Behavior:** Ensures operations like task creation and OODA loop responses are quorum-backed and safely distributed across the mesh.

### UC-PLAN-009: Startup Optimization
- **Actors:** System
- **Flow:** Builds a DAG of container definitions, performs topological sorting, and uses the Critical Path Method (CPM) to optimize boot execution waves.
- **Behavior:** Minimizes system boot time while respecting dependency order and resource constraints.

## 4. Conclusion
The Gleam Planning System is a mathematically rigorous, mathematically verified orchestration kernel. Humans interface with it to steer high-level goals and override safety circuits, while agents are constrained by the Enforcer pipeline to autonomously execute and coordinate task distribution within the OODA cycle.