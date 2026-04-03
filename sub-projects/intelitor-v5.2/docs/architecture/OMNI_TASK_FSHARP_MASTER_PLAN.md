# DOCUMENT: F# CEPAF Omni-Task Integration Plan (v21.3.0)

**Classification**: L5-SPINE (Cortex Design)
**Compliance**: SIL-6 Biomorphic / Axiom 0
**Scope**: F# (CEPAF) Integration with SQLite Task Database
**Status**: ACTIVE

---

## LEVEL 1: ANALYSIS & VISION

### 1.1 The Need for Cortex Access
The Elixir Logic Plane handles the "Business Physics" (CRUD, Validation). The F# Cortex Plane (CEPAF) handles "Cybernetic Reasoning" (Optimization, OODA, autonomous scheduling). To function, CEPAF needs direct, type-safe access to the Task Holon (`todos.db`).

### 1.2 "F# Only" Capability
This module must function independently of the BEAM. If Elixir crashes, F# must still be able to read the state, analyze the failure, and repair the data or restart the mesh.

---

## LEVEL 2: SPECIFICATIONS

### 2.1 Type Provider Contract
- **Provider**: `FSharp.Data.SqlProvider` (Compile-time verified SQL).
- **Connection**: `DataSource="data/kms/todos.db", Mode=ReadWrite`.
- **Mapping**: Map `custom_fields` (Text) to `JsonNode` or F# Records dynamically.

### 2.2 Functional Requirements
- **Read**: `getActiveTasks()`, `getTaskGraph(rootId)`.
- **Write**: `createSystemTask(title, priority)`, `blockTask(id, reason)`.
- **Analyze**: `detectCycles()`, `calculateCriticalPath()`.

---

## LEVEL 3: ARCHITECTURE

### 3.1 The "Bicameral Mind"
```
[ F# Cortex ] <---> [ SQLite Driver ] <---> [ todos.db ]
```
The F# layer bypasses the Elixir Context for performance and independence during OODA cycles.

### 3.2 Domain Model (`Cepaf.Kms`)
- **Type**: `TaskHolon` (F# Record).
- **Graph**: `TaskNode` with `Children: TaskNode list`.

---

## LEVEL 4: IMPLEMENTATION DETAIL

### 4.1 SQL Provider Setup
```fsharp
type sql = SqlDataProvider<Common.DatabaseProviderTypes.SQLITE, "./data/kms/todos.db">
let ctx = sql.GetDataContext()
```

### 4.2 Graph Analysis (Recursive)
F# is superior for graph algorithms. We will implement `Tarjan's Algorithm` for cycle detection and `Critical Path Method (CPM)` for scheduling.

### 4.3 JSON Interop
Use `System.Text.Json` to parse the `custom_fields` column stored as text.

---

## LEVEL 5: UI/UX/CX/DX

### 5.1 The TUI (Terminal User Interface)
The `fractal-tui.fsx` will be updated to show a **Gantt Chart** derived from the SQLite data.

### 5.2 Cognitive Experience (CX)
The AI Copilot will use F# tools to "reason" about the schedule: *"I see Task A is blocking Task B, but Task A is idle. Should I escalate?"*

---

## LEVEL 6: TESTING & VERIFICATION

### 6.1 Property Testing (FsCheck)
- **Invariant**: The graph structure read by F# matches the structure written by Elixir.
- **Verification**: Write random tree in Elixir -> Read in F# -> Assert Isomorphism.

---

## LEVEL 7: USER GUIDE

### 7.1 F# Script Usage
```bash
# Analyze the task graph
dotnet fsi lib/cepaf/scripts/analyze-tasks.fsx

# Create a system task
dotnet fsi lib/cepaf/scripts/create-task.fsx --title "System Optimize" --prio P0
```

### 7.2 Integration
Include `Cepaf.Kms.dll` in your project references.
