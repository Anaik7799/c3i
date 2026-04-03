defmodule Indrajaal.Testing.Performance.TestSupport do
  @moduledoc """
  Performance testing support utilities for advanced test configuration.

  Provides comprehensive performance testing capabilities integrated with
  SOPv5.11 cybernetic framework, TPS methodology, and STAMP safety constraints.
  """

  @doc """
  Benchmark a function execution time with statistical analysis.

  ## Examples

      performance_benchmark("database query", fn ->
        Repo.all(User)
      end, target_time_ms: 50)

  """
  def performance_benchmark(description, fun, opts \\ []) do
    target_time = Keyword.get(opts, :target_time_ms, 100)
    iterations = Keyword.get(opts, :iterations, 10)

    times =
      for _i <- 1..iterations do
        {time_us, _result} = :timer.tc(fun)
        # Convert to milliseconds
        time_us / 1000
      end

    avg_time = Enum.sum(times) / length(times)
    min_time = Enum.min(times)
    max_time = Enum.max(times)

    IO.puts("📊 Performance Benchmark: #{description}")
    IO.puts("   Average: #{Float.round(avg_time, 2)}ms")
    IO.puts("   Min: #{Float.round(min_time, 2)}ms")
    IO.puts("   Max: #{Float.round(max_time, 2)}ms")
    IO.puts("   Target: #{target_time}ms")

    if avg_time <= target_time do
      IO.puts("   ✅ Performance target achieved")
    else
      IO.puts("   ❌ Performance target missed by #{Float.round(avg_time - target_time, 2)}ms")
    end

    %{
      description: description,
      average_time_ms: avg_time,
      min_time_ms: min_time,
      max_time_ms: max_time,
      target_time_ms: target_time,
      target_achieved: avg_time <= target_time,
      iterations: iterations
    }
  end

  @doc """
  Memory usage benchmark for functions.
  """
  def memory_benchmark(description, fun, opts \\ []) do
    target_memory_mb = Keyword.get(opts, :target_memory_mb, 10)

    # Get initial memory usage
    initial_memory = :erlang.memory(:total)

    # Execute function
    result = fun.()

    # Get final memory usage
    final_memory = :erlang.memory(:total)
    memory_used_bytes = final_memory - initial_memory
    memory_used_mb = memory_used_bytes / (1024 * 1024)

    IO.puts("🧠 Memory Benchmark: #{description}")
    IO.puts("   Memory used: #{Float.round(memory_used_mb, 2)}MB")
    IO.puts("   Target: #{target_memory_mb}MB")

    if memory_used_mb <= target_memory_mb do
      IO.puts("   ✅ Memory target achieved")
    else
      IO.puts(
        "   ❌ Memory target exceeded by #{Float.round(memory_used_mb - target_memory_mb, 2)}MB"
      )
    end

    %{
      description: description,
      memory_used_mb: memory_used_mb,
      target_memory_mb: target_memory_mb,
      target_achieved: memory_used_mb <= target_memory_mb,
      result: result
    }
  end

  @doc """
  Parallel execution performance test.
  """
  def parallel_performance_test(description, tasks, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, 10)
    target_time_ms = Keyword.get(opts, :target_time_ms, 1000)

    IO.puts("⚡ Parallel Performance Test: #{description}")
    IO.puts("   Tasks: #{length(tasks)}")
    IO.puts("   Max concurrency: #{max_concurrency}")

    {time_us, results} =
      :timer.tc(fn ->
        tasks
        |> Task.async_stream(& &1.(), max_concurrency: max_concurrency, timeout: 30_000)
        |> Enum.to_list()
      end)

    time_ms = time_us / 1000
    success_count = results |> Enum.count(fn {status, _} -> status == :ok end)

    IO.puts("   Execution time: #{Float.round(time_ms, 2)}ms")
    IO.puts("   Successful tasks: #{success_count}/#{length(tasks)}")
    IO.puts("   Target time: #{target_time_ms}ms")

    if time_ms <= target_time_ms do
      IO.puts("   ✅ Parallel performance target achieved")
    else
      IO.puts(
        "   ❌ Parallel performance target missed by #{Float.round(time_ms - target_time_ms, 2)}ms"
      )
    end

    %{
      description: description,
      execution_time_ms: time_ms,
      target_time_ms: target_time_ms,
      target_achieved: time_ms <= target_time_ms,
      success_count: success_count,
      total_tasks: length(tasks),
      success_rate: success_count / length(tasks)
    }
  end

  @doc """
  Database performance test for connection pooling and query efficiency.
  """
  def database_performance_test(query_fun, opts \\ []) do
    concurrent_connections = Keyword.get(opts, :concurrent_connections, 10)
    queries_per_connection = Keyword.get(opts, :queries_per_connection, 10)
    target_avg_query_time_ms = Keyword.get(opts, :target_avg_query_time_ms, 50)

    IO.puts("🗃️ Database Performance Test")
    IO.puts("   Concurrent connections: #{concurrent_connections}")
    IO.puts("   Queries per connection: #{queries_per_connection}")

    tasks =
      for _i <- 1..concurrent_connections do
        Task.async(fn ->
          query_times =
            for _j <- 1..queries_per_connection do
              {time_us, _result} = :timer.tc(query_fun)
              # Convert to milliseconds
              time_us / 1000
            end

          %{
            avg_time: Enum.sum(query_times) / length(query_times),
            min_time: Enum.min(query_times),
            max_time: Enum.max(query_times),
            query_count: length(query_times)
          }
        end)
      end

    {total_time_us, connection_results} =
      :timer.tc(fn ->
        Task.await_many(tasks, 30_000)
      end)

    total_time_ms = total_time_us / 1000
    total_queries = concurrent_connections * queries_per_connection

    avg_query_time =
      connection_results
      |> Enum.map(& &1.avg_time)
      |> Enum.sum()
      |> Kernel./(concurrent_connections)

    queries_per_second = total_queries / (total_time_ms / 1000)

    IO.puts("   Total execution time: #{Float.round(total_time_ms, 2)}ms")
    IO.puts("   Total queries: #{total_queries}")
    IO.puts("   Average query time: #{Float.round(avg_query_time, 2)}ms")
    IO.puts("   Queries per second: #{Float.round(queries_per_second, 2)}")
    IO.puts("   Target avg query time: #{target_avg_query_time_ms}ms")

    if avg_query_time <= target_avg_query_time_ms do
      IO.puts("   ✅ Database performance target achieved")
    else
      IO.puts(
        "   ❌ Database performance target missed by #{Float.round(avg_query_time - target_avg_query_time_ms, 2)}ms"
      )
    end

    %{
      total_time_ms: total_time_ms,
      total_queries: total_queries,
      avg_query_time_ms: avg_query_time,
      queries_per_second: queries_per_second,
      target_avg_query_time_ms: target_avg_query_time_ms,
      target_achieved: avg_query_time <= target_avg_query_time_ms,
      connection_results: connection_results
    }
  end

  @doc """
  Container-aware performance testing.
  """
  def container_performance_test(description, fun, opts \\ []) do
    container_overhead_threshold = Keyword.get(opts, :container_overhead_threshold, 10.0)

    IO.puts("🐳 Container Performance Test: #{description}")

    # Test with container awareness
    System.put_env("CONTAINER_TEST_MODE", "true")
    {container_time_us, container_result} = :timer.tc(fun)
    System.delete_env("CONTAINER_TEST_MODE")

    # Test without container awareness (if possible)
    {native_time_us, native_result} = :timer.tc(fun)

    container_time_ms = container_time_us / 1000
    native_time_ms = native_time_us / 1000
    overhead_percent = (container_time_ms - native_time_ms) / native_time_ms * 100

    IO.puts("   Container time: #{Float.round(container_time_ms, 2)}ms")
    IO.puts("   Native time: #{Float.round(native_time_ms, 2)}ms")
    IO.puts("   Container overhead: #{Float.round(overhead_percent, 2)}%")
    IO.puts("   Threshold: #{container_overhead_threshold}%")

    if overhead_percent <= container_overhead_threshold do
      IO.puts("   ✅ Container overhead within threshold")
    else
      IO.puts(
        "   ❌ Container overhead exceeds threshold by #{Float.round(overhead_percent - container_overhead_threshold, 2)}%"
      )
    end

    %{
      description: description,
      container_time_ms: container_time_ms,
      native_time_ms: native_time_ms,
      overhead_percent: overhead_percent,
      threshold: container_overhead_threshold,
      threshold_met: overhead_percent <= container_overhead_threshold,
      container_result: container_result,
      native_result: native_result
    }
  end

  @doc """
  SOPv5.11 cybernetic performance monitoring.
  """
  def sopv511performance_monitor(operation, target_efficiency \\ 85.0) do
    # 15-agent architecture
    agent_count = 50

    IO.puts("🤖 SOPv5.11 Performance Monitor: #{operation}")
    IO.puts("   Agent architecture: #{agent_count} agents")
    IO.puts("   Target efficiency: #{target_efficiency}%")

    # Simulate agent coordination efficiency
    {time_us, result} =
      :timer.tc(fn ->
        # Simulate distributed processing across 15 agents
        tasks =
          for i <- 1..agent_count do
            Task.async(fn ->
              # Simulate agent work
              :timer.sleep(Enum.random(1..10))
              {:agent, i, :completed}
            end)
          end

        Task.await_many(tasks, 5_000)
      end)

    time_ms = time_us / 1000
    # Theoretical optimal time in ms
    theoretical_optimal_time = 100
    actual_efficiency = theoretical_optimal_time / time_ms * 100

    IO.puts("   Execution time: #{Float.round(time_ms, 2)}ms")
    IO.puts("   Actual efficiency: #{Float.round(actual_efficiency, 2)}%")

    if actual_efficiency >= target_efficiency do
      IO.puts("   ✅ SOPv5.11 efficiency target achieved")
    else
      IO.puts(
        "   ❌ SOPv5.11 efficiency target missed by #{Float.round(target_efficiency - actual_efficiency, 2)}%"
      )
    end

    %{
      operation: operation,
      agent_count: agent_count,
      execution_time_ms: time_ms,
      actual_efficiency: actual_efficiency,
      target_efficiency: target_efficiency,
      target_achieved: actual_efficiency >= target_efficiency,
      result: result
    }
  end

  @doc """
  Comprehensive performance test suite.
  """
  def comprehensiveperformance_test(test_suite_name, tests) do
    IO.puts("🚀 Comprehensive Performance Test Suite: #{test_suite_name}")
    IO.puts("   Tests: #{length(tests)}")

    results =
      for {test_name, test_fun} <- tests do
        IO.puts("\n   Running: #{test_name}")
        test_fun.()
      end

    successful_tests =
      results
      |> Enum.count(fn result ->
        Map.get(result, :target_achieved, false)
      end)

    success_rate = successful_tests / length(tests) * 100

    IO.puts("\n📊 Performance Test Suite Results:")
    IO.puts("   Total tests: #{length(tests)}")
    IO.puts("   Successful tests: #{successful_tests}")
    IO.puts("   Success rate: #{Float.round(success_rate, 2)}%")

    if success_rate >= 80.0 do
      IO.puts("   ✅ Performance test suite passed")
    else
      IO.puts("   ❌ Performance test suite failed")
    end

    %{
      suite_name: test_suite_name,
      total_tests: length(tests),
      successful_tests: successful_tests,
      success_rate: success_rate,
      passed: success_rate >= 80.0,
      results: results
    }
  end
end
