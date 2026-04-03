defmodule Indrajaal.Cluster.Supervisor do
  @moduledoc """
  Cluster Coordination Supervisor

  Manages cluster infrastructure: Sentinel (health/quorum guardian)
  and CapabilityRouter (unified multi-backend compute routing).

  STAMP: SC-CLU-001 (cluster identity), SC-AUTO-001 (Sentinel first)
  Strategy: :rest_for_one — Sentinel must be available before routing
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.Cluster.Sentinel, []},
      {Indrajaal.Cluster.Capabilities.CapabilityRouter, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
