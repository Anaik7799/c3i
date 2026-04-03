#!/bin/bash
# SOPv5.11 PostgreSQL External Service Starter
# This script starts PostgreSQL 17 on port 5433 (avoiding conflicts with default 5432)

set -e

echo "🐘 Starting PostgreSQL 17 for Intelitor development..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if container already exists
if podman ps -a | grep -q intelitor-postgres; then
  echo "⚠️  Container 'intelitor-postgres' already exists."

  # Check if it's running
  if podman ps | grep -q intelitor-postgres; then
    echo "✅ PostgreSQL is already running on port 5433"
    podman logs --tail 5 intelitor-postgres
    exit 0
  else
    echo "🔄 Starting existing container..."
    podman start intelitor-postgres
    sleep 2

    if pg_isready -h localhost -p 5433 >/dev/null 2>&1; then
      echo "✅ PostgreSQL started successfully on port 5433"
      echo ""
      echo "Connection details:"
      echo "  Host: localhost (or host.docker.internal from container)"
      echo "  Port: 5433"
      echo "  Database: intelitor_dev"
      echo "  User: postgres"
      echo "  Password: postgres"
    else
      echo "❌ PostgreSQL failed to start"
      podman logs --tail 20 intelitor-postgres
      exit 1
    fi
    exit 0
  fi
fi

# Create new container
echo "📦 Creating PostgreSQL container..."
podman run -d --name intelitor-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=intelitor_dev \
  -p 5433:5432 \
  postgres:17-alpine

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
  if pg_isready -h localhost -p 5433 >/dev/null 2>&1; then
    echo "✅ PostgreSQL started successfully on port 5433"
    echo ""
    echo "Connection details:"
    echo "  Host: localhost (or host.docker.internal from container)"
    echo "  Port: 5433"
    echo "  Database: intelitor_dev"
    echo "  User: postgres"
    echo "  Password: postgres"
    echo ""
    echo "Test connection:"
    echo "  psql -h localhost -p 5433 -U postgres -d intelitor_dev"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
  fi
  sleep 1
done

# If we get here, PostgreSQL didn't start in time
echo "❌ PostgreSQL failed to start within 30 seconds"
echo "Container logs:"
podman logs intelitor-postgres
exit 1
