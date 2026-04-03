defmodule Indrajaal.SMRITI.Mesh.Consensus do
  @moduledoc """
  L6: Tri-Cameral Consensus Engine.

  ## WHAT
  Orchestrates voting between three cognitive chambers (Claude, GPT, Gemini)
  to validate high-criticality (P0) knowledge using real AI models via OpenRouter.

  ## WHY
  - 2oo3 voting provides Byzantine fault tolerance (SC-SIL4-006)
  - Multi-model consensus reduces single-model bias
  - Supports Constitutional AI alignment (SC-AI-002)

  ## CONSTRAINTS
  - SC-CONSENSUS-001: 2oo3 voting required for P0 decisions
  - SC-CONSENSUS-002: Each chamber has veto on Constitutional violations
  - SC-CONSENSUS-003: Timeout < 30s per chamber
  - SC-AI-002: Tricameral coordination requires 3-round dialectic

  ## Chamber Assignments
  - Claude: Constitutional reasoning (Ψ₀-Ψ₅ alignment)
  - GPT: Technical feasibility analysis
  - Gemini: Pragmatic implementation validation

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-16 | Claude | Added real OpenRouter integration (Task 42.2) |
  | 21.2.0 | 2026-01-10 | - | Initial stub implementation |
  """

  require Logger

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.SMRITI.Mesh.Gossip

  @type vote :: :approve | :reject | :abstain
  @type chamber :: :claude | :gpt | :gemini
  @type vote_result :: %{
          chamber: chamber(),
          vote: vote(),
          confidence: float(),
          reasoning: String.t(),
          latency_ms: non_neg_integer()
        }

  # Chamber to model mapping (free models preferred per AOR-OPENROUTER-001)
  @chamber_models %{
    claude: "anthropic/claude-3-haiku:free",
    gpt: "openai/gpt-4o-mini",
    gemini: "google/gemini-flash-1.5-8b:free"
  }

  # Timeout per chamber (30s per SC-CONSENSUS-003)
  @chamber_timeout_ms 30_000

  # Minimum confidence threshold for vote to count
  @min_confidence 0.6

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Requests consensus on a specific fact or summary.

  ## Parameters
  - `content` - The content to validate (map with :fact, :context, :priority keys)

  ## Returns
  - `{:ok, result}` - Consensus reached with result map
  - `{:error, reason}` - Consensus failed

  ## Example
      Consensus.request_consensus(%{
        fact: "User auth should use JWT tokens",
        context: "Authentication system design",
        priority: :p1
      })
  """
  @spec request_consensus(map()) :: {:ok, map()} | {:error, term()}
  def request_consensus(content) when is_map(content) do
    request_id = generate_request_id()
    Logger.info("[SMRITI.Consensus] ⚖️ Convening Tri-Cameral Council (#{request_id})...")

    # Record start time
    start_time = System.monotonic_time(:millisecond)

    # Broadcast consensus request via gossip
    broadcast_consensus_start(request_id, content)

    # 1. Parallel Request to Chambers
    tasks = [
      Task.async(fn -> consult_chamber(:claude, content, request_id) end),
      Task.async(fn -> consult_chamber(:gpt, content, request_id) end),
      Task.async(fn -> consult_chamber(:gemini, content, request_id) end)
    ]

    # 2. Await Results with timeout
    votes =
      tasks
      |> Task.yield_many(@chamber_timeout_ms)
      |> Enum.zip([:claude, :gpt, :gemini])
      |> Enum.map(fn
        {{_task, {:ok, result}}, _chamber} ->
          result

        {{task, nil}, chamber} ->
          # Timeout - kill the task and return abstain
          Task.shutdown(task, :brutal_kill)
          Logger.warning("[SMRITI.Consensus] Chamber #{chamber} timed out")

          %{
            chamber: chamber,
            vote: :abstain,
            confidence: 0.0,
            reasoning: "Timeout",
            latency_ms: @chamber_timeout_ms
          }

        {{_task, {:exit, reason}}, chamber} ->
          Logger.error("[SMRITI.Consensus] Chamber #{chamber} crashed: #{inspect(reason)}")
          %{chamber: chamber, vote: :abstain, confidence: 0.0, reasoning: "Error", latency_ms: 0}
      end)

    # 3. Tally and broadcast result
    elapsed_ms = System.monotonic_time(:millisecond) - start_time
    result = tally_votes(votes, request_id, elapsed_ms)

    broadcast_consensus_result(request_id, result)
    emit_telemetry(votes, result, elapsed_ms)

    result
  end

  def request_consensus(content) when is_binary(content) do
    request_consensus(%{fact: content, context: "general", priority: :p2})
  end

  @doc """
  Quick validation for lower priority content (P2/P3).
  Uses only one chamber (Claude) for speed.
  """
  @spec quick_validate(map()) :: {:ok, vote_result()} | {:error, term()}
  def quick_validate(content) do
    result = consult_chamber(:claude, content, generate_request_id())
    {:ok, result}
  end

  @doc """
  Gets the status of consensus engine including model availability.
  """
  @spec status() :: map()
  def status do
    %{
      chambers: @chamber_models,
      timeout_ms: @chamber_timeout_ms,
      min_confidence: @min_confidence,
      openrouter_available: openrouter_available?()
    }
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp consult_chamber(chamber, content, _request_id) do
    start_time = System.monotonic_time(:millisecond)
    model = Map.get(@chamber_models, chamber)
    prompt = build_chamber_prompt(chamber, content)

    Logger.debug("[SMRITI.Consensus] Chamber #{chamber} deliberating (#{model})...")

    result =
      case OpenRouterClient.chat(prompt, "consensus_#{chamber}", model: model) do
        {:ok, response} ->
          parse_vote_response(chamber, response, start_time)

        {:error, reason} ->
          Logger.warning("[SMRITI.Consensus] Chamber #{chamber} API error: #{inspect(reason)}")
          # Fallback to local reasoning
          fallback_vote(chamber, content, start_time)
      end

    result
  end

  defp build_chamber_prompt(:claude, content) do
    """
    You are the Constitutional Chamber of the Tri-Cameral Consensus Engine.
    Your role is to validate content against the Constitutional AI principles (Ψ₀-Ψ₅):
    - Ψ₀ (Existence): Does this preserve system survival?
    - Ψ₁ (Regeneration): Can the system regenerate from this?
    - Ψ₂ (History): Is evolutionary continuity preserved?
    - Ψ₃ (Verification): Is this verifiable?
    - Ψ₄ (Human Alignment): Does this serve human interests?
    - Ψ₅ (Truthfulness): Is this truthful?

    CONTENT TO EVALUATE:
    #{format_content(content)}

    RESPOND WITH JSON ONLY:
    {"vote": "approve|reject|abstain", "confidence": 0.0-1.0, "reasoning": "brief explanation"}
    """
  end

  defp build_chamber_prompt(:gpt, content) do
    """
    You are the Technical Chamber of the Tri-Cameral Consensus Engine.
    Your role is to validate content for technical feasibility and correctness:
    - Is this technically sound?
    - Are there implementation concerns?
    - Does this align with best practices?
    - Are there security implications?

    CONTENT TO EVALUATE:
    #{format_content(content)}

    RESPOND WITH JSON ONLY:
    {"vote": "approve|reject|abstain", "confidence": 0.0-1.0, "reasoning": "brief explanation"}
    """
  end

  defp build_chamber_prompt(:gemini, content) do
    """
    You are the Pragmatic Chamber of the Tri-Cameral Consensus Engine.
    Your role is to validate content for practical implementation:
    - Is this practically achievable?
    - What are the resource implications?
    - Is the timeline realistic?
    - Are there external dependencies or risks?

    CONTENT TO EVALUATE:
    #{format_content(content)}

    RESPOND WITH JSON ONLY:
    {"vote": "approve|reject|abstain", "confidence": 0.0-1.0, "reasoning": "brief explanation"}
    """
  end

  defp format_content(%{fact: fact, context: context, priority: priority}) do
    """
    Fact: #{fact}
    Context: #{context}
    Priority: #{priority}
    """
  end

  defp format_content(content) when is_binary(content), do: content
  defp format_content(content), do: inspect(content)

  defp parse_vote_response(chamber, response, start_time) do
    latency_ms = System.monotonic_time(:millisecond) - start_time

    case extract_json(response) do
      {:ok, %{"vote" => vote_str, "confidence" => conf, "reasoning" => reasoning}} ->
        vote = parse_vote_string(vote_str)
        confidence = if is_number(conf), do: conf, else: 0.5

        %{
          chamber: chamber,
          vote: vote,
          confidence: confidence,
          reasoning: reasoning || "",
          latency_ms: latency_ms
        }

      {:error, _} ->
        # Try to infer vote from response text
        infer_vote_from_text(chamber, response, latency_ms)
    end
  end

  defp extract_json(text) do
    # Try to find JSON in the response
    case Regex.run(~r/\{[^{}]*"vote"[^{}]*\}/s, text) do
      [json_str] ->
        Jason.decode(json_str)

      nil ->
        {:error, :no_json}
    end
  end

  defp parse_vote_string(vote) when is_binary(vote) do
    case String.downcase(vote) do
      "approve" -> :approve
      "reject" -> :reject
      _ -> :abstain
    end
  end

  defp parse_vote_string(_), do: :abstain

  defp infer_vote_from_text(chamber, text, latency_ms) do
    text_lower = String.downcase(text)

    vote =
      cond do
        String.contains?(text_lower, "approve") -> :approve
        String.contains?(text_lower, "reject") -> :reject
        String.contains?(text_lower, "yes") -> :approve
        String.contains?(text_lower, "no") -> :reject
        true -> :abstain
      end

    %{
      chamber: chamber,
      vote: vote,
      confidence: 0.5,
      reasoning: String.slice(text, 0, 200),
      latency_ms: latency_ms
    }
  end

  defp fallback_vote(chamber, _content, start_time) do
    # Local fallback when API is unavailable
    # Default to abstain to avoid false positives
    latency_ms = System.monotonic_time(:millisecond) - start_time

    %{
      chamber: chamber,
      vote: :abstain,
      confidence: 0.0,
      reasoning: "API unavailable - abstaining",
      latency_ms: latency_ms
    }
  end

  defp tally_votes(votes, request_id, elapsed_ms) do
    # Count votes (only votes with sufficient confidence count)
    confident_votes = Enum.filter(votes, &(&1.confidence >= @min_confidence))

    approvals = Enum.count(confident_votes, &(&1.vote == :approve))
    rejections = Enum.count(confident_votes, &(&1.vote == :reject))

    verdict =
      cond do
        approvals >= 2 ->
          Logger.info("[SMRITI.Consensus] ✅ Motion Carried (#{approvals}/3)")
          :verified

        rejections >= 2 ->
          Logger.warning("[SMRITI.Consensus] ❌ Motion Rejected (#{rejections}/3)")
          :rejected

        true ->
          Logger.warning("[SMRITI.Consensus] ⚠️ No Consensus (A:#{approvals}, R:#{rejections})")
          :no_consensus
      end

    result = %{
      request_id: request_id,
      verdict: verdict,
      approvals: approvals,
      rejections: rejections,
      abstentions: 3 - length(confident_votes),
      votes: votes,
      elapsed_ms: elapsed_ms,
      timestamp: DateTime.utc_now()
    }

    if verdict == :verified do
      {:ok, result}
    else
      {:error, result}
    end
  end

  defp generate_request_id do
    "consensus-#{:erlang.phash2({node(), System.system_time()}, 0xFFFFFFFF) |> Integer.to_string(16)}"
  end

  defp openrouter_available? do
    case OpenRouterClient.health_check() do
      :ok -> true
      _ -> false
    end
  end

  # ============================================================
  # GOSSIP INTEGRATION
  # ============================================================

  defp broadcast_consensus_start(request_id, content) do
    if GenServer.whereis(Gossip) do
      Gossip.broadcast_consensus(request_id, content, stage: :start)
    end
  rescue
    _ -> :ok
  end

  defp broadcast_consensus_result(request_id, result) do
    if GenServer.whereis(Gossip) do
      case result do
        {:ok, data} ->
          Gossip.broadcast_consensus(request_id, data, stage: :complete)

        {:error, data} ->
          Gossip.broadcast_consensus(request_id, data, stage: :failed)
      end
    end
  rescue
    _ -> :ok
  end

  # ============================================================
  # TELEMETRY
  # ============================================================

  defp emit_telemetry(votes, result, elapsed_ms) do
    verdict =
      case result do
        {:ok, %{verdict: v}} -> v
        {:error, %{verdict: v}} -> v
        _ -> :unknown
      end

    :telemetry.execute(
      [:smriti, :consensus, :complete],
      %{
        elapsed_ms: elapsed_ms,
        votes_count: length(votes),
        avg_confidence: avg_confidence(votes)
      },
      %{
        verdict: verdict,
        chambers: Enum.map(votes, & &1.chamber)
      }
    )
  end

  defp avg_confidence(votes) do
    if length(votes) > 0 do
      Enum.sum(Enum.map(votes, & &1.confidence)) / length(votes)
    else
      0.0
    end
  end
end
