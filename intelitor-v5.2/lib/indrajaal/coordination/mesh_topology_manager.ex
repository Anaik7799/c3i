defmodule Indrajaal.Coordination.MeshTopologyManager do
  @moduledoc """
  Mesh Topology Manager — L5 Coordination Layer

  Maintains an authoritative view of the mesh network topology including:
  - Node join/leave events via Phoenix PubSub subscription
  - Adjacency matrix stored in ETS for O(1) lookup
  - Dijkstra shortest-path routing calculation
  - Network partition detection via connectivity analysis

  ## STAMP Constraints
  - SC-DIST-001: FQUN-based node identification MANDATORY
  - SC-DIST-002: Node registry MUST be distributed
  - SC-DIST-003: Network partitions MUST be detected within 5s
  - SC-HA-003: Zenoh 2oo3 quorum in HA configuration
  - SC-ORCH-010: Service health monitored continuously

  ## Topology Data Model
  - Nodes identified by FQUN (Fully Qualified Unit Name)
  - Edges represent active communication channels with latency weights
  - Partitions detected when connected component count > 1

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation (L5 morphogenesis) |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @nodes_table :mesh_topology_nodes
  @edges_table :mesh_topology_edges
  @check_interval_ms 5_000
  @pubsub_topic "mesh:topology"
  @infinity 999_999_999

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type node_id :: String.t()
  @type weight :: non_neg_integer()
  @type path :: [node_id()]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a node joining the mesh."
  @spec node_join(node_id(), map()) :: :ok
  def node_join(node_id, metadata \\ %{}) do
    GenServer.cast(@name, {:node_join, node_id, metadata})
  end

  @doc "Register a node leaving the mesh."
  @spec node_leave(node_id()) :: :ok
  def node_leave(node_id) do
    GenServer.cast(@name, {:node_leave, node_id})
  end

  @doc "Register or update a directed edge with a latency weight."
  @spec set_edge(node_id(), node_id(), weight()) :: :ok
  def set_edge(from, to, weight \\ 1) do
    GenServer.cast(@name, {:set_edge, from, to, weight})
  end

  @doc "Remove an edge between two nodes."
  @spec remove_edge(node_id(), node_id()) :: :ok
  def remove_edge(from, to) do
    GenServer.cast(@name, {:remove_edge, from, to})
  end

  @doc "Compute the shortest path between two nodes (Dijkstra)."
  @spec shortest_path(node_id(), node_id()) :: {:ok, path(), weight()} | {:error, :no_path}
  def shortest_path(source, target) do
    GenServer.call(@name, {:shortest_path, source, target})
  end

  @doc "Detect network partitions — returns list of connected components."
  @spec partitions() :: [[node_id()]]
  def partitions do
    GenServer.call(@name, :partitions)
  end

  @doc "Returns all nodes currently in the mesh."
  @spec nodes() :: [node_id()]
  def nodes do
    :ets.match_object(@nodes_table, {:"$1", :"$2"})
    |> Enum.map(fn {id, _meta} -> id end)
  rescue
    _ -> []
  end

  @doc "Returns all edges as {from, to, weight} tuples."
  @spec edges() :: [{node_id(), node_id(), weight()}]
  def edges do
    :ets.match_object(@edges_table, {:"$1", :"$2", :"$3"})
    |> Enum.map(fn {from, to, weight} -> {from, to, weight} end)
  rescue
    _ -> []
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    :ets.new(@nodes_table, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(@edges_table, [:named_table, :public, :bag, read_concurrency: true])

    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cluster:membership")

    schedule_partition_check()

    Logger.info("[MeshTopologyManager] Started [SC-DIST-001]")

    {:ok, %{partition_count: 1}}
  end

  @impl true
  def handle_cast({:node_join, node_id, metadata}, state) do
    :ets.insert(@nodes_table, {node_id, metadata})
    broadcast_topology_change(:node_join, node_id)

    Logger.debug("[MeshTopologyManager] Node joined: #{node_id} [SC-DIST-001]")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:node_leave, node_id}, state) do
    :ets.delete(@nodes_table, node_id)
    remove_all_edges_for_node(node_id)
    broadcast_topology_change(:node_leave, node_id)

    Logger.debug("[MeshTopologyManager] Node left: #{node_id} [SC-DIST-001]")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_edge, from, to, weight}, state) do
    :ets.delete_object(@edges_table, {from, to, :_})
    :ets.match_delete(@edges_table, {from, to, :"$1"})
    :ets.insert(@edges_table, {from, to, weight})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove_edge, from, to}, state) do
    :ets.match_delete(@edges_table, {from, to, :"$1"})

    {:noreply, state}
  end

  @impl true
  def handle_call({:shortest_path, source, target}, _from, state) do
    result = dijkstra(source, target)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:partitions, _from, state) do
    components = find_connected_components()
    {:reply, components, state}
  end

  @impl true
  def handle_info(:check_partitions, state) do
    components = find_connected_components()
    count = length(components)

    if count > 1 do
      Logger.warning(
        "[MeshTopologyManager] PARTITION DETECTED: #{count} components [SC-DIST-003]"
      )

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:partition_detected, %{component_count: count, components: components}}
      )
    end

    schedule_partition_check()

    {:noreply, %{state | partition_count: count}}
  end

  @impl true
  def handle_info({:cluster_event, event}, state) do
    case event do
      {:node_up, node_id} -> node_join(node_id, %{})
      {:node_down, node_id} -> node_leave(node_id)
      _ -> :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Dijkstra Implementation
  # ---------------------------------------------------------------------------

  defp dijkstra(source, target) do
    all_nodes =
      :ets.match_object(@nodes_table, {:"$1", :"$2"})
      |> Enum.map(fn {id, _} -> id end)

    if source not in all_nodes or target not in all_nodes do
      {:error, :no_path}
    else
      dist = Map.new(all_nodes, fn n -> {n, if(n == source, do: 0, else: @infinity)} end)
      prev = Map.new(all_nodes, fn n -> {n, nil} end)
      unvisited = MapSet.new(all_nodes)

      result = dijkstra_loop(dist, prev, unvisited, target)

      case result do
        {:ok, final_dist, final_prev} ->
          if final_dist[target] == @infinity do
            {:error, :no_path}
          else
            path = reconstruct_path(final_prev, source, target)
            {:ok, path, final_dist[target]}
          end

        {:error, _} = err ->
          err
      end
    end
  end

  defp dijkstra_loop(dist, prev, unvisited, target) do
    if Enum.empty?(unvisited) do
      {:ok, dist, prev}
    else
      {current, current_dist} =
        unvisited
        |> Enum.map(fn n -> {n, Map.get(dist, n, @infinity)} end)
        |> Enum.min_by(fn {_, d} -> d end)

      if current_dist == @infinity do
        {:ok, dist, prev}
      else
        if current == target do
          {:ok, dist, prev}
        else
          unvisited2 = MapSet.delete(unvisited, current)

          {dist2, prev2} =
            neighbors(current)
            |> Enum.reduce({dist, prev}, fn {neighbor, weight}, {d, p} ->
              if MapSet.member?(unvisited2, neighbor) do
                alt = Map.get(d, current, @infinity) + weight

                if alt < Map.get(d, neighbor, @infinity) do
                  {Map.put(d, neighbor, alt), Map.put(p, neighbor, current)}
                else
                  {d, p}
                end
              else
                {d, p}
              end
            end)

          dijkstra_loop(dist2, prev2, unvisited2, target)
        end
      end
    end
  end

  defp neighbors(node) do
    :ets.match_object(@edges_table, {node, :"$1", :"$2"})
    |> Enum.map(fn {_, neighbor, weight} -> {neighbor, weight} end)
  rescue
    _ -> []
  end

  defp reconstruct_path(prev, source, target) do
    path = do_reconstruct(prev, source, target, [target])
    path
  end

  defp do_reconstruct(_prev, source, source, acc), do: acc

  defp do_reconstruct(prev, source, current, acc) do
    case Map.get(prev, current) do
      nil -> acc
      parent -> do_reconstruct(prev, source, parent, [parent | acc])
    end
  end

  # ---------------------------------------------------------------------------
  # Connected Components (BFS)
  # ---------------------------------------------------------------------------

  defp find_connected_components do
    all_nodes =
      :ets.match_object(@nodes_table, {:"$1", :"$2"})
      |> Enum.map(fn {id, _} -> id end)
      |> MapSet.new()

    do_bfs_components(all_nodes, [])
  end

  defp do_bfs_components(remaining, components) do
    if Enum.empty?(remaining) do
      components
    else
      do_bfs_components_step(remaining, components)
    end
  end

  defp do_bfs_components_step(remaining, components) do
    start = Enum.at(remaining, 0)
    component = bfs_component(start)
    remaining2 = MapSet.difference(remaining, MapSet.new(component))
    do_bfs_components(remaining2, [component | components])
  end

  defp bfs_component(start) do
    do_bfs([start], MapSet.new([start]))
  end

  defp do_bfs([], visited), do: MapSet.to_list(visited)

  defp do_bfs([current | queue], visited) do
    nbrs =
      (neighbors_undirected(current) ++ reverse_neighbors(current))
      |> Enum.reject(&MapSet.member?(visited, &1))

    visited2 = Enum.reduce(nbrs, visited, &MapSet.put(&2, &1))
    do_bfs(queue ++ nbrs, visited2)
  end

  defp neighbors_undirected(node) do
    :ets.match_object(@edges_table, {node, :"$1", :"$2"})
    |> Enum.map(fn {_, neighbor, _} -> neighbor end)
  rescue
    _ -> []
  end

  defp reverse_neighbors(node) do
    :ets.match_object(@edges_table, {:"$1", node, :"$2"})
    |> Enum.map(fn {from, _, _} -> from end)
  rescue
    _ -> []
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp remove_all_edges_for_node(node_id) do
    :ets.match_delete(@edges_table, {node_id, :"$1", :"$2"})
    :ets.match_delete(@edges_table, {:"$1", node_id, :"$2"})
  rescue
    _ -> :ok
  end

  defp broadcast_topology_change(event, node_id) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:topology_change,
       %{event: event, node_id: node_id, timestamp: System.system_time(:millisecond)}}
    )
  rescue
    _ -> :ok
  end

  defp schedule_partition_check do
    Process.send_after(self(), :check_partitions, @check_interval_ms)
  end
end
