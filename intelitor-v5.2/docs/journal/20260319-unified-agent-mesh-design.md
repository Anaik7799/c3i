# Journal: Biomorphic F# Agentic Mesh & Zenoh Unified IPC

**Date**: 2026-03-19
**Author**: Cybernetic Architect (Gemini)
**Status**: DESIGN & SPECIFICATION
**Version**: 1.0.0-SIL6
**Focus**: Unified F# Agent Framework replacing Dapr and Fragmented Scripts.

## 1. The Fractal Entity Model (L0-L5)

The implementation maps the Indrajaal 50-agent hierarchy into a fractal holonic structure where each entity is a stateful F# Actor (`MailboxProcessor`).

| Fractal Level | Entity | Responsibility | Implementation |
| :--- | :--- | :--- | :--- |
| **L5: Federation** | Global Mesh | Cross-holon negotiation and drift detection. | Zenoh Federation Protocol |
| **L4: Mesh** | The Cluster | The collective of indrajaal-app, db, and obs nodes. | Zenoh Topic Hierarchy |
| **L3: Organism** | Executive Agent | Supreme authority; orchestrates Supervisors. | Singleton Actor (Root) |
| **L2: Holon** | Domain Supervisors | Lifecycle, Health, Planning, Knowledge. | Supervision Actors |
| **L1: Atomic** | Worker Agents | Atomic tasks: `StartContainer`, `UpdateTask`. | Leaf Actors |
| **L0: Substrate** | Environment | Podman socket, Zenoh router, SQLite/DuckDB. | Native Native/Unix Sockets |

## 2. Design: The Unified Backplane

### 2.1 Agent State Machine (OODA Implementation)
Every agent implements a standardized OODA cycle within its message loop:
*   **Receive (Observe)**: Listen for Zenoh messages or internal Actor messages.
*   **Match (Orient)**: Categorize message type and validate against the `SystemRegistry`.
*   **Process (Decide)**: Execute logic (Pure F#) or consult the `Guardian` safety kernel.
*   **Execute (Act)**: Trigger a Zenoh publication, a Podman command, or a database write.

### 2.2 Zenoh-Only IPC
No more JSON-RPC or Elixir Ports.
*   **Command Bus**: `indrajaal/cepaf/cmd/*`
*   **Event Bus**: `indrajaal/cepaf/evt/*`
*   **Query Bus**: `indrajaal/cepaf/query/*`

## 3. Implementation Blueprint

### 3.1 The Core Agent Template
```fsharp
type AgentMessage =
    | Command of string * Payload
    | HealthCheck of AsyncReplyChannel<HealthStatus>
    | InternalSignal of Signal

let createAgent name parent =
    MailboxProcessor.Start(fun inbox ->
        let rec loop state = async {
            let! msg = inbox.Receive()
            // SC-VAL-003: FPPS Consensus inside match
            match msg with
            | Command(cmd, payload) ->
                let newState = processCommand state cmd payload
                return! loop newState
            | HealthCheck channel ->
                channel.Reply (calculateHealth state)
                return! loop state
        }
        loop InitialState)
```

### 3.2 The Zenoh Bridge
A dedicated `ZenohBridgeActor` manages the native connection to `libzenoh_ffi.so`, routing external messages to the correct internal Agent inboxes.

## 4. Key Features Provided
1.  **Zero-Latency Boot**: No JIT compilation of `.fsx` scripts; code is pre-compiled.
2.  **Thread-Safe Persistence**: The `SmritiAgent` serializes all writes to SQLite, eliminating database locking errors.
3.  **Autonomous Recovery**: If a Worker Agent crashes, its Supervisor Agent catches the exception and restarts it (Erlang-style supervision in F#).
4.  **Invisible UI**: The Cockpit TUI becomes a stateless Zenoh subscriber, making it significantly faster and lighter.

## 5. Testing & Validation Strategy

### 5.1 Three-Layer Testing
1.  **Unit (Expecto)**: Test `processCommand` logic using pure functions without Zenoh or Podman.
2.  **Integration (Zenoh Mock)**: Use a local Zenoh router to verify that `sa-plan` messages correctly reach the `PlanningAgent`.
3.  **Property (FsCheck)**: Verify invariants like: "The task count in SQLite MUST always match the task count in PROJECT_TODOLIST.md."

### 5.2 Failure Mode Analysis (FMEA)
*   **FM-001: Zenoh Disconnect**: Agents enter "Hibernation" mode, buffering local state to SQLite until reconnection.
*   **FM-002: Agent Deadlock**: Standard `MailboxProcessor` timeouts trigger a Supervisor restart.

## 6. Coverage Goals
*   **Logic Coverage**: 100% of the OODA decision logic (Target: 5000+ tests).
*   **Constraint Coverage**: All 242 STAMP constraints mapped to an automated check.
*   **Interaction Coverage**: All 17 mobile endpoints verified through Zenoh query/reply simulations.

---
**The Cybernetic Pledge**: "I am the Architect of the Loop. I recognize the Codebase as a Living Graph."
