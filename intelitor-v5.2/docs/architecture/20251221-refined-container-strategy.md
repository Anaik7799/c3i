# Refined Container Strategy: Verify-Then-Orchestrate

**Date**: 20251221-1100 CEST
**Status**: Adopted
**Framework**: SOPv5.11 + TPS (Jidoka)

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20251221-1100 CEST | CREATED | Initial strategy document | Gemini |

## 1.0 Executive Summary (Level 1)

This document outlines a refined, more robust strategy for containerized environment setup. The previous monolithic approach, which attempted to build and orchestrate all services simultaneously, proved brittle and difficult to debug. The new "Verify-Then-Orchestrate" strategy mandates that each containerized service is started and validated in isolation *before* attempting full orchestration. This follows the Jidoka principle of stopping to fix problems at the source, ensuring each component is sound before integrating it into the whole.

### 2.0 Core Principles (Level 2)

#### 2.1 Single Source of Truth
All container configurations—including service names, image tags, ports, volumes, and health checks—are canonically defined in `lib/indrajaal/deployment/config.ex`. This is the master configuration file.

#### 2.2 Individual Service Verification
No service may be started as part of an orchestrated environment until it has been successfully started and validated in isolation. This isolates failures and dramatically simplifies debugging.

#### 2.3 Dependency-Aware Staging
Services will be brought online sequentially, following the `dependency_order` defined in the configuration module, allowing dependent services to be tested against live, validated dependencies.

### 3.0 Verification Workflow (Level 3)

The workflow proceeds in discrete, verifiable stages. A failure at any stage triggers a root cause analysis for that specific component only.

#### 3.1 Stage 1: Database (Postgres)
- **Action**: Start the `postgres` container in isolation on the `indrajaal-network`.
- **Validation**: Run the `health_check_database` function until it passes.
- **Success Criteria**: Container is running and accepting connections.

#### 3.2 Stage 2: Cache (Redis)
- **Action**: Start the `redis` container in isolation on the `indrajaal-network`.
- **Validation**: Run the `health_check_redis` function until it passes.
- **Success Criteria**: Container is running and responds with `PONG`.

#### 3.3 Stage 3: Application (App)
- **Action**: Start the `app` container, connected to the network with the live `postgres` and `redis` containers.
- **Validation**: Run the `health_check_app` function until it passes.
- **Success Criteria**: Container is running and the Phoenix health endpoint is responsive.

### 4.0 Detailed Task Breakdown (Level 4)

#### 4.1.1 Stop and Clean Environment
- **Task**: Run `podman stop` and `podman rm` on all project containers.
- **Verification**: `podman ps -a` shows no running or exited containers for this project.

#### 4.1.2 Create Network
- **Task**: Execute `podman network create indrajaal-network`.
- **Verification**: `podman network ls` shows the network exists.

#### 4.1.3 Start and Verify Postgres
- **Task**: Use `podman run` with parameters from `Indrajaal.Deployment.Config` for the `:postgres` service.
- **Verification**: `podman logs postgres` shows no startup errors. `pg_isready` health check passes.

### 5.0 Micro-tasks for Postgres Verification (Level 5)

- **5.1.3.1**: Construct `podman run` command for `postgres` from the canonical config.
- **5.1.3.2**: Execute the command.
- **5.1.3.3**: Wait 10 seconds for initialization.
- **5.1.3.4**: Check `podman ps -a` to ensure the container is in a `running` state.
- **5.1.3.5**: If not running, immediately execute `podman logs postgres` to capture the exit error.
- **5.1.3.6**: If running, execute the health check from `Indrajaal.Deployment.Config` in a loop until it passes or times out.
- **5.1.3.7**: Do not proceed until the health check passes.
