defmodule Indrajaal.Performance.ResourceMonitorTest do
  @moduledoc """
  Comprehensive TDG Test Suite for ResourceMonitor Performance Module.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  require Logger

  alias Indrajaal.Performance.ResourceMonitor

  setup do
    if pid = Process.whereis(ResourceMonitor) do
      GenServer.stop(pid)
    end

    {:ok, _pid} = ResourceMonitor.start_link()
    :ok
  end

  defp restart_monitor(opts \\ []) do
    if pid = Process.whereis(ResourceMonitor) do
      GenServer.stop(pid)
    end

    ResourceMonitor.start_link(opts)
  end

  # Test data generators for property-based testing
  defp resource_monitor_config_generator do
    gen all(
          enabled <- SD.boolean(),
          timeout <- SD.integer(1000..30_000),
          max_retries <- SD.integer(1..10),
          buffer_size <- SD.integer(100..10_000)
        ) do
      %{
        enabled: enabled,
        timeout: timeout,
        max_retries: max_retries,
        buffer_size: buffer_size
      }
    end
  end

  # ============================================================================
  # Core Functionality Tests
  # ============================================================================

  describe "ResourceMonitor Core Functionality" do
    test "starts successfully with default configuration" do
      if pid = Process.whereis(ResourceMonitor) do
        GenServer.stop(pid)
      end

      assert {:ok, _pid} = ResourceMonitor.start_link()

      # Verify module is responsive
      assert {:ok, _status} = ResourceMonitor.get_status()
    end

    test "starts with custom configuration" do
      opts = [
        enabled: true,
        timeout: 5000,
        monitoring: true
      ]

      assert {:ok, _pid} = restart_monitor(opts)
    end

    test "handles basic operations correctly" do
      # Test basic functionality
      assert {:ok, result} = ResourceMonitor.perform_operation(:test_operation)
      assert is_map(result)
      assert Map.has_key?(result, :status)
    end
  end

  # ============================================================================
  # Performance and Optimization Tests
  # ============================================================================

  describe "ResourceMonitor Performance Optimization" do
    test "handles high-throughput operations" do
      operation_count = 100
      start_time = System.monotonic_time(:millisecond)

      tasks =
        Enum.map(1..operation_count, fn _i ->
          Task.async(fn ->
            ResourceMonitor.perform_operation(:performance_test)
          end)
        end)

      results = Task.await_many(tasks, 30_000)
      end_time = System.monotonic_time(:millisecond)

      successful_operations =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      execution_time = end_time - start_time

      throughput =
        if execution_time > 0,
          do: successful_operations / execution_time * 1000,
          else: successful_operations * 1000

      # Should handle at least 10 operations per second
      assert throughput >= 10
      assert successful_operations >= operation_count * 0.8
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "ResourceMonitor Integration Tests" do
    test "integrates with performance monitoring system" do
      # Verify monitoring integration
      assert {:ok, metrics} = ResourceMonitor.get_metrics()
      assert is_map(metrics)
      assert Map.has_key?(metrics, :performance)
      assert Map.has_key?(metrics, :utilization)
    end

    test "supports telemetry events" do
      # Test telemetry integration
      test_pid = self()

      :telemetry.attach(
        "resource_monitor_test",
        [:resource_monitor, :operation],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger operation that should emit telemetry
      assert {:ok, _result} = ResourceMonitor.perform_operation(:telemetry_test)

      # Verify telemetry event was received
      assert_received {:telemetry, [:resource_monitor, :operation], measurements, metadata}
      assert is_map(measurements)
      assert is_map(metadata)

      :telemetry.detach("resource_monitor_test")
    end

    test "handles system resource constraints gracefully" do
      # Simulate resource pressure
      resource_intensive_operations = 50

      results =
        Enum.map(1..resource_intensive_operations, fn _i ->
          ResourceMonitor.perform_operation(:resource_intensive)
        end)

      # Verify system handles resource pressure
      successful_operations =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      # Should handle at least 70% of operations even under resource pressure
      assert successful_operations >= resource_intensive_operations * 0.7
    end
  end

  # ============================================================================
  # STAMP Safety Constraint Tests
  # ============================================================================

  describe "ResourceMonitor STAMP Safety Validation" do
    test "validates STAMP safety constraint SC1: Data Integrity" do
      # Test data integrity under various conditions
      test_data = %{id: 123, value: "test_data", timestamp: DateTime.utc_now()}

      assert {:ok, _result} = ResourceMonitor.process_data(test_data)

      # Verify data integrity is maintained
      {:ok, processed_data} = ResourceMonitor.get_processed_data(test_data.id)
      assert processed_data.id == test_data.id
      assert processed_data.value == test_data.value
    end

    test "validates STAMP safety constraint SC2: Performance Bounds" do
      # Test performance stays within acceptable bounds
      # 1 second
      max_response_time = 1000

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, _result} = ResourceMonitor.perform_operation(:performance_check)
      end_time = System.monotonic_time(:millisecond)

      response_time = end_time - start_time
      assert response_time <= max_response_time
    end

    test "validates STAMP safety constraint SC3: Resource Limits" do
      # Test resource consumption stays within limits
      initial_memory = :erlang.memory(:total)

      # Perform memory-intensive operation
      assert {:ok, _result} = ResourceMonitor.perform_operation(:memory_intensive)

      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      # Should not increase memory by more than 100MB
      max_memory_increase = 100 * 1024 * 1024
      assert memory_increase <= max_memory_increase
    end

    test "validates STAMP safety constraint SC4: Availability Guarantees" do
      # Verify availability
      assert {:ok, status} = ResourceMonitor.get_status()
      assert status.available == true

      # Test availability under load
      load_tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn -> ResourceMonitor.perform_operation(:availability_test) end)
        end)

      Task.await_many(load_tasks, 5_000)

      # Verify still available after load
      assert {:ok, status} = ResourceMonitor.get_status()
      assert status.available == true
    end

    test "validates STAMP safety constraint SC5: Security Isolation" do
      # Test security and isolation requirements
      tenant_a_data = %{tenant_id: "tenant_a", data: "confidential_a"}
      tenant_b_data = %{tenant_id: "tenant_b", data: "confidential_b"}

      assert {:ok, _} = ResourceMonitor.process_tenant_data(tenant_a_data)
      assert {:ok, _} = ResourceMonitor.process_tenant_data(tenant_b_data)

      # Verify tenant isolation
      {:ok, a_result} = ResourceMonitor.get_tenant_data("tenant_a")
      {:ok, b_result} = ResourceMonitor.get_tenant_data("tenant_b")

      assert a_result.data == "confidential_a"
      assert b_result.data == "confidential_b"

      # Verify tenant A cannot access tenant B's data
      assert {:error, :unauthorized} =
               ResourceMonitor.get_tenant_data_as("tenant_a", "tenant_b")
    end
  end

  # ============================================================================
  # SOPv5.1 Cybernetic Integration Tests
  # ============================================================================

  describe "ResourceMonitor SOPv5.1 Cybernetic Integration" do
    test "supports SOPv5.1 goal-oriented execution" do
      # Test cybernetic goal-directed behavior
      performance_goal = %{
        type: :performance_optimization,
        target_metric: :latency,
        target_value: 50,
        priority: :high
      }

      assert {:ok, execution_result} = ResourceMonitor.execute_goal(performance_goal)
      assert execution_result.goal_achieved == true
      assert execution_result.performance_improvement >= 0.0
    end

    test "implements cybernetic feedback loops" do
      # Test feedback loop implementation
      initial_config = %{optimization_level: :low}

      assert {:ok, _pid} = restart_monitor(initial_config)

      # Trigger feedback loop
      performance_feedback = %{
        latency_improvement: 0.15,
        throughput_improvement: 0.08,
        recommendation: :increase_optimization
      }

      assert {:ok, adaptation_result} = ResourceMonitor.apply_feedback(performance_feedback)
      assert adaptation_result.configuration_updated == true
      assert adaptation_result.optimization_level == :medium
    end
  end

  # ============================================================================
  # Property-Based Testing
  # ============================================================================

  describe "ResourceMonitor Property-Based Testing" do
    test "maintains consistency across different configurations" do
      ExUnitProperties.check all(config <- resource_monitor_config_generator()) do
        case restart_monitor(config) do
          {:ok, _pid} ->
            # If started successfully, should be responsive
            assert {:ok, status} = ResourceMonitor.get_status()
            assert is_map(status)

          {:error, reason} ->
            # If failed to start, reason should be valid
            assert is_atom(reason)
        end
      end
    end
  end

  # ============================================================================
  # Performance Benchmarking
  # ============================================================================

  describe "ResourceMonitor Performance Benchmarking" do
    test "performance benchmarks meet requirements" do
      # Benchmark key operations
      benchmarks = %{
        startup_time: benchmark_startup(),
        operation_latency: benchmark_operation_latency(),
        throughput: benchmark_throughput(),
        memory_usage: benchmark_memory_usage()
      }

      # Validate benchmark results
      # 5 seconds
      assert benchmarks.startup_time <= 5_000
      # 100ms
      assert benchmarks.operation_latency <= 100
      # 100 ops/sec
      assert benchmarks.throughput >= 100
      # 100MB
      assert benchmarks.memory_usage <= 100 * 1024 * 1024

      Logger.info("ResourceMonitor Performance Benchmarks:", extra: benchmarks)
    end

    defp benchmark_startup do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _pid} = restart_monitor()
      end_time = System.monotonic_time(:millisecond)
      end_time - start_time
    end

    defp benchmark_operation_latency do
      iterations = 100
      start_time = System.monotonic_time(:microsecond)

      Enum.each(1..iterations, fn _i ->
        ResourceMonitor.perform_operation(:benchmark)
      end)

      end_time = System.monotonic_time(:microsecond)
      # Convert to milliseconds
      (end_time - start_time) / iterations / 1000
    end

    defp benchmark_throughput do
      # 5 seconds
      duration = 5_000
      start_time = System.monotonic_time(:millisecond)

      operations =
        fn ->
          ResourceMonitor.perform_operation(:throughput_test)
        end
        |> Stream.repeatedly()
        |> Stream.take_while(fn _ ->
          System.monotonic_time(:millisecond) - start_time < duration
        end)
        |> Enum.to_list()

      # Operations per second
      length(operations) / (duration / 1000)
    end

    defp benchmark_memory_usage do
      initial_memory = :erlang.memory(:total)

      # Perform memory-intensive operations
      Enum.each(1..100, fn _i ->
        ResourceMonitor.perform_operation(:memory_benchmark)
      end)

      final_memory = :erlang.memory(:total)
      final_memory - initial_memory
    end
  end
end
