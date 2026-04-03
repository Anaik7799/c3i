defmodule Indrajaal.RiskManagement do
  @moduledoc """
  Risk Management Domain - Enterprise risk assessment and mitigation framework.

  Manages risk identification, assessment, mitigation strategies, monitoring,
  and compliance with enterprise risk management standards and regulations.
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource Indrajaal.RiskManagement.RiskCategory
    resource Indrajaal.RiskManagement.Risk
    resource Indrajaal.RiskManagement.RiskAssessment
    resource Indrajaal.RiskManagement.RiskMitigation
    resource Indrajaal.RiskManagement.RiskMonitoring
    resource Indrajaal.RiskManagement.RiskIncident
    resource Indrajaal.RiskManagement.RiskControl
    resource Indrajaal.RiskManagement.RiskMatrix
    resource Indrajaal.RiskManagement.RiskTreatment
    resource Indrajaal.RiskManagement.RiskReporting
    resource Indrajaal.Compliance.Assessment
    resource Indrajaal.Compliance.Framework
    resource Indrajaal.Compliance.Requirement
    resource Indrajaal.Compliance.Report
    resource Indrajaal.Compliance.Document
  end

  authorization do
    authorize :by_default
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Risk management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
