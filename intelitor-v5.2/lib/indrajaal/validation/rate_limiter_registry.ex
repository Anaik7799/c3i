defmodule Indrajaal.Validation.RateLimiterRegistry do
  @moduledoc """
  Registry for rate limiter processes.

  Provides a centralized registry for managing rate limiter processes
  per session, ensuring each session has its own rate limiter instance.
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end
