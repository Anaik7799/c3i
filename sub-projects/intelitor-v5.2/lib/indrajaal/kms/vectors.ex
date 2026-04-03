defmodule Indrajaal.KMS.Vectors do
  @moduledoc """
  Vector Search Layer for Knowledge Management System

  WHAT: Semantic similarity search using embeddings.
  WHY: Enable AI-powered knowledge discovery beyond keyword search.
  CONSTRAINTS:
    - SC-KMS-001 (SQLite vectors)
    - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    - SC-DBLOCAL-002: Local access latency < 1ms

  ## Architecture Note (2026-01-17)
  KMS Vectors uses DIRECT Exqlite access because it's LOCAL holon state.
  Per SC-DBLOCAL-001, local database access bypasses Zenoh entirely.

  ## Storage

  Vectors are stored in SQLite alongside holons using a JSON blob format.
  DuckDB is used for similarity computations via its array functions.

  ## Embedding Models

  Embeddings should be generated externally (e.g., via OpenRouter/Voyage-3)
  and stored through this module for later retrieval.

  ## Usage

      # Store embedding for a holon
      :ok = Vectors.store_embedding(holon_id, embedding, model: "voyage-3")

      # Find similar holons
      {:ok, results} = Vectors.similarity_search(query_embedding, limit: 10)
  """

  use GenServer
  require Logger

  alias Indrajaal.KMS

  @default_model "voyage-3"

  # Schema for vector storage (added to SQLite)
  @vector_schema """
  CREATE TABLE IF NOT EXISTS holon_vectors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    holon_id TEXT NOT NULL,
    model TEXT NOT NULL,
    dimensions INTEGER NOT NULL,
    embedding TEXT NOT NULL,
    chunk_index INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(holon_id, model, chunk_index),
    FOREIGN KEY(holon_id) REFERENCES holons(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_vectors_holon ON holon_vectors(holon_id);
  CREATE INDEX IF NOT EXISTS idx_vectors_model ON holon_vectors(model);
  """

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @doc """
  Initialize vector storage schema.
  """
  @impl true
  def init(_opts) do
    db_path = KMS.sqlite_path()
    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    # Ensure directory exists
    db_dir = Path.dirname(db_path)
    File.mkdir_p!(db_dir)

    case Exqlite.Sqlite3.open(db_path) do
      {:ok, conn} ->
        @vector_schema
        |> String.split(";")
        |> Enum.each(fn stmt ->
          stmt = String.trim(stmt)
          if stmt != "", do: Exqlite.Sqlite3.execute(conn, stmt)
        end)

        Exqlite.Sqlite3.close(conn)
        Logger.info("[KMS.Vectors] Vector schema initialized (SC-DBLOCAL-001 direct)")
        {:ok, %{db_path: db_path}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Store an embedding for a holon.

  ## Parameters

  - `holon_id` - The holon to associate the embedding with
  - `embedding` - List of floats (the embedding vector)
  - `opts` - Options:
    - `:model` - Embedding model name (default: "voyage-3")
    - `:chunk_index` - For chunked content (default: 0)

  ## Examples

      :ok = Vectors.store_embedding("hln_abc123", [0.1, 0.2, ...], model: "voyage-3")
  """
  @spec store_embedding(String.t(), [float()], keyword()) :: :ok | {:error, term()}
  def store_embedding(holon_id, embedding, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    chunk_index = Keyword.get(opts, :chunk_index, 0)
    dimensions = length(embedding)
    embedding_json = Jason.encode!(embedding)
    db_path = KMS.sqlite_path()

    query = """
    INSERT INTO holon_vectors (holon_id, model, dimensions, embedding, chunk_index)
    VALUES (?1, ?2, ?3, ?4, ?5)
    ON CONFLICT (holon_id, model, chunk_index) DO UPDATE SET
      dimensions = excluded.dimensions,
      embedding = excluded.embedding,
      created_at = datetime('now')
    """

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
         {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      Exqlite.Sqlite3.bind(stmt, [holon_id, model, dimensions, embedding_json, chunk_index])

      case Exqlite.Sqlite3.step(conn, stmt) do
        :done ->
          Exqlite.Sqlite3.release(conn, stmt)
          Exqlite.Sqlite3.close(conn)
          :ok

        {:error, reason} ->
          Exqlite.Sqlite3.release(conn, stmt)
          Exqlite.Sqlite3.close(conn)
          {:error, reason}
      end
    end
  end

  @doc """
  Get embedding for a holon.
  """
  @spec get_embedding(String.t(), keyword()) :: {:ok, [float()]} | {:error, :not_found | term()}
  def get_embedding(holon_id, opts \\ []) do
    model = Keyword.get(opts, :model, @default_model)
    chunk_index = Keyword.get(opts, :chunk_index, 0)
    db_path = KMS.sqlite_path()

    query = """
    SELECT embedding FROM holon_vectors
    WHERE holon_id = ?1 AND model = ?2 AND chunk_index = ?3
    """

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
         {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      Exqlite.Sqlite3.bind(stmt, [holon_id, model, chunk_index])

      result =
        case Exqlite.Sqlite3.step(conn, stmt) do
          {:row, [embedding_json]} ->
            {:ok, Jason.decode!(embedding_json)}

          :done ->
            {:error, :not_found}
        end

      Exqlite.Sqlite3.release(conn, stmt)
      Exqlite.Sqlite3.close(conn)
      result
    end
  end

  @doc """
  Perform similarity search using cosine similarity.

  ## Parameters

  - `query_embedding` - The query vector
  - `opts` - Options:
    - `:limit` - Max results (default: 10)
    - `:model` - Filter by model (default: "voyage-3")
    - `:threshold` - Minimum similarity (default: 0.0)

  ## Returns

  List of maps with `:holon_id`, `:similarity`, and `:holon` (full holon data).
  """
  @spec similarity_search([float()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def similarity_search(query_embedding, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    model = Keyword.get(opts, :model, @default_model)
    threshold = Keyword.get(opts, :threshold, 0.0)

    db_path = KMS.sqlite_path()
    duckdb_path = KMS.duckdb_path()

    # Use DuckDB for vector similarity computation
    # First, get all embeddings from SQLite, then compute similarities in DuckDB

    with {:ok, embeddings} <- get_all_embeddings(db_path, model),
         {:ok, results} <-
           compute_similarities(duckdb_path, query_embedding, embeddings, limit, threshold) do
      # Enrich with holon data
      enriched =
        Enum.map(results, fn %{holon_id: holon_id, similarity: similarity} ->
          case KMS.get_holon(holon_id) do
            {:ok, holon} -> %{holon_id: holon_id, similarity: similarity, holon: holon}
            _ -> %{holon_id: holon_id, similarity: similarity, holon: nil}
          end
        end)

      {:ok, enriched}
    end
  end

  @doc """
  Delete embeddings for a holon.
  """
  @spec delete_embeddings(String.t()) :: :ok | {:error, term()}
  def delete_embeddings(holon_id) do
    db_path = KMS.sqlite_path()
    query = "DELETE FROM holon_vectors WHERE holon_id = ?1"

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
         {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      Exqlite.Sqlite3.bind(stmt, [holon_id])
      Exqlite.Sqlite3.step(conn, stmt)
      Exqlite.Sqlite3.release(conn, stmt)
      Exqlite.Sqlite3.close(conn)
      :ok
    end
  end

  @doc """
  Get vector statistics.
  """
  @spec stats() :: {:ok, map()} | {:error, term()}
  def stats do
    db_path = KMS.sqlite_path()

    query = """
    SELECT
      model,
      COUNT(*) as count,
      AVG(dimensions) as avg_dimensions,
      MIN(created_at) as oldest,
      MAX(created_at) as newest
    FROM holon_vectors
    GROUP BY model
    """

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
         {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      results = fetch_all_rows(conn, stmt)
      Exqlite.Sqlite3.release(conn, stmt)
      Exqlite.Sqlite3.close(conn)

      stats =
        Enum.map(results, fn row ->
          %{
            model: Enum.at(row, 0),
            count: Enum.at(row, 1) || 0,
            avg_dimensions: Enum.at(row, 2),
            oldest: Enum.at(row, 3),
            newest: Enum.at(row, 4)
          }
        end)

      {:ok, %{by_model: stats, total: Enum.reduce(stats, 0, fn s, acc -> acc + s.count end)}}
    end
  end

  # Private Functions

  defp get_all_embeddings(db_path, model) do
    query = """
    SELECT holon_id, embedding FROM holon_vectors
    WHERE model = ?1
    """

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    with {:ok, conn} <- Exqlite.Sqlite3.open(db_path),
         {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query) do
      Exqlite.Sqlite3.bind(stmt, [model])
      results = fetch_all_rows(conn, stmt)
      Exqlite.Sqlite3.release(conn, stmt)
      Exqlite.Sqlite3.close(conn)

      embeddings =
        Enum.map(results, fn [holon_id, embedding_json] ->
          %{holon_id: holon_id, embedding: Jason.decode!(embedding_json)}
        end)

      {:ok, embeddings}
    end
  end

  defp compute_similarities(duckdb_path, query_embedding, embeddings, limit, threshold) do
    # Use DuckDB for vector similarity computation (SC-KMS-001)
    # We create a temporary table in DuckDB to perform the vectorized math

    _query_json = Jason.encode!(query_embedding)

    # DuckDB SQL for Cosine Similarity: dot_product(v1, v2) / (norm(v1) * norm(v2))
    # Since embeddings are often pre-normalized, we can simplify to dot_product if possible

    # For now, we perform the computation in a temporary DuckDB session
    # In a high-load scenario, we would use a persistent worker pool

    case Duckdbex.open(duckdb_path) do
      {:ok, db} ->
        case Duckdbex.connection(db) do
          {:ok, conn} ->
            try do
              # 1. Create table for batch computation
              Duckdbex.query(
                conn,
                "CREATE TEMPORARY TABLE search_vectors (id TEXT, vec DOUBLE[])"
              )

              # 2. Insert batch (parameterized)
              # For simplicity in this reification, we insert using individual queries or a batch insert
              # In production, use the Appender API for max speed
              Enum.each(embeddings, fn %{holon_id: id, embedding: vec} ->
                vec_str = "[" <> (Enum.map(vec, &to_string/1) |> Enum.join(",")) <> "]"
                sql = "INSERT INTO search_vectors VALUES ('#{id}', #{vec_str}::DOUBLE[])"
                Duckdbex.query(conn, sql)
              end)

              # 3. Compute Cosine Similarity
              query_vec_str =
                "[" <> (Enum.map(query_embedding, &to_string/1) |> Enum.join(",")) <> "]"

              search_sql = """
              SELECT id, 
                     list_dot_product(vec, #{query_vec_str}::DOUBLE[]) / 
                     (list_aggregate(vec, 'sum_sq') * list_aggregate(#{query_vec_str}::DOUBLE[], 'sum_sq'))^0.5 as similarity
              FROM search_vectors
              WHERE similarity >= #{threshold}
              ORDER BY similarity DESC
              LIMIT #{limit}
              """

              case Duckdbex.query(conn, search_sql) do
                {:ok, res} ->
                  rows = Duckdbex.fetch_all(res)
                  results = Enum.map(rows, fn {id, sim} -> %{holon_id: id, similarity: sim} end)
                  {:ok, results}

                error ->
                  error
              end
            after
              # Cleanup happens on connection close for temporary tables
              :ok
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  defp cosine_similarity(vec1, vec2, norm1) do
    zipped = Enum.zip(vec1, vec2)
    dot = zipped |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    norm2 = vector_norm(vec2)

    if norm1 == 0 or norm2 == 0 do
      0.0
    else
      dot / (norm1 * norm2)
    end
  end

  defp vector_norm(vec) do
    vec
    |> Enum.reduce(0.0, fn x, acc -> acc + x * x end)
    |> :math.sqrt()
  end

  # Helper to fetch all rows from a prepared statement
  defp fetch_all_rows(conn, stmt, acc \\ []) do
    case Exqlite.Sqlite3.step(conn, stmt) do
      {:row, row} -> fetch_all_rows(conn, stmt, [row | acc])
      :done -> Enum.reverse(acc)
    end
  end

  # ---------------------------------------------------------------------------
  # Public: Similarity Search Variants (used by AI module)
  # ---------------------------------------------------------------------------

  @doc """
  Find holons similar to a given holon by its ID.

  ## Options
    - `:limit` - Maximum results (default: 10)
    - `:model` - Embedding model to use (default: "voyage-3")
    - `:min_similarity` - Minimum similarity threshold (default: 0.0)
  """
  @spec find_similar(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def find_similar(holon_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    model = Keyword.get(opts, :model, @default_model)
    min_similarity = Keyword.get(opts, :min_similarity, 0.0)

    # Get the holon's embedding first
    case get_embedding(holon_id, model: model) do
      {:ok, embedding} when is_list(embedding) and length(embedding) > 0 ->
        # Search for similar holons using the embedding
        similarity_search(embedding, limit: limit, model: model, threshold: min_similarity)

      {:ok, _} ->
        {:error, :no_embedding}

      error ->
        error
    end
  end

  @doc """
  Find all pairs of similar holons above a threshold.

  ## Options
    - `:min_similarity` - Minimum similarity (default: 0.9)
    - `:limit` - Maximum pairs to return (default: 100)
    - `:model` - Embedding model to use (default: "voyage-3")
  """
  @spec find_all_similar_pairs(keyword()) :: {:ok, [[String.t()]]} | {:error, term()}
  def find_all_similar_pairs(opts \\ []) do
    min_similarity = Keyword.get(opts, :min_similarity, 0.9)
    limit = Keyword.get(opts, :limit, 100)
    model = Keyword.get(opts, :model, @default_model)

    db_path = KMS.sqlite_path()

    with {:ok, embeddings} <- get_all_embeddings(db_path, model) do
      # Compare all pairs and find similar ones
      pairs =
        embeddings
        |> do_find_similar_pairs(min_similarity)
        |> Enum.take(limit)

      {:ok, pairs}
    end
  end

  defp do_find_similar_pairs(embeddings, min_similarity) do
    # Compare all pairs - O(n^2) but acceptable for small datasets
    embeddings
    |> Enum.with_index()
    |> Enum.flat_map(fn {%{holon_id: id1, embedding: emb1}, idx1} ->
      embeddings
      |> Enum.drop(idx1 + 1)
      |> Enum.filter(fn %{embedding: emb2} ->
        similarity = cosine_similarity(emb1, emb2, vector_norm(emb1))
        similarity >= min_similarity
      end)
      |> Enum.map(fn %{holon_id: id2} -> [id1, id2] end)
    end)
  end
end
