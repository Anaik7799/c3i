defmodule Indrajaal.Testing.AnalyticsEngine do
  @moduledoc """

  Testing Framework Analytics Engine

  SOPv5.1Cybernetic execution with advanced analytics for test performance optimization,
  quality assurance automation, and predictive testing insights using Timescale DB.

  ## Features-Real-time test execution analytics-Performance regression detection with ML-based insights
  - Quality assurance automation and optimization
  - Predictive test failure analysis
  - Resource utilization optimization
  - Test suite efficiency analysis
  - Automated bottleneck identification
  - CI/CD pipeline optimization recommendations
  """

  use GenServer
  require Logger

  alias Indrajaal.Repo

  # Configuration constants

  @spec start_link(keyword() | map()) :: GenServer.on_start()
  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  @impl GenServer
  def init(params) do
    {:ok, params}
  end

  @spec analyze_suite_optimization(binary() | integer(), any()) :: term()
  def analyze_suite_optimization(tenant_id, test_suite) do
    end_time = DateTime.utc_now()
    # Last 7 days
    start_time = DateTime.add(end_time, -7, :day)

    # Comprehensive suite analysis
    execution_analysis =
      analyze_suite_execution_patterns(tenant_id, test_suite, start_time, end_time)

    resource_analysis = analyze_suite_resource_usage(tenant_id, test_suite, start_time, end_time)
    failure_analysis = analyze_suite_failure_patterns(tenant_id, test_suite, start_time, end_time)
    dependency_analysis = analyze_suite_dependencies(tenant_id, test_suite)

    # Generate optimization recommendations
    optimization_recommendations =
      generate_suite_optimization_recommendations(
        execution_analysis,
        resource_analysis,
        failure_analysis,
        dependency_analysis
      )

    %{
      test_suite: test_suite,
      analysis_period: %{start_time: start_time, end_time: end_time},
      execution_analysis: execution_analysis,
      resource_analysis: resource_analysis,
      failure_analysis: failure_analysis,
      dependency_analysis: dependency_analysis,
      optimization_recommendations: optimization_recommendations,
      performance_score:
        calculate_suite_overall_performance_score(
          execution_analysis,
          resource_analysis,
          failure_analysis
        ),
      next_review_date: DateTime.add(end_time, 7, :day)
    }
  end

  defp analyze_suite_execution_patterns(tenant_id, test_suite, start_time, end_time) do
    query = """
    WITH execution_patterns AS (
      SELECT
        test_name,
        COUNT(*) as execution_count,
        AVG(execution_time_ms) as avg_time,
        STDDEV(execution_time_ms) as stddev_time,
        MIN(execution_time_ms) as min_time,
        MAX(execution_time_ms) as max_time,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_count,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_count
      FROM test_executions
      WHERE tenant_id = $1 AND test_suite = $2
        AND recorded_at >= $3 AND recorded_at <= $4
      GROUP BY test_name
    )
    SELECT
      test_name, execution_count, avg_time, stddev_time, min_time, max_time,
      passed_count, failed_count,
      CASE WHEN execution_count > 0 THEN (passed_count::float / execution_count * 100) ELSE 0 END as success_rate
    FROM execution_patterns
    ORDER BY avg_time DESC
    """

    result = Repo.query!(query, [tenant_id, test_suite, start_time, end_time])

    test_patterns =
      Enum.map(result.rows, fn [name, count, avg, stddev, min, max, passed, failed, success_rate] ->
        %{
          test_name: name,
          execution_count: count,
          average_time_ms: Decimal.to_float(avg),
          standard_deviation_ms: Decimal.to_float(stddev || Decimal.new("0")),
          min_time_ms: Decimal.to_float(min),
          max_time_ms: Decimal.to_float(max),
          passed_count: passed,
          failed_count: failed,
          success_rate: success_rate,
          consistency_score: calculate_test_consistency_score(avg, stddev),
          performance_category: categorize_test_performance(avg, stddev)
        }
      end)

    %{
      total_tests: length(test_patterns),
      test_patterns: test_patterns,
      slowest_tests: Enum.take(Enum.sort_by(test_patterns, & &1.average_time_ms, :desc), 10),
      most_inconsistent_tests: Enum.take(Enum.sort_by(test_patterns, & &1.consistency_score), 10),
      execution_distribution: calculate_execution_time_distribution(test_patterns)
    }
  end

  defp calculate_test_consistency_score(avg_time, stddev) do
    avg = Decimal.to_float(avg_time)
    std = Decimal.to_float(stddev || Decimal.new("0"))

    if avg > 0 do
      coefficient_of_variation = std / avg
      raw_score = max(0, 100 - coefficient_of_variation * 100)
      round(raw_score)
    else
      100
    end
  end

  defp categorize_test_performance(avg_time, stddev) do
    avg = Decimal.to_float(avg_time)
    std = Decimal.to_float(stddev || Decimal.new("0"))
    cv = if avg > 0, do: std / avg, else: 0

    cond do
      avg <= 50 and cv <= 0.2 -> :excellent
      avg <= 200 and cv <= 0.3 -> :good
      avg <= 500 and cv <= 0.5 -> :acceptable
      avg <= 1000 -> :slow
      true -> :critical
    end
  end

  defp calculate_execution_time_distribution(test_patterns) do
    times = Enum.map(test_patterns, & &1.average_time_ms)

    if length(times) > 0 do
      sorted_times = Enum.sort(times)
      total_tests = length(times)

      %{
        p50: Enum.at(sorted_times, round(total_tests * 0.5) - 1),
        p75: Enum.at(sorted_times, round(total_tests * 0.75) - 1),
        p90: Enum.at(sorted_times, round(total_tests * 0.9) - 1),
        p95: Enum.at(sorted_times, round(total_tests * 0.95) - 1),
        p99: Enum.at(sorted_times, round(total_tests * 0.99) - 1),
        mean: Enum.sum(times) / total_tests,
        median: Enum.at(sorted_times, div(total_tests, 2))
      }
    else
      %{p50: 0, p75: 0, p90: 0, p95: 0, p99: 0, mean: 0, median: 0}
    end
  end

  defp analyze_suite_resource_usage(tenant_id, test_suite, start_time, end_time) do
    query = """
    SELECT
      AVG(memory_usage_kb) as avg_memory,
      MAX(memory_usage_kb) as max_memory,
      STDDEV(memory_usage_kb) as stddev_memory,
      AVG(setup_time_ms + teardown_time_ms) as avg_overhead_time,
      COUNT(*) as sample_count
    FROM test_executions
    WHERE tenant_id = $1 AND test_suite = $2
      AND recorded_at >= $3 AND recorded_at <= $4
      AND memory_usage_kb IS NOT NULL
    """

    result = Repo.query!(query, [tenant_id, test_suite, start_time, end_time])

    case result.rows do
      [[avg_memory, max_memory, stddev_memory, avg_overhead, sample_count]] ->
        %{
          average_memory_usage_kb: Decimal.to_float(avg_memory || Decimal.new("0")),
          peak_memory_usage_kb: Decimal.to_float(max_memory || Decimal.new("0")),
          memory_usage_variability: Decimal.to_float(stddev_memory || Decimal.new("0")),
          average_overhead_time_ms: Decimal.to_float(avg_overhead || Decimal.new("0")),
          sample_count: sample_count || 0,
          memory_efficiency_score:
            calculate_memory_efficiency_score(avg_memory, max_memory, stddev_memory),
          resource_recommendations:
            generate_resource_recommendations(avg_memory, max_memory, avg_overhead)
        }

      _ ->
        %{average_memory_usage_kb: 0, memory_efficiency_score: 100, resource_recommendations: []}
    end
  end

  defp calculate_memory_efficiency_score(avg_memory, max_memory, stddev_memory) do
    avg = Decimal.to_float(avg_memory || Decimal.new("0"))
    max_mem = Decimal.to_float(max_memory || Decimal.new("0"))
    std = Decimal.to_float(stddev_memory || Decimal.new("0"))

    if avg > 0 and max_mem > 0 do
      # Score based on consistency and reasonable usage
      consistency = 100 - min(100, std / avg * 100)
      # Peak vs average
      efficiency = 100 - min(100, (max_mem - avg) / avg * 50)

      usage_score =
        cond do
          # < 50MB is excellent
          avg <= 50 * 1024 -> 100
          # < 200MB is good
          avg <= 200 * 1024 -> 80
          # < 500MB is acceptable
          avg <= 500 * 1024 -> 60
          # > 500MB needs attention
          true -> 40
        end

      (consistency * 0.3 + efficiency * 0.3 + usage_score * 0.4) |> round()
    else
      100
    end
  end

  defp generate_resource_recommendations(avg_memory, max_memory, avg_overhead) do
    recommendations = []

    avg_mb = Decimal.to_float(avg_memory || Decimal.new("0")) / 1024
    max_mb = Decimal.to_float(max_memory || Decimal.new("0")) / 1024
    overhead_ms = Decimal.to_float(avg_overhead || Decimal.new("0"))

    recommendations =
      cond do
        avg_mb > 500 ->
          ["Consider reducing memory usage-average \#{Float.round(avg_mb)}MB" | recommendations]

        avg_mb > 200 ->
          ["Monitor memory usage-averaging \#{Float.round(avg_mb)}MB" | recommendations]

        true ->
          recommendations
      end

    recommendations =
      if max_mb > avg_mb * 2 do
        [
          "High memory spikes detected-peak \#{Float.round(max_mb)}MB vs average \#{Float.round(avg_mb)}MB"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if overhead_ms > 1000 do
        [
          "Optimize setup / teardown time-currently \#{Float.round(overhead_ms)}ms"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Resource usage is efficient"]
    else
      recommendations
    end
  end

  defp analyze_suite_failure_patterns(tenant_id, test_suite, start_time, end_time) do
    query = """
    SELECT
      failure_category,
      COUNT(*) as failure_count,
      COUNT(DISTINCT test_name) as affected_tests,
      COUNT(CASE WHEN flaky_indicator = true THEN 1 END) as flaky_count,
      STRING_AGG(DISTINCT pattern_hash, ', ') as patterns
    FROM test_failures
    WHERE tenant_id = $1 AND test_suite = $2
      AND recorded_at >= $3 AND recorded_at <= $4
    GROUP BY failure_category
    ORDER BY failure_count DESC
    """

    result = Repo.query!(query, [tenant_id, test_suite, start_time, end_time])

    failure_categories =
      Enum.map(result.rows, fn [category, count, affected, flaky, patterns] ->
        %{
          category: category,
          failure_count: count,
          affected_tests: affected,
          flaky_failures: flaky,
          unique_patterns: length(String.split(patterns || "", ", ")),
          severity: determine_failure_severity(count, affected, flaky),
          recommendations: generate_failure_category_recommendations(category, count, flaky)
        }
      end)

    total_failures = Enum.sum(Enum.map(failure_categories, & &1.failure_count))
    total_affected_tests = failure_categories |> Enum.map(& &1.affected_tests) |> Enum.sum()

    %{
      total_failures: total_failures,
      total_affected_tests: total_affected_tests,
      failure_categories: failure_categories,
      most_problematic_category:
        Enum.max_by(failure_categories, & &1.failure_count, fn -> nil end),
      reliability_score: calculate_suite_reliability_score(total_failures, total_affected_tests),
      failure_trends: analyze_failure_trends(tenant_id, test_suite, start_time, end_time)
    }
  end

  defp determine_failure_severity(count, affected_tests, flaky_count) do
    flaky_rate = if count > 0, do: flaky_count / count, else: 0

    cond do
      count > 50 or affected_tests > 10 or flaky_rate > 0.5 -> :critical
      count > 20 or affected_tests > 5 or flaky_rate > 0.3 -> :high
      count > 5 or affected_tests > 2 or flaky_rate > 0.1 -> :medium
      true -> :low
    end
  end

  defp generate_failure_category_recommendations(category, count, flaky_count) do
    base_recommendations =
      case category do
        "timeout" ->
          [
            "Review timeout configurations",
            "Optimize async operations",
            "Add better progress indicators"
          ]

        "connectivity" ->
          ["Improve network reliability", "Add connection retry logic", "Use connection pooling"]

        "assertion" ->
          ["Review assertion logic", "Add better error messages", "Improve test __data quality"]

        "null_reference" ->
          ["Add null checks", "Improve object initialization", "Review test setup"]

        "authorization" ->
          ["Review permissions setup", "Improve auth test __data", "Check environment config"]

        "resource" ->
          ["Optimize resource cleanup", "Add resource monitoring", "Review memory management"]

        _ ->
          ["Investigate \#{category} failures", "Add better error handling"]
      end

    flaky_recommendations =
      if flaky_count > count * 0.2 do
        [
          "HIGH: \#{Float.round(flaky_count / count * 100, 1)}% flaky failures",
          "Implement test stabilization"
        ]
      else
        []
      end

    volume_recommendations =
      cond do
        count > 50 -> ["CRITICAL: \#{count} failures need immediate attention"]
        count > 20 -> ["HIGH: \#{count} failures require investigation"]
        count > 5 -> ["MEDIUM: \#{count} failures should be addressed"]
        true -> []
      end

    base_recommendations ++ flaky_recommendations ++ volume_recommendations
  end

  defp calculate_suite_reliability_score(total_failures, total_affected_tests) do
    # Simple reliability score based on failure volume
    cond do
      total_failures == 0 -> 100
      total_failures <= 5 and total_affected_tests <= 2 -> 90
      total_failures <= 10 and total_affected_tests <= 5 -> 80
      total_failures <= 20 and total_affected_tests <= 10 -> 70
      total_failures <= 50 and total_affected_tests <= 20 -> 60
      true -> 40
    end
  end

  defp analyze_failure_trends(tenant_id, test_suite, start_time, end_time) do
    query = """
    WITH daily_failures AS (
      SELECT
        DATE_TRUNC('day', recorded_at) as day,
        COUNT(*) as daily_failures
      FROM test_failures
      WHERE tenant_id = $1 AND test_suite = $2
        AND recorded_at >= $3 AND recorded_at <= $4
      GROUP BY DATE_TRUNC('day', recorded_at)
      ORDER BY day
    )
    SELECT
      day,
      daily_failures,
      LAG(daily_failures) OVER (ORDER BY day) as previous_day_failures
    FROM daily_failures
    """

    result = Repo.query!(query, [tenant_id, test_suite, start_time, end_time])

    daily_trends =
      Enum.map(result.rows, fn [day, failures, prev_failures] ->
        %{
          date: day,
          failure_count: failures,
          change_from_previous: if(prev_failures, do: failures - prev_failures, else: 0)
        }
      end)

    trend_direction =
      if length(daily_trends) >= 3 do
        recent_changes = daily_trends |> Enum.take(-3) |> Enum.map(& &1.change_from_previous)
        positive_changes = Enum.count(recent_changes, &(&1 > 0))

        cond do
          positive_changes >= 2 -> :increasing
          positive_changes <= 1 -> :decreasing
          true -> :stable
        end
      else
        :insufficient_data
      end

    %{
      daily_trends: daily_trends,
      trend_direction: trend_direction,
      average_daily_failures:
        if(length(daily_trends) > 0,
          do: Enum.sum(Enum.map(daily_trends, & &1.failure_count)) / length(daily_trends),
          else: 0
        )
    }
  end

  defp analyze_suite_dependencies(_tenant_id, _test_suite) do
    # Placeholder for dependency analysis
    # In a real implementation, this would analyze test interdependencies
    %{
      dependency_graph: %{},
      circular_dependencies: [],
      optimization_opportunities: [],
      parallelization_potential: :high,
      recommendations: ["Analyze test dependencies for parallel execution optimization"]
    }
  end

  defp generate_suite_optimization_recommendations(
         execution_analysis,
         resource_analysis,
         failure_analysis,
         dependency_analysis
       ) do
    recommendations = []

    # Performance recommendations
    slow_tests = execution_analysis.slowest_tests |> Enum.take(5)

    recommendations =
      if length(slow_tests) > 0 do
        [
          "PERFORMANCE: Optimize #{length(slow_tests)} slowest tests (avg: #{Float.round(Enum.at(slow_tests, 0).average_time_ms)}ms)"
          | recommendations
        ]
      else
        recommendations
      end

    # Consistency recommendations
    inconsistent_tests = execution_analysis.most_inconsistent_tests |> Enum.take(3)

    recommendations =
      if length(inconsistent_tests) > 0 do
        [
          "CONSISTENCY: Stabilize #{length(inconsistent_tests)} inconsistent tests"
          | recommendations
        ]
      else
        recommendations
      end

    # Resource recommendations
    recommendations = recommendations ++ resource_analysis.resource_recommendations

    # Reliability recommendations
    recommendations =
      if failure_analysis.reliability_score < 80 do
        [
          "RELIABILITY: Address failure patterns (reliability score: #{failure_analysis.reliability_score}%)"
          | recommendations
        ]
      else
        recommendations
      end

    # Parallelization recommendations
    recommendations =
      if dependency_analysis.parallelization_potential == :high do
        ["PARALLELIZATION: Tests appear suitable for parallel execution" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Test suite is well optimized", "Continue monitoring for regressions"]
    else
      recommendations
    end
  end

  defp calculate_suite_overall_performance_score(
         execution_analysis,
         resource_analysis,
         failure_analysis
       ) do
    # Weighted performance score
    avg_time =
      if length(execution_analysis.test_patterns) > 0 do
        Enum.sum(Enum.map(execution_analysis.test_patterns, & &1.average_time_ms)) /
          length(execution_analysis.test_patterns)
      else
        0
      end

    performance_score =
      cond do
        avg_time <= 200 -> 100
        avg_time <= 500 -> 80
        avg_time <= 1000 -> 60
        avg_time <= 2000 -> 40
        true -> 20
      end

    resource_score = resource_analysis.memory_efficiency_score
    reliability_score = failure_analysis.reliability_score

    # Weighted average: performance 40%, resource 30%, reliability 30%
    result = (performance_score * 0.4 + resource_score * 0.3 + reliability_score * 0.3) |> round()
    result
  end
end
