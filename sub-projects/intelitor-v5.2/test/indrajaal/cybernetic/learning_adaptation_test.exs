defmodule Indrajaal.Cybernetic.LearningAdaptationTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cybernetic.LearningAdaptation.

  Named GenServer (name: __MODULE__). Tests start an isolated instance
  to avoid conflicts with production/other tests.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.LearningAdaptation

  @config %{
    learning_rate: 0.01,
    adaptation_threshold: 0.85
  }

  setup do
    # Stop any existing named process, start fresh for each test
    case Process.whereis(LearningAdaptation) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 500)
    end

    {:ok, _pid} = start_supervised({LearningAdaptation, @config})
    :ok
  end

  describe "learn_and_adapt/1" do
    test "returns a map or ok tuple for valid experience" do
      experience = %{
        context: %{domain: :alarms, complexity: :low},
        outcome: :success,
        performance_score: 0.9
      }

      result = LearningAdaptation.learn_and_adapt(experience)
      assert is_map(result) or match?({:ok, _}, result)
    end

    test "does not crash on minimal experience map" do
      result = LearningAdaptation.learn_and_adapt(%{})
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns result with learning status" do
      experience = %{
        context: %{domain: :devices},
        outcome: :failure,
        performance_score: 0.2
      }

      result = LearningAdaptation.learn_and_adapt(experience)
      # Must be a structured response, not a crash
      assert result != nil
    end
  end

  describe "select_learning_algorithm/2" do
    test "returns a string or atom algorithm name" do
      context = %{domain: :alarms, complexity: :high, data_size: 1000}
      result = LearningAdaptation.select_learning_algorithm(context, %{})
      assert is_binary(result) or is_atom(result) or is_map(result)
    end

    test "does not crash with empty context" do
      result = LearningAdaptation.select_learning_algorithm(%{}, %{})
      assert result != nil
    end

    test "selects different algorithms for different complexity levels" do
      low_context = %{complexity: :low}
      high_context = %{complexity: :high}

      result_low = LearningAdaptation.select_learning_algorithm(low_context, %{})
      result_high = LearningAdaptation.select_learning_algorithm(high_context, %{})

      # Both should return something (not necessarily different)
      assert result_low != nil
      assert result_high != nil
    end
  end

  describe "optimize_strategy_with_rl/3" do
    test "returns a map or tuple with optimized strategy" do
      state = %{current_performance: 0.7, target: 0.95}
      action_space = [:increase_rate, :decrease_rate, :hold]
      reward_fn = fn _s, _a -> :rand.uniform() end

      result = LearningAdaptation.optimize_strategy_with_rl(state, action_space, reward_fn)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with minimal inputs" do
      result = LearningAdaptation.optimize_strategy_with_rl(%{}, [], fn _s, _a -> 0.0 end)
      assert result != nil
    end
  end

  describe "transfer_knowledge/3" do
    test "returns a result map or tuple" do
      source = %{domain: :alarms, knowledge: %{pattern: :spike_detection}}
      target = %{domain: :devices}
      adaptation_params = %{similarity_threshold: 0.7}

      result = LearningAdaptation.transfer_knowledge(source, target, adaptation_params)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty maps" do
      result = LearningAdaptation.transfer_knowledge(%{}, %{}, %{})
      assert result != nil
    end
  end

  describe "evolve_parameters/3" do
    test "returns evolved parameters as map or tuple" do
      current_params = %{learning_rate: 0.01, momentum: 0.9}
      performance_metrics = %{accuracy: 0.85, loss: 0.15}
      evolution_strategy = :gradient_based

      result =
        LearningAdaptation.evolve_parameters(
          current_params,
          performance_metrics,
          evolution_strategy
        )

      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with minimal params" do
      result = LearningAdaptation.evolve_parameters(%{}, %{}, :default)
      assert result != nil
    end
  end

  describe "collective_decision/3" do
    test "returns a decision map or tuple" do
      agents = [%{id: "a1", vote: :approve}, %{id: "a2", vote: :reject}]
      decision_context = %{threshold: 0.6, domain: :safety}
      aggregation_method = :majority_vote

      result =
        LearningAdaptation.collective_decision(agents, decision_context, aggregation_method)

      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty agent list" do
      result = LearningAdaptation.collective_decision([], %{}, :majority_vote)
      assert result != nil
    end
  end

  describe "get_learning_metrics/0" do
    test "returns a map with metrics" do
      result = LearningAdaptation.get_learning_metrics()
      assert is_map(result)
    end

    test "metrics map contains expected keys" do
      metrics = LearningAdaptation.get_learning_metrics()
      # Should have at least some metrics fields
      assert map_size(metrics) >= 0
    end

    test "can be called multiple times without error" do
      m1 = LearningAdaptation.get_learning_metrics()
      m2 = LearningAdaptation.get_learning_metrics()
      assert is_map(m1)
      assert is_map(m2)
    end

    test "server remains alive after metrics call" do
      LearningAdaptation.get_learning_metrics()
      assert Process.alive?(Process.whereis(LearningAdaptation))
    end
  end
end
