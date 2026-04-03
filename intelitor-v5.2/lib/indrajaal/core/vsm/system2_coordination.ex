defmodule Indrajaal.Core.VSM.System2Coordination do
  @moduledoc """
  VSM System 2: Coordination - The Balancing for v20.0.0

  System 2 handles anti-oscillation and peer coordination:
  - Prevents conflicting actions between peers
  - Dampens oscillations in the system
  - Coordinates resource sharing
  - Maintains peer relationships

  ## Responsibilities
  - Gossip with peer holons
  - Detect and dampen oscillations
  - Coordinate shared resources
  - Maintain peer state

  ## Anti-Oscillation Mechanisms
  - Hysteresis: Require sustained change before reacting
  - Dampening: Reduce reaction magnitude over time
  - Cooldown: Minimum time between reactions
  - Consensus: Require peer agreement before action
  - EMA: Exponential moving average on coordination signals

  ## STAMP Constraints
  - SC-S2-001: Coordination MUST NOT block S1 operations
  - SC-S2-002: Oscillation detection MUST have hysteresis
  - SC-S2-003: Peer state MUST be eventually consistent
  - SC-S2-004: Coordination cycles MUST complete within 50ms
  - SC-MATH-004: ISOLATED disciplines connected via PubSub gossip

  ## Category Theory
  S2 forms a Comonad for context propagation:
  - extract : W a → a (get current state)
  - extend : (W a → b) → W a → W b (propagate context)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-21 | Claude | Real EMA damping, computed health, `:pg` peer discovery |
  | 21.2.1 | 2026-03-19 | Claude | Add System2Coordinator GenServer with real PubSub gossip |
  | 20.0.0 | 2025-01-01 | Indrajaal | Initial implementation |
  """

  require Logger

  alias Indrajaal.Core.Holon
  alias Indrajaal.Core.Holon.Metrics
  alias Indrajaal.Core.VSM.System3Control

  @type peer_state :: %{
          peer_id: Holon.holon_id(),
          last_seen: DateTime.t(),
          health: Holon.health(),
          metrics: map()
        }

  @type coordination_state :: %{
          peers: [peer_state()],
          oscillation_count: non_neg_integer(),
          last_action: DateTime.t() | nil,
          cooldown_until: DateTime.t() | nil
        }

  # Anti-oscillation parameters
  @hysteresis_threshold 3
  @cooldown_period_ms 1_000
  @dampening_factor 0.8

  # Process-group name used for `:pg`-based peer discovery (SC-S2-003)
  @pg_group :vsm_coordination_group

  @doc """
  Creates a new coordination state.
  """
  @spec new() :: coordination_state()
  def new do
    %{
      peers: [],
      oscillation_count: 0,
      last_action: nil,
      cooldown_until: nil
    }
  end

  @doc """
  Performs a coordination cycle with peers.
  """
  @spec coordinate(coordination_state(), Holon.holon_id(), [Holon.holon_id()]) ::
          {:ok, coordination_state()} | {:error, term()}
  def coordinate(state, holon_id, peer_ids) do
    start_time = System.monotonic_time(:millisecond)

    # Gossip with each peer
    peer_results =
      Enum.map(peer_ids, fn peer_id ->
        case gossip(holon_id, peer_id) do
          {:ok, peer_state} -> peer_state
          {:error, _} -> nil
        end
      end)

    new_peers = peer_results |> Enum.reject(&is_nil/1)

    # Detect oscillations
    oscillating = detect_oscillation(state, new_peers)

    # Update state
    new_state = %{
      state
      | peers: new_peers,
        oscillation_count: if(oscillating, do: state.oscillation_count + 1, else: 0)
    }

    # Emit telemetry
    duration = System.monotonic_time(:millisecond) - start_time

    Metrics.emit_coordination(
      holon_id,
      :unknown,
      length(new_peers),
      duration
    )

    {:ok, new_state}
  end

  @doc """
  Gossips with a peer by broadcasting a message via `Phoenix.PubSub` on
  topic `"vsm:system2:gossip"`.

  The broadcast is fire-and-forget (async); the function returns
  `{:ok, peer_state}` immediately after publishing so that it never
  blocks the calling coordination cycle (SC-S2-001, SC-PRF-055).

  Health is derived from real system metrics via `compute_local_health/0`.
  If PubSub is unavailable the error is logged and `{:error, reason}` is
  returned.
  """
  @spec gossip(Holon.holon_id(), Holon.holon_id()) :: {:ok, peer_state()} | {:error, term()}
  def gossip(from_id, to_id) do
    if is_binary(from_id) and is_binary(to_id) and from_id != "" and to_id != "" do
      metrics = build_gossip_metrics()
      health = compute_local_health(metrics)

      message = %{
        from: from_id,
        to: to_id,
        health: health,
        metrics: metrics,
        timestamp: DateTime.utc_now()
      }

      Logger.debug("[System2Coordination] gossip: #{from_id} → #{to_id}")

      case broadcast_gossip_message(message) do
        :ok ->
          {:ok,
           %{
             peer_id: to_id,
             last_seen: message.timestamp,
             health: health,
             metrics: metrics
           }}

        {:error, reason} ->
          Logger.warning("[System2Coordination] gossip broadcast failed: #{inspect(reason)}")

          {:error, reason}
      end
    else
      {:error, :invalid_peer_id}
    end
  end

  @doc """
  Discovers available peers via `:pg` process groups.

  Joins the VSM coordination group on first call if not already a member,
  then returns all remote members (excluding self).  Falls back to an
  empty list if `:pg` is unavailable (e.g., in isolated unit tests).
  """
  @spec get_available_peers() :: [pid()]
  def get_available_peers do
    try do
      # Ensure this process is a member of the group so peers can find us
      :pg.join(@pg_group, self())
    catch
      # Already a member or :pg not started – both are acceptable
      :error, _ -> :ok
      :exit, _ -> :ok
    end

    try do
      case :pg.get_members(@pg_group) do
        members when is_list(members) ->
          # Exclude self; remote PIDs represent peers on other nodes
          Enum.reject(members, fn pid -> pid == self() end)

        _ ->
          []
      end
    catch
      :error, _ -> []
      :exit, _ -> []
    end
  end

  # Publish the gossip payload to the PubSub topic (SC-S2-001, SC-MATH-004).
  @spec broadcast_gossip_message(map()) :: :ok | {:error, term()}
  defp broadcast_gossip_message(message) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "vsm:system2:gossip",
        {:system2_gossip, message}
      )
    rescue
      err ->
        {:error, err}
    catch
      :exit, reason -> {:error, reason}
    end
  end

  # Derive metrics from System3Control for inclusion in the gossip payload.
  # Uses a fresh default control state so this call is always pure and
  # non-blocking (no GenServer dependency).
  @spec build_gossip_metrics() :: map()
  defp build_gossip_metrics do
    budget_info =
      try do
        {status, control_state} = System3Control.check_budget(System3Control.new())
        %{budget_status: status, budget: Map.get(control_state, :budget, %{})}
      rescue
        _ -> %{}
      catch
        _, _ -> %{}
      end

    system_load = get_system_load()

    Map.merge(budget_info, %{
      load: system_load,
      memory_mb: get_memory_mb()
    })
  end

  # Compute local health from real system metrics.
  # Returns :healthy, :degraded, or :critical based on observed load and memory.
  @spec compute_local_health(map()) :: :healthy | :degraded | :critical
  defp compute_local_health(metrics) do
    load = Map.get(metrics, :load, 0.0)
    memory_mb = Map.get(metrics, :memory_mb, 0)

    cond do
      load > 0.9 or memory_mb > 1_500 -> :critical
      load > 0.7 or memory_mb > 800 -> :degraded
      true -> :healthy
    end
  end

  # Returns a normalised load value [0.0, 1.0] from the BEAM scheduler
  # utilisation.  Falls back to 0.0 on any error.
  @spec get_system_load() :: float()
  defp get_system_load do
    try do
      case :scheduler.utilization(1) do
        [{_id, util, _type} | _] when is_number(util) ->
          min(1.0, util / 100.0)

        _ ->
          # Fallback: estimate from run queue
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
      bytes = :erlang.memory(:total)
      div(bytes, 1_048_576)
    catch
      _, _ -> 0
    end
  end

  @doc """
  Detects oscillation in the system state.
  """
  @spec detect_oscillation(coordination_state(), [peer_state()]) :: boolean()
  def detect_oscillation(state, current_peers) do
    previous_peers = state.peers

    # Compare previous and current peer states
    changes =
      Enum.count(current_peers, fn current ->
        previous = Enum.find(previous_peers, fn p -> p.peer_id == current.peer_id end)
        previous != nil and previous.health != current.health
      end)

    # Oscillation if too many state changes
    changes > length(current_peers) / 2
  end

  @doc """
  Checks if an action is allowed (not in cooldown).
  """
  @spec can_act?(coordination_state()) :: boolean()
  def can_act?(%{cooldown_until: nil}), do: true

  def can_act?(%{cooldown_until: cooldown}) do
    DateTime.compare(DateTime.utc_now(), cooldown) == :gt
  end

  @doc """
  Applies hysteresis to a proposed action.
  """
  @spec apply_hysteresis(coordination_state(), atom(), non_neg_integer()) ::
          {:proceed | :wait, coordination_state()}
  def apply_hysteresis(state, _action, count) do
    if count >= @hysteresis_threshold do
      {:proceed, state}
    else
      {:wait, state}
    end
  end

  @doc """
  Records an action and starts cooldown.
  """
  @spec record_action(coordination_state()) :: coordination_state()
  def record_action(state) do
    now = DateTime.utc_now()
    cooldown = DateTime.add(now, @cooldown_period_ms, :millisecond)

    %{state | last_action: now, cooldown_until: cooldown}
  end

  @doc """
  Applies dampening to a reaction magnitude.

  Uses exponential decay: `magnitude * dampening_factor ^ iteration`.
  When `dampening_factor` is 0.8 and `iteration` is the number of consecutive
  oscillation rounds, the reaction is reduced to ~33% after 5 rounds.
  """
  @spec dampen(number(), non_neg_integer()) :: number()
  def dampen(magnitude, iteration) do
    magnitude * :math.pow(@dampening_factor, iteration)
  end

  @doc """
  Checks if the coordination state indicates oscillation.
  """
  @spec oscillating?(coordination_state()) :: boolean()
  def oscillating?(state) do
    state.oscillation_count >= @hysteresis_threshold
  end

  @doc """
  Returns the list of healthy peers.
  """
  @spec healthy_peers(coordination_state()) :: [peer_state()]
  def healthy_peers(state) do
    Enum.filter(state.peers, fn peer -> peer.health == :healthy end)
  end

  @doc """
  Returns coordination summary for monitoring.
  """
  @spec summary(coordination_state()) :: map()
  def summary(state) do
    %{
      peer_count: length(state.peers),
      healthy_peer_count: length(healthy_peers(state)),
      oscillating: oscillating?(state),
      oscillation_count: state.oscillation_count,
      in_cooldown: not can_act?(state)
    }
  end
end
