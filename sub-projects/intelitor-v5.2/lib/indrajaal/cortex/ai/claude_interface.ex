defmodule Indrajaal.Cortex.AI.ClaudeInterface do
  @moduledoc """
  Claude Interface for Reasoning and Synthesis in the Bicameral Cortex.

  WHAT: Interface to Anthropic Claude for code generation and reasoning.
  WHY: Claude excels at code generation, reasoning, and following complex instructions.
  CONSTRAINTS: Rate limits, API key required, Guardian validation on ALL outputs.

  ## Role in Bicameral Architecture

  Claude acts as "The Chief Architect" - performing:
  - Goal-Directed Evaluation (GDE)
  - Code synthesis from analysis
  - Reasoning about solutions
  - Following STAMP constraints

  ## STAMP Constraints

  - SC-AI-001: API key must be configured
  - SC-AI-002: Rate limiting must be respected
  - SC-AI-003: Outputs must pass Guardian validation
  - SC-SEC-001: No code execution without Guardian review

  ## AOR Rules

  - AOR-CTX-001: AI proposals MUST pass Guardian

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-AI-001 to SC-AI-003, SC-SEC-001 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Observability.ZenohNeuralStream
  alias Indrajaal.AI.OpenRouterClient

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type generation_request :: %{
          analysis: map(),
          requirements: String.t(),
          constraints: [String.t()]
        }

  @type generation_response :: %{
          code: String.t(),
          explanation: String.t(),
          files_to_modify: [String.t()],
          confidence: float(),
          guardian_approved: boolean()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_model "claude-sonnet-4-20_250_514"
  @default_timeout_ms 120_000
  # @max_tokens is set per-request in OpenRouterClient based on model

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate code solution based on analysis and requirements.

  ## Parameters
  - analysis: Context analysis (from Gemini or other source)
  - requirements: What needs to be implemented
  - opts: Options
    - :constraints - Additional STAMP constraints to follow
    - :guardian_validate - Whether to validate with Guardian (default: true)

  ## Returns
  - {:ok, generation_response}
  - {:error, reason}
  - {:veto, reason, fallback} - Guardian rejected the proposal
  """
  @spec generate_solution(map(), String.t(), keyword()) ::
          {:ok, generation_response()} | {:error, term()} | {:veto, term(), term()}
  def generate_solution(analysis, requirements, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(__MODULE__, {:generate, analysis, requirements, opts}, timeout + 1000)
  end

  @doc """
  Fix code based on error analysis.

  ## Parameters
  - error_analysis: Error analysis (from Gemini)
  - affected_files: Files that need fixing
  - opts: Options

  ## Returns
  - {:ok, fix_response}
  - {:error, reason}
  """
  @spec generate_fix(map(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def generate_fix(error_analysis, affected_files, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(__MODULE__, {:fix, error_analysis, affected_files, opts}, timeout + 1000)
  end

  @doc """
  Reason about a problem and propose solutions.

  ## Parameters
  - problem: Problem description
  - context: Relevant context
  - opts: Options

  ## Returns
  - {:ok, reasoning_response}
  - {:error, reason}
  """
  @spec reason(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def reason(problem, context, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    GenServer.call(__MODULE__, {:reason, problem, context, opts}, timeout + 1000)
  end

  @doc """
  Check if Claude API is configured and available.
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
    Logger.info("[ClaudeInterface] Initializing Claude reasoning engine - SC-AI-001")

    openrouter_key =
      Application.get_env(:indrajaal, :ai, [])[:openrouter_key] ||
        System.get_env("OPENROUTER_API_KEY")

    api_key = Keyword.get(opts, :api_key) || openrouter_key || System.get_env("ANTHROPIC_API_KEY")

    state = %{
      api_key: api_key,
      model: Keyword.get(opts, :model, @default_model),
      available: api_key != nil and api_key != "",
      # Statistics
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      guardian_vetoes: 0,
      total_tokens: 0,
      last_request: nil,
      started_at: DateTime.utc_now()
    }

    if state.available do
      Logger.info("[ClaudeInterface] API key configured - Claude available")
    else
      Logger.warning("[ClaudeInterface] No API key - running in mock mode")
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:generate, analysis, requirements, opts}, _from, state) do
    guardian_validate = Keyword.get(opts, :guardian_validate, true)
    constraints = Keyword.get(opts, :constraints, [])

    result =
      if state.available do
        perform_generation(analysis, requirements, constraints, state)
      else
        mock_generation(analysis, requirements)
      end

    # Guardian validation if enabled
    final_result =
      case result do
        {:ok, response} when guardian_validate ->
          validate_with_guardian(response, state)

        other ->
          other
      end

    new_state = update_stats(state, final_result)
    stream_telemetry(:generate, final_result)

    {:reply, final_result, new_state}
  end

  @impl true
  def handle_call({:fix, error_analysis, affected_files, opts}, _from, state) do
    guardian_validate = Keyword.get(opts, :guardian_validate, true)

    result =
      if state.available do
        perform_fix_generation(error_analysis, affected_files, state)
      else
        mock_fix_generation(error_analysis, affected_files)
      end

    final_result =
      case result do
        {:ok, response} when guardian_validate ->
          validate_with_guardian(response, state)

        other ->
          other
      end

    new_state = update_stats(state, final_result)
    stream_telemetry(:fix, final_result)

    {:reply, final_result, new_state}
  end

  @impl true
  def handle_call({:reason, problem, context, _opts}, _from, state) do
    result =
      if state.available do
        perform_reasoning(problem, context, state)
      else
        mock_reasoning(problem, context)
      end

    new_state = update_stats(state, result)
    stream_telemetry(:reason, result)

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
      guardian_vetoes: state.guardian_vetoes,
      total_tokens: state.total_tokens,
      last_request: state.last_request,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  # ============================================================
  # PRIVATE - API CALLS
  # ============================================================

  defp perform_generation(analysis, requirements, constraints, state) do
    prompt = build_generation_prompt(analysis, requirements, constraints)

    case call_claude_api(prompt, state.api_key, state.model) do
      {:ok, response} ->
        parse_generation_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_fix_generation(error_analysis, affected_files, state) do
    file_contents = read_files(affected_files)
    prompt = build_fix_prompt(error_analysis, file_contents)

    case call_claude_api(prompt, state.api_key, state.model) do
      {:ok, response} ->
        parse_fix_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp perform_reasoning(problem, context, state) do
    prompt = build_reasoning_prompt(problem, context)

    case call_claude_api(prompt, state.api_key, state.model) do
      {:ok, response} ->
        parse_reasoning_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call_claude_api(prompt, _api_key, model) do
    # Map models to OpenRouter
    model_id =
      case model do
        # Use OpenRouterClient's smart alias (Claude 3.5 Sonnet)
        "claude-sonnet-4-20_250_514" -> :smart
        other -> other
      end

    # P0-CRITICAL: Full pre-flight Guardian + Graph verification (SC-NEURO-001, SC-GVF-003)
    # This implements the proper Simplex Architecture flow:
    # 1. Guardian validates the AI request BEFORE execution
    # 2. Graph verification ensures routing constraints
    # 3. Only then proceed with the actual API call
    with {:ok, %{guardian_approved: true}} <-
           OpenRouterClient.full_pre_flight_check(:claude_interface, model_id, prompt) do
      # Guardian approved + Graph verified - proceed with API call
      messages = [
        %{role: "user", content: prompt}
      ]

      case OpenRouterClient.chat(messages, model: model_id) do
        {:ok, content} ->
          {:ok, content}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, {:guardian_veto, reason, _fallback}} ->
        Logger.error("🛡️ [ClaudeInterface] Guardian pre-flight VETO: #{inspect(reason)}")
        {:error, {:guardian_pre_flight_veto, reason}}

      {:error, {:guardian_unavailable, _error}} ->
        # Fail safe: if Guardian is unavailable, deny the request
        Logger.error("🚫 [ClaudeInterface] Guardian unavailable - request denied (SC-NEURO-001)")
        {:error, :guardian_unavailable}

      {:error, reason} ->
        Logger.error("🚫 [ClaudeInterface] SC-GVF verification failed: #{inspect(reason)}")
        {:error, {:graph_verification_failed, reason}}
    end
  end

  # ============================================================
  # PRIVATE - GUARDIAN VALIDATION
  # ============================================================

  defp validate_with_guardian(response, _state) do
    proposal = %{
      action: :exec_code,
      code: Map.get(response, :code, ""),
      source: :claude_interface
    }

    case Guardian.validate_proposal(proposal) do
      {:ok, _} ->
        {:ok, Map.put(response, :guardian_approved, true)}

      {:veto, reason, fallback} ->
        Logger.warning("[ClaudeInterface] Guardian vetoed proposal: #{inspect(reason)}")
        {:veto, reason, fallback}
    end
  end

  # ============================================================
  # PRIVATE - MOCK RESPONSES
  # ============================================================

  defp mock_generation(analysis, requirements) do
    {:ok,
     %{
       code: """
       # Mock generated code - ANTHROPIC_API_KEY not configured
       # Requirements: #{requirements}
       # Analysis summary: #{Map.get(analysis, :summary, "N/A")}

       defmodule MockGenerated do
         @moduledoc "Auto-generated mock module"

         def mock_function do
           :ok
         end
       end
       """,
       explanation: "This is a mock response. Configure ANTHROPIC_API_KEY for real generation.",
       files_to_modify: [],
       confidence: 0.0,
       guardian_approved: false,
       mock: true
     }}
  end

  defp mock_fix_generation(error_analysis, affected_files) do
    {:ok,
     %{
       code: "# Mock fix - API not available",
       fixes:
         Enum.map(affected_files, fn f ->
           %{file: f, changes: ["Mock change"]}
         end),
       explanation: "Mock fix for: #{Map.get(error_analysis, :root_cause, "unknown")}",
       confidence: 0.0,
       guardian_approved: false,
       mock: true
     }}
  end

  defp mock_reasoning(problem, _context) do
    {:ok,
     %{
       problem: problem,
       analysis: "Mock reasoning - API not available",
       solutions: [
         %{
           approach: "Configure ANTHROPIC_API_KEY",
           pros: ["Enables real reasoning"],
           cons: ["Requires API key"],
           confidence: 0.0
         }
       ],
       recommendation: "Configure API key for real reasoning",
       mock: true
     }}
  end

  # ============================================================
  # PRIVATE - PROMPT BUILDING
  # ============================================================

  defp build_generation_prompt(analysis, requirements, constraints) do
    constraints_text =
      if Enum.empty?(constraints) do
        ""
      else
        "\n## STAMP Constraints\n" <> Enum.map_join(constraints, "\n", &"- #{&1}")
      end

    """
    You are an expert Elixir developer following the Indrajaal SOPv5.11 framework.

    ## Context Analysis
    #{format_analysis(analysis)}

    ## Requirements
    #{requirements}
    #{constraints_text}

    ## Instructions
    Generate production-ready Elixir code that:
    1. Follows Ash 3.x patterns and BaseResource conventions
    2. Includes proper @moduledoc with WHAT/WHY/CONSTRAINTS
    3. Uses proper error handling
    4. Is safe for production (no security vulnerabilities)

    Format your response as JSON:
    ```json
    {
      "code": "defmodule ... end",
      "explanation": "What this code does and why",
      "files_to_modify": ["path/to/file.ex"],
      "confidence": 0.85
    }
    ```
    """
  end

  defp build_fix_prompt(error_analysis, file_contents) do
    """
    You are an expert Elixir debugger following the Indrajaal SOPv5.11 framework.

    ## Error Analysis
    - Type: #{Map.get(error_analysis, :error_type, :unknown)}
    - Root Cause: #{Map.get(error_analysis, :root_cause, "Unknown")}
    - Suggested Fixes: #{inspect(Map.get(error_analysis, :suggested_fixes, []))}

    ## Affected Files
    #{format_file_contents(file_contents)}

    ## Instructions
    Generate fixes that:
    1. Address the root cause
    2. Follow existing code patterns
    3. Include proper error handling
    4. Are minimal and focused

    Format your response as JSON:
    ```json
    {
      "fixes": [
        {"file": "path.ex", "old_code": "...", "new_code": "...", "explanation": "..."}
      ],
      "confidence": 0.85
    }
    ```
    """
  end

  defp build_reasoning_prompt(problem, context) do
    """
    You are an expert system architect reasoning about a problem.

    ## Problem
    #{problem}

    ## Context
    #{inspect(context)}

    ## Instructions
    Analyze the problem and propose solutions:
    1. Break down the problem
    2. Consider multiple approaches
    3. Evaluate trade-offs
    4. Recommend best approach

    Format your response as JSON:
    ```json
    {
      "analysis": "Problem breakdown...",
      "solutions": [
        {"approach": "...", "pros": [...], "cons": [...], "confidence": 0.85}
      ],
      "recommendation": "Best approach and why"
    }
    ```
    """
  end

  # ============================================================
  # PRIVATE - RESPONSE PARSING
  # ============================================================

  defp parse_generation_response(text) do
    case extract_json(text) do
      {:ok, data} ->
        {:ok,
         %{
           code: Map.get(data, "code", ""),
           explanation: Map.get(data, "explanation", ""),
           files_to_modify: Map.get(data, "files_to_modify", []),
           confidence: Map.get(data, "confidence", 0.5),
           guardian_approved: false
         }}

      {:error, _} ->
        {:ok,
         %{
           code: text,
           explanation: "",
           files_to_modify: [],
           confidence: 0.3,
           guardian_approved: false
         }}
    end
  end

  defp parse_fix_response(text) do
    case extract_json(text) do
      {:ok, data} ->
        {:ok,
         %{
           fixes: Map.get(data, "fixes", []),
           confidence: Map.get(data, "confidence", 0.5),
           guardian_approved: false
         }}

      {:error, _} ->
        {:ok,
         %{
           fixes: [],
           code: text,
           confidence: 0.3,
           guardian_approved: false
         }}
    end
  end

  defp parse_reasoning_response(text) do
    case extract_json(text) do
      {:ok, data} ->
        {:ok,
         %{
           analysis: Map.get(data, "analysis", ""),
           solutions: Map.get(data, "solutions", []),
           recommendation: Map.get(data, "recommendation", "")
         }}

      {:error, _} ->
        {:ok,
         %{
           analysis: text,
           solutions: [],
           recommendation: ""
         }}
    end
  end

  defp extract_json(text) do
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

  defp format_analysis(analysis) when is_map(analysis) do
    """
    Summary: #{Map.get(analysis, :summary, "N/A")}
    Insights: #{inspect(Map.get(analysis, :insights, []))}
    References: #{inspect(Map.get(analysis, :references, []))}
    """
  end

  defp format_analysis(_), do: "No analysis provided"

  defp format_file_contents(file_contents) do
    Enum.map_join(file_contents, "\n\n", fn {path, content} ->
      """
      ### #{path}
      ```elixir
      #{String.slice(content, 0..5000)}
      ```
      """
    end)
  end

  defp update_stats(state, result) do
    {successful, failed, vetoes} =
      case result do
        {:ok, _} ->
          {state.successful_requests + 1, state.failed_requests, state.guardian_vetoes}

        {:veto, _, _} ->
          {state.successful_requests, state.failed_requests, state.guardian_vetoes + 1}

        {:error, _} ->
          {state.successful_requests, state.failed_requests + 1, state.guardian_vetoes}
      end

    %{
      state
      | total_requests: state.total_requests + 1,
        successful_requests: successful,
        failed_requests: failed,
        guardian_vetoes: vetoes,
        last_request: DateTime.utc_now()
    }
  end

  defp stream_telemetry(operation, result) do
    status =
      case result do
        {:ok, _} -> :success
        {:veto, _, _} -> :vetoed
        {:error, _} -> :failure
      end

    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_metric(:claude, operation, 1, %{status: status})
    end
  rescue
    _ -> :ok
  end
end
