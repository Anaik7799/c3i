#!/bin/bash

# Simple demo startup script

echo "🚀 Starting Indrajaal Demo Environment"
echo "=================================="

# Check if containers are running
echo "📦 Checking containers..."
podman ps | grep indrajaal

# Start database if not running
if ! podman ps | grep -q indrajaal-postgres-demo; then
    echo "🗄️ Starting PostgreSQL..."
    podman start indrajaal-postgres-demo
    sleep 5
fi

# Start Redis if not running
if ! podman ps | grep -q indrajaal-redis-demo; then
    echo "🔄 Starting Redis..."
    podman start indrajaal-redis-demo
    sleep 3
fi

# Check database connectivity
echo "🔍 Checking database..."
if pg_isready -h localhost -p 5433 -U postgres -d indrajaal_demo; then
    echo "✅ Database is ready"
else
    echo "❌ Database is not ready"
    exit 1
fi

# Run migrations
echo "🔧 Running migrations..."
mix ecto.migrate

# Start Phoenix server
echo "🌐 Starting Phoenix server..."
echo "Visit http://localhost:4000 once started"
echo ""
PORT=4000 MIX_ENV=dev mix phx.server