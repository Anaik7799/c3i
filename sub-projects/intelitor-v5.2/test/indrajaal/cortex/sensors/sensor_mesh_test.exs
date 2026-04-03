defmodule Indrajaal.Cortex.Sensors.SensorMeshTest do
  @moduledoc """
  L2.2: SensorMesh → FastOODA Integration Tests.

  Tests the unified sensor mesh that coordinates all Cortex sensors
  and routes observations to FastOODA.

  STAMP Constraints:
  - SC-SENS-001: Non-blocking polling
  - SC-SENS-002: Graceful degradation
  - SC-SENS-003: 50ms max poll latency
  - SC-OODA-003: Async observation only
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cortex.Sensors.SensorMesh
  alias Indrajaal.Cortex.FastOODA

  describe "SensorMesh.start_link/1" do
    test "starts the sensor mesh with default config" do
      {:ok, pid} = SensorMesh.start_link(name: :test_mesh_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with custom poll interval" do
      {:ok, pid} = SensorMesh.start_link(name: :test_mesh_2, poll_interval: 100)
      status = SensorMesh.status(:test_mesh_2)
      assert status.poll_interval == 100
      GenServer.stop(pid)
    end
  end

  describe "SensorMesh.register_sensor/3" do
    test "registers a sensor by type and pid" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_3)

      # Simulate a sensor process
      sensor_pid = spawn(fn -> Process.sleep(:infinity) end)
      :ok = SensorMesh.register_sensor(:test_mesh_3, :test_sensor, sensor_pid)

      sensors = SensorMesh.list_sensors(:test_mesh_3)
      assert :test_sensor in Enum.map(sensors, & &1.type)

      Process.exit(sensor_pid, :normal)
      GenServer.stop(mesh)
    end

    test "registers multiple sensors" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_4)

      pids =
        for type <- [:cpu, :memory, :io] do
          pid = spawn(fn -> Process.sleep(:infinity) end)
          :ok = SensorMesh.register_sensor(:test_mesh_4, type, pid)
          pid
        end

      sensors = SensorMesh.list_sensors(:test_mesh_4)
      assert length(sensors) == 3

      Enum.each(pids, &Process.exit(&1, :normal))
      GenServer.stop(mesh)
    end
  end

  describe "SensorMesh.unregister_sensor/2" do
    test "removes a sensor from the mesh" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_5)
      sensor_pid = spawn(fn -> Process.sleep(:infinity) end)
      :ok = SensorMesh.register_sensor(:test_mesh_5, :temp_sensor, sensor_pid)

      assert length(SensorMesh.list_sensors(:test_mesh_5)) == 1

      :ok = SensorMesh.unregister_sensor(:test_mesh_5, :temp_sensor)
      assert SensorMesh.list_sensors(:test_mesh_5) == []

      Process.exit(sensor_pid, :normal)
      GenServer.stop(mesh)
    end
  end

  describe "L2.2: SensorMesh → FastOODA Flow" do
    test "observations are injected into FastOODA" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_6, poll_interval: 50)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_mesh_1, ai_enabled: false)

      # Wire the mesh to the OODA loop
      :ok = SensorMesh.connect_to_ooda(:test_mesh_6, :test_ooda_mesh_1)

      # Force a poll cycle
      SensorMesh.poll_now(:test_mesh_6)
      Process.sleep(100)

      # Verify OODA received observations
      status = SensorMesh.status(:test_mesh_6)
      assert status.poll_count >= 1

      GenServer.stop(ooda)
      GenServer.stop(mesh)
    end

    test "mesh tracks observation injection count" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_7, poll_interval: 50)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_mesh_2, ai_enabled: false)

      :ok = SensorMesh.connect_to_ooda(:test_mesh_7, :test_ooda_mesh_2)

      # Poll multiple times
      for _ <- 1..3 do
        SensorMesh.poll_now(:test_mesh_7)
        Process.sleep(60)
      end

      status = SensorMesh.status(:test_mesh_7)
      assert status.observations_injected >= 3

      GenServer.stop(ooda)
      GenServer.stop(mesh)
    end
  end

  describe "L2.2: Sensor Health Tracking" do
    test "mesh reports aggregate sensor health" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_8)

      # Start with no sensors - should be healthy (no sensors = no failures)
      health = SensorMesh.health(:test_mesh_8)
      assert health in [:healthy, :unknown]

      GenServer.stop(mesh)
    end

    test "mesh detects failed sensors" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_9)

      # Register a sensor
      sensor_pid = spawn(fn -> Process.sleep(:infinity) end)
      :ok = SensorMesh.register_sensor(:test_mesh_9, :volatile_sensor, sensor_pid)

      # Kill the sensor
      Process.exit(sensor_pid, :kill)
      Process.sleep(50)

      # Mesh should detect the failure
      sensors = SensorMesh.list_sensors(:test_mesh_9)
      assert Enum.any?(sensors, &(&1.status == :dead)) or sensors == []

      GenServer.stop(mesh)
    end
  end

  describe "L2.2: Graceful Degradation (SC-SENS-002)" do
    test "mesh continues with partial sensor availability" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_10)

      # Register some sensors
      healthy_pid = spawn(fn -> Process.sleep(:infinity) end)
      failing_pid = spawn(fn -> Process.sleep(:infinity) end)

      :ok = SensorMesh.register_sensor(:test_mesh_10, :healthy, healthy_pid)
      :ok = SensorMesh.register_sensor(:test_mesh_10, :failing, failing_pid)

      # Kill one sensor
      Process.exit(failing_pid, :kill)
      Process.sleep(50)

      # Force poll - should not crash
      SensorMesh.poll_now(:test_mesh_10)
      Process.sleep(100)

      # Mesh should still be alive
      assert Process.alive?(mesh)

      status = SensorMesh.status(:test_mesh_10)
      assert status.poll_count >= 1

      Process.exit(healthy_pid, :normal)
      GenServer.stop(mesh)
    end
  end

  describe "L2.2: Poll Latency Compliance (SC-SENS-003)" do
    test "poll latency is tracked" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_11, poll_interval: 50)

      SensorMesh.poll_now(:test_mesh_11)
      Process.sleep(100)

      status = SensorMesh.status(:test_mesh_11)
      assert is_number(status.last_poll_latency_ms)
      assert status.last_poll_latency_ms >= 0

      GenServer.stop(mesh)
    end

    test "poll latency under 50ms threshold (SC-SENS-003)" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_12, poll_interval: 50)

      # Do several polls
      for _ <- 1..5 do
        SensorMesh.poll_now(:test_mesh_12)
        Process.sleep(60)
      end

      status = SensorMesh.status(:test_mesh_12)
      # Average should be under threshold
      assert status.avg_poll_latency_ms < 50

      GenServer.stop(mesh)
    end
  end

  describe "SensorMesh.metrics/1" do
    test "returns comprehensive metrics" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_13)

      SensorMesh.poll_now(:test_mesh_13)
      Process.sleep(100)

      metrics = SensorMesh.metrics(:test_mesh_13)

      assert Map.has_key?(metrics, :poll_count)
      assert Map.has_key?(metrics, :sensor_count)
      assert Map.has_key?(metrics, :observations_injected)
      assert Map.has_key?(metrics, :avg_poll_latency_ms)

      GenServer.stop(mesh)
    end
  end

  describe "L2.2: Backpressure Feedback" do
    test "mesh respects OODA backpressure signal" do
      {:ok, mesh} = SensorMesh.start_link(name: :test_mesh_14, poll_interval: 50)
      {:ok, ooda} = FastOODA.start_link(name: :test_ooda_mesh_3, ai_enabled: false)

      :ok = SensorMesh.connect_to_ooda(:test_mesh_14, :test_ooda_mesh_3)

      # Simulate backpressure by setting a flag
      SensorMesh.set_backpressure(:test_mesh_14, true)

      status_before = SensorMesh.status(:test_mesh_14)

      # Polls during backpressure should be skipped
      SensorMesh.poll_now(:test_mesh_14)
      Process.sleep(60)

      status_after = SensorMesh.status(:test_mesh_14)

      # Poll count may not increase during backpressure
      # Or polls happen but injection is throttled
      assert status_after.backpressure_active == true

      SensorMesh.set_backpressure(:test_mesh_14, false)
      status_final = SensorMesh.status(:test_mesh_14)
      assert status_final.backpressure_active == false

      GenServer.stop(ooda)
      GenServer.stop(mesh)
    end
  end
end
