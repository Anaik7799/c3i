defmodule Indrajaal.Substrate.L7.TrophicCascade do
  @moduledoc """
  ## Design Intent
  L7 substrate trophic cascade — pure functional module that models
  multi-level cascade effects through a food-web style dependency graph.

  Biological metaphor: top-down trophic cascades — removal of a keystone
  predator triggers population explosions in prey, which in turn deplete
  vegetation, destabilising the whole ecosystem. In system terms: a
  change in a "keystone" service propagates through dependent services.

  Algorithm:
    - Nodes represent system entities; edges represent dependency.
    - Each edge has a transfer coefficient ∈ [0.0, 1.0] (how much effect
      propagates across the link).
    - `cascade/3` propagates an initial perturbation from a source node
      using breadth-first traversal up to `max_depth` hops.
    - Effect at each hop decays by the product of transfer coefficients
      along the path (multiplicative attenuation).
    - Final cascade map: `%{node_id => cumulative_effect}`.

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED
  - SC-ECO-004: Ecosystem cascade analysis — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @type node_id :: String.t()

  @type edge :: %{
          from: node_id(),
          to: node_id(),
          transfer: float()
        }

  @type t :: %__MODULE__{
          edges: [edge()],
          nodes: MapSet.t(),
          cascade_count: non_neg_integer()
        }

  defstruct edges: [],
            nodes: MapSet.new(),
            cascade_count: 0

  # Default maximum cascade depth to avoid infinite loops
  @default_max_depth 6

  # Minimum effect magnitude below which propagation stops (pruning)
  @min_effect 0.001

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Create a new TrophicCascade model.

  Options:
    - `:edges` — list of `%{from: id, to: id, transfer: float}` maps.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    edges = Keyword.get(opts, :edges, [])

    cond do
      not is_list(edges) ->
        {:error, "edges must be a list"}

      not Enum.all?(edges, &valid_edge?/1) ->
        {:error, "each edge needs from, to (strings) and transfer in [0.0, 1.0]"}

      true ->
        nodes =
          Enum.reduce(edges, MapSet.new(), fn e, acc ->
            acc |> MapSet.put(e.from) |> MapSet.put(e.to)
          end)

        {:ok, %__MODULE__{edges: edges, nodes: nodes}}
    end
  end

  @doc "Add a directed edge to the dependency graph."
  @spec add_edge(t(), node_id(), node_id(), float()) ::
          {:ok, t()} | {:error, String.t()}
  def add_edge(%__MODULE__{} = state, from, to, transfer)
      when is_binary(from) and is_binary(to) do
    cond do
      transfer < 0.0 or transfer > 1.0 ->
        {:error, "transfer must be in [0.0, 1.0]"}

      true ->
        edge = %{from: from, to: to, transfer: transfer}
        new_nodes = state.nodes |> MapSet.put(from) |> MapSet.put(to)
        {:ok, %{state | edges: [edge | state.edges], nodes: new_nodes}}
    end
  end

  def add_edge(%__MODULE__{}, _from, _to, _transfer),
    do: {:error, "from and to must be strings"}

  @doc """
  Simulate a cascade effect starting from `source_node` with `initial_effect`.

  Traverses the dependency graph BFS up to `max_depth` hops.
  Returns `{cascade_map, updated_state}` where `cascade_map` is
  `%{node_id => cumulative_effect}`.
  """
  @spec cascade(t(), node_id(), float()) :: {%{node_id() => float()}, t()}
  def cascade(%__MODULE__{} = state, source, initial_effect) do
    cascade(state, source, initial_effect, @default_max_depth)
  end

  @spec cascade(t(), node_id(), float(), non_neg_integer()) ::
          {%{node_id() => float()}, t()}
  def cascade(%__MODULE__{} = state, source, initial_effect, max_depth)
      when is_binary(source) and is_integer(max_depth) do
    effect = max(-1.0, min(1.0, initial_effect * 1.0))
    adjacency = build_adjacency(state.edges)

    result = bfs_cascade(adjacency, source, effect, max_depth)
    new_state = %{state | cascade_count: state.cascade_count + 1}
    {result, new_state}
  end

  @doc "Returns a summary status map."
  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    %{
      node_count: MapSet.size(state.nodes),
      edge_count: length(state.edges),
      cascade_count: state.cascade_count
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec build_adjacency([edge()]) :: %{node_id() => [{node_id(), float()}]}
  defp build_adjacency(edges) do
    Enum.reduce(edges, %{}, fn e, acc ->
      Map.update(acc, e.from, [{e.to, e.transfer}], fn list -> [{e.to, e.transfer} | list] end)
    end)
  end

  @spec bfs_cascade(map(), node_id(), float(), non_neg_integer()) ::
          %{node_id() => float()}
  defp bfs_cascade(adjacency, source, initial_effect, max_depth) do
    # Queue entries: {node, effect, depth}
    queue = [{source, initial_effect, 0}]
    accumulated = %{source => initial_effect}
    do_bfs(adjacency, queue, accumulated, max_depth)
  end

  defp do_bfs(_adj, [], acc, _max_depth), do: acc

  defp do_bfs(adj, [{_node, effect, depth} | rest], acc, max_depth)
       when depth >= max_depth or abs(effect) < @min_effect do
    do_bfs(adj, rest, acc, max_depth)
  end

  defp do_bfs(adj, [{node, effect, depth} | rest], acc, max_depth) do
    neighbors = Map.get(adj, node, [])

    {new_queue, new_acc} =
      Enum.reduce(neighbors, {rest, acc}, fn {neighbor, transfer}, {q_acc, a_acc} ->
        propagated = effect * transfer
        previous = Map.get(a_acc, neighbor, 0.0)
        combined = previous + propagated
        new_entry = {neighbor, propagated, depth + 1}
        {[new_entry | q_acc], Map.put(a_acc, neighbor, combined)}
      end)

    do_bfs(adj, new_queue, new_acc, max_depth)
  end

  @spec valid_edge?(term()) :: boolean()
  defp valid_edge?(%{from: f, to: t, transfer: tr})
       when is_binary(f) and is_binary(t) and is_float(tr) do
    tr >= 0.0 and tr <= 1.0
  end

  defp valid_edge?(_), do: false
end
