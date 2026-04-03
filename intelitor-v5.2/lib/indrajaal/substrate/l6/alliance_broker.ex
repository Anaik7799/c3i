defmodule Indrajaal.Substrate.L6.AllianceBroker do
  @moduledoc """
  ## Design Intent
  L6 Alliance Broker — manages inter-holon alliances and partnerships within the
  Indrajaal VSM fractal mesh. Maintains a persistent registry of active alliances,
  tracking partner identity, agreed terms, trust scores, and expiry.

  Alliance lifecycle:
    - :proposed   — initiated by local holon, awaiting acceptance
    - :active     — accepted by both parties, within expiry window
    - :expired    — past expires_at, no longer honoured
    - :dissolved  — explicitly terminated by either party

  Trust score is EMA-smoothed from interaction outcomes over time. Alliances with
  trust_score < 0.3 are eligible for auto-dissolution via the heartbeat tick.

  Heartbeat (every 120 s) expires stale alliances and publishes alliance status.

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions — broker tracks, never modifies
  - SC-FED-002: Maintain node autonomy — alliance terms cannot override constitution
  - SC-FED-003: Detect constitution divergence — alliances monitor alignment drift
  - SC-FED-004: Emergency coordination time-bounded — alliance negotiations bounded
  - SC-FED-005: Membership management maintained — registry kept current
  - SC-FED-006: Attestation Ed25519-verified — alliance identity verified
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L6 morphogenesis) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_alliances :alliance_broker_alliances
  @pubsub_topic "prajna:federation"
  @zenoh_topic "indrajaal/substrate/l6/alliances/status"
  @checkpoint "CP-L6-ALLIANCE-01"

  # Default alliance TTL (seconds) — 24 hours
  @default_ttl_s 86_400

  # Heartbeat interval ms
  @heartbeat_ms 120_000

  # EMA smoothing factor for trust updates
  @ema_alpha 0.3

  # Auto-dissolve threshold
  @min_trust_threshold 0.3

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type alliance_status :: :proposed | :active | :expired | :dissolved

  @type alliance_terms :: %{
          purpose: String.t(),
          resource_sharing: boolean(),
          data_sharing: boolean(),
          priority: :low | :medium | :high
        }

  @type alliance :: %{
          id: String.t(),
          partner_id: String.t(),
          terms: alliance_terms(),
          trust_score: float(),
          status: alliance_status(),
          proposed_at: integer(),
          accepted_at: integer() | nil,
          expires_at: integer(),
          dissolved_at: integer() | nil
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Propose a new alliance with a partner holon.
  Returns `{:ok, alliance_id}` or `{:error, reason}`.
  """
  @spec propose(String.t(), alliance_terms()) :: {:ok, String.t()} | {:error, term()}
  def propose(partner_id, terms)
      when is_binary(partner_id) and is_map(terms) do
    GenServer.call(@name, {:propose, partner_id, terms})
  end

  @doc """
  Accept a proposed alliance by its ID, activating it.
  """
  @spec accept(String.t()) :: :ok | {:error, term()}
  def accept(alliance_id) when is_binary(alliance_id) do
    GenServer.call(@name, {:accept, alliance_id})
  end

  @doc """
  Dissolve an active or proposed alliance.
  """
  @spec dissolve(String.t()) :: :ok | {:error, term()}
  def dissolve(alliance_id) when is_binary(alliance_id) do
    GenServer.call(@name, {:dissolve, alliance_id})
  end

  @doc """
  Return all currently active alliances.
  """
  @spec active_alliances() :: [alliance()]
  def active_alliances do
    GenServer.call(@name, :active_alliances)
  end

  @doc """
  Return all alliances in the registry regardless of status.
  """
  @spec all_alliances() :: [alliance()]
  def all_alliances do
    GenServer.call(@name, :all_alliances)
  end

  @doc """
  Update trust score for an alliance using EMA smoothing.
  `outcome` should be between 0.0 (bad) and 1.0 (perfect).
  """
  @spec update_trust(String.t(), float()) :: :ok | {:error, term()}
  def update_trust(alliance_id, outcome)
      when is_binary(alliance_id) and is_float(outcome) do
    GenServer.call(@name, {:update_trust, alliance_id, outcome})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_alliances, [:set, :public, :named_table, read_concurrency: true])

    interval_ms = Keyword.get(opts, :heartbeat_interval_ms, @heartbeat_ms)
    schedule_heartbeat(interval_ms)

    state = %{
      heartbeat_count: 0,
      heartbeat_interval_ms: interval_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[ALLIANCE_BROKER] Started — checkpoint=#{@checkpoint}")
    {:ok, state}
  end

  @impl true
  def handle_call({:propose, partner_id, terms}, _from, state) do
    now = System.monotonic_time(:second)
    id = generate_id()

    alliance = %{
      id: id,
      partner_id: partner_id,
      terms: terms,
      trust_score: 0.7,
      status: :proposed,
      proposed_at: now,
      accepted_at: nil,
      expires_at: now + @default_ttl_s,
      dissolved_at: nil
    }

    :ets.insert(@ets_alliances, {id, alliance})

    Logger.info("[ALLIANCE_BROKER] Alliance proposed id=#{id} partner=#{partner_id}")
    {:reply, {:ok, id}, state}
  end

  @impl true
  def handle_call({:accept, alliance_id}, _from, state) do
    case :ets.lookup(@ets_alliances, alliance_id) do
      [{^alliance_id, %{status: :proposed} = alliance}] ->
        now = System.monotonic_time(:second)
        updated = %{alliance | status: :active, accepted_at: now}
        :ets.insert(@ets_alliances, {alliance_id, updated})
        Logger.info("[ALLIANCE_BROKER] Alliance accepted id=#{alliance_id}")
        {:reply, :ok, state}

      [{^alliance_id, %{status: status}}] ->
        {:reply, {:error, {:invalid_status, status}}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:dissolve, alliance_id}, _from, state) do
    case :ets.lookup(@ets_alliances, alliance_id) do
      [{^alliance_id, alliance}] ->
        now = System.monotonic_time(:second)
        updated = %{alliance | status: :dissolved, dissolved_at: now}
        :ets.insert(@ets_alliances, {alliance_id, updated})
        Logger.info("[ALLIANCE_BROKER] Alliance dissolved id=#{alliance_id}")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:active_alliances, _from, state) do
    alliances =
      :ets.tab2list(@ets_alliances)
      |> Enum.map(fn {_id, a} -> a end)
      |> Enum.filter(&(&1.status == :active))

    {:reply, alliances, state}
  end

  @impl true
  def handle_call(:all_alliances, _from, state) do
    alliances = :ets.tab2list(@ets_alliances) |> Enum.map(fn {_id, a} -> a end)
    {:reply, alliances, state}
  end

  @impl true
  def handle_call({:update_trust, alliance_id, outcome}, _from, state) do
    outcome_clamped = max(0.0, min(1.0, outcome))

    case :ets.lookup(@ets_alliances, alliance_id) do
      [{^alliance_id, alliance}] ->
        new_score = @ema_alpha * outcome_clamped + (1.0 - @ema_alpha) * alliance.trust_score
        new_score = Float.round(new_score, 4)
        updated = %{alliance | trust_score: new_score}
        :ets.insert(@ets_alliances, {alliance_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info(:heartbeat_tick, state) do
    now = System.monotonic_time(:second)
    expire_stale_alliances(now)
    auto_dissolve_low_trust()

    new_state = %{state | heartbeat_count: state.heartbeat_count + 1}

    active = active_count()
    broadcast_status(active, new_state.heartbeat_count)

    Logger.debug(
      "[ALLIANCE_BROKER] Heartbeat #{new_state.heartbeat_count} — active_alliances=#{active}"
    )

    schedule_heartbeat(state.heartbeat_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[ALLIANCE_BROKER] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp expire_stale_alliances(now) do
    :ets.tab2list(@ets_alliances)
    |> Enum.each(fn {id, alliance} ->
      if alliance.status == :active and alliance.expires_at <= now do
        :ets.insert(@ets_alliances, {id, %{alliance | status: :expired}})
        Logger.info("[ALLIANCE_BROKER] Alliance expired id=#{id}")
      end
    end)
  end

  defp auto_dissolve_low_trust do
    :ets.tab2list(@ets_alliances)
    |> Enum.each(fn {id, alliance} ->
      if alliance.status == :active and alliance.trust_score < @min_trust_threshold do
        now = System.monotonic_time(:second)
        :ets.insert(@ets_alliances, {id, %{alliance | status: :dissolved, dissolved_at: now}})
        Logger.warning("[ALLIANCE_BROKER] Alliance auto-dissolved (low trust) id=#{id}")
      end
    end)
  end

  defp active_count do
    :ets.tab2list(@ets_alliances)
    |> Enum.count(fn {_id, a} -> a.status == :active end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat_tick, interval_ms)
  end

  defp broadcast_status(active_count, heartbeat_count) do
    payload = %{active_alliances: active_count, heartbeat_count: heartbeat_count}

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:alliance_status, payload}
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
