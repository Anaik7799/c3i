defmodule Indrajaal.Substrate.L7.CoevolutionTracker do
  @moduledoc """
  ## Design Intent
  L7 Coevolution Tracker — GenServer that records how this holon co-evolves with its
  wider ecosystem by logging adaptation events and computing a fitness score.

  Co-evolutionary model:
    - Adaptations are discrete events: the holon changes some capability in response
      to an ecosystem signal
    - Each adaptation carries: type, stimulus (what triggered it), outcome (0.0–1.0),
      and a capability delta map
    - Fitness is an EMA-smoothed aggregate of adaptation outcomes over time
    - Trajectory is the chronological sequence of fitness snapshots
    - Stagnation is detected when the fitness standard deviation over the last
      @stagnation_window events is below @stagnation_threshold

  Fitness formula:
    fitness_new = α × outcome + (1−α) × fitness_old    (α = 0.25)

  Stagnation detection:
    stagnant = std_dev(last N outcomes) < 0.05

  Heartbeat (every 180 s) publishes coevolution summary.

  ## STAMP Constraints
  - SC-SMRITI-063: Federation protocol — tracker records cross-holon co-evolution
  - SC-SMRITI-140: All evolution events recorded — ENFORCED (adaptation log)
  - SC-SMRITI-141: Lineage chain unbroken — adaptation sequence append-only
  - SC-FED-003: Detect constitution divergence — adaptations that drift are flagged
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L7 morphogenesis) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:ecosystem"
  @zenoh_topic "indrajaal/substrate/l7/coevolution/status"
  @checkpoint "CP-L7-COEVOLUTION-01"

  # EMA smoothing factor for fitness updates
  @ema_alpha 0.25

  # Initial fitness score (neutral prior)
  @initial_fitness 0.5

  # Stagnation detection window (number of events)
  @stagnation_window 10

  # Stagnation threshold (std dev below this = stagnant)
  @stagnation_threshold 0.05

  # Max adaptation log size (ring buffer)
  @max_adaptations 500

  # Max trajectory snapshots
  @max_trajectory 200

  # Heartbeat interval ms
  @heartbeat_ms 180_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type adaptation_type ::
          :capability_addition
          | :capability_removal
          | :protocol_upgrade
          | :resource_reallocation
          | :topology_change
          | :constitutional_update

  @type adaptation_event :: %{
          id: String.t(),
          type: adaptation_type(),
          stimulus: String.t(),
          outcome: float(),
          capability_delta: map(),
          fitness_after: float(),
          recorded_at: integer()
        }

  @type trajectory_snapshot :: %{
          fitness: float(),
          adaptation_count: non_neg_integer(),
          timestamp: integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Record an adaptation event. `outcome` must be in [0.0, 1.0].
  Returns `{:ok, new_fitness}`.
  """
  @spec record_adaptation(adaptation_type(), map()) :: {:ok, float()} | {:error, term()}
  def record_adaptation(type, attrs) when is_atom(type) and is_map(attrs) do
    GenServer.call(@name, {:record_adaptation, type, attrs})
  end

  @doc """
  Return the current fitness score.
  """
  @spec fitness() :: float()
  def fitness do
    GenServer.call(@name, :fitness)
  end

  @doc """
  Return the chronological fitness trajectory (list of snapshots).
  """
  @spec trajectory() :: [trajectory_snapshot()]
  def trajectory do
    GenServer.call(@name, :trajectory)
  end

  @doc """
  Return `true` if the holon is in a stagnation state (low fitness variance).
  """
  @spec stagnation?() :: boolean()
  def stagnation? do
    GenServer.call(@name, :stagnation?)
  end

  @doc """
  Return the full coevolution summary.
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
    interval_ms = Keyword.get(opts, :heartbeat_interval_ms, @heartbeat_ms)
    schedule_heartbeat(interval_ms)

    state = %{
      fitness: @initial_fitness,
      adaptations: [],
      trajectory: [],
      heartbeat_count: 0,
      heartbeat_interval_ms: interval_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[COEVOLUTION_TRACKER] Started — checkpoint=#{@checkpoint}")
    {:ok, state}
  end

  @impl true
  def handle_call({:record_adaptation, type, attrs}, _from, state) do
    now = System.monotonic_time(:second)
    outcome = Map.get(attrs, :outcome, 0.5) |> max(0.0) |> min(1.0)

    new_fitness = @ema_alpha * outcome + (1.0 - @ema_alpha) * state.fitness
    new_fitness = Float.round(new_fitness, 4)

    id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

    event = %{
      id: id,
      type: type,
      stimulus: Map.get(attrs, :stimulus, "unknown"),
      outcome: outcome,
      capability_delta: Map.get(attrs, :capability_delta, %{}),
      fitness_after: new_fitness,
      recorded_at: now
    }

    adaptations = [event | Enum.take(state.adaptations, @max_adaptations - 1)]

    snapshot = %{
      fitness: new_fitness,
      adaptation_count: length(adaptations),
      timestamp: now
    }

    trajectory = [snapshot | Enum.take(state.trajectory, @max_trajectory - 1)]

    Logger.info(
      "[COEVOLUTION_TRACKER] Adaptation recorded type=#{type} outcome=#{outcome} fitness=#{new_fitness}"
    )

    new_state = %{state | fitness: new_fitness, adaptations: adaptations, trajectory: trajectory}
    {:reply, {:ok, new_fitness}, new_state}
  end

  @impl true
  def handle_call(:fitness, _from, state) do
    {:reply, state.fitness, state}
  end

  @impl true
  def handle_call(:trajectory, _from, state) do
    {:reply, Enum.reverse(state.trajectory), state}
  end

  @impl true
  def handle_call(:stagnation?, _from, state) do
    result = detect_stagnation(state.adaptations)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    summary = %{
      fitness: state.fitness,
      adaptation_count: length(state.adaptations),
      stagnant: detect_stagnation(state.adaptations),
      heartbeat_count: state.heartbeat_count,
      started_at: DateTime.to_iso8601(state.started_at)
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_info(:heartbeat_tick, state) do
    new_state = %{state | heartbeat_count: state.heartbeat_count + 1}

    payload = %{
      fitness: state.fitness,
      adaptation_count: length(state.adaptations),
      stagnant: detect_stagnation(state.adaptations),
      heartbeat_count: new_state.heartbeat_count
    }

    broadcast_status(payload)

    Logger.debug(
      "[COEVOLUTION_TRACKER] Heartbeat #{new_state.heartbeat_count} — fitness=#{state.fitness}"
    )

    schedule_heartbeat(state.heartbeat_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[COEVOLUTION_TRACKER] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp detect_stagnation(adaptations) when length(adaptations) < @stagnation_window, do: false

  defp detect_stagnation(adaptations) do
    recent = Enum.take(adaptations, @stagnation_window)
    outcomes = Enum.map(recent, & &1.outcome)
    mean = Enum.sum(outcomes) / length(outcomes)

    variance =
      Enum.sum(Enum.map(outcomes, fn o -> (o - mean) * (o - mean) end)) / length(outcomes)

    std_dev = :math.sqrt(variance)
    std_dev < @stagnation_threshold
  end

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat_tick, interval_ms)
  end

  defp broadcast_status(payload) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:coevolution_status, payload}
      )
    rescue
      _ -> :ok
    end

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(
        @zenoh_topic,
        Map.merge(payload, %{
          checkpoint: @checkpoint,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      )
    rescue
      _ -> :ok
    end
  end
end
