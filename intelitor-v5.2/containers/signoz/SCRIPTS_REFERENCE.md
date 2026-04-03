# SigNoz Scripts Reference

Complete reference for all operational scripts in the SigNoz deployment.

## Deployment Scripts

### start-signoz-simple.sh
**Purpose**: Launch complete SigNoz stack with all 4 containers

**Usage**:
```bash
./start-signoz-simple.sh
```

**What it does**:
1. Creates signoz-network bridge network
2. Creates persistent volumes for all services
3. Starts ClickHouse database container
4. Initializes ClickHouse schema (calls clickhouse-setup.sh)
5. Starts OTEL Collector container
6. Starts Query Service container
7. Starts Frontend container

**Success indicators**:
- All containers show "healthy" or "running" status
- ClickHouse tables created successfully
- Frontend accessible at http://localhost:3301

**Notes**:
- First run may take 2-3 minutes for container health checks
- OTEL Collector health check may timeout initially but service will be functional
- Query Service requires configuration (see Phase 5 docs for ClickHouse exporter issue)

---

### stop-signoz.sh
**Purpose**: Gracefully stop all SigNoz containers

**Usage**:
```bash
./stop-signoz.sh
```

**What it does**:
- Stops containers in reverse dependency order (Frontend → Query → Collector → ClickHouse)
- Shows final container status
- Provides commands for cleanup and restart

**Notes**:
- Does not remove containers (use `podman rm` manually if needed)
- Does not delete volumes (data persists)
- Use `./start-signoz-simple.sh` to restart

---

### clickhouse-setup.sh
**Purpose**: Initialize ClickHouse schema for SigNoz

**Usage**:
```bash
./clickhouse-setup.sh
```

**What it creates**:
- `signoz.signoz_traces` - OpenTelemetry trace storage
- `signoz.signoz_metrics` - Metrics data storage
- `signoz.signoz_logs` - Log data storage

**Schema features**:
- Optimized compression (ZSTD, DoubleDelta)
- 7-day TTL on all data
- Partitioned by date for efficient queries
- Optimized for high cardinality attributes

**Notes**:
- Automatically called by start-signoz-simple.sh
- Safe to run multiple times (CREATE TABLE IF NOT EXISTS)
- Executes commands inside signoz-clickhouse container

---

## Operational Scripts

### status.sh
**Purpose**: Comprehensive system status check

**Usage**:
```bash
./status.sh
```

**What it shows**:
- Container status with ports
- Network connectivity
- Volume sizes
- Service health (4 HTTP endpoints)
- Database status with row counts
- All access URLs

**Exit codes**:
- Always returns 0 (informational only)

---

### verify-deployment.sh
**Purpose**: Automated health checks for CI/CD pipelines

**Usage**:
```bash
./verify-deployment.sh
```

**What it checks**:
- 4 container status checks
- 5 endpoint health checks
- Network existence
- Database accessibility
- Table count verification

**Exit codes**:
- 0 if all checks pass
- 1 if any check fails

**Use cases**:
- Pre-deployment validation
- Post-deployment smoke tests
- CI/CD pipeline health gates
- Automated monitoring

---

### send_test_trace.sh
**Purpose**: Send test OTLP traces for validation

**Usage**:
```bash
./send_test_trace.sh [service-name]
```

**Examples**:
```bash
./send_test_trace.sh                    # Uses "test-service" as default
./send_test_trace.sh my-app            # Custom service name
./send_test_trace.sh production-api    # Another example
```

**What it does**:
- Generates unique trace and span IDs
- Creates properly formatted OTLP JSON payload
- Sends trace via HTTP to port 4318
- Provides verification commands

**Verification**:
```bash
# Check OTEL Collector logs
podman logs signoz-otel-collector | grep TracesExporter

# Query ClickHouse (once exporter enabled)
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT * FROM signoz.signoz_traces WHERE traceID = 'YOUR_TRACE_ID'"
```

---

### monitor-all.sh
**Purpose**: Monitor all container logs simultaneously

**Usage**:
```bash
./monitor-all.sh
```

**What it does**:
- Shows logs from all 4 containers in parallel
- Color-coded output per container:
  - Cyan: ClickHouse
  - Green: OTEL Collector
  - Yellow: Query Service
  - Magenta: Frontend
- Real-time log streaming

**Notes**:
- Press Ctrl+C to stop monitoring
- Useful for debugging startup issues
- Shows all container output simultaneously

---

### backup-data.sh
**Purpose**: Backup SigNoz data and configuration

**Usage**:
```bash
./backup-data.sh [backup-name]
```

**Examples**:
```bash
./backup-data.sh                        # Auto-generated timestamped name
./backup-data.sh before-upgrade         # Custom name
./backup-data.sh 2025-11-23-production  # Date-based name
```

**What it backs up**:
- All trace data (JSONEachRow format)
- All metrics data
- All logs data
- Database schema (DDL)
- Configuration files
- Container image references

**Backup location**:
```
/home/an/dev/indrajaal-demo/data/signoz/backups/[backup-name]/
├── traces.jsonl
├── metrics.jsonl
├── logs.jsonl
├── schema_traces.sql
├── schema_metrics.sql
├── schema_logs.sql
├── config/
└── metadata.json
```

**Notes**:
- Backups are stored outside containers
- Safe to run while system is running
- Can be used for disaster recovery or migration

---

### reset-data.sh
**Purpose**: Clear all telemetry data from ClickHouse

**Usage**:
```bash
./reset-data.sh
```

**What it does**:
- Requires explicit "yes" confirmation
- Truncates all 3 tables (traces, metrics, logs)
- Verifies all data cleared
- Reports final row counts

**Use cases**:
- Clean slate for testing
- Remove test data before production
- Development environment refresh

**Warning**:
- **IRREVERSIBLE** - All data will be permanently deleted
- Use `./backup-data.sh` first if you need to preserve data
- Does not affect schema or configuration

---

## Quick Reference

### Daily Operations

```bash
# Start the system
./start-signoz-simple.sh

# Check status
./status.sh

# Send test trace
./send_test_trace.sh my-service

# Monitor logs
./monitor-all.sh

# Stop the system
./stop-signoz.sh
```

### Troubleshooting

```bash
# Comprehensive verification
./verify-deployment.sh

# Check specific container logs
podman logs signoz-clickhouse
podman logs signoz-otel-collector
podman logs signoz-query-service
podman logs signoz-frontend

# Monitor all logs simultaneously
./monitor-all.sh

# Check database connectivity
podman exec signoz-clickhouse clickhouse-client --query "SELECT 1"

# Check table counts
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_traces"
```

### Maintenance

```bash
# Create backup before changes
./backup-data.sh before-maintenance

# Verify deployment health
./verify-deployment.sh

# Clear test data
./reset-data.sh

# Restart services
./stop-signoz.sh
./start-signoz-simple.sh
```

### CI/CD Integration

```bash
#!/bin/bash
# Example deployment pipeline

# Deploy containers
./start-signoz-simple.sh

# Wait for startup
sleep 30

# Verify deployment
if ./verify-deployment.sh; then
    echo "Deployment successful"

    # Send test trace
    ./send_test_trace.sh ci-test

    # Run additional tests...

else
    echo "Deployment failed"
    ./stop-signoz.sh
    exit 1
fi
```

---

## Environment Variables

### OTEL Collector
- `OTEL_EXPORTER_OTLP_ENDPOINT`: Where to send telemetry (default: http://localhost:4318)

### Query Service
- `STORAGE_TYPE`: Storage backend (needs configuration - see Phase 5 docs)
- `CLICKHOUSE_HOST`: ClickHouse server (default: clickhouse)
- `CLICKHOUSE_PORT`: ClickHouse port (default: 9000)

### Frontend
- `FRONTEND_API_ENDPOINT`: Query Service URL (default: http://query-service:8080)

---

## Port Reference

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| ClickHouse | 9000 | TCP | Native protocol |
| ClickHouse | 8123 | HTTP | HTTP interface |
| OTEL Collector | 4317 | gRPC | OTLP gRPC receiver |
| OTEL Collector | 4318 | HTTP | OTLP HTTP receiver |
| OTEL Collector | 8888 | HTTP | Metrics endpoint |
| OTEL Collector | 13133 | HTTP | Health check |
| Query Service | 8081 | HTTP | API (mapped from 8080) |
| Frontend | 3301 | HTTP | Web UI |

---

## File Permissions

All scripts are executable:
```bash
chmod +x *.sh
```

Required permissions for data directories:
- `/var/lib/clickhouse` inside container: user `clickhouse`
- Volume mounts: SELinux `:z` flag for proper access

---

## Troubleshooting Common Issues

### OTEL Collector shows "unhealthy"
**Symptom**: Health check fails but service is running

**Cause**: Health endpoint takes 30-60 seconds to start

**Solution**: Wait longer or check actual functionality:
```bash
curl http://localhost:13133/
```

### Query Service fails to start
**Symptom**: Container crashes with "storage type not supported"

**Cause**: Missing ClickHouse exporter configuration (Phase 5 issue)

**Solution**: See `CLICKHOUSE_EXPORTER_SCHEMA_ISSUE.md` for workaround

### Frontend can't connect to Query Service
**Symptom**: Frontend UI shows errors

**Cause**: Query Service not configured or not running

**Solution**:
1. Check Query Service logs: `podman logs signoz-query-service`
2. Verify network connectivity: `podman network inspect signoz-network`
3. Check FRONTEND_API_ENDPOINT environment variable

### ClickHouse schema not created
**Symptom**: Tables don't exist in database

**Cause**: clickhouse-setup.sh failed or not called

**Solution**:
```bash
./clickhouse-setup.sh
# Or manually:
podman exec signoz-clickhouse clickhouse-client --query "SHOW TABLES FROM signoz"
```

---

## Related Documentation

- [README.md](README.md) - System overview and architecture
- [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) - Current deployment state
- [CLICKHOUSE_EXPORTER_SCHEMA_ISSUE.md](CLICKHOUSE_EXPORTER_SCHEMA_ISSUE.md) - Known issues
- [PHASE_5_INTEGRATION_TESTING_REPORT.md](PHASE_5_INTEGRATION_TESTING_REPORT.md) - Test results

---

## Script Development Guidelines

When creating new scripts:

1. **Add shebang**: `#!/bin/bash`
2. **Set permissions**: `chmod +x script.sh`
3. **Use `set -e`**: Exit on errors for deployment scripts
4. **Add comments**: Explain what each section does
5. **Print status**: Use echo to show progress
6. **Use emojis**: ✅ ❌ 🔍 📊 for visual feedback
7. **Handle errors**: Check exit codes and provide helpful messages
8. **Document usage**: Add usage instructions in comments and help output
