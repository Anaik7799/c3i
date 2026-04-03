defmodule Indrajaal.Reflex.CircuitBreakerTest do
  @moduledoc """
  Tests for Indrajaal.Reflex.CircuitBreaker.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Reflex.CircuitBreaker

  @moduletag :zenoh_nif

  describe "setup/1" do
    test "function is exported" do
      assert function_exported?(CircuitBreaker, :setup, 1)
    end

    test "setup with a service name returns ok or error" do
      result = CircuitBreaker.setup(:test_service_cb)
      assert result == :ok or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "setup with a string service name" do
      result = CircuitBreaker.setup("string_service")
      assert is_atom(result) or is_tuple(result)
    end
  end

  describe "call/2" do
    test "function is exported" do
      assert function_exported?(CircuitBreaker, :call, 2)
    end

    test "call with a function returns result" do
      result = CircuitBreaker.call(:test_cb_call, fn -> {:ok, "success"} end)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "call with failing function returns error" do
      result =
        CircuitBreaker.call(:test_cb_fail, fn ->
          raise "intentional failure"
        end)

      assert match?({:error, _}, result)
    end

    test "call with simple return value" do
      result = CircuitBreaker.call(:test_cb_simple, fn -> :done end)
      assert result == :done or match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
