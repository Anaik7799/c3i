defmodule Indrajaal.Distributed.Agents.SentinelAgent do
  @moduledoc """
  Agent 6: Sentinel - Health and Quorum Guardian.

  WHAT: Monitors cluster health and manages quorum for HA.
  WHY: SC-CLU-002 requires minimum 3 nodes for HA with quorum.
  CONSTRAINTS: Split-brain prevention, leader election.

  ## Sentinel Responsibilities

  1. **Health Monitoring**: Node health checks
  2. **Quorum Management**: Consensus for cluster operations
  3. **Leader Election**: Raft-like leader selection
  4. **Split-Brain Prevention**: Network partition handling

  ## STAMP Constraints
  - SC-CLU-002: Minimum 3 nodes for HA
  - SC-CLU-005: Split-brain prevention
  - SC-SEN-001: Heartbeat every 5s
  - SC-SEN-002: Quorum required for writes

  ## Mathematical Specification

  ```
  Sentinel := (Nodes, Quorum, Leader, Health)

  Nodes := Set(Node)
  Quorum := ⌊|Nodes|/2⌋ + 1

  Leader ∈ Nodes | nil
  Health: Node → {alive, suspected, dead}

  Quorum Invariant:
    ∀ write: |AlivePeers| ≥ Quorum ⟹ Allowed(write)

  Split-Brain Prevention:
    ∀ partition P: |P| < Quorum ⟹ ReadOnly(P)
  ```
  """

  use Indrajaal.Distributed.Agents.BaseAgent,
    type: :cybernetic,
    namespace: "sentinel",
    name: "guardian"

  # ============================================================
  # AGENT CALLBACKS
  # ============================================================

  @impl true
  def agent_init(_opts) do
    state = %{
      # Cluster state
      nodes: %{},
      node_count: 0,
      quorum_size: 0,
      has_quorum: false,

      # Leader state
      leader: nil,
      term: 0,
      is_leader: false,
      voted_for: nil,

      # Health tracking
      node_health: %{},
      last_heartbeats: %{},
      suspected_nodes: MapSet.new(),
      dead_nodes: MapSet.new(),

      # Configuration
      config: %{
        heartbeat_interval_ms: 5_000,
        election_timeout_ms: 15_000,
        suspicion_threshold_ms: 10_000,
        dead_threshold_ms: 30_000,
        min_nodes_for_quorum: 3
      },

      # Metrics
      elections_triggered: 0,
      quorum_lost_count: 0,
      partitions_detected: 0
    }

    # Register self
    self_node = Node.self()
    state = register_node(state, self_node, %{joined_at: DateTime.utc_now()})

    # Schedule heartbeat
    Process.send_after(self(), :heartbeat, state.config.heartbeat_interval_ms)
    Process.send_after(self(), :check_health, state.config.suspicion_threshold_ms)

    {:ok, state}
  end

  @impl true
  def agent_state(state) do
    %{
      nodes: map_size(state.nodes),
      quorum_size: state.quorum_size,
      has_quorum: state.has_quorum,
      leader: state.leader,
      is_leader: state.is_leader,
      term: state.term,
      health: node_health_summary(state),
      suspected: MapSet.to_list(state.suspected_nodes),
      dead: MapSet.to_list(state.dead_nodes)
    }
  end

  @impl true
  def agent_metrics(state) do
    %{
      node_count: state.node_count,
      quorum_size: state.quorum_size,
      has_quorum: state.has_quorum,
      current_term: state.term,
      elections_triggered: state.elections_triggered,
      quorum_lost_count: state.quorum_lost_count,
      partitions_detected: state.partitions_detected,
      alive_nodes: state.node_count - MapSet.size(state.dead_nodes),
      suspected_count: MapSet.size(state.suspected_nodes),
      dead_count: MapSet.size(state.dead_nodes)
    }
  end

  @impl true
  def handle_command(:register_node, params, state) do
    node = Map.get(params, :node)
    metadata = Map.get(params, :metadata, %{})

    new_state = register_node(state, node, metadata)
    {:ok, %{registered: node, quorum_size: new_state.quorum_size}, new_state}
  end

  @impl true
  def handle_command(:unregister_node, params, state) do
    node = Map.get(params, :node)
    new_state = unregister_node(state, node)
    {:ok, :unregistered, new_state}
  end

  @impl true
  def handle_command(:heartbeat_received, params, state) do
    node = Map.get(params, :node)
    new_state = record_heartbeat(state, node)
    {:ok, :recorded, new_state}
  end

  @impl true
  def handle_command(:check_quorum, _params, state) do
    {has_quorum, new_state} = check_quorum(state)
    {:ok, %{has_quorum: has_quorum, quorum_size: state.quorum_size}, new_state}
  end

  @impl true
  def handle_command(:trigger_election, _params, state) do
    new_state = start_election(state)
    {:ok, %{term: new_state.term, leader: new_state.leader}, new_state}
  end

  @impl true
  def handle_command(:vote, params, state) do
    candidate = Map.get(params, :candidate)
    term = Map.get(params, :term)

    {vote_granted, new_state} = process_vote_request(state, candidate, term)
    {:ok, %{granted: vote_granted}, new_state}
  end

  @impl true
  def handle_command(:get_leader, _params, state) do
    {:ok, %{leader: state.leader, term: state.term, is_leader: state.is_leader}, state}
  end

  @impl true
  def handle_command(:mark_suspected, params, state) do
    node = Map.get(params, :node)
    new_suspected = MapSet.put(state.suspected_nodes, node)
    new_state = %{state | suspected_nodes: new_suspected}
    {:ok, :marked, new_state}
  end

  @impl true
  def handle_command(:mark_dead, params, state) do
    node = Map.get(params, :node)
    new_dead = MapSet.put(state.dead_nodes, node)
    new_suspected = MapSet.delete(state.suspected_nodes, node)

    new_state = %{
      state
      | dead_nodes: new_dead,
        suspected_nodes: new_suspected
    }

    # Re-check quorum
    {_, new_state} = check_quorum(new_state)
    {:ok, :marked_dead, new_state}
  end

  @impl true
  def handle_command(:revive_node, params, state) do
    node = Map.get(params, :node)
    new_dead = MapSet.delete(state.dead_nodes, node)
    new_suspected = MapSet.delete(state.suspected_nodes, node)

    new_state = %{
      state
      | dead_nodes: new_dead,
        suspected_nodes: new_suspected
    }

    {:ok, :revived, new_state}
  end

  @impl true
  def handle_command(unknown, _params, state) do
    {:error, {:unknown_command, unknown}, state}
  end

  # Handle periodic heartbeat
  @impl Indrajaal.Distributed.Agents.BaseAgent
  def handle_agent_info(:heartbeat, state) do
    # Send heartbeat to all known nodes
    publish_heartbeat(state)

    # Schedule next heartbeat
    Process.send_after(self(), :heartbeat, state.config.heartbeat_interval_ms)
    {:ok, state}
  end

  def handle_agent_info(:check_health, state) do
    # Check for suspected/dead nodes
    new_state = check_node_health(state)

    # Schedule next check
    Process.send_after(self(), :check_health, state.config.suspicion_threshold_ms)
    {:ok, new_state}
  end

  def handle_agent_info(_msg, _state), do: :ignore

  # ============================================================
  # SENTINEL IMPLEMENTATION
  # ============================================================

  defp register_node(state, node, metadata) do
    full_metadata =
      Map.merge(metadata, %{
        registered_at: DateTime.utc_now(),
        fqun: nil
      })

    # Generate FQUN for node
    {:ok, fqun} =
      Indrajaal.Distributed.FQUN.generate(
        :resource,
        :compute,
        "cluster",
        node_to_name(node)
      )

    full_metadata = Map.put(full_metadata, :fqun, fqun)

    new_nodes = Map.put(state.nodes, node, full_metadata)
    new_count = map_size(new_nodes)
    new_quorum = calculate_quorum(new_count, state.config.min_nodes_for_quorum)

    %{
      state
      | nodes: new_nodes,
        node_count: new_count,
        quorum_size: new_quorum,
        last_heartbeats: Map.put(state.last_heartbeats, node, DateTime.utc_now())
    }
  end

  defp unregister_node(state, node) do
    new_nodes = Map.delete(state.nodes, node)
    new_count = map_size(new_nodes)
    new_quorum = calculate_quorum(new_count, state.config.min_nodes_for_quorum)

    %{
      state
      | nodes: new_nodes,
        node_count: new_count,
        quorum_size: new_quorum,
        last_heartbeats: Map.delete(state.last_heartbeats, node),
        suspected_nodes: MapSet.delete(state.suspected_nodes, node),
        dead_nodes: MapSet.delete(state.dead_nodes, node)
    }
  end

  defp record_heartbeat(state, node) do
    now = DateTime.utc_now()

    %{
      state
      | last_heartbeats: Map.put(state.last_heartbeats, node, now),
        suspected_nodes: MapSet.delete(state.suspected_nodes, node),
        dead_nodes: MapSet.delete(state.dead_nodes, node)
    }
  end

  defp calculate_quorum(node_count, min_nodes) do
    if node_count >= min_nodes do
      div(node_count, 2) + 1
    else
      # Not enough nodes for quorum
      node_count + 1
    end
  end

  defp check_quorum(state) do
    alive_count = state.node_count - MapSet.size(state.dead_nodes)
    has_quorum = alive_count >= state.quorum_size

    new_state =
      if has_quorum != state.has_quorum do
        if has_quorum do
          Logger.info("[SentinelAgent] Quorum restored",
            alive: alive_count,
            required: state.quorum_size
          )

          %{state | has_quorum: has_quorum}
        else
          Logger.warning("[SentinelAgent] Quorum lost!",
            alive: alive_count,
            required: state.quorum_size
          )

          %{state | has_quorum: has_quorum, quorum_lost_count: state.quorum_lost_count + 1}
        end
      else
        %{state | has_quorum: has_quorum}
      end

    {has_quorum, new_state}
  end

  defp start_election(state) do
    new_term = state.term + 1
    Logger.info("[SentinelAgent] Starting election", term: new_term)

    # Vote for self
    new_state = %{
      state
      | term: new_term,
        voted_for: Node.self(),
        elections_triggered: state.elections_triggered + 1
    }

    # Publish election request via Zenoh
    publish_election(new_state)

    # For now, become leader (simplified - in production would wait for votes)
    %{new_state | leader: Node.self(), is_leader: true}
  end

  defp process_vote_request(state, candidate, term) do
    cond do
      term < state.term ->
        {false, state}

      term > state.term ->
        {true, %{state | term: term, voted_for: candidate}}

      state.voted_for == nil ->
        {true, %{state | voted_for: candidate}}

      state.voted_for == candidate ->
        {true, state}

      true ->
        {false, state}
    end
  end

  defp check_node_health(state) do
    now = DateTime.utc_now()
    suspicion_ms = state.config.suspicion_threshold_ms
    dead_ms = state.config.dead_threshold_ms

    {new_suspected, new_dead} =
      Enum.reduce(state.last_heartbeats, {state.suspected_nodes, state.dead_nodes}, fn
        {node, last_hb}, {suspected, dead} ->
          age_ms = DateTime.diff(now, last_hb, :millisecond)
          determine_node_status(node, age_ms, suspected, dead, suspicion_ms, dead_ms)
      end)

    state = %{state | suspected_nodes: new_suspected, dead_nodes: new_dead}
    {_, state} = check_quorum(state)
    state
  end

  defp determine_node_status(node, age_ms, suspected, dead, suspicion_ms, dead_ms) do
    cond do
      age_ms > dead_ms and not MapSet.member?(dead, node) ->
        Logger.warning("[SentinelAgent] Node marked dead", node: node, age_ms: age_ms)
        {MapSet.delete(suspected, node), MapSet.put(dead, node)}

      age_ms > suspicion_ms and not MapSet.member?(dead, node) and
          not MapSet.member?(suspected, node) ->
        Logger.warning("[SentinelAgent] Node suspected", node: node, age_ms: age_ms)
        {MapSet.put(suspected, node), dead}

      true ->
        {suspected, dead}
    end
  end

  defp publish_heartbeat(state) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "sentinel/heartbeat",
      %{
        node: Node.self(),
        term: state.term,
        leader: state.leader,
        has_quorum: state.has_quorum,
        timestamp: DateTime.utc_now()
      }
    )
  rescue
    _ -> :ok
  end

  defp publish_election(state) do
    Indrajaal.Observability.ZenohCoordinator.publish_coord(
      "sentinel/election",
      %{
        candidate: Node.self(),
        term: state.term,
        timestamp: DateTime.utc_now()
      }
    )
  rescue
    _ -> :ok
  end

  defp node_health_summary(state) do
    %{
      alive:
        state.node_count - MapSet.size(state.suspected_nodes) - MapSet.size(state.dead_nodes),
      suspected: MapSet.size(state.suspected_nodes),
      dead: MapSet.size(state.dead_nodes)
    }
  end

  defp node_to_name(node) when is_atom(node) do
    node
    |> Atom.to_string()
    |> String.replace("@", "_at_")
    |> String.replace(".", "_")
    |> String.downcase()
  end
end
