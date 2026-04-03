defmodule Indrajaal.Crm do
  @moduledoc """
  CRM Domain - Customer Relationship Management automation.

  ## WHAT
  Comprehensive CRM automation including lead management, workflow automation,
  sales pipeline analytics, forecasting, campaign ROI tracking, and dashboards.

  ## WHY
  Provides enterprise-grade sales automation with real-time analytics,
  AI-driven insights, and collaborative forecasting for revenue optimization.

  ## CONSTRAINTS
  - SC-AUTO-001: Max 100 rules per object
  - SC-AUTO-002: Evaluation timeout 5s
  - SC-AUTO-003: Fallback owner required
  - SC-EMR-057: Emergency stop capability
  - SC-DB-001: All resources use BaseResource
  - SC-PRF-050: Response time < 50ms for analytics queries
  - SC-OBS-069: Dual logging (Terminal + Zenoh)
  - SC-HOLON-001: All holon state in SQLite/DuckDB

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Enhanced Lead, Account, Contact, Opportunity, Activity, OpportunityContactRole, added AccountTeamMember |
  | 21.2.1 | 2026-01-11 | Claude | Added Analytics, Forecasting, Quota, Campaign ROI |
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |
  """

  use Ash.Domain,
    extensions: [Ash.Domain.Graphql, Ash.Domain.JsonApi]

  resources do
    # Core CRM Resources
    resource Indrajaal.Crm.Account
    resource Indrajaal.Crm.Contact
    resource Indrajaal.Crm.Lead
    resource Indrajaal.Crm.Opportunity

    # Sales Process Resources (Work Stream 6)
    resource Indrajaal.Crm.Product
    resource Indrajaal.Crm.Pricebook
    resource Indrajaal.Crm.PricebookEntry
    resource Indrajaal.Crm.Quote
    resource Indrajaal.Crm.QuoteLineItem
    resource Indrajaal.Crm.OpportunityLineItem
    resource Indrajaal.Crm.Campaign
    resource Indrajaal.Crm.CampaignMember
    resource Indrajaal.Crm.Order
    resource Indrajaal.Crm.OrderLineItem

    # Automation & Workflow Resources
    resource Indrajaal.Crm.Activity
    resource Indrajaal.Crm.ApprovalRequest
    resource Indrajaal.Crm.WorkflowRule
    resource Indrajaal.Crm.AssignmentRule
    resource Indrajaal.Crm.OpportunityContactRole
    resource Indrajaal.Crm.AccountTeamMember
    resource Indrajaal.Crm.Quota
  end
end
