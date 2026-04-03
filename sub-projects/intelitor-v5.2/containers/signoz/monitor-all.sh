#!/bin/bash
# Monitor logs from all SigNoz containers
# Usage: ./monitor-all.sh

echo "🔍 Monitoring all SigNoz container logs..."
echo "Press Ctrl+C to stop"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Function to add colored prefixes
monitor_container() {
    local container=$1
    local color=$2
    podman logs -f "$container" 2>&1 | while IFS= read -r line; do
        echo -e "\033[${color}m[$container]\033[0m $line"
    done
}

# Start monitoring all containers in parallel
monitor_container "signoz-clickhouse" "36" &  # Cyan
monitor_container "signoz-otel-collector" "32" &  # Green
monitor_container "signoz-query-service" "33" &  # Yellow
monitor_container "signoz-frontend" "35" &  # Magenta

# Wait for all background processes
wait
