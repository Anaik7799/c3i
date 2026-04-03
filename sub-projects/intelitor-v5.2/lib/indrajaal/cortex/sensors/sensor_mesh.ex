defmodule Indrajaal.Cortex.Sensors.SensorMesh do
  @moduledoc """
  L2.2: Unified Sensor Mesh Orchestrator for v20.0.0

  Coordinates all Cortex sensors and routes observations to FastOODA.
  Acts as the "nervous system" collecting sensory data from distributed
  sensors and injecting them into the OODA control loop.

  ## Architecture

  ```
  ┌──────────────────────────────────────────────────────────────┐
  │                       SensorMesh                              │
  │                    (50ms poll cycle)                          │
  ├──────────────────────────────────────────────────────────────┤
  │  Registered Sensors:                                         │
  │    ├── SystemSensor (CPU, Memory, IO, GC)                    │
  │    ├── ContainerSensorBridge (Container health aggregator)    │
  │    ├── BeamSensor (BEAM VM metrics)                          │
  │    ├── FlameSensor (FLAME pool metrics)                      │
  │    └── MLSensor (ML inference metrics)                       │
  │                                                               │
  │  Output: FastOODA.inject_observation/1                        │
  │  Feedback: Backpressure from OODA cycle                       │
  └──────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints

  - SC-SENS-001: Non-blocking polling (async sensor reads)
  - SC-SENS-002: Graceful degradation (continue with partial sensors)
  - SC-SENS-003: 50ms max poll latency
  - SC-OODA-003: Async observation only

  ## Usage

      {:ok, mesh} = SensorMesh.start_link(name: :sensor_mesh)

      # Register a sensor
      SensorMesh.register_sensor(:sensor_mesh, :my_sensor, sensor_pid)

      # Connect to FastOODA
      SensorMesh.connect_to_ooda(:sensor_mesh, FastOODA)

      # Check health
      SensorMesh.health(:sensor_mesh)

  """

  use GenServer

  require Logger

  alias Indrajaal.Cortex.FastOODA

  # ============================================================
  # TYPES
  # ============================================================

  @type sensor_type :: atom()
  @type sensor_info :: %{
          type: sensor_type(),
          pid: pid(),
          registered_at: DateTime.t(),
          status: :alive | :dead,
          last_measure_latency_ms: float()
        }

  @type state :: %{
          sensors: %{sensor_type() => sensor_info()},
          poll_interval: pos_integer(),
          poll_count: non_neg_integer(),
          observations_injected: non_neg_integer(),
          last_poll_latency_ms: float(),
          avg_poll_latency_ms: float(),
          ooda_target: atom() | nil,
          backpressure_active: boolean(),
          started_at: DateTime.t()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_poll_interval 50
  @max_poll_latency_ms 50

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Start the SensorMesh GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a sensor with the mesh.
  """
  @spec register_sensor(GenServer.server(), sensor_type(), pid()) :: :ok
  def register_sensor(server, type, pid) do
    GenServer.call(server, {:register_sensor, type, pid})
  end

  @doc """
  Unregister a sensor from the mesh.
  """
  @spec unregister_sensor(GenServer.server(), sensor_type()) :: :ok
  def unregister_sensor(server, type) do
    GenServer.call(server, {:unregister_sensor, type})
  end

  @doc """
  List all registered sensors.
  """
  @spec list_sensors(GenServer.server()) :: [sensor_info()]
  def list_sensors(server) do
    GenServer.call(server, :list_sensors)
  end

  @doc """
  Connect the mesh to a FastOODA instance.
  """
  @spec connect_to_ooda(GenServer.server(), atom()) :: :ok
  def connect_to_ooda(server, ooda_name) do
    GenServer.call(server, {:connect_to_ooda, ooda_name})
  end

  @doc """
  Force an immediate poll cycle.
  """
  @spec poll_now(GenServer.server()) :: :ok
  def poll_now(server) do
    GenServer.cast(server, :poll_now)
  end

  @doc """
  Get mesh status.
  """
  @spec status(GenServer.server()) :: map()
  def status(server) do
    GenServer.call(server, :status)
  end

  @doc """
  Get aggregate health of all sensors.
  """
  @spec health(GenServer.server()) :: :healthy | :degraded | :unhealthy | :unknown
  def health(server) do
    GenServer.call(server, :health)
  end

  @doc """
  Get mesh metrics.
  """
  @spec metrics(GenServer.server()) :: map()
  def metrics(server) do
    GenServer.call(server, :metrics)
  end

  @doc """
  Set backpressure state (feedback from OODA).
  """
  @spec set_backpressure(GenServer.server(), boolean()) :: :ok
  def set_backpressure(server, active) do
    GenServer.call(server, {:set_backpressure, active})
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)

    Logger.info("[SensorMesh] Initializing with #{poll_interval}ms poll interval (SC-SENS-003)")

    state = %{
      sensors: %{},
      poll_interval: poll_interval,
      poll_count: 0,
      observations_injected: 0,
      last_poll_latency_ms: 0.0,
      avg_poll_latency_ms: 0.0,
      ooda_target: nil,
      backpressure_active: false,
      started_at: DateTime.utc_now()
    }

    # Schedule first poll
    schedule_poll(poll_interval)

    {:ok, state}
  end

  @impl true
  def handle_call({:register_sensor, type, pid}, _from, state) do
    Logger.debug("[SensorMesh] Registering sensor: #{type}")

    # Monitor the sensor process
    Process.monitor(pid)

    sensor_info = %{
      type: type,
      pid: pid,
      registered_at: DateTime.utc_now(),
      status: :alive,
      last_measure_latency_ms: 0.0
    }

    new_sensors = Map.put(state.sensors, type, sensor_info)
    {:reply, :ok, %{state | sensors: new_sensors}}
  end

  @impl true
  def handle_call({:unregister_sensor, type}, _from, state) do
    Logger.debug("[SensorMesh] Unregistering sensor: #{type}")
    new_sensors = Map.delete(state.sensors, type)
    {:reply, :ok, %{state | sensors: new_sensors}}
  end

  @impl true
  def handle_call(:list_sensors, _from, state) do
    sensors = Map.values(state.sensors)
    {:reply, sensors, state}
  end

  @impl true
  def handle_call({:connect_to_ooda, ooda_name}, _from, state) do
    Logger.info("[SensorMesh] Connected to OODA: #{ooda_name}")
    {:reply, :ok, %{state | ooda_target: ooda_name}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status_map = %{
      sensor_count: map_size(state.sensors),
      poll_count: state.poll_count,
      poll_interval: state.poll_interval,
      observations_injected: state.observations_injected,
      last_poll_latency_ms: state.last_poll_latency_ms,
      avg_poll_latency_ms: state.avg_poll_latency_ms,
      ooda_connected: state.ooda_target != nil,
      backpressure_active: state.backpressure_active,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, status_map, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    health = derive_mesh_health(state.sensors)
    {:reply, health, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics_map = %{
      poll_count: state.poll_count,
      sensor_count: map_size(state.sensors),
      observations_injected: state.observations_injected,
      avg_poll_latency_ms: state.avg_poll_latency_ms,
      last_poll_latency_ms: state.last_poll_latency_ms,
      health: derive_mesh_health(state.sensors),
      uptime_ms: DateTime.diff(DateTime.utc_now(), state.started_at, :millisecond)
    }

    {:reply, metrics_map, state}
  end

  @impl true
  def handle_call({:set_backpressure, active}, _from, state) do
    Logger.debug("[SensorMesh] Backpressure set to: #{active}")
    {:reply, :ok, %{state | backpressure_active: active}}
  end

  @impl true
  def handle_cast(:poll_now, state) do
    new_state = execute_poll(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:poll, state) do
    new_state = execute_poll(state)
    schedule_poll(state.poll_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Find and mark the sensor as dead
    updated_sensors =
      state.sensors
      |> Enum.map(fn {type, info} ->
        if info.pid == pid do
          {type, %{info | status: :dead}}
        else
          {type, info}
        end
      end)
      |> Map.new()

    Logger.warning("[SensorMesh] Sensor process died: #{inspect(pid)}")

    {:noreply, %{state | sensors: updated_sensors}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================
  # POLL IMPLEMENTATION
  # ============================================================

  defp execute_poll(state) do
    # Check backpressure - if active, skip injection but still track
    if state.backpressure_active do
      Logger.debug("[SensorMesh] Skipping poll injection due to backpressure")
      state
    else
      do_poll(state)
    end
  end

  defp do_poll(state) do
    poll_start = System.monotonic_time(:microsecond)

    # Aggregate observations from sensors (SC-SENS-001: non-blocking)
    observations = aggregate_sensor_observations(state.sensors)

    # Inject to FastOODA if connected (SC-OODA-003: async)
    injected =
      if state.ooda_target do
        inject_to_ooda(observations, state.ooda_target)
        true
      else
        false
      end

    # Calculate latency
    poll_latency_ms = (System.monotonic_time(:microsecond) - poll_start) / 1000

    # Emit telemetry
    emit_poll_telemetry(observations, poll_latency_ms, state)

    # Check for latency violation (SC-SENS-003)
    if poll_latency_ms > @max_poll_latency_ms do
      Logger.warning(
        "[SensorMesh] Poll latency #{Float.round(poll_latency_ms, 2)}ms exceeds #{@max_poll_latency_ms}ms (SC-SENS-003)"
      )
    end

    # Update state
    new_poll_count = state.poll_count + 1

    new_injected =
      if injected, do: state.observations_injected + 1, else: state.observations_injected

    new_avg = update_rolling_average(state.avg_poll_latency_ms, poll_latency_ms, new_poll_count)

    %{
      state
      | poll_count: new_poll_count,
        observations_injected: new_injected,
        last_poll_latency_ms: poll_latency_ms,
        avg_poll_latency_ms: new_avg
    }
  rescue
    error ->
      Logger.error("[SensorMesh] Poll failed: #{Exception.message(error)}")
      state
  end

  # ============================================================
  # SENSOR AGGREGATION
  # ============================================================

  defp aggregate_sensor_observations(sensors) do
    # Get observations from alive sensors only (SC-SENS-002: graceful degradation)
    alive_sensors =
      sensors
      |> Enum.filter(fn {_type, info} -> info.status == :alive end)

    # Default observation structure
    base = %{
      cpu: 0.0,
      memory: 0.0,
      io: 0.0,
      network: 0.0,
      sensor_count: length(alive_sensors),
      timestamp: DateTime.utc_now()
    }

    # If no sensors, return base with fallback values
    if alive_sensors == [] do
      base
    else
      # Poll each sensor asynchronously with timeout (non-blocking)
      sensor_data =
        alive_sensors
        |> Task.async_stream(
          fn {type, info} ->
            {type, safe_measure(info.pid)}
          end,
          timeout: 25,
          on_timeout: :kill_task
        )
        |> Enum.reduce(%{}, fn
          {:ok, {type, data}}, acc -> Map.put(acc, type, data)
          {:exit, _reason}, acc -> acc
        end)

      # Merge sensor data into observations
      merge_sensor_data(base, sensor_data)
    end
  end

  defp safe_measure(pid) do
    if Process.alive?(pid) do
      # Try to call measure/0 on the sensor
      try do
        GenServer.call(pid, :measure, 20)
      catch
        :exit, _ -> %{error: true}
      end
    else
      %{error: true}
    end
  end

  defp merge_sensor_data(base, sensor_data) do
    # Extract metrics from sensor data (prioritizing available values)
    cpu = extract_metric(sensor_data, [:cpu, :cpu_usage], base.cpu)
    memory = extract_metric(sensor_data, [:memory, :memory_usage], base.memory)
    io = extract_metric(sensor_data, [:io, :io_total], base.io)
    network = extract_metric(sensor_data, [:network, :network_usage], base.network)

    %{
      base
      | cpu: cpu,
        memory: memory,
        io: io,
        network: network
    }
  end

  defp extract_metric(sensor_data, keys, default) do
    Enum.find_value(sensor_data, default, fn {_type, data} ->
      Enum.find_value(keys, nil, fn key ->
        case Map.get(data, key) do
          nil -> nil
          value when is_number(value) -> value
          _ -> nil
        end
      end)
    end)
  end

  # ============================================================
  # OODA INJECTION
  # ============================================================

  defp inject_to_ooda(observations, ooda_target) do
    # SC-OODA-003: Async injection
    if ooda_available?(ooda_target) do
      FastOODA.inject_observation(observations, ooda_target)
    end

    :ok
  end

  defp ooda_available?(name) do
    case GenServer.whereis(name) do
      nil -> false
      _pid -> true
    end
  end

  # ============================================================
  # HEALTH DERIVATION
  # ============================================================

  defp derive_mesh_health(sensors) when map_size(sensors) == 0 do
    :unknown
  end

  defp derive_mesh_health(sensors) do
    total = map_size(sensors)
    alive = Enum.count(sensors, fn {_type, info} -> info.status == :alive end)

    ratio = alive / max(total, 1)

    cond do
      ratio >= 1.0 -> :healthy
      ratio >= 0.5 -> :degraded
      true -> :unhealthy
    end
  end

  # ============================================================
  # HELPERS
  # ============================================================

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp update_rolling_average(current_avg, new_value, count) do
    if count <= 1 do
      new_value
    else
      (current_avg * (count - 1) + new_value) / count
    end
  end

  defp emit_poll_telemetry(observations, latency_ms, state) do
    :telemetry.execute(
      [:indrajaal, :cortex, :sensor_mesh, :poll],
      %{
        latency_ms: latency_ms,
        sensor_count: map_size(state.sensors),
        cpu: observations.cpu,
        memory: observations.memory,
        system_time: System.system_time(:millisecond)
      },
      %{
        backpressure: state.backpressure_active,
        ooda_connected: state.ooda_target != nil,
        node: Node.self()
      }
    )
  end
end
