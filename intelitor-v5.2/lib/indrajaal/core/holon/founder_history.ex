defmodule Indrajaal.Core.Holon.FounderHistory do
  @moduledoc """
  Immutable history module for Founder's Directive holon.

  WHAT: DuckDB-based append-only event log (SC-HOLON-003)
  WHY: Evolution history per Ω₈ (Immutable Register)
  CONSTRAINTS: SC-HOLON-019 (append-only), SC-REG-001 (cryptographic chain)

  History is stored in data/holons/founder_directive/history.duckdb

  ## P0-4 Fix (2026-01-15)

  Implements AOR-HOLON-002 compliance with proper DuckDB persistence:
  - Events persisted to DuckDB on append
  - query_events/2 queries from DuckDB (no longer returns [])
  - Hash chain verification implemented
  - Latest hash retrieved from actual data

  ## STAMP Constraints
  - SC-HOLON-003: DuckDB-based append-only event log
  - SC-HOLON-019: Append-only history
  - SC-REG-001: Cryptographic chain integrity
  - AOR-HOLON-002: DuckDB for evolution history
  """

  require Logger

  # History directory and database path for DuckDB storage
  @history_dir "data/holons/founder_directive"
  @db_path "data/holons/founder_directive/history.duckdb"
  @genesis_hash "0000000000000000000000000000000000000000000000000000000000000000"

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Append an event to the holon's history.
  Events are cryptographically chained (SHA-256).

  Persists to DuckDB per AOR-HOLON-002.

  ## Implementation Note
  Uses a single connection for both reading latest hash and writing the new event
  to ensure transactional consistency (fixes hash chain linkage).
  """
  def append_event(event_type, payload, metadata \\ %{}) do
    with_connection(fn conn ->
      # Get the latest hash within the same connection for chain linking
      prev_hash = get_latest_hash_from_conn(conn)

      event = %{
        id: generate_event_id(),
        type: event_type,
        payload: payload,
        metadata: metadata,
        timestamp: DateTime.utc_now(),
        prev_hash: prev_hash
      }

      # Hash the event for chain integrity (SC-REG-001)
      event_hash = hash_event(event)
      stored_event = Map.put(event, :hash, event_hash)

      Logger.debug(
        "[FounderHistory] append_event id=#{event.id} type=#{inspect(event.type)} hash=#{event_hash}"
      )

      # Persist to DuckDB within same connection (AOR-HOLON-002)
      case persist_event_to_conn(conn, stored_event) do
        :ok ->
          Logger.debug("[FounderHistory] Event appended: #{event_type} [#{event_hash}]")
          # Trigger mesh replication
          Indrajaal.Core.Holon.LegacyReplicator.replicate_event(stored_event)
          {:ok, stored_event}

        {:error, reason} ->
          Logger.error("[FounderHistory] Failed to persist event: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  @doc """
  Verifies and stores an event received from a peer.
  """
  def verify_and_store_remote_event(event) do
    # 1. Verify hash integrity
    computed_hash = hash_event(event)

    if computed_hash == event.hash do
      # 2. Verify chain linkage
      case verify_chain_link(event) do
        :ok ->
          # 3. Store in DuckDB
          persist_event(event)

        error ->
          error
      end
    else
      {:error, :invalid_hash}
    end
  end

  @doc """
  Query history events by type.

  ## Options
  - `:limit` - Maximum number of events to return (default: 100)
  - `:since` - Only return events after this DateTime

  ## Examples

      iex> FounderHistory.query_events(:state_change)
      {:ok, [%{id: "evt_...", type: :state_change, ...}]}

      iex> FounderHistory.query_events(:all, limit: 10)
      {:ok, [%{...}, ...]}
  """
  def query_events(event_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    since = Keyword.get(opts, :since, nil)

    with_connection(fn conn ->
      {sql, params} = build_query_sql(event_type, since, limit)

      case Duckdbex.query(conn, sql, params) do
        {:ok, result} ->
          events =
            result
            |> fetch_all_rows()
            |> Enum.map(&row_to_event/1)
            |> Enum.reject(&is_nil/1)

          {:ok, events}

        {:error, reason} ->
          Logger.error("[FounderHistory] Query failed: #{inspect(reason)}")
          {:ok, []}
      end
    end)
  end

  @doc """
  Get the latest event hash for chain verification.
  """
  def latest_hash do
    get_latest_hash_from_db()
  end

  @doc """
  Verify the integrity of the history chain.
  Returns {:ok, :verified} if chain is valid, {:error, reason} otherwise.
  """
  def verify_chain do
    with_connection(fn conn ->
      sql = "SELECT * FROM founder_events ORDER BY timestamp ASC"

      case Duckdbex.query(conn, sql, []) do
        {:ok, result} ->
          events =
            result
            |> fetch_all_rows()
            |> Enum.map(&row_to_event/1)
            |> Enum.reject(&is_nil/1)

          verify_chain_integrity(events)

        {:error, reason} ->
          Logger.error("[FounderHistory] Chain verification query failed: #{inspect(reason)}")
          {:error, :query_failed}
      end
    end)
  end

  @doc """
  Get all events (for debugging/inspection).
  """
  def all_events do
    query_events(:all, limit: 10_000)
  end

  @doc """
  Get event count.
  """
  def event_count do
    with_connection(fn conn ->
      sql = "SELECT COUNT(*) as count FROM founder_events"

      case Duckdbex.query(conn, sql, []) do
        {:ok, result} ->
          case fetch_all_rows(result) do
            [[count]] -> {:ok, count}
            _ -> {:ok, 0}
          end

        {:error, _} ->
          {:ok, 0}
      end
    end)
  end

  # ============================================================================
  # Private: DuckDB Operations
  # ============================================================================

  defp with_connection(fun) do
    # Ensure directory exists
    File.mkdir_p!(@history_dir)

    case Duckdbex.open(@db_path) do
      {:ok, db} ->
        case Duckdbex.connection(db) do
          {:ok, conn} ->
            # Ensure schema exists
            ensure_schema(conn)
            result = fun.(conn)
            # Force checkpoint to ensure WAL is flushed to main database
            # This ensures subsequent connections can see our changes
            case Duckdbex.query(conn, "CHECKPOINT", []) do
              {:ok, r} -> Duckdbex.fetch_all(r)
              _ -> nil
            end

            result

          {:error, reason} ->
            Logger.error("[FounderHistory] DuckDB connection failed: #{inspect(reason)}")
            {:error, {:connection_failed, reason}}
        end

      {:error, reason} ->
        Logger.error("[FounderHistory] DuckDB open failed: #{inspect(reason)}")
        {:error, {:open_failed, reason}}
    end
  rescue
    e ->
      Logger.error("[FounderHistory] DuckDB error: #{inspect(e)}")
      {:error, {:duckdb_error, e}}
  end

  defp ensure_schema(conn) do
    sql = """
    CREATE TABLE IF NOT EXISTS founder_events (
      id VARCHAR PRIMARY KEY,
      event_type VARCHAR NOT NULL,
      payload JSON NOT NULL,
      metadata JSON,
      timestamp TIMESTAMP NOT NULL,
      prev_hash VARCHAR(64) NOT NULL,
      hash VARCHAR(64) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """

    case Duckdbex.query(conn, sql, []) do
      {:ok, result} ->
        # Must fetch to execute the DDL
        Duckdbex.fetch_all(result)

        # Create indexes for efficient querying (with fetch to ensure execution)
        index_sql = """
        CREATE INDEX IF NOT EXISTS idx_founder_events_type
          ON founder_events(event_type)
        """

        case Duckdbex.query(conn, index_sql, []) do
          {:ok, r} -> Duckdbex.fetch_all(r)
          _ -> nil
        end

        timestamp_idx_sql = """
        CREATE INDEX IF NOT EXISTS idx_founder_events_timestamp
          ON founder_events(timestamp)
        """

        case Duckdbex.query(conn, timestamp_idx_sql, []) do
          {:ok, r} -> Duckdbex.fetch_all(r)
          _ -> nil
        end

        :ok

      {:error, reason} ->
        Logger.warning("[FounderHistory] Schema creation warning: #{inspect(reason)}")
        :ok
    end
  rescue
    _ -> :ok
  end

  # Connection-aware helper to get latest hash (used within append_event)
  defp get_latest_hash_from_conn(conn) do
    sql = "SELECT hash FROM founder_events ORDER BY timestamp DESC LIMIT 1"

    case Duckdbex.query(conn, sql, []) do
      {:ok, result} ->
        case fetch_all_rows(result) do
          [[hash]] when is_binary(hash) -> hash
          _ -> @genesis_hash
        end

      {:error, _} ->
        @genesis_hash
    end
  end

  # Connection-aware helper to persist event (used within append_event)
  defp persist_event_to_conn(conn, event) do
    sql = """
    INSERT INTO founder_events
      (id, event_type, payload, metadata, timestamp, prev_hash, hash)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    """

    timestamp_str = DateTime.to_iso8601(event.timestamp)
    payload_json = Jason.encode!(event.payload)
    metadata_json = Jason.encode!(event.metadata || %{})

    Logger.debug("[FounderHistory] persist_event id=#{event.id} timestamp=#{timestamp_str}")

    params = [
      event.id,
      to_string(event.type),
      payload_json,
      metadata_json,
      timestamp_str,
      event.prev_hash,
      event.hash
    ]

    case Duckdbex.query(conn, sql, params) do
      {:ok, result} ->
        # Fetch all to ensure the INSERT is executed and committed
        Duckdbex.fetch_all(result)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_event(event) do
    with_connection(fn conn ->
      sql = """
      INSERT INTO founder_events
        (id, event_type, payload, metadata, timestamp, prev_hash, hash)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (id) DO NOTHING
      """

      timestamp_str = DateTime.to_iso8601(event.timestamp)
      payload_json = Jason.encode!(event.payload)
      metadata_json = Jason.encode!(event.metadata || %{})

      params = [
        event.id,
        to_string(event.type),
        payload_json,
        metadata_json,
        timestamp_str,
        event.prev_hash,
        event.hash
      ]

      case Duckdbex.query(conn, sql, params) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp get_latest_hash_from_db do
    with_connection(fn conn ->
      sql = "SELECT hash FROM founder_events ORDER BY timestamp DESC LIMIT 1"

      case Duckdbex.query(conn, sql, []) do
        {:ok, result} ->
          case fetch_all_rows(result) do
            [[hash]] when is_binary(hash) -> {:ok, hash}
            _ -> {:ok, @genesis_hash}
          end

        {:error, _} ->
          {:ok, @genesis_hash}
      end
    end)
  end

  defp build_query_sql(:all, nil, limit) do
    {"SELECT * FROM founder_events ORDER BY timestamp DESC LIMIT ?", [limit]}
  end

  defp build_query_sql(:all, since, limit) do
    {"SELECT * FROM founder_events WHERE timestamp > ? ORDER BY timestamp DESC LIMIT ?",
     [DateTime.to_iso8601(since), limit]}
  end

  defp build_query_sql(event_type, nil, limit) do
    {"SELECT * FROM founder_events WHERE event_type = ? ORDER BY timestamp DESC LIMIT ?",
     [to_string(event_type), limit]}
  end

  defp build_query_sql(event_type, since, limit) do
    {"SELECT * FROM founder_events WHERE event_type = ? AND timestamp > ? ORDER BY timestamp DESC LIMIT ?",
     [to_string(event_type), DateTime.to_iso8601(since), limit]}
  end

  defp fetch_all_rows(result) do
    # Duckdbex.fetch_all returns rows directly, not {:ok, rows}
    case Duckdbex.fetch_all(result) do
      {:ok, data} -> data
      list when is_list(list) -> list
      _ -> []
    end
  rescue
    _ -> []
  end

  defp row_to_event([
         id,
         event_type,
         payload_json,
         metadata_json,
         timestamp,
         prev_hash,
         hash | _rest
       ]) do
    Logger.debug("[FounderHistory] row_to_event id=#{id} raw_timestamp=#{inspect(timestamp)}")

    payload =
      case Jason.decode(payload_json) do
        {:ok, p} -> p
        _ -> %{}
      end

    metadata =
      case Jason.decode(metadata_json || "{}") do
        {:ok, m} -> m
        _ -> %{}
      end

    timestamp_dt =
      case timestamp do
        %DateTime{} = dt ->
          dt

        ts when is_binary(ts) ->
          DateTime.from_iso8601(ts) |> elem(1)

        # DuckDB returns timestamps as {{year, month, day}, {hour, minute, second, microsecond}}
        {{year, month, day}, {hour, minute, second, microsecond}}
        when is_integer(year) and is_integer(month) and is_integer(day) and
               is_integer(hour) and is_integer(minute) and is_integer(second) and
               is_integer(microsecond) ->
          {:ok, dt} =
            DateTime.new(
              Date.new!(year, month, day),
              Time.new!(hour, minute, second, {microsecond, 6})
            )

          dt

        _ ->
          DateTime.utc_now()
      end

    Logger.debug(
      "[FounderHistory] row_to_event id=#{id} parsed_timestamp=#{DateTime.to_iso8601(timestamp_dt)}"
    )

    %{
      id: id,
      type: String.to_atom(event_type),
      payload: payload,
      metadata: metadata,
      timestamp: timestamp_dt,
      prev_hash: prev_hash,
      hash: hash
    }
  rescue
    _ -> nil
  end

  defp row_to_event(_), do: nil

  defp verify_chain_link(event) do
    {:ok, latest} = get_latest_hash_from_db()

    if event.prev_hash == latest do
      :ok
    else
      {:error, :chain_broken}
    end
  end

  defp verify_chain_integrity([]), do: {:ok, :verified}

  defp verify_chain_integrity(events) do
    result =
      events
      |> Enum.reduce_while({:ok, @genesis_hash}, fn event, {:ok, expected_prev} ->
        computed_hash = hash_event(event)

        cond do
          event.prev_hash != expected_prev ->
            {:halt, {:error, {:chain_broken, event.id, expected_prev, event.prev_hash}}}

          computed_hash != event.hash ->
            Logger.warning(
              "[FounderHistory] Hash mismatch id=#{event.id} stored=#{event.hash} computed=#{computed_hash}"
            )

            {:halt, {:error, {:hash_mismatch, event.id}}}

          true ->
            {:cont, {:ok, event.hash}}
        end
      end)

    case result do
      {:ok, _} -> {:ok, :verified}
      error -> error
    end
  end

  # ============================================================================
  # Private: Cryptography
  # ============================================================================

  defp generate_event_id do
    "evt_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp hash_event(event) do
    # Exclude hash key itself if present to ensure idempotency
    data_to_hash = Map.delete(event, :hash)

    # Normalize the event to ensure consistent hashing regardless of
    # whether data was just created (atom keys) or retrieved from DB (string keys)
    # We use a canonical form with sorted keys for consistent hashing
    #
    # The canonical form is a sorted keyword list representation:
    # - id: string
    # - metadata: canonicalized sorted list
    # - payload: canonicalized sorted list
    # - prev_hash: string
    # - timestamp: ISO8601 string
    # - type: string
    canonical = [
      {:id, data_to_hash.id},
      {:metadata, canonicalize(data_to_hash.metadata || %{})},
      {:payload, canonicalize(data_to_hash.payload)},
      {:prev_hash, data_to_hash.prev_hash},
      {:timestamp, DateTime.to_iso8601(data_to_hash.timestamp)},
      {:type, to_string(data_to_hash.type)}
    ]

    canonical
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha3_256, &1))
    |> Base.encode16(case: :lower)
  end

  # Canonicalize data structures for deterministic hashing
  # Converts maps to sorted lists of {string_key, value} tuples
  defp canonicalize(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {to_string(k), canonicalize(v)} end)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  defp canonicalize(list) when is_list(list) do
    Enum.map(list, &canonicalize/1)
  end

  defp canonicalize(other), do: other
end
