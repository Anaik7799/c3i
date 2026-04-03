defmodule Indrajaal.SMRITI.Mesh.VectorStore do
  @moduledoc """
  L5: Local Vector Store for SMRITI Knowledge Mesh.

  WHAT: Semantic similarity search for SMRITI's sensory and cognitive layers.
  WHY: Enable AI-powered knowledge discovery and intent matching.
  HOW: Delegates to KMS.Vectors for storage, uses Nx for fast similarity.

  CONSTRAINTS:
    - SC-SMRITI-001: Vector search latency < 100ms
    - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct
    - SC-AI-001: AI agents persist context via SMRITI

  ## Architecture

  SMRITI VectorStore provides the semantic layer for the biomorphic knowledge mesh:

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                    SMRITI KNOWLEDGE MESH                     │
  ├─────────────────────────────────────────────────────────────┤
  │  Sensory Layer (L1-L2)                                      │
  │    ├─ FileWatcher → Embedding generation                    │
  │    └─ EventStream → Real-time indexing                      │
  │                                                              │
  │  Vector Layer (L3-L4) ← THIS MODULE                         │
  │    ├─ VectorStore.search/2 → Semantic search                │
  │    ├─ VectorStore.similarity/2 → Nx tensor ops              │
  │    └─ KMS.Vectors → SQLite storage                          │
  │                                                              │
  │  Cognitive Layer (L5-L6)                                    │
  │    ├─ IntentMatcher → Query understanding                   │
  │    └─ KnowledgeGraph → Holon relationships                  │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Usage

      # Search for similar holons by embedding
      {:ok, results} = VectorStore.search(query_embedding, 10)

      # Compute similarity between two vectors
      score = VectorStore.similarity(vec_a, vec_b)

      # Store embedding for a holon
      :ok = VectorStore.store(holon_id, embedding)

      # Find holons similar to a given holon
      {:ok, similar} = VectorStore.find_similar(holon_id, limit: 5)
  """

  require Logger

  alias Indrajaal.KMS.Vectors

  @default_limit 10
  @default_model "voyage-3"

  # ---------------------------------------------------------------------------
  # Public API: Similarity Computation (Nx-based for speed)
  # ---------------------------------------------------------------------------

  @doc """
  Computes cosine similarity between two embedding lists using Nx tensors.

  This is a fast, in-memory computation suitable for:
  - Comparing two specific vectors
  - Real-time similarity checks
  - Pre-filtering before database search

  ## Examples

      iex> VectorStore.similarity([0.1, 0.2, 0.3], [0.1, 0.2, 0.3])
      1.0

      iex> VectorStore.similarity([1.0, 0.0, 0.0], [0.0, 1.0, 0.0])
      0.0
  """
  @spec similarity([float()], [float()]) :: float()
  def similarity(vec_a, vec_b) when is_list(vec_a) and is_list(vec_b) do
    # Convert to tensors
    t_a = Nx.tensor(vec_a)
    t_b = Nx.tensor(vec_b)

    # Cosine Similarity = (A ⋅ B) / (||A|| * ||B||)
    dot_product = Nx.dot(t_a, t_b)
    norm_a = Nx.LinAlg.norm(t_a)
    norm_b = Nx.LinAlg.norm(t_b)

    Nx.to_number(Nx.divide(dot_product, Nx.multiply(norm_a, norm_b)))
  end

  # ---------------------------------------------------------------------------
  # Public API: Database Search (KMS.Vectors delegation)
  # ---------------------------------------------------------------------------

  @doc """
  Searches the SMRITI knowledge mesh for semantically similar holons.

  Delegates to `KMS.Vectors.similarity_search/2` for persistent storage search.

  ## Parameters

  - `query_vector` - The embedding vector to search with
  - `limit` - Maximum number of results (default: 10)

  ## Options (via keyword list as second arg or opts)

  - `:model` - Embedding model filter (default: "voyage-3")
  - `:threshold` - Minimum similarity score (default: 0.0)

  ## Returns

  `{:ok, results}` where results is a list of maps:
  ```
  [
    %{holon_id: "hln_abc123", similarity: 0.95, holon: %{...}},
    %{holon_id: "hln_def456", similarity: 0.87, holon: %{...}}
  ]
  ```

  ## Examples

      # Basic search
      {:ok, results} = VectorStore.search(query_embedding, 5)

      # With options
      {:ok, results} = VectorStore.search(query_embedding, limit: 10, threshold: 0.8)
  """
  @spec search([float()], non_neg_integer() | keyword()) :: {:ok, [map()]} | {:error, term()}
  def search(query_vector, limit_or_opts \\ @default_limit)

  def search(query_vector, limit) when is_list(query_vector) and is_integer(limit) do
    search(query_vector, limit: limit)
  end

  def search(query_vector, opts) when is_list(query_vector) and is_list(opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    model = Keyword.get(opts, :model, @default_model)
    threshold = Keyword.get(opts, :threshold, 0.0)

    Logger.info(
      "[SMRITI.VectorStore] Performing semantic search (limit=#{limit}, model=#{model})"
    )

    start_time = System.monotonic_time(:microsecond)

    result =
      Vectors.similarity_search(query_vector,
        limit: limit,
        model: model,
        threshold: threshold
      )

    elapsed_us = System.monotonic_time(:microsecond) - start_time

    # Telemetry for observability
    :telemetry.execute(
      [:smriti, :vector_store, :search],
      %{duration_us: elapsed_us, result_count: result_count(result)},
      %{model: model, limit: limit}
    )

    case result do
      {:ok, results} ->
        Logger.debug(
          "[SMRITI.VectorStore] Search completed in #{elapsed_us}μs, found #{length(results)} results"
        )

        {:ok, results}

      {:error, reason} = error ->
        Logger.warning("[SMRITI.VectorStore] Search failed: #{inspect(reason)}")
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Public API: Storage Operations
  # ---------------------------------------------------------------------------

  @doc """
  Stores an embedding for a holon in the SMRITI knowledge mesh.

  Delegates to `KMS.Vectors.store_embedding/3`.

  ## Parameters

  - `holon_id` - The holon identifier
  - `embedding` - The embedding vector (list of floats)
  - `opts` - Options:
    - `:model` - Embedding model name (default: "voyage-3")
    - `:chunk_index` - For chunked content (default: 0)

  ## Examples

      :ok = VectorStore.store("hln_abc123", embedding)
      :ok = VectorStore.store("hln_abc123", embedding, model: "text-embedding-3-small")
  """
  @spec store(String.t(), [float()], keyword()) :: :ok | {:error, term()}
  def store(holon_id, embedding, opts \\ []) when is_binary(holon_id) and is_list(embedding) do
    model = Keyword.get(opts, :model, @default_model)

    Logger.debug(
      "[SMRITI.VectorStore] Storing embedding for #{holon_id} (dims=#{length(embedding)}, model=#{model})"
    )

    result = Vectors.store_embedding(holon_id, embedding, opts)

    # Telemetry
    :telemetry.execute(
      [:smriti, :vector_store, :store],
      %{dimensions: length(embedding)},
      %{holon_id: holon_id, model: model, success: result == :ok}
    )

    result
  end

  @doc """
  Retrieves the embedding for a holon.

  Delegates to `KMS.Vectors.get_embedding/2`.
  """
  @spec get(String.t(), keyword()) :: {:ok, [float()]} | {:error, :not_found | term()}
  def get(holon_id, opts \\ []) when is_binary(holon_id) do
    Vectors.get_embedding(holon_id, opts)
  end

  @doc """
  Deletes all embeddings for a holon.

  Delegates to `KMS.Vectors.delete_embeddings/1`.
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(holon_id) when is_binary(holon_id) do
    Logger.info("[SMRITI.VectorStore] Deleting embeddings for #{holon_id}")
    Vectors.delete_embeddings(holon_id)
  end

  # ---------------------------------------------------------------------------
  # Public API: Advanced Search
  # ---------------------------------------------------------------------------

  @doc """
  Finds holons similar to a given holon by its ID.

  Retrieves the holon's embedding and uses it to search for similar holons.

  ## Options

  - `:limit` - Maximum results (default: 10)
  - `:model` - Embedding model (default: "voyage-3")
  - `:min_similarity` - Minimum similarity threshold (default: 0.0)

  ## Examples

      {:ok, similar} = VectorStore.find_similar("hln_abc123", limit: 5)
  """
  @spec find_similar(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def find_similar(holon_id, opts \\ []) when is_binary(holon_id) do
    Logger.info("[SMRITI.VectorStore] Finding holons similar to #{holon_id}")
    Vectors.find_similar(holon_id, opts)
  end

  @doc """
  Returns statistics about the vector store.

  ## Returns

  ```
  {:ok, %{
    by_model: [%{model: "voyage-3", count: 1500, ...}],
    total: 1500
  }}
  ```
  """
  @spec stats() :: {:ok, map()} | {:error, term()}
  def stats do
    Vectors.stats()
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp result_count({:ok, results}), do: length(results)
  defp result_count(_), do: 0
end
