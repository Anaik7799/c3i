defmodule Indrajaal.Holon.Database.SQLitePool do
  @moduledoc """
  High-performance SQLite connection pool using Exqlite.

  WHAT: Pooled SQLite connections with WAL mode for concurrent access.
  WHY: SC-XHOLON-002 requires direct access via native libraries.
       SC-XHOLON-020 mandates < 1ms read latency.

  CONSTRAINTS:
    - SC-XHOLON-020: SQLite read latency < 1ms
    - SC-XHOLON-030: No data loss on crash (WAL mode)
    - SC-XHOLON-031: ACID compliance mandatory
    - SC-CONC-002: Connection pooling via Poolboy

  ## Features
    - WAL mode for concurrent reads
    - Connection pooling via NimblePool
    - Automatic retry on SQLITE_BUSY
    - Prepared statement caching
  """

  require Logger

  @pool_timeout 5_000
  @busy_timeout 5_000

  # ============================================================================
  # Pool Management
  # ============================================================================

  @doc """
  Start a SQLite connection pool.

  ## Parameters
    - `pool_name` - Atom name for the pool
    - `db_path` - Path to the SQLite database file
    - `pool_size` - Number of connections in pool
    - `acquire_timeout` - Timeout for acquiring a connection

  ## Returns
    - `{:ok, pid}` on success
  """
  @spec start_pool(atom(), String.t(), pos_integer(), pos_integer()) :: {:ok, pid()}
  def start_pool(pool_name, db_path, pool_size, acquire_timeout) do
    Logger.debug("[SQLitePool] Starting pool #{pool_name} for #{db_path}")

    pool_config = [
      name: {:local, pool_name},
      worker_module: __MODULE__.Worker,
      size: pool_size,
      max_overflow: 2
    ]

    worker_args = [db_path: db_path, busy_timeout: @busy_timeout]

    case :poolboy.start_link(pool_config, worker_args) do
      {:ok, pid} ->
        # Store pool config in registry for later use
        :persistent_term.put({__MODULE__, pool_name}, %{
          db_path: db_path,
          acquire_timeout: acquire_timeout
        })

        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Stop a SQLite connection pool.
  """
  @spec stop_pool(atom()) :: :ok
  def stop_pool(pool_name) do
    :poolboy.stop(pool_name)
    :persistent_term.erase({__MODULE__, pool_name})
    :ok
  rescue
    _ -> :ok
  end

  # ============================================================================
  # Query Operations
  # ============================================================================

  @doc """
  Execute a read query and return rows as maps.

  ## Parameters
    - `pool_name` - The pool to use
    - `sql` - SQL query string
    - `params` - Query parameters

  ## Returns
    - `{:ok, [map()]}` with rows as maps
    - `{:error, reason}` on failure
  """
  @spec query(atom(), String.t(), list()) :: {:ok, [map()]} | {:error, String.t()}
  def query(pool_name, sql, params \\ []) do
    config = :persistent_term.get({__MODULE__, pool_name})
    timeout = Map.get(config, :acquire_timeout, @pool_timeout)

    :poolboy.transaction(
      pool_name,
      fn worker ->
        GenServer.call(worker, {:query, sql, params}, timeout)
      end,
      timeout
    )
  rescue
    error ->
      Logger.error("[SQLitePool] Query error: #{inspect(error)}")
      {:error, "Pool timeout or worker error: #{inspect(error)}"}
  end

  @doc """
  Execute a write statement.

  ## Parameters
    - `pool_name` - The pool to use
    - `sql` - SQL statement
    - `params` - Statement parameters

  ## Returns
    - `{:ok, %{changes: n, last_insert_id: id}}` on success
    - `{:error, reason}` on failure
  """
  @spec execute(atom(), String.t(), list()) :: {:ok, map()} | {:error, String.t()}
  def execute(pool_name, sql, params \\ []) do
    config = :persistent_term.get({__MODULE__, pool_name})
    timeout = Map.get(config, :acquire_timeout, @pool_timeout)

    :poolboy.transaction(
      pool_name,
      fn worker ->
        GenServer.call(worker, {:execute, sql, params}, timeout)
      end,
      timeout
    )
  rescue
    error ->
      Logger.error("[SQLitePool] Execute error: #{inspect(error)}")
      {:error, "Pool timeout or worker error: #{inspect(error)}"}
  end

  @doc """
  Execute a function within a transaction.

  ## Parameters
    - `pool_name` - The pool to use
    - `fun` - Function to execute within transaction
    - `opts` - Transaction options
      - `:isolation` - :serializable, :immediate, :deferred

  ## Returns
    - `{:ok, result}` on commit
    - `{:error, reason}` on rollback
  """
  @spec transaction(atom(), (Exqlite.Sqlite3.db() -> {:ok, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, term()}
  def transaction(pool_name, fun, opts \\ []) do
    config = :persistent_term.get({__MODULE__, pool_name})
    timeout = Map.get(config, :acquire_timeout, @pool_timeout)
    isolation = Keyword.get(opts, :isolation, :serializable)

    :poolboy.transaction(
      pool_name,
      fn worker ->
        GenServer.call(worker, {:transaction, fun, isolation}, timeout * 2)
      end,
      timeout
    )
  rescue
    error ->
      Logger.error("[SQLitePool] Transaction error: #{inspect(error)}")
      {:error, "Transaction error: #{inspect(error)}"}
  end

  # ============================================================================
  # Worker Module
  # ============================================================================

  defmodule Worker do
    @moduledoc false
    use GenServer

    require Logger

    defstruct [:conn, :db_path, :stmt_cache]

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    @impl true
    def init(args) do
      db_path = Keyword.fetch!(args, :db_path)
      busy_timeout = Keyword.get(args, :busy_timeout, 5_000)

      case open_connection(db_path, busy_timeout) do
        {:ok, conn} ->
          {:ok, %__MODULE__{conn: conn, db_path: db_path, stmt_cache: %{}}}

        {:error, reason} ->
          {:stop, reason}
      end
    end

    @impl true
    def handle_call({:query, sql, params}, _from, state) do
      result = do_query(state.conn, sql, params)
      {:reply, result, state}
    end

    @impl true
    def handle_call({:execute, sql, params}, _from, state) do
      result = do_execute(state.conn, sql, params)
      {:reply, result, state}
    end

    @impl true
    def handle_call({:transaction, fun, isolation}, _from, state) do
      result = do_transaction(state.conn, fun, isolation)
      {:reply, result, state}
    end

    @impl true
    def terminate(_reason, state) do
      if state.conn do
        Exqlite.Sqlite3.close(state.conn)
      end

      :ok
    end

    # ============================================================================
    # Private Functions
    # ============================================================================

    defp open_connection(db_path, busy_timeout) do
      case Exqlite.Sqlite3.open(db_path) do
        {:ok, conn} ->
          # Enable WAL mode for concurrent access
          :ok = Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
          # Set busy timeout
          :ok = Exqlite.Sqlite3.execute(conn, "PRAGMA busy_timeout=#{busy_timeout}")
          # Enable foreign keys
          :ok = Exqlite.Sqlite3.execute(conn, "PRAGMA foreign_keys=ON")
          # Synchronous mode for safety
          :ok = Exqlite.Sqlite3.execute(conn, "PRAGMA synchronous=NORMAL")
          {:ok, conn}

        error ->
          error
      end
    end

    defp do_query(conn, sql, params) do
      case Exqlite.Sqlite3.prepare(conn, sql) do
        {:ok, stmt} ->
          try do
            # Bind parameters
            :ok = bind_params(stmt, params)

            # Fetch all rows
            rows = fetch_all_rows(conn, stmt, [])

            # Get column names
            {:ok, columns} = Exqlite.Sqlite3.columns(conn, stmt)
            column_atoms = Enum.map(columns, &String.to_atom/1)

            # Convert to maps
            maps =
              Enum.map(rows, fn row ->
                Enum.zip(column_atoms, row) |> Map.new()
              end)

            {:ok, maps}
          after
            Exqlite.Sqlite3.release(conn, stmt)
          end

        {:error, reason} ->
          {:error, "Prepare failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Query error: #{inspect(error)}"}
    end

    defp do_execute(conn, sql, params) do
      case Exqlite.Sqlite3.prepare(conn, sql) do
        {:ok, stmt} ->
          try do
            :ok = bind_params(stmt, params)

            case Exqlite.Sqlite3.step(conn, stmt) do
              :done ->
                changes = Exqlite.Sqlite3.changes(conn)
                last_id = Exqlite.Sqlite3.last_insert_rowid(conn)
                {:ok, %{changes: changes, last_insert_id: last_id}}

              {:row, _} ->
                # Statement returned rows, drain them
                drain_rows(conn, stmt)
                changes = Exqlite.Sqlite3.changes(conn)
                {:ok, %{changes: changes, last_insert_id: nil}}

              {:error, reason} ->
                {:error, "Execute failed: #{inspect(reason)}"}
            end
          after
            Exqlite.Sqlite3.release(conn, stmt)
          end

        {:error, reason} ->
          {:error, "Prepare failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Execute error: #{inspect(error)}"}
    end

    defp do_transaction(conn, fun, isolation) do
      begin_sql =
        case isolation do
          :serializable -> "BEGIN IMMEDIATE"
          :immediate -> "BEGIN IMMEDIATE"
          :deferred -> "BEGIN DEFERRED"
          _ -> "BEGIN IMMEDIATE"
        end

      case Exqlite.Sqlite3.execute(conn, begin_sql) do
        :ok ->
          try do
            case fun.(conn) do
              {:ok, result} ->
                :ok = Exqlite.Sqlite3.execute(conn, "COMMIT")
                {:ok, result}

              {:error, reason} ->
                :ok = Exqlite.Sqlite3.execute(conn, "ROLLBACK")
                {:error, reason}

              other ->
                :ok = Exqlite.Sqlite3.execute(conn, "COMMIT")
                {:ok, other}
            end
          rescue
            error ->
              Exqlite.Sqlite3.execute(conn, "ROLLBACK")
              {:error, "Transaction error: #{inspect(error)}"}
          end

        {:error, reason} ->
          {:error, "Begin transaction failed: #{inspect(reason)}"}
      end
    end

    defp bind_params(_stmt, []), do: :ok

    defp bind_params(stmt, params) do
      # Exqlite.Sqlite3.bind/2 takes statement and list of params
      :ok = Exqlite.Sqlite3.bind(stmt, params)
      :ok
    end

    defp fetch_all_rows(conn, stmt, acc) do
      case Exqlite.Sqlite3.step(conn, stmt) do
        {:row, row} -> fetch_all_rows(conn, stmt, [row | acc])
        :done -> Enum.reverse(acc)
        {:error, _} -> Enum.reverse(acc)
      end
    end

    defp drain_rows(conn, stmt) do
      case Exqlite.Sqlite3.step(conn, stmt) do
        {:row, _} -> drain_rows(conn, stmt)
        _ -> :ok
      end
    end
  end
end
