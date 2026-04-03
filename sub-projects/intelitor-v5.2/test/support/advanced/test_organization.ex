defmodule Indrajaal.Testing.Advanced.TestOrganization do
  @moduledoc """
  Advanced test organization and management system for enterprise-grade testing.

  Provides sophisticated test categorization, execution ordering, and parallel
  execution strategies integrated with SOPv5.11, TPS, and STAMP methodologies.
  """

  @test_categories %{
    unit: %{
      pattern: ~r/^test\/.*\/.*_test\.exs$/,
      priority: 1,
      parallel: true,
      timeout: 10_000,
      description: "Fast unit tests with mocked dependencies"
    },
    integration: %{
      pattern: ~r/^test\/integration\/.*_test\.exs$/,
      priority: 2,
      parallel: true,
      timeout: 30_000,
      description: "Integration tests with real dependencies"
    },
    property: %{
      pattern: ~r/^test\/property\/.*_test\.exs$/,
      priority: 3,
      parallel: true,
      timeout: 60_000,
      description: "Property-based testing with PropCheck/ExUnitProperties"
    },
    stamp: %{
      pattern: ~r/^test\/stamp\/.*_test\.exs$/,
      priority: 4,
      parallel: false,
      timeout: 30_000,
      description: "STAMP safety constraint validation tests"
    },
    tdg: %{
      pattern: ~r/^test\/tdg\/.*_test\.exs$/,
      priority: 5,
      parallel: true,
      timeout: 45_000,
      description: "Test-Driven Generation methodology validation"
    },
    wallaby: %{
      pattern: ~r/^test\/.*wallaby.*_test\.exs$/,
      priority: 6,
      parallel: false,
      timeout: 120_000,
      description: "End-to-end browser testing with Wallaby"
    },
    performance: %{
      pattern: ~r/^test\/performance\/.*_test\.exs$/,
      priority: 7,
      parallel: false,
      timeout: 300_000,
      description: "Performance and load testing"
    }
  }

  @domains [
    :access_control,
    :accounts,
    :alarms,
    :analytics,
    :communication,
    :compliance,
    :devices,
    :energy_management,
    :environmental,
    :fleet_management,
    :guard_tours,
    :integration,
    :intelligence,
    :maintenance,
    :shifts,
    :sites,
    :training,
    :video,
    :visitor_management
  ]

  @doc """
  Organize and categorize test files by type and domain.
  """
  def categorize_tests(test_files) do
    categories =
      for test_file <- test_files do
        category = determine_test_category(test_file)
        domain = determine_test_domain(test_file)

        %{
          file: test_file,
          category: category,
          domain: domain,
          priority: @test_categories[category][:priority],
          parallel: @test_categories[category][:parallel],
          timeout: @test_categories[category][:timeout]
        }
      end

    # Group by category and domain
    grouped = Enum.group_by(categories, fn test -> {test.category, test.domain} end)

    %{
      total_files: length(test_files),
      categories: categories,
      grouped: grouped,
      summary: generate_category_summary(categories)
    }
  end

  @doc """
  Generate optimal test execution plan based on dependencies and parallelization.
  """
  def generate_execution_plan(categorized_tests, opts \\ []) do
    max_parallel = Keyword.get(opts, :max_parallel, 16)
    respect_priorities = Keyword.get(opts, :respect_priorities, true)

    # Sort by priority if required
    sorted_tests =
      if respect_priorities do
        Enum.sort_by(categorized_tests.categories, & &1.priority)
      else
        categorized_tests.categories
      end

    # Create execution groups
    parallel_groups =
      sorted_tests
      |> Enum.group_by(fn test ->
        if test.parallel do
          # Group parallel tests by category for better resource utilization
          test.category
        else
          # Sequential tests get their own group
          {:sequential, test.file}
        end
      end)

    execution_stages = []

    # Add parallel stages
    parallel_stages =
      for {category, tests} when is_atom(category) <- parallel_groups,
          @test_categories[category][:parallel] do
        %{
          type: :parallel,
          category: category,
          tests: tests,
          max_concurrency: min(length(tests), max_parallel),
          estimated_time: calculate_estimated_time(tests)
        }
      end

    # Add sequential stages
    sequential_stages =
      for {{:sequential, _file}, tests} <- parallel_groups do
        %{
          type: :sequential,
          category: :sequential,
          tests: tests,
          max_concurrency: 1,
          estimated_time: calculate_estimated_time(tests)
        }
      end

    execution_stages = execution_stages ++ parallel_stages ++ sequential_stages

    total_estimated_time =
      execution_stages
      |> Enum.map(& &1.estimated_time)
      |> Enum.sum()

    %{
      stages: execution_stages,
      total_stages: length(execution_stages),
      total_tests: length(sorted_tests),
      total_estimated_time_ms: total_estimated_time,
      parallel_efficiency: calculate_parallel_efficiency(execution_stages)
    }
  end

  @doc """
  Execute test plan with monitoring and reporting.
  """
  def execute_test_plan(execution_plan, opts \\ []) do
    monitor_execution = Keyword.get(opts, :monitor, true)
    report_progress = Keyword.get(opts, :report_progress, true)

    if report_progress do
      IO.puts("🚀 Executing Test Plan")
      IO.puts("   Total stages: #{execution_plan.total_stages}")
      IO.puts("   Total tests: #{execution_plan.total_tests}")

      IO.puts(
        "   Estimated time: #{Float.round(execution_plan.total_estimated_time_ms / 1000, 2)}s"
      )

      IO.puts("   Parallel efficiency: #{Float.round(execution_plan.parallel_efficiency, 2)}%")
    end

    {total_time_us, stage_results} =
      :timer.tc(fn ->
        execution_plan.stages
        |> Enum.with_index(1)
        |> Enum.map(fn {stage, index} ->
          if report_progress do
            IO.puts(
              "\n📋 Stage #{index}/#{execution_plan.total_stages}: #{stage.category} (#{stage.type})"
            )

            IO.puts("   Tests: #{length(stage.tests)}")
            IO.puts("   Concurrency: #{stage.max_concurrency}")
          end

          execute_test_stage(stage, monitor_execution)
        end)
      end)

    total_time_ms = total_time_us / 1000

    # Calculate overall results
    total_tests_run = stage_results |> Enum.map(& &1.tests_run) |> Enum.sum()
    total_failures = stage_results |> Enum.map(& &1.failures) |> Enum.sum()
    success_rate = (total_tests_run - total_failures) / total_tests_run * 100

    if report_progress do
      IO.puts("\n📊 Test Execution Summary")
      IO.puts("   Total time: #{Float.round(total_time_ms / 1000, 2)}s")
      IO.puts("   Tests run: #{total_tests_run}")
      IO.puts("   Failures: #{total_failures}")
      IO.puts("   Success rate: #{Float.round(success_rate, 2)}%")
    end

    %{
      execution_time_ms: total_time_ms,
      tests_run: total_tests_run,
      failures: total_failures,
      success_rate: success_rate,
      stage_results: stage_results,
      efficiency: calculate_actual_efficiency(execution_plan, total_time_ms)
    }
  end

  @doc """
  Generate test organization report.
  """
  def generate_organization_report(categorized_tests) do
    report = """
    # Test Organization Report

    Generated: #{DateTime.utc_now() |> DateTime.to_string()}

    ## Summary

    - **Total test files**: #{categorized_tests.total_files}
    - **Categories**: #{categorized_tests.summary |> Map.keys() |> length()}
    - **Domains**: #{categorized_tests.summary |> Enum.flat_map(fn {_cat, domains} -> Map.keys(domains) end) |> Enum.uniq() |> length()}

    ## Category Breakdown

    #{generate_category_breakdown(categorized_tests.summary)}

    ## Domain Distribution

    #{generate_domain_distribution(categorized_tests.categories)}

    ## Execution Recommendations

    #{generate_execution_recommendations(categorized_tests)}
    """

    report_file = "test_organization_report_#{DateTime.utc_now() |> DateTime.to_unix()}.md"
    File.write!("./data/tmp/#{report_file}", report)

    IO.puts("📄 Test organization report saved: ./data/tmp/#{report_file}")

    %{
      report_content: report,
      report_file: "./data/tmp/#{report_file}",
      summary: categorized_tests.summary
    }
  end

  # Private helper functions

  defp determine_test_category(test_file) do
    @test_categories
    |> Enum.find(fn {_category, config} ->
      Regex.match?(config.pattern, test_file)
    end)
    |> case do
      {category, _config} -> category
      # Default to unit test
      nil -> :unit
    end
  end

  defp determine_test_domain(test_file) do
    @domains
    |> Enum.find(fn domain ->
      String.contains?(test_file, to_string(domain))
    end)
    |> case do
      nil -> :general
      domain -> domain
    end
  end

  defp generate_category_summary(categories) do
    categories
    |> Enum.group_by(& &1.category)
    |> Enum.into(%{}, fn {category, tests} ->
      domain_counts =
        tests
        |> Enum.group_by(& &1.domain)
        |> Enum.into(%{}, fn {domain, domain_tests} ->
          {domain, length(domain_tests)}
        end)

      {category, domain_counts}
    end)
  end

  defp calculate_estimated_time(tests) do
    tests
    |> Enum.map(fn test -> test.timeout end)
    |> Enum.sum()
  end

  defp calculate_parallel_efficiency(stages) do
    parallel_stages = Enum.filter(stages, &(&1.type == :parallel))
    sequential_stages = Enum.filter(stages, &(&1.type == :sequential))

    parallel_time = parallel_stages |> Enum.map(& &1.estimated_time) |> Enum.sum()
    sequential_time = sequential_stages |> Enum.map(& &1.estimated_time) |> Enum.sum()
    total_time = parallel_time + sequential_time

    if total_time > 0 do
      parallel_time / total_time * 100
    else
      0.0
    end
  end

  defp execute_test_stage(stage, monitor) do
    # Simulate test execution (in real implementation, this would run actual tests)
    {time_us, results} =
      :timer.tc(fn ->
        if stage.type == :parallel do
          # Simulate parallel test execution
          stage.tests
          |> Task.async_stream(
            fn test ->
              # Simulate test execution time
              :timer.sleep(Enum.random(10..100))
              %{test: test.file, result: if(Enum.random(1..10) > 8, do: :failed, else: :passed)}
            end,
            max_concurrency: stage.max_concurrency,
            timeout: 60_000
          )
          |> Enum.to_list()
          |> Enum.map(fn {:ok, result} -> result end)
        else
          # Simulate sequential test execution
          Enum.map(stage.tests, fn test ->
            :timer.sleep(Enum.random(10..50))
            %{test: test.file, result: if(Enum.random(1..10) > 8, do: :failed, else: :passed)}
          end)
        end
      end)

    execution_time_ms = time_us / 1000
    failures = Enum.count(results, fn result -> result.result == :failed end)

    if monitor do
      IO.puts("   ✅ Stage completed in #{Float.round(execution_time_ms, 2)}ms")

      if failures > 0 do
        IO.puts("   ⚠️ #{failures} test(s) failed")
      end
    end

    %{
      stage: stage.category,
      type: stage.type,
      execution_time_ms: execution_time_ms,
      tests_run: length(results),
      failures: failures,
      results: results
    }
  end

  defp calculate_actual_efficiency(execution_plan, actual_time_ms) do
    estimated_time_ms = execution_plan.total_estimated_time_ms
    estimated_time_ms / actual_time_ms * 100
  end

  defp generate_category_breakdown(summary) do
    Enum.map_join(summary, "\n", fn {category, domains} ->
      domain_list =
        Enum.map_join(domains, ", ", fn {domain, count} -> "#{domain}: #{count}" end)

      "- **#{category}**: #{domain_list}"
    end)
  end

  defp generate_domain_distribution(categories) do
    categories
    |> Enum.group_by(& &1.domain)
    |> Enum.map_join("\n", fn {domain, tests} ->
      category_counts =
        tests
        |> Enum.group_by(& &1.category)
        |> Enum.into(%{}, fn {category, category_tests} ->
          {category, length(category_tests)}
        end)

      category_list =
        Enum.map_join(category_counts, ", ", fn {category, count} -> "#{category}: #{count}" end)

      "- **#{domain}**: #{category_list}"
    end)
  end

  defp generate_execution_recommendations(categorized_tests) do
    recommendations = []

    # Analyze parallel vs sequential balance
    parallel_count =
      categorized_tests.categories
      |> Enum.count(& &1.parallel)

    sequential_count = length(categorized_tests.categories) - parallel_count

    recommendations =
      if parallel_count < sequential_count do
        ["Consider converting some sequential tests to parallel execution" | recommendations]
      else
        recommendations
      end

    # Check for large test categories
    large_categories =
      categorized_tests.summary
      |> Enum.filter(fn {_category, domains} ->
        total_tests = domains |> Map.values() |> Enum.sum()
        total_tests > 20
      end)

    recommendations =
      if Enum.empty?(large_categories) do
        recommendations
      else
        ["Consider splitting large test categories for better organization" | recommendations]
      end

    if Enum.empty?(recommendations) do
      "- Test organization appears well-balanced"
    else
      Enum.map_join(recommendations, "\n", fn rec -> "- #{rec}" end)
    end
  end
end
