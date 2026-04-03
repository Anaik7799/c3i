defmodule Indrajaal.Substrate.L6.SymbiosisTracker do
  @moduledoc """
  L6 Symbiosis Tracker — Inter-holon mutualism and cooperation metrics.

  Tracks the symbiotic relationship quality between this holon and its federation
  peers. Computes mutualism scores based on resource exchange, message reciprocity,
  and collaborative task completion rates.

  ## Metrics
  - Mutualism Index: ratio of bidirectional exchanges to total exchanges
  - Reciprocity Score: balance of give vs receive per peer
  - Trust Trajectory: trend of trust scores over time (EMA)

  ## STAMP Constraints
  - SC-FED-005: Membership management maintained
  - SC-FED-001: No modification of node constitutions
  """

  use GenServer
  require Logger

  @ema_alpha 0.2
  @stale_threshold_ms 300_000

  defstruct peers: %{}, exchanges: 0, last_update: nil

  @type peer_metrics :: %{
          mutualism_index: float(),
          reciprocity: float(),
          trust_ema: float(),
          gives: non_neg_integer(),
          receives: non_neg_integer(),
          last_exchange: DateTime.t() | nil
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec record_exchange(String.t(), :give | :receive, map()) :: :ok
  def record_exchange(peer_id, direction, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:exchange, peer_id, direction, metadata})
  end

  @spec peer_metrics(String.t()) :: {:ok, peer_metrics()} | {:error, :unknown_peer}
  def peer_metrics(peer_id) do
    GenServer.call(__MODULE__, {:peer_metrics, peer_id})
  end

  @spec federation_health() :: map()
  def federation_health do
    GenServer.call(__MODULE__, :federation_health)
  end

  @spec stale_peers() :: [String.t()]
  def stale_peers do
    GenServer.call(__MODULE__, :stale_peers)
  end

  # ── GenServer ────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:exchange, peer_id, direction, _metadata}, state) do
    peer = Map.get(state.peers, peer_id, default_peer())
    updated_peer = record_direction(peer, direction)
    peers = Map.put(state.peers, peer_id, updated_peer)

    {:noreply,
     %{state | peers: peers, exchanges: state.exchanges + 1, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:peer_metrics, peer_id}, _from, state) do
    case Map.get(state.peers, peer_id) do
      nil -> {:reply, {:error, :unknown_peer}, state}
      peer -> {:reply, {:ok, compute_metrics(peer)}, state}
    end
  end

  @impl true
  def handle_call(:federation_health, _from, state) do
    peer_count = map_size(state.peers)

    avg_mutualism =
      if peer_count > 0 do
        state.peers
        |> Enum.map(fn {_id, p} -> compute_metrics(p).mutualism_index end)
        |> Enum.sum()
        |> Kernel./(peer_count)
      else
        0.0
      end

    health = %{
      peer_count: peer_count,
      total_exchanges: state.exchanges,
      avg_mutualism_index: Float.round(avg_mutualism, 3),
      last_update: state.last_update
    }

    {:reply, health, state}
  end

  @impl true
  def handle_call(:stale_peers, _from, state) do
    stale =
      state.peers
      |> Enum.filter(fn {_id, p} ->
        case p.last_exchange do
          nil ->
            true

          ts ->
            diff = DateTime.diff(DateTime.utc_now(), ts, :millisecond)
            diff > @stale_threshold_ms
        end
      end)
      |> Enum.map(fn {id, _p} -> id end)

    {:reply, stale, state}
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp default_peer do
    %{gives: 0, receives: 0, trust_ema: 0.5, last_exchange: nil}
  end

  defp record_direction(peer, :give) do
    trust = @ema_alpha * 0.6 + (1 - @ema_alpha) * peer.trust_ema
    %{peer | gives: peer.gives + 1, trust_ema: trust, last_exchange: DateTime.utc_now()}
  end

  defp record_direction(peer, :receive) do
    trust = @ema_alpha * 0.4 + (1 - @ema_alpha) * peer.trust_ema
    %{peer | receives: peer.receives + 1, trust_ema: trust, last_exchange: DateTime.utc_now()}
  end

  defp compute_metrics(peer) do
    total = peer.gives + peer.receives
    bidirectional = 2 * min(peer.gives, peer.receives)

    mutualism = if total > 0, do: bidirectional / total, else: 0.0
    reciprocity = if total > 0, do: 1.0 - abs(peer.gives - peer.receives) / total, else: 0.0

    %{
      mutualism_index: Float.round(mutualism, 3),
      reciprocity: Float.round(reciprocity, 3),
      trust_ema: Float.round(peer.trust_ema, 3),
      gives: peer.gives,
      receives: peer.receives,
      last_exchange: peer.last_exchange
    }
  end
end
