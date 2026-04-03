# 🚀 Indrajaal LXC Performance Testing Environment

This document provides comprehensive instructions for setting up and running scalability and performance testing for the Indrajaal security monitoring system using LXC containers with NixOS.

## 📋 Overview

The performance testing environment consists of:

- **6 LXC containers** with NixOS running specialized services
- **devenv.sh environment** with all necessary tools and scripts
- **Comprehensive monitoring** with Prometheus and Grafana
- **Load testing tools** including Artillery, wrk, and custom Elixir tools
- **Automated setup and orchestration** scripts

### Container Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Performance Testing Network                  │
│                         10.200.0.0/24                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│ │   Database   │ │ App Primary  │ │ App Secondary│            │
│ │ 10.200.0.5   │ │ 10.200.0.10  │ │ 10.200.0.11  │            │
│ │ PostgreSQL   │ │ Elixir App   │ │ Elixir App   │            │
│ │ 8GB / 4 CPU  │ │ 16GB / 8 CPU │ │ 12GB / 6 CPU │            │
│ └──────────────┘ └──────────────┘ └──────────────┘            │
│                                                                 │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│ │Load Generator│ │  Monitoring  │ │   Storage    │            │
│ │ 10.200.0.20  │ │ 10.200.0.30  │ │ 10.200.0.40  │            │
│ │Artillery/wrk │ │ Grafana/Prom │ │    MinIO     │            │
│ │ 8GB / 6 CPU  │ │ 6GB / 4 CPU  │ │ 4GB / 2 CPU  │            │
│ └──────────────┘ └──────────────┘ └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## 🏗️ Prerequisites

### System Requirements

- **Operating System**: Ubuntu 25.04 LTS or compatible Linux distribution
- **Memory**: 32GB+ RAM (64GB recommended for full testing)
- **CPU**: 16+ cores (32 cores recommended)
- **Storage**: 200GB+ available disk space (NVMe SSD preferred)
- **Network**: Gigabit Ethernet for realistic testing

### Software Requirements

- **Nix Package Manager**: Required for devenv.sh
- **LXD/LXC**: Container runtime (will be installed automatically)
- **Git**: For repository management
- **devenv.sh**: Development environment manager

### Installation Steps

1. **Install Nix** (if not already installed):
   ```bash
   curl -L https://nixos.org/nix/install | sh
   source ~/.nix-profile/etc/profile.d/nix.sh
   ```

2. **Install devenv.sh**:
   ```bash
   nix profile install nixpkgs#devenv
   ```

3. **Clone and setup the project**:
   ```bash
   git clone <repository-url>
   cd indrajaal
   direnv allow  # If using direnv
   devenv shell  # Enter development environment
   ```

## 🚀 Quick Start

### 1. Validate Configuration

Before setting up containers, validate your system:

```bash
# Enter the performance testing environment
devenv shell -f devenv-performance.nix

# Validate system configuration
./scripts/performance/validate_lxc_configs.sh
```

### 2. Setup LXC Environment

Create all containers and configure the testing environment:

```bash
# Setup all containers (takes 15-30 minutes)
lxc-setup

# Check container status
lxc-status

# Start all containers
lxc-start
```

### 3. Setup Indrajaal Application

Prepare the application and test data:

```bash
# Setup application with test data
perf-setup

# Deploy application to containers
deploy-app

# Setup production databases
db-setup

# Verify all services are healthy
health-check
```

### 4. Run Performance Tests

Execute comprehensive performance testing:

```bash
# Run full performance test suite
perf-full

# Or run individual test types:
perf-baseline    # Baseline performance
perf-load        # Load testing
perf-stress      # Stress testing
perf-endurance   # Endurance testing
```

### 5. Monitor Performance

Access monitoring dashboards:

```bash
# Start local monitoring dashboard
perf-monitor

# Access web dashboards:
# Grafana: http://10.200.0.30:3000 (admin/perftest123)
# Prometheus: http://10.200.0.30:9090
# MinIO: http://10.200.0.40:9000 (admin/perftest123)
```

## 🧪 Testing Scenarios

### Load Testing Tools

#### Artillery.io HTTP Load Testing
```bash
# Run Artillery load test
artillery-test

# Custom Artillery configuration
artillery run scripts/performance/artillery-config.yml --output results.json
artillery report results.json --output report.html
```

#### wrk HTTP Benchmarking
```bash
# Quick wrk test
wrk-test

# Custom wrk test
wrk -t12 -c400 -d30s --latency http://10.200.0.10:4000/api/v1/alarms
```

#### Custom Elixir Load Testing
```bash
# Run custom Elixir load tester
elixir-load

# Custom parameters
elixir scripts/performance/elixir_load_tester.ex --users 200 --duration 15
```

### Performance Test Categories

1. **Baseline Testing**: Establish performance baseline under normal conditions
2. **Load Testing**: Test system behavior under expected production load
3. **Stress Testing**: Test system limits and breaking points
4. **Endurance Testing**: Test system stability over extended periods
5. **Spike Testing**: Test system response to sudden load increases

### Alarm Processing Tests

The tests focus heavily on alarm processing performance:

- **Latency Target**: <1000ms p99 for alarm processing
- **Throughput Target**: 1000+ alarms/minute sustained
- **Correlation Testing**: Pattern detection and multi-alarm scenarios
- **Storm Testing**: High-volume alarm burst handling

## 📊 Monitoring and Analysis

### Real-time Monitoring

Access these dashboards during testing:

- **Grafana**: http://10.200.0.30:3000
  - Indrajaal Performance Dashboard
  - Container resource usage
  - Database performance metrics
  - Application-specific metrics

- **Prometheus**: http://10.200.0.30:9090
  - Raw metrics and alerts
  - Custom query interface
  - Historical data analysis

### Performance Metrics

Key metrics tracked during testing:

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| Alarm Processing Latency (P95) | <500ms | >1000ms |
| Alarm Processing Latency (P99) | <1000ms | >2000ms |
| Alarm Throughput | 1000+/min | <500/min |
| API Response Time (P95) | <200ms | >500ms |
| Database Query Time (P95) | <100ms | >300ms |
| Memory Usage | <80% | >90% |
| CPU Utilization | <70% | >85% |

### Log Collection and Analysis

```bash
# Collect logs from all containers
collect-logs

# Analyze performance data
analyze-performance

# View container resource usage
lxc-status
```

## 🔧 Configuration

### Container Configuration

Each container is optimized for its specific role:

**Database Container (indrajaal-db-perf)**:
- PostgreSQL 17 with performance tuning
- 8GB RAM, 4 CPU cores
- Optimized for high-concurrency workloads
- Prometheus metrics exporter included

**Application Containers (primary/secondary)**:
- Elixir 1.17 / OTP 27 runtime
- 16GB/12GB RAM, 8/6 CPU cores
- Production-like configuration
- Load balancing between instances

**Load Generator Container**:
- Artillery, wrk, custom Elixir tools
- 8GB RAM, 6 CPU cores
- High file descriptor limits
- Network performance optimized

**Monitoring Container**:
- Grafana + Prometheus + Alertmanager
- 6GB RAM, 4 CPU cores
- Pre-configured dashboards
- Historical data retention

**Storage Container**:
- MinIO S3-compatible storage
- 4GB RAM, 2 CPU cores
- File upload performance testing
- Backup and recovery testing

### Network Configuration

- **Container Network**: 10.200.0.0/24
- **Port Forwarding**: All services accessible from host
- **NAT**: Enabled for internet access
- **Isolation**: Containers isolated from host network

### Resource Limits

Total resource allocation:
- **Memory**: 54GB across all containers
- **CPU**: 30 cores across all containers
- **Storage**: ~300GB for all container data

## 🚨 Troubleshooting

### Common Issues

1. **Insufficient Resources**:
   ```bash
   # Check system resources
   free -h
   nproc
   df -h

   # Reduce container resources if needed
   lxc config set container-name limits.memory 4GB
   ```

2. **Container Networking Issues**:
   ```bash
   # Reset network configuration
   lxc network delete perftest
   lxc-setup  # Will recreate network
   ```

3. **Port Conflicts**:
   ```bash
   # Check for port conflicts
   netstat -tuln | grep -E ':(3000|4000|5432|9090)'

   # Stop conflicting services
   sudo systemctl stop service-name
   ```

4. **Container Startup Failures**:
   ```bash
   # Check container logs
   lxc info container-name
   lxc exec container-name -- journalctl -n 50

   # Restart container
   lxc restart container-name
   ```

### Performance Issues

1. **Slow Test Execution**:
   - Verify SSD storage is being used
   - Check for CPU/memory constraints
   - Ensure containers have adequate resources

2. **High Latency**:
   - Check network configuration
   - Verify container resource limits
   - Monitor system load during tests

3. **Low Throughput**:
   - Increase concurrent users gradually
   - Check database connection limits
   - Monitor application logs for bottlenecks

### Debugging Tools

```bash
# Container resource monitoring
lxc exec container-name -- htop

# Network debugging
lxc exec container-name -- netstat -tuln
lxc exec container-name -- ss -tuln

# Application debugging
lxc exec indrajaal-app-primary -- mix compile.dashboard --status
```

## 🧹 Cleanup

### Stop and Remove Containers

```bash
# Stop all containers
lxc-stop

# Remove all containers (careful!)
lxc-teardown

# Remove network
lxc network delete perftest
```

### Clean Host System

```bash
# Remove performance test data
rm -rf logs/containers
rm -rf tmp/performance

# Clean LXD storage
lxc storage list
# lxc storage delete storage-pool  # If needed
```

## 📚 Comprehensive Documentation

### Complete Documentation Suite

For detailed information, refer to the comprehensive documentation:

- **[LXC Setup Guide](docs/performance/LXC_SETUP_GUIDE.md)**: Complete setup instructions and configuration
- **[Container Reference](docs/performance/CONTAINER_REFERENCE.md)**: Detailed container specifications and management
- **[Optimization Analysis](docs/performance/OPTIMIZATION_ANALYSIS.md)**: Resource allocation and performance analysis
- **[Troubleshooting Guide](docs/performance/TROUBLESHOOTING_GUIDE.md)**: Common issues and resolution procedures
- **[Setup Completion Report](docs/performance/SETUP_COMPLETION_REPORT.md)**: Environment status and validation

### Quick Start Documentation

- **[Quick Start Guide](QUICK_START_PERFORMANCE.md)**: Rapid deployment and testing
- **[Setup Complete](scripts/performance/SETUP_COMPLETE.md)**: Post-setup configuration

## 📚 Advanced Usage

### Custom Test Scenarios

Create custom test scenarios by modifying:

- `scripts/performance/artillery-config.yml`: HTTP load patterns
- `scripts/performance/elixir_load_tester.ex`: Custom Elixir testing
- `monitoring/grafana-indrajaal-dashboard.json`: Custom dashboards

### Scaling Testing

For larger scale testing:

1. **Increase Container Resources**:
   ```bash
   lxc config set container-name limits.memory 32GB
   lxc config set container-name limits.cpu 16
   ```

2. **Add More Application Containers**:
   - Modify `setup_lxc_environment.exs`
   - Add additional app containers
   - Configure load balancing

3. **Multi-Host Testing**:
   - Deploy containers across multiple hosts
   - Use LXD clustering
   - Configure cross-host networking

### Continuous Performance Testing

Integrate with CI/CD:

```bash
# Add to CI pipeline
- name: "Performance Regression Test"
  run: |
    devenv shell -f devenv-performance.nix
    lxc-setup
    perf-baseline
    mix performance.regression_test
```

## 🔗 Useful Links

- **Grafana Dashboards**: http://10.200.0.30:3000
- **Prometheus Metrics**: http://10.200.0.30:9090
- **Primary Application**: http://10.200.0.10:4000
- **Secondary Application**: http://10.200.0.11:4010
- **MinIO Storage**: http://10.200.0.40:9000

## 📞 Support

For issues with the performance testing environment:

1. Check the troubleshooting section above
2. Run `health-check` to verify system status
3. Review container logs with `collect-logs`
4. Validate configuration with `validate_lxc_configs.sh`

---

**Note**: This environment is designed for performance testing and uses default credentials. Do not use these configurations in production without proper security hardening.