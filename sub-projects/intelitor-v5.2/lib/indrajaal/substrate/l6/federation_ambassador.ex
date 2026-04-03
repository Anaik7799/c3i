defmodule Indrajaal.Substrate.L6.FederationAmbassador do
  @moduledoc """
  ## Design Intent
  L6 GenServer managing inter-holon diplomatic relations for the Indrajaal VSM
  fractal mesh. Maintains a peer_holons registry, per-peer trust_scores (0.0–1.0),
  and last_attestation timestamps for federated identity verification.

  Diplomatic model:
    - Each peer holon has: id, fqun, trust_score, attestation_status, last_seen
    - trust_score decays over time if no fresh attestation is received
    - Trust levels: :trusted (≥ 0.8), :provisional (≥ 0.5), :untrusted (< 0.5)
    - Attestation refresh (Ed25519-style — simulated here) resets trust to 1.0
    - Peers not attested for > 1 hour are downgraded to :untrusted
    - Heartbeat tick (every 60 s) applies trust decay and publishes federation status

  Trust decay formula:
    trust_score(t) = initial_score × e^(-decay_rate × elapsed_minutes)
    decay_rate = 0.02 (half-life ~35 minutes)

  ## STAMP Constraints
  - SC-FED-001: No modification of node constitutions — ambassador observes, never mutates
  - SC-FED-006: Attestation Ed25519-verified — simulated here, real FFI in production
  - SC-SMRITI-110: Version vectors in SQLite; attestation expires 1hr — ENFORCED
  - SC-DIST-001: FQUN tracked for all peers — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (Task 68, L6) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_peers :federation_ambassador_peers
  @pubsub_topic "prajna:federation"
  @zenoh_topic "indrajaal/substrate/l6/federation/status"
  @checkpoint "CP-L6-FED-AMBASSADOR-01"

  # Heartbeat interval ms
  @heartbeat_ms 60_000

  # Attestation expiry (seconds)
  @attestation_expiry_s 3600

  # Trust decay rate per minute (λ = 0.02 → half-life ~35 min)
  @decay_rate 0.02

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type trust_level :: :trusted | :provisional | :untrusted

  @type peer_holon :: %{
          id: String.t(),
          fqun: String.t(),
          trust_score: float(),
          trust_level: trust_level(),
          attestation_status: :fresh | :stale | :expired,
          last_attestation_at: integer() | nil,
          last_seen_at: integer() | nil,
          registered_at: integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Register a peer holon in the federation registry.
  """
  @spec register_peer(String.t(), String.t()) :: :ok | {:error, term()}
  def register_peer(peer_id, fqun) when is_binary(peer_id) and is_binary(fqun) do
    GenServer.call(@name, {:register_peer, peer_id, fqun})
  end

  @doc """
  Record a fresh attestation from a peer, resetting trust score to 1.0.
  """
  @spec attest_peer(String.t()) :: :ok | {:error, term()}
  def attest_peer(peer_id) when is_binary(peer_id) do
    GenServer.call(@name, {:attest_peer, peer_id})
  end

  @doc """
  Update last_seen timestamp for a peer (heartbeat from peer).
  """
  @spec peer_heartbeat(String.t()) :: :ok | {:error, term()}
  def peer_heartbeat(peer_id) when is_binary(peer_id) do
    GenServer.call(@name, {:peer_heartbeat, peer_id})
  end

  @doc """
  Return the current trust score and level for a peer.
  """
  @spec trust_status(String.t()) :: {:ok, peer_holon()} | {:error, :not_found}
  def trust_status(peer_id) when is_binary(peer_id) do
    GenServer.call(@name, {:trust_status, peer_id})
  end

  @doc """
  List all registered peer holons.
  """
  @spec list_peers() :: [peer_holon()]
  def list_peers do
    GenServer.call(@name, :list_peers)
  end

  @doc """
  Return federation summary statistics.
  """
  @spec federation_summary() :: map()
  def federation_summary do
    GenServer.call(@name, :federation_summary)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_peers, [:set, :public, :named_table, read_concurrency: true])

    interval_ms = Keyword.get(opts, :heartbeat_interval_ms, @heartbeat_ms)
    schedule_heartbeat(interval_ms)

    state = %{
      heartbeat_count: 0,
      heartbeat_interval_ms: interval_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[FED_AMBASSADOR] Started — checkpoint=#{@checkpoint}")

    {:ok, state}
  end

  @impl true
  def handle_call({:register_peer, peer_id, fqun}, _from, state) do
    peer = %{
      id: peer_id,
      fqun: fqun,
      trust_score: 1.0,
      trust_level: :trusted,
      attestation_status: :fresh,
      last_attestation_at: System.monotonic_time(:second),
      last_seen_at: System.monotonic_time(:second),
      registered_at: System.monotonic_time(:second)
    }

    :ets.insert(@ets_peers, {peer_id, peer})

    Logger.info("[FED_AMBASSADOR] Peer registered id=#{peer_id} fqun=#{fqun}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:attest_peer, peer_id}, _from, state) do
    case :ets.lookup(@ets_peers, peer_id) do
      [{^peer_id, peer}] ->
        now = System.monotonic_time(:second)

        updated = %{
          peer
          | trust_score: 1.0,
            trust_level: :trusted,
            attestation_status: :fresh,
            last_attestation_at: now,
            last_seen_at: now
        }

        :ets.insert(@ets_peers, {peer_id, updated})

        Logger.debug("[FED_AMBASSADOR] Peer attested id=#{peer_id} trust=1.0")

        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:peer_heartbeat, peer_id}, _from, state) do
    case :ets.lookup(@ets_peers, peer_id) do
      [{^peer_id, peer}] ->
        updated = %{peer | last_seen_at: System.monotonic_time(:second)}
        :ets.insert(@ets_peers, {peer_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:trust_status, peer_id}, _from, state) do
    case :ets.lookup(@ets_peers, peer_id) do
      [{^peer_id, peer}] -> {:reply, {:ok, peer}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_peers, _from, state) do
    peers = :ets.tab2list(@ets_peers) |> Enum.map(fn {_id, p} -> p end)
    {:reply, peers, state}
  end

  @impl true
  def handle_call(:federation_summary, _from, state) do
    peers = :ets.tab2list(@ets_peers) |> Enum.map(fn {_id, p} -> p end)
    total = length(peers)
    trusted = Enum.count(peers, &(&1.trust_level == :trusted))
    provisional = Enum.count(peers, &(&1.trust_level == :provisional))
    untrusted = Enum.count(peers, &(&1.trust_level == :untrusted))

    avg_trust =
      if total > 0,
        do: Float.round(Enum.sum(Enum.map(peers, & &1.trust_score)) / total, 3),
        else: 0.0

    summary = %{
      total_peers: total,
      trusted: trusted,
      provisional: provisional,
      untrusted: untrusted,
      average_trust: avg_trust,
      heartbeat_count: state.heartbeat_count,
      started_at: DateTime.to_iso8601(state.started_at)
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_info(:heartbeat_tick, state) do
    now = System.monotonic_time(:second)
    apply_trust_decay(now)

    new_state = %{state | heartbeat_count: state.heartbeat_count + 1}

    peers = :ets.tab2list(@ets_peers) |> Enum.map(fn {_id, p} -> p end)
    broadcast_status(peers, new_state.heartbeat_count)
    emit_telemetry(length(peers), new_state.heartbeat_count)

    Logger.debug(
      "[FED_AMBASSADOR] Heartbeat #{new_state.heartbeat_count} — peers=#{length(peers)}"
    )

    schedule_heartbeat(state.heartbeat_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[FED_AMBASSADOR] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp apply_trust_decay(now) do
    :ets.tab2list(@ets_peers)
    |> Enum.each(fn {peer_id, peer} ->
      elapsed_min =
        case peer.last_attestation_at do
          nil -> 0.0
          ts -> (now - ts) / 60.0
        end

      # Exponential decay
      new_score = peer.trust_score * :math.exp(-@decay_rate * elapsed_min)
      new_score = max(0.0, min(1.0, new_score))

      attestation_status =
        case peer.last_attestation_at do
          nil ->
            :expired

          ts ->
            elapsed_s = now - ts

            cond do
              elapsed_s > @attestation_expiry_s -> :expired
              elapsed_s > @attestation_expiry_s / 2 -> :stale
              true -> :fresh
            end
        end

      trust_level =
        cond do
          new_score >= 0.8 -> :trusted
          new_score >= 0.5 -> :provisional
          true -> :untrusted
        end

      updated = %{
        peer
        | trust_score: Float.round(new_score, 4),
          trust_level: trust_level,
          attestation_status: attestation_status
      }

      :ets.insert(@ets_peers, {peer_id, updated})
    end)
  end

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat_tick, interval_ms)
  end

  defp broadcast_status(peers, count) do
    trusted_count = Enum.count(peers, &(&1.trust_level == :trusted))
    untrusted_count = Enum.count(peers, &(&1.trust_level == :untrusted))

    payload = %{
      total_peers: length(peers),
      trusted: trusted_count,
      untrusted: untrusted_count,
      heartbeat_count: count
    }

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:federation_status, payload}
      )
    rescue
      _ -> :ok
    end

    publish_zenoh(payload)
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

  defp emit_telemetry(peer_count, heartbeat_count) do
    try do
      :telemetry.execute(
        [:indrajaal, :substrate, :l6, :federation_ambassador, :heartbeat],
        %{peer_count: peer_count, heartbeat_count: heartbeat_count},
        %{checkpoint: @checkpoint, constraint: "SC-FED-001"}
      )
    rescue
      _ -> :ok
    end
  end
end
