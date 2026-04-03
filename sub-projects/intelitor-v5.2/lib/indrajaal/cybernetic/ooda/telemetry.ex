defmodule Indrajaal.Cybernetic.OODA.Telemetry do
  @moduledoc """
  Telemetry instrumentation for the OODA Loop.
  Provides observability into the cybernetic decision cycle.

  ## OODA Phases
  - Observe: Data collection latency
  - Orient: Analysis duration
  - Decide: Decision confidence
  - Act: Execution success/failure

  ## STAMP Compliance
  - SC-OBS-065: Telemetry integration
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = []
    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the list of metrics for the OODA loop.
  These should be added to the main Telemetry supervisor.
  """
  def metrics do
    [
      # Cycle Counting
      counter("intelitor.ooda.loop.count",
        event_name: [:indrajaal, :ooda, :loop],
        tags: [:phase, :event]
      ),

      # Data Quality (Observe Phase)
      last_value("intelitor.ooda.loop.data_quality",
        event_name: [:indrajaal, :ooda, :loop],
        description: "Quality score of the observation phase (0-100)"
      ),

      # Decision Confidence (Decide Phase)
      last_value("intelitor.ooda.loop.decision_confidence",
        event_name: [:indrajaal, :ooda, :loop],
        description: "Confidence score of the decision (0-100)"
      ),

      # Loop Latency (Act Phase)
      summary("intelitor.ooda.loop.latency",
        event_name: [:indrajaal, :ooda, :loop],
        unit: {:native, :millisecond},
        description: "Time taken to complete one full OODA cycle"
      )
    ]
  end
end
