defmodule Indrajaal.Cortex.SynapseOpenRouter do
  @moduledoc """
  Cortex-layer OpenRouter AI inference integration.

  WHAT: L3 Cortex module providing cached, rate-limited AI inference via OpenRouter.
  WHY: Decouples Synapse GenServer from raw HTTP client, adds result caching,
       audit logging, and Cortex-specific inference orchestration.
  CONSTRAINTS: SC-OPENROUTER-001 to SC-OPENROUTER-005, SC-GDE-001, SC-NEURO-001,
               SC-MCP-001, AOR-OPENROUTER-001 to AOR-OPENROUTER-005.

  ## Architecture

  ```
  Synapse GenServer
      │
      ▼
  SynapseOpenRouter    ◄─── this module (Cortex L3)
      │
      ├─ ETS Cache (:synapse_openrouter_cache)
      ├─ Audit Log (DuckDB via telemetry)
      └─ OpenRouterClient (HTTP / mock fallback)
  ```

  ## STAMP Constraints

  - SC-OPENROUTER-001: Free models MUST be prioritized
  - SC-OPENROUTER-002: Rate limiting with exponential backoff
  - SC-OPENROUTER-003: Fallback to mock on API unavailable
  - SC-OPENROUTER-004: Max 10 concurrent AI requests
  - SC-OPENROUTER-005: Context window < 4K tokens per request
  - SC-GDE-001: Guardian validation required for proposals
  - SC-NEURO-001: Simplex principle — AI output passes Guardian
  - AOR-OPENROUTER-003: Cache successful generations
  - AOR-OPENROUTER-004: Log all API calls for audit
  - AOR-OPENROUTER-005: Fallback to mock for offline development

  ## Free Models (SC-OPENROUTER-001)

  ```
  property_gen:  "meta-llama/llama-3.1-8b-instruct:free"
  code_analysis: "google/gemma-2-9b-it:free"
  bdd_gen:       "mistralai/mistral-7b-instruct:free"
  fmea_analysis: "qwen/qwen-2-7b-instruct:free"
  formal_verify: "meta-llama/llama-3.1-8b-instruct:free"
  ```
  """

  require Logger

  alias Indrajaal.AI.OpenRouterClient

  @table :synapse_openrouter_cache
  @cache_ttl_ms 300_000
  @max_concurrent_requests 10
  @max_context_tokens 4_000

  # Free models per task type (SC-OPENROUTER-001)
  @free_models %{
    property_gen: "meta-llama/llama-3.1-8b-instruct:free",
    code_analysis: "google/gemma-2-9b-it:free",
    bdd_gen: "mistralai/mistral-7b-instruct:free",
    fmea_analysis: "qwen/qwen-2-7b-instruct:free",
    formal_verify: "meta-llama/llama-3.1-8b-instruct:free",
    general: "meta-llama/llama-3.1-8b-instruct:free"
  }

  @doc """
  Initializes the ETS cache table. Must be called before any inference.
  Idempotent — safe to call multiple times.
  """
  @spec init() :: :ok
  def init do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
        :ok

      _ ->
        :ok
    end
  end

  @doc """
  Runs an AI inference request via OpenRouter with caching and audit logging.

  ## Parameters
  - `prompt` — the inference prompt (truncated to 4K tokens if needed)
  - `task_type` — atom key for free model selection (default: :general)
  - `opts` — keyword options: `model`, `bypass_cache`, `guardian_approved`

  ## Returns
  - `{:ok, response_text}` on success
  - `{:error, reason}` on failure
  """
  @spec infer(String.t(), atom(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def infer(prompt, task_type \\ :general, opts \\ []) do
    ensure_table_exists()

    # SC-OPENROUTER-005: enforce context window limit
    truncated_prompt = truncate_prompt(prompt, @max_context_tokens)

    model = opts[:model] || Map.get(@free_models, task_type, @free_models.general)
    bypass_cache = Keyword.get(opts, :bypass_cache, false)
    cache_key = cache_key(truncated_prompt, model)

    # AOR-OPENROUTER-003: check cache first
    with :cache_miss <- if(bypass_cache, do: :cache_miss, else: check_cache(cache_key)),
         :ok <- check_concurrency_limit(),
         {:ok, response} <- OpenRouterClient.chat(truncated_prompt, model, opts) do
      # Cache successful result
      put_cache(cache_key, response)

      # AOR-OPENROUTER-004: audit log
      emit_audit_telemetry(:success, task_type, model, prompt, response)

      {:ok, response}
    else
      {:cache_hit, cached} ->
        emit_audit_telemetry(:cache_hit, task_type, model, prompt, cached)
        {:ok, cached}

      {:error, :concurrency_limit} ->
        Logger.warning(
          "[SynapseOpenRouter] Concurrency limit reached (max #{@max_concurrent_requests})"
        )

        emit_audit_telemetry(:concurrency_limit, task_type, model, prompt, nil)
        {:error, :concurrency_limit}

      {:error, :tpm_limit_exceeded} ->
        Logger.warning(
          "[SynapseOpenRouter] TPM limit exceeded — using mock fallback (AOR-OPENROUTER-005)"
        )

        mock_response = mock_inference(truncated_prompt, task_type)
        emit_audit_telemetry(:tpm_fallback, task_type, model, prompt, mock_response)
        {:ok, mock_response}

      {:error, reason} ->
        # AOR-OPENROUTER-005: fallback to mock on API unavailable
        Logger.warning("[SynapseOpenRouter] API error #{inspect(reason)} — using mock fallback")
        mock_response = mock_inference(truncated_prompt, task_type)
        emit_audit_telemetry(:api_fallback, task_type, model, prompt, mock_response)
        {:ok, mock_response}
    end
  end

  @doc """
  Returns the model name for a given task type (SC-OPENROUTER-001).
  """
  @spec model_for(atom()) :: String.t()
  def model_for(task_type) do
    Map.get(@free_models, task_type, @free_models.general)
  end

  @doc """
  Returns all configured free models.
  """
  @spec free_models() :: map()
  def free_models, do: @free_models

  @doc """
  Validates that a model uses the :free suffix (SC-OPENROUTER-001).
  """
  @spec free_model?(String.t()) :: boolean()
  def free_model?(model) when is_binary(model) do
    String.ends_with?(model, ":free")
  end

  @doc """
  Checks OpenRouter health via the underlying client.
  """
  @spec health_check() :: :ok | {:error, term()}
  def health_check do
    OpenRouterClient.health_check()
  end

  @doc """
  Returns cache statistics for observability.
  """
  @spec cache_stats() :: map()
  def cache_stats do
    ensure_table_exists()
    size = :ets.info(@table, :size)
    memory = :ets.info(@table, :memory)

    %{
      table: @table,
      size: size,
      memory_words: memory,
      ttl_ms: @cache_ttl_ms
    }
  end

  @doc """
  Clears the inference cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    ensure_table_exists()
    :ets.delete_all_objects(@table)
    Logger.info("[SynapseOpenRouter] Cache cleared")
    :ok
  end

  @doc """
  Returns the current concurrent request count from ETS.
  """
  @spec concurrent_requests() :: non_neg_integer()
  def concurrent_requests do
    ensure_table_exists()

    case :ets.lookup(@table, :__concurrent_count__) do
      [{:__concurrent_count__, n}] -> n
      [] -> 0
    end
  end

  # ---- Private helpers ----

  @spec truncate_prompt(String.t(), non_neg_integer()) :: String.t()
  defp truncate_prompt(prompt, max_tokens) do
    # Approximate: 1 token ~ 4 chars
    max_chars = max_tokens * 4

    if String.length(prompt) > max_chars do
      String.slice(prompt, 0, max_chars) <> "\n[TRUNCATED — context window limit]"
    else
      prompt
    end
  end

  @spec cache_key(String.t(), String.t()) :: binary()
  defp cache_key(prompt, model) do
    :crypto.hash(:sha256, "#{model}:#{prompt}") |> Base.encode16(case: :lower)
  end

  @spec check_cache(binary()) :: {:cache_hit, String.t()} | :cache_miss
  defp check_cache(key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, inserted_at}] when now - inserted_at < @cache_ttl_ms ->
        {:cache_hit, value}

      _ ->
        :cache_miss
    end
  end

  @spec put_cache(binary(), String.t()) :: true
  defp put_cache(key, value) do
    now = System.monotonic_time(:millisecond)
    :ets.insert(@table, {key, value, now})
  end

  @spec check_concurrency_limit() :: :ok | {:error, :concurrency_limit}
  defp check_concurrency_limit do
    ensure_table_exists()
    count = concurrent_requests()

    if count >= @max_concurrent_requests do
      {:error, :concurrency_limit}
    else
      :ok
    end
  end

  @spec mock_inference(String.t(), atom()) :: String.t()
  defp mock_inference(prompt, task_type) do
    "MOCK CORTEX [#{task_type}]: Analysis of '#{String.slice(prompt, 0, 80)}...' — " <>
      "Recommended action: apply STAMP constraints and verify constitutional alignment."
  end

  @spec emit_audit_telemetry(atom(), atom(), String.t(), String.t(), String.t() | nil) :: :ok
  defp emit_audit_telemetry(outcome, task_type, model, _prompt, _response) do
    :telemetry.execute(
      [:cortex, :openrouter, :inference],
      %{count: 1},
      %{
        outcome: outcome,
        task_type: task_type,
        model: model,
        timestamp: DateTime.utc_now()
      }
    )

    :ok
  end

  @spec ensure_table_exists() :: :ok
  defp ensure_table_exists do
    if :ets.whereis(@table) == :undefined, do: init()
    :ok
  end
end
