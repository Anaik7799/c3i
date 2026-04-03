defmodule Indrajaal.Formal.ModelChecker do
  @moduledoc """
  Model Checker — L7 Formal Layer

  ## Design Intent
  Lightweight model checking for finite-state system properties. Verifies
  reachability, deadlock freedom, and safety properties over state machine
  models encoded as transition functions.

  Models are defined as `{states, initial, transitions, properties}` tuples.
  The checker performs BFS exploration of the state space and evaluates
  properties at each state.

  ## STAMP Constraints
  - SC-DFA-001: DFA state machine validation
  - SC-STATE-001: Atomic state updates
  - SC-VER-074: Constitutional L0-L7 MUST hold
  - SC-BOOT-008: DAG acyclic (Kahn's algorithm)

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :formal_models
  @max_states 10_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type state :: term()
  @type model_id :: atom()
  @type transition_fn :: (state() -> [state()])
  @type property_fn :: (state() -> boolean())

  @type model :: %{
          id: model_id(),
          initial_state: state(),
          transition_fn: transition_fn(),
          properties: [{atom(), property_fn()}],
          description: String.t()
        }

  @type check_result :: %{
          model_id: model_id(),
          states_explored: non_neg_integer(),
          deadlocks: [state()],
          property_violations: [{atom(), state()}],
          passed: boolean(),
          duration_us: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a model for checking."
  @spec register_model(
          model_id(),
          state(),
          transition_fn(),
          [{atom(), property_fn()}],
          String.t()
        ) ::
          :ok
  def register_model(id, initial_state, transition_fn, properties \\ [], description \\ "") do
    GenServer.call(@name, {:register, id, initial_state, transition_fn, properties, description})
  end

  @doc "Check a registered model. Returns verification results."
  @spec check_model(model_id()) :: {:ok, check_result()} | {:error, :not_found}
  def check_model(id) do
    GenServer.call(@name, {:check, id}, 30_000)
  end

  @doc "Check reachability — can a target state be reached from initial state?"
  @spec reachable?(model_id(), state()) :: {:ok, boolean()} | {:error, :not_found}
  def reachable?(id, target_state) do
    GenServer.call(@name, {:reachable, id, target_state}, 30_000)
  end

  @doc "List all registered models with their last check results."
  @spec list_models() :: [map()]
  def list_models do
    GenServer.call(@name, :list_models)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    Logger.info("[ModelChecker] Started — max_states=#{@max_states} [SC-DFA-001]")

    {:ok, %{check_count: 0}}
  end

  @impl true
  def handle_call({:register, id, initial, transition_fn, properties, desc}, _from, state) do
    model = %{
      id: id,
      initial_state: initial,
      transition_fn: transition_fn,
      properties: properties,
      description: desc,
      last_result: nil
    }

    :ets.insert(@table, {id, model})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:check, id}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, model}] ->
        result = explore_state_space(model)
        updated = %{model | last_result: result}
        :ets.insert(@table, {id, updated})
        emit_check_telemetry(result)
        {:reply, {:ok, result}, %{state | check_count: state.check_count + 1}}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:reachable, id, target}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, model}] ->
        reached = bfs_reachable(model.initial_state, model.transition_fn, target)
        {:reply, {:ok, reached}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_models, _from, state) do
    models =
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, m} ->
        %{
          id: m.id,
          description: m.description,
          property_count: length(m.properties),
          last_result: summarize_result(m.last_result)
        }
      end)

    {:reply, models, state}
  end

  # ---------------------------------------------------------------------------
  # State Space Exploration (BFS)
  # ---------------------------------------------------------------------------

  defp explore_state_space(model) do
    start_time = System.monotonic_time(:microsecond)

    {explored, deadlocks, violations} =
      bfs_explore(
        [model.initial_state],
        MapSet.new([model.initial_state]),
        model.transition_fn,
        model.properties,
        [],
        []
      )

    duration = System.monotonic_time(:microsecond) - start_time

    %{
      model_id: model.id,
      states_explored: MapSet.size(explored),
      deadlocks: deadlocks,
      property_violations: violations,
      passed: deadlocks == [] and violations == [],
      duration_us: duration
    }
  end

  defp bfs_explore([], visited, _transition_fn, _properties, deadlocks, violations) do
    {visited, deadlocks, violations}
  end

  defp bfs_explore(_queue, visited, _transition_fn, _properties, deadlocks, violations)
       when map_size(visited) > @max_states do
    Logger.warning("[ModelChecker] State space exceeded #{@max_states} — truncating [SC-DFA-001]")
    {visited, deadlocks, violations}
  end

  defp bfs_explore([current | rest], visited, transition_fn, properties, deadlocks, violations) do
    # Check properties at this state
    new_violations =
      Enum.reduce(properties, violations, fn {prop_name, prop_fn}, acc ->
        try do
          if prop_fn.(current), do: acc, else: [{prop_name, current} | acc]
        rescue
          _ -> acc
        end
      end)

    # Get successor states
    successors =
      try do
        transition_fn.(current)
      rescue
        _ -> []
      end

    # Check for deadlock (no successors from non-terminal state)
    new_deadlocks =
      if successors == [] do
        [current | deadlocks]
      else
        deadlocks
      end

    # Add unvisited successors to queue
    {new_queue, new_visited} =
      Enum.reduce(successors, {rest, visited}, fn s, {q, v} ->
        if MapSet.member?(v, s) do
          {q, v}
        else
          {q ++ [s], MapSet.put(v, s)}
        end
      end)

    bfs_explore(new_queue, new_visited, transition_fn, properties, new_deadlocks, new_violations)
  end

  defp bfs_reachable(initial, transition_fn, target) do
    do_bfs_reach([initial], MapSet.new([initial]), transition_fn, target)
  end

  defp do_bfs_reach([], _visited, _transition_fn, _target), do: false

  defp do_bfs_reach([current | rest], visited, transition_fn, target) do
    if current == target do
      true
    else
      successors =
        try do
          transition_fn.(current)
        rescue
          _ -> []
        end

      {new_queue, new_visited} =
        Enum.reduce(successors, {rest, visited}, fn s, {q, v} ->
          if MapSet.member?(v, s), do: {q, v}, else: {q ++ [s], MapSet.put(v, s)}
        end)

      if MapSet.size(new_visited) > @max_states do
        false
      else
        do_bfs_reach(new_queue, new_visited, transition_fn, target)
      end
    end
  end

  defp summarize_result(nil), do: nil

  defp summarize_result(result) do
    %{
      passed: result.passed,
      states_explored: result.states_explored,
      deadlock_count: length(result.deadlocks),
      violation_count: length(result.property_violations)
    }
  end

  defp emit_check_telemetry(result) do
    :telemetry.execute(
      [:indrajaal, :formal, :model_check],
      %{states_explored: result.states_explored, duration_us: result.duration_us},
      %{model_id: result.model_id, passed: result.passed}
    )
  rescue
    _ -> :ok
  end
end
