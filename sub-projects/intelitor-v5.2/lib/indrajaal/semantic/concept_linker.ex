defmodule Indrajaal.Semantic.ConceptLinker do
  @moduledoc """
  Concept Linker — L4 Intelligence Layer (Semantic Subsystem)

  ## Design Intent

  Pure module for linking related concepts in the knowledge graph using
  similarity scoring. Concepts are linked by Jaccard similarity over their
  shared attributes or tag sets. Supports clustering of related concepts
  via a simple greedy connected-components approach.

  All functions are referentially transparent — they accept explicit concept
  maps and return computed results without side effects or ETS access.

  ## Concept Representation

  A concept is a map with at minimum:
  - `:id` — unique identifier (String.t())
  - `:tags` — MapSet or list of string attributes used for similarity
  - `:text` — optional raw text (used for token overlap similarity)

  ## STAMP Constraints

  - SC-SEM-002: Concept relationships tracked
  - SC-GRAPH-002: Graph analytics available
  - SC-SMRITI-130: Query results include integrity proofs

  ## Change History

  | Version | Date       | Author | Change                        |
  |---------|------------|--------|-------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Rewrite as pure module        |
  """

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type concept_id :: String.t()
  @type tag :: String.t()

  @type concept :: %{
          id: concept_id(),
          tags: MapSet.t() | [tag()],
          text: String.t() | nil,
          weight: float() | nil
        }

  @type link :: %{
          from: concept_id(),
          to: concept_id(),
          similarity: float(),
          shared_tags: [tag()]
        }

  @type cluster :: %{
          cluster_id: non_neg_integer(),
          members: [concept_id()],
          cohesion: float()
        }

  # ---------------------------------------------------------------------------
  # Public API — Pure Functions
  # ---------------------------------------------------------------------------

  @doc """
  Link two concept IDs by computing their similarity from the concept map.

  Accepts a map of `%{concept_id => concept}` as the knowledge base.
  Returns a `link` struct with similarity score and shared tags, or
  `{:error, :not_found}` if either concept is missing.

  ## Examples

      iex> concepts = %{
      ...>   "a" => %{id: "a", tags: MapSet.new(["x", "y"])},
      ...>   "b" => %{id: "b", tags: MapSet.new(["y", "z"])}
      ...> }
      iex> Indrajaal.Semantic.ConceptLinker.link("a", "b", concepts)
      {:ok, %{from: "a", to: "b", similarity: 0.3333, shared_tags: ["y"]}}
  """
  @spec link(concept_id(), concept_id(), %{concept_id() => concept()}) ::
          {:ok, link()} | {:error, :not_found}
  def link(from_id, to_id, concepts) when is_map(concepts) do
    with {:ok, from_concept} <- fetch_concept(from_id, concepts),
         {:ok, to_concept} <- fetch_concept(to_id, concepts) do
      sim = similarity(from_concept, to_concept)
      shared = shared_tags(from_concept, to_concept)

      {:ok,
       %{
         from: from_id,
         to: to_id,
         similarity: sim,
         shared_tags: shared
       }}
    end
  end

  @doc """
  Compute Jaccard similarity between two concepts.

  Jaccard(A, B) = |A ∩ B| / |A ∪ B| over the tag sets.
  Returns 0.0 when both tag sets are empty, 1.0 for identical sets.
  """
  @spec similarity(concept(), concept()) :: float()
  def similarity(%{tags: tags_a} = _a, %{tags: tags_b} = _b) do
    set_a = to_mapset(tags_a)
    set_b = to_mapset(tags_b)

    intersection = MapSet.intersection(set_a, set_b) |> MapSet.size()
    union = MapSet.union(set_a, set_b) |> MapSet.size()

    if union == 0 do
      0.0
    else
      Float.round(intersection / union, 4)
    end
  end

  @doc """
  Find all concepts related to `concept_id` above a similarity threshold.

  Scans the full concept map and returns links for concepts with
  similarity >= `threshold` (default 0.3). Excludes self-links.
  Results are sorted by similarity descending.
  """
  @spec related(concept_id(), %{concept_id() => concept()}, float()) :: [link()]
  def related(concept_id, concepts, threshold \\ 0.3)
      when is_map(concepts) and is_float(threshold) do
    case fetch_concept(concept_id, concepts) do
      {:error, :not_found} ->
        []

      {:ok, source_concept} ->
        concepts
        |> Enum.reject(fn {id, _} -> id == concept_id end)
        |> Enum.flat_map(fn {other_id, other_concept} ->
          sim = similarity(source_concept, other_concept)

          if sim >= threshold do
            [
              %{
                from: concept_id,
                to: other_id,
                similarity: sim,
                shared_tags: shared_tags(source_concept, other_concept)
              }
            ]
          else
            []
          end
        end)
        |> Enum.sort_by(& &1.similarity, :desc)
    end
  end

  @doc """
  Cluster concepts by similarity into connected components.

  Builds a similarity graph where nodes are concept IDs and edges connect
  pairs with similarity >= `threshold` (default 0.3). Returns the connected
  components of this graph as clusters, each with a cohesion score (mean
  intra-cluster similarity).

  Results are sorted by cluster size descending.
  """
  @spec cluster(%{concept_id() => concept()}, float()) :: [cluster()]
  def cluster(concepts, threshold \\ 0.3)
      when is_map(concepts) and is_float(threshold) do
    if map_size(concepts) == 0 do
      []
    else
      concept_ids = Map.keys(concepts)
      adj = build_similarity_graph(concepts, concept_ids, threshold)
      components = connected_components(concept_ids, adj)

      components
      |> Enum.with_index()
      |> Enum.map(fn {members, idx} ->
        cohesion = compute_cohesion(members, concepts)
        %{cluster_id: idx, members: members, cohesion: cohesion}
      end)
      |> Enum.sort_by(fn c -> length(c.members) end, :desc)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — Tag Utilities
  # ---------------------------------------------------------------------------

  defp to_mapset(%MapSet{} = s), do: s
  defp to_mapset(list) when is_list(list), do: MapSet.new(list)
  defp to_mapset(_), do: MapSet.new()

  defp shared_tags(a, b) do
    set_a = to_mapset(a.tags)
    set_b = to_mapset(b.tags)
    MapSet.intersection(set_a, set_b) |> MapSet.to_list() |> Enum.sort()
  end

  defp fetch_concept(id, concepts) do
    case Map.get(concepts, id) do
      nil -> {:error, :not_found}
      concept -> {:ok, concept}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — Clustering
  # ---------------------------------------------------------------------------

  defp build_similarity_graph(concepts, ids, threshold) do
    pairs = for a <- ids, b <- ids, a < b, do: {a, b}

    Enum.reduce(pairs, %{}, fn {a, b}, acc ->
      ca = Map.get(concepts, a)
      cb = Map.get(concepts, b)
      sim = similarity(ca, cb)

      if sim >= threshold do
        acc
        |> Map.update(a, [b], &[b | &1])
        |> Map.update(b, [a], &[a | &1])
      else
        acc
      end
    end)
  end

  defp connected_components(all_ids, adj) do
    {components, _visited} =
      Enum.reduce(all_ids, {[], MapSet.new()}, fn id, {comps, visited} ->
        if MapSet.member?(visited, id) do
          {comps, visited}
        else
          component = bfs_component(id, adj)
          new_visited = Enum.reduce(component, visited, &MapSet.put(&2, &1))
          {[component | comps], new_visited}
        end
      end)

    components
  end

  defp bfs_component(start, adj) do
    do_bfs_component([start], MapSet.new([start]), adj)
  end

  defp do_bfs_component([], visited, _adj), do: MapSet.to_list(visited)

  defp do_bfs_component([current | rest], visited, adj) do
    neighbors =
      Map.get(adj, current, [])
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
    do_bfs_component(rest ++ neighbors, new_visited, adj)
  end

  defp compute_cohesion(members, _concepts) when length(members) < 2, do: 1.0

  defp compute_cohesion(members, concepts) do
    pairs = for a <- members, b <- members, a < b, do: {a, b}

    if Enum.empty?(pairs) do
      1.0
    else
      total_sim =
        Enum.reduce(pairs, 0.0, fn {a, b}, sum ->
          ca = Map.get(concepts, a)
          cb = Map.get(concepts, b)
          if ca && cb, do: sum + similarity(ca, cb), else: sum
        end)

      Float.round(total_sim / length(pairs), 4)
    end
  end
end
