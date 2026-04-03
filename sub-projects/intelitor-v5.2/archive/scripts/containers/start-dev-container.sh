#!/bin/bash
# SOPv5.11 Development Container Starter
# This script starts the fully functional development container with:
# - Elixir 1.19.2 + Erlang/OTP 27
# - UTF-8 locale support (glibcLocales)
# - Multi-path SSL certificates
# - PAM-free user switching (setpriv)
# - PHICS v2.1 hot-reloading

set -e

echo "🚀 Starting Intelitor SOPv5.11 Development Container..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Ensure we're in the project directory
if [ ! -f "mix.exs" ]; then
  echo "❌ Error: mix.exs not found. Please run from project root."
  exit 1
fi

# Check if development container image exists (look for any tag)
if ! podman images | grep -q "intelitor-dev.*nixos-25.05"; then
  echo "⚠️  Warning: Development container image not found!"
  echo ""
  echo "📋 To build the container, use:"
  echo "  elixir scripts/containers/create_functional_dev_container.exs --all"
  echo ""
  echo "Or manually:"
  echo "  cd containers && nix-build sopv51-dev-comprehensive.nix"
  echo "  podman load < /nix/store/*-docker-image-intelitor-dev.tar.gz"
  exit 1
fi

# Get the actual image tag
IMAGE_TAG=$(podman images | grep "intelitor-dev.*nixos-25.05" | awk '{print $2}' | head -1)
if [ -z "$IMAGE_TAG" ]; then
  echo "❌ Error: Could not determine container image tag"
  exit 1
fi
echo "📦 Using container image: localhost/intelitor-dev:$IMAGE_TAG"

# Check if PostgreSQL is running
echo "🔍 Checking external services..."
POSTGRES_RUNNING=false
# Check for either intelitor-postgres or intelitor-timescaledb-demo
if podman ps --filter "name=intelitor-postgres" --format "{{.Names}}" | grep -q "intelitor-postgres"; then
  if podman exec intelitor-postgres pg_isready -U postgres >/dev/null 2>&1; then
    echo "✅ PostgreSQL (intelitor-postgres) is running on port 5433"
    POSTGRES_RUNNING=true
  fi
elif podman ps --filter "name=intelitor-timescaledb-demo" --format "{{.Names}}" | grep -q "intelitor-timescaledb-demo"; then
  if podman exec intelitor-timescaledb-demo pg_isready -U postgres >/dev/null 2>&1; then
    echo "✅ PostgreSQL (intelitor-timescaledb-demo) is running on port 5433"
    POSTGRES_RUNNING=true
  fi
fi

if [ "$POSTGRES_RUNNING" = false ]; then
  echo "⚠️  PostgreSQL is not running on port 5433"
  echo "Starting PostgreSQL..."
  ./scripts/containers/start-postgresql.sh
fi

# Check if Redis is running
REDIS_RUNNING=false
# Check for either intelitor-redis or intelitor-redis-demo
if podman exec intelitor-redis redis-cli ping >/dev/null 2>&1; then
  echo "✅ Redis (intelitor-redis) is running on port 6379"
  REDIS_RUNNING=true
elif podman exec intelitor-redis-demo redis-cli ping >/dev/null 2>&1; then
  echo "✅ Redis (intelitor-redis-demo) is running on port 6379"
  REDIS_RUNNING=true
fi

if [ "$REDIS_RUNNING" = false ]; then
  echo "⚠️  Redis is not running on port 6379"
  echo "Starting Redis..."
  ./scripts/containers/start-redis.sh
fi

echo "✅ External services ready"
echo ""
echo "📦 Starting development container..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop existing container if running
if podman ps -a --format "{{.Names}}" | grep -q "^intelitor-dev$"; then
  echo "🛑 Stopping existing container..."
  podman stop intelitor-dev 2>/dev/null || true
  podman rm intelitor-dev 2>/dev/null || true
fi

echo "🚀 Starting development container..."
echo ""
echo "📌 Container features:"
echo "   ✓ Elixir 1.19.2 with Erlang/OTP 27"
echo "   ✓ UTF-8 locale support"
echo "   ✓ SSL/TLS certificates configured"
echo "   ✓ PHICS hot-reloading enabled"
echo ""
echo "💡 To use the container:"
echo "   podman exec intelitor-dev bash -c \"source /etc/profile.d/intelitor.sh && cd /workspace && mix compile\""
echo ""

# Run the container
podman run -it --rm \
  --name intelitor-dev \
  -v "$(pwd):/workspace:z" \
  -p 4000:4000 \
  -p 4001:4001 \
  --add-host host.docker.internal:host-gateway \
  localhost/intelitor-dev:$IMAGE_TAG
