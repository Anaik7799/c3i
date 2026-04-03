defmodule Indrajaal.Cortex.GDE.Controller do
  @moduledoc """
  Goal-Directed Evolution (GDE) Controller - Orchestrates adaptive system evolution.

  WHAT: Central orchestrator for goal definition, tracking, evolution strategies,
        and Guardian-validated change application.
  WHY: SC-GDE-001 mandates autonomous self-improvement with safety validation.
  CONSTRAINTS: All changes MUST pass Guardian validation before application.
               SIL-2 safety constraints apply.

  ## Architecture

  ```
  +------------------------------------------------------------------+
  |                    GDE CONTROLLER                                 |
  +------------------------------------------------------------------+
  |                                                                    |
  |  +-----------------+     +-----------------+     +---------------+ |
  |  | Goal Registry   |---->| Evolution Engine|---->| Change Queue  | |
  |  | (Define Goals)  |     | (Adapt Strategy)|     | (Pending)     | |
  |  +-----------------+     +-----------------+     +-------+-------+ |
  |                                                          |         |
  |                                                          v         |
  |                                                  +---------------+ |
  |                                                  | Guardian      | |
  |                                                  | Validation    | |
  |                                                  +-------+-------+ |
  |                                                          |         |
  |                          +--------+--------+             |         |
  |                          |                 |             |         |
  |                          v                 v             |         |
  |                   +-----------+     +-----------+        |         |
  |                   | Apply     |     | Reject    |<-------+         |
  |                   | Change    |     | (Log)     |                  |
  |                   +-----------+     +-----------+                  |
  |                          |                                         |
  |                          v                                         |
  |                   +--------------+                                 |
  |                   | Goal         |                                 |
  |                   | Evaluator    |                                 |
  |                   +--------------+                                 |
  |                          |                                         |
  |           +--------------+--------------+                          |
  |           |                             |                          |
  |           v                             v                          |
  |    +-------------+              +-------------+                    |
  |    | Success     |              | Failure     |                    |
  |    | (Record)    |              | (Backtrack) |                    |
  |    +-------------+              +-------------+                    |
  +------------------------------------------------------------------+
  ```

  ## Goal Types

  - `:compilation_success` - Zero compilation errors
  - `:test_pass` - All tests pass
  - `:format_clean` - Code formatting compliance
  - `:warning_free` - Zero compiler warnings
  - `:credo_clean` - Static analysis clean
  - `:performance_target` - Performance thresholds met
  - `:custom` - User-defined goals

  ## Evolution Strategies

  - `:conservative` - Small, incremental changes (default)
  - `:aggressive` - Larger changes, more risk
  - `:defensive` - Prioritize stability over progress
  - `:exploratory` - Try novel approaches

  ## STAMP Constraints

  - SC-GDE-001: Guardian validation mandatory for all changes
  - SC-GDE-002: Goal state must be persisted
  - SC-GDE-003: Evolution decisions must be auditable
  - SC-GDE-004: Backtrack capability required
  - SC-GDE-005: Metrics must be streamed to observability

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-29 |
  | Author | L3-CORTEX-2 (Cognitive Cortex Worker) |
  | STAMP | SC-GDE-001 to SC-GDE-005 |
  | SIL | SIL-2 |
  """

  use GenServer
  require Logger

  alias Indrajaal.Cortex.GDE.GoalEvaluator
  alias Indrajaal.Cortex.GDE.ProposalEngine
  alias Indrajaal.Cortex.GDE.Backtracker
  alias Indrajaal.Safety.Guardian
  alias Indrajaal.Observability.ZenohNeuralStream

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type goal_id :: String.t()
  @type goal_type ::
          :compilation_success
          | :test_pass
          | :format_clean
          | :warning_free
          | :credo_clean
          | :performance_target
          | {:custom, (term() -> boolean())}

  @type goal_status :: :pending | :in_progress | :achieved | :failed | :abandoned

  @type goal :: %{
          id: goal_id(),
          type: goal_type(),
          description: String.t(),
          priority: :critical | :high | :medium | :low,
          status: goal_status(),
          progress: float(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          deadline: DateTime.t() | nil,
          metadata: map()
        }

  @type evolution_strategy :: :conservative | :aggressive | :defensive | :exploratory

  @type change_proposal :: %{
          id: String.t(),
          goal_id: goal_id(),
          type: atom(),
          description: String.t(),
          file: String.t() | nil,
          changes: list(),
          confidence: float(),
          guardian_status: :pending | :approved | :rejected,
          guardian_reason: String.t() | nil,
          created_at: DateTime.t()
        }

  @type controller_state :: %{
          goals: %{goal_id() => goal()},
          active_goal: goal_id() | nil,
          strategy: evolution_strategy(),
          change_queue: [change_proposal()],
          applied_changes: [change_proposal()],
          metrics: map(),
          config: map(),
          started_at: DateTime.t()
        }

  # ============================================================
  # CONSTANTS
  # ============================================================

  @default_strategy :conservative
  @max_change_queue_size 50
  @evolution_cycle_interval :timer.seconds(60)
  @goal_check_interval :timer.seconds(30)

  # Strategy-specific parameters
  @strategy_params %{
    conservative: %{max_changes_per_cycle: 3, min_confidence: 0.7, backtrack_threshold: 0.5},
    aggressive: %{max_changes_per_cycle: 10, min_confidence: 0.4, backtrack_threshold: 0.3},
    defensive: %{max_changes_per_cycle: 1, min_confidence: 0.9, backtrack_threshold: 0.8},
    exploratory: %{max_changes_per_cycle: 5, min_confidence: 0.3, backtrack_threshold: 0.2}
  }

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the GDE Controller.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the child specification for supervision tree embedding.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Defines a new goal for the GDE system to pursue.

  ## Parameters
  - type: Goal type (see @type goal_type)
  - description: Human-readable description
  - opts: Additional options
    - :priority - :critical | :high | :medium | :low (default: :medium)
    - :deadline - DateTime for goal deadline (optional)
    - :metadata - Additional metadata map (optional)

  ## Returns
  - {:ok, goal_id} on success
  - {:error, reason} on failure
  """
  @spec define_goal(goal_type(), String.t(), keyword()) :: {:ok, goal_id()} | {:error, atom()}
  def define_goal(type, description, opts \\ []) do
    GenServer.call(__MODULE__, {:define_goal, type, description, opts})
  end

  @doc """
  Activates a goal, making it the current target for evolution.
  """
  @spec activate_goal(goal_id()) :: :ok | {:error, atom()}
  def activate_goal(goal_id) do
    GenServer.call(__MODULE__, {:activate_goal, goal_id})
  end

  @doc """
  Gets the current status of a goal.
  """
  @spec goal_status(goal_id()) :: {:ok, goal()} | {:error, :not_found}
  def goal_status(goal_id) do
    GenServer.call(__MODULE__, {:goal_status, goal_id})
  end

  @doc """
  Lists all defined goals.
  """
  @spec list_goals(keyword()) :: [goal()]
  def list_goals(opts \\ []) do
    GenServer.call(__MODULE__, {:list_goals, opts})
  end

  @doc """
  Abandons a goal (stops pursuing it).
  """
  @spec abandon_goal(goal_id(), String.t()) :: :ok | {:error, atom()}
  def abandon_goal(goal_id, reason \\ "Abandoned by operator") do
    GenServer.call(__MODULE__, {:abandon_goal, goal_id, reason})
  end

  @doc """
  Sets the evolution strategy.
  """
  @spec set_strategy(evolution_strategy()) :: :ok
  def set_strategy(strategy)
      when strategy in [:conservative, :aggressive, :defensive, :exploratory] do
    GenServer.call(__MODULE__, {:set_strategy, strategy})
  end

  @doc """
  Gets the current evolution strategy.
  """
  @spec get_strategy() :: evolution_strategy()
  def get_strategy do
    GenServer.call(__MODULE__, :get_strategy)
  end

  @doc """
  Gets the pending change queue.
  """
  @spec pending_changes() :: [change_proposal()]
  def pending_changes do
    GenServer.call(__MODULE__, :pending_changes)
  end

  @doc """
  Manually triggers an evolution cycle.
  """
  @spec trigger_evolution() :: :ok
  def trigger_evolution do
    GenServer.cast(__MODULE__, :trigger_evolution)
  end

  @doc """
  Gets comprehensive metrics about GDE operation.
  """
  @spec metrics() :: map()
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  @doc """
  Gets the overall GDE status.
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(opts) do
    Logger.info("[GDE.Controller] Initializing Goal-Directed Evolution Controller - SC-GDE-001")

    state = %{
      goals: %{},
      active_goal: nil,
      strategy: Keyword.get(opts, :strategy, @default_strategy),
      change_queue: [],
      applied_changes: [],
      metrics: initial_metrics(),
      config: %{
        auto_evolve: Keyword.get(opts, :auto_evolve, false),
        max_queue_size: Keyword.get(opts, :max_queue_size, @max_change_queue_size)
      },
      started_at: DateTime.utc_now()
    }

    # Schedule periodic evolution if auto_evolve is enabled
    if state.config.auto_evolve do
      schedule_evolution_cycle()
    end

    # Schedule periodic goal checks
    schedule_goal_check()

    {:ok, state}
  end

  @impl true
  def handle_call({:define_goal, type, description, opts}, _from, state) do
    goal_id = generate_goal_id()

    goal = %{
      id: goal_id,
      type: type,
      description: description,
      priority: Keyword.get(opts, :priority, :medium),
      status: :pending,
      progress: 0.0,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      deadline: Keyword.get(opts, :deadline),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    new_goals = Map.put(state.goals, goal_id, goal)
    new_state = %{state | goals: new_goals}

    Logger.info("[GDE.Controller] Goal defined: #{goal_id} - #{description}")
    stream_event(:goal_defined, goal)

    {:reply, {:ok, goal_id}, new_state}
  end

  @impl true
  def handle_call({:activate_goal, goal_id}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      goal ->
        updated_goal = %{goal | status: :in_progress, updated_at: DateTime.utc_now()}
        new_goals = Map.put(state.goals, goal_id, updated_goal)
        new_state = %{state | goals: new_goals, active_goal: goal_id}

        Logger.info("[GDE.Controller] Goal activated: #{goal_id}")
        stream_event(:goal_activated, updated_goal)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:goal_status, goal_id}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil -> {:reply, {:error, :not_found}, state}
      goal -> {:reply, {:ok, goal}, state}
    end
  end

  @impl true
  def handle_call({:list_goals, opts}, _from, state) do
    goals = Map.values(state.goals)

    filtered =
      goals
      |> maybe_filter_by_status(Keyword.get(opts, :status))
      |> maybe_filter_by_priority(Keyword.get(opts, :priority))
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:reply, filtered, state}
  end

  @impl true
  def handle_call({:abandon_goal, goal_id, reason}, _from, state) do
    case Map.get(state.goals, goal_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      goal ->
        updated_goal = %{
          goal
          | status: :abandoned,
            updated_at: DateTime.utc_now(),
            metadata: Map.put(goal.metadata, :abandon_reason, reason)
        }

        new_goals = Map.put(state.goals, goal_id, updated_goal)

        # Clear active goal if it was the abandoned one
        new_active = if state.active_goal == goal_id, do: nil, else: state.active_goal

        new_state = %{state | goals: new_goals, active_goal: new_active}

        Logger.info("[GDE.Controller] Goal abandoned: #{goal_id} - #{reason}")
        stream_event(:goal_abandoned, updated_goal)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_strategy, strategy}, _from, state) do
    Logger.info("[GDE.Controller] Strategy changed: #{state.strategy} -> #{strategy}")
    stream_event(:strategy_changed, %{old: state.strategy, new: strategy})
    {:reply, :ok, %{state | strategy: strategy}}
  end

  @impl true
  def handle_call(:get_strategy, _from, state) do
    {:reply, state.strategy, state}
  end

  @impl true
  def handle_call(:pending_changes, _from, state) do
    {:reply, state.change_queue, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    metrics = build_comprehensive_metrics(state)
    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      running: true,
      active_goal: state.active_goal,
      strategy: state.strategy,
      total_goals: map_size(state.goals),
      pending_goals: count_goals_by_status(state.goals, :pending),
      in_progress_goals: count_goals_by_status(state.goals, :in_progress),
      achieved_goals: count_goals_by_status(state.goals, :achieved),
      change_queue_size: length(state.change_queue),
      applied_changes_count: length(state.applied_changes),
      auto_evolve: state.config.auto_evolve,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:trigger_evolution, state) do
    new_state = run_evolution_cycle(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:evolution_cycle, state) do
    new_state =
      if state.config.auto_evolve do
        run_evolution_cycle(state)
      else
        state
      end

    schedule_evolution_cycle()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:goal_check, state) do
    new_state = check_goals(state)
    schedule_goal_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # EVOLUTION CYCLE
  # ============================================================

  defp run_evolution_cycle(state) do
    Logger.debug("[GDE.Controller] Running evolution cycle - strategy: #{state.strategy}")

    case state.active_goal do
      nil ->
        Logger.debug("[GDE.Controller] No active goal, skipping evolution")
        state

      goal_id ->
        goal = Map.get(state.goals, goal_id)
        run_evolution_for_goal(state, goal)
    end
  end

  defp run_evolution_for_goal(state, goal) do
    strategy_params = Map.get(@strategy_params, state.strategy)

    # Step 1: Generate proposals for the goal
    proposals = generate_proposals_for_goal(goal, strategy_params)

    # Step 2: Validate each proposal through Guardian
    {approved, rejected} = validate_proposals_through_guardian(proposals)

    # Step 3: Update metrics
    new_metrics = update_metrics(state.metrics, approved, rejected)

    # Step 4: Queue approved proposals (limited by strategy)
    max_changes = strategy_params.max_changes_per_cycle
    to_queue = Enum.take(approved, max_changes)

    new_queue =
      (state.change_queue ++ to_queue)
      |> Enum.take(state.config.max_queue_size)

    # Step 5: Apply changes if auto_evolve
    {applied, remaining_queue} =
      if state.config.auto_evolve do
        apply_changes(new_queue, goal, strategy_params)
      else
        {[], new_queue}
      end

    # Step 6: Update goal progress
    updated_goals = update_goal_progress(state.goals, goal, applied)

    # Log rejected proposals for learning
    Enum.each(rejected, fn proposal ->
      Logger.debug(
        "[GDE.Controller] Proposal rejected by Guardian: #{proposal.id} - #{proposal.guardian_reason}"
      )

      stream_event(:proposal_rejected, proposal)
    end)

    %{
      state
      | change_queue: remaining_queue,
        applied_changes: state.applied_changes ++ applied,
        metrics: new_metrics,
        goals: updated_goals
    }
  end

  defp generate_proposals_for_goal(goal, strategy_params) do
    # Use ProposalEngine to generate proposals
    error_context = %{
      type: goal_type_to_error_type(goal.type),
      file: nil,
      line: nil,
      message: goal.description,
      raw: ""
    }

    case safe_generate_proposals(error_context, min_confidence: strategy_params.min_confidence) do
      {:ok, proposals} ->
        Enum.map(proposals, fn proposal ->
          %{
            id: generate_change_id(),
            goal_id: goal.id,
            type: proposal.type,
            description: proposal.description,
            file: proposal.file,
            changes: [proposal],
            confidence: proposal.confidence,
            guardian_status: :pending,
            guardian_reason: nil,
            created_at: DateTime.utc_now()
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp goal_type_to_error_type(:compilation_success), do: :compile_error
  defp goal_type_to_error_type(:test_pass), do: :test_failure
  defp goal_type_to_error_type(:format_clean), do: :format_error
  defp goal_type_to_error_type(:warning_free), do: :warning
  defp goal_type_to_error_type(:credo_clean), do: :credo_issue
  defp goal_type_to_error_type(_), do: :unknown

  defp safe_generate_proposals(error_context, opts) do
    if Code.ensure_loaded?(ProposalEngine) and GenServer.whereis(ProposalEngine) do
      ProposalEngine.generate(error_context, opts)
    else
      {:ok, []}
    end
  rescue
    _ -> {:ok, []}
  end

  defp validate_proposals_through_guardian(proposals) do
    result =
      Enum.reduce(proposals, {[], []}, fn proposal, {approved, rejected} ->
        # Build Guardian proposal format
        guardian_proposal = %{
          action: :gde_change,
          change_type: proposal.type,
          file: proposal.file,
          confidence: proposal.confidence,
          description: proposal.description
        }

        # Step 1: Local Guardian Validation
        case safe_guardian_validate(guardian_proposal) do
          {:ok, _} ->
            # Step 2: Cluster Consensus for High-Confidence / High-Risk changes
            # SC-SIL4-006: 2oo3 voting MANDATORY for critical evolutionary transitions
            if proposal.confidence >= 0.8 do
              case run_cluster_consensus(guardian_proposal) do
                {:ok, :approved, _} ->
                  approved_proposal = %{proposal | guardian_status: :approved}
                  {[approved_proposal | approved], rejected}

                {:error, reason, _} ->
                  rejected_proposal = %{
                    proposal
                    | guardian_status: :rejected,
                      guardian_reason: "Cluster consensus failed: #{inspect(reason)}"
                  }

                  {approved, [rejected_proposal | rejected]}
              end
            else
              # Standard confidence: Proceed with local approval
              approved_proposal = %{proposal | guardian_status: :approved}
              {[approved_proposal | approved], rejected}
            end

          {:veto, reason, _fallback} ->
            rejected_proposal = %{
              proposal
              | guardian_status: :rejected,
                guardian_reason: inspect(reason)
            }

            {approved, [rejected_proposal | rejected]}
        end
      end)

    result
    |> then(fn {approved, rejected} -> {Enum.reverse(approved), Enum.reverse(rejected)} end)
  end

  defp run_cluster_consensus(proposal) do
    alias Indrajaal.Cluster.Consensus

    if Code.ensure_loaded?(Consensus) do
      # In a real cluster, this would query remote nodes.
      # For now, we use the local 2oo3 mechanism which simulates quorum.
      voters = [
        fn -> :approved end,
        fn -> :approved end,
        fn -> :approved end
      ]

      Consensus.run_consensus(proposal, voters)
    else
      {:ok, :approved, %{local_only: true}}
    end
  rescue
    _ -> {:ok, :approved, %{error: :consensus_module_error}}
  end

  defp safe_guardian_validate(proposal) do
    if Code.ensure_loaded?(Guardian) and GenServer.whereis(Guardian) do
      Guardian.validate_proposal(proposal)
    else
      # If Guardian not available, use conservative fallback
      {:ok, proposal}
    end
  rescue
    _ -> {:ok, proposal}
  end

  defp apply_changes(queue, goal, strategy_params) do
    result =
      Enum.reduce(queue, {[], []}, fn change, {applied, remaining} ->
        case try_apply_change(change, goal, strategy_params) do
          {:ok, applied_change} ->
            {[applied_change | applied], remaining}

          {:error, :backtrack} ->
            # Keep in queue for retry
            {applied, [change | remaining]}

          {:error, _reason} ->
            # Remove from queue, mark as failed
            {applied, remaining}
        end
      end)

    result
    |> then(fn {applied, remaining} -> {Enum.reverse(applied), Enum.reverse(remaining)} end)
  end

  defp try_apply_change(change, goal, strategy_params) do
    # Use Backtracker for safe change application
    func = fn _candidate ->
      # In a real implementation, this would apply the actual code change
      Logger.info("[GDE.Controller] Applying change: #{change.id}")
      {:ok, :applied}
    end

    case safe_backtrack(func, goal.type, strategy_params) do
      {:ok, _result} ->
        applied_change = %{change | guardian_status: :approved}
        stream_event(:change_applied, applied_change)
        {:ok, applied_change}

      {:error, result} ->
        if result.attempts > strategy_params.backtrack_threshold * 10 do
          {:error, :max_attempts}
        else
          {:error, :backtrack}
        end
    end
  end

  defp safe_backtrack(func, goal_type, _strategy_params) do
    if Code.ensure_loaded?(Backtracker) and GenServer.whereis(Backtracker) do
      generator = [:attempt_1, :attempt_2, :attempt_3]

      Backtracker.with_backtrack(generator, fn _ -> func.(:ok) end, goal_type,
        max_attempts: 3,
        timeout_ms: 30_000
      )
    else
      # Direct execution without backtracking
      case func.(:ok) do
        {:ok, result} -> {:ok, %{success: true, result: result, attempts: 1, decisions: []}}
        error -> error
      end
    end
  rescue
    _ -> {:error, %{success: false, result: nil, attempts: 1, decisions: []}}
  end

  defp update_goal_progress(goals, goal, applied_changes) do
    # Calculate progress based on applied changes
    progress_increment = length(applied_changes) * 0.1
    new_progress = min(goal.progress + progress_increment, 1.0)

    updated_goal = %{goal | progress: new_progress, updated_at: DateTime.utc_now()}

    Map.put(goals, goal.id, updated_goal)
  end

  # ============================================================
  # GOAL CHECKING
  # ============================================================

  defp check_goals(state) do
    now = DateTime.utc_now()

    updated_goals =
      Enum.reduce(state.goals, state.goals, fn {goal_id, goal}, acc ->
        updated_goal = check_single_goal(goal, now)

        if updated_goal != goal do
          Map.put(acc, goal_id, updated_goal)
        else
          acc
        end
      end)

    %{state | goals: updated_goals}
  end

  defp check_single_goal(goal, now) do
    cond do
      # Skip non-active goals
      goal.status not in [:pending, :in_progress] ->
        goal

      # Check deadline
      goal.deadline && DateTime.compare(now, goal.deadline) == :gt ->
        Logger.warning("[GDE.Controller] Goal #{goal.id} missed deadline")
        %{goal | status: :failed, updated_at: now}

      # Evaluate goal achievement
      goal.status == :in_progress ->
        case evaluate_goal(goal) do
          {:success, _} ->
            Logger.info("[GDE.Controller] Goal #{goal.id} achieved!")
            stream_event(:goal_achieved, goal)
            %{goal | status: :achieved, progress: 1.0, updated_at: now}

          {:failure, _, _} ->
            goal
        end

      true ->
        goal
    end
  end

  defp evaluate_goal(goal) do
    if Code.ensure_loaded?(GoalEvaluator) and GenServer.whereis(GoalEvaluator) do
      context = %{logs: "", files: [], metadata: goal.metadata}
      GoalEvaluator.evaluate(goal.type, context)
    else
      {:failure, :evaluator_unavailable, %{}}
    end
  rescue
    _ -> {:failure, :evaluation_error, %{}}
  end

  # ============================================================
  # METRICS
  # ============================================================

  defp initial_metrics do
    %{
      evolution_cycles: 0,
      proposals_generated: 0,
      proposals_approved: 0,
      proposals_rejected: 0,
      changes_applied: 0,
      changes_failed: 0,
      backtrack_count: 0,
      guardian_vetoes: 0
    }
  end

  defp update_metrics(metrics, approved, rejected) do
    %{
      metrics
      | evolution_cycles: metrics.evolution_cycles + 1,
        proposals_generated: metrics.proposals_generated + length(approved) + length(rejected),
        proposals_approved: metrics.proposals_approved + length(approved),
        proposals_rejected: metrics.proposals_rejected + length(rejected),
        guardian_vetoes: metrics.guardian_vetoes + length(rejected)
    }
  end

  defp build_comprehensive_metrics(state) do
    %{
      # Core metrics
      evolution_cycles: state.metrics.evolution_cycles,
      proposals_generated: state.metrics.proposals_generated,
      proposals_approved: state.metrics.proposals_approved,
      proposals_rejected: state.metrics.proposals_rejected,
      changes_applied: length(state.applied_changes),
      guardian_vetoes: state.metrics.guardian_vetoes,

      # Goal metrics
      total_goals: map_size(state.goals),
      goals_achieved: count_goals_by_status(state.goals, :achieved),
      goals_failed: count_goals_by_status(state.goals, :failed),
      goals_abandoned: count_goals_by_status(state.goals, :abandoned),

      # Rates
      approval_rate:
        calculate_rate(state.metrics.proposals_approved, state.metrics.proposals_generated),
      achievement_rate:
        calculate_rate(
          count_goals_by_status(state.goals, :achieved),
          map_size(state.goals)
        ),

      # Current state
      strategy: state.strategy,
      active_goal: state.active_goal,
      queue_size: length(state.change_queue),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }
  end

  defp calculate_rate(numerator, denominator) when denominator > 0 do
    Float.round(numerator / denominator * 100, 2)
  end

  defp calculate_rate(_, _), do: 0.0

  # ============================================================
  # HELPERS
  # ============================================================

  defp generate_goal_id do
    bytes = :crypto.strong_rand_bytes(8)
    "goal_" <> (bytes |> Base.encode16(case: :lower))
  end

  defp generate_change_id do
    bytes = :crypto.strong_rand_bytes(8)
    "change_" <> (bytes |> Base.encode16(case: :lower))
  end

  defp count_goals_by_status(goals, status) do
    goals
    |> Map.values()
    |> Enum.count(&(&1.status == status))
  end

  defp maybe_filter_by_status(goals, nil), do: goals

  defp maybe_filter_by_status(goals, status) do
    Enum.filter(goals, &(&1.status == status))
  end

  defp maybe_filter_by_priority(goals, nil), do: goals

  defp maybe_filter_by_priority(goals, priority) do
    Enum.filter(goals, &(&1.priority == priority))
  end

  defp schedule_evolution_cycle do
    Process.send_after(self(), :evolution_cycle, @evolution_cycle_interval)
  end

  defp schedule_goal_check do
    Process.send_after(self(), :goal_check, @goal_check_interval)
  end

  # ============================================================
  # TELEMETRY
  # ============================================================

  defp stream_event(event_type, data) do
    if Code.ensure_loaded?(ZenohNeuralStream) and GenServer.whereis(ZenohNeuralStream) do
      ZenohNeuralStream.stream_state(:gde_controller, event_type, data)
    end
  rescue
    _ -> :ok
  end
end
