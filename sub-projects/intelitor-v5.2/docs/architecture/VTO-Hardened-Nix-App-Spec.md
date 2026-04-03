# 🏗️ VTO-APP-001: Hardened Nix-App 5-Level Specification

**Version**: 1.0.0
**Date**: 2025-12-21
**Service**: `app` (Indrajaal Core)
**Framework**: SOPv5.11 + TPS + OODA + Jidoka + STAMP

## 1.0 Strategic Analysis (Level 1)

### 1.1 AS-IS: Compilation Fragility
- **State**: `mimerl` failure during `mix deps.compile`.
- **Root Cause**: Missing C-toolchain (`gcc`, `make`) in the runtime environment and missing Erlang header paths.
- **SSL State**: `:no_cacerts_found` despite environment variables, due to missing files in standard Unix paths (`/etc/ssl/certs/ca-certificates.crt`).

### 1.2 TO-BE: Hermetic Runtime Readiness
- **Objective**: An image that arrives "Build-Ready."
- **Paradigm**: The container *is* the build environment. No external dependencies.
- **Success Gate**: `mix compile` succeeds on the first OODA iteration of the `app` service.

---

## 2.0 Architectural Design (Level 2)

### 2.1 The Build-Tool Sidecar (In-Image)
- **Concept**: Instead of a "slim" image that fails to compile C-deps, we ship a "Hardened Build-Ready" image containing the Nix-managed toolchain.
- **Key Tools**: `gcc`, `gnumake`, `binutils`, `rebar3`, `git`.

### 2.2 SSoT Sync: Image Genome
- **Config**: `lib/indrajaal/deployment/config.ex` defines the image as `localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv`.
- **Orchestration**: VTO Orchestrator uses this image to run the `app` stage health check.

---

## 3.0 Implementation Details (Level 3)

### 3.1 Hardened Nix Derivation (`sopv51-elixir-app.nix`)
- **SSL Hardening**: Symlink `pkgs.cacert` to three standard Unix locations.
- **Toolchain Inclusion**: Explicitly add `shadow`, `gcc`, `gnumake` to `appFS`.
- **Environment Invariant**: Set `HEX_CACERTS_PATH` and `SSL_CERT_FILE` in the `Entrypoint` script.

### 3.2 VTO OODA Integration
- **Verification Command**: `mix deps.compile mimerl && mix compile`.
- **Health Endpoint**: Phoenix `/health` (4001).

---

## 4.0 The Verification Sequence (Level 4)

### 4.1 Stage 1: Build & Load
- **Action**: `elixir scripts/containers/parallel_build_agent.exs`.
- **Gate**: Image loaded into Podman store without permission errors.

### 4.2 Stage 2: Isolated Compilation (The "Acid Test")
- **Action**: `podman run` with isolated volume.
- **Verification**: `mimerl` compilation succeeds.

### 4.3 Stage 3: Networked Integration
- **Action**: Full `vto_orchestrator.exs` run.
- **Success**: Stack is up and `curl localhost:4001/health` returns 200.

---

## 5.0 Tactical Operations (Level 5)

### 5.1 Manual Debugging (mimerl focus)
```bash
podman run --rm -it -v $(pwd):/workspace:z localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv bash
# Inside:
which gcc && which make && which rebar3
mix deps.compile mimerl
```

### 5.2 Automated Recovery
If SSL fails:
1.  Verify `/etc/ssl/certs/ca-certificates.crt` exists in the container.
2.  Check `NIX_SSL_CERT_FILE` environment variable.
