defmodule Indrajaal.Performance.NUMAOptimizerTest do
  @moduledoc """
  Comprehensive TDG Test Suite for NUMAOptimizer Performance Module.

  This test suite implements Test-Driven Generation (TDG) methodology to validate:
  - NUMAOptimizer core functionality with comprehensive NUMA topology management
  - NUMA node affinity optimization and memory locality management
  - Integration with SOPv5.1 cybernetic framework
  - STAMP safety constraint compliance (SC1-SC5)
  - Multi-tenant NUMA isolation and QoS guarantees
  - Real-time NUMA analytics and optimization integration

  ## TDG Methodology Compliance

  All tests follow TDG principles:
  - Tests written BEFORE implementation validation
  - Comprehensive coverage of all NUMAOptimizer features
  - Property-based testing with ExUnitProperties
  - Performance benchmarking and regression testing
  - Safety constraint validation using STAMP methodology
  - Multi-agent coordination validation
  - Cybernetic feedback loop testing

  ## Test Categories

  - **Unit Tests**: Individual component testing
  - **Integration Tests**: Component interaction testing
  - **Performance Tests**: Load and stress testing
  - **Safety Tests**: STAMP safety constraint testing
  - **Cybernetic Tests**: SOPv5.1 framework testing
  - **End-to-End Tests**: Complete system workflow testing
  """

  use ExUnit.Case, async: false
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  require Logger

  alias Indrajaal.Performance.NUMAOptimizer

  setup do
    if pid = Process.whereis(NUMAOptimizer) do
      GenServer.stop(pid)
    end

    {:ok, _pid} = NUMAOptimizer.start_link()
    :ok
  end

  defp restart_optimizer(opts \\ []) do
    if pid = Process.whereis(NUMAOptimizer) do
      GenServer.stop(pid)
    end

    NUMAOptimizer.start_link(opts)
  end

  # Test data generators for property-based testing
  # Property-based test generators for NUMAOptimizer
  defp numa_optimizer_config_generator do
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

  defp numa_optimizer_metrics_generator do
    gen all(
          utilization <- SD.float(min: 0.0, max: 1.0),
          memory_locality <- SD.float(min: 0.0, max: 1.0),
          node_count <- SD.integer(1..16),
          affinity_efficiency <- SD.float(min: 0.0, max: 1.0)
        ) do
      %{
        utilization: utilization,
        memory_locality: memory_locality,
        node_count: node_count,
        affinity_efficiency: affinity_efficiency,
        timestamp: DateTime.utc_now()
      }
    end
  end

  # ============================================================================
  # Core Functionality Tests
  # ============================================================================

  describe "NUMAOptimizer Core Functionality" do
    test "starts with NUMA topology discovery" do
      numa_config = %{
        topology_discovery: true,
        memory_policy: :interleave,
        affinity_optimization: true,
        numa_nodes: [:node0, :node1, :node2, :node3]
      }

      assert {:ok, _pid} = restart_optimizer(numa_config)

      # Verify NUMA topology discovery is active
      assert {:ok, topology} = NUMAOptimizer.get_numa_topology()
      assert topology.discovery_active == true
      assert is_list(topology.available_nodes)
    end

    test "optimizes memory allocation for NUMA locality" do
      # Test NUMA-aware memory allocation
      memory_request = %{
        # 256MB
        size: 1024 * 1024 * 256,
        node_preference: :node0,
        access_pattern: :sequential,
        thread_affinity: :cpu0
      }

      assert {:ok, allocation} = NUMAOptimizer.allocate_numa_memory(memory_request)
      assert allocation.node_assigned in [:node0, :node1, :node2, :node3]
      assert allocation.locality_score >= 0.8
    end

    test "manages CPU affinity for optimal NUMA performance" do
      # Test CPU affinity optimization
      process_request = %{
        process_id: 1234,
        preferred_node: :node1,
        cpu_requirements: 4,
        memory_footprint: :large
      }

      assert {:ok, affinity} = NUMAOptimizer.set_cpu_affinity(process_request)
      assert affinity.assigned_cpus |> length() == 4
      assert affinity.numa_node == :node1
      assert affinity.affinity_efficiency >= 0.75
    end
  end

  # ============================================================================
  # Performance and Optimization Tests
  # ============================================================================

  describe "NUMAOptimizer Performance Optimization" do
    test "NUMA topology analysis provides comprehensive insights" do
      # Test NUMA topology analysis
      assert {:ok, analysis} = NUMAOptimizer.analyze_numa_topology()

      assert is_map(analysis)
      assert Map.has_key?(analysis, :node_count)
      assert Map.has_key?(analysis, :memory_distribution)
      assert Map.has_key?(analysis, :cpu_distribution)
      assert Map.has_key?(analysis, :interconnect_topology)

      # Verify analysis quality
      assert analysis.node_count >= 1
      assert analysis.analysis_quality >= 0.8
    end

    test "memory migration optimizes NUMA locality" do
      # Test memory page migration for NUMA optimization
      migration_request = %{
        process_id: 5678,
        source_node: :node2,
        target_node: :node0,
        memory_pages: 1000,
        migration_strategy: :gradual
      }

      assert {:ok, migration} = NUMAOptimizer.migrate_memory(migration_request)
      assert migration.pages_migrated <= migration_request.memory_pages
      assert migration.locality_improvement >= 0.1
      assert migration.migration_completed == true
    end

    test "balances workload across NUMA nodes" do
      # Test NUMA-aware load balancing
      workload = %{
        total_threads: 16,
        memory_intensive: true,
        cpu_intensive: false,
        preferred_distribution: :balanced
      }

      assert {:ok, distribution} = NUMAOptimizer.balance_workload(workload)

      # Verify balanced distribution
      total_assigned =
        distribution.node_assignments
        |> Map.values()
        |> Enum.sum()

      assert total_assigned == workload.total_threads
      assert distribution.balance_score >= 0.8
    end
  end

  # ============================================================================
  # Integration Tests
  # ============================================================================

  describe "NUMAOptimizer Integration Tests" do
    test "integrates with system performance monitoring" do
      # Verify monitoring integration
      assert {:ok, metrics} = NUMAOptimizer.get_metrics()
      assert is_map(metrics)
      assert Map.has_key?(metrics, :performance)
      assert Map.has_key?(metrics, :utilization)
    end

    test "supports telemetry __events for NUMA monitoring" do
      # Test telemetry integration
      test_pid = self()

      :telemetry.attach(
        "numa_optimizer_test",
        [:numa_optimizer, :operation],
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      # Trigger operation that should emit telemetry
      assert {:ok, _result} = NUMAOptimizer.perform_operation(:numa_telemetry_test)

      # Verify telemetry event was received
      assert_received {:telemetry, [:numa_optimizer, :operation], measurements, metadata}
      assert is_map(measurements)
      assert is_map(metadata)

      :telemetry.detach("numa_optimizer_test")
    end

    test "handles NUMA constraints gracefully" do
      # Test behavior under NUMA constraints
      # This would typically involve testing with limited NUMA resources

      # Simulate NUMA pressure
      numa_intensive_operations = 20

      results =
        Enum.map(1..numa_intensive_operations, fn _i ->
          NUMAOptimizer.perform_operation(:numa_intensive)
        end)

      # Verify system handles NUMA pressure
      successful_operations =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      # Should handle at least 70% of operations even under NUMA pressure
      assert successful_operations >= numa_intensive_operations * 0.7
    end

    test "coordinates with memory management systems" do
      # Test coordination with memory management
      memory_config = %{
        numa_aware_allocation: true,
        automatic_migration: true,
        locality_optimization: :aggressive
      }

      assert {:ok, result} = NUMAOptimizer.coordinate_memory_management(memory_config)
      assert result.numa_coordination_enabled == true
      assert result.memory_numa_balance == :optimal
    end
  end

  # ============================================================================
  # STAMP Safety Constraint Tests
  # ============================================================================

  describe "NUMAOptimizer STAMP Safety Validation" do
    test "validates STAMP safety constraint SC1: Data Integrity" do
      # Test NUMA data integrity under various conditions
      numa__data = %{
        id: 123,
        node_affinity: :node1,
        memory_size: 4096,
        timestamp: DateTime.utc_now()
      }

      assert {:ok, _result} = NUMAOptimizer.process_numa_data(numa__data)

      # Verify NUMA data integrity is maintained
      {:ok, processed_data} = NUMAOptimizer.get_processed_numa_data(numa__data.id)
      assert processed_data.id == numa__data.id
      assert processed_data.node_affinity == numa__data.node_affinity
      assert processed_data.memory_size == numa__data.memory_size
    end

    test "validates STAMP safety constraint SC2: Performance Bounds" do
      # Test NUMA performance stays within acceptable bounds
      # 1 second
      max_response_time = 1000

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, _result} = NUMAOptimizer.perform_operation(:numa_performance_check)
      end_time = System.monotonic_time(:millisecond)

      response_time = end_time - start_time
      assert response_time <= max_response_time
    end

    test "validates STAMP safety constraint SC3: Resource Limits" do
      # Test NUMA resource consumption stays within limits
      # 1GB
      memory_limit = 1024 * 1024 * 1024

      initial_memory = :erlang.memory(:total)

      # Perform NUMA memory-intensive operation
      assert {:ok, _result} = NUMAOptimizer.perform_operation(:numa_memory_intensive)

      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      # Should not increase memory by more than the limit
      assert memory_increase <= memory_limit
    end

    test "validates STAMP safety constraint SC4: Availability Guarantees" do
      # Verify availability
      assert {:ok, status} = NUMAOptimizer.get_status()
      assert status.available == true

      # Test availability under NUMA load
      load_tasks =
        Enum.map(1..10, fn _i ->
          Task.async(fn -> NUMAOptimizer.perform_operation(:numa_availability_test) end)
        end)

      Task.await_many(load_tasks, 5_000)

      # Verify still available after load
      assert {:ok, status} = NUMAOptimizer.get_status()
      assert status.available == true
    end

    test "validates STAMP safety constraint SC5: Security Isolation" do
      # Test NUMA security and isolation requirements
      tenant_a_numa = %{tenant_id: "tenant_a", numa_allocation: "node0,node1"}
      tenant_b_numa = %{tenant_id: "tenant_b", numa_allocation: "node2,node3"}

      assert {:ok, _} = NUMAOptimizer.process_tenant_numa_data(tenant_a_numa)
      assert {:ok, _} = NUMAOptimizer.process_tenant_numa_data(tenant_b_numa)

      # Verify tenant NUMA isolation
      {:ok, a_result} = NUMAOptimizer.get_tenant_numa_data("tenant_a")
      {:ok, b_result} = NUMAOptimizer.get_tenant_numa_data("tenant_b")

      assert a_result.numa_allocation == "node0,node1"
      assert b_result.numa_allocation == "node2,node3"

      # Verify tenant A cannot access tenant B's NUMA data
      assert {:error, :unauthorized} =
               NUMAOptimizer.get_tenant_numa_data_as("tenant_a", "tenant_b")
    end
  end

  # ============================================================================
  # SOPv5.1 Cybernetic Integration Tests
  # ============================================================================

  describe "NUMAOptimizer SOPv5.1 Cybernetic Integration" do
    test "supports SOPv5.1 goal-oriented NUMA execution" do
      # Test cybernetic goal-directed NUMA behavior
      numa_goal = %{
        type: :numa_locality_optimization,
        target_metric: :memory_locality,
        target_value: 0.90,
        priority: :high
      }

      assert {:ok, execution_result} = NUMAOptimizer.execute_numa_goal(numa_goal)
      assert execution_result.goal_achieved == true
      assert execution_result.locality_improvement >= 0.0
    end

    test "implements cybernetic NUMA feedback loops" do
      # Test NUMA feedback loop implementation
      initial_config = %{optimization_level: :low}

      assert {:ok, _pid} = restart_optimizer(initial_config)

      # Trigger NUMA feedback loop
      numa_feedback = %{
        locality_improvement: 0.20,
        affinity_improvement: 0.12,
        recommendation: :increase_numa_optimization
      }

      assert {:ok, adaptation_result} = NUMAOptimizer.apply_numa_feedback(numa_feedback)
      assert adaptation_result.configuration_updated == true
      assert adaptation_result.optimization_level == :medium
    end

    test "integrates with TPS methodology for NUMA management" do
      # Test TPS (Toyota Production System) integration for NUMA
      numa_improvement_opportunity = %{
        area: :numa_locality,
        current_locality: 0.65,
        target_locality: 0.85,
        kaizen_approach: :continuous_improvement
      }

      assert {:ok, tps_result} =
               NUMAOptimizer.apply_numa_tps_methodology(numa_improvement_opportunity)

      assert tps_result.improvements_identified > 0
      assert tps_result.kaizen_actions > 0
      assert tps_result.jidoka_applied == true
    end

    test "supports multi-agent NUMA coordination" do
      # Test multi-agent NUMA coordination capabilities
      numa_coordination_config = %{
        agent_count: 6,
        coordination_strategy: :numa_balanced,
        load_balancing: true
      }

      assert {:ok, coordination_result} =
               NUMAOptimizer.coordinate_numa_agents(numa_coordination_config)

      assert coordination_result.agents_coordinated == 6
      assert coordination_result.numa_load_balanced == true
      assert coordination_result.coordination_efficiency >= 0.8
    end

    test "implements patient mode NUMA execution" do
      # Test patient mode NUMA execution with extended timeouts
      patient_numa_config = %{
        # 1 minute
        timeout: 60_000,
        retries: 15,
        patience_level: :maximum
      }

      start_time = System.monotonic_time(:millisecond)

      assert {:ok, patient_result} =
               NUMAOptimizer.execute_numa_patiently(:complex_numa_operation, patient_numa_config)

      end_time = System.monotonic_time(:millisecond)

      execution_time = end_time - start_time

      # Should complete successfully even with extended NUMA execution
      assert patient_result.completed == true
      assert patient_result.retries_used <= 15

      # May take longer but should complete within patient timeout
      assert execution_time <= 60_000
    end
  end

  # ============================================================================
  # Property-Based Testing
  # ============================================================================

  describe "NUMAOptimizer Property-Based Testing" do
    test "maintains NUMA consistency across different configurations" do
      ExUnitProperties.check all(config <- numa_optimizer_config_generator()) do
        case restart_optimizer(config) do
          {:ok, _pid} ->
            # If started successfully, should be responsive
            assert {:ok, status} = NUMAOptimizer.get_status()
            assert is_map(status)

          {:error, reason} ->
            # If failed to start, reason should be valid
            assert is_atom(reason)
        end
      end
    end

    test "produces valid NUMA metrics under various conditions" do
      ExUnitProperties.check all(
                               operation_type <-
                                 SD.member_of([:standard_numa, :intensive_numa, :minimal_numa])
                             ) do
        case NUMAOptimizer.perform_operation(operation_type) do
          {:ok, result} ->
            # Successful NUMA operations should produce valid results
            assert is_map(result)

            if Map.has_key?(result, :numa_metrics) do
              assert is_map(result.numa_metrics)
            end

          {:error, reason} ->
            # Failed NUMA operations should have valid error reasons
            assert is_atom(reason)
        end
      end
    end

    test "handles concurrent NUMA operations safely" do
      ExUnitProperties.check all(operation_count <- SD.integer(1..20)) do
        tasks =
          Enum.map(1..operation_count, fn _i ->
            Task.async(fn ->
              NUMAOptimizer.perform_operation(:concurrent_numa_test)
            end)
          end)

        results = Task.await_many(tasks, 30_000)

        # At least some NUMA operations should succeed
        successful_operations =
          Enum.count(results, fn
            {:ok, _} -> true
            _ -> false
          end)

        assert successful_operations > 0

        # No more than the total number of operations
        assert successful_operations <= operation_count
      end
    end

    test "NUMA locality remains within valid bounds" do
      ExUnitProperties.check all(metrics <- numa_optimizer_metrics_generator()) do
        # Simulate processing NUMA metrics
        case NUMAOptimizer.process_numa_metrics(metrics) do
          {:ok, processed_metrics} ->
            # Memory locality should be between 0.0 and 1.0
            assert processed_metrics.memory_locality >= 0.0
            assert processed_metrics.memory_locality <= 1.0

            # Utilization should be non-negative
            assert processed_metrics.utilization >= 0.0

            # Node count should be positive
            assert processed_metrics.node_count > 0

          {:error, reason} ->
            # Valid error reasons for invalid metrics
            assert reason in [:invalid_metrics, :out_of_bounds]
        end
      end
    end
  end

  # ============================================================================
  # Performance Benchmarking
  # ============================================================================

  describe "NUMAOptimizer Performance Benchmarking" do
    test "NUMA performance benchmarks meet requirements" do
      # Benchmark key NUMA operations
      benchmarks = %{
        startup_time: benchmark_startup(),
        numa_operation_latency: benchmark_numa_operation_latency(),
        numa_throughput: benchmark_numa_throughput(),
        numa_memory_usage: benchmark_numa_memory_usage()
      }

      # Validate NUMA benchmark results
      # 5 seconds
      assert benchmarks.startup_time <= 5_000
      # 100ms
      assert benchmarks.numa_operation_latency <= 100
      # 100 NUMA ops/sec
      assert benchmarks.numa_throughput >= 100
      # 100MB
      assert benchmarks.numa_memory_usage <= 100 * 1024 * 1024

      Logger.info("NUMAOptimizer Performance Benchmarks:", extra: benchmarks)
    end

    defp benchmark_startup do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _pid} = restart_optimizer()
      end_time = System.monotonic_time(:millisecond)
      end_time - start_time
    end

    defp benchmark_numa_operation_latency do
      iterations = 100
      start_time = System.monotonic_time(:microsecond)

      Enum.each(1..iterations, fn _i ->
        NUMAOptimizer.perform_operation(:numa_benchmark)
      end)

      end_time = System.monotonic_time(:microsecond)
      # Convert to milliseconds
      (end_time - start_time) / iterations / 1000
    end

    defp benchmark_numa_throughput do
      # 5 seconds
      duration = 5_000
      start_time = System.monotonic_time(:millisecond)

      operations =
        fn ->
          NUMAOptimizer.perform_operation(:numa_throughput_test)
        end
        |> Stream.repeatedly()
        |> Stream.take_while(fn _ ->
          System.monotonic_time(:millisecond) - start_time < duration
        end)
        |> Enum.to_list()

      # Operations per second
      length(operations) / (duration / 1000)
    end

    defp benchmark_numa_memory_usage do
      initial_memory = :erlang.memory(:total)

      # Perform NUMA memory-intensive operations
      Enum.each(1..100, fn _i ->
        NUMAOptimizer.perform_operation(:numa_memory_benchmark)
      end)

      final_memory = :erlang.memory(:total)
      final_memory - initial_memory
    end
  end
end
