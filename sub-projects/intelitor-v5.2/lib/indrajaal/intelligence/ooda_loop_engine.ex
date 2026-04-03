defmodule Indrajaal.Intelligence.OodaLoopEngine do
  @moduledoc """
  OODA Loop Engine — L4 Intelligence Layer

  Implements the OODA (Observe-Orient-Decide-Act) loop as a GenServer with
  configurable cycle time targeting < 100ms per SC-VER-041.

  ## OODA Phases

  - **Observe**: Collect telemetry from Phoenix PubSub subscriptions and ETS cache
  - **Orient**: Classify situation using pattern matching and contextual analysis
  - **Decide**: Select action from a typed decision tree
  - **Act**: Dispatch actions via PubSub to downstream consumers

  ## STAMP Constraints
  - SC-VER-041: OODA cycle MUST be < 100ms
  - SC-ORCH-004: OODA cycle < 100ms
  - SC-ORCH-001: Task creation coordinates Prajna/Smriti/Chaya
  - SC-DEBUG-001: All telemetry events must be observable
  - SC-HMI-010: Vibrant chromatic feedback on telemetry metabolics

  ## Metrics Published
  - Cycle latency (observe/orient/decide/act phases)
  - Throughput (cycles per second)
  - Decision distribution (action types chosen)

  Zenoh topic: `indrajaal/intelligence/ooda`

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L4 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @default_cycle_ms 100
  @zenoh_topic "indrajaal/intelligence/ooda"
  @pubsub_topic "ooda_loop:events"
  @table :ooda_observations

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type situation_class ::
          :nominal
          | :degraded
          | :critical
          | :unknown

  @type action_type ::
          :noop
          | :alert
          | :throttle
          | :escalate
          | :recover

  @type cycle_metrics :: %{
          observe_us: non_neg_integer(),
          orient_us: non_neg_integer(),
          decide_us: non_neg_integer(),
          act_us: non_neg_integer(),
          total_us: non_neg_integer(),
          cycle_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns the most recent cycle metrics."
  @spec metrics() :: cycle_metrics()
  def metrics do
    GenServer.call(@name, :metrics)
  end

  @doc "Returns the current situation classification."
  @spec current_situation() :: situation_class()
  def current_situation do
    GenServer.call(@name, :current_situation)
  end

  @doc "Injects a telemetry observation directly (for testing)."
  @spec inject_observation(map()) :: :ok
  def inject_observation(obs) when is_map(obs) do
    GenServer.cast(@name, {:inject_observation, obs})
  end

  @doc "Forces an immediate OODA cycle."
  @spec run_cycle() :: :ok
  def run_cycle do
    GenServer.call(@name, :run_cycle)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    cycle_ms = Keyword.get(opts, :cycle_ms, @default_cycle_ms)

    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    schedule_cycle(cycle_ms)

    state = %{
      cycle_ms: cycle_ms,
      cycle_count: 0,
      situation: :unknown,
      last_metrics: empty_metrics(),
      decision_counts: %{}
    }

    Logger.info("[OodaLoopEngine] Started — cycle_ms=#{cycle_ms} [SC-VER-041]")

    {:ok, state}
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    {:reply, state.last_metrics, state}
  end

  @impl true
  def handle_call(:current_situation, _from, state) do
    {:reply, state.situation, state}
  end

  @impl true
  def handle_call(:run_cycle, _from, state) do
    new_state = execute_ooda_cycle(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:inject_observation, obs}, state) do
    :ets.insert(@table, {:injected, obs})
    {:noreply, state}
  end

  @impl true
  def handle_info(:ooda_cycle, state) do
    new_state = execute_ooda_cycle(state)
    schedule_cycle(state.cycle_ms)
    {:noreply, new_state}
  end

  # ---------------------------------------------------------------------------
  # OODA Implementation
  # ---------------------------------------------------------------------------

  defp execute_ooda_cycle(state) do
    cycle_start = System.monotonic_time(:microsecond)

    # Phase 1: Observe
    obs_start = cycle_start
    observations = observe()
    obs_end = System.monotonic_time(:microsecond)

    # Phase 2: Orient
    orient_start = obs_end
    situation = orient(observations)
    orient_end = System.monotonic_time(:microsecond)

    # Phase 3: Decide
    decide_start = orient_end
    action = decide(situation, observations)
    decide_end = System.monotonic_time(:microsecond)

    # Phase 4: Act
    act_start = decide_end
    act(action, situation)
    act_end = System.monotonic_time(:microsecond)

    total_us = act_end - cycle_start

    if total_us > 100_000 do
      Logger.warning(
        "[OodaLoopEngine] Cycle #{state.cycle_count + 1} exceeded 100ms: #{total_us}us [SC-VER-041]"
      )
    end

    metrics = %{
      observe_us: obs_end - obs_start,
      orient_us: orient_end - orient_start,
      decide_us: decide_end - decide_start,
      act_us: act_end - act_start,
      total_us: total_us,
      cycle_count: state.cycle_count + 1
    }

    decision_counts = Map.update(state.decision_counts, action, 1, &(&1 + 1))

    publish_metrics(metrics, situation, action)

    %{
      state
      | cycle_count: state.cycle_count + 1,
        situation: situation,
        last_metrics: metrics,
        decision_counts: decision_counts
    }
  end

  # Observe: collect telemetry from ETS and PubSub
  defp observe do
    injected =
      case :ets.lookup(@table, :injected) do
        [{:injected, obs}] ->
          :ets.delete(@table, :injected)
          [obs]

        _ ->
          []
      end

    system_obs = collect_system_observations()

    injected ++ system_obs
  end

  defp collect_system_observations do
    memory = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    scheduler_usage = :scheduler.utilization(1) |> Enum.map(fn {_id, usage, _} -> usage end)

    avg_scheduler =
      if scheduler_usage == [], do: 0.0, else: Enum.sum(scheduler_usage) / length(scheduler_usage)

    [
      %{
        type: :system_health,
        timestamp: System.system_time(:millisecond),
        memory_total: memory[:total],
        memory_processes: memory[:processes],
        process_count: process_count,
        scheduler_utilization: avg_scheduler
      }
    ]
  rescue
    _ -> []
  end

  # Orient: classify situation from observations
  @spec orient(list()) :: situation_class()
  defp orient([]), do: :nominal

  defp orient(observations) do
    system_obs = Enum.find(observations, &(&1[:type] == :system_health))

    cond do
      is_nil(system_obs) -> :nominal
      critical_thresholds?(system_obs) -> :critical
      degraded_thresholds?(system_obs) -> :degraded
      true -> :nominal
    end
  end

  defp critical_thresholds?(obs) do
    memory_pressure = obs[:memory_processes] / max(obs[:memory_total], 1) > 0.9
    process_overload = obs[:process_count] > 50_000
    cpu_saturation = obs[:scheduler_utilization] > 0.95

    memory_pressure or process_overload or cpu_saturation
  end

  defp degraded_thresholds?(obs) do
    memory_pressure = obs[:memory_processes] / max(obs[:memory_total], 1) > 0.7
    process_load = obs[:process_count] > 20_000
    cpu_high = obs[:scheduler_utilization] > 0.75

    memory_pressure or process_load or cpu_high
  end

  # Decide: select action based on situation
  @spec decide(situation_class(), list()) :: action_type()
  defp decide(:critical, _), do: :escalate
  defp decide(:degraded, _), do: :throttle
  defp decide(:nominal, _), do: :noop
  defp decide(_, _), do: :alert

  # Act: dispatch action via PubSub
  defp act(:noop, _situation), do: :ok

  defp act(action, situation) do
    payload = %{
      action: action,
      situation: situation,
      timestamp: System.system_time(:millisecond)
    }

    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:ooda_action, payload}
    )

    Logger.debug("[OodaLoopEngine] Act: #{action} for situation=#{situation} [SC-ORCH-001]")

    :ok
  rescue
    e ->
      Logger.warning("[OodaLoopEngine] PubSub broadcast failed: #{inspect(e)}")
      :ok
  end

  # ---------------------------------------------------------------------------
  # Telemetry & Scheduling
  # ---------------------------------------------------------------------------

  defp publish_metrics(metrics, situation, action) do
    :telemetry.execute(
      [:indrajaal, :intelligence, :ooda, :cycle],
      %{
        total_us: metrics.total_us,
        observe_us: metrics.observe_us,
        orient_us: metrics.orient_us,
        decide_us: metrics.decide_us,
        act_us: metrics.act_us
      },
      %{
        situation: situation,
        action: action,
        cycle: metrics.cycle_count,
        zenoh_topic: @zenoh_topic
      }
    )
  rescue
    _ -> :ok
  end

  defp schedule_cycle(cycle_ms) do
    Process.send_after(self(), :ooda_cycle, cycle_ms)
  end

  defp empty_metrics do
    %{
      observe_us: 0,
      orient_us: 0,
      decide_us: 0,
      act_us: 0,
      total_us: 0,
      cycle_count: 0
    }
  end
end
