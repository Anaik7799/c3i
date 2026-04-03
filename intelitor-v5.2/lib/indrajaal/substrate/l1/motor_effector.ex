defmodule Indrajaal.Substrate.L1.MotorEffector do
  @moduledoc """
  ## Design Intent
  L1 substrate motor effector — executes actions in response to commands received
  from sensory neurons or higher-layer controllers. Tracks action_count,
  last_action, and success_rate using a sliding window of outcomes.

  Command execution model:
    - Commands arrive via `execute/2` specifying action type and parameters
    - Each command dispatched to a registered action handler or default handler
    - Outcome (success/failure) recorded in a circular buffer of last N outcomes
    - success_rate = successes / total in window
    - Commands broadcast to PubSub "substrate:motor_output"

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-PHICS-001: Commands logged to Immutable Register — REFERENCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "substrate:motor_output"
  @window_size 100

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Execute an action command.
  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec execute(atom(), map()) :: {:ok, term()} | {:error, term()}
  def execute(action_type, params \\ %{})
      when is_atom(action_type) and is_map(params) do
    GenServer.call(@name, {:execute, action_type, params})
  end

  @doc "Register a handler for an action type: `fun(params) :: {:ok, result} | {:error, reason}`."
  @spec register_action(atom(), function()) :: :ok
  def register_action(action_type, fun)
      when is_atom(action_type) and is_function(fun, 1) do
    GenServer.call(@name, {:register_action, action_type, fun})
  end

  @doc "Returns effector status."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    handlers = Keyword.get(opts, :handlers, %{})

    state = %{
      handlers: handlers,
      action_count: 0,
      success_count: 0,
      failure_count: 0,
      outcome_window: :queue.new(),
      window_successes: 0,
      window_total: 0,
      last_action: nil,
      last_action_at: nil,
      started_at: DateTime.utc_now()
    }

    Logger.info("[MOTOR_EFFECTOR] started — handlers=#{map_size(handlers)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:execute, action_type, params}, _from, state) do
    {result, outcome} = dispatch_action(action_type, params, state.handlers)

    new_state = record_outcome(state, action_type, params, outcome, result)

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:motor_action, %{action: action_type, params: params, outcome: outcome, result: result}}
    )

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:register_action, action_type, fun}, _from, state) do
    {:reply, :ok, %{state | handlers: Map.put(state.handlers, action_type, fun)}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    success_rate =
      if state.window_total > 0,
        do: state.window_successes / state.window_total,
        else: 0.0

    {:reply,
     %{
       action_count: state.action_count,
       success_count: state.success_count,
       failure_count: state.failure_count,
       success_rate: Float.round(success_rate, 4),
       window_size: state.window_total,
       last_action: state.last_action,
       last_action_at: state.last_action_at
     }, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec dispatch_action(atom(), map(), map()) ::
          {{:ok, term()} | {:error, term()}, :success | :failure}
  defp dispatch_action(action_type, params, handlers) do
    handler = Map.get(handlers, action_type, &default_handler/1)

    try do
      case handler.(params) do
        {:ok, result} -> {{:ok, result}, :success}
        {:error, reason} -> {{:error, reason}, :failure}
        other -> {{:ok, other}, :success}
      end
    rescue
      e ->
        Logger.warning("[MOTOR_EFFECTOR] action #{action_type} raised #{inspect(e)}")
        {{:error, {:exception, e}}, :failure}
    end
  end

  defp default_handler(params) do
    {:ok, Map.put(params, :executed_by, :default_handler)}
  end

  @spec record_outcome(map(), atom(), map(), :success | :failure, term()) :: map()
  defp record_outcome(state, action_type, _params, outcome, _result) do
    is_success = outcome == :success

    # Sliding window maintenance
    {new_window, new_win_succ, new_win_total} =
      if :queue.len(state.outcome_window) >= @window_size do
        {{:value, evicted}, trimmed} = :queue.out(state.outcome_window)
        evicted_success = if evicted == :success, do: 1, else: 0

        {
          :queue.in(outcome, trimmed),
          state.window_successes - evicted_success + if(is_success, do: 1, else: 0),
          state.window_total
        }
      else
        {
          :queue.in(outcome, state.outcome_window),
          state.window_successes + if(is_success, do: 1, else: 0),
          state.window_total + 1
        }
      end

    %{
      state
      | action_count: state.action_count + 1,
        success_count: state.success_count + if(is_success, do: 1, else: 0),
        failure_count: state.failure_count + if(is_success, do: 0, else: 1),
        outcome_window: new_window,
        window_successes: new_win_succ,
        window_total: new_win_total,
        last_action: action_type,
        last_action_at: DateTime.utc_now()
    }
  end
end
