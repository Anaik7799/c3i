defmodule Indrajaal.AI.PricingTest do
  @moduledoc """
  Tests for the Pricing module.

  ## STAMP Constraints Verified
  - SC-DF-003: Cost calculation for all requests
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AI.Pricing

  describe "estimate_cost/3" do
    test "calculates cost for known model" do
      # Claude 3.5 Sonnet: $3/1M input, $15/1M output
      cost = Pricing.estimate_cost("anthropic/claude-3.5-sonnet", 1_000_000, 1_000_000)

      # 3.0 + 15.0 = 18.0
      assert cost == 18.0
    end

    test "calculates cost for partial tokens" do
      # 1000 input tokens, 2000 output tokens
      cost = Pricing.estimate_cost("anthropic/claude-3.5-sonnet", 1000, 2000)

      # (1000 / 1M * 3.0) + (2000 / 1M * 15.0) = 0.003 + 0.030 = 0.033
      assert cost == 0.033
    end

    test "returns zero cost for free models" do
      cost = Pricing.estimate_cost("meta-llama/llama-3.1-8b-instruct:free", 10_000, 10_000)

      assert cost == 0.0
    end

    test "uses default pricing for unknown models" do
      cost = Pricing.estimate_cost("unknown/model", 1_000_000, 1_000_000)

      # Default: $1/1M input, $5/1M output = 6.0
      assert cost == 6.0
    end
  end

  describe "get_pricing/1" do
    test "returns pricing tuple for known model" do
      assert {:ok, {3.0, 15.0}} = Pricing.get_pricing("anthropic/claude-3.5-sonnet")
    end

    test "returns error for unknown model" do
      assert {:error, :unknown_model} = Pricing.get_pricing("unknown/model")
    end
  end

  describe "get_pricing_tuple/1" do
    test "returns tuple for known model" do
      assert {3.0, 15.0} = Pricing.get_pricing_tuple("anthropic/claude-3.5-sonnet")
    end

    test "returns default for unknown model" do
      assert {1.0, 5.0} = Pricing.get_pricing_tuple("unknown/model")
    end
  end

  describe "free?/1" do
    test "returns true for free models" do
      assert Pricing.free?("meta-llama/llama-3.1-8b-instruct:free")
      assert Pricing.free?("google/gemini-2.0-flash-exp:free")
    end

    test "returns false for paid models" do
      refute Pricing.free?("anthropic/claude-3.5-sonnet")
      refute Pricing.free?("openai/gpt-4o")
    end
  end

  describe "list_models/0" do
    test "returns list of known models" do
      models = Pricing.list_models()

      assert is_list(models)
      assert "anthropic/claude-3.5-sonnet" in models
      assert "openai/gpt-4o" in models
      assert "google/gemini-1.5-pro" in models
    end
  end

  describe "xAI Grok pricing" do
    test "returns pricing for grok-2-1212" do
      assert {:ok, {2.0, 10.0}} = Pricing.get_pricing("x-ai/grok-2-1212")
    end

    test "returns pricing for grok-2" do
      assert {:ok, {2.0, 10.0}} = Pricing.get_pricing("x-ai/grok-2")
    end

    test "returns pricing for grok-2-vision" do
      assert {:ok, {2.0, 10.0}} = Pricing.get_pricing("x-ai/grok-2-vision-1212")
    end

    test "returns pricing for grok-beta" do
      assert {:ok, {5.0, 15.0}} = Pricing.get_pricing("x-ai/grok-beta")
    end

    test "calculates cost for grok-2" do
      # 1000 input tokens, 2000 output tokens
      # (1000 / 1M * 2.0) + (2000 / 1M * 10.0) = 0.002 + 0.020 = 0.022
      cost = Pricing.estimate_cost("x-ai/grok-2-1212", 1000, 2000)
      assert cost == 0.022
    end

    test "grok models appear in list_models" do
      models = Pricing.list_models()

      assert "x-ai/grok-2-1212" in models
      assert "x-ai/grok-2" in models
    end
  end

  describe "list_free_models/0" do
    test "returns only free models" do
      free_models = Pricing.list_free_models()

      assert is_list(free_models)
      assert Enum.all?(free_models, &Pricing.free?/1)
    end
  end

  describe "cost_breakdown/3" do
    test "returns detailed breakdown" do
      breakdown = Pricing.cost_breakdown("anthropic/claude-3.5-sonnet", 1000, 2000)

      assert breakdown.model == "anthropic/claude-3.5-sonnet"
      assert breakdown.input_tokens == 1000
      assert breakdown.output_tokens == 2000
      assert breakdown.input_price_per_1m == 3.0
      assert breakdown.output_price_per_1m == 15.0
      assert breakdown.input_cost == 0.003
      assert breakdown.output_cost == 0.030
      assert breakdown.total_cost == 0.033
      assert breakdown.currency == :usd
    end
  end
end
