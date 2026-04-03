defmodule Indrajaal.Zenoh.DatabaseProxy do
  @moduledoc """
  Database Proxy for routing all DuckDB/SQLite access through Zenoh to CEPAF F#.

  ## WHAT
  Routes all database queries through the Zenoh mesh to CEPAF F# backend,
  which has authoritative access to DuckDB and SQLite databases.

  ## WHY
  - SC-HOLON-009: SQLite/DuckDB is the ONLY authoritative source of holon state
  - SC-SYNC-001: All database access must be synchronized through Zenoh
  - AOR-HOLON-001: All holon state must be stored in SQLite (WAL mode)
  - AOR-HOLON-002: All holon history must be stored in DuckDB

  ## ARCHITECTURE
  ```
  Elixir Code
      │
      ▼
  DatabaseProxy (this module)
      │
      ▼
  Zenoh Pub/Sub
      │
      ▼
  CEPAF F# Bridge
      │
      ▼
  DuckDB / SQLite
  ```

  ## CONSTRAINTS
  - SC-ZENOH-001: Zenoh NIF must be loaded
  - SC-BRIDGE-001: Message buffer FIFO ordering
  - SC-PRF-050: Latency < 50ms for queries

  ## Usage
  ```elixir
  # DuckDB query
  {:ok, result} = DatabaseProxy.duckdb_query("SELECT * FROM holons")

  # SQLite query
  {:ok, result} = DatabaseProxy.sqlite_query("SELECT * FROM kms_keys")

  # Insert with table specification
  :ok = DatabaseProxy.duckdb_insert("holons", %{id: uuid, data: json})
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohSession

  # Zenoh topics for database communication
  @duckdb_request_topic "indrajaal/db/duckdb/request"
  @duckdb_response_topic "indrajaal/db/duckdb/response"
  @sqlite_request_topic "indrajaal/db/sqlite/request"
  @sqlite_response_topic "indrajaal/db/sqlite/response"

  # Timeout for database operations (SC-PRF-050: <50ms preferred)
  @default_timeout_ms 5_000

  # State structure
  defstruct [
    :duckdb_subscriber,
    :sqlite_subscriber,
    :pending_requests,
    :stats
  ]

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Execute a DuckDB query via Zenoh → CEPAF F#.

  ## Parameters
  - `sql` - SQL query string
  - `params` - Query parameters (default [])
  - `timeout` - Timeout in ms (default 5000)

  ## Returns
  - `{:ok, result}` - Query result
  - `{:error, reason}` - Query failed
  """
  @spec duckdb_query(String.t(), list(), non_neg_integer()) ::
          {:ok, any()} | {:error, any()}
  def duckdb_query(sql, params \\ [], timeout \\ @default_timeout_ms) do
    GenServer.call(__MODULE__, {:duckdb_query, sql, params}, timeout + 1000)
  end

  @doc """
  Execute a DuckDB insert via Zenoh → CEPAF F#.

  ## Parameters
  - `table` - Table name
  - `record` - Map of column -> value
  - `timeout` - Timeout in ms

  ## Returns
  - `:ok` - Insert successful
  - `{:error, reason}` - Insert failed
  """
  @spec duckdb_insert(String.t(), map(), non_neg_integer()) :: :ok | {:error, any()}
  def duckdb_insert(table, record, timeout \\ @default_timeout_ms) do
    GenServer.call(__MODULE__, {:duckdb_insert, table, record}, timeout + 1000)
  end

  @doc """
  Execute a SQLite query via Zenoh → CEPAF F#.

  ## Parameters
  - `sql` - SQL query string
  - `params` - Query parameters (default [])
  - `timeout` - Timeout in ms (default 5000)

  ## Returns
  - `{:ok, result}` - Query result
  - `{:error, reason}` - Query failed
  """
  @spec sqlite_query(String.t(), list(), non_neg_integer()) ::
          {:ok, any()} | {:error, any()}
  def sqlite_query(sql, params \\ [], timeout \\ @default_timeout_ms) do
    GenServer.call(__MODULE__, {:sqlite_query, sql, params}, timeout + 1000)
  end

  @doc """
  Execute a SQLite command (INSERT, UPDATE, DELETE) via Zenoh → CEPAF F#.

  ## Parameters
  - `sql` - SQL command string
  - `params` - Command parameters
  - `timeout` - Timeout in ms

  ## Returns
  - `{:ok, rows_affected}` - Command successful
  - `{:error, reason}` - Command failed
  """
  @spec sqlite_execute(String.t(), list(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, any()}
  def sqlite_execute(sql, params \\ [], timeout \\ @default_timeout_ms) do
    GenServer.call(__MODULE__, {:sqlite_execute, sql, params}, timeout + 1000)
  end

  @doc """
  Open a SQLite database via Zenoh → CEPAF F#.

  ## Parameters
  - `db_path` - Path to SQLite database file
  - `timeout` - Timeout in ms

  ## Returns
  - `{:ok, connection_id}` - Connection reference
  - `{:error, reason}` - Open failed
  """
  @spec sqlite_open(String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, any()}
  def sqlite_open(db_path, timeout \\ @default_timeout_ms) do
    GenServer.call(__MODULE__, {:sqlite_open, db_path}, timeout + 1000)
  end

  @doc """
  Close a SQLite database via Zenoh → CEPAF F#.

  ## Parameters
  - `connection_id` - Connection reference from sqlite_open

  ## Returns
  - `:ok` - Close successful
  - `{:error, reason}` - Close failed
  """
  @spec sqlite_close(String.t()) :: :ok | {:error, any()}
  def sqlite_close(connection_id) do
    GenServer.call(__MODULE__, {:sqlite_close, connection_id})
  end

  @doc """
  Get database proxy statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    Logger.info("[DatabaseProxy] Initializing Zenoh database proxy")

    state = %__MODULE__{
      duckdb_subscriber: nil,
      sqlite_subscriber: nil,
      pending_requests: %{},
      stats: initial_stats()
    }

    # Subscribe to response topics
    send(self(), :subscribe_responses)

    {:ok, state}
  end

  @impl true
  def handle_call({:duckdb_query, sql, params}, from, state) do
    request_id = generate_request_id()

    request = %{
      request_id: request_id,
      type: "query",
      sql: sql,
      params: params,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case publish_request(@duckdb_request_topic, request) do
      :ok ->
        new_pending =
          Map.put(
            state.pending_requests,
            request_id,
            {from, :duckdb, System.monotonic_time(:millisecond)}
          )

        new_stats = update_stats(state.stats, :duckdb_query)
        {:noreply, %{state | pending_requests: new_pending, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:duckdb_insert, table, record}, from, state) do
    request_id = generate_request_id()

    request = %{
      request_id: request_id,
      type: "insert",
      table: table,
      record: record,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case publish_request(@duckdb_request_topic, request) do
      :ok ->
        new_pending =
          Map.put(
            state.pending_requests,
            request_id,
            {from, :duckdb, System.monotonic_time(:millisecond)}
          )

        new_stats = update_stats(state.stats, :duckdb_insert)
        {:noreply, %{state | pending_requests: new_pending, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:sqlite_query, sql, params}, from, state) do
    request_id = generate_request_id()

    request = %{
      request_id: request_id,
      type: "query",
      sql: sql,
      params: params,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case publish_request(@sqlite_request_topic, request) do
      :ok ->
        new_pending =
          Map.put(
            state.pending_requests,
            request_id,
            {from, :sqlite, System.monotonic_time(:millisecond)}
          )

        new_stats = update_stats(state.stats, :sqlite_query)
        {:noreply, %{state | pending_requests: new_pending, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:sqlite_execute, sql, params}, from, state) do
    request_id = generate_request_id()

    request = %{
      request_id: request_id,
      type: "execute",
      sql: sql,
      params: params,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case publish_request(@sqlite_request_topic, request) do
      :ok ->
        new_pending =
          Map.put(
            state.pending_requests,
            request_id,
            {from, :sqlite, System.monotonic_time(:millisecond)}
          )

        new_stats = update_stats(state.stats, :sqlite_execute)
        {:noreply, %{state | pending_requests: new_pending, stats: new_stats}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:sqlite_open, db_path}, from, state) do
    request_id = generate_request_id()

    request = %{
      request_id: request_id,
      type: "open",
      db_path: db_path,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case publish_request(@sqlite_request_topic, request) do
      :ok ->
        new_pending =
          Map.put(
            state.pending_requests,
            request_id,
            {from, :sqlite, System.monotonic_time(:millisecond)}
          )

        {:noreply, %{state | pending_requests: new_pending}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:sqlite_close, connection_id}, from, state) do
    request_id = generate_request_id()

    request = %{
      request_id: request_id,
      type: "close",
      connection_id: connection_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case publish_request(@sqlite_request_topic, request) do
      :ok ->
        new_pending =
          Map.put(
            state.pending_requests,
            request_id,
            {from, :sqlite, System.monotonic_time(:millisecond)}
          )

        {:noreply, %{state | pending_requests: new_pending}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info(:subscribe_responses, state) do
    # Subscribe to DuckDB responses
    duckdb_sub =
      case ZenohSession.subscribe(@duckdb_response_topic, self()) do
        {:ok, ref} ->
          Logger.debug("[DatabaseProxy] Subscribed to DuckDB responses")
          ref

        {:error, reason} ->
          Logger.warning(
            "[DatabaseProxy] Failed to subscribe to DuckDB responses: #{inspect(reason)}"
          )

          nil
      end

    # Subscribe to SQLite responses
    sqlite_sub =
      case ZenohSession.subscribe(@sqlite_response_topic, self()) do
        {:ok, ref} ->
          Logger.debug("[DatabaseProxy] Subscribed to SQLite responses")
          ref

        {:error, reason} ->
          Logger.warning(
            "[DatabaseProxy] Failed to subscribe to SQLite responses: #{inspect(reason)}"
          )

          nil
      end

    {:noreply, %{state | duckdb_subscriber: duckdb_sub, sqlite_subscriber: sqlite_sub}}
  end

  @impl true
  def handle_info({:zenoh_message, topic, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"request_id" => request_id} = response} ->
        handle_response(request_id, topic, response, state)

      {:error, reason} ->
        Logger.warning("[DatabaseProxy] Failed to decode response: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Unsubscribe from topics
    if state.duckdb_subscriber, do: ZenohSession.unsubscribe(state.duckdb_subscriber)
    if state.sqlite_subscriber, do: ZenohSession.unsubscribe(state.sqlite_subscriber)
    :ok
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp handle_response(request_id, _topic, response, state) do
    case Map.pop(state.pending_requests, request_id) do
      {{from, db_type, start_time}, new_pending} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        # Emit telemetry
        :telemetry.execute(
          [:database_proxy, db_type, :response],
          %{duration_ms: elapsed},
          %{request_id: request_id}
        )

        # Send reply based on response status
        reply =
          case response do
            %{"status" => "ok", "result" => result} -> {:ok, result}
            %{"status" => "error", "error" => error} -> {:error, error}
            other -> {:error, {:unexpected_response, other}}
          end

        GenServer.reply(from, reply)

        new_stats = update_stats(state.stats, :response_received, elapsed)
        {:noreply, %{state | pending_requests: new_pending, stats: new_stats}}

      {nil, _} ->
        Logger.warning("[DatabaseProxy] Received response for unknown request: #{request_id}")
        {:noreply, state}
    end
  end

  defp publish_request(topic, request) do
    case Jason.encode(request) do
      {:ok, payload} ->
        ZenohSession.publish(topic, payload)

      {:error, reason} ->
        Logger.error("[DatabaseProxy] Failed to encode request: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp initial_stats do
    %{
      duckdb_queries: 0,
      duckdb_inserts: 0,
      sqlite_queries: 0,
      sqlite_executes: 0,
      responses_received: 0,
      total_latency_ms: 0,
      avg_latency_ms: 0.0,
      started_at: DateTime.utc_now()
    }
  end

  defp update_stats(stats, :duckdb_query) do
    %{stats | duckdb_queries: stats.duckdb_queries + 1}
  end

  defp update_stats(stats, :duckdb_insert) do
    %{stats | duckdb_inserts: stats.duckdb_inserts + 1}
  end

  defp update_stats(stats, :sqlite_query) do
    %{stats | sqlite_queries: stats.sqlite_queries + 1}
  end

  defp update_stats(stats, :sqlite_execute) do
    %{stats | sqlite_executes: stats.sqlite_executes + 1}
  end

  defp update_stats(stats, :response_received, latency_ms) do
    total = stats.responses_received + 1
    total_latency = stats.total_latency_ms + latency_ms

    %{
      stats
      | responses_received: total,
        total_latency_ms: total_latency,
        avg_latency_ms: total_latency / total
    }
  end
end
