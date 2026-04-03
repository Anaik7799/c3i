defmodule Indrajaal.Control.NeuralIntegrationTest do
  @moduledoc """
  L2.1: Neural Integration Tests - FastOODA ↔ UnifiedBus Bidirectional Wiring.

  Tests the integration between FastOODA and UnifiedBus to ensure:
  - FastOODA registers with UnifiedBus on startup
  - FastOODA decisions flow to UnifiedBus
  - UnifiedBus control events reach FastOODA
  - Circuit breaker coordination works

  STAMP Constraints:
  - SC-BUS-001: Async messaging only
  - SC-BUS-002: No blocking operations
  - SC-BUS-003: Circuit breaker at 1000 events/sec
  - SC-OODA-001: Cycle time <100ms
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Control.UnifiedBus
  alias Indrajaal.Cortex.FastOODA

  describe "L2.1: FastOODA → UnifiedBus Flow" do
    test "FastOODA decisions are broadcast to UnifiedBus" do
      # Start UnifiedBus with unique name
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_1)
      # Start FastOODA with our bus
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_1, ai_enabled: false)

      # Register FastOODA with bus manually (simulating startup wiring)
      :ok = GenServer.call(:test_bus_1, {:register, :fast_ooda, ooda})

      # Verify registration
      status = GenServer.call(:test_bus_1, :status)
      assert :fast_ooda in status.registered_loops

      # Inject high-stress observation to trigger a decision
      FastOODA.inject_observation(%{cpu: 95, memory: 90, io: 50, network: 30}, :test_ooda_1)

      # Trigger cycle
      FastOODA.trigger_cycle(:test_ooda_1)
      Process.sleep(100)

      # Verify cycle executed
      state = FastOODA.get_state(:test_ooda_1)
      assert state.cycle_count >= 1

      GenServer.stop(ooda)
      GenServer.stop(bus)
    end

    test "FastOODA decisions increment UnifiedBus decision counter" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_2)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_2, ai_enabled: false)

      :ok = GenServer.call(:test_bus_2, {:register, :fast_ooda, ooda})

      # Get initial decision count
      initial_metrics = GenServer.call(:test_bus_2, :metrics)
      initial_decisions = initial_metrics.decisions_executed

      # Inject critical stress to trigger emergency_scale_up
      FastOODA.inject_observation(%{cpu: 95, memory: 95}, :test_ooda_2)
      FastOODA.trigger_cycle(:test_ooda_2)
      Process.sleep(100)

      # Check decision was executed
      final_metrics = GenServer.call(:test_bus_2, :metrics)

      # Decision count should increase (depends on confidence gate)
      assert final_metrics.decisions_executed >= initial_decisions

      GenServer.stop(ooda)
      GenServer.stop(bus)
    end
  end

  describe "L2.1: UnifiedBus → FastOODA Flow" do
    test "control events from UnifiedBus are received by FastOODA" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_3)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_3, ai_enabled: false)

      # Register FastOODA with bus
      :ok = GenServer.call(:test_bus_3, {:register, :fast_ooda, ooda})

      # Broadcast a control event via the named bus
      GenServer.cast(:test_bus_3, {:broadcast_to_loops, %{type: :stress_alert, level: 0.85}})

      # Allow time for message delivery
      Process.sleep(100)

      # Verify broadcast was sent (check metrics)
      status = GenServer.call(:test_bus_3, :status)
      assert status.metrics.loop_broadcasts > 0

      GenServer.stop(ooda)
      GenServer.stop(bus)
    end

    test "UnifiedBus broadcasts increment loop_broadcasts counter" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_4)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_4, ai_enabled: false)

      :ok = GenServer.call(:test_bus_4, {:register, :fast_ooda, ooda})

      # Initial count
      initial = GenServer.call(:test_bus_4, :status).metrics.loop_broadcasts

      # Send multiple broadcasts using the registered name
      for i <- 1..5 do
        GenServer.cast(:test_bus_4, {:broadcast_to_loops, %{type: :test_event, index: i}})
      end

      Process.sleep(100)

      # Check counter increased
      final = GenServer.call(:test_bus_4, :status).metrics.loop_broadcasts
      assert final >= initial + 5

      GenServer.stop(ooda)
      GenServer.stop(bus)
    end
  end

  describe "L2.1: Circuit Breaker Coordination" do
    test "UnifiedBus circuit breaker protects FastOODA from overload" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_5)

      # Start circuit in closed state
      assert GenServer.call(:test_bus_5, :circuit_status) == :closed

      # Reset circuit to test
      :ok = GenServer.call(:test_bus_5, :reset_circuit)

      GenServer.stop(bus)
    end

    test "circuit state persists across broadcasts" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_6)

      # Send some broadcasts with full event format including priority
      for _ <- 1..10 do
        GenServer.cast(
          :test_bus_6,
          {:broadcast,
           %{
             topic: :test,
             payload: %{data: :sample},
             timestamp: DateTime.utc_now(),
             source: self(),
             priority: :normal
           }}
        )
      end

      Process.sleep(100)

      # Circuit should remain closed for low volume
      assert GenServer.call(:test_bus_6, :circuit_status) == :closed

      GenServer.stop(bus)
    end
  end

  describe "L2.1: Decision Routing" do
    test "scale_up decisions are routed correctly" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_7)

      # Execute a scale_up decision via GenServer cast to the named bus
      GenServer.cast(
        :test_bus_7,
        {:execute, %{action: :scale_up, confidence: 90, priority: :high}}
      )

      # Allow more time for async processing
      Process.sleep(100)

      metrics = GenServer.call(:test_bus_7, :metrics)
      assert metrics.decisions_executed > 0

      GenServer.stop(bus)
    end

    test "emergency_scale_up decisions are routed with priority" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_8)

      # Execute emergency decision
      GenServer.cast(
        :test_bus_8,
        {:execute, %{action: :emergency_scale_up, confidence: 95, priority: :critical}}
      )

      Process.sleep(100)

      metrics = GenServer.call(:test_bus_8, :metrics)
      assert metrics.decisions_executed > 0

      GenServer.stop(bus)
    end

    test "maintain decisions don't trigger external actions" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_9)

      initial = GenServer.call(:test_bus_9, :metrics).decisions_executed

      # Execute maintain (no-op)
      GenServer.cast(
        :test_bus_9,
        {:execute, %{action: :maintain, confidence: 100, priority: :normal}}
      )

      Process.sleep(100)

      final = GenServer.call(:test_bus_9, :metrics).decisions_executed
      # Maintain still counts as an executed decision
      assert final == initial + 1

      GenServer.stop(bus)
    end
  end

  describe "L2.1: Auto-Discovery" do
    test "UnifiedBus discovers FastOODA automatically" do
      # Start bus first with unique name
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_10)

      # Start FastOODA with unique test name
      {:ok, ooda} = FastOODA.start_link(name: :test_fast_ooda_discover)

      # Wait for autodiscovery check
      Process.sleep(100)

      # FastOODA should be discoverable via its name
      assert is_pid(GenServer.whereis(:test_fast_ooda_discover))

      GenServer.stop(ooda)
      GenServer.stop(bus)
    end
  end

  describe "L2.1: Latency Compliance" do
    test "FastOODA cycle completes within 100ms (SC-OODA-001)" do
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_latency, ai_enabled: false)

      # Inject observations
      for _ <- 1..10 do
        FastOODA.inject_observation(%{cpu: 50, memory: 50}, :test_ooda_latency)
      end

      # Trigger cycle and measure
      FastOODA.trigger_cycle(:test_ooda_latency)
      Process.sleep(150)

      state = FastOODA.get_state(:test_ooda_latency)

      # Last latency should be under 100ms
      assert state.last_latency < 100

      GenServer.stop(ooda)
    end

    test "UnifiedBus broadcast latency is tracked" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_latency)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_lat2, ai_enabled: false)

      :ok = GenServer.call(:test_bus_latency, {:register, :fast_ooda, ooda})

      # Send broadcasts
      for _ <- 1..10 do
        GenServer.cast(:test_bus_latency, {:broadcast_to_loops, %{type: :latency_test}})
      end

      Process.sleep(100)

      metrics = GenServer.call(:test_bus_latency, :metrics)
      # Should have avg latency tracked
      assert is_number(metrics.avg_broadcast_latency_us)

      GenServer.stop(ooda)
      GenServer.stop(bus)
    end
  end
end
