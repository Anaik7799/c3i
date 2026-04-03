defmodule Indrajaal.Smriti.Cognition.FullTextSearch do
  @moduledoc """
  SMRITI Full-Text Search using SQLite FTS5.

  ## WHAT
  Provides full-text search over the SMRITI knowledge store using SQLite FTS5
  virtual tables with relevance ranking via the BM25 algorithm.

  ## WHY
  Enables fast, relevant knowledge retrieval across all ingested documents,
  supporting the Synapse's semantic recall and the Cortex AI recommendations.

  ## CONSTRAINTS
  - SC-SMRITI-131: Full-text search uses FTS5
  - SC-SMRITI-133: Query timeout < 500ms
  - SC-DBLOCAL-001: Local holon DB access MUST be direct
  - SC-DBLOCAL-004: WAL mode for SQLite

  ## Architecture

  ```
  FTS5 Virtual Table: smriti_fts
    ├── content='smriti_entries'    (source table)
    ├── content_rowid='rowid'
    └── tokenize='porter ascii'     (stemming for English)
  ```

  ## Change History
  | Version | Date       | Author | Change                     |
  |---------|------------|--------|----------------------------|
  | 21.3.0  | 2026-03-23 | Claude | Initial FTS5 implementation|
  """

  use GenServer
  require Logger

  @table_name :smriti_fts
  @default_db_path "data/holons/smriti/smriti.sqlite3"
  @default_limit 20
  @type search_result :: %{
          id: String.t(),
          title: String.t(),
          content: String.t(),
          rank: float(),
          snippet: String.t(),
          tags: [String.t()],
          created_at: DateTime.t() | nil
        }

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Search the SMRITI knowledge store using FTS5 BM25 relevance ranking.

  Returns results ordered by relevance (highest first).

  ## Parameters
  - query: Full-text search query (supports FTS5 syntax: AND, OR, NOT, phrase)
  - opts:
    - limit: Max results (default: 20)
    - offset: Skip N results (default: 0)
    - tags: Filter by tags list (optional)

  ## Examples

      iex> FullTextSearch.search("guardian safety constraint")
      {:ok, [%{id: "...", title: "...", rank: -1.5, ...}]}

      iex> FullTextSearch.search("zenoh OR mesh", limit: 5)
      {:ok, [%{...}, ...]}
  """
  @spec search(String.t(), keyword()) :: {:ok, [search_result()]} | {:error, term()}
  def search(query, opts \\ []) when is_binary(query) do
    GenServer.call(__MODULE__, {:search, query, opts}, 5_000)
  catch
    :exit, _ -> {:error, :not_available}
  end

  @doc """
  Index a new entry in the FTS5 virtual table.

  Called automatically when new knowledge is ingested. Also usable directly
  for testing or manual indexing.

  ## Parameters
  - entry: Map with :id, :title, :content, :tags (optional), :created_at (optional)
  """
  @spec index_entry(map()) :: :ok | {:error, term()}
  def index_entry(entry) when is_map(entry) do
    GenServer.call(__MODULE__, {:index, entry}, 5_000)
  catch
    :exit, _ -> {:error, :not_available}
  end

  @doc """
  Remove an entry from the FTS5 index by ID.
  """
  @spec remove_entry(String.t()) :: :ok | {:error, term()}
  def remove_entry(id) when is_binary(id) do
    GenServer.call(__MODULE__, {:remove, id}, 5_000)
  catch
    :exit, _ -> {:error, :not_available}
  end

  @doc """
  Rebuild the FTS5 index from the source table (smriti_entries).
  Use when index is out of sync.
  """
  @spec rebuild_index() :: :ok | {:error, term()}
  def rebuild_index do
    GenServer.call(__MODULE__, :rebuild_index, 30_000)
  catch
    :exit, _ -> {:error, :not_available}
  end

  @doc """
  Return current index statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats, 2_000)
  catch
    :exit, _ -> %{available: false}
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    db_path = Keyword.get(opts, :db_path, @default_db_path)
    Logger.info("[SMRITI.FTS] Initializing FTS5 index — SC-SMRITI-131")

    state = %{
      db_path: db_path,
      conn: nil,
      index_count: 0,
      search_count: 0,
      last_rebuild: nil
    }

    # Initialize ETS table for caching recent searches
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])

    case ensure_db_and_index(db_path) do
      {:ok, conn} ->
        index_count = count_index(conn)
        Logger.info("[SMRITI.FTS] FTS5 ready, #{index_count} entries indexed")
        {:ok, %{state | conn: conn, index_count: index_count}}

      {:error, reason} ->
        Logger.warning(
          "[SMRITI.FTS] DB init failed: #{inspect(reason)} — operating in degraded mode"
        )

        {:ok, state}
    end
  end

  @impl true
  def handle_call({:search, query, opts}, _from, %{conn: nil} = state) do
    # Fallback: ETS-based search when DB unavailable
    results = ets_search(query, opts)
    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    start_ts = System.monotonic_time(:microsecond)
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, 0)

    result =
      case do_fts_search(state.conn, query, limit, offset) do
        {:ok, rows} ->
          {:ok, rows}

        {:error, reason} ->
          Logger.warning(
            "[SMRITI.FTS] FTS5 search failed: #{inspect(reason)}, falling back to ETS"
          )

          {:ok, ets_search(query, opts)}
      end

    elapsed_us = System.monotonic_time(:microsecond) - start_ts
    emit_telemetry(:search, result, elapsed_us)

    new_state = %{state | search_count: state.search_count + 1}
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:index, entry}, _from, %{conn: nil} = state) do
    # Store in ETS when DB unavailable
    store_in_ets(entry)
    {:reply, :ok, %{state | index_count: state.index_count + 1}}
  end

  @impl true
  def handle_call({:index, entry}, _from, state) do
    result = do_index_entry(state.conn, entry)
    store_in_ets(entry)

    new_count = if result == :ok, do: state.index_count + 1, else: state.index_count
    {:reply, result, %{state | index_count: new_count}}
  end

  @impl true
  def handle_call({:remove, id}, _from, state) do
    :ets.delete(@table_name, id)

    result =
      if state.conn do
        do_remove_entry(state.conn, id)
      else
        :ok
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:rebuild_index, _from, %{conn: nil} = state) do
    {:reply, {:error, :no_db_connection}, state}
  end

  @impl true
  def handle_call(:rebuild_index, _from, state) do
    result = do_rebuild_index(state.conn)
    count = count_index(state.conn)
    Logger.info("[SMRITI.FTS] Index rebuilt, #{count} entries")
    {:reply, result, %{state | index_count: count, last_rebuild: DateTime.utc_now()}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      available: state.conn != nil,
      db_path: state.db_path,
      index_count: state.index_count,
      search_count: state.search_count,
      last_rebuild: state.last_rebuild,
      ets_entries: :ets.info(@table_name, :size)
    }

    {:reply, stats, state}
  end

  # ---------------------------------------------------------------------------
  # Private: DB setup
  # ---------------------------------------------------------------------------

  defp ensure_db_and_index(db_path) do
    db_dir = Path.dirname(db_path)
    File.mkdir_p!(db_dir)

    case :ets.whereis(:exqlite_db_smriti_fts) do
      :undefined ->
        open_sqlite(db_path)

      _ ->
        open_sqlite(db_path)
    end
  end

  defp open_sqlite(db_path) do
    if Code.ensure_loaded?(Exqlite.Sqlite3) do
      case Exqlite.Sqlite3.open(db_path) do
        {:ok, conn} ->
          with :ok <- setup_schema(conn) do
            {:ok, conn}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :exqlite_not_available}
    end
  end

  defp setup_schema(conn) do
    statements = [
      # Enable WAL mode (SC-DBLOCAL-004)
      "PRAGMA journal_mode=WAL",
      # Source table for FTS5 content
      """
      CREATE TABLE IF NOT EXISTS smriti_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        created_at TEXT,
        updated_at TEXT
      )
      """,
      # FTS5 virtual table with porter stemming and BM25 ranking
      """
      CREATE VIRTUAL TABLE IF NOT EXISTS smriti_fts_index
      USING fts5(
        id UNINDEXED,
        title,
        content,
        tags,
        content='smriti_entries',
        content_rowid='rowid',
        tokenize='porter ascii'
      )
      """,
      # Trigger to keep FTS in sync with source table (INSERT)
      """
      CREATE TRIGGER IF NOT EXISTS smriti_fts_ai
      AFTER INSERT ON smriti_entries BEGIN
        INSERT INTO smriti_fts_index(rowid, id, title, content, tags)
        VALUES (new.rowid, new.id, new.title, new.content, new.tags);
      END
      """,
      # Trigger to keep FTS in sync (DELETE)
      """
      CREATE TRIGGER IF NOT EXISTS smriti_fts_ad
      AFTER DELETE ON smriti_entries BEGIN
        INSERT INTO smriti_fts_index(smriti_fts_index, rowid, id, title, content, tags)
        VALUES ('delete', old.rowid, old.id, old.title, old.content, old.tags);
      END
      """,
      # Trigger to keep FTS in sync (UPDATE)
      """
      CREATE TRIGGER IF NOT EXISTS smriti_fts_au
      AFTER UPDATE ON smriti_entries BEGIN
        INSERT INTO smriti_fts_index(smriti_fts_index, rowid, id, title, content, tags)
        VALUES ('delete', old.rowid, old.id, old.title, old.content, old.tags);
        INSERT INTO smriti_fts_index(rowid, id, title, content, tags)
        VALUES (new.rowid, new.id, new.title, new.content, new.tags);
      END
      """
    ]

    Enum.reduce_while(statements, :ok, fn sql, _acc ->
      case exec_sqlite(conn, sql, []) do
        {:ok, _} ->
          {:cont, :ok}

        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          Logger.warning("[SMRITI.FTS] Schema setup warning: #{inspect(reason)}")
          # Non-fatal — continue (triggers/tables may already exist)
          {:cont, :ok}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private: FTS operations
  # ---------------------------------------------------------------------------

  defp do_fts_search(conn, query, limit, offset) do
    # BM25 rank is negative in SQLite FTS5 — order ASC for best match first
    sql = """
    SELECT
      e.id,
      e.title,
      SUBSTR(e.content, 1, 200) as content,
      bm25(smriti_fts_index) as rank,
      snippet(smriti_fts_index, 2, '<b>', '</b>', '...', 20) as snippet,
      e.tags,
      e.created_at
    FROM smriti_fts_index
    JOIN smriti_entries e ON e.id = smriti_fts_index.id
    WHERE smriti_fts_index MATCH ?
    ORDER BY rank ASC
    LIMIT ? OFFSET ?
    """

    case query_sqlite(conn, sql, [query, limit, offset]) do
      {:ok, rows} ->
        results =
          Enum.map(rows, fn row ->
            [id, title, content, rank, snippet, tags_str, created_at] = row

            %{
              id: to_str(id),
              title: to_str(title),
              content: to_str(content),
              rank: parse_float(rank),
              snippet: to_str(snippet),
              tags: parse_tags(tags_str),
              created_at: parse_datetime(created_at)
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_index_entry(conn, entry) do
    id = Map.get(entry, :id, Ecto.UUID.generate())
    title = Map.get(entry, :title, "")
    content = Map.get(entry, :content, Map.get(entry, :text, ""))
    tags = entry |> Map.get(:tags, []) |> Enum.join(",")
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    sql = """
    INSERT INTO smriti_entries (id, title, content, tags, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      title=excluded.title,
      content=excluded.content,
      tags=excluded.tags,
      updated_at=excluded.updated_at
    """

    case exec_sqlite(conn, sql, [id, title, content, tags, now, now]) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_remove_entry(conn, id) do
    sql = "DELETE FROM smriti_entries WHERE id = ?"

    case exec_sqlite(conn, sql, [id]) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_rebuild_index(conn) do
    # FTS5 optimize command rebuilds the index
    sql = "INSERT INTO smriti_fts_index(smriti_fts_index) VALUES ('rebuild')"

    case exec_sqlite(conn, sql, []) do
      {:ok, _} -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp count_index(conn) do
    case query_sqlite(conn, "SELECT COUNT(*) FROM smriti_entries", []) do
      {:ok, [[count]]} -> count || 0
      _ -> 0
    end
  end

  # ---------------------------------------------------------------------------
  # Private: ETS fallback
  # ---------------------------------------------------------------------------

  defp store_in_ets(entry) do
    id = Map.get(entry, :id, Ecto.UUID.generate())
    :ets.insert(@table_name, {id, entry})
  end

  defp ets_search(query, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    query_lower = String.downcase(query)
    terms = String.split(query_lower, ~r/\s+AND\s+|\s+OR\s+|\s+/, trim: true)

    @table_name
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, entry} ->
      text =
        [
          Map.get(entry, :title, ""),
          Map.get(entry, :content, Map.get(entry, :text, "")),
          Enum.join(Map.get(entry, :tags, []), " ")
        ]
        |> Enum.join(" ")
        |> String.downcase()

      Enum.any?(terms, &String.contains?(text, &1))
    end)
    |> Enum.take(limit)
    |> Enum.map(fn {id, entry} ->
      %{
        id: id,
        title: Map.get(entry, :title, ""),
        content: String.slice(Map.get(entry, :content, Map.get(entry, :text, "")), 0, 200),
        rank: -1.0,
        snippet: "",
        tags: Map.get(entry, :tags, []),
        created_at: nil
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Private: SQLite helpers (direct Exqlite access per SC-DBLOCAL-001)
  # ---------------------------------------------------------------------------

  defp query_sqlite(conn, sql, params) do
    if Code.ensure_loaded?(Exqlite.Sqlite3) do
      with {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, sql),
           :ok <- bind_params(stmt, params),
           {:ok, rows} <- collect_rows(conn, stmt) do
        Exqlite.Sqlite3.release(conn, stmt)
        {:ok, rows}
      end
    else
      {:error, :exqlite_not_loaded}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp exec_sqlite(conn, sql, params) do
    if Code.ensure_loaded?(Exqlite.Sqlite3) do
      with {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, sql),
           :ok <- bind_params(stmt, params) do
        result = Exqlite.Sqlite3.step(conn, stmt)
        Exqlite.Sqlite3.release(conn, stmt)

        case result do
          :done -> :ok
          {:row, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
      end
    else
      {:error, :exqlite_not_loaded}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp bind_params(_stmt, []), do: :ok

  defp bind_params(stmt, params) do
    Exqlite.Sqlite3.bind(stmt, params)
  end

  defp collect_rows(conn, stmt) do
    collect_rows(conn, stmt, [])
  end

  defp collect_rows(conn, stmt, acc) do
    case Exqlite.Sqlite3.step(conn, stmt) do
      {:row, row} -> collect_rows(conn, stmt, [row | acc])
      :done -> {:ok, Enum.reverse(acc)}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: helpers
  # ---------------------------------------------------------------------------

  defp to_str(nil), do: ""
  defp to_str(val) when is_binary(val), do: val
  defp to_str(val), do: to_string(val)

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_tags(nil), do: []
  defp parse_tags(""), do: []

  defp parse_tags(tags_str) when is_binary(tags_str) do
    tags_str
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp emit_telemetry(:search, result, elapsed_us) do
    status = if match?({:ok, _}, result), do: :ok, else: :error

    count =
      case result do
        {:ok, list} when is_list(list) -> length(list)
        _ -> 0
      end

    :telemetry.execute(
      [:smriti, :fts, :search],
      %{duration_us: elapsed_us, result_count: count},
      %{status: status}
    )
  end
end
