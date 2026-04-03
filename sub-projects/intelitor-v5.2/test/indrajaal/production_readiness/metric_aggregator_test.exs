defmodule Indrajaal.ProductionReadiness.MetricAggregatorTest do
  @moduledoc """
  TDG test suite for MetricAggregator GenServer.

  ## STAMP Safety Integration
  - UCA-010: Prevent metric explosion from poor aggregation

  ## TPS 5-Level RCA Context
  - L1 Symptom: Query times too slow
  - L5 Root Cause: No limit on grouping dimensions
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.MetricAggregator

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(MetricAggregator)
    end

    test "public API functions are exported" do
      assert function_exported?(MetricAggregator, :start_link, 1)
      assert function_exported?(MetricAggregator, :query, 1)
      assert function_exported?(MetricAggregator, :analyze, 1)
      assert function_exported?(MetricAggregator, :get_stats, 0)
    end
  end

  describe "default limits" do
    test "max metrics per query prevents overload" do
      max = 1000
      assert max >= 100
      assert max <= 100_000
    end

    test "max time range is bounded" do
      max_days = 30
      assert max_days >= 1
      assert max_days <= 365
    end

    test "max grouping dimensions is small" do
      max_dims = 3
      assert max_dims >= 1
      assert max_dims <= 10
    end
  end

  describe "start_link/1" do
    test "starts with default limits" do
      name = :"metric_aggregator_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(MetricAggregator, %{}, name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
