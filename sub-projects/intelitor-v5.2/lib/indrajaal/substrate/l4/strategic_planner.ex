defmodule Indrajaal.Substrate.L4.StrategicPlanner do
  @moduledoc """
  ## Design Intent
  L4 GenServer managing strategic objectives for the Indrajaal VSM fractal mesh.
  Maintains a goals list with progress tracking and deadline enforcement. Executes
  an OODA-style plan→execute→review cycle via periodic handle_info(:review) ticks.

  Goal lifecycle:
    1. Operator calls `add_goal/3` with name, target_progress (0–100), deadline
    2. Goals stored in ETS keyed by id, progress tracked against deadline
    3. Review cycle (every 30 s) evaluates progress, marks overdue goals, publishes
    4. Caller calls `update_progress/2` to advance a goal toward 100%
    5. Completed goals (progress >= 100) transition to :completed status
    6. Overdue goals (past deadline, progress < 100) transition to :overdue

  OODA cycle mapping:
    Observe  — scan all goals, measure current progress vs baseline
    Orient   — classify each goal as :on_track | :at_risk | :overdue | :completed
    Decide   — identify highest-priority action (most urgent at_risk goal)
    Act      — publish assessment + recommended action to PubSub + Zenoh

  ## STAMP Constraints
  - SC-VER-041: OODA cycle < 100ms — review scan is O(n) over goal list
  - SC-BIO-001: OODA cycle budget respected
  - SC-FUNC-001: System must compile at all times — ENFORCED
  - SC-CPU-GOV-001: CPU utilization limit respected

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 33, L4) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_goals :strategic_planner_goals
  @pubsub_topic "prajna:strategic"
  @zenoh_topic "indrajaal/substrate/l4/strategic/review"
  @checkpoint "CP-L4-STRATEGIC-01"

  # Review interval ms
  @review_ms 30_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type goal_status :: :pending | :active | :at_risk | :completed | :overdue

  @type goal :: %{
          id: String.t(),
          name: String.t(),
          progress: non_neg_integer(),
          target_progress: non_neg_integer(),
          deadline: DateTime.t(),
          status: goal_status(),
          created_at: integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Add a strategic goal.

  - `name`            — human-readable goal description
  - `target_progress` — integer 1–100 representing 100% completion
  - `deadline`        — `DateTime.t()` deadline for goal completion
  """
  @spec add_goal(String.t(), non_neg_integer(), DateTime.t()) ::
          {:ok, String.t()} | {:error, term()}
  def add_goal(name, target_progress, deadline)
      when is_binary(name) and is_integer(target_progress) and target_progress in 1..100 do
    GenServer.call(@name, {:add_goal, name, target_progress, deadline})
  end

  @doc """
  Update progress on an existing goal (0–100).
  """
  @spec update_progress(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def update_progress(goal_id, progress)
      when is_binary(goal_id) and is_integer(progress) and progress in 0..100 do
    GenServer.call(@name, {:update_progress, goal_id, progress})
  end

  @doc """
  Return all current goals.
  """
  @spec list_goals() :: [goal()]
  def list_goals do
    GenServer.call(@name, :list_goals)
  end

  @doc """
  Return planner state summary.
  """
  @spec summary() :: map()
  def summary do
    GenServer.call(@name, :summary)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_goals, [:set, :public, :named_table, read_concurrency: true])

    schedule_review()

    state = %{
      review_count: 0,
      goals_added: 0,
      goals_completed: 0,
      review_interval_ms: Keyword.get(opts, :review_interval_ms, @review_ms),
      started_at: DateTime.utc_now()
    }

    Logger.warning("[STRATEGIC_PLANNER] Started — checkpoint=#{@checkpoint}")

    {:ok, state}
  end

  @impl true
  def handle_call({:add_goal, name, target_progress, deadline}, _from, state) do
    id = generate_id()

    goal = %{
      id: id,
      name: name,
      progress: 0,
      target_progress: target_progress,
      deadline: deadline,
      status: :active,
      created_at: System.monotonic_time(:millisecond)
    }

    :ets.insert(@ets_goals, {id, goal})
    new_state = %{state | goals_added: state.goals_added + 1}

    Logger.debug(
      "[STRATEGIC_PLANNER] Goal added id=#{id} name=#{name} " <>
        "target=#{target_progress} deadline=#{DateTime.to_iso8601(deadline)}"
    )

    {:reply, {:ok, id}, new_state}
  end

  @impl true
  def handle_call({:update_progress, goal_id, progress}, _from, state) do
    case :ets.lookup(@ets_goals, goal_id) do
      [{^goal_id, goal}] ->
        new_status =
          cond do
            progress >= goal.target_progress -> :completed
            DateTime.compare(DateTime.utc_now(), goal.deadline) == :gt -> :overdue
            progress >= goal.target_progress * 0.7 -> :active
            true -> :at_risk
          end

        updated_goal = %{goal | progress: progress, status: new_status}
        :ets.insert(@ets_goals, {goal_id, updated_goal})

        new_state =
          if new_status == :completed do
            %{state | goals_completed: state.goals_completed + 1}
          else
            state
          end

        broadcast_goal_update(updated_goal)

        Logger.debug(
          "[STRATEGIC_PLANNER] Progress updated id=#{goal_id} " <>
            "progress=#{progress} status=#{new_status}"
        )

        {:reply, :ok, new_state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_goals, _from, state) do
    goals =
      :ets.tab2list(@ets_goals)
      |> Enum.map(fn {_id, g} -> g end)
      |> Enum.sort_by(& &1.created_at)

    {:reply, goals, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    goals = :ets.tab2list(@ets_goals) |> Enum.map(fn {_id, g} -> g end)
    total = length(goals)
    completed = Enum.count(goals, &(&1.status == :completed))
    at_risk = Enum.count(goals, &(&1.status == :at_risk))
    overdue = Enum.count(goals, &(&1.status == :overdue))

    avg_progress =
      if total > 0 do
        Enum.sum(Enum.map(goals, & &1.progress)) / total
      else
        0.0
      end

    summary = %{
      total_goals: total,
      completed: completed,
      at_risk: at_risk,
      overdue: overdue,
      average_progress: Float.round(avg_progress, 1),
      review_count: state.review_count,
      started_at: state.started_at
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_info(:review, state) do
    # OODA: Observe → Orient → Decide → Act
    goals = :ets.tab2list(@ets_goals) |> Enum.map(fn {_id, g} -> g end)
    now = DateTime.utc_now()

    # Orient — reclassify each goal
    updated_goals =
      Enum.map(goals, fn goal ->
        new_status =
          cond do
            goal.status == :completed -> :completed
            goal.progress >= goal.target_progress -> :completed
            DateTime.compare(now, goal.deadline) == :gt -> :overdue
            deadline_hours_remaining(goal.deadline, now) < 2 -> :at_risk
            true -> goal.status
          end

        if new_status != goal.status do
          updated = %{goal | status: new_status}
          :ets.insert(@ets_goals, {goal.id, updated})
          updated
        else
          goal
        end
      end)

    # Decide — find most urgent at_risk goal
    most_urgent =
      updated_goals
      |> Enum.filter(&(&1.status == :at_risk))
      |> Enum.min_by(&deadline_hours_remaining(&1.deadline, now), fn -> nil end)

    new_state = %{state | review_count: state.review_count + 1}

    # Act — publish assessment
    broadcast_review(updated_goals, most_urgent, new_state.review_count)
    emit_telemetry(length(updated_goals), new_state.review_count)

    Logger.debug(
      "[STRATEGIC_PLANNER] Review #{new_state.review_count} complete — " <>
        "goals=#{length(updated_goals)} urgent=#{inspect(most_urgent && most_urgent.id)}"
    )

    schedule_review()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[STRATEGIC_PLANNER] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp deadline_hours_remaining(deadline, now) do
    DateTime.diff(deadline, now, :second) / 3600.0
  end

  defp schedule_review do
    Process.send_after(self(), :review, @review_ms)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp broadcast_review(goals, most_urgent, review_count) do
    payload = %{
      event: :strategic_review,
      goals_count: length(goals),
      completed: Enum.count(goals, &(&1.status == :completed)),
      at_risk: Enum.count(goals, &(&1.status == :at_risk)),
      overdue: Enum.count(goals, &(&1.status == :overdue)),
      most_urgent_id: most_urgent && most_urgent.id,
      review_count: review_count
    }

    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:review_complete, payload})
    rescue
      _ -> :ok
    end

    publish_zenoh(payload)
  end

  defp broadcast_goal_update(goal) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:goal_updated, goal.id, goal.status, goal.progress}
      )
    rescue
      _ -> :ok
    end
  end

  defp publish_zenoh(payload) do
    data =
      Map.merge(payload, %{
        checkpoint: @checkpoint,
        topic: @zenoh_topic,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(goals_count, review_count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l4, :strategic_planner, :review],
        %{goals_count: goals_count, review_count: review_count},
        %{checkpoint: @checkpoint, constraint: "SC-VER-041"}
      )
    rescue
      _ -> :ok
    end
  end
end
