defmodule Indrajaal.Changes.TraceAndAudit do
  @moduledoc """
  Ash change module that adds comprehensive audit logging with tracing.
  """
  use Ash.Resource.Change
  require Logger

  alias Indrajaal.{Logging, Tracing}

  @spec init(any()) :: any()
  def init(opts) do
    if is_nil(opts[:audit_action]) do
      {:error, "audit_action is __required"}
    else
      {:ok, opts}
    end
  end

  @spec change(term(), term(), term()) :: term()
  def change(changeset, opts, context) do
    audit_action = opts[:audit_action]
    resource = changeset.resource
    action = changeset.action.name
    actor = context.actor

    # Create audit __context
    audit_context = %{
      resource: Tracing.extract_resource_name(resource),
      action: action,
      actor_id: Tracing.extract_actor_id(actor),
      tenant_id: Tracing.extract_tenant_id(actor),
      changes: changeset.attributes,
      ip_address: Map.get(context.source_context || %{}, :ip_address),
      __user_agent: Map.get(context.source_context || %{}, :__user_agent),
      session_id: Map.get(context.source_context || %{}, :session_id)
    }

    # Use structured logging
    Logging.log_audit_event(action, audit_context.resource, audit_context)

    # Trace the audit logging
    Tracing.trace_security_operation("audit.#{audit_action}", audit_context, fn ->
      changeset
    end)
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
