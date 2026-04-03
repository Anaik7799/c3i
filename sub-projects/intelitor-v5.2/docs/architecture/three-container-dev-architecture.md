# Three-Container Development Architecture

**Version**: 2.0.0
**Date**: 2025-12-19
**Status**: Production Ready
**Runtime**: Elixir 1.19.2 + OTP 28
**STAMP Compliance**: SC-CLU-001, SC-CNT-009, SC-CNT-012, SC-CNT-014

---

> ## MANDATORY ENFORCEMENT: PODMAN ONLY
>
> **All container operations in this architecture MUST use Podman.**
>
> | Requirement | Enforcement |
> |-------------|-------------|
> | Container Runtime | Podman >= 5.4.1 (rootless) |
> | Compose Tool | podman-compose (NOT docker-compose) |
> | Image Registry | localhost/ only |
> | Base OS | NixOS containers only |
>
> **FORBIDDEN (per SC-CNT-009, AOR-CNT-001, Axiom 2)**:
> - Docker daemon
> - docker-compose
> - DockerHub registry
> - Alpine/Ubuntu base images
>
> Violation of these constraints will trigger STAMP safety halt.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture](#2-architecture)
   - 2.1 [High-Level Overview](#21-high-level-overview)
   - 2.2 [Container Breakdown](#22-container-breakdown)
   - 2.3 [Network Topology](#23-network-topology)
3. [Implementation](#3-implementation)
   - 3.1 [Sidecar Pattern](#31-sidecar-pattern)
   - 3.2 [Resource Allocation](#32-resource-allocation)
   - 3.3 [Service Configuration](#33-service-configuration)
4. [Test Plan](#4-test-plan)
   - 4.1 [Unit Tests](#41-unit-tests)
   - 4.2 [Integration Tests](#42-integration-tests)
   - 4.3 [System Tests](#43-system-tests)
5. [Usage](#5-usage)
   - 5.1 [Quick Start](#51-quick-start)
   - 5.2 [Operations](#52-operations)
   - 5.3 [Troubleshooting](#53-troubleshooting)

---

## 1. Executive Summary

The Three-Container Development Architecture consolidates the Indrajaal platform from 6+ containers into 3 logical container groups using the **sidecar pattern**. This approach provides:

- **Simplified orchestration**: 3 primary containers vs 6+ separate containers
- **Shared network namespaces**: Sidecars communicate via localhost
- **Resource efficiency**: Per SOPv5.11 allocation (20 CPU, 56GB RAM)
- **Tailscale DNS integration**: Identity-based networking via MagicDNS

### Container Summary

| Container | Purpose | Sidecars | Resources |
|-----------|---------|----------|-----------|
| `indrajaal-db` | Database | None | 4 CPU, 16GB RAM |
| `indrajaal-app` | Application | Redis, Nginx | 12 CPU, 32GB RAM |
| `indrajaal-obs` | Observability | Grafana, OTEL | 4 CPU, 8GB RAM |

---

## 2. Architecture

### 2.1 High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        THREE-CONTAINER ARCHITECTURE                          │
│                                                                              │
│  ┌──────────────┐    ┌──────────────────────┐    ┌───────────────────────┐  │
│  │              │    │                      │    │                       │  │
│  │  indrajaal   │◄───│    indrajaal-app     │───►│    indrajaal-obs      │  │
│  │     -db      │    │                      │    │                       │  │
│  │              │    │   + redis sidecar    │    │   + grafana sidecar   │  │
│  │  TimescaleDB │    │   + nginx sidecar    │    │   + otel sidecar      │  │
│  │              │    │                      │    │                       │  │
│  └──────────────┘    └──────────────────────┘    └───────────────────────┘  │
│       :5433               :4000,:80,:443              :9090,:3000,:4317      │
│                                                                              │
│  ════════════════════════════════════════════════════════════════════════   │
│                          indrajaal-net (172.30.0.0/24)                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Key Design Decisions

1. **Sidecar Pattern over Multi-Process**: Each service runs in its own container but shares network namespace
2. **Primary Container Owns Network**: Ports defined on primary, sidecars use localhost
3. **Tailscale DNS Naming**: `{service}-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}`
4. **Health Check Chain**: db → app → obs (dependency order)

### 2.2 Container Breakdown

#### 2.2.1 Container 1: Database (`indrajaal-db`)

**Purpose**: Persistent data storage with time-series optimization

```
┌─────────────────────────────────────────────────────────────────┐
│ CONTAINER: indrajaal-db                                          │
├─────────────────────────────────────────────────────────────────┤
│ Image: localhost/indrajaal-timescaledb-demo:nixos-devenv         │
│ Hostname: db-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}               │
│ IP: 172.30.0.10                                                  │
│ Port: 5433                                                       │
├─────────────────────────────────────────────────────────────────┤
│ Components:                                                      │
│  └── TimescaleDB 2.x + PostgreSQL 17                            │
├─────────────────────────────────────────────────────────────────┤
│ Resources:                                                       │
│  ├── CPU: 4 cores (limit), 2 cores (reservation)                │
│  └── RAM: 16GB (limit), 8GB (reservation)                       │
├─────────────────────────────────────────────────────────────────┤
│ Volumes:                                                         │
│  ├── ./data/timescaledb:/var/lib/postgresql/data                │
│  ├── ./priv/repo/migrations:/docker-entrypoint-initdb.d         │
│  └── ./scripts/timescale/init-timescaledb.sql                   │
├─────────────────────────────────────────────────────────────────┤
│ Health Check:                                                    │
│  └── pg_isready -U indrajaal -d indrajaal_dev -p 5433           │
└─────────────────────────────────────────────────────────────────┘
```

**Configuration Parameters**:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `POSTGRES_DB` | indrajaal_dev | Database name |
| `POSTGRES_USER` | indrajaal | Database user |
| `PGPORT` | 5433 | Non-standard port (avoids conflict) |
| `TS_TUNE_MEMORY` | 8GB | TimescaleDB memory tuning |
| `POSTGRES_SHARED_BUFFERS` | 4GB | PostgreSQL shared memory |

#### 2.2.2 Container 2: Application (`indrajaal-app`)

**Purpose**: Elixir/Phoenix application with caching and reverse proxy

```
┌─────────────────────────────────────────────────────────────────┐
│ CONTAINER GROUP: indrajaal-app                                   │
├─────────────────────────────────────────────────────────────────┤
│ PRIMARY: indrajaal-app                                           │
│  ├── Image: localhost/indrajaal-sopv51-elixir-app:nixos-25.05   │
│  ├── Hostname: app-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}         │
│  ├── IP: 172.30.0.20                                            │
│  └── Ports: 4000, 4001, 6379, 80, 443                           │
├─────────────────────────────────────────────────────────────────┤
│ SIDECAR: indrajaal-redis                                         │
│  ├── Image: localhost/indrajaal-redis-demo:nixos-devenv         │
│  ├── network_mode: "service:indrajaal-app"                      │
│  └── Access: localhost:6379 (from app)                          │
├─────────────────────────────────────────────────────────────────┤
│ SIDECAR: indrajaal-nginx                                         │
│  ├── Image: localhost/indrajaal-nginx-demo:nixos-devenv         │
│  ├── network_mode: "service:indrajaal-app"                      │
│  └── Access: localhost:80, localhost:443 (from host)            │
├─────────────────────────────────────────────────────────────────┤
│ Resources (Combined):                                            │
│  ├── CPU: 12 cores (limit), 6 cores (reservation)               │
│  └── RAM: 32GB (limit), 16GB (reservation)                      │
├─────────────────────────────────────────────────────────────────┤
│ Resource Distribution:                                           │
│  ├── App:   8 CPU, 26GB RAM                                     │
│  ├── Redis: 2 CPU, 4GB RAM                                      │
│  └── Nginx: 1 CPU, 1GB RAM                                      │
└─────────────────────────────────────────────────────────────────┘
```

**Sidecar Communication**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Shared Network Namespace                      │
│                                                                  │
│   ┌─────────┐     localhost:6379      ┌─────────┐               │
│   │   App   │◄────────────────────────│  Redis  │               │
│   │ :4000   │                         │ :6379   │               │
│   └────▲────┘                         └─────────┘               │
│        │                                                         │
│        │ localhost:4000                                          │
│        │                                                         │
│   ┌────┴────┐                                                    │
│   │  Nginx  │◄──── External: :80, :443                          │
│   │ :80,:443│                                                    │
│   └─────────┘                                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 2.2.3 Container 3: Observability (`indrajaal-obs`)

**Purpose**: Metrics collection, visualization, and distributed tracing

```
┌─────────────────────────────────────────────────────────────────┐
│ CONTAINER GROUP: indrajaal-obs                                   │
├─────────────────────────────────────────────────────────────────┤
│ PRIMARY: indrajaal-obs (Prometheus)                              │
│  ├── Image: localhost/indrajaal-prometheus-demo:nixos-devenv    │
│  ├── Hostname: obs-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}         │
│  ├── IP: 172.30.0.30                                            │
│  └── Ports: 9090, 3000, 4317, 4318, 8888                        │
├─────────────────────────────────────────────────────────────────┤
│ SIDECAR: indrajaal-grafana                                       │
│  ├── Image: localhost/indrajaal-grafana-demo:nixos-devenv       │
│  ├── network_mode: "service:indrajaal-obs"                      │
│  └── Access: localhost:3000 (from host via obs ports)           │
├─────────────────────────────────────────────────────────────────┤
│ SIDECAR: indrajaal-otel                                          │
│  ├── Image: localhost/indrajaal-otel-collector-demo:nixos-devenv│
│  ├── network_mode: "service:indrajaal-obs"                      │
│  └── Access: localhost:4317 (gRPC), localhost:4318 (HTTP)       │
├─────────────────────────────────────────────────────────────────┤
│ Resources (Combined):                                            │
│  ├── CPU: 4 cores (limit), 2 cores (reservation)                │
│  └── RAM: 8GB (limit), 4GB (reservation)                        │
├─────────────────────────────────────────────────────────────────┤
│ Resource Distribution:                                           │
│  ├── Prometheus: 2 CPU, 2GB RAM                                 │
│  ├── Grafana:    1 CPU, 2GB RAM                                 │
│  └── OTEL:       1 CPU, 2GB RAM                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Observability Data Flow**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Observability Pipeline                        │
│                                                                  │
│   indrajaal-app                                                  │
│        │                                                         │
│        │ OTLP (traces, metrics)                                  │
│        ▼                                                         │
│   ┌─────────┐    scrape :4000/metrics    ┌────────────┐         │
│   │  OTEL   │───────────────────────────►│ Prometheus │         │
│   │ :4317   │                            │   :9090    │         │
│   └─────────┘                            └─────┬──────┘         │
│                                                │                 │
│                                                │ datasource      │
│                                                ▼                 │
│                                          ┌──────────┐           │
│                                          │ Grafana  │           │
│                                          │  :3000   │           │
│                                          └──────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Network Topology

#### 2.3.1 Network Configuration

```yaml
networks:
  indrajaal-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/24
          gateway: 172.30.0.1
```

#### 2.3.2 IP Address Assignment

| Service | IP Address | Purpose |
|---------|------------|---------|
| Gateway | 172.30.0.1 | Network gateway |
| indrajaal-db | 172.30.0.10 | Database |
| indrajaal-app | 172.30.0.20 | Application (+ sidecars) |
| indrajaal-obs | 172.30.0.30 | Observability (+ sidecars) |

#### 2.3.3 Port Mapping

| Host Port | Container | Service | Protocol |
|-----------|-----------|---------|----------|
| 5433 | indrajaal-db | PostgreSQL | TCP |
| 4000 | indrajaal-app | Phoenix HTTP | TCP |
| 4001 | indrajaal-app | Phoenix WS | TCP |
| 6379 | indrajaal-app | Redis | TCP |
| 80 | indrajaal-app | Nginx HTTP | TCP |
| 443 | indrajaal-app | Nginx HTTPS | TCP |
| 9090 | indrajaal-obs | Prometheus | TCP |
| 3000 | indrajaal-obs | Grafana | TCP |
| 4317 | indrajaal-obs | OTEL gRPC | TCP |
| 4318 | indrajaal-obs | OTEL HTTP | TCP |
| 8888 | indrajaal-obs | OTEL Metrics | TCP |

#### 2.3.4 Tailscale DNS Integration

**Naming Convention**: `{service}-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}`

| Service | FQDN (example) |
|---------|----------------|
| Database | `db-vm-1.tail55d152.ts.net` |
| Application | `app-vm-1.tail55d152.ts.net` |
| Observability | `obs-vm-1.tail55d152.ts.net` |

---

## 3. Implementation

### 3.1 Sidecar Pattern

#### 3.1.1 Overview

The sidecar pattern uses `network_mode: "service:X"` to share the network namespace between containers:

```yaml
# Primary container owns the network
indrajaal-app:
  container_name: indrajaal-app
  networks:
    indrajaal-net:
      ipv4_address: 172.30.0.20
  ports:
    - "4000:4000"   # App port
    - "6379:6379"   # Redis port (sidecar)

# Sidecar shares network with primary
indrajaal-redis:
  container_name: indrajaal-redis
  network_mode: "service:indrajaal-app"  # KEY: Share network namespace
  depends_on:
    indrajaal-app:
      condition: service_started
```

#### 3.1.2 Benefits

| Benefit | Description |
|---------|-------------|
| **Localhost Communication** | Sidecars communicate via `localhost`, no network overhead |
| **Shared Ports** | Primary container exposes all ports for the group |
| **Simplified Networking** | Single IP address for the container group |
| **Independent Lifecycle** | Each container can be restarted independently |
| **Separate Logs** | Each container has its own log stream |

#### 3.1.3 Constraints

| Constraint | Mitigation |
|------------|------------|
| **Ports on Primary Only** | Define all ports on primary container |
| **Primary Must Start First** | Use `depends_on: condition: service_started` |
| **Shared Network Fate** | If primary fails, sidecars lose network |

### 3.2 Resource Allocation

#### 3.2.1 SOPv5.11 Compliance

Per CLAUDE.md ContainerAllocation:

| Container | CPU (Limit) | CPU (Reserve) | RAM (Limit) | RAM (Reserve) |
|-----------|-------------|---------------|-------------|---------------|
| indrajaal-db | 4.0 | 2.0 | 16GB | 8GB |
| indrajaal-app | 12.0 | 6.0 | 32GB | 16GB |
| indrajaal-obs | 4.0 | 2.0 | 8GB | 4GB |
| **Total** | **20.0** | **10.0** | **56GB** | **28GB** |

#### 3.2.2 Sidecar Resource Distribution

**Application Group (32GB total)**:

```
┌─────────────────────────────────────────┐
│         Application Resources           │
├─────────────────────────────────────────┤
│ ████████████████████████████ App: 26GB  │
│ ████ Redis: 4GB                         │
│ ██ Nginx: 1GB                           │
│ (1GB overhead)                          │
└─────────────────────────────────────────┘
```

**Observability Group (8GB total)**:

```
┌─────────────────────────────────────────┐
│        Observability Resources          │
├─────────────────────────────────────────┤
│ ████████ Prometheus: 2GB                │
│ ████████ Grafana: 2GB                   │
│ ████████ OTEL: 2GB                      │
│ (2GB overhead)                          │
└─────────────────────────────────────────┘
```

### 3.3 Service Configuration

#### 3.3.1 Database Configuration

```yaml
indrajaal-db:
  environment:
    # Core
    POSTGRES_DB: indrajaal_dev
    POSTGRES_USER: indrajaal
    POSTGRES_PASSWORD: indrajaal_dev
    PGPORT: 5433

    # TimescaleDB Tuning
    TS_TUNE_MEMORY: 8GB
    TS_TUNE_NUM_CPUS: 4
    TS_TUNE_MAX_CONNS: 200

    # PostgreSQL Tuning
    POSTGRES_SHARED_BUFFERS: 4GB
    POSTGRES_EFFECTIVE_CACHE_SIZE: 12GB
    POSTGRES_WORK_MEM: 64MB
```

#### 3.3.2 Application Configuration

```yaml
indrajaal-app:
  environment:
    # Application
    MIX_ENV: dev
    DATABASE_URL: ecto://indrajaal:indrajaal_dev@172.30.0.10:5433/indrajaal_dev
    REDIS_URL: redis://localhost:6379
    PHX_HOST: localhost
    PHX_PORT: 4000

    # Tailscale DNS
    TAILSCALE_DNS_SUFFIX: ${TAILSCALE_DNS_SUFFIX:-tail55d152.ts.net}
    TS_HOSTNAME: ${TS_HOSTNAME:-vm-1}

    # BEAM VM Tuning
    ELIXIR_ERL_OPTIONS: "+S 12 +A 64 +K true +P 2097152"
    ERL_MAX_PORTS: 524288
```

#### 3.3.3 Observability Configuration

```yaml
indrajaal-obs:
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'
    - '--storage.tsdb.retention.time=30d'
    - '--storage.tsdb.retention.size=20GB'
    - '--web.enable-lifecycle'
    - '--web.enable-admin-api'
```

---

## 4. Test Plan

### 4.1 Unit Tests

#### 4.1.1 Container Image Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| UT-IMG-001 | Database image exists | `podman image exists localhost/indrajaal-timescaledb-demo:nixos-devenv` returns 0 |
| UT-IMG-002 | App image exists | `podman image exists localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv` returns 0 |
| UT-IMG-003 | Redis image exists | `podman image exists localhost/indrajaal-redis-demo:nixos-devenv` returns 0 |
| UT-IMG-004 | Nginx image exists | `podman image exists localhost/indrajaal-nginx-demo:nixos-devenv` returns 0 |
| UT-IMG-005 | Prometheus image exists | `podman image exists localhost/indrajaal-prometheus-demo:nixos-devenv` returns 0 |
| UT-IMG-006 | Grafana image exists | `podman image exists localhost/indrajaal-grafana-demo:nixos-devenv` returns 0 |
| UT-IMG-007 | OTEL image exists | `podman image exists localhost/indrajaal-otel-collector-demo:nixos-devenv` returns 0 |

#### 4.1.2 Configuration Tests

| Test ID | Test Case | Expected Result |
|---------|-----------|-----------------|
| UT-CFG-001 | Compose file syntax | `podman-compose -f podman-compose-3container.yml config` succeeds |
| UT-CFG-002 | Environment file sources | `source tailscale.env` succeeds |
| UT-CFG-003 | Network defined | Config shows `indrajaal-net` with subnet `172.30.0.0/24` |
| UT-CFG-004 | Volumes defined | Config shows `app_deps` and `app_build` volumes |

### 4.2 Integration Tests

#### 4.2.1 Container Startup Tests

| Test ID | Test Case | Command | Expected Result |
|---------|-----------|---------|-----------------|
| IT-START-001 | Database starts | `podman-compose up -d indrajaal-db` | Container running, healthy |
| IT-START-002 | App starts after DB | `podman-compose up -d indrajaal-app` | Container running after DB healthy |
| IT-START-003 | Redis sidecar starts | Check `indrajaal-redis` status | Running with `network_mode: service:indrajaal-app` |
| IT-START-004 | Nginx sidecar starts | Check `indrajaal-nginx` status | Running with `network_mode: service:indrajaal-app` |
| IT-START-005 | Obs starts after App | `podman-compose up -d indrajaal-obs` | Container running after App healthy |
| IT-START-006 | Grafana sidecar starts | Check `indrajaal-grafana` status | Running with `network_mode: service:indrajaal-obs` |
| IT-START-007 | OTEL sidecar starts | Check `indrajaal-otel` status | Running with `network_mode: service:indrajaal-obs` |

#### 4.2.2 Connectivity Tests

| Test ID | Test Case | Command | Expected Result |
|---------|-----------|---------|-----------------|
| IT-CONN-001 | DB accepts connections | `podman exec indrajaal-db pg_isready -p 5433` | "accepting connections" |
| IT-CONN-002 | App connects to DB | Check app logs | No connection errors |
| IT-CONN-003 | App connects to Redis | `podman exec indrajaal-app redis-cli -h localhost ping` | "PONG" |
| IT-CONN-004 | Prometheus scrapes app | `curl localhost:9090/api/v1/targets` | App target "up" |
| IT-CONN-005 | Grafana connects to Prometheus | `curl localhost:3000/api/datasources` | Prometheus datasource configured |

#### 4.2.3 Health Check Tests

| Test ID | Test Case | Command | Expected Result |
|---------|-----------|---------|-----------------|
| IT-HC-001 | DB health check | `podman inspect indrajaal-db --format '{{.State.Health.Status}}'` | "healthy" |
| IT-HC-002 | App health check | `curl -f localhost:4000/health` | HTTP 200 |
| IT-HC-003 | Redis health check | `podman exec indrajaal-redis redis-cli ping` | "PONG" |
| IT-HC-004 | Prometheus health check | `curl -f localhost:9090/-/healthy` | HTTP 200 |
| IT-HC-005 | Grafana health check | `curl -f localhost:3000/api/health` | HTTP 200 |

#### 4.2.4 ContainerHealthSensor ExUnit Tests

**STAMP Compliance**: SC-CNT-009, SC-CNT-010, SC-CNT-011, SC-CNT-012, SC-CNT-V01, SC-CNT-V02, SC-OBS-065

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test/indrajaal/cortex/sensors/container_health_sensor_test.exs` | 35 | GenServer API validation, STAMP constraint verification |
| `test/indrajaal/cortex/sensors/container_health_telemetry_test.exs` | 26 | Telemetry event emission for observability |

**7-Phase Verification Pipeline** (tested in ContainerHealthSensor):
1. `verifying_versions` - Elixir 1.19.2, OTP 28, ERTS 16.1.1
2. `verifying_packages` - Required system packages
3. `verifying_environment` - NixOS container, Podman runtime
4. `verifying_network` - DNS, localhost reachability
5. `verifying_ssl` - CA bundle, SSL application
6. `verifying_phics` - <50ms latency requirement
7. `verifying_stamp` - All SC-CNT-* constraints

**Run Container Health Tests**:
```bash
MIX_ENV=test mix test \
  test/indrajaal/cortex/sensors/container_health_sensor_test.exs \
  test/indrajaal/cortex/sensors/container_health_telemetry_test.exs
```

**Related Quint Specification**: `docs/formal_specs/container_verification.qnt`

### 4.3 System Tests

#### 4.3.1 Full Stack Tests

| Test ID | Test Case | Procedure | Expected Result |
|---------|-----------|-----------|-----------------|
| ST-FULL-001 | Complete startup | `podman-compose -f podman-compose-3container.yml up -d` | All 7 containers running |
| ST-FULL-002 | Service dependency chain | Stop DB, check app | App enters unhealthy state |
| ST-FULL-003 | Sidecar network sharing | `podman exec indrajaal-redis hostname -i` | Same IP as indrajaal-app |
| ST-FULL-004 | Data persistence | Restart stack, check data | PostgreSQL data persisted |

#### 4.3.2 Performance Tests

| Test ID | Test Case | Procedure | Expected Result |
|---------|-----------|-----------|-----------------|
| ST-PERF-001 | Startup time | Time from `up -d` to all healthy | < 120 seconds |
| ST-PERF-002 | Memory under limit | Check container stats | Each group under limit |
| ST-PERF-003 | CPU under limit | Check container stats | Each group under limit |
| ST-PERF-004 | Network latency | Ping between containers | < 1ms |

#### 4.3.3 Failure Tests

| Test ID | Test Case | Procedure | Expected Result |
|---------|-----------|-----------|-----------------|
| ST-FAIL-001 | Sidecar restart | Restart Redis sidecar | App continues operating |
| ST-FAIL-002 | Primary restart | Restart indrajaal-app | Sidecars reconnect after restart |
| ST-FAIL-003 | Database failover | Stop DB, check app behavior | App reports DB unavailable |
| ST-FAIL-004 | Full stack recovery | Stop all, start all | All services recover |

### 4.4 Test Execution Commands

```bash
#!/bin/bash
# Test execution script

# Unit Tests
echo "=== Unit Tests ==="
podman-compose -f podman-compose-3container.yml config > /dev/null && echo "UT-CFG-001: PASS"
source tailscale.env && echo "UT-CFG-002: PASS"

# Integration Tests - Startup
echo "=== Integration Tests - Startup ==="
podman-compose -f podman-compose-3container.yml up -d indrajaal-db
sleep 10
podman inspect indrajaal-db --format '{{.State.Health.Status}}' | grep -q healthy && echo "IT-START-001: PASS"

podman-compose -f podman-compose-3container.yml up -d indrajaal-app indrajaal-redis indrajaal-nginx
sleep 30
podman ps | grep -q indrajaal-redis && echo "IT-START-003: PASS"

# Integration Tests - Connectivity
echo "=== Integration Tests - Connectivity ==="
podman exec indrajaal-db pg_isready -p 5433 && echo "IT-CONN-001: PASS"
podman exec indrajaal-redis redis-cli ping | grep -q PONG && echo "IT-CONN-003: PASS"

# System Tests
echo "=== System Tests ==="
podman-compose -f podman-compose-3container.yml ps | grep -c "Up" | grep -q 7 && echo "ST-FULL-001: PASS"
```

---

## 5. Usage

### 5.1 Quick Start

#### 5.1.1 Prerequisites

1. **Podman** >= 5.4.1 (rootless) - **MANDATORY: Docker is FORBIDDEN per SC-CNT-009**
2. **podman-compose** >= 1.0.0 - **NOT docker-compose**
3. **Tailscale** configured with MagicDNS
4. **NixOS container images** built locally with Podman

> **CRITICAL ENFORCEMENT (AOR-CNT-001)**: All container operations MUST use Podman.
> Docker is explicitly FORBIDDEN per STAMP constraint SC-CNT-009 and Axiom 2 (Container Isolation Invariant).
> Using Docker will result in STAMP compliance violation.

#### 5.1.2 Environment Setup

```bash
# 1. Navigate to project directory
cd /home/an/dev/ver/indrajaal-v5.2

# 2. Verify Tailscale status
tailscale status

# 3. Source environment variables
source tailscale.env

# 4. Verify environment
echo "Hostname: $TS_HOSTNAME"
echo "Tailnet: $TAILSCALE_DNS_SUFFIX"
echo "IP: $TS_IP_ADDRESS"
```

#### 5.1.3 Start Stack

```bash
# Start all containers
podman-compose --env-file tailscale.env -f podman-compose-3container.yml up -d

# Check status
podman-compose -f podman-compose-3container.yml ps

# Expected output:
# CONTAINER ID  IMAGE                                           STATUS          NAMES
# xxxx          localhost/indrajaal-timescaledb-demo:...       Up (healthy)    indrajaal-db
# xxxx          localhost/indrajaal-sopv51-elixir-app:...      Up (healthy)    indrajaal-app
# xxxx          localhost/indrajaal-redis-demo:...             Up (healthy)    indrajaal-redis
# xxxx          localhost/indrajaal-nginx-demo:...             Up              indrajaal-nginx
# xxxx          localhost/indrajaal-prometheus-demo:...        Up (healthy)    indrajaal-obs
# xxxx          localhost/indrajaal-grafana-demo:...           Up (healthy)    indrajaal-grafana
# xxxx          localhost/indrajaal-otel-collector-demo:...    Up (healthy)    indrajaal-otel
```

#### 5.1.4 Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Phoenix App | http://localhost:4000 | - |
| Nginx | http://localhost:80 | - |
| PostgreSQL | localhost:5433 | indrajaal/indrajaal_dev |
| Redis | localhost:6379 | - |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin/admin |
| OTEL gRPC | localhost:4317 | - |
| OTEL HTTP | localhost:4318 | - |

### 5.2 Operations

#### 5.2.1 Container Management

```bash
# Start specific container group
podman-compose -f podman-compose-3container.yml up -d indrajaal-db
podman-compose -f podman-compose-3container.yml up -d indrajaal-app indrajaal-redis indrajaal-nginx
podman-compose -f podman-compose-3container.yml up -d indrajaal-obs indrajaal-grafana indrajaal-otel

# Stop all
podman-compose -f podman-compose-3container.yml down

# Stop specific container
podman-compose -f podman-compose-3container.yml stop indrajaal-redis

# Restart specific container
podman-compose -f podman-compose-3container.yml restart indrajaal-app

# View logs
podman-compose -f podman-compose-3container.yml logs -f indrajaal-app
podman-compose -f podman-compose-3container.yml logs -f indrajaal-redis

# Execute command in container
podman exec -it indrajaal-app /bin/sh
podman exec -it indrajaal-db psql -U indrajaal -d indrajaal_dev
```

#### 5.2.2 Database Operations

```bash
# Connect to database
podman exec -it indrajaal-db psql -U indrajaal -d indrajaal_dev -p 5433

# Run migrations (from app container)
podman exec -it indrajaal-app mix ecto.migrate

# Database backup
podman exec indrajaal-db pg_dump -U indrajaal -p 5433 indrajaal_dev > backup.sql

# Database restore
cat backup.sql | podman exec -i indrajaal-db psql -U indrajaal -p 5433 indrajaal_dev
```

#### 5.2.3 Monitoring Operations

```bash
# Check Prometheus targets
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query Prometheus
curl -s 'localhost:9090/api/v1/query?query=up' | jq '.data.result'

# Check Grafana datasources
curl -s -u admin:admin localhost:3000/api/datasources | jq '.[].name'

# View container resource usage
podman stats --no-stream
```

### 5.3 Troubleshooting

#### 5.3.1 Common Issues

**Issue: Container fails to start**

```bash
# Check logs
podman-compose -f podman-compose-3container.yml logs indrajaal-app

# Check container state
podman inspect indrajaal-app --format '{{.State.Status}} - {{.State.Error}}'

# Check resource limits
podman stats --no-stream indrajaal-app
```

**Issue: Sidecar can't connect to primary**

```bash
# Verify network mode
podman inspect indrajaal-redis --format '{{.HostConfig.NetworkMode}}'
# Should show: "container:indrajaal-app"

# Verify shared network namespace
podman exec indrajaal-redis hostname -i
podman exec indrajaal-app hostname -i
# Should show same IP: 172.30.0.20
```

**Issue: Database connection refused**

```bash
# Check DB is healthy
podman inspect indrajaal-db --format '{{.State.Health.Status}}'

# Check DB is listening
podman exec indrajaal-db pg_isready -p 5433 -h localhost

# Check network connectivity
podman exec indrajaal-app ping -c 1 172.30.0.10
```

**Issue: Ports already in use**

```bash
# Find what's using the port
sudo lsof -i :4000

# Kill the process or change port mapping in compose file
```

#### 5.3.2 Debug Commands

```bash
# Full container inspection
podman inspect indrajaal-app | jq '.[0].NetworkSettings'

# Network inspection
podman network inspect indrajaal-net

# Volume inspection
podman volume ls
podman volume inspect app_deps

# System resource check
podman system df
podman system info
```

#### 5.3.3 Recovery Procedures

**Full Stack Recovery**:

```bash
# 1. Stop all containers
podman-compose -f podman-compose-3container.yml down

# 2. Remove orphaned containers
podman rm -f $(podman ps -aq --filter "name=indrajaal")

# 3. Verify no containers running
podman ps -a | grep indrajaal

# 4. Start fresh
source tailscale.env
podman-compose --env-file tailscale.env -f podman-compose-3container.yml up -d

# 5. Wait for health checks
sleep 60
podman-compose -f podman-compose-3container.yml ps
```

**Data Recovery** (if volumes corrupted):

```bash
# 1. Stop stack
podman-compose -f podman-compose-3container.yml down

# 2. Backup existing data
cp -r ./data ./data.backup.$(date +%Y%m%d)

# 3. Remove corrupted volumes
podman volume rm app_deps app_build

# 4. Restart (will recreate volumes)
podman-compose --env-file tailscale.env -f podman-compose-3container.yml up -d
```

---

## 6. Implementation Reference (5-Level Detail)

### 6.1 Level 1: Container Build Pipeline

#### 6.1.1 Level 2: Nix Container Definitions

##### 6.1.1.1 Level 3: Base Container (`sopv51-base.nix`)

###### 6.1.1.1.1 Level 4: Package Selection

**Level 5: Package Version Requirements**

| Package | Version | Nix Attribute | Purpose |
|---------|---------|---------------|---------|
| Elixir | 1.19.2 | `elixir_1_19` | BEAM language |
| Erlang/OTP | 28.0 | `erlang_28` | BEAM VM |
| PostgreSQL Client | 17 | `postgresql_17` | DB connectivity |
| Node.js | 20 | `nodejs_20` | Asset compilation |
| Git | Latest | `git` | VCS |
| curl | Latest | `curl` | HTTP client |

**Level 5: Build Configuration**

```nix
# containers/sopv51-base.nix - Critical Sections
{
  # Package set selection (nixpkgs 25.05 unstable)
  pkgs ? import <nixpkgs> {}

  # Git metadata for image tagging
, gitRev ? "unknown"
, gitBranch ? "unknown"
, buildDate ? "unknown"
}

# Core packages for base image
baseFS = pkgs.symlinkJoin {
  name = "indrajaal-base-fs";
  paths = with pkgs; [
    # Runtime (Elixir 1.19 + OTP 28)
    elixir_1_19
    erlang_28
    # Development tools
    git gnumake gcc
    # SOPv5.11 requirements
    inotify-tools entr watchman
  ];
};
```

###### 6.1.1.1.2 Level 4: Environment Configuration

**Level 5: Environment Variables**

| Variable | Value | Purpose |
|----------|-------|---------|
| `PHICS_ENABLED` | `true` | Hot-reload system |
| `NO_TIMEOUT` | `true` | Patient mode |
| `CONTAINER_OS` | `nixos` | OS identifier |
| `ELIXIR_ERL_OPTIONS` | `+S 16` | BEAM schedulers |
| `SSL_CERT_FILE` | `/etc/ssl/certs/ca-bundle.crt` | CA certs |

##### 6.1.1.2 Level 3: App Container (`sopv51-elixir-app.nix`)

###### 6.1.1.2.1 Level 4: Additional Packages

**Level 5: Application-Specific Packages**

| Package | Purpose | Mount Point |
|---------|---------|-------------|
| `imagemagick` | Image processing | N/A |
| `yarn` | Node package manager | N/A |
| `redis` | Cache client CLI | N/A |
| `postgresql_17` | Database client | N/A |

###### 6.1.1.2.2 Level 4: PHICS Configuration

**Level 5: File Watch Configuration**

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

#### 6.1.2 Level 2: Build Process

##### 6.1.2.1 Level 3: Nix Build Commands

###### 6.1.2.1.1 Level 4: Base Container Build

**Level 5: Build Command Details**

```bash
# Full command with all arguments
nix-build containers/sopv51-base.nix \
  --argstr gitRev "$(git rev-parse --short HEAD)" \
  --argstr gitBranch "$(git rev-parse --abbrev-ref HEAD)" \
  --argstr buildDate "$(date -Iseconds)" \
  -o result-base

# Output: /nix/store/xxx-docker-image-indrajaal-sopv51-base.tar.gz
```

###### 6.1.2.1.2 Level 4: App Container Build

**Level 5: Build Command Details**

```bash
# Full command with all arguments
nix-build containers/sopv51-elixir-app.nix \
  --argstr gitRev "$(git rev-parse --short HEAD)" \
  --argstr gitBranch "$(git rev-parse --abbrev-ref HEAD)" \
  --argstr buildDate "$(date -Iseconds)" \
  -o result-app

# Output: /nix/store/xxx-docker-image-indrajaal-sopv51-elixir-app.tar.gz
```

##### 6.1.2.2 Level 3: Podman Load Process

###### 6.1.2.2.1 Level 4: Image Loading

**Level 5: Load Commands**

```bash
# Load base image
podman load < result-base
# Output: Loaded image: localhost/indrajaal-sopv51-base:nixos-25.05-<gitrev>

# Load app image
podman load < result-app
# Output: Loaded image: localhost/indrajaal-sopv51-elixir-app:nixos-25.05-<gitrev>
```

###### 6.1.2.2.2 Level 4: Image Tagging

**Level 5: Tag Conventions**

```bash
# Tag with semantic version
podman tag localhost/indrajaal-sopv51-elixir-app:nixos-25.05-a198e92d3 \
           localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28

# Tag as latest
podman tag localhost/indrajaal-sopv51-elixir-app:nixos-25.05-a198e92d3 \
           localhost/indrajaal-sopv51-elixir-app:latest
```

### 6.2 Level 1: Testing Container Deployment

#### 6.2.1 Level 2: Compose File Configuration

##### 6.2.1.1 Level 3: Network Definition

###### 6.2.1.1.1 Level 4: Subnet Configuration

**Level 5: Network Parameters**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Driver | bridge | Container networking |
| Subnet | 172.31.0.0/24 | Testing network |
| Gateway | 172.31.0.1 | Network gateway |
| DB IP | 172.31.0.10 | Primary database |
| App IPs | 172.31.0.20-22 | App cluster |
| Obs IP | 172.31.0.30 | Observability |

##### 6.2.1.2 Level 3: Service Definitions

###### 6.2.1.2.1 Level 4: Database Service

**Level 5: Database Configuration**

```yaml
indrajaal-db-primary:
  image: localhost/indrajaal-timescaledb-demo:nixos-devenv
  environment:
    POSTGRES_DB: indrajaal_test
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
    PGPORT: 5433
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres -p 5433"]
    interval: 10s
    timeout: 5s
    retries: 5
```

###### 6.2.1.2.2 Level 4: Application Service

**Level 5: Application Configuration**

```yaml
indrajaal-app-1:
  image: localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28
  environment:
    MIX_ENV: test
    DATABASE_URL: ecto://postgres:postgres@172.31.0.10:5433/indrajaal_test
    ELIXIR_ERL_OPTIONS: "+S 4 +A 32 +K true +P 1048576"
  volumes:
    - .:/workspace:z
    - /etc/ssl/certs:/etc/ssl/certs:ro
  command: >
    sh -c "mix deps.get && mix ecto.migrate && mix phx.server"
```

---

## 7. Testing Reference (5-Level Detail)

### 7.1 Level 1: Test Categories

#### 7.1.1 Level 2: Container Image Tests

##### 7.1.1.1 Level 3: Version Verification

###### 7.1.1.1.1 Level 4: Elixir Version Check

**Level 5: Test Commands**

```bash
# Test: Verify Elixir 1.19.2
podman run --rm localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 elixir --version

# Expected Output:
# Erlang/OTP 28 [erts-16.1.1] [source] [64-bit] [smp:16:10]
# Elixir 1.19.2 (compiled with Erlang/OTP 28)

# Validation Script
#!/bin/bash
VERSION=$(podman run --rm localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 elixir --version)
echo "$VERSION" | grep -q "Elixir 1.19" && echo "PASS: Elixir 1.19" || echo "FAIL: Wrong Elixir version"
echo "$VERSION" | grep -q "OTP 28" && echo "PASS: OTP 28" || echo "FAIL: Wrong OTP version"
```

###### 7.1.1.1.2 Level 4: OTP Version Check

**Level 5: OTP Verification**

```bash
# Test: Verify OTP 28 runtime
podman run --rm localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 \
  erl -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'

# Expected Output: 28

# Test: Verify ERTS version
podman run --rm localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 \
  erl -eval 'io:format("~s~n", [erlang:system_info(version)]), halt().'

# Expected Output: 16.1.1
```

#### 7.1.2 Level 2: Container Startup Tests

##### 7.1.2.1 Level 3: Database Startup

###### 7.1.2.1.1 Level 4: Health Check Verification

**Level 5: Health Check Script**

```bash
#!/bin/bash
# Test: IT-START-001 - Database starts healthy

# Start database
podman-compose -f podman-compose-testing.yml up -d indrajaal-db-primary

# Wait for health check
for i in {1..30}; do
  STATUS=$(podman inspect indrajaal-db-primary --format '{{.State.Health.Status}}' 2>/dev/null)
  if [ "$STATUS" = "healthy" ]; then
    echo "PASS: Database healthy after ${i}0 seconds"
    exit 0
  fi
  sleep 10
done
echo "FAIL: Database did not become healthy within 300 seconds"
exit 1
```

##### 7.1.2.2 Level 3: Application Startup

###### 7.1.2.2.1 Level 4: Compilation Test

**Level 5: Compilation Verification**

```bash
#!/bin/bash
# Test: Application compiles successfully with OTP 28

podman exec indrajaal-app-1 sh -c "
  export MIX_ENV=test
  mix compile --warnings-as-errors 2>&1
"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "PASS: Compilation succeeded with 0 errors, 0 warnings"
else
  echo "FAIL: Compilation failed with exit code $EXIT_CODE"
fi
```

#### 7.1.3 Level 2: Integration Tests

##### 7.1.3.1 Level 3: Database Connectivity

###### 7.1.3.1.1 Level 4: Ecto Connection Test

**Level 5: Connection Verification**

```bash
#!/bin/bash
# Test: IT-CONN-002 - App connects to database

podman exec indrajaal-app-1 sh -c "
  mix ecto.migrate 2>&1
"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "PASS: Ecto migration succeeded - DB connection verified"
else
  echo "FAIL: Ecto migration failed - DB connection issue"
fi
```

###### 7.1.3.1.2 Level 4: Query Test

**Level 5: Query Verification**

```bash
#!/bin/bash
# Test: Execute query through Elixir

podman exec indrajaal-app-1 sh -c "
  mix run -e 'IO.inspect(Indrajaal.Repo.query!(\"SELECT 1\"))'
"
```

##### 7.1.3.2 Level 3: Cluster Communication

###### 7.1.3.2.1 Level 4: Node Discovery

**Level 5: Cluster Test Script**

```bash
#!/bin/bash
# Test: Nodes can discover each other

# Get node names
NODE1=$(podman exec indrajaal-app-1 sh -c 'echo $NODE_NAME')
NODE2=$(podman exec indrajaal-app-2 sh -c 'echo $NODE_NAME')
NODE3=$(podman exec indrajaal-app-3 sh -c 'echo $NODE_NAME')

echo "Node 1: $NODE1"
echo "Node 2: $NODE2"
echo "Node 3: $NODE3"

# Verify nodes can ping each other
podman exec indrajaal-app-1 sh -c "
  mix run -e 'Node.ping(:\"$NODE2\") |> IO.inspect()'
"
```

### 7.2 Level 1: Chaos Testing

#### 7.2.1 Level 2: Container Failure Scenarios

##### 7.2.1.1 Level 3: Container Restart Test

###### 7.2.1.1.1 Level 4: Primary Container Restart

**Level 5: Restart Test Script**

```bash
#!/bin/bash
# Test: ST-FAIL-002 - Primary container restart

echo "=== Chaos Test: Primary Container Restart ==="

# Record initial state
INITIAL_UPTIME=$(podman exec indrajaal-app-1 cat /proc/uptime | cut -d' ' -f1)
echo "Initial uptime: $INITIAL_UPTIME seconds"

# Restart container
podman restart indrajaal-app-1

# Wait for container to be healthy again
sleep 30

# Verify health
HEALTH=$(podman inspect indrajaal-app-1 --format '{{.State.Health.Status}}')
if [ "$HEALTH" = "healthy" ]; then
  echo "PASS: Container recovered and healthy"
else
  echo "FAIL: Container not healthy after restart"
fi
```

##### 7.2.1.2 Level 3: Network Partition Test

###### 7.2.1.2.1 Level 4: Simulated Partition

**Level 5: Network Isolation Script**

```bash
#!/bin/bash
# Test: Simulate network partition

echo "=== Chaos Test: Network Partition ==="

# Disconnect app-2 from network
podman network disconnect indrajaal-test-net indrajaal-app-2

# Wait and observe
sleep 10

# Reconnect
podman network connect indrajaal-test-net indrajaal-app-2 --ip 172.31.0.21

# Verify recovery
sleep 10
HEALTH=$(podman inspect indrajaal-app-2 --format '{{.State.Health.Status}}')
echo "App-2 health after reconnection: $HEALTH"
```

---

## 8. User Guide Reference (5-Level Detail)

### 8.1 Level 1: Installation

#### 8.1.1 Level 2: Prerequisites

##### 8.1.1.1 Level 3: Podman Installation

###### 8.1.1.1.1 Level 4: NixOS Installation

**Level 5: NixOS Configuration**

```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:
{
  # Enable Podman
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;  # Provides docker alias
    defaultNetwork.settings.dns_enabled = true;
  };

  # Add podman-compose
  environment.systemPackages = with pkgs; [
    podman-compose
    fuse-overlayfs
    slirp4netns
  ];
}
```

###### 8.1.1.1.2 Level 4: Ubuntu/Debian Installation

**Level 5: APT Installation**

```bash
#!/bin/bash
# Install Podman on Ubuntu 22.04+

# Add repository
sudo apt-get update
sudo apt-get install -y podman

# Install podman-compose
pip3 install podman-compose

# Verify installation
podman version
podman-compose version
```

##### 8.1.1.2 Level 3: Image Build

###### 8.1.1.2.1 Level 4: Building Images

**Level 5: Complete Build Script**

```bash
#!/bin/bash
# build-containers.sh - Build all NixOS containers

set -e
cd /home/an/dev/ver/indrajaal-v5.2

GIT_REV=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date -Iseconds)

echo "Building with: Rev=$GIT_REV Branch=$GIT_BRANCH Date=$BUILD_DATE"

# Build base container
echo "=== Building sopv51-base ==="
nix-build containers/sopv51-base.nix \
  --argstr gitRev "$GIT_REV" \
  --argstr gitBranch "$GIT_BRANCH" \
  --argstr buildDate "$BUILD_DATE" \
  -o result-base

# Build app container
echo "=== Building sopv51-elixir-app ==="
nix-build containers/sopv51-elixir-app.nix \
  --argstr gitRev "$GIT_REV" \
  --argstr gitBranch "$GIT_BRANCH" \
  --argstr buildDate "$BUILD_DATE" \
  -o result-app

# Load into Podman
echo "=== Loading images ==="
podman load < result-base
podman load < result-app

# Tag with friendly names
podman tag localhost/indrajaal-sopv51-elixir-app:nixos-25.05-$GIT_REV \
           localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28

echo "=== Build Complete ==="
podman images | grep indrajaal-sopv51
```

### 8.2 Level 1: Operations

#### 8.2.1 Level 2: Daily Operations

##### 8.2.1.1 Level 3: Starting the Stack

###### 8.2.1.1.1 Level 4: Quick Start

**Level 5: Complete Startup Procedure**

```bash
#!/bin/bash
# start-dev-stack.sh - Start development environment

set -e
cd /home/an/dev/ver/indrajaal-v5.2

echo "=== Starting Indrajaal Development Stack ==="
echo "Runtime: Elixir 1.19.2 + OTP 28"
echo "Framework: SOPv5.11"

# 1. Verify prerequisites
echo "Step 1: Verifying prerequisites..."
podman version > /dev/null || { echo "ERROR: Podman not installed"; exit 1; }

# 2. Verify images exist
echo "Step 2: Verifying container images..."
podman image exists localhost/indrajaal-sopv51-elixir-app:elixir-1.19-otp28 || {
  echo "ERROR: App image not found. Run build-containers.sh first"
  exit 1
}

# 3. Start database first
echo "Step 3: Starting database..."
podman-compose -f podman-compose-testing.yml up -d indrajaal-db-primary
sleep 10

# 4. Wait for DB health
echo "Step 4: Waiting for database health..."
for i in {1..30}; do
  STATUS=$(podman inspect indrajaal-db-primary --format '{{.State.Health.Status}}' 2>/dev/null)
  [ "$STATUS" = "healthy" ] && break
  sleep 2
done

# 5. Start application cluster
echo "Step 5: Starting application cluster..."
podman-compose -f podman-compose-testing.yml up -d indrajaal-app-1 indrajaal-app-2 indrajaal-app-3

# 6. Start observability
echo "Step 6: Starting observability..."
podman-compose -f podman-compose-testing.yml up -d indrajaal-obs

# 7. Show status
echo "=== Stack Status ==="
podman-compose -f podman-compose-testing.yml ps

echo ""
echo "Access:"
echo "  App:        http://localhost:4000"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000"
```

##### 8.2.1.2 Level 3: Stopping the Stack

###### 8.2.1.2.1 Level 4: Graceful Shutdown

**Level 5: Shutdown Procedure**

```bash
#!/bin/bash
# stop-dev-stack.sh - Stop development environment gracefully

set -e
cd /home/an/dev/ver/indrajaal-v5.2

echo "=== Stopping Indrajaal Development Stack ==="

# 1. Stop app containers (graceful)
echo "Step 1: Stopping application containers..."
podman-compose -f podman-compose-testing.yml stop indrajaal-app-1 indrajaal-app-2 indrajaal-app-3
sleep 5

# 2. Stop observability
echo "Step 2: Stopping observability..."
podman-compose -f podman-compose-testing.yml stop indrajaal-obs

# 3. Stop database (last)
echo "Step 3: Stopping database..."
podman-compose -f podman-compose-testing.yml stop indrajaal-db-primary indrajaal-db-replica

# 4. Remove containers (keep volumes)
echo "Step 4: Removing containers..."
podman-compose -f podman-compose-testing.yml down

echo "=== Stack Stopped ==="
echo "Note: Data volumes preserved. Use 'podman volume prune' to clean up."
```

#### 8.2.2 Level 2: Debugging

##### 8.2.2.1 Level 3: Log Analysis

###### 8.2.2.1.1 Level 4: Application Logs

**Level 5: Log Commands**

```bash
# View real-time logs for all containers
podman-compose -f podman-compose-testing.yml logs -f

# View logs for specific container
podman-compose -f podman-compose-testing.yml logs -f indrajaal-app-1

# View last 100 lines
podman logs --tail 100 indrajaal-app-1

# Search for errors
podman logs indrajaal-app-1 2>&1 | grep -i error

# Export logs to file
podman logs indrajaal-app-1 > app1-logs-$(date +%Y%m%d).txt 2>&1
```

###### 8.2.2.1.2 Level 4: Database Logs

**Level 5: PostgreSQL Debugging**

```bash
# View PostgreSQL logs
podman logs indrajaal-db-primary 2>&1 | grep -E "(ERROR|FATAL|WARNING)"

# Connect to database for debugging
podman exec -it indrajaal-db-primary psql -U postgres -d indrajaal_test -p 5433

# Check active connections
podman exec indrajaal-db-primary psql -U postgres -p 5433 -c \
  "SELECT pid, usename, application_name, state FROM pg_stat_activity;"

# Check for locks
podman exec indrajaal-db-primary psql -U postgres -p 5433 -c \
  "SELECT * FROM pg_locks WHERE NOT granted;"
```

##### 8.2.2.2 Level 3: Interactive Debugging

###### 8.2.2.2.1 Level 4: IEx Shell

**Level 5: Elixir Debugging**

```bash
# Open IEx shell in running container
podman exec -it indrajaal-app-1 sh -c "
  cd /workspace && iex -S mix
"

# In IEx:
# > Indrajaal.Repo.query!("SELECT 1")
# > Node.list()
# > :observer.start()  # Requires X11 forwarding

# Remote IEx connection (if epmd running)
podman exec -it indrajaal-app-1 sh -c "
  iex --name debug@172.31.0.20 --remsh indrajaal@app-1
"
```

---

## Appendix A: File Reference

| File | Purpose |
|------|---------|
| `podman-compose-3container.yml` | Main compose file |
| `tailscale.env` | Environment variables |
| `monitoring/prometheus.yml` | Prometheus configuration |
| `monitoring/otel-collector-config.yaml` | OTEL Collector configuration |
| `monitoring/grafana/provisioning/` | Grafana datasources and dashboards |
| `config/nginx/nginx.conf` | Nginx main configuration |
| `config/nginx/conf.d/` | Nginx site configurations |

## Appendix B: STAMP Compliance Matrix

| Constraint | Requirement | Implementation | Verification |
|------------|-------------|----------------|--------------|
| **SC-CNT-009** | **NixOS containers only** | `localhost/indrajaal-*:nixos-*` images | `podman images \| grep localhost` |
| **SC-CNT-010** | **localhost/ registry only** | All images from `localhost/` | No external registry pulls |
| **SC-CNT-012** | **Rootless execution** | Podman rootless mode | `podman info --format '{{.Host.Security.Rootless}}'` |
| SC-CNT-014 | Resource isolation | Per-container CPU/RAM limits | `deploy.resources` in compose |
| SC-CLU-001 | Identity-based networking | Tailscale DNS hostnames | `hostname` in each container |

### Podman Enforcement Rules

| Rule ID | Rule | Enforcement |
|---------|------|-------------|
| **AOR-CNT-001** | Use Podman, NOT Docker | `which docker` must fail or alias to podman |
| **Axiom 2 (Ω₂)** | Runtime ≡ Podman | `podman version` must succeed |
| **SC-CNT-009** | Environment = NixOS Container | All images tagged `nixos-*` |

### Verification Commands

```bash
# Verify Podman is in use (not Docker)
podman version
# Must show: "podman version X.X.X"

# Verify rootless mode
podman info --format '{{.Host.Security.Rootless}}'
# Must show: "true"

# Verify all images are localhost
podman images --format "{{.Repository}}" | grep -v "^localhost/" && echo "VIOLATION: External images detected" || echo "COMPLIANT"

# Verify no Docker daemon running
systemctl is-active docker 2>/dev/null && echo "VIOLATION: Docker daemon running" || echo "COMPLIANT"
```

---

---

## 9. Cortex Container Health Verification

### 9.1 Overview

The Cortex autonomic system includes a dedicated **ContainerHealthSensor** that performs formal verification of container compliance at runtime. This sensor implements the 7-phase verification protocol defined in the formal specifications.

### 9.2 Formal Verification Layers

| Layer | Tool | Purpose | File |
|-------|------|---------|------|
| Layer 1 | Mathematica | Specification | `docs/formal_specs/container_verification.m` |
| Layer 2 | Quint | Model Checking | `docs/formal_specs/container_verification.qnt` |
| Layer 3 | Agda | Constructive Proofs | `docs/formal_specs/container_verification.agda` |
| Layer 4 | ExUnit | Runtime Validation | `test/indrajaal/container/container_verification_test.exs` |

### 9.3 7-Phase Verification Protocol

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CORTEX 7-PHASE CONTAINER VERIFICATION                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 1: VERSION VERIFICATION (SC-CNT-V01, SC-CNT-V02)                      │
│          ├── Elixir 1.19.2 ✓                                                │
│          ├── OTP 28 ✓                                                       │
│          └── ERTS 16.1.1 ✓                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 2: PACKAGE VERIFICATION                                                │
│          └── Required binaries: elixir, erl, git, curl, make, psql, etc.   │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 3: ENVIRONMENT VERIFICATION (SC-CNT-009, SC-CNT-012)                  │
│          ├── Container type: NixOS/Podman ✓                                 │
│          ├── Rootless execution ✓                                           │
│          └── Patient mode flags ✓                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 4: NETWORK VERIFICATION                                                │
│          ├── DNS resolution ✓                                               │
│          └── Localhost connectivity ✓                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 5: SSL VERIFICATION                                                    │
│          ├── CA certificates present ✓                                      │
│          └── SSL application running ✓                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 6: PHICS VERIFICATION (SC-CNT-011)                                    │
│          └── Hot-reload latency < 50ms ✓                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Phase 7: STAMP VERIFICATION                                                  │
│          ├── SC-CNT-009: NixOS container ✓                                  │
│          ├── SC-CNT-010: localhost registry ✓                               │
│          ├── SC-CNT-011: PHICS < 50ms ✓                                     │
│          ├── SC-CNT-012: rootless execution ✓                               │
│          ├── SC-CNT-V01: Elixir 1.19.x ✓                                    │
│          └── SC-CNT-V02: OTP 28 ✓                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.4 Cortex Integration

The ContainerHealthSensor is integrated into the Cortex OODA loop:

```elixir
# lib/indrajaal/cortex/sensors/container_health_sensor.ex

# OBSERVE phase collects container metrics
def measure do
  %{
    healthy: state.phase == :complete,
    stamp_compliant: all_stamp_satisfied?(state.stamp_constraints),
    verification_count: state.verification_count,
    failure_rate: calculate_failure_rate(state)
  }
end

# Cortex Controller calculates container stress (0.0 - 1.0)
# Stress levels:
#   1.0 - Container unhealthy
#   0.7 - STAMP violation
#   0.6 - High failure rate (>50%)
#   0.3 - Moderate failure rate (>20%)
#   0.0 - Healthy, compliant
```

### 9.5 Agda Proofs (Eternal Guarantees)

Key theorems proven in `docs/formal_specs/container_verification.agda`:

| Theorem | Meaning |
|---------|---------|
| `docker-forbidden` | Docker runtime IMPOSSIBLE with STAMP compliance |
| `external-registry-forbidden` | External registries IMPOSSIBLE |
| `non-nixos-forbidden` | Non-NixOS containers IMPOSSIBLE |
| `compliant-passes-verification` | Compliant containers ALWAYS pass |
| `<ₚ-wellFounded` | Verification ALWAYS terminates |

### 9.6 TDG Rules for Containers

| Rule | Description |
|------|-------------|
| TDG-CNT-001 | Tests MUST precede container build |
| TDG-CNT-002 | Version tests MUST verify Elixir/OTP/ERTS |
| TDG-CNT-003 | Package tests MUST verify all required binaries |
| TDG-CNT-004 | Every STAMP constraint MUST have a test |
| TDG-CNT-005 | Health check tests MUST cover all 7 phases |

### 9.7 AOR Rules for Containers

| Rule | Description |
|------|-------------|
| AOR-CNT-001 | Docker is FORBIDDEN, Podman REQUIRED |
| AOR-CNT-002 | nix-build for container creation |
| AOR-CNT-003 | localhost registry only |
| AOR-CNT-004 | Image tags MUST include git revision |
| AOR-CNT-005 | Rootless execution REQUIRED |
| AOR-CNT-006 | NixOS base images only |

---

## Appendix C: Formal Verification Commands

```bash
# Quint model checking (100 steps)
quint verify --invariant=containerSafetyInvariant --max-steps=100 \
  docs/formal_specs/container_verification.qnt

# Agda proof verification
agda --safe docs/formal_specs/container_verification.agda

# ExUnit container tests (109+ tests)
MIX_ENV=test mix test test/indrajaal/container/container_verification_test.exs

# Cortex container health verification (runtime)
iex -S mix -e "Indrajaal.Cortex.Sensors.ContainerHealthSensor.full_verification()"
```

---

## 10. Container Verification Functions

### 10.1 Bash Verification Functions

The `scripts/cluster/cluster_env.sh` provides shell-level verification functions for container compliance.

#### 10.1.1 Version Verification Function

```bash
# verify_container_versions(container_name)
# Verifies Elixir and OTP versions in a running container
# Returns: 0 if pass, 1 if fail

verify_container_versions() {
    local container_name="${1:-indrajaal-app-demo}"

    # Get Elixir version
    local elixir_version=$(podman exec "$container_name" elixir --version 2>/dev/null \
        | grep "Elixir" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    # Verify Elixir 1.19.x
    local elixir_major=$(echo "$elixir_version" | cut -d. -f1)
    local elixir_minor=$(echo "$elixir_version" | cut -d. -f2)

    if [ "$elixir_major" != "$EXPECTED_ELIXIR_MAJOR" ] || \
       [ "$elixir_minor" != "$EXPECTED_ELIXIR_MINOR" ]; then
        echo "❌ Elixir version mismatch: got $elixir_version, expected 1.19.x"
        return 1
    fi

    # Get OTP version
    local otp_version=$(podman exec "$container_name" elixir --version 2>/dev/null \
        | grep "OTP" | grep -oE '[0-9]+' | head -1)

    if [ "$otp_version" != "$EXPECTED_OTP_MAJOR" ]; then
        echo "❌ OTP version mismatch: got $otp_version, expected 28"
        return 1
    fi

    echo "🎉 Container version verification: PASSED"
    return 0
}
```

#### 10.1.2 STAMP Constraint Verification

```bash
# verify_stamp_constraints()
# Verifies STAMP container safety constraints
# Returns: 0 if pass, 1 if fail

verify_stamp_constraints() {
    local errors=0

    # SC-CNT-009: Container OS is NixOS
    if podman images --format "{{.Repository}}" | grep -q "^localhost/"; then
        echo "✅ SC-CNT-009: NixOS containers (localhost registry)"
    else
        echo "❌ SC-CNT-009: VIOLATION - Non-localhost images detected"
        errors=$((errors + 1))
    fi

    # SC-CNT-012: Rootless execution
    if podman info --format "{{.Host.Security.Rootless}}" 2>/dev/null | grep -q "true"; then
        echo "✅ SC-CNT-012: Rootless execution enabled"
    else
        echo "❌ SC-CNT-012: VIOLATION - Not running rootless"
        errors=$((errors + 1))
    fi

    # AOR-CNT-001: Docker forbidden
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo "⚠️  WARNING: Docker daemon is running (AOR-CNT-001: Docker FORBIDDEN)"
    else
        echo "✅ AOR-CNT-001: Docker not in use"
    fi

    if [ $errors -gt 0 ]; then
        echo "❌ STAMP verification: FAILED ($errors violations)"
        return 1
    fi

    echo "🎉 STAMP verification: PASSED"
    return 0
}
```

#### 10.1.3 Environment Variable Exports

```bash
# Container Version Requirements (SC-CNT-V01, SC-CNT-V02)
export EXPECTED_ELIXIR_MAJOR=1
export EXPECTED_ELIXIR_MINOR=19
export EXPECTED_ELIXIR_PATCH=2
export EXPECTED_OTP_MAJOR=28
export EXPECTED_OTP_MINOR=0
export EXPECTED_OTP_PATCH=0
export EXPECTED_ERTS_MAJOR=16
export EXPECTED_ERTS_MINOR=1
export EXPECTED_ERTS_PATCH=1
```

---

## 11. Container Health Telemetry

### 11.1 Overview

The `ContainerHealthTelemetry` module provides comprehensive observability for container verification operations.

### 11.2 Telemetry Events

| Event | Description | Measurements |
|-------|-------------|--------------|
| `[:indrajaal, :container, :health, :verification, :start]` | Verification started | `system_time` |
| `[:indrajaal, :container, :health, :verification, :stop]` | Verification completed | `duration_ms`, `success` |
| `[:indrajaal, :container, :health, :phase, :complete]` | Phase passed | `phase`, `duration_ms` |
| `[:indrajaal, :container, :health, :phase, :failed]` | Phase failed | `phase`, `duration_ms`, `error` |
| `[:indrajaal, :container, :health, :stamp, :check]` | STAMP constraint checked | `constraint_id`, `satisfied` |
| `[:indrajaal, :container, :health, :stamp, :violation]` | STAMP violation detected | `constraint_id`, `severity` |

### 11.3 Metrics Emitted

```
container_health_verification_duration_ms (histogram)
container_health_phase_duration_ms (histogram by phase)
container_health_verification_count (counter)
container_health_verification_failures (counter)
container_health_stamp_violations (counter by constraint)
container_health_phics_latency_ms (gauge)
```

### 11.4 OpenTelemetry Integration

All telemetry events emit OpenTelemetry spans with relevant attributes:

```elixir
# Verification span
Tracer.with_span "container.health.verification", kind: :internal do
  Tracer.set_attributes([
    {"container.verification.success", true},
    {"container.verification.duration_ms", 45.2},
    {"container.node", "indrajaal@app-1.tail55d152.ts.net"}
  ])
end

# STAMP violation span
Tracer.with_span "container.health.stamp.violation", kind: :internal do
  Tracer.set_attributes([
    {"stamp.constraint_id", "SC-CNT-009"},
    {"stamp.severity", "critical"},
    {"stamp.violation_reason", "Docker detected"}
  ])
  Tracer.set_status(:error, "STAMP constraint SC-CNT-009 violated")
end
```

### 11.5 Usage

```elixir
# Attach telemetry handlers at application startup
def start(_type, _args) do
  # Attach container health telemetry
  Indrajaal.Cortex.Sensors.ContainerHealthTelemetry.attach()

  # ... rest of supervision tree
end

# Emit events manually
alias Indrajaal.Cortex.Sensors.ContainerHealthTelemetry, as: Telemetry

Telemetry.emit_verification_start(%{verification_count: 5})
Telemetry.emit_phase_complete(:verifying_versions, 12.5, %{elixir: "1.19.2"})
Telemetry.emit_stamp_check("SC-CNT-009", true, %{container_type: :nixos})
Telemetry.emit_stamp_violation("SC-CNT-012", "Running as root", :critical)
Telemetry.emit_verification_stop(true, 156.7, %{phases: 7})
```

---

## 12. OODA Loop Integration

### 12.1 Container Observations in OODA

The Cortex Controller's OODA loop observes container health as part of the Observe phase:

```elixir
# lib/indrajaal/cortex/controller.ex

defp observe do
  %{
    system: safe_measure(SystemSensor),
    flame: safe_measure(FLAMESensor),
    ml: safe_measure(MLSensor),
    container: safe_measure(ContainerHealthSensor),  # Container health
    circuit_breakers: CircuitBreaker.status(),
    timestamp: DateTime.utc_now()
  }
end
```

### 12.2 Container Stress Calculation

Container health affects the overall system stress score in the Orient phase:

```elixir
# Stress weighting (from controller.ex)
overall_stress =
  system_stress * 0.35 +
  flame_stress * 0.25 +
  ml_stress * 0.20 +
  container_stress * 0.20  # 20% weight for container health

# Container stress calculation
defp calculate_container_stress(%{error: true}), do: 0.8  # Unknown = high stress
defp calculate_container_stress(metrics) do
  healthy = Map.get(metrics, :healthy, false)
  stamp_compliant = Map.get(metrics, :stamp_compliant, false)
  failure_rate = Map.get(metrics, :failure_rate, 0.0)

  cond do
    not healthy -> 1.0           # Unhealthy container = max stress
    not stamp_compliant -> 0.7   # STAMP violation = high stress
    failure_rate > 0.5 -> 0.6    # High failure rate = elevated stress
    failure_rate > 0.2 -> 0.3    # Moderate failure rate
    true -> 0.0                   # Healthy, compliant = no stress
  end
end
```

### 12.3 Anomaly Detection

Container anomalies trigger alerts:

```elixir
defp detect_anomalies(observation) do
  anomalies = []

  # Container health anomalies (SC-CNT-009 to SC-CNT-012)
  container_healthy = get_in(observation, [:container, :healthy])
  stamp_compliant = get_in(observation, [:container, :stamp_compliant])

  anomalies = if container_healthy == false,
    do: [:container_unhealthy | anomalies], else: anomalies
  anomalies = if stamp_compliant == false,
    do: [:stamp_violation | anomalies], else: anomalies

  anomalies
end
```

### 12.4 Decision Phase

Container stress influences scaling decisions:

| Stress Level | Container State | Action |
|--------------|-----------------|--------|
| > 0.9 | Critical | Emergency scale up, alert |
| > 0.7 | High (STAMP violation) | Alert, queue remediation |
| > 0.3 | Moderate | Log warning, monitor |
| < 0.3 | Healthy | Normal operation |

---

## 13. Validation Approach

### 13.1 Five-Layer Validation Pyramid

```
           ┌─────────────────────┐
           │   Layer 5: Agda     │  Eternal proofs (∀ executions)
           │   Proofs            │  docker-forbidden, compliant-passes
           ├─────────────────────┤
           │   Layer 4: Quint    │  Model checking (bounded)
           │   Model Checking    │  containerSafetyInvariant
           ├─────────────────────┤
           │   Layer 3: ExUnit   │  Runtime tests (109+ tests)
           │   Tests             │  Elixir property tests
           ├─────────────────────┤
           │   Layer 2: Cortex   │  Runtime monitoring
           │   Health Sensor     │  7-phase verification
           ├─────────────────────┤
           │   Layer 1: Bash     │  Shell verification
           │   Verification      │  verify_container_versions()
           └─────────────────────┘
```

### 13.2 Compile-Time Verification

| Check | Tool | Trigger |
|-------|------|---------|
| Type safety | Dialyzer | `mix dialyzer` |
| Code quality | Credo | `mix credo --strict` |
| Security | Sobelow | `mix sobelow --exit` |
| Formatting | mix format | `mix format --check-formatted` |
| Dependencies | mix deps | `mix deps.audit` |

### 13.3 Runtime Verification

| Check | Component | Frequency |
|-------|-----------|-----------|
| Container versions | ContainerHealthSensor | On startup + periodic |
| STAMP constraints | ContainerHealthSensor | On startup + periodic |
| PHICS latency | ContainerHealthSensor | Every verification cycle |
| Network health | ContainerHealthSensor | Every verification cycle |
| SSL certificates | ContainerHealthSensor | Every verification cycle |

### 13.4 Continuous Validation Workflow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     CONTINUOUS VALIDATION WORKFLOW                        │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  BUILD TIME                                                               │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐          │
│  │  nix-build     │───►│  podman load   │───►│  verify_       │          │
│  │  container     │    │  image         │    │  container_    │          │
│  │                │    │                │    │  versions()    │          │
│  └────────────────┘    └────────────────┘    └────────────────┘          │
│                                                     │                     │
│                                                     ▼                     │
│  STARTUP TIME                              ┌────────────────┐            │
│  ┌────────────────┐    ┌────────────────┐ │  ContainerHealth│            │
│  │  podman-compose│───►│  Cortex        │─►│  Sensor        │            │
│  │  up -d         │    │  Supervisor    │  │  7-phase       │            │
│  └────────────────┘    └────────────────┘ └────────────────┘            │
│                                                     │                     │
│                                                     ▼                     │
│  RUNTIME                                   ┌────────────────┐            │
│  ┌────────────────┐    ┌────────────────┐ │  Telemetry     │            │
│  │  OODA Loop     │◄───│  measure()     │◄─│  Events        │            │
│  │  Observe       │    │  every 30s     │  │  + OpenTelemetry│           │
│  └────────────────┘    └────────────────┘ └────────────────┘            │
│         │                                                                 │
│         ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │                    DECISION & ACTION                               │    │
│  │  - stress > 0.9: Emergency response                               │    │
│  │  - stamp_violation: Alert + remediation queue                     │    │
│  │  - container_unhealthy: Restart + investigate                     │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### 13.5 Validation Commands

```bash
# Full validation pipeline
#!/bin/bash

echo "=== COMPILE-TIME VALIDATION ==="
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix dialyzer

echo "=== BUILD-TIME VALIDATION ==="
nix-build containers/sopv51-elixir-app.nix -o result-app
podman load < result-app
source scripts/cluster/cluster_env.sh
verify_container_versions "$(podman ps -q -l)"
verify_stamp_constraints

echo "=== RUNTIME VALIDATION ==="
podman-compose --env-file tailscale.env -f podman-compose.yml up -d

# Wait for Cortex startup
sleep 30

# Check initial verification
podman exec indrajaal-app sh -c "
  mix run -e 'Indrajaal.Cortex.Sensors.ContainerHealthSensor.full_verification() |> IO.inspect()'
"

echo "=== FORMAL VERIFICATION ==="
quint verify --invariant=containerSafetyInvariant --max-steps=100 \
  docs/formal_specs/container_verification.qnt

agda --safe docs/formal_specs/container_verification.agda

echo "=== EXUNIT TESTS ==="
MIX_ENV=test mix test test/indrajaal/container/ --trace
```

---

**Document Version History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.1.0 | 2025-12-19 | Claude Code | Added verification functions, telemetry, OODA integration |
| 2.0.0 | 2025-12-19 | Claude Code | Added Cortex health verification, formal specs |
| 1.0.0 | 2025-12-19 | Claude Code | Initial release |
