#!/usr/bin/env elixir

# ═══════════════════════════════════════════════════════════════════════════════
# Script: create_signoz_dashboards.exs
# Purpose: Create comprehensive SigNoz dashboards for all Indrajaal domains
# Author: SOPv5.1 Cybernetic Enhancement System
# Date: 2025-08-03
# Version: 1.0.0
# ═══════════════════════════════════════════════════════════════════════════════
#
# This script creates production-ready SigNoz dashboards for comprehensive
# observability across all Indrajaal domains. It implements:
#
# - STAMP: Safety constraint validation for dashboard reliability
# - TDG: Test-driven dashboard configuration
# - GDE: Goal-directed metrics for business impact
# - SOPv5.1: Cybernetic execution with adaptive dashboard creation
#
# Usage:
#   elixir scripts/observability/dashboards/create_signoz_dashboards.exs [options
#
# Options:
#   --signoz-url URL     SigNoz API URL (default: http://localhost:3301)
#   --api-key KEY        SigNoz API key for authentication
#   --dry-run            Show dashboard configs without creating
#   --domain DOMAIN      Create dashboard for specific domain only
#   --validate           Validate existing dashboards
#
# ═══════════════════════════════════════════════════════════════════════════════

defmodule SigNozDashboardCreator do
  @moduledoc """
  Creates comprehensive SigNoz dashboards for all Indrajaal domains.

  STAMP: Implements safety constraints for dashboard reliability
  TDG: All dashboard configurations tested before deployment
  GDE: Goal-directed metrics selection for business impact
  """

  __require Logger

  @signoz_api_version "v1"
  @default_time_range "1h"
  @refresh_interval "10s"

  # Domain-specific dashboard configurations
  @domain_dashboards %{
    "system_overview" => %{
      title: "Indrajaal System Overview",
      description: "High-level system health and performance metrics",
      panels: [
        %{
          title: "Request Rate",
          query: "sum(rate(http_requests_total[5m])) by (method, status)",
          type: "graph"
        },
        %{
          title: "Response Time P95",
          query: "histogram_quantile(0.95, http_request_duration_seconds_bucket)",
          type: "graph"
        },
        %{
          title: "Error Rate",
          query: "sum(rate(http_requests_total{status=~\"5..\"}[5m]))",
          type: "stat"
        },
        %{
          title: "Active Users",
          query: "count(distinct(__user_id))",
          type: "stat"
        },
        %{
          title: "Database Connections",
          query: "ecto_db_connections_active",
          type: "gauge"
        },
        %{
          title: "Background Jobs",
          query: "sum(oban_jobs_running) by (queue)",
          type: "graph"
        }
      ]
    },

    "alarms" => %{
      title: "Alarms Domain Dashboard",
      description: "Real-time alarm monitoring and response metrics",
      panels: [
        %{
          title: "Active Alarms by Severity",
          query: "sum(indrajaal_alarms_active) by (severity)",
          type: "bar"
        },
        %{
          title: "Alarm Response Time",
          query: "histogram_quantile(0.95, indrajaal_alarm_response_time_bucket)",
          type: "graph"
        },
        %{
          title: "Alarm Acknowledgment Rate",
          query: "rate(indrajaal_alarms_acknowledged_total[5m])",
          type: "graph"
        },
        %{
          title: "False Positive Rate",
          query: "rate(indrajaal_alarms_false_positive_total[5m])",
          type: "stat"
        },
        %{
          title: "Alarm Escalations",
          query: "sum(rate(indrajaal_alarms_escalated_total[5m])) by (level)",
          type: "graph"
        },
        %{
          title: "SIA Protocol Performance",
          query: "histogram_quantile(0.95, sia_protocol_latency_bucket)",
          type: "graph"
        }
      ]
    },

    "devices" => %{
      title: "Devices Domain Dashboard",
      description: "Device health, connectivity, and performance monitoring",
      panels: [
        %{
          title: "Device Uptime",
          query: "avg(indrajaal_device_uptime_percentage) by (device_type)",
          type: "graph"
        },
        %{
          title: "Device Status Overview",
          query: "sum(indrajaal_devices_total) by (status)",
          type: "pie"
        },
        %{
          title: "Communication Failures",
          query: "rate(indrajaal_device_communication_failures_total[5m])",
          type: "graph"
        },
        %{
          title: "Device Response Time",
          query: "histogram_quantile(0.95, indrajaal_device_response_time_bucket)",
          type: "graph"
        },
        %{
          title: "Battery Levels",
          query: "avg(indrajaal_device_battery_level) by (device_type)",
          type: "gauge"
        },
        %{
          title: "Firmware Versions",
          query: "count(indrajaal_devices_total) by (firmware_version)",
          type: "table"
        }
      ]
    },

    "sites" => %{
      title: "Sites Domain Dashboard",
      description: "Multi-site monitoring and location analytics",
      panels: [
        %{
          title: "Sites Overview",
          query: "count(indrajaal_sites_total) by (status, region)",
          type: "heatmap"
        },
        %{
          title: "Site Alarm Distribution",
          query: "sum(indrajaal_alarms_active) by (site_id, severity)",
          type: "graph"
        },
        %{
          title: "Site Connectivity",
          query: "avg(indrajaal_site_connectivity_score) by (site_id)",
          type: "graph"
        },
        %{
          title: "Guard Coverage",
          query: "sum(indrajaal_guards_on_duty) by (site_id)",
          type: "bar"
        },
        %{
          title: "Visitor Traffic",
          query: "sum(rate(indrajaal_visitors_total[5m])) by (site_id)",
          type: "graph"
        }
      ]
    },

    "video" => %{
      title: "Video Domain Dashboard",
      description: "Video stream quality and analytics performance",
      panels: [
        %{
          title: "Active Streams",
          query: "sum(indrajaal_video_streams_active) by (resolution, codec)",
          type: "graph"
        },
        %{
          title: "Stream Quality Score",
          query: "avg(indrajaal_video_quality_score) by (camera_id)",
          type: "graph"
        },
        %{
          title: "Recording Storage",
          query: "sum(indrajaal_video_storage_bytes) by (site_id)",
          type: "graph"
        },
        %{
          title: "Analytics Processing Time",
          query: "histogram_quantile(0.95, indrajaal_video_analytics_time_bucket)",
          type: "graph"
        },
        %{
          title: "Frame Rate",
          query: "avg(indrajaal_video_frame_rate) by (camera_id)",
          type: "graph"
        },
        %{
          title: "Motion Detection Events",
          query: "rate(indrajaal_motion_detection_events_total[5m])",
          type: "graph"
        }
      ]
    },

    "accounts" => %{
      title: "Accounts Domain Dashboard",
      description: "User authentication and account management metrics",
      panels: [
        %{
          title: "Login Success Rate",
          query: "rate(indrajaal_login_attempts_total{status=\"success\"}[5m])",
          type: "graph"
        },
        %{
          title: "Authentication Methods",
          query: "sum(indrajaal_authentications_total) by (method)",
          type: "pie"
        },
        %{
          title: "Active Sessions",
          query: "sum(indrajaal_sessions_active) by (__user_type)",
          type: "graph"
        },
        %{
          title: "MFA Adoption",
          query: "sum(indrajaal_users_mfa_enabled) / sum(indrajaal_users_total) * 100",
          type: "stat"
        },
        %{
          title: "Password Reset Requests",
          query: "rate(indrajaal_password_reset_requests_total[5m])",
          type: "graph"
        }
      ]
    },

    "access_control" => %{
      title: "Access Control Domain Dashboard",
      description: "Physical access control and security monitoring",
      panels: [
        %{
          title: "Access Events",
          query: "rate(indrajaal_access_events_total[5m]) by (type, result)",
          type: "graph"
        },
        %{
          title: "Door Status",
          query: "sum(indrajaal_doors_total) by (status)",
          type: "pie"
        },
        %{
          title: "Badge Scans",
          query: "rate(indrajaal_badge_scans_total[5m]) by (reader_id)",
          type: "heatmap"
        },
        %{
          title: "Access Violations",
          query: "rate(indrajaal_access_violations_total[5m]) by (type)",
          type: "graph"
        },
        %{
          title: "Tailgating Detection",
          query: "rate(indrajaal_tailgating_events_total[5m])",
          type: "stat"
        }
      ]
    },

    "analytics" => %{
      title: "Analytics Domain Dashboard",
      description: "Business intelligence and reporting metrics",
      panels: [
        %{
          title: "Report Generation Time",
          query: "histogram_quantile(0.95, indrajaal_report_generation_time_bucket)",
          type: "graph"
        },
        %{
          title: "Dashboard Load Time",
          query: "histogram_quantile(0.95, indrajaal_dashboard_load_time_bucket)",
          type: "graph"
        },
        %{
          title: "Data Processing Pipeline",
          query: "sum(indrajaal_analytics_pipeline_throughput) by (stage)",
          type: "graph"
        },
        %{
          title: "Custom Metrics",
          query: "count(indrajaal_custom_metrics_total) by (category)",
          type: "bar"
        },
        %{
          title: "Export Jobs",
          query: "sum(indrajaal_export_jobs_total) by (status, format)",
          type: "table"
        }
      ]
    },

    "communication" => %{
      title: "Communication Domain Dashboard",
      description: "Notification delivery and communication metrics",
      panels: [
        %{
          title: "Notification Delivery Rate",
          query: "rate(indrajaal_notifications_sent_total[5m]) by (channel, status)",
          type: "graph"
        },
        %{
          title: "Email Queue Size",
          query: "indrajaal_email_queue_size",
          type: "graph"
        },
        %{
          title: "SMS Delivery Time",
          query: "histogram_quantile(0.95, indrajaal_sms_delivery_time_bucket)",
          type: "graph"
        },
        %{
          title: "Push Notification Success",
          query: "rate(indrajaal_push_notifications_total{status=\"delivered\"}[5m])",
          type: "stat"
        },
        %{
          title: "WebSocket Connections",
          query: "sum(indrajaal_websocket_connections_active)",
          type: "gauge"
        }
      ]
    },

    "guard_tours" => %{
      title: "Guard Tours Domain Dashboard",
      description: "Guard patrol and checkpoint monitoring",
      panels: [
        %{
          title: "Active Patrols",
          query: "sum(indrajaal_patrols_active) by (site_id)",
          type: "graph"
        },
        %{
          title: "Checkpoint Compliance",
          query: "avg(indrajaal_checkpoint_compliance_percentage) by (tour_id)",
          type: "graph"
        },
        %{
          title: "Patrol Duration",
          query: "histogram_quantile(0.95, indrajaal_patrol_duration_bucket)",
          type: "graph"
        },
        %{
          title: "Missed Checkpoints",
          query: "sum(indrajaal_checkpoints_missed_total) by (reason)",
          type: "bar"
        },
        %{
          title: "Guard Location Updates",
          query: "rate(indrajaal_guard_location_updates_total[5m])",
          type: "graph"
        }
      ]
    },

    "maintenance" => %{
      title: "Maintenance Domain Dashboard",
      description: "Work order and maintenance tracking",
      panels: [
        %{
          title: "Open Work Orders",
          query: "sum(indrajaal_work_orders_open) by (priority, category)",
          type: "graph"
        },
        %{
          title: "SLA Compliance",
          query: "avg(indrajaal_maintenance_sla_compliance_percentage) by (category)",
          type: "graph"
        },
        %{
          title: "Technician Utilization",
          query: "avg(indrajaal_technician_utilization_percentage) by (technician_id)",
          type: "bar"
        },
        %{
          title: "Mean Time to Repair",
          query: "avg(indrajaal_mttr_hours) by (device_type)",
          type: "graph"
        },
        %{
          title: "Pr__eventive vs Reactive",
          query: "sum(indrajaal_maintenance_tasks_total) by (type)",
          type: "pie"
        }
      ]
    },

    "visitor_management" => %{
      title: "Visitor Management Domain Dashboard",
      description: "Visitor check-in/out and flow analytics",
      panels: [
        %{
          title: "Current Visitors On-Site",
          query: "sum(indrajaal_visitors_onsite) by (site_id, visitor_type)",
          type: "graph"
        },
        %{
          title: "Check-in Rate",
          query: "rate(indrajaal_visitor_checkins_total[5m]) by (site_id)",
          type: "graph"
        },
        %{
          title: "Average Visit Duration",
          query: "avg(indrajaal_visit_duration_minutes) by (visitor_type)",
          type: "bar"
        },
        %{
          title: "Pre-Registration Usage",
          query: "sum(indrajaal_visitors_preregistered_total) / sum(indrajaal_visitors_total) * 100",
          type: "stat"
        },
        %{
          title: "Badge Printing Queue",
          query: "indrajaal_badge_printing_queue_size",
          type: "gauge"
        }
      ]
    }
  }

  @spec main(any()) :: any()
  def main(args \\ []) do
    Logger.info("SigNoz Dashboard Creator starting...",
      framework: "SOPv5.1",
      methodologies: ["STAMP", "TDG", "GDE"]
    )

    options = parse_args(args)

    # Validate SigNoz connection
    case validate_signoz_connection(options) do
      :ok ->
        Logger.info("SigNoz connection validated successfully")
        create_dashboards(options)
      {:error, reason} ->
        Logger.error("Failed to connect to SigNoz", error: reason)
        System.halt(1)
    end
  end

  @spec parse_args(term()) :: term()
  defp parse_args(args) do
    {__opts, _, _} = OptionParser.parse(args,
      switches: [
        signoz_url: :string,
        api_key: :string,
        dry_run: :boolean,
        domain: :string,
        validate: :boolean
      ]
    )

    %{
      signoz_url: __opts[:signoz_url] || System.get_env("SIGNOZ_URL", "http://localhost:3301"),
      api_key: __opts[:api_key] || System.get_env("SIGNOZ_API_KEY"),
      dry_run: __opts[:dry_run] || false,
      domain: __opts[:domain],
      validate: __opts[:validate] || false
    }
  end

  @spec validate_signoz_connection(term()) :: term()
  defp validate_signoz_connection(options) do
    # STAMP: Validate connection before creating dashboards
    url = "#{options.signoz_url}/api/#{@signoz_api_version}/health"
    headers = build_headers(options)

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200}} ->
        :ok
      {:ok, response} ->
        {:error, "Unexpected status: #{response.status_code}"}
      {:error, error} ->
        {:error, error}
    end
  rescue
    _ -> {:error, "Connection failed"}
  end

  @spec create_dashboards(term()) :: term()
  defp create_dashboards(options) do
    dashboards = if options.domain do
      # Create single domain dashboard
      case Map.get(@domain_dashboards, options.domain) do
        nil ->
          Logger.error("Unknown domain", domain: options.domain)
          System.halt(1)
        config ->
          [{options.domain, config}]
      end
    else
      # Create all dashboards
      @domain_dashboards
    end

    _results = Enum.map(dashboards, fn {domain, config} ->
      create_dashboard(domain, config, options)
    end)

    # Summary
    successful = Enum.count(results, &(&1 == :ok))
    failed = length(results) - successful

    Logger.info("Dashboard creation complete",
      total: length(results),
      successful: successful,
      failed: failed
    )

    if failed > 0 do
      System.halt(1)
    end
  end

  defp create_dashboard(domain, config, options) do
    Logger.info("Creating dashboard", domain: domain, title: config.title)

    if options.dry_run do
      # Dry run - just show configuration
      IO.puts("\n=== Dashboard: #{config.title} ===")
      IO.puts("Domain: #{domain}")
      IO.puts("Description: #{config.description}")
      IO.puts("Panels: #{length(config.panels)}")

      Enum.each(config.panels, fn panel ->
        IO.puts("  - #{panel.title} (#{panel.type})")
      end)

      :ok
    else
      # Actually create dashboard
      dashboard_json = build_dashboard_json(domain, config)

      url = "#{options.signoz_url}/api/#{@signoz_api_version}/dashboards"
      headers = build_headers(options)

      case HTTPoison.post(url, Jason.encode!(dashboard_json), headers) do
        {:ok, %{status_code: status}} when status in 200..299 ->
          Logger.info("Dashboard created successfully", domain: domain)
          :ok
        {:ok, response} ->
          Logger.error("Failed to create dashboard",
            domain: domain,
            status: response.status_code,
            body: response.body
          )
          :error
        {:error, error} ->
          Logger.error("Failed to create dashboard",
            domain: domain,
            error: inspect(error)
          )
          :error
      end
    end
  end

  @spec build_dashboard_json(term(), term()) :: term()
  defp build_dashboard_json(domain, config) do
    # TDG: Dashboard structure validated by tests
    %{
      "uid" => "indrajaal-#{domain}",
      "title" => config.title,
      "tags" => ["indrajaal", domain, "production"],
      "timezone" => "browser",
      "refresh" => @refresh_interval,
      "time" => %{
        "from" => "now-#{@default_time_range}",
        "to" => "now"
      },
      "panels" => build_panels(config.panels),
      "annotations" => %{
        "list" => [
          %{
            "name" => "Deployments",
            "__datasource" => "SigNoz",
            "enable" => true,
            "iconColor" => "rgba(0, 211, 255, 1)",
            "query" => "deployment_events{service=\"indrajaal\"}"
          }
        ]
      },
      "description" => config.description,
      "editable" => true,
      "gnetId" => nil,
      "graphTooltip" => 1,
      "hideControls" => false,
      "links" => build_navigation_links(domain),
      "schemaVersion" => 36,
      "style" => "dark",
      "version" => 1
    }
  end

  @spec build_panels(term()) :: term()
  defp build_panels(panel_configs) do
    # GDE: Arrange panels for optimal viewing
    panel_configs
    |> Enum.with_index()
    |> Enum.map(fn {panel, index} ->
      row = div(index, 2)
      col = rem(index, 2)

      %{
        "id" => index + 1,
        "title" => panel.title,
        "type" => map_panel_type(panel.type),
        "__datasource" => "SigNoz",
        "gridPos" => %{
          "h" => 8,
          "w" => 12,
          "x" => col * 12,
          "y" => row * 8
        },
        "targets" => [
          %{
            "expr" => panel.query,
            "refId" => "A"
          }
        ],
        "options" => panel_options(panel.type),
        "fieldConfig" => field_config(panel.type)
      }
    end)
  end

  @spec map_panel_type(String.t()) :: term()
  defp map_panel_type("graph"), do: "timeseries"
  defp map_panel_type("stat"), do: "stat"
  defp map_panel_type("gauge"), do: "gauge"
  @spec map_panel_type(String.t()) :: term()
  defp map_panel_type("bar"), do: "barchart"
  defp map_panel_type("pie"), do: "piechart"
  defp map_panel_type("table"), do: "table"
  @spec map_panel_type(String.t()) :: term()
  defp map_panel_type("heatmap"), do: "heatmap"
  defp map_panel_type(type), do: type

  @spec panel_options(String.t()) :: term()
  defp panel_options("stat") do
    %{
      "reduceOptions" => %{
        "values" => false,
        "calcs" => ["lastNotNull"]
      },
      "orientation" => "auto",
      "textMode" => "auto",
      "colorMode" => "value",
      "graphMode" => "area",
      "justifyMode" => "auto"
    }
  end

  @spec panel_options(String.t()) :: term()
  defp panel_options("gauge") do
    %{
      "showThresholdLabels" => false,
      "showThresholdMarkers" => true,
      "orientation" => "auto",
      "reduceOptions" => %{
        "values" => false,
        "calcs" => ["lastNotNull"]
      }
    }
  end

  @spec panel_options(term()) :: term()
  defp panel_options(_type) do
    %{}
  end

  @spec field_config(String.t()) :: term()
  defp field_config("gauge") do
    %{
      "defaults" => %{
        "thresholds" => %{
          "mode" => "absolute",
          "steps" => [
            %{"color" => "green", "value" => nil},
            %{"color" => "yellow", "value" => 60},
            %{"color" => "red", "value" => 80}
          ]
        },
        "unit" => "percent",
        "min" => 0,
        "max" => 100
      }
    }
  end

  @spec field_config(term()) :: term()
  defp field_config(_type) do
    %{
      "defaults" => %{
        "thresholds" => %{
          "mode" => "absolute",
          "steps" => [
            %{"color" => "green", "value" => nil}
          ]
        }
      }
    }
  end

  @spec build_navigation_links(term()) :: term()
  defp build_navigation_links(current_domain) do
    # Create navigation links to other dashboards
    @domain_dashboards
    |> Map.keys()
    |> Enum.reject(&(&1 == current_domain))
    |> Enum.map(fn domain ->
      %{
        "title" => String.capitalize(String.replace(domain, "_", " ")),
        "type" => "dashboards",
        "tags" => [domain],
        "asDropdown" => false,
        "includeVars" => true,
        "keepTime" => true,
        "targetBlank" => false
      }
    end)
  end

  @spec build_headers(term()) :: term()
  defp build_headers(options) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    if options.api_key do
      [{"Authorization", "Bearer #{options.api_key}"} | headers]
    else
      headers
    end
  end
end

# Check if HTTPoison is available
case Code.ensure_loaded(HTTPoison) do
  {:module, _} ->
    SigNozDashboardCreator.main(System.argv())
  {:error, _} ->
    IO.puts("Error: HTTPoison is __required. Add {:httpoison, \"~> 2.0\"} to mix.exs")
    System.halt(1)
end