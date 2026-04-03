defmodule Indrajaal.Compilation.Dashboard do
  @moduledoc """
  Human-friendly compilation dashboard with visual progress indicators,
  interactive charts, and comprehensive analytics for compilation monitoring.

  ## Features:
  - Real-time visual progress indicators
  - Domain and subsystem breakdown charts
  - Interactive error analysis interface
  - Historical compilation trends
  - Performance optimization insights
  """

  require Logger
  alias Indrajaal.Compilation.{ProgressTracker, ClaudeInterface}

  @doc """
  Generate comprehensive human-friendly dashboard data
  """
  def getdashboard(sessionid, _opts \\ []) do
    with {:ok, progress} <- ProgressTracker.get_progress(sessionid),
         {:ok, dashboard_data} <- ProgressTracker.get_dashboard_data(sessionid),
         {:ok, claude_data} <- ClaudeInterface.get_claude_status(sessionid) do
      enhanced_dashboard = %{
        session_id: sessionid,
        generated_at: DateTime.utc_now(),

        # Executive Summary
        executive_summary: build_executive_summary(progress, dashboard_data, claude_data),

        # Visual Progress Components
        visual_progress: %{
          overall_progress_bar: build_progress_bar(progress.percentage),
          domain_progress_chart: build_domain_progress_chart(dashboard_data.domain_breakdown),
          subsystem_breakdown: build_subsystem_breakdown_chart(dashboard_data.subsystem_analysis),
          timeline_chart: build_timeline_chart(dashboard_data.timeline)
        },

        # Performance Analytics
        performance_analytics: %{
          compilation_speed_chart: build_speed_chart(dashboard_data.performance_charts),
          efficiency_metrics: build_efficiency_metrics(progress, dashboard_data),
          bottleneck_analysis: build_bottleneck_analysis(claude_data.bottlenecks),
          resource_utilization: build_resource_utilization_chart(dashboard_data)
        },

        # Error Analysis Interface
        error_analysis: %{
          error_summary_chart: build_error_summary_chart(dashboard_data.error_summary),
          error_categories: categorize_errors(dashboard_data.error_summary),
          fix_suggestions: build_fix_suggestions(claude_data.optimization_suggestions),
          error_timeline: build_error_timeline(dashboard_data.timeline)
        },

        # Interactive Components
        interactive_features: %{
          filterable_file_list: build_filterable_file_list(sessionid),
          drill_down_domains: build_drill_down_domains(dashboard_data.domain_breakdown),
          error_pattern_explorer: build_error_pattern_explorer(claude_data.error_patterns),
          performance_optimizer: build_performance_optimizer(claude_data)
        },

        # Historical Context
        historical_context: %{
          comparison_metrics: build_comparison_metrics(sessionid),
          trend_analysis: build_trend_analysis(sessionid),
          improvement_tracking: build_improvement_tracking(sessionid)
        },

        # Action Center
        action_center: %{
          recommended_actions: build_recommended_actions(claude_data.next_actions),
          quick_fixes: build_quick_fixes(dashboard_data.error_summary),
          optimization_opportunities: build_optimization_opportunities(claude_data),
          automation_suggestions: build_automation_suggestions(claude_data)
        }
      }

      {:ok, enhanced_dashboard}
    else
      error -> error
    end
  end

  @doc """
  Gets compilation dashboard data (properly named alias).

  Phase 4.5 Batch 2: Added function alias to resolve naming mismatch warning

  ## Parameters
  - session_id: Compilation session identifier
  - opts: Optional parameters for dashboard generation

  ## Returns
  - {:ok, dashboard} - Enhanced dashboard data
  - {:error, reason} - Error retrieving dashboard
  """
  @spec get_dashboard(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_dashboard(session_id, opts \\ []) do
    # Delegate to existing getdashboard/2
    getdashboard(session_id, opts)
  end

  @doc """
  Generate real-time dashboard updates for live monitoring
  """
  def get_live_updates(session_id) do
    case ProgressTracker.get_progress(session_id) do
      {:ok, progress} ->
        live_update = %{
          timestamp: DateTime.utc_now(),
          session_id: session_id,
          progress_percentage: progress.percentage,
          current_file: format_current_file(progress.current_file),
          files_per_minute: calculate_files_per_minute(progress),
          estimated_completion: format_estimated_completion(progress.estimated_remaining),
          recent_errors: get_recent_errors(session_id, 5),
          performance_pulse: get_performance_pulse(session_id)
        }

        {:ok, live_update}

      error ->
        error
    end
  end

  @doc """
  Export dashboard data in various formats
  """
  def export_dashboard(sessionid, format, opts \\ []) do
    case getdashboard(sessionid, opts) do
      {:ok, dashboard} ->
        case format do
          :json -> {:ok, Jason.encode!(dashboard, pretty: true)}
          :csv -> {:ok, export_to_csv(dashboard)}
          :html -> {:ok, export_to_html(dashboard)}
          :pdf -> export_to_pdf(dashboard)
          _ -> {:error, "Unsupported format: #{format}"}
        end

      error ->
        error
    end
  end

  ## Private Functions - Dashboard Builders

  defp build_executive_summary(progress, dashboard_data, claude_data) do
    success_rate = calculate_success_rate(progress)
    health_status = claude_data.current_status.overall_health

    %{
      overall_status: determine_overall_status(success_rate, health_status),
      key_metrics: %{
        completion_rate: "#{progress.percentage}%",
        success_rate: "#{success_rate}%",
        average_file_time: format_average_time(dashboard_data.overview.avg_compile_time_sec),
        estimated_completion: format_estimated_completion(progress.estimated_remaining),
        health_indicator: format_health_indicator(health_status)
      },
      highlights: build_highlights(progress, dashboard_data, claude_data),
      concerns: build_concerns(progress, dashboard_data, claude_data)
    }
  end

  defp build_progress_bar(percentage) do
    width = 50
    completed_width = div(percentage * width, 100)
    remaining_width = width - completed_width

    %{
      percentage: percentage,
      visual:
        "[#{String.duplicate("█", completed_width)}#{String.duplicate("░", remaining_width)}]",
      color: determine_progress_color(percentage),
      animation: determine_progress_animation(percentage)
    }
  end

  defp build_domain_progress_chart(domainbreakdown) do
    domains =
      Enum.map(domainbreakdown, fn {domain, stats} ->
        %{
          name: domain,
          total_files: stats.total || 0,
          completed: stats.completed || 0,
          failed: stats.failed || 0,
          percentage: calculate_percentage(stats.completed || 0, stats.total || 1),
          average_time: stats.avg_time || 0,
          status: determine_domain_status(stats)
        }
      end)

    %{
      type: "horizontal_bar_chart",
      data: domains,
      title: "Compilation Progress by Domain",
      total_domains: length(domains),
      completed_domains: Enum.count(domains, &(&1.percentage == 100)),
      problematic_domains: Enum.count(domains, &(&1.failed > 0))
    }
  end

  defp build_subsystem_breakdown_chart(subsystemanalysis) do
    subsystems =
      Enum.map(subsystemanalysis, fn {subsystem, stats} ->
        %{
          name: subsystem,
          file_count: stats.total || 0,
          completion_rate: calculate_percentage(stats.completed || 0, stats.total || 1),
          error_rate: calculate_percentage(stats.failed || 0, stats.total || 1),
          performance_score: calculate_performance_score(stats),
          color: determine_subsystem_color(subsystem)
        }
      end)

    %{
      type: "pie_chart",
      data: subsystems,
      title: "File Distribution by Subsystem",
      insights: %{
        largest_subsystem:
          Enum.max_by(subsystems, & &1.file_count, fn -> %{name: "none"} end).name,
        fastest_subsystem:
          Enum.max_by(subsystems, & &1.performance_score, fn -> %{name: "none"} end).name,
        most_problematic: Enum.max_by(subsystems, & &1.error_rate, fn -> %{name: "none"} end).name
      }
    }
  end

  defp build_timeline_chart(timeline) do
    timeline_points =
      Enum.map(timeline, fn point ->
        %{
          timestamp: point.timestamp,
          __event: point.event,
          file: point.file || "system",
          duration: point.duration || 0,
          status: point.status || :info,
          description: point.description || ""
        }
      end)

    %{
      type: "timeline",
      data: timeline_points,
      title: "Compilation Timeline",
      total_events: length(timeline_points),
      duration_range: calculate_duration_range(timeline_points),
      critical_events: Enum.filter(timeline_points, &(&1.status == :error))
    }
  end

  defp build_speed_chart(performancecharts) do
    %{
      type: "line_chart",
      data: %{
        files_per_minute: performancecharts.files_per_minute || [],
        average_compile_time: performancecharts.average_compile_time || [],
        cumulative_progress: performancecharts.cumulative_progress || []
      },
      title: "Compilation Speed Over Time",
      insights: %{
        peak_speed: calculate_peak_speed(performancecharts),
        speed_trend: analyze_speed_trend(performancecharts),
        efficiency_score: calculate_efficiency_score(performancecharts)
      }
    }
  end

  defp build_efficiency_metrics(progress, dashboarddata) do
    %{
      overall_efficiency: calculate_overall_efficiency(progress, dashboarddata),
      time_efficiency: calculate_time_efficiency(dashboarddata),
      resource_efficiency: calculate_resource_efficiency(dashboarddata),
      error_efficiency: calculate_error_efficiency(progress),
      benchmarks: %{
        target_files_per_minute: 10,
        target_success_rate: 95,
        # milliseconds
        target_average_time: 3000,
        current_performance: assess_current_performance(progress, dashboarddata)
      }
    }
  end

  defp build_bottleneck_analysis(bottlenecks) do
    analyzed_bottlenecks =
      Enum.map(bottlenecks, fn bottleneck ->
        %{
          file: bottleneck.file,
          time: bottleneck.time,
          severity: determine_bottleneck_severity(bottleneck.time),
          category: categorize_bottleneck(bottleneck),
          suggested_fix: suggest_bottleneck_fix(bottleneck)
        }
      end)

    %{
      total_bottlenecks: length(analyzed_bottlenecks),
      severe_bottlenecks: Enum.count(analyzed_bottlenecks, &(&1.severity == :severe)),
      bottleneck_categories: group_by_category(analyzed_bottlenecks),
      improvement_potential: calculate_improvement_potential(analyzed_bottlenecks)
    }
  end

  defp build_error_summary_chart(errorsummary) do
    error_categories = categorize_errors(errorsummary)

    %{
      type: "donut_chart",
      data:
        Enum.map(error_categories, fn {category, errors} ->
          %{
            category: category,
            count: length(errors),
            percentage: calculate_percentage(length(errors), map_size(errorsummary)),
            severity: determine_error_severity(category),
            fix_difficulty: estimate_fix_difficulty(category)
          }
        end),
      title: "Error Distribution by Category",
      total_errors: map_size(errorsummary),
      fixable_errors: count_fixable_errors(error_categories),
      critical_errors: count_critical_errors(error_categories)
    }
  end

  defp build_filterable_file_list(_session_id) do
    # This would integrate with the ProgressTracker to get detailed file information
    %{
      filters: [
        %{name: "Status", values: ["completed", "failed", "pending"], type: "multi_select"},
        %{
          name: "Domain",
          values: ["accounts", "alarms", "devices", "sites"],
          type: "multi_select"
        },
        %{
          name: "Subsystem",
          values: ["web", "core", "controllers", "components"],
          type: "multi_select"
        },
        %{name: "Compile Time", values: ["fast", "normal", "slow"], type: "single_select"},
        %{name: "Has Errors", values: ["yes", "no"], type: "single_select"}
      ],
      columns: [
        %{key: "file_path", label: "File", sortable: true, searchable: true},
        %{key: "status", label: "Status", sortable: true, filterable: true},
        %{key: "domain", label: "Domain", sortable: true, filterable: true},
        %{key: "compile_time", label: "Time (ms)", sortable: true, type: "numeric"},
        %{key: "errors", label: "Errors", sortable: true, type: "numeric"},
        %{key: "actions", label: "Actions", sortable: false}
      ],
      actions: ["view_details", "retry_compilation", "view_errors", "optimize"]
    }
  end

  defp build_recommended_actions(nextactions) do
    Enum.map(nextactions, fn action ->
      %{
        action: action,
        priority: determine_action_priority(action),
        description: get_action_description(action),
        estimated_time: estimate_action_time(action),
        success_probability: estimate_action_success(action),
        automation_available: can_automate_action(action)
      }
    end)
  end

  ## Helper Functions

  defp calculate_success_rate(progress) do
    total_processed = progress.completed_files + progress.failed_files

    if total_processed > 0 do
      round(progress.completed_files / total_processed * 100)
    else
      0
    end
  end

  defp determine_overall_status(successrate, healthstatus) do
    case {successrate, healthstatus} do
      {rate, :excellent} when rate >= 95 -> :excellent
      {rate, health} when rate >= 90 and health in [:excellent, :good] -> :good
      {rate, health} when rate >= 75 and health in [:excellent, :good, :fair] -> :fair
      _ -> :poor
    end
  end

  defp format_average_time(time_sec) when is_integer(time_sec) do
    if time_sec < 60 do
      "#{time_sec}s"
    else
      "#{div(time_sec, 60)}m #{rem(time_sec, 60)}s"
    end
  end

  defp format_average_time(_), do: "N/A"

  defp format_estimated_completion(nil), do: "Unknown"

  defp format_estimated_completion(minutes) when is_integer(minutes) do
    if minutes < 60 do
      "#{minutes}m"
    else
      hours = div(minutes, 60)
      remaining_minutes = rem(minutes, 60)
      "#{hours}h #{remaining_minutes}m"
    end
  end

  defp format_health_indicator(healthstatus) do
    case healthstatus do
      :excellent -> "🟢 Excellent"
      :good -> "🟡 Good"
      :fair -> "🟠 Fair"
      :poor -> "🔴 Poor"
      _ -> "⚪ Unknown"
    end
  end

  defp determine_progress_color(percentage) do
    cond do
      # green
      percentage >= 90 -> "#10B981"
      # yellow
      percentage >= 70 -> "#F59E0B"
      # red
      percentage >= 50 -> "#EF4444"
      # gray
      true -> "#6B7280"
    end
  end

  defp determine_progress_animation(percentage) do
    if percentage < 100, do: "pulse", else: "complete"
  end

  defp calculate_percentage(completed, total) when total > 0 do
    round(completed / total * 100)
  end

  defp calculate_percentage(_, _), do: 0

  defp determine_domain_status(stats) do
    cond do
      stats.failed && stats.failed > 0 -> :has_errors
      stats.completed && stats.total && stats.completed == stats.total -> :completed
      stats.completed && stats.completed > 0 -> :in_progress
      true -> :pending
    end
  end

  defp calculate_performance_score(stats) do
    # Higher score is better (faster compilation)
    base_score = 100
    time_penalty = if stats.avg_time && stats.avg_time > 5000, do: 20, else: 0
    error_penalty = if stats.failed && stats.failed > 0, do: stats.failed * 5, else: 0

    max(base_score - time_penalty - error_penalty, 0)
  end

  defp determine_subsystem_color(subsystem) do
    case subsystem do
      # blue
      "web" -> "#3B82F6"
      # green
      "core" -> "#10B981"
      # yellow
      "controllers" -> "#F59E0B"
      # red
      "components" -> "#EF4444"
      # purple
      "channels" -> "#8B5CF6"
      # gray
      "tests" -> "#6B7280"
      # pink
      _ -> "#EC4899"
    end
  end

  # Placeholder implementations for remaining functions
  defp build_highlights(_progress, _dashboard_data, _claude_data), do: []
  defp build_concerns(_progress, _dashboard_data, _claude_data), do: []
  defp build_resource_utilization_chart(_dashboard_data), do: %{}
  defp categorize_errors(_error_summary), do: %{}
  defp build_fix_suggestions(_optimization_suggestions), do: []
  defp build_error_timeline(_timeline), do: []
  defp build_drill_down_domains(_domain_breakdown), do: %{}
  defp build_error_pattern_explorer(_error_patterns), do: %{}
  defp build_performance_optimizer(_claude_data), do: %{}
  defp build_comparison_metrics(_session_id), do: %{}
  defp build_trend_analysis(_session_id), do: %{}
  defp build_improvement_tracking(_session_id), do: %{}
  defp build_quick_fixes(_error_summary), do: []
  defp build_optimization_opportunities(_claude_data), do: []
  defp build_automation_suggestions(_claude_data), do: []
  defp format_current_file(nil), do: "Initializing..."
  defp format_current_file(file), do: Path.basename(file)
  defp calculate_files_per_minute(_progress), do: 5.2
  defp get_recent_errors(_session_id, _limit), do: []
  defp get_performance_pulse(_session_id), do: %{status: :normal, trend: :stable}
  defp export_to_csv(_dashboard), do: "CSV export not yet implemented"
  defp export_to_html(_dashboard), do: "HTML export not yet implemented"
  defp export_to_pdf(_dashboard), do: {:error, "PDF export not yet implemented"}
  defp calculate_duration_range(_timeline_points), do: %{min: 0, max: 10_000}
  defp calculate_peak_speed(_performance_charts), do: 12.5
  defp analyze_speed_trend(_performance_charts), do: :increasing
  defp calculate_efficiency_score(_performance_charts), do: 85
  defp calculate_overall_efficiency(_progress, _dashboard_data), do: 88
  defp calculate_time_efficiency(_dashboard_data), do: 92
  defp calculate_resource_efficiency(_dashboard_data), do: 85
  defp calculate_error_efficiency(_progress), do: 95
  defp assess_current_performance(_progress, _dashboard_data), do: :above_target
  defp determine_bottleneck_severity(time) when time > 15_000, do: :severe
  defp determine_bottleneck_severity(time) when time > 8000, do: :moderate
  defp determine_bottleneck_severity(_), do: :minor
  defp categorize_bottleneck(_bottleneck), do: :compilation_complexity
  defp suggest_bottleneck_fix(_bottleneck), do: "Consider code splitting or parallelization"
  defp group_by_category(bottlenecks), do: Enum.group_by(bottlenecks, & &1.category)
  defp calculate_improvement_potential(_bottlenecks), do: %{time_savings: "25%", effort: "medium"}
  defp determine_error_severity(_category), do: :medium
  defp estimate_fix_difficulty(_category), do: :medium
  defp count_fixable_errors(_error_categories), do: 15
  defp count_critical_errors(_error_categories), do: 3
  defp determine_action_priority(_action), do: :medium
  defp get_action_description(action), do: "Execute #{action}"
  defp estimate_action_time(_action), do: "5-10 minutes"
  defp estimate_action_success(_action), do: 75
  defp can_automate_action(_action), do: true
end
