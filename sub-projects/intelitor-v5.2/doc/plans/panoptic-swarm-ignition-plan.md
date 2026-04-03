# Plan: Panoptic Swarm Ignition - F# Container Synthesis & Orchestration

**Created**: 20260328-1800 CEST
**Status**: DRAFT
**Framework**: SOPv5.11 + STAMP + Fractal Mesh Architecture

## Executive Summary
This plan details the implementation of "Panoptic Swarm Ignition," migrating all container declarative and generative configurations (e.g., Podman Compose YAML) into the `cepaf` F# codebase. It enforces strict mathematical checks during generation to prevent configuration drift or corruption. The F# orchestrator will be extended with Zenoh, MCP, Telemetry, OpenTelemetry (OTel), and Fractal Messaging capabilities to provide a high-fidelity dashboard of agent thinking and progress.

## 1.0 Step-by-Step Container Synthesis Process (Genetic Re-Synthesis)

The synthesis of the Elixir App and ALL Swarm containers will be programmatically handled in F# (`lib/cepaf/src/Cepaf.Config/ComposeGenerator.fs`).

1. **Phase 1: Environment Orientation & Type-Safe Configuration**
   - The F# system parses requested environments (Dev, Test, Prod, Mesh).
   - Strict Algebraic Data Types (ADTs) ensure configurations (Ports, Volumes, Network bindings) are mathematically proven to lack conflicts before generating text/YAML.
2. **Phase 2: Mathematical Safety Checking (Validation)**
   - Pre-flight F# properties validate resource allocations (RAM, CPU).
   - Port collisions, missing NIF/Musl mount paths, and volume shadowing rules (Axiom 0.2) are checked and blocked via F# compilation validation.
3. **Phase 3: Immutable Artifact Generation**
   - The validated ADTs are transformed into in-memory YAML DOMs, then serialized to disk.
   - Cryptographic hashes (BLAKE3) of the generated files are recorded in the Immutable Register.
4. **Phase 4: Zenoh-Powered Swarm Ignition**
   - Containers are launched transactionally using Podman API/CLI.
   - Progress is published in real-time over Zenoh topics (`indrajaal/ignition/progress`).

## 2.0 Architectural Control Checks per Layer

| Fractal Layer | Element | Enforced Check in F# Synthesis |
|---|---|---|
| **L7 Federation** | Mesh Topologies | Validates that node names resolve DNS/IPs (SC-NET-001). |
| **L6 Cluster** | Consensus Ports | Verifies EPMD (4369) and Dist ports (9100-9199) are open and exclusively mapped. |
| **L5 Node** | Resources | Enforces max core limits and checks `MIX_OS_DEPS_COMPILE_PARTITION_COUNT`. |
| **L4 Container** | Isolation / Setup | Validates `podman-compose-secure.yml` properties: rootless mode, read-only rootfs, `localhost/` registry. |
| **L3 Holon** | Data Sovereignty | Verifies SQLite/DuckDB volume mounts are not shadowed by host files (Axiom 0.2). |
| **L2 Component**| Services | Validates DB connection strings match injected secrets. |
| **L1 Atomic** | Execution | Checks `NO_TIMEOUT=true` and `PATIENT_MODE` env vars for compilation nodes. |

## 3.0 Extending `cepaf` (Zenoh, MCP, Telemetry, OTel)

1. **Zenoh Integration**: Embed the F# Zenoh client (`Cepaf.Cockpit.Avalonia/Services/ZenohSubscriber.fs`) into the daemon to broadcast state changes, ignition phases, and agent thinking steps.
2. **MCP (Model Context Protocol)**: Extend `Cepaf.Sentinel.MCP` to allow AI agents to securely query container states and propose repairs during synthesis failures.
3. **OpenTelemetry (OTel)**: Inject OTel spans directly from the F# orchestrator for every container lifecycle event (pull, create, start, healthcheck).
4. **Dashboard Fidelity**: Surface "Agent Thinking" strings in real-time via Zenoh streams to the Prajna LiveView and Avalonia GUI.

## 4.0 Safety, FEMA, and STAMP Analysis

### FEMA & Risk Assessment
| Component | Failure Mode | Severity | Probability | Risk (RPN) | F# Mitigation |
|---|---|---|---|---|---|
| Config Generator | Port Collision | High (8) | Medium (4) | 32 | F# ADT mathematically prevents duplicate port assignment. |
| Volume Mounter | Host Shadowing | Critical (10) | Low (3) | 30 | F# path resolution block checks target mounts (Axiom 0.2). |
| Ignition Engine | Partial Swarm Boot | High (9) | Medium (5) | 45 | DAG-based dependency resolution with rollback on failure. |

### STAMP / AOR Mappings
*   **SC-IGNITE-001**: F# Synthesis MUST perform step-by-step breakdown of container builds.
*   **SC-IGNITE-002**: Architectural control checks (L0-L7) MUST be enforced at every ignition stage.
*   **SC-IGNITE-003**: 7-Level Fractal RCA MUST be executed automatically on any boot failure.
*   **AOR-TRK-003**: F# Orchestrator SHALL strictly isolate all artifacts to `lib/cepaf/artifacts/`.

## 5.0 Implementation Plan (Risk & Criticality Based)

*   **Step 1 (Critical): Type-Safe YAML Generator**
    *   Update `Cepaf.Config.ComposeGenerator.fs` to model Podman definitions via strict F# types.
    *   Implement volume and port collision validations (Axiom 0.2).
*   **Step 2 (High): Telemetry & Zenoh Publisher**
    *   Integrate OTel tracing in `cepaf` daemon for container lifecycle events.
    *   Build Zenoh publisher to broadcast `[Thinking]` and `[Progress]` markers.
*   **Step 3 (Medium): Swarm Ignition Controller**
    *   Implement the DAG-based startup sequencer.
    *   Connect the F# health-check logic (`DualLayerHealthMonitor.fs`) to gate dependencies.
*   **Step 4 (Medium): MCP & Agentic Hooks**
    *   Expose MCP tools for the "Supervisor Agent" to read telemetry and trigger fractal RCAs when ignition halts.

## 6.0 Success Criteria
- ALL `docker-compose` and YAML generation is derived strictly from compiled, mathematically verified F# code.
- Swarm boots fully with 15 containers (App, DB, Obs, Zenoh Routers, Cortex, Bridge, Chaya, ML, Ollama) via `cepaf`.
- Progress and Agent thinking are visible in the Zenoh stream and dashboard.
