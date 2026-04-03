defmodule Indrajaal.CommunicationDomain do
  @moduledoc """
  Communication Domain - Enterprise communication and messaging framework.

  Manages broadcast campaigns, message templates, notification channels, and
  delivery analytics with comprehensive communication orchestration.
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource Indrajaal.Communication.BroadcastCampaign
    resource Indrajaal.Communication.ContactGroup
    resource Indrajaal.Communication.ContactPreference
    resource Indrajaal.Communication.DeliveryLog
    resource Indrajaal.Communication.Message
    resource Indrajaal.Communication.MessageQueue
    resource Indrajaal.Communication.MessageTemplate
    resource Indrajaal.Communication.NotificationChannel
    resource Indrajaal.Communication.NotificationRule

    # CLAUDE_AGENT_CONTEXT: Fixed compilation error - Removed GenServer modules
    # Date: 2025-09-03
    # Issue: ArgumentError - modules listed here must be Spark DSL modules (Ash Resources)
    # Root Cause: GenServers were incorrectly listed as resources in domain
    # Pattern: EP045_DOMAIN_RESOURCE_MISMATCH
    # Fix: Only include modules that use Ash.Resource or Indrajaal.BaseResource
    #
    # Removed GenServer modules (these are services, not resources):
    # - MessageDeliveryAnalytics (GenServer for analytics processing)
    # - TimescaleCommunicationEvents (GenServer for time-series __data)
    # - TimescaleDomainIntegration (GenServer for domain integration)
    # - UserEngagementAnalytics (GenServer for engagement tracking)
    #
    # TPS 5-Level RCA Applied:
    # L1: Compilation fails with ArgumentError
    # L2: Non-resource module in resources list
    # L3: Mix of resources and services in same directory
    # L4: No validation of resource types
    # L5: Architecture allows mixing without clear boundaries
  end

  authorization do
    authorize :by_default
  end
end

# Agent: Helper - 2 (Communication Domain Agent)
# SOPv5.1 Compliance: ✅ Communication and messaging coordination with cybernetic framework
# Domain: Communication
# Responsibilities: Messaging, notifications, broadcast campaigns, delivery analytics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
