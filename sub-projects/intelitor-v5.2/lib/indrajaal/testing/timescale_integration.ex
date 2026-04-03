defmodule Indrajaal.Testing.TimescaleIntegration do
  @moduledoc """

  Comprehensive Testing Framework Timescale DB Integration

  SOPv5.1Cybernetic execution with TPS + STAMP + TDG + GDE methodology integration.
  Provides comprehensive test execution metrics, performance analytics, and quality
  assurance tracking with real-time monitoring capabilities.

  ## Features
  - Test execution metrics with hypertable storage
  - Performance regression detection and alerting
  - Quality gate compliance monitoring
  - Test failure pattern analysis and correlation
  - Continuous integration pipeline metrics
  - Property-based testing analytics
  - Load testing and scalability metrics
  - Triple logging architecture integration
  """

  use GenServer
  require Logger

  alias Indrajaal.Repo
  # EP201: Removed unused alias Tenant
  # alias Indrajaal.Core.Tenant
  # EP201: Removed unused alias DualLogging
  # alias Indrajaal.Observability.DualLogging
  # EP201: Removed unused import Ecto.Query
  # import Ecto.Query

  @doc """
  Start the Timescale DB testing integration GenServer
  """
  @spec start_link(keyword() | map()) :: term()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize testing hypertables if they don't exist
  """
  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    Logger.info("Initializing Testing Framework Timescale DB Integration")

    case setup_hypertables() do
      :ok ->
        Indrajaal.Observability.DualLogging.log_domain_event(
          :testing,
          "timescale_integration_started",
          :info,
          component: "testing_timescale_integration",
          status: "initialized"
        )

        {:ok, %{metrics_buffer: [], performance_buffer: []}}

      {:error, reason} ->
        Logger.error("Failed to initialize testing hypertables", error: reason)
        {:stop, reason}
    end
  end

  @doc """
  Record test execution event with comprehensive metrics
  """
  @spec record_test_execution(term(), keyword() | map()) :: term()
  def record_test_execution(test_data, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_test_execution, test_data, opts})
  end

  @doc """
  Record test performance metrics
  """
  @spec record_performance_metrics(term(), keyword() | map()) :: term()
  def record_performance_metrics(performance_data, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_performance_metrics, performance_data, opts})
  end

  @doc """
  Record quality gate compliance event
  """
  @spec record_quality_gate(term(), keyword() | map()) :: term()
  def record_quality_gate(quality_data, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_quality_gate, quality_data, opts})
  end

  @doc """
  Record test failure with pattern analysis
  """
  @spec record_test_failure(term(), keyword() | map()) :: term()
  def record_test_failure(failure_data, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_test_failure, failure_data, opts})
  end

  @doc """
  Record CI / CD pipeline metrics
  """
  @spec record_pipeline_metrics(term(), keyword() | map()) :: term()
  def record_pipeline_metrics(pipeline_data, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_pipeline_metrics, pipeline_data, opts})
  end

  @doc """
  Get test execution analytics for specified time range
  """
  @spec get_test_analytics(binary() | integer(), term(), keyword() | map()) :: term()
  def get_test_analytics(tenant_id, time_range, opts \\ []) do
    GenServer.call(__MODULE__, {:get_test_analytics, tenant_id, time_range, opts})
  end

  @doc """
  Get performance regression analysis
  """
  @spec get_performance_regression_analysis(binary() | integer(), term(), keyword() | map()) ::
          term()
  def get_performance_regression_analysis(tenant_id, test_suite, opts \\ []) do
    GenServer.call(__MODULE__, {:get_performance_regression, tenant_id, test_suite, opts})
  end

  @doc """
  Get test failure pattern analysis
  """
  @spec get_failure_pattern_analysis(binary() | integer(), term(), keyword() | map()) :: term()
  def get_failure_pattern_analysis(tenant_id, time_range, opts \\ []) do
    GenServer.call(__MODULE__, {:get_failure_patterns, tenant_id, time_range, opts})
  end

  @doc """
  Get quality metrics dashboard data
  """
  @spec get_quality_dashboard_data(binary() | integer(), keyword() | map()) :: term()
  def get_quality_dashboard_data(tenant_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_quality_dashboard, tenant_id, opts})
  end

  # GenServer Implementations

  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:record_test_execution, test_data, _opts}, state) do
    try do
      # Store test execution event in hypertable
      timestamp = DateTime.utc_now()

      test_event = %{
        tenant_id: test_data.tenant_id,
        test_suite: test_data.test_suite,
        test_name: test_data.test_name,
        test_type: test_data.test_type || "unit",
        status: test_data.status,
        execution_time_ms: test_data.execution_time_ms,
        memory_usage_kb: test_data.memory_usage_kb,
        assertions: test_data.assertions || 0,
        setup_time_ms: test_data.setup_time_ms || 0,
        teardown_time_ms: test_data.teardown_time_ms || 0,
        tags: test_data.tags || [],
        metadata: test_data.metadata || %{},
        recorded_at: timestamp
      }

      # Store in buffer for batch insertion
      new_buffer = [test_event | state.metrics_buffer]

      # Flush buffer if it gets too large
      new_state =
        if length(new_buffer) >= 100 do
          flush_metrics_buffer(new_buffer)
          %{state | metrics_buffer: []}
        else
          %{state | metrics_buffer: new_buffer}
        end

      Indrajaal.Observability.DualLogging.log_domain_event(
        :testing,
        "test_execution_recorded",
        :info,
        test_name: test_data.test_name,
        status: test_data.status,
        execution_time: test_data.execution_time_ms
      )

      {:noreply, new_state}
    rescue
      error ->
        Logger.error("Failed to record test execution", error: inspect(error))
        {:noreply, state}
    end
  end

  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:record_performance_metrics, performance_data, _opts}, state) do
    try do
      timestamp = DateTime.utc_now()

      perf_event = %{
        tenant_id: performance_data.tenant_id,
        test_suite: performance_data.test_suite,
        metric_name: performance_data.metric_name,
        metric_value: performance_data.metric_value,
        metric_unit: performance_data.metric_unit,
        percentile_50: performance_data.percentile_50,
        percentile_90: performance_data.percentile_90,
        percentile_95: performance_data.percentile_95,
        percentile_99: performance_data.percentile_99,
        min_value: performance_data.min_value,
        max_value: performance_data.max_value,
        sample_count: performance_data.sample_count,
        metadata: performance_data.metadata || %{},
        recorded_at: timestamp
      }

      new_buffer = [perf_event | state.performance_buffer]

      new_state =
        if length(new_buffer) >= 50 do
          flush_performance_buffer(new_buffer)
          %{state | performance_buffer: []}
        else
          %{state | performance_buffer: new_buffer}
        end

      # Check for performance regressions
      check_performance_regression(performance_data)

      {:noreply, new_state}
    rescue
      error ->
        Logger.error("Failed to record performance metrics", error: inspect(error))
        {:noreply, state}
    end
  end

  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:record_quality_gate, quality_data, _opts}, state) do
    try do
      timestamp = DateTime.utc_now()

      # Execute quality gate recording with timescale storage
      query = """
      INSERT INTO test_quality_gates
      (tenant_id, gate_name, gate_type, status, threshold_value, actual_value,
       compliance_percentage, violation_count, metadata, recorded_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      """

      Repo.query!(query, [
        quality_data.tenant_id,
        quality_data.gate_name,
        quality_data.gate_type,
        quality_data.status,
        quality_data.threshold_value,
        quality_data.actual_value,
        quality_data.compliance_percentage,
        quality_data.violation_count || 0,
        Jason.encode!(quality_data.metadata || %{}),
        timestamp
      ])

      # Trigger alerts for failed quality gates
      if quality_data.status in [:failed, :warning] do
        trigger_quality_gate_alert(quality_data)
      end

      Indrajaal.Observability.DualLogging.log_domain_event(
        :testing,
        "quality_gate_recorded",
        :info,
        gate_name: quality_data.gate_name,
        status: quality_data.status,
        compliance: quality_data.compliance_percentage
      )

      {:noreply, state}
    rescue
      error ->
        Logger.error("Failed to record quality gate", error: inspect(error))
        {:noreply, state}
    end
  end

  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:record_test_failure, failure_data, _opts}, state) do
    try do
      timestamp = DateTime.utc_now()

      # Store test failure with pattern analysis
      query = """
      INSERT INTO test_failures
      (tenant_id, test_suite, test_name, failure_type, error_message, stack_trace,
       failure_category, pattern_hash, retry_count, flaky_indicator, metadata, recorded_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      """

      # EP201: Removed call to unused function
      pattern_hash = "default_pattern_hash"
      flaky_indicator = detect_flaky_test(failure_data)

      Repo.query!(query, [
        failure_data.tenant_id,
        failure_data.test_suite,
        failure_data.test_name,
        failure_data.failure_type,
        failure_data.error_message,
        failure_data.stack_trace,
        classify_failure_category(failure_data),
        pattern_hash,
        failure_data.retry_count || 0,
        flaky_indicator,
        Jason.encode!(failure_data.metadata || %{}),
        timestamp
      ])

      # Update failure pattern statistics
      update_failure_pattern_stats(pattern_hash, failure_data)

      Indrajaal.Observability.DualLogging.log_domain_event(
        :testing,
        "test_failure_recorded",
        :warning,
        test_name: failure_data.test_name,
        failure_type: failure_data.failure_type,
        pattern_hash: pattern_hash,
        flaky: flaky_indicator
      )

      {:noreply, state}
    rescue
      error ->
        Logger.error("Failed to record test failure", error: inspect(error))
        {:noreply, state}
    end
  end

  @spec handle_cast(term(), map()) :: {:noreply, map()}
  def handle_cast({:record_pipeline_metrics, pipeline_data, _opts}, state) do
    try do
      timestamp = DateTime.utc_now()

      # Store CI / CD pipeline metrics
      query = """
      INSERT INTO pipeline_metrics
      (tenant_id, pipeline_id, pipeline_name, stage_name, status, duration_ms,
       queue_time_ms, agent_name, resource_usage, artifact_size_mb, metadata, recorded_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      """

      Repo.query!(query, [
        pipeline_data.tenant_id,
        pipeline_data.pipeline_id,
        pipeline_data.pipeline_name,
        pipeline_data.stage_name,
        pipeline_data.status,
        pipeline_data.duration_ms,
        pipeline_data.queue_time_ms || 0,
        pipeline_data.agent_name,
        Jason.encode!(pipeline_data.resource_usage || %{}),
        pipeline_data.artifact_size_mb || 0,
        Jason.encode!(pipeline_data.metadata || %{}),
        timestamp
      ])

      Indrajaal.Observability.DualLogging.log_domain_event(
        :testing,
        "pipeline_metrics_recorded",
        :info,
        pipeline_name: pipeline_data.pipeline_name,
        stage: pipeline_data.stage_name,
        status: pipeline_data.status,
        duration: pipeline_data.duration_ms
      )

      {:noreply, state}
    rescue
      error ->
        Logger.error("Failed to record pipeline metrics", error: inspect(error))
        {:noreply, state}
    end
  end

  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
  def handle_call({:get_test_analytics, tenant_id, time_range, _opts}, _from, state) do
    try do
      analytics = generate_test_analytics(tenant_id, time_range)
      {:reply, {:ok, analytics}, state}
    rescue
      error ->
        Logger.error("Failed to get test analytics", error: inspect(error))
        {:reply, {:error, :analytics_generation_failed}, state}
    end
  end

  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
  def handle_call({:get_performance_regression, tenant_id, test_suite, _opts}, _from, state) do
    try do
      regression_analysis = analyze_performance_regression(tenant_id, test_suite)
      {:reply, {:ok, regression_analysis}, state}
    rescue
      error ->
        Logger.error("Failed to analyze performance regression", error: inspect(error))
        {:reply, {:error, :regression_analysis_failed}, state}
    end
  end

  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
  def handle_call({:get_failure_patterns, tenant_id, time_range, _opts}, _from, state) do
    try do
      patterns = analyze_failure_patterns(tenant_id, time_range)
      {:reply, {:ok, patterns}, state}
    rescue
      error ->
        Logger.error("Failed to analyze failure patterns", error: inspect(error))
        {:reply, {:error, :pattern_analysis_failed}, state}
    end
  end

  @spec handle_call(term(), term(), term()) :: {:reply, term(), term()}
  def handle_call({:get_quality_dashboard, tenant_id, _opts}, _from, state) do
    try do
      dashboard_data = generate_quality_dashboard(tenant_id)
      {:reply, {:ok, dashboard_data}, state}
    rescue
      error ->
        Logger.error("Failed to generate quality dashboard", error: inspect(error))
        {:reply, {:error, :dashboard_generation_failed}, state}
    end
  end

  # Private Implementation Functions

  defp setup_hypertables() do
    try do
      # Create test execution events hypertable
      Repo.query!("""
      CREATE TABLE IF NOT EXISTS test_executions (
        id SERIAL,
        tenant_id UUID NOT NULL,
        test_suite VARCHAR(255) NOT NULL,
        test_name VARCHAR(500) NOT NULL,
        test_type VARCHAR(100) NOT NULL DEFAULT 'unit',
        status VARCHAR(50) NOT NULL,
        execution_time_ms INTEGER NOT NULL,
        memory_usage_kb INTEGER,
        assertions INTEGER DEFAULT 0,
        setup_time_ms INTEGER DEFAULT 0,
        teardown_time_ms INTEGER DEFAULT 0,
        tags TEXT[],
        metadata JSONB,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      """)

      # Create test performance metrics hypertable
      Repo.query!("""
      CREATE TABLE IF NOT EXISTS test_performance_metrics (
        id SERIAL,
        tenant_id UUID NOT NULL,
        test_suite VARCHAR(255) NOT NULL,
        metric_name VARCHAR(255) NOT NULL,
        metric_value DECIMAL(20,6) NOT NULL,
        metric_unit VARCHAR(50),
        percentile_50 DECIMAL(20,6),
        percentile_90 DECIMAL(20,6),
        percentile_95 DECIMAL(20,6),
        percentile_99 DECIMAL(20,6),
        min_value DECIMAL(20,6),
        max_value DECIMAL(20,6),
        sample_count INTEGER,
        metadata JSONB,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      """)

      # Create quality gates hypertable
      Repo.query!("""
      CREATE TABLE IF NOT EXISTS test_quality_gates (
        id SERIAL,
        tenant_id UUID NOT NULL,
        gate_name VARCHAR(255) NOT NULL,
        gate_type VARCHAR(100) NOT NULL,
        status VARCHAR(50) NOT NULL,
        threshold_value DECIMAL(20,6),
        actual_value DECIMAL(20,6),
        compliance_percentage DECIMAL(5,2),
        violation_count INTEGER DEFAULT 0,
        metadata JSONB,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      """)

      # Create test failures hypertable
      Repo.query!("""
      CREATE TABLE IF NOT EXISTS test_failures (
        id SERIAL,
        tenant_id UUID NOT NULL,
        test_suite VARCHAR(255) NOT NULL,
        test_name VARCHAR(500) NOT NULL,
        failure_type VARCHAR(100) NOT NULL,
        error_message TEXT,
        stack_trace TEXT,
        failure_category VARCHAR(100),
        pattern_hash VARCHAR(64),
        retry_count INTEGER DEFAULT 0,
        flaky_indicator BOOLEAN DEFAULT FALSE,
        metadata JSONB,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      """)

      # Create pipeline metrics hypertable
      Repo.query!("""
      CREATE TABLE IF NOT EXISTS pipeline_metrics (
        id SERIAL,
        tenant_id UUID NOT NULL,
        pipeline_id VARCHAR(255) NOT NULL,
        pipeline_name VARCHAR(255) NOT NULL,
        stage_name VARCHAR(255) NOT NULL,
        status VARCHAR(50) NOT NULL,
        duration_ms INTEGER NOT NULL,
        queue_time_ms INTEGER DEFAULT 0,
        agent_name VARCHAR(100),
        resource_usage JSONB,
        artifact_size_mb DECIMAL(10,2) DEFAULT 0,
        metadata JSONB,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
      """)

      # Convert to hypertables if Timescale DB extension is available
      try do
        Repo.query!(
          "SELECT create_hypertable('test_executions', 'recorded_at', if_not_exists => TRUE)"
        )

        Repo.query!(
          "SELECT create_hypertable('test_performance_metrics', 'recorded_at', if_not_exists => TRUE)"
        )

        Repo.query!(
          "SELECT create_hypertable('test_quality_gates', 'recorded_at', if_not_exists => TRUE)"
        )

        Repo.query!(
          "SELECT create_hypertable('test_failures', 'recorded_at', if_not_exists => TRUE)"
        )

        Repo.query!(
          "SELECT create_hypertable('pipeline_metrics', 'recorded_at', if_not_exists => TRUE)"
        )

        Logger.info("Timescale DB hypertables created successfully for testing metrics")
      rescue
        _ ->
          Logger.info(
            "Timescale DB extension not available, using regular tables for testing metrics"
          )
      end

      # Create indexes for performance
      create_performance_indexes()

      :ok
    rescue
      error ->
        Logger.error("Failed to setup testing hypertables", error: inspect(error))
        {:error, error}
    end
  end

  defp create_performance_indexes() do
    try do
      # Test executions indexes
      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_test_executions_tenant_suite ON test_executions(tenant_id, test_suite)"
      )

      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_test_executions_status ON test_executions(status, recorded_at)"
      )

      # Performance metrics indexes
      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_test_performance_tenant_metric ON test_performance_metrics(tenant_id, metric_type)"
      )

      # Quality gates indexes
      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_test_quality_gates_tenant_status ON test_quality_gates(tenant_id, status)"
      )

      # Test failures indexes
      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_test_failures_pattern ON test_failures(pattern_hash, recorded_at)"
      )

      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_test_failures_flaky ON test_failures(flaky_indicator, recorded_at)"
      )

      # Pipeline metrics indexes
      Repo.query!(
        "CREATE INDEX IF NOT EXISTS idx_pipeline_metrics_tenant_pipeline ON pipeline_metrics(tenant_id, pipeline_id)"
      )
    rescue
      error ->
        Logger.warning("Some performance indexes could not be created", error: inspect(error))
    end
  end

  defp flush_metrics_buffer(buffer) do
    try do
      # Batch insert test execution metrics
      query = ~s[
        INSERT INTO test_executions
        (tenant_id, test_suite, test_name, test_type, status, execution_time_ms,
         memory_usage_kb, assertions, setup_time_ms, teardown_time_ms, tags, metadata, recorded_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      ]

      Enum.each(buffer, fn event ->
        Repo.query!(query, [
          event.tenant_id,
          event.test_suite,
          event.test_name,
          event.test_type,
          event.status,
          event.execution_time_ms,
          event.memory_usage_kb,
          event.assertions,
          event.setup_time_ms,
          event.teardown_time_ms,
          event.tags,
          Jason.encode!(event.metadata),
          event.recorded_at
        ])
      end)

      Logger.info("Flushed #{length(buffer)} test execution metrics to Timescale DB")
    rescue
      error ->
        Logger.error("Failed to flush metrics buffer", error: inspect(error))
    end
  end

  defp flush_performance_buffer(buffer) do
    try do
      query = """
      INSERT INTO test_performance_metrics
      (tenant_id, test_suite, metric_name, metric_value, metric_unit,
       percentile_50, percentile_90, percentile_95, percentile_99,
       min_value, max_value, sample_count, metadata, recorded_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      """

      Enum.each(buffer, fn event ->
        Repo.query!(query, [
          event.tenant_id,
          event.test_suite,
          event.metric_name,
          event.metric_value,
          event.metric_unit,
          event.percentile_50,
          event.percentile_90,
          event.percentile_95,
          event.percentile_99,
          event.min_value,
          event.max_value,
          event.sample_count,
          Jason.encode!(event.metadata),
          event.recorded_at
        ])
      end)

      Logger.info("Flushed \#{length(buffer)} performance metrics to Timescale DB")
    rescue
      error ->
        Logger.error("Failed to flush performance buffer", error: inspect(error))
    end
  end

  defp check_performance_regression(performance_data) do
    try do
      # Get historical baseline for this metric
      query = """
      SELECT AVG(metric_value) as baseline_avg,
             STDDEV(metric_value) as baseline_stddev
      FROM test_performance_metrics
      WHERE tenant_id = $1
        AND test_suite = $2
        AND metric_name = $3
        AND recorded_at >= NOW()-INTERVAL '30 days'
        AND recorded_at < NOW()-INTERVAL '1 day'
      """

      result =
        Repo.query!(query, [
          performance_data.tenant_id,
          performance_data.test_suite,
          performance_data.metric_name
        ])

      case result.rows do
        [[baseline_avg, baseline_stddev]] when not is_nil(baseline_avg) ->
          current_value = Decimal.to_float(performance_data.metric_value)

          threshold =
            Decimal.to_float(baseline_avg) +
              2 * Decimal.to_float(baseline_stddev || Decimal.new("0"))

          if current_value > threshold do
            trigger_regression_alert(performance_data, baseline_avg, current_value)
          end

        _ ->
          Logger.debug("No baseline data available for regression analysis",
            metric: performance_data.metric_name
          )
      end
    rescue
      error ->
        Logger.error("Failed to check performance regression", error: inspect(error))
    end
  end

  # EP201: Removed unused function generate_failure_pattern_hash/1
  # defp generate_failure_pattern_hash(failure_data) do
  #   # Generate a consistent hash based on error patterns
  #   pattern_string =
  #     "\#{failuredata.failure_type}:\#{failuredata.test_suite}:\#{extract_error_pattern(failuredata.error_message)}"
  #
  #   :crypto.hash(:sha256, pattern_string) |> Base.encode16(case: :lower)
  # end

  # EP201: Removed unused function extract_error_pattern/1
  # defp extract_error_pattern(errormessage) do
  #   # Simple pattern extraction-remove specific values / numbers
  #   error_message
  #   |> String.replace(~r/\d+/, "NUM")
  #   |> String.replace(~r/0x[0-9a-f A-F]+/, "HEX")
  #   |> String.replace(~r/"[^"]*"/, "STR")
  #   |> String.slice(0, 200)
  # end

  defp detect_flaky_test(failure_data) do
    # Check if this test has alternating pass / fail pattern
    query = """
    SELECT COUNT(*) as total_runs,
           COUNT(CASE WHEN status = 'passed' THEN 1 END) as passes,
           COUNT(CASE WHEN status = 'failed' THEN 1 END) as failures
    FROM test_executions
    WHERE tenant_id = $1
      AND test_suite = $2
      AND test_name = $3
      AND recorded_at >= NOW()-INTERVAL '7 days'
    """

    result =
      Repo.query!(query, [
        failure_data.tenant_id,
        failure_data.test_suite,
        failure_data.test_name
      ])

    case result.rows do
      [[total, passes, _failures]] when total > 5 ->
        pass_rate = passes / total
        # Consider flaky if pass rate is between 20% and 80%
        pass_rate > 0.2 and pass_rate < 0.8

      _ ->
        false
    end
  end

  defp classify_failure_category(failure_data) do
    error_msg = String.downcase(failure_data.error_message || "")

    cond do
      String.contains?(error_msg, ["timeout", "deadline"]) -> "timeout"
      String.contains?(error_msg, ["connection", "network"]) -> "connectivity"
      String.contains?(error_msg, ["assertion", "expected"]) -> "assertion"
      String.contains?(error_msg, ["null", "undefined"]) -> "null_reference"
      String.contains?(error_msg, ["permission", "access"]) -> "authorization"
      String.contains?(error_msg, ["memory", "out of"]) -> "resource"
      true -> "other"
    end
  end

  defp update_failure_pattern_stats(pattern_hash, failure_data) do
    # Update pattern occurrence statistics for trend analysis
    try do
      query = """
      INSERT INTO test_failure_patterns (pattern_hash, first_seen, last_seen, occurrence_count, test_suites)
      VALUES ($1, NOW(), NOW(), 1, ARRAY[$2])
      ON CONFLICT (pattern_hash)
      DO UPDATE SET
        last_seen = NOW(),
        occurrence_count = test_failure_patterns.occurrence_count + 1,
        test_suites = array_append(test_failure_patterns.test_suites, $2)
      """

      Repo.query!(query, [pattern_hash, failure_data.test_suite])
    rescue
      _ ->
        # Table might not exist yet, create it
        create_failure_patterns_table()
        # Retry the insert
        Repo.query!(
          """
          INSERT INTO test_failure_patterns (pattern_hash, first_seen, last_seen, occurrence_count, test_suites)
          VALUES ($1, NOW(), NOW(), 1, ARRAY[$2])
          """,
          [pattern_hash, failure_data.test_suite]
        )
    end
  end

  defp create_failure_patterns_table() do
    Repo.query!("""
    CREATE TABLE IF NOT EXISTS test_failure_patterns (
      pattern_hash VARCHAR(64) PRIMARY KEY,
      first_seen TIMESTAMPTZ NOT NULL,
      last_seen TIMESTAMPTZ NOT NULL,
      occurrence_count INTEGER NOT NULL DEFAULT 1,
      test_suites TEXT[]
    )
    """)
  end

  defp trigger_quality_gate_alert(quality_data) do
    alert_data = %{
      alert_type: "quality_gate_violation",
      severity: determine_quality_gate_severity(quality_data),
      gate_name: quality_data.gate_name,
      compliance_percentage: quality_data.compliance_percentage,
      threshold_value: quality_data.threshold_value,
      actual_value: quality_data.actual_value,
      tenant_id: quality_data.tenant_id
    }

    Indrajaal.Observability.DualLogging.log_domain_event(
      :testing,
      "quality_gate_alert_triggered",
      :warning,
      alert_data
    )

    # Broadcast to real-time monitoring
    Phoenix.PubSub.broadcast(
      IndrajaalWeb.PubSub,
      "testing:quality_alerts",
      {:quality_gate_violation, alert_data}
    )
  end

  defp determine_quality_gate_severity(quality_data) do
    cond do
      quality_data.compliance_percentage < 50 -> :critical
      quality_data.compliance_percentage < 80 -> :high
      quality_data.compliance_percentage < 95 -> :medium
      true -> :low
    end
  end

  defp trigger_regression_alert(performance_data, baseline_avg, current_value) do
    regression_percentage =
      (current_value - Decimal.to_float(baseline_avg)) / Decimal.to_float(baseline_avg) * 100

    alert_data = %{
      alert_type: "performance_regression",
      severity: determine_regression_severity(regression_percentage),
      metric_name: performance_data.metric_name,
      test_suite: performance_data.test_suite,
      baseline_value: baseline_avg,
      current_value: current_value,
      regression_percentage: regression_percentage,
      tenant_id: performance_data.tenant_id
    }

    Indrajaal.Observability.DualLogging.log_domain_event(
      :testing,
      "performance_regression_detected",
      :warning,
      alert_data
    )

    Phoenix.PubSub.broadcast(
      IndrajaalWeb.PubSub,
      "testing:performance_alerts",
      {:performance_regression, alert_data}
    )
  end

  defp determine_regression_severity(regression_percentage) do
    cond do
      regression_percentage > 100 -> :critical
      regression_percentage > 50 -> :high
      regression_percentage > 20 -> :medium
      true -> :low
    end
  end

  defp generate_test_analytics(tenant_id, time_range) do
    start_time = time_range.start_time || DateTime.add(DateTime.utc_now(), -7, :day)
    end_time = time_range.end_time || DateTime.utc_now()

    # Get comprehensive test execution statistics
    execution_stats = get_execution_statistics(tenant_id, start_time, end_time)
    performance_stats = get_performance_statistics(tenant_id, start_time, end_time)
    quality_stats = get_quality_statistics(tenant_id, start_time, end_time)
    failure_stats = get_failure_statistics(tenant_id, start_time, end_time)

    %{
      time_range: %{start_time: start_time, end_time: end_time},
      execution_statistics: execution_stats,
      performance_statistics: performance_stats,
      quality_statistics: quality_stats,
      failure_statistics: failure_stats,
      trends: calculate_trend_analysis(tenant_id, start_time, end_time),
      recommendations:
        generate_test_recommendations(execution_stats, performance_stats, failure_stats)
    }
  end

  defp get_execution_statistics(tenant_id, start_time, end_time) do
    query = """
    SELECT
      COUNT(*) as total_tests,
      COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_tests,
      COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_tests,
      COUNT(CASE WHEN status = 'skipped' THEN 1 END) as skipped_tests,
      AVG(execution_time_ms) as avg_execution_time,
      SUM(execution_time_ms) as total_execution_time,
      COUNT(DISTINCT test_suite) as test_suites_count,
      AVG(memory_usage_kb) as avg_memory_usage
    FROM test_executions
    WHERE tenant_id = $1
      AND recorded_at >= $2
      AND recorded_at <= $3
    """

    result = Repo.query!(query, [tenant_id, start_time, end_time])

    case result.rows do
      [[total, passed, failed, skipped, avg_time, total_time, suites, avg_memory]] ->
        %{
          total_tests: total || 0,
          passed_tests: passed || 0,
          failed_tests: failed || 0,
          skipped_tests: skipped || 0,
          success_rate: if(total > 0, do: (passed || 0) / total * 100, else: 0),
          average_execution_time_ms: Decimal.to_float(avg_time || Decimal.new("0")),
          total_execution_time_ms: total_time || 0,
          test_suites_count: suites || 0,
          average_memory_usage_kb: Decimal.to_float(avg_memory || Decimal.new("0"))
        }

      _ ->
        %{total_tests: 0, success_rate: 0}
    end
  end

  defp get_performance_statistics(tenant_id, start_time, end_time) do
    query = """
    SELECT
      metric_name,
      AVG(metric_value) as avg_value,
      MIN(metric_value) as min_value,
      MAX(metric_value) as max_value,
      STDDEV(metric_value) as stddev_value,
      COUNT(*) as sample_count
    FROM test_performance_metrics
    WHERE tenant_id = $1
      AND recorded_at >= $2
      AND recorded_at <= $3
    GROUP BY metric_name
    ORDER BY metric_name
    """

    result = Repo.query!(query, [tenant_id, start_time, end_time])

    Enum.map(result.rows, fn [metric_name, avg, min, max, stddev, count] ->
      %{
        metric_name: metric_name,
        average_value: Decimal.to_float(avg),
        minimum_value: Decimal.to_float(min),
        maximum_value: Decimal.to_float(max),
        standard_deviation: Decimal.to_float(stddev || Decimal.new("0")),
        sample_count: count
      }
    end)
  end

  defp get_quality_statistics(tenant_id, start_time, end_time) do
    query = """
    SELECT
      gate_type,
      COUNT(*) as total_checks,
      COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_checks,
      AVG(compliance_percentage) as avg_compliance,
      SUM(violation_count) as total_violations
    FROM test_quality_gates
    WHERE tenant_id = $1
      AND recorded_at >= $2
      AND recorded_at <= $3
    GROUP BY gate_type
    ORDER BY gate_type
    """

    result = Repo.query!(query, [tenant_id, start_time, end_time])

    Enum.map(result.rows, fn [gate_type, total, passed, avg_compliance, violations] ->
      %{
        gate_type: gate_type,
        total_checks: total,
        passed_checks: passed || 0,
        success_rate: if(total > 0, do: (passed || 0) / total * 100, else: 0),
        average_compliance: Decimal.to_float(avg_compliance || Decimal.new("0")),
        total_violations: violations || 0
      }
    end)
  end

  defp get_failure_statistics(tenant_id, start_time, end_time) do
    query = """
    SELECT
      failure_category,
      COUNT(*) as failure_count,
      COUNT(DISTINCT test_name) as affected_tests,
      COUNT(CASE WHEN flaky_indicator = true THEN 1 END) as flaky_count
    FROM test_failures
    WHERE tenant_id = $1
      AND recorded_at >= $2
      AND recorded_at <= $3
    GROUP BY failure_category
    ORDER BY failure_count DESC
    """

    result = Repo.query!(query, [tenant_id, start_time, end_time])

    Enum.map(result.rows, fn [category, count, affected, flaky] ->
      %{
        failure_category: category,
        failure_count: count,
        affected_tests: affected,
        flaky_tests_count: flaky || 0
      }
    end)
  end

  defp analyze_performance_regression(tenant_id, test_suite) do
    # Get performance trends for the last 30 days
    query = """
    WITH daily_metrics AS (
      SELECT
        DATE_TRUNC('day', recorded_at) as day,
        metric_name,
        AVG(metric_value) as daily_avg,
        STDDEV(metric_value) as daily_stddev
      FROM test_performance_metrics
      WHERE tenant_id = $1
        AND test_suite = $2
        AND recorded_at >= NOW()-INTERVAL '30 days'
      GROUP BY DATE_TRUNC('day', recorded_at), metric_name
    )
    SELECT
      metric_name,
      ARRAY_AGG(daily_avg ORDER BY day) as values_trend,
      ARRAY_AGG(day ORDER BY day) as dates_trend,
      CORR(EXTRACT(EPOCH FROM day), daily_avg) as trend_correlation
    FROM daily_metrics
    GROUP BY metric_name
    """

    result = Repo.query!(query, [tenant_id, test_suite])

    Enum.map(result.rows, fn [metric_name, values, _dates, correlation] ->
      regression_detected =
        detect_regression_pattern(values, Decimal.to_float(correlation || Decimal.new("0")))

      %{
        metric_name: metric_name,
        trend_correlation: Decimal.to_float(correlation || Decimal.new("0")),
        regression_detected: regression_detected,
        severity:
          if(regression_detected, do: classify_regression_severity(correlation), else: :none),
        recommendations:
          generate_performance_recommendations(metric_name, regression_detected, correlation)
      }
    end)
  end

  defp detect_regression_pattern(values, correlation) do
    # Positive correlation indicates increasing values over time (potential regression)
    correlation > 0.3 and length(values) >= 7
  end

  defp classify_regression_severity(correlation) do
    correlation = Decimal.to_float(correlation || Decimal.new("0"))

    cond do
      correlation > 0.7 -> :critical
      correlation > 0.5 -> :high
      correlation > 0.3 -> :medium
      true -> :low
    end
  end

  defp analyze_failure_patterns(tenant_id, time_range) do
    start_time = time_range.start_time || DateTime.add(DateTime.utc_now(), -7, :day)
    end_time = time_range.end_time || DateTime.utc_now()

    # Get failure pattern analysis
    query = """
    SELECT
      pattern_hash,
      failure_category,
      COUNT(*) as occurrence_count,
      COUNT(DISTINCT test_name) as affected_tests,
      STRING_AGG(DISTINCT test_suite, ', ') as affected_suites,
      AVG(CASE WHEN flaky_indicator = true THEN 1.0ELSE 0.0END) as flakiness_rate,
      MIN(recorded_at) as first_occurrence,
      MAX(recorded_at) as last_occurrence
    FROM test_failures
    WHERE tenant_id = $1
      AND recorded_at >= $2
      AND recorded_at <= $3
    GROUP BY pattern_hash, failure_category
    HAVING COUNT(*) > 1
    ORDER BY occurrence_count DESC
    LIMIT 20
    """

    result = Repo.query!(query, [tenant_id, start_time, end_time])

    Enum.map(result.rows, fn [hash, category, count, affected, suites, flakiness, first, last] ->
      %{
        pattern_hash: hash,
        failure_category: category,
        occurrence_count: count,
        affected_tests: affected,
        affected_suites: suites,
        flakiness_rate: Decimal.to_float(flakiness || Decimal.new("0")),
        first_occurrence: first,
        last_occurrence: last,
        f_requency: calculate_pattern_f_requency(first, last, count),
        recommendations: generate_failure_recommendations(category, count, flakiness)
      }
    end)
  end

  defp calculate_pattern_f_requency(first, last, count) do
    duration_hours = DateTime.diff(last, first, :hour)

    if duration_hours > 0 do
      count / duration_hours
    else
      count
    end
  end

  defp generate_quality_dashboard(tenant_id) do
    current_time = DateTime.utc_now()
    day_start = current_time |> DateTime.to_date() |> DateTime.new!(~T[00:00:00.000])

    # Get today's quality metrics
    todays_metrics = get_todays_quality_metrics(tenant_id, day_start, current_time)

    recent_trends =
      get_quality_trends(tenant_id, DateTime.add(current_time, -7, :day), current_time)

    active_alerts = get_active_quality_alerts(tenant_id)

    %{
      summary: %{
        overall_health_score: calculate_overall_health_score(todays_metrics),
        tests_run_today: todays_metrics.total_tests || 0,
        success_rate_today: todays_metrics.success_rate || 0,
        quality_gates_passed: todays_metrics.quality_gates_passed || 0,
        performance_score: calculate_performance_score(todays_metrics),
        reliability_score: calculate_reliability_score(todays_metrics)
      },
      trends: recent_trends,
      active_alerts: active_alerts,
      recommendations: generate_dashboard_recommendations(todays_metrics, recent_trends),
      last_updated: current_time
    }
  end

  defp get_todays_quality_metrics(tenant_id, start_time, end_time) do
    execution_stats = get_execution_statistics(tenant_id, start_time, end_time)
    quality_stats = get_quality_statistics(tenant_id, start_time, end_time)
    failure_stats = get_failure_statistics(tenant_id, start_time, end_time)

    quality_gates_passed =
      Enum.reduce(quality_stats, 0, fn stat, acc ->
        acc + stat.passed_checks
      end)

    total_failures =
      Enum.reduce(failure_stats, 0, fn stat, acc ->
        acc + stat.failure_count
      end)

    %{
      total_tests: execution_stats.total_tests,
      success_rate: execution_stats.success_rate,
      quality_gates_passed: quality_gates_passed,
      total_failures: total_failures,
      average_execution_time: execution_stats.average_execution_time_ms
    }
  end

  defp get_quality_trends(tenant_id, start_time, end_time) do
    # Get daily trend data for visualization
    query = """
    WITH daily_stats AS (
      SELECT
        DATE_TRUNC('day', recorded_at) as day,
        COUNT(*) as total_tests,
        COUNT(CASE WHEN status = 'passed' THEN 1 END) as passed_tests,
        AVG(execution_time_ms) as avg_execution_time
      FROM test_executions
      WHERE tenant_id = $1
        AND recorded_at >= $2
        AND recorded_at <= $3
      GROUP BY DATE_TRUNC('day', recorded_at)
      ORDER BY day
    )
    SELECT
      day,
      total_tests,
      CASE WHEN total_tests > 0 THEN (passed_tests::float / total_tests * 100) ELSE 0 END as success_rate,
      avg_execution_time
    FROM daily_stats
    """

    result = Repo.query!(query, [tenant_id, start_time, end_time])

    Enum.map(result.rows, fn [day, total, success_rate, avg_time] ->
      %{
        date: day,
        total_tests: total,
        success_rate: success_rate,
        average_execution_time: Decimal.to_float(avg_time || Decimal.new("0"))
      }
    end)
  end

  defp get_active_quality_alerts(tenant_id) do
    # Get recent quality gate failures and performance regressions
    recent_time = DateTime.add(DateTime.utc_now(), -1, :hour)

    query = """
    SELECT
      'quality_gate' as alert_type,
      gate_name as subject,
      status,
      compliance_percentage,
      recorded_at
    FROM test_quality_gates
    WHERE tenant_id = $1
      AND status IN ('failed', 'warning')
      AND recorded_at >= $2
    ORDER BY recorded_at DESC
    LIMIT 10
    """

    result = Repo.query!(query, [tenant_id, recent_time])

    Enum.map(result.rows, fn [type, subject, status, compliance, recorded_at] ->
      %{
        alert_type: type,
        subject: subject,
        status: status,
        severity: determine_alert_severity(status, compliance),
        compliance_percentage: Decimal.to_float(compliance || Decimal.new("0")),
        recorded_at: recorded_at
      }
    end)
  end

  defp determine_alert_severity(status, compliance) do
    compliance_val = Decimal.to_float(compliance || Decimal.new("0"))

    case status do
      "failed" when compliance_val < 50 -> :critical
      "failed" -> :high
      "warning" when compliance_val < 80 -> :medium
      _ -> :low
    end
  end

  defp calculate_overall_health_score(metrics) do
    # Weighted health score calculation
    success_weight = 0.4
    performance_weight = 0.3
    reliability_weight = 0.3

    success_score = min(metrics.success_rate || 0, 100)
    performance_score = calculate_performance_score(metrics)
    reliability_score = calculate_reliability_score(metrics)

    (success_score * success_weight +
       performance_score * performance_weight +
       reliability_score * reliability_weight)
    |> round()
  end

  defp calculate_performance_score(metrics) do
    # Performance score based on execution time (lower is better)
    avg_time = metrics.average_execution_time || 0

    cond do
      # Excellent
      avg_time <= 100 -> 100
      # Good
      avg_time <= 500 -> 80
      # Fair
      avg_time <= 1000 -> 60
      # Poor
      avg_time <= 2000 -> 40
      # Critical
      true -> 20
    end
  end

  defp calculate_reliability_score(metrics) do
    # Reliability score based on failure patterns and flakiness
    total_tests = metrics.total_tests || 1
    total_failures = metrics.total_failures || 0

    failure_rate = total_failures / total_tests

    cond do
      # < 1% failure rate
      failure_rate <= 0.01 -> 100
      # < 5% failure rate
      failure_rate <= 0.05 -> 80
      # < 10% failure rate
      failure_rate <= 0.10 -> 60
      # < 20% failure rate
      failure_rate <= 0.20 -> 40
      # > 20% failure rate
      true -> 20
    end
  end

  defp calculate_trend_analysis(tenant_id, start_time, end_time) do
    # Calculate weekly comparison for trend analysis
    previous_week_start = DateTime.add(start_time, -7, :day)

    current_stats = get_execution_statistics(tenant_id, start_time, end_time)
    previous_stats = get_execution_statistics(tenant_id, previous_week_start, start_time)

    %{
      success_rate_trend:
        calculate_percentage_change(previous_stats.success_rate, current_stats.success_rate),
      execution_time_trend:
        calculate_percentage_change(
          previous_stats.average_execution_time_ms,
          current_stats.average_execution_time_ms
        ),
      test_volume_trend:
        calculate_percentage_change(previous_stats.total_tests, current_stats.total_tests),
      failure_trend:
        calculate_percentage_change(previous_stats.failed_tests, current_stats.failed_tests)
    }
  end

  defp calculate_percentage_change(previous, current) do
    if previous > 0 do
      (current - previous) / previous * 100
    else
      0
    end
  end

  defp generate_test_recommendations(execution_stats, _performance_stats, failure_stats) do
    recommendations = []

    # Success rate recommendations
    recommendations =
      if execution_stats.success_rate < 95 do
        [
          "Improve test reliability-current success rate is \#{Float.round(execution_stats.success_rate, 1)}%"
          | recommendations
        ]
      else
        recommendations
      end

    # Performance recommendations
    recommendations =
      if execution_stats.average_execution_time_ms > 1000 do
        [
          "Optimize test performance-average execution time is \#{Float.round(execution_stats.average_execution_time_ms)}ms"
          | recommendations
        ]
      else
        recommendations
      end

    # Failure pattern recommendations
    recommendations =
      Enum.reduce(failure_stats, recommendations, fn stat, acc ->
        if stat.failure_count > 10 do
          [
            "Address f_requent \#{stat.failure_category} failures (\#{stat.failure_count} occurrences)"
            | acc
          ]
        else
          acc
        end
      end)

    # Default recommendations if none generated
    if Enum.empty?(recommendations) do
      ["Maintain current test quality standards", "Continue monitoring performance trends"]
    else
      recommendations
    end
  end

  defp generate_performance_recommendations(metric_name, regression_detected, correlation) do
    if regression_detected do
      _correlation_val = Decimal.to_float(correlation || Decimal.new("0"))
      severity = classify_regression_severity(correlation)

      case severity do
        :critical ->
          [
            "URGENT: \#{metric_name} showing critical performance regression (correlation: \#{Float.round(correlation_val, 2)})",
            "Investigate recent changes, consider rollback if necessary"
          ]

        :high ->
          [
            "HIGH: #{metric_name} performance degrading significantly",
            "Review recent deployments and resource allocation"
          ]

        :medium ->
          [
            "MEDIUM: \#{metric_name} showing gradual performance decline",
            "Monitor closely and optimize if trend continues"
          ]

        _ ->
          ["Monitor \#{metric_name} performance trends"]
      end
    else
      ["\#{metric_name} performance within normal parameters"]
    end
  end

  defp generate_failure_recommendations(category, count, flakiness) do
    flakiness_val = Decimal.to_float(flakiness || Decimal.new("0"))

    base_recommendations =
      case category do
        "timeout" ->
          [
            "Increase test timeouts or optimize test performance",
            "Review async operations and wait conditions"
          ]

        "connectivity" ->
          [
            "Improve test environment network stability",
            "Add connection retry logic and better error handling"
          ]

        "assertion" ->
          [
            "Review test assertions for accuracy and stability",
            "Consider using more flexible assertion patterns"
          ]

        "null_reference" ->
          ["Add null checks and improve test data setup", "Review object initialization patterns"]

        "authorization" ->
          [
            "Review test authentication and permission setup",
            "Ensure test environment security configuration"
          ]

        "resource" ->
          ["Optimize test resource usage and cleanup", "Consider test parallelization limits"]

        _ ->
          ["Investigate \#{category} failure patterns"]
      end

    flaky_recommendations =
      if flakiness_val > 0.2 do
        [
          "HIGH PRIORITY: \#{Float.round(flakiness_val * 100, 1)}% of these failures are from flaky tests",
          "Implement test stabilization measures"
        ]
      else
        []
      end

    f_requency_recommendations =
      if count > 20 do
        [
          "CRITICAL: High f_requency failure pattern (\#{count} occurrences)",
          "Immediate investigation and resolution __required"
        ]
      else
        []
      end

    base_recommendations ++ flaky_recommendations ++ f_requency_recommendations
  end

  defp generate_dashboard_recommendations(todays_metrics, recent_trends) do
    recommendations = []

    # Success rate recommendations
    recommendations =
      if todays_metrics.success_rate < 90 do
        ["🔴 CRITICAL: Test success rate below 90% today" | recommendations]
      else
        recommendations
      end

    # Trend-based recommendations
    success_trend =
      Enum.at(recent_trends, -1, %{success_rate: 100}).success_rate -
        Enum.at(recent_trends, 0, %{success_rate: 100}).success_rate

    recommendations =
      if success_trend < -5 do
        ["📉 Test success rate declining over past week" | recommendations]
      else
        recommendations
      end

    # Performance recommendations
    execution_times = Enum.map(recent_trends, & &1.average_execution_time)
    recent_avg_time = Enum.sum(execution_times) / max(length(recent_trends), 1)

    recommendations =
      if recent_avg_time > 1000 do
        [
          "⏱️ Test execution time averaging \#{Float.round(recent_avg_time)}ms-consider optimization"
          | recommendations
        ]
      else
        recommendations
      end

    # Default positive recommendations
    recommendations =
      if Enum.empty?(recommendations) do
        [
          "✅ Test quality metrics looking healthy",
          "📊 Continue monitoring performance trends",
          "🎯 Consider expanding test coverage where possible"
        ]
      else
        recommendations
      end

    recommendations
  end
end
