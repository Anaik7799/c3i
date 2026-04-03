defmodule Indrajaal.Integrations do
  @moduledoc """
  The Integrations domain manages external system integrations and __data
    exchange.

  This domain provides:
  - Webhook management for external notifications
  - API integrations with third - party security systems
  - Data synchronization and mapping
  - Integration monitoring and error handling
  """

  use Indrajaal.BaseDomain, name: "integrations"

  resources do
    resource Indrajaal.Integrations.Webhook
    resource Indrajaal.Integrations.ApiConnection
    resource Indrajaal.Integrations.DataMapping
    resource Indrajaal.Integrations.SyncJob
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Integrations
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
