defmodule Indrajaal.Cybernetic.OODA.Act do
  @moduledoc """
  OODA Act Phase - Execution with Feedback for v20.0.0

  Implements the Act phase of the OODA loop with:
  - Action execution with safety guards
  - Feedback loop integration
  - Outcome measurement
  - Learning signal generation

  ## Action Execution Model

  A: D × S → S' × F

  Where:
  - D = Decision
  - S = Current state
  - S' = New state
  - F = Feedback signal for learning

  ## Action Types
  - **Observe**: Gather more information
  - **Maintain**: Keep current state
  - **Repair**: Fix degraded components
  - **Escalate**: Request human intervention
  - **Noop**: No operation (wait)

  ## STAMP Constraints
  - SC-EMR-057: Stop < 5s on emergency
  - SC-EMR-060: Rollback capability
  - SC-ACT-001: Action selection < 5ms
  - SC-PRF-055: No blocking operations
  """

  require Logger

  alias Indrajaal.Cybernetic.OODA.Decide

  @type action_result :: %{
          action: atom(),
          success: boolean(),
          outcome: map(),
          duration_ms: non_neg_integer(),
          feedback: map()
        }

  @type act_state :: %{
          executors: map(),
          action_history: [action_result()],
          rollback_stack: [map()],
          emergency_mode: boolean(),
          emergency_mode_since: DateTime.t() | nil,
          emergency_exit_attempts: non_neg_integer()
        }

  # Maximum execution time before timeout (ms)
  @max_execution_time 5000

  # Emergency mode auto-exit timeout (10 seconds) - SC-ACT-002
  @emergency_mode_timeout_ms 10_000

  # Maximum emergency exit attempts before requiring manual intervention
  @max_emergency_exit_attempts 3

  @doc """
  Creates a new act state.
  """
  @spec new(Keyword.t()) :: act_state()
  def new(opts \\ []) do
    %{
      executors: Keyword.get(opts, :executors, default_executors()),
      action_history: [],
      rollback_stack: [],
      emergency_mode: false,
      emergency_mode_since: nil,
      emergency_exit_attempts: 0
    }
  end

  @doc """
  Executes a decision and returns the result with feedback.
  """
  @spec act(Decide.decision(), act_state()) :: {action_result(), act_state()}
  def act(decision, state) do
    # Check emergency mode
    if state.emergency_mode do
      result = emergency_action(decision)
      {result, state}
    else
      # Save rollback point (SC-EMR-060)
      rollback_point = create_rollback_point(decision, state)
      new_rollback_stack = [rollback_point | Enum.take(state.rollback_stack, 9)]

      # Execute with timeout protection
      start_time = System.monotonic_time(:millisecond)

      {success, outcome} =
        try do
          execute_action(decision.action, decision, state.executors)
        rescue
          e ->
            Logger.error("Action execution failed: #{inspect(e)}")
            {false, %{error: inspect(e)}}
        end

      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      # Generate feedback for learning
      feedback = generate_feedback(decision, success, outcome, duration_ms)

      result = %{
        action: decision.action,
        success: success,
        outcome: outcome,
        duration_ms: duration_ms,
        feedback: feedback
      }

      # Update history
      new_history = [result | Enum.take(state.action_history, 99)]

      new_state = %{
        state
        | action_history: new_history,
          rollback_stack: new_rollback_stack
      }

      # Emit telemetry
      emit_telemetry(result)

      {result, new_state}
    end
  end

  @doc """
  Executes an action with the appropriate executor.
  """
  @spec execute_action(atom(), Decide.decision(), map()) :: {boolean(), map()}
  def execute_action(action, decision, executors) do
    executor = Map.get(executors, action, &default_executor/2)

    task =
      Task.async(fn ->
        executor.(action, decision)
      end)

    case Task.yield(task, @max_execution_time) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        Logger.error("Action #{action} timed out after #{@max_execution_time}ms")
        {false, %{error: :timeout}}
    end
  end

  @doc """
  Performs emergency stop (SC-EMR-057).
  """
  @spec emergency_stop(act_state()) :: act_state()
  def emergency_stop(state) do
    Logger.warning("Emergency stop initiated")

    # Cancel any pending actions
    # In production, this would interrupt running processes

    %{
      state
      | emergency_mode: true,
        emergency_mode_since: DateTime.utc_now(),
        emergency_exit_attempts: 0
    }
  end

  @doc """
  Attempts to exit emergency mode (SC-ACT-002).

  Emergency mode can be exited when:
  1. A successful observation has been completed
  2. A successful orientation analysis has passed
  3. The emergency mode timeout has elapsed (10s default)

  Returns {:ok, new_state} on successful exit, {:error, reason} if exit conditions not met.
  """
  @spec emergency_exit(act_state(), map()) :: {:ok, act_state()} | {:error, atom()}
  def emergency_exit(state, conditions \\ %{}) do
    cond do
      not state.emergency_mode ->
        {:error, :not_in_emergency_mode}

      state.emergency_exit_attempts >= @max_emergency_exit_attempts ->
        Logger.warning(
          "Emergency exit: max attempts (#{@max_emergency_exit_attempts}) exceeded, requires manual intervention"
        )

        {:error, :max_attempts_exceeded}

      check_emergency_exit_conditions(state, conditions) ->
        Logger.info("Emergency mode exit: conditions met, returning to normal operation")

        new_state = %{
          state
          | emergency_mode: false,
            emergency_mode_since: nil,
            emergency_exit_attempts: 0
        }

        emit_emergency_exit_telemetry(state)
        {:ok, new_state}

      true ->
        Logger.debug(
          "Emergency exit: conditions not yet met, attempt #{state.emergency_exit_attempts + 1}"
        )

        {:error, :conditions_not_met}
    end
  end

  @doc """
  Checks if emergency mode should auto-exit due to timeout.
  Called periodically by the OODA loop controller.
  """
  @spec check_emergency_timeout(act_state()) :: {:exit, act_state()} | :continue
  def check_emergency_timeout(state) do
    if state.emergency_mode and state.emergency_mode_since do
      elapsed_ms = DateTime.diff(DateTime.utc_now(), state.emergency_mode_since, :millisecond)

      if elapsed_ms >= @emergency_mode_timeout_ms do
        Logger.info(
          "Emergency mode: timeout elapsed (#{elapsed_ms}ms >= #{@emergency_mode_timeout_ms}ms), attempting auto-exit"
        )

        new_state = %{state | emergency_exit_attempts: state.emergency_exit_attempts + 1}

        # Try to exit with timeout condition
        case emergency_exit(new_state, %{timeout_elapsed: true}) do
          {:ok, exited_state} -> {:exit, exited_state}
          {:error, _} -> :continue
        end
      else
        :continue
      end
    else
      :continue
    end
  end

  # Check if emergency exit conditions are satisfied
  defp check_emergency_exit_conditions(state, conditions) do
    timeout_elapsed = Map.get(conditions, :timeout_elapsed, false)
    observation_ok = Map.get(conditions, :observation_success, false)
    orientation_ok = Map.get(conditions, :orientation_success, false)

    # Exit if timeout elapsed OR (observation AND orientation succeeded)
    timeout_elapsed or (observation_ok and orientation_ok) or
      (state.emergency_mode_since &&
         DateTime.diff(DateTime.utc_now(), state.emergency_mode_since, :millisecond) >=
           @emergency_mode_timeout_ms)
  end

  defp emit_emergency_exit_telemetry(state) do
    duration_ms =
      if state.emergency_mode_since do
        DateTime.diff(DateTime.utc_now(), state.emergency_mode_since, :millisecond)
      else
        0
      end

    :telemetry.execute(
      [:indrajaal, :ooda, :emergency_exit],
      %{duration_ms: duration_ms, attempts: state.emergency_exit_attempts},
      %{exit_type: :normal}
    )
  end

  @doc """
  Performs rollback to previous state (SC-EMR-060).
  """
  @spec rollback(act_state()) :: {:ok, act_state()} | {:error, :no_rollback_point}
  def rollback(state) do
    case state.rollback_stack do
      [rollback_point | rest] ->
        Logger.info("Rolling back to: #{inspect(rollback_point.timestamp)}")
        new_state = apply_rollback(state, rollback_point)
        {:ok, %{new_state | rollback_stack: rest}}

      [] ->
        {:error, :no_rollback_point}
    end
  end

  @doc """
  Generates feedback signal for learning.
  """
  @spec generate_feedback(Decide.decision(), boolean(), map(), non_neg_integer()) :: map()
  def generate_feedback(decision, success, outcome, duration_ms) do
    # Calculate reward signal
    reward =
      cond do
        not success -> -1.0
        duration_ms > 1000 -> 0.3
        true -> 1.0
      end

    # Assess prediction accuracy
    prediction_error =
      if Map.has_key?(outcome, :expected_state) and Map.has_key?(outcome, :actual_state) do
        if outcome.expected_state == outcome.actual_state, do: 0.0, else: 1.0
      else
        0.5
      end

    %{
      reward: reward,
      prediction_error: prediction_error,
      action: decision.action,
      decision_type: decision.type,
      execution_time_ms: duration_ms,
      success: success,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Registers a custom executor for an action.
  """
  @spec register_executor(act_state(), atom(), function()) :: act_state()
  def register_executor(state, action, executor) do
    new_executors = Map.put(state.executors, action, executor)
    %{state | executors: new_executors}
  end

  @doc """
  Returns action statistics.
  """
  @spec stats(act_state()) :: map()
  def stats(state) do
    history = state.action_history

    if Enum.empty?(history) do
      %{
        total: 0,
        success_rate: 0.0,
        avg_duration_ms: 0.0,
        by_action: %{}
      }
    else
      success_count = Enum.count(history, & &1.success)
      total_duration = Enum.sum(Enum.map(history, & &1.duration_ms))
      by_action = Enum.frequencies_by(history, & &1.action)

      %{
        total: length(history),
        success_rate: success_count / length(history),
        avg_duration_ms: total_duration / length(history),
        by_action: by_action,
        rollback_points: length(state.rollback_stack),
        emergency_mode: state.emergency_mode
      }
    end
  end

  @doc """
  Returns summary of last action.
  """
  @spec summary(action_result()) :: map()
  def summary(result) do
    %{
      action: result.action,
      success: result.success,
      duration_ms: result.duration_ms,
      reward: result.feedback.reward
    }
  end

  # Private helpers

  defp default_executors do
    %{
      observe: &execute_observe/2,
      maintain: &execute_maintain/2,
      repair: &execute_repair/2,
      escalate: &execute_escalate/2,
      noop: &execute_noop/2
    }
  end

  defp default_executor(action, _decision) do
    Logger.debug("Default executor for #{action}")
    {true, %{executed: action}}
  end

  defp execute_observe(_action, _decision) do
    # Trigger additional sensor collection
    Logger.debug("Executing observe action")
    {true, %{observation_triggered: true}}
  end

  defp execute_maintain(_action, _decision) do
    # Maintain current operational state
    Logger.debug("Executing maintain action")
    {true, %{maintained: true}}
  end

  defp execute_repair(_action, decision) do
    # Attempt repair based on identified issues
    Logger.info("Executing repair action for #{inspect(decision.rationale)}")

    # Simulated repair - in production would call actual repair procedures
    {true, %{repaired: true, items: []}}
  end

  defp execute_escalate(_action, decision) do
    # Escalate to human operator
    Logger.warning("Escalating: #{inspect(decision.rationale)}")

    # In production, would send alerts/notifications
    {true, %{escalated: true, notified: [:ops_team]}}
  end

  defp execute_noop(_action, _decision) do
    # No operation
    {true, %{noop: true}}
  end

  defp emergency_action(decision) do
    Logger.warning("Emergency mode: minimal action for #{decision.action}")

    %{
      action: :emergency_noop,
      success: true,
      outcome: %{emergency_mode: true},
      duration_ms: 0,
      feedback: %{reward: 0.0, prediction_error: 0.0}
    }
  end

  defp create_rollback_point(decision, state) do
    %{
      timestamp: DateTime.utc_now(),
      decision: decision,
      history_snapshot: Enum.take(state.action_history, 5)
    }
  end

  defp apply_rollback(state, _rollback_point) do
    # In production, would restore system state
    state
  end

  defp emit_telemetry(result) do
    :telemetry.execute(
      [:indrajaal, :ooda, :act],
      %{
        duration_ms: result.duration_ms,
        success: if(result.success, do: 1, else: 0),
        reward: result.feedback.reward
      },
      %{
        action: result.action
      }
    )
  end
end
