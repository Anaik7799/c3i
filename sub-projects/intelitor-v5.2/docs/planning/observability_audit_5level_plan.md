# Comprehensive Observability Audit & Enhancement Plan
## 5-Level Detailed Implementation Plan

**Document Version**: 1.0
**Created**: 2025-01-23
**Status**: Approved - Ready for Implementation
**Total Effort**: 250 hours across 7 phases

---

## Level 1: Executive Summary (Strategic Overview)

### Mission Statement
Establish enterprise-grade observability across all 19 Ash domains of the Indrajaal Security Monitoring System, ensuring 100% coverage for logging, telemetry, health monitoring, and audit trails with full SOPv5.11 compliance.

### Strategic Goals
1. **Complete Observability Coverage**: 100% of critical operations instrumented
2. **STAMP Safety Compliance**: All 4 SC-OBS constraints validated
3. **Production Readiness**: Enterprise-grade monitoring and alerting
4. **Regulatory Compliance**: Complete audit trail for SOX, GDPR, HIPAA
5. **Operational Excellence**: <1 minute incident detection, <5 minute MTTR

### Current State Assessment
- **Domain Coverage**: 47% (9 of 19 domains instrumented)
- **Logging Coverage**: <10% (minimal Logger calls)
- **Health Checks**: Partial (no unified framework)
- **Audit Logging**: 30% (limited forensic trails)
- **Test Coverage**: <50% for observability code

### Target State
- **Domain Coverage**: 100% (all 19 domains)
- **Logging Coverage**: 100% (all critical operations)
- **Health Checks**: Complete (unified framework, <100ms response)
- **Audit Logging**: 100% (complete forensic trails)
- **Test Coverage**: >95% for observability code

### Business Value
- **Risk Reduction**: Early detection of security incidents
- **Compliance**: Meet regulatory audit requirements
- **Performance**: Identify and resolve bottlenecks
- **Reliability**: Proactive issue detection before customer impact
- **Cost Savings**: Reduced MTTR from hours to minutes

### Key Stakeholders
- **Operations Team**: Daily monitoring and incident response
- **Security Team**: Audit trail analysis and compliance
- **Development Team**: Performance optimization and debugging
- **Compliance Officer**: Regulatory reporting
- **Executive Leadership**: Business impact visibility

---

## Level 2: Tactical Breakdown (7 Phases)

### Phase 1: Critical Logging Infrastructure (P0 - 40 hours)
**Objective**: Add comprehensive structured logging across all 19 domains

**Deliverables**:
- Logger calls in 200+ critical operation points
- Structured log metadata (user_id, tenant_id, trace_id)
- Consistent log levels across all domains
- Log aggregation in SigNoz

**Success Metrics**:
- 100% of critical operations have logging
- All logs include trace context
- <50ms logging overhead

### Phase 2: Complete Domain Instrumentation (P0 - 60 hours)
**Objective**: Implement telemetry for 10 missing domains

**Deliverables**:
- 10 new instrumentation modules
- Domain-specific metrics registration
- STAMP safety constraint tracking
- Performance baseline establishment

**Success Metrics**:
- 100% domain coverage (19/19)
- All domains emit telemetry events
- Metrics visible in SigNoz dashboards

### Phase 3: Health Check Framework (P1 - 30 hours)
**Objective**: Unified health monitoring system

**Deliverables**:
- Health check registry and metrics
- Component health checks (DB, Redis, OTLP, etc.)
- 4 health endpoints (basic, detailed, readiness, liveness)
- Integration with monitoring systems

**Success Metrics**:
- <100ms health check response time
- All critical components monitored
- Kubernetes-compatible probes

### Phase 4: Audit Logging System (P1 - 35 hours)
**Objective**: Forensic audit trail for compliance

**Deliverables**:
- Audit logging framework
- Immutable audit trail storage
- Compliance-relevant event capture
- 7-day minimum retention

**Success Metrics**:
- SC-OBS-004 compliance validated
- All authentication/authorization logged
- Tamper-proof audit trail

### Phase 5: SigNoz Integration Enhancement (P2 - 25 hours)
**Objective**: Complete observability dashboards and alerting

**Deliverables**:
- 19 domain-specific dashboards
- Alerting rules for critical metrics
- Custom service maps
- Performance SLO tracking

**Success Metrics**:
- All domains have dashboards
- <1 minute alert notification
- 95% alert accuracy (low false positives)

### Phase 6: Test Suite for Observability (P2 - 45 hours)
**Objective**: Comprehensive TDG test coverage

**Deliverables**:
- Unit tests for all instrumentation
- Integration tests for telemetry pipeline
- Property-based tests for metrics
- Health check endpoint tests

**Success Metrics**:
- >95% test coverage
- All tests follow TDG methodology
- Property tests validate metric accuracy

### Phase 7: SOPv5.11 Compliance Validation (P3 - 15 hours)
**Objective**: Validate all safety constraints

**Deliverables**:
- STAMP safety constraint validation
- TDG methodology compliance report
- GDE goal tracking verification
- Compliance documentation

**Success Metrics**:
- SC-OBS-001: 100% critical operation observability
- SC-OBS-002: <1 minute anomaly detection
- SC-OBS-003: 7-day data retention validated
- SC-OBS-004: Complete audit trail verified

---

## Level 3: Operational Details (Task-Level Breakdown)

### Phase 1: Critical Logging Infrastructure (P0)

#### Task 1.1: Audit Existing Logging (4 hours)
**Steps**:
1. Scan all 19 domains for existing Logger calls
2. Identify critical operations without logging
3. Document current logging patterns
4. Create logging coverage matrix

**Tools**: `grep -r "Logger\." lib/`, custom analysis scripts

**Output**: `logging_coverage_matrix.md` in `/docs/planning/`

#### Task 1.2: Define Logging Standards (3 hours)
**Steps**:
1. Define log levels (info, warn, error, debug)
2. Define required metadata fields
3. Create logging helper modules
4. Document logging best practices

**Files to Create**:
- `/lib/indrajaal/logging/logging_helpers.ex`
- `/docs/guides/logging_standards.md`

#### Task 1.3: Implement Domain-Specific Logging (28 hours)
**Steps** (for each domain):
1. Identify critical operations (create, update, delete, critical reads)
2. Add Logger.info() for operational events
3. Add Logger.warn() for recoverable issues
4. Add Logger.error() for failures
5. Include metadata: user_id, tenant_id, trace_id, operation_context

**Domains**:
1. Access Control (2h)
2. Accounts (2h)
3. Alarms (2h)
4. Analytics (1.5h)
5. Asset Management (1.5h)
6. Billing (1.5h)
7. Communication (1.5h)
8. Compliance (2h)
9. Core (2h)
10. Devices (1.5h)
11. Dispatch (1.5h)
12. Guard Tour (1.5h)
13. Integrations (2h)
14. Maintenance (1.5h)
15. Policy (1.5h)
16. Risk Management (1.5h)
17. Sites (1.5h)
18. Video (2h)
19. Visitor Management (1.5h)

#### Task 1.4: Test Logging Integration (3 hours)
**Steps**:
1. Verify logs appear in console
2. Verify logs appear in SigNoz
3. Test log metadata extraction
4. Validate trace context propagation

#### Task 1.5: Documentation & Review (2 hours)
**Steps**:
1. Update logging documentation
2. Create logging examples for each domain
3. Peer review logging implementation
4. Update OPERATIONAL_RUNBOOKS.md

### Phase 2: Complete Domain Instrumentation (P0)

#### Task 2.1: Create Instrumentation Module Template (4 hours)
**Steps**:
1. Analyze existing instrumentation modules
2. Create reusable template
3. Define common metrics (operation_count, duration, error_rate)
4. Include STAMP constraint tracking

**Output**: `/lib/indrajaal/observability/domains/_template_instrumentation.ex`

#### Task 2.2: Implement 10 Missing Instrumentation Modules (50 hours)

**For Each Domain (5 hours each)**:

**Asset Management Domain (5h)**:
```elixir
# /lib/indrajaal/observability/domains/asset_management_instrumentation.ex

defmodule Indrajaal.Observability.Domains.AssetManagementInstrumentation do
  @moduledoc """
  Telemetry instrumentation for Asset Management domain.
  Tracks asset creation, updates, lifecycle events, and performance.
  """

  alias Indrajaal.Observability.Helpers.InstrumentationHelper

  @domain_prefix [:indrajaal, :asset_management]

  # Step 1: Define metrics to track
  def metrics do
    [
      # Operation counters
      counter(@domain_prefix ++ [:asset, :created]),
      counter(@domain_prefix ++ [:asset, :updated]),
      counter(@domain_prefix ++ [:asset, :deleted]),
      counter(@domain_prefix ++ [:asset, :errors]),

      # Operation durations
      distribution(@domain_prefix ++ [:asset, :create_duration]),
      distribution(@domain_prefix ++ [:asset, :update_duration]),

      # Business metrics
      gauge(@domain_prefix ++ [:assets, :total]),
      gauge(@domain_prefix ++ [:assets, :active]),

      # STAMP safety constraints
      gauge(@domain_prefix ++ [:stamp, :sc_obs_001_compliance]),
      counter(@domain_prefix ++ [:stamp, :violations])
    ]
  end

  # Step 2: Attach event handlers
  def attach_handlers do
    events = [
      [:indrajaal, :asset_management, :asset, :created],
      [:indrajaal, :asset_management, :asset, :updated],
      [:indrajaal, :asset_management, :asset, :deleted],
      [:indrajaal, :asset_management, :error]
    ]

    :telemetry.attach_many(
      "asset-management-instrumentation",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  # Step 3: Event handler implementation
  def handle_event(event, measurements, metadata, _config) do
    # Log to structured logger
    Logger.metadata(
      domain: :asset_management,
      tenant_id: metadata[:tenant_id],
      user_id: metadata[:user_id],
      trace_id: metadata[:trace_id]
    )

    # Emit OpenTelemetry span
    OpenTelemetry.Tracer.with_span event do
      OpenTelemetry.Span.set_attributes(%{
        "domain" => "asset_management",
        "operation" => event |> List.last() |> to_string(),
        "tenant_id" => metadata[:tenant_id]
      })
    end

    # Update metrics
    case event do
      [:indrajaal, :asset_management, :asset, :created] ->
        :telemetry.execute(
          @domain_prefix ++ [:asset, :created],
          %{count: 1},
          metadata
        )

      [:indrajaal, :asset_management, :asset, :updated] ->
        :telemetry.execute(
          @domain_prefix ++ [:asset, :updated],
          %{count: 1, duration: measurements[:duration]},
          metadata
        )

      # Handle other events...
    end
  end

  # Step 4: STAMP safety constraint tracking
  def track_stamp_constraint(constraint, value, metadata) do
    :telemetry.execute(
      @domain_prefix ++ [:stamp, constraint],
      %{value: value},
      metadata
    )
  end

  # Step 5: Performance baseline tracking
  def track_performance_baseline(operation, duration, metadata) do
    :telemetry.execute(
      @domain_prefix ++ [:performance, :baseline, operation],
      %{duration: duration},
      metadata
    )
  end
end
```

**Repeat for**:
1. Asset Management (5h)
2. Billing (5h)
3. Compliance (5h)
4. Core (5h)
5. Dispatch (5h)
6. Integrations (5h)
7. Policy (5h)
8. Risk Management (5h)
9. Sites (5h)
10. Video (5h)

#### Task 2.3: Register All Instrumentation Modules (3 hours)
**Steps**:
1. Update `/lib/indrajaal/observability/telemetry.ex`
2. Register all 19 domain instrumentation modules
3. Verify metrics appear in SigNoz
4. Test event emission

#### Task 2.4: Documentation & Review (3 hours)
**Steps**:
1. Document each domain's metrics
2. Create metric naming conventions guide
3. Peer review all instrumentation
4. Update observability documentation

### Phase 3: Health Check Framework (P1)

#### Task 3.1: Create Health Check Infrastructure (8 hours)

**File 1: `/lib/indrajaal/health/health_check_registry.ex`**
```elixir
defmodule Indrajaal.Health.HealthCheckRegistry do
  @moduledoc """
  Registry for all health checks in the system.
  Provides centralized health status aggregation.
  """

  use GenServer

  @health_checks [
    # Database checks
    {Indrajaal.Health.Checks.Database, :check, []},
    {Indrajaal.Health.Checks.DatabasePool, :check, []},

    # Cache checks
    {Indrajaal.Health.Checks.Redis, :check, []},

    # Observability checks
    {Indrajaal.Health.Checks.SigNoz, :check, []},
    {Indrajaal.Health.Checks.OpenTelemetry, :check, []},

    # External integration checks
    {Indrajaal.Health.Checks.SIADC09, :check, []},
    {Indrajaal.Health.Checks.WebRTC, :check, []},

    # Container checks
    {Indrajaal.Health.Checks.Container, :check, []}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_health_status do
    GenServer.call(__MODULE__, :get_health)
  end

  def get_detailed_health do
    GenServer.call(__MODULE__, :get_detailed_health)
  end

  @impl true
  def init(_opts) do
    # Schedule periodic health checks
    schedule_health_check()
    {:ok, %{last_check: nil, status: :unknown, components: %{}}}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    overall_status = if all_healthy?(state), do: :healthy, else: :unhealthy
    {:reply, overall_status, state}
  end

  @impl true
  def handle_call(:get_detailed_health, _from, state) do
    detailed = %{
      status: if(all_healthy?(state), do: :healthy, else: :unhealthy),
      timestamp: DateTime.utc_now(),
      components: state.components,
      duration_ms: state.check_duration
    }
    {:reply, detailed, state}
  end

  @impl true
  def handle_info(:perform_health_check, state) do
    start_time = System.monotonic_time(:millisecond)

    # Run all health checks in parallel
    results =
      @health_checks
      |> Task.async_stream(fn {module, function, args} ->
        try do
          {module, apply(module, function, args)}
        rescue
          error -> {module, {:error, error}}
        end
      end, timeout: 5000)
      |> Enum.map(fn {:ok, result} -> result end)
      |> Map.new()

    duration = System.monotonic_time(:millisecond) - start_time

    new_state = %{
      last_check: DateTime.utc_now(),
      status: if(all_healthy?(results), do: :healthy, else: :unhealthy),
      components: results,
      check_duration: duration
    }

    # Emit telemetry
    :telemetry.execute(
      [:indrajaal, :health, :check],
      %{duration: duration},
      %{status: new_state.status}
    )

    schedule_health_check()
    {:noreply, new_state}
  end

  defp all_healthy?(%{components: components}) when is_map(components) do
    Enum.all?(components, fn {_name, status} ->
      match?(:ok, status) or match?({:ok, _}, status)
    end)
  end

  defp schedule_health_check do
    Process.send_after(self(), :perform_health_check, 30_000) # 30 seconds
  end
end
```

**File 2: `/lib/indrajaal/health/checks/database.ex`**
```elixir
defmodule Indrajaal.Health.Checks.Database do
  @moduledoc """
  Health check for PostgreSQL database connectivity.
  """

  alias Indrajaal.Repo

  def check do
    case Repo.query("SELECT 1", [], timeout: 1000) do
      {:ok, _} -> {:ok, %{status: :healthy, latency_ms: 0}}
      {:error, error} -> {:error, %{status: :unhealthy, reason: inspect(error)}}
    end
  end
end
```

#### Task 3.2: Implement Component Health Checks (12 hours)
**Components to check**:
1. Database connectivity (1h)
2. Database connection pool (1h)
3. Redis connectivity (1h)
4. SigNoz OTLP endpoint (2h)
5. OpenTelemetry exporter (2h)
6. SIA DC-09 integration (2h)
7. WebRTC media server (2h)
8. Container infrastructure (1h)

#### Task 3.3: Create Health Check Endpoints (6 hours)

**File: `/lib/indrajaal_web/controllers/health_controller.ex`**
```elixir
defmodule IndrajaalWeb.HealthController do
  use IndrajaalWeb, :controller

  alias Indrajaal.Health.HealthCheckRegistry

  # GET /health
  def index(conn, _params) do
    case HealthCheckRegistry.get_health_status() do
      :healthy ->
        json(conn, %{status: "ok"})

      :unhealthy ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error"})
    end
  end

  # GET /health/detailed
  def detailed(conn, _params) do
    health = HealthCheckRegistry.get_detailed_health()

    status_code = if health.status == :healthy, do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(%{
      status: health.status,
      timestamp: health.timestamp,
      duration_ms: health.duration_ms,
      components: format_components(health.components)
    })
  end

  # GET /health/readiness
  def readiness(conn, _params) do
    # Kubernetes readiness probe
    # Only check critical components needed to serve traffic
    critical_checks = [:database, :redis]

    health = HealthCheckRegistry.get_detailed_health()

    ready? = Enum.all?(critical_checks, fn component ->
      case Map.get(health.components, component) do
        {:ok, _} -> true
        :ok -> true
        _ -> false
      end
    end)

    if ready? do
      json(conn, %{status: "ready"})
    else
      conn
      |> put_status(:service_unavailable)
      |> json(%{status: "not_ready"})
    end
  end

  # GET /health/liveness
  def liveness(conn, _params) do
    # Kubernetes liveness probe
    # Simple check that the application is running
    json(conn, %{status: "alive"})
  end

  defp format_components(components) do
    Enum.map(components, fn {name, result} ->
      case result do
        {:ok, details} -> {name, Map.put(details, :status, :healthy)}
        :ok -> {name, %{status: :healthy}}
        {:error, reason} -> {name, %{status: :unhealthy, reason: reason}}
      end
    end)
    |> Map.new()
  end
end
```

#### Task 3.4: Add Health Routes (1 hour)
```elixir
# In router.ex
scope "/health", IndrajaalWeb do
  pipe_through :api

  get "/", HealthController, :index
  get "/detailed", HealthController, :detailed
  get "/readiness", HealthController, :readiness
  get "/liveness", HealthController, :liveness
end
```

#### Task 3.5: Test Health Check System (2 hours)
**Steps**:
1. Test all health check endpoints
2. Verify <100ms response time
3. Test failure scenarios
4. Validate Kubernetes probe compatibility

#### Task 3.6: Documentation (1 hour)
**Steps**:
1. Update OPERATIONAL_RUNBOOKS.md
2. Document health check endpoints
3. Create health check troubleshooting guide

### Phase 4: Audit Logging System (P1)

#### Task 4.1: Design Audit Log Schema (4 hours)
**Schema Design**:
```elixir
defmodule Indrajaal.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "audit_logs" do
    field :event_type, :string          # "authentication", "authorization", "data_access", etc.
    field :event_action, :string        # "create", "update", "delete", "read"
    field :resource_type, :string       # "user", "alarm", "device", etc.
    field :resource_id, :binary_id      # ID of affected resource
    field :actor_id, :binary_id         # User who performed action
    field :tenant_id, :binary_id        # Multi-tenant isolation
    field :trace_id, :string            # OpenTelemetry trace correlation
    field :ip_address, :string          # Source IP
    field :user_agent, :string          # Client user agent
    field :outcome, :string             # "success", "failure", "partial"
    field :metadata, :map               # Additional context
    field :immutable_hash, :string      # Tamper detection

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  # Audit logs are immutable - no updates allowed
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [...])
    |> validate_required([...])
    |> put_immutable_hash()
  end

  defp put_immutable_hash(changeset) do
    # Create hash of all fields for tamper detection
    hash = :crypto.hash(:sha256, inspect(get_change(changeset, :metadata)))
            |> Base.encode16()
    put_change(changeset, :immutable_hash, hash)
  end
end
```

#### Task 4.2: Create Audit Logging Framework (12 hours)

**File: `/lib/indrajaal/audit/audit_logger.ex`**
```elixir
defmodule Indrajaal.Audit.AuditLogger do
  @moduledoc """
  Centralized audit logging for compliance and forensic analysis.
  All audit logs are immutable and retained for minimum 7 days (SC-OBS-003).
  """

  alias Indrajaal.Audit.AuditLog
  alias Indrajaal.Repo

  @doc """
  Log an audit event.
  Returns {:ok, audit_log} or {:error, changeset}.
  """
  def log_event(event_type, event_action, attrs) do
    %AuditLog{}
    |> AuditLog.changeset(
      attrs
      |> Map.put(:event_type, event_type)
      |> Map.put(:event_action, event_action)
      |> Map.put(:trace_id, current_trace_id())
    )
    |> Repo.insert()
    |> tap(&emit_telemetry/1)
  end

  @doc "Log authentication attempt"
  def log_authentication(actor_id, outcome, metadata \\ %{}) do
    log_event("authentication", "login", %{
      actor_id: actor_id,
      outcome: outcome,
      metadata: metadata,
      ip_address: metadata[:ip_address],
      user_agent: metadata[:user_agent]
    })
  end

  @doc "Log authorization decision"
  def log_authorization(actor_id, resource_type, resource_id, outcome, metadata \\ %{}) do
    log_event("authorization", "check", %{
      actor_id: actor_id,
      resource_type: resource_type,
      resource_id: resource_id,
      outcome: outcome,
      metadata: metadata
    })
  end

  @doc "Log data access"
  def log_data_access(actor_id, resource_type, resource_id, action, metadata \\ %{}) do
    log_event("data_access", action, %{
      actor_id: actor_id,
      resource_type: resource_type,
      resource_id: resource_id,
      outcome: "success",
      metadata: metadata
    })
  end

  @doc "Log administrative action"
  def log_admin_action(actor_id, action, resource_type, resource_id, metadata \\ %{}) do
    log_event("administrative", action, %{
      actor_id: actor_id,
      resource_type: resource_type,
      resource_id: resource_id,
      outcome: "success",
      metadata: metadata
    })
  end

  defp current_trace_id do
    OpenTelemetry.Tracer.current_span_ctx()
    |> case do
      :undefined -> nil
      ctx -> OpenTelemetry.Span.hex_trace_id(ctx)
    end
  end

  defp emit_telemetry({:ok, audit_log}) do
    :telemetry.execute(
      [:indrajaal, :audit, :logged],
      %{count: 1},
      %{event_type: audit_log.event_type, outcome: audit_log.outcome}
    )
  end
  defp emit_telemetry(_), do: :ok
end
```

#### Task 4.3: Integrate Audit Logging Across Domains (15 hours)
**For each domain** (19 domains × ~45 min each):
1. Identify audit-relevant operations
2. Add AuditLogger calls to critical paths
3. Test audit log creation
4. Verify immutability

**Example for Accounts Domain**:
```elixir
defmodule Indrajaal.Accounts.User do
  # ...

  def create(attrs, actor_id) do
    with {:ok, user} <- %User{} |> changeset(attrs) |> Repo.insert() do
      # Audit log the user creation
      Indrajaal.Audit.AuditLogger.log_admin_action(
        actor_id,
        "create",
        "user",
        user.id,
        %{username: user.username, email: user.email}
      )

      {:ok, user}
    end
  end
end
```

#### Task 4.4: Create Audit Log Retention Policy (2 hours)
**Steps**:
1. Create migration for TTL (7 days minimum)
2. Schedule periodic cleanup job
3. Verify SC-OBS-003 compliance
4. Test retention enforcement

#### Task 4.5: Documentation & Testing (2 hours)

### Phase 5: SigNoz Integration Enhancement (P2)

#### Task 5.1: Verify SigNoz Configuration (3 hours)
**Steps**:
1. Verify OTEL_EXPORTER_OTLP_ENDPOINT
2. Check trace sampling configuration
3. Validate service name and tags
4. Test trace arrival in SigNoz

#### Task 5.2: Create Domain Dashboards (15 hours)
**For each domain** (~45 min each):
1. Create dashboard in SigNoz UI
2. Add key metrics widgets
3. Add error rate charts
4. Add performance percentiles (p50, p95, p99)
5. Export dashboard JSON

**Example Dashboard Structure**:
```json
{
  "title": "Access Control Domain",
  "panels": [
    {
      "title": "Authentication Attempts",
      "query": "sum(rate(indrajaal_access_control_auth_attempts[5m])) by (outcome)"
    },
    {
      "title": "Authorization Checks",
      "query": "histogram_quantile(0.95, indrajaal_access_control_authz_duration)"
    },
    {
      "title": "Error Rate",
      "query": "sum(rate(indrajaal_access_control_errors[5m]))"
    }
  ]
}
```

#### Task 5.3: Configure Alerting Rules (5 hours)
**Alert Categories**:
1. High error rate (>5% errors in 5 min)
2. Performance degradation (p95 > 1s)
3. Authorization failures (>10 failures/min)
4. Compliance violations (any SC-OBS violation)
5. Integration failures (external system down)

**Example Alert Rule**:
```yaml
alert: HighErrorRate
expr: rate(indrajaal_errors_total[5m]) > 0.05
for: 2m
labels:
  severity: critical
annotations:
  summary: "High error rate detected"
  description: "{{ $labels.domain }} domain has >5% error rate"
```

#### Task 5.4: Documentation (2 hours)

### Phase 6: Test Suite for Observability (P2)

#### Task 6.1: Create TDG Test Structure (5 hours)
**Test Files to Create**:
1. `test/indrajaal/observability/telemetry_coverage_test.exs`
2. `test/indrajaal/observability/domain_instrumentation_test.exs`
3. `test/indrajaal/audit/audit_log_test.exs`
4. `test/indrajaal/health/health_check_test.exs`
5. `test/indrajaal_web/controllers/health_controller_test.exs`

#### Task 6.2: Write Unit Tests for Instrumentation (20 hours)
**For each domain** (19 × 1 hour):
```elixir
defmodule Indrajaal.Observability.Domains.AssetManagementInstrumentationTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.Domains.AssetManagementInstrumentation

  setup do
    # Attach test telemetry handler
    :telemetry.attach(
      "test-handler",
      [:indrajaal, :asset_management, :asset, :created],
      &capture_event/4,
      self()
    )

    on_exit(fn -> :telemetry.detach("test-handler") end)

    :ok
  end

  test "emits telemetry event when asset is created" do
    # Emit event
    :telemetry.execute(
      [:indrajaal, :asset_management, :asset, :created],
      %{count: 1},
      %{tenant_id: "test-tenant", asset_id: "test-asset"}
    )

    # Verify event was captured
    assert_receive {:telemetry_event, event, measurements, metadata}
    assert event == [:indrajaal, :asset_management, :asset, :created]
    assert measurements.count == 1
    assert metadata.tenant_id == "test-tenant"
  end

  defp capture_event(event, measurements, metadata, pid) do
    send(pid, {:telemetry_event, event, measurements, metadata})
  end
end
```

#### Task 6.3: Write Integration Tests (10 hours)
**Test scenarios**:
1. End-to-end telemetry pipeline (event → SigNoz)
2. Audit log creation and retrieval
3. Health check endpoint responses
4. Trace context propagation

#### Task 6.4: Write Property-Based Tests (5 hours)
```elixir
defmodule Indrajaal.Observability.MetricPropertiesTest do
  use ExUnit.Case
  use ExUnitProperties

  property "metric values are always non-negative" do
    check all operation <- member_of([:created, :updated, :deleted]),
              count <- positive_integer(),
              duration <- positive_integer() do

      :telemetry.execute(
        [:indrajaal, :test, :operation, operation],
        %{count: count, duration: duration},
        %{}
      )

      # Verify metrics are non-negative
      assert count >= 0
      assert duration >= 0
    end
  end
end
```

#### Task 6.5: Documentation & Review (5 hours)

### Phase 7: SOPv5.11 Compliance Validation (P3)

#### Task 7.1: STAMP Safety Constraint Validation (8 hours)

**SC-OBS-001: 100% Observability for Critical Operations**
- Verify all critical operations emit telemetry
- Create coverage report
- Validate logging completeness

**SC-OBS-002: Anomaly Detection Within 1 Minute**
- Test health check frequency (30s interval)
- Verify alert notification latency
- Validate threshold tuning

**SC-OBS-003: 7-Day Data Retention**
- Verify TTL configuration
- Test retention enforcement
- Validate backup procedures

**SC-OBS-004: Complete Audit Trail**
- Verify audit log coverage
- Test immutability
- Validate forensic capabilities

#### Task 7.2: TDG Methodology Validation (3 hours)
- Verify all tests written before implementation
- Check test coverage >95%
- Validate property-based tests

#### Task 7.3: GDE Goal Tracking (2 hours)
- Verify goal achievement monitoring
- Test feedback loops
- Validate adaptive optimization

#### Task 7.4: Create Compliance Report (2 hours)
**Report Structure**:
```markdown
# SOPv5.11 Observability Compliance Report

## STAMP Safety Constraints
- SC-OBS-001: ✅ COMPLIANT (100% coverage)
- SC-OBS-002: ✅ COMPLIANT (<1 min detection)
- SC-OBS-003: ✅ COMPLIANT (7-day retention)
- SC-OBS-004: ✅ COMPLIANT (complete audit trail)

## TDG Methodology
- Test coverage: 97% (target: >95%)
- Tests written first: 100%
- Property tests: Complete

## GDE Integration
- Goal tracking: Operational
- Feedback loops: <1 min latency
- Adaptive optimization: Enabled

## Conclusion
All SOPv5.11 requirements met for observability system.
```

---

## Level 4: Implementation Details (Code-Level Guidance)

### Logging Implementation Patterns

#### Pattern 1: Structured Logging with Context
```elixir
# ❌ BAD - Unstructured logging
Logger.info("User logged in")

# ✅ GOOD - Structured logging with context
Logger.info("User authentication successful",
  user_id: user.id,
  tenant_id: user.tenant_id,
  auth_method: "password",
  trace_id: OpenTelemetry.Tracer.current_span_ctx() |> trace_id(),
  ip_address: conn.remote_ip,
  timestamp: DateTime.utc_now()
)
```

#### Pattern 2: Error Logging with Stack Traces
```elixir
# ✅ GOOD - Include full error context
try do
  perform_operation()
rescue
  error ->
    Logger.error("Operation failed",
      error: inspect(error),
      stacktrace: Exception.format_stacktrace(__STACKTRACE__),
      operation: "perform_operation",
      user_id: user_id,
      trace_id: current_trace_id()
    )
    {:error, error}
end
```

#### Pattern 3: Performance Logging
```elixir
# ✅ GOOD - Log operation duration
def create_alarm(attrs, user_id) do
  start_time = System.monotonic_time(:millisecond)

  result =
    %Alarm{}
    |> changeset(attrs)
    |> Repo.insert()

  duration = System.monotonic_time(:millisecond) - start_time

  Logger.info("Alarm created",
    user_id: user_id,
    duration_ms: duration,
    alarm_id: result.id,
    trace_id: current_trace_id()
  )

  result
end
```

### Telemetry Event Emission Patterns

#### Pattern 1: Domain Event Emission
```elixir
defmodule Indrajaal.Alarms.Alarm do
  def create(attrs, user_id) do
    with {:ok, alarm} <- %Alarm{} |> changeset(attrs) |> Repo.insert() do
      # Emit telemetry event
      :telemetry.execute(
        [:indrajaal, :alarms, :alarm, :created],
        %{count: 1, processing_time: 0},
        %{
          tenant_id: alarm.tenant_id,
          user_id: user_id,
          alarm_type: alarm.type,
          severity: alarm.severity
        }
      )

      {:ok, alarm}
    end
  end
end
```

#### Pattern 2: Operation Duration Tracking
```elixir
defmodule Indrajaal.Analytics.Report do
  def generate(params) do
    start_time = System.monotonic_time(:millisecond)

    result = perform_analysis(params)

    duration = System.monotonic_time(:millisecond) - start_time

    :telemetry.execute(
      [:indrajaal, :analytics, :report, :generated],
      %{duration: duration, data_points: result.count},
      %{report_type: params.type, tenant_id: params.tenant_id}
    )

    result
  end
end
```

#### Pattern 3: Error Event Emission
```elixir
defmodule Indrajaal.Integration.SIADC09 do
  def send_alarm(alarm) do
    case HTTPClient.post("/alarms", alarm) do
      {:ok, response} ->
        :telemetry.execute(
          [:indrajaal, :integration, :sia_dc09, :success],
          %{count: 1},
          %{alarm_id: alarm.id}
        )
        {:ok, response}

      {:error, reason} ->
        :telemetry.execute(
          [:indrajaal, :integration, :sia_dc09, :error],
          %{count: 1},
          %{alarm_id: alarm.id, error: inspect(reason)}
        )
        {:error, reason}
    end
  end
end
```

### Health Check Implementation Patterns

#### Pattern 1: Database Health Check
```elixir
defmodule Indrajaal.Health.Checks.Database do
  def check do
    start_time = System.monotonic_time(:millisecond)

    case Repo.query("SELECT 1", [], timeout: 1000) do
      {:ok, _} ->
        latency = System.monotonic_time(:millisecond) - start_time
        {:ok, %{status: :healthy, latency_ms: latency}}

      {:error, %DBConnection.ConnectionError{} = error} ->
        {:error, %{
          status: :unhealthy,
          reason: "Database connection failed",
          details: inspect(error)
        }}
    end
  end
end
```

#### Pattern 2: External Integration Health Check
```elixir
defmodule Indrajaal.Health.Checks.SigNoz do
  def check do
    otlp_endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT")

    case HTTPClient.get("#{otlp_endpoint}/health", [], timeout: 2000) do
      {:ok, %{status: 200}} ->
        {:ok, %{status: :healthy, endpoint: otlp_endpoint}}

      {:ok, %{status: status}} ->
        {:error, %{
          status: :unhealthy,
          reason: "SigNoz returned #{status}",
          endpoint: otlp_endpoint
        }}

      {:error, reason} ->
        {:error, %{
          status: :unhealthy,
          reason: "Cannot reach SigNoz",
          details: inspect(reason)
        }}
    end
  end
end
```

### Audit Logging Implementation Patterns

#### Pattern 1: Authentication Audit
```elixir
defmodule Indrajaal.Accounts.Sessions do
  alias Indrajaal.Audit.AuditLogger

  def create_session(credentials, metadata) do
    case authenticate(credentials) do
      {:ok, user} ->
        AuditLogger.log_authentication(
          user.id,
          "success",
          %{
            method: "password",
            ip_address: metadata.ip_address,
            user_agent: metadata.user_agent,
            session_id: generate_session_id()
          }
        )

        {:ok, user}

      {:error, :invalid_credentials} ->
        AuditLogger.log_authentication(
          nil,
          "failure",
          %{
            reason: "invalid_credentials",
            username: credentials.username,
            ip_address: metadata.ip_address
          }
        )

        {:error, :invalid_credentials}
    end
  end
end
```

#### Pattern 2: Data Modification Audit
```elixir
defmodule Indrajaal.Devices.Device do
  alias Indrajaal.Audit.AuditLogger

  def update(device, attrs, actor_id) do
    old_values = Map.take(device, [:name, :status, :configuration])

    with {:ok, updated_device} <- device |> changeset(attrs) |> Repo.update() do
      new_values = Map.take(updated_device, [:name, :status, :configuration])

      AuditLogger.log_data_access(
        actor_id,
        "device",
        device.id,
        "update",
        %{
          changes: diff(old_values, new_values),
          tenant_id: device.tenant_id
        }
      )

      {:ok, updated_device}
    end
  end

  defp diff(old, new) do
    Enum.reduce(new, %{}, fn {key, new_value}, acc ->
      old_value = Map.get(old, key)
      if old_value != new_value do
        Map.put(acc, key, %{from: old_value, to: new_value})
      else
        acc
      end
    end)
  end
end
```

### Testing Patterns

#### Pattern 1: Telemetry Event Testing
```elixir
defmodule Indrajaal.Alarms.AlarmTest do
  use Indrajaal.DataCase

  import Indrajaal.TestHelpers.TelemetryHelper

  test "emits telemetry event on alarm creation" do
    # Capture telemetry events
    events = capture_telemetry_events([:indrajaal, :alarms, :alarm, :created], fn ->
      Alarm.create(%{type: "intrusion", severity: "high"}, user_id: "test-user")
    end)

    assert length(events) == 1
    assert hd(events).measurements.count == 1
    assert hd(events).metadata.alarm_type == "intrusion"
  end
end
```

#### Pattern 2: Health Check Testing
```elixir
defmodule Indrajaal.Health.HealthCheckRegistryTest do
  use ExUnit.Case

  test "returns healthy status when all checks pass" do
    # Mock all health checks to return :ok
    Mox.stub(DatabaseMock, :check, fn -> {:ok, %{status: :healthy}} end)
    Mox.stub(RedisMock, :check, fn -> {:ok, %{status: :healthy}} end)

    assert :healthy == HealthCheckRegistry.get_health_status()
  end

  test "returns unhealthy when any check fails" do
    Mox.stub(DatabaseMock, :check, fn -> {:ok, %{status: :healthy}} end)
    Mox.stub(RedisMock, :check, fn -> {:error, %{status: :unhealthy}} end)

    assert :unhealthy == HealthCheckRegistry.get_health_status()
  end
end
```

#### Pattern 3: Audit Log Testing
```elixir
defmodule Indrajaal.Audit.AuditLoggerTest do
  use Indrajaal.DataCase

  test "creates immutable audit log entry" do
    {:ok, audit_log} = AuditLogger.log_authentication(
      "user-123",
      "success",
      %{method: "password"}
    )

    # Verify audit log was created
    assert audit_log.event_type == "authentication"
    assert audit_log.outcome == "success"
    assert audit_log.actor_id == "user-123"

    # Verify immutability hash
    assert byte_size(audit_log.immutable_hash) == 64 # SHA256 hex

    # Verify cannot update
    assert_raise Ecto.NoPrimaryKeyValueError, fn ->
      audit_log |> Ecto.Changeset.change(%{outcome: "failure"}) |> Repo.update()
    end
  end

  test "includes trace context in audit log" do
    OpenTelemetry.Tracer.with_span "test-span" do
      {:ok, audit_log} = AuditLogger.log_data_access(
        "user-123",
        "device",
        "device-456",
        "read"
      )

      assert audit_log.trace_id != nil
      assert String.length(audit_log.trace_id) == 32 # Trace ID is 32 hex chars
    end
  end
end
```

---

## Level 5: Execution Checklist (Daily Task Breakdown)

### Week 1: Critical Logging Infrastructure (P0)

#### Day 1: Logging Standards & Audit (8 hours)
- [ ] 09:00-10:00: Scan codebase for existing Logger calls
- [ ] 10:00-11:00: Create logging coverage matrix
- [ ] 11:00-12:00: Define logging standards document
- [ ] 12:00-13:00: Lunch break
- [ ] 13:00-15:00: Create logging helper modules
- [ ] 15:00-16:00: Document logging best practices
- [ ] 16:00-17:00: Peer review logging standards
- [ ] 17:00-17:30: Daily standup and planning

**Deliverables**:
- `/docs/planning/logging_coverage_matrix.md`
- `/lib/indrajaal/logging/logging_helpers.ex`
- `/docs/guides/logging_standards.md`

#### Day 2: Domain Logging - Access Control, Accounts, Alarms (8 hours)
- [ ] 09:00-11:00: Access Control domain logging (2h)
  - Identify 15-20 critical operations
  - Add Logger calls with metadata
  - Test log output in SigNoz
- [ ] 11:00-13:00: Accounts domain logging (2h)
  - Authentication/authorization logging
  - User CRUD operation logging
  - Session management logging
- [ ] 13:00-14:00: Lunch break
- [ ] 14:00-16:00: Alarms domain logging (2h)
  - Alarm lifecycle logging
  - Alarm processing logging
  - Integration event logging
- [ ] 16:00-17:00: Test and verify all logging
- [ ] 17:00-17:30: Daily standup

#### Day 3: Domain Logging - Analytics, Asset Management, Billing (8 hours)
- [ ] 09:00-10:30: Analytics domain logging (1.5h)
- [ ] 10:30-12:00: Asset Management domain logging (1.5h)
- [ ] 12:00-13:00: Lunch break
- [ ] 13:00-14:30: Billing domain logging (1.5h)
- [ ] 14:30-16:30: Test logging integration for all 3 domains
- [ ] 16:30-17:30: Update logging documentation
- [ ] Daily standup

#### Day 4: Domain Logging - Communication, Compliance, Core, Devices (8 hours)
- [ ] 09:00-10:30: Communication domain logging (1.5h)
- [ ] 10:30-12:00: Compliance domain logging (1.5h)
- [ ] 12:00-13:00: Lunch break
- [ ] 13:00-14:30: Core domain logging (1.5h)
- [ ] 14:30-16:00: Devices domain logging (1.5h)
- [ ] 16:00-17:30: Test and verify
- [ ] Daily standup

#### Day 5: Domain Logging - Remaining Domains (8 hours)
- [ ] 09:00-10:30: Dispatch & Guard Tour logging (1.5h each)
- [ ] 10:30-12:00: Integrations & Maintenance logging (1.5h each)
- [ ] 12:00-13:00: Lunch break
- [ ] 13:00-14:30: Policy & Risk Management logging (1.5h each)
- [ ] 14:30-16:00: Sites & Video logging (1.5h each)
- [ ] 16:00-17:00: Visitor Management logging (1h)
- [ ] 17:00-17:30: Week 1 review and planning
- [ ] Weekly retrospective

**Week 1 Completion Criteria**:
- [ ] All 19 domains have comprehensive Logger calls
- [ ] All logs include trace_id, tenant_id, user_id metadata
- [ ] All logs visible in SigNoz
- [ ] Logging documentation complete

### Week 2: Domain Instrumentation Part 1 (P0)

#### Day 6: Instrumentation Template & Setup (8 hours)
- [ ] 09:00-11:00: Analyze existing instrumentation modules
- [ ] 11:00-13:00: Create reusable template with STAMP tracking
- [ ] 13:00-14:00: Lunch break
- [ ] 14:00-16:00: Document instrumentation patterns
- [ ] 16:00-17:30: Set up testing infrastructure
- [ ] Daily standup

**Deliverables**:
- `/lib/indrajaal/observability/domains/_template_instrumentation.ex`
- `/docs/guides/instrumentation_patterns.md`

#### Day 7-8: Implement Asset Management, Billing, Compliance Instrumentation (16 hours)
**Day 7**:
- [ ] 09:00-14:00: Asset Management instrumentation (5h)
  - Define metrics
  - Attach event handlers
  - Implement STAMP constraint tracking
  - Write tests
- [ ] 14:00-15:00: Lunch break
- [ ] 15:00-17:30: Billing instrumentation (2.5h)
  - Start implementation

**Day 8**:
- [ ] 09:00-11:30: Billing instrumentation completion (2.5h)
  - Complete implementation and tests
- [ ] 11:30-13:00: Lunch break
- [ ] 13:00-18:00: Compliance instrumentation (5h)
  - Full implementation with tests

#### Day 9-10: Implement Core, Dispatch, Integrations Instrumentation (16 hours)
**Day 9**:
- [ ] 09:00-14:00: Core domain instrumentation (5h)
- [ ] 14:00-15:00: Lunch
- [ ] 15:00-17:30: Dispatch instrumentation (2.5h)

**Day 10**:
- [ ] 09:00-11:30: Dispatch instrumentation completion (2.5h)
- [ ] 11:30-13:00: Lunch
- [ ] 13:00-18:00: Integrations instrumentation (5h)
- [ ] Week 2 review

### Week 3: Domain Instrumentation Part 2 + Health Checks (P0/P1)

#### Day 11-12: Implement Policy, Risk Management, Sites, Video Instrumentation (16 hours)
**Day 11**:
- [ ] 09:00-14:00: Policy instrumentation (5h)
- [ ] 14:00-15:00: Lunch
- [ ] 15:00-17:30: Risk Management instrumentation (2.5h)

**Day 12**:
- [ ] 09:00-11:30: Risk Management completion (2.5h)
- [ ] 11:30-13:00: Lunch
- [ ] 13:00-18:00: Sites instrumentation (5h)

#### Day 13: Complete Video Instrumentation + Register All Modules (8 hours)
- [ ] 09:00-14:00: Video instrumentation (5h)
- [ ] 14:00-15:00: Lunch
- [ ] 15:00-17:00: Register all 19 modules in telemetry.ex
- [ ] 17:00-17:30: Verify all metrics in SigNoz

#### Day 14-15: Health Check Framework (16 hours)
**Day 14**:
- [ ] 09:00-12:00: Create health check infrastructure (3h)
  - HealthCheckRegistry GenServer
  - HealthMetrics module
  - ComponentHealth behavior
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Implement component checks (4h)
  - Database check
  - Redis check
  - SigNoz check
  - Start external integration checks

**Day 15**:
- [ ] 09:00-12:00: Complete component checks (3h)
  - Finish external integrations
  - Container health check
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-16:00: Create health endpoints (3h)
  - HealthController
  - Routes
  - Response formatting
- [ ] 16:00-17:30: Test health check system
- [ ] Week 3 retrospective

### Week 4: Audit Logging + SigNoz Enhancement (P1/P2)

#### Day 16-17: Audit Logging System (16 hours)
**Day 16**:
- [ ] 09:00-12:00: Design audit log schema (3h)
  - Create migration
  - Define AuditLog schema
  - Test immutability
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Create audit logging framework (4h)
  - AuditLogger module
  - Helper functions
  - Telemetry integration

**Day 17**:
- [ ] 09:00-12:00: Integrate audit logging - Domains 1-6 (3h)
  - Access Control, Accounts, Alarms
  - Analytics, Asset Management, Billing
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Integrate audit logging - Domains 7-12 (4h)
  - Communication, Compliance, Core
  - Devices, Dispatch, Guard Tour

#### Day 18: Complete Audit Integration + Retention (8 hours)
- [ ] 09:00-12:00: Integrate audit logging - Domains 13-19 (3h)
  - Integrations, Maintenance, Policy
  - Risk Management, Sites, Video, Visitor Management
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-15:00: Create retention policy (2h)
  - TTL migration
  - Cleanup job
  - SC-OBS-003 validation
- [ ] 15:00-17:00: Test audit logging system
- [ ] Documentation update

#### Day 19-20: SigNoz Dashboards & Alerting (16 hours)
**Day 19**:
- [ ] 09:00-10:00: Verify SigNoz configuration
- [ ] 10:00-12:00: Create dashboards 1-5 (2h)
  - Access Control, Accounts, Alarms
  - Analytics, Asset Management
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Create dashboards 6-10 (4h)
  - Billing, Communication, Compliance
  - Core, Devices

**Day 20**:
- [ ] 09:00-12:00: Create dashboards 11-19 (3h)
  - Remaining 9 domains
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-16:00: Configure alerting rules (3h)
  - Error rate alerts
  - Performance alerts
  - Compliance alerts
- [ ] 16:00-17:30: Test alerts and dashboards
- [ ] Week 4 retrospective

### Week 5: Test Suite + Compliance Validation (P2/P3)

#### Day 21-23: Observability Test Suite (24 hours)
**Day 21**:
- [ ] 09:00-12:00: Create TDG test structure (3h)
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Unit tests for instrumentation 1-5 (4h)

**Day 22**:
- [ ] 09:00-12:00: Unit tests for instrumentation 6-10 (3h)
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Unit tests for instrumentation 11-15 (4h)

**Day 23**:
- [ ] 09:00-12:00: Unit tests for instrumentation 16-19 (3h)
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Health check and audit log tests (4h)

#### Day 24: Integration & Property Tests (8 hours)
- [ ] 09:00-12:00: Integration tests (3h)
  - End-to-end telemetry pipeline
  - Audit log creation/retrieval
  - Health check responses
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-17:00: Property-based tests (4h)
  - Metric accuracy
  - Event emission
  - Audit log immutability

#### Day 25: SOPv5.11 Compliance Validation (8 hours)
- [ ] 09:00-12:00: STAMP safety constraint validation (3h)
  - SC-OBS-001: Observability coverage
  - SC-OBS-002: Anomaly detection
  - SC-OBS-003: Data retention
  - SC-OBS-004: Audit trail
- [ ] 12:00-13:00: Lunch
- [ ] 13:00-15:00: TDG methodology validation (2h)
- [ ] 15:00-16:00: GDE goal tracking (1h)
- [ ] 16:00-17:30: Create compliance report
- [ ] Final project retrospective

---

## Success Criteria & Validation

### Phase Completion Checklist

**Phase 1: Critical Logging Infrastructure** ✅
- [ ] All 19 domains have Logger calls in critical operations
- [ ] All logs include trace_id, tenant_id, user_id metadata
- [ ] Logs visible in SigNoz with proper formatting
- [ ] Logging standards documentation complete
- [ ] <50ms logging overhead verified

**Phase 2: Complete Domain Instrumentation** ✅
- [ ] 10 new instrumentation modules created
- [ ] 100% domain coverage (19/19 domains)
- [ ] All domain metrics registered in telemetry.ex
- [ ] All metrics visible in SigNoz
- [ ] STAMP constraint tracking operational

**Phase 3: Health Check Framework** ✅
- [ ] HealthCheckRegistry GenServer operational
- [ ] All 8 component health checks implemented
- [ ] 4 health endpoints responding correctly
- [ ] <100ms health check response time verified
- [ ] Kubernetes probe compatibility validated

**Phase 4: Audit Logging System** ✅
- [ ] AuditLog schema and migration created
- [ ] AuditLogger framework operational
- [ ] All 19 domains integrated with audit logging
- [ ] 7-day retention policy enforced
- [ ] Immutability and tamper-proofing verified
- [ ] SC-OBS-004 compliance validated

**Phase 5: SigNoz Integration Enhancement** ✅
- [ ] SigNoz configuration verified
- [ ] 19 domain dashboards created
- [ ] Alerting rules configured for all critical metrics
- [ ] <1 minute alert notification latency
- [ ] Service maps and SLO tracking operational

**Phase 6: Test Suite for Observability** ✅
- [ ] Test coverage >95% for observability code
- [ ] All instrumentation modules have unit tests
- [ ] Integration tests for telemetry pipeline
- [ ] Property-based tests for metric accuracy
- [ ] Health check endpoint tests passing
- [ ] Audit log tests passing

**Phase 7: SOPv5.11 Compliance Validation** ✅
- [ ] SC-OBS-001: 100% critical operation observability
- [ ] SC-OBS-002: <1 minute anomaly detection
- [ ] SC-OBS-003: 7-day data retention verified
- [ ] SC-OBS-004: Complete audit trail validated
- [ ] TDG methodology: All tests written first
- [ ] GDE integration: Goal tracking operational
- [ ] Compliance report generated and approved

---

## Risk Management

### High-Risk Areas

**Risk 1: Performance Impact of Logging**
- **Mitigation**: Async logging, sampling for high-volume operations
- **Monitoring**: Track logging overhead with telemetry
- **Threshold**: <50ms p99 latency for all logging operations

**Risk 2: SigNoz Integration Failures**
- **Mitigation**: OTLP exporter retry logic, local buffering
- **Monitoring**: Health check for SigNoz connectivity
- **Fallback**: Graceful degradation with console logging

**Risk 3: Audit Log Storage Growth**
- **Mitigation**: 7-day TTL, compression, partitioning
- **Monitoring**: Database size and growth rate
- **Alert**: >80% disk usage triggers cleanup

**Risk 4: Test Coverage Gaps**
- **Mitigation**: TDG methodology, property-based testing
- **Monitoring**: Coverage reports in CI/CD
- **Quality Gate**: >95% coverage required for merge

### Contingency Plans

**If Phase 1 exceeds timeline**:
- Prioritize critical domains (Alarms, Access Control, Accounts)
- Defer logging for low-traffic domains
- Parallelize work across multiple developers

**If SigNoz is unavailable**:
- Fall back to console logging
- Buffer telemetry events locally
- Resume export when connectivity restored

**If audit log performance degrades**:
- Implement write-behind caching
- Batch audit log writes
- Consider separate audit database

---

## Appendix A: Reference Commands

### Daily Development Commands
```bash
# Start observability stack
cd /home/an/dev/indrajaal-demo/containers/signoz
./start-signoz-simple.sh

# Check health
curl http://localhost:4000/health/detailed | jq

# View telemetry events
iex -S mix
:telemetry.list_handlers()

# Run observability tests
mix test test/indrajaal/observability/
mix test test/indrajaal/audit/
mix test test/indrajaal/health/

# View SigNoz dashboards
open http://localhost:3301

# Query audit logs
iex> Indrajaal.Repo.all(Indrajaal.Audit.AuditLog) |> Enum.take(10)

# Check STAMP compliance
mix test test/stamp/observability_safety_constraints_test.exs
```

### Verification Commands
```bash
# Verify all domains have instrumentation
ls lib/indrajaal/observability/domains/*.ex | wc -l
# Should return: 19

# Count Logger calls
grep -r "Logger\." lib/indrajaal/ | wc -l
# Should return: >200

# Check health check response time
time curl http://localhost:4000/health
# Should be: <100ms

# Verify audit logs
psql -d indrajaal_dev -c "SELECT COUNT(*) FROM audit_logs;"

# Check SigNoz connectivity
curl http://localhost:4318/v1/traces
# Should return: 405 Method Not Allowed (endpoint exists)
```

---

## Appendix B: Glossary

**Telemetry**: Automated collection and transmission of measurements and metrics
**OpenTelemetry (OTEL)**: Observability framework for distributed tracing
**SigNoz**: Open-source observability platform (APM)
**OTLP**: OpenTelemetry Protocol for telemetry data
**STAMP**: System-Theoretic Accident Model and Processes (safety framework)
**TDG**: Test-Driven Generation (tests written before code)
**GDE**: Goal-Directed Execution (SOPv5.11 cybernetic framework)
**SC-OBS-XXX**: STAMP Safety Constraints for Observability
**Audit Trail**: Immutable log of security-relevant events
**Health Check**: Endpoint that reports system/component health status
**Instrumentation**: Code that emits telemetry events and metrics
**Trace Context**: Correlation ID for distributed tracing

---

**END OF 5-LEVEL PLAN**

Total Pages: 50+
Total Tasks: 100+
Total Effort: 250 hours
Completion Timeline: 5 weeks
