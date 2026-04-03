# Comprehensive Test and Verification Plan for Complete SigNoz Integration

**Date**: 2025-08-03
**Status**: Implementation Plan
**Frameworks**: TDG, STAMP, GDE

## Executive Summary
This plan ensures 100% integration of SigNoz observability platform with all 19 Ash domains and supporting modules in the Indrajaal Security Monitoring System. The plan follows TDG, STAMP, and GDE methodologies to systematically verify that all logging and observability information flows correctly to SigNoz.

## Phase 1: Integration Verification Tests (TDG)

### 1.1 Domain-Specific Integration Tests
Create comprehensive integration tests for each of the 19 domains:

**Test Files to Create:**
```
test/observability/integration/
├── core_domain_signoz_test.exs          # Core (Tenant, Organization)
├── accounts_domain_signoz_test.exs      # Accounts (User, Session, Auth)
├── sites_domain_signoz_test.exs         # Sites (Site, Zone, Location)
├── devices_domain_signoz_test.exs       # Devices (Device, DeviceType)
├── alarms_domain_signoz_test.exs        # Alarms (Alarm, Incident)
├── video_domain_signoz_test.exs         # Video (Camera, Recording)
├── access_control_signoz_test.exs       # Access Control (Access, Credential)
├── policy_domain_signoz_test.exs        # Policy (Role, Permission)
├── billing_domain_signoz_test.exs       # Billing (Subscription, Invoice)
├── compliance_domain_signoz_test.exs    # Compliance (Assessment, Audit)
├── communication_signoz_test.exs        # Communication (Notification)
├── analytics_domain_signoz_test.exs     # Analytics (Dashboard, Report)
├── maintenance_domain_signoz_test.exs   # Maintenance (WorkOrder, Schedule)
├── dispatch_domain_signoz_test.exs      # Dispatch (Responder, Incident)
├── visitor_management_signoz_test.exs   # Visitor Management
├── guard_tour_signoz_test.exs           # Guard Tour (Checkpoint, Tour)
├── risk_management_signoz_test.exs      # Risk Management
├── asset_management_signoz_test.exs     # Asset Management
└── integrations_signoz_test.exs         # External Integrations
```

### 1.2 Cross-Domain Integration Tests
```
test/observability/integration/
├── multi_domain_correlation_test.exs    # Cross-domain trace correlation
├── tenant_isolation_test.exs            # Multi-tenant data isolation
├── end_to_end_workflow_test.exs        # Complete business workflows
└── performance_baseline_test.exs        # Performance impact validation
```

### 1.3 Infrastructure Integration Tests
```
test/observability/infrastructure/
├── telemetry_handler_test.exs          # Telemetry event handling
├── logging_module_test.exs             # Structured logging
├── tracing_module_test.exs             # OpenTelemetry tracing
├── oban_job_tracing_test.exs          # Background job telemetry
├── phoenix_endpoint_test.exs           # HTTP request tracing
└── ecto_query_tracing_test.exs        # Database query telemetry
```

## Phase 2: Module Enhancement Implementation

### 2.1 Telemetry Handler Enhancements
**File: lib/indrajaal/telemetry.ex**
- Add OpenTelemetry span creation for all event handlers
- Ensure trace_id propagation in all telemetry events
- Add SigNoz-specific attributes to all events

### 2.2 Logging Module Integration
**File: lib/indrajaal/logging.ex**
- Verify LoggerJSON formatter includes trace_id/span_id
- Add SigNoz service attributes to all log calls
- Ensure proper severity mapping for SigNoz

### 2.3 Tracing Module Updates
**File: lib/indrajaal/tracing.ex**
- Add SigNoz-specific span attributes
- Implement proper error recording for SigNoz
- Add business context attributes

### 2.4 Domain-Specific Instrumentation
For each domain module, ensure:
- All CRUD operations have trace spans
- Business events emit telemetry with SigNoz attributes
- Error handling includes proper span status
- Tenant context is propagated

## Phase 3: Verification Test Suites

### 3.1 Data Flow Verification
```elixir
# Verify each domain sends data to SigNoz
test "#{domain}_operations_appear_in_signoz" do
  # Create domain entity
  # Verify trace in SigNoz
  # Verify logs in SigNoz
  # Verify metrics in SigNoz
end
```

### 3.2 Correlation Verification
```elixir
# Verify trace correlation across domains
test "cross_domain_trace_correlation" do
  # Start user session (Accounts)
  # Create alarm (Alarms)
  # Dispatch responder (Dispatch)
  # Verify single trace ID spans all operations
end
```

### 3.3 Performance Verification
```elixir
# Verify performance goals
test "signoz_integration_performance_impact" do
  # Baseline without telemetry
  # Measure with full telemetry
  # Assert < 10% overhead (GDE Goal G3)
end
```

## Phase 4: STAMP Safety Validation

### 4.1 Data Loss Prevention (SC1)
- Test telemetry during SigNoz outages
- Verify buffering and retry mechanisms
- Validate no critical data loss

### 4.2 Tenant Isolation (SC2)
- Test multi-tenant query isolation
- Verify tenant headers in all telemetry
- Validate cross-tenant data protection

### 4.3 Resource Protection (SC3)
- Test memory usage under high telemetry load
- Verify CPU impact stays within limits
- Validate storage growth rates

## Phase 5: Complete System Validation

### 5.1 End-to-End Scenarios
1. **Security Incident Flow**
   - Alarm triggered → Investigation → Response → Resolution
   - Verify complete observability throughout

2. **Access Control Flow**
   - Badge scan → Authorization → Access grant/deny → Audit
   - Verify all events traced and logged

3. **Video Analytics Flow**
   - Motion detection → Recording → Analytics → Alert
   - Verify video system telemetry

### 5.2 Dashboard Validation
- Import all domain-specific dashboards
- Verify real-time data updates
- Test alert configurations
- Validate custom queries

### 5.3 Production Readiness
- Load testing with realistic data volumes
- Chaos testing (network failures, restarts)
- Security audit of telemetry data
- Compliance validation (audit trails)

## Phase 6: Documentation and Training

### 6.1 Create Documentation
- Observability runbook
- Dashboard user guide
- Query examples for each domain
- Troubleshooting guide

### 6.2 Team Training
- SigNoz query language training
- Dashboard creation workshop
- Alert configuration training
- Performance analysis techniques

## Success Criteria

### Functional Requirements
- [ ] All 19 domains send traces to SigNoz
- [ ] All structured logs appear in SigNoz
- [ ] All business metrics available in SigNoz
- [ ] Cross-domain correlation working
- [ ] Multi-tenant isolation verified

### Performance Requirements (GDE Goals)
- [ ] P95 query latency < 2 seconds (G2)
- [ ] Telemetry overhead < 10% (G3)
- [ ] 99.9% availability maintained (G5)

### Safety Requirements (STAMP)
- [ ] No data loss during outages (SC1)
- [ ] Tenant isolation enforced (SC2)
- [ ] Resource limits respected (SC3)
- [ ] Alert delivery < 1 minute (SC4)

## Implementation Timeline

**Week 1-2**: Create all integration test files
**Week 3-4**: Implement module enhancements
**Week 5-6**: Run verification test suites
**Week 7**: Performance and safety validation
**Week 8**: Documentation and training

This comprehensive plan ensures complete integration of SigNoz with every aspect of the Indrajaal system, providing unified observability while maintaining performance and safety requirements.