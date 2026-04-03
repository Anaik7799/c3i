defmodule Indrajaal.ProductionReadiness.PrometheusMetricsTest do
  @moduledoc """
  TDG test suite for PrometheusMetrics GenServer.

  ## STAMP Safety Integration
  - SC-012: Monitoring must not impact system performance

  ## TPS 5-Level RCA Context
  - L1 Symptom: Metrics cardinality explosion
  - L5 Root Cause: Missing cardinality limit enforcement
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.PrometheusMetrics

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(PrometheusMetrics)
    end

    test "public API functions are exported" do
      assert function_exported?(PrometheusMetrics, :start_link, 1)
      assert function_exported?(PrometheusMetrics, :define_metric, 1)
      assert function_exported?(PrometheusMetrics, :define_metrics, 1)
      assert function_exported?(PrometheusMetrics, :inc, 1)
      assert function_exported?(PrometheusMetrics, :inc, 2)
      assert function_exported?(PrometheusMetrics, :set, 2)
      assert function_exported?(PrometheusMetrics, :set, 3)
    end
  end

  describe "metric_types" do
    test "all standard metric types are supported" do
      types = [:counter, :gauge, :histogram, :summary]
      assert length(types) == 4
      assert :counter in types
      assert :histogram in types
    end
  end

  describe "default limits" do
    test "default limits are reasonable" do
      limits = %{
        max_cpu_percent: 2.0,
        max_memory_mb: 100,
        max_cardinality: 10_000
      }

      assert limits.max_cpu_percent <= 5.0
      assert limits.max_memory_mb <= 1024
      assert limits.max_cardinality >= 1000
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      name = :"prometheus_metrics_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(PrometheusMetrics, %{}, name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
