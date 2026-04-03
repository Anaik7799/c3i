defmodule Indrajaal.GuardTour do
  @moduledoc """
  Guard Tour Domain - Security patrol management and checkpoint tracking.

  Manages security guard patrols, routes, checkpoints, and tour execution
  with real - time tracking and exception handling.
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource Indrajaal.GuardTour.TourRoute
    resource Indrajaal.GuardTour.Checkpoint
    resource Indrajaal.GuardTour.TourSchedule
    resource Indrajaal.GuardTour.TourExecution
    resource Indrajaal.GuardTour.CheckpointScan
    resource Indrajaal.GuardTour.TourException
    resource Indrajaal.GuardTour.GuardAssignment
    resource Indrajaal.GuardTour.TourReport
  end

  authorization do
    authorize :by_default
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
