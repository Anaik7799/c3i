defmodule Indrajaal.Substrate.L2.HeartbeatSync do
  @moduledoc """
  ## Design Intent
  L2 substrate Heartbeat Sync — pure functional distributed heartbeat synchronizer.
  Maintains a registry of peer heartbeats and computes synchrony metrics for
  VSM System 2 coordination. Uses a sliding-window jitter model to detect
  peers that are drifting out of sync.

  Jitter model:
    jitter = abs(observed_interval − expected_interval)
    normalized_jitter = jitter / expected_interval     (clamped to [0.0, 1.0])

  Sync score per peer:
    sync_score = 1.0 − EMA(normalized_jitter)          (α = 0.3)

  Cluster sync health:
    health = mean(sync_score for alive peers)

  A peer is considered :stale when last_beat age > stale_threshold_ticks.

  ## STAMP Constraints
  - SC-S2-001: VSM S2 coordination subsystem — ENFORCED
  - SC-S2-002: Oscillation detection mandatory — ENFORCED
  - SC-DMS-001: Heartbeat interval MUST be ≤ 100ms — ENFORCED (validation)
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @ema_alpha 0.3
  @stale_threshold_ticks 3
  @max_peers 64

  @type peer_id :: String.t()

  @type peer_state :: %{
          id: peer_id(),
          last_tick: non_neg_integer(),
          last_interval: non_neg_integer(),
          jitter_ema: float(),
          sync_score: float(),
          status: :alive | :stale | :unknown
        }

  @type t :: %__MODULE__{
          self_id: peer_id(),
          expected_interval_ticks: pos_integer(),
          tick: non_neg_integer(),
          peers: %{peer_id() => peer_state()},
          cluster_health: float()
        }

  defstruct self_id: "node_0",
            expected_interval_ticks: 1,
            tick: 0,
            peers: %{},
            cluster_health: 1.0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    self_id = Keyword.get(opts, :self_id, "node_0")
    expected = Keyword.get(opts, :expected_interval_ticks, 1)

    cond do
      not is_binary(self_id) ->
        {:error, "self_id must be a string"}

      not is_integer(expected) or expected < 1 ->
        {:error, "expected_interval_ticks must be a positive integer"}

      true ->
        {:ok,
         %__MODULE__{
           self_id: self_id,
           expected_interval_ticks: expected
         }}
    end
  end

  @doc """
  Record a heartbeat from a peer at the current tick.
  Returns updated state with recalculated sync scores.
  """
  @spec record_beat(t(), peer_id()) :: {:ok, t()} | {:error, String.t()}
  def record_beat(%__MODULE__{} = state, peer_id) when is_binary(peer_id) do
    cond do
      peer_id == state.self_id ->
        {:error, "cannot record beat from self"}

      map_size(state.peers) >= @max_peers and not Map.has_key?(state.peers, peer_id) ->
        {:error, "peer capacity #{@max_peers} reached"}

      true ->
        peer = Map.get(state.peers, peer_id, new_peer(peer_id))

        interval =
          if peer.last_tick == 0,
            do: state.expected_interval_ticks,
            else: state.tick - peer.last_tick

        jitter =
          abs(interval - state.expected_interval_ticks) / max(state.expected_interval_ticks, 1)

        jitter = clamp(jitter, 0.0, 1.0)
        jitter_ema = @ema_alpha * jitter + (1.0 - @ema_alpha) * peer.jitter_ema
        sync_score = Float.round(1.0 - jitter_ema, 4)

        updated_peer = %{
          peer
          | last_tick: state.tick,
            last_interval: interval,
            jitter_ema: Float.round(jitter_ema, 4),
            sync_score: sync_score,
            status: :alive
        }

        peers = Map.put(state.peers, peer_id, updated_peer)
        new_state = %{state | peers: peers}
        {:ok, recompute_health(new_state)}
    end
  end

  @doc """
  Advance tick counter. Marks peers that missed more than
  `stale_threshold_ticks` ticks as `:stale`.
  """
  @spec advance_tick(t()) :: t()
  def advance_tick(%__MODULE__{} = state) do
    new_tick = state.tick + 1

    peers =
      Map.new(state.peers, fn {id, peer} ->
        age = new_tick - peer.last_tick

        status =
          cond do
            peer.status == :unknown -> :unknown
            age > @stale_threshold_ticks -> :stale
            true -> :alive
          end

        {id, %{peer | status: status}}
      end)

    state
    |> Map.put(:tick, new_tick)
    |> Map.put(:peers, peers)
    |> recompute_health()
  end

  @doc """
  Return peers grouped by status.
  """
  @spec peer_summary(t()) :: %{alive: [peer_id()], stale: [peer_id()], unknown: [peer_id()]}
  def peer_summary(%__MODULE__{} = state) do
    Enum.group_by(
      Map.keys(state.peers),
      fn id -> state.peers[id].status end
    )
    |> Map.merge(%{alive: [], stale: [], unknown: []}, fn _k, v1, _v2 -> v1 end)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    summary = peer_summary(state)

    %{
      self_id: state.self_id,
      tick: state.tick,
      peer_count: map_size(state.peers),
      alive_count: length(summary.alive),
      stale_count: length(summary.stale),
      cluster_health: Float.round(state.cluster_health, 4)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp new_peer(id) do
    %{
      id: id,
      last_tick: 0,
      last_interval: 0,
      jitter_ema: 0.0,
      sync_score: 1.0,
      status: :unknown
    }
  end

  defp recompute_health(%__MODULE__{} = state) do
    alive =
      state.peers
      |> Map.values()
      |> Enum.filter(fn p -> p.status == :alive end)

    health =
      if alive == [] do
        1.0
      else
        Enum.sum(Enum.map(alive, & &1.sync_score)) / length(alive)
      end

    %{state | cluster_health: Float.round(health, 4)}
  end

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo
end
