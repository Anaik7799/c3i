defmodule Indrajaal.Holon.Database.HolonDatabase do
  @moduledoc """
  Unified Database Access for Elixir Holons.

  WHAT: Single entry point for all holon database operations with direct
        high-performance access to SQLite and DuckDB.

  WHY: SC-XHOLON-001 requires isolated database access per holon.
       SC-XHOLON-002 mandates native high-performance libraries.

  CONSTRAINTS:
    - SC-XHOLON-001: Each holon has isolated database files
    - SC-XHOLON-002: Direct access via Exqlite/Duckdbex
    - SC-XHOLON-010: Lock-free reads via OCC
    - SC-XHOLON-020: SQLite read latency < 1ms
    - SC-XHOLON-021: DuckDB query latency < 10ms
    - SC-DBNAME-001: UHI-based database paths

  ## Architecture

  ```
  HolonDatabase (GenServer)
       │
       ├── SQLitePool (Poolboy + Exqlite)
       │   └── state.sqlite, vectors.sqlite, cache.sqlite
       │
       └── DuckDBPool (Poolboy + Duckdbex)
           └── analytics.duckdb, history.duckdb, register.duckdb
  ```

  ## Usage

  ```elixir
  # Start database for a holon
  {:ok, pid} = HolonDatabase.start_link(holon_id: "ex:l3:kms:srv:main")

  # Read from SQLite
  {:ok, rows} = HolonDatabase.query(:state, "SELECT * FROM config WHERE key = ?", ["setting"])

  # Write to SQLite with transaction
  {:ok, _} = HolonDatabase.transaction(:state, fn conn ->
    HolonDatabase.execute(conn, "INSERT INTO config (key, value) VALUES (?, ?)", ["k", "v"])
  end)

  # Query DuckDB for analytics
  {:ok, rows} = HolonDatabase.query(:analytics, "SELECT * FROM metrics WHERE ts > ?", [timestamp])
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Holon.DatabasePath
  alias Indrajaal.Holon.Database.{SQLitePool, DuckDBPool, ConcurrencyHandler}

  @type holon_id :: String.t()
  @type db_type :: :state | :analytics | :history | :vectors | :register | :cache
  @type query_result :: {:ok, [map()]} | {:error, String.t()}
  @type version_vector :: %{String.t() => non_neg_integer()}

  @sqlite_dbs [:state, :vectors, :cache]
  @duckdb_dbs [:analytics, :history, :register]

  defstruct [
    :holon_id,
    :sqlite_pools,
    :duckdb_pools,
    :version_vectors,
    :stats
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Start a HolonDatabase for the given holon.

  ## Options
    - `:holon_id` - Required. The UHI of the holon (e.g., "ex:l3:kms:srv:main")
    - `:pool_size` - Optional. Connection pool size (default: 5)
    - `:acquire_timeout` - Optional. Pool acquire timeout in ms (default: 5000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    holon_id = Keyword.fetch!(opts, :holon_id)
    name = via_tuple(holon_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Execute a read query on the specified database type.

  ## Parameters
    - `holon_id` - The UHI of the holon
    - `db_type` - One of :state, :vectors, :cache (SQLite) or :analytics, :history, :register (DuckDB)
    - `sql` - The SQL query string
    - `params` - Query parameters (default: [])

  ## Returns
    - `{:ok, rows}` on success
    - `{:error, reason}` on failure

  ## Example
      {:ok, rows} = HolonDatabase.query("ex:l3:kms:srv:main", :state, "SELECT * FROM config")
  """
  @spec query(holon_id(), db_type(), String.t(), list()) :: query_result()
  def query(holon_id, db_type, sql, params \\ []) do
    GenServer.call(via_tuple(holon_id), {:query, db_type, sql, params})
  end

  @doc """
  Execute a write statement on the specified database type.

  ## Parameters
    - `holon_id` - The UHI of the holon
    - `db_type` - Database type
    - `sql` - The SQL statement
    - `params` - Statement parameters

  ## Returns
    - `{:ok, %{changes: n}}` on success
    - `{:error, reason}` on failure
  """
  @spec execute(holon_id(), db_type(), String.t(), list()) :: {:ok, map()} | {:error, String.t()}
  def execute(holon_id, db_type, sql, params \\ []) do
    GenServer.call(via_tuple(holon_id), {:execute, db_type, sql, params})
  end

  @doc """
  Execute multiple statements within a transaction.

  ## Parameters
    - `holon_id` - The UHI of the holon
    - `db_type` - Database type (SQLite only for full ACID)
    - `fun` - Function receiving connection, should return {:ok, result} or {:error, reason}
    - `opts` - Transaction options
      - `:isolation` - :serializable, :repeatable_read, :read_committed (default: :serializable)
      - `:timeout` - Transaction timeout in ms (default: 5000)

  ## Example
      {:ok, result} = HolonDatabase.transaction("ex:l3:kms:srv:main", :state, fn conn ->
        HolonDatabase.conn_execute(conn, "INSERT INTO t VALUES (?)", [1])
        HolonDatabase.conn_execute(conn, "INSERT INTO t VALUES (?)", [2])
        {:ok, :inserted}
      end)
  """
  @spec transaction(
          holon_id(),
          db_type(),
          (term() -> {:ok, term()} | {:error, term()}),
          keyword()
        ) ::
          {:ok, term()} | {:error, term()}
  def transaction(holon_id, db_type, fun, opts \\ []) do
    GenServer.call(via_tuple(holon_id), {:transaction, db_type, fun, opts})
  end

  @doc """
  Get current version vector for optimistic concurrency control.
  """
  @spec get_version_vector(holon_id()) :: {:ok, version_vector()}
  def get_version_vector(holon_id) do
    GenServer.call(via_tuple(holon_id), :get_version_vector)
  end

  @doc """
  Execute with optimistic concurrency control (compare-and-swap).

  ## Parameters
    - `holon_id` - The UHI of the holon
    - `db_type` - Database type
    - `sql` - The SQL statement
    - `params` - Statement parameters
    - `expected_version` - Expected version vector

  ## Returns
    - `{:ok, %{changes: n, new_version: vv}}` on success
    - `{:conflict, current_version}` on version mismatch
    - `{:error, reason}` on failure
  """
  @spec execute_cas(holon_id(), db_type(), String.t(), list(), version_vector()) ::
          {:ok, map()} | {:conflict, version_vector()} | {:error, String.t()}
  def execute_cas(holon_id, db_type, sql, params, expected_version) do
    GenServer.call(via_tuple(holon_id), {:execute_cas, db_type, sql, params, expected_version})
  end

  @doc """
  Get database statistics.
  """
  @spec stats(holon_id()) :: {:ok, map()}
  def stats(holon_id) do
    GenServer.call(via_tuple(holon_id), :stats)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    holon_id = Keyword.fetch!(opts, :holon_id)
    pool_size = Keyword.get(opts, :pool_size, 5)
    acquire_timeout = Keyword.get(opts, :acquire_timeout, 5_000)

    Logger.info("[HolonDatabase] Initializing database for holon: #{holon_id}")

    # Initialize SQLite pools
    sqlite_pools =
      @sqlite_dbs
      |> Enum.map(fn db_type ->
        fqdn = "#{holon_id}:#{db_type}"
        {:ok, path} = DatabasePath.resolve(fqdn)
        ensure_directory(path)

        pool_name = pool_name(holon_id, db_type)
        {:ok, _} = SQLitePool.start_pool(pool_name, path, pool_size, acquire_timeout)
        {db_type, pool_name}
      end)
      |> Map.new()

    # Initialize DuckDB pools
    duckdb_pools =
      @duckdb_dbs
      |> Enum.map(fn db_type ->
        fqdn = "#{holon_id}:#{db_type}"
        {:ok, path} = DatabasePath.resolve(fqdn)
        ensure_directory(path)

        pool_name = pool_name(holon_id, db_type)
        {:ok, _} = DuckDBPool.start_pool(pool_name, path, pool_size, acquire_timeout)
        {db_type, pool_name}
      end)
      |> Map.new()

    # Initialize version vectors
    version_vectors = %{
      "local" => 0,
      holon_id => 0
    }

    # Initialize statistics
    stats = %{
      queries: 0,
      executes: 0,
      transactions: 0,
      conflicts: 0,
      errors: 0,
      started_at: DateTime.utc_now()
    }

    state = %__MODULE__{
      holon_id: holon_id,
      sqlite_pools: sqlite_pools,
      duckdb_pools: duckdb_pools,
      version_vectors: version_vectors,
      stats: stats
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:query, db_type, sql, params}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result =
      case get_pool(state, db_type) do
        {:sqlite, pool_name} ->
          SQLitePool.query(pool_name, sql, params)

        {:duckdb, pool_name} ->
          DuckDBPool.query(pool_name, sql, params)

        {:error, reason} ->
          {:error, reason}
      end

    duration = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:query, state.holon_id, db_type, duration, result)

    new_stats = update_stats(state.stats, :queries, result)
    {:reply, result, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:execute, db_type, sql, params}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result =
      case get_pool(state, db_type) do
        {:sqlite, pool_name} ->
          SQLitePool.execute(pool_name, sql, params)

        {:duckdb, pool_name} ->
          DuckDBPool.execute(pool_name, sql, params)

        {:error, reason} ->
          {:error, reason}
      end

    # Update version vector on successful write
    {result, new_vv} =
      case result do
        {:ok, changes} ->
          new_vv = increment_version(state.version_vectors, state.holon_id)
          {{:ok, Map.put(changes, :version, new_vv)}, new_vv}

        error ->
          {error, state.version_vectors}
      end

    duration = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:execute, state.holon_id, db_type, duration, result)

    new_stats = update_stats(state.stats, :executes, result)
    {:reply, result, %{state | stats: new_stats, version_vectors: new_vv}}
  end

  @impl true
  def handle_call({:transaction, db_type, fun, opts}, _from, state) do
    start_time = System.monotonic_time(:microsecond)

    result =
      case get_pool(state, db_type) do
        {:sqlite, pool_name} ->
          SQLitePool.transaction(pool_name, fun, opts)

        {:duckdb, _pool_name} ->
          # DuckDB has limited transaction support
          {:error, "DuckDB transactions not fully supported, use SQLite for ACID"}

        {:error, reason} ->
          {:error, reason}
      end

    # Update version vector on successful transaction
    {result, new_vv} =
      case result do
        {:ok, _} = ok ->
          new_vv = increment_version(state.version_vectors, state.holon_id)
          {ok, new_vv}

        error ->
          {error, state.version_vectors}
      end

    duration = System.monotonic_time(:microsecond) - start_time
    emit_telemetry(:transaction, state.holon_id, db_type, duration, result)

    new_stats = update_stats(state.stats, :transactions, result)
    {:reply, result, %{state | stats: new_stats, version_vectors: new_vv}}
  end

  @impl true
  def handle_call({:execute_cas, db_type, sql, params, expected_version}, _from, state) do
    # Compare version vectors
    if ConcurrencyHandler.version_gte?(state.version_vectors, expected_version) do
      # Version matches, proceed with execute
      result =
        case get_pool(state, db_type) do
          {:sqlite, pool_name} ->
            SQLitePool.execute(pool_name, sql, params)

          {:duckdb, pool_name} ->
            DuckDBPool.execute(pool_name, sql, params)

          {:error, reason} ->
            {:error, reason}
        end

      case result do
        {:ok, changes} ->
          new_vv = increment_version(state.version_vectors, state.holon_id)
          new_stats = update_stats(state.stats, :executes, result)

          {:reply, {:ok, Map.put(changes, :new_version, new_vv)},
           %{state | stats: new_stats, version_vectors: new_vv}}

        error ->
          new_stats = update_stats(state.stats, :errors, error)
          {:reply, error, %{state | stats: new_stats}}
      end
    else
      # Version conflict
      new_stats = Map.update!(state.stats, :conflicts, &(&1 + 1))
      {:reply, {:conflict, state.version_vectors}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:get_version_vector, _from, state) do
    {:reply, {:ok, state.version_vectors}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info(
      "[HolonDatabase] Shutting down database for holon: #{state.holon_id}, reason: #{inspect(reason)}"
    )

    # Stop all pools
    Enum.each(state.sqlite_pools, fn {_type, pool_name} ->
      SQLitePool.stop_pool(pool_name)
    end)

    Enum.each(state.duckdb_pools, fn {_type, pool_name} ->
      DuckDBPool.stop_pool(pool_name)
    end)

    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp via_tuple(holon_id) do
    {:via, Registry, {Indrajaal.Holon.Database.Registry, holon_id}}
  end

  defp pool_name(holon_id, db_type) do
    String.to_atom("holon_db_#{String.replace(holon_id, ":", "_")}_#{db_type}")
  end

  defp get_pool(state, db_type) when db_type in @sqlite_dbs do
    case Map.fetch(state.sqlite_pools, db_type) do
      {:ok, pool_name} -> {:sqlite, pool_name}
      :error -> {:error, "Unknown SQLite database type: #{db_type}"}
    end
  end

  defp get_pool(state, db_type) when db_type in @duckdb_dbs do
    case Map.fetch(state.duckdb_pools, db_type) do
      {:ok, pool_name} -> {:duckdb, pool_name}
      :error -> {:error, "Unknown DuckDB database type: #{db_type}"}
    end
  end

  defp get_pool(_state, db_type) do
    {:error, "Unknown database type: #{db_type}"}
  end

  defp ensure_directory(path) do
    dir = Path.dirname(path)
    File.mkdir_p!(dir)
  end

  defp increment_version(version_vectors, holon_id) do
    Map.update(version_vectors, holon_id, 1, &(&1 + 1))
  end

  defp update_stats(stats, key, result) do
    stats
    |> Map.update!(key, &(&1 + 1))
    |> maybe_increment_errors(result)
  end

  defp maybe_increment_errors(stats, {:error, _}), do: Map.update!(stats, :errors, &(&1 + 1))
  defp maybe_increment_errors(stats, _), do: stats

  defp emit_telemetry(operation, holon_id, db_type, duration_us, result) do
    status = if match?({:ok, _}, result), do: :ok, else: :error

    :telemetry.execute(
      [:indrajaal, :holon, :database, operation],
      %{duration_us: duration_us},
      %{holon_id: holon_id, db_type: db_type, status: status}
    )
  end
end
