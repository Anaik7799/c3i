defmodule Indrajaal.Validation.CircuitBreakerTest do
  @moduledoc """
  TDG tests for Indrajaal.Validation.CircuitBreaker.

  Tests the circuit breaker pattern for OpenCode API client.
  Protects against cascading failures.
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Validation.CircuitBreaker
  alias Indrajaal.Validation.CircuitBreakerRegistry

  setup do
    # Start registry if not running
    case Registry.start_link(keys: :unique, name: CircuitBreakerRegistry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    name = :"test_cb_#{System.unique_integer([:positive])}"
    {:ok, _pid} = CircuitBreaker.start_link(name: name)
    {:ok, cb_name: name}
  end

  describe "start_link/1" do
    test "starts circuit breaker with unique name", %{cb_name: name} do
      assert is_atom(name)
    end

    test "starts in closed state", %{cb_name: name} do
      {state, _info} = CircuitBreaker.get_state(name)
      assert state == :closed
    end
  end

  describe "call/2" do
    test "executes function and returns result", %{cb_name: name} do
      result = CircuitBreaker.call(name, fn -> {:ok, :value} end)
      assert result == {:ok, :value}
    end

    test "returns error on function failure", %{cb_name: name} do
      result = CircuitBreaker.call(name, fn -> {:error, :bad_thing} end)
      assert result == {:error, :bad_thing}
    end

    test "wraps non-tagged return as ok", %{cb_name: name} do
      result = CircuitBreaker.call(name, fn -> 42 end)
      assert result == {:ok, 42}
    end

    test "handles exception in function", %{cb_name: name} do
      result = CircuitBreaker.call(name, fn -> raise "boom" end)
      assert match?({:error, _}, result)
    end
  end

  describe "get_state/1" do
    test "returns tuple with state and info map", %{cb_name: name} do
      {state, info} = CircuitBreaker.get_state(name)
      assert state in [:closed, :open, :half_open]
      assert is_map(info)
    end

    test "info map contains failures key", %{cb_name: name} do
      {_state, info} = CircuitBreaker.get_state(name)
      assert Map.has_key?(info, :failures)
    end

    test "info map contains successes key", %{cb_name: name} do
      {_state, info} = CircuitBreaker.get_state(name)
      assert Map.has_key?(info, :successes)
    end

    test "returns error when circuit breaker not started" do
      result = CircuitBreaker.get_state(:nonexistent_cb_xyz)
      assert result == {:error, :not_started}
    end
  end

  describe "reset/1" do
    test "resets to closed state", %{cb_name: name} do
      # Trip first
      CircuitBreaker.trip(name)
      # Reset
      CircuitBreaker.reset(name)
      {state, _} = CircuitBreaker.get_state(name)
      assert state == :closed
    end

    test "returns ok", %{cb_name: name} do
      assert :ok = CircuitBreaker.reset(name)
    end

    test "returns error when not started" do
      result = CircuitBreaker.reset(:nonexistent_cb_xyz)
      assert result == {:error, :not_started}
    end
  end

  describe "trip/1" do
    test "opens circuit breaker", %{cb_name: name} do
      CircuitBreaker.trip(name)
      {state, _} = CircuitBreaker.get_state(name)
      assert state == :open
    end

    test "returns ok", %{cb_name: name} do
      assert :ok = CircuitBreaker.trip(name)
    end

    test "tripped circuit fails fast", %{cb_name: name} do
      CircuitBreaker.trip(name)
      result = CircuitBreaker.call(name, fn -> {:ok, :value} end)
      assert match?({:error, :circuit_open}, result)
    end
  end
end
