#!/usr/bin/env bash
# ============================================================================
# NixOS Observability Stack - Start Script
# ============================================================================
# SOPv5.11 Compliant - All containers use real NixOS packages
# No Docker Hub images, no placeholders, no Alpine/Ubuntu
#
# Components:
#   - ClickHouse (pkgs.clickhouse) - Trace/metrics storage
#   - OTEL Collector (pkgs.opentelemetry-collector-contrib) - Telemetry ingestion
#   - Tempo (pkgs.tempo) - Distributed tracing
#   - Grafana (pkgs.grafana) - Visualization
#
# Usage: ./scripts/containers/start-observability-stack.sh [--build]
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SIGNOZ_DIR="$PROJECT_ROOT/containers/signoz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if --build flag is passed
BUILD_IMAGES=false
if [[ "$1" == "--build" ]]; then
    BUILD_IMAGES=true
fi

echo "============================================================================"
echo "  NixOS Observability Stack - Starting"
echo "  SOPv5.11 Compliant | Real NixOS Packages Only"
echo "============================================================================"
echo ""

cd "$SIGNOZ_DIR"

# Step 1: Build images if requested or if they don't exist
if [[ "$BUILD_IMAGES" == true ]]; then
    log_info "Building all NixOS container images..."

    log_info "Building ClickHouse..."
    nix-build clickhouse-nixos.nix -o result 2>&1 | tail -5

    log_info "Building OTEL Collector..."
    nix-build otel-collector-nixos.nix -o result-otel 2>&1 | tail -5

    log_info "Building Tempo..."
    nix-build tempo-nixos.nix -o result-tempo 2>&1 | tail -5

    log_info "Building Grafana..."
    nix-build grafana-nixos.nix -o result-grafana 2>&1 | tail -5

    log_success "All images built successfully"
    echo ""
fi

# Step 2: Check if images need to be loaded
check_and_load_image() {
    local image_name=$1
    local result_path=$2

    if ! podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image_name}:latest$"; then
        if [[ -L "$result_path" ]]; then
            log_info "Loading $image_name..."
            podman load < "$result_path"
        else
            log_error "Image $image_name not found and result path $result_path doesn't exist"
            log_error "Run with --build flag: $0 --build"
            exit 1
        fi
    else
        log_info "$image_name already loaded"
    fi
}

log_info "Checking container images..."
check_and_load_image "localhost/signoz-clickhouse" "result"
check_and_load_image "localhost/signoz-otel-collector" "result-otel"
check_and_load_image "localhost/signoz-tempo" "result-tempo"
check_and_load_image "localhost/signoz-grafana" "result-grafana"
log_success "All images available"
echo ""

# Step 3: Create network if it doesn't exist
log_info "Setting up network..."
podman network create signoz-net 2>/dev/null && log_success "Created signoz-net network" || log_info "Network signoz-net already exists"

# Step 4: Create data directories
log_info "Creating data directories..."
mkdir -p /tmp/clickhouse-data /tmp/clickhouse-logs
mkdir -p /tmp/otel-data
mkdir -p /tmp/tempo-data
mkdir -p /tmp/grafana-data
chmod 777 /tmp/clickhouse-data /tmp/clickhouse-logs /tmp/otel-data /tmp/tempo-data /tmp/grafana-data
log_success "Data directories ready"
echo ""

# Step 5: Stop existing containers if running
log_info "Stopping any existing containers..."
for container in signoz-clickhouse signoz-tempo signoz-otel-collector signoz-grafana; do
    if podman ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        podman stop "$container" 2>/dev/null || true
        podman rm "$container" 2>/dev/null || true
        log_info "Removed existing $container"
    fi
done
echo ""

# Step 6: Start containers in order
log_info "Starting ClickHouse..."
podman run -d \
    --name signoz-clickhouse \
    --network signoz-net \
    --user 0:0 \
    -p 8123:8123 \
    -p 9000:9000 \
    -v /tmp/clickhouse-data:/var/lib/clickhouse:z \
    -v /tmp/clickhouse-logs:/var/log/clickhouse-server:z \
    localhost/signoz-clickhouse:latest

log_info "Starting Tempo..."
podman run -d \
    --name signoz-tempo \
    --network signoz-net \
    -p 3200:3200 \
    -p 9095:9095 \
    -v /tmp/tempo-data:/var/lib/tempo:z \
    localhost/signoz-tempo:latest

log_info "Starting OTEL Collector..."
podman run -d \
    --name signoz-otel-collector \
    --network signoz-net \
    -p 4317:4317 \
    -p 4318:4318 \
    -p 8888:8888 \
    -p 8889:8889 \
    -p 13133:13133 \
    -v /tmp/otel-data:/var/lib/otel:z \
    localhost/signoz-otel-collector:latest

log_info "Starting Grafana..."
podman run -d \
    --name signoz-grafana \
    --network signoz-net \
    -p 3001:3000 \
    -v /tmp/grafana-data:/var/lib/grafana:z \
    localhost/signoz-grafana:latest

echo ""
log_info "Waiting for containers to become healthy (30s)..."
sleep 30

# Step 7: Verify health
echo ""
echo "============================================================================"
echo "  Health Check Results"
echo "============================================================================"

check_health() {
    local name=$1
    local url=$2
    local expected=$3

    result=$(curl -s "$url" 2>/dev/null || echo "FAILED")
    if echo "$result" | grep -q "$expected"; then
        log_success "$name: OK"
        return 0
    else
        log_error "$name: FAILED"
        return 1
    fi
}

check_health "ClickHouse" "http://localhost:8123/ping" "Ok"
check_health "Tempo" "http://localhost:3200/ready" "ready"
check_health "OTEL Collector" "http://localhost:13133/health" "Server available"
check_health "Grafana" "http://localhost:3001/api/health" "ok"

echo ""
echo "============================================================================"
echo "  Container Status"
echo "============================================================================"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(signoz|NAME)"

echo ""
echo "============================================================================"
echo "  Access Points"
echo "============================================================================"
echo "  Grafana UI:          http://localhost:3001 (admin/admin)"
echo "  OTLP gRPC:           localhost:4317"
echo "  OTLP HTTP:           localhost:4318"
echo "  Prometheus Metrics:  http://localhost:8889/metrics"
echo "  Tempo API:           http://localhost:3200"
echo "  ClickHouse HTTP:     http://localhost:8123"
echo "  OTEL Health:         http://localhost:13133/health"
echo "============================================================================"
echo ""
log_success "Observability stack started successfully!"
