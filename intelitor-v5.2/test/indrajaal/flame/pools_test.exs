defmodule Indrajaal.FLAME.PoolsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FLAME.Pools

  describe "pools/0" do
    test "returns exactly 3 pool configurations" do
      pools = Pools.pools()
      assert length(pools) == 3
    end

    test "each pool has all required keys" do
      required_keys = [:name, :min, :max, :max_concurrency, :idle_shutdown_after, :log]

      for pool <- Pools.pools() do
        for key <- required_keys do
          assert Map.has_key?(pool, key),
                 "pool #{inspect(pool[:name])} missing key #{inspect(key)}"
        end
      end
    end

    test "pool names are the expected module atoms" do
      names = Pools.pools() |> Enum.map(& &1.name)
      assert Indrajaal.FLAME.IntelligencePool in names
      assert Indrajaal.FLAME.VideoPool in names
      assert Indrajaal.FLAME.AnalyticsPool in names
    end

    test "all pool names are unique" do
      names = Pools.pools() |> Enum.map(& &1.name)
      assert length(names) == length(Enum.uniq(names))
    end

    test "min is non-negative for all pools" do
      for pool <- Pools.pools() do
        assert pool.min >= 0,
               "pool #{inspect(pool[:name])} has negative min: #{pool.min}"
      end
    end

    test "max is greater than zero for all pools" do
      for pool <- Pools.pools() do
        assert pool.max > 0,
               "pool #{inspect(pool[:name])} has non-positive max: #{pool.max}"
      end
    end

    test "min is less than or equal to max for all pools" do
      for pool <- Pools.pools() do
        assert pool.min <= pool.max,
               "pool #{inspect(pool[:name])}: min #{pool.min} > max #{pool.max}"
      end
    end

    test "max_concurrency is positive for all pools" do
      for pool <- Pools.pools() do
        assert pool.max_concurrency > 0,
               "pool #{inspect(pool[:name])} has non-positive max_concurrency"
      end
    end

    test "idle_shutdown_after is positive for all pools" do
      for pool <- Pools.pools() do
        assert pool.idle_shutdown_after > 0,
               "pool #{inspect(pool[:name])} has non-positive idle_shutdown_after"
      end
    end

    test "log level is :debug for all pools" do
      for pool <- Pools.pools() do
        assert pool.log == :debug,
               "pool #{inspect(pool[:name])} has unexpected log level: #{pool.log}"
      end
    end

    test "intelligence pool is configured for CPU-bound workloads (low concurrency)" do
      pool = Pools.pools() |> Enum.find(&(&1.name == Indrajaal.FLAME.IntelligencePool))

      assert pool.max_concurrency <= 5,
             "IntelligencePool should have low concurrency for CPU-bound AI inference"
    end

    test "video pool is configured for memory-bound workloads (low concurrency)" do
      pool = Pools.pools() |> Enum.find(&(&1.name == Indrajaal.FLAME.VideoPool))

      assert pool.max_concurrency <= 3,
             "VideoPool should have low concurrency for memory-bound stream processing"
    end

    test "analytics pool has higher concurrency for I/O-bound workloads" do
      pools = Pools.pools()
      analytics = Enum.find(pools, &(&1.name == Indrajaal.FLAME.AnalyticsPool))
      intelligence = Enum.find(pools, &(&1.name == Indrajaal.FLAME.IntelligencePool))

      assert analytics.max_concurrency > intelligence.max_concurrency,
             "AnalyticsPool should have higher concurrency than IntelligencePool"
    end

    test "returns consistent results on repeated calls" do
      assert Pools.pools() == Pools.pools()
    end
  end
end
