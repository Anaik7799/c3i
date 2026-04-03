defmodule Indrajaal.Cortex.Sensor do
  @moduledoc """
  Behaviour for Cortex Sensors.
  Defines the contract for collecting metrics from various system components.
  """
  @callback measure() :: map()
end
