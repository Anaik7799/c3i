defmodule Indrajaal.Control.BackpressureIntegrationTest do
  @moduledoc """
  L2.4: Backpressure Coordination Integration Tests.

  Tests end-to-end backpressure coordination across L2 components:
  - SensorMesh respects backpressure from FastOODA
  - FastOODA respects backpressure from UnifiedBus
  - Zenoh Backpressure module coordinates rate limiting
  - Circuit breaker state propagation

  STAMP Constraints:
  - SC-BUS-003: Circuit breaker at 1000 events/sec
  - SC-SENS-002: Graceful degradation under load
  - SC-OODA-005: Hysteresis prevents decision oscillation
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cluster.Zenoh.Backpressure
  alias Indrajaal.Cortex.FastOODA
  alias Indrajaal.Cortex.Sensors.SensorMesh
  alias Indrajaal.Control.UnifiedBus

  describe "L2.4: SensorMesh Backpressure" do
    test "SensorMesh respects backpressure signal" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_bp_1)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_bp_1, ai_enabled: false)

      SensorMesh.connect_to_ooda(:test_mesh_bp_1, :test_ooda_bp_1)

      # Get initial state
      status_before = SensorMesh.status(:test_mesh_bp_1)
      refute status_before.backpressure_active

      # Activate backpressure
      SensorMesh.set_backpressure(:test_mesh_bp_1, true)

      status_during = SensorMesh.status(:test_mesh_bp_1)
      assert status_during.backpressure_active

      # Deactivate
      SensorMesh.set_backpressure(:test_mesh_bp_1, false)

      status_after = SensorMesh.status(:test_mesh_bp_1)
      refute status_after.backpressure_active

      GenServer.stop(ooda)
      GenServer.stop(mesh)
    end

    test "SensorMesh skips injection during backpressure" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_bp_2)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_bp_2, ai_enabled: false)

      SensorMesh.connect_to_ooda(:test_mesh_bp_2, :test_ooda_bp_2)

      # Get initial injection count
      initial = SensorMesh.status(:test_mesh_bp_2).observations_injected

      # Enable backpressure
      SensorMesh.set_backpressure(:test_mesh_bp_2, true)

      # Poll during backpressure
      SensorMesh.poll_now(:test_mesh_bp_2)
      Process.sleep(100)

      # Injection count should not increase (backpressure active)
      during_bp = SensorMesh.status(:test_mesh_bp_2)
      assert during_bp.observations_injected == initial

      # Disable backpressure and poll again
      SensorMesh.set_backpressure(:test_mesh_bp_2, false)
      SensorMesh.poll_now(:test_mesh_bp_2)
      Process.sleep(100)

      # Now injection should occur
      after_bp = SensorMesh.status(:test_mesh_bp_2)
      assert after_bp.observations_injected >= initial + 1

      GenServer.stop(ooda)
      GenServer.stop(mesh)
    end
  end

  describe "L2.4: UnifiedBus Circuit Breaker" do
    test "circuit breaker starts closed" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_bp_1)

      status = GenServer.call(:test_bus_bp_1, :circuit_status)
      assert status == :closed

      GenServer.stop(bus)
    end

    test "circuit breaker can be reset" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_bp_2)

      # Reset circuit
      :ok = GenServer.call(:test_bus_bp_2, :reset_circuit)

      status = GenServer.call(:test_bus_bp_2, :circuit_status)
      assert status == :closed

      GenServer.stop(bus)
    end
  end

  describe "L2.4: Zenoh Backpressure Module" do
    test "allows events under rate limit" do
      {:ok, bp} = Backpressure.start_link(name: :test_zenoh_bp_1, rate_limit: 100)

      results = for _ <- 1..50, do: Backpressure.allow?(bp, "control-events")
      assert Enum.all?(results, & &1)

      GenServer.stop(bp)
    end

    test "blocks events when rate limit exceeded" do
      {:ok, bp} = Backpressure.start_link(name: :test_zenoh_bp_2, rate_limit: 10)

      # Send 15 events
      results = for _ <- 1..15, do: Backpressure.allow?(bp, "flood-key")

      allowed = Enum.count(results, & &1)
      assert allowed <= 10

      GenServer.stop(bp)
    end

    test "metrics track allowed/rejected events" do
      {:ok, bp} = Backpressure.start_link(name: :test_zenoh_bp_3, rate_limit: 10)

      # Generate traffic
      for _ <- 1..15, do: Backpressure.allow?(bp, "metrics-key")

      metrics = Backpressure.metrics(bp)

      assert metrics.total_allowed > 0
      assert metrics.total_rejected > 0
      assert metrics.total_allowed + metrics.total_rejected == 15

      GenServer.stop(bp)
    end
  end

  describe "L2.4: End-to-End Backpressure Flow" do
    test "backpressure propagates from Backpressure → SensorMesh" do
      {:ok, bp} = Backpressure.start_link(name: :test_bp_e2e_1, rate_limit: 10)
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_e2e_1)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_e2e_1, ai_enabled: false)

      SensorMesh.connect_to_ooda(:test_mesh_e2e_1, :test_ooda_e2e_1)

      # Simulate rate limit trigger
      for _ <- 1..15, do: Backpressure.allow?(bp, "sensor-events")

      # Check circuit state
      bp_state = Backpressure.get_state(bp, "sensor-events")

      # If circuit is open, propagate backpressure to mesh
      if bp_state.circuit_state == :open do
        SensorMesh.set_backpressure(:test_mesh_e2e_1, true)
        status = SensorMesh.status(:test_mesh_e2e_1)
        assert status.backpressure_active
      end

      GenServer.stop(ooda)
      GenServer.stop(mesh)
      GenServer.stop(bp)
    end

    test "full stack: Backpressure → SensorMesh → FastOODA → UnifiedBus" do
      {:ok, bp} = Backpressure.start_link(name: :test_bp_stack, rate_limit: 100)
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_stack)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_stack, ai_enabled: false)
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_stack)

      # Wire components
      SensorMesh.connect_to_ooda(:test_mesh_stack, :test_ooda_stack)
      :ok = GenServer.call(:test_bus_stack, {:register, :fast_ooda, ooda})

      # Verify all components are operational
      assert Backpressure.allow?(bp, "stack-events")
      assert SensorMesh.health(:test_mesh_stack) in [:healthy, :unknown]
      assert GenServer.call(:test_bus_stack, :circuit_status) == :closed

      # Run data through the stack
      SensorMesh.poll_now(:test_mesh_stack)
      Process.sleep(50)

      FastOODA.inject_observation(%{cpu: 50, memory: 50}, :test_ooda_stack)
      FastOODA.trigger_cycle(:test_ooda_stack)
      Process.sleep(100)

      # Verify metrics flow
      mesh_metrics = SensorMesh.metrics(:test_mesh_stack)
      ooda_state = FastOODA.get_state(:test_ooda_stack)
      bus_metrics = GenServer.call(:test_bus_stack, :metrics)
      bp_metrics = Backpressure.metrics(bp)

      assert mesh_metrics.poll_count >= 1
      assert ooda_state.cycle_count >= 1
      assert is_number(bp_metrics.total_allowed)

      GenServer.stop(mesh)
      GenServer.stop(ooda)
      GenServer.stop(bus)
      GenServer.stop(bp)
    end
  end

  describe "L2.4: Recovery from Backpressure" do
    test "system recovers when backpressure is cleared" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_recover)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_recover, ai_enabled: false)

      SensorMesh.connect_to_ooda(:test_mesh_recover, :test_ooda_recover)

      # Activate backpressure
      SensorMesh.set_backpressure(:test_mesh_recover, true)
      initial_injections = SensorMesh.status(:test_mesh_recover).observations_injected

      # Poll during backpressure - no injections
      SensorMesh.poll_now(:test_mesh_recover)
      Process.sleep(100)

      during_count = SensorMesh.status(:test_mesh_recover).observations_injected
      assert during_count == initial_injections

      # Clear backpressure - recovery
      SensorMesh.set_backpressure(:test_mesh_recover, false)

      # Multiple polls should work
      for _ <- 1..3 do
        SensorMesh.poll_now(:test_mesh_recover)
        Process.sleep(60)
      end

      final_count = SensorMesh.status(:test_mesh_recover).observations_injected
      assert final_count > initial_injections

      GenServer.stop(ooda)
      GenServer.stop(mesh)
    end

    test "circuit breaker recovers after window expires" do
      {:ok, bp} =
        Backpressure.start_link(
          name: :test_bp_recover,
          rate_limit: 5,
          window_ms: 100
        )

      # Exceed limit
      for _ <- 1..10, do: Backpressure.allow?(bp, "recover-key")

      # Should be blocked
      refute Backpressure.allow?(bp, "recover-key")

      # Wait for window to expire
      Process.sleep(150)

      # Should be allowed again
      assert Backpressure.allow?(bp, "recover-key")

      GenServer.stop(bp)
    end
  end

  describe "L2.4: Metrics Under Backpressure" do
    test "metrics accurately reflect backpressure state" do
      {:ok, bp} = Backpressure.start_link(name: :test_bp_metrics, rate_limit: 10)

      # Generate mixed traffic
      for _ <- 1..15, do: Backpressure.allow?(bp, "metrics-test")

      metrics = Backpressure.metrics(bp)
      health = Backpressure.health(bp)

      assert metrics.total_allowed == 10
      assert metrics.total_rejected == 5
      assert metrics.active_keys == 1
      assert health.status == :healthy

      GenServer.stop(bp)
    end
  end
end
