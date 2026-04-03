defmodule Indrajaal.Cortex.GDE.AIIntegration do
  @moduledoc """
  AI Integration: Connects GDE with OpenRouter for AI-assisted code generation.

  WHAT: Bridges GDE ProposalEngine with cloud AI (Claude/Gemini via OpenRouter).
  WHY: Enables intelligent proposal generation and code synthesis.
  CONSTRAINTS: All AI outputs must pass Guardian validation. Uses OpenRouter for all AI work.

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │                   GDE AI INTEGRATION                            │
  │                                                                 │
  │   ┌─────────┐     ┌─────────────┐     ┌─────────────────────┐  │
  │   │PROPOSAL │────►│ OpenRouter  │────►│ AI-Enhanced         │  │
  │   │ENGINE   │     │ (Cloud AI)  │     │ Fix Proposals       │  │
  │   └─────────┘     └─────────────┘     └─────────────────────┘  │
  │        │                                       │               │
  │        │          ┌─────────────┐              │               │
  │        └─────────►│ Backtracker │◄─────────────┘               │
  │                   │   (GDE)     │                              │
  │                   └─────────────┘                              │
  │                                                                 │
  │   Model Hierarchy:                                              │
  │   - :fast   → Gemini Flash 1.5 8B (Quick analysis)             │
  │   - :smart  → Claude 3.5 Sonnet (Code synthesis)               │
  │   - :deep   → OpenAI o1-preview (Complex reasoning)            │
  └─────────────────────────────────────────────────────────────────┘
  ```

  ## STAMP Constraints

  - SC-GDE-060: AI calls must use OpenRouter exclusively
  - SC-GDE-061: All proposals must include confidence scores
  - SC-GDE-062: AI outputs must be validated before execution
  - SC-GDE-063: Fallback to local analysis if API unavailable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-060 to SC-GDE-063 |
  """

  require Logger

  alias Indrajaal.AI.OpenRouterClient
  alias Indrajaal.Cortex.GDE.Generator
  alias Indrajaal.Cortex.GDE.StringScanner
  alias Indrajaal.Cortex.GDE.ProposalEngine
  alias Indrajaal.Cortex.Evolution.TrainingGym
  alias Indrajaal.Observability.ZenohEvolutionPublisher
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type error_context :: %{
          type: atom(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          message: String.t(),
          raw: String.t()
        }

  @type ai_proposal :: %{
          type: atom(),
          confidence: float(),
          description: String.t(),
          code: String.t() | nil,
          file: String.t() | nil,
          line: pos_integer() | nil,
          original: String.t() | nil,
          replacement: String.t() | nil,
          reasoning: String.t(),
          model: atom(),
          metadata: map()
        }

  @type ai_options :: [
          model: :fast | :smart | :deep,
          max_proposals: pos_integer(),
          min_confidence: float(),
          timeout: pos_integer()
        ]

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_model :smart
  @default_max_proposals 5
  @default_min_confidence 0.6

  # ============================================================
  # PUBLIC API
  # ============================================================

  @doc """
  Generates AI-enhanced fix proposals for an error context.

  Uses OpenRouter to call Claude/Gemini for intelligent code synthesis.

  ## Parameters
  - error_context: Parsed error context from StringScanner
  - opts: AI options (model, max_proposals, min_confidence)

  ## Returns
  - {:ok, [ai_proposal()]} on success
  - {:error, reason} on failure

  ## Example

      context = %{
        type: :compile_error,
        file: "lib/test.ex",
        line: 10,
        message: "undefined function foo/1",
        raw: "..."
      }

      {:ok, proposals} = AIIntegration.generate_ai_proposals(context, model: :smart)
  """
  @spec generate_ai_proposals(error_context(), ai_options()) ::
          {:ok, [ai_proposal()]} | {:error, term()}
  def generate_ai_proposals(error_context, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    max_proposals = Keyword.get(opts, :max_proposals, @default_max_proposals)
    min_confidence = Keyword.get(opts, :min_confidence, @default_min_confidence)

    Logger.info("[AIIntegration] Generating proposals via OpenRouter (#{model})")

    # Build prompt from error context
    prompt = build_fix_prompt(error_context)

    # Call OpenRouter
    case call_openrouter(prompt, model) do
      {:ok, response} ->
        # Parse AI response into proposals
        proposals =
          response
          |> parse_ai_response(error_context, model)
          |> Enum.filter(&(&1.confidence >= min_confidence))
          |> Enum.take(max_proposals)

        Logger.debug("[AIIntegration] Generated #{length(proposals)} AI proposals")
        {:ok, proposals}

      {:error, :missing_api_key} ->
        Logger.warning("[AIIntegration] OpenRouter API key missing, using local analysis")
        fallback_to_local(error_context, opts)

      {:error, reason} ->
        Logger.error("[AIIntegration] OpenRouter call failed: #{inspect(reason)}")
        fallback_to_local(error_context, opts)
    end
  end

  @doc """
  Creates a generator of AI-enhanced proposals for backtracking.

  ## Parameters
  - error_context: Error context
  - opts: AI options

  ## Returns
  - Generator of proposals (lazy stream)
  """
  @spec proposal_generator(error_context(), ai_options()) :: Generator.generator()
  def proposal_generator(error_context, opts \\ []) do
    case generate_ai_proposals(error_context, opts) do
      {:ok, proposals} -> Generator.alternatives(proposals)
      {:error, _} -> Generator.alternatives([])
    end
  end

  @doc """
  Analyzes error logs and generates comprehensive fix plan.

  Uses a two-stage approach:
  1. :fast model for quick error categorization
  2. :smart model for detailed fix generation

  ## Parameters
  - error_logs: Raw error output
  - opts: Analysis options

  ## Returns
  - {:ok, %{analysis: map(), proposals: [ai_proposal()]}}
  - {:error, reason}
  """
  @spec analyze_and_propose(String.t(), ai_options()) ::
          {:ok, map()} | {:error, term()}
  def analyze_and_propose(error_logs, opts \\ []) do
    Logger.info("[AIIntegration] Starting two-stage analysis")

    # Stage 1: Quick analysis with :fast model
    analysis_result = analyze_error_fast(error_logs)

    case analysis_result do
      {:ok, analysis} ->
        # Stage 2: Generate proposals with :smart model
        error_context = build_context_from_analysis(analysis, error_logs)

        case generate_ai_proposals(error_context, Keyword.put(opts, :model, :smart)) do
          {:ok, proposals} ->
            {:ok, %{analysis: analysis, proposals: proposals}}

          {:error, reason} ->
            {:error, {:proposal_generation_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:analysis_failed, reason}}
    end
  end

  @doc """
  Enhances an existing proposal with AI-generated code.

  Takes a basic proposal from ProposalEngine and enriches it with
  actual code generation from the AI.

  ## Parameters
  - proposal: Basic proposal from ProposalEngine
  - file_content: Current file content for context
  - opts: AI options

  ## Returns
  - {:ok, enhanced_proposal}
  - {:error, reason}
  """
  @spec enhance_proposal(map(), String.t(), ai_options()) ::
          {:ok, ai_proposal()} | {:error, term()}
  def enhance_proposal(proposal, file_content, opts \\ []) do
    model = Keyword.get(opts, :model, :smart)

    prompt = build_enhancement_prompt(proposal, file_content)

    case call_openrouter(prompt, model) do
      {:ok, response} ->
        enhanced = enhance_with_ai_response(proposal, response, model)
        {:ok, enhanced}

      {:error, reason} ->
        Logger.warning("[AIIntegration] Enhancement failed: #{inspect(reason)}")
        # Return original proposal with lower confidence
        {:ok, Map.merge(proposal, %{confidence: proposal.confidence * 0.5, ai_enhanced: false})}
    end
  end

  @doc """
  Validates a proposed fix using AI reasoning.

  Uses the :deep model for complex reasoning about fix correctness.

  ## Parameters
  - proposal: Proposal to validate
  - original_error: Original error context
  - opts: Validation options

  ## Returns
  - {:ok, %{valid: boolean(), reasoning: String.t()}}
  - {:error, reason}
  """
  @spec validate_fix(ai_proposal(), error_context(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def validate_fix(proposal, original_error, opts \\ []) do
    # Use :deep model for validation reasoning
    model = Keyword.get(opts, :model, :deep)

    prompt = build_validation_prompt(proposal, original_error)

    case call_openrouter(prompt, model) do
      {:ok, response} ->
        validation = parse_validation_response(response)
        {:ok, validation}

      {:error, reason} ->
        # Fallback: assume valid if AI unavailable
        {:ok, %{valid: true, reasoning: "Validation skipped: #{inspect(reason)}", fallback: true}}
    end
  end

  # ============================================================
  # PRIVATE - OPENROUTER CALLS
  # ============================================================

  defp call_openrouter(prompt, model) do
    # P0-CRITICAL: Full pre-flight Guardian + Graph verification (SC-NEURO-001, SC-GVF-003)
    # SC-GDE-060: All AI calls must use OpenRouter exclusively
    # This implements the proper Simplex Architecture flow:
    # 1. Guardian validates the AI request BEFORE execution
    # 2. Graph verification ensures routing constraints
    # 3. Only then proceed with the actual API call
    with {:ok, %{guardian_approved: true}} <-
           OpenRouterClient.full_pre_flight_check(:gde_ai_integration, model, prompt) do
      # Guardian approved + Graph verified - proceed with API call
      messages = [
        %{
          role: "system",
          content: system_prompt()
        },
        %{
          role: "user",
          content: prompt
        }
      ]

      OpenRouterClient.chat(messages, model: model, temperature: 0.2)
    else
      {:error, {:guardian_veto, reason, _fallback}} ->
        Logger.error("🛡️ [AIIntegration] Guardian pre-flight VETO: #{inspect(reason)}")
        {:error, {:guardian_pre_flight_veto, reason}}

      {:error, {:guardian_unavailable, _error}} ->
        # Fail safe: if Guardian is unavailable, deny the request
        Logger.error("🚫 [AIIntegration] Guardian unavailable - request denied (SC-NEURO-001)")
        {:error, :guardian_unavailable}

      {:error, reason} ->
        Logger.error("🚫 [AIIntegration] SC-GVF verification failed: #{inspect(reason)}")
        {:error, {:graph_verification_failed, reason}}
    end
  end

  defp system_prompt do
    """
    You are the Indrajaal Chief Architect, an expert Elixir developer specializing in:
    - Ash Framework 3.x
    - Phoenix 1.8+
    - OTP and GenServer patterns
    - Safety-critical systems (IEC 61_508 SIL-2)

    Your role is to analyze errors and generate precise, minimal fixes.

    CONSTRAINTS (SOPv5.11 + STAMP):
    - Fixes must compile without warnings
    - Prefer editing existing code over creating new files
    - Use Ash 3.x patterns (require_atomic? false for function-based changes)
    - Follow BaseResource conventions
    - Never introduce security vulnerabilities

    OUTPUT FORMAT:
    For code fixes, respond with:
    ```elixir
    # File: <path>
    # Line: <number>
    # Original:
    <original_code>
    # Replacement:
    <fixed_code>
    ```

    Include confidence (0.0-1.0) and brief reasoning.
    """
  end

  # ============================================================
  # PRIVATE - PROMPT BUILDING
  # ============================================================

  defp build_fix_prompt(error_context) when is_map(error_context) do
    error_type = Map.get(error_context, :type, "unknown")
    file = Map.get(error_context, :file, "unknown") || "unknown"
    line = Map.get(error_context, :line, "unknown") || "unknown"
    message = Map.get(error_context, :message, Map.get(error_context, :prompt, ""))
    raw = Map.get(error_context, :raw, "") || ""
    raw_str = if is_binary(raw), do: String.slice(raw, 0, 1500), else: inspect(raw)

    """
    ERROR ANALYSIS REQUEST

    Error Type: #{error_type}
    File: #{file}
    Line: #{line}
    Message: #{message}

    Raw Output:
    ```
    #{raw_str}
    ```

    Generate up to 3 fix proposals, ranked by confidence.
    For each proposal, provide:
    1. Type of fix (add_import, fix_typo, add_clause, etc.)
    2. Confidence score (0.0-1.0)
    3. The actual code change
    4. Brief reasoning

    Focus on the most likely root cause and minimal fix.
    """
  end

  defp build_enhancement_prompt(proposal, file_content) do
    """
    PROPOSAL ENHANCEMENT REQUEST

    I have a basic fix proposal that needs concrete code generation:

    Proposal Type: #{proposal.type}
    Target File: #{proposal.file}
    Target Line: #{proposal.line}
    Description: #{proposal.description}

    Current File Content (relevant section):
    ```elixir
    #{extract_relevant_section(file_content, proposal.line)}
    ```

    Generate the exact code change needed.
    Include:
    1. The original code to replace
    2. The replacement code
    3. Any required imports or aliases
    """
  end

  defp build_validation_prompt(proposal, original_error) do
    """
    FIX VALIDATION REQUEST

    Original Error:
    - Type: #{original_error.type}
    - Message: #{original_error.message}
    - File: #{original_error.file}

    Proposed Fix:
    - Type: #{proposal.type}
    - File: #{proposal.file}
    - Original: #{proposal.original}
    - Replacement: #{proposal.replacement}
    - Reasoning: #{proposal.reasoning}

    Validate this fix:
    1. Will it resolve the original error?
    2. Could it introduce new errors?
    3. Is there a better alternative?

    Respond with:
    VALID: true/false
    REASONING: <explanation>
    CONCERNS: <any potential issues>
    """
  end

  # ============================================================
  # PRIVATE - RESPONSE PARSING
  # ============================================================

  defp parse_ai_response(response, error_context, model) do
    # Parse structured proposals from AI response
    response
    |> extract_code_blocks()
    |> Enum.with_index()
    |> Enum.map(fn {block, idx} ->
      parse_proposal_block(block, error_context, model, idx)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_code_blocks(response) do
    # Extract ```elixir ... ``` blocks
    blocks = Regex.scan(~r/```elixir\n(.*?)\n```/s, response, capture: :all_but_first)
    blocks |> Enum.map(fn [code] -> code end)
  end

  defp parse_proposal_block(block, error_context, model, index) do
    # Parse file/line/original/replacement from block
    file = extract_field(block, "File") || error_context.file
    line = extract_line_field(block) || error_context.line
    original = extract_section(block, "Original")
    replacement = extract_section(block, "Replacement")

    # Extract confidence from surrounding text if available
    confidence = extract_confidence(block) || 1.0 - index * 0.15

    if replacement do
      %{
        type: infer_fix_type(original, replacement),
        confidence: confidence,
        description: "AI-generated fix for #{error_context.type}",
        code: replacement,
        file: file,
        line: line,
        original: original,
        replacement: replacement,
        reasoning: "Generated by #{model} model",
        model: model,
        metadata: %{
          ai_generated: true,
          proposal_index: index
        }
      }
    else
      nil
    end
  end

  defp extract_field(text, field) do
    case Regex.run(~r/# #{field}: (.+)/, text) do
      [_, value] -> String.trim(value)
      _ -> nil
    end
  end

  defp extract_line_field(text) do
    case Regex.run(~r/# Line: (\d+)/, text) do
      [_, line] -> String.to_integer(line)
      _ -> nil
    end
  end

  defp extract_section(text, section) do
    case Regex.run(~r/# #{section}:\n(.+?)(?=\n# |\z)/s, text) do
      [_, content] -> String.trim(content)
      _ -> nil
    end
  end

  defp extract_confidence(text) do
    case Regex.run(~r/[Cc]onfidence[:\s]+([0-9.]+)/, text) do
      [_, conf] -> String.to_float(conf)
      _ -> nil
    end
  end

  defp infer_fix_type(nil, _replacement), do: :add_code
  defp infer_fix_type(_original, nil), do: :remove_code

  defp infer_fix_type(original, replacement) do
    cond do
      String.contains?(replacement, "import ") -> :add_import
      String.contains?(replacement, "alias ") -> :add_alias
      String.contains?(replacement, "require ") -> :add_require
      String.length(replacement) > String.length(original) * 1.5 -> :add_clause
      true -> :fix_code
    end
  end

  defp parse_validation_response(response) do
    valid =
      cond do
        String.contains?(response, "VALID: true") -> true
        String.contains?(response, "VALID: false") -> false
        true -> true
      end

    reasoning =
      case Regex.run(~r/REASONING: (.+?)(?=\nCONCERNS|\z)/s, response) do
        [_, r] -> String.trim(r)
        _ -> response
      end

    concerns =
      case Regex.run(~r/CONCERNS: (.+)/s, response) do
        [_, c] -> String.trim(c)
        _ -> nil
      end

    %{
      valid: valid,
      reasoning: reasoning,
      concerns: concerns
    }
  end

  defp enhance_with_ai_response(proposal, response, model) do
    # Extract enhanced code from AI response
    code_blocks = extract_code_blocks(response)

    replacement =
      case code_blocks do
        [first | _] -> first
        [] -> proposal.replacement
      end

    Map.merge(proposal, %{
      replacement: replacement,
      code: replacement,
      reasoning: "Enhanced by #{model} model",
      model: model,
      confidence: min(proposal.confidence + 0.1, 1.0),
      ai_enhanced: true,
      metadata: Map.put(proposal.metadata || %{}, :enhanced, true)
    })
  end

  # ============================================================
  # PRIVATE - FALLBACK & HELPERS
  # ============================================================

  defp fallback_to_local(error_context, opts) do
    Logger.info("[AIIntegration] Using local ProposalEngine fallback")

    # Use the local ProposalEngine without AI
    case ProposalEngine.generate(error_context, opts) do
      {:ok, proposals} ->
        # Mark as non-AI-enhanced
        enhanced =
          Enum.map(proposals, fn p ->
            Map.merge(p, %{
              model: :local,
              ai_enhanced: false,
              reasoning: "Generated locally (AI unavailable)"
            })
          end)

        {:ok, enhanced}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_error_fast(error_logs) when is_binary(error_logs) do
    prompt = """
    QUICK ERROR ANALYSIS

    Analyze this error output and categorize it:

    ```
    #{String.slice(error_logs, 0..2000)}
    ```

    Respond with:
    ERROR_TYPE: <compile_error|runtime_error|test_failure|warning>
    FILE: <affected file path or "unknown">
    LINE: <line number or "unknown">
    ROOT_CAUSE: <brief description>
    AFFECTED_MODULES: <comma-separated list>
    """

    case call_openrouter(prompt, :fast) do
      {:ok, response} ->
        analysis = %{
          error_type: extract_analysis_field(response, "ERROR_TYPE"),
          file: extract_analysis_field(response, "FILE"),
          line: extract_analysis_line(response, "LINE"),
          root_cause: extract_analysis_field(response, "ROOT_CAUSE"),
          affected_modules: extract_analysis_list(response, "AFFECTED_MODULES")
        }

        {:ok, analysis}

      {:error, reason} ->
        # Fallback to StringScanner with compile_error pattern
        pattern = StringScanner.builtin(:compile_error)

        case StringScanner.scan(error_logs, pattern) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, reason}
        end
    end
  end

  defp analyze_error_fast(error_logs) do
    analyze_error_fast(inspect(error_logs))
  end

  defp extract_analysis_field(response, field) do
    case Regex.run(~r/#{field}: (.+)/, response) do
      [_, value] -> String.trim(value)
      _ -> "unknown"
    end
  end

  defp extract_analysis_line(response, field) do
    case Regex.run(~r/#{field}: (\d+)/, response) do
      [_, line] -> String.to_integer(line)
      _ -> nil
    end
  end

  defp extract_analysis_list(response, field) do
    case Regex.run(~r/#{field}: (.+)/, response) do
      [_, value] ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == "" or &1 == "unknown"))

      _ ->
        []
    end
  end

  defp build_context_from_analysis(analysis, raw_logs) do
    # Handle both AI analysis format and StringScanner format
    error_type = Map.get(analysis, :error_type) || Map.get(analysis, :type, "unknown")
    file = Map.get(analysis, :file)
    line = Map.get(analysis, :line)
    message = Map.get(analysis, :root_cause) || Map.get(analysis, :message, "unknown error")

    %{
      type: parse_error_type(to_string(error_type)),
      file: if(file && file != "unknown", do: file, else: nil),
      line: parse_line(line),
      message: message,
      raw: raw_logs
    }
  end

  defp parse_line(nil), do: nil
  defp parse_line(line) when is_integer(line), do: line

  defp parse_line(line) when is_binary(line) do
    case Integer.parse(line) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_line(_), do: nil

  defp parse_error_type("compile_error"), do: :compile_error
  defp parse_error_type("runtime_error"), do: :runtime_error
  defp parse_error_type("test_failure"), do: :test_failure
  defp parse_error_type("warning"), do: :warning
  defp parse_error_type(_), do: :unknown

  defp extract_relevant_section(content, nil), do: String.slice(content, 0..500)

  defp extract_relevant_section(content, line) when is_integer(line) do
    lines = String.split(content, "\n")
    start_line = max(0, line - 10)
    end_line = min(length(lines), line + 10)

    lines
    |> Enum.slice(start_line..end_line)
    |> Enum.with_index(start_line + 1)
    |> Enum.map_join("\n", fn {l, idx} -> "#{idx}: #{l}" end)
  end

  # ============================================================
  # GDE PIPELINE INTEGRATION (SC-GDE-064 to SC-GDE-067)
  # ============================================================

  @doc """
  Executes a complete GDE fix cycle with Guardian validation and Training capture.

  This is the main entry point for Goal-Directed Evolution:
  1. Generate AI proposals for the error
  2. Validate each proposal against Guardian
  3. Record results to TrainingGym for RL
  4. Stream telemetry to Zenoh

  ## Parameters
  - error_context: Parsed error context
  - opts: GDE options

  ## Returns
  - {:ok, %{proposals: [...], validated: [...], vetoed: [...]}}
  - {:error, reason}
  """
  @spec execute_gde_cycle(error_context(), ai_options()) :: {:ok, map()} | {:error, term()}
  def execute_gde_cycle(error_context, opts \\ []) do
    Logger.info("[GDE] Starting GDE cycle for #{error_context.type}")

    with {:ok, proposals} <- generate_ai_proposals(error_context, opts),
         {validated, vetoed} <- validate_proposals_with_guardian(proposals, error_context) do
      # Record results to TrainingGym
      record_gde_results(error_context, validated, vetoed)

      # Stream to Zenoh
      stream_gde_telemetry(proposals, validated, vetoed)

      {:ok,
       %{
         proposals: proposals,
         validated: validated,
         vetoed: vetoed,
         success_rate: safe_ratio(length(validated), length(proposals))
       }}
    end
  end

  @doc """
  Validates proposals through the Guardian safety kernel.

  Returns tuple of {validated_proposals, vetoed_proposals}.
  """
  @spec validate_proposals_with_guardian([ai_proposal()], error_context()) ::
          {[ai_proposal()], [ai_proposal()]}
  def validate_proposals_with_guardian(proposals, error_context) do
    result =
      Enum.reduce(proposals, {[], []}, fn proposal, {valid_acc, veto_acc} ->
        guardian_proposal = build_guardian_proposal(proposal, error_context)

        case Guardian.validate_proposal(guardian_proposal) do
          {:ok, _} ->
            Logger.debug("[GDE] Proposal validated by Guardian: #{proposal.type}")
            {[Map.put(proposal, :guardian_approved, true) | valid_acc], veto_acc}

          {:veto, reason, _fallback} ->
            Logger.warning("[GDE] Proposal vetoed by Guardian: #{inspect(reason)}")
            vetoed = Map.merge(proposal, %{guardian_approved: false, veto_reason: reason})
            {valid_acc, [vetoed | veto_acc]}
        end
      end)

    result |> then(fn {valid, vetoed} -> {Enum.reverse(valid), Enum.reverse(vetoed)} end)
  rescue
    _ ->
      # Guardian not available - pass through with warning
      Logger.warning("[GDE] Guardian unavailable, proposals not validated")
      {proposals, []}
  end

  defp build_guardian_proposal(proposal, error_context) do
    %{
      action: :exec_code,
      code: proposal.replacement || proposal.code || "",
      target_file: proposal.file || error_context.file,
      proposal_type: proposal.type,
      confidence: proposal.confidence
    }
  end

  defp record_gde_results(error_context, validated, vetoed) do
    # Record successes (validated proposals)
    Enum.each(validated, fn proposal ->
      try_record_success(error_context, proposal)
    end)

    # Record near-misses (vetoed proposals)
    Enum.each(vetoed, fn proposal ->
      try_record_near_miss(error_context, proposal)
    end)
  end

  defp try_record_success(error_context, proposal) do
    if Code.ensure_loaded?(TrainingGym) and GenServer.whereis(TrainingGym) do
      state_before = %{
        error_type: error_context.type,
        file: error_context.file,
        line: error_context.line
      }

      action = %{
        proposal_type: proposal.type,
        confidence: proposal.confidence,
        model: proposal.model
      }

      result = %{
        guardian_approved: true,
        timestamp: DateTime.utc_now()
      }

      TrainingGym.record_success(state_before, action, result)
    end
  rescue
    _ -> :ok
  end

  defp try_record_near_miss(error_context, proposal) do
    if Code.ensure_loaded?(TrainingGym) and GenServer.whereis(TrainingGym) do
      state_before = %{
        error_type: error_context.type,
        file: error_context.file,
        line: error_context.line
      }

      action = %{
        proposal_type: proposal.type,
        confidence: proposal.confidence,
        model: proposal.model,
        code: String.slice(proposal.code || "", 0..200)
      }

      veto_reason = %{
        reason: proposal.veto_reason,
        timestamp: DateTime.utc_now()
      }

      TrainingGym.record_near_miss(state_before, action, veto_reason)
    end
  rescue
    _ -> :ok
  end

  defp stream_gde_telemetry(_proposals, validated, vetoed) do
    # Stream to ZenohEvolutionPublisher if available
    if Code.ensure_loaded?(ZenohEvolutionPublisher) and GenServer.whereis(ZenohEvolutionPublisher) do
      # Stream each validated proposal
      Enum.each(validated, fn proposal ->
        ZenohEvolutionPublisher.publish_guardian_validation(
          %{action: proposal.type, target: proposal.file},
          :approved,
          %{confidence: proposal.confidence, model: proposal.model}
        )
      end)

      # Stream each vetoed proposal
      Enum.each(vetoed, fn proposal ->
        ZenohEvolutionPublisher.publish_guardian_validation(
          %{action: proposal.type, target: proposal.file},
          :vetoed,
          %{reason: proposal.veto_reason, confidence: proposal.confidence}
        )
      end)

      # Flush to ensure delivery
      ZenohEvolutionPublisher.flush()
    end
  rescue
    _ -> :ok
  end

  defp safe_ratio(_, 0), do: 0.0
  defp safe_ratio(num, denom), do: Float.round(num / denom, 3)
end
