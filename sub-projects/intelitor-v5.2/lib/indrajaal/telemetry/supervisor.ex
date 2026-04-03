defmodule Indrajaal.Telemetry.Supervisor do
  @moduledoc """
  Telemetry Supervisor for Comprehensive System Monitoring

  Manages all telemetry - related processes including:
  - Metrics collection and aggregation
  - Event handling and processing
  - Storage and persistence
  - Reporting and alerting
  - Performance monitoring
  """

  use Supervisor
  require Logger

  @spec start_link(any()) :: any()
  def start_link(initarg) do
    Supervisor.start_link(__MODULE__, initarg, name: __MODULE__)
  end

  @impl true
  @spec init(any()) :: any()
  def init(_init_arg) do
    Logger.info("Starting Indrajaal Telemetry Supervisor")

    children = [
      # Core telemetry components
      {Indrajaal.Telemetry.MetricsCollector, []},
      {Indrajaal.Telemetry.EventHandler, []},
      {Indrajaal.Telemetry.PerformanceReporter, []},
      {Indrajaal.Telemetry.Storage, []},

      # Specialized monitoring components
      {Indrajaal.Telemetry.PerformanceMonitor, []},
      {Indrajaal.Telemetry.SafetyMonitor, []},
      {Indrajaal.Telemetry.AlertManager, []},

      # Periodic tasks
      {Indrajaal.Telemetry.PeriodicCollector, []}
    ]

    # Setup telemetry __event handlers
    Indrajaal.Telemetry.Handlers.setup()

    Logger.info("Telemetry components configured",
      components: length(children),
      handlers_attached: true
    )

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Restart all telemetry components
  """
  @spec restart_all() :: any()
  def restart_all do
    Logger.warning("Restarting all telemetry components")

    for {child_id, _, _, _} <- Supervisor.which_children(__MODULE__) do
      Supervisor.terminate_child(__MODULE__, child_id)
      Supervisor.restart_child(__MODULE__, child_id)
    end

    # Reattach handlers
    Indrajaal.Telemetry.Handlers.setup()

    :ok
  end

  @doc """
  Get status of all telemetry components
  """
  @spec component_status() :: any()
  def component_status do
    children = Supervisor.which_children(__MODULE__)

    children
    |> Enum.map(fn {id, pid, type, modules} ->
      status =
        if Process.alive?(pid) do
          :running
        else
          :stopped
        end

      %{
        id: id,
        pid: pid,
        type: type,
        modules: modules,
        status: status
      }
    end)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
