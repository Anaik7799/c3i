defmodule Indrajaal.Cybernetic.Inference.IntelligenceBenchmarkerTest do
  @moduledoc """
  Tests for Indrajaal.Cybernetic.Inference.IntelligenceBenchmarker.

  benchmark/3 takes (internal_pred, oracle_pred, actual_obs) where each is a
  probability distribution map %{state => probability}.

  Returns %{internal_error, oracle_error, supremacy_delta}.
  supremacy_delta > 0 means the internal model out-predicted the oracle.

  NOTE: async: false because FounderDirective is a shared GenServer.
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cybernetic.Inference.IntelligenceBenchmarker
  alias Indrajaal.Core.Holon.FounderDirective

  setup do
    if is_nil(GenServer.whereis(FounderDirective)), do: FounderDirective.start_link()
    :ok
  end

  # Shared test distributions
  @actual_healthy %{healthy: 1.0, failing: 0.0}
  @perfect_pred %{healthy: 1.0, failing: 0.0}
  @good_internal %{healthy: 0.9, failing: 0.1}
  @poor_oracle %{healthy: 0.6, failing: 0.4}
  @bad_internal %{healthy: 0.5, failing: 0.5}

  describe "benchmark/3 — return shape" do
    test "returns a map" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert is_map(result)
    end

    test "result has :internal_error key" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert Map.has_key?(result, :internal_error)
    end

    test "result has :oracle_error key" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert Map.has_key?(result, :oracle_error)
    end

    test "result has :supremacy_delta key" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert Map.has_key?(result, :supremacy_delta)
    end

    test "result has exactly three keys" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert map_size(result) == 3
    end

    test "internal_error is a number" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert is_number(result.internal_error)
    end

    test "oracle_error is a number" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert is_number(result.oracle_error)
    end

    test "supremacy_delta is a number" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert is_number(result.supremacy_delta)
    end
  end

  describe "benchmark/3 — supremacy_delta calculation" do
    test "supremacy_delta equals oracle_error minus internal_error" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      expected_delta = result.oracle_error - result.internal_error
      assert_in_delta(result.supremacy_delta, expected_delta, 1.0e-9)
    end

    test "positive delta when internal is more accurate than oracle" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert result.supremacy_delta > 0
    end

    test "negative delta when internal is less accurate than oracle" do
      result = IntelligenceBenchmarker.benchmark(@bad_internal, @perfect_pred, @actual_healthy)
      assert result.supremacy_delta < 0
    end

    test "zero delta when both predictions are identical" do
      result =
        IntelligenceBenchmarker.benchmark(@good_internal, @good_internal, @actual_healthy)

      assert_in_delta(result.supremacy_delta, 0.0, 1.0e-9)
    end
  end

  describe "benchmark/3 — intelligence gain recording" do
    test "intelligence_score increases when supremacy_delta is positive" do
      initial_score = FounderDirective.intelligence_score()
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)

      assert result.supremacy_delta > 0
      assert FounderDirective.intelligence_score() > initial_score
    end

    test "intelligence_score unchanged when supremacy_delta is negative" do
      initial_score = FounderDirective.intelligence_score()
      result = IntelligenceBenchmarker.benchmark(@bad_internal, @perfect_pred, @actual_healthy)

      assert result.supremacy_delta < 0
      assert FounderDirective.intelligence_score() == initial_score
    end

    test "intelligence_score monotonically non-decreasing across positive benchmarks" do
      scores =
        for _i <- 1..3 do
          IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
          FounderDirective.intelligence_score()
        end

      pairs = Enum.zip(scores, tl(scores))

      for {s1, s2} <- pairs do
        assert s2 >= s1, "Expected score to be non-decreasing: #{s1} then #{s2}"
      end
    end
  end

  describe "benchmark/3 — error values" do
    test "errors are non-negative (KL divergence is always >= 0)" do
      result = IntelligenceBenchmarker.benchmark(@good_internal, @poor_oracle, @actual_healthy)
      assert result.internal_error >= 0
      assert result.oracle_error >= 0
    end

    test "perfect prediction yields lower error than imperfect prediction" do
      perfect_result =
        IntelligenceBenchmarker.benchmark(@perfect_pred, @poor_oracle, @actual_healthy)

      imperfect_result =
        IntelligenceBenchmarker.benchmark(@bad_internal, @poor_oracle, @actual_healthy)

      assert perfect_result.internal_error <= imperfect_result.internal_error
    end
  end
end
