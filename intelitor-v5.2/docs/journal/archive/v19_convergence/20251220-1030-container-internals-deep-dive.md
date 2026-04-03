# Deep Dive: Container Construction & Internals Analysis (Level 5)

**Date**: 2025-12-20 10:30 CEST
**Category**: Infrastructure Engineering
**References**: `containers/*.nix`, `devenv.nix`, `podman-compose*.yml`
**Status**: VERIFIED
**Author**: Gemini Agent (SOPv5.11)

## Executive Summary
This document provides the Level 5 technical specification for the construction, configuration, and operational internals of the Indrajaal container ecosystem. It details the **Nix-based build pipeline**, **component versioning**, and **runtime behaviors** that enforce the SOPv5.11 safety constraints.

## 1.0 Container Construction Methodology
All containers are built using a **Deterministic Nix Pipeline**, bypassing standard Dockerfile indeterminism.

*   **Build Engine**: `pkgs.dockerTools.buildImage` (NixOS).
*   **Layer Strategy**: `copyToRoot` (avoids KVM/QEMU requirement of `runAsRoot`, ensuring CI compatibility).
*   **Registry Target**: `localhost/` (Strict isolation per SC-CNT-010).
*   **Build Command**: `nix-build containers/<container-name>.nix`.

## 2.0 Container Specifications (Component-Level)

### 2.1 Elixir Application Container (`indrajaal-sopv51-elixir-app`)
*   **Source Definition**: `containers/sopv51-elixir-app.nix`
*   **Key Components & Versions**:
    *   **Elixir**: `1.19` (Bleeding edge for performance)
    *   **Erlang/OTP**: `28` (JIT optimizations)
    *   **Node.js**: `20` (LTS for assets)
    *   **PHICS Tools**: `inotify-tools`, `watchman`, `entr` (File watching)
    *   **Process Mgmt**: `setpriv` (Rootless user switching without PAM)
*   **Filesystem Layout**:
    *   `/workspace`: Main working directory (mounted from host in Dev).
    *   `/etc/ssl/certs`: Symlinked CA bundles for HTTPS.
    *   `/home/developer`: UID 1000 home directory.
*   **Runtime Config (Entrypoint)**:
    *   **Script**: `app-entrypoint` (Embedded in image).
    *   **Mode Logic**: Uses `CONTAINER_MODE` env var to switch behavior:
        *   `test`: Runs `mix test`, disables Phoenix server.
        *   `dev`: Runs `iex -S mix phx.server` with hot-reloading.
        *   `demo`: Runs `mix phx.server` with demo data.
        *   `prod`: Runs release binary `/app/bin/server`.

### 2.2 TimescaleDB Database Container (`indrajaal-timescaledb-demo`)
*   **Source Definition**: `containers/indrajaal-timescaledb-demo.nix`
*   **Key Components**:
    *   **PostgreSQL**: `17` (Latest stable).
    *   **Extension**: `timescaledb` (Time-series optimization).
    *   **Mesh Layer**: Injected `tailscale` binaries for mesh networking.
*   **Configuration**:
    *   `shared_preload_libraries = 'timescaledb'` automatically set in `postgresql.conf`.
    *   `pg_hba.conf` configured for container-network trust.
*   **Mesh Integration**:
    *   **Wrapper**: Uses `ts.wrap entrypoint` to launch Tailscale sidecar *inside* the entrypoint execution flow, binding the database to the mesh IP.

### 2.3 Redis Cache Container
*   **Source**: `containers/indrajaal-redis-demo.nix` (Inferred from pattern).
*   **Components**: Standard Redis package from Nixpkgs.
*   **Config**: Optimized for LRU eviction (`allkeys-lru`) and persistence (`appendonly yes`).

## 3.0 Runtime Configuration & Orchestration

### 3.1 Environment Variables (Source of Truth)
*   **Definition**: `devenv.nix` and `podman-compose.yml`.
*   **Critical Variables**:
    *   `PHICS_ENABLED=true`: Activates hot-reloading watchers.
    *   `NO_TIMEOUT=true`: Disables compilation timeouts (Patient Mode).
    *   `ELIXIR_ERL_OPTIONS="+S 16"`: Optimizes scheduler threads for host CPU.

### 3.2 Scripts & Tooling
*   **Build**:
    *   `scripts/containers/build_nixos_containers.exs`: Automates `nix-build` and `podman load`.
    *   `scripts/containers/sopv51_base_build.exs`: Builds the common base layer to speed up iterations.
*   **Orchestration**:
    *   `scripts/containers/start_nixos_containers.exs`: Elixir-based wrapper around `podman-compose` that performs pre-flight checks (ports, volumes).
*   **Validation**:
    *   `scripts/pcis/container_phics_validator.exs`: Verifies PHICS requirements inside the container.

## 4.0 Safety & Compliance Mechanisms
*   **Rootless Enforcement**: Containers define specific users (`developer`, `postgres`) and `setpriv` is used to drop privileges immediately upon entry.
*   **Read-Only Roots**: Orchestration files (`-secure.yml`) enforce `read_only: true`, requiring explicit `tmpfs` mounts for writable areas (`/tmp`, `/_build`).
*   **Tailscale Identity**: Containers are not just network endpoints; they are **Identities** in the Tailscale mesh, authenticated via ephemeral keys injected at runtime.
