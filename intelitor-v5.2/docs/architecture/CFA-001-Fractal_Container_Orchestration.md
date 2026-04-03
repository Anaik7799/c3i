# CFA-001: Fractal Container Orchestration & Verification

**ID**: CFA-001
**Title**: Fractal Container Orchestration & Verification
**Date**: 20251221-1420 CEST
**Status**: Adopted (Replaces all previous ad-hoc strategies)
**Framework**: SOPv5.11, Cybernetic Architect Framework (CAF), OODA, Jidoka, PHICS

## Change Log
| Timestamp | Change Type | Description | Author |
|---|---|---|---|
| 20251221-1420 CEST | CREATED | Initial formalization of the Verify-Then-Orchestrate strategy, incorporating 5-level RCA, risk analysis, and explicit developer instructions. | Gemini |

---

## 1.0 Philosophy: The "Verify-Then-Orchestrate" (VTO) Protocol

This protocol is the mandated process for creating and managing the application's containerized environment. Its creation was necessitated by systemic, difficult-to-debug failures in previous monolithic startup scripts.

### 1.1 The Problem (5-Level Root Cause Analysis)

A 5-Level RCA revealed the fundamental issue with our prior "all-at-once" approach:

- **Level 1 (Symptom):** The full system (`podman-compose up`) fails to start; specifically, the `app` container enters a crash loop.
- **Level 2 (Proximate Cause):** The `app` container fails during `mix deps.get`, citing an SSL/TLS error (`:pubkey_os_cacerts.conv_error_reason(:no_cacerts_found)`), preventing it from fetching Hex packages.
- **Level 3 (Contributing Factor):** The container's sandboxed environment, created by Nix and run by Podman, has an inconsistent and unreliable mechanism for locating the system's SSL certificate bundle. Attempts to fix this at the infrastructure layer (e.g., via environment variables, Nix package installation) were not consistently effective.
- **Level 4 (Systemic Issue):** The previous monolithic startup scripts violated the **Jidoka** principle ("automation with a human touch"). By attempting to build and run everything in one step, they hid the root cause of individual component failures, leading to long, confusing, and expensive debugging cycles. We could not distinguish a networking failure from a build failure or a runtime failure.
- **Level 5 (Root Cause):** **The system lacked verifiable, independent component health checks before system integration.** We were building a complex machine without ever testing if the individual gears worked.

### 1.2 The Solution: VTO as an OODA Loop

The VTO protocol solves this root cause by treating each service as a distinct component that must be proven healthy before it can be integrated. This is a direct implementation of the **OODA Loop**:

1.  **OBSERVE:** Start a single service in isolation.
2.  **ORIENT:** Run a deterministic, contract-mandated health check.
3.  **DECIDE:** Is the service healthy?
4.  **ACT:** If yes, certify it and proceed. If no, halt the entire sequence and enter a debug micro-loop for that specific component.

This approach is **fractal**: the same OODA loop used to verify the `postgres` container is used to verify the `app` container, and the successful execution of all individual loops is what verifies the health of the system as a whole.

---

## 2.0 The Canonical Configuration: The System Genome (Level 2)

The VTO protocol is governed by a **Single Source of Truth (SSoT)**, which acts as the "genome" for our entire container ecosystem.

**Location:** `lib/indrajaal/deployment/config.ex`

This module defines a **Service Contract** for every container. It is not just configuration; it is an executable specification.

| Key | Type | Purpose | Example |
|---|---|---|---|
| `:service_name` | `atom` | Unique network identifier. | `:app` |
| `:image_name` | `string`| The name for the built artifact. | `"localhost/indrajaal-app"`|
| `:dependency_order`| `integer`| Position in the startup DAG. | `3` |
| **`:health_check`**| `mfa` | **Executable Contract.** A function pointer `{Module, :function, [args]}` that returns `:ok` or `{:error, reason}`. | `HealthChecks.app_health_check/0`|
| `:nix_file` | `string` | Path to the Nix definition for the image. | `"containers/app.nix"`|

> **RISK ANALYSIS (HIGH):** Manual modification of the SSoT (`config.ex`).
>
> **MITIGATION (AOR-CFG-001):** Any change to this file **requires** a developer to re-run the compose file generator (`elixir scripts/deployment/generate_compose.exs`) and perform a full VTO cycle from a clean slate. This ensures system-wide consistency is maintained.

---

## 3.0 The Fractal Workflow: Verifying a Single Service (Level 3)

This is the core, repeatable pattern of the VTO protocol. For any service `S` defined in the SSoT:

1.  **Preparation:** Ensure a clean environment. The target container `S` and any containers that depend on it must not be running. The shared network (`indrajaal-network`) must exist.
2.  **ACTION (Observe):** Construct and execute a `podman run` command *solely* from the attributes defined for `S` in the SSoT. Do not add or change parameters. This enforces the contract.
3.  **VERIFICATION (Orient):**
    a. Wait an appropriate time for initialization (e.g., 15s for Postgres, 120s for Elixir compilation).
    b. Check the process status: `podman ps -a --format "{{.Names}}: {{.Status}}"`
    c. If "Up", execute the health check: `elixir -e 'Indrajaal.Deployment.Config.run_health_check_for(:S)'`
4.  **CERTIFICATION (Decide & Act):**
    a. If the health check returns `:ok`, the service is **Certified**. Log this and proceed.
    b. If the container `Exited` or the health check returns `{:error, ...}`, the system **HALTS**. Enter the debug loop:
        i.   `podman logs <service_name>` -> Isolate the error.
        ii.  Modify the corresponding `.nix` file or Elixir code to fix it.
        iii. `elixir scripts/containers/build_nixos_containers.exs` -> Rebuild the image.
        iv.  `podman rm -f <service_name>` -> Reset the component's state.
        v.   Return to Step 2.

---

## 4.0 The Macro Sequence: SOPv5.11 System Ignition (Level 4)

This sequence applies the VTO fractal to the entire system in the mandated dependency order.

1.  **Phase 1: Environment Setup**
    - `podman rm -f $(podman ps -a -q) || true` (Jidoka: Stop the line)
    - `podman network create indrajaal-network || true` (Create the work area)
    - `elixir scripts/containers/build_nixos_containers.exs` (Build all components)

2.  **Phase 2: Staged & Verified Service Ignition (VTO Execution)**
    - **Certify `postgres` (Order 1):** Execute VTO fractal.
    - **Certify `redis` (Order 2):** Execute VTO fractal.
    - **Certify `app` (Order 3):** Execute VTO fractal.

3.  **Phase 3: Orchestration & PHICS Integration**
    - **Halt Individual Containers:** `podman stop postgres redis app`
    - **Generate Compose File:** `elixir scripts/deployment/generate_compose.exs`
    - **Full System Start:** `podman-compose up -d`
    - **Final Verification:** Check that all three containers are healthy.
    - **PHICS Usage:** The environment is now stable. Development with live-reloading via mounted volumes can now safely begin.

> **RISK ANALYSIS (CRITICAL):** Bypassing the individual verification steps and running `podman-compose up -d` directly.
>
> **MITIGATION (AOR-VTO-001):** This is a critical violation of the VTO protocol. The entire purpose of this framework is to prevent the confusing, compound failures that arise from this exact action. The process is now the official standard of practice.

---

## 5.0 Developer Usage Instructions & Commands (Level 5)

This framework supports two distinct operational modes, each with a dedicated compose file.

### 5.1 Mode 1: Hybrid Development (Recommended for Coding)

In this mode, the `app` runs directly on the host for rapid iteration and debugging, while backing services (`postgres`, `redis`) run in containers. This is the fastest and most common workflow.

**Compose File:** `podman-compose.dev.yml`

```bash
# STEP 1: Clean Slate & Network Setup
podman-compose -f podman-compose.dev.yml down
podman network create indrajaal-network || true

# STEP 2: Start Services
# This starts only postgres and redis.
podman-compose -f podman-compose.dev.yml up -d

# STEP 3: Verify Services
echo "Waiting for services to initialize..."
sleep 15
podman exec postgres pg_isready -U postgres -p 5433 # Expected: "... accepting connections"
podman exec redis redis-cli ping # Expected: PONG
echo "✅ Backend services are ready."

# STEP 4: Run App on Host
# The application connects to the container services via localhost ports.
mix phx.server
```

### 5.2 Mode 2: Full Containerization (for Testing & Demos)

In this mode, all services, including the `app`, run inside containers. This perfectly mirrors the production environment and is ideal for integration testing or demos. This requires that all individual components have been certified via the VTO process.

**Compose File:** `podman-compose.yml`

```bash
# STEP 1: Generate the Full Compose File
elixir scripts/deployment/generate_compose.exs

# STEP 2: Start All Services
podman-compose -f podman-compose.yml up -d

# STEP 3: Verify Full System Health
echo "Waiting 120s for app compilation..."
sleep 120
podman ps -a --format "{{.Names}}: {{.Status}}"
curl -sf --connect-timeout 5 http://localhost:4000/health # Expected: "OK"
echo "✅ Full system is up and running."
```

#### 5.3 Debugging a Failed Stage (Jidoka Cycle)
If any `podman-compose` command fails, **do not proceed**. Revert to the single-service verification pattern from Section 3.0:
1.  `podman logs <failed_container_name>` -> Observe the error.
2.  `vim containers/<service>.nix` -> Decide on a fix.
3.  `elixir scripts/containers/build_nixos_containers.exs` -> Act by rebuilding.
4.  `podman rm <failed_container_name>` -> Reset the component's state.
5.  Re-run the single `podman run ...` command for that service until it is Certified. Only then, return to the `podman-compose` workflow.