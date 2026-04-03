defmodule Indrajaal.Distributed.Mesh.Routing do
  @moduledoc """
  Message Routing - Intelligent Message Routing for v20.0.0

  Implements routing algorithms for mesh network:
  - Shortest path routing
  - Load-balanced routing
  - Failover routing
  - Content-based routing

  ## Routing Model

  Route selection: argmin_r cost(r) subject to latency(r) < threshold

  Where:
  - cost(r) = hop_count × latency_factor + congestion_factor
  - latency(r) = Σ edge_latency for edges in route

  ## Routing Strategies
  - **Shortest**: Minimum hops
  - **Fastest**: Minimum latency
  - **Balanced**: Load distribution
  - **Reliable**: Multiple paths

  ## STAMP Constraints
  - SC-ROU-001: Route calculation < 5ms
  - SC-ROU-002: Route cache MUST be invalidated on topology change
  - SC-ROU-003: Failover MUST be automatic
  - SC-ROU-004: Loop detection MUST be enforced
  """

  use GenServer
  require Logger

  alias Indrajaal.Distributed.Mesh.Mycelium

  @type node_id :: String.t()
  @type route :: [node_id()]
  @type routing_strategy :: :shortest | :fastest | :balanced | :reliable

  @type route_entry :: %{
          destination: node_id(),
          next_hop: node_id(),
          path: route(),
          cost: float(),
          latency_ms: non_neg_integer(),
          created_at: DateTime.t(),
          expires_at: DateTime.t()
        }

  @type routing_state :: %{
          node_id: node_id(),
          routing_table: map(),
          topology: map(),
          metrics: map(),
          config: map()
        }

  # Route cache TTL (seconds)
  @route_ttl 60

  # Route calculation timeout (ms)
  @route_timeout 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the route to a destination.
  """
  @spec get_route(node_id(), Keyword.t()) :: {:ok, route()} | {:error, term()}
  def get_route(destination, opts \\ []) do
    GenServer.call(__MODULE__, {:get_route, destination, opts}, @route_timeout)
  end

  @doc """
  Gets the next hop for a destination.
  """
  @spec next_hop(node_id()) :: {:ok, node_id()} | {:error, term()}
  def next_hop(destination) do
    GenServer.call(__MODULE__, {:next_hop, destination})
  end

  @doc """
  Routes a message to destination.
  """
  @spec route_message(node_id(), term()) :: :ok | {:error, term()}
  def route_message(destination, message) do
    GenServer.call(__MODULE__, {:route_message, destination, message})
  end

  @doc """
  Updates topology information.
  """
  @spec update_topology(map()) :: :ok
  def update_topology(topology) do
    GenServer.cast(__MODULE__, {:update_topology, topology})
  end

  @doc """
  Reports link metrics.
  """
  @spec report_metrics(node_id(), map()) :: :ok
  def report_metrics(neighbor, metrics) do
    GenServer.cast(__MODULE__, {:report_metrics, neighbor, metrics})
  end

  @doc """
  Invalidates route cache.
  """
  @spec invalidate_cache() :: :ok
  def invalidate_cache do
    GenServer.cast(__MODULE__, :invalidate_cache)
  end

  @doc """
  Gets routing table.
  """
  @spec routing_table() :: map()
  def routing_table do
    GenServer.call(__MODULE__, :routing_table)
  end

  @doc """
  Gets routing statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, generate_id())

    state = %{
      node_id: node_id,
      routing_table: %{},
      topology: %{nodes: [], edges: []},
      metrics: %{},
      stats: %{
        routes_calculated: 0,
        cache_hits: 0,
        cache_misses: 0,
        failovers: 0
      },
      config: %{
        default_strategy: Keyword.get(opts, :strategy, :fastest),
        cache_ttl: Keyword.get(opts, :cache_ttl, @route_ttl),
        max_hops: Keyword.get(opts, :max_hops, 10)
      }
    }

    # Schedule cache cleanup
    Process.send_after(self(), :cleanup_cache, state.config.cache_ttl * 1000)

    Logger.info("🛤️ Routing service started on #{node_id}")

    {:ok, state}
  end

  @impl true
  def handle_call({:get_route, destination, opts}, _from, state) do
    strategy = Keyword.get(opts, :strategy, state.config.default_strategy)

    # Check cache first
    case get_cached_route(destination, state) do
      {:ok, route_entry} ->
        new_stats = %{state.stats | cache_hits: state.stats.cache_hits + 1}
        {:reply, {:ok, route_entry.path}, %{state | stats: new_stats}}

      :miss ->
        # Calculate route
        case calculate_route(destination, strategy, state) do
          {:ok, route_entry} ->
            # Cache the route
            new_table = Map.put(state.routing_table, destination, route_entry)

            new_stats = %{
              state.stats
              | cache_misses: state.stats.cache_misses + 1,
                routes_calculated: state.stats.routes_calculated + 1
            }

            {:reply, {:ok, route_entry.path},
             %{state | routing_table: new_table, stats: new_stats}}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:next_hop, destination}, _from, state) do
    case get_cached_route(destination, state) do
      {:ok, route_entry} ->
        {:reply, {:ok, route_entry.next_hop}, state}

      :miss ->
        case calculate_route(destination, state.config.default_strategy, state) do
          {:ok, route_entry} ->
            new_table = Map.put(state.routing_table, destination, route_entry)
            {:reply, {:ok, route_entry.next_hop}, %{state | routing_table: new_table}}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:route_message, destination, message}, _from, state) do
    case get_or_calculate_route(destination, state) do
      {:ok, route_entry, new_state} ->
        # Send to next hop
        case Mycelium.send_message(
               route_entry.next_hop,
               {:routed, destination, message, route_entry.path}
             ) do
          :ok ->
            {:reply, :ok, new_state}

          {:error, _reason} ->
            # Failover to alternate route
            case failover_route(destination, route_entry, new_state) do
              {:ok, alt_entry, final_state} ->
                new_stats = %{final_state.stats | failovers: final_state.stats.failovers + 1}

                Mycelium.send_message(
                  alt_entry.next_hop,
                  {:routed, destination, message, alt_entry.path}
                )

                {:reply, :ok, %{final_state | stats: new_stats}}

              error ->
                {:reply, error, new_state}
            end
        end

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:routing_table, _from, state) do
    {:reply, state.routing_table, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        cached_routes: map_size(state.routing_table),
        known_nodes: length(state.topology.nodes),
        known_edges: length(state.topology.edges)
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:update_topology, topology}, state) do
    # Invalidate affected routes (SC-ROU-002)
    new_table = invalidate_affected_routes(state.routing_table, topology, state.topology)
    {:noreply, %{state | topology: topology, routing_table: new_table}}
  end

  @impl true
  def handle_cast({:report_metrics, neighbor, metrics}, state) do
    new_metrics = Map.put(state.metrics, neighbor, metrics)
    {:noreply, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_cast(:invalidate_cache, state) do
    {:noreply, %{state | routing_table: %{}}}
  end

  @impl true
  def handle_info(:cleanup_cache, state) do
    now = DateTime.utc_now()

    filtered_entries =
      Enum.filter(state.routing_table, fn {_, entry} ->
        DateTime.compare(now, entry.expires_at) == :lt
      end)

    new_table = Map.new(filtered_entries)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_cache, state.config.cache_ttl * 1000)

    {:noreply, %{state | routing_table: new_table}}
  end

  @impl true
  def handle_info({:routed, destination, message, remaining_path}, state) do
    if destination == state.node_id do
      # Destination reached
      Logger.debug("Message arrived at destination")
      send(self(), {:delivered, message})
    else
      # Forward to next hop
      case remaining_path do
        [_current, next | rest] ->
          Mycelium.send_message(next, {:routed, destination, message, [next | rest]})

        _ ->
          Logger.warning("Invalid routing path")
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:delivered, _message}, state) do
    # Handle delivered message
    {:noreply, state}
  end

  # Private helpers

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(8)
    Base.encode16(random_bytes, case: :lower)
  end

  defp get_cached_route(destination, state) do
    case Map.get(state.routing_table, destination) do
      nil ->
        :miss

      entry ->
        now = DateTime.utc_now()

        if DateTime.compare(now, entry.expires_at) == :lt do
          {:ok, entry}
        else
          :miss
        end
    end
  end

  defp get_or_calculate_route(destination, state) do
    case get_cached_route(destination, state) do
      {:ok, entry} ->
        {:ok, entry, state}

      :miss ->
        case calculate_route(destination, state.config.default_strategy, state) do
          {:ok, entry} ->
            new_table = Map.put(state.routing_table, destination, entry)
            {:ok, entry, %{state | routing_table: new_table}}

          error ->
            error
        end
    end
  end

  defp calculate_route(destination, strategy, state) do
    # Build adjacency graph
    graph = build_graph(state.topology, state.metrics)

    # Find path based on strategy
    route_result =
      case strategy do
        :shortest ->
          dijkstra_shortest(graph, state.node_id, destination, :hops)

        :fastest ->
          dijkstra_shortest(graph, state.node_id, destination, :latency)

        :balanced ->
          load_balanced_route(graph, state.node_id, destination)

        :reliable ->
          multipath_route(graph, state.node_id, destination)
      end

    case route_result do
      {:ok, path, cost, latency} ->
        entry = %{
          destination: destination,
          next_hop: Enum.at(path, 1, destination),
          path: path,
          cost: cost,
          latency_ms: latency,
          created_at: DateTime.utc_now(),
          expires_at: DateTime.add(DateTime.utc_now(), state.config.cache_ttl, :second)
        }

        {:ok, entry}

      error ->
        error
    end
  end

  defp build_graph(topology, metrics) do
    # Build adjacency list with weights
    edges =
      Enum.reduce(topology.edges, %{}, fn edge, acc ->
        latency = get_edge_latency(edge, metrics)
        load = get_edge_load(edge, metrics)

        from_edges = Map.get(acc, edge.from, [])
        new_edges = [{edge.to, %{latency: latency, load: load}} | from_edges]
        Map.put(acc, edge.from, new_edges)
      end)

    %{nodes: topology.nodes, edges: edges}
  end

  defp get_edge_latency(edge, metrics) do
    case Map.get(metrics, edge.to) do
      nil -> 100
      m -> Map.get(m, :latency, 100)
    end
  end

  defp get_edge_load(edge, metrics) do
    case Map.get(metrics, edge.to) do
      nil -> 0.5
      m -> Map.get(m, :load, 0.5)
    end
  end

  defp dijkstra_shortest(graph, source, destination, weight_type) do
    # Simplified Dijkstra's algorithm
    initial = %{
      distances: %{source => 0},
      predecessors: %{},
      visited: MapSet.new(),
      queue: [{0, source}]
    }

    case dijkstra_loop(initial, graph, destination, weight_type) do
      {:found, state} ->
        path = reconstruct_path(state.predecessors, source, destination)
        cost = Map.get(state.distances, destination, :infinity)
        {:ok, path, cost, cost}

      :not_found ->
        {:error, :no_route}
    end
  end

  defp dijkstra_loop(%{queue: []} = _state, _graph, _dest, _weight), do: :not_found

  defp dijkstra_loop(state, graph, destination, weight_type) do
    [{dist, current} | rest_queue] = Enum.sort(state.queue)

    if current == destination do
      {:found, state}
    else
      if MapSet.member?(state.visited, current) do
        dijkstra_loop(%{state | queue: rest_queue}, graph, destination, weight_type)
      else
        new_visited = MapSet.put(state.visited, current)
        neighbors = Map.get(graph.edges, current, [])

        {new_distances, new_predecessors, new_queue} =
          Enum.reduce(neighbors, {state.distances, state.predecessors, rest_queue}, fn {neighbor,
                                                                                        edge_data},
                                                                                       {dists,
                                                                                        preds,
                                                                                        queue} ->
            update_neighbor_distance(
              neighbor,
              edge_data,
              current,
              dist,
              dists,
              preds,
              queue,
              weight_type
            )
          end)

        new_state = %{
          state
          | distances: new_distances,
            predecessors: new_predecessors,
            visited: new_visited,
            queue: new_queue
        }

        dijkstra_loop(new_state, graph, destination, weight_type)
      end
    end
  end

  defp reconstruct_path(predecessors, source, destination) do
    reconstruct_path(predecessors, source, destination, [destination])
  end

  defp reconstruct_path(_predecessors, source, source, path), do: path

  defp reconstruct_path(predecessors, source, current, path) do
    case Map.get(predecessors, current) do
      nil -> path
      prev -> reconstruct_path(predecessors, source, prev, [prev | path])
    end
  end

  defp update_neighbor_distance(
         neighbor,
         edge_data,
         current,
         dist,
         dists,
         preds,
         queue,
         weight_type
       ) do
    weight =
      case weight_type do
        :hops -> 1
        :latency -> edge_data.latency
      end

    alt = dist + weight
    current_dist = Map.get(dists, neighbor, :infinity)

    if alt < current_dist do
      {Map.put(dists, neighbor, alt), Map.put(preds, neighbor, current),
       [{alt, neighbor} | queue]}
    else
      {dists, preds, queue}
    end
  end

  defp load_balanced_route(graph, source, destination) do
    # Simplified load-balanced routing
    dijkstra_shortest(graph, source, destination, :latency)
  end

  defp multipath_route(graph, source, destination) do
    # Simplified - just return primary path
    dijkstra_shortest(graph, source, destination, :latency)
  end

  defp failover_route(destination, failed_entry, state) do
    # Calculate alternative route avoiding failed next hop
    # Simplified - recalculate route
    case calculate_route(destination, :reliable, state) do
      {:ok, entry} when entry.next_hop != failed_entry.next_hop ->
        {:ok, entry, state}

      _ ->
        {:error, :no_alternate_route}
    end
  end

  defp invalidate_affected_routes(table, new_topology, old_topology) do
    # Find nodes that changed
    new_nodes = MapSet.new(new_topology.nodes)
    old_nodes = MapSet.new(old_topology.nodes)
    changed = MapSet.symmetric_difference(new_nodes, old_nodes)

    # Invalidate routes that pass through changed nodes
    filtered_routes =
      Enum.filter(table, fn {_dest, entry} ->
        not Enum.any?(entry.path, fn node -> MapSet.member?(changed, node) end)
      end)

    Map.new(filtered_routes)
  end
end
