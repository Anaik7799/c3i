defmodule Indrajaal.KMS.SQLite do
  @moduledoc """
  SQLite OLTP Layer for Knowledge Management System

  WHAT: Primary transactional database for holon CRUD operations.
  WHY: SQLite provides ACID, FTS5 search, and direct local access.
  CONSTRAINTS:
    - SC-KMS-001 (SQLite only)
    - SC-KMS-004 (<100ms ops)
    - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    - SC-DBLOCAL-002: Local access latency < 1ms
    - SC-DBLOCAL-004: WAL mode for SQLite

  ## Architecture Note (2026-01-17)
  KMS SQLite uses DIRECT Exqlite access because it's LOCAL holon state.
  Per SC-DBLOCAL-001, local database access bypasses Zenoh entirely.

  Cross-holon database access (different holons) uses DatabaseProxy via Zenoh.
  See: docs/architecture/ZENOH_DATABASE_BRIDGE_ARCHITECTURE.md

  ## Data Flow (LOCAL - this module)
  ```
  KMS.SQLite (this module)
      │
      ▼
  Exqlite.Sqlite3 (direct NIF)
      │
      ▼
  SQLite (data/holons/ex/l3/kms/{node}/state.sqlite)
  ```
  """

  require Logger
  # Note: DatabaseProxy is for CROSS-HOLON access only, not used here
  # alias Indrajaal.Zenoh.DatabaseProxy

  # ... (pragmas and schema omitted for brevity - kept same)
  # I will just include init and core functions. I will reuse the previous full file content but add the missing functions.
  # Since I cannot see the full file content from previous turn in my mind easily and `read_file` was truncated, I should be careful.
  # I will use the truncated read I have and try to be complete.
  # Actually, I will just append/modify the file by reading it first? No, I have to overwrite.
  # I will rely on the previous read output in Turn 33 which seemed complete enough for the structure.
  # Wait, Turn 33 read was NOT truncated. It has the full file.
  # I will use that content and add the functions.

  # SQLite Pragmas for high performance
  @pragmas """
  PRAGMA journal_mode = WAL;
  PRAGMA synchronous = NORMAL;
  PRAGMA cache_size = -64_000;
  PRAGMA mmap_size = 268_435_456;
  PRAGMA temp_store = MEMORY;
  PRAGMA busy_timeout = 5000;
  PRAGMA foreign_keys = ON;
  """

  # Schema DDL
  @schema """
  -- Core holon table
  CREATE TABLE IF NOT EXISTS holons (
    id TEXT PRIMARY KEY,
    fqun TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index')),
    name TEXT NOT NULL,
    parent_id TEXT REFERENCES holons(id),
    genome TEXT NOT NULL DEFAULT '{}',
    vital_signs TEXT DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
    membrane TEXT DEFAULT '{}',
    payload TEXT NOT NULL DEFAULT '{}',
    hlc_physical INTEGER NOT NULL,
    hlc_logical INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );

  -- Indexes for fast lookup
  CREATE INDEX IF NOT EXISTS idx_holons_parent ON holons(parent_id);
  CREATE INDEX IF NOT EXISTS idx_holons_type ON holons(type);
  CREATE INDEX IF NOT EXISTS idx_holons_hlc ON holons(hlc_physical, hlc_logical);
  CREATE INDEX IF NOT EXISTS idx_holons_name ON holons(name);

  -- Holon relationships (graph edges)
  CREATE TABLE IF NOT EXISTS holon_edges (
    source_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    target_id TEXT NOT NULL REFERENCES holons(id) ON DELETE CASCADE,
    relation TEXT NOT NULL,
    weight REAL DEFAULT 1.0,
    metadata TEXT DEFAULT '{}',
    PRIMARY KEY (source_id, target_id, relation)
  );

  CREATE INDEX IF NOT EXISTS idx_edges_target ON holon_edges(target_id);
  CREATE INDEX IF NOT EXISTS idx_edges_relation ON holon_edges(relation);

  -- Event log (append-only)
  CREATE TABLE IF NOT EXISTS holon_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    holon_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT DEFAULT '{}',
    hlc_physical INTEGER NOT NULL,
    hlc_logical INTEGER NOT NULL,
    agent_id TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX IF NOT EXISTS idx_events_holon ON holon_events(holon_id);
  CREATE INDEX IF NOT EXISTS idx_events_type ON holon_events(event_type);
  CREATE INDEX IF NOT EXISTS idx_events_hlc ON holon_events(hlc_physical);

  -- Full-text search (standalone table - simpler and more reliable)
  CREATE VIRTUAL TABLE IF NOT EXISTS holons_fts USING fts5(
    holon_id,
    name,
    payload
  );

  -- Triggers to keep FTS in sync
  CREATE TRIGGER IF NOT EXISTS holons_ai AFTER INSERT ON holons BEGIN
    INSERT INTO holons_fts(holon_id, name, payload) VALUES (new.id, new.name, new.payload);
  END;

  CREATE TRIGGER IF NOT EXISTS holons_ad AFTER DELETE ON holons BEGIN
    DELETE FROM holons_fts WHERE holon_id = old.id;
  END;

  CREATE TRIGGER IF NOT EXISTS holons_au AFTER UPDATE ON holons BEGIN
    DELETE FROM holons_fts WHERE holon_id = old.id;
    INSERT INTO holons_fts(holon_id, name, payload) VALUES (new.id, new.name, new.payload);
  END;
  """

  @doc """
  Initialize SQLite database with schema.
  """
  @spec init(String.t()) :: :ok | {:error, term()}
  def init(db_path) do
    with {:ok, conn} <- open_connection(db_path),
         :ok <- execute_pragmas(conn),
         :ok <- execute_schema(conn) do
      close_connection(conn)
      Logger.info("[KMS.SQLite] Database initialized at #{db_path}")
      :ok
    end
  end

  @doc """
  Get a holon by ID.
  """
  @spec get_holon(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def get_holon(db_path, holon_id) do
    query = "SELECT * FROM holons WHERE id = ?1"

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, [holon_id]) do
      close_connection(conn)

      case rows do
        [row] -> {:ok, row_to_holon(row)}
        [] -> {:error, :not_found}
      end
    end
  end

  @doc """
  Get a holon by FQUN.
  """
  @spec get_holon_by_fqun(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def get_holon_by_fqun(db_path, fqun) do
    query = "SELECT * FROM holons WHERE fqun = ?1"

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, [fqun]) do
      close_connection(conn)

      case rows do
        [row] -> {:ok, row_to_holon(row)}
        [] -> {:error, :not_found}
      end
    end
  end

  @doc """
  List holons with optional filtering.
  """
  @spec list_holons(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_holons(db_path, opts \\ []) do
    type_filter = Keyword.get(opts, :type)
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    {query, params} =
      case type_filter do
        nil ->
          {"SELECT * FROM holons ORDER BY updated_at DESC LIMIT ?1 OFFSET ?2", [limit, offset]}

        type ->
          {"SELECT * FROM holons WHERE type = ?1 ORDER BY updated_at DESC LIMIT ?2 OFFSET ?3",
           [to_string(type), limit, offset]}
      end

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, params) do
      close_connection(conn)
      {:ok, Enum.map(rows, &row_to_holon/1)}
    end
  end

  @doc """
  Insert a new holon.
  """
  @spec insert_holon(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def insert_holon(db_path, holon) do
    query = """
    INSERT INTO holons (id, fqun, type, name, parent_id, genome, vital_signs, membrane, payload, hlc_physical, hlc_logical, created_at, updated_at)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
    """

    params = [
      holon.id,
      holon.fqun,
      holon.type,
      holon.name,
      holon.parent_id,
      holon.genome,
      holon.vital_signs,
      holon.membrane,
      holon.payload,
      holon.hlc_physical,
      holon.hlc_logical,
      holon.created_at,
      holon.updated_at
    ]

    with {:ok, conn} <- open_connection(db_path),
         :ok <- execute_update(conn, query, params) do
      close_connection(conn)
      {:ok, holon}
    end
  end

  @doc """
  Update an existing holon.
  """
  @spec update_holon(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def update_holon(db_path, holon_id, attrs) do
    with {:ok, existing} <- get_holon(db_path, holon_id) do
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      {physical, logical} = get_hlc_timestamp()

      # Build SET clause dynamically
      updates =
        attrs
        |> Enum.filter(fn {k, _} -> k in [:name, :genome, :vital_signs, :membrane, :payload] end)
        |> Enum.map(fn {k, v} -> {k, if(is_map(v), do: Jason.encode!(v), else: v)} end)

      {set_clause, params} = _build_update_query(updates, physical, logical, now, holon_id)
      query = "UPDATE holons SET #{set_clause}"

      with {:ok, conn} <- open_connection(db_path),
           :ok <- execute_update(conn, query, params) do
        close_connection(conn)
        _apply_updates(existing, updates, physical, logical, now)
      end
    end
  end

  defp _build_update_query(updates, physical, logical, now, holon_id) do
    set_clause =
      updates
      |> Enum.with_index(1)
      |> Enum.map(fn {{k, _}, i} -> "#{k} = ?#{i}" end)
      |> Kernel.++([
        "hlc_physical = ?#{length(updates) + 1}",
        "hlc_logical = ?#{length(updates) + 2}",
        "updated_at = ?#{length(updates) + 3}"
      ])
      |> Enum.join(", ")
      |> Kernel.<>(" WHERE id = ?#{length(updates) + 4}")

    params =
      Enum.map(updates, fn {_, v} -> v end) ++ [physical, logical, now, holon_id]

    {set_clause, params}
  end

  defp _apply_updates(existing, updates, physical, logical, now) do
    {:ok,
     existing
     |> Map.merge(Map.new(updates))
     |> Map.put(:hlc_physical, physical)
     |> Map.put(:hlc_logical, logical)
     |> Map.put(:updated_at, now)}
  end

  @doc """
  Delete a holon.
  """
  @spec delete_holon(String.t(), String.t()) :: :ok | {:error, term()}
  def delete_holon(db_path, holon_id) do
    query = "DELETE FROM holons WHERE id = ?1"

    with {:ok, conn} <- open_connection(db_path),
         :ok <- execute_update(conn, query, [holon_id]) do
      close_connection(conn)
      :ok
    end
  end

  @doc """
  Insert an edge between holons.
  """
  @spec insert_edge(String.t(), String.t(), String.t(), atom(), float(), map()) ::
          :ok | {:error, term()}
  def insert_edge(db_path, source_id, target_id, relation, weight, metadata) do
    query = """
    INSERT OR REPLACE INTO holon_edges (source_id, target_id, relation, weight, metadata)
    VALUES (?1, ?2, ?3, ?4, ?5)
    """

    params = [source_id, target_id, to_string(relation), weight, Jason.encode!(metadata)]

    with {:ok, conn} <- open_connection(db_path),
         :ok <- execute_update(conn, query, params) do
      close_connection(conn)
      :ok
    end
  end

  @doc """
  Get all edges for a holon (both incoming and outgoing).
  """
  @spec get_edges(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_edges(db_path, holon_id) do
    query = """
    SELECT * FROM holon_edges
    WHERE source_id = ?1 OR target_id = ?1
    """

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, [holon_id]) do
      close_connection(conn)
      {:ok, Enum.map(rows, &row_to_edge/1)}
    end
  end

  @doc """
  List all edges with optional filtering.

  ## Options
    - `:type` - Filter by relation type
    - `:limit` - Maximum results (default: 100)
  """
  @spec list_edges(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_edges(db_path, opts \\ []) do
    relation = Keyword.get(opts, :type)
    limit = Keyword.get(opts, :limit, 100)

    {query, params} =
      if relation do
        {"SELECT * FROM holon_edges WHERE relation = ?1 ORDER BY created_at DESC LIMIT ?2",
         [to_string(relation), limit]}
      else
        {"SELECT * FROM holon_edges ORDER BY created_at DESC LIMIT ?1", [limit]}
      end

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, params) do
      close_connection(conn)
      {:ok, Enum.map(rows, &row_to_edge/1)}
    end
  end

  @doc """
  Get direct children of a holon.
  """
  @spec get_children(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_children(db_path, holon_id) do
    query = "SELECT * FROM holons WHERE parent_id = ?1 ORDER BY name"

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, [holon_id]) do
      close_connection(conn)
      {:ok, Enum.map(rows, &row_to_holon/1)}
    end
  end

  @doc """
  Get all descendants recursively.
  """
  @spec get_descendants(String.t(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_descendants(db_path, holon_id) do
    query = """
    WITH RECURSIVE descendants AS (
      SELECT * FROM holons WHERE parent_id = ?1
      UNION ALL
      SELECT h.* FROM holons h
      JOIN descendants d ON h.parent_id = d.id
    )
    SELECT * FROM descendants
    """

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, [holon_id]) do
      close_connection(conn)
      {:ok, Enum.map(rows, &row_to_holon/1)}
    end
  end

  @doc """
  Full-text search using FTS5.
  """
  @spec full_text_search(String.t(), String.t(), non_neg_integer()) ::
          {:ok, [map()]} | {:error, term()}
  def full_text_search(db_path, query_text, limit) do
    # Escape FTS5 special characters and prepare query
    safe_query = query_text |> String.replace(~r/[^\w\s]/, "") |> String.trim()

    # Use prefix matching with * suffix for better results
    # FTS5 tokenizes JSON content, so "OAuth2" in payload needs prefix match
    fts_query =
      safe_query
      |> String.split()
      |> Enum.map_join(" ", &"#{&1}*")

    # Query FTS table directly and join with holons for full data
    query = """
    SELECT h.* FROM holons h
    WHERE h.id IN (
      SELECT holon_id FROM holons_fts WHERE holons_fts MATCH ?1
    )
    LIMIT ?2
    """

    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, query, [fts_query, limit]) do
      close_connection(conn)
      {:ok, Enum.map(rows, &row_to_holon/1)}
    end
  end

  @doc """
  Log an event.
  """
  @spec log_event(String.t(), String.t(), atom(), map()) :: :ok | {:error, term()}
  def log_event(db_path, holon_id, event_type, payload) do
    {physical, logical} = get_hlc_timestamp()

    query = """
    INSERT INTO holon_events (holon_id, event_type, payload, hlc_physical, hlc_logical)
    VALUES (?1, ?2, ?3, ?4, ?5)
    """

    params = [holon_id, to_string(event_type), Jason.encode!(payload), physical, logical]

    with {:ok, conn} <- open_connection(db_path),
         :ok <- execute_update(conn, query, params) do
      close_connection(conn)
      :ok
    end
  end

  @doc """
  Execute a raw query (SELECT).
  """
  @spec query(String.t(), String.t(), [term()]) :: {:ok, [map()]} | {:error, term()}
  def query(db_path, sql, params \\ []) do
    with {:ok, conn} <- open_connection(db_path),
         {:ok, rows} <- execute_query(conn, sql, params) do
      close_connection(conn)
      {:ok, rows}
    end
  end

  @doc """
  Execute a raw statement (INSERT, UPDATE, DELETE).
  """
  @spec execute(String.t(), String.t(), [term()]) :: {:ok, :done} | {:error, term()}
  def execute(db_path, sql, params \\ []) do
    with {:ok, conn} <- open_connection(db_path),
         :ok <- execute_update(conn, sql, params) do
      close_connection(conn)
      {:ok, :done}
    end
  end

  @doc """
  Export holons to a separate SQLite database.
  """
  @spec export_holons(String.t(), [map()], String.t()) :: {:ok, String.t()} | {:error, term()}
  def export_holons(_source_db, holons, dest_db) do
    # Initialize destination database
    with :ok <- init(dest_db),
         {:ok, conn} <- open_connection(dest_db) do
      # Insert each holon
      Enum.each(holons, fn holon ->
        query = """
        INSERT OR REPLACE INTO holons (id, fqun, type, name, parent_id, genome, vital_signs, membrane, payload, hlc_physical, hlc_logical, created_at, updated_at)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
        """

        params = [
          holon.id,
          holon.fqun,
          holon.type,
          holon.name,
          holon.parent_id,
          encode_if_map(holon.genome),
          encode_if_map(holon.vital_signs),
          encode_if_map(holon.membrane),
          encode_if_map(holon.payload),
          holon.hlc_physical,
          holon.hlc_logical,
          holon.created_at,
          holon.updated_at
        ]

        execute_update(conn, query, params)
      end)

      close_connection(conn)
      {:ok, dest_db}
    end
  end

  @doc """
  Import holons from another SQLite database.
  """
  @spec import_holons(String.t(), String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def import_holons(target_db, source_db) do
    with {:ok, target_conn} <- open_connection(target_db) do
      # Attach source database
      attach_query = "ATTACH DATABASE '#{source_db}' AS import_db"
      execute_update(target_conn, attach_query, [])

      # Insert or replace holons from source
      import_query = """
      INSERT OR REPLACE INTO holons
      SELECT * FROM import_db.holons
      """

      execute_update(target_conn, import_query, [])

      # Get count
      count_query = "SELECT COUNT(*) as count FROM import_db.holons"
      {:ok, [%{count: count}]} = execute_query(target_conn, count_query, [])

      # Detach
      execute_update(target_conn, "DETACH DATABASE import_db", [])
      close_connection(target_conn)

      {:ok, count}
    end
  end

  # Private Functions

  defp open_connection(db_path) do
    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    # SC-DBLOCAL-002: Local access latency < 1ms
    # KMS is LOCAL state, so we use direct Exqlite access.
    # Ensure directory exists
    db_dir = Path.dirname(db_path)

    case File.mkdir_p(db_dir) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> {:error, {:mkdir_failed, reason}}
    end

    Logger.debug("[KMS.SQLite] Opening SQLite directly: #{db_path} (SC-DBLOCAL-001)")

    case Exqlite.Sqlite3.open(db_path) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end

  defp close_connection(conn) when is_reference(conn) do
    # SC-DBLOCAL-001: Direct Exqlite close for local connections
    Exqlite.Sqlite3.close(conn)
  end

  defp close_connection(_conn) do
    # No-op for nil or invalid connections
    :ok
  end

  defp execute_pragmas(conn) when is_reference(conn) do
    # SC-DBLOCAL-001: Direct Exqlite pragma execution for local connections
    # SC-DBLOCAL-004: WAL mode for SQLite
    @pragmas
    |> String.split(";")
    |> Enum.each(fn pragma ->
      pragma = String.trim(pragma)
      if pragma != "", do: Exqlite.Sqlite3.execute(conn, pragma)
    end)

    :ok
  end

  defp execute_schema(conn) when is_reference(conn) do
    # SC-DBLOCAL-001: Direct Exqlite schema execution for local connections
    # Parse and execute schema statements, handling triggers specially
    # Triggers contain semicolons inside BEGIN...END blocks
    parse_and_execute_statements(@schema, conn)
    :ok
  end

  defp parse_and_execute_statements(schema, conn) do
    # SC-DBLOCAL-001: Direct Exqlite execution for local connections
    # First, extract and handle trigger statements separately
    {triggers, other} = extract_triggers(schema)

    # Execute non-trigger statements (split by semicolon)
    other
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&strip_leading_comments/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.each(fn stmt ->
      Exqlite.Sqlite3.execute(conn, stmt)
    end)

    # Execute triggers as complete statements
    Enum.each(triggers, fn trigger ->
      Exqlite.Sqlite3.execute(conn, trigger)
    end)
  end

  defp extract_triggers(schema) do
    # Match CREATE TRIGGER statements (including their BEGIN...END blocks)
    trigger_regex =
      ~r/CREATE\s+TRIGGER\s+IF\s+NOT\s+EXISTS\s+\w+\s+AFTER\s+\w+\s+ON\s+\w+\s+BEGIN\s+[\s\S]*?END;/m

    triggers = Regex.scan(trigger_regex, schema) |> Enum.map(&List.first/1)

    # Remove triggers from the schema to get remaining statements
    remaining = Regex.replace(trigger_regex, schema, "")

    {triggers, remaining}
  end

  # Strip leading comment lines from a SQL block, preserving the actual statement
  defp strip_leading_comments(str) do
    str
    |> String.split("\n")
    |> Enum.drop_while(fn line ->
      trimmed = String.trim(line)
      trimmed == "" or String.starts_with?(trimmed, "--")
    end)
    |> Enum.join("\n")
    |> String.trim()
  end

  defp execute_query(conn, query, params) when is_reference(conn) do
    # SC-DBLOCAL-001: Direct Exqlite query execution for local connections
    with {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- bind_params(conn, stmt, params),
         {:ok, rows} <- fetch_all(conn, stmt) do
      Exqlite.Sqlite3.release(conn, stmt)
      {:ok, rows}
    end
  end

  defp execute_update(conn, query, params) when is_reference(conn) do
    # SC-DBLOCAL-001: Direct Exqlite update execution for local connections
    with {:ok, stmt} <- Exqlite.Sqlite3.prepare(conn, query),
         :ok <- bind_params(conn, stmt, params),
         :done <- Exqlite.Sqlite3.step(conn, stmt) do
      Exqlite.Sqlite3.release(conn, stmt)
      :ok
    end
  end

  defp bind_params(_conn, stmt, params) do
    # SC-DBLOCAL-001: Direct Exqlite parameter binding
    Exqlite.Sqlite3.bind(stmt, params)
  end

  defp fetch_all(conn, stmt, acc \\ []) do
    # SC-DBLOCAL-001: Direct Exqlite row fetching
    case Exqlite.Sqlite3.step(conn, stmt) do
      {:row, columns} ->
        # Get column names
        {:ok, col_names} = Exqlite.Sqlite3.columns(conn, stmt)

        row =
          col_names
          |> Enum.zip(columns)
          |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

        fetch_all(conn, stmt, [row | acc])

      :done ->
        {:ok, Enum.reverse(acc)}
    end
  end

  defp row_to_holon(row) do
    row
    |> Map.update(:genome, %{}, &decode_json/1)
    |> Map.update(:vital_signs, %{}, &decode_json/1)
    |> Map.update(:membrane, %{}, &decode_json/1)
    |> Map.update(:payload, %{}, &decode_json/1)
  end

  defp row_to_edge(row) do
    row
    |> Map.update(:metadata, %{}, &decode_json/1)
  end

  defp decode_json(nil), do: %{}
  defp decode_json(str) when is_binary(str), do: Jason.decode!(str)
  defp decode_json(other), do: other

  defp encode_if_map(value) when is_map(value), do: Jason.encode!(value)
  defp encode_if_map(value), do: value

  defp get_hlc_timestamp do
    {System.system_time(:microsecond), 0}
  end
end
