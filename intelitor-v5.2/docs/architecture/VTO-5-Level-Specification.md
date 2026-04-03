# 🏗️ VTO-001: Fractal Container Orchestration 5-Level Specification

**Version**: 1.0.0
**Date**: 2025-12-21
**Framework**: SOPv5.11 + TPS + OODA + Jidoka + STAMP

## 1.0 Strategic Analysis (Level 1)

### 1.1 AS-IS: Monolithic Fragility
- **Implementation**: Brittle shell scripts (`rebuild.sh`) and monolithic Elixir scripts (`execute_comprehensive_rebuild.exs`).
- **Issues**: Cascading failures, masked errors, SSL/TLS cert path mismatches in NixOS, environment drift.
- **Status**: UNSTABLE. Failed repeatedly due to compound errors.

### 1.2 TO-BE: Fractal Resilience (VTO)
- **Architecture**: Staged, verifiable isolation OODA loops.
- **Objective**: Proven component health *before* integration.
- **Benefits**: Isolated debugging, deterministic builds, 100% configuration consistency.

---

## 2.0 Architectural Framework (Level 2)

### 2.1 The Single Source of Truth (SSoT)
- **Module**: `lib/indrajaal/deployment/config.ex`
- **Role**: Defines the "Genome" of every service (ports, images, nix files, health checks).
- **Mandate**: All other artifacts (Compose files, Run commands) are derivative.

### 2.2 The Verification OODA Loop
- **Observe**: Start container in isolation on `indrajaal-network`.
- **Orient**: Execute contract-mandated health check (MFA).
- **Decide**: Certify success or trigger Jidoka (Stop).
- **Act**: Proceed to next dependency or enter debug micro-loop.

---

## 3.0 Implementation Details (Level 3)

### 3.1 Build-Time (Nix)
- **Mechanism**: Use `pkgs.cacert` and `ln -sf` to standard paths.
- **Files**: `containers/*.nix`.
- **Variables**: `SSL_CERT_FILE`, `HEX_CACERTS_PATH`, `CURL_CA_BUNDLE`.

### 3.2 Runtime (Podman)
- **Networking**: Bridge network `indrajaal-network` shared across stages.
- **Orchestration**: `podman-compose` used ONLY after individual certification.
- **Persistence**: Standardized volume mapping for `data/`.

---

## 4.0 The Verification Sequence (Level 4)

### 4.1 Stage 1: Backing Infrastructure
- **Service**: `postgres` (Priority 1) -> Health: `pg_isready`.
- **Service**: `redis` (Priority 2) -> Health: `redis-cli ping`.

### 4.2 Stage 2: Application Layer
- **Service**: `app` (Priority 3) -> Health: `/health` endpoint.
- **Actions**: `mix deps.get`, `mix ecto.migrate`, `mix compile`.

### 4.3 Stage 3: Full Integration
- **Action**: Dynamic generation of `podman-compose.yml`.
- **Verification**: `curl` check of the combined stack.

---

## 5.0 Operational Instructions (Level 5)

### 5.1 Manual Verification (Jidoka Mode)
```bash
# 1. Start isolated
podman run -d --name postgres -p 5433:5433 localhost/indrajaal-timescaledb-demo:nixos-devenv
# 2. Verify
elixir -e 'Indrajaal.Deployment.Config.run_health_check_for(:postgres)'
```

### 5.2 Automated Orchestration (AEE Mode)
```bash
# 1. Build
elixir scripts/containers/build_nixos_containers.exs
# 2. Orchestrate
elixir scripts/containers/vto_orchestrator.exs --all
```

---

## 6.0 Project Plan & Milestones

1.  **[M1] SSoT Foundation**: Finalize `config.ex` and `generate_compose.exs`.
2.  **[M2] Nix Hardening**: Update `sopv51-elixir-app.nix` with SSL fix.
3.  **[M3] VTO Orchestrator**: Implement `vto_orchestrator.exs`.
4.  **[M4] App Pre-Flight**: Implement environment validation in `application.ex`.
5.  **[M5] Full System Ignition**: Execute and certify the stack.
