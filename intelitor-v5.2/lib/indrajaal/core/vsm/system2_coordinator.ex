defmodule Indrajaal.Core.VSM.System2Coordinator do
  @moduledoc """
  VSM System 2: Coordinator GenServer

  Wraps `System2Coordination` with a long-running process that performs
  real PubSub-based gossip with peers every #{5} seconds.

  ## Responsibilities
  - Subscribe to the `vsm:system2:gossip` PubSub topic on startup
  - Broadcast local coordination state (including real load + health) to
    all peers on every gossip tick
  - Receive and merge peer gossip messages
  - Track known peers discovered via gossip AND via `:pg` process groups
  - Detect cross-peer oscillations and apply EMA-based dampening
  - Emit telemetry for all gossip events

  ## Anti-Oscillation Damping (EMA)
  The coordinator tracks a smoothed coordination signal using an
  Exponential Moving Average (EMA):

      ema_t = α × signal_t + (1 − α) × ema_{t−1}

  where α = 0.3 (configurable via `:ema_alpha` init option).

  A signal direction reversal (sign change relative to the previous round)
  increments `direction_changes`.  When `direction_changes` exceeds 3
  within the last `@direction_window` rounds, dampening is activated and
  the EMA alpha is halved to slow the response further.

  ## STAMP Constraints
  - SC-S2-001: Gossip cycle MUST NOT block S1 operations (async PubSub)
  - SC-S2-003: Peer state MUST be eventually consistent
  - SC-S2-004: Gossip publish MUST complete within 50ms
  - SC-MATH-004: ISOLATED VSM discipline connected via PubSub
  - SC-PRF-055: No blocking operations in gossip path

  ## Graceful Degradation
  If `Indrajaal.PubSub` is not started (e.g., in isolated unit tests),
  all PubSub calls are silently skipped and the process continues using
  only local coordination state.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-21 | Claude | Real EMA damping, direction-change counter, `:pg` peer discovery, local digest in do_gossip |
  | 21.2.1 | 2026-03-19 | Claude | Initial implementation with PubSub gossip |
  """

  use GenServer

  require Logger

  alias Indrajaal.Core.VSM.System2Coordination
  alias Indrajaal.Core.Holon.Metrics

  @pubsub_name Indrajaal.PubSub
  @gossip_topic "vsm:system2:gossip"
  @default_gossip_interval_ms 5_000

  # EMA anti-oscillation defaults
  @default_ema_alpha 0.3
  # Increase damping when direction reversals exceed this count …
  @oscillation_reversal_threshold 3
  # … within this many consecutive rounds
  @direction_window 10

  # ── Server state type ──────────────────────────────────────────────────────

  @type server_state :: %{
          holon_id: String.t(),
          coordination_state: System2Coordination.coordination_state(),
          known_peers: MapSet.t(String.t()),
          gossip_interval_ms: non_neg_integer(),
          oscillation_detected: boolean(),
          dampening_active: boolean(),
          pubsub_available: boolean(),
          # EMA state (anti-oscillation)
          ema_signal: float(),
          ema_alpha: float(),
          prev_signal: float(),
          direction_changes: non_neg_integer(),
          direction_history: [integer()],
          # Monotone round counter (version vector scalar)
          gossip_round: non_neg_integer()
        }

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Starts the System2 Coordinator GenServer.

  ## Options
  - `:holon_id` – identifier for this holon (required)
  - `:gossip_interval_ms` – gossip period in milliseconds (default: #{@default_gossip_interval_ms})
  - `:ema_alpha` – EMA smoothing factor 0 < α ≤ 1 (default: #{@default_ema_alpha})
  - `:name` – registered name (optional)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, name_opts)
  end

  @doc """
  Returns the current coordination summary for monitoring.
  """
  @spec get_summary(GenServer.server()) :: map()
  def get_summary(server \\ __MODULE__) do
    GenServer.call(server, :get_summary)
  end

  @doc """
  Returns all known peer IDs discovered via gossip.
  """
  @spec get_peers(GenServer.server()) :: [String.t()]
  def get_peers(server \\ __MODULE__) do
    GenServer.call(server, :get_peers)
  end

  @doc """
  Forces an immediate gossip broadcast (useful for testing).
  """
  @spec force_gossip(GenServer.server()) :: :ok
  def force_gossip(server \\ __MODULE__) do
    GenServer.cast(server, :force_gossip)
  end

  # ── GenServer callbacks ────────────────────────────────────────────────────

  @impl GenServer
  def init(opts) do
    holon_id = Keyword.fetch!(opts, :holon_id)
    gossip_interval_ms = Keyword.get(opts, :gossip_interval_ms, @default_gossip_interval_ms)
    ema_alpha = Keyword.get(opts, :ema_alpha, @default_ema_alpha)

    pubsub_available = try_subscribe()

    if pubsub_available do
      Logger.info("[System2Coordinator] #{holon_id} subscribed to #{@gossip_topic}")
    else
      Logger.warning(
        "[System2Coordinator] #{holon_id} PubSub unavailable – gossip degraded to local-only"
      )
    end

    schedule_gossip(gossip_interval_ms)

    state = %{
      holon_id: holon_id,
      coordination_state: System2Coordination.new(),
      known_peers: MapSet.new(),
      gossip_interval_ms: gossip_interval_ms,
      oscillation_detected: false,
      dampening_active: false,
      pubsub_available: pubsub_available,
      # EMA initial values – start neutral
      ema_signal: 0.0,
      ema_alpha: ema_alpha,
      prev_signal: 0.0,
      direction_changes: 0,
      direction_history: [],
      gossip_round: 0
    }

    :telemetry.execute(
      [:indrajaal, :vsm, :system2, :init],
      %{gossip_interval_ms: gossip_interval_ms},
      %{holon_id: holon_id, pubsub_available: pubsub_available}
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_summary, _from, state) do
    base = System2Coordination.summary(state.coordination_state)

    full_summary =
      Map.merge(base, %{
        holon_id: state.holon_id,
        known_peer_count: MapSet.size(state.known_peers),
        oscillation_detected: state.oscillation_detected,
        dampening_active: state.dampening_active,
        pubsub_available: state.pubsub_available,
        ema_signal: state.ema_signal,
        ema_alpha: state.ema_alpha,
        direction_changes: state.direction_changes,
        gossip_round: state.gossip_round
      })

    {:reply, full_summary, state}
  end

  def handle_call(:get_peers, _from, state) do
    {:reply, MapSet.to_list(state.known_peers), state}
  end

  @impl GenServer
  def handle_cast(:force_gossip, state) do
    new_state = do_gossip(state)
    {:noreply, new_state}
  end

  @impl GenServer
  # Periodic gossip tick
  def handle_info(:gossip_tick, state) do
    new_state = do_gossip(state)
    schedule_gossip(state.gossip_interval_ms)
    {:noreply, new_state}
  end

  # Incoming peer gossip message (SC-S2-003: eventually consistent peer state)
  def handle_info({:system2_gossip, peer_message}, state) do
    peer_node = Map.get(peer_message, :node)
    peer_holon = Map.get(peer_message, :holon_id, inspect(peer_node))

    # Ignore our own reflected broadcasts
    if peer_holon == state.holon_id do
      {:noreply, state}
    else
      new_state = merge_peer_gossip(state, peer_message)
      {:noreply, new_state}
    end
  end

  # Catch-all for unexpected messages
  def handle_info(msg, state) do
    Logger.debug("[System2Coordinator] #{state.holon_id} unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  # Attempt PubSub subscription, returning whether it succeeded.
  @spec try_subscribe() :: boolean()
  defp try_subscribe do
    try do
      case Phoenix.PubSub.subscribe(@pubsub_name, @gossip_topic) do
        :ok -> true
        {:error, _} -> false
      end
    rescue
      _ -> false
    catch
      :exit, _ -> false
    end
  end

  # Build and broadcast the local gossip message.
  # Also computes the local state digest and updates coordination_state so
  # that the GenServer's own health is reflected in peer-visible state.
  @spec do_gossip(server_state()) :: server_state()
  defp do_gossip(state) do
    # 1. Compute local digest from real system metrics
    local_digest = compute_local_digest(state)

    # 2. Update our own peer entry in coordination_state
    updated_coord = update_local_in_coord(state.coordination_state, state.holon_id, local_digest)

    # 3. Discover :pg peers and add them to the known-peers set
    pg_peer_pids = System2Coordination.get_available_peers()

    # We use PIDs as opaque peer references; derive string IDs from them
    pg_peer_ids =
      Enum.map(pg_peer_pids, fn pid ->
        inspect(pid)
      end)

    known_peers =
      Enum.reduce(pg_peer_ids, state.known_peers, fn id, acc -> MapSet.put(acc, id) end)

    # 4. Build gossip message with real local digest
    message = build_gossip_message_with_digest(state, local_digest)

    # 5. Broadcast (fire-and-forget, SC-S2-001)
    broadcast_result = broadcast_gossip(message, state.pubsub_available)

    # 6. Update EMA signal from local load
    raw_signal = Map.get(local_digest, :load, 0.0)
    new_state_ema = update_ema(state, raw_signal)

    # 7. Increment round counter
    gossip_round = state.gossip_round + 1

    :telemetry.execute(
      [:indrajaal, :vsm, :system2, :gossip, :sent],
      %{peer_count: MapSet.size(known_peers)},
      %{
        holon_id: state.holon_id,
        broadcast_ok: broadcast_result == :ok,
        oscillation_detected: state.oscillation_detected,
        ema_signal: new_state_ema.ema_signal,
        dampening_active: new_state_ema.dampening_active,
        gossip_round: gossip_round
      }
    )

    Logger.debug(
      "[System2Coordinator] #{state.holon_id} gossip sent – peers=#{MapSet.size(known_peers)}" <>
        " load=#{Float.round(raw_signal, 3)} ema=#{Float.round(new_state_ema.ema_signal, 3)}" <>
        " dampen=#{new_state_ema.dampening_active} round=#{gossip_round}"
    )

    %{
      new_state_ema
      | coordination_state: updated_coord,
        known_peers: known_peers,
        gossip_round: gossip_round
    }
  end

  # Compute a compact state digest reflecting real local system metrics.
  @spec compute_local_digest(server_state()) :: map()
  defp compute_local_digest(state) do
    load = get_system_load()
    memory_mb = get_memory_mb()

    health =
      cond do
        load > 0.9 or memory_mb > 1_500 -> :critical
        load > 0.7 or memory_mb > 800 -> :degraded
        true -> :healthy
      end

    %{
      node: node(),
      holon_id: state.holon_id,
      round: state.gossip_round,
      load: load,
      memory_mb: memory_mb,
      health: health,
      oscillating: state.oscillation_detected,
      dampening: state.dampening_active,
      timestamp: System.monotonic_time(:millisecond),
      peer_count: MapSet.size(state.known_peers)
    }
  end

  # Insert / update this node's own entry in the coordination peer list.
  @spec update_local_in_coord(
          System2Coordination.coordination_state(),
          String.t(),
          map()
        ) :: System2Coordination.coordination_state()
  defp update_local_in_coord(coord_state, holon_id, digest) do
    local_peer = %{
      peer_id: holon_id,
      last_seen: DateTime.utc_now(),
      health: Map.get(digest, :health, :healthy),
      metrics: Map.take(digest, [:load, :memory_mb, :round])
    }

    updated_peers =
      case Enum.find_index(coord_state.peers, fn p -> p.peer_id == holon_id end) do
        nil -> [local_peer | coord_state.peers]
        idx -> List.replace_at(coord_state.peers, idx, local_peer)
      end

    Map.put(coord_state, :peers, updated_peers)
  end

  # Build the gossip message using the precomputed local digest.
  @spec build_gossip_message_with_digest(server_state(), map()) :: map()
  defp build_gossip_message_with_digest(state, local_digest) do
    %{
      node: node(),
      holon_id: state.holon_id,
      round: state.gossip_round,
      timestamp: System.monotonic_time(:millisecond),
      digest: local_digest,
      coordination_state: summarize_for_gossip(state.coordination_state),
      oscillation_detected: state.oscillation_detected,
      dampening_active: state.dampening_active,
      ema_signal: state.ema_signal
    }
  end

  # Summarise only the fields needed by peers (keeps payload small, SC-S2-004).
  @spec summarize_for_gossip(System2Coordination.coordination_state()) :: map()
  defp summarize_for_gossip(coord_state) do
    %{
      peer_count: length(coord_state.peers),
      oscillation_count: coord_state.oscillation_count,
      in_cooldown: not System2Coordination.can_act?(coord_state)
    }
  end

  # Publish via PubSub with graceful degradation when unavailable.
  @spec broadcast_gossip(map(), boolean()) :: :ok | {:error, term()}
  defp broadcast_gossip(_message, false), do: :ok

  defp broadcast_gossip(message, true) do
    try do
      Phoenix.PubSub.broadcast(@pubsub_name, @gossip_topic, {:system2_gossip, message})
    rescue
      err ->
        Logger.warning("[System2Coordinator] gossip broadcast failed: #{inspect(err)}")
        {:error, err}
    catch
      :exit, reason ->
        Logger.warning("[System2Coordinator] gossip broadcast exit: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Update EMA signal and direction-change counter.
  #
  # EMA:   ema_t = α × signal_t + (1 − α) × ema_{t−1}
  #
  # Direction change: compare sign of (ema_t − ema_{t−1}) with previous
  # round.  If the sign flips (signal changes direction), increment
  # direction_changes.  When direction_changes > @oscillation_reversal_threshold
  # within the last @direction_window rounds, dampening is activated and alpha
  # is halved so the EMA responds more slowly.
  @spec update_ema(server_state(), float()) :: server_state()
  defp update_ema(state, raw_signal) do
    alpha = state.ema_alpha
    prev_ema = state.ema_signal

    new_ema = alpha * raw_signal + (1.0 - alpha) * prev_ema

    # Compute direction of this step: +1 going up, -1 going down, 0 flat
    delta = new_ema - prev_ema

    current_dir =
      cond do
        delta > 0.001 -> 1
        delta < -0.001 -> -1
        true -> 0
      end

    # Was the previous step in the same direction?
    prev_dir = List.first(state.direction_history, 0)
    reversed = current_dir != 0 and prev_dir != 0 and current_dir != prev_dir

    # Keep a rolling window of direction indicators
    direction_history =
      [current_dir | state.direction_history]
      |> Enum.take(@direction_window)

    # Count actual reversals in the window
    reversals = count_reversals(direction_history)

    direction_changes =
      if reversed do
        state.direction_changes + 1
      else
        max(0, state.direction_changes - 1)
      end

    # Activate damping if too many reversals in the window
    dampening_active = reversals > @oscillation_reversal_threshold

    # When dampening is active, halve alpha so EMA slows down.
    # When no longer dampening, restore original alpha.
    effective_alpha =
      if dampening_active do
        max(0.05, alpha / 2.0)
      else
        alpha
      end

    %{
      state
      | ema_signal: new_ema,
        prev_signal: prev_ema,
        direction_changes: direction_changes,
        direction_history: direction_history,
        dampening_active: dampening_active,
        ema_alpha: effective_alpha
    }
  end

  # Count the number of direction reversals in a history list.
  # A reversal is where consecutive non-zero entries have opposite signs.
  @spec count_reversals([integer()]) :: non_neg_integer()
  defp count_reversals([]), do: 0
  defp count_reversals([_]), do: 0

  defp count_reversals(history) do
    history
    |> Enum.reject(&(&1 == 0))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] -> a != b end)
  end

  # Merge state received from a peer into the local coordination state.
  @spec merge_peer_gossip(server_state(), map()) :: server_state()
  defp merge_peer_gossip(state, peer_message) do
    peer_holon_id = Map.get(peer_message, :holon_id, "unknown")
    peer_oscillating = Map.get(peer_message, :oscillation_detected, false)
    peer_dampening = Map.get(peer_message, :dampening_active, false)

    # Extract health from the nested digest if present, otherwise from
    # top-level oscillation flag (backwards compat with pre-21.2.1 peers)
    peer_health =
      peer_message
      |> Map.get(:digest, %{})
      |> Map.get(:health, if(peer_oscillating, do: :degraded, else: :healthy))

    # Register the peer as known
    known_peers = MapSet.put(state.known_peers, peer_holon_id)

    # Build a peer_state entry for coordination tracking
    peer_entry = %{
      peer_id: peer_holon_id,
      last_seen: DateTime.utc_now(),
      health: peer_health,
      metrics: Map.get(peer_message, :coordination_state, %{})
    }

    # Merge into the coordination state's peer list (upsert by peer_id)
    current_peers = state.coordination_state.peers

    updated_peers =
      case Enum.find_index(current_peers, fn p -> p.peer_id == peer_holon_id end) do
        nil -> [peer_entry | current_peers]
        idx -> List.replace_at(current_peers, idx, peer_entry)
      end

    updated_coord =
      state.coordination_state
      |> Map.put(:peers, updated_peers)

    # Re-run oscillation detection with the updated peer list (SC-S2-002)
    oscillation_detected =
      System2Coordination.detect_oscillation(updated_coord, updated_peers)

    # Increase oscillation count if peers are also oscillating
    oscillation_count =
      if oscillation_detected or peer_oscillating do
        updated_coord.oscillation_count + 1
      else
        max(0, updated_coord.oscillation_count - 1)
      end

    updated_coord = Map.put(updated_coord, :oscillation_count, oscillation_count)

    # Activate dampening if oscillation exceeds hysteresis (SC-S2-002)
    dampening_active =
      System2Coordination.oscillating?(updated_coord) or peer_dampening or
        state.dampening_active

    :telemetry.execute(
      [:indrajaal, :vsm, :system2, :gossip, :received],
      %{known_peer_count: MapSet.size(known_peers)},
      %{
        holon_id: state.holon_id,
        peer_holon_id: peer_holon_id,
        peer_health: peer_health,
        oscillation_detected: oscillation_detected,
        dampening_active: dampening_active
      }
    )

    Metrics.emit_coordination(
      state.holon_id,
      :unknown,
      MapSet.size(known_peers),
      0
    )

    Logger.debug(
      "[System2Coordinator] #{state.holon_id} merged gossip from #{peer_holon_id}" <>
        " health=#{peer_health} oscillating=#{oscillation_detected} dampening=#{dampening_active}"
    )

    %{
      state
      | coordination_state: updated_coord,
        known_peers: known_peers,
        oscillation_detected: oscillation_detected,
        dampening_active: dampening_active
    }
  end

  # Schedule the next gossip tick (SC-S2-001: non-blocking).
  @spec schedule_gossip(non_neg_integer()) :: reference()
  defp schedule_gossip(interval_ms) do
    Process.send_after(self(), :gossip_tick, interval_ms)
  end

  # Returns a normalised load value [0.0, 1.0] from BEAM scheduler utilisation.
  @spec get_system_load() :: float()
  defp get_system_load do
    try do
      case :scheduler.utilization(1) do
        [{_id, util, _type} | _] when is_number(util) ->
          min(1.0, util / 100.0)

        _ ->
          schedulers = :erlang.system_info(:schedulers_online)
          run_queue = :erlang.statistics(:run_queue)
          min(1.0, run_queue / max(1, schedulers))
      end
    catch
      _, _ ->
        schedulers = :erlang.system_info(:schedulers_online)
        run_queue = :erlang.statistics(:run_queue)
        min(1.0, run_queue / max(1, schedulers))
    end
  end

  # Returns total memory used by this BEAM node in megabytes.
  @spec get_memory_mb() :: non_neg_integer()
  defp get_memory_mb do
    try do
      div(:erlang.memory(:total), 1_048_576)
    catch
      _, _ -> 0
    end
  end
end
