defmodule Indrajaal.Validation.RateLimiterRegistryTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.RateLimiterRegistry.

  Tests the Registry wrapper for rate limiter processes.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.RateLimiterRegistry

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(RateLimiterRegistry)
    end

    test "child_spec/1 returns a valid spec" do
      spec = RateLimiterRegistry.child_spec([])
      assert is_map(spec)
    end

    test "child_spec has id field" do
      spec = RateLimiterRegistry.child_spec([])
      assert Map.has_key?(spec, :id)
    end

    test "child_spec has start field" do
      spec = RateLimiterRegistry.child_spec([])
      assert Map.has_key?(spec, :start)
    end
  end
end
