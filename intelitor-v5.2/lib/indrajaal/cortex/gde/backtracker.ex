defmodule Indrajaal.Cortex.GDE.Backtracker do
  @moduledoc """
  Backtracker: Manages retry logic and state rewind for GDE.

  WHAT: Coordinates backtracking with state management via ZenohTimeTravel.
  WHY: Enables automatic retry with state restoration on failure.
  CONSTRAINTS: Must integrate with TimeTravel, limit branching, record decisions.

  ## Backtracking Process

  1. Record checkpoint before attempting solution
  2. Try solution
  3. If success: Record successful path, return result
  4. If failure: Rewind to checkpoint, try next alternative
  5. If exhausted: Return failure with attempts summary

  ## Integration with ZenohTimeTravel

  The Backtracker uses ZenohTimeTravel for state snapshots:
  - `record_checkpoint/2`: Save state before each attempt
  - `rewind_to/1`: Restore state on failure
  - `list_checkpoints/1`: View decision history

  ## STAMP Constraints

  - SC-GDE-020: Must checkpoint before each attempt
  - SC-GDE-021: Must rewind on failure
  - SC-GDE-022: Must limit branching factor
  - SC-GDE-023: Must record decision tree

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-020 to SC-GDE-023 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.GDE.Generator
  alias Indrajaal.Cortex.GDE.GoalEvaluator
  alias Indrajaal.Observability.ZenohTimeTravel
  alias Indrajaal.Observability.ZenohNeuralStream

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type attempt_result :: {:ok, term()} | {:error, term()}

  @type backtrack_options :: [
          max_attempts: pos_integer(),
          timeout_ms: pos_integer(),
          on_failure: (term() -> :retry | :stop),
          record_decisions: boolean()
        ]

  @type decision_node :: %{
          attempt: pos_integer(),
          checkpoint_id: String.t() | nil,
          candidate: term(),
          result: :success | :failure,
          reason: term() | nil,
          timestamp: DateTime.t()
        }

  @type backtrack_result :: %{
          success: boolean(),
          result: term() | nil,
          attempts: pos_integer(),
          decisions: [decision_node()],
          duration_ms: non_neg_integer()
        }

  @type backtrack_context :: %{
          func: (term() -> attempt_result()),
          goal: term(),
          timeout_ms: pos_integer(),
          on_failure: (term() -> :retry | :stop),
          record_decisions: boolean(),
          session_id: String.t() | nil,
          start_time: integer(),
          decisions: [decision_node()],
          attempt: pos_integer()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_max_attempts 10
  @default_timeout_ms 60_000
  @session_prefix "backtrack"

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a function with automatic backtracking on failure.

  ## Parameters
  - generator: Generator of candidate values
  - func: Function to try with each value (returns {:ok, result} or {:error, reason})
  - goal: Goal to evaluate after each attempt
  - opts: Backtracking options

  ## Returns
  - {:ok, backtrack_result} on success
  - {:error, backtrack_result} on exhaustion or timeout
  """
  @spec with_backtrack(
          Generator.generator(),
          (term() -> attempt_result()),
          term(),
          backtrack_options()
        ) ::
          {:ok, backtrack_result()} | {:error, backtrack_result()}
  def with_backtrack(generator, func, goal, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:backtrack, generator, func, goal, opts},
      Keyword.get(opts, :timeout_ms, @default_timeout_ms) + 5000
    )
  end

  @doc """
  Executes with simple retry logic (no state rewind).

  ## Parameters
  - func: Function to execute
  - max_retries: Maximum retry count
  - delay_ms: Delay between retries

  ## Returns
  - {:ok, result} on success
  - {:error, :exhausted} after all retries
  """
  @spec with_retry((-> attempt_result()), pos_integer(), non_neg_integer()) ::
          {:ok, term()} | {:error, :exhausted}
  def with_retry(func, max_retries \\ 3, delay_ms \\ 100) when is_function(func, 0) do
    do_retry(func, max_retries, delay_ms, 1)
  end

  @doc """
  Gets the current decision tree from an active backtrack session.
  """
  @spec current_decisions() :: [decision_node()]
  def current_decisions do
    GenServer.call(__MODULE__, :current_decisions)
  end

  @doc """
  Gets backtracker statistics.
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
    Logger.info("[Backtracker] Initializing GDE backtracker - SC-GDE-020")

    # Start a TimeTravel session for this backtracker
    session_id = start_time_travel_session()

    state = %{
      session_id: session_id,
      current_decisions: [],
      # Statistics
      total_backtracks: 0,
      successful_backtracks: 0,
      failed_backtracks: 0,
      total_attempts: 0,
      # Started timestamp
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:backtrack, generator, func, goal, opts}, _from, state) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    on_failure = Keyword.get(opts, :on_failure, fn _reason -> :retry end)
    record_decisions = Keyword.get(opts, :record_decisions, true)

    start_time = System.monotonic_time(:millisecond)

    # Build context for backtracking
    context = %{
      generator: generator,
      func: func,
      goal: goal,
      max_attempts: max_attempts,
      timeout_ms: timeout_ms,
      on_failure: on_failure,
      record_decisions: record_decisions,
      session_id: state.session_id,
      start_time: start_time
    }

    # Execute backtracking
    {result, decisions, attempts} = execute_backtrack(context)

    duration_ms = System.monotonic_time(:millisecond) - start_time

    backtrack_result = %{
      success: match?({:ok, _}, result),
      result: if(match?({:ok, _}, result), do: elem(result, 1), else: nil),
      attempts: attempts,
      decisions: decisions,
      duration_ms: duration_ms
    }

    # Update stats
    {successful, failed} =
      case result do
        {:ok, _} -> {state.successful_backtracks + 1, state.failed_backtracks}
        _ -> {state.successful_backtracks, state.failed_backtracks + 1}
      end

    new_state = %{
      state
      | current_decisions: decisions,
        total_backtracks: state.total_backtracks + 1,
        successful_backtracks: successful,
        failed_backtracks: failed,
        total_attempts: state.total_attempts + attempts
    }

    stream_telemetry(:backtrack, result)

    reply =
      case result do
        {:ok, _} -> {:ok, backtrack_result}
        _ -> {:error, backtrack_result}
      end

    {:reply, reply, new_state}
  end

  @impl true
  def handle_call(:current_decisions, _from, state) do
    {:reply, state.current_decisions, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    success_rate =
      if state.total_backtracks > 0,
        do: Float.round(state.successful_backtracks / state.total_backtracks * 100, 2),
        else: 0.0

    avg_attempts =
      if state.total_backtracks > 0,
        do: Float.round(state.total_attempts / state.total_backtracks, 2),
        else: 0.0

    stats = %{
      total_backtracks: state.total_backtracks,
      successful_backtracks: state.successful_backtracks,
      failed_backtracks: state.failed_backtracks,
      success_rate: success_rate,
      total_attempts: state.total_attempts,
      avg_attempts_per_backtrack: avg_attempts,
      session_id: state.session_id,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  # ============================================================
  # PRIVATE - BACKTRACKING EXECUTION
  # ============================================================

  defp execute_backtrack(context) do
    # Convert generator to list (bounded)
    candidates = Enum.take(context.generator, context.max_attempts)

    # Build execution context with initialized fields
    exec_context = %{
      func: context.func,
      goal: context.goal,
      timeout_ms: context.timeout_ms,
      on_failure: context.on_failure,
      record_decisions: context.record_decisions,
      session_id: context.session_id,
      start_time: context.start_time,
      decisions: [],
      attempt: 1
    }

    do_backtrack(candidates, exec_context)
  end

  defp do_backtrack([], context) do
    # Exhausted all candidates
    {{:error, :exhausted}, Enum.reverse(context.decisions), context.attempt - 1}
  end

  defp do_backtrack([candidate | rest], context) do
    # Check timeout
    elapsed = System.monotonic_time(:millisecond) - context.start_time

    if elapsed > context.timeout_ms do
      {{:error, :timeout}, Enum.reverse(context.decisions), context.attempt - 1}
    else
      # Record checkpoint before attempt
      checkpoint_id =
        maybe_record_checkpoint(context.session_id, %{
          candidate: candidate,
          attempt: context.attempt
        })

      Logger.debug("[Backtracker] Attempt #{context.attempt}: trying #{inspect(candidate)}")

      # Try the function
      func_result = safe_execute(context.func, candidate)

      # Record decision
      decision =
        if context.record_decisions do
          %{
            attempt: context.attempt,
            checkpoint_id: checkpoint_id,
            candidate: candidate,
            result: if(match?({:ok, _}, func_result), do: :success, else: :failure),
            reason: if(match?({:error, _}, func_result), do: elem(func_result, 1), else: nil),
            timestamp: DateTime.utc_now()
          }
        else
          nil
        end

      new_decisions = if decision, do: [decision | context.decisions], else: context.decisions

      case func_result do
        {:ok, result} ->
          # Success! Evaluate goal
          goal_result = evaluate_goal(context.goal, result)

          case goal_result do
            {:success, _} ->
              Logger.debug("[Backtracker] Goal achieved on attempt #{context.attempt}")
              {{:ok, result}, Enum.reverse(new_decisions), context.attempt}

            {:failure, reason, _} ->
              Logger.debug("[Backtracker] Goal failed: #{inspect(reason)}, backtracking")
              # Rewind and try next
              maybe_rewind_checkpoint(checkpoint_id)

              handle_failure(reason, rest, new_decisions, context)
          end

        {:error, reason} ->
          Logger.debug("[Backtracker] Attempt #{context.attempt} failed: #{inspect(reason)}")
          # Rewind and try next
          maybe_rewind_checkpoint(checkpoint_id)

          handle_failure(reason, rest, new_decisions, context)
      end
    end
  end

  defp handle_failure(reason, rest, decisions, context) do
    case context.on_failure.(reason) do
      :stop ->
        {{:error, reason}, Enum.reverse(decisions), context.attempt}

      :retry ->
        updated_context = %{
          context
          | decisions: decisions,
            attempt: context.attempt + 1
        }

        do_backtrack(rest, updated_context)
    end
  end

  defp safe_execute(func, candidate) do
    try do
      func.(candidate)
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    catch
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  defp evaluate_goal(nil, _result), do: {:success, %{}}

  defp evaluate_goal(goal, result) do
    if Code.ensure_loaded?(GoalEvaluator) and GenServer.whereis(GoalEvaluator) do
      context = %{logs: inspect(result), metadata: %{}}
      GoalEvaluator.evaluate(goal, context)
    else
      {:success, %{}}
    end
  rescue
    _ -> {:success, %{}}
  end

  # ============================================================
  # PRIVATE - RETRY LOGIC
  # ============================================================

  defp do_retry(_func, 0, _delay, _attempt), do: {:error, :exhausted}

  defp do_retry(func, retries_left, delay_ms, attempt) do
    case func.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} ->
        if delay_ms > 0 do
          Process.sleep(delay_ms)
        end

        do_retry(func, retries_left - 1, delay_ms, attempt + 1)
    end
  end

  # ============================================================
  # PRIVATE - TIME TRAVEL INTEGRATION
  # ============================================================

  defp start_time_travel_session do
    if Code.ensure_loaded?(ZenohTimeTravel) and GenServer.whereis(ZenohTimeTravel) do
      case ZenohTimeTravel.new_session(prefix: @session_prefix) do
        {:ok, session_id} -> session_id
        _ -> nil
      end
    else
      nil
    end
  end

  defp maybe_record_checkpoint(nil, _data), do: nil

  defp maybe_record_checkpoint(session_id, data) do
    if Code.ensure_loaded?(ZenohTimeTravel) and GenServer.whereis(ZenohTimeTravel) do
      case ZenohTimeTravel.record_checkpoint(data, session: session_id) do
        {:ok, checkpoint_id} -> checkpoint_id
        _ -> nil
      end
    else
      nil
    end
  end

  defp maybe_rewind_checkpoint(nil), do: :ok

  defp maybe_rewind_checkpoint(checkpoint_id) do
    if Code.ensure_loaded?(ZenohTimeTravel) and GenServer.whereis(ZenohTimeTravel) do
      ZenohTimeTravel.rewind_to(checkpoint_id)
    end

    :ok
  rescue
    _ -> :ok
  end

  # ============================================================
  # PRIVATE - TELEMETRY
  # ============================================================

  defp stream_telemetry(operation, result) do
    status = if match?({:ok, _}, result), do: :success, else: :failure

    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_metric(:gde, operation, 1, %{status: status})
    end
  rescue
    _ -> :ok
  end
end
