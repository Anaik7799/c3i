defmodule Prometheus.Gauge do
  @moduledoc """
  Prometheus.Gauge stub for metrics gauge functionality.

  This module provides Prometheus gauge metric operations.
  Created as a stub to resolve UNDEFINED_MODULE warnings during Phase 2.

  Prometheus gauges are metrics that can both increase and decrease.
  They are used for measuring current values like memory usage, temperature, etc.

  Functions to be implemented:
  - set/2 - Set gauge to a specific value
  """

  @doc """
  Set a gauge to a specific value.

  ## Parameters
  - name: Gauge metric name (atom or string)
  - value: Value to set the gauge to

  ## Returns
  - :ok on success
  - {:error, reason} on failure
  """
  @spec set(atom() | String.t(), number()) :: :ok | {:error, String.t()}
  def set(_name, _value) do
    # Stub implementation - does nothing for now
    :ok
  end
end
