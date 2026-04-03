defmodule Indrajaal.Supervisors.IntelligenceSupervisor do
  @moduledoc """
  L3 INTELLIGENCE SUPERVISOR
  Manages AI services, model servers, safety planes, and knowledge management.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Indrajaal.MCP.Foundation.Server, [transport: :stdio]},
      %{
        id: Indrajaal.Authentication.TokenRevocationCache,
        start: {Indrajaal.Authentication.TokenRevocationCache, :start_link, [[]]}
      },
      Indrajaal.Vault,
      {Indrajaal.Core.Holon.InfrastructureSupervisor, []},
      {Indrajaal.KMS.Supervisor, []},
      {Indrajaal.Cluster.Supervisor, []},
      {Indrajaal.Safety.Supervisor, []},
      {Indrajaal.AI.Supervisor, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
