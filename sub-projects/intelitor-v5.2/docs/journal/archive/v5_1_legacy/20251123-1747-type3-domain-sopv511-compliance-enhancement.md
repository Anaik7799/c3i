# Type 3 Domain SOPv5.11 Compliance Enhancement - Complete Design Documentation

**Date**: 2025-11-23 17:47:00 CEST
**Status**: ✅ DESIGN COMPLETE | ⏳ IMPLEMENTATION PENDING
**Target**: `/lib/indrajaal/telemetry.ex` (lines 242-257)
**Scope**: 60% of system (39 resources across 10 Type 3 domains)
**Framework**: TDG + STAMP + TPS + SOPv5.11 + AEE 50-Agent Architecture
**Total Effort**: 6.5 hours implementation + validation

---

## 1. Executive Summary

### 1.1 Enhancement Objective

Bring Type 3 domains (60% of system, 39 resources) into full SOPv5.11 observability compliance by enhancing the `handle_ash_event/4` function in `/lib/indrajaal/telemetry.ex` to integrate the three-helper observability framework (DomainLogger, ErrorLogger, AuditLogger).

### 1.2 Type 3 Domain Characteristics

**Definition**: Domains with full Ash telemetry infrastructure but lacking SOPv5.11 observability helper integration.

**Affected Domains** (10 total):
1. `billing` (6 resources)
2. `devices` (4 resources)
3. `sites` (3 resources)
4. `visitor_management` (5 resources)
5. `communication` (4 resources)
6. `guard_tour` (3 resources)
7. `maintenance` (4 resources)
8. `risk_management` (3 resources)
9. `analytics` (4 resources)
10. `policy` (3 resources)

**System Impact**: 39 resources / 65 total resources = 60% of entire system

### 1.3 Enhancement Strategy

**Minimal Enhancement Approach**:
- ✅ Preserve existing Ash telemetry infrastructure (12 events already attached)
- ✅ Add SOPv5.11 compliance layer on top via event routing
- ✅ Zero breaking changes to current Ash event flow
- ✅ Fallback to standard Logger for edge cases (non-domain resources)
- ✅ Complete backward compatibility with existing telemetry consumers

---

## 2. Critical Gaps Analysis

### Gap 1: Uses `Logger.info` Instead of `DomainLogger.log_success`

**Current State** (line 246):
```elixir
[:ash, _domain, _action, :stop] ->
  Logger.info("Ash operation completed",
    event: event_name,
    resource: metadata.resource,
    action: metadata.action,
    duration_ms: duration_ms
  )
```

**Problem**:
- No domain name validation against 19 valid domains
- Missing required metadata: `user_id`, `tenant_id`, `trace_id`, `resource_id`
- No structured logging format compliance
- No automatic metadata validation

**Desired State**:
```elixir
[:ash, _domain, _action, :stop] ->
  if domain do
    DomainLogger.log_success(domain, operation, obs_metadata)
  else
    Logger.info("Ash operation completed",
      Keyword.merge([event: event_name], obs_metadata))
  end
```

**Impact**: 100% of successful operations in Type 3 domains lack proper structured logging

---

### Gap 2: No Domain Name Extraction/Validation

**Current State**: No domain extraction from resource module name

**Problem**:
- Cannot route events to DomainLogger (requires valid domain string)
- Cannot validate domain against 19 valid domains
- Cannot apply domain-specific logging rules
- Cannot track domain-level metrics

**Desired State**:
```elixir
@spec extract_domain_from_resource(module()) :: String.t() | nil
defp extract_domain_from_resource(resource) when is_atom(resource) do
  case Module.split(resource) do
    ["Indrajaal", domain_module | _rest] ->
      domain_module |> Macro.underscore()
    _ ->
      nil
  end
end

# Example: Indrajaal.Billing.Invoice → "billing"
# Example: Indrajaal.Devices.Camera → "devices"
```

**Pattern Source**: `/lib/indrajaal/shared/context_helpers.ex` (lines 371-377)

**Impact**: Cannot leverage DomainLogger's validation and structured logging

---

### Gap 3: No Exception Handling via `ErrorLogger.log_error`

**Current State** (line 253):
```elixir
[:ash, _domain, _action, :exception] ->
  Logger.error("Ash operation failed",
    event: event_name,
    resource: metadata.resource,
    action: metadata.action,
    error: metadata[:error] || metadata[:kind],
    duration_ms: duration_ms
  )
```

**Problem**:
- No automatic error classification (database_error, validation_error, etc.)
- No severity determination (critical, high, medium, low)
- No Jidoka halt triggering for critical errors
- No 5-Level RCA integration
- No retry tracking for recoverable errors

**Desired State**:
```elixir
[:ash, _domain, _action, :exception] ->
  error = metadata[:error] || metadata[:kind]
  if domain do
    ErrorLogger.log_error(domain, operation, error, obs_metadata)
  else
    Logger.error("Ash operation failed",
      Keyword.merge([event: event_name, error: inspect(error)], obs_metadata))
  end
```

**ErrorLogger Benefits**:
- Automatic classification: `:database_error`, `:validation_error`, `:timeout_error`, etc.
- Severity determination: `:critical` → Jidoka halt, `:high` → immediate attention
- TPS integration: 5-Level RCA for systematic problem resolution
- Recovery tracking: `log_error_with_retry/4` for retry scenarios

**Reference**: `/lib/indrajaal/observability/error_logger.ex` (complete implementation)

**Impact**: 100% of errors in Type 3 domains lack proper classification and severity handling

---

### Gap 4: No Audit Trail via `AuditLogger.log_audit_event`

**Current State**: No audit logging for create/update/destroy operations

**Problem**:
- SC-OBS-004 violation (Complete Audit Trail requirement)
- No immutable record of who did what when
- No compliance with SOX, GDPR, HIPAA audit requirements
- Cannot track user actions for security analysis

**Desired State**:
```elixir
if should_audit?(metadata), do: log_audit_event(domain, operation, obs_metadata)

@spec should_audit?(map()) :: boolean()
defp should_audit?(%{action_type: action_type, actor: actor})
  when action_type in [:create, :update, :destroy] and not is_nil(actor), do: true
defp should_audit?(_), do: false

@spec log_audit_event(String.t(), String.t(), keyword()) :: :ok
defp log_audit_event(domain, operation, metadata) do
  AuditLogger.log_audit_event(
    "user_action",
    operation,
    %{
      domain: domain,
      operation: operation,
      resource: metadata[:resource],
      resource_id: metadata[:resource_id],
      action: metadata[:action]
    },
    metadata
  )
end
```

**Audit Criteria**:
- Action type in [:create, :update, :destroy]
- Actor present (user-initiated action, not system)
- Domain successfully extracted

**Reference**: `/test/observability/audit_logger_test.exs` (lines 1-505)

**Impact**: Type 3 domains have 0% audit trail coverage for user actions

---

### Gap 5: Missing `trace_id` Propagation

**Current State**: No OpenTelemetry trace context propagation

**Problem**:
- Cannot correlate logs across distributed services
- Cannot trace requests end-to-end through system
- Missing required metadata for DomainLogger

**Desired State**:
```elixir
@spec get_trace_id() :: String.t()
defp get_trace_id do
  case OpentelemetryProcessPropagator.fetch_trace_id() do
    {:ok, trace_id} -> trace_id
    _ -> "no-trace"
  end
end

# Include in obs_metadata:
trace_id: get_trace_id()
```

**Reference**: `/test/observability/domain_logger_test.exs` (lines 65-75)

**Impact**: Cannot trace requests across services, limiting debugging capabilities

---

### Gap 6: Missing `resource_id` Logging

**Current State**: Resource ID not extracted from Ash metadata

**Problem**:
- Cannot identify which specific record was affected
- Missing required metadata for DomainLogger
- Cannot correlate logs with database records

**Desired State**:
```elixir
@spec extract_resource_id(map()) :: String.t() | nil
defp extract_resource_id(%{data: %{id: id}}) when not is_nil(id), do: to_string(id)
defp extract_resource_id(_), do: nil

# Include in obs_metadata:
resource_id: extract_resource_id(ash_metadata)
```

**Impact**: Cannot track operations on specific records

---

### Gap 7: Uses `actor_id` Instead of `user_id` (Naming Mismatch)

**Current State**: Ash uses `actor` field, DomainLogger expects `user_id`

**Problem**:
- Metadata key mismatch causes DomainLogger validation failure
- Breaks required metadata validation

**Desired State**:
```elixir
@spec extract_actor_id(map()) :: String.t() | nil
defp extract_actor_id(%{actor: %{id: id}}) when not is_nil(id), do: to_string(id)
defp extract_actor_id(%{actor: actor}) when is_binary(actor), do: actor
defp extract_actor_id(_), do: nil

# Map to user_id:
user_id: extract_actor_id(ash_metadata) || "system"
```

**Impact**: All Type 3 domain logs fail DomainLogger validation

---

## 3. Enhancement Design - 4 Core Components

### Component 1: Domain Extraction Function

**Purpose**: Extract domain identifier from Ash resource module name for routing to DomainLogger.

**Implementation**:
```elixir
@doc """
Extracts domain identifier from Ash resource module name.

## Examples

    iex> extract_domain_from_resource(Indrajaal.Billing.Invoice)
    "billing"

    iex> extract_domain_from_resource(Indrajaal.Devices.Camera)
    "devices"

    iex> extract_domain_from_resource(SomeOtherModule)
    nil
"""
@spec extract_domain_from_resource(module()) :: String.t() | nil
defp extract_domain_from_resource(resource) when is_atom(resource) do
  case Module.split(resource) do
    ["Indrajaal", domain_module | _rest] ->
      domain_module |> Macro.underscore()
    _ ->
      nil
  end
end
```

**Pattern Source**: `/lib/indrajaal/shared/context_helpers.ex` (lines 371-377)

**Validation**:
- Returns `String.t()` matching one of 19 valid domains
- Returns `nil` for non-Indrajaal modules (graceful fallback)
- Uses `Macro.underscore()` for consistent naming (e.g., "VisitorManagement" → "visitor_management")

**Test Cases Required** (TDG Methodology):
```elixir
describe "extract_domain_from_resource/1" do
  test "extracts domain from Type 3 billing resource" do
    assert extract_domain_from_resource(Indrajaal.Billing.Invoice) == "billing"
  end

  test "extracts domain from Type 3 devices resource" do
    assert extract_domain_from_resource(Indrajaal.Devices.Camera) == "devices"
  end

  test "returns nil for non-Indrajaal module" do
    assert extract_domain_from_resource(ExternalModule) == nil
  end

  test "handles multi-word domains correctly" do
    assert extract_domain_from_resource(Indrajaal.VisitorManagement.Visit) == "visitor_management"
  end
end
```

---

### Component 2: Metadata Mapping Functions

**Purpose**: Transform Ash telemetry metadata into SOPv5.11-compliant format with all required fields.

**Implementation**:
```elixir
@doc """
Prepares observability metadata from Ash telemetry metadata.

Transforms Ash format to SOPv5.11 format with required fields:
- user_id (from actor)
- tenant_id (from metadata)
- trace_id (from OpenTelemetry context)
- resource_id (from data.id)
- duration_ms
- Additional context fields

## Examples

    iex> metadata = %{
    ...>   resource: Indrajaal.Billing.Invoice,
    ...>   action: :create,
    ...>   action_type: :create,
    ...>   actor: %{id: "user-123"},
    ...>   tenant_id: "tenant-456",
    ...>   data: %{id: "invoice-789"}
    ...> }
    iex> prepare_observability_metadata(metadata, 1250)
    [
      user_id: "user-123",
      tenant_id: "tenant-456",
      trace_id: "trace-abc",
      resource_id: "invoice-789",
      duration_ms: 1250,
      resource: Indrajaal.Billing.Invoice,
      action: :create,
      action_type: :create
    ]
"""
@spec prepare_observability_metadata(map(), integer()) :: keyword()
defp prepare_observability_metadata(ash_metadata, duration_ms) do
  [
    user_id: extract_actor_id(ash_metadata) || "system",
    tenant_id: extract_tenant_id(ash_metadata),
    trace_id: get_trace_id(),
    resource_id: extract_resource_id(ash_metadata),
    duration_ms: duration_ms,
    resource: ash_metadata.resource,
    action: ash_metadata.action,
    action_type: ash_metadata.action_type
  ]
  |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
end

@doc """
Extracts actor ID from Ash metadata and maps to user_id.

Handles multiple actor formats:
- Map with :id key
- String actor identifier
- Nil (returns "system" default)
"""
@spec extract_actor_id(map()) :: String.t() | nil
defp extract_actor_id(%{actor: %{id: id}}) when not is_nil(id), do: to_string(id)
defp extract_actor_id(%{actor: actor}) when is_binary(actor), do: actor
defp extract_actor_id(_), do: nil

@doc """
Extracts tenant_id from Ash metadata for multi-tenancy support.
"""
@spec extract_tenant_id(map()) :: String.t() | nil
defp extract_tenant_id(%{tenant_id: tenant_id}) when not is_nil(tenant_id), do: to_string(tenant_id)
defp extract_tenant_id(%{tenant: tenant_id}) when not is_nil(tenant_id), do: to_string(tenant_id)
defp extract_tenant_id(_), do: nil

@doc """
Extracts resource ID from Ash result data.

Handles cases where data might be:
- Map with :id key
- List of records (uses first record's ID)
- Nil (operation failed)
"""
@spec extract_resource_id(map()) :: String.t() | nil
defp extract_resource_id(%{data: %{id: id}}) when not is_nil(id), do: to_string(id)
defp extract_resource_id(%{data: [%{id: id} | _]}) when not is_nil(id), do: to_string(id)
defp extract_resource_id(_), do: nil

@doc """
Gets current OpenTelemetry trace ID from process context.

Returns "no-trace" if no trace context available (e.g., background jobs).
"""
@spec get_trace_id() :: String.t()
defp get_trace_id do
  case OpentelemetryProcessPropagator.fetch_trace_id() do
    {:ok, trace_id} -> trace_id
    _ -> "no-trace"
  end
end
```

**Reference**: `/test/observability/domain_logger_test.exs` (lines 43-90) for required metadata

**Test Cases Required** (TDG Methodology):
```elixir
describe "prepare_observability_metadata/2" do
  test "transforms Ash metadata to SOPv5.11 format with all fields" do
    ash_metadata = %{
      resource: Indrajaal.Billing.Invoice,
      action: :create,
      action_type: :create,
      actor: %{id: "user-123"},
      tenant_id: "tenant-456",
      data: %{id: "invoice-789"}
    }

    result = prepare_observability_metadata(ash_metadata, 1250)

    assert result[:user_id] == "user-123"
    assert result[:tenant_id] == "tenant-456"
    assert result[:resource_id] == "invoice-789"
    assert result[:duration_ms] == 1250
    assert is_binary(result[:trace_id])
  end

  test "handles missing actor with system default" do
    ash_metadata = %{resource: Indrajaal.Billing.Invoice, action: :create}
    result = prepare_observability_metadata(ash_metadata, 0)
    assert result[:user_id] == "system"
  end

  test "filters out nil values" do
    ash_metadata = %{resource: Indrajaal.Billing.Invoice}
    result = prepare_observability_metadata(ash_metadata, 0)
    refute Keyword.has_key?(result, :tenant_id)
  end
end

describe "extract_resource_id/1" do
  test "extracts ID from single record data" do
    metadata = %{data: %{id: "invoice-123"}}
    assert extract_resource_id(metadata) == "invoice-123"
  end

  test "extracts ID from list of records (first record)" do
    metadata = %{data: [%{id: "invoice-123"}, %{id: "invoice-456"}]}
    assert extract_resource_id(metadata) == "invoice-123"
  end

  test "returns nil for missing data" do
    assert extract_resource_id(%{}) == nil
  end
end

describe "get_trace_id/0" do
  test "returns trace ID from OpenTelemetry context when available" do
    # Setup OpenTelemetry context...
    trace_id = get_trace_id()
    assert is_binary(trace_id)
  end

  test "returns no-trace when OpenTelemetry context unavailable" do
    # Clear OpenTelemetry context...
    assert get_trace_id() == "no-trace"
  end
end
```

---

### Component 3: Enhanced Event Handler with Routing Logic

**Purpose**: Route Ash telemetry events to appropriate SOPv5.11 observability helpers based on event type and domain extraction.

**Implementation**:
```elixir
@doc """
Handles Ash telemetry events with SOPv5.11 observability integration.

Event routing:
- [:ash, domain, action, :stop] → DomainLogger.log_success + optional audit
- [:ash, domain, action, :exception] → ErrorLogger.log_error
- [:ash, domain, action, :start] → No-op (start events not logged)
- Unknown events → Debug log

Fallback strategy:
- If domain extraction fails (non-Indrajaal resource), falls back to Logger
- Preserves all existing functionality while adding SOPv5.11 compliance layer
"""
@spec handle_ash_event(list(atom()), map(), map(), any()) :: :ok
defp handle_ash_event(event_name, measurements, metadata, _config) do
  duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
  domain = extract_domain_from_resource(metadata.resource)
  operation = "#{metadata.action_type}_#{metadata.action}"
  obs_metadata = prepare_observability_metadata(metadata, duration_ms)

  case event_name do
    # SUCCESS: Completed operation (Ash :stop event)
    [:ash, _domain, _action, :stop] ->
      if domain do
        # Route to DomainLogger for SOPv5.11 compliance
        DomainLogger.log_success(domain, operation, obs_metadata)
      else
        # Fallback for non-Indrajaal resources
        Logger.info("Ash operation completed",
          Keyword.merge([event: event_name], obs_metadata))
      end

      # Audit trail for create/update/destroy with actor
      if should_audit?(metadata) do
        log_audit_event(domain, operation, obs_metadata)
      end

    # EXCEPTION: Failed operation (Ash :exception event)
    [:ash, _domain, _action, :exception] ->
      error = metadata[:error] || metadata[:kind]

      if domain do
        # Route to ErrorLogger for automatic classification and severity
        ErrorLogger.log_error(domain, operation, error, obs_metadata)
      else
        # Fallback for non-Indrajaal resources
        Logger.error("Ash operation failed",
          Keyword.merge([event: event_name, error: inspect(error)], obs_metadata))
      end

    # START: Operation initiated (Ash :start event)
    [:ash, _domain, _action, :start] ->
      # No logging for start events (avoid noise)
      :ok

    # UNKNOWN: Unrecognized event
    _ ->
      Logger.debug("Unhandled Ash event: #{inspect(event_name)}")
  end

  # Preserve existing metrics emission
  emit_ash_metrics(event_name, measurements, metadata, duration_ms)
end
```

**Event Flow Diagram**:
```
Ash Telemetry Event
        ↓
extract_domain_from_resource()
        ↓
   domain present?
    ↙         ↘
  YES          NO
   ↓            ↓
SOPv5.11    Logger
Helpers    (fallback)
   ↓
DomainLogger.log_success()
ErrorLogger.log_error()
   ↓
should_audit?()
   ↓
AuditLogger.log_audit_event()
```

**Backward Compatibility**:
- ✅ All existing Ash telemetry consumers continue to work
- ✅ Non-Indrajaal resources fallback to Logger (no breaking changes)
- ✅ Metrics emission preserved via `emit_ash_metrics/4`
- ✅ Zero changes to Ash framework configuration

**Test Cases Required** (TDG Methodology):
```elixir
describe "handle_ash_event/4 - success path" do
  test "routes Type 3 domain success to DomainLogger" do
    event = [:ash, :billing, :create, :stop]
    measurements = %{duration: 1_000_000}  # 1ms in native units
    metadata = %{
      resource: Indrajaal.Billing.Invoice,
      action: :create,
      action_type: :create,
      actor: %{id: "user-123"},
      tenant_id: "tenant-456",
      data: %{id: "invoice-789"}
    }

    log = capture_log(fn ->
      handle_ash_event(event, measurements, metadata, nil)
    end)

    assert log =~ "Domain operation successful"
    assert log =~ "domain: \"billing\""
    assert log =~ "user_id: \"user-123\""
  end

  test "creates audit trail for user-initiated create" do
    metadata = %{
      resource: Indrajaal.Billing.Invoice,
      action: :create,
      action_type: :create,
      actor: %{id: "user-123"},
      data: %{id: "invoice-789"}
    }

    log = capture_log(fn ->
      handle_ash_event([:ash, :billing, :create, :stop], %{duration: 0}, metadata, nil)
    end)

    assert log =~ "Audit event"
    assert log =~ "operation_type: \"user_action\""
  end

  test "falls back to Logger for non-Indrajaal resource" do
    metadata = %{
      resource: ExternalModule.SomeResource,
      action: :read,
      action_type: :read
    }

    log = capture_log(fn ->
      handle_ash_event([:ash, :external, :read, :stop], %{duration: 0}, metadata, nil)
    end)

    assert log =~ "Ash operation completed"
    refute log =~ "Domain operation successful"
  end
end

describe "handle_ash_event/4 - exception path" do
  test "routes Type 3 domain exception to ErrorLogger" do
    metadata = %{
      resource: Indrajaal.Billing.Invoice,
      action: :create,
      action_type: :create,
      error: %RuntimeError{message: "Payment failed"}
    }

    log = capture_log(fn ->
      handle_ash_event([:ash, :billing, :create, :exception], %{duration: 0}, metadata, nil)
    end)

    assert log =~ "Domain operation failed"
    assert log =~ "error_type: :runtime_error"
  end

  test "falls back to Logger for non-Indrajaal resource exception" do
    metadata = %{
      resource: ExternalModule.SomeResource,
      error: %RuntimeError{message: "Failed"}
    }

    log = capture_log(fn ->
      handle_ash_event([:ash, :external, :read, :exception], %{duration: 0}, metadata, nil)
    end)

    assert log =~ "Ash operation failed"
    refute log =~ "Domain operation failed"
  end
end
```

---

### Component 4: Audit Integration Helpers

**Purpose**: Determine when to create audit trail and format audit events for AuditLogger.

**Implementation**:
```elixir
@doc """
Determines if an operation should be audited based on SOPv5.11 criteria.

Audit Criteria (ALL must be true):
- Action type is create, update, or destroy (data mutations)
- Actor is present (user-initiated, not system background job)

Returns true if operation should be audited, false otherwise.

## Examples

    iex> should_audit?(%{action_type: :create, actor: %{id: "user-123"}})
    true

    iex> should_audit?(%{action_type: :read, actor: %{id: "user-123"}})
    false

    iex> should_audit?(%{action_type: :create, actor: nil})
    false
"""
@spec should_audit?(map()) :: boolean()
defp should_audit?(%{action_type: action_type, actor: actor})
  when action_type in [:create, :update, :destroy] and not is_nil(actor), do: true
defp should_audit?(_), do: false

@doc """
Logs audit event to AuditLogger with SOPv5.11 compliance.

Creates immutable audit trail entry with:
- operation_type: "user_action"
- operation_subtype: derived from action (e.g., "create_invoice")
- details: domain, operation, resource info
- metadata: user_id, tenant_id, trace_id, resource_id

Satisfies SC-OBS-004 (Complete Audit Trail) requirement.

## Examples

    iex> log_audit_event("billing", "create_invoice", [
    ...>   user_id: "user-123",
    ...>   tenant_id: "tenant-456",
    ...>   resource_id: "invoice-789",
    ...>   resource: Indrajaal.Billing.Invoice
    ...> ])
    :ok
"""
@spec log_audit_event(String.t(), String.t(), keyword()) :: :ok
defp log_audit_event(domain, operation, metadata) do
  AuditLogger.log_audit_event(
    "user_action",
    operation,
    %{
      domain: domain,
      operation: operation,
      resource: metadata[:resource],
      resource_id: metadata[:resource_id],
      action: metadata[:action]
    },
    metadata
  )
end
```

**Audit Decision Matrix**:
| Action Type | Actor Present | Audit? | Reason |
|-------------|---------------|--------|---------|
| :create     | Yes           | ✅ Yes | User-initiated mutation |
| :update     | Yes           | ✅ Yes | User-initiated mutation |
| :destroy    | Yes           | ✅ Yes | User-initiated mutation |
| :read       | Yes           | ❌ No  | Read-only, no mutation |
| :create     | No            | ❌ No  | System background job |
| :update     | No            | ❌ No  | System background job |

**SC-OBS-004 Compliance**:
- ✅ Audit log entries include all required fields (timestamp, operation_type, details, user, sopv511_compliance)
- ✅ Immutable audit entries (AuditLogger enforces write-once semantics)
- ✅ Complete audit trail for all user-initiated mutations
- ✅ Retention policy enforcement (7+ days minimum)

**Reference**: `/test/observability/audit_logger_test.exs` (lines 9-61) for audit entry structure

**Test Cases Required** (TDG Methodology):
```elixir
describe "should_audit?/1" do
  test "returns true for user-initiated create" do
    metadata = %{action_type: :create, actor: %{id: "user-123"}}
    assert should_audit?(metadata) == true
  end

  test "returns true for user-initiated update" do
    metadata = %{action_type: :update, actor: %{id: "user-123"}}
    assert should_audit?(metadata) == true
  end

  test "returns true for user-initiated destroy" do
    metadata = %{action_type: :destroy, actor: %{id: "user-123"}}
    assert should_audit?(metadata) == true
  end

  test "returns false for read operation" do
    metadata = %{action_type: :read, actor: %{id: "user-123"}}
    assert should_audit?(metadata) == false
  end

  test "returns false for system operation (no actor)" do
    metadata = %{action_type: :create, actor: nil}
    assert should_audit?(metadata) == false
  end
end

describe "log_audit_event/3" do
  test "creates audit trail with SC-OBS-004 compliance" do
    log = capture_log(fn ->
      log_audit_event("billing", "create_invoice", [
        user_id: "user-123",
        tenant_id: "tenant-456",
        resource_id: "invoice-789",
        resource: Indrajaal.Billing.Invoice,
        action: :create
      ])
    end)

    assert log =~ "Audit event"
    assert log =~ "operation_type: \"user_action\""
    assert log =~ "operation_subtype: \"create_invoice\""
    assert log =~ "sopv511_compliance: \"SC-OBS-004\""
  end
end
```

---

## 4. Implementation Plan - 11 Tasks, 6.5 Hours Total

### 4.1 Component Implementation Tasks (4 hours)

#### Task 11.4.1.1.1: Add Module Imports to telemetry.ex (15 min)

**Objective**: Add required observability module imports to `/lib/indrajaal/telemetry.ex`

**File**: `/lib/indrajaal/telemetry.ex`

**Changes**:
```elixir
# Add after line 5 (existing require Logger):
alias Indrajaal.Observability.{DomainLogger, ErrorLogger, AuditLogger}

# Add after line 15 (ensure OpenTelemetry availability):
require OpentelemetryProcessPropagator
```

**TDG Requirements**: No tests needed (import-only change)

**Verification**: Compilation succeeds without warnings

---

#### Task 11.4.1.1.2: Implement Domain Extraction Function (45 min)

**Objective**: Add `extract_domain_from_resource/1` function with full test coverage

**File**: `/lib/indrajaal/telemetry.ex`

**Implementation**: See Component 1 design above

**TDG Requirements**: Write 4 test cases FIRST in `test/indrajaal/telemetry_test.exs`:
1. Extracts domain from Type 3 billing resource
2. Extracts domain from Type 3 devices resource
3. Returns nil for non-Indrajaal module
4. Handles multi-word domains correctly (visitor_management)

**Verification**:
- All 4 tests pass
- Pattern matches `/lib/indrajaal/shared/context_helpers.ex` (lines 371-377)

---

#### Task 11.4.1.1.3: Implement Metadata Mapping Functions (1 hour)

**Objective**: Add all metadata transformation functions with full test coverage

**File**: `/lib/indrajaal/telemetry.ex`

**Implementation**: See Component 2 design above (5 functions):
1. `prepare_observability_metadata/2`
2. `extract_actor_id/1`
3. `extract_tenant_id/1`
4. `extract_resource_id/1`
5. `get_trace_id/0`

**TDG Requirements**: Write 8 test cases FIRST in `test/indrajaal/telemetry_test.exs`:
1. Transforms complete metadata to SOPv5.11 format
2. Handles missing actor with "system" default
3. Filters out nil values
4. Extracts resource_id from single record
5. Extracts resource_id from list (first record)
6. Returns nil for missing resource data
7. Gets trace_id from OpenTelemetry when available
8. Returns "no-trace" when OpenTelemetry unavailable

**Verification**:
- All 8 tests pass
- Metadata format matches DomainLogger requirements (`/test/observability/domain_logger_test.exs` lines 43-90)

---

#### Task 11.4.1.1.4: Implement Event Routing Logic (1.5 hours)

**Objective**: Update `handle_ash_event/4` with SOPv5.11 routing logic and full test coverage

**File**: `/lib/indrajaal/telemetry.ex` (lines 242-257)

**Implementation**: See Component 3 design above

**TDG Requirements**: Write 6 test cases FIRST in `test/indrajaal/telemetry_test.exs`:
1. Routes Type 3 domain success to DomainLogger
2. Creates audit trail for user-initiated create
3. Falls back to Logger for non-Indrajaal resource success
4. Routes Type 3 domain exception to ErrorLogger
5. Falls back to Logger for non-Indrajaal resource exception
6. Preserves metrics emission via emit_ash_metrics/4

**Verification**:
- All 6 tests pass
- Backward compatibility: All existing Ash telemetry consumers still work
- Zero breaking changes to Ash framework

---

#### Task 11.4.1.1.5: Implement Audit Integration Helpers (1 hour)

**Objective**: Add `should_audit?/1` and `log_audit_event/3` functions with full test coverage

**File**: `/lib/indrajaal/telemetry.ex`

**Implementation**: See Component 4 design above

**TDG Requirements**: Write 7 test cases FIRST in `test/indrajaal/telemetry_test.exs`:
1. should_audit? returns true for user-initiated create
2. should_audit? returns true for user-initiated update
3. should_audit? returns true for user-initiated destroy
4. should_audit? returns false for read operation
5. should_audit? returns false for system operation (no actor)
6. log_audit_event creates SC-OBS-004 compliant audit trail
7. log_audit_event includes all required fields

**Verification**:
- All 7 tests pass
- Audit entry structure matches `/test/observability/audit_logger_test.exs` (lines 9-61)
- SC-OBS-004 compliance validated

---

### 4.2 Verification Tasks (2.5 hours)

#### Task 11.4.1.2.1: Integration Testing with Sample Events (1.5 hours)

**Objective**: End-to-end integration testing with real Ash telemetry events from all 10 Type 3 domains

**Approach**:
1. Create test that simulates Ash telemetry events for each Type 3 domain:
   - billing, devices, sites, visitor_management, communication
   - guard_tour, maintenance, risk_management, analytics, policy
2. Verify DomainLogger receives events with correct metadata
3. Verify ErrorLogger receives exception events
4. Verify AuditLogger receives create/update/destroy events
5. Verify fallback to Logger for non-Indrajaal resources

**Test File**: `test/indrajaal/telemetry_integration_test.exs`

**Test Cases**:
```elixir
defmodule Indrajaal.TelemetryIntegrationTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "Type 3 Domain Integration" do
    test "billing domain: create invoice success" do
      event = [:ash, :billing, :create, :stop]
      measurements = %{duration: 1_250_000}  # 1.25ms
      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        action_type: :create,
        actor: %{id: "user-123"},
        tenant_id: "tenant-456",
        data: %{id: "invoice-789"}
      }

      log = capture_log(fn ->
        Indrajaal.Telemetry.handle_ash_event(event, measurements, metadata, nil)
      end)

      # Verify DomainLogger
      assert log =~ "Domain operation successful"
      assert log =~ "domain: \"billing\""
      assert log =~ "user_id: \"user-123\""
      assert log =~ "resource_id: \"invoice-789\""

      # Verify AuditLogger
      assert log =~ "Audit event"
      assert log =~ "operation_type: \"user_action\""
    end

    test "devices domain: camera update failure" do
      event = [:ash, :devices, :update, :exception]
      metadata = %{
        resource: Indrajaal.Devices.Camera,
        action: :update,
        action_type: :update,
        error: %RuntimeError{message: "Connection timeout"},
        actor: %{id: "user-456"}
      }

      log = capture_log(fn ->
        Indrajaal.Telemetry.handle_ash_event(event, %{duration: 0}, metadata, nil)
      end)

      # Verify ErrorLogger
      assert log =~ "Domain operation failed"
      assert log =~ "domain: \"devices\""
      assert log =~ "error_type: :runtime_error"
    end

    # Test all 10 Type 3 domains...
  end

  describe "Fallback Behavior" do
    test "non-Indrajaal resource uses Logger fallback" do
      metadata = %{
        resource: ExternalModule.SomeResource,
        action: :read
      }

      log = capture_log(fn ->
        Indrajaal.Telemetry.handle_ash_event(
          [:ash, :external, :read, :stop],
          %{duration: 0},
          metadata,
          nil
        )
      end)

      assert log =~ "Ash operation completed"
      refute log =~ "Domain operation successful"
    end
  end
end
```

**Success Criteria**:
- All 10 Type 3 domains successfully route to observability helpers
- Fallback to Logger works for non-Indrajaal resources
- Zero errors, zero warnings during integration tests

---

#### Task 11.4.1.2.2: STAMP Safety Constraint Validation (30 min)

**Objective**: Verify SC-OBS-001 (100% Observability Coverage) and SC-OBS-004 (Complete Audit Trail) compliance

**Test File**: `test/stamp/type3_domain_observability_constraints_test.exs`

**Test Cases**:
```elixir
defmodule STAMP.Type3DomainObservabilityConstraintsTest do
  use ExUnit.Case, async: true

  describe "SC-OBS-001: 100% Observability Coverage" do
    test "all Type 3 domains have observability helper integration" do
      type3_domains = [
        "billing", "devices", "sites", "visitor_management", "communication",
        "guard_tour", "maintenance", "risk_management", "analytics", "policy"
      ]

      for domain <- type3_domains do
        # Verify domain extraction works
        resource_module = Module.concat([Indrajaal, Macro.camelize(domain), "TestResource"])
        assert extract_domain_from_resource(resource_module) == domain

        # Verify DomainLogger accepts domain
        assert :ok = DomainLogger.validate_domain!(domain)
      end
    end

    test "success events route to DomainLogger with required metadata" do
      # Test that all success events include user_id, tenant_id, trace_id, resource_id
      # (See implementation in Task 11.4.1.2.1)
    end

    test "exception events route to ErrorLogger with classification" do
      # Test that all exception events receive automatic error classification
      # (See implementation in Task 11.4.1.2.1)
    end
  end

  describe "SC-OBS-004: Complete Audit Trail" do
    test "user-initiated mutations create audit trail" do
      mutation_types = [:create, :update, :destroy]

      for action_type <- mutation_types do
        metadata = %{
          resource: Indrajaal.Billing.Invoice,
          action: action_type,
          action_type: action_type,
          actor: %{id: "user-123"},
          data: %{id: "test-id"}
        }

        assert should_audit?(metadata) == true
      end
    end

    test "read operations do not create audit trail" do
      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :read,
        action_type: :read,
        actor: %{id: "user-123"}
      }

      assert should_audit?(metadata) == false
    end

    test "system operations (no actor) do not create audit trail" do
      metadata = %{
        resource: Indrajaal.Billing.Invoice,
        action: :create,
        action_type: :create,
        actor: nil
      }

      assert should_audit?(metadata) == false
    end

    test "audit entries include all SC-OBS-004 required fields" do
      # Verify: timestamp, operation_type, operation_subtype, details, user, sopv511_compliance
      # (See implementation in Component 4 test cases)
    end
  end
end
```

**Success Criteria**:
- SC-OBS-001 validated: 100% of Type 3 domains have observability coverage
- SC-OBS-004 validated: Complete audit trail for all user-initiated mutations
- Zero STAMP constraint violations

---

#### Task 11.4.1.2.3: Final Comprehensive Verification (30 min)

**Objective**: Run complete test suite and verify zero errors, zero warnings

**Commands**:
```bash
# 1. Run all tests
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true MIX_ENV=test mix test

# 2. Verify telemetry tests specifically
mix test test/indrajaal/telemetry_test.exs
mix test test/indrajaal/telemetry_integration_test.exs
mix test test/stamp/type3_domain_observability_constraints_test.exs

# 3. Run compilation with warnings-as-errors
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --warnings-as-errors

# 4. Verify observability helper tests still pass
mix test test/observability/domain_logger_test.exs
mix test test/observability/error_logger_test.exs
mix test test/observability/audit_logger_test.exs
```

**Success Criteria**:
- ✅ All tests pass (0 failures)
- ✅ Zero compilation warnings
- ✅ Zero compilation errors
- ✅ All observability helper tests still pass (backward compatibility)

---

#### Task 11.4.1.2.4: Update Documentation (30 min)

**Objective**: Update documentation to reflect Type 3 domain SOPv5.11 compliance

**Files to Update**:

1. **`/lib/indrajaal/telemetry.ex` module documentation**:
```elixir
@moduledoc """
Telemetry and observability infrastructure for Indrajaal.

## SOPv5.11 Observability Integration

This module integrates Ash Framework telemetry with SOPv5.11 observability standards
via the three-helper framework:
- DomainLogger: Structured logging with required metadata validation
- ErrorLogger: Automatic error classification and severity determination
- AuditLogger: Complete audit trail for SC-OBS-004 compliance

## Type 3 Domain Support

Type 3 domains (60% of system, 39 resources) have full Ash telemetry infrastructure
and now receive complete SOPv5.11 observability coverage:

Supported Domains:
- billing (6 resources)
- devices (4 resources)
- sites (3 resources)
- visitor_management (5 resources)
- communication (4 resources)
- guard_tour (3 resources)
- maintenance (4 resources)
- risk_management (3 resources)
- analytics (4 resources)
- policy (3 resources)

## Event Routing

Ash telemetry events are routed as follows:
- [:ash, domain, action, :stop] → DomainLogger.log_success + optional audit
- [:ash, domain, action, :exception] → ErrorLogger.log_error
- [:ash, domain, action, :start] → No-op (not logged)

Fallback: Non-Indrajaal resources fallback to standard Logger (backward compatibility).

## Metadata Requirements

All logged events include SOPv5.11-required metadata:
- user_id: Actor ID or "system"
- tenant_id: Tenant identifier for multi-tenancy
- trace_id: OpenTelemetry trace context
- resource_id: Affected record ID
- duration_ms: Operation duration

## Audit Trail

User-initiated mutations (create/update/destroy) automatically create audit trail
via AuditLogger for SC-OBS-004 compliance.
"""
```

2. **`CHANGELOG.md`**:
```markdown
## [Unreleased]

### Added
- Type 3 Domain SOPv5.11 Observability Compliance (60% of system, 39 resources)
  - DomainLogger integration for all Ash telemetry success events
  - ErrorLogger integration for all Ash telemetry exception events
  - AuditLogger integration for user-initiated mutations
  - Complete SC-OBS-001 (100% Observability Coverage) compliance
  - Complete SC-OBS-004 (Complete Audit Trail) compliance
  - Backward compatibility with all existing Ash telemetry consumers
```

3. **`PROJECT_TODOLIST.md`**: Update Task 11.4 status from in_progress to completed

**Success Criteria**:
- All documentation accurately reflects implementation
- MODULE documentation updated
- CHANGELOG.md updated
- PROJECT_TODOLIST.md updated

---

## 5. Risk Assessment

### 5.1 Identified Risks

**Risk 1: DomainLogger Validation Failure for Multi-Word Domains**

**Probability**: LOW
**Impact**: MEDIUM
**Mitigation**:
- Use `Macro.underscore()` consistently (same pattern as context_helpers.ex)
- Test multi-word domains explicitly (visitor_management, guard_tour, risk_management)
- Validation: Domain extraction test case #4

**Risk 2: Missing tenant_id in Some Ash Contexts**

**Probability**: MEDIUM
**Impact**: LOW
**Mitigation**:
- `extract_tenant_id/1` handles both `:tenant_id` and `:tenant` keys
- Returns `nil` if neither present (filtered out via `Enum.filter`)
- DomainLogger allows optional tenant_id for system operations

**Risk 3: Backward Compatibility with Existing Telemetry Consumers**

**Probability**: LOW
**Impact**: HIGH
**Mitigation**:
- Preserve `emit_ash_metrics/4` call in all code paths
- No changes to Ash framework telemetry event structure
- Fallback to Logger for non-Indrajaal resources
- Comprehensive integration testing (Task 11.4.1.2.1)

**Risk 4: Performance Impact of Domain Extraction**

**Probability**: LOW
**Impact**: LOW
**Mitigation**:
- Domain extraction is O(1) operation (Module.split + Enum.at)
- Cached in `domain` variable, only executed once per event
- No database queries or external calls

**Risk 5: OpenTelemetry Context Unavailable in Background Jobs**

**Probability**: MEDIUM
**Impact**: LOW
**Mitigation**:
- `get_trace_id/0` returns "no-trace" fallback
- Background jobs still get logged with other metadata
- trace_id is optional for DomainLogger

---

### 5.2 Edge Cases

**Edge Case 1: Non-Indrajaal Resource Module**

**Example**: `ExternalModule.SomeResource`

**Handling**:
```elixir
domain = extract_domain_from_resource(ExternalModule.SomeResource)
# Returns: nil

# In handle_ash_event/4:
if domain do
  DomainLogger.log_success(domain, operation, obs_metadata)
else
  Logger.info("Ash operation completed", obs_metadata)  # Fallback
end
```

**Result**: Graceful fallback to standard Logger, no errors

---

**Edge Case 2: Ash Operation with No actor (System Background Job)**

**Example**: Scheduled invoice generation

**Handling**:
```elixir
user_id: extract_actor_id(%{actor: nil}) || "system"
# Returns: "system"

should_audit?(%{action_type: :create, actor: nil})
# Returns: false (no audit for system operations)
```

**Result**: Logged with user_id="system", no audit trail created

---

**Edge Case 3: Ash Operation with No data (Failed Validation)**

**Example**: Create invoice with validation errors

**Handling**:
```elixir
resource_id: extract_resource_id(%{data: nil})
# Returns: nil

# In prepare_observability_metadata/2:
|> Enum.filter(fn {_k, v} -> not is_nil(v) end)
# resource_id filtered out
```

**Result**: Logged without resource_id (operation failed before record creation)

---

**Edge Case 4: Ash Operation with List of Records (Bulk Operation)**

**Example**: Bulk create invoices

**Handling**:
```elixir
resource_id: extract_resource_id(%{data: [%{id: "inv-1"}, %{id: "inv-2"}]})
# Returns: "inv-1" (first record ID)
```

**Result**: Logged with first record ID as representative

**Note**: Consider future enhancement for bulk operation logging

---

**Edge Case 5: Ash Operation with Missing tenant_id**

**Example**: Global configuration resource

**Handling**:
```elixir
tenant_id: extract_tenant_id(%{})
# Returns: nil

# In prepare_observability_metadata/2:
|> Enum.filter(fn {_k, v} -> not is_nil(v) end)
# tenant_id filtered out
```

**Result**: Logged without tenant_id (DomainLogger allows optional tenant_id)

---

## 6. Success Criteria

### 6.1 Functional Requirements

✅ **FR-1**: All 10 Type 3 domains route to DomainLogger for success events
✅ **FR-2**: All 10 Type 3 domains route to ErrorLogger for exception events
✅ **FR-3**: User-initiated mutations create audit trail via AuditLogger
✅ **FR-4**: Domain extraction works for all Type 3 domain resources
✅ **FR-5**: Metadata transformation includes all required fields (user_id, tenant_id, trace_id, resource_id, duration_ms)
✅ **FR-6**: Fallback to Logger works for non-Indrajaal resources
✅ **FR-7**: Backward compatibility maintained with existing Ash telemetry consumers

---

### 6.2 Quality Requirements

✅ **QR-1**: Zero compilation errors
✅ **QR-2**: Zero compilation warnings
✅ **QR-3**: All tests pass (unit + integration + STAMP)
✅ **QR-4**: TDG compliance: All tests written BEFORE implementation
✅ **QR-5**: 100% test coverage for new functions
✅ **QR-6**: Code quality: mix format, mix credo --strict pass

---

### 6.3 STAMP Safety Constraints

✅ **SC-OBS-001**: 100% Observability Coverage
- All 10 Type 3 domains have observability helper integration
- All success events logged via DomainLogger
- All exception events logged via ErrorLogger

✅ **SC-OBS-004**: Complete Audit Trail
- All user-initiated create operations audited
- All user-initiated update operations audited
- All user-initiated destroy operations audited
- Audit entries include all required fields
- Audit entries immutable (AuditLogger enforces)

---

### 6.4 Performance Requirements

✅ **PR-1**: No measurable performance degradation (<1ms overhead per event)
✅ **PR-2**: Domain extraction: O(1) operation
✅ **PR-3**: Metadata transformation: O(1) operation
✅ **PR-4**: No additional database queries introduced

---

## 7. Testing Strategy

### 7.1 TDG Methodology (Test-Driven Generation)

**Principle**: Write ALL tests BEFORE implementation code.

**Test Categories**:
1. **Unit Tests**: Individual function testing (25 test cases)
2. **Integration Tests**: End-to-end event flow (10+ test cases)
3. **STAMP Tests**: Safety constraint validation (8+ test cases)

**Total Test Cases**: 43+ comprehensive tests

---

### 7.2 Unit Test Plan

**Test File**: `test/indrajaal/telemetry_test.exs`

**Test Organization**:
```elixir
defmodule Indrajaal.TelemetryTest do
  use ExUnit.Case, async: true

  describe "extract_domain_from_resource/1" do
    # 4 test cases (see Component 1)
  end

  describe "prepare_observability_metadata/2" do
    # 3 test cases (see Component 2)
  end

  describe "extract_actor_id/1" do
    # 3 test cases (see Component 2)
  end

  describe "extract_tenant_id/1" do
    # 2 test cases (see Component 2)
  end

  describe "extract_resource_id/1" do
    # 3 test cases (see Component 2)
  end

  describe "get_trace_id/0" do
    # 2 test cases (see Component 2)
  end

  describe "handle_ash_event/4 - success path" do
    # 3 test cases (see Component 3)
  end

  describe "handle_ash_event/4 - exception path" do
    # 2 test cases (see Component 3)
  end

  describe "should_audit?/1" do
    # 5 test cases (see Component 4)
  end

  describe "log_audit_event/3" do
    # 1 test case (see Component 4)
  end
end
```

**Total**: 28 unit tests

---

### 7.3 Integration Test Plan

**Test File**: `test/indrajaal/telemetry_integration_test.exs`

**Test Organization**:
```elixir
defmodule Indrajaal.TelemetryIntegrationTest do
  use ExUnit.Case, async: true

  describe "Type 3 Domain Integration" do
    test "billing domain: create invoice success" do
    test "billing domain: update invoice failure" do
    test "devices domain: camera create success" do
    test "devices domain: camera update failure" do
    test "sites domain: location read (no audit)" do
    test "visitor_management domain: visit create success" do
    test "communication domain: message send exception" do
    test "guard_tour domain: checkpoint create success" do
    test "maintenance domain: work order update success" do
    test "risk_management domain: assessment create success" do
    test "analytics domain: report generate success" do
    test "policy domain: rule create success" do
  end

  describe "Fallback Behavior" do
    test "non-Indrajaal resource uses Logger fallback" do
  end

  describe "Metrics Preservation" do
    test "emit_ash_metrics called for all event types" do
  end
end
```

**Total**: 14 integration tests

---

### 7.4 STAMP Safety Constraint Test Plan

**Test File**: `test/stamp/type3_domain_observability_constraints_test.exs`

**Test Organization**:
```elixir
defmodule STAMP.Type3DomainObservabilityConstraintsTest do
  use ExUnit.Case, async: true

  describe "SC-OBS-001: 100% Observability Coverage" do
    test "all Type 3 domains have observability helper integration" do
    test "success events route to DomainLogger with required metadata" do
    test "exception events route to ErrorLogger with classification" do
  end

  describe "SC-OBS-004: Complete Audit Trail" do
    test "user-initiated mutations create audit trail" do
    test "read operations do not create audit trail" do
    test "system operations (no actor) do not create audit trail" do
    test "audit entries include all SC-OBS-004 required fields" do
  end
end
```

**Total**: 7 STAMP tests

---

## 8. References

### 8.1 Pattern Source Files

**Domain Extraction Pattern**:
- File: `/lib/indrajaal/shared/context_helpers.ex`
- Lines: 371-377
- Function: `extract_domain/1`
- Pattern: `Module.split() |> Enum.at(1) |> Macro.underscore()`

**DomainLogger API Reference**:
- File: `/test/observability/domain_logger_test.exs`
- Lines: 43-90
- Required Metadata: user_id, tenant_id, trace_id, resource_id, duration_ms
- Valid Domains: 19 domains validated (lines 18-38)

**ErrorLogger API Reference**:
- File: `/test/observability/error_logger_test.exs`
- Lines: 21-36
- API: `log_error(domain, operation, error, metadata)`
- Features: Automatic classification, severity determination, Jidoka halt

**AuditLogger API Reference**:
- File: `/test/observability/audit_logger_test.exs`
- Lines: 9-61
- API: `log_audit_event(operation_type, operation_subtype, details, metadata)`
- SC-OBS-004 Compliance: Required fields, immutability, retention

**ErrorLogger Implementation Reference**:
- File: `/lib/indrajaal/observability/error_logger.ex`
- Complete implementation of error classification, severity determination
- Functions: `log_error/4`, `log_error_with_retry/4`, `log_recoverable_error/4`, `log_critical_error/4`

---

### 8.2 SOPv5.11 Compliance Documents

**STAMP Safety Constraints**:
- SC-OBS-001: 100% Observability Coverage
- SC-OBS-004: Complete Audit Trail

**TDG Methodology**:
- Test-Driven Generation: Write tests FIRST before implementation
- Test coverage: 100% for all new functions

**TPS Methodology**:
- Jidoka: ErrorLogger triggers automatic halt for critical errors
- 5-Level RCA: Integrated into ErrorLogger

---

## 9. Next Steps

### 9.1 Immediate Actions

1. ✅ **COMPLETED**: Update PROJECT_TODOLIST.md with 4-level implementation plan
2. ✅ **COMPLETED**: Create this journal entry documenting complete enhancement design
3. ⏳ **NEXT**: Begin implementation starting with Task 11.4.1.1.1 (Add Module Imports)

### 9.2 Implementation Sequence

**Phase 1: Component Implementation** (4 hours):
1. Task 11.4.1.1.1: Add Module Imports (15 min)
2. Task 11.4.1.1.2: Implement Domain Extraction (45 min)
3. Task 11.4.1.1.3: Implement Metadata Mapping (1 hour)
4. Task 11.4.1.1.4: Implement Event Routing Logic (1.5 hours)
5. Task 11.4.1.1.5: Implement Audit Integration (1 hour)

**Phase 2: Verification** (2.5 hours):
6. Task 11.4.1.2.1: Integration Testing (1.5 hours)
7. Task 11.4.1.2.2: STAMP Safety Validation (30 min)
8. Task 11.4.1.2.3: Final Comprehensive Verification (30 min)
9. Task 11.4.1.2.4: Update Documentation (30 min)

**Total Effort**: 6.5 hours

---

## 10. Conclusion

This comprehensive design brings Type 3 domains (60% of system, 39 resources) into full SOPv5.11 observability compliance through a minimal enhancement strategy that:

✅ Preserves existing Ash telemetry infrastructure
✅ Adds SOPv5.11 compliance layer via event routing
✅ Maintains 100% backward compatibility
✅ Achieves SC-OBS-001 (100% Observability Coverage)
✅ Achieves SC-OBS-004 (Complete Audit Trail)
✅ Follows TDG methodology (tests first)
✅ Integrates TPS principles (Jidoka, 5-Level RCA)
✅ Provides comprehensive test coverage (43+ tests)

**Impact**: Complete observability coverage for 60% of system (39 resources) with zero breaking changes and enterprise-grade reliability.

---

**Document Status**: ✅ DESIGN COMPLETE | ⏳ IMPLEMENTATION PENDING
**Next Action**: Begin Task 11.4.1.1.1 - Add Module Imports to telemetry.ex (15 min)
**Total Implementation Time**: 6.5 hours with comprehensive validation
