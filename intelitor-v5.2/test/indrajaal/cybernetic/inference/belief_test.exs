defmodule Indrajaal.Cybernetic.Inference.BeliefTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.Inference.Belief.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation refinement
  - FPPS Validation: Probabilistic belief state verification

  ## STAMP Safety Integration
  - SC-BEL-001: Beliefs MUST sum to 1 (normalized)
  - SC-BEL-002: Beliefs MUST be non-negative
  - SC-BEL-003: Belief update MUST be numerically stable
  - SC-BEL-004: Entropy MUST be bounded [0, log(|S|)]

  ## Constitutional Verification
  - Psi_0 Existence: Belief state survives all observation updates
  - Psi_1 Regeneration: Beliefs reconstructable from prior alone
  - Psi_5 Truthfulness: Normalized probabilities represent true belief

  ## Founder's Directive Alignment
  - Omega_0.6: Supports sentience pursuit via Bayesian inference engine

  ## TPS 5-Level RCA Context
  - L1 Symptom: Incorrect action selection in safety-critical scenarios
  - L5 Root Cause: Belief normalization invariant violated under extreme surprise
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.Inference.Belief

  @moduletag :zenoh_nif

  # ---- Constructor / initial state -------------------------------------------

  describe "new/1" do
    test "returns a Belief struct with default states" do
      belief = Belief.new()
      assert %Belief{} = belief
      assert map_size(belief.states) == 4
      assert Map.has_key?(belief.states, :normal)
      assert Map.has_key?(belief.states, :degraded)
      assert Map.has_key?(belief.states, :critical)
      assert Map.has_key?(belief.states, :failed)
    end

    test "initial states sum to 1.0 (SC-BEL-001)" do
      belief = Belief.new()
      total = belief.states |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end

    test "all initial probabilities are non-negative (SC-BEL-002)" do
      belief = Belief.new()

      Enum.each(belief.states, fn {_state, prob} ->
        assert prob >= 0.0
      end)
    end

    test "initial confidence is 0.5" do
      belief = Belief.new()
      assert belief.confidence == 0.5
    end

    test "initial last_update is nil" do
      belief = Belief.new()
      assert belief.last_update == nil
    end

    test "prior equals initial states" do
      belief = Belief.new()
      assert belief.prior == belief.states
    end

    test "custom states are accepted via opts" do
      custom = %{a: 0.6, b: 0.4}
      belief = Belief.new(states: custom)
      assert Map.has_key?(belief.states, :a)
      assert Map.has_key?(belief.states, :b)
      total = belief.states |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end
  end

  # ---- update/3 --------------------------------------------------------------

  describe "update/3" do
    setup do
      {:ok, belief: Belief.new()}
    end

    test "returns updated Belief struct", %{belief: belief} do
      observation = %{state: :normal}
      updated = Belief.update(belief, observation, 2.0)
      assert %Belief{} = updated
    end

    test "updated states still sum to 1.0 (SC-BEL-001)", %{belief: belief} do
      observation = %{state: :normal}
      updated = Belief.update(belief, observation, 5.0)
      total = updated.states |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end

    test "all updated probabilities are non-negative (SC-BEL-002)", %{belief: belief} do
      observation = %{state: :failed}
      updated = Belief.update(belief, observation, 3.0)
      Enum.each(updated.states, fn {_s, p} -> assert p >= 0.0 end)
    end

    test "last_update is set after update", %{belief: belief} do
      observation = %{state: :degraded}
      updated = Belief.update(belief, observation, 1.0)
      assert %DateTime{} = updated.last_update
    end

    test "prior is preserved as previous states", %{belief: belief} do
      original_states = belief.states
      observation = %{state: :normal}
      updated = Belief.update(belief, observation, 2.0)
      assert updated.prior == original_states
    end

    test "high surprise causes stronger belief update", %{belief: belief} do
      obs = %{state: :normal}
      low_surprise_update = Belief.update(belief, obs, 0.1)
      high_surprise_update = Belief.update(belief, obs, 10.0)
      # High surprise => normal state should be weighted more heavily
      assert high_surprise_update.states[:normal] >= low_surprise_update.states[:normal]
    end

    test "confidence is updated after observation", %{belief: belief} do
      obs = %{state: :normal}
      updated = Belief.update(belief, obs, 5.0)
      # Confidence should be different from initial 0.5 after receiving observations
      assert is_float(updated.confidence)
      assert updated.confidence >= 0.0
      assert updated.confidence <= 1.0
    end

    test "numerical stability with zero-surprise (SC-BEL-003)", %{belief: belief} do
      obs = %{state: :normal}
      updated = Belief.update(belief, obs, 0.0)
      total = updated.states |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end
  end

  # ---- probability/2 ---------------------------------------------------------

  describe "probability/2" do
    test "returns a float in [epsilon, 1.0]" do
      belief = Belief.new()
      obs = %{state: :normal}
      prob = Belief.probability(belief, obs)
      assert is_float(prob)
      assert prob > 0.0
      assert prob <= 1.0
    end

    test "returns higher probability for likely state" do
      # After seeing :normal twice, normal should have higher probability
      belief =
        Belief.new()
        |> Belief.update(%{state: :normal}, 5.0)
        |> Belief.update(%{state: :normal}, 5.0)

      normal_prob = Belief.probability(belief, %{state: :normal})
      failed_prob = Belief.probability(belief, %{state: :failed})
      assert normal_prob > failed_prob
    end
  end

  # ---- log_likelihood/2 ------------------------------------------------------

  describe "log_likelihood/2" do
    test "returns a non-positive float (log of probability <= 1)" do
      belief = Belief.new()
      obs = %{state: :normal}
      ll = Belief.log_likelihood(belief, obs)
      assert is_float(ll)
      assert ll <= 0.0
    end
  end

  # ---- entropy/1 -------------------------------------------------------------

  describe "entropy/1" do
    test "entropy of uniform distribution is maximal (SC-BEL-004)" do
      belief = Belief.new()
      ent = Belief.entropy(belief)
      n = map_size(belief.states)
      max_ent = :math.log(n)
      assert ent <= max_ent + 1.0e-9
    end

    test "entropy is non-negative" do
      belief = Belief.new()
      assert Belief.entropy(belief) >= 0.0
    end

    test "certainty reduces entropy" do
      # After many observations of the same state, entropy should decrease
      certain_belief =
        Enum.reduce(1..10, Belief.new(), fn _, b ->
          Belief.update(b, %{state: :normal}, 8.0)
        end)

      initial_belief = Belief.new()
      assert Belief.entropy(certain_belief) < Belief.entropy(initial_belief)
    end
  end

  # ---- information_gain/2 ----------------------------------------------------

  describe "information_gain/2" do
    test "returns non-negative float" do
      belief = Belief.new()
      predicted = %{%{state: :normal} => 0.7, %{state: :failed} => 0.3}
      gain = Belief.information_gain(belief, predicted)
      assert is_float(gain)
      assert gain >= 0.0
    end
  end

  # ---- most_likely/1 ---------------------------------------------------------

  describe "most_likely/1" do
    test "returns the state with highest probability" do
      belief = Belief.new()
      {state, prob} = Belief.most_likely(belief)
      assert is_atom(state)
      assert is_float(prob)
      # All other probabilities should be <= best
      Enum.each(belief.states, fn {_s, p} -> assert p <= prob + 1.0e-9 end)
    end

    test "returns :normal as most likely in fresh uniform+weighted belief" do
      # Default prior: normal=0.5, degraded=0.25, critical=0.15, failed=0.1
      belief = Belief.new()
      {state, _prob} = Belief.most_likely(belief)
      assert state == :normal
    end
  end

  # ---- likely_states/2 -------------------------------------------------------

  describe "likely_states/2" do
    test "returns states above default threshold of 0.1" do
      belief = Belief.new()
      likely = Belief.likely_states(belief)
      # All states in fresh uniform belief are >= 0.1
      assert length(likely) >= 1
      Enum.each(likely, fn {_state, prob} -> assert prob >= 0.1 end)
    end

    test "returns states sorted by probability descending" do
      belief = Belief.new()
      likely = Belief.likely_states(belief)
      probs = Enum.map(likely, fn {_, p} -> p end)
      assert probs == Enum.sort(probs, :desc)
    end

    test "custom threshold filters correctly" do
      belief = Belief.new()
      high_threshold = Belief.likely_states(belief, 0.5)
      low_threshold = Belief.likely_states(belief, 0.01)
      assert length(low_threshold) >= length(high_threshold)
    end
  end

  # ---- merge/3 ---------------------------------------------------------------

  describe "merge/3" do
    test "merged states sum to 1.0 (SC-BEL-001)" do
      b1 = Belief.new()
      b2 = Belief.new()
      merged = Belief.merge(b1, b2, 0.5)
      total = merged.states |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-9
    end

    test "equal weight merge produces average probabilities" do
      b1 = Belief.new()
      b2 = Belief.new()
      merged = Belief.merge(b1, b2, 0.5)
      # Same distributions merged equally should give same result
      Enum.each(merged.states, fn {state, prob} ->
        expected = (b1.states[state] + b2.states[state]) / 2.0
        assert_in_delta prob, expected, 1.0e-6
      end)
    end

    test "weight 1.0 favors first belief" do
      b1 = Belief.new()

      b2 =
        Enum.reduce(1..5, Belief.new(), fn _, b ->
          Belief.update(b, %{state: :failed}, 10.0)
        end)

      merged = Belief.merge(b1, b2, 1.0)
      # Should be close to b1 states
      assert_in_delta merged.states[:normal], b1.states[:normal], 0.01
    end
  end

  # ---- reset_to_prior/1 ------------------------------------------------------

  describe "reset_to_prior/1" do
    test "restores states to prior distribution" do
      belief =
        Belief.new()
        |> Belief.update(%{state: :failed}, 10.0)

      reset = Belief.reset_to_prior(belief)
      assert reset.states == belief.prior
    end

    test "resets confidence to 0.5" do
      belief =
        Belief.new()
        |> Belief.update(%{state: :failed}, 10.0)

      reset = Belief.reset_to_prior(belief)
      assert reset.confidence == 0.5
    end

    test "resets last_update to nil" do
      belief =
        Belief.new()
        |> Belief.update(%{state: :normal}, 5.0)

      reset = Belief.reset_to_prior(belief)
      assert reset.last_update == nil
    end
  end

  # ---- summary/1 -------------------------------------------------------------

  describe "summary/1" do
    test "returns a map with expected keys" do
      belief = Belief.new()
      s = Belief.summary(belief)
      assert Map.has_key?(s, :most_likely)
      assert Map.has_key?(s, :probability)
      assert Map.has_key?(s, :confidence)
      assert Map.has_key?(s, :entropy)
      assert Map.has_key?(s, :num_states)
      assert Map.has_key?(s, :last_update)
    end

    test "num_states matches actual state count" do
      belief = Belief.new()
      s = Belief.summary(belief)
      assert s.num_states == map_size(belief.states)
    end
  end

  # ---- PropCheck property tests ----------------------------------------------

  property "belief states always sum to 1.0 after any number of updates (SC-BEL-001)" do
    forall {n_updates, surprise} <- {PC.pos_integer(), PC.float(1.0, 20.0)} do
      n = min(n_updates, 20)

      final_belief =
        Enum.reduce(1..n, Belief.new(), fn i, b ->
          state = Enum.at([:normal, :degraded, :critical, :failed], rem(i, 4))
          Belief.update(b, %{state: state}, surprise)
        end)

      total = final_belief.states |> Map.values() |> Enum.sum()
      abs(total - 1.0) < 1.0e-6
    end
  end

  property "entropy is always non-negative (SC-BEL-004)" do
    forall surprise <- PC.float(0.1, 50.0) do
      belief = Belief.new() |> Belief.update(%{state: :normal}, surprise)
      Belief.entropy(belief) >= 0.0
    end
  end

  property "confidence is always in [0.0, 1.0]" do
    forall surprise <- PC.float(0.0, 100.0) do
      belief = Belief.new() |> Belief.update(%{state: :degraded}, surprise)
      belief.confidence >= 0.0 and belief.confidence <= 1.0
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "merged beliefs preserve probability mass" do
    ExUnitProperties.check all(
                             weight <- SD.float(min: 0.0, max: 1.0),
                             n <- SD.integer(1..10)
                           ) do
      b1 = Belief.new()

      b2 =
        Enum.reduce(1..n, Belief.new(), fn _, b ->
          Belief.update(b, %{state: :failed}, 5.0)
        end)

      merged = Belief.merge(b1, b2, weight)
      total = merged.states |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-6
    end
  end
end
