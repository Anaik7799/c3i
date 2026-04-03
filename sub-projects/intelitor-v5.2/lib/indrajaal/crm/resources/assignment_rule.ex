defmodule Indrajaal.Crm.AssignmentRule do
  @moduledoc """
  Assignment Rule resource - defines record assignment automation.

  ## Purpose

  Stores assignment rule configuration including:
  - Object type to assign
  - Evaluation criteria
  - Target assignee
  - Rule order and priority

  ## STAMP Constraints

  - SC-DB-001: Uses BaseResource
  - SC-DB-005: UUID primary key
  - SC-DB-012: create_if_not_exists indexes
  - SC-AUTO-001: Max 100 rules per object type
  - SC-AUTO-003: Fallback owner required

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
      description "Assignment rule name"
    end

    attribute :description, :string do
      public? true
      description "Assignment rule description"
    end

    attribute :object_type, :atom do
      allow_nil? false
      public? true
      description "Object type to assign (lead, case, etc.)"
    end

    attribute :criteria, :map do
      public? true
      default %{}
      description "Matching criteria (field conditions)"
    end

    attribute :assignee_id, :uuid do
      allow_nil? false
      public? true
      description "User or queue to assign to"
    end

    attribute :assignee_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:user, :queue, :role]
      default :user
      description "Type of assignee"
    end

    attribute :assignment_method, :atom do
      public? true
      constraints one_of: [:direct, :round_robin, :load_balance]
      default :direct
      description "Assignment method"
    end

    attribute :active, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether rule is active"
    end

    attribute :order, :integer do
      allow_nil? false
      public? true
      constraints min: 0
      default 0
      description "Evaluation order (lower evaluates first)"
    end

    attribute :metadata, :map do
      public? true
      default %{}
      description "Additional rule metadata"
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
        :criteria,
        :assignee_id,
        :assignee_type,
        :assignment_method,
        :active,
        :order,
        :metadata
      ]

      primary? true
    end

    update :update do
      accept [
        :name,
        :description,
        :criteria,
        :assignee_id,
        :assignee_type,
        :assignment_method,
        :active,
        :order,
        :metadata
      ]

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

    read :active do
      filter expr(active == true)
    end

    read :active_by_type do
      argument :object_type, :atom, allow_nil?: false

      filter expr(object_type == ^arg(:object_type) and active == true)

      prepare fn query, _context ->
        Ash.Query.sort(query, order: :asc)
      end
    end

    read :by_assignee do
      argument :assignee_id, :uuid, allow_nil?: false

      filter expr(assignee_id == ^arg(:assignee_id))
    end
  end

  code_interface do
    define :create, action: :create
    define :update, action: :update
    # get and list are already defined in BaseResource
    define :activate, action: :activate
    define :deactivate, action: :deactivate
    define :by_object_type, args: [:object_type]
    define :active
    define :active_by_type, args: [:object_type]
    define :by_assignee, args: [:assignee_id]
  end

  identities do
    identity :unique_name, [:name], message: "Assignment rule name must be unique"
  end

  postgres do
    table "assignment_rules"
    repo Indrajaal.Repo

    custom_indexes do
      index [:object_type], name: "assignment_rules_object_type_index"
      index [:active], name: "assignment_rules_active_index"
      index [:object_type, :active], name: "assignment_rules_lookup_index"
      index [:order], name: "assignment_rules_order_index"
      index [:assignee_id], name: "assignment_rules_assignee_id_index"
    end
  end

  @doc """
  Checks whether a record matches this assignment rule's criteria.

  Criteria is a map of `%{field_name => expected_value}`. All conditions
  must match (AND semantics).
  """
  @spec matches?(map(), map()) :: boolean()
  def matches?(%{criteria: criteria}, record) when is_map(criteria) and is_map(record) do
    Enum.all?(criteria, fn {field, expected} ->
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field
      Map.get(record, field_atom) == expected
    end)
  rescue
    ArgumentError -> false
  end

  def matches?(_, _), do: false

  @doc """
  Returns active rules for a given object type, sorted by order (ascending).

  Uses the `:active_by_type` Ash read action. Falls back to an empty list
  on error so callers can safely iterate.
  """
  @spec active_by_object(atom(), Keyword.t()) :: [t()]
  def active_by_object(object_type, opts \\ []) do
    case __MODULE__.active_by_type(object_type, opts) do
      {:ok, rules} -> rules
      _ -> []
    end
  end
end
