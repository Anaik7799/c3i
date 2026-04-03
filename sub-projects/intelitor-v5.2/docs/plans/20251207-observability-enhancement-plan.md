# Comprehensive Observability Enhancement Plan

**Date**: 2025-12-07 15:45 CET (Updated: 2025-12-08 09:25 CET)
**Author**: Claude Code (Opus 4.5)
**Status**: IN PROGRESS
**SOPv5.11 Compliance**: Full alignment with STAMP SC-OBS-065 to SC-OBS-072

## Executive Summary

This plan outlines a comprehensive approach to achieve 95%+ observability coverage across all Indrajaal domains, web layers, background jobs, and infrastructure components. Current coverage is approximately 65%.

## Current State Assessment

### Coverage by Layer

| Layer | Current | Target | Gap |
|-------|---------|--------|-----|
| Domain Logic (instrumented) | 100% | 100% | 0% |
| Domain Logic (missing) | 0% | 100% | 100% |
| API Controllers | 28% | 95% | 67% |
| WebSocket Channels | 43% | 95% | 52% |
| LiveView Components | 40% | 95% | 55% |
| Background Jobs | 33% | 100% | 67% |
| HTTP Clients | 0% | 100% | 100% |
| Infrastructure | 50% | 95% | 45% |

### Domains Status

**Fully Instrumented (11)**:
- accounts, alarms, access_control, analytics, communication
- devices, guard_tours, maintenance, sites, video, visitor_management

**Missing Instrumentation (3)**:
- integration (0%)
- intelligence (0%)
- shifts (20%)

---

## 5-Level Task Hierarchy

### 14.0 - Comprehensive Observability Enhancement (P1 - Critical)
**Status**: in_progress | **Priority**: P1
**Target**: 95%+ observability coverage

---

### 14.1 - Phase 1: Critical Domain Instrumentation (P1 - Critical)
**Status**: in_progress | **Priority**: P1 | **Parent**: 14.0

#### 14.1.1 - Integration Domain Instrumentation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.1
**File**: `lib/indrajaal/observability/domains/integration_instrumentation.ex`

##### 14.1.1.1 - Create integration instrumentation module
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Tasks**:
- Create module with `use Indrajaal.Observability.DomainInstrumentation`
- Define telemetry event prefixes
- Implement setup/0 function

##### 14.1.1.2 - Implement external API telemetry events
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Events**:
- `[:indrajaal, :integration, :external_api, :request_start]`
- `[:indrajaal, :integration, :external_api, :request_stop]`
- `[:indrajaal, :integration, :external_api, :error]`

##### 14.1.1.3 - Implement webhook telemetry events
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Events**:
- `[:indrajaal, :integration, :webhook, :received]`
- `[:indrajaal, :integration, :webhook, :processed]`

##### 14.1.1.4 - Implement data sync telemetry events
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Events**:
- `[:indrajaal, :integration, :data_sync, :start]`
- `[:indrajaal, :integration, :data_sync, :stop]`

##### 14.1.1.5 - Implement rate limit and retry telemetry
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Events**:
- `[:indrajaal, :integration, :rate_limit, :exceeded]`
- `[:indrajaal, :integration, :retry, :attempt]`

##### 14.1.1.6 - Add OpenTelemetry tracing spans
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Spans**:
- `integration.external_request` (root)
- `integration.request_preparation`
- `integration.request_execution`
- `integration.response_parsing`
- `integration.error_handling`

##### 14.1.1.7 - Write unit tests for integration instrumentation
**Status**: in_progress | **Priority**: P1 | **Parent**: 14.1.1
**File**: `test/indrajaal/observability/domains/integration_instrumentation_test.exs`
**Tests Required**:
- Telemetry event emission verification
- Log message format validation
- Trace context propagation check
- Metadata completeness verification
- Error scenario coverage

##### 14.1.1.8 - Compile and verify integration instrumentation module
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Verification Steps**:
- Run `mix compile --warnings-as-errors` for module compilation
- Verify module loads correctly: `Code.ensure_loaded!(Indrajaal.Observability.Domains.IntegrationInstrumentation)`
- Test setup/0 function executes without error
- Verify telemetry handlers attach correctly
- Run runtime verification: emit test events and verify handlers receive them

##### 14.1.1.9 - Runtime verification for integration instrumentation
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.1
**Runtime Checks**:
- Verify telemetry event emission works at runtime
- Verify Logger.info/Logger.warning output format
- Verify tracing spans create correctly with OpenTelemetry
- Verify metadata enrichment functions work
- Verify ID generation functions produce valid output

#### 14.1.2 - Intelligence Domain Instrumentation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.1
**File**: `lib/indrajaal/observability/domains/intelligence_instrumentation.ex`

##### 14.1.2.1 - Create intelligence instrumentation module
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2

##### 14.1.2.2 - Implement threat detection telemetry
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**Events**:
- `[:indrajaal, :intelligence, :threat_detection, :score]`
- `[:indrajaal, :intelligence, :anomaly_detection, :triggered]`

##### 14.1.2.3 - Implement ML model telemetry
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**Events**:
- `[:indrajaal, :intelligence, :ml_model, :inference_start]`
- `[:indrajaal, :intelligence, :ml_model, :inference_stop]`

##### 14.1.2.4 - Implement alert telemetry
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**Events**:
- `[:indrajaal, :intelligence, :alert_correlation, :found]`
- `[:indrajaal, :intelligence, :predictive_alert, :issued]`
- `[:indrajaal, :intelligence, :false_positive, :detected]`

##### 14.1.2.5 - Add OpenTelemetry tracing spans
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**Spans**:
- `intelligence.threat_analysis` (root)
- `intelligence.data_collection`
- `intelligence.model_inference`
- `intelligence.score_calculation`
- `intelligence.alert_generation`

##### 14.1.2.6 - Write unit tests for intelligence instrumentation
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**File**: `test/indrajaal/observability/domains/intelligence_instrumentation_test.exs`
**Tests Required**:
- Telemetry event emission verification for threat detection
- Telemetry event emission verification for ML model inference
- Telemetry event emission verification for alerts
- Log message format validation
- Trace context propagation check
- Metadata completeness verification
- Error scenario coverage

##### 14.1.2.7 - Compile and verify intelligence instrumentation module
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**Verification Steps**:
- Run `mix compile --warnings-as-errors` for module compilation
- Verify module loads correctly: `Code.ensure_loaded!(Indrajaal.Observability.Domains.IntelligenceInstrumentation)`
- Test setup/0 function executes without error
- Verify telemetry handlers attach correctly
- Run runtime verification: emit test events and verify handlers receive them

##### 14.1.2.8 - Runtime verification for intelligence instrumentation
**Status**: pending | **Priority**: P1 | **Parent**: 14.1.2
**Runtime Checks**:
- Verify threat detection telemetry events emit correctly
- Verify ML model inference telemetry events emit correctly
- Verify alert telemetry events emit correctly
- Verify Logger output format for different log levels (info, warning, error)
- Verify tracing spans create correctly with nested span structure
- Verify metadata enrichment functions work
- Verify ID generation functions produce valid output (analysis_id, inference_id, etc.)

#### 14.1.3 - Shifts Domain Instrumentation (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.1
**File**: `lib/indrajaal/observability/domains/shifts_instrumentation.ex`

##### 14.1.3.1 - Create shifts instrumentation module
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3

##### 14.1.3.2 - Implement assignment telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3
**Events**:
- `[:indrajaal, :shifts, :assignment, :created]`
- `[:indrajaal, :shifts, :assignment, :updated]`
- `[:indrajaal, :shifts, :assignment, :deleted]`

##### 14.1.3.3 - Implement time tracking telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3
**Events**:
- `[:indrajaal, :shifts, :time_tracking, :start]`
- `[:indrajaal, :shifts, :time_tracking, :stop]`
- `[:indrajaal, :shifts, :break, :taken]`
- `[:indrajaal, :shifts, :break, :cancelled]`

##### 14.1.3.4 - Implement conflict detection telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3
**Events**:
- `[:indrajaal, :shifts, :conflict, :detected]`
- `[:indrajaal, :shifts, :availability, :updated]`

##### 14.1.3.5 - Write unit tests for shifts instrumentation
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3

##### 14.1.3.6 - Compile and verify shifts instrumentation module
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3
**Verification Steps**:
- Run `mix compile --warnings-as-errors` for module compilation
- Verify module loads correctly
- Test setup/0 function executes without error
- Verify telemetry handlers attach correctly

##### 14.1.3.7 - Runtime verification for shifts instrumentation
**Status**: pending | **Priority**: P2 | **Parent**: 14.1.3
**Runtime Checks**:
- Verify assignment telemetry events emit correctly
- Verify time tracking telemetry events emit correctly
- Verify conflict detection telemetry events emit correctly
- Verify Logger output format
- Verify metadata enrichment functions work

---

### 14.2 - Phase 2: Web Layer Instrumentation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.0

#### 14.2.1 - API Controller Instrumentation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.2
**Target**: 28 controllers

##### 14.2.1.1 - Create base controller instrumentation module
**Status**: pending | **Priority**: P1 | **Parent**: 14.2.1
**File**: `lib/indrajaal_web/plugs/api_instrumentation_plug.ex`

##### 14.2.1.2 - Instrument video controllers (5 controllers)
**Status**: pending | **Priority**: P1 | **Parent**: 14.2.1
**Controllers**: video_analytics, video_retention, video_streams, video_privacy, video_recording

##### 14.2.1.3 - Instrument device/location controllers (3 controllers)
**Status**: pending | **Priority**: P1 | **Parent**: 14.2.1
**Controllers**: device_groups, locations, zones

##### 14.2.1.4 - Instrument integration/intelligence controllers (2 controllers)
**Status**: pending | **Priority**: P1 | **Parent**: 14.2.1
**Controllers**: integration, intelligence

##### 14.2.1.5 - Instrument operational controllers (6 controllers)
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.1
**Controllers**: fleet_management, environmental, training, compliance, reports, schedules

##### 14.2.1.6 - Instrument user/permission controllers (5 controllers)
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.1
**Controllers**: users, roles, permissions, tenants, settings

##### 14.2.1.7 - Instrument remaining controllers (7 controllers)
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.1
**Controllers**: notifications, audit, dashboard, assets, incidents, patrols, base_config

#### 14.2.2 - WebSocket Channel Instrumentation (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.2
**Target**: 4 channels

##### 14.2.2.1 - Create channel instrumentation base module
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.2

##### 14.2.2.2 - Instrument sync_channel
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.2

##### 14.2.2.3 - Instrument config_channel
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.2

##### 14.2.2.4 - Instrument notification_channel
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.2

##### 14.2.2.5 - Instrument mobile_socket
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.2

#### 14.2.3 - LiveView Component Instrumentation (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.2
**Target**: 3 components

##### 14.2.3.1 - Create LiveView instrumentation hook
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.3

##### 14.2.3.2 - Instrument permissions_management_live
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.3

##### 14.2.3.3 - Instrument access_control_monitoring_live
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.3

##### 14.2.3.4 - Instrument monitoring_dashboard_live
**Status**: pending | **Priority**: P2 | **Parent**: 14.2.3

---

### 14.3 - Phase 3: Background Job Instrumentation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.0

#### 14.3.1 - Oban Worker Instrumentation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.3

##### 14.3.1.1 - Create Oban worker instrumentation base
**Status**: pending | **Priority**: P1 | **Parent**: 14.3.1

##### 14.3.1.2 - Instrument alarm_escalation worker
**Status**: pending | **Priority**: P1 | **Parent**: 14.3.1

##### 14.3.1.3 - Instrument alarm_correlation worker
**Status**: pending | **Priority**: P1 | **Parent**: 14.3.1

##### 14.3.1.4 - Instrument alarm_auto_resolve worker
**Status**: pending | **Priority**: P1 | **Parent**: 14.3.1

##### 14.3.1.5 - Add queue metrics telemetry
**Status**: pending | **Priority**: P1 | **Parent**: 14.3.1

---

### 14.4 - Phase 4: Infrastructure Instrumentation (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.0

#### 14.4.1 - HTTP Client Instrumentation (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.4

##### 14.4.1.1 - Add request lifecycle telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.1

##### 14.4.1.2 - Add retry mechanism telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.1

##### 14.4.1.3 - Add connection pool telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.1

#### 14.4.2 - Circuit Breaker Enhancement (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.4

##### 14.4.2.1 - Add state transition telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.2

##### 14.4.2.2 - Add failure recording telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.2

##### 14.4.2.3 - Add recovery attempt telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.2

#### 14.4.3 - Rate Limiter Enhancement (P2 - High)
**Status**: pending | **Priority**: P2 | **Parent**: 14.4

##### 14.4.3.1 - Add check result telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.3

##### 14.4.3.2 - Add quota status telemetry
**Status**: pending | **Priority**: P2 | **Parent**: 14.4.3

#### 14.4.4 - Response Cache Instrumentation (P3 - Medium)
**Status**: pending | **Priority**: P3 | **Parent**: 14.4

##### 14.4.4.1 - Add cache hit/miss telemetry
**Status**: pending | **Priority**: P3 | **Parent**: 14.4.4

##### 14.4.4.2 - Add cache invalidation telemetry
**Status**: pending | **Priority**: P3 | **Parent**: 14.4.4

##### 14.4.4.3 - Add memory pressure telemetry
**Status**: pending | **Priority**: P3 | **Parent**: 14.4.4

---

### 14.5 - Phase 5: Advanced Observability Features (P3 - Medium)
**Status**: pending | **Priority**: P3 | **Parent**: 14.0

#### 14.5.1 - Business Impact Metrics (P3 - Medium)
**Status**: pending | **Priority**: P3 | **Parent**: 14.5

##### 14.5.1.1 - Implement alarm response time correlation
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.1

##### 14.5.1.2 - Implement user experience scoring
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.1

##### 14.5.1.3 - Implement system health composite index
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.1

##### 14.5.1.4 - Implement SLA compliance tracking
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.1

#### 14.5.2 - Cross-Domain Correlation (P3 - Medium)
**Status**: pending | **Priority**: P3 | **Parent**: 14.5

##### 14.5.2.1 - Implement request ID propagation
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.2

##### 14.5.2.2 - Implement tenant isolation tracking
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.2

##### 14.5.2.3 - Implement user journey tracing
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.2

##### 14.5.2.4 - Implement error chain analysis
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.2

#### 14.5.3 - Predictive Analytics Integration (P3 - Medium)
**Status**: pending | **Priority**: P3 | **Parent**: 14.5

##### 14.5.3.1 - Implement anomaly pattern detection
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.3

##### 14.5.3.2 - Implement capacity forecasting
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.3

##### 14.5.3.3 - Implement performance degradation prediction
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.3

##### 14.5.3.4 - Implement security threat trending
**Status**: pending | **Priority**: P3 | **Parent**: 14.5.3

---

### 14.6 - Observability Testing & Validation (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.0

#### 14.6.1 - Per-Instrumentation Testing (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.6

##### 14.6.1.1 - Create telemetry event test helpers
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.1

##### 14.6.1.2 - Implement event emission verification tests
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.1

##### 14.6.1.3 - Implement log format validation tests
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.1

##### 14.6.1.4 - Implement trace context propagation tests
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.1

##### 14.6.1.5 - Implement metadata completeness tests
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.1

#### 14.6.2 - Integration Testing (P1 - Critical)
**Status**: pending | **Priority**: P1 | **Parent**: 14.6

##### 14.6.2.1 - Implement end-to-end trace validation
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.2

##### 14.6.2.2 - Implement log aggregation verification
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.2

##### 14.6.2.3 - Implement metric collection accuracy tests
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.2

##### 14.6.2.4 - Implement alert triggering validation
**Status**: pending | **Priority**: P1 | **Parent**: 14.6.2

---

## Implementation Guidelines

### Telemetry Event Structure

```elixir
:telemetry.execute(
  [:indrajaal, :domain, :operation, :phase],
  %{
    duration: duration_ms,
    count: count,
    size_bytes: size
  },
  %{
    tenant_id: tenant_id,
    user_id: user_id,
    resource_id: resource_id,
    resource_type: resource_type,
    operation: operation,
    status: status
  }
)
```

### Logging Format

```elixir
Logger.info("Operation completed",
  domain: :domain_name,
  operation: :operation_name,
  resource_id: resource_id,
  tenant_id: tenant_id,
  user_id: user_id,
  duration_ms: duration,
  status: :success
)
```

### Tracing Pattern

```elixir
require OpenTelemetry.Tracer, as: Tracer

def operation(params) do
  Tracer.with_span "domain.operation" do
    Tracer.set_attributes([
      {"domain.resource_id", params.resource_id},
      {"domain.tenant_id", params.tenant_id}
    ])

    result = execute_operation(params)

    Tracer.add_event("operation.completed", %{
      status: :success,
      result_count: length(result)
    })

    result
  end
end
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Domain instrumentation coverage | 100% |
| API controller coverage | 95% |
| WebSocket channel coverage | 95% |
| Background job coverage | 100% |
| Infrastructure coverage | 95% |
| Trace context propagation | 100% |
| Dual logging compliance | 100% |
| STAMP SC-OBS compliance | 100% |

---

## References

- CLAUDE.md Section 13.0 (Dual Logging System)
- CLAUDE.md Section 45.0 (OpenTelemetry Integration)
- STAMP Constraints SC-OBS-065 to SC-OBS-072
- SOPv5.11 Phase 6 (Monitoring and Observability)
