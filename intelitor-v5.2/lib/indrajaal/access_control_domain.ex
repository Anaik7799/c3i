defmodule Indrajaal.AccessControlDomain do
  @moduledoc """
  Access Control Domain - Enterprise security and access management framework.

  Manages access control credentials, rules, schedules, logging, and anti-passback
  systems with comprehensive security policy enforcement.
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource Indrajaal.AccessControl.AccessCredential
    resource Indrajaal.AccessControl.AccessException
    resource Indrajaal.AccessControl.AccessGrant
    resource Indrajaal.AccessControl.AccessLevel
    resource Indrajaal.AccessControl.AccessLog
    resource Indrajaal.AccessControl.AccessRequest
    resource Indrajaal.AccessControl.AccessRevocation
    resource Indrajaal.AccessControl.AccessSchedule
    resource Indrajaal.AccessControl.AntiPassback
  end

  authorization do
    authorize :by_default
  end
end

# Agent: Helper - 2 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ Access control and security management with cybernetic framework
# Domain: Access control
# Responsibilities: Access control, security policies, credential management
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
