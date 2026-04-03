defmodule Indrajaal.Cortex.GDE.GoalEvaluator do
  @moduledoc """
  Goal Evaluator: Determines success or failure of goals in GDE.

  WHAT: Evaluates whether a goal has been achieved and records outcomes.
  WHY: Central component for determining when to stop backtracking.
  CONSTRAINTS: Must be deterministic and provide clear success/failure signals.

  ## Goals in GDE

  Goals represent desired outcomes that the system tries to achieve.
  When a goal fails, GDE backtracks and tries alternative approaches.
  When a goal succeeds, the successful path is recorded for learning.

  ## Standard Goals

  - `:compilation_success` - Zero compilation errors
  - `:test_pass` - All tests pass
  - `:format_clean` - No format violations
  - `:warning_free` - Zero warnings
  - `:credo_clean` - No Credo issues
  - `:custom` - User-defined goal

  ## STAMP Constraints

  - SC-GDE-010: Goals must be clearly defined
  - SC-GDE-011: Evaluation must be deterministic
  - SC-GDE-012: Failures must include diagnostic info

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-010 to SC-GDE-012 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohNeuralStream

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type goal ::
          :compilation_success
          | :test_pass
          | :format_clean
          | :warning_free
          | :credo_clean
          | {:custom, (term() -> boolean())}

  @type goal_result :: %{
          goal: goal(),
          success: boolean(),
          timestamp: DateTime.t(),
          duration_ms: non_neg_integer(),
          details: map()
        }

  @type evaluation_context :: %{
          files: [String.t()],
          logs: String.t(),
          metadata: map()
        }

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Evaluates whether a goal has been achieved.

  ## Parameters
  - goal: The goal to evaluate
  - context: Evaluation context (logs, files, metadata)

  ## Returns
  - {:success, details} if goal achieved
  - {:failure, reason, diagnostics} if goal not achieved
  """
  @spec evaluate(goal(), evaluation_context()) ::
          {:success, map()} | {:failure, atom(), map()}
  def evaluate(goal, context) do
    GenServer.call(__MODULE__, {:evaluate, goal, context})
  end

  @doc """
  Records a successful goal achievement.

  ## Parameters
  - goal: The achieved goal
  - path: The path taken to achieve it
  """
  @spec mark_success(goal(), list()) :: :ok
  def mark_success(goal, path) do
    GenServer.cast(__MODULE__, {:success, goal, path})
  end

  @doc """
  Records a goal failure with diagnostic information.

  ## Parameters
  - goal: The failed goal
  - reason: Failure reason
  - diagnostics: Additional diagnostic info
  """
  @spec mark_failure(goal(), atom(), map()) :: :ok
  def mark_failure(goal, reason, diagnostics \\ %{}) do
    GenServer.cast(__MODULE__, {:failure, goal, reason, diagnostics})
  end

  @doc """
  Gets statistics about goal evaluations.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Gets the history of recent evaluations.
  """
  @spec history(keyword()) :: [goal_result()]
  def history(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    GenServer.call(__MODULE__, {:history, limit})
  end

  @doc """
  Clears evaluation history.
  """
  @spec clear_history() :: :ok
  def clear_history do
    GenServer.cast(__MODULE__, :clear_history)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[GoalEvaluator] Initializing goal evaluator - SC-GDE-010")

    state = %{
      # Statistics
      total_evaluations: 0,
      successes: 0,
      failures: 0,
      # History (recent evaluations)
      history: [],
      max_history: 100,
      # Started timestamp
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:evaluate, goal, context}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    result = do_evaluate(goal, context)

    duration_ms = System.monotonic_time(:millisecond) - start_time

    # Record result
    goal_result = %{
      goal: goal,
      success: match?({:success, _}, result),
      timestamp: DateTime.utc_now(),
      duration_ms: duration_ms,
      details:
        case result do
          {:success, details} -> details
          {:failure, reason, diag} -> %{reason: reason, diagnostics: diag}
        end
    }

    new_history = [goal_result | state.history] |> Enum.take(state.max_history)

    {successes, failures} =
      case result do
        {:success, _} -> {state.successes + 1, state.failures}
        {:failure, _, _} -> {state.successes, state.failures + 1}
      end

    new_state = %{
      state
      | total_evaluations: state.total_evaluations + 1,
        successes: successes,
        failures: failures,
        history: new_history
    }

    stream_telemetry(:evaluate, goal, result)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    success_rate =
      if state.total_evaluations > 0,
        do: Float.round(state.successes / state.total_evaluations * 100, 2),
        else: 0.0

    stats = %{
      total_evaluations: state.total_evaluations,
      successes: state.successes,
      failures: state.failures,
      success_rate: success_rate,
      history_size: length(state.history),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:history, limit}, _from, state) do
    {:reply, Enum.take(state.history, limit), state}
  end

  @impl true
  def handle_cast({:success, goal, path}, state) do
    Logger.debug("[GoalEvaluator] Goal achieved: #{inspect(goal)}")
    stream_event(:success, goal, %{path: path})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:failure, goal, reason, diagnostics}, state) do
    Logger.debug("[GoalEvaluator] Goal failed: #{inspect(goal)} - #{inspect(reason)}")
    stream_event(:failure, goal, %{reason: reason, diagnostics: diagnostics})
    {:noreply, state}
  end

  @impl true
  def handle_cast(:clear_history, state) do
    {:noreply, %{state | history: []}}
  end

  # ============================================================
  # GOAL EVALUATION IMPLEMENTATIONS
  # ============================================================

  defp do_evaluate(:compilation_success, context) do
    logs = Map.get(context, :logs, "")

    cond do
      # Check for compilation errors
      String.contains?(logs, "** (CompileError)") ->
        errors = extract_compile_errors(logs)

        {:failure, :compile_error,
         %{
           error_count: length(errors),
           errors: errors
         }}

      String.contains?(logs, "== Compilation error") ->
        {:failure, :compile_error, %{raw: logs}}

      # Check for successful compilation
      String.contains?(logs, "Compiled") or logs == "" ->
        {:success, %{message: "Compilation successful"}}

      true ->
        {:success, %{message: "No compilation errors detected"}}
    end
  end

  defp do_evaluate(:test_pass, context) do
    logs = Map.get(context, :logs, "")

    cond do
      # Check for test failures
      Regex.match?(~r/\d+ tests?, \d+ failures?/, logs) ->
        case Regex.run(~r/(\d+) tests?, (\d+) failures?/, logs) do
          [_, total, failures] when failures != "0" ->
            {:failure, :test_failure,
             %{
               total_tests: String.to_integer(total),
               failures: String.to_integer(failures),
               failed_tests: extract_failed_tests(logs)
             }}

          _ ->
            {:success, %{message: "All tests passed"}}
        end

      String.contains?(logs, "0 failures") ->
        {:success, %{message: "All tests passed"}}

      true ->
        {:failure, :unknown, %{raw: logs}}
    end
  end

  defp do_evaluate(:format_clean, context) do
    logs = Map.get(context, :logs, "")

    cond do
      String.contains?(logs, "mix format failed") ->
        {:failure, :format_error, %{raw: logs}}

      String.contains?(logs, "** (Mix)") and String.contains?(logs, "format") ->
        {:failure, :format_error, %{raw: logs}}

      true ->
        {:success, %{message: "Format clean"}}
    end
  end

  defp do_evaluate(:warning_free, context) do
    logs = Map.get(context, :logs, "")
    warnings = extract_warnings(logs)

    if Enum.empty?(warnings) do
      {:success, %{message: "No warnings"}}
    else
      {:failure, :warnings,
       %{
         warning_count: length(warnings),
         warnings: Enum.take(warnings, 10)
       }}
    end
  end

  defp do_evaluate(:credo_clean, context) do
    logs = Map.get(context, :logs, "")

    cond do
      String.contains?(logs, "found no issues") ->
        {:success, %{message: "Credo clean"}}

      Regex.match?(~r/\d+ issues? found/, logs) ->
        {:failure, :credo_issues, %{raw: logs}}

      true ->
        {:success, %{message: "Credo check passed"}}
    end
  end

  defp do_evaluate({:custom, func}, context) when is_function(func, 1) do
    try do
      if func.(context) do
        {:success, %{message: "Custom goal achieved"}}
      else
        {:failure, :custom_failed, %{message: "Custom goal not achieved"}}
      end
    rescue
      e -> {:failure, :custom_error, %{error: inspect(e)}}
    end
  end

  defp do_evaluate(unknown_goal, _context) do
    {:failure, :unknown_goal, %{goal: unknown_goal}}
  end

  # ============================================================
  # EXTRACTION HELPERS
  # ============================================================

  defp extract_compile_errors(logs) do
    # Match patterns like: ** (CompileError) lib/file.ex:10: message
    error_matches = Regex.scan(~r/\*\* \(CompileError\) ([^:]+):(\d+): (.+?)(?=\n|$)/, logs)

    Enum.map(error_matches, fn [_, file, line, message] ->
      %{file: file, line: String.to_integer(line), message: String.trim(message)}
    end)
  end

  defp extract_failed_tests(logs) do
    # Match test failure patterns
    test_matches = Regex.scan(~r/\d+\) test (.+?) \((.+?)\)/, logs)

    test_matches
    |> Enum.map(fn [_, name, module] ->
      %{name: name, module: module}
    end)
    |> Enum.take(10)
  end

  defp extract_warnings(logs) do
    matches = Regex.scan(~r/warning: (.+?)(?=\n|$)/, logs)

    matches
    |> Enum.map(fn [_, warning] -> String.trim(warning) end)
  end

  # ============================================================
  # TELEMETRY HELPERS
  # ============================================================

  defp stream_telemetry(operation, goal, result) do
    status = if match?({:success, _}, result), do: :success, else: :failure

    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_metric(:gde, operation, 1, %{goal: goal, status: status})
    end
  rescue
    _ -> :ok
  end

  defp stream_event(type, goal, data) do
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:goal_evaluator, type, %{goal: goal, data: data})
    end
  rescue
    _ -> :ok
  end
end
