# Unified Phase 4 Implementation Plan: Cortex & KMS Todo (7-Level)

**Date**: 2026-01-07 14:15 CEST
**Status**: APPROVED | **Context**: SIL-6 Biomorphic Fractal Mesh
**Target**: Unified Bicameral Architecture (Cortex + Todo Graph)

## Executive Summary
This plan unifies the execution of **Phase 4 (Directed Telescope)** and the **KMS Todo System**. It treats them as a single architectural shift: establishing the "Brain" (Cortex) and the "Will" (Todo) of the system.

---

## 7-Level Implementation Hierarchy

### Level 1: Strategic (The Goal)
**31.1.4.0.0.0.0 - Establish Biomorphic Cognition (Phase 4 Unified)**
*   **Criticality**: **P0 (CRITICAL)**
*   **Objective**: Deploy the Cortex Service and migrate Task Management to the KMS Graph.
*   **Success Criteria**: `indrajaal-cortex` running, `sa-todo` CLI active, `PROJECT_TODOLIST.md` generated from DB.

### Level 2: Architectural (The Topology)
**31.1.4.1.0.0.0 - Materialize the Cortex Infrastructure**
*   **Criticality**: **P0**
*   **Objective**: Deploy the F#/.NET 10 Worker Service (`indrajaal-cortex`).

**31.1.4.2.0.0.0 - Establish the Somatic Bridge (Zenoh)**
*   **Criticality**: **P0**
*   **Objective**: Connect Elixir (Body) to F# (Brain) via Zenoh.

**31.1.4.3.0.0.0 - Migrate Task Memory (KMS Data)**
*   **Criticality**: **P0**
*   **Objective**: Move from Markdown to SQLite Graph.

### Level 3: Holonic (The Components)
**31.1.4.1.1.0.0 - Implement Cortex Service**
*   **Criticality**: **P0**
*   **Activity**: Scaffold, Containerize, and Orchestrate the .NET Service.

**31.1.4.3.1.0.0 - Implement KMS Ecto Schemas**
*   **Criticality**: **P0**
*   **Activity**: Create `Indrajaal.KMS.Todo` schemas (`Task`, `Dependency`).

**31.1.4.3.2.0.0 - Implement Projection Engine**
*   **Criticality**: **P1 (HIGH)**
*   **Activity**: Generate Markdown from DB (`Indrajaal.KMS.Todo.Projection`).

### Level 4: Operational (The Workflow)
**31.1.4.1.1.1.0 - Cortex Scaffolding**
*   **Criticality**: P0
*   **Action**: `dotnet new worker`, Dockerfile setup.

**31.1.4.3.1.1.0 - Data Migration**
*   **Criticality**: P0
*   **Action**: Write script to parse current `PROJECT_TODOLIST.md` into SQLite.

**31.1.4.4.1.0.0 - CLI Tooling**
*   **Criticality**: P1
*   **Action**: Create `sa-todo` CLI wrapper for KMS operations.

### Level 5: Implementation (The Tasks)
**31.1.4.1.1.1.1 - Initialize .NET Project**
*   **Criticality**: P0
*   **Detail**: `dotnet new worker -n Indrajaal.Cortex`

**31.1.4.1.1.1.2 - Configure Zenoh.Net**
*   **Criticality**: P0
*   **Detail**: Add NuGet package, configure session.

**31.1.4.3.1.1.1 - Create Ecto Migration**
*   **Criticality**: P0
*   **Detail**: `mix ecto.gen.migration create_kms_todo_tables`

**31.1.4.3.1.1.2 - Implement Import Logic**
*   **Criticality**: P0
*   **Detail**: Logic to regex-parse Markdown and insert into DB.

### Level 6: Atomic (The Steps)
**31.1.4.1.1.1.1.1 - Execute Scaffolding Command**
*   **Criticality**: P0
*   **Command**: `dotnet new worker ...`

**31.1.4.3.1.1.1.1 - Define Task Schema**
*   **Criticality**: P0
*   **Code**: `schema "kms_todos" do ...`

### Level 7: Sub-Atomic (The Code)
**31.1.4.3.1.1.1.1.1 - Field Definition**
*   **Criticality**: P0
*   **Code**: `field :holon_id, :binary_id`

---

## Criticality Analysis Summary

| Component | Criticality | Justification |
| :--- | :--- | :--- |
| **Cortex Container** | **P0** | The physical host for the new logic. |
| **KMS Database** | **P0** | The memory store for the new Task Graph. |
| **Zenoh Bridge** | **P0** | The nervous system connecting Body and Brain. |
| **Markdown Projection** | **P1** | Essential for developer UX/Backward Compatibility. |
| **Graph Logic (Cycle)** | **P1** | Essential for correctness, but system runs without it initially. |

## Execution Sequence

1.  **SCAFFOLD**: Create `indrajaal-cortex` service.
2.  **SCHEMA**: Define `kms_todos` in Elixir.
3.  **MIGRATE**: Ingest `PROJECT_TODOLIST.md` to DB.
4.  **CONNECT**: Wire up Zenoh.
5.  **PROJECT**: Auto-generate Markdown from DB.
