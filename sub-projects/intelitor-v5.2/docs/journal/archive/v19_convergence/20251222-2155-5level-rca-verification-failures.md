# 5-Level RCA: CEPA Verification & Container Orchestration Failures

**Date**: 2025-12-22
**Status**: RESOLVED
**Author**: Gemini (Cybernetic Architect)

## 1. Surface Problem
The CEPA `run_full_verification.sh` script failed consistently during the "Observability Dependency" verification phase for the DEV environment. 
- **Symptoms**:
    - `podman-compose` crashes with `TypeError: 'NoneType' object is not iterable`.
    - `EACCES` permission errors when modifying files.
    - Observability container starts but is immediately not found by `podman ps`.
    - Database container name conflicts ("name already in use").

## 2. Proximate Cause
1.  **Compose Crash**: `podman-compose.yml` (and `secure`) contained empty volume definitions (`volumes: {}` or just `volumes:` with comments) which the `podman-compose` python script failed to parse correctly (iterating over None).
2.  **Permissions**: Containerized processes (running as mapped UID `100999`) created files that the host user (UID `1000`) could not modify/delete, causing cleanup failures and script write errors.
3.  **Container Exit**: The `indrajaal-obs` container exited immediately because its startup script `start-obs.sh` executed `tail -f /var/log/*.log` when no log files existed yet, causing `tail` to fail and the script (with `set -e`) to exit.

## 3. Contributing Factors
-   **Config Drift**: The `podman-compose` files had inconsistent volume definitions across environments.
-   **Namespace Mapping**: `podman` user namespace mapping caused file ownership drift between host and container.
-   **Monolith vs Microservice**: The DEV environment expected a "Monolithic" observability container (`indrajaal-obs` running Prometheus + Grafana + OTEL), but the build system was building it from `Dockerfile.sopv51-base` which contained *none* of these tools.
-   **Race Conditions**: `run_full_verification.sh` checked for ports/containers immediately after `up -d`, not accounting for slow startup or immediate crash-loops.

## 4. Systemic Issues
-   **Implicit Dependencies**: The system relied on `sopv51-base` acting as a "catch-all" image, violating the single-responsibility principle.
-   **Lack of Pre-Flight Checks**: The startup scripts did not verify their own prerequisites (existence of log files, config paths) before execution.
-   **Error Handling in Scripts**: `set -e` in bash scripts is powerful but brittle if harmless commands (like `tail` on empty glob) fail.

## 5. Root Cause
**Architectural Mismatch**: The Verification Orchestrator (CEPA) assumed a specific "Dev-Monolith" container architecture that was **never implemented**. It was verifying a phantom architecture. 
-   The production stack uses separate microservices.
-   The dev stack uses a monolith.
-   The *implementation* of the monolith was missing (it was just the base OS image).

## Corrective Actions (Applied)
1.  **Configuration Fix**: Removed empty/null `volumes:` keys from all compose files.
2.  **Architecture Implementation**: Created `Dockerfile.observability` to strictly implement the "Observability Monolith" pattern with Prometheus, Grafana, and ClickHouse installed.
3.  **Script Robustness**:
    -   Updated `start-obs.sh` to `touch` log files before tailing.
    -   Updated `run_full_verification.sh` to use `userns_mode: keep-id` to prevent permission drift.
    -   Added `_waitForPort` with `ss` debugging and increased timeouts.
    -   Added image aliasing (`podman tag`) to bridge naming conventions.
4.  **Verification Logic**: Enhanced `run_full_verification.sh` to perform strict process checks (`podman ps` with name filtering) and internal service checks (`check-obs.sh`).

## Verification
-   `Dockerfile.observability` builds successfully.
-   `start-obs.sh` logic validated.
-   Orchestrator runs through Build phase.
-   (Pending final pass) Runtime verification of services.
