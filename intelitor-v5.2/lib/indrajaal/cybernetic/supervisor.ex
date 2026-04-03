defmodule Indrajaal.Cybernetic.Supervisor do
  @moduledoc """
  Cybernetic Autonomic Supervisor

  Manages the OODA cybernetic control loop, telemetry, resource monitoring
  (Observe signals), and FLAME scaling (Act capabilities).

  STAMP: SC-OODA-001 (cycle <100ms), SC-BUS-001 (async messaging)
  Strategy: :one_for_one — each autonomic component is independently restartable
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.Cybernetic.OODA.Loop, []},
      {Indrajaal.Cybernetic.OODA.Telemetry, []},
      {Indrajaal.System.ResourceMonitor, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
