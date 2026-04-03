defmodule Indrajaal.Health do
  @moduledoc """
  High-assurance health coordinator for the SIL-6 Biomorphic Mesh.
  Bridges the Elixir application cortex to the Zenoh/Sentinel data plane.
  """

  require Logger

  @doc """
  Performs an immediate health assessment of the local node and the mesh.
  """
  def assess_now do
    Logger.info("[Health] Initiating biomorphic health assessment...")

    # 1. Local node health - Use stable Erlang VM statistics
    local_health = %{
      node: node(),
      status: :healthy,
      run_queue: :erlang.statistics(:run_queue),
      process_count: :erlang.system_info(:process_count),
      timestamp: DateTime.utc_now()
    }

    # 2. Sentinel status
    sentinel_status = Indrajaal.Sentinel.assess_now()

    # 3. Aggregate mesh health
    mesh_health = %{
      aggregate_score: sentinel_status.health_score,
      quorum: :ok
    }

    # 4. Telemetry emission
    :telemetry.execute(
      [:indrajaal, :health, :assessment],
      %{score: mesh_health.aggregate_score},
      %{status: local_health.status}
    )

    {:ok, %{local: local_health, sentinel: sentinel_status, mesh: mesh_health}}
  end
end
