# 🚀 Next Steps Guide - LXC Performance Environment

**Current Status**: Infrastructure Complete, Service Installation Ready
**Estimated Time to Full Operation**: 2-4 hours
**Last Updated**: August 4, 2025, 9:30 AM CEST

## 🎯 Current Achievement Summary

### ✅ COMPLETED SUCCESSFULLY
1. **Complete LXC Infrastructure**: 6 optimized containers running (30GB RAM, 12 CPU cores)
2. **Network Architecture**: Dedicated performance testing network operational
3. **Management Automation**: Full setup, monitoring, and status scripts
4. **Comprehensive Documentation**: 8 detailed guides covering all aspects
5. **Validation Testing**: Infrastructure performance validated and optimized

### ⏳ IMMEDIATE NEXT STEPS

## Step 1: Check Container Readiness (5-10 minutes)

The NixOS containers should now be ready or very close to ready for service installation.

```bash
# Check if containers are ready
elixir scripts/performance/monitor_container_readiness.exs --check

# If not all ready, monitor until ready
elixir scripts/performance/monitor_container_readiness.exs --monitor

# Alternative: Wait for all to be ready
elixir scripts/performance/monitor_container_readiness.exs --wait --timeout 600
```

## Step 2: Install Core Services (30-45 minutes)

Once containers are ready, install essential services:

```bash
# Install all services automatically
elixir scripts/performance/install_services.exs --install

# Or install services individually if issues arise
elixir scripts/performance/install_services.exs --install --container indrajaal-db-perf
elixir scripts/performance/install_services.exs --install --container indrajaal-app-primary
# ... continue for each container

# Verify installation success
elixir scripts/performance/install_services.exs --test
```

**Expected Services After Installation**:
- ✅ PostgreSQL 17 in database container
- ✅ Elixir 1.19.1/OTP 27 in application containers
- ✅ Node.js 18.x and load testing tools
- ✅ Grafana/Prometheus monitoring stack
- ✅ MinIO S3-compatible storage

## Step 3: Deploy Indrajaal Application (45-60 minutes)

Deploy the main application to containers:

```bash
# Copy application code to containers
lxc file push -r . indrajaal-app-primary/app/
lxc file push -r . indrajaal-app-secondary/app/

# Setup database
lxc exec indrajaal-db-perf -- su postgres -c "createdb indrajaal_dev"
lxc exec indrajaal-db-perf -- su postgres -c "createdb indrajaal_test"
lxc exec indrajaal-db-perf -- su postgres -c "createdb indrajaal_prod"

# Configure application
lxc exec indrajaal-app-primary -- bash
cd /app
mix deps.get
mix deps.compile
mix ecto.setup
PORT=4000 mix phx.server

# Repeat for secondary application on port 4010
```

## Step 4: Configure Monitoring (20-30 minutes)

Setup monitoring dashboards and metrics:

```bash
# Configure Grafana
lxc exec indrajaal-monitoring -- grafana-server --config /etc/grafana/grafana.ini &

# Configure Prometheus
lxc exec indrajaal-monitoring -- prometheus --config.file=/etc/prometheus.yml &

# Access monitoring
# Grafana: http://10.179.185.210:3000 (admin/admin)
# Prometheus: http://10.179.185.210:9090
```

## Step 5: Performance Testing Setup (30-45 minutes)

Prepare and execute performance tests:

```bash
# Install load testing tools
lxc exec indrajaal-load-gen -- npm install -g artillery

# Configure load testing
lxc file push scripts/performance/artillery-config.yml indrajaal-load-gen/tmp/

# Run baseline performance test
lxc exec indrajaal-load-gen -- artillery run /tmp/artillery-config.yml

# Monitor results in Grafana dashboard
```

## 🛠️ Available Tools and Scripts

### Container Management
```bash
# Status monitoring
elixir scripts/performance/setup_lxc_optimized.exs --status

# Container lifecycle
elixir scripts/performance/setup_lxc_optimized.exs --start
elixir scripts/performance/setup_lxc_optimized.exs --stop
elixir scripts/performance/setup_lxc_optimized.exs --restart

# Container readiness
elixir scripts/performance/monitor_container_readiness.exs --monitor
```

### Service Management
```bash
# Service installation
elixir scripts/performance/install_services.exs --install
elixir scripts/performance/install_services.exs --test

# Environment testing
elixir scripts/performance/test_environment.exs --quick
elixir scripts/performance/test_environment.exs --full
```

### Documentation Reference
```bash
# Complete guides available:
docs/performance/LXC_SETUP_GUIDE.md              # Setup instructions
docs/performance/CONTAINER_REFERENCE.md          # Container specifications
docs/performance/TROUBLESHOOTING_GUIDE.md        # Issue resolution
docs/performance/USAGE_EXAMPLES.md               # Daily operations
docs/performance/SERVICE_DEPLOYMENT_STRATEGY.md  # Installation strategy
```

## 🚨 Troubleshooting Quick Reference

### If Containers Still Not Ready
```bash
# Check container status
lxc list | grep indrajaal

# Restart problematic containers
lxc restart indrajaal-db-perf

# Check container logs
lxc exec indrajaal-db-perf -- journalctl -n 50

# Force container recreation if needed
lxc stop indrajaal-db-perf --force
lxc delete indrajaal-db-perf
lxc launch nixos-unstable indrajaal-db-perf
# Reconfigure resources and network
```

### If Service Installation Fails
```bash
# Check package availability
lxc exec indrajaal-db-perf -- nix search nixpkgs postgresql

# Manual package installation
lxc exec indrajaal-db-perf -- nix-env -iA nixpkgs.postgresql_15

# Alternative installation methods
lxc exec indrajaal-db-perf -- bash
# Use standard package managers if needed
```

### If Application Deployment Issues
```bash
# Check Elixir environment
lxc exec indrajaal-app-primary -- elixir --version
lxc exec indrajaal-app-primary -- mix --version

# Database connectivity test
lxc exec indrajaal-app-primary -- mix ecto.migrate --check

# Check application logs
lxc exec indrajaal-app-primary -- tail -f /app/log/dev.log
```

## 📊 Expected Performance Targets

### Infrastructure Metrics
- Container startup: < 30 seconds
- Service installation: 30-45 minutes total
- Network latency: < 2ms between containers
- Resource overhead: < 10% of allocated resources

### Application Metrics (After Deployment)
- Application startup: < 60 seconds
- Database queries: < 100ms (P95)
- API responses: < 200ms (P95)
- Concurrent users: 100+ supported

### Load Testing Targets
- Baseline test: 50 users, 5 minutes
- Load test: 100 users, 15 minutes
- Stress test: 200 users, 30 minutes
- Endurance test: 50 users, 60 minutes

## 🎯 Success Criteria

### Phase 2 Complete When:
- [ ] All containers respond to commands < 5 seconds
- [ ] PostgreSQL accessible and accepting connections
- [ ] Elixir applications can connect to database
- [ ] Monitoring dashboards accessible
- [ ] Load testing tools operational
- [ ] Basic application functionality verified

### Phase 3 Complete When:
- [ ] Indrajaal application fully deployed
- [ ] Test data generated and loaded
- [ ] End-to-end user workflows functional
- [ ] Monitoring collecting meaningful metrics
- [ ] Performance baseline established

## 🔄 Continuous Operation

### Daily Usage
```bash
# Start work session
elixir scripts/performance/setup_lxc_optimized.exs --status
elixir scripts/performance/setup_lxc_optimized.exs --start

# Run performance tests
lxc exec indrajaal-load-gen -- artillery run baseline-test.yml

# Monitor results
# Visit: http://10.179.185.210:3000 (Grafana)
```

### Maintenance
```bash
# Container health check
elixir scripts/performance/monitor_container_readiness.exs --check

# Resource monitoring
lxc list --format table -c ns4mr | grep indrajaal

# Backup important data
lxc snapshot indrajaal-db-perf backup-$(date +%Y%m%d)
```

## 📞 Support Resources

### Documentation
- **[Complete Setup Guide](docs/performance/LXC_SETUP_GUIDE.md)**
- **[Troubleshooting Guide](docs/performance/TROUBLESHOOTING_GUIDE.md)**
- **[Container Reference](docs/performance/CONTAINER_REFERENCE.md)**

### Emergency Procedures
- **Container Issues**: See Troubleshooting Guide Section 4
- **Service Problems**: See Service Deployment Strategy
- **Performance Issues**: See Optimization Analysis

### Quick Commands
```bash
# Emergency container restart
for container in $(lxc list --format csv -c n | grep indrajaal); do lxc restart $container; done

# Complete environment reset
elixir scripts/performance/setup_lxc_optimized.exs --teardown --force
# Then re-run setup process
```

## 🎉 Environment Ready Status

**Infrastructure**: ✅ 100% Complete
**Documentation**: ✅ 100% Complete
**Management Tools**: ✅ 100% Complete
**Service Installation**: ⏳ Ready to Execute
**Application Deployment**: ⏳ Pending Service Installation

**Next Action**: Check container readiness and begin service installation!

---

*This guide provides everything needed to complete the performance testing environment setup and begin comprehensive testing.*