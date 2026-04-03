defmodule Indrajaal.Observability.SingletonsSupervisor do
  @moduledoc """
  Observability Singletons Supervisor

  Manages standalone observability GenServers that don't belong to the
  Fractal or ZenohCoordinator supervisor trees: Metrics collector,
  StateTracker (CubDB), TelemetryMetricsWorker, and Sentinel ZenohPublisher.

  STAMP: SC-OBS-069 (dual logging), SC-ZENOH-001 (Zenoh primacy)
  Strategy: :one_for_one — each singleton is independently restartable
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.Sentinel.ZenohPublisher, []},
      Indrajaal.Observability.Metrics,
      {Indrajaal.TelemetryMetricsWorker, []},
      {Indrajaal.Observability.StateTracker, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
