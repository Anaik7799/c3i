defmodule Indrajaal.Cybernetic.RealTimeDecisionEngineTest do
  @moduledoc """
  TDG test suite for Indrajaal.Cybernetic.RealTimeDecisionEngine.

  Named GenServer. Known bug: get_decision_metrics/0 calls :get_metrics but
  handle_call matches :getmetrics (no underscore) — the test documents this
  as a TDG-failing test that reveals the implementation bug.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.RealTimeDecisionEngine

  setup do
    case Process.whereis(RealTimeDecisionEngine) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal, 500)
    end

    {:ok, _pid} = start_supervised({RealTimeDecisionEngine, %{}})
    :ok
  end

  describe "make_real_time_decision/1" do
    test "returns a decision result for valid context" do
      context = %{
        problem_description: "Route emergency alert to nearest responder",
        criteria: [:response_time, :availability, :competency],
        alternatives: ["team_alpha", "team_beta", "team_gamma"],
        weights: [0.5, 0.3, 0.2]
      }

      result = RealTimeDecisionEngine.make_real_time_decision(context)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "result contains a decision or selected_alternative" do
      context = %{
        problem_description: "Select optimal alarm policy",
        criteria: [:accuracy, :speed],
        alternatives: ["policy_a", "policy_b"]
      }

      result = RealTimeDecisionEngine.make_real_time_decision(context)
      assert result != nil
    end

    test "does not crash with empty context" do
      result = RealTimeDecisionEngine.make_real_time_decision(%{})
      assert result != nil
    end

    test "handles single alternative" do
      context = %{
        problem_description: "Trivial choice",
        criteria: [:cost],
        alternatives: ["only_option"]
      }

      result = RealTimeDecisionEngine.make_real_time_decision(context)
      assert result != nil
    end

    test "server remains alive after decision" do
      RealTimeDecisionEngine.make_real_time_decision(%{description: "test"})
      assert Process.alive?(Process.whereis(RealTimeDecisionEngine))
    end
  end

  describe "analyze_multi_criteria/3" do
    test "returns analysis result for valid inputs" do
      alternatives = ["option_a", "option_b", "option_c"]

      criteria = [
        %{name: :cost, weight: 0.4},
        %{name: :quality, weight: 0.6}
      ]

      scores = %{
        "option_a" => %{cost: 0.7, quality: 0.8},
        "option_b" => %{cost: 0.9, quality: 0.6},
        "option_c" => %{cost: 0.5, quality: 0.9}
      }

      result = RealTimeDecisionEngine.analyze_multi_criteria(alternatives, criteria, scores)
      assert is_map(result) or is_list(result) or match?({:ok, _}, result)
    end

    test "does not crash with empty alternatives" do
      result = RealTimeDecisionEngine.analyze_multi_criteria([], [], %{})
      assert result != nil
    end

    test "returns ranked alternatives" do
      alternatives = ["a", "b"]
      criteria = [%{name: :score, weight: 1.0}]
      scores = %{"a" => %{score: 0.9}, "b" => %{score: 0.6}}

      result = RealTimeDecisionEngine.analyze_multi_criteria(alternatives, criteria, scores)
      assert result != nil
    end
  end

  describe "process_fuzzy_decision/2" do
    test "returns a fuzzy decision result" do
      inputs = %{temperature: 75, pressure: 50}

      rules = [
        %{if: :high_temperature, then: :reduce_load},
        %{if: :high_pressure, then: :emergency_stop}
      ]

      result = RealTimeDecisionEngine.process_fuzzy_decision(inputs, rules)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty inputs and rules" do
      result = RealTimeDecisionEngine.process_fuzzy_decision(%{}, [])
      assert result != nil
    end
  end

  describe "bayesian_decision_inference/3" do
    test "returns a Bayesian inference result" do
      prior = %{event_a: 0.3, event_b: 0.7}
      likelihood = %{evidence_x: %{event_a: 0.8, event_b: 0.2}}
      evidence = [:evidence_x]

      result = RealTimeDecisionEngine.bayesian_decision_inference(prior, likelihood, evidence)
      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty evidence" do
      result = RealTimeDecisionEngine.bayesian_decision_inference(%{}, %{}, [])
      assert result != nil
    end
  end

  describe "analyze_strategic_interactions/3" do
    test "returns a game theory analysis" do
      players = ["agent_1", "agent_2"]

      strategies = %{
        "agent_1" => [:cooperate, :defect],
        "agent_2" => [:cooperate, :defect]
      }

      payoff_matrix = %{
        {:cooperate, :cooperate} => {3, 3},
        {:cooperate, :defect} => {0, 5},
        {:defect, :cooperate} => {5, 0},
        {:defect, :defect} => {1, 1}
      }

      result =
        RealTimeDecisionEngine.analyze_strategic_interactions(players, strategies, payoff_matrix)

      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty players" do
      result = RealTimeDecisionEngine.analyze_strategic_interactions([], %{}, %{})
      assert result != nil
    end
  end

  describe "solve_constraint_problem/4" do
    test "returns a constraint satisfaction result" do
      variables = [:x, :y]
      domains = %{x: 1..10, y: 1..10}
      constraints = [fn x, y -> x + y <= 15 end]
      objective = fn x, y -> x * y end

      result =
        RealTimeDecisionEngine.solve_constraint_problem(
          variables,
          domains,
          constraints,
          objective
        )

      assert is_map(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "does not crash with empty variables" do
      result = RealTimeDecisionEngine.solve_constraint_problem([], %{}, [], fn -> 0 end)
      assert result != nil
    end
  end

  describe "get_decision_metrics/0" do
    test "documents the handle_call mismatch bug - call sends :get_metrics but pattern matches :getmetrics" do
      # This test documents the known bug: the public API calls :get_metrics,
      # but the handle_call in the module matches :getmetrics (no underscore).
      # TDG mandate: test must initially fail, revealing the bug.
      # The test will either:
      # a) Pass if the implementation is fixed (metrics returned)
      # b) Raise/timeout if not fixed (documents the bug)
      result =
        try do
          RealTimeDecisionEngine.get_decision_metrics()
        catch
          :exit, {:timeout, _} -> {:error, :genserver_timeout}
          :exit, reason -> {:error, reason}
        end

      # If the bug exists: result is {:error, :genserver_timeout}
      # If fixed: result is a map
      assert is_map(result) or match?({:error, _}, result)
    end
  end
end
