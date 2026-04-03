defmodule Indrajaal.Dispatch do
  @moduledoc """
  The Dispatch domain manages response team coordination and deployment.

  This domain handles the orchestration of security teams, emergency responders,
  and service personnel in response to alarms and incidents. It provides
  comprehensive dispatch management including team allocation,
    route optimization,
  and real - time coordination capabilities.
  """

  use Indrajaal.BaseDomain, name: "dispatch"

  resources do
    resource Indrajaal.Dispatch.Team
    resource Indrajaal.Dispatch.Officer
    resource Indrajaal.Dispatch.Vehicle
    resource Indrajaal.Dispatch.Assignment
    resource Indrajaal.Dispatch.Route
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Dispatch
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
