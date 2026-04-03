# Journal Entry: Unified Autonomic Verification Protocol Design

**Date**: 2025-12-22
**Author**: Gemini Agent
**Status**: DESIGN COMPLETE

This document provides a detailed architectural design for the **CEPA (Cybernetic Execution and Performance Architect)**, a self-correcting, cybernetic verification system. It outlines the Elixir-based architecture, data structures, and control flows required to implement the protocol.

---

## 1.0 Core Elixir Architecture

The system is centered around a set of Elixir modules, orchestrated by a master script. A lightweight Dart launcher (`run_full_verification.sh`) will act as the entry point, immediately executing the main Elixir orchestrator.

### 1.1 `MasterAceLifecycleTest`: The Orchestrator

This is the main entry point (`scripts/master_ace_lifecycle_test.exs`). It defines the high-level, three-phase workflow.

**Control Flow:**
```elixir
defmodule MasterAceLifecycleTest do
  def main do
    with :ok <- Indrajaal.VTOOrchestrator.sterilize_all(),
         :ok <- Indrajaal.ImageBuilder.build_all(),
         :ok <- Indrajaal.AceVerifier.verify_all_environments() do
      IO.puts "✅ Full System Verification Protocol Completed Successfully."
      System.halt(0)
    else
      {:error, reason} ->
        IO.puts "❌ A critical error occurred: #{reason}"
        System.halt(1)
    end
  end
end
```

### 1.2 `VTOOrchestrator`: The Sterilizer

This module ensures a clean state by removing all project-related containers, networks, and volumes before verification begins.

**Implementation Details:**
- Uses `System.cmd/2` to execute `podman-compose down -v`.
- The implementation will be enhanced to find all containers with a project label (e.g., `io.podman.compose.project=indrajaal-v52`) and remove them individually for more robust cleanup.

### 1.3 `ImageBuilder`: The Constructor

This module rebuilds container images from their source `Containerfile` to ensure a clean and verifiable build.

**Implementation Details:**
- A map (`@images`) will define the relationship between an image tag and its source file.
- It iterates through the map, calling a private `build_image/2` function for each.
- **Self-Correction (OODA Loop)**: The `handle_build_failure/4` function will contain regex patterns to identify common build errors (e.g., syntax mistakes in a Dockerfile) and will attempt to automatically patch the file and retry the build once.

### 1.4 `AceVerifier`: The Cybernetic Verifier

This module is the core of the CEPA, managing the verification of each environment and implementing the decision-making logic of the OODA loop.

**Implementation Details:**
- It will load and parse all `podman-compose-*.yml` files into a list of `ComposeConfig` structs.
- It will first execute the specialized `verify_dev_environment/0` function for the host-based setup.
- It will then iterate through the remaining containerized configurations, calling `verify_container_environment/1` for each.

### 1.5 Data Structures

A dedicated struct will be used to hold the parsed data from each compose file, enabling the data-driven verification logic.

```elixir
defmodule Indrajaal.AceVerifier.ComposeConfig do
  @enforce_keys [:name, :filename, :services]
  defstruct [:name, :filename, services: %{}]
end

defmodule Indrajaal.AceVerifier.Service do
  @enforce_keys [:name, :image]
  defstruct [:name, :image, :command, :environment, :ports, :volumes]
end
```

---

## 2.0 The Verification Protocol in Detail

### 2.1 Host-Based `dev` Environment Verification

This is a unique phase that tests the application directly on the host to isolate application logic from containerization issues.

**Control Flow:**
1.  **Start Dependencies**: Bring up `indrajaal-db` container.
2.  **Wait for DB**: A looped Ecto query (`_waitForDatabase`) ensures the database is fully ready.
3.  **Start App**: Launch `iex -S mix phx.server` as a background OS process.
4.  **Observe (Quadplex)**: Monitor the Phoenix server's `stdout` for the startup message AND poll a `CubDB` state file for a `:boot_complete` atom.
5.  **Orient**: The CEPA will differentiate between a simple crash (no logs) and a complex hang (web server up, but `:boot_complete` never written).
6.  **Act & Verify**: Execute a series of `System.cmd/2` calls to verify:
    *   **Web**: `curl http://localhost:4000`
    *   **Database**: `mix run -e "..."`
    *   **Logging**: `File.stat!("logs/session-dev.log")`
    *   **Telemetry**: `podman exec indrajaal-obs ...`
7.  **Shutdown**: Gracefully kill the server process and bring down the `indrajaal-db` container.

### 2.2 Containerized Environment Verification

This phase verifies the application in its fully containerized state for `test`, `demo`, and `prod` environments.

**Control Flow:**
1.  **Start Environment**: Run `podman-compose -f <config_file> up -d`.
2.  **Verify (via `podman exec`)**: All checks are performed by executing commands *inside* the containers to validate their internal state and networking.
    *   `podman exec <app_container> curl http://postgres:5433` (verifies internal network).
    *   `podman exec <db_container> pg_isready`.
3.  **Shutdown**: Run `podman-compose -f <config_file> down`.

---

## 3.0 CEPA in Action: OODA Loop & Self-Correction Scenarios

The system's intelligence comes from its ability to correlate data from the four logging pillars and act on it.

### 3.1 Scenario 1: Simple Build Failure (Dockerfile Syntax Error)

1.  **Observe**: `podman build` returns a non-zero exit code. The **Console** log shows: `Dockerfile:15 unexpected token 'RUNN'`.
2.  **Orient**: The error is classified as a "Dockerfile Syntax Error".
3.  **Decide**: The CEPA determines a high-confidence fix: "RUNN" -> "RUN".
4.  **Act**: The `ImageBuilder` module reads the Dockerfile, applies the string replacement, and re-runs the build command.

### 3.2 Scenario 2: Complex Runtime Failure (DB Connection Timeout)

1.  **Observe**:
    *   **Console**: The `_waitForDatabase` loop times out and fails.
    *   **Telemetry**: Shows zero active DB connections.
    *   **State Tracker**: The `CubDB` state remains stuck at `:repo_started`.
    *   `podman ps` shows the DB container is "running".
2.  **Orient**: The CEPA correlates the signals: the container is running but the application cannot establish a connection. This is a configuration or internal database issue, not a simple container crash.
3.  **Decide**: The CEPA decides to investigate the configuration mismatch between the application's environment variables and the database's exposed state.
4.  **Act**: It programmatically inspects the `DATABASE_URL` used by the app and the `environment` section of the parsed `podman-compose.yml` for the `postgres` service. Upon finding a port mismatch, it HALTS the verification and outputs a precise, actionable error: "Configuration mismatch: App expects DB on port 5432, but container is configured for 5433."

---

## 4.0 Quadplex Logging Implementation Details

The four pillars of logging provide the sensory input for the CEPA.

1.  **Console (IO)**: Implemented via `IO.puts` and by streaming the `stdout` of child processes directly to the main script's console.
2.  **File (`Logger`)**: Elixir's `:logger` application will be configured with a file backend to automatically write all log events to a timestamped session file in the `logs/` directory.
3.  **Telemetry (`:telemetry` & `OpenTelemetry`)**: The application will be instrumented with `:telemetry.execute/3` calls at critical points (e.g., function entry/exit, query times). These events will be consumed by `Opentelemetry` and exported to the `indrajaal-obs` container. The CEPA can then query the observability backend via its API.
4.  **State Tracker (`CubDB`)**: A simple `GenServer` named `Indrajaal.Observability.StateTracker` will wrap a `CubDB` database. Application components will call `StateTracker.set(:my_component_status, :started)` at key points in their initialization, providing a durable, queryable record of the application's boot process.

---
