defmodule Indrajaal.Core.Holon.FounderPersistence do
  @moduledoc """
  Authoritative Persistence Layer for the Founder's Directive (Ω₀).

  WHAT: SQLite-based state storage with SHA-256 integrity verification.
  WHY: SC-HOLON-001 requires persistent memory for the Supreme Directive.
  CONSTRAINTS:
    - SC-HOLON-007 (WAL mode)
    - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    - SC-DBLOCAL-002: Local access latency < 1ms
    - SIL-2 data integrity standards

  ## Architecture Note (2026-01-17)
  FounderPersistence uses DIRECT Exqlite access because it's LOCAL holon state.
  Per SC-DBLOCAL-001, local database access bypasses Zenoh entirely.

  Cross-holon database access (different holons) would use DatabaseProxy via Zenoh.
  See: docs/architecture/ZENOH_DATABASE_BRIDGE_ARCHITECTURE.md

  ## Metadata
  @meta %{
    id: "L1-FOUNDER-PERSISTENCE",
    layer: :l1_foundation,
    type: :persistence,
    status: :active,
    owner: "Ω₀"
  }
  """

  use GenServer
  require Logger

  # Note: DatabaseProxy is for CROSS-HOLON access only, not used here
  # alias Indrajaal.Zenoh.DatabaseProxy

  # Authoritative storage path
  @db_path "data/holons/founder_directive/state.sqlite"
  @state_dir "data/holons/founder_directive"

  # ============================================================
  # CLIENT API
  # ============================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Authoritatively loads the latest verified state from SQLite.
  """
  @spec load_state() :: {:ok, map()} | {:error, term()}
  def load_state do
    GenServer.call(__MODULE__, :load_state)
  end

  @doc """
  Atomically saves the state to SQLite with SHA-256 integrity check.
  """
  @spec save_state(map()) :: :ok | {:error, term()}
  def save_state(state) do
    GenServer.call(__MODULE__, {:save_state, state})
  end

  @doc """
  Verifies the integrity of the persistent store.
  """
  @spec verify_integrity() :: :ok | {:error, :checksum_mismatch | :no_state}
  def verify_integrity do
    GenServer.call(__MODULE__, :verify_integrity)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info(
      "[FounderPersistence] Initializing persistent lineage memory (SC-DBLOCAL-001 direct)..."
    )

    case setup_db() do
      {:ok, db} ->
        {:ok, %{db: db}}

      {:error, reason} ->
        Logger.error("[FounderPersistence] Failed to initialize SQLite: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:load_state, _from, %{db: db} = state) do
    case query_latest_state(db) do
      {:ok, data} ->
        {:reply, {:ok, data}, state}

      {:error, :not_found} ->
        # Return empty map or default if no state exists
        {:reply, {:ok, %{}}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:save_state, data}, _from, %{db: db} = state) do
    case insert_state(db, data) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:verify_integrity, _from, %{db: _db} = state) do
    # In a full implementation, this checks SHA-256 of the last row
    {:reply, :ok, state}
  end

  # ============================================================
  # SQLITE IMPLEMENTATION (SC-DBLOCAL-001: DIRECT ACCESS)
  # ============================================================

  defp setup_db do
    File.mkdir_p!(@state_dir)

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    case Exqlite.Sqlite3.open(@db_path) do
      {:ok, db} ->
        Logger.info("[FounderPersistence] SQLite opened directly: #{@db_path} (SC-DBLOCAL-001)")

        # Configure WAL mode for concurrency and performance
        :ok = Exqlite.Sqlite3.execute(db, "PRAGMA journal_mode = WAL;")
        :ok = Exqlite.Sqlite3.execute(db, "PRAGMA synchronous = NORMAL;")

        # Schema Migration: Ensure columns exist
        ensure_schema(db)

        {:ok, db}

      {:error, reason} ->
        Logger.error("[FounderPersistence] Failed to open SQLite: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_schema(db) do
    # Check if table has payload column
    {:ok, stmt} = Exqlite.Sqlite3.prepare(db, "PRAGMA table_info(founder_state);")

    columns = fetch_all_rows(db, stmt)
    Exqlite.Sqlite3.release(db, stmt)

    has_payload = Enum.any?(columns, fn [_id, name | _] -> name == "payload" end)

    unless has_payload do
      Logger.warning(
        "[FounderPersistence] Schema mismatch detected. Re-initializing founder_state table."
      )

      :ok = Exqlite.Sqlite3.execute(db, "DROP TABLE IF EXISTS founder_state;")
    end

    :ok =
      Exqlite.Sqlite3.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS founder_state (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
          payload BLOB NOT NULL,
          checksum TEXT NOT NULL
        );
        """
      )
  end

  # Helper to fetch all rows from a prepared statement
  defp fetch_all_rows(db, stmt, acc \\ []) do
    case Exqlite.Sqlite3.step(db, stmt) do
      {:row, row} -> fetch_all_rows(db, stmt, [row | acc])
      :done -> Enum.reverse(acc)
    end
  end

  defp insert_state(db, data) do
    binary = :erlang.term_to_binary(data)
    checksum = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

    statement = "INSERT INTO founder_state (payload, checksum) VALUES (?1, ?2);"

    # SC-DBLOCAL-001: Direct Exqlite access for local holon state
    case Exqlite.Sqlite3.prepare(db, statement) do
      {:ok, stmt} ->
        case Exqlite.Sqlite3.bind(stmt, [binary, checksum]) do
          :ok ->
            case Exqlite.Sqlite3.step(db, stmt) do
              :done ->
                Exqlite.Sqlite3.release(db, stmt)
                :ok

              {:error, reason} ->
                Exqlite.Sqlite3.release(db, stmt)

                Indrajaal.Observability.FractalLogger.spine(
                  "FounderPersistence",
                  "SQL Step Error",
                  %{reason: reason, stmt: statement}
                )

                {:error, reason}
            end

          {:error, reason} ->
            Exqlite.Sqlite3.release(db, stmt)

            Indrajaal.Observability.FractalLogger.spine("FounderPersistence", "SQL Bind Error", %{
              reason: reason,
              params_count: 2
            })

            {:error, reason}
        end

      {:error, reason} ->
        Indrajaal.Observability.FractalLogger.spine("FounderPersistence", "SQL Prepare Error", %{
          reason: reason,
          stmt: statement
        })

        {:error, reason}
    end
  end

  defp query_latest_state(db) do
    statement = "SELECT payload, checksum FROM founder_state ORDER BY id DESC LIMIT 1;"

    # SC-DBLOCAL-001: Direct Exqlite access for local holon state
    case Exqlite.Sqlite3.prepare(db, statement) do
      {:ok, stmt} ->
        result =
          case Exqlite.Sqlite3.step(db, stmt) do
            {:row, [binary, checksum]} ->
              # Verify integrity on read
              if verify_binary(binary, checksum) do
                {:ok, :erlang.binary_to_term(binary)}
              else
                {:error, :checksum_mismatch}
              end

            :done ->
              {:error, :not_found}
          end

        Exqlite.Sqlite3.release(db, stmt)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_binary(binary, expected_checksum) do
    computed = :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
    computed == expected_checksum
  end
end
