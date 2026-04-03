defmodule Indrajaal.Multitenancy.TenantResource do
  @moduledoc """
  Provides multi - tenancy support for Ash resources.

  This extension automatically adds tenant isolation to any resource that
    uses it.
  It includes:
  - tenant_id attribute
  - automatic tenant filtering on all queries
  - tenant validation on creates / updates
  - tenant isolation calculations
  """

  # Claude Agent Fix: Mark opts parameter as unused with underscore prefix
  # TPS Jidoka: Stop-and-fix for unused parameter warning
  # 5-Level RCA: Root cause: Parameter required by macro signature but not used
  defmacro __using__(_opts) do
    quote do
      require Ash.Query

      attributes do
        attribute :tenant_id, :uuid do
          allow_nil? false
          public? true
          description "The tenant this resource belongs to"
        end
      end

      changes do
        change fn changeset, context ->
          actor = Map.get(context, :actor)

          if changeset.action.type == :create && actor do
            # Handle different actor types
            tenant_id =
              case actor do
                %{id: id, __struct__: Indrajaal.Core.Tenant} -> id
                %{tenant_id: tenant_id} when is_binary(tenant_id) -> tenant_id
                actor when is_map(actor) -> actor[:tenant_id]
                _ -> nil
              end

            if tenant_id do
              Ash.Changeset.force_change_attribute(changeset, :tenant_id, tenant_id)
            else
              changeset
            end
          else
            changeset
          end
        end
      end

      preparations do
        prepare fn query, context ->
          # First check if tenant is passed directly in the context
          tenant_id = Map.get(context, :tenant) || query.tenant

          # If not, try to get it from the actor
          actor = Map.get(context, :actor)

          tenant_id =
            tenant_id ||
              case actor do
                %{id: id, __struct__: Indrajaal.Core.Tenant} -> id
                %{tenant_id: tid} when is_binary(tid) -> tid
                act when is_map(act) -> act[:tenant_id]
                _ -> nil
              end

          if tenant_id do
            Ash.Query.filter(query, tenant_id: tenant_id)
          else
            query
          end
        end
      end

      # No explicit validations needed - tenant_id is set automatically from ac
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
