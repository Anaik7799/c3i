defmodule Indrajaal.Billing do
  @moduledoc """
  The Billing domain.

  Manages financial transactions, subscriptions, invoicing, and revenue
  tracking for the security monitoring system. Supports multiple billing
  models including subscription - based, usage - based, and hybrid pricing.
  """

  use Indrajaal.BaseDomain, name: "billing"

  resources do
    resource Indrajaal.Billing.Subscription
    resource Indrajaal.Billing.Invoice
    resource Indrajaal.Billing.Payment
    resource Indrajaal.Billing.Plan
    resource Indrajaal.Billing.UsageRecord
  end

  authorization do
    authorize :by_default
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Billing
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
