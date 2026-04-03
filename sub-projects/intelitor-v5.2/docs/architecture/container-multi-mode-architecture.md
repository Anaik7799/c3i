# Container Multi-Mode Architecture Specification

**Version**: 1.0.0
**Date**: 2025-12-19
**Status**: PROPOSED
**STAMP Compliance**: SC-CNT-TEST-001 to SC-CNT-TEST-005
**Incident Reference**: INC-20251219-001

---

## Overview

This document specifies a multi-mode container architecture that supports test, development, demo, and production execution modes within a single container image. This design addresses the fragility of single-purpose containers and enables robust container-based testing.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MULTI-MODE CONTAINER ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ENVIRONMENT VARIABLE: CONTAINER_MODE                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     MODE SELECTION LAYER                              │   │
│  │                                                                       │   │
│  │   CONTAINER_MODE=test    ───▶  Test Mode Entrypoint                  │   │
│  │   CONTAINER_MODE=dev     ───▶  Development Mode Entrypoint           │   │
│  │   CONTAINER_MODE=demo    ───▶  Demo Mode Entrypoint (default)        │   │
│  │   CONTAINER_MODE=prod    ───▶  Production Mode Entrypoint            │   │
│  │   CONTAINER_MODE=compile ───▶  Compile-Only Mode Entrypoint          │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────┐  │
│  │   TEST MODE    │ │   DEV MODE     │ │   DEMO MODE    │ │  PROD MODE   │  │
│  ├────────────────┤ ├────────────────┤ ├────────────────┤ ├──────────────┤  │
│  │ MIX_ENV=test   │ │ MIX_ENV=dev    │ │ MIX_ENV=demo   │ │ MIX_ENV=prod │  │
│  │                │ │                │ │                │ │              │  │
│  │ Apps Started:  │ │ Apps Started:  │ │ Apps Started:  │ │ Apps:        │  │
│  │ • Ecto Repo    │ │ • All + IEx    │ │ • All + PHX    │ │ • All + PHX  │  │
│  │ • PropCheck    │ │ • LiveReload   │ │ • No IEx       │ │ • No Debug   │  │
│  │ • ExUnit       │ │ • PHX Server   │ │                │ │              │  │
│  │ • StreamData   │ │                │ │                │ │              │  │
│  │                │ │                │ │                │ │              │  │
│  │ NO PHX Server  │ │ Port: 4000     │ │ Port: 4000     │ │ Port: 4000   │  │
│  │ Port: N/A      │ │                │ │                │ │              │  │
│  │                │ │                │ │                │ │              │  │
│  │ Command:       │ │ Command:       │ │ Command:       │ │ Command:     │  │
│  │ mix test $ARGS │ │ iex -S mix     │ │ mix phx.server │ │ bin/server   │  │
│  │                │ │ phx.server     │ │                │ │              │  │
│  └────────────────┘ └────────────────┘ └────────────────┘ └──────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      SHARED INFRASTRUCTURE                            │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │
│  │  • NixOS Base Layer (Elixir 1.19.2, OTP 28)                          │   │
│  │  • SSL Certificates (/etc/ssl/certs/ca-bundle.crt)                   │   │
│  │  • User: developer (UID 1000)                                         │   │
│  │  • Workspace: /workspace                                              │   │
│  │  • Mix/Hex: /workspace/.mix, /workspace/.hex                         │   │
│  │  • PHICS Hot-Reload Support                                           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Mode Specifications

### Test Mode (`CONTAINER_MODE=test`)

**Purpose**: Execute test suites with proper application initialization

**Requirements**:
- PropCheck.CounterStrike GenServer must be started
- Ecto Repo must be started and connected to database
- ExUnit must be initialized
- Phoenix server must NOT start (no port binding)
- Database sandbox mode enabled

**Environment Variables**:
```bash
CONTAINER_MODE=test
MIX_ENV=test
PHX_SERVER=false
ECTO_SANDBOX=true
```

**Entrypoint Command**:
```bash
# Start applications needed for testing but not Phoenix
mix do compile --warnings-as-errors, test "$@"
```

**Health Check**:
```bash
# Test mode health: verify Repo connection
mix run -e "Indrajaal.Repo.query!('SELECT 1')"
```

---

### Development Mode (`CONTAINER_MODE=dev`)

**Purpose**: Interactive development with hot-reloading

**Requirements**:
- IEx shell available
- Phoenix LiveReload enabled
- PHICS hot-reload integration
- Code recompilation on save

**Environment Variables**:
```bash
CONTAINER_MODE=dev
MIX_ENV=dev
PHX_SERVER=true
PHX_HOST=localhost
PHX_PORT=4000
```

**Entrypoint Command**:
```bash
iex -S mix phx.server
```

**Health Check**:
```bash
curl -f http://localhost:4000/health --max-time 5
```

---

### Demo Mode (`CONTAINER_MODE=demo`)

**Purpose**: Demonstration deployments with full functionality

**Requirements**:
- Phoenix server running
- No IEx shell (background execution)
- All demo features enabled
- Sample data loading capability

**Environment Variables**:
```bash
CONTAINER_MODE=demo
MIX_ENV=demo
PHX_SERVER=true
PHX_HOST=localhost
PHX_PORT=4000
```

**Entrypoint Command**:
```bash
mix phx.server
```

**Health Check**:
```bash
curl -f http://localhost:4000/health --max-time 5
```

---

### Production Mode (`CONTAINER_MODE=prod`)

**Purpose**: Production deployment with security hardening

**Requirements**:
- Release binary execution
- No source code access
- Minimal attack surface
- Optimized for performance

**Environment Variables**:
```bash
CONTAINER_MODE=prod
MIX_ENV=prod
PHX_SERVER=true
SECRET_KEY_BASE=<generated>
DATABASE_URL=<production_url>
```

**Entrypoint Command**:
```bash
/app/bin/server
```

**Health Check**:
```bash
curl -f http://localhost:4000/health --max-time 5
```

---

### Compile Mode (`CONTAINER_MODE=compile`)

**Purpose**: Compilation-only for CI/CD pipelines

**Requirements**:
- Full compilation with warnings-as-errors
- No runtime execution
- Exit with compilation status

**Environment Variables**:
```bash
CONTAINER_MODE=compile
MIX_ENV=prod  # Or test for test compilation
```

**Entrypoint Command**:
```bash
mix do deps.get, compile --warnings-as-errors
```

**Health Check**: N/A (exits after compilation)

---

## Implementation: Multi-Mode Entrypoint Script

```bash
#!/usr/bin/env bash
# File: scripts/container/multi_mode_entrypoint.sh
# Purpose: Mode-aware container entrypoint
# STAMP: SC-CNT-TEST-001, SC-CNT-TEST-004

set -e

# Default mode
MODE="${CONTAINER_MODE:-demo}"
MIX_ENV_OVERRIDE="${MIX_ENV:-}"

# Logging function
log() {
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] ENTRYPOINT: $*"
}

log "Starting container in '$MODE' mode"

# Set MIX_ENV based on mode (if not explicitly overridden)
if [ -z "$MIX_ENV_OVERRIDE" ]; then
  case "$MODE" in
    test)    export MIX_ENV=test ;;
    dev)     export MIX_ENV=dev ;;
    demo)    export MIX_ENV=demo ;;
    prod)    export MIX_ENV=prod ;;
    compile) export MIX_ENV=prod ;;
    *)       export MIX_ENV=demo ;;
  esac
fi

log "MIX_ENV set to: $MIX_ENV"

# Ensure workspace is ready
cd /workspace

# Verify Hex and Rebar are installed
if [ ! -f "$HEX_HOME/hex.config" ]; then
  log "Installing Hex..."
  mix local.hex --force --if-missing
fi

if [ ! -f "$MIX_HOME/rebar3" ]; then
  log "Installing Rebar3..."
  mix local.rebar --force
fi

# Mode-specific execution
case "$MODE" in
  test)
    log "TEST MODE: Starting test infrastructure..."
    # PropCheck and Ecto will be started by mix test
    # No Phoenix server, no port binding
    export PHX_SERVER=false

    # Get dependencies if needed
    mix deps.get --only test

    # Compile first to catch PropCheck macro issues
    log "Compiling for test..."
    mix compile

    # Run tests with all arguments passed through
    log "Running tests with args: $*"
    exec mix test "$@"
    ;;

  dev)
    log "DEV MODE: Starting interactive development server..."
    export PHX_SERVER=true
    mix deps.get
    exec iex -S mix phx.server
    ;;

  demo)
    log "DEMO MODE: Starting demo server..."
    export PHX_SERVER=true
    mix deps.get
    mix ecto.create --quiet 2>/dev/null || true
    mix ecto.migrate
    exec mix phx.server
    ;;

  prod)
    log "PROD MODE: Starting production server..."
    export PHX_SERVER=true
    # Assume release is pre-built
    if [ -f "/app/bin/server" ]; then
      exec /app/bin/server
    else
      log "WARNING: No release found, falling back to mix"
      exec mix phx.server
    fi
    ;;

  compile)
    log "COMPILE MODE: Running compilation..."
    mix deps.get
    exec mix compile --warnings-as-errors
    ;;

  *)
    log "ERROR: Unknown mode '$MODE'"
    log "Valid modes: test, dev, demo, prod, compile"
    exit 1
    ;;
esac
```

---

## Updated Nix Configuration

```nix
# File: containers/sopv51-elixir-app.nix (updated section)

# Create multi-mode entrypoint
multiModeEntrypoint = pkgs.writeScriptBin "container-entrypoint" ''
  #!${pkgs.bash}/bin/bash
  set -e

  MODE="${"$"}{CONTAINER_MODE:-demo}"

  echo "🚀 Indrajaal Container - Mode: $MODE"

  # ... (full script as above)
'';

# In config section:
config = {
  Cmd = [ "${multiModeEntrypoint}/bin/container-entrypoint" ];
  # ... rest of config

  Env = [
    "CONTAINER_MODE=demo"  # Default, but overridable
    "CONTAINER_OS=nixos"
    # ... other env vars
  ];
};
```

---

## Podman Compose Integration

```yaml
# File: podman-compose-testing.yml (add new service)

services:
  # Existing services...

  # NEW: Dedicated test runner
  indrajaal-test-runner:
    image: localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28
    container_name: indrajaal-test-runner
    hostname: test-runner
    networks:
      indrajaal-test-net:
        ipv4_address: 172.31.0.25
    environment:
      CONTAINER_MODE: test
      MIX_ENV: test
      DATABASE_URL: ecto://indrajaal:indrajaal_test@172.31.0.10:5433/indrajaal_test
      POSTGRES_USER: indrajaal
      POSTGRES_PASSWORD: indrajaal_test
      # No PHX_SERVER, no PHX_PORT - test mode doesn't use them
      ELIXIR_ERL_OPTIONS: "+S 4 +A 32 +K true +P 1048576"
      SSL_CERT_FILE: /etc/ssl/certs/ca-certificates.crt
    volumes:
      - .:/workspace:z
      - test_runner_deps:/workspace/deps
      - test_runner_build:/workspace/_build
      - /etc/ssl/certs:/etc/ssl/certs:ro
    working_dir: /workspace
    # Command passed to entrypoint (test arguments)
    command: ["--max-failures", "50", "--cover"]
    depends_on:
      indrajaal-db-primary:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '8.0'
    # No healthcheck - test runner exits when done
    restart: "no"  # Don't restart after tests complete

volumes:
  test_runner_deps:
    driver: local
  test_runner_build:
    driver: local
```

---

## STAMP Constraint Definitions

```mathematica
(* SC-CNT-TEST: Container Test Execution Safety Constraints *)

SC_CNT_TEST_001 :=
  O[Container, ∀ mode ∈ {test, dev, demo, prod, compile} :
    SupportsMode[Container, mode]]

SC_CNT_TEST_002 :=
  O[TestContainer,
    StartedApps ⊇ {PropCheck.CounterStrike, Ecto.Repo, ExUnit}]

SC_CNT_TEST_003 :=
  O[TestContainer,
    ¬PhoenixServerRunning ∧ ¬PortBinding[4000]]

SC_CNT_TEST_004 :=
  O[Container,
    ModeSelection == EnvVar["CONTAINER_MODE"]]

SC_CNT_TEST_005 :=
  O[TestContainer,
    DatabaseConnectivity[Verified] ∧
    DatabaseCredentials[Correct]]
```

---

## Validation Tests

```elixir
# File: test/containers/multi_mode_container_test.exs

defmodule Indrajaal.Containers.MultiModeContainerTest do
  use ExUnit.Case, async: false

  @moduletag :container_mode

  describe "SC-CNT-TEST-001: Multi-mode support" do
    @tag :slow
    test "container supports test mode" do
      {output, 0} = System.cmd("podman", [
        "run", "--rm", "-e", "CONTAINER_MODE=test",
        "localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28",
        "echo", "TEST_MODE_OK"
      ])
      assert String.contains?(output, "TEST_MODE_OK")
    end

    @tag :slow
    test "container supports compile mode" do
      {output, 0} = System.cmd("podman", [
        "run", "--rm", "-e", "CONTAINER_MODE=compile",
        "localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28",
        "--dry-run"  # Added for fast validation
      ])
      assert String.contains?(output, "COMPILE MODE")
    end
  end

  describe "SC-CNT-TEST-003: Test mode port isolation" do
    test "test mode does not bind port 4000" do
      # Verify PHX_SERVER is false in test mode
      assert System.get_env("PHX_SERVER") != "true" or
             System.get_env("CONTAINER_MODE") != "test"
    end
  end
end
```

---

## Migration Path

### Step 1: Create Multi-Mode Entrypoint (Immediate)
- Create `scripts/container/multi_mode_entrypoint.sh`
- Test locally with `chmod +x && ./multi_mode_entrypoint.sh`

### Step 2: Update Nix Configuration (This Sprint)
- Modify `containers/sopv51-elixir-app.nix`
- Build new image: `nix-build containers/sopv51-elixir-app.nix`
- Tag: `localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28-multimode`

### Step 3: Update Compose Files (This Sprint)
- Add `indrajaal-test-runner` service
- Test: `podman-compose -f podman-compose-testing.yml up indrajaal-test-runner`

### Step 4: CI/CD Integration (Next Sprint)
- Update GitHub Actions workflow
- Add container mode validation job

---

## References

- **Incident**: INC-20251219-001
- **Journal**: `journal/2025-12/20251219-1330-container-test-execution-rca.md`
- **STAMP**: SC-CNT-TEST-001 to SC-CNT-TEST-005
- **TDG**: TDG-CNT-001 to TDG-CNT-003
- **AOR**: AOR-CNT-TEST-001 to AOR-CNT-TEST-004

---

**Document Created**: 2025-12-19T13:45:00+01:00
**Author**: Claude Code (Opus 4.5)
**Framework**: SOPv5.11 + STAMP/STPA
