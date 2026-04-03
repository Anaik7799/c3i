defmodule Indrajaal.Cortex.Sensors.BeamSensorTest do
  @moduledoc """
  Tests for Indrajaal.Cortex.Sensors.BeamSensor.

  take_snapshot/0 is a pure read of BEAM introspection APIs.
  It returns a map with exactly these keys:
    :total_memory, :process_count, :process_utilization,
    :scheduler_usage, :atom_memory, :processes_memory, :timestamp
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cortex.Sensors.BeamSensor

  describe "take_snapshot/0 — return shape" do
    test "returns a map" do
      assert is_map(BeamSensor.take_snapshot())
    end

    test "has :total_memory key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :total_memory)
    end

    test "has :process_count key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :process_count)
    end

    test "has :process_utilization key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :process_utilization)
    end

    test "has :scheduler_usage key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :scheduler_usage)
    end

    test "has :atom_memory key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :atom_memory)
    end

    test "has :processes_memory key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :processes_memory)
    end

    test "has :timestamp key" do
      assert Map.has_key?(BeamSensor.take_snapshot(), :timestamp)
    end

    test "has exactly 7 keys" do
      assert map_size(BeamSensor.take_snapshot()) == 7
    end

    test "no key has a nil value" do
      snapshot = BeamSensor.take_snapshot()

      for {key, value} <- snapshot do
        assert value != nil, "Expected non-nil for key #{inspect(key)}"
      end
    end
  end

  describe "take_snapshot/0 — :total_memory" do
    test "total_memory is a positive integer (bytes)" do
      mem = BeamSensor.take_snapshot().total_memory
      assert is_integer(mem) and mem > 0
    end

    test "total_memory is at least 1 MB" do
      mem = BeamSensor.take_snapshot().total_memory
      assert mem >= 1_000_000, "Expected at least 1MB, got #{mem} bytes"
    end
  end

  describe "take_snapshot/0 — :process_count" do
    test "process_count is a positive integer" do
      count = BeamSensor.take_snapshot().process_count
      assert is_integer(count) and count > 0
    end

    test "process_count includes at least the current test process" do
      count = BeamSensor.take_snapshot().process_count
      assert count >= 1
    end
  end

  describe "take_snapshot/0 — :process_utilization" do
    test "process_utilization is a float" do
      assert is_float(BeamSensor.take_snapshot().process_utilization)
    end

    test "process_utilization is between 0.0 and 1.0 inclusive" do
      util = BeamSensor.take_snapshot().process_utilization

      assert util >= 0.0 and util <= 1.0,
             "Expected 0.0..1.0, got #{util}"
    end

    test "process_utilization is rounded to 4 decimal places" do
      util = BeamSensor.take_snapshot().process_utilization
      # Float.round(x, 4) means at most 4 digits after the decimal point
      rounded = Float.round(util, 4)
      assert util == rounded
    end
  end

  describe "take_snapshot/0 — :scheduler_usage" do
    test "scheduler_usage is a number" do
      usage = BeamSensor.take_snapshot().scheduler_usage
      assert is_number(usage)
    end

    test "scheduler_usage is non-negative" do
      assert BeamSensor.take_snapshot().scheduler_usage >= 0
    end
  end

  describe "take_snapshot/0 — :atom_memory" do
    test "atom_memory is a positive integer (bytes)" do
      mem = BeamSensor.take_snapshot().atom_memory
      assert is_integer(mem) and mem > 0
    end
  end

  describe "take_snapshot/0 — :processes_memory" do
    test "processes_memory is a positive integer (bytes)" do
      mem = BeamSensor.take_snapshot().processes_memory
      assert is_integer(mem) and mem > 0
    end
  end

  describe "take_snapshot/0 — :timestamp" do
    test "timestamp is an integer (system_time in ms)" do
      ts = BeamSensor.take_snapshot().timestamp
      assert is_integer(ts)
    end

    test "timestamp is a recent epoch millisecond (after year 2020)" do
      # 2020-01-01 in milliseconds
      ts_2020 = 1_577_836_800_000
      ts = BeamSensor.take_snapshot().timestamp
      assert ts > ts_2020, "Timestamp #{ts} looks wrong — before 2020"
    end

    test "two consecutive snapshots have non-decreasing timestamps" do
      ts1 = BeamSensor.take_snapshot().timestamp
      ts2 = BeamSensor.take_snapshot().timestamp
      assert ts2 >= ts1
    end
  end

  describe "take_snapshot/0 — consistency" do
    test "two snapshots have the same set of keys" do
      keys1 = BeamSensor.take_snapshot() |> Map.keys() |> Enum.sort()
      keys2 = BeamSensor.take_snapshot() |> Map.keys() |> Enum.sort()
      assert keys1 == keys2
    end

    test "calling take_snapshot/0 three times succeeds without crash" do
      for _i <- 1..3 do
        result = BeamSensor.take_snapshot()
        assert is_map(result)
      end
    end
  end
end
