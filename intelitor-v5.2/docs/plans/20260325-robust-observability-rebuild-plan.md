# Comprehensive Plan: Robust NixOS Observability Container & F# Lifecycle Supervisor

**Created**: 20260325-1200 CEST
**Status**: ACTIVE
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA) + SC-CNT-009

## Executive Summary
The `indrajaal-obs-prod` container is currently unhealthy because it relies on a broken NixOS skeleton image (`sleep infinity`). To achieve SIL-6 biomorphic integration and comply with SC-CNT-009 (NixOS-only environments), this plan completely rebuilds the container using a strict, declarative `flake.nix` (leveraging `dockerTools.buildLayeredImage`). 

Crucially, an F# Agent (`.NET 10.0`) will be engineered to act as the primary container supervisor. Running under a lightweight init (`tini`) to handle zombie reaping, the F# Agent will boot before any observability services. It will establish native Zenoh mesh connectivity, expose Model Context Protocol (MCP) endpoints, and autonomously manage the lifecycles of Prometheus, Grafana, ClickHouse, and OpenTelemetry. 

## Detailed Architectural Analysis for Robustness

### 1. PID 1 & Signal Handling
- **Challenge**: If an F# application runs directly as PID 1, it must handle OS signal propagation (SIGTERM/SIGINT) and reap zombie child processes (Prometheus, Grafana, etc.). Failure to do so leads to resource exhaustion and ungraceful shutdowns.
- **Robust Solution**: Use `tini` (provided via Nixpkgs) as the absolute PID 1. `tini` will spawn the F# Agent, guaranteeing proper zombie reaping and signal forwarding. The F# Agent will catch `SIGTERM` and orchestrate a graceful shutdown of its managed child services.

### 2. The F# Supervisor (Cepaf.ObsSupervisor)
- **Role**: Replaces `start-obs.sh` with a fully typed, stateful `MailboxProcessor` actor system.
- **Responsibilities**:
  - Spawn processes: `prometheus`, `grafana-server`, `clickhouse-server`, `otelcol`.
  - Monitor process exits and implement exponential backoff restarts.
  - Expose a unified `/health` endpoint for the `podman` healthcheck, aggregating the status of all managed services.
- **Runtime**: `.NET 10.0` (mandated by SC-NET-001).

### 3. Mesh Connectivity (Zenoh + MCP)
- **Zenoh FFI**: The Nix build must compile or include `libzenoh_ffi.so`. The F# agent will bind to this library to publish health telemetry (`indrajaal/obs/health`) and listen for control plane commands (e.g., `indrajaal/obs/cmd/restart`).
- **MCP Server**: The agent will embed an MCP server exposing tools (`obs_status`, `obs_restart_service`, `obs_read_service_log`) allowing Gemini/Claude direct introspective capabilities into the observability stack without needing bash access.

### 4. Pure NixOS Build Pipeline
- **Mechanism**: A dedicated `containers/obs/flake.nix`.
- **Contents**: It will define a derivation that compiles the F# Agent and packages it alongside Prometheus, Grafana, ClickHouse, OTEL, and `tini` into a layered OCI image. No Dockerfiles will be used.

## 5-Level Execution Plan

### 1.0 - Pure NixOS Container & F# Supervisor Rebuild (P0)
#### 1.1 - Pure NixOS Image Architecture (P0)
##### 1.1.1 - Define Observability Flake (`containers/obs/flake.nix`) (P0)
###### 1.1.1.1 - Package Resolutions & Derivations (P0)
- 1.1.1.1.1 - Import `nixpkgs` and specify dependencies: `tini`, `prometheus`, `grafana`, `clickhouse`, `opentelemetry-collector`, `dotnet-sdk_10`, `rustc`, `cargo` (for Zenoh FFI).
- 1.1.1.1.2 - Define a derivation to compile the `Cepaf.ObsSupervisor` F# project during the Nix build phase.
###### 1.1.1.2 - OCI Image Generation (P0)
- 1.1.1.2.1 - Use `pkgs.dockerTools.buildLayeredImage`.
- 1.1.1.2.2 - Configure the image `config` block: `Entrypoint = ["/bin/tini", "--", "/bin/Cepaf.ObsSupervisor"]`.

#### 1.2 - F# Supervisor (Cepaf.ObsSupervisor) Implementation (P0)
##### 1.2.1 - Core Actor & Process Management (P0)
###### 1.2.1.1 - `ProcessManager.fs` MailboxProcessor (P0)
- 1.2.1.1.1 - Implement standard `System.Diagnostics.Process` spawners with redirected standard streams (capturing stdout/stderr).
- 1.2.1.1.2 - Implement crash detection and exponential backoff retry logic for each specific service.
###### 1.2.1.2 - Graceful Teardown Hooks (P0)
- 1.2.1.2.1 - Handle `Console.CancelKeyPress` and `AppDomain.CurrentDomain.ProcessExit`.
- 1.2.1.2.2 - Ensure graceful `SIGTERM` transmission to child processes before the F# agent exits.

#### 1.3 - Zenoh Mesh & MCP Integration (P0)
##### 1.3.1 - Zenoh Native FFI Bridge (P0)
###### 1.3.1.1 - P/Invoke Setup & Telemetry Loop (P0)
- 1.3.1.1.1 - Map `libzenoh_ffi` functions in F#.
- 1.3.1.1.2 - Implement a background loop publishing a JSON payload to `indrajaal/obs/telemetry/heartbeat` every 5 seconds.
##### 1.3.2 - Embedded MCP Server (P1)
###### 1.3.2.1 - Expose Management Tools (P1)
- 1.3.2.1.1 - Implement HTTP-based MCP endpoints: `tools/list` and `tools/call`.
- 1.3.2.1.2 - Define tools: `obs_service_status`, `obs_restart_service`, `obs_read_service_log`.

#### 1.4 - System Integration & Rollout (P0)
##### 1.4.1 - Local Image Registration (P0)
###### 1.4.1.1 - Nix Build to Podman Load (P0)
- 1.4.1.1.1 - Run `nix build .#obsContainer`.
- 1.4.1.1.2 - Pipe result to `podman load` and tag as `localhost/indrajaal-obs-unified:nixos-native`.
##### 1.4.2 - Compose & Configuration Updates (P0)
###### 1.4.2.1 - Update `podman-compose-sil6-full-mesh.yml` (P0)
- 1.4.2.1.1 - Change `indrajaal-obs-prod` image reference.
- 1.4.2.1.2 - Update the `healthcheck` to query the F# Supervisor's unified `/health` endpoint instead of individual services.

#### 1.5 - Validation & Verification (P0)
##### 1.5.1 - SIL-6 & STAMP Compliance Verification (P0)
###### 1.5.1.1 - Container & Mesh Health Checks (P0)
- 1.5.1.1.1 - Verify `podman ps` reports healthy.
- 1.5.1.1.2 - Verify Zenoh pub/sub connectivity by subscribing to `indrajaal/obs/health` via `zenoh_sub`.
- 1.5.1.1.3 - Test graceful shutdown (`podman stop indrajaal-obs-prod`) and verify no orphaned processes remain.

## FMEA Risk Analysis
| Failure Mode | Effect | Severity | Detection | RPN | Mitigation |
|--------------|--------|----------|-----------|-----|------------|
| F# Agent crashes | Container exits, services die | 9 | 9 | 81 | `tini` as PID 1, robust try/catch at F# main loop. |
| Zenoh FFI linkage fails | Agent cannot connect to mesh | 8 | 8 | 64 | Nix derivation explicitly sets `LD_LIBRARY_PATH` / `rpath`. |
| Out of Memory (OOM) | Container killed by kernel | 8 | 5 | 40 | Proper resource limits in Podman compose, ClickHouse tuning. |
| Zombie processes accumulate | Container hangs | 7 | 6 | 42 | `tini` completely mitigates zombie accumulation. |
