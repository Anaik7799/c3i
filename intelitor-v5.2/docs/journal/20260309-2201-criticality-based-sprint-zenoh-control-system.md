# Criticality-Based Sprint Task Control via Zenoh Messaging

| Field | Value |
|-------|-------|
| Date | 2026-03-09 21:59 CEST |
| Author | Cybernetic Architect (Claude Opus 4.6) |
| Sprint | 42-46 (cross-sprint orchestration) |
| Version | 21.3.0-SIL6 |
| STAMP | SC-ZTEST-001 to SC-ZTEST-020, SC-SIL6-001 |
| AOR | AOR-ZTEST-001 to AOR-ZTEST-015 |
| Status | IMPLEMENTED - Both runtimes compile clean |

---

## Level 1: Executive Summary (30 seconds)

Built a dual-runtime (Elixir + F#) criticality-based sprint task control system that manages 18 tasks across sprints 42-46 using Zenoh pub/sub messaging. Tasks are classified by priority (P0/P1/P2), organized into 6 execution waves with dependency DAG, controlled by Jidoka quality gates, and tracked via 6-dimensional state vectors. All 4 files compile with 0 errors, 0 warnings in both runtimes.

---

## Level 2: Technical Overview (5 minutes)

### What Was Built

Four files forming a complete sprint orchestration layer:

| File | Lines | Runtime | Role |
|------|-------|---------|------|
| `checkpoint_messages.ex` | +80 | Elixir | 18 sprint + 6 wave checkpoint IDs, message schemas, topic patterns |
| `sprint_task_publisher.ex` | ~350 | Elixir | Task lifecycle publisher with registry, DAG, Zenoh integration |
| `zenoh_test_orchestrator.ex` | +60 | Elixir | Sprint event aggregation via telemetry, PubSub broadcast |
| `SprintOrchestrator.fs` | ~462 | F# | DAG executor, wave management, Jidoka gates, FMEA analysis |

### Task Classification

| Wave | Priority | Tasks | Gate |
|------|----------|-------|------|
| 0 - Foundations | P0 Critical | 42.1, 42.4, 44.2, 46.1 | CP-WAVE-G0 |
| 1 - Core Logic | P0/P1 | 43.1.1, 46.2, 42.2 | CP-WAVE-G1 |
| 2 - Integration | P1 High | 43.1.2, 43.1.3, 43.1.4, 44.1, 44.3 | CP-WAVE-G2 |
| 3 - Higher-Order | P1/P2 | 45.1, 46.3, 42.3 | CP-WAVE-G3 |
| 4 - Verification | P1/P2 | 45.2, 46.4 | CP-WAVE-G4 |
| 5 - Rollup | P0 | 43.1.0 (parent) | CP-WAVE-FINAL |

### Build Verification

```
Elixir: mix compile → 3 files compiled, 0 errors, 0 warnings
F#:     dotnet build → Build succeeded, 0 errors, 0 warnings
```

---

## Level 3: Architecture & Design Decisions (15 minutes)

### 3.1 Design Philosophy

The system follows three principles from the existing codebase:

1. **Dual-Runtime Parity**: Elixir handles runtime lifecycle (publish/subscribe, telemetry, GenServer aggregation) while F# handles static analysis (DAG computation, gate evaluation, FMEA, dashboard rendering). This mirrors the existing ZenohBootPublisher (Elixir) ↔ DigitalTwin (F#) pattern.

2. **Checkpoint-Based Control**: Every task lifecycle event (started, progress, completed, failed) publishes a Zenoh checkpoint message with a unique CP-{DOMAIN}-{NN} identifier, following SC-ZTEST-001 to SC-ZTEST-020 constraints.

3. **Jidoka Quality Gates**: Waves cannot advance until a gate evaluates all quality dimensions (compilation, tests, coverage ≥95%, FPPS consensus, F# build). A failed gate halts the pipeline — the Jidoka (autonomation) principle from TPS.

### 3.2 Dependency DAG

```
Wave 0 (no deps):
  42.1.0.0.0 ─────────────────────────┐
  42.4.0.0.0 ─────────────────────────┤
  44.2.0.0.0 ─────────────────────────┤
  46.1.0.0.0 ──┐                      │
               │                      │
Wave 1:        │                      │
  43.1.1.0.0   │                      │
  46.2.0.0.0 ◀─┘ (depends on 46.1)   │
  42.2.0.0.0 ◀────────────────────────┘ (depends on 42.1)
               │
Wave 2:        │
  43.1.2.0.0 ◀─┤ (depends on 43.1.1)
  43.1.3.0.0 ◀─┤ (depends on 43.1.1)
  43.1.4.0.0 ◀─┤ (depends on 43.1.1 + 44.2)
  44.1.0.0.0 ◀─┘ (depends on 43.1.1)
  44.3.0.0.0 ◀──── (depends on 42.1 + 42.4)
               │
Wave 3:        │
  45.1.0.0.0 ◀──── (depends on 44.3)
  46.3.0.0.0 ◀──── (depends on 46.2 + 43.1.2)
  42.3.0.0.0 ◀──── (depends on 42.2)
               │
Wave 4:        │
  45.2.0.0.0 ◀──── (depends on 45.1)
  46.4.0.0.0 ◀──── (depends on 46.1 + 46.2 + 46.3)
               │
Wave 5:        │
  43.1.0.0.0 ◀──── (depends on 43.1.1 + 43.1.2 + 43.1.3 + 43.1.4)
```

### 3.3 6D State Vector

Each task tracks progress across 6 dimensions:

```
[design, implement, test, integrate, verify, deploy]
  ↓         ↓        ↓       ↓         ↓       ↓
  D         I        T       G         V       P

Example progression:
  [0,0,0,0,0,0] → Pending (0%)
  [1,0,0,0,0,0] → Design done (17%)
  [1,1,0,0,0,0] → Implemented (33%)
  [1,1,1,0,0,0] → Tested (50%)
  [1,1,1,1,0,0] → Integrated (67%)
  [1,1,1,1,1,0] → Verified (83%)
  [1,1,1,1,1,1] → Complete (100%)
```

### 3.4 Zenoh Topic Hierarchy

```
indrajaal/sprint/
├── {sprint_id}/task/{task_key}/
│   ├── started       # Task lifecycle events
│   ├── progress
│   ├── completed
│   ├── failed
│   └── verify        # Checkpoint verification
├── wave/{wave_id}/
│   ├── started
│   ├── completed
│   └── gate          # Jidoka gate results
└── orchestrator/
    ├── status
    └── dashboard
```

Topic depth = 5 levels (within SC-ZTEST-017 limit of 6).

### 3.5 Telemetry Integration

The Elixir side uses `:telemetry.attach_many/4` to route events:

```elixir
# SprintTaskPublisher emits:
[:indrajaal, :sprint, :task, :task_started]
[:indrajaal, :sprint, :task, :task_progress]
[:indrajaal, :sprint, :task, :task_completed]
[:indrajaal, :sprint, :task, :task_failed]
[:indrajaal, :sprint, :task, :wave_gate]

# ZenohTestOrchestrator subscribes and aggregates
# → Updates sprint_tasks map, sprint_waves map
# → Broadcasts to Phoenix.PubSub "zenoh:test_events"
# → Wave gate failures trigger alerts
```

### 3.6 F# Build Fix: RequireQualifiedAccess

The initial F# build had 8 errors caused by type name collision:

- `TaskStatus.Failed` leaked into `Cepaf.Mesh` namespace, shadowing `ContainerHealth.Failed` in MeshStartup.fs
- `task` variable name shadowed F#'s `task {}` computation expression builder
- `KeyValue()` active pattern doesn't match tuples from `Map.toSeq`

Fix applied:
1. Added `[<RequireQualifiedAccess>]` to `TaskStatus` and `TaskPriority` DUs
2. Qualified all case references: `TaskStatus.Pending`, `TaskPriority.P0_Critical`, etc.
3. Changed `for KeyValue(_, task)` to `for (_, st)` with tuple destructuring
4. Renamed loop variable from `task` to `st` to avoid CE builder conflict

---

## Level 4: Implementation Details (30 minutes)

### 4.1 Elixir: checkpoint_messages.ex (Extensions)

Added to the existing central schema module:

**18 Sprint Checkpoint IDs** mapped to Zenoh topics:
```elixir
@sprint_checkpoints %{
  "CP-HOLON-01" => "indrajaal/sprint/42/task/42-1/verify",
  "CP-HOLON-02" => "indrajaal/sprint/42/task/42-2/verify",
  "CP-HOLON-03" => "indrajaal/sprint/42/task/42-3/verify",
  "CP-HOLON-04" => "indrajaal/sprint/42/task/42-4/verify",
  "CP-FVAL-01"  => "indrajaal/sprint/43/task/43-1-0/verify",
  "CP-FVAL-02"  => "indrajaal/sprint/43/task/43-1-1/verify",
  "CP-FVAL-03"  => "indrajaal/sprint/43/task/43-1-2/verify",
  "CP-FVAL-04"  => "indrajaal/sprint/43/task/43-1-3/verify",
  "CP-FVAL-05"  => "indrajaal/sprint/43/task/43-1-4/verify",
  "CP-VALD-01"  => "indrajaal/sprint/44/task/44-1/verify",
  "CP-VALD-02"  => "indrajaal/sprint/44/task/44-2/verify",
  "CP-VALD-03"  => "indrajaal/sprint/44/task/44-3/verify",
  "CP-PLAN-01"  => "indrajaal/sprint/45/task/45-1/verify",
  "CP-PLAN-02"  => "indrajaal/sprint/45/task/45-2/verify",
  "CP-FPPS-01"  => "indrajaal/sprint/46/task/46-1/verify",
  "CP-FPPS-02"  => "indrajaal/sprint/46/task/46-2/verify",
  "CP-FPPS-03"  => "indrajaal/sprint/46/task/46-3/verify",
  "CP-FPPS-04"  => "indrajaal/sprint/46/task/46-4/verify"
}
```

**6 Wave Gate Checkpoint IDs**:
```elixir
@wave_checkpoints %{
  "CP-WAVE-G0"    => "indrajaal/sprint/wave/0/gate",
  "CP-WAVE-G1"    => "indrajaal/sprint/wave/1/gate",
  "CP-WAVE-G2"    => "indrajaal/sprint/wave/2/gate",
  "CP-WAVE-G3"    => "indrajaal/sprint/wave/3/gate",
  "CP-WAVE-G4"    => "indrajaal/sprint/wave/4/gate",
  "CP-WAVE-FINAL" => "indrajaal/sprint/final/gate"
}
```

**New Message Builders**:
- `build_task_started/4` — Task ID, sprint, wave, priority
- `build_task_progress/5` — Task ID, dimension, completed_dims, total_dims, state_vector
- `build_task_completed/4` — Task ID, duration_ms, state_vector, checkpoint_id
- `build_task_failed/4` — Task ID, reason, state_vector, checkpoint_id
- `build_sprint_gate/3` — Wave ID, gate_id, gate_result map

**New Topic Functions**:
- `sprint_topic_pattern/0` — Returns `"indrajaal/sprint/**"`
- `sprint_task_topic/3` — Returns `"indrajaal/sprint/{sprint}/task/{key}/{event}"`
- `sprint_wave_topic/2` — Returns `"indrajaal/sprint/wave/{wave}/{event}"`

### 4.2 Elixir: sprint_task_publisher.ex (New File)

Complete sprint task lifecycle publisher following ZenohBootPublisher patterns:

**Task Registry** — Maps all 18 task IDs to metadata:
```elixir
@task_registry %{
  "42.1.0.0.0" => %{title: "Biological Substrate (L0-L5)", sprint: 42, ...},
  ...
}
```

**Dependency DAG** — Explicit dependency edges:
```elixir
@dependency_dag %{
  "42.2.0.0.0" => ["42.1.0.0.0"],
  "46.2.0.0.0" => ["46.1.0.0.0"],
  "43.1.2.0.0" => ["43.1.1.0.0"],
  ...
}
```

**Wave Definitions** — 6 waves with task lists:
```elixir
@waves %{
  0 => %{tasks: ["42.1.0.0.0", "42.4.0.0.0", "44.2.0.0.0", "46.1.0.0.0"], gate: "CP-WAVE-G0"},
  1 => %{tasks: ["43.1.1.0.0", "46.2.0.0.0", "42.2.0.0.0"], gate: "CP-WAVE-G1"},
  ...
}
```

**Publishing Pattern** (SC-ZTEST-008 compliant):
1. Build message via CheckpointMessages builder
2. Log fallback `[ZTEST-CHECKPOINT]` line (guaranteed durability)
3. Emit `:telemetry` event (picked up by orchestrator)
4. Async `Task.start` to publish via ZenohSession (best-effort real-time)

**Query API**:
- `critical_tasks/0` — Returns P0 tasks
- `tasks_by_wave/0` — Groups tasks by wave number
- `critical_path/0` — Returns two critical path chains
- `dependencies_satisfied?/2` — Checks if task deps are in completed set

### 4.3 Elixir: zenoh_test_orchestrator.ex (Extensions)

Added sprint aggregation state to the existing GenServer:

**New State Fields**:
```elixir
sprint_tasks: %{},       # task_id => latest event
sprint_waves: %{},       # wave_id => gate result
sprint_completed: 0,     # counter
sprint_failed: 0,        # counter
sprint_gates_passed: 0   # counter
```

**New Telemetry Subscriptions** (5 events):
- `[:indrajaal, :sprint, :task, :task_started]`
- `[:indrajaal, :sprint, :task, :task_progress]`
- `[:indrajaal, :sprint, :task, :task_completed]`
- `[:indrajaal, :sprint, :task, :task_failed]`
- `[:indrajaal, :sprint, :task, :wave_gate]`

**Event Handlers**:
- `handle_sprint_event/3` — Routes to appropriate handler
- Updates `sprint_tasks` map with latest event per task
- Wave gate failures broadcast alert to `"zenoh:test_events"` PubSub topic
- Sprint stats included in `get_stats/0` response

### 4.4 F#: SprintOrchestrator.fs (New File)

Complete DAG-based orchestrator with Jidoka gate evaluation:

**Type System** (with `[<RequireQualifiedAccess>]` to prevent namespace pollution):
```fsharp
type TaskPriority = P0_Critical | P1_High | P2_Medium | P3_Low
type TaskStatus = Pending | Running | Completed | Failed of string | Blocked of string list
type TaskStateVector = { Design; Implement; Test; Integrate; Verify; Deploy : bool }
type SprintTask = { TaskId; Title; Sprint; TaskKey; CheckpointId; Priority; Wave; Dependencies; Status; StateVector; ... }
type GateResult = { WaveId; GateId; Compilation; Tests; Coverage; FppsConsensus; FsharpBuild; Passed; ... }
type WaveState = { WaveId; Tasks; GateId; Status; GateResult option; ... }
type SprintOrchestratorState = { Tasks; Waves; CurrentWave; CompletedTasks; FailedTasks; CreatedAt }
```

**Operations**:
- `create()` — Initialize with full 18-task registry and 6 wave definitions
- `startTask/completeTask/failTask` — Lifecycle transitions
- `updateStateVector` — Set individual dimensions
- `readyTasks` — Get tasks in current wave with satisfied dependencies
- `isWaveComplete` — Check if all wave tasks are completed/failed
- `evaluateGate` — Jidoka gate with 5 quality dimensions
- `advanceWave` — Move to next wave if gate passed

**FMEA Analysis** (10 failure modes):
| Task | Failure Mode | RPN | Critical? |
|------|-------------|-----|-----------|
| 43.1.1 | F# validator false positives | 140 | YES |
| 42.4.0 | Incomplete ZKMS->SMRITI rename | 108 | YES |
| 46.1.0 | Regex migration breaks validation | 105 | YES |
| 46.2.0 | 5-method consensus breaks FPPS | 96 | No |
| 42.1.0 | SQLite schema breaks holon state | 96 | No |
| 44.2.0 | Zenoh NIF API breaks formatter | 81 | No |
| 43.1.4 | Telemetry latency exceeds 10ms | 72 | No |
| 42.2.0 | L6-L7 consensus split-brain | 54 | No |
| 45.2.0 | Planning cutover loses state | 48 | No |
| 44.3.0 | Smriti data loss during migration | 36 | No |

**Dashboard** — ANSI-colored TUI with task status table, wave progress, and critical risk alerts.

**JSON Export** — `toJson/1` serializes full state for Zenoh publishing.

### 4.5 .fsproj Compile Order

SprintOrchestrator.fs inserted immediately after DigitalTwin.fs:
```xml
<Compile Include="Mesh/DigitalTwin.fs" />
<Compile Include="Mesh/SprintOrchestrator.fs" />  <!-- NEW -->
<Compile Include="Mesh/ContainerLifecycleManager.fs" />
```

This ensures DigitalTwin types are available but SprintOrchestrator's qualified types don't leak into downstream files.

---

## Level 5: Mathematical Foundations & Formal Properties (60 minutes)

### 5.1 State Space Definition

The sprint orchestrator state space is formally defined as:

$$\mathcal{S} = \mathcal{T}^{18} \times \mathcal{W}^6 \times \mathbb{N} \times 2^{\mathcal{ID}} \times 2^{\mathcal{ID}} \times \mathbb{T}$$

where:
- $\mathcal{T}$ = Task state (status × state_vector × metadata)
- $\mathcal{W}$ = Wave state (status × gate_result)
- $\mathbb{N}$ = Current wave index
- $2^{\mathcal{ID}}$ = Sets of completed/failed task IDs
- $\mathbb{T}$ = Timestamp

### 5.2 Task State Vector Algebra

Each task has a state vector $\vec{v} \in \{0,1\}^6$:

$$\vec{v} = (d, i, t, g, v, p) \quad \text{where } d,i,t,g,v,p \in \{0,1\}$$

**Progress function**:
$$\text{progress}(\vec{v}) = \frac{\sum_{k=1}^{6} v_k}{6} \times 100\%$$

**Completion predicate**:
$$\text{complete}(\vec{v}) \iff \prod_{k=1}^{6} v_k = 1$$

**Monotonicity invariant** (state vector can only advance):
$$\forall k, t_1 < t_2: v_k(t_1) = 1 \implies v_k(t_2) = 1$$

This ensures tasks cannot regress once a dimension is achieved.

### 5.3 Dependency DAG Formal Properties

The dependency graph $G = (V, E)$ where $V = \{v_1, ..., v_{18}\}$ and $E \subseteq V \times V$:

**Acyclicity** (verified by construction):
$$\nexists \text{ cycle in } G$$

This is enforced by the wave structure: all edges go from lower waves to higher waves, making cycles impossible:
$$\forall (u, v) \in E: \text{wave}(u) < \text{wave}(v)$$

**Topological order exists** (consequence of acyclicity):
$$\exists \tau: V \to \mathbb{N} \text{ s.t. } (u,v) \in E \implies \tau(u) < \tau(v)$$

The wave assignment IS the topological order.

**Critical path analysis** — Two longest dependency chains:

$$\pi_1 = [42.1 \to 44.3 \to 45.1 \to 45.2] \quad |\pi_1| = 4$$
$$\pi_2 = [46.1 \to 46.2 \to 46.3 \to 46.4] \quad |\pi_2| = 4$$

Both span waves 0-4 (5 waves), determining the minimum theoretical execution depth.

**Parallelism factor**:
$$\text{width}(G) = \max_{w \in \{0..5\}} |W_w| = 5 \quad \text{(Wave 2)}$$

Wave 2 has 5 tasks executable in parallel, giving maximum parallelism.

### 5.4 Wave Gate Formal Specification

A Jidoka gate $\mathcal{G}_w$ for wave $w$ is a predicate:

$$\mathcal{G}_w(\vec{q}) = \bigwedge_{i=1}^{5} q_i$$

where quality vector $\vec{q} = (c, t, \kappa, f, s)$:
- $c$ = compilation passed (bool)
- $t$ = tests passed (bool)
- $\kappa$ = coverage ≥ 95% (bool, derived from float)
- $f$ = FPPS 5-method consensus (bool)
- $s$ = F# build passed (bool, optional)

**Gate advancement rule**:
$$\text{advance}(w, \mathcal{G}_w) = \begin{cases} w + 1 & \text{if } \mathcal{G}_w = \top \\ w & \text{if } \mathcal{G}_w = \bot \end{cases}$$

**Jidoka halt property**: If any quality dimension fails, the pipeline halts:
$$\exists i: q_i = \bot \implies \text{halt}(w) \quad \text{(stop and fix before continuing)}$$

### 5.5 FMEA Risk Priority Number Mathematics

$$\text{RPN} = S \times O \times D$$

where $S, O, D \in \{1, ..., 10\}$ giving $\text{RPN} \in \{1, ..., 1000\}$.

**Risk classification thresholds**:

| Range | Classification | Action |
|-------|---------------|--------|
| RPN > 200 | CRITICAL | Immediate mitigation required |
| 100 < RPN ≤ 200 | HIGH | Mitigation before wave gate |
| 50 < RPN ≤ 100 | MEDIUM | Monitor during execution |
| RPN ≤ 50 | LOW | Accept risk |

**Current risk distribution**:
- 3 tasks with RPN > 100 (HIGH): 140, 108, 105
- 4 tasks with 50 < RPN ≤ 100 (MEDIUM): 96, 96, 81, 72
- 3 tasks with RPN ≤ 50 (LOW): 54, 48, 36

**Aggregate risk** (sum of all RPNs):
$$\text{RPN}_{total} = 140 + 108 + 105 + 96 + 96 + 81 + 72 + 54 + 48 + 36 = 836$$

**Mean RPN** per task with identified failure modes:
$$\bar{\text{RPN}} = 836 / 10 = 83.6 \quad \text{(MEDIUM range)}$$

### 5.6 Zenoh Messaging Latency Budget

Total E2E latency budget: $L_{total} < 100\text{ms}$ (SC-ZTEST-005)

$$L_{total} = L_{log} + L_{telemetry} + L_{publish} + L_{route} + L_{subscribe} + L_{aggregate}$$

| Component | Budget | Implementation |
|-----------|--------|----------------|
| $L_{log}$ | 1ms | Logger.info (sync, local) |
| $L_{telemetry}$ | 2ms | :telemetry.execute (in-process) |
| $L_{publish}$ | 10ms | ZenohSession.publish (async, SC-ZTEST-003) |
| $L_{route}$ | 15ms | Zenoh router forwarding |
| $L_{subscribe}$ | 10ms | Zenoh delivery to subscriber |
| $L_{aggregate}$ | 50ms | GenServer cast + PubSub broadcast |
| **Total** | **88ms** | Within 100ms budget |

**Dual-write ordering guarantee** (SC-ZTEST-008):
1. Log fallback written FIRST (synchronous, guaranteed)
2. Telemetry emitted SECOND (in-process, guaranteed)
3. Zenoh published THIRD (async, best-effort)

This ensures that even if Zenoh is unavailable, all events are captured in logs and telemetry.

### 5.7 Checkpoint ID Namespace

Five checkpoint domains with cardinality:

| Domain | Prefix | Count | ID Range |
|--------|--------|-------|----------|
| HOLON | CP-HOLON-{01..04} | 4 | Sprint 42 tasks |
| FVAL | CP-FVAL-{01..05} | 5 | Sprint 43 tasks |
| VALD | CP-VALD-{01..03} | 3 | Sprint 44 tasks |
| PLAN | CP-PLAN-{01..02} | 2 | Sprint 45 tasks |
| FPPS | CP-FPPS-{01..04} | 4 | Sprint 46 tasks |
| WAVE | CP-WAVE-{G0..G4,FINAL} | 6 | Quality gates |
| **Total** | | **24** | |

**Uniqueness invariant** (SC-ZTEST-001):
$$\forall c_i, c_j \in \mathcal{C}: i \neq j \implies \text{id}(c_i) \neq \text{id}(c_j) \wedge \text{topic}(c_i) \neq \text{topic}(c_j)$$

All 24 checkpoint IDs map to unique Zenoh topics — verified by construction (each topic encodes sprint ID + task key + event type).

### 5.8 Execution Semantics

**Wave execution model** — Tasks within a wave execute in parallel, subject to dependency satisfaction:

$$\text{ready}(w, \mathcal{S}) = \{t \in W_w \mid \text{status}(t) = \text{Pending} \wedge \forall d \in \text{deps}(t): d \in \text{Completed}(\mathcal{S})\}$$

**State transition function**:

$$\sigma: \mathcal{S} \times \mathcal{E} \to \mathcal{S}$$

where $\mathcal{E} = \{\text{Start}(id), \text{Complete}(id, ms), \text{Fail}(id, reason), \text{UpdateSV}(id, \vec{v}), \text{Gate}(w, \vec{q})\}$

**Safety property** — No task runs before dependencies complete:
$$\Box(\text{Running}(t) \implies \forall d \in \text{deps}(t): \text{Completed}(d))$$

**Liveness property** — If all prerequisites are met and no failures, task eventually completes:
$$\text{ready}(t) \implies \Diamond(\text{Completed}(t) \lor \text{Failed}(t))$$

**Progress property** — The system makes progress (no infinite stall):
$$\Box(|\text{ready}(w, \mathcal{S})| > 0 \implies \Diamond(|\text{Completed}(\mathcal{S})| \text{ increases}))$$

### 5.9 Relationship to Existing Constraints

| This System | Existing Constraint | Relationship |
|-------------|-------------------|--------------|
| Sprint checkpoints | SC-ZTEST-001 | Unique topic per checkpoint |
| Log fallback | SC-ZTEST-008 | Always write log before Zenoh |
| Publish latency | SC-ZTEST-003 | < 10ms per message |
| Topic depth | SC-ZTEST-017 | ≤ 6 levels (we use 5) |
| FIFO ordering | SC-ZTEST-012 | Per-topic message ordering |
| Jidoka gates | SC-SIL6-001 | Mesh boot stage gates (extended to sprints) |
| 6D state vector | SC-ZTEST-006 | Boot state vector (extended from 6-bit to 6D per task) |
| FMEA analysis | AOR-FMEA-001 | Risk assessment before fix prioritization |
| Dependency DAG | DAG-ZTEST-001 | Acyclic dependency graph |
| Quality gates | SC-OODA-002 | Quality gates enforced 80% min |

---

## 5-Order Effects Analysis

| Order | Effect |
|-------|--------|
| **1st (Immediate)** | 18 tasks have unique Zenoh checkpoint IDs; publishers emit lifecycle events; F# can evaluate Jidoka gates |
| **2nd (Seconds)** | ZenohTestOrchestrator aggregates sprint events; PubSub broadcasts to LiveView dashboard; log fallback captured |
| **3rd (Minutes)** | Wave progression controlled by gate evaluation; blocked tasks identified; FMEA risks surfaced to dashboard |
| **4th (Hours)** | Full sprint execution tracked end-to-end with state vectors; critical path bottlenecks visible; risk mitigation prioritized |
| **5th (Days)** | Cross-sprint dependency tracking enables predictive scheduling; FMEA data feeds back into future sprint planning; system approaches self-managing sprint execution |
