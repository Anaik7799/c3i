defmodule Indrajaal.Federation.PartitionDetector do
  @moduledoc """
  Partition Detector — L6 Federation Layer

  ## Design Intent

  Detects network partitions in the federation mesh using Phi Accrual
  failure detection and heartbeat consensus.

  Tracks registered federation peers via periodic heartbeat messages. Applies
  the Phi Accrual algorithm (Hayashibara et al., 2004) to compute a suspicion
  level φ for each peer: when φ exceeds the configured threshold the peer is
  declared partitioned. Split-brain conditions (live peer count below quorum)
  are detected by comparing the live peer set against the total registered set.

  Core responsibilities:
  - Register federation peers with their expected heartbeat interval
  - Record incoming heartbeats and update per-peer arrival statistics
  - Compute φ (suspicion level) using a sliding window of inter-arrival times
  - Declare peers :suspect, :partitioned, or :alive based on φ thresholds
  - Detect split-brain when quorum of live peers drops below ⌊N/2⌋+1
  - Broadcast partition events via PubSub `"prajna:partition"`
  - Emit telemetry for every partition state transition
  - Maintain a bounded history ring of partition events in ETS

  ## Phi Accrual Algorithm

  The suspicion value φ at time t for peer p is:

      φ(t) = -log₁₀(P_later(t - t_last))

  where `P_later` is the probability of receiving the next heartbeat later
  than `t - t_last`, modelled as a Normal distribution over the observed
  inter-arrival times. When φ ≥ `@phi_suspect` the peer is suspect;
  when φ ≥ `@phi_partition` the peer is considered partitioned.

  ## STAMP Constraints

  - SC-SIL4-015: Split-brain detection triggers apoptosis
  - SC-HA-003: Zenoh 2oo3 quorum requires awareness of live peer set
  - SC-DMS-002: Failsafe triggers within 50 ms of timeout
  - SC-FED-004: Emergency coordination time-bounded
  - SC-VER-022: Quorum maintained verified

  ## Change History

  | Version | Date       | Author | Change                                          |
  |---------|------------|--------|-------------------------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Add partitioned?/0, suspected_partitions/0, status/0 |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "prajna:partition"
  @ets_peers :partition_detector_peers
  @ets_history :partition_detector_history

  # Phi thresholds
  @phi_suspect 4.0
  @phi_partition 8.0

  # Sliding window size for inter-arrival statistics
  @window_size 20

  # Heartbeat check interval (5 seconds)
  @check_interval_ms 5_000

  # Maximum history records
  @history_max 200

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type peer_state :: :alive | :suspect | :partitioned

  @type peer_entry :: %{
          peer_id: String.t(),
          expected_interval_ms: pos_integer(),
          last_heartbeat: DateTime.t() | nil,
          arrival_window: [integer()],
          mean_ms: float(),
          stddev_ms: float(),
          phi: float(),
          state: peer_state(),
          state_changed_at: DateTime.t(),
          heartbeat_count: non_neg_integer()
        }

  @type partition_event :: %{
          event: :peer_suspect | :peer_partitioned | :peer_recovered | :split_brain,
          peer_id: String.t() | nil,
          phi: float() | nil,
          live_count: non_neg_integer(),
          total_count: non_neg_integer(),
          timestamp: DateTime.t()
        }

  @type t :: %{
          check_count: non_neg_integer(),
          partition_count: non_neg_integer(),
          split_brain_count: non_neg_integer(),
          started_at: DateTime.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the PartitionDetector GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a federation peer for heartbeat monitoring.
  `expected_interval_ms` is the expected heartbeat period for this peer.
  """
  @spec register_peer(String.t(), pos_integer()) :: :ok
  def register_peer(peer_id, expected_interval_ms \\ 5_000)
      when is_binary(peer_id) and is_integer(expected_interval_ms) and expected_interval_ms > 0 do
    GenServer.call(@name, {:register_peer, peer_id, expected_interval_ms})
  end

  @doc """
  Record a heartbeat arrival from a peer.

  Updates the inter-arrival sliding window and resets the peer's φ to 0.
  This is the primary liveness signal — peers MUST call this regularly.
  Publishes to "prajna:partition" on peer state changes.
  """
  @spec heartbeat(String.t()) :: :ok
  def heartbeat(peer_id) when is_binary(peer_id) do
    GenServer.cast(@name, {:heartbeat, peer_id})
  end

  @doc """
  Return `true` when the federation is currently partitioned.

  A partition is detected when the number of alive peers drops below
  the ⌊N/2⌋+1 quorum threshold. Returns `false` when no peers are
  registered (degenerate single-node mode).
  """
  @spec partitioned?() :: boolean()
  def partitioned? do
    if :ets.whereis(@ets_peers) != :undefined do
      total = :ets.info(@ets_peers, :size)
      alive_count = count_alive_peers()
      quorum = div(total, 2) + 1
      total > 0 and alive_count < quorum
    else
      false
    end
  end

  @doc """
  Return the list of peer IDs currently suspected or confirmed as partitioned.

  Suspected peers have φ ≥ `@phi_suspect` (4.0) but < `@phi_partition` (8.0).
  Partitioned peers have φ ≥ `@phi_partition` (8.0).

  Returns a map `%{suspected: [peer_id], partitioned: [peer_id]}`.
  """
  @spec suspected_partitions() :: %{suspected: [String.t()], partitioned: [String.t()]}
  def suspected_partitions do
    if :ets.whereis(@ets_peers) != :undefined do
      @ets_peers
      |> :ets.tab2list()
      |> Enum.reduce(%{suspected: [], partitioned: []}, fn {peer_id, entry}, acc ->
        case entry.state do
          :suspect -> Map.update!(acc, :suspected, &[peer_id | &1])
          :partitioned -> Map.update!(acc, :partitioned, &[peer_id | &1])
          _ -> acc
        end
      end)
    else
      %{suspected: [], partitioned: []}
    end
  end

  @doc """
  Return a comprehensive status map for the partition detector.

  Includes registered peer count, alive/suspect/partitioned counts,
  quorum status, partition flag, and uptime statistics.
  """
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  @doc """
  Run partition detection across all registered peers.
  Returns a map `%{partitioned: [...], suspect: [...], alive: [...]}`.
  """
  @spec detect_partition() ::
          %{partitioned: [String.t()], suspect: [String.t()], alive: [String.t()]}
  def detect_partition do
    GenServer.call(@name, :detect_partition, 10_000)
  end

  @doc "Return the bounded list of partition history events."
  @spec partition_history(non_neg_integer()) :: [partition_event()]
  def partition_history(limit \\ 50) do
    if :ets.whereis(@ets_history) != :undefined do
      @ets_history
      |> :ets.tab2list()
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
      |> Enum.take(limit)
    else
      []
    end
  end

  @doc "Return list of peer IDs that are currently alive (φ < suspect threshold)."
  @spec live_peers() :: [String.t()]
  def live_peers do
    if :ets.whereis(@ets_peers) != :undefined do
      @ets_peers
      |> :ets.tab2list()
      |> Enum.filter(fn {_id, entry} -> entry.state == :alive end)
      |> Enum.map(fn {id, _} -> id end)
    else
      []
    end
  end

  @doc "Return `true` when live peer count satisfies ⌊N/2⌋+1 quorum."
  @spec quorum_ok?() :: boolean()
  def quorum_ok? do
    total = if :ets.whereis(@ets_peers) != :undefined, do: :ets.info(@ets_peers, :size), else: 0
    live = length(live_peers())
    quorum = div(total, 2) + 1
    live >= quorum
  end

  @doc "GenServer statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    ensure_ets_tables()
    schedule_check()

    state = %{
      check_count: 0,
      partition_count: 0,
      split_brain_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[PartitionDetector] Online — phi_suspect=#{@phi_suspect} " <>
        "phi_partition=#{@phi_partition} window=#{@window_size} " <>
        "check=#{@check_interval_ms}ms — SC-SIL4-015, SC-HA-003"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:register_peer, peer_id, interval_ms}, _from, state) do
    entry = %{
      peer_id: peer_id,
      expected_interval_ms: interval_ms,
      last_heartbeat: nil,
      arrival_window: [],
      mean_ms: interval_ms * 1.0,
      stddev_ms: interval_ms * 0.1,
      phi: 0.0,
      state: :alive,
      state_changed_at: DateTime.utc_now(),
      heartbeat_count: 0
    }

    :ets.insert(@ets_peers, {peer_id, entry})
    Logger.debug("[PartitionDetector] Registered peer=#{peer_id} interval=#{interval_ms}ms")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:detect_partition, _from, state) do
    {result, new_state} = do_detect(state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    total =
      if :ets.whereis(@ets_peers) != :undefined, do: :ets.info(@ets_peers, :size), else: 0

    suspects = suspected_partitions()

    result = %{
      registered_peers: total,
      alive_peers: count_alive_peers(),
      suspect_peers: length(suspects.suspected),
      partitioned_peers: length(suspects.partitioned),
      quorum_ok: quorum_ok?(),
      partitioned: partitioned?(),
      check_count: state.check_count,
      partition_count: state.partition_count,
      split_brain_count: state.split_brain_count,
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, result, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    total =
      if :ets.whereis(@ets_peers) != :undefined, do: :ets.info(@ets_peers, :size), else: 0

    result = %{
      check_count: state.check_count,
      partition_count: state.partition_count,
      split_brain_count: state.split_brain_count,
      registered_peers: total,
      live_peers: length(live_peers()),
      quorum_ok: quorum_ok?(),
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:heartbeat, peer_id}, state) do
    record_heartbeat(peer_id)
    {:noreply, state}
  end

  @impl true
  def handle_info(:scheduled_check, state) do
    schedule_check()
    {_result, new_state} = do_detect(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[PartitionDetector] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp count_alive_peers do
    if :ets.whereis(@ets_peers) != :undefined do
      @ets_peers
      |> :ets.tab2list()
      |> Enum.count(fn {_id, entry} -> entry.state == :alive end)
    else
      0
    end
  end

  defp record_heartbeat(peer_id) do
    now = DateTime.utc_now()

    case :ets.lookup(@ets_peers, peer_id) do
      [{^peer_id, entry}] ->
        interval_ms =
          if is_nil(entry.last_heartbeat) do
            entry.expected_interval_ms
          else
            DateTime.diff(now, entry.last_heartbeat, :millisecond)
          end

        new_window =
          [interval_ms | entry.arrival_window]
          |> Enum.take(@window_size)

        {mean, stddev} = compute_stats(new_window)

        updated = %{
          entry
          | last_heartbeat: now,
            arrival_window: new_window,
            mean_ms: mean,
            stddev_ms: stddev,
            phi: 0.0,
            state: :alive,
            heartbeat_count: entry.heartbeat_count + 1
        }

        :ets.insert(@ets_peers, {peer_id, updated})

        # Broadcast recovery if was suspect/partitioned
        if entry.state != :alive do
          broadcast_state_change(:alive, peer_id, 0.0, :ets.info(@ets_peers, :size), now)
        end

      [] ->
        # Auto-register with default interval
        register_peer_internal(peer_id, @check_interval_ms, now)
    end
  rescue
    e ->
      Logger.debug("[PartitionDetector] record_heartbeat failed for #{peer_id}: #{inspect(e)}")
  end

  defp register_peer_internal(peer_id, interval_ms, now) do
    entry = %{
      peer_id: peer_id,
      expected_interval_ms: interval_ms,
      last_heartbeat: now,
      arrival_window: [interval_ms],
      mean_ms: interval_ms * 1.0,
      stddev_ms: interval_ms * 0.1,
      phi: 0.0,
      state: :alive,
      state_changed_at: now,
      heartbeat_count: 1
    }

    :ets.insert(@ets_peers, {peer_id, entry})
  end

  defp do_detect(state) do
    now = DateTime.utc_now()
    entries = :ets.tab2list(@ets_peers)
    total = length(entries)

    {partitioned, suspect, alive, new_partition_count} =
      Enum.reduce(entries, {[], [], [], 0}, fn {peer_id, entry}, {p_acc, s_acc, a_acc, pc_acc} ->
        phi = compute_phi(entry, now)
        updated_entry = %{entry | phi: phi}

        {new_peer_state, pc_delta} =
          cond do
            phi >= @phi_partition ->
              {:partitioned, if(entry.state != :partitioned, do: 1, else: 0)}

            phi >= @phi_suspect ->
              {:suspect, 0}

            true ->
              {:alive, 0}
          end

        if new_peer_state != entry.state do
          transition = %{
            peer_id: peer_id,
            from: entry.state,
            to: new_peer_state,
            phi: phi,
            timestamp: now
          }

          log_state_transition(transition)
          broadcast_state_change(new_peer_state, peer_id, phi, total, now)
          emit_transition_telemetry(peer_id, new_peer_state, phi)
          store_history_event(new_peer_state, peer_id, phi, total, now)
        end

        changed_at =
          if new_peer_state != entry.state, do: now, else: entry.state_changed_at

        final_entry = %{updated_entry | state: new_peer_state, state_changed_at: changed_at}
        :ets.insert(@ets_peers, {peer_id, final_entry})

        case new_peer_state do
          :partitioned -> {[peer_id | p_acc], s_acc, a_acc, pc_acc + pc_delta}
          :suspect -> {p_acc, [peer_id | s_acc], a_acc, pc_acc}
          :alive -> {p_acc, s_acc, [peer_id | a_acc], pc_acc}
        end
      end)

    live_count = length(alive)
    quorum = div(total, 2) + 1
    split_brain_delta = if total > 0 and live_count < quorum, do: 1, else: 0

    if split_brain_delta > 0 do
      Logger.warning(
        "[PartitionDetector] SPLIT-BRAIN detected live=#{live_count} total=#{total} " <>
          "quorum=#{quorum} — SC-SIL4-015"
      )

      broadcast_split_brain(live_count, total, now)
      emit_split_brain_telemetry(live_count, total)
      store_history_event(:split_brain, nil, nil, total, now)
    end

    result = %{partitioned: partitioned, suspect: suspect, alive: alive}

    new_state = %{
      state
      | check_count: state.check_count + 1,
        partition_count: state.partition_count + new_partition_count,
        split_brain_count: state.split_brain_count + split_brain_delta
    }

    {result, new_state}
  rescue
    e ->
      Logger.error("[PartitionDetector] detect_partition failed: #{inspect(e)}")
      {%{partitioned: [], suspect: [], alive: []}, state}
  end

  # Phi Accrual computation using Normal distribution approximation
  defp compute_phi(entry, now) do
    case entry.last_heartbeat do
      nil ->
        0.0

      last_hb ->
        elapsed_ms = max(0, DateTime.diff(now, last_hb, :millisecond))
        mean = entry.mean_ms
        stddev = max(entry.stddev_ms, 1.0)

        z = (elapsed_ms - mean) / stddev
        p_later = normal_cdf_complement(z)
        p_clamped = max(p_later, 1.0e-15)
        -1.0 * :math.log10(p_clamped)
    end
  rescue
    _ -> 0.0
  end

  # Complementary CDF of standard Normal (Abramowitz & Stegun 26.2.17)
  defp normal_cdf_complement(z) do
    if z <= 0.0 do
      1.0
    else
      t = 1.0 / (1.0 + 0.2316419 * z)

      poly =
        t *
          (0.319381530 +
             t *
               (-0.356563782 +
                  t *
                    (1.781477937 +
                       t * (-1.821255978 + t * 1.330274429))))

      phi_z = 1.0 / :math.sqrt(2.0 * :math.pi()) * :math.exp(-0.5 * z * z)
      max(0.0, phi_z * poly)
    end
  end

  defp compute_stats([]), do: {1000.0, 100.0}

  defp compute_stats(window) do
    count = length(window)
    mean = Enum.sum(window) / count

    variance =
      window
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(count)

    stddev = :math.sqrt(max(variance, 1.0))
    {mean, stddev}
  end

  defp log_state_transition(%{peer_id: pid, from: from, to: :partitioned, phi: phi}) do
    Logger.warning(
      "[PartitionDetector] PARTITION peer=#{pid} #{from}→partitioned phi=#{Float.round(phi, 2)} — SC-SIL4-015"
    )
  end

  defp log_state_transition(%{peer_id: pid, from: from, to: :suspect, phi: phi}) do
    Logger.warning(
      "[PartitionDetector] SUSPECT peer=#{pid} #{from}→suspect phi=#{Float.round(phi, 2)}"
    )
  end

  defp log_state_transition(%{peer_id: pid, from: from, to: :alive}) do
    Logger.info("[PartitionDetector] RECOVERED peer=#{pid} #{from}→alive")
  end

  defp log_state_transition(_), do: :ok

  defp broadcast_state_change(new_peer_state, peer_id, phi, total, now) do
    event_name =
      case new_peer_state do
        :partitioned -> :peer_partitioned
        :suspect -> :peer_suspect
        :alive -> :peer_recovered
      end

    message = %{
      event: event_name,
      peer_id: peer_id,
      phi: phi,
      live_count: count_alive_peers(),
      total_count: total,
      timestamp: now
    }

    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:partition_event, message})
    rescue
      e -> Logger.debug("[PartitionDetector] PubSub broadcast failed: #{inspect(e)}")
    end
  end

  defp broadcast_split_brain(live_count, total, now) do
    message = %{
      event: :split_brain,
      peer_id: nil,
      phi: nil,
      live_count: live_count,
      total_count: total,
      timestamp: now
    }

    try do
      Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:partition_event, message})
    rescue
      e -> Logger.debug("[PartitionDetector] PubSub split_brain broadcast failed: #{inspect(e)}")
    end
  end

  defp emit_transition_telemetry(peer_id, new_peer_state, phi) do
    try do
      :telemetry.execute(
        [:indrajaal, :federation, :partition, new_peer_state],
        %{count: 1, phi: phi},
        %{peer_id: peer_id}
      )
    rescue
      e -> Logger.debug("[PartitionDetector] telemetry.execute failed: #{inspect(e)}")
    end
  end

  defp emit_split_brain_telemetry(live_count, total) do
    try do
      :telemetry.execute(
        [:indrajaal, :federation, :partition, :split_brain],
        %{count: 1, live_count: live_count, total_count: total},
        %{}
      )
    rescue
      e ->
        Logger.debug("[PartitionDetector] telemetry.execute split_brain failed: #{inspect(e)}")
    end
  end

  defp store_history_event(event_type, peer_id, phi, total, timestamp) do
    record = %{
      event: event_type,
      peer_id: peer_id,
      phi: phi,
      live_count: count_alive_peers(),
      total_count: total,
      timestamp: timestamp
    }

    key = {timestamp, :erlang.unique_integer([:monotonic])}
    :ets.insert(@ets_history, {key, record})
    trim_history()
  rescue
    _ -> :ok
  end

  defp trim_history do
    count = :ets.info(@ets_history, :size)

    if count > @history_max do
      case :ets.first(@ets_history) do
        :"$end_of_table" -> :ok
        oldest_key -> :ets.delete(@ets_history, oldest_key)
      end
    end
  rescue
    _ -> :ok
  end

  defp schedule_check do
    Process.send_after(self(), :scheduled_check, @check_interval_ms)
  end

  defp ensure_ets_tables do
    if :ets.whereis(@ets_peers) == :undefined do
      :ets.new(@ets_peers, [:named_table, :public, :set, write_concurrency: true])
    end

    if :ets.whereis(@ets_history) == :undefined do
      :ets.new(@ets_history, [:named_table, :public, :ordered_set, read_concurrency: true])
    end
  end
end
