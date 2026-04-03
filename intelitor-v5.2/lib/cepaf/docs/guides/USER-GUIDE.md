# CEPAF User Guide

**Version**: 1.0.0
**Framework**: F# (.NET 8.0)
**Platform**: NixOS with Rootless Podman 5.4.1+
**STAMP Compliance**: IEC 61508 SIL-2, ISO 27001

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Environment Setup](#2-environment-setup)
3. [Container Management](#3-container-management)
4. [Observability](#4-observability)
5. [Troubleshooting](#5-troubleshooting)
6. [Command Reference](#6-command-reference)

---

## 1. Quick Start

### 1.1 Prerequisites

Ensure you have the following installed:
- .NET 8.0 SDK
- Podman 5.4.1+ (rootless mode)
- F# language support

### 1.2 Clone and Build

```bash
# Navigate to CEPAF directory
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf

# Restore NuGet dependencies
dotnet restore Cepaf.sln

# Build all projects
dotnet build Cepaf.sln

# Build for Release
dotnet build Cepaf.sln -c Release
```

### 1.3 Run Development Environment

```bash
# Start dev environment (3 core containers)
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -y

# Available environments: DEV, TEST, DEMO, PROD
```

### 1.4 Verify Container Health

```bash
# Check container status via Podman
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Expected output:
# NAMES           STATUS         PORTS
# indrajaal-db    Up 30 seconds  0.0.0.0:5433->5432/tcp
# indrajaal-app   Up 25 seconds  0.0.0.0:4000->4000/tcp
# indrajaal-obs   Up 20 seconds  0.0.0.0:8080->8080/tcp, ...
```

### 1.5 Run Test Suite

```bash
# Run all tests
dotnet test

# Run with verbose output
dotnet test --verbosity normal
```

---

## 2. Environment Setup

### 2.1 Dev Environment (3 Containers)

The minimal development environment consists of 3 core containers:

| Container | Purpose | Ports | Layer |
|-----------|---------|-------|-------|
| `indrajaal-db` | PostgreSQL 17 + TimescaleDB | 5433 | 0 |
| `indrajaal-app` | Phoenix/Elixir Application | 4000 | 1 |
| `indrajaal-obs` | Observability Stack | 8080, 4317, 3000 | 2 |

**Boot Sequence:**
```
Layer 0: indrajaal-db (no dependencies)
    |
    v
Layer 1: indrajaal-app (depends on db - Mandatory)
    |
    v
Layer 2: indrajaal-obs (depends on app - Optional)
```

**Start Dev Environment:**
```bash
# Via CEPAF CLI
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -y

# Via compose files
podman-compose -f artifacts/podman-compose-dev.yml up -d
```

### 2.2 Full Environment (6 Containers)

The full development environment adds sidecars:

| Container | Purpose | Ports | Layer |
|-----------|---------|-------|-------|
| `indrajaal-db` | PostgreSQL 17 | 5433 | 0 |
| `indrajaal-app` | Phoenix Application | 4000 | 1 |
| `localhost:6379 (integrated Redis)` | Redis Cache | 6379 | 1+ |
| `indrajaal-nginx` | Reverse Proxy | 80, 443 | 1+ |
| `indrajaal-obs` | Observability Core | 8080, 4317 | 2 |
| `indrajaal-grafana` | Grafana Dashboards | 3000 | 2+ |

**Start Full Environment:**
```bash
# Via CEPAF CLI
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV --full -y
```

### 2.3 Observability Stack (5 Components)

The observability stack runs as a sub-chain:

| Component | Purpose | Ports |
|-----------|---------|-------|
| `obs-clickhouse` | Time-series database | 8123, 9000 |
| `obs-otel-collector` | OpenTelemetry Collector | 4317 (gRPC), 4318 (HTTP) |
| `obs-query-service` | SigNoz Query Service | 8085 |
| `obs-frontend` | SigNoz UI | 8080 |
| `obs-grafana` | Grafana Dashboards | 3000 |

**Start Observability Only:**
```bash
# Via CEPAF CLI
dotnet run --project src/Cepaf/Cepaf.fsproj -- -o -y

# Via compose file
podman-compose -f artifacts/podman-compose-obs-standalone.yml up -d
```

### 2.4 Environment Variables

Set these environment variables for optimal operation:

```bash
# Patient Mode (extended timeouts for compilation)
export NO_TIMEOUT=true
export PATIENT_MODE=enabled
export INFINITE_PATIENCE=true
export ELIXIR_ERL_OPTIONS="+S 16"

# Podman Socket (rootless)
export XDG_RUNTIME_DIR=/run/user/$(id -u)
# Socket path: $XDG_RUNTIME_DIR/podman/podman.sock

# Telemetry Configuration
export OTEL_SERVICE_NAME=indrajaal
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1
```

### 2.5 Network Configuration

CEPAF uses dedicated Podman networks:

| Network | Subnet | Purpose |
|---------|--------|---------|
| `indrajaal-net` | 172.30.0.0/24 | Main application network |
| `indrajaal-obs-net` | 172.31.0.0/24 | Observability network |

**IP Assignments (Dev Chain):**
```
indrajaal-db:      172.30.0.10
indrajaal-app:     172.30.0.20
indrajaal-obs:     172.30.0.30
localhost:6379 (integrated Redis):   172.30.0.20 (shares with app)
indrajaal-nginx:   172.30.0.20 (shares with app)
indrajaal-grafana: 172.30.0.30 (shares with obs)
```

---

## 3. Container Management

### 3.1 Starting the Service Chain

**Method 1: CEPAF CLI (Recommended)**
```bash
# Dev environment with auto-confirm
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -y

# With formal verification
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -v -y

# Patient mode (extended timeouts)
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -p -y

# Skip VTO sterilization
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV --no-sterilize -y
```

**Method 2: Direct Compose**
```bash
cd /home/an/dev/ver/indrajaal-v5.2/lib/cepaf

# Database standalone
podman-compose -f artifacts/podman-compose-db-standalone.yml up -d

# Observability standalone
podman-compose -f artifacts/podman-compose-obs-standalone.yml up -d

# Full dev environment
podman-compose -f artifacts/podman-compose-dev.yml up -d
```

### 3.2 Health Checking

**Via CEPAF CLI:**
```bash
# Check container health status
dotnet run --project src/Cepaf/Cepaf.fsproj -- --status
```

**Via Podman:**
```bash
# List running containers with health
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# Inspect specific container health
podman healthcheck run indrajaal-db

# View health check logs
podman inspect indrajaal-db --format "{{json .State.Health}}" | jq
```

**Health Endpoints:**

| Container | Health Check | Port |
|-----------|--------------|------|
| indrajaal-db | `pg_isready` | 5433 |
| indrajaal-app | HTTP GET `/health` | 4000 |
| indrajaal-obs | HTTP GET `/api/status` | 8080 |
| obs-clickhouse | HTTP GET `/ping` | 8123 |
| obs-otel-collector | gRPC health check | 4317 |
| obs-grafana | HTTP GET `/api/health` | 3000 |

**FPPS Verification (5-Method Consensus):**
```bash
# Run FPPS verification via CLI
dotnet run --project src/Cepaf/Cepaf.fsproj -- --fpps

# FPPS Methods:
# 1. PodmanStatus - Container state from Podman API
# 2. HealthEndpoint - HTTP health check
# 3. PortProbe - TCP port connectivity
# 4. ProcessCheck - Process running check
# 5. LogAnalysis - Log error pattern detection
```

### 3.3 Stopping and Cleanup

**Graceful Shutdown (Recommended):**
```bash
# Stop in reverse boot order (obs -> app -> db)
dotnet run --project src/Cepaf/Cepaf.fsproj -- --stop

# Via compose
podman-compose -f artifacts/podman-compose-dev.yml down
```

**Emergency Stop:**
```bash
# Force stop all containers (SC-EMR-057: < 5 seconds)
podman stop -t 5 $(podman ps -q --filter "name=indrajaal-")

# VTO Sterilization (complete cleanup)
dotnet run --project src/Cepaf/Cepaf.fsproj -- --vto
```

**Cleanup Resources:**
```bash
# Remove stopped containers
podman rm $(podman ps -aq --filter "name=indrajaal-")

# Remove networks
podman network rm indrajaal-net indrajaal-obs-net

# Remove volumes (CAUTION: destroys data)
podman volume rm $(podman volume ls -q --filter "name=indrajaal-")

# Full cleanup
podman system prune --volumes -f
```

### 3.4 Container Logs

```bash
# View container logs
podman logs indrajaal-app

# Follow logs
podman logs -f indrajaal-app

# Last 100 lines
podman logs --tail 100 indrajaal-app

# Logs since timestamp
podman logs --since "2024-01-01T00:00:00" indrajaal-app

# All container logs
for c in indrajaal-db indrajaal-app indrajaal-obs; do
  echo "=== $c ===" && podman logs --tail 20 $c
done
```

---

## 4. Observability

### 4.1 Accessing SigNoz (Port 8080)

SigNoz provides distributed tracing, metrics, and logs.

**URL:** `http://localhost:8080`

**Default Credentials:**
- Email: admin@admin.com
- Password: admin123

**Features:**
- Distributed Traces
- Service Metrics
- Log Explorer
- Alerts
- Dashboards

**OTLP Configuration (for Elixir app):**
```elixir
# config/runtime.exs
config :opentelemetry, :processors, [
  otel_batch_processor: %{
    exporter: {:opentelemetry_exporter, %{
      endpoints: ["http://localhost:4317"]
    }}
  }
]
```

### 4.2 Accessing Grafana (Port 3000)

Grafana provides advanced dashboards and visualization.

**URL:** `http://localhost:3000`

**Default Credentials:**
- Username: admin
- Password: admin

**Pre-configured Datasources:**
- ClickHouse (for SigNoz data)
- Prometheus (for metrics)

**Pre-provisioned Dashboards:**
- Indrajaal System Overview
- Container Health
- OTEL Metrics

### 4.3 Viewing Traces and Metrics

**Trace Flow:**
```
Application (Elixir)
    |
    v [OTLP/gRPC :4317]
OTEL Collector
    |
    v
ClickHouse (Storage)
    |
    +---> SigNoz UI (Traces, Metrics, Logs)
    |
    +---> Grafana (Custom Dashboards)
```

**Verify Telemetry Flow:**
```bash
# Check OTEL Collector is receiving data
curl -s http://localhost:8888/metrics | grep otelcol_receiver

# Check ClickHouse tables
curl -s "http://localhost:8123/" --data "SELECT count() FROM signoz_traces.signoz_spans"

# Check SigNoz API
curl -s http://localhost:8080/api/v1/services | jq
```

### 4.4 STAMP Observability Compliance

CEPAF enforces these observability constraints:

**SC-OBS-069: Dual Logging**
- Terminal output (console)
- SigNoz logging (centralized)

**SC-OBS-071: 4 OTEL Modules**
- Traces (distributed tracing)
- Metrics (application metrics)
- Logs (structured logging)
- Baggage (context propagation)

**Verify Compliance:**
```bash
# Check OTEL modules in Elixir
mix deps | grep opentelemetry

# Expected modules:
# opentelemetry_api
# opentelemetry_sdk
# opentelemetry_exporter
# opentelemetry_phoenix
```

---

## 5. Troubleshooting

### 5.1 Container Not Starting

**Symptoms:**
- Container stays in "Created" state
- Container exits immediately after start

**Diagnosis:**
```bash
# Check container logs
podman logs indrajaal-app

# Check events
podman events --filter container=indrajaal-app --since 5m

# Inspect container
podman inspect indrajaal-app | jq '.[0].State'
```

**Common Causes:**

| Issue | Solution |
|-------|----------|
| Image not found | `podman pull localhost/indrajaal-app:nixos` |
| Port already in use | `lsof -i :4000` then stop conflicting process |
| Missing dependencies | Start dependent containers first |
| Resource limits | Check `podman system info` for available resources |

**Resolution:**
```bash
# Rebuild image
podman build -t localhost/indrajaal-app:nixos -f Dockerfile.app .

# Check for port conflicts
lsof -i :4000 :5433 :8080

# Force remove and restart
podman rm -f indrajaal-app
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -y
```

### 5.2 Health Check Failures

**Symptoms:**
- Container running but health check failing
- FPPS consensus not achieved

**Diagnosis:**
```bash
# Manual health check
curl -v http://localhost:4000/health

# Check internal health
podman exec indrajaal-app curl -s http://localhost:4000/health

# Database connectivity
podman exec indrajaal-db pg_isready -h localhost -p 5432

# OTEL endpoint
curl -v http://localhost:4317/
```

**Common Causes:**

| Issue | Health Check | Solution |
|-------|--------------|----------|
| App not ready | `/health` fails | Wait for initialization |
| DB not accepting connections | `pg_isready` fails | Check DB logs |
| Network isolation | Cannot reach other containers | Verify network config |
| Process crash | ProcessCheck fails | Check container logs |

**Resolution:**
```bash
# Check network connectivity
podman exec indrajaal-app ping -c 3 indrajaal-db

# Verify service is listening
podman exec indrajaal-app netstat -tlnp

# Restart with health check debugging
podman run --rm --health-cmd "curl -f http://localhost:4000/health" \
  --health-interval=10s --health-retries=3 \
  localhost/indrajaal-app:nixos
```

### 5.3 Port Conflicts

**Symptoms:**
- "Address already in use" error
- Container fails to start

**Diagnosis:**
```bash
# Find processes using ports
lsof -i :4000
lsof -i :5433
lsof -i :8080
lsof -i :4317
lsof -i :3000

# List all listening ports
ss -tlnp
```

**Resolution:**
```bash
# Stop conflicting process
kill $(lsof -t -i :4000)

# Use alternative ports (modify compose file)
# Or stop other containers first
podman stop $(podman ps -q)
```

**Default Ports Reference:**

| Service | Port | Alternative |
|---------|------|-------------|
| Database | 5433 | 5434 |
| Application | 4000 | 4001 |
| SigNoz UI | 8080 | 8081 |
| OTEL gRPC | 4317 | 4319 |
| OTEL HTTP | 4318 | 4320 |
| Grafana | 3000 | 3001 |
| ClickHouse HTTP | 8123 | 8124 |

### 5.4 Log Analysis

**Finding Errors:**
```bash
# Search for errors in all container logs
for c in indrajaal-db indrajaal-app indrajaal-obs; do
  echo "=== $c ===" && podman logs $c 2>&1 | grep -E "ERROR|FATAL|CRITICAL|panic"
done

# Application-specific error patterns
podman logs indrajaal-app 2>&1 | grep -E "error|exception|failed"

# Database-specific
podman logs indrajaal-db 2>&1 | grep -E "FATAL|ERROR|could not"

# OTEL collector errors
podman logs obs-otel-collector 2>&1 | grep -E "failed to export|connection refused"
```

**Log Locations:**
```
lib/cepaf/artifacts/
+-- logs/
    +-- db/           # Database logs
    +-- app/          # Application logs
    +-- obs/          # Observability logs
    +-- cepa.log      # CEPAF orchestration log
```

### 5.5 FPPS Verification Failures

**Symptoms:**
- "Consensus not achieved" error
- Some verification methods passing, others failing

**Diagnosis:**
```bash
# Run verbose FPPS verification
dotnet run --project src/Cepaf/Cepaf.fsproj -- --fpps --verbose
```

**Method-specific debugging:**

| Method | Check | Command |
|--------|-------|---------|
| PodmanStatus | Container running | `podman ps -a \| grep indrajaal` |
| HealthEndpoint | HTTP 200 OK | `curl -v http://localhost:4000/health` |
| PortProbe | TCP open | `nc -zv localhost 4000` |
| ProcessCheck | Main process | `podman top indrajaal-app` |
| LogAnalysis | No ERROR patterns | `podman logs indrajaal-app \| grep ERROR` |

---

## 6. Command Reference

### 6.1 dotnet Build Commands

```bash
# Restore dependencies
dotnet restore Cepaf.sln

# Build (Debug)
dotnet build Cepaf.sln

# Build (Release)
dotnet build Cepaf.sln -c Release

# Build specific project
dotnet build src/Cepaf/Cepaf.fsproj

# Publish self-contained executable
dotnet publish src/Cepaf/Cepaf.fsproj -c Release -r linux-x64 --self-contained

# Clean build artifacts
dotnet clean
```

### 6.2 dotnet Test Commands

```bash
# Run all tests
dotnet test

# Run with verbose output
dotnet test --verbosity normal

# Run specific test project
dotnet test src/Cepaf.Tests/Cepaf.Tests.fsproj

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Filter tests
dotnet test --filter "FullyQualifiedName~PathResolver"
```

### 6.3 CEPAF CLI Commands

```bash
# Show help
dotnet run --project src/Cepaf/Cepaf.fsproj -- --help

# Environment options
-e, --env <ENV>         Target environment (DEV, TEST, DEMO, PROD)
-y, --yes               Auto-confirm prompts
-p, --patient-mode      Extended timeouts

# Verification options
-v, --verify            Enable formal verification
--fpps                  Run FPPS 5-method verification
--status                Show container status

# Test modes
-d, --db-test           Database standalone test
-o, --obs-test          Observability standalone test
--test                  Run Elixir test suite
--ui                    Run UI verification

# Build options
--no-sterilize          Skip VTO sterilization
--no-build              Skip container build
-i, --no-infra          Skip infrastructure checks

# Management
--stop                  Stop all containers
--vto                   VTO sterilization (full cleanup)
```

### 6.4 Container Management Commands

```bash
# List containers
podman ps -a --filter "name=indrajaal-"

# Start container
podman start indrajaal-db

# Stop container
podman stop indrajaal-app

# Restart container
podman restart indrajaal-obs

# Remove container
podman rm -f indrajaal-app

# Execute command in container
podman exec indrajaal-db psql -U indrajaal -c "SELECT 1"

# View logs
podman logs -f --tail 100 indrajaal-app

# Health check
podman healthcheck run indrajaal-db

# Inspect container
podman inspect indrajaal-app | jq '.[0].State'
```

### 6.5 Compose Commands

```bash
# Start services
podman-compose -f artifacts/podman-compose-dev.yml up -d

# Stop services
podman-compose -f artifacts/podman-compose-dev.yml down

# Restart services
podman-compose -f artifacts/podman-compose-dev.yml restart

# View logs
podman-compose -f artifacts/podman-compose-dev.yml logs -f

# Scale (if applicable)
podman-compose -f artifacts/podman-compose-dev.yml up -d --scale app=3
```

### 6.6 Verification Commands

```bash
# Full FPPS verification
dotnet run --project src/Cepaf/Cepaf.fsproj -- --fpps

# Database standalone verification
dotnet run --project src/Cepaf/Cepaf.fsproj -- -d -y

# Observability standalone verification
dotnet run --project src/Cepaf/Cepaf.fsproj -- -o -y

# Formal verification gate
dotnet run --project src/Cepaf/Cepaf.fsproj -- -e DEV -v -y
```

---

## Appendix A: Environment Quick Reference

| Environment | Containers | Compose File |
|-------------|------------|--------------|
| DEV (minimal) | 3 | `podman-compose-dev.yml` |
| DEV (full) | 6 | `podman-compose-dev-full.yml` |
| TEST | 3 | `podman-compose-test.yml` |
| DB Standalone | 1 | `podman-compose-db-standalone.yml` |
| OBS Standalone | 5 | `podman-compose-obs-standalone.yml` |

## Appendix B: Port Reference

| Port | Service | Protocol |
|------|---------|----------|
| 4000 | Phoenix Application | HTTP |
| 5433 | PostgreSQL | TCP |
| 8080 | SigNoz UI | HTTP |
| 4317 | OTEL Collector gRPC | gRPC |
| 4318 | OTEL Collector HTTP | HTTP |
| 3000 | Grafana | HTTP |
| 8123 | ClickHouse HTTP | HTTP |
| 9000 | ClickHouse Native | TCP |
| 8085 | SigNoz Query Service | HTTP |
| 6379 | Redis | TCP |
| 80/443 | Nginx | HTTP/HTTPS |

## Appendix C: STAMP Constraints Quick Reference

| Constraint | Description |
|------------|-------------|
| SC-CNT-009 | NixOS/Podman only |
| SC-CNT-010 | Localhost registry only |
| SC-CNT-012 | Rootless Podman |
| SC-CEP-003 | FPPS 5-method consensus |
| SC-VAL-003 | 100% consensus required |
| SC-AGT-018 | No deadlocks |
| SC-OBS-069 | Dual logging |
| SC-OBS-071 | 4 OTEL modules |
| SC-EMR-057 | Emergency stop < 5s |
