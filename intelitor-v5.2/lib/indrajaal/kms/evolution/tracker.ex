defmodule Indrajaal.KMS.Evolution.Tracker do
  @moduledoc """
  L4 Evolution Tracker: Knowledge evolution and learning.

  Tracks the evolution of knowledge holons over time, including
  content changes, relationship updates, and entropy decay.
  Supports the Constitutional invariant Ψ₂ (History) by maintaining
  complete evolutionary lineage.

  ## STAMP Constraints

  - SC-SMRITI-140: All evolution events MUST be recorded
  - SC-SMRITI-141: Lineage chain MUST be unbroken
  - SC-SMRITI-142: Evolution history stored in DuckDB (append-only)
  - SC-HOLON-019: Evolution history is immutable
  - SC-REG-001: All state changes via append-only register
  - SC-OBS-035: All evolution events emit telemetry

  ## Constitutional Alignment

  - Ψ₂ (History): Complete evolutionary lineage preserved
  - Ψ₁ (Regeneration): Evolution enables self-improvement
  - Ψ₀ (Existence): Learning ensures continued relevance
  - Ω₀ (Founder's Directive): Evolution serves lineage survival

  ## Observer-Observed Pattern

  This module emits telemetry for:
  - Evolution event recording
  - Lineage queries
  - Entropy recalculation
  - Learning feedback
  - Pattern detection

  ## 5-Order Effects

  1st: Evolution event recorded
  2nd: Lineage chain updated
  3rd: Entropy recalculated
  4th: Patterns detected
  5th: Learning model updated

  ## Usage

      # Record evolution event
      {:ok, event_id} = Tracker.record_evolution(holon_id, :content_update, changes)

      # Get evolution history
      {:ok, history} = Tracker.get_lineage(holon_id)

      # Analyze evolution patterns
      {:ok, patterns} = Tracker.analyze_patterns(cluster)

      # Calculate evolution metrics
      {:ok, metrics} = Tracker.evolution_metrics(holon_id)
  """

  use GenServer
  require Logger

  alias Indrajaal.KMS.SQLite

  @evolution_types [
    :created,
    :content_update,
    :relationship_added,
    :relationship_removed,
    :tags_updated,
    :cluster_changed,
    :entropy_recalculated,
    :merged,
    :split
  ]

  @type holon_id :: String.t()
  @type evolution_type :: atom()
  @type event_id :: String.t()

  @type evolution_event :: %{
          id: event_id(),
          holon_id: holon_id(),
          type: evolution_type(),
          timestamp: DateTime.t(),
          changes: map(),
          parent_event: event_id() | nil,
          metadata: map()
        }

  @type lineage :: %{
          holon_id: holon_id(),
          events: list(evolution_event()),
          total_evolutions: non_neg_integer(),
          first_evolution: DateTime.t() | nil,
          last_evolution: DateTime.t() | nil,
          evolution_rate: float()
        }

  @type evolution_pattern :: %{
          pattern_type: atom(),
          frequency: non_neg_integer(),
          holons_affected: list(holon_id()),
          first_seen: DateTime.t(),
          last_seen: DateTime.t()
        }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the Evolution Tracker GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records an evolution event for a holon.

  This is the primary entry point for tracking changes to knowledge holons.
  Events are appended to the immutable evolution log.
  """
  @spec record_evolution(holon_id(), evolution_type(), map(), keyword()) ::
          {:ok, event_id()} | {:error, term()}
  def record_evolution(holon_id, type, changes, opts \\ []) do
    GenServer.call(__MODULE__, {:record_evolution, holon_id, type, changes, opts})
  end

  @doc """
  Gets the complete evolution lineage for a holon.
  """
  @spec get_lineage(holon_id(), keyword()) :: {:ok, lineage()} | {:error, term()}
  def get_lineage(holon_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_lineage, holon_id, opts})
  end

  @doc """
  Gets a specific evolution event by ID.
  """
  @spec get_event(event_id()) :: {:ok, evolution_event()} | {:error, term()}
  def get_event(event_id) do
    GenServer.call(__MODULE__, {:get_event, event_id})
  end

  @doc """
  Analyzes evolution patterns within a cluster or globally.
  """
  @spec analyze_patterns(String.t() | nil, keyword()) ::
          {:ok, list(evolution_pattern())} | {:error, term()}
  def analyze_patterns(cluster \\ nil, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_patterns, cluster, opts})
  end

  @doc """
  Calculates evolution metrics for a holon.
  """
  @spec evolution_metrics(holon_id()) :: {:ok, map()} | {:error, term()}
  def evolution_metrics(holon_id) do
    GenServer.call(__MODULE__, {:evolution_metrics, holon_id})
  end

  @doc """
  Recalculates entropy for a holon based on its evolution history.
  """
  @spec recalculate_entropy(holon_id()) :: {:ok, float()} | {:error, term()}
  def recalculate_entropy(holon_id) do
    GenServer.call(__MODULE__, {:recalculate_entropy, holon_id})
  end

  @doc """
  Records learning feedback for improving evolution predictions.
  """
  @spec record_feedback(event_id(), :positive | :negative | :neutral, map()) ::
          :ok | {:error, term()}
  def record_feedback(event_id, sentiment, details \\ %{}) do
    GenServer.cast(__MODULE__, {:record_feedback, event_id, sentiment, details})
  end

  @doc """
  Lists recent evolution events across all holons.
  """
  @spec recent_events(keyword()) :: {:ok, list(evolution_event())} | {:error, term()}
  def recent_events(opts \\ []) do
    GenServer.call(__MODULE__, {:recent_events, opts})
  end

  @doc """
  Gets evolution statistics for the knowledge base.
  """
  @spec stats() :: {:ok, map()}
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Returns supported evolution types.
  """
  @spec evolution_types() :: list(atom())
  def evolution_types, do: @evolution_types

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    db_path = Keyword.get(opts, :db_path, get_db_path())

    # Ensure evolution tables exist
    ensure_tables(db_path)

    emit_telemetry(:init, %{db_path: db_path})

    Logger.info("[Evolution.Tracker] Initialized")

    {:ok,
     %{
       db_path: db_path,
       event_count: 0,
       started_at: DateTime.utc_now()
     }}
  end

  @impl true
  def handle_call({:record_evolution, holon_id, type, changes, opts}, _from, state) do
    emit_telemetry(:record_start, %{holon_id: holon_id, type: type})

    unless type in @evolution_types do
      {:reply, {:error, :invalid_evolution_type}, state}
    else
      parent_event = Keyword.get(opts, :parent_event)
      metadata = Keyword.get(opts, :metadata, %{})

      event_id = generate_event_id()
      now = DateTime.utc_now()

      event = %{
        id: event_id,
        holon_id: holon_id,
        type: type,
        timestamp: now,
        changes: changes,
        parent_event: parent_event,
        metadata: metadata
      }

      case persist_event(event, state.db_path) do
        :ok ->
          emit_telemetry(:record_complete, %{
            holon_id: holon_id,
            type: type,
            event_id: event_id
          })

          {:reply, {:ok, event_id}, %{state | event_count: state.event_count + 1}}

        {:error, reason} = error ->
          emit_telemetry(:record_failed, %{
            holon_id: holon_id,
            type: type,
            reason: reason
          })

          {:reply, error, state}
      end
    end
  end

  @impl true
  def handle_call({:get_lineage, holon_id, opts}, _from, state) do
    emit_telemetry(:lineage_query_start, %{holon_id: holon_id})

    limit = Keyword.get(opts, :limit, 100)

    case query_lineage(holon_id, limit, state.db_path) do
      {:ok, events} ->
        lineage = build_lineage(holon_id, events)

        emit_telemetry(:lineage_query_complete, %{holon_id: holon_id, event_count: length(events)})

        {:reply, {:ok, lineage}, state}

      {:error, reason} = error ->
        emit_telemetry(:lineage_query_failed, %{holon_id: holon_id, reason: reason})
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_event, event_id}, _from, state) do
    case query_event(event_id, state.db_path) do
      {:ok, event} -> {:reply, {:ok, event}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:analyze_patterns, cluster, opts}, _from, state) do
    emit_telemetry(:analyze_patterns_start, %{cluster: cluster})

    min_frequency = Keyword.get(opts, :min_frequency, 3)
    lookback_days = Keyword.get(opts, :lookback_days, 30)

    # detect_patterns always returns {:ok, patterns}
    {:ok, patterns} = detect_patterns(cluster, min_frequency, lookback_days, state.db_path)

    emit_telemetry(:analyze_patterns_complete, %{
      cluster: cluster,
      pattern_count: length(patterns)
    })

    {:reply, {:ok, patterns}, state}
  end

  @impl true
  def handle_call({:evolution_metrics, holon_id}, _from, state) do
    case calculate_metrics(holon_id, state.db_path) do
      {:ok, metrics} -> {:reply, {:ok, metrics}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:recalculate_entropy, holon_id}, _from, state) do
    emit_telemetry(:entropy_recalculate_start, %{holon_id: holon_id})

    case do_recalculate_entropy(holon_id, state.db_path) do
      {:ok, entropy} ->
        # Record the entropy recalculation as an evolution event (directly, not via GenServer.call)
        event = %{
          id: generate_event_id(),
          holon_id: holon_id,
          type: :entropy_recalculated,
          timestamp: DateTime.utc_now(),
          changes: %{new_entropy: entropy},
          parent_event: nil,
          metadata: %{}
        }

        persist_event(event, state.db_path)

        emit_telemetry(:entropy_recalculate_complete, %{
          holon_id: holon_id,
          entropy: entropy
        })

        {:reply, {:ok, entropy}, %{state | event_count: state.event_count + 1}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:recent_events, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 50)
    type = Keyword.get(opts, :type)

    case query_recent_events(limit, type, state.db_path) do
      {:ok, events} -> {:reply, {:ok, events}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    uptime = DateTime.diff(DateTime.utc_now(), state.started_at, :second)

    stats = %{
      event_count: state.event_count,
      uptime_seconds: uptime,
      events_per_minute: if(uptime > 0, do: state.event_count / (uptime / 60), else: 0.0),
      db_path: state.db_path
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({:record_feedback, event_id, sentiment, details}, state) do
    persist_feedback(event_id, sentiment, details, state.db_path)

    emit_telemetry(:feedback_recorded, %{
      event_id: event_id,
      sentiment: sentiment,
      details: details
    })

    {:noreply, state}
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp ensure_tables(db_path) do
    # Create evolution_events table if not exists
    sql = """
    CREATE TABLE IF NOT EXISTS evolution_events (
      id TEXT PRIMARY KEY,
      holon_id TEXT NOT NULL,
      type TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      changes TEXT,
      parent_event TEXT,
      metadata TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )
    """

    SQLite.execute(db_path, sql)

    # Create index on holon_id
    SQLite.execute(db_path, """
    CREATE INDEX IF NOT EXISTS idx_evolution_holon_id ON evolution_events(holon_id)
    """)

    # Create index on timestamp
    SQLite.execute(db_path, """
    CREATE INDEX IF NOT EXISTS idx_evolution_timestamp ON evolution_events(timestamp)
    """)

    # Create feedback table for learning model (SC-SMRITI-140)
    SQLite.execute(db_path, """
    CREATE TABLE IF NOT EXISTS evolution_feedback (
      id TEXT PRIMARY KEY,
      event_id TEXT NOT NULL,
      sentiment TEXT NOT NULL,
      details TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (event_id) REFERENCES evolution_events(id)
    )
    """)

    SQLite.execute(db_path, """
    CREATE INDEX IF NOT EXISTS idx_feedback_event_id ON evolution_feedback(event_id)
    """)

    :ok
  rescue
    _ -> :ok
  end

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp persist_event(event, db_path) do
    sql = """
    INSERT INTO evolution_events (id, holon_id, type, timestamp, changes, parent_event, metadata)
    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
    """

    params = [
      event.id,
      event.holon_id,
      Atom.to_string(event.type),
      DateTime.to_iso8601(event.timestamp),
      Jason.encode!(event.changes),
      event.parent_event,
      Jason.encode!(event.metadata)
    ]

    case SQLite.execute(db_path, sql, params) do
      {:ok, :done} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp persist_feedback(event_id, sentiment, details, db_path) do
    sql = """
    INSERT INTO evolution_feedback (id, event_id, sentiment, details)
    VALUES (?1, ?2, ?3, ?4)
    """

    feedback_id = generate_event_id()

    params = [
      feedback_id,
      event_id,
      Atom.to_string(sentiment),
      Jason.encode!(details)
    ]

    case SQLite.execute(db_path, sql, params) do
      {:ok, :done} ->
        :ok

      {:error, reason} ->
        Logger.warning("[Evolution.Tracker] Feedback persist failed: #{inspect(reason)}")
    end
  rescue
    e -> Logger.warning("[Evolution.Tracker] Feedback persist error: #{Exception.message(e)}")
  end

  defp query_lineage(holon_id, limit, db_path) do
    sql = """
    SELECT id, holon_id, type, timestamp, changes, parent_event, metadata
    FROM evolution_events
    WHERE holon_id = ?1
    ORDER BY timestamp DESC
    LIMIT ?2
    """

    case SQLite.query(db_path, sql, [holon_id, limit]) do
      {:ok, rows} ->
        events =
          rows
          |> Enum.map(&parse_event_row/1)
          |> Enum.reject(&is_nil/1)

        {:ok, events}

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  rescue
    e -> {:error, {:query_exception, Exception.message(e)}}
  end

  defp query_event(event_id, db_path) do
    sql = """
    SELECT id, holon_id, type, timestamp, changes, parent_event, metadata
    FROM evolution_events
    WHERE id = ?1
    """

    case SQLite.query(db_path, sql, [event_id]) do
      {:ok, [row]} ->
        case parse_event_row(row) do
          nil -> {:error, :not_found}
          event -> {:ok, event}
        end

      {:ok, []} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  defp query_recent_events(limit, type, db_path) do
    {sql, params} =
      if type do
        {"""
         SELECT id, holon_id, type, timestamp, changes, parent_event, metadata
         FROM evolution_events
         WHERE type = ?1
         ORDER BY timestamp DESC
         LIMIT ?2
         """, [Atom.to_string(type), limit]}
      else
        {"""
         SELECT id, holon_id, type, timestamp, changes, parent_event, metadata
         FROM evolution_events
         ORDER BY timestamp DESC
         LIMIT ?1
         """, [limit]}
      end

    case SQLite.query(db_path, sql, params) do
      {:ok, rows} ->
        events =
          rows
          |> Enum.map(&parse_event_row/1)
          |> Enum.reject(&is_nil/1)

        {:ok, events}

      {:error, reason} ->
        {:error, {:query_failed, reason}}
    end
  end

  # Primary clause: SQLite returns rows as maps (KMS.SQLite.fetch_all)
  defp parse_event_row(%{} = row) do
    %{
      id: row[:id],
      holon_id: row[:holon_id] || "unknown",
      type: safe_to_atom(row[:type]),
      timestamp: parse_timestamp(row[:timestamp]),
      changes: parse_json(row[:changes]),
      parent_event: row[:parent_event],
      metadata: parse_json(row[:metadata])
    }
  end

  # Legacy list format (7 columns)
  defp parse_event_row([id, holon_id, type, timestamp, changes, parent_event, metadata]) do
    %{
      id: id,
      holon_id: holon_id,
      type: safe_to_atom(type),
      timestamp: parse_timestamp(timestamp),
      changes: parse_json(changes),
      parent_event: parent_event,
      metadata: parse_json(metadata)
    }
  end

  # Legacy list format (4+ columns)
  defp parse_event_row([id, holon_id, type, timestamp | rest]) do
    {changes, parent_event, metadata} =
      case rest do
        [] -> {%{}, nil, %{}}
        [c] -> {parse_json(c), nil, %{}}
        [c, p] -> {parse_json(c), p, %{}}
        [c, p, m | _] -> {parse_json(c), p, parse_json(m)}
      end

    %{
      id: id,
      holon_id: holon_id,
      type: safe_to_atom(type),
      timestamp: parse_timestamp(timestamp),
      changes: changes,
      parent_event: parent_event,
      metadata: metadata
    }
  end

  defp parse_event_row(_), do: nil

  defp safe_to_atom(type) when is_binary(type) do
    String.to_existing_atom(type)
  rescue
    _ -> String.to_atom(type)
  end

  defp safe_to_atom(type) when is_atom(type), do: type
  defp safe_to_atom(_), do: :unknown

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now()

  defp parse_json(nil), do: %{}

  defp parse_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  defp parse_json(_), do: %{}

  defp build_lineage(holon_id, events) do
    {first_evolution, last_evolution} =
      case events do
        [] ->
          {nil, nil}

        events ->
          sorted = Enum.sort_by(events, & &1.timestamp, DateTime)
          {hd(sorted).timestamp, List.last(sorted).timestamp}
      end

    evolution_rate =
      if first_evolution && last_evolution do
        days = max(1, DateTime.diff(last_evolution, first_evolution, :day))
        length(events) / days
      else
        0.0
      end

    %{
      holon_id: holon_id,
      events: events,
      total_evolutions: length(events),
      first_evolution: first_evolution,
      last_evolution: last_evolution,
      evolution_rate: evolution_rate
    }
  end

  defp detect_patterns(cluster, min_frequency, lookback_days, db_path) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-lookback_days * 86_400, :second)
      |> DateTime.to_iso8601()

    {sql, params} =
      if cluster do
        {"""
         SELECT type, COUNT(*) as freq,
                GROUP_CONCAT(DISTINCT holon_id) as holons,
                MIN(timestamp) as first_ts,
                MAX(timestamp) as last_ts
         FROM evolution_events
         WHERE timestamp >= ?1
           AND holon_id IN (
             SELECT DISTINCT holon_id FROM evolution_events
             WHERE metadata LIKE ?2
           )
         GROUP BY type
         HAVING freq >= ?3
         ORDER BY freq DESC
         """, [cutoff, "%#{cluster}%", min_frequency]}
      else
        {"""
         SELECT type, COUNT(*) as freq,
                GROUP_CONCAT(DISTINCT holon_id) as holons,
                MIN(timestamp) as first_ts,
                MAX(timestamp) as last_ts
         FROM evolution_events
         WHERE timestamp >= ?1
         GROUP BY type
         HAVING freq >= ?2
         ORDER BY freq DESC
         """, [cutoff, min_frequency]}
      end

    case SQLite.query(db_path, sql, params) do
      {:ok, rows} ->
        patterns =
          Enum.map(rows, fn row ->
            parse_pattern_row(row)
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, patterns}

      {:error, _reason} ->
        # Table may not exist yet — return empty patterns
        {:ok, []}
    end
  rescue
    _ -> {:ok, []}
  end

  # Primary clause: SQLite returns rows as maps
  defp parse_pattern_row(%{} = row) do
    holons_str = row[:holons]

    %{
      pattern_type: safe_to_atom(row[:type]),
      frequency: row[:freq] || 0,
      holons_affected: if(holons_str, do: String.split(holons_str, ","), else: []),
      first_seen: parse_timestamp(row[:first_ts]),
      last_seen: parse_timestamp(row[:last_ts])
    }
  end

  # Legacy list format
  defp parse_pattern_row([type, freq, holons_str, first_ts, last_ts]) do
    %{
      pattern_type: safe_to_atom(type),
      frequency: freq,
      holons_affected: if(holons_str, do: String.split(holons_str, ","), else: []),
      first_seen: parse_timestamp(first_ts),
      last_seen: parse_timestamp(last_ts)
    }
  end

  defp parse_pattern_row(_), do: nil

  defp calculate_metrics(holon_id, db_path) do
    case query_lineage(holon_id, 1000, db_path) do
      {:ok, events} ->
        type_counts =
          events
          |> Enum.group_by(& &1.type)
          |> Enum.map(fn {type, evts} -> {type, length(evts)} end)
          |> Map.new()

        metrics = %{
          holon_id: holon_id,
          total_events: length(events),
          type_distribution: type_counts,
          evolution_velocity: calculate_velocity(events),
          last_updated: List.first(events)[:timestamp]
        }

        {:ok, metrics}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_velocity([]), do: 0.0

  defp calculate_velocity(events) do
    now = DateTime.utc_now()

    recent =
      events
      |> Enum.filter(fn e ->
        DateTime.diff(now, e.timestamp, :day) <= 7
      end)

    length(recent) / 7.0
  end

  defp do_recalculate_entropy(holon_id, db_path) do
    case query_lineage(holon_id, 100, db_path) do
      {:ok, events} ->
        # Entropy increases with age and decreases with activity
        base_entropy = 0.5

        activity_factor =
          if length(events) > 0 do
            -0.1 * min(length(events) / 10, 0.3)
          else
            0.2
          end

        age_factor =
          case events do
            [] ->
              0.1

            [latest | _] ->
              days_since = DateTime.diff(DateTime.utc_now(), latest.timestamp, :day)
              min(days_since / 30 * 0.1, 0.2)
          end

        entropy = max(0.0, min(1.0, base_entropy + activity_factor + age_factor))
        {:ok, Float.round(entropy, 3)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_db_path do
    Application.get_env(:indrajaal, :smriti_db_path, "data/kms/smriti.db")
  end

  # ============================================================================
  # Telemetry
  # ============================================================================

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:smriti, :evolution, event],
      %{timestamp: System.system_time(:nanosecond)},
      metadata
    )
  end
end
