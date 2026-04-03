# General Availability (GA) Deployment Guide
**Version**: 1.2.0
**Target**: Production / Demo
**Compliance**: SIL-6 / IEC 61508

## 1. Prerequisites
*   **OS**: Linux (Kernel 5.15+)
*   **Runtime**: Podman 5.4.1+
*   **Framework**: .NET 10.0 SDK (for Supervisor) / Elixir 1.19 (for Watchdogs)

## 2. Deployment Steps

### Step 1: Build Hardened Images
Execute the parallel build factory to generate SIL-6 artifacts.
```bash
./scripts/containers/build_sil4_images.sh
```
*Expected Time: ~30s*

### Step 2: Preflight Verification
Run the verification suite to ensure the substrate is ready.
```bash
elixir scripts/verification/sil4_preflight_check.exs
```

### Step 3: Launch Mesh
Start the system in Fractal Mode.
```bash
./sa-up.fsx
```
*Wait for the TUI to show "SYSTEM STATE: READY (QUORUM REACHED)"*

## 3. Demo Procedures
*   **Traffic Simulation**: Run `./sa-up.fsx --demo` to auto-inject traffic.
*   **Chaos Testing**: Run `elixir scripts/chaos/fractal_chaos_monkey.exs` to demonstrate resilience.

## 4. Maintenance
*   **Logs**: `podman logs -f indrajaal-app-1`
*   **Clean**: `./sa-clean.fsx` (WARNING: Destructive)

## 5. Troubleshooting
*   **Network Exists Error**: If `podman-compose` fails with `podman network exists` error, run `podman network create fractal-mesh` manually before startup. This is a known issue with `podman-compose` versions < 1.0.7 in rootless mode. The `sil4_preflight_check.exs` attempts to auto-fix this.
*   **Zombie Containers**: If the TUI shows "STARTING" indefinitely, check `podman ps -a` and kill stuck containers with `./sa-clean.fsx`.
