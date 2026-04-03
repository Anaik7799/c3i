# 5-Level RCA: ACE Verification Protocol Failures

**Date**: 2025-12-22
**Author**: Gemini (Cybernetic Architect)
**Status**: ANALYZED
**Incident**: Repeated failures to execute the `ace.verify` protocol.

---

## 1.0 Level 1: Surface Problem (Symptoms)
The user attempted to execute the "full container verification protocol."
*   **Symptom A**: `mix ace.verify` failed with `(Mix) The task "ace.verify" could not be found`.
*   **Symptom B**: Script-based execution (`elixir scripts/...`) failed with `(UndefinedFunctionError) function nil.config/0` (Oban startup failure).
*   **Symptom C**: Compilation warnings (Telemetry, SSL) treated as errors halted execution.

## 2.0 Level 2: Proximate Causes
*   **Cause A**: The file `lib/mix/tasks/ace_verify.ex` did not exist when `mix ace.verify` was run.
*   **Cause B**: Standalone Elixir scripts (`.exs`) invoked via `System.cmd("elixir", ...)` do not inherit the parent Mix environment. They start a fresh VM which fails to load `config/runtime.exs`, causing Oban to crash on boot.
*   **Cause C**: The project enforces `--warnings-as-errors`. Unused variables and deprecated function calls in `telemetry_metrics_worker.ex` and `ssl_fix.ex` prevented the application from compiling, which in turn prevented Mix tasks from being loaded.

## 3.0 Level 3: Contributing Factors
*   **Factor A (Deletion)**: The `mix ace.verify` task was explicitly deleted in a previous turn (`rm lib/mix/tasks/ace_verify.ex`) to switch to a "script-based" approach, but the operator (Agent) later attempted to run the deleted task.
*   **Factor B (Script Isolation)**: The `vto_orchestrator.exs` script relies on the full application environment (to access `Indrajaal.Deployment.Config` and potentially other modules) but was being run in isolation.
*   **Factor C (Circular Logic)**: The attempt to "fix" the script involved adding `Mix.Task.run("app.start")` inside it, but this fails because `Mix` is not fully initialized in a raw `elixir` script invocation.

## 4.0 Level 4: Systemic Issues
*   **Systemic Issue A (Fragmentation)**: Critical deployment logic (VTO, Image Building) resides in ad-hoc `scripts/` rather than in the core `lib/` codebase. This makes them second-class citizens, hard to test, and subject to environment drift.
*   **Systemic Issue B (Configuration Coupling)**: The application's startup (specifically Oban) is tightly coupled to the presence of specific environment variables (like `DATABASE_URL`) which may not be relevant for a simple verification script, yet the application crashes if they are missing or if config isn't loaded.

## 5.0 Level 5: Root Cause & Corrective Action
**Root Cause**: The **execution model was fundamentally flawed**. Attempting to orchestrate a complex system verification using nested, standalone scripts (`System.cmd("elixir", ...)`) breaks the Erlang/OTP application loading guarantees. The "Fix" cycle became a game of Whac-A-Mole with environment variables because we were fighting the platform's design instead of using it.

**Corrective Action Plan**:
1.  **Refactor to Library**: Move the logic from `scripts/containers/*.exs` into proper modules within `lib/indrajaal/deployment/`.
    *   `scripts/containers/vto_orchestrator.exs` -> `lib/indrajaal/deployment/vto_orchestrator.ex`
    *   `scripts/containers/ace_image_builder.exs` -> `lib/indrajaal/deployment/image_builder.ex`
    *   `scripts/testing/ace_full_environment_verification.exs` -> `lib/indrajaal/testing/ace_verifier.ex`
2.  **Recreate Mix Task**: Implement `mix ace.verify` not as a wrapper for shell commands, but as a direct caller of these new library modules. This guarantees a single, consistent runtime environment.
3.  **Clean Compilation**: Ensure the project compiles cleanly (completed in previous steps) so the task can be loaded.

---
**Signed**: Gemini (Cybernetic Architect)
