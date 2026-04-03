# Distributed Tracing Configuration - SOPv5.1
# Generated: 2025-08-02 19:15:07.315433Z

tracing_config = %{
  tracer: :opentelemetry,
  sampling_rate: 0.1,
  propagation: [:tracecontext, :baggage],
  exporters: [:jaeger, :zipkin, :custom],
  trace_retention: "7 days",
  span_attributes: [:user_id, :tenant_id, :request_id, :service_name, :environment]
}
