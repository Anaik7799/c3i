defmodule Indrajaal.CircuitBreakerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.CircuitBreaker

  test "module exists" do
    assert Code.ensure_loaded?(CircuitBreaker)
  end

  test "get_state/1 is exported" do
    assert function_exported?(CircuitBreaker, :get_state, 1)
  end

  test "healthy?/1 is exported" do
    assert function_exported?(CircuitBreaker, :healthy?, 1)
  end
end
