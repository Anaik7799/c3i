defmodule Prometheus.Counter do
  @moduledoc """
  Prometheus.Counter stub for metrics counter functionality.

  This module provides Prometheus counter metric operations.
  Created as a stub to resolve UNDEFINED_MODULE warnings during Phase 2.

  Prometheus counters are cumulative metrics that only increase.
  They are used for counting events, requests, errors, etc.

  Functions to be implemented:
  - inc/1 - Increment counter by 1
  - inc/2 - Increment counter by specified value
  """

  @doc """
  Increment a counter by 1.

  ## Parameters
  - name: Counter metric name (atom or string)

  ## Returns
  - :ok on success
  - {:error, reason} on failure
  """
  @spec inc(atom() | String.t()) :: :ok | {:error, String.t()}
  def inc(_name) do
    # Stub implementation - does nothing for now
    :ok
  end

  @doc """
  Increment a counter by a specified value.

  ## Parameters
  - name: Counter metric name (atom or string)
  - value: Amount to increment by (must be positive)

  ## Returns
  - :ok on success
  - {:error, reason} on failure
  """
  @spec inc(atom() | String.t(), number()) :: :ok | {:error, String.t()}
  def inc(_name, _value) do
    # Stub implementation - does nothing for now
    :ok
  end
end
