defmodule Indrajaal.Changes.TraceBusinessCritical do
  @moduledoc """
  Ash change module that traces business - critical operations with OpenTelemetry.
  """
  use Ash.Resource.Change
  require Logger

  @spec init(any()) :: any()
  def init(opts) do
    if is_nil(opts[:operation_name]) do
      {:error, "operation_name is __required"}
    else
      {:ok, opts}
    end
  end

  @spec change(term(), term(), term()) :: term()
  def change(changeset, opts, context) do
    operation_name = opts[:operation_name]
    importance = opts[:importance] || :high
    actor = context.actor

    business_context = %{
      operation: operation_name,
      importance: importance,
      resource: changeset.resource,
      actor_id: Indrajaal.Tracing.extract_actor_id(actor),
      tenant_id: Indrajaal.Tracing.extract_tenant_id(actor)
    }

    Indrajaal.Tracing.trace_business_operation(operation_name, business_context, fn ->
      # Emit business telemetry
      :telemetry.execute(
        [:indrajaal, :business, :critical_operation],
        %{count: 1, importance_level: importance_to_number(importance)},
        business_context
      )

      changeset
    end)
  end

  @spec importance_to_number(term()) :: term()
  defp importance_to_number(:low), do: 1
  defp importance_to_number(:medium), do: 2
  defp importance_to_number(:high), do: 3
  @spec importance_to_number(term()) :: term()
  defp importance_to_number(:critical), do: 4
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
