defmodule Indrajaal.Substrate.L7.PollinationNetwork do
  @moduledoc """
  ## Design Intent
  L7 substrate Pollination Network — pure functional cross-pollination graph.
  Models information/capability transfer between ecosystem nodes using a
  weighted directed graph. Each edge represents a pollination event where
  node A "pollinates" node B with a payload (concept, pattern, signal).

  Graph properties tracked:
  - Node degree (in/out) for influence measurement
  - Edge weight decay: w_t = w_0 × e^(−λt) where λ = 0.05 per tick
  - Network density: |edges| / (|nodes| × (|nodes| − 1))

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED (L7)
  - SC-ECO-004: Integration pattern validation — ENFORCED
  - SC-GRAPH-001: Graph operations — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @max_nodes 128
  @max_edges 512
  @decay_lambda 0.05

  @type node_id :: String.t()

  @type edge :: %{
          from: node_id(),
          to: node_id(),
          weight: float(),
          payload_type: atom(),
          tick: non_neg_integer()
        }

  @type node_entry :: %{
          id: node_id(),
          in_degree: non_neg_integer(),
          out_degree: non_neg_integer()
        }

  @type t :: %__MODULE__{
          nodes: %{node_id() => node_entry()},
          edges: [edge()],
          tick: non_neg_integer()
        }

  defstruct nodes: %{},
            edges: [],
            tick: 0

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    node_ids = Keyword.get(opts, :nodes, [])

    cond do
      length(node_ids) > @max_nodes ->
        {:error, "nodes exceeds max #{@max_nodes}"}

      not Enum.all?(node_ids, &is_binary/1) ->
        {:error, "all node IDs must be strings"}

      true ->
        nodes =
          Map.new(node_ids, fn id ->
            {id, %{id: id, in_degree: 0, out_degree: 0}}
          end)

        {:ok, %__MODULE__{nodes: nodes}}
    end
  end

  @doc """
  Register a pollination event from `from` to `to` with a given weight.
  Nodes are auto-registered if not present.
  """
  @spec pollinate(t(), node_id(), node_id(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def pollinate(%__MODULE__{} = state, from, to, opts \\ [])
      when is_binary(from) and is_binary(to) do
    cond do
      from == to ->
        {:error, "self-pollination not allowed"}

      length(state.edges) >= @max_edges ->
        {:error, "edge capacity #{@max_edges} reached"}

      true ->
        weight = Keyword.get(opts, :weight, 1.0) |> clamp(0.0, 1.0)
        payload_type = Keyword.get(opts, :payload_type, :generic)

        edge = %{
          from: from,
          to: to,
          weight: weight,
          payload_type: payload_type,
          tick: state.tick
        }

        nodes =
          state.nodes
          |> ensure_node(from)
          |> ensure_node(to)
          |> update_in([from, :out_degree], &(&1 + 1))
          |> update_in([to, :in_degree], &(&1 + 1))

        {:ok, %{state | nodes: nodes, edges: [edge | state.edges]}}
    end
  end

  @doc """
  Advance the tick counter and apply weight decay to all edges.
  """
  @spec tick(t()) :: t()
  def tick(%__MODULE__{} = state) do
    new_tick = state.tick + 1

    edges =
      state.edges
      |> Enum.map(fn e ->
        age = new_tick - e.tick
        decayed = e.weight * :math.exp(-@decay_lambda * age)
        %{e | weight: Float.round(decayed, 4)}
      end)
      |> Enum.reject(fn e -> e.weight < 0.001 end)

    %{state | tick: new_tick, edges: edges}
  end

  @doc """
  Compute top N nodes by influence (in-degree × mean incoming weight).
  """
  @spec top_influencers(t(), pos_integer()) :: [%{id: node_id(), score: float()}]
  def top_influencers(%__MODULE__{} = state, n \\ 5) when is_integer(n) and n > 0 do
    state.nodes
    |> Enum.map(fn {id, node} ->
      incoming = Enum.filter(state.edges, fn e -> e.to == id end)

      mean_weight =
        if incoming == [],
          do: 0.0,
          else: Enum.sum(Enum.map(incoming, & &1.weight)) / length(incoming)

      %{id: id, score: Float.round(node.in_degree * mean_weight, 4)}
    end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(n)
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    node_count = map_size(state.nodes)
    edge_count = length(state.edges)
    max_possible = max(node_count * (node_count - 1), 1)

    %{
      node_count: node_count,
      edge_count: edge_count,
      tick: state.tick,
      network_density: Float.round(edge_count / max_possible, 4)
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp ensure_node(nodes, id) do
    Map.put_new(nodes, id, %{id: id, in_degree: 0, out_degree: 0})
  end

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo
end
