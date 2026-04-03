defmodule Indrajaal.Alarms.TimescaleDBSchema do
  @moduledoc """

  Timescale DB schema and hypertable management for alarm event time-series data.

  This module provides comprehensive Timescale DB architecture for:
  - Real
  - time alarm event logging
  - High
  - performance time-series queries
  - Automatic data retention and compression
  - Partition-based performance optimization-Alarm lifecycle event tracking

  SOPv5.1Compliance: ✅ Cybernetic goal-oriented execution
  Agent: Helper-1 (Alarm Processing Coordination Agent)
  Framework: Container-Only + Git-based + Maximum Parallelization
  """

  use GenServer
  require Logger

  # Hypertable configuration constants
  @hypertables %{
    alarm_events_ts: %{
      table_name: "alarm_events_timescale",
      time_column: :triggered_at,
      space_column: :site_id,
      chunk_time_interval: "1 day",
      compression_after: "7 days",
      retention_policy: "90 days"
    },
    alarm_state_changes: %{
      table_name: "alarm_state_changes",
      time_column: :changed_at,
      space_column: :site_id,
      chunk_time_interval: "6 hours",
      compression_after: "3 days",
      retention_policy: "30 days"
    },
    alarm_escalations: %{
      table_name: "alarm_escalations",
      time_column: :escalated_at,
      space_column: :site_id,
      chunk_time_interval: "12 hours",
      compression_after: "7 days",
      retention_policy: "180 days"
    },
    security_incidents: %{
      table_name: "security_incidents",
      time_column: :incident_at,
      space_column: :tenant_id,
      chunk_time_interval: "2 hours",
      compression_after: "1 day",
      retention_policy: "365 days"
    },
    alarm_analytics: %{
      table_name: "alarm_analytics_hourly",
      time_column: :hour_bucket,
      space_column: :site_id,
      chunk_time_interval: "1 day",
      compression_after: "30 days",
      retention_policy: "2 years"
    }
  }

  @spec start_link(keyword() | map()) :: term()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    Logger.info("🏭 Starting Timescale DB Schema Manager-SOPv5.1Cybernetic Mode")

    # Validate Timescale DB extension availability
    case validate_timescaledb() do
      :ok ->
        Logger.info("✅ Timescale DB extension validated successfully")
        {:ok, %{status: :ready, hypertables: @hypertables}}

      {:error, reason} ->
        Logger.error("❌ Timescale DB validation failed: #{inspect(reason)}")
        {:ok, %{status: :error, reason: reason}}
    end
  end

  # Public API for hypertable management

  @doc """
  Create all __required hypertables for alarm processing.

  This creates optimized time-series tables with:
  - Proper partitioning strategy
  - Compression policies
  - Retention policies
  - Performance indexes
  """
  @spec create_hypertables :: any()
  def create_hypertables do
    GenServer.call(__MODULE__, :create_hypertables, 30_000)
  end

  @doc """
  Optimize existing hypertables with compression and retention.
  """
  @spec optimize_hypertables :: any()
  def optimize_hypertables do
    GenServer.call(__MODULE__, :optimize_hypertables)
  end

  @doc """
  Get hypertable status and performance metrics.
  """
  @spec get_hypertable_status :: any()
  def get_hypertable_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer implementation

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:createhypertables, _from, state) do
    Logger.info("🚀 Creating Timescale DB hypertables-Maximum Parallelization")

    results =
      @hypertables
      |> Enum.map(&create_single_hypertable/1)
      |> Enum.reduce(%{success: [], errors: []}, fn
        {:ok, _table_name} = result, acc ->
          %{acc | success: [result | acc.success]}

        {:error, _table_name, _reason} = error, acc ->
          %{acc | errors: [error | acc.errors]}
      end)

    response = %{
      created: length(results.success),
      failed: length(results.errors),
      details: results
    }

    {:reply, response, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:optimizehypertables, _from, state) do
    Logger.info("⚡ Optimizing Timescale DB hypertables")

    optimization_results =
      @hypertables
      |> Enum.map(&optimize_single_hypertable/1)
      |> Map.new()

    {:reply, optimization_results, state}
  end

  @impl true
  @spec handle_call(term(), term(), term()) :: term()
  def handle_call(:getstatus, _from, state) do
    status = get_comprehensive_status()
    {:reply, status, state}
  end

  # Private implementation functions

  defp validate_timescaledb do
    sql = "SELECT extname FROM pg_extension WHERE extname = 'timescaledb'"

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, %{rows: [["timescaledb"]]}} ->
        :ok

      {:ok, %{rows: []}} ->
        {:error, :timescaledb_not_installed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_single_hypertable({hypertable_key, config}) do
    table_name = config[:table_name]
    Logger.info("📊 Creating hypertable: #{table_name}")

    try do
      # Create base table first
      :ok = create_base_table(hypertable_key, config)

      # Convert to hypertable
      :ok = convert_to_hypertable(config)

      # Add compression policy
      :ok = add_compression_policy(config)

      # Add retention policy
      :ok = add_retention_policy(config)

      # Create optimized indexes
      :ok = create_performance_indexes(hypertable_key, config)

      Logger.info("✅ Successfully created hypertable: #{table_name}")
      {:ok, table_name}
    rescue
      exception ->
        Logger.error("❌ Failed to create hypertable #{table_name}: #{inspect(exception)}")
        {:error, table_name, exception}
    end
  end

  defp create_base_table(:alarm_events_ts, config) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{config[:table_name]} (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      site_id UUID NOT NULL,
      alarm_id UUID NOT NULL,

      -- Event identification
      event_code VARCHAR(20) NOT NULL,
      event_type VARCHAR(50) NOT NULL,
      severity VARCHAR(20) NOT NULL,
      priority INTEGER NOT NULL,
      state VARCHAR(20) NOT NULL,

      -- Location information
      zone_id UUID,
      device_id UUID,
      location_details TEXT,

      -- Event details
      description TEXT NOT NULL,
      sia_code VARCHAR(10),
      account_number VARCHAR(16),
      raw_data JSONB,

      -- Timing information (critical for time-series)
      triggered_at TIMESTAMPTZ NOT NULL,
      acknowledged_at TIMESTAMPTZ,
      investigating_at TIMESTAMPTZ,
      resolved_at TIMESTAMPTZ,

      -- Response metrics
      response_time_seconds INTEGER,
      resolution_time_seconds INTEGER,

      -- Verification and processing
      verified BOOLEAN DEFAULT FALSE,
      verification_method VARCHAR(50),
      auto_acknowledged BOOLEAN DEFAULT FALSE,

      -- Correlation data
      parent_event_id UUID,
      correlated_events UUID[],
      correlation_group_id UUID,
      correlation_data JSONB,

      -- Metadata
      severity_factors JSONB,
      metadata JSONB,
      evidence_data JSONB,
      storm_suppressed BOOLEAN DEFAULT FALSE,

      -- Audit fields
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "Failed to create base table: #{inspect(reason)}"
    end
  end

  defp create_base_table(:alarm_state_changes, config) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{config[:table_name]} (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      site_id UUID NOT NULL,
      alarm_id UUID NOT NULL,

      -- State change information
      previous_state VARCHAR(20),
      new_state VARCHAR(20) NOT NULL,
      changed_by UUID,
      change_reason TEXT,

      -- Timing
      changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

      -- Metadata
      change_metadata JSONB,

      -- Audit
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "Failed to create alarm state changes table: #{inspect(reason)}"
    end
  end

  defp create_base_table(:alarmescalations, config) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{config[:table_name]} (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      site_id UUID NOT NULL,
      alarm_id UUID NOT NULL,

      -- Escalation information
      escalation_level INTEGER NOT NULL,
      escalation_reason TEXT,
      escalated_by UUID,
      escalated_to UUID,

      -- Escalation rules and automation
      escalation_rule_id UUID,
      auto_escalated BOOLEAN DEFAULT FALSE,
      escalation_data JSONB,

      -- Timing
      escalated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

      -- Response tracking
      acknowledged_at TIMESTAMPTZ,
      response_time_seconds INTEGER,

      -- Audit
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "Failed to create escalations table: #{inspect(reason)}"
    end
  end

  defp create_base_table(:security_incidents, config) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{config[:table_name]} (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      site_id UUID,

      -- Incident classification
      incident_type VARCHAR(100) NOT NULL,
      severity_level VARCHAR(20) NOT NULL,
      threat_level VARCHAR(20),
      confidence_score DECIMAL(3,2),

      -- Incident details
      title VARCHAR(500) NOT NULL,
      description TEXT,
      affected_systems TEXT[],
      attack_vectors TEXT[],

      -- Intelligence correlation
      threat_indicators JSONB,
      ioc_data JSONB,  -- Indicators of Compromise
      mitre_techniques TEXT[],  -- MITRE ATT&CK framework

      -- Related alarms and events
      related_alarm_events UUID[],
      related_incidents UUID[],
      correlation_score DECIMAL(3,2),

      -- Response and investigation
      assigned_to UUID,
      response_status VARCHAR(50),
      investigation_notes TEXT,

      -- Timing
      incident_at TIMESTAMPTZ NOT NULL,
      detected_at TIMESTAMPTZ DEFAULT NOW(),
      contained_at TIMESTAMPTZ,
      resolved_at TIMESTAMPTZ,

      -- Metadata
      incident_metadata JSONB,
      evidence_links TEXT[],

      -- Audit
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "Failed to create security incidents table: #{inspect(reason)}"
    end
  end

  defp create_base_table(:alarmanalytics, config) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{config[:table_name]} (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant_id UUID NOT NULL,
      site_id UUID NOT NULL,

      -- Time bucket for aggregation
      hour_bucket TIMESTAMPTZ NOT NULL,

      -- Alarm volume metrics
      total_alarms INTEGER DEFAULT 0,
      critical_alarms INTEGER DEFAULT 0,
      high_alarms INTEGER DEFAULT 0,
      medium_alarms INTEGER DEFAULT 0,
      low_alarms INTEGER DEFAULT 0,

      -- State distribution
      triggered_count INTEGER DEFAULT 0,
      acknowledged_count INTEGER DEFAULT 0,
      investigating_count INTEGER DEFAULT 0,
      resolved_count INTEGER DEFAULT 0,
      false_alarm_count INTEGER DEFAULT 0,

      -- Performance metrics
      avg_response_time_seconds DECIMAL(10,2),
      avg_resolution_time_seconds DECIMAL(10,2),
      sla_compliance_rate DECIMAL(5,2),

      -- Event type breakdown
      intrusion_events INTEGER DEFAULT 0,
      fire_events INTEGER DEFAULT 0,
      medical_events INTEGER DEFAULT 0,
      panic_events INTEGER DEFAULT 0,
      tamper_events INTEGER DEFAULT 0,
      other_events INTEGER DEFAULT 0,

      -- Quality metrics
      verification_rate DECIMAL(5,2),
      false_positive_rate DECIMAL(5,2),
      auto_resolution_rate DECIMAL(5,2),

      -- Metadata
      analytics_metadata JSONB,

      -- Audit
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "Failed to create analytics table: #{inspect(reason)}"
    end
  end

  defp convert_to_hypertable(config) do
    # Create hypertable with time and space partitioning
    space_partition =
      if config[:space_column] do
        ", partitioning_column => '#{config[:space_column]}'"
      else
        ""
      end

    sql = """
    SELECT create_hypertable(
      '#{config[:table_name]}',
      '#{config[:time_column]}',
      chunk_time_interval => INTERVAL '#{config[:chunk_time_interval]}'
      #{space_partition}
    );
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} ->
        :ok

      {:error, %{postgres: %{code: :duplicate_object}}} ->
        # Hypertable already exists
        :ok

      {:error, reason} ->
        raise "Failed to create hypertable: #{inspect(reason)}"
    end
  end

  defp add_compression_policy(config) do
    sql = """
    SELECT add_compression_policy('#{config[:table_name]}', INTERVAL '#{config[:compression_after]}');
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} ->
        :ok

      {:error, %{postgres: %{code: :duplicate_object}}} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to add compression policy for #{config[:table_name]}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp add_retention_policy(config) do
    sql = """
    SELECT add_retention_policy('#{config[:table_name]}', INTERVAL '#{config[:retention_policy]}');
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, _} ->
        :ok

      {:error, %{postgres: %{code: :duplicate_object}}} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to add retention policy for #{config[:table_name]}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp create_performance_indexes(:alarm_events_ts, config) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_tenant_site ON #{config[:table_name]} (tenant_id, site_id, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}__state_priority ON #{config[:table_name]} (state, priority, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_event_type_severity ON #{config[:table_name]} (event_type, severity, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_device_time ON #{config[:table_name]} (device_id, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_correlation ON #{config[:table_name]} (correlation_group_id) WHERE correlation_group_id IS NOT NULL",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_verification ON #{config[:table_name]} (verified, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_response_metrics ON #{config[:table_name]} (response_time_seconds, acknowledgment_time_seconds)"
    ]

    create_indexes(indexes)
  end

  defp create_performance_indexes(:alarm_state_changes, config) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_alarm_time ON #{config[:table_name]} (alarm_id, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}__state_transition ON #{config[:table_name]} (previous_state, new_state, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_changed_by ON #{config[:table_name]} (changed_by, created_at DESC)"
    ]

    create_indexes(indexes)
  end

  defp create_performance_indexes(:alarm_escalations, config) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_alarm_level ON #{config[:table_name]} (alarm_id, escalation_level, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_escalated_to ON #{config[:table_name]} (escalated_to, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_auto_escalation ON #{config[:table_name]} (auto_escalated, created_at DESC)"
    ]

    create_indexes(indexes)
  end

  defp create_performance_indexes(:security_incidents, config) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_incident_type ON #{config[:table_name]} (incident_type, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_threat_level ON #{config[:table_name]} (threat_level, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_response_status ON #{config[:table_name]} (response_status, created_at DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_mitre_techniques ON #{config[:table_name]} USING GIN (mitre_techniques)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_related_alarms ON #{config[:table_name]} USING GIN (related_alarm_events)"
    ]

    create_indexes(indexes)
  end

  defp create_performance_indexes(:alarm_analytics, config) do
    indexes = [
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_bucket_site ON #{config[:table_name]} (hour_bucket DESC, site_id)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_tenant_bucket ON #{config[:table_name]} (tenant_id, hour_bucket DESC)",
      "CREATE INDEX IF NOT EXISTS idx_#{config[:table_name]}_sla_compliance ON #{config[:table_name]} (sla_compliance_rate, hour_bucket DESC)"
    ]

    create_indexes(indexes)
  end

  defp create_indexes(index_sqls) do
    Enum.each(index_sqls, fn sql ->
      case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Failed to create index: #{inspect(reason)}")
      end
    end)

    :ok
  end

  defp optimize_single_hypertable({hypertable_key, config}) do
    table_name = config.table_name

    optimizations = %{
      compression_status: check_compression_status(table_name),
      retention_status: check_retention_status(table_name),
      chunk_statistics: get_chunk_statistics(table_name),
      index_usage: analyze_index_usage(table_name)
    }

    {hypertable_key, optimizations}
  end

  defp check_compression_status(table_name) do
    sql = """
    SELECT
      chunk_schema,
      chunk_name,
      compression_status
    FROM timescaledb_information.chunks
    WHERE hypertable_name = $1
    LIMIT 5
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql, [table_name]) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp check_retention_status(table_name) do
    sql = """
    SELECT
      job_id,
      application_name,
      schedule_interval,
      config
    FROM timescaledb_information.jobs
    WHERE application_name LIKE '%retention%'
    AND config::text LIKE '%#{table_name}%'
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp get_chunk_statistics(table_name) do
    sql = """
    SELECT
      chunk_name,
      range_start,
      range_end,
      pg_size_pretty(pg_total_relation_size(chunk_schema||'.'||chunk_name)) as size
    FROM timescaledb_information.chunks
    WHERE hypertable_name = $1
    ORDER BY range_start DESC
    LIMIT 10
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql, [table_name]) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp analyze_index_usage(table_name) do
    sql = """
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_scan as scans,
      idx_tup_read as tuples_read,
      idx_tup_fetch as tuples_fetched
    FROM pg_stat_user_indexes
    WHERE tablename = $1
    ORDER BY idx_scan DESC
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql, [table_name]) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp get_comprehensive_status do
    %{
      timescaledb_version: get_timescaledb_version(),
      hypertables: get_hypertables_info(),
      compression_jobs: get_compression_jobs(),
      retention_jobs: get_retention_jobs(),
      chunk_statistics: get_overall_chunk_stats(),
      performance_metrics: get_performance_metrics()
    }
  end

  defp get_timescaledb_version do
    sql = "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'"

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, %{rows: [[version]]}} -> version
      _ -> "unknown"
    end
  end

  defp get_hypertables_info do
    sql = """
    SELECT
      hypertable_name,
      num_dimensions,
      num_chunks,
      compression_enabled,
      pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as size
    FROM timescaledb_information.hypertables
    WHERE hypertable_name IN ('alarm_events_timescale',
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp get_compression_jobs do
    sql = """
    SELECT
      job_id,
      application_name,
      schedule_interval,
      last_run_status
    FROM timescaledb_information.jobs
    WHERE application_name = 'Compression Policy'
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp get_retention_jobs do
    sql = """
    SELECT
      job_id,
      application_name,
      schedule_interval,
      last_run_status
    FROM timescaledb_information.jobs
    WHERE application_name = 'Retention Policy'
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, result} -> result.rows
      {:error, _} -> []
    end
  end

  defp get_overall_chunk_stats do
    sql = """
    SELECT
      COUNT(*) as total_chunks,
      COUNT(*) FILTER (WHERE compression_status = 'Compressed') as compressed_chunks,
      pg_size_pretty(SUM(pg_total_relation_size(chunk_schema||'.'||chunk_name))) as total_size
    FROM timescaledb_information.chunks
    WHERE hypertable_name IN ('alarm_events_timescale',
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, %{rows: [[total, compressed, size]]}} ->
        %{total: total, compressed: compressed, size: size}

      {:error, _} ->
        %{total: 0, compressed: 0, size: "0 bytes"}
    end
  end

  defp get_performance_metrics do
    %{
      avg_query_time: get_avg_query_time(),
      cache_hit_ratio: get_cache_hit_ratio(),
      index_usage_ratio: get_index_usage_ratio()
    }
  end

  defp get_avg_query_time do
    sql = """
    SELECT
      ROUND(mean_exec_time::numeric, 2) as avg_time_ms
    FROM pg_stat_statements
    WHERE query LIKE '%alarm_events_timescale%'
    ORDER BY mean_exec_time DESC
    LIMIT 1
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, %{rows: [[avg_time]]}} -> avg_time
      {:error, _} -> "N / A"
    end
  end

  defp get_cache_hit_ratio do
    sql = """
    SELECT
      ROUND(
        100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2
      ) as cache_hit_ratio
    FROM pg_stat_database
    WHERE datname = current_database()
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, %{rows: [[ratio]]}} -> ratio
      {:error, _} -> "N / A"
    end
  end

  defp get_index_usage_ratio do
    sql = """
    SELECT
      ROUND(
        100.0 * sum(idx_blks_hit) / (sum(idx_blks_hit) + sum(idx_blks_read)), 2
      ) as index_hit_ratio
    FROM pg_statio_user_indexes
    """

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, sql) do
      {:ok, %{rows: [[ratio]]}} -> ratio
      {:error, _} -> "N / A"
    end
  end

  # Public API for logging alarm events to Timescale DB

  @doc """
  Log alarm event to Timescale DB for time-series analysis.
  """
  @spec log_alarm_event(term()) :: term()
  def log_alarm_event(alarm_event) do
    insert_sql = """
    INSERT INTO alarm_events_timescale (
      tenant_id, site_id, alarm_id, event_code, event_type,
      severity, priority, state, zone_id, device_id, location_details,
      description, sia_code, account_number, raw_data, triggered_at,
      acknowledged_at, investigating_at, resolved_at, response_time_seconds,
      resolution_time_seconds, verified, verification_method, auto_acknowledged,
      parent_event_id, correlated_events, correlation_group_id, correlation_data,
      severity_factors, metadata, evidence_data, storm_suppressed
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
      $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32
    )
    """

    params = [
      alarm_event.tenant_id,
      alarm_event.site_id,
      alarm_event.id,
      alarm_event.event_code,
      to_string(alarm_event.event_type),
      to_string(alarm_event.severity),
      alarm_event.priority,
      to_string(alarm_event.state),
      alarm_event.zone_id,
      alarm_event.device_id,
      alarm_event.location_details,
      alarm_event.description,
      alarm_event.sia_code,
      alarm_event.account_number,
      alarm_event.raw_data,
      alarm_event.triggered_at,
      alarm_event.acknowledged_at,
      alarm_event.investigating_at,
      alarm_event.resolved_at,
      alarm_event.response_time_seconds,
      alarm_event.resolution_time_seconds,
      alarm_event.verified?,
      alarm_event.verification_method && to_string(alarm_event.verification_method),
      alarm_event.auto_acknowledged?,
      alarm_event.parent_event_id,
      alarm_event.correlated_events,
      alarm_event.correlation_group_id,
      alarm_event.correlation_data,
      alarm_event.severity_factors,
      alarm_event.metadata,
      alarm_event.evidence_data,
      alarm_event.storm_suppressed
    ]

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, insert_sql, params) do
      {:ok, _} ->
        Logger.debug("✅ Alarm event logged to Timescale DB: #{alarm_event.id}")
        :ok

      {:error, reason} ->
        Logger.error("❌ Failed to log alarm event to Timescale DB: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Log alarm state change to Timescale DB.
  """
  @spec log_state_change(binary() | integer(), term(), term(), term(), keyword() | map()) ::
          term()
  def log_state_change(alarm_id, previous_state, new_state, changed_by, opts \\ []) do
    insert_sql = """
    INSERT INTO alarm_state_changes (
      tenant_id, site_id, alarm_id, previous_state, new_state,
      changed_by, change_reason, changed_at, change_metadata
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    """

    params = [
      opts[:tenant_id],
      opts[:site_id],
      alarm_id,
      previous_state && to_string(previous_state),
      to_string(new_state),
      changed_by,
      opts[:reason],
      opts[:changed_at] || DateTime.utc_now(),
      opts[:metadata] || %{}
    ]

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, insert_sql, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Log alarm escalation to Timescale DB.
  """
  @spec log_escalation(binary() | integer(), term()) :: term()
  def log_escalation(alarm_id, escalation_data) do
    insert_sql = """
    INSERT INTO alarm_escalations (
      tenant_id, site_id, alarm_id, escalation_level, escalation_reason,
      escalated_by, escalated_to, escalation_rule_id, auto_escalated,
      escalation_data, escalated_at, acknowledged_at, response_time_seconds
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
    """

    params = [
      escalation_data[:tenant_id],
      escalation_data[:site_id],
      alarm_id,
      escalation_data[:level],
      escalation_data[:reason],
      escalation_data[:escalated_by],
      escalation_data[:escalated_to],
      escalation_data[:rule_id],
      escalation_data[:auto_escalated] || false,
      escalation_data[:metadata] || %{},
      escalation_data[:escalated_at] || DateTime.utc_now(),
      escalation_data[:acknowledged_at],
      escalation_data[:response_time]
    ]

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, insert_sql, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create or update security incident record.
  """
  @spec log_security_incident(binary() | integer()) :: term()
  def log_security_incident(incident_data) do
    insert_sql = """
    INSERT INTO security_incidents (
      tenant_id, site_id, incident_type, severity_level, threat_level,
      confidence_score, title, description, affected_systems, attack_vectors,
      threat_indicators, ioc_data, mitre_techniques, related_alarm_events,
      related_incidents, correlation_score, assigned_to, response_status,
      investigation_notes, incident_at, detected_at, contained_at, resolved_at,
      incident_metadata, evidence_links
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
      $17, $18, $19, $20, $21, $22, $23, $24, $25
    )
    """

    params = [
      incident_data[:tenant_id],
      incident_data[:site_id],
      incident_data[:incident_type],
      incident_data[:severity_level],
      incident_data[:threat_level],
      incident_data[:confidence_score],
      incident_data[:title],
      incident_data[:description],
      incident_data[:affected_systems],
      incident_data[:attack_vectors],
      incident_data[:threat_indicators] || %{},
      incident_data[:ioc_data] || %{},
      incident_data[:mitre_techniques] || [],
      incident_data[:related_alarm_events] || [],
      incident_data[:related_incidents] || [],
      incident_data[:correlation_score],
      incident_data[:assigned_to],
      incident_data[:response_status] || "open",
      incident_data[:investigation_notes],
      incident_data[:incident_at] || DateTime.utc_now(),
      DateTime.utc_now(),
      incident_data[:contained_at],
      incident_data[:resolved_at],
      incident_data[:metadata] || %{},
      incident_data[:evidence_links] || []
    ]

    case Ecto.Adapters.SQL.query(Indrajaal.Repo, insert_sql, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Telemetry and monitoring (removed unused function)
end

# Agent: Helper-1 (Alarm Processing Coordination Agent)
# SOPv5.1Compliance: ✅ Cybernetic goal - oriented execution with systematic optimization
# Framework: Container-Only + Git - based + Maximum Parallelization + TDG Methodology
# Domain: Alarms Timescale DB Architecture
# Responsibilities: Time - series data management, hypertable optimization, real-time logging
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Continuous performance optimization and schema validation
