#!/bin/bash
# Reset SigNoz data (clear all traces, metrics, logs)
# Usage: ./reset-data.sh

echo "⚠️  SigNoz Data Reset"
echo "════════════════════════════════════════════════════════════════"
echo "This will DELETE all traces, metrics, and logs from ClickHouse!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Reset cancelled"
    exit 0
fi

echo ""
echo "🗑️  Clearing data..."

# Truncate tables
echo "Truncating signoz_traces..."
podman exec signoz-clickhouse clickhouse-client --query \
  "TRUNCATE TABLE signoz.signoz_traces"

echo "Truncating signoz_metrics..."
podman exec signoz-clickhouse clickhouse-client --query \
  "TRUNCATE TABLE signoz.signoz_metrics"

echo "Truncating signoz_logs..."
podman exec signoz-clickhouse clickhouse-client --query \
  "TRUNCATE TABLE signoz.signoz_logs"

# Verify counts
echo ""
echo "Verifying data cleared..."
TRACE_COUNT=$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_traces")
METRIC_COUNT=$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_metrics")
LOG_COUNT=$(podman exec signoz-clickhouse clickhouse-client --query \
  "SELECT COUNT(*) FROM signoz.signoz_logs")

echo "Traces: $TRACE_COUNT"
echo "Metrics: $METRIC_COUNT"
echo "Logs: $LOG_COUNT"
echo ""

if [ "$TRACE_COUNT" -eq 0 ] && [ "$METRIC_COUNT" -eq 0 ] && [ "$LOG_COUNT" -eq 0 ]; then
    echo "✅ All data cleared successfully!"
else
    echo "⚠️  Warning: Some data may remain"
fi
