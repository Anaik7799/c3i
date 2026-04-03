defmodule Indrajaal.Cybernetic.OODA.ObserverTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.OODA.Observer.

  observe/1 aggregates telemetry from Sentinel, BeamSensor, and FLAME into a
  unified observation map with these keys:
    :cluster_status, :active_nodes,
    :memory_usage, :process_count, :process_utilization, :cpu_usage,
    :flame_runners,
    :queue_depth, :latency_p99, :error_rate,
    :timestamp, :data_quality

  Sentinel may not be running in tests; the module catches the exit and uses
  %{status: :unknown, active_count: 0} as fallback.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cybernetic.OODA.Observer

  describe "observe/1 — return shape" do
    test "returns a map" do
      assert is_map(Observer.observe(%{}))
    end

    test "has :cluster_status key" do
      assert Map.has_key?(Observer.observe(%{}), :cluster_status)
    end

    test "has :active_nodes key" do
      assert Map.has_key?(Observer.observe(%{}), :active_nodes)
    end

    test "has :memory_usage key" do
      assert Map.has_key?(Observer.observe(%{}), :memory_usage)
    end

    test "has :process_count key" do
      assert Map.has_key?(Observer.observe(%{}), :process_count)
    end

    test "has :process_utilization key" do
      assert Map.has_key?(Observer.observe(%{}), :process_utilization)
    end

    test "has :cpu_usage key" do
      assert Map.has_key?(Observer.observe(%{}), :cpu_usage)
    end

    test "has :flame_runners key" do
      assert Map.has_key?(Observer.observe(%{}), :flame_runners)
    end

    test "has :queue_depth key" do
      assert Map.has_key?(Observer.observe(%{}), :queue_depth)
    end

    test "has :latency_p99 key" do
      assert Map.has_key?(Observer.observe(%{}), :latency_p99)
    end

    test "has :error_rate key" do
      assert Map.has_key?(Observer.observe(%{}), :error_rate)
    end

    test "has :timestamp key" do
      assert Map.has_key?(Observer.observe(%{}), :timestamp)
    end

    test "has :data_quality key" do
      assert Map.has_key?(Observer.observe(%{}), :data_quality)
    end

    test "has exactly 12 keys" do
      assert map_size(Observer.observe(%{})) == 12
    end

    test "no value is nil" do
      obs = Observer.observe(%{})

      for {key, value} <- obs do
        assert value != nil, "Expected non-nil value for key #{inspect(key)}"
      end
    end
  end

  describe "observe/1 — VM metrics (from BeamSensor)" do
    test "memory_usage is a positive integer" do
      mem = Observer.observe(%{}).memory_usage
      assert is_integer(mem) and mem > 0
    end

    test "process_count is a positive integer" do
      count = Observer.observe(%{}).process_count
      assert is_integer(count) and count > 0
    end

    test "process_utilization is a float between 0 and 1" do
      util = Observer.observe(%{}).process_utilization
      assert is_float(util) and util >= 0.0 and util <= 1.0
    end

    test "cpu_usage is a number" do
      assert is_number(Observer.observe(%{}).cpu_usage)
    end
  end

  describe "observe/1 — cluster metrics" do
    test "cluster_status is an atom" do
      assert is_atom(Observer.observe(%{}).cluster_status)
    end

    test "active_nodes is a non-negative integer" do
      nodes = Observer.observe(%{}).active_nodes
      assert is_integer(nodes) and nodes >= 0
    end
  end

  describe "observe/1 — FLAME metrics" do
    test "flame_runners is a non-negative integer" do
      runners = Observer.observe(%{}).flame_runners
      assert is_integer(runners) and runners >= 0
    end
  end

  describe "observe/1 — legacy metrics" do
    test "queue_depth is 0 (stub value)" do
      assert Observer.observe(%{}).queue_depth == 0
    end

    test "latency_p99 is 0 (stub value)" do
      assert Observer.observe(%{}).latency_p99 == 0
    end

    test "error_rate is 0 (stub value)" do
      assert Observer.observe(%{}).error_rate == 0
    end
  end

  describe "observe/1 — :timestamp" do
    test "timestamp is an integer" do
      assert is_integer(Observer.observe(%{}).timestamp)
    end

    test "timestamp is in epoch seconds (after year 2020)" do
      # 2020-01-01 in seconds
      ts_2020_sec = 1_577_836_800
      ts = Observer.observe(%{}).timestamp
      assert ts > ts_2020_sec, "Timestamp #{ts} looks wrong — before 2020 in seconds"
    end
  end

  describe "observe/1 — :data_quality" do
    test "data_quality is an integer" do
      assert is_integer(Observer.observe(%{}).data_quality)
    end

    test "data_quality is one of the valid values: 0, 50, 60, 100" do
      # Valid values per the case expression in the implementation
      valid = [0, 50, 60, 100]
      dq = Observer.observe(%{}).data_quality
      assert dq in valid, "Expected quality in #{inspect(valid)}, got #{dq}"
    end

    test "data_quality is >= 0" do
      assert Observer.observe(%{}).data_quality >= 0
    end
  end

  describe "observe/1 — accepts any context" do
    test "accepts empty map context" do
      assert is_map(Observer.observe(%{}))
    end

    test "accepts populated context map" do
      assert is_map(Observer.observe(%{extra: :data, foo: 42}))
    end

    test "two calls return the same set of keys" do
      keys1 = Observer.observe(%{}) |> Map.keys() |> Enum.sort()
      keys2 = Observer.observe(%{}) |> Map.keys() |> Enum.sort()
      assert keys1 == keys2
    end
  end
end
