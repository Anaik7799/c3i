# User Guide: Standalone App Container System
## Indrajaal v5.2 - DAG-Based Container Testing Framework

**Version**: 1.0.0
**Date**: 2025-12-24
**Compliance**: SOPv5.11, STAMP, SC-CNT-009, SC-VAL-001
**Audience**: Developers, DevOps Engineers, QA Engineers

---

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Quick Start Guide](#2-quick-start-guide)
3. [Container Operations](#3-container-operations)
4. [Health Monitoring](#4-health-monitoring)
5. [Logging and Debugging](#5-logging-and-debugging)
6. [Configuration Reference](#6-configuration-reference)
7. [Common Tasks](#7-common-tasks)
8. [Troubleshooting](#8-troubleshooting)
9. [Best Practices](#9-best-practices)
10. [Command Reference](#10-command-reference)
11. [FAQ](#11-faq)
12. [Appendix](#12-appendix)

---

## 1. Getting Started

### 1.1 Prerequisites

Before using the standalone app container system, ensure you have:

| Requirement | Version | Verification Command |
|-------------|---------|---------------------|
| Podman | 5.4.1+ | `podman --version` |
| podman-compose | 1.0.0+ | `podman-compose --version` |
| NixOS/devenv | Latest | `devenv --version` |
| PostgreSQL client | 15+ | `psql --version` |
| curl | Latest | `curl --version` |
| jq | Latest | `jq --version` |

### 1.2 System Requirements

```
Minimum Requirements:
├── CPU: 4 cores (8 recommended for Patient Mode)
├── RAM: 8GB (16GB recommended)
├── Disk: 20GB free space
└── Network: Access to localhost ports 4000, 5433, 8123
```

### 1.3 Directory Structure

```
/home/an/dev/ver/indrajaal-v5.2/
├── lib/cepaf/
│   ├── artifacts/           # Podman compose files
│   │   ├── podman-compose-app-standalone.yml
│   │   ├── podman-compose-app-debug.yml
│   │   └── podman-compose-db-standalone.yml
│   └── docs/                # Documentation (you are here)
├── config/
│   └── runtime.exs          # Runtime configuration
├── data/tmp/                # Logs and temporary files
└── journal/                 # Session journals
```

---

## 2. Quick Start Guide

### 2.1 5-Minute Setup

Follow these steps to get a running container in 5 minutes:

```bash
# Step 1: Navigate to project directory
cd /home/an/dev/ver/indrajaal-v5.2

# Step 2: Start database container (if not running)
podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml up -d

# Step 3: Wait for database health (30 seconds)
sleep 30

# Step 4: Verify database
podman exec indrajaal-db-standalone pg_isready -U postgres
# Expected: localhost:5433 - accepting connections

# Step 5: Start app container
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml up -d

# Step 6: Verify health (wait 2-5 minutes for compilation)
curl -sf http://localhost:4000/health | jq .
```

### 2.2 Expected Output

After successful startup, you should see:

```json
{
  "status": "ok",
  "liveness": {
    "memory": "ok",
    "scheduler": "ok",
    "beam_vm": "ok"
  },
  "startup": {
    "application": "ok",
    "endpoint": "ok",
    "supervision_tree": "ok"
  },
  "readiness": {
    "telemetry": "ok",
    "database": "ok",
    "pubsub": "ok",
    "redis": "ok"
  }
}
```

Note: Redis runs as an integrated daemon inside the app container (localhost:6379),
not as a separate container. All readiness checks should show "ok" status.

### 2.3 Visual Status Check (3-Container Architecture)

```
                    ┌─────────────────────────────────────────┐
                    │   3-CONTAINER STANDALONE STACK STATUS   │
                    └─────────────────────────────────────────┘
                                       │
          ┌────────────────────────────┼────────────────────────────┐
          ▼                            ▼                            ▼
    ┌──────────────┐        ┌────────────────────┐        ┌──────────────┐
    │ DB Container │        │   APP Container    │        │ OBS Container│
    │ indrajaal-db │        │ indrajaal-app      │        │ indrajaal-obs│
    │    :5433     │───────▶│  :4000  :4001      │───────▶│ :4317  :8123 │
    └──────────────┘        │                    │        │ :3000  :9090 │
          │                 │  ┌──────────────┐  │        └──────────────┘
          ▼                 │  │Integrated    │  │              │
    pg_isready              │  │Redis :6379   │  │              ▼
    accepting               │  └──────────────┘  │        ClickHouse
                            └────────────────────┘        Prometheus
                                   │                      Grafana
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
               /healthz       redis-cli       OODA Loop
               /ready          ping           running
               /startup
```

**Verify all components:**
```bash
# Database
podman exec indrajaal-db-standalone pg_isready -U postgres -p 5433

# App + Integrated Redis
curl -sf http://localhost:4000/healthz
podman exec indrajaal-app-standalone redis-cli ping

# Observability
curl -sf http://localhost:8123/ping  # ClickHouse
curl -sf http://localhost:9090/-/healthy  # Prometheus
curl -sf http://localhost:3000/api/health  # Grafana
```

---

## 3. Container Operations

### 3.1 Starting Containers

#### Standard Mode (Recommended for Production Testing)
```bash
# Start with standard compose file
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml up -d

# View startup logs
podman logs -f indrajaal-app-standalone
```

#### Debug Mode (Recommended for Development)
```bash
# Start with verbose debug logging
podman-compose -f lib/cepaf/artifacts/podman-compose-app-debug.yml up -d

# Monitor debug output
podman logs -f indrajaal-app-standalone 2>&1 | grep -E "\[DEBUG\]|\[PHASE\]|\[ERROR\]"
```

### 3.2 Stopping Containers

```bash
# Graceful stop (recommended)
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down

# Force stop (if unresponsive)
podman stop -t 10 indrajaal-app-standalone
podman rm indrajaal-app-standalone

# Stop all related containers
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down
podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml down
```

### 3.3 Restarting Containers

```bash
# Restart app only
podman restart indrajaal-app-standalone

# Full restart (recommended after config changes)
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml up -d
```

### 3.4 Container Status

```bash
# List running containers
podman ps --filter name=indrajaal

# Detailed status
podman inspect indrajaal-app-standalone --format '{{.State.Status}} - {{.State.Health.Status}}'

# Resource usage
podman stats indrajaal-app-standalone --no-stream
```

---

## 4. Health Monitoring

### 4.1 Health Endpoints

| Endpoint | Purpose | Expected Response |
|----------|---------|-------------------|
| `/healthz` | Kubernetes liveness | `{"status":"ok","probe":"liveness"}` |
| `/ready` | Kubernetes readiness | `{"status":"ready"}` or `{"status":"not_ready"}` |
| `/startup` | Kubernetes startup | `{"status":"started","uptime_ms":...}` |
| `/health` | Comprehensive check | Full JSON with all subsystems |

### 4.2 Checking Health

```bash
# Quick liveness check
curl -sf http://localhost:4000/healthz

# Readiness check
curl -sf http://localhost:4000/ready

# Startup check with uptime
curl -sf http://localhost:4000/startup | jq .

# Full comprehensive health
curl -sf http://localhost:4000/health | jq .
```

### 4.3 Monitoring Script

Save this as `monitor_health.sh`:

```bash
#!/bin/bash
# Health monitoring script for Indrajaal app container

ENDPOINT="http://localhost:4000"
INTERVAL=5

echo "=== Indrajaal Health Monitor ==="
echo "Checking every ${INTERVAL}s... (Ctrl+C to stop)"
echo ""

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Liveness
    LIVENESS=$(curl -sf "${ENDPOINT}/healthz" 2>/dev/null | jq -r '.status // "error"')

    # Readiness
    READINESS=$(curl -sf "${ENDPOINT}/ready" 2>/dev/null | jq -r '.status // "error"')

    # Startup uptime
    UPTIME=$(curl -sf "${ENDPOINT}/startup" 2>/dev/null | jq -r '.uptime_ms // 0')

    # Format uptime
    if [ "$UPTIME" -gt 0 ]; then
        UPTIME_FMT=$(echo "scale=1; $UPTIME / 1000 / 60" | bc)m
    else
        UPTIME_FMT="N/A"
    fi

    # Print status line
    printf "[%s] Liveness: %-6s | Readiness: %-10s | Uptime: %s\n" \
        "$TIMESTAMP" "$LIVENESS" "$READINESS" "$UPTIME_FMT"

    sleep $INTERVAL
done
```

### 4.4 Health Status Interpretation

```
┌─────────────────────────────────────────────────────────────┐
│                    HEALTH STATUS GUIDE                      │
├─────────────────────────────────────────────────────────────┤
│ STATUS          │ MEANING                  │ ACTION         │
├─────────────────┼──────────────────────────┼────────────────┤
│ Liveness: ok    │ Container is alive       │ None           │
│ Liveness: error │ Container may be dead    │ Restart        │
├─────────────────┼──────────────────────────┼────────────────┤
│ Readiness: ready│ Ready to serve traffic   │ None           │
│ Readiness: not_ │ Not ready (deps missing) │ Check deps     │
├─────────────────┼──────────────────────────┼────────────────┤
│ Startup: started│ Initialization complete  │ None           │
│ Startup: error  │ Failed to start          │ Check logs     │
└─────────────────┴──────────────────────────┴────────────────┘
```

---

## 5. Logging and Debugging

### 5.1 Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| `debug` | Detailed tracing | OODA cycle events |
| `info` | Normal operations | Request processing |
| `warning` | Potential issues | Slow queries |
| `error` | Errors | Failed connections |
| `emergency` | Critical failures | System shutdown |

### 5.2 Viewing Logs

```bash
# All logs
podman logs indrajaal-app-standalone

# Follow logs (live)
podman logs -f indrajaal-app-standalone

# Last 100 lines
podman logs --tail 100 indrajaal-app-standalone

# Logs since timestamp
podman logs --since "2025-12-24T08:00:00" indrajaal-app-standalone

# Filter for errors
podman logs indrajaal-app-standalone 2>&1 | grep -E "\[error\]|\[ERROR\]"

# Filter for specific component
podman logs indrajaal-app-standalone 2>&1 | grep -E "Ecto|Phoenix|Bandit"
```

### 5.3 Log Analysis

```bash
# Count log levels
podman logs indrajaal-app-standalone 2>&1 | grep -c "\[info\]"
podman logs indrajaal-app-standalone 2>&1 | grep -c "\[error\]"
podman logs indrajaal-app-standalone 2>&1 | grep -c "\[warning\]"

# Find slow operations (>1s)
podman logs indrajaal-app-standalone 2>&1 | grep -E "taking more than|timeout|slow"

# OODA loop status
podman logs indrajaal-app-standalone 2>&1 | grep "OODA" | tail -5
```

### 5.4 Debug Mode

To enable verbose debugging:

```bash
# Use debug compose file
podman-compose -f lib/cepaf/artifacts/podman-compose-app-debug.yml up -d

# Debug environment variables are set:
# MIX_DEBUG=1
# LOGGER_LEVEL=debug
# ECTO_DEBUG=true
# OTEL_LOG_LEVEL=debug
# CEPAF_DEBUG=1
# CEPAF_VERBOSE=1
```

### 5.5 Real-time Log Filtering

```bash
# Phase-based progress
podman logs -f indrajaal-app-standalone 2>&1 | grep -E "^\[PHASE"

# Compilation progress
podman logs -f indrajaal-app-standalone 2>&1 | grep -E "Compiling|Generated"

# Database operations
podman logs -f indrajaal-app-standalone 2>&1 | grep -E "Ecto|migration|database"

# HTTP requests
podman logs -f indrajaal-app-standalone 2>&1 | grep -E "GET|POST|PUT|DELETE"
```

---

## 6. Configuration Reference

### 6.1 Environment Variables

#### Essential Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MIX_ENV` | `test` | Elixir environment |
| `PHX_SERVER` | `true` | Enable Phoenix HTTP server |
| `PHX_PORT` | `4000` | HTTP listening port |
| `DATABASE_URL` | See below | PostgreSQL connection |
| `LOG_LEVEL` | `info` | Logging verbosity |

#### Patient Mode Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `NO_TIMEOUT` | `true` | Disable all timeouts |
| `PATIENT_MODE` | `enabled` | Enable patient compilation |
| `INFINITE_PATIENCE` | `true` | Never interrupt compilation |
| `ELIXIR_ERL_OPTIONS` | `+S 10:10 +fnu` | BEAM scheduler config |

#### Debug Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `MIX_DEBUG` | `1` | Mix task debugging |
| `LOGGER_LEVEL` | `debug` | Full log output |
| `ECTO_DEBUG` | `true` | SQL query logging |
| `OTEL_LOG_LEVEL` | `debug` | Telemetry debug |
| `CEPAF_DEBUG` | `1` | Framework debug |
| `CEPAF_VERBOSE` | `1` | Verbose output |

### 6.2 Database Configuration

```bash
# Connection URL format
DATABASE_URL="ecto://USER:PASSWORD@HOST:PORT/DATABASE"

# Default for standalone testing
DATABASE_URL="ecto://postgres:postgres@indrajaal-db-standalone:5433/indrajaal_standalone"

# Individual variables (alternative)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_HOST=indrajaal-db-standalone
POSTGRES_PORT=5433
POSTGRES_DB=indrajaal_standalone
```

### 6.3 Telemetry Configuration

```bash
# OpenTelemetry endpoint
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# Service identification
OTEL_SERVICE_NAME="indrajaal"
OTEL_SERVICE_VERSION="1.0.0"
OTEL_SERVICE_NAMESPACE="indrajaal"

# Deployment environment
OTEL_DEPLOYMENT_ENVIRONMENT="test"

# Sampling (development: always_on)
OTEL_TRACES_SAMPLER="always_on"
```

### 6.4 Configuration Files

| File | Purpose |
|------|---------|
| `config/runtime.exs` | Runtime configuration (env vars) |
| `config/test.exs` | Test environment config |
| `config/config.exs` | Base configuration |
| `podman-compose-*.yml` | Container orchestration |

---

## 7. Common Tasks

### 7.1 Running Tests in Container

```bash
# Enter container
podman exec -it indrajaal-app-standalone bash

# Run specific test
cd /workspace
MIX_ENV=test mix test test/indrajaal/accounts_test.exs

# Run with coverage
MIX_ENV=test mix test --cover

# Run in Patient Mode
NO_TIMEOUT=true PATIENT_MODE=enabled mix test
```

### 7.2 Database Operations

```bash
# Check database connectivity
podman exec indrajaal-app-standalone sh -c \
  "pg_isready -h indrajaal-db-standalone -p 5433 -U postgres"

# Run migrations
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && MIX_ENV=test mix ecto.migrate"

# Reset database
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && MIX_ENV=test mix ecto.reset"

# Database shell
podman exec -it indrajaal-db-standalone psql -U postgres -d indrajaal_standalone
```

### 7.3 Recompiling

```bash
# Full recompile
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && mix clean && mix compile"

# Patient Mode recompile
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && NO_TIMEOUT=true PATIENT_MODE=enabled mix compile"

# Check compilation status
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && mix compile --warnings-as-errors"
```

### 7.4 Phoenix Operations

```bash
# Restart Phoenix server
podman restart indrajaal-app-standalone

# Check Phoenix routes
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && mix phx.routes"

# Interactive shell with Phoenix
podman exec -it indrajaal-app-standalone sh -c \
  "cd /workspace && iex -S mix"
```

### 7.5 Cleaning Up

```bash
# Remove container but keep image
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down

# Remove container and volumes
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down -v

# Full cleanup (containers + images)
podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down --rmi all
podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml down --rmi all
```

---

## 8. Troubleshooting

### 8.1 Container Won't Start

**Symptoms**: Container exits immediately or keeps restarting.

```bash
# Check container logs
podman logs indrajaal-app-standalone

# Check for port conflicts
ss -tlnp | grep -E "4000|5433"

# Verify image exists
podman images | grep indrajaal

# Try starting manually
podman run -it --rm localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv bash
```

**Common causes**:
- Port 4000 already in use
- Missing database container
- Corrupted image

### 8.2 Health Check Failing

**Symptoms**: Container shows "unhealthy" status.

```bash
# Check what's listening
podman exec indrajaal-app-standalone ss -tlnp

# Verify Phoenix started
podman exec indrajaal-app-standalone sh -c "pgrep -f 'beam.smp'"

# Check health endpoint manually
podman exec indrajaal-app-standalone curl -v http://localhost:4000/health
```

**Solution**: Ensure `PHX_SERVER=true` is set in environment.

### 8.3 Database Connection Errors

**Symptoms**: Ecto connection errors in logs.

```bash
# Verify database is running
podman ps | grep indrajaal-db

# Test connectivity from app container
podman exec indrajaal-app-standalone sh -c \
  "pg_isready -h indrajaal-db-standalone -p 5433 -U postgres"

# Check network connectivity
podman exec indrajaal-app-standalone ping -c 3 indrajaal-db-standalone

# Verify DATABASE_URL
podman exec indrajaal-app-standalone env | grep DATABASE
```

**Solutions**:
- Ensure containers are on same network
- Check DATABASE_URL format
- Wait for database initialization (30-60s)

### 8.4 Compilation Stuck

**Symptoms**: Compilation takes longer than 10 minutes.

```bash
# Check compilation progress
podman logs indrajaal-app-standalone 2>&1 | grep -c "Compiling"

# Check for specific slow files
podman logs indrajaal-app-standalone 2>&1 | grep "taking more than"

# Check system resources
podman stats indrajaal-app-standalone --no-stream
```

**Solutions**:
- Ensure Patient Mode is enabled
- Increase container resources
- Check for circular dependencies

### 8.5 OODA Loop Not Running

**Symptoms**: No OODA cycle messages in logs.

```bash
# Check for OODA messages
podman logs indrajaal-app-standalone 2>&1 | grep "OODA"

# Verify process is running
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && iex -S mix -e 'IO.inspect Process.whereis(Indrajaal.Cybernetic.OODALoop)'"
```

**Solution**: Check supervision tree started correctly.

### 8.6 Quick Diagnostic Script

Save as `diagnose.sh`:

```bash
#!/bin/bash
echo "=== Indrajaal Container Diagnostics ==="
echo ""

echo "1. Container Status:"
podman ps -a --filter name=indrajaal --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "2. Health Endpoints:"
echo -n "   /healthz: "
curl -sf http://localhost:4000/healthz 2>/dev/null || echo "FAILED"
echo -n "   /ready: "
curl -sf http://localhost:4000/ready 2>/dev/null || echo "FAILED"
echo -n "   /startup: "
curl -sf http://localhost:4000/startup 2>/dev/null || echo "FAILED"
echo ""

echo "3. Database Connectivity:"
podman exec indrajaal-app-standalone pg_isready -h indrajaal-db-standalone -p 5433 -U postgres 2>/dev/null || echo "   FAILED"
echo ""

echo "4. Recent Errors:"
podman logs --tail 20 indrajaal-app-standalone 2>&1 | grep -E "\[error\]|\[ERROR\]" || echo "   No recent errors"
echo ""

echo "5. Resource Usage:"
podman stats indrajaal-app-standalone --no-stream 2>/dev/null || echo "   Container not running"
```

---

## 9. Best Practices

### 9.1 Development Workflow

1. **Always use debug mode for development**:
   ```bash
   podman-compose -f lib/cepaf/artifacts/podman-compose-app-debug.yml up -d
   ```

2. **Monitor logs in separate terminal**:
   ```bash
   podman logs -f indrajaal-app-standalone
   ```

3. **Wait for full startup before testing**:
   ```bash
   while ! curl -sf http://localhost:4000/healthz; do sleep 5; done
   echo "Container ready!"
   ```

### 9.2 Production Testing

1. **Use standard compose file**:
   ```bash
   podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml up -d
   ```

2. **Run DAG verification**:
   ```bash
   elixir scripts/testing/run_container_dag_tests.exs
   ```

3. **Check all health probes**:
   ```bash
   for probe in healthz ready startup health; do
     echo "$probe: $(curl -sf http://localhost:4000/$probe | jq -r '.status // "error"')"
   done
   ```

### 9.3 Cleanup Practices

1. **Regular cleanup** (weekly):
   ```bash
   podman system prune -f
   ```

2. **Before major updates**:
   ```bash
   podman-compose down -v
   podman rmi localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv
   ```

### 9.4 Security Best Practices

- Always use rootless Podman
- Never expose container ports to 0.0.0.0 in production
- Use secrets for sensitive environment variables
- Regularly update base images

---

## 10. Command Reference

### 10.1 Container Management

| Command | Description |
|---------|-------------|
| `podman ps` | List running containers |
| `podman ps -a` | List all containers |
| `podman logs CONTAINER` | View container logs |
| `podman logs -f CONTAINER` | Follow container logs |
| `podman exec -it CONTAINER bash` | Enter container shell |
| `podman stop CONTAINER` | Stop container |
| `podman start CONTAINER` | Start container |
| `podman restart CONTAINER` | Restart container |
| `podman rm CONTAINER` | Remove container |
| `podman stats CONTAINER` | Show resource usage |
| `podman inspect CONTAINER` | Detailed container info |

### 10.2 Compose Operations

| Command | Description |
|---------|-------------|
| `podman-compose up -d` | Start in background |
| `podman-compose down` | Stop and remove |
| `podman-compose down -v` | Stop, remove, and delete volumes |
| `podman-compose logs` | View all logs |
| `podman-compose ps` | List compose services |
| `podman-compose restart` | Restart all services |

### 10.3 Health Checks

| Command | Description |
|---------|-------------|
| `curl localhost:4000/healthz` | Liveness probe |
| `curl localhost:4000/ready` | Readiness probe |
| `curl localhost:4000/startup` | Startup probe |
| `curl localhost:4000/health` | Comprehensive health |

### 10.4 Database Operations

| Command | Description |
|---------|-------------|
| `pg_isready -h HOST -p PORT` | Check database ready |
| `mix ecto.create` | Create database |
| `mix ecto.migrate` | Run migrations |
| `mix ecto.reset` | Drop and recreate |
| `mix ecto.rollback` | Rollback migration |

---

## 11. FAQ

### Q: How long should startup take?

**A**: Initial startup with compilation: 3-5 minutes (Patient Mode). Subsequent restarts: 30-60 seconds.

### Q: Why is Redis showing as "error" in health check?

**A**: This is expected in standalone mode. The app container doesn't include Redis. For full stack testing, use the complete compose file.

### Q: Can I use Docker instead of Podman?

**A**: No. SC-CNT-009 mandates NixOS/Podman only. Docker is not supported.

### Q: How do I increase compilation speed?

**A**:
1. Ensure Patient Mode is enabled
2. Increase container resources: `--cpus 8 --memory 16g`
3. Use `ELIXIR_ERL_OPTIONS="+S 16:16"` for more schedulers

### Q: How do I access the IEx console?

**A**:
```bash
podman exec -it indrajaal-app-standalone sh -c "cd /workspace && iex -S mix"
```

### Q: How do I run a single test?

**A**:
```bash
podman exec indrajaal-app-standalone sh -c \
  "cd /workspace && MIX_ENV=test mix test test/path/to/test.exs:42"
```

### Q: What's the difference between standalone and debug modes?

**A**:
- **Standalone**: Standard configuration, production-like settings
- **Debug**: Verbose logging, all debug flags enabled, phase-by-phase output

### Q: How do I check the OODA cycle count?

**A**:
```bash
podman logs indrajaal-app-standalone 2>&1 | grep "OODA" | tail -1
```

### Q: How do I update the container image?

**A**:
1. Stop containers: `podman-compose down`
2. Remove image: `podman rmi localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv`
3. Rebuild: Run your image build script
4. Start: `podman-compose up -d`

---

## 12. Appendix

### 12.1 DAG Phase Reference

| Phase | Tasks | Description |
|-------|-------|-------------|
| P0 | 3 | Prerequisites (Image, Network, DB) |
| P1 | 1 | Container Creation |
| P2 | 4 | Setup (Hex, Rebar, Deps) |
| P3 | 3 | Database (Connect, Create, Migrate) |
| P4 | 4 | Compilation (Mix, Assets, Digest, Warnings) |
| P5 | 1 | Startup (Phoenix) |
| P6 | 3 | Health (TCP, HTTP, Logs) |
| P7 | 3 | Verification (API, Telemetry, E2E) |

### 12.2 STAMP Constraints Reference

| Constraint | Description |
|------------|-------------|
| SC-CNT-009 | NixOS/Podman runtime only |
| SC-CNT-010 | localhost/ registry only |
| SC-VAL-001 | Patient Mode required |
| SC-CMP-025 | Zero compilation warnings |
| SC-OBS-069 | Dual logging enabled |

### 12.3 Port Reference

| Port | Service | Protocol |
|------|---------|----------|
| 4000 | Phoenix HTTP | TCP |
| 4001 | LiveDashboard | TCP |
| 9568 | Prometheus metrics | TCP |
| 5433 | PostgreSQL | TCP |
| 4317 | OTLP gRPC | TCP |
| 8123 | SigNoz/ClickHouse | TCP |

### 12.4 Related Documentation

- [Architecture Guide](ARCHITECTURE-APP-CONTAINER-STANDALONE.md)
- [Implementation Guide](IMPLEMENTATION-APP-CONTAINER-STANDALONE.md)
- [Testing Guide](TESTING-APP-CONTAINER-STANDALONE.md)
- [DAG Verification](APP-CONTAINER-VERIFICATION-DAG.md)
- [Test Suite](TESTSUITE-APP_CONTAINER-Standalone.md)

### 12.5 Support

For issues or questions:
1. Check this troubleshooting guide
2. Review container logs
3. Check CLAUDE.md/GEMINI.md for system constraints
4. Create a journal entry documenting the issue

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-24
**Maintainer**: Claude Code / Cybernetic Architect
**Compliance**: SOPv5.11 + STAMP + TDG
