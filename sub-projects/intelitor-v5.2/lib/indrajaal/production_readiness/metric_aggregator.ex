defmodule Indrajaal.ProductionReadiness.MetricAggregator do
  @moduledoc """
  Intelligent metric aggregation with performance insights.
  Implements TDG _requirements with STAMP safety constraints.

  Framework: AEE+SOPv5.1+GDE+PHICS+TPS+STAMP+Container-Only

  Safety Constraints:
  - UCA-010: Pr_event metric explosion from poor aggregation
  """

  use GenServer
  require Logger

  @default_limits %{
    max_metrics_per_query: 1000,
    max_time_range_days: 30,
    max_grouping_dimensions: 3
  }

  # @percentiles [0.5, 0.9, 0.95, 0.99]  # AGENT GA FIX: STUB - unused module attribute, not _required by runtime

  # Client API

  def start_link(opts \\ []) do
    limits = Map.merge(@default_limits, Map.new(opts))
    GenServer.start_link(__MODULE__, limits, name: __MODULE__)
  end

  @doc """
  Query metrics with aggregation.
  Pr_events UCA-010: Metric explosion from poor aggregation.
  """
  def query(query_spec) do
    GenServer.call(__MODULE__, {:query, query_spec}, 30_000)
  end

  @doc """
  Analyze raw metrics and provide insights.
  """
  def analyze(raw_metrics) do
    GenServer.call(__MODULE__, {:analyze, raw_metrics})
  end

  @doc """
  Get aggregation statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  @impl true
  def init(limits) do
    state = %{
      limits: limits,
      query_history: [],
      cached_results: %{},
      stats: %{
        queries_processed: 0,
        queries_rejected: 0,
        total_metrics_analyzed: 0,
        cache_hits: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:query, query_spec}, _from, state) do
    Logger.info("[MetricAggregator] Processing query: #{inspect(query_spec)}")

    # UCA-010: Validate query complexity
    case validate_query(query_spec, state.limits) do
      :ok ->
        # Check cache
        cache_key = generate_cache_key(query_spec)

        case Map.get(state.cached_results, cache_key) do
          nil ->
            # Process query
            result = process_query(query_spec)

            # Update cache
            new_cached_results =
              Map.put(state.cached_results, cache_key, {DateTime.utc_now(), result})

            # Clean old cache entries
            cleaned_cache = clean_cache(new_cached_results)

            new_state = %{
              state
              | cached_results: cleaned_cache,
                query_history:
                  [{DateTime.utc_now(), query_spec} | state.query_history] |> Enum.take(100),
                stats: Map.update!(state.stats, :queries_processed, &(&1 + 1))
            }

            {:reply, {:ok, result}, new_state}

          {_timestamp, cached_result} ->
            new_state = %{state | stats: Map.update!(state.stats, :cache_hits, &(&1 + 1))}

            {:reply, {:ok, cached_result}, new_state}
        end

      {:error, :query_too_expensive} = error ->
        Logger.error("[MetricAggregator] Query rejected - too expensive")

        new_state = %{state | stats: Map.update!(state.stats, :queries_rejected, &(&1 + 1))}

        {:reply, error, new_state}
    end
  end

  @impl true
  def handle_call({:analyze, raw_metrics}, _from, state) do
    insights = analyze_metrics(raw_metrics)

    new_state = %{
      state
      | stats:
          Map.update!(state.stats, :total_metrics_analyzed, &(&1 + count_metrics(raw_metrics)))
    }

    {:reply, {:ok, insights}, new_state}
  end

  @impl true
  def handle_call(:getstats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        cache_size: map_size(state.cached_results),
        recent_queries: length(state.query_history)
      })

    {:reply, stats, state}
  end

  # Private functions

  defp validate_query(query, limits) do
    cond do
      # Check if querying all metrics
      query[:metrics] == :all ->
        {:error, :query_too_expensive}

      # Check time range
      query[:time_range] == :all_time ->
        {:error, :query_too_expensive}

      # Check grouping dimensions
      length(query[:group_by] || []) > limits.max_grouping_dimensions ->
        {:error, :query_too_expensive}

      # Check if it would create too many series
      estimate_result_size(query) > limits.max_metrics_per_query ->
        {:error, :query_too_expensive}

      true ->
        :ok
    end
  end

  defp estimate_result_size(query) do
    # Estimate based on query parameters
    base_size = length(query[:metrics] || [1])
    group_by_multiplier = :math.pow(10, length(query[:group_by] || []))

    round(base_size * group_by_multiplier)
  end

  defp process_query(query) do
    # In production, this would query actual metric storage
    # Simulating aggregation results
    %{
      time_range: query[:time_range] || {DateTime.utc_now(), DateTime.utc_now()},
      metrics: query[:metrics] || [],
      aggregations: %{
        count: :rand.uniform(10_000),
        sum: :rand.uniform() * 100_000,
        avg: 50 + :rand.uniform() * 50,
        min: :rand.uniform() * 10,
        max: 90 + :rand.uniform() * 100
      },
      group_by_results: if(query[:group_by], do: generate_grouped_results(query), else: nil)
    }
  end

  defp generate_grouped_results(query) do
    # Simulate grouped results
    groups =
      for i <- 1..5 do
        group_values =
          Enum.map(query[:group_by], fn dim ->
            {dim, "value_#{i}"}
          end)

        {group_values,
         %{
           count: :rand.uniform(1000),
           avg: 40 + :rand.uniform() * 60
         }}
      end

    Map.new(groups)
  end

  defp analyze_metrics(raw_metrics) do
    insights = %{
      response_time_p50: nil,
      response_time_p90: nil,
      response_time_p95: nil,
      response_time_p99: nil,
      error_rate: nil,
      throughput_trend: nil,
      anomalies: [],
      recommendations: []
    }

    # Analyze response times
    insights =
      if response_times = raw_metrics[:response_times] do
        analyze_response_times(insights, response_times)
      else
        insights
      end

    # Analyze error rates
    insights =
      if error_counts = raw_metrics[:error_counts] do
        analyze_error_rates(
          insights,
          error_counts,
          length(raw_metrics[:response_times] || []),
          nil
        )
      else
        insights
      end

    # Analyze throughput
    insights =
      if throughput = raw_metrics[:throughput] do
        analyze_throughput(insights, throughput)
      else
        insights
      end

    # Generate recommendations
    add_recommendations(insights)
  end

  defp analyze_response_times(insights, response_times) do
    sorted = Enum.sort(response_times)
    len = length(sorted)

    percentiles = %{
      response_time_p50: Enum.at(sorted, div(len, 2)),
      response_time_p90: Enum.at(sorted, div(len * 9, 10)),
      response_time_p95: Enum.at(sorted, div(len * 95, 100)),
      response_time_p99: Enum.at(sorted, div(len * 99, 100))
    }

    # Detect anomalies (outliers)
    p99 = percentiles.response_time_p99

    anomalies =
      response_times
      |> Enum.filter(&(&1 > p99 * 1.5))
      |> Enum.map(&{:response_time_outlier, &1})

    merged = Map.merge(insights, percentiles)
    Map.put(merged, :anomalies, insights.anomalies ++ anomalies)
  end

  defp analyze_error_rates(insights, error_counts, total_requests, _req) do
    total_errors = error_counts |> Map.values() |> Enum.sum()

    error_rate =
      if total_requests > 0 do
        total_errors / total_requests
      else
        0.0
      end

    # Check for error anomalies
    anomalies =
      if error_rate > 0.05 do
        [{:high_error_rate, error_rate} | insights.anomalies]
      else
        insights.anomalies
      end

    insights
    |> Map.put(:error_rate, error_rate)
    |> Map.put(:anomalies, anomalies)
  end

  defp analyze_throughput(insights, throughput_values) do
    avg_throughput = Enum.sum(throughput_values) / length(throughput_values)
    variance = calculate_variance(throughput_values, avg_throughput)

    trend =
      cond do
        variance < avg_throughput * 0.1 -> :stable
        trending_up?(throughput_values) -> :increasing
        trending_down?(throughput_values) -> :decreasing
        true -> :volatile
      end

    Map.put(insights, :throughput_trend, trend)
  end

  defp add_recommendations(insights) do
    recommendations = []

    # Response time recommendations
    recommendations =
      if insights.response_time_p95 && insights.response_time_p95 > 100 do
        ["Consider caching or query optimization for slow endpoints" | recommendations]
      else
        recommendations
      end

    # Error rate recommendations
    recommendations =
      if insights.error_rate && insights.error_rate > 0.01 do
        ["Investigate error patterns and implement retry logic" | recommendations]
      else
        recommendations
      end

    # Throughput recommendations
    recommendations =
      if insights.throughput_trend == :volatile do
        ["Traffic pattern is volatile - consider auto-scaling" | recommendations]
      else
        recommendations
      end

    # Anomaly recommendations
    recommendations =
      if length(insights.anomalies) > 0 do
        ["Anomalies detected - investigate outliers" | recommendations]
      else
        recommendations
      end

    Map.put(insights, :recommendations, recommendations)
  end

  defp calculate_variance(values, mean) do
    squared_diffs = Enum.map(values, fn v -> :math.pow(v - mean, 2) end)
    Enum.sum(squared_diffs) / length(values)
  end

  defp trending_up?(values) do
    pairs = Enum.zip(Enum.drop(values, -1), Enum.drop(values, 1))
    increases = Enum.count(pairs, fn {a, b} -> b > a end)
    increases > length(pairs) * 0.7
  end

  defp trending_down?(values) do
    pairs = Enum.zip(Enum.drop(values, -1), Enum.drop(values, 1))
    decreases = Enum.count(pairs, fn {a, b} -> b < a end)
    decreases > length(pairs) * 0.7
  end

  defp generate_cache_key(query) do
    hash = :crypto.hash(:md5, :erlang.term_to_binary(query))
    Base.encode16(hash)
  end

  defp clean_cache(cache) do
    # Remove entries older than 5 minutes
    cutoff = DateTime.add(DateTime.utc_now(), -300, :second)

    cache
    |> Enum.filter(fn {_, {timestamp, _}} ->
      DateTime.compare(timestamp, cutoff) == :gt
    end)
    |> Map.new()
  end

  defp count_metrics(raw_metrics) do
    raw_metrics
    |> Map.values()
    |> Enum.map(fn
      list when is_list(list) -> length(list)
      map when is_map(map) -> map_size(map)
      _ -> 1
    end)
    |> Enum.sum()
  end
end
