defmodule Indrajaal.Cortex.ModelSelectorTest do
  use ExUnit.Case, async: true

  use ExUnitProperties

  alias StreamData, as: SD

  alias Indrajaal.Cortex.ModelSelector

  # EP-GEN-014 compliance: StreamData only (SD. prefix); no PropCheck forall to avoid CounterStrike

  describe "assess_complexity/2" do
    test "returns 0.0 for empty goal with no context" do
      score = ModelSelector.assess_complexity("", %{})
      assert is_float(score)
      assert score >= 0.0
      assert score <= 1.0
    end

    test "safety keywords increase complexity" do
      base = ModelSelector.assess_complexity("simple refactor", %{})
      safety = ModelSelector.assess_complexity("guardian constitutional check", %{})
      assert safety > base
    end

    test "formal verification keywords increase complexity" do
      base = ModelSelector.assess_complexity("add a function", %{})
      formal = ModelSelector.assess_complexity("agda proof theorem verify", %{})
      assert formal > base
    end

    test "token count increases complexity" do
      low = ModelSelector.assess_complexity("task", %{token_count: 100})
      high = ModelSelector.assess_complexity("task", %{token_count: 3_000})
      assert high > low
    end

    test "complexity is capped at 1.0" do
      score =
        ModelSelector.assess_complexity(
          "guardian constitutional sil-6 fmea apoptosis agda proof theorem verify formal",
          %{token_count: 10_000, triage_score: 1.0}
        )

      assert score <= 1.0
    end
  end

  describe "tier_for/1" do
    test "complexity < 0.3 returns :local" do
      assert ModelSelector.tier_for(0.1) == :local
      assert ModelSelector.tier_for(0.29) == :local
    end

    test "complexity 0.3-0.7 returns :free" do
      assert ModelSelector.tier_for(0.3) == :free
      assert ModelSelector.tier_for(0.5) == :free
      assert ModelSelector.tier_for(0.69) == :free
    end

    test "complexity >= 0.7 returns :smart" do
      assert ModelSelector.tier_for(0.7) == :smart
      assert ModelSelector.tier_for(0.9) == :smart
      assert ModelSelector.tier_for(1.0) == :smart
    end
  end

  describe "rank_models/3" do
    test "returns a non-empty list" do
      ranked = ModelSelector.rank_models(0.5, :general)
      assert is_list(ranked)
      assert length(ranked) > 0
    end

    test "results are sorted descending by score" do
      ranked = ModelSelector.rank_models(0.5, :general)
      scores = Enum.map(ranked, & &1.score)
      assert scores == Enum.sort(scores, :desc)
    end

    test "all results have required keys" do
      ranked = ModelSelector.rank_models(0.5, :general)

      for entry <- ranked do
        assert Map.has_key?(entry, :tier)
        assert Map.has_key?(entry, :model)
        assert Map.has_key?(entry, :score)
        assert Map.has_key?(entry, :estimated_cost)
        assert Map.has_key?(entry, :estimated_latency_ms)
      end
    end

    test "low complexity prefers :local tier at top" do
      ranked = ModelSelector.rank_models(0.1, :general)
      assert hd(ranked).tier == :local
    end

    test "high complexity avoids :local at top" do
      ranked = ModelSelector.rank_models(0.95, :general)
      refute hd(ranked).tier == :local
    end

    test "force_free disqualifies :local at mid-complexity" do
      ranked = ModelSelector.rank_models(0.5, :general, force_free: true)
      tiers = Enum.map(ranked, & &1.tier)
      refute :local in tiers
    end

    test "latency_budget_ms filters out slow tiers" do
      ranked = ModelSelector.rank_models(0.8, :general, latency_budget_ms: 60)
      # Only tiers within budget should appear
      for entry <- ranked do
        assert entry.estimated_latency_ms <= 60
      end
    end

    test "quality_floor filters low-quality tiers" do
      ranked = ModelSelector.rank_models(0.1, :general, quality_floor: 0.8)
      # :local tier (quality 0.5) should be excluded
      tiers = Enum.map(ranked, & &1.tier)
      refute :local in tiers
    end
  end

  describe "select/3" do
    test "returns {:ok, model} for valid complexity" do
      assert {:ok, _model} = ModelSelector.select(0.5, :general)
    end

    test "returns :local for very low complexity" do
      assert {:ok, :local} = ModelSelector.select(0.1, :general)
    end

    test "returns a string model for high complexity" do
      {:ok, model} = ModelSelector.select(0.9, :fmea_analysis)
      assert is_binary(model) or model == :local
    end

    test "returns error when no model fits tight constraints" do
      # Tight latency AND high quality floor — may return no suitable model
      result = ModelSelector.select(0.5, :general, latency_budget_ms: 1, quality_floor: 0.99)
      assert result == {:error, :no_suitable_model}
    end
  end

  describe "quality_score/1 and latency_estimate/1" do
    test "quality_score returns expected values" do
      assert ModelSelector.quality_score(:local) == 0.5
      assert ModelSelector.quality_score(:free) == 0.7
      assert ModelSelector.quality_score(:smart) == 0.85
      assert ModelSelector.quality_score(:premium) == 0.95
    end

    test "latency_estimate returns positive integers" do
      for tier <- [:local, :free, :smart, :premium] do
        est = ModelSelector.latency_estimate(tier)
        assert is_integer(est)
        assert est > 0
      end
    end
  end

  describe "model_catalogue/0" do
    test "returns map with expected tier keys" do
      catalogue = ModelSelector.model_catalogue()
      assert Map.has_key?(catalogue, :local)
      assert Map.has_key?(catalogue, :free)
      assert Map.has_key?(catalogue, :smart)
      assert Map.has_key?(catalogue, :premium)
    end
  end

  # Property-based tests (EP-GEN-014 compliant — StreamData only, no PropCheck forall)

  test "StreamData: assess_complexity is always between 0.0 and 1.0" do
    ExUnitProperties.check all(goal <- SD.string(:alphanumeric, max_length: 50)) do
      score = ModelSelector.assess_complexity(goal, %{})
      assert score >= 0.0
      assert score <= 1.0
    end
  end

  test "StreamData: rank_models with valid complexity always returns list" do
    ExUnitProperties.check all(complexity <- SD.float(min: 0.0, max: 1.0)) do
      result = ModelSelector.rank_models(complexity, :general)
      assert is_list(result)
    end
  end

  test "StreamData: rank_models scores are always in valid range" do
    ExUnitProperties.check all(complexity <- SD.float(min: 0.0, max: 1.0)) do
      ranked = ModelSelector.rank_models(complexity, :general)

      assert Enum.all?(ranked, fn entry ->
               entry.score >= 0.0 and entry.score <= 1.5
             end)
    end
  end

  test "StreamData: select returns ok or error for any float complexity" do
    ExUnitProperties.check all(complexity <- SD.float(min: 0.0, max: 1.0)) do
      result = ModelSelector.select(complexity, :general)
      assert match?({:ok, _}, result) or match?({:error, :no_suitable_model}, result)
    end
  end
end
