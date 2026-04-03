defmodule Indrajaal.Observability.Domains.VisitorManagementInstrumentation do
  @moduledoc """
  require Logger
  Instrumentation for the Visitor Management domain.

  Provides comprehensive telemetry,
    metrics, and tracing for visitor registration,
  check - in / check - out processes, badge management, and visitor analytics.
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :visitor_management

  # EP-012: Aliases not explicitly used but available through InstrumentationBase

  # Telemetry event prefixes
  @visitor_prefix [:indrajaal, :visitor_management, :visitor]
  @badge_prefix [:indrajaal, :visitor_management, :badge]
  @access_prefix [:indrajaal, :visitor_management, :access]
  @compliance_prefix [:indrajaal, :visitor_management, :compliance]

  @doc """
  Attaches all visitor management telemetry handlers.
  """
  def setup do
    attach_visitor_handlers()
    attach_badge_handlers()
    attach_access_handlers()
    attach_compliance_handlers()
    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :visitor_management, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :visitor_management}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :visitor_management, :metric],
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
       domain: :visitor_management,
       visitor_event_prefix: @visitor_prefix,
       badge_event_prefix: @badge_prefix,
       access_event_prefix: @access_prefix,
       compliance_event_prefix: @compliance_prefix
     ]}
  end

  def shutdown do
    :ok
  end

  # Visitor Registration and Check - in Handlers
  defp attach_visitor_handlers do
    events = [
      @visitor_prefix ++ [:registration, :start],
      @visitor_prefix ++ [:registration, :complete],
      @visitor_prefix ++ [:registration, :failed],
      @visitor_prefix ++ [:checkin, :start],
      @visitor_prefix ++ [:checkin, :complete],
      @visitor_prefix ++ [:checkout, :complete],
      @visitor_prefix ++ [:overstay, :detected]
    ]

    :telemetry.attach_many(
      "visitor - management - visitor - handlers",
      events,
      &handle_visitor_event/4,
      nil
    )
  end

  # Badge Management Handlers
  defp attach_badge_handlers do
    events = [
      @badge_prefix ++ [:issued],
      @badge_prefix ++ [:activated],
      @badge_prefix ++ [:deactivated],
      @badge_prefix ++ [:returned],
      @badge_prefix ++ [:lost],
      @badge_prefix ++ [:print, :completed],
      @badge_prefix ++ [:print, :failed]
    ]

    :telemetry.attach_many(
      "visitor - management - badge - handlers",
      events,
      &handle_badge_event/4,
      nil
    )
  end

  # Access Control Handlers
  defp attach_access_handlers do
    events = [
      @access_prefix ++ [:granted],
      @access_prefix ++ [:denied],
      @access_prefix ++ [:violation],
      @access_prefix ++ [:escort, :required],
      @access_prefix ++ [:zone, :entered],
      @access_prefix ++ [:zone, :exited]
    ]

    :telemetry.attach_many(
      "visitor - management - access - handlers",
      events,
      &handle_access_event/4,
      nil
    )
  end

  # Compliance and Security Handlers
  defp attach_compliance_handlers do
    events = [
      @compliance_prefix ++ [:screening, :completed],
      @compliance_prefix ++ [:screening, :flagged],
      @compliance_prefix ++ [:watchlist, :hit],
      @compliance_prefix ++ [:document, :verified],
      @compliance_prefix ++ [:agreement, :signed],
      @compliance_prefix ++ [:audit, :logged]
    ]

    :telemetry.attach_many(
      "visitor - management - compliance - handlers",
      events,
      &handle_compliance_event/4,
      nil
    )
  end

  # Event Handlers
  defp handle_visitor_event(event, measurements, metadata, _config) do
    case event do
      [@visitor_prefix | [:registration, :start]] ->
        Logger.info("Visitor registration started",
          visitor_type: metadata[:visitor_type],
          pre_registered: metadata[:pre_registered],
          host_id: metadata[:host_id],
          trace_id: metadata[:trace_id]
        )

        Telemetry.create_span(
          "visitor_management.registration",
          metadata[:trace_id],
          %{
            "visitor.type" => metadata[:visitor_type],
            "visitor.pre_registered" => metadata[:pre_registered],
            "visitor.host_id" => metadata[:host_id],
            "visitor.purpose" => metadata[:purpose]
          }
        )

      [@visitor_prefix | [:registration, :complete]] ->
        duration_ms = System.convert_time_unit(measurements[:duration], :native, :millisecond)

        Logger.info("Visitor registration completed",
          visitor_id: metadata[:visitor_id],
          duration_ms: duration_ms,
          badge_issued: metadata[:badge_issued]
        )

        Telemetry.record_metric(
          "visitor_management.registration.duration",
          duration_ms,
          :histogram,
          %{
            visitor_type: metadata[:visitor_type],
            pre_registered: metadata[:pre_registered]
          }
        )

        Telemetry.record_metric(
          "visitor_management.registrations",
          1,
          :counter,
          %{visitor_type: metadata[:visitor_type]}
        )

      [@visitor_prefix | [:checkin, :complete]] ->
        wait_time_ms = measurements[:wait_time_ms]

        Telemetry.record_metric(
          "visitor_management.checkin.wait_time",
          wait_time_ms,
          :histogram,
          %{
            location: metadata[:location],
            visitor_type: metadata[:visitor_type]
          }
        )

        Telemetry.record_metric(
          "visitor_management.active_visitors",
          1,
          :gauge,
          %{location: metadata[:location]}
        )

      [@visitor_prefix | [:checkout, :complete]] ->
        visit_duration_hours = measurements[:visit_duration_hours]

        Telemetry.record_metric(
          "visitor_management.visit.duration",
          visit_duration_hours,
          :histogram,
          %{
            visitor_type: metadata[:visitor_type],
            purpose: metadata[:purpose]
          }
        )

        Telemetry.record_metric(
          "visitor_management.active_visitors",
          -1,
          :gauge,
          %{location: metadata[:location]}
        )

      [@visitor_prefix | [:overstay, :detected]] ->
        overstay_hours = measurements[:overstay_hours]

        Logger.warning("Visitor overstay detected",
          visitor_id: metadata[:visitor_id],
          overstay_hours: overstay_hours,
          scheduled_checkout: metadata[:scheduled_checkout]
        )

        Telemetry.record_metric(
          "visitor_management.overstays",
          1,
          :counter,
          %{
            severity: classify_overstay_severity(overstay_hours),
            visitor_type: metadata[:visitor_type]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_badge_event(event, measurements, metadata, _config) do
    case event do
      [@badge_prefix | [:issued]] ->
        Logger.info("Visitor badge issued",
          badge_id: metadata[:badge_id],
          visitor_id: metadata[:visitor_id],
          badge_type: metadata[:badge_type]
        )

        Telemetry.record_metric(
          "visitor_management.badges.issued",
          1,
          :counter,
          %{
            badge_type: metadata[:badge_type],
            validity_hours: metadata[:validity_hours]
          }
        )

      [@badge_prefix | [:lost]] ->
        Logger.warning("Visitor badge reported lost",
          badge_id: metadata[:badge_id],
          visitor_id: metadata[:visitor_id]
        )

        Telemetry.record_metric(
          "visitor_management.badges.lost",
          1,
          :counter,
          %{badge_type: metadata[:badge_type]}
        )

      [@badge_prefix | [:print, :completed]] ->
        print_time_ms = measurements[:print_time_ms]

        Telemetry.record_metric(
          "visitor_management.badge.print_time",
          print_time_ms,
          :histogram,
          %{
            printer_id: metadata[:printer_id],
            badge_template: metadata[:template]
          }
        )

      [@badge_prefix | [:print, :failed]] ->
        Logger.error("Badge print failed",
          badge_id: metadata[:badge_id],
          printer_id: metadata[:printer_id],
          error: metadata[:error]
        )

        Telemetry.record_metric(
          "visitor_management.badge.print_failures",
          1,
          :counter,
          %{
            printer_id: metadata[:printer_id],
            error_type: metadata[:error_type]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_access_event(event, _measurements, metadata, _config) do
    case event do
      [@access_prefix | [:granted]] ->
        Telemetry.record_metric(
          "visitor_management.access.granted",
          1,
          :counter,
          %{
            zone: metadata[:zone],
            visitor_type: metadata[:visitor_type]
          }
        )

      [@access_prefix | [:denied]] ->
        Logger.warning("Visitor access denied",
          visitor_id: metadata[:visitor_id],
          zone: metadata[:zone],
          reason: metadata[:reason]
        )

        Telemetry.record_metric(
          "visitor_management.access.denied",
          1,
          :counter,
          %{
            zone: metadata[:zone],
            denial_reason: metadata[:reason]
          }
        )

      [@access_prefix | [:violation]] ->
        Logger.error("Visitor access violation",
          visitor_id: metadata[:visitor_id],
          violation_type: metadata[:violation_type],
          zone: metadata[:zone]
        )

        Telemetry.record_metric(
          "visitor_management.access.violations",
          1,
          :counter,
          %{
            violation_type: metadata[:violation_type],
            zone: metadata[:zone]
          }
        )

      [@access_prefix | [:zone, :entered]] ->
        Telemetry.record_metric(
          "visitor_management.zone.occupancy",
          1,
          :gauge,
          %{
            zone: metadata[:zone],
            zone_type: metadata[:zone_type]
          }
        )

      _ ->
        :ok
    end
  end

  defp handle_compliance_event(event, measurements, metadata, _config) do
    case event do
      [@compliance_prefix | [:screening, :completed]] ->
        screening_time = measurements[:screening_time_ms]

        Telemetry.record_metric(
          "visitor_management.screening.duration",
          screening_time,
          :histogram,
          %{
            screening_type: metadata[:screening_type],
            result: metadata[:result]
          }
        )

      [@compliance_prefix | [:screening, :flagged]] ->
        Logger.warning("Visitor screening flagged",
          visitor_id: metadata[:visitor_id],
          flag_type: metadata[:flag_type],
          severity: metadata[:severity]
        )

        Telemetry.record_metric(
          "visitor_management.screening.flags",
          1,
          :counter,
          %{
            flag_type: metadata[:flag_type],
            severity: metadata[:severity]
          }
        )

      [@compliance_prefix | [:watchlist, :hit]] ->
        Logger.error("Visitor watchlist hit",
          visitor_id: metadata[:visitor_id],
          watchlist_type: metadata[:watchlist_type],
          match_confidence: metadata[:match_confidence]
        )

        Telemetry.record_metric(
          "visitor_management.watchlist.hits",
          1,
          :counter,
          %{
            watchlist_type: metadata[:watchlist_type],
            action_taken: metadata[:action_taken]
          }
        )

      [@compliance_prefix | [:document, :verified]] ->
        verification_time = measurements[:verification_time_ms]

        Telemetry.record_metric(
          "visitor_management.document.verification_time",
          verification_time,
          :histogram,
          %{
            document_type: metadata[:document_type],
            verification_method: metadata[:method]
          }
        )

      _ ->
        :ok
    end
  end

  @doc """
  Records visitor registration metrics.
  """
  @spec record_registration(term(), term(), term(), term()) :: term()
  def record_registration(visitor_type, duration_ms, pre_registered, success) do
    event = if success, do: :complete, else: :failed

    :telemetry.execute(
      @visitor_prefix ++ [:registration, event],
      %{duration: System.convert_time_unit(duration_ms, :millisecond, :native)},
      %{
        visitor_type: visitor_type,
        pre_registered: pre_registered
      }
    )
  end

  @doc """
  Records visitor check-in/check-out events.
  """
  @spec record_visitor_movement(term(), term(), term(), map()) :: term()
  def record_visitor_movement(visitor_id, event_type, location, metadata \\ %{}) do
    measurements =
      case event_type do
        :checkin ->
          %{wait_time_ms: metadata[:wait_time_ms] || 0}

        :checkout ->
          %{
            visit_duration_hours:
              metadata[:visit_duration_hours] ||
                0
          }

        _ ->
          %{}
      end

    :telemetry.execute(
      @visitor_prefix ++ [event_type, :complete],
      measurements,
      Map.merge(metadata, %{
        visitor_id: visitor_id,
        location: location
      })
    )
  end

  @doc """
  Records badge management events.
  """
  def record_badge_event(badge_id, visitor_id, event_type, metadata \\ %{}) do
    :telemetry.execute(
      @badge_prefix ++ [event_type],
      %{},
      Map.merge(metadata, %{
        badge_id: badge_id,
        visitor_id: visitor_id
      })
    )
  end

  @doc """
  Records access control decisions.
  """
  @spec record_access_decision(term(), term(), term(), map()) :: term()
  def record_access_decision(visitor_id, decision, zone, metadata \\ %{}) do
    :telemetry.execute(
      @access_prefix ++ [decision],
      %{},
      Map.merge(metadata, %{
        visitor_id: visitor_id,
        zone: zone
      })
    )
  end

  @doc """
  Records compliance and screening results.
  """
  @spec record_compliance_check(term(), term(), term(), map()) :: term()
  def record_compliance_check(visitor_id, result, check_type, metadata \\ %{}) do
    event =
      case result do
        :pass -> :completed
        :fail -> :flagged
        :hit -> :hit
        _ -> :completed
      end

    :telemetry.execute(
      @compliance_prefix ++ [check_type, event],
      %{},
      Map.merge(metadata, %{
        visitor_id: visitor_id,
        result: result
      })
    )
  end

  @spec classify_overstay_severity(term()) :: term()
  defp classify_overstay_severity(hours) when hours < 1, do: "minor"
  defp classify_overstay_severity(hours) when hours < 4, do: "moderate"
  defp classify_overstay_severity(_), do: "severe"
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
