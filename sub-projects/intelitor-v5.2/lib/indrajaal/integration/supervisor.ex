defmodule Indrajaal.Integration.Supervisor do
  @moduledoc """
  CEPAF Integration Supervisor

  Manages the F# bridge: CepafPort (low-level Port lifecycle) and
  CepafClient (high-level facade with caching and telemetry).

  STAMP: SC-SYNC-001 (timeout <5s), SC-SYNC-003 (circuit breaker)
  Strategy: :rest_for_one — Port must be available before Client
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.Integration.CepafPort, []},
      {Indrajaal.Integration.CepafClient, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
