#!/bin/bash
# Stop all SigNoz containers
# Usage: ./stop-signoz.sh

echo "🛑 Stopping SigNoz containers..."
echo ""

# Stop containers in reverse order (frontend -> query -> collector -> clickhouse)
for container in signoz-frontend signoz-query-service signoz-otel-collector signoz-clickhouse; do
    if podman ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "Stopping $container..."
        podman stop "$container" 2>/dev/null || echo "  (already stopped)"
    else
        echo "Container $container does not exist"
    fi
done

echo ""
echo "✅ All SigNoz containers stopped"
echo ""
echo "Container status:"
podman ps -a --filter name=signoz- --format "table {{.Names}}\t{{.Status}}"
echo ""
echo "To start again: ./start-signoz-simple.sh"
echo "To remove containers: podman rm signoz-clickhouse signoz-otel-collector signoz-query-service signoz-frontend"
echo ""
