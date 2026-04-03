# DOCUMENT: The Omni-Task Biomorphic System (v21.3.0)

**Classification**: L5-SPINE (Supreme Design Blueprint)
**Compliance**: SIL-6 Biomorphic / Axiom 0 / Biomorphic
**Substrate**: Pure Ecto + SQLite (No Ash)
**Languages**: Elixir (Logic) + F# (Cortex)

---

## LEVEL 1: ANALYSIS & VISION

### 1.1 The Problem
The previous task management system was constrained by framework abstractions (Ash) and lacked the "best-in-class" features of modern tools. We require a system that merges the **Rigidity of Jira**, the **Fluidity of Notion**, and the **Visuals of Linear**, running on a **Portable SQLite Substrate** that can be accessed by both Elixir and F#.

### 1.2 The Vision: "Omni-Task Holon"
We are building a **Self-Contained Task Organism**.
- **Fractal**: Tasks can contain infinite sub-tasks (10-Level proven).
- **Polyglot**: Accessed via Elixir Ecto and F# Dapper/Sqlite.
- **Portable**: The entire brain (`todos.db`) can be moved/backed up instantly.
- **Ecto-Native**: Unleashing the full power of Ecto Changesets, Multi, and Query without middleware.

### 1.3 Feature Matrix (The "Best Of")
| Feature | Inspiration | Implementation |
| :--- | :--- | :--- |
| **Readable IDs** | Linear | `IND-123` (Auto-increment + Prefix) |
| **Graph Dependency** | Asana | Recursive CTEs for blocking chains |
| **Rich Content** | Notion | Markdown blob in DB |
| **Flexible Fields** | ClickUp | JSON-serialized text column |
| **Strict States** | Jira | Ecto FSM logic |

---

## LEVEL 2: SPECIFICATIONS (SIL-6 Biomorphic)

### 2.1 Data Integrity (SC-DATA-001)
- **Atomic Writes**: All multi-step operations (e.g., creating task + dependency) MUST use `Ecto.Multi`.
- **Foreign Keys**: Enforced at the SQLite level (`PRAGMA foreign_keys = ON`).
- **Immutable Audit**: Every change MUST append a record to the `audit_log` table.

### 2.2 Schema Constraints
- **Title**: Not Null, Min 3 chars.
- **Status**: Enum atom (`:backlog`, `:in_progress`, `:done`).
- **Layer**: Enum atom (`:l1`..`:l10`).
- **Timestamps**: UTC Microsecond precision.

### 2.3 Biomorphic Constraints
- **Axiom 0**: System MUST remain bootable even if `todos.db` is corrupted (Auto-heal/Reset).
- **Memory**: Task graph traversal MUST NOT exceed 50MB RAM.

---

## LEVEL 3: ARCHITECTURE & DESIGN

### 3.1 The "Twin-Brain" Architecture
The system logic is split but shares a single memory (`todos.db`).

```
[ Elixir Logic Plane ]        [ F# Cortex Plane ]
       │                             │
   (Ecto Repo)                  (Dapper/SQLProvider)
       │                             │
       └──────────► [ SQLite DB ] ◄──┘
                    (todos.db)
```

### 3.2 The Guardrail: Ash vs. Ecto
To prevent contamination:
1.  **Namespace Isolation**: All pure Ecto code lives in `Indrajaal.KMS.Context.*`.
2.  **No "Use Ash"**: The string `use Ash.Resource` is FORBIDDEN in this namespace.
3.  **Direct SQL**: Complex graph queries use raw SQL or Ecto fragments, bypassing Ash capabilities.

### 3.3 Database Schema (SQLite Optimized)
- **Table `todos`**: Main entity.
    - `custom_fields`: TEXT (JSON encoded). Ecto handles serialization transparently.
- **Table `dependencies`**: Join table.
- **Table `audit_log`**: Append-only event stream.

---

## LEVEL 4: IMPLEMENTATION DETAIL

### 4.1 Ecto JSON Support in SQLite
Since SQLite lacks native JSON types, we implement a custom Ecto Type.

```elixir
defmodule Indrajaal.Ecto.JSONText do
  use Ecto.Type
  def type, do: :string
  def cast(map) when is_map(map), do: {:ok, map}
  def load(data), do: Jason.decode(data)
  def dump(map), do: Jason.encode(map)
end
```

### 4.2 Recursive CTE for Dependencies
We use Ecto's `recursive_ctes` to find blocking chains.

```elixir
dependency_tree = 
  from t in Todo,
  join: d in "todo_dependencies", on: t.id == d.blocked_id,
  join: parent in "tree", on: d.blocking_id == parent.id,
  select: t
```

### 4.3 F# Type Provider Access
F# uses the `SQLProvider` for compile-time verified queries against `todos.db`.

```fsharp
type db = SqlDataProvider<Common.DatabaseProviderTypes.SQLITE, "./data/holons/todos.db">
let activeTasks = db.GetDataContext().Main.Todos |> Seq.filter (fun t -> t.Status = "in_progress")
```

---

## LEVEL 5: UI/UX/CX/DX (RICH INTERFACE)

### 5.1 Phoenix LiveView "Cockpit" (The Pilot's Seat)
The primary interface is a highly responsive, single-page application.
- **Kanban Board**: Drag-and-drop state transitions (`SortableJS` + LiveView Hooks).
- **Gantt Chart**: SVG-based timeline visualization using `start_at` and `due_at`.
- **Fractal Zoom**: Click a task to "Dive" into its sub-tasks (Breadcrumb navigation).
- **Real-Time**: Presence indicators show other agents/users viewing the same task.

### 5.2 Fractal TUI (The Engineer's Terminal)
A keyboard-centric interface for rapid manipulation.
- **Mode**: `sa-todo` command launches the ncurses-like dashboard.
- **Keys**: `j/k` navigation, `Enter` to edit, `Space` to toggle status.
- **Graph View**: ASCII-art dependency tree visualization.

### 5.3 Cognitive Experience (CX)
- **Natural Language**: "Create a P0 task to fix the bug" -> Parses to Ecto insert.
- **Contextual Suggestions**: "You have 3 blocking tasks, should I prioritize them?"

### 5.4 Developer Experience (DX)
- **REPL Access**: `Todos.create_task(...)` is a first-class citizen.
- **Migrations**: Standard `mix ecto.migrate` workflow.

---

## LEVEL 6: TESTING & VERIFICATION

### 6.1 SIL-6 Biomorphic Test Suite
- **Property Testing**: Use `PropCheck` to generate random task graphs and verify no cycles are created.
- **Traceability**: Every test case maps to a specific Spec ID (e.g., `test_sc_data_001`).

### 6.2 Biomorphic Chaos
- **Constraint**: `Mara` agent randomly locks SQLite table to test retry logic.
- **Recovery**: System MUST backoff and retry transactions (SQLITE_BUSY).

### 6.3 Test Case Example
```elixir
property "circular dependencies are rejected" do
  forall graph <- dependency_graph() do
    if has_cycle?(graph) do
      assert {:error, :cycle_detected} == Todos.import_graph(graph)
    end
  end
end
```

---

## LEVEL 7: USER GUIDE

### 7.1 Quick Start
Since this is a Pure Ecto setup, use the standard Mix Ecto tasks targeting the KMS Repo.

```bash
# 1. Generate the SQLite Database
mix ecto.create -r Indrajaal.KMSRepo

# 2. Run the Migrations (Materialize Tables)
mix ecto.migrate -r Indrajaal.KMSRepo

# 3. Verify Schema
mix run -e "IO.inspect Indrajaal.KMSRepo.all(Indrajaal.KMS.Schema.Todo)"
```

### 7.2 F# Integration
The F# Type Provider requires the database to exist *at compile time*.
1. Ensure `data/kms/todos.db` exists (run steps above).
2. Build the F# project: `dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj`.

### 7.3 CLI Commands (Gemini/Claude)
The AI agent uses the `mcp` toolset which maps to the Ecto Context.
- `mcp call todo_create --title "Fix Bug"`
- `mcp call todo_link --blocker "ID-1" --blocked "ID-2"`