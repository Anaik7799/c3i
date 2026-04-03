defmodule Indrajaal.AI.IntentRouter do
  @moduledoc """
  Routes AI requests based on intent to optimal model/provider combination.

  ## Intent Categories

  - `:triage` - Quick classification, low cost
  - `:analyze` - Deep analysis, high accuracy
  - `:synthesize` - Content generation, creative
  - `:reason` - Complex reasoning, chain-of-thought
  - `:validate` - Verification, consistency checking
  - `:code` - Code generation/review

  ## Routing Strategies

  - `:nitro` - Speed-optimized (fastest providers)
  - `:floor` - Cost-optimized (cheapest providers)
  - `:free` - Free tier only
  - `nil` - Default routing

  ## STAMP Constraints

  - SC-AI-007: Intent routing provides fallback
  - SC-AI-009: Free tier for triage
  - SC-AI-102: Intent routing mandatory

  ## Usage

      # Get routing config for intent
      config = IntentRouter.route(:analyze)
      # => %{model: "google/gemini-1.5-pro", route: :floor, ...}

      # Select model for intent
      model = IntentRouter.select_model(:synthesize)
      # => "anthropic/claude-3.5-sonnet"
  """

  @type intent :: :triage | :analyze | :synthesize | :reason | :validate | :code | :extract

  @type routing_config :: %{
          model: String.t(),
          route: atom() | nil,
          provider_preferences: map(),
          max_tokens: non_neg_integer(),
          temperature: float()
        }

  # Intent to routing configuration
  @intent_config %{
    triage: %{
      model: "google/gemini-flash-1.5-8b",
      fallback: "meta-llama/llama-3.1-8b-instruct:free",
      route: :floor,
      providers: ["google", "meta-llama"],
      max_tokens: 500,
      temperature: 0.3,
      description: "Quick classification, low cost"
    },
    analyze: %{
      model: "google/gemini-1.5-pro",
      fallback: "anthropic/claude-3.5-sonnet",
      route: :floor,
      providers: ["google", "anthropic"],
      max_tokens: 4000,
      temperature: 0.5,
      description: "Deep analysis, high accuracy"
    },
    synthesize: %{
      model: "anthropic/claude-3.5-sonnet",
      fallback: "openai/gpt-4o",
      route: nil,
      providers: ["anthropic", "openai"],
      max_tokens: 4000,
      temperature: 0.7,
      description: "Content generation, creative"
    },
    reason: %{
      model: "openai/o1-preview",
      fallback: "x-ai/grok-2-1212",
      route: :nitro,
      providers: ["openai", "x-ai", "anthropic"],
      max_tokens: 8000,
      # o1 requires temperature=1
      temperature: 1.0,
      description: "Complex reasoning, chain-of-thought"
    },
    validate: %{
      model: "anthropic/claude-3.5-sonnet",
      fallback: "openai/gpt-4o",
      route: nil,
      providers: ["anthropic", "openai"],
      max_tokens: 2000,
      temperature: 0.2,
      description: "Verification, consistency checking"
    },
    code: %{
      model: "anthropic/claude-3.5-sonnet",
      fallback: "deepseek/deepseek-coder",
      route: nil,
      providers: ["anthropic", "deepseek"],
      max_tokens: 8000,
      temperature: 0.3,
      description: "Code generation/review"
    },
    extract: %{
      model: "google/gemini-2.0-flash-exp:free",
      fallback: "google/gemini-flash-1.5-8b",
      route: :free,
      providers: ["google"],
      max_tokens: 2000,
      temperature: 0.1,
      description: "Knowledge graph extraction"
    }
  }

  # Tier to model mapping (for backwards compatibility)
  @tier_models %{
    fast: "google/gemini-flash-1.5-8b",
    smart: "anthropic/claude-3.5-sonnet",
    deep: "openai/o1-preview",
    grok: "x-ai/grok-2-1212",
    free: "meta-llama/llama-3.1-8b-instruct:free"
  }

  @doc """
  Get full routing configuration for an intent.

  ## Parameters

  - `intent`: The AI intent (:triage, :analyze, etc.)
  - `opts`: Optional overrides

  ## Returns

  A routing configuration map with model, routing strategy, and parameters.
  """
  @spec route(intent(), keyword()) :: routing_config()
  def route(intent, opts \\ []) do
    config = Map.get(@intent_config, intent, @intent_config[:synthesize])

    # Apply strategy override
    strategy = Keyword.get(opts, :strategy)
    model = select_model_for_strategy(config, strategy, opts)

    %{
      model: Keyword.get(opts, :model, model),
      intent: intent,
      route: Keyword.get(opts, :route, config.route),
      provider_preferences: build_provider_preferences(config, opts),
      max_tokens: Keyword.get(opts, :max_tokens, config.max_tokens),
      temperature: Keyword.get(opts, :temperature, config.temperature),
      routing_headers: build_routing_headers(config.route)
    }
  end

  @doc """
  Select the optimal model for an intent.

  Uses the default model for the intent unless budget constraints
  require a fallback.
  """
  @spec select_model(intent()) :: String.t()
  def select_model(intent) do
    config = Map.get(@intent_config, intent, @intent_config[:synthesize])
    config.model
  end

  @doc """
  Select a model for a given tier.

  ## Tiers

  - `:fast` - Low latency, lower cost
  - `:smart` - Balanced performance
  - `:deep` - Complex reasoning
  - `:free` - Free tier models
  """
  @spec select_model_for_tier(atom()) :: String.t()
  def select_model_for_tier(tier) do
    Map.get(@tier_models, tier, @tier_models[:smart])
  end

  @doc """
  Get the routing strategy for an intent.
  """
  @spec get_strategy(intent()) :: atom() | nil
  def get_strategy(intent) do
    config = Map.get(@intent_config, intent, @intent_config[:synthesize])
    config.route
  end

  @doc """
  Get the fallback model for an intent.
  """
  @spec get_fallback(intent()) :: String.t()
  def get_fallback(intent) do
    config = Map.get(@intent_config, intent, @intent_config[:synthesize])
    config.fallback
  end

  @doc """
  List all supported intents with their descriptions.
  """
  @spec list_intents() :: [{intent(), String.t()}]
  def list_intents do
    @intent_config
    |> Enum.map(fn {intent, config} -> {intent, config.description} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  List all supported intents.
  """
  @spec list_supported_intents() :: [intent()]
  def list_supported_intents do
    Map.keys(@intent_config)
  end

  @doc """
  Get the description for an intent.
  """
  @spec intent_description(intent()) :: String.t()
  def intent_description(intent) do
    case Map.get(@intent_config, intent) do
      nil -> "Unknown intent"
      config -> config.description
    end
  end

  @doc """
  Build routing headers for OpenRouter based on strategy.
  """
  @spec build_routing_headers(atom() | nil) :: map()
  def build_routing_headers(:nitro) do
    %{
      "X-Provider-Preferences" => "speed",
      "X-OpenRouter-Suffix" => "nitro"
    }
  end

  def build_routing_headers(:floor) do
    %{
      "X-Provider-Preferences" => "price",
      "X-OpenRouter-Suffix" => "floor"
    }
  end

  def build_routing_headers(:free) do
    %{
      "X-Provider-Preferences" => "price",
      "X-OpenRouter-Suffix" => "free"
    }
  end

  def build_routing_headers(_), do: %{}

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp build_provider_preferences(config, opts) do
    %{
      order: Keyword.get(opts, :providers, config.providers),
      allow_fallbacks: Keyword.get(opts, :allow_fallbacks, true),
      require_parameters: true
    }
  end

  defp select_model_for_strategy(_config, :free, _opts) do
    # Free strategy always uses free tier models
    "google/gemini-2.0-flash-exp:free"
  end

  defp select_model_for_strategy(config, :nitro, _opts) do
    # Nitro strategy uses fastest available
    config.model
  end

  defp select_model_for_strategy(config, :floor, _opts) do
    # Floor strategy uses cheapest non-free option
    config.fallback
  end

  defp select_model_for_strategy(config, _nil_or_unknown, opts) do
    # Default: use budget-aware selection
    select_budget_aware_model(config, opts)
  end

  defp select_budget_aware_model(config, opts) do
    # Check if we should use budget-aware selection
    if Keyword.get(opts, :budget_aware, true) do
      case check_budget_for_model(config.model) do
        :ok ->
          config.model

        {:error, _} ->
          # Try fallback
          case check_budget_for_model(config.fallback) do
            :ok ->
              config.fallback

            {:error, _} ->
              # Use cheapest available
              "meta-llama/llama-3.1-8b-instruct:free"
          end
      end
    else
      config.model
    end
  end

  defp check_budget_for_model(model) do
    # Estimate cost for a typical request
    estimated_cost = Indrajaal.AI.Pricing.estimate_cost(model, 1000, 2000)
    Indrajaal.AI.CostMonitor.check_budget_and_rate(model, estimated_cost)
  end
end
