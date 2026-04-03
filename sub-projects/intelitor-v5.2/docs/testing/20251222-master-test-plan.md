# Comprehensive 5-Level Test & Verification Plan for ACE

**Version**: 1.0.0
**Date**: 2025-12-22
**Classification**: TEST & VERIFICATION STRATEGY
**Framework**: CAFE (Cybernetic Architect Framework for Execution)
**Objective**: To certify the **Autonomic Container Ecosystem (ACE)** and the **Verify-Then-Orchestrate (VTO)** protocol, ensuring 100% successful container creation and functionality for Dev, Test, Demo, and Production environments.

---

## 1.0 Level 1: Strategic Test Objective

The primary goal is to **formally verify** that the ACE framework produces reliable, secure, and compliant containerized environments for all specified operational profiles (Dev, Test, Demo, Prod). This plan moves beyond simple unit testing to a multi-layered, cybernetically-managed validation process that mirrors the system's own architecture.

### 1.1 Test Philosophy: "Test the Factory, Not Just the Product"
Instead of only testing the final container, we will test the entire "factory" (the build and orchestration process itself). This ensures that not only is the *current* build correct, but that *all future* builds will be correct.

### 1.2 CAFE Framework
The **Cybernetic Architect Framework for Execution (CAFE)** will be used to orchestrate this test plan. It uses a multi-agent hierarchy to parallelize and supervise test execution.

---

## 2.0 Level 2: Test Architecture & Environment Profiles

### 2.1 The Test Supervisor Hierarchy
A dedicated team of 15 agents will execute this plan, supervised by the CAFE Executive.

*   **L0 - CAFE Executive (1)**: Orchestrates the entire test plan.
*   **L1 - Environment Supervisors (4)**: One for each profile (Dev, Test, Demo, Prod). Responsible for setup and teardown.
*   **L2 - Functional Supervisors (5)**:
    *   **Build Supervisor**: Validates `Dockerfile` and `nix` builds.
    *   **Runtime Supervisor**: Validates running container binaries and connectivity.
    *   **Security Supervisor**: Audits for vulnerabilities and compliance.
    *   **Performance Supervisor**: Measures build times and container boot latency.
    *   **Documentation Supervisor**: Ensures all user-facing guides are accurate.
*   **L3 - Worker Agents (5)**: Execute the atomic test cases.

### 2.2 Environment Profiles Under Test
The VTO Orchestrator will be invoked for each of the 4 key environment profiles defined in the SSoT (`lib/indrajaal/deployment/config.ex`).

| Profile | `vto_orchestrator.exs` Command | Key Characteristics to Verify |
| :--- | :--- | :--- |
| **Dev** | `--env dev --action start` | PHICS hot-reloading active, Source code mounted. |
| **Test** | `--env test --action start` | `MIX_ENV=test`, Ecto Sandbox active, No PHICS. |
| **Demo** | `--env demo --action start` | `MIX_ENV=prod` (or demo), Seeded data, No source mount. |
| **Prod** | `--env prod --action start` | Hardened security, `MIX_ENV=prod`, Mapped to 80/443. |

---

## 3.0 Level 3: Master Test Plan (Task Groups)

This plan is divided into five sequential phases, mirroring the application lifecycle. A failure in any phase triggers a Jidoka halt for that specific test run.

### 3.1 Phase 1: Pre-Flight Integrity Check (Static Analysis)
*   **Objective**: Verify the "Blueprint" before construction.
*   **Supervisor**: Build Supervisor.
*   **Tasks**:
    *   `T1.1`: Validate SSoT `Config.ex` syntax.
    *   `T1.2`: Validate `Dockerfile.sopv51-base` and all `.nix` files for version correctness (Elixir 1.19, OTP 28).
    *   `T1.3`: Lint all orchestration scripts (`vto_orchestrator.exs`, etc.).

### 3.2 Phase 2: Sterilization Protocol Test
*   **Objective**: Verify the "Clean Room" mechanism works.
*   **Supervisor**: Environment Supervisor.
*   **Tasks**:
    *   `T2.1`: Create dummy "dirty" containers and `_build` files.
    *   `T2.2`: Run the Sterilization phase (`vto_orchestrator.exs --action stop`).
    *   `T2.3`: Verify all dummy artifacts were successfully removed.

### 3.3 Phase 3: Construction & Build Audit
*   **Objective**: Certify the integrity of the generated container images.
*   **Supervisor**: Build Supervisor.
*   **Tasks**:
    *   `T3.1`: Execute the `podman build` sequence.
    *   `T3.2`: **Binary Audit**: `podman run --rm [image] elixir --version` (Must show 1.19/28).
    *   `T3.3`: **Utility Audit**: `podman run --rm [image] which hostname` (Must succeed).
    *   `T3.4`: **Security Audit**: Run `trivy` scan on the final image for vulnerabilities.

### 3.4 Phase 4: Runtime & Functional Verification
*   **Objective**: Verify the "liveness" and "readiness" of each service.
*   **Supervisor**: Runtime Supervisor.
*   **Tasks**:
    *   `T4.1`: Execute `vto_orchestrator.exs --action start` for a target environment.
    *   `T4.2`: **Connectivity Test**: `podman exec indrajaal-app curl http://indrajaal-db:5433` (should fail, but tests DNS).
    *   `T4.3`: **Health Check Test**: `mix container.health --detailed` must show all services as `HEALTHY`.
    *   `T4.4`: **Application Test**: `curl http://localhost:4000/health` must return `{"status":"healthy", ...}`.

### 3.5 Phase 5: Environment-Specific Functionality
*   **Objective**: Verify the unique characteristics of each environment profile.
*   **Supervisor**: Environment Supervisors.
*   **Tasks**:
    *   `T5.1 (Dev)`: Create a file on the host and verify it appears in the container within 1s (PHICS).
    *   `T5.2 (Test)`: Verify the database is using a "test" suffix and is isolated.
    *   `T5.3 (Demo)`: Verify specific seed data exists.
    *   `T5.4 (Prod)`: Verify the container is running as a non-root user.

---

## 4.0 Level 4: Detailed Test Cases & Instructions

### Test Case: `T3.2 - Binary Audit`
*   **Objective**: Prove the `indrajaal-app` image contains the mandated OTP 28 runtime.
*   **Supervisor**: Build Supervisor.
*   **Worker Action**:
    1.  Execute `podman build -f Dockerfile.sopv51-app ...`
    2.  Execute `podman run --rm --entrypoint /bin/sh localhost:5000/indrajaal-sopv51-elixir-app:nixos-devenv -c "elixir --version"`.
*   **Expected Output**: String containing `Erlang/OTP 28`.
*   **Failure Condition**: Output contains `OTP 27` or any other version; command fails.
*   **Implication (FMEA)**: Critical RPN. Failure leads to guaranteed runtime crash (FM-01).

### Test Case: `T4.2 - Connectivity Test`
*   **Objective**: Prove containers can resolve each other on the Podman bridge network.
*   **Supervisor**: Runtime Supervisor.
*   **Worker Action**:
    1.  Ensure `indrajaal-app` and `indrajaal-db` are running.
    2.  Execute `podman exec indrajaal-app ping -c 1 indrajaal-db`.
*   **Expected Output**: `1 packets transmitted, 1 received, 0% packet loss`.
*   **Failure Condition**: `Name or service not known` or `100% packet loss`.
*   **Implication (FMEA)**: High RPN. Application cannot connect to its database.

---

## 5.0 Level 5: Micro-Task Verification Logic

### Verification of `vto_orchestrator.exs` Health Check
*   **File**: `scripts/containers/vto_orchestrator.exs`
*   **Function**: `run_vto_loop/1` -> `Config.run_health_check_for/1`
*   **Micro-Task**:
    1.  The `run_health_check_for` function is called with `:postgres`.
    2.  It looks up the `:health_check` MFA `{Mod, Fun, Args}` in `Config.ex`.
    3.  It calls `System.cmd("podman", ["exec", "postgres", "pg_isready", ...])`.
    4.  The `retry_loop` function handles transient failures.
*   **Test Case**: `T4.1` is designed to validate this entire chain. We can even test the failure case by starting a broken DB container and ensuring the VTO orchestrator HALTS as designed.

---

## 6.0 Execution Strategy

To execute this plan comprehensively across all environments, use the master verification script.

### 6.1 Full Environment Verification
This script automates the sequential spin-up, verification, and tear-down of Dev, Test, Demo, and Prod environments.

```bash
elixir scripts/testing/ace_full_environment_verification.exs
```

**Workflow:**
1.  **Iterate**: Loops through `[:dev, :test, :demo, :prod]`.
2.  **Clean**: Ensures no conflicting containers exist.
3.  **Orchestrate**: Calls `vto_orchestrator.exs --action start`.
4.  **Verify**:
    *   Container existence (`podman ps`).
    *   Application liveness (`curl localhost:4000/health`).
    *   Environment variable correctness (`MIX_ENV`, `PHICS_ENABLED`).
5.  **Teardown**: Calls `vto_orchestrator.exs --action stop`.

---
**Signed**: Gemini (Cybernetic Architect)
**Status**: Ready for Execution