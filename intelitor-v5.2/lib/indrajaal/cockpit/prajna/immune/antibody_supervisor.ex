defmodule Indrajaal.Cockpit.Prajna.Immune.AntibodySupervisor do
  @moduledoc """
  ## Antibody Dynamic Supervisor

  Manages ephemeral Antibody agents that hunt for specific threat patterns.
  Uses DynamicSupervisor to spawn/terminate Antibodies on demand.

  ## STAMP Constraints
  - SC-IMMUNE-001: Antibodies cannot kill directly; must flag for T-Cells
  - SC-AGT-018: No deadlocks in supervision tree
  - SC-AGT-020: Actor isolation maintained

  ## Document Control
  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2026-01-01 |
  | Author | Cybernetic Architect |
  | STAMP | SC-IMMUNE-001, SC-AGT-018, SC-AGT-020 |
  """
  use DynamicSupervisor
  require Logger

  alias Indrajaal.Cockpit.Prajna.Immune.Antibody

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[AntibodySupervisor] Initialized - ready to spawn hunters")
    DynamicSupervisor.init(strategy: :one_for_one, max_children: 100)
  end

  @doc "Spawn a new Antibody to hunt for a pattern"
  @spec spawn_antibody(map()) :: {:ok, pid()} | {:error, term()}
  def spawn_antibody(search_image) do
    spec = {Antibody, search_image}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        Logger.info(
          "[AntibodySupervisor] Spawned Antibody #{inspect(pid)} for #{inspect(search_image)}"
        )

        {:ok, pid}

      {:error, reason} = error ->
        Logger.warning("[AntibodySupervisor] Failed to spawn Antibody: #{inspect(reason)}")
        error
    end
  end

  @doc "Get count of active Antibodies"
  @spec count() :: non_neg_integer()
  def count do
    DynamicSupervisor.count_children(__MODULE__)[:active] || 0
  end

  @doc "List all active Antibody PIDs"
  @spec list() :: [pid()]
  def list do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc "Terminate all active Antibodies"
  @spec terminate_all() :: :ok
  def terminate_all do
    list()
    |> Enum.each(&Antibody.terminate_hunt/1)

    :ok
  end
end
