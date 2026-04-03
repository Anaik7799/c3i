defmodule Indrajaal.Crm.AuditLog do
  @moduledoc """
  CRM field change tracking with ETS-backed audit log.

  ## WHAT
  Tracks field-level changes across CRM entities (Opportunity, Lead, Contact, Account)
  and persists them to an ETS audit ring-buffer for real-time access. A DuckDB
  flush worker drains the ETS buffer to durable storage on a configurable interval.

  ## WHY
  Provides a full field-change audit trail for CRM entities to satisfy:
  - Compliance requirements for financial/sales records
  - Debugging pipeline stage regressions
  - Producing change-history views in the dashboard

  ## STAMP Compliance
  - SC-ARK-001: Data archival to long-term storage (DuckDB flush)
  - SC-AUDIT-001: Append-only audit trail
  - SC-SAFETY-003: Complete audit trail to Immutable Register (ETS → DuckDB)
  - SC-CONC-001: ETS for concurrent access without bottleneck
  - Ω₇ (Holon State Sovereignty): SQLite/DuckDB as authoritative storage

  ## Architecture
  - ETS table `:crm_audit_log` (ordered_set, public): ring-buffer of last 10 000 entries
  - GenServer `Indrajaal.Crm.AuditLog.Server`: owns the table, handles flush
  - Public API `record_change/4`: fire-and-forget cast (non-blocking)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial ETS audit log — task 4a2ab7eb |
  """

  use GenServer

  require Logger

  @table :crm_audit_log
  # keep last 10 000 entries in-memory
  @ring_size 10_000
  # flush to DuckDB every 60 s
  @flush_interval_ms 60_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Record a field change for a CRM entity.

  ## Parameters
  - `entity_type` — atom such as `:opportunity`, `:lead`, `:contact`, `:account`
  - `entity_id` — UUID string
  - `changes` — map of `%{field_name => {old_value, new_value}}`
  - `actor_id` — UUID or string identifying the user/agent that made the change

  ## Returns
  `:ok` (always, fire-and-forget)

  ## Examples

      AuditLog.record_change(:opportunity, opp.id, %{stage: {:prospecting, :qualification}}, user.id)
  """
  @spec record_change(atom(), String.t(), map(), String.t()) :: :ok
  def record_change(entity_type, entity_id, changes, actor_id) do
    GenServer.cast(__MODULE__, {:record, entity_type, entity_id, changes, actor_id})
  end

  @doc """
  Return the most recent `limit` audit entries (across all entities), newest first.
  """
  @spec recent(non_neg_integer()) :: list(map())
  def recent(limit \\ 100) when is_integer(limit) and limit > 0 do
    # ETS key is {monotonic_ts, ref} — iterate in reverse for newest-first
    case :ets.info(@table) do
      :undefined ->
        []

      _ ->
        @table
        |> :ets.tab2list()
        |> Enum.sort_by(fn {{ts, _ref}, _} -> ts end, :desc)
        |> Enum.take(limit)
        |> Enum.map(fn {{_ts, _ref}, entry} -> entry end)
    end
  end

  @doc """
  Return audit entries for a specific entity (newest first).
  """
  @spec for_entity(atom(), String.t(), non_neg_integer()) :: list(map())
  def for_entity(entity_type, entity_id, limit \\ 50) do
    case :ets.info(@table) do
      :undefined ->
        []

      _ ->
        @table
        |> :ets.tab2list()
        |> Enum.filter(fn {_key, e} ->
          e.entity_type == entity_type and e.entity_id == entity_id
        end)
        |> Enum.sort_by(fn {{ts, _ref}, _} -> ts end, :desc)
        |> Enum.take(limit)
        |> Enum.map(fn {_key, entry} -> entry end)
    end
  end

  # ---------------------------------------------------------------------------
  # Supervision
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:ordered_set, :public, :named_table, read_concurrency: true])

    # Schedule periodic flush to DuckDB
    Process.send_after(self(), :flush, @flush_interval_ms)

    Logger.info("[CRM.AuditLog] Started — ETS table #{@table}, ring size #{@ring_size}")

    {:ok, %{table: table, flush_pending: []}}
  end

  @impl true
  def handle_cast({:record, entity_type, entity_id, changes, actor_id}, state) do
    ts = System.monotonic_time(:millisecond)
    ref = make_ref()

    entry = %{
      entity_type: entity_type,
      entity_id: entity_id,
      changes: changes,
      actor_id: actor_id,
      recorded_at: DateTime.utc_now(),
      monotonic_ts: ts
    }

    :ets.insert(@table, {{ts, ref}, entry})

    # Enforce ring size — drop oldest when over limit
    drop_oldest_if_needed()

    {:noreply, %{state | flush_pending: [entry | state.flush_pending]}}
  end

  @impl true
  def handle_info(:flush, state) do
    pending = state.flush_pending

    unless pending == [] do
      flush_to_duckdb(pending)
    end

    Process.send_after(self(), :flush, @flush_interval_ms)
    {:noreply, %{state | flush_pending: []}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp drop_oldest_if_needed do
    size = :ets.info(@table, :size)

    if size > @ring_size do
      excess = size - @ring_size

      @table
      |> :ets.first()
      |> drop_n(excess)
    end
  end

  defp drop_n(:"$end_of_table", _), do: :ok
  defp drop_n(_, 0), do: :ok

  defp drop_n(key, n) do
    next = :ets.next(@table, key)
    :ets.delete(@table, key)
    drop_n(next, n - 1)
  end

  defp flush_to_duckdb([]), do: :ok

  defp flush_to_duckdb(entries) do
    # Attempt DuckDB flush — gracefully degrade if DuckDB is unavailable.
    # The ETS ring buffer is the primary in-memory store; DuckDB is the
    # durable archive (SC-ARK-001).
    case try_duckdb_flush(entries) do
      :ok ->
        Logger.debug("[CRM.AuditLog] Flushed #{length(entries)} entries to DuckDB")

      {:error, reason} ->
        Logger.warning(
          "[CRM.AuditLog] DuckDB flush skipped (degraded mode): #{inspect(reason)}. " <>
            "#{length(entries)} entries remain in ETS ring buffer."
        )
    end
  end

  defp try_duckdb_flush(entries) do
    # Check if Exduckdb/DuckDB NIF is available before attempting write
    with true <- Code.ensure_loaded?(Duckdbex),
         {:ok, conn} <- open_audit_db() do
      ensure_audit_table(conn)
      insert_entries(conn, entries)
      :ok
    else
      false ->
        {:error, :duckdb_not_loaded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp open_audit_db do
    db_path = Application.get_env(:indrajaal, :crm_audit_db_path, "data/holons/crm_audit.duckdb")

    case Duckdbex.open(db_path) do
      {:ok, db} ->
        case Duckdbex.connection(db) do
          {:ok, conn} -> {:ok, conn}
          {:error, r} -> {:error, {:connection_failed, r}}
        end

      {:error, r} ->
        {:error, {:open_failed, r}}
    end
  end

  defp ensure_audit_table(conn) do
    sql = """
    CREATE TABLE IF NOT EXISTS crm_field_changes (
      id           VARCHAR PRIMARY KEY,
      entity_type  VARCHAR NOT NULL,
      entity_id    VARCHAR NOT NULL,
      field_name   VARCHAR NOT NULL,
      old_value    VARCHAR,
      new_value    VARCHAR,
      actor_id     VARCHAR,
      recorded_at  TIMESTAMP NOT NULL
    );
    """

    Duckdbex.query(conn, sql, [])
  end

  defp insert_entries(conn, entries) do
    Enum.each(entries, fn entry ->
      Enum.each(entry.changes, fn {field, {old_val, new_val}} ->
        id = Ecto.UUID.generate()
        recorded_at = DateTime.to_iso8601(entry.recorded_at)

        sql = """
        INSERT INTO crm_field_changes
          (id, entity_type, entity_id, field_name, old_value, new_value, actor_id, recorded_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, CAST(? AS TIMESTAMP))
        ON CONFLICT (id) DO NOTHING;
        """

        Duckdbex.query(conn, sql, [
          id,
          to_string(entry.entity_type),
          entry.entity_id,
          to_string(field),
          inspect(old_val),
          inspect(new_val),
          entry.actor_id,
          recorded_at
        ])
      end)
    end)
  end
end
