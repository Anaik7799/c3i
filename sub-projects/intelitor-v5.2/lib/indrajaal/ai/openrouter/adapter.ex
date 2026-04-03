defmodule Indrajaal.AI.OpenRouter.Adapter do
  @moduledoc """
  Enhanced OpenRouter adapter with retry, streaming, and fallback capabilities.

  Provides a unified interface to OpenRouter API with enterprise-grade
  resilience features:

  - Exponential backoff with jitter (SC-AI-RETRY-001/002)
  - SSE streaming support (SC-AI-STREAM-001/002/003)
  - 3-level model fallback chains (SC-AI-FALLBACK-001/002/003)

  ## STAMP Constraints

  - SC-AI-RETRY-001: Max 3 retries with exponential backoff
  - SC-AI-RETRY-002: Jitter factor 0.1-0.3 prevents thundering herd
  - SC-AI-STREAM-001: Non-blocking SSE via GenStage
  - SC-AI-FALLBACK-001: 3-level model fallback chain

  ## Usage

      # Simple chat with automatic retry and fallback
      Adapter.chat(messages, intent: :analysis)

      # Streaming chat
      Adapter.stream_chat(messages, fn chunk ->
        IO.write(chunk.content)
      end, intent: :chat)

  ## Integration Points

  - `SimplexController` - Safety-validated AI execution
  - `OODAAgent` - AI orientation in FastOODA loop
  - `ProviderDispatcher` - Multi-provider routing

  """

  require Logger

  alias Indrajaal.AI.OpenRouter.{RetryStrategy, StreamHandler, ModelFallback}

  @type message :: %{role: String.t(), content: String.t()}
  @type chat_opts :: [
          intent: atom(),
          model: String.t(),
          max_tokens: pos_integer(),
          temperature: float(),
          stream: boolean(),
          timeout: pos_integer()
        ]

  @type result :: {:ok, map()} | {:error, term()}

  @default_timeout 30_000
  @default_max_tokens 4096
  @default_temperature 0.7

  @doc """
  Performs a chat completion with automatic retry and fallback.

  ## Options

  - `:intent` - Task intent for model selection (:analysis, :coding, :chat)
  - `:model` - Override model selection (optional)
  - `:max_tokens` - Maximum tokens to generate (default: 4096)
  - `:temperature` - Temperature for sampling (default: 0.7)
  - `:timeout` - Request timeout in ms (default: 30_000)

  ## Examples

      Adapter.chat([%{role: "user", content: "Hello"}], intent: :chat)
      # => {:ok, %{content: "Hello! How can I help?", model: "anthropic/claude-3.5-sonnet"}}

  """
  @spec chat([message()], chat_opts()) :: result()
  def chat(messages, opts \\ []) when is_list(messages) do
    intent = Keyword.get(opts, :intent, :chat)
    model_override = Keyword.get(opts, :model)

    if model_override do
      # Direct model call with retry
      execute_chat(messages, model_override, opts)
    else
      # Use fallback chain
      ModelFallback.execute_with_fallback(intent, fn model ->
        execute_chat(messages, model, opts)
      end)
    end
  end

  @doc """
  Performs streaming chat completion.

  Streams response chunks to the provided callback function.

  ## Options

  Same as `chat/2` plus:
  - `:on_chunk` - Callback for each chunk (alternative to callback arg)

  ## Examples

      Adapter.stream_chat(messages, fn chunk ->
        IO.write(chunk.content || "")
      end, intent: :chat)

  """
  @spec stream_chat([message()], (map() -> any()), chat_opts()) :: result()
  def stream_chat(messages, callback, opts \\ [])
      when is_list(messages) and is_function(callback, 1) do
    intent = Keyword.get(opts, :intent, :chat)
    model_override = Keyword.get(opts, :model)

    if model_override do
      execute_stream_chat(messages, model_override, callback, opts)
    else
      ModelFallback.execute_with_fallback(intent, fn model ->
        execute_stream_chat(messages, model, callback, opts)
      end)
    end
  end

  @doc """
  Returns the model that would be selected for an intent.

  Useful for displaying model information before making a request.
  """
  @spec select_model(atom(), Keyword.t()) :: String.t()
  def select_model(intent, opts \\ []) do
    ModelFallback.select_model(intent, opts)
  end

  @doc """
  Returns configuration for integration with FastOODA.

  The returned config can be used by OODAAgent for AI orientation
  with the 20ms timeout constraint (SC-OODA-006).
  """
  @spec ooda_config() :: map()
  def ooda_config do
    %{
      timeout_ms: 20,
      fallback_enabled: true,
      intent: :analysis,
      max_tokens: 256,
      # Use fast model for OODA loop
      model: "google/gemini-1.5-flash"
    }
  end

  # Private implementation

  defp execute_chat(messages, model, opts) do
    {timeout, request_opts} = build_request_opts(model, opts)

    RetryStrategy.execute(fn ->
      do_chat_request(messages, request_opts, timeout)
    end)
  end

  defp execute_stream_chat(messages, model, callback, opts) do
    {timeout, request_opts} = build_request_opts(model, opts, stream: true)

    RetryStrategy.execute(fn ->
      do_stream_request(messages, request_opts, callback, timeout)
    end)
  end

  defp build_request_opts(model, opts, extra \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    temperature = Keyword.get(opts, :temperature, @default_temperature)

    request_opts =
      [model: model, max_tokens: max_tokens, temperature: temperature]
      |> Keyword.merge(extra)

    {timeout, request_opts}
  end

  defp do_chat_request(messages, opts, timeout) do
    # Delegate to existing OpenRouterClient
    case Indrajaal.AI.OpenRouterClient.chat(messages, opts ++ [timeout: timeout]) do
      {:ok, response} ->
        {:ok, normalize_response(response, opts[:model])}

      {:error, reason} ->
        {:error, normalize_error(reason)}
    end
  end

  defp do_stream_request(messages, opts, callback, timeout) do
    model = opts[:model]

    case Indrajaal.AI.OpenRouterClient.chat(messages, opts ++ [timeout: timeout]) do
      {:ok, stream_ref} when is_reference(stream_ref) ->
        # Handle streaming response
        collect_stream(stream_ref, callback, model)

      {:ok, response} ->
        # Non-streaming response (fallback)
        content = get_in(response, ["choices", Access.at(0), "message", "content"]) || ""
        callback.(%{type: :data, content: content})
        callback.(%{type: :done})
        {:ok, normalize_response(response, model)}

      {:error, reason} ->
        {:error, normalize_error(reason)}
    end
  end

  defp collect_stream(stream_ref, callback, model) do
    state = StreamHandler.new_state()
    do_collect_stream(stream_ref, callback, state, [], model)
  end

  defp do_collect_stream(stream_ref, callback, state, events, model) do
    receive do
      {:stream, ^stream_ref, {:data, chunk}} ->
        case StreamHandler.decode_chunk(chunk, state) do
          {:ok, new_events, new_state} ->
            # Call callback for each event
            Enum.each(new_events, callback)
            do_collect_stream(stream_ref, callback, new_state, events ++ new_events, model)
        end

      {:stream, ^stream_ref, :done} ->
        result = StreamHandler.stream_to_result(events)
        {:ok, Map.put(result, :model, model)}

      {:stream, ^stream_ref, {:error, reason}} ->
        {:error, normalize_error(reason)}
    after
      30_000 ->
        {:error, :stream_timeout}
    end
  end

  defp normalize_response(response, model) when is_map(response) do
    content = get_in(response, ["choices", Access.at(0), "message", "content"]) || ""
    finish_reason = get_in(response, ["choices", Access.at(0), "finish_reason"])
    id = response["id"]

    %{
      content: content,
      finish_reason: finish_reason,
      id: id,
      model: model
    }
  end

  defp normalize_response(content, model) when is_binary(content) do
    %{
      content: content,
      finish_reason: "stop",
      id: nil,
      model: model
    }
  end

  defp normalize_error(%{status: status}) when status in [429, 529] do
    :rate_limited
  end

  defp normalize_error(%{status: status}) when status in [500, 502, 503, 504] do
    :service_unavailable
  end

  defp normalize_error(%{status: 401}), do: :invalid_api_key
  defp normalize_error(%{status: 400}), do: :invalid_request
  defp normalize_error(%{status: 403}), do: :authorization_failed

  defp normalize_error(:timeout), do: :timeout
  defp normalize_error(:connect_timeout), do: :timeout
  defp normalize_error(:econnrefused), do: :network_error

  defp normalize_error(reason), do: reason
end
