defmodule Indrajaal.AI.CostMonitorTest do
  @moduledoc """
  Tests for the CostMonitor GenServer.

  ## STAMP Constraints Verified
  - SC-DF-001: Budget enforcement
  - SC-DF-002: Rate limiting
  """

  use ExUnit.Case, async: false

  alias Indrajaal.AI.CostMonitor

  setup do
    # Start a fresh CostMonitor for each test
    case GenServer.whereis(CostMonitor) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid, :normal, 100)
        catch
          :exit, _ -> :ok
        end
    end

    # Small delay to ensure previous process is fully cleaned up
    Process.sleep(10)

    {:ok, pid} = CostMonitor.start_link([])

    on_exit(fn ->
      case GenServer.whereis(CostMonitor) do
        nil ->
          :ok

        p ->
          try do
            GenServer.stop(p, :normal, 100)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    {:ok, pid: pid}
  end

  describe "check_budget_and_rate/2" do
    test "allows request within budget" do
      assert :ok = CostMonitor.check_budget_and_rate("anthropic/claude-3.5-sonnet", 0.10)
    end

    test "rejects request exceeding per-request limit" do
      # Default per-request limit is $5
      assert {:error, :per_request_limit_exceeded} =
               CostMonitor.check_budget_and_rate("anthropic/claude-3-opus", 6.0)
    end

    test "rejects request when daily budget exhausted" do
      # Record a lot of usage to exhaust daily budget
      for _ <- 1..51 do
        CostMonitor.record_usage("test/model", :test, 1.0, 1000)
      end

      assert {:error, :daily_budget_exceeded} =
               CostMonitor.check_budget_and_rate("test/model", 0.10)
    end
  end

  describe "record_usage/4" do
    test "tracks usage by model" do
      CostMonitor.record_usage("anthropic/claude-3.5-sonnet", :test, 0.50, 1000)
      CostMonitor.record_usage("anthropic/claude-3.5-sonnet", :test, 0.25, 500)

      stats = CostMonitor.get_stats()
      model_usage = stats.usage_by_model["anthropic/claude-3.5-sonnet"]

      assert model_usage.total_cost == 0.75
      assert model_usage.total_tokens == 1500
      assert model_usage.request_count == 2
    end

    test "tracks usage by source" do
      CostMonitor.record_usage("test/model", :cortex, 0.10, 100)
      CostMonitor.record_usage("test/model", :cortex, 0.20, 200)
      CostMonitor.record_usage("test/model", :gde, 0.15, 150)

      stats = CostMonitor.get_stats()

      # Use assert_in_delta for floating point comparison
      assert_in_delta stats.usage_by_source.cortex, 0.30, 0.001
      assert_in_delta stats.usage_by_source.gde, 0.15, 0.001
    end

    test "updates daily total" do
      CostMonitor.record_usage("test/model", :test, 1.50, 1000)

      stats = CostMonitor.get_stats()
      assert stats.daily_usage == 1.50
    end
  end

  describe "get_stats/0" do
    test "returns current statistics" do
      stats = CostMonitor.get_stats()

      assert Map.has_key?(stats, :daily_usage)
      assert Map.has_key?(stats, :monthly_usage)
      assert Map.has_key?(stats, :daily_budget)
      assert Map.has_key?(stats, :monthly_budget)
      assert Map.has_key?(stats, :usage_by_model)
      assert Map.has_key?(stats, :usage_by_source)
    end

    test "reflects recorded usage" do
      CostMonitor.record_usage("test/model", :test, 2.50, 2000)

      stats = CostMonitor.get_stats()

      assert stats.daily_usage == 2.50
      assert stats.monthly_usage == 2.50
    end
  end

  describe "configure/1" do
    test "updates daily budget" do
      CostMonitor.configure(daily_budget: 100.0)

      stats = CostMonitor.get_stats()
      assert stats.daily_budget == 100.0
    end

    test "updates monthly budget" do
      CostMonitor.configure(monthly_budget: 2000.0)

      stats = CostMonitor.get_stats()
      assert stats.monthly_budget == 2000.0
    end

    test "updates rate limit" do
      CostMonitor.configure(rate_limit_per_minute: 200)

      stats = CostMonitor.get_stats()
      assert stats.rate_limit_per_minute == 200
    end
  end

  describe "check_rate_limit/0" do
    test "allows requests within rate limit" do
      assert :ok = CostMonitor.check_rate_limit()
    end

    test "rejects when rate limit exceeded" do
      # Default is 100 requests per minute
      for _ <- 1..101 do
        CostMonitor.check_rate_limit()
      end

      assert {:error, :rate_limit_exceeded} = CostMonitor.check_rate_limit()
    end
  end
end
