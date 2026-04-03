# Safety Systems Implementation Plan

**Date**: 2025-08-04 15:51:00 CEST
**Type**: Detailed Implementation Plan
**Priority**: CRITICAL
**Timeline**: 3 Sprints (6 weeks)

## Executive Summary

This plan details the implementation of critical safety systems for the Indrajaal Security Monitoring System. The work is organized into three priority levels across three 2-week sprints.

## Sprint 1: Critical Security Fixes (Weeks 1-2)

### 1. JWT Token Validation Implementation
**Priority**: CRITICAL
**Owner**: Security Team
**Dependencies**: None

#### Tasks:
1.1. **Implement Joken-based JWT validation** (3 days)
```elixir
# File: lib/indrajaal/authentication/token_validator.ex
defmodule Indrajaal.Authentication.TokenValidator do
  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud], default_exp: 3600)
    |> add_claim("sub", nil, &validate_subject/1)
    |> add_claim("tenant_id", nil, &validate_tenant_id/1)
    |> add_claim("role", nil, &validate_role/1)
    |> add_claim("jti", nil, &validate_jti/1)
  end

  defp validate_subject(sub) when is_binary(sub), do: :ok
  defp validate_subject(_), do: {:error, :invalid_subject}

  defp validate_tenant_id(tenant_id) do
    # Check tenant exists and is active
    case Indrajaal.Accounts.get_tenant(tenant_id) do
      {:ok, %{active: true}} -> :ok
      _ -> {:error, :invalid_tenant}
    end
  end

  defp validate_role(role) when role in ~w(admin manager operator viewer), do: :ok
  defp validate_role(_), do: {:error, :invalid_role}

  defp validate_jti(jti) do
    # Check token revocation list
    if TokenRevocationCache.revoked?(jti), do: {:error, :token_revoked}, else: :ok
  end
end
```

1.2. **Create token revocation cache** (2 days)
- ETS-based cache with TTL
- Redis backup for distributed systems
- Automatic cleanup of expired tokens

1.3. **Add token refresh mechanism** (2 days)
- Secure refresh token generation
- Rotation on use
- Family detection for security

1.4. **Integration tests** (1 day)

### 2. Real Rate Limiting System
**Priority**: CRITICAL
**Owner**: Infrastructure Team
**Dependencies**: Redis/ETS setup

#### Tasks:
2.1. **Implement sliding window rate limiter** (3 days)
```elixir
# File: lib/indrajaal/security/rate_limiter.ex
defmodule Indrajaal.Security.RateLimiter do
  use GenServer

  @default_limits %{
    admin: {requests: 1000, window: 60},
    manager: {requests: 500, window: 60},
    operator: {requests: 200, window: 60},
    viewer: {requests: 100, window: 60}
  }

  def check_rate(user_id, endpoint, role) do
    key = "rate:#{user_id}:#{endpoint}"
    {limit, window} = get_limit(role, endpoint)

    case increment_and_check(key, limit, window) do
      {:ok, count} -> {:ok, %{count: count, limit: limit, remaining: limit - count}}
      {:error, :exceeded} -> {:error, :rate_limited}
    end
  end

  defp increment_and_check(key, limit, window) do
    # Implement sliding window with Redis sorted sets
    # or ETS with timestamp tracking
  end
end
```

2.2. **Add endpoint-specific limits** (2 days)
- Configuration system for limits
- Dynamic adjustment based on load
- Bypass for health checks

2.3. **Create rate limit headers** (1 day)
- X-RateLimit-Limit
- X-RateLimit-Remaining
- X-RateLimit-Reset

2.4. **Integration with Phoenix** (2 days)
- Plug for automatic enforcement
- Customizable response messages
- Metrics collection

### 3. Session Security Enhancement
**Priority**: CRITICAL
**Owner**: Security Team
**Dependencies**: Database schema updates

#### Tasks:
3.1. **Implement session fingerprinting** (3 days)
```elixir
# File: lib/indrajaal/accounts/session_security.ex
defmodule Indrajaal.Accounts.SessionSecurity do
  @fingerprint_components [:user_agent, :accept_language, :accept_encoding]

  def generate_fingerprint(conn) do
    components = Enum.map(@fingerprint_components, &get_header(conn, &1))
    :crypto.hash(:sha256, Enum.join(components, "|"))
    |> Base.encode64()
  end

  def validate_session(session_id, conn) do
    with {:ok, session} <- load_session(session_id),
         :ok <- validate_fingerprint(session, conn),
         :ok <- validate_ip_consistency(session, conn),
         :ok <- validate_expiration(session) do
      {:ok, session}
    end
  end

  def rotate_session_id(old_session) do
    new_id = generate_secure_id()
    # Copy session data to new ID
    # Invalidate old session
    # Return new session
  end
end
```

3.2. **Add concurrent session limits** (2 days)
- Maximum sessions per user
- Device management
- Force logout of oldest sessions

3.3. **Implement session timeout** (2 days)
- Idle timeout
- Absolute timeout
- Warning notifications

3.4. **Session hijacking prevention** (2 days)
- IP validation with flexibility
- User agent checking
- Anomaly detection

### 4. Functioning Telemetry System
**Priority**: CRITICAL
**Owner**: Platform Team
**Dependencies**: None

#### Tasks:
4.1. **Create telemetry supervisor** (3 days)
```elixir
# File: lib/indrajaal/telemetry/supervisor.ex
defmodule Indrajaal.Telemetry.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Indrajaal.Telemetry.MetricsCollector, []},
      {Indrajaal.Telemetry.EventHandler, []},
      {Indrajaal.Telemetry.Reporter, []},
      {Indrajaal.Telemetry.Storage, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

4.2. **Implement metrics collection** (3 days)
- Request metrics
- Database query metrics
- Business metrics
- System metrics

4.3. **Create event handlers** (2 days)
```elixir
# File: lib/indrajaal/telemetry/handlers.ex
defmodule Indrajaal.Telemetry.Handlers do
  def setup do
    events = [
      [:phoenix, :endpoint, :stop],
      [:indrajaal, :repo, :query],
      [:indrajaal, :auth, :login],
      [:indrajaal, :alarm, :triggered],
      [:indrajaal, :safety, :violation]
    ]

    :telemetry.attach_many(
      "indrajaal-metrics",
      events,
      &handle_event/4,
      nil
    )
  end

  def handle_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    # Process HTTP request metrics
  end

  def handle_event([:indrajaal, :safety, :violation], measurements, metadata, _config) do
    # Trigger safety interventions
  end
end
```

4.4. **Integration tests** (1 day)

## Sprint 2: Safety Infrastructure (Weeks 3-4)

### 5. Runtime Safety Monitors
**Priority**: HIGH
**Owner**: Safety Team
**Dependencies**: Telemetry system

#### Tasks:
5.1. **Create safety monitor GenServer** (4 days)
```elixir
# File: lib/indrajaal/safety/monitor.ex
defmodule Indrajaal.Safety.Monitor do
  use GenServer
  require Logger

  @safety_constraints [
    {:alarm_rate, :max, 1000, :per_minute},
    {:failed_auth, :max, 10, :per_minute},
    {:tenant_violations, :max, 0, :absolute},
    {:db_connections, :max, 100, :absolute},
    {:memory_usage, :max, 80, :percentage}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check_constraint(metric, value) do
    GenServer.call(__MODULE__, {:check, metric, value})
  end

  @impl true
  def handle_call({:check, metric, value}, _from, state) do
    case evaluate_constraint(metric, value, state) do
      :ok ->
        {:reply, :ok, update_state(state, metric, value)}
      {:violation, constraint} ->
        handle_violation(constraint, metric, value)
        {:reply, {:error, :safety_violation}, state}
    end
  end

  defp handle_violation(constraint, metric, value) do
    Logger.error("Safety violation: #{metric} = #{value} violates #{inspect(constraint)}")

    # Trigger interventions
    case constraint.severity do
      :critical -> EmergencyResponse.activate(constraint)
      :high -> Alerts.send_immediate(constraint)
      :medium -> Alerts.send_delayed(constraint)
      :low -> Logger.warn("Low severity violation logged")
    end
  end
end
```

5.2. **Implement constraint validation engine** (3 days)
- Dynamic constraint loading
- Complex constraint expressions
- Time-window constraints
- Percentage-based constraints

5.3. **Create intervention system** (3 days)
- Automatic remediation actions
- Circuit breakers
- Graceful degradation
- Emergency shutdown procedures

5.4. **Add safety metrics dashboard** (2 days)
- Real-time constraint status
- Historical violation data
- Predictive warnings
- Intervention history

### 6. Error Pattern Integration
**Priority**: HIGH
**Owner**: Platform Team
**Dependencies**: Error pattern database

#### Tasks:
6.1. **Create pattern matching engine** (3 days)
```elixir
# File: lib/indrajaal/safety/error_pattern_engine.ex
defmodule Indrajaal.Safety.ErrorPatternEngine do
  @patterns [
    %{
      id: "EP001",
      pattern: ~r/connection.*refused/i,
      category: :connection,
      severity: :high,
      remediation: :restart_connection_pool
    },
    %{
      id: "EP002",
      pattern: ~r/timeout.*exceeded/i,
      category: :performance,
      severity: :medium,
      remediation: :increase_timeout
    }
    # ... 110+ more patterns
  ]

  def analyze(error) do
    matching_patterns = Enum.filter(@patterns, &matches?(&1, error))

    matching_patterns
    |> Enum.sort_by(& &1.severity)
    |> Enum.map(&apply_remediation/1)
  end

  defp apply_remediation(%{remediation: action} = pattern) do
    case action do
      :restart_connection_pool ->
        Indrajaal.Repo.restart_pool()
      :increase_timeout ->
        Indrajaal.Config.update_timeout(pattern.suggested_value)
      # ... more remediation actions
    end
  end
end
```

6.2. **Load patterns from database** (2 days)
- Dynamic pattern loading
- Pattern versioning
- A/B testing for remediations

6.3. **Create remediation library** (3 days)
- Automated fixes
- Manual intervention requests
- Rollback mechanisms
- Success tracking

6.4. **Integration with error handler** (2 days)
- Automatic pattern analysis
- Remediation execution
- Metric collection
- Learning system

### 7. Safety Constraint Validation
**Priority**: HIGH
**Owner**: Safety Team
**Dependencies**: STAMP implementation

#### Tasks:
7.1. **Implement constraint validator** (3 days)
```elixir
# File: lib/indrajaal/safety/constraint_validator.ex
defmodule Indrajaal.Safety.ConstraintValidator do
  @ucas [
    %{
      id: "UCA001",
      control_action: :alarm_acknowledgment,
      context: :alarm_storm,
      unsafe_condition: :delayed_acknowledgment,
      validation: fn timing -> timing < 1000 end
    },
    # ... 77 more UCAs
  ]

  def validate_action(action, context, params) do
    applicable_ucas = Enum.filter(@ucas, &applies_to?(&1, action, context))

    violations = Enum.reject(applicable_ucas, fn uca ->
      uca.validation.(params)
    end)

    case violations do
      [] -> :ok
      _ -> {:error, {:unsafe_control_actions, violations}}
    end
  end
end
```

7.2. **Add pre-action validation hooks** (2 days)
- Ash action callbacks
- Controller validations
- Background job checks

7.3. **Create safety gates** (2 days)
- Critical path protection
- Degraded mode operations
- Override mechanisms

7.4. **Testing and validation** (2 days)

### 8. Incident Response System
**Priority**: HIGH
**Owner**: Operations Team
**Dependencies**: Telemetry, monitoring

#### Tasks:
8.1. **Create incident coordinator** (3 days)
```elixir
# File: lib/indrajaal/safety/incident_coordinator.ex
defmodule Indrajaal.Safety.IncidentCoordinator do
  use GenServer

  defstruct [:id, :type, :severity, :status, :started_at, :actions, :resolution]

  def report_incident(type, details) do
    GenServer.call(__MODULE__, {:new_incident, type, details})
  end

  @impl true
  def handle_call({:new_incident, type, details}, _from, state) do
    incident = %__MODULE__{
      id: generate_incident_id(),
      type: type,
      severity: assess_severity(type, details),
      status: :active,
      started_at: DateTime.utc_now(),
      actions: []
    }

    # Start incident response
    {:ok, pid} = IncidentHandler.start_link(incident)

    # Notify stakeholders
    notify_incident_started(incident)

    # Start CAST analysis
    CastAnalyzer.analyze_async(incident)

    {:reply, {:ok, incident.id}, Map.put(state, incident.id, {incident, pid})}
  end
end
```

8.2. **Implement CAST analyzer** (3 days)
- Automated root cause analysis
- System state capture
- Timeline reconstruction
- Recommendation engine

8.3. **Create response playbooks** (2 days)
- Automated response actions
- Escalation procedures
- Communication templates
- Recovery verification

8.4. **Add incident dashboard** (2 days)
- Active incidents
- Response timeline
- Action history
- Post-mortem reports

## Sprint 3: Advanced Integration (Weeks 5-6)

### 9. Full STAMP Runtime Integration
**Priority**: MEDIUM
**Owner**: Architecture Team
**Dependencies**: All previous safety systems

#### Tasks:
9.1. **Move STAMP to runtime** (4 days)
```elixir
# File: lib/indrajaal/safety/stamp/runtime.ex
defmodule Indrajaal.Safety.STAMP.Runtime do
  @moduledoc """
  Runtime STAMP integration for continuous safety validation
  """

  def validate_control_structure do
    %{
      controllers: identify_controllers(),
      control_actions: map_control_actions(),
      feedback_loops: trace_feedback_loops(),
      safety_constraints: load_safety_constraints()
    }
  end

  def monitor_control_action(controller, action, context) do
    with :ok <- validate_controller_authority(controller, action),
         :ok <- check_action_preconditions(action, context),
         :ok <- validate_safety_constraints(action, context),
         :ok <- check_feedback_requirements(action) do
      :ok
    else
      {:error, reason} = error ->
        log_safety_violation(controller, action, reason)
        error
    end
  end
end
```

9.2. **Create control structure monitor** (3 days)
- Real-time control flow tracking
- Authority validation
- Feedback loop monitoring
- Constraint enforcement

9.3. **Implement STPA automation** (3 days)
- Automated hazard analysis
- UCA detection
- Control flaw identification
- Mitigation suggestions

9.4. **Integration testing** (2 days)

### 10. Multi-Agent Safety System
**Priority**: MEDIUM
**Owner**: Agent Team
**Dependencies**: Agent infrastructure

#### Tasks:
10.1. **Create safety supervisor agent** (3 days)
```elixir
# File: lib/indrajaal/agents/safety_supervisor.ex
defmodule Indrajaal.Agents.SafetySupervisor do
  use GenServer

  @safety_agents [
    :constraint_monitor,
    :incident_responder,
    :pattern_analyzer,
    :intervention_executor,
    :audit_tracker
  ]

  def coordinate_safety_response(issue) do
    # Distribute work to specialized agents
    tasks = assign_tasks(issue, @safety_agents)

    # Collect responses
    responses = Task.await_many(tasks, 30_000)

    # Build consensus
    decision = build_consensus(responses)

    # Execute coordinated response
    execute_decision(decision)
  end

  defp build_consensus(responses) do
    # Implement voting mechanism
    # Weight by agent expertise
    # Resolve conflicts
    # Generate unified response
  end
end
```

10.2. **Implement specialized safety agents** (4 days)
- Constraint monitoring agent
- Incident response agent
- Pattern analysis agent
- Intervention agent
- Audit agent

10.3. **Create agent communication protocol** (2 days)
- Message passing
- State sharing
- Consensus building
- Conflict resolution

10.4. **Add distributed decision making** (3 days)
- Voting mechanisms
- Expertise weighting
- Escalation procedures
- Override capabilities

### 11. Advanced Monitoring Dashboards
**Priority**: MEDIUM
**Owner**: UI/UX Team
**Dependencies**: Telemetry, LiveView

#### Tasks:
11.1. **Create safety dashboard** (3 days)
```elixir
# File: lib/indrajaal_web/live/safety_dashboard_live.ex
defmodule IndrajaalWeb.SafetyDashboardLive do
  use IndrajaalWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to safety events
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "safety:metrics")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "safety:violations")
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "safety:interventions")
    end

    {:ok, assign(socket,
      constraints: load_constraints(),
      violations: load_recent_violations(),
      metrics: load_current_metrics(),
      interventions: load_active_interventions()
    )}
  end

  def handle_info({:safety_metric, metric}, socket) do
    {:noreply, update_metric(socket, metric)}
  end

  def handle_info({:safety_violation, violation}, socket) do
    {:noreply, add_violation(socket, violation)}
  end
end
```

11.2. **Add real-time visualizations** (3 days)
- Constraint status indicators
- Violation heat maps
- Trend analysis
- Predictive warnings

11.3. **Create incident command center** (2 days)
- Active incident tracking
- Response coordination
- Resource allocation
- Communication hub

11.4. **Implement audit dashboard** (2 days)
- Compliance status
- Audit trails
- Report generation
- Remediation tracking

### 12. Chaos Engineering Tests
**Priority**: MEDIUM
**Owner**: QA Team
**Dependencies**: All safety systems

#### Tasks:
12.1. **Create chaos test framework** (3 days)
```elixir
# File: test/chaos/safety_chaos_test.exs
defmodule Indrajaal.Chaos.SafetyTest do
  use Indrajaal.ChaosCase

  @chaos_scenarios [
    :database_failure,
    :memory_exhaustion,
    :network_partition,
    :clock_skew,
    :disk_full,
    :cpu_starvation,
    :cascading_failure
  ]

  test "system remains safe under chaos" do
    for scenario <- @chaos_scenarios do
      # Inject chaos
      {:ok, chaos_ref} = ChaosMonkey.inject(scenario)

      # Verify safety maintained
      assert SafetyMonitor.all_constraints_holding?()

      # Verify interventions triggered
      assert length(SafetyMonitor.get_interventions()) > 0

      # Verify system recovers
      ChaosMonkey.stop(chaos_ref)
      assert eventually(fn -> system_healthy?() end)
    end
  end
end
```

12.2. **Implement chaos scenarios** (3 days)
- Resource exhaustion
- Network failures
- Byzantine failures
- Time-based issues

12.3. **Add safety verification** (2 days)
- Constraint monitoring
- Intervention tracking
- Recovery validation
- Performance impact

12.4. **Create chaos reports** (2 days)
- Failure analysis
- Safety response evaluation
- Improvement recommendations
- Regression prevention

## Success Criteria

### Sprint 1 Success Metrics:
- 0 authentication bypasses in penetration testing
- < 10ms token validation latency
- 100% of sessions properly secured
- Telemetry capturing 100% of defined events

### Sprint 2 Success Metrics:
- 100% of UCAs monitored in runtime
- < 100ms safety constraint validation
- 90% of known error patterns handled automatically
- < 5 minute mean time to incident detection

### Sprint 3 Success Metrics:
- Full STAMP compliance in runtime
- 11-agent safety coordination operational
- < 1 second safety decision consensus
- Chaos tests passing without safety violations

## Risk Mitigation

### Technical Risks:
1. **Performance Impact**: Mitigate with caching, async processing
2. **Complexity**: Phase implementation, extensive testing
3. **Integration Issues**: Clear interfaces, gradual rollout

### Process Risks:
1. **Timeline Slippage**: Daily standups, early escalation
2. **Scope Creep**: Strict change control, clear priorities
3. **Resource Conflicts**: Dedicated safety team, clear ownership

## Resource Requirements

### Team Allocation:
- 2 Senior Security Engineers
- 2 Platform Engineers
- 1 Safety Specialist
- 1 UI/UX Developer
- 1 QA Engineer

### Infrastructure:
- Redis cluster for distributed caching
- Additional monitoring infrastructure
- Load testing environment
- Chaos testing platform

## Implementation Schedule

### Week 1-2 (Sprint 1):
- Mon-Tue: JWT implementation
- Wed-Thu: Rate limiting
- Fri-Mon: Session security
- Tue-Thu: Telemetry system
- Fri: Integration and testing

### Week 3-4 (Sprint 2):
- Mon-Wed: Safety monitors
- Thu-Fri: Error patterns
- Mon-Tue: Constraint validation
- Wed-Thu: Incident response
- Fri: Sprint review and testing

### Week 5-6 (Sprint 3):
- Mon-Tue: STAMP integration
- Wed-Thu: Multi-agent system
- Fri-Mon: Monitoring dashboards
- Tue-Wed: Chaos engineering
- Thu-Fri: Final testing and deployment

## Conclusion

This plan addresses all critical safety gaps identified in the analysis. The phased approach ensures we fix the most dangerous vulnerabilities first while building toward a comprehensive safety system that matches the excellent architecture already documented.

Key to success:
1. No shortcuts on security implementations
2. Extensive testing at each phase
3. Real implementations, not stubs
4. Continuous monitoring of safety metrics
5. Regular security audits

Upon completion, the Indrajaal system will have enterprise-grade safety systems that match its ambitious architectural vision.

---
**Plan Version**: 1.0
**Last Updated**: 2025-08-04 15:51:00 CEST
**Next Review**: Week 2 Sprint Planning