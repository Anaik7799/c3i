#!/usr/bin/env elixir

defmodule Dashboards.MultiAgentPerformance do
  @moduledoc """
  TDG-validated dashboard configuration for multi-agent compilation monitoring.

  This script creates dashboard definitions that can be imported into SigNoz
  for monitoring the 11-agent architecture performance.
  """

  @dashboard_config %{
    uid: "multi-agent-performance",
    title: "Multi-Agent Compilation Performance",
    description: "Monitor the performance of the 11-agent compilation architecture",
    tags: ["indrajaal", "compilation", "multi-agent", "performance"],
    refresh: "30s",
    time: %{
      from: "now-1h",
      to: "now"
    },
    panels: []
  }

  @spec main(any()) :: any()
  def main(_args \\ []) do
    IO.puts """
    ╔═══════════════════════════════════════════════════════════════════╗
    ║         Multi-Agent Performance Dashboard Generator               ║
    ╚═══════════════════════════════════════════════════════════════════╝
    """

    dashboard = build_dashboard()

    # Save dashboard JSON
    output_file = "observability/dashboards/multi_agent_performance.json"
    File.write!(output_file, Jason.encode!(dashboard, pretty: true))

    IO.puts "\n✅ Dashboard configuration saved to: #{output_file}"
    IO.puts "\nTo import into SigNoz:"
    IO.puts "1. Open SigNoz UI at http://localhost:3301"
    IO.puts "2. Navigate to Dashboards → Import"
    IO.puts "3. Upload the generated JSON file"
  end

  @spec build_dashboard() :: any()
  defp build_dashboard do
    @dashboard_config
    |> Map.put(:panels, [
      agent_activity_timeline_panel(),
      compilation_success_rate_panel(),
      agent_resource_utilization_panel(),
      compilation_duration_histogram_panel(),
      error_rate_by_domain_panel(),
      agent_coordination_heatmap_panel(),
      warning_patterns_panel(),
      system_health_overview_panel()
    ])
  end

  @spec agent_activity_timeline_panel() :: any()
  defp agent_activity_timeline_panel do
    %{
      id: 1,
      gridPos: %{x: 0, y: 0, w: 24, h: 8},
      type: "graph",
      title: "Agent Activity Timeline",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            toDateTime(timestamp) as time,
            attributes['agent.id'] as agent_id,
            attributes['task.type'] as task_type,
            duration_ms
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND name LIKE 'compilation.%'
            AND timestamp >= now() - INTERVAL 1 HOUR
          ORDER BY timestamp
          """
        }
      ],
      options: %{
        legend: %{show: true, placement: "bottom"},
        tooltip: %{mode: "multi", sort: "desc"}
      }
    }
  end

  @spec compilation_success_rate_panel() :: any()
  defp compilation_success_rate_panel do
    %{
      id: 2,
      gridPos: %{x: 0, y: 8, w: 12, h: 8},
      type: "stat",
      title: "Compilation Success Rate",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            countIf(attributes['operation.success'] = 'true') * 100.0 / count() as success_rate
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND name = 'compilation.complete'
            AND timestamp >= now() - INTERVAL 1 HOUR
          """
        }
      ],
      options: %{
        unit: "percent",
        decimals: 2,
        thresholds: %{
          steps: [
            %{color: "red", value: 0},
            %{color: "yellow", value: 90},
            %{color: "green", value: 95}
          ]
        }
      }
    }
  end

  @spec agent_resource_utilization_panel() :: any()
  defp agent_resource_utilization_panel do
    %{
      id: 3,
      gridPos: %{x: 12, y: 8, w: 12, h: 8},
      type: "graph",
      title: "Agent Resource Utilization",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            toDateTime(timestamp) as time,
            attributes['agent.type'] as agent_type,
            avg(attributes['cpu.usage']) as avg_cpu,
            avg(attributes['memory.usage']) as avg_memory
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND name LIKE 'agent.%'
            AND timestamp >= now() - INTERVAL 1 HOUR
          GROUP BY time, agent_type
          ORDER BY time
          """
        }
      ],
      yaxis: [
        %{label: "CPU %", min: 0, max: 100},
        %{label: "Memory MB", min: 0}
      ]
    }
  end

  @spec compilation_duration_histogram_panel() :: any()
  defp compilation_duration_histogram_panel do
    %{
      id: 4,
      gridPos: %{x: 0, y: 16, w: 12, h: 8},
      type: "histogram",
      title: "Compilation Duration Distribution",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            histogram(duration_ms) as duration_histogram
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND name = 'compilation.complete'
            AND timestamp >= now() - INTERVAL 1 HOUR
          """
        }
      ],
      options: %{
        bucketSize: 1000,
        unit: "ms"
      }
    }
  end

  @spec error_rate_by_domain_panel() :: any()
  defp error_rate_by_domain_panel do
    %{
      id: 5,
      gridPos: %{x: 12, y: 16, w: 12, h: 8},
      type: "bar",
      title: "Error Rate by Ash Domain",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            attributes['ash.domain'] as domain,
            countIf(attributes['operation.success'] = 'false') * 100.0 / count() as error_rate
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND name LIKE 'domain.%'
            AND timestamp >= now() - INTERVAL 1 HOUR
          GROUP BY domain
          ORDER BY error_rate DESC
          """
        }
      ],
      options: %{
        orientation: "horizontal",
        unit: "percent"
      }
    }
  end

  @spec agent_coordination_heatmap_panel() :: any()
  defp agent_coordination_heatmap_panel do
    %{
      id: 6,
      gridPos: %{x: 0, y: 24, w: 12, h: 8},
      type: "heatmap",
      title: "Agent Coordination Heatmap",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            toStartOfMinute(timestamp) as time,
            attributes['coordination.wait_time'] as wait_time,
            count() as f__requency
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND name = 'agent.coordination'
            AND timestamp >= now() - INTERVAL 1 HOUR
          GROUP BY time, wait_time
          ORDER BY time
          """
        }
      ],
      options: %{
        calculate: false,
        color: %{
          mode: "spectrum",
          scheme: "Oranges"
        }
      }
    }
  end

  @spec warning_patterns_panel() :: any()
  defp warning_patterns_panel do
    %{
      id: 7,
      gridPos: %{x: 12, y: 24, w: 12, h: 8},
      type: "table",
      title: "Top Warning Patterns",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            attributes['warning.pattern'] as pattern,
            attributes['warning.category'] as category,
            count() as occurrences,
            max(timestamp) as last_seen
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND attributes['warning.pattern'] != ''
            AND timestamp >= now() - INTERVAL 1 HOUR
          GROUP BY pattern, category
          ORDER BY occurrences DESC
          LIMIT 20
          """
        }
      ],
      options: %{
        showHeader: true,
        sortBy: [%{displayName: "Occurrences", desc: true}]
      }
    }
  end

  @spec system_health_overview_panel() :: any()
  defp system_health_overview_panel do
    %{
      id: 8,
      gridPos: %{x: 0, y: 32, w: 24, h: 4},
      type: "__state-timeline",
      title: "System Health Overview",
      targets: [
        %{
          queryType: "clickhouse",
          query: """
          SELECT
            toDateTime(timestamp) as time,
            multiIf(
              countIf(attributes['severity'] = 'error') > 0, 'critical',
              countIf(attributes['severity'] = 'warning') > 0, 'warning',
              'healthy'
            ) as health_status
          FROM signoz_traces.distributed_traces_v2
          WHERE
            serviceName = 'indrajaal'
            AND timestamp >= now() - INTERVAL 1 HOUR
          GROUP BY toStartOfMinute(timestamp) as time
          ORDER BY time
          """
        }
      ],
      options: %{
        mergeValues: false,
        showValue: "auto",
        alignValue: "center"
      }
    }
  end
end

# Generate the dashboard
Dashboards.MultiAgentPerformance.main(System.argv())