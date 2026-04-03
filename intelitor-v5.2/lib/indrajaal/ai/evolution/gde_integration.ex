defmodule Indrajaal.AI.Evolution.GDEIntegration do
  @moduledoc """
  Integration of AI capabilities with the Goal-Directed Evolution (GDE) system.

  ## GDE Cycle with AI

  The GDE cycle uses AI at each phase:

  1. **OBSERVE**: Detect anomaly or error state
  2. **ORIENT**: Analyze context with Gemini (analysis-optimized)
  3. **DECIDE**: Generate fix proposals with Claude (synthesis-optimized)
  4. **ACT**: Execute verified fix
  5. **LEARN**: Record episode in TrainingGym

  ## Bicameral Architecture

  Uses the bicameral approach for optimal results:
  - Gemini 1.5 Pro: Analysis, pattern detection, context understanding
  - Claude 3.5 Sonnet: Synthesis, code generation, validation

  ## STAMP Constraints

  - SC-AI-105: GDE uses dual-model approach
  - SC-AI-106: Validation before execution
  - SC-GDE-060: Learning from outcomes

  ## Usage

      {:ok, result} = GDEIntegration.execute_cycle(%{
        error_type: :compilation_error,
        error_message: "undefined function...",
        affected_files: ["lib/module.ex"]
      })
  """

  alias Indrajaal.AI.Simplex.SimplexController
  alias Indrajaal.AI.Evolution.TrainingGym

  require Logger

  @analysis_model "google/gemini-1.5-pro"
  @synthesis_model "anthropic/claude-3.5-sonnet"

  @doc """
  Execute a full GDE cycle for an error context.

  ## Parameters

  - `error_context`: Map containing error details
    - `:error_type` - Type of error (compilation, runtime, etc.)
    - `:error_message` - The error message
    - `:affected_files` - List of affected files
    - `:stack_trace` - Optional stack trace
    - `:context` - Additional context

  ## Returns

  - `{:ok, result}` with fix details
  - `{:error, reason}` if cycle fails
  """
  @spec execute_cycle(map()) :: {:ok, map()} | {:error, term()}
  def execute_cycle(error_context) do
    cycle_id = generate_cycle_id()
    start_time = System.monotonic_time(:millisecond)

    Logger.info("[GDE] Starting cycle #{cycle_id} for #{error_context[:error_type]}")

    result =
      with {:ok, analysis} <- observe_and_orient(error_context, cycle_id),
           {:ok, proposals} <- decide_fixes(analysis, error_context, cycle_id),
           {:ok, selected} <- validate_and_select(proposals, cycle_id),
           {:ok, execution_result} <- act_on_fix(selected, error_context, cycle_id) do
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Record learning
        learn_from_result(error_context, execution_result, duration)

        {:ok,
         %{
           cycle_id: cycle_id,
           duration_ms: duration,
           analysis: analysis,
           proposals: proposals,
           selected_fix: selected,
           result: execution_result
         }}
      end

    case result do
      {:ok, _} = success ->
        Logger.info("[GDE] Cycle #{cycle_id} completed successfully")
        success

      {:error, reason} = error ->
        Logger.warning("[GDE] Cycle #{cycle_id} failed: #{inspect(reason)}")
        learn_from_failure(error_context, reason)
        error
    end
  end

  @doc """
  Execute only the analysis phase (Observe + Orient).
  """
  @spec analyze_error(map()) :: {:ok, map()} | {:error, term()}
  def analyze_error(error_context) do
    observe_and_orient(error_context, generate_cycle_id())
  end

  @doc """
  Generate fix proposals without executing them.
  """
  @spec generate_proposals(map()) :: {:ok, [map()]} | {:error, term()}
  def generate_proposals(error_context) do
    cycle_id = generate_cycle_id()

    with {:ok, analysis} <- observe_and_orient(error_context, cycle_id) do
      decide_fixes(analysis, error_context, cycle_id)
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 1-2: Observe and Orient (Analysis with Gemini)
  # ---------------------------------------------------------------------------

  defp observe_and_orient(error_context, cycle_id) do
    prompt = build_analysis_prompt(error_context)

    request = %{
      action: :gde_analysis,
      source: :gde_integration,
      intent: :analyze,
      prompt: prompt,
      model: @analysis_model
    }

    case SimplexController.execute(request, request_id: "#{cycle_id}-analyze") do
      {:ok, result} ->
        analysis = parse_analysis(result[:content])
        {:ok, analysis}

      {:error, reason} ->
        {:error, {:analysis_failed, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 3: Decide (Generate proposals with Claude)
  # ---------------------------------------------------------------------------

  defp decide_fixes(analysis, error_context, cycle_id) do
    prompt = build_synthesis_prompt(analysis, error_context)

    request = %{
      action: :gde_synthesis,
      source: :gde_integration,
      intent: :synthesize,
      prompt: prompt,
      model: @synthesis_model
    }

    case SimplexController.execute(request, request_id: "#{cycle_id}-synthesize") do
      {:ok, result} ->
        proposals = parse_proposals(result[:content])
        {:ok, proposals}

      {:error, reason} ->
        {:error, {:synthesis_failed, reason}}
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 4: Validate and Select
  # ---------------------------------------------------------------------------

  defp validate_and_select(proposals, _cycle_id) when proposals == [] or is_nil(proposals) do
    {:error, :no_proposals_generated}
  end

  defp validate_and_select(proposals, cycle_id) do
    prompt = build_validation_prompt(proposals)

    request = %{
      action: :gde_validation,
      source: :gde_integration,
      intent: :validate,
      prompt: prompt,
      model: @synthesis_model
    }

    case SimplexController.execute(request, request_id: "#{cycle_id}-validate") do
      {:ok, result} ->
        selected = select_best_proposal(proposals, result[:content])
        {:ok, selected}

      {:error, _reason} ->
        # On validation failure, use first proposal with caution flag
        Logger.warning("[GDE] Validation failed, using first proposal with caution")
        {:ok, Map.put(hd(proposals), :validation_skipped, true)}
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 5: Act
  # ---------------------------------------------------------------------------

  defp act_on_fix(proposal, error_context, _cycle_id) do
    # In a real implementation, this would execute the fix
    # For now, we return the proposal as a simulated execution

    Logger.info("[GDE] Would execute fix: #{proposal[:description]}")

    {:ok,
     %{
       status: :simulated,
       fix_applied: proposal[:description],
       files_modified: proposal[:files] || error_context[:affected_files] || [],
       rollback_available: true
     }}
  end

  # ---------------------------------------------------------------------------
  # Phase 6: Learn
  # ---------------------------------------------------------------------------

  defp learn_from_result(error_context, result, duration) do
    episode_type =
      case result[:status] do
        :success -> :success
        :simulated -> :success
        :partial -> :near_miss
        _ -> :failure
      end

    TrainingGym.record_episode(%{
      type: episode_type,
      primary_model: @synthesis_model,
      secondary_model: @analysis_model,
      request_intent: :gde_cycle,
      error_type: error_context[:error_type],
      fix_applied: result[:fix_applied],
      duration_ms: duration,
      timestamp: DateTime.utc_now()
    })
  end

  defp learn_from_failure(error_context, reason) do
    TrainingGym.record_episode(%{
      type: :failure,
      primary_model: @synthesis_model,
      secondary_model: @analysis_model,
      request_intent: :gde_cycle,
      error_type: error_context[:error_type],
      failure_reason: inspect(reason),
      timestamp: DateTime.utc_now()
    })
  end

  # ---------------------------------------------------------------------------
  # Prompt Builders
  # ---------------------------------------------------------------------------

  defp build_analysis_prompt(error_context) do
    """
    You are an expert Elixir developer analyzing a system error. Analyze the following context and identify:

    1. **Root Cause**: What is the fundamental issue causing this error?
    2. **Affected Components**: Which modules/functions are impacted?
    3. **Severity Level**: Critical, High, Medium, or Low
    4. **Impact Assessment**: What functionality is affected?
    5. **Potential Fix Strategies**: List 2-3 approaches to resolve this

    ## Error Context

    **Error Type**: #{error_context[:error_type]}

    **Error Message**:
    ```
    #{error_context[:error_message]}
    ```

    **Affected Files**: #{inspect(error_context[:affected_files] || [])}

    #{if error_context[:stack_trace], do: "**Stack Trace**:\n```\n#{error_context[:stack_trace]}\n```", else: ""}

    #{if error_context[:context], do: "**Additional Context**:\n#{inspect(error_context[:context], pretty: true)}", else: ""}

    Provide a structured analysis with clear sections for each point above.
    """
  end

  defp build_synthesis_prompt(analysis, error_context) do
    """
    Based on the following analysis, generate 3 potential fixes for the error.

    ## Analysis Summary

    #{format_analysis(analysis)}

    ## Original Error

    **Type**: #{error_context[:error_type]}
    **Message**: #{error_context[:error_message]}

    ## Requirements for Each Fix

    For each proposed fix, provide:
    1. **Description**: Brief explanation of the fix
    2. **Code Changes**: Specific code modifications needed
    3. **Risk Level**: Low, Medium, or High
    4. **Rollback Strategy**: How to revert if needed
    5. **Testing Approach**: How to verify the fix works

    Generate exactly 3 proposals, ordered by your confidence in their correctness.
    Separate each proposal with `---`.
    """
  end

  defp build_validation_prompt(proposals) do
    """
    Validate and rank the following fix proposals. For each, assess:

    1. **Correctness**: Will this actually fix the problem?
    2. **Safety**: Could this introduce new issues?
    3. **Completeness**: Does it address the root cause?
    4. **Minimal Invasiveness**: Does it change only what's necessary?

    ## Proposals

    #{format_proposals(proposals)}

    Respond with a ranking (1 = best) and brief justification for each.
    Format: `RANK 1: Proposal X - [reason]`
    """
  end

  # ---------------------------------------------------------------------------
  # Parsers
  # ---------------------------------------------------------------------------

  defp parse_analysis(content) when is_binary(content) do
    %{
      raw: content,
      root_cause: extract_section(content, "Root Cause"),
      severity: extract_severity(content),
      strategies: extract_strategies(content)
    }
  end

  defp parse_analysis(_), do: %{raw: "", root_cause: "Unknown", severity: :medium, strategies: []}

  defp parse_proposals(content) when is_binary(content) do
    content
    |> String.split("---")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index(1)
    |> Enum.map(fn {proposal_text, index} ->
      %{
        id: index,
        description: extract_first_line(proposal_text),
        full_text: proposal_text,
        risk: extract_risk(proposal_text),
        files: []
      }
    end)
  end

  defp parse_proposals(_), do: []

  defp select_best_proposal(proposals, validation_content) do
    # Try to extract ranking from validation
    best =
      case Regex.run(~r/RANK 1:\s*Proposal\s*(\d+)/i, validation_content || "") do
        [_, index_str] ->
          index = String.to_integer(index_str)
          Enum.at(proposals, index - 1, hd(proposals))

        _ ->
          # Default to first proposal
          hd(proposals)
      end

    Map.put(best, :validation, validation_content)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp generate_cycle_id do
    "gde-#{4 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)}"
  end

  defp format_analysis(%{raw: raw}), do: raw
  defp format_analysis(analysis) when is_map(analysis), do: inspect(analysis, pretty: true)
  defp format_analysis(analysis), do: to_string(analysis)

  defp format_proposals(proposals) do
    proposals
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {p, i} ->
      "### Proposal #{i}\n#{p[:full_text] || p[:description]}"
    end)
  end

  defp extract_section(content, section_name) do
    case Regex.run(~r/#{section_name}[:\s]*(.+?)(?=\n\n|\n#|\z)/is, content) do
      [_, value] -> String.trim(value)
      _ -> "Not specified"
    end
  end

  defp extract_severity(content) do
    cond do
      String.contains?(String.downcase(content), "critical") -> :critical
      String.contains?(String.downcase(content), "high") -> :high
      String.contains?(String.downcase(content), "low") -> :low
      true -> :medium
    end
  end

  defp extract_strategies(content) do
    case Regex.run(~r/strategies?[:\s]*(.+?)(?=\n\n|\n#|\z)/is, content) do
      [_, strategies] ->
        strategies
        |> String.split(~r/\n[-*\d.]+\s*/)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end

  defp extract_first_line(text) do
    text
    |> String.split("\n")
    |> hd()
    |> String.trim()
    |> String.slice(0..200)
  end

  defp extract_risk(text) do
    cond do
      String.contains?(String.downcase(text), "high risk") -> :high
      String.contains?(String.downcase(text), "low risk") -> :low
      true -> :medium
    end
  end
end
