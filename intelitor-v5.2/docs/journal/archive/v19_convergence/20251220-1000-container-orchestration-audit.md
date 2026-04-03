# Container Orchestration Audit & System Artifact Analysis

**Date**: 2025-12-20
**Time**: 10:00 CEST
**Author**: Gemini Agent (SOPv5.11)
**Category**: Infrastructure Audit
**Status**: COMPLETE

## 1. Executive Summary

A comprehensive audit of the Indrajaal container orchestration infrastructure was conducted to map all `podman-compose*.yml` definitions to their consuming system artifacts. This audit verifies adherence to SOPv5.11, STAMP safety constraints, and the "Podman-Only" axiom. Six distinct orchestration files were analyzed, covering development, security, testing, clustering, and observability.

## 2. Orchestration File Analysis

### 2.1 `podman-compose.yml` (The Core Standard)
**Purpose**: The central, authoritative orchestration manifest for the standard Indrajaal demo environment.
**Key Features**:
- **Services (6)**: `postgres` (TimescaleDB), `redis`, `app` (Phoenix), `prometheus`, `grafana`, `nginx`.
- **Security**: Enforces `localhost/` registry (SC-CNT-010), rootless execution (SC-CNT-012).
- **Dev features**: PHICS hot-reloading (<50ms latency), local volume mounts for build artifacts.
- **Networking**: Defines `indrajaal-app` bridge network.

**Referencing System Artifacts & Operations**:
- **Validation Scripts**:
    - `scripts/validation/container_configuration_validator.exs`: Parses the file to validate structure and existence.
    - `scripts/pcis/container_phics_validator.exs`: Checks specifically for PHICS environment variables and volume mounts.
    - `scripts/protection/container_config_guardian.exs`: Monitors file integrity to prevent unauthorized changes.
- **Demo Executors**:
    - `scripts/demo/performance_monitoring_demo_executor.exs`: Executes `podman-compose up` to provision the environment for performance demos.
    - `scripts/demo/comprehensive_containerized_demo_executor.exs`: Verifies file presence before running comprehensive demos.
- **Documentation**:
    - `CLAUDE.md` / `GEMINI.md`: Referenced as the mandatory standard (Axiom 2).
    - `README.md`: Provided as the primary startup instruction.

### 2.2 `podman-compose-secure.yml` (The Hardened Baseline)
**Purpose**: A security-hardened variant for production-like environments, implementing strict least-privilege principles.
**Key Features**:
- **Read-Only Root**: Filesystems mounted read-only where possible.
- **Cap Drop**: `cap_drop: ["ALL"]` with explicit allow-listing (e.g., `NET_BIND_SERVICE`).
- **Resource Limits**: Strict CPU/RAM limits per STAMP ContainerAllocation.
- **Network Isolation**: Uses `indrajaal-net` with explicit subnetting.

**Referencing System Artifacts & Operations**:
- **Security Documentation**:
    - `docs/security/container-security-implementation.md`: Documents this file as the reference implementation for hardened orchestration.
- **Journal Logs**:
    - `journal/20251219-gde-p0-p1-completion-session.md`: Logs the execution of this file during security verification sessions.

### 2.3 `podman-compose-testing.yml` (The HA Testbed)
**Purpose**: A High-Availability (HA) environment for integration and chaos testing.
**Key Features**:
- **Clustering**: 3 Application nodes (`app-1`, `app-2`, `app-3`) forming an Erlang cluster.
- **Database HA**: Primary (`db-primary`) and Replica (`db-replica`) databases.
- **Test Runner**: A dedicated `indrajaal-test-runner` container for executing in-network tests.

**Referencing System Artifacts & Operations**:
- **Test Executors**:
    - `scripts/testing/chaos-test.sh`: Uses this file to spin up the cluster before injecting faults (node kills).
- **Architecture Docs**:
    - `docs/container-architecture.md`: References this file to demonstrate SC-CNT-010 compliance in clustered setups.
    - `docs/architecture/container-multi-mode-architecture.md`: Details the addition of the `indrajaal-test-runner` service.

### 2.4 `podman-compose-3container.yml` (The Dev Standard)
**Purpose**: Implements the "3-Container Architecture" (App, DB, Obs) using sidecars for efficiency, optimized for developer workstations.
**Key Features**:
- **Pod Pattern**: Groups related services (e.g., App+Redis+Nginx, Obs+Grafana+Otel) into single network namespaces.
- **Tailscale Integration**: References `${TS_HOSTNAME}` for identity-based networking.

**Referencing System Artifacts & Operations**:
- **Architecture Specs**:
    - `docs/architecture/three-container-dev-architecture.md`: The primary definition document for this architecture.
    - `docs/architecture/level-2-container-architecture.md`: Lists this file as the development compose standard.
- **Configuration**:
    - `.claude/settings.local.json`: Configured as a recognized bash command target.

### 2.5 `podman-compose-cluster.yml` (The Mesh Cluster)
**Purpose**: Dedicated orchestration for testing Erlang distribution over Tailscale Mesh DNS.
**Key Features**:
- **Mesh Networking**: Configures `ERL_EPMD_ADDRESS` to bind to Tailscale IPs.
- **DNS Discovery**: Uses `Cluster.Strategy.Kubernetes.DNS` (simulated via Tailscale MagicDNS).

**Referencing System Artifacts & Operations**:
- **Integration Guides**:
    - `docs/architecture/tailscale-dns-integration-guide.md`: Uses this file to demonstrate setting up a mesh-connected cluster.
- **Journals**:
    - `journal/20251219-0030-tailscale-dns-host-alignment.md`: Logs the creation and alignment of this file with DNS settings.

### 2.6 `podman-compose.observability.yml` (The SigNoz Stack)
**Purpose**: Deploys the comprehensive SigNoz observability stack (ClickHouse, Query, Frontend, Otel).
**Key Features**:
- **ClickHouse**: Optimized configuration for high-ingest telemetry.
- **Initialization**: Includes a `signoz-init` service to provision schemas.

**Referencing System Artifacts & Operations**:
- **Deployment Scripts**:
    - `scripts/observability/deploy_signoz.exs`: Automatically runs `podman-compose -f ... up -d` to deploy the stack.
    - `scripts/observability/test_telemetry_export.exs`: Verifies the stack is running by checking `ps` output on this file.
    - `scripts/observability/test_observability_in_containers.exs`: Uses it to validate container metrics collection.

## 3. Conclusion

The Indrajaal system maintains a robust, modular container orchestration strategy. 
- **`podman-compose.yml`** remains the "Gold Standard" for general usage.
- **Specialized variants** exist for Security (`-secure`), HA Testing (`-testing`), and Dev Efficiency (`-3container`).
- **Automation is high**: Scripts explicitly reference these files to automate validation, deployment, and testing, minimizing manual error.
- **Safety is enforced**: All files adhere to the strict `localhost/` registry policy and rootless execution requirements.
