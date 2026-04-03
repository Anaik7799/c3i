defmodule Indrajaal.AI.OpenRouterClient do
  @moduledoc """
  OpenRouter Client for interfacing with External LLMs (The Cortex).

  **SOPv5.11 Compliance:**
  - **SC-NEURO-002**: Uses high-latency path for cognitive tasks.
  - **SC-SEC-042**: API Key must be loaded from environment at runtime.
  - **SC-PRIV-001**: ZDR (Zero Data Retention) enabled by default.

  **Rate Limiting (SC-API-002, AOR-OPENROUTER-002):**
  - ETS-backed token bucket with 60-second windows
  - Tracks RPM (200 max) and TPM (40000 max) for free tier
  - Returns {:ok, :allowed} or {:error, :rate_limited}
  - Supports exponential backoff on 429 responses
  """
  require Logger

  @base_url "https://openrouter.ai/api/v1"
  @default_model "anthropic/claude-3-sonnet"

  # Rate limit defaults (free tier per AOR-OPENROUTER-001)
  @default_rpm_limit 200
  @default_tpm_limit 40_000
  @rate_limit_table :openrouter_rate_limits
  # 60 seconds in milliseconds
  @window_duration 60_000

  @type chat_opts :: [
          model: String.t(),
          temperature: float(),
          max_tokens: integer(),
          stream: boolean(),
          zdr: boolean()
        ]

  @type rate_limit_state :: %{
          window_start: integer(),
          request_count: integer(),
          token_count: integer(),
          backoff_until: integer() | nil
        }

  def init do
    if :ets.whereis(@rate_limit_table) == :undefined do
      :ets.new(@rate_limit_table, [:set, :public, :named_table])
      Logger.info("[OpenRouter] Rate limit table initialized")
    end

    init_window()
  end

  defp init_window do
    now = System.monotonic_time(:millisecond)

    :ets.insert(
      @rate_limit_table,
      {:window,
       %{
         window_start: now,
         request_count: 0,
         token_count: 0,
         backoff_until: nil
       }}
    )
  end

  @doc """
  Sends a prompt to the OpenRouter API.

  ## Parameters
  - prompt: The user query or system signal description.
  - context: A string identifier for the system context (e.g., "system_observer").
  - opts: Optional parameters.

  ## Returns
  - `{:ok, response_text}` on success.
  - `{:error, reason}` on failure.
  """
  def chat(prompt, context, opts \\ []) do
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      Logger.warning("[OpenRouter] API Key missing. Falling back to Mock Cortex.")
      mock_chat(prompt, context)
    else
      execute_remote_call(api_key, prompt, context, opts)
    end
  end

  @doc """
  Streams a prompt response from OpenRouter API.

  ## Returns
  - `{:ok, stream}` where stream emits chunks of text.
  - `{:error, reason}` on failure.
  """
  def chat_stream(prompt, context, opts \\ []) do
    api_key = get_api_key()

    if is_nil(api_key) or api_key == "" do
      Logger.warning("[OpenRouter] API Key missing. Falling back to Mock Stream.")
      {:ok, mock_stream(prompt)}
    else
      execute_remote_stream(api_key, prompt, context, opts)
    end
  end

  defp get_api_key, do: System.get_env("OPENROUTER_API_KEY")

  defp build_request(api_key, prompt, context, opts) do
    model = Keyword.get(opts, :model, System.get_env("OPENROUTER_MODEL", @default_model))
    model_id = map_model_id(model)
    # Default to True for Privacy
    zdr = Keyword.get(opts, :zdr, true)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"},
      {"HTTP-Referer", "https://intelitor.ai"},
      {"X-Title", "Indrajaal PRAJNA"}
    ]

    body = %{
      model: model_id,
      messages: [
        %{
          role: "system",
          content:
            "You are PRAJNA, the Cybernetic Cortex of the Indrajaal System. Context: #{context}. Response must be a concise, actionable plan."
        },
        %{
          role: "user",
          content: prompt
        }
      ],
      provider: %{
        require_parameters: zdr,
        data_collection: if(zdr, do: "deny", else: "allow")
      }
    }

    {headers, body, model_id}
  end

  defp map_model_id(:fast), do: "google/gemini-2.0-flash-lite:free"
  defp map_model_id(:smart), do: "anthropic/claude-3.5-sonnet"
  defp map_model_id(:deep), do: "openai/gpt-4o"
  defp map_model_id(model) when is_binary(model), do: model
  defp map_model_id(model), do: to_string(model)

  defp execute_remote_call(api_key, prompt, context, opts) do
    {headers, body, model} = build_request(api_key, prompt, context, opts)

    Logger.debug(
      "[OpenRouter] Sending request to Cortex (Model: #{model}, ZDR: #{body.provider.data_collection})..."
    )

    case Req.post("#{@base_url}/chat/completions", headers: headers, json: body) do
      {:ok,
       %Req.Response{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]} = response_body
       }} ->
        # Record token usage after successful API call (SC-API-002, AOR-OPENROUTER-002)
        case response_body do
          %{"usage" => %{"total_tokens" => total_tokens}} when is_integer(total_tokens) ->
            record_token_usage(total_tokens)

          %{"usage" => %{"prompt_tokens" => prompt, "completion_tokens" => completion}}
          when is_integer(prompt) and is_integer(completion) ->
            record_token_usage(prompt + completion)

          _ ->
            # No usage info in response, estimate based on content length
            estimated_tokens = div(String.length(content), 4)
            if estimated_tokens > 0, do: record_token_usage(estimated_tokens)
        end

        {:ok, content}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[OpenRouter] API Error #{status}: #{inspect(body)}")
        {:error, "OpenRouter API Error: #{status}"}

      {:error, reason} ->
        Logger.error("[OpenRouter] Network Error: #{inspect(reason)}")
        {:error, "Network Error"}
    end
  end

  defp execute_remote_stream(api_key, prompt, context, opts) do
    {headers, body, model} = build_request(api_key, prompt, context, opts)
    body = Map.put(body, :stream, true)

    Logger.debug("[OpenRouter] Streaming request to Cortex (Model: #{model})...")

    parent = self()

    stream =
      Stream.resource(
        fn ->
          # Spawn a task to handle the HTTP request asynchronously
          Task.async(fn ->
            # Send chunks to the parent process (the stream consumer)
            Req.post!("#{@base_url}/chat/completions",
              headers: headers,
              json: body,
              into: parent
            )
          end)
        end,
        fn task ->
          receive do
            {_req, {:data, data}} ->
              # Parse SSE data
              chunks = parse_sse(data)
              {chunks, task}

            {_req, {:headers, _headers}} ->
              {[], task}

            {_req, {:status, _status}} ->
              {[], task}

            {_req, :done} ->
              {:halt, task}

            # Handle Task completion/exit
            {ref, _result} when is_reference(ref) ->
              if ref == task.ref, do: {:halt, task}, else: {[], task}

            {:DOWN, ref, :process, _pid, _reason} ->
              if ref == task.ref, do: {:halt, task}, else: {[], task}

            _other ->
              {[], task}
          end
        end,
        fn task ->
          # Cleanup: Ensure task is shut down
          Task.shutdown(task, :brutal_kill)
        end
      )

    {:ok, stream}
  end

  defp parse_sse(data) do
    data
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.map(fn line ->
      json = String.replace_prefix(line, "data: ", "")

      case Jason.decode(json) do
        {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}} -> content
        _ -> ""
      end
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp mock_chat(_prompt, _context) do
    Process.sleep(500)
    {:ok, "MOCK CORTEX: Recommended action is to restart the affected node."}
  end

  defp mock_stream(_prompt) do
    ["MOCK", " ", "CORTEX", ":", " ", "Streaming", " ", "Response", "..."]
    |> Stream.map(fn chunk ->
      Process.sleep(100)
      chunk
    end)
  end

  @doc """
  Evaluates a proposal for cognitive alignment with system invariants.
  Used by the Guardian for high-impact autonomic decisions.
  """
  @spec evaluate_alignment(map()) ::
          {:ok, :aligned} | {:ok, :unaligned, String.t()} | {:error, any()}
  def evaluate_alignment(proposal) do
    prompt = """
    Evaluate this autonomic proposal for structural and ethical alignment with the Indrajaal SIL-6 biomorphic architecture.
    Proposal: #{inspect(proposal)}

    Response must be a JSON object:
    {"status": "aligned" | "unaligned", "reason": "brief explanation"}
    """

    case chat(prompt, "guardian_cognitive_check", model: "anthropic/claude-3.5-sonnet") do
      {:ok, response} ->
        # Attempt to extract JSON from response
        case extract_json(response) do
          %{"status" => "aligned"} -> {:ok, :aligned}
          %{"status" => "unaligned", "reason" => reason} -> {:ok, :unaligned, reason}
          # Fallback: default to aligned if JSON parse fails
          _ -> {:ok, :aligned}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_json(text) do
    # Simple JSON extraction from LLM response
    case Regex.run(~r/\{.*\}/s, text) do
      [json] ->
        try do
          Jason.decode!(json)
        rescue
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  @doc """
  Health check for OpenRouter API availability.
  """
  def health_check do
    api_key = get_api_key()
    if is_nil(api_key) or api_key == "", do: {:error, :api_key_missing}, else: :ok
  end

  @doc false
  def validate_routing_proposal(proposal) when is_map(proposal) do
    required_keys = [:source, :target, :model, :confidence, :guardian_approved]

    if Enum.all?(required_keys, &Map.has_key?(proposal, &1)) do
      {:ok, proposal}
    else
      {:error, {:invalid_proposal, :missing_required_keys}}
    end
  end

  def validate_routing_proposal(_proposal), do: {:ok, :verified}

  @doc false
  @spec verify_routing_graph(atom(), String.t(), keyword()) ::
          {:ok, :verified} | {:error, {atom(), atom()}}
  def verify_routing_graph(source, model, opts \\ []) do
    confidence = Keyword.get(opts, :confidence, 1.0)
    guardian_approved = Keyword.get(opts, :guardian_approved, false)

    with :ok <- check_confidence_threshold(confidence),
         :ok <- check_simplex_principle(source, guardian_approved),
         :ok <- check_exclusivity_constraint(source, model) do
      {:ok, :verified}
    end
  end

  @doc false
  @spec check_simplex_principle(atom(), boolean()) :: :ok | {:error, {atom(), atom()}}
  def check_simplex_principle(source, guardian_approved) do
    trusted = source in [:guardian, :gde]

    if trusted or guardian_approved do
      :ok
    else
      {:error, {:constraint_violation, :inv_simplex_principle}}
    end
  end

  @doc false
  @spec check_exclusivity_constraint(atom(), String.t()) :: :ok | {:error, {atom(), atom()}}
  def check_exclusivity_constraint(source, model) do
    if source == :synapse and not String.contains?(model, "/") do
      {:error, {:constraint_violation, :inv_openrouter_exclusivity}}
    else
      :ok
    end
  end

  @doc false
  @spec get_routing_graph_state() :: map()
  def get_routing_graph_state do
    %{
      nodes: [:cortex, :synapse, :openrouter, :guardian, :gde, :agent],
      edges: [
        {:cortex, :synapse},
        {:synapse, :openrouter},
        {:guardian, :cortex},
        {:gde, :cortex}
      ],
      version: "1.0.0",
      invariants: [
        :inv_simplex_principle,
        :inv_openrouter_exclusivity,
        :inv_confidence_threshold
      ]
    }
  end

  @doc """
  Performs comprehensive pre-flight checks before AI invocation.

  This function validates the AI request against Guardian safety constraints,
  rate limits, and constitutional alignment before allowing the request to proceed.

  ## Parameters
    - caller: The module/process requesting AI assistance
    - model_id: The OpenRouter model identifier (e.g., "meta-llama/llama-3.1-8b-instruct:free")
    - prompt: The prompt being sent to the AI

  ## Returns
    - {:ok, validation_result} on approval
    - {:error, reason} on rejection

  ## STAMP Constraints
    - SC-NEURO-001: AI output MUST pass Guardian.validate_proposal/1
    - SC-AI-003: Intelligence amplification factor verification
    - SC-PROM-001: Proof requirement for state-mutating actions
  """
  @spec full_pre_flight_check(module() | atom(), String.t(), String.t()) ::
          {:ok, map()} | {:error, atom()}
  def full_pre_flight_check(caller, model_id, prompt) do
    alias Indrajaal.Safety.Guardian

    # Build the proposal for Guardian validation
    proposal = %{
      action: :ai_request,
      caller: caller,
      model_id: model_id,
      prompt_length: byte_size(prompt),
      prompt_hash:
        :crypto.hash(:sha256, prompt) |> Base.encode16(case: :lower) |> binary_part(0, 16),
      timestamp: DateTime.utc_now(),
      # Token estimation (rough: ~4 chars per token)
      estimated_tokens: div(byte_size(prompt), 4)
    }

    # Pre-flight checks in order of precedence
    with :ok <- check_rate_limits(model_id),
         :ok <- check_token_budget(proposal.estimated_tokens),
         :ok <- check_prompt_safety(prompt),
         {:ok, _} <- validate_with_guardian(proposal) do
      {:ok,
       %{
         guardian_approved: true,
         model_id: model_id,
         caller: caller,
         prompt_hash: proposal.prompt_hash,
         estimated_tokens: proposal.estimated_tokens,
         approved_at: DateTime.utc_now()
       }}
    else
      {:error, reason} ->
        Logger.warning("[OpenRouter] Pre-flight check failed: #{inspect(reason)}")
        {:error, reason}

      {:veto, reason, _fallback} ->
        Logger.warning("[OpenRouter] Guardian vetoed request: #{inspect(reason)}")
        {:error, {:guardian_veto, reason}}
    end
  end

  # Check rate limits against API budget (SC-API-002, AOR-OPENROUTER-002)
  # ETS-backed token bucket with 60-second windows
  defp check_rate_limits(model_id) do
    init()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@rate_limit_table, :window) do
      [{:window, state}] ->
        # Check if window expired
        window_age = now - state.window_start
        new_state = if window_age > @window_duration, do: init_window_state(now), else: state

        # Check backoff (exponential backoff on 429 errors)
        if not is_nil(new_state.backoff_until) and now < new_state.backoff_until do
          :telemetry.execute(
            [:openrouter, :rate_limit],
            %{
              type: :backoff,
              remaining_ms: new_state.backoff_until - now
            },
            %{model: model_id}
          )

          {:error, :rate_limited}
        else
          # Check RPM limit (200 max for free tier)
          if new_state.request_count >= @default_rpm_limit do
            :telemetry.execute(
              [:openrouter, :rate_limit],
              %{
                type: :rpm_exceeded,
                current: new_state.request_count,
                limit: @default_rpm_limit
              },
              %{model: model_id}
            )

            {:error, :rate_limited}
          else
            # Rate limit check passed, update counter
            updated_state = %{
              new_state
              | request_count: new_state.request_count + 1,
                backoff_until: nil
            }

            :ets.insert(@rate_limit_table, {:window, updated_state})

            :telemetry.execute(
              [:openrouter, :rate_limit],
              %{
                type: :allowed,
                rpm: updated_state.request_count,
                tpm: updated_state.token_count
              },
              %{model: model_id}
            )

            :ok
          end
        end

      [] ->
        # Initialize if missing
        init_window()
        check_rate_limits(model_id)
    end
  end

  defp init_window_state(now) do
    %{
      window_start: now,
      request_count: 0,
      token_count: 0,
      backoff_until: nil
    }
  end

  @doc """
  Record token usage for TPM tracking.
  Called after successful API responses to track token consumption.
  """
  def record_token_usage(token_count) when is_integer(token_count) and token_count > 0 do
    case :ets.lookup(@rate_limit_table, :window) do
      [{:window, state}] ->
        # Check TPM limit (40000 max for free tier)
        if state.token_count + token_count > @default_tpm_limit do
          :telemetry.execute(
            [:openrouter, :rate_limit],
            %{
              type: :tpm_exceeded,
              current: state.token_count,
              requested: token_count,
              limit: @default_tpm_limit
            },
            %{}
          )

          {:error, :tpm_limit_exceeded}
        else
          updated_state = %{state | token_count: state.token_count + token_count}
          :ets.insert(@rate_limit_table, {:window, updated_state})

          :telemetry.execute(
            [:openrouter, :token_usage],
            %{
              tokens: token_count,
              total: updated_state.token_count,
              limit: @default_tpm_limit
            },
            %{}
          )

          :ok
        end

      [] ->
        init_window()
        record_token_usage(token_count)
    end
  end

  @doc """
  Apply exponential backoff after rate limit error (429 response).
  Implements AOR-OPENROUTER-002 exponential backoff pattern.
  """
  def apply_exponential_backoff(retry_count \\ 1) do
    backoff_ms = trunc(1000 * :math.pow(2, retry_count - 1)) + :rand.uniform(1000)

    case :ets.lookup(@rate_limit_table, :window) do
      [{:window, state}] ->
        backoff_until = System.monotonic_time(:millisecond) + backoff_ms
        updated_state = %{state | backoff_until: backoff_until}
        :ets.insert(@rate_limit_table, {:window, updated_state})

        :telemetry.execute(
          [:openrouter, :backoff],
          %{
            retry_count: retry_count,
            backoff_ms: backoff_ms
          },
          %{}
        )

        backoff_ms

      [] ->
        init_window()
        apply_exponential_backoff(retry_count)
    end
  end

  # Check token budget
  # SC-API-003: Token budget - stay within 80% of limit
  defp check_token_budget(estimated_tokens) do
    # 4K context for free models (SC-OPENROUTER-005)
    max_tokens = 4000

    if estimated_tokens > max_tokens * 0.8 do
      {:error, :token_budget_exceeded}
    else
      :ok
    end
  end

  # Check prompt for dangerous patterns
  # SC-SEC-001: No code execution without review
  defp check_prompt_safety(prompt) do
    dangerous_patterns = [
      ~r/rm\s+-rf/i,
      ~r/DROP\s+TABLE/i,
      ~r/DELETE\s+FROM.*WHERE.*1\s*=\s*1/i,
      ~r/System\.cmd/i,
      ~r/:os\.cmd/i,
      ~r/eval\(/i,
      ~r/exec\(/i
    ]

    if Enum.any?(dangerous_patterns, &Regex.match?(&1, prompt)) do
      {:error, :dangerous_prompt_pattern}
    else
      :ok
    end
  end

  # Validate with Guardian safety kernel
  # SC-NEURO-001: AI output MUST pass Guardian.validate_proposal/1
  # SC-GDE-001: Guardian validation required for all mutations
  defp validate_with_guardian(proposal) do
    alias Indrajaal.Safety.Guardian

    case Guardian.alive?(timeout: 1000) do
      true ->
        Guardian.validate_proposal(proposal, timeout: 3000)

      false ->
        # Guardian not running - behavior depends on environment
        handle_guardian_unavailable(proposal)
    end
  rescue
    error ->
      Logger.warning("[OpenRouter] Guardian check error: #{inspect(error)}")
      handle_guardian_unavailable(proposal)
  end

  defp check_confidence_threshold(confidence) when confidence >= 0.85, do: :ok

  defp check_confidence_threshold(_confidence),
    do: {:error, {:constraint_violation, :inv_confidence_threshold}}

  defp handle_guardian_unavailable(proposal) do
    # Check environment - SC-GDE-001 requires Guardian in production
    prod_mode? =
      Application.get_env(:indrajaal, :env, :dev) == :prod or
        System.get_env("MIX_ENV") == "prod"

    if prod_mode? do
      # In production, Guardian unavailability BLOCKS requests (SC-GDE-001)
      Logger.error("[OpenRouter] Guardian unavailable in production - blocking request")
      :telemetry.execute([:openrouter, :guardian, :blocked], %{reason: :unavailable}, %{})
      {:error, :guardian_unavailable}
    else
      # In development/test, allow with warning (fail-safe for development)
      Logger.warning("[OpenRouter] Guardian not available, allowing request (dev mode)")
      {:ok, proposal}
    end
  end
end
