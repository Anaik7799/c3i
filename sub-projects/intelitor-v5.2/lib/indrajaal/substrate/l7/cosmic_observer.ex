defmodule Indrajaal.Substrate.L7.CosmicObserver do
  @moduledoc """
  ## Design Intent
  L7 GenServer tracking system-of-systems metrics for the Indrajaal VSM fractal mesh.
  Monitors federation health across all registered holons, computes ecosystem-level KPIs,
  and publishes composite situational awareness data to "prajna:cosmos".

  Ecosystem KPIs computed:
    - ecosystem_health_score  — weighted average of per-holon health scores (0.0–1.0)
    - federation_coherence    — % of holons in quorum agreement (0.0–1.0)
    - total_active_holons     — count of holons with last_seen < 5 minutes
    - total_registered_holons — total count in registry
    - threat_level            — :green | :yellow | :orange | :red
    - evolution_velocity      — morphogenic change events per hour (rolling 1h window)
    - mean_trust_score        — average trust score across federation peers

  Threat level derivation:
    :green  — ecosystem_health >= 0.9, no critical violations
    :yellow — ecosystem_health >= 0.7
    :orange — ecosystem_health >= 0.5
    :red    — ecosystem_health < 0.5 or any :blocked constitutional violation

  Observation tick: every 30 s (CLAUDE.md §5 SC-MON-001 30s refresh)

  ## STAMP Constraints
  - SC-MON-001: Metrics refresh every 30s — ENFORCED
  - SC-MON-004: Safety metrics mandatory — threat level published every tick
  - SC-VER-074: Constitutional L0-L7 hold — L7 observer verifies ecosystem integrity
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 78, L7) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_holons :cosmic_observer_holons
  @ets_events :cosmic_observer_events
  @pubsub_topic "prajna:cosmos"
  @zenoh_topic "indrajaal/substrate/l7/cosmos/kpi"
  @checkpoint "CP-L7-COSMIC-OBSERVER-01"

  # Observation tick ms (30 s per SC-MON-001)
  @tick_ms 30_000

  # Holon considered active if last_seen < this many seconds ago
  @active_threshold_s 300

  # Evolution event window (1 hour)
  @evolution_window_s 3600

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type threat_level :: :green | :yellow | :orange | :red

  @type holon_record :: %{
          id: String.t(),
          fqun: String.t(),
          health_score: float(),
          last_seen_at: integer(),
          constitutional_ok: boolean(),
          registered_at: integer()
        }

  @type ecosystem_kpi :: %{
          ecosystem_health_score: float(),
          federation_coherence: float(),
          total_active_holons: non_neg_integer(),
          total_registered_holons: non_neg_integer(),
          threat_level: threat_level(),
          evolution_velocity: float(),
          mean_trust_score: float(),
          observation_count: non_neg_integer(),
          computed_at: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Register a holon for ecosystem-level observation.
  """
  @spec register_holon(String.t(), String.t()) :: :ok
  def register_holon(holon_id, fqun) when is_binary(holon_id) and is_binary(fqun) do
    GenServer.call(@name, {:register_holon, holon_id, fqun})
  end

  @doc """
  Update health score for a registered holon.
  """
  @spec update_health(String.t(), float(), boolean()) :: :ok | {:error, term()}
  def update_health(holon_id, health_score, constitutional_ok \\ true)
      when is_binary(holon_id) and is_float(health_score) do
    GenServer.call(@name, {:update_health, holon_id, health_score, constitutional_ok})
  end

  @doc """
  Record an evolution (morphogenic change) event.
  """
  @spec record_evolution_event(String.t(), atom()) :: :ok
  def record_evolution_event(holon_id, event_type)
      when is_binary(holon_id) and is_atom(event_type) do
    GenServer.cast(@name, {:record_evolution, holon_id, event_type})
  end

  @doc """
  Compute and return current ecosystem KPIs immediately.
  """
  @spec current_kpi() :: ecosystem_kpi()
  def current_kpi do
    GenServer.call(@name, :current_kpi)
  end

  @doc """
  Return the last computed KPI snapshot (non-blocking read from state).
  """
  @spec latest_snapshot() :: ecosystem_kpi() | nil
  def latest_snapshot do
    GenServer.call(@name, :latest_snapshot)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_holons, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_events, [:bag, :public, :named_table, read_concurrency: true])

    tick_ms = Keyword.get(opts, :tick_ms, @tick_ms)
    schedule_tick(tick_ms)

    state = %{
      observation_count: 0,
      latest_kpi: nil,
      tick_ms: tick_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[COSMIC_OBSERVER] Started — checkpoint=#{@checkpoint}")

    {:ok, state}
  end

  @impl true
  def handle_call({:register_holon, holon_id, fqun}, _from, state) do
    record = %{
      id: holon_id,
      fqun: fqun,
      health_score: 1.0,
      last_seen_at: System.monotonic_time(:second),
      constitutional_ok: true,
      registered_at: System.monotonic_time(:second)
    }

    :ets.insert(@ets_holons, {holon_id, record})

    Logger.debug("[COSMIC_OBSERVER] Holon registered id=#{holon_id} fqun=#{fqun}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_health, holon_id, health_score, constitutional_ok}, _from, state) do
    case :ets.lookup(@ets_holons, holon_id) do
      [{^holon_id, record}] ->
        updated = %{
          record
          | health_score: max(0.0, min(1.0, health_score)),
            last_seen_at: System.monotonic_time(:second),
            constitutional_ok: constitutional_ok
        }

        :ets.insert(@ets_holons, {holon_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:current_kpi, _from, state) do
    kpi = compute_kpi(state.observation_count)
    {:reply, kpi, state}
  end

  @impl true
  def handle_call(:latest_snapshot, _from, state) do
    {:reply, state.latest_kpi, state}
  end

  @impl true
  def handle_cast({:record_evolution, holon_id, event_type}, state) do
    now = System.monotonic_time(:second)
    :ets.insert(@ets_events, {now, %{holon_id: holon_id, event_type: event_type, ts: now}})
    {:noreply, state}
  end

  @impl true
  def handle_info(:observation_tick, state) do
    prune_old_events()

    kpi = compute_kpi(state.observation_count + 1)
    new_state = %{state | observation_count: state.observation_count + 1, latest_kpi: kpi}

    broadcast_kpi(kpi)
    emit_telemetry(kpi, new_state.observation_count)

    Logger.debug(
      "[COSMIC_OBSERVER] Observation #{new_state.observation_count} — " <>
        "health=#{kpi.ecosystem_health_score} threat=#{kpi.threat_level} " <>
        "active_holons=#{kpi.total_active_holons}"
    )

    schedule_tick(state.tick_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[COSMIC_OBSERVER] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — KPI computation
  # ---------------------------------------------------------------------------

  defp compute_kpi(observation_count) do
    now = System.monotonic_time(:second)
    holons = :ets.tab2list(@ets_holons) |> Enum.map(fn {_id, h} -> h end)
    total = length(holons)

    active =
      Enum.filter(holons, fn h ->
        now - h.last_seen_at < @active_threshold_s
      end)

    active_count = length(active)

    ecosystem_health =
      if active_count > 0 do
        scores = Enum.map(active, & &1.health_score)
        Float.round(Enum.sum(scores) / active_count, 4)
      else
        if total == 0, do: 1.0, else: 0.0
      end

    constitutional_ok_count = Enum.count(active, & &1.constitutional_ok)

    federation_coherence =
      if active_count > 0 do
        Float.round(constitutional_ok_count / active_count, 4)
      else
        1.0
      end

    has_constitutional_violation = Enum.any?(active, &(not &1.constitutional_ok))

    threat_level = derive_threat_level(ecosystem_health, has_constitutional_violation)

    evolution_velocity = compute_evolution_velocity(now)

    mean_trust = compute_mean_trust(active)

    %{
      ecosystem_health_score: ecosystem_health,
      federation_coherence: federation_coherence,
      total_active_holons: active_count,
      total_registered_holons: total,
      threat_level: threat_level,
      evolution_velocity: evolution_velocity,
      mean_trust_score: mean_trust,
      observation_count: observation_count,
      computed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp derive_threat_level(health, has_constitutional_violation) do
    cond do
      has_constitutional_violation -> :red
      health >= 0.9 -> :green
      health >= 0.7 -> :yellow
      health >= 0.5 -> :orange
      true -> :red
    end
  end

  defp compute_evolution_velocity(now) do
    cutoff = now - @evolution_window_s

    events =
      :ets.tab2list(@ets_events)
      |> Enum.filter(fn {ts, _} -> ts >= cutoff end)

    # Events per hour
    Float.round(length(events) / (@evolution_window_s / 3600.0), 2)
  end

  defp compute_mean_trust(holons) do
    if length(holons) == 0 do
      1.0
    else
      # Use health_score as proxy for trust (real trust from FederationAmbassador)
      total = Enum.sum(Enum.map(holons, & &1.health_score))
      Float.round(total / length(holons), 4)
    end
  end

  defp prune_old_events do
    cutoff = System.monotonic_time(:second) - @evolution_window_s

    :ets.tab2list(@ets_events)
    |> Enum.filter(fn {ts, _} -> ts < cutoff end)
    |> Enum.each(fn {ts, _} -> :ets.delete(@ets_events, ts) end)
  end

  defp schedule_tick(tick_ms) do
    Process.send_after(self(), :observation_tick, tick_ms)
  end

  defp broadcast_kpi(kpi) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:cosmos_kpi, kpi}
      )
    rescue
      _ -> :ok
    end

    publish_zenoh(kpi)
  end

  defp publish_zenoh(kpi) do
    data =
      Map.merge(kpi, %{
        checkpoint: @checkpoint,
        topic: @zenoh_topic
      })

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(kpi, observation_count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l7, :cosmic_observer, :observation],
        %{
          ecosystem_health: kpi.ecosystem_health_score,
          active_holons: kpi.total_active_holons,
          observation_count: observation_count
        },
        %{
          checkpoint: @checkpoint,
          threat_level: kpi.threat_level,
          constraint: "SC-MON-001"
        }
      )
    rescue
      _ -> :ok
    end
  end
end
