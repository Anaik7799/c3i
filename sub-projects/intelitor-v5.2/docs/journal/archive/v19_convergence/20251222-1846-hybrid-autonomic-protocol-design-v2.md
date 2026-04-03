# Journal Entry: Unified Autonomic Verification Protocol Design v2 (Hybrid Architecture)

**Date**: 2025-12-22
**Author**: Gemini Agent
**Status**: DETAILED DESIGN COMPLETE

## 1.0 Executive Summary

This document outlines a fault-tolerant, hybrid architecture for the **CEPA (Cybernetic Execution and Performance Architect)**. The previous monolithic Elixir-based design proved to have a critical flaw: instability in any part of the Elixir application (the system under test) would crash the entire verification orchestrator.

This revised v2.0 architecture addresses this by inverting control. A robust **Dart application** now serves as the master orchestrator, while **Elixir scripts** are refactored into a toolbox of small, stateless, single-purpose command-line tools. This isolates failures, leverages the strengths of both platforms, and creates a more resilient and maintainable system.

## 2.0 Architectural Principles

1.  **Orchestrator-Tool Separation**: The orchestrator (Dart) is decoupled from the tools (Elixir). The orchestrator is responsible for *what* to do and *when*, while the tools are responsible for *how* to do it.
2.  **Process-Level Fault Isolation**: Each Elixir script runs in its own isolated BEAM instance. A crash in one tool does not affect the orchestrator or other tools.
3.  **Stateless Tools**: Elixir scripts are designed to be stateless. They receive all necessary context via command-line arguments or input files and produce a result to an output file or `stdout`. This makes them deterministic and easy to debug.
4.  **Structured Data Exchange**: Communication between Dart and Elixir is done via a simple, contract-based JSON protocol. This ensures clear and predictable data flow.
5.  **Centralized Control, Distributed Execution**: The Dart CEPA centralizes all decision-making, but can execute verification tasks in parallel, leveraging the process isolation of the Elixir toolset.

## 3.0 System Components & Functional Breakup

### 3.1 Dart Orchestrator (`run_full_verification.sh`)

The Dart application is the "brain" of the system.

#### **Key Modules/Classes:**

*   **`CEPA.dart`**: The main class, containing the OODA loop logic. It orchestrates the entire protocol.
*   **`LifecycleManager.dart`**: Implements the high-level `Sterilize -> Construct -> Verify` phases.
*   **`PodmanCompose.dart`**: A wrapper for executing `podman-compose` commands and parsing their output.
*   **`ElixirTool.dart`**: A generic class for running an Elixir script tool. It handles passing arguments, executing the script, and parsing the JSON result.
*   **`Quadplex.dart`**: A module responsible for ingesting and correlating the four pillars of logging data.

#### **Responsibilities:**

*   **Control Flow**: Manages the main sequence of verification steps.
*   **Configuration Management**: Reads and parses all `podman-compose-*.yml` files.
*   **Task Delegation**: Determines which Elixir tool to call for a given task.
*   **Result Analysis**: Reads the JSON output from Elixir tools to decide on the next action.
*   **Error Handling & Self-Correction**: Catches non-zero exit codes from subprocesses and initiates self-correction loops.

### 3.2 Elixir Toolbox (`scripts/*.exs`)

This is a collection of single-purpose command-line scripts. Each script uses `Mix.install/2` to load necessary dependencies.

#### **Script Granularity:**

Each script is designed to do one thing and do it well.

*   `scripts/verification/db_connect.exs`: Checks database connectivity.
*   `scripts/verification/web_health.exs`: Checks a web endpoint.
*   `scripts/verification/log_check.exs`: Checks for specific patterns in a log file.
*   `scripts/image_builder.exs`: Builds a single container image.
*   `scripts/container_sterilizer.exs`: Stops and removes all project containers.

## 4.0 Control Flow

### 4.1 Master Execution Flow

The control flow is managed entirely by the Dart orchestrator.

```
1. START: User runs ./run_full_verification.sh
2. DART: CEPA initializes.
3. DART: Calls LifecycleManager.sterilize().
   - Executes Elixir 'container_sterilizer.exs' script.
4. DART: Calls LifecycleManager.construct().
   - For each image, executes Elixir 'image_builder.exs'.
   - OODA loop monitors for build failures and attempts self-correction.
5. DART: Calls LifecycleManager.verify().
   - For each environment (dev, test, etc.):
     a. **DECIDE**: Determine verification steps based on parsed compose file.
     b. **ACT**: Execute a sequence of Elixir tool scripts for each check.
        - `elixir scripts/verification/db_connect.exs --input ...`
        - `elixir scripts/verification/web_health.exs --input ...`
     c. **OBSERVE**: Read the JSON output of each script.
     d. **ORIENT**: If a script fails, correlate with other data points (e.g., container logs) to diagnose the root cause.
6. DART: All steps complete. Exit with success code.
```

## 5.0 Data Flow

### 5.1 Communication Protocol (Dart <-> Elixir)

The communication is file-based to ensure simplicity and robustness.

1.  **Dart (Orchestrator)** writes a `task.json` file.
    ```json
    // task.json
    {
      "task": "verify_db",
      "params": {
        "database_url": "postgres://user:pass@host:port/db"
      }
    }
    ```
2.  **Dart** executes the Elixir script:
    ```bash
    elixir scripts/verification/db_connect.exs --input task.json --output result.json
    ```
3.  **Elixir (Tool)** reads `task.json`, performs its action, and writes to `result.json`.
    ```json
    // result.json
    {
      "status": "ok",
      "data": {
        "message": "Connection successful."
      }
    }
    ```
4.  **Dart** reads and deletes `task.json` and `result.json`, then processes the result.

### 5.2 Quadplex Data Ingestion

The Dart CEPA is the central point for collecting and analyzing all four types of data:

1.  **Console/File**: The Dart `_runCommand` function naturally captures all `stdout` and `stderr` from the Elixir tools, which constitutes the first two pillars.
2.  **Telemetry**: For telemetry checks, Dart executes a specific Elixir tool (`scripts/get_telemetry_metrics.exs`) that connects to the observability backend and returns the metrics as JSON.
3.  **State Tracker**: Similarly, another Elixir tool (`scripts/get_cubdb_state.exs`) connects to the CubDB file and returns the application's internal state as JSON.

## 6.0 Implementation Tradeoffs

*   **Performance vs. Robustness**: Starting a new BEAM instance for every Elixir script introduces a small overhead (typically <1 second per script). This is a deliberate tradeoff. We are accepting a slight performance penalty in exchange for near-perfect fault isolation. A failure in one check will never compromise the integrity of the orchestrator.
*   **Simplicity vs. Power**: The Elixir scripts are extremely simple, making them easy to write and debug. The complexity is moved to the Dart orchestrator, which is better suited for imperative control flow and process management.
*   **Loose vs. Tight Coupling**: This architecture is very loosely coupled. A new verification step only requires a new Elixir script and a corresponding call in the Dart orchestrator; the two components do not need to know about each other's internal logic.

## 7.0 Dashboard & Metrics

To provide visibility into this autonomous system, a simple text-based dashboard will be rendered to the console by the Dart orchestrator.

**Key Metrics to Track:**
*   **Verification Phase**: (Sterilizing, Building, Verifying `dev`, Verifying `test`, etc.)
*   **Current Task**: (e.g., `verify_db_connection.exs` for `indrajaal-app`)
*   **Self-Corrections**: A counter for the number of automatically corrected errors.
*   **Environment Status**: A table showing the status of each environment (Pending, Running, Passed, Failed).
*   **Execution Time**: A running timer for the entire process.

## 8.0 Logging & Debugging

This architecture makes debugging significantly easier.

*   **Centralized Logging**: The Dart orchestrator captures the `stdout` and `stderr` of every subprocess it runs. All logs are prefixed with the name of the script that produced them (e.g., `[db_connect.exs] Connecting to database...`).
*   **Debugging a Failed Tool**: If an Elixir script fails, the developer can take the exact command printed by the Dart orchestrator (including the generated `task.json` file) and run it manually in their terminal to get a fully reproducible test case, completely isolated from the rest of the system. This eliminates guesswork and dramatically speeds up root cause analysis.
