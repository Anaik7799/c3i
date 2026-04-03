# SigNoz Deployment Guide

Complete guide for deploying and operating SigNoz observability platform on Podman.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Initial Deployment](#initial-deployment)
4. [Verification](#verification)
5. [Operational Procedures](#operational-procedures)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)
7. [Troubleshooting](#troubleshooting)
8. [Advanced Configuration](#advanced-configuration)

---

## Quick Start

For experienced users who want to deploy immediately:

```bash
cd /home/an/dev/indrajaal-demo/containers/signoz

# Deploy complete stack
./start-signoz-simple.sh

# Verify deployment
./verify-deployment.sh

# Check status
./status.sh

# Access UI
# Open browser: http://localhost:3301
```

---

## Prerequisites

### System Requirements

**Hardware**:
- CPU: 4+ cores recommended
- RAM: 6GB minimum, 8GB recommended
- Disk: 20GB+ for data storage

**Software**:
- Podman 4.0+ installed
- Linux kernel 5.0+ (for containerization features)
- curl/wget for health checks

### Network Requirements

**Required Ports**:
- 3301: Frontend UI
- 4317: OTLP gRPC receiver
- 4318: OTLP HTTP receiver
- 8081: Query Service API
- 8123: ClickHouse HTTP
- 9000: ClickHouse Native
- 13133: Health checks

**Firewall Rules**:
```bash
# If using firewall, allow these ports
sudo firewall-cmd --add-port=3301/tcp --permanent
sudo firewall-cmd --add-port=4317-4318/tcp --permanent
sudo firewall-cmd --add-port=8081/tcp --permanent
sudo firewall-cmd --reload
```

### Container Images

Required images (must be pre-built):
- `localhost/signoz-clickhouse:latest`
- `localhost/signoz-otel-collector:latest`
- `localhost/signoz-query-service:latest`
- `localhost/signoz-frontend:latest`

**Verify images exist**:
```bash
podman images | grep signoz
```

---

## Initial Deployment

### Step 1: Prepare Environment

```bash
# Navigate to deployment directory
cd /home/an/dev/indrajaal-demo/containers/signoz

# Verify all scripts are executable
ls -la *.sh

# Make scripts executable if needed
chmod +x *.sh
```

### Step 2: Review Configuration

**Optional: Customize resource limits**

Edit `start-signoz-simple.sh` to adjust container resources:

```bash
# ClickHouse resources
--cpus=2.0          # CPU cores
--memory=2g         # RAM limit

# OTEL Collector resources
--cpus=1.0
--memory=1g

# Query Service resources
--cpus=1.0
--memory=1g

# Frontend resources
--cpus=0.5
--memory=512m
```

### Step 3: Deploy Stack

```bash
# Clean start (if needed)
./stop-signoz.sh
podman rm signoz-clickhouse signoz-otel-collector signoz-query-service signoz-frontend

# Deploy all containers
./start-signoz-simple.sh
```

**Expected output**:
```
=== SigNoz Container Startup (Simplified) ===
Date: 2025-11-23T12:56:19+01:00

Creating network...
✅ Network: signoz-network

Creating volumes...
✅ Volume: signoz-clickhouse-data
✅ Volume: signoz-query-service-data
✅ Volume: signoz-otel-collector-data

Starting ClickHouse...
✅ ClickHouse container started
   Waiting for health check...
✅ ClickHouse is healthy

Setting up ClickHouse database...
✅ SigNoz ClickHouse schema created successfully

Starting OTEL Collector...
✅ OTEL Collector container started

Starting Query Service...
✅ Query Service container started

Starting Frontend...
✅ Frontend container started

=== SigNoz Deployment Complete ===
```

**Deployment timeline**:
- Initial startup: 2-3 minutes
- ClickHouse ready: ~30 seconds
- OTEL Collector ready: ~60 seconds
- Full stack ready: ~3 minutes

---

## Verification

### Automated Verification

```bash
# Run comprehensive checks
./verify-deployment.sh
```

**Expected results**:
```
🔍 SigNoz Deployment Verification
════════════════════════════════════════════════════════════════

Container Status:
Checking signoz-clickhouse... ✅ Running
Checking signoz-otel-collector... ✅ Running
Checking signoz-query-service... ✅ Running
Checking signoz-frontend... ✅ Running

Endpoint Health:
Checking OTLP HTTP endpoint... ✅ Accessible
Checking Health Check endpoint... ✅ Accessible
Checking Metrics endpoint... ✅ Accessible
Checking Frontend endpoint... ✅ Accessible
Checking Query Service endpoint... ⚠️  May need configuration

Network Status:
Checking signoz-network... ✅ Exists

Database Status:
Checking ClickHouse database... ✅ Accessible
Checking signoz database... ✅ Exists
Checking tables... ✅ 4 tables found

════════════════════════════════════════════════════════════════
Summary:
  ✅ Passed: 11-13
  ❌ Failed: 0-2
```

### Manual Verification

**Check container status**:
```bash
podman ps --filter name=signoz-
```

**Test ClickHouse connectivity**:
```bash
podman exec signoz-clickhouse clickhouse-client --query "SELECT 1"
```

**Verify tables created**:
```bash
podman exec signoz-clickhouse clickhouse-client --query "SHOW TABLES FROM signoz"
```

**Test OTLP receiver**:
```bash
./send_test_trace.sh test-deployment
```

**Access Frontend UI**:
```bash
# Open in browser
xdg-open http://localhost:3301

# Or test with curl
curl -s http://localhost:3301 | grep -i signoz
```

---

## Operational Procedures

### Daily Operations

**Start the system**:
```bash
./start-signoz-simple.sh
```

**Check system status**:
```bash
./status.sh
```

**Monitor logs**:
```bash
# All containers
./monitor-all.sh

# Specific container
podman logs -f signoz-otel-collector
```

**Stop the system**:
```bash
./stop-signoz.sh
```

### Data Management

**Create backup**:
```bash
# Automated timestamped backup
./backup-data.sh

# Named backup
./backup-data.sh before-upgrade
```

**Clear data** (destructive):
```bash
./reset-data.sh
# Type "yes" to confirm
```

**Restore from backup**:
```bash
# Stop services
./stop-signoz.sh

# Restore data (manual process)
# 1. Copy backup files to container volumes
# 2. Import using clickhouse-client
# 3. Restart services
./start-signoz-simple.sh
```

### Testing and Development

**Send test traces**:
```bash
# Single test trace
./send_test_trace.sh my-service

# Multiple traces
for i in {1..10}; do
    ./send_test_trace.sh "service-$i"
    sleep 1
done
```

**Query traces in ClickHouse**:
```bash
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT serviceName, name, COUNT(*)
   FROM signoz.signoz_traces
   GROUP BY serviceName, name"
```

---

## Monitoring and Maintenance

### Health Monitoring

**Automated monitoring** (cron recommended):
```bash
# Add to crontab for automated monitoring
*/5 * * * * /home/an/dev/indrajaal-demo/containers/signoz/verify-deployment.sh || \
  echo "SigNoz health check failed" | mail -s "Alert" admin@example.com
```

**Manual health checks**:
```bash
# Container health
podman ps --filter name=signoz- --format "table {{.Names}}\t{{.Status}}"

# Service endpoints
curl -s http://localhost:13133/    # Health endpoint
curl -s http://localhost:8888/metrics  # Metrics
curl -s http://localhost:3301/     # Frontend
```

**Database health**:
```bash
# Check table sizes
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     table,
     formatReadableSize(sum(bytes)) as size,
     sum(rows) as rows
   FROM system.parts
   WHERE database = 'signoz'
   GROUP BY table"

# Check data age
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     min(timestamp) as oldest,
     max(timestamp) as newest,
     COUNT(*) as total
   FROM signoz.signoz_traces"
```

### Performance Monitoring

**Container resource usage**:
```bash
podman stats --no-stream signoz-clickhouse signoz-otel-collector \
  signoz-query-service signoz-frontend
```

**Network metrics**:
```bash
# Check OTLP receiver metrics
curl -s http://localhost:8888/metrics | grep otelcol_receiver
```

**Database performance**:
```bash
# Query performance statistics
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT
     query,
     elapsed,
     read_rows,
     formatReadableSize(read_bytes) as read_size
   FROM system.query_log
   WHERE type = 'QueryFinish'
   ORDER BY elapsed DESC
   LIMIT 10"
```

### Maintenance Tasks

**Log rotation**:
```bash
# Container logs managed by Podman
# Configure in /etc/containers/containers.conf:
# [engine]
# events_logger = "journald"
# log_size_max = 10485760  # 10MB
```

**Data retention**:
```bash
# Tables have 7-day TTL by default
# To manually clean old data:
podman exec signoz-clickhouse clickhouse-client --query \
  "OPTIMIZE TABLE signoz.signoz_traces FINAL"
```

**Volume cleanup**:
```bash
# Check volume sizes
podman volume ls
du -sh /var/lib/containers/storage/volumes/signoz-*

# Clean unused volumes (careful!)
podman volume prune
```

---

## Troubleshooting

### Container Issues

**Problem: Container fails to start**

```bash
# Check container logs
podman logs signoz-[container-name]

# Check if port is already in use
ss -tulpn | grep [port-number]

# Remove and recreate
podman rm -f signoz-[container-name]
./start-signoz-simple.sh
```

**Problem: Container shows unhealthy status**

```bash
# Check health check logs
podman inspect signoz-[container-name] | jq '.[].State.Health'

# Manually test health check
podman exec signoz-otel-collector wget --no-verbose --tries=1 \
  --spider http://localhost:13133/
```

### Network Issues

**Problem: Containers can't communicate**

```bash
# Check network exists
podman network ls | grep signoz-network

# Inspect network
podman network inspect signoz-network

# Verify containers connected
podman network inspect signoz-network | jq '.[].containers'

# Recreate network
podman network rm signoz-network
podman network create signoz-network
```

**Problem: Ports not accessible**

```bash
# Check port bindings
podman port signoz-frontend

# Test from inside container
podman exec signoz-frontend curl http://localhost:3301

# Check firewall
sudo firewall-cmd --list-ports
```

### Database Issues

**Problem: ClickHouse won't start**

```bash
# Check logs
podman logs signoz-clickhouse

# Check data directory permissions
podman exec signoz-clickhouse ls -la /var/lib/clickhouse

# Reset data (destructive)
podman volume rm signoz-clickhouse-data
./start-signoz-simple.sh
```

**Problem: Schema not created**

```bash
# Manually run schema setup
./clickhouse-setup.sh

# Verify tables
podman exec signoz-clickhouse clickhouse-client --query \
  "SHOW TABLES FROM signoz"
```

**Problem: Can't query data**

```bash
# Check table exists
podman exec signoz-clickhouse clickhouse-client --query \
  "EXISTS TABLE signoz.signoz_traces"

# Check permissions
podman exec signoz-clickhouse clickhouse-client --query \
  "SHOW GRANTS"

# Test simple query
podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_traces"
```

### OTEL Collector Issues

**Problem: Not receiving traces**

```bash
# Check receiver configuration
podman exec signoz-otel-collector cat /etc/otelcol/config.yaml

# Check logs for errors
podman logs signoz-otel-collector | grep -i error

# Test OTLP endpoint
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'
```

**Problem: Exporter errors**

See `CLICKHOUSE_EXPORTER_SCHEMA_ISSUE.md` for known ClickHouse exporter compatibility issues.

---

## Advanced Configuration

### Custom Configuration

**Override OTEL Collector config**:

```yaml
# config/otel-collector/custom-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 100

exporters:
  logging:
    loglevel: debug
  # ClickHouse exporter pending schema compatibility fix

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
```

**Mount custom config**:
```bash
podman run -d \
  --name signoz-otel-collector \
  -v $(pwd)/config/otel-collector/custom-config.yaml:/etc/otelcol/config.yaml:ro,z \
  # ... rest of arguments
  localhost/signoz-otel-collector:latest
```

### Performance Tuning

**ClickHouse optimization**:

```bash
# Increase max connections
podman exec signoz-clickhouse clickhouse-client --query \
  "SET max_connections = 1000"

# Adjust buffer sizes
podman exec signoz-clickhouse clickhouse-client --query \
  "SET max_bytes_before_external_group_by = 20000000000"
```

**OTEL Collector tuning**:

Adjust batch processor in config:
```yaml
processors:
  batch:
    timeout: 10s           # Longer timeout
    send_batch_size: 1024  # Larger batches
```

**Container resources**:

Edit `start-signoz-simple.sh`:
```bash
# Production settings for ClickHouse
--cpus=4.0
--memory=8g

# Production settings for OTEL Collector
--cpus=2.0
--memory=4g
```

### High Availability

**Database replication** (future):
- Deploy multiple ClickHouse nodes
- Configure replication
- Use load balancer

**OTEL Collector scaling**:
```bash
# Run multiple collector instances
for i in {1..3}; do
  podman run -d \
    --name signoz-otel-collector-$i \
    --network signoz-network \
    -p $((4317+$i)):4317 \
    -p $((4318+$i)):4318 \
    localhost/signoz-otel-collector:latest
done

# Use nginx/haproxy to load balance
```

---

## Migration and Upgrade

### Upgrade Procedure

1. **Backup current deployment**:
```bash
./backup-data.sh before-v0.41-upgrade
```

2. **Stop services**:
```bash
./stop-signoz.sh
```

3. **Pull new images**:
```bash
podman pull localhost/signoz-clickhouse:v0.41
podman pull localhost/signoz-otel-collector:v0.41
podman pull localhost/signoz-query-service:v0.41
podman pull localhost/signoz-frontend:v0.41
```

4. **Update image tags in scripts**:
```bash
# Edit start-signoz-simple.sh
# Change :latest to :v0.41
```

5. **Start with new images**:
```bash
./start-signoz-simple.sh
```

6. **Verify upgrade**:
```bash
./verify-deployment.sh
./status.sh
```

### Rollback Procedure

1. **Stop new version**:
```bash
./stop-signoz.sh
```

2. **Revert image tags**:
```bash
# Edit start-signoz-simple.sh back to previous version
```

3. **Restore data if needed**:
```bash
# Follow backup restore procedure
```

4. **Start old version**:
```bash
./start-signoz-simple.sh
```

---

## Security Considerations

### Network Security

**Restrict external access**:
```bash
# Bind ports to localhost only
-p 127.0.0.1:3301:3301  # Frontend
-p 127.0.0.1:4317:4317  # OTLP gRPC
# etc.
```

**Use firewall rules**:
```bash
# Allow only specific IPs
sudo firewall-cmd --add-rich-rule='rule family="ipv4" \
  source address="10.0.0.0/8" port port="3301" protocol="tcp" accept'
```

### Authentication

**ClickHouse users** (future enhancement):
```sql
CREATE USER monitoring IDENTIFIED BY 'secure_password';
GRANT SELECT ON signoz.* TO monitoring;
```

**Query Service JWT** (future enhancement):
Configure JWT_SECRET environment variable

### Data Security

**Encrypt volumes**:
```bash
# Use LUKS-encrypted volumes
# Mount encrypted volumes before starting containers
```

**Regular backups**:
```bash
# Automated daily backups
0 2 * * * /home/an/dev/indrajaal-demo/containers/signoz/backup-data.sh \
  daily-$(date +\%Y\%m\%d)
```

---

## Production Deployment Checklist

Before deploying to production:

- [ ] Resource requirements met (CPU, RAM, Disk)
- [ ] Network ports properly configured
- [ ] Firewall rules in place
- [ ] Container images tested and tagged
- [ ] Configuration files reviewed
- [ ] Backup strategy implemented
- [ ] Monitoring and alerting configured
- [ ] Health check automation in place
- [ ] Data retention policy defined
- [ ] Security measures applied
- [ ] Documentation updated
- [ ] Team trained on operations
- [ ] Incident response procedures documented
- [ ] Disaster recovery plan tested

---

## Support and Resources

### Documentation

- [README.md](README.md) - System overview
- [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) - Script documentation
- [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) - Current status
- [CLICKHOUSE_EXPORTER_SCHEMA_ISSUE.md](CLICKHOUSE_EXPORTER_SCHEMA_ISSUE.md) - Known issues
- [PHASE_5_INTEGRATION_TESTING_REPORT.md](PHASE_5_INTEGRATION_TESTING_REPORT.md) - Test results

### Community

- SigNoz Documentation: https://signoz.io/docs
- SigNoz Community: https://community.signoz.io
- SigNoz Slack: http://signoz.io/slack
- GitHub: https://github.com/SigNoz/signoz

### Getting Help

For deployment issues:
1. Check logs: `podman logs [container-name]`
2. Run verification: `./verify-deployment.sh`
3. Check documentation
4. Contact support team

---

**Last Updated**: 2025-11-23
**Version**: 1.0
**Maintainer**: Development Team
