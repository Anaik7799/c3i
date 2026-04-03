defmodule Indrajaal.Observability.Domains.SitesInstrumentation do
  @moduledoc """
  Domain - specific instrumentation for site operations and hierarchy tracking.

  Provides comprehensive telemetry for:
  - Site status and operational metrics
  - Location hierarchy and zone management
  - Site - level aggregated alarms and events
  - Occupancy and capacity tracking

  - Multi - site coordination and performance
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :sites

  # EP-012: Tracing alias removed (unused)
  alias Indrajaal.Observability.Logging

  # EP-013: Site states and zone types (unused but kept for future reference)
  # @site_states ~w(operational limited_operation maintenance closed emergency)a  # Reserved for future site state validation
  # @zone_types ~w(perimeter interior restricted public emergency)a  # Reserved for future zone type classification

  # Telemetry events
  @site_status [:sites, :site, :status]
  @site_alarm_summary [:sites, :alarms, :summary]
  @site_occupancy [:sites, :occupancy, :update]
  @site_zone_event [:sites, :zone, :event]
  @site_hierarchy [:sites, :hierarchy, :change]
  @site_performance [:sites, :performance, :metrics]
  @site_coordination [:sites, :coordination, :event]

  @doc """
  Sets up telemetry handlers for the Sites domain.
  """
  def setup do
    :telemetry.execute(
      [:indrajaal, :observability, :sites, :setup],
      %{timestamp: System.system_time(:millisecond)},
      %{module: __MODULE__}
    )

    :ok
  end

  @doc """
  Handles a telemetry event for the Sites domain.
  """
  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :sites, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  @doc """
  Returns current metrics for the Sites domain.
  """
  def get_metrics do
    {:ok, %{status: :active, domain: :sites}}
  end

  @doc """
  Records a named metric for the Sites domain.
  """
  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :sites, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  @doc """
  Configures the Sites domain instrumentation.
  """
  def configure(_opts) do
    :ok
  end

  @doc """
  Returns the current configuration for the Sites domain.
  """
  def get_configuration do
    {:ok,
     [
       domain: :sites,
       site_status_events: @site_status,
       alarm_summary_events: @site_alarm_summary,
       occupancy_events: @site_occupancy,
       zone_events: @site_zone_event,
       hierarchy_events: @site_hierarchy,
       performance_events: @site_performance,
       coordination_events: @site_coordination
     ]}
  end

  @doc """
  Shuts down the Sites domain instrumentation.
  """
  def shutdown do
    :ok
  end

  @doc """
  Instruments site status changes with comprehensive telemetry.
  """
  def instrumentstatus_change(site, old_status, new_status, metadata \\ %{}) do
    _start_time = System.monotonic_time()

    span_ctx =
      Tracing.start_span("sites.status_change", %{
        attributes: %{
          "site.id" => site.id,
          "site.name" => site.name,
          "status.from" => old_status,
          "status.to" => new_status,
          "site.level" => site.hierarchy_level,
          "tenant.id" => site.tenant_id
        }
      })

    try do
      # Execute telemetry event
      :telemetry.execute(
        @site_status,
        %{
          count: 1,
          affected_devices: count_affected_devices(site),
          affected_zones: count_affected_zones(site)
        },
        Map.merge(metadata, %{
          site_id: site.id,
          site_name: site.name,
          old_status: old_status,
          new_status: new_status,
          hierarchy_level: site.hierarchy_level,
          parent_site_id: site.parent_site_id,
          tenant_id: site.tenant_id
        })
      )

      # Log status change with impact analysis
      log_level = determine_site_log_level(old_status, new_status)

      Logging.log(log_level, "Site status changed", %{
        domain: "sites",
        action: "status_change",
        site_id: site.id,
        site_name: site.name,
        old_status: old_status,
        new_status: new_status,
        impact: calculate_status_impact(site, new_status)
      })

      # Propagate status to child sites if needed
      if should_propagate_status?(old_status, new_status) do
        propagate_status_to_children(site, new_status)
      end

      # Alert on critical site status
      if new_status == :emergency do
        trigger_site_emergency_protocol(site, metadata)
      end

      {:ok, site}
    rescue
      error ->
        Tracing.record_error(span_ctx, error)
        {:error, error}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments site alarm summary updates.
  """
  @spec instrument_alarm_summary(term(), term(), term()) :: term()
  def instrument_alarm_summary(site, alarm_summary, metadata \\ %{}) do
    span_ctx =
      Tracing.start_span("sites.alarm_summary", %{
        attributes: %{
          "site.id" => site.id,
          "alarms.total" => alarm_summary.total_count,
          "alarms.critical" => alarm_summary.critical_count,
          "alarms.unacknowledged" => alarm_summary.unacknowledged_count
        }
      })

    try do
      :telemetry.execute(
        @site_alarm_summary,
        %{
          total_alarms: alarm_summary.total_count,
          critical_alarms: alarm_summary.critical_count,
          high_alarms: alarm_summary.high_count,
          medium_alarms: alarm_summary.medium_count,
          low_alarms: alarm_summary.low_count,
          unacknowledged_alarms: alarm_summary.unacknowledged_count
        },
        Map.merge(metadata, %{
          site_id: site.id,
          site_name: site.name,
          summary_timestamp: DateTime.utc_now()
        })
      )

      # Track alarm density and patterns
      track_alarm_patterns(site, alarm_summary)

      # Alert on threshold breaches
      check_alarm_thresholds(site, alarm_summary)

      {:ok, alarm_summary}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments site occupancy updates.
  """
  @spec instrument_occupancy_update(term(), term(), term()) :: term()
  def instrument_occupancy_update(site, occupancy_data, metadata \\ %{}) do
    occupancy_percentage = calculate_occupancy_percentage(occupancy_data)

    span_ctx =
      Tracing.start_span("sites.occupancy_update", %{
        attributes: %{
          "site.id" => site.id,
          "occupancy.current" => occupancy_data.current_count,
          "occupancy.capacity" => occupancy_data.capacity,
          "occupancy.percentage" => occupancy_percentage
        }
      })

    try do
      :telemetry.execute(
        @site_occupancy,
        %{
          current_count: occupancy_data.current_count,
          capacity: occupancy_data.capacity,
          occupancy_percentage: occupancy_percentage,
          visitors: occupancy_data.visitor_count || 0,
          staff: occupancy_data.staff_count || 0,
          contractors: occupancy_data.contractor_count || 0
        },
        Map.merge(metadata, %{
          site_id: site.id,
          site_name: site.name,
          zone_id: occupancy_data[:zone_id],
          update_source: occupancy_data[:source]
        })
      )

      # Check occupancy limits
      if occupancy_percentage > 90 do
        trigger_occupancy_alert(site, occupancy_data, :high_occupancy)
      end

      # Track occupancy trends
      track_occupancy_trends(site, occupancy_data)

      {:ok, occupancy_data}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments zone - specific events within a site.
  """
  @spec instrument_zone_event(term(), term(), term(), map()) :: term()
  def instrument_zone_event(site, zone, event_type, metadata \\ %{}) do
    span_ctx =
      Tracing.start_span("sites.zone_event", %{
        attributes: %{
          "site.id" => site.id,
          "zone.id" => zone.id,
          "zone.type" => zone.type,
          "event.type" => event_type
        }
      })

    try do
      :telemetry.execute(
        @site_zone_event,
        %{
          count: 1,
          zone_device_count: zone.device_count || 0
        },
        Map.merge(metadata, %{
          site_id: site.id,
          zone_id: zone.id,
          zone_name: zone.name,
          zone_type: zone.type,
          event_type: event_type,
          timestamp: DateTime.utc_now()
        })
      )

      # Log zone events based on type
      log_zone_event(site, zone, event_type, metadata)

      # Process zone - specific logic
      process_zone_event(site, zone, event_type, metadata)

      {:ok, zone}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments site hierarchy changes.
  """
  @spec instrument_hierarchy_change(term(), term(), term()) :: term()
  def instrument_hierarchy_change(site, change_type, metadata \\ %{}) do
    span_ctx =
      Tracing.start_span("sites.hierarchy_change", %{
        attributes: %{
          "site.id" => site.id,
          "change.type" => change_type,
          "hierarchy.level" => site.hierarchy_level,
          "parent.id" => site.parent_site_id
        }
      })

    try do
      affected_sites = calculate_affected_sites(site, change_type)

      :telemetry.execute(
        @site_hierarchy,
        %{
          count: 1,
          affected_sites: length(affected_sites),
          hierarchy_depth: calculate_hierarchy_depth(site)
        },
        Map.merge(metadata, %{
          site_id: site.id,
          change_type: change_type,
          affected_site_ids: affected_sites,
          new_parent_id: metadata[:new_parent_id],
          old_parent_id: metadata[:old_parent_id]
        })
      )

      Logging.info("Site hierarchy changed", %{
        domain: "sites",
        action: "hierarchy_change",
        site_id: site.id,
        change_type: change_type,
        affected_sites: length(affected_sites)
      })

      # Recalculate aggregated metrics for affected sites
      recalculate_hierarchy_metrics(affected_sites)

      {:ok, site}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments site performance metrics.
  """
  @spec instrument_performance_metrics(term(), term(), term()) :: term()
  def instrument_performance_metrics(site, metrics, metadata \\ %{}) do
    span_ctx =
      Tracing.start_span("sites.performance_metrics", %{
        attributes: %{
          "site.id" => site.id,
          "metrics.period" => metadata[:period],
          "metrics.type" => metadata[:metric_type]
        }
      })

    try do
      :telemetry.execute(
        @site_performance,
        Map.merge(metrics, %{
          site_efficiency_score: calculate_efficiency_score(metrics),
          site_health_score: calculate_site_health_score(metrics)
        }),
        Map.merge(metadata, %{
          site_id: site.id,
          site_name: site.name,
          measurement_period: metadata[:period],
          timestamp: DateTime.utc_now()
        })
      )

      # Track performance trends
      track_performance_trends(site, metrics)

      # Generate performance insights
      generate_performance_insights(site, metrics)

      {:ok, metrics}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments multi - site coordination events.
  """
  @spec instrument_coordination_event(term(), term(), term()) :: term()
  def instrument_coordination_event(sites, event_type, metadata \\ %{}) do
    site_ids = Enum.map(sites, & &1.id)

    span_ctx =
      Tracing.start_span("sites.coordination_event", %{
        attributes: %{
          "event.type" => event_type,
          "sites.count" => length(sites),
          "coordination.scope" => metadata[:scope]
        }
      })

    try do
      :telemetry.execute(
        @site_coordination,
        %{
          site_count: length(sites),
          coordination_latency_ms: metadata[:latency] || 0
        },
        Map.merge(metadata, %{
          site_ids: site_ids,
          event_type: event_type,
          coordination_id: metadata[:coordination_id],
          timestamp: DateTime.utc_now()
        })
      )

      Logging.info("Multi - site coordination event", %{
        domain: "sites",
        action: "coordination",
        event_type: event_type,
        site_count: length(sites),
        scope: metadata[:scope]
      })

      {:ok, sites}
    after
      Tracing.end_span(span_ctx)
    end
  end

  # Private functions

  @spec count_affected_devices(term()) :: term()
  defp count_affected_devices(site) do
    # Count devices under this site and its children
    site.device_count || 0
  end

  @spec count_affected_zones(term()) :: term()
  defp count_affected_zones(site) do
    # Count zones under this site
    site.zone_count || 0
  end

  @spec determine_site_log_level(term(), term()) :: term()
  defp determine_site_log_level(:operational, :emergency), do: :error
  defp determine_site_log_level(_, :emergency), do: :error
  defp determine_site_log_level(:operational, :closed), do: :warning
  @spec determine_site_log_level(term(), term()) :: term()
  defp determine_site_log_level(_, _), do: :info

  defp calculate_status_impact(site, new_status) do
    %{
      affected_devices: count_affected_devices(site),
      affected_zones: count_affected_zones(site),
      affected_users: site.active_user_count || 0,
      severity: status_severity(new_status)
    }
  end

  @spec status_severity(term()) :: term()
  defp status_severity(:emergency), do: :critical
  defp status_severity(:closed), do: :high
  defp status_severity(:maintenance), do: :medium
  @spec status_severity(term()) :: term()
  defp status_severity(:limited_operation), do: :medium
  defp status_severity(:operational), do: :low

  @spec should_propagate_status?(term(), term()) :: term()
  defp should_propagate_status?(
         :operational,
         status
       )
       when status != :operational,
       do: true

  defp should_propagate_status?(_, :emergency), do: true
  defp should_propagate_status?(_, _), do: false

  @spec propagate_status_to_children(term(), term()) :: term()
  defp propagate_status_to_children(site, new_status) do
    # Propagate status to child sites
    # This would typically trigger status changes for child sites
    :telemetry.execute(
      [:sites, :status, :propagated],
      %{
        child_count: site.child_site_count || 0
      },
      %{
        parent_site_id: site.id,
        new_status: new_status
      }
    )
  end

  @spec trigger_site_emergency_protocol(term(), term()) :: term()
  defp trigger_site_emergency_protocol(site, metadata) do
    Logging.error("Site emergency protocol activated", %{
      domain: "sites",
      action: "emergency_protocol",
      site_id: site.id,
      site_name: site.name,
      reason: metadata[:reason],
      activated_by: metadata[:user_id]
    })

    # Trigger emergency notifications
    :telemetry.execute([:sites, :emergency, :activated], %{count: 1}, %{
      site_id: site.id,
      site_name: site.name
    })
  end

  @spec track_alarm_patterns(term(), term()) :: term()
  defp track_alarm_patterns(site, alarm_summary) do
    # Calculate alarm density (alarms per device)
    alarm_density =
      if site.device_count > 0 do
        alarm_summary.total_count / site.device_count
      else
        0.0
      end

    :telemetry.execute(
      [:sites, :alarms, :patterns],
      %{
        alarm_density: alarm_density,
        critical_ratio:
          safe_ratio(
            alarm_summary.critical_count,
            alarm_summary.total_count
          ),
        acknowledgment_ratio:
          safe_ratio(
            alarm_summary.total_count - alarm_summary.unacknowledged_count,
            alarm_summary.total_count
          )
      },
      %{
        site_id: site.id
      }
    )
  end

  @spec check_alarm_thresholds(term(), term()) :: term()
  defp check_alarm_thresholds(site, alarm_summary) do
    thresholds = site.alarm_thresholds || default_alarm_thresholds()

    if alarm_summary.critical_count > thresholds.critical_max do
      trigger_threshold_alert(site, :critical_alarms_exceeded, alarm_summary)
    end

    if alarm_summary.unacknowledged_count > thresholds.unacknowledged_max do
      trigger_threshold_alert(site, :unacknowledged_alarms_exceeded, alarm_summary)
    end
  end

  @spec default_alarm_thresholds() :: any()
  def default_alarm_thresholds() do
    %{
      critical_max: 5,
      unacknowledged_max: 10,
      total_max: 50
    }
  end

  defp trigger_threshold_alert(site, alert_type, alarm_summary) do
    Logging.warning("Alarm threshold exceeded", %{
      domain: "sites",
      action: "threshold_alert",
      site_id: site.id,
      alert_type: alert_type,
      alarm_summary: alarm_summary
    })
  end

  @spec calculate_occupancy_percentage(term()) :: term()
  defp calculate_occupancy_percentage(occupancy_data) do
    if occupancy_data.capacity > 0 do
      occupancy_data.current_count / occupancy_data.capacity * 100
    else
      0.0
    end
  end

  defp trigger_occupancy_alert(site, occupancy_data, alert_type) do
    Logging.warning("Occupancy alert triggered", %{
      domain: "sites",
      action: "occupancy_alert",
      site_id: site.id,
      alert_type: alert_type,
      current_count: occupancy_data.current_count,
      capacity: occupancy_data.capacity
    })
  end

  @spec track_occupancy_trends(term(), term()) :: term()
  defp track_occupancy_trends(site, _occupancy_data) do
    # Track hourly, daily, weekly trends
    trend_data = %{
      hourly_average: calculate_occupancy_average(site.id, :hour),
      daily_peak: calculate_occupancy_peak(site.id, :day),
      weekly_pattern: analyze_weekly_pattern(site.id)
    }

    :telemetry.execute([:sites, :occupancy, :trends], trend_data, %{
      site_id: site.id
    })
  end

  defp log_zone_event(site, zone, event_type, metadata) do
    log_level =
      case event_type do
        :intrusion_detected -> :warning
        :access_granted -> :info
        :emergency_activated -> :error
        _ -> :info
      end

    Logging.log(log_level, "Zone event occurred", %{
      domain: "sites",
      action: "zone_event",
      site_id: site.id,
      zone_id: zone.id,
      event_type: event_type,
      metadata: metadata
    })
  end

  defp process_zone_event(site, zone, :intrusion_detected, metadata) do
    # Create alarm for intrusion
    :telemetry.execute([:sites, :zone, :intrusion], %{count: 1}, %{
      site_id: site.id,
      zone_id: zone.id,
      sensor_id: metadata[:sensor_id]
    })
  end

  defp process_zone_event(site, zone, :emergencyactivated, metadata) do
    # Activate emergency protocols for zone
    :telemetry.execute([:sites, :zone, :emergency], %{count: 1}, %{
      site_id: site.id,
      zone_id: zone.id,
      activated_by: metadata[:user_id]
    })
  end

  defp process_zone_event(_, _, _, _), do: :ok

  @spec calculate_affected_sites(term(), term()) :: term()
  defp calculate_affected_sites(site, change_type) do
    case change_type do
      :parent_changed -> [site.id | get_child_site_ids(site)]
      :children_added -> [site.id]
      :children_removed -> [site.id]
      _ -> [site.id]
    end
  end

  @spec get_child_site_ids(term()) :: term()
  defp get_child_site_ids(site) do
    # Return list of child site IDs
    site.child_site_ids || []
  end

  @spec calculate_hierarchy_depth(term()) :: term()
  defp calculate_hierarchy_depth(site) do
    # Calculate depth in hierarchy tree
    site.hierarchy_level || 0
  end

  @spec recalculate_hierarchy_metrics(term()) :: term()
  defp recalculate_hierarchy_metrics(site_ids) do
    # Trigger metric recalculation for affected sites
    :telemetry.execute(
      [:sites, :hierarchy, :recalculate],
      %{
        site_count: length(site_ids)
      },
      %{
        site_ids: site_ids,
        timestamp: DateTime.utc_now()
      }
    )
  end

  @spec calculate_efficiency_score(term()) :: term()
  defp calculate_efficiency_score(metrics) do
    # Calculate overall site efficiency based on metrics
    scores = [
      metrics[:alarm_response_efficiency] || 0.5,
      metrics[:device_availability] || 0.5,
      metrics[:occupancy_efficiency] || 0.5
    ]

    Enum.sum(scores) / length(scores) * 100
  end

  @spec calculate_site_health_score(term()) :: term()
  defp calculate_site_health_score(metrics) do
    # Calculate site health score
    factors = %{
      device_health: metrics[:average_device_health] || 50,
      alarm_load: 100 - min(metrics[:alarm_density] || 0, 100),
      response_time: 100 - min(metrics[:average_response_time] || 0, 100)
    }

    Enum.sum(Map.values(factors)) / map_size(factors)
  end

  @spec track_performance_trends(term(), term()) :: term()
  defp track_performance_trends(site, metrics) do
    # Store and analyze performance trends
    :telemetry.execute(
      [:sites, :performance, :trends],
      %{
        efficiency_trend: calculate_trend(site.id, :efficiency, metrics[:efficiency_score]),
        health_trend: calculate_trend(site.id, :health, metrics[:health_score])
      },
      %{
        site_id: site.id
      }
    )
  end

  @spec generate_performance_insights(term(), term()) :: term()
  defp generate_performance_insights(site, metrics) do
    insights = []

    insights =
      if metrics[:alarm_density] > 10 do
        ["High alarm density detected" | insights]
      else
        insights
      end

    # 5 minutes
    insights =
      if metrics[:average_response_time] > 300_000 do
        ["Slow alarm response times" | insights]
      else
        insights
      end

    unless Enum.empty?(insights) do
      Logging.info("Site performance insights generated", %{
        domain: "sites",
        action: "insights",
        site_id: site.id,
        insights: insights
      })
    end
  end

  @spec safe_ratio(term(), term()) :: term()
  defp safe_ratio(numerator, denominator) when denominator > 0 do
    numerator / denominator
  end

  @spec safe_ratio(term(), term()) :: term()
  defp safe_ratio(_, _), do: 0.0

  defp calculate_occupancy_average(_site_id, _period) do
    # Calculate average occupancy for period
    # This is a placeholder
    50.0
  end

  @spec calculate_occupancy_peak(term(), term()) :: term()
  defp calculate_occupancy_peak(_site_id, _period) do
    # Calculate peak occupancy for period
    # This is a placeholder
    75.0
  end

  @spec analyze_weekly_pattern(term()) :: term()
  defp analyze_weekly_pattern(_site_id) do
    # Analyze weekly occupancy patterns
    # This is a placeholder
    %{
      busiest_day: :wednesday,
      peak_hour: 14
    }
  end

  defp calculate_trend(_site_id, _metric_type, _current_value) do
    # Calculate trend based on historical data
    # This is a placeholder
    0.0
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
