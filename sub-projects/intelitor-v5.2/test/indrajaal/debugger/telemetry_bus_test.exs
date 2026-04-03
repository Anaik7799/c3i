defmodule Indrajaal.Debugger.TelemetryBusTest do
  @moduledoc """
  TDG tests for Indrajaal.Debugger.TelemetryBus GenServer.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Debugger.TelemetryBus

  describe "TelemetryBus module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TelemetryBus)
    end

    test "start_link/1 is exported" do
      assert function_exported?(TelemetryBus, :start_link, 1)
    end

    test "emit_debugger/2 is exported" do
      assert function_exported?(TelemetryBus, :emit_debugger, 2)
    end

    test "emit/3 is exported" do
      assert function_exported?(TelemetryBus, :emit, 3)
    end

    test "subscribe/2 is exported" do
      assert function_exported?(TelemetryBus, :subscribe, 2)
    end

    test "unsubscribe/1 is exported" do
      assert function_exported?(TelemetryBus, :unsubscribe, 1)
    end

    test "stats/0 is exported" do
      assert function_exported?(TelemetryBus, :stats, 0)
    end

    test "circuit_open?/0 is exported" do
      assert function_exported?(TelemetryBus, :circuit_open?, 0)
    end
  end

  describe "TelemetryBus child_spec" do
    test "has child_spec/1" do
      assert function_exported?(TelemetryBus, :child_spec, 1)
    end
  end

  describe "TelemetryBus GenServer" do
    test "can start with unique name" do
      name = :"telemetry_bus_test_#{System.unique_integer([:positive])}"
      result = start_supervised({TelemetryBus, [name: name]})
      assert {:ok, _pid} = result
    end

    test "circuit_open?/0 returns boolean when running" do
      name = :"telemetry_bus_circuit_#{System.unique_integer([:positive])}"
      {:ok, _pid} = start_supervised({TelemetryBus, [name: name]})
      result = TelemetryBus.circuit_open?()
      assert is_boolean(result)
    end

    test "stats/0 returns map when running" do
      name = :"telemetry_bus_stats_#{System.unique_integer([:positive])}"
      {:ok, _pid} = start_supervised({TelemetryBus, [name: name]})
      stats = TelemetryBus.stats()
      assert is_map(stats)
    end
  end
end
