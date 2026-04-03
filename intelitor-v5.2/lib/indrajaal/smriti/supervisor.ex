defmodule Indrajaal.Smriti.Supervisor do
  @moduledoc """
  SMRITI Knowledge System Supervisor

  Manages the knowledge system: ingestion pipeline (Senses.Supervisor),
  immortality protocol, health monitoring, and federation sync.

  STAMP: SC-AI-001 (context persistence), SC-FRAC-006 (federation)
  Strategy: :one_for_one — each SMRITI component is independently restartable
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.Smriti.Senses.Supervisor, []},
      {Indrajaal.Smriti.Immortality.Protocol, []},
      {Indrajaal.Smriti.Automation.HealthMonitoring, []},
      {Indrajaal.Smriti.Federation.Protocol, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
