# Plan Update Journal Entry

**Date**: 20260320-1200 CEST
**Plan Document**: N/A (Architecture Analysis & Design)
**Update Type**: CREATED
**Author**: Cybernetic Architect (Gemini)

## Executive Summary
This document provides a comprehensive analysis and detailed design for integrating the F# testing infrastructure (`RegressionRunner`, `RuntimeTestOrchestrator`) with `Sentinel-Zenoh`. The goal is to provide unified Control Plane and Data Plane access to testing functionality via both MCP (for Claude/Gemini) and native Zenoh pub/sub.

## 1. Requirements Summarization

1.  **Lifecycle Control**: Ability to remotely `start`, `stop`, and `query` the status of F# tests.
2.  **Omni-Channel Access**: 
    *   **MCP**: Controllable by AI agents (Gemini/Claude) via Model Context Protocol tools.
    *   **Zenoh**: Controllable by any node in the Biomorphic Fractal Mesh via Zenoh topics.
3.  **Plane Separation & Accessibility**:
    *   **Control Plane**: Imperative commands (start, stop) and synchronous queries (status).
    *   **Data Plane**: Real-time streaming of test progress, assertions, and metrics.
    *   *Constraint*: Both planes must be fully accessible from MCP and Zenoh.
4.  **Integration with Existing CEPAF**: Must leverage the existing `Cepaf.Testing.RegressionRunner` (5-Level Suite) and `Cepaf.Zenoh.Core` (Native FFI).

## 2. Architectural Design

### 2.1 The F# Test Agent (The Executor)
A new long-running MailboxProcessor actor, `Cepaf.Testing.TestAgent`, will be embedded within the `Cepaf.KmsCatalog.Daemon` or the primary `Cepaf.Bridge` host.
*   **Role**: Subscribes to Control Plane Zenoh topics, manages the subprocess/execution thread of tests, and handles cancellation tokens.
*   **Zenoh Topics**:
    *   `indrajaal/test/fsharp/cmd/start` (Subscribes to start triggers)
    *   `indrajaal/test/fsharp/cmd/stop` (Subscribes to abort triggers)
    *   `indrajaal/test/fsharp/query/status` (Responds to Zenoh get/query requests)
*   **Action**: Upon receiving a `start` command, it spawns `RegressionRunner.run` asynchronously.

### 2.2 Data Plane (Real-Time Results)
The existing `ZenohTestTelemetry` and `ZenohProgress` modules inside `RegressionRunner.fs` already utilize a triple-write pattern.
*   **Enhancement**: We will ensure the `ZenohPublish.setNativeSession` is injected by the `TestAgent` so real Zenoh Native FFI messages are broadcasted.
*   **Topics**:
    *   `indrajaal/regression/run/*/start`
    *   `indrajaal/regression/test/*/*/result`
    *   `indrajaal/regression/level/*/progress`

### 2.3 MCP Integration (The AI Bridge)
The `Cepaf.Sentinel.MCP` server will be expanded with a dedicated toolset for testing, abstracting the raw Zenoh topics into semantic AI capabilities.
*   **`test_fsharp_start`**: Takes configuration (e.g., levels `[1, 2, 3]`). Translates to a `zenoh_pub` on the control plane.
*   **`test_fsharp_stop`**: Publishes the abort signal.
*   **`test_fsharp_status`**: Executes a Zenoh query to retrieve the current state vector.
*   **`test_fsharp_results`**: Subscribes/polls the Data Plane topics (using the underlying `zenoh_sub` mechanism) to stream recent test failures or live progress back to the LLM.

## 3. Implementation Approach

**Phase 1: Agent & State Management (F# Core)**
1.  Define the schema for `TestCommand` and `TestStatus` records.
2.  Implement `Cepaf.Testing.TestAgent` using F#'s `MailboxProcessor` for lock-free state management.
3.  Wire the agent to an active `ZenohLifecycle` session to register its subscribers and queryable endpoints.

**Phase 2: Execution Hook-up**
1.  Refactor `RegressionRunner` to accept a `CancellationToken`.
2.  Connect the `TestAgent`'s "Start" state to spawn the runner task, passing the cancellation token.
3.  Connect the "Stop" state to trigger `CancellationTokenSource.Cancel()`.

**Phase 3: MCP Tooling (Sentinel.MCP)**
1.  Add a `TestTools.fs` module to `Cepaf.Sentinel.MCP`.
2.  Implement the MCP schema for `test_start`, `test_stop`, `test_status`.
3.  Under the hood, these MCP tools will utilize the existing `ZenohState` to perform `ZenohFfiBridge.publish` and `ZenohFfiBridge.get`.

**Phase 4: Telemetry & Data Plane Bridging**
1.  Ensure the MCP server can subscribe to Data Plane topics (`indrajaal/regression/#`) and buffer them.
2.  Provide a `test_get_logs` MCP tool that dumps the bounded buffer of recent test events so Claude/Gemini can read the exact test failure stack traces.

## 4. Supported Features

*   **Asynchronous Orchestration**: AI agents can trigger a heavy 15-minute 5-level regression test suite and continue doing other work, polling status occasionally.
*   **Surgical Interruption**: If an AI notices the environment is broken, it can abort the test run immediately to save compute.
*   **Deep Introspection**: Gemini/Claude can query the exact state vector `[L1, L2, L3, L4, L5]` representing `[Pending, Running, Pass, Fail, Skip]`.
*   **Mesh Interoperability**: Because the control is fundamentally Zenoh-based, a Rust node or an Elixir LiveView dashboard can trigger the exact same F# tests using the same topics.
*   **OODA Integration**: Integrates directly into the system's autonomic loops. An error detected in production can automatically trigger a targeted test run to replicate the issue.