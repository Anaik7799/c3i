defmodule Indrajaal.Metrics.MetricsCollector do
  @moduledoc """
  Claude Agent Generated: EP-084 Behaviour Definition
  Purpose: Resolve behaviour compliance warnings
  Created: 2025-09-04T13:18:45.857426Z
  """

  @callback collect_metrics(source :: atom()) :: {:ok, map()} | {:error, term()}
  @callback record_metric(metric_name :: atom(), value :: term()) :: :ok
  @callback get_collected_metrics() :: {:ok, map()} | {:error, term()}
end
