defmodule Indrajaal.AI.ProviderDispatcher do
  @moduledoc """
  Dispatches AI requests to the appropriate provider.

  ## Providers

  - `:openrouter` - OpenRouter multi-model gateway (default)
  - `:anthropic` - Direct Anthropic API
  - `:google` - Direct Google AI API
  - `:ollama` - Local Ollama instance

  ## Features

  - Provider-specific request formatting
  - Response normalization
  - Automatic fallback on provider failure
  - Cost tracking integration
  - Telemetry streaming

  ## STAMP Constraints

  - SC-AI-001: All providers emit telemetry
  - SC-DF-003: Cost calculated for all responses

  ## Usage

      {:ok, result} = ProviderDispatcher.chat(:openrouter, proposal, opts)
  """

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.AI.Providers.GrokClient

  require Logger

  @type provider :: :openrouter | :anthropic | :google | :ollama | :grok

  @type chat_result :: %{
          content: String.t(),
          model: String.t(),
          usage: map(),
          cost: map(),
          provider: provider(),
          latency_ms: non_neg_integer()
        }

  @doc """
  Send a chat request to the specified provider.

  ## Parameters

  - `provider`: The AI provider to use
  - `proposal`: The request proposal from SimplexController
  - `opts`: Additional options

  ## Returns

  - `{:ok, result}` with normalized response
  - `{:error, reason}` on failure
  """
  @spec chat(provider(), map(), keyword()) :: {:ok, chat_result()} | {:error, term()}
  def chat(provider, proposal, opts \\ [])

  def chat(:openrouter, proposal, opts) do
    start_time = System.monotonic_time(:millisecond)

    messages = proposal[:messages] || build_messages(proposal[:prompt])
    model = proposal[:model]

    merged_opts =
      opts
      |> Keyword.put(:model, model)
      |> Keyword.put(:temperature, proposal[:temperature])

    case OpenRouterClient.chat(messages, merged_opts) do
      {:ok, content} ->
        end_time = System.monotonic_time(:millisecond)
        latency = end_time - start_time

        result = %{
          content: content,
          model: model,
          usage: %{
            prompt_tokens: proposal[:estimated_input_tokens] || 0,
            completion_tokens: estimate_tokens(content),
            total_tokens: (proposal[:estimated_input_tokens] || 0) + estimate_tokens(content)
          },
          cost:
            calculate_cost(
              model,
              proposal[:estimated_input_tokens] || 0,
              estimate_tokens(content)
            ),
          provider: :openrouter,
          latency_ms: latency
        }

        {:ok, result}

      {:error, reason} ->
        Logger.warning("[ProviderDispatcher] OpenRouter failed: #{inspect(reason)}")
        maybe_fallback(proposal, opts, reason)
    end
  end

  def chat(:anthropic, proposal, opts) do
    # Direct Anthropic API (future implementation)
    Logger.debug(
      "[ProviderDispatcher] Anthropic direct not implemented, falling back to OpenRouter"
    )

    chat(:openrouter, proposal, opts)
  end

  def chat(:google, proposal, opts) do
    # Direct Google AI API (future implementation)
    Logger.debug("[ProviderDispatcher] Google direct not implemented, falling back to OpenRouter")
    chat(:openrouter, proposal, opts)
  end

  def chat(:ollama, proposal, opts) do
    # Local Ollama instance
    case dispatch_to_ollama(proposal, opts) do
      {:ok, _} = result ->
        result

      {:error, reason} ->
        Logger.warning("[ProviderDispatcher] Ollama failed: #{inspect(reason)}, falling back")
        maybe_fallback(proposal, opts, reason)
    end
  end

  def chat(:grok, proposal, opts) do
    # Direct Grok API via xAI
    start_time = System.monotonic_time(:millisecond)

    messages = proposal[:messages] || build_messages(proposal[:prompt])
    model = proposal[:model] || "grok-2"

    merged_opts =
      opts
      |> Keyword.put(:model, model)
      |> Keyword.put(:temperature, proposal[:temperature])

    case GrokClient.chat(messages, merged_opts) do
      {:ok, content} ->
        end_time = System.monotonic_time(:millisecond)
        latency = end_time - start_time

        result = %{
          content: content,
          model: model,
          usage: %{
            prompt_tokens: proposal[:estimated_input_tokens] || 0,
            completion_tokens: estimate_tokens(content),
            total_tokens: (proposal[:estimated_input_tokens] || 0) + estimate_tokens(content)
          },
          cost:
            calculate_cost(
              model,
              proposal[:estimated_input_tokens] || 0,
              estimate_tokens(content)
            ),
          provider: :grok,
          latency_ms: latency
        }

        {:ok, result}

      {:error, reason} ->
        Logger.warning("[ProviderDispatcher] Grok failed: #{inspect(reason)}")
        maybe_fallback(proposal, opts, reason)
    end
  end

  def chat(unknown_provider, proposal, opts) do
    Logger.warning("[ProviderDispatcher] Unknown provider: #{unknown_provider}, using OpenRouter")
    chat(:openrouter, proposal, opts)
  end

  @doc """
  Stream a chat response from the specified provider.

  Returns a stream that can be consumed for real-time responses.
  """
  @spec chat_stream(provider(), map(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def chat_stream(:openrouter, proposal, opts) do
    # OpenRouter streaming
    prompt = proposal[:prompt] || ""
    model = proposal[:model]
    context = proposal[:context] || "provider_dispatcher"

    stream_opts =
      opts
      |> Keyword.put(:model, model)
      |> Keyword.put(:stream, true)
      # Allow ZDR injection from opts, default to true if not present
      |> Keyword.put_new(:zdr, true)

    OpenRouterClient.chat_stream(prompt, context, stream_opts)
  end

  def chat_stream(provider, proposal, opts) do
    # For other providers, fall back to regular chat
    case chat(provider, proposal, opts) do
      {:ok, result} ->
        {:ok, result[:content] |> Stream.iterate(fn _ -> nil end) |> Stream.take(1)}

      error ->
        error
    end
  end

  @doc """
  Get available providers.
  """
  @spec list_providers() :: [provider()]
  def list_providers do
    [:openrouter, :anthropic, :google, :ollama, :grok]
  end

  @doc """
  Check if a provider is available.
  """
  @spec provider_available?(provider()) :: boolean()
  def provider_available?(:openrouter) do
    config = Application.get_env(:indrajaal, :ai, [])
    not is_nil(config[:openrouter_key]) and config[:openrouter_key] != ""
  end

  def provider_available?(:ollama) do
    # Check if Ollama is running locally
    case :gen_tcp.connect(~c"localhost", 11_434, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _} ->
        false
    end
  end

  def provider_available?(:grok) do
    api_key = System.get_env("GROK_API_KEY")
    not is_nil(api_key) and api_key != ""
  end

  def provider_available?(_), do: false

  # ---------------------------------------------------------------------------
  # Private Functions
  # ---------------------------------------------------------------------------

  defp build_messages(nil), do: []
  defp build_messages(""), do: []

  defp build_messages(prompt) when is_binary(prompt) do
    [%{"role" => "user", "content" => prompt}]
  end

  defp estimate_tokens(nil), do: 0
  defp estimate_tokens(text) when is_binary(text), do: div(String.length(text), 4)
  defp estimate_tokens(_), do: 0

  defp calculate_cost(model, input_tokens, output_tokens) do
    total = Indrajaal.AI.Pricing.estimate_cost(model, input_tokens, output_tokens)
    breakdown = Indrajaal.AI.Pricing.cost_breakdown(model, input_tokens, output_tokens)

    %{
      input_cost: breakdown.input_cost,
      output_cost: breakdown.output_cost,
      total_cost: total,
      currency: :usd
    }
  end

  defp maybe_fallback(proposal, opts, _original_error) do
    if Keyword.get(opts, :allow_fallback, true) do
      fallback_model = Indrajaal.AI.IntentRouter.get_fallback(proposal[:intent] || :synthesize)

      if fallback_model != proposal[:model] do
        Logger.info("[ProviderDispatcher] Attempting fallback to #{fallback_model}")
        fallback_proposal = Map.put(proposal, :model, fallback_model)
        chat(:openrouter, fallback_proposal, Keyword.put(opts, :allow_fallback, false))
      else
        {:error, :no_fallback_available}
      end
    else
      {:error, :fallback_disabled}
    end
  end

  defp dispatch_to_ollama(proposal, _opts) do
    model = proposal[:model] || "llama3.1"
    prompt = proposal[:prompt] || ""

    # Extract just the model name for Ollama
    ollama_model =
      model
      |> String.split("/")
      |> List.last()
      |> String.split(":")
      |> List.first()

    payload = %{
      model: ollama_model,
      prompt: prompt,
      stream: false
    }

    case Req.post("http://localhost:11_434/api/generate", json: payload) do
      {:ok, %{status: 200, body: body}} ->
        {:ok,
         %{
           content: body["response"] || "",
           model: ollama_model,
           usage: %{total_tokens: 0},
           cost: %{total_cost: 0.0, currency: :usd},
           provider: :ollama,
           latency_ms: 0
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, {:ollama_error, status, body}}

      {:error, reason} ->
        {:error, {:ollama_connection_failed, reason}}
    end
  end
end
