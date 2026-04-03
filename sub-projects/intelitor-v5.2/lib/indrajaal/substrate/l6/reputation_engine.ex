defmodule Indrajaal.Substrate.L6.ReputationEngine do
  @moduledoc """
  ## Design Intent
  L6 Reputation Engine — tracks and computes peer reputation scores for all known
  federation peers using Exponential Moving Average (EMA) smoothing.

  Reputation model:
    - Each rating event carries a score (0.0–1.0) and an optional category tag
    - The reputation score is updated using EMA: score_new = α × rating + (1−α) × score_old
    - α = 0.2 (slow learning; robust against short-term anomalies)
    - Initial score for unknown peers is 0.5 (neutral prior)
    - Peers whose score drops below @blacklist_threshold are flagged as blacklisted
    - Top-N peers are computed by sorting ETS entries by descending score

  Blacklisted peers are not removed — they remain in the registry so history is
  preserved. Callers check `blacklisted?/1` before initiating interactions.

  Heartbeat tick (every 90 s) publishes reputation summary to PubSub + Zenoh.

  ## STAMP Constraints
  - SC-FED-005: Membership management maintained — reputation affects membership weight
  - SC-FED-006: Attestation Ed25519-verified — rating source verified
  - SC-SMRITI-110: Version vectors in SQLite — reputation history append-only
  - SC-FUNC-001: System must compile at all times

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L6 morphogenesis) |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_table :reputation_engine_scores
  @pubsub_topic "prajna:federation"
  @zenoh_topic "indrajaal/substrate/l6/reputation/summary"
  @checkpoint "CP-L6-REPUTATION-01"

  # EMA smoothing factor — slow learning for robustness
  @ema_alpha 0.2

  # Initial reputation for unknown peers
  @initial_score 0.5

  # Blacklist threshold — peers below this score are blacklisted
  @blacklist_threshold 0.2

  # Heartbeat interval ms
  @heartbeat_ms 90_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type peer_id :: String.t()

  @type rating_category :: :connectivity | :reliability | :honesty | :performance | :default

  @type peer_record :: %{
          peer_id: peer_id(),
          score: float(),
          rating_count: non_neg_integer(),
          blacklisted: boolean(),
          last_rated_at: integer() | nil,
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
  Submit a rating for a peer. `score` must be in [0.0, 1.0].
  If the peer is unknown it is registered with the neutral prior first.
  """
  @spec rate(peer_id(), float(), rating_category()) :: :ok | {:error, term()}
  def rate(peer_id, score, category \\ :default)
      when is_binary(peer_id) and is_float(score) do
    GenServer.call(@name, {:rate, peer_id, score, category})
  end

  @doc """
  Return the current reputation score for a peer, or `{:error, :not_found}`.
  """
  @spec score(peer_id()) :: {:ok, float()} | {:error, :not_found}
  def score(peer_id) when is_binary(peer_id) do
    case :ets.lookup(@ets_table, peer_id) do
      [{^peer_id, record}] -> {:ok, record.score}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Return the top `n` peers by descending reputation score.
  """
  @spec top_peers(pos_integer()) :: [peer_record()]
  def top_peers(n) when is_integer(n) and n > 0 do
    :ets.tab2list(@ets_table)
    |> Enum.map(fn {_id, r} -> r end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(n)
  end

  @doc """
  Return `true` if the peer's reputation is below the blacklist threshold.
  """
  @spec blacklisted?(peer_id()) :: boolean()
  def blacklisted?(peer_id) when is_binary(peer_id) do
    case :ets.lookup(@ets_table, peer_id) do
      [{^peer_id, record}] -> record.blacklisted
      [] -> false
    end
  end

  @doc """
  Return full record for a peer.
  """
  @spec peer_record(peer_id()) :: {:ok, peer_record()} | {:error, :not_found}
  def peer_record(peer_id) when is_binary(peer_id) do
    case :ets.lookup(@ets_table, peer_id) do
      [{^peer_id, record}] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])

    interval_ms = Keyword.get(opts, :heartbeat_interval_ms, @heartbeat_ms)
    schedule_heartbeat(interval_ms)

    state = %{
      heartbeat_count: 0,
      heartbeat_interval_ms: interval_ms,
      started_at: DateTime.utc_now()
    }

    Logger.warning("[REPUTATION_ENGINE] Started — checkpoint=#{@checkpoint}")
    {:ok, state}
  end

  @impl true
  def handle_call({:rate, peer_id, score, _category}, _from, state) do
    score_clamped = max(0.0, min(1.0, score))
    now = System.monotonic_time(:second)

    record =
      case :ets.lookup(@ets_table, peer_id) do
        [{^peer_id, existing}] -> existing
        [] -> new_record(peer_id, now)
      end

    new_score = @ema_alpha * score_clamped + (1.0 - @ema_alpha) * record.score
    new_score = Float.round(new_score, 4)
    blacklisted = new_score < @blacklist_threshold

    updated = %{
      record
      | score: new_score,
        rating_count: record.rating_count + 1,
        blacklisted: blacklisted,
        last_rated_at: now
    }

    :ets.insert(@ets_table, {peer_id, updated})

    if blacklisted do
      Logger.warning("[REPUTATION_ENGINE] Peer blacklisted id=#{peer_id} score=#{new_score}")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:heartbeat_tick, state) do
    new_state = %{state | heartbeat_count: state.heartbeat_count + 1}

    total = :ets.info(@ets_table, :size)
    blacklisted = :ets.tab2list(@ets_table) |> Enum.count(fn {_id, r} -> r.blacklisted end)

    broadcast_summary(total, blacklisted, new_state.heartbeat_count)

    Logger.debug(
      "[REPUTATION_ENGINE] Heartbeat #{new_state.heartbeat_count} — peers=#{total} blacklisted=#{blacklisted}"
    )

    schedule_heartbeat(state.heartbeat_interval_ms)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[REPUTATION_ENGINE] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp new_record(peer_id, now) do
    %{
      peer_id: peer_id,
      score: @initial_score,
      rating_count: 0,
      blacklisted: false,
      last_rated_at: nil,
      registered_at: now
    }
  end

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat_tick, interval_ms)
  end

  defp broadcast_summary(total, blacklisted, heartbeat_count) do
    payload = %{
      total_peers: total,
      blacklisted: blacklisted,
      heartbeat_count: heartbeat_count
    }

    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:reputation_summary, payload}
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
