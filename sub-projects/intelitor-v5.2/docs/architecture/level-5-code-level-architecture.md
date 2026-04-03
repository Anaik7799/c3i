# Level 5: Code-Level Architecture

**Version**: 1.0.0
**Date**: 2025-12-19
**Framework**: SOPv5.11 + STAMP + TDG + GDE + CAFE
**Compliance**: IEC 61508 SIL-2

---

## 1. Overview

This document provides detailed code-level architecture documentation for the Indrajaal safety-critical security platform. It covers implementation patterns, algorithms, type specifications, and code structures used across the cybernetic control system.

### 1.1 Scope

- GenServer implementation patterns
- Type specifications and contracts
- Core algorithms (stress calculation, trend analysis, OODA cycles)
- State management structures
- Quality gates and validation logic
- Safety constraint enforcement

---

## 2. Core Design Patterns

### 2.1 GenServer Pattern

All stateful processes in Indrajaal follow the OTP GenServer pattern for fault tolerance and supervision.

```elixir
defmodule Indrajaal.Cortex.Homeostasis do
  use GenServer
  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  ## Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  ## Server Callbacks
  @impl true
  def init(_opts) do
    state = %{
      current_stress: 0.0,
      stress_trend: :stable,
      thresholds: %{...},
      started_at: DateTime.utc_now()
    }
    schedule_check()
    {:ok, state}
  end
end
```

**Pattern Elements**:
- Named process registration (`name: __MODULE__`)
- State initialization in `init/1`
- Scheduled recurring work via `Process.send_after/3`
- OpenTelemetry tracing integration
- Explicit callback implementation (`@impl true`)

### 2.2 State Machine Pattern (OODA Loop)

The OODA loop implements a cyclic state machine for cybernetic control:

```elixir
defmodule Indrajaal.Cybernetic.OODA.Loop do
  use GenServer
  require Logger

  defstruct [:phase, :context, :start_time, :cycle_count]

  @phases [:observe, :orient, :decide, :act]

  def init(_opts) do
    state = %__MODULE__{
      phase: :observe,
      context: %{},
      start_time: System.monotonic_time(:millisecond),
      cycle_count: 0
    }
    schedule_next_phase(:observe)
    {:ok, state}
  end

  # Phase transitions
  def handle_info(:observe, state) do
    observations = Indrajaal.Cybernetic.OODA.Observer.collect()
    schedule_next_phase(:orient)
    {:noreply, %{state | phase: :orient, context: %{observations: observations}}}
  end

  def handle_info(:orient, state) do
    strategy = Indrajaal.Cybernetic.OODA.Orientator.analyze(state.context.observations)
    schedule_next_phase(:decide)
    {:noreply, %{state | phase: :decide, context: Map.put(state.context, :strategy, strategy)}}
  end

  def handle_info(:decide, state) do
    decision = Indrajaal.Cybernetic.OODA.Decider.make_decision(state.context.strategy)
    # Quality gate: confidence threshold
    if decision.confidence > 0.7 do
      schedule_next_phase(:act)
      {:noreply, %{state | phase: :act, context: Map.put(state.context, :decision, decision)}}
    else
      Logger.info("OODA: Low confidence, skipping Action")
      schedule_next_phase(:observe)
      {:noreply, %{state | phase: :observe}}
    end
  end

  def handle_info(:act, state) do
    Indrajaal.Cybernetic.OODA.Actor.execute(state.context.decision)
    new_cycle_count = state.cycle_count + 1
    schedule_next_phase(:observe)
    {:noreply, %{state |
      phase: :observe,
      cycle_count: new_cycle_count,
      start_time: System.monotonic_time(:millisecond)
    }}
  end

  defp schedule_next_phase(phase) do
    Process.send_after(self(), phase, 100)
  end
end
```

**Pattern Elements**:
- Struct-based state definition
- Phase enumeration constant
- Quality gate in decision phase (confidence > 0.7)
- Cycle counting for metrics
- Immediate phase scheduling

---

## 3. Type Specifications

### 3.1 Agent Manager Types

```elixir
@moduledoc """
Agent Management Type System
"""

# Agent classification types
@type agent_type :: :supervisor | :helper | :worker | :specialist
@type agent_status :: :idle | :busy | :unhealthy | :terminated
@type scaling_direction :: :up | :down | :maintain

# Agent record structure
@type agent_info :: %{
  id: String.t(),
  type: agent_type(),
  status: agent_status(),
  capabilities: [atom()],
  current_task: task_id() | nil,
  health_score: float(),
  last_heartbeat: DateTime.t(),
  resource_allocation: resource_allocation(),
  performance_metrics: performance_metrics()
}

# Resource allocation structure
@type resource_allocation :: %{
  cpu_cores: pos_integer(),
  memory_mb: pos_integer(),
  network_mbps: pos_integer(),
  priority: :high | :normal | :low
}

# Performance metrics
@type performance_metrics :: %{
  tasks_completed: non_neg_integer(),
  average_task_duration_ms: float(),
  error_rate: float(),
  efficiency_score: float()
}
```

### 3.2 Safety Monitor Types

```elixir
@moduledoc """
STAMP Safety Monitoring Type System
"""

# Safety classification
@type safety_level :: :critical | :high | :medium | :low | :informational

# Violation categorization
@type violation_type ::
  :constraint_violation |
  :hazard_detected |
  :unsafe_state |
  :performance_degradation

# Response action enumeration
@type response_action ::
  :immediate_halt |
  :graceful_shutdown |
  :warning_alert |
  :monitoring_increase

# Safety constraint structure
@type safety_constraint :: %{
  id: String.t(),
  name: String.t(),
  description: String.t(),
  safety_level: safety_level(),
  validation_rule: (map() -> boolean()),
  response_action: response_action(),
  enabled: boolean()
}

# Violation record
@type violation_record :: %{
  constraint_id: String.t(),
  violation_type: violation_type(),
  timestamp: DateTime.t(),
  context: map(),
  resolved: boolean(),
  resolution_time: DateTime.t() | nil
}
```

### 3.3 Homeostasis Types

```elixir
@moduledoc """
Autonomic Regulation Type System
"""

# Stress trend enumeration
@type stress_trend :: :rising | :falling | :stable

# Actuator action types
@type actuator_action :: :emergency_expand | :expand | :contract

# Threshold configuration
@type threshold_config :: %{
  critical: float(),      # 0.9
  high: float(),          # 0.75
  optimal_high: float(),  # 0.6
  optimal_low: float(),   # 0.3
  low: float()            # 0.2
}

# Homeostasis state
@type homeostasis_state :: %{
  current_stress: float(),
  stress_trend: stress_trend(),
  thresholds: threshold_config(),
  last_action: actuator_action() | nil,
  last_action_at: DateTime.t() | nil,
  action_history: [{actuator_action(), DateTime.t()}],
  stress_history: [{float(), DateTime.t()}],
  auto_tune: boolean(),
  started_at: DateTime.t()
}
```

---

## 4. Core Algorithms

### 4.1 Stress Calculation Algorithm

The homeostasis engine calculates system stress using a weighted average of resource metrics:

```elixir
@doc """
Calculate system stress score from metrics.

Formula: stress = memory * 0.4 + cpu * 0.3 + queue * 0.3

Where:
- memory: Memory usage ratio (0.0-1.0)
- cpu: CPU usage ratio (0.0-1.0)
- queue: Normalized run queue (capped at 1.0)

Returns: float between 0.0 and 1.0
"""
defp calculate_stress(metrics) do
  # Try enhanced Analyzer first, fall back to basic calculation
  try do
    Analyzer.calculate_stress_score(metrics)
  rescue
    _ ->
      # Basic stress calculation
      memory = Map.get(metrics, :memory_usage, 0.5)
      cpu = Map.get(metrics, :cpu_usage, 0.5)
      queue = min(Map.get(metrics, :run_queue, 0) / 100, 1.0)

      # Weighted average with memory prioritized
      memory * 0.4 + cpu * 0.3 + queue * 0.3
  end
end
```

**Algorithm Properties**:
- **Weights**: Memory (40%), CPU (30%), Run Queue (30%)
- **Normalization**: Run queue divided by 100, capped at 1.0
- **Fallback**: Graceful degradation to basic calculation
- **Default Values**: 0.5 for missing metrics (neutral stress)

### 4.2 Trend Analysis Algorithm

Stress trend is calculated by comparing recent vs. historical averages:

```elixir
@doc """
Calculate stress trend from historical readings.

Compares average of most recent 5 readings against
average of older 5 readings.

Trend thresholds:
- Rising: recent_avg > older_avg + 0.1
- Falling: recent_avg < older_avg - 0.1
- Stable: otherwise
"""
defp calculate_trend(history) when length(history) < 3, do: :stable

defp calculate_trend(history) do
  # Extract recent readings (first 5)
  recent = history |> Enum.take(5) |> Enum.map(fn {s, _} -> s end)
  avg_recent = Enum.sum(recent) / length(recent)

  # Extract older readings (next 5)
  older = history |> Enum.drop(5) |> Enum.take(5) |> Enum.map(fn {s, _} -> s end)

  if length(older) > 0 do
    avg_older = Enum.sum(older) / length(older)
    diff = avg_recent - avg_older

    cond do
      diff > 0.1 -> :rising
      diff < -0.1 -> :falling
      true -> :stable
    end
  else
    :stable
  end
end
```

**Algorithm Properties**:
- **Window Size**: 5 readings each for recent and older
- **Threshold**: 0.1 (10%) change required to indicate trend
- **Minimum Data**: 3 readings required for trend calculation
- **History Format**: `[{stress_value, timestamp}, ...]`

### 4.3 Control Logic Algorithm

The homeostasis control logic determines actions based on stress level and trend:

```elixir
@doc """
Apply control logic to determine homeostatic action.

Decision Matrix:
| Stress Level | Trend   | Action           |
|--------------|---------|------------------|
| > critical   | any     | emergency_expand |
| > high       | rising  | expand           |
| < low        | falling | contract         |
| optimal      | any     | none             |
| other        | any     | none (monitor)   |

Rate limiting: Minimum 60 seconds between non-emergency actions.
"""
defp apply_control_logic(stress, trend, state) do
  now = DateTime.utc_now()
  can_act = can_take_action?(state.last_action_at, now)

  cond do
    # Critical stress - always act (bypasses rate limit)
    stress > state.thresholds.critical ->
      action = :emergency_expand
      Logger.warning("CRITICAL STRESS (#{Float.round(stress, 2)})")
      execute_action(action, state, now)

    # High stress and rising - expand if rate limit allows
    stress > state.thresholds.high and trend == :rising and can_act ->
      action = :expand
      Logger.warning("High stress (#{Float.round(stress, 2)}), rising")
      execute_action(action, state, now)

    # Low stress and falling - contract if rate limit allows
    stress < state.thresholds.low and trend == :falling and can_act ->
      action = :contract
      Logger.info("Low stress (#{Float.round(stress, 2)}), falling")
      execute_action(action, state, now)

    # Within optimal bounds - no action
    stress >= state.thresholds.optimal_low and
    stress <= state.thresholds.optimal_high ->
      {nil, state}

    # Monitoring, no action
    true ->
      {nil, state}
  end
end

defp can_take_action?(nil, _now), do: true
defp can_take_action?(last_action_at, now) do
  elapsed = DateTime.diff(now, last_action_at, :millisecond)
  elapsed >= @min_action_interval  # 60,000 ms
end
```

**Algorithm Properties**:
- **Emergency Override**: Critical stress bypasses rate limiting
- **Rate Limiting**: 60 second minimum between actions
- **Trend Coupling**: Actions require matching trend direction
- **Optimal Band**: No action when within 0.3-0.6 stress range

### 4.4 Agent Capability Assignment

```elixir
@doc """
Define capabilities based on agent type.

Each agent type has specific capabilities that determine
what tasks it can perform.
"""
defp define_agent_capabilities(:supervisor) do
  [
    :strategic_oversight,
    :resource_allocation,
    :conflict_resolution,
    :progress_monitoring,
    :agent_coordination,
    :decision_making
  ]
end

defp define_agent_capabilities(:helper) do
  [
    :compilation_management,
    :testing_coordination,
    :analysis_support,
    :monitoring_assistance,
    :validation_support,
    :optimization_analysis
  ]
end

defp define_agent_capabilities(:worker) do
  [
    :task_execution,
    :parallel_processing,
    :container_operations,
    :file_processing,
    :data_transformation,
    :batch_operations
  ]
end

defp define_agent_capabilities(:specialist) do
  [
    :advanced_analytics,
    :machine_learning,
    :security_analysis,
    :performance_optimization,
    :compliance_checking,
    :pattern_recognition
  ]
end
```

### 4.5 Resource Allocation Strategy

```elixir
@doc """
Allocate resources based on agent type.

Resource allocation determines CPU, memory, network,
and scheduling priority for each agent type.
"""
defp get_resource_allocation_for_type(:supervisor) do
  %{
    cpu_cores: 2,
    memory_mb: 1024,
    network_mbps: 50,
    priority: :high
  }
end

defp get_resource_allocation_for_type(:helper) do
  %{
    cpu_cores: 1,
    memory_mb: 512,
    network_mbps: 25,
    priority: :normal
  }
end

defp get_resource_allocation_for_type(:worker) do
  %{
    cpu_cores: 1,
    memory_mb: 256,
    network_mbps: 10,
    priority: :normal
  }
end

defp get_resource_allocation_for_type(:specialist) do
  %{
    cpu_cores: 4,
    memory_mb: 2048,
    network_mbps: 100,
    priority: :high
  }
end
```

---

## 5. Safety Constraint Implementation

### 5.1 STAMP Constraint Definitions

The safety monitor defines 10 core safety constraints (SC001-SC010):

```elixir
@doc """
Initialize predefined safety constraints.

Each constraint includes:
- Unique identifier (SC001-SC010)
- Human-readable name
- Description of the safety requirement
- Safety level classification
- Validation rule (function)
- Response action on violation
- Enabled flag
"""
defp initialize_safety_constraints do
  [
    %{
      id: "SC001",
      name: "Patient Mode Compilation",
      description: "All compilations must use patient mode with no timeouts",
      safety_level: :critical,
      validation_rule: &validate_patient_mode_compilation/1,
      response_action: :immediate_halt,
      enabled: true
    },
    %{
      id: "SC002",
      name: "Container Isolation",
      description: "All operations must execute within isolated containers",
      safety_level: :critical,
      validation_rule: &validate_container_isolation/1,
      response_action: :immediate_halt,
      enabled: true
    },
    %{
      id: "SC003",
      name: "Zero Defect Quality",
      description: "No compilation errors or warnings allowed",
      safety_level: :high,
      validation_rule: &validate_zero_defect_quality/1,
      response_action: :graceful_shutdown,
      enabled: true
    },
    %{
      id: "SC004",
      name: "Test-Driven Development",
      description: "Tests must precede implementation",
      safety_level: :high,
      validation_rule: &validate_test_driven_development/1,
      response_action: :warning_alert,
      enabled: true
    },
    %{
      id: "SC005",
      name: "Validation Consensus",
      description: "All validation methods must agree",
      safety_level: :critical,
      validation_rule: &validate_consensus/1,
      response_action: :immediate_halt,
      enabled: true
    },
    %{
      id: "SC006",
      name: "Agent Efficiency",
      description: "Agent efficiency must exceed 90%",
      safety_level: :medium,
      validation_rule: &validate_agent_efficiency/1,
      response_action: :monitoring_increase,
      enabled: true
    },
    %{
      id: "SC007",
      name: "Deadlock Prevention",
      description: "No agent deadlocks allowed",
      safety_level: :critical,
      validation_rule: &validate_no_deadlocks/1,
      response_action: :immediate_halt,
      enabled: true
    },
    %{
      id: "SC008",
      name: "Resource Limits",
      description: "Resource usage must stay within limits",
      safety_level: :high,
      validation_rule: &validate_resource_limits/1,
      response_action: :graceful_shutdown,
      enabled: true
    },
    %{
      id: "SC009",
      name: "Data Integrity",
      description: "Data integrity must be maintained",
      safety_level: :critical,
      validation_rule: &validate_data_integrity/1,
      response_action: :immediate_halt,
      enabled: true
    },
    %{
      id: "SC010",
      name: "Audit Trail",
      description: "All operations must be logged",
      safety_level: :medium,
      validation_rule: &validate_audit_trail/1,
      response_action: :warning_alert,
      enabled: true
    }
  ]
end
```

### 5.2 Constraint Validation Pattern

```elixir
@doc """
Validate a single safety constraint against current state.

Returns:
- {:ok, constraint} on success
- {:violation, constraint, context} on failure
"""
defp validate_constraint(constraint, state) do
  if constraint.enabled do
    context = build_validation_context(state)
    case constraint.validation_rule.(context) do
      true -> {:ok, constraint}
      false -> {:violation, constraint, context}
      {:error, reason} -> {:violation, constraint, Map.put(context, :error, reason)}
    end
  else
    {:ok, constraint}  # Disabled constraints always pass
  end
end

defp build_validation_context(state) do
  %{
    timestamp: DateTime.utc_now(),
    system_state: get_system_state(),
    agent_states: get_agent_states(),
    resource_metrics: get_resource_metrics(),
    safety_state: state
  }
end
```

### 5.3 Emergency Shutdown Protocol

```elixir
@doc """
Execute emergency shutdown sequence.

Steps:
1. Halt dangerous operations
2. Save critical state
3. Notify operators
4. Initiate recovery mode

This is triggered by :immediate_halt response action.
"""
defp execute_emergency_shutdown(state, reason) do
  shutdown_steps = [
    :halt_dangerous_operations,
    :save_critical_state,
    :notify_operators,
    :initiate_recovery_mode
  ]

  results = Enum.map(shutdown_steps, fn step ->
    execute_shutdown_step(step, reason, state)
  end)

  %{
    shutdown_reason: reason,
    steps_executed: shutdown_steps,
    results: results,
    emergency_timestamp: DateTime.utc_now(),
    recovery_mode_active: true
  }
end

defp execute_shutdown_step(:halt_dangerous_operations, _reason, _state) do
  # Stop all non-essential processes
  {:ok, :operations_halted}
end

defp execute_shutdown_step(:save_critical_state, _reason, state) do
  # Persist state to durable storage
  {:ok, :state_saved}
end

defp execute_shutdown_step(:notify_operators, reason, _state) do
  # Send alerts via configured channels
  {:ok, :operators_notified}
end

defp execute_shutdown_step(:initiate_recovery_mode, _reason, _state) do
  # Enter safe mode for recovery
  {:ok, :recovery_mode_active}
end
```

---

## 6. State Management

### 6.1 Homeostasis State Structure

```elixir
%{
  # Current stress assessment
  current_stress: 0.0,           # float 0.0-1.0
  stress_trend: :stable,         # :rising | :falling | :stable

  # Operational bounds (thresholds)
  thresholds: %{
    critical: 0.9,
    high: 0.75,
    optimal_high: 0.6,
    optimal_low: 0.3,
    low: 0.2
  },

  # Action history
  last_action: nil,              # :emergency_expand | :expand | :contract | nil
  last_action_at: nil,           # DateTime.t() | nil
  action_history: [],            # [{action, timestamp}, ...]

  # Metrics history for trend analysis
  stress_history: [],            # [{stress_value, timestamp}, ...]

  # Configuration
  auto_tune: true,               # Enable automatic threshold adjustment
  started_at: DateTime.utc_now() # Process start time
}
```

### 6.2 Agent Manager State Structure

```elixir
%{
  # Agent registry
  agents: %{},                   # %{agent_id => agent_info}

  # Task management
  task_queue: [],                # Pending tasks
  active_tasks: %{},             # %{task_id => task_info}

  # Scaling configuration
  scaling_config: %{
    min_agents: 5,
    max_agents: 50,
    scale_up_threshold: 0.8,
    scale_down_threshold: 0.3,
    cooldown_period_ms: 60_000
  },

  # Health monitoring
  health_check_interval_ms: 30_000,
  unhealthy_threshold: 3,        # Consecutive failures

  # Metrics
  total_tasks_completed: 0,
  total_tasks_failed: 0,
  started_at: DateTime.utc_now()
}
```

### 6.3 Safety Monitor State Structure

```elixir
%{
  # Constraint management
  constraints: [],               # [safety_constraint, ...]
  enabled_constraints: [],       # Filtered enabled constraints

  # Violation tracking
  violations: [],                # [violation_record, ...]
  active_violations: [],         # Unresolved violations
  violation_count_by_level: %{
    critical: 0,
    high: 0,
    medium: 0,
    low: 0,
    informational: 0
  },

  # Hazard analysis
  hazard_patterns: [],           # Identified hazard patterns
  hazard_mitigations: %{},       # Active mitigations

  # Safety status
  safety_status: :safe,          # :safe | :warning | :critical | :emergency
  last_check_time: nil,
  check_interval_ms: 5_000,

  # Emergency state
  emergency_mode: false,
  emergency_reason: nil,
  recovery_in_progress: false
}
```

---

## 7. Quality Gates

### 7.1 OODA Decision Confidence Gate

```elixir
@doc """
Quality gate for OODA decision phase.

A decision is only acted upon if confidence exceeds
the threshold (0.7 = 70%).

Low confidence decisions loop back to observation
for more data collection.
"""
def handle_info(:decide, state) do
  decision = Decider.make_decision(state.context.strategy)

  # QUALITY GATE: Confidence threshold
  if decision.confidence > 0.7 do
    schedule_next_phase(:act)
    {:noreply, update_phase(state, :act, decision)}
  else
    Logger.info("OODA: Low confidence (#{decision.confidence}), skipping Action")
    schedule_next_phase(:observe)
    {:noreply, reset_to_observe(state)}
  end
end
```

### 7.2 Agent Health Gate

```elixir
@doc """
Health check gate for agent operations.

Agents must pass health checks to remain active.
Failed checks trigger recovery or termination.
"""
defp perform_health_check(agent_id, state) do
  agent = Map.get(state.agents, agent_id)

  checks = [
    check_heartbeat(agent),
    check_memory_usage(agent),
    check_task_completion_rate(agent),
    check_error_rate(agent)
  ]

  health_score = calculate_health_score(checks)

  cond do
    health_score >= 0.8 -> {:healthy, health_score}
    health_score >= 0.5 -> {:degraded, health_score}
    true -> {:unhealthy, health_score}
  end
end
```

### 7.3 FPPS Consensus Gate

```elixir
@doc """
Five-Point Pattern System consensus gate.

All 5 validation methods must agree on error/warning
counts for validation to pass.

Disagreement triggers EP-110 prevention protocol.
"""
def check_consensus(results) do
  error_counts = Enum.map(results, & &1.errors) |> Enum.uniq()
  warning_counts = Enum.map(results, & &1.warnings) |> Enum.uniq()

  cond do
    length(error_counts) == 1 and length(warning_counts) == 1 ->
      {:consensus, %{errors: hd(error_counts), warnings: hd(warning_counts)}}

    true ->
      Logger.error("FPPS Consensus Failure - EP-110 Prevention Active")
      {:disagreement, %{
        error_counts: error_counts,
        warning_counts: warning_counts,
        action: :emergency_halt
      }}
  end
end
```

---

## 8. OpenTelemetry Integration

### 8.1 Tracing Pattern

```elixir
require OpenTelemetry.Tracer, as: Tracer

defp perform_stability_check(state) do
  Tracer.with_span "homeostasis.stability_check", kind: :internal do
    # Collect metrics
    metrics = collect_metrics()

    # Calculate stress
    stress = calculate_stress(metrics)
    Tracer.set_attribute("homeostasis.stress", stress)

    # Calculate trend
    trend = calculate_trend(state.stress_history)
    Tracer.set_attribute("homeostasis.trend", to_string(trend))

    # Apply control logic
    {action, new_state} = apply_control_logic(stress, trend, state)

    if action do
      Tracer.set_attribute("homeostasis.action", to_string(action))
    end

    update_state(new_state, stress, trend)
  end
end
```

### 8.2 Metric Attributes

Standard attributes used across spans:

| Attribute | Type | Description |
|-----------|------|-------------|
| `homeostasis.stress` | float | Current stress level (0.0-1.0) |
| `homeostasis.trend` | string | Trend direction (rising/falling/stable) |
| `homeostasis.action` | string | Action taken (expand/contract/emergency_expand) |
| `agent.id` | string | Agent identifier |
| `agent.type` | string | Agent type |
| `agent.status` | string | Agent status |
| `safety.constraint_id` | string | Violated constraint ID |
| `safety.level` | string | Safety level of violation |

---

## 9. Error Handling Patterns

### 9.1 Graceful Degradation

```elixir
defp collect_metrics do
  try do
    SystemSensor.measure()
  rescue
    _ ->
      # Fallback to basic BeamSensor if SystemSensor unavailable
      try do
        Indrajaal.Cortex.Sensors.BeamSensor.measure()
      rescue
        _ -> %{memory_usage: 0.5, cpu_usage: 0.5, run_queue: 0}
      end
  end
end
```

### 9.2 Supervisor Recovery

```elixir
# In application supervisor
children = [
  {Indrajaal.Cortex.Homeostasis, []},
  {Indrajaal.Cybernetic.OODA.Loop, []},
  {Indrajaal.Coordination.AgentManager, []},
  {Indrajaal.Coordination.SafetyMonitor, []}
]

opts = [
  strategy: :one_for_one,  # Restart only failed child
  max_restarts: 10,
  max_seconds: 60
]

Supervisor.start_link(children, opts)
```

---

## 10. Configuration Constants

### 10.1 Timing Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `@check_interval` | 30s | Homeostasis check frequency |
| `@min_action_interval` | 60s | Rate limit between actions |
| `@health_check_interval` | 30s | Agent health check frequency |
| `@ooda_phase_interval` | 100ms | OODA phase transition delay |
| `@safety_check_interval` | 5s | Safety constraint check frequency |

### 10.2 Threshold Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `@stress_critical` | 0.9 | Emergency action threshold |
| `@stress_high` | 0.75 | Expand action threshold |
| `@stress_optimal_high` | 0.6 | Upper optimal bound |
| `@stress_optimal_low` | 0.3 | Lower optimal bound |
| `@stress_low` | 0.2 | Contract action threshold |
| `@confidence_threshold` | 0.7 | OODA decision confidence |
| `@efficiency_threshold` | 0.9 | Agent efficiency target |

### 10.3 Capacity Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `@max_agents` | 50 | Maximum agent count |
| `@min_agents` | 5 | Minimum agent count |
| `@stress_history_size` | 20 | Readings kept for trend |
| `@action_history_size` | 100 | Actions kept for audit |
| `@max_consecutive_failures` | 3 | Agent unhealthy threshold |

---

## 11. Code Organization

### 11.1 Module Hierarchy

```
lib/indrajaal/
├── cortex/
│   ├── homeostasis.ex         # Autonomic regulation
│   ├── controller.ex          # Cognitive control
│   ├── analyzer.ex            # Stress analysis
│   └── sensors/
│       ├── system_sensor.ex   # System metrics
│       └── beam_sensor.ex     # BEAM metrics
├── cybernetic/
│   ├── framework_orchestrator.ex
│   └── ooda/
│       ├── loop.ex            # OODA state machine
│       ├── observer.ex        # Data collection
│       ├── orientator.ex      # Strategy analysis
│       ├── decider.ex         # Decision making
│       └── actor.ex           # Action execution
├── coordination/
│   ├── agent_manager.ex       # Agent lifecycle
│   ├── safety_monitor.ex      # STAMP safety
│   ├── load_balancer.ex       # Task distribution
│   └── multi_agent_coordinator.ex
└── validation/
    └── fpps_validator.ex      # 5-method consensus
```

### 11.2 Naming Conventions

- **Modules**: PascalCase (`Indrajaal.Cortex.Homeostasis`)
- **Functions**: snake_case (`calculate_stress`)
- **Types**: snake_case (`agent_type`)
- **Constants**: SCREAMING_SNAKE_CASE with @ (`@stress_critical`)
- **Callbacks**: Prefixed with `handle_` (`handle_info`, `handle_call`)
- **Private Functions**: Prefixed with `defp`

---

## 12. Testing Patterns

### 12.1 Unit Test Pattern

```elixir
defmodule Indrajaal.Cortex.HomeostasisTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Cortex.Homeostasis

  describe "stress calculation" do
    test "returns 0.5 for default metrics" do
      metrics = %{memory_usage: 0.5, cpu_usage: 0.5, run_queue: 0}
      assert Homeostasis.calculate_stress(metrics) == 0.5
    end

    test "weights memory at 40%" do
      metrics = %{memory_usage: 1.0, cpu_usage: 0.0, run_queue: 0}
      assert Homeostasis.calculate_stress(metrics) == 0.4
    end
  end
end
```

### 12.2 Property-Based Test Pattern

```elixir
use ExUnitProperties

property "stress is always between 0 and 1" do
  check all memory <- float(min: 0.0, max: 1.0),
            cpu <- float(min: 0.0, max: 1.0),
            queue <- integer(0..200) do
    metrics = %{memory_usage: memory, cpu_usage: cpu, run_queue: queue}
    stress = Homeostasis.calculate_stress(metrics)
    assert stress >= 0.0 and stress <= 1.0
  end
end
```

---

## 13. Compliance Mapping

| STAMP Constraint | Implementation | File |
|------------------|----------------|------|
| SC-VAL-001 | Patient mode validation | safety_monitor.ex:45 |
| SC-VAL-003 | FPPS consensus check | fpps_validator.ex |
| SC-AGT-017 | Efficiency monitoring | agent_manager.ex:312 |
| SC-AGT-018 | Deadlock prevention | agent_manager.ex:445 |
| SC-CNT-009 | Container validation | safety_monitor.ex:67 |

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-19
**Author**: Claude Code (Opus 4.5)
**Framework**: SOPv5.11 + STAMP + TDG + GDE + CAFE
