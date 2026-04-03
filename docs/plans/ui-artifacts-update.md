# UI Artifacts Update and Planning System Overview

## 1. Summary of UI-Related System Artifacts

Based on the analysis of the `c3i` and `intelitor-v5.2` codebase, here is the summary of the key UI-related artifacts and what they do:

### Rules (`.claude/rules/`)
*   **`gleam-web-ui-development.md`**: Defines the "Fractal Agentic UI" approach (AG-UI protocol). It enforces a Triple-Interface Mandate (Lustre Web SSR, Wisp REST API, TUI ANSI) for every UI capability. It strictly prohibits direct side effects in UI updates, dictates the 8-Panel Dashboard pattern, and defines human-in-the-loop (HITL) and mathematical coverage standards (ITQS, Shannon Entropy).
*   **`ui-graph-testing.md`**: Outlines a mathematical, graph-theory-based testing framework. It models UI navigation as a directed graph (G_nav) and page states as Labeled Transition Systems (LTS). It requires prime path coverage (C_path >= 0.95), PubSub channel hypergraph mapping, and adjacency matrices to ensure exhaustive UI testing and reachability (SCC).

### Skills (`.gemini/skills/`)
*   **`lustre-gleam-ui-expert/SKILL.md`**: An expert guide for the LLM to write production-quality, type-safe SPAs using the Elm Architecture (MVU) via the Lustre framework. It strictly enforces the "Laws of the Lustre Loop" (Type-First Modeling, Flat State with normalized collections, Effect Isolation, Exhaustive Pattern Matching, and Opaque Domain Boundaries).

### Documentation & Design (`docs/`)
*   **`PLANNING_WEBUI_COMPREHENSIVE.md`**: Detailed UX/UI design system focusing on the "Dark Cockpit" pattern (where panels auto-hide when healthy and illuminate based on anomaly severity). It includes user personas, an 8-panel CSS grid layout, spatial interaction patterns, operational incident response procedures, and a Generative UI widget catalog for AI agent rendering.
*   **`PLANNING_WEBUI_DESIGN.md`**: Specifies the visual and structural design intent for the 8-panel Planning Dashboard interface.

---

## 2. Collation for c3i Gleam System Integration

To unify these artifacts into actionable contexts for Gleam-based `c3i` code generation, they should be logically grouped into the following directives:

### **Rules Integration (For Static Analysis & Test Generation)**
*   **Enforce AG-UI Protocol:** All Lustre updates must yield `#(Model, Effect(Msg))`.
*   **Graph Coverage:** Generate Labeled Transition Systems (LTS) for every Lustre view. Tests must invoke `gleeunit` to achieve prime path coverage across states defined in the model.
*   **Triple-Interface Sync:** Code generation must simultaneously target `ui/lustre/`, `ui/wisp/`, and `ui/tui/`.

### **Skills Integration (For Coding Agents)**
*   Use `lustre`, `lustre_ui`, `sketch` (or `lustre_dev_tools` validated Tailwind), and `modem`.
*   Always structure state using `Dict(Id, Entity)` rather than `List(Entity)`.
*   External bounds (HTTP/JS) must strictly return `Result(Data, AppError)`.

### **Agents & Prompts (For UI Generative Tasks)**
*   Agents must reference the **Generative UI Widget Catalog** (e.g., `TaskCard`, `OodaRing`, `SafetyShield`) from the comprehensive design docs when emitting A2UI declarative JSON components.

### **CLAUDE.md & GEMINI.md Updates**
*   **CLAUDE.md**: Append the `SC-UIGT` (UI Graph Testing) and `SC-GLM-UI` mandates, ensuring Claude verifies prime paths on PRs.
*   **GEMINI.md**: Add the "Laws of the Lustre Loop" and "Dark Cockpit Pattern" (SC-HMI-010) as core context constraints (L4 Safety) to ensure zero-defect UI generation.

---

## 3. Web UI Development Prompt for Gleam

**Prompt Text to use when developing or testing Web UI on the c3i Gleam codebase:**

> **System Prompt: Gleam/Lustre Expert (C3I AG-UI Protocol)**
>
> You are an expert Gleam developer tasked with building and testing a production-quality, type-safe UI following the C3I "Fractal Agentic UI" (AG-UI) protocol and the Elm Architecture (MVU).
>
> **Core Directives:**
> 1. **Triple-Interface Mandate:** Ensure logic supports Lustre (SSR), Wisp (JSON API), and TUI. Use shared types from `ui/domain.gleam`.
> 2. **Lustre Loop Laws:**
>    - Define `Model` and `Msg` FIRST.
>    - Use `Dict(Id, T)` for collections, never nested lists.
>    - The `update` function must be PURE. Handle all side effects exclusively via `lustre/effect`.
>    - Exhaustive pattern matching on all `Msg` variants (no `_` catch-alls).
> 3. **Data Boundaries:** Wrap all external data calls in `Result(Data, AppError)`. Handle `NotAsked`, `Loading`, `Loaded`, and `Failed` states in the view.
> 4. **Styling & UX:** Use the "Dark Cockpit" pattern. Default to minimal/gray rendering unless anomalies are present. Use `sketch` for type-safe CSS or validated Tailwind. No raw inline style strings.
> 5. **Testing (SC-UIGT):** When writing tests, apply Graph-Theory principles. Model the view as a Labeled Transition System (LTS). Ensure node coverage (all tabs/modals), edge coverage (all `Msg` transitions), and prime path coverage.
>
> Provide the requested Gleam code ensuring zero compiler warnings, total type safety, and strict alignment with the 8-category coverage gold standard.

---

## 4. Planning and Task Allocation Answers

### How is planning and task allocation in c3i done?
Planning and task allocation are handled via an integrated **Service Orchestration and OODA loop** implemented in Gleam (`lib/cepaf_gleam/src/cepaf_gleam/planning/orchestration.gleam` and `manager.gleam`).
*   **Task Creation:** Tasks are created and coordinated across the `Planning`, `CEPAF`, and `Guardian` services. Guardian provides safety kernel approval.
*   **Allocation/Distribution:** The `distribute_tasks` function allocates tasks to nodes using one of four strategies: `RoundRobin`, `LeastLoaded`, `PriorityBased`, or `AffinityBased` (hashing task names to consistent nodes).
*   **Execution (OODA):** It operates on a continuous Observe-Orient-Decide-Act cycle, coordinating AI systems like `Cortex` (threat landscape/situational data) and `Prajna` with the Planning core.

### Where is this information stored? Which database?
The authoritative source of truth for the Holon state (including tasks and planning data) is **DuckDB** (with SQLite serving as a degraded-mode fallback).
*   According to `SC-HOLON-009` and the code in `lib/cepaf_gleam/src/cepaf_gleam/planning/repository.gleam`, tasks are persisted in a `tasks` table using the DuckDB FFI bindings.
*   It tracks `id`, `title`, `status`, `priority`, `parent_id`, `owner_id`, and `version` to ensure state is immutable and version-controlled.

### Does Gleam code or Rust code in the `src` folder support planning and task allocation functionality?
**Yes.** The primary planning and task allocation engine is written entirely in **Gleam**, located under `lib/cepaf_gleam/src/cepaf_gleam/planning/`.
*   **Gleam** handles the orchestration (`orchestration.gleam`), database interactions (`repository.gleam`), domain logic (`domain.gleam`), and Zenoh event publishing (`zenoh_adapter.gleam`).
*   **Rust** code in the `lib/rust/` directory provides essential background utility layers for this system (e.g., coverage math audit, graph analysis, and Swarm generation) which are exposed to Gleam via NIFs (Native Implemented Functions), but the core architectural routing and task logic live natively in the Gleam layer.