defmodule Indrajaal.MultiTenant do
  @moduledoc """
  Multi - tenant isolation framework.

  Ensures complete __data isolation between tenants.
  Agent: Helper - 3 enforces all isolation rules.
  """

  import Ecto.Query

  @spec scope_to_tenant(any(), any()) :: any()
  def scope_to_tenant(query, tenant_id) do
    where(query, [r], r.tenant_id == ^tenant_id)
  end

  @spec add_tenant(any(), any()) :: any()
  def add_tenant(changeset, tenant_id) do
    Ecto.Changeset.put_change(changeset, :tenant_id, tenant_id)
  end

  @spec verify_tenant_access(any(), any()) :: any()
  def verify_tenant_access(resource, tenant_id) do
    if resource.tenant_id == tenant_id do
      :ok
    else
      {:error, :tenant_mismatch}
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
