# Container Infrastructure Unified Plan

**Date**: 2025-11-25 16:45:00 CEST
**Status**: 🚧 PLANNING PHASE
**Framework**: SOPv5.11 + AEE + GDE + TPS + STAMP + PHICS v2.1

## Executive Summary

This plan addresses the critical integration gap between the SigNoz observability stack and the main application infrastructure. Currently, SigNoz containers run via a separate `containers/signoz/docker-compose.yml` file, preventing unified orchestration across dev/test/demo environments.

**Critical Issues Identified**:
1. SigNoz stack isolated from main application orchestration
2. Query Service crash-looping (exit code 1)
3. OTEL Collector showing unhealthy status
4. Redis container stuck in "starting" state
5. Application container (indrajaal-dev) not running
6. 10 component containers never started
7. Port conflict between SigNoz Query Service (8080) and nginx (8080)

**Strategic Goal**: Create unified container orchestration supporting dev, test, and demo environments with comprehensive observability and logging across all services.

## Current State Analysis

### SigNoz Observability Stack (Production Ready - Phase 5)

**Location**: `containers/signoz/`
**Status**: Production ready but isolated
**Architecture**: 4-container stack
  - **ClickHouse**: OLAP database for telemetry storage (Up 2 days, healthy)
  - **OTEL Collector**: OpenTelemetry data ingestion (Up 2 days, unhealthy)
  - **Query Service**: API layer for data retrieval (Crash-looping, exit code 1)
  - **Frontend**: Web UI for observability (Up 2 days, healthy)

**Resources Allocated**:
  - Total: 4.5 CPU cores, 4.5GB RAM
  - ClickHouse: 2.0 CPU, 2GB RAM (limits), 1.0 CPU, 1GB RAM (reservations)
  - OTEL Collector: 1.0 CPU, 1GB RAM (limits), 0.5 CPU, 512MB RAM (reservations)
  - Query Service: 1.0 CPU, 1GB RAM (limits), 0.5 CPU, 512MB RAM (reservations)
  - Frontend: 0.5 CPU, 512MB RAM (limits), 0.25 CPU, 256MB RAM (reservations)

**Network**: signoz-network (bridge driver)
**Volumes**:
  - signoz-clickhouse-data (local)
  - signoz-query-service-data (local)
  - signoz-otel-collector-data (local)

**Ports**:
  - ClickHouse: 9000 (native), 8123 (HTTP)
  - OTEL Collector: 4317 (gRPC), 4318 (HTTP), 8888 (metrics), 13133 (health)
  - Query Service: 8081:8080 (host:container) - **PORT CONFLICT RESOLVED**
  - Frontend: 3301 (UI)

**Known Issues Documented**:
1. OTEL Collector health check uses wget, but container lacks wget binary
2. Query Service port changed from 8080 to 8081 to avoid conflict with nginx
3. ClickHouse custom configs not loaded due to SELinux permission issues

### Main Application Infrastructure

**Location**: `podman-compose.yml` (root)
**Status**: Partially operational
**Services Defined**: 6 services
  - postgres (TimescaleDB)
  - redis
  - app (Elixir/Phoenix)
  - prometheus
  - grafana
  - nginx

**Current Operational Status** (from `podman ps`):
1. **indrajaal-timescaledb-demo**: ✅ Up 59 minutes (healthy)
   - Port: 5433
   - Recent work: Security implementation complete, postgres user (UID 999) operational

2. **indrajaal-redis-demo**: ⚠️ Up 2 hours (starting)
   - Port: 6379
   - Issue: Stuck in "starting" state, health check not passing

3. **indrajaal-dev**: ❌ Exited (0) 7 hours ago
   - Ports: 4000-4001
   - Issue: Application container not running, needs restart

4. **10 Component Containers**: ❌ Created but not started
   - accounts, devices, observability, compliance, analytics, etc.
   - Status: All in "Created" state
   - Purpose: Unclear - need to determine if these are test fixtures or required services

**Port Conflict**:
- nginx uses port 8080 in main `podman-compose.yml`
- SigNoz Query Service originally configured for port 8080
- Currently resolved by mapping Query Service to 8081:8080

### Integration Gap Analysis

**Critical Finding**: SigNoz and application containers run in separate orchestration contexts:

```
Current Architecture:
┌─────────────────────────────────────┐
│ containers/signoz/docker-compose.yml│
│                                     │
│ ┌──────────┐  ┌────────────────┐  │
│ │ClickHouse│  │ OTEL Collector │  │
│ └──────────┘  └────────────────┘  │
│ ┌──────────────┐  ┌──────────┐   │
│ │Query Service │  │ Frontend │   │
│ └──────────────┘  └──────────┘   │
│                                     │
│ Network: signoz-network            │
└─────────────────────────────────────┘
               ⚠️ NO CONNECTION ⚠️
┌─────────────────────────────────────┐
│ podman-compose.yml (root)           │
│                                     │
│ ┌──────────┐  ┌───────┐  ┌──────┐ │
│ │TimescaleDB│ │ Redis │  │ App  │ │
│ └──────────┘  └───────┘  └──────┘ │
│ ┌──────────┐  ┌────────┐ ┌──────┐ │
│ │Prometheus│  │Grafana │ │nginx │ │
│ └──────────┘  └────────┘ └──────┘ │
│                                     │
│ Network: (default bridge)          │
└─────────────────────────────────────┘
```

**Impact**:
1. Cannot manage all containers together with single `podman-compose` command
2. Application cannot send telemetry to OTEL Collector (different networks)
3. No unified health monitoring across all services
4. Environment-specific configurations (dev/test/demo) impossible to manage
5. Cannot leverage podman-compose dependency ordering between app and observability services

## Proposed Unified Architecture

### Design Principles

1. **Single Orchestration File**: Merge SigNoz services into main `podman-compose.yml`
2. **Unified Network**: All services on same network for inter-container communication
3. **Service Dependencies**: Proper startup ordering with health check dependencies
4. **Environment Profiles**: Support dev/test/demo configurations via environment variables
5. **Resource Management**: STAMP safety constraints with CPU/memory limits
6. **Observability-First**: All application services configured to send telemetry to SigNoz
7. **Port Management**: Resolve conflicts, standardize port allocation
8. **Volume Strategy**: Persistent data volumes for databases, ephemeral for dev cache

### Unified Container Architecture

```
Unified podman-compose.yml:
┌─────────────────────────────────────────────────────────────┐
│ Networks: indrajaal-network (bridge)                        │
├─────────────────────────────────────────────────────────────┤
│ PERSISTENCE LAYER                                           │
│ ┌──────────────┐  ┌───────────┐  ┌──────────────────┐    │
│ │ TimescaleDB  │  │   Redis   │  │   ClickHouse     │    │
│ │ (postgres)   │  │  (cache)  │  │  (telemetry DB)  │    │
│ │ Port: 5433   │  │ Port: 6379│  │ Ports: 9000,8123 │    │
│ └──────────────┘  └───────────┘  └──────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│ OBSERVABILITY LAYER                                         │
│ ┌────────────────┐  ┌──────────────────┐  ┌────────────┐  │
│ │ OTEL Collector │  │  Query Service   │  │  Frontend  │  │
│ │ (ingestion)    │  │  (API)           │  │  (UI)      │  │
│ │ Ports: 4317/18 │  │ Port: 8081       │  │ Port: 3301 │  │
│ └────────────────┘  └──────────────────┘  └────────────┘  │
├─────────────────────────────────────────────────────────────┤
│ APPLICATION LAYER                                           │
│ ┌──────────────────────────────────────────────────────┐   │
│ │            Elixir/Phoenix Application                │   │
│ │            (indrajaal-dev)                           │   │
│ │            Ports: 4000 (HTTP), 4001 (HTTPS)         │   │
│ │            Sends telemetry to OTEL Collector         │   │
│ └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│ MONITORING LAYER                                            │
│ ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│ │ Prometheus   │  │   Grafana    │  │     nginx       │  │
│ │ (metrics)    │  │  (dashboards)│  │  (reverse proxy)│  │
│ │ Port: 9090   │  │  Port: 3000  │  │  Port: 8080     │  │
│ └──────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘

Startup Dependencies:
1. TimescaleDB, Redis, ClickHouse (parallel, no dependencies)
2. OTEL Collector (depends on ClickHouse health)
3. Query Service (depends on ClickHouse + OTEL Collector health)
4. Frontend (depends on Query Service health)
5. Application (depends on TimescaleDB + Redis + OTEL Collector health)
6. Prometheus (depends on Application health)
7. Grafana (depends on Prometheus health)
8. nginx (depends on Application + Frontend health)
```

### Port Allocation Strategy

**Resolved Allocations**:
```
Database Tier:
  - 5433: TimescaleDB (PostgreSQL)
  - 6379: Redis
  - 9000: ClickHouse (native protocol)
  - 8123: ClickHouse (HTTP interface)

Observability Tier:
  - 4317: OTEL Collector (gRPC OTLP)
  - 4318: OTEL Collector (HTTP OTLP)
  - 8888: OTEL Collector (Prometheus metrics)
  - 13133: OTEL Collector (health check)
  - 8081: SigNoz Query Service (API) - CHANGED FROM 8080
  - 3301: SigNoz Frontend (UI)

Application Tier:
  - 4000: Phoenix HTTP
  - 4001: Phoenix HTTPS

Monitoring Tier:
  - 9090: Prometheus
  - 3000: Grafana
  - 8080: nginx (reverse proxy)
```

**Port Conflict Resolution**:
- Original: SigNoz Query Service wanted 8080, nginx already using 8080
- Resolution: Map Query Service as 8081:8080 (host:container)
- Container internally uses 8080, externally accessible at 8081

### Network Architecture

**Single Network Design**:
```yaml
networks:
  indrajaal-network:
    driver: bridge
    name: indrajaal-network
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

**Service Communication**:
- All containers on `indrajaal-network`
- DNS resolution by container name (e.g., `clickhouse`, `otel-collector`, `postgres`)
- Internal communication uses container ports (e.g., Query Service internally is `query-service:8080`)
- External access uses host-mapped ports (e.g., Query Service externally is `localhost:8081`)

### Volume Strategy

**Persistent Volumes** (data must survive container recreation):
```yaml
volumes:
  postgres-data:
    driver: local
  redis-data:
    driver: local
  clickhouse-data:
    driver: local
  query-service-data:
    driver: local
  otel-collector-data:
    driver: local
  prometheus-data:
    driver: local
  grafana-data:
    driver: local
```

**Bind Mounts** (development convenience):
- Application code: `./:/workspace:z` (SELinux labeled)
- Config files: `./config/[service]/:/etc/[service]/:ro` (read-only)

## Environment-Specific Configurations

### Development Environment

**Purpose**: Local development with hot-reloading, verbose logging, debug tools

**Characteristics**:
- Application with PHICS v2.1 hot-reloading enabled
- All debug endpoints accessible
- Verbose logging (level: debug)
- No resource limits (use full development machine capacity)
- Local file system bind mounts for code
- PostgreSQL with development fixtures
- Redis without persistence (cache only)

**Configuration**:
```yaml
services:
  app:
    environment:
      - MIX_ENV=dev
      - PHX_SERVER=true
      - PHICS_HOT_RELOAD=enabled
      - LOG_LEVEL=debug
      - OTEL_SERVICE_NAME=indrajaal-dev
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
    volumes:
      - ./:/workspace:z
    command: ["mix", "phx.server"]
```

### Test Environment

**Purpose**: Automated testing, CI/CD integration, reproducible test runs

**Characteristics**:
- Application in test mode
- Fresh database for each test run
- In-memory Redis
- Test fixtures loaded
- Isolated from dev/demo data
- Telemetry disabled or mocked

**Configuration**:
```yaml
services:
  app-test:
    environment:
      - MIX_ENV=test
      - PHX_SERVER=false
      - LOG_LEVEL=warn
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5433/indrajaal_test
      - OTEL_TRACES_EXPORTER=none
    command: ["mix", "test"]
```

### Demo Environment

**Purpose**: Customer demonstrations, realistic data, production-like setup

**Characteristics**:
- Application in prod mode (but not actual production)
- Demo fixtures with realistic data
- Full observability stack operational
- Performance optimized
- Prometheus + Grafana dashboards configured
- SigNoz UI accessible for demo

**Configuration**:
```yaml
services:
  app-demo:
    environment:
      - MIX_ENV=prod
      - PHX_SERVER=true
      - LOG_LEVEL=info
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5433/indrajaal_demo
      - OTEL_SERVICE_NAME=indrajaal-demo
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
      - DEMO_MODE=enabled
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
```

## Implementation Phases

### Phase 1: Fix Operational Issues (PRIORITY: CRITICAL)

**Objective**: Restore operational health of existing containers before integration

**Tasks**:
1. **Fix Query Service Crash-Loop**
   - Check logs: `podman logs signoz-query-service`
   - Common causes: ClickHouse connection failure, config file missing, port bind failure
   - Verify ClickHouse accessibility: `podman exec signoz-query-service curl http://clickhouse:9000`
   - Verify config file mount: `podman exec signoz-query-service ls -la /root/config/`

2. **Fix OTEL Collector Health Check**
   - Known issue: health check uses wget, container lacks wget
   - Solution options:
     a. Install wget in container (modify Nix build)
     b. Change health check to use curl instead
     c. Use TCP socket check instead of HTTP
   - Recommended: Change health check to `curl -f http://localhost:13133/ || exit 1`

3. **Fix Redis Stuck in Starting**
   - Check logs: `podman logs indrajaal-redis-demo`
   - Verify health check: `podman exec indrajaal-redis-demo redis-cli ping`
   - Check if health check command is correct in podman-compose.yml

4. **Restart Application Container**
   - Investigate exit reason: `podman logs indrajaal-dev`
   - Check if exit code 0 means normal shutdown or crash
   - Verify PHICS integration is functional
   - Start with: `podman-compose up -d app`

5. **Investigate Component Containers**
   - List containers: `podman ps -a | grep Created`
   - Determine purpose: test fixtures, dev services, or obsolete
   - Decision: start if needed, remove if obsolete

**Success Criteria**:
- All containers show "healthy" or "up" status
- No containers in crash-loop
- Application accessible at http://localhost:4000
- SigNoz UI accessible at http://localhost:3301

### Phase 2: Merge SigNoz into Main Orchestration (PRIORITY: HIGH)

**Objective**: Create unified podman-compose.yml with all services

**Tasks**:
1. **Backup Current Configuration**
   ```bash
   cp podman-compose.yml podman-compose.yml.backup.$(date +%Y%m%d-%H%M)
   git add podman-compose.yml.backup.*
   git commit -m "backup: podman-compose.yml before SigNoz integration"
   ```

2. **Define Unified Network**
   ```yaml
   networks:
     indrajaal-network:
       driver: bridge
       name: indrajaal-network
   ```

3. **Merge SigNoz Services**
   - Copy service definitions from `containers/signoz/docker-compose.yml`
   - Update network references: `signoz-network` → `indrajaal-network`
   - Update volume names: prefix with `indrajaal-` for consistency
   - Preserve resource limits and health checks
   - Update Query Service port mapping to 8081:8080

4. **Configure Service Dependencies**
   ```yaml
   services:
     otel-collector:
       depends_on:
         clickhouse:
           condition: service_healthy

     query-service:
       depends_on:
         clickhouse:
           condition: service_healthy
         otel-collector:
           condition: service_healthy

     frontend:
       depends_on:
         query-service:
           condition: service_healthy

     app:
       depends_on:
         postgres:
           condition: service_healthy
         redis:
           condition: service_healthy
         otel-collector:
           condition: service_started
   ```

5. **Test Unified Orchestration**
   ```bash
   # Stop separate SigNoz stack
   cd containers/signoz
   podman-compose down
   cd ../..

   # Start unified stack
   podman-compose up -d

   # Verify all services
   podman-compose ps
   ```

**Success Criteria**:
- Single `podman-compose.yml` manages all services
- All services start in correct dependency order
- No port conflicts
- All containers healthy
- Application can communicate with OTEL Collector

### Phase 3: Configure Application Telemetry (PRIORITY: HIGH)

**Objective**: Configure Elixir/Phoenix application to send telemetry to SigNoz

**Tasks**:
1. **Add OpenTelemetry Dependencies**
   ```elixir
   # mix.exs
   defp deps do
     [
       {:opentelemetry_api, "~> 1.3"},
       {:opentelemetry, "~> 1.4"},
       {:opentelemetry_exporter, "~> 1.7"},
       {:opentelemetry_phoenix, "~> 1.2"},
       {:opentelemetry_ecto, "~> 1.2"},
       {:opentelemetry_oban, "~> 1.0"}
     ]
   end
   ```

2. **Configure OpenTelemetry in Application**
   ```elixir
   # config/runtime.exs
   config :opentelemetry,
     resource: [
       service: [
         name: System.get_env("OTEL_SERVICE_NAME", "indrajaal"),
         namespace: "indrajaal"
       ]
     ]

   config :opentelemetry_exporter,
     otlp_protocol: :grpc,
     otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
   ```

3. **Setup OpenTelemetry in Application Supervisor**
   ```elixir
   # lib/indrajaal/application.ex
   def start(_type, _args) do
     :opentelemetry_cowboy.setup()
     OpentelemetryPhoenix.setup(adapter: :cowboy2)
     OpentelemetryEcto.setup([:indrajaal, :repo])

     # ... rest of supervisor setup
   end
   ```

4. **Add Custom Instrumentation**
   ```elixir
   # lib/indrajaal/telemetry.ex
   defmodule Indrajaal.Telemetry do
     require OpenTelemetry.Tracer

     def start_span(name, attrs \\ %{}) do
       OpenTelemetry.Tracer.start_span(name, %{attributes: attrs})
     end

     def end_span do
       OpenTelemetry.Tracer.end_span()
     end
   end
   ```

5. **Configure Environment Variables in podman-compose.yml**
   ```yaml
   services:
     app:
       environment:
         - OTEL_SERVICE_NAME=indrajaal-dev
         - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
         - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
         - OTEL_TRACES_SAMPLER=always_on
   ```

6. **Test Telemetry Flow**
   ```bash
   # Send test request to application
   curl http://localhost:4000/health

   # Verify trace in SigNoz UI
   open http://localhost:3301

   # Check OTEL Collector metrics
   curl http://localhost:8888/metrics
   ```

**Success Criteria**:
- Application sends traces to OTEL Collector
- Traces visible in SigNoz UI
- Spans captured for HTTP requests, database queries, Oban jobs
- No errors in OTEL Collector logs
- Trace IDs correlate with application logs

### Phase 4: Environment-Specific Configuration (PRIORITY: MEDIUM)

**Objective**: Support dev/test/demo environments with appropriate configurations

**Tasks**:
1. **Create Environment-Specific Compose Files**
   ```bash
   podman-compose.yml              # Base configuration
   podman-compose.dev.yml          # Development overrides
   podman-compose.test.yml         # Test overrides
   podman-compose.demo.yml         # Demo overrides
   ```

2. **Configure Development Environment**
   ```yaml
   # podman-compose.dev.yml
   version: '3.8'
   services:
     app:
       environment:
         - MIX_ENV=dev
         - LOG_LEVEL=debug
         - PHICS_HOT_RELOAD=enabled
       volumes:
         - ./:/workspace:z
       command: ["mix", "phx.server"]
   ```

3. **Configure Test Environment**
   ```yaml
   # podman-compose.test.yml
   version: '3.8'
   services:
     app:
       environment:
         - MIX_ENV=test
         - LOG_LEVEL=warn
         - DATABASE_URL=postgresql://postgres:postgres@postgres:5433/indrajaal_test
       command: ["mix", "test"]

     postgres:
       environment:
         - POSTGRES_DB=indrajaal_test
   ```

4. **Configure Demo Environment**
   ```yaml
   # podman-compose.demo.yml
   version: '3.8'
   services:
     app:
       environment:
         - MIX_ENV=prod
         - LOG_LEVEL=info
         - DEMO_MODE=enabled
       deploy:
         resources:
           limits:
             cpus: '2.0'
             memory: 2G
   ```

5. **Create Helper Scripts**
   ```bash
   # scripts/containers/start-dev.sh
   #!/bin/bash
   podman-compose -f podman-compose.yml -f podman-compose.dev.yml up -d

   # scripts/containers/start-test.sh
   #!/bin/bash
   podman-compose -f podman-compose.yml -f podman-compose.test.yml up -d

   # scripts/containers/start-demo.sh
   #!/bin/bash
   podman-compose -f podman-compose.yml -f podman-compose.demo.yml up -d
   ```

**Success Criteria**:
- Can start dev environment: `./scripts/containers/start-dev.sh`
- Can start test environment: `./scripts/containers/start-test.sh`
- Can start demo environment: `./scripts/containers/start-demo.sh`
- Each environment has appropriate configuration
- No configuration conflicts between environments

### Phase 5: Documentation and Validation (PRIORITY: MEDIUM)

**Objective**: Document unified architecture and validate complete system

**Tasks**:
1. **Update Container Documentation**
   - Update `containers/signoz/README.md` to reference unified orchestration
   - Document new port allocations
   - Document environment-specific startup procedures
   - Update troubleshooting guides

2. **Create Comprehensive Setup Guide**
   ```markdown
   # docs/guides/CONTAINER_SETUP_GUIDE.md

   ## Development Environment
   1. Prerequisites
   2. First-time setup
   3. Daily workflow
   4. Troubleshooting

   ## Test Environment
   1. CI/CD integration
   2. Running tests locally
   3. Test data fixtures

   ## Demo Environment
   1. Demo data setup
   2. Demo scenarios
   3. Resetting demo environment
   ```

3. **Create Validation Script**
   ```bash
   # scripts/validation/validate-container-infrastructure.exs
   #!/usr/bin/env elixir

   # Validate all services are healthy
   # Validate telemetry flow
   # Validate network connectivity
   # Validate volume persistence
   # Generate validation report
   ```

4. **Update PROJECT_TODOLIST.md**
   - Mark completed tasks
   - Add remaining integration tasks
   - Update Task 12.0 progress

5. **Create Architecture Diagrams**
   - Network topology diagram
   - Data flow diagram (application → OTEL → ClickHouse)
   - Dependency graph
   - Port allocation diagram

**Success Criteria**:
- Documentation complete and accurate
- Validation script passes all checks
- TODO list reflects current state
- Architecture diagrams created

## Risk Assessment and Mitigation

### High-Risk Areas

1. **Query Service Crash-Loop**
   - Risk: Cannot complete SigNoz integration without working Query Service
   - Mitigation: Priority fix in Phase 1, investigate logs immediately
   - Rollback: Can continue using separate SigNoz stack if needed

2. **Network Integration Complexity**
   - Risk: Merging two networks may cause connectivity issues
   - Mitigation: Thorough testing after merge, keep backup of original compose files
   - Rollback: Can revert to separate orchestration if issues arise

3. **Port Conflicts**
   - Risk: Unknown port conflicts may appear during integration
   - Mitigation: Comprehensive port audit before merge, test all services
   - Rollback: Can modify port mappings in unified compose file

4. **Resource Contention**
   - Risk: Running all containers together may exceed available resources
   - Mitigation: Monitor resource usage, configure appropriate limits
   - Rollback: Can scale down non-essential services if needed

5. **Data Loss**
   - Risk: Misconfiguration during migration could lead to data loss
   - Mitigation: Backup all volumes before changes, use named volumes
   - Rollback: Can restore from backups if needed

### Medium-Risk Areas

1. **Application Configuration Changes**
   - Risk: OpenTelemetry integration may introduce bugs
   - Mitigation: Thorough testing, feature flags for telemetry
   - Rollback: Can disable telemetry via environment variables

2. **Performance Degradation**
   - Risk: Additional observability overhead may slow application
   - Mitigation: Performance testing, sampling configuration
   - Rollback: Can adjust sampling rate or disable telemetry

3. **Dependency Ordering**
   - Risk: Incorrect dependency configuration may cause startup failures
   - Mitigation: Health checks at each dependency level
   - Rollback: Can adjust dependency order in compose file

### Low-Risk Areas

1. **Documentation Updates**
   - Risk: Minimal, documentation errors don't affect system operation
   - Mitigation: Review and testing of documented procedures

2. **Environment-Specific Configuration**
   - Risk: Low, compose override files are additive
   - Mitigation: Test each environment separately

## Success Criteria

### Technical Success Criteria

✅ **All containers healthy and operational**
- No containers in crash-loop state
- All health checks passing
- No resource exhaustion

✅ **Unified orchestration functional**
- Single `podman-compose up` starts all services
- Correct dependency ordering
- All services on same network

✅ **Telemetry pipeline working end-to-end**
- Application sends traces to OTEL Collector
- OTEL Collector forwards to ClickHouse
- Query Service can retrieve traces
- Traces visible in SigNoz UI

✅ **Environment configurations working**
- Dev environment starts with hot-reloading
- Test environment can run tests
- Demo environment has demo data and configurations

✅ **No regressions**
- TimescaleDB continues working (recent security work preserved)
- Application functionality unchanged
- Performance metrics within acceptable range

### Documentation Success Criteria

✅ **Complete documentation**
- Setup guides for each environment
- Architecture diagrams created
- Troubleshooting procedures documented
- Port allocations documented

✅ **TODO list updated**
- Task 12.0 progress reflected
- New tasks added for remaining work
- Completed tasks marked

### Operational Success Criteria

✅ **Developer experience**
- Single command to start dev environment
- Hot-reloading functional
- Clear error messages if something fails

✅ **CI/CD integration ready**
- Test environment can run in CI pipeline
- No manual setup required for tests
- Consistent test results

✅ **Demo readiness**
- Can start demo environment reliably
- Demo data loads correctly
- SigNoz UI accessible and functional

## Timeline Estimate

**Phase 1**: Fix Operational Issues - **2-4 hours**
- Query Service debugging: 1-2 hours
- OTEL Collector health check fix: 30 minutes
- Redis investigation: 30 minutes
- Application restart and verification: 1 hour

**Phase 2**: Merge SigNoz - **4-6 hours**
- Backup and preparation: 30 minutes
- Service migration: 2 hours
- Dependency configuration: 1 hour
- Testing and debugging: 2-3 hours

**Phase 3**: Application Telemetry - **3-4 hours**
- Add dependencies: 30 minutes
- Configure OpenTelemetry: 1 hour
- Add instrumentation: 1 hour
- Testing and verification: 1-2 hours

**Phase 4**: Environment Configuration - **2-3 hours**
- Create compose override files: 1 hour
- Create helper scripts: 30 minutes
- Testing each environment: 1-2 hours

**Phase 5**: Documentation and Validation - **2-3 hours**
- Documentation updates: 1 hour
- Create validation script: 1 hour
- TODO list updates: 30 minutes
- Architecture diagrams: 30 minutes

**Total Estimated Time**: **13-20 hours**

**Recommended Approach**: Execute phases sequentially over 2-3 days, allowing time for testing and validation between phases.

## Next Steps

1. **Immediate Action** (Phase 1):
   - Check Query Service logs to diagnose crash-loop
   - Fix OTEL Collector health check
   - Investigate Redis startup issue
   - Restart application container

2. **Plan Review**:
   - Review this plan with team
   - Identify any missing considerations
   - Confirm timeline and priorities
   - Get approval to proceed

3. **Implementation**:
   - Execute Phase 1 (operational fixes)
   - Test and validate before proceeding to Phase 2
   - Execute remaining phases sequentially
   - Document progress and issues

4. **Continuous Monitoring**:
   - Track implementation progress
   - Update TODO list regularly
   - Create git commits at logical points
   - Maintain detailed notes of changes and decisions

## SOPv5.11 Framework Application

### AEE (Adaptive Execution Engine)
- **Autonomous Decision-Making**: Plan allows for adaptive changes based on findings during implementation
- **Self-Correction**: Built-in rollback strategies and testing at each phase
- **Continuous Learning**: Documentation of issues and resolutions feeds back into process

### GDE (Goal-Directed Execution)
- **Clear Goals**: Unified orchestration with full observability
- **Measurable Objectives**: Success criteria defined for each phase
- **Progress Tracking**: TODO list updates and git commits track progress toward goal

### TPS (Toyota Production System)
- **Jidoka (Stop and Fix)**: Phase 1 prioritizes fixing existing issues before new work
- **Just-In-Time**: Phases ordered to deliver value incrementally
- **Kaizen (Continuous Improvement)**: Each phase includes lessons learned
- **Respect for People**: Documentation ensures knowledge transfer

### STAMP (Systems-Theoretic Accident Model and Processes)
- **Proactive Hazard Analysis**: Risk assessment section identifies potential issues
- **Safety Constraints**: Resource limits and health checks defined
- **Control Structure**: Dependencies and orchestration order specified
- **System-Level Thinking**: Considers interactions between all components

### PHICS v2.1
- **Hot-Reloading**: Development environment maintains PHICS support
- **Container Integration**: Application code mounted from host
- **Bidirectional Sync**: File changes reflect in container immediately

## Conclusion

This plan provides a comprehensive roadmap for unifying the Indrajaal container infrastructure, resolving operational issues, and establishing proper observability across all environments. By following the phased approach and adhering to the SOPv5.11 framework principles, we will achieve a robust, maintainable, and observable system that supports development, testing, and demonstration needs.

The integration of SigNoz into the main orchestration represents a significant architectural improvement, enabling unified management of all services and complete end-to-end visibility into system behavior.

**Status**: Ready for review and implementation
**Next Action**: Execute Phase 1 to restore operational health
