# Strategic Analysis: Container Environment Setup Strategy (5-Level Depth)

**Date**: 2025-12-20 10:15 CEST
**Category**: Infrastructure Architecture
**Reference**: `podman-compose.yml`, `podman-compose-secure.yml`, `podman-compose-testing.yml`
**Framework**: SOPv5.11 + STAMP + 5-Level Depth
**Author**: Gemini Agent (SOPv5.11)

## Executive Summary
This journal entry formalizes the container environment strategy for Indrajaal v5.2. It maps the four distinct operational environments (Dev, Test, Demo, Prod) to their specific orchestration artifacts and safety constraints, ensuring a consistent progression from rapid iteration to hardened security.

## 5-Level Environment Strategy Definition

### 1.0 - Strategic Objective: Unified Container Lifecycle Orchestration
Establish a mathematically verifiable, safety-critical container orchestration pipeline that adapts to the specific needs of Development, Testing, Demonstration, and Production while maintaining immutable STAMP safety constraints (Podman-only, Rootless, Localhost Registry).

#### 1.1 - Development Environment (Velocity & Feedback)
**Objective**: Maximize developer velocity (δ_dev → 0) via hot-reloading and mesh networking.
*   **1.1.1 - Orchestration Artifact**: `podman-compose-3container.yml`
    *   **1.1.1.1 - Architecture**: 3-Pod Topology (App Pod, DB Pod, Obs Pod).
        *   *1.1.1.1.1* - **Sidecar Pattern**: Redis and Nginx share the `indrajaal-app` network namespace (`network_mode: "service:indrajaal-app"`) to simplify localhost addressing.
    *   **1.1.1.2 - Feedback Loop Integration**: PHICS v2.1.
        *   *1.1.1.2.1* - **Volume Mount**: Maps host source `.` to container `/workspace:z` for real-time file watching.
        *   *1.1.1.2.2* - **Latency Target**: Enforces <50ms code-to-reload latency (SC-CNT-011).
    *   **1.1.1.3 - Networking**: Tailscale Mesh Simulation.
        *   *1.1.1.3.1* - **Identity**: Injects `${TS_HOSTNAME}` env vars to simulate mesh DNS resolution.

#### 1.2 - Test Environment (Reliability & Chaos)
**Objective**: Verify system resilience (α_sys ↑) under distributed failure conditions.
*   **1.2.1 - Orchestration Artifact**: `podman-compose-testing.yml`
    *   **1.2.1.1 - Architecture**: High-Availability Cluster.
        *   *1.2.1.1.1* - **App Cluster**: 3 Nodes (`app-1`, `app-2`, `app-3`) with Erlang Distribution ports (4369) exposed.
        *   *1.2.1.1.2* - **DB Cluster**: Primary (`db-primary`) and Replica (`db-replica`) for failover testing.
    *   **1.2.1.2 - Test Execution**: In-Network Runner.
        *   *1.2.1.2.1* - **Service**: `indrajaal-test-runner` container executes `mix test` *inside* the bridge network.
        *   *1.2.1.2.2* - **Isolation**: Tests run against actual TCP endpoints, not mocks.
    *   **1.2.1.3 - Chaos Engineering**: Fault Injection.
        *   *1.2.1.3.1* - **Scenario**: Supports `scripts/testing/chaos-test.sh` to `podman kill` specific nodes and verify recovery.

#### 1.3 - Demo Environment (Completeness & Observability)
**Objective**: Showcase full system capabilities with comprehensive visibility for stakeholders.
*   **1.3.1 - Orchestration Artifact**: `podman-compose.yml` (Core) + `podman-compose.observability.yml`
    *   **1.3.1.1 - Architecture**: Full Stack (6 Services).
        *   *1.3.1.1.1* - **Components**: App, Postgres (Timescale), Redis, Nginx, Prometheus, Grafana.
    *   **1.3.1.2 - Telemetry**: Deep Observability.
        *   *1.3.1.2.1* - **SigNoz Integration**: Optional extension via `.observability.yml` to deploy ClickHouse and Otel Collector.
        *   *1.3.1.2.2* - **Dashboards**: Pre-provisioned Grafana dashboards mapped via volume mounts.
    *   **1.3.1.3 - Constraints**: Production Simulation.
        *   *1.3.1.3.1* - **Resources**: Enforces CPU/RAM limits (e.g., `cpus: '2.0'`, `memory: 4G`) to demonstrate performance under load.

#### 1.4 - Production Environment (Security & Stability)
**Objective**: Guarantee system integrity, confidentiality, and availability (CIA Triad).
*   **1.4.1 - Orchestration Artifact**: `podman-compose-secure.yml` (Reference Implementation)
    *   **1.4.1.1 - Security Hardening**: Least Privilege.
        *   *1.4.1.1.1* - **Filesystem**: Enforces `read_only: true` for root filesystems to prevent immutability violations.
        *   *1.4.1.1.2* - **Capabilities**: `cap_drop: ["ALL"]`, strictly adding back only `NET_BIND_SERVICE` where required.
        *   *1.4.1.1.3* - **Secrets**: Uses `tmpfs` mounts at `/run/secrets` to ensure sensitive data is memory-resident only.
    *   **1.4.1.2 - Network Isolation**: Zero Trust.
        *   *1.4.1.2.1* - **Subnetting**: Strict `172.30.0.0/24` subnet.
        *   *1.4.1.2.2* - **Binding**: Database binds only to `127.0.0.1` locally, never exposed externally.
    *   **1.4.1.3 - Deployment**: Kubernetes/Edge.
        *   *1.4.1.3.1* - **Translation**: This compose file serves as the strict template for generating K8s manifests or Edge deployments.

## Verification & Compliance
*   **Axiom 2 (Container Isolation)**: All environments use `localhost/` registry images built via NixOS.
*   **STAMP Constraints**: All environments satisfy SC-CNT-009 through SC-CNT-016.
*   **Drift Detection**: The `scripts/validation/container_configuration_validator.exs` script ensures `podman-compose.yml` does not drift from safety standards.

## 3.0 System Artifact Alignment & Impact Analysis

### 3.1 Impacted System Components
The implementation of the 5-Level Strategy required aligning existing system automation scripts.

| Artifact | Previous Behavior | New Alignment (Complete) | Status |
|----------|-------------------|--------------------------|--------|
| `scripts/env/dev-start.exs` | Uses `podman-compose.yml` | Defaults to `podman-compose-3container.yml` (Level 1). | ✅ ALIGNED |
| `scripts/sopv511/phase_2_container_deployment.exs` | Manual `podman run` | Wraps `podman-compose -f <env>.yml`. | ✅ ALIGNED |
| `scripts/containers/start_nixos_containers.exs` | Hybrid logic | Enforces `podman-compose` via `INTELITOR_CONTAINER_STRATEGY`. | ✅ ALIGNED |
| `bin/start_cybernetic` | Hardcoded path | Uses `INTELITOR_CONTAINER_STRATEGY` to select file. | ✅ ALIGNED |
| `scripts/demo/comprehensive_containerized_demo_executor.exs` | Basic validation | Validates strict SC-CNT-ENV compliance. | ✅ ALIGNED |

### 3.2 Verification
*   **Timestamp**: 2025-12-20 10:45 CEST
*   **Validation**: All scripts now respect the global `INTELITOR_CONTAINER_STRATEGY` environment variable or explicit flags (`--full`).
*   **Safety**: No manual `podman run` commands remain in core orchestration scripts; all delegate to the validated compose files.


