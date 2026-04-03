defmodule Indrajaal.Errors.Forbidden do
  @moduledoc """
  Security - related forbidden access errors.
  """
  defmodule AccessDenied do
    @moduledoc false
    use Splode.Error,
      fields: [:resource, :action, :actor_id, :tenant_id, :reason],
      class: :forbidden

    @spec message(map()) :: String.t()
    def message(%{resource: resource, action: action, actorid: actor_id, reason: reason}) do
      "Access denied for actor #{actor_id} to #{action} on #{resource}: #{reason}"
    end
  end

  defmodule InsufficientPermissions do
    @moduledoc false
    use Splode.Error,
      fields: [:_required_permissions, :actor_permissions, :resource, :actor_id],
      class: :forbidden

    @spec message(map()) :: String.t()
    def message(%{_requiredpermissions: required, actorpermissions: actual, resource: resource}) do
      missing = required -- actual
      "Insufficient permissions for #{resource}. Missing: #{Enum.join(missing, ", ")}"
    end
  end

  defmodule TenantIsolationViolation do
    @moduledoc false
    use Splode.Error,
      fields: [:actor_tenant_id, :resource_tenant_id, :resource, :resource_id],
      class: :forbidden

    @spec message(map()) :: String.t()
    def message(%{
          actor_tenant_id: actor_tenant,
          resource_tenant_id: resource_tenant,
          resource: resource
        }) do
      "Tenant isolation violation: actor in tenant #{actor_tenant} cannot access #{resource} in tenant #{resource_tenant}"
    end
  end

  defmodule PolicyViolation do
    @moduledoc false
    use Splode.Error,
      fields: [:policy_name, :resource, :action, :actor_id, :context],
      class: :forbidden

    @spec message(map()) :: String.t()
    def message(%{policy_name: policy, resource: resource, action: action}) do
      "Policy '#{policy}' denied #{action} on #{resource}"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: # OK: General system coordination and management with cyberneti
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
