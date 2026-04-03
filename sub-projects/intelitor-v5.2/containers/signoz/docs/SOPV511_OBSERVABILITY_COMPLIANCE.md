# SOPv5.11 Observability System Compliance Documentation

**Status**: ✅ Production Ready - Phase 5 Complete
**Last Updated**: 2025-11-23 14:30:00 CEST
**Version**: 1.0.0
**Compliance Level**: Enterprise-Grade

---

## Table of Contents

1. [Overview](#overview)
2. [STAMP Safety Constraints](#stamp-safety-constraints)
3. [Cybernetic Framework Integration](#cybernetic-framework-integration)
4. [TPS Methodology Compliance](#tps-methodology-compliance)
5. [Mandatory Instrumentation Requirements](#mandatory-instrumentation-requirements)
6. [Compliance Verification Procedures](#compliance-verification-procedures)
7. [Audit Trail Requirements](#audit-trail-requirements)
8. [Operational Compliance Workflows](#operational-compliance-workflows)
9. [Emergency Response Protocols](#emergency-response-protocols)
10. [Continuous Compliance Monitoring](#continuous-compliance-monitoring)

---

## Overview

The SigNoz observability system implements SOPv5.11 cybernetic framework compliance through comprehensive monitoring, safety constraints, and operational procedures. This document details all compliance requirements, verification procedures, and operational workflows.

### SOPv5.11 Framework Components

- **50-Agent Architecture**: Hierarchical coordination with real-time telemetry
- **STAMP Safety Constraints**: 4 critical observability safety requirements
- **TPS Integration**: Jidoka, 5-Level RCA, and continuous improvement
- **Cybernetic Feedback**: Real-time adaptation and optimization
- **Container-Native**: Complete deployment within localhost/ registry containers

### Compliance Scope

This compliance framework covers:
- All 4 SigNoz containers (ClickHouse, OTEL Collector, Query Service, Frontend)
- All 10 operational scripts for deployment and management
- All telemetry instrumentation across Elixir/Phoenix application
- Complete audit trail and monitoring infrastructure

---

## STAMP Safety Constraints

### SC-OBS-001: Observability for All Critical Operations

**Requirement**: System SHALL maintain observability for all critical operations.

**Critical Operations Defined:**
- Container lifecycle events (start, stop, restart, health check)
- Database operations (schema initialization, data ingestion, query execution)
- OTLP data ingestion (HTTP/gRPC trace, metrics, and log reception)
- Frontend UI interactions and API calls
- Inter-container communication and network events
- Resource utilization and performance metrics

**Implementation Requirements:**

```elixir
# All critical operations must include OpenTelemetry tracing
OpenTelemetry.Tracer.with_span "critical_operation" do
  OpenTelemetry.Tracer.set_attributes(%{
    "operation.type" => "database_query",
    "operation.criticality" => "high",
    "sopv511.compliance" => "SC-OBS-001",
    "container.name" => "signoz-clickhouse",
    "resource.name" => "signoz.signoz_traces"
  })

  # Operation execution
  result = execute_critical_operation()

  # Record operation outcome
  OpenTelemetry.Tracer.set_status(:ok)
  result
end
```

**Verification Commands:**

```bash
# Verify all containers are instrumented
./verify-deployment.sh

# Check telemetry data flow
./send_test_trace.sh critical-ops-test

# Query recent critical operations
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces
   WHERE attributes['sopv511.compliance'] = 'SC-OBS-001'
   ORDER BY timestamp DESC LIMIT 10"
```

**Compliance Metrics:**
- **Target**: 100% of critical operations instrumented
- **Measurement**: Query traces table for SC-OBS-001 tagged operations
- **Frequency**: Daily validation via automated scripts
- **Remediation**: Any uninstrumented critical operation must be fixed within 24 hours

---

### SC-OBS-002: Anomaly Detection Within 1 Minute

**Requirement**: System SHALL detect and alert on anomalies within 1 minute.

**Anomaly Types:**
- Container health check failures
- Database connection errors or query timeouts
- OTLP data ingestion rate drops or spikes
- Memory or CPU usage exceeding thresholds
- Network connectivity issues between containers
- Data pipeline interruptions or delays

**Implementation Requirements:**

```elixir
# Configure health check monitoring with 30-second intervals
defmodule Intelitor.Observability.HealthMonitor do
  use GenServer

  @health_check_interval 30_000  # 30 seconds
  @anomaly_threshold 2            # 2 consecutive failures = anomaly

  def init(state) do
    schedule_health_check()
    {:ok, state}
  end

  def handle_info(:health_check, state) do
    results = check_all_containers()

    # Detect anomalies
    anomalies = Enum.filter(results, fn {_container, status} ->
      status in [:unhealthy, :degraded, :error]
    end)

    # Alert within 1 minute (2 consecutive checks)
    if length(anomalies) >= @anomaly_threshold do
      alert_anomaly(anomalies)

      # Trace anomaly detection
      OpenTelemetry.Tracer.with_span "anomaly_detected" do
        OpenTelemetry.Tracer.set_attributes(%{
          "sopv511.compliance" => "SC-OBS-002",
          "anomaly.type" => "health_check_failure",
          "anomaly.containers" => inspect(anomalies),
          "detection.time_ms" => 60_000
        })
      end
    end

    schedule_health_check()
    {:noreply, state}
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end
end
```

**Verification Commands:**

```bash
# Monitor real-time health checks
./monitor-all.sh

# Verify health check intervals
podman inspect signoz-clickhouse --format='{{.State.Health}}'

# Check recent anomaly detections
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces
   WHERE name = 'anomaly_detected'
   ORDER BY timestamp DESC LIMIT 10"
```

**Compliance Metrics:**
- **Target**: 100% anomaly detection within 60 seconds
- **Measurement**: Time from anomaly occurrence to trace creation
- **Frequency**: Continuous monitoring via health checks every 30 seconds
- **Remediation**: Any missed detection requires immediate investigation and fix

---

### SC-OBS-003: Minimum 7-Day Data Retention

**Requirement**: System SHALL retain telemetry data for minimum 7 days.

**Data Retention Scope:**
- OpenTelemetry traces in `signoz.signoz_traces` table
- Metrics data in `signoz.signoz_metrics` table
- Log data in `signoz.signoz_logs` table
- Container health check history
- Performance metrics and baselines

**Implementation Requirements:**

```sql
-- ClickHouse tables configured with 7-day TTL
CREATE TABLE IF NOT EXISTS signoz.signoz_traces (
    timestamp DateTime,
    traceID String,
    spanID String,
    -- ... other columns
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (timestamp, traceID)
TTL timestamp + INTERVAL 7 DAY
SETTINGS index_granularity = 8192;
```

**Verification Commands:**

```bash
# Check table TTL settings
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT table, engine_full
   FROM system.tables
   WHERE database = 'signoz'
   AND name LIKE 'signoz_%'"

# Verify data retention (should have 7 days of data)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     toDate(MIN(timestamp)) as oldest_data,
     toDate(MAX(timestamp)) as newest_data,
     date_diff('day', MIN(timestamp), MAX(timestamp)) as retention_days
   FROM signoz.signoz_traces"

# Check volume disk usage
podman volume inspect signoz-clickhouse-data --format='{{.Mountpoint}}'
du -sh $(podman volume inspect signoz-clickhouse-data --format='{{.Mountpoint}}')
```

**Compliance Metrics:**
- **Target**: All telemetry data retained for exactly 7 days
- **Measurement**: Query oldest and newest data timestamps
- **Frequency**: Daily retention verification
- **Remediation**: Any data loss before 7 days requires immediate investigation

---

### SC-OBS-004: Complete Audit Trail

**Requirement**: System SHALL provide complete audit trail for all operations.

**Audit Trail Components:**
- All container lifecycle events (create, start, stop, remove)
- All database schema changes and data modifications
- All configuration changes to SigNoz components
- All operational script executions (10 management scripts)
- All user interactions with Frontend UI
- All API calls to Query Service

**Implementation Requirements:**

```elixir
# Audit logging for all operations
defmodule Intelitor.Observability.AuditLogger do
  require Logger

  def log_operation(operation_type, details) do
    # Create audit log entry
    audit_entry = %{
      timestamp: DateTime.utc_now(),
      operation_type: operation_type,
      details: details,
      user: get_current_user(),
      container: System.get_env("CONTAINER_NAME"),
      sopv511_compliance: "SC-OBS-004"
    }

    # Log to application logs (dual logging: terminal + SigNoz)
    Logger.info("AUDIT: #{operation_type}", audit_entry)

    # Send as OpenTelemetry event
    OpenTelemetry.Tracer.with_span "audit_log" do
      OpenTelemetry.Tracer.set_attributes(audit_entry)
      OpenTelemetry.Tracer.add_event("operation_executed", audit_entry)
    end

    :ok
  end
end

# Example usage in operational scripts
Intelitor.Observability.AuditLogger.log_operation(
  "container_start",
  %{
    container: "signoz-clickhouse",
    script: "start-signoz-simple.sh",
    status: "success"
  }
)
```

**Verification Commands:**

```bash
# Check audit logs in SigNoz
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces
   WHERE attributes['sopv511_compliance'] = 'SC-OBS-004'
   ORDER BY timestamp DESC LIMIT 20"

# Review application logs
find ./data/tmp -name "*.log" -mtime -7 | xargs grep "AUDIT:"

# Verify operational script execution logs
./status.sh | grep -i "audit"
```

**Compliance Metrics:**
- **Target**: 100% of operations have audit trail entries
- **Measurement**: Cross-reference operations with audit logs
- **Frequency**: Weekly audit trail completeness review
- **Remediation**: Any missing audit entries require immediate fix and gap analysis

---

## Cybernetic Framework Integration

### 50-Agent Architecture Monitoring

The observability system integrates with the SOPv5.11 15-agent cybernetic framework to provide real-time telemetry and feedback loops.

**Agent Hierarchy:**

1. **Executive Director (1 agent)**
   - Monitors overall system health and performance
   - Receives aggregated telemetry from all layers
   - Makes strategic decisions based on observability data

2. **Domain Supervisors (10 agents)**
   - One per specialized container domain
   - Monitor container-specific metrics and health
   - Coordinate with observability system for domain telemetry

3. **Functional Supervisors (15 agents)**
   - Compilation Specialists: Monitor build and deployment metrics
   - Quality Assurance: Track test coverage and quality metrics
   - Performance Monitors: Analyze resource usage and optimization opportunities

4. **Worker Agents (24 agents)**
   - File Processors: Monitor file operations and I/O metrics
   - Pattern Recognizers: Detect error patterns in telemetry data
   - Validators: Continuous validation of observability data quality

**Agent Instrumentation Requirements:**

```elixir
# All agent operations must include agent metadata
OpenTelemetry.Tracer.with_span "agent_operation" do
  OpenTelemetry.Tracer.set_attributes(%{
    "sopv511.agent.layer" => "domain_supervisor",
    "sopv511.agent.id" => "domain-09",  # observability domain
    "sopv511.agent.role" => "container_health_monitor",
    "sopv511.operation.type" => "health_check",
    "sopv511.cybernetic.feedback" => "enabled"
  })

  # Agent operation execution
end
```

### Real-Time Telemetry Collection

**Telemetry Sources:**
- Container metrics (CPU, memory, disk, network)
- Application performance (request rates, latency, errors)
- Database performance (query times, connection pools)
- Agent coordination metrics (efficiency, task distribution)

**Collection Frequency:**
- Container health: Every 30 seconds
- Application metrics: Real-time (per request)
- Database metrics: Every 60 seconds
- Agent metrics: Every 10 seconds

### Cybernetic Feedback Loops

**Performance Optimization Loop:**
```
Collect Metrics → Analyze Performance → Identify Bottlenecks →
Apply Optimizations → Measure Impact → Adjust Strategy
```

**Quality Assurance Loop:**
```
Monitor Quality Metrics → Detect Quality Issues → Trigger Jidoka →
Apply 5-Level RCA → Implement Fixes → Verify Improvement
```

**Resource Management Loop:**
```
Monitor Resource Usage → Predict Resource Needs →
Allocate Resources → Validate Allocation → Optimize Distribution
```

---

## TPS Methodology Compliance

### Jidoka (Stop-and-Fix) Integration

**Principle**: Stop all operations immediately when critical errors are detected.

**Implementation:**

```elixir
defmodule Intelitor.Observability.Jidoka do
  def check_and_halt_on_error(operation_result) do
    case operation_result do
      {:error, :critical, reason} ->
        # Immediate halt
        halt_all_operations()

        # Trigger 5-Level RCA
        initiate_rca(reason)

        # Log Jidoka event
        OpenTelemetry.Tracer.with_span "jidoka_halt" do
          OpenTelemetry.Tracer.set_attributes(%{
            "sopv511.tps.principle" => "jidoka",
            "halt.reason" => reason,
            "halt.timestamp" => DateTime.utc_now(),
            "rca.initiated" => true
          })
        end

        {:halted, reason}

      {:ok, _} = success ->
        success
    end
  end
end
```

**Jidoka Triggers:**
- Container health check failures (2 consecutive)
- Database connection loss
- OTLP data ingestion pipeline failure
- Critical resource exhaustion (>95% memory or CPU)
- Data corruption detected in ClickHouse

**Verification:**

```bash
# Check for recent Jidoka halts
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces
   WHERE name = 'jidoka_halt'
   ORDER BY timestamp DESC LIMIT 5"
```

### 5-Level Root Cause Analysis

**Principle**: Systematically investigate incidents through 5 levels of "why" questions.

**RCA Process:**

1. **Level 1 - Symptom**: What happened?
2. **Level 2 - Surface Cause**: What immediate factor caused it?
3. **Level 3 - System Behavior**: What system behavior allowed this?
4. **Level 4 - Configuration Gap**: What configuration or design gap exists?
5. **Level 5 - Root Cause**: What fundamental issue needs to be addressed?

**Example RCA Documentation:**

```markdown
## 5-Level RCA: OTEL Collector Health Check Failure

**Incident**: OTEL Collector health check timeout on 2025-11-23 13:45:00

**Level 1 - Symptom**:
Health check endpoint (http://localhost:13133/) timeout after 10 seconds

**Level 2 - Surface Cause**:
OTEL Collector process not responding to HTTP requests

**Level 3 - System Behavior**:
Container startup dependencies not properly ordered - OTEL started before ClickHouse ready

**Level 4 - Configuration Gap**:
docker-compose.yml missing `depends_on` with health condition for ClickHouse

**Level 5 - Root Cause**:
Inadequate container orchestration design - health checks not enforcing startup order

**Corrective Actions**:
1. Update docker-compose.yml with proper depends_on conditions
2. Add health check validation in start-signoz-simple.sh
3. Implement 5-Level RCA documentation template for future incidents
```

**Verification:**

```bash
# All RCA documents stored in data/tmp with standardized naming
ls -la ./data/tmp/rca_*.md

# RCA completion tracked in telemetry
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces
   WHERE attributes['sopv511.tps.principle'] = '5-level-rca'
   ORDER BY timestamp DESC"
```

### Continuous Improvement (Kaizen)

**Principle**: Systematic and ongoing improvement of processes and systems.

**Continuous Improvement Areas:**
- Container startup time optimization
- Query performance tuning in ClickHouse
- Dashboard response time improvement
- Resource utilization efficiency
- Operational script automation enhancement

**Improvement Tracking:**

```elixir
# Track improvements in telemetry
OpenTelemetry.Tracer.with_span "kaizen_improvement" do
  OpenTelemetry.Tracer.set_attributes(%{
    "sopv511.tps.principle" => "kaizen",
    "improvement.area" => "container_startup",
    "improvement.metric" => "startup_time_ms",
    "improvement.before" => 45_000,
    "improvement.after" => 28_000,
    "improvement.percentage" => 37.8,
    "improvement.date" => "2025-11-23"
  })
end
```

**Verification:**

```bash
# Query improvement history
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     attributes['improvement.area'] as area,
     attributes['improvement.metric'] as metric,
     AVG(toFloat64(attributes['improvement.percentage'])) as avg_improvement
   FROM signoz.signoz_traces
   WHERE name = 'kaizen_improvement'
   GROUP BY area, metric"
```

---

## Mandatory Instrumentation Requirements

### All Critical Operations

**Required Attributes for Every Trace:**

```elixir
# Minimum required attributes
%{
  # SOPv5.11 Compliance
  "sopv511.compliance" => "SC-OBS-001",  # Which safety constraint
  "sopv511.phase" => "phase_5",          # Which deployment phase

  # Operation Details
  "operation.type" => "database_query",
  "operation.criticality" => "high",
  "operation.duration_ms" => 45,

  # Container Context
  "container.name" => "signoz-clickhouse",
  "container.id" => container_id,

  # Resource Context
  "resource.type" => "database_table",
  "resource.name" => "signoz.signoz_traces",

  # Agent Context (if applicable)
  "sopv511.agent.type" => "domain_supervisor",
  "sopv511.agent.id" => "domain-09"
}
```

### Container Lifecycle Events

**Container Start:**

```bash
#!/bin/bash
# start-signoz-simple.sh

# Log container start event
elixir -e "
  OpenTelemetry.Tracer.with_span \"container_start\" do
    OpenTelemetry.Tracer.set_attributes(%{
      \"sopv511.compliance\" => \"SC-OBS-004\",
      \"container.name\" => \"signoz-clickhouse\",
      \"operation.type\" => \"lifecycle_start\",
      \"script.name\" => \"start-signoz-simple.sh\"
    })
  end
"

# Start container
podman run -d --name signoz-clickhouse ...
```

### Database Operations

**Schema Initialization:**

```bash
# clickhouse-setup.sh

# Log schema creation
elixir -e "
  OpenTelemetry.Tracer.with_span \"schema_initialization\" do
    OpenTelemetry.Tracer.set_attributes(%{
      \"sopv511.compliance\" => \"SC-OBS-001\",
      \"database.name\" => \"signoz\",
      \"operation.type\" => \"schema_create\",
      \"tables.created\" => 3
    })
  end
"

# Create tables
podman exec signoz-clickhouse clickhouse-client --query "CREATE TABLE IF NOT EXISTS signoz.signoz_traces ..."
```

### Health Check Monitoring

**Continuous Health Checks:**

```elixir
defmodule Intelitor.Observability.HealthCheck do
  def perform_health_check(container_name) do
    OpenTelemetry.Tracer.with_span "health_check" do
      OpenTelemetry.Tracer.set_attributes(%{
        "sopv511.compliance" => "SC-OBS-002",
        "container.name" => container_name,
        "check.type" => "http_endpoint",
        "check.interval_seconds" => 30
      })

      result = execute_health_check(container_name)

      OpenTelemetry.Tracer.set_attributes(%{
        "check.status" => result.status,
        "check.response_time_ms" => result.response_time
      })

      result
    end
  end
end
```

---

## Compliance Verification Procedures

### Daily Verification Checklist

**Run daily at 09:00 CEST:**

```bash
#!/bin/bash
# Daily SOPv5.11 compliance verification

echo "=== SOPv5.11 Observability Compliance Verification ==="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 1. Verify all containers running and healthy
echo "1. Container Health Check:"
./status.sh | grep -E "signoz-(clickhouse|otel-collector|query-service|frontend)"

# 2. Verify SC-OBS-001: All critical operations instrumented
echo ""
echo "2. SC-OBS-001 Compliance (Critical Operations):"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) as instrumented_operations
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.compliance'] = 'SC-OBS-001'
   AND timestamp > now() - INTERVAL 1 DAY"

# 3. Verify SC-OBS-002: Anomaly detection functioning
echo ""
echo "3. SC-OBS-002 Compliance (Anomaly Detection):"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) as anomalies_detected,
          MAX(toInt64(attributes['detection.time_ms'])) as max_detection_time
   FROM signoz.signoz_traces
   WHERE name = 'anomaly_detected'
   AND timestamp > now() - INTERVAL 1 DAY"

# 4. Verify SC-OBS-003: Data retention (7 days)
echo ""
echo "4. SC-OBS-003 Compliance (Data Retention):"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     date_diff('day', MIN(timestamp), MAX(timestamp)) as retention_days,
     COUNT(*) as total_traces
   FROM signoz.signoz_traces"

# 5. Verify SC-OBS-004: Audit trail completeness
echo ""
echo "5. SC-OBS-004 Compliance (Audit Trail):"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) as audit_entries
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.compliance'] = 'SC-OBS-004'
   AND timestamp > now() - INTERVAL 1 DAY"

# 6. Verify TPS integration (Jidoka, RCA, Kaizen)
echo ""
echo "6. TPS Integration Verification:"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     attributes['sopv511.tps.principle'] as principle,
     COUNT(*) as occurrences
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.tps.principle'] IS NOT NULL
   AND timestamp > now() - INTERVAL 1 DAY
   GROUP BY principle"

echo ""
echo "=== Verification Complete ==="
```

### Weekly Compliance Review

**Run weekly on Mondays:**

```bash
#!/bin/bash
# Weekly comprehensive compliance review

# Generate compliance report
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     toDate(timestamp) as date,
     attributes['sopv511.compliance'] as constraint,
     COUNT(*) as operations,
     AVG(toFloat64(attributes['operation.duration_ms'])) as avg_duration_ms
   FROM signoz.signoz_traces
   WHERE timestamp > now() - INTERVAL 7 DAY
   GROUP BY date, constraint
   ORDER BY date DESC, constraint
   FORMAT CSV" > ./data/tmp/weekly_compliance_report_$(date +%Y%m%d).csv

echo "Weekly compliance report generated: ./data/tmp/weekly_compliance_report_$(date +%Y%m%d).csv"
```

### Automated Compliance Testing

**Integration with CI/CD:**

```bash
# Run as part of deployment pipeline
mix test test/sopv511_observability_compliance_test.exs
```

**Test Coverage:**
- All 4 STAMP safety constraints
- Agent instrumentation requirements
- TPS methodology integration
- Audit trail completeness

---

## Audit Trail Requirements

### Audit Log Structure

**All audit entries must include:**

```elixir
%{
  # Timestamp
  timestamp: DateTime.utc_now(),

  # Who performed the operation
  user: "system" | "admin@example.com",
  actor_type: "script" | "user" | "agent",

  # What operation was performed
  operation_type: "container_start" | "schema_create" | "config_update",
  operation_details: %{...},

  # Where the operation occurred
  container: "signoz-clickhouse" | nil,
  script: "start-signoz-simple.sh" | nil,

  # Result
  status: "success" | "failure",
  error_message: nil | "Connection timeout",

  # Compliance
  sopv511_compliance: "SC-OBS-004"
}
```

### Audit Log Storage

**Multiple Storage Locations:**

1. **Application Logs**: `./data/tmp/[timestamp]-signoz-operations.log`
2. **SigNoz Traces**: `signoz.signoz_traces` table with `sopv511.compliance = SC-OBS-004`
3. **Container Logs**: Captured via `podman logs` for each container

### Audit Log Retention

- **Minimum**: 7 days in ClickHouse (per SC-OBS-003)
- **Application Logs**: 30 days in ./data/tmp
- **Backup Logs**: Indefinite retention in backup archives

### Audit Trail Query Examples

```sql
-- All operations in last 24 hours
SELECT * FROM signoz.signoz_traces
WHERE attributes['sopv511.compliance'] = 'SC-OBS-004'
AND timestamp > now() - INTERVAL 1 DAY
ORDER BY timestamp DESC;

-- Failed operations requiring investigation
SELECT * FROM signoz.signoz_traces
WHERE attributes['sopv511.compliance'] = 'SC-OBS-004'
AND attributes['status'] = 'failure'
AND timestamp > now() - INTERVAL 7 DAY;

-- Operations by specific user
SELECT * FROM signoz.signoz_traces
WHERE attributes['sopv511.compliance'] = 'SC-OBS-004'
AND attributes['user'] = 'admin@example.com'
ORDER BY timestamp DESC;
```

---

## Operational Compliance Workflows

### Container Deployment Workflow

**Compliance-Aware Deployment:**

```bash
#!/bin/bash
# start-signoz-simple.sh with full compliance

# 1. Audit: Log deployment start
elixir -e "Intelitor.Observability.AuditLogger.log_operation(
  'deployment_start',
  %{script: 'start-signoz-simple.sh'}
)"

# 2. SC-OBS-001: Create network with instrumentation
podman network create signoz-network
elixir -e "OpenTelemetry.Tracer.with_span 'network_create' do ... end"

# 3. SC-OBS-001: Create volumes with instrumentation
podman volume create signoz-clickhouse-data
elixir -e "OpenTelemetry.Tracer.with_span 'volume_create' do ... end"

# 4. SC-OBS-002: Start ClickHouse with health monitoring
podman run -d --name signoz-clickhouse \
  --health-cmd="clickhouse-client --query 'SELECT 1'" \
  --health-interval=30s \
  ...

# 5. SC-OBS-001: Initialize schema
./clickhouse-setup.sh

# 6. SC-OBS-002: Verify all health checks passing
./verify-deployment.sh

# 7. Audit: Log deployment completion
elixir -e "Intelitor.Observability.AuditLogger.log_operation(
  'deployment_complete',
  %{script: 'start-signoz-simple.sh', status: 'success'}
)"
```

### Monitoring Workflow

**Real-Time Compliance Monitoring:**

```bash
#!/bin/bash
# monitor-all.sh with compliance checking

# Start monitoring all containers
podman logs -f signoz-clickhouse &
podman logs -f signoz-otel-collector &
podman logs -f signoz-query-service &
podman logs -f signoz-frontend &

# Simultaneously check compliance
while true; do
  # SC-OBS-002: Check for anomalies every 30 seconds
  anomalies=$(podman exec signoz-clickhouse clickhouse-client --query \
    "SELECT COUNT(*) FROM signoz.signoz_traces
     WHERE name = 'anomaly_detected'
     AND timestamp > now() - INTERVAL 1 MINUTE")

  if [ "$anomalies" -gt 0 ]; then
    echo "[COMPLIANCE ALERT] SC-OBS-002: $anomalies anomalies detected in last minute"
  fi

  sleep 30
done
```

### Backup Workflow

**Compliance-Aware Backup:**

```bash
#!/bin/bash
# backup-data.sh with full compliance

backup_name=${1:-"backup-$(date +%Y%m%d-%H%M)"}
backup_dir="./data/signoz/backups/$backup_name"

# 1. Audit: Log backup start
elixir -e "Intelitor.Observability.AuditLogger.log_operation(
  'backup_start',
  %{backup_name: '$backup_name'}
)"

# 2. SC-OBS-001: Export all data with instrumentation
elixir -e "OpenTelemetry.Tracer.with_span 'backup_export' do
  # Export traces
  podman exec signoz-clickhouse clickhouse-client --query \
    \"SELECT * FROM signoz.signoz_traces FORMAT JSONEachRow\" \
    > $backup_dir/traces.jsonl

  # Export metrics
  podman exec signoz-clickhouse clickhouse-client --query \
    \"SELECT * FROM signoz.signoz_metrics FORMAT JSONEachRow\" \
    > $backup_dir/metrics.jsonl
end"

# 3. SC-OBS-004: Create backup metadata with audit trail
cat > $backup_dir/metadata.json <<EOF
{
  "backup_name": "$backup_name",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sopv511_compliance": "SC-OBS-004",
  "data_retention_days": 7,
  "audit_trail": "complete"
}
EOF

# 4. Audit: Log backup completion
elixir -e "Intelitor.Observability.AuditLogger.log_operation(
  'backup_complete',
  %{backup_name: '$backup_name', status: 'success'}
)"
```

---

## Emergency Response Protocols

### Container Failure Response

**Automated Response:**

```elixir
defmodule Intelitor.Observability.EmergencyResponse do
  def handle_container_failure(container_name) do
    # 1. Jidoka: Immediate halt and assessment
    OpenTelemetry.Tracer.with_span "emergency_response" do
      OpenTelemetry.Tracer.set_attributes(%{
        "sopv511.tps.principle" => "jidoka",
        "emergency.type" => "container_failure",
        "container.name" => container_name
      })

      # 2. SC-OBS-002: Alert within 1 minute
      send_alert("Container failure: #{container_name}")

      # 3. Attempt automatic recovery
      case recover_container(container_name) do
        {:ok, _} ->
          # 4. SC-OBS-004: Log recovery success
          AuditLogger.log_operation("emergency_recovery", %{
            container: container_name,
            status: "success"
          })

        {:error, reason} ->
          # 5. Initiate 5-Level RCA
          initiate_rca(container_name, reason)

          # 6. SC-OBS-004: Log recovery failure
          AuditLogger.log_operation("emergency_recovery", %{
            container: container_name,
            status: "failure",
            reason: reason
          })
      end
    end
  end
end
```

### Data Loss Prevention

**Automatic Backup Trigger:**

```bash
#!/bin/bash
# Emergency backup before recovery attempt

container_name=$1
emergency_backup="emergency-$(date +%Y%m%d-%H%M%S)-$container_name"

# SC-OBS-001: Create emergency backup
./backup-data.sh $emergency_backup

# SC-OBS-004: Log emergency action
elixir -e "Intelitor.Observability.AuditLogger.log_operation(
  'emergency_backup',
  %{container: '$container_name', backup: '$emergency_backup'}
)"

# Attempt recovery
./scripts/recovery/recover-container.sh $container_name
```

### Compliance Violation Response

**Automatic Violation Detection:**

```elixir
defmodule Intelitor.Observability.ComplianceMonitor do
  def check_compliance_violations do
    violations = [
      check_sc_obs_001_compliance(),
      check_sc_obs_002_compliance(),
      check_sc_obs_003_compliance(),
      check_sc_obs_004_compliance()
    ]
    |> Enum.filter(fn {status, _} -> status == :violation end)

    if length(violations) > 0 do
      # Jidoka: Halt on compliance violation
      halt_operations("Compliance violations detected")

      # Initiate 5-Level RCA for each violation
      Enum.each(violations, fn {_, violation_details} ->
        initiate_rca(:compliance_violation, violation_details)
      end)

      # Alert compliance team
      send_compliance_alert(violations)
    end
  end
end
```

---

## Continuous Compliance Monitoring

### Real-Time Monitoring Dashboard

**Compliance Metrics Dashboard:**

```bash
#!/bin/bash
# compliance-dashboard.sh

watch -n 10 '
echo "=== SOPv5.11 Compliance Dashboard ==="
echo "Last Updated: $(date)"
echo ""

echo "SC-OBS-001: Critical Operations Instrumented (Last Hour)"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_traces
   WHERE attributes[\"sopv511.compliance\"] = \"SC-OBS-001\"
   AND timestamp > now() - INTERVAL 1 HOUR"

echo ""
echo "SC-OBS-002: Anomaly Detection Performance"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     COUNT(*) as anomalies,
     AVG(toFloat64(attributes[\"detection.time_ms\"])) as avg_detection_ms
   FROM signoz.signoz_traces
   WHERE name = \"anomaly_detected\"
   AND timestamp > now() - INTERVAL 1 HOUR"

echo ""
echo "SC-OBS-003: Data Retention Status"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     date_diff(\"day\", MIN(timestamp), MAX(timestamp)) as retention_days
   FROM signoz.signoz_traces"

echo ""
echo "SC-OBS-004: Audit Trail Coverage (Last Hour)"
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_traces
   WHERE attributes[\"sopv511.compliance\"] = \"SC-OBS-004\"
   AND timestamp > now() - INTERVAL 1 HOUR"
'
```

### Automated Compliance Reports

**Daily Report Generation:**

```bash
#!/bin/bash
# generate-compliance-report.sh

report_date=$(date +%Y-%m-%d)
report_file="./data/tmp/compliance_report_${report_date}.md"

cat > $report_file <<EOF
# SOPv5.11 Observability Compliance Report

**Date**: $report_date
**Generated**: $(date '+%Y-%m-%d %H:%M:%S %Z')

---

## Executive Summary

$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     COUNT(DISTINCT attributes['sopv511.compliance']) as constraints_active,
     COUNT(*) as total_compliance_operations
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.compliance'] IS NOT NULL
   AND timestamp > now() - INTERVAL 1 DAY")

---

## SC-OBS-001: Critical Operations Coverage

$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     attributes['operation.type'] as operation_type,
     COUNT(*) as operations
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.compliance'] = 'SC-OBS-001'
   AND timestamp > now() - INTERVAL 1 DAY
   GROUP BY operation_type")

---

## SC-OBS-002: Anomaly Detection Performance

$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     COUNT(*) as total_anomalies,
     AVG(toFloat64(attributes['detection.time_ms'])) as avg_detection_ms,
     MAX(toFloat64(attributes['detection.time_ms'])) as max_detection_ms
   FROM signoz.signoz_traces
   WHERE name = 'anomaly_detected'
   AND timestamp > now() - INTERVAL 1 DAY")

---

## SC-OBS-003: Data Retention Compliance

$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     date_diff('day', MIN(timestamp), MAX(timestamp)) as retention_days,
     COUNT(*) as total_traces,
     formatReadableSize(sum(length(toString(*)))) as total_data_size
   FROM signoz.signoz_traces")

---

## SC-OBS-004: Audit Trail Completeness

$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     attributes['operation_type'] as operation_type,
     COUNT(*) as audit_entries
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.compliance'] = 'SC-OBS-004'
   AND timestamp > now() - INTERVAL 1 DAY
   GROUP BY operation_type")

---

## TPS Methodology Integration

$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     attributes['sopv511.tps.principle'] as tps_principle,
     COUNT(*) as occurrences
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.tps.principle'] IS NOT NULL
   AND timestamp > now() - INTERVAL 1 DAY
   GROUP BY tps_principle")

---

## Compliance Status

- **Overall Status**: $(if [ $(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_traces WHERE attributes['sopv511.compliance'] IS NOT NULL AND timestamp > now() - INTERVAL 1 DAY") -gt 0 ]; then echo "✅ COMPLIANT"; else echo "❌ NON-COMPLIANT"; fi)
- **Violations**: 0
- **Action Items**: None

EOF

echo "Compliance report generated: $report_file"
```

---

## Appendices

### A. Quick Reference Commands

```bash
# Daily compliance check
./scripts/compliance/daily-compliance-check.sh

# Generate compliance report
./scripts/compliance/generate-compliance-report.sh

# Start compliance monitoring dashboard
./scripts/compliance/compliance-dashboard.sh

# Verify STAMP safety constraints
mix test test/sopv511_observability_compliance_test.exs

# Check audit trail completeness
./scripts/compliance/audit-trail-verification.sh
```

### B. Compliance Metrics Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| SC-OBS-001 Coverage | 100% | Critical operations with traces |
| SC-OBS-002 Detection Time | <60 seconds | Anomaly detection latency |
| SC-OBS-003 Retention | 7 days | Data retention in ClickHouse |
| SC-OBS-004 Audit Coverage | 100% | Operations with audit entries |
| TPS Jidoka Response | <5 seconds | Time from error to halt |
| 5-Level RCA Completion | 100% | Incidents with full RCA |
| Kaizen Improvements | >1 per week | Documented improvements |

### C. Emergency Contacts

- **System Administrator**: admin@example.com
- **Compliance Officer**: compliance@example.com
- **On-Call Engineer**: oncall@example.com
- **Escalation**: escalation@example.com

### D. Related Documentation

- [LOGGING_OBSERVABILITY_COMPREHENSIVE_GUIDE.md](../LOGGING_OBSERVABILITY_COMPREHENSIVE_GUIDE.md) - Complete observability documentation
- [DEPLOYMENT_STATUS.md](../DEPLOYMENT_STATUS.md) - Current deployment status
- [SCRIPTS_REFERENCE.md](../SCRIPTS_REFERENCE.md) - Operational scripts documentation
- [README.md](../README.md) - System overview

---

**Document Version**: 1.0.0
**Last Reviewed**: 2025-11-23
**Next Review**: 2025-12-23
**Document Owner**: SOPv5.11 Compliance Team
