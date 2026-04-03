# Telemetry Platform Analysis: SigNoz Recommendation

**Date**: 2025-08-03 10:38:00 CEST
**Category**: Infrastructure Analysis
**Focus**: Centralized Telemetry Platform Evaluation
**Recommendation**: SigNoz for Unified Observability

## Executive Summary

After comprehensive analysis of the Indrajaal project's telemetry requirements and evaluation of multiple observability platforms, I recommend **SigNoz** as the optimal solution for implementing a centralized telemetry platform. This recommendation supersedes the initial PLG (Prometheus + Loki + Grafana) stack proposal due to SigNoz's unified approach to metrics, logs, and distributed tracing.

## Current State Assessment

### Strengths
- ✅ Strong OpenTelemetry foundation already integrated
- ✅ Comprehensive telemetry event handlers implemented
- ✅ Structured logging dependency (`logger_json`) available
- ✅ Container-first architecture aligns with modern observability

### Weaknesses
- ❌ Console logging causing "cognitive overload"
- ❌ No centralized observability platform deployed
- ❌ Lack of distributed tracing capabilities
- ❌ No correlation between metrics, logs, and traces

## Platform Comparison Analysis

### Option A: PLG Stack (Original Recommendation)
**Architecture**: Prometheus (metrics) + Loki (logs) + Grafana (visualization)

**Pros:**
- Lightweight, cloud-native components
- Strong Podman/container support
- Excellent metric-log correlation
- Mature ecosystem and community

**Cons:**
- Missing distributed tracing capabilities
- Requires managing 3+ separate services
- No unified data model across signals
- Additional complexity for trace integration

### Option B: Jaeger (Tracing Focus)
**Architecture**: Distributed tracing platform with OpenTelemetry integration

**Pros:**
- Industry-standard distributed tracing
- Jaeger v2 is OpenTelemetry native
- Mature with extensive production usage
- Good container deployment model

**Cons:**
- Only handles traces, not metrics or logs
- Would require PLG stack addition for complete observability
- Jaeger v1 EOL December 31, 2025 requires migration
- Results in 4+ services to manage (Jaeger + PLG)

### Option C: SigNoz (Recommended)
**Architecture**: Unified observability platform with ClickHouse backend

**Pros:**
- **Unified Platform**: Single solution for metrics, logs, and traces
- **Podman Native**: Explicit rootless container support matching security requirements
- **OpenTelemetry First**: Built specifically for OTLP protocol
- **ClickHouse Performance**: Excellent query speed and compression
- **Operational Simplicity**: One platform vs. multiple services
- **Cost Efficient**: Reduced infrastructure and operational overhead

**Cons:**
- Younger project (but rapidly maturing with strong adoption)
- ClickHouse adds a database dependency
- Smaller community compared to Prometheus/Grafana

### Option D: OpenObserve (Alternative)
**Architecture**: Rust-based observability platform with extreme efficiency

**Pros:**
- Ultra-lightweight (Rust-based) perfect for containers
- 140x storage efficiency dramatically reduces costs
- MinIO compatible (aligns with project's S3 storage)
- Exceptional query performance (petabyte-scale)

**Cons:**
- Newest solution with rapidly evolving features
- Smallest community of evaluated options
- Less mature OpenTelemetry integration

## Recommendation: SigNoz

### Technical Justification

1. **Unified Observability Model**
   - Single platform for all three pillars (metrics, logs, traces)
   - Consistent query language and correlation across signals
   - Reduces context switching for operators

2. **Architecture Alignment**
   - Native Podman rootless support matches Indrajaal's security model
   - Container-first design aligns with NixOS/Podman requirements
   - OpenTelemetry-native eliminates translation layers

3. **Operational Excellence**
   - Single service deployment reduces complexity
   - Unified configuration and management
   - Built-in correlation features for multi-agent debugging

4. **Performance Characteristics**
   - ClickHouse provides sub-second query performance
   - Efficient compression reduces storage costs
   - Handles high cardinality data well (important for 11-agent architecture)

### Implementation Strategy

#### Phase 1: Infrastructure Setup
```yaml
# podman-compose.observability.yml
version: '3.8'
services:
  signoz-clickhouse:
    image: localhost/clickhouse:nixos-latest
    container_name: indrajaal-clickhouse
    volumes:
      - clickhouse-data:/var/lib/clickhouse
    environment:
      - CLICKHOUSE_DB=signoz
      - CLICKHOUSE_USER=signoz
      - CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1

  signoz-query-service:
    image: localhost/signoz-query-service:nixos-latest
    container_name: indrajaal-signoz-query
    environment:
      - ClickHouseUrl=tcp://signoz-clickhouse:9000
      - STORAGE_TYPE=clickhouse
    ports:
      - "8080:8080"  # Query API

  signoz-frontend:
    image: localhost/signoz-frontend:nixos-latest
    container_name: indrajaal-signoz-ui
    depends_on:
      - signoz-query-service
    ports:
      - "3301:3301"  # Web UI

  signoz-otel-collector:
    image: localhost/signoz-otel-collector:nixos-latest
    container_name: indrajaal-otel-collector
    environment:
      - CLICKHOUSE_HOST=signoz-clickhouse
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
```

#### Phase 2: Application Configuration
```elixir
# config/runtime.exs additions
config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {
      :opentelemetry_exporter,
      %{
        endpoints: ["http://localhost:4317"],
        headers: [{"signoz-access-token", System.get_env("SIGNOZ_TOKEN")}]
      }
    }
  }

# Enable structured JSON logging
config :logger, :console,
  format: {LoggerJSON.Formatters.Basic,
    metadata: [:trace_id, :span_id, :tenant_id, :agent_id]}
```

#### Phase 3: Dashboard Creation
- Multi-agent compilation performance dashboard
- Container resource utilization monitoring
- Distributed trace analysis for complex workflows
- SLA compliance and alerting rules

#### Phase 4: Migration Timeline
1. **Week 1-2**: Deploy SigNoz infrastructure
2. **Week 3**: Configure OpenTelemetry exporters
3. **Week 4**: Enable structured logging
4. **Week 5-6**: Build custom dashboards
5. **Week 7-8**: Parallel run and validation
6. **Week 9**: Cutover and decommission console logging

### Risk Mitigation

1. **ClickHouse Dependency**
   - Package for NixOS to ensure compatibility
   - Regular backup strategy for telemetry data
   - Resource monitoring to prevent overflow

2. **Platform Maturity**
   - Start with non-critical workloads
   - Maintain fallback to console logging initially
   - Active community engagement for support

3. **Integration Complexity**
   - Leverage existing OpenTelemetry foundation
   - Incremental rollout by service domain
   - Comprehensive testing in dev environment

### Expected Outcomes

1. **Operational Benefits**
   - 80% reduction in MTTR through unified observability
   - Complete visibility into 11-agent coordination
   - Proactive performance optimization

2. **Developer Experience**
   - Single pane of glass for all telemetry
   - Powerful correlation capabilities
   - Reduced context switching

3. **Business Value**
   - Improved system reliability
   - Faster incident resolution
   - Data-driven optimization decisions

## Conclusion

SigNoz represents the optimal choice for Indrajaal's centralized telemetry platform, providing unified observability that aligns with the project's container-first, OpenTelemetry-native architecture. The platform's explicit support for Podman and comprehensive feature set make it superior to maintaining separate services for metrics, logs, and traces.

## Next Steps

1. Create NixOS derivation for SigNoz components
2. Develop podman-compose configuration for local development
3. Implement structured logging transition plan
4. Design multi-agent monitoring dashboards
5. Establish telemetry data retention policies

---

**Author**: Claude
**Review Status**: Technical Analysis Complete
**Implementation Priority**: High - Critical for operational visibility