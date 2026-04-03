defmodule Indrajaal.Cortex.GDE.Supervisor do
  @moduledoc """
  GDE Supervisor: Manages Goal-Directed Evaluation components.

  WHAT: OTP Supervisor for GDE subsystem.
  WHY: Ensures fault-tolerant operation of all GDE components.
  CONSTRAINTS: Must restart components on failure, maintain isolation.

  ## Supervised Components

  - GoalEvaluator: Determines success/failure of goals
  - Backtracker: Manages retry logic with state rewind
  - ProposalEngine: Generates fix proposals
  - Controller: Orchestrates goal-directed evolution

  ## STAMP Constraints

  - SC-GDE-050: All components must be supervised
  - SC-GDE-051: Restart strategy must be one_for_one
  - SC-GDE-052: Must integrate with Cortex supervision tree

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-050 to SC-GDE-052 |
  """

  use Supervisor
  require Logger

  alias Indrajaal.Cortex.GDE.GoalEvaluator
  alias Indrajaal.Cortex.GDE.Backtracker
  alias Indrajaal.Cortex.GDE.ProposalEngine
  alias Indrajaal.Cortex.GDE.Controller

  # ============================================================
  # PUBLIC API
  # ============================================================

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the child specification for embedding in another supervisor.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Gets status of all GDE components.
  """
  @spec status() :: map()
  def status do
    children = Supervisor.which_children(__MODULE__)

    mapped =
      Enum.map(children, fn {id, pid, type, _modules} ->
        {id, %{pid: pid, type: type, alive: is_pid(pid) and Process.alive?(pid)}}
      end)

    component_status =
      mapped
      |> Map.new()

    %{
      supervisor: :running,
      components: component_status
    }
  end

  @doc """
  Gets combined statistics from all GDE components.
  """
  @spec combined_stats() :: map()
  def combined_stats do
    %{
      goal_evaluator: safe_call(GoalEvaluator, :stats),
      backtracker: safe_call(Backtracker, :stats),
      proposal_engine: safe_call(ProposalEngine, :stats),
      controller: safe_call(Controller, :metrics)
    }
  end

  # ============================================================
  # SUPERVISOR CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    Logger.info("[GDE.Supervisor] Starting GDE supervision tree - SC-GDE-050")

    children = [
      {GoalEvaluator, []},
      {Backtracker, []},
      {ProposalEngine, []},
      {Controller, []}
    ]

    # one_for_one: if one child crashes, only that child is restarted
    Supervisor.init(children, strategy: :one_for_one)
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp safe_call(module, function) do
    if GenServer.whereis(module) do
      apply(module, function, [])
    else
      %{status: :not_running}
    end
  rescue
    _ -> %{status: :error}
  end
end
