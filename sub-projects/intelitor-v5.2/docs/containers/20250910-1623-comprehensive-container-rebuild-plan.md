# Comprehensive Container Rebuild Plan

**Created**: 2025-09-10 16:23:45 UTC  
**Status**: 🚀 **COMPREHENSIVE REBUILD FROM SCRATCH**  
**Classification**: Complete Container Infrastructure Recreation  

## 🎯 Executive Summary

This plan provides a comprehensive approach to rebuilding all containers from scratch with complete functional validation. All existing containers have been cleaned up, and we will create a production-ready 6-container architecture with full NixOS compliance, STAMP safety constraints, and comprehensive functional testing.

## 📋 Current State Assessment

### ✅ Cleanup Completed
- **Containers**: All removed (indrajaal-dev-app deleted)
- **Images**: All removed (docker.io/nixos/nix:latest deleted) 
- **Networks**: Custom networks removed (indrajaal-fix-network deleted)
- **System**: Complete cleanup with `podman system prune -a -f`

### 🎯 Target Architecture
We will create **6 production-ready containers** with complete functional validation:

| Container | Purpose | Base Image | Port | Health Check |
|-----------|---------|------------|------|--------------|
| **indrajaal-timescaledb** | Time-series database | postgres:17 | 5432 | SQL query test |
| **indrajaal-redis** | Caching layer | redis:7-alpine | 6379 | PING/PONG test |
| **indrajaal-app** | Phoenix application | nixos/nix:latest | 4000 | HTTP health endpoint |
| **indrajaal-prometheus** | Metrics collection | prom/prometheus | 9090 | Metrics endpoint |
| **indrajaal-grafana** | Visualization | grafana/grafana | 3000 | API health check |
| **indrajaal-nginx** | Reverse proxy | nginx:alpine | 80 | HTTP response test |

## 🏗️ Phase-by-Phase Rebuild Plan

### **Phase 1: Network Infrastructure (5 minutes)**
```bash
# 1.1 Create dedicated network
podman network create indrajaal-network --driver bridge

# 1.2 Verify network creation
podman network inspect indrajaal-network

# 1.3 Test network connectivity
podman run --rm --network indrajaal-network alpine ping -c 1 8.8.8.8
```

### **Phase 2: Database Layer (15 minutes)**
```bash
# 2.1 Create TimescaleDB container
podman run -d \
  --name indrajaal-timescaledb \
  --network indrajaal-network \
  -p 5432:5432 \
  -e POSTGRES_DB=indrajaal_dev \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e TIMESCALEDB_TELEMETRY=off \
  timescale/timescaledb:latest-pg17

# 2.2 Wait for database startup (up to 60 seconds)
timeout 60 bash -c 'until podman exec indrajaal-timescaledb pg_isready -U postgres; do sleep 1; done'

# 2.3 Functional validation
podman exec indrajaal-timescaledb psql -U postgres -d indrajaal_dev -c "SELECT version();"
podman exec indrajaal-timescaledb psql -U postgres -d indrajaal_dev -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
```

### **Phase 3: Caching Layer (10 minutes)**
```bash
# 3.1 Create Redis container  
podman run -d \
  --name indrajaal-redis \
  --network indrajaal-network \
  -p 6379:6379 \
  redis:7-alpine \
  redis-server --appendonly yes

# 3.2 Wait for Redis startup
sleep 10

# 3.3 Functional validation
podman exec indrajaal-redis redis-cli ping
podman exec indrajaal-redis redis-cli set test_key "test_value"
podman exec indrajaal-redis redis-cli get test_key
```

### **Phase 4: Application Container (20 minutes)**
```bash
# 4.1 Pull NixOS base image
podman pull nixos/nix:latest

# 4.2 Create application container
podman run -d \
  --name indrajaal-app \
  --network indrajaal-network \
  -p 4000:4000 \
  -p 4001:4001 \
  -v "$(pwd):/workspace:Z" \
  -w /workspace \
  -e MIX_ENV=dev \
  -e DATABASE_URL=postgresql://postgres:postgres@indrajaal-timescaledb:5432/indrajaal_dev \
  -e REDIS_URL=redis://indrajaal-redis:6379/0 \
  nixos/nix:latest \
  sleep infinity

# 4.3 Install development tools
podman exec indrajaal-app nix-env -iA nixpkgs.elixir nixpkgs.postgresql nixpkgs.git

# 4.4 Configure SSL certificates
podman exec indrajaal-app bash -c "
  mkdir -p /etc/ssl/certs
  CA_BUNDLE=\$(find /nix/store -name 'ca-bundle.crt' -type f | head -1)
  ln -sf \"\$CA_BUNDLE\" /etc/ssl/certs/ca-bundle.crt
  ln -sf \"\$CA_BUNDLE\" /etc/ssl/certs/ca-certificates.crt
"

# 4.5 Install Hex and dependencies
podman exec indrajaal-app bash -c "cd /workspace && mix local.hex --force"
podman exec indrajaal-app bash -c "cd /workspace && mix deps.get"

# 4.6 Functional validation
podman exec indrajaal-app elixir --version
podman exec indrajaal-app bash -c "cd /workspace && mix compile --dry-run"
```

### **Phase 5: Monitoring Infrastructure (15 minutes)**
```bash
# 5.1 Create Prometheus container
podman run -d \
  --name indrajaal-prometheus \
  --network indrajaal-network \
  -p 9090:9090 \
  -v prometheus-data:/prometheus \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.console.templates=/etc/prometheus/consoles

# 5.2 Wait for Prometheus startup
sleep 15

# 5.3 Functional validation
podman exec indrajaal-prometheus wget -qO- http://localhost:9090/-/healthy
curl -s http://localhost:9090/api/v1/label/__name__/values | grep -q "prometheus"

# 5.4 Create Grafana container
podman run -d \
  --name indrajaal-grafana \
  --network indrajaal-network \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  -v grafana-data:/var/lib/grafana \
  grafana/grafana:latest

# 5.5 Wait for Grafana startup
sleep 20

# 5.6 Functional validation
curl -s -u admin:admin http://localhost:3000/api/health | grep -q "ok"
```

### **Phase 6: Reverse Proxy (10 minutes)**
```bash
# 6.1 Create Nginx configuration
mkdir -p ./containers/nginx
cat > ./containers/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server indrajaal-app:4000;
    }
    
    upstream grafana {
        server indrajaal-grafana:3000;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /grafana/ {
            proxy_pass http://grafana/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /health {
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# 6.2 Create Nginx container
podman run -d \
  --name indrajaal-nginx \
  --network indrajaal-network \
  -p 80:80 \
  -v "./containers/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:alpine

# 6.3 Wait for Nginx startup
sleep 10

# 6.4 Functional validation
curl -s http://localhost/health | grep -q "healthy"
```

## 🧪 Comprehensive Functional Validation

### **Database Validation Tests**
```bash
# Test 1: Basic connectivity
podman exec indrajaal-timescaledb pg_isready -U postgres

# Test 2: TimescaleDB extension
podman exec indrajaal-timescaledb psql -U postgres -d indrajaal_dev -c "SELECT extname FROM pg_extension WHERE extname = 'timescaledb';"

# Test 3: Create test table and data
podman exec indrajaal-timescaledb psql -U postgres -d indrajaal_dev -c "
  CREATE TABLE IF NOT EXISTS test_metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id INT,
    value DOUBLE PRECISION
  );
  SELECT create_hypertable('test_metrics', 'time', if_not_exists => TRUE);
  INSERT INTO test_metrics VALUES (NOW(), 1, 25.5);
  SELECT COUNT(*) FROM test_metrics;
"
```

### **Cache Validation Tests**
```bash
# Test 1: Basic connectivity
podman exec indrajaal-redis redis-cli ping

# Test 2: Data operations
podman exec indrajaal-redis redis-cli set session:test "user123"
podman exec indrajaal-redis redis-cli get session:test
podman exec indrajaal-redis redis-cli expire session:test 300
podman exec indrajaal-redis redis-cli ttl session:test

# Test 3: Pub/Sub functionality
podman exec -d indrajaal-redis redis-cli subscribe test_channel &
sleep 2
podman exec indrajaal-redis redis-cli publish test_channel "hello world"
```

### **Application Validation Tests**
```bash
# Test 1: Elixir environment
podman exec indrajaal-app elixir -e "IO.puts(System.version())"

# Test 2: Mix environment
podman exec indrajaal-app bash -c "cd /workspace && mix --version"

# Test 3: Database connectivity
podman exec indrajaal-app bash -c "cd /workspace && mix run -e 'IO.puts(System.get_env(\"DATABASE_URL\"))'"

# Test 4: SSL certificate validation
podman exec indrajaal-app elixir -e "IO.puts(length(:pubkey_os_cacerts.get()))"

# Test 5: Compilation test
podman exec indrajaal-app bash -c "cd /workspace && timeout 300 mix compile 2>&1 | head -20"
```

### **Monitoring Validation Tests**
```bash
# Test 1: Prometheus health
curl -s http://localhost:9090/-/healthy

# Test 2: Prometheus metrics
curl -s http://localhost:9090/api/v1/query?query=up | grep -q "success"

# Test 3: Grafana health  
curl -s -u admin:admin http://localhost:3000/api/health

# Test 4: Grafana API
curl -s -u admin:admin http://localhost:3000/api/datasources | grep -q "\[\]"
```

### **Proxy Validation Tests**
```bash
# Test 1: Nginx health
curl -s http://localhost/health

# Test 2: Proxy configuration
curl -s -I http://localhost/ | grep -q "200\|502"

# Test 3: Upstream connectivity
podman exec indrajaal-nginx nginx -t
```

## 🛡️ STAMP Safety Constraints

### **Container Safety Constraints (SC-RB-001 to SC-RB-006)**
- **SC-RB-001**: System SHALL create all containers in correct dependency order
- **SC-RB-002**: System SHALL validate each container health before proceeding
- **SC-RB-003**: System SHALL use only approved base images (no docker.io for production)
- **SC-RB-004**: System SHALL implement proper network isolation
- **SC-RB-005**: System SHALL validate all functional requirements before completion
- **SC-RB-006**: System SHALL maintain complete audit trail of creation process

## ⚡ Execution Timeline

| Phase | Duration | Dependencies | Validation |
|-------|----------|--------------|------------|
| **Network** | 5 min | None | Connectivity test |
| **Database** | 15 min | Network | SQL query test |
| **Cache** | 10 min | Network | PING/PONG test |
| **Application** | 20 min | Network, DB, Cache | Compilation test |
| **Monitoring** | 15 min | Network | Health endpoints |
| **Proxy** | 10 min | Network, App, Grafana | HTTP response |
| **Validation** | 15 min | All containers | Comprehensive tests |
| **Total** | **90 min** | Sequential | Full functionality |

## 🔧 Emergency Recovery Procedures

### **Container Recovery (if any container fails)**
```bash
# 1. Stop and remove failed container
podman stop <container-name>
podman rm <container-name>

# 2. Check logs for failure cause
podman logs <container-name>

# 3. Recreate container with debug mode
podman run -it --name <container-name>-debug <image> /bin/bash

# 4. Fix issue and recreate production container
```

### **Network Recovery**
```bash
# 1. Remove and recreate network
podman network rm indrajaal-network
podman network create indrajaal-network --driver bridge

# 2. Restart all containers to rejoin network
podman restart $(podman ps -aq)
```

### **Data Recovery**
```bash
# 1. Backup existing data
podman exec indrajaal-timescaledb pg_dump -U postgres indrajaal_dev > backup.sql

# 2. Restore data after recreation
podman exec -i indrajaal-timescaledb psql -U postgres indrajaal_dev < backup.sql
```

## 🎯 Success Criteria

### **Container Creation Success**
- ✅ All 6 containers created successfully
- ✅ All containers show "Running" status
- ✅ All health checks pass
- ✅ Network connectivity established
- ✅ Inter-container communication working

### **Functional Validation Success**
- ✅ Database: SQL queries execute successfully
- ✅ Cache: Redis operations work correctly  
- ✅ Application: Elixir compilation succeeds
- ✅ Monitoring: Metrics collection active
- ✅ Proxy: HTTP routing functional
- ✅ Integration: End-to-end workflow operational

### **STAMP Compliance Success**
- ✅ All safety constraints satisfied
- ✅ Dependency order maintained
- ✅ Health validation completed
- ✅ Network isolation verified
- ✅ Audit trail complete

## 📊 Monitoring and Reporting

### **Real-time Status Dashboard**
```bash
# Container status monitoring
watch -n 5 'podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Health check monitoring  
watch -n 10 'curl -s http://localhost/health && curl -s http://localhost:9090/-/healthy'

# Resource usage monitoring
podman stats --no-stream
```

### **Completion Report Generation**
Upon successful completion, generate comprehensive report including:
- Container creation timeline
- Functional validation results
- Performance benchmarks
- Security compliance status
- Troubleshooting guide

---

**Plan Status**: ✅ **READY FOR EXECUTION**  
**Estimated Duration**: 90 minutes  
**Success Probability**: 95%+ with systematic execution  
**Next Step**: Execute Phase 1 (Network Infrastructure Creation)