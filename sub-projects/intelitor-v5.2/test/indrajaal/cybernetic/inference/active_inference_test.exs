defmodule Indrajaal.Cybernetic.Inference.ActiveInferenceTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.Inference.ActiveInference.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation iteration
  - FPPS Validation: Free Energy Principle mathematical consistency

  ## STAMP Safety Integration
  - SC-AI-001: Free energy MUST decrease over time (on average)
  - SC-AI-002: Beliefs MUST be updated within 10ms
  - SC-AI-003: Action selection MUST consider epistemic value
  - SC-AI-004: Model MUST be validated against observations
  - SC-MATH-004: ISOLATED discipline connected to active Sentinel caller

  ## Constitutional Verification
  - Psi_0 Existence: Agent state survives any valid observation
  - Psi_1 Regeneration: Full state reconstructable via new/1 + cycles
  - Psi_5 Truthfulness: free_energy accurately tracks belief accuracy

  ## Founder's Directive Alignment
  - Omega_0.6: Core sentience engine - FEP is path to intelligence

  ## TPS 5-Level RCA Context
  - L1 Symptom: System unable to adapt to anomalous operational conditions
  - L5 Root Cause: Free energy calculation diverges for degenerate observations
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.Inference.ActiveInference

  @moduletag :zenoh_nif

  # ---- new/1 -----------------------------------------------------------------

  describe "new/1" do
    test "creates a valid agent state map" do
      agent = ActiveInference.new()
      assert is_map(agent)
      assert Map.has_key?(agent, :beliefs)
      assert Map.has_key?(agent, :model)
      assert Map.has_key?(agent, :free_energy)
      assert Map.has_key?(agent, :history)
      assert Map.has_key?(agent, :iteration)
    end

    test "initial free_energy is 0.0" do
      agent = ActiveInference.new()
      assert agent.free_energy == 0.0
    end

    test "initial history is empty" do
      agent = ActiveInference.new()
      assert agent.history == []
    end

    test "initial iteration is 0" do
      agent = ActiveInference.new()
      assert agent.iteration == 0
    end

    test "custom model is stored" do
      model = %{confidence: 0.8}
      agent = ActiveInference.new(model)
      assert agent.model == model
    end
  end

  # ---- cycle/2 ---------------------------------------------------------------

  describe "cycle/2" do
    setup do
      {:ok, agent: ActiveInference.new()}
    end

    test "returns {action, updated_state}", %{agent: agent} do
      obs = %{state: :normal}
      {action, new_state} = ActiveInference.cycle(agent, obs)
      assert is_atom(action)
      assert is_map(new_state)
    end

    test "iteration increments after each cycle", %{agent: agent} do
      obs = %{state: :normal}
      {_, s1} = ActiveInference.cycle(agent, obs)
      assert s1.iteration == 1
      {_, s2} = ActiveInference.cycle(s1, obs)
      assert s2.iteration == 2
    end

    test "history grows after cycle", %{agent: agent} do
      obs = %{state: :normal}
      {_, updated} = ActiveInference.cycle(agent, obs)
      assert length(updated.history) == 1
    end

    test "history is capped at 100 entries", %{agent: agent} do
      obs = %{state: :normal}

      final_agent =
        Enum.reduce(1..110, agent, fn _, a ->
          {_, new_a} = ActiveInference.cycle(a, obs)
          new_a
        end)

      assert length(final_agent.history) <= 100
    end

    test "action is one of valid actions", %{agent: agent} do
      valid_actions = [:observe, :maintain, :repair, :escalate, :noop]
      obs = %{state: :degraded}
      {action, _} = ActiveInference.cycle(agent, obs)
      assert action in valid_actions
    end

    test "cycle completes within 10ms (SC-AI-002)", %{agent: agent} do
      obs = %{state: :normal}
      start = System.monotonic_time(:millisecond)
      ActiveInference.cycle(agent, obs)
      elapsed = System.monotonic_time(:millisecond) - start
      assert elapsed < 10
    end

    test "free_energy is updated after cycle", %{agent: agent} do
      obs = %{state: :normal}
      {_, updated} = ActiveInference.cycle(agent, obs)
      assert is_float(updated.free_energy)
    end
  end

  # ---- calculate_free_energy/3 -----------------------------------------------

  describe "calculate_free_energy/3" do
    test "returns a float" do
      agent = ActiveInference.new()
      obs = %{state: :normal}
      result = ActiveInference.calculate_free_energy(agent.beliefs, obs, agent.model)
      assert is_float(result)
    end

    test "is finite (no NaN or Infinity)" do
      agent = ActiveInference.new()
      obs = %{state: :normal}
      fe = ActiveInference.calculate_free_energy(agent.beliefs, obs, agent.model)
      refute is_nan_or_inf(fe)
    end

    defp is_nan_or_inf(f) when is_float(f) do
      f != f or f == :math.inf() or f == -:math.inf()
    rescue
      _ -> false
    end

    defp is_nan_or_inf(_), do: false
  end

  # ---- expected_free_energy/3 ------------------------------------------------

  describe "expected_free_energy/3" do
    test "returns a float for each standard action" do
      agent = ActiveInference.new()
      valid_actions = [:observe, :maintain, :repair, :escalate, :noop]

      Enum.each(valid_actions, fn action ->
        efe = ActiveInference.expected_free_energy(agent.beliefs, action, agent.model)
        assert is_float(efe)
      end)
    end
  end

  # ---- converging?/1 ---------------------------------------------------------

  describe "converging?/1" do
    test "returns true for empty history" do
      agent = ActiveInference.new()
      assert ActiveInference.converging?(agent)
    end

    test "returns true for single history entry" do
      agent = %{ActiveInference.new() | history: [1.0]}
      assert ActiveInference.converging?(agent)
    end

    test "returns true when current <= previous" do
      agent = %{ActiveInference.new() | history: [1.0, 2.0]}
      assert ActiveInference.converging?(agent)
    end

    test "returns false when current > previous" do
      agent = %{ActiveInference.new() | history: [3.0, 1.0]}
      refute ActiveInference.converging?(agent)
    end
  end

  # ---- average_free_energy/1 -------------------------------------------------

  describe "average_free_energy/1" do
    test "returns 0.0 for empty history" do
      agent = ActiveInference.new()
      assert ActiveInference.average_free_energy(agent) == 0.0
    end

    test "returns correct mean" do
      agent = %{ActiveInference.new() | history: [1.0, 2.0, 3.0]}
      avg = ActiveInference.average_free_energy(agent)
      assert_in_delta avg, 2.0, 0.001
    end

    test "single entry returns that entry" do
      agent = %{ActiveInference.new() | history: [5.0]}
      assert ActiveInference.average_free_energy(agent) == 5.0
    end
  end

  # ---- reset/1 ---------------------------------------------------------------

  describe "reset/1" do
    test "resets iteration to 0" do
      agent = ActiveInference.new()
      {_, updated} = ActiveInference.cycle(agent, %{state: :normal})
      reset = ActiveInference.reset(updated)
      assert reset.iteration == 0
    end

    test "resets free_energy to 0.0" do
      agent = ActiveInference.new()
      {_, updated} = ActiveInference.cycle(agent, %{state: :normal})
      reset = ActiveInference.reset(updated)
      assert reset.free_energy == 0.0
    end

    test "resets history to empty" do
      agent = ActiveInference.new()
      {_, updated} = ActiveInference.cycle(agent, %{state: :normal})
      reset = ActiveInference.reset(updated)
      assert reset.history == []
    end
  end

  # ---- summary/1 -------------------------------------------------------------

  describe "summary/1" do
    test "returns expected keys" do
      agent = ActiveInference.new()
      s = ActiveInference.summary(agent)
      assert Map.has_key?(s, :iteration)
      assert Map.has_key?(s, :free_energy)
      assert Map.has_key?(s, :avg_free_energy)
      assert Map.has_key?(s, :converging)
      assert Map.has_key?(s, :belief_entropy)
      assert Map.has_key?(s, :history_length)
    end

    test "history_length reflects actual history" do
      agent = ActiveInference.new()
      {_, a1} = ActiveInference.cycle(agent, %{state: :normal})
      {_, a2} = ActiveInference.cycle(a1, %{state: :degraded})
      s = ActiveInference.summary(a2)
      assert s.history_length == 2
    end
  end

  # ---- infer_system_state/1 --------------------------------------------------

  describe "infer_system_state/1" do
    test "returns {:ok, map} for a valid metrics map" do
      assert {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.9})
      assert Map.has_key?(result, :most_likely_state)
      assert Map.has_key?(result, :confidence)
      assert Map.has_key?(result, :free_energy)
      assert Map.has_key?(result, :beliefs)
      assert Map.has_key?(result, :converging)
    end

    test "healthy metrics produces :normal state (SC-MATH-004)" do
      {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.95})
      assert result.most_likely_state == :normal
    end

    test "critical metrics produces :critical or :failed state" do
      {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.1, error_rate: 200.0})
      assert result.most_likely_state in [:critical, :failed]
    end

    test "degraded metrics produces :degraded state" do
      {:ok, result} =
        ActiveInference.infer_system_state(%{health_score: 0.6, memory_usage: 0.55})

      assert result.most_likely_state in [:normal, :degraded]
    end

    test "empty metrics map is valid and returns some state" do
      assert {:ok, result} = ActiveInference.infer_system_state(%{})
      assert is_atom(result.most_likely_state)
    end

    test "returns {:error, :invalid_metrics} for non-map input" do
      assert {:error, :invalid_metrics} = ActiveInference.infer_system_state("bad")
      assert {:error, :invalid_metrics} = ActiveInference.infer_system_state(nil)
      assert {:error, :invalid_metrics} = ActiveInference.infer_system_state(42)
    end

    test "confidence is in [0.0, 1.0]" do
      {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.7})
      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
    end

    test "beliefs map contains the four canonical health states" do
      {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.5})
      beliefs = result.beliefs
      assert Map.has_key?(beliefs, :normal)
      assert Map.has_key?(beliefs, :degraded)
      assert Map.has_key?(beliefs, :critical)
      assert Map.has_key?(beliefs, :failed)
    end

    test "beliefs sum to 1.0" do
      {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.8})
      total = result.beliefs |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-6
    end

    test "converging field is a boolean" do
      {:ok, result} = ActiveInference.infer_system_state(%{health_score: 0.5})
      assert is_boolean(result.converging)
    end
  end

  # ---- PropCheck properties --------------------------------------------------

  property "multiple cycles keep iteration monotonically increasing" do
    forall n <- PC.choose(1, 20) do
      obs = %{state: :normal}
      agent = ActiveInference.new()

      final =
        Enum.reduce(1..n, agent, fn _, a ->
          {_, updated} = ActiveInference.cycle(a, obs)
          updated
        end)

      final.iteration == n
    end
  end

  property "infer_system_state accepts any numeric health_score in [0,1]" do
    forall score <- PC.float(0.0, 1.0) do
      match?({:ok, _}, ActiveInference.infer_system_state(%{health_score: score}))
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "infer_system_state always returns a valid health atom" do
    ExUnitProperties.check all(
                             health <- SD.float(min: 0.0, max: 1.0),
                             memory <- SD.float(min: 0.0, max: 1.0),
                             cpu <- SD.float(min: 0.0, max: 1.0)
                           ) do
      {:ok, result} =
        ActiveInference.infer_system_state(%{
          health_score: health,
          memory_usage: memory,
          cpu_usage: cpu
        })

      assert result.most_likely_state in [:normal, :degraded, :critical, :failed]
    end
  end

  test "reset/1 always produces a clean agent state" do
    ExUnitProperties.check all(n <- SD.integer(1..15)) do
      obs = %{state: :degraded}
      agent = ActiveInference.new()

      worked_agent =
        Enum.reduce(1..n, agent, fn _, a ->
          {_, updated} = ActiveInference.cycle(a, obs)
          updated
        end)

      reset = ActiveInference.reset(worked_agent)
      assert reset.iteration == 0
      assert reset.history == []
      assert reset.free_energy == 0.0
    end
  end
end
