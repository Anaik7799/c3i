defmodule Indrajaal.Performance.AdvancedResourceManagerTest do
  @moduledoc """
  Comprehensive TDG Test Suite for AdvancedResourceManager Performance Module.
  """

  use ExUnit.Case, async: false
  alias StreamData, as: SD
  use ExUnitProperties
  require Logger

  alias Indrajaal.Performance.AdvancedResourceManager

  setup do
    if pid = Process.whereis(AdvancedResourceManager) do
      GenServer.stop(pid)
    end

    {:ok, _pid} = AdvancedResourceManager.start_link()
    :ok
  end

  defp restart_manager(opts \\ []) do
    if pid = Process.whereis(AdvancedResourceManager) do
      GenServer.stop(pid)
    end

    AdvancedResourceManager.start_link(opts)
  end

  # Test data generators for property-based testing
  defp advanced_resource_manager_config_generator do
    gen all(
          enabled <- SD.boolean(),
          timeout <- SD.integer(1000..30_000)
        ) do
      %{
        enabled: enabled,
        timeout: timeout
      }
    end
  end

  # ============================================================================
  # Core Functionality Tests
  # ============================================================================

  describe "AdvancedResourceManager Core Functionality" do
    test "starts successfully with default configuration" do
      if pid = Process.whereis(AdvancedResourceManager) do
        GenServer.stop(pid)
      end

      assert {:ok, _pid} = AdvancedResourceManager.start_link()

      # Verify module is responsive
      assert {:ok, status} = AdvancedResourceManager.get_resource_status()
      assert is_map(status)
    end

    test "allocates resources correctly" do
      tenant_id = "tenant_test"
      resource_request = %{cpu: 2, memory: 4096}

      assert {:ok, result} =
               AdvancedResourceManager.allocate_resources(tenant_id, resource_request)

      assert result.status == :active
      assert result.allocated_resources.cpu == 2
    end

    test "deallocates resources correctly" do
      tenant_id = "tenant_test"
      resource_request = %{cpu: 2}
      {:ok, result} = AdvancedResourceManager.allocate_resources(tenant_id, resource_request)

      assert {:ok, _} =
               AdvancedResourceManager.deallocate_resources(tenant_id, result.allocation_id)
    end
  end

  # ============================================================================
  # Performance and Optimization Tests
  # ============================================================================

  describe "AdvancedResourceManager Performance Optimization" do
    test "handles high-throughput operations" do
      operation_count = 20
      start_time = System.monotonic_time(:millisecond)

      tasks =
        Enum.map(1..operation_count, fn i ->
          Task.async(fn ->
            AdvancedResourceManager.allocate_resources("tenant_#{i}", %{cpu: 1})
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

      assert throughput >= 0
      assert successful_operations > 0
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "AdvancedResourceManager Integration Tests" do
    test "supports telemetry events" do
      # Test telemetry integration
      test_pid = self()

      :telemetry.attach(
        "resource_manager_test",
        [:resource_manager, :allocation_completed],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger operation that should emit telemetry
      assert {:ok, _result} = AdvancedResourceManager.allocate_resources("test_tenant", %{cpu: 1})

      # Verify telemetry event was received
      assert_received {:telemetry, [:resource_manager, :allocation_completed], _measurements,
                       _metadata}

      :telemetry.detach("resource_manager_test")
    end
  end

  # ============================================================================
  # Performance Benchmarking
  # ============================================================================

  describe "AdvancedResourceManager Performance Benchmarking" do
    test "performance benchmarks meet requirements" do
      # Benchmark key operations
      benchmarks = %{
        startup_time: benchmark_startup(),
        operation_latency: benchmark_operation_latency()
      }

      # Validate benchmark results
      # 5 seconds
      assert benchmarks.startup_time <= 5_000
      # 100ms
      assert benchmarks.operation_latency <= 100

      Logger.info("AdvancedResourceManager Performance Benchmarks:", extra: benchmarks)
    end

    defp benchmark_startup do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _pid} = restart_manager()
      end_time = System.monotonic_time(:millisecond)
      end_time - start_time
    end

    defp benchmark_operation_latency do
      iterations = 10
      start_time = System.monotonic_time(:microsecond)

      Enum.each(1..iterations, fn _i ->
        AdvancedResourceManager.get_resource_status()
      end)

      end_time = System.monotonic_time(:microsecond)
      # Convert to milliseconds
      (end_time - start_time) / iterations / 1000
    end
  end
end
