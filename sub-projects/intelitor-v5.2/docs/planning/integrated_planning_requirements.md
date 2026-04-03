# Integrated Planning & Project Management Requirements

**Target System**: Indrajaal / Cepaf.Planning
**Status**: Requirements Definition
**Architecture**: Fractal, Holonic, Biomorphic

## 1. Overview
This document defines the requirements for the unified Planning System, integrating best-in-class features from industry tools (Asana, Jira, etc.) with military-grade operational models (OODA, SOD). The system will be implemented in F# and backed by Smriti (SQLite) and Zenoh.

## 2. Core Feature Requirements (The "Best of Breed" Synthesis)

### 2.1 From Asana (Team Balance & Handoffs)
*   **Workload Management**: Visual indication of agent/user load.
*   **Dependencies**: Explicit blocking relationships (Task B requires Task A).
*   **Milestones**: Major checkpoints aggregating smaller tasks.

### 2.2 From Monday.com (Visual Management)
*   **Custom Status Columns**: Ability to define domain-specific statuses.
*   **Dashboards**: High-level view of progress (Percent complete, Burndown).

### 2.3 From Trello (Simplicity & Kanban)
*   **Board View**: Ability to view tasks as cards in columns (Pending, In Progress, Done).
*   **Drag-and-Drop**: Easy status transition (Simulated in TUI/CLI).

### 2.4 From Todoist (Personal Productivity)
*   **Natural Language Input**: "Add task to check logs every Friday" (AI parsing).
*   **Priority Levels**: P1, P2, P3, P4 (Mapped to P0-P4 in our system).

### 2.5 From Jira (Agile & Dev)
*   **Sprints**: Grouping tasks into time-boxed iterations.
*   **Epics**: Large bodies of work (Holons).
*   **Issue Linking**: Relates-to, Duplicates, Blocks.

### 2.6 From Smartsheet (Grid View)
*   **Table/Grid View**: Dense information display for bulk editing.
*   **Hierarchical Indentation**: Parent-child relationships visible in grid.

## 3. Military Planning Integration (The "War Room" Features)

### 3.1 OODA Loop Support
*   **Observe**: Real-time feeds of system state alongside tasks.
*   **Orient**: Contextual analysis (why is this task blocked?).
*   **Decide**: AI-assisted prioritization and assignment.
*   **Act**: One-click execution of task-related scripts/commands.

### 3.2 Systemic Operational Design (SOD)
*   **Holistic Framing**: Tasks are not isolated; they belong to a "Campaign" (System goal).
*   **Logic mapping**: Visualizing the "Theory of Victory" for a sprint.

### 3.3 Fractal Execution (7 Levels)
*   **L1 (Soldier)**: "Rosh Gadol" - Task allows improvisation details.
*   **L2 (Tactical)**: Squad-level coordination (Agent groups).
*   **L3 (Unit)**: Specialized capabilities (Domain focus).
*   **L4 (Operational)**: Campaign management.
*   **L5 (Strategic)**: Long-term goals.
*   **L6 (Societal)**: Ecosystem impact.
*   **L7 (Geopolitical)**: Federation-wide alignment.

## 4. Technical Requirements (F# & Smriti)

### 4.1 Persistence (Smriti DB)
*   **Engine**: SQLite (Microsoft.Data.Sqlite).
*   **Schema**:
    *   `Tasks` (Id, Title, Status, Priority, ParentId, ...)
    *   `Dependencies` (FromId, ToId, Type)
    *   `Events` (Id, TaskId, Type, Payload, Timestamp)
*   **Mode**: WAL (Write-Ahead Log) for concurrency.

### 4.2 Distributed Sync (Zenoh)
*   **Pub/Sub**: `indrajaal/planning/updates`.
*   **State Sync**: CRDT-like merging or Event Sourcing.

### 4.3 CLI Interface (`sa-plan`)
*   `status`: Show board/list.
*   `add`: Create task (supporting hierarchy).
*   `move`: Change status/parent.
*   `view`: Detailed task view (military context).

### 4.4 Backup & Legacy
*   **Mirror**: Automatically update `PROJECT_TODOLIST.md` on every change.
*   **Import**: Capability to re-ingest `PROJECT_TODOLIST.md` if DB is lost.

## 5. Migration Strategy
*   **Phase 1**: Build F# Core (Domain, Repo).
*   **Phase 2**: Build CLI (`sa-plan`) and Import logic.
*   **Phase 3**: Parallel Run (Elixir reads MD, F# reads DB, F# writes both).
*   **Phase 4**: Cutover (F# is source of truth, MD is read-only output).
*   **Phase 5**: Decommission Elixir script.
