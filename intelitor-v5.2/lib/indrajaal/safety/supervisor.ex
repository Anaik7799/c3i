defmodule Indrajaal.Safety.Supervisor do
  @moduledoc """
  Safety Plane Supervisor - SIL-6 Critical

  Manages the Simplex safety kernel: Guardian (deterministic validator)
  and Sentinel (immune system threat hunter).

  STAMP: SC-AGT-019 (Executive Authority), SC-IMMUNE-001 (Sentinel)
  Strategy: :one_for_one — each safety service is independently restartable
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Initialize ConsensusIntegrity ETS table before starting dependent GenServers
    Indrajaal.Safety.ConsensusIntegrity.init()

    children = [
      {Indrajaal.Safety.Guardian, []},
      {Indrajaal.Safety.Sentinel, []},
      # Bicameral consensus — cross-plane integrity scoring (SC-CONSENSUS-001)
      {Indrajaal.Safety.ConsensusAggregator, []},
      # Holographic Regeneration Protocol (SC-REGEN-003)
      {Indrajaal.Safety.RegenerationSwarm, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
