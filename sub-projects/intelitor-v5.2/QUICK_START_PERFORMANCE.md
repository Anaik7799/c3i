# 🚀 Quick Start: LXC Performance Testing

This guide gets you up and running with the Indrajaal LXC performance testing environment in under 30 minutes.

## ⚡ Prerequisites Check

Ensure your system meets the requirements:

```bash
# Check available resources
free -h    # Need 32GB+ RAM
nproc      # Need 16+ CPU cores
df -h      # Need 200GB+ disk space

# Verify Nix is installed
nix --version

# Verify LXD is available (will be installed if missing)
which lxc || echo "LXD will be installed automatically"
```

## 🏁 Step-by-Step Setup

### 1. Enter Performance Environment

```bash
# Navigate to project directory
cd /path/to/indrajaal

# Enter the performance testing devenv
devenv shell -f devenv-performance.nix
```

You should see a welcome message with available commands.

### 2. Validate Configuration

```bash
# Run comprehensive validation
./scripts/performance/validate_lxc_configs.sh
```

Fix any issues identified before proceeding.

### 3. Setup LXC Containers

```bash
# Create all 6 containers with NixOS (15-30 minutes)
lxc-setup

# Check setup progress
lxc-status
```

### 4. Setup Indrajaal Application

```bash
# Setup application with performance test data (5-10 minutes)
perf-setup

# Deploy application to containers (2-5 minutes)
deploy-app

# Setup production databases (1-2 minutes)
db-setup
```

### 5. Verify Environment

```bash
# Run quick environment tests
./scripts/performance/test_environment.exs --quick

# Run comprehensive health check
health-check
```

### 6. Run Your First Performance Test

```bash
# Start monitoring dashboard in background
perf-monitor &

# Run baseline performance test (5-10 minutes)
perf-baseline

# View results in Grafana: http://10.200.0.30:3000
```

## 🎯 Quick Test Commands

Once setup is complete, use these commands for testing:

### Basic Performance Tests
```bash
perf-baseline    # Establish performance baseline
perf-load        # Standard load testing
perf-stress      # Stress testing
```

### Load Testing Tools
```bash
artillery-test   # HTTP load testing with Artillery
wrk-test        # HTTP benchmarking with wrk
elixir-load     # Custom Elixir load testing
```

### Monitoring
```bash
perf-monitor     # Local monitoring dashboard
lxc-status       # Container status and resources
health-check     # Comprehensive health verification
```

## 📊 Access Points

After setup, access these services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://10.200.0.30:3000 | admin/perftest123 |
| **Prometheus** | http://10.200.0.30:9090 | none |
| **Primary App** | http://10.200.0.10:4000 | none |
| **Secondary App** | http://10.200.0.11:4010 | none |
| **MinIO** | http://10.200.0.40:9000 | admin/perftest123 |

## 🧪 Example Test Session

Here's a complete example testing session:

```bash
# 1. Enter environment
devenv shell -f devenv-performance.nix

# 2. Validate (first time only)
./scripts/performance/validate_lxc_configs.sh

# 3. Setup containers (first time only - 20-30 min)
lxc-setup

# 4. Setup application (first time only - 10 min)
perf-setup
deploy-app
db-setup

# 5. Verify everything is working
health-check

# 6. Start monitoring
perf-monitor &

# 7. Run baseline test
perf-baseline

# 8. Run load test
perf-load

# 9. Analyze results in Grafana
# Visit: http://10.200.0.30:3000

# 10. Collect logs for analysis
collect-logs
```

## ⚠️ Important Notes

### Resource Usage
- **Setup time**: 30-45 minutes for initial setup
- **Running memory**: ~54GB across all containers
- **Running CPU**: ~30 cores across all containers
- **Storage**: ~300GB for all data

### Network Configuration
- Containers use network: `10.200.0.0/24`
- Host ports are forwarded to container services
- No conflicts with host services

### Default Credentials
These are for testing only - change for production:
- **Grafana**: admin/perftest123
- **MinIO**: admin/perftest123
- **PostgreSQL**: postgres (no password)

## 🚨 Troubleshooting

### Common Issues

**"Insufficient resources" error**:
```bash
# Check available resources
free -h
nproc

# Reduce container memory if needed
lxc config set indrajaal-app-primary limits.memory 8GB
```

**"Container failed to start"**:
```bash
# Check container logs
lxc info container-name
lxc exec container-name -- journalctl -n 50

# Restart container
lxc restart container-name
```

**"Network connectivity issues"**:
```bash
# Test basic connectivity
ping 10.200.0.5   # Database
ping 10.200.0.10  # Primary app

# Restart network if needed
lxc network delete perftest
lxc-setup  # Will recreate
```

**"Application not responding"**:
```bash
# Check application logs
lxc exec indrajaal-app-primary -- journalctl -f

# Redeploy application
deploy-app
```

### Getting Help

1. Run diagnostics: `health-check`
2. Collect logs: `collect-logs`
3. Check container status: `lxc-status`
4. Validate configuration: `./scripts/performance/validate_lxc_configs.sh`

## 🧹 Cleanup

When finished testing:

```bash
# Stop all containers
lxc-stop

# Remove everything (careful!)
lxc-teardown

# Clean host
rm -rf logs/containers tmp/performance
```

## 📚 Next Steps

After successful setup:

1. **Customize Tests**: Modify `scripts/performance/artillery-config.yml`
2. **Add Metrics**: Enhance `monitoring/grafana-indrajaal-dashboard.json`
3. **Scale Testing**: Increase container resources or add more containers
4. **Automate**: Integrate with CI/CD pipelines

For detailed information, see `PERFORMANCE_TESTING_README.md`.

---

🎉 **You're ready to start performance testing!** The environment provides enterprise-grade scalability testing capabilities for the Indrajaal security monitoring system.