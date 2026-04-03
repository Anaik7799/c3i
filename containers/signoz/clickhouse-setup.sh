#!/bin/bash
# SigNoz ClickHouse Schema Setup
# Creates tables for traces, metrics, and logs following OpenTelemetry conventions

set -e

echo "Creating SigNoz ClickHouse schema..."

# Create signoz_traces table for trace data
podman exec signoz-clickhouse clickhouse-client --query "
CREATE TABLE IF NOT EXISTS signoz.signoz_traces (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    traceID String CODEC(ZSTD(1)),
    spanID String CODEC(ZSTD(1)),
    parentSpanID String CODEC(ZSTD(1)),
    serviceName LowCardinality(String) CODEC(ZSTD(1)),
    name LowCardinality(String) CODEC(ZSTD(1)),
    kind Int8 CODEC(T64, ZSTD(1)),
    durationNano UInt64 CODEC(T64, ZSTD(1)),
    statusCode Int16 CODEC(T64, ZSTD(1)),
    component LowCardinality(String) CODEC(ZSTD(1)),
    httpMethod LowCardinality(String) CODEC(ZSTD(1)),
    httpUrl String CODEC(ZSTD(1)),
    httpStatusCode Int16 CODEC(T64, ZSTD(1)),
    resourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    spanAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    events Nested(
        timestamp DateTime64(9),
        name LowCardinality(String),
        attributes Map(LowCardinality(String), String)
    ) CODEC(ZSTD(1)),
    links Nested(
        traceID String,
        spanID String,
        attributes Map(LowCardinality(String), String)
    ) CODEC(ZSTD(1))
) ENGINE = MergeTree()
PARTITION BY toDate(timestamp)
ORDER BY (serviceName, timestamp, traceID)
TTL toDateTime(timestamp) + INTERVAL 7 DAY
SETTINGS index_granularity = 8192;
"

# Create signoz_metrics table for metrics data
podman exec signoz-clickhouse clickhouse-client --query "
CREATE TABLE IF NOT EXISTS signoz.signoz_metrics (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    name LowCardinality(String) CODEC(ZSTD(1)),
    value Float64 CODEC(ZSTD(1)),
    attributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    resourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1))
) ENGINE = MergeTree()
PARTITION BY toDate(timestamp)
ORDER BY (name, timestamp)
TTL toDateTime(timestamp) + INTERVAL 7 DAY
SETTINGS index_granularity = 8192;
"

# Create signoz_logs table for log data
podman exec signoz-clickhouse clickhouse-client --query "
CREATE TABLE IF NOT EXISTS signoz.signoz_logs (
    timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    observedTimestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    traceID String CODEC(ZSTD(1)),
    spanID String CODEC(ZSTD(1)),
    severityText LowCardinality(String) CODEC(ZSTD(1)),
    severityNumber Int8 CODEC(T64, ZSTD(1)),
    body String CODEC(ZSTD(1)),
    resourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    logAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1))
) ENGINE = MergeTree()
PARTITION BY toDate(timestamp)
ORDER BY (timestamp, severityNumber)
TTL toDateTime(timestamp) + INTERVAL 7 DAY
SETTINGS index_granularity = 8192;
"

echo "✅ SigNoz ClickHouse schema created successfully"
echo ""
echo "Tables created:"
podman exec signoz-clickhouse clickhouse-client --query "SHOW TABLES FROM signoz"
