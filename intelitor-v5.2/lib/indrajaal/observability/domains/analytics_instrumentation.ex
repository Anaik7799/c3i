defmodule Indrajaal.Observability.Domains.AnalyticsInstrumentation do
  @moduledoc """
  require Logger
  Instrumentation for the Analytics domain.

  Provides comprehensive telemetry,
    metrics, and tracing for analytics processing,
  business intelligence generation, predictive insights, and report generation.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :analytics

  # Telemetry __event prefixes
  @analytics_prefix [:indrajaal, :analytics]
  @report_prefix [:indrajaal, :analytics, :report]
  @insight_prefix [:indrajaal, :analytics, :insight]
  @prediction_prefix [:indrajaal, :analytics, :prediction]

  @doc """
  Attaches all analytics telemetry handlers.
  """
  def setup do
    attach_analytics_handlers()
    attach_report_handlers()
    attach_insight_handlers()
    attach_prediction_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :analytics, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :analytics}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :analytics, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :analytics,
       analytics_event_prefix: @analytics_prefix,
       report_event_prefix: @report_prefix,
       insight_event_prefix: @insight_prefix,
       prediction_event_prefix: @prediction_prefix
     ]}
  end

  def shutdown do
    :ok
  end

  # Analytics Processing Handlers
  defp attach_analytics_handlers do
    events = [
      @analytics_prefix ++ [:processing, :start],
      @analytics_prefix ++ [:processing, :stop],
      @analytics_prefix ++ [:processing, :exception],
      @analytics_prefix ++ [:query, :start],
      @analytics_prefix ++ [:query, :stop],
      @analytics_prefix ++ [:aggregation, :start],
      @analytics_prefix ++ [:aggregation, :stop]
    ]

    :telemetry.attach_many(
      "analytics - processing - handlers",
      events,
      &handle_analytics_event/4,
      nil
    )
  end

  # Report Generation Handlers
  defp attach_report_handlers do
    events = [
      @report_prefix ++ [:generation, :start],
      @report_prefix ++ [:generation, :stop],
      @report_prefix ++ [:generation, :exception],
      @report_prefix ++ [:export, :start],
      @report_prefix ++ [:export, :stop],
      @report_prefix ++ [:schedule, :executed]
    ]

    :telemetry.attach_many(
      "analytics - report - handlers",
      events,
      &handle_report_event/4,
      nil
    )
  end

  # Business Intelligence Handlers
  defp attach_insight_handlers do
    events = [
      @insight_prefix ++ [:generation, :start],
      @insight_prefix ++ [:generation, :stop],
      @insight_prefix ++ [:dashboard, :update],
      @insight_prefix ++ [:kpi, :calculated],
      @insight_prefix ++ [:anomaly, :detected]
    ]

    :telemetry.attach_many(
      "analytics - insight - handlers",
      events,
      &handle_insight_event/4,
      nil
    )
  end

  # Predictive Analytics Handlers
  defp attach_prediction_handlers do
    events = [
      @prediction_prefix ++ [:model, :start],
      @prediction_prefix ++ [:model, :stop],
      @prediction_prefix ++ [:forecast, :generated],
      @prediction_prefix ++ [:trend, :analyzed],
      @prediction_prefix ++ [:alert, :triggered]
    ]

    :telemetry.attach_many(
      "analytics - prediction - handlers",
      events,
      &handle_prediction_event/4,
      nil
    )
  end

  # Event Handlers
  defp handle_analytics_event(event, measurements, metadata, __config) do
    case event do
      [@analytics_prefix | [:processing, :start]] ->
        Logger.info("Analytics processing started",
          analytics_type: metadata[:type],
          data_source: metadata[:source],
          trace_id: metadata[:trace_id]
        )

        Telemetry.create_span(
          "analytics.processing",
          metadata[:trace_id],
          %{
            "analytics.type" => metadata[:type],
            "analytics.source" => metadata[:source],
            "analytics.records_count" => metadata[:record_count]
          }
        )

      [@analytics_prefix | [:processing, :stop]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Logger.info("Analytics processing completed",
          analytics_type: metadata[:type],
          duration_ms: duration_ms,
          records_processed: metadata[:records_processed]
        )

        Telemetry.record_metric(
          "analytics.processing.duration",
          duration_ms,
          :histogram,
          %{
            analytics_type: metadata[:type],
            status: "success"
          }
        )

      [@analytics_prefix | [:query, :stop]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Telemetry.record_metric(
          "analytics.query.duration",
          duration_ms,
          :histogram,
          %{
            query_type: metadata[:query_type],
            data_source: metadata[:source]
          }
        )

      [@analytics_prefix | [:aggregation, :stop]] ->
        Telemetry.record_metric(
          "analytics.aggregation.rows",
          measurements[:row_count],
          :counter,
          %{
            aggregation_type: metadata[:type],
            grouping: metadata[:group_by]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_report_event(event, measurements, metadata, __config) do
    case event do
      [@report_prefix | [:generation, :start]] ->
        Logger.info("Report generation started",
          report_type: metadata[:type],
          format: metadata[:format],
          tenant_id: metadata[:tenant_id]
        )

        Telemetry.create_span(
          "analytics.report.generation",
          metadata[:trace_id],
          %{
            "report.type" => metadata[:type],
            "report.format" => metadata[:format],
            "report.scheduled" => metadata[:scheduled]
          }
        )

      [@report_prefix | [:generation, :stop]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Telemetry.record_metric(
          "analytics.report.generation_time",
          duration_ms,
          :histogram,
          %{
            report_type: metadata[:type],
            format: metadata[:format]
          }
        )

        Telemetry.record_metric(
          "analytics.report.size_bytes",
          measurements[:size_bytes],
          :histogram,
          %{report_type: metadata[:type]}
        )

      [@report_prefix | [:export, :stop]] ->
        Telemetry.record_metric(
          "analytics.report.exports",
          1,
          :counter,
          %{
            export_format: metadata[:format],
            destination: metadata[:destination]
          }
        )

      [@report_prefix | [:schedule, :executed]] ->
        Telemetry.record_metric(
          "analytics.report.scheduled_executions",
          1,
          :counter,
          %{
            schedule_type: metadata[:schedule_type],
            success: metadata[:success]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_insight_event(event, measurements, metadata, __config) do
    case event do
      [@insight_prefix | [:generation, :stop]] ->
        Telemetry.record_metric(
          "analytics.insight.generated",
          1,
          :counter,
          %{
            insight_type: metadata[:type],
            confidence: metadata[:confidence]
          }
        )

      [@insight_prefix | [:dashboard, :update]] ->
        Telemetry.record_metric(
          "analytics.dashboard.updates",
          1,
          :counter,
          %{
            dashboard_id: metadata[:dashboard_id],
            widget_count: metadata[:widget_count]
          }
        )

      [@insight_prefix | [:kpi, :calculated]] ->
        Telemetry.record_metric(
          "analytics.kpi.value",
          measurements[:value],
          :gauge,
          %{
            kpi_name: metadata[:name],
            category: metadata[:category]
          }
        )

      [@insight_prefix | [:anomaly, :detected]] ->
        Logger.warning("Analytics anomaly detected",
          anomaly_type: metadata[:type],
          severity: metadata[:severity],
          affected_metric: metadata[:metric]
        )

        Telemetry.record_metric(
          "analytics.anomalies",
          1,
          :counter,
          %{
            anomaly_type: metadata[:type],
            severity: metadata[:severity]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_prediction_event(event, measurements, metadata, __config) do
    case event do
      [@prediction_prefix | [:model, :stop]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Telemetry.record_metric(
          "analytics.prediction.model_runtime",
          duration_ms,
          :histogram,
          %{
            model_type: metadata[:model_type],
            accuracy: metadata[:accuracy]
          }
        )

      [@prediction_prefix | [:forecast, :generated]] ->
        Telemetry.record_metric(
          "analytics.forecast.generated",
          1,
          :counter,
          %{
            forecast_type: metadata[:type],
            horizon_days: metadata[:horizon_days]
          }
        )

      [@prediction_prefix | [:trend, :analyzed]] ->
        Telemetry.record_metric(
          "analytics.trend.direction",
          measurements[:slope],
          :gauge,
          %{
            metric_name: metadata[:metric],
            trend_direction: metadata[:direction]
          }
        )

      [@prediction_prefix | [:alert, :triggered]] ->
        Logger.warning("Predictive alert triggered",
          alert_type: metadata[:type],
          threshold: metadata[:threshold],
          predicted_value: measurements[:predicted_value]
        )

        Telemetry.record_metric(
          "analytics.predictive_alerts",
          1,
          :counter,
          %{
            alert_type: metadata[:type],
            severity: metadata[:severity]
          }
        )

      _ ->
        :ok
    end
  end

  @doc """
  Records analytics processing metrics.
  """
  @spec record_processing(term(), term(), term(), term()) :: term()
  def record_processing(type, source, record_count, duration_ms) do
    :telemetry.execute(
      @analytics_prefix ++ [:processing, :stop],
      %{duration: System.convert_time_unit(duration_ms, :millisecond, :native)},
      %{
        type: type,
        source: source,
        records_processed: record_count
      }
    )
  end

  @doc """
  Records report generation metrics.
  """
  @spec record_report_generation(term(), term(), term(), term()) :: term()
  def record_report_generation(type, format, size_bytes, duration_ms) do
    :telemetry.execute(
      @report_prefix ++ [:generation, :stop],
      %{
        duration: System.convert_time_unit(duration_ms, :millisecond, :native),
        size_bytes: size_bytes
      },
      %{
        type: type,
        format: format
      }
    )
  end

  @doc """
  Records business insight generation.
  """
  @spec record_insight(term(), term(), term()) :: term()
  def record_insight(type, confidence, metadata \\ %{}) do
    :telemetry.execute(
      @insight_prefix ++ [:generation, :stop],
      %{},
      Map.merge(metadata, %{
        type: type,
        confidence: confidence
      })
    )
  end

  @doc """
  Records predictive model execution.
  """
  @spec record_prediction(term(), term(), term()) :: term()
  def record_prediction(model_type, accuracy, duration_ms) do
    :telemetry.execute(
      @prediction_prefix ++ [:model, :stop],
      %{duration: System.convert_time_unit(duration_ms, :millisecond, :native)},
      %{
        model_type: model_type,
        accuracy: accuracy
      }
    )
  end

  @doc """
  Records KPI calculation.
  """
  @spec record_kpi(term(), term(), term()) :: term()
  def record_kpi(name, value, category) do
    :telemetry.execute(
      @insight_prefix ++ [:kpi, :calculated],
      %{value: value},
      %{
        name: name,
        category: category
      }
    )
  end

  @doc """
  Records detected anomaly.
  """
  @spec record_anomaly(term(), term(), term(), map()) :: term()
  def record_anomaly(type, severity, metric, details \\ %{}) do
    :telemetry.execute(
      @insight_prefix ++ [:anomaly, :detected],
      %{},
      Map.merge(details, %{
        type: type,
        severity: severity,
        metric: metric
      })
    )
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
