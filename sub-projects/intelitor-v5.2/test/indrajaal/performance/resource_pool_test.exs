defmodule Indrajaal.Performance.ResourcePoolTest do
  @moduledoc """
  Comprehensive TDG Test Suite for ResourcePool Performance Module.
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  require Logger

  alias Indrajaal.Performance.ResourcePool

  setup do
    if pid = Process.whereis(ResourcePool) do
      GenServer.stop(pid)
    end

    {:ok, _pid} = ResourcePool.start_link()
    :ok
  end

  defp restart_pool(opts \\ []) do
    if pid = Process.whereis(ResourcePool) do
      GenServer.stop(pid)
    end

    ResourcePool.start_link(opts)
  end

  # Test data generators for property-based testing
  defp resource_pool_config_generator do
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

  describe "ResourcePool Core Functionality" do
    test "starts successfully with pool configuration" do
      pool_config = %{
        pool_name: :cpu_pool,
        cpu_cores: 16
      }

      assert {:ok, _pid} = restart_pool(Map.to_list(pool_config))

      # Verify pool is responsive
      assert report = ResourcePool.get_pool_status(ResourcePool)
      assert report.cpu.total == 16
    end

    test "allocates and deallocates resources correctly" do
      # Using the specific API functions
      assert {:ok, allocation_id} = ResourcePool.allocate_cpu(ResourcePool, cores: 2)

      status = ResourcePool.get_pool_status(ResourcePool)
      assert status.cpu.allocated == 2

      assert :ok = ResourcePool.release_cpu(ResourcePool, allocation_id)

      status_after = ResourcePool.get_pool_status(ResourcePool)
      assert status_after.cpu.allocated == 0
    end
  end

  # ============================================================================
  # Performance and Optimization Tests
  # ============================================================================

  describe "ResourcePool Performance Optimization" do
    test "handles high allocation throughput" do
      # Test allocation performance under load
      allocation_count = 100
      start_time = System.monotonic_time(:millisecond)

      tasks =
        Enum.map(1..allocation_count, fn _i ->
          Task.async(fn ->
            ResourcePool.allocate_cpu(ResourcePool, cores: 1)
          end)
        end)

      results = Task.await_many(tasks, 30_000)
      end_time = System.monotonic_time(:millisecond)

      successful_allocations =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      execution_time = end_time - start_time
      throughput = successful_allocations / execution_time * 1000

      # Should handle at least 10 allocations per second
      assert throughput >= 10
      # Given default cores is small, we might hit limit, but we check if it handles it
      assert successful_allocations > 0
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "ResourcePool Integration Tests" do
    test "integrates with performance monitoring system" do
      # Verify monitoring integration
      assert {:ok, health} = ResourcePool.health_check(ResourcePool)
      assert is_map(health)
      assert Map.has_key?(health, :resource_utilization)
    end

    test "supports telemetry events" do
      # Test telemetry integration
      test_pid = self()

      :telemetry.attach(
        "resource_pool_test",
        [:resource_pool, :allocation],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger operation that should emit telemetry
      assert {:ok, _result} = ResourcePool.allocate_cpu(ResourcePool, cores: 1)

      # Verify telemetry event was received
      assert_received {:telemetry, [:resource_pool, :allocation], measurements, metadata}
      assert is_map(measurements)
      assert is_map(metadata)

      :telemetry.detach("resource_pool_test")
    end
  end

  # ============================================================================
  # STAMP Safety Constraint Tests
  # ============================================================================

  describe "ResourcePool STAMP Safety Validation" do
    test "validates STAMP safety constraint SC1: Data Integrity" do
      # Verify data integrity via allocation details
      assert {:ok, allocation_id} = ResourcePool.allocate_memory(ResourcePool, gb: 4)

      # Verify data integrity is maintained
      {:ok, details} = ResourcePool.get_allocation_details(ResourcePool, allocation_id)
      assert details.allocation_id == allocation_id
      assert details.allocated_amount == 4
      assert details.resource_type == :memory
    end

    test "validates STAMP safety constraint SC2: Performance Bounds" do
      # Test performance stays within acceptable bounds
      # 1 second
      max_response_time = 1000

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, _result} = ResourcePool.allocate_cpu(ResourcePool, cores: 1)
      end_time = System.monotonic_time(:millisecond)

      response_time = end_time - start_time
      assert response_time <= max_response_time
    end

    test "validates STAMP safety constraint SC3: Resource Limits" do
      # Test resource consumption stays within limits

      # Reset pool to known state
      ResourcePool.reset(ResourcePool)

      # Try to allocate more than available
      # Default is 8 cores
      assert {:ok, _} = ResourcePool.allocate_cpu(ResourcePool, cores: 8)
      assert {:error, :insufficient_resources} = ResourcePool.allocate_cpu(ResourcePool, cores: 1)
    end

    test "validates STAMP safety constraint SC4: Availability Guarantees" do
      # Verify availability
      assert {:ok, health} = ResourcePool.health_check(ResourcePool)
      assert health.status == :healthy

      # Test availability under load
      load_tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn -> ResourcePool.get_available_cpu(ResourcePool) end)
        end)

      Task.await_many(load_tasks, 5_000)

      # Verify still available after load
      assert {:ok, health_after} = ResourcePool.health_check(ResourcePool)
      assert health_after.status == :healthy
    end
  end

  # ============================================================================
  # Property-Based Testing
  # ============================================================================

  describe "ResourcePool Property-Based Testing" do
    test "resource allocation maintains pool consistency" do
      ExUnitProperties.check all(
                               cpu_request <- SD.integer(1..4),
                               memory_request <- SD.integer(1..4)
                             ) do
        # Use a fresh pool for each property iteration to ensure isolation
        {:ok, pid} = restart_pool(cpu_cores: 10, memory_gb: 10)

        case ResourcePool.allocate_cpu(pid, cores: cpu_request) do
          {:ok, allocation_id} ->
            status = ResourcePool.get_pool_status(pid)
            assert status.cpu.allocated == cpu_request

            ResourcePool.release_cpu(pid, allocation_id)
            status_after = ResourcePool.get_pool_status(pid)
            assert status_after.cpu.allocated == 0

          {:error, reason} ->
            assert reason in [:insufficient_resources]
        end

        GenServer.stop(pid)
      end
    end
  end

  # ============================================================================
  # Performance Benchmarking
  # ============================================================================

  describe "ResourcePool Performance Benchmarking" do
    test "performance benchmarks meet requirements" do
      # Benchmark key operations
      benchmarks = %{
        startup_time: benchmark_startup(),
        operation_latency: benchmark_operation_latency(),
        memory_usage: benchmark_memory_usage()
      }

      # Validate benchmark results
      # 5 seconds
      assert benchmarks.startup_time <= 5_000
      # 100ms
      assert benchmarks.operation_latency <= 100
      # 100MB
      assert benchmarks.memory_usage <= 100 * 1024 * 1024

      Logger.info("ResourcePool Performance Benchmarks:", extra: benchmarks)
    end

    defp benchmark_startup do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _pid} = restart_pool()
      end_time = System.monotonic_time(:millisecond)
      end_time - start_time
    end

    defp benchmark_operation_latency do
      iterations = 100
      start_time = System.monotonic_time(:microsecond)

      Enum.each(1..iterations, fn _i ->
        ResourcePool.get_available_cpu(ResourcePool)
      end)

      end_time = System.monotonic_time(:microsecond)
      # Convert to milliseconds
      (end_time - start_time) / iterations / 1000
    end

    defp benchmark_memory_usage do
      initial_memory = :erlang.memory(:total)

      # Perform operations
      Enum.each(1..100, fn _i ->
        ResourcePool.get_pool_status(ResourcePool)
      end)

      final_memory = :erlang.memory(:total)
      final_memory - initial_memory
    end
  end
end
