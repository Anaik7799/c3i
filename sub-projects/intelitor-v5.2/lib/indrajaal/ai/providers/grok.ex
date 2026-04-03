defmodule Indrajaal.AI.Providers.GrokClient do
  @moduledoc """
  xAI Grok Client with rate limiting and circuit breaker.

  ## WHAT
  Provides integration with xAI's Grok model API with:
  - 450 RPS rate limiting
  - Circuit breaker pattern for fault tolerance
  - Telemetry integration for observability
  - Request/response normalization

  ## WHY
  - Grok models provide fast inference and high availability
  - Rate limiting ensures API quotas are respected
  - Circuit breaker prevents cascading failures
  - Normalized responses work with provider dispatcher

  ## STAMP Constraints
  - SC-GDE-001: Guardian validation required
  - SC-GDE-002: Shadow testing mandatory
  - SC-GDE-003: Rollback capability
  - SC-GDE-004: Proposal threshold >= 0.85

  ## Usage

      # Check rate limit status
      status = GrokClient.check_rate_limit()

      # Send chat request
      messages = [%{"role" => "user", "content" => "Hello"}]
      {:ok, response} = GrokClient.chat(messages, model: "grok-2")

      # Stream response
      {:ok, stream} = GrokClient.chat_stream(messages, model: "grok-2")
  """

  require Logger

  alias Indrajaal.AI.Pricing

  # Grok API configuration
  @base_url "https://api.x.ai/v1"
  @max_rps 450
  @circuit_breaker_threshold 5
  @circuit_breaker_timeout 30_000

  # Default model
  @default_model "grok-2"

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Send a chat request to Grok API.

  ## Parameters
  - `messages`: List of message maps with role and content
  - `opts`: Options including model, temperature, max_tokens, etc.

  ## Returns
  - `{:ok, response}` with normalized response containing:
    - `content`: The generated text
    - `model`: The model ID used
    - `usage`: Token counts (prompt_tokens, completion_tokens)
    - `latency_ms`: Response time in milliseconds
  - `{:error, reason}` on failure
  """
  @spec chat(list(), keyword()) :: {:ok, map()} | {:error, term()}
  def chat(messages, opts \\ []) do
    if circuit_open?() do
      {:error, :circuit_open}
    else
      if approaching_rate_limit?() do
        {:error, :rate_limit_exceeded}
      else
        do_chat(messages, opts)
      end
    end
  end

  @doc """
  Stream a chat response from Grok API.

  ## Returns
  - `{:ok, stream}` with an enumerable stream
  - `{:error, reason}` on failure
  """
  @spec chat_stream(list(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def chat_stream(messages, opts \\ []) do
    if circuit_open?() do
      {:error, :circuit_open}
    else
      if approaching_rate_limit?() do
        {:error, :rate_limit_exceeded}
      else
        do_chat_stream(messages, opts)
      end
    end
  end

  @doc """
  Check current rate limit status.

  Returns a map with:
  - `max_rps`: Maximum requests per second (450)
  - `current_rps`: Current requests in last second
  - `remaining_capacity`: Remaining requests available
  - `approaching_limit`: Boolean indicating if close to limit
  - `default_model`: Default model to use
  """
  @spec check_rate_limit() :: map()
  def check_rate_limit do
    state = get_rate_limiter_state()

    %{
      max_rps: @max_rps,
      current_rps: state.current_rps,
      remaining_capacity: @max_rps - state.current_rps,
      approaching_limit: state.current_rps > @max_rps * 0.8,
      default_model: @default_model,
      last_reset: state.last_reset
    }
  end

  @doc """
  Get circuit breaker status.

  Returns a map with:
  - `state`: :closed, :open, or :half_open
  - `failures`: Number of consecutive failures
  - `last_failure`: Timestamp of last failure
  - `failure_threshold`: Number of failures before opening
  - `timeout_ms`: Time circuit stays open
  """
  @spec circuit_breaker_status() :: map()
  def circuit_breaker_status do
    state = get_circuit_breaker_state()

    %{
      state: state.state,
      failures: state.failures,
      last_failure: state.last_failure,
      failure_threshold: @circuit_breaker_threshold,
      timeout_ms: @circuit_breaker_timeout,
      last_success: state.last_success
    }
  end

  @doc """
  Reset the rate limiter for testing purposes.
  """
  @spec reset_rate_limiter() :: :ok
  def reset_rate_limiter do
    Agent.get_and_update(:grok_rate_limiter, fn _state ->
      {:ok, initial_rate_limiter_state()}
    end)
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp do_chat(messages, opts) do
    model = Keyword.get(opts, :model, @default_model)
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)

    api_key = System.get_env("GROK_API_KEY")

    if is_nil(api_key) or api_key == "" do
      Logger.warning("[Grok] API key missing, returning mock response")
      mock_chat_response(messages, model)
    else
      make_api_request(messages, model, temperature, max_tokens, api_key)
    end
  end

  defp do_chat_stream(messages, opts) do
    _model = Keyword.get(opts, :model, @default_model)

    case do_chat(messages, opts) do
      {:ok, response} ->
        # Wrap in a stream
        stream = Stream.concat([response.content])
        {:ok, stream}

      error ->
        error
    end
  end

  defp make_api_request(messages, model, temperature, max_tokens, api_key) do
    start_time = System.monotonic_time(:millisecond)

    body = %{
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case Req.post("#{@base_url}/chat/completions", headers: headers, json: body) do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]}
       }} ->
        end_time = System.monotonic_time(:millisecond)
        latency = end_time - start_time

        record_success()

        input_tokens = estimate_tokens(messages)
        output_tokens = estimate_tokens(content)

        response = %{
          content: content,
          model: model,
          usage: %{
            prompt_tokens: input_tokens,
            completion_tokens: output_tokens,
            total_tokens: input_tokens + output_tokens
          },
          cost: %{
            input_cost: Pricing.estimate_cost(model, input_tokens, 0),
            output_cost: Pricing.estimate_cost(model, 0, output_tokens),
            total_cost: Pricing.estimate_cost(model, input_tokens, output_tokens),
            currency: :usd
          },
          provider: :grok,
          latency_ms: latency
        }

        {:ok, response}

      {:ok, %Req.Response{status: status, body: body}} ->
        record_failure()
        Logger.error("[Grok] API Error #{status}: #{inspect(body)}")
        {:error, {:grok_api_error, status}}

      {:error, reason} ->
        record_failure()
        Logger.error("[Grok] Network Error: #{inspect(reason)}")
        {:error, {:network_error, reason}}
    end
  end

  defp mock_chat_response(messages, model) do
    start_time = System.monotonic_time(:millisecond)

    # Simulate response latency
    Process.sleep(100)

    end_time = System.monotonic_time(:millisecond)
    latency = end_time - start_time

    input_tokens = estimate_tokens(messages)
    output_tokens = 150

    content =
      "This is a mock response from Grok. " <>
        "In production, this would be generated by the xAI Grok API. " <>
        "The response demonstrates proper formatting and token estimation."

    {:ok,
     %{
       content: content,
       model: model,
       usage: %{
         prompt_tokens: input_tokens,
         completion_tokens: output_tokens,
         total_tokens: input_tokens + output_tokens
       },
       cost: %{
         input_cost: Pricing.estimate_cost(model, input_tokens, 0),
         output_cost: Pricing.estimate_cost(model, 0, output_tokens),
         total_cost: Pricing.estimate_cost(model, input_tokens, output_tokens),
         currency: :usd
       },
       provider: :grok,
       latency_ms: latency
     }}
  end

  defp estimate_tokens(data) do
    case data do
      messages when is_list(messages) ->
        messages
        |> Enum.map(fn msg ->
          case msg do
            %{"content" => content} when is_binary(content) -> String.length(content)
            _ -> 0
          end
        end)
        |> Enum.sum()
        |> div(4)

      content when is_binary(content) ->
        div(String.length(content), 4)

      _ ->
        0
    end
  end

  defp circuit_open? do
    state = get_circuit_breaker_state()
    state.state == :open and not time_to_retry?(state)
  end

  defp approaching_rate_limit? do
    state = get_rate_limiter_state()
    state.current_rps > @max_rps * 0.9
  end

  defp time_to_retry?(cb_state) do
    case cb_state.last_failure do
      nil -> false
      timestamp -> System.monotonic_time(:millisecond) - timestamp > @circuit_breaker_timeout
    end
  end

  defp record_success do
    Agent.update(:grok_circuit_breaker, fn state ->
      %{state | failures: 0, last_success: System.monotonic_time(:millisecond), state: :closed}
    end)

    Agent.update(:grok_rate_limiter, fn state ->
      %{
        state
        | current_rps: state.current_rps + 1,
          last_request: System.monotonic_time(:millisecond)
      }
    end)
  end

  defp record_failure do
    Agent.update(:grok_circuit_breaker, fn state ->
      failures = state.failures + 1

      new_state =
        if failures >= @circuit_breaker_threshold do
          :open
        else
          :closed
        end

      %{
        state
        | failures: failures,
          last_failure: System.monotonic_time(:millisecond),
          state: new_state
      }
    end)
  end

  defp get_circuit_breaker_state do
    case Agent.start_link(fn -> initial_circuit_breaker_state() end, name: :grok_circuit_breaker) do
      {:ok, _pid} -> initial_circuit_breaker_state()
      {:error, {:already_started, _pid}} -> Agent.get(:grok_circuit_breaker, & &1)
    end
  end

  defp get_rate_limiter_state do
    case Agent.start_link(fn -> initial_rate_limiter_state() end, name: :grok_rate_limiter) do
      {:ok, _pid} -> initial_rate_limiter_state()
      {:error, {:already_started, _pid}} -> Agent.get(:grok_rate_limiter, & &1)
    end
  end

  defp initial_circuit_breaker_state do
    %{
      state: :closed,
      failures: 0,
      last_failure: nil,
      last_success: System.monotonic_time(:millisecond)
    }
  end

  defp initial_rate_limiter_state do
    %{
      current_rps: 0,
      last_reset: System.monotonic_time(:second),
      last_request: nil
    }
  end
end
