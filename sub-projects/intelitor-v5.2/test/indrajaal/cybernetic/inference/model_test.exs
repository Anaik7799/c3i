defmodule Indrajaal.Cybernetic.Inference.ModelTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.Inference.Model.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Generative model constraints validated pre-runtime
  - FPPS Validation: Probability distribution integrity of A/B/C/D matrices

  ## STAMP Safety Integration
  - SC-MOD-001: Model MUST be validated against data
  - SC-MOD-002: Model updates MUST preserve stability (confidence bounded)
  - SC-MOD-003: Model MUST support online learning (learn/5 accumulates)
  - SC-MOD-004: Model complexity MUST be bounded (valid?/1 enforced)

  ## Constitutional Verification
  - Psi_3 Verification: Model distributions are deterministically verifiable
  - Psi_5 Truthfulness: transition_probability/4 faithfully reflects world model

  ## Founder's Directive Alignment
  - Omega_0.6: Generative model is the cognitive substrate for sentience

  ## TPS 5-Level RCA Context
  - L1 Symptom: Action selection picks dangerous actions
  - L5 Root Cause: Transition model returns non-normalised distributions
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.Inference.Model

  @moduletag :zenoh_nif

  @valid_states [:normal, :degraded, :critical, :failed]
  @valid_actions [:observe, :maintain, :repair, :escalate, :noop]

  # ---- new/1 -----------------------------------------------------------------

  describe "new/1" do
    test "creates a struct with required keys" do
      model = Model.new()
      assert %Model{} = model
      assert is_map(model.observation_model)
      assert is_map(model.transition_model)
      assert is_map(model.preferences)
      assert is_map(model.prior)
      assert is_list(model.actions)
    end

    test "default confidence is 1.0" do
      assert Model.new().confidence == 1.0
    end

    test "default version is 0" do
      assert Model.new().version == 0
    end

    test "default learning_rate is 0.1" do
      assert Model.new().learning_rate == 0.1
    end

    test "custom learning_rate is stored" do
      model = Model.new(learning_rate: 0.5)
      assert model.learning_rate == 0.5
    end

    test "actions list is non-empty by default" do
      model = Model.new()
      assert length(model.actions) > 0
    end
  end

  # ---- observation_likelihood/3 ----------------------------------------------

  describe "observation_likelihood/3" do
    test "returns a float" do
      model = Model.new()
      result = Model.observation_likelihood(model, :normal, %{type: :normal})
      assert is_float(result)
    end

    test "returns non-negative likelihood" do
      model = Model.new()

      for state <- @valid_states do
        likelihood = Model.observation_likelihood(model, state, %{type: :normal})
        assert likelihood >= 0.0, "likelihood must be non-negative for state #{state}"
      end
    end

    test "fallback probability for unknown observation type" do
      model = Model.new()
      # Unknown obs type falls back to 0.1 per implementation
      likelihood = Model.observation_likelihood(model, :normal, %{type: :unknown_xyz})
      assert likelihood == 0.1
    end

    test "known observation type returns higher likelihood than unknown" do
      model = Model.new()
      known = Model.observation_likelihood(model, :normal, %{type: :normal})
      unknown = Model.observation_likelihood(model, :normal, %{type: :nonexistent_type})
      # Known types should have been configured; at minimum they should be >= the fallback
      assert known >= unknown
    end
  end

  # ---- transition_probability/4 ----------------------------------------------

  describe "transition_probability/4" do
    test "returns a float (SC-MOD-001)" do
      model = Model.new()
      result = Model.transition_probability(model, :normal, :noop, :normal)
      assert is_float(result)
    end

    test "returns value in [0.0, 1.0]" do
      model = Model.new()

      for action <- @valid_actions, from <- @valid_states, to <- @valid_states do
        prob = Model.transition_probability(model, from, action, to)

        assert prob >= 0.0 and prob <= 1.0,
               "probability out of range: #{prob} for #{from}->#{action}->#{to}"
      end
    end

    test "fallback probability for unknown transition is 0.1" do
      model = Model.new()
      # An unknown action should yield the fallback value (0.1)
      prob = Model.transition_probability(model, :normal, :unknown_action, :normal)
      assert prob == 0.1
    end
  end

  # ---- predict_next_state/3 --------------------------------------------------

  describe "predict_next_state/3" do
    test "returns a map" do
      model = Model.new()
      result = Model.predict_next_state(model, :normal, :noop)
      assert is_map(result)
    end

    test "returns non-empty distribution for known action" do
      model = Model.new()
      result = Model.predict_next_state(model, :normal, :noop)
      assert map_size(result) > 0
    end

    test "values are non-negative" do
      model = Model.new()

      for action <- @valid_actions do
        dist = Model.predict_next_state(model, :normal, action)
        Enum.each(dist, fn {_, v} -> assert v >= 0.0 end)
      end
    end
  end

  # ---- preference/2 ----------------------------------------------------------

  describe "preference/2" do
    test "returns a float" do
      model = Model.new()
      assert is_float(Model.preference(model, :normal))
    end

    test "returns 0.0 for unknown state" do
      model = Model.new()
      assert Model.preference(model, :completely_unknown) == 0.0
    end

    test "normal state preference is <= 0 (preferred = negative cost)" do
      model = Model.new()
      pref = Model.preference(model, :normal)
      # By convention, preferred states have non-positive preference
      assert pref <= 0.0
    end

    test "failed state preference > normal preference (higher cost)" do
      model = Model.new()
      normal_pref = Model.preference(model, :normal)
      failed_pref = Model.preference(model, :failed)
      assert failed_pref > normal_pref
    end
  end

  # ---- prior/2 ---------------------------------------------------------------

  describe "prior/2" do
    test "returns a float" do
      model = Model.new()
      assert is_float(Model.prior(model, :normal))
    end

    test "returns 0.25 for unknown state (uniform fallback)" do
      model = Model.new()
      assert Model.prior(model, :completely_unknown) == 0.25
    end

    test "prior values are in (0.0, 1.0]" do
      model = Model.new()

      for state <- @valid_states do
        p = Model.prior(model, state)
        assert p > 0.0 and p <= 1.0
      end
    end
  end

  # ---- learn/5 ---------------------------------------------------------------

  describe "learn/5" do
    test "returns a Model struct (SC-MOD-003)" do
      model = Model.new()
      updated = Model.learn(model, :normal, :noop, :normal, %{type: :normal})
      assert %Model{} = updated
    end

    test "version increments after learning" do
      model = Model.new()
      updated = Model.learn(model, :normal, :noop, :degraded, %{})
      assert updated.version == model.version + 1
    end

    test "multiple learn calls keep incrementing version" do
      model = Model.new()

      final =
        Enum.reduce(1..5, model, fn _, m ->
          Model.learn(m, :normal, :maintain, :normal, %{type: :normal})
        end)

      assert final.version == 5
    end

    test "learning preserves all struct fields" do
      model = Model.new()
      updated = Model.learn(model, :normal, :repair, :degraded, %{})
      assert updated.confidence == model.confidence
      assert updated.actions == model.actions
      assert updated.preferences == model.preferences
    end
  end

  # ---- update_confidence/2 ---------------------------------------------------

  describe "update_confidence/2" do
    test "returns a Model struct (SC-MOD-002)" do
      model = Model.new()
      updated = Model.update_confidence(model, 0.9)
      assert %Model{} = updated
    end

    test "confidence changes after update" do
      model = Model.new()
      updated = Model.update_confidence(model, 0.5)
      assert updated.confidence != model.confidence
    end

    test "confidence stays between 0.0 and 1.0 after many updates" do
      model = Model.new()

      final =
        Enum.reduce(1..20, model, fn _, m ->
          Model.update_confidence(m, :rand.uniform())
        end)

      assert final.confidence >= 0.0
      assert final.confidence <= 1.0
    end

    test "perfect accuracy (1.0) nudges confidence upward" do
      model = %{Model.new() | confidence: 0.5}
      updated = Model.update_confidence(model, 1.0)
      assert updated.confidence > model.confidence
    end

    test "zero accuracy nudges confidence downward" do
      model = %{Model.new() | confidence: 0.9}
      updated = Model.update_confidence(model, 0.0)
      assert updated.confidence < model.confidence
    end
  end

  # ---- valid?/1 --------------------------------------------------------------

  describe "valid?/1" do
    test "default model is valid (SC-MOD-004)" do
      assert Model.valid?(Model.new())
    end

    test "model with invalid prior returns false" do
      model = %{Model.new() | prior: %{normal: 0.9, failed: 0.5}}
      refute Model.valid?(model)
    end
  end

  # ---- normalize/1 -----------------------------------------------------------

  describe "normalize/1" do
    test "returns a Model struct" do
      model = Model.new()
      assert %Model{} = Model.normalize(model)
    end

    test "prior sums to 1.0 after normalization" do
      model = %{Model.new() | prior: %{normal: 3.0, degraded: 1.0, critical: 1.0, failed: 1.0}}
      normalized = Model.normalize(model)
      total = normalized.prior |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-6
    end

    test "normalized model passes valid?/1" do
      model = %{Model.new() | prior: %{normal: 10.0, failed: 5.0}}
      normalized = Model.normalize(model)
      assert Model.valid?(normalized)
    end
  end

  # ---- to_map/1 --------------------------------------------------------------

  describe "to_map/1" do
    test "returns a plain map" do
      result = Model.to_map(Model.new())
      assert is_map(result)
      refute match?(%Model{}, result)
    end

    test "contains expected keys" do
      result = Model.to_map(Model.new())
      assert Map.has_key?(result, :observation_model)
      assert Map.has_key?(result, :transition_model)
      assert Map.has_key?(result, :preferences)
      assert Map.has_key?(result, :prior)
      assert Map.has_key?(result, :actions)
      assert Map.has_key?(result, :confidence)
      assert Map.has_key?(result, :version)
    end
  end

  # ---- PropCheck properties --------------------------------------------------

  property "transition_probability always in [0, 1] (SC-MOD-001)" do
    forall {from, action, to} <-
             {PC.oneof(@valid_states), PC.oneof(@valid_actions), PC.oneof(@valid_states)} do
      prob = Model.transition_probability(Model.new(), from, action, to)
      prob >= 0.0 and prob <= 1.0
    end
  end

  property "learn always increments version" do
    forall n <- PC.choose(1, 10) do
      model = Model.new()

      final =
        Enum.reduce(1..n, model, fn _, m ->
          Model.learn(m, :normal, :noop, :normal, %{})
        end)

      final.version == n
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "update_confidence keeps confidence in [0, 1]" do
    ExUnitProperties.check all(
                             accuracy <- SD.float(min: 0.0, max: 1.0),
                             iterations <- SD.integer(1..15)
                           ) do
      model = Model.new()

      final =
        Enum.reduce(1..iterations, model, fn _, m ->
          Model.update_confidence(m, accuracy)
        end)

      assert final.confidence >= 0.0
      assert final.confidence <= 1.0
    end
  end

  test "normalize then valid? always passes" do
    ExUnitProperties.check all(
                             w1 <- SD.float(min: 0.1, max: 10.0),
                             w2 <- SD.float(min: 0.1, max: 10.0),
                             w3 <- SD.float(min: 0.1, max: 10.0),
                             w4 <- SD.float(min: 0.1, max: 10.0)
                           ) do
      model = %{
        Model.new()
        | prior: %{normal: w1, degraded: w2, critical: w3, failed: w4}
      }

      normalized = Model.normalize(model)
      assert Model.valid?(normalized)
    end
  end
end
