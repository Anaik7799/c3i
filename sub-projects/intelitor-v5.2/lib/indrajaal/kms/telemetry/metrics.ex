defmodule Indrajaal.KMS.Telemetry.Metrics do
  @moduledoc """
  Prometheus metrics definition for SMRITI.

  Defines metrics for:
  - Holon counts (gauge)
  - Search latency (histogram)
  - Immortality protocol status (counter)
  - Federation sync events (counter)
  """

  import Telemetry.Metrics

  def metrics do
    [
      # Counters
      counter("smriti.immortality.success.count",
        description: "Successful immortality protocol runs"
      ),
      counter("smriti.immortality.failure.count",
        description: "Failed immortality protocol runs"
      ),
      counter("smriti.federation.sync.count", description: "Federation sync events"),

      # Gauges
      last_value("smriti.metrics.total_holons", description: "Total number of holons"),
      last_value("smriti.metrics.orphan_holons", description: "Number of orphan holons"),
      last_value("smriti.metrics.stale_holons", description: "Number of stale holons"),
      last_value("smriti.metrics.cluster_count", description: "Number of knowledge clusters"),
      last_value("smriti.metrics.health_score", description: "System health score (0-100)"),

      # Histograms
      summary("smriti.search.query.duration",
        unit: {:native, :millisecond},
        description: "Search query latency"
      ),
      summary("smriti.health.check.duration",
        unit: {:native, :millisecond},
        description: "Health check duration"
      ),
      summary("smriti.agent.ooda_cycle.duration",
        unit: {:native, :millisecond},
        description: "Agent OODA cycle duration"
      )
    ]
  end
end
