defmodule Indrajaal.KMS.Telemetry.Dashboard do
  @moduledoc """
  Grafana Dashboard configuration for SMRITI.
  """

  def dashboard_config do
    %{
      title: "SMRITI Knowledge System",
      panels: [
        %{
          title: "Health Score",
          type: "gauge",
          metric: "smriti.metrics.health_score"
        },
        %{
          title: "Holon Growth",
          type: "graph",
          metric: "smriti.metrics.total_holons"
        },
        %{
          title: "Agent OODA Latency",
          type: "heatmap",
          metric: "smriti.agent.ooda_cycle.duration"
        }
      ]
    }
  end
end
