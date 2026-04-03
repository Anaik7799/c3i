defmodule Indrajaal.Semantic.EmbeddingStore do
  @moduledoc """
  Embedding Store — L4 Intelligence Layer (Semantic Subsystem)

  ## Design Intent

  GenServer managing vector embeddings for semantic search. Uses ETS for
  fast in-process lookup with O(n) nearest-neighbor scan via cosine
  similarity. Embeddings are L2-normalized on ingestion for efficient dot
  product similarity computation.

  Multiple embedding spaces are supported (`:text`, `:code`, `:concept`),
  each stored under a `{space, doc_id}` composite key.

  ## STAMP Constraints

  - SC-SEM-001: Semantic analysis pipeline observable
  - SC-SMRITI-132: Semantic search uses vector embeddings
  - SC-SMRITI-133: Query timeout < 500ms

  ## Change History

  | Version | Date       | Author | Change                         |
  |---------|------------|--------|--------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Rewrite with required API      |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @table :semantic_embeddings
  @meta_table :embedding_meta
  @max_per_space 50_000

  # Default embedding dimensionality (text-embedding-3-small)
  @default_dims 1536

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type space :: :text | :code | :concept | atom()
  @type doc_id :: String.t()
  @type embedding :: [float()]
  @type similarity :: float()

  @type search_result :: %{
          doc_id: doc_id(),
          similarity: similarity(),
          metadata: map()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Store an embedding vector for a document in a given space.

  The embedding is L2-normalized before storage for efficient cosine
  similarity computation. Metadata is stored separately.
  """
  @spec store(space(), doc_id(), embedding()) :: :ok
  def store(space, doc_id, embedding) when is_list(embedding) do
    GenServer.call(@name, {:store, space, doc_id, embedding, %{}})
  end

  @doc """
  Query the embedding store for nearest neighbors.

  Performs brute-force cosine similarity over all embeddings in the given
  space. Returns a list of `search_result` maps sorted by similarity
  descending, limited to `k` results (default 10).
  """
  @spec query(space(), embedding()) :: [search_result()]
  def query(space, query_embedding) when is_list(query_embedding) do
    GenServer.call(@name, {:query, space, query_embedding, 10}, 10_000)
  end

  @doc """
  Find the `k` nearest neighbors to the query embedding in the given space.

  Same as `query/2` but with explicit k parameter.
  """
  @spec nearest(space(), embedding(), pos_integer()) :: [search_result()]
  def nearest(space, query_embedding, k \\ 10)
      when is_list(query_embedding) and is_integer(k) and k > 0 do
    GenServer.call(@name, {:query, space, query_embedding, k}, 10_000)
  end

  @doc """
  Return the default embedding dimensionality for this store.

  This is the dimensionality expected for ingested vectors. Vectors with
  different dimensions can be stored but similarity computation between
  different-dimension vectors returns 0.0.
  """
  @spec dimensions() :: pos_integer()
  def dimensions do
    @default_dims
  end

  @doc """
  Delete an embedding from the store.
  """
  @spec delete(space(), doc_id()) :: :ok | {:error, :not_found}
  def delete(space, doc_id) do
    GenServer.call(@name, {:delete, space, doc_id})
  end

  @doc "Return store statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    ensure_ets_tables()

    state = %{
      total_stored: 0,
      total_queries: 0,
      space_counts: %{}
    }

    Logger.info(
      "[EmbeddingStore] Online — dims=#{@default_dims} max_per_space=#{@max_per_space} [SC-SEM-001]"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:store, space, doc_id, embedding, metadata}, _from, state) do
    key = {space, doc_id}
    norm = l2_norm(embedding)
    normalized = if norm > 0, do: Enum.map(embedding, &(&1 / norm)), else: embedding

    :ets.insert(@table, {key, normalized, length(embedding)})
    :ets.insert(@meta_table, {key, metadata, System.system_time(:millisecond)})

    prune_space_if_needed(space)

    space_counts = Map.update(state.space_counts, space, 1, &(&1 + 1))
    state2 = %{state | total_stored: state.total_stored + 1, space_counts: space_counts}

    emit_telemetry(:stored, %{space: space, dim: length(embedding)})

    {:reply, :ok, state2}
  end

  @impl true
  def handle_call({:query, space, query_embedding, k}, _from, state) do
    query_norm = l2_norm(query_embedding)

    normalized_query =
      if query_norm > 0,
        do: Enum.map(query_embedding, &(&1 / query_norm)),
        else: query_embedding

    results =
      @table
      |> :ets.tab2list()
      |> Enum.filter(fn {{s, _}, _, _} -> s == space end)
      |> Enum.map(fn {{_s, did}, emb, _dim} ->
        sim = dot_product(normalized_query, emb)
        meta = lookup_meta(space, did)
        %{doc_id: did, similarity: Float.round(sim, 6), metadata: meta}
      end)
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(k)

    state2 = %{state | total_queries: state.total_queries + 1}
    emit_telemetry(:queried, %{space: space, k: k, hits: length(results)})

    {:reply, results, state2}
  end

  @impl true
  def handle_call({:delete, space, doc_id}, _from, state) do
    key = {space, doc_id}

    case :ets.lookup(@table, key) do
      [{^key, _, _}] ->
        :ets.delete(@table, key)
        :ets.delete(@meta_table, key)

        space_counts = Map.update(state.space_counts, space, 0, &max(&1 - 1, 0))
        {:reply, :ok, %{state | space_counts: space_counts}}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       total_stored: state.total_stored,
       total_queries: state.total_queries,
       space_counts: state.space_counts,
       active_embeddings: :ets.info(@table, :size),
       default_dims: @default_dims
     }, state}
  end

  # ---------------------------------------------------------------------------
  # Private — Vector Math
  # ---------------------------------------------------------------------------

  defp l2_norm(vec) do
    vec
    |> Enum.reduce(0.0, fn x, acc -> acc + x * x end)
    |> :math.sqrt()
  end

  # Dot product of pre-normalized vectors equals cosine similarity
  defp dot_product(a, b) when length(a) == length(b) do
    Enum.zip(a, b)
    |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    |> max(-1.0)
    |> min(1.0)
  end

  defp dot_product(_, _), do: 0.0

  # ---------------------------------------------------------------------------
  # Private — ETS Helpers
  # ---------------------------------------------------------------------------

  defp lookup_meta(space, doc_id) do
    case :ets.lookup(@meta_table, {space, doc_id}) do
      [{_, meta, _ts}] -> meta
      [] -> %{}
    end
  end

  defp prune_space_if_needed(space) do
    space_entries =
      @meta_table
      |> :ets.tab2list()
      |> Enum.filter(fn {{s, _}, _, _} -> s == space end)

    if length(space_entries) > @max_per_space do
      # Remove oldest quarter
      to_remove =
        space_entries
        |> Enum.sort_by(fn {_, _, ts} -> ts end)
        |> Enum.take(div(length(space_entries), 4))

      Enum.each(to_remove, fn {key, _, _} ->
        :ets.delete(@table, key)
        :ets.delete(@meta_table, key)
      end)
    end
  rescue
    _ -> :ok
  end

  defp ensure_ets_tables do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    if :ets.whereis(@meta_table) == :undefined do
      :ets.new(@meta_table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  defp emit_telemetry(event, meta) do
    :telemetry.execute(
      [:indrajaal, :semantic, :embedding, event],
      %{timestamp: System.system_time(:millisecond)},
      meta
    )
  rescue
    _ -> :ok
  end
end
