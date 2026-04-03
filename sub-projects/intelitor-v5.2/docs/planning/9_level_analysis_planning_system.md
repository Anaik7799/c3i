# 9-Level Fractal Analysis: Indrajaal Planning & Project Management System

**Status**: DRAFT | **Target**: F# Migration & Zenoh Integration | **Compliance**: SIL-6 Biomorphic

## Executive Summary
This analysis decomposes the requirements for the new F#-based Planning System across 9 levels of fractal detail. The goal is to migrate all todolist logic from Elixir to F#, integrate with the Smriti database, and enable mesh-wide awareness via Zenoh, while incorporating military planning principles (OODA, SOD).

---

## L1: The Atomic Level (Primitives & Types)
**Focus**: Data Structures, Immutability, and Type Safety.

*   **Requirement**: Define strict F# types for all planning entities.
*   **Implementation**: `Cepaf.Planning.Domain` module.
    *   `TaskId`: Hierarchical string (e.g., "42.1.0.0.0").
    *   `Status`: Discriminated Union (`Pending`, `InProgress`, `Completed`, `Blocked`).
    *   `Priority`: Discriminated Union (`P0`..`P4`).
    *   `Task`: Record type with immutable fields.
    *   `Event`: Domain events (`TaskCreated`, `StatusChanged`).
*   **Military Aspect**: Atomic units of action (Soldier/Fireteam).
*   **Database**: Map to SQLite tables (`Tasks`, `Events`).

## L2: The Component Level (Logic & Parsing)
**Focus**: Input/Output, Transformation, and Validation.

*   **Requirement**: Robust parsing of `PROJECT_TODOLIST.md` and command inputs.
*   **Implementation**: `Cepaf.Planning.Parsers`.
    *   **Markdown Parser**: Bi-directional conversion between Markdown and Domain Types.
    *   **Command Parser**: CLI argument parsing.
    *   **Validation**: Business rule enforcement (e.g., "Cannot complete parent if child is pending").
*   **Military Aspect**: Standard Operating Procedures (SOPs) and Drills.

## L3: The Holon Level (State & Persistence)
**Focus**: Local State Management, ACID Transactions, and Boundaries.

*   **Requirement**: Reliable local storage independent of the mesh.
*   **Implementation**: `Cepaf.Planning.Repository`.
    *   **Smriti DB**: SQLite database (`smriti_planning.db`) for task storage.
    *   **WAL Mode**: Write-Ahead Logging for concurrency.
    *   **Repository Pattern**: `GetTask(id)`, `SaveTask(task)`, `GetWorkingSet()`.
*   **Military Aspect**: Unit cohesiveness and self-sufficiency.

## L4: The Container Level (Runtime & Execution)
**Focus**: Processes, Supervision, and Resource Isolation.

*   **Requirement**: Running the planning logic as a managed service or CLI tool.
*   **Implementation**: `Cepaf.Planning.CLI` and `Cepaf.Planning.Service`.
    *   **CLI Tool**: `sa-plan` for user interaction.
    *   **Service**: Background daemon for Zenoh synchronization (optional/future).
    *   **Environment**: Running within the `infra-f#-cepa` track.
*   **Military Aspect**: Logistics and base of operations.

## L5: The Node Level (Integration & API)
**Focus**: System-wide availability on a single machine.

*   **Requirement**: Exposing planning capabilities to other local components.
*   **Implementation**: `Cepaf.Planning.Api`.
    *   **Local API**: F# Interface for other modules (Cockpit, Cortex).
    *   **Backup**: Maintaining `PROJECT_TODOLIST.md` as a read-only mirror/backup.
*   **Military Aspect**: Base/Camp coordination.

## L6: The Mesh Level (Zenoh & Synchronization)
**Focus**: Distributed Awareness and Event Propagation.

*   **Requirement**: Broadcasting task updates to the entire mesh.
*   **Implementation**: `Cepaf.Planning.Zenoh`.
    *   **Publisher**: Publish `indrajaal/planning/events` (e.g., `TaskCompleted`).
    *   **Subscriber**: Listen for remote updates (if multi-node).
    *   **OODA Loop**: Observe (Zenoh) -> Orient (Parse) -> Decide (Update DB) -> Act (Ack).
*   **Military Aspect**: Blue Force Tracking and Common Operational Picture (COP).

## L7: The Federation Level (Strategy & Governance)
**Focus**: Long-term Goals, Policy, and Cross-Domain Logic.

*   **Requirement**: Strategic alignment and specialized planning views.
*   **Implementation**: `Cepaf.Planning.Strategy`.
    *   **Rollup Logic**: Aggregating status from L1->L6 tasks to L7 milestones.
    *   **Views**: Kanban (Trello-like), List (Asana-like), Timeline (Gantt).
    *   **Military Aspect**: Campaign Planning and SOD (Systemic Operational Design).

## L8: The Ecosystem Level (User Experience & Tools)
**Focus**: Human-Machine Interface and External Integrations.

*   **Requirement**: Seamless interaction for developers and agents.
*   **Implementation**: `Cepaf.Cockpit` Integration.
    *   **TUI**: Interactive task board in the terminal.
    *   **AI Integration**: Agents (Gemini/Claude) can query/update tasks via tools.
    *   **Features**: Drag-and-drop (simulated), filtering, rich text.
*   **Military Aspect**: User Interface (ATAK/Tzayad).

## L9: The Universe Level (Evolution & Archival)
**Focus**: Deep Time, History, and Entropy.

*   **Requirement**: Preserving the history of the project ("The Ark").
*   **Implementation**: `Cepaf.Planning.Archival`.
    *   **History Table**: Tracking all changes (Audit Log).
    *   **Ark Export**: Periodically archiving completed sprints to `indrajaal.ark`.
    *   **Entropy**: Measuring task stagnation.
*   **Military Aspect**: Doctrine, History, and Long-term Strategy.

---

## Action Plan
1.  **Scaffold F# Project**: `Cepaf.Planning`.
2.  **Define Domain**: `Domain.fs`.
3.  **Implement Persistence**: `Repository.fs` (SQLite).
4.  **Implement Logic**: `Manager.fs`.
5.  **Implement CLI**: `Program.fs` (CLI commands).
6.  **Implement Zenoh**: `ZenohAdapter.fs`.
7.  **Verify**: Unit tests and Integration tests.
8.  **Migrate**: Import existing `PROJECT_TODOLIST.md`.
