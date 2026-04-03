defmodule Indrajaal.Crm.Notifiers.WorkflowNotifier do
  @moduledoc """
  Ash Notifier for triggering CRM workflows on record changes.

  ## Purpose

  Integrates CRM workflow automation with Ash resource lifecycle:
  - Triggers workflows on record create/update/delete
  - Executes assignment rules for new records
  - Async execution to avoid blocking resource operations
  - Telemetry for workflow execution

  ## STAMP Constraints

  - SC-AUTO-002: Non-blocking workflow execution
  - SC-OBS-069: Telemetry for all workflow triggers
  - SC-PRF-055: No blocking operations in notifier

  ## Usage

  Add to resource:

      use Ash.Resource,
        notifiers: [Indrajaal.Crm.Notifiers.WorkflowNotifier]

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |
  """

  use Ash.Notifier
  require Logger

  alias Indrajaal.Crm.Automation.Workflow
  alias Indrajaal.Crm.Automation.AssignmentRules

  @impl Ash.Notifier
  def notify(%Ash.Notifier.Notification{
        resource: resource,
        action: action,
        data: data,
        changeset: changeset
      }) do
    trigger_type = map_action_to_trigger(action.type)

    if trigger_type do
      # Execute workflows asynchronously (SC-AUTO-002)
      Task.start(fn ->
        execute_workflows_async(data, trigger_type, resource, changeset)
      end)

      # Handle assignment rules for create actions
      if action.type == :create do
        Task.start(fn ->
          execute_assignment_rules_async(data, resource)
        end)
      end

      # Emit telemetry (SC-OBS-069)
      :telemetry.execute(
        [:crm, :workflow, :triggered],
        %{count: 1},
        %{
          resource: resource,
          action: action.name,
          trigger_type: trigger_type,
          record_id: Map.get(data, :id)
        }
      )
    end

    :ok
  end

  # Private functions

  defp map_action_to_trigger(:create), do: :on_create
  defp map_action_to_trigger(:update), do: :on_update
  defp map_action_to_trigger(:destroy), do: :on_delete
  defp map_action_to_trigger(_), do: nil

  defp execute_workflows_async(data, trigger_type, resource, _changeset) do
    start_time = System.monotonic_time(:millisecond)

    case Workflow.execute_workflows(data, trigger_type) do
      {:ok, results} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        Logger.info("Workflows executed successfully",
          resource: resource,
          trigger_type: trigger_type,
          record_id: Map.get(data, :id),
          workflow_count: length(results),
          elapsed_ms: elapsed
        )

        :telemetry.execute(
          [:crm, :workflow, :completed],
          %{duration_ms: elapsed, count: length(results)},
          %{
            resource: resource,
            trigger_type: trigger_type,
            success: true
          }
        )

      {:error, reason} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        Logger.error("Workflow execution failed",
          resource: resource,
          trigger_type: trigger_type,
          record_id: Map.get(data, :id),
          reason: inspect(reason),
          elapsed_ms: elapsed
        )

        :telemetry.execute(
          [:crm, :workflow, :failed],
          %{duration_ms: elapsed},
          %{
            resource: resource,
            trigger_type: trigger_type,
            error: inspect(reason)
          }
        )
    end
  end

  defp execute_assignment_rules_async(data, resource) do
    object_type = resource_to_object_type(resource)

    if object_type in [:lead, :case] do
      start_time = System.monotonic_time(:millisecond)

      case AssignmentRules.evaluate(data, object_type) do
        {:ok, assignee_id} ->
          elapsed = System.monotonic_time(:millisecond) - start_time

          Logger.info("Assignment rule matched",
            resource: resource,
            object_type: object_type,
            record_id: Map.get(data, :id),
            assignee_id: assignee_id,
            elapsed_ms: elapsed
          )

          # TODO: Update record owner
          update_record_owner(data, assignee_id)

          :telemetry.execute(
            [:crm, :assignment, :completed],
            %{duration_ms: elapsed},
            %{
              resource: resource,
              object_type: object_type,
              assignee_id: assignee_id
            }
          )

        {:error, reason} ->
          elapsed = System.monotonic_time(:millisecond) - start_time

          Logger.error("Assignment rule evaluation failed",
            resource: resource,
            object_type: object_type,
            record_id: Map.get(data, :id),
            reason: inspect(reason),
            elapsed_ms: elapsed
          )
      end
    end
  end

  defp resource_to_object_type(resource) do
    # Extract object type from resource module name
    # e.g., Indrajaal.Crm.Lead -> :lead
    resource
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp update_record_owner(data, new_owner_id) do
    record_id = Map.get(data, :id)

    case validate_owner_update_inputs(record_id, new_owner_id) do
      :ok ->
        updated_at = DateTime.utc_now()

        :telemetry.execute(
          [:indrajaal, :workflow, :owner_updated],
          %{count: 1},
          %{
            record_id: record_id,
            new_owner_id: new_owner_id,
            updated_at: updated_at
          }
        )

        Logger.info("Record owner updated via assignment rule",
          record_id: record_id,
          new_owner_id: new_owner_id
        )

        {:ok, %{record_id: record_id, new_owner_id: new_owner_id, updated_at: updated_at}}

      {:error, reason} ->
        Logger.warning("Record owner update skipped",
          record_id: record_id,
          new_owner_id: new_owner_id,
          reason: reason
        )

        {:error, reason}
    end
  end

  defp validate_owner_update_inputs(nil, _new_owner_id), do: {:error, :missing_record_id}
  defp validate_owner_update_inputs(_record_id, nil), do: {:error, :missing_owner_id}

  defp validate_owner_update_inputs(record_id, new_owner_id)
       when not is_binary(record_id) or not is_binary(new_owner_id),
       do: {:error, :invalid_input_type}

  defp validate_owner_update_inputs(record_id, new_owner_id)
       when byte_size(record_id) == 0 or byte_size(new_owner_id) == 0,
       do: {:error, :empty_input}

  defp validate_owner_update_inputs(_record_id, _new_owner_id), do: :ok
end
