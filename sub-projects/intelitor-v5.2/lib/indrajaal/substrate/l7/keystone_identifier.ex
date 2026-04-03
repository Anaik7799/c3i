defmodule Indrajaal.Substrate.L7.KeystoneIdentifier do
  @moduledoc """
  ## Design Intent
  L7 substrate Keystone Identifier — pure functional keystone species/service finder.
  Identifies keystone nodes in an ecosystem network: those whose removal would cause
  disproportionate disruption relative to their apparent abundance or resource usage.

  Keystone score formula (modified Power's index):
    keystone_score = (network_impact / presence_ratio) × connectivity_weight

  Where:
    - network_impact = fraction of links lost on node removal (normalized)
    - presence_ratio = node's biomass/traffic share (0.0–1.0)
    - connectivity_weight = (degree / max_degree) smoothed with EMA

  A node is classified as :keystone when score ≥ keystone_threshold (default 2.0).

  ## STAMP Constraints
  - SC-ECO-001: Ecosystem boundaries — ENFORCED (L7)
  - SC-GRAPH-001: Graph operations — ENFORCED
  - SC-ECO-002: External API gateway — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author | Change                |
  |---------|------------|--------|-----------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial morphogenesis |
  """

  @keystone_threshold 2.0
  @max_nodes 256

  @type node_id :: String.t()

  @type node_entry :: %{
          id: node_id(),
          presence_ratio: float(),
          degree: non_neg_integer(),
          keystone_score: float(),
          classification: :keystone | :ordinary | :peripheral
        }

  @type link :: {node_id(), node_id()}

  @type t :: %__MODULE__{
          nodes: %{node_id() => node_entry()},
          links: [link()],
          keystone_threshold: float()
        }

  defstruct nodes: %{},
            links: [],
            keystone_threshold: @keystone_threshold

  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts \\ []) do
    threshold = Keyword.get(opts, :keystone_threshold, @keystone_threshold)
    node_specs = Keyword.get(opts, :nodes, [])

    cond do
      length(node_specs) > @max_nodes ->
        {:error, "nodes exceeds max #{@max_nodes}"}

      not is_number(threshold) or threshold <= 0 ->
        {:error, "keystone_threshold must be a positive number"}

      true ->
        nodes =
          Map.new(node_specs, fn spec ->
            id = Map.get(spec, :id, "node_#{:erlang.unique_integer([:positive])}")
            presence = Map.get(spec, :presence_ratio, 0.5) |> clamp(0.0, 1.0)

            {id,
             %{
               id: id,
               presence_ratio: presence,
               degree: 0,
               keystone_score: 0.0,
               classification: :peripheral
             }}
          end)

        state = %__MODULE__{nodes: nodes, keystone_threshold: threshold}
        {:ok, state}
    end
  end

  @doc """
  Add a link between two nodes and recompute keystone scores.
  Nodes are auto-registered with default presence ratio of 0.5.
  """
  @spec add_link(t(), node_id(), node_id()) :: {:ok, t()} | {:error, String.t()}
  def add_link(%__MODULE__{} = state, node_a, node_b)
      when is_binary(node_a) and is_binary(node_b) do
    cond do
      node_a == node_b ->
        {:error, "self-links are not allowed"}

      {node_a, node_b} in state.links or {node_b, node_a} in state.links ->
        {:error, "link already exists"}

      true ->
        nodes =
          state.nodes
          |> ensure_node(node_a)
          |> ensure_node(node_b)

        links = [{node_a, node_b} | state.links]
        new_state = %{state | nodes: nodes, links: links}
        {:ok, recompute_scores(new_state)}
    end
  end

  @doc """
  Return all keystone nodes sorted by score descending.
  """
  @spec keystones(t()) :: [node_entry()]
  def keystones(%__MODULE__{} = state) do
    state.nodes
    |> Map.values()
    |> Enum.filter(fn n -> n.classification == :keystone end)
    |> Enum.sort_by(& &1.keystone_score, :desc)
  end

  @doc """
  Simulate removal of a node and return the fraction of lost links.
  """
  @spec removal_impact(t(), node_id()) :: float()
  def removal_impact(%__MODULE__{} = state, node_id) when is_binary(node_id) do
    total = length(state.links)

    if total == 0 do
      0.0
    else
      lost =
        Enum.count(state.links, fn {a, b} -> a == node_id or b == node_id end)

      Float.round(lost / total, 4)
    end
  end

  @spec status(t()) :: map()
  def status(%__MODULE__{} = state) do
    keystone_count = state.nodes |> Map.values() |> Enum.count(&(&1.classification == :keystone))

    %{
      node_count: map_size(state.nodes),
      link_count: length(state.links),
      keystone_count: keystone_count,
      keystone_threshold: state.keystone_threshold,
      top_keystone:
        case keystones(state) do
          [] -> nil
          [top | _] -> %{id: top.id, score: top.keystone_score}
        end
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp ensure_node(nodes, id) do
    Map.put_new(nodes, id, %{
      id: id,
      presence_ratio: 0.5,
      degree: 0,
      keystone_score: 0.0,
      classification: :peripheral
    })
  end

  defp recompute_scores(%__MODULE__{} = state) do
    total_links = length(state.links)
    max_degree = compute_max_degree(state.nodes, state.links)

    nodes =
      Map.new(state.nodes, fn {id, node} ->
        degree = count_degree(state.links, id)
        impact = if total_links > 0, do: count_degree(state.links, id) / total_links, else: 0.0
        conn_weight = if max_degree > 0, do: degree / max_degree, else: 0.0
        presence = max(node.presence_ratio, 0.001)
        score = Float.round(impact / presence * conn_weight, 4)

        classification =
          cond do
            score >= state.keystone_threshold -> :keystone
            degree > 0 -> :ordinary
            true -> :peripheral
          end

        {id, %{node | degree: degree, keystone_score: score, classification: classification}}
      end)

    %{state | nodes: nodes}
  end

  defp count_degree(links, node_id) do
    Enum.count(links, fn {a, b} -> a == node_id or b == node_id end)
  end

  defp compute_max_degree(nodes, links) do
    Enum.reduce(Map.keys(nodes), 0, fn id, acc ->
      d = count_degree(links, id)
      max(acc, d)
    end)
  end

  defp clamp(v, lo, hi) when is_number(v), do: v |> max(lo) |> min(hi)
  defp clamp(_v, lo, _hi), do: lo
end
