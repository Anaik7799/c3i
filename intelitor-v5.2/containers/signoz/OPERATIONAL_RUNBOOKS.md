# SigNoz Observability Platform - Operational Runbooks

**Version**: 1.0.0
**Last Updated**: 2025-01-23
**Status**: Production-Ready (Phase 5)
**SOPv5.11 Compliance**: SC-OBS-001, SC-OBS-002, SC-OBS-003, SC-OBS-004

---

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Incident Response](#incident-response)
3. [Maintenance Procedures](#maintenance-procedures)
4. [Troubleshooting Guide](#troubleshooting-guide)
5. [Emergency Procedures](#emergency-procedures)
6. [Performance Optimization](#performance-optimization)
7. [SOPv5.11 Compliance Operations](#sopv511-compliance-operations)

---

## 1. Daily Operations

### 1.1 Morning Health Check Routine

**Purpose**: Verify all observability components are operational before business hours

**Frequency**: Daily at 08:00 CEST

**Procedure**:

```bash
# 1. Check container status
cd /home/an/dev/indrajaal-demo/containers/signoz
./status.sh

# Expected output:
# ✅ signoz-clickhouse: Up X hours
# ✅ signoz-otel-collector: Up X hours
# ✅ signoz-query-service: Up X hours
# ✅ signoz-frontend: Up X hours

# 2. Verify deployment health
./verify-deployment.sh

# Expected output:
# ✅ Network connectivity: OK
# ✅ ClickHouse health: OK
# ✅ OTEL Collector health: OK
# ✅ Query Service health: OK
# ✅ Frontend accessibility: OK
# ✅ Database tables: 3/3 present

# 3. Check OTLP endpoints
curl -f http://localhost:4318/v1/traces || echo "❌ OTLP HTTP endpoint failed"
curl -f http://localhost:13133/ || echo "❌ OTEL Collector health endpoint failed"

# 4. Verify data ingestion (last 5 minutes)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces WHERE timestamp > now() - INTERVAL 5 MINUTE"

# Expected: > 0 traces (if application is sending telemetry)
```

**Success Criteria**:
- All 4 containers running
- All health endpoints responding
- Database tables present
- Recent telemetry data visible (if expected)

**Escalation**: If any check fails, proceed to [Troubleshooting Guide](#troubleshooting-guide)

---

### 1.2 Monitoring Dashboard Review

**Purpose**: Review system metrics and identify trends

**Frequency**: Daily at 09:00 and 17:00 CEST

**Procedure**:

1. **Access SigNoz UI**:
   ```
   http://localhost:3301
   ```

2. **Review Key Metrics**:
   - **Trace Volume**: Traces per minute trend (last 24 hours)
   - **Error Rate**: HTTP 5xx responses (should be <1%)
   - **Latency**: P95 latency for critical services (track against baseline)
   - **Resource Usage**: Container CPU/memory (should be <80%)

3. **Check for Anomalies** (SC-OBS-002 compliance):
   - Sudden spikes in error rate
   - Unusual latency patterns
   - Missing telemetry data from expected services
   - Database query performance degradation

4. **Document Findings**:
   ```bash
   # Create daily monitoring report
   cat > /home/an/dev/indrajaal-demo/data/tmp/monitoring-report-$(date +%Y%m%d).md <<EOF
   # Daily Monitoring Report - $(date +%Y-%m-%d)

   ## Trace Volume
   - 24h average: [traces/min]
   - Peak: [traces/min] at [time]
   - Lowest: [traces/min] at [time]

   ## Error Rate
   - 24h average: [%]
   - Notable errors: [list]

   ## Performance
   - P95 latency: [ms]
   - Database queries: [avg ms]

   ## Anomalies
   - [List any detected anomalies]

   ## Actions Taken
   - [List any interventions]
   EOF
   ```

**Success Criteria**:
- All metrics within acceptable ranges
- No critical anomalies detected
- Report documented

**Escalation**: If anomalies detected, proceed to [Incident Response](#incident-response)

---

### 1.3 Data Retention Verification

**Purpose**: Verify SC-OBS-003 (7-day TTL) compliance

**Frequency**: Daily at 23:00 CEST

**Procedure**:

```bash
# 1. Check oldest data in each table
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     'signoz_traces' as table,
     min(timestamp) as oldest_record,
     dateDiff('day', min(timestamp), now()) as age_days
   FROM signoz.signoz_traces
   UNION ALL
   SELECT
     'signoz_metrics' as table,
     min(timestamp) as oldest_record,
     dateDiff('day', min(timestamp), now()) as age_days
   FROM signoz.signoz_metrics
   UNION ALL
   SELECT
     'signoz_logs' as table,
     min(timestamp) as oldest_record,
     dateDiff('day', min(timestamp), now()) as age_days
   FROM signoz.signoz_logs
   FORMAT PrettyCompact"

# Expected: age_days ≤ 7 for all tables

# 2. Verify TTL enforcement is active
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT table, ttl_expression FROM system.tables
   WHERE database = 'signoz' AND table IN ('signoz_traces', 'signoz_metrics', 'signoz_logs')
   FORMAT PrettyCompact"

# Expected: ttl_expression shows "timestamp + toIntervalDay(7)" for all tables

# 3. Check disk space usage
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     database,
     table,
     formatReadableSize(sum(bytes)) as size,
     sum(rows) as rows
   FROM system.parts
   WHERE database = 'signoz'
   GROUP BY database, table
   FORMAT PrettyCompact"
```

**Success Criteria**:
- No data older than 7 days (±6 hours for merge timing)
- TTL expressions correct for all tables
- Disk usage stable or decreasing

**Escalation**: If data older than 7.5 days exists, investigate TTL merge process

---

### 1.4 Audit Log Review

**Purpose**: Verify SC-OBS-004 (complete audit trail) compliance

**Frequency**: Daily at 18:00 CEST

**Procedure**:

```bash
# 1. Check audit log entries for last 24 hours
# (Assuming audit logs are stored in ClickHouse or separate logging system)

# Example query for ClickHouse-based audit logs:
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     count() as total_events,
     uniq(operation_type) as operation_types,
     uniq(user) as unique_users
   FROM signoz.audit_log
   WHERE timestamp > now() - INTERVAL 24 HOUR
   FORMAT PrettyCompact"

# 2. Verify critical operations are logged
# Check for:
# - Container lifecycle events (start/stop)
# - Database schema changes
# - Configuration modifications
# - Security events (auth failures, permission denials)

# 3. Verify log immutability
# (Audit logs should be write-once, no modifications allowed)

# 4. Check audit log retention
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     min(timestamp) as oldest_audit,
     max(timestamp) as newest_audit,
     dateDiff('day', min(timestamp), now()) as retention_days
   FROM signoz.audit_log
   FORMAT PrettyCompact"

# Expected: retention_days ≥ 7 (matching SC-OBS-003)
```

**Success Criteria**:
- Audit events logged for all critical operations
- No gaps in audit trail
- Retention policy enforced

**Escalation**: If audit gaps detected, initiate [Incident Response](#incident-response)

---

## 2. Incident Response

### 2.1 Jidoka Halt Procedure (TPS Methodology)

**Purpose**: Stop-and-fix principle for critical observability failures

**Trigger Conditions**:
- Any container crash or restart
- Health check failures (2 consecutive failures)
- Data ingestion stopped (no traces for >5 minutes)
- Database connection failures
- Critical anomaly detected (SC-OBS-002)

**Procedure**:

```bash
# 1. HALT - Stop accepting new telemetry data
# (If safe to do so without data loss)
podman exec signoz-otel-collector pkill -STOP otelcol-contrib

# 2. ASSESS - Gather diagnostic information
./status.sh > /home/an/dev/indrajaal-demo/data/tmp/incident-status-$(date +%Y%m%d-%H%M%S).txt
podman logs signoz-clickhouse --tail 100 > /home/an/dev/indrajaal-demo/data/tmp/incident-clickhouse-$(date +%Y%m%d-%H%M%S).log
podman logs signoz-otel-collector --tail 100 > /home/an/dev/indrajaal-demo/data/tmp/incident-otel-$(date +%Y%m%d-%H%M%S).log

# 3. IDENTIFY - Determine root cause using 5-Level RCA
# Level 1: What is the symptom? (e.g., "Container crashed")
# Level 2: What is the surface cause? (e.g., "Out of memory")
# Level 3: What system behavior led to this? (e.g., "Memory leak in OTEL Collector")
# Level 4: What configuration gap allowed this? (e.g., "No memory limits set")
# Level 5: What design decision led to this gap? (e.g., "Assumed default limits sufficient")

# 4. FIX - Apply immediate remediation
# Example for container crash:
podman restart <container-name>

# Example for resource exhaustion:
# Update container resource limits in start-signoz-simple.sh

# 5. VERIFY - Confirm fix resolved issue
./verify-deployment.sh

# 6. RESUME - Restart telemetry ingestion
podman exec signoz-otel-collector pkill -CONT otelcol-contrib

# 7. DOCUMENT - Create incident report
cat > /home/an/dev/indrajaal-demo/data/tmp/incident-report-$(date +%Y%m%d-%H%M%S).md <<EOF
# Incident Report - $(date +%Y-%m-%d %H:%M:%S)

## Incident Details
- **Trigger**: [Description]
- **Detection**: [How discovered]
- **Impact**: [Services affected]
- **Duration**: [Time from detection to resolution]

## 5-Level Root Cause Analysis
1. **Symptom**: [What happened]
2. **Surface Cause**: [Immediate cause]
3. **System Behavior**: [What led to surface cause]
4. **Configuration Gap**: [What allowed behavior]
5. **Design Decision**: [What led to gap]

## Remediation
- **Immediate Fix**: [What was done]
- **Verification**: [How confirmed]
- **Preventive Measures**: [To prevent recurrence]

## SOPv5.11 Compliance
- **Safety Constraints Affected**: [SC-OBS-001, SC-OBS-002, etc.]
- **Agent Coordination**: [15-agent response if applicable]

## Lessons Learned
- [Key takeaways]
- [Process improvements]
EOF
```

**Success Criteria**:
- Incident resolved within target time (P1: <15 min, P2: <1 hour, P3: <4 hours)
- Root cause identified and documented
- Preventive measures implemented
- Audit trail complete (SC-OBS-004)

**Escalation**: If incident cannot be resolved within target time, escalate to emergency procedures

---

### 2.2 Health Check Failure Response

**Purpose**: Respond to SC-OBS-002 anomaly detection (within 1 minute)

**Trigger**: 2 consecutive health check failures (detected within 60 seconds)

**Procedure**:

```bash
# 1. DETECT - Health monitoring detects failure
# (Automated: health checks run every 30 seconds)

# 2. VERIFY - Confirm failure is real (not transient)
# Manual verification:
curl -f http://localhost:13133/ || echo "OTEL Collector health check FAILED"
curl -f http://localhost:8123/ping || echo "ClickHouse health check FAILED"
curl -f http://localhost:8081/api/v1/health || echo "Query Service health check FAILED"
curl -f http://localhost:3301/ || echo "Frontend health check FAILED"

# 3. DIAGNOSE - Check container status
podman ps -a --filter "name=signoz-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 4. INVESTIGATE - Check logs for errors
podman logs <failed-container> --tail 50

# 5. REMEDIATE - Based on failure type:

# Container not running:
podman start <container-name>

# Container running but unhealthy:
podman restart <container-name>

# Network connectivity issues:
podman network inspect signoz-network
# If network missing:
podman network create signoz-network

# Port conflicts:
ss -tulpn | grep -E '(4318|4317|13133|8123|8081|3301|9000)'
# Resolve port conflicts if found

# 6. MONITOR - Verify recovery
# Wait 30 seconds for container startup
sleep 30
./verify-deployment.sh

# 7. DOCUMENT - Log incident
echo "$(date +%Y-%m-%d\ %H:%M:%S) - Health check failure: <container-name> - Remediation: <action-taken>" \
  >> /home/an/dev/indrajaal-demo/data/tmp/health-incidents.log
```

**Success Criteria**:
- Health check passing within 1 minute (SC-OBS-002 compliance)
- Container status verified
- Incident logged

**Escalation**: If health checks still failing after restart, proceed to [Emergency Procedures](#emergency-procedures)

---

### 2.3 Data Ingestion Failure Response

**Purpose**: Restore telemetry data flow when OTLP ingestion stops

**Trigger**: No new traces/metrics/logs for >5 minutes (expected baseline)

**Procedure**:

```bash
# 1. VERIFY - Confirm data ingestion stopped
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces WHERE timestamp > now() - INTERVAL 5 MINUTE"

# If count = 0 and telemetry is expected, data ingestion has stopped

# 2. CHECK OTLP ENDPOINTS
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}' || echo "OTLP HTTP endpoint failed"

# 3. CHECK OTEL COLLECTOR STATUS
podman exec signoz-otel-collector ps aux | grep otelcol-contrib || echo "OTEL Collector process not running"

# 4. CHECK OTEL COLLECTOR LOGS
podman logs signoz-otel-collector --tail 100 | grep -i error

# Common errors:
# - "connection refused" → ClickHouse not accessible
# - "out of memory" → Memory limits exceeded
# - "context deadline exceeded" → Timeout issues

# 5. REMEDIATE BASED ON ERROR

# If ClickHouse connection issues:
podman exec signoz-clickhouse clickhouse-client --query "SELECT 1"
# If fails, restart ClickHouse:
podman restart signoz-clickhouse
sleep 30

# If OTEL Collector process issues:
podman restart signoz-otel-collector
sleep 30

# If configuration issues:
# Check /home/an/dev/indrajaal-demo/containers/signoz/config/otel-collector-config.yaml
# Verify exporters.clickhouse endpoint is correct

# 6. TEST DATA INGESTION
./send_test_trace.sh

# 7. VERIFY RECOVERY
# Wait 1 minute for data to appear
sleep 60
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces WHERE timestamp > now() - INTERVAL 2 MINUTE"

# Should show new traces
```

**Success Criteria**:
- Data ingestion restored
- Test traces visible in database
- OTLP endpoints responding

**Escalation**: If ingestion cannot be restored, check [Troubleshooting Guide](#troubleshooting-guide)

---

## 3. Maintenance Procedures

### 3.1 Backup Procedure

**Purpose**: Create recoverable backups of observability data

**Frequency**:
- Daily automated backups at 02:00 CEST
- Manual backups before maintenance or upgrades

**Procedure**:

```bash
# 1. Create backup using automated script
cd /home/an/dev/indrajaal-demo/containers/signoz
./backup-data.sh

# Script creates:
# - /home/an/dev/indrajaal-demo/data/backups/signoz-backup-<timestamp>.tar.gz
# - Contains: ClickHouse data, OTEL Collector config, SigNoz config

# 2. Verify backup integrity
BACKUP_FILE=$(ls -t /home/an/dev/indrajaal-demo/data/backups/signoz-backup-*.tar.gz | head -1)
tar -tzf "$BACKUP_FILE" | head -20

# Should list:
# - signoz-clickhouse-data/
# - signoz-otel-collector-config/
# - signoz-config/

# 3. Test backup restoration (in test environment)
# Create test volumes:
podman volume create signoz-clickhouse-data-test
podman volume create signoz-otel-collector-config-test

# Extract backup to test volumes:
tar -xzf "$BACKUP_FILE" -C $(podman volume inspect signoz-clickhouse-data-test --format '{{.Mountpoint}}')

# 4. Verify backup size and retention
du -h /home/an/dev/indrajaal-demo/data/backups/signoz-backup-*.tar.gz

# 5. Clean old backups (keep 30 days)
find /home/an/dev/indrajaal-demo/data/backups -name "signoz-backup-*.tar.gz" -mtime +30 -delete
```

**Success Criteria**:
- Backup file created successfully
- Backup size reasonable (typically 100MB - 2GB for 7 days of data)
- Backup integrity verified
- Old backups cleaned

**Restoration Procedure** (if needed):
```bash
# 1. Stop containers
./stop-signoz.sh

# 2. Remove old volumes
podman volume rm signoz-clickhouse-data signoz-otel-collector-config

# 3. Create new volumes
podman volume create signoz-clickhouse-data
podman volume create signoz-otel-collector-config

# 4. Restore from backup
BACKUP_FILE="<path-to-backup-file>"
tar -xzf "$BACKUP_FILE" -C $(podman volume inspect signoz-clickhouse-data --format '{{.Mountpoint}}')

# 5. Restart containers
./start-signoz-simple.sh

# 6. Verify data restored
./verify-deployment.sh
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces"
```

---

### 3.2 Database Maintenance

**Purpose**: Optimize ClickHouse performance and ensure data integrity

**Frequency**: Weekly on Sunday at 03:00 CEST

**Procedure**:

```bash
# 1. OPTIMIZE tables (force merge of data parts)
podman exec signoz-clickhouse clickhouse-client --query \
  "OPTIMIZE TABLE signoz.signoz_traces FINAL"

podman exec signoz-clickhouse clickhouse-client --query \
  "OPTIMIZE TABLE signoz.signoz_metrics FINAL"

podman exec signoz-clickhouse clickhouse-client --query \
  "OPTIMIZE TABLE signoz.signoz_logs FINAL"

# 2. Check for detached parts (sign of corruption)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM system.detached_parts WHERE database = 'signoz'"

# If count > 0, investigate with:
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM system.detached_parts WHERE database = 'signoz' FORMAT PrettyCompact"

# 3. Verify table checksums
podman exec signoz-clickhouse clickhouse-client --query \
  "CHECK TABLE signoz.signoz_traces"

podman exec signoz-clickhouse clickhouse-client --query \
  "CHECK TABLE signoz.signoz_metrics"

podman exec signoz-clickhouse clickhouse-client --query \
  "CHECK TABLE signoz.signoz_logs"

# Expected output: "Ok" for all tables

# 4. Analyze disk usage and compression
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     table,
     formatReadableSize(sum(bytes)) as total_size,
     formatReadableSize(sum(bytes_on_disk)) as compressed_size,
     round(sum(bytes) / sum(bytes_on_disk), 2) as compression_ratio,
     sum(rows) as total_rows
   FROM system.parts
   WHERE database = 'signoz' AND active
   GROUP BY table
   FORMAT PrettyCompact"

# 5. Update table statistics (for query optimization)
podman exec signoz-clickhouse clickhouse-client --query \
  "SYSTEM RELOAD DICTIONARY signoz.*"

# 6. Check for slow queries (>1 second)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     query,
     query_duration_ms,
     read_rows,
     result_rows,
     memory_usage
   FROM system.query_log
   WHERE query_duration_ms > 1000
     AND event_time > now() - INTERVAL 7 DAY
     AND type = 'QueryFinish'
   ORDER BY query_duration_ms DESC
   LIMIT 10
   FORMAT PrettyCompact"

# 7. Document maintenance results
cat > /home/an/dev/indrajaal-demo/data/tmp/db-maintenance-$(date +%Y%m%d).md <<EOF
# Database Maintenance Report - $(date +%Y-%m-%d)

## Optimization Results
- signoz_traces: Optimized
- signoz_metrics: Optimized
- signoz_logs: Optimized

## Health Checks
- Detached parts: [count]
- Table checksums: [OK/FAILED]

## Disk Usage
[Paste compression ratio output]

## Performance
- Slow queries: [count]
- Top slow query: [duration]ms

## Actions Taken
- [List any remediation steps]
EOF
```

**Success Criteria**:
- All tables optimized successfully
- No detached parts (or investigated if present)
- Table checksums OK
- Compression ratio maintained (>3:1)
- Maintenance documented

---

### 3.3 Container Updates and Upgrades

**Purpose**: Keep SigNoz components up-to-date with security and feature updates

**Frequency**: Monthly (or as needed for security patches)

**Procedure**:

```bash
# PRE-UPDATE CHECKLIST
# 1. Create full backup
./backup-data.sh

# 2. Document current state
./status.sh > /home/an/dev/indrajaal-demo/data/tmp/pre-update-status-$(date +%Y%m%d).txt
./verify-deployment.sh > /home/an/dev/indrajaal-demo/data/tmp/pre-update-verify-$(date +%Y%m%d).txt

# 3. Check SigNoz release notes
# Visit: https://github.com/SigNoz/signoz/releases
# Review: Breaking changes, migration steps, new features

# 4. Test upgrade in non-production environment first
# (If available)

# UPDATE PROCEDURE

# 1. Pull latest container images
# Note: Using localhost/ registry per container policy
# Ensure images are available in localhost/ registry before proceeding

# 2. Stop containers (reverse dependency order)
./stop-signoz.sh

# 3. Update start script with new image tags (if needed)
# Edit start-signoz-simple.sh to reference new image versions
# Example:
# OLD: localhost/signoz-frontend:0.36.0
# NEW: localhost/signoz-frontend:0.37.0

# 4. Start containers with new images
./start-signoz-simple.sh

# 5. Monitor startup logs
podman logs -f signoz-clickhouse &
podman logs -f signoz-otel-collector &
podman logs -f signoz-query-service &
podman logs -f signoz-frontend &

# Look for:
# - Successful startup messages
# - Database migrations (if any)
# - No error messages

# 6. Verify deployment
./verify-deployment.sh

# 7. Test data ingestion
./send_test_trace.sh

# 8. Verify test trace appears in UI
# Access http://localhost:3301 and check for test trace

# 9. Monitor for 30 minutes post-upgrade
# Watch for:
# - Container stability (no restarts)
# - Data ingestion continuing
# - No error spikes in logs
# - Performance within acceptable range

# 10. Document upgrade
cat > /home/an/dev/indrajaal-demo/data/tmp/upgrade-report-$(date +%Y%m%d).md <<EOF
# SigNoz Upgrade Report - $(date +%Y-%m-%d)

## Versions
- ClickHouse: [old] → [new]
- OTEL Collector: [old] → [new]
- Query Service: [old] → [new]
- Frontend: [old] → [new]

## Upgrade Steps
- Backup created: [timestamp]
- Downtime: [start] to [end] ([duration])
- Migration steps: [list if any]

## Post-Upgrade Verification
- Deployment health: [PASS/FAIL]
- Data ingestion: [PASS/FAIL]
- UI accessibility: [PASS/FAIL]

## Issues Encountered
- [List any issues and resolutions]

## Rollback Plan (if needed)
- Backup location: [path]
- Rollback steps: [brief description]
EOF
```

**Rollback Procedure** (if upgrade fails):
```bash
# 1. Stop containers
./stop-signoz.sh

# 2. Restore from pre-upgrade backup
# (Follow backup restoration procedure in section 3.1)

# 3. Revert start script to old image tags

# 4. Restart with old versions
./start-signoz-simple.sh

# 5. Verify rollback successful
./verify-deployment.sh

# 6. Document rollback reason
# Update upgrade report with rollback details
```

**Success Criteria**:
- All containers running new versions
- Deployment verification passed
- Data ingestion working
- No critical errors in logs
- Upgrade documented

---

## 4. Troubleshooting Guide

### 4.1 Container Won't Start

**Symptoms**:
- Container status shows "Exited" or "Restarting"
- Start script fails

**Diagnostic Steps**:

```bash
# 1. Check container logs
podman logs <container-name>

# 2. Check for port conflicts
ss -tulpn | grep -E '(4318|4317|13133|8123|8081|3301|9000)'

# 3. Check volume permissions
podman volume inspect <volume-name>
# Verify mountpoint exists and has correct permissions

# 4. Check network
podman network inspect signoz-network
# Verify network exists

# 5. Check resource limits
podman inspect <container-name> | grep -A 10 "Resources"
```

**Common Issues and Resolutions**:

**Issue**: Port already in use
```bash
# Find process using port
sudo ss -tulpn | grep :<port>

# Option 1: Stop conflicting service
sudo systemctl stop <service-name>

# Option 2: Change SigNoz port mapping in start script
# Edit start-signoz-simple.sh and modify port mapping
# Example: -p 14318:4318 instead of -p 4318:4318
```

**Issue**: Volume permission denied
```bash
# Fix SELinux labels
podman volume rm <volume-name>
podman volume create <volume-name>

# Restart container with :z label
# Already included in start-signoz-simple.sh
```

**Issue**: Network not found
```bash
# Recreate network
podman network rm signoz-network
podman network create signoz-network

# Restart containers
./start-signoz-simple.sh
```

---

### 4.2 Database Connection Failures

**Symptoms**:
- "Connection refused" errors in OTEL Collector logs
- Query Service unable to connect to ClickHouse
- Empty results in SigNoz UI

**Diagnostic Steps**:

```bash
# 1. Check ClickHouse is running
podman ps --filter "name=signoz-clickhouse"

# 2. Test ClickHouse connectivity from host
curl http://localhost:8123/ping

# Expected response: "Ok."

# 3. Test ClickHouse from OTEL Collector container
podman exec signoz-otel-collector nc -zv signoz-clickhouse 9000

# Expected: "Connection to signoz-clickhouse 9000 port [tcp/*] succeeded!"

# 4. Check ClickHouse logs for errors
podman logs signoz-clickhouse | grep -i error

# 5. Verify ClickHouse native protocol port
podman exec signoz-clickhouse netstat -tulpn | grep 9000
```

**Common Issues and Resolutions**:

**Issue**: ClickHouse not ready during OTEL Collector startup
```bash
# Solution: Ensure proper startup order in start script
# start-signoz-simple.sh already includes health check delays

# Manual fix: Restart OTEL Collector after ClickHouse is ready
sleep 30  # Wait for ClickHouse to be fully ready
podman restart signoz-otel-collector
```

**Issue**: ClickHouse crashed or corrupted
```bash
# 1. Check ClickHouse logs
podman logs signoz-clickhouse --tail 100

# 2. Try restarting
podman restart signoz-clickhouse
sleep 30

# 3. If still failing, check data corruption
podman exec signoz-clickhouse clickhouse-client --query "CHECK TABLE signoz.signoz_traces"

# 4. If corrupted, restore from backup (section 3.1)
```

**Issue**: Network isolation preventing connections
```bash
# Verify containers are on same network
podman inspect signoz-clickhouse signoz-otel-collector --format '{{.NetworkSettings.Networks}}'

# If on different networks, recreate with correct network
podman rm -f signoz-clickhouse signoz-otel-collector
./start-signoz-simple.sh
```

---

### 4.3 No Traces Appearing in UI

**Symptoms**:
- OTLP endpoints accepting data
- No errors in logs
- But traces not visible in SigNoz UI

**Diagnostic Steps**:

```bash
# 1. Verify data is in ClickHouse
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count(), min(timestamp), max(timestamp) FROM signoz.signoz_traces"

# If count > 0, data is being ingested

# 2. Check time range in UI
# Ensure UI time range includes recent data timestamps

# 3. Verify Query Service is running
curl http://localhost:8081/api/v1/health

# 4. Check Query Service logs
podman logs signoz-query-service | grep -i error

# 5. Test Query Service API directly
curl -X POST http://localhost:8081/api/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "start": "'$(date -u -d '1 hour ago' +%s)000000000'",
    "end": "'$(date -u +%s)000000000'",
    "limit": 10
  }'

# Should return JSON with traces

# 6. Check Frontend connectivity
podman exec signoz-frontend nc -zv signoz-query-service 8081
```

**Common Issues and Resolutions**:

**Issue**: Time range mismatch
```bash
# Solution: In SigNoz UI, set time range to "Last 15 minutes"
# Or use custom time range that includes recent timestamps
```

**Issue**: Query Service not querying correct table
```bash
# Verify Query Service configuration
podman exec signoz-query-service env | grep CLICKHOUSE

# Expected:
# CLICKHOUSE_HOST=signoz-clickhouse
# CLICKHOUSE_PORT=9000
# CLICKHOUSE_DATABASE=signoz
```

**Issue**: Frontend build/cache issues
```bash
# Clear browser cache and reload
# Or access in private/incognito mode

# Restart frontend container
podman restart signoz-frontend
sleep 10
```

---

### 4.4 High Memory Usage

**Symptoms**:
- Container memory usage >80%
- OOMKilled messages in logs
- Slow performance

**Diagnostic Steps**:

```bash
# 1. Check current memory usage
podman stats --no-stream

# 2. Identify high-memory container
# ClickHouse typically uses most memory (expected)

# 3. Check ClickHouse memory settings
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM system.settings WHERE name LIKE '%memory%' FORMAT PrettyCompact"

# 4. Check for memory leaks
# Monitor memory over time:
watch -n 5 'podman stats --no-stream'

# 5. Check OTEL Collector memory configuration
# In config/otel-collector-config.yaml:
# processors:
#   memory_limiter:
#     check_interval: 1s
#     limit_mib: 1024
```

**Common Issues and Resolutions**:

**Issue**: ClickHouse using excessive memory
```bash
# Solution 1: Increase container memory limit
# Edit start-signoz-simple.sh:
# Add: --memory=4g (or appropriate limit)

# Solution 2: Tune ClickHouse memory settings
podman exec signoz-clickhouse clickhouse-client --query \
  "SET max_memory_usage = 2000000000"  # 2GB

# Solution 3: Reduce query complexity
# Avoid SELECT * queries
# Use time range filters
# Limit result sizes
```

**Issue**: OTEL Collector memory leak
```bash
# Solution: Enable memory limiter processor
# Already configured in otel-collector-config.yaml

# If still leaking, restart OTEL Collector daily:
# Add to cron:
# 0 3 * * * podman restart signoz-otel-collector

# Or upgrade to latest version (may have bug fixes)
```

**Issue**: Too much data in 7-day window
```bash
# Solution: Reduce TTL to 3-5 days
podman exec signoz-clickhouse clickhouse-client --query \
  "ALTER TABLE signoz.signoz_traces MODIFY TTL timestamp + INTERVAL 5 DAY"

# Repeat for signoz_metrics and signoz_logs

# Force immediate cleanup:
podman exec signoz-clickhouse clickhouse-client --query \
  "OPTIMIZE TABLE signoz.signoz_traces FINAL"
```

---

### 4.5 Slow Query Performance

**Symptoms**:
- SigNoz UI slow to load
- Queries taking >5 seconds
- Timeout errors

**Diagnostic Steps**:

```bash
# 1. Identify slow queries
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     query,
     query_duration_ms,
     read_rows,
     result_rows,
     formatReadableSize(memory_usage) as memory
   FROM system.query_log
   WHERE query_duration_ms > 5000
     AND event_time > now() - INTERVAL 1 HOUR
     AND type = 'QueryFinish'
   ORDER BY query_duration_ms DESC
   LIMIT 10
   FORMAT PrettyCompact"

# 2. Check table statistics
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     table,
     sum(rows) as total_rows,
     count() as parts_count,
     formatReadableSize(sum(bytes)) as total_size
   FROM system.parts
   WHERE database = 'signoz' AND active
   GROUP BY table
   FORMAT PrettyCompact"

# 3. Check disk I/O
podman exec signoz-clickhouse iostat -x 1 5

# 4. Check for unoptimized queries
# Look for queries without time range filters
```

**Common Issues and Resolutions**:

**Issue**: Too many small parts (poor merge performance)
```bash
# Solution: Force table optimization
podman exec signoz-clickhouse clickhouse-client --query \
  "OPTIMIZE TABLE signoz.signoz_traces FINAL"

# Expected: Parts count should decrease significantly

# Automate: Add to weekly maintenance (section 3.2)
```

**Issue**: Queries scanning too many rows
```bash
# Solution: Ensure queries use time range filters
# Bad query:
SELECT * FROM signoz.signoz_traces WHERE service_name = 'my-service'

# Good query:
SELECT * FROM signoz.signoz_traces
WHERE service_name = 'my-service'
  AND timestamp >= now() - INTERVAL 1 HOUR
  AND timestamp <= now()

# Time range filter uses ORDER BY index (optimized)
```

**Issue**: Disk I/O bottleneck
```bash
# Solution 1: Move volume to faster storage (SSD)
# 1. Backup data
./backup-data.sh

# 2. Stop containers
./stop-signoz.sh

# 3. Copy volume to new location
# 4. Update volume mountpoint
# 5. Restart

# Solution 2: Increase disk I/O limits (if using cgroups)
podman update --blkio-weight 500 signoz-clickhouse
```

---

## 5. Emergency Procedures

### 5.1 Complete System Failure

**Situation**: All containers down, unrecoverable state

**Procedure**:

```bash
# 1. ASSESS SITUATION
# Document current state before making changes
podman ps -a > /home/an/dev/indrajaal-demo/data/tmp/emergency-state-$(date +%Y%m%d-%H%M%S).txt
podman volume ls >> /home/an/dev/indrajaal-demo/data/tmp/emergency-state-$(date +%Y%m%d-%H%M%S).txt
podman network ls >> /home/an/dev/indrajaal-demo/data/tmp/emergency-state-$(date +%Y%m%d-%H%M%S).txt

# 2. ATTEMPT GRACEFUL RECOVERY
# Try standard startup first
./start-signoz-simple.sh

# 3. If graceful recovery fails, FULL RESET
# WARNING: This will lose recent data not in backup

# Stop and remove all containers
podman stop signoz-frontend signoz-query-service signoz-otel-collector signoz-clickhouse
podman rm signoz-frontend signoz-query-service signoz-otel-collector signoz-clickhouse

# Recreate from backup
# (Follow restoration procedure in section 3.1)

# 4. If backup restoration fails, CLEAN SLATE
# EXTREME MEASURE: Only use if data loss is acceptable

# Remove all SigNoz resources
./reset-data.sh  # Interactive confirmation required

# Recreate from scratch
./start-signoz-simple.sh
./clickhouse-setup.sh

# 5. VERIFY RECOVERY
./verify-deployment.sh

# 6. TEST FUNCTIONALITY
./send_test_trace.sh

# 7. DOCUMENT INCIDENT
# Create detailed incident report (use template from section 2.1)
```

**Post-Recovery Actions**:
- Perform 5-Level RCA to prevent recurrence
- Update documentation with lessons learned
- Implement additional monitoring to detect similar failures earlier
- Consider infrastructure improvements (redundancy, failover)

---

### 5.2 Data Corruption Detection

**Situation**: ClickHouse reports corrupted data parts

**Procedure**:

```bash
# 1. IDENTIFY CORRUPTED PARTS
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM system.detached_parts WHERE database = 'signoz' FORMAT PrettyCompact"

# 2. ASSESS IMPACT
# Check which tables are affected
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT table, count() as detached_parts
   FROM system.detached_parts
   WHERE database = 'signoz'
   GROUP BY table
   FORMAT PrettyCompact"

# 3. ATTEMPT AUTOMATIC REPAIR
podman exec signoz-clickhouse clickhouse-client --query \
  "SYSTEM RESTART REPLICA signoz.signoz_traces"

# For each affected table

# 4. If automatic repair fails, MANUAL DETACHMENT HANDLING

# Option A: Try to attach detached parts
podman exec signoz-clickhouse clickhouse-client --query \
  "ALTER TABLE signoz.signoz_traces ATTACH PART '<part-name>'"

# Option B: Drop detached parts (DATA LOSS for that time range)
podman exec signoz-clickhouse clickhouse-client --query \
  "ALTER TABLE signoz.signoz_traces DROP DETACHED PART '<part-name>'"

# 5. VERIFY TABLE INTEGRITY
podman exec signoz-clickhouse clickhouse-client --query \
  "CHECK TABLE signoz.signoz_traces"

# Expected: "Ok"

# 6. If CHECK TABLE fails, RESTORE FROM BACKUP
# (Follow restoration procedure in section 3.1)
# Note: This will lose data between last backup and corruption detection

# 7. PREVENT RECURRENCE
# Check for underlying issues:
# - Disk errors: dmesg | grep -i error
# - Memory issues: journalctl -u podman | grep -i oom
# - Filesystem issues: fsck (when unmounted)

# 8. DOCUMENT INCIDENT
# Include:
# - Time of detection
# - Affected tables and time ranges
# - Data loss assessment
# - Recovery steps taken
# - Root cause analysis
```

**Prevention Measures**:
- Regular backups (daily automated)
- Disk health monitoring (SMART status)
- Memory testing (memtest86)
- Filesystem consistency checks
- Container resource limits to prevent OOM

---

### 5.3 Security Breach Response

**Situation**: Unauthorized access detected or suspected

**Immediate Actions**:

```bash
# 1. ISOLATE SYSTEM
# Stop accepting external connections
podman network disconnect signoz-network signoz-frontend
podman network disconnect signoz-network signoz-query-service

# 2. PRESERVE EVIDENCE
# Capture logs before any cleanup
podman logs signoz-frontend > /home/an/dev/indrajaal-demo/data/tmp/security-incident-frontend-$(date +%Y%m%d-%H%M%S).log
podman logs signoz-query-service > /home/an/dev/indrajaal-demo/data/tmp/security-incident-query-$(date +%Y%m%d-%H%M%S).log
podman logs signoz-otel-collector > /home/an/dev/indrajaal-demo/data/tmp/security-incident-otel-$(date +%Y%m%d-%H%M%S).log
podman logs signoz-clickhouse > /home/an/dev/indrajaal-demo/data/tmp/security-incident-clickhouse-$(date +%Y%m%d-%H%M%S).log

# 3. CHECK FOR UNAUTHORIZED ACCESS
# Review ClickHouse query log for suspicious queries
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     event_time,
     query,
     user,
     client_hostname,
     query_duration_ms
   FROM system.query_log
   WHERE event_time > now() - INTERVAL 24 HOUR
   ORDER BY event_time DESC
   LIMIT 100
   FORMAT PrettyCompact" > /home/an/dev/indrajaal-demo/data/tmp/security-queries-$(date +%Y%m%d-%H%M%S).txt

# 4. CHECK FOR DATA EXFILTRATION
# Look for unusually large queries
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     event_time,
     query,
     result_rows,
     formatReadableSize(result_bytes) as data_transferred
   FROM system.query_log
   WHERE result_rows > 100000
     AND event_time > now() - INTERVAL 7 DAY
   ORDER BY result_rows DESC
   LIMIT 20
   FORMAT PrettyCompact"

# 5. CHECK FOR UNAUTHORIZED MODIFICATIONS
# Review audit log (if implemented)
# Look for:
# - Schema changes
# - User modifications
# - Configuration changes

# 6. ASSESS IMPACT
# Create incident severity assessment:
cat > /home/an/dev/indrajaal-demo/data/tmp/security-incident-assessment-$(date +%Y%m%d-%H%M%S).md <<EOF
# Security Incident Assessment - $(date +%Y-%m-%d %H:%M:%S)

## Incident Details
- **Detection Method**: [How breach was discovered]
- **Suspected Entry Point**: [How attacker gained access]
- **Estimated Breach Window**: [Time range]

## Impact Assessment
- **Data Accessed**: [Yes/No, which tables]
- **Data Modified**: [Yes/No, what changes]
- **Data Exfiltrated**: [Yes/No, approximate volume]
- **System Damage**: [Describe any system modifications]

## Immediate Actions Taken
- [List isolation and evidence preservation steps]

## Next Steps
- [List investigation and remediation steps]
EOF

# 7. NOTIFY STAKEHOLDERS
# According to incident response policy

# 8. FORENSIC INVESTIGATION
# Engage security team or external experts if needed

# 9. REMEDIATION
# Based on investigation findings:
# - Patch vulnerabilities
# - Reset credentials
# - Rebuild compromised containers
# - Restore from known-good backup if necessary

# 10. RESTORE SERVICE
# Only after security team clearance
podman network connect signoz-network signoz-frontend
podman network connect signoz-network signoz-query-service
```

**Post-Incident Actions**:
- Complete security audit
- Implement additional security controls
- Update incident response procedures
- Conduct security awareness training
- Consider security monitoring tools

---

## 6. Performance Optimization

### 6.1 Query Optimization

**Purpose**: Improve ClickHouse query performance

**Procedure**:

```bash
# 1. IDENTIFY SLOW QUERIES (from section 4.5)
# Top 10 slowest queries in last 24 hours
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     normalized_query_hash,
     any(query) as example_query,
     count() as execution_count,
     avg(query_duration_ms) as avg_duration_ms,
     max(query_duration_ms) as max_duration_ms,
     avg(read_rows) as avg_rows_read
   FROM system.query_log
   WHERE event_time > now() - INTERVAL 24 HOUR
     AND type = 'QueryFinish'
     AND query_duration_ms > 1000
   GROUP BY normalized_query_hash
   ORDER BY avg_duration_ms DESC
   LIMIT 10
   FORMAT PrettyCompact"

# 2. ANALYZE QUERY EXECUTION PLANS
# For a slow query, get execution plan:
podman exec signoz-clickhouse clickhouse-client --query \
  "EXPLAIN PLAN SELECT * FROM signoz.signoz_traces
   WHERE service_name = 'my-service'
     AND timestamp >= now() - INTERVAL 1 HOUR
   FORMAT PrettyCompact"

# Look for:
# - Full table scans (should use index)
# - Excessive row reads
# - Missing WHERE clauses on indexed columns

# 3. OPTIMIZATION TECHNIQUES

# Technique A: Add time range filters (uses ORDER BY index)
# Before:
SELECT * FROM signoz.signoz_traces WHERE service_name = 'my-service'

# After:
SELECT * FROM signoz.signoz_traces
WHERE timestamp >= now() - INTERVAL 1 HOUR
  AND timestamp <= now()
  AND service_name = 'my-service'

# Technique B: Use PREWHERE for large columns
# Before:
SELECT * FROM signoz.signoz_traces
WHERE service_name = 'my-service' AND timestamp >= now() - INTERVAL 1 HOUR

# After:
SELECT * FROM signoz.signoz_traces
PREWHERE service_name = 'my-service'
WHERE timestamp >= now() - INTERVAL 1 HOUR

# Technique C: Limit result size
# Before:
SELECT * FROM signoz.signoz_traces WHERE ...

# After:
SELECT trace_id, span_id, span_name, timestamp
FROM signoz.signoz_traces
WHERE ...
LIMIT 1000

# Technique D: Use sampling for analytics queries
# Before:
SELECT count() FROM signoz.signoz_traces WHERE ...

# After:
SELECT count() * 10 FROM signoz.signoz_traces
SAMPLE 0.1  -- 10% sample
WHERE ...

# 4. MONITOR IMPROVEMENT
# Re-run slow query analysis after optimizations
# Verify avg_duration_ms decreased

# 5. UPDATE QUERY SERVICE CODE
# If slow queries come from Query Service application code:
# - Work with development team to apply optimizations
# - Add indexes if appropriate
# - Cache frequently accessed data
```

**Common Optimization Patterns**:

```sql
-- Pattern 1: Time-series queries (always filter by timestamp first)
SELECT * FROM signoz.signoz_traces
WHERE timestamp >= toDateTime('2025-01-23 00:00:00')
  AND timestamp < toDateTime('2025-01-23 01:00:00')
  AND service_name = 'api-service'
ORDER BY timestamp DESC
LIMIT 100

-- Pattern 2: Aggregations with GROUP BY
SELECT
  toStartOfHour(timestamp) as hour,
  service_name,
  count() as trace_count,
  avg(duration_nano) as avg_duration
FROM signoz.signoz_traces
WHERE timestamp >= now() - INTERVAL 24 HOUR
GROUP BY hour, service_name
ORDER BY hour DESC, trace_count DESC

-- Pattern 3: Join with small dimension table
SELECT
  t.trace_id,
  t.span_name,
  t.duration_nano
FROM signoz.signoz_traces t
WHERE timestamp >= now() - INTERVAL 1 HOUR
  AND service_name = 'checkout-service'
ORDER BY duration_nano DESC
LIMIT 10
```

---

### 6.2 Resource Tuning

**Purpose**: Optimize container resource allocation

**Procedure**:

```bash
# 1. BASELINE RESOURCE USAGE
# Monitor for 24 hours to establish baseline
# Create monitoring script:
cat > /home/an/dev/indrajaal-demo/data/tmp/resource-monitor.sh <<'EOF'
#!/bin/bash
while true; do
  echo "=== $(date +%Y-%m-%d\ %H:%M:%S) ===" >> /home/an/dev/indrajaal-demo/data/tmp/resource-usage.log
  podman stats --no-stream >> /home/an/dev/indrajaal-demo/data/tmp/resource-usage.log
  sleep 300  # 5 minutes
done
EOF

chmod +x /home/an/dev/indrajaal-demo/data/tmp/resource-monitor.sh
# Run in background:
nohup /home/an/dev/indrajaal-demo/data/tmp/resource-monitor.sh &

# 2. ANALYZE BASELINE
# After 24 hours, analyze resource-usage.log
# Calculate average, peak, and trend for each container

# 3. TUNE CPU ALLOCATION

# If ClickHouse CPU usage consistently >80%:
# Edit start-signoz-simple.sh to add:
--cpus=4.0  # Allow up to 4 CPUs

# If OTEL Collector CPU spikes during high load:
# Edit otel-collector-config.yaml:
processors:
  batch:
    send_batch_size: 1024  # Reduce from 8192
    send_batch_max_size: 2048
    timeout: 5s

# 4. TUNE MEMORY ALLOCATION

# If ClickHouse memory usage consistently >90%:
# Edit start-signoz-simple.sh to add:
--memory=8g  # Increase from 4g

# If OTEL Collector memory grows unbounded:
# Edit otel-collector-config.yaml:
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 2048  # Increase from 1024
    spike_limit_mib: 512

# 5. TUNE DISK I/O

# If ClickHouse experiencing disk I/O bottleneck:
# Option 1: Increase I/O weight
podman update --blkio-weight 1000 signoz-clickhouse  # Max weight

# Option 2: Move volume to faster storage
# (Requires data migration - see section 3.1)

# 6. TUNE NETWORK

# If network latency between containers:
# Check network driver:
podman network inspect signoz-network | grep -i driver

# If using bridge, consider host networking (less isolation, better performance):
# Edit start-signoz-simple.sh:
# Replace: --network signoz-network
# With: --network host
# Note: Changes port mapping behavior

# 7. APPLY TUNING CHANGES

# Stop containers
./stop-signoz.sh

# Edit start-signoz-simple.sh with resource limits

# Restart with new limits
./start-signoz-simple.sh

# 8. VERIFY IMPROVEMENTS

# Monitor for another 24 hours
# Compare new baseline to old baseline
# Verify:
# - CPU usage more balanced
# - Memory usage stable
# - Disk I/O reduced
# - Query performance improved

# 9. DOCUMENT TUNING
cat > /home/an/dev/indrajaal-demo/data/tmp/resource-tuning-$(date +%Y%m%d).md <<EOF
# Resource Tuning Report - $(date +%Y-%m-%d)

## Baseline Metrics
- ClickHouse CPU: [avg]% / [peak]%
- ClickHouse Memory: [avg]GB / [peak]GB
- OTEL Collector CPU: [avg]% / [peak]%
- OTEL Collector Memory: [avg]MB / [peak]MB

## Tuning Changes
- [List changes made to resource limits]

## Post-Tuning Metrics
- ClickHouse CPU: [avg]% / [peak]%
- ClickHouse Memory: [avg]GB / [peak]GB
- OTEL Collector CPU: [avg]% / [peak]%
- OTEL Collector Memory: [avg]MB / [peak]MB

## Performance Impact
- Query latency: [before] → [after]
- Data ingestion rate: [before] → [after]
- Resource efficiency: [analysis]
EOF
```

**Resource Limit Recommendations**:

| Container | CPU Limit | Memory Limit | Recommended For |
|-----------|-----------|--------------|-----------------|
| ClickHouse | 2-4 cores | 4-8 GB | Small-medium workload (1-10M spans/day) |
| ClickHouse | 4-8 cores | 8-16 GB | Large workload (10-100M spans/day) |
| OTEL Collector | 0.5-1 core | 1-2 GB | Up to 10k spans/sec |
| OTEL Collector | 1-2 cores | 2-4 GB | Up to 50k spans/sec |
| Query Service | 0.5-1 core | 512 MB - 1 GB | Standard |
| Frontend | 0.25-0.5 core | 256-512 MB | Standard |

---

### 6.3 Data Compression Optimization

**Purpose**: Maximize storage efficiency without sacrificing performance

**Procedure**:

```bash
# 1. ANALYZE CURRENT COMPRESSION RATIO
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     table,
     formatReadableSize(sum(bytes)) as uncompressed_size,
     formatReadableSize(sum(bytes_on_disk)) as compressed_size,
     round(sum(bytes) / sum(bytes_on_disk), 2) as compression_ratio,
     any(compression_codec) as codec
   FROM system.parts
   WHERE database = 'signoz' AND active
   GROUP BY table
   FORMAT PrettyCompact"

# Target compression ratio: 3:1 to 5:1 for ZSTD(1)

# 2. TEST DIFFERENT COMPRESSION LEVELS

# Create test table with ZSTD(3) (higher compression, more CPU)
podman exec signoz-clickhouse clickhouse-client --query \
  "CREATE TABLE signoz.signoz_traces_zstd3 AS signoz.signoz_traces
   ENGINE = MergeTree()
   ORDER BY (timestamp, trace_id)
   TTL timestamp + INTERVAL 7 DAY
   SETTINGS index_granularity = 8192
   CODEC(ZSTD(3))"

# Insert sample data:
podman exec signoz-clickhouse clickhouse-client --query \
  "INSERT INTO signoz.signoz_traces_zstd3
   SELECT * FROM signoz.signoz_traces LIMIT 1000000"

# Compare compression:
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     'ZSTD(1) original' as version,
     formatReadableSize(sum(bytes)) as uncompressed,
     formatReadableSize(sum(bytes_on_disk)) as compressed,
     round(sum(bytes) / sum(bytes_on_disk), 2) as ratio
   FROM system.parts
   WHERE table = 'signoz_traces' AND active
   UNION ALL
   SELECT
     'ZSTD(3) test' as version,
     formatReadableSize(sum(bytes)) as uncompressed,
     formatReadableSize(sum(bytes_on_disk)) as compressed,
     round(sum(bytes) / sum(bytes_on_disk), 2) as ratio
   FROM system.parts
   WHERE table = 'signoz_traces_zstd3' AND active
   FORMAT PrettyCompact"

# 3. BENCHMARK QUERY PERFORMANCE
# Run same query on both tables, compare times:
time podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces WHERE timestamp > now() - INTERVAL 1 HOUR"

time podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces_zstd3 WHERE timestamp > now() - INTERVAL 1 HOUR"

# 4. DECIDE ON COMPRESSION LEVEL
# Trade-off:
# - ZSTD(1): Lower compression (~3:1), faster queries, lower CPU
# - ZSTD(3): Higher compression (~4:1), slower queries, higher CPU
# - ZSTD(9): Highest compression (~5:1), slowest queries, highest CPU

# Recommendation:
# - Stick with ZSTD(1) for balanced performance (default)
# - Use ZSTD(3) if disk space critical and CPU available
# - Avoid ZSTD(9) unless extreme disk constraints

# 5. APPLY COMPRESSION CHANGE (if decided)
# Note: Cannot change compression on existing table
# Must create new table and migrate data

# Example for ZSTD(3):
# 1. Create new table with ZSTD(3)
# 2. Copy data: INSERT INTO new_table SELECT * FROM old_table
# 3. Rename tables: RENAME TABLE old TO old_backup, new TO production
# 4. Update application to use new table
# 5. Drop old_backup after verification period

# 6. CLEAN UP TEST TABLE
podman exec signoz-clickhouse clickhouse-client --query \
  "DROP TABLE signoz.signoz_traces_zstd3"
```

**Compression Codec Comparison**:

| Codec | Compression Ratio | Decompression Speed | CPU Usage | Recommended Use |
|-------|-------------------|---------------------|-----------|-----------------|
| LZ4 | 2:1 - 3:1 | Very Fast | Low | Real-time analytics, hot data |
| ZSTD(1) | 3:1 - 4:1 | Fast | Low-Medium | **Default - balanced** |
| ZSTD(3) | 4:1 - 5:1 | Medium | Medium | Disk space constrained |
| ZSTD(9) | 5:1 - 6:1 | Slow | High | Archival, cold data |

---

## 7. SOPv5.11 Compliance Operations

### 7.1 Safety Constraint Verification

**Purpose**: Verify all 4 observability safety constraints are satisfied

**Frequency**: Daily at 10:00 CEST (automated)

**Procedure**:

```bash
# SC-OBS-001: 100% Observability Coverage
# Verify all critical operations generate telemetry

# 1. Check telemetry from all expected services
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT DISTINCT service_name FROM signoz.signoz_traces
   WHERE timestamp > now() - INTERVAL 1 HOUR
   ORDER BY service_name
   FORMAT PrettyCompact"

# Expected: List of all application services
# If any service missing, investigate telemetry configuration

# 2. Verify spans for critical operations
# Example: Check for "user_login" spans
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces
   WHERE span_name = 'user_login'
     AND timestamp > now() - INTERVAL 24 HOUR"

# If count = 0 and logins expected, SC-OBS-001 violated


# SC-OBS-002: Anomaly Detection Within 1 Minute
# Verify health check system operational

# 1. Test health check responsiveness
START_TIME=$(date +%s)
curl -f http://localhost:13133/ || echo "Health check failed"
END_TIME=$(date +%s)
RESPONSE_TIME=$((END_TIME - START_TIME))
echo "Health check response time: ${RESPONSE_TIME}s"
# Expected: < 1 second

# 2. Verify health check frequency (should be every 30 seconds)
# Check health monitoring logs for timestamp intervals

# 3. Simulate anomaly (2 consecutive failures)
# Stop OTEL Collector:
podman stop signoz-otel-collector
# Verify alert generated within 60 seconds
# Check alert/notification system logs
# Restart:
podman start signoz-otel-collector


# SC-OBS-003: 7-Day Minimum Data Retention
# Verify TTL enforcement

# 1. Check oldest data (from section 1.3)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     table,
     min(timestamp) as oldest_record,
     dateDiff('day', min(timestamp), now()) as age_days
   FROM signoz.signoz_traces
   GROUP BY table
   UNION ALL
   SELECT
     'signoz_metrics' as table,
     min(timestamp) as oldest_record,
     dateDiff('day', min(timestamp), now()) as age_days
   FROM signoz.signoz_metrics
   UNION ALL
   SELECT
     'signoz_logs' as table,
     min(timestamp) as oldest_record,
     dateDiff('day', min(timestamp), now()) as age_days
   FROM signoz.signoz_logs
   FORMAT PrettyCompact"

# Expected: age_days ≤ 7 for all tables (SC-OBS-003 compliant)
# If age_days > 7.5, TTL enforcement may be failing

# 2. Verify TTL expressions
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT database, table, ttl_expression
   FROM system.tables
   WHERE database = 'signoz'
   FORMAT PrettyCompact"

# Expected: "timestamp + toIntervalDay(7)" for all tables


# SC-OBS-004: Complete Audit Trail
# Verify audit logging operational

# 1. Check audit log coverage (from section 1.4)
# Verify critical operations logged:
# - Container lifecycle
# - Database operations
# - Security events
# - Configuration changes

# 2. Verify audit log immutability
# Attempt to modify audit log (should fail):
# podman exec signoz-clickhouse clickhouse-client --query \
#   "ALTER TABLE signoz.audit_log UPDATE operation_type = 'modified' WHERE id = 1"
# Expected: Error (table should be write-once)

# 3. Check audit log retention (≥ 7 days)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     min(timestamp) as oldest_audit,
     dateDiff('day', min(timestamp), now()) as retention_days
   FROM signoz.audit_log
   FORMAT PrettyCompact"

# Expected: retention_days ≥ 7


# COMPLIANCE REPORT GENERATION
cat > /home/an/dev/indrajaal-demo/data/tmp/sopv511-compliance-$(date +%Y%m%d).md <<EOF
# SOPv5.11 Observability Compliance Report - $(date +%Y-%m-%d)

## SC-OBS-001: 100% Observability Coverage
- **Status**: [COMPLIANT / NON-COMPLIANT]
- **Services Reporting**: [count] / [expected]
- **Missing Services**: [list if any]
- **Critical Operations Traced**: [Yes/No]
- **Remediation**: [if non-compliant]

## SC-OBS-002: Anomaly Detection Within 1 Minute
- **Status**: [COMPLIANT / NON-COMPLIANT]
- **Health Check Frequency**: [actual] seconds
- **Health Check Response Time**: [actual] seconds
- **Anomaly Detection Tested**: [Yes/No]
- **Detection Latency**: [actual] seconds (target: <60)
- **Remediation**: [if non-compliant]

## SC-OBS-003: 7-Day Minimum Data Retention
- **Status**: [COMPLIANT / NON-COMPLIANT]
- **signoz_traces retention**: [actual] days
- **signoz_metrics retention**: [actual] days
- **signoz_logs retention**: [actual] days
- **TTL Expressions Valid**: [Yes/No]
- **Remediation**: [if non-compliant]

## SC-OBS-004: Complete Audit Trail
- **Status**: [COMPLIANT / NON-COMPLIANT]
- **Audit Log Coverage**: [%]
- **Audit Log Retention**: [actual] days
- **Audit Log Immutability**: [Enforced/Not Enforced]
- **Critical Operations Logged**: [Yes/No]
- **Remediation**: [if non-compliant]

## Overall Compliance
- **Total Constraints**: 4
- **Compliant**: [count]
- **Non-Compliant**: [count]
- **Compliance Rate**: [%]

## Actions Required
- [List any remediation actions needed]
EOF
```

**Success Criteria**:
- All 4 safety constraints compliant
- Compliance report generated
- Any non-compliance issues documented with remediation plan

---

### 7.2 50-Agent Coordination Validation

**Purpose**: Verify SOPv5.11 15-agent hierarchical architecture coordination

**Note**: This section validates that the SigNoz observability system integrates properly with the SOPv5.11 15-agent coordination framework described in CLAUDE.md.

**Frequency**: Weekly on Monday at 09:00 CEST

**Procedure**:

```bash
# 1. VERIFY AGENT HIERARCHY AWARENESS
# Domain Supervisor 9 (Observability) should coordinate SigNoz operations

# Check that observability operations use agent coordination:
# - Container lifecycle managed by agents
# - Health monitoring coordinated by agents
# - Incident response follows agent hierarchy

# 2. VERIFY TELEMETRY FROM AGENT OPERATIONS
# Agents should generate telemetry for their activities

# Check for agent-related spans:
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces
   WHERE attributes['sopv511.agent'] != ''
     AND timestamp > now() - INTERVAL 24 HOUR"

# Expected: > 0 if agents are instrumented to send telemetry

# 3. VERIFY JIDOKA HALT TELEMETRY
# When Jidoka halt occurs, it should be recorded in observability

# Check for Jidoka-related spans:
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     timestamp,
     span_name,
     attributes
   FROM signoz.signoz_traces
   WHERE attributes['sopv511.tps.principle'] = 'jidoka'
     AND timestamp > now() - INTERVAL 7 DAY
   ORDER BY timestamp DESC
   LIMIT 10
   FORMAT PrettyCompact"

# 4. VERIFY 5-LEVEL RCA DOCUMENTATION
# RCA findings should be stored and queryable

# Check RCA audit entries:
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.audit_log
   WHERE operation_subtype = '5_level_rca'
     AND timestamp > now() - INTERVAL 7 DAY"

# 5. VERIFY AGENT PERFORMANCE METRICS
# Agents should report their coordination efficiency

# Example query (if agent metrics are sent to SigNoz):
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     metric_name,
     avg(value) as avg_value
   FROM signoz.signoz_metrics
   WHERE metric_name LIKE 'sopv511_agent_%'
     AND timestamp > now() - INTERVAL 1 HOUR
   GROUP BY metric_name
   FORMAT PrettyCompact"

# Expected metrics:
# - sopv511_agent_coordination_efficiency (target: >90%)
# - sopv511_agent_task_completion_rate
# - sopv511_agent_response_time

# 6. VERIFY EMERGENCY PROTOCOL INTEGRATION
# Emergency procedures should trigger agent coordination

# Simulate emergency (controlled test):
# - Trigger Jidoka halt
# - Verify Executive Director notified (log entry)
# - Verify Domain Supervisor 9 (Observability) coordinates response
# - Verify Worker Agents execute remediation

# 7. DOCUMENT AGENT COORDINATION VALIDATION
cat > /home/an/dev/indrajaal-demo/data/tmp/agent-coordination-validation-$(date +%Y%m%d).md <<EOF
# 50-Agent Coordination Validation - $(date +%Y-%m-%d)

## Hierarchy Awareness
- **Observability Domain Supervisor**: [Active/Inactive]
- **Worker Agent Count**: [count]
- **Coordination Protocol**: [Operational/Needs Attention]

## Telemetry Integration
- **Agent Spans**: [count] in last 24 hours
- **Jidoka Events**: [count] in last 7 days
- **RCA Documentation**: [count] in last 7 days

## Performance Metrics
- **Coordination Efficiency**: [%]
- **Task Completion Rate**: [%]
- **Response Time**: [ms]

## Emergency Protocol
- **Integration Status**: [Tested/Not Tested]
- **Executive Director Notification**: [Working/Needs Attention]
- **Remediation Coordination**: [Effective/Needs Improvement]

## Recommendations
- [List any improvements to agent-observability integration]
EOF
```

**Success Criteria**:
- Agent hierarchy aware of observability operations
- Telemetry generated for agent activities
- Jidoka and RCA events properly documented
- Emergency protocols integrate with agent coordination

---

### 7.3 PHICS Integration Health Check

**Purpose**: Verify PHICS v2.1 (Phoenix Hot-reloading Integration Container System) operational

**Note**: PHICS enables <50ms bidirectional file synchronization for development

**Frequency**: Daily during development sprints

**Procedure**:

```bash
# 1. VERIFY PHICS CONTAINER SETUP
# Check if PHICS is enabled for development containers

# Expected PHICS environment variables:
podman exec signoz-frontend env | grep PHICS

# Expected:
# PHICS_ENABLED=true
# PHICS_WATCH_ENABLED=true
# PHICS_CONTAINER_MODE=development

# 2. TEST FILE SYNCHRONIZATION LATENCY
# Create test file on host:
echo "PHICS test $(date)" > /home/an/dev/indrajaal-demo/containers/signoz/phics-test.txt

# Check if file appears in container:
START_TIME=$(date +%s%3N)  # milliseconds
podman exec signoz-frontend test -f /app/phics-test.txt
END_TIME=$(date +%s%3N)
SYNC_LATENCY=$((END_TIME - START_TIME))

echo "PHICS sync latency: ${SYNC_LATENCY}ms"
# Expected: < 50ms (SC-PHICS-001 compliance)

# Clean up:
rm /home/an/dev/indrajaal-demo/containers/signoz/phics-test.txt
podman exec signoz-frontend rm -f /app/phics-test.txt

# 3. VERIFY BIDIRECTIONAL SYNC
# Modify file in container:
podman exec signoz-frontend sh -c 'echo "Container modification $(date)" > /app/container-test.txt'

# Check if appears on host:
sleep 1
if [ -f /home/an/dev/indrajaal-demo/containers/signoz/container-test.txt ]; then
  echo "Bidirectional sync: WORKING"
else
  echo "Bidirectional sync: FAILED"
fi

# Clean up:
rm -f /home/an/dev/indrajaal-demo/containers/signoz/container-test.txt

# 4. VERIFY HOT-RELOADING
# (If Phoenix application in development mode)
# Make code change on host → should reload in container automatically

# Monitor Phoenix reload logs:
podman logs signoz-frontend --tail 20 | grep -i reload

# 5. MEASURE PHICS PERFORMANCE
# Track PHICS sync metrics:
podman exec signoz-frontend env | grep PHICS | while read line; do
  echo "$(date +%Y-%m-%d\ %H:%M:%S) $line" >> /home/an/dev/indrajaal-demo/data/tmp/phics-metrics.log
done

# 6. DOCUMENT PHICS HEALTH
cat > /home/an/dev/indrajaal-demo/data/tmp/phics-health-$(date +%Y%m%d).md <<EOF
# PHICS Integration Health Check - $(date +%Y-%m-%d)

## Configuration
- **PHICS Enabled**: [Yes/No]
- **Watch Enabled**: [Yes/No]
- **Container Mode**: [development/production]

## Performance
- **Host-to-Container Sync**: [latency]ms (target: <50ms)
- **Container-to-Host Sync**: [latency]ms (target: <50ms)
- **Hot-Reload Working**: [Yes/No]

## SC-PHICS-001 Compliance
- **Status**: [COMPLIANT / NON-COMPLIANT]
- **Sync Latency**: [actual] (target: <50ms)

## Issues
- [List any synchronization issues]

## Recommendations
- [List any PHICS optimization suggestions]
EOF
```

**Success Criteria**:
- PHICS environment variables set correctly
- Sync latency <50ms (SC-PHICS-001 compliant)
- Bidirectional sync working
- Hot-reloading functional (if applicable)

---

## Appendix A: Reference Commands

### Quick Reference Card

```bash
# STATUS CHECK (most frequent)
./status.sh
./verify-deployment.sh
curl http://localhost:13133/  # OTEL Collector health
curl http://localhost:8123/ping  # ClickHouse health

# DATA VERIFICATION
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz.signoz_traces WHERE timestamp > now() - INTERVAL 5 MINUTE"

# LOG INSPECTION
podman logs signoz-clickhouse --tail 50
podman logs signoz-otel-collector --tail 50
podman logs signoz-query-service --tail 50
podman logs signoz-frontend --tail 50

# PERFORMANCE
podman stats --no-stream
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM system.query_log WHERE query_duration_ms > 1000 ORDER BY query_duration_ms DESC LIMIT 5 FORMAT PrettyCompact"

# BACKUP & RECOVERY
./backup-data.sh
# Restore: see section 3.1

# EMERGENCY
./stop-signoz.sh
./start-signoz-simple.sh
./reset-data.sh  # CAUTION: Data loss

# MONITORING
./monitor-all.sh  # Real-time logs from all containers
```

---

## Appendix B: Escalation Matrix

| Issue Severity | Response Time | Escalation Path | On-Call Required |
|----------------|---------------|-----------------|------------------|
| **P1 - Critical** | 15 minutes | Immediate → Team Lead → Management | Yes (24/7) |
| All containers down | | | |
| Data corruption detected | | | |
| Security breach | | | |
| **P2 - High** | 1 hour | Standard → Team Lead | Business hours |
| Single container down | | | |
| Health check failures | | | |
| Data ingestion stopped | | | |
| **P3 - Medium** | 4 hours | Standard escalation | Business hours |
| Performance degradation | | | |
| Non-critical errors | | | |
| Slow queries | | | |
| **P4 - Low** | 24 hours | Standard workflow | No |
| Minor issues | | | |
| Optimization opportunities | | | |

---

## Appendix C: Contact Information

```
# SigNoz Observability Platform Operations

Primary Operator: [Name]
Email: [email]
Phone: [phone]

Team Lead: [Name]
Email: [email]
Phone: [phone]

Escalation Email: [email]
Emergency Hotline: [phone]

On-Call Schedule: [Link to schedule]
Incident Management: [Link to tool]
Documentation: /home/an/dev/indrajaal-demo/containers/signoz/
```

---

## Appendix D: Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-01-23 | 1.0.0 | Initial release | System |
| | | Comprehensive operational runbooks created | |
| | | All 7 sections documented | |
| | | SOPv5.11 compliance integrated | |

---

**End of Operational Runbooks**

**Last Updated**: 2025-01-23
**Next Review**: 2025-02-23 (Monthly)
**Maintained By**: SigNoz Observability Operations Team
