#!/bin/bash
# SOPv5.11 Redis External Service Starter
# This script starts Redis 7 on port 6379

set -e

echo "📦 Starting Redis 7 for Intelitor development..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if container already exists
if podman ps -a | grep -q intelitor-redis; then
  echo "⚠️  Container 'intelitor-redis' already exists."

  # Check if it's running
  if podman ps | grep -q intelitor-redis; then
    echo "✅ Redis is already running on port 6379"
    podman logs --tail 5 intelitor-redis
    exit 0
  else
    echo "🔄 Starting existing container..."
    podman start intelitor-redis
    sleep 1

    if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
      echo "✅ Redis started successfully on port 6379"
      echo ""
      echo "Connection details:"
      echo "  Host: localhost (or host.docker.internal from container)"
      echo "  Port: 6379"
      echo "  Database: 0 (default)"
    else
      echo "❌ Redis failed to start"
      podman logs --tail 20 intelitor-redis
      exit 1
    fi
    exit 0
  fi
fi

# Create new container
echo "📦 Creating Redis container..."
podman run -d --name intelitor-redis \
  -p 6379:6379 \
  redis:7-alpine

# Wait for Redis to be ready
echo "⏳ Waiting for Redis to be ready..."
for i in {1..15}; do
  if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
    echo "✅ Redis started successfully on port 6379"
    echo ""
    echo "Connection details:"
    echo "  Host: localhost (or host.docker.internal from container)"
    echo "  Port: 6379"
    echo "  Database: 0 (default)"
    echo ""
    echo "Test connection:"
    echo "  redis-cli -h localhost -p 6379 ping"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
  fi
  sleep 1
done

# If we get here, Redis didn't start in time
echo "❌ Redis failed to start within 15 seconds"
echo "Container logs:"
podman logs intelitor-redis
exit 1
