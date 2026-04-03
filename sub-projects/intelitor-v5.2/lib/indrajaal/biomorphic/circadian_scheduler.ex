defmodule Indrajaal.Biomorphic.CircadianScheduler do
  @moduledoc """
  ## Design Intent
  Time-of-day-aware scheduling subsystem for the Indrajaal biomorphic mesh.
  Adjusts system behavior based on load patterns by tracking the current
  circadian phase and notifying registered schedules when the phase changes.

  Circadian phases and their load semantics:
    :peak        — Business hours, maximum resource allocation (08:00–18:00)
    :normal      — Standard operation, balanced resources (06:00–08:00, 18:00–22:00)
    :maintenance — Light traffic, allow maintenance tasks (22:00–00:00)
    :quiet       — Minimal load, run heavy background jobs (00:00–06:00)

  Schedule lifecycle:
    1. Caller registers a schedule with `register_schedule/3` including phase(s) and callback
    2. Phase evaluator runs every 60 s and recomputes the active phase
    3. On phase transition, all registered schedules for the new phase are triggered
    4. Phase override allows manual forcing for testing or planned events
    5. Schedule history (last 100 transitions) is maintained in ETS

  Phase is computed from wall-clock UTC time adjusted by configurable UTC offset.

  ## STAMP Constraints
  - SC-BIO-002: Circadian rhythm adaptation — ENFORCED
  - SC-RCPSP-001: Resource-constrained scheduling respect — ENFORCED via phase gating
  - SC-CPU-GOV-001: CPU utilization limit respected — phase transitions are O(n) callbacks
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_schedules :circadian_schedules
  @ets_history :circadian_history
  @pubsub_topic "biomorphic:circadian"
  @zenoh_topic "indrajaal/biomorphic/circadian/phase"
  @checkpoint "CP-BIO-CIRCADIAN-01"

  # Phase evaluation interval (ms)
  @tick_ms 60_000

  # Maximum history entries to retain
  @max_history 100

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type phase :: :peak | :normal | :maintenance | :quiet

  @type schedule :: %{
          id: String.t(),
          phases: [phase()],
          description: String.t(),
          handler: (phase() -> :ok),
          registered_at: integer()
        }

  @type history_entry :: %{
          from_phase: phase(),
          to_phase: phase(),
          transitioned_at: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Register a schedule that triggers on specified phases.

  - `id`          — unique schedule identifier
  - `phases`      — list of phases that trigger the handler
  - `opts`        — keyword: description (string), handler (fn/1)
  """
  @spec register_schedule(String.t(), [phase()], keyword()) :: :ok | {:error, term()}
  def register_schedule(id, phases, opts \\ [])
      when is_binary(id) and is_list(phases) do
    valid_phases = [:peak, :normal, :maintenance, :quiet]

    if Enum.all?(phases, &(&1 in valid_phases)) do
      GenServer.call(@name, {:register_schedule, id, phases, opts})
    else
      {:error, :invalid_phase}
    end
  end

  @doc """
  Returns the current circadian phase.
  """
  @spec current_phase() :: phase()
  def current_phase do
    case :ets.lookup(@ets_schedules, :__current_phase__) do
      [{:__current_phase__, phase}] -> phase
      [] -> :normal
    end
  end

  @doc """
  Override the current phase manually (for testing or planned events).
  Pass `nil` to clear the override and resume automatic phase detection.
  """
  @spec override_phase(phase() | nil) :: :ok
  def override_phase(phase)
      when phase in [:peak, :normal, :maintenance, :quiet] or is_nil(phase) do
    GenServer.call(@name, {:override_phase, phase})
  end

  @doc """
  Returns recent phase transition history (up to last 100 entries), newest first.
  """
  @spec schedule_history() :: [history_entry()]
  def schedule_history do
    GenServer.call(@name, :schedule_history)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_schedules, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_history, [:ordered_set, :public, :named_table, read_concurrency: true])

    utc_offset_h = Keyword.get(opts, :utc_offset_h, 0)
    initial_phase = compute_phase(utc_offset_h)

    :ets.insert(@ets_schedules, {:__current_phase__, initial_phase})

    schedule_tick()

    state = %{
      utc_offset_h: utc_offset_h,
      current_phase: initial_phase,
      phase_override: nil,
      transition_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning(
      "[CIRCADIAN] CircadianScheduler started — initial_phase=#{initial_phase} " <>
        "utc_offset=#{utc_offset_h}h checkpoint=#{@checkpoint}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:register_schedule, id, phases, opts}, _from, state) do
    description = Keyword.get(opts, :description, "")
    handler = Keyword.get(opts, :handler, fn _phase -> :ok end)

    schedule = %{
      id: id,
      phases: phases,
      description: description,
      handler: handler,
      registered_at: System.monotonic_time(:millisecond)
    }

    :ets.insert(@ets_schedules, {id, schedule})

    Logger.debug("[CIRCADIAN] Schedule registered id=#{id} phases=#{inspect(phases)}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:override_phase, phase}, _from, state) do
    new_state = %{state | phase_override: phase}

    if not is_nil(phase) do
      new_state2 = transition_to(phase, new_state)
      Logger.warning("[CIRCADIAN] Phase override applied: #{phase}")
      {:reply, :ok, new_state2}
    else
      Logger.info("[CIRCADIAN] Phase override cleared — resuming automatic detection")
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:schedule_history, _from, state) do
    history =
      :ets.tab2list(@ets_history)
      |> Enum.sort_by(fn {key, _} -> key end, :desc)
      |> Enum.take(@max_history)
      |> Enum.map(fn {_key, entry} -> entry end)

    {:reply, history, state}
  end

  @impl true
  def handle_info(:phase_tick, state) do
    new_state =
      if not is_nil(state.phase_override) do
        state
      else
        desired_phase = compute_phase(state.utc_offset_h)

        if desired_phase != state.current_phase do
          transition_to(desired_phase, state)
        else
          state
        end
      end

    schedule_tick()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[CIRCADIAN] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — phase computation and transitions
  # ---------------------------------------------------------------------------

  defp compute_phase(utc_offset_h) do
    now = DateTime.utc_now()
    local_hour = rem(now.hour + utc_offset_h + 24, 24)

    cond do
      local_hour >= 8 and local_hour < 18 -> :peak
      (local_hour >= 6 and local_hour < 8) or (local_hour >= 18 and local_hour < 22) -> :normal
      local_hour >= 22 -> :maintenance
      true -> :quiet
    end
  end

  defp transition_to(new_phase, state) do
    old_phase = state.current_phase
    :ets.insert(@ets_schedules, {:__current_phase__, new_phase})

    record_transition(old_phase, new_phase, state.transition_count)
    trigger_schedules(new_phase)
    broadcast_transition(old_phase, new_phase)
    emit_telemetry(old_phase, new_phase)

    Logger.info(
      "[CIRCADIAN] Phase transition #{old_phase} -> #{new_phase} " <>
        "[ZTEST-CHECKPOINT] checkpoint=#{@checkpoint} timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    )

    %{state | current_phase: new_phase, transition_count: state.transition_count + 1}
  end

  defp trigger_schedules(phase) do
    :ets.tab2list(@ets_schedules)
    |> Enum.filter(fn
      {:__current_phase__, _} -> false
      {_id, sched} when is_map(sched) -> phase in sched.phases
      _ -> false
    end)
    |> Enum.each(fn {id, sched} ->
      try do
        sched.handler.(phase)
      rescue
        e ->
          Logger.warning("[CIRCADIAN] Schedule handler failed id=#{id} error=#{inspect(e)}")
      end
    end)
  end

  defp record_transition(from_phase, to_phase, count) do
    key = System.monotonic_time(:nanosecond)

    entry = %{
      from_phase: from_phase,
      to_phase: to_phase,
      transitioned_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ets.insert(@ets_history, {key, entry})

    # Prune oldest if over limit
    if count + 1 > @max_history do
      case :ets.first(@ets_history) do
        :"$end_of_table" -> :ok
        oldest_key -> :ets.delete(@ets_history, oldest_key)
      end
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :phase_tick, @tick_ms)
  end

  defp broadcast_transition(old_phase, new_phase) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:phase_transition, old_phase, new_phase}
      )
    rescue
      _ -> :ok
    end

    publish_zenoh(new_phase)
  end

  defp publish_zenoh(phase) do
    data = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      phase: phase,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(old_phase, new_phase) do
    try do
      :telemetry.execute(
        [:indrajaal, :biomorphic, :circadian, :transition],
        %{from: old_phase, to: new_phase},
        %{constraint: "SC-BIO-002"}
      )
    rescue
      _ -> :ok
    end
  end
end
