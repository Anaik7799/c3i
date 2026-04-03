# Indrajaal Application Container Mechanism & Process

**Version**: 1.0.0
**Status**: ACTIVE
**Reference**: SC-CNT-009 (NixOS Containers), CFA-001 (Hardened App)

## 1.0 Executive Summary

This document defines the definitive mechanism and operational processes for the creation, deployment, and runtime management of the Indrajaal Application Container (`indrajaal-app`). It standardizes the "Hardened Nix-App" strategy to resolve historical compilation fragility and environment inconsistencies.

---

## 2.0 AS-IS vs. TO-BE Analysis

### 2.1 AS-IS State (Legacy/Fragile)
*   **Derivation**: `containers/enhanced-app-nixos.nix` (deprecated).
*   **Toolchain**: Minimal runtime dependencies. Missing `gcc`, `gnumake`, `binutils` in the final image layer.
*   **Compilation**: Frequently failed on C-extensions (`mimerl`, `bcrypt_elixir`) due to missing headers/tools.
*   **SSL/TLS**: Relied on implicit cert paths. `CAST` analysis showed frequent `:nxdomain` or `:econnrefused` due to SSL handshake failures.
*   **Configuration**: `DATABASE_URL` hardcoded or missing in `runtime.exs`. No Single Source of Truth (SSoT).
*   **Orchestration**: `podman-compose up` blindly started containers without pre-verification (VTO violation).

### 2.2 TO-BE State (Hardened/Robust)
*   **Derivation**: `containers/sopv51-elixir-app.nix`.
*   **Toolchain**: "Fat" runtime layer including `gcc`, `gnumake`, `binutils`, `rebar3`, and `git`.
*   **Compilation**: 100% success rate for C-nodes. `MIX_REBAR3` forces usage of Nix-provided binary.
*   **SSL/TLS**: Entrypoint symlinks certificates to `/etc/ssl/certs/ca-certificates.crt` before app start.
*   **Configuration**: SSoT via `lib/indrajaal/deployment/config.ex`. `config/runtime.exs` patched to accept dynamic env vars.
*   **Orchestration**: VTO (Verify-Then-Orchestrate) OODA loop enforced via `vto_orchestrator.exs`.

---

## 3.0 Container Creation Mechanism

### 3.1 The Hardened Derivation (`sopv51-elixir-app.nix`)
The container is built using Nix `dockerTools.buildImage`. Key architectural decisions:

1.  **Base Layer**: `nixpkgs/nixos-23.11` (or latest stable) for hermetic reproducibility.
2.  **Runtime Packages**:
    *   `elixir`, `erlang` (BEAM VM)
    *   `gcc`, `gnumake`, `binutils` (C-compilation support for deps)
    *   `rebar3` (Erlang package manager, explicitly linked)
    *   `git` (Dependency fetching)
    *   `bash`, `coreutils` (Shell environment)
    *   `cacert` (SSL Trust store)
3.  **Environment Variables**:
    *   `MIX_REBAR3 = "${pkgs.rebar3}/bin/rebar3"`: Prevents Mix from downloading a possibly incompatible rebar3.
    *   `LANG = "C.UTF-8"`: Locales.

### 3.2 The Entrypoint Strategy
The container uses a smart entrypoint script (`CopyScript` in Nix) that performs "Just-In-Time" hardening:

```bash
# 1. SSL Symlinking (Crucial for generic Elixir SSL support)
mkdir -p /etc/ssl/certs
ln -sf /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

# 2. Rebar3 Verification
if [ -z "$MIX_REBAR3" ]; then
  echo "CRITICAL: MIX_REBAR3 not set. Compilation may fail."
fi

# 3. Execution
exec "$@"
```

### 3.3 Build Process
The build is managed by `scripts/containers/parallel_build_agent.exs` to ensure concurrency and caching.

**Command**:
```bash
elixir scripts/containers/parallel_build_agent.exs --target app --strategy hardened
```

---

## 4.0 Runtime Process (VTO OODA Loop)

Usage of the container MUST follow the VTO protocol. Do NOT use raw `podman run` or `podman-compose up` manually for production/demo flows.

### 4.1 The Verify-Then-Orchestrate (VTO) Loop

1.  **Observe (Verify Image)**:
    *   Check if `localhost/indrajaal-app:fully-functional` exists.
    *   Verify toolchain presence: `podman run --rm ... gcc --version`.
    
2.  **Orient (Configure Environment)**:
    *   Load SSoT from `lib/indrajaal/deployment/config.ex`.
    *   Generate `podman-compose.yml` dynamically if needed (or verify existing).
    *   Ensure `config/runtime.exs` matches the container expected env vars (`DATABASE_URL`, `SECRET_KEY_BASE`).

3.  **Decide (Orchestration Strategy)**:
    *   If `Dev`: Use `podman-compose-3container.yml` (PHICS enabled).
    *   If `Demo/Prod`: Use hardened image + `vto_orchestrator.exs`.

4.  **Act (Launch & Monitor)**:
    *   Start Dependencies: `postgres`, `redis`, `observability`.
    *   Wait for Health: `pg_isready`.
    *   Start App: `indrajaal-app`.
    *   Monitor: Tail logs for `App Started!` or `Ecto.Migration` success.

### 4.2 Standard Launch Command
```bash
elixir scripts/containers/vto_orchestrator.exs --profile hardened --action start
```

---

## 5.0 Maintenance & Troubleshooting

### 5.1 Common Issues & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `mimerl` compilation error | Missing `gcc`/`make` | Rebuild with `sopv51-elixir-app.nix` (Hardened profile). |
| `:nxdomain` in DB connect | Missing SSL symlinks | Ensure entrypoint creates `/etc/ssl/certs/ca-certificates.crt`. |
| `rebar3: cmd not found` | Mix trying to fetch rebar | Verify `MIX_REBAR3` env var in derivation. |
| Health Check Timeout | App taking >30s to compile | Increase `start_period` in `config.ex` / `vto_orchestrator.exs`. |

### 5.2 Update Procedure
When `mix.lock` changes:
1.  Run `parallel_build_agent.exs` to rebuild the image layer.
2.  The Nix derivation uses `src = ./` so it will pick up new lockfiles.
3.  Restart VTO orchestrator.

---

## 6.0 Compliance
*   **SC-CNT-009**: NixOS-based container (Checked).
*   **SC-CNT-010**: Localhost registry (Checked).
*   **SC-SEC-042**: Secrets passed via env vars, not baked in (Checked).
