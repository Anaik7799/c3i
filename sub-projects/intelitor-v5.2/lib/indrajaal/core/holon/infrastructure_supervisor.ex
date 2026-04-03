defmodule Indrajaal.Core.Holon.InfrastructureSupervisor do
  @moduledoc """
  Holon Infrastructure Supervisor

  Manages the foundational holon services: registry, health propagation,
  state integrity watchdog, founder persistence, and replication.

  STAMP: SC-HOL-001 to SC-HOL-004, SC-HOLON-014 (integrity verification)
  Strategy: :rest_for_one — Registry must be available before dependents
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.Core.Holon.Registry, []},
      {Indrajaal.Core.Holon.HealthPropagator, [name: Indrajaal.Core.Holon.HealthPropagator]},
      {Indrajaal.Core.Holon.StateWatchdog, []},
      {Indrajaal.Core.Holon.FounderPersistence, []},
      {Indrajaal.Core.Holon.LegacyReplicator, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
