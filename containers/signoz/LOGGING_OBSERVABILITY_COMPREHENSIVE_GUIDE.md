# SigNoz Logging and Observability - Comprehensive Guide

**Document Version**: 1.0.0
**Last Updated**: 2025-11-23 14:30:00 CEST
**System Status**: ✅ Production Ready
**Compliance**: SOPv5.11 Cybernetic Framework

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Telemetry Data Types](#telemetry-data-types)
4. [Data Flow](#data-flow)
5. [Configuration](#configuration)
6. [Instrumentation Guide](#instrumentation-guide)
7. [Query and Analysis](#query-and-analysis)
8. [Dashboards and Visualization](#dashboards-and-visualization)
9. [Alerting](#alerting)
10. [Performance and Optimization](#performance-and-optimization)
11. [Security and Compliance](#security-and-compliance)
12. [Troubleshooting](#troubleshooting)
13. [SOPv5.11 Integration](#sopv511-integration)
14. [References](#references)

---

## Overview

### What is SigNoz?

SigNoz is a full-stack open-source observability platform that provides:
- **Distributed Tracing**: Track requests across microservices
- **Metrics Monitoring**: Time-series metrics collection and analysis
- **Log Management**: Centralized log aggregation and search
- **Service Maps**: Visualize service dependencies
- **Alerts**: Proactive monitoring and notifications

### Current Deployment

Our SigNoz deployment consists of 4 containerized components:

| Component | Purpose | Status | Ports |
|-----------|---------|--------|-------|
| **ClickHouse** | OLAP database for telemetry storage | ✅ Healthy | 9000 (native), 8123 (HTTP) |
| **OTEL Collector** | Telemetry data ingestion and processing | ✅ Running | 4317 (gRPC), 4318 (HTTP), 8888, 13133 |
| **Query Service** | API layer for data retrieval | ✅ Running | 8081 |
| **Frontend** | Web UI for visualization | ✅ Healthy | 3301 |

### Key Features

#### ✅ Implemented
- OpenTelemetry Protocol (OTLP) ingestion (HTTP and gRPC)
- ClickHouse database with optimized schema
- Real-time trace ingestion and storage
- Web UI for visualization
- Container health monitoring
- Automated deployment scripts

#### 🚧 In Progress
- Custom dashboards
- Alert rules configuration
- Log aggregation pipeline
- Metrics collection from applications

#### 📋 Planned
- Service performance analytics
- Custom retention policies
- Advanced filtering and search
- Integration with external systems

---

## Architecture

### Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        SigNoz Architecture                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐                                                │
│  │ Applications │ (Your services generating telemetry)          │
│  └──────┬───────┘                                                │
│         │                                                         │
│         │ OTLP (HTTP:4318 or gRPC:4317)                         │
│         ▼                                                         │
│  ┌──────────────────┐                                            │
│  │ OTEL Collector   │ (Receive, process, export)                │
│  │ - Receivers      │                                            │
│  │ - Processors     │                                            │
│  │ - Exporters      │                                            │
│  └──────┬───────────┘                                            │
│         │                                                         │
│         │ Native ClickHouse Protocol (:9000)                     │
│         ▼                                                         │
│  ┌──────────────────┐                                            │
│  │   ClickHouse     │ (Columnar database)                       │
│  │ - signoz_traces  │                                            │
│  │ - signoz_metrics │                                            │
│  │ - signoz_logs    │                                            │
│  └──────┬───────────┘                                            │
│         │                                                         │
│         │ SQL Queries                                            │
│         ▼                                                         │
│  ┌──────────────────┐        ┌──────────────┐                   │
│  │  Query Service   │───────▶│   Frontend   │                   │
│  │  (API Layer)     │        │   (Web UI)   │                   │
│  │  :8081           │        │   :3301      │                   │
│  └──────────────────┘        └──────────────┘                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Network Architecture

All components communicate via the `signoz-network` bridge network:

- **Container-to-Container**: Internal DNS resolution (e.g., `clickhouse:9000`)
- **Host Access**: Port mapping for external access
- **Isolation**: No direct external connectivity except exposed ports

### Data Storage

#### ClickHouse Tables

**1. signoz_traces**
- Stores distributed trace data
- Optimized with ZSTD compression
- 7-day TTL (configurable)
- Partitioned by date

**2. signoz_metrics**
- Time-series metrics data
- DoubleDelta compression for timestamps
- Aggregation-friendly structure
- Configurable retention

**3. signoz_logs**
- Centralized log storage
- Full-text search capabilities
- Trace correlation via traceID
- Structured and unstructured logs

---

## Telemetry Data Types

### 1. Distributed Traces

**What are traces?**
- Represent a single request through your system
- Composed of spans (units of work)
- Track timing, errors, and context

**Trace Structure:**
```json
{
  "traceID": "14e49e03c21941f1926b64bdb2ba3704",
  "spans": [
    {
      "spanID": "f09b2b0ef3724522",
      "parentSpanID": "",
      "serviceName": "demo-service",
      "name": "test-operation",
      "kind": "SERVER",
      "startTimeUnixNano": "1700000000000000000",
      "endTimeUnixNano": "1700000100000000",
      "attributes": {
        "http.method": "GET",
        "http.url": "/api/users",
        "http.status_code": 200
      }
    }
  ]
}
```

**Use Cases:**
- Root cause analysis for errors
- Performance bottleneck identification
- Request flow visualization
- Latency analysis

### 2. Metrics

**What are metrics?**
- Numerical measurements over time
- Aggregated for performance
- Used for trending and alerting

**Metric Types:**
- **Counter**: Cumulative values (e.g., request count)
- **Gauge**: Point-in-time values (e.g., CPU usage)
- **Histogram**: Distribution of values (e.g., latency buckets)

**Example Metrics:**
```
http_requests_total{service="api", status="200"} 1523
http_request_duration_seconds{service="api", quantile="0.99"} 0.156
system_cpu_usage{host="server1"} 0.75
```

### 3. Logs

**What are logs?**
- Textual records of events
- Timestamped and structured
- Correlated with traces

**Log Structure:**
```json
{
  "timestamp": "2025-11-23T14:30:00Z",
  "severityText": "ERROR",
  "severityNumber": 17,
  "body": "Database connection failed",
  "traceID": "14e49e03c21941f1926b64bdb2ba3704",
  "spanID": "f09b2b0ef3724522",
  "resourceAttributes": {
    "service.name": "api-service",
    "host.name": "server1"
  },
  "logAttributes": {
    "error.type": "ConnectionError",
    "db.host": "db.example.com"
  }
}
```

---

## Data Flow

### Trace Data Flow

```
Application
    │
    │ 1. Generate span data (SDK)
    │
    ▼
OTLP Exporter (HTTP/gRPC)
    │
    │ 2. Send to OTEL Collector (port 4318 or 4317)
    │
    ▼
OTEL Collector
    │
    │ 3. Receive (OTLP receiver)
    │ 4. Process (batch, attributes)
    │ 5. Export (ClickHouse exporter)
    │
    ▼
ClickHouse
    │
    │ 6. Store in signoz_traces table
    │
    ▼
Query Service
    │
    │ 7. Query via SQL
    │ 8. Transform and aggregate
    │
    ▼
Frontend UI
    │
    │ 9. Visualize in dashboard
    │
    ▼
User
```

### Current Configuration

**OTLP HTTP Endpoint**: `http://localhost:4318/v1/traces`
- Method: POST
- Content-Type: application/json
- Protocol: OTLP/HTTP 1.0

**OTLP gRPC Endpoint**: `grpc://localhost:4317`
- Protocol: OTLP/gRPC

**Test Command:**
```bash
./send_test_trace.sh my-service
```

---

## Configuration

### OTEL Collector Configuration

The OTEL Collector configuration defines:
- **Receivers**: How to accept telemetry data
- **Processors**: How to transform data
- **Exporters**: Where to send processed data

**Current Configuration**: Default SigNoz configuration

**Key Settings:**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

exporters:
  clickhouse:
    endpoint: tcp://clickhouse:9000
    database: signoz
    ttl: 168h  # 7 days

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
```

### ClickHouse Schema

**Traces Table Structure:**
```sql
CREATE TABLE signoz.signoz_traces (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    traceID String CODEC(ZSTD(1)),
    spanID String CODEC(ZSTD(1)),
    parentSpanID String CODEC(ZSTD(1)),
    serviceName LowCardinality(String) CODEC(ZSTD(1)),
    name LowCardinality(String) CODEC(ZSTD(1)),
    kind Int8 CODEC(T64, ZSTD(1)),
    durationNano UInt64 CODEC(T64, ZSTD(1)),
    statusCode Int16 CODEC(T64, ZSTD(1)),
    component LowCardinality(String) CODEC(ZSTD(1)),
    httpMethod LowCardinality(String) CODEC(ZSTD(1)),
    httpUrl String CODEC(ZSTD(1)),
    httpStatusCode Int16 CODEC(T64, ZSTD(1)),
    resourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    spanAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    events Nested(...) CODEC(ZSTD(1)),
    links Nested(...) CODEC(ZSTD(1))
) ENGINE = MergeTree()
PARTITION BY toDate(timestamp)
ORDER BY (serviceName, timestamp, traceID)
TTL toDateTime(timestamp) + INTERVAL 7 DAY
SETTINGS index_granularity = 8192;
```

**Optimization Features:**
- **ZSTD Compression**: High compression ratio
- **DoubleDelta Codec**: Optimized for timestamps
- **LowCardinality**: Efficient storage for repeated strings
- **Date Partitioning**: Fast queries by time range
- **7-Day TTL**: Automatic data cleanup

---

## Instrumentation Guide

### OpenTelemetry SDK Integration

#### Elixir/Phoenix Application

**1. Add Dependencies:**
```elixir
# mix.exs
defp deps do
  [
    {:opentelemetry, "~> 1.3"},
    {:opentelemetry_api, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.6"},
    {:opentelemetry_phoenix, "~> 1.1"},
    {:opentelemetry_ecto, "~> 1.1"}
  ]
end
```

**2. Configure Exporter:**
```elixir
# config/runtime.exs
config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {
      :opentelemetry_exporter,
      %{
        endpoints: ["http://localhost:4318/v1/traces"],
        protocol: :http_protobuf
      }
    }
  }
```

**3. Setup Instrumentation:**
```elixir
# application.ex
def start(_type, _args) do
  :opentelemetry_phoenix.setup()
  :opentelemetry_ecto.setup([:indrajaal, :repo])

  # ... rest of supervisor tree
end
```

#### Manual Span Creation

```elixir
require OpenTelemetry.Tracer

def process_order(order_id) do
  OpenTelemetry.Tracer.with_span "process_order" do
    # Add attributes
    OpenTelemetry.Tracer.set_attributes(%{
      "order.id" => order_id,
      "order.status" => "processing"
    })

    # Your business logic
    result = do_process_order(order_id)

    # Add events
    OpenTelemetry.Tracer.add_event("Order validated", %{
      "validator" => "payment_service"
    })

    result
  end
end
```

### Custom Attributes

**Best Practices:**
- Use semantic conventions (e.g., `http.method`, `db.system`)
- Add business context (e.g., `user.id`, `order.id`)
- Include error details (e.g., `error.type`, `error.message`)
- Keep attribute values simple (strings, numbers, booleans)

---

## Query and Analysis

### ClickHouse SQL Queries

#### Basic Trace Queries

**Get recent traces:**
```sql
SELECT
    timestamp,
    traceID,
    serviceName,
    name,
    durationNano / 1000000 as durationMs,
    statusCode
FROM signoz.signoz_traces
WHERE timestamp > now() - INTERVAL 1 HOUR
ORDER BY timestamp DESC
LIMIT 100;
```

**Find traces by service:**
```sql
SELECT
    traceID,
    name,
    durationNano / 1000000 as durationMs
FROM signoz.signoz_traces
WHERE serviceName = 'demo-service'
    AND timestamp > now() - INTERVAL 1 HOUR
ORDER BY timestamp DESC;
```

**Find slow traces:**
```sql
SELECT
    traceID,
    serviceName,
    name,
    durationNano / 1000000 as durationMs,
    httpUrl
FROM signoz.signoz_traces
WHERE durationNano > 1000000000  -- 1 second
    AND timestamp > now() - INTERVAL 1 HOUR
ORDER BY durationNano DESC
LIMIT 20;
```

**Find traces with errors:**
```sql
SELECT
    traceID,
    serviceName,
    name,
    statusCode,
    httpStatusCode
FROM signoz.signoz_traces
WHERE statusCode = 2  -- ERROR status
    AND timestamp > now() - INTERVAL 1 HOUR
ORDER BY timestamp DESC;
```

#### Aggregation Queries

**Request rate by service:**
```sql
SELECT
    serviceName,
    count() as requests,
    avg(durationNano / 1000000) as avg_latency_ms
FROM signoz.signoz_traces
WHERE timestamp > now() - INTERVAL 1 HOUR
GROUP BY serviceName
ORDER BY requests DESC;
```

**P95, P99 latencies:**
```sql
SELECT
    serviceName,
    quantile(0.50)(durationNano / 1000000) as p50_ms,
    quantile(0.95)(durationNano / 1000000) as p95_ms,
    quantile(0.99)(durationNano / 1000000) as p99_ms
FROM signoz.signoz_traces
WHERE timestamp > now() - INTERVAL 1 HOUR
GROUP BY serviceName;
```

**Error rate by endpoint:**
```sql
SELECT
    httpUrl,
    count() as total_requests,
    countIf(statusCode = 2) as errors,
    errors / total_requests * 100 as error_rate_pct
FROM signoz.signoz_traces
WHERE timestamp > now() - INTERVAL 1 HOUR
    AND httpUrl != ''
GROUP BY httpUrl
HAVING total_requests > 10
ORDER BY error_rate_pct DESC;
```

### Query Service API

**Health Check:**
```bash
curl http://localhost:8081/api/v1/health
```

**Query Traces:**
```bash
curl -X POST http://localhost:8081/api/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "start": 1700000000000,
    "end": 1700000900000,
    "limit": 100
  }'
```

---

## Dashboards and Visualization

### Frontend UI

**Access**: http://localhost:3301

**Main Views:**
1. **Services** - Service list with key metrics
2. **Traces** - Trace search and filtering
3. **Service Map** - Visual service dependencies
4. **Dashboards** - Custom metric dashboards

### Creating Custom Dashboards

**Coming Soon**: Dashboard creation guide

---

## Alerting

### Alert Configuration

**Coming Soon**: Alert rules configuration

### Alert Channels

**Supported Channels:**
- Email
- Slack
- PagerDuty
- Webhook

---

## Performance and Optimization

### ClickHouse Performance

**Current Optimization:**
- ✅ ZSTD compression for high compression ratio
- ✅ DoubleDelta codec for timestamps
- ✅ Date-based partitioning
- ✅ Proper ordering keys
- ✅ Index granularity tuned

**Monitoring Queries:**

**Check table sizes:**
```sql
SELECT
    table,
    formatReadableSize(sum(bytes)) as size,
    sum(rows) as rows
FROM system.parts
WHERE database = 'signoz'
GROUP BY table;
```

**Query performance:**
```sql
SELECT
    query,
    event_time,
    query_duration_ms,
    read_rows,
    read_bytes
FROM system.query_log
WHERE type = 'QueryFinish'
ORDER BY event_time DESC
LIMIT 10;
```

### OTEL Collector Performance

**Batch Processing:**
- Default: 10s timeout or 1024 spans
- Reduces network overhead
- Balances latency vs. throughput

**Resource Limits:**
- CPU: 0.5-1.0 cores
- Memory: 512MB-1GB

---

## Security and Compliance

### Network Security

**Current Setup:**
- ✅ All containers on private bridge network
- ✅ Only necessary ports exposed to host
- ✅ No external registry dependencies
- ✅ Rootless Podman execution

### Data Security

**Considerations:**
- Telemetry may contain sensitive data
- Use attribute processors to redact PII
- Implement access controls on Frontend UI
- Encrypt data at rest (ClickHouse encryption)

### Compliance

**Container Policy:**
- ✅ All images from localhost/ registry
- ✅ Version pinning prevents drift
- ✅ Complete audit trail maintained

---

## Troubleshooting

### Common Issues

**1. No data appearing in UI**

Check:
```bash
# Verify OTEL Collector is receiving data
curl http://localhost:8888/metrics | grep otelcol_receiver

# Check ClickHouse has data
podman exec signoz-clickhouse clickhouse-client \
  --query "SELECT count() FROM signoz.signoz_traces"

# Review OTEL Collector logs
podman logs signoz-otel-collector | tail -50
```

**2. High memory usage**

```bash
# Check container stats
podman stats signoz-clickhouse signoz-otel-collector

# ClickHouse memory usage
podman exec signoz-clickhouse clickhouse-client \
  --query "SELECT formatReadableSize(sum(bytes)) FROM system.parts WHERE database = 'signoz'"
```

**3. Slow queries**

```bash
# Check slow queries in ClickHouse
podman exec signoz-clickhouse clickhouse-client \
  --query "SELECT query, query_duration_ms FROM system.query_log WHERE query_duration_ms > 1000 ORDER BY event_time DESC LIMIT 10"
```

### Diagnostic Commands

**Complete System Status:**
```bash
./status.sh
```

**Verify Deployment:**
```bash
./verify-deployment.sh
```

**Test Trace Ingestion:**
```bash
./send_test_trace.sh test-service
```

**Monitor All Logs:**
```bash
./monitor-all.sh
```

---

## SOPv5.11 Integration

### Cybernetic Framework Compliance

**Agent Coordination:**
- 15-agent architecture monitoring
- Real-time telemetry from agents
- Performance tracking per agent layer

**STAMP Safety Constraints:**
- SC-OBS-001: System SHALL maintain observability for all critical operations
- SC-OBS-002: System SHALL detect and alert on anomalies within 1 minute
- SC-OBS-003: System SHALL retain telemetry data for minimum 7 days
- SC-OBS-004: System SHALL provide complete audit trail for all operations

**TPS Integration:**
- Jidoka: Stop-and-fix on critical errors
- 5-Level RCA: Root cause analysis via trace correlation
- Continuous Improvement: Performance trending

### Instrumentation Requirements

**Mandatory for all SOPv5.11 operations:**
```elixir
# Add trace context to all operations
OpenTelemetry.Tracer.with_span "sopv511_operation" do
  OpenTelemetry.Tracer.set_attributes(%{
    "sopv511.phase" => "phase_2",
    "sopv511.agent.type" => "domain_supervisor",
    "sopv511.agent.id" => "domain-02",
    "sopv511.operation" => "container_deployment"
  })

  # Operation code
end
```

---

## References

### Internal Documentation
- [README.md](README.md) - System overview
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Complete operational guide
- [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) - Script documentation
- [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) - Current deployment state
- [DOCUMENTATION_UPDATE_SUMMARY.md](DOCUMENTATION_UPDATE_SUMMARY.md) - Task completion record

### External Resources
- [SigNoz Official Documentation](https://signoz.io/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [ClickHouse Documentation](https://clickhouse.com/docs/)
- [OTLP Specification](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/otlp.md)

### Support
- **Container Issues**: Review troubleshooting section
- **Query Performance**: Check ClickHouse optimization guide
- **Integration Help**: See instrumentation guide
- **Policy Compliance**: Review SOPv5.11 section

---

**Document Maintained By**: Indrajaal Development Team
**Last Review**: 2025-11-23
**Next Review**: 2025-12-23
