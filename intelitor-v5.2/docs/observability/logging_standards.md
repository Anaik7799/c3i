# Logging Standards - Indrajaal Security Monitoring System

**Document Version**: 1.0
**Date**: 2025-01-23
**SOPv5.11 Compliance**: SC-OBS-001, SC-OBS-004
**Status**: 🟢 ACTIVE - Mandatory for all development

---

## Executive Summary

This document defines the mandatory logging standards for the Indrajaal Security Monitoring System. All developers, domains, and components MUST adhere to these standards to ensure:

- **100% Observability** (SC-OBS-001): All critical operations logged with sufficient context
- **Complete Audit Trail** (SC-OBS-004): All user actions and system state changes tracked
- **Anomaly Detection** (SC-OBS-002): Sufficient logging density for <1 minute detection
- **7-Day Retention** (SC-OBS-003): Logs retained for minimum compliance period

**Enforcement**: All pull requests MUST pass logging compliance checks before merge.

---

## 1. Structured Logging Format

### 1.1 Mandatory Logging Library

**REQUIRED**: Use Elixir's `Logger` module exclusively.

```elixir
require Logger

# ✅ CORRECT
Logger.info("Operation completed", metadata)

# ❌ FORBIDDEN
IO.puts("Operation completed")  # No structured logging
```

**Rationale**: Logger provides:
- Structured metadata support
- Configurable backends (console, file, SigNoz)
- Log level filtering
- Integration with OpenTelemetry

### 1.2 Log Message Structure

**Format**: `[Action] [Resource] [Result]` with structured metadata

```elixir
# ✅ CORRECT: Action + Resource + Result with metadata
Logger.info("Invoice generated successfully",
  operation: "invoice_generation",
  invoice_id: invoice.id,
  amount: invoice.total,
  currency: invoice.currency,
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: get_trace_id(),
  duration_ms: duration
)

# ❌ WRONG: Unstructured message
Logger.info("Generated invoice #{invoice.id} for $#{invoice.total}")
```

**Required Components**:
1. **Human-readable message**: Clear action description
2. **Structured metadata**: Key-value pairs for filtering and searching
3. **Context identifiers**: user_id, tenant_id, trace_id
4. **Performance metrics**: duration_ms when applicable

---

## 2. Metadata Requirements

### 2.1 Mandatory Metadata Fields

**ALL log entries MUST include**:

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `operation` | string | Operation identifier | "invoice_generation" |
| `user_id` | UUID | User performing action | "550e8400-e29b-41d4-a716-446655440000" |
| `tenant_id` | UUID | Tenant context | "7c9e6679-7425-40de-944b-e07fc1f90ae7" |
| `trace_id` | string | OpenTelemetry trace ID | "1234567890abcdef" |
| `timestamp` | DateTime | UTC timestamp | Auto-added by Logger |

```elixir
# ✅ CORRECT: All mandatory fields present
Logger.info("Payment processed",
  operation: "payment_processing",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: OpentelemetryProcessPropagator.fetch_trace_id(),
  payment_id: payment.id,
  amount: payment.amount,
  status: "success"
)
```

### 2.2 Conditional Metadata Fields

**Include when applicable**:

| Field | Type | When Required | Example |
|-------|------|---------------|---------|
| `duration_ms` | integer | Operations >10ms | 1250 |
| `error` | string | On failures | "Network timeout" |
| `error_type` | atom | On failures | :network_error |
| `resource_id` | UUID | Resource operations | alarm.id |
| `resource_type` | string | Resource operations | "alarm" |
| `previous_value` | any | Updates | "active" |
| `new_value` | any | Updates | "resolved" |
| `external_service` | string | External API calls | "stripe_api" |
| `http_status` | integer | HTTP operations | 200 |
| `ip_address` | string | Security events | "192.168.1.100" |

```elixir
# ✅ CORRECT: Conditional fields included appropriately
Logger.info("Alarm status updated",
  operation: "alarm_status_change",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  resource_id: alarm.id,
  resource_type: "alarm",
  previous_value: "active",
  new_value: "resolved",
  duration_ms: 45
)
```

### 2.3 Domain-Specific Metadata

**Each domain SHOULD include domain-specific context**:

```elixir
# billing domain
Logger.info("Subscription created",
  operation: "subscription_creation",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  subscription_id: subscription.id,
  plan: "enterprise",
  billing_cycle: "monthly",
  mrr: 999.00
)

# video domain
Logger.info("Recording started",
  operation: "recording_start",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  camera_id: camera.id,
  resolution: "1080p",
  fps: 30,
  codec: "h264"
)
```

---

## 3. Log Levels and Severity Guidelines

### 3.1 Log Level Definitions

| Level | Usage | Examples | Response Required |
|-------|-------|----------|-------------------|
| **error** | System failures, data corruption, unrecoverable errors | Database connection lost, Payment processing failed | Immediate investigation |
| **warn** | Recoverable errors, degraded performance, threshold violations | API rate limit approaching, High memory usage | Monitor and plan action |
| **info** | Normal operations, business events, state changes | User login, Invoice generated, Alarm resolved | None - informational |
| **debug** | Development diagnostics, detailed execution flow | Function entry/exit, Variable values | Development only |

### 3.2 Error Level - Critical Failures

**Use `Logger.error/2` for**:
- Database connection failures
- Payment processing failures
- Data corruption detected
- External service unavailable (critical services)
- Authentication system failures
- Unhandled exceptions

```elixir
# ✅ CORRECT: Error level for critical failure
Logger.error("Database connection lost",
  operation: "database_connection",
  error: "Connection timeout after 5000ms",
  error_type: :connection_timeout,
  database: "primary",
  tenant_id: tenant.id,
  retry_attempt: 3
)
```

### 3.3 Warn Level - Recoverable Issues

**Use `Logger.warn/2` for**:
- API rate limits approaching
- Resource utilization high (>80%)
- Retry attempts (before failure)
- Deprecated feature usage
- Configuration issues (with fallback)
- Performance degradation

```elixir
# ✅ CORRECT: Warn level for degraded performance
Logger.warn("API rate limit approaching",
  operation: "external_api_call",
  service: "stripe_api",
  current_usage: 980,
  limit: 1000,
  usage_percent: 98,
  tenant_id: tenant.id,
  trace_id: trace_id
)
```

### 3.4 Info Level - Business Events

**Use `Logger.info/2` for**:
- User authentication (success/failure)
- Business transactions (create/update/delete)
- State transitions (alarm raised/resolved)
- External API calls (successful)
- Background job completion
- System health checks (success)

```elixir
# ✅ CORRECT: Info level for business event
Logger.info("User authenticated successfully",
  operation: "user_authentication",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  auth_method: "oauth",
  provider: "microsoft_entra",
  ip_address: conn.remote_ip
)
```

### 3.5 Debug Level - Development Diagnostics

**Use `Logger.debug/2` for**:
- Function entry/exit (only in development)
- Variable state inspection
- Detailed execution flow
- Test debugging information

```elixir
# ✅ CORRECT: Debug level for development diagnostics
Logger.debug("Entering payment processing workflow",
  operation: "payment_processing",
  payment_id: payment.id,
  amount: payment.amount,
  payment_method: payment.method
)
```

**⚠️ WARNING**: Debug logs MUST NOT be used in production due to:
- Performance impact
- Log volume
- Potential sensitive data exposure

---

## 4. Logging Patterns by Operation Type

### 4.1 CRUD Operations

**Pattern**: Log ALL create, read (when critical), update, delete operations

```elixir
# CREATE
Logger.info("Resource created",
  operation: "resource_creation",
  resource_type: "alarm",
  resource_id: alarm.id,
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration
)

# UPDATE
Logger.info("Resource updated",
  operation: "resource_update",
  resource_type: "alarm",
  resource_id: alarm.id,
  field_changed: "status",
  previous_value: "active",
  new_value: "resolved",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration
)

# DELETE
Logger.info("Resource deleted",
  operation: "resource_deletion",
  resource_type: "alarm",
  resource_id: alarm.id,
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration
)
```

### 4.2 External API Calls

**Pattern**: Log request initiation, response, and errors

```elixir
# Request
Logger.info("External API request initiated",
  operation: "external_api_call",
  service: "stripe_api",
  endpoint: "/v1/charges",
  method: "POST",
  tenant_id: tenant.id,
  trace_id: trace_id
)

# Success
Logger.info("External API request succeeded",
  operation: "external_api_call",
  service: "stripe_api",
  endpoint: "/v1/charges",
  http_status: 200,
  duration_ms: 1250,
  tenant_id: tenant.id,
  trace_id: trace_id
)

# Failure
Logger.error("External API request failed",
  operation: "external_api_call",
  service: "stripe_api",
  endpoint: "/v1/charges",
  http_status: 500,
  error: "Internal server error",
  error_type: :external_service_error,
  duration_ms: 5000,
  tenant_id: tenant.id,
  trace_id: trace_id,
  retry_attempt: 2
)
```

### 4.3 Authentication and Authorization

**Pattern**: Log ALL authentication attempts and authorization decisions

```elixir
# Authentication Success
Logger.info("User authenticated",
  operation: "user_authentication",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  auth_method: "oauth",
  provider: "microsoft_entra",
  ip_address: conn.remote_ip,
  user_agent: get_user_agent(conn)
)

# Authentication Failure
Logger.warn("Authentication failed",
  operation: "user_authentication",
  username: username,
  tenant_id: tenant.id,
  trace_id: trace_id,
  reason: "invalid_credentials",
  ip_address: conn.remote_ip,
  user_agent: get_user_agent(conn)
)

# Authorization Denied
Logger.warn("Authorization denied",
  operation: "authorization_check",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  resource_type: "alarm",
  resource_id: alarm.id,
  action: "update",
  reason: "insufficient_permissions"
)
```

### 4.4 Background Jobs and Scheduled Tasks

**Pattern**: Log job start, completion, and errors

```elixir
# Job Start
Logger.info("Background job started",
  operation: "background_job",
  job_type: "invoice_generation",
  job_id: job.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  scheduled_at: job.scheduled_at
)

# Job Complete
Logger.info("Background job completed",
  operation: "background_job",
  job_type: "invoice_generation",
  job_id: job.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration,
  records_processed: 150
)

# Job Failed
Logger.error("Background job failed",
  operation: "background_job",
  job_type: "invoice_generation",
  job_id: job.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration,
  error: "Database connection lost",
  error_type: :connection_error,
  retry_attempt: 3
)
```

### 4.5 State Transitions

**Pattern**: Log all state changes with previous and new state

```elixir
Logger.info("State transition",
  operation: "state_transition",
  resource_type: "alarm",
  resource_id: alarm.id,
  previous_state: "active",
  new_state: "resolved",
  trigger: "user_action",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  duration_ms: duration
)
```

### 4.6 Error Handling and Recovery

**Pattern**: Log errors with full context and recovery actions

```elixir
# Error Detected
Logger.error("Payment processing error",
  operation: "payment_processing",
  payment_id: payment.id,
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  error: "Insufficient funds",
  error_type: :payment_declined,
  amount: payment.amount,
  currency: payment.currency
)

# Recovery Action
Logger.info("Payment retry scheduled",
  operation: "payment_retry",
  payment_id: payment.id,
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: trace_id,
  retry_at: DateTime.add(DateTime.utc_now(), 3600, :second),
  retry_attempt: 1
)
```

---

## 5. Security and Privacy Guidelines

### 5.1 Sensitive Data Protection

**FORBIDDEN**: NEVER log sensitive data

```elixir
# ❌ FORBIDDEN: Logging sensitive data
Logger.info("Payment processed",
  card_number: "4111111111111111",
  cvv: "123",
  password: "secret123"
)

# ✅ CORRECT: Redacted sensitive fields
Logger.info("Payment processed",
  card_last_four: "1111",
  card_brand: "visa",
  payment_method: "credit_card"
)
```

**Sensitive Data Categories**:
- Passwords, tokens, API keys
- Full credit card numbers, CVV codes
- Social Security Numbers, Tax IDs
- Personal health information
- Biometric data
- Raw video/audio content (log metadata only)

### 5.2 PII (Personally Identifiable Information) Handling

**Guideline**: Log PII identifiers only when necessary

```elixir
# ✅ CORRECT: Log user_id instead of email/name
Logger.info("User profile updated",
  operation: "profile_update",
  user_id: user.id,  # Good: UUID reference
  tenant_id: tenant.id,
  trace_id: trace_id,
  fields_updated: ["phone", "address"]
)

# ⚠️ USE SPARINGLY: Log email only when required for audit
Logger.info("Password reset requested",
  operation: "password_reset",
  user_id: user.id,
  email: user.email,  # Acceptable for audit trail
  tenant_id: tenant.id,
  trace_id: trace_id,
  ip_address: conn.remote_ip
)
```

### 5.3 Multi-Tenancy Isolation

**MANDATORY**: ALL logs MUST include tenant_id for isolation

```elixir
# ✅ CORRECT: tenant_id always included
Logger.info("Operation performed",
  operation: "alarm_creation",
  tenant_id: tenant.id,  # MANDATORY
  user_id: user.id,
  trace_id: trace_id
)
```

**Rationale**: tenant_id enables:
- Log filtering by tenant in SigNoz
- Security incident investigation per tenant
- Compliance reporting per tenant
- Multi-tenant isolation verification

---

## 6. Performance Considerations

### 6.1 Logging Overhead Guidelines

**Target**: Logging should add <5% overhead to operation time

```elixir
# ✅ CORRECT: Lightweight logging
Logger.info("Operation completed",
  operation: "fast_operation",
  duration_ms: 10
)

# ⚠️ CAUTION: Expensive metadata calculation
Logger.info("Operation completed",
  operation: "slow_operation",
  # Avoid expensive calculations in metadata
  expensive_calculation: calculate_complex_metric()  # BAD
)

# ✅ CORRECT: Calculate expensive metrics separately
metric = if log_detailed_metrics?(), do: calculate_complex_metric(), else: nil
Logger.info("Operation completed",
  operation: "optimized_operation",
  complex_metric: metric
)
```

### 6.2 Log Volume Management

**Guideline**: Balance observability needs with storage costs

| Operation Frequency | Recommended Logging |
|---------------------|---------------------|
| >1000/sec | Sample 1-10% or aggregate |
| 100-1000/sec | Log all with info level |
| 10-100/sec | Log all with full metadata |
| <10/sec | Log all with detailed metadata |

```elixir
# ✅ CORRECT: Sampling high-frequency operations
if :rand.uniform(100) <= 10 do  # 10% sampling
  Logger.info("Health check performed",
    operation: "health_check",
    status: "healthy"
  )
end

# ✅ CORRECT: Aggregate high-frequency operations
Logger.info("Health checks completed",
  operation: "health_check_batch",
  checks_performed: 1000,
  healthy: 995,
  degraded: 5,
  unhealthy: 0,
  duration_ms: 5000
)
```

### 6.3 Conditional Logging

**Pattern**: Use log level configuration for conditional logging

```elixir
# ✅ CORRECT: Debug logs only in development
if Logger.level() == :debug do
  Logger.debug("Detailed execution flow",
    operation: "complex_workflow",
    step: "validation",
    data: inspect(data)
  )
end

# ✅ BETTER: Logger automatically filters by level
Logger.debug("Detailed execution flow",
  operation: "complex_workflow",
  step: "validation",
  data: inspect(data)
)
```

---

## 7. Integration with Observability Stack

### 7.1 OpenTelemetry Integration

**MANDATORY**: Propagate trace context in all logs

```elixir
defmodule MyApp.LogHelper do
  def get_trace_id do
    case OpentelemetryProcessPropagator.fetch_trace_id() do
      {:ok, trace_id} -> trace_id
      _ -> "no-trace"
    end
  end

  def get_span_id do
    case OpentelemetryProcessPropagator.fetch_span_id() do
      {:ok, span_id} -> span_id
      _ -> "no-span"
    end
  end
end

# Usage
Logger.info("Operation performed",
  operation: "payment_processing",
  trace_id: MyApp.LogHelper.get_trace_id(),
  span_id: MyApp.LogHelper.get_span_id(),
  user_id: user.id,
  tenant_id: tenant.id
)
```

### 7.2 SigNoz Dashboard Integration

**Guideline**: Structure logs for SigNoz queries

```elixir
# ✅ CORRECT: Structured for SigNoz filtering
Logger.info("Payment processed",
  # Standard fields for filtering
  operation: "payment_processing",
  status: "success",
  tenant_id: tenant.id,
  user_id: user.id,

  # Metrics for dashboards
  amount: 99.99,
  currency: "USD",
  duration_ms: 1250,

  # Context for correlation
  trace_id: trace_id,
  span_id: span_id
)
```

**Common SigNoz Queries**:
```sql
-- Error rate by operation
operation: "payment_processing" AND level: "error"

-- Slow operations
operation: "payment_processing" AND duration_ms > 1000

-- User activity
user_id: "550e8400-e29b-41d4-a716-446655440000"

-- Tenant activity
tenant_id: "7c9e6679-7425-40de-944b-e07fc1f90ae7"
```

### 7.3 Dual Logging (Console + SigNoz)

**Configuration**: Logs MUST appear in BOTH console and SigNoz

```elixir
# config/config.exs
config :logger,
  backends: [:console, LoggerJSON],
  level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :tenant_id, :trace_id, :user_id]

config :logger_json, :backend,
  formatter: LoggerJSON.Formatters.Datadog,
  metadata: :all
```

---

## 8. Testing and Validation

### 8.1 Logging Tests

**REQUIRED**: Test that critical operations produce logs

```elixir
defmodule MyApp.PaymentTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  test "payment processing logs success" do
    log = capture_log(fn ->
      PaymentProcessor.process(payment)
    end)

    assert log =~ "Payment processed"
    assert log =~ "payment_id"
    assert log =~ "amount"
    assert log =~ "user_id"
    assert log =~ "tenant_id"
    assert log =~ "trace_id"
  end

  test "payment processing logs errors" do
    log = capture_log(fn ->
      assert_raise PaymentError, fn ->
        PaymentProcessor.process(invalid_payment)
      end
    end)

    assert log =~ "Payment processing error"
    assert log =~ "error_type"
    assert log =~ "payment_declined"
  end
end
```

### 8.2 Log Compliance Checks

**REQUIRED**: Validate logs contain mandatory metadata

```elixir
defmodule MyApp.LogComplianceTest do
  use ExUnit.Case, async: false

  test "all info logs include mandatory metadata" do
    logs = capture_all_logs()

    for log <- logs do
      assert has_field?(log, "operation")
      assert has_field?(log, "user_id")
      assert has_field?(log, "tenant_id")
      assert has_field?(log, "trace_id")
    end
  end
end
```

---

## 9. Migration Guide for Existing Code

### 9.1 Identifying Non-Compliant Logs

**Script**: Scan for logs without metadata

```bash
# Find Logger calls without metadata
grep -r "Logger\.(info|warn|error)" lib/ | grep -v "operation:"
```

### 9.2 Migration Pattern

**Before** (Non-Compliant):
```elixir
Logger.info("Payment processed for user #{user.id}")
```

**After** (Compliant):
```elixir
Logger.info("Payment processed",
  operation: "payment_processing",
  user_id: user.id,
  tenant_id: tenant.id,
  trace_id: get_trace_id(),
  payment_id: payment.id,
  amount: payment.amount,
  currency: payment.currency,
  duration_ms: duration
)
```

### 9.3 Migration Checklist per Domain

- [ ] Audit existing Logger calls
- [ ] Add mandatory metadata fields
- [ ] Add domain-specific context
- [ ] Update tests to verify metadata
- [ ] Verify logs appear in SigNoz
- [ ] Update documentation

---

## 10. Helper Modules and Utilities

### 10.1 DomainLogger Module

**Location**: `lib/indrajaal/observability/domain_logger.ex`

```elixir
defmodule Indrajaal.Observability.DomainLogger do
  @moduledoc """
  Standardized logging helper for domain operations.
  Ensures consistent logging across all 19 Ash domains.
  """

  require Logger

  @doc """
  Log a successful domain operation.
  """
  def log_success(domain, operation, metadata \\ %{}) do
    Logger.info("Domain operation successful",
      domain: domain,
      operation: operation,
      user_id: metadata[:user_id],
      tenant_id: metadata[:tenant_id],
      trace_id: metadata[:trace_id] || get_trace_id(),
      resource_id: metadata[:resource_id],
      duration_ms: metadata[:duration_ms]
    )
  end

  @doc """
  Log a failed domain operation.
  """
  def log_error(domain, operation, error, metadata \\ %{}) do
    Logger.error("Domain operation failed",
      domain: domain,
      operation: operation,
      error: inspect(error),
      error_type: metadata[:error_type] || :unknown_error,
      user_id: metadata[:user_id],
      tenant_id: metadata[:tenant_id],
      trace_id: metadata[:trace_id] || get_trace_id(),
      resource_id: metadata[:resource_id]
    )
  end

  @doc """
  Log a state transition.
  """
  def log_state_change(domain, resource_type, resource_id, previous_state, new_state, metadata \\ %{}) do
    Logger.info("State transition",
      domain: domain,
      operation: "state_transition",
      resource_type: resource_type,
      resource_id: resource_id,
      previous_state: previous_state,
      new_state: new_state,
      user_id: metadata[:user_id],
      tenant_id: metadata[:tenant_id],
      trace_id: metadata[:trace_id] || get_trace_id()
    )
  end

  defp get_trace_id do
    case OpentelemetryProcessPropagator.fetch_trace_id() do
      {:ok, trace_id} -> trace_id
      _ -> "no-trace"
    end
  end
end
```

### 10.2 AuditLogger Module

**Location**: `lib/indrajaal/observability/audit_logger.ex`

```elixir
defmodule Indrajaal.Observability.AuditLogger do
  @moduledoc """
  Audit trail logging for SC-OBS-004 compliance.
  """

  require Logger

  @doc """
  Log an audit event with full context.
  """
  def log_audit_event(operation_type, operation_subtype, details, metadata) do
    Logger.info("Audit event",
      operation_type: operation_type,
      operation_subtype: operation_subtype,
      details: details,
      user_id: metadata[:user_id],
      tenant_id: metadata[:tenant_id],
      trace_id: metadata[:trace_id],
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent],
      sopv511_compliance: "SC-OBS-004",
      severity: metadata[:severity] || "info"
    )
  end
end
```

---

## 11. Compliance Checklist

### 11.1 Developer Checklist (Pre-Commit)

- [ ] All Logger calls include `operation` field
- [ ] All Logger calls include `user_id` (when available)
- [ ] All Logger calls include `tenant_id`
- [ ] All Logger calls include `trace_id`
- [ ] No sensitive data in logs (passwords, tokens, full card numbers)
- [ ] Appropriate log level used (error/warn/info/debug)
- [ ] Tests verify log output
- [ ] Logs verified in SigNoz dashboard

### 11.2 Code Review Checklist

- [ ] Logging standards followed
- [ ] Metadata complete and accurate
- [ ] No performance issues (avoid expensive calculations)
- [ ] Security requirements met (no sensitive data)
- [ ] Tests include log verification
- [ ] Documentation updated if needed

### 11.3 Domain Compliance Checklist

- [ ] All CRUD operations logged
- [ ] All external API calls logged
- [ ] All authentication attempts logged
- [ ] All authorization decisions logged
- [ ] All state transitions logged
- [ ] All errors logged with context
- [ ] Minimum 5 Logger calls per domain
- [ ] Domain-specific metadata included

---

## 12. Examples by Domain

### 12.1 billing Domain

```elixir
defmodule Indrajaal.Billing do
  require Logger
  alias Indrajaal.Observability.DomainLogger

  def generate_invoice(subscription, user, tenant) do
    start_time = System.monotonic_time(:millisecond)

    try do
      invoice = perform_invoice_generation(subscription)

      duration = System.monotonic_time(:millisecond) - start_time

      DomainLogger.log_success("billing", "invoice_generation",
        user_id: user.id,
        tenant_id: tenant.id,
        trace_id: get_trace_id(),
        resource_id: invoice.id,
        duration_ms: duration,
        amount: invoice.total,
        currency: invoice.currency,
        subscription_id: subscription.id
      )

      {:ok, invoice}
    rescue
      error ->
        DomainLogger.log_error("billing", "invoice_generation", error,
          user_id: user.id,
          tenant_id: tenant.id,
          trace_id: get_trace_id(),
          error_type: :invoice_generation_failed,
          subscription_id: subscription.id
        )

        {:error, error}
    end
  end
end
```

### 12.2 devices Domain

```elixir
defmodule Indrajaal.Devices do
  require Logger
  alias Indrajaal.Observability.DomainLogger

  def register_device(device_params, user, tenant) do
    start_time = System.monotonic_time(:millisecond)

    case Devices.create(device_params) do
      {:ok, device} ->
        duration = System.monotonic_time(:millisecond) - start_time

        DomainLogger.log_success("devices", "device_registration",
          user_id: user.id,
          tenant_id: tenant.id,
          trace_id: get_trace_id(),
          resource_id: device.id,
          duration_ms: duration,
          device_type: device.type,
          manufacturer: device.manufacturer,
          model: device.model
        )

        {:ok, device}

      {:error, reason} ->
        DomainLogger.log_error("devices", "device_registration", reason,
          user_id: user.id,
          tenant_id: tenant.id,
          trace_id: get_trace_id(),
          error_type: :device_registration_failed
        )

        {:error, reason}
    end
  end

  def check_device_health(device_id, tenant) do
    Logger.info("Device health check initiated",
      domain: "devices",
      operation: "device_health_check",
      device_id: device_id,
      tenant_id: tenant.id,
      trace_id: get_trace_id()
    )

    case perform_health_check(device_id) do
      {:ok, :healthy} ->
        Logger.info("Device health check passed",
          domain: "devices",
          operation: "device_health_check",
          device_id: device_id,
          tenant_id: tenant.id,
          trace_id: get_trace_id(),
          status: "healthy"
        )

      {:ok, :degraded} ->
        Logger.warn("Device health check degraded",
          domain: "devices",
          operation: "device_health_check",
          device_id: device_id,
          tenant_id: tenant.id,
          trace_id: get_trace_id(),
          status: "degraded"
        )

      {:error, reason} ->
        Logger.error("Device health check failed",
          domain: "devices",
          operation: "device_health_check",
          device_id: device_id,
          tenant_id: tenant.id,
          trace_id: get_trace_id(),
          error: inspect(reason),
          error_type: :health_check_failed
        )
    end
  end
end
```

### 12.3 integrations Domain

```elixir
defmodule Indrajaal.Integrations do
  require Logger

  def call_external_api(service, endpoint, params, tenant) do
    Logger.info("External API request initiated",
      domain: "integrations",
      operation: "external_api_call",
      service: service,
      endpoint: endpoint,
      method: "POST",
      tenant_id: tenant.id,
      trace_id: get_trace_id()
    )

    start_time = System.monotonic_time(:millisecond)

    case HTTPClient.post(endpoint, params) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.info("External API request succeeded",
          domain: "integrations",
          operation: "external_api_call",
          service: service,
          endpoint: endpoint,
          http_status: status,
          duration_ms: duration,
          tenant_id: tenant.id,
          trace_id: get_trace_id()
        )

        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error("External API request failed",
          domain: "integrations",
          operation: "external_api_call",
          service: service,
          endpoint: endpoint,
          http_status: status,
          error: "Non-success status code",
          error_type: :external_api_error,
          duration_ms: duration,
          tenant_id: tenant.id,
          trace_id: get_trace_id()
        )

        {:error, {:http_error, status, body}}

      {:error, reason} ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.error("External API request failed",
          domain: "integrations",
          operation: "external_api_call",
          service: service,
          endpoint: endpoint,
          error: inspect(reason),
          error_type: :network_error,
          duration_ms: duration,
          tenant_id: tenant.id,
          trace_id: get_trace_id()
        )

        {:error, reason}
    end
  end
end
```

---

## 13. Appendix: Quick Reference Card

### Mandatory Fields
```elixir
Logger.info("Message",
  operation: "operation_name",     # REQUIRED
  user_id: user.id,                # REQUIRED (when available)
  tenant_id: tenant.id,            # REQUIRED
  trace_id: get_trace_id()         # REQUIRED
)
```

### Log Levels
- **error**: System failures, unrecoverable errors
- **warn**: Recoverable errors, performance degradation
- **info**: Business events, normal operations
- **debug**: Development diagnostics only

### Forbidden
- ❌ Passwords, tokens, API keys
- ❌ Full credit card numbers
- ❌ Social Security Numbers
- ❌ Personal health information

### Helper Modules
- `Indrajaal.Observability.DomainLogger` - Standard domain logging
- `Indrajaal.Observability.AuditLogger` - Audit trail logging

---

**Document Status**: ✅ APPROVED
**Effective Date**: 2025-01-23
**Next Review**: 2025-04-23 (Quarterly)
**Owner**: Observability Team
