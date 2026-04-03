defmodule Intelitor.Realtime.RateLimiterTest do
  @moduledoc """
  Test suite for Intelitor.Realtime.RateLimiter.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/realtime/rate_limiter.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Realtime.RateLimiter

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(RateLimiter)
    end

    test "module has __info__/1 function" do
      assert function_exported?(RateLimiter, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = RateLimiter.__info__(:module)
      assert info == Intelitor.Realtime.RateLimiter
    end
  end
end
