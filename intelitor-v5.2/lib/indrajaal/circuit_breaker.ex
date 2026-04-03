defmodule Indrajaal.CircuitBreaker do
  @moduledoc """
  Circuit breaker facade delegating to Cortex implementation.

  WHAT: Provides circuit breaker pattern for external service calls.
  WHY: SC-PRF-055 requires graceful degradation on service failures.
  CONSTRAINTS: Non-blocking, configurable thresholds.
  """

  alias Indrajaal.Cortex.Reflexes.CircuitBreaker, as: CortexCB

  # Delegate to Cortex implementation
  defdelegate call(name, fun), to: CortexCB
  defdelegate status(name), to: CortexCB
  defdelegate reset(name), to: CortexCB

  @doc """
  Legacy call/1 for backwards compatibility.
  Accepts a map with :service_name and :operation keys.
  """
  def call(%{service_name: service_name, operation: operation}) do
    call(service_name, operation)
  end

  def call(%{} = opts) do
    service_name = Map.get(opts, :service_name, :default)
    operation = Map.get(opts, :operation, fn -> {:ok, nil} end)
    call(service_name, operation)
  end

  @doc """
  Get the state of a circuit breaker.
  Returns {:ok, state_info} or {:error, :not_found}.
  """
  def get_state(name) do
    status(name)
  end

  # Convenience functions
  def healthy?(name) do
    case status(name) do
      {:ok, %{state: :closed}} -> true
      _ -> false
    end
  end

  def open?(name) do
    case status(name) do
      {:ok, %{state: :open}} -> true
      _ -> false
    end
  end

  def half_open?(name) do
    case status(name) do
      {:ok, %{state: :half_open}} -> true
      _ -> false
    end
  end
end
