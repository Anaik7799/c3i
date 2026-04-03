defmodule Indrajaal.AI.Simplex.SimplexController do
  @moduledoc """
  Central Simplex controller for all AI operations.

  ## Simplex Architecture

  Every AI operation follows this mandatory control flow:

      Request → Guardian → Graph → Provider → Response

  ## STAMP Constraints

  - SC-NEURO-001: All AI routes MUST pass through Guardian
  - SC-NEURO-002: No bypass of Simplex
  - SC-GUARD-001: Guardian MUST use Envelope for constraints
  - SC-GUARD-002: Fail closed on Guardian unavailable
  - SC-GVF-001: Graph verification after Guardian
  - SC-AI-001: Request ID for all operations
  - SC-AI-002: Telemetry for all outcomes

  ## Usage

      # Basic execution
      {:ok, result} = SimplexController.execute(%{
        prompt: "Analyze this code",
        intent: :analyze,
        source: :cortex
      })

      # With explicit model
      {:ok, result} = SimplexController.execute(%{
        prompt: "Generate code",
        intent: :synthesize,
        model: "anthropic/claude-3.5-sonnet"
      })
  """

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.AI.Simplex.{GraphVerification, TelemetryFlow}
  alias Indrajaal.AI.{IntentRouter, CostMonitor, ProviderDispatcher}
  alias Indrajaal.AI.Security.ContentInspector

  require Logger

  @type request :: %{
          optional(:action) => atom(),
          optional(:source) => atom(),
          optional(:intent) => atom(),
          optional(:model) => String.t(),
          optional(:provider) => atom(),
          optional(:prompt) => String.t(),
          optional(:messages) => list(map()),
          optional(:temperature) => float(),
          optional(:max_tokens) => non_neg_integer()
        }

  @type result :: %{
          content: String.t(),
          model: String.t(),
          usage: map(),
          cost: map(),
          request_id: String.t()
        }

  @doc """
  Execute an AI operation through the full Simplex pipeline.

  ## Steps

  1. Build Guardian proposal from request
  2. Content inspection (security patterns)
  3. Guardian pre-flight check
  4. Graph verification
  5. Provider dispatch
  6. Response processing with telemetry

  ## Returns

  - `{:ok, result}` on success
  - `{:error, {:guardian_veto, reason, fallback}}` on safety rejection
  - `{:error, {:content_blocked, reason}}` on content inspection failure
  - `{:error, {:graph_failed, reason}}` on verification failure
  - `{:error, {:provider_failed, reason}}` on API failure
  """
  @spec execute(request(), keyword()) :: {:ok, result()} | {:error, term()}
  def execute(request, opts \\ []) do
    request_id = generate_request_id()
    start_time = System.monotonic_time(:millisecond)

    :telemetry.span([:ai, :simplex, :execute], %{request_id: request_id}, fn ->
      with {:ok, proposal} <- build_proposal_internal(request, request_id, opts),
           {:ok, _clean} <- content_inspection(proposal),
           {:ok, _approved} <- guardian_pre_flight(proposal),
           {:ok, _verified} <- graph_verification(proposal),
           {:ok, result} <- provider_dispatch(proposal, opts) do
        end_time = System.monotonic_time(:millisecond)
        latency = end_time - start_time

        # Record cost and emit telemetry
        record_usage(proposal, result)
        emit_success_telemetry(request_id, result, latency)

        final_result =
          Map.merge(result, %{
            request_id: request_id,
            latency_ms: latency
          })

        {{:ok, final_result}, %{request_id: request_id, status: :success}}
      else
        {:error, reason} = error ->
          end_time = System.monotonic_time(:millisecond)
          latency = end_time - start_time
          emit_failure_telemetry(request_id, reason, latency)
          {error, %{request_id: request_id, status: :failed, reason: reason}}
      end
    end)
  end

  @doc """
  Execute with streaming support.

  Similar to execute/2 but returns a stream for real-time responses.
  """
  @spec execute_stream(request(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def execute_stream(request, opts \\ []) do
    request_id = generate_request_id()

    with {:ok, proposal} <- build_proposal_internal(request, request_id, opts),
         {:ok, _clean} <- content_inspection(proposal),
         {:ok, _approved} <- guardian_pre_flight(proposal),
         {:ok, _verified} <- graph_verification(proposal) do
      stream_opts = Keyword.put(opts, :stream, true)
      ProviderDispatcher.chat_stream(proposal.provider, proposal, stream_opts)
    end
  end

  # ---------------------------------------------------------------------------
  # Public API for testing and composition
  # ---------------------------------------------------------------------------

  @doc """
  Build a proposal from a request (public API for testing).
  """
  @spec build_proposal(map()) :: map()
  def build_proposal(request) do
    prompt = extract_prompt(request)
    intent = Map.get(request, :intent) || infer_intent(prompt)
    {model, routing_config} = resolve_model_and_routing(request, intent, [])

    %{
      action: Map.get(request, :action, :ai_request),
      prompt: prompt,
      intent: intent,
      model: model,
      estimated_input_tokens: estimate_tokens(prompt),
      estimated_output_tokens: routing_config[:max_tokens] || 1000,
      estimated_cost_usd: estimate_cost(model, prompt),
      temperature: routing_config[:temperature] || 0.7
    }
  end

  @doc """
  Estimate token count for text.
  """
  @spec estimate_tokens(String.t() | nil) :: non_neg_integer()
  def estimate_tokens(nil), do: 0
  def estimate_tokens(text) when is_binary(text), do: max(0, div(String.length(text), 4))
  def estimate_tokens(_), do: 0

  @doc """
  Infer intent from prompt content.
  """
  @spec infer_intent(String.t() | nil) :: atom()
  def infer_intent(nil), do: :triage
  def infer_intent(""), do: :triage

  def infer_intent(prompt) when is_binary(prompt) do
    prompt_lower = String.downcase(prompt)

    cond do
      String.contains?(prompt_lower, [
        "reason",
        "implications",
        "consequences",
        "why",
        "explain why"
      ]) ->
        :reason

      String.contains?(prompt_lower, [
        "analyze",
        "review",
        "examine",
        "inspect",
        "debug",
        "identify"
      ]) ->
        :analyze

      String.contains?(prompt_lower, ["generate", "create", "build", "synthesize", "produce"]) ->
        :synthesize

      String.contains?(prompt_lower, ["validate", "verify", "check", "confirm", "ensure"]) ->
        :validate

      String.contains?(prompt_lower, ["write", "code", "implement", "function", "module"]) ->
        :code

      true ->
        :triage
    end
  end

  @doc """
  Check if proposal confidence meets threshold.
  """
  @spec check_confidence(map()) :: :ok | {:error, {:low_confidence, float()}}
  def check_confidence(%{confidence: confidence}) when confidence >= 0.5, do: :ok
  def check_confidence(%{confidence: confidence}), do: {:error, {:low_confidence, confidence}}
  def check_confidence(_), do: :ok

  # ---------------------------------------------------------------------------
  # Step 1: Build Guardian proposal
  # ---------------------------------------------------------------------------

  defp build_proposal_internal(request, request_id, opts) do
    prompt = extract_prompt(request)
    intent = Map.get(request, :intent, :synthesize)

    # Use IntentRouter for model selection if not explicitly specified
    {model, routing_config} = resolve_model_and_routing(request, intent, opts)

    proposal = %{
      # Core Identity
      action: Map.get(request, :action, :ai_request),
      source: Map.get(request, :source, :unknown),
      request_id: request_id,
      timestamp: DateTime.utc_now(),

      # AI Request Details
      intent: intent,
      model: model,
      provider: Map.get(request, :provider, :openrouter),

      # Content (Sanitized)
      prompt: prompt,
      prompt_preview: String.slice(prompt || "", 0..500),
      prompt_length: String.length(prompt || ""),
      messages: Map.get(request, :messages, build_messages(prompt)),
      temperature: routing_config[:temperature] || Keyword.get(opts, :temperature, 0.7),
      max_tokens: routing_config[:max_tokens] || Keyword.get(opts, :max_tokens),

      # Routing
      routing_headers: routing_config[:routing_headers] || %{},

      # Cost Estimation
      estimated_input_tokens: estimate_tokens(prompt),
      estimated_output_tokens: routing_config[:max_tokens] || 1000,
      estimated_cost_usd: estimate_cost(model, prompt),

      # Actor Context
      actor_id: Keyword.get(opts, :actor_id),
      tenant_id: Keyword.get(opts, :tenant_id)
    }

    {:ok, proposal}
  end

  defp resolve_model_and_routing(request, intent, opts) do
    case Map.get(request, :model) do
      nil ->
        # Use IntentRouter for intelligent model selection
        config = IntentRouter.route(intent, opts)
        {config.model, config}

      model when is_binary(model) ->
        # Explicit model, use defaults
        {model, %{temperature: 0.7, max_tokens: 4000}}

      tier when is_atom(tier) ->
        # Tier-based selection
        model = IntentRouter.select_model_for_tier(tier)
        {model, %{temperature: 0.7, max_tokens: 4000}}
    end
  end

  # ---------------------------------------------------------------------------
  # Step 2: Content Inspection
  # ---------------------------------------------------------------------------

  defp content_inspection(proposal) do
    case ContentInspector.inspect_prompt(proposal.prompt || "") do
      {:ok, :clean} ->
        {:ok, :clean}

      {:error, {:forbidden, reason}} ->
        Logger.warning("[Simplex] Content blocked: #{reason}")
        {:error, {:content_blocked, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Step 3: Guardian pre-flight check
  # ---------------------------------------------------------------------------

  defp guardian_pre_flight(proposal) do
    guardian_proposal = %{
      action: proposal.action,
      source: proposal.source,
      model: proposal.model,
      prompt_preview: proposal.prompt_preview,
      prompt_length: proposal.prompt_length,
      temperature: proposal.temperature,
      estimated_cost_usd: proposal.estimated_cost_usd,
      timestamp: proposal.timestamp
    }

    case Guardian.validate_proposal(guardian_proposal) do
      {:ok, approved} ->
        Logger.debug("[Simplex] Guardian approved: #{proposal.request_id}")
        {:ok, approved}

      {:veto, reason, fallback} ->
        Logger.warning("[Simplex] Guardian vetoed: #{inspect(reason)}")
        {:error, {:guardian_veto, reason, fallback}}
    end
  rescue
    error ->
      # Fail closed: deny if Guardian unavailable (SC-GUARD-002)
      Logger.error("[Simplex] Guardian unavailable: #{inspect(error)}")
      {:error, {:guardian_unavailable, error}}
  end

  # ---------------------------------------------------------------------------
  # Step 4: Graph verification
  # ---------------------------------------------------------------------------

  defp graph_verification(proposal) do
    routing_proposal = %{
      source: proposal.source,
      target: proposal.provider,
      model: proposal.model,
      confidence: 1.0,
      guardian_approved: true
    }

    GraphVerification.validate_routing_proposal(routing_proposal)
  end

  # ---------------------------------------------------------------------------
  # Step 5: Provider dispatch
  # ---------------------------------------------------------------------------

  defp provider_dispatch(proposal, opts) do
    case ProviderDispatcher.chat(proposal.provider, proposal, opts) do
      {:ok, content} when is_binary(content) ->
        {:ok,
         %{
           content: content,
           model: proposal.model,
           usage: %{total_tokens: estimate_tokens(content) + proposal.estimated_input_tokens},
           cost: %{total_cost: proposal.estimated_cost_usd}
         }}

      {:ok, result} when is_map(result) ->
        {:ok, result}

      {:error, reason} ->
        {:error, {:provider_failed, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp generate_request_id do
    "ai-#{8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)}"
  end

  defp extract_prompt(%{prompt: prompt}) when is_binary(prompt), do: prompt

  defp extract_prompt(%{messages: [_ | _] = messages}) do
    messages
    |> Enum.filter(&(&1["role"] == "user" or &1[:role] == :user))
    |> Enum.map_join("\n", &(&1["content"] || &1[:content]))
  end

  defp extract_prompt(_), do: ""

  defp build_messages(nil), do: []
  defp build_messages(""), do: []

  defp build_messages(prompt) when is_binary(prompt) do
    [%{"role" => "user", "content" => prompt}]
  end

  # estimate_tokens/1 is defined as public above

  defp estimate_cost(model, prompt) do
    tokens = estimate_tokens(prompt)
    Indrajaal.AI.Pricing.estimate_cost(model, tokens, 1000)
  end

  defp record_usage(proposal, result) do
    tokens = get_in(result, [:usage, :total_tokens]) || 0
    cost = get_in(result, [:cost, :total_cost]) || 0.0

    CostMonitor.record_usage(proposal.model, proposal.source, cost, tokens)
  end

  defp emit_success_telemetry(request_id, result, latency) do
    TelemetryFlow.emit_ai_event(
      [:simplex, :success],
      %{
        tokens: get_in(result, [:usage, :total_tokens]) || 0,
        cost: get_in(result, [:cost, :total_cost]) || 0.0,
        latency_ms: latency
      },
      %{
        request_id: request_id,
        model: result[:model]
      }
    )
  end

  defp emit_failure_telemetry(request_id, reason, latency) do
    TelemetryFlow.emit_ai_event(
      [:simplex, :failure],
      %{
        latency_ms: latency
      },
      %{
        request_id: request_id,
        reason: inspect(reason)
      }
    )
  end
end
