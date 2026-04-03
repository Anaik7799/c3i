defmodule Indrajaal.Cortex.GDE.ProposalEngine do
  @moduledoc """
  Proposal Engine: Generates and ranks hypotheses for fixing issues.

  WHAT: Creates structured proposals for resolving compilation/test failures.
  WHY: Central component for intelligent fix generation in GDE.
  CONSTRAINTS: Must generate ranked proposals with confidence scores.

  ## Proposal Flow

  1. Analyze error context (file, line, message, type)
  2. Generate candidate fixes using pattern matching
  3. Rank by confidence and historical success
  4. Return prioritized proposal list

  ## Proposal Types

  - `:add_import` - Add missing import statement
  - `:add_alias` - Add module alias
  - `:fix_function_call` - Correct function call
  - `:add_clause` - Add pattern match clause
  - `:fix_type` - Fix type mismatch
  - `:add_dependency` - Add missing dependency

  ## STAMP Constraints

  - SC-GDE-040: Proposals must include confidence score
  - SC-GDE-041: Proposals must be deterministic
  - SC-GDE-042: Must integrate with StringScanner for parsing
  - SC-GDE-043: Must track proposal success rates

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-040 to SC-GDE-043 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.GDE.StringScanner
  alias Indrajaal.Cortex.GDE.Generator
  alias Indrajaal.Observability.ZenohNeuralStream

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type proposal_type ::
          :add_import
          | :add_alias
          | :fix_function_call
          | :add_clause
          | :fix_type
          | :add_dependency
          | :remove_code
          | :replace_code

  @type proposal :: %{
          type: proposal_type(),
          confidence: float(),
          description: String.t(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          original: String.t() | nil,
          replacement: String.t() | nil,
          metadata: map()
        }

  @type error_context :: %{
          type: atom(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          message: String.t(),
          raw: String.t()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_max_proposals 10
  @min_confidence 0.1

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generates proposals for fixing an error.

  ## Parameters
  - error_context: Parsed error information
  - opts: Options
    - :max_proposals - Maximum proposals to return (default: 10)
    - :min_confidence - Minimum confidence threshold (default: 0.1)

  ## Returns
  - {:ok, [proposal()]} - Ranked list of proposals
  """
  @spec generate(error_context(), keyword()) :: {:ok, [proposal()]}
  def generate(error_context, opts \\ []) do
    GenServer.call(__MODULE__, {:generate, error_context, opts})
  end

  @doc """
  Generates proposals from raw log text.

  ## Parameters
  - log_text: Raw log/error text
  - opts: Generation options

  ## Returns
  - {:ok, [proposal()]} on success
  - {:error, :no_errors_found} if no errors detected
  """
  @spec generate_from_logs(String.t(), keyword()) ::
          {:ok, [proposal()]} | {:error, :no_errors_found}
  def generate_from_logs(log_text, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_from_logs, log_text, opts})
  end

  @doc """
  Records the outcome of a proposal (for learning).

  ## Parameters
  - proposal: The proposal that was tried
  - success: Whether it worked
  """
  @spec record_outcome(proposal(), boolean()) :: :ok
  def record_outcome(proposal, success) do
    GenServer.cast(__MODULE__, {:record_outcome, proposal, success})
  end

  @doc """
  Gets generator of proposals (for backtracking).

  ## Parameters
  - error_context: Error context
  - opts: Options

  ## Returns
  - Generator of proposals
  """
  @spec proposal_generator(error_context(), keyword()) :: Generator.generator()
  def proposal_generator(error_context, opts \\ []) do
    case generate(error_context, opts) do
      {:ok, proposals} -> Generator.alternatives(proposals)
    end
  end

  @doc """
  Gets statistics about proposal generation.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[ProposalEngine] Initializing proposal engine - SC-GDE-040")

    state = %{
      # Track success rates by proposal type
      success_rates: %{},
      # Total proposals generated
      total_generated: 0,
      # Successful outcomes
      successful_outcomes: 0,
      # Failed outcomes
      failed_outcomes: 0,
      # Started timestamp
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:generate, error_context, opts}, _from, state) do
    max_proposals = Keyword.get(opts, :max_proposals, @default_max_proposals)
    min_confidence = Keyword.get(opts, :min_confidence, @min_confidence)

    proposals =
      error_context
      |> generate_proposals(state.success_rates)
      |> Enum.filter(&(&1.confidence >= min_confidence))
      |> Enum.sort_by(& &1.confidence, :desc)
      |> Enum.take(max_proposals)

    new_state = %{state | total_generated: state.total_generated + length(proposals)}

    stream_telemetry(:generate, error_context.type, length(proposals))

    {:reply, {:ok, proposals}, new_state}
  end

  @impl true
  def handle_call({:generate_from_logs, log_text, opts}, _from, state) do
    case StringScanner.extract_error(log_text) do
      {:ok, error_info} ->
        error_context = %{
          type: Map.get(error_info, :type, :unknown),
          file: Map.get(error_info, :file),
          line: parse_line(Map.get(error_info, :line)),
          message: Map.get(error_info, :message, ""),
          raw: log_text
        }

        max_proposals = Keyword.get(opts, :max_proposals, @default_max_proposals)
        min_confidence = Keyword.get(opts, :min_confidence, @min_confidence)

        proposals =
          error_context
          |> generate_proposals(state.success_rates)
          |> Enum.filter(&(&1.confidence >= min_confidence))
          |> Enum.sort_by(& &1.confidence, :desc)
          |> Enum.take(max_proposals)

        new_state = %{state | total_generated: state.total_generated + length(proposals)}

        {:reply, {:ok, proposals}, new_state}

      {:error, :unknown} ->
        {:reply, {:error, :no_errors_found}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total_outcomes = state.successful_outcomes + state.failed_outcomes

    success_rate =
      if total_outcomes > 0,
        do: Float.round(state.successful_outcomes / total_outcomes * 100, 2),
        else: 0.0

    stats = %{
      total_generated: state.total_generated,
      successful_outcomes: state.successful_outcomes,
      failed_outcomes: state.failed_outcomes,
      success_rate: success_rate,
      success_rates_by_type: state.success_rates,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:record_outcome, proposal, success}, state) do
    type = proposal.type

    # Update success rates
    current = Map.get(state.success_rates, type, {0, 0})
    {successes, total} = current

    new_rates =
      if success do
        Map.put(state.success_rates, type, {successes + 1, total + 1})
      else
        Map.put(state.success_rates, type, {successes, total + 1})
      end

    # Update counters
    {succ, fail} =
      if success do
        {state.successful_outcomes + 1, state.failed_outcomes}
      else
        {state.successful_outcomes, state.failed_outcomes + 1}
      end

    new_state = %{
      state
      | success_rates: new_rates,
        successful_outcomes: succ,
        failed_outcomes: fail
    }

    stream_event(:outcome, proposal.type, success)

    {:noreply, new_state}
  end

  # ============================================================
  # PROPOSAL GENERATION
  # ============================================================

  defp generate_proposals(error_context, success_rates) do
    base_proposals = proposals_for_error_type(error_context)

    # Adjust confidence based on historical success rates
    Enum.map(base_proposals, fn proposal ->
      adjusted_confidence = adjust_confidence(proposal, success_rates)
      %{proposal | confidence: adjusted_confidence}
    end)
  end

  defp proposals_for_error_type(%{type: :compile_error} = ctx) do
    message = ctx.message || ""

    cond do
      String.contains?(message, "undefined function") ->
        undefined_function_proposals(ctx)

      String.contains?(message, "undefined module") ->
        undefined_module_proposals(ctx)

      String.contains?(message, "is undefined") ->
        undefined_proposals(ctx)

      String.contains?(message, "expected") ->
        syntax_error_proposals(ctx)

      true ->
        generic_compile_proposals(ctx)
    end
  end

  defp proposals_for_error_type(%{type: :undefined_function} = ctx) do
    undefined_function_proposals(ctx)
  end

  defp proposals_for_error_type(%{type: :undefined_module} = ctx) do
    undefined_module_proposals(ctx)
  end

  defp proposals_for_error_type(%{type: :runtime_error} = ctx) do
    runtime_error_proposals(ctx)
  end

  defp proposals_for_error_type(%{type: :test_failure} = ctx) do
    test_failure_proposals(ctx)
  end

  defp proposals_for_error_type(ctx) do
    generic_proposals(ctx)
  end

  # ============================================================
  # SPECIFIC PROPOSAL GENERATORS
  # ============================================================

  defp undefined_function_proposals(ctx) do
    function_name = extract_function_name(ctx.message || "")

    [
      %{
        type: :add_import,
        confidence: 0.8,
        description: "Add import for #{function_name}",
        file: ctx.file,
        line: 1,
        original: nil,
        replacement: "import SomeModule",
        metadata: %{function: function_name}
      },
      %{
        type: :add_alias,
        confidence: 0.7,
        description: "Add alias for module containing #{function_name}",
        file: ctx.file,
        line: 1,
        original: nil,
        replacement: "alias SomeModule",
        metadata: %{function: function_name}
      },
      %{
        type: :fix_function_call,
        confidence: 0.6,
        description: "Fix function call - possible typo in #{function_name}",
        file: ctx.file,
        line: ctx.line,
        original: function_name,
        replacement: nil,
        metadata: %{function: function_name, suggestions: similar_functions(function_name)}
      }
    ]
  end

  defp undefined_module_proposals(ctx) do
    module_name = extract_module_name(ctx.message || "")

    [
      %{
        type: :add_alias,
        confidence: 0.85,
        description: "Add alias for #{module_name}",
        file: ctx.file,
        line: 1,
        original: nil,
        replacement: "alias #{module_name}",
        metadata: %{module: module_name}
      },
      %{
        type: :add_dependency,
        confidence: 0.5,
        description: "Add dependency containing #{module_name}",
        file: "mix.exs",
        line: nil,
        original: nil,
        replacement: nil,
        metadata: %{module: module_name}
      }
    ]
  end

  defp undefined_proposals(ctx) do
    undefined_function_proposals(ctx) ++ undefined_module_proposals(ctx)
  end

  defp syntax_error_proposals(ctx) do
    [
      %{
        type: :fix_type,
        confidence: 0.7,
        description: "Fix syntax error",
        file: ctx.file,
        line: ctx.line,
        original: nil,
        replacement: nil,
        metadata: %{message: ctx.message}
      }
    ]
  end

  defp generic_compile_proposals(ctx) do
    [
      %{
        type: :fix_type,
        confidence: 0.5,
        description: "Generic compile fix",
        file: ctx.file,
        line: ctx.line,
        original: nil,
        replacement: nil,
        metadata: %{message: ctx.message}
      }
    ]
  end

  defp runtime_error_proposals(ctx) do
    [
      %{
        type: :add_clause,
        confidence: 0.6,
        description: "Add pattern match clause for edge case",
        file: ctx.file,
        line: ctx.line,
        original: nil,
        replacement: nil,
        metadata: %{error_type: ctx.type}
      },
      %{
        type: :fix_type,
        confidence: 0.5,
        description: "Fix type handling in function",
        file: ctx.file,
        line: ctx.line,
        original: nil,
        replacement: nil,
        metadata: %{error_type: ctx.type}
      }
    ]
  end

  defp test_failure_proposals(ctx) do
    [
      %{
        type: :fix_function_call,
        confidence: 0.6,
        description: "Fix test expectation or implementation",
        file: ctx.file,
        line: ctx.line,
        original: nil,
        replacement: nil,
        metadata: %{test: true}
      }
    ]
  end

  defp generic_proposals(ctx) do
    [
      %{
        type: :fix_type,
        confidence: 0.3,
        description: "Generic fix suggestion",
        file: ctx.file,
        line: ctx.line,
        original: nil,
        replacement: nil,
        metadata: %{type: ctx.type}
      }
    ]
  end

  # ============================================================
  # HELPER FUNCTIONS
  # ============================================================

  defp extract_function_name(message) do
    case Regex.run(~r/undefined function (\w+\/\d+)/, message) do
      [_, func] -> func
      nil -> "unknown"
    end
  end

  defp extract_module_name(message) do
    case Regex.run(~r/undefined module ([A-Z][\w.]+)/, message) do
      [_, mod] -> mod
      nil -> "Unknown"
    end
  end

  defp similar_functions(function_name) do
    # Simple Levenshtein-based suggestions would go here
    # For now, return empty list
    [function_name]
  end

  defp parse_line(nil), do: nil
  defp parse_line(line) when is_integer(line), do: line
  defp parse_line(line) when is_binary(line), do: String.to_integer(line)

  defp adjust_confidence(proposal, success_rates) do
    case Map.get(success_rates, proposal.type) do
      nil ->
        proposal.confidence

      {successes, total} when total > 0 ->
        historical_rate = successes / total
        # Blend base confidence with historical rate
        proposal.confidence * 0.7 + historical_rate * 0.3

      _ ->
        proposal.confidence
    end
  end

  # ============================================================
  # TELEMETRY
  # ============================================================

  defp stream_telemetry(operation, error_type, count) do
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_metric(:gde, operation, count, %{error_type: error_type})
    end
  rescue
    _ -> :ok
  end

  defp stream_event(type, proposal_type, success) do
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:proposal_engine, type, %{
        proposal_type: proposal_type,
        success: success
      })
    end
  rescue
    _ -> :ok
  end
end
