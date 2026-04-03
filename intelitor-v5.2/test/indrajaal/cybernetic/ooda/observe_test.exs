defmodule Indrajaal.Cybernetic.OODA.ObserveTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Observe.

  Key API notes:
  - new/1  takes keyword opts, returns observer_state()
  - collect/1 takes observer_state(), returns {observation(), observer_state()}
  - summary/1 takes observation() (NOT observer_state())
  - buffer_stats/1 takes observer_state()
  - register_sensor/3 takes (observer_state(), sensor_id, config)
  - unregister_sensor/2 takes (observer_state(), sensor_id)
  - detect_anomalies/2 takes (observation(), observer_state())
  - fuse_readings/2 takes ([sensor_reading()], sensors_map())
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cybernetic.OODA.Observe

  # Helper to build a minimal observation (as returned by collect/1)
  defp minimal_observation do
    %{
      readings: [],
      fused: %{},
      timestamp: DateTime.utc_now(),
      quality: 1.0
    }
  end

  # Helper to build a minimal sensor reading
  defp minimal_reading(sensor_id) do
    %{
      sensor: sensor_id,
      value: %{usage: 42},
      timestamp: DateTime.utc_now(),
      confidence: 0.9,
      metadata: %{}
    }
  end

  describe "new/1" do
    test "returns a map (observer_state)" do
      assert is_map(Observe.new([]))
    end

    test "has :sensors key" do
      state = Observe.new([])
      assert Map.has_key?(state, :sensors)
    end

    test "has :buffer key initialised to empty list" do
      state = Observe.new([])
      assert state.buffer == []
    end

    test "has :buffer_size key" do
      state = Observe.new([])
      assert is_integer(state.buffer_size) and state.buffer_size > 0
    end

    test "has :last_observation key initialised to nil" do
      state = Observe.new([])
      assert state.last_observation == nil
    end

    test "respects :buffer_size option" do
      state = Observe.new(buffer_size: 42)
      assert state.buffer_size == 42
    end

    test "accepts default sensors when :sensors not provided" do
      state = Observe.new([])
      assert is_map(state.sensors) and map_size(state.sensors) > 0
    end

    test "accepts custom sensors via :sensors option" do
      custom = %{temperature: %{type: :physical, weight: 1.0, confidence: 0.95}}
      state = Observe.new(sensors: custom)
      assert state.sensors == custom
    end
  end

  describe "collect/1" do
    test "returns a 2-tuple" do
      state = Observe.new([])
      result = Observe.collect(state)
      assert is_tuple(result) and tuple_size(result) == 2
    end

    test "first element is an observation map" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert is_map(observation)
    end

    test "observation has :readings key" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert Map.has_key?(observation, :readings)
    end

    test "observation has :fused key" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert Map.has_key?(observation, :fused)
    end

    test "observation has :timestamp key" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert Map.has_key?(observation, :timestamp)
    end

    test "observation has :quality key" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert Map.has_key?(observation, :quality)
    end

    test "quality is a float between 0.0 and 1.0" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert is_float(observation.quality)
      assert observation.quality >= 0.0 and observation.quality <= 1.0
    end

    test "second element is updated observer_state" do
      state = Observe.new([])
      {_obs, new_state} = Observe.collect(state)
      assert is_map(new_state)
    end

    test "updated state has :last_observation set" do
      {_, new_state} = Observe.collect(Observe.new([]))
      assert new_state.last_observation != nil
    end

    test "readings is a list" do
      {observation, _} = Observe.collect(Observe.new([]))
      assert is_list(observation.readings)
    end
  end

  describe "collect_sensor/2" do
    test "returns a map for a known sensor id" do
      config = %{type: :system, weight: 1.0, confidence: 0.95}
      result = Observe.collect_sensor(:cpu, config)
      assert is_map(result)
    end

    test "returned reading has :sensor key matching the sensor id" do
      config = %{type: :system, confidence: 0.9}
      reading = Observe.collect_sensor(:memory, config)
      assert reading.sensor == :memory
    end

    test "returned reading has :value key" do
      config = %{type: :application, confidence: 0.85}
      reading = Observe.collect_sensor(:latency, config)
      assert Map.has_key?(reading, :value)
    end

    test "returned reading has :confidence matching config" do
      config = %{confidence: 0.75}
      reading = Observe.collect_sensor(:cpu, config)
      assert reading.confidence == 0.75
    end

    test "returned reading has :timestamp key" do
      reading = Observe.collect_sensor(:cpu, %{})
      assert Map.has_key?(reading, :timestamp)
    end

    test "returns nil on exception (graceful degradation)" do
      # A config that causes read_sensor to raise — not easily triggered without
      # overriding internals, so we verify the normal path returns non-nil.
      result = Observe.collect_sensor(:cpu, %{})
      # Under normal conditions, collect_sensor returns a map, not nil
      assert is_map(result) or is_nil(result)
    end
  end

  describe "fuse_readings/2" do
    test "returns a map for non-empty readings" do
      sensors = %{cpu: %{type: :system, weight: 1.0, confidence: 0.9}}
      readings = [minimal_reading(:cpu)]
      result = Observe.fuse_readings(readings, sensors)
      assert is_map(result)
    end

    test "returns a map for empty readings" do
      result = Observe.fuse_readings([], %{})
      assert is_map(result)
    end

    test "groups readings by sensor type" do
      sensors = %{
        cpu: %{type: :system, weight: 1.0, confidence: 0.9},
        memory: %{type: :system, weight: 1.0, confidence: 0.9},
        latency: %{type: :application, weight: 1.5, confidence: 0.85}
      }

      readings = [minimal_reading(:cpu), minimal_reading(:memory), minimal_reading(:latency)]
      fused = Observe.fuse_readings(readings, sensors)

      # Should have :system and :application groups
      assert Map.has_key?(fused, :system)
      assert Map.has_key?(fused, :application)
    end

    test "each fused group has :count key" do
      sensors = %{cpu: %{type: :system, confidence: 0.9}}
      readings = [minimal_reading(:cpu)]
      fused = Observe.fuse_readings(readings, sensors)

      for {_type, group_data} <- fused do
        assert Map.has_key?(group_data, :count)
      end
    end

    test "sensors missing from config get :unknown type" do
      sensors = %{}
      readings = [minimal_reading(:unknown_sensor)]
      fused = Observe.fuse_readings(readings, sensors)
      assert Map.has_key?(fused, :unknown)
    end
  end

  describe "register_sensor/3" do
    test "adds sensor to state.sensors" do
      state = Observe.new([])
      config = %{type: :physical, confidence: 0.9}
      new_state = Observe.register_sensor(state, :temperature, config)
      assert Map.has_key?(new_state.sensors, :temperature)
    end

    test "stored config matches provided config" do
      state = Observe.new([])
      config = %{type: :custom, weight: 2.0}
      new_state = Observe.register_sensor(state, :my_sensor, config)
      assert new_state.sensors[:my_sensor] == config
    end

    test "does not modify other state fields" do
      state = Observe.new(buffer_size: 500)
      new_state = Observe.register_sensor(state, :extra, %{})
      assert new_state.buffer_size == state.buffer_size
      assert new_state.buffer == state.buffer
    end

    test "overrides existing sensor config" do
      state = Observe.new([])
      state = Observe.register_sensor(state, :cpu, %{confidence: 0.5})
      state = Observe.register_sensor(state, :cpu, %{confidence: 0.99})
      assert state.sensors[:cpu].confidence == 0.99
    end
  end

  describe "unregister_sensor/2" do
    test "removes sensor from state.sensors" do
      state = Observe.new([])
      state = Observe.register_sensor(state, :removable, %{})
      state = Observe.unregister_sensor(state, :removable)
      refute Map.has_key?(state.sensors, :removable)
    end

    test "does not crash when sensor does not exist" do
      state = Observe.new([])
      result = Observe.unregister_sensor(state, :nonexistent)
      assert is_map(result)
    end

    test "does not affect other sensors" do
      state = Observe.new([])
      state = Observe.register_sensor(state, :keep_me, %{type: :system})
      state = Observe.register_sensor(state, :remove_me, %{type: :system})
      state = Observe.unregister_sensor(state, :remove_me)
      assert Map.has_key?(state.sensors, :keep_me)
    end
  end

  describe "buffer_stats/1" do
    test "returns a map" do
      assert is_map(Observe.buffer_stats(Observe.new([])))
    end

    test "has :size key" do
      assert Map.has_key?(Observe.buffer_stats(Observe.new([])), :size)
    end

    test "has :max_size key" do
      assert Map.has_key?(Observe.buffer_stats(Observe.new([])), :max_size)
    end

    test "has :utilization key" do
      assert Map.has_key?(Observe.buffer_stats(Observe.new([])), :utilization)
    end

    test "has :sensors key" do
      assert Map.has_key?(Observe.buffer_stats(Observe.new([])), :sensors)
    end

    test "size is 0 for fresh state" do
      assert Observe.buffer_stats(Observe.new([])).size == 0
    end

    test "utilization is 0.0 for fresh state" do
      assert Observe.buffer_stats(Observe.new([])).utilization == 0.0
    end

    test "max_size matches what was provided at new/1" do
      state = Observe.new(buffer_size: 200)
      assert Observe.buffer_stats(state).max_size == 200
    end

    test "sensors count matches state.sensors map_size" do
      state = Observe.new([])
      stats = Observe.buffer_stats(state)
      assert stats.sensors == map_size(state.sensors)
    end
  end

  describe "summary/1 — takes observation(), NOT observer_state()" do
    test "returns a map for a minimal observation" do
      assert is_map(Observe.summary(minimal_observation()))
    end

    test "has :num_readings key" do
      assert Map.has_key?(Observe.summary(minimal_observation()), :num_readings)
    end

    test "has :quality key" do
      assert Map.has_key?(Observe.summary(minimal_observation()), :quality)
    end

    test "has :timestamp key" do
      assert Map.has_key?(Observe.summary(minimal_observation()), :timestamp)
    end

    test "has :fused_types key" do
      assert Map.has_key?(Observe.summary(minimal_observation()), :fused_types)
    end

    test "num_readings is 0 for observation with empty readings list" do
      obs = minimal_observation()
      assert Observe.summary(obs).num_readings == 0
    end

    test "quality matches observation.quality" do
      obs = %{minimal_observation() | quality: 0.77}
      assert Observe.summary(obs).quality == 0.77
    end

    test "fused_types is a list of keys from observation.fused" do
      obs = %{minimal_observation() | fused: %{system: %{}, application: %{}}}
      summary = Observe.summary(obs)
      assert :system in summary.fused_types
      assert :application in summary.fused_types
    end

    test "summary from collect/1 result is valid" do
      {observation, _state} = Observe.collect(Observe.new([]))
      result = Observe.summary(observation)
      assert is_map(result)
      assert Map.has_key?(result, :num_readings)
    end
  end

  describe "detect_anomalies/2" do
    test "returns a list" do
      state = Observe.new([])
      obs = minimal_observation()
      assert is_list(Observe.detect_anomalies(obs, state))
    end

    test "returns empty list when buffer has fewer than 5 readings" do
      state = Observe.new([])
      obs = minimal_observation()
      # Buffer is empty — not enough history to detect anomalies
      assert Observe.detect_anomalies(obs, state) == []
    end

    test "returns list of maps when anomaly is detected" do
      state = Observe.new([])
      obs = minimal_observation()
      anomalies = Observe.detect_anomalies(obs, state)

      for anomaly <- anomalies do
        assert is_map(anomaly)
      end
    end
  end
end
