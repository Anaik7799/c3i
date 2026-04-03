defmodule Indrajaal.Authentication.RateLimiterTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Authentication.RateLimiter

  test "module exists" do
    assert Code.ensure_loaded?(RateLimiter)
  end

  test "check_rate_limit/2 is exported" do
    assert function_exported?(RateLimiter, :check_rate_limit, 2)
  end
end
