# Level 4: Module Architecture

**Document Version**: 1.0.0
**Last Updated**: 2025-12-19
**C4 Model Level**: 4 - Module (Code)
**Framework**: SOPv5.11 + STAMP + TDG + OODA + Cybernetic

---

## 1. Overview

This document provides detailed module-level architecture for the Indrajaal system's core components. It focuses on GenServer implementations, state machines, supervision trees, and inter-module communication patterns.

### 1.1 Document Scope

| Aspect | Coverage |
|--------|----------|
| **Components Covered** | Cybernetic, Cortex, Coordination |
| **Module Count** | 32 primary modules |
| **Pattern Focus** | GenServer, Supervisor, State Machine |
| **Compliance** | STAMP SC-*, IEC 61508 SIL-2 |

### 1.2 Module Distribution

```
Indrajaal Module Architecture
├── Cybernetic Layer (14 modules)
│   ├── Framework Orchestrator (coordinator)
│   ├── OODA Subsystem (6 modules)
│   └── Intelligence Modules (7 modules)
├── Cortex Layer (11 modules)
│   ├── Controller (OODA engine)
│   ├── Homeostasis (autonomic)
│   ├── Sensors (5 modules)
│   └── Reflexes (1 module)
└── Coordination Layer (7 modules)
    ├── Agent Manager
    ├── Safety Monitor
    └── Support Modules (5 modules)
```

---

## 2. Cybernetic Layer Modules

### 2.1 Framework Orchestrator

**Path**: `lib/indrajaal/cybernetic/framework_orchestrator.ex`
**Type**: GenServer
**Role**: Master coordinator for all 7 cybernetic subsystems

#### 2.1.1 Module Structure

```elixir
defmodule Indrajaal.Cybernetic.FrameworkOrchestrator do
  use GenServer
  require Logger

  @default_orchestrator_config %{
    subsystem_coordination: %{
      parallel_execution: true,
      fault_tolerance: true,
      load_balancing: true
    },
    enterprise_features: %{
      high_availability: true,
      disaster_recovery: true,
      security_monitoring: true,
      compliance_tracking: true
    },
    performance_targets: %{
      max_response_time_ms: 1000,
      min_availability: 0.999,
      max_error_rate: 0.001
    },
    quality_gates: %{
      cybernetic_intelligence: 0.9,
      system_reliability: 0.95,
      methodology_compliance: 0.95
    }
  }
end
```

#### 2.1.2 State Structure

```elixir
%{
  subsystems: %{
    ooda: %{status: :running, last_cycle: DateTime.t()},
    cortex: %{status: :running, stress_level: float()},
    coordination: %{status: :running, agent_count: integer()},
    # ... 4 more subsystems
  },
  config: @default_orchestrator_config,
  metrics: %{
    uptime: integer(),
    cycles_completed: integer(),
    errors_handled: integer()
  },
  started_at: DateTime.t()
}
```

#### 2.1.3 Key Callbacks

| Callback | Purpose | Frequency |
|----------|---------|-----------|
| `handle_info(:coordinate_cycle, state)` | Subsystem coordination | Every 30s |
| `handle_call(:get_status, _, state)` | Status reporting | On-demand |
| `handle_cast({:subsystem_event, event}, state)` | Event processing | Async |

#### 2.1.4 Dependencies

```
FrameworkOrchestrator
├── Indrajaal.Cortex.Controller
├── Indrajaal.Coordination.AgentManager
├── Indrajaal.Coordination.SafetyMonitor
├── Indrajaal.Cybernetic.OODA.Loop
└── Indrajaal.Observability.OtelSDK
```

---

### 2.2 OODA Subsystem (6 Modules)

#### 2.2.1 OODA Loop State Machine

**Path**: `lib/indrajaal/cybernetic/ooda/loop.ex`
**Type**: GenServer (State Machine)
**Role**: Implements the Observe-Orient-Decide-Act cycle

```elixir
defmodule Indrajaal.Cybernetic.OODA.Loop do
  use GenServer
  require Logger

  @phase_timeout 5_000  # 5 seconds per phase max

  defstruct [
    :phase,        # :observe | :orient | :decide | :act
    :context,      # Current cycle context
    :start_time,   # Cycle start timestamp
    :cycle_count   # Total cycles completed
  ]
end
```

##### State Machine Transitions

```
┌─────────┐     data_collected     ┌─────────┐
│ OBSERVE │ ────────────────────▶ │ ORIENT  │
└─────────┘                        └─────────┘
     ▲                                  │
     │                                  │ analysis_complete
     │                                  ▼
     │                             ┌─────────┐
     │         cycle_complete      │ DECIDE  │
     │ ◀─────────────────────────  └─────────┘
     │              │                   │
     │              │                   │ confidence > 0.7
     │              │                   ▼
     │              │              ┌─────────┐
     │              └───────────── │   ACT   │
     │                             └─────────┘
     │                                  │
     │         confidence < 0.7        │
     └─────────────────────────────────┘
              (short-circuit)
```

##### Phase Implementation

```elixir
# Observe Phase - Data Collection
defp execute_observe(state) do
  observations = %{
    system: collect_system_metrics(),
    agents: collect_agent_status(),
    safety: collect_safety_status(),
    timestamp: DateTime.utc_now()
  }

  {:ok, %{state | context: Map.put(state.context, :observations, observations)}}
end

# Orient Phase - Analysis
defp execute_orient(state) do
  analysis = %{
    stress_level: calculate_stress(state.context.observations),
    anomalies: detect_anomalies(state.context.observations),
    trends: analyze_trends(state.context.observations)
  }

  {:ok, %{state | context: Map.put(state.context, :analysis, analysis)}}
end

# Decide Phase - Strategy Selection (with Quality Gate)
defp execute_decide(state) do
  decision = generate_decision(state.context.analysis)

  # Quality Gate: Confidence check
  if decision.confidence > 0.7 do
    schedule_next_phase(:act)
    {:ok, %{state | context: Map.put(state.context, :decision, decision)}}
  else
    Logger.info("OODA: Low confidence (#{decision.confidence}), skipping Action")
    schedule_next_phase(:observe)  # Short-circuit back to observe
    {:ok, state}
  end
end

# Act Phase - Execution
defp execute_act(state) do
  case execute_decision(state.context.decision) do
    {:ok, result} ->
      Logger.info("OODA: Action executed successfully")
      {:ok, %{state | cycle_count: state.cycle_count + 1}}
    {:error, reason} ->
      Logger.error("OODA: Action failed: #{inspect(reason)}")
      {:error, reason}
  end
end
```

#### 2.2.2 OODA Observer Module

**Path**: `lib/indrajaal/cybernetic/ooda/observer.ex`
**Role**: Data collection from all system sensors

```elixir
defmodule Indrajaal.Cybernetic.OODA.Observer do
  @moduledoc """
  OODA Observer - Collects and aggregates sensor data.

  STAMP Compliance: SC-OBS-001 (Complete observation coverage)
  """

  @sensors [
    Indrajaal.Cortex.Sensors.SystemSensor,
    Indrajaal.Cortex.Sensors.FLAMESensor,
    Indrajaal.Cortex.Sensors.MLSensor,
    Indrajaal.Cortex.Sensors.ContainerHealthSensor
  ]

  def collect_all do
    @sensors
    |> Task.async_stream(&safe_collect/1, timeout: 5_000)
    |> Enum.reduce(%{}, fn
      {:ok, {sensor, data}} -> Map.put(acc, sensor, data)
      {:exit, _} -> acc  # Skip failed sensors
    end)
  end
end
```

#### 2.2.3 OODA Orientator Module

**Path**: `lib/indrajaal/cybernetic/ooda/orientator.ex`
**Role**: Pattern recognition and situational analysis

```elixir
defmodule Indrajaal.Cybernetic.OODA.Orientator do
  @moduledoc """
  OODA Orientator - Analyzes observations for patterns and threats.

  Uses weighted stress calculation across multiple dimensions.
  """

  @stress_weights %{
    system: 0.35,
    flame: 0.25,
    ml: 0.20,
    container: 0.20
  }

  def analyze(observations) do
    %{
      stress_score: calculate_weighted_stress(observations),
      anomalies: detect_anomalies(observations),
      patterns: recognize_patterns(observations),
      recommendations: generate_recommendations(observations)
    }
  end
end
```

#### 2.2.4 OODA Decider Module

**Path**: `lib/indrajaal/cybernetic/ooda/decider.ex`
**Role**: Decision generation with confidence scoring

```elixir
defmodule Indrajaal.Cybernetic.OODA.Decider do
  @moduledoc """
  OODA Decider - Generates decisions based on analysis.

  Quality Gate: Decisions require confidence > 0.7
  STAMP: SC-VAL-003 (Consensus-based decision making)
  """

  @confidence_threshold 0.7

  defstruct [
    :action,
    :priority,
    :confidence,
    :rationale,
    :rollback_plan
  ]

  def decide(analysis) do
    decision = %__MODULE__{
      action: select_action(analysis),
      priority: calculate_priority(analysis),
      confidence: calculate_confidence(analysis),
      rationale: generate_rationale(analysis),
      rollback_plan: create_rollback_plan(analysis)
    }

    {:ok, decision}
  end
end
```

#### 2.2.5 OODA Actor Module

**Path**: `lib/indrajaal/cybernetic/ooda/actor.ex`
**Role**: Action execution with rollback capability

```elixir
defmodule Indrajaal.Cybernetic.OODA.Actor do
  @moduledoc """
  OODA Actor - Executes approved decisions.

  STAMP: SC-EMR-060 (Rollback capability maintained)
  """

  def execute(%{action: action, rollback_plan: rollback}) do
    with {:ok, pre_state} <- capture_state(),
         {:ok, result} <- perform_action(action),
         :ok <- verify_result(result) do
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Action failed, initiating rollback: #{reason}")
        execute_rollback(rollback)
        {:error, reason}
    end
  end
end
```

#### 2.2.6 OODA Telemetry Module

**Path**: `lib/indrajaal/cybernetic/ooda/telemetry.ex`
**Role**: OODA cycle metrics and observability

---

### 2.3 Intelligence Modules

#### 2.3.1 Goal-Oriented Intelligence

**Path**: `lib/indrajaal/cybernetic/goal_oriented_intelligence.ex`
**Type**: GenServer
**Role**: Hierarchical goal decomposition and optimization

```elixir
defmodule Indrajaal.Cybernetic.GoalOrientedIntelligence do
  @moduledoc """
  Implements Goal-Directed Evolution (GDE) algorithm.

  Multi-objective Pareto optimization for goal prioritization.
  """

  defstruct [
    :goal_hierarchy,    # Tree structure of goals
    :active_goals,      # Currently pursued goals
    :completed_goals,   # Historical completions
    :pareto_frontier    # Non-dominated solutions
  ]

  @optimization_objectives [:business_value, :urgency, :impact, :effort, :risk]
end
```

#### 2.3.2 Real-Time Decision Engine

**Path**: `lib/indrajaal/cybernetic/real_time_decision_engine.ex`
**Type**: GenServer
**Role**: Sub-100ms decision making for critical paths

```elixir
defmodule Indrajaal.Cybernetic.RealTimeDecisionEngine do
  @moduledoc """
  Fast-path decision engine for time-critical operations.

  Target latency: <100ms for critical decisions
  STAMP: SC-PRF-049 (Performance targets)
  """

  @critical_latency_ms 10
  @standard_latency_ms 100
  @strategic_latency_ms 1000
end
```

#### 2.3.3 Learning Adaptation

**Path**: `lib/indrajaal/cybernetic/learning_adaptation.ex`
**Type**: GenServer
**Role**: Pattern learning and strategy refinement

```elixir
defmodule Indrajaal.Cybernetic.LearningAdaptation do
  @moduledoc """
  Adaptive learning system with multiple algorithm support.

  Algorithms: Reinforcement, Transfer, Evolutionary, Swarm, Meta-Learning
  """

  @learning_algorithms [
    :reinforcement_learning,
    :transfer_learning,
    :evolutionary_algorithm,
    :swarm_intelligence,
    :meta_learning
  ]

  @memory_config %{
    short_term: %{capacity: 1000, decay: 0.9},
    long_term: %{capacity: 100_000, consolidation_threshold: 0.8},
    episodic: %{max_episodes: 10_000, retrieval: :similarity_based}
  }
end
```

---

## 3. Cortex Layer Modules

### 3.1 Cortex Controller (OODA Engine)

**Path**: `lib/indrajaal/cortex/controller.ex`
**Type**: GenServer
**Role**: Autonomic system management via OODA cycle

#### 3.1.1 Module Structure

```elixir
defmodule Indrajaal.Cortex.Controller do
  @moduledoc """
  Cortex Cognitive Controller - The OODA Loop Engine.

  Implements the Observe-Orient-Decide-Act cycle for autonomic system management.

  STAMP Compliance:
  - SC-CTX-004: OODA cycle bounded latency (<1000ms)
  - SC-CTX-005: Decision audit trail
  - SC-CTX-006: Action rollback capability
  """

  use GenServer
  require Logger
  require OpenTelemetry.Tracer, as: Tracer

  alias Indrajaal.Cortex.Sensors.{SystemSensor, FLAMESensor, MLSensor, ContainerHealthSensor}
  alias Indrajaal.Cortex.Reflexes.CircuitBreaker

  @ooda_interval :timer.seconds(30)
  @max_ooda_latency 1000  # ms

  # Thresholds for decision making
  @stress_critical 0.9
  @stress_high 0.7
  @stress_low 0.3
end
```

#### 3.1.2 State Structure

```elixir
state = %{
  # OODA state
  phase: :idle,
  last_observation: nil,
  last_orientation: nil,
  proposals: [],
  executed_actions: [],

  # Metrics
  cycle_count: 0,
  total_latency_ms: 0,
  decisions_made: 0,
  actions_executed: 0,

  # History
  stress_history: [],
  action_history: [],

  # Configuration
  auto_execute: false,  # Require approval by default
  started_at: DateTime.utc_now()
}
```

#### 3.1.3 OODA Cycle Implementation

```elixir
defp run_ooda_cycle(state) do
  start_time = System.monotonic_time(:millisecond)

  Tracer.with_span "cortex.ooda_cycle", kind: :internal do
    # OBSERVE
    observation = observe()
    Tracer.set_attribute("ooda.observation.sensors", length(Map.keys(observation)))

    # ORIENT
    orientation = orient(observation)
    Tracer.set_attribute("ooda.orientation.stress", orientation.stress_score)

    # DECIDE
    {decisions, proposals} = decide(orientation, state)
    Tracer.set_attribute("ooda.decisions.count", length(decisions))

    # ACT (if auto-execute enabled or reflexive)
    {executed, remaining_proposals} = act(proposals, state.auto_execute)
    Tracer.set_attribute("ooda.actions.executed", length(executed))

    latency = System.monotonic_time(:millisecond) - start_time

    # STAMP SC-CTX-004: Latency bound check
    if latency > @max_ooda_latency do
      Logger.warning("Cortex: OODA cycle exceeded latency bound: #{latency}ms")
    end

    # Update state
    %{state |
      phase: :idle,
      last_observation: observation,
      last_orientation: orientation,
      proposals: remaining_proposals,
      cycle_count: state.cycle_count + 1,
      total_latency_ms: state.total_latency_ms + latency
    }
  end
end
```

#### 3.1.4 Stress Calculation

```elixir
# Weighted stress calculation across all sensors
defp orient(observation) do
  system_stress = calculate_system_stress(observation.system)
  flame_stress = calculate_flame_stress(observation.flame)
  ml_stress = calculate_ml_stress(observation.ml)
  container_stress = calculate_container_stress(observation.container)

  # Weighted combination
  overall_stress =
    system_stress * 0.35 +
    flame_stress * 0.25 +
    ml_stress * 0.20 +
    container_stress * 0.20

  %{
    stress_score: Float.round(overall_stress, 3),
    component_stress: %{
      system: Float.round(system_stress, 3),
      flame: Float.round(flame_stress, 3),
      ml: Float.round(ml_stress, 3),
      container: Float.round(container_stress, 3)
    },
    anomalies: detect_anomalies(observation),
    circuit_breaker_issues: assess_circuit_breakers(observation.circuit_breakers)
  }
end
```

#### 3.1.5 Decision Logic

```elixir
defp decide(orientation, state) do
  stress = orientation.stress_score

  cond do
    stress > @stress_critical ->
      proposal = create_proposal(:emergency_scale_up, :critical, "Critical stress: #{stress}")
      {[:emergency_response], [proposal | state.proposals]}

    stress > @stress_high ->
      proposal = create_proposal(:scale_up, :high, "High stress: #{stress}")
      {[:scale_up_recommended], [proposal | state.proposals]}

    stress < @stress_low and not Enum.empty?(state.executed_actions) ->
      proposal = create_proposal(:scale_down, :low, "Low stress: #{stress}")
      {[:scale_down_recommended], [proposal | state.proposals]}

    true ->
      {[:maintain_current], state.proposals}
  end
end
```

---

### 3.2 Homeostasis Engine

**Path**: `lib/indrajaal/cortex/homeostasis.ex`
**Type**: GenServer
**Role**: Autonomic regulation maintaining system equilibrium

#### 3.2.1 Module Structure

```elixir
defmodule Indrajaal.Cortex.Homeostasis do
  @moduledoc """
  Homeostasis Engine - Maintains system equilibrium.

  Implements autonomic regulation with:
  - Stress level monitoring
  - Automatic adjustments
  - Self-healing capabilities

  STAMP Compliance:
  - SC-HOM-001: Stress bounds enforcement
  - SC-HOM-002: Minimum action interval
  - SC-HOM-003: Recovery protocols
  """

  use GenServer
  require Logger

  @check_interval :timer.seconds(30)
  @min_action_interval :timer.seconds(60)

  # Stress thresholds
  @stress_critical 0.9
  @stress_high 0.75
  @stress_optimal_high 0.6
  @stress_optimal_low 0.3
  @stress_low 0.2
end
```

#### 3.2.2 State Structure

```elixir
state = %{
  current_stress: 0.5,
  stress_history: [],
  last_action_time: nil,
  adjustments_made: 0,

  # Regulation state
  regulation_active: true,
  target_stress: 0.45,  # Optimal range midpoint

  # Metrics
  started_at: DateTime.utc_now(),
  recovery_count: 0
}
```

#### 3.2.3 Stress Response Logic

```elixir
defp assess_and_respond(state) do
  stress = state.current_stress

  cond do
    # Critical - Emergency response
    stress > @stress_critical ->
      Logger.error("Homeostasis: CRITICAL stress level #{stress}")
      trigger_emergency_response(state)

    # High - Scale up resources
    stress > @stress_high ->
      Logger.warning("Homeostasis: High stress level #{stress}")
      maybe_scale_up(state)

    # Optimal - Maintain
    stress >= @stress_optimal_low and stress <= @stress_optimal_high ->
      Logger.debug("Homeostasis: Optimal stress level #{stress}")
      state

    # Low - Scale down resources
    stress < @stress_low ->
      Logger.info("Homeostasis: Low stress level #{stress}")
      maybe_scale_down(state)

    true ->
      state
  end
end
```

---

### 3.3 Sensor Modules (5 Modules)

#### 3.3.1 System Sensor

**Path**: `lib/indrajaal/cortex/sensors/system_sensor.ex`
**Role**: System metrics collection (CPU, memory, processes)

```elixir
defmodule Indrajaal.Cortex.Sensors.SystemSensor do
  @moduledoc """
  System resource sensor for Cortex.

  Collects: CPU usage, memory usage, process count, run queue depth
  """

  def measure do
    %{
      memory_usage: calculate_memory_usage(),
      cpu_usage: calculate_cpu_usage(),
      process_count: :erlang.system_info(:process_count),
      run_queue: :erlang.statistics(:run_queue),
      atom_count: :erlang.system_info(:atom_count),
      port_count: :erlang.system_info(:port_count),
      timestamp: DateTime.utc_now()
    }
  end

  defp calculate_memory_usage do
    mem_data = :erlang.memory()
    total = mem_data[:total]
    system_total = :erlang.system_info(:allocated_areas)
    total / system_total  # Normalized 0.0-1.0
  end
end
```

#### 3.3.2 FLAME Sensor

**Path**: `lib/indrajaal/cortex/sensors/flame_sensor.ex`
**Role**: FLAME distributed compute pool metrics

```elixir
defmodule Indrajaal.Cortex.Sensors.FLAMESensor do
  @moduledoc """
  FLAME pool monitoring sensor.

  Tracks: Pool utilization, queue depth, runner health
  STAMP: SC-FLAME-001 to SC-FLAME-006
  """

  @flame_pools [:intelligence, :video, :analytics]

  def measure do
    pools = @flame_pools
    |> Enum.map(fn pool_name ->
      {pool_name, measure_pool(pool_name)}
    end)
    |> Enum.into(%{})

    %{
      pools: pools,
      total_runners: count_total_runners(pools),
      overall_utilization: calculate_overall_utilization(pools),
      timestamp: DateTime.utc_now()
    }
  end
end
```

#### 3.3.3 ML Sensor

**Path**: `lib/indrajaal/cortex/sensors/ml_sensor.ex`
**Role**: Machine learning inference metrics

```elixir
defmodule Indrajaal.Cortex.Sensors.MLSensor do
  @moduledoc """
  ML inference performance sensor.

  Tracks: Inference latency, model accuracy, batch throughput
  """

  def measure do
    %{
      avg_latency_ms: get_average_latency(),
      p95_latency_ms: get_p95_latency(),
      throughput_rps: get_throughput(),
      model_accuracy: get_accuracy_metrics(),
      cache_hit_rate: get_cache_stats(),
      timestamp: DateTime.utc_now()
    }
  end
end
```

#### 3.3.4 Container Health Sensor

**Path**: `lib/indrajaal/cortex/sensors/container_health_sensor.ex`
**Role**: Container health and STAMP compliance monitoring

```elixir
defmodule Indrajaal.Cortex.Sensors.ContainerHealthSensor do
  @moduledoc """
  Container health monitoring sensor.

  STAMP Compliance: SC-CNT-009 to SC-CNT-016
  Monitors: Container health, PHICS latency, STAMP compliance
  """

  @containers [:indrajaal_app, :indrajaal_db, :indrajaal_obs]

  def measure do
    %{
      healthy: all_containers_healthy?(),
      stamp_compliant: check_stamp_compliance(),
      phics_latency_ms: measure_phics_latency(),
      failure_rate: calculate_failure_rate(),
      container_statuses: get_container_statuses(),
      timestamp: DateTime.utc_now()
    }
  end

  defp check_stamp_compliance do
    # SC-CNT-009: NixOS container check
    # SC-CNT-010: localhost registry check
    # SC-CNT-011: PHICS <50ms check
    # SC-CNT-012: Rootless execution check
    true  # Actual implementation checks each constraint
  end
end
```

---

### 3.4 Reflex Module

#### 3.4.1 Circuit Breaker

**Path**: `lib/indrajaal/cortex/reflexes/circuit_breaker.ex`
**Role**: Automatic failure isolation and recovery

```elixir
defmodule Indrajaal.Cortex.Reflexes.CircuitBreaker do
  @moduledoc """
  Circuit breaker pattern for external service protection.

  States: :closed (normal), :open (failing), :half_open (testing)

  STAMP: SC-EMR-057 (Emergency response <5s)
  """

  use GenServer

  @failure_threshold 5
  @reset_timeout :timer.seconds(30)
  @half_open_max_calls 3

  defstruct [
    :name,
    :state,           # :closed | :open | :half_open
    :failure_count,
    :success_count,
    :last_failure,
    :last_success
  ]

  def call(name, func) do
    case get_state(name) do
      :closed -> execute_closed(name, func)
      :open -> {:error, :circuit_open}
      :half_open -> execute_half_open(name, func)
    end
  end

  def status do
    GenServer.call(__MODULE__, :get_all_statuses)
  end
end
```

---

## 4. Coordination Layer Modules

### 4.1 Agent Manager

**Path**: `lib/indrajaal/coordination/agent_manager.ex`
**Type**: GenServer
**Role**: Agent lifecycle management and coordination

#### 4.1.1 Module Structure

```elixir
defmodule Indrajaal.Coordination.AgentManager do
  @moduledoc """
  Agent Manager - Manages the lifecycle of all system agents.

  Responsibilities:
  - Agent spawning and termination
  - Health monitoring
  - Task assignment
  - Dynamic scaling

  STAMP Compliance:
  - SC-AGT-017: Agent efficiency >90%
  - SC-AGT-018: Deadlock prevention
  - SC-AGT-023: Failure detection
  """

  use GenServer
  require Logger

  @type agent_type :: :supervisor | :helper | :worker | :specialist
  @type agent_status :: :idle | :busy | :unhealthy | :terminated
  @type scaling_direction :: :up | :down | :maintain

  @health_check_interval :timer.seconds(30)
  @max_agents 100
  @min_agents 5
end
```

#### 4.1.2 State Structure

```elixir
state = %{
  agents: %{},  # agent_id => %Agent{}

  # Categorized agent sets
  by_type: %{
    supervisor: MapSet.new(),
    helper: MapSet.new(),
    worker: MapSet.new(),
    specialist: MapSet.new()
  },

  by_status: %{
    idle: MapSet.new(),
    busy: MapSet.new(),
    unhealthy: MapSet.new()
  },

  # Metrics
  total_spawned: 0,
  total_terminated: 0,
  tasks_completed: 0,

  # Configuration
  scaling_enabled: true,
  target_utilization: 0.75,

  started_at: DateTime.utc_now()
}
```

#### 4.1.3 Agent Record

```elixir
defmodule Indrajaal.Coordination.AgentManager.Agent do
  defstruct [
    :id,
    :type,
    :status,
    :pid,
    :current_task,
    :tasks_completed,
    :error_count,
    :last_health_check,
    :spawned_at
  ]
end
```

#### 4.1.4 Key Operations

```elixir
# Spawn a new agent
def spawn_agent(type, opts \\ []) do
  GenServer.call(__MODULE__, {:spawn_agent, type, opts})
end

# Assign task to available agent
def assign_task(task) do
  GenServer.call(__MODULE__, {:assign_task, task})
end

# Get agent status
def get_agent_status(agent_id) do
  GenServer.call(__MODULE__, {:get_status, agent_id})
end

# Scale agents
def scale(direction) when direction in [:up, :down, :maintain] do
  GenServer.cast(__MODULE__, {:scale, direction})
end
```

#### 4.1.5 Health Check Implementation

```elixir
defp perform_health_checks(state) do
  state.agents
  |> Enum.reduce(state, fn {agent_id, agent}, acc_state ->
    case check_agent_health(agent) do
      :healthy ->
        acc_state

      :unhealthy ->
        Logger.warning("Agent #{agent_id} unhealthy, marking for recovery")
        mark_unhealthy(acc_state, agent_id)

      :dead ->
        Logger.error("Agent #{agent_id} dead, initiating recovery")
        initiate_recovery(acc_state, agent_id)
    end
  end)
end
```

---

### 4.2 Safety Monitor

**Path**: `lib/indrajaal/coordination/safety_monitor.ex`
**Type**: GenServer
**Role**: STAMP-based safety constraint validation

#### 4.2.1 Module Structure

```elixir
defmodule Indrajaal.Coordination.SafetyMonitor do
  @moduledoc """
  Safety Monitor - STAMP-based safety constraint validation.

  Implements:
  - Continuous safety monitoring
  - Hazard detection
  - Emergency response coordination
  - Audit trail generation

  STAMP Compliance: All SC-* constraints
  IEC 61508: SIL-2 compliance
  """

  use GenServer
  require Logger

  @type safety_level :: :critical | :high | :medium | :low | :informational
  @type violation_type :: :constraint_violation | :hazard_detected |
                          :unsafe_state | :performance_degradation
  @type response_action :: :immediate_halt | :graceful_shutdown |
                           :warning_alert | :monitoring_increase

  @monitor_interval :timer.seconds(10)
end
```

#### 4.2.2 State Structure

```elixir
state = %{
  # Current safety status
  safety_status: :nominal,  # :nominal | :warning | :critical | :emergency

  # Active violations
  active_violations: [],

  # Constraint tracking
  constraints: load_stamp_constraints(),
  constraint_statuses: %{},  # constraint_id => :satisfied | :violated

  # Audit trail
  audit_log: [],

  # Metrics
  checks_performed: 0,
  violations_detected: 0,
  emergencies_triggered: 0,

  started_at: DateTime.utc_now()
}
```

#### 4.2.3 Safety Check Implementation

```elixir
defp perform_safety_checks(state) do
  state.constraints
  |> Enum.reduce({state, []}, fn constraint, {acc_state, violations} ->
    case check_constraint(constraint) do
      :satisfied ->
        {update_constraint_status(acc_state, constraint.id, :satisfied), violations}

      {:violated, reason} ->
        violation = create_violation(constraint, reason)
        Logger.warning("STAMP violation: #{constraint.id} - #{reason}")
        {
          update_constraint_status(acc_state, constraint.id, :violated),
          [violation | violations]
        }
    end
  end)
  |> handle_violations()
end
```

#### 4.2.4 Response Actions

```elixir
defp handle_violation(%{level: :critical} = violation, state) do
  Logger.error("CRITICAL safety violation: #{violation.constraint_id}")

  # STAMP SC-EMR-057: Emergency response <5s
  response = %{
    action: :immediate_halt,
    violation: violation,
    timestamp: DateTime.utc_now()
  }

  # Trigger emergency shutdown
  Indrajaal.Emergency.trigger_emergency(violation)

  %{state |
    safety_status: :emergency,
    active_violations: [violation | state.active_violations],
    emergencies_triggered: state.emergencies_triggered + 1
  }
end

defp handle_violation(%{level: :high} = violation, state) do
  Logger.warning("HIGH safety violation: #{violation.constraint_id}")

  # Graceful degradation
  response = %{
    action: :graceful_shutdown,
    violation: violation,
    timestamp: DateTime.utc_now()
  }

  %{state |
    safety_status: :critical,
    active_violations: [violation | state.active_violations]
  }
end
```

---

### 4.3 Load Balancer

**Path**: `lib/indrajaal/coordination/load_balancer.ex`
**Type**: GenServer
**Role**: Work distribution across agents

```elixir
defmodule Indrajaal.Coordination.LoadBalancer do
  @moduledoc """
  Load Balancer - Distributes work across available agents.

  Strategies:
  - Round-robin
  - Least-connections
  - Weighted
  - Adaptive (based on agent performance)

  STAMP: SC-AGT-024 (Load balancing maintenance)
  """

  use GenServer

  @strategies [:round_robin, :least_connections, :weighted, :adaptive]
  @default_strategy :adaptive

  defstruct [
    :strategy,
    :agent_weights,
    :connection_counts,
    :performance_scores,
    :last_assigned
  ]
end
```

---

### 4.4 Advanced Multi-Agent Coordinator

**Path**: `lib/indrajaal/coordination/advanced_multi_agent_coordinator.ex`
**Type**: GenServer
**Role**: Complex multi-agent task orchestration

```elixir
defmodule Indrajaal.Coordination.AdvancedMultiAgentCoordinator do
  @moduledoc """
  Advanced Multi-Agent Coordinator - Orchestrates complex multi-agent workflows.

  Features:
  - Task decomposition
  - Parallel execution
  - Dependency resolution
  - Failure handling

  STAMP: SC-AGT-017 to SC-AGT-024
  """

  use GenServer

  defstruct [
    :workflows,         # Active workflows
    :task_graph,        # DAG of task dependencies
    :agent_assignments, # task_id => agent_id mapping
    :completion_status  # task_id => :pending | :running | :completed | :failed
  ]
end
```

---

### 4.5 Support Modules

#### 4.5.1 Reliability Monitor

**Path**: `lib/indrajaal/coordination/reliability_monitor.ex`
**Role**: System reliability metrics and SLA tracking

#### 4.5.2 Performance Optimizer

**Path**: `lib/indrajaal/coordination/performance_optimizer.ex`
**Role**: Performance tuning recommendations

#### 4.5.3 Cybernetic Controller

**Path**: `lib/indrajaal/coordination/cybernetic_controller.ex`
**Role**: Coordination-layer cybernetic control

---

## 5. Inter-Module Communication

### 5.1 Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        MESSAGE FLOW ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────┐         ┌──────────────────┐                      │
│  │   Framework      │ ◀─────▶ │     Cortex       │                      │
│  │   Orchestrator   │         │    Controller    │                      │
│  └────────┬─────────┘         └────────┬─────────┘                      │
│           │                            │                                 │
│           │ coordinate                 │ observe                         │
│           ▼                            ▼                                 │
│  ┌──────────────────┐         ┌──────────────────┐                      │
│  │   Agent          │ ◀─────▶ │    Homeostasis   │                      │
│  │   Manager        │         │     Engine       │                      │
│  └────────┬─────────┘         └────────┬─────────┘                      │
│           │                            │                                 │
│           │ assign_task                │ adjust_resources                │
│           ▼                            ▼                                 │
│  ┌──────────────────┐         ┌──────────────────┐                      │
│  │   Load           │ ◀─────▶ │    Safety        │                      │
│  │   Balancer       │         │    Monitor       │                      │
│  └──────────────────┘         └──────────────────┘                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Communication Patterns

| Source | Target | Pattern | Message Type |
|--------|--------|---------|--------------|
| Orchestrator | Controller | GenServer.call | `:get_status` |
| Controller | Sensors | Direct call | `sensor.measure()` |
| Controller | Homeostasis | GenServer.cast | `{:stress_update, level}` |
| AgentManager | LoadBalancer | GenServer.call | `{:get_assignment, task}` |
| SafetyMonitor | All | PubSub broadcast | `{:safety_alert, violation}` |
| Homeostasis | AgentManager | GenServer.cast | `{:scale, direction}` |

### 5.3 PubSub Topics

```elixir
# Safety events
Phoenix.PubSub.broadcast(Indrajaal.PubSub, "safety:violations", {:violation, v})
Phoenix.PubSub.broadcast(Indrajaal.PubSub, "safety:emergencies", {:emergency, e})

# System events
Phoenix.PubSub.broadcast(Indrajaal.PubSub, "system:stress", {:stress_update, level})
Phoenix.PubSub.broadcast(Indrajaal.PubSub, "system:metrics", {:metrics, data})

# Agent events
Phoenix.PubSub.broadcast(Indrajaal.PubSub, "agents:spawned", {:spawned, agent})
Phoenix.PubSub.broadcast(Indrajaal.PubSub, "agents:terminated", {:terminated, id})
```

---

## 6. Supervision Trees

### 6.1 Cortex Supervision Tree

```elixir
defmodule Indrajaal.Cortex.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Core controller
      {Indrajaal.Cortex.Controller, []},

      # Homeostasis engine
      {Indrajaal.Cortex.Homeostasis, []},

      # Sensor supervisor
      {Indrajaal.Cortex.Sensors.Supervisor, []},

      # Circuit breaker
      {Indrajaal.Cortex.Reflexes.CircuitBreaker, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 6.2 Coordination Supervision Tree

```elixir
defmodule Indrajaal.Coordination.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Safety monitor (started first for safety)
      {Indrajaal.Coordination.SafetyMonitor, []},

      # Agent management
      {Indrajaal.Coordination.AgentManager, []},

      # Load balancing
      {Indrajaal.Coordination.LoadBalancer, []},

      # Advanced coordinator
      {Indrajaal.Coordination.AdvancedMultiAgentCoordinator, []},

      # Performance optimization
      {Indrajaal.Coordination.PerformanceOptimizer, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
```

---

## 7. STAMP Constraint Mapping

### 7.1 Module-to-Constraint Matrix

| Module | Primary Constraints | Enforcement Mechanism |
|--------|--------------------|-----------------------|
| Cortex.Controller | SC-CTX-004, SC-CTX-005, SC-CTX-006 | Latency monitoring, audit logging, rollback |
| Homeostasis | SC-HOM-001, SC-HOM-002, SC-HOM-003 | Stress bounds, action intervals, recovery |
| SafetyMonitor | All SC-* | Continuous monitoring |
| AgentManager | SC-AGT-017, SC-AGT-018, SC-AGT-023 | Efficiency tracking, deadlock prevention |
| CircuitBreaker | SC-EMR-057 | <5s response time |
| ContainerHealthSensor | SC-CNT-009 to SC-CNT-016 | Container compliance checks |

### 7.2 Constraint Verification Points

```elixir
# SC-CTX-004: OODA latency check
if latency > @max_ooda_latency do
  Logger.warning("STAMP SC-CTX-004: Latency bound exceeded")
  emit_violation(:constraint_violation, "SC-CTX-004", latency)
end

# SC-AGT-017: Agent efficiency check
efficiency = calculate_efficiency(state)
if efficiency < 0.90 do
  Logger.warning("STAMP SC-AGT-017: Agent efficiency below threshold")
  emit_violation(:performance_degradation, "SC-AGT-017", efficiency)
end

# SC-CNT-011: PHICS latency check
phics_latency = measure_phics_latency()
if phics_latency >= 50 do
  Logger.warning("STAMP SC-CNT-011: PHICS latency exceeded")
  emit_violation(:constraint_violation, "SC-CNT-011", phics_latency)
end
```

---

## 8. Module Dependencies

### 8.1 Dependency Graph

```
                    ┌─────────────────────────┐
                    │  FrameworkOrchestrator  │
                    └───────────┬─────────────┘
                                │
           ┌────────────────────┼────────────────────┐
           │                    │                    │
           ▼                    ▼                    ▼
   ┌───────────────┐    ┌─────────────┐    ┌──────────────┐
   │ OODA.Loop     │    │ Cortex.     │    │ Agent        │
   │               │    │ Controller  │    │ Manager      │
   └───────┬───────┘    └──────┬──────┘    └──────┬───────┘
           │                   │                  │
           │                   ▼                  │
           │           ┌─────────────┐            │
           │           │ Homeostasis │            │
           │           └──────┬──────┘            │
           │                  │                   │
           └──────────────────┼───────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  SafetyMonitor  │
                    └─────────────────┘
```

### 8.2 Circular Dependency Prevention

The module architecture follows these rules to prevent circular dependencies:

1. **Downward-only calls**: Higher-level modules call lower-level modules
2. **PubSub for upward communication**: Lower modules publish events
3. **Contracts via behaviours**: Interface definitions prevent coupling
4. **Dependency injection**: Dependencies passed via `start_link/1` options

---

## 9. Testing Patterns

### 9.1 GenServer Testing

```elixir
defmodule Indrajaal.Cortex.ControllerTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = Indrajaal.Cortex.Controller.start_link([])
    %{pid: pid}
  end

  test "OODA cycle completes within latency bound", %{pid: pid} do
    # Trigger cycle
    :ok = GenServer.cast(pid, :trigger_cycle)

    # Wait for completion
    Process.sleep(1500)

    # Check metrics
    metrics = Indrajaal.Cortex.Controller.metrics()
    assert metrics.avg_latency_ms < 1000  # SC-CTX-004
  end

  test "stress thresholds trigger appropriate responses", %{pid: pid} do
    # Inject high stress
    send(pid, {:inject_stress, 0.85})

    # Check proposals generated
    proposals = Indrajaal.Cortex.Controller.get_proposals()
    assert Enum.any?(proposals, &(&1.action == :scale_up))
  end
end
```

### 9.2 State Machine Testing

```elixir
defmodule Indrajaal.Cybernetic.OODA.LoopTest do
  use ExUnit.Case, async: true

  test "phase transitions follow valid sequence" do
    {:ok, pid} = Indrajaal.Cybernetic.OODA.Loop.start_link([])

    # Start in observe
    assert get_phase(pid) == :observe

    # Transition through phases
    trigger_phase_complete(pid)
    assert get_phase(pid) == :orient

    trigger_phase_complete(pid)
    assert get_phase(pid) == :decide

    # With high confidence, goes to act
    set_confidence(pid, 0.9)
    trigger_phase_complete(pid)
    assert get_phase(pid) == :act

    # Cycles back to observe
    trigger_phase_complete(pid)
    assert get_phase(pid) == :observe
  end

  test "low confidence short-circuits to observe" do
    {:ok, pid} = Indrajaal.Cybernetic.OODA.Loop.start_link([])

    # Get to decide phase
    advance_to_phase(pid, :decide)

    # Set low confidence
    set_confidence(pid, 0.5)
    trigger_phase_complete(pid)

    # Should skip act, go to observe
    assert get_phase(pid) == :observe
  end
end
```

---

## 10. Performance Considerations

### 10.1 Critical Paths

| Path | Target Latency | Modules Involved |
|------|---------------|------------------|
| OODA Cycle | <1000ms | Controller, Sensors, Homeostasis |
| Safety Check | <10ms | SafetyMonitor |
| Agent Assignment | <50ms | AgentManager, LoadBalancer |
| Emergency Response | <5s | SafetyMonitor, CircuitBreaker |

### 10.2 Optimization Strategies

1. **Async sensor collection**: Parallel Task.async_stream for sensors
2. **ETS caching**: Frequently accessed data cached in ETS
3. **GenServer timeouts**: All calls have explicit timeouts
4. **Circuit breaker protection**: External calls protected

```elixir
# Parallel sensor collection
defp observe do
  sensors = [SystemSensor, FLAMESensor, MLSensor, ContainerHealthSensor]

  sensors
  |> Task.async_stream(&safe_measure/1, max_concurrency: 4, timeout: 2_000)
  |> Enum.reduce(%{}, fn
    {:ok, {sensor, data}} -> Map.put(acc, sensor, data)
    _ -> acc
  end)
end
```

---

## 11. References

### 11.1 Related Documents

- [Level 3: Component Architecture](level-3-component-architecture.md)
- [Level 5: Code-Level Architecture](level-5-code-level-architecture.md)
- [STAMP Safety Constraints](../formal_specs/stamp_constraints.md)
- [CLAUDE.md](../../CLAUDE.md) - System specification

### 11.2 Module File Locations

| Module | Path |
|--------|------|
| Framework Orchestrator | `lib/indrajaal/cybernetic/framework_orchestrator.ex` |
| OODA Loop | `lib/indrajaal/cybernetic/ooda/loop.ex` |
| Cortex Controller | `lib/indrajaal/cortex/controller.ex` |
| Homeostasis | `lib/indrajaal/cortex/homeostasis.ex` |
| Agent Manager | `lib/indrajaal/coordination/agent_manager.ex` |
| Safety Monitor | `lib/indrajaal/coordination/safety_monitor.ex` |
| Load Balancer | `lib/indrajaal/coordination/load_balancer.ex` |

---

**Document Generated**: 2025-12-19
**Framework Compliance**: SOPv5.11 + STAMP + TDG
**STAMP Constraints Mapped**: 25+
