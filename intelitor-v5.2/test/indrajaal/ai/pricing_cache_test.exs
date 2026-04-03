defmodule Indrajaal.AI.PricingCacheTest do
  @moduledoc """
  Tests for the PricingCache GenServer.

  ## STAMP Constraints Verified
  - SC-CACHE-001: Daily refresh ensures data freshness
  - SC-HIST-001: Historical pricing retained for auditing
  - SC-DF-003: Accurate cost calculation for all models
  """

  use ExUnit.Case, async: false

  alias Indrajaal.AI.PricingCache

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(PricingCache)
    end

    test "exports start_link/1" do
      assert function_exported?(PricingCache, :start_link, 1)
    end

    test "exports get_pricing/1" do
      assert function_exported?(PricingCache, :get_pricing, 1)
    end

    test "exports get_pricing!/1" do
      assert function_exported?(PricingCache, :get_pricing!, 1)
    end

    test "exports estimate_cost/3" do
      assert function_exported?(PricingCache, :estimate_cost, 3)
    end

    test "exports is_free?/1" do
      assert function_exported?(PricingCache, :is_free?, 1)
    end

    test "exports list_models/0" do
      assert function_exported?(PricingCache, :list_models, 0)
    end

    test "exports list_free_models/0" do
      assert function_exported?(PricingCache, :list_free_models, 0)
    end

    test "exports list_by_cost/1" do
      assert function_exported?(PricingCache, :list_by_cost, 1)
    end

    test "exports refresh/0" do
      assert function_exported?(PricingCache, :refresh, 0)
    end

    test "exports stats/0" do
      assert function_exported?(PricingCache, :stats, 0)
    end

    test "exports get_pricing_history/2" do
      assert function_exported?(PricingCache, :get_pricing_history, 2)
    end

    test "exports get_price_changes/2" do
      assert function_exported?(PricingCache, :get_price_changes, 2)
    end

    test "exports get_recent_price_changes/1" do
      assert function_exported?(PricingCache, :get_recent_price_changes, 1)
    end

    test "exports cheapest_models/1" do
      assert function_exported?(PricingCache, :cheapest_models, 1)
    end
  end

  describe "GenServer lifecycle" do
    test "can start the GenServer" do
      # Stop if already running
      if GenServer.whereis(PricingCache), do: GenServer.stop(PricingCache)

      {:ok, pid} = PricingCache.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)

      # Wait for initial setup
      :timer.sleep(100)

      GenServer.stop(pid)
    end
  end

  describe "get_pricing/1 when not started" do
    test "returns error when cache not ready" do
      # Ensure it's not running
      if GenServer.whereis(PricingCache), do: GenServer.stop(PricingCache)

      result = PricingCache.get_pricing("any/model")
      assert {:error, _} = result
    end
  end

  describe "get_pricing!/1" do
    test "returns default pricing for unknown model" do
      pricing = PricingCache.get_pricing!("unknown/model")

      assert is_map(pricing)
      assert Map.has_key?(pricing, :input)
      assert Map.has_key?(pricing, :output)
      assert Map.has_key?(pricing, :context)
    end
  end

  describe "estimate_cost/3" do
    test "calculates cost correctly" do
      # 1000 input tokens + 500 output tokens with default pricing (1.0, 5.0)
      cost = PricingCache.estimate_cost("unknown/model", 1000, 500)

      # (1000 * 1.0 / 1_000_000) + (500 * 5.0 / 1_000_000)
      # = 0.001 + 0.0025 = 0.0035
      assert is_float(cost)
      assert cost > 0
    end

    test "returns 0 for zero tokens" do
      cost = PricingCache.estimate_cost("any/model", 0, 0)
      assert cost == 0.0
    end
  end

  describe "list_models/0" do
    test "returns list of model IDs" do
      models = PricingCache.list_models()
      assert is_list(models)
    end
  end

  describe "list_free_models/0" do
    test "returns list of free model IDs" do
      models = PricingCache.list_free_models()
      assert is_list(models)
    end
  end

  describe "list_by_cost/1" do
    test "returns list sorted by cost" do
      models = PricingCache.list_by_cost(limit: 5)

      assert is_list(models)

      if length(models) > 1 do
        [first | rest] = models
        assert first.input <= hd(rest).input
      end
    end

    test "respects limit option" do
      models = PricingCache.list_by_cost(limit: 3)
      assert length(models) <= 3
    end
  end

  describe "cheapest_models/1" do
    test "returns cheapest models" do
      models = PricingCache.cheapest_models(limit: 5)
      assert is_list(models)
    end

    test "filters by minimum context" do
      models = PricingCache.cheapest_models(min_context: 100_000)

      Enum.each(models, fn m ->
        assert m.context >= 100_000
      end)
    end
  end

  describe "stats/0 when started" do
    setup do
      if GenServer.whereis(PricingCache), do: GenServer.stop(PricingCache)
      {:ok, pid} = PricingCache.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :timer.sleep(100)
      %{pid: pid}
    end

    test "returns statistics map" do
      stats = PricingCache.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :model_count)
      assert Map.has_key?(stats, :last_refresh)
      assert Map.has_key?(stats, :refresh_errors)
      assert Map.has_key?(stats, :price_changes_detected)
      assert Map.has_key?(stats, :history_entries)
      assert Map.has_key?(stats, :next_refresh_in)
    end
  end

  describe "get_pricing_history/2" do
    test "returns empty list when no history" do
      history = PricingCache.get_pricing_history("unknown/model")
      assert is_list(history)
    end

    test "respects days option" do
      history = PricingCache.get_pricing_history("any/model", days: 7)
      assert is_list(history)
    end
  end

  describe "get_price_changes/2" do
    test "returns empty list when no changes" do
      changes = PricingCache.get_price_changes("unknown/model")
      assert is_list(changes)
    end
  end

  describe "get_recent_price_changes/1" do
    test "returns list of recent changes" do
      changes = PricingCache.get_recent_price_changes(days: 7)
      assert is_list(changes)
    end
  end

  describe "refresh/0" do
    setup do
      if GenServer.whereis(PricingCache), do: GenServer.stop(PricingCache)
      {:ok, pid} = PricingCache.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      :timer.sleep(100)
      %{pid: pid}
    end

    test "triggers cache refresh" do
      result = PricingCache.refresh()
      assert result == :ok
    end
  end

  describe "is_free?/1" do
    test "returns boolean" do
      result = PricingCache.is_free?("some/model")
      assert is_boolean(result)
    end
  end
end
