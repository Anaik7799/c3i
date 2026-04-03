defmodule Indrajaal.Crm.Activity do
  @moduledoc """
  CRM Activity resource for tracking tasks, events, calls, and emails.

  Features:
  - Multi-type activities (Task, Event, Call, Email)
  - Polymorphic associations (Lead, Account, Contact, Opportunity)
  - Status and priority tracking
  - Reminders and recurrence
  - Outcome tracking

  ## STAMP Compliance
  - SC-ASH-001: force_change_attribute in before_action
  - SC-ASH-004: require_atomic? false for fn changes
  - SC-DB-001: Uses BaseResource
  - SC-DB-005: uuid_primary_key
  - SC-DB-012: create_if_not_exists indexes
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Crm

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    # Basic Information
    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [:task, :event, :call, :email]
      description "Activity type"
    end

    attribute :subject, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
      description "Activity subject/title"
    end

    attribute :description, :string do
      description "Detailed description"
    end

    # Status and priority
    attribute :status, :atom do
      default :not_started

      constraints one_of: [
                    :not_started,
                    :in_progress,
                    :completed,
                    :deferred,
                    :waiting,
                    :cancelled
                  ]

      description "Activity status"
    end

    attribute :priority, :atom do
      default :normal
      constraints one_of: [:low, :normal, :high, :urgent]
      description "Activity priority"
    end

    # Timing
    attribute :due_date, :utc_datetime do
      description "Due date/time"
    end

    attribute :start_datetime, :utc_datetime do
      description "Start date/time (for events)"
    end

    attribute :end_datetime, :utc_datetime do
      description "End date/time (for events)"
    end

    attribute :duration_minutes, :integer do
      description "Activity duration in minutes"
    end

    attribute :reminder_datetime, :utc_datetime do
      description "When to send reminder"
    end

    # Completion
    attribute :completed_at, :utc_datetime do
      description "When activity was completed"
    end

    attribute :outcome, :string do
      constraints max_length: 255
      description "Activity outcome/result"
    end

    # Type-specific fields
    # Call
    attribute :call_type, :atom do
      constraints one_of: [:inbound, :outbound]
      description "For calls: inbound or outbound"
    end

    attribute :call_duration_seconds, :integer do
      description "For calls: actual call duration"
    end

    attribute :call_result, :string do
      constraints max_length: 100
      description "For calls: connected, no_answer, voicemail, etc."
    end

    # Email
    attribute :email_from, :string do
      constraints max_length: 255
      description "For emails: sender address"
    end

    attribute :email_to, {:array, :string} do
      default []
      description "For emails: recipient addresses"
    end

    attribute :email_cc, {:array, :string} do
      default []
    end

    # Polymorphic parent (what this activity is related to)
    attribute :related_to_type, :string do
      constraints max_length: 100
      description "Type of related record: Lead, Account, Contact, Opportunity"
    end

    attribute :related_to_id, :uuid do
      description "ID of related record"
    end

    # Metadata
    attribute :tags, {:array, :string} do
      default []
    end

    attribute :custom_fields, :map do
      default %{}
    end

    attribute :created_by_id, :uuid
    attribute :updated_by_id, :uuid

    timestamps()
  end

  relationships do
    belongs_to :owner, Indrajaal.Accounts.User do
      attribute_public? true
      description "Activity owner/assignee"
    end

    belongs_to :created_by, Indrajaal.Accounts.User do
      source_attribute :created_by_id
      attribute_public? true
    end

    belongs_to :updated_by, Indrajaal.Accounts.User do
      source_attribute :updated_by_id
      attribute_public? true
    end

    # Specific relationships (even though we use polymorphic pattern)
    belongs_to :lead, Indrajaal.Crm.Lead do
      attribute_public? true
    end

    belongs_to :account, Indrajaal.Crm.Account do
      attribute_public? true
    end

    belongs_to :contact, Indrajaal.Crm.Contact do
      attribute_public? true
    end

    belongs_to :opportunity, Indrajaal.Crm.Opportunity do
      attribute_public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :type,
        :subject,
        :description,
        :status,
        :priority,
        :due_date,
        :start_datetime,
        :end_datetime,
        :duration_minutes,
        :reminder_datetime,
        :call_type,
        :call_duration_seconds,
        :call_result,
        :email_from,
        :email_to,
        :email_cc,
        :related_to_type,
        :related_to_id,
        :tags,
        :custom_fields
      ]

      argument :owner_id, :uuid
      argument :lead_id, :uuid
      argument :account_id, :uuid
      argument :contact_id, :uuid
      argument :opportunity_id, :uuid
      argument :created_by_id, :uuid, allow_nil?: false

      change set_attribute(:owner_id, arg(:owner_id))
      change set_attribute(:lead_id, arg(:lead_id))
      change set_attribute(:account_id, arg(:account_id))
      change set_attribute(:contact_id, arg(:contact_id))
      change set_attribute(:opportunity_id, arg(:opportunity_id))
      change set_attribute(:created_by_id, arg(:created_by_id))

      validate present([:type, :subject])
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :subject,
        :description,
        :status,
        :priority,
        :due_date,
        :start_datetime,
        :end_datetime,
        :duration_minutes,
        :reminder_datetime,
        :outcome,
        :call_type,
        :call_duration_seconds,
        :call_result,
        :email_from,
        :email_to,
        :email_cc,
        :tags,
        :custom_fields
      ]

      argument :updated_by_id, :uuid

      change set_attribute(:updated_by_id, arg(:updated_by_id))
    end

    update :complete do
      require_atomic? false
      accept []

      argument :outcome, :string

      change fn changeset, _ ->
        outcome = Ash.Changeset.get_argument(changeset, :outcome)

        changeset
        |> Ash.Changeset.change_attribute(:status, :completed)
        |> Ash.Changeset.change_attribute(:completed_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:outcome, outcome)
      end
    end

    update :cancel do
      require_atomic? false
      accept []

      change set_attribute(:status, :cancelled)
    end

    update :assign do
      require_atomic? false
      accept []

      argument :owner_id, :uuid, allow_nil?: false

      change fn changeset, _ ->
        owner_id = Ash.Changeset.get_argument(changeset, :owner_id)
        Ash.Changeset.change_attribute(changeset, :owner_id, owner_id)
      end
    end
  end

  calculations do
    calculate :is_overdue?, :boolean do
      calculation fn records, _ ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.due_date && record.status not in [:completed, :cancelled] do
            DateTime.compare(record.due_date, now) == :lt
          else
            false
          end
        end)
      end
    end

    calculate :is_completed?, :boolean, expr(status == :completed)
  end

  validations do
    validate fn changeset, _ ->
      # Validate end_datetime > start_datetime for events
      start_dt = Ash.Changeset.get_attribute(changeset, :start_datetime)
      end_dt = Ash.Changeset.get_attribute(changeset, :end_datetime)

      if start_dt && end_dt && DateTime.compare(end_dt, start_dt) != :gt do
        {:error, field: :end_datetime, message: "must be after start_datetime"}
      else
        :ok
      end
    end
  end

  policies do
    # Admins can do anything
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Managers can manage activities
    policy action_type([:read, :create, :update]) do
      authorize_if actor_attribute_equals(:role, :manager)
    end

    # Operators can read and manage their activities
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :operator)
    end

    policy action_type([:create, :update]) do
      authorize_if expr(owner_id == ^actor(:id))
    end
  end

  code_interface do
    define :create
    define :update
    define :complete, args: [:outcome]
    define :cancel
    define :assign, args: [:owner_id]
  end

  postgres do
    table "activities"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :type]
      index [:owner_id]
      index [:status]
      index [:priority]
      index [:due_date], where: "due_date IS NOT NULL"
      index [:lead_id], where: "lead_id IS NOT NULL"
      index [:account_id], where: "account_id IS NOT NULL"
      index [:contact_id], where: "contact_id IS NOT NULL"
      index [:opportunity_id], where: "opportunity_id IS NOT NULL"
      index [:related_to_type, :related_to_id], where: "related_to_id IS NOT NULL"
      index [:created_at]
    end
  end
end
