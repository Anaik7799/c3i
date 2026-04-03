#!/bin/bash
# SigNoz Container Startup Script
# Uses native podman commands to start all SigNoz services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== SigNoz Container Startup ==="
echo "Date: $(date -Iseconds)"
echo ""

# Create network if it doesn't exist
echo "Creating network..."
podman network exists signoz-network 2>/dev/null || podman network create signoz-network
echo "✅ Network: signoz-network"
echo ""

# Create volumes if they don't exist
echo "Creating volumes..."
for vol in signoz-clickhouse-data signoz-query-service-data signoz-otel-collector-data; do
    podman volume exists "$vol" 2>/dev/null || podman volume create "$vol"
    echo "✅ Volume: $vol"
done
echo ""

# Start ClickHouse
echo "Starting ClickHouse..."
podman run -d \
    --name signoz-clickhouse \
    --hostname clickhouse \
    --network signoz-network \
    -p 9000:9000 \
    -p 8123:8123 \
    -v signoz-clickhouse-data:/var/lib/clickhouse \
    -v "$SCRIPT_DIR/config/clickhouse/clickhouse-config.xml:/etc/clickhouse-server/config.d/logging.xml:ro,z" \
    -v "$SCRIPT_DIR/config/clickhouse/clickhouse-users.xml:/etc/clickhouse-server/users.d/logging.xml:ro,z" \
    -e CLICKHOUSE_DB=signoz \
    -e CLICKHOUSE_USER=signoz \
    -e CLICKHOUSE_PASSWORD=signoz \
    --health-cmd='clickhouse-client --query "SELECT 1"' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=40s \
    --restart=unless-stopped \
    --cpus=2.0 \
    --memory=2g \
    localhost/signoz-clickhouse:latest

echo "✅ ClickHouse container started"
echo "   Waiting for health check..."

# Wait for ClickHouse to be healthy
sleep 5
for i in {1..20}; do
    if podman healthcheck run signoz-clickhouse 2>/dev/null; then
        echo "✅ ClickHouse is healthy"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ ClickHouse health check timeout"
        exit 1
    fi
    sleep 3
done
echo ""

# Start OTEL Collector
echo "Starting OTEL Collector..."
podman run -d \
    --name signoz-otel-collector \
    --hostname otel-collector \
    --network signoz-network \
    -p 4317:4317 \
    -p 4318:4318 \
    -p 8888:8888 \
    -p 13133:13133 \
    -v signoz-otel-collector-data:/var/lib/otelcol \
    -v "$SCRIPT_DIR/config/otel-collector/otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro,z" \
    --health-cmd='wget --no-verbose --tries=1 --spider http://localhost:13133/ || exit 1' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=30s \
    --restart=unless-stopped \
    --cpus=1.0 \
    --memory=1g \
    localhost/signoz-otel-collector:latest \
    --config=/etc/otel-collector-config.yaml

echo "✅ OTEL Collector container started"
echo "   Waiting for health check..."

sleep 5
for i in {1..15}; do
    if podman healthcheck run signoz-otel-collector 2>/dev/null; then
        echo "✅ OTEL Collector is healthy"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ OTEL Collector health check timeout"
        exit 1
    fi
    sleep 2
done
echo ""

# Start Query Service
echo "Starting Query Service..."
podman run -d \
    --name signoz-query-service \
    --hostname query-service \
    --network signoz-network \
    -p 8080:8080 \
    -v signoz-query-service-data:/var/lib/signoz \
    -v "$SCRIPT_DIR/config/query-service/config.yaml:/root/config/config.yaml:ro,z" \
    --health-cmd='wget --no-verbose --tries=1 --spider http://localhost:8080/api/v1/health || exit 1' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=30s \
    --restart=unless-stopped \
    --cpus=1.0 \
    --memory=1g \
    localhost/signoz-query-service:latest \
    -config=/root/config/config.yaml

echo "✅ Query Service container started"
echo "   Waiting for health check..."

sleep 5
for i in {1..15}; do
    if podman healthcheck run signoz-query-service 2>/dev/null; then
        echo "✅ Query Service is healthy"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ Query Service health check timeout"
        exit 1
    fi
    sleep 2
done
echo ""

# Start Frontend
echo "Starting Frontend..."
podman run -d \
    --name signoz-frontend \
    --hostname frontend \
    --network signoz-network \
    -p 3301:3301 \
    -e FRONTEND_API_ENDPOINT=http://query-service:8080 \
    --health-cmd='wget --no-verbose --tries=1 --spider http://localhost:3301/ || exit 1' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=30s \
    --restart=unless-stopped \
    --cpus=0.5 \
    --memory=512m \
    localhost/signoz-frontend:latest

echo "✅ Frontend container started"
echo "   Waiting for health check..."

sleep 5
for i in {1..15}; do
    if podman healthcheck run signoz-frontend 2>/dev/null; then
        echo "✅ Frontend is healthy"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "❌ Frontend health check timeout"
        exit 1
    fi
    sleep 2
done
echo ""

echo "=== SigNoz Deployment Complete ==="
echo ""
echo "Services:"
echo "  ClickHouse:       http://localhost:9000 (native), http://localhost:8123 (HTTP)"
echo "  OTEL Collector:   http://localhost:4317 (gRPC), http://localhost:4318 (HTTP)"
echo "  Query Service:    http://localhost:8080"
echo "  Frontend:         http://localhost:3301"
echo ""
echo "To check status: podman ps"
echo "To view logs:    podman logs -f <container-name>"
echo "To stop all:     podman stop signoz-clickhouse signoz-otel-collector signoz-query-service signoz-frontend"
echo ""
