defmodule Indrajaal.Cybernetic.Inference.PredictionTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.Inference.Prediction.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Prediction correctness validated before runtime usage
  - FPPS Validation: Probability distribution integrity across prediction horizons

  ## STAMP Safety Integration
  - SC-PRED-001: Predictions MUST include uncertainty estimates
  - SC-PRED-002: Prediction horizon MUST be bounded (max 10)
  - SC-PRED-003: Prediction errors MUST be tracked
  - SC-PRED-004: Model updates MUST be gradual (learning_rate <= 1.0)

  ## Constitutional Verification
  - Psi_3 Verification: Prediction distributions are deterministically verifiable
  - Psi_5 Truthfulness: KL divergence-based error accurately measures mismatch

  ## TPS 5-Level RCA Context
  - L1 Symptom: Action selection selects dangerous actions in critical state
  - L5 Root Cause: State transition model returns non-normalised distribution
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.Inference.{Belief, Prediction}

  @moduletag :zenoh_nif

  # ---- predict/3 -------------------------------------------------------------

  describe "predict/3" do
    setup do
      {:ok, belief: Belief.new(), model: %{}}
    end

    test "returns a non-empty map", %{belief: belief, model: model} do
      result = Prediction.predict(belief, :noop, model)
      assert is_map(result)
      assert map_size(result) > 0
    end

    test "predicted probabilities are non-negative", %{belief: belief, model: model} do
      result = Prediction.predict(belief, :noop, model)
      Enum.each(result, fn {_, prob} -> assert prob >= 0.0 end)
    end

    test "predicted probabilities sum to 1.0", %{belief: belief, model: model} do
      result = Prediction.predict(belief, :noop, model)
      total = result |> Map.values() |> Enum.sum()
      assert_in_delta total, 1.0, 1.0e-6
    end

    test "all default actions return valid distributions", %{belief: belief, model: model} do
      for action <- [:observe, :maintain, :repair, :escalate, :noop] do
        result = Prediction.predict(belief, action, model)
        assert map_size(result) > 0
        total = result |> Map.values() |> Enum.sum()
        assert_in_delta total, 1.0, 1.0e-6
      end
    end
  end

  # ---- predict_trajectory/4 --------------------------------------------------

  describe "predict_trajectory/4" do
    setup do
      {:ok, belief: Belief.new(), model: %{}}
    end

    test "returns list of prediction maps", %{belief: belief, model: model} do
      trajectory = Prediction.predict_trajectory(belief, [:noop, :maintain], model)
      assert is_list(trajectory)
      assert length(trajectory) > 0
      Enum.each(trajectory, fn pred -> assert is_map(pred) end)
    end

    test "horizon is bounded at max 10 (SC-PRED-002)", %{belief: belief, model: model} do
      actions = List.duplicate(:noop, 5)
      trajectory = Prediction.predict_trajectory(belief, actions, model, 15)
      assert length(trajectory) <= 10
    end

    test "trajectory length equals horizon when actions provided", %{belief: belief, model: model} do
      horizon = 5
      trajectory = Prediction.predict_trajectory(belief, [], model, horizon)
      assert length(trajectory) == horizon
    end

    test "each step has valid probability distribution", %{belief: belief, model: model} do
      trajectory = Prediction.predict_trajectory(belief, [:noop], model, 3)

      Enum.each(trajectory, fn pred ->
        total = pred |> Map.values() |> Enum.sum()
        assert_in_delta total, 1.0, 1.0e-6
      end)
    end
  end

  # ---- error/2 ---------------------------------------------------------------

  describe "error/2" do
    test "returns prediction_error map" do
      predicted = %{normal: 0.7, failed: 0.3}
      actual = %{normal: 0.8, failed: 0.2}
      result = Prediction.error(predicted, actual)
      assert Map.has_key?(result, :predicted)
      assert Map.has_key?(result, :actual)
      assert Map.has_key?(result, :error)
    end

    test "error is non-negative float (KL divergence)" do
      predicted = %{normal: 0.7, failed: 0.3}
      actual = %{normal: 0.8, failed: 0.2}
      result = Prediction.error(predicted, actual)
      assert is_float(result.error)
      assert result.error >= 0.0
    end

    test "identical distributions yield near-zero error" do
      dist = %{normal: 0.6, degraded: 0.3, critical: 0.1}
      result = Prediction.error(dist, dist)
      assert result.error < 0.01
    end

    test "preserves predicted and actual in result" do
      predicted = %{normal: 0.9, failed: 0.1}
      actual = %{normal: 0.1, failed: 0.9}
      result = Prediction.error(predicted, actual)
      assert result.predicted == predicted
      assert result.actual == actual
    end

    test "large divergence produces large error" do
      predicted = %{normal: 0.99, failed: 0.01}
      actual = %{normal: 0.01, failed: 0.99}
      small_pred = %{normal: 0.55, failed: 0.45}
      small_actual = %{normal: 0.45, failed: 0.55}

      large_err = Prediction.error(predicted, actual).error
      small_err = Prediction.error(small_pred, small_actual).error
      assert large_err > small_err
    end
  end

  # ---- accuracy/1 ------------------------------------------------------------

  describe "accuracy/1" do
    test "empty error list returns 1.0" do
      assert Prediction.accuracy([]) == 1.0
    end

    test "returns float in (0.0, 1.0] for non-empty errors" do
      errors = [
        %{predicted: %{}, actual: %{}, error: 1.0},
        %{predicted: %{}, actual: %{}, error: 2.0}
      ]

      acc = Prediction.accuracy(errors)
      assert is_float(acc)
      assert acc > 0.0
      assert acc <= 1.0
    end

    test "zero errors produce accuracy of 1.0" do
      errors = [
        %{predicted: %{}, actual: %{}, error: 0.0},
        %{predicted: %{}, actual: %{}, error: 0.0}
      ]

      assert Prediction.accuracy(errors) == 1.0
    end

    test "higher error results in lower accuracy" do
      low_error = [%{predicted: %{}, actual: %{}, error: 0.1}]
      high_error = [%{predicted: %{}, actual: %{}, error: 100.0}]
      assert Prediction.accuracy(low_error) > Prediction.accuracy(high_error)
    end
  end

  # ---- update_model/3 --------------------------------------------------------

  describe "update_model/3" do
    test "returns a map (SC-PRED-004)" do
      model = %{confidence: 1.0}
      errors = [%{predicted: %{}, actual: %{}, error: 0.5}]
      updated = Prediction.update_model(model, errors)
      assert is_map(updated)
    end

    test "confidence is adjusted down when error is high" do
      model = %{confidence: 1.0}
      errors = [%{predicted: %{}, actual: %{}, error: 5.0}]
      updated = Prediction.update_model(model, errors, 0.1)
      assert updated.confidence < 1.0
    end

    test "confidence floor is respected (min 0.1)" do
      model = %{confidence: 1.0}
      errors = List.duplicate(%{predicted: %{}, actual: %{}, error: 100.0}, 20)
      updated = Prediction.update_model(model, errors, 1.0)
      assert updated.confidence >= 0.1
    end

    test "confidence ceiling is respected (max 1.0)" do
      model = %{confidence: 0.5}
      errors = [%{predicted: %{}, actual: %{}, error: 0.0}]
      updated = Prediction.update_model(model, errors, 0.1)
      assert updated.confidence <= 1.0
    end

    test "empty errors do not change model" do
      model = %{confidence: 0.8}
      updated = Prediction.update_model(model, [], 0.1)
      assert updated.confidence == 0.8
    end
  end

  # ---- most_likely/1 ---------------------------------------------------------

  describe "most_likely/1" do
    test "returns tuple {atom, float}" do
      prediction = %{normal: 0.7, failed: 0.3}
      {state, prob} = Prediction.most_likely(prediction)
      assert is_atom(state)
      assert is_float(prob)
    end

    test "returns the state with highest probability" do
      prediction = %{normal: 0.7, degraded: 0.2, failed: 0.1}
      {state, prob} = Prediction.most_likely(prediction)
      assert state == :normal
      assert prob == 0.7
    end

    test "empty map returns {:unknown, 0.0}" do
      {state, prob} = Prediction.most_likely(%{})
      assert state == :unknown
      assert prob == 0.0
    end
  end

  # ---- entropy/1 -------------------------------------------------------------

  describe "entropy/1" do
    test "returns non-negative float" do
      prediction = %{normal: 0.5, failed: 0.5}
      assert Prediction.entropy(prediction) >= 0.0
    end

    test "uniform distribution has max entropy" do
      uniform = %{a: 0.25, b: 0.25, c: 0.25, d: 0.25}
      certain = %{a: 0.97, b: 0.01, c: 0.01, d: 0.01}
      assert Prediction.entropy(uniform) > Prediction.entropy(certain)
    end

    test "empty map returns 0.0" do
      assert Prediction.entropy(%{}) == 0.0
    end
  end

  # ---- uncertainty/1 ---------------------------------------------------------

  describe "uncertainty/1" do
    test "returns float in [0.0, 1.0] (SC-PRED-001)" do
      prediction = %{normal: 0.6, failed: 0.4}
      u = Prediction.uncertainty(prediction)
      assert u >= 0.0
      assert u <= 1.0
    end

    test "uniform distribution has high uncertainty" do
      uniform = %{a: 0.25, b: 0.25, c: 0.25, d: 0.25}
      certain = %{a: 0.99, b: 0.005, c: 0.003, d: 0.002}
      assert Prediction.uncertainty(uniform) > Prediction.uncertainty(certain)
    end
  end

  # ---- confident?/2 ----------------------------------------------------------

  describe "confident?/2" do
    test "returns true when best prob >= threshold" do
      prediction = %{normal: 0.8, failed: 0.2}
      assert Prediction.confident?(prediction, 0.7)
    end

    test "returns false when best prob < threshold" do
      prediction = %{normal: 0.5, failed: 0.5}
      refute Prediction.confident?(prediction, 0.7)
    end

    test "uses default threshold of 0.6" do
      high_conf = %{normal: 0.7, failed: 0.3}
      low_conf = %{normal: 0.55, failed: 0.45}
      assert Prediction.confident?(high_conf)
      refute Prediction.confident?(low_conf)
    end
  end

  # ---- PropCheck properties --------------------------------------------------

  property "predicted distributions always sum to ~1.0" do
    forall action <- PC.oneof([:observe, :maintain, :repair, :escalate, :noop]) do
      belief = Belief.new()
      result = Prediction.predict(belief, action, %{})
      total = result |> Map.values() |> Enum.sum()
      abs(total - 1.0) < 1.0e-6
    end
  end

  property "uncertainty is always in [0.0, 1.0] (SC-PRED-001)" do
    forall probs <- PC.vector(3, PC.float(0.01, 1.0)) do
      total = Enum.sum(probs)
      norm = Enum.map(probs, &(&1 / total))
      dist = Enum.zip([:a, :b, :c], norm) |> Map.new()
      u = Prediction.uncertainty(dist)
      u >= 0.0 and u <= 1.0
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "accuracy degrades monotonically with increasing error" do
    ExUnitProperties.check all(
                             err1 <- SD.float(min: 0.0, max: 5.0),
                             err2 <- SD.float(min: 5.0, max: 50.0)
                           ) do
      e1 = [%{predicted: %{}, actual: %{}, error: err1}]
      e2 = [%{predicted: %{}, actual: %{}, error: err2}]
      Prediction.accuracy(e1) >= Prediction.accuracy(e2)
    end
  end

  test "prediction trajectory length is bounded by max horizon" do
    ExUnitProperties.check all(horizon <- SD.integer(1..20)) do
      belief = Belief.new()
      traj = Prediction.predict_trajectory(belief, [], %{}, horizon)
      length(traj) <= 10
    end
  end
end
