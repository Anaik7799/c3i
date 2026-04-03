defmodule Indrajaal.TelemetryMetricsWorker do
  @moduledoc """
  A worker to initialize Telemetry.Metrics definitions.
  This runs as part of the supervision tree to ensure `:telemetry_metrics`
  is available before its functions are called.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Define and attach metrics
    setup_telemetry_metrics()
    {:ok, %{}}
  end

  defp setup_telemetry_metrics do
    _metrics = []

    # Enum.each(metrics, fn metric ->
    #   :ok = Telemetry.Metrics.attach(metric, Indrajaal.Telemetry)
    # end)

    :ok
  end
end
