# Level 2: Container Architecture

**Document Version**: 1.0.0
**Last Updated**: 2025-12-19
**Architecture Level**: C4 Model - Level 2 (Container)
**Parent Document**: [Level 1: System Context](./level-1-system-context.md)

---

## 1. Executive Summary

This document describes the container-level architecture of the Indrajaal platform. The system operates within a **three-container architecture** designed for security isolation, resource optimization, and operational independence.

### Container Overview

| Container | Purpose | Technology | Resources |
|-----------|---------|------------|-----------|
| `indrajaal-app` | Application Runtime | Elixir/Phoenix/BEAM | 12 CPU, 32GB RAM |
| `indrajaal-db` | Data Persistence | PostgreSQL 17 + TimescaleDB | 4 CPU, 16GB RAM |
| `indrajaal-obs` | Observability Stack | SigNoz/OpenTelemetry | 4 CPU, 8GB RAM |

**Total Allocated**: 20 CPU cores, 56GB RAM

---

## 2. Container Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           INTELITOR THREE-CONTAINER ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                        CONTAINER: indrajaal-app                              │    │
│  │                     [Elixir/Phoenix/BEAM Runtime]                            │    │
│  │                        Port: 4000 (HTTP/WS)                                  │    │
│  ├─────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                              │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │    │
│  │  │   Phoenix Web    │  │  Cybernetic      │  │   Domain         │          │    │
│  │  │   Layer          │  │  Control Layer   │  │   Services       │          │    │
│  │  │  ─────────────   │  │  ─────────────   │  │  ─────────────   │          │    │
│  │  │  • Controllers   │  │  • OODA Loop     │  │  • 79 Domains    │          │    │
│  │  │  • Channels      │  │  • Cortex        │  │  • Ash Resources │          │    │
│  │  │  • LiveView      │  │  • Homeostasis   │  │  • Business      │          │    │
│  │  │  • REST API      │  │  • GDE/AEE       │  │    Logic         │          │    │
│  │  │  • GraphQL       │  │  • 175 Agents    │  │  • Validations   │          │    │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘          │    │
│  │                                                                              │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │    │
│  │  │   FLAME Pools    │  │   Broadway       │  │   Oban Workers   │          │    │
│  │  │  ─────────────   │  │   Pipelines      │  │  ─────────────   │          │    │
│  │  │  • Intelligence  │  │  ─────────────   │  │  • Scheduled     │          │    │
│  │  │  • Video         │  │  • Alarm Events  │  │    Jobs          │          │    │
│  │  │  • Analytics     │  │  • Access Events │  │  • Background    │          │    │
│  │  │  • Elastic       │  │  • Device Data   │  │    Processing    │          │    │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘          │    │
│  │                                                                              │    │
│  │  Resources: 12 CPU cores, 32GB RAM                                          │    │
│  │  Scaling: Horizontal (libcluster/Kubernetes)                                │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                          │                                           │
│                                          │ Ecto/PostgreSQL Protocol                  │
│                                          │ Port: 5433                                │
│                                          ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                        CONTAINER: indrajaal-db                               │    │
│  │                    [PostgreSQL 17 + TimescaleDB]                             │    │
│  │                         Port: 5433 (TCP)                                     │    │
│  ├─────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                              │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │    │
│  │  │   PostgreSQL 17  │  │   TimescaleDB    │  │   Extensions     │          │    │
│  │  │  ─────────────   │  │  ─────────────   │  │  ─────────────   │          │    │
│  │  │  • ACID          │  │  • Hypertables   │  │  • pgcrypto      │          │    │
│  │  │  • MVCC          │  │  • Continuous    │  │  • pg_trgm       │          │    │
│  │  │  • WAL           │  │    Aggregates    │  │  • uuid-ossp     │          │    │
│  │  │  • Logical       │  │  • Compression   │  │  • ltree         │          │    │
│  │  │    Replication   │  │  • Retention     │  │  • PostGIS       │          │    │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘          │    │
│  │                                                                              │    │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │    │
│  │  │                        DATABASE SCHEMAS                               │   │    │
│  │  │  • public (core tables, Ash resources)                               │   │    │
│  │  │  • timescale (hypertables: events, metrics, audit)                   │   │    │
│  │  │  • oban (job queue persistence)                                      │   │    │
│  │  │  • extensions (PostGIS, ltree)                                       │   │    │
│  │  └──────────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                              │    │
│  │  Resources: 4 CPU cores, 16GB RAM                                           │    │
│  │  Storage: Persistent Volume (SSD recommended)                               │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                          │                                           │
│                                          │ OTLP/HTTP (Telemetry Export)              │
│                                          │ Port: 4317/4318                           │
│                                          ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                        CONTAINER: indrajaal-obs                              │    │
│  │                    [SigNoz Observability Stack]                              │    │
│  │                      Ports: 3301 (UI), 4317/4318 (OTLP)                      │    │
│  ├─────────────────────────────────────────────────────────────────────────────┤    │
│  │                                                                              │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │    │
│  │  │   SigNoz Core    │  │   ClickHouse     │  │   Query Service  │          │    │
│  │  │  ─────────────   │  │  ─────────────   │  │  ─────────────   │          │    │
│  │  │  • OTLP Receiver │  │  • Column Store  │  │  • Trace Search  │          │    │
│  │  │  • Trace         │  │  • Time-Series   │  │  • Metric        │          │    │
│  │  │    Pipeline      │  │    Optimization  │  │    Aggregation   │          │    │
│  │  │  • Metrics       │  │  • Fast Queries  │  │  • Log Analysis  │          │    │
│  │  │    Collector     │  │                  │  │  • Alerting      │          │    │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘          │    │
│  │                                                                              │    │
│  │  ┌──────────────────────────────────────────────────────────────────────┐   │    │
│  │  │                     OBSERVABILITY CAPABILITIES                        │   │    │
│  │  │  • Distributed Tracing (OpenTelemetry)                               │   │    │
│  │  │  • Metrics Collection (Phoenix.Telemetry, BEAM VM)                   │   │    │
│  │  │  • Log Aggregation (structured JSON logs)                            │   │    │
│  │  │  • Dashboard Visualization                                            │   │    │
│  │  │  • Alerting Rules (STAMP constraint violations)                      │   │    │
│  │  └──────────────────────────────────────────────────────────────────────┘   │    │
│  │                                                                              │    │
│  │  Resources: 4 CPU cores, 8GB RAM                                            │    │
│  │  Storage: Persistent Volume (retention: 30 days default)                    │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Container Specifications

### 3.1 indrajaal-app (Application Container)

#### Purpose
The primary application container running the Elixir/Phoenix/BEAM runtime. Hosts all business logic, API endpoints, real-time communication, and the cybernetic control system.

#### Technology Stack
```yaml
runtime:
  language: Elixir 1.19
  framework: Phoenix 1.7
  vm: BEAM (Erlang OTP 28)

dependencies:
  web: Phoenix, Plug, Bandit
  data: Ash 3.x, AshPostgres, AshPhoenix
  realtime: Phoenix.PubSub, Phoenix.Channels
  async: Broadway, Oban
  distributed: FLAME, libcluster
  observability: OpentelemetryPhoenix, OpentelemetryEcto
```

#### Internal Components

| Component | Responsibility | Key Modules |
|-----------|---------------|-------------|
| Phoenix Web Layer | HTTP/WS handling | Controllers, Channels, LiveView |
| Cybernetic Control | Autonomous operation | OODA, Cortex, GDE, AEE |
| Domain Services | Business logic | 79 Ash domains |
| FLAME Pools | Elastic compute | Intelligence, Video, Analytics |
| Broadway Pipelines | Event processing | Alarm, Access, Device events |
| Oban Workers | Background jobs | Scheduled tasks, reports |

#### Resource Configuration
```elixir
# config/runtime.exs
config :indrajaal, IndrajaalApp,
  cpu_cores: 12,
  memory_mb: 32_768,
  schedulers: 16,
  async_threads: 16,
  io_poll_threads: 16

# BEAM VM Options
ELIXIR_ERL_OPTIONS="+S 16:16 +SDio 16 +A 64"
```

#### Ports and Protocols
| Port | Protocol | Purpose |
|------|----------|---------|
| 4000 | HTTP/1.1, HTTP/2 | REST API, GraphQL |
| 4000 | WebSocket | LiveView, Channels |
| 4369 | EPMD | Erlang Distribution |
| 9100-9199 | TCP | BEAM Distribution |

#### Health Endpoints
```
GET /health          -> Basic health check
GET /health/ready    -> Kubernetes readiness
GET /health/live     -> Kubernetes liveness
GET /health/startup  -> Kubernetes startup probe
```

---

### 3.2 indrajaal-db (Database Container)

#### Purpose
Persistent data storage using PostgreSQL 17 with TimescaleDB extension for time-series optimization. Handles all structured data, event history, and job queue persistence.

#### Technology Stack
```yaml
database:
  engine: PostgreSQL 17
  extensions:
    - TimescaleDB 2.x (time-series)
    - pgcrypto (encryption)
    - pg_trgm (fuzzy search)
    - uuid-ossp (UUID generation)
    - ltree (hierarchical data)
    - PostGIS (geospatial) [optional]
```

#### Database Schemas

| Schema | Purpose | Key Tables |
|--------|---------|------------|
| `public` | Core application data | users, tenants, sites, devices |
| `timescale` | Time-series data | alarm_events, access_logs, metrics |
| `oban` | Job queue | oban_jobs, oban_producers |
| `extensions` | Extension data | spatial_ref_sys (PostGIS) |

#### TimescaleDB Hypertables
```sql
-- Event hypertables with automatic chunking
CREATE TABLE timescale.alarm_events (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  event_type VARCHAR(50),
  data JSONB
);

SELECT create_hypertable('timescale.alarm_events', 'timestamp');

-- Continuous aggregates for dashboards
CREATE MATERIALIZED VIEW alarm_hourly_stats
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', timestamp) AS bucket,
  tenant_id,
  COUNT(*) as event_count
FROM timescale.alarm_events
GROUP BY bucket, tenant_id;
```

#### Resource Configuration
```yaml
# PostgreSQL tuning for container
shared_buffers: 4GB
effective_cache_size: 12GB
maintenance_work_mem: 1GB
checkpoint_completion_target: 0.9
wal_buffers: 64MB
max_connections: 200
```

#### Connection Pooling
```elixir
# Ecto pool configuration
config :indrajaal, Indrajaal.Repo,
  pool_size: 20,
  queue_target: 50,
  queue_interval: 1000,
  timeout: 30_000
```

#### Ports and Protocols
| Port | Protocol | Purpose |
|------|----------|---------|
| 5433 | PostgreSQL Wire Protocol | Database connections |
| 5432 | PostgreSQL (internal) | Replication |

---

### 3.3 indrajaal-obs (Observability Container)

#### Purpose
Centralized observability stack based on SigNoz. Collects, stores, and visualizes traces, metrics, and logs from the application container using OpenTelemetry protocols.

#### Technology Stack
```yaml
observability:
  platform: SigNoz
  collector: OpenTelemetry Collector
  storage: ClickHouse
  protocols:
    - OTLP/gRPC (4317)
    - OTLP/HTTP (4318)
```

#### Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| OTLP Receiver | Ingest telemetry | OpenTelemetry Collector |
| Trace Pipeline | Process spans | SigNoz Query Service |
| Metrics Collector | Aggregate metrics | SigNoz Metrics |
| ClickHouse | Telemetry storage | Column-oriented DB |
| Frontend | Dashboards | SigNoz UI |

#### Data Flow
```
┌─────────────┐    OTLP/gRPC    ┌─────────────────┐
│ indrajaal-  │ ──────────────> │   OpenTelemetry │
│    app      │    Port 4317    │    Collector    │
└─────────────┘                 └────────┬────────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │   ClickHouse    │
                                │   (Storage)     │
                                └────────┬────────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │   SigNoz UI     │
                                │   Port 3301     │
                                └─────────────────┘
```

#### Telemetry Categories
```elixir
# Traces exported
Phoenix.Controller.call
Phoenix.Router.dispatch
Ecto.Repo.query
Broadway.Message.handle
Oban.Job.execute
FLAME.call

# Metrics collected
phoenix_http_request_duration
ecto_query_duration
broadway_message_latency
oban_job_duration
beam_vm_memory
beam_vm_processes
```

#### Resource Configuration
```yaml
# ClickHouse tuning
max_memory_usage: 6GB
max_concurrent_queries: 100
background_pool_size: 16

# Retention policies
trace_retention_days: 30
metrics_retention_days: 90
logs_retention_days: 14
```

#### Ports and Protocols
| Port | Protocol | Purpose |
|------|----------|---------|
| 3301 | HTTP | SigNoz Dashboard UI |
| 4317 | gRPC | OTLP trace/metric receiver |
| 4318 | HTTP | OTLP HTTP receiver |
| 8080 | HTTP | Health check |

---

## 4. Inter-Container Communication

### 4.1 Communication Matrix

```
┌──────────────────┬────────────────┬────────────────┬────────────────┐
│                  │  indrajaal-app │  indrajaal-db  │  indrajaal-obs │
├──────────────────┼────────────────┼────────────────┼────────────────┤
│  indrajaal-app   │       -        │ PostgreSQL     │ OTLP/gRPC      │
│                  │                │ (5433)         │ (4317)         │
├──────────────────┼────────────────┼────────────────┼────────────────┤
│  indrajaal-db    │ Query Response │       -        │       -        │
│                  │                │                │                │
├──────────────────┼────────────────┼────────────────┼────────────────┤
│  indrajaal-obs   │       -        │       -        │       -        │
│                  │                │                │                │
└──────────────────┴────────────────┴────────────────┴────────────────┘
```

### 4.2 Network Configuration

```yaml
# podman-compose.yml network configuration
networks:
  indrajaal-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  indrajaal-app:
    networks:
      indrajaal-network:
        ipv4_address: 172.20.0.10

  indrajaal-db:
    networks:
      indrajaal-network:
        ipv4_address: 172.20.0.20

  indrajaal-obs:
    networks:
      indrajaal-network:
        ipv4_address: 172.20.0.30
```

### 4.3 Service Discovery

```elixir
# Container DNS names (Podman/Kubernetes)
Database: indrajaal-db:5433
Observability: indrajaal-obs:4317

# Environment-based configuration
config :indrajaal, Indrajaal.Repo,
  hostname: System.get_env("DATABASE_HOST", "indrajaal-db"),
  port: System.get_env("DATABASE_PORT", "5433") |> String.to_integer()

config :opentelemetry_exporter,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://indrajaal-obs:4317")
```

---

## 5. Container Orchestration

### 5.1 Podman Compose (Development)

```yaml
# podman-compose.yml
version: "3.8"

services:
  indrajaal-app:
    image: localhost/indrajaal-app:latest
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
      - "4369:4369"
    environment:
      - MIX_ENV=dev
      - DATABASE_URL=ecto://indrajaal:password@indrajaal-db:5433/indrajaal_dev
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://indrajaal-obs:4317
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
    volumes:
      - ./:/app:z
      - deps:/app/deps
      - build:/app/_build
    depends_on:
      - indrajaal-db
      - indrajaal-obs
    deploy:
      resources:
        limits:
          cpus: "12"
          memory: 32G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  indrajaal-db:
    image: timescale/timescaledb:latest-pg17
    ports:
      - "5433:5432"
    environment:
      - POSTGRES_USER=indrajaal
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=indrajaal_dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: 16G
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U indrajaal"]
      interval: 10s
      timeout: 5s
      retries: 5

  indrajaal-obs:
    image: signoz/signoz:latest
    ports:
      - "3301:3301"
      - "4317:4317"
      - "4318:4318"
    volumes:
      - signoz-data:/var/lib/signoz
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: 8G

volumes:
  deps:
  build:
  pgdata:
  signoz-data:
```

### 5.2 Kubernetes (Production)

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: indrajaal-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: indrajaal
      component: app
  template:
    metadata:
      labels:
        app: indrajaal
        component: app
    spec:
      containers:
        - name: indrajaal
          image: registry.example.com/indrajaal:v1.0.0
          ports:
            - containerPort: 4000
          resources:
            requests:
              cpu: "4"
              memory: "8Gi"
            limits:
              cpu: "12"
              memory: "32Gi"
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: indrajaal-secrets
                  key: database-url
          livenessProbe:
            httpGet:
              path: /health/live
              port: 4000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 4000
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: indrajaal-headless
spec:
  clusterIP: None
  selector:
    app: indrajaal
    component: app
  ports:
    - port: 4369
      name: epmd
```

---

## 6. Container Health Monitoring

### 6.1 Health Check Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CORTEX HEALTH MONITORING                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  ContainerHealthSensor                    │   │
│  │  lib/indrajaal/cortex/sensors/container_health_sensor.ex │   │
│  └────────────────────────────┬─────────────────────────────┘   │
│                               │                                  │
│           ┌───────────────────┼───────────────────┐             │
│           ▼                   ▼                   ▼             │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │  App Health    │  │   DB Health    │  │   Obs Health   │    │
│  │  ───────────   │  │  ───────────   │  │  ───────────   │    │
│  │  • HTTP 4000   │  │  • TCP 5433    │  │  • HTTP 4317   │    │
│  │  • /health     │  │  • pg_isready  │  │  • /health     │    │
│  │  • VM metrics  │  │  • Connection  │  │  • Collector   │    │
│  └────────────────┘  └────────────────┘  └────────────────┘    │
│                               │                                  │
│                               ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Homeostasis Engine                     │   │
│  │     lib/indrajaal/cortex/homeostasis.ex                  │   │
│  │  • Stress level calculation                               │   │
│  │  • Adaptive resource allocation                           │   │
│  │  • Anomaly detection and response                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Health Check Implementation

```elixir
# lib/indrajaal/cortex/sensors/container_health_sensor.ex
defmodule Indrajaal.Cortex.Sensors.ContainerHealthSensor do
  use GenServer

  @check_interval 5_000  # 5 seconds

  def check_all_containers do
    %{
      app: check_app_health(),
      db: check_db_health(),
      obs: check_obs_health(),
      overall: calculate_overall_health()
    }
  end

  defp check_app_health do
    case HTTPoison.get("http://localhost:4000/health", [], timeout: 2_000) do
      {:ok, %{status_code: 200}} -> :healthy
      _ -> :unhealthy
    end
  end

  defp check_db_health do
    case Indrajaal.Repo.query("SELECT 1", [], timeout: 2_000) do
      {:ok, _} -> :healthy
      _ -> :unhealthy
    end
  end

  defp check_obs_health do
    case HTTPoison.get("http://indrajaal-obs:8080/health", [], timeout: 2_000) do
      {:ok, %{status_code: 200}} -> :healthy
      _ -> :degraded  # Non-critical
    end
  end
end
```

### 6.3 STAMP Safety Constraints for Containers

| Constraint | Description | Verification |
|------------|-------------|--------------|
| SC-CNT-009 | Execute in NixOS containers only | Runtime check |
| SC-CNT-010 | Use only localhost registry | Image source validation |
| SC-CNT-011 | PHICS latency < 50ms | Continuous monitoring |
| SC-CNT-012 | Rootless container execution | Podman configuration |
| SC-CNT-013 | Health check before operations | Startup probe |
| SC-CNT-014 | Resource isolation maintained | cgroups enforcement |
| SC-CNT-015 | Network security enforced | Network policies |
| SC-CNT-016 | No registry drift | Image hash verification |

---

## 7. PHICS Integration (Hot-Reload)

### 7.1 PHICS Architecture

**PHICS** (Phoenix Hot-reload Integrated Container System) enables real-time code synchronization between host and container with < 50ms latency.

```
┌──────────────────────────────────────────────────────────────────┐
│                     PHICS v2.1 ARCHITECTURE                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  HOST SYSTEM                          CONTAINER                   │
│  ───────────                          ─────────                   │
│                                                                   │
│  ┌────────────────┐                   ┌────────────────┐         │
│  │  Source Code   │  ──── Volume ───> │  /app mounted  │         │
│  │  /home/dev/    │      Mount        │  directory     │         │
│  │  indrajaal     │                   │                │         │
│  └───────┬────────┘                   └───────┬────────┘         │
│          │                                    │                   │
│          │ inotify                            │ fswatch           │
│          ▼                                    ▼                   │
│  ┌────────────────┐                   ┌────────────────┐         │
│  │  File System   │                   │  Phoenix       │         │
│  │  Watcher       │                   │  LiveReload    │         │
│  └───────┬────────┘                   └───────┬────────┘         │
│          │                                    │                   │
│          │ < 50ms                             │ HMR               │
│          │                                    ▼                   │
│          │                            ┌────────────────┐         │
│          │                            │  Browser       │         │
│          └──────────────────────────> │  Auto-refresh  │         │
│                                       └────────────────┘         │
│                                                                   │
│  Latency Target: < 50ms (SC-CNT-011)                             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 7.2 Volume Mount Configuration

```yaml
# Development volume mounts for PHICS
volumes:
  - type: bind
    source: ./lib
    target: /app/lib
    read_only: false
  - type: bind
    source: ./config
    target: /app/config
    read_only: false
  - type: bind
    source: ./priv
    target: /app/priv
    read_only: false
```

---

## 8. Scaling Strategy

### 8.1 Horizontal Scaling (Application)

```elixir
# libcluster configuration for Kubernetes
config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes.DNS,
      config: [
        service: "indrajaal-headless",
        application_name: "indrajaal",
        polling_interval: 5_000
      ]
    ]
  ]
```

### 8.2 Vertical Scaling (Database)

| Tier | Connections | Shared Buffers | Workers |
|------|-------------|----------------|---------|
| Small | 100 | 2GB | 2 |
| Medium | 200 | 4GB | 4 |
| Large | 500 | 8GB | 8 |
| Enterprise | 1000 | 16GB | 16 |

### 8.3 FLAME Elastic Compute

```elixir
# FLAME pool configuration
config :flame,
  pools: [
    intelligence: [
      min: 0,
      max: 10,
      max_concurrency: 5,
      idle_shutdown_after: 30_000
    ],
    video: [
      min: 0,
      max: 20,
      max_concurrency: 3,
      idle_shutdown_after: 60_000
    ],
    analytics: [
      min: 1,
      max: 5,
      max_concurrency: 10,
      idle_shutdown_after: 120_000
    ]
  ]
```

---

## 9. Security Considerations

### 9.1 Container Security

| Security Control | Implementation |
|-----------------|----------------|
| Rootless execution | Podman default |
| Read-only filesystem | `--read-only` flag |
| No privileged mode | `--security-opt=no-new-privileges` |
| Secrets management | Kubernetes Secrets / Vault |
| Network isolation | Dedicated bridge network |
| Image verification | Content trust / Cosign |

### 9.2 Network Security

```yaml
# Kubernetes NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: indrajaal-network-policy
spec:
  podSelector:
    matchLabels:
      app: indrajaal
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: indrajaal
      ports:
        - port: 4000
        - port: 4369
  egress:
    - to:
        - podSelector:
            matchLabels:
              component: db
      ports:
        - port: 5433
    - to:
        - podSelector:
            matchLabels:
              component: obs
      ports:
        - port: 4317
```

---

## 10. Related Documents

| Document | Description |
|----------|-------------|
| [Level 1: System Context](./level-1-system-context.md) | External actors and boundaries |
| [Level 3: Component Architecture](./level-3-component-architecture.md) | Internal components |
| [podman-compose.yml](../../podman-compose.yml) | Development compose file |
| [podman-compose-3container.yml](../../podman-compose-3container.yml) | Three-container setup |
| [CLAUDE.md](../../CLAUDE.md) | STAMP safety constraints |

---

**Document Classification**: Internal Architecture
**Compliance**: SOPv5.11, STAMP SC-CNT-009 to SC-CNT-016
**Next Review**: 2025-03-19
