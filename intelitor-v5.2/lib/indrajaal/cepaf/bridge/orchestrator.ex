defmodule Indrajaal.CEPAF.Bridge.Orchestrator do
  @moduledoc """
  CEPAF Orchestrator - Cross-Language Workflow Coordination for v20.0.0

  Coordinates workflow execution between Elixir and F# runtimes:
  - Workflow scheduling
  - State management
  - Cross-runtime coordination
  - Failure handling

  ## Orchestration Model

  Workflows are executed as:
  1. Elixir parses and validates workflow
  2. F# executes computation-heavy tasks
  3. Elixir handles IO and side effects
  4. Results synchronized via Bridge

  ## STAMP Constraints
  - SC-ORC-001: Workflow state MUST be recoverable
  - SC-ORC-002: Cross-runtime calls MUST timeout
  - SC-ORC-003: Failures MUST trigger compensation
  - SC-ORC-004: State MUST be consistent
  """

  use GenServer
  require Logger

  alias Indrajaal.CEPAF.Bridge.{Bridge, Grammar}

  @type workflow_id :: String.t()
  @type workflow_status :: :pending | :running | :paused | :completed | :failed | :compensating

  @type workflow_instance :: %{
          id: workflow_id(),
          workflow: Grammar.workflow(),
          status: workflow_status(),
          current_step: non_neg_integer(),
          state: map(),
          started_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          error: term() | nil
        }

  @type state :: %{
          instances: map(),
          completed: [workflow_id()],
          stats: map(),
          config: map()
        }

  # Max concurrent workflows
  @max_concurrent 100

  # Step execution timeout
  @step_timeout 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts a workflow execution.
  """
  @spec start_workflow(Grammar.workflow(), map()) :: {:ok, workflow_id()} | {:error, term()}
  def start_workflow(workflow, initial_state \\ %{}) do
    GenServer.call(__MODULE__, {:start_workflow, workflow, initial_state})
  end

  @doc """
  Gets workflow status.
  """
  @spec get_status(workflow_id()) :: {:ok, workflow_instance()} | {:error, :not_found}
  def get_status(workflow_id) do
    GenServer.call(__MODULE__, {:get_status, workflow_id})
  end

  @doc """
  Pauses a running workflow.
  """
  @spec pause(workflow_id()) :: :ok | {:error, term()}
  def pause(workflow_id) do
    GenServer.call(__MODULE__, {:pause, workflow_id})
  end

  @doc """
  Resumes a paused workflow.
  """
  @spec resume(workflow_id()) :: :ok | {:error, term()}
  def resume(workflow_id) do
    GenServer.call(__MODULE__, {:resume, workflow_id})
  end

  @doc """
  Cancels a workflow.
  """
  @spec cancel(workflow_id()) :: :ok | {:error, term()}
  def cancel(workflow_id) do
    GenServer.call(__MODULE__, {:cancel, workflow_id})
  end

  @doc """
  Lists active workflows.
  """
  @spec list_active() :: [workflow_instance()]
  def list_active do
    GenServer.call(__MODULE__, :list_active)
  end

  @doc """
  Gets orchestrator statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      instances: %{},
      completed: [],
      stats: %{
        workflows_started: 0,
        workflows_completed: 0,
        workflows_failed: 0,
        steps_executed: 0,
        compensations: 0
      },
      config: %{
        max_concurrent: Keyword.get(opts, :max_concurrent, @max_concurrent),
        step_timeout: Keyword.get(opts, :step_timeout, @step_timeout),
        persist_state: Keyword.get(opts, :persist_state, true)
      }
    }

    Logger.info("🎭 CEPAF Orchestrator started")

    {:ok, state}
  end

  @impl true
  def handle_call({:start_workflow, workflow, initial_state}, _from, state) do
    if map_size(state.instances) >= state.config.max_concurrent do
      {:reply, {:error, :too_many_workflows}, state}
    else
      # Validate workflow
      case Grammar.validate(workflow) do
        :ok ->
          workflow_id = generate_id()

          instance = %{
            id: workflow_id,
            workflow: workflow,
            status: :pending,
            current_step: 0,
            state: initial_state,
            history: [],
            started_at: DateTime.utc_now(),
            completed_at: nil,
            error: nil
          }

          new_instances = Map.put(state.instances, workflow_id, instance)
          new_stats = %{state.stats | workflows_started: state.stats.workflows_started + 1}

          # Start execution
          send(self(), {:execute, workflow_id})

          {:reply, {:ok, workflow_id}, %{state | instances: new_instances, stats: new_stats}}

        {:error, errors} ->
          {:reply, {:error, {:validation_failed, errors}}, state}
      end
    end
  end

  @impl true
  def handle_call({:get_status, workflow_id}, _from, state) do
    case Map.get(state.instances, workflow_id) do
      nil -> {:reply, {:error, :not_found}, state}
      instance -> {:reply, {:ok, instance}, state}
    end
  end

  @impl true
  def handle_call({:pause, workflow_id}, _from, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :running} = instance ->
        updated = %{instance | status: :paused}
        new_instances = Map.put(state.instances, workflow_id, updated)
        {:reply, :ok, %{state | instances: new_instances}}

      _ ->
        {:reply, {:error, :not_running}, state}
    end
  end

  @impl true
  def handle_call({:resume, workflow_id}, _from, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :paused} = instance ->
        updated = %{instance | status: :running}
        new_instances = Map.put(state.instances, workflow_id, updated)
        send(self(), {:execute, workflow_id})
        {:reply, :ok, %{state | instances: new_instances}}

      _ ->
        {:reply, {:error, :not_paused}, state}
    end
  end

  @impl true
  def handle_call({:cancel, workflow_id}, _from, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      instance ->
        # Trigger compensation
        send(self(), {:compensate, workflow_id})
        updated = %{instance | status: :compensating}
        new_instances = Map.put(state.instances, workflow_id, updated)
        {:reply, :ok, %{state | instances: new_instances}}
    end
  end

  @impl true
  def handle_call(:list_active, _from, state) do
    active =
      state.instances
      |> Map.values()
      |> Enum.filter(fn i -> i.status in [:pending, :running, :paused] end)

    {:reply, active, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        active_workflows: map_size(state.instances),
        completed_count: length(state.completed)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:execute, workflow_id}, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:noreply, state}

      %{status: status} when status not in [:pending, :running] ->
        {:noreply, state}

      instance ->
        # Execute next step
        new_state = execute_step(instance, state)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:step_complete, workflow_id, step_idx, result}, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:noreply, state}

      instance ->
        # Update instance state
        new_instance_state = Map.merge(instance.state, result)
        history = [{step_idx, :completed, DateTime.utc_now()} | instance.history]

        updated = %{
          instance
          | current_step: step_idx + 1,
            state: new_instance_state,
            history: history
        }

        new_instances = Map.put(state.instances, workflow_id, updated)
        new_stats = %{state.stats | steps_executed: state.stats.steps_executed + 1}

        # Continue execution
        send(self(), {:execute, workflow_id})

        {:noreply, %{state | instances: new_instances, stats: new_stats}}
    end
  end

  @impl true
  def handle_info({:step_failed, workflow_id, step_idx, error}, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:noreply, state}

      instance ->
        history = [{step_idx, :failed, DateTime.utc_now()} | instance.history]

        updated = %{
          instance
          | status: :failed,
            error: error,
            history: history,
            completed_at: DateTime.utc_now()
        }

        new_instances = Map.put(state.instances, workflow_id, updated)
        new_stats = %{state.stats | workflows_failed: state.stats.workflows_failed + 1}

        # Trigger compensation
        send(self(), {:compensate, workflow_id})

        {:noreply, %{state | instances: new_instances, stats: new_stats}}
    end
  end

  @impl true
  def handle_info({:compensate, workflow_id}, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:noreply, state}

      instance ->
        # Run compensation in reverse order
        compensation_steps =
          instance.history
          |> Enum.filter(fn {_, status, _} -> status == :completed end)
          |> Enum.reverse()

        Task.start(fn ->
          compensate_steps(compensation_steps, instance)
        end)

        updated = %{instance | status: :compensating}
        new_instances = Map.put(state.instances, workflow_id, updated)
        new_stats = %{state.stats | compensations: state.stats.compensations + 1}

        {:noreply, %{state | instances: new_instances, stats: new_stats}}
    end
  end

  @impl true
  def handle_info({:workflow_complete, workflow_id}, state) do
    case Map.get(state.instances, workflow_id) do
      nil ->
        {:noreply, state}

      instance ->
        updated = %{
          instance
          | status: :completed,
            completed_at: DateTime.utc_now()
        }

        # Move to completed list
        new_instances = Map.delete(state.instances, workflow_id)
        new_completed = [workflow_id | Enum.take(state.completed, 999)]
        new_stats = %{state.stats | workflows_completed: state.stats.workflows_completed + 1}

        Logger.info("🎭 Workflow #{workflow_id} completed")

        # Persist final state if configured
        if state.config.persist_state do
          persist_workflow_state(updated)
        end

        {:noreply,
         %{state | instances: new_instances, completed: new_completed, stats: new_stats}}
    end
  end

  # Private helpers

  defp generate_id do
    bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(bytes, case: :lower)
  end

  defp execute_step(instance, state) do
    steps = instance.workflow.steps
    step_idx = instance.current_step

    if step_idx >= length(steps) do
      # Workflow complete
      send(self(), {:workflow_complete, instance.id})
      state
    else
      step = Enum.at(steps, step_idx)
      updated = %{instance | status: :running}
      new_instances = Map.put(state.instances, instance.id, updated)

      # Execute step asynchronously
      Task.start(fn ->
        result = execute_single_step(step, instance.state, state.config)

        case result do
          {:ok, output} ->
            send(self(), {:step_complete, instance.id, step_idx, output})

          {:error, error} ->
            send(self(), {:step_failed, instance.id, step_idx, error})
        end
      end)

      %{state | instances: new_instances}
    end
  end

  defp execute_single_step(
         %{type: :action, name: name, body: args, constraints: constraints},
         workflow_state,
         config
       ) do
    timeout = find_timeout(constraints, config.step_timeout)

    task =
      Task.async(fn ->
        # Determine execution target
        if should_execute_in_fsharp?(name) do
          Bridge.command(name, %{args: args, state: workflow_state})
        else
          execute_locally(name, args, workflow_state)
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  defp execute_single_step(%{type: :parallel, body: steps}, workflow_state, config) do
    tasks =
      steps
      |> Enum.map(fn step ->
        Task.async(fn ->
          execute_single_step(step, workflow_state, config)
        end)
      end)

    results = Task.yield_many(tasks, config.step_timeout)

    errors =
      results
      |> Enum.filter(fn
        {_, {:ok, {:error, _}}} -> true
        {_, nil} -> true
        _ -> false
      end)

    if Enum.empty?(errors) do
      outputs =
        results
        |> Enum.map(fn {_, {:ok, {:ok, out}}} -> out end)
        |> Enum.reduce(%{}, &Map.merge/2)

      {:ok, outputs}
    else
      {:error, :parallel_step_failed}
    end
  end

  defp execute_single_step(
         %{type: :choice, body: %{condition: condition, then: then_steps, else: else_steps}},
         workflow_state,
         config
       ) do
    if evaluate_condition(condition, workflow_state) do
      execute_sequence(then_steps, workflow_state, config)
    else
      execute_sequence(else_steps, workflow_state, config)
    end
  end

  defp execute_single_step(
         %{type: :loop, body: %{condition: condition, body: body_steps}},
         workflow_state,
         config
       ) do
    execute_loop(condition, body_steps, workflow_state, config)
  end

  defp execute_single_step(%{type: :sequence, body: steps}, workflow_state, config) do
    execute_sequence(steps, workflow_state, config)
  end

  defp execute_sequence([], workflow_state, _config), do: {:ok, workflow_state}

  defp execute_sequence([step | rest], workflow_state, config) do
    case execute_single_step(step, workflow_state, config) do
      {:ok, new_state} ->
        merged = Map.merge(workflow_state, new_state)
        execute_sequence(rest, merged, config)

      error ->
        error
    end
  end

  defp execute_loop(condition, body_steps, workflow_state, config) do
    if evaluate_condition(condition, workflow_state) do
      case execute_sequence(body_steps, workflow_state, config) do
        {:ok, new_state} ->
          merged = Map.merge(workflow_state, new_state)
          execute_loop(condition, body_steps, merged, config)

        error ->
          error
      end
    else
      {:ok, workflow_state}
    end
  end

  defp find_timeout(constraints, default) do
    case constraints |> Enum.find(fn c -> c.type == :timeout end) do
      nil -> default
      %{value: ms} -> ms
    end
  end

  defp should_execute_in_fsharp?(action_name) do
    # Actions that should run in F# runtime
    fsharp_actions = [:compute, :transform, :aggregate, :analyze, :optimize]
    action_name in fsharp_actions
  end

  defp execute_locally(action_name, args, workflow_state) do
    # Execute Elixir-side actions
    case action_name do
      :log ->
        Logger.info("Workflow: #{inspect(args)}")
        {:ok, %{}}

      :delay ->
        Process.sleep(args[:ms] || 1000)
        {:ok, %{}}

      :assign ->
        {:ok, args}

      :fetch ->
        # Simulate data fetch
        {:ok, %{data: "fetched_#{args[:key]}"}}

      _ ->
        {:ok, Map.put(workflow_state, :last_action, action_name)}
    end
  end

  defp evaluate_condition(condition, workflow_state) when is_list(condition) do
    # Simple condition evaluation
    case condition do
      [:eq, key, value] -> Map.get(workflow_state, key) == value
      [:neq, key, value] -> Map.get(workflow_state, key) != value
      [:gt, key, value] -> Map.get(workflow_state, key) > value
      [:lt, key, value] -> Map.get(workflow_state, key) < value
      [:has, key] -> Map.has_key?(workflow_state, key)
      _ -> true
    end
  end

  defp evaluate_condition(condition, workflow_state) when is_atom(condition) do
    Map.get(workflow_state, condition, false)
  end

  defp evaluate_condition(_, _), do: true

  defp compensate_steps([], _instance) do
    Logger.info("Compensation complete")
  end

  defp compensate_steps([{step_idx, :completed, _} | rest], instance) do
    step = Enum.at(instance.workflow.steps, step_idx)
    compensate_step(step)
    compensate_steps(rest, instance)
  end

  defp compensate_step(%{type: :action, name: name, body: args}) do
    compensation_name = :"compensate_#{name}"
    Logger.info("Compensating #{name}")

    # Try to call compensation handler
    try do
      Bridge.command(compensation_name, args)
    rescue
      _ -> :ok
    end
  end

  defp compensate_step(_), do: :ok

  defp persist_workflow_state(instance) do
    # Would persist to database/file
    Logger.debug("Persisting workflow state: #{instance.id}")
  end
end
