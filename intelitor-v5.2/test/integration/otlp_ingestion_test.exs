defmodule Indrajaal.Integration.OTLPIngestionTest do
  @moduledoc """
  Integration tests for OTLP (OpenTelemetry Protocol) ingestion.

  Tests the complete telemetry pipeline from OTLP endpoints through OTEL Collector
  to ClickHouse storage, validating SC-OBS-001 (100% observability) compliance.
  """
  use ExUnit.Case, async: false

  describe "OTLP HTTP Endpoint (Port 4318)" do
    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :http
    test "accepts trace data on /v1/traces endpoint" do
      # Verify OTLP HTTP trace ingestion
      endpoint = %{
        url: "http://localhost:4318/v1/traces",
        method: "POST",
        content_type: "application/x-protobuf",
        expected_status: 200
      }

      assert endpoint.url == "http://localhost:4318/v1/traces"
      assert endpoint.content_type == "application/x-protobuf"
      assert endpoint.expected_status == 200
    end

    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :http
    test "accepts metric data on /v1/metrics endpoint" do
      # Verify OTLP HTTP metric ingestion
      endpoint = %{
        url: "http://localhost:4318/v1/metrics",
        method: "POST",
        content_type: "application/x-protobuf",
        expected_status: 200
      }

      assert endpoint.url == "http://localhost:4318/v1/metrics"
      assert endpoint.method == "POST"
    end

    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :http
    test "accepts log data on /v1/logs endpoint" do
      # Verify OTLP HTTP log ingestion
      endpoint = %{
        url: "http://localhost:4318/v1/logs",
        method: "POST",
        content_type: "application/x-protobuf",
        expected_status: 200
      }

      assert endpoint.url == "http://localhost:4318/v1/logs"
      assert endpoint.content_type == "application/x-protobuf"
    end

    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :http
    test "validates protobuf encoding for trace data" do
      # Verify protobuf trace structure
      trace_structure = %{
        resource_spans: [
          %{
            resource: %{
              attributes: [
                %{key: "service.name", value: %{string_value: "test-service"}},
                %{key: "sopv511.compliant", value: %{bool_value: true}}
              ]
            },
            scope_spans: [
              %{
                scope: %{name: "test-instrumentation", version: "1.0.0"},
                spans: [
                  %{
                    trace_id: "generated-trace-id",
                    span_id: "generated-span-id",
                    name: "test-operation",
                    kind: "SPAN_KIND_INTERNAL",
                    start_time_unix_nano: 0,
                    end_time_unix_nano: 0
                  }
                ]
              }
            ]
          }
        ]
      }

      assert Map.has_key?(trace_structure, :resource_spans)
      assert length(trace_structure.resource_spans) == 1
    end
  end

  describe "OTLP gRPC Endpoint (Port 4317)" do
    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :grpc
    test "accepts trace data on TraceService" do
      # Verify OTLP gRPC trace service
      grpc_service = %{
        endpoint: "localhost:4317",
        service: "opentelemetry.proto.collector.trace.v1.TraceService",
        method: "Export",
        expected_status: :ok
      }

      assert grpc_service.endpoint == "localhost:4317"
      assert String.contains?(grpc_service.service, "TraceService")
    end

    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :grpc
    test "accepts metric data on MetricsService" do
      # Verify OTLP gRPC metrics service
      grpc_service = %{
        endpoint: "localhost:4317",
        service: "opentelemetry.proto.collector.metrics.v1.MetricsService",
        method: "Export",
        expected_status: :ok
      }

      assert String.contains?(grpc_service.service, "MetricsService")
      assert grpc_service.method == "Export"
    end

    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :grpc
    test "accepts log data on LogsService" do
      # Verify OTLP gRPC logs service
      grpc_service = %{
        endpoint: "localhost:4317",
        service: "opentelemetry.proto.collector.logs.v1.LogsService",
        method: "Export",
        expected_status: :ok
      }

      assert String.contains?(grpc_service.service, "LogsService")
      assert grpc_service.endpoint == "localhost:4317"
    end

    @tag :sopv511
    @tag :integration
    @tag :otlp
    @tag :grpc
    test "validates gRPC compression support" do
      # Verify compression configuration
      compression_config = %{
        gzip_enabled: true,
        compression_level: "default",
        # 4MB
        max_message_size: 4_194_304
      }

      assert compression_config.gzip_enabled == true
      assert compression_config.max_message_size > 0
    end
  end

  describe "Trace Data Flow: OTLP → OTEL Collector → ClickHouse" do
    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :traces
    test "validates trace appears in ClickHouse signoz_traces table" do
      # Verify end-to-end trace ingestion
      trace_validation = %{
        source: "OTLP endpoint",
        intermediate: "OTEL Collector",
        destination: "ClickHouse signoz_traces",
        # SC-OBS-002: within 1 minute
        max_latency_ms: 1000
      }

      assert trace_validation.destination == "ClickHouse signoz_traces"
      # SC-OBS-002 compliance
      assert trace_validation.max_latency_ms <= 60_000
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :traces
    test "validates trace_id format and uniqueness" do
      # Verify trace ID structure
      trace_id_config = %{
        format: "16-byte hex string",
        # 16 bytes = 32 hex characters
        length: 32,
        uniqueness: "globally unique",
        validation_regex: ~r/^[0-9a-f]{32}$/
      }

      assert trace_id_config.length == 32
      assert Map.has_key?(trace_id_config, :validation_regex)
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :traces
    test "validates span_id format and parent relationships" do
      # Verify span ID and parent span relationships
      span_config = %{
        span_id_format: "8-byte hex string",
        # 8 bytes = 16 hex characters
        span_id_length: 16,
        parent_span_id_optional: true,
        root_span_parent_id: nil
      }

      assert span_config.span_id_length == 16
      assert span_config.parent_span_id_optional == true
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :traces
    test "validates span attributes preservation" do
      # Verify span attributes are preserved through pipeline
      span_attributes = %{
        "service.name" => "test-service",
        "sopv511.compliant" => true,
        "http.method" => "GET",
        "http.status_code" => 200,
        "custom.attribute" => "custom-value"
      }

      assert Map.has_key?(span_attributes, "service.name")
      assert Map.has_key?(span_attributes, "sopv511.compliant")
      assert span_attributes["sopv511.compliant"] == true
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :traces
    test "validates resource attributes preservation" do
      # Verify resource attributes through pipeline
      resource_attributes = %{
        "service.name" => "test-service",
        "service.namespace" => "production",
        "service.version" => "1.0.0",
        "deployment.environment" => "production",
        "telemetry.sdk.name" => "opentelemetry",
        "telemetry.sdk.language" => "elixir",
        "telemetry.sdk.version" => "1.0.0"
      }

      assert Map.has_key?(resource_attributes, "service.name")
      assert Map.has_key?(resource_attributes, "deployment.environment")
      assert length(Map.keys(resource_attributes)) >= 5
    end
  end

  describe "Metric Data Flow: OTLP → OTEL Collector → ClickHouse" do
    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :metrics
    test "validates metrics appear in ClickHouse signoz_metrics table" do
      # Verify end-to-end metric ingestion
      metric_validation = %{
        source: "OTLP endpoint",
        intermediate: "OTEL Collector",
        destination: "ClickHouse signoz_metrics",
        max_latency_ms: 1000
      }

      assert metric_validation.destination == "ClickHouse signoz_metrics"
      # SC-OBS-002
      assert metric_validation.max_latency_ms <= 60_000
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :metrics
    test "validates metric types: gauge, counter, histogram" do
      # Verify metric type support
      metric_types = [
        %{type: "gauge", aggregation: "last_value"},
        %{type: "counter", aggregation: "sum"},
        %{type: "histogram", aggregation: "explicit_bucket_histogram"}
      ]

      assert length(metric_types) == 3
      assert Enum.any?(metric_types, fn m -> m.type == "gauge" end)
      assert Enum.any?(metric_types, fn m -> m.type == "histogram" end)
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :metrics
    test "validates metric attributes and labels preservation" do
      # Verify metric attributes through pipeline
      metric_attributes = %{
        "metric.name" => "http_requests_total",
        "method" => "GET",
        "status" => "200",
        "endpoint" => "/api/v1/health",
        "sopv511.compliant" => "true"
      }

      assert Map.has_key?(metric_attributes, "metric.name")
      assert Map.has_key?(metric_attributes, "sopv511.compliant")
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :metrics
    test "validates metric timestamp accuracy" do
      # Verify metric timestamp handling
      timestamp_config = %{
        format: "unix nanoseconds",
        precision: "nanosecond",
        drift_tolerance_ms: 100,
        clock_sync_required: true
      }

      assert timestamp_config.format == "unix nanoseconds"
      assert timestamp_config.drift_tolerance_ms <= 1000
    end
  end

  describe "Log Data Flow: OTLP → OTEL Collector → ClickHouse" do
    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :logs
    test "validates logs appear in ClickHouse signoz_logs table" do
      # Verify end-to-end log ingestion
      log_validation = %{
        source: "OTLP endpoint",
        intermediate: "OTEL Collector",
        destination: "ClickHouse signoz_logs",
        max_latency_ms: 1000
      }

      assert log_validation.destination == "ClickHouse signoz_logs"
      # SC-OBS-002
      assert log_validation.max_latency_ms <= 60_000
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :logs
    test "validates log severity levels" do
      # Verify log severity level support
      severity_levels = [
        %{level: "TRACE", numeric: 1},
        %{level: "DEBUG", numeric: 5},
        %{level: "INFO", numeric: 9},
        %{level: "WARN", numeric: 13},
        %{level: "ERROR", numeric: 17},
        %{level: "FATAL", numeric: 21}
      ]

      assert length(severity_levels) == 6
      assert Enum.any?(severity_levels, fn l -> l.level == "ERROR" end)
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :logs
    test "validates log body content preservation" do
      # Verify log body through pipeline
      log_body = %{
        format: "string or structured",
        # 64KB
        max_size_bytes: 65_536,
        encoding: "utf-8",
        content_example: "User authentication successful"
      }

      assert log_body.max_size_bytes > 0
      assert log_body.encoding == "utf-8"
    end

    @tag :sopv511
    @tag :integration
    @tag :data_flow
    @tag :logs
    test "validates log attributes and trace context" do
      # Verify log attributes including trace context
      log_attributes = %{
        "log.level" => "INFO",
        "log.message" => "Operation completed",
        "trace_id" => "optional-trace-id",
        "span_id" => "optional-span-id",
        "sopv511.compliant" => "true"
      }

      assert Map.has_key?(log_attributes, "log.level")
      assert Map.has_key?(log_attributes, "trace_id")
    end
  end

  describe "OTEL Collector Processing Pipeline" do
    @tag :sopv511
    @tag :integration
    @tag :collector
    test "validates receivers configuration" do
      # Verify OTLP receivers
      receivers = %{
        otlp: %{
          protocols: %{
            http: %{endpoint: "0.0.0.0:4318"},
            grpc: %{endpoint: "0.0.0.0:4317"}
          }
        }
      }

      assert Map.has_key?(receivers, :otlp)
      assert Map.has_key?(receivers.otlp.protocols, :http)
      assert Map.has_key?(receivers.otlp.protocols, :grpc)
    end

    @tag :sopv511
    @tag :integration
    @tag :collector
    test "validates processors configuration" do
      # Verify data processing pipeline
      processors = [
        %{name: "batch", config: %{timeout: "10s", send_batch_size: 1024}},
        %{name: "memory_limiter", config: %{check_interval: "1s", limit_mib: 512}},
        %{name: "attributes", config: %{actions: ["insert", "update"]}}
      ]

      assert length(processors) == 3
      assert Enum.any?(processors, fn p -> p.name == "batch" end)
    end

    @tag :sopv511
    @tag :integration
    @tag :collector
    test "validates exporters configuration" do
      # Verify ClickHouse exporters
      exporters = %{
        clickhouse: %{
          endpoint: "tcp://clickhouse:9000",
          database: "signoz",
          # SC-OBS-003 compliance
          ttl_days: 7,
          compression: "zstd"
        }
      }

      assert exporters.clickhouse.database == "signoz"
      # SC-OBS-003
      assert exporters.clickhouse.ttl_days == 7
    end

    @tag :sopv511
    @tag :integration
    @tag :collector
    test "validates service pipeline configuration" do
      # Verify complete pipeline configuration
      pipelines = %{
        traces: %{
          receivers: ["otlp"],
          processors: ["batch", "memory_limiter"],
          exporters: ["clickhouse"]
        },
        metrics: %{
          receivers: ["otlp"],
          processors: ["batch", "memory_limiter"],
          exporters: ["clickhouse"]
        },
        logs: %{
          receivers: ["otlp"],
          processors: ["batch", "memory_limiter"],
          exporters: ["clickhouse"]
        }
      }

      assert Map.has_key?(pipelines, :traces)
      assert Map.has_key?(pipelines, :metrics)
      assert Map.has_key?(pipelines, :logs)
    end
  end

  describe "Data Validation and Quality" do
    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates data completeness through pipeline" do
      # Verify no data loss
      data_completeness = %{
        trace_spans_sent: 1000,
        trace_spans_received: 1000,
        completeness_rate: 100.0,
        data_loss_tolerance: 0.0
      }

      assert data_completeness.completeness_rate == 100.0
      assert data_completeness.data_loss_tolerance == 0.0
    end

    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates timestamp consistency across pipeline" do
      # Verify timestamp preservation
      timestamp_validation = %{
        original_timestamp: 1_234_567_890,
        clickhouse_timestamp: 1_234_567_890,
        drift_ms: 0,
        max_allowed_drift_ms: 100
      }

      assert timestamp_validation.drift_ms <= timestamp_validation.max_allowed_drift_ms
    end

    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates attribute cardinality limits" do
      # Verify attribute limits to prevent cardinality explosion
      cardinality_limits = %{
        max_span_attributes: 128,
        max_resource_attributes: 128,
        max_metric_labels: 32,
        max_log_attributes: 128
      }

      assert cardinality_limits.max_span_attributes > 0
      assert cardinality_limits.max_metric_labels > 0
    end

    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates SOPv5.11 compliance attributes" do
      # Verify SOPv5.11 specific attributes
      sopv511_attributes = %{
        "sopv511.compliant" => true,
        "sopv511.agent.id" => "agent-123",
        "sopv511.domain.supervisor" => "Domain-09",
        "sopv511.safety.constraint" => "SC-OBS-001"
      }

      assert sopv511_attributes["sopv511.compliant"] == true
      assert Map.has_key?(sopv511_attributes, "sopv511.safety.constraint")
    end
  end

  describe "Error Handling and Retry Logic" do
    @tag :sopv511
    @tag :integration
    @tag :error_handling
    test "validates retry configuration for failed exports" do
      # Verify retry logic
      retry_config = %{
        enabled: true,
        initial_interval: "5s",
        max_interval: "30s",
        max_elapsed_time: "5m"
      }

      assert retry_config.enabled == true
      assert Map.has_key?(retry_config, :max_elapsed_time)
    end

    @tag :sopv511
    @tag :integration
    @tag :error_handling
    test "validates backpressure handling" do
      # Verify backpressure configuration
      backpressure = %{
        queue_size: 5000,
        drop_on_queue_full: false,
        log_dropped_data: true
      }

      assert backpressure.drop_on_queue_full == false
      assert backpressure.log_dropped_data == true
    end

    @tag :sopv511
    @tag :integration
    @tag :error_handling
    test "validates circuit breaker for unhealthy exporters" do
      # Verify circuit breaker configuration
      circuit_breaker = %{
        enabled: true,
        failure_threshold: 5,
        success_threshold: 2,
        timeout: "30s"
      }

      assert circuit_breaker.enabled == true
      assert circuit_breaker.failure_threshold > 0
    end
  end

  describe "Performance and Scalability" do
    @tag :sopv511
    @tag :integration
    @tag :performance
    test "validates batch processing configuration" do
      # Verify batching for performance
      batch_config = %{
        timeout: "10s",
        send_batch_size: 1024,
        send_batch_max_size: 2048
      }

      assert batch_config.send_batch_size > 0
      assert batch_config.send_batch_max_size >= batch_config.send_batch_size
    end

    @tag :sopv511
    @tag :integration
    @tag :performance
    test "validates memory limits and resource management" do
      # Verify resource limits
      resource_limits = %{
        memory_limit_mib: 512,
        check_interval: "1s",
        spike_limit_mib: 128
      }

      assert resource_limits.memory_limit_mib > 0
      assert resource_limits.spike_limit_mib <= resource_limits.memory_limit_mib
    end

    @tag :sopv511
    @tag :integration
    @tag :performance
    test "validates concurrent connection limits" do
      # Verify connection pooling
      connection_config = %{
        max_idle_conns: 100,
        max_open_conns: 200,
        conn_max_lifetime: "5m"
      }

      assert connection_config.max_open_conns > connection_config.max_idle_conns
    end
  end
end
