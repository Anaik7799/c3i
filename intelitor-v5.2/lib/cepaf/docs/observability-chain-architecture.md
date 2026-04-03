# CEPAF Observability Chain Architecture

**Version**: 1.0.0 | **Status**: ACTIVE | **Date**: 2025-12-24
**STAMP Compliance**: SC-OBS-069, SC-OBS-071, SC-CNT-009, SC-CNT-010, SC-CNT-012

## 1. Overview

The CEPAF Observability Chain provides a complete telemetry pipeline for the Indrajaal system, enabling collection, storage, and visualization of traces, metrics, and logs. The architecture is designed around SigNoz as the primary observability platform with Grafana as an alternative visualization layer.

### Key Features
- **Unified Telemetry**: Single OTLP endpoint for all telemetry types
- **Time-Series Storage**: ClickHouse for high-performance trace/metric storage
- **Dual Logging**: SC-OBS-069 compliant terminal + SigNoz logging
- **4 OTEL Modules**: SC-OBS-071 compliant (Traces, Metrics, Logs, Baggage)
- **NixOS Containers**: SC-CNT-009 compliant container images
- **Rootless Execution**: SC-CNT-012 compliant Podman deployment

## 2. Architecture Diagram

```
                              INTELITOR OBSERVABILITY CHAIN
    ============================================================================

                                    LAYER 3: VISUALIZATION
                         +------------------------------------------+
                         |                                          |
                    +----------+                              +----------+
                    | SigNoz   |                              | Grafana  |
                    | Frontend |                              |   UI     |
                    | :8080    |                              |  :3000   |
                    +----+-----+                              +----+-----+
                         |                                         |
                         +---------+                    +----------+
                                   |                    |
    ============================================================================

                                    LAYER 2: QUERY
                               +------------------+
                               |  Query Service   |
                               |     :8085        |
                               |  /api/v1/traces  |
                               |  /api/v1/metrics |
                               |  /api/v1/logs    |
                               +--------+---------+
                                        |
    ============================================================================

                                    LAYER 1: INGESTION
                               +------------------+
                               | OTEL Collector   |
                               |  :4317 (gRPC)    |
                               |  :4318 (HTTP)    |
                               |  :8888 (metrics) |
                               +--------+---------+
                                        |
                        +---------------+---------------+
                        |               |               |
                   [Traces]        [Metrics]        [Logs]
                        |               |               |
                        +-------+-------+-------+-------+
                                |
    ============================================================================

                                    LAYER 0: STORAGE
                               +------------------+
                               |   ClickHouse     |
                               |  :8123 (HTTP)    |
                               |  :9000 (TCP)     |
                               |  :9009 (Native)  |
                               +------------------+

    ============================================================================
                                DATA FLOW (BOTTOM-UP)
```

## 3. Component Descriptions

### 3.1 Layer 0: Storage Foundation

#### ClickHouse (obs-clickhouse)
- **Image**: `localhost/indrajaal-clickhouse:nixos-devenv`
- **Purpose**: Time-series database for traces, metrics, and logs
- **Ports**:
  - `8123`: HTTP interface (queries, health checks)
  - `9000`: Native TCP protocol
  - `9009`: Interserver communication
- **Health Check**: `GET /ping` returns "Ok."
- **Startup Time**: ~60 seconds
- **Data Retention**: 168 hours (7 days)

### 3.2 Layer 1: Ingestion

#### OTEL Collector (obs-otel-collector)
- **Image**: `localhost/indrajaal-otel-collector:nixos-devenv`
- **Purpose**: OpenTelemetry data collection and routing
- **Ports**:
  - `4317`: OTLP gRPC receiver (traces, metrics, logs)
  - `4318`: OTLP HTTP receiver (traces, metrics, logs)
  - `8888`: Collector internal metrics
- **Health Check**: `/health` endpoint
- **Startup Time**: ~30 seconds
- **Dependencies**: ClickHouse (Mandatory)

**SC-OBS-071 Compliance - Required OTEL Modules**:
| Module   | Status   | Description                    |
|----------|----------|--------------------------------|
| Traces   | Required | Distributed tracing            |
| Metrics  | Required | System and application metrics |
| Logs     | Required | Structured logging             |
| Baggage  | Required | Context propagation            |

### 3.3 Layer 2: Query

#### Query Service (obs-query-service)
- **Image**: `localhost/indrajaal-signoz-query:nixos-devenv`
- **Purpose**: Backend API for trace/metric/log queries
- **Ports**:
  - `8085`: Query API
- **Health Check**: `/api/v1/health`
- **Ready Check**: `/api/v1/ready`
- **Startup Time**: ~45 seconds
- **Dependencies**: ClickHouse (Mandatory), OTEL Collector (Optional)

**API Endpoints**:
| Endpoint          | Method | Description              |
|-------------------|--------|--------------------------|
| `/api/v1/traces`  | GET    | Query trace data         |
| `/api/v1/metrics` | GET    | Query metric data        |
| `/api/v1/logs`    | GET    | Query log data           |
| `/api/v1/health`  | GET    | Service health status    |
| `/api/v1/ready`   | GET    | Service readiness status |

### 3.4 Layer 3: Visualization

#### SigNoz Frontend (obs-frontend)
- **Image**: `localhost/indrajaal-signoz-frontend:nixos-devenv`
- **Purpose**: Web UI for observability dashboard
- **Ports**:
  - `8080`: Web interface
- **Health Check**: `/health`
- **Startup Time**: ~30 seconds
- **Dependencies**: Query Service (Mandatory)

#### Grafana (obs-grafana)
- **Image**: `localhost/indrajaal-grafana:nixos-devenv`
- **Purpose**: Alternative visualization with custom dashboards
- **Ports**:
  - `3000`: Web interface
- **Health Check**: `/api/health`
- **Startup Time**: ~45 seconds
- **Dependencies**: ClickHouse (Mandatory), OTEL Collector (Optional)

**Pre-configured Dashboards**:
- System Overview
- Container Metrics
- Trace Analysis

## 4. Port Mapping Reference

| Port | Protocol | Service          | Description                    |
|------|----------|------------------|--------------------------------|
| 4317 | gRPC     | OTEL Collector   | OTLP gRPC receiver             |
| 4318 | HTTP     | OTEL Collector   | OTLP HTTP receiver             |
| 8080 | HTTP     | SigNoz Frontend  | SigNoz Web UI                  |
| 3000 | HTTP     | Grafana          | Grafana Web UI                 |
| 8123 | HTTP     | ClickHouse       | ClickHouse HTTP interface      |
| 9000 | TCP      | ClickHouse       | ClickHouse native protocol     |
| 8085 | HTTP     | Query Service    | SigNoz Query API               |
| 8888 | HTTP     | OTEL Collector   | Collector internal metrics     |

## 5. Health Check Endpoints

### 5.1 ClickHouse
```bash
# HTTP Health Check
curl -sf http://localhost:8123/ping
# Expected: "Ok."

# Query Test
curl -sf http://localhost:8123/ -d "SELECT 1"
# Expected: "1"
```

### 5.2 OTEL Collector
```bash
# gRPC Port Check
nc -z localhost 4317 && echo "gRPC OK"

# HTTP Port Check
curl -sf http://localhost:4318/v1/traces
# Expected: 405 (method not allowed - but endpoint exists)

# Metrics Endpoint
curl -sf http://localhost:8888/metrics
```

### 5.3 Query Service
```bash
# Health Check
curl -sf http://localhost:8085/api/v1/health
# Expected: {"status":"ok"}

# Ready Check
curl -sf http://localhost:8085/api/v1/ready
# Expected: {"status":"ready"}
```

### 5.4 SigNoz Frontend
```bash
# Health Check
curl -sf http://localhost:8080/health
# Expected: {"status":"ok"}
```

### 5.5 Grafana
```bash
# Health Check
curl -sf http://localhost:3000/api/health
# Expected: {"commit":"...","database":"ok","version":"..."}
```

## 6. STAMP Compliance Mapping

### 6.1 SC-OBS-069: Dual Logging (Terminal + SigNoz)

The observability chain enforces dual logging through:

1. **Terminal Logging**: Direct console output via QuadplexLogger
2. **SigNoz Logging**: OTLP export to SigNoz via OTEL Collector

```
+-------------------+     +------------------+     +----------------+
| Elixir Logger     | --> | QuadplexLogger   | --> | Console Output |
|                   |     |                  |     +----------------+
|                   |     |                  |
|                   |     |                  | --> | OTLP Exporter  | --> | OTEL Collector |
+-------------------+     +------------------+     +----------------+     +----------------+
```

**Compliance Verification**:
```fsharp
let checkDualLoggingCompliance (config: ObsChainConfig) : DualLoggingCompliance =
    let compliant = config.DualLogging.TerminalEnabled && config.DualLogging.SigNozEnabled
    { ConstraintId = "SC-OBS-069"
      TerminalLoggingActive = config.DualLogging.TerminalEnabled
      SigNozLoggingActive = config.DualLogging.SigNozEnabled
      IsCompliant = compliant }
```

### 6.2 SC-OBS-071: 4 OTEL Modules Required

| Module   | Implementation               | Status   |
|----------|------------------------------|----------|
| Traces   | `opentelemetry_exporter`     | Active   |
| Metrics  | `telemetry_metrics_prometheus`| Active   |
| Logs     | `opentelemetry_log`          | Active   |
| Baggage  | `opentelemetry_ctx`          | Active   |

**Compliance Verification**:
```fsharp
let checkOtelModulesCompliance (config: ObsChainConfig) : OtelModulesCompliance =
    let activeCount =
        [config.OtelModules.TracesEnabled; config.OtelModules.MetricsEnabled;
         config.OtelModules.LogsEnabled; config.OtelModules.BaggageEnabled]
        |> List.filter id |> List.length
    { ConstraintId = "SC-OBS-071"
      TotalActive = activeCount
      RequiredCount = 4
      IsCompliant = activeCount >= 4 }
```

### 6.3 Other STAMP Constraints

| Constraint  | Description                  | Verification                        |
|-------------|------------------------------|-------------------------------------|
| SC-CNT-009  | NixOS containers only        | Image contains "nixos"              |
| SC-CNT-010  | localhost/ registry only     | Image starts with "localhost/"      |
| SC-CNT-012  | Rootless execution           | Podman rootless mode                |
| SC-AGT-018  | No dependency cycles         | DAG cycle detection                 |
| SC-PRF-050  | Query latency < 50ms         | QueryService constraint check       |

## 7. Integration with Elixir Telemetry

### 7.1 OpenTelemetry Configuration

Add to `config/runtime.exs`:

```elixir
# OpenTelemetry configuration
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: {:otlp, protocol: :grpc, endpoint: "http://localhost:4317"},
  resource: [
    service: [name: "indrajaal", namespace: "indrajaal-ns"]
  ]

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"

config :opentelemetry, :processors,
  batch: [
    scheduled_delay_ms: 5000,
    max_queue_size: 512
  ]
```

### 7.2 Telemetry Metrics Integration

```elixir
# Metrics export via Prometheus
config :telemetry_metrics_prometheus,
  port: 9568,
  metrics: [
    # Phoenix metrics
    summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
    counter("phoenix.router.dispatch.stop.duration"),

    # Ecto metrics
    summary("indrajaal.repo.query.total_time", unit: {:native, :millisecond}),
    counter("indrajaal.repo.query.count"),

    # Custom business metrics
    counter("indrajaal.agent.task.completed"),
    summary("indrajaal.agent.task.duration")
  ]
```

### 7.3 QuadplexLogger Integration

```elixir
# QuadplexLogger channels for SC-OBS-069
config :indrajaal, Indrajaal.Observability.QuadplexLogger,
  channels: [
    # Channel 1: Console (Terminal)
    {Indrajaal.Observability.ConsoleChannel, level: :info},
    # Channel 2: File
    {Indrajaal.Observability.FileChannel, path: "logs/indrajaal.log"},
    # Channel 3: OTEL/SigNoz
    {Indrajaal.Observability.TelemetryChannel, endpoint: "http://localhost:4317"},
    # Channel 4: State Tracker
    {Indrajaal.Observability.StateTrackerChannel, buffer_size: 1000}
  ]
```

## 8. Boot Sequence

### 8.1 Layer-by-Layer Boot Order

```
TIME     LAYER    CONTAINER           STATUS
----     -----    ---------           ------
0ms      L0       obs-clickhouse      Starting
60000ms  L0       obs-clickhouse      Healthy
60000ms  L1       obs-otel-collector  Starting
90000ms  L1       obs-otel-collector  Healthy
90000ms  L2       obs-query-service   Starting
135000ms L2       obs-query-service   Healthy
135000ms L3       obs-frontend        Starting
135000ms L3       obs-grafana         Starting
165000ms L3       obs-frontend        Healthy
180000ms L3       obs-grafana         Healthy
```

### 8.2 Boot Threshold

- **Full Chain**: 180 seconds (3 minutes)
- **Minimal Chain**: 135 seconds (2.25 minutes)
- **Storage Only**: 60 seconds (1 minute)

### 8.3 Degraded Modes

| Mode                  | Missing Component    | Impact                      |
|-----------------------|----------------------|-----------------------------|
| DegradedNoFrontend    | SigNoz Frontend      | No SigNoz UI, Grafana works |
| DegradedNoGrafana     | Grafana              | No Grafana, SigNoz works    |
| CoreOnly              | Both visualizers     | API-only access             |

## 9. Network Configuration

### 9.1 IP Assignment

| Container          | IP Address    |
|--------------------|---------------|
| obs-clickhouse     | 172.31.0.10   |
| obs-otel-collector | 172.31.0.20   |
| obs-query-service  | 172.31.0.30   |
| obs-frontend       | 172.31.0.40   |
| obs-grafana        | 172.31.0.50   |

### 9.2 Network Subnet

- **Network Name**: `indrajaal-obs-net`
- **Subnet**: `172.31.0.0/24`
- **Gateway**: `172.31.0.1`

## 10. Troubleshooting

### 10.1 Common Issues

| Issue                     | Symptom                          | Solution                           |
|---------------------------|----------------------------------|------------------------------------|
| ClickHouse not starting   | Port 8123 not responding         | Check disk space (>2GB required)   |
| OTEL export failures      | "connection refused" in logs     | Verify ClickHouse is healthy       |
| Query service slow        | Queries > 50ms                   | Check ClickHouse query performance |
| Grafana datasource error  | "Bad gateway" in dashboard       | Verify ClickHouse connection       |

### 10.2 Log Analysis Patterns

**OTEL Collector Errors**:
```
"failed to export"     -> Check ClickHouse connectivity
"connection refused"   -> Dependency not ready
"exporter error"       -> Configuration issue
"pipeline failed"      -> Processing error
```

**ClickHouse Errors**:
```
"DB::Exception"        -> Query syntax error
"Code: 60"             -> Table not found
"Code: 81"             -> Database not found
"Too many parts"       -> Merge backlog
"Memory limit"         -> Resource exhaustion
```

## 11. References

- [SigNoz Documentation](https://signoz.io/docs/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [ClickHouse Documentation](https://clickhouse.com/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- CEPAF STAMP-TDG-AOR Specification
- CEPAF Quadplex Logger Architecture
