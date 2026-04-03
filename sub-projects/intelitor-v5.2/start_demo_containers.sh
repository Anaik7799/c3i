#!/bin/bash

# 🚀 Indrajaal Demo Container Startup Script
# SOPv5.1 Compliant Container Orchestration

set -e

echo "🚀 Starting Indrajaal Demo Environment"
echo "======================================"
echo "Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container-Only + PHICS"
echo "Agent Architecture: 11-Agent Coordination Support"
echo ""

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/{postgres,redis,grafana,prometheus,nginx/logs,tmp}

# Ensure network exists
echo "🌐 Setting up container network..."
podman network exists indrajaal-app || podman network create --driver bridge --subnet 172.29.0.0/24 --gateway 172.29.0.1 indrajaal-app

# Function to check container health
check_container_health() {
    local container_name=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    echo "⏳ Waiting for $container_name to be healthy..."
    while [ $attempt -lt $max_attempts ]; do
        if podman healthcheck run $container_name 2>/dev/null | grep -q "healthy"; then
            echo "✅ $container_name is healthy"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "❌ $container_name failed to become healthy after $max_attempts attempts"
    return 1
}

# Start PostgreSQL Database (Priority 1)
echo ""
echo "🗄️ Starting PostgreSQL Database..."
if ! podman ps | grep -q indrajaal-postgres-demo; then
    podman run -d \
        --name indrajaal-postgres-demo \
        --hostname postgres-db \
        --network indrajaal-app \
        -e POSTGRES_DB=indrajaal_demo \
        -e POSTGRES_USER=postgres \
        -e POSTGRES_PASSWORD=postgres \
        -e PGPORT=5433 \
        -e POSTGRES_INITDB_ARGS="--encoding=UTF-8 --lc-collate=C --lc-ctype=C" \
        -e POSTGRES_SHARED_BUFFERS=512MB \
        -e POSTGRES_EFFECTIVE_CACHE_SIZE=1GB \
        -e POSTGRES_WORK_MEM=16MB \
        -e POSTGRES_MAINTENANCE_WORK_MEM=128MB \
        -e PHICS_ENABLED=true \
        -e NO_TIMEOUT=true \
        -e CONTAINER_OS=nixos \
        -e MAX_PARALLELIZATION=true \
        -e SOPV51_COMPLIANT=true \
        -e AGENT_COORDINATOR=app_worker \
        -e CLAUDE_LOGGING_DIR=./data/tmp \
        -p 5433:5433 \
        -v "$(pwd)/data/postgres:/var/lib/postgresql/data:z" \
        -v "$(pwd)/data/tmp:/var/log/claude:z" \
        --memory=2g \
        --cpus=2 \
        --health-cmd="pg_isready -U postgres -d indrajaal_demo -p 5433 -h localhost" \
        --health-interval=10s \
        --health-timeout=5s \
        --health-retries=5 \
        --health-start-period=30s \
        --restart=unless-stopped \
        localhost/indrajaal-postgres-demo:demo-ready
        
    sleep 10
    check_container_health indrajaal-postgres-demo
else
    echo "✅ PostgreSQL already running"
fi

# Start Redis Cache (Priority 1)
echo ""
echo "🔄 Starting Redis Cache..."
if ! podman ps | grep -q indrajaal-redis-demo; then
    podman run -d \
        --name indrajaal-redis-demo \
        --hostname redis-cache \
        --network indrajaal-app \
        -e REDIS_MAXMEMORY=1gb \
        -e REDIS_MAXMEMORY_POLICY=allkeys-lru \
        -e REDIS_SAVE="900 1 300 10 60 10000" \
        -e REDIS_APPENDONLY=yes \
        -e REDIS_APPENDFSYNC=everysec \
        -e PHICS_ENABLED=true \
        -e NO_TIMEOUT=true \
        -e CONTAINER_OS=nixos \
        -e MAX_PARALLELIZATION=true \
        -e SOPV51_COMPLIANT=true \
        -e AGENT_COORDINATOR=app_worker \
        -e CLAUDE_LOGGING_DIR=./data/tmp \
        -p 6379:6379 \
        -v "$(pwd)/data/redis:/data:z" \
        -v "$(pwd)/data/tmp:/var/log/claude:z" \
        --memory=1.5g \
        --cpus=1 \
        --health-cmd="redis-cli ping" \
        --health-interval=10s \
        --health-timeout=3s \
        --health-retries=5 \
        --health-start-period=15s \
        --restart=unless-stopped \
        localhost/indrajaal-redis-demo:demo-ready
        
    sleep 5
    check_container_health indrajaal-redis-demo
else
    echo "✅ Redis already running"
fi

# Start Elixir/Phoenix Application (Priority 2)
echo ""
echo "🚀 Starting Elixir/Phoenix Application..."
podman stop indrajaal-app-demo 2>/dev/null || true
podman rm indrajaal-app-demo 2>/dev/null || true

podman run -d \
    --name indrajaal-app-demo \
    --hostname indrajaal-app \
    --network indrajaal-app \
    -e MIX_ENV=demo \
    -e DATABASE_URL=postgres://postgres:postgres@postgres-db:5433/indrajaal_demo \
    -e REDIS_URL=redis://redis-cache:6379 \
    -e SECRET_KEY_BASE=demo_secret_key_base_64_chars_long_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
    -e PHX_HOST=localhost \
    -e PHX_PORT=4000 \
    -e PHX_SERVER=true \
    -e CONTAINER_ENFORCEMENT=true \
    -e PHICS_ENABLED=true \
    -e NO_TIMEOUT=true \
    -e CONTAINER_OS=nixos \
    -e MAX_PARALLELIZATION=true \
    -e SOPV51_COMPLIANT=true \
    -e AGENT_COORDINATOR=app_worker \
    -e CLAUDE_LOGGING_DIR=./data/tmp \
    -e ELIXIR_ERL_OPTIONS="+S 16 +A 32 +K true +P 1048576 +Q 2048576" \
    -e ERL_MAX_PORTS=262144 \
    -e ERL_MAX_ETS_TABLES=32768 \
    -e DIALYZER_PLT_PATH="/workspace/plt_files" \
    -e DIALYZER_ENABLED=true \
    -e CREDO_ENABLED=true \
    -e SOBELOW_ENABLED=true \
    -e TYPE_CHECKING_ENABLED=true \
    -e PHICS_WATCH_ENABLED=true \
    -e PHICS_RELOAD_STRATEGY=smart \
    -p 4000:4000 \
    -p 4001:4001 \
    -v "$(pwd):/workspace:z" \
    -v "$(pwd)/data/tmp:/var/log/claude:z" \
    -w /workspace \
    --memory=4g \
    --cpus=4 \
    --health-cmd="curl -f http://localhost:4000/health --max-time 5" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=60s \
    --restart=unless-stopped \
    localhost/indrajaal-app-demo:demo-ready \
    sh -c "mix deps.get && mix ecto.migrate && mix phx.server"

# Start Prometheus (Priority 3)
echo ""
echo "📊 Starting Prometheus..."
if ! podman ps | grep -q indrajaal-prometheus-demo; then
    podman run -d \
        --name indrajaal-prometheus-demo \
        --hostname prometheus-metrics \
        --network indrajaal-app \
        -e PHICS_ENABLED=true \
        -e NO_TIMEOUT=true \
        -e CONTAINER_OS=nixos \
        -e MAX_PARALLELIZATION=true \
        -e SOPV51_COMPLIANT=true \
        -e AGENT_COORDINATOR=monitoring_worker \
        -e CLAUDE_LOGGING_DIR=./data/tmp \
        -p 9090:9090 \
        -v "$(pwd)/data/prometheus:/prometheus:z" \
        -v "$(pwd)/data/tmp:/var/log/claude:z" \
        --memory=2g \
        --cpus=2 \
        --health-cmd="curl -f http://localhost:9090/-/healthy --max-time 5" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        --health-start-period=30s \
        --restart=unless-stopped \
        localhost/indrajaal-prometheus-demo:nixos-devenv \
        --config.file=/etc/prometheus/prometheus.yml \
        --storage.tsdb.path=/prometheus \
        --storage.tsdb.retention.time=15d \
        --storage.tsdb.retention.size=10GB \
        --web.enable-lifecycle \
        --web.enable-admin-api \
        --query.max-concurrency=50 \
        --query.timeout=2m
else
    echo "✅ Prometheus already running"
fi

# Start Grafana (Priority 3)
echo ""
echo "📈 Starting Grafana..."
if ! podman ps | grep -q indrajaal-grafana-demo; then
    podman run -d \
        --name indrajaal-grafana-demo \
        --hostname grafana-dashboards \
        --network indrajaal-app \
        -e GF_SECURITY_ADMIN_PASSWORD=demo_admin_password \
        -e GF_USERS_ALLOW_SIGN_UP=false \
        -e GF_USERS_DEFAULT_THEME=dark \
        -e GF_DATABASE_WAL=true \
        -e GF_DATABASE_CACHE_MODE=shared \
        -e GF_EXPLORE_ENABLED=true \
        -e PHICS_ENABLED=true \
        -e NO_TIMEOUT=true \
        -e CONTAINER_OS=nixos \
        -e MAX_PARALLELIZATION=true \
        -e SOPV51_COMPLIANT=true \
        -e AGENT_COORDINATOR=monitoring_worker \
        -e CLAUDE_LOGGING_DIR=./data/tmp \
        -p 3000:3000 \
        -v "$(pwd)/data/grafana:/var/lib/grafana:z" \
        -v "$(pwd)/data/tmp:/var/log/claude:z" \
        --memory=1g \
        --cpus=1 \
        --health-cmd="curl -f http://localhost:3000/api/health --max-time 5" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        --health-start-period=45s \
        --restart=unless-stopped \
        localhost/indrajaal-grafana-demo:nixos-devenv
else
    echo "✅ Grafana already running"
fi

# Final status check
echo ""
echo "📋 Container Status Summary"
echo "=========================="
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🌐 Service URLs"
echo "=============="
echo "🚀 Phoenix Application:  http://localhost:4000"
echo "📊 Prometheus Metrics:   http://localhost:9090"  
echo "📈 Grafana Dashboards:   http://localhost:3000 (admin/demo_admin_password)"
echo "🗄️ PostgreSQL Database:  localhost:5433 (postgres/postgres)"
echo "🔄 Redis Cache:          localhost:6379"

echo ""
echo "✅ Indrajaal Demo Environment Started Successfully!"
echo "🎯 All containers are running with SOPv5.1 compliance"
echo ""
echo "📚 Next Steps:"
echo "1. Wait for application to fully start (~60 seconds)"
echo "2. Visit http://localhost:4000 to access the demo"
echo "3. Check container logs: podman logs <container-name>"
echo "4. Monitor with: podman stats"