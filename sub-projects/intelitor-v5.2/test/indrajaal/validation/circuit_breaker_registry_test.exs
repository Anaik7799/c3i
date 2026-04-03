defmodule Indrajaal.Validation.CircuitBreakerRegistryTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.CircuitBreakerRegistry.

  Tests the Registry wrapper for circuit breaker processes.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.CircuitBreakerRegistry

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(CircuitBreakerRegistry)
    end

    test "child_spec/1 returns a valid spec" do
      spec = CircuitBreakerRegistry.child_spec([])
      assert is_map(spec)
    end

    test "child_spec has id field" do
      spec = CircuitBreakerRegistry.child_spec([])
      assert Map.has_key?(spec, :id)
    end

    test "child_spec has start field" do
      spec = CircuitBreakerRegistry.child_spec([])
      assert Map.has_key?(spec, :start)
    end
  end
end
