#!/bin/bash
# Show status of all SigNoz containers and services
# Usage: ./status.sh

echo "📊 SigNoz System Status"
echo "════════════════════════════════════════════════════════════════"
echo "Generated: $(date)"
echo ""

# Container status
echo "Container Status:"
echo "────────────────────────────────────────────────────────────────"
podman ps -a --filter name=signoz- --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Network status
echo "Network Status:"
echo "────────────────────────────────────────────────────────────────"
if podman network inspect signoz-network > /dev/null 2>&1; then
    echo "✅ signoz-network exists"
    echo "   Connected containers:"
    podman network inspect signoz-network --format '{{range .Containers}}  - {{.Name}}{{"\n"}}{{end}}'
else
    echo "❌ signoz-network does not exist"
fi
echo ""

# Volume status
echo "Volume Status:"
echo "────────────────────────────────────────────────────────────────"
for vol in signoz-clickhouse-data signoz-otel-collector-data signoz-query-service-data; do
    if podman volume exists "$vol" 2>/dev/null; then
        size=$(podman volume inspect "$vol" --format '{{.Mountpoint}}' | xargs du -sh 2>/dev/null | awk '{print $1}')
        echo "✅ $vol (${size:-unknown size})"
    else
        echo "❌ $vol (not found)"
    fi
done
echo ""

# Service health
echo "Service Health:"
echo "────────────────────────────────────────────────────────────────"

# Check ClickHouse
echo -n "ClickHouse:        "
if curl -sf http://localhost:8123 > /dev/null 2>&1; then
    echo "✅ HTTP accessible"
else
    echo "❌ HTTP not accessible"
fi

# Check OTEL Collector
echo -n "OTEL Collector:    "
if curl -sf http://localhost:13133 > /dev/null 2>&1; then
    echo "✅ Health endpoint accessible"
else
    echo "❌ Health endpoint not accessible"
fi

# Check Query Service
echo -n "Query Service:     "
if curl -sf http://localhost:8081/api/v1/health > /dev/null 2>&1; then
    echo "✅ API accessible"
else
    echo "❌ API not accessible"
fi

# Check Frontend
echo -n "Frontend:          "
if curl -sf http://localhost:3301 > /dev/null 2>&1; then
    echo "✅ UI accessible"
else
    echo "❌ UI not accessible"
fi
echo ""

# Database status
echo "Database Status:"
echo "────────────────────────────────────────────────────────────────"
if podman exec signoz-clickhouse clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
    echo "✅ ClickHouse client accessible"
    
    # Check databases
    if podman exec signoz-clickhouse clickhouse-client --query "SHOW DATABASES" | grep -q "signoz"; then
        echo "✅ signoz database exists"
        
        # Count tables
        table_count=$(podman exec signoz-clickhouse clickhouse-client --query "SHOW TABLES FROM signoz" | wc -l)
        echo "   Tables: $table_count"
        
        # Count data
        trace_count=$(podman exec signoz-clickhouse clickhouse-client --query "SELECT COUNT(*) FROM signoz.signoz_traces" 2>/dev/null || echo "0")
        metric_count=$(podman exec signoz-clickhouse clickhouse-client --query "SELECT COUNT(*) FROM signoz.signoz_metrics" 2>/dev/null || echo "0")
        log_count=$(podman exec signoz-clickhouse clickhouse-client --query "SELECT COUNT(*) FROM signoz.signoz_logs" 2>/dev/null || echo "0")
        
        echo "   Data:"
        echo "     Traces:  $trace_count"
        echo "     Metrics: $metric_count"
        echo "     Logs:    $log_count"
    else
        echo "❌ signoz database not found"
    fi
else
    echo "❌ ClickHouse not accessible"
fi
echo ""

# Access URLs
echo "Access URLs:"
echo "────────────────────────────────────────────────────────────────"
echo "  ClickHouse HTTP:  http://localhost:8123"
echo "  ClickHouse Native: tcp://localhost:9000"
echo "  OTLP HTTP:        http://localhost:4318/v1/traces"
echo "  OTLP gRPC:        grpc://localhost:4317"
echo "  Health Check:     http://localhost:13133"
echo "  Metrics:          http://localhost:8888/metrics"
echo "  Query Service:    http://localhost:8081"
echo "  Frontend:         http://localhost:3301"
echo ""

echo "════════════════════════════════════════════════════════════════"
