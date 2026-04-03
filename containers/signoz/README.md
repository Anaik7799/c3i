# SigNoz Observability Stack - Deployment and Operations

**Status**: ✅ **PRODUCTION READY** - Phase 5 Complete
**Last Updated**: 2025-11-23 14:30:00 CEST
**Policy Compliance**: EXC-001 (100% localhost/ registry)
**Deployment Version**: 1.2.0

## Overview

This directory contains the complete SigNoz observability stack deployment - a full-stack open-source APM (Application Performance Monitoring) and observability platform providing distributed tracing, metrics monitoring, and log management capabilities.

### Current System Status

✅ **All 4 containers operational and production-ready:**
- **ClickHouse** (Database) - Healthy
- **OTEL Collector** (Data Ingestion) - Running
- **Query Service** (API Layer) - Running
- **Frontend** (Web UI) - Healthy

### Quick Links

- **📖 [Comprehensive Logging & Observability Guide](LOGGING_OBSERVABILITY_COMPREHENSIVE_GUIDE.md)** - Complete system documentation
- **🚀 [Deployment Guide](DEPLOYMENT_GUIDE.md)** - Full operational procedures
- **📋 [Scripts Reference](SCRIPTS_REFERENCE.md)** - All operational scripts
- **📊 [Deployment Status](DEPLOYMENT_STATUS.md)** - Current system state
- **🔧 [Documentation Summary](DOCUMENTATION_UPDATE_SUMMARY.md)** - Task completion record

## System Architecture

### 4-Container Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   SigNoz Observability Stack                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Your Application (Elixir/Phoenix)                               │
│         │                                                         │
│         │ OTLP (HTTP:4318 or gRPC:4317)                         │
│         ▼                                                         │
│  ┌──────────────────┐                                            │
│  │ OTEL Collector   │ Receive, Process, Export                  │
│  │ Port: 4317/4318  │                                            │
│  └────────┬─────────┘                                            │
│           │                                                       │
│           │ Native Protocol (:9000)                              │
│           ▼                                                       │
│  ┌──────────────────┐                                            │
│  │   ClickHouse     │ Columnar Database Storage                 │
│  │ Port: 9000/8123  │                                            │
│  └────────┬─────────┘                                            │
│           │                                                       │
│           │ SQL Queries                                          │
│           ▼                                                       │
│  ┌──────────────────┐        ┌──────────────┐                   │
│  │  Query Service   │───────▶│   Frontend   │                   │
│  │  Port: 8081      │        │  Port: 3301  │                   │
│  └──────────────────┘        └──────────────┘                   │
│                                      │                           │
│                                      ▼                           │
│                              http://localhost:3301               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Purpose | Image | Ports | Status |
|-----------|---------|-------|-------|--------|
| **ClickHouse** | OLAP database for traces/metrics/logs | localhost/signoz-clickhouse:latest | 9000, 8123 | ✅ Healthy |
| **OTEL Collector** | OpenTelemetry data ingestion | localhost/signoz-otel-collector:latest | 4317, 4318, 8888, 13133 | ✅ Running |
| **Query Service** | API layer for data retrieval | localhost/signoz-query-service:latest | 8081 | ✅ Running |
| **Frontend** | Web UI for visualization | localhost/signoz-frontend:latest | 3301 | ✅ Healthy |

## Directory Structure

```
signoz/
├── docker-compose.yml                    # Main orchestration file
├── config/
│   ├── clickhouse/
│   │   ├── clickhouse-config.xml        # ClickHouse server config
│   │   └── clickhouse-users.xml         # User credentials
│   ├── otel-collector/
│   │   └── otel-collector-config.yaml   # OTEL pipeline config
│   └── query-service/
│       └── config.yaml                   # Query service config
├── docs/
│   └── security/
│       └── CONTAINER_POLICY_EXCEPTIONS.md  # Policy exception documentation
└── README.md                             # This file
```

## Deployment Instructions

### Prerequisites
- Podman installed and running
- All 4 SigNoz images imported to localhost/ registry (verified ✅)
- PostgreSQL 17 available on port 5433 (for application integration)

### Quick Start

```bash
# Navigate to deployment directory
cd /home/an/dev/indrajaal-demo/containers/signoz

# Start all services using simplified script
./start-signoz-simple.sh

# Check comprehensive status
./status.sh

# Verify deployment health
./verify-deployment.sh
```

### Alternative: Manual Container Management

```bash
# Start all services via Podman Compose
podman-compose up -d

# Check status
podman ps -a | grep signoz

# View logs for all services
./monitor-all.sh
```

### Verify Deployment

Use the comprehensive verification script:

```bash
# Automated verification (recommended)
./verify-deployment.sh

# Manual verification steps
./status.sh

# Access Frontend UI
# Open browser: http://localhost:3301
```

### Stop the Stack

```bash
# Graceful shutdown using script
./stop-signoz.sh

# Alternative: Stop via Podman Compose
podman-compose down

# Stop and remove volumes (WARNING: deletes all data)
podman-compose down -v
```

## Network Architecture

All services communicate via the `signoz-network` bridge network:

```
┌─────────────────────────────────────────────────────────┐
│                    signoz-network                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │  Frontend    │───▶│ Query Service│                   │
│  │  :3301       │    │  :8080       │                   │
│  └──────────────┘    └───────┬──────┘                   │
│                              │                           │
│                              ▼                           │
│  ┌──────────────┐    ┌──────────────┐                   │
│  │OTEL Collector│───▶│  ClickHouse  │                   │
│  │:4317,:4318   │    │ :9000,:8123  │                   │
│  └──────────────┘    └──────────────┘                   │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Service Dependencies

The services start in the following order (enforced by health checks):

1. **ClickHouse** - Database must be healthy first
2. **OTEL Collector** - Depends on ClickHouse
3. **Query Service** - Depends on ClickHouse and OTEL Collector
4. **Frontend** - Depends on Query Service

## Data Persistence

All data is stored in Docker/Podman volumes:

- `signoz-clickhouse-data`: Metrics, traces, and logs
- `signoz-query-service-data`: Query cache and metadata
- `signoz-otel-collector-data`: Collector state and buffers

### Backup Volumes

```bash
# Backup ClickHouse data
podman run --rm -v signoz-clickhouse-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/clickhouse-backup-$(date +%Y%m%d).tar.gz /data

# Restore from backup
podman run --rm -v signoz-clickhouse-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/clickhouse-backup-YYYYMMDD.tar.gz -C /
```

## Port Mapping

| Service | Internal Port | External Port | Purpose |
|---------|--------------|---------------|---------|
| ClickHouse | 9000 | 9000 | Native protocol |
| ClickHouse | 8123 | 8123 | HTTP interface |
| OTEL Collector | 4317 | 4317 | OTLP gRPC receiver |
| OTEL Collector | 4318 | 4318 | OTLP HTTP receiver |
| OTEL Collector | 8888 | 8888 | Prometheus metrics |
| OTEL Collector | 13133 | 13133 | Health check |
| Query Service | 8080 | 8080 | HTTP API |
| Frontend | 3301 | 3301 | Web UI |

## Health Checks

All services include health checks with the following parameters:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3 attempts
- **Start Period**: 30-40 seconds

### Manual Health Checks

```bash
# ClickHouse
podman exec signoz-clickhouse clickhouse-client --query "SELECT 1"

# OTEL Collector
curl http://localhost:13133/

# Query Service
curl http://localhost:8080/api/v1/health

# Frontend
curl http://localhost:3301/
```

## Resource Limits

Resource limits are configured per STAMP safety constraints:

| Service | CPU Limit | Memory Limit | CPU Reserve | Memory Reserve |
|---------|-----------|--------------|-------------|----------------|
| ClickHouse | 2.0 cores | 2GB | 1.0 cores | 1GB |
| OTEL Collector | 1.0 cores | 1GB | 0.5 cores | 512MB |
| Query Service | 1.0 cores | 1GB | 0.5 cores | 512MB |
| Frontend | 0.5 cores | 512MB | 0.25 cores | 256MB |

**Total**: 4.5 CPU cores, 4.5GB RAM

## Operational Scripts

The deployment includes 10 comprehensive operational scripts for streamlined management:

### Core Management Scripts

1. **start-signoz-simple.sh** - Complete stack startup with network/volume creation
2. **stop-signoz.sh** - Graceful shutdown with proper dependency order
3. **status.sh** - Comprehensive system status and health checks
4. **clickhouse-setup.sh** - Database schema initialization

### Monitoring and Testing Scripts

5. **verify-deployment.sh** - Automated health validation (CI/CD ready)
6. **monitor-all.sh** - Real-time log monitoring for all containers
7. **send_test_trace.sh** - OTLP trace testing and validation

### Data Management Scripts

8. **backup-data.sh** - Complete data and configuration backup
9. **reset-data.sh** - Clear all telemetry data (with confirmation)

See [SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md) for detailed documentation of all scripts.

## Troubleshooting

### Quick Diagnostics

```bash
# Run comprehensive status check
./status.sh

# Run automated verification
./verify-deployment.sh

# Monitor all containers in real-time
./monitor-all.sh
```

### Container Won't Start

```bash
# Check container logs
podman logs signoz-<service-name>

# Check container status
podman inspect signoz-<service-name>

# Verify image exists
podman images | grep signoz

# Restart specific container
podman restart signoz-<service-name>
```

### Health Check Failing

```bash
# Check health status
podman inspect --format='{{.State.Health.Status}}' signoz-<service-name>

# View health check logs
podman inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' signoz-<service-name>

# Manual health check
curl http://localhost:13133/  # OTEL Collector
curl http://localhost:8081/api/v1/health  # Query Service
```

### Inter-Container Connectivity Issues

```bash
# Check network
podman network inspect signoz-network

# Test connectivity
podman exec signoz-frontend ping -c 3 query-service
podman exec signoz-query-service ping -c 3 clickhouse

# Verify network DNS
podman exec signoz-otel-collector nslookup clickhouse
```

### Data Persistence Issues

```bash
# List volumes
podman volume ls | grep signoz

# Inspect volume
podman volume inspect signoz-clickhouse-data

# Check volume mount
podman inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' signoz-clickhouse

# Backup data before investigating
./backup-data.sh troubleshooting-backup
```

### Common Issues and Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| OTEL Collector unhealthy | Health check timeout | Wait 30-60s for startup, check logs |
| Query Service crashes | Container restarts | Verify ClickHouse is healthy first |
| No data in Frontend | Empty dashboards | Run `./send_test_trace.sh` to verify ingestion |
| High memory usage | Container OOM | Check resource limits, review data retention |

## Security Considerations

### Policy Compliance
- ✅ All images from localhost/ registry (EXC-001 compliant)
- ✅ No external registry references
- ✅ Version pinning prevents supply chain drift
- ✅ Complete audit trail in `./data/tmp/signoz-pull-audit-corrected-20251117.log`

### Network Security
- All services communicate via private bridge network
- Only necessary ports exposed to host
- No container runs as root (rootless Podman)

### Credential Management
- ClickHouse credentials in configuration files (development only)
- **Production**: Use secrets management (Podman secrets, Vault, etc.)

### Recommendations for Production
1. Use Podman secrets for credentials
2. Enable TLS/SSL for all services
3. Implement network policies
4. Regular security updates
5. Backup automation
6. Monitoring and alerting

## Production Deployment

### Phase 5 Complete - Production Ready ✅

The SigNoz observability stack is fully operational and production-ready:

1. ✅ **All 4 containers deployed** - ClickHouse, OTEL Collector, Query Service, Frontend
2. ✅ **Health monitoring active** - Automated health checks with 30-second intervals
3. ✅ **Data persistence configured** - 3 persistent volumes with backup capability
4. ✅ **Network isolation** - Private bridge network for inter-container communication
5. ✅ **Resource limits enforced** - 4.5 CPU cores, 4.5GB RAM total allocation
6. ✅ **Operational scripts** - 10 management scripts for daily operations
7. ✅ **SOPv5.11 compliant** - Integrated with cybernetic framework and STAMP safety

### Integration with Elixir/Phoenix Applications

See the [Comprehensive Logging & Observability Guide](LOGGING_OBSERVABILITY_COMPREHENSIVE_GUIDE.md) for:
- OpenTelemetry SDK setup
- Automatic Phoenix instrumentation
- Custom span creation
- Distributed tracing configuration
- Query examples and dashboard setup

### Operational Tasks

**Daily Operations:**
```bash
./status.sh                    # Check system health
./monitor-all.sh              # View live logs
./send_test_trace.sh my-app   # Test telemetry ingestion
```

**Maintenance:**
```bash
./backup-data.sh weekly-backup  # Create backup
./verify-deployment.sh          # Run health checks
./reset-data.sh                # Clear test data (with confirmation)
```

### Future Enhancements

Planned improvements for Phase 6 and beyond:
1. Alerting rules and notification channels
2. Custom dashboard templates
3. Automated data retention policies
4. High availability configuration
5. Multi-tenant deployment support

## References

### Documentation

- **[Comprehensive Logging & Observability Guide](LOGGING_OBSERVABILITY_COMPREHENSIVE_GUIDE.md)** - Complete system documentation
- **[Deployment Guide](DEPLOYMENT_GUIDE.md)** - Full operational procedures (if available)
- **[Scripts Reference](SCRIPTS_REFERENCE.md)** - All operational scripts documentation
- **[Deployment Status](DEPLOYMENT_STATUS.md)** - Current system state
- **[Documentation Summary](DOCUMENTATION_UPDATE_SUMMARY.md)** - Task completion record

### Policy and Compliance

- **Policy Exception**: `docs/security/CONTAINER_POLICY_EXCEPTIONS.md`
- **Container Policy**: `CONTAINER_POLICY.md` (project root)
- **Audit Log**: `./data/tmp/signoz-pull-audit-corrected-20251117.log`

### External Resources

- **SigNoz Documentation**: https://signoz.io/docs/
- **OpenTelemetry Specification**: https://opentelemetry.io/docs/
- **ClickHouse Documentation**: https://clickhouse.com/docs/

## Support

### Quick Help

```bash
# System status and diagnostics
./status.sh

# Automated troubleshooting
./verify-deployment.sh

# View all logs
./monitor-all.sh
```

### Issue Categories

For issues related to:
- **Deployment**: Use operational scripts (`./start-signoz-simple.sh`, `./status.sh`)
- **Health checks**: Run `./verify-deployment.sh` for automated validation
- **Data issues**: Check ClickHouse with `podman exec signoz-clickhouse clickhouse-client`
- **Performance**: Review resource limits and adjust in configuration
- **Policy compliance**: Review EXC-001 documentation and localhost/ registry requirements
- **Integration**: See [Comprehensive Logging & Observability Guide](LOGGING_OBSERVABILITY_COMPREHENSIVE_GUIDE.md)

### Getting Help

1. **Check operational scripts** - Most common tasks have dedicated scripts
2. **Review comprehensive guide** - Detailed documentation with examples
3. **Run verification** - `./verify-deployment.sh` for automated health checks
4. **Check logs** - `./monitor-all.sh` for real-time log monitoring

---

**Last Updated**: 2025-11-23 14:30:00 CEST
**Status**: ✅ Production Ready - Phase 5 Complete
**Version**: 1.2.0
