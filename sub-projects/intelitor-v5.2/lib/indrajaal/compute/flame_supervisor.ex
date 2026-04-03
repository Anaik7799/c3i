defmodule Indrajaal.Compute.FLAMESupervisor do
  @moduledoc """
  Supervisor for FLAME elastic compute pools and external compute bridges.

  Consolidates all FLAME.Pool children (previously inline in AutonomicSupervisor)
  using the canonical pool configs from `Indrajaal.FLAME.Pools.pools/0`.

  ## STAMP Constraints
  - SC-FLAME-001: FLAME pools supervised with one_for_one restart
  - SC-MOJO-001: MojoRunner/MojoHealthSubscriber added as siblings (Wave 2)
  """
  use Supervisor

  alias Indrajaal.FLAME.Pools

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    flame_children =
      Pools.pools()
      |> Enum.map(fn pool_config ->
        {FLAME.Pool, Map.to_list(pool_config)}
      end)

    # Mojo MAX Bridge (Zenoh-connected external compute — SC-MOJO-001)
    mojo_children = [
      {Indrajaal.Compute.MojoRunner, []},
      {Indrajaal.Compute.MojoHealthSubscriber, []}
    ]

    children = flame_children ++ mojo_children

    Supervisor.init(children, strategy: :one_for_one)
  end
end
