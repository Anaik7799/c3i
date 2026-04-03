-- 🚀 TimescaleDB Initialization Script - SOPv5.11 Cybernetic Execution
-- =====================================================================
-- Updated: 2025-11-25 15:45:00 CEST (TimescaleDB Container Integration Complete)
-- Framework: SOPv5.11 + TPS + STAMP + TDG + GDE + PHICS v2.1 + Container-Only
-- Purpose: Initialize TimescaleDB extension and create hypertables for event logging
-- Agent: Database Configuration Helper
-- Container: localhost/intelitor-timescaledb-demo:nixos-devenv (PostgreSQL 17 + TimescaleDB)
-- Build: NIXPKGS_ALLOW_UNFREE=1 nix-build containers/intelitor-timescaledb-demo.nix --impure
-- Docs: containers/README.md (lines 599-775), data/tmp/20251125-1545-timescaledb-container-integration-complete.md

-- Enable TimescaleDB Extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Verify TimescaleDB Installation
SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';

-- Create ts_event_logs table for time-series data
CREATE TABLE IF NOT EXISTS ts_event_logs (
    id BIGSERIAL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type VARCHAR(100) NOT NULL,
    event_source VARCHAR(100) NOT NULL,
    tenant_id UUID NOT NULL,
    user_id UUID,
    resource_type VARCHAR(100),
    resource_id UUID,
    action VARCHAR(100),
    status VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    duration_ms INTEGER,
    ip_address INET,
    user_agent TEXT,
    correlation_id UUID,
    trace_id VARCHAR(64),
    span_id VARCHAR(16),
    severity VARCHAR(20) DEFAULT 'info',
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create hypertable for ts_event_logs (partitioned by timestamp)
-- Partition by day for optimal time-series performance
SELECT create_hypertable('ts_event_logs', 'timestamp', 
    chunk_time_interval => INTERVAL '1 day',
    create_default_indexes => false
);

-- Create optimized indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_timestamp ON ts_event_logs (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_tenant_timestamp ON ts_event_logs (tenant_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_event_type_timestamp ON ts_event_logs (event_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_user_timestamp ON ts_event_logs (user_id, timestamp DESC) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_resource_timestamp ON ts_event_logs (resource_type, resource_id, timestamp DESC) WHERE resource_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_correlation_id ON ts_event_logs (correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_trace_id ON ts_event_logs (trace_id) WHERE trace_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_severity_timestamp ON ts_event_logs (severity, timestamp DESC);

-- Create GIN index for metadata JSONB queries
CREATE INDEX IF NOT EXISTS idx_ts_event_logs_metadata_gin ON ts_event_logs USING GIN (metadata);

-- Create ts_alarm_events table for time-series alarm data
CREATE TABLE IF NOT EXISTS ts_alarm_events (
    id BIGSERIAL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tenant_id UUID NOT NULL,
    alarm_id UUID NOT NULL,
    device_id UUID,
    site_id UUID,
    alarm_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL,
    acknowledged BOOLEAN DEFAULT false,
    acknowledged_by UUID,
    acknowledged_at TIMESTAMPTZ,
    resolved BOOLEAN DEFAULT false,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    escalated BOOLEAN DEFAULT false,
    escalation_level INTEGER DEFAULT 0,
    message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create hypertable for ts_alarm_events
SELECT create_hypertable('ts_alarm_events', 'timestamp', 
    chunk_time_interval => INTERVAL '1 hour',
    create_default_indexes => false
);

-- Create indexes for ts_alarm_events
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_timestamp ON ts_alarm_events (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_tenant_timestamp ON ts_alarm_events (tenant_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_alarm_id_timestamp ON ts_alarm_events (alarm_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_device_timestamp ON ts_alarm_events (device_id, timestamp DESC) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_site_timestamp ON ts_alarm_events (site_id, timestamp DESC) WHERE site_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_type_severity_timestamp ON ts_alarm_events (alarm_type, severity, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_status_timestamp ON ts_alarm_events (status, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_alarm_events_unresolved ON ts_alarm_events (tenant_id, timestamp DESC) WHERE resolved = false;

-- Create ts_performance_metrics table for time-series performance data
CREATE TABLE IF NOT EXISTS ts_performance_metrics (
    id BIGSERIAL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tenant_id UUID NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- counter, gauge, histogram, summary
    value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(20),
    labels JSONB DEFAULT '{}',
    source VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create hypertable for ts_performance_metrics
SELECT create_hypertable('ts_performance_metrics', 'timestamp', 
    chunk_time_interval => INTERVAL '1 hour',
    create_default_indexes => false
);

-- Create indexes for ts_performance_metrics
CREATE INDEX IF NOT EXISTS idx_ts_performance_metrics_timestamp ON ts_performance_metrics (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_performance_metrics_tenant_timestamp ON ts_performance_metrics (tenant_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_performance_metrics_name_timestamp ON ts_performance_metrics (metric_name, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_performance_metrics_type_timestamp ON ts_performance_metrics (metric_type, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_ts_performance_metrics_labels_gin ON ts_performance_metrics USING GIN (labels);

-- Create retention policies (automatic data cleanup)
-- Keep ts_event_logs for 90 days
SELECT add_retention_policy('ts_event_logs', INTERVAL '90 days');

-- Keep ts_alarm_events for 1 year
SELECT add_retention_policy('ts_alarm_events', INTERVAL '365 days');

-- Keep ts_performance_metrics for 30 days
SELECT add_retention_policy('ts_performance_metrics', INTERVAL '30 days');

-- Create continuous aggregates for common queries (materialized views)

-- Hourly event summary
CREATE MATERIALIZED VIEW IF NOT EXISTS ts_event_logs_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', timestamp) as hour,
    tenant_id,
    event_type,
    event_source,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    AVG(duration_ms) as avg_duration_ms,
    MAX(duration_ms) as max_duration_ms,
    COUNT(*) FILTER (WHERE severity = 'error') as error_count,
    COUNT(*) FILTER (WHERE severity = 'warn') as warning_count
FROM ts_event_logs
GROUP BY hour, tenant_id, event_type, event_source;

-- Add refresh policy for continuous aggregate
SELECT add_continuous_aggregate_policy('ts_event_logs_hourly',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- Daily alarm summary
CREATE MATERIALIZED VIEW IF NOT EXISTS ts_alarm_events_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', timestamp) as day,
    tenant_id,
    alarm_type,
    severity,
    COUNT(*) as alarm_count,
    COUNT(*) FILTER (WHERE acknowledged = true) as acknowledged_count,
    COUNT(*) FILTER (WHERE resolved = true) as resolved_count,
    AVG(EXTRACT(EPOCH FROM (resolved_at - timestamp))/60) FILTER (WHERE resolved_at IS NOT NULL) as avg_resolution_minutes
FROM ts_alarm_events
GROUP BY day, tenant_id, alarm_type, severity;

-- Add refresh policy for alarm continuous aggregate
SELECT add_continuous_aggregate_policy('ts_alarm_events_daily',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour');

-- Create compression policies for older data
-- Compress ts_event_logs chunks older than 7 days
SELECT add_compression_policy('ts_event_logs', INTERVAL '7 days');

-- Compress ts_alarm_events chunks older than 7 days
SELECT add_compression_policy('ts_alarm_events', INTERVAL '7 days');

-- Compress ts_performance_metrics chunks older than 1 day
SELECT add_compression_policy('ts_performance_metrics', INTERVAL '1 day');

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ts_event_logs TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON ts_alarm_events TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON ts_performance_metrics TO postgres;
GRANT SELECT ON ts_event_logs_hourly TO postgres;
GRANT SELECT ON ts_alarm_events_daily TO postgres;

-- Grant usage on sequences
GRANT USAGE ON SEQUENCE ts_event_logs_id_seq TO postgres;
GRANT USAGE ON SEQUENCE ts_alarm_events_id_seq TO postgres;
GRANT USAGE ON SEQUENCE ts_performance_metrics_id_seq TO postgres;

-- Log successful initialization
INSERT INTO ts_event_logs (event_type, event_source, tenant_id, action, status, message) 
VALUES ('database', 'timescaledb_init', '00000000-0000-0000-0000-000000000000', 'initialize', 'success', 'TimescaleDB initialized successfully with hypertables and policies');

-- Display initialization summary
SELECT 
    'TimescaleDB Initialization Complete' as status,
    NOW() as completed_at,
    version() as postgresql_version,
    (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb') as timescaledb_version;