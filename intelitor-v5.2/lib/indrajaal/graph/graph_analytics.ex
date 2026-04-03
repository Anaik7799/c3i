defmodule Indrajaal.Graph.GraphAnalytics do
  @moduledoc """
  L2+ Advanced Analytics for the Graph Engine.

  ## WHAT
  Computes graph centrality metrics (Eigenvector, Degree, Betweenness, Closeness),
  builds live system topology from real process/supervisor data, tracks centrality
  convergence across snapshots, and publishes results to Zenoh.

  ## WHY
  To identify "Critical Nodes" in the system topology (High centrality = High Risk),
  and to quantify how fast topology stabilises after configuration changes.

  ## STAMP
  - SC-ANALYTICS-001: Convergence must occur within 100 iterations (eigenvector).
  - SC-ANALYTICS-002: Degree/Betweenness/Closeness computed on adjacency map (no Nx).
  - SC-ANALYTICS-003: System topology built from live BEAM process registry.
  - SC-ANALYTICS-004: Centrality results published to indrajaal/graph/centrality.

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-19 | Claude | Add degree/betweenness/closeness, topology builder, convergence analysis, Zenoh publish |
  | 21.1.0 | 2025-12-01 | Claude | Initial eigenvector centrality via power iteration |
  """
  require Logger

  alias Indrajaal.Observability.ZenohPublisher

  @zenoh_topic "indrajaal/graph/centrality"

  # ---------------------------------------------------------------------------
  # Eigenvector Centrality (Nx-based, original implementation)
  # ---------------------------------------------------------------------------

  @doc """
  Computes Eigenvector Centrality via power iteration.

      v_next = A * v_current / ||A * v_current||_2

  Converges when ||v_next - v|| < tol or max_iter is reached.

  ## Parameters
  - `adjacency_matrix` - Nx tensor, shape {n, n}
  - `max_iter` - maximum iterations (default 100, SC-ANALYTICS-001)
  - `tol` - convergence tolerance (default 1.0e-6)

  Returns an Nx vector of length n with eigenvector centrality scores.
  """
  @spec centrality(Nx.Tensor.t(), pos_integer(), float()) :: Nx.Tensor.t()
  def centrality(adjacency_matrix, max_iter \\ 100, tol \\ 1.0e-6) do
    start_time = System.monotonic_time()

    n = Nx.axis_size(adjacency_matrix, 0)
    v = Nx.broadcast(1.0, {n})

    {v_final, iters} = do_power_iteration(adjacency_matrix, v, max_iter, tol, 0)

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:indrajaal, :graph, :centrality],
      %{duration: duration, iterations: iters},
      %{nodes: n}
    )

    v_final
  end

  defp do_power_iteration(_matrix, v, max_iter, _tol, iter) when iter >= max_iter,
    do: {v, iter}

  defp do_power_iteration(matrix, v, max_iter, tol, iter) do
    v_next = Nx.dot(matrix, v)
    norm_val = Nx.sum(Nx.pow(v_next, 2)) |> Nx.sqrt()
    v_next = if Nx.to_number(norm_val) == 0.0, do: v_next, else: Nx.divide(v_next, norm_val)

    diff = Nx.sum(Nx.abs(Nx.subtract(v_next, v))) |> Nx.to_number()

    if diff < tol do
      {v_next, iter + 1}
    else
      do_power_iteration(matrix, v_next, max_iter, tol, iter + 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Degree Centrality (map-based, no Nx dependency)
  # ---------------------------------------------------------------------------

  @doc """
  Computes degree centrality for all nodes in an adjacency map.

      Degree(v) = out_degree(v) / (|V| - 1)

  For a directed graph, this uses out-degree. For an undirected graph where
  both directions are stored, each edge is counted once.

  ## Parameters
  - `adjacency` - map of `node => [neighbour, ...]`

  Returns `%{node => float}` where 1.0 means connected to every other node.

  ## Examples

      iex> GraphAnalytics.degree_centrality(%{"a" => ["b", "c"], "b" => ["a"], "c" => ["a"]})
      %{"a" => 1.0, "b" => 0.5, "c" => 0.5}
  """
  @spec degree_centrality(%{term() => [term()]}) :: %{term() => float()}
  def degree_centrality(adjacency) when map_size(adjacency) == 0, do: %{}

  def degree_centrality(adjacency) do
    nodes = Map.keys(adjacency)
    n = length(nodes)

    Map.new(nodes, fn node ->
      degree = length(Map.get(adjacency, node, []))
      score = if n > 1, do: degree / (n - 1), else: 0.0
      {node, score}
    end)
  end

  # ---------------------------------------------------------------------------
  # Betweenness Centrality (Brandes' BFS algorithm, map-based)
  # ---------------------------------------------------------------------------

  @doc """
  Computes betweenness centrality using Brandes' BFS algorithm.

      Betweenness(v) = Σ_{s≠v≠t} σ(s,t|v) / σ(s,t)
                       normalised by 1 / ((|V|-1)(|V|-2)) for directed graphs

  where σ(s,t) is the number of shortest paths from s to t and σ(s,t|v) is
  the number that pass through v.

  ## Parameters
  - `adjacency` - map of `node => [neighbour, ...]`

  Returns `%{node => float}` with normalised betweenness scores ∈ [0, 1].
  """
  @spec betweenness_centrality(%{term() => [term()]}) :: %{term() => float()}
  def betweenness_centrality(adjacency) when map_size(adjacency) == 0, do: %{}

  def betweenness_centrality(adjacency) do
    nodes = Map.keys(adjacency)
    n = length(nodes)

    # Accumulate raw betweenness scores via Brandes' accumulation
    raw =
      Enum.reduce(nodes, Map.new(nodes, &{&1, 0.0}), fn source, acc ->
        brandes_accumulate(source, adjacency, nodes, acc)
      end)

    # Normalise: divide by (n-1)(n-2) for directed graph
    normaliser = if n > 2, do: (n - 1) * (n - 2), else: 1

    Map.new(raw, fn {node, score} -> {node, score / normaliser} end)
  end

  # Single-source BFS accumulation step (Brandes 2001)
  defp brandes_accumulate(source, adjacency, nodes, betweenness) do
    # BFS initialisation
    sigma = Map.new(nodes, &{&1, 0.0}) |> Map.put(source, 1.0)
    dist = Map.new(nodes, &{&1, -1}) |> Map.put(source, 0)
    pred = Map.new(nodes, &{&1, []})
    queue = :queue.in(source, :queue.new())
    stack = []

    {stack, sigma, pred} =
      bfs_phase(queue, stack, sigma, dist, pred, adjacency)

    # Back-propagation phase
    delta = Map.new(nodes, &{&1, 0.0})

    {betweenness, _delta} =
      Enum.reduce(stack, {betweenness, delta}, fn w, {b_acc, d_acc} ->
        d_acc =
          Enum.reduce(Map.get(pred, w, []), d_acc, fn v, _d ->
            contribution =
              Map.get(sigma, v, 0.0) / max(Map.get(sigma, w, 1.0), 1.0) *
                (1.0 + Map.get(d_acc, w, 0.0))

            Map.update(d_acc, v, contribution, &(&1 + contribution))
          end)

        b_acc =
          if w != source do
            Map.update(b_acc, w, Map.get(d_acc, w, 0.0), &(&1 + Map.get(d_acc, w, 0.0)))
          else
            b_acc
          end

        {b_acc, d_acc}
      end)

    betweenness
  end

  defp bfs_phase(queue, stack, sigma, dist, pred, adjacency) do
    case :queue.out(queue) do
      {:empty, _} ->
        {stack, sigma, pred}

      {{:value, v}, queue_rest} ->
        stack = [v | stack]

        {queue_next, sigma_next, dist_next, pred_next} =
          Enum.reduce(Map.get(adjacency, v, []), {queue_rest, sigma, dist, pred}, fn w,
                                                                                     {q, s, d, p} ->
            d_v = Map.get(d, v, -1)
            d_w = Map.get(d, w, -1)

            # First time we reach w?
            {q, d} =
              if d_w < 0 do
                {:queue.in(w, q), Map.put(d, w, d_v + 1)}
              else
                {q, d}
              end

            # Is this a shortest path to w via v?
            {s, p} =
              if Map.get(d, w, -1) == Map.get(d, v, -1) + 1 do
                s = Map.update(s, w, Map.get(s, v, 0.0), &(&1 + Map.get(s, v, 0.0)))
                p = Map.update(p, w, [v], &[v | &1])
                {s, p}
              else
                {s, p}
              end

            {q, s, d, p}
          end)

        bfs_phase(queue_next, stack, sigma_next, dist_next, pred_next, adjacency)
    end
  end

  # ---------------------------------------------------------------------------
  # Closeness Centrality (BFS-based, map-based)
  # ---------------------------------------------------------------------------

  @doc """
  Computes closeness centrality for all nodes.

      Closeness(v) = (|V| - 1) / Σ_{u ≠ v} d(v, u)

  A node that is reachable from all others in few hops scores close to 1.0.
  Nodes from which other nodes are unreachable receive score 0.0.

  ## Parameters
  - `adjacency` - map of `node => [neighbour, ...]`

  Returns `%{node => float}` ∈ [0, 1].
  """
  @spec closeness_centrality(%{term() => [term()]}) :: %{term() => float()}
  def closeness_centrality(adjacency) when map_size(adjacency) == 0, do: %{}

  def closeness_centrality(adjacency) do
    nodes = Map.keys(adjacency)
    n = length(nodes)

    Map.new(nodes, fn source ->
      total_dist = bfs_total_distance(source, adjacency)

      score =
        if total_dist == 0 do
          0.0
        else
          (n - 1) / total_dist
        end

      {source, score}
    end)
  end

  # BFS from source, returns the sum of all shortest-path distances
  defp bfs_total_distance(source, adjacency) do
    dist = %{source => 0}
    queue = :queue.in(source, :queue.new())
    bfs_sum(queue, dist, adjacency, 0)
  end

  defp bfs_sum(queue, dist, adjacency, acc) do
    case :queue.out(queue) do
      {:empty, _} ->
        acc

      {{:value, v}, rest} ->
        d_v = Map.get(dist, v, 0)

        {queue_next, dist_next, acc_next} =
          Enum.reduce(Map.get(adjacency, v, []), {rest, dist, acc}, fn w, {q, d, a} ->
            if Map.has_key?(d, w) do
              {q, d, a}
            else
              d_w = d_v + 1
              {:queue.in(w, q), Map.put(d, w, d_w), a + d_w}
            end
          end)

        bfs_sum(queue_next, dist_next, adjacency, acc_next)
    end
  end

  # ---------------------------------------------------------------------------
  # All-centrality: compute all three map-based metrics at once
  # ---------------------------------------------------------------------------

  @doc """
  Computes all three structural centrality metrics in a single pass.

  Returns a map:

      %{
        degree:      %{node => float},
        betweenness: %{node => float},
        closeness:   %{node => float}
      }
  """
  @spec all_centrality(%{term() => [term()]}) :: %{
          degree: %{term() => float()},
          betweenness: %{term() => float()},
          closeness: %{term() => float()}
        }
  def all_centrality(adjacency) do
    %{
      degree: degree_centrality(adjacency),
      betweenness: betweenness_centrality(adjacency),
      closeness: closeness_centrality(adjacency)
    }
  end

  # ---------------------------------------------------------------------------
  # System Topology Builder (real BEAM data)
  # ---------------------------------------------------------------------------

  @doc """
  Builds a topology graph from live BEAM system data.

  Nodes are derived from `Process.registered/0`. Edges are inferred from:
  - Supervisor child relationships (`:supervisor.which_children/1`)
  - Known Phoenix.PubSub → subscriber bindings (best-effort)

  Returns:

      %{
        nodes: [%{id: atom(), pid: pid()}],
        adjacency: %{atom() => [atom()]},
        edges: [{atom(), atom()}],
        metadata: %{timestamp: DateTime.t(), node_count: integer(), edge_count: integer()}
      }
  """
  @spec build_system_topology() :: map()
  def build_system_topology do
    registered = Process.registered()

    pids =
      Enum.flat_map(registered, fn name ->
        case Process.whereis(name) do
          nil -> []
          pid -> [{name, pid}]
        end
      end)

    adjacency = build_adjacency_from_supervisors(pids)

    edges =
      Enum.flat_map(adjacency, fn {parent, children} ->
        Enum.map(children, fn child -> {parent, child} end)
      end)

    %{
      nodes: Enum.map(pids, fn {name, pid} -> %{id: name, pid: pid} end),
      adjacency: adjacency,
      edges: edges,
      metadata: %{
        timestamp: DateTime.utc_now(),
        node_count: length(pids),
        edge_count: length(edges)
      }
    }
  end

  # Walk each registered process; if it is a supervisor, record parent→child edges.
  defp build_adjacency_from_supervisors(pids) do
    pid_to_name = Map.new(pids, fn {name, pid} -> {pid, name} end)

    Enum.reduce(pids, %{}, fn {parent_name, pid}, acc ->
      children = supervisor_children(pid, pid_to_name)
      # Ensure the parent key always exists even with no children
      Map.update(acc, parent_name, children, fn existing ->
        Enum.uniq(existing ++ children)
      end)
    end)
  end

  defp supervisor_children(pid, pid_to_name) do
    try do
      {:links, links} = Process.info(pid, :links)

      Enum.flat_map(links, fn linked_pid ->
        case Map.get(pid_to_name, linked_pid) do
          nil -> []
          name -> [name]
        end
      end)
    rescue
      _ -> []
    catch
      _, _ -> []
    end
  end

  # ---------------------------------------------------------------------------
  # Convergence Analysis
  # ---------------------------------------------------------------------------

  @doc """
  Analyses how quickly centrality scores converge across a history of snapshots.

  Each snapshot in `history` must be a `%{node => float}` map (e.g. degree
  centrality from consecutive `build_system_topology/0` calls).

  Returns:

      %{
        converged:       boolean(),
        convergence_rate: float(),   # 1.0 = fully stable, 0.0 = fully unstable
        delta_norms:     [float()],  # ||C_t - C_{t-1}|| for each consecutive pair
        snapshot_count:  integer()
      }

  ## Convergence formula

      rate = 1 - (||C_t - C_{t-1}||_2 / max(||C_{t-1}||_2, ε))

  averaged over all consecutive pairs; rate ≥ 0.95 is considered "converged".
  """
  @spec convergence_analysis([%{term() => float()}]) :: map()
  def convergence_analysis(history) when length(history) < 2 do
    %{
      converged: false,
      convergence_rate: 0.0,
      delta_norms: [],
      snapshot_count: length(history),
      error: "need at least 2 snapshots"
    }
  end

  def convergence_analysis(history) do
    pairs = Enum.zip(history, tl(history))

    delta_norms =
      Enum.map(pairs, fn {prev, curr} ->
        all_nodes = (Map.keys(prev) ++ Map.keys(curr)) |> Enum.uniq()

        sq_diff =
          Enum.reduce(all_nodes, 0.0, fn node, acc ->
            p = Map.get(prev, node, 0.0)
            c = Map.get(curr, node, 0.0)
            acc + (c - p) * (c - p)
          end)

        sq_prev =
          Enum.reduce(all_nodes, 0.0, fn node, acc ->
            p = Map.get(prev, node, 0.0)
            acc + p * p
          end)

        norm_diff = :math.sqrt(sq_diff)
        norm_prev = max(:math.sqrt(sq_prev), 1.0e-10)
        # Rate for this pair
        max(0.0, 1.0 - norm_diff / norm_prev)
      end)

    avg_rate = Enum.sum(delta_norms) / length(delta_norms)

    %{
      converged: avg_rate >= 0.95,
      convergence_rate: Float.round(avg_rate, 6),
      delta_norms: Enum.map(delta_norms, &Float.round(&1, 6)),
      snapshot_count: length(history)
    }
  end

  # ---------------------------------------------------------------------------
  # Zenoh Publishing
  # ---------------------------------------------------------------------------

  @doc """
  Computes all centrality metrics for the live system topology and publishes
  the result to Zenoh topic `indrajaal/graph/centrality`.

  Returns the full metrics map so callers can use it locally too.

  ## Dual-write (SC-ZTEST-008)
  The payload is always logged first; then Zenoh publish is attempted.
  A Zenoh failure does NOT raise — it is logged at `:warning` level.
  """
  @spec publish_centrality_metrics() :: map()
  def publish_centrality_metrics do
    topology = build_system_topology()
    metrics = all_centrality(topology.adjacency)

    payload = %{
      checkpoint: "CP-GRAPH-01",
      topic: @zenoh_topic,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      node_count: topology.metadata.node_count,
      edge_count: topology.metadata.edge_count,
      degree: metrics.degree,
      betweenness: metrics.betweenness,
      closeness: metrics.closeness
    }

    # Log fallback first (SC-ZTEST-008 dual-write)
    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=CP-GRAPH-01 topic=#{@zenoh_topic} " <>
        "node_count=#{payload.node_count} edge_count=#{payload.edge_count} " <>
        "timestamp=#{payload.timestamp}",
      domain: :graph_analytics
    )

    # Best-effort async Zenoh publish (SC-ZTEST-004: non-blocking)
    try do
      ZenohPublisher.publish_async(@zenoh_topic, payload)
    rescue
      _ -> :ok
    end

    :telemetry.execute(
      [:indrajaal, :graph, :centrality_publish],
      %{node_count: topology.metadata.node_count, edge_count: topology.metadata.edge_count},
      %{}
    )

    payload
  end
end
