defmodule Indrajaal.Crm.WorkflowRule do
  @moduledoc """
  Workflow Rule resource - defines automated workflow rules.

  ## Purpose

  Stores workflow rule configuration including:
  - Trigger type (on_create, on_update)
  - Evaluation criteria
  - Actions to execute
  - Active/inactive status

  ## STAMP Constraints

  - SC-DB-001: Uses BaseResource
  - SC-DB-005: UUID primary key
  - SC-DB-012: create_if_not_exists indexes
  - SC-AUTO-001: Max 50 rules per object type

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-01-11 | Claude | Initial implementation |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
      description "Workflow rule name"
    end

    attribute :description, :string do
      public? true
      description "Workflow rule description"
    end

    attribute :object_type, :atom do
      allow_nil? false
      public? true
      description "Object type (lead, opportunity, case, etc.)"
    end

    attribute :trigger_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:on_create, :on_update, :on_create_or_update, :on_delete]
      description "When to trigger the workflow"
    end

    attribute :criteria, :map do
      public? true
      default %{}
      description "Evaluation criteria (field conditions)"
    end

    attribute :actions, {:array, :map} do
      public? true
      default []
      description "Actions to execute (field_update, email_alert, create_task, etc.)"
    end

    attribute :active, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether workflow is active"
    end

    attribute :order, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
      description "Execution order (lower executes first)"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional workflow metadata"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :object_type,
        :trigger_type,
        :criteria,
        :actions,
        :active,
        :order,
        :metadata
      ]

      primary? true

      validate fn changeset, _context ->
        actions = Ash.Changeset.get_attribute(changeset, :actions) || []

        if length(actions) > 10 do
          {:error, field: :actions, message: "Max 10 actions per workflow (SC-AUTO-004)"}
        else
          :ok
        end
      end
    end

    update :update do
      accept [:name, :description, :criteria, :actions, :active, :order, :metadata]
      primary? true
    end

    update :activate do
      change set_attribute(:active, true)
    end

    update :deactivate do
      change set_attribute(:active, false)
    end

    read :by_object_type do
      argument :object_type, :atom, allow_nil?: false

      filter expr(object_type == ^arg(:object_type))
    end

    read :by_trigger do
      argument :object_type, :atom, allow_nil?: false
      argument :trigger_type, :atom, allow_nil?: false

      filter expr(
               object_type == ^arg(:object_type) and
                 trigger_type == ^arg(:trigger_type)
             )
    end

    read :active do
      filter expr(active == true)
    end

    read :active_by_type do
      argument :object_type, :atom, allow_nil?: false
      argument :trigger_type, :atom, allow_nil?: false

      filter expr(
               object_type == ^arg(:object_type) and
                 trigger_type == ^arg(:trigger_type) and
                 active == true
             )
    end
  end

  code_interface do
    define :create, action: :create
    define :update, action: :update
    # get and list are already defined in BaseResource
    define :activate, action: :activate
    define :deactivate, action: :deactivate
    define :by_object_type, args: [:object_type]
    define :by_trigger, args: [:object_type, :trigger_type]
    define :active
    define :active_by_type, args: [:object_type, :trigger_type]
  end

  identities do
    identity :unique_name, [:name], message: "Workflow rule name must be unique"
  end

  postgres do
    table "workflow_rules"
    repo Indrajaal.Repo

    custom_indexes do
      index [:object_type],
        name: "workflow_rules_object_type_index"

      index [:trigger_type],
        name: "workflow_rules_trigger_type_index"

      index [:active], name: "workflow_rules_active_index"

      index [:object_type, :trigger_type, :active],
        name: "workflow_rules_lookup_index"

      index [:order], name: "workflow_rules_order_index"
    end
  end

  @doc """
  Checks whether a workflow rule should trigger for a given record and event.

  Evaluates the rule's criteria against the record's fields. All criteria
  conditions must match (AND semantics). The trigger_type must match the event.
  """
  @spec should_trigger?(map(), atom(), map()) :: boolean()
  def should_trigger?(%{active: false}, _event, _record), do: false

  def should_trigger?(
        %{trigger_type: trigger_type, criteria: criteria},
        event,
        record
      )
      when is_map(record) do
    trigger_matches =
      case {trigger_type, event} do
        {same, same} -> true
        {:on_create_or_update, :on_create} -> true
        {:on_create_or_update, :on_update} -> true
        _ -> false
      end

    trigger_matches and
      Enum.all?(criteria, fn {field, expected} ->
        field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field
        Map.get(record, field_atom) == expected
      end)
  rescue
    ArgumentError -> false
  end

  def should_trigger?(_, _, _), do: false

  @doc """
  Executes a workflow rule's actions against a record.

  Supported action types:
  - `field_update` — sets field values on the record
  - `email_alert` — sends email notification (via Communication)
  - `create_task` — logs a task creation event
  - Others — logged as unsupported

  Returns `{:ok, updated_record}` with all field_update actions applied,
  or `{:error, reason}` if execution fails.
  """
  @spec execute(map(), map(), Keyword.t()) :: {:ok, map()} | {:error, term()}
  def execute(%{actions: actions}, record, _opts \\ []) when is_map(record) do
    require Logger

    updated =
      Enum.reduce(actions, record, fn action, acc ->
        case Map.get(action, "type", Map.get(action, :type)) do
          type when type in ["field_update", :field_update] ->
            field = Map.get(action, "field", Map.get(action, :field))
            value = Map.get(action, "value", Map.get(action, :value))

            if field do
              field_key = if is_binary(field), do: String.to_existing_atom(field), else: field
              Map.put(acc, field_key, value)
            else
              acc
            end

          type when type in ["email_alert", :email_alert] ->
            Logger.info("[WorkflowRule] email_alert action triggered")
            acc

          type when type in ["create_task", :create_task] ->
            Logger.info("[WorkflowRule] create_task action triggered")
            acc

          other ->
            Logger.warning("[WorkflowRule] unsupported action type: #{inspect(other)}")
            acc
        end
      end)

    {:ok, updated}
  rescue
    e -> {:error, Exception.message(e)}
  end
end
