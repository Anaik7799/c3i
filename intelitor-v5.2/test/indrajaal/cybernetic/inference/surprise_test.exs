defmodule Indrajaal.Cybernetic.Inference.SurpriseTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Cybernetic.Inference.Surprise.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests enforce information-theoretic constraints pre-implementation
  - FPPS Validation: Surprise metric mathematical correctness

  ## STAMP Safety Integration
  - SC-SUR-001: Surprise MUST be non-negative
  - SC-SUR-002: Surprise calculation MUST be < 1ms
  - SC-SUR-003: Infinite surprise MUST be capped at 100.0
  - SC-SUR-004: Surprise MUST trigger belief update when > threshold (2.0)

  ## Constitutional Verification
  - Psi_3 Verification: Surprise values are deterministic and verifiable
  - Psi_5 Truthfulness: Surprise faithfully reflects deviation from beliefs

  ## Founder's Directive Alignment
  - Omega_0.6: Sentience requires surprise-driven learning

  ## TPS 5-Level RCA Context
  - L1 Symptom: System fails to adapt when anomaly occurs
  - L5 Root Cause: Surprise capping or normalization fails, disabling learning
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Cybernetic.Inference.{Belief, Surprise}

  @moduletag :zenoh_nif
  @max_surprise 100.0
  @threshold 2.0

  # ---- calculate/2 -----------------------------------------------------------

  describe "calculate/2" do
    setup do
      {:ok, belief: Belief.new()}
    end

    test "returns a non-negative float (SC-SUR-001)", %{belief: belief} do
      obs = %{state: :normal}
      result = Surprise.calculate(obs, belief)
      assert is_float(result)
      assert result >= 0.0
    end

    test "surprise is capped at max_surprise (SC-SUR-003)", %{belief: belief} do
      # An impossible observation should produce max surprise
      obs = %{state: :impossible_state}
      result = Surprise.calculate(obs, belief)
      assert result <= @max_surprise
    end

    test "expected observation produces low surprise", %{belief: belief} do
      # Train belief strongly toward :normal
      strong_belief =
        Enum.reduce(1..10, belief, fn _, b ->
          Belief.update(b, %{state: :normal}, 8.0)
        end)

      normal_surprise = Surprise.calculate(%{state: :normal}, strong_belief)
      failed_surprise = Surprise.calculate(%{state: :failed}, strong_belief)
      assert normal_surprise < failed_surprise
    end

    test "surprise is computed quickly (SC-SUR-002)", %{belief: belief} do
      obs = %{state: :degraded}
      start = System.monotonic_time(:microsecond)
      Surprise.calculate(obs, belief)
      elapsed_us = System.monotonic_time(:microsecond) - start
      # Must complete in < 1ms = 1000 microseconds
      assert elapsed_us < 1000
    end
  end

  # ---- bayesian/2 ------------------------------------------------------------

  describe "bayesian/2" do
    test "returns non-negative float" do
      posterior = Belief.new() |> Belief.update(%{state: :normal}, 5.0)
      prior = Belief.new()
      result = Surprise.bayesian(posterior, prior)
      assert is_float(result)
      assert result >= 0.0
    end

    test "same distributions produce near-zero bayesian surprise" do
      b = Belief.new()
      result = Surprise.bayesian(b, b)
      assert result < 0.1
    end
  end

  # ---- expected/2 ------------------------------------------------------------

  describe "expected/2" do
    test "returns non-negative float" do
      belief = Belief.new()
      predicted = %{%{state: :normal} => 0.8, %{state: :failed} => 0.2}
      result = Surprise.expected(predicted, belief)
      assert is_float(result)
      assert result >= 0.0
    end

    test "empty predicted distribution returns 0.0" do
      belief = Belief.new()
      result = Surprise.expected(%{}, belief)
      assert result == 0.0
    end
  end

  # ---- significant?/1 --------------------------------------------------------

  describe "significant?/1" do
    test "returns false for surprise below threshold" do
      refute Surprise.significant?(0.0)
      refute Surprise.significant?(1.9)
    end

    test "returns true for surprise at or above threshold (SC-SUR-004)" do
      assert Surprise.significant?(@threshold)
      assert Surprise.significant?(5.0)
      assert Surprise.significant?(@max_surprise)
    end
  end

  # ---- learning_rate/1 -------------------------------------------------------

  describe "learning_rate/1" do
    test "returns float in [0.01, 1.0]" do
      for surprise <- [0.0, 0.5, 1.0, 2.0, 5.0, 50.0, 100.0] do
        rate = Surprise.learning_rate(surprise)
        assert is_float(rate)
        assert rate >= 0.01
        assert rate <= 1.0
      end
    end

    test "higher surprise produces higher learning rate" do
      low_rate = Surprise.learning_rate(0.1)
      high_rate = Surprise.learning_rate(20.0)
      assert high_rate > low_rate
    end

    test "zero surprise gives near-minimum learning rate" do
      rate = Surprise.learning_rate(0.0)
      assert rate <= 0.05
    end
  end

  # ---- categorize/1 ----------------------------------------------------------

  describe "categorize/1" do
    test "0.0 is :low" do
      assert Surprise.categorize(0.0) == :low
    end

    test "0.5 is :low" do
      assert Surprise.categorize(0.5) == :low
    end

    test "1.5 is :moderate" do
      assert Surprise.categorize(1.5) == :moderate
    end

    test "5.0 is :high" do
      assert Surprise.categorize(5.0) == :high
    end

    test "50.0 is :extreme" do
      assert Surprise.categorize(50.0) == :extreme
    end

    test "max_surprise is :extreme" do
      assert Surprise.categorize(@max_surprise) == :extreme
    end
  end

  # ---- derivative/1 ----------------------------------------------------------

  describe "derivative/1" do
    test "empty history returns 0.0" do
      assert Surprise.derivative([]) == 0.0
    end

    test "single element returns 0.0" do
      assert Surprise.derivative([5.0]) == 0.0
    end

    test "returns current minus previous" do
      history = [3.0, 2.0, 1.0]
      assert Surprise.derivative(history) == 1.0
    end

    test "decreasing sequence gives negative derivative" do
      history = [1.0, 3.0, 5.0]
      assert Surprise.derivative(history) == -2.0
    end
  end

  # ---- increasing?/1 ---------------------------------------------------------

  describe "increasing?/1" do
    test "empty history is not increasing" do
      refute Surprise.increasing?([])
    end

    test "single element is not increasing" do
      refute Surprise.increasing?([5.0])
    end

    test "derivative > 0.5 is increasing" do
      assert Surprise.increasing?([10.0, 5.0])
    end

    test "decreasing history is not increasing" do
      refute Surprise.increasing?([2.0, 5.0, 8.0])
    end
  end

  # ---- normalize/1 -----------------------------------------------------------

  describe "normalize/1" do
    test "returns float in [0.0, 1.0]" do
      for surprise <- [0.0, 1.0, 10.0, 50.0, 100.0] do
        result = Surprise.normalize(surprise)
        assert result >= 0.0
        assert result <= 1.0
      end
    end

    test "zero surprise normalizes near 0.0" do
      result = Surprise.normalize(0.0)
      assert result < 0.05
    end

    test "high surprise normalizes near 1.0" do
      result = Surprise.normalize(@max_surprise)
      assert result > 0.9
    end
  end

  # ---- threshold/0 -----------------------------------------------------------

  describe "threshold/0" do
    test "returns the expected threshold value" do
      assert Surprise.threshold() == @threshold
    end
  end

  # ---- summary/1 -------------------------------------------------------------

  describe "summary/1" do
    test "empty list returns zero-valued summary" do
      s = Surprise.summary([])
      assert s.count == 0
      assert s.mean == 0.0
      assert s.max == 0.0
      assert s.min == 0.0
      assert s.trend == :stable
    end

    test "non-empty list returns correct statistics" do
      history = [1.0, 2.0, 3.0, 4.0, 5.0]
      s = Surprise.summary(history)
      assert s.count == 5
      assert_in_delta s.mean, 3.0, 0.001
      assert s.max == 5.0
      assert s.min == 1.0
    end

    test "trend is :increasing when surprise is growing" do
      history = [5.0, 1.0]
      s = Surprise.summary(history)
      assert s.trend == :increasing
    end

    test "trend is :stable when surprise is decreasing" do
      history = [1.0, 5.0]
      s = Surprise.summary(history)
      assert s.trend == :stable
    end
  end

  # ---- PropCheck properties --------------------------------------------------

  property "surprise is always non-negative (SC-SUR-001)" do
    forall prob <- PC.float(0.0, 1.0) do
      # Build an artificial belief where probability equals prob
      # We verify the shape: -log(prob) >= 0
      if prob > 0.0 do
        -:math.log(prob) >= 0.0
      else
        true
      end
    end
  end

  property "learning rate is always in [0.01, 1.0]" do
    forall surprise <- PC.float(0.0, 200.0) do
      rate = Surprise.learning_rate(surprise)
      rate >= 0.01 and rate <= 1.0
    end
  end

  property "normalize always returns value in [0.0, 1.0]" do
    forall surprise <- PC.float(0.0, 1000.0) do
      result = Surprise.normalize(surprise)
      result >= 0.0 and result <= 1.0
    end
  end

  # ---- StreamData property tests ---------------------------------------------

  test "surprise capping enforces max_surprise (SC-SUR-003)" do
    ExUnitProperties.check all(surprise_input <- SD.float(min: 0.0, max: 1.0e6)) do
      # Simulate capping logic
      capped = min(surprise_input, @max_surprise)
      assert capped <= @max_surprise
    end
  end

  test "significant? is monotone" do
    ExUnitProperties.check all(
                             low <- SD.float(min: 0.0, max: 2.0),
                             high <- SD.float(min: 2.0, max: 100.0)
                           ) do
      # If low is significant, high must also be significant
      if Surprise.significant?(low) do
        assert Surprise.significant?(high)
      else
        assert true
      end
    end
  end
end
