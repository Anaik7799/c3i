defmodule Indrajaal.Cortex.AI.GeminiInterface do
  @moduledoc """
  Gemini Interface for Context Awareness in the Bicameral Cortex.

  WHAT: Interface to Google Gemini for high-context analysis and observation.
  WHY: Gemini 1.5 Pro has 1M+ token context - ideal for repository-wide analysis.
  CONSTRAINTS: Rate limits, API key required, Guardian validation on outputs.

  ## Role in Bicameral Architecture

  Gemini acts as "The Global Observer" - answering:
  - "Where are we?" (codebase context)
  - "What is the history of this error?" (log analysis)
  - "What patterns exist?" (semantic analysis)

  ## STAMP Constraints

  - SC-AI-001: API key must be configured
  - SC-AI-002: Rate limiting must be respected
  - SC-AI-003: Outputs must pass Guardian validation

  ## AOR Rules

  - AOR-CTX-001: AI proposals MUST pass Guardian

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AI-001 to SC-AI-003 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohNeuralStream
  alias Indrajaal.AI.OpenRouterClient

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type analysis_request :: %{
          files: [String.t()],
          query: String.t(),
          context: map()
        }

  @type analysis_response :: %{
          summary: String.t(),
          insights: [String.t()],
          references: [map()],
          confidence: float()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_model "google/gemini-pro-1.5"
  @default_timeout_ms 60_000
  # Reserved for retry logic implementation
  @max_retries 3
  @rate_limit_delay_ms 1000

  # Suppress unused warnings - reserved for resilience implementation
  _ = @max_retries
  _ = @rate_limit_delay_ms

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze codebase context using Gemini.

  ## Parameters
  - files: List of file paths to include in context
  - query: Analysis query/question
  - opts: Options
    - :model - Model to use (default: gemini-1.5-pro)
    - :timeout - Request timeout in ms

  ## Returns
  - {:ok, analysis_response}
  - {:error, reason}
  """
  @spec analyze_context([String.t()], String.t(), keyword()) ::
          {:ok, analysis_response()} | {:error, term()}
  def analyze_context(files, query, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(__MODULE__, {:analyze, files, query, opts}, timeout + 1000)
  end

  @doc """
  Analyze error logs to understand failure context.

  ## Parameters
  - logs: Error log content
  - context: Additional context (files, history)

  ## Returns
  - {:ok, error_analysis}
  - {:error, reason}
  """
  @spec analyze_error(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def analyze_error(logs, context \\ %{}) do
    GenServer.call(__MODULE__, {:analyze_error, logs, context}, @default_timeout_ms)
  end

  @doc """
  Extract semantic patterns from codebase.

  ## Parameters
  - files: Files to analyze
  - pattern_type: Type of patterns to extract (:dependencies, :architecture, :conventions)

  ## Returns
  - {:ok, patterns}
  - {:error, reason}
  """
  @spec extract_patterns([String.t()], atom()) :: {:ok, map()} | {:error, term()}
  def extract_patterns(files, pattern_type) do
    GenServer.call(__MODULE__, {:extract_patterns, files, pattern_type}, @default_timeout_ms)
  end

  @doc """
  Check if Gemini API is configured and available.
  """
  @spec available?() :: boolean()
  def available? do
    GenServer.call(__MODULE__, :available?)
  catch
    :exit, _ -> false
  end

  @doc """
  Get interface statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[GeminiInterface] Initializing Gemini context analyzer - SC-AI-001")

    # Prefer OpenRouter key if available, consistent with OODA operations
    openrouter_key =
      Application.get_env(:indrajaal, :ai, [])[:openrouter_key] ||
        System.get_env("OPENROUTER_API_KEY")

    api_key = Keyword.get(opts, :api_key) || openrouter_key || System.get_env("GEMINI_API_KEY")

    state = %{
      api_key: api_key,
      model: Keyword.get(opts, :model, @default_model),
      available: api_key != nil and api_key != "",
      # Statistics
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      total_tokens: 0,
      last_request: nil,
      started_at: DateTime.utc_now()
    }

    if state.available do
      Logger.info("[GeminiInterface] API key configured - Gemini available")
    else
      Logger.warning("[GeminiInterface] No API key - running in mock mode")
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:analyze, files, query, opts}, _from, state) do
    model = Keyword.get(opts, :model, state.model)

    result =
      if state.available do
        perform_analysis(files, query, model, state.api_key)
      else
        mock_analysis(files, query)
      end

    new_state = update_stats(state, result)
    stream_telemetry(:analyze, result)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:analyze_error, logs, context}, _from, state) do
    result =
      if state.available do
        perform_error_analysis(logs, context, state.api_key)
      else
        mock_error_analysis(logs, context)
      end

    new_state = update_stats(state, result)
    stream_telemetry(:analyze_error, result)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:extract_patterns, files, pattern_type}, _from, state) do
    result =
      if state.available do
        perform_pattern_extraction(files, pattern_type, state.api_key)
      else
        mock_pattern_extraction(files, pattern_type)
      end

    new_state = update_stats(state, result)
    stream_telemetry(:extract_patterns, result)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:available?, _from, state) do
    {:reply, state.available, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      available: state.available,
      model: state.model,
      total_requests: state.total_requests,
      successful_requests: state.successful_requests,
      failed_requests: state.failed_requests,
      total_tokens: state.total_tokens,
      last_request: state.last_request,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  # ============================================================
  # PRIVATE - API CALLS
  # ============================================================

  defp perform_analysis(files, query, model, api_key) do
    # Read file contents
    file_contents = read_files(files)

    prompt = build_analysis_prompt(file_contents, query)

    case call_gemini_api(prompt, model, api_key) do
      {:ok, response} ->
        parse_analysis_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_error_analysis(logs, context, api_key) do
    prompt = build_error_analysis_prompt(logs, context)

    case call_gemini_api(prompt, @default_model, api_key) do
      {:ok, response} ->
        parse_error_analysis_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_pattern_extraction(files, pattern_type, api_key) do
    file_contents = read_files(files)
    prompt = build_pattern_prompt(file_contents, pattern_type)

    case call_gemini_api(prompt, @default_model, api_key) do
      {:ok, response} ->
        parse_pattern_response(response, pattern_type)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_gemini_api(prompt, model, _api_key) do
    # Map legacy model names to OpenRouter if needed
    model_id =
      case model do
        "gemini-1.5-pro" -> "google/gemini-pro-1.5"
        other -> other
      end

    # P0-CRITICAL: Full pre-flight Guardian + Graph verification (SC-NEURO-001, SC-GVF-003)
    # This implements the proper Simplex Architecture flow:
    # 1. Guardian validates the AI request BEFORE execution
    # 2. Graph verification ensures routing constraints
    # 3. Only then proceed with the actual API call
    with {:ok, %{guardian_approved: true}} <-
           OpenRouterClient.full_pre_flight_check(:gemini_interface, model_id, prompt) do
      # Guardian approved + Graph verified - proceed with API call
      messages = [
        %{role: "user", content: prompt}
      ]

      # Use OpenRouterClient which handles auth and standardizes the response
      case OpenRouterClient.chat(messages, model: model_id, temperature: 0.2) do
        {:ok, content} ->
          {:ok, content}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, {:guardian_veto, reason, _fallback}} ->
        Logger.error("🛡️ [GeminiInterface] Guardian pre-flight VETO: #{inspect(reason)}")
        {:error, {:guardian_pre_flight_veto, reason}}

      {:error, {:guardian_unavailable, _error}} ->
        # Fail safe: if Guardian is unavailable, deny the request
        Logger.error("🚫 [GeminiInterface] Guardian unavailable - request denied (SC-NEURO-001)")
        {:error, :guardian_unavailable}

      {:error, reason} ->
        Logger.error("🚫 [GeminiInterface] SC-GVF verification failed: #{inspect(reason)}")
        {:error, {:graph_verification_failed, reason}}
    end
  end

  # ============================================================
  # PRIVATE - MOCK RESPONSES
  # ============================================================

  defp mock_analysis(files, query) do
    {:ok,
     %{
       summary: "Mock analysis for #{length(files)} files",
       query: query,
       insights: [
         "This is a mock response - GEMINI_API_KEY not configured",
         "Files analyzed: #{Enum.join(files, ", ")}",
         "Query: #{query}"
       ],
       references:
         Enum.map(files, fn f ->
           %{file: f, relevance: 0.8}
         end),
       confidence: 0.0,
       mock: true
     }}
  end

  defp mock_error_analysis(logs, _context) do
    {:ok,
     %{
       error_type: :unknown,
       root_cause: "Mock analysis - API not available",
       affected_files: [],
       suggested_fixes: ["Configure GEMINI_API_KEY for real analysis"],
       log_snippet: String.slice(logs, 0..200),
       mock: true
     }}
  end

  defp mock_pattern_extraction(files, pattern_type) do
    {:ok,
     %{
       pattern_type: pattern_type,
       patterns: ["Mock pattern 1", "Mock pattern 2"],
       files_analyzed: length(files),
       mock: true
     }}
  end

  # ============================================================
  # PRIVATE - PROMPT BUILDING
  # ============================================================

  defp build_analysis_prompt(file_contents, query) do
    """
    You are an expert code analyst. Analyze the following codebase context and answer the query.

    ## Files
    #{format_file_contents(file_contents)}

    ## Query
    #{query}

    ## Instructions
    Provide a structured analysis with:
    1. Summary (1-2 sentences)
    2. Key insights (bullet points)
    3. File references with relevance scores
    4. Confidence level (0.0-1.0)

    Format your response as JSON:
    ```json
    {
      "summary": "...",
      "insights": ["..."],
      "references": [{"file": "...", "relevance": 0.9, "reason": "..."}],
      "confidence": 0.85
    }
    ```
    """
  end

  defp build_error_analysis_prompt(logs, context) do
    context_str = if map_size(context) > 0, do: "\n## Context\n#{inspect(context)}", else: ""

    """
    You are an expert debugger. Analyze the following error logs and identify the root cause.

    ## Error Logs
    ```
    #{logs}
    ```
    #{context_str}

    ## Instructions
    Provide a structured analysis with:
    1. Error type classification
    2. Root cause identification
    3. Affected files/modules
    4. Suggested fixes (prioritized)

    Format your response as JSON:
    ```json
    {
      "error_type": "compilation|runtime|test|logic",
      "root_cause": "...",
      "affected_files": ["..."],
      "suggested_fixes": ["..."],
      "confidence": 0.85
    }
    ```
    """
  end

  defp build_pattern_prompt(file_contents, pattern_type) do
    type_instructions =
      case pattern_type do
        :dependencies -> "Identify module dependencies, imports, and coupling patterns"
        :architecture -> "Identify architectural patterns, layers, and design decisions"
        :conventions -> "Identify coding conventions, naming patterns, and style guidelines"
        _ -> "Identify relevant patterns"
      end

    """
    You are an expert code architect. Analyze the following codebase for #{pattern_type} patterns.

    ## Files
    #{format_file_contents(file_contents)}

    ## Instructions
    #{type_instructions}

    Format your response as JSON:
    ```json
    {
      "pattern_type": "#{pattern_type}",
      "patterns": [
        {"name": "...", "description": "...", "occurrences": [...], "importance": "high|medium|low"}
      ],
      "recommendations": ["..."]
    }
    ```
    """
  end

  # ============================================================
  # PRIVATE - RESPONSE PARSING
  # ============================================================

  defp parse_analysis_response(text) do
    case extract_json(text) do
      {:ok, data} ->
        {:ok,
         %{
           summary: Map.get(data, "summary", ""),
           insights: Map.get(data, "insights", []),
           references: Map.get(data, "references", []),
           confidence: Map.get(data, "confidence", 0.5)
         }}

      {:error, _} ->
        # Fallback: treat entire response as summary
        {:ok,
         %{
           summary: text,
           insights: [],
           references: [],
           confidence: 0.3
         }}
    end
  end

  defp parse_error_analysis_response(text) do
    case extract_json(text) do
      {:ok, data} ->
        {:ok,
         %{
           error_type: String.to_atom(Map.get(data, "error_type", "unknown")),
           root_cause: Map.get(data, "root_cause", ""),
           affected_files: Map.get(data, "affected_files", []),
           suggested_fixes: Map.get(data, "suggested_fixes", []),
           confidence: Map.get(data, "confidence", 0.5)
         }}

      {:error, _} ->
        {:ok,
         %{
           error_type: :unknown,
           root_cause: text,
           affected_files: [],
           suggested_fixes: [],
           confidence: 0.3
         }}
    end
  end

  defp parse_pattern_response(text, pattern_type) do
    case extract_json(text) do
      {:ok, data} ->
        {:ok,
         %{
           pattern_type: pattern_type,
           patterns: Map.get(data, "patterns", []),
           recommendations: Map.get(data, "recommendations", [])
         }}

      {:error, _} ->
        {:ok,
         %{
           pattern_type: pattern_type,
           patterns: [],
           recommendations: [text]
         }}
    end
  end

  defp extract_json(text) do
    # Try to find JSON in markdown code blocks
    case Regex.run(~r/```json\s*(.*?)\s*```/s, text) do
      [_, json] -> Jason.decode(json)
      nil -> Jason.decode(text)
    end
  end

  # ============================================================
  # PRIVATE - HELPERS
  # ============================================================

  defp read_files(files) do
    Enum.map(files, fn path ->
      case File.read(path) do
        {:ok, content} -> {path, content}
        {:error, _} -> {path, "# File not found: #{path}"}
      end
    end)
  end

  defp format_file_contents(file_contents) do
    Enum.map_join(file_contents, "\n\n", fn {path, content} ->
      """
      ### #{path}
      ```elixir
      #{String.slice(content, 0..10_000)}
      ```
      """
    end)
  end

  defp update_stats(state, result) do
    {successful, failed} =
      case result do
        {:ok, _} -> {state.successful_requests + 1, state.failed_requests}
        {:error, _} -> {state.successful_requests, state.failed_requests + 1}
      end

    %{
      state
      | total_requests: state.total_requests + 1,
        successful_requests: successful,
        failed_requests: failed,
        last_request: DateTime.utc_now()
    }
  end

  defp stream_telemetry(operation, result) do
    status = if match?({:ok, _}, result), do: :success, else: :failure

    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_metric(:gemini, operation, 1, %{status: status})
    end
  rescue
    _ -> :ok
  end
end
