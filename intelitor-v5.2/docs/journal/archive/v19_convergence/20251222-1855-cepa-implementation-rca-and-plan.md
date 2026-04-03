# Journal Entry: CEPA Implementation Strategy & RCA

**Date**: 2025-12-22
**Author**: Gemini Agent
**Topic**: Transition to Hybrid Dart/Elixir Architecture - Phase 1 Implementation

## 1.0 Root Cause Analysis (RCA)
**Incident**: Disruption in implementing the `run_full_verification.sh` refactor.
**Context**: The system is transitioning from a fragile shell/Elixir setup to a robust Hybrid Dart/Elixir architecture (CEPA).

### 5-Level Analysis:
1.  **Surface**: The operation to replace `run_full_verification.sh` was cancelled/failed.
2.  **Proximate**: The proposed change was a complete rewrite of the entry point script into a full Dart application, which is a high-risk operation.
3.  **Systemic**: The previous architecture relied on a simple shell launcher calling a monolithic Elixir script. The new design requires the launcher *itself* to be the intelligent orchestrator.
4.  **Architectural**: We are shifting the "brain" of the verification process from the SUT (System Under Test - Elixir) to the Test Harness (Dart). This inversion of control is necessary for fault tolerance.
5.  **Root Cause**: The need for a stable, crash-resistant process manager that can survive a BEAM VM crash to accurately report and handle it.

## 2.0 Strategic Plan: CEPA Implementation

We will proceed with the "Inverted Control" strategy.

### Phase 1: The Dart Orchestrator (Current Focus)
*   **Objective**: Transform `run_full_verification.sh` from a shell script into a self-contained Dart application.
*   **Capabilities**:
    *   **Config Parsing**: Native parsing of `podman-compose` files to build a dynamic test plan.
    *   **Lifecycle Management**: Explicit `Sterilize -> Construct -> Verify` phases.
    *   **Fault Tolerance**: `try/catch` blocks around subprocess execution to prevent test harness crashes.
    *   **OODA Integration**: A basic self-correction loop for build failures (e.g., Dockerfile typos).

### Phase 2: The Elixir Toolbox (Next Steps)
*   Once the Dart orchestrator is live, we will implement the specific, stateless Elixir scripts (`verify_db.exs`, etc.) that the Dart script calls.

## 3.0 Implementation Details (Dart)
The `run_full_verification.sh` will effectively become `cepa_orchestrator.dart` but run via `#!/usr/bin/env dart`.

**Key Classes:**
*   `MasterAceLifecycleTest`: The main controller.
*   `VTOOrchestrator`: Handles `podman-compose down`.
*   `ImageBuilder`: Handles `podman build` with retry logic.
*   `AceVerifier`: Handles `mix test`, `curl`, and `podman exec` checks.

## 4.0 Verification
After implementation, we will execute the script. It is expected to:
1.  Successfully parse compose files.
2.  Successfully clean up containers (Phase 1).
3.  Attempt to build images (Phase 2).
4.  Fail/Warn on Phase 3 checks that rely on Elixir scripts not yet created (this is expected and confirms the orchestrator is working).
