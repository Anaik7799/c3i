#!/bin/bash
# Send a test OTLP trace to the SigNoz OTEL Collector
# Usage: ./send_test_trace.sh [service-name]

SERVICE_NAME="${1:-test-service}"
TRACE_ID=$(uuidgen | tr -d '-' | head -c 32)
SPAN_ID=$(uuidgen | tr -d '-' | head -c 16)
TIMESTAMP_START=$(($(date +%s) * 1000000000))
TIMESTAMP_END=$((TIMESTAMP_START + 100000000))

echo "Sending test trace..."
echo "Service: $SERVICE_NAME"
echo "Trace ID: $TRACE_ID"
echo "Span ID: $SPAN_ID"

curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"$SERVICE_NAME\"}
        }]
      },
      \"scopeSpans\": [{
        \"spans\": [{
          \"traceId\": \"$TRACE_ID\",
          \"spanId\": \"$SPAN_ID\",
          \"name\": \"test-operation\",
          \"kind\": 1,
          \"startTimeUnixNano\": \"$TIMESTAMP_START\",
          \"endTimeUnixNano\": \"$TIMESTAMP_END\",
          \"attributes\": [{
            \"key\": \"http.method\",
            \"value\": {\"stringValue\": \"GET\"}
          }, {
            \"key\": \"http.url\",
            \"value\": {\"stringValue\": \"http://example.com/api/test\"}
          }, {
            \"key\": \"http.status_code\",
            \"value\": {\"intValue\": 200}
          }]
        }]
      }]
    }]
  }"

echo ""
echo "✅ Test trace sent successfully!"
echo ""
echo "To verify in logs:"
echo "  podman logs signoz-otel-collector | grep TracesExporter"
echo ""
echo "To query in ClickHouse (once exporter is enabled):"
echo "  podman exec signoz-clickhouse clickhouse-client --query \"SELECT * FROM signoz.signoz_traces WHERE traceID = '$TRACE_ID'\""
