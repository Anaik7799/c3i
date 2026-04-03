defmodule Indrajaal.Knowledge.Engine do
  @moduledoc """
  Indrajaal Knowledge Engine (IKE) - The Hippocampus.

  WHAT: Central coordinator for system memory, learning, and retrieval.
  WHY: Enables RAG-Enhanced OODA (Area B) and long-term adaptation.

  Components:
  - SQLiteStore (Relational/Graph)
  - DuckDBStore (Analytical/History)
  - VectorStore (Semantic)

  Directives:
  - Ω₀.2: Universal Intelligence (Requires memory)
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🧠 Starting Indrajaal Knowledge Engine (IKE)...")

    children = [
      Indrajaal.Knowledge.Store.SQLiteStore,
      Indrajaal.Knowledge.Store.DuckDBStore,
      Indrajaal.Knowledge.Vector.Store
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Query the knowledge base for relevant context (RAG).
  """
  def recall(query_text, _opts \\ []) do
    # 1. Vector Search (Placeholder: Need embedding service)
    # 2. SQL Filter
    # 3. DuckDB Aggregate
    Logger.info("🧠 IKE Recall: #{query_text}")

    # For now, fallback to SQL search if vectors aren't passed
    # In a full impl, we'd call an Embedding Service here.

    sql = "SELECT * FROM holons WHERE content LIKE ? LIMIT 5"
    Indrajaal.Knowledge.Store.DuckDBStore.query(sql, ["%#{query_text}%"])
  end

  @doc """
  Store a new experience/memory.
  """
  def memorize(content, metadata \\ %{}) do
    Logger.info("🧠 IKE Memorize: #{inspect(metadata)}")

    # Store in SQLite for structured data
    Indrajaal.Knowledge.Store.SQLiteStore.insert(:memories, %{
      content: content,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Get system context for OODA decision-making.
  Returns relevant knowledge for the current situation.
  """
  def get_context(situation, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Combine multiple knowledge sources
    with {:ok, recent} <- get_recent_events(limit),
         {:ok, similar} <- find_similar_situations(situation, limit) do
      {:ok,
       %{
         recent_events: recent,
         similar_situations: similar,
         timestamp: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Get recent events from history.
  """
  def get_recent_events(limit \\ 10) do
    Indrajaal.Knowledge.Store.DuckDBStore.query(
      "SELECT * FROM holon_history ORDER BY timestamp DESC LIMIT ?",
      [limit]
    )
  end

  @doc """
  Find similar historical situations.
  """
  def find_similar_situations(situation, limit \\ 5) do
    # Check if situation has an embedding attached
    case Map.get(situation, :embedding) do
      nil ->
        Logger.debug("🧠 IKE: No embedding in situation, skipping vector search")
        {:ok, []}

      embedding ->
        Indrajaal.Knowledge.Vector.Store.search(embedding, limit)
    end
  end

  @doc """
  Record an OODA cycle outcome for learning.
  """
  def record_ooda_outcome(cycle_id, observation, decision, outcome) do
    Indrajaal.Knowledge.Store.DuckDBStore.append(:ooda_history, %{
      cycle_id: cycle_id,
      observation: observation,
      decision: decision,
      outcome: outcome,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Get knowledge engine statistics.
  """
  def stats do
    %{
      sqlite: Indrajaal.Knowledge.Store.SQLiteStore.stats(),
      duckdb: Indrajaal.Knowledge.Store.DuckDBStore.stats(),
      status: :active
    }
  end
end
