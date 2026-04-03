defmodule Indrajaal.Knowledge.Vector.Store do
  @moduledoc """
  Semantic Vector Search Engine for IKE.

  WHAT: In-memory vector store powered by Nx, synced with the shared DuckDB.
  WHY: Enables fast cosine similarity search for RAG (Retrieval Augmented Generation).
  HOW:
    1. Loads vectors from DuckDB `vectors` table on startup.
    2. Converts BLOBs to Nx tensors.
    3. Performs dot-product similarity search.

  Shared Schema (F#): vectors (uuid UUID, vector_id VARCHAR, model VARCHAR, embedding BLOB)
  """

  use GenServer
  require Logger
  alias Indrajaal.Knowledge.Store.DuckDBStore

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Search for similar items given a query embedding.
  Returns: [{uuid, score}, ...] sorted by score desc.
  """
  def search(query_embedding, limit \\ 5) do
    GenServer.call(__MODULE__, {:search, query_embedding, limit})
  end

  @doc """
  Force a refresh of vectors from DuckDB.
  """
  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  @doc """
  Get store stats.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    Logger.info("🧠 IKE: Starting Vector Store...")
    # Load vectors asynchronously to not block startup
    send(self(), :load_vectors)
    {:ok, %{vectors: nil, ids: [], count: 0, status: :loading}}
  end

  @impl true
  def handle_info(:load_vectors, state) do
    Logger.info("🧠 IKE: Loading vectors from DuckDB...")

    case DuckDBStore.get_all_vectors() do
      {:ok, rows} ->
        {ids, tensor} = process_rows(rows)
        count = length(ids)
        Logger.info("🧠 IKE: Loaded #{count} vectors into memory.")
        {:noreply, %{state | vectors: tensor, ids: ids, count: count, status: :ready}}

      error ->
        Logger.error("🧠 IKE: Failed to load vectors: #{inspect(error)}")
        # Retry logic could go here
        {:noreply, %{state | status: :error}}
    end
  end

  @impl true
  def handle_call({:search, _query, _limit}, _from, %{status: status} = state)
      when status != :ready do
    {:reply, {:error, :not_ready}, state}
  end

  @impl true
  def handle_call({:search, query_embedding, limit}, _from, state) do
    # 1. Ensure query is a tensor
    q = Nx.tensor(query_embedding)

    # 2. Compute Cosine Similarity
    # Assuming normalized vectors: Dot product is cosine similarity
    # If not normalized: Nx.dot(A, B) / (Nx.norm(A) * Nx.norm(B))

    # We'll implement dot product for speed, assuming normalized inputs from F#
    # Matrix-Vector multiplication: (N x D) . (D) -> (N)
    scores = Nx.dot(state.vectors, q)

    # 3. Get top K
    # Nx doesn't have a direct top_k for 1D yet in stable, so we pull to elixir list
    # This is fine for <100k vectors. For larger, use HNSW lib.

    flat_scores = Nx.to_flat_list(scores)

    results =
      Enum.zip(state.ids, flat_scores)
      |> Enum.sort_by(fn {_id, score} -> score end, :desc)
      |> Enum.take(limit)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, %{count: state.count, status: state.status}, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    send(self(), :load_vectors)
    {:noreply, state}
  end

  # ============================================================================
  # Internal Helpers
  # ============================================================================

  defp process_rows(rows) do
    # rows is list of [uuid, embedding_blob]
    # We need to parse the blob (likely f32 array) into a tensor

    {ids, binaries} =
      rows
      |> Enum.reduce({[], []}, fn [uuid, blob], {id_acc, bin_acc} ->
        {[uuid | id_acc], [blob | bin_acc]}
      end)

    # Reverse to maintain order (though not strictly necessary)
    ids = Enum.reverse(ids)

    # Convert list of binaries to a single tensor
    # Assuming 1536 dims (OpenAI) or 384 (MiniLM) float32
    # Check first blob size to determine shape

    if binaries == [] do
      {[], nil}
    else
      # Stack them
      tensors =
        Enum.map(binaries, fn bin ->
          # Assuming float32
          Nx.from_binary(bin, {:f, 32})
        end)

      full_tensor = Nx.stack(tensors)
      {ids, full_tensor}
    end
  end
end
