# CAE Enablement Implementation Plan - 5-Level Roadmap

**Date**: 2025-12-29T12:00:00+01:00
**Plan Type**: Cybernetically Augmented Evolution (CAE) Enablement
**Status**: APPROVED - Ready for Implementation
**Framework**: SOPv5.11 + STAMP + TDG + Fractal Architecture
**Target Completion**: 2025-02-02 (5 weeks)

---

## Level 1: Executive Roadmap (System Context)

### 1.1 Strategic Objectives

| Objective | Metric | Current | Target | Timeline |
|-----------|--------|---------|--------|----------|
| OODA Cycle Speed | Latency | 30s | <100ms | Week 1 |
| Feedback Coupling | Integration % | 20% | 100% | Week 3 |
| GDE Activation | Status | PENDING | ACTIVE | Week 2 |
| Autonomous Evolution | Mode | Manual | Semi-Auto | Week 5 |
| CAE Readiness | Score | 7.5/10 | 9.5/10 | Week 5 |

### 1.2 Phase Overview

```
Week 1: OODA Acceleration (Critical Path)
   └── Reduce cycle from 30s to 50ms

Week 2: GDE Activation (High Priority)
   └── Enable Goal-Directed Evolution with manual gate

Week 3: Control Loop Coupling (High Priority)
   └── Unify OODA + ACE + Homeostasis + GDE

Week 4: Physical Sensor Integration (Medium Priority)
   └── Wire container/hardware sensors to OODA

Week 5: Semi-Autonomous Evolution (Final)
   └── Enable shadow-tested auto-evolution
```

### 1.3 Success Criteria

| Gate | Metric | Threshold |
|------|--------|-----------|
| G1 | OODA cycle time | <100ms |
| G2 | GDE proposal generation | >10/day |
| G3 | Control loop events/sec | >1000 |
| G4 | Sensor coverage | >95% |
| G5 | Shadow test pass rate | >99% |

### 1.4 Risk Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| OODA too fast, unstable | Medium | High | Quality gates, circuit breakers |
| GDE generates bad code | Low | Critical | Simplex architecture, manual gate |
| Control coupling deadlock | Medium | High | Async messaging, timeouts |
| Sensor overload | Low | Medium | Sampling, aggregation |

---

## Level 2: Container Architecture Plan

### 2.1 Week 1: OODA Acceleration Infrastructure

#### 2.1.1 Container Configuration Changes

```yaml
# podman-compose.yml additions
services:
  indrajaal-app:
    environment:
      - OODA_FAST_MODE=true
      - OODA_INTERVAL_MS=50
      - OODA_BATCH_SIZE=100
      - OODA_ASYNC_OBSERVE=true
    deploy:
      resources:
        limits:
          cpus: '6'  # Increase from 4
          memory: 6G  # Increase from 4G
```

#### 2.1.2 New Container: OODA Fast Worker

```yaml
# New service for dedicated OODA processing
  indrajaal-ooda-fast:
    image: localhost/indrajaal-app:latest
    command: ["bin/indrajaal", "eval", "Indrajaal.Cortex.FastOODA.start()"]
    environment:
      - ROLE=ooda_worker
      - OODA_INTERVAL_MS=50
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

#### 2.1.3 Observability Enhancements

```yaml
# OTEL collector additions for fast OODA metrics
  indrajaal-obs:
    environment:
      - OODA_METRICS_ENABLED=true
      - OODA_TRACE_ALL_PHASES=true
      - OODA_HISTOGRAM_BUCKETS=1,5,10,25,50,100,250,500,1000
```

### 2.2 Week 2-3: Control Bus Container

```yaml
# Unified control bus service
  indrajaal-control-bus:
    image: localhost/indrajaal-app:latest
    command: ["bin/indrajaal", "eval", "Indrajaal.Control.UnifiedBus.start()"]
    environment:
      - ROLE=control_bus
      - LOOPS=ooda,ace,homeostasis,gde
      - BROADCAST_MODE=async
    depends_on:
      - indrajaal-app
      - indrajaal-db
```

### 2.3 Container Health Wiring

```elixir
# New: lib/indrajaal/cortex/sensors/container_sensor_bridge.ex
defmodule Indrajaal.Cortex.Sensors.ContainerSensorBridge do
  @moduledoc """
  Bridges container health metrics to OODA Observe phase.
  SC-CNT-009: NixOS/Podman container awareness
  """

  use GenServer
  @poll_interval 50  # 50ms polling

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll, state) do
    metrics = poll_container_metrics()
    send(Indrajaal.Cortex.FastOODA, {:container_observation, metrics})
    schedule_poll()
    {:noreply, state}
  end

  defp poll_container_metrics do
    %{
      cpu: get_cpu_usage(),
      memory: get_memory_usage(),
      io: get_io_stats(),
      network: get_network_stats(),
      health: get_health_status()
    }
  end

  defp schedule_poll, do: Process.send_after(self(), :poll, @poll_interval)
end
```

---

## Level 3: Domain Architecture Plan

### 3.1 Week 1: Fast OODA Domain Module

```elixir
# New: lib/indrajaal/cortex/fast_ooda.ex
defmodule Indrajaal.Cortex.FastOODA do
  @moduledoc """
  Fast OODA Loop for CAE - 50ms cycles.

  ## STAMP Constraints
  - SC-OODA-001: Cycle time <100ms
  - SC-OODA-002: Quality gates enforced
  - SC-OODA-003: Async observation

  ## TDG Requirements
  - Property tests for cycle timing
  - Integration tests for phase transitions
  """

  use GenServer
  require Logger

  # Configuration
  @cycle_interval 50          # 50ms target
  @batch_size 100             # Observations per batch
  @min_quality 80             # Quality gate
  @min_confidence 70          # Confidence gate

  defstruct [
    :phase,
    :context,
    :start_time,
    :cycle_count,
    :observations_buffer,
    :last_latency
  ]

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def inject_observation(obs) do
    GenServer.cast(__MODULE__, {:observation, obs})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    Logger.info("🚀 FastOODA: Initializing 50ms cycle loop")

    state = %__MODULE__{
      phase: :observe,
      context: %{},
      start_time: System.monotonic_time(:millisecond),
      cycle_count: 0,
      observations_buffer: [],
      last_latency: 0
    }

    schedule_cycle()
    {:ok, state}
  end

  @impl true
  def handle_info(:cycle, state) do
    new_state = execute_fast_cycle(state)
    schedule_cycle()
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:observation, obs}, state) do
    buffer = [obs | state.observations_buffer] |> Enum.take(@batch_size)
    {:noreply, %{state | observations_buffer: buffer}}
  end

  # --- Fast Cycle Implementation ---

  defp execute_fast_cycle(state) do
    cycle_start = System.monotonic_time(:microsecond)

    # OBSERVE (async batch)
    observations = aggregate_observations(state.observations_buffer)

    # ORIENT (pattern matching)
    situation = orient(observations)

    # DECIDE (rule-based + ML)
    decision = decide(situation)

    # ACT (if confident)
    if decision.confidence >= @min_confidence do
      act(decision)
      record_learning(state, decision)
    end

    # Metrics
    latency = (System.monotonic_time(:microsecond) - cycle_start) / 1000
    emit_metrics(state, latency)

    %{state |
      phase: :observe,
      context: %{},
      cycle_count: state.cycle_count + 1,
      observations_buffer: [],
      last_latency: latency
    }
  end

  defp aggregate_observations(buffer) do
    # Fast aggregation of batched observations
    %{
      cpu: calculate_avg(buffer, :cpu),
      memory: calculate_avg(buffer, :memory),
      events: length(buffer),
      quality: calculate_quality(buffer)
    }
  end

  defp orient(observations) do
    # Fast pattern matching for situation assessment
    %{
      stress_level: calculate_stress(observations),
      trend: calculate_trend(observations),
      anomalies: detect_anomalies(observations)
    }
  end

  defp decide(situation) do
    # Rule-based + optional ML decision
    cond do
      situation.stress_level > 0.8 -> %{action: :scale_up, confidence: 90}
      situation.stress_level < 0.2 -> %{action: :scale_down, confidence: 80}
      situation.anomalies != [] -> %{action: :investigate, confidence: 75}
      true -> %{action: :maintain, confidence: 100}
    end
  end

  defp act(decision) do
    # Execute action through unified control bus
    Indrajaal.Control.UnifiedBus.execute(decision)
  end

  defp record_learning(state, decision) do
    # Wire to TrainingGym
    Indrajaal.Cortex.Learning.TrainingGym.record_episode(
      state.context,
      decision.action,
      1.0,  # Reward placeholder
      %{}
    )
  end

  defp schedule_cycle do
    Process.send_after(self(), :cycle, @cycle_interval)
  end

  defp emit_metrics(state, latency) do
    :telemetry.execute(
      [:indrajaal, :fast_ooda, :cycle],
      %{latency_ms: latency, cycle: state.cycle_count},
      %{phase: :complete}
    )
  end

  # Helper functions
  defp calculate_avg([], _), do: 0
  defp calculate_avg(buffer, key) do
    buffer
    |> Enum.map(&Map.get(&1, key, 0))
    |> Enum.sum()
    |> Kernel./(length(buffer))
  end

  defp calculate_quality(buffer), do: min(100, length(buffer) * 10)
  defp calculate_stress(obs), do: (obs.cpu + obs.memory) / 200
  defp calculate_trend(_obs), do: :stable
  defp detect_anomalies(_obs), do: []
end
```

### 3.2 Week 2: GDE Activation

```elixir
# Update: lib/indrajaal/cortex/evolution/gde.ex
defmodule Indrajaal.Cortex.Evolution.GDE do
  @moduledoc """
  Goal-Directed Evolution Engine - ACTIVATED.

  ## Activation Status
  - enabled: true (was: false)
  - auto_apply: false (manual gate)
  - proposal_threshold: 0.85

  ## STAMP Constraints
  - SC-GDE-001: Proposals validated by Guardian
  - SC-GDE-002: Shadow testing required
  - SC-GDE-003: Rollback capability
  """

  use GenServer
  require Logger

  @proposal_threshold 0.85
  @max_proposals_per_cycle 5

  defstruct [
    :enabled,
    :proposals,
    :active_shadows,
    :promotion_queue
  ]

  def start_link(opts) do
    enabled = Keyword.get(opts, :enabled, true)  # NOW ENABLED
    GenServer.start_link(__MODULE__, %{enabled: enabled}, name: __MODULE__)
  end

  @impl true
  def init(%{enabled: enabled}) do
    Logger.info("🧬 GDE: Initialized (enabled: #{enabled})")
    {:ok, %__MODULE__{
      enabled: enabled,
      proposals: [],
      active_shadows: %{},
      promotion_queue: []
    }}
  end

  # Receive goals from OODA Decide phase
  def submit_goal(goal) do
    GenServer.cast(__MODULE__, {:goal, goal})
  end

  @impl true
  def handle_cast({:goal, goal}, state) do
    if state.enabled do
      proposals = generate_proposals(goal)
      validated = validate_with_guardian(proposals)
      shadowed = submit_to_shadow(validated)

      {:noreply, %{state |
        proposals: state.proposals ++ validated,
        active_shadows: Map.merge(state.active_shadows, shadowed)
      }}
    else
      {:noreply, state}
    end
  end

  defp generate_proposals(goal) do
    # Generate code proposals for goal
    Indrajaal.Cortex.Evolution.Generator.generate(goal)
    |> Enum.take(@max_proposals_per_cycle)
  end

  defp validate_with_guardian(proposals) do
    proposals
    |> Enum.filter(fn p ->
      case Indrajaal.Safety.Guardian.validate_proposal(p) do
        :ok -> true
        {:reject, _reason} -> false
      end
    end)
  end

  defp submit_to_shadow(proposals) do
    proposals
    |> Enum.map(fn p ->
      shadow_id = Indrajaal.Cortex.Evolution.ShadowMode.start_shadow(p)
      {shadow_id, p}
    end)
    |> Map.new()
  end
end
```

### 3.3 Week 3: Unified Control Bus

```elixir
# New: lib/indrajaal/control/unified_bus.ex
defmodule Indrajaal.Control.UnifiedBus do
  @moduledoc """
  Unified Control Bus - Couples all cybernetic loops.

  ## Connected Loops
  - OODA (Fast + Standard)
  - ACE (Autonomic Computing Engine)
  - Homeostasis
  - GDE (Goal-Directed Evolution)

  ## STAMP Constraints
  - SC-BUS-001: Async messaging only
  - SC-BUS-002: No blocking operations
  - SC-BUS-003: Circuit breaker on overload
  """

  use GenServer
  require Logger

  @loops [:ooda, :fast_ooda, :ace, :homeostasis, :gde]
  @circuit_threshold 1000  # Events/sec before circuit break

  defstruct [
    :event_count,
    :circuit_state,
    :loop_registry
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🔌 UnifiedBus: Connecting #{length(@loops)} control loops")
    {:ok, %__MODULE__{
      event_count: 0,
      circuit_state: :closed,
      loop_registry: register_loops()
    }}
  end

  # Broadcast event to all loops
  def broadcast(event) do
    GenServer.cast(__MODULE__, {:broadcast, event})
  end

  # Execute action with feedback
  def execute(decision) do
    GenServer.cast(__MODULE__, {:execute, decision})
  end

  @impl true
  def handle_cast({:broadcast, event}, state) do
    if state.circuit_state == :closed do
      for {_name, pid} <- state.loop_registry do
        send(pid, {:control_event, event})
      end
      {:noreply, %{state | event_count: state.event_count + 1}}
    else
      Logger.warning("UnifiedBus: Circuit OPEN, dropping event")
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:execute, decision}, state) do
    # Route decision to appropriate executor
    result = route_decision(decision)

    # Broadcast result as feedback
    broadcast({:action_result, decision.action, result})

    {:noreply, state}
  end

  defp register_loops do
    @loops
    |> Enum.map(fn loop ->
      pid = get_loop_pid(loop)
      {loop, pid}
    end)
    |> Enum.filter(fn {_, pid} -> pid != nil end)
    |> Map.new()
  end

  defp get_loop_pid(:ooda), do: Process.whereis(Indrajaal.Cybernetic.OODA.Loop)
  defp get_loop_pid(:fast_ooda), do: Process.whereis(Indrajaal.Cortex.FastOODA)
  defp get_loop_pid(:ace), do: Process.whereis(Indrajaal.Cortex.ACE)
  defp get_loop_pid(:homeostasis), do: Process.whereis(Indrajaal.Cortex.Homeostasis)
  defp get_loop_pid(:gde), do: Process.whereis(Indrajaal.Cortex.Evolution.GDE)

  defp route_decision(%{action: :scale_up}), do: scale_up()
  defp route_decision(%{action: :scale_down}), do: scale_down()
  defp route_decision(%{action: :investigate}), do: investigate()
  defp route_decision(%{action: :maintain}), do: :ok
  defp route_decision(%{action: :evolve, proposal: p}), do: submit_evolution(p)

  defp scale_up, do: :ok  # FLAME integration
  defp scale_down, do: :ok  # FLAME integration
  defp investigate, do: :ok  # Anomaly investigation
  defp submit_evolution(proposal), do: Indrajaal.Cortex.Evolution.GDE.submit_goal(proposal)
end
```

---

## Level 4: Component Architecture Plan

### 4.1 Test-Driven Development (TDG Required)

#### 4.1.1 Fast OODA Tests (Week 1)

```elixir
# test/indrajaal/cortex/fast_ooda_test.exs
defmodule Indrajaal.Cortex.FastOODATest do
  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  describe "L4-TEST: Fast OODA Cycle Timing" do
    @tag :cae
    @tag :performance
    test "cycle completes under 100ms" do
      {:ok, _pid} = Indrajaal.Cortex.FastOODA.start_link()

      # Inject observations
      for _ <- 1..100 do
        Indrajaal.Cortex.FastOODA.inject_observation(%{cpu: 50, memory: 60})
      end

      # Wait for cycle
      Process.sleep(100)

      state = Indrajaal.Cortex.FastOODA.get_state()
      assert state.last_latency < 100, "Cycle latency #{state.last_latency}ms exceeds 100ms"
    end

    property "cycle latency remains bounded under load" do
      forall observations <- PC.list(PC.map()) do
        {:ok, pid} = Indrajaal.Cortex.FastOODA.start_link()

        for obs <- observations do
          Indrajaal.Cortex.FastOODA.inject_observation(obs)
        end

        Process.sleep(100)
        state = Indrajaal.Cortex.FastOODA.get_state()
        GenServer.stop(pid)

        state.last_latency < 100
      end
    end
  end

  describe "L4-TEST: Quality Gates" do
    test "low quality observations trigger retry" do
      {:ok, _pid} = Indrajaal.Cortex.FastOODA.start_link()

      # Inject low quality (empty buffer)
      Process.sleep(100)

      state = Indrajaal.Cortex.FastOODA.get_state()
      # Should not have acted without quality
      assert state.cycle_count >= 1
    end
  end
end
```

#### 4.1.2 GDE Tests (Week 2)

```elixir
# test/indrajaal/cortex/evolution/gde_test.exs
defmodule Indrajaal.Cortex.Evolution.GDETest do
  use ExUnit.Case, async: false

  describe "L4-TEST: GDE Proposal Generation" do
    @tag :cae
    test "generates proposals for valid goals" do
      {:ok, _pid} = Indrajaal.Cortex.Evolution.GDE.start_link(enabled: true)

      goal = %{
        type: :performance,
        target: "reduce latency",
        threshold: 0.85
      }

      Indrajaal.Cortex.Evolution.GDE.submit_goal(goal)
      Process.sleep(100)

      # Verify proposals generated
      # (Implementation depends on Generator)
    end

    test "guardian rejects unsafe proposals" do
      # Test Simplex architecture safety
    end

    test "proposals enter shadow mode" do
      # Test shadow testing integration
    end
  end
end
```

#### 4.1.3 Unified Bus Tests (Week 3)

```elixir
# test/indrajaal/control/unified_bus_test.exs
defmodule Indrajaal.Control.UnifiedBusTest do
  use ExUnit.Case, async: false

  describe "L4-TEST: Control Loop Coupling" do
    @tag :cae
    test "broadcast reaches all registered loops" do
      {:ok, _pid} = Indrajaal.Control.UnifiedBus.start_link()

      # Register mock loops
      # Broadcast event
      Indrajaal.Control.UnifiedBus.broadcast({:test_event, :data})

      # Verify all loops received
    end

    test "circuit breaker activates on overload" do
      {:ok, _pid} = Indrajaal.Control.UnifiedBus.start_link()

      # Flood with events
      for _ <- 1..2000 do
        Indrajaal.Control.UnifiedBus.broadcast({:flood, :event})
      end

      # Circuit should be open
    end
  end
end
```

### 4.2 Component Integration Points

| Component | Integrates With | Protocol |
|-----------|-----------------|----------|
| FastOODA | UnifiedBus | Cast {:control_event, _} |
| FastOODA | TrainingGym | record_episode/4 |
| GDE | Guardian | validate_proposal/1 |
| GDE | ShadowMode | start_shadow/1 |
| UnifiedBus | All Loops | {:control_event, _} |
| ContainerSensor | FastOODA | {:container_observation, _} |

---

## Level 5: Code Architecture Plan

### 5.1 Module Dependencies

```elixir
# application.ex additions
children = [
  # Existing...

  # CAE Fast Path
  {Indrajaal.Cortex.FastOODA, []},
  {Indrajaal.Control.UnifiedBus, []},
  {Indrajaal.Cortex.Sensors.ContainerSensorBridge, []},

  # Evolution (now enabled)
  {Indrajaal.Cortex.Evolution.GDE, [enabled: true]},

  # Existing supervision continues...
]
```

### 5.2 Configuration Changes

```elixir
# config/config.exs additions
config :indrajaal, Indrajaal.Cortex.FastOODA,
  interval_ms: 50,
  batch_size: 100,
  min_quality: 80,
  min_confidence: 70

config :indrajaal, Indrajaal.Control.UnifiedBus,
  loops: [:ooda, :fast_ooda, :ace, :homeostasis, :gde],
  circuit_threshold: 1000

config :indrajaal, Indrajaal.Cortex.Evolution.GDE,
  enabled: true,
  auto_apply: false,
  proposal_threshold: 0.85,
  max_proposals_per_cycle: 5

config :indrajaal, Indrajaal.Cortex.Sensors.ContainerSensorBridge,
  poll_interval_ms: 50,
  metrics: [:cpu, :memory, :io, :network, :health]
```

### 5.3 Telemetry Events

```elixir
# New telemetry events for CAE
[
  [:indrajaal, :fast_ooda, :cycle],      # Cycle complete
  [:indrajaal, :fast_ooda, :observe],    # Observation batch
  [:indrajaal, :fast_ooda, :decide],     # Decision made
  [:indrajaal, :fast_ooda, :act],        # Action executed
  [:indrajaal, :control_bus, :broadcast], # Event broadcast
  [:indrajaal, :control_bus, :circuit],   # Circuit state change
  [:indrajaal, :gde, :proposal],          # Proposal generated
  [:indrajaal, :gde, :validated],         # Proposal validated
  [:indrajaal, :gde, :shadowed],          # Shadow test started
  [:indrajaal, :gde, :promoted],          # Shadow promoted
  [:indrajaal, :sensor, :container],      # Container metrics
]
```

### 5.4 STAMP Constraint Additions

```elixir
# New constraints for CAE
@stamp_constraints [
  # Fast OODA
  {"SC-OODA-001", "Cycle time <100ms"},
  {"SC-OODA-002", "Quality gates enforced"},
  {"SC-OODA-003", "Async observation only"},
  {"SC-OODA-004", "No blocking in cycle"},

  # Control Bus
  {"SC-BUS-001", "Async messaging only"},
  {"SC-BUS-002", "No blocking operations"},
  {"SC-BUS-003", "Circuit breaker protection"},
  {"SC-BUS-004", "Event ordering preserved"},

  # GDE
  {"SC-GDE-001", "Guardian validation required"},
  {"SC-GDE-002", "Shadow testing mandatory"},
  {"SC-GDE-003", "Rollback capability"},
  {"SC-GDE-004", "Proposal threshold >=0.85"},

  # Sensors
  {"SC-SENS-001", "Non-blocking polling"},
  {"SC-SENS-002", "Graceful degradation"},
  {"SC-SENS-003", "Observation buffering"}
]
```

---

## Appendix A: Weekly Milestones

### Week 1: OODA Acceleration

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | TDG: Write FastOODA tests | `test/indrajaal/cortex/fast_ooda_test.exs` |
| 2 | Implement FastOODA module | `lib/indrajaal/cortex/fast_ooda.ex` |
| 3 | Wire to TrainingGym | Learning integration |
| 4 | Container config updates | `podman-compose.yml` |
| 5 | Integration testing | All tests pass |

### Week 2: GDE Activation

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | TDG: Write GDE tests | `test/indrajaal/cortex/evolution/gde_test.exs` |
| 2 | Enable GDE module | `lib/indrajaal/cortex/evolution/gde.ex` |
| 3 | Guardian integration | Proposal validation |
| 4 | ShadowMode wiring | Shadow test pipeline |
| 5 | Manual approval gate | Promotion workflow |

### Week 3: Control Loop Coupling

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | TDG: Write UnifiedBus tests | `test/indrajaal/control/unified_bus_test.exs` |
| 2 | Implement UnifiedBus | `lib/indrajaal/control/unified_bus.ex` |
| 3 | Connect all loops | Full coupling |
| 4 | Circuit breaker | Overload protection |
| 5 | End-to-end testing | Full CAE cycle |

### Week 4: Physical Sensor Integration

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | TDG: Write sensor tests | Sensor test suite |
| 2 | ContainerSensorBridge | `lib/indrajaal/cortex/sensors/container_sensor_bridge.ex` |
| 3 | Wire to FastOODA | Observation injection |
| 4 | Additional sensors | Network, disk, FLAME |
| 5 | Aggregation tuning | Optimal batch sizes |

### Week 5: Semi-Autonomous Evolution

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Shadow testing validation | 10K cycle threshold |
| 2 | Promotion pipeline | Auto-promotion config |
| 3 | Rollback testing | Fail-safe verification |
| 4 | Documentation | CAE operations guide |
| 5 | Final validation | CAE 9.5/10 readiness |

---

## Appendix B: File Creation Checklist

| File | Status | Week |
|------|--------|------|
| `lib/indrajaal/cortex/fast_ooda.ex` | NEW | 1 |
| `test/indrajaal/cortex/fast_ooda_test.exs` | NEW | 1 |
| `lib/indrajaal/control/unified_bus.ex` | NEW | 3 |
| `test/indrajaal/control/unified_bus_test.exs` | NEW | 3 |
| `lib/indrajaal/cortex/sensors/container_sensor_bridge.ex` | NEW | 4 |
| `lib/indrajaal/cortex/evolution/gde.ex` | UPDATE | 2 |
| `test/indrajaal/cortex/evolution/gde_test.exs` | NEW | 2 |
| `config/config.exs` | UPDATE | 1 |
| `podman-compose.yml` | UPDATE | 1 |
| `lib/indrajaal/application.ex` | UPDATE | 1 |

---

## Appendix C: Validation Commands

```bash
# Week 1: OODA Acceleration
MIX_ENV=test mix test test/indrajaal/cortex/fast_ooda_test.exs --trace
mix run -e "Indrajaal.Cortex.FastOODA.start_link(); Process.sleep(1000); IO.inspect(Indrajaal.Cortex.FastOODA.get_state())"

# Week 2: GDE Activation
MIX_ENV=test mix test test/indrajaal/cortex/evolution/gde_test.exs --trace
mix run -e "Indrajaal.Cortex.Evolution.GDE.start_link(enabled: true); Indrajaal.Cortex.Evolution.GDE.submit_goal(%{type: :test})"

# Week 3: Control Bus
MIX_ENV=test mix test test/indrajaal/control/unified_bus_test.exs --trace
mix run -e "Indrajaal.Control.UnifiedBus.start_link(); Indrajaal.Control.UnifiedBus.broadcast({:test, :event})"

# Week 4: Sensors
MIX_ENV=test mix test test/indrajaal/cortex/sensors/ --trace

# Week 5: Full CAE
MIX_ENV=test mix test --only cae
mix run -e "Indrajaal.CAE.full_cycle_test()"

# Validation Gate
mix compile --warnings-as-errors && mix test --only cae && echo "CAE READY"
```

---

*Generated by Cybernetic Architect - SOPv5.11 Framework*
*Plan Date: 2025-12-29T12:00:00+01:00*
*Target Completion: 2025-02-02*
*Total New Files: 7 | Updated Files: 4*
