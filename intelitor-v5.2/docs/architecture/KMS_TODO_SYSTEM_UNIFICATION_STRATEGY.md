# Architectural Analysis: Unifying the Omni-Task Management System (KMS + Phase 4)

**Date**: 2026-01-07 13:00 CEST
**Status**: DRAFT | **Context**: SIL-6 Biomorphic Fractal Mesh
**Objective**: Fully integrate the KMS (Knowledge Management System) Todo Service into the Phase 4 Biomorphic Architecture.

## 1. Executive Summary
The current `todolist_manager.exs` script is a tactical tool. The `Indrajaal.KMS.Todo` system (Ecto/SQLite + F# Cortex) is a strategic capability. To achieve **SIL-6 Biomorphic State**, we must transition from the script-based manager to the full KMS architecture, treating Tasks as first-class **Holons** with biological properties (Lifecycle, Dependency, Entropy).

## 2. The KMS Todo Holon (Capabilities Mapping)

The KMS Todo system is not just a list; it is a **Graph**. We will map its capabilities to the 7-Level Fractal Model.

| Capability | Current Script | KMS Holon (Target) | Phase 4 Integration |
| :--- | :--- | :--- | :--- |
| **Storage** | Markdown File | SQLite (WAL) + Zenoh | **Immutable Memory**: Tasks persist across restarts and are queryable via SQL. |
| **Identity** | Regex String | Human-Readable ID + UUID | **Holon Identity**: Each task gets a `HolonID` for entropy tracking. |
| **Relationships** | Indentation | Directed Acyclic Graph (DAG) | **Dependency Physics**: F# Cortex prevents "Closing" a task if its blockers are active (Physics-level interlock). |
| **State** | Text Edit | Finite State Machine (FSM) | **Lifecycle Rigor**: State transitions (`pending` -> `active`) emit Zenoh telemetry events. |
| **Search** | Grep | Full-Text Search (FTS5) + Vector | **Semantic Retrieval**: "Show me all safety-critical tasks related to Zenoh." |
| **Visibility** | File Read | LiveView Cockpit + TUI | **Biomorphic Dashboard**: Real-time visualization of the "Work Metabolism." |

## 3. SIL-6 Alignment Strategy

To meet SIL-6 standards, the Todo System must be **Safety-Critical Software**.

*   **SC-TODO-SIL6-001 (Audit)**: Every state change must be cryptographically signed and logged to the **Immutable Register**.
*   **SC-TODO-SIL6-002 (Interlock)**: High-criticality tasks (P0) act as **System Interlocks**. You cannot deploy code if a P0 task is open.
*   **SC-TODO-SIL6-003 (2oo3 Voting)**: Task completion requires consensus:
    1.  **Human**: Marks as done.
    2.  **Test**: Verification passes.
    3.  **Cortex**: Entropy score is within limits.

## 4. Biomorphic Integration (Phase 4)

We will treat the Todo List as the **Genome of the Sprint**.

*   **Metabolic Rate**: The system measures the rate of task completion ($v_{work}$) vs. the rate of bug creation ($v_{entropy}$).
*   **Auto-Generation**: When the Cortex detects code rot (Phase 4), it *autonomously* injects a Refactoring Task into the KMS.
*   **Apoptosis**: Stale tasks (> 30 days inactive) are automatically marked for review or archived, mimicking cellular death.

## 5. Implementation Plan (Migration)

### Step 1: The Bridge (Hybrid Mode)
*   Modify `todolist_manager.exs` to read/write to the **KMS SQLite Database** instead of just parsing Markdown.
*   Keep `PROJECT_TODOLIST.md` as a **Read-Only View** generated from the DB (Projection).

### Step 2: The Cortex Hook
*   Update `indrajaal-cortex` (F#) to subscribe to `indrajaal/kms/todos` Zenoh topics.
*   Implement the **Dependency Logic** in F# (e.g., Cycle detection in task graph).

### Step 3: Full Switchover
*   Deprecate direct file editing.
*   All interactions occur via `sa-todo` (CLI) or the LiveView Cockpit.

## 6. Benefits
1.  **Truth**: Single source of truth (SQLite), multiple views (Markdown, UI, CLI).
2.  **Safety**: Impossible to "forget" a blocker.
3.  **Intelligence**: AI Agents can query the graph ("What is blocking Phase 4?") instead of parsing text.

## 7. Next Actions
1.  **Verify**: Check the current state of `Indrajaal.KMS` schemas (Tasks, Dependencies).
2.  **Scaffold**: Generate the Migration Script (`markdown_to_sqlite.exs`).
3.  **Connect**: Wire the `todolist_manager.exs` to the `Indrajaal.Repo`.
