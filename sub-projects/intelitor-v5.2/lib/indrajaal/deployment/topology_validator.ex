defmodule Indrajaal.Deployment.TopologyValidator do
  @moduledoc """
  SIL-4 Compliant DAG Topology Validation

  WHAT: Validates container dependency graphs and computes optimal startup order.

  WHY: SIL-4 requires deterministic boot sequences. DAG validation ensures
  no circular dependencies exist and computes parallel wave structure.

  CONSTRAINTS:
  - SC-SIL4-010: DAG validation before boot
  - SC-SIL4-005: Start order: DB → OBS → APP
  - SC-CLU-001: Seed node MUST start before satellites
  - SC-CLU-002: Fractal-cluster is MANDATORY

  TECHNIQUES:
  | Algorithm | Purpose | Complexity |
  |-----------|---------|------------|
  | Kahn's Algorithm | Topological sort | O(V + E) |
  | DFS Cycle Detection | Validate acyclicity | O(V + E) |
  | Configuration Hashing | Cache invalidation | O(1) |

  AOR:
  - AOR-SIL4-001: Validate topology before every boot
  - AOR-SIL4-002: Cache topology computation with hash validation
  """

  require Logger

  @type node_id :: String.t()
  @type dependency_graph :: %{node_id() => [node_id()]}
  @type topology_layer :: [node_id()]

  # =============================================================================
  # Fractal-Cluster Default Topology (SC-CLU-002)
  # =============================================================================

  @fractal_cluster_dependencies %{
    "db-primary" => [],
    "indrajaal-obs" => ["db-primary"],
    "indrajaal-ex-app-1" => ["db-primary", "indrajaal-obs"],
    "indrajaal-ex-app-2" => ["db-primary", "indrajaal-obs", "indrajaal-ex-app-1"],
    "indrajaal-ex-app-3" => ["db-primary", "indrajaal-obs", "indrajaal-ex-app-1"]
  }

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Returns the default fractal-cluster dependency graph.
  """
  @spec default_graph() :: dependency_graph()
  def default_graph, do: @fractal_cluster_dependencies

  @doc """
  Performs topological sort using Kahn's algorithm.
  Returns layers of nodes that can be started in parallel within each layer.

  ## Example

      iex> graph = %{"a" => [], "b" => ["a"], "c" => ["a"], "d" => ["b", "c"]}
      iex> TopologyValidator.topological_sort(graph)
      {:ok, [["a"], ["b", "c"], ["d"]]}

  """
  @spec topological_sort(dependency_graph()) ::
          {:ok, [topology_layer()]} | {:error, :cycle_detected}
  def topological_sort(graph) do
    # Build in-degree map and adjacency list
    {in_degree, adjacency} = build_graph_structures(graph)

    # Find all nodes with in-degree 0
    initial_queue =
      in_degree
      |> Enum.filter(fn {_node, degree} -> degree == 0 end)
      |> Enum.map(fn {node, _} -> node end)
      |> Enum.sort()

    # Execute Kahn's algorithm
    kahns_algorithm(initial_queue, in_degree, adjacency, [], 0, map_size(graph))
  end

  @doc """
  Validates that a dependency graph is acyclic using DFS.
  """
  @spec validate_acyclic(dependency_graph()) :: :ok | {:error, :cycle_detected}
  def validate_acyclic(graph) do
    nodes = Map.keys(graph)

    initial_state = %{
      white: MapSet.new(nodes),
      gray: MapSet.new(),
      black: MapSet.new()
    }

    result =
      Enum.reduce_while(nodes, initial_state, fn node, state ->
        if MapSet.member?(state.white, node) do
          case dfs_visit(node, graph, state) do
            {:ok, new_state} -> {:cont, new_state}
            {:error, :cycle} -> {:halt, {:error, :cycle}}
          end
        else
          {:cont, state}
        end
      end)

    case result do
      {:error, :cycle} -> {:error, :cycle_detected}
      _ -> :ok
    end
  end

  @doc """
  Validates the fractal-cluster topology.
  Returns :ok if valid, {:error, reason} otherwise.
  """
  @spec validate_fractal_cluster() :: :ok | {:error, String.t()}
  def validate_fractal_cluster do
    validate(@fractal_cluster_dependencies)
  end

  @doc """
  Validates a dependency graph.
  Checks for cycles and required nodes.
  """
  @spec validate(dependency_graph()) :: :ok | {:error, String.t()}
  def validate(graph) do
    with :ok <- validate_acyclic(graph),
         :ok <- validate_all_deps_exist(graph),
         :ok <- validate_no_self_deps(graph) do
      :ok
    end
  end

  @doc """
  Computes configuration hash for cache invalidation.
  """
  @spec config_hash(dependency_graph()) :: binary()
  def config_hash(graph) do
    graph
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0..15)
  end

  @doc """
  Returns startup waves from the fractal-cluster topology.
  """
  @spec fractal_cluster_waves() :: {:ok, [Indrajaal.Deployment.StartupWave.t()]}
  def fractal_cluster_waves do
    alias Indrajaal.Deployment.StartupWave

    waves = [
      %StartupWave{
        order: 1,
        containers: ["db-primary"],
        timeout_ms: 30_000,
        jitter_enabled: false
      },
      %StartupWave{
        order: 2,
        containers: ["indrajaal-obs"],
        timeout_ms: 30_000,
        jitter_enabled: false
      },
      %StartupWave{
        order: 3,
        containers: ["indrajaal-ex-app-1"],
        timeout_ms: 30_000,
        jitter_enabled: false
      },
      %StartupWave{
        order: 4,
        containers: ["indrajaal-ex-app-2", "indrajaal-ex-app-3"],
        timeout_ms: 30_000,
        jitter_enabled: true
      }
    ]

    {:ok, waves}
  end

  @doc """
  Computes shutdown waves (reverse of startup).
  """
  @spec compute_shutdown_waves(dependency_graph()) ::
          {:ok, [topology_layer()]} | {:error, :cycle_detected}
  def compute_shutdown_waves(graph) do
    case topological_sort(graph) do
      {:ok, layers} ->
        {:ok, Enum.reverse(layers)}

      error ->
        error
    end
  end

  # =============================================================================
  # Private: Kahn's Algorithm
  # =============================================================================

  defp build_graph_structures(graph) do
    # Initialize in-degree for all nodes
    all_nodes = Map.keys(graph)
    initial_in_degree = Map.new(all_nodes, fn node -> {node, 0} end)

    # Build adjacency list (who depends on me) and count in-degrees
    {in_degree, adjacency} =
      Enum.reduce(graph, {initial_in_degree, %{}}, fn {node, deps}, {in_deg, adj} ->
        # This node has |deps| incoming edges
        new_in_deg = Map.put(in_deg, node, length(deps))

        # Each dep has an outgoing edge to this node
        new_adj =
          Enum.reduce(deps, adj, fn dep, acc ->
            Map.update(acc, dep, [node], fn existing -> [node | existing] end)
          end)

        {new_in_deg, new_adj}
      end)

    {in_degree, adjacency}
  end

  defp kahns_algorithm([], _in_degree, _adjacency, layers, processed, total)
       when processed == total do
    {:ok, Enum.reverse(layers)}
  end

  defp kahns_algorithm([], _in_degree, _adjacency, _layers, processed, total)
       when processed < total do
    # Not all nodes processed = cycle exists
    {:error, :cycle_detected}
  end

  defp kahns_algorithm(queue, in_degree, adjacency, layers, processed, total) do
    # Current layer = all nodes in queue
    current_layer = Enum.sort(queue)

    # Process all nodes in current layer
    {new_in_degree, next_queue} =
      Enum.reduce(current_layer, {in_degree, []}, fn node, {in_deg, next_q} ->
        # Get all nodes that depend on this node
        dependents = Map.get(adjacency, node, [])

        # Decrease their in-degree
        {updated_in_deg, new_zero_degree} =
          Enum.reduce(dependents, {in_deg, []}, fn dep, {deg_acc, zero_acc} ->
            new_degree = Map.get(deg_acc, dep, 0) - 1
            updated_deg = Map.put(deg_acc, dep, new_degree)

            if new_degree == 0 do
              {updated_deg, [dep | zero_acc]}
            else
              {updated_deg, zero_acc}
            end
          end)

        {updated_in_deg, next_q ++ new_zero_degree}
      end)

    new_processed = processed + length(current_layer)

    kahns_algorithm(
      Enum.uniq(next_queue),
      new_in_degree,
      adjacency,
      [current_layer | layers],
      new_processed,
      total
    )
  end

  # =============================================================================
  # Private: DFS Cycle Detection
  # =============================================================================

  defp dfs_visit(node, graph, state) do
    # Move from white to gray
    state = %{
      state
      | white: MapSet.delete(state.white, node),
        gray: MapSet.put(state.gray, node)
    }

    # Visit all dependencies
    deps = Map.get(graph, node, [])

    result =
      Enum.reduce_while(deps, {:ok, state}, fn dep, {:ok, s} ->
        cond do
          # Back edge to gray node = cycle
          MapSet.member?(s.gray, dep) ->
            {:halt, {:error, :cycle}}

          # White node = unvisited, recurse
          MapSet.member?(s.white, dep) ->
            case dfs_visit(dep, graph, s) do
              {:ok, new_state} -> {:cont, {:ok, new_state}}
              {:error, :cycle} -> {:halt, {:error, :cycle}}
            end

          # Black node = already fully processed
          true ->
            {:cont, {:ok, s}}
        end
      end)

    case result do
      {:ok, final_state} ->
        # Move from gray to black
        {:ok,
         %{
           final_state
           | gray: MapSet.delete(final_state.gray, node),
             black: MapSet.put(final_state.black, node)
         }}

      error ->
        error
    end
  end

  # =============================================================================
  # Private: Validation Helpers
  # =============================================================================

  defp validate_all_deps_exist(graph) do
    all_nodes = MapSet.new(Map.keys(graph))

    missing =
      graph
      |> Enum.flat_map(fn {_node, deps} -> deps end)
      |> Enum.reject(&MapSet.member?(all_nodes, &1))
      |> Enum.uniq()

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing dependencies: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_no_self_deps(graph) do
    self_deps =
      graph
      |> Enum.filter(fn {node, deps} -> node in deps end)
      |> Enum.map(fn {node, _} -> node end)

    if Enum.empty?(self_deps) do
      :ok
    else
      {:error, "Self-dependencies detected: #{Enum.join(self_deps, ", ")}"}
    end
  end
end
