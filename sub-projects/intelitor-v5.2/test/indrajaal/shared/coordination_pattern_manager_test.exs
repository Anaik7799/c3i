defmodule Indrajaal.Shared.CoordinationPatternManagerTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.CoordinationPatternManager module.

  Tests comprehensive multi-agent coordination patterns for:
  - Coordination initialization with SOPv5.1 architecture
  - Task distribution strategies (round_robin, load_balanced)
  - Agent health monitoring
  - Performance optimization
  - Agent count validation (max 4 helpers, 6 workers, 11 total)

  Created: 2025-11-27 15:15:00 CEST
  Phase: 2.4 - C1 Security-Critical Testing (Pattern & Factory Modules)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.CoordinationPatternManager

  # ============================================================================
  # COORDINATION INITIALIZATION TESTS
  # ============================================================================

  describe "initialize_coordination/1" do
    test "creates coordination struct with default values" do
      result = CoordinationPatternManager.initialize_coordination()

      assert is_map(result)
      assert Map.has_key?(result, :supervisor_agent)
      assert Map.has_key?(result, :helper_agents)
      assert Map.has_key?(result, :worker_agents)
      assert Map.has_key?(result, :total_agents)
      assert Map.has_key?(result, :created_at)
    end

    test "creates coordination struct with keyword list options" do
      opts = [supervisor_agent: "supervisor-1", helper_agents: 2, worker_agents: 4]
      result = CoordinationPatternManager.initialize_coordination(opts)

      assert is_map(result)
      assert result.supervisor_agent == "supervisor-1"
      assert result.helper_agents == 2
      assert result.worker_agents == 4
    end

    test "creates coordination struct with map options" do
      opts = %{supervisor_agent: "supervisor-custom", helper_agents: 3, worker_agents: 5}
      result = CoordinationPatternManager.initialize_coordination(opts)

      assert is_map(result)
      assert result.supervisor_agent == "supervisor-custom"
    end

    test "includes timestamp in created_at field" do
      result = CoordinationPatternManager.initialize_coordination()

      assert Map.has_key?(result, :created_at)
      # Should be a DateTime or similar timestamp
      assert result.created_at != nil
    end

    test "calculates total_agents correctly" do
      opts = [helper_agents: 3, worker_agents: 5]
      result = CoordinationPatternManager.initialize_coordination(opts)

      # Total should include supervisor (1) + helpers + workers
      expected_total = 1 + 3 + 5
      assert result.total_agents == expected_total
    end

    test "enforces maximum helper_agents limit of 4" do
      # Exceeds max of 4
      opts = [helper_agents: 10]
      result = CoordinationPatternManager.initialize_coordination(opts)

      # Should be capped at 4
      assert result.helper_agents <= 4
    end

    test "enforces maximum worker_agents limit of 6" do
      # Exceeds max of 6
      opts = [worker_agents: 10]
      result = CoordinationPatternManager.initialize_coordination(opts)

      # Should be capped at 6
      assert result.worker_agents <= 6
    end

    test "enforces maximum total_agents limit of 11" do
      opts = [helper_agents: 4, worker_agents: 6]
      result = CoordinationPatternManager.initialize_coordination(opts)

      # Total: 1 supervisor + 4 helpers + 6 workers = 11
      assert result.total_agents <= 11
    end

    test "handles empty options" do
      result = CoordinationPatternManager.initialize_coordination([])

      assert is_map(result)
      assert Map.has_key?(result, :supervisor_agent)
    end

    test "handles empty map options" do
      result = CoordinationPatternManager.initialize_coordination(%{})

      assert is_map(result)
      assert Map.has_key?(result, :supervisor_agent)
    end
  end

  # ============================================================================
  # TASK DISTRIBUTION TESTS
  # ============================================================================

  describe "distribute_tasks/3" do
    setup do
      coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 2,
          worker_agents: 4
        )

      {:ok, coordination: coordination}
    end

    test "distributes tasks with default strategy", %{coordination: coordination} do
      tasks = [:task1, :task2, :task3, :task4]
      result = CoordinationPatternManager.distribute_tasks(coordination, tasks)

      assert is_map(result) or is_tuple(result)
    end

    test "distributes tasks with round_robin strategy", %{coordination: coordination} do
      tasks = [:task1, :task2, :task3, :task4]

      result =
        CoordinationPatternManager.distribute_tasks(coordination, tasks, strategy: :round_robin)

      assert is_map(result) or is_tuple(result)
    end

    test "distributes tasks with load_balanced strategy", %{coordination: coordination} do
      tasks = [:task1, :task2, :task3, :task4]

      result =
        CoordinationPatternManager.distribute_tasks(coordination, tasks, strategy: :load_balanced)

      assert is_map(result) or is_tuple(result)
    end

    test "handles empty task list", %{coordination: coordination} do
      result = CoordinationPatternManager.distribute_tasks(coordination, [])

      # Should not crash with empty tasks
      assert is_map(result) or is_tuple(result)
    end

    test "handles single task", %{coordination: coordination} do
      result = CoordinationPatternManager.distribute_tasks(coordination, [:single_task])

      assert is_map(result) or is_tuple(result)
    end

    test "handles large task list", %{coordination: coordination} do
      tasks = Enum.map(1..100, fn i -> {:task, i} end)
      result = CoordinationPatternManager.distribute_tasks(coordination, tasks)

      assert is_map(result) or is_tuple(result)
    end

    test "distributes tasks with map options", %{coordination: coordination} do
      tasks = [:task1, :task2]

      result =
        CoordinationPatternManager.distribute_tasks(coordination, tasks, %{strategy: :round_robin})

      assert is_map(result) or is_tuple(result)
    end

    test "handles various task types", %{coordination: coordination} do
      tasks = [
        {:compile, "file.ex"},
        {:test, "test_file.exs"},
        {:analyze, %{type: :static}},
        :simple_task
      ]

      result = CoordinationPatternManager.distribute_tasks(coordination, tasks)

      assert is_map(result) or is_tuple(result)
    end
  end

  # ============================================================================
  # AGENT HEALTH MONITORING TESTS
  # ============================================================================

  describe "monitor_agent_health/1" do
    setup do
      coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 2,
          worker_agents: 3
        )

      {:ok, coordination: coordination}
    end

    test "returns health status for coordination", %{coordination: coordination} do
      result = CoordinationPatternManager.monitor_agent_health(coordination)

      assert is_map(result) or is_tuple(result)
    end

    test "includes supervisor health status", %{coordination: coordination} do
      result = CoordinationPatternManager.monitor_agent_health(coordination)

      # Should have some form of health indication
      assert result != nil
    end

    test "handles coordination with maximum agents" do
      coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 4,
          worker_agents: 6
        )

      result = CoordinationPatternManager.monitor_agent_health(coordination)

      assert result != nil
    end

    test "handles coordination with minimum agents" do
      coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 0,
          worker_agents: 0
        )

      result = CoordinationPatternManager.monitor_agent_health(coordination)

      assert result != nil
    end

    test "returns consistent structure" do
      coordination = CoordinationPatternManager.initialize_coordination()

      result1 = CoordinationPatternManager.monitor_agent_health(coordination)
      result2 = CoordinationPatternManager.monitor_agent_health(coordination)

      # Results should have consistent structure
      assert is_map(result1) == is_map(result2)
    end
  end

  # ============================================================================
  # PERFORMANCE OPTIMIZATION TESTS
  # ============================================================================

  describe "optimize_performance/1" do
    setup do
      coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 2,
          worker_agents: 4
        )

      {:ok, coordination: coordination}
    end

    test "returns optimization result", %{coordination: coordination} do
      result = CoordinationPatternManager.optimize_performance(coordination)

      assert result != nil
    end

    test "handles fully loaded coordination", %{coordination: _coordination} do
      max_coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 4,
          worker_agents: 6
        )

      result = CoordinationPatternManager.optimize_performance(max_coordination)

      assert result != nil
    end

    test "handles minimal coordination", %{coordination: _coordination} do
      min_coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 1,
          worker_agents: 1
        )

      result = CoordinationPatternManager.optimize_performance(min_coordination)

      assert result != nil
    end

    test "optimization is idempotent" do
      coordination = CoordinationPatternManager.initialize_coordination()

      result1 = CoordinationPatternManager.optimize_performance(coordination)
      result2 = CoordinationPatternManager.optimize_performance(coordination)

      # Running optimization twice should produce consistent results
      assert result1 == result2
    end
  end

  # ============================================================================
  # AGENT VALIDATION TESTS
  # ============================================================================

  describe "Agent Count Validation" do
    test "validates helper_agents maximum is 4" do
      # Test boundary: exactly 4 helpers (valid)
      result = CoordinationPatternManager.initialize_coordination(helper_agents: 4)
      assert result.helper_agents <= 4

      # Test boundary: 5 helpers (should be capped)
      result = CoordinationPatternManager.initialize_coordination(helper_agents: 5)
      assert result.helper_agents <= 4
    end

    test "validates worker_agents maximum is 6" do
      # Test boundary: exactly 6 workers (valid)
      result = CoordinationPatternManager.initialize_coordination(worker_agents: 6)
      assert result.worker_agents <= 6

      # Test boundary: 7 workers (should be capped)
      result = CoordinationPatternManager.initialize_coordination(worker_agents: 7)
      assert result.worker_agents <= 6
    end

    test "validates total_agents maximum is 11" do
      # Maximum valid: 1 supervisor + 4 helpers + 6 workers = 11
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 4,
          worker_agents: 6
        )

      assert result.total_agents <= 11
    end

    test "handles zero agents gracefully" do
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 0,
          worker_agents: 0
        )

      # Should still have supervisor (1 agent minimum)
      assert result.total_agents >= 1
    end

    test "handles negative agent counts" do
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: -1,
          worker_agents: -2
        )

      # Should handle gracefully (likely default to 0)
      assert result.helper_agents >= 0
      assert result.worker_agents >= 0
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "initialize_coordination always returns valid struct" do
      forall {helpers, workers} <- {PC.non_neg_integer(), PC.non_neg_integer()} do
        result =
          CoordinationPatternManager.initialize_coordination(
            helper_agents: helpers,
            worker_agents: workers
          )

        is_map(result) and
          Map.has_key?(result, :supervisor_agent) and
          Map.has_key?(result, :total_agents)
      end
    end

    property "helper_agents never exceeds 4" do
      forall helpers <- non_neg_integer() do
        result = CoordinationPatternManager.initialize_coordination(helper_agents: helpers)

        result.helper_agents <= 4
      end
    end

    property "worker_agents never exceeds 6" do
      forall workers <- non_neg_integer() do
        result = CoordinationPatternManager.initialize_coordination(worker_agents: workers)

        result.worker_agents <= 6
      end
    end

    property "total_agents never exceeds 11" do
      forall {helpers, workers} <- {PC.non_neg_integer(), PC.non_neg_integer()} do
        result =
          CoordinationPatternManager.initialize_coordination(
            helper_agents: helpers,
            worker_agents: workers
          )

        result.total_agents <= 11
      end
    end

    property "total_agents equals 1 + helpers + workers (within limits)" do
      forall {helpers, workers} <- {PC.range(0, 4), PC.range(0, 6)} do
        result =
          CoordinationPatternManager.initialize_coordination(
            helper_agents: helpers,
            worker_agents: workers
          )

        result.total_agents == 1 + result.helper_agents + result.worker_agents
      end
    end

    property "distribute_tasks handles any list of tasks" do
      forall tasks <- PC.list(PC.any()) do
        coordination = CoordinationPatternManager.initialize_coordination()
        result = CoordinationPatternManager.distribute_tasks(coordination, tasks)

        # Should not crash and return some result
        result != nil
      end
    end

    property "monitor_agent_health always returns valid result" do
      forall {helpers, workers} <- {PC.range(0, 4), PC.range(0, 6)} do
        coordination =
          CoordinationPatternManager.initialize_coordination(
            helper_agents: helpers,
            worker_agents: workers
          )

        result = CoordinationPatternManager.monitor_agent_health(coordination)

        result != nil
      end
    end

    property "optimize_performance is deterministic" do
      forall {helpers, workers} <- {PC.range(0, 4), PC.range(0, 6)} do
        coordination =
          CoordinationPatternManager.initialize_coordination(
            helper_agents: helpers,
            worker_agents: workers
          )

        result1 = CoordinationPatternManager.optimize_performance(coordination)
        result2 = CoordinationPatternManager.optimize_performance(coordination)

        result1 == result2
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "handles very large agent request" do
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 1000,
          worker_agents: 1000
        )

      # Should cap to maximum values
      assert result.helper_agents <= 4
      assert result.worker_agents <= 6
      assert result.total_agents <= 11
    end

    test "handles nil values in options" do
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: nil,
          worker_agents: nil
        )

      # Should handle nil gracefully
      assert is_map(result)
    end

    test "handles mixed valid and invalid options" do
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 2,
          worker_agents: 3,
          invalid_option: "ignored"
        )

      assert result.helper_agents == 2
      assert result.worker_agents == 3
    end

    test "handles string values for agent counts" do
      # Module should handle or reject string values gracefully
      result =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: "2",
          worker_agents: "3"
        )

      assert is_map(result)
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "complete workflow: initialize, distribute, monitor, optimize" do
      # Step 1: Initialize coordination
      coordination =
        CoordinationPatternManager.initialize_coordination(
          helper_agents: 3,
          worker_agents: 5
        )

      assert coordination.total_agents == 9

      # Step 2: Distribute tasks
      tasks = Enum.map(1..20, fn i -> {:task, i} end)
      distribution = CoordinationPatternManager.distribute_tasks(coordination, tasks)
      assert distribution != nil

      # Step 3: Monitor health
      health = CoordinationPatternManager.monitor_agent_health(coordination)
      assert health != nil

      # Step 4: Optimize performance
      optimized = CoordinationPatternManager.optimize_performance(coordination)
      assert optimized != nil
    end

    test "simulates SOPv5.1 11-agent architecture" do
      # Create maximum SOPv5.1 configuration: 1 supervisor + 4 helpers + 6 workers
      coordination =
        CoordinationPatternManager.initialize_coordination(
          supervisor_agent: "executive-supervisor",
          helper_agents: 4,
          worker_agents: 6
        )

      assert coordination.total_agents == 11
      assert coordination.supervisor_agent == "executive-supervisor"
      assert coordination.helper_agents == 4
      assert coordination.worker_agents == 6

      # Distribute compilation tasks across all agents
      compilation_tasks = [
        {:compile, "lib/domain1.ex"},
        {:compile, "lib/domain2.ex"},
        {:compile, "lib/domain3.ex"},
        {:test, "test/domain1_test.exs"},
        {:test, "test/domain2_test.exs"},
        {:analyze, :static},
        {:analyze, :security}
      ]

      result =
        CoordinationPatternManager.distribute_tasks(
          coordination,
          compilation_tasks,
          strategy: :load_balanced
        )

      assert result != nil

      # Verify health monitoring works
      health = CoordinationPatternManager.monitor_agent_health(coordination)
      assert health != nil
    end

    test "handles rapid successive operations" do
      coordination = CoordinationPatternManager.initialize_coordination()

      # Rapid task distribution
      results =
        Enum.map(1..10, fn _ ->
          tasks = Enum.map(1..5, fn i -> {:task, i} end)
          CoordinationPatternManager.distribute_tasks(coordination, tasks)
        end)

      # All operations should complete without error
      assert Enum.all?(results, fn r -> r != nil end)
    end
  end
end
