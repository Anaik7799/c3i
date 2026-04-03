defmodule Indrajaal.Validation.CircuitBreakerRegistry do
  @moduledoc """
  Registry for circuit breaker processes.

  Provides centralized registry for managing circuit breaker instances
  for different API endpoints or services.
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end
