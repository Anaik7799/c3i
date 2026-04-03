# Journal Entry: Definitive CEPA-Driven Verification Plan

**Date**: 2025-12-22
**Author**: Gemini (Cybernetic Architect)
**Reference RCA**: `docs/journal/20251222-1700-rca-verification-failure.md`
**Status**: ACTIVE

## 1.0 Overview

This document outlines the final, definitive action plan to implement a robust, end-to-end verification protocol. It corrects the strategic misalignment identified in the latest Root Cause Analysis, moving from a fragile, linear script execution model to a resilient, cybernetic approach that embodies the CEPA/OODA/Quadplex principles.

The core of this plan is to create a master orchestration script that acts as an intelligent agent, using real-time feedback from the system to make decisions, rather than blindly executing a pre-determined sequence.

## 2.0 The Action Plan

### 2.1. Architectural Consolidation

1.  **Create Master Orchestrator**: A new master script, `scripts/verification/cepa_verification_protocol.exs`, will be created. This script will serve as the single entry point and contain the logic for the OODA loops for all environments.
2.  **Deprecate Old Scripts**: The now-obsolete scripts (`scripts/testing/start_prerequisites.exs`, `scripts/master_ace_lifecycle_test.exs`) have already been deleted.
3.  **Refine Core Modules**:
    *   `lib/mix/tasks/ace_verify.ex`: Will be simplified to be a clean, single entry point that invokes the new CEPA orchestrator script.
    *   `lib/indrajaal/testing/ace_verifier.ex`: Will be refactored to contain granular, check-specific functions (e.g., `check_db_connectivity`, `check_web_access`) that can be called by the CEPA orchestrator.
    *   `lib/indrajaal/deployment/vto_orchestrator.ex`: Is now correctly implemented to use `podman-compose`, respecting the robust health checks in the YAML files. This module is now considered stable.

### 2.2. Phase 1: Host-Based `dev` Verification (OODA Loop Implementation)

This phase will be driven by active observation using the Quadplex pillars.

1.  **ACT (Dependencies):** The CEPA script will execute `podman-compose -f podman-compose.dev.yml up -d`.
2.  **OBSERVE (Dependencies):** The script will actively monitor the health of the dependency containers:
    *   **Console:** Poll `podman ps --filter "status=healthy"` to confirm readiness.
    *   **File:** Tail the `indrajaal-db` logs for the `database system is ready` message.
    *   **State:** Attempt a direct `Postgrex.start_link` connection in a retry loop.
3.  **ORIENT/DECIDE (Dependencies):** If any dependency fails to become healthy, the script will dump the specific container's logs and halt with a precise error (e.g., "DB_HEALTH_CHECK_TIMEOUT").
4.  **ACT (Application):** If dependencies are healthy, the script will start the Phoenix server as a background OS process (`mix phx.server &`) and capture its PID.
5.  **OBSERVE (Application):** The script will then verify the running host application by actively checking the four pillars:
    *   **Web Access:** `curl --fail http://localhost:4000/health`.
    *   **Database Connectivity:** Execute a simple Ecto query (`Repo.all(Indrajaal.Core.Tenant)`).
    *   **Logging:** Verify that a designated log file (`logs/dev/quadplex.log`) has been recently modified.
    *   **Telemetry:** Programmatically check if the `:telemetry_metrics` OTP application is loaded and running.
6.  **ORIENT/DECIDE (Application):** A PASS/FAIL status is determined based on the results of all four checks.
7.  **ACT (Cleanup):** The script will ensure a graceful shutdown by terminating the captured `phx.server` PID and executing `podman-compose -f podman-compose.dev.yml down --volumes`.

### 2.3. Phase 2: Container-Based Verification (OODA Loop for Test/Demo/Prod)

1.  **ACT:** The CEPA script will loop through the `:test`, `:demo`, and `:prod` environments. For each, it will invoke the corrected `VTOOrchestrator` which runs the appropriate `podman-compose -f <file> up -d` command. The success of this command is predicated on all containers passing their internal, robust TCP-based health checks.
2.  **OBSERVE:** The primary observation is the exit code from the `VTOOrchestrator` script.
3.  **ORIENT:**
    *   An exit code of `0` signifies that the entire container stack for that environment started, became healthy, and is stable. This constitutes a pass for the "Construction & Verification" phase for that environment.
    *   A non-zero exit code signifies a critical failure.
4.  **DECIDE/ACT:** Upon failure, the script will immediately call `podman-compose -f <file> logs` to capture the complete state of all containers at the moment of failure and print a detailed report before halting. This provides precise, actionable data for the next corrective OODA loop.

This plan directly implements the required cybernetic feedback loop and provides a clear, robust, and repeatable path to full system verification.
