defmodule Indrajaal.Policy do
  @moduledoc """
  The Policy domain manages authorization and access control.

  This domain provides:
  - Role - based access control (RBAC)
  - Permission management
  - Dynamic access rules
  - Policy enforcement
  """

  @type policy_result :: :authorized | :unauthorized | {:error, term()}
  @type access_context :: %{
          required(:actor) => term(),
          required(:resource) => term(),
          optional(atom()) => any()
        }

  use Indrajaal.BaseDomain, name: "policy"

  resources do
    resource Indrajaal.Policy.Role
    resource Indrajaal.Policy.Permission
    resource Indrajaal.Policy.RolePermission
    resource Indrajaal.Policy.UserRole
    resource Indrajaal.Policy.AccessRule
    resource Indrajaal.Authorization.Role
    resource Indrajaal.Authorization.Permission
    resource Indrajaal.Authorization.Policy
    resource Indrajaal.Authorization.AuthorizationLog
    resource Indrajaal.Authorization.AccessMatrix
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Policy
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
