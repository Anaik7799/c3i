defmodule Indrajaal.AI.Pricing do
  @moduledoc """
  Real-time pricing data for AI model cost estimation.

  ## WHAT
  Provides pricing lookups for AI models with a two-tier strategy:
  1. First checks dynamic cache (PricingCache) for live OpenRouter data
  2. Falls back to static pricing if cache unavailable

  ## WHY
  - Ensures accurate cost tracking even during cache refresh
  - Provides reliable fallback for known models
  - Supports both cached and static pricing sources

  ## STAMP Constraints
  - SC-AI-001: Pricing data available for cost telemetry
  - SC-DF-003: Accurate cost calculation for all models

  ## Usage

      # Estimate cost for a request (uses cache with fallback)
      cost = Pricing.estimate_cost("anthropic/claude-3.5-sonnet", 1000, 2000)
      # => 0.033

      # Get pricing details
      {:ok, {input_price, output_price}} = Pricing.get_pricing("anthropic/claude-3.5-sonnet")

      # Force refresh of cache
      Pricing.refresh_cache()
  """

  alias Indrajaal.AI.PricingCache

  # Prices per 1M tokens: {input_price, output_price}
  @static_pricing %{
    # Anthropic
    "anthropic/claude-3.5-sonnet" => {3.00, 15.00},
    "anthropic/claude-sonnet-4" => {3.00, 15.00},
    "anthropic/claude-3-opus" => {15.00, 75.00},
    "anthropic/claude-3-haiku" => {0.25, 1.25},

    # OpenAI
    "openai/gpt-4o" => {2.50, 10.00},
    "openai/gpt-4o-mini" => {0.15, 0.60},
    "openai/o1-preview" => {15.00, 60.00},
    "openai/o1" => {15.00, 60.00},

    # Google
    "google/gemini-1.5-pro" => {1.25, 5.00},
    "google/gemini-flash-1.5" => {0.075, 0.30},
    "google/gemini-flash-1.5-8b" => {0.0375, 0.15},
    # Free during preview
    "google/gemini-2.0-flash-exp" => {0.0, 0.0},
    "google/gemini-2.0-flash-exp:free" => {0.0, 0.0},

    # DeepSeek
    "deepseek/deepseek-chat" => {0.14, 0.28},
    "deepseek/deepseek-coder" => {0.14, 0.28},

    # Meta (Free tier)
    "meta-llama/llama-3.1-8b-instruct:free" => {0.0, 0.0},
    "meta-llama/llama-3.1-70b-instruct:free" => {0.0, 0.0},

    # Mistral
    "mistralai/mistral-large" => {3.00, 9.00},
    "mistralai/mistral-medium" => {2.70, 8.10},
    "mistralai/mistral-small" => {0.20, 0.60},

    # xAI Grok
    "x-ai/grok-2-1212" => {2.00, 10.00},
    "x-ai/grok-2" => {2.00, 10.00},
    "x-ai/grok-2-vision-1212" => {2.00, 10.00},
    "x-ai/grok-beta" => {5.00, 15.00}
  }

  # Default pricing for unknown models
  @default_pricing {1.00, 5.00}

  @doc """
  Estimate the cost for a model given token counts.

  Checks dynamic cache first, then falls back to static pricing.

  ## Parameters

  - `model`: The model ID (e.g., "anthropic/claude-3.5-sonnet")
  - `input_tokens`: Number of input/prompt tokens
  - `output_tokens`: Number of output/completion tokens

  ## Returns

  Float representing estimated cost in USD.
  """
  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def estimate_cost(model, input_tokens, output_tokens) do
    {input_price, output_price} = get_pricing_tuple(model)

    input_cost = input_tokens / 1_000_000 * input_price
    output_cost = output_tokens / 1_000_000 * output_price

    Float.round(input_cost + output_cost, 6)
  end

  @doc """
  Get the pricing tuple for a model.

  Checks dynamic cache first, then static pricing.
  Returns `{input_price_per_1m, output_price_per_1m}`.
  """
  @spec get_pricing(String.t()) :: {:ok, {float(), float()}} | {:error, :unknown_model}
  def get_pricing(model) do
    # Try cache first
    case PricingCache.get_pricing(model) do
      {:ok, %{input: input, output: output}} ->
        {:ok, {input, output}}

      {:error, _} ->
        # Fall back to static pricing
        case Map.get(@static_pricing, model) do
          nil -> {:error, :unknown_model}
          pricing -> {:ok, pricing}
        end
    end
  end

  @doc """
  Get pricing tuple, with fallback to default.

  Checks dynamic cache first, then static pricing, then default.
  """
  @spec get_pricing_tuple(String.t()) :: {float(), float()}
  def get_pricing_tuple(model) do
    case PricingCache.get_pricing(model) do
      {:ok, %{input: input, output: output}} ->
        {input, output}

      {:error, _} ->
        Map.get(@static_pricing, model, @default_pricing)
    end
  end

  @doc """
  Check if a model is free tier.
  """
  @spec free?(String.t()) :: boolean()
  def free?(model) do
    {input, output} = get_pricing_tuple(model)
    input == 0.0 and output == 0.0
  end

  @doc """
  List all known models with pricing.

  Returns models from cache (if available) plus static models.
  """
  @spec list_models() :: [String.t()]
  def list_models do
    cached_models = PricingCache.list_models()
    static_models = Map.keys(@static_pricing)

    (cached_models ++ static_models)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  List free tier models.

  Returns free models from cache (if available) plus static free models.
  """
  @spec list_free_models() :: [String.t()]
  def list_free_models do
    cached_free = PricingCache.list_free_models()

    static_free =
      @static_pricing
      |> Enum.filter(fn {_model, {input, output}} ->
        abs(input) < 0.001 and abs(output) < 0.001
      end)
      |> Enum.map(&elem(&1, 0))

    (cached_free ++ static_free)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Force refresh of the pricing cache.
  """
  @spec refresh_cache() :: :ok
  def refresh_cache do
    PricingCache.refresh()
  end

  @doc """
  Get cache statistics.
  """
  @spec cache_stats() :: map()
  def cache_stats do
    PricingCache.stats()
  end

  @doc """
  Calculate cost breakdown for a request.

  Returns detailed cost information.
  """
  @spec cost_breakdown(String.t(), non_neg_integer(), non_neg_integer()) :: map()
  def cost_breakdown(model, input_tokens, output_tokens) do
    {input_price, output_price} = get_pricing_tuple(model)

    input_cost = input_tokens / 1_000_000 * input_price
    output_cost = output_tokens / 1_000_000 * output_price

    %{
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      input_price_per_1m: input_price,
      output_price_per_1m: output_price,
      input_cost: Float.round(input_cost, 6),
      output_cost: Float.round(output_cost, 6),
      total_cost: Float.round(input_cost + output_cost, 6),
      currency: :usd
    }
  end
end
