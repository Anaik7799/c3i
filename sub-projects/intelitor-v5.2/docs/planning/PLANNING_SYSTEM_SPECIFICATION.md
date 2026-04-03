# Indrajaal Planning System Specification

**Version**: 21.3.0-SIL6
**Module**: Cepaf.Planning
**Status**: Production Ready
**Criticality**: P0 (CRITICAL)
**STAMP**: SC-TODO-001 to SC-TODO-008, SC-PLAN-001 to SC-PLAN-003

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Requirements & Specifications](#2-requirements--specifications)
3. [Architecture](#3-architecture)
4. [Implementation Details](#4-implementation-details)
5. [Control Flow](#5-control-flow)
6. [Data Flow](#6-data-flow)
7. [Interface Design (CLI/GUI/TUI)](#7-interface-design)
8. [Experience Design (UI/UX/CX/DX)](#8-experience-design)
9. [9-Layer BDD Testing Framework](#9-9-layer-bdd-testing-framework)
10. [STAMP Constraints & AOR Rules](#10-stamp-constraints--aor-rules)
11. [Formal Verification](#11-formal-verification)
12. [Appendices](#12-appendices)

---

## 1. Executive Summary

### 1.1 Purpose

The Indrajaal Planning System is the central task management and orchestration engine for the entire SIL-6 biomorphic organism. It provides:

- **Task Lifecycle Management**: Create, track, update, and complete tasks
- **Hierarchical Organization**: 5-level task numbering (X.X.X.X.X)
- **Multi-Interface Access**: CLI, GUI (Prajna Cockpit), TUI, API
- **Distributed Coordination**: Zenoh-based mesh synchronization
- **Formal Verification**: Agda proofs, Quint models, graph validation
- **Access Control**: Strict F#-only access per SC-TODO-001

### 1.2 Key Principles

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLANNING SYSTEM PRINCIPLES                    │
├─────────────────────────────────────────────────────────────────┤
│  1. SINGLE SOURCE OF TRUTH: SQLite/DuckDB (not markdown)        │
│  2. F# GATEWAY ONLY: All access via Cepaf.Planning CLI/API      │
│  3. EVENTUAL CONSISTENCY: Zenoh mesh synchronization            │
│  4. AUDIT TRAIL: Every mutation logged to Immutable Register    │
│  5. GRACEFUL DEGRADATION: Offline-first with sync on reconnect  │
│  6. DEVELOPER EXPERIENCE: <100ms response, intuitive commands   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 System Context

```
                    ┌─────────────────────┐
                    │   Human Operator    │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            ▼                  ▼                  ▼
     ┌──────────┐      ┌──────────────┐    ┌──────────┐
     │   CLI    │      │  Prajna GUI  │    │   TUI    │
     │ sa-plan  │      │   /prajna    │    │  chaya   │
     └────┬─────┘      └──────┬───────┘    └────┬─────┘
          │                   │                  │
          └───────────────────┼──────────────────┘
                              ▼
                 ┌────────────────────────┐
                 │    Cepaf.Planning.CLI  │
                 │    (F# Gateway)        │
                 └───────────┬────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
    ┌───────────┐     ┌──────────────┐    ┌───────────┐
    │  SQLite   │     │    Zenoh     │    │  DuckDB   │
    │  (State)  │     │   (Events)   │    │ (History) │
    └───────────┘     └──────────────┘    └───────────┘
```

---

## 2. Requirements & Specifications

### 2.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-001 | Create tasks with title, description, priority | P0 | ✓ |
| FR-002 | Update task status (Pending→InProgress→Completed) | P0 | ✓ |
| FR-003 | List tasks with filtering (by status, priority) | P0 | ✓ |
| FR-004 | Hierarchical task numbering (5 levels) | P1 | ✓ |
| FR-005 | Task dependencies and blocking relationships | P1 | ✓ |
| FR-006 | Generate markdown backup (PROJECT_TODOLIST.md) | P1 | ✓ |
| FR-007 | Zenoh event publishing for mesh sync | P1 | ✓ |
| FR-008 | OODA cycle integration (Observe→Orient→Decide→Act) | P2 | ✓ |
| FR-009 | Chaya Digital Twin standalone operation | P2 | ✓ |
| FR-010 | Import from legacy markdown format | P2 | ✓ |

### 2.2 Non-Functional Requirements

| ID | Requirement | Target | Measurement |
|----|-------------|--------|-------------|
| NFR-001 | Response time (CLI) | <100ms | p99 latency |
| NFR-002 | Response time (GUI) | <200ms | p99 latency |
| NFR-003 | Concurrent users | 50+ | Load test |
| NFR-004 | Data durability | 99.999% | MTBF |
| NFR-005 | Availability | 99.9% | Uptime |
| NFR-006 | Recovery time | <5s | RTO |
| NFR-007 | Sync latency (mesh) | <500ms | p95 |

### 2.3 Security Requirements

| ID | Requirement | Implementation |
|----|-------------|----------------|
| SR-001 | No direct file access to PROJECT_TODOLIST.md | AccessControl.fs |
| SR-002 | All mutations via F# gateway | SC-TODO-004 |
| SR-003 | Audit trail for all changes | Immutable Register |
| SR-004 | Command validation | Regex patterns |
| SR-005 | Agent identity verification | AgentId tracking |

### 2.4 Compatibility Requirements

| Platform | Support Level | Notes |
|----------|---------------|-------|
| Linux (NixOS) | Full | Primary development |
| macOS | Full | Tested |
| Windows (WSL) | Partial | Requires WSL2 |
| Container | Full | Podman rootless |

---

## 3. Architecture

### 3.1 Component Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CEPAF.PLANNING MODULE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     PRESENTATION LAYER                           │    │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │    │
│  │  │    CLI    │  │    GUI    │  │    TUI    │  │    API    │    │    │
│  │  │ sa-plan   │  │  Prajna   │  │   chaya   │  │   REST    │    │    │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘    │    │
│  └────────┼──────────────┼──────────────┼──────────────┼──────────┘    │
│           │              │              │              │                 │
│           └──────────────┴──────────────┴──────────────┘                 │
│                                   │                                      │
│  ┌────────────────────────────────▼────────────────────────────────┐    │
│  │                     APPLICATION LAYER                            │    │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │    │
│  │  │     Manager     │  │  AccessControl  │  │   Validation    │  │    │
│  │  │  (Orchestrator) │  │   (Security)    │  │   (Business)    │  │    │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘  │    │
│  └───────────┼───────────────────┼───────────────────┼─────────────┘    │
│              │                    │                    │                  │
│  ┌───────────▼───────────────────▼───────────────────▼─────────────┐    │
│  │                       DOMAIN LAYER                               │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │    │
│  │  │   Task   │  │  Status  │  │ Priority │  │  Events  │        │    │
│  │  │  Types   │  │  Machine │  │  Levels  │  │   Bus    │        │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    INFRASTRUCTURE LAYER                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │    │
│  │  │  Repository  │  │ ZenohAdapter │  │MarkdownGen   │          │    │
│  │  │   (SQLite)   │  │   (Mesh)     │  │  (Backup)    │          │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Module Structure

```
lib/cepaf/src/Cepaf.Planning/
├── Core/                          # Level 1 - Critical Foundation
│   ├── Types.fs                   # Base type definitions
│   ├── Ids.fs                     # ID generation (UUID, hierarchical)
│   ├── Result.fs                  # Result monad
│   └── Validation.fs              # Validation combinators
├── Domain/                        # Level 2 - Business Logic
│   ├── Task.fs                    # Task aggregate
│   ├── Events.fs                  # Domain events
│   └── OODA.fs                    # OODA cycle types
├── Domain.fs                      # Domain facade
├── AccessControl.fs               # Security enforcement (SC-TODO-*)
├── MarkdownParser.fs              # Legacy import
├── Repository.fs                  # SQLite persistence
├── ZenohAdapter.fs                # Mesh integration
├── Integration/
│   ├── ChayaIntegration.fs        # Digital Twin
│   └── OpenRouterParser.fs        # AI parsing
├── Chaya/
│   ├── StandaloneChaya.fs         # Offline operation
│   └── MeshSimulator.fs           # Testing support
└── Manager.fs                     # Application orchestrator

lib/cepaf/src/Cepaf.Planning.CLI/
└── Program.fs                     # CLI entry point
```

### 3.3 Layer Dependencies

```
┌─────────────────────────────────────────────┐
│          DEPENDENCY DIRECTION               │
│              (Top → Bottom)                 │
├─────────────────────────────────────────────┤
│                                             │
│   CLI/GUI/TUI  ──────────────────────────┐  │
│        │                                 │  │
│        ▼                                 │  │
│   Manager.fs  ◄─────── AccessControl.fs  │  │
│        │                     │           │  │
│        ▼                     ▼           │  │
│   Domain.fs  ◄────── Validation.fs       │  │
│        │                                 │  │
│        ▼                                 │  │
│   Repository.fs  ◄── ZenohAdapter.fs     │  │
│        │                     │           │  │
│        ▼                     ▼           │  │
│    Core/*.fs  ◄────── External Libs      │  │
│                                             │
└─────────────────────────────────────────────┘

INVARIANT: No upward dependencies allowed
INVARIANT: Core has zero dependencies on Domain/Application
```

### 3.4 State Machine

```
                    ┌─────────────┐
                    │   PENDING   │◄──────────────────────┐
                    └──────┬──────┘                       │
                           │                              │
                    start()│                              │ block()
                           ▼                              │
                    ┌─────────────┐                       │
              ┌─────│ IN_PROGRESS │──────────────────────►│
              │     └──────┬──────┘                       │
              │            │                              │
      pause() │            │ complete()                   │
              │            ▼                              │
              │     ┌─────────────┐                       │
              └────►│  COMPLETED  │                       │
                    └─────────────┘                       │
                           │                              │
                           │ reopen()                     │
                           └──────────────────────────────┘

TRANSITIONS:
  Pending → InProgress : start()
  InProgress → Completed : complete()
  InProgress → Pending : pause()
  Completed → Pending : reopen()
  Any → Blocked : block()
  Blocked → Pending : unblock()
```

---

## 4. Implementation Details

### 4.1 Core Types

```fsharp
// Task.fs - Core task aggregate
type TaskId = TaskId of string

type Priority =
    | P0  // Critical - Immediate action
    | P1  // High - Same day
    | P2  // Medium - This week
    | P3  // Low - Backlog

type Status =
    | Pending
    | InProgress
    | Completed
    | Blocked of reason: string

type Task = {
    Id: TaskId
    HierarchicalId: string        // "52.1.0.0.0"
    Title: string
    Description: string option
    Priority: Priority
    Status: Status
    Dependencies: TaskId list
    CreatedAt: DateTime
    UpdatedAt: DateTime
    CompletedAt: DateTime option
    Tags: string list
    Metadata: Map<string, string>
}
```

### 4.2 Repository Pattern

```fsharp
// Repository.fs - SQLite persistence
type ITaskRepository =
    abstract member GetAll: unit -> Task list
    abstract member GetById: TaskId -> Task option
    abstract member GetByStatus: Status -> Task list
    abstract member Create: Task -> Result<Task, string>
    abstract member Update: Task -> Result<Task, string>
    abstract member Delete: TaskId -> Result<unit, string>
    abstract member Search: query: string -> Task list

type SqliteTaskRepository(connectionString: string) =
    interface ITaskRepository with
        // Implementation using Dapper + SQLite
```

### 4.3 Manager (Orchestrator)

```fsharp
// Manager.fs - Application orchestrator
module Manager =

    /// Add a new task
    let addTask (title: string) (priority: Priority option) : Result<Task, string> =
        // 1. Validate input
        // 2. Generate hierarchical ID
        // 3. Create task in SQLite
        // 4. Publish to Zenoh
        // 5. Update markdown backup
        // 6. Return result

    /// Update task status
    let updateStatus (taskId: string) (status: Status) : Result<Task, string> =
        // 1. Validate state transition
        // 2. Update in SQLite
        // 3. Publish event to Zenoh
        // 4. Update markdown backup
        // 5. Return result

    /// List tasks with optional filter
    let listTasks (filter: TaskFilter option) : Task list =
        // Query SQLite with filter
```

### 4.4 Access Control Implementation

```fsharp
// AccessControl.fs - Security enforcement
module AccessControl =

    let private forbiddenPatterns = [
        @"cat\s+.*PROJECT_TODOLIST\.md"
        @"grep\s+.*PROJECT_TODOLIST\.md"
        // ... more patterns
    ]

    /// Validate access request
    let validateAccess (agent: AgentId) (method: AccessMethod) (path: string) : AccessResult =
        if isAgent agent && isDirectAccess method && targetsTodolist path then
            Blocked "SC-TODO-001: Use sa-plan CLI instead"
        elif isAuthorized method then
            Allowed
        else
            Denied "Unknown method"

    /// Build access control graph for verification
    let buildAccessControlGraph () : ACEdge list =
        // Graph-based access control model
```

---

## 5. Control Flow

### 5.1 Task Creation Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      TASK CREATION CONTROL FLOW                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  User Input                                                              │
│      │                                                                   │
│      ▼                                                                   │
│  ┌─────────────────┐                                                    │
│  │ 1. Parse Input  │ ◄── CLI: sa-plan add "title"                       │
│  │    Validate     │     GUI: Form submission                            │
│  └────────┬────────┘     TUI: chaya add "title"                         │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │ 2. Access Check │ ◄── AccessControl.validateAccess()                 │
│  │    SC-TODO-004  │     - Verify agent identity                        │
│  └────────┬────────┘     - Check authorized method                      │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │ 3. Generate ID  │ ◄── Ids.generateHierarchicalId()                   │
│  │    Hierarchical │     - Parent lookup                                 │
│  └────────┬────────┘     - Sibling count                                 │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │ 4. Validate     │ ◄── Validation.validateTask()                      │
│  │    Business     │     - Title not empty                               │
│  │    Rules        │     - Priority valid                                │
│  └────────┬────────┘     - Dependencies exist                            │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │ 5. Persist      │ ◄── Repository.create()                            │
│  │    SQLite       │     - INSERT with RETURNING                         │
│  └────────┬────────┘     - Transaction commit                            │
│           │                                                              │
│           ├─────────────────────────────────────┐                       │
│           ▼                                     ▼                       │
│  ┌─────────────────┐                   ┌─────────────────┐              │
│  │ 6a. Publish     │                   │ 6b. Update      │              │
│  │     Zenoh Event │                   │     Markdown    │              │
│  │ indrajaal/plan  │                   │ PROJECT_TODO.md │              │
│  └────────┬────────┘                   └────────┬────────┘              │
│           │                                     │                       │
│           └─────────────────┬───────────────────┘                       │
│                             ▼                                            │
│                    ┌─────────────────┐                                  │
│                    │ 7. Return Result│                                  │
│                    │    Task + ID    │                                  │
│                    └─────────────────┘                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Task Update Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      TASK UPDATE CONTROL FLOW                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  sa-plan update <id> <status>                                           │
│      │                                                                   │
│      ▼                                                                   │
│  ┌─────────────────┐                                                    │
│  │ 1. Parse Input  │ ◄── TaskId + Status                                │
│  └────────┬────────┘                                                    │
│           │                                                              │
│           ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                            │
│  │ 2. Lookup Task  │────►│ Task Not Found? │──► Error: "Task not found" │
│  │    by ID        │     │                 │                            │
│  └────────┬────────┘     └─────────────────┘                            │
│           │ found                                                        │
│           ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                            │
│  │ 3. Validate     │────►│ Invalid Trans?  │──► Error: "Invalid state"  │
│  │    Transition   │     │                 │                            │
│  └────────┬────────┘     └─────────────────┘                            │
│           │ valid                                                        │
│           ▼                                                              │
│  ┌─────────────────┐     ┌─────────────────┐                            │
│  │ 4. Check        │────►│ Blocked Deps?   │──► Error: "Blocked by X"   │
│  │    Dependencies │     │                 │                            │
│  └────────┬────────┘     └─────────────────┘                            │
│           │ clear                                                        │
│           ▼                                                              │
│  ┌─────────────────┐                                                    │
│  │ 5. Update       │ ◄── UPDATE tasks SET status = ? WHERE id = ?       │
│  │    SQLite       │     SET updated_at = NOW()                         │
│  └────────┬────────┘     SET completed_at = ? (if Completed)            │
│           │                                                              │
│           ├─────────────────────────────────────┐                       │
│           ▼                                     ▼                       │
│  ┌─────────────────┐                   ┌─────────────────┐              │
│  │ 6a. Zenoh Event │                   │ 6b. Markdown    │              │
│  │  TaskUpdated    │                   │     Sync        │              │
│  └────────┬────────┘                   └────────┬────────┘              │
│           │                                     │                       │
│           └─────────────────┬───────────────────┘                       │
│                             ▼                                            │
│                    ┌─────────────────┐                                  │
│                    │ 7. Return OK    │                                  │
│                    │    + Updated    │                                  │
│                    └─────────────────┘                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 OODA Cycle Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         OODA CYCLE FLOW                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        OBSERVE                                    │   │
│  │  - Query current task state from SQLite                          │   │
│  │  - Check Zenoh for mesh updates                                  │   │
│  │  - Assess system health (Sentinel)                               │   │
│  │  - Read environment (git status, build state)                    │   │
│  └──────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        ORIENT                                     │   │
│  │  - Prioritize tasks by P0 > P1 > P2 > P3                         │   │
│  │  - Analyze dependencies (topological sort)                       │   │
│  │  - Identify blockers                                             │   │
│  │  - Calculate critical path                                       │   │
│  └──────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                        DECIDE                                     │   │
│  │  - Select next task to execute                                   │   │
│  │  - Allocate resources (agents)                                   │   │
│  │  - Plan execution strategy                                       │   │
│  │  - Set success criteria                                          │   │
│  └──────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                         ACT                                       │   │
│  │  - Execute task (update status to InProgress)                    │   │
│  │  - Monitor execution                                             │   │
│  │  - Capture telemetry                                             │   │
│  │  - Complete or block based on outcome                            │   │
│  └──────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│                    ┌────────────────────────┐                           │
│                    │  FEEDBACK LOOP         │                           │
│                    │  Cycle Time: <100ms    │                           │
│                    │  (SC-OODA-001)         │                           │
│                    └────────────────────────┘                           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Data Flow

### 6.1 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐                                                        │
│  │   User/     │                                                        │
│  │   Agent     │                                                        │
│  └──────┬──────┘                                                        │
│         │                                                                │
│         │ Command (sa-plan add "Task")                                  │
│         ▼                                                                │
│  ╔══════════════════════════════════════════════════════════════════╗   │
│  ║                    F# PLANNING GATEWAY                            ║   │
│  ║  ┌──────────────────────────────────────────────────────────┐    ║   │
│  ║  │ Parse → Validate → AccessCheck → Execute → Respond       │    ║   │
│  ║  └──────────────────────────────────────────────────────────┘    ║   │
│  ╚══════════════════════════════════════════════════════════════════╝   │
│         │                │                     │                        │
│         │ Write          │ Publish             │ Write                  │
│         ▼                ▼                     ▼                        │
│  ┌─────────────┐  ┌─────────────┐      ┌─────────────┐                 │
│  │   SQLite    │  │    Zenoh    │      │  Markdown   │                 │
│  │  (Primary)  │  │   (Events)  │      │  (Backup)   │                 │
│  │             │  │             │      │             │                 │
│  │ tasks.db    │  │ indrajaal/  │      │ PROJECT_    │                 │
│  │             │  │ planning/   │      │ TODOLIST.md │                 │
│  └──────┬──────┘  └──────┬──────┘      └─────────────┘                 │
│         │                │                                              │
│         │ Replicate      │ Subscribe                                    │
│         ▼                ▼                                              │
│  ┌─────────────┐  ┌─────────────┐                                      │
│  │   DuckDB    │  │   Other     │                                      │
│  │  (History)  │  │   Nodes     │                                      │
│  │             │  │  (Mesh)     │                                      │
│  │ evolution/  │  │             │                                      │
│  │ tasks.duckdb│  │             │                                      │
│  └─────────────┘  └─────────────┘                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Data Stores

| Store | Type | Purpose | Location |
|-------|------|---------|----------|
| SQLite | Primary | Real-time task state | `data/holons/planning/tasks.db` |
| DuckDB | Analytical | Evolution history | `data/holons/planning/history.duckdb` |
| Markdown | Backup | Human-readable | `PROJECT_TODOLIST.md` |
| Zenoh | Event Bus | Mesh synchronization | `indrajaal/planning/events` |

### 6.3 Schema Definition

```sql
-- SQLite Schema: tasks.db

CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    hierarchical_id TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    priority INTEGER NOT NULL DEFAULT 2,  -- P0=0, P1=1, P2=2, P3=3
    status INTEGER NOT NULL DEFAULT 0,    -- Pending=0, InProgress=1, Completed=2, Blocked=3
    block_reason TEXT,
    parent_id TEXT REFERENCES tasks(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT,
    tags TEXT,  -- JSON array
    metadata TEXT  -- JSON object
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_hierarchical ON tasks(hierarchical_id);
CREATE INDEX idx_tasks_parent ON tasks(parent_id);

CREATE TABLE task_dependencies (
    task_id TEXT NOT NULL REFERENCES tasks(id),
    depends_on_id TEXT NOT NULL REFERENCES tasks(id),
    PRIMARY KEY (task_id, depends_on_id)
);

CREATE TABLE access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    agent_id TEXT NOT NULL,
    method TEXT NOT NULL,
    file_path TEXT NOT NULL,
    result TEXT NOT NULL,
    constraint_id TEXT
);
```

---

## 7. Interface Design

### 7.1 CLI Interface (sa-plan)

```
╔══════════════════════════════════════════════════════════════════════════╗
║                         SA-PLAN CLI REFERENCE                            ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  SYNOPSIS                                                                ║
║    sa-plan <command> [options] [arguments]                               ║
║                                                                          ║
║  COMMANDS                                                                ║
║                                                                          ║
║    list [--status <status>] [--priority <priority>]                      ║
║         List all tasks, optionally filtered                              ║
║         Status: Pending, InProgress, Completed, Blocked                  ║
║         Priority: P0, P1, P2, P3                                         ║
║                                                                          ║
║    add <title> [--priority <P0|P1|P2|P3>] [--parent <id>]               ║
║         Create a new task                                                ║
║         Default priority: P2                                             ║
║                                                                          ║
║    update <id> <status>                                                  ║
║         Update task status                                               ║
║         Status: Pending, InProgress, Completed, Blocked                  ║
║                                                                          ║
║    status                                                                ║
║         Show summary statistics                                          ║
║                                                                          ║
║    show <id>                                                             ║
║         Show detailed task information                                   ║
║                                                                          ║
║    deps <id>                                                             ║
║         Show task dependency tree                                        ║
║                                                                          ║
║    backup                                                                ║
║         Create timestamped backup                                        ║
║                                                                          ║
║    sync                                                                  ║
║         Synchronize with mesh nodes                                      ║
║                                                                          ║
║  EXAMPLES                                                                ║
║                                                                          ║
║    sa-plan list                                                          ║
║    sa-plan list --status InProgress                                      ║
║    sa-plan list --priority P0                                            ║
║    sa-plan add "Implement feature X" --priority P1                       ║
║    sa-plan update abc123 Completed                                       ║
║    sa-plan status                                                        ║
║    sa-plan show abc123                                                   ║
║                                                                          ║
║  OUTPUT FORMAT                                                           ║
║                                                                          ║
║    Default: Human-readable table                                         ║
║    --json: JSON format for scripting                                     ║
║    --compact: Minimal output                                             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### 7.2 TUI Interface (chaya)

```
╔══════════════════════════════════════════════════════════════════════════╗
║                         CHAYA TUI REFERENCE                              ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  SYNOPSIS                                                                ║
║    chaya <command> [options] [arguments]                                 ║
║                                                                          ║
║  COMMANDS                                                                ║
║                                                                          ║
║    status                                                                ║
║         Show Chaya Digital Twin status and health                        ║
║                                                                          ║
║    list [--status <status>]                                              ║
║         List tasks (standalone mode)                                     ║
║                                                                          ║
║    add <title> [P0|P1|P2|P3]                                            ║
║         Add task with optional priority                                  ║
║                                                                          ║
║    update <id> <status>                                                  ║
║         Update task status                                               ║
║                                                                          ║
║    ooda                                                                  ║
║         Run OODA cycle (SC-OODA-001: <100ms)                            ║
║                                                                          ║
║    mesh                                                                  ║
║         Show mesh topology and node status                               ║
║                                                                          ║
║    sync                                                                  ║
║         Synchronize with PROJECT_TODOLIST.md                             ║
║                                                                          ║
║  STANDALONE MODE                                                         ║
║                                                                          ║
║    Chaya operates independently when mesh is unavailable:                ║
║    - Local SQLite persistence                                            ║
║    - Simulated mesh for testing                                          ║
║    - Automatic sync on reconnection                                      ║
║                                                                          ║
║  EXAMPLES                                                                ║
║                                                                          ║
║    chaya status                                                          ║
║    chaya list                                                            ║
║    chaya add "Fix bug in module X" P1                                    ║
║    chaya update abc123 Completed                                         ║
║    chaya ooda                                                            ║
║    chaya mesh                                                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### 7.3 GUI Interface (Prajna Cockpit)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PRAJNA COCKPIT - PLANNING VIEW                       │
├─────────────────────────────────────────────────────────────────────────┤
│  [Dashboard] [Alarms] [Planning*] [Analytics] [Settings]                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────┬───────────────────────────┐│
│  │         TASK OVERVIEW                   │      QUICK ACTIONS        ││
│  │  ┌─────────────────────────────────┐    │  ┌───────────────────┐    ││
│  │  │ Total Tasks: 247                │    │  │ [+ Add Task]      │    ││
│  │  │ ▓▓▓▓▓░░░░░ Pending: 45 (18%)   │    │  │ [↻ Sync Mesh]     │    ││
│  │  │ ▓▓▓▓▓▓▓░░░ In Progress: 12 (5%)│    │  │ [📋 Export MD]    │    ││
│  │  │ ▓▓▓▓▓▓▓▓▓░ Completed: 190 (77%)│    │  │ [🔄 OODA Cycle]   │    ││
│  │  └─────────────────────────────────┘    │  └───────────────────┘    ││
│  └─────────────────────────────────────────┴───────────────────────────┘│
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                        TASK LIST                                     ││
│  │  ┌─────┬────────────────────────────────────┬──────┬──────┬───────┐ ││
│  │  │ ID  │ Title                              │ Pri  │Status│Actions│ ││
│  │  ├─────┼────────────────────────────────────┼──────┼──────┼───────┤ ││
│  │  │52.1 │ Implement MaraAgent.fs             │ [P0] │ ✓    │ ⋮     │ ││
│  │  │52.2 │ Antibody Logic in Guardian         │ [P0] │ ✓    │ ⋮     │ ││
│  │  │52.3 │ Healing Reflex in Orchestrator     │ [P0] │ ✓    │ ⋮     │ ││
│  │  │53.1 │ Federation Protocol Enhancement    │ [P1] │ ○    │ ⋮     │ ││
│  │  │53.2 │ Cross-Holon Knowledge Sharing      │ [P1] │ ○    │ ⋮     │ ││
│  │  └─────┴────────────────────────────────────┴──────┴──────┴───────┘ ││
│  │  [< Prev]  Page 1 of 12  [Next >]                                   ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                     DEPENDENCY GRAPH                                 ││
│  │                                                                      ││
│  │     [52.1] ──────► [52.2] ──────► [52.4]                            ││
│  │                       │                                              ││
│  │                       ▼                                              ││
│  │                    [52.3]                                            ││
│  │                                                                      ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.4 API Interface (REST)

```yaml
openapi: 3.0.0
info:
  title: Indrajaal Planning API
  version: 21.3.0

paths:
  /api/planning/tasks:
    get:
      summary: List all tasks
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [Pending, InProgress, Completed, Blocked]
        - name: priority
          in: query
          schema:
            type: string
            enum: [P0, P1, P2, P3]
      responses:
        200:
          description: List of tasks
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Task'

    post:
      summary: Create a new task
      requestBody:
        content:
          application/json:
            schema:
              type: object
              required: [title]
              properties:
                title:
                  type: string
                priority:
                  type: string
                  enum: [P0, P1, P2, P3]
                  default: P2
                parentId:
                  type: string
      responses:
        201:
          description: Task created

  /api/planning/tasks/{id}:
    get:
      summary: Get task by ID
      responses:
        200:
          description: Task details

    patch:
      summary: Update task
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                status:
                  type: string
                  enum: [Pending, InProgress, Completed, Blocked]
      responses:
        200:
          description: Task updated

  /api/planning/status:
    get:
      summary: Get planning statistics
      responses:
        200:
          description: Statistics

components:
  schemas:
    Task:
      type: object
      properties:
        id:
          type: string
        hierarchicalId:
          type: string
        title:
          type: string
        priority:
          type: string
        status:
          type: string
        createdAt:
          type: string
          format: date-time
        updatedAt:
          type: string
          format: date-time
```

---

## 8. Experience Design

### 8.1 User Experience (UX)

#### 8.1.1 Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Consistency** | Same commands across CLI/TUI/GUI |
| **Feedback** | Immediate response (<100ms) |
| **Error Prevention** | Validation before execution |
| **Recovery** | Clear error messages with solutions |
| **Efficiency** | Shortcuts and aliases |

#### 8.1.2 User Journeys

```
JOURNEY 1: Create and Complete Task
─────────────────────────────────────
1. User runs: sa-plan add "Fix login bug" --priority P1
2. System validates input
3. System creates task with ID (e.g., "abc123")
4. System displays: "✅ Task added: abc123"
5. User works on task
6. User runs: sa-plan update abc123 Completed
7. System updates status
8. System displays: "✅ Task abc123 updated to Completed"

JOURNEY 2: Review and Prioritize
─────────────────────────────────────
1. User runs: sa-plan list --status Pending
2. System displays pending tasks sorted by priority
3. User identifies high-priority item
4. User runs: sa-plan show <id> (for details)
5. User runs: sa-plan update <id> InProgress
6. User begins work

JOURNEY 3: OODA Cycle
─────────────────────────────────────
1. User runs: chaya ooda
2. System OBSERVES: queries current state
3. System ORIENTS: prioritizes tasks
4. System DECIDES: selects next task
5. System displays recommendation
6. User reviews and approves
7. System ACTS: updates status
8. Cycle repeats
```

#### 8.1.3 Error Messages

```
ERROR MESSAGE DESIGN
─────────────────────────────────────

❌ BAD:
   "Error: Invalid input"

✅ GOOD:
   "Error: Task ID 'xyz' not found.

    Did you mean one of these?
    - abc123 (52.1 - MaraAgent)
    - def456 (52.2 - Antibody)

    Run 'sa-plan list' to see all tasks."

❌ BAD:
   "Access denied"

✅ GOOD:
   "⚠️ SC-TODO-001 Violation: Direct file access blocked.

    You cannot read PROJECT_TODOLIST.md directly.
    Use the authorized command instead:

      sa-plan list

    See: .claude/rules/todolist-access-control.md"
```

### 8.2 Developer Experience (DX)

#### 8.2.1 API Design Principles

| Principle | Example |
|-----------|---------|
| **Predictable** | `Manager.addTask`, `Manager.updateStatus` |
| **Composable** | `Result.bind`, `Result.map` |
| **Type-Safe** | Discriminated unions for Status, Priority |
| **Documented** | XML doc comments on all public APIs |

#### 8.2.2 Code Examples

```fsharp
// F# API Usage Example

open Cepaf.Planning

// Create a task
let result =
    Manager.addTask "Implement feature X" (Some Priority.P1)
    |> Result.bind (fun task ->
        printfn "Created: %s" task.Id
        Ok task
    )

// List tasks
let pendingTasks =
    Manager.listTasks (Some { Status = Some Pending; Priority = None })

// Update status with validation
let updateResult =
    Manager.updateStatus "abc123" Status.Completed
    |> Result.mapError (fun err ->
        printfn "Error: %s" err
        err
    )

// OODA cycle
let cycle = OODA.runCycle()
match cycle.Decision with
| Some task -> printfn "Next task: %s" task.Title
| None -> printfn "No pending tasks"
```

#### 8.2.3 Extension Points

```fsharp
// Custom task filter
let customFilter (task: Task) =
    task.Priority = P0 && task.Status = Pending

let criticalTasks = Manager.listTasks None |> List.filter customFilter

// Custom event handler
ZenohAdapter.subscribe "indrajaal/planning/events" (fun event ->
    match event with
    | TaskCreated task -> handleNewTask task
    | TaskUpdated (id, status) -> handleUpdate id status
    | _ -> ()
)
```

### 8.3 Customer Experience (CX)

#### 8.3.1 Onboarding Flow

```
STEP 1: First Run
─────────────────
$ sa-plan status

  Welcome to Indrajaal Planning System v21.3.0!

  Quick Start:
    sa-plan add "My first task"    # Create a task
    sa-plan list                   # View all tasks
    sa-plan update <id> Completed  # Complete a task

  Learn more: docs/planning/PLANNING_SYSTEM_SPECIFICATION.md

STEP 2: Create First Task
─────────────────────────
$ sa-plan add "Review documentation"

  ✅ Task added: 8f3a2b1c

  View it: sa-plan show 8f3a2b1c
  Update it: sa-plan update 8f3a2b1c InProgress

STEP 3: Track Progress
──────────────────────
$ sa-plan list

  TASKS: 1 total
  ─────────────────────────────────────────────────────
    ID       Title                    Pri   Status
  ─────────────────────────────────────────────────────
    8f3a2b1c Review documentation     [P2]  ○ Pending
  ─────────────────────────────────────────────────────
```

#### 8.3.2 Help System

```
$ sa-plan help

INDRAJAAL PLANNING SYSTEM
═════════════════════════

A task management system for the SIL-6 biomorphic organism.

QUICK REFERENCE:
  sa-plan list              List all tasks
  sa-plan add <title>       Create new task
  sa-plan update <id> <s>   Update task status
  sa-plan status            Show summary
  sa-plan help <command>    Get help on command

DETAILED HELP:
  sa-plan help list         Learn about filtering
  sa-plan help add          Learn about priorities
  sa-plan help update       Learn about status transitions

DOCUMENTATION:
  Full specification: docs/planning/PLANNING_SYSTEM_SPECIFICATION.md
  BDD tests: test/features/planning/

SUPPORT:
  Issues: https://github.com/anthropics/claude-code/issues
```

### 8.4 UI Design Guidelines

#### 8.4.1 Color Coding

| Color | Meaning | Usage |
|-------|---------|-------|
| 🟢 Green | Success, Completed | Task completion, success messages |
| 🟡 Yellow | Warning, InProgress | Active tasks, warnings |
| 🔴 Red | Error, Blocked | Errors, blocked tasks |
| 🔵 Blue | Info, Pending | Information, pending tasks |
| ⚪ Gray | Inactive | Disabled options |

#### 8.4.2 Priority Indicators

```
[P0] ████████████ CRITICAL  (Red, Bold)
[P1] ████████░░░░ HIGH      (Orange)
[P2] ████░░░░░░░░ MEDIUM    (Yellow)
[P3] ██░░░░░░░░░░ LOW       (Gray)
```

#### 8.4.3 Status Indicators

```
○ Pending     (Empty circle)
◐ InProgress  (Half-filled circle, animated)
✓ Completed   (Checkmark, green)
⊘ Blocked     (Slashed circle, red)
```

---

## 9. 9-Layer BDD Testing Framework

### 9.1 Testing Pyramid

```
                          ▲
                         /│\
                        / │ \
                       /  │  \       L9: Ecosystem (Federation)
                      /   │   \
                     /────┼────\     L8: E2E User Journeys
                    /     │     \
                   /──────┼──────\   L7: Integration (Multi-Component)
                  /       │       \
                 /────────┼────────\ L6: Component (Manager, Repository)
                /         │         \
               /──────────┼──────────\L5: Domain (Task, Status, Priority)
              /           │           \
             /────────────┼────────────\L4: Validation (Input, Business Rules)
            /             │             \
           /──────────────┼──────────────\L3: Security (AccessControl)
          /               │               \
         /────────────────┼────────────────\L2: Infrastructure (SQLite, Zenoh)
        /                 │                 \
       /──────────────────┼──────────────────\L1: Core (Types, Ids, Result)
      ─────────────────────────────────────────
```

### 9.2 Layer Definitions

| Layer | Name | Focus | Test Count |
|-------|------|-------|------------|
| L1 | Core | Types, IDs, Result monad | 50+ |
| L2 | Infrastructure | SQLite, Zenoh, Markdown | 40+ |
| L3 | Security | Access control, validation | 60+ |
| L4 | Validation | Input, business rules | 45+ |
| L5 | Domain | Task, Status, Priority | 55+ |
| L6 | Component | Manager, Repository | 50+ |
| L7 | Integration | Multi-component flows | 35+ |
| L8 | E2E | User journeys | 25+ |
| L9 | Ecosystem | Federation, mesh | 20+ |

### 9.3 Feature Files

#### L1: Core Layer Tests

```gherkin
# test/features/planning/L1_core.feature

Feature: Core Types and Utilities
  As a developer
  I want type-safe core utilities
  So that the system is reliable

  @L1 @core @types
  Scenario: TaskId generation is unique
    Given I generate 1000 TaskIds
    Then all TaskIds should be unique
    And all TaskIds should be valid UUIDs

  @L1 @core @hierarchical
  Scenario Outline: Hierarchical ID generation
    Given a parent task with ID "<parent_id>"
    And there are <sibling_count> existing children
    When I generate a new hierarchical ID
    Then the ID should be "<expected_id>"

    Examples:
      | parent_id   | sibling_count | expected_id   |
      | 52.0.0.0.0  | 0             | 52.1.0.0.0    |
      | 52.0.0.0.0  | 3             | 52.4.0.0.0    |
      | 52.1.0.0.0  | 0             | 52.1.1.0.0    |
      | 52.1.2.0.0  | 5             | 52.1.2.6.0    |

  @L1 @core @result
  Scenario: Result monad bind operation
    Given a successful result with value "test"
    When I bind a function that appends "123"
    Then the result should be successful
    And the value should be "test123"

  @L1 @core @result @error
  Scenario: Result monad error propagation
    Given a failed result with error "initial error"
    When I bind any function
    Then the result should be failed
    And the error should be "initial error"
```

#### L2: Infrastructure Layer Tests

```gherkin
# test/features/planning/L2_infrastructure.feature

Feature: Infrastructure Layer
  As a system
  I want reliable persistence and messaging
  So that data is never lost

  @L2 @sqlite @persistence
  Scenario: SQLite task persistence
    Given an empty SQLite database
    When I create a task with title "Test Task"
    And I restart the application
    Then the task should still exist
    And the title should be "Test Task"

  @L2 @sqlite @transactions
  Scenario: SQLite transaction rollback on error
    Given a task with ID "existing-task"
    When I start a transaction
    And I update the task title to "New Title"
    And an error occurs during commit
    Then the task title should be unchanged
    And no partial updates should exist

  @L2 @zenoh @publish
  Scenario: Zenoh event publishing
    Given a Zenoh connection is established
    When I create a new task
    Then a TaskCreated event should be published
    And the event should contain the task ID
    And the event topic should be "indrajaal/planning/events"

  @L2 @zenoh @subscribe
  Scenario: Zenoh event subscription
    Given I subscribe to "indrajaal/planning/events"
    When another node creates a task
    Then I should receive a TaskCreated event
    And my local cache should be updated

  @L2 @markdown @generation
  Scenario: Markdown backup generation
    Given 5 tasks exist in the database
    When I trigger markdown generation
    Then PROJECT_TODOLIST.md should be created
    And it should contain all 5 tasks
    And it should be properly formatted
```

#### L3: Security Layer Tests

```gherkin
# test/features/planning/L3_security.feature

Feature: Access Control Security
  As a security system
  I want to enforce access policies
  So that unauthorized access is blocked

  @L3 @security @sc-todo-001
  Scenario: Block agent direct read of PROJECT_TODOLIST.md
    Given I am an agent named "claude"
    When I attempt to read "PROJECT_TODOLIST.md" directly
    Then the access should be blocked
    And the reason should reference "SC-TODO-001"
    And an access log entry should be created

  @L3 @security @sc-todo-002
  Scenario: Block agent direct write to PROJECT_TODOLIST.md
    Given I am an agent named "gemini"
    When I attempt to write to "PROJECT_TODOLIST.md"
    Then the access should be blocked
    And the reason should reference "SC-TODO-002"

  @L3 @security @sc-todo-003
  Scenario Outline: Block shell commands accessing todolist
    Given I am an agent named "<agent>"
    When I attempt to run "<command>"
    Then the command should be blocked
    And the reason should reference "SC-TODO-003"

    Examples:
      | agent  | command                              |
      | claude | cat PROJECT_TODOLIST.md              |
      | gemini | head PROJECT_TODOLIST.md             |
      | grok   | grep "pattern" PROJECT_TODOLIST.md   |
      | claude | sed -i 's/a/b/' PROJECT_TODOLIST.md  |

  @L3 @security @authorized
  Scenario: Allow authorized F# CLI access
    Given I am an agent named "claude"
    When I access tasks via "sa-plan list"
    Then the access should be allowed
    And tasks should be returned

  @L3 @security @human
  Scenario: Allow human direct access
    Given I am a human operator
    When I read "PROJECT_TODOLIST.md" directly
    Then the access should be allowed
    And the file contents should be returned

  @L3 @security @graph
  Scenario: Graph verification finds no forbidden paths
    Given the access control graph is built
    When I run graph verification
    Then no forbidden paths should exist
    And all agent→direct→file paths should be blocked
```

#### L4: Validation Layer Tests

```gherkin
# test/features/planning/L4_validation.feature

Feature: Input Validation
  As a user
  I want clear validation
  So that I understand what's wrong

  @L4 @validation @title
  Scenario Outline: Task title validation
    When I create a task with title "<title>"
    Then the result should be "<result>"
    And the message should contain "<message>"

    Examples:
      | title                    | result  | message              |
      |                          | error   | Title cannot be empty|
      | a                        | error   | Title too short      |
      | Valid task title         | success |                      |
      | A very long title...x500 | error   | Title too long       |

  @L4 @validation @priority
  Scenario Outline: Priority validation
    When I create a task with priority "<priority>"
    Then the result should be "<result>"

    Examples:
      | priority | result  |
      | P0       | success |
      | P1       | success |
      | P2       | success |
      | P3       | success |
      | P4       | error   |
      | HIGH     | error   |

  @L4 @validation @status-transition
  Scenario Outline: Status transition validation
    Given a task with status "<from_status>"
    When I try to change status to "<to_status>"
    Then the transition should be "<result>"

    Examples:
      | from_status | to_status  | result    |
      | Pending     | InProgress | allowed   |
      | Pending     | Completed  | forbidden |
      | InProgress  | Completed  | allowed   |
      | InProgress  | Pending    | allowed   |
      | Completed   | Pending    | allowed   |
      | Completed   | InProgress | forbidden |
      | Blocked     | Pending    | allowed   |

  @L4 @validation @dependencies
  Scenario: Cannot complete task with incomplete dependencies
    Given a task "A" depends on task "B"
    And task "B" is Pending
    When I try to complete task "A"
    Then the update should fail
    And the message should say "Blocked by incomplete dependency: B"
```

#### L5: Domain Layer Tests

```gherkin
# test/features/planning/L5_domain.feature

Feature: Domain Logic
  As a domain expert
  I want correct business logic
  So that the system behaves properly

  @L5 @domain @task
  Scenario: Task creation with all fields
    When I create a task with:
      | field       | value               |
      | title       | Implement feature X |
      | description | Full description    |
      | priority    | P1                  |
      | tags        | feature, v21        |
    Then the task should be created
    And the status should be "Pending"
    And the createdAt should be now
    And the updatedAt should equal createdAt

  @L5 @domain @completion
  Scenario: Task completion sets completedAt
    Given an InProgress task
    When I complete the task
    Then completedAt should be set
    And status should be "Completed"
    And updatedAt should be updated

  @L5 @domain @hierarchy
  Scenario: Child tasks inherit parent context
    Given a parent task in category "52.0.0.0.0"
    When I create a child task
    Then the child ID should start with "52."
    And the child should reference the parent

  @L5 @domain @priority-sorting
  Scenario: Tasks sort by priority then date
    Given tasks with priorities P2, P0, P1, P3
    When I list tasks with default sorting
    Then they should be ordered P0, P1, P2, P3
    And within same priority, older tasks first
```

#### L6: Component Layer Tests

```gherkin
# test/features/planning/L6_component.feature

Feature: Component Integration
  As a component
  I want to integrate correctly
  So that the system works end-to-end

  @L6 @manager @create
  Scenario: Manager.addTask creates and persists
    When I call Manager.addTask "New Task" with priority P1
    Then the task should be in SQLite
    And an event should be published to Zenoh
    And PROJECT_TODOLIST.md should be updated

  @L6 @manager @update
  Scenario: Manager.updateStatus validates and updates
    Given a pending task with ID "abc123"
    When I call Manager.updateStatus "abc123" InProgress
    Then the task status should change
    And updatedAt should be updated
    And a TaskUpdated event should be published

  @L6 @repository @query
  Scenario: Repository filters correctly
    Given 10 Pending, 5 InProgress, and 15 Completed tasks
    When I query with status filter "InProgress"
    Then exactly 5 tasks should be returned
    And all should have status "InProgress"

  @L6 @repository @pagination
  Scenario: Repository supports pagination
    Given 100 tasks exist
    When I query with page=2 and pageSize=20
    Then 20 tasks should be returned
    And they should be tasks 21-40
```

#### L7: Integration Layer Tests

```gherkin
# test/features/planning/L7_integration.feature

Feature: Multi-Component Integration
  As a system
  I want components to work together
  So that workflows complete successfully

  @L7 @integration @full-lifecycle
  Scenario: Complete task lifecycle
    When I create a task "Lifecycle Test"
    And I start the task
    And I complete the task
    Then the task should have 3 status changes in history
    And 3 Zenoh events should have been published
    And the markdown should show completed

  @L7 @integration @concurrent
  Scenario: Concurrent task updates
    Given a pending task
    When two processes try to start it simultaneously
    Then only one should succeed
    And the other should get a conflict error
    And the task should be InProgress (not corrupted)

  @L7 @integration @recovery
  Scenario: Recovery after crash
    Given I create a task
    And the process crashes before Zenoh publish
    When the process restarts
    Then the orphaned event should be republished
    And state should be consistent

  @L7 @integration @offline-sync
  Scenario: Offline operation and sync
    Given I am offline
    When I create 3 tasks locally
    And I go online
    Then all 3 tasks should sync to mesh
    And other nodes should receive them
```

#### L8: E2E User Journey Tests

```gherkin
# test/features/planning/L8_e2e.feature

Feature: End-to-End User Journeys
  As a user
  I want complete workflows to work
  So that I can accomplish my goals

  @L8 @e2e @cli @happy-path
  Scenario: Complete CLI workflow
    Given a fresh system
    When I run "sa-plan add 'First Task' --priority P1"
    And I run "sa-plan list"
    And I capture the task ID
    And I run "sa-plan update <id> InProgress"
    And I run "sa-plan update <id> Completed"
    And I run "sa-plan status"
    Then the status should show 1 completed task

  @L8 @e2e @gui @prajna
  Scenario: Prajna cockpit workflow
    Given I open the Prajna cockpit
    When I click "Add Task"
    And I fill in "Implement feature" with priority P1
    And I click "Save"
    Then the task should appear in the list
    When I click the task
    And I click "Start"
    Then the status should change to "In Progress"

  @L8 @e2e @tui @chaya
  Scenario: Chaya TUI workflow
    Given I run "chaya status"
    When I run "chaya add 'TUI Task' P2"
    And I run "chaya list"
    And I run "chaya ooda"
    Then the OODA cycle should complete in <100ms
    And recommendations should be displayed

  @L8 @e2e @api @rest
  Scenario: REST API workflow
    Given I have an API token
    When I POST to /api/planning/tasks with {"title": "API Task"}
    And I GET /api/planning/tasks
    Then the response should include my task
    When I PATCH /api/planning/tasks/<id> with {"status": "Completed"}
    Then the task should be completed
```

#### L9: Ecosystem Layer Tests

```gherkin
# test/features/planning/L9_ecosystem.feature

Feature: Ecosystem and Federation
  As a distributed system
  I want mesh coordination to work
  So that all nodes stay synchronized

  @L9 @ecosystem @mesh
  Scenario: Multi-node synchronization
    Given 3 nodes in the mesh
    When node 1 creates a task
    Then nodes 2 and 3 should receive the task within 500ms
    And all nodes should have identical state

  @L9 @ecosystem @partition
  Scenario: Network partition recovery
    Given 3 nodes in the mesh
    When node 3 is partitioned
    And nodes 1 and 2 create tasks
    And node 3 reconnects
    Then node 3 should sync all missed tasks
    And no duplicates should exist

  @L9 @ecosystem @conflict
  Scenario: Conflict resolution
    Given 3 nodes in the mesh
    And all nodes have task "abc123" as Pending
    When node 1 sets status to InProgress
    And node 2 sets status to Completed (before seeing node 1's change)
    Then the conflict should be resolved
    And the final status should be deterministic (latest wins)

  @L9 @ecosystem @federation
  Scenario: Cross-holon task visibility
    Given holon A and holon B are federated
    When holon A creates a task with federation flag
    Then holon B should see the task
    And updates from holon B should propagate to holon A

  @L9 @ecosystem @formal-verification
  Scenario: Quint model verification
    Given the todolist_access_control.qnt model
    When I run quint verify
    Then all invariants should pass
    And no safety violations should be found
    And all temporal properties should hold
```

### 9.4 Test Coverage Matrix

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BDD TEST COVERAGE MATRIX                             │
├───────────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬──────┤
│ Component │ L1  │ L2  │ L3  │ L4  │ L5  │ L6  │ L7  │ L8  │ L9  │Total │
├───────────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼──────┤
│ Types     │ 15  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  15  │
│ Ids       │ 20  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  20  │
│ Result    │ 15  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  15  │
│ SQLite    │  -  │ 20  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  20  │
│ Zenoh     │  -  │ 15  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  15  │
│ Markdown  │  -  │  5  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │   5  │
│ Access    │  -  │  -  │ 60  │  -  │  -  │  -  │  -  │  -  │  -  │  60  │
│ Validate  │  -  │  -  │  -  │ 45  │  -  │  -  │  -  │  -  │  -  │  45  │
│ Task      │  -  │  -  │  -  │  -  │ 30  │  -  │  -  │  -  │  -  │  30  │
│ Status    │  -  │  -  │  -  │  -  │ 15  │  -  │  -  │  -  │  -  │  15  │
│ Priority  │  -  │  -  │  -  │  -  │ 10  │  -  │  -  │  -  │  -  │  10  │
│ Manager   │  -  │  -  │  -  │  -  │  -  │ 30  │  -  │  -  │  -  │  30  │
│ Repo      │  -  │  -  │  -  │  -  │  -  │ 20  │  -  │  -  │  -  │  20  │
│ Lifecycle │  -  │  -  │  -  │  -  │  -  │  -  │ 15  │  -  │  -  │  15  │
│ Concur    │  -  │  -  │  -  │  -  │  -  │  -  │ 10  │  -  │  -  │  10  │
│ Recovery  │  -  │  -  │  -  │  -  │  -  │  -  │ 10  │  -  │  -  │  10  │
│ CLI       │  -  │  -  │  -  │  -  │  -  │  -  │  -  │ 10  │  -  │  10  │
│ GUI       │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  8  │  -  │   8  │
│ TUI       │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  7  │  -  │   7  │
│ Mesh      │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │ 10  │  10  │
│ Partition │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  5  │   5  │
│ Federation│  -  │  -  │  -  │  -  │  -  │  -  │  -  │  -  │  5  │   5  │
├───────────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼──────┤
│ TOTAL     │ 50  │ 40  │ 60  │ 45  │ 55  │ 50  │ 35  │ 25  │ 20  │ 380  │
└───────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴──────┘
```

---

## 10. STAMP Constraints & AOR Rules

### 10.1 STAMP Constraints

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| SC-TODO-001 | Agents SHALL NOT read PROJECT_TODOLIST.md directly | CRITICAL | AccessControl.fs |
| SC-TODO-002 | Agents SHALL NOT write PROJECT_TODOLIST.md directly | CRITICAL | AccessControl.fs |
| SC-TODO-003 | Agents SHALL NOT use shell to access PROJECT_TODOLIST.md | CRITICAL | Command filter |
| SC-TODO-004 | All todolist access MUST use F# Planning CLI | CRITICAL | Gateway |
| SC-TODO-005 | PROJECT_TODOLIST.md is generated artifact ONLY | HIGH | Header marker |
| SC-TODO-006 | Todolist state is authoritative in SQLite/DuckDB | CRITICAL | AOR-HOLON-009 |
| SC-TODO-007 | F# Planning CLI sync generates markdown backup | HIGH | Automatic |
| SC-TODO-008 | Violations MUST be logged to Immutable Register | CRITICAL | Audit trail |
| SC-PLAN-001 | F# Planning CLI is authoritative | CRITICAL | Single entry |
| SC-PLAN-002 | PROJECT_TODOLIST.md sync via sa-plan | HIGH | Backup only |
| SC-PLAN-003 | SQLite persistence for tasks | CRITICAL | Primary store |
| SC-OODA-001 | OODA cycle MUST complete in <100ms | HIGH | Performance |

### 10.2 AOR Rules

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-TODO-001 | NEVER use Read tool on PROJECT_TODOLIST.md | BLOCK + ALERT |
| AOR-TODO-002 | NEVER use Write/Edit tool on PROJECT_TODOLIST.md | BLOCK + ALERT |
| AOR-TODO-003 | NEVER use Bash cat/head/tail on PROJECT_TODOLIST.md | BLOCK + ALERT |
| AOR-TODO-004 | NEVER use sed/awk/grep on PROJECT_TODOLIST.md | BLOCK + ALERT |
| AOR-TODO-005 | ALWAYS use `sa-plan list` to view tasks | Required |
| AOR-TODO-006 | ALWAYS use `sa-plan add` to create tasks | Required |
| AOR-TODO-007 | ALWAYS use `sa-plan update` to change status | Required |
| AOR-TODO-008 | ALWAYS use `sa-plan status` for summary | Required |
| AOR-TODO-009 | Chaya Digital Twin uses `chaya` commands | Required |
| AOR-TODO-010 | Log all access attempts to telemetry | Required |
| AOR-PLAN-001 | Use F# Planning CLI for task management | Required |
| AOR-PLAN-002 | Sync task changes to PROJECT_TODOLIST.md | Automatic |
| AOR-PLAN-003 | Use priority levels P0-P3 | Required |

---

## 11. Formal Verification

### 11.1 Agda Proofs

See: `docs/formal_specs/agda/TodolistAccessControl.agda`

Key theorems:
- `direct-access-blocked`: Agents cannot directly access todolist
- `authorized-access-allowed`: F# CLI access always allowed
- `safety-theorem`: No sequence leads to unauthorized access

### 11.2 Quint Models

See: `docs/formal_specs/quint/todolist_access_control.qnt`

Key invariants:
- `directAccessInvariant`: No direct agent access during execution
- `authorizedMethodInvariant`: Only authorized methods execute
- `safetyInvariant`: No direct access ever succeeds in log

Temporal properties:
- `requestEventuallyCompletes`: All requests complete
- `blockedRequestsLogged`: All blocks are logged
- `directAccessNeverSucceeds`: Safety holds forever

### 11.3 Graph Verification

The `AccessControl.fs` module includes graph-based verification:

```fsharp
/// Verify no forbidden path exists in access control graph
let verifyNoForbiddenPath (graph: ACEdge list) (agent: AgentId) : bool =
    // Build adjacency list
    // Check: no path Agent → DirectMethod → File with IsAllowed = true
    // Return: true if no forbidden paths exist
```

---

## 12. Appendices

### 12.1 Glossary

| Term | Definition |
|------|------------|
| **Chaya** | Digital Twin for standalone/offline operation |
| **Holon** | Self-contained unit with SQLite/DuckDB state |
| **OODA** | Observe-Orient-Decide-Act decision cycle |
| **Prajna** | C3I Command Cockpit GUI |
| **STAMP** | Safety constraint framework |
| **Zenoh** | Pub/sub mesh networking |

### 12.2 Related Documents

| Document | Location |
|----------|----------|
| CLAUDE.md | `/CLAUDE.md` |
| Access Control Rules | `.claude/rules/todolist-access-control.md` |
| Agda Proofs | `docs/formal_specs/agda/TodolistAccessControl.agda` |
| Quint Models | `docs/formal_specs/quint/todolist_access_control.qnt` |
| BDD Features | `test/features/planning/` |

### 12.3 Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 21.3.0 | 2026-01-16 | Claude Opus 4.5 | Initial comprehensive spec |

---

**End of Document**

*Generated by Indrajaal Planning System v21.3.0-SIL6*
