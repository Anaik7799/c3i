# Plan: Observability Container Rebuild & F# Supervisor Integration

**Created**: 20260325-1154 CEST
**Last Updated**: 20260325-1154 CEST
**Status**: DRAFT
**Framework**: SOPv5.11 + TPS (Jidoka + 5-Level RCA)

## Change Log
| Timestamp | Change Type | Description | Author |
|-----------|-------------|-------------|--------|
| 20260325-1154 CEST | CREATED | Initial plan creation | Cybernetic Architect |

## Executive Summary
The current `indrajaal-obs-prod` container is failing health checks due to relying on a broken skeleton image (`sleep infinity` entrypoint). Furthermore, its architecture lacks native, SIL-6 biomorphic integration. This plan details the complete rebuild of the observability container utilizing a strict NixOS declarative base. An F# Agent (`.NET 10.0`) will be introduced as the primary PID 1 supervisor. This agent will establish Zenoh and MCP connectivity immediately at boot and will natively monitor, manage, and report on the lifecycle of all embedded observability services (Prometheus, Grafana, ClickHouse, OTEL).

## 5-Level Detailed Plan

### 1.0 - Observability Container Rebuild & F# Supervision Integration (Priority: P0)
#### 1.1 - NixOS Base Image Construction (Priority: P0)
##### 1.1.1 - Declarative NixOS Environment Setup (Priority: P0)
###### 1.1.1.1 - Create `flake.nix` for Observability Container (Priority: P0)
- 1.1.1.1.1 - Define Nix packages: `prometheus`, `grafana`, `clickhouse`, `opentelemetry-collector`, `dotnet-sdk_10` (Priority: P0)
- 1.1.1.1.2 - Define container networking and port exposures in Nix configuration (Priority: P0)
###### 1.1.1.2 - Build Rootless OCI Image (Priority: P0)
- 1.1.1.2.1 - Implement NixOS `dockerTools.buildImage` or `pkgs.dockerTools.buildLayeredImage` script (Priority: P0)
- 1.1.1.2.2 - Verify image builds locally via `nix build` (Priority: P0)

#### 1.2 - F# Supervisor Agent Development (Priority: P0)
##### 1.2.1 - Bootstrapper Project Creation (Priority: P0)
###### 1.2.1.1 - Initialize `.NET 10.0` Console App (Priority: P0)
- 1.2.1.1.1 - Run `dotnet new console -lang F# -n Cepaf.ObsSupervisor` (Priority: P0)
- 1.2.1.1.2 - Target `net10.0` in `.fsproj` (SC-NET-001) (Priority: P0)
###### 1.2.1.2 - Service Lifecycle Management Implementation (Priority: P0)
- 1.2.1.2.1 - Implement F# `System.Diagnostics.Process` wrappers for OTEL, Prometheus, Grafana, ClickHouse (Priority: P0)
- 1.2.1.2.2 - Implement restart policies and exponential backoff on service crash (Priority: P0)

#### 1.3 - Zenoh and MCP Connectivity (Priority: P0)
##### 1.3.1 - Zenoh NIF/FFI Integration (Priority: P0)
###### 1.3.1.1 - Link `libzenoh_ffi.so` to F# Supervisor (Priority: P0)
- 1.3.1.1.1 - Add P/Invoke bindings for Zenoh session creation (Priority: P0)
- 1.3.1.1.2 - Implement health telemetry publisher on `indrajaal/obs/health` (Priority: P0)
##### 1.3.2 - MCP Server Integration (Priority: P1)
###### 1.3.2.1 - Expose Supervisor via MCP (Priority: P1)
- 1.3.2.1.1 - Implement MCP endpoints: `get_service_status`, `restart_service`, `get_service_logs` (Priority: P1)
- 1.3.2.1.2 - Bind MCP server to standard I/O or configured HTTP port (Priority: P1)

#### 1.4 - Service Integration & Management (Priority: P0)
##### 1.4.1 - Configuration Injection (Priority: P0)
###### 1.4.1.1 - Map Nix Store Configs to Services (Priority: P0)
- 1.4.1.1.1 - Pass `prometheus.yml`, `grafana.ini`, and `otel-collector-standalone.yaml` as arguments in the F# supervisor process definitions (Priority: P0)
- 1.4.1.1.2 - Verify directory permissions and state tracking in `/var/lib/` equivalents (Priority: P0)

#### 1.5 - Validation & Deployment (Priority: P0)
##### 1.5.1 - Image Replacement & Compose Update (Priority: P0)
###### 1.5.1.1 - Load New Image to Localhost Registry (Priority: P0)
- 1.5.1.1.1 - Run `podman load -i result` (Priority: P0)
- 1.5.1.1.2 - Tag image as `localhost/indrajaal-obs-unified:nixos-native` (Priority: P0)
###### 1.5.1.2 - Update Compose File & Verify Health (Priority: P0)
- 1.5.1.2.1 - Update `podman-compose-sil6-full-mesh.yml` to point to the new image (Priority: P0)
- 1.5.1.2.2 - Execute `podman-compose up -d indrajaal-obs-prod` (Priority: P0)
- 1.5.1.2.3 - Verify `podman inspect` shows healthy status and logs show F# Agent booting services (Priority: P0)

## Success Criteria
- `indrajaal-obs-prod` container is healthy (`podman ps` status).
- All services (Prometheus, Grafana, OTEL, ClickHouse) are active and responding.
- F# Supervisor Agent boots first (PID 1) and correctly manages child processes.
- Zenoh telemetry from the F# Agent is visible on the `indrajaal/obs/health` topic.
- Container is built entirely declaratively using NixOS tools, satisfying SC-CNT-009.

## Risk Assessment
- **L1 Surface**: Container fails to boot.
- **L2 Proximate**: F# Agent crashes or fails to find `libzenoh_ffi.so`.
- **L3 Contributing**: `LD_LIBRARY_PATH` not correctly set in the Nix environment.
- **L4 Systemic**: Build environment mismatch for .NET 10.0 under strict Nix boundaries.
- **L5 Root Cause**: Missing native dependencies for FFI compilation in the container build step.
- **Mitigation**: Preflight tests of the F# agent in `devenv shell` before packaging into the OCI image.