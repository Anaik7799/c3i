defmodule Indrajaal.Cortex.GDE do
  @moduledoc """
  Goal-Directed Evolution - Main entry point for GDE subsystem.

  WHAT: Provides GDE subsystem status interface and goal management.
  WHY: Required by cockpit modules for GDE health monitoring and operation.
  CONSTRAINTS: SC-GDE-001 - All operations must be Guardian-validated.

  ## GDE Overview

  Goal-Directed Evolution (GDE) is a self-improvement subsystem that:
  - Defines and tracks goals for system improvement
  - Generates proposals to achieve those goals
  - Validates all changes through Guardian safety kernel
  - Applies changes with backtracking support
  - Learns from success/failure outcomes

  ## Usage

  ```elixir
  # Define a goal
  {:ok, goal_id} = Indrajaal.Cortex.GDE.define_goal(
    :compilation_success,
    "Achieve zero compilation errors"
  )

  # Activate the goal
  :ok = Indrajaal.Cortex.GDE.activate_goal(goal_id)

  # Check status
  Indrajaal.Cortex.GDE.status()
  # => :active

  # Get metrics
  Indrajaal.Cortex.GDE.metrics()
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Created | 2025-12-26 |
  | Updated | 2025-12-29 |
  | Author | Cybernetic Architect |
  | STAMP | SC-GDE-001 |
  """

  alias Indrajaal.Cortex.GDE.Controller
  alias Indrajaal.Cortex.GDE.Supervisor, as: GDESupervisor

  @doc """
  Returns the current status of the GDE subsystem.

  - `:pending` - No active goals, waiting for goal definition
  - `:active` - Actively pursuing goals with evolution cycles
  - `:learning` - Analyzing past results for improved strategies
  - `:paused` - Temporarily suspended (manual intervention)
  """
  @spec status() :: :pending | :active | :learning | :paused
  def status do
    case safe_controller_call(:status) do
      %{active_goal: nil} -> :pending
      %{active_goal: _goal_id, auto_evolve: true} -> :active
      %{active_goal: _goal_id, auto_evolve: false} -> :learning
      _ -> :pending
    end
  end

  @doc """
  Defines a new goal for the GDE system to pursue.

  See `Indrajaal.Cortex.GDE.Controller.define_goal/3` for details.
  """
  @spec define_goal(Controller.goal_type(), String.t(), keyword()) ::
          {:ok, Controller.goal_id()} | {:error, atom()}
  def define_goal(type, description, opts \\ []) do
    Controller.define_goal(type, description, opts)
  end

  @doc """
  Activates a goal, making it the current evolution target.
  """
  @spec activate_goal(Controller.goal_id()) :: :ok | {:error, atom()}
  def activate_goal(goal_id) do
    Controller.activate_goal(goal_id)
  end

  @doc """
  Gets the status of a specific goal.
  """
  @spec goal_status(Controller.goal_id()) :: {:ok, Controller.goal()} | {:error, :not_found}
  def goal_status(goal_id) do
    Controller.goal_status(goal_id)
  end

  @doc """
  Lists all defined goals.
  """
  @spec list_goals(keyword()) :: [Controller.goal()]
  def list_goals(opts \\ []) do
    Controller.list_goals(opts)
  end

  @doc """
  Sets the evolution strategy.

  - `:conservative` - Small, incremental changes (safest)
  - `:aggressive` - Larger changes, more risk
  - `:defensive` - Prioritize stability
  - `:exploratory` - Try novel approaches
  """
  @spec set_strategy(Controller.evolution_strategy()) :: :ok
  def set_strategy(strategy) do
    Controller.set_strategy(strategy)
  end

  @doc """
  Triggers a manual evolution cycle.
  """
  @spec trigger_evolution() :: :ok
  def trigger_evolution do
    Controller.trigger_evolution()
  end

  @doc """
  Gets comprehensive GDE metrics.
  """
  @spec metrics() :: map()
  def metrics do
    safe_controller_call(:metrics)
  end

  @doc """
  Gets combined statistics from all GDE components.
  """
  @spec combined_stats() :: map()
  def combined_stats do
    GDESupervisor.combined_stats()
  end

  # Private helper for safe controller calls
  defp safe_controller_call(function) do
    if GenServer.whereis(Controller) do
      apply(Controller, function, [])
    else
      %{status: :not_running, error: :controller_unavailable}
    end
  rescue
    _ -> %{status: :error, error: :call_failed}
  end
end
