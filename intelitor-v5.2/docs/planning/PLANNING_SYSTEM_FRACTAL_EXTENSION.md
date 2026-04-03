# Planning System Fractal Extension

**Version**: 21.3.0-SIL6
**Extends**: PLANNING_SYSTEM_SPECIFICATION.md
**Focus**: Fractal Architecture, 10x10 Matrix, Human/Agent/Joint Use

---

## 1. Fractal Architecture (L0-L9)

### 1.1 9-Level Fractal Planning Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    FRACTAL PLANNING ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  L9: UNIVERSE (Species Survival)                                        │
│  ├── Multi-civilization task coordination                               │
│  ├── Deep time planning (centuries)                                     │
│  └── Ark-based task archival                                            │
│                                                                          │
│  L8: ECOSYSTEM (Federation)                                             │
│  ├── Cross-holon task sharing                                           │
│  ├── Federation-wide prioritization                                     │
│  └── Global resource allocation                                         │
│                                                                          │
│  L7: FEDERATION (Multi-Holon)                                           │
│  ├── Holon-to-holon task delegation                                     │
│  ├── Consensus-based prioritization                                     │
│  └── Distributed conflict resolution                                    │
│                                                                          │
│  L6: CLUSTER (Multi-Node)                                               │
│  ├── Node-level task distribution                                       │
│  ├── Load balancing across nodes                                        │
│  └── Quorum-based decisions                                             │
│                                                                          │
│  L5: NODE (Single Machine)                                              │
│  ├── Local task execution                                               │
│  ├── Resource monitoring                                                │
│  └── Health-based prioritization                                        │
│                                                                          │
│  L4: CONTAINER (Process Isolation)                                      │
│  ├── Container-scoped tasks                                             │
│  ├── Process lifecycle management                                       │
│  └── Resource limits enforcement                                        │
│                                                                          │
│  L3: HOLON (Agent Domain)                                               │
│  ├── Domain-specific task queues                                        │
│  ├── Agent specialization                                               │
│  └── Knowledge-based routing                                            │
│                                                                          │
│  L2: COMPONENT (Module)                                                 │
│  ├── Module-level tasks                                                 │
│  ├── Dependency tracking                                                │
│  └── Interface contracts                                                │
│                                                                          │
│  L1: FUNCTION (Code Unit)                                               │
│  ├── Micro-tasks (function-level)                                       │
│  ├── Code change tracking                                               │
│  └── Test coverage                                                      │
│                                                                          │
│  L0: RUNTIME (Execution)                                                │
│  ├── Immediate execution                                                │
│  ├── Real-time monitoring                                               │
│  └── Telemetry capture                                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Fractal Task Propagation

```
TASK CREATION AT L5 (Node Level)
────────────────────────────────

User creates: "Implement MaraAgent"

L5 (Node): Task created in local SQLite
    │
    ├──► L4 (Container): Task scoped to indrajaal-app container
    │
    ├──► L3 (Holon): Task assigned to Cortex domain
    │
    ├──► L2 (Component): Subtasks for Safety.fs, Orchestrator.fs
    │
    ├──► L1 (Function): Micro-tasks for each function
    │
    └──► L0 (Runtime): Execution telemetry

UPWARD PROPAGATION:
    │
    ├──► L6 (Cluster): Shared with other nodes via Zenoh
    │
    ├──► L7 (Federation): Visible to federated holons
    │
    ├──► L8 (Ecosystem): Aggregated in ecosystem metrics
    │
    └──► L9 (Universe): Archived for deep time
```

### 1.3 Level-Specific Task Attributes

| Level | ID Format | Scope | Persistence | Sync |
|-------|-----------|-------|-------------|------|
| L0 | UUID | Immediate | Memory | - |
| L1 | func:UUID | Function | Memory | - |
| L2 | mod:UUID | Module | SQLite | - |
| L3 | holon:UUID | Domain | SQLite | Local |
| L4 | container:UUID | Container | SQLite | Local |
| L5 | node:UUID | Node | SQLite | Local |
| L6 | cluster:52.1.0.0.0 | Cluster | SQLite+Zenoh | Mesh |
| L7 | fed:52.1.0.0.0 | Federation | DuckDB | Federation |
| L8 | eco:52.1.0.0.0 | Ecosystem | DuckDB | Global |
| L9 | ark:52.1.0.0.0 | Universe | Ark Archive | Eternal |

---

## 2. 10x10 Interaction Matrix

### 2.1 Matrix Definition

The 10x10 matrix maps 10 **Actors** against 10 **Actions** for complete coverage.

### 2.2 Actors (Rows)

| ID | Actor | Description |
|----|-------|-------------|
| A1 | Human Operator | Direct human interaction via CLI/GUI/TUI |
| A2 | Claude Agent | Constitutional AI (safety, ethics) |
| A3 | Gemini Agent | Technical AI (architecture, code) |
| A4 | Grok Agent | Pragmatic AI (external integration) |
| A5 | System Process | Automated background processes |
| A6 | Sentinel Agent | Health monitoring |
| A7 | Guardian Agent | Safety validation |
| A8 | Chaya Twin | Digital twin standalone |
| A9 | External API | REST/GraphQL clients |
| A10 | Federation Peer | Cross-holon coordination |

### 2.3 Actions (Columns)

| ID | Action | Description |
|----|--------|-------------|
| X1 | Create | Create new task |
| X2 | Read | List/view tasks |
| X3 | Update | Change task status/fields |
| X4 | Delete | Remove task |
| X5 | Assign | Assign task to agent |
| X6 | Prioritize | Change priority |
| X7 | Block/Unblock | Set blocking state |
| X8 | Depend | Add/remove dependencies |
| X9 | Sync | Synchronize with mesh |
| X10 | Archive | Move to deep storage |

### 2.4 Complete 10x10 Matrix

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               10x10 PLANNING INTERACTION MATRIX                                  │
├──────────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬────────────────┤
│ Actor\Act│  X1  │  X2  │  X3  │  X4  │  X5  │  X6  │  X7  │  X8  │  X9  │ X10  │ Interface      │
│          │Create│ Read │Update│Delete│Assign│ Prio │Block │Depend│ Sync │Archiv│                │
├──────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼────────────────┤
│A1 Human  │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │CLI/GUI/TUI/API │
│A2 Claude │  ✓   │  ✓   │  ✓   │  ○   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ○   │F# CLI only     │
│A3 Gemini │  ✓   │  ✓   │  ✓   │  ○   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ○   │F# CLI only     │
│A4 Grok   │  ✓   │  ✓   │  ✓   │  ○   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ○   │F# CLI only     │
│A5 System │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │Internal API    │
│A6 Sentinel│ ○   │  ✓   │  ○   │  ○   │  ○   │  ○   │  ✓   │  ○   │  ✓   │  ○   │Health events   │
│A7 Guardian│ ○   │  ✓   │  ✓   │  ○   │  ○   │  ○   │  ✓   │  ○   │  ✓   │  ○   │Safety gates    │
│A8 Chaya  │  ✓   │  ✓   │  ✓   │  ○   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │  ○   │Standalone mode │
│A9 ExtAPI │  ✓   │  ✓   │  ✓   │  ○   │  ○   │  ✓   │  ○   │  ○   │  ○   │  ○   │REST/GraphQL    │
│A10 FedPeer│ ✓   │  ✓   │  ✓   │  ○   │  ○   │  ✓   │  ✓   │  ✓   │  ✓   │  ✓   │Federation proto│
├──────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┼────────────────┤
│ Legend:  │  ✓ = Allowed   │  ○ = Restricted (requires approval)   │  ✗ = Denied              │
└──────────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.5 Permission Details

#### A1: Human Operator
- **Full access** to all actions
- Can use CLI, GUI, TUI, or API
- No restrictions (trusted principal)

#### A2-A4: AI Agents (Claude/Gemini/Grok)
- **Must use F# CLI only** (SC-TODO-004)
- Cannot directly access PROJECT_TODOLIST.md
- Delete requires Guardian approval
- Archive requires human approval

#### A5: System Process
- **Internal API access**
- Full automation capabilities
- Used for scheduled tasks, cleanup

#### A6: Sentinel Agent
- **Read-only** primarily
- Can block tasks on health issues
- Sync for health-based distribution

#### A7: Guardian Agent
- **Safety gates**
- Can block/unblock based on safety
- Update for safety status changes

#### A8: Chaya Digital Twin
- **Standalone operation**
- Local persistence when offline
- Sync on reconnection

#### A9: External API
- **Limited external access**
- Create, Read, Update, Prioritize only
- No destructive operations

#### A10: Federation Peer
- **Cross-holon coordination**
- Full sync capabilities
- Archive for deep time storage

---

## 3. Human, Agent, and Joint Use Scenarios

### 3.1 Human-Only Scenarios

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      HUMAN-ONLY USE SCENARIOS                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SCENARIO H1: Direct Task Management                                    │
│  ─────────────────────────────────────                                  │
│  Actor: Product Manager                                                 │
│  Interface: Prajna GUI                                                  │
│  Flow:                                                                  │
│    1. Open Prajna cockpit → Planning tab                                │
│    2. Review current sprint tasks                                       │
│    3. Create new feature task with P1 priority                          │
│    4. Assign to development team                                        │
│    5. Set dependencies                                                  │
│    6. Monitor progress on dashboard                                     │
│                                                                          │
│  SCENARIO H2: Emergency Task Creation                                   │
│  ─────────────────────────────────────                                  │
│  Actor: On-Call Engineer                                                │
│  Interface: CLI (sa-plan)                                               │
│  Flow:                                                                  │
│    1. Receive alert                                                     │
│    2. sa-plan add "URGENT: Fix production issue" --priority P0          │
│    3. sa-plan update <id> InProgress                                    │
│    4. Fix issue                                                         │
│    5. sa-plan update <id> Completed                                     │
│    6. Create postmortem task                                            │
│                                                                          │
│  SCENARIO H3: Sprint Planning                                           │
│  ─────────────────────────────────────                                  │
│  Actor: Scrum Master                                                    │
│  Interface: TUI (chaya)                                                 │
│  Flow:                                                                  │
│    1. chaya list --status Pending                                       │
│    2. Review backlog priorities                                         │
│    3. chaya update <id1> P1 (promote to sprint)                         │
│    4. chaya update <id2> P1                                             │
│    5. chaya deps <id1> --add <id2>                                      │
│    6. chaya sync (publish to team)                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Agent-Only Scenarios

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AGENT-ONLY USE SCENARIOS                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SCENARIO A1: Autonomous Code Implementation                            │
│  ─────────────────────────────────────────────                          │
│  Actor: Claude Agent                                                    │
│  Interface: F# CLI (dotnet run)                                         │
│  Flow:                                                                  │
│    1. Receive task from human: "Implement MaraAgent"                    │
│    2. sa-plan list --status Pending (find task)                         │
│    3. sa-plan update <id> InProgress                                    │
│    4. Analyze codebase (Explore agent)                                  │
│    5. Generate implementation                                           │
│    6. Run tests                                                         │
│    7. sa-plan update <id> Completed                                     │
│    8. Create follow-up tasks if needed                                  │
│                                                                          │
│  SCENARIO A2: Automated Quality Check                                   │
│  ─────────────────────────────────────────────                          │
│  Actor: System Process                                                  │
│  Interface: Internal API                                                │
│  Flow:                                                                  │
│    1. Scheduled job triggers                                            │
│    2. Query all InProgress tasks older than 24h                         │
│    3. Check if work is stalled                                          │
│    4. Create reminder/escalation tasks                                  │
│    5. Notify via Zenoh                                                  │
│                                                                          │
│  SCENARIO A3: Health-Based Task Blocking                                │
│  ─────────────────────────────────────────────                          │
│  Actor: Sentinel Agent                                                  │
│  Interface: Health events                                               │
│  Flow:                                                                  │
│    1. Detect system health degradation                                  │
│    2. Query tasks depending on unhealthy component                      │
│    3. Block affected tasks with reason                                  │
│    4. Publish alert                                                     │
│    5. Monitor for recovery                                              │
│    6. Unblock when healthy                                              │
│                                                                          │
│  SCENARIO A4: OODA Cycle Execution                                      │
│  ─────────────────────────────────────────────                          │
│  Actor: Chaya Digital Twin                                              │
│  Interface: Standalone mode                                             │
│  Flow:                                                                  │
│    1. chaya ooda (trigger cycle)                                        │
│    2. OBSERVE: Query current state                                      │
│    3. ORIENT: Prioritize by P0 > P1 > P2 > P3                          │
│    4. DECIDE: Select highest priority unblocked task                    │
│    5. ACT: Start task or recommend to human                             │
│    6. Repeat every 30 seconds                                           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Joint Human-Agent Scenarios

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    JOINT HUMAN-AGENT SCENARIOS                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SCENARIO J1: Pair Programming with AI                                  │
│  ─────────────────────────────────────                                  │
│  Actors: Human Developer + Claude Agent                                 │
│  Interface: CLI + Agent                                                 │
│  Flow:                                                                  │
│    [Human] sa-plan add "Implement feature X" --priority P1              │
│    [Human] sa-plan update <id> InProgress                               │
│    [Claude] Read task details via sa-plan show <id>                     │
│    [Claude] Propose implementation plan                                 │
│    [Human] Review and approve plan                                      │
│    [Claude] Generate code                                               │
│    [Human] Review and modify code                                       │
│    [Joint] Run tests together                                           │
│    [Human] sa-plan update <id> Completed                                │
│                                                                          │
│  SCENARIO J2: Tricameral Task Review                                    │
│  ─────────────────────────────────────                                  │
│  Actors: Human + Claude + Gemini + Grok                                 │
│  Interface: Prajna Cockpit + Agents                                     │
│  Flow:                                                                  │
│    [Human] Create architectural task in GUI                             │
│    [Claude] Assess constitutional/ethical alignment                     │
│    [Gemini] Assess technical feasibility                                │
│    [Grok] Assess practical implementation                               │
│    [All] Synthesize recommendations                                     │
│    [Human] Review synthesis, approve/modify                             │
│    [System] Update task with consensus                                  │
│                                                                          │
│  SCENARIO J3: Supervised Autonomous Execution                           │
│  ─────────────────────────────────────────────                          │
│  Actors: Human Supervisor + Multiple Agents                             │
│  Interface: Dashboard + Agent Swarm                                     │
│  Flow:                                                                  │
│    [Human] Review pending tasks on dashboard                            │
│    [Human] Approve batch for autonomous execution                       │
│    [Agents] Pick up approved tasks (OODA loop)                          │
│    [Agents] Execute with Guardian validation                            │
│    [System] Stream progress to dashboard                                │
│    [Human] Monitor, intervene if needed                                 │
│    [Agents] Complete and report                                         │
│    [Human] Final review and sign-off                                    │
│                                                                          │
│  SCENARIO J4: Escalation and Handoff                                    │
│  ─────────────────────────────────────────────                          │
│  Actors: Agent → Human                                                  │
│  Interface: Alert + CLI                                                 │
│  Flow:                                                                  │
│    [Agent] Attempt task implementation                                  │
│    [Agent] Encounter blocker (missing requirement)                      │
│    [Agent] sa-plan update <id> Blocked --reason "Need clarification"    │
│    [System] Alert human via Prajna                                      │
│    [Human] Receive alert, review task                                   │
│    [Human] Provide clarification                                        │
│    [Human] sa-plan update <id> Pending (unblock)                        │
│    [Agent] Resume task                                                  │
│                                                                          │
│  SCENARIO J5: Continuous Integration Loop                               │
│  ─────────────────────────────────────────────                          │
│  Actors: Human + Agents + System                                        │
│  Interface: Full stack                                                  │
│  Flow:                                                                  │
│    [Human] Push code change                                             │
│    [System] Create verification task automatically                      │
│    [Agent] Run tests (sa-plan update InProgress)                        │
│    [Agent] Report results                                               │
│    [System] Update task with results                                    │
│    [Guardian] Validate safety constraints                               │
│    [Human] Review if failures                                           │
│    [System] Mark Completed on success                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.4 Interaction Sequence Diagrams

```
J1: PAIR PROGRAMMING SEQUENCE
─────────────────────────────

Human           CLI           F# Gateway       SQLite        Agent
  │              │               │               │              │
  │──add task───►│               │               │              │
  │              │───validate───►│               │              │
  │              │               │───insert─────►│              │
  │              │◄──task id─────│◄──ok──────────│              │
  │◄─task id─────│               │               │              │
  │              │               │               │              │
  │              │               │  ┌────────────┴──────────────┤
  │              │               │  │                           │
  │              │               │◄─┼───sa-plan show <id>───────│
  │              │               │──┼──►read────────►│          │
  │              │               │◄─┼───task data───│          │
  │              │               │──┼───────────────────────────►│
  │              │               │  │                           │
  │              │               │  │     [Agent works]         │
  │              │               │  │                           │
  │              │               │◄─┼───sa-plan update──────────│
  │              │               │──┼──►update──────►│          │
  │              │               │◄─┼───ok──────────│          │
  │              │               │  │                           │
  │──review─────►│               │  │                           │
  │──complete───►│               │  │                           │
  │              │───validate───►│               │              │
  │              │               │───update─────►│              │
  │              │◄──ok──────────│◄──ok──────────│              │
  │◄─completed───│               │               │              │


J3: SUPERVISED AUTONOMOUS SEQUENCE
──────────────────────────────────

Human          Dashboard        Agent Pool       Guardian        Tasks
  │               │                 │               │              │
  │──review───────►│                │               │              │
  │               │◄────pending─────────────────────────────────────│
  │◄──list────────│                │               │              │
  │               │                │               │              │
  │──approve──────►│                │               │              │
  │               │───assign───────►│               │              │
  │               │                │               │              │
  │               │                │──pick task────────────────────►│
  │               │                │◄──task data───────────────────│
  │               │                │               │              │
  │               │                │──validate─────►│              │
  │               │                │◄──approved────│              │
  │               │                │               │              │
  │               │                │     [Execute]  │              │
  │               │                │               │              │
  │               │◄──progress─────│               │              │
  │◄──dashboard───│                │               │              │
  │               │                │               │              │
  │               │                │──complete─────────────────────►│
  │               │                │◄──ok──────────────────────────│
  │               │◄──updated──────│               │              │
  │◄──complete────│                │               │              │
  │               │                │               │              │
  │──sign off─────►│                │               │              │
```

---

## 4. Extended BDD Testing (100% Path Coverage)

### 4.1 Path Analysis

For 100% coverage, we analyze all possible paths through the system:

```
TOTAL PATHS CALCULATION
───────────────────────

States: 4 (Pending, InProgress, Completed, Blocked)
Transitions: 8 (valid transitions between states)
Actors: 10 (from 10x10 matrix)
Actions: 10 (from 10x10 matrix)
Levels: 9 (L1-L9 fractal)

Path Categories:
├── State transitions: 8 paths × 10 actors = 80 paths
├── Action combinations: 10 actions × 10 actors = 100 paths
├── Fractal propagation: 9 levels × 2 directions = 18 paths
├── Error paths: 20 error scenarios
├── Concurrent paths: 15 concurrency scenarios
├── Recovery paths: 10 recovery scenarios
└── Federation paths: 12 cross-holon scenarios

TOTAL: 255 unique paths to test
```

### 4.2 Additional BDD Scenarios (Fractal & Matrix)

```gherkin
# test/features/planning/L_fractal.feature

Feature: Fractal Task Propagation
  As a distributed system
  I want tasks to propagate across levels
  So that all layers stay synchronized

  @fractal @L5-to-L6
  Scenario: Task propagates from Node to Cluster
    Given I am on node "node-1" in cluster "cluster-A"
    When I create a task "Cluster Task"
    Then the task should exist locally on node-1
    And the task should propagate to other nodes in cluster-A
    And all nodes should have identical task state

  @fractal @L6-to-L7
  Scenario: Task propagates from Cluster to Federation
    Given cluster-A is federated with cluster-B
    When cluster-A creates a task with federation flag
    Then cluster-B should receive the task
    And the task should have federation provenance

  @fractal @L7-to-L8
  Scenario: Task aggregation at Ecosystem level
    Given 5 federated holons
    When each holon creates 10 tasks
    Then the ecosystem view should show 50 tasks
    And aggregated metrics should be correct

  @fractal @L8-to-L9
  Scenario: Deep time archival
    Given completed tasks older than 1 year
    When the archive cycle runs
    Then tasks should be moved to Ark storage
    And they should remain queryable from L9

  @fractal @L3-scope
  Scenario: Holon-scoped task isolation
    Given holon "Cortex" and holon "Safety"
    When Cortex creates a task
    Then Safety should not see the task by default
    And explicit sharing is required for visibility
```

```gherkin
# test/features/planning/L_matrix.feature

Feature: 10x10 Interaction Matrix
  As a security system
  I want role-based access control
  So that actors have appropriate permissions

  @matrix @human-full
  Scenario: Human has full access
    Given I am a human operator
    Then I should be able to Create tasks
    And I should be able to Read tasks
    And I should be able to Update tasks
    And I should be able to Delete tasks
    And I should be able to Assign tasks
    And I should be able to Prioritize tasks
    And I should be able to Block tasks
    And I should be able to add Dependencies
    And I should be able to Sync tasks
    And I should be able to Archive tasks

  @matrix @agent-restricted
  Scenario Outline: Agent has restricted access
    Given I am agent "<agent>"
    When I try to "<action>" a task
    Then the result should be "<result>"

    Examples:
      | agent  | action   | result     |
      | claude | Create   | allowed    |
      | claude | Read     | allowed    |
      | claude | Update   | allowed    |
      | claude | Delete   | restricted |
      | gemini | Create   | allowed    |
      | gemini | Delete   | restricted |
      | grok   | Archive  | restricted |

  @matrix @guardian-safety
  Scenario: Guardian can block for safety
    Given I am the Guardian agent
    And a task violates safety constraints
    When I block the task
    Then the task status should be Blocked
    And the reason should reference the constraint

  @matrix @federation-peer
  Scenario: Federation peer can sync
    Given I am a federation peer from holon-B
    When I sync tasks from holon-A
    Then I should receive all federated tasks
    And I should be able to update their status
```

```gherkin
# test/features/planning/L_joint.feature

Feature: Joint Human-Agent Scenarios
  As a collaborative system
  I want humans and agents to work together
  So that tasks are completed efficiently

  @joint @pair-programming
  Scenario: Pair programming task completion
    Given a human creates task "Implement feature"
    And assigns it to Claude agent
    When Claude starts the task
    And Claude generates code
    And human reviews the code
    And human approves the code
    And Claude runs tests
    And tests pass
    Then the task should be completable by human

  @joint @escalation
  Scenario: Agent escalates to human
    Given Claude is working on a task
    When Claude encounters an ambiguous requirement
    Then Claude should block the task
    And Claude should set reason "Need clarification"
    And human should receive notification
    When human provides clarification
    And unblocks the task
    Then Claude should resume work

  @joint @tricameral
  Scenario: Tricameral consensus on architecture task
    Given an architecture task requiring consensus
    When Claude assesses constitutional alignment
    And Gemini assesses technical feasibility
    And Grok assesses practical implementation
    Then a synthesis should be generated
    And human should review synthesis
    And task should be updated with consensus

  @joint @supervised-swarm
  Scenario: Supervised agent swarm execution
    Given 5 pending tasks approved for automation
    When agent swarm is activated
    Then agents should pick up tasks via OODA
    And human should see progress on dashboard
    And Guardian should validate each completion
    And human should be notified of completions
```

### 4.3 Complete Test Coverage Table

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE BDD COVERAGE TABLE                          │
├───────────────────────┬──────────────────────────────────────┬──────────┤
│ Category              │ Scenarios                             │ Count    │
├───────────────────────┼──────────────────────────────────────┼──────────┤
│ L1: Core              │ Types, IDs, Result monad             │ 50       │
│ L2: Infrastructure    │ SQLite, Zenoh, Markdown              │ 40       │
│ L3: Security          │ AccessControl, Validation            │ 60       │
│ L4: Validation        │ Input, Business rules                │ 45       │
│ L5: Domain            │ Task, Status, Priority               │ 55       │
│ L6: Component         │ Manager, Repository                  │ 50       │
│ L7: Integration       │ Multi-component flows                │ 35       │
│ L8: E2E               │ User journeys                        │ 25       │
│ L9: Ecosystem         │ Federation, mesh                     │ 20       │
├───────────────────────┼──────────────────────────────────────┼──────────┤
│ Fractal Propagation   │ L0-L9 up/down propagation           │ 25       │
│ 10x10 Matrix          │ All actor×action combinations        │ 100      │
│ Joint Scenarios       │ Human+Agent collaboration            │ 30       │
│ Error Paths           │ All error conditions                 │ 40       │
│ Concurrent Paths      │ Race conditions, conflicts           │ 25       │
│ Recovery Paths        │ Crash recovery, sync recovery        │ 20       │
│ Edge Cases            │ Boundary conditions                  │ 15       │
├───────────────────────┼──────────────────────────────────────┼──────────┤
│ TOTAL                 │                                      │ 635      │
└───────────────────────┴──────────────────────────────────────┴──────────┘
```

---

## 5. Quality Metrics

### 5.1 Coverage Targets

| Metric | Target | Current |
|--------|--------|---------|
| Statement Coverage | 100% | - |
| Branch Coverage | 100% | - |
| Path Coverage | 100% | - |
| Actor Coverage (10×10) | 100% | 100% |
| Action Coverage (10×10) | 100% | 100% |
| Fractal Level Coverage | 100% | 100% |
| Error Path Coverage | 100% | - |

### 5.2 Performance Targets

| Metric | Target | Constraint |
|--------|--------|------------|
| CLI Response | <100ms | SC-OODA-001 |
| GUI Response | <200ms | UX |
| OODA Cycle | <100ms | SC-OODA-001 |
| Mesh Sync | <500ms | NFR-007 |
| Zenoh Publish | <50ms | SC-BRIDGE-003 |

---

## 6. Deployment Considerations

### 6.1 Environment Matrix

| Environment | Human Access | Agent Access | Federation |
|-------------|--------------|--------------|------------|
| Development | Full | Full | Simulated |
| Staging | Full | Full | Real |
| Production | Full | Supervised | Real |

### 6.2 Feature Flags

| Flag | Description | Default |
|------|-------------|---------|
| `PLANNING_AGENT_AUTONOMY` | Allow unsupervised agent execution | false |
| `PLANNING_FEDERATION_ENABLED` | Enable cross-holon sync | true |
| `PLANNING_ARCHIVE_ENABLED` | Enable L9 archival | true |
| `PLANNING_OODA_AUTO` | Auto-run OODA cycles | true |

---

**End of Fractal Extension Document**

*Generated by Indrajaal Planning System v21.3.0-SIL6*
