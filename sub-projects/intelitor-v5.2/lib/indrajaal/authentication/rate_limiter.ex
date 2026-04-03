defmodule Indrajaal.Authentication.RateLimiter do
  @moduledoc """
  Facade for Rate Limiting.
  Delegates to Indrajaal.Security.RateLimiter.
  """

  # Delegate RateLimiter functions to the Security context
  defdelegate check_rate(key, action, opts), to: Indrajaal.Security.RateLimiter
end
