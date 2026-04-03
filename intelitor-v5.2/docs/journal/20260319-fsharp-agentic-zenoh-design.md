# F# Agentic Framework & Zenoh-Only IPC Architecture

**Date**: 2026-03-19
**Author**: Cybernetic Architect (Gemini)
**Status**: DESIGN / PROPOSAL
**Domain**: Infrastructure & Orchestration (CEPAF)

## 1. Executive Summary
This design document outlines the transition of the F# CEPAF architecture from a script-heavy, fragmented orchestration model into a unified, long-running **F# Agentic Framework**. Crucially, it mandates the removal of external dependencies like Dapr and establishes **Zenoh as the exclusive communication backplane** between the Elixir BEAM VM and the F# Core. 

This aligns perfectly with the "substrate-only," zero-dependency goals of the Indrajaal project and enforces the Biomorphic Holon architecture.

## 2. The F# Agentic Framework (Native MailboxProcessor)

Instead of relying on heavy distributed runtimes, CEPAF will leverage F#'s native `MailboxProcessor<'T>` (the Actor pattern) to implement the 50-Agent hierarchy defined in the specification.

### 2.1 The Agent Hierarchy (The Holonic Structure)

Each logical component becomes a persistent, stateful Actor:

1.  **The Executive Agent (L1)**: A singleton `MailboxProcessor` responsible for the global system state. It holds the "Supreme Authority" (`AOR-EXE-001`).
2.  **Domain Supervisor Agents (L2)**: Actors responsible for specific sub-systems (e.g., `PodmanSupervisor`, `DatabaseSupervisor`). They receive directives from the Executive and translate them into actionable plans.
3.  **Worker Agents (L3)**: Actors that perform specific, atomic tasks (e.g., `ContainerLifecyleAgent`, `LogStreamingAgent`). They run the Fast OODA loop.

### 2.2 Lock-Free State Management (Smriti)

Currently, the system relies on complex SQLite locks. By moving to an Agent model, state mutation becomes inherently sequential and thread-safe.

*   **The Planning Agent (Chaya/Todo)**: A single `MailboxProcessor` owns the `PROJECT_TODOLIST.md` and the SQLite database. If Elixir needs to update a task, it publishes a Zenoh message. The F# Zenoh subscriber forwards that message to the `PlanningAgent`'s inbox, guaranteeing no race conditions (`SC-TODO-001`).

### 2.3 Eliminating Script Sprawl

*   The 22 `sa-*.fsx` scripts will be deleted.
*   They will be replaced by a single, long-running F# daemon (`indrajaal-cepaf-daemon`).
*   The CLI commands (`sa-up`, `sa-health`) will become thin clients that send **Zenoh Queries** to the daemon. 

## 3. Zenoh-Only Communication (The Unified Backplane)

All JSON-RPC, REST, and custom port bridges between Elixir and F# will be dismantled. Zenoh becomes the singular nervous system connecting the two languages.

### 3.1 Topic Architecture (The Semantic Nervous System)

We will structure Zenoh topics to mirror the Agent hierarchy:

| Topic Pattern | Direction | Purpose | Semantic Mapping |
| :--- | :--- | :--- | :--- |
| `indrajaal/cepaf/cmd/<agent_id>` | Elixir $\to$ F# | Imperative commands. | "Act" |
| `indrajaal/cepaf/evt/<agent_id>` | F# $\to$ Elixir | State changes, events, logs. | "Observe" |
| `indrajaal/cepaf/query/<domain>` | Elixir $\leftrightarrow$ F# | Synchronous data requests. | "Orient" |

### 3.2 IPC Workflows

#### A. Command Execution (e.g., "Start Mesh")
1.  **Elixir** publishes to `indrajaal/cepaf/cmd/orchestrator` with payload: `{"command": "sa-up"}`.
2.  **F# Daemon** (Zenoh Subscriber) receives the message and posts it to the `ExecutiveAgent` inbox.
3.  **F# ExecutiveAgent** processes the OODA loop and delegates to the `PodmanSupervisor`.
4.  **F# Daemon** continuously publishes status updates to `indrajaal/cepaf/evt/orchestrator`.
5.  **Elixir** (Zenoh Subscriber) receives updates and updates the Phoenix LiveView.

#### B. Synchronous Queries (e.g., "Get Health Status")
1.  **Elixir** issues a Zenoh Query to `indrajaal/cepaf/query/health`.
2.  **F# Daemon** (Zenoh Queryable) intercepts the query.
3.  **F# Daemon** sends a `GetHealth` message to the `HealthCoordinatorAgent`, awaits the reply, and sends the Zenoh response back to Elixir.

## 4. Path Forward (Implementation Steps)

1.  **Phase 1: The Zenoh Daemon**: Create a new F# console application (`Cepaf.Daemon`) that initializes a Zenoh session and binds a basic `MailboxProcessor`.
2.  **Phase 2: Port the Planning System**: Move the `Cepaf.Planning` logic into a `PlanningAgent`. Expose it via Zenoh Queries (`indrajaal/cepaf/query/tasks`). Update Elixir to read tasks via Zenoh.
3.  **Phase 3: Port the Orchestrator**: Migrate the `sa-mesh.fsx` logic into an `OrchestratorAgent`. Have it listen for Zenoh commands.
4.  **Phase 4: Eradicate Scripts**: Delete the `.fsx` files and update `devenv.nix` to use Zenoh pub/sub commands or a thin F# CLI that talks exclusively to the Zenoh daemon.
