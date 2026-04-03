# Indrajaal Container Architecture
## SOPv5.11 Compliant NixOS Container Strategy

**Version**: 1.0.0
**Updated**: 2025-12-18
**Framework**: SOPv5.11 + STAMP + TDG + AOR
**Runtime**: Elixir 1.19.2 / OTP 28

---

## 1. Architecture Overview

### 1.1 Container Topology

```
                          ┌─────────────────────────────────────────────────────────────┐
                          │            SOPv5.11 Testing/Demo Architecture               │
                          │                   (Podman Rootless)                         │
                          └─────────────────────────────────────────────────────────────┘
                                                     │
              ┌──────────────────────────────────────┼──────────────────────────────────────┐
              │                                      │                                      │
    ┌─────────▼─────────┐              ┌─────────────▼─────────────┐           ┌───────────▼───────────┐
    │  DATABASE LAYER   │              │    APPLICATION LAYER       │           │  OBSERVABILITY LAYER  │
    │     (2 nodes)     │              │        (3 nodes)           │           │       (1 node)        │
    └───────────────────┘              └───────────────────────────┘           └───────────────────────┘
              │                                      │                                      │
    ┌─────────┴─────────┐              ┌─────────────┼─────────────┐                       │
    │                   │              │             │             │                       │
┌───▼───┐          ┌────▼───┐    ┌─────▼────┐  ┌─────▼────┐  ┌─────▼────┐           ┌──────▼──────┐
│Primary│          │Replica │    │  app-1   │  │  app-2   │  │  app-3   │           │    obs      │
│ :5433 │          │ :5434  │    │  :4000   │  │  :4001   │  │  :4002   │           │ :9090/:3000 │
└───────┘          └────────┘    └──────────┘  └──────────┘  └──────────┘           └─────────────┘
172.31.0.10        172.31.0.11    172.31.0.20   172.31.0.21   172.31.0.22             172.31.0.30
```

### 1.2 Container Images

| Image | Tag | Version | Purpose | Size |
|-------|-----|---------|---------|------|
| `localhost/indrajaal-sopv51-base` | `elixir-1.19-otp28` | Elixir 1.19.2, OTP 28 | Base development environment | ~1.7GB |
| `localhost/indrajaal-sopv51-elixir-app` | `elixir-1.19-otp28` | Elixir 1.19.2, OTP 28 | Full application with PHICS | ~1.9GB |
| `localhost/indrajaal-timescaledb-demo` | `nixos-devenv` | PostgreSQL 17 + TimescaleDB | Database layer | ~194MB |
| `localhost/indrajaal-prometheus-demo` | `nixos-devenv` | Prometheus placeholder | Observability | ~4.7MB |

### 1.3 Network Configuration

| Network | Subnet | Gateway |
|---------|--------|---------|
| `indrajaal-test-net` | `172.31.0.0/24` | `172.31.0.1` |

---

## 2. STAMP Safety Constraints Compliance

### 2.1 Container Safety Constraints (SC-CNT-*)

| ID | Constraint | Implementation | Verification |
|----|------------|----------------|--------------|
| SC-CNT-009 | NixOS containers ONLY | All containers built with `pkgs.dockerTools.buildImage` | `podman inspect --format='{{.Config.Labels}}'` |
| SC-CNT-010 | localhost/ registry ONLY | All image references start with `localhost/` | `grep "image:" podman-compose-testing.yml` |
| SC-CNT-012 | Rootless Podman execution | User-space Podman without root privileges | `podman info --format='{{.Host.Security.Rootless}}'` |
| SC-CNT-014 | Resource isolation | CPU/memory limits in compose file | `deploy.resources.limits` |

### 2.2 Validation Constraints (SC-VAL-*)

| ID | Constraint | Implementation |
|----|------------|----------------|
| SC-VAL-001 | Patient Mode compilation | `NO_TIMEOUT=true PATIENT_MODE=enabled` environment |
| SC-VAL-002 | Complete log analysis | Logs streamed to `./data/tmp/` for full analysis |

### 2.3 Agent Operating Rules (AOR-CNT-*)

| ID | Rule | Enforcement |
|----|------|-------------|
| AOR-CNT-001 | Podman ONLY (Docker FORBIDDEN) | `podman-compose` used exclusively, no `docker` CLI |

---

## 3. Container Build Process

### 3.1 Build Pipeline

```bash
# Step 1: Update .nix files (done)
# containers/sopv51-base.nix: elixir_1_19 + erlang_28
# containers/sopv51-elixir-app.nix: elixir_1_19 + erlang_28

# Step 2: Build containers
nix-build containers/sopv51-base.nix -o result-base
nix-build containers/sopv51-elixir-app.nix -o result-app

# Step 3: Load to Podman (localhost registry)
podman load < result-base
podman load < result-app

# Step 4: Tag with version info
podman tag localhost/indrajaal-sopv51-base:nixos-25.05-unknown \
           localhost/indrajaal-sopv51-base:elixir-1.19-otp28
podman tag localhost/indrajaal-sopv51-elixir-app:nixos-25.05-unknown \
           localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28

# Step 5: Verify versions
podman run --rm localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 elixir --version
# Expected: Elixir 1.19.2 (compiled with Erlang/OTP 28)
```

### 3.2 NixOS Build Features

The containers use `copyToRoot` instead of `runAsRoot` to avoid KVM requirements:

```nix
pkgs.dockerTools.buildImage {
  name = "indrajaal-sopv51-elixir-app";
  tag = "nixos-25.05-${gitRev}";

  # KVM-free build approach
  copyToRoot = pkgs.buildEnv {
    name = "indrajaal-app-root";
    paths = [ appFS ];
    pathsToLink = [ "/" ];
  };
  ...
}
```

### 3.3 PHICS Configuration

PHICS (Persistent Hot-reload In Container System) is configured for development:

```json
{
  "watch_paths": [
    "lib/**/*.ex",
    "lib/**/*.exs",
    "priv/static/**/*",
    "assets/**/*"
  ],
  "reload_commands": [
    "mix compile",
    "mix phx.digest"
  ],
  "port": 4000
}
```

---

## 4. Environment Configurations

### 4.1 Development Environment

```bash
# Start minimal development setup (single app + database)
podman run -d --name indrajaal-dev-db \
  -e POSTGRES_DB=indrajaal_dev \
  -e POSTGRES_USER=indrajaal \
  -e POSTGRES_PASSWORD=indrajaal_dev \
  -p 5433:5433 \
  localhost/indrajaal-timescaledb-demo:nixos-devenv

podman run -d --name indrajaal-dev-app \
  -v $(pwd):/workspace:z \
  -p 4000:4000 \
  --env-file devenv.env \
  localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28
```

### 4.2 Test Environment

```bash
# Use full compose stack for testing
POSTGRES_USER=indrajaal POSTGRES_PASSWORD=indrajaal_dev \
  podman-compose -f podman-compose-testing.yml up -d

# Run tests inside container
podman exec indrajaal-app-1 mix test
```

### 4.3 Demo Environment

```bash
# Demo mode with all services
MIX_ENV=demo podman-compose -f podman-compose-testing.yml up -d

# Access points:
# - App 1: http://localhost:4000
# - App 2: http://localhost:4001
# - App 3: http://localhost:4002
# - Prometheus: http://localhost:9090
# - Grafana: http://localhost:3000
```

---

## 5. TDG (Test-Driven Generation) Compliance

### 5.1 Container Testing Strategy

| Test Type | Coverage | Command |
|-----------|----------|---------|
| Unit Tests | Container builds | `nix-build --dry-run` |
| Integration Tests | Service connectivity | `podman-compose up -d && ./scripts/test-connectivity.sh` |
| Health Checks | Container health | `podman ps --filter health=healthy` |
| Chaos Tests | Failure recovery | See Section 6 |

### 5.2 Container Health Checks

All application containers include health checks:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:4000/health", "--max-time", "5"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 180s
```

Database containers use PostgreSQL-specific checks:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U indrajaal -d indrajaal_test -p 5433"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

---

## 6. Chaos Testing & Failure Scenarios

### 6.1 Container Restart Testing

```bash
# Test graceful restart
podman restart indrajaal-app-1

# Test forced restart (simulates crash)
podman kill indrajaal-app-1
podman start indrajaal-app-1

# Verify recovery
podman ps --filter name=indrajaal-app-1 --format "{{.Status}}"
```

### 6.2 Network Partition Testing

```bash
# Disconnect app-2 from network
podman network disconnect indrajaal-test-net indrajaal-app-2

# Verify cluster degradation handling
podman logs indrajaal-app-1 2>&1 | grep -i "node down\|cluster"

# Reconnect
podman network connect indrajaal-test-net indrajaal-app-2
```

### 6.3 Database Failover Testing

```bash
# Stop primary database
podman stop indrajaal-db-primary

# Verify app behavior (should connect to replica or fail gracefully)
curl -f http://localhost:4000/health || echo "Health check failed"

# Restart primary
podman start indrajaal-db-primary
```

### 6.4 Resource Exhaustion Testing

```bash
# Stress test with limited memory
podman run --rm --memory=256m \
  localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 \
  mix compile

# Expected: OOM handling or graceful degradation
```

### 6.5 Chaos Test Script

```bash
#!/bin/bash
# scripts/chaos-test.sh

set -e

echo "=== Chaos Test Suite ==="

# Test 1: Container restart
echo "Test 1: Container restart..."
podman restart indrajaal-app-1
sleep 30
curl -f http://localhost:4000/health && echo "PASS" || echo "FAIL"

# Test 2: Database failover
echo "Test 2: Database failover..."
podman stop indrajaal-db-primary
sleep 10
podman start indrajaal-db-primary
sleep 30
curl -f http://localhost:4000/health && echo "PASS" || echo "FAIL"

# Test 3: Full cluster restart
echo "Test 3: Full cluster restart..."
podman-compose -f podman-compose-testing.yml restart
sleep 60
curl -f http://localhost:4000/health && echo "PASS" || echo "FAIL"

echo "=== Chaos Test Complete ==="
```

---

## 7. Resource Allocation

### 7.1 Container Limits

| Container | CPU | Memory | Purpose |
|-----------|-----|--------|---------|
| indrajaal-db-primary | 2.0 | 4GB | Primary database |
| indrajaal-db-replica | 2.0 | 4GB | Replica + connection pooling |
| indrajaal-app-1 | 4.0 | 4GB | Application node 1 |
| indrajaal-app-2 | 4.0 | 4GB | Application node 2 |
| indrajaal-app-3 | 4.0 | 4GB | Application node 3 |
| indrajaal-obs | 1.0 | 2GB | Observability |
| **Total** | **17.0** | **22GB** | |

### 7.2 Erlang VM Configuration

```bash
ELIXIR_ERL_OPTIONS="+S 4 +A 32 +K true +P 1048576"
ERL_MAX_PORTS=262144
```

| Option | Value | Purpose |
|--------|-------|---------|
| `+S 4` | 4 schedulers | Match CPU limit |
| `+A 32` | 32 async threads | I/O performance |
| `+K true` | Enable kernel poll | Better I/O handling |
| `+P 1048576` | 1M processes | High concurrency support |

---

## 8. Troubleshooting Guide

### 8.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "image not found" | Image not loaded | `podman load < result-app` |
| Port binding error | Port already in use | `podman stop` existing containers |
| Health check failing | Container not ready | Increase `start_period` |
| SSL certificate error | Missing CA certs | Mount `/etc/ssl/certs:ro` |

### 8.2 Debugging Commands

```bash
# View container logs
podman logs -f indrajaal-app-1

# Check container health
podman inspect --format='{{.State.Health.Status}}' indrajaal-app-1

# Enter container shell
podman exec -it indrajaal-app-1 bash

# View network configuration
podman network inspect indrajaal-test-net

# List all Indrajaal images
podman images | grep indrajaal
```

### 8.3 Recovery Procedures

```bash
# Full cleanup and restart
podman-compose -f podman-compose-testing.yml down -v
podman-compose -f podman-compose-testing.yml up -d

# Rebuild specific image
nix-build containers/sopv51-elixir-app.nix -o result-app
podman load < result-app
podman tag <new-id> localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28
```

---

## 9. Version Matrix

| Component | Dev | Test | Demo | Production |
|-----------|-----|------|------|------------|
| Elixir | 1.19.2 | 1.19.2 | 1.19.2 | 1.19.2 |
| OTP | 28 | 28 | 28 | 28 |
| PostgreSQL | 17 | 17 | 17 | 17 |
| TimescaleDB | 2.x | 2.x | 2.x | 2.x |
| NixOS | 25.05 | 25.05 | 25.05 | 25.05 |
| Podman | 5.4.1+ | 5.4.1+ | 5.4.1+ | 5.4.1+ |

---

## 10. Quick Start

```bash
# 1. Build containers (if not already done)
nix-build containers/sopv51-elixir-app.nix -o result-app
podman load < result-app
podman tag localhost/indrajaal-sopv51-elixir-app:nixos-25.05-unknown \
           localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28

# 2. Start test environment
podman-compose -f podman-compose-testing.yml up -d

# 3. Verify health
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 4. Run tests
podman exec indrajaal-app-1 mix test

# 5. Access application
open http://localhost:4000
```

---

**Document maintained by**: SOPv5.11 Cybernetic Framework
**STAMP Compliance**: SC-CNT-009, SC-CNT-010, SC-CNT-012, SC-CNT-014, AOR-CNT-001
**TDG Status**: Verified
