defmodule Indrajaal.Supervisors.AutonomicSupervisor do
  @moduledoc """
  L4 AUTONOMIC SUPERVISOR
  Manages self-healing loops, distributed clusters, ML serving, and cognitive planes.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children =
      [
        # Cluster Supervisor for Libcluster
        {Cluster.Supervisor,
         [
           Application.get_env(:libcluster, :topologies, []),
           [name: Indrajaal.ClusterSupervisor]
         ]},

        # FLAME Pools + External Compute Bridges (consolidated into FLAMESupervisor)
        {Indrajaal.Compute.FLAMESupervisor, []},
        {Indrajaal.Cybernetic.Supervisor, []},
        {Indrajaal.ML.Serving, []},
        {Indrajaal.Integration.Supervisor, []},

        # Semantic Layer
        if(Mix.env() != :test, do: {Indrajaal.Semantic.Bridge, []}, else: nil),
        {Indrajaal.Cortex.Supervisor, []},
        {Indrajaal.Cockpit.Prajna.Supervisor, []},
        {Indrajaal.Observability.Fractal.Supervisor, [enable_cybernetic: true]},
        {Indrajaal.Economic.Substrate, []},
        {Indrajaal.Testing.AdversarialLoop, []},
        {Indrajaal.Smriti.Supervisor, []},

        # L4-BODY: CPU Governor — adaptive parallelism with PID controller (SC-CPU-GOV-001)
        {Indrajaal.Core.CpuGovernor, []}
      ]
      |> Enum.filter(& &1)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
