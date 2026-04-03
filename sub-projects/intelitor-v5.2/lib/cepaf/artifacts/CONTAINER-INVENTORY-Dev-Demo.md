# CEPAF Container Inventory - Dev & Demo Environments
**Version**: 1.0.0
**Date**: 2025-12-24
**STAMP Compliance**: SC-CNT-009, SC-CNT-010, SC-CNT-012

---

## 1. Executive Summary

This document provides a comprehensive inventory of all containers used in the Indrajaal Dev and Demo environments, including their configurations, dependencies, port mappings, and health check specifications.

---

## 2. Container Registry

| Container Name | Image | Environment | Purpose |
|----------------|-------|-------------|---------|
| `indrajaal-app` | `localhost/indrajaal-app:nixos` | Dev/Demo | Phoenix Application Server |
| `indrajaal-db` | `localhost/indrajaal-db:nixos` | Dev/Demo | PostgreSQL 17 + TimescaleDB |
| `indrajaal-db-standalone` | `localhost/indrajaal-db:nixos` | Test | Standalone DB for testing |
| `indrajaal-obs` | `localhost/indrajaal-observability:nixos` | Dev/Demo | Unified Observability Stack |
| `indrajaal-obs-standalonetest` | `localhost/indrajaal-observability:nixos` | Test | Standalone OBS for testing |

---

## 3. Container Specifications

### 3.1 indrajaal-app (Application Server)

```yaml
Container: indrajaal-app
Image: localhost/indrajaal-app:nixos
Base: NixOS 24.11

# Ports
Exposed:
  - 4000:4000  # Phoenix HTTP
  - 4001:4001  # Phoenix HTTPS (optional)
  - 9568:9568  # Prometheus metrics

# Environment Variables
PHX_HOST: localhost
PHX_SERVER: true
DATABASE_URL: ecto://postgres:postgres@indrajaal-db:5433/indrajaal_dev
SECRET_KEY_BASE: <generated>
OTEL_EXPORTER_OTLP_ENDPOINT: http://indrajaal-obs:4317
MIX_ENV: dev|demo

# Resources
Memory: 2Gi (min), 4Gi (recommended)
CPU: 2 cores (min), 4 cores (recommended)

# Dependencies
requires:
  - indrajaal-db (mandatory)
  - indrajaal-obs (optional, degraded mode if missing)

# Health Checks
startup_probe:
  http_get:
    path: /health
    port: 4000
  initial_delay_seconds: 30
  period_seconds: 5
  failure_threshold: 12  # 60s max startup

liveness_probe:
  http_get:
    path: /live
    port: 4000
  period_seconds: 10
  failure_threshold: 3

readiness_probe:
  http_get:
    path: /ready
    port: 4000
  period_seconds: 5
  failure_threshold: 2

# Volumes
mounts:
  - ./priv/static:/app/priv/static:ro
  - ./uploads:/app/uploads:rw
```

### 3.2 indrajaal-db (Database Server)

```yaml
Container: indrajaal-db
Image: localhost/indrajaal-db:nixos
Base: NixOS 24.11 + PostgreSQL 17 + TimescaleDB

# Ports
Exposed:
  - 5433:5432  # PostgreSQL (non-standard to avoid conflicts)

# Environment Variables
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
POSTGRES_DB: indrajaal_dev

# Resources
Memory: 1Gi (min), 2Gi (recommended)
CPU: 1 core (min), 2 cores (recommended)
Storage: 10Gi (min), 50Gi (recommended)

# Dependencies
requires: []  # No dependencies - primary container

# Health Checks
startup_probe:
  exec:
    command: ["pg_isready", "-h", "127.0.0.1", "-p", "5432", "-U", "postgres"]
  initial_delay_seconds: 5
  period_seconds: 2
  failure_threshold: 15  # 30s max startup

liveness_probe:
  exec:
    command: ["pg_isready", "-h", "127.0.0.1", "-p", "5432"]
  period_seconds: 10
  failure_threshold: 3

readiness_probe:
  exec:
    command: ["psql", "-h", "127.0.0.1", "-p", "5432", "-U", "postgres", "-c", "SELECT 1"]
  period_seconds: 5
  failure_threshold: 2

# Volumes
mounts:
  - indrajaal-db-data:/var/lib/postgresql/data:rw

# Features
extensions:
  - timescaledb
  - pg_stat_statements
  - uuid-ossp
```

### 3.3 indrajaal-obs (Observability Stack)

```yaml
Container: indrajaal-obs
Image: localhost/indrajaal-observability:nixos
Base: NixOS 24.11

# Internal Services
services:
  clickhouse:
    port: 8123  # HTTP API
  prometheus:
    port: 9090  # Web UI / API
  grafana:
    port: 3000  # Web UI
  otel-collector:
    ports:
      - 4317  # gRPC receiver
      - 4318  # HTTP receiver

# External Ports
Exposed:
  - 8123:8123  # ClickHouse HTTP
  - 9090:9090  # Prometheus
  - 3000:3000  # Grafana
  - 4317:4317  # OTEL gRPC
  - 4318:4318  # OTEL HTTP

# Resources
Memory: 2Gi (min), 4Gi (recommended)
CPU: 2 cores (min), 4 cores (recommended)
Storage: 20Gi (min) for ClickHouse data

# Dependencies
requires: []  # No dependencies - standalone stack

# Health Checks
startup_probe:
  exec:
    command: ["sh", "-c", "curl -sf http://localhost:8123/ping && curl -sf http://localhost:9090/-/healthy && nc -z localhost 4317"]
  initial_delay_seconds: 10
  period_seconds: 5
  failure_threshold: 12  # 60s max startup

liveness_probe:
  exec:
    command: ["curl", "-sf", "http://localhost:9090/-/healthy"]
  period_seconds: 30
  failure_threshold: 3

readiness_probe:
  exec:
    command: ["sh", "-c", "nc -z localhost 4317 && nc -z localhost 4318"]
  period_seconds: 10
  failure_threshold: 2

# Volumes
mounts:
  - indrajaal-clickhouse-data:/var/lib/clickhouse:rw
  - indrajaal-prometheus-data:/prometheus:rw
  - indrajaal-grafana-data:/var/lib/grafana:rw
```

---

## 4. Port Mapping Summary

| Port | Container | Service | Protocol |
|------|-----------|---------|----------|
| 3000 | indrajaal-obs | Grafana UI | HTTP |
| 4000 | indrajaal-app | Phoenix HTTP | HTTP |
| 4001 | indrajaal-app | Phoenix HTTPS | HTTPS |
| 4317 | indrajaal-obs | OTEL Collector gRPC | gRPC |
| 4318 | indrajaal-obs | OTEL Collector HTTP | HTTP |
| 5433 | indrajaal-db | PostgreSQL | TCP |
| 8123 | indrajaal-obs | ClickHouse HTTP | HTTP |
| 9090 | indrajaal-obs | Prometheus | HTTP |
| 9568 | indrajaal-app | Prometheus Metrics | HTTP |

---

## 5. Network Configuration

```yaml
Network: indrajaal-net
Driver: bridge
Subnet: 172.20.0.0/16

Container IPs (Static Assignment):
  indrajaal-db: 172.20.0.10
  indrajaal-obs: 172.20.0.20
  indrajaal-app: 172.20.0.30

DNS Resolution:
  indrajaal-db.indrajaal-net -> 172.20.0.10
  indrajaal-obs.indrajaal-net -> 172.20.0.20
  indrajaal-app.indrajaal-net -> 172.20.0.30
```

---

## 6. Volume Specifications

| Volume Name | Container | Mount Path | Purpose |
|-------------|-----------|------------|---------|
| `indrajaal-db-data` | indrajaal-db | /var/lib/postgresql/data | Database persistence |
| `indrajaal-clickhouse-data` | indrajaal-obs | /var/lib/clickhouse | ClickHouse data |
| `indrajaal-prometheus-data` | indrajaal-obs | /prometheus | Prometheus TSDB |
| `indrajaal-grafana-data` | indrajaal-obs | /var/lib/grafana | Grafana dashboards/config |

---

## 7. Environment Differences

### 7.1 Dev Environment

```yaml
Compose File: podman-compose.yml
Mode: Development
Features:
  - Hot code reload enabled
  - Debug logging
  - All services run
  - Mock data seeded

App Environment:
  MIX_ENV: dev
  PHX_SERVER: true
  LOG_LEVEL: debug
```

### 7.2 Demo Environment

```yaml
Compose File: podman-compose-demo.yml
Mode: Demo/Presentation
Features:
  - Pre-seeded realistic data
  - Optimized for demonstrations
  - Production-like settings

App Environment:
  MIX_ENV: prod
  PHX_SERVER: true
  LOG_LEVEL: info
  DEMO_MODE: true
```

---

## 8. STAMP Safety Constraints

| Constraint | Description | Verification |
|------------|-------------|--------------|
| SC-CNT-009 | NixOS containers only | ✓ All images use NixOS base |
| SC-CNT-010 | Localhost registry only | ✓ All images from `localhost/` |
| SC-CNT-012 | Rootless Podman | ✓ No root privileges required |
| SC-OBS-065 | Container health probes | ✓ All containers have health checks |
| SC-CEP-004 | 30s boot threshold | ✓ Full stack boots in <30s |

---

## 9. Commands Reference

```bash
# Start full dev stack
podman-compose -f podman-compose.yml up -d

# Start standalone DB
podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml up -d

# Start standalone OBS
podman-compose -f lib/cepaf/artifacts/podman-compose-obs-standalone.yml up -d

# Check container health
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View logs
podman logs -f indrajaal-app
podman logs -f indrajaal-db
podman logs -f indrajaal-obs

# Execute shell in container
podman exec -it indrajaal-app bash
podman exec -it indrajaal-db psql -U postgres

# Stop all containers
podman-compose -f podman-compose.yml down
```

---

**Document Owner**: Claude Cybernetic Architect
**Last Updated**: 2025-12-24 01:30 CET
