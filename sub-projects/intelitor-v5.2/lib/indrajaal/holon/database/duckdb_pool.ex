defmodule Indrajaal.Holon.Database.DuckDBPool do
  @moduledoc """
  High-performance DuckDB connection pool for analytical queries.

  WHAT: Pooled DuckDB connections for OLAP workloads.
  WHY: SC-XHOLON-002 requires direct access via native libraries.
       SC-XHOLON-021 mandates < 10ms query latency.

  CONSTRAINTS:
    - SC-XHOLON-021: DuckDB query latency < 10ms
    - SC-XHOLON-035: Audit trail immutable (append-only)
    - SC-HOLON-007: Use DuckDB for analytics queries
    - SC-CONC-002: Connection pooling

  ## Features
    - Columnar storage for analytics
    - Vectorized query execution
    - Append-only mode for history tables
    - Parquet export capability
  """

  require Logger

  @pool_timeout 5_000

  # ============================================================================
  # Pool Management
  # ============================================================================

  @doc """
  Start a DuckDB connection pool.

  ## Parameters
    - `pool_name` - Atom name for the pool
    - `db_path` - Path to the DuckDB database file
    - `pool_size` - Number of connections in pool
    - `acquire_timeout` - Timeout for acquiring a connection

  ## Returns
    - `{:ok, pid}` on success
  """
  @spec start_pool(atom(), String.t(), pos_integer(), pos_integer()) :: {:ok, pid()}
  def start_pool(pool_name, db_path, pool_size, acquire_timeout) do
    Logger.debug("[DuckDBPool] Starting pool #{pool_name} for #{db_path}")

    pool_config = [
      name: {:local, pool_name},
      worker_module: __MODULE__.Worker,
      size: pool_size,
      max_overflow: 2
    ]

    worker_args = [db_path: db_path]

    case :poolboy.start_link(pool_config, worker_args) do
      {:ok, pid} ->
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
  Stop a DuckDB connection pool.
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
  Execute an analytical query and return rows as maps.

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
      Logger.error("[DuckDBPool] Query error: #{inspect(error)}")
      {:error, "Pool timeout or worker error: #{inspect(error)}"}
  end

  @doc """
  Execute a write statement (INSERT/UPDATE/DELETE).

  Note: For history/register tables, only INSERT (append) is allowed
  per SC-XHOLON-035.

  ## Parameters
    - `pool_name` - The pool to use
    - `sql` - SQL statement
    - `params` - Statement parameters

  ## Returns
    - `{:ok, %{changes: n}}` on success
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
      Logger.error("[DuckDBPool] Execute error: #{inspect(error)}")
      {:error, "Pool timeout or worker error: #{inspect(error)}"}
  end

  @doc """
  Append records to an append-only table (history/register).

  This is the preferred method for history tables as it enforces
  append-only semantics per SC-XHOLON-035.

  ## Parameters
    - `pool_name` - The pool to use
    - `table` - Table name
    - `columns` - List of column names
    - `rows` - List of row tuples

  ## Returns
    - `{:ok, %{inserted: n}}` on success
    - `{:error, reason}` on failure
  """
  @spec append(atom(), String.t(), [String.t()], [tuple()]) :: {:ok, map()} | {:error, String.t()}
  def append(pool_name, table, columns, rows) do
    config = :persistent_term.get({__MODULE__, pool_name})
    timeout = Map.get(config, :acquire_timeout, @pool_timeout)

    :poolboy.transaction(
      pool_name,
      fn worker ->
        GenServer.call(worker, {:append, table, columns, rows}, timeout)
      end,
      timeout
    )
  rescue
    error ->
      Logger.error("[DuckDBPool] Append error: #{inspect(error)}")
      {:error, "Pool timeout or worker error: #{inspect(error)}"}
  end

  @doc """
  Export query results to Parquet file.

  ## Parameters
    - `pool_name` - The pool to use
    - `sql` - SQL query to export
    - `output_path` - Path for output Parquet file

  ## Returns
    - `{:ok, path}` on success
    - `{:error, reason}` on failure
  """
  @spec export_parquet(atom(), String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def export_parquet(pool_name, sql, output_path) do
    config = :persistent_term.get({__MODULE__, pool_name})
    # Longer for export
    timeout = Map.get(config, :acquire_timeout, @pool_timeout) * 10

    :poolboy.transaction(
      pool_name,
      fn worker ->
        GenServer.call(worker, {:export_parquet, sql, output_path}, timeout)
      end,
      timeout
    )
  rescue
    error ->
      Logger.error("[DuckDBPool] Export error: #{inspect(error)}")
      {:error, "Export error: #{inspect(error)}"}
  end

  # ============================================================================
  # Worker Module
  # ============================================================================

  defmodule Worker do
    @moduledoc false
    use GenServer

    require Logger

    defstruct [:conn, :db_path]

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    @impl true
    def init(args) do
      db_path = Keyword.fetch!(args, :db_path)

      case open_connection(db_path) do
        {:ok, conn} ->
          {:ok, %__MODULE__{conn: conn, db_path: db_path}}

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
    def handle_call({:append, table, columns, rows}, _from, state) do
      result = do_append(state.conn, table, columns, rows)
      {:reply, result, state}
    end

    @impl true
    def handle_call({:export_parquet, sql, output_path}, _from, state) do
      result = do_export_parquet(state.conn, sql, output_path)
      {:reply, result, state}
    end

    @impl true
    def terminate(_reason, _state) do
      # Duckdbex connections are cleaned up automatically by GC
      # The db handle is released when the connection reference is dropped
      # SC-HOLON-007: DuckDB analytics queries - graceful termination
      :ok
    end

    # ============================================================================
    # Private Functions
    # ============================================================================

    defp open_connection(db_path) do
      case Duckdbex.open(db_path) do
        {:ok, db} ->
          case Duckdbex.connection(db) do
            {:ok, conn} ->
              # Configure for analytics workload
              Duckdbex.query(conn, "SET threads TO 4")
              Duckdbex.query(conn, "SET memory_limit = '1GB'")
              {:ok, conn}

            error ->
              error
          end

        error ->
          error
      end
    rescue
      error ->
        {:error, "Failed to open DuckDB: #{inspect(error)}"}
    end

    defp do_query(conn, sql, params) do
      # Substitute parameters
      final_sql = substitute_params(sql, params)

      case Duckdbex.query(conn, final_sql) do
        {:ok, result} ->
          # Convert result to list of maps
          columns = Duckdbex.columns(result)
          column_atoms = Enum.map(columns, &String.to_atom/1)

          rows = Duckdbex.fetch_all(result)

          maps =
            Enum.map(rows, fn row ->
              Enum.zip(column_atoms, Tuple.to_list(row)) |> Map.new()
            end)

          {:ok, maps}

        {:error, reason} ->
          {:error, "Query failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Query error: #{inspect(error)}"}
    end

    defp do_execute(conn, sql, params) do
      final_sql = substitute_params(sql, params)

      case Duckdbex.query(conn, final_sql) do
        {:ok, _result} ->
          # DuckDB doesn't easily report changes, estimate based on operation
          {:ok, %{changes: 1}}

        {:error, reason} ->
          {:error, "Execute failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Execute error: #{inspect(error)}"}
    end

    defp do_append(conn, table, columns, rows) when is_list(rows) do
      # Build bulk INSERT
      cols_str = Enum.join(columns, ", ")

      placeholders =
        Enum.map(rows, fn row ->
          values =
            row
            |> Tuple.to_list()
            |> Enum.map(&format_value/1)
            |> Enum.join(", ")

          "(#{values})"
        end)
        |> Enum.join(", ")

      sql = "INSERT INTO #{table} (#{cols_str}) VALUES #{placeholders}"

      case Duckdbex.query(conn, sql) do
        {:ok, _} ->
          {:ok, %{inserted: length(rows)}}

        {:error, reason} ->
          {:error, "Append failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Append error: #{inspect(error)}"}
    end

    defp do_export_parquet(conn, sql, output_path) do
      export_sql = "COPY (#{sql}) TO '#{output_path}' (FORMAT PARQUET)"

      case Duckdbex.query(conn, export_sql) do
        {:ok, _} ->
          {:ok, output_path}

        {:error, reason} ->
          {:error, "Export failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Export error: #{inspect(error)}"}
    end

    defp substitute_params(sql, []), do: sql

    defp substitute_params(sql, params) do
      # First pass: replace numbered $N placeholders
      sql_with_numbered =
        params
        |> Enum.with_index(1)
        |> Enum.reduce(sql, fn {value, index}, acc ->
          String.replace(acc, "$#{index}", format_value(value), global: false)
        end)

      # Second pass: replace positional ? placeholders sequentially
      # Each ? is replaced with the corresponding parameter by position
      {result, _} =
        params
        |> Enum.reduce({sql_with_numbered, 0}, fn value, {acc, count} ->
          if String.contains?(acc, "?") do
            # Replace only the first occurrence of ?
            new_sql = String.replace(acc, "?", format_value(value), global: false)
            {new_sql, count + 1}
          else
            {acc, count}
          end
        end)

      result
    end

    defp format_value(nil), do: "NULL"
    defp format_value(true), do: "TRUE"
    defp format_value(false), do: "FALSE"
    defp format_value(value) when is_binary(value), do: "'#{String.replace(value, "'", "''")}'"
    defp format_value(value) when is_integer(value), do: Integer.to_string(value)
    defp format_value(value) when is_float(value), do: Float.to_string(value)
    defp format_value(%DateTime{} = dt), do: "'#{DateTime.to_iso8601(dt)}'"
    defp format_value(%NaiveDateTime{} = dt), do: "'#{NaiveDateTime.to_iso8601(dt)}'"
    defp format_value(%Date{} = d), do: "'#{Date.to_iso8601(d)}'"
    defp format_value(value), do: "'#{inspect(value)}'"
  end
end
