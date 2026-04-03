defmodule Indrajaal.Cortex.SensorTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.Sensor (behaviour).
  Tests behaviour definition — only @callback declarations exist.
  STAMP: SC-SENS-001, SC-COG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.Sensor

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Sensor)
    end

    test "module defines the measure/0 callback" do
      callbacks = Sensor.behaviour_info(:callbacks)
      assert {:measure, 0} in callbacks
    end

    test "module provides optional_callbacks list" do
      # Optional callbacks may be empty — just verify it doesn't crash
      optional = Sensor.behaviour_info(:optional_callbacks)
      assert is_list(optional)
    end
  end

  describe "behaviour contract" do
    test "a module implementing Sensor satisfies measure/0" do
      # Inline implementation to verify the behaviour contract compiles
      defmodule TestSensor do
        @behaviour Indrajaal.Cortex.Sensor
        @impl true
        def measure, do: %{cpu: 0.1, memory: 0.2}
      end

      assert Code.ensure_loaded?(TestSensor)
      result = TestSensor.measure()
      assert is_map(result)
    end
  end
end
