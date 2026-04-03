defmodule RateLimitTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(RateLimit)
  end

  test "check_limit/1 is exported" do
    assert function_exported?(RateLimit, :check_limit, 1)
  end

  test "check_limit/1 returns error tuple (stub)" do
    assert {:error, _} = RateLimit.check_limit("user-123")
  end
end
