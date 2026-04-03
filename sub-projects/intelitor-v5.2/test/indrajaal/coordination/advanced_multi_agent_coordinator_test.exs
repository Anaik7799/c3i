defmodule Indrajaal.Coordination.AdvancedMultiAgentCoordinatorTest do
  use ExUnit.Case, async: false
  use Indrajaal.Ultimate.TestConsolidation
  alias Indrajaal.Coordination.AdvancedMultiAgentCoordinator

  @moduletag :coordination_tests

  describe "AdvancedMultiAgentCoordinator initialization" do
    test "starts successfully with default configuration" do
      {:ok, pid} = AdvancedMultiAgentCoordinator.start_link([])
      assert Process.alive?(pid)

      # Test basic coordination capabilities
      agents = create_test_agents(5)
      workload = create_test_workload(10)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(pid, workload, agents)

      assert result.execution_status == :completed
      assert is_list(result.task_assignments)
      assert length(result.task_assignments) > 0
    end

    test "starts with custom configuration" do
      config = [
        coordination_strategy: :performance_optimized,
        max_agents: 20,
        cybernetic_enabled: true,
        dynamic_scaling: true
      ]

      {:ok, pid} = AdvancedMultiAgentCoordinator.start_link(config)
      assert Process.alive?(pid)

      status = AdvancedMultiAgentCoordinator.get_coordination_status(pid)
      assert status.coordination_strategy == :performance_optimized
      assert status.max_agents == 20
      assert status.cybernetic_enabled == true
    end
  end

  describe "cybernetic workload execution" do
    setup do
      {:ok, coordinator} = AdvancedMultiAgentCoordinator.start_link([])
      %{coordinator: coordinator}
    end

    test "executes workload with cybernetic optimization", %{coordinator: coordinator} do
      # 1 supervisor + 4 helpers + 6 workers
      agents = create_test_agents(11)
      workload = create_complex_workload(25)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      # Validate cybernetic execution
      assert result.execution_status == :completed
      assert result.cybernetic_optimizations_applied > 0
      assert result.performance_improvement > 0
      assert is_integer(result.execution_time_ms)
      assert result.execution_time_ms > 0

      # Validate task assignments
      assert length(result.task_assignments) == 25

      # Validate agent utilization
      agent_utilization = result.agent_utilization
      assert Map.has_key?(agent_utilization, "supervisor_1")
      assert Map.has_key?(agent_utilization, "helper_1")
      assert Map.has_key?(agent_utilization, "worker_1")
    end

    test "handles workload with priority - based assignment", %{coordinator: coordinator} do
      agents = create_test_agents(8)
      workload = create_priority_workload()

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      # Validate priority handling
      critical_tasks =
        Enum.filter(result.task_assignments, fn assignment ->
          assignment.task.priority == :critical
        end)

      # Critical tasks should be assigned to high - performance agents
      Enum.each(critical_tasks, fn assignment ->
        assert assignment.agent.type in [:supervisor, :specialist]
      end)
    end

    test "applies dynamic scaling during execution", %{coordinator: coordinator} do
      # Start with fewer agents
      agents = create_test_agents(5)
      # Large workload __requiring scaling
      large_workload = create_test_workload(50)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(
          coordinator,
          large_workload,
          agents
        )

      # Should have scaled up agents during execution
      assert result.dynamic_scaling_applied == true
      assert result.agents_scaled_up > 0
      assert length(result.final_agent_pool) > 5
    end

    test "handles agent failures gracefully", %{coordinator: coordinator} do
      # Include some failing agents
      agents = create_test_agents_with_failure(10)
      workload = create_test_workload(15)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      # Should complete despite failures
      assert result.execution_status == :completed
      assert result.failed_agents > 0
      assert result.recovery_actions_taken > 0

      # All tasks should still be assigned
      assert length(result.task_assignments) == 15
    end
  end

  describe "agent management" do
    setup do
      {:ok, coordinator} = AdvancedMultiAgentCoordinator.start_link([])
      %{coordinator: coordinator}
    end

    test "scales agents up when needed", %{coordinator: coordinator} do
      initial_agents = create_test_agents(3)

      {:ok, result} = AdvancedMultiAgentCoordinator.scale_agents(coordinator, initial_agents, 8)

      assert result.scaling_action == :scale_up
      assert result.agents_added == 5
      assert length(result.final_agent_pool) == 8
    end

    test "scales agents down when appropriate", %{coordinator: coordinator} do
      initial_agents = create_test_agents(15)

      {:ok, result} = AdvancedMultiAgentCoordinator.scale_agents(coordinator, initial_agents, 8)

      assert result.scaling_action == :scale_down
      assert result.agents_removed == 7
      assert length(result.final_agent_pool) == 8
    end

    test "optimizes agent allocation", %{coordinator: coordinator} do
      agents = create_mixed_performance_agents(10)

      {:ok, result} = AdvancedMultiAgentCoordinator.optimize_agent_allocation(coordinator, agents)

      assert result.optimization_applied == true
      assert result.performance_improvement > 0
      assert is_map(result.optimized_allocation)
    end
  end

  describe "coordination strategies" do
    setup do
      {:ok, coordinator} = AdvancedMultiAgentCoordinator.start_link([])
      %{coordinator: coordinator}
    end

    test "applies performance - optimized strategy" do
      agents = create_test_agents(10)
      workload = create_performance_critical_workload()

      {:ok, coordinator} =
        AdvancedMultiAgentCoordinator.start_link(coordination_strategy: :performance_optimized)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      assert result.strategy_applied == :performance_optimized
      assert result.performance_score > 80.0
    end

    test "applies resource - efficient strategy" do
      agents = create_test_agents(10)
      workload = create_resource_intensive_workload()

      {:ok, coordinator} =
        AdvancedMultiAgentCoordinator.start_link(coordination_strategy: :resource_efficient)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      assert result.strategy_applied == :resource_efficient
      assert result.resource_efficiency > 75.0
    end

    test "applies fault - tolerant strategy" do
      # Agents with potential failures
      agents = create_unreliable_agents(10)
      workload = create_test_workload(20)

      {:ok, coordinator} =
        AdvancedMultiAgentCoordinator.start_link(coordination_strategy: :fault_tolerant)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      assert result.strategy_applied == :fault_tolerant
      assert result.fault_tolerance_score > 85.0
      # Should complete despite unreliable agents
      assert result.execution_status == :completed
    end
  end

  describe "performance monitoring" do
    setup do
      {:ok, coordinator} = AdvancedMultiAgentCoordinator.start_link([])
      %{coordinator: coordinator}
    end

    test "tracks execution metrics", %{coordinator: coordinator} do
      agents = create_test_agents(8)
      workload = create_test_workload(15)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      metrics = AdvancedMultiAgentCoordinator.get_performance_metrics(coordinator)

      assert metrics.total_executions >= 1
      assert metrics.successful_executions >= 1
      assert is_float(metrics.average_execution_time_ms)
      assert is_float(metrics.average_agent_utilization)
      assert is_list(metrics.performance_history)
    end

    test "provides detailed coordination status", %{coordinator: coordinator} do
      status = AdvancedMultiAgentCoordinator.get_coordination_status(coordinator)

      assert Map.has_key?(status, :active_agents)
      assert Map.has_key?(status, :pending_tasks)
      assert Map.has_key?(status, :coordination_strategy)
      assert Map.has_key?(status, :cybernetic_enabled)
      assert Map.has_key?(status, :performance_score)
      assert is_float(status.performance_score)
    end
  end

  describe "error handling and recovery" do
    setup do
      {:ok, coordinator} = AdvancedMultiAgentCoordinator.start_link([])
      %{coordinator: coordinator}
    end

    test "handles malformed workload gracefully", %{coordinator: coordinator} do
      agents = create_test_agents(5)
      malformed_workload = %{invalid: :workload}

      result =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(
          coordinator,
          malformed_workload,
          agents
        )

      assert {:error, reason} = result
      assert is_binary(reason) or is_atom(reason)
    end

    test "handles empty agent pool", %{coordinator: coordinator} do
      empty_agents = %{}
      workload = create_test_workload(5)

      result =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(
          coordinator,
          workload,
          empty_agents
        )

      assert {:error, reason} = result
      assert reason =~ "no agents" or reason == :no_agents_available
    end

    test "handles agent communication failures", %{coordinator: coordinator} do
      agents = create_test_agents_with_communication_failures(8)
      workload = create_test_workload(10)

      {:ok, result} =
        AdvancedMultiAgentCoordinator.execute_cybernetic_workload(coordinator, workload, agents)

      # Should complete with recovery actions
      assert result.execution_status == :completed
      assert result.communication_failures > 0
      assert result.recovery_actions_taken > 0
    end
  end

  # Helper functions for creating test __data

  defp create_test_agents(count) do
    supervisor_count = 1
    helper_count = min(4, div(count - 1, 2))
    worker_count = count - supervisor_count - helper_count

    agents = %{}

    # Add supervisor
    agents =
      Map.put(agents, "supervisor_1", %{
        id: "supervisor_1",
        type: :supervisor,
        status: :idle,
        capabilities: [:coordination, :decision_making, :oversight],
        performance_score: 95.0,
        resource_usage: %{cpu: 20.0, memory: 15.0}
      })

    # Add helpers
    agents =
      Enum.reduce(1..helper_count, agents, fn i, acc ->
        Map.put(acc, "helper_#{i}", %{
          id: "helper_#{i}",
          type: :helper,
          status: :idle,
          capabilities: [:analysis, :optimization, :support],
          performance_score: 85.0 + :rand.uniform() * 10,
          resource_usage: %{cpu: 30.0, memory: 25.0}
        })
      end)

    # Add workers
    Enum.reduce(1..worker_count, agents, fn i, acc ->
      Map.put(acc, "worker_#{i}", %{
        id: "worker_#{i}",
        type: :worker,
        status: :idle,
        capabilities: [:execution, :processing],
        performance_score: 70.0 + :rand.uniform() * 20,
        resource_usage: %{cpu: 40.0, memory: 30.0}
      })
    end)
  end

  defp create_test_workload(task_count) do
    %{
      tasks:
        Enum.map(1..task_count, fn i ->
          %{
            id: "task_#{i}",
            type: Enum.random([:computation, :analysis, :processing]),
            priority: Enum.random([:low, :medium, :high]),
            estimated_load: :rand.uniform(10),
            complexity: :rand.uniform(5),
            required_capabilities: []
          }
        end),
      metadata: %{
        total_tasks: task_count,
        estimated_duration_ms: task_count * 1000,
        resource_requirements: %{cpu: task_count * 5, memory: task_count * 3}
      }
    }
  end

  defp create_complex_workload(task_count) do
    workload = create_test_workload(task_count)

    # Add complexity and dependencies
    complex_tasks =
      Enum.map(workload.tasks, fn task ->
        Map.merge(task, %{
          # Higher complexity
          complexity: :rand.uniform(8) + 2,
          dependencies:
            if(:rand.uniform() < 0.3, do: ["task_#{:rand.uniform(task_count)}"], else: []),
          required_capabilities:
            Enum.take_random(
              [:analysis, :optimization, :coordination, :processing],
              :rand.uniform(3)
            )
        })
      end)

    %{workload | tasks: complex_tasks}
  end

  defp create_priority_workload do
    critical_tasks =
      Enum.map(1..3, fn i ->
        %{
          id: "critical_task_#{i}",
          type: :critical_processing,
          priority: :critical,
          estimated_load: 8,
          complexity: 7,
          required_capabilities: [:coordination, :analysis]
        }
      end)

    high_tasks =
      Enum.map(1..5, fn i ->
        %{
          id: "high_task_#{i}",
          type: :analysis,
          priority: :high,
          estimated_load: 5,
          complexity: 4,
          required_capabilities: [:analysis]
        }
      end)

    normal_tasks =
      Enum.map(1..7, fn i ->
        %{
          id: "normal_task_#{i}",
          type: :processing,
          priority: :medium,
          estimated_load: 3,
          complexity: 2,
          required_capabilities: [:processing]
        }
      end)

    %{
      tasks: critical_tasks ++ high_tasks ++ normal_tasks,
      metadata: %{
        total_tasks: 15,
        priority_distribution: %{critical: 3, high: 5, medium: 7},
        estimated_duration_ms: 45_000
      }
    }
  end

  defp create_test_agents_with_failure(count) do
    agents = create_test_agents(count)

    # Make some agents fail randomly
    # 25% failure rate
    failing_agent_count = div(count, 4)

    failing_agents =
      agents
      |> Map.keys()
      |> Enum.take_random(failing_agent_count)

    Enum.reduce(failing_agents, agents, fn agent_id, acc ->
      Map.update!(acc, agent_id, fn agent ->
        Map.merge(agent, %{
          status: :unhealthy,
          failure_probability: 0.7,
          failure_type: Enum.random([:communication, :resource_exhaustion, :timeout])
        })
      end)
    end)
  end

  defp create_mixed_performance_agents(count) do
    agents = create_test_agents(count)

    Enum.reduce(agents, %{}, fn {agent_id, agent}, acc ->
      # -20 to +20
      performance_variation = :rand.uniform() * 40 - 20
      new_performance = max(10.0, min(100.0, agent.performance_score + performance_variation))

      updated_agent = Map.put(agent, :performance_score, new_performance)
      Map.put(acc, agent_id, updated_agent)
    end)
  end

  defp create_performance_critical_workload do
    %{
      tasks:
        Enum.map(1..8, fn i ->
          %{
            id: "perf_task_#{i}",
            type: :high_performance_computation,
            priority: :high,
            estimated_load: 8,
            complexity: 6,
            performance_requirements: %{min_score: 80.0, response_time_ms: 500},
            required_capabilities: [:optimization, :processing]
          }
        end),
      metadata: %{
        total_tasks: 8,
        performance_critical: true,
        target_completion_time_ms: 5000
      }
    }
  end

  defp create_resource_intensive_workload do
    %{
      tasks:
        Enum.map(1..12, fn i ->
          %{
            id: "resource_task_#{i}",
            type: :resource_intensive_processing,
            priority: :medium,
            estimated_load: 6,
            complexity: 4,
            resource_requirements: %{cpu: 60, memory: 80, disk: 40},
            required_capabilities: [:processing]
          }
        end),
      metadata: %{
        total_tasks: 12,
        resource_intensive: true,
        estimated_resource_usage: %{cpu: 720, memory: 960, disk: 480}
      }
    }
  end

  defp create_unreliable_agents(count) do
    agents = create_test_agents(count)

    # Add reliability issues to some agents
    Enum.reduce(agents, %{}, fn {agent_id, agent}, acc ->
      # 60 - 90% reliability
      reliability_score = 60.0 + :rand.uniform() * 30

      updated_agent =
        Map.merge(agent, %{
          reliability_score: reliability_score,
          failure_probability: (100 - reliability_score) / 100,
          recovery_time_ms: :rand.uniform(5000) + 1000
        })

      Map.put(acc, agent_id, updated_agent)
    end)
  end

  defp create_test_agents_with_communication_failures(count) do
    agents = create_test_agents(count)

    # Add communication issues to some agents
    # 33% with communication issues
    failing_count = div(count, 3)

    failing_agents =
      agents
      |> Map.keys()
      |> Enum.take_random(failing_count)

    Enum.reduce(failing_agents, agents, fn agent_id, acc ->
      Map.update!(acc, agent_id, fn agent ->
        Map.merge(agent, %{
          communication_failure_rate: 0.4,
          network_latency_ms: 5000 + :rand.uniform(10_000),
          timeout_probability: 0.3
        })
      end)
    end)
  end
end
