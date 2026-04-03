defmodule Indrajaal.Observability.Domains.GuardToursInstrumentation do
  @moduledoc """
  require Logger
  Instrumentation for the Guard Tours domain.

  Provides comprehensive telemetry,
    metrics, and tracing for guard tour operations,
  checkpoint scanning, GPS tracking, route compliance, and tour reporting.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :guard_tours

  # EP-012: Aliases not explicitly used but available through InstrumentationBase

  # Telemetry __event prefixes
  @tour_prefix [:indrajaal, :guard_tours, :tour]
  @checkpoint_prefix [:indrajaal, :guard_tours, :checkpoint]
  @tracking_prefix [:indrajaal, :guard_tours, :tracking]
  @compliance_prefix [:indrajaal, :guard_tours, :compliance]

  @doc """
  Attaches all guard tours telemetry handlers.
  """
  def setup do
    attach_tour_handlers()
    attach_checkpoint_handlers()
    attach_tracking_handlers()
    attach_compliance_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :guard_tours, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :guard_tours}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :guard_tours, :metric],
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
       domain: :guard_tours,
       tour_event_prefix: @tour_prefix,
       checkpoint_event_prefix: @checkpoint_prefix,
       tracking_event_prefix: @tracking_prefix,
       compliance_event_prefix: @compliance_prefix
     ]}
  end

  def shutdown do
    :ok
  end

  # Tour Management Handlers
  defp attach_tour_handlers do
    events = [
      @tour_prefix ++ [:start],
      @tour_prefix ++ [:complete],
      @tour_prefix ++ [:abandon],
      @tour_prefix ++ [:pause],
      @tour_prefix ++ [:resume],
      @tour_prefix ++ [:exception]
    ]

    :telemetry.attach_many(
      "guard - tours - tour - handlers",
      events,
      &handle_tour_event/4,
      nil
    )
  end

  # Checkpoint Scanning Handlers
  defp attach_checkpoint_handlers do
    events = [
      @checkpoint_prefix ++ [:scan, :start],
      @checkpoint_prefix ++ [:scan, :stop],
      @checkpoint_prefix ++ [:scan, :failed],
      @checkpoint_prefix ++ [:validation, :passed],
      @checkpoint_prefix ++ [:validation, :failed],
      @checkpoint_prefix ++ [:skip, :recorded]
    ]

    :telemetry.attach_many(
      "guard - tours - checkpoint - handlers",
      events,
      &handle_checkpoint_event/4,
      nil
    )
  end

  # GPS Tracking Handlers
  defp attach_tracking_handlers do
    events = [
      @tracking_prefix ++ [:location, :updated],
      @tracking_prefix ++ [:location, :lost],
      @tracking_prefix ++ [:geofence, :entered],
      @tracking_prefix ++ [:geofence, :exited],
      @tracking_prefix ++ [:route, :deviation]
    ]

    :telemetry.attach_many(
      "guard - tours - tracking - handlers",
      events,
      &handle_tracking_event/4,
      nil
    )
  end

  # Compliance and Reporting Handlers
  defp attach_compliance_handlers do
    events = [
      @compliance_prefix ++ [:violation, :detected],
      @compliance_prefix ++ [:report, :generated],
      @compliance_prefix ++ [:audit, :performed],
      @compliance_prefix ++ [:sla, :checked]
    ]

    :telemetry.attach_many(
      "guard - tours - compliance - handlers",
      events,
      &handle_compliance_event/4,
      nil
    )
  end

  # Event Handlers
  defp handle_tour_event(event, measurements, metadata, __config) do
    case event do
      [@tour_prefix | [:start]] ->
        Logger.info("Guard tour started",
          tour_id: metadata[:tour_id],
          guard_id: metadata[:guard_id],
          route_id: metadata[:route_id],
          checkpoint_count: metadata[:checkpoint_count],
          trace_id: metadata[:trace_id]
        )

        Telemetry.create_span(
          "guard_tours.tour",
          metadata[:trace_id],
          %{
            "tour.id" => metadata[:tour_id],
            "tour.route_id" => metadata[:route_id],
            "tour.guard_id" => metadata[:guard_id],
            "tour.checkpoint_count" => metadata[:checkpoint_count],
            "tour.scheduled" => metadata[:scheduled]
          }
        )

        Telemetry.record_metric(
          "guard_tours.active_tours",
          1,
          :gauge,
          %{route_id: metadata[:route_id]}
        )

      [@tour_prefix | [:complete]] ->
        duration_ms = measurements[:duration_ms]

        Logger.info("Guard tour completed",
          tour_id: metadata[:tour_id],
          duration_ms: duration_ms,
          checkpoints_scanned: metadata[:checkpoints_scanned],
          checkpoints_total: metadata[:checkpoints_total]
        )

        Telemetry.record_metric(
          "guard_tours.tour.duration",
          duration_ms,
          :histogram,
          %{
            route_id: metadata[:route_id],
            completion_rate: metadata[:checkpoints_scanned] / metadata[:checkpoints_total]
          }
        )

        Telemetry.record_metric(
          "guard_tours.tour.completed",
          1,
          :counter,
          %{route_id: metadata[:route_id]}
        )

      [@tour_prefix | [:abandon]] ->
        Logger.warning("Guard tour abandoned",
          tour_id: metadata[:tour_id],
          reason: metadata[:reason],
          progress_percent: metadata[:progress_percent]
        )

        Telemetry.record_metric(
          "guard_tours.tour.abandoned",
          1,
          :counter,
          %{
            route_id: metadata[:route_id],
            reason: metadata[:reason]
          }
        )

      [@tour_prefix | [:pause]] ->
        Telemetry.record_metric(
          "guard_tours.tour.paused",
          1,
          :counter,
          %{
            tour_id: metadata[:tour_id],
            pause_reason: metadata[:reason]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_checkpoint_event(event, measurements, metadata, __config) do
    case event do
      [@checkpoint_prefix | [:scan, :stop]] ->
        scan_time = measurements[:scan_time_ms]

        Logger.info("Checkpoint scanned",
          checkpoint_id: metadata[:checkpoint_id],
          tour_id: metadata[:tour_id],
          scan_method: metadata[:scan_method],
          scan_time_ms: scan_time
        )

        Telemetry.record_metric(
          "guard_tours.checkpoint.scan_time",
          scan_time,
          :histogram,
          %{
            scan_method: metadata[:scan_method],
            checkpoint_type: metadata[:checkpoint_type]
          }
        )

        Telemetry.record_metric(
          "guard_tours.checkpoint.scanned",
          1,
          :counter,
          %{checkpoint_id: metadata[:checkpoint_id]}
        )

      [@checkpoint_prefix | [:scan, :failed]] ->
        Logger.error("Checkpoint scan failed",
          checkpoint_id: metadata[:checkpoint_id],
          error: metadata[:error],
          scan_method: metadata[:scan_method]
        )

        Telemetry.record_metric(
          "guard_tours.checkpoint.scan_failures",
          1,
          :counter,
          %{
            error_type: metadata[:error_type],
            scan_method: metadata[:scan_method]
          }
        )

      [@checkpoint_prefix | [:validation, :failed]] ->
        Logger.warning("Checkpoint validation failed",
          checkpoint_id: metadata[:checkpoint_id],
          validation_type: metadata[:validation_type],
          reason: metadata[:reason]
        )

        Telemetry.record_metric(
          "guard_tours.checkpoint.validation_failures",
          1,
          :counter,
          %{
            validation_type: metadata[:validation_type],
            failure_reason: metadata[:reason]
          }
        )

      [@checkpoint_prefix | [:skip, :recorded]] ->
        Telemetry.record_metric(
          "guard_tours.checkpoint.skipped",
          1,
          :counter,
          %{
            skip_reason: metadata[:reason],
            authorized: metadata[:authorized]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_tracking_event(event, measurements, metadata, __config) do
    case event do
      [@tracking_prefix | [:location, :updated]] ->
        accuracy = measurements[:accuracy_meters]

        Telemetry.record_metric(
          "guard_tours.gps.accuracy",
          accuracy,
          :histogram,
          %{
            guard_id: metadata[:guard_id],
            location_source: metadata[:source]
          }
        )

        if measurements[:speed_kmh] do
          Telemetry.record_metric(
            "guard_tours.movement.speed",
            measurements[:speed_kmh],
            :gauge,
            %{guard_id: metadata[:guard_id]}
          )
        end

      [@tracking_prefix | [:location, :lost]] ->
        Logger.warning("GPS signal lost",
          guard_id: metadata[:guard_id],
          last_known_location: metadata[:last_location],
          duration_lost_seconds: measurements[:duration_seconds]
        )

        Telemetry.record_metric(
          "guard_tours.gps.signal_lost",
          1,
          :counter,
          %{guard_id: metadata[:guard_id]}
        )

      [@tracking_prefix | [:geofence, :entered]] ->
        Telemetry.record_metric(
          "guard_tours.geofence.entries",
          1,
          :counter,
          %{
            geofence_id: metadata[:geofence_id],
            geofence_type: metadata[:geofence_type]
          }
        )

      [@tracking_prefix | [:route, :deviation]] ->
        deviation_meters = measurements[:deviation_meters]

        Logger.warning("Route deviation detected",
          tour_id: metadata[:tour_id],
          guard_id: metadata[:guard_id],
          deviation_meters: deviation_meters
        )

        Telemetry.record_metric(
          "guard_tours.route.deviation",
          deviation_meters,
          :histogram,
          %{
            tour_id: metadata[:tour_id],
            severity: classify_deviation_severity(deviation_meters)
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_compliance_event(event, measurements, metadata, __config) do
    case event do
      [@compliance_prefix | [:violation, :detected]] ->
        Logger.warning("Compliance violation detected",
          violation_type: metadata[:type],
          tour_id: metadata[:tour_id],
          severity: metadata[:severity],
          details: metadata[:details]
        )

        Telemetry.record_metric(
          "guard_tours.compliance.violations",
          1,
          :counter,
          %{
            violation_type: metadata[:type],
            severity: metadata[:severity]
          }
        )

      [@compliance_prefix | [:report, :generated]] ->
        Telemetry.record_metric(
          "guard_tours.reports.generated",
          1,
          :counter,
          %{
            report_type: metadata[:report_type],
            period: metadata[:period]
          }
        )

        if measurements[:generation_time_ms] do
          Telemetry.record_metric(
            "guard_tours.reports.generation_time",
            measurements[:generation_time_ms],
            :histogram,
            %{report_type: metadata[:report_type]}
          )
        end

      [@compliance_prefix | [:sla, :checked]] ->
        sla_met = metadata[:sla_met]

        Telemetry.record_metric(
          "guard_tours.sla.compliance_rate",
          if(sla_met, do: 100, else: 0),
          :gauge,
          %{
            sla_type: metadata[:sla_type],
            client_id: metadata[:client_id]
          }
        )

      _ ->
        :ok
    end
  end

  @doc """
  Records tour lifecycle __events.
  """
  @spec record_tour_event(term(), term(), term()) :: term()
  def record_tour_event(tour_id, event_type, metadata \\ %{}) do
    base_metadata = Map.merge(metadata, %{tour_id: tour_id})

    case event_type do
      :start ->
        :telemetry.execute(
          @tour_prefix ++ [:start],
          %{},
          base_metadata
        )

      :complete ->
        :telemetry.execute(
          @tour_prefix ++ [:complete],
          %{duration_ms: metadata[:duration_ms]},
          base_metadata
        )

      _ ->
        :telemetry.execute(
          @tour_prefix ++ [event_type],
          %{},
          base_metadata
        )
    end
  end

  @doc """
  Records checkpoint scanning metrics.
  """
  @spec record_checkpoint_scan(binary() | integer(), binary() | integer(), term(), term(), term()) ::
          term()
  def record_checkpoint_scan(checkpoint_id, tour_id, scan_time_ms, scan_method, success) do
    event = if success, do: :stop, else: :failed

    :telemetry.execute(
      @checkpoint_prefix ++ [:scan, event],
      %{scan_time_ms: scan_time_ms},
      %{
        checkpoint_id: checkpoint_id,
        tour_id: tour_id,
        scan_method: scan_method
      }
    )
  end

  @doc """
  Records GPS tracking updates.
  """
  @spec record_location_update(term(), term(), term()) :: term()
  def record_location_update(guard_id, accuracy_meters, speed_kmh \\ nil) do
    :telemetry.execute(
      @tracking_prefix ++ [:location, :updated],
      %{
        accuracy_meters: accuracy_meters,
        speed_kmh: speed_kmh
      },
      %{
        guard_id: guard_id,
        source: "gps"
      }
    )
  end

  @doc """
  Records compliance violations.
  """
  @spec record_compliance_violation(term(), term(), term(), term()) :: term()
  def record_compliance_violation(type, tour_id, severity, details) do
    :telemetry.execute(
      @compliance_prefix ++ [:violation, :detected],
      %{},
      %{
        type: type,
        tour_id: tour_id,
        severity: severity,
        details: details
      }
    )
  end

  @spec classify_deviation_severity(term()) :: term()
  defp classify_deviation_severity(meters) when meters < 50, do: "minor"
  defp classify_deviation_severity(meters) when meters < 200, do: "moderate"
  defp classify_deviation_severity(_), do: "severe"
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
