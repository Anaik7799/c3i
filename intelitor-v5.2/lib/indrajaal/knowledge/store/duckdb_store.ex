defmodule Indrajaal.Knowledge.Store.DuckDBStore do
  @moduledoc """
  Analytical Storage Engine for Indrajaal Knowledge Engine (IKE).

  WHAT: DuckDB-backed columnar store for high-volume time-series and analytical data.
  WHY: SC-HOLON-003 requires DuckDB for Holon Evolution History.
  CONSTRAINTS:
    - SC-STORE-001: Append-only for history.
    - SC-STORE-002: Local file storage in data/holons/.
    - SC-DBNAME-001: UHI-based path: ex:l3:kms:srv:main:analytics
    - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    - Shared Schema with F# CEPAF#:
      - holons (uuid, path, title, holon_level, entropy_score, last_verified, meta, content_hash, content)
      - relations (source, target, type, weight)
      - vectors (uuid, vector_id, model, embedding)

  ## Architecture Note (2026-01-17)
  DuckDBStore uses DIRECT Duckdbex access because it's LOCAL holon state.
  Per SC-DBLOCAL-001, local database access bypasses Zenoh entirely.

  Cross-holon database access (different holons) uses DatabaseProxy via Zenoh.
  See: docs/architecture/ZENOH_DATABASE_BRIDGE_ARCHITECTURE.md

  ## Data Flow (LOCAL - this module)
  ```
  DuckDBStore (this module)
      │
      ▼
  Duckdbex (direct NIF)
      │
      ▼
  DuckDB (data/holons/ex/l3/kms/main/analytics.duckdb)
  ```
  """

  use GenServer
  require Logger

  # Note: DatabaseProxy is for CROSS-HOLON access only, not used here
  # alias Indrajaal.Zenoh.DatabaseProxy

  # SC-DBNAME-001: UHI ex:l3:kms:srv:main:analytics
  @db_path "data/holons/ex/l3/kms/main/analytics.duckdb"

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def query(sql, params \\ []) do
    GenServer.call(__MODULE__, {:query, sql, params})
  end

  def insert_history(holon_id, state) do
    GenServer.cast(__MODULE__, {:insert_history, holon_id, state})
  end

  @doc """
  Append a record to an append-only table.
  """
  def append(table, record) do
    GenServer.call(__MODULE__, {:append, table, record})
  end

  @doc """
  Retrieve all vectors for in-memory indexing.
  Returns: [{uuid, embedding_binary}, ...]
  """
  def get_all_vectors do
    GenServer.call(__MODULE__, :get_all_vectors)
  end

  @doc """
  Get store statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(@db_path))

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    # Open DuckDB connection directly for local holon state
    case Duckdbex.open(@db_path) do
      {:ok, conn} ->
        Logger.info("🧠 IKE: DuckDB Connection Established (SC-DBLOCAL-001 direct)")
        {:ok, %{conn: conn, path: @db_path}}

      {:error, reason} ->
        Logger.error("🧠 IKE: Failed to open DuckDB: #{inspect(reason)}")
        # Start with nil conn - will retry on first query
        {:ok, %{conn: nil, path: @db_path}}
    end
  end

  @impl true
  def handle_call({:query, sql, params}, _from, state) do
    # SC-DBLOCAL-001: Direct Duckdbex query for local connections
    state = ensure_connection(state)

    result =
      case state.conn do
        nil -> {:error, :not_connected}
        conn -> Duckdbex.query(conn, sql, params)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:append, table, record}, _from, state) do
    # SC-DBLOCAL-001: Direct Duckdbex insert for local connections
    state = ensure_connection(state)

    result =
      case state.conn do
        nil ->
          {:error, :not_connected}

        conn ->
          cols = Map.keys(record) |> Enum.join(", ")
          vals = Map.values(record)
          placeholders = Enum.map_join(1..length(vals), ", ", fn _ -> "?" end)
          sql = "INSERT INTO #{table} (#{cols}) VALUES (#{placeholders})"

          case Duckdbex.query(conn, sql, vals) do
            {:ok, _} -> {:ok, record}
            error -> error
          end
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_all_vectors, _from, state) do
    # SC-DBLOCAL-001: Direct Duckdbex query for local connections
    state = ensure_connection(state)

    sql = "SELECT uuid, embedding FROM vectors"

    result =
      case state.conn do
        nil -> {:error, :not_connected}
        conn -> Duckdbex.query(conn, sql, [])
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       path: state.path,
       status: if(state.conn, do: :connected, else: :disconnected),
       mode: :direct_local
     }, state}
  end

  @impl true
  def handle_cast({:insert_history, holon_id, state_data}, state) do
    # SC-DBLOCAL-001: Direct Duckdbex insert for local connections
    state = ensure_connection(state)

    case state.conn do
      nil ->
        Logger.warning("🧠 IKE: DuckDB not connected, skipping history insert")

      conn ->
        sql =
          "INSERT INTO holon_history (id, timestamp, state_json) VALUES (?, current_timestamp, ?)"

        Duckdbex.query(conn, sql, [holon_id, Jason.encode!(state_data)])
    end

    {:noreply, state}
  end

  # Ensure DuckDB connection exists, attempt reconnect if needed
  defp ensure_connection(%{conn: nil, path: path} = state) do
    case Duckdbex.open(path) do
      {:ok, conn} ->
        Logger.info("🧠 IKE: DuckDB reconnected")
        %{state | conn: conn}

      {:error, reason} ->
        Logger.warning("🧠 IKE: DuckDB reconnect failed: #{inspect(reason)}")
        state
    end
  end

  defp ensure_connection(state), do: state

  @impl true
  def terminate(_reason, %{conn: conn} = _state) when not is_nil(conn) do
    # SC-DBLOCAL-001: Close direct DuckDB connection on terminate
    Logger.info("🧠 IKE: DuckDBStore terminated (closing direct connection)")
    :ok
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("🧠 IKE: DuckDBStore terminated")
    :ok
  end
end
