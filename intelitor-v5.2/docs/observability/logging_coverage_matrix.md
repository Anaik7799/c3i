# Logging Coverage Matrix - Observability Audit

**Document Version**: 1.0
**Date**: 2025-01-23
**Audit Phase**: Phase 1, Task 1.1
**SOPv5.11 Compliance**: SC-OBS-001, SC-OBS-004

---

## Executive Summary

### Overall Findings
- **Total Logger Calls**: 2,535 across entire codebase
- **Domains with Logging**: 9 of 19 (47.4%)
- **Domains without Logging**: 10 of 19 (52.6%)
- **Critical Gap**: Over half the system lacks any observability instrumentation

### Severity Assessment
🔴 **CRITICAL**: 10 domains have **ZERO** logging, creating blind spots for:
- Incident response and debugging
- Audit trail compliance (SC-OBS-004)
- Anomaly detection (SC-OBS-002)
- 100% observability requirement (SC-OBS-001)

### Compliance Status
- ❌ **SC-OBS-001 VIOLATION**: 100% observability NOT achieved (52.6% domains have zero logging)
- ⚠️ **SC-OBS-004 PARTIAL**: Audit trail incomplete for 10 domains
- ⚠️ **SC-OBS-002 PARTIAL**: Anomaly detection impossible in 10 domains

---

## Domain Logging Statistics

### High Coverage Domains (>50 Logger calls)
| Domain | Logger Calls | Status | Priority |
|--------|-------------|--------|----------|
| alarms | 183 | ✅ Good | P3 - Enhance |
| communication | 53 | ✅ Good | P3 - Enhance |
| access_control | 50 | ✅ Good | P3 - Enhance |

**Analysis**: These domains have substantial logging infrastructure and can serve as reference implementations for other domains.

### Medium Coverage Domains (10-49 Logger calls)
| Domain | Logger Calls | Status | Priority |
|--------|-------------|--------|----------|
| analytics | 39 | ⚠️ Adequate | P2 - Improve |
| compliance | 12 | ⚠️ Adequate | P2 - Improve |
| accounts | 11 | ⚠️ Adequate | P2 - Improve |

**Analysis**: These domains have basic logging but need enhancement for complete observability coverage.

### Low Coverage Domains (1-9 Logger calls)
| Domain | Logger Calls | Status | Priority |
|--------|-------------|--------|----------|
| core | 1 | 🔴 Critical | P0 - Immediate |

**Analysis**: Core domain has only 1 Logger call despite being foundational infrastructure. This is a critical security and operational risk.

### Zero Coverage Domains (0 Logger calls)
| Domain | Logger Calls | Status | Priority | Business Impact |
|--------|-------------|--------|----------|-----------------|
| asset_management | 0 | 🔴 Critical | P0 - Immediate | Asset tracking blind spot |
| billing | 0 | 🔴 Critical | P0 - Immediate | Financial audit risk |
| devices | 0 | 🔴 Critical | P0 - Immediate | Hardware monitoring gap |
| dispatch | 0 | 🔴 Critical | P0 - Immediate | Response coordination blind |
| guard_tour | 0 | 🔴 Critical | P0 - Immediate | Patrol verification missing |
| integrations | 0 | 🔴 Critical | P0 - Immediate | External system failures invisible |
| maintenance | 0 | 🔴 Critical | P0 - Immediate | Work order tracking gap |
| policy | 0 | 🔴 Critical | P0 - Immediate | Compliance enforcement blind |
| risk_management | 0 | 🔴 Critical | P0 - Immediate | Risk assessment untracked |
| sites | 0 | 🔴 Critical | P0 - Immediate | Location management gap |
| video | 0 | 🔴 Critical | P0 - Immediate | Surveillance system blind |
| visitor_management | 0 | 🔴 Critical | P0 - Immediate | Access control incomplete |

**Analysis**: These 10 domains represent critical business functionality with ZERO observability. This creates:
- **Security Risk**: Unable to detect unauthorized access or anomalies
- **Compliance Risk**: No audit trail for regulatory requirements
- **Operational Risk**: Blind to failures and performance issues
- **Financial Risk**: Billing errors undetectable

---

## Critical Operations Inventory

### Operations Requiring Immediate Logging (P0)

#### billing Domain
- [ ] Invoice generation and processing
- [ ] Payment processing and validation
- [ ] Subscription lifecycle management
- [ ] Tax calculation and compliance
- [ ] Refund processing
- [ ] Billing dispute handling

#### devices Domain
- [ ] Device registration and provisioning
- [ ] Device health monitoring and alerts
- [ ] Firmware updates and rollbacks
- [ ] Device configuration changes
- [ ] Communication protocol handling
- [ ] Device failure detection and recovery

#### integrations Domain
- [ ] External API calls and responses
- [ ] Webhook delivery and retries
- [ ] Data synchronization operations
- [ ] Authentication with external systems
- [ ] Rate limiting and throttling
- [ ] Integration failure handling

#### video Domain
- [ ] Camera stream initialization
- [ ] Recording start/stop operations
- [ ] Motion detection events
- [ ] Video analytics processing
- [ ] Storage management
- [ ] Playback and export operations

#### guard_tour Domain
- [ ] Tour schedule creation and updates
- [ ] Checkpoint scanning events
- [ ] Tour completion validation
- [ ] Missed checkpoint alerts
- [ ] Tour report generation

#### visitor_management Domain
- [ ] Visitor registration and check-in
- [ ] Access credential generation
- [ ] Visitor checkout and exit
- [ ] Host notification events
- [ ] Emergency visitor evacuation

#### asset_management Domain
- [ ] Asset registration and tagging
- [ ] Asset location tracking
- [ ] Asset transfer operations
- [ ] Asset maintenance scheduling
- [ ] Asset depreciation calculations
- [ ] Asset audit trail

#### dispatch Domain
- [ ] Incident assignment to guards
- [ ] Response time tracking
- [ ] Escalation handling
- [ ] Dispatch queue management
- [ ] Communication with field personnel

#### maintenance Domain
- [ ] Work order creation and assignment
- [ ] Maintenance task completion
- [ ] Equipment downtime tracking
- [ ] Preventive maintenance scheduling
- [ ] Maintenance cost tracking

#### policy Domain
- [ ] Policy rule evaluation
- [ ] Policy violation detection
- [ ] Policy enforcement actions
- [ ] Policy update distribution
- [ ] Compliance verification

#### risk_management Domain
- [ ] Risk assessment execution
- [ ] Risk score calculation
- [ ] Risk mitigation tracking
- [ ] Risk report generation
- [ ] Risk threshold alerts

#### sites Domain
- [ ] Site configuration changes
- [ ] Site hierarchy management
- [ ] Site access control updates
- [ ] Site status monitoring
- [ ] Site emergency protocols

---

## Test Infrastructure Analysis

### Existing Test Patterns

From analysis of `test/observability/` directory, the following test patterns are established:

#### 1. Jidoka (Stop-and-Fix) Testing Pattern
**File**: `test/observability/jidoka_test.exs` (485 lines)

**Key Patterns**:
- Tags: `:sopv511`, `:tps`, `:jidoka`, `:rca`, `:fix`, `:telemetry`, `:kaizen`
- Tests critical error detection and automatic halting
- Validates 5-Level RCA process integration
- Tests fix verification before resume
- Validates OpenTelemetry span creation for Jidoka events

**Example Test Structure**:
```elixir
@tag :sopv511
@tag :tps
@tag :jidoka
test "critical database connection errors trigger immediate halt" do
  critical_error = {:error, :critical, "database_connection_lost"}

  case critical_error do
    {:error, :critical, reason} ->
      # Jidoka: Stop immediately on critical error
      assert reason == "database_connection_lost"

      # Verify halt action would be taken
      halt_action = %{
        action: "halt_all_operations",
        reason: reason,
        timestamp: DateTime.utc_now(),
        rca_initiated: true
      }

      assert halt_action.action == "halt_all_operations"
      assert halt_action.rca_initiated == true
  end
end
```

#### 2. Audit Logging Testing Pattern
**File**: `test/observability/audit_logger_test.exs` (504 lines)

**Key Patterns**:
- Tags: `:sopv511`, `:stamp`, `:audit`, `:lifecycle`, `:database`, `:security`
- Tests SC-OBS-004 compliance (Complete Audit Trail)
- Validates audit log immutability
- Tests emergency event logging
- Validates 7-day minimum retention

**Example Test Structure**:
```elixir
@tag :sopv511
@tag :stamp
@tag :audit
test "audit log entries include all required fields" do
  audit_entry = %{
    timestamp: DateTime.utc_now(),
    operation_type: "container_lifecycle",
    operation_subtype: "container_start",
    details: %{
      container_name: "signoz-clickhouse",
      action: "start",
      result: "success"
    },
    user: "system",
    container: "signoz-clickhouse",
    sopv511_compliance: "SC-OBS-004",
    severity: "info"
  }

  # Verify all required fields present
  assert Map.has_key?(audit_entry, :timestamp)
  assert Map.has_key?(audit_entry, :sopv511_compliance)
  assert audit_entry.sopv511_compliance == "SC-OBS-004"
end
```

#### 3. Health Monitoring Testing Pattern
**File**: `test/observability/health_monitor_test.exs` (331 lines)

**Key Patterns**:
- Tags: `:health`, `:anomaly`, `:endpoint`, `:status`, `:dependencies`
- Tests SC-OBS-002 compliance (Anomaly detection within 1 minute)
- Validates 30-second health check intervals
- Tests container dependency tracking
- Validates automatic recovery with RCA

**Example Test Structure**:
```elixir
@health_check_interval 30_000  # 30 seconds
@anomaly_threshold 2            # 2 consecutive failures

test "detects anomalies within 60 seconds" do
  # With 30-second intervals and 2 failure threshold:
  max_detection_time = @health_check_interval * @anomaly_threshold

  # Must meet SC-OBS-002 requirement
  assert max_detection_time <= 60_000
end
```

---

## Gap Analysis

### Critical Gaps by Category

#### 1. Business Operations (P0 - CRITICAL)
- **billing**: No financial transaction logging (regulatory risk)
- **visitor_management**: No access audit trail (security risk)
- **guard_tour**: No patrol verification (compliance risk)
- **maintenance**: No work order tracking (operational risk)

#### 2. Technical Infrastructure (P0 - CRITICAL)
- **devices**: No hardware monitoring (operational blind spot)
- **integrations**: No external system logging (debugging impossible)
- **video**: No surveillance system logging (security risk)
- **sites**: No location management tracking (configuration blind spot)

#### 3. Risk and Compliance (P0 - CRITICAL)
- **policy**: No policy enforcement logging (compliance risk)
- **risk_management**: No risk assessment tracking (business risk)
- **asset_management**: No asset audit trail (financial risk)
- **dispatch**: No incident response logging (operational risk)

#### 4. Core Infrastructure (P0 - CRITICAL)
- **core**: Only 1 Logger call in foundational infrastructure (architectural risk)

---

## Priority Recommendations

### Phase 1: Immediate Action (P0 - Week 1)

#### Task 1.2: Define Logging Standards (4 hours)
**Deliverable**: Logging standards document with:
- Structured logging format specification
- Metadata requirements (user_id, tenant_id, trace_id, operation_type)
- Severity level guidelines
- Error handling patterns

#### Task 1.3: Create Logging Helper Modules (8 hours)
**Deliverable**: Reusable logging modules:
```elixir
# lib/indrajaal/observability/domain_logger.ex
defmodule Indrajaal.Observability.DomainLogger do
  @moduledoc """
  Standardized logging helper for domain operations.
  Ensures consistent logging across all 19 Ash domains.
  """

  require Logger

  def log_operation(domain, operation, metadata \\ %{}) do
    Logger.info("Domain operation",
      domain: domain,
      operation: operation,
      user_id: metadata[:user_id],
      tenant_id: metadata[:tenant_id],
      trace_id: metadata[:trace_id],
      timestamp: DateTime.utc_now()
    )
  end

  def log_error(domain, error, metadata \\ %{}) do
    Logger.error("Domain error",
      domain: domain,
      error: inspect(error),
      user_id: metadata[:user_id],
      tenant_id: metadata[:tenant_id],
      trace_id: metadata[:trace_id],
      timestamp: DateTime.utc_now()
    )
  end
end
```

#### Task 1.4: Add Logger Calls to Critical Operations (24 hours)
**Target**: 10 zero-coverage domains

**Approach**: Systematic domain instrumentation following priority order:

1. **billing** (P0 - 3 hours)
   - Invoice generation: success/failure
   - Payment processing: attempt/success/failure
   - Subscription changes: create/update/cancel
   - Refunds: request/approve/complete

2. **devices** (P0 - 3 hours)
   - Device registration: success/failure
   - Health checks: status changes
   - Configuration updates: applied/failed
   - Communication: connected/disconnected

3. **integrations** (P0 - 3 hours)
   - API calls: request/response
   - Webhook delivery: attempt/success/failure
   - Data sync: start/complete/error
   - Authentication: success/failure

4. **video** (P0 - 3 hours)
   - Stream initialization: start/stop
   - Recording: start/stop/error
   - Motion detection: event triggered
   - Storage: capacity warnings

5. **visitor_management** (P0 - 2 hours)
   - Check-in: success/failure
   - Check-out: success/failure
   - Access credential: generated/revoked
   - Host notification: sent/delivered

6. **guard_tour** (P0 - 2 hours)
   - Tour start: scheduled/actual
   - Checkpoint scan: success/missed
   - Tour complete: on-time/late
   - Alert generation: missed checkpoint

7. **asset_management** (P0 - 2 hours)
   - Asset registration: success/failure
   - Location update: success/failure
   - Transfer: initiated/completed
   - Audit: start/complete

8. **dispatch** (P0 - 2 hours)
   - Incident assigned: to whom/when
   - Response time: dispatched/arrived
   - Escalation: triggered/resolved
   - Communication: sent/acknowledged

9. **maintenance** (P0 - 2 hours)
   - Work order: created/assigned
   - Task: started/completed
   - Equipment: status changes
   - Schedule: created/updated

10. **policy** (P0 - 2 hours)
    - Rule evaluation: success/failure
    - Violation: detected/action taken
    - Update: distributed/applied
    - Compliance: verified/failed

### Phase 2: Enhancement (P1 - Week 2-3)

#### Enhance Medium Coverage Domains
- **analytics** (39 calls): Add data pipeline logging
- **compliance** (12 calls): Add regulatory event logging
- **accounts** (11 calls): Add authentication logging

#### Enhance Core Infrastructure
- **core** (1 call): Add foundational operation logging

### Phase 3: Optimization (P2 - Week 4-5)

#### Optimize High Coverage Domains
- **alarms** (183 calls): Review for redundancy, add structured metadata
- **communication** (53 calls): Add message delivery tracking
- **access_control** (50 calls): Add authorization decision logging

---

## Compliance Validation Checklist

### SC-OBS-001: 100% Observability for Critical Operations
- [ ] All 19 domains have Logger calls for critical operations
- [ ] All CRUD operations logged with metadata
- [ ] All external API calls logged with response status
- [ ] All authentication attempts logged
- [ ] All authorization decisions logged

### SC-OBS-002: Anomaly Detection Within 1 Minute
- [ ] Health checks run every 30 seconds
- [ ] 2 consecutive failure threshold configured
- [ ] Anomaly alerts trigger within 60 seconds
- [ ] Recovery procedures include RCA

### SC-OBS-003: 7-Day Minimum Data Retention
- [ ] Log retention policy configured
- [ ] Audit trail retention enforced
- [ ] Telemetry data retention validated
- [ ] Backup and recovery procedures tested

### SC-OBS-004: Complete Audit Trail
- [ ] All user actions logged with timestamps
- [ ] All system state changes logged
- [ ] Audit logs include user_id, tenant_id, operation_type
- [ ] Audit trail immutability enforced
- [ ] Emergency events logged with severity: critical

---

## Success Metrics

### Coverage Targets
- **Week 1**: 19/19 domains have ≥5 Logger calls (100% coverage)
- **Week 2**: 19/19 domains have ≥20 Logger calls
- **Week 3**: 19/19 domains have complete critical operation coverage

### Quality Targets
- **Structured Logging**: 100% of Logger calls include metadata
- **Trace Propagation**: 100% of Logger calls include trace_id
- **Test Coverage**: 95% of logging code covered by tests

### Compliance Targets
- **SC-OBS-001**: 100% observability achieved
- **SC-OBS-002**: <60 second anomaly detection validated
- **SC-OBS-003**: 7-day retention enforced and tested
- **SC-OBS-004**: Complete audit trail validated

---

## Next Steps

### Immediate (Today)
1. ✅ Complete logging coverage matrix documentation
2. 🔄 Begin Task 1.2: Define Logging Standards (4 hours)
   - Create logging standards document
   - Define metadata requirements
   - Establish severity guidelines

### Tomorrow
3. Begin Task 1.3: Create Logging Helper Modules (8 hours)
   - Implement DomainLogger module
   - Create AuditLogger helper
   - Add ErrorLogger patterns

### Rest of Week 1
4. Begin Task 1.4: Add Logger Calls to Critical Operations (24 hours)
   - Start with billing domain
   - Continue with devices, integrations, video
   - Validate with tests for each domain

---

## Appendix A: Reference Implementations

### alarms Domain (183 Logger calls - GOOD EXAMPLE)
The alarms domain demonstrates best practices:
- Comprehensive lifecycle logging (create/update/acknowledge/resolve)
- Structured metadata (alarm_id, severity, user_id, tenant_id)
- Error handling with detailed context
- Integration with OpenTelemetry tracing

**Recommendation**: Use alarms domain as template for zero-coverage domains.

### communication Domain (53 Logger calls - GOOD EXAMPLE)
The communication domain shows effective logging:
- Message delivery tracking
- Error handling with retry logic
- External system integration logging
- Performance metrics capture

**Recommendation**: Use communication domain as template for integrations domain.

### access_control Domain (50 Logger calls - GOOD EXAMPLE)
The access_control domain demonstrates security logging:
- Authentication attempt logging
- Authorization decision logging
- Failed access tracking
- Audit trail with user context

**Recommendation**: Use access_control domain as template for visitor_management domain.

---

## Appendix B: Logging Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Logging Without Context
```elixir
# BAD: No metadata
Logger.info("Operation completed")

# GOOD: Rich metadata
Logger.info("Operation completed",
  operation: "invoice_generation",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration
)
```

### ❌ Anti-Pattern 2: Excessive Debug Logging in Production
```elixir
# BAD: Debug noise in production
Logger.debug("Step 1")
Logger.debug("Step 2")
Logger.debug("Step 3")

# GOOD: Structured single log with steps
Logger.info("Multi-step operation",
  operation: "complex_workflow",
  steps_completed: ["validation", "processing", "persistence"],
  duration_ms: duration
)
```

### ❌ Anti-Pattern 3: Sensitive Data in Logs
```elixir
# BAD: Sensitive data exposed
Logger.info("Payment processed", card_number: card.number, cvv: card.cvv)

# GOOD: Redacted sensitive fields
Logger.info("Payment processed",
  card_last_four: card.last_four,
  payment_method: card.brand,
  amount: amount
)
```

---

**Document Status**: ✅ COMPLETE
**Next Task**: Task 1.2 - Define Logging Standards (4 hours)
**Estimated Completion**: Phase 1 - 5 days (40 hours)
