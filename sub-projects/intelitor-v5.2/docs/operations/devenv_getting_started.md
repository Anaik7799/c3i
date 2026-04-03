# devenv Shell Getting Started Guide

> Version: 21.3.1-SIL6 | Date: 2026-03-28 | STAMP: SC-ENV-001, SC-PARALLEL-001

## Overview

Indrajaal uses devenv (Nix-based development environments) to provide a reproducible
shell with all required toolchains: Elixir/OTP, .NET 10, Rust, Node.js, and Podman.
This guide covers setup, essential commands, and environment variables.

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Nix | 2.18+ | `curl -L https://nixos.org/nix/install \| sh` |
| devenv | 1.0+ | `nix profile install github:cachix/devenv` |
| direnv | 2.32+ | `nix profile install nixpkgs#direnv` |
| Podman | 5.4.1+ | Via NixOS module or system package |

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> indrajaal && cd indrajaal

# 2. Enter the devenv shell (first run downloads dependencies, ~5 min)
devenv shell

# 3. Verify toolchain versions
elixir --version        # Elixir 1.18+ / OTP 28+
dotnet --version        # .NET 10.0
cargo --version         # Rust 1.82+
node --version          # Node.js 22+
podman --version        # Podman 5.4.1+

# 4. Install Elixir dependencies
mix deps.get

# 5. Compile (with CPU governance)
scripts/cpu-governor.sh governed_compile

# 6. Run tests
scripts/cpu-governor.sh governed_test
```

## Environment Variables (Mandatory)

These are set automatically by devenv.nix:

| Variable | Value | Purpose |
|----------|-------|---------|
| `NO_TIMEOUT` | `true` | Disable compilation timeouts |
| `PATIENT_MODE` | `enabled` | Extended wait for NIF compilation |
| `INFINITE_PATIENCE` | `true` | No build timeout limits |
| `SKIP_ZENOH_NIF` | `0` | Enable Zenoh NIF (mandatory) |
| `WALLABY_ENABLED` | `true` | Enable Wallaby E2E tests |
| `ELIXIR_ERL_OPTIONS` | `+S 16:16 +SDio 16` | BEAM scheduler config |
| `MIX_ENV` | `dev` | Default environment |
| `HEALTH_PORT` | `4006` | Health check port (not 4001) |

## Essential Commands

### Compilation

```bash
# Standard compile (CPU governed, SC-CPU-GOV-002)
scripts/cpu-governor.sh governed_compile

# Direct compile (when CPU is known to be low)
NO_TIMEOUT=true PATIENT_MODE=enabled SKIP_ZENOH_NIF=0 WALLABY_ENABLED=true \
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16" mix compile --jobs 16

# F# compile
dotnet build lib/cepaf/src/Cepaf/Cepaf.fsproj

# Rust Zenoh FFI
cargo build --release -p zenoh_ffi
```

### Testing

```bash
# Elixir tests (CPU governed)
scripts/cpu-governor.sh governed_test

# F# tests
dotnet run --project lib/cepaf/test/Cepaf.Tests/Cepaf.Tests.fsproj -- --summary

# Wallaby E2E browser tests
scripts/cpu-governor.sh governed_wallaby

# Single test file
MIX_ENV=test mix test test/path/to/test_file.exs
```

### Quality Gates

```bash
# Format check
mix format --check-formatted

# Credo strict analysis
mix credo --strict

# Security scan
mix sobelow

# Full quality pipeline
mix format --check-formatted && mix credo --strict && mix sobelow
```

### Mesh Operations

```bash
# Boot the 4-container mesh
./sa-up

# Check health
./sa-status

# Verify safety
./sa-verify

# Graceful shutdown
./sa-down
```

### Planning

```bash
# List tasks
sa-plan list

# Add a task
sa-plan add "Description" --priority P2

# Update status
sa-plan update <task-id> in_progress
```

## CPU Governor

All heavy operations MUST use CPU governance (SC-CPU-GOV-002):

```bash
# Check current CPU status
scripts/cpu-governor.sh check

# Governed operations auto-throttle based on CPU:
#   < 60%: 16 schedulers, 16 jobs
#   < 70%: 12 schedulers, 12 jobs
#   < 80%: 10 schedulers, 10 jobs
#   >= 80%: 6 schedulers, 6 jobs (SC-CPU-GOV-PRECEDENCE)
#   > 85%: Wait loop until < 75% (SC-CPU-GOV-005)
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `ld-linux-x86-64.so.2` error | `rm -rf _build deps` (Axiom 0.1) |
| NIF compilation hangs | Ensure `PATIENT_MODE=enabled` |
| Port 4001 occupied | Use `HEALTH_PORT=4006` |
| Podman permission denied | Ensure rootless mode configured |
| devenv shell slow | Run `devenv gc` to clean old generations |

## Related Documents

- CLAUDE.md Section 1.0 (Axiom 1: Patient Mode)
- CLAUDE.md Section 5.0 (SC-CPU-GOV, SC-PARALLEL)
- scripts/cpu-governor.sh
- devenv.nix
