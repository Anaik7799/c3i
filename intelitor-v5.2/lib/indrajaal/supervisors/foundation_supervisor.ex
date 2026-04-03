defmodule Indrajaal.Supervisors.FoundationSupervisor do
  @moduledoc """
  L1 FOUNDATION SUPERVISOR
  Manages the absolute core substrate: Health Server, Zenoh Mesh, Database, and Networking.

  STAMP: SC-ZENOH-001 (Zenoh Primacy), SC-FIX-007 (Bandit first)
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # SECONDARY HEALTH SERVER (Port 4001) - SC-FIX-007
      {Bandit,
       plug: IndrajaalWeb.Plugs.HealthPlug,
       ip: {0, 0, 0, 0},
       port: String.to_integer(System.get_env("HEALTH_PORT") || "4001"),
       scheme: :http},

      # ZENOH COORDINATION SYSTEM
      {Indrajaal.Observability.ZenohCoordinator, []},
      IndrajaalWeb.Telemetry,
      Indrajaal.Repo,
      {Redix,
       name: :redix,
       host: System.get_env("REDIS_HOST", "localhost"),
       port: String.to_integer(System.get_env("REDIS_PORT", "6379"))},
      {Phoenix.PubSub, name: Indrajaal.PubSub},
      {Finch, name: Indrajaal.Finch},

      # MESH NETWORKING
      {Indrajaal.Mesh.TailscaleMesh, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
