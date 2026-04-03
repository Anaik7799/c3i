# CEPAF Cockpit Console Design Analysis (F#)

**Date**: 2025-12-27 10:00 CEST
**Component**: `cepaf` (Cybernetic Execution and Performance Architect - F# Track)
**Context**: "infra-f#-cepa" / Version 19.0
**Status**: DESIGN ANALYSIS (Level 5 Detail)

## 1.0 Level 1: Strategic Vision (The "Why")

The **CEPAF Cockpit** (`cepaf-cockpit`) is the designated "Mission Control" interface for the Indrajaal system. While the Elixir `app-elixir-cepa` track handles application-level self-healing, `cepaf-cockpit` provides the **Human-in-the-Loop (HITL)** operational layer.

*   **Objective**: Consolidate disparate CLI tools (podman commands, mix tasks, validation scripts) into a single, cohesive, cybernetic TUI (Terminal User Interface).
*   **Philosophy**: "Observation precedes Actuation." The console must provide high-fidelity situational awareness before allowing control actions.
*   **Target State**: A single binary (`cepaf`) that launches an interactive, real-time dashboard capable of orchestrating the entire OODA loop.

## 2.0 Level 2: Architecture & Component Design (The "What")

The system follows a **Hexagonal Architecture** (Ports and Adapters) implemented in F#.

### 2.1 Module Breakdown
1.  **`Cepaf.Core`**: The domain logic. Contains the OODA loop definitions, state machines, and safety invariants.
2.  **`Cepaf.Cockpit` (Adapter)**: The Presentation Layer. Uses **Spectre.Console** to render the TUI.
3.  **`Cepaf.Infrastructure` (Adapter)**: The Actuation Layer. Wraps `Podman`, `Git`, and `FileSystem` interactions.
4.  **`Cepaf.Bridge` (Port)**: The Connectivity Layer. Communicates with the running Elixir nodes via **Zenoh** (preferred for mesh) or HTTP/JSON.

### 2.2 Dependency Graph
```mermaid
graph TD
    User --> [Cepaf.Cockpit]
    [Cepaf.Cockpit] --> [Cepaf.Core]
    [Cepaf.Core] --> [Cepaf.Infrastructure]
    [Cepaf.Core] --> [Cepaf.Bridge]
    [Cepaf.Infrastructure] --> [Podman/Docker]
    [Cepaf.Bridge] --> [Elixir Nodes]
```

## 3.0 Level 3: Inter-Process Communication & Data Flow (The "Flow")

The Cockpit operates on an **Async Actor Model** to ensure the UI remains responsive while handling heavy background I/O.

### 3.1 Data Flow Patterns
1.  **Telemetry Ingestion (Stream)**:
    *   Source: Elixir nodes emit `:telemetry` events.
    *   Bridge: Zenoh topic `indrajaal/telemetry/**`.
    *   Sink: F# `MailboxProcessor` aggregates metrics into a `SystemState` record.
    *   UI Update: The TUI redraws at 10Hz (max) using the latest state.

2.  **Command Execution (Request/Reply)**:
    *   Source: User selects "Restart Database" in TUI.
    *   Validation: `Cepaf.Core` checks STAMP constraints (e.g., "Is volume backed up?").
    *   Execution: `Cepaf.Infrastructure` executes `podman restart indrajaal-db`.
    *   Feedback: Operation result is piped to the "Action Log" panel.

## 4.0 Level 4: UX/UI Design & Implementation Specifics (The "How")

### 4.1 Technology Stack
*   **Language**: F# (.NET 8/9).
*   **UI Library**: `Spectre.Console` (The gold standard for .NET TUIs).
*   **CLI Parsing**: `System.CommandLine` or `Argu` (F# native).
*   **Concurrency**: `FSharp.Control.Async` and `MailboxProcessor`.

### 4.2 Screen Layout (Spectre.Console Grid)
The TUI will be divided into a 2x2 or 3-column grid:

| **Status (Top Left)** | **Metrics (Top Right)** |
| :--- | :--- |
| **Container Health**: ✅<br>**Validation Gate**: 🟢<br>**Active Phase**: 4 (Prod) | **CPU**: 45% \| **RAM**: 12GB<br>**Events/s**: 1,240<br>**OODA Latency**: 45ms |
| **Active Tasks / OODA Loop (Bottom Left)** | **Logs / Audit Trail (Bottom Right)** |
| > *Analyzing Root Cause...*<br>> *Running G3 Verification...* | [10:00:01] **INFO**: DB Connected<br>[10:00:05] **WARN**: Latency Spike |

### 4.3 F# Type Domain (Sketch)
```fsharp
type SystemStatus = Healthy | Degraded | Critical | Maintenance

type ContainerState = {
    Name: string
    Status: string
    CpuUsage: float
    MemoryUsage: float
}

type Msg =
    | Tick of DateTime
    | TelemetryReceived of Metric
    | UserCommand of Command
    | InfrastructureEvent of Event

type Model = {
    Status: SystemStatus
    Containers: Map<string, ContainerState>
    RecentLogs: LogEntry list
}
```

## 5.0 Level 5: Safety & STAMP Compliance (The "Guardrails")

### 5.1 Safety Constraints (SC-CEPAF)
The Cockpit MUST enforce the following constraints **before** any command is sent to the infrastructure.

*   **SC-CEPAF-001 (Two-Key Turn)**: Any destructive operation (Data Deletion, Force Kill) REQUIRES an explicit, randomized confirmation code (e.g., "Type '7392' to confirm").
*   **SC-CEPAF-002 (State Awareness)**: The Cockpit SHALL NOT allow "Start" commands if the state is already "Running".
*   **SC-CEPAF-003 (Audit Logging)**: Every user interaction MUST be logged to `docs/journal/audit/` with a timestamp and user ID before execution.
*   **SC-CEPAF-004 (Visual Distinctiveness)**: Production environments MUST be rendered with a **RED** border/theme to prevent context confusion. Development is **GREEN/BLUE**.

### 5.2 Verification
*   **Unit Tests**: Use `Expecto` to test the `Update` function of the MVU architecture.
*   **Property Tests**: Verify that invalid states cannot be represented in the `Model`.
