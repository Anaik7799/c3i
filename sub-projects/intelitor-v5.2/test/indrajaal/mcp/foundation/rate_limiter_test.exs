defmodule Indrajaal.MCP.Foundation.RateLimiterTest do
  @moduledoc """
  Unit tests for MCP Foundation RateLimiter module.

  WHAT: Tests sliding window rate limiting, burst control, and concurrent access.
  WHY: Ensures SC-MCP-062 (rate limiting) and SC-API-001 (backoff).

  STAMP Constraints:
  - SC-MCP-062: Rate limiting per client
  - SC-API-001: Exponential backoff on 429
  - SC-API-002: Well-behaved client
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.MCP.Foundation.RateLimiter

  setup do
    table = :"rate_test_#{System.unique_integer([:positive])}"
    :ets.new(table, [:named_table, :public, :set])
    {:ok, table: table}
  end

  describe "check_rate/3 - sliding window" do
    test "allows first request", %{table: table} do
      client = "client-1"

      assert {:ok, %{remaining: _, reset_at: _}} =
               RateLimiter.check_rate(client, table, limit: 10, window_ms: 1000)
    end

    test "tracks request count within window", %{table: table} do
      client = "client-track"

      for i <- 1..5 do
        {:ok, %{remaining: remaining}} =
          RateLimiter.check_rate(client, table, limit: 10, window_ms: 60_000)

        assert remaining == 10 - i
      end
    end

    test "rejects requests over limit", %{table: table} do
      client = "client-over"

      # Exhaust the limit
      for _ <- 1..10 do
        RateLimiter.check_rate(client, table, limit: 10, window_ms: 60_000)
      end

      assert {:error, :rate_limited, %{retry_after_ms: _}} =
               RateLimiter.check_rate(client, table, limit: 10, window_ms: 60_000)
    end

    test "different clients have independent limits", %{table: table} do
      for _ <- 1..5 do
        RateLimiter.check_rate("client-a", table, limit: 5, window_ms: 60_000)
      end

      # client-a is at limit, but client-b should still work
      assert {:ok, _} = RateLimiter.check_rate("client-b", table, limit: 5, window_ms: 60_000)
    end
  end

  describe "check_rate/3 - burst control" do
    test "allows burst within burst limit", %{table: table} do
      client = "burst-client"

      results =
        for _ <- 1..3 do
          RateLimiter.check_rate(client, table, limit: 10, window_ms: 60_000, burst: 5)
        end

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end

  describe "reset/2" do
    test "clears rate limit for a client", %{table: table} do
      client = "reset-client"

      # Use up some quota
      for _ <- 1..5 do
        RateLimiter.check_rate(client, table, limit: 10, window_ms: 60_000)
      end

      # Reset
      :ok = RateLimiter.reset(client, table)

      # Should have full quota again
      {:ok, %{remaining: remaining}} =
        RateLimiter.check_rate(client, table, limit: 10, window_ms: 60_000)

      assert remaining == 9
    end
  end

  describe "concurrent access" do
    test "handles concurrent requests safely", %{table: table} do
      client = "concurrent-client"

      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            RateLimiter.check_rate(client, table, limit: 100, window_ms: 60_000)
          end)
        end

      results = Task.await_many(tasks, 5000)

      ok_count =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      assert ok_count == 20
    end
  end

  describe "property tests" do
    property "remaining count never exceeds limit" do
      forall limit <- PC.pos_integer() do
        table = :"prop_rate_#{System.unique_integer([:positive])}"
        :ets.new(table, [:named_table, :public, :set])
        client = "prop-client"
        safe_limit = min(limit, 1000)

        {:ok, %{remaining: remaining}} =
          RateLimiter.check_rate(client, table, limit: safe_limit, window_ms: 60_000)

        :ets.delete(table)
        remaining < safe_limit
      end
    end

    property "rate limiter is deterministic for same state" do
      ExUnitProperties.check all(
                               limit <- SD.integer(1..100),
                               window <- SD.integer(1000..60_000)
                             ) do
        table = :"prop_det_#{System.unique_integer([:positive])}"
        :ets.new(table, [:named_table, :public, :set])

        result1 = RateLimiter.check_rate("det-client", table, limit: limit, window_ms: window)
        :ets.delete(table)

        table2 = :"prop_det2_#{System.unique_integer([:positive])}"
        :ets.new(table2, [:named_table, :public, :set])

        result2 = RateLimiter.check_rate("det-client", table2, limit: limit, window_ms: window)
        :ets.delete(table2)

        # Both should succeed with same remaining count
        assert {:ok, %{remaining: r1}} = result1
        assert {:ok, %{remaining: r2}} = result2
        assert r1 == r2
      end
    end
  end
end
