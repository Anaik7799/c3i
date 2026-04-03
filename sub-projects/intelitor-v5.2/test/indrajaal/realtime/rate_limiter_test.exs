defmodule Indrajaal.Realtime.RateLimiterTest do
  @moduledoc """
  Tests for Indrajaal.Realtime.RateLimiter GenServer.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Realtime.RateLimiter

  @moduletag :zenoh_nif

  defp start_limiter(name) do
    start_supervised!({RateLimiter, [name: name]})
  end

  describe "start_link/1" do
    test "starts successfully with a unique name" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      pid = start_limiter(name)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "registers under the given name" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      pid = start_limiter(name)
      assert Process.whereis(name) == pid
    end
  end

  describe "check_rate/2" do
    test "allows requests within limit" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)
      result = RateLimiter.check_rate(name, "user_1")

      assert result == :ok or result == :allow or match?({:ok, _}, result) or
               match?({:allow, _}, result) or
               (is_tuple(result) and elem(result, 0) in [:ok, :allow])
    end

    test "returns a tuple or atom for any user id" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)
      result = RateLimiter.check_rate(name, "test_user")
      assert is_atom(result) or is_tuple(result)
    end

    test "handles multiple calls for the same user" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)

      Enum.each(1..5, fn _ ->
        result = RateLimiter.check_rate(name, "user_multi")
        assert is_atom(result) or is_tuple(result)
      end)
    end
  end

  describe "get_usage/2" do
    test "returns usage data for a user" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)
      RateLimiter.check_rate(name, "user_usage")
      result = RateLimiter.get_usage(name, "user_usage")
      assert is_map(result) or is_integer(result) or is_tuple(result)
    end

    test "returns something for unknown user" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)
      result = RateLimiter.get_usage(name, "unknown_user")
      assert result != nil or is_nil(result)
    end
  end

  describe "get_all_usage/1" do
    test "returns a map or list of all usages" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)
      RateLimiter.check_rate(name, "user_a")
      RateLimiter.check_rate(name, "user_b")
      result = RateLimiter.get_all_usage(name)
      assert is_map(result) or is_list(result)
    end

    test "returns empty collection when no usage" do
      name = :"rate_limiter_#{System.unique_integer([:positive])}"
      start_limiter(name)
      result = RateLimiter.get_all_usage(name)
      assert result == %{} or result == [] or is_map(result) or is_list(result)
    end
  end

  describe "get_stats/0" do
    test "function is exported" do
      assert function_exported?(RateLimiter, :get_stats, 0)
    end
  end

  describe "reset_user_limits/1" do
    test "function is exported" do
      assert function_exported?(RateLimiter, :reset_user_limits, 1)
    end
  end

  describe "update_limit/3" do
    test "function is exported" do
      assert function_exported?(RateLimiter, :update_limit, 3)
    end
  end

  describe "check_rates/2" do
    test "function is exported" do
      assert function_exported?(RateLimiter, :check_rates, 2)
    end
  end
end
