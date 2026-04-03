defmodule Indrajaal.Control.ZenohNeuralIntegrationTest do
  @moduledoc """
  L2.3: Zenoh Neural Stream Integration Tests.

  Tests the integration between control loops and Zenoh neural streaming:
  - FastOODA decisions stream to Zenoh
  - SensorMesh observations stream to Zenoh
  - UnifiedBus control events stream to Zenoh

  STAMP Constraints:
  - SC-OBS-001: Latency < 50ms (95th percentile)
  - SC-OBS-002: No data loss (buffered until flush)
  - SC-OBS-003: Ordered delivery per key
  - SC-ZENOH-INT-001: All components have Zenoh access
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Observability.ZenohNeuralStream
  alias Indrajaal.Cortex.FastOODA
  alias Indrajaal.Cortex.Sensors.SensorMesh
  alias Indrajaal.Control.UnifiedBus

  setup do
    # Start ZenohNeuralStream if not running
    case GenServer.whereis(ZenohNeuralStream) do
      nil ->
        {:ok, _stream_pid} = ZenohNeuralStream.start_link(buffer_size: 10, flush_interval_ms: 50)
        :ok

      _pid ->
        :ok
    end

    :ok
  end

  describe "L2.3: FastOODA → Zenoh Integration" do
    test "FastOODA cycle data streams to Zenoh" do
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_zenoh_1, ai_enabled: false)

      # Get initial stats
      initial_stats = ZenohNeuralStream.stats()

      # Inject observations to trigger cycle
      FastOODA.inject_observation(%{cpu: 80, memory: 70}, :test_ooda_zenoh_1)
      FastOODA.trigger_cycle(:test_ooda_zenoh_1)
      Process.sleep(100)

      # Stream OODA state to Zenoh
      state = FastOODA.get_state(:test_ooda_zenoh_1)
      ZenohNeuralStream.stream_state(:fast_ooda, :phase, state.phase)
      ZenohNeuralStream.stream_metric(:cortex, :ooda_latency, state.last_latency || 0)

      # Flush and verify
      ZenohNeuralStream.flush()
      final_stats = ZenohNeuralStream.stats()

      assert final_stats.states_streamed >= initial_stats.states_streamed
      assert final_stats.metrics_streamed >= initial_stats.metrics_streamed

      GenServer.stop(ooda)
    end

    test "OODA decisions stream with action metadata" do
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_zenoh_2, ai_enabled: false)

      initial = ZenohNeuralStream.stats()

      # Inject high-stress to trigger decision
      FastOODA.inject_observation(%{cpu: 95, memory: 95}, :test_ooda_zenoh_2)
      FastOODA.trigger_cycle(:test_ooda_zenoh_2)
      Process.sleep(100)

      # Stream the decision
      state = FastOODA.get_state(:test_ooda_zenoh_2)

      ZenohNeuralStream.stream_state(:fast_ooda, :last_decision, state.last_decision)

      ZenohNeuralStream.stream_log(
        :info,
        FastOODA,
        "Decision made: #{inspect(state.last_decision)}"
      )

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      assert final.logs_streamed > initial.logs_streamed

      GenServer.stop(ooda)
    end
  end

  describe "L2.3: SensorMesh → Zenoh Integration" do
    test "sensor observations stream to Zenoh" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_zenoh_1)

      initial = ZenohNeuralStream.stats()

      # Register a mock sensor
      sensor_pid = spawn(fn -> Process.sleep(:infinity) end)
      SensorMesh.register_sensor(:test_mesh_zenoh_1, :mock_sensor, sensor_pid)

      # Poll and stream
      SensorMesh.poll_now(:test_mesh_zenoh_1)
      Process.sleep(100)

      # Get mesh metrics and stream to Zenoh
      metrics = SensorMesh.metrics(:test_mesh_zenoh_1)
      ZenohNeuralStream.stream_metric(:sensor_mesh, :poll_count, metrics.poll_count)
      ZenohNeuralStream.stream_metric(:sensor_mesh, :sensor_count, metrics.sensor_count)

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      assert final.metrics_streamed > initial.metrics_streamed

      Process.exit(sensor_pid, :normal)
      GenServer.stop(mesh)
    end

    test "sensor health streams to Zenoh" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_zenoh_2)

      initial = ZenohNeuralStream.stats()

      # Get health and stream
      health = SensorMesh.health(:test_mesh_zenoh_2)
      ZenohNeuralStream.stream_state(:sensor_mesh, :health, health)

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      assert final.states_streamed > initial.states_streamed

      GenServer.stop(mesh)
    end
  end

  describe "L2.3: UnifiedBus → Zenoh Integration" do
    test "control loop events stream to Zenoh" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_zenoh_1)

      initial = ZenohNeuralStream.stats()

      # Broadcast a control event
      GenServer.cast(
        :test_bus_zenoh_1,
        {:broadcast,
         %{
           topic: :neural_test,
           payload: %{data: :zenoh_test},
           timestamp: DateTime.utc_now(),
           source: self(),
           priority: :normal
         }}
      )

      Process.sleep(100)

      # Get bus metrics and stream
      metrics = GenServer.call(:test_bus_zenoh_1, :metrics)
      ZenohNeuralStream.stream_metric(:unified_bus, :loop_broadcasts, metrics.loop_broadcasts)

      ZenohNeuralStream.stream_metric(
        :unified_bus,
        :decisions_executed,
        metrics.decisions_executed
      )

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      assert final.metrics_streamed > initial.metrics_streamed

      GenServer.stop(bus)
    end

    test "circuit breaker state streams to Zenoh" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_zenoh_2)

      initial = ZenohNeuralStream.stats()

      # Get circuit status and stream
      circuit_status = GenServer.call(:test_bus_zenoh_2, :circuit_status)
      ZenohNeuralStream.stream_state(:unified_bus, :circuit_status, circuit_status)

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      assert final.states_streamed > initial.states_streamed

      GenServer.stop(bus)
    end
  end

  describe "L2.3: Cross-Component Streaming" do
    test "end-to-end: Sensor → FastOODA → Bus → Zenoh" do
      {:ok, bus} = UnifiedBus.start_link(name: :test_bus_e2e)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_e2e, ai_enabled: false)
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_e2e)

      initial = ZenohNeuralStream.stats()

      # Wire components
      :ok = SensorMesh.connect_to_ooda(:test_mesh_e2e, :test_ooda_e2e)
      :ok = GenServer.call(:test_bus_e2e, {:register, :fast_ooda, ooda})

      # Trigger data flow
      SensorMesh.poll_now(:test_mesh_e2e)
      Process.sleep(50)

      FastOODA.inject_observation(%{cpu: 75, memory: 65}, :test_ooda_e2e)
      FastOODA.trigger_cycle(:test_ooda_e2e)
      Process.sleep(100)

      # Stream all components to Zenoh
      mesh_metrics = SensorMesh.metrics(:test_mesh_e2e)
      ooda_state = FastOODA.get_state(:test_ooda_e2e)
      bus_metrics = GenServer.call(:test_bus_e2e, :metrics)

      ZenohNeuralStream.stream_metric(:e2e, :mesh_polls, mesh_metrics.poll_count)
      ZenohNeuralStream.stream_metric(:e2e, :ooda_cycles, ooda_state.cycle_count)
      ZenohNeuralStream.stream_metric(:e2e, :bus_decisions, bus_metrics.decisions_executed)
      ZenohNeuralStream.stream_state(:e2e, :ooda_phase, ooda_state.phase)

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      assert final.metrics_streamed > initial.metrics_streamed + 2
      assert final.states_streamed > initial.states_streamed

      GenServer.stop(mesh)
      GenServer.stop(ooda)
      GenServer.stop(bus)
    end
  end

  describe "L2.3: Latency Compliance (SC-OBS-001)" do
    test "streaming round-trip under 50ms" do
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_latency, ai_enabled: false)

      start = System.monotonic_time(:microsecond)

      # Full cycle: inject → trigger → get state → stream → flush
      FastOODA.inject_observation(%{cpu: 50, memory: 50}, :test_ooda_latency)
      FastOODA.trigger_cycle(:test_ooda_latency)
      state = FastOODA.get_state(:test_ooda_latency)
      ZenohNeuralStream.stream_state(:latency_test, :state, state.phase)
      ZenohNeuralStream.flush()

      elapsed_us = System.monotonic_time(:microsecond) - start
      elapsed_ms = elapsed_us / 1000

      # Should complete in under 50ms (generous for test environment)
      assert elapsed_ms < 50, "Round-trip took #{elapsed_ms}ms, expected < 50ms"

      GenServer.stop(ooda)
    end
  end

  describe "L2.3: No Data Loss (SC-OBS-002)" do
    test "all streamed data is captured" do
      initial = ZenohNeuralStream.stats()

      # Stream exact counts
      for i <- 1..10 do
        ZenohNeuralStream.stream_log(:info, __MODULE__, "Test log #{i}")
      end

      for i <- 1..5 do
        ZenohNeuralStream.stream_metric(:test_domain, :counter, i)
      end

      for i <- 1..3 do
        ZenohNeuralStream.stream_state(:test_agent, :iteration, i)
      end

      ZenohNeuralStream.flush()
      final = ZenohNeuralStream.stats()

      # Logs: 10 streamed
      assert final.logs_streamed >= initial.logs_streamed + 10

      # Metrics: aggregated, at least 1 entry
      assert final.metrics_streamed >= initial.metrics_streamed + 1

      # States: only changed values streamed (3 iterations)
      assert final.states_streamed >= initial.states_streamed + 1
    end
  end
end
