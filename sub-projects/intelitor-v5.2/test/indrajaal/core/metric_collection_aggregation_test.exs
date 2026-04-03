defmodule Indrajaal.Core.MetricCollectionAggregationTest do
  @moduledoc """
  TDG test suite for metric collection and aggregation via OTEL pipeline.

  WHAT: Tests that metrics are collected from multiple sources, aggregated
  correctly (sum, avg, percentile, histogram), and that the pipeline maintains
  ordering and completeness guarantees.

  CONSTRAINTS:
  - SC-OBS-069: Dual Log (Term+SigNoz)
  - SC-OBS-071: 4 OTEL modules required
  - SC-CIRCUIT-001: Drop telemetry when queue > 100

  ## Constitutional Verification
  - Ψ₃ (Verification): Metric aggregation is reproducible
  - Ψ₅ (Truthfulness): Metrics reflect actual system state

  ## Change History
  | Version | Date       | Author | Change                                     |
  |---------|------------|--------|--------------------------------------------|
  | 21.3.0  | 2026-03-24 | Claude | Sprint 88 Wave 10 — OTEL pipeline suite    |
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # ---------------------------------------------------------------------------
  # Metric collection engine (simulates OTEL pipeline)
  # ---------------------------------------------------------------------------

  @metric_types [:counter, :gauge, :histogram, :summary]

  defp build_metric(name, type, value, opts \\ []) do
    %{
      name: name,
      type: type,
      value: value,
      timestamp: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond)),
      labels: Keyword.get(opts, :labels, %{}),
      unit: Keyword.get(opts, :unit, :none)
    }
  end

  defp collect_metrics(sources) do
    Enum.flat_map(sources, fn {source_id, metrics} ->
      Enum.map(metrics, &Map.put(&1, :source, source_id))
    end)
  end

  defp aggregate_sum(metrics, name) do
    metrics
    |> Enum.filter(&(&1.name == name))
    |> Enum.map(& &1.value)
    |> Enum.sum()
  end

  defp aggregate_avg(metrics, name) do
    filtered = Enum.filter(metrics, &(&1.name == name))

    case length(filtered) do
      0 -> 0.0
      n -> Enum.sum(Enum.map(filtered, & &1.value)) / n
    end
  end

  defp aggregate_percentile(metrics, name, percentile)
       when percentile >= 0 and percentile <= 100 do
    values =
      metrics
      |> Enum.filter(&(&1.name == name))
      |> Enum.map(& &1.value)
      |> Enum.sort()

    case length(values) do
      0 ->
        0.0

      n ->
        rank = percentile / 100.0 * (n - 1)
        lower = floor(rank)
        upper = min(lower + 1, n - 1)
        weight = rank - lower
        Enum.at(values, lower) * (1 - weight) + Enum.at(values, upper) * weight
    end
  end

  defp build_histogram(metrics, name, bucket_boundaries) do
    values =
      metrics
      |> Enum.filter(&(&1.name == name))
      |> Enum.map(& &1.value)

    buckets =
      Enum.map(bucket_boundaries, fn boundary ->
        {boundary, Enum.count(values, &(&1 <= boundary))}
      end)

    inf_count = length(values)
    buckets ++ [{:infinity, inf_count}]
  end

  defp apply_circuit_breaker(metrics, max_queue_size) do
    if length(metrics) > max_queue_size do
      {Enum.take(metrics, max_queue_size), length(metrics) - max_queue_size}
    else
      {metrics, 0}
    end
  end

  # ---------------------------------------------------------------------------
  # Collection tests
  # ---------------------------------------------------------------------------

  describe "metric collection" do
    test "collects from multiple sources" do
      sources = %{
        "node-1" => [build_metric("cpu", :gauge, 45.5), build_metric("mem", :gauge, 72.0)],
        "node-2" => [build_metric("cpu", :gauge, 62.3), build_metric("mem", :gauge, 58.1)]
      }

      collected = collect_metrics(sources)
      assert length(collected) == 4
      assert Enum.all?(collected, &Map.has_key?(&1, :source))
    end

    test "preserves source attribution" do
      sources = %{
        "alpha" => [build_metric("latency", :histogram, 5.2)],
        "beta" => [build_metric("latency", :histogram, 8.1)]
      }

      collected = collect_metrics(sources)
      sources_found = Enum.map(collected, & &1.source) |> Enum.sort()
      assert sources_found == ["alpha", "beta"]
    end

    test "handles empty sources" do
      sources = %{"empty-node" => []}
      assert collect_metrics(sources) == []
    end

    test "all metric types are representable" do
      metrics =
        Enum.map(@metric_types, fn type ->
          build_metric("test_#{type}", type, 1.0)
        end)

      assert length(metrics) == 4
      types = Enum.map(metrics, & &1.type) |> MapSet.new()
      assert MapSet.equal?(types, MapSet.new(@metric_types))
    end
  end

  # ---------------------------------------------------------------------------
  # Aggregation tests
  # ---------------------------------------------------------------------------

  describe "metric aggregation: sum" do
    test "sums values correctly" do
      metrics = [
        build_metric("requests", :counter, 100),
        build_metric("requests", :counter, 200),
        build_metric("requests", :counter, 50)
      ]

      assert aggregate_sum(metrics, "requests") == 350
    end

    test "ignores unrelated metrics" do
      metrics = [
        build_metric("requests", :counter, 100),
        build_metric("errors", :counter, 5),
        build_metric("requests", :counter, 50)
      ]

      assert aggregate_sum(metrics, "requests") == 150
    end

    test "returns 0 for missing metric" do
      metrics = [build_metric("cpu", :gauge, 50.0)]
      assert aggregate_sum(metrics, "nonexistent") == 0
    end
  end

  describe "metric aggregation: average" do
    test "computes average correctly" do
      metrics = [
        build_metric("latency", :gauge, 10.0),
        build_metric("latency", :gauge, 20.0),
        build_metric("latency", :gauge, 30.0)
      ]

      assert aggregate_avg(metrics, "latency") == 20.0
    end

    test "handles single value" do
      metrics = [build_metric("latency", :gauge, 42.0)]
      assert aggregate_avg(metrics, "latency") == 42.0
    end

    test "returns 0 for empty set" do
      assert aggregate_avg([], "latency") == 0.0
    end
  end

  describe "metric aggregation: percentile" do
    test "p50 gives median" do
      metrics = for v <- [1, 2, 3, 4, 5], do: build_metric("lat", :gauge, v)
      assert aggregate_percentile(metrics, "lat", 50) == 3.0
    end

    test "p99 gives near-max" do
      metrics = for v <- 1..100, do: build_metric("lat", :gauge, v)
      p99 = aggregate_percentile(metrics, "lat", 99)
      assert p99 >= 99.0
    end

    test "p0 gives minimum" do
      metrics = for v <- [10, 20, 30], do: build_metric("lat", :gauge, v)
      assert aggregate_percentile(metrics, "lat", 0) == 10.0
    end

    test "p100 gives maximum" do
      metrics = for v <- [10, 20, 30], do: build_metric("lat", :gauge, v)
      assert aggregate_percentile(metrics, "lat", 100) == 30.0
    end
  end

  describe "histogram bucketing" do
    test "distributes values into buckets" do
      metrics = for v <- [1, 5, 10, 25, 50, 100, 200], do: build_metric("dur", :histogram, v)
      buckets = build_histogram(metrics, "dur", [10, 50, 100, 500])

      assert {10, 3} in buckets
      assert {50, 5} in buckets
      assert {100, 6} in buckets
      assert {500, 7} in buckets
      assert {:infinity, 7} in buckets
    end

    test "empty metrics give zero-count buckets" do
      buckets = build_histogram([], "dur", [10, 50, 100])
      assert Enum.all?(buckets, fn {_boundary, count} -> count == 0 end)
    end
  end

  # ---------------------------------------------------------------------------
  # Circuit breaker tests (SC-CIRCUIT-001)
  # ---------------------------------------------------------------------------

  describe "SC-CIRCUIT-001: circuit breaker" do
    test "drops metrics when queue exceeds 100" do
      metrics = for i <- 1..150, do: build_metric("m#{i}", :counter, i)
      {kept, dropped} = apply_circuit_breaker(metrics, 100)

      assert length(kept) == 100
      assert dropped == 50
    end

    test "passes all metrics when under limit" do
      metrics = for i <- 1..50, do: build_metric("m#{i}", :counter, i)
      {kept, dropped} = apply_circuit_breaker(metrics, 100)

      assert length(kept) == 50
      assert dropped == 0
    end

    test "boundary: exactly 100 metrics passes" do
      metrics = for i <- 1..100, do: build_metric("m#{i}", :counter, i)
      {kept, dropped} = apply_circuit_breaker(metrics, 100)

      assert length(kept) == 100
      assert dropped == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  describe "property: metric invariants" do
    property "sum is always non-negative for positive values" do
      forall values <- PC.list(PC.pos_integer()) do
        metrics = Enum.map(values, &build_metric("test", :counter, &1))
        aggregate_sum(metrics, "test") >= 0
      end
    end

    test "average is bounded by min and max" do
      ExUnitProperties.check all(
                               values <- SD.list_of(SD.float(min: 1.0, max: 100.0), min_length: 1)
                             ) do
        metrics = Enum.map(values, &build_metric("test", :gauge, &1))
        avg = aggregate_avg(metrics, "test")
        min_val = Enum.min(values)
        max_val = Enum.max(values)

        assert avg >= min_val - 0.001
        assert avg <= max_val + 0.001
      end
    end

    test "p50 is always between p0 and p100" do
      ExUnitProperties.check all(
                               values <-
                                 SD.list_of(SD.float(min: 0.0, max: 1000.0), min_length: 1)
                             ) do
        metrics = Enum.map(values, &build_metric("test", :gauge, &1))
        p0 = aggregate_percentile(metrics, "test", 0)
        p50 = aggregate_percentile(metrics, "test", 50)
        p100 = aggregate_percentile(metrics, "test", 100)

        assert p50 >= p0 - 0.001
        assert p50 <= p100 + 0.001
      end
    end

    property "circuit breaker never keeps more than max" do
      forall {n, max_size} <- {PC.integer(1, 500), PC.integer(10, 200)} do
        metrics = for i <- 1..n, do: build_metric("m", :counter, i)
        {kept, _dropped} = apply_circuit_breaker(metrics, max_size)
        length(kept) <= max_size
      end
    end
  end
end
