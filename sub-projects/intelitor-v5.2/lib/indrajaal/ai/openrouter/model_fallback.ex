defmodule Indrajaal.AI.OpenRouter.ModelFallback do
  @moduledoc """
  3-level model fallback chain for OpenRouter API resilience.

  Implements intent-based model selection with automatic fallback on failures.
  Each intent has a curated chain of 3 models optimized for that use case.

  ## STAMP Constraints

  - SC-AI-FALLBACK-001: 3-level model fallback chain
  - SC-AI-FALLBACK-002: Intent-based model selection
  - SC-AI-FALLBACK-003: Graceful degradation on model failure

  ## Usage

      # Get fallback chain for an intent
      chain = ModelFallback.get_chain(:analysis)
      # => ["anthropic/claude-3.5-sonnet", "openai/gpt-4-turbo", "google/gemini-pro"]

      # Execute with automatic fallback
      ModelFallback.execute_with_fallback(:chat, fn model ->
        OpenRouterClient.chat(messages, model: model)
      end)

  ## Intents

  - `:analysis` - Complex reasoning and analysis tasks
  - `:coding` - Code generation and review
  - `:chat` - Conversational interactions
  - `:embedding` - Text embedding tasks
  - `:vision` - Image understanding tasks

  """

  require Logger

  @type intent :: :analysis | :coding | :chat | :embedding | :vision | atom()
  @type model :: String.t()
  @type fallback_opts :: [preference: model()]

  # Model chains per intent (3 levels each)
  # Level 1: Best quality
  # Level 2: Good balance
  # Level 3: Reliable fallback
  @model_chains %{
    analysis: [
      "anthropic/claude-3.5-sonnet",
      "openai/gpt-4-turbo",
      "google/gemini-1.5-pro"
    ],
    coding: [
      "anthropic/claude-3.5-sonnet",
      "openai/gpt-4-turbo",
      "deepseek/deepseek-coder"
    ],
    chat: [
      "anthropic/claude-3.5-sonnet",
      "openai/gpt-4-turbo",
      "google/gemini-1.5-flash"
    ],
    embedding: [
      "openai/text-embedding-3-large",
      "openai/text-embedding-3-small",
      "cohere/embed-english-v3.0"
    ],
    vision: [
      "anthropic/claude-3.5-sonnet",
      "openai/gpt-4-vision-preview",
      "google/gemini-1.5-pro"
    ]
  }

  # Default chain for unknown intents
  @default_chain [
    "anthropic/claude-3.5-sonnet",
    "openai/gpt-4-turbo",
    "google/gemini-1.5-flash"
  ]

  # Non-retryable errors (fail immediately, no fallback)
  @non_retryable_errors [
    :invalid_api_key,
    :invalid_request,
    :authentication_failed,
    :authorization_failed,
    :content_policy_violation
  ]

  # Model metadata for capability checking
  @model_info %{
    "anthropic/claude-3.5-sonnet" => %{
      context_length: 200_000,
      capabilities: [:analysis, :coding, :chat, :vision],
      cost_tier: :high
    },
    "openai/gpt-4-turbo" => %{
      context_length: 128_000,
      capabilities: [:analysis, :coding, :chat, :vision],
      cost_tier: :high
    },
    "google/gemini-1.5-pro" => %{
      context_length: 1_000_000,
      capabilities: [:analysis, :coding, :chat, :vision],
      cost_tier: :medium
    },
    "google/gemini-1.5-flash" => %{
      context_length: 1_000_000,
      capabilities: [:chat],
      cost_tier: :low
    },
    "deepseek/deepseek-coder" => %{
      context_length: 64_000,
      capabilities: [:coding],
      cost_tier: :low
    },
    "openai/text-embedding-3-large" => %{
      context_length: 8_191,
      capabilities: [:embedding],
      cost_tier: :low
    },
    "openai/text-embedding-3-small" => %{
      context_length: 8_191,
      capabilities: [:embedding],
      cost_tier: :low
    },
    "cohere/embed-english-v3.0" => %{
      context_length: 512,
      capabilities: [:embedding],
      cost_tier: :low
    },
    "openai/gpt-4-vision-preview" => %{
      context_length: 128_000,
      capabilities: [:vision, :chat],
      cost_tier: :high
    }
  }

  @default_model_info %{
    context_length: 8_000,
    capabilities: [:chat],
    cost_tier: :unknown
  }

  @doc """
  Returns the 3-level fallback chain for an intent.

  ## Examples

      iex> ModelFallback.get_chain(:analysis)
      ["anthropic/claude-3.5-sonnet", "openai/gpt-4-turbo", "google/gemini-1.5-pro"]

      iex> ModelFallback.get_chain(:unknown)
      # Returns default chain

  """
  @spec get_chain(intent()) :: [model()]
  def get_chain(intent) do
    Map.get(@model_chains, intent, @default_chain)
  end

  @doc """
  Selects the best model for an intent based on options.

  ## Options

  - `:preference` - Preferred model (used if in chain)

  ## Examples

      iex> ModelFallback.select_model(:coding)
      "anthropic/claude-3.5-sonnet"

      iex> ModelFallback.select_model(:coding, preference: "openai/gpt-4-turbo")
      "openai/gpt-4-turbo"

  """
  @spec select_model(intent(), fallback_opts()) :: model()
  def select_model(intent, opts \\ []) do
    chain = get_chain(intent)
    preference = Keyword.get(opts, :preference)

    if preference && preference in chain do
      preference
    else
      hd(chain)
    end
  end

  @doc """
  Returns the next model in the fallback chain.

  Returns `nil` if the current model is the last in the chain.

  ## Examples

      iex> ModelFallback.next_model(:analysis, "anthropic/claude-3.5-sonnet")
      "openai/gpt-4-turbo"

      iex> ModelFallback.next_model(:analysis, "google/gemini-1.5-pro")
      nil

  """
  @spec next_model(intent(), model()) :: model() | nil
  def next_model(intent, current_model) do
    chain = get_chain(intent)

    case Enum.find_index(chain, &(&1 == current_model)) do
      nil ->
        # Model not in chain, return first
        hd(chain)

      index ->
        Enum.at(chain, index + 1)
    end
  end

  @doc """
  Executes a function with automatic model fallback.

  Tries each model in the fallback chain until one succeeds or
  all models fail. Non-retryable errors fail immediately.

  ## Examples

      ModelFallback.execute_with_fallback(:chat, fn model ->
        OpenRouterClient.chat(messages, model: model)
      end)

  """
  @spec execute_with_fallback(intent(), (model() -> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def execute_with_fallback(intent, fun) when is_function(fun, 1) do
    chain = get_chain(intent)
    do_execute_chain(chain, fun, nil)
  end

  @doc """
  Returns metadata about a model.

  ## Examples

      iex> ModelFallback.model_info("anthropic/claude-3.5-sonnet")
      %{context_length: 200_000, capabilities: [:analysis, :coding, :chat, :vision], cost_tier: :high}

  """
  @spec model_info(model()) :: map()
  def model_info(model) do
    Map.get(@model_info, model, @default_model_info)
  end

  @doc """
  Checks if a model is suitable for an intent.

  ## Examples

      iex> ModelFallback.suitable_for_intent?("anthropic/claude-3.5-sonnet", :analysis)
      true

  """
  @spec suitable_for_intent?(model(), intent()) :: boolean()
  def suitable_for_intent?(model, intent) do
    info = model_info(model)
    intent in info.capabilities
  end

  # Private functions

  defp do_execute_chain([], _fun, _last_error) do
    {:error, :all_models_failed}
  end

  defp do_execute_chain([model | rest], fun, _last_error) do
    Logger.debug("[ModelFallback] Trying model: #{model}")

    case fun.(model) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error when reason in @non_retryable_errors ->
        # Non-retryable error - fail immediately
        Logger.warning("[ModelFallback] Non-retryable error: #{inspect(reason)}")
        error

      {:error, reason} ->
        Logger.debug("[ModelFallback] Model #{model} failed: #{inspect(reason)}")

        if rest == [] do
          {:error, :all_models_failed}
        else
          do_execute_chain(rest, fun, reason)
        end
    end
  end
end
