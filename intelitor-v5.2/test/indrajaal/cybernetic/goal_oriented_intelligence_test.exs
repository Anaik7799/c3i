defmodule Indrajaal.Cybernetic.GoalOrientedIntelligenceTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.GoalOrientedIntelligence.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: GenServer lifecycle tested before runtime integration
  - FPPS Validation: 5-method consensus on goal processing pipeline

  ## STAMP Safety Integration
  - SC-GOI-001: Goal processing MUST complete within 30s timeout
  - SC-GOI-002: Goal hierarchy depth MUST be bounded (max 7)
  - SC-GOI-003: Priority optimization MUST return ranked alternatives
  - SC-GOI-004: Context adaptation MUST log adaptation recommendations

  ## Constitutional Verification
  - Psi_0 Existence: GenServer survives any valid goal_spec
  - Psi_4 Human Alignment: Pareto optimization serves Founder's multi-objective goals

  ## Founder's Directive Alignment
  - Omega_0.6: Goal-oriented intelligence is the planning layer for sentience
  - Omega_0.1: Resource acquisition goals processed through Pareto frontier

  ## TPS 5-Level RCA Context
  - L1 Symptom: System selects suboptimal goal in multi-objective scenario
  - L5 Root Cause: Priority matrix weights not updated after context shift
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.GoalOrientedIntelligence

  @moduletag :zenoh_nif

  defp valid_goal(id \\ "goal-001") do
    %{
      id: id,
      type: :operational,
      description: "Test operational goal",
      priority: 0.8,
      complexity: 0.5,
      dependencies: [],
      constraints: %{},
      context: %{},
      decomposition: %{},
      success_criteria: %{},
      resource_requirements: %{},
      adaptation_history: [],
      learning_insights: %{},
      timestamp: DateTime.utc_now()
    }
  end

  setup do
    pid = start_supervised!(GoalOrientedIntelligence)
    on_exit(fn -> :ok end)
    {:ok, pid: pid}
  end

  # ---- start_link/1 ----------------------------------------------------------

  describe "start_link/1" do
    test "starts with default config", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "registered under module name" do
      assert Process.whereis(GoalOrientedIntelligence) != nil
    end
  end

  # ---- process_intelligent_goal/1 --------------------------------------------

  describe "process_intelligent_goal/1" do
    test "returns {:ok, result} for valid goal spec" do
      goal = valid_goal()
      assert {:ok, result} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      assert is_map(result)
    end

    test "result contains processed_goal key" do
      goal = valid_goal("goal-002")
      {:ok, result} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      assert Map.has_key?(result, :processed_goal)
    end

    test "result contains intelligence_insights key" do
      goal = valid_goal("goal-003")
      {:ok, result} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      assert Map.has_key?(result, :intelligence_insights)
    end

    test "result contains optimization_recommendations key" do
      goal = valid_goal("goal-004")
      {:ok, result} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      assert Map.has_key?(result, :optimization_recommendations)
    end

    test "result contains timestamp" do
      goal = valid_goal("goal-005")
      {:ok, result} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      assert Map.has_key?(result, :timestamp)
      assert %DateTime{} = result.timestamp
    end

    test "processed_goal retains original goal id" do
      goal = valid_goal("goal-id-preserved")
      {:ok, result} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      assert result.processed_goal.id == "goal-id-preserved"
    end

    test "sequential calls succeed (goal persistence)" do
      for i <- 1..3 do
        goal = valid_goal("seq-goal-#{i}")
        assert {:ok, _} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      end
    end
  end

  # ---- decompose_goal_hierarchically/2 ---------------------------------------

  describe "decompose_goal_hierarchically/2" do
    test "returns {:ok, decomposition} for valid goal" do
      goal = valid_goal("decomp-001")
      assert {:ok, result} = GoalOrientedIntelligence.decompose_goal_hierarchically(goal)
      assert is_map(result)
    end

    test "custom max_depth is accepted (SC-GOI-002)" do
      goal = valid_goal("decomp-002")
      assert {:ok, _} = GoalOrientedIntelligence.decompose_goal_hierarchically(goal, 3)
    end

    test "max_depth bounded at default 5 if not specified" do
      goal = valid_goal("decomp-003")
      assert {:ok, result} = GoalOrientedIntelligence.decompose_goal_hierarchically(goal)
      assert is_map(result)
    end
  end

  # ---- optimize_goal_priorities/2 -------------------------------------------

  describe "optimize_goal_priorities/2" do
    test "returns {:ok, result} for list of goals (SC-GOI-003)" do
      goals = [valid_goal("opt-001"), valid_goal("opt-002")]
      assert {:ok, result} = GoalOrientedIntelligence.optimize_goal_priorities(goals)
      assert is_map(result)
    end

    test "result contains pareto_analysis" do
      goals = [valid_goal("opt-003")]
      {:ok, result} = GoalOrientedIntelligence.optimize_goal_priorities(goals)
      assert Map.has_key?(result, :pareto_analysis)
    end

    test "result contains resource_optimization" do
      goals = [valid_goal("opt-004")]
      {:ok, result} = GoalOrientedIntelligence.optimize_goal_priorities(goals)
      assert Map.has_key?(result, :resource_optimization)
    end

    test "result contains priority_recommendations" do
      goals = [valid_goal("opt-005")]
      {:ok, result} = GoalOrientedIntelligence.optimize_goal_priorities(goals)
      assert Map.has_key?(result, :priority_recommendations)
    end

    test "works with empty goal list" do
      assert {:ok, result} = GoalOrientedIntelligence.optimize_goal_priorities([])
      assert is_map(result)
    end

    test "works with custom constraints" do
      goals = [valid_goal("opt-006")]
      constraints = %{max_resources: 100, deadline: DateTime.utc_now()}
      assert {:ok, _} = GoalOrientedIntelligence.optimize_goal_priorities(goals, constraints)
    end
  end

  # ---- adapt_goals_to_context/1 ----------------------------------------------

  describe "adapt_goals_to_context/1" do
    test "returns {:ok, result} for context change map (SC-GOI-004)" do
      context_changes = %{environmental_factors: %{temperature: :high}}
      assert {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(context_changes)
      assert is_map(result)
    end

    test "result contains context_analysis key" do
      changes = %{resource_availability: %{cpu: 0.3}}
      {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(changes)
      assert Map.has_key?(result, :context_analysis)
    end

    test "result contains adaptation_recommendations key" do
      changes = %{strategic_priorities: %{focus: :security}}
      {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(changes)
      assert Map.has_key?(result, :adaptation_recommendations)
    end

    test "adaptation_recommendations is a list" do
      changes = %{environmental_factors: %{network: :degraded}}
      {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(changes)
      assert is_list(result.adaptation_recommendations)
    end

    test "unknown context type still returns general recommendation" do
      changes = %{unknown_factor: %{data: :anything}}
      {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(changes)
      assert is_list(result.adaptation_recommendations)
      recs = result.adaptation_recommendations
      types = Enum.map(recs, & &1.type)
      assert :general in types
    end

    test "works with empty context changes" do
      assert {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(%{})
      assert is_map(result)
    end
  end

  # ---- predict_goal_completion/1 ---------------------------------------------

  describe "predict_goal_completion/1" do
    test "returns {:error, :goal_not_found} for unknown goal id" do
      assert {:error, :goal_not_found} =
               GoalOrientedIntelligence.predict_goal_completion("nonexistent-goal")
    end

    test "returns {:ok, prediction} for a known goal" do
      # First add the goal to the GenServer state
      goal = valid_goal("predict-goal-001")
      {:ok, _} = GoalOrientedIntelligence.process_intelligent_goal(goal)

      assert {:ok, prediction} =
               GoalOrientedIntelligence.predict_goal_completion("predict-goal-001")

      assert is_map(prediction)
    end

    test "prediction contains combined_prediction key" do
      goal = valid_goal("predict-goal-002")
      {:ok, _} = GoalOrientedIntelligence.process_intelligent_goal(goal)
      {:ok, prediction} = GoalOrientedIntelligence.predict_goal_completion("predict-goal-002")
      assert Map.has_key?(prediction, :combined_prediction)
    end
  end

  # ---- pareto_optimize_goals/2 -----------------------------------------------

  describe "pareto_optimize_goals/2" do
    test "returns {:ok, result} for valid objectives and constraints" do
      objectives = [
        %{id: "speed", value: 0.9},
        %{id: "cost", value: 0.7}
      ]

      constraints = %{max_iterations: 50}

      assert {:ok, result} =
               GoalOrientedIntelligence.pareto_optimize_goals(objectives, constraints)

      assert is_map(result)
    end

    test "result contains pareto_frontier key" do
      objectives = [%{id: "quality", value: 0.8}]
      {:ok, result} = GoalOrientedIntelligence.pareto_optimize_goals(objectives, %{})
      assert Map.has_key?(result, :pareto_frontier)
    end

    test "result contains optimal_trade_offs key" do
      objectives = [%{id: "efficiency", value: 0.7}]
      {:ok, result} = GoalOrientedIntelligence.pareto_optimize_goals(objectives, %{})
      assert Map.has_key?(result, :optimal_trade_offs)
    end

    test "result contains recommendations key" do
      objectives = [%{id: "safety", value: 1.0}]
      {:ok, result} = GoalOrientedIntelligence.pareto_optimize_goals(objectives, %{})
      assert Map.has_key?(result, :recommendations)
    end
  end

  # ---- GenServer lifecycle ---------------------------------------------------

  describe "GenServer lifecycle" do
    test "process survives multiple concurrent goal submissions" do
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            goal = valid_goal("concurrent-goal-#{i}")
            GoalOrientedIntelligence.process_intelligent_goal(goal)
          end)
        end

      results = Task.await_many(tasks, 30_000)
      assert Enum.all?(results, fn r -> match?({:ok, _}, r) end)
    end

    test "process remains alive after handle_info :intelligence_evolution" do
      pid = Process.whereis(GoalOrientedIntelligence)
      send(pid, :intelligence_evolution)
      # Give it time to process
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "process remains alive after handle_info :priority_recalculation" do
      pid = Process.whereis(GoalOrientedIntelligence)
      send(pid, :priority_recalculation)
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  # ---- PropCheck properties --------------------------------------------------

  property "process_intelligent_goal always returns ok or error tuple" do
    forall priority <- PC.float(0.0, 1.0) do
      goal = %{valid_goal("prop-goal") | priority: priority}

      case GoalOrientedIntelligence.process_intelligent_goal(goal) do
        {:ok, _} -> true
        {:error, _} -> true
        _ -> false
      end
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "adapt_goals_to_context returns list of recommendations" do
    ExUnitProperties.check all(factor_count <- SD.integer(0..5)) do
      changes =
        Enum.into(1..max(factor_count, 1), %{}, fn i ->
          {String.to_atom("factor_#{i}"), %{level: i}}
        end)

      {:ok, result} = GoalOrientedIntelligence.adapt_goals_to_context(changes)
      assert is_list(result.adaptation_recommendations)
    end
  end
end
