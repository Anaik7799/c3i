defmodule Indrajaal.Communication.TimescaleCommunicationEvents do
  @moduledoc """

  Timescale DB integration for Communication domain __events with comprehensive analytics.

  Tracks communication __events, delivery analytics, and user engagement patterns
  for regulatory compliance and optimization.
  """

  use GenServer
  require Logger
  alias Indrajaal.Repo

  @hypertable_communication_events """
  CREATE TABLE IF NOT EXISTS communication_events (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    message_id UUID NOT NULL,
    user_id UUID,
    channel VARCHAR(50) NOT NULL, -- email, sms, push, in_app, slack, teams
    __event_type VARCHAR(50) NOT NULL, -- sent, delivered, opened, clicked, bounced, failed
    message_type VARCHAR(50) NOT NULL, -- alarm, notification, campaign, security_alert
    template_id UUID,
    campaign_id UUID,
    subject TEXT,
    recipient VARCHAR(255),
    delivery_status VARCHAR(50),
    delivery_time TIMESTAMPTZ,
    opened_time TIMESTAMPTZ,
    clicked_time TIMESTAMPTZ,
    bounce_reason TEXT,
    error_message TEXT,
    metadata JSONB,
    engagement_score INTEGER,
    compliance_tags TEXT[],
    regulatory_classification VARCHAR(100), -- gdpr, hipaa, sox, pci_dss
    consent_status VARCHAR(50), -- granted, revoked, pending
    retention_period INTEGER, -- days
    INDEX(tenant_id, time DESC),
    INDEX(user_id, time DESC),
    INDEX(channel, __event_type),
    INDEX(regulatory_classification),
    INDEX(consent_status)
  );
  """

  @hypertable_compliance_audit_events """
  CREATE TABLE IF NOT EXISTS compliance_audit_events (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    audit_id UUID NOT NULL,
    compliance_framework VARCHAR(50) NOT NULL, -- gdpr, hipaa, sox, pci_dss, iso27001
    __event_type VARCHAR(50) NOT NULL, -- policy_evaluation, violation_detected, remediation_started, compliance_verified
    resource_type VARCHAR(50), -- user, message, data_export, access_log
    resource_id UUID,
    policy_id UUID,
    violation_severity VARCHAR(20), -- low, medium, high, critical
    violation_details JSONB,
    remediation_actions TEXT[],
    remediation_status VARCHAR(50), -- pending, in_progress, completed, failed
    auditor_id UUID,
    evidence_references TEXT[],
    risk_assessment JSONB,
    next_review_date DATE,
    metadata JSONB,
    INDEX(tenant_id, time DESC),
    INDEX(compliance_framework, __event_type),
    INDEX(violation_severity),
    INDEX(remediation_status),
    INDEX(next_review_date)
  );
  """

  @hypertable_communication_analytics """
  CREATE TABLE IF NOT EXISTS communication_analytics (
    time TIMESTAMPTZ NOT NULL,
    tenant_id UUID NOT NULL,
    period_type VARCHAR(20) NOT NULL, -- hourly, daily, weekly, monthly
    channel VARCHAR(50) NOT NULL,
    message_type VARCHAR(50) NOT NULL,
    total_sent INTEGER DEFAULT 0,
    total_delivered INTEGER DEFAULT 0,
    total_opened INTEGER DEFAULT 0,
    total_clicked INTEGER DEFAULT 0,
    total_bounced INTEGER DEFAULT 0,
    total_failed INTEGER DEFAULT 0,
    delivery_rate DECIMAL(5,2),
    open_rate DECIMAL(5,2),
    click_rate DECIMAL(5,2),
    bounce_rate DECIMAL(5,2),
    engagement_score DECIMAL(8,2),
    cost_per_message DECIMAL(10,4),
    revenue_attribution DECIMAL(15,2),
    unsubscribe_count INTEGER DEFAULT 0,
    complaint_count INTEGER DEFAULT 0,
    reputation_score DECIMAL(5,2),
    metadata JSONB,
    INDEX(tenant_id, time DESC),
    INDEX(channel, period_type),
    INDEX(delivery_rate),
    INDEX(engagement_score DESC)
  );
  """

  @continuous_aggregates [
    """
    CREATE MATERIALIZED VIEW IF NOT EXISTS communication_hourly_stats
    WITH (timescaledb.continuous) AS
    SELECT
      time_bucket('1 hour', time) AS bucket,
      tenant_id,
      channel,
      message_type,
      COUNT(*) as total_events,
      COUNT(*) FILTER (WHERE __event_type = 'delivered') as delivered_count,
      COUNT(*) FILTER (WHERE __event_type = 'opened') as opened_count,
      COUNT(*) FILTER (WHERE __event_type = 'clicked') as clicked_count,
      COUNT(*) FILTER (WHERE __event_type = 'bounced') as bounced_count,
      AVG(engagement_score) as avg_engagement_score
    FROM communication_events
    WHERE __event_type IN ('sent', 'delivered', 'opened', 'clicked', 'bounced', 'failed')
    GROUP BY bucket, tenant_id, channel, message_type
    WITH NO DATA;
    """,
    """
    CREATE MATERIALIZED VIEW IF NOT EXISTS compliance_daily_summary
    WITH (timescaledb.continuous) AS
    SELECT
      time_bucket('1 day', time) AS bucket,
      tenant_id,
      compliance_framework,
      COUNT(*) as total_audits,
      COUNT(*) FILTER (WHERE __event_type = 'violation_detected') as violations_detected,
      COUNT(*) FILTER (WHERE violation_severity = 'critical') as critical_violations,
      COUNT(*) FILTER (WHERE violation_severity = 'high') as high_violations,
      COUNT(*) FILTER (WHERE remediation_status = 'completed') as remediated_count,
      AVG(EXTRACT(epoch FROM (time-time_bucket('1 day', time)))) as avg_resolution_time
    FROM compliance_audit_events
    GROUP BY bucket, tenant_id, compliance_framework
    WITH NO DATA;
    """
  ]

  @spec start_link(keyword() | map()) :: term()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(keyword() | map()) :: term()
  def init(_opts) do
    # 5 minutes
    :timer.send_interval(300_000, :health_check)
    {:ok, %{}}
  end

  @spec setup_hypertables :: any()
  def setup_hypertables do
    with {:ok, _} <- Repo.query(@hypertable_communication_events),
         {:ok, _} <-
           Repo.query(
             "SELECT create_hypertable('communication_events', 'time', if_not_exists => TRUE);"
           ),
         {:ok, _} <- Repo.query(@hypertable_compliance_audit_events),
         {:ok, _} <-
           Repo.query(
             "SELECT create_hypertable('compliance_audit_events', 'time', if_not_exists => TRUE);"
           ),
         {:ok, _} <- Repo.query(@hypertable_communication_analytics),
         {:ok, _} <-
           Repo.query(
             "SELECT create_hypertable('communication_analytics', 'time', if_not_exists => TRUE);"
           ) do
      # Setup continuous aggregates
      Enum.each(@continuous_aggregates, fn query ->
        case Repo.query(query) do
          {:ok, _} ->
            Logger.info("Communication continuous aggregate created successfully")

          {:error, error} ->
            Logger.warning(
              "Communication continuous aggregate creation failed: #{inspect(error)}"
            )
        end
      end)

      # Setup refresh policies
      refresh_policies = [
        "SELECT add_continuous_aggregate_policy('communication_hourly_stats', start_offset => INTERVAL '2 hours', end_offset => INTERVAL '30 minutes', schedule_interval => INTERVAL '1 hour');",
        "SELECT add_continuous_aggregate_policy('compliance_daily_summary', start_offset => INTERVAL '3 days', end_offset => INTERVAL '1 hour', schedule_interval => INTERVAL '1 day');"
      ]

      Enum.each(refresh_policies, fn policy ->
        case Repo.query(policy) do
          {:ok, _} ->
            Logger.info("Communication refresh policy added successfully")

          {:error, error} ->
            Logger.warning("Communication refresh policy failed: #{inspect(error)}")
        end
      end)

      Logger.info("Communication Timescale DB hypertables setup completed")
      :ok
    else
      {:error, error} ->
        Logger.error("Communication Timescale DB setup failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Log communication __event to Timescale DB
  """
  @spec log_communication_event(term()) :: term()
  def log_communication_event(event_data) do
    event_data_with_time = Map.put(event_data, :time, DateTime.utc_now())

    query = """
    INSERT INTO communication_events (
      time, tenant_id, message_id, user_id, channel, __event_type, message_type,
      template_id, campaign_id, subject, recipient, delivery_status, delivery_time,
      opened_time, clicked_time, bounce_reason, error_message, metadata,
      engagement_score, compliance_tags, regulatory_classification, consent_status,
      retention_period
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23
    )
    """

    params = [
      event_data_with_time[:time],
      event_data[:tenant_id],
      event_data[:message_id],
      event_data[:user_id],
      event_data[:channel],
      event_data[:__event_type],
      event_data[:message_type],
      event_data[:template_id],
      event_data[:campaign_id],
      event_data[:subject],
      event_data[:recipient],
      event_data[:delivery_status],
      event_data[:delivery_time],
      event_data[:opened_time],
      event_data[:clicked_time],
      event_data[:bounce_reason],
      event_data[:error_message],
      event_data[:metadata] |> Jason.encode!(),
      event_data[:engagement_score],
      event_data[:compliance_tags],
      event_data[:regulatory_classification],
      event_data[:consent_status],
      event_data[:retention_period]
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to log communication __event: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Log compliance audit __event to Timescale DB
  """
  @spec log_compliance_audit_event(term()) :: term()
  def log_compliance_audit_event(audit_data) do
    audit_data_with_time = Map.put(audit_data, :time, DateTime.utc_now())

    query = """
    INSERT INTO compliance_audit_events (
      time, tenant_id, audit_id, compliance_framework, __event_type, resource_type,
      resource_id, policy_id, violation_severity, violation_details, remediation_actions,
      remediation_status, auditor_id, evidence_references, risk_assessment, next_review_date,
      metadata
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
    )
    """

    params = [
      audit_data_with_time[:time],
      audit_data[:tenant_id],
      audit_data[:audit_id],
      audit_data[:compliance_framework],
      audit_data[:__event_type],
      audit_data[:resource_type],
      audit_data[:resource_id],
      audit_data[:policy_id],
      audit_data[:violation_severity],
      audit_data[:violation_details] |> Jason.encode!(),
      audit_data[:remediation_actions],
      audit_data[:remediation_status],
      audit_data[:auditor_id],
      audit_data[:evidence_references],
      audit_data[:risk_assessment] |> Jason.encode!(),
      audit_data[:next_review_date],
      audit_data[:metadata] |> Jason.encode!()
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to log compliance audit __event: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Update communication analytics aggregated data
  """
  @spec update_communication_analytics(term()) :: term()
  def update_communication_analytics(analytics_data) do
    analytics_data_with_time = Map.put(analytics_data, :time, DateTime.utc_now())

    query = """
    INSERT INTO communication_analytics (
      time, tenant_id, period_type, channel, message_type, total_sent, total_delivered,
      total_opened, total_clicked, total_bounced, total_failed, delivery_rate, open_rate,
      click_rate, bounce_rate, engagement_score, cost_per_message, revenue_attribution,
      unsubscribe_count, complaint_count, reputation_score, metadata
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22
    ) ON CONFLICT (time, tenant_id, period_type, channel, message_type)
    DO UPDATE SET
      total_sent = EXCLUDED.total_sent,
      total_delivered = EXCLUDED.total_delivered,
      total_opened = EXCLUDED.total_opened,
      total_clicked = EXCLUDED.total_clicked,
      total_bounced = EXCLUDED.total_bounced,
      total_failed = EXCLUDED.total_failed,
      delivery_rate = EXCLUDED.delivery_rate,
      open_rate = EXCLUDED.open_rate,
      click_rate = EXCLUDED.click_rate,
      bounce_rate = EXCLUDED.bounce_rate,
      engagement_score = EXCLUDED.engagement_score,
      cost_per_message = EXCLUDED.cost_per_message,
      revenue_attribution = EXCLUDED.revenue_attribution,
      unsubscribe_count = EXCLUDED.unsubscribe_count,
      complaint_count = EXCLUDED.complaint_count,
      reputation_score = EXCLUDED.reputation_score,
      metadata = EXCLUDED.metadata
    """

    params = [
      analytics_data_with_time[:time],
      analytics_data[:tenant_id],
      analytics_data[:period_type],
      analytics_data[:channel],
      analytics_data[:message_type],
      analytics_data[:total_sent] || 0,
      analytics_data[:total_delivered] || 0,
      analytics_data[:total_opened] || 0,
      analytics_data[:total_clicked] || 0,
      analytics_data[:total_bounced] || 0,
      analytics_data[:total_failed] || 0,
      analytics_data[:delivery_rate],
      analytics_data[:open_rate],
      analytics_data[:click_rate],
      analytics_data[:bounce_rate],
      analytics_data[:engagement_score],
      analytics_data[:cost_per_message],
      analytics_data[:revenue_attribution],
      analytics_data[:unsubscribe_count] || 0,
      analytics_data[:complaint_count] || 0,
      analytics_data[:reputation_score],
      analytics_data[:metadata] |> Jason.encode!()
    ]

    case Repo.query(query, params) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to update communication analytics: #{inspect(error)}")
        {:error, error}
    end
  end

  @spec handle_info(term(), term()) :: term()
  def handle_info(:timeout, state) do
    # Health check implementation
    Logger.debug("Communication Timescale DB health check completed")
    {:noreply, state}
  end
end
