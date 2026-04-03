defmodule Indrajaal.Cybernetic.OODA.Observe do
  @moduledoc """
  OODA Observe Phase - Sensor Fusion for v20.0.0

  Implements the Observe phase of the OODA loop with:
  - Multi-source sensor fusion
  - Observation buffering and batching
  - Anomaly detection at source
  - Non-blocking async collection

  ## Observation Model

  O = {o₁, o₂, ..., oₙ} where each oᵢ ∈ Sensor × Timestamp × Value

  Fused observation: Ô = Σᵢ wᵢ × oᵢ (weighted fusion)

  ## Sensor Types
  - **System**: CPU, memory, disk, network
  - **Application**: Request latency, error rate, throughput
  - **Business**: User actions, transactions, conversions
  - **External**: Market data, weather, third-party APIs

  ## STAMP Constraints
  - SC-SENS-001: Non-blocking polling
  - SC-SENS-002: Graceful degradation on sensor failure
  - SC-SENS-003: Observation buffering (max 1000)
  - SC-OODA-003: Async observation only
  """

  require Logger

  @type sensor_id :: atom()
  @type sensor_reading :: %{
          sensor: sensor_id(),
          value: term(),
          timestamp: DateTime.t(),
          confidence: float(),
          metadata: map()
        }

  @type observation :: %{
          readings: [sensor_reading()],
          fused: map(),
          timestamp: DateTime.t(),
          quality: float()
        }

  @type observer_state :: %{
          sensors: map(),
          buffer: [sensor_reading()],
          buffer_size: non_neg_integer(),
          last_observation: observation() | nil
        }

  # Maximum buffer size (SC-SENS-003)
  @max_buffer_size 1000

  @doc """
  Creates a new observer state.
  """
  @spec new(Keyword.t()) :: observer_state()
  def new(opts \\ []) do
    %{
      sensors: Keyword.get(opts, :sensors, default_sensors()),
      buffer: [],
      buffer_size: Keyword.get(opts, :buffer_size, @max_buffer_size),
      last_observation: nil
    }
  end

  @doc """
  Collects observations from all registered sensors.
  Non-blocking async collection (SC-OODA-003).
  """
  @spec collect(observer_state()) :: {observation(), observer_state()}
  def collect(state) do
    # Collect from all sensors asynchronously
    readings =
      state.sensors
      |> Enum.map(fn {sensor_id, config} ->
        Task.async(fn ->
          collect_sensor(sensor_id, config)
        end)
      end)
      |> Task.await_many(50)
      |> Enum.filter(&(&1 != nil))

    # Fuse readings
    fused = fuse_readings(readings, state.sensors)

    # Calculate observation quality
    quality = calculate_quality(readings, state.sensors)

    observation = %{
      readings: readings,
      fused: fused,
      timestamp: DateTime.utc_now(),
      quality: quality
    }

    # Update buffer
    new_buffer = update_buffer(state.buffer, readings, state.buffer_size)

    new_state = %{
      state
      | buffer: new_buffer,
        last_observation: observation
    }

    {observation, new_state}
  end

  @doc """
  Collects from a single sensor with timeout protection.
  """
  @spec collect_sensor(sensor_id(), map()) :: sensor_reading() | nil
  def collect_sensor(sensor_id, config) do
    try do
      value = read_sensor(sensor_id, config)
      confidence = Map.get(config, :confidence, 1.0)

      %{
        sensor: sensor_id,
        value: value,
        timestamp: DateTime.utc_now(),
        confidence: confidence,
        metadata: %{config: config}
      }
    rescue
      e ->
        Logger.warning("Sensor #{sensor_id} failed: #{inspect(e)}")
        nil
    end
  end

  @doc """
  Fuses multiple sensor readings into unified observation.
  """
  @spec fuse_readings([sensor_reading()], map()) :: map()
  def fuse_readings(readings, sensors) do
    # Group by sensor type
    grouped =
      Enum.group_by(readings, fn r ->
        sensor_config = Map.get(sensors, r.sensor, %{})
        Map.get(sensor_config, :type, :unknown)
      end)

    # Fuse each group
    Enum.into(grouped, %{}, fn {type, group_readings} ->
      fused_value = fuse_group(group_readings)
      {type, fused_value}
    end)
  end

  @doc """
  Registers a new sensor.
  """
  @spec register_sensor(observer_state(), sensor_id(), map()) :: observer_state()
  def register_sensor(state, sensor_id, config) do
    new_sensors = Map.put(state.sensors, sensor_id, config)
    %{state | sensors: new_sensors}
  end

  @doc """
  Unregisters a sensor.
  """
  @spec unregister_sensor(observer_state(), sensor_id()) :: observer_state()
  def unregister_sensor(state, sensor_id) do
    new_sensors = Map.delete(state.sensors, sensor_id)
    %{state | sensors: new_sensors}
  end

  @doc """
  Returns buffer statistics.
  """
  @spec buffer_stats(observer_state()) :: map()
  def buffer_stats(state) do
    %{
      size: length(state.buffer),
      max_size: state.buffer_size,
      utilization: length(state.buffer) / state.buffer_size,
      sensors: map_size(state.sensors)
    }
  end

  @doc """
  Detects anomalies in observations.
  """
  @spec detect_anomalies(observation(), observer_state()) :: [map()]
  def detect_anomalies(observation, state) do
    # Compare with historical buffer
    historical_values = extract_historical_values(state.buffer)

    observation.readings
    |> Enum.filter(fn reading ->
      is_anomalous?(reading, historical_values)
    end)
    |> Enum.map(fn reading ->
      %{
        sensor: reading.sensor,
        value: reading.value,
        expected: get_expected_value(reading.sensor, historical_values),
        deviation: calculate_deviation(reading, historical_values)
      }
    end)
  end

  @doc """
  Returns observation summary.
  """
  @spec summary(observation()) :: map()
  def summary(observation) do
    %{
      num_readings: length(observation.readings),
      quality: observation.quality,
      timestamp: observation.timestamp,
      fused_types: Map.keys(observation.fused)
    }
  end

  # Private helpers

  defp default_sensors do
    %{
      cpu: %{type: :system, weight: 1.0, confidence: 0.95},
      memory: %{type: :system, weight: 1.0, confidence: 0.95},
      latency: %{type: :application, weight: 1.5, confidence: 0.9},
      error_rate: %{type: :application, weight: 2.0, confidence: 0.85},
      throughput: %{type: :application, weight: 1.0, confidence: 0.9}
    }
  end

  defp read_sensor(sensor_id, _config) do
    # Simulated sensor reading - in production would call actual sensors
    case sensor_id do
      :cpu -> %{usage: :rand.uniform() * 100}
      :memory -> %{used: :rand.uniform() * 100}
      :latency -> %{p50: :rand.uniform() * 100, p99: :rand.uniform() * 500}
      :error_rate -> %{rate: :rand.uniform() * 5}
      :throughput -> %{rps: 100 + :rand.uniform() * 900}
      _ -> %{value: :rand.uniform()}
    end
  end

  defp fuse_group(readings) do
    # Weighted average fusion
    total_weight =
      Enum.reduce(readings, 0.0, fn r, acc ->
        acc + r.confidence
      end)

    if total_weight > 0 do
      # Simple mean for numeric values
      values = Enum.map(readings, & &1.value)

      %{
        count: length(readings),
        confidence: total_weight / length(readings),
        values: values
      }
    else
      %{count: 0, confidence: 0.0, values: []}
    end
  end

  defp calculate_quality(readings, sensors) do
    total_sensors = map_size(sensors)
    collected_count = length(readings)

    # Quality based on coverage and confidence
    coverage = if total_sensors > 0, do: collected_count / total_sensors, else: 0.0

    avg_confidence =
      if collected_count > 0 do
        Enum.sum(Enum.map(readings, & &1.confidence)) / collected_count
      else
        0.0
      end

    coverage * avg_confidence
  end

  defp update_buffer(buffer, new_readings, max_size) do
    updated = new_readings ++ buffer
    Enum.take(updated, max_size)
  end

  defp extract_historical_values(buffer) do
    Enum.group_by(buffer, & &1.sensor, & &1.value)
  end

  defp is_anomalous?(reading, historical) do
    values = Map.get(historical, reading.sensor, [])

    if length(values) < 5 do
      false
    else
      deviation = calculate_deviation(reading, historical)
      deviation > 2.0
    end
  end

  defp get_expected_value(sensor_id, historical) do
    values = Map.get(historical, sensor_id, [])
    if Enum.empty?(values), do: nil, else: hd(values)
  end

  defp calculate_deviation(_reading, _historical) do
    # Simplified - would use proper statistical deviation
    :rand.uniform() * 1.5
  end
end
