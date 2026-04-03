defmodule Indrajaal.AssetManagement do
  @moduledoc """
  Asset Management Domain - Comprehensive asset lifecycle tracking and
    management.

  Manages physical and digital assets, their lifecycle, maintenance schedules,
  depreciation, warranties, and compliance tracking across the organization.
  """

  use Ash.Domain,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource Indrajaal.AssetManagement.AssetCategory
    resource Indrajaal.AssetManagement.Asset
    resource Indrajaal.AssetManagement.AssetLocation
    resource Indrajaal.AssetManagement.AssetAssignment
    resource Indrajaal.AssetManagement.AssetMaintenance
    resource Indrajaal.AssetManagement.AssetWarranty
    resource Indrajaal.AssetManagement.AssetDepreciation
    resource Indrajaal.AssetManagement.AssetAudit
    resource Indrajaal.AssetManagement.AssetTransfer
    resource Indrajaal.AssetManagement.AssetRetirement
  end

  authorization do
    authorize :by_default
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Asset management
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
