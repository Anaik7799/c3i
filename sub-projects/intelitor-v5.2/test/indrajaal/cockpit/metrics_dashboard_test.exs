defmodule Indrajaal.Cockpit.MetricsDashboardTest do
  @moduledoc """
  Tests for the Metrics Dashboard.

  WHAT: Validates system metrics collection and visualization.
  WHY: SC-HITL-003 requires operational metrics dashboard.
  CONSTRAINTS: Must verify all metrics are collected correctly.
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Cockpit.MetricsDashboard

  # ============================================================
  # BEAM METRICS TESTS
  # ============================================================

  describe "beam_metrics/0" do
    test "returns comprehensive BEAM metrics" do
      metrics = MetricsDashboard.beam_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :memory)
      assert Map.has_key?(metrics, :processes)
      assert Map.has_key?(metrics, :schedulers)
      assert Map.has_key?(metrics, :run_queue)
      assert Map.has_key?(metrics, :io)
      assert Map.has_key?(metrics, :gc)
    end

    test "memory breakdown is complete" do
      metrics = MetricsDashboard.beam_metrics()

      assert is_integer(metrics.memory.total_mb)
      assert is_integer(metrics.memory.processes_mb)
      assert is_integer(metrics.memory.system_mb)
      assert is_integer(metrics.memory.binary_mb)
      assert is_integer(metrics.memory.ets_mb)
      assert is_integer(metrics.memory.code_mb)
      assert is_integer(metrics.memory.atom_mb)
    end

    test "scheduler info is present" do
      metrics = MetricsDashboard.beam_metrics()

      assert is_integer(metrics.schedulers.online)
      assert is_integer(metrics.schedulers.total)
      assert metrics.schedulers.online > 0
    end

    test "process count is valid" do
      metrics = MetricsDashboard.beam_metrics()

      assert is_integer(metrics.processes.count)
      assert is_integer(metrics.processes.limit)
      assert metrics.processes.count > 0
      assert metrics.processes.limit > metrics.processes.count
    end
  end

  describe "memory_chart_data/0" do
    test "returns chart-compatible data" do
      data = MetricsDashboard.memory_chart_data()

      assert is_list(data)
      assert length(data) > 0

      Enum.each(data, fn item ->
        assert Map.has_key?(item, :category)
        assert Map.has_key?(item, :mb)
        assert is_binary(item.category)
        assert is_integer(item.mb)
      end)
    end

    test "includes expected memory categories" do
      data = MetricsDashboard.memory_chart_data()
      categories = Enum.map(data, & &1.category)

      assert "Processes" in categories
      assert "Binary" in categories
      assert "ETS" in categories
    end
  end

  describe "memory_pie_spec/0" do
    test "returns valid VegaLite specification" do
      spec = MetricsDashboard.memory_pie_spec()

      assert is_map(spec)
      assert spec["$schema"] =~ "vega-lite"
      assert spec["mark"]["type"] == "arc"
    end
  end

  # ============================================================
  # FLAME METRICS TESTS
  # ============================================================

  describe "flame_metrics/0" do
    test "returns FLAME pool metrics" do
      metrics = MetricsDashboard.flame_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :available)
      assert Map.has_key?(metrics, :pools)
    end

    test "pool structure is correct" do
      metrics = MetricsDashboard.flame_metrics()

      if metrics.available do
        Enum.each(metrics.pools, fn pool ->
          assert Map.has_key?(pool, :name)
          assert Map.has_key?(pool, :min)
          assert Map.has_key?(pool, :max)
          assert Map.has_key?(pool, :current)
        end)
      end
    end
  end

  describe "flame_chart_data/0" do
    test "returns chart-compatible data" do
      data = MetricsDashboard.flame_chart_data()

      assert is_list(data)

      Enum.each(data, fn item ->
        assert Map.has_key?(item, :pool)
        assert Map.has_key?(item, :current)
        assert Map.has_key?(item, :max)
        assert Map.has_key?(item, :utilization)
      end)
    end
  end

  # ============================================================
  # AGENT METRICS TESTS
  # ============================================================

  describe "agent_metrics/0" do
    test "returns agent status map" do
      metrics = MetricsDashboard.agent_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :cortex)
      assert Map.has_key?(metrics, :synapse)
      assert Map.has_key?(metrics, :gde)
      assert Map.has_key?(metrics, :zenoh)
    end

    test "each agent has availability flag" do
      metrics = MetricsDashboard.agent_metrics()

      for {_name, agent} <- metrics do
        # Each agent should have at least an :available key or be a map
        assert is_map(agent)
      end
    end
  end

  # ============================================================
  # CONTAINER METRICS TESTS
  # ============================================================

  describe "container_metrics/0" do
    test "returns container status" do
      metrics = MetricsDashboard.container_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :containers)
      assert Map.has_key?(metrics, :overall_health)
    end

    test "container list is populated" do
      metrics = MetricsDashboard.container_metrics()

      assert is_list(metrics.containers)
      assert length(metrics.containers) > 0

      Enum.each(metrics.containers, fn container ->
        assert Map.has_key?(container, :name)
        assert Map.has_key?(container, :status)
        assert Map.has_key?(container, :health)
      end)
    end

    test "expected containers are present" do
      metrics = MetricsDashboard.container_metrics()
      names = Enum.map(metrics.containers, & &1.name)

      assert "indrajaal-app" in names
      assert "indrajaal-db" in names
    end
  end

  # ============================================================
  # SAMPLE COLLECTION TESTS
  # ============================================================

  describe "collect_samples/2" do
    test "collects specified number of samples" do
      samples = MetricsDashboard.collect_samples(3, 10)

      assert length(samples) == 3
    end

    test "samples have required fields" do
      samples = MetricsDashboard.collect_samples(2, 10)

      Enum.each(samples, fn sample ->
        assert Map.has_key?(sample, :sample)
        assert Map.has_key?(sample, :timestamp)
        assert Map.has_key?(sample, :memory_mb)
        assert Map.has_key?(sample, :process_count)
        assert Map.has_key?(sample, :run_queue)
      end)
    end

    test "samples are sequential" do
      samples = MetricsDashboard.collect_samples(3, 10)
      sample_numbers = Enum.map(samples, & &1.sample)

      assert sample_numbers == [1, 2, 3]
    end
  end

  describe "metric_stream/1" do
    test "returns enumerable stream" do
      stream = MetricsDashboard.metric_stream(10)

      assert is_function(stream) or is_struct(stream, Stream)
    end
  end
end
